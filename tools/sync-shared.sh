#!/usr/bin/env bash
# Push shared/addons/studio_core into every game's addons/ folder (including
# _template). Shared code is edited ONLY in shared/ — synced copies are
# overwritten here. Game-specific plugins elsewhere in addons/ are untouched.
# Usage: tools/sync-shared.sh
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SRC="$ROOT/shared/addons/studio_core/"

count=0
for dir in "$ROOT"/games/*/; do
  [[ -f "$dir/project.godot" ]] || continue
  mkdir -p "$dir/addons"
  # *.uid / *.import are generated per game by Godot — keep theirs.
  rsync -a --delete --exclude='*.uid' --exclude='*.import' "$SRC" "$dir/addons/studio_core/"
  echo "synced $(basename "$dir")"
  count=$((count + 1))
done

echo "done: $count project(s)"
