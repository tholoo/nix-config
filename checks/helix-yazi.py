"""Regression checks for the Helix/Yazi handoff, using synthetic selections."""

import importlib.util
import os
from pathlib import Path
import pty
import subprocess
import termios
import unittest
from unittest.mock import patch

SOURCE = Path(__file__).resolve().parents[1] / "modules/home/apps/tui/helix/yazi.py"
spec = importlib.util.spec_from_file_location("helix_yazi", SOURCE)
chooser = importlib.util.module_from_spec(spec)
spec.loader.exec_module(chooser)


class ChooserTests(unittest.TestCase):
    def setUp(self):
        self.master, self.slave = pty.openpty()
        self.tty = os.ttyname(self.slave)
        self.state = termios.tcgetattr(self.slave)
        self.directories = []

    def tearDown(self):
        os.close(self.master)
        os.close(self.slave)

    def run_chooser(self, selection=None, status=0, error=None):
        def yazi(argv, **kwargs):
            self.assertEqual(argv[0], "/test/yazi")
            self.assertEqual(argv[-2:], ["--", "/test/a 'quoted' %name.txt"])
            self.assertNotIn("shell", kwargs)
            self.assertIs(kwargs["stdin"], kwargs["stdout"])
            self.assertIs(kwargs["stdout"], kwargs["stderr"])
            path = Path(argv[2])
            self.assertEqual(path.parent.stat().st_mode & 0o777, 0o700)
            self.directories.append(path.parent)
            changed = termios.tcgetattr(self.slave)
            changed[3] ^= termios.ECHO
            termios.tcsetattr(self.slave, termios.TCSANOW, changed)
            if error:
                raise error
            if selection is not None:
                path.write_text(selection)
            return subprocess.CompletedProcess(argv, status)

        with patch.object(chooser.subprocess, "run", side_effect=yazi):
            try:
                return chooser.choose("/test/yazi", "/test/a 'quoted' %name.txt", self.tty)
            finally:
                self.assertEqual(termios.tcgetattr(self.slave), self.state)
                self.assertEqual(
                    os.read(self.master, 128),
                    b"\x1b[?1049h\x1b[?2004h\x1b[?1000h\x1b[?1002h\x1b[?1003h\x1b[?1006h",
                )
                self.assertTrue(all(not path.exists() for path in self.directories))

    def test_cancel_and_empty_selection_are_noops(self):
        self.assertEqual(self.run_chooser(), "noop")
        self.assertEqual(self.run_chooser(""), "noop")

    def test_multiple_paths_preserve_spaces_quotes_and_literal_expansions(self):
        self.assertEqual(
            self.run_chooser("/test/a b.txt\n/test/it's %sh{literal}.txt\n/test/report:2026\n"),
            "open -- '/test/a b.txt:1:1' '/test/it''s %sh{literal}.txt:1:1' '/test/report:2026:1:1'",
        )

    def test_failed_yazi_does_not_open_a_stale_selection(self):
        self.assertEqual(self.run_chooser("/test/stale\n", 2), "echo 'Yazi exited with status 2'")

    def test_launch_error_restores_terminal_and_removes_temporary_files(self):
        with self.assertRaises(FileNotFoundError):
            self.run_chooser(error=FileNotFoundError("missing executable"))

    def test_launches_use_distinct_chooser_files(self):
        self.run_chooser()
        self.run_chooser()
        self.assertNotEqual(*self.directories)

    def test_dispatch_passes_filename_literally(self):
        path = "/test/it's $(literal) %sh{literal}.txt"
        with patch.object(chooser, "choose", return_value="noop") as choose:
            self.assertEqual(chooser.dispatch("/test/nu", "/test/yazi", "helix-yazi " + path), "noop")
            choose.assert_called_once_with("/test/yazi", path)

    def test_other_shell_commands_keep_nushell_semantics(self):
        command = "[1 2 3] | math sum"
        with patch.object(chooser.os, "execv", side_effect=SystemExit) as execute:
            with self.assertRaises(SystemExit):
                chooser.dispatch("/test/nu", "/test/yazi", command)
            execute.assert_called_once_with("/test/nu", ["/test/nu", "-c", command])


if __name__ == "__main__":
    unittest.main()
