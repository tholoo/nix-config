#!/usr/bin/env python3
"""Check configured pane shortcuts in an isolated real Zellij PTY session.

Usage: python checks/zellij-layouts.py --config /path/to/generated/config.kdl
Never attaches to or changes the user's sessions.
"""

import argparse
import fcntl
import json
import os
import pty
import shutil
import struct
import subprocess
import tempfile
import termios
import threading
import time
from pathlib import Path


def wait_for(predicate, message):
    deadline = time.monotonic() + 15
    while time.monotonic() < deadline:
        try:
            value = predicate()
            if value:
                return value
        except (subprocess.SubprocessError, json.JSONDecodeError, KeyError):
            pass
        time.sleep(0.05)
    raise AssertionError(message)


def run(args):
    layouts = (
        Path(__file__).resolve().parents[1] / "modules/home/apps/tui/zellij/layouts"
    )
    generated = Path(args.config).read_text()
    # Test the actual generated bindings, without launching agent/browser plugins.
    keys = generated[generated.index("keybinds clear-defaults=true") :]
    with tempfile.TemporaryDirectory(prefix="zellij-layout-check-") as tmp:
        root = Path(tmp)
        config_dir = root / "config"
        config_dir.mkdir()
        shutil.copytree(layouts, config_dir / "layouts")
        config = config_dir / "config.kdl"
        config.write_text(
            "show_startup_tips false\nshow_release_notes false\nsession_serialization false\n"
            + "default_shell "
            + json.dumps(shutil.which("bash"))
            + "\n"
            + keys
        )
        runtime = root / "run"
        runtime.mkdir(mode=0o700)
        env = dict(os.environ)
        for key in list(env):
            if key.startswith(("ZELLIJ", "DEV_NVIM", "NVIM")):
                env.pop(key)
        env.update(
            HOME=str(root),
            XDG_RUNTIME_DIR=str(runtime),
            XDG_CONFIG_HOME=str(root),
            XDG_CACHE_HOME=str(root / "cache"),
            XDG_DATA_HOME=str(root / "data"),
            XDG_STATE_HOME=str(root / "state"),
            ZELLIJ_CONFIG_DIR=str(config_dir),
            TERM="xterm-256color",
        )
        session = "layout-fixture"

        def command(*argv, check=True):
            result = subprocess.run(
                [args.zellij, *argv],
                env=env,
                cwd=root,
                text=True,
                capture_output=True,
                timeout=10,
                check=False,
            )
            if check and result.returncode:
                raise subprocess.CalledProcessError(
                    result.returncode,
                    result.args,
                    output=result.stdout,
                    stderr=result.stderr,
                )
            return result

        def action(*argv):
            return command("--session", session, "action", *argv).stdout

        def panes():
            return [
                p
                for p in json.loads(action("list-panes", "--json", "--all"))
                if not p["is_plugin"]
            ]

        def pane(pane_id):
            return next(p for p in panes() if p["id"] == pane_id)

        def focus(pane_id):
            # Zellij returns an error for an already-focused target.
            if not pane(pane_id)["is_focused"]:
                action("focus-pane-id", str(pane_id))
            wait_for(lambda: pane(pane_id)["is_focused"], "pane did not focus")

        def press(key):
            os.write(master, b"\x1bp" + key.encode())

        def split(key):
            before = {p["id"] for p in panes()}
            press(key)
            new = wait_for(
                lambda: [p for p in panes() if p["id"] not in before],
                "split did not create a pane",
            )
            return new[0]["id"]

        def cycle_to_right_main():
            for _ in range(12):
                press("L")
                time.sleep(0.15)
                info = json.loads(action("current-tab-info", "--json"))
                if info["active_swap_layout_name"] == "right-main":
                    return
            raise AssertionError("right-main preset was not reachable with Alt+p L")

        def arrange_right_main(a, b, c):
            expected_ids = {a, b, c}
            cycle_to_right_main()
            assert {p["id"] for p in panes()} == expected_ids, "layout replaced panes"
            # Layout history affects slot assignment. Use the existing move-mode
            # bindings to put the chosen terminal on the right, then order the left.
            if pane(b)["pane_x"] == 0:
                focus(b)
                os.write(master, b"\x1bml\r")
                wait_for(lambda: pane(b)["pane_x"] > 0, "B did not move right")
            if pane(a)["pane_y"] > pane(c)["pane_y"]:
                focus(a)
                os.write(master, b"\x1bmk\r")
                wait_for(
                    lambda: pane(a)["pane_y"] < pane(c)["pane_y"], "A did not move up"
                )
            geometry = {p["id"]: p for p in panes()}
            assert set(geometry) == expected_ids, "move replaced panes"
            assert (
                geometry[a]["pane_x"] == geometry[c]["pane_x"] < geometry[b]["pane_x"]
            ), geometry
            assert geometry[a]["pane_y"] < geometry[c]["pane_y"], geometry
            assert (
                geometry[b]["pane_rows"]
                == geometry[a]["pane_rows"] + geometry[c]["pane_rows"]
            ), geometry

        # Parsing the real generated config is also safe: setup does not start plugins.
        command("--config", args.config, "setup", "--check")
        master, slave = pty.openpty()
        fcntl.ioctl(slave, termios.TIOCSWINSZ, struct.pack("HHHH", 40, 120, 0, 0))
        client = subprocess.Popen(
            [args.zellij, "--session", session],
            env=env,
            cwd=root,
            stdin=slave,
            stdout=slave,
            stderr=slave,
            start_new_session=True,
        )
        os.close(slave)

        def drain():
            try:
                while os.read(master, 65536):
                    pass
            except OSError:
                pass

        reader = threading.Thread(target=drain, daemon=True)
        reader.start()
        try:
            initial = wait_for(panes, "session did not start")
            assert len(initial) == 1, initial
            a = initial[0]["id"]
            b = split("l")
            assert pane(b)["pane_x"] > pane(a)["pane_x"], "l must split right"
            focus(b)
            left = split("h")
            wait_for(
                lambda: pane(left)["pane_x"] < pane(b)["pane_x"],
                "h must place new pane left",
            )
            focus(left)
            action("close-pane")
            wait_for(lambda: len(panes()) == 2, "fixture pane did not close")
            focus(b)
            above = split("k")
            wait_for(
                lambda: pane(above)["pane_y"] < pane(b)["pane_y"],
                "k must place new pane above",
            )
            focus(above)
            action("close-pane")
            wait_for(lambda: len(panes()) == 2, "fixture pane did not close")
            focus(b)
            action("close-pane")
            wait_for(lambda: len(panes()) == 1, "fixture reset failed")
            focus(a)
            c = split("j")
            assert pane(c)["pane_y"] > pane(a)["pane_y"], "j must split down"
            # From A/C, add B below C then apply right-main.
            b = split("j")
            expected_ids = {a, b, c}
            arrange_right_main(a, b, c)
            # A move marks the layout dirty: the first cycle can reapply it.
            press("H")
            time.sleep(0.15)
            press("H")
            wait_for(
                lambda: (
                    json.loads(action("current-tab-info", "--json"))[
                        "active_swap_layout_name"
                    ]
                    != "right-main"
                ),
                "H must select previous layout",
            )
            assert {p["id"] for p in panes()} == expected_ids
            # Reproduce the other starting shape: A|B over full-width C.
            for old in (b, c):
                focus(old)
                action("close-pane")
            wait_for(lambda: len(panes()) == 1, "second fixture reset failed")
            focus(a)
            c = split("j")
            focus(a)
            b = split("l")
            assert pane(a)["pane_y"] == pane(b)["pane_y"] < pane(c)["pane_y"]
            assert (
                pane(c)["pane_columns"]
                == pane(a)["pane_columns"] + pane(b)["pane_columns"]
            )
            arrange_right_main(a, b, c)
            print(
                "PASS: real hjkl and H/L bindings, both starting shapes, move-mode placement, and pane preservation"
            )
        finally:
            command("kill-session", session, check=False)
            try:
                client.wait(timeout=5)
            except subprocess.TimeoutExpired:
                client.kill()
                client.wait(timeout=5)
            os.close(master)
            reader.join(timeout=1)


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("--config", required=True)
    parser.add_argument("--zellij", default=shutil.which("zellij"))
    try:
        run(parser.parse_args())
    except subprocess.CalledProcessError as error:
        print(error.stdout or "")
        print(error.stderr or "")
        raise
