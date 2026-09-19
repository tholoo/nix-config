"""One editor/agent workspace per canonical directory, hosted by Zellij."""

import argparse
import contextlib
import fcntl
import hashlib
import json
import os
import re
import signal
import socket
import stat
import subprocess
import sys
import tempfile
from pathlib import Path

DEFAULT_CONFIG = {
    "editorCommand": ["nvim"],
    "agentCommand": ["pi"],
    "editorWidth": 60,
    "zellijCommand": "zellij",
    "direnvCommand": None,
}


def workspace_root(directory):
    root = Path(directory).expanduser().resolve(strict=True)
    if not root.is_dir():
        raise ValueError(f"Not a directory: {root}")
    result = subprocess.run(
        ["git", "-C", str(root), "rev-parse", "--show-toplevel"],
        text=True,
        check=False,
        capture_output=True,
    )
    return (
        Path(result.stdout.rstrip("\n")).resolve() if result.returncode == 0 else root
    )


def workspace_id(root):
    digest = hashlib.sha256(os.fsencode(root)).hexdigest()[:20]
    label = re.sub(r"[^a-zA-Z0-9_-]", "-", root.name)[:24] or "workspace"
    return f"dev-{label}-{digest}"


def private_dir(path):
    path.mkdir(mode=0o700, parents=True, exist_ok=True)
    info = path.lstat()
    if not stat.S_ISDIR(info.st_mode) or info.st_uid != os.getuid():
        raise ValueError(f"Runtime path must be an owned directory: {path}")
    path.chmod(0o700)
    return path


def runtime_dir(root):
    base = Path(os.environ.get("XDG_RUNTIME_DIR", f"/run/user/{os.getuid()}"))
    if not base.is_absolute() or not base.is_dir():
        raise ValueError("A valid XDG_RUNTIME_DIR is required")
    # Keep socket paths short even for deeply nested projects.
    return private_dir(private_dir(base / "dev") / workspace_id(root).rsplit("-", 1)[1])


def socket_path(runtime):
    path = runtime / "nvim.sock"
    if len(os.fsencode(path)) >= 108:
        raise ValueError("XDG_RUNTIME_DIR is too long for a Unix socket")
    return path


@contextlib.contextmanager
def lock(path, blocking=True):
    fd = os.open(path, os.O_CREAT | os.O_RDWR | os.O_NOFOLLOW, 0o600)
    try:
        fcntl.flock(fd, fcntl.LOCK_EX | (0 if blocking else fcntl.LOCK_NB))
        yield fd
    finally:
        os.close(fd)


def atomic_write(path, text):
    fd, temporary = tempfile.mkstemp(prefix=".dev-", dir=path.parent)
    try:
        with os.fdopen(fd, "w") as stream:
            stream.write(text)
        os.replace(temporary, path)
    finally:
        if os.path.exists(temporary):
            os.unlink(temporary)


def reentry(config_path):
    args = [sys.executable, str(Path(__file__).resolve())]
    if config_path:
        args += ["--config", str(Path(config_path).resolve())]
    return args


def live_socket(path):
    with socket.socket(socket.AF_UNIX, socket.SOCK_STREAM) as connection:
        connection.settimeout(0.25)
        try:
            connection.connect(str(path))
            return True
        except (FileNotFoundError, ConnectionRefusedError):
            return False


def pane(role, root, runtime, config):
    # Explicit pane arguments remain authoritative when Zellij restores a pane.
    runtime = private_dir(runtime)
    address = socket_path(runtime)
    env = dict(os.environ)
    if role == "agent":
        snapshot = runtime / "environment.json"
        if snapshot.exists():
            inherited = json.loads(snapshot.read_text())
            # The new pane's identity belongs to Zellij, not the launching shell.
            pane_identity = {
                key: value for key, value in env.items() if key.startswith("ZELLIJ")
            }
            env = inherited | pane_identity
    env.pop("NVIM", None)
    env.pop("NVIM_LISTEN_ADDRESS", None)
    env.update(
        DEV_WORKSPACE_ROOT=str(root),
        DEV_NVIM_SOCKET=str(address),
        NVIM_ADDRESS=str(address),
    )
    env["PWD"] = str(root)
    command = list(config["editorCommand" if role == "editor" else "agentCommand"])
    try:
        with lock(runtime / f"{role}.lock", blocking=False) as role_lock:
            if role == "editor":
                if address.is_symlink():
                    raise ValueError(
                        f"Refusing a symlink at the editor socket: {address}"
                    )
                if address.exists():
                    if not stat.S_ISSOCK(address.stat().st_mode):
                        raise ValueError(f"Refusing to replace a non-socket: {address}")
                    if live_socket(address):
                        raise ValueError("The workspace editor is already running")
                    address.unlink()
                command += ["--listen", str(address)]
            # Keep this supervisor alive to own the role lock. Zellij retains an
            # exited pane, so Enter restarts just this editor or agent.
            return run_pane_command(command, root, env, role_lock)
    except BlockingIOError as error:
        raise ValueError(f"The workspace {role} is already running") from error


