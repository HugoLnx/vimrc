import importlib.util
import json
import os
import subprocess
import sys
import tempfile
import unittest
from datetime import datetime, timezone
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
SCRIPT = ROOT / "agentic" / "claude" / "statusline.py"
FIXTURES = Path(__file__).with_name("fixtures")
NOW = "1794398400"  # 2026-11-11 12:00 UTC
E = "\x1b"


def run(payload, cwd=None, codex_home=None, cache=None):
    env = os.environ.copy()
    with tempfile.TemporaryDirectory(prefix="codex-empty-") as empty:
        if cache is not None:
            (Path(empty) / "cache").mkdir()
            (Path(empty) / "cache" / "codex-usage.json").write_text(json.dumps(cache))
        env.update({"STATUSLINE_NOW": NOW, "TZ": "UTC", "CODEX_HOME": str(codex_home or empty),
                    "STATUSLINE_CODEX_REFRESH": "0", "STATUSLINE_CACHE_DIR": str(Path(empty) / "cache")})
        result = subprocess.run([sys.executable, str(SCRIPT)], input=json.dumps(payload).encode(),
                                stdout=subprocess.PIPE, stderr=subprocess.PIPE, cwd=cwd,
                                env=env, check=True)
    return result.stdout.decode()


def write_codex(home, line, name="rollout-x.jsonl"):
    folder = Path(home) / "sessions" / "2026" / "11" / "11"
    folder.mkdir(parents=True, exist_ok=True)
    (folder / name).write_text(line + "\n")


def codex_line(used, reset, minutes=10080):
    return json.dumps({"payload": {"rate_limits": {
        "primary": {"used_percent": 1.0, "window_minutes": 300, "resets_at": 1794416400},
        "secondary": {"used_percent": used, "window_minutes": minutes, "resets_at": reset}}}})


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
        self.assertIn("week:" + E + "[33m60%", weekday_to_weekend)
        self.assertIn("week:" + E + "[31m60%", weekend_to_weekday)
        self.assertNotIn("~", weekday_to_weekend)

    def test_codex_cache_beats_session_logs(self):
        claude = {"rate_limits": {"seven_day": {"used_percentage": 60, "resets_at": 1794657600}}}
        cache = {"used": 17, "resets_at": 1794657600, "fetched_at": int(NOW)}
        with tempfile.TemporaryDirectory() as home:
            write_codex(home, codex_line(94, 1794657600))
            self.assertIn("cdx" + E + "[36m17%", run(claude, codex_home=home, cache=cache))

    def test_codex_cache_lifetime_and_parsing(self):
        spec = importlib.util.spec_from_file_location("statusline", SCRIPT)
        module = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(module)
        now = datetime.fromtimestamp(int(NOW), timezone.utc)
        self.assertTrue(module.codex_cache_due(None, now))
        self.assertFalse(module.codex_cache_due({"fetched_at": int(NOW) - 59}, now))
        self.assertTrue(module.codex_cache_due({"fetched_at": int(NOW) - 60}, now))
        result = {"rateLimits": {"primary": {"usedPercent": 7, "windowDurationMins": 300, "resetsAt": 1},
                                 "secondary": {"usedPercent": 17, "windowDurationMins": 10080, "resetsAt": 1796143300}}}
        self.assertEqual(module.parse_codex_rate_limits(result), {"used": 17.0, "resets_at": 1796143300})
        self.assertIsNone(module.parse_codex_rate_limits({"rateLimits": {}}))

    def test_codex_week(self):
        claude = {"rate_limits": {"seven_day": {"used_percentage": 60, "resets_at": 1794657600}}}
        with tempfile.TemporaryDirectory() as home:
            write_codex(home, codex_line(60, 1794657600))
            self.assertIn("week:" + E + "[33m60%" + E + "[0m cdx" + E + "[33m60%", run(claude, codex_home=home))
        with tempfile.TemporaryDirectory() as home:
            write_codex(home, codex_line(94, 1794398000))  # stale: window already reset
            self.assertIn("cdx" + E + "[36m0%", run(claude, codex_home=home))
        with tempfile.TemporaryDirectory() as home:
            write_codex(home, codex_line(60, 1794657600))
            self.assertIn("week:-- cdx" + E + "[33m60%", run({}, codex_home=home))
        with tempfile.TemporaryDirectory() as home:
            write_codex(home, "not json \"rate_limits\"")
            write_codex(home, codex_line(60, 1794657600, minutes=300), name="rollout-y.jsonl")
            self.assertNotIn("cdx", run(claude, codex_home=home))


if __name__ == "__main__":
    unittest.main()
