"""Dispatch Helix's Yazi chooser; run all other shell commands with Nushell."""

import os
from pathlib import Path
import subprocess
import sys
import tempfile
import termios


def quote(value):
    # Helix single-quoted arguments escape quotes by doubling them. Their
    # contents are literal, including percent expansions and shell metacharacters.
    return "'" + value.replace("'", "''") + "'"


def choose(yazi, start, tty_path="/dev/tty"):
    with open(tty_path, "r+b", buffering=0) as tty:
        state = termios.tcgetattr(tty)
        try:
            with tempfile.TemporaryDirectory(prefix="helix-yazi-") as directory:
                chooser = Path(directory) / "selection"
                result = subprocess.run(
                    [yazi, "--chooser-file", str(chooser), "--", start],
                    stdin=tty,
                    stdout=tty,
                    stderr=tty,
                )
                if result.returncode:
                    return "echo " + quote(f"Yazi exited with status {result.returncode}")
                if not chooser.exists():
                    return "noop"
                paths = chooser.read_text().splitlines()
                if not paths:
                    return "noop"
                # Explicit positions avoid interpreting a numeric filename suffix
                # (e.g. report:2026) as Helix's optional :line[:column] syntax.
                return "open -- " + " ".join(quote(path + ":1:1") for path in paths)
        finally:
            termios.tcsetattr(tty, termios.TCSADRAIN, state)
            # Yazi leaves the alternate screen and disables bracketed paste on exit.
            tty.write(b"\x1b[?1049h\x1b[?2004h\x1b[?1000h\x1b[?1002h\x1b[?1003h\x1b[?1006h")


def dispatch(nushell, yazi, command):
    prefix = "helix-yazi "
    if not command.startswith(prefix):
        os.execv(nushell, [nushell, "-c", command])
    return choose(yazi, command[len(prefix):])


if __name__ == "__main__":
    try:
        command = dispatch(*sys.argv[1:])
    except (OSError, ValueError) as error:
        command = "echo " + quote(f"Yazi: {error}")
    print(command)