def run_pane_command(command, root, env, role_lock):
    child = subprocess.Popen(command, cwd=root, env=env, pass_fds=(role_lock,))
    previous = {}
    try:
        # Interactive Ctrl-C belongs to the pane program, not its supervisor.
        previous[signal.SIGINT] = signal.signal(signal.SIGINT, signal.SIG_IGN)
        for signum in (signal.SIGTERM, signal.SIGHUP):
            previous[signum] = signal.signal(
                signum, lambda sig, frame: child.send_signal(sig)
            )
        return child.wait()
    finally:
        for signum, handler in previous.items():
            signal.signal(signum, handler)


def action(config, *arguments):
    result = subprocess.run(
        [
            config["zellijCommand"],
            "--session",
            os.environ["ZELLIJ_SESSION_NAME"],
            "action",
            *arguments,
        ],
        capture_output=True,
        text=True,
        check=False,
        timeout=10,
    )
    if result.returncode:
        raise RuntimeError(result.stderr.strip() or "Zellij action failed")
    return result.stdout


def current_pane(config):
    if not all(
        os.environ.get(key)
        for key in ("ZELLIJ", "ZELLIJ_SESSION_NAME", "ZELLIJ_PANE_ID")
    ):
        raise ValueError("Run dev from a terminal pane in your existing Zellij session")
    pane_id = int(os.environ["ZELLIJ_PANE_ID"].removeprefix("terminal_"))
    panes = json.loads(action(config, "list-panes", "--json", "--all"))
    caller = next((p for p in panes if not p["is_plugin"] and p["id"] == pane_id), None)
    if caller is None:
        raise ValueError("Cannot identify the invoking Zellij pane")
    terminals = [
        p
        for p in panes
        if p["tab_id"] == caller["tab_id"]
        and not p["is_plugin"]
        and not p["is_suppressed"]
    ]
    if caller["is_floating"] or caller["is_fullscreen"]:
        raise ValueError(
            "Run dev in a tab with one tiled terminal pane, outside fullscreen mode"
        )
    return caller, terminals


def resize_pair(config, editor_id, agent_id):
    target = config["editorWidth"] / 100
    for _ in range(20):
        panes = json.loads(action(config, "list-panes", "--json", "--all"))
        terminals = {p["id"]: p for p in panes if not p["is_plugin"]}
        editor, agent = terminals[editor_id], terminals[agent_id]
        total = editor["pane_columns"] + agent["pane_columns"]
        fraction = editor["pane_columns"] / total
        if abs(fraction - target) <= 1 / total:
            return
        action(
            config,
            "resize",
            "increase" if fraction < target else "decrease",
            "right",
            "--pane-id",
            f"terminal_{editor_id}",
        )
    raise RuntimeError("Could not resize the pair; the terminal may be too narrow")


