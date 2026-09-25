#!/usr/bin/env python3
"""One-shot local metrics collector for Agent Pulse. Uses Python's standard library."""
from __future__ import annotations

import argparse
import fcntl
import hashlib
import json
import os
import sqlite3
import tempfile
import time
import urllib.error
import urllib.request
from collections import defaultdict
from contextlib import closing
from datetime import datetime, timedelta
from pathlib import Path
from typing import Any

DEFAULT_CONFIG = {
    "codex_home": str(Path.home() / ".codex"),
    "claude_home": str(Path.home() / ".claude"),
    "claude_online_usage": True,
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
        with closing(sqlite3.connect(f"file:{db}?mode=ro", uri=True, timeout=2)) as con:
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
                        has_window = isinstance(limits, dict) and any(
                            isinstance(limits.get(key), dict) and limits[key].get("used_percent") is not None
                            for key in ("primary", "secondary", "individual_limit")
                        )
                        if has_window and (newest is None or stamp > newest[0]):
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


def claude_metrics(home: Path, today: datetime, online_usage: bool = True) -> tuple[dict[str, Any], dict[str, int]]:
    path = home / "stats-cache.json"
    daily: dict[str, int] = defaultdict(int)
    sessions: dict[str, int] = defaultdict(int)
    cache_date = None
    try:
        data = json.loads(path.read_text())
        cache_date = data.get("lastComputedDate")
        for item in data.get("dailyModelTokens", []):
            daily[item["date"]] += sum(int(v or 0) for v in item.get("tokensByModel", {}).values())
        for item in data.get("dailyActivity", []):
            sessions[item["date"]] += int(item.get("sessionCount", 0))
    except (OSError, ValueError, TypeError, KeyError):
        data = {}
    raw_daily, raw_sessions = recent_claude_sessions(home, today)
    for day, tokens in raw_daily.items():
        if cache_date is None or day > cache_date:
            daily[day] = tokens
            sessions[day] = raw_sessions.get(day, 0)
    if not data and not raw_daily:
        return provider("Claude", False, "History files unavailable"), daily
    result = summarize("Claude", daily, sessions, today)
    result["source_updated"] = max(raw_daily, default=cache_date or "")
    if online_usage:
        result["rate_windows"], result["usage_status"] = claude_usage(home)
    else:
        result["usage_status"] = "disabled"
    return result, daily


def claude_rate_windows(home: Path) -> list[dict[str, Any]]:
    """Return Claude windows, retaining this helper for existing callers."""
    return claude_usage(home)[0]


def claude_usage(home: Path) -> tuple[list[dict[str, Any]], str]:
    """Share successful windows and retry timing across one-shot collector runs."""
    cache_key = hashlib.sha256(str(home).encode()).hexdigest()[:16]
    cache_dir = Path(os.getenv("XDG_CACHE_HOME", Path.home() / ".cache")) / "agent-pulse" / cache_key
    try:
        cache_dir.mkdir(mode=0o700, parents=True, exist_ok=True)
        with (cache_dir / "claude-usage.lock").open("a+") as lock:
            fcntl.flock(lock, fcntl.LOCK_EX)
            cache_file = cache_dir / "claude-usage.json"
            try:
                cached = json.loads(cache_file.read_text())
            except (OSError, ValueError, TypeError):
                cached = {}
            now = time.time()
            windows = cached.get("windows", [])
            if not isinstance(windows, list):
                windows = []
            status = cached.get("status", "unavailable")
            try:
                next_attempt = float(cached.get("next_attempt_at", 0))
            except (TypeError, ValueError):
                next_attempt = 0
            if now < next_attempt:
                return windows, ("" if windows else "unavailable") if status == "current" else status
            try:
                credentials = json.loads((home / ".credentials.json").read_text())
                token = credentials["claudeAiOauth"]["accessToken"]
                request = urllib.request.Request(
                    "https://api.anthropic.com/api/oauth/usage",
                    headers={"Authorization": f"Bearer {token}", "Content-Type": "application/json",
                             "User-Agent": "agent-pulse/0.1"},
                )
                with urllib.request.urlopen(request, timeout=5) as response:
                    fetched = parse_claude_windows(json.load(response))
                cached = {"windows": fetched, "status": "current", "failures": 0,
                          "next_attempt_at": now + 300}
            except urllib.error.HTTPError as exc:
                try:
                    failures = min(int(cached.get("failures", 0)) + 1, 5)
                except (TypeError, ValueError):
                    failures = 1
                retry = min(3600, 120 * 2 ** (failures - 1)) if exc.code == 429 else 60
                if exc.code == 429:
                    try:
                        retry = max(retry, int(exc.headers.get("Retry-After", "0")))
                    except (AttributeError, TypeError, ValueError):
                        pass
                cached = {"windows": windows, "status": "rate_limited" if exc.code == 429 else "unavailable",
                          "failures": failures, "next_attempt_at": now + retry}
            except (OSError, KeyError, ValueError, TypeError, urllib.error.URLError):
                cached = {"windows": windows, "status": "unavailable", "failures": 0,
                          "next_attempt_at": now + 60}
            with tempfile.NamedTemporaryFile("w", dir=cache_dir, delete=False) as temporary:
                json.dump(cached, temporary)
                temporary_path = temporary.name
            os.replace(temporary_path, cache_file)
            status = cached["status"]
            return cached["windows"], ("" if cached["windows"] else "unavailable") if status == "current" else status
    except OSError:
        return [], "unavailable"


def parse_claude_windows(payload: dict[str, Any]) -> list[dict[str, Any]]:
    windows = []
    for limit in payload.get("limits", []):
        if limit.get("percent") is None:
            continue
        kind = str(limit.get("kind") or "")
        scope = limit.get("scope") or {}
        model = (scope.get("model") or {}).get("display_name")
        label = "5 HOUR" if kind == "session" else "WEEKLY" if kind == "weekly_all" else f"{model.upper()} WEEKLY" if model else kind.replace("_", " ").upper()
        reset_at = ""
        if limit.get("resets_at"):
            reset_at = datetime.fromisoformat(str(limit["resets_at"]).replace("Z", "+00:00")).astimezone().strftime("%a %H:%M")
        windows.append({"label": label, "used_percent": float(limit["percent"]),
                        "reset_at": reset_at, "severity": limit.get("severity", "normal")})
    return windows


def recent_claude_sessions(home: Path, today: datetime) -> tuple[dict[str, int], dict[str, int]]:
    """Aggregate recent assistant usage, deduplicating streamed records by message id."""
    cutoff = today.date() - timedelta(days=6)
    daily: dict[str, int] = defaultdict(int)
    session_days: dict[str, set[str]] = defaultdict(set)
    try:
        files = [p for p in (home / "projects").glob("*/*.jsonl")
                 if datetime.fromtimestamp(p.stat().st_mtime).date() >= cutoff]
    except OSError:
        return daily, {}
    for path in files:
        messages: dict[tuple[str, str], int] = {}
        try:
            with path.open(errors="ignore") as stream:
                for line in stream:
                    try:
                        event = json.loads(line)
                        if event.get("type") != "assistant":
                            continue
                        message = event.get("message") or {}
                        usage = message.get("usage") or {}
                        stamp = str(event.get("timestamp") or "")
                        day = datetime.fromisoformat(stamp.replace("Z", "+00:00")).astimezone().date()
                        if day < cutoff:
                            continue
                        message_id = str(message.get("id") or event.get("uuid") or "")
                        tokens = sum(int(usage.get(key, 0) or 0) for key in
                                     ("input_tokens", "output_tokens", "cache_creation_input_tokens", "cache_read_input_tokens"))
                        key = (day.isoformat(), message_id)
                        messages[key] = max(messages.get(key, 0), tokens)
                    except (ValueError, TypeError, AttributeError):
                        continue
        except OSError:
            continue
        for (day, _), tokens in messages.items():
            daily[day] += tokens
            session_days[day].add(path.name)
    return daily, {day: len(names) for day, names in session_days.items()}


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
    codex, cdaily = codex_metrics(Path(config["codex_home"]).expanduser(), now)
    claude, adaily = claude_metrics(Path(config["claude_home"]).expanduser(), now, bool(config.get("claude_online_usage", True)))
    totals = []
    for offset in range(6, -1, -1):
        day = now.date() - timedelta(days=offset)
        key = day.isoformat()
        totals.append((day.strftime("%d"), cdaily.get(key, 0) + adaily.get(key, 0)))
    peak = max((v for _, v in totals), default=0) or 1
    return {"schema": 1, "generated_at": now.strftime("%H:%M:%S"), "providers": [codex, claude],
            "history": [{"label": label, "tokens": value, "ratio": value / peak} for label, value in totals],
            "privacy": "local-history; provider usage lookup enabled" if config.get("claude_online_usage", True) else "local-only",
            "quota_note": "Rate windows are included only when reported by the providers."}


def main() -> None:
    parser = argparse.ArgumentParser(description="Agent Pulse local metrics collector")
    parser.add_argument("--config", type=Path)
    parser.add_argument("--once", action="store_true", help="retained for older callers")
    usage = parser.add_mutually_exclusive_group()
    usage.add_argument("--online", action="store_true", help="fetch Claude online usage")
    usage.add_argument("--offline", action="store_true", help="skip Claude online usage")
    parser.add_argument("--refresh-id", help="unique widget refresh identifier")
    args = parser.parse_args(); config = load_config(args.config)
    if args.online:
        config["claude_online_usage"] = True
    elif args.offline:
        config["claude_online_usage"] = False
    print(json.dumps(collect(config)))

if __name__ == "__main__":
    main()
