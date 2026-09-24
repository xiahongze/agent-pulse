# Agent Pulse

A native Plasma 6 widget for private, at-a-glance Codex and Claude Code activity. Agent Pulse turns the local history those tools already keep into a restrained desktop dashboard—without uploading prompts, source code, or credentials.

![Plasma 6](https://img.shields.io/badge/Plasma-6-1d99f3) ![Python 3](https://img.shields.io/badge/Python-3.11%2B-3776ab) ![License](https://img.shields.io/badge/license-MIT-22c55e)

## What it shows

- Codex and Claude tokens today and over the last seven days
- Seven-day session counts and a combined activity chart
- Collector health, source freshness, last refresh, and auto-refresh cadence
- Server-reported Codex 5-hour and weekly usage percentages with reset times
- System, light, and dark appearances with Cyan, Violet, Amber, Nord, and Solarized accents
- Adjustable background opacity, defaulting to 50%

## Install on Plasma 6

```bash
git clone https://github.com/xiahongze/agent-usage-dashboard.git
cd agent-usage-dashboard
./scripts/install.sh
```

Then open Plasma's widget picker, search for **Agent Pulse**, and add it to the desktop or panel. The installer discovers the current `codex` and `claude` binaries, starts a user-level local service, and installs the plasmoid. Defaults are a 60-second UI refresh and a loopback-only endpoint at `127.0.0.1:42427`.

Configuration lives at `~/.config/agent-pulse/config.json`. The UI interval, theme, palette, and endpoint are available through the widget settings.

## Data accuracy and privacy

The top-level non-interactive commands do not directly print quota, but Codex records server-reported rate-limit snapshots in its local session events. Agent Pulse shows those 5-hour/weekly percentages and reset times, plus local history:

- Codex: rate windows from recent `token_count` events and aggregate history from `~/.codex/state_5.sqlite`
- Claude: aggregate daily model-token and activity values from `~/.claude/stats-cache.json`

For OAuth-based Claude accounts, Agent Pulse reads only the access token from `.credentials.json` and sends it to Anthropic's official HTTPS `/api/oauth/usage` endpoint—the same source as Claude Code's `/usage` screen. This supplies the 5-hour, weekly, and any model-scoped windows. The token is never returned by the local service, logged, or stored elsewhere. Set `claude_online_usage` to `false` to keep collection fully offline; history continues to work.

The collector never reads prompt/response fields, tool calls, or source content. Its local endpoint binds only to loopback. Upstream file schemas are not public contracts, so unavailable or changed data is omitted rather than guessed.

## Develop and package

```bash
make test
make lint
make package
```

The release artifact is `dist/agent-pulse.plasmoid`. The project intentionally uses a native QML/Kirigami frontend and a dependency-free Python collector for easy auditing and deployment.

## Uninstall

```bash
kpackagetool6 --type Plasma/Applet --remove io.github.xiahongze.agentpulse
systemctl --user disable --now agent-pulse.service
rm ~/.config/systemd/user/agent-pulse.service ~/.local/share/agent-pulse/agent_pulse.py
```
