import importlib.util
import json
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest

spec = importlib.util.spec_from_file_location("settings", Path(__file__).parents[1] / "merge-settings.py")
settings = importlib.util.module_from_spec(spec)
spec.loader.exec_module(settings)


class SettingsTests(unittest.TestCase):
    def test_migrates_empty_legacy_locks_without_changing_credentials(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            destination = root / "settings.json"
            destination.write_text("{}")
            auth = root / "auth.json"
            auth.write_text('{"synthetic":"credential-fixture"}')
            before = auth.read_bytes()
            for name in ("settings.json.lock", "auth.json.lock"):
                (root / name).touch()
            managed = root / "managed.json"
            managed.write_text("{}")
            settings.merge_settings(managed, destination)
            self.assertFalse((root / "settings.json.lock").exists())
            self.assertFalse((root / "auth.json.lock").exists())
            self.assertEqual(auth.read_bytes(), before)

    def test_preserves_directory_nonempty_and_symlink_locks(self):
        for kind in ("directory", "nonempty", "symlink"):
            with self.subTest(kind=kind), tempfile.TemporaryDirectory() as tmp:
                root = Path(tmp)
                lock = root / "auth.json.lock"
                if kind == "directory":
                    lock.mkdir()
                elif kind == "nonempty":
                    lock.write_text("unknown lock format")
                else:
                    target = root / "target"
                    target.touch()
                    lock.symlink_to(target)
                managed = root / "managed.json"
                managed.write_text("{}")
                settings.merge_settings(managed, root / "settings.json")
                self.assertTrue(lock.exists())

    def test_refuses_to_remove_a_held_legacy_lock(self):
        child = """
import fcntl, sys
with open(sys.argv[1], "w") as lock:
    getattr(fcntl, sys.argv[2])(lock, fcntl.LOCK_EX | fcntl.LOCK_NB)
    print("locked", flush=True)
    sys.stdin.read()
"""
        for method in ("flock", "lockf"):
            with self.subTest(method=method), tempfile.TemporaryDirectory() as tmp:
                root = Path(tmp)
                destination = root / "settings.json"
                destination.write_text('{"theme":"old"}')
                managed = root / "managed.json"
                managed.write_text('{"theme":"new"}')
                lock = root / "settings.json.lock"
                with subprocess.Popen(
                    [sys.executable, "-c", child, str(lock), method],
                    stdin=subprocess.PIPE, stdout=subprocess.PIPE, text=True,
                ) as held:
                    try:
                        self.assertEqual(held.stdout.readline().strip(), "locked")
                        with self.assertRaises(RuntimeError):
                            settings.merge_settings(managed, destination)
                        self.assertTrue(lock.exists())
                        self.assertEqual(destination.read_text(), '{"theme":"old"}')
                    finally:
                        held.communicate(timeout=5)

    def test_replaces_old_packages_and_scopes_preserving_other_preferences(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            old = root / "settings.json"
            old.write_text(json.dumps({"packages": ["npm:old"], "editorPaddingX": 3, "subagents": {"defaultProvider": "paid", "old": True}}))
            managed = root / "managed.json"
            managed.write_text(json.dumps({"packages": ["/nix/store/example"], "subagents": {"defaultProvider": "openai-codex"}}))
            settings.merge_settings(managed, old)
            result = json.loads(old.read_text())
            self.assertEqual(result["packages"], ["/nix/store/example"])
            self.assertEqual(result["editorPaddingX"], 3)
            self.assertEqual(result["subagents"], {"defaultProvider": "openai-codex"})
            self.assertEqual(old.stat().st_mode & 0o777, 0o600)

    def test_replaces_store_symlink_without_writing_its_target(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            target = root / "store.json"
            target.write_text('{"theme":"old"}')
            dest = root / "settings.json"
            dest.symlink_to(target)
            managed = root / "managed.json"
            managed.write_text('{"theme":"dark"}')
            settings.merge_settings(managed, dest)
            self.assertFalse(dest.is_symlink())
            self.assertEqual(target.read_text(), '{"theme":"old"}')
            self.assertEqual(json.loads(dest.read_text())["theme"], "dark")

    def test_invalid_existing_settings_are_preserved(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            dest = root / "settings.json"
            dest.write_text("broken json")
            managed = root / "managed.json"
            managed.write_text("{}")
            with self.assertRaises(ValueError):
                settings.merge_settings(managed, dest)
            self.assertEqual(dest.read_text(), "broken json")
