#!/usr/bin/env python3
"""Codex lifecycle hook and USB bridge for the ESP32 status dashboard."""

from __future__ import annotations

import argparse
import json
import os
from pathlib import Path
import re
import shlex
import shutil
import sqlite3
import sys
import tempfile
import threading
import time
from typing import Any
from urllib.error import HTTPError, URLError
from urllib.request import Request, urlopen


MAX_TASKS = 6
PROBE_URL = "https://chatgpt.com"
SERIAL_BAUD = 115200


def state_directory() -> Path:
    configured = os.environ.get("CODEX_BOARD_STATE_DIR")
    path = (
        Path(configured).expanduser()
        if configured
        else Path(tempfile.gettempdir()) / f"codex-board-{os.getuid()}"
    )
    path.mkdir(mode=0o700, parents=True, exist_ok=True)
    return path


def database_path() -> Path:
    return state_directory() / "state.sqlite3"


def open_database(path: Path | None = None) -> sqlite3.Connection:
    connection = sqlite3.connect(path or database_path(), timeout=3)
    connection.row_factory = sqlite3.Row
    connection.execute("PRAGMA busy_timeout = 3000")
    connection.execute(
        """
        CREATE TABLE IF NOT EXISTS tasks (
            id TEXT PRIMARY KEY,
            parent_session TEXT NOT NULL,
            kind TEXT NOT NULL,
            project TEXT NOT NULL,
            title TEXT NOT NULL,
            status TEXT NOT NULL,
            started_at REAL NOT NULL,
            status_since REAL NOT NULL,
            updated_at REAL NOT NULL,
            finished_at REAL
        )
        """
    )
    connection.commit()
    return connection


def project_name(cwd: str | None) -> str:
    if not cwd:
        return "unknown"
    path = Path(cwd)
    return path.name or str(path)


def clean_text(value: str, limit: int = 48) -> str:
    value = re.sub(r"[\r\n|]+", " ", value).strip()
    value = re.sub(r"\s+", " ", value)
    return value.encode("ascii", "replace").decode("ascii")[:limit] or "_"


def update_task(
    connection: sqlite3.Connection,
    task_id: str,
    parent_session: str,
    kind: str,
    project: str,
    status: str,
    *,
    title: str | None = None,
    reset_timer: bool = False,
) -> None:
    now = time.time()
    row = connection.execute("SELECT * FROM tasks WHERE id = ?", (task_id,)).fetchone()

    if row is None:
        connection.execute(
            """
            INSERT INTO tasks
                (id, parent_session, kind, project, title, status,
                 started_at, status_since, updated_at, finished_at)
            VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
            """,
            (
                task_id,
                parent_session,
                kind,
                clean_text(project, 32),
                clean_text(title or "_", 32),
                status,
                now,
                now,
                now,
                now if status == "D" else None,
            ),
        )
    else:
        status_since = now if reset_timer or row["status"] != status else row["status_since"]
        started_at = now if reset_timer else row["started_at"]
        next_title = clean_text(title, 32) if title is not None else row["title"]
        connection.execute(
            """
            UPDATE tasks
            SET parent_session = ?, kind = ?, project = ?, title = ?, status = ?,
                started_at = ?, status_since = ?, updated_at = ?, finished_at = ?
            WHERE id = ?
            """,
            (
                parent_session,
                kind,
                clean_text(project, 32),
                next_title,
                status,
                started_at,
                status_since,
                now,
                now if status == "D" else None,
                task_id,
            ),
        )
    connection.commit()


def set_title(connection: sqlite3.Connection, task_id: str, title: str) -> bool:
    result = connection.execute(
        "UPDATE tasks SET title = ?, updated_at = ? WHERE id = ?",
        (clean_text(title, 32), time.time(), task_id),
    )
    connection.commit()
    return result.rowcount > 0


