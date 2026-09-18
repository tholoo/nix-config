"""Atomically apply managed top-level Pi settings, retaining other preferences."""

import fcntl
import json
import os
from pathlib import Path
import stat
import sys
import tempfile


def remove_legacy_locks(agent_dir):
    """Pi's directory locks cannot replace old, empty file-based locks."""
    removed = []
    for name in ("settings.json.lock", "auth.json.lock"):
        path = Path(agent_dir) / name
        try:
            info = path.lstat()
        except FileNotFoundError:
            continue
        if not stat.S_ISREG(info.st_mode) or info.st_size != 0:
            continue
        try:
            fd = os.open(path, os.O_RDWR | os.O_NOFOLLOW | os.O_NONBLOCK)
        except FileNotFoundError:
            continue
        try:
            try:
                # Cover both flock and POSIX record locks used by older clients.
                fcntl.flock(fd, fcntl.LOCK_EX | fcntl.LOCK_NB)
                fcntl.lockf(fd, fcntl.LOCK_EX | fcntl.LOCK_NB)
            except BlockingIOError as error:
                raise RuntimeError(f"Pi lock is in use; close older Pi sessions: {path}") from error
            opened = os.fstat(fd)
            try:
                current = path.lstat()
            except FileNotFoundError:
                continue
            if (
                stat.S_ISREG(opened.st_mode)
                and opened.st_size == 0
                and (current.st_dev, current.st_ino) == (opened.st_dev, opened.st_ino)
            ):
                path.unlink()
                removed.append(name)
        finally:
            os.close(fd)
    return removed


def merge_settings(managed_path, destination):
    managed = json.loads(Path(managed_path).read_text())
    destination = Path(destination)
    current = json.loads(destination.read_text()) if destination.exists() else {}
    if not isinstance(current, dict) or not isinstance(managed, dict):
        raise ValueError("Pi settings must be JSON objects")
    current.update(managed)
    destination.parent.mkdir(parents=True, exist_ok=True, mode=0o700)
    remove_legacy_locks(destination.parent)
    fd, temporary = tempfile.mkstemp(prefix=".settings-", dir=destination.parent)
    try:
        with os.fdopen(fd, "w") as stream:
            json.dump(current, stream, indent=2)
            stream.write("\n")
        os.replace(temporary, destination)
    finally:
        Path(temporary).unlink(missing_ok=True)


if __name__ == "__main__":
    merge_settings(*sys.argv[1:])
