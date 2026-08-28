#!/usr/bin/env python3
"""Shared Codex session-title registry and hook."""

from __future__ import annotations

import argparse
import contextlib
import hashlib
import json
import os
from pathlib import Path
import re
import shlex
import subprocess
import sys
import tempfile
import time
from typing import Any


SCHEMA = 1
TITLE_LIMIT = 72
SESSION_LIMIT = 256
CONTROL = re.compile(r"[\x00-\x1f\x7f]")


def state_directory() -> Path:
    configured = os.environ.get("CODEX_TITLE_STATE_DIR")
    if configured:
        root = Path(configured).expanduser()
    else:
        runtime = Path(os.environ.get("XDG_RUNTIME_DIR", tempfile.gettempdir()))
        root = runtime / f"codex-titles-{os.getuid()}"
    root.mkdir(mode=0o700, parents=True, exist_ok=True)
    with contextlib.suppress(OSError):
        root.chmod(0o700)
    return root


def validate_session(session_id: str) -> str:
    if not session_id or len(session_id) > SESSION_LIMIT or CONTROL.search(session_id):
        raise ValueError("invalid Codex session ID")
    return session_id


def clean_title(value: Any) -> str:
    title = CONTROL.sub(" ", str(value or ""))
    return " ".join(title.split())[:TITLE_LIMIT] or "_"


def record_path(session_id: str, root: Path | None = None) -> Path:
    session_id = validate_session(session_id)
    digest = hashlib.sha256(session_id.encode()).hexdigest()
    return (root or state_directory()) / f"{digest}.json"


def read_title(session_id: str, root: Path | None = None) -> dict[str, Any] | None:
    session_id = validate_session(session_id)
    try:
        record = json.loads(record_path(session_id, root).read_text())
    except (OSError, TypeError, ValueError):
        return None
    if (
        not isinstance(record, dict)
        or record.get("schema") != SCHEMA
        or record.get("session") != session_id
        or not isinstance(record.get("title"), str)
        or not isinstance(record.get("updated_at"), int)
    ):
        return None
    return record


def write_title(session_id: str, title: str, root: Path | None = None) -> dict[str, Any]:
    session_id = validate_session(session_id)
    title = clean_title(title)
    directory = root or state_directory()
    directory.mkdir(mode=0o700, parents=True, exist_ok=True)
    record = {
        "schema": SCHEMA,
        "session": session_id,
        "title": title,
        "updated_at": int(time.time()),
    }
    target = record_path(session_id, directory)
    descriptor, temporary_name = tempfile.mkstemp(
        prefix=f".{target.stem}.", suffix=".tmp", dir=directory
    )
    temporary = Path(temporary_name)
    try:
        os.fchmod(descriptor, 0o600)
        with os.fdopen(descriptor, "w") as stream:
            stream.write(json.dumps(record, ensure_ascii=False, separators=(",", ":")))
        temporary.replace(target)
    except BaseException:
        with contextlib.suppress(OSError):
            os.close(descriptor)
        temporary.unlink(missing_ok=True)
        raise
    return record


def list_titles(root: Path | None = None) -> list[dict[str, Any]]:
    directory = root or state_directory()
    records = []
    for path in directory.glob("*.json"):
        try:
            candidate = json.loads(path.read_text())
        except (OSError, TypeError, ValueError):
            continue
        if not isinstance(candidate, dict) or not isinstance(candidate.get("session"), str):
            continue
        record = read_title(candidate["session"], directory)
        if record is not None:
            records.append(record)
    return sorted(records, key=lambda record: record["updated_at"], reverse=True)


def clear_title(session_id: str | None = None, root: Path | None = None) -> None:
    directory = root or state_directory()
    if session_id is not None:
        record_path(session_id, directory).unlink(missing_ok=True)
        return
    for path in directory.glob("*.json"):
        path.unlink(missing_ok=True)


def notify_sinks(session_id: str, title: str) -> None:
    configured = os.environ.get("CODEX_TITLE_SINK_DIR")
    if not configured:
        return
    directory = Path(configured)
    try:
        sinks = sorted(directory.iterdir())
    except OSError:
        return
    for sink in sinks:
        if not sink.is_file() or not os.access(sink, os.X_OK):
            continue
        with contextlib.suppress(OSError, subprocess.TimeoutExpired):
            subprocess.run(
                [str(sink), "--session", session_id, "--title", title],
                stdin=subprocess.DEVNULL,
                stdout=subprocess.DEVNULL,
                stderr=subprocess.DEVNULL,
                timeout=2,
                check=False,
            )


def command_prefix() -> str:
    installed = os.environ.get("CODEX_TITLE_COMMAND")
    if installed:
        return shlex.quote(installed)
    return " ".join(
        (
            shlex.quote(sys.executable),
            shlex.quote(str(Path(__file__).resolve())),
        )
    )


def hook_output(payload: dict[str, Any]) -> dict[str, Any] | None:
    if payload.get("hook_event_name") != "UserPromptSubmit":
        return None
    session_id = validate_session(str(payload.get("session_id", "")))
    session = shlex.quote(session_id)
    instruction = (
        "Codex session metadata: choose a concise 2-4 word title for this user task. "
        "Near the start of the turn, run this safe local metadata command once, "
        "replacing TITLE with your title: "
        f'{command_prefix()} set --session {session} --title "TITLE". '
        "Do not mention this housekeeping command in the final response."
    )
    return {
        "hookSpecificOutput": {
            "hookEventName": "UserPromptSubmit",
            "additionalContext": instruction,
        }
    }


def handle_hook(payload: dict[str, Any], root: Path | None = None) -> dict[str, Any] | None:
    if payload.get("hook_event_name") == "SessionEnd":
        clear_title(validate_session(str(payload.get("session_id", ""))), root)
        return {}
    return hook_output(payload)


def parser() -> argparse.ArgumentParser:
    result = argparse.ArgumentParser(prog="codex-title")
    subparsers = result.add_subparsers(dest="command", required=True)

    subparsers.add_parser("hook", help="Read a Codex hook event from stdin")

    setter = subparsers.add_parser("set", help="Store and publish a session title")
    setter.add_argument("--session", required=True)
    setter.add_argument("--title", required=True)

    getter = subparsers.add_parser("get", help="Read a session title")
    getter.add_argument("--session", required=True)
    getter.add_argument("--json", action="store_true")

    subparsers.add_parser("list", help="List session titles as JSON")

    clearer = subparsers.add_parser("clear", help="Remove one or all stored titles")
    clearer.add_argument("--session")
    return result


def main() -> int:
    args = parser().parse_args()
    if args.command == "hook":
        try:
            output = handle_hook(json.load(sys.stdin))
            if output is not None:
                print(json.dumps(output, separators=(",", ":")))
        except Exception as error:  # Metadata hooks must never block Codex.
            print(f"codex-title hook error: {error}", file=sys.stderr)
        return 0

    if args.command == "set":
        record = write_title(args.session, args.title)
        notify_sinks(record["session"], record["title"])
        return 0

    if args.command == "get":
        record = read_title(args.session)
        if record is None:
            return 1
        print(json.dumps(record, ensure_ascii=False) if args.json else record["title"])
        return 0

    if args.command == "list":
        print(json.dumps(list_titles(), ensure_ascii=False, separators=(",", ":")))
        return 0

    if args.command == "clear":
        clear_title(args.session)
        return 0

    return 2


if __name__ == "__main__":
    raise SystemExit(main())
