import json
import os
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
SCRIPT = ROOT / "agentic" / "claude" / "statusline.py"
FIXTURES = Path(__file__).with_name("fixtures")
NOW = "1794398400"  # 2026-11-11 12:00 UTC
E = "\x1b"


def run(payload, cwd=None):
    env = os.environ.copy()
    env.update({"STATUSLINE_NOW": NOW, "TZ": "UTC"})
    result = subprocess.run([sys.executable, str(SCRIPT)], input=json.dumps(payload).encode(),
                            stdout=subprocess.PIPE, stderr=subprocess.PIPE, cwd=cwd,
                            env=env, check=True)
    return result.stdout.decode()


class StatuslineTests(unittest.TestCase):
    def test_fixtures(self):
        for name in ("full", "no_context", "no_limits"):
            with self.subTest(name=name):
                payload = json.loads((FIXTURES / (name + ".json")).read_text())
                expected = (FIXTURES / (name + ".out")).read_text().rstrip("\n")
                self.assertEqual(run(payload), expected)

    def test_long_folder_and_non_git_directory(self):
        with tempfile.TemporaryDirectory(prefix="statusline-test-") as parent:
            directory = Path(parent) / "verylongfoldername"
            directory.mkdir()
            self.assertEqual(run({"workspace": {"current_dir": str(directory)}}),
                             "veryl..rname/ · ctx:--")

    def test_detached_head_uses_short_commit(self):
        with tempfile.TemporaryDirectory() as directory:
            subprocess.run(["git", "init", "-q", directory], check=True)
            subprocess.run(["git", "-C", directory, "config", "user.email", "test@example.invalid"], check=True)
            subprocess.run(["git", "-C", directory, "config", "user.name", "Test"], check=True)
            Path(directory, "a").write_text("a")
            subprocess.run(["git", "-C", directory, "add", "a"], check=True)
            subprocess.run(["git", "-C", directory, "commit", "-qm", "initial"], check=True)
            commit = subprocess.check_output(["git", "-C", directory, "rev-parse", "--short", "HEAD"]).decode().strip()
            subprocess.run(["git", "-C", directory, "checkout", "--detach", "-q"], check=True)
            self.assertEqual(run({"cwd": directory}), Path(directory).name + "/ [" + commit + "] · ctx:--")

    def test_ctx_and_percent_boundaries(self):
        # Ctx: <=80k cyan, 80k--<120k green, >=120k yellow, >250k red.
        cases = [(80000, 36), (80001, 32), (120000, 33), (250000, 33), (250001, 31)]
        for tokens, color in cases:
            with self.subTest(tokens=tokens):
                self.assertEqual(run({"context_window": {"total_input_tokens": tokens}}),
                                 "ctx:%s[%dm%sk%s[0m" % (E, color, round(tokens / 1000), E) if tokens >= 1000
                                 else "ctx:%s[%dm%d%s[0m" % (E, color, tokens, E))
        # Percent: <=25 cyan, 26--49 green, 50--84 yellow, >=85 red.
        for used, color in [(25, 36), (26, 32), (50, 33), (84, 33), (85, 31)]:
            with self.subTest(percent=used):
                result = run({"rate_limits": {"five_hour": {"used_percentage": used}}})
                self.assertEqual(result, "ctx:-- · 5h:%s[%dm%d%%%s[0m" % (E, color, used, E))

    def test_pace_boundaries(self):
        # With reset exactly 300 minutes away, used 0/5/10/30/31 produces
        # ratios 1.0, .95, .9, .7, .69 respectively; 1.25 needs reset 240 min away.
        cases = [(0, 1794416400, 32), (5, 1794416400, 33), (10, 1794416400, 33),
                 (30, 1794416400, 33),
                 (31, 1794416400, 31), (0, 1794412800, 36)]
        for used, reset, color in cases:
            with self.subTest(used=used, reset=reset):
                output = run({"rate_limits": {"five_hour": {"used_percentage": used, "resets_at": reset}}})
                self.assertIn("%s[%dm~" % (E, color), output)

    def test_weekly_work_minutes_cross_weekday_and_weekend(self):
        # Wed 09:00 BRT to Sat 09:00 BRT: 600 + 720 + 720 + 60 weighted min.
        # Wed 09:00 BRT to Mon 08:00 BRT: 600 + 720 + 720 + 360 + 360 + 60.
        weekday_to_weekend = run({"rate_limits": {"seven_day": {"used_percentage": 60, "resets_at": 1794657600}}})
        weekend_to_weekday = run({"rate_limits": {"seven_day": {"used_percentage": 60, "resets_at": 1794826800}}})
        self.assertIn(E + "[33m~14Nov", weekday_to_weekend)
        self.assertIn(E + "[31m~16Nov", weekend_to_weekday)


if __name__ == "__main__":
    unittest.main()
