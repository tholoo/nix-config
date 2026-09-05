import importlib.util
import os
from pathlib import Path
import tempfile
import unittest

spec = importlib.util.spec_from_file_location(
    "browser", Path(__file__).parents[1] / "agent_browser.py"
)
browser = importlib.util.module_from_spec(spec)
spec.loader.exec_module(browser)


class ProfileTests(unittest.TestCase):
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
