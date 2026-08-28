import importlib.util
import json
import os
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch


MODULE_PATH = Path(__file__).with_name("codex_title.py")
SPEC = importlib.util.spec_from_file_location("codex_title", MODULE_PATH)
codex_title = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(codex_title)


class CodexTitleTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.root = Path(self.temp.name)

    def tearDown(self):
        self.temp.cleanup()

    def test_round_trip_and_json_record(self):
        written = codex_title.write_title("session-1", "  Fix\nshared   titles  ", self.root)
        self.assertEqual(written["title"], "Fix shared titles")
        self.assertEqual(
            set(written),
            {"schema", "session", "title", "updated_at"},
        )
        self.assertEqual(codex_title.read_title("session-1", self.root), written)
        self.assertEqual(codex_title.list_titles(self.root), [written])

    def test_sessions_use_private_hashed_files(self):
        codex_title.write_title("private-session-id", "Short title", self.root)
        files = list(self.root.glob("*.json"))
        self.assertEqual(len(files), 1)
        self.assertNotIn("private-session-id", files[0].name)
        self.assertEqual(files[0].stat().st_mode & 0o777, 0o600)

    def test_set_notifies_each_executable_sink(self):
        sinks = self.root / "sinks"
        sinks.mkdir()
        first = sinks / "10-first"
        second = sinks / "20-second"
        ignored = sinks / "README"
        for path in (first, second, ignored):
            path.write_text("")
        first.chmod(0o700)
        second.chmod(0o700)

        completed = codex_title.subprocess.CompletedProcess([], 0)
        with (
            patch.dict(os.environ, {"CODEX_TITLE_SINK_DIR": str(sinks)}),
            patch.object(codex_title.subprocess, "run", return_value=completed) as run,
        ):
            codex_title.notify_sinks("session-1", "Shared title")

        self.assertEqual(
            [call.args[0] for call in run.call_args_list],
            [
                [str(first), "--session", "session-1", "--title", "Shared title"],
                [str(second), "--session", "session-1", "--title", "Shared title"],
            ],
        )

    def test_hook_requests_the_generic_command(self):
        with patch.dict(os.environ, {"CODEX_TITLE_COMMAND": "/test/bin/codex-title"}):
            output = codex_title.hook_output(
                {
                    "hook_event_name": "UserPromptSubmit",
                    "session_id": "session-1",
                    "prompt": "private prompt content that must not be copied",
                }
            )
        context = output["hookSpecificOutput"]["additionalContext"]
        self.assertIn("/test/bin/codex-title set", context)
        self.assertIn("--session session-1", context)
        self.assertNotIn("breadboard", context.lower())
        self.assertNotIn("private prompt content", context)
        self.assertEqual(list(self.root.glob("*.json")), [])

    def test_clear_can_remove_one_or_all_titles(self):
        codex_title.write_title("session-1", "One", self.root)
        codex_title.write_title("session-2", "Two", self.root)
        codex_title.clear_title("session-1", self.root)
        self.assertIsNone(codex_title.read_title("session-1", self.root))
        self.assertIsNotNone(codex_title.read_title("session-2", self.root))
        codex_title.clear_title(root=self.root)
        self.assertEqual(codex_title.list_titles(self.root), [])

    def test_session_end_hook_removes_the_title(self):
        codex_title.write_title("session-1", "Transient title", self.root)
        output = codex_title.handle_hook(
            {"hook_event_name": "SessionEnd", "session_id": "session-1"},
            self.root,
        )
        self.assertEqual(output, {})
        self.assertIsNone(codex_title.read_title("session-1", self.root))


if __name__ == "__main__":
    unittest.main()
