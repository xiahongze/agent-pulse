#!/usr/bin/env python3
"""Local-only metrics service for Agent Pulse. Uses Python's standard library."""
from __future__ import annotations

import argparse
import json
import os
import shutil
import sqlite3
from collections import defaultdict
from datetime import datetime, timedelta
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path
from typing import Any

DEFAULT_CONFIG = {
    "host": "127.0.0.1", "port": 42427,
    "codex_binary": shutil.which("codex") or str(Path.home() / ".bun/bin/codex"),
    "claude_binary": shutil.which("claude") or str(Path.home() / ".local/bin/claude"),
    "codex_home": str(Path.home() / ".codex"),
    "claude_home": str(Path.home() / ".claude"),
}


def load_config(path: Path | None = None) -> dict[str, Any]:
    config = dict(DEFAULT_CONFIG)
    path = path or Path(os.getenv("XDG_CONFIG_HOME", Path.home() / ".config")) / "agent-pulse/config.json"
    try:
        raw = json.loads(path.read_text())
        for key in config:
            if key in raw:
                config[key] = raw[key]
    except FileNotFoundError:
        pass
    return config


def codex_metrics(home: Path, today: datetime) -> tuple[dict[str, Any], dict[str, int]]:
    daily: dict[str, int] = defaultdict(int)
    sessions: dict[str, int] = defaultdict(int)
    db = home / "state_5.sqlite"
    if not db.exists():
        return provider("Codex", False), daily
    try:
        with sqlite3.connect(f"file:{db}?mode=ro", uri=True, timeout=2) as con:
            rows = con.execute("SELECT created_at, tokens_used FROM threads").fetchall()
    except sqlite3.Error as exc:
        return provider("Codex", False, f"History unavailable: {type(exc).__name__}"), daily
    for stamp, tokens in rows:
        dt = datetime.fromtimestamp(stamp)
        key = dt.date().isoformat()
        daily[key] += int(tokens or 0)
        sessions[key] += 1
    result = summarize("Codex", daily, sessions, today)
    result["source_updated"] = datetime.fromtimestamp(db.stat().st_mtime).astimezone().strftime("%d %b %H:%M")
    result["rate_windows"] = latest_codex_limits(home)
    if result["rate_windows"]:
        result["plan"] = result["rate_windows"][0].get("plan", "")
        for window in result["rate_windows"]:
            window.pop("plan", None)
    return result, daily


def latest_codex_limits(home: Path) -> list[dict[str, Any]]:
    """Read only the tail of recent rollouts; token_count events carry server-reported limits."""
    try:
        files = sorted((home / "sessions").glob("*/*/*/rollout-*.jsonl"), key=lambda p: p.stat().st_mtime, reverse=True)[:20]
    except OSError:
        return []
    newest: tuple[str, dict[str, Any]] | None = None
    for path in files:
        try:
            with path.open("rb") as stream:
                stream.seek(max(0, path.stat().st_size - 512_000))
                for raw in stream:
                    try:
                        event = json.loads(raw)
                        limits = event.get("payload", {}).get("rate_limits")
                        stamp = event.get("timestamp", "")
                        if limits and (newest is None or stamp > newest[0]):
                            newest = (stamp, limits)
                    except (ValueError, UnicodeDecodeError):
                        continue
        except OSError:
            continue
    if not newest:
        return []
    limits = newest[1]
    result = []
    for key in ("primary", "secondary", "individual_limit"):
        window = limits.get(key)
        if not isinstance(window, dict) or window.get("used_percent") is None:
            continue
        minutes = int(window.get("window_minutes") or 0)
        label = "5 HOUR" if minutes == 300 else "WEEKLY" if minutes == 10080 else f"{minutes // 60} HOUR"
        reset = datetime.fromtimestamp(int(window["resets_at"])).astimezone() if window.get("resets_at") else None
        result.append({"label": label, "used_percent": float(window["used_percent"]),
                       "reset_at": reset.strftime("%a %H:%M") if reset else "",
                       "plan": str(limits.get("plan_type") or "").upper()})
    return result


