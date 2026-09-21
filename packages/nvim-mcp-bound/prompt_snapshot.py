"""Bounded prompt context from one explicitly assigned Neovim socket."""

import argparse
import json
from pathlib import Path
import sys

from nvim_mcp.client import NvimClient

SNAPSHOT = Path(__file__).with_name("prompt_snapshot.lua").read_text()


def snapshot(address, max_bytes=24 * 1024, max_lines=400):
    if not Path(address).is_absolute():
        raise ValueError("The paired editor requires an absolute Unix socket path")
    if not 1024 <= max_bytes <= 128 * 1024 or not 20 <= max_lines <= 2000:
        raise ValueError("Snapshot budget is out of range")
    # No discovery and no retries. A later prompt may reconnect to this socket.
    with NvimClient.connect(address, timeout=0.75) as client:
        return client.exec_lua(SNAPSHOT, max_bytes, max_lines)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--socket", required=True)
    parser.add_argument("--max-bytes", type=int, default=24 * 1024)
    parser.add_argument("--max-lines", type=int, default=400)
    args = parser.parse_args()
    try:
        result = snapshot(args.socket, args.max_bytes, args.max_lines)
    except Exception:
        # Keep transport diagnostics and source text out of the terminal UI.
        print(json.dumps({"error": "Paired editor unavailable"}))
        return 1
    print(json.dumps(result, ensure_ascii=False))
    return 0


if __name__ == "__main__":
    sys.exit(main())
