"""Capture and operate a Hyprland desktop. All results are JSON."""

import argparse
from contextlib import contextmanager
import fcntl
import json
import math
import os
from pathlib import Path
import re
import struct
import subprocess
import sys
import tempfile
import time


def run(*args, input=None):
    result = subprocess.run(args, input=input, capture_output=True, timeout=15)
    if result.returncode:
        raise RuntimeError(
            f"{args[0]} failed: {result.stderr.decode(errors='replace').strip()}"
        )
    return result.stdout


def query(name):
    return json.loads(run("hyprctl", "-j", name))


def dispatch(name, argument):
    result = run("hyprctl", "dispatch", name, argument).decode().strip()
    if result != "ok":
        raise RuntimeError(f"Hyprland {name}: {result}")


def monitor_geometry(monitor):
    width, height = monitor["width"], monitor["height"]
    if monitor.get("transform", 0) % 2:
        width, height = height, width
    scale = monitor["scale"]
    return {
        "name": monitor["name"],
        "x": monitor["x"],
        "y": monitor["y"],
        "width": math.floor(width / scale),
        "height": math.floor(height / scale),
        "scale": scale,
        "transform": monitor.get("transform", 0),
    }


def get_monitor(name=None):
    monitors = query("monitors")
    matches = (
        [m for m in monitors if m["name"] == name]
        if name
        else [m for m in monitors if m.get("focused")]
    )
    if len(matches) != 1:
        raise RuntimeError(
            "Choose an active monitor with --monitor (see agent-desktop monitors)"
        )
    return monitor_geometry(matches[0])


def target_window(address):
    for window in query("clients"):
        if window["address"].lower() == address.lower() and window.get("mapped", True):
            return window
    raise RuntimeError("Target window no longer exists; refresh agent-desktop windows")


def assert_focus(address):
    if query("activewindow").get("address", "").lower() != address.lower():
        raise RuntimeError("Target window lost focus; input was not sent")


def focus(address):
    target_window(address)
    dispatch("focuswindow", f"address:{address}")
    for _ in range(20):
        if query("activewindow").get("address", "").lower() == address.lower():
            return
        time.sleep(0.05)
    raise RuntimeError("Could not focus target window")


def point(monitor, x, y):
    if not 0 <= x < monitor["width"] or not 0 <= y < monitor["height"]:
        raise RuntimeError(
            "Coordinates are outside the monitor's logical screenshot dimensions"
        )
    return monitor["x"] + x, monitor["y"] + y


def move_to_window(address, monitor, x, y):
    gx, gy = point(monitor, x, y)
    window = target_window(address)
    wx, wy = window["at"]
    ww, wh = window["size"]
    if not wx <= gx < wx + ww or not wy <= gy < wy + wh:
        raise RuntimeError("Coordinates are outside the target window")
    dispatch("movecursor", f"{gx} {gy}")
    time.sleep(0.1)
    assert_focus(address)
    return {"x": gx, "y": gy}


# Linux input keycodes: key shortcuts represent physical US-layout keys.
KEYS = dict(zip("qwertyuiop", range(16, 26)))
KEYS.update(zip("asdfghjkl", range(30, 39)))
KEYS.update(zip("zxcvbnm", range(44, 51)))
KEYS.update(zip("1234567890", range(2, 12)))
KEYS.update(
    {
        "ctrl": 29,
        "shift": 42,
        "alt": 56,
        "super": 125,
        "enter": 28,
        "tab": 15,
        "escape": 1,
        "backspace": 14,
        "space": 57,
        "left": 105,
        "right": 106,
        "up": 103,
        "down": 108,
        "home": 102,
        "end": 107,
        "pageup": 104,
        "pagedown": 109,
        "delete": 111,
        **{f"f{i}": 58 + i for i in range(1, 11)},
        "f11": 87,
        "f12": 88,
    }
)


def key_events(chord):
    names = chord.lower().split("+")
    if not names or len(names) != len(set(names)) or any(n not in KEYS for n in names):
        raise ValueError(
            "Unknown or repeated key; use physical US keys, e.g. ctrl+shift+p or enter"
        )
    codes = [KEYS[n] for n in names]
    return [f"{c}:1" for c in codes] + [f"{c}:0" for c in reversed(codes)]


def send_key(address, chord):
    events = key_events(chord)
    assert_focus(address)
    try:
        run("ydotool", "key", "--key-delay", "20", *events)
    except BaseException:
        # Release every potentially pressed key if the command was interrupted.
        try:
            run("ydotool", "key", *[e for e in events if e.endswith(":0")])
        except (OSError, RuntimeError, subprocess.TimeoutExpired):
            pass
        raise


@contextmanager
def desktop_lock():
    runtime = os.environ.get("XDG_RUNTIME_DIR")
    if not runtime or not os.environ.get("HYPRLAND_INSTANCE_SIGNATURE"):
        raise RuntimeError(
            "Run from the local Hyprland session with XDG_RUNTIME_DIR and HYPRLAND_INSTANCE_SIGNATURE"
        )
    directory = Path(runtime) / "agent-desktop"
    directory.mkdir(mode=0o700, exist_ok=True)
    with open(directory / "control.lock", "a+") as lock:
        try:
            fcntl.flock(lock, fcntl.LOCK_EX | fcntl.LOCK_NB)
        except BlockingIOError:
            raise RuntimeError(
                "Another agent-desktop command is running; retry when it finishes"
            ) from None
        yield directory