def claude_metrics(home: Path, today: datetime) -> tuple[dict[str, Any], dict[str, int]]:
    path = home / "stats-cache.json"
    daily: dict[str, int] = defaultdict(int)
    sessions: dict[str, int] = defaultdict(int)
    if not path.exists():
        return provider("Claude", False, "History file not found"), daily
    try:
        data = json.loads(path.read_text())
        for item in data.get("dailyModelTokens", []):
            daily[item["date"]] += sum(int(v or 0) for v in item.get("tokensByModel", {}).values())
        for item in data.get("dailyActivity", []):
            sessions[item["date"]] += int(item.get("sessionCount", 0))
    except (OSError, ValueError, TypeError, KeyError):
        return provider("Claude", False, "History file unreadable"), daily
    result = summarize("Claude", daily, sessions, today)
    result["source_updated"] = data.get("lastComputedDate") or datetime.fromtimestamp(path.stat().st_mtime).astimezone().strftime("%d %b %H:%M")
    return result, daily


def provider(name: str, available: bool, reason: str = "") -> dict[str, Any]:
    return {"name": name, "available": available, "tokens_today": 0, "tokens_7d": 0,
            "sessions_7d": 0, "rate_windows": [], "status_detail": reason}


def summarize(name: str, daily: dict[str, int], sessions: dict[str, int], today: datetime) -> dict[str, Any]:
    keys = [(today.date() - timedelta(days=i)).isoformat() for i in range(7)]
    out = provider(name, True)
    out.update(tokens_today=daily.get(keys[0], 0), tokens_7d=sum(daily.get(k, 0) for k in keys),
               sessions_7d=sum(sessions.get(k, 0) for k in keys))
    return out


def collect(config: dict[str, Any], now: datetime | None = None) -> dict[str, Any]:
    now = now or datetime.now().astimezone()
    codex, cdaily = codex_metrics(Path(config["codex_home"]), now)
    claude, adaily = claude_metrics(Path(config["claude_home"]), now)
    totals = []
    for offset in range(6, -1, -1):
        day = now.date() - timedelta(days=offset)
        key = day.isoformat()
        totals.append((day.strftime("%d"), cdaily.get(key, 0) + adaily.get(key, 0)))
    peak = max((v for _, v in totals), default=0) or 1
    return {"schema": 1, "generated_at": now.strftime("%H:%M:%S"), "providers": [codex, claude],
            "history": [{"label": label, "tokens": value, "ratio": value / peak} for label, value in totals],
            "privacy": "local-only", "quota_note": "Rate windows are included only when reported by local agent events."}


class Handler(BaseHTTPRequestHandler):
    config: dict[str, Any] = DEFAULT_CONFIG
    def do_GET(self) -> None:
        if self.path not in ("/v1/stats", "/health"):
            self.send_error(404); return
        body = json.dumps({"status": "ok"} if self.path == "/health" else collect(self.config)).encode()
        self.send_response(200); self.send_header("Content-Type", "application/json")
        self.send_header("Cache-Control", "no-store"); self.send_header("Access-Control-Allow-Origin", "*")
        self.send_header("Content-Length", str(len(body))); self.end_headers(); self.wfile.write(body)
    def log_message(self, fmt: str, *args: Any) -> None:
        return


def main() -> None:
    parser = argparse.ArgumentParser(description="Agent Pulse local metrics service")
    parser.add_argument("--config", type=Path); parser.add_argument("--once", action="store_true")
    args = parser.parse_args(); config = load_config(args.config)
    if args.once:
        print(json.dumps(collect(config), indent=2)); return
    Handler.config = config
    server = ThreadingHTTPServer((str(config["host"]), int(config["port"])), Handler)
    print(f"Agent Pulse listening on http://{config['host']}:{config['port']}")
    server.serve_forever()

if __name__ == "__main__":
    main()
