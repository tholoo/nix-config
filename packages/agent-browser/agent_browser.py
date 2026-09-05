"""Launch Playwright MCP with an exclusively leased, persistent browser profile."""

import argparse
import fcntl
import os
from pathlib import Path
import re
import signal
import subprocess
import sys


def lease_profile(root, profile=None):
    root.mkdir(parents=True, exist_ok=True, mode=0o700)
    os.chmod(root, 0o700)
    names = (
        [profile] if profile else ["primary", *[f"parallel-{i}" for i in range(1, 32)]]
    )
    for name in names:
        lock = open(root / f".{name}.lock", "a+")
        try:
            fcntl.flock(lock, fcntl.LOCK_EX | fcntl.LOCK_NB)
        except BlockingIOError:
            lock.close()
            continue
        directory = root / name
        directory.mkdir(exist_ok=True, mode=0o700)
        os.chmod(directory, 0o700)
        return directory, lock
    raise RuntimeError(
        "Browser profile is busy; choose another --profile or close its session"
    )


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--profile", help="Reuse a named profile exclusively (default: first free slot)"
    )
    parser.add_argument(
        "--headless", action="store_true", help="Run without a visible browser window"
    )
    args = parser.parse_args()
    if args.profile and not re.fullmatch(
        r"[a-zA-Z0-9][a-zA-Z0-9_-]{0,63}", args.profile
    ):
        parser.error("profile must be 1–64 letters, digits, underscores or hyphens")
    os.umask(0o077)
    state = Path(os.environ.get("XDG_STATE_HOME", Path.home() / ".local/state"))
    if not state.is_absolute():
        parser.error("XDG_STATE_HOME must be absolute")
    directory, lock = lease_profile(state / "agent-browsers" / "codex", args.profile)
    env = os.environ.copy()
    # nixpkgs' wrapper defaults to isolated mode unless this variable is set.
    env["PLAYWRIGHT_MCP_USER_DATA_DIR"] = str(directory)
    env.pop("PLAYWRIGHT_MCP_ISOLATED", None)
    command = [
        env["AGENT_BROWSER_MCP"],
        "--browser",
        "chromium",
        "--executable-path",
        env["AGENT_BROWSER_CHROMIUM"],
        "--user-data-dir",
        str(directory),
    ]
    if args.headless:
        command.append("--headless")
    # Retain the lease in both processes, including if this launcher is killed.
    with lock:
        child = subprocess.Popen(command, env=env, pass_fds=(lock.fileno(),))

        def forward(signum, _frame):
            if child.poll() is None:
                child.send_signal(signum)

        signal.signal(signal.SIGTERM, forward)
        signal.signal(signal.SIGINT, forward)
        return child.wait()


if __name__ == "__main__":
    try:
        sys.exit(main())
    except (OSError, RuntimeError, KeyError) as error:
        print(f"agent-browser: {error}", file=sys.stderr)
        sys.exit(1)
