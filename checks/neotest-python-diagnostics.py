"""Check the packaged adapter with Python 3.14+ and synthetic unittest failures.

python checks/neotest-python-diagnostics.py --adapter /path/to/neotest-python/neotest.py
"""

import argparse
import json
import os
from pathlib import Path
import subprocess
import sys
import tempfile


def check(adapter, python):
    with tempfile.TemporaryDirectory(prefix="neotest-diagnostics-") as directory:
        root = Path(directory)
        test_file = root / "test_example.py"
        test_file.write_text(
            "import unittest\n"
            "class Example(unittest.TestCase):\n"
            "    def test_failure(self):\n"
            '        self.assertEqual(False, True, "details α\\nsecond line")\n'
            "    def test_error(self):\n"
            '        raise ValueError("example error")\n'
            "    def test_pass(self):\n"
            "        self.assertTrue(True)\n"
            '    @unittest.skip("example skip")\n'
            "    def test_skip(self):\n"
            "        pass\n"
        )
        for color in (True, False):
            env = dict(os.environ, PYTHON_COLORS="1" if color else "0")
            env.pop("NO_COLOR", None)
            env.pop("FORCE_COLOR", None)
            results_file = root / "results.json"
            run = subprocess.run(
                [
                    python,
                    str(adapter),
                    "--results-file",
                    str(results_file),
                    "--stream-file",
                    str(root / "stream.json"),
                    "--runner",
                    "unittest",
                    "--",
                    str(test_file),
                ],
                cwd=root,
                env=env,
                capture_output=True,
                text=True,
                timeout=20,
            )
            assert run.returncode == 1, run.stderr
            assert ("\x1b[" in run.stderr) == color, "raw output colors changed"
            results = json.loads(results_file.read_text())

            def result(name):
                return results[f"{test_file}::Example::{name}"]

            for name, line, message in (
                ("test_failure", 3, "AssertionError: False != True : details α\nsecond line"),
                ("test_error", 5, "ValueError: example error"),
            ):
                value = result(name)
                assert value["status"] == "failed", value
                error = value["errors"][0]
                assert "\x1b" not in error["message"], "ANSI escapes leaked into diagnostic"
                assert error["line"] == line, error
                assert "Traceback" in error["message"], error
                assert message in error["message"], error
            assert result("test_pass")["status"] == "passed"
            assert result("test_skip")["status"] == "skipped"
            print(f"PASS: color={color}: clean diagnostics, original output, messages, locations, statuses")


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("--adapter", type=Path, required=True)
    parser.add_argument("--python", default=sys.executable)
    args = parser.parse_args()
    check(args.adapter.resolve(), args.python)
