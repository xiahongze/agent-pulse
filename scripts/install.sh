#!/usr/bin/env bash
set -euo pipefail
repo_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
"$repo_dir/scripts/package.sh"
for variant in agent-pulse agent-pulse-usage; do
  plugin_id=io.github.xiahongze.agentpulse
  if [[ "$variant" == agent-pulse-usage ]]; then
    plugin_id+=.usage
  fi
  if kpackagetool6 --type Plasma/Applet --show "$plugin_id" >/dev/null 2>&1; then
    kpackagetool6 --type Plasma/Applet --upgrade "$repo_dir/dist/$variant.plasmoid"
  else
    kpackagetool6 --type Plasma/Applet --install "$repo_dir/dist/$variant.plasmoid"
  fi
done
if command -v kbuildsycoca6 >/dev/null 2>&1; then
  kbuildsycoca6 --noincremental >/dev/null
fi
echo "Installed Agent Pulse alternatives: Icon Only and Usage Stack."