def launch(root, config, config_path):
    caller, terminals = current_pane(config)
    runtime = runtime_dir(root)
    try:
        with lock(runtime / "launch.lock", blocking=False):
            with lock(runtime / "editor.lock", blocking=False):
                pass
            pair_path = runtime / "pair.json"
            pair = json.loads(pair_path.read_text()) if pair_path.exists() else {}
            existing_agent = next(
                (p for p in terminals if p["id"] == pair.get("agent")), None
            )
            reuse = (
                len(terminals) == 2
                and pair.get("session") == os.environ["ZELLIJ_SESSION_NAME"]
                and pair.get("editor") == caller["id"]
                and pair.get("tab") == caller["tab_id"]
                and existing_agent is not None
                and existing_agent.get("terminal_command") == pair.get("agentCommand")
            )
            if not reuse and len(terminals) != 1:
                raise ValueError(
                    "Run dev in a tab with one terminal pane, or in its existing editor pane"
                )
            if reuse:
                agent_id = existing_agent["id"]
                created = None
            else:
                with lock(runtime / "agent.lock", blocking=False):
                    pass
                # The existing server can predate this shell's dev environment.
                # A private runtime snapshot also preserves it on agent restart.
                atomic_write(runtime / "environment.json", json.dumps(dict(os.environ)))
                command = reentry(config_path) + [
                    "_pane",
                    "agent",
                    str(root),
                    str(runtime),
                ]
                created = action(
                    config,
                    "new-pane",
                    "--direction",
                    "right",
                    "--no-focus",
                    "--cwd",
                    str(root),
                    "--name",
                    "agent",
                    "--",
                    *command,
                ).strip()
                match = re.fullmatch(r"terminal_(\d+)", created)
                if not match:
                    raise RuntimeError(
                        f"Unexpected pane identifier from Zellij: {created}"
                    )
                agent_id = int(match.group(1))
            try:
                resize_pair(config, caller["id"], agent_id)
            except Exception:
                # Undo only the pane this invocation created.
                if created:
                    action(config, "close-pane", "--pane-id", created)
                raise
            all_panes = json.loads(action(config, "list-panes", "--json", "--all"))
            agent_pane = next(
                p for p in all_panes if not p["is_plugin"] and p["id"] == agent_id
            )
            atomic_write(
                pair_path,
                json.dumps(
                    {
                        "session": os.environ["ZELLIJ_SESSION_NAME"],
                        "tab": caller["tab_id"],
                        "editor": caller["id"],
                        "agent": agent_id,
                        "agentCommand": agent_pane.get("terminal_command"),
                    }
                ),
            )
            action(
                config, "rename-pane", "--pane-id", f"terminal_{caller['id']}", "editor"
            )
            # Neovim runs in the invoking shell's pane. Exiting returns to that
            # shell; the agent pane remains independently usable.
            return pane("editor", root, runtime, config)
    except BlockingIOError as error:
        raise ValueError(
            "This worktree already has a running dev editor or agent"
        ) from error


def main(argv=None):
    parser = argparse.ArgumentParser(
        description="Split the current Zellij tab into Neovim (60%) and an agent (40%)."
    )
    parser.add_argument("--config", help=argparse.SUPPRESS)
    parser.add_argument(
        "--status",
        action="store_true",
        help="show workspace root and editor socket without launching",
    )
    parser.add_argument(
        "directory",
        nargs="?",
        default=".",
        help="directory or Git worktree (default: current directory)",
    )
    parser.add_argument("internal_args", nargs="*", help=argparse.SUPPRESS)
    args = parser.parse_args(argv)
    config = DEFAULT_CONFIG | (
        json.loads(Path(args.config).read_text()) if args.config else {}
    )
    for key in ("editorCommand", "agentCommand"):
        if (
            not isinstance(config[key], list)
            or not config[key]
            or not all(isinstance(x, str) and x for x in config[key])
        ):
            raise ValueError(f"{key} must be a nonempty argument list")
    if not 10 <= config["editorWidth"] <= 90 or config["editorWidth"] % 5:
        raise ValueError("editorWidth must be a multiple of 5 between 10 and 90")
    if args.directory == "_pane":
        role, root, runtime = args.internal_args
        if role not in ("editor", "agent"):
            raise ValueError("Unknown pane role")
        return pane(role, Path(root), Path(runtime), config)
    if args.directory == "_launch":
        root = Path(args.internal_args[0])
    else:
        if args.internal_args:
            parser.error("expected one directory")
        root = workspace_root(args.directory)
        if args.status:
            print(
                json.dumps(
                    {
                        "workspace": workspace_id(root),
                        "root": str(root),
                        "socket": str(socket_path(runtime_dir(root))),
                    },
                    indent=2,
                )
            )
            return 0
        current_pane(config)
        if config["direnvCommand"]:
            command = [config["direnvCommand"], "exec", str(root)] + reentry(
                args.config
            )
            command += ["_launch", str(root)]
            os.execvp(command[0], command)
    return launch(root, config, args.config)


if __name__ == "__main__":
    try:
        sys.exit(main())
    except (OSError, ValueError, RuntimeError, subprocess.TimeoutExpired) as error:
        print(f"dev: {error}", file=sys.stderr)
        sys.exit(1)