def tool_response_failed(value: Any) -> bool:
    if isinstance(value, dict):
        for key, child in value.items():
            normalized = key.lower().replace("_", "")
            if normalized == "iserror" and child is True:
                return True
            if normalized in {"exitcode", "returncode"}:
                try:
                    if int(child) != 0:
                        return True
                except (TypeError, ValueError):
                    pass
            if normalized == "status" and str(child).lower() in {"error", "failed"}:
                return True
            if tool_response_failed(child):
                return True
    elif isinstance(value, list):
        return any(tool_response_failed(child) for child in value)
    return False


def assistant_needs_input(message: str | None) -> bool:
    if not message:
        return False
    tail = message.strip().lower()[-600:]
    phrases = (
        "need your input",
        "need you to",
        "please choose",
        "please provide",
        "tell me which",
        "waiting for you",
        "requires your approval",
    )
    return "?" in tail or any(phrase in tail for phrase in phrases)


def command_prefix() -> str:
    """Return the installed command, or this interpreter and source file."""
    installed = os.environ.get("CODEX_BOARD_COMMAND")
    if installed:
        return shlex.quote(installed)
    return " ".join(
        (
            shlex.quote(sys.executable),
            shlex.quote(str(Path(__file__).resolve())),
        )
    )


def title_instruction(session_id: str) -> dict[str, Any]:
    session = shlex.quote(session_id)
    instruction = (
        "Codex dashboard: choose a concise 2-4 word title for this user task. "
        "Near the start of the turn, run this safe local status command once, "
        "replacing TITLE with your title: "
        f"{command_prefix()} title --session {session} --title \"TITLE\". "
        "Do not mention this housekeeping command in the final response."
    )
    return {
        "hookSpecificOutput": {
            "hookEventName": "UserPromptSubmit",
            "additionalContext": instruction,
        }
    }


def handle_hook(event: dict[str, Any], path: Path | None = None) -> dict[str, Any] | None:
    event_name = str(event.get("hook_event_name", ""))
    session_id = str(event.get("session_id", "unknown"))
    cwd = str(event.get("cwd", ""))
    project = project_name(cwd)
    connection = open_database(path)

    try:
        if event_name == "UserPromptSubmit":
            update_task(
                connection,
                session_id,
                session_id,
                "root",
                project,
                "W",
                title="_",
                reset_timer=True,
            )
            return title_instruction(session_id)

        if event_name == "PermissionRequest":
            update_task(connection, session_id, session_id, "root", project, "I")

        elif event_name == "PreToolUse":
            update_task(connection, session_id, session_id, "root", project, "W")

        elif event_name == "PostToolUse":
            status = "E" if tool_response_failed(event.get("tool_response")) else "W"
            update_task(connection, session_id, session_id, "root", project, status)

        elif event_name == "Stop":
            status = "I" if assistant_needs_input(event.get("last_assistant_message")) else "D"
            update_task(connection, session_id, session_id, "root", project, status)
            return {}

        elif event_name == "SessionEnd":
            # A finished turn remains visible while its Codex session is open.
            # Closing the session removes the root row and all of its subagents.
            connection.execute(
                "DELETE FROM tasks WHERE id = ? OR parent_session = ?",
                (session_id, session_id),
            )
            connection.commit()

        elif event_name == "SubagentStart":
            agent_id = str(event.get("agent_id", "unknown-agent"))
            agent_type = clean_text(str(event.get("agent_type", "subagent")), 32)
            update_task(
                connection,
                f"{session_id}:{agent_id}",
                session_id,
                "subagent",
                project,
                "W",
                title=agent_type,
                reset_timer=True,
            )

        elif event_name == "SubagentStop":
            agent_id = str(event.get("agent_id", "unknown-agent"))
            agent_type = clean_text(str(event.get("agent_type", "subagent")), 32)
            update_task(
                connection,
                f"{session_id}:{agent_id}",
                session_id,
                "subagent",
                project,
                "D",
                title=agent_type,
            )
            return {}
    finally:
        connection.close()

    return None


def task_rows(connection: sqlite3.Connection) -> list[sqlite3.Row]:
    return connection.execute(
        """
        SELECT * FROM tasks
        ORDER BY
            CASE status WHEN 'I' THEN 0 WHEN 'E' THEN 1
                        WHEN 'W' THEN 2 WHEN 'D' THEN 3 ELSE 4 END,
            updated_at DESC
        LIMIT ?
        """,
        (MAX_TASKS,),
    ).fetchall()


