import importlib.util
import json
from pathlib import Path
import tempfile
import unittest

spec = importlib.util.spec_from_file_location("settings", Path(__file__).parents[1] / "merge-settings.py")
settings = importlib.util.module_from_spec(spec)
spec.loader.exec_module(settings)


class SettingsTests(unittest.TestCase):
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
