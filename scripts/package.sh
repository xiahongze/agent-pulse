#!/usr/bin/env bash
set -euo pipefail
repo_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
mkdir -p "$repo_dir/dist"
python3 - "$repo_dir" <<'PACKAGE'
import json, pathlib, sys, zipfile
root = pathlib.Path(sys.argv[1])
metadata = json.loads((root / "metadata.json").read_text())
for usage in (False, True):
    variant = json.loads(json.dumps(metadata))
    if usage:
        variant["KPlugin"].update({
            "Id": "io.github.xiahongze.agentpulse.usage",
            "Name": "Agent Pulse — Usage Stack",
            "Description": "Compact stacked agent usage on the taskbar with a click-open dashboard",
        })
    target = root / "dist" / ("agent-pulse-usage.plasmoid" if usage else "agent-pulse.plasmoid")
    with zipfile.ZipFile(target, "w", zipfile.ZIP_DEFLATED) as archive:
        archive.writestr("metadata.json", json.dumps(variant, ensure_ascii=False, indent=2) + "\n")
        for item in [root / "LICENSE", *(root / "contents").rglob("*")]:
            if item.is_file():
                archive.write(item, item.relative_to(root))
        archive.write(root / "src/agent_pulse.py", "contents/code/agent_pulse.py")
    print(target.relative_to(root))
PACKAGE