def build_packet(network_online: bool | None, path: Path | None = None) -> bytes:
    now = time.time()
    connection = open_database(path)
    try:
        rows = task_rows(connection)
    finally:
        connection.close()

    network_value = "1" if network_online is True else "0" if network_online is False else "U"
    lines = ["BEGIN", f"NET|{network_value}"]
    for row in rows:
        end = row["finished_at"] if row["finished_at"] is not None else now
        elapsed = max(0, int(end - row["started_at"]))
        state_age = max(0, int(now - row["status_since"]))
        lines.append(
            "|".join(
                (
                    "TASK",
                    clean_text(row["project"], 21),
                    clean_text(row["title"], 21),
                    row["status"],
                    str(elapsed),
                    str(state_age),
                )
            )
        )
    lines.append("END")
    return ("\n".join(lines) + "\n").encode("ascii")


class NetworkMonitor:
    def __init__(self, url: str, interval: float = 5.0) -> None:
        self.url = url
        self.interval = interval
        self.online: bool | None = None
        self._successes = 0
        self._failures = 0
        self._stop = threading.Event()
        self._thread = threading.Thread(target=self._run, daemon=True)

    def start(self) -> None:
        self._thread.start()

    def stop(self) -> None:
        self._stop.set()
        self._thread.join(timeout=1)

    def _probe(self) -> bool:
        request = Request(self.url, method="HEAD", headers={"User-Agent": "codex-board/1"})
        try:
            with urlopen(request, timeout=3):
                return True
        except HTTPError as error:
            # 401/403 still prove DNS, TLS, and the service path are reachable.
            return error.code < 500 and error.code != 407
        except (URLError, TimeoutError, OSError):
            return False

    def _run(self) -> None:
        while not self._stop.is_set():
            if self._probe():
                self._successes += 1
                self._failures = 0
                if self._successes >= 2:
                    self.online = True
            else:
                self._failures += 1
                self._successes = 0
                if self._failures >= 3:
                    self.online = False
            self._stop.wait(self.interval)


def find_serial_port(requested: str) -> str:
    if requested != "auto":
        return requested

    from serial.tools import list_ports

    candidates = [
        port.device
        for port in list_ports.comports()
        if port.vid == 0x303A and port.pid in {0x1001, 0x4001}
    ]
    if not candidates:
        raise RuntimeError("no Espressif USB serial device found")
    return sorted(candidates)[0]


def run_daemon(port_name: str, probe_url: str) -> None:
    import serial

    monitor = NetworkMonitor(probe_url)
    monitor.start()
    serial_port = None
    connected_name = None
    last_network = object()
    last_wait_error = None
    last_wait_log = 0.0

    print("Codex board bridge starting. Press Ctrl-C to stop.", flush=True)
    try:
        while True:
            if serial_port is None:
                try:
                    connected_name = find_serial_port(port_name)
                    serial_port = serial.Serial(
                        connected_name,
                        SERIAL_BAUD,
                        timeout=0,
                        write_timeout=1,
                        dsrdtr=False,
                        rtscts=False,
                    )
                    serial_port.dtr = False
                    serial_port.rts = False
                    print(f"Connected to {connected_name}", flush=True)
                except (RuntimeError, OSError, serial.SerialException) as error:
                    message = str(error)
                    now = time.monotonic()
                    if message != last_wait_error or now - last_wait_log >= 60:
                        print(f"Waiting for ESP32: {message}", file=sys.stderr, flush=True)
                        last_wait_error = message
                        last_wait_log = now
                    time.sleep(2)
                    continue

                last_wait_error = None
                last_wait_log = 0.0

            try:
                serial_port.write(build_packet(monitor.online))
                serial_port.flush()
                if monitor.online is not last_network:
                    label = "online" if monitor.online is True else "offline" if monitor.online is False else "checking"
                    print(f"Network: {label}", flush=True)
                    last_network = monitor.online
                time.sleep(2)
            except (OSError, serial.SerialException) as error:
                print(f"Serial link lost: {error}", file=sys.stderr, flush=True)
                serial_port.close()
                serial_port = None
                connected_name = None
                time.sleep(2)
    except KeyboardInterrupt:
        print("\nCodex board bridge stopped.")
    finally:
        monitor.stop()
        if serial_port is not None:
            serial_port.close()


