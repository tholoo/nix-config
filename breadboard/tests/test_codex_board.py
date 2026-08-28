import json
from pathlib import Path
import tempfile
import time
import unittest

from host import codex_board


class CodexBoardTests(unittest.TestCase):
    def setUp(self):
        self.temp_dir = tempfile.TemporaryDirectory()
        self.database = Path(self.temp_dir.name) / "test.sqlite3"

    def tearDown(self):
        self.temp_dir.cleanup()

    def event(self, name, **extra):
        value = {
            "hook_event_name": name,
            "session_id": "thread-1",
            "cwd": "/workspace/nix-config",
        }
        value.update(extra)
        return value

    def row(self, task_id="thread-1"):
        connection = codex_board.open_database(self.database)
        try:
            return connection.execute(
                "SELECT * FROM tasks WHERE id = ?", (task_id,)
            ).fetchone()
        finally:
            connection.close()

    def test_root_task_lifecycle(self):
        output = codex_board.handle_hook(
            self.event("UserPromptSubmit", prompt="Fix the flake setup"), self.database
        )
        self.assertEqual(self.row()["status"], "W")
        self.assertEqual(self.row()["project"], "nix-config")
        self.assertEqual(self.row()["title"], "_")
        self.assertIn("additionalContext", output["hookSpecificOutput"])

        connection = codex_board.open_database(self.database)
        try:
            self.assertTrue(codex_board.set_title(connection, "thread-1", "repair flake setup"))
        finally:
            connection.close()

        codex_board.handle_hook(self.event("PermissionRequest"), self.database)
        self.assertEqual(self.row()["status"], "I")

        output = codex_board.handle_hook(
            self.event("Stop", last_assistant_message="Finished successfully."),
            self.database,
        )
        self.assertEqual(output, {})
        self.assertEqual(self.row()["status"], "D")
        self.assertEqual(self.row()["title"], "repair flake setup")

    def test_question_at_stop_requires_input(self):
        codex_board.handle_hook(self.event("UserPromptSubmit"), self.database)
        codex_board.handle_hook(
            self.event("Stop", last_assistant_message="Which option should I use?"),
            self.database,
        )
        self.assertEqual(self.row()["status"], "I")

    def test_failed_tool_sets_error_and_success_clears_it(self):
        codex_board.handle_hook(self.event("UserPromptSubmit"), self.database)
        codex_board.handle_hook(
            self.event("PostToolUse", tool_response={"exit_code": 1}), self.database
        )
        self.assertEqual(self.row()["status"], "E")
        codex_board.handle_hook(
            self.event("PostToolUse", tool_response={"exit_code": 0}), self.database
        )
        self.assertEqual(self.row()["status"], "W")

    def test_subagent_is_tracked_separately(self):
        codex_board.handle_hook(
            self.event("SubagentStart", agent_id="agent-2", agent_type="research"),
            self.database,
        )
        self.assertEqual(self.row("thread-1:agent-2")["status"], "W")
        codex_board.handle_hook(
            self.event("SubagentStop", agent_id="agent-2", agent_type="research"),
            self.database,
        )
        self.assertEqual(self.row("thread-1:agent-2")["status"], "D")

    def test_session_end_removes_root_and_subagents(self):
        codex_board.handle_hook(self.event("UserPromptSubmit"), self.database)
        codex_board.handle_hook(
            self.event("SubagentStart", agent_id="agent-2", agent_type="research"),
            self.database,
        )
        codex_board.handle_hook(
            self.event("Stop", last_assistant_message="Finished successfully."),
            self.database,
        )
        self.assertEqual(self.row()["status"], "D")
        self.assertIsNotNone(self.row("thread-1:agent-2"))

        codex_board.handle_hook(self.event("SessionEnd"), self.database)
        self.assertIsNone(self.row())
        self.assertIsNone(self.row("thread-1:agent-2"))

    def test_packet_is_ascii_and_sanitized(self):
        codex_board.handle_hook(self.event("UserPromptSubmit"), self.database)
        connection = codex_board.open_database(self.database)
        try:
            codex_board.set_title(connection, "thread-1", "fix | unicode ✓")
        finally:
            connection.close()
        packet = codex_board.build_packet(True, self.database).decode("ascii")
        self.assertIn("NET|1", packet)
        self.assertIn("TASK|nix-config|fix unicode ?|W|", packet)
        self.assertTrue(packet.endswith("END\n"))

    def test_hooks_json_is_valid(self):
        rendered = json.dumps(codex_board.hooks_configuration())
        parsed = json.loads(rendered)
        self.assertIn("PermissionRequest", parsed["hooks"])
        self.assertIn("Stop", parsed["hooks"])

    def test_hook_installer_preserves_unrelated_hooks(self):
        target = Path(self.temp_dir.name) / "hooks.json"
        target.write_text(
            json.dumps(
                {
                    "hooks": {
                        "Stop": [
                            {
                                "hooks": [
                                    {"type": "command", "command": "python3 other.py"}
                                ]
                            }
                        ]
                    }
                }
            )
        )
        backup = codex_board.install_hooks(target)
        self.assertTrue(backup.exists())
        installed = json.loads(target.read_text())
        self.assertEqual(len(installed["hooks"]["Stop"]), 2)
        self.assertTrue(codex_board.uninstall_hooks(target))
        uninstalled = json.loads(target.read_text())
        self.assertEqual(len(uninstalled["hooks"]["Stop"]), 1)
        self.assertEqual(
            uninstalled["hooks"]["Stop"][0]["hooks"][0]["command"],
            "python3 other.py",
        )


if __name__ == "__main__":
    unittest.main()