def screenshot(args, directory):
    monitor = get_monitor(args.monitor)
    if args.output:
        path = Path(args.output).absolute()
        # Exclusive creation avoids overwriting files or following output symlinks.
        fd = os.open(path, os.O_WRONLY | os.O_CREAT | os.O_EXCL, 0o600)
    else:
        fd, name = tempfile.mkstemp(prefix="screen-", suffix=".png", dir=directory)
        path = Path(name)
    try:
        # One PNG pixel per logical desktop coordinate, including scaled outputs.
        geometry = (
            f"{monitor['x']},{monitor['y']} {monitor['width']}x{monitor['height']}"
        )
        data = run("grim", "-s", "1", "-g", geometry, "-")
        if data[:8] != b"\x89PNG\r\n\x1a\n" or len(data) < 24:
            raise RuntimeError("Screenshot tool did not produce a PNG")
        width, height = struct.unpack(">II", data[16:24])
        if (width, height) != (monitor["width"], monitor["height"]):
            raise RuntimeError(
                "Screenshot dimensions differ from logical monitor coordinates"
            )
        with os.fdopen(fd, "wb") as output:
            fd = None
            output.write(data)
    except BaseException:
        if fd is not None:
            os.close(fd)
        path.unlink(missing_ok=True)
        raise
    return {
        "path": str(path),
        "monitor": monitor,
        "coordinate_space": "monitor-local logical pixels",
    }


def address(value):
    if not re.fullmatch(r"0x[0-9a-fA-F]+", value):
        raise argparse.ArgumentTypeError(
            "Use the hexadecimal address from agent-desktop windows"
        )
    return value


def parser():
    root = argparse.ArgumentParser(description=__doc__)
    commands = root.add_subparsers(dest="command", required=True)
    for name in ["windows", "monitors", "active"]:
        commands.add_parser(name)
    shot = commands.add_parser(
        "screenshot",
        help="Save a private PNG at logical resolution; return its path and monitor geometry",
    )
    shot.add_argument("--monitor")
    shot.add_argument(
        "--output", help="New output path; defaults to the session runtime directory"
    )
    for name in ["focus", "click", "scroll", "key", "type"]:
        command = commands.add_parser(name)
        command.add_argument("--window", required=True, type=address)
        if name in ["click", "scroll"]:
            command.add_argument("--monitor", required=True)
            command.add_argument("x", type=int)
            command.add_argument("y", type=int)
        if name == "click":
            command.add_argument(
                "--button", choices=["left", "middle", "right"], default="left"
            )
            command.add_argument("--count", type=int, choices=[1, 2], default=1)
        elif name == "scroll":
            command.add_argument("direction", choices=["up", "down", "left", "right"])
            command.add_argument("--steps", type=int, choices=range(1, 21), default=3)
        elif name == "key":
            command.add_argument(
                "chord", help="Physical US keys, e.g. ctrl+a, alt+tab, enter"
            )
        elif name == "type":
            command.add_argument(
                "--paste-key",
                default="ctrl+v",
                help="Paste shortcut (ctrl+shift+v for terminals)",
            )
            command.add_argument(
                "text",
                nargs="?",
                help="Unicode text; omit to read stdin. Replaces clipboard contents.",
            )
    return root


def execute(args, directory):
    if args.command == "windows":
        fields = [
            "address",
            "class",
            "title",
            "at",
            "size",
            "workspace",
            "monitor",
            "mapped",
        ]
        return [{k: w[k] for k in fields if k in w} for w in query("clients")]
    if args.command == "monitors":
        return [monitor_geometry(m) for m in query("monitors")]
    if args.command == "active":
        w = query("activewindow")
        return {k: w[k] for k in ["address", "class", "title"] if k in w}
    if args.command == "screenshot":
        return screenshot(args, directory)
    # Validate keyboard input before changing desktop state.
    if args.command == "key":
        key_events(args.chord)
    if args.command == "type":
        key_events(args.paste_key)
        text = args.text if args.text is not None else sys.stdin.read()
    focus(args.window)
    result = {"ok": True, "window": args.window, "action": args.command}
    if args.command in ["click", "scroll"]:
        result["cursor"] = move_to_window(
            args.window, get_monitor(args.monitor), args.x, args.y
        )
        if args.command == "click":
            button = {"left": "0xC0", "right": "0xC1", "middle": "0xC2"}[args.button]
            run("ydotool", "click", "--repeat", str(args.count), button)
        else:
            dx, dy = {"up": (0, 1), "down": (0, -1), "left": (-1, 0), "right": (1, 0)}[
                args.direction
            ]
            run(
                "ydotool",
                "mousemove",
                "--wheel",
                "--",
                str(dx * args.steps),
                str(dy * args.steps),
            )
    elif args.command == "key":
        send_key(args.window, args.chord)
    elif args.command == "type":
        assert_focus(args.window)
        run("wl-copy", "--type", "text/plain;charset=utf-8", input=text.encode())
        send_key(args.window, args.paste_key)
        result["clipboard_replaced"] = True
    return result


def main():
    args = parser().parse_args()
    os.umask(0o077)
    try:
        with desktop_lock() as directory:
            result = execute(args, directory)
        print(json.dumps(result, ensure_ascii=False))
        return 0
    except (OSError, RuntimeError, ValueError, subprocess.TimeoutExpired) as error:
        print(json.dumps({"error": str(error)}), file=sys.stderr)
        return 1


if __name__ == "__main__":
    sys.exit(main())
