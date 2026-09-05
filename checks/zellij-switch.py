#!/usr/bin/env python3
"""Exercise the real picker with isolated session, directory, and fzf fixtures."""

import json
import os
from pathlib import Path
import subprocess
import tempfile
import unittest


SCRIPT = Path(__file__).resolve().parents[1] / "modules/home/apps/tui/zellij/zellij-switch.nu"
STUB = r'''#!/usr/bin/env python3
import json
import os
from pathlib import Path
import sys

root = Path(os.environ["PICKER_TEST_ROOT"])
name = Path(sys.argv[0]).name
args = sys.argv[1:]
with (root / "calls").open("a") as log:
    log.write(json.dumps([name, *args]) + "\n")
if name == "zellij" and args[0] == "list-sessions":
    sessions = json.loads(os.environ["PICKER_TEST_SESSIONS"])
    for session in sessions:
        if "--short" in args or "-s" in args:
            print(session)
        else:
            current = " (current)" if session == os.environ.get("ZELLIJ_SESSION_NAME") else ""
            print(f"{session} [Created 1m ago]{current}")
elif name == "zellij" and os.environ.get("PICKER_TEST_SWITCH_FAIL"):
    print("switch failed", file=sys.stderr)
    sys.exit(1)
elif name == "zoxide":
    if os.environ.get("PICKER_TEST_ZOXIDE_EMPTY"):
        sys.exit(1)
    print(os.environ.get("PICKER_TEST_DIRECTORIES", ""))
elif name == "fzf":
    rows = sys.stdin.read().splitlines()
    (root / "rows").write_text(json.dumps(rows))
    target = os.environ.get("PICKER_TEST_SELECTION", "B")
    if target == "CANCEL":
        sys.exit(130)
    for row in rows:
        if target == "FIRST" or row.endswith("\t" + target):
            print(row)
            break
    else:
        sys.exit(1)
'''


class PickerTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(prefix="zellij-picker-test-")
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        bin_dir = self.root / "bin"
        bin_dir.mkdir()
        for name in ("zellij", "zoxide", "fzf"):
            executable = bin_dir / name
            executable.write_text(STUB)
            executable.chmod(0o755)
        self.cache = self.root / "cache"
        self.state = self.cache / "zellij" / "last-session"
        self.env = dict(os.environ)
        self.env.update(
            PATH=f"{bin_dir}:{os.environ['PATH']}",
            XDG_CACHE_HOME=str(self.cache),
            PICKER_TEST_ROOT=str(self.root),
            PICKER_TEST_SESSIONS=json.dumps(["A", "B"]),
            ZELLIJ="0",
            ZELLIJ_SESSION_NAME="A",
        )

    def run_picker(self, selection="B", current="A"):
        self.env["PICKER_TEST_SELECTION"] = selection
        self.env["ZELLIJ_SESSION_NAME"] = current
        result = subprocess.run(
            ["nu", "--no-config-file", str(SCRIPT)], env=self.env,
            text=True, capture_output=True, timeout=10,
        )
        self.assertEqual(result.returncode, 0, result.stderr)
        calls = [json.loads(line) for line in (self.root / "calls").read_text().splitlines()]
        return [call for call in calls if call[0] == "zellij" and call[1] != "list-sessions"]

    def test_switch_existing_session(self):
        self.assertEqual(self.run_picker(), [["zellij", "action", "switch-session", "B"]])
        self.assertEqual(self.state.read_text().strip(), "A")

    def test_previous_session_first_and_overwritten(self):
        self.run_picker()
        (self.root / "calls").unlink()
        self.assertEqual(self.run_picker("FIRST", "B"), [["zellij", "action", "switch-session", "A"]])
        self.assertEqual(self.state.read_text().strip(), "B")

    def test_directory_with_spaces(self):
        project = self.root / "project B"
        project.mkdir()
        self.env["PICKER_TEST_DIRECTORIES"] = str(project)
        self.assertEqual(self.run_picker(str(project)), [
            ["zellij", "action", "switch-session", "project_B", "--cwd", str(project)]
        ])

    def test_existing_directory_session_keeps_its_cwd(self):
        project = self.root / "B"
        project.mkdir()
        self.env["PICKER_TEST_DIRECTORIES"] = str(project)
        self.assertEqual(self.run_picker(str(project)), [["zellij", "action", "switch-session", "B"]])

    def test_cancel_does_not_change_state(self):
        self.state.parent.mkdir(parents=True)
        self.state.write_text("B")
        self.assertEqual(self.run_picker("CANCEL"), [])
        self.assertEqual(self.state.read_text(), "B")

    def test_exact_session_name(self):
        self.env["PICKER_TEST_SESSIONS"] = json.dumps(["A", "B.v2 [work]", "B.v2"])
        self.assertEqual(self.run_picker("B.v2 [work]"), [
            ["zellij", "action", "switch-session", "B.v2 [work]"]
        ])

    def test_stale_previous_session_is_not_offered(self):
        self.state.parent.mkdir(parents=True)
        self.state.write_text("deleted-session")
        self.run_picker()
        rows = json.loads((self.root / "rows").read_text())
        self.assertFalse(any("deleted-session" in row for row in rows))

    def test_current_session_is_not_offered(self):
        self.run_picker()
        rows = json.loads((self.root / "rows").read_text())
        self.assertFalse(any(row.endswith("\tA") for row in rows))

    def test_attach_outside_zellij(self):
        self.env.pop("ZELLIJ")
        self.assertEqual(self.run_picker(), [["zellij", "attach", "B", "--create"]])

    def test_create_directory_session_outside_zellij(self):
        self.env.pop("ZELLIJ")
        project = self.root / "project B"
        project.mkdir()
        self.env["PICKER_TEST_SESSIONS"] = "[]"
        self.env["PICKER_TEST_DIRECTORIES"] = str(project)
        self.assertEqual(self.run_picker(str(project)), [
            ["zellij", "attach", "project_B", "--create", "options", "--default-cwd", str(project)]
        ])

    def test_empty_zoxide_database(self):
        self.env["PICKER_TEST_ZOXIDE_EMPTY"] = "1"
        self.assertEqual(self.run_picker(), [["zellij", "action", "switch-session", "B"]])

    def test_no_other_sessions_or_directories(self):
        self.env["PICKER_TEST_SESSIONS"] = '["A"]'
        self.env["PICKER_TEST_ZOXIDE_EMPTY"] = "1"
        self.assertEqual(self.run_picker(), [])
        self.assertFalse(self.state.exists())

    def test_failed_switch_preserves_history(self):
        self.state.parent.mkdir(parents=True)
        self.state.write_text("B")
        self.env["PICKER_TEST_SWITCH_FAIL"] = "1"
        result = subprocess.run(
            ["nu", "--no-config-file", str(SCRIPT)], env=self.env,
            text=True, capture_output=True, timeout=10,
        )
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("switch failed", result.stderr)
        self.assertEqual(self.state.read_text(), "B")


if __name__ == "__main__":
    unittest.main()
