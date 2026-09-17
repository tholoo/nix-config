"""Hand Helix's terminal to Yazi or Lazygit; forward other commands to Nushell."""

from contextlib import contextmanager
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


@contextmanager
def terminal(tty_path):
    with open(tty_path, "r+b", buffering=0) as tty:
        state = termios.tcgetattr(tty)
        try:
            yield tty
        finally:
            termios.tcsetattr(tty, termios.TCSADRAIN, state)
            # Restore Helix's alternate screen, bracketed paste and mouse reporting.
            tty.write(b"\x1b[?1049h\x1b[?2004h\x1b[?1000h\x1b[?1002h\x1b[?1003h\x1b[?1006h")


def choose(yazi, start, tty_path="/dev/tty"):
    with terminal(tty_path) as tty:
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


def git_ui(lazygit, start, tty_path="/dev/tty"):
    path = Path(start) if start else Path.cwd()
    directory = path if path.is_dir() else path.parent
    with terminal(tty_path) as tty:
        result = subprocess.run(
            [lazygit], cwd=directory, stdin=tty, stdout=tty, stderr=tty
        )
    if result.returncode:
        return "echo " + quote(f"Lazygit exited with status {result.returncode}")
    return "noop"


def dispatch(nushell, yazi, lazygit, command):
    name, _, argument = command.partition(" ")
    if name == "helix-yazi":
        return choose(yazi, argument)
    if name == "helix-lazygit":
        return git_ui(lazygit, argument)
    os.execv(nushell, [nushell, "-c", command])


if __name__ == "__main__":
    try:
        command = dispatch(*sys.argv[1:])
    except (OSError, ValueError) as error:
        command = "echo " + quote(f"Terminal handoff: {error}")
    print(command)
