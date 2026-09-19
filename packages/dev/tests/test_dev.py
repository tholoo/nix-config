import importlib.util
import json
import os
import subprocess
import tempfile
import unittest
from pathlib import Path
from unittest.mock import patch

spec = importlib.util.spec_from_file_location(
    "dev", Path(__file__).parents[1] / "dev.py"
)
dev = importlib.util.module_from_spec(spec)
spec.loader.exec_module(dev)


class WorkspaceTests(unittest.TestCase):
    def test_git_subdirectory_symlink_and_worktrees(self):
        with tempfile.TemporaryDirectory() as tmp:
            base = Path(tmp)
            repo = base / 'repo with "quotes"'
            repo.mkdir()

            def git(*args):
                return subprocess.run(
                    ["git", "-C", str(repo), *args], check=True, capture_output=True
                )

            git("init", "--quiet")
            git(
                "-c",
                "user.name=Fixture",
                "-c",
                "user.email=fixture@example.invalid",
                "-c",
                "commit.gpgsign=false",
                "commit",
                "--quiet",
                "--allow-empty",
                "-m",
                "fixture",
            )
            (repo / "src").mkdir()
            linked = base / "alias"
            linked.symlink_to(repo)
            worktree = base / "other-worktree"
            git("worktree", "add", "--quiet", "-b", "fixture-other", str(worktree))
            self.assertEqual(dev.workspace_root(repo / "src"), repo)
            self.assertEqual(dev.workspace_root(linked), repo)
            self.assertNotEqual(
                dev.workspace_id(repo), dev.workspace_id(dev.workspace_root(worktree))
            )
            self.assertNotEqual(
                dev.workspace_id(base / "one" / "same"),
                dev.workspace_id(base / "two" / "same"),
            )
            self.assertEqual(dev.workspace_root(base), base)

    def test_runtime_is_private_and_bounded(self):
        with (
            tempfile.TemporaryDirectory() as tmp,
            patch.dict(os.environ, {"XDG_RUNTIME_DIR": tmp}),
        ):
            runtime = dev.runtime_dir(Path("/project/" + "long" * 100))
            self.assertEqual(runtime.stat().st_mode & 0o777, 0o700)
            self.assertLess(len(os.fsencode(dev.socket_path(runtime))), 108)
            dev.atomic_write(runtime / "layout", "fixture")
            self.assertEqual((runtime / "layout").stat().st_mode & 0o777, 0o600)

    def test_runtime_symlink_is_refused(self):
        with (
            tempfile.TemporaryDirectory() as tmp,
            patch.dict(os.environ, {"XDG_RUNTIME_DIR": tmp}),
        ):
            root = Path(tmp)
            (root / "elsewhere").mkdir()
            (root / "dev").symlink_to(root / "elsewhere")
            with self.assertRaises(ValueError):
                dev.runtime_dir(Path("/project"))

    def test_role_lock_prevents_duplicate(self):
        with (
            tempfile.TemporaryDirectory() as tmp,
            dev.lock(Path(tmp) / "editor.lock", blocking=False),
            self.assertRaises(BlockingIOError),
            dev.lock(Path(tmp) / "editor.lock", blocking=False),
        ):
            self.fail("acquired duplicate lock")

    def test_outside_zellij_fails_before_action(self):
        with (
            patch.dict(os.environ, {}, clear=True),
            patch.object(dev, "action") as action,
        ):
            with self.assertRaisesRegex(ValueError, "existing Zellij session"):
                dev.current_pane(dev.DEFAULT_CONFIG)
            action.assert_not_called()

    def test_resize_uses_explicit_editor_and_stops_at_60_percent(self):
        frames = [
            [
                {"id": 3, "is_plugin": False, "pane_columns": 50},
                {"id": 4, "is_plugin": False, "pane_columns": 50},
            ],
            [
                {"id": 3, "is_plugin": False, "pane_columns": 55},
                {"id": 4, "is_plugin": False, "pane_columns": 45},
            ],
            [
                {"id": 3, "is_plugin": False, "pane_columns": 60},
                {"id": 4, "is_plugin": False, "pane_columns": 40},
            ],
        ]
        with patch.object(
            dev,
            "action",
            side_effect=[
                json.dumps(frames[0]),
                "",
                json.dumps(frames[1]),
                "",
                json.dumps(frames[2]),
            ],
        ) as action:
            dev.resize_pair(dev.DEFAULT_CONFIG, 3, 4)
            mutations = [
                call.args[1:]
                for call in action.call_args_list
                if call.args[1] != "list-panes"
            ]
            self.assertEqual(
                mutations,
                [("resize", "increase", "right", "--pane-id", "terminal_3")] * 2,
            )

    def test_agent_uses_shell_environment_but_its_own_pane_identity(self):
        with (
            tempfile.TemporaryDirectory() as tmp,
            patch.dict(
                os.environ, {"ZELLIJ_PANE_ID": "8", "FIXTURE_ENV": "old-server"}
            ),
        ):
            runtime = Path(tmp)
            (runtime / "environment.json").write_text(
                json.dumps({"FIXTURE_ENV": "launching-shell", "ZELLIJ_PANE_ID": "3"})
            )
            with patch.object(dev, "run_pane_command", return_value=0) as run:
                dev.pane("agent", runtime, runtime, dev.DEFAULT_CONFIG)
                env = run.call_args.args[2]
                self.assertEqual(env["FIXTURE_ENV"], "launching-shell")
                self.assertEqual(env["ZELLIJ_PANE_ID"], "8")

    def test_pane_binds_environment_and_preserves_unrelated_values(self):
        with (
            tempfile.TemporaryDirectory() as tmp,
            patch.dict(
                os.environ,
                {
                    "DEV_NVIM_SOCKET": "/wrong",
                    "NVIM_ADDRESS": "/wrong",
                    "NVIM": "/wrong",
                    "FIXTURE_ENV": "kept",
                },
            ),
        ):
            runtime = Path(tmp) / "runtime"
            with patch.object(dev, "run_pane_command", return_value=0) as call:
                self.assertEqual(
                    dev.pane("agent", Path(tmp), runtime, dev.DEFAULT_CONFIG), 0
                )
                env = call.call_args.args[2]
                self.assertEqual(env["DEV_NVIM_SOCKET"], str(runtime / "nvim.sock"))
                self.assertEqual(env["NVIM_ADDRESS"], env["DEV_NVIM_SOCKET"])
                self.assertEqual(env["FIXTURE_ENV"], "kept")
                self.assertNotIn("NVIM", env)
                self.assertEqual(call.call_args.args[0], ["pi"])

    def test_editor_refuses_live_or_non_socket_path(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            (root / "nvim.sock").write_text("preserve")
            with self.assertRaises(ValueError):
                dev.pane("editor", root, root, dev.DEFAULT_CONFIG)
            self.assertEqual((root / "nvim.sock").read_text(), "preserve")
