import importlib.util
import os
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch

spec = importlib.util.spec_from_file_location(
    "browser", Path(__file__).parents[1] / "agent_browser.py"
)
browser = importlib.util.module_from_spec(spec)
spec.loader.exec_module(browser)


class ProfileTests(unittest.TestCase):
    def test_agent_namespaces_do_not_share_profiles(self):
        with tempfile.TemporaryDirectory() as tmp:
            captured = []

            def start(command, **kwargs):
                profile = Path(command[command.index("--user-data-dir") + 1])
                captured.append(profile)
                class Child:
                    def wait(self):
                        return 0
                return Child()

            with patch.dict(os.environ, {
                "XDG_STATE_HOME": tmp,
                "AGENT_BROWSER_MCP": "synthetic-mcp",
                "AGENT_BROWSER_CHROMIUM": "synthetic-chromium",
            }), patch.object(browser.subprocess, "Popen", side_effect=start), patch.object(browser.signal, "signal"):
                for args in (["agent-browser"], ["agent-browser", "--agent", "pi"]):
                    with patch.object(browser.sys, "argv", args):
                        self.assertEqual(browser.main(), 0)
            self.assertEqual(captured[0], Path(tmp) / "agent-browsers/codex/primary")
            self.assertEqual(captured[1], Path(tmp) / "agent-browsers/pi/primary")

    def test_namespace_rejects_path_traversal(self):
        for name in ("../escape", "/absolute", "", "a/b"):
            with self.subTest(name=name), patch.object(browser.sys, "argv", ["agent-browser", "--agent", name]), patch.object(browser.sys, "stderr"):
                with self.assertRaises(SystemExit) as result:
                    browser.main()
                self.assertEqual(result.exception.code, 2)

    def test_concurrent_sessions_get_distinct_profiles_and_reuse_state(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp) / "profiles"
            first, lock1 = browser.lease_profile(root)
            self.addCleanup(lock1.close)
            (first / "sentinel").write_text("persistent state")
            second, lock2 = browser.lease_profile(root)
            self.addCleanup(lock2.close)
            self.assertNotEqual(first, second)
            lock1.close()
            again, lock3 = browser.lease_profile(root)
            self.addCleanup(lock3.close)
            self.assertEqual(again, first)
            self.assertEqual((again / "sentinel").read_text(), "persistent state")
            self.assertEqual(root.stat().st_mode & 0o777, 0o700)
            self.assertEqual(again.stat().st_mode & 0o777, 0o700)

    def test_named_profile_fails_while_leased(self):
        with tempfile.TemporaryDirectory() as tmp:
            _, lock = browser.lease_profile(Path(tmp), "research")
            self.addCleanup(lock.close)
            with self.assertRaisesRegex(RuntimeError, "busy"):
                browser.lease_profile(Path(tmp), "research")

    def test_lease_prevents_reuse_in_another_process(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            _, lock = browser.lease_profile(root)
            self.addCleanup(lock.close)
            pid = os.fork()
            if pid == 0:
                # Drop the inherited descriptor; the parent retains the lease.
                lock.close()
                profile, child_lock = browser.lease_profile(root)
                (root / "selected").write_text(profile.name)
                child_lock.close()
                os._exit(0)
            _, status = os.waitpid(pid, 0)
            self.assertEqual(status, 0)
            self.assertEqual((root / "selected").read_text(), "parallel-1")
