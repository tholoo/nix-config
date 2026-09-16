"""Exercise the desktop notifier without sending real notifications."""

import json
import os
from pathlib import Path
import subprocess
import tempfile
import unittest


SCRIPT = Path(__file__).with_name("notify.sh")
TITLE_PROMPT = "Generate a concise, single-line task title of at most 36 characters"


class NotifyTests(unittest.TestCase):
    def notify(self, payload, *, stdin=False):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            capture = root / "notifications"
            # Shell functions also intercept the packaged script, whose Nix
            # wrapper prepends the real notification binaries to PATH.
            stubs = root / "stubs.sh"
            stubs.write_text(
                'notify-send() { printf "%s\\n" "$@" >> "$NOTIFY_CAPTURE"; }\n'
                'dunstify() { printf "%s\\n" "$@" >> "$NOTIFY_CAPTURE"; }\n'
            )
            encoded = json.dumps(payload)
            subprocess.run(
                ["bash", str(SCRIPT)] + ([] if stdin else [encoded]),
                input=encoded if stdin else "",
                text=True,
                check=True,
                env=os.environ | {
                    "BASH_ENV": str(stubs),
                    "NOTIFY_CAPTURE": str(capture),
                    "CODEX_HOME": directory,
                },
            )
            return capture.read_text() if capture.exists() else ""

    def test_title_helper_is_silent(self):
        for stdin in (False, True):
            with self.subTest(stdin=stdin):
                self.assertEqual(self.notify({
                    "type": "agent-turn-complete",
                    "input-messages": [TITLE_PROMPT + " for this task: synthetic task"],
                    "last-assistant-message": "Synthetic task",
                }, stdin=stdin), "")

    def test_normal_completion_still_notifies(self):
        for messages in (None, [], ["Fix a bug"], ["Explain this prompt: " + TITLE_PROMPT]):
            with self.subTest(messages=messages):
                self.assertIn("Codex turn complete", self.notify({
                    "type": "agent-turn-complete",
                    "input-messages": messages,
                    "last-assistant-message": "Done",
                }))

    def test_approval_still_notifies(self):
        self.assertIn("Codex approval needed", self.notify({
            "type": "approval-requested",
            "input-messages": [TITLE_PROMPT],
        }))


if __name__ == "__main__":
    unittest.main()
