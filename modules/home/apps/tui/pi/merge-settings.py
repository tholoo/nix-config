"""Atomically apply managed top-level Pi settings, retaining other preferences."""

import json
import os
from pathlib import Path
import sys
import tempfile


def merge_settings(managed_path, destination):
    managed = json.loads(Path(managed_path).read_text())
    destination = Path(destination)
    current = json.loads(destination.read_text()) if destination.exists() else {}
    if not isinstance(current, dict) or not isinstance(managed, dict):
        raise ValueError("Pi settings must be JSON objects")
    current.update(managed)
    destination.parent.mkdir(parents=True, exist_ok=True, mode=0o700)
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