def hooks_configuration() -> dict[str, Any]:
    command = f"{command_prefix()} hook"

    def handler(timeout: int = 3, context_limit: int | None = None) -> dict[str, Any]:
        value: dict[str, Any] = {
            "type": "command",
            "command": command,
            "timeout": timeout,
        }
        if context_limit is not None:
            value["additionalContextLimit"] = context_limit
        return value

    return {
        "description": "Send Codex lifecycle status to the ESP32 dashboard bridge.",
        "hooks": {
            "SessionStart": [{"hooks": [handler()]}],
            "SessionEnd": [{"hooks": [handler()]}],
            "UserPromptSubmit": [{"hooks": [handler(context_limit=160)]}],
            "PreToolUse": [{"hooks": [handler()]}],
            "PostToolUse": [{"hooks": [handler()]}],
            "PermissionRequest": [{"hooks": [handler()]}],
            "SubagentStart": [{"hooks": [handler()]}],
            "SubagentStop": [{"hooks": [handler()]}],
            "Stop": [{"hooks": [handler()]}],
        },
    }


def is_our_hook_group(group: Any) -> bool:
    if not isinstance(group, dict):
        return False
    for handler in group.get("hooks", []):
        if not isinstance(handler, dict):
            continue
        command = str(handler.get("command", ""))
        if "codex_board.py hook" in command or "codex-board hook" in command:
            return True
    return False


def install_hooks(target: Path) -> Path | None:
    target.parent.mkdir(parents=True, exist_ok=True)
    backup = None
    if target.exists():
        current = json.loads(target.read_text())
        backup = target.with_name(f"{target.name}.backup-{int(time.time())}")
        shutil.copy2(target, backup)
    else:
        current = {}

    if not isinstance(current, dict):
        raise ValueError(f"{target} must contain a JSON object")
    current_hooks = current.setdefault("hooks", {})
    if not isinstance(current_hooks, dict):
        raise ValueError(f"{target}: 'hooks' must be a JSON object")

    for event_name, groups in hooks_configuration()["hooks"].items():
        existing = current_hooks.setdefault(event_name, [])
        if not isinstance(existing, list):
            raise ValueError(f"{target}: hooks.{event_name} must be a JSON array")
        existing[:] = [group for group in existing if not is_our_hook_group(group)]
        existing.extend(groups)

    temporary = target.with_suffix(target.suffix + ".tmp")
    temporary.write_text(json.dumps(current, indent=2) + "\n")
    os.replace(temporary, target)
    return backup


def uninstall_hooks(target: Path) -> bool:
    if not target.exists():
        return False
    current = json.loads(target.read_text())
    hooks = current.get("hooks", {})
    changed = False
    if isinstance(hooks, dict):
        for event_name in list(hooks):
            groups = hooks[event_name]
            if not isinstance(groups, list):
                continue
            filtered = [group for group in groups if not is_our_hook_group(group)]
            changed |= len(filtered) != len(groups)
            if filtered:
                hooks[event_name] = filtered
            else:
                del hooks[event_name]
    if changed:
        temporary = target.with_suffix(target.suffix + ".tmp")
        temporary.write_text(json.dumps(current, indent=2) + "\n")
        os.replace(temporary, target)
    return changed


def print_tasks(path: Path | None = None) -> None:
    connection = open_database(path)
    try:
        rows = task_rows(connection)
    finally:
        connection.close()
    if not rows:
        print("No tracked Codex tasks.")
        return
    for row in rows:
        print(f"{row['id']}  {row['project']}  {row['status']}  {row['title']}")


