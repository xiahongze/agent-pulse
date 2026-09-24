import json
import sqlite3
import tempfile
import unittest
from datetime import datetime
from pathlib import Path
from src.agent_pulse import collect, load_config

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
            self.assertEqual(result["privacy"], "local-only")

    def test_defaults_bind_loopback(self):
        self.assertEqual(load_config(Path("/does/not/exist"))["host"], "127.0.0.1")

if __name__ == "__main__": unittest.main()

