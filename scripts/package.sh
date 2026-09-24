#!/usr/bin/env bash
set -euo pipefail
repo_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
mkdir -p "$repo_dir/dist"
cd "$repo_dir"
zip -qr "dist/agent-pulse.plasmoid" metadata.json contents LICENSE
echo "dist/agent-pulse.plasmoid"