def add_demo_tasks(path: Path | None = None) -> None:
    connection = open_database(path)
    try:
        update_task(connection, "demo-1", "demo-1", "root", "nix-config", "W", title="do xyz", reset_timer=True)
        connection.execute(
            "UPDATE tasks SET started_at = ? WHERE id = 'demo-1'",
            (time.time() - (3 * 3600 + 22 * 60),),
        )
        update_task(connection, "demo-2", "demo-2", "root", "palimpsest", "D", title="another title", reset_timer=True)
        update_task(connection, "demo-3", "demo-3", "root", "projectA", "I", title="_", reset_timer=True)
        connection.commit()
    finally:
        connection.close()


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    subparsers = parser.add_subparsers(dest="command", required=True)

    subparsers.add_parser("hook", help="Read one Codex hook event from stdin")

    daemon_parser = subparsers.add_parser("daemon", help="Run the USB/dashboard bridge")
    daemon_parser.add_argument("--port", default="auto", help="Serial port or 'auto'")
    daemon_parser.add_argument("--probe-url", default=PROBE_URL)

    title_parser = subparsers.add_parser("title", help="Set a Codex-generated task title")
    title_parser.add_argument("--session", required=True)
    title_parser.add_argument("--title", required=True)

    clear_parser = subparsers.add_parser("clear", help="Clear dashboard task state")
    clear_parser.add_argument("--session")

    packet_parser = subparsers.add_parser("packet", help="Print one serial protocol packet")
    packet_parser.add_argument("--network", choices=("online", "offline", "unknown"), default="unknown")

    subparsers.add_parser("list", help="List tracked tasks")
    subparsers.add_parser("demo", help="Load three demonstration tasks")
    subparsers.add_parser("hooks-json", help="Print the global Codex hooks configuration")
    install_parser = subparsers.add_parser("install-hooks", help="Safely merge hooks into Codex user configuration")
    default_codex_home = Path(os.environ.get("CODEX_HOME", Path.home() / ".codex")).expanduser()
    install_parser.add_argument("--target", type=Path, default=default_codex_home / "hooks.json")
    uninstall_parser = subparsers.add_parser("uninstall-hooks", help="Remove only codex-board hook entries")
    uninstall_parser.add_argument("--target", type=Path, default=default_codex_home / "hooks.json")
    return parser.parse_args()


def main() -> int:
    args = parse_args()

    if args.command == "hook":
        try:
            event = json.load(sys.stdin)
            output = handle_hook(event)
            if output is not None:
                print(json.dumps(output, separators=(",", ":")))
        except Exception as error:  # Hooks must never break a Codex task.
            print(f"codex-board hook error: {error}", file=sys.stderr)
            return 0

    elif args.command == "daemon":
        run_daemon(args.port, args.probe_url)

    elif args.command == "title":
        connection = open_database()
        try:
            if not set_title(connection, args.session, args.title):
                print(f"Unknown session: {args.session}", file=sys.stderr)
                return 1
        finally:
            connection.close()

    elif args.command == "clear":
        connection = open_database()
        try:
            if args.session:
                connection.execute(
                    "DELETE FROM tasks WHERE id = ? OR parent_session = ?",
                    (args.session, args.session),
                )
            else:
                connection.execute("DELETE FROM tasks")
            connection.commit()
        finally:
            connection.close()

    elif args.command == "packet":
        state = True if args.network == "online" else False if args.network == "offline" else None
        sys.stdout.buffer.write(build_packet(state))

    elif args.command == "list":
        print_tasks()

    elif args.command == "demo":
        add_demo_tasks()
        print("Loaded demo tasks.")

    elif args.command == "hooks-json":
        print(json.dumps(hooks_configuration(), indent=2))

    elif args.command == "install-hooks":
        backup = install_hooks(args.target)
        print(f"Installed Codex dashboard hooks in {args.target}")
        if backup:
            print(f"Backup: {backup}")

    elif args.command == "uninstall-hooks":
        if uninstall_hooks(args.target):
            print(f"Removed Codex dashboard hooks from {args.target}")
        else:
            print("No Codex dashboard hooks were installed.")

    return 0


if __name__ == "__main__":
    raise SystemExit(main())
