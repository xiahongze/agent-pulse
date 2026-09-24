import json
import sqlite3
import tempfile
import unittest
from unittest.mock import patch
from datetime import datetime
from pathlib import Path
import src.agent_pulse as agent_pulse
from src.agent_pulse import claude_rate_windows, collect, latest_codex_limits, load_config

class CollectorTests(unittest.TestCase):
    def test_collects_both_local_formats_without_content(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp); codex = root / "codex"; claude = root / "claude"; codex.mkdir(); claude.mkdir()
            con = sqlite3.connect(codex / "state_5.sqlite")
            con.execute("CREATE TABLE threads(created_at INTEGER, tokens_used INTEGER, archived INTEGER)")
            con.execute("INSERT INTO threads VALUES(?, 1200, 0)", (datetime(2026, 9, 24, 8).timestamp(),)); con.commit(); con.close()
            (claude / "stats-cache.json").write_text(json.dumps({"lastComputedDate":"2026-09-24","dailyModelTokens":[{"date":"2026-09-24","tokensByModel":{"sonnet":800}}],"dailyActivity":[{"date":"2026-09-24","sessionCount":2}]}))
            result = collect({"codex_home":str(codex),"claude_home":str(claude)}, datetime(2026,9,24,12))
            self.assertEqual(result["providers"][0]["tokens_today"], 1200)
            self.assertEqual(result["providers"][1]["tokens_today"], 800)
            self.assertEqual(result["history"][-1]["tokens"], 2000)
            self.assertEqual(result["privacy"], "local-history; provider usage lookup enabled")

    def test_defaults_bind_loopback(self):
        self.assertEqual(load_config(Path("/does/not/exist"))["host"], "127.0.0.1")

    def test_bad_codex_schema_isolated_from_claude(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp); codex = root / "codex"; claude = root / "claude"; codex.mkdir(); claude.mkdir()
            sqlite3.connect(codex / "state_5.sqlite").close()
            (claude / "stats-cache.json").write_text('{"dailyModelTokens":[],"dailyActivity":[]}')
            result = collect({"codex_home":str(codex),"claude_home":str(claude)}, datetime(2026,9,24,12))
            self.assertFalse(result["providers"][0]["available"])
            self.assertTrue(result["providers"][1]["available"])

    def test_reads_latest_codex_rate_windows(self):
        with tempfile.TemporaryDirectory() as tmp:
            home = Path(tmp); day = home / "sessions/2026/09/24"; day.mkdir(parents=True)
            payload = {"timestamp":"2026-09-24T01:30:00Z","payload":{"rate_limits":{"plan_type":"plus","primary":{"used_percent":12,"window_minutes":300,"resets_at":1790230000},"secondary":{"used_percent":34,"window_minutes":10080,"resets_at":1790816800}}}}
            unavailable = {"timestamp":"2026-09-24T01:31:00Z","payload":{"rate_limits":{"limit_id":"premium","primary":None,"secondary":None,"individual_limit":None}}}
            (day / "rollout-test.jsonl").write_text(json.dumps(payload) + "\n" + json.dumps(unavailable) + "\n")
            windows = latest_codex_limits(home)
            self.assertEqual([(w["label"], w["used_percent"]) for w in windows], [("5 HOUR", 12.0), ("WEEKLY", 34.0)])

    def test_claude_sessions_fill_stale_cache(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp); codex = root / "codex"; claude = root / "claude"; codex.mkdir(); claude.mkdir()
            con = sqlite3.connect(codex / "state_5.sqlite")
            con.execute("CREATE TABLE threads(created_at INTEGER, tokens_used INTEGER, archived INTEGER)"); con.close()
            (claude / "stats-cache.json").write_text('{"lastComputedDate":"2026-09-17","dailyModelTokens":[],"dailyActivity":[]}')
            project = claude / "projects/demo"; project.mkdir(parents=True)
            event = {"type":"assistant","timestamp":"2026-09-24T01:00:00Z","message":{"id":"msg-1","usage":{"input_tokens":100,"output_tokens":20,"cache_read_input_tokens":300}}}
            (project / "session.jsonl").write_text(json.dumps(event) + "\n" + json.dumps(event) + "\n")
            result = collect({"codex_home":str(codex),"claude_home":str(claude)}, datetime(2026,9,24,12))
            claude_result = result["providers"][1]
            self.assertEqual(claude_result["tokens_today"], 420)
            self.assertEqual(claude_result["sessions_7d"], 1)

    def test_claude_online_rate_windows(self):
        with tempfile.TemporaryDirectory() as tmp:
            home = Path(tmp)
            (home / ".credentials.json").write_text('{"claudeAiOauth":{"accessToken":"secret"}}')
            response = unittest.mock.MagicMock()
            response.__enter__.return_value = response
            response.__exit__.return_value = False
            payload = {"limits":[{"kind":"session","percent":42,"resets_at":"2026-09-24T02:30:00Z"},{"kind":"weekly_all","percent":17,"resets_at":"2026-09-25T08:00:00Z"}]}
            agent_pulse._CLAUDE_USAGE_CACHE = (0.0, [])
            with patch("src.agent_pulse.urllib.request.urlopen", return_value=response), patch("src.agent_pulse.json.load", return_value=payload):
                windows = claude_rate_windows(home)
            self.assertEqual([(w["label"], w["used_percent"]) for w in windows], [("5 HOUR", 42.0), ("WEEKLY", 17.0)])

if __name__ == "__main__": unittest.main()
