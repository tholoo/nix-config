import json
from pathlib import Path
import tempfile
import time
import unittest
from unittest.mock import patch

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
        self.assertEqual(self.row()["title"], "Fix the flake setup")
        self.assertEqual(output, {})

        codex_board.handle_hook(self.event("PermissionRequest"), self.database)
        self.assertEqual(self.row()["status"], "I")

        output = codex_board.handle_hook(
            self.event("Stop", last_assistant_message="Finished successfully."),
            self.database,
        )
        self.assertEqual(output, {})
        self.assertEqual(self.row()["status"], "D")
        self.assertEqual(self.row()["title"], "Fix the flake setup")

    def test_question_at_stop_requires_input(self):
        codex_board.handle_hook(self.event("UserPromptSubmit"), self.database)
        codex_board.handle_hook(
            self.event("Stop", last_assistant_message="Which option should I use?"),
            self.database,
        )
        self.assertEqual(self.row()["status"], "I")

    def test_completed_task_is_acknowledged_when_session_is_revisited(self):
        codex_board.handle_hook(self.event("UserPromptSubmit"), self.database)
        codex_board.handle_hook(
            self.event("Stop", last_assistant_message="Finished successfully."),
            self.database,
        )
        self.assertEqual(self.row()["status"], "D")

        output = codex_board.handle_hook(self.event("SessionStart"), self.database)
        self.assertEqual(output, {})
        self.assertEqual(self.row()["status"], "A")

    def test_acknowledgement_does_not_clear_non_completed_state(self):
        codex_board.handle_hook(self.event("UserPromptSubmit"), self.database)
        connection = codex_board.open_database(self.database)
        try:
            self.assertFalse(codex_board.acknowledge_task(connection, "thread-1"))
        finally:
            connection.close()
        self.assertEqual(self.row()["status"], "W")

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

    def test_packet_only_includes_root_tasks(self):
        codex_board.handle_hook(self.event("UserPromptSubmit"), self.database)
        codex_board.handle_hook(
            self.event("SubagentStart", agent_id="agent-2", agent_type="research"),
            self.database,
        )
        codex_board.handle_hook(
            self.event("SubagentStop", agent_id="agent-2", agent_type="research"),
            self.database,
        )

        packet = codex_board.build_packet(self.database).decode("ascii")
        task_lines = [line for line in packet.splitlines() if line.startswith("TASK|")]
        self.assertEqual(len(task_lines), 1)
        self.assertIn("TASK|nix-config|_|W|", task_lines[0])

    def test_title_generation_helper_does_not_create_a_completed_root_task(self):
        helper_id = "title-helper"
        helper = {"session_id": helper_id, "model": "gpt-5.6-luna"}

        codex_board.handle_hook(
            self.event("SessionStart", **helper), self.database
        )
        codex_board.handle_hook(
            self.event(
                "UserPromptSubmit",
                **helper,
                prompt=(
                    "Generate a concise, single-line task title of at most 36 "
                    "characters and return JSON."
                ),
            ),
            self.database,
        )
        codex_board.handle_hook(
            self.event(
                "Stop",
                session_id=helper_id,
                last_assistant_message='{"title":"Generated by Codex"}',
            ),
            self.database,
        )

        packet = codex_board.build_packet(self.database).decode("ascii")
        task_lines = [line for line in packet.splitlines() if line.startswith("TASK|")]
        self.assertEqual(task_lines, [])

    def test_existing_completed_title_generation_helper_is_hidden(self):
        connection = codex_board.open_database(self.database)
        try:
            codex_board.update_task(
                connection,
                "old-title-helper",
                "old-title-helper",
                "root",
                "nix-config",
                "D",
                title=(
                    "Generate a concise, single-line task title of at most 36 "
                    "characters and return JSON."
                ),
            )
        finally:
            connection.close()

        packet = codex_board.build_packet(self.database).decode("ascii")
        task_lines = [line for line in packet.splitlines() if line.startswith("TASK|")]
        self.assertEqual(task_lines, [])

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
        self.assertEqual(self.row()["title"], "fix | unicode ✓")
        packet = codex_board.build_packet(self.database).decode("ascii")
        self.assertNotIn("NET|", packet)
        self.assertIn("USAGE|0|-1|0", packet)
        self.assertIn("TASK|nix-config|fix unicode ?|W|", packet)
        self.assertTrue(packet.endswith("END\n"))

    def test_usage_is_added_without_removing_task_records(self):
        codex_board.handle_hook(self.event("UserPromptSubmit"), self.database)
        usage = codex_board.UsageSnapshot(
            (
                codex_board.UsageLimit("5H", 75, 900),
                codex_board.UsageLimit("7D", 40, 10_000),
            ),
            10_000,
        )
        packet = codex_board.build_packet(
            self.database, usage, now=10_030
        ).decode("ascii")
        self.assertIn("USAGE|1|-1|30", packet)
        self.assertIn("LIMIT|5H|75|870", packet)
        self.assertIn("LIMIT|7D|40|9970", packet)
        self.assertIn("TASK|nix-config|_|W|", packet)

    def test_parses_remaining_usage(self):
        payload = {
            "rateLimits": {
                "limitId": "codex",
                "primary": {
                    "usedPercent": 25,
                    "windowDurationMins": 300,
                    "resetsAt": 10_900,
                },
                "secondary": {
                    "usedPercent": 60,
                    "windowDurationMins": 10_080,
                    "resetsAt": 20_000,
                },
            },
            "rateLimitsByLimitId": {},
        }
        self.assertEqual(
            codex_board.parse_rate_limits(payload, now=10_000),
            (
                codex_board.UsageLimit("5H", 75, 900),
                codex_board.UsageLimit("7D", 40, 10_000),
            ),
        )
    def test_spark_quota_does_not_fill_the_second_row(self):
        window = {
            "usedPercent": 25,
            "windowDurationMins": 300,
            "resetsAt": 10_900,
        }
        for limit_id, metadata in (
            ("gpt-5.3-codex-spark", {}),
            ("other", {"limitId": "gpt-5.3-codex-spark"}),
            ("other", {"limitName": "GPT-5.3-Codex-SPARK"}),
        ):
            with self.subTest(limit_id=limit_id, metadata=metadata):
                payload = {
                    "rateLimits": {"limitId": "codex", "primary": window},
                    "rateLimitsByLimitId": {
                        limit_id: {**metadata, "primary": window},
                    },
                }
                self.assertEqual(
                    codex_board.parse_rate_limits(payload, now=10_000),
                    (codex_board.UsageLimit("5H", 75, 900),),
                )
                payload["rateLimitsByLimitId"]["other-model"] = {
                    "limitName": "Other Model",
                    "primary": window,
                }
                self.assertEqual(
                    codex_board.parse_rate_limits(payload, now=10_000),
                    (
                        codex_board.UsageLimit("5H", 75, 900),
                        codex_board.UsageLimit("OTHER5H", 75, 900),
                    ),
                )

    def budget(self, remaining, elapsed=0, reset_at=7 * 86400):
        return codex_board.update_daily_budget(
            (codex_board.UsageLimit("7D", remaining, reset_at - elapsed),),
            elapsed,
            self.database,
        )

    def test_daily_allowance_carries_savings_and_spends_today_first(self):
        self.assertEqual(self.budget(100), codex_board.DailyBudget(14, 0, 86400))
        self.assertEqual(self.budget(93, 80000), codex_board.DailyBudget(7, 0, 86400))
        self.assertEqual(self.budget(93, 86400), codex_board.DailyBudget(14, 7, 172800))
        # Each call reopens the database, including across daemon restarts.
        self.assertEqual(self.budget(84, 90000), codex_board.DailyBudget(5, 7, 172800))
        self.assertEqual(self.budget(78, 91000), codex_board.DailyBudget(0, 6, 172800))
        self.assertEqual(self.budget(70, 92000), codex_board.DailyBudget(-1, 0, 172800))

    def test_deficit_is_visible_and_subtracted_from_tomorrows_allowance(self):
        self.assertEqual(
            self.budget(50, 2 * 86400),
            codex_board.DailyBudget(-7, 0, 3 * 86400),
        )
        self.assertEqual(
            self.budget(50, 3 * 86400),
            codex_board.DailyBudget(7, 0, 4 * 86400),
        )

    def test_deficit_carries_across_multiple_days_and_clears_at_weekly_reset(self):
        self.assertEqual(self.budget(0).today_percent, -85)
        self.assertEqual(self.budget(0, 86400).today_percent, -71)
        self.assertEqual(self.budget(0, 6 * 86400).today_percent, 0)
        self.assertEqual(
            self.budget(100, 7 * 86400, 14 * 86400),
            codex_board.DailyBudget(14, 0, 8 * 86400),
        )

    def test_negative_budget_is_sent_in_the_serial_packet(self):
        usage = codex_board.UsageSnapshot(
            (codex_board.UsageLimit("7D", 50, 5 * 86400),),
            2 * 86400,
            self.budget(50, 2 * 86400),
        )
        packet = codex_board.build_packet(self.database, usage, now=2 * 86400)
        self.assertIn(b"BUDGET|-7|0\n", packet)

    def test_overspending_reduces_the_next_allowance(self):
        self.budget(80, 80000)
        self.assertEqual(self.budget(80, 86400), codex_board.DailyBudget(8, 0, 172800))

    def test_initial_estimate_protects_future_days(self):
        self.assertEqual(self.budget(90, 86400), codex_board.DailyBudget(14, 4, 172800))

    def test_weekly_reset_discards_previous_savings(self):
        self.budget(100, 6 * 86400)
        reset_at = 14 * 86400
        self.assertEqual(
            self.budget(100, 7 * 86400, reset_at),
            codex_board.DailyBudget(14, 0, 8 * 86400),
        )

    def test_all_seven_allowances_preserve_fractional_remainders(self):
        for day in range(7):
            with self.subTest(day=day):
                result = self.budget(100, day * 86400)
                self.assertEqual(result.today_percent, 14)
                self.assertEqual(result.reserve_percent, (day * 100) // 7)
        # On the last day all remaining quota is available, with no lost
        # allowance from truncating 100/7 to 14 for display.
        self.assertEqual(self.budget(1, 6 * 86400 + 1).reserve_percent, 1)

    def test_offline_usage_is_charged_when_observed(self):
        self.budget(93, 80000)
        result = self.budget(70, 3 * 86400)
        self.assertEqual(result, codex_board.DailyBudget(0, 27, 4 * 86400))

    def test_missing_or_expired_weekly_quota_has_no_budget(self):
        for limits in (
            (),
            (codex_board.UsageLimit("5H", 100, 300),),
            (codex_board.UsageLimit("OTHER7D", 100, 300),),
            (codex_board.UsageLimit("7D", 100, 0),),
            (codex_board.UsageLimit("7D", 100, 7 * 86400 + 1),),
        ):
            with self.subTest(limits=limits):
                self.assertIsNone(codex_board.update_daily_budget(limits, 0, self.database))

    def test_budget_packet_expires_at_the_daily_boundary(self):
        usage = codex_board.UsageSnapshot(
            (codex_board.UsageLimit("7D", 84, 5 * 86400),),
            90000,
            codex_board.DailyBudget(5, 7, 172800),
        )
        packet = codex_board.build_packet(self.database, usage, now=90030)
        self.assertIn(b"BUDGET|5|7\n", packet)
        self.assertNotIn(b"BUDGET|", codex_board.build_packet(self.database, usage, now=172800))

    def test_budget_storage_failure_keeps_live_quota_available(self):
        monitor = codex_board.UsageMonitor()
        limits = (codex_board.UsageLimit("7D", 84, 5 * 86400),)
        with (
            patch.object(codex_board, "AppServerClient") as client,
            patch.object(codex_board, "parse_rate_limits", return_value=limits),
            patch.object(codex_board, "update_daily_budget", side_effect=OSError("storage unavailable")),
            patch.object(monitor._stop, "wait", side_effect=lambda _: monitor._stop.set()),
        ):
            monitor._run()
        snapshot, error = monitor.read()
        self.assertEqual(snapshot.limits, limits)
        self.assertIsNone(snapshot.budget)
        self.assertIn("Daily budget unavailable", error)
        client.return_value.request.assert_called_once_with("account/rateLimits/read")

    def test_spark_is_excluded_if_returned_as_the_main_quota(self):
        self.assertEqual(
            codex_board.parse_rate_limits(
                {
                    "rateLimits": {
                        "limitId": "codex-spark",
                        "primary": {
                            "usedPercent": 25,
                            "windowDurationMins": 300,
                            "resetsAt": 10_900,
                        },
                    },
                },
                now=10_000,
            ),
            (),
        )

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
