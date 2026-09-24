#!/usr/bin/env bash
set -euo pipefail
repo_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
install -Dm755 "$repo_dir/src/agent_pulse.py" "$HOME/.local/share/agent-pulse/agent_pulse.py"
install -Dm644 "$repo_dir/systemd/agent-pulse.service" "$HOME/.config/systemd/user/agent-pulse.service"
mkdir -p "$HOME/.config/agent-pulse"
if [[ ! -f "$HOME/.config/agent-pulse/config.json" ]]; then
  codex_path="$(command -v codex || true)"
  claude_path="$(command -v claude || true)"
  sed -e "s#\"codex\"#\"${codex_path:-codex}\"#" \
      -e "s#\"claude\"#\"${claude_path:-claude}\"#" \
      -e "s#~/#$HOME/#g" "$repo_dir/config.example.json" > "$HOME/.config/agent-pulse/config.json"
fi
systemctl --user daemon-reload
systemctl --user enable --now agent-pulse.service
if kpackagetool6 --type Plasma/Applet --show io.github.xiahongze.agentpulse >/dev/null 2>&1; then
  kpackagetool6 --type Plasma/Applet --upgrade "$repo_dir"
else
  kpackagetool6 --type Plasma/Applet --install "$repo_dir"
fi
echo "Installed Agent Pulse. Add it from Plasma's widget picker."
