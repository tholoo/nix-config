import argparse
import importlib.util
from pathlib import Path
import struct
import tempfile
import unittest
from unittest.mock import patch

spec = importlib.util.spec_from_file_location(
    "desktop", Path(__file__).parents[1] / "agent_desktop.py"
)
desktop = importlib.util.module_from_spec(spec)
spec.loader.exec_module(desktop)


class DesktopTests(unittest.TestCase):
    def test_scaled_rotated_monitor_with_negative_origin(self):
        m = desktop.monitor_geometry(
            {
                "name": "TEST",
                "width": 3840,
                "height": 2160,
                "scale": 2,
                "transform": 1,
                "x": -1080,
                "y": -200,
            }
        )
        self.assertEqual((m["width"], m["height"]), (1080, 1920))
        self.assertEqual(desktop.point(m, 100, 300), (-980, 100))
        for x, y in [(-1, 0), (1080, 0), (0, 1920)]:
            with self.assertRaises(RuntimeError):
                desktop.point(m, x, y)

    def test_click_outside_target_does_not_move_or_send_input(self):
        args = desktop.parser().parse_args(
            ["click", "--window", "0x1234", "--monitor", "TEST", "600", "600"]
        )
        with (
            patch.object(desktop, "focus"),
            patch.object(
                desktop,
                "get_monitor",
                return_value={"x": 0, "y": 0, "width": 1000, "height": 1000},
            ),
            patch.object(
                desktop,
                "target_window",
                return_value={"at": [0, 0], "size": [100, 100]},
            ),
            patch.object(desktop, "run") as run,
        ):
            with self.assertRaisesRegex(RuntimeError, "outside the target"):
                desktop.execute(args, Path("/unused"))
            run.assert_not_called()

    def test_focus_loss_after_mouse_move_prevents_click(self):
        args = desktop.parser().parse_args(
            ["click", "--window", "0x1234", "--monitor", "TEST", "20", "30"]
        )
        with (
            patch.object(desktop, "focus"),
            patch.object(
                desktop,
                "get_monitor",
                return_value={"x": 0, "y": 0, "width": 100, "height": 100},
            ),
            patch.object(
                desktop,
                "target_window",
                return_value={"at": [0, 0], "size": [100, 100]},
            ),
            patch.object(desktop, "dispatch"),
            patch.object(desktop, "query", return_value={"address": "0x9999"}),
            patch.object(desktop, "run") as run,
        ):
            with self.assertRaisesRegex(RuntimeError, "lost focus"):
                desktop.execute(args, Path("/unused"))
            run.assert_not_called()

    def test_unicode_paste_stays_out_of_output_and_command_arguments(self):
        text = "Bonjour — سلام $(echo nope)"
        args = desktop.parser().parse_args(["type", "--window", "0x1234", text])
        with (
            patch.object(desktop, "focus"),
            patch.object(desktop, "assert_focus"),
            patch.object(desktop, "send_key") as key,
            patch.object(desktop, "run") as run,
        ):
            result = desktop.execute(args, Path("/unused"))
            run.assert_called_once_with(
                "wl-copy", "--type", "text/plain;charset=utf-8", input=text.encode()
            )
            key.assert_called_once_with("0x1234", "ctrl+v")
            self.assertNotIn(text, str(result))

    def test_invalid_shortcut_fails_before_focus(self):
        args = desktop.parser().parse_args(
            ["key", "--window", "0x1234", "ctrl+unknown"]
        )
        with patch.object(desktop, "focus") as focus:
            with self.assertRaises(ValueError):
                desktop.execute(args, Path("/unused"))
            focus.assert_not_called()

    def test_failed_key_command_releases_keys(self):
        with (
            patch.object(desktop, "assert_focus"),
            patch.object(
                desktop, "run", side_effect=[RuntimeError("failed"), b""]
            ) as run,
        ):
            with self.assertRaises(RuntimeError):
                desktop.send_key("0x1234", "ctrl+a")
            self.assertEqual(run.call_args.args, ("ydotool", "key", "30:0", "29:0"))

    def test_screenshot_has_private_permissions_and_exact_coordinate_scale(self):
        m = {"name": "TEST", "x": -100, "y": 50, "width": 100, "height": 80}
        png = b"\x89PNG\r\n\x1a\n" + b"\x00" * 8 + struct.pack(">II", 100, 80)
        with (
            tempfile.TemporaryDirectory() as tmp,
            patch.object(desktop, "get_monitor", return_value=m),
            patch.object(desktop, "run", return_value=png) as run,
        ):
            result = desktop.screenshot(
                argparse.Namespace(monitor="TEST", output=None), Path(tmp)
            )
            path = Path(result["path"])
            self.assertEqual(path.read_bytes(), png)
            self.assertEqual(path.stat().st_mode & 0o777, 0o600)
            run.assert_called_once_with("grim", "-s", "1", "-g", "-100,50 100x80", "-")

    def test_screenshot_does_not_overwrite_existing_file(self):
        with (
            tempfile.TemporaryDirectory() as tmp,
            patch.object(desktop, "get_monitor", return_value={}),
        ):
            path = Path(tmp) / "existing"
            path.write_text("keep")
            with self.assertRaises(FileExistsError):
                desktop.screenshot(
                    argparse.Namespace(monitor="TEST", output=str(path)), Path(tmp)
                )
            self.assertEqual(path.read_text(), "keep")

    def test_bad_screenshot_is_removed(self):
        m = {"name": "TEST", "x": 0, "y": 0, "width": 100, "height": 80}
        with (
            tempfile.TemporaryDirectory() as tmp,
            patch.object(desktop, "get_monitor", return_value=m),
            patch.object(desktop, "run", return_value=b"not a png"),
        ):
            with self.assertRaises(RuntimeError):
                desktop.screenshot(
                    argparse.Namespace(monitor="TEST", output=None), Path(tmp)
                )
            self.assertEqual(list(Path(tmp).iterdir()), [])
