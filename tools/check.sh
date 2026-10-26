#!/usr/bin/env bash
# Headless import + one-frame boot of a game project; fails on script errors.
# Usage: tools/check.sh [<slug>|all]     (default: all)
set -uo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
GODOT="${GODOT:-/Applications/Godot.app/Contents/MacOS/Godot}"

if [[ ! -x "$GODOT" ]]; then
  echo "error: Godot binary not found at $GODOT (install Godot 4, or set \$GODOT)" >&2
  exit 1
fi

target="${1:-all}"
dirs=()
if [[ "$target" == "all" ]]; then
  for d in "$ROOT"/games/*/; do
    [[ -f "$d/project.godot" ]] && dirs+=("$d")
  done
else
  for d in "$ROOT"/games/*"$target"*/; do
    [[ -f "$d/project.godot" ]] && dirs+=("$d")
  done
  if [[ ${#dirs[@]} -eq 0 ]]; then
    echo "error: no game matching '$target' under games/" >&2
    exit 1
  fi
fi

fail=0
for d in "${dirs[@]}"; do
  game="$(basename "$d")"
  echo "== $game: import"
  out="$("$GODOT" --headless --path "$d" --import 2>&1)"
  echo "== $game: boot one frame"
  out+=$'\n'"$("$GODOT" --headless --path "$d" --quit 2>&1)"

  # Exit-time ObjectDB/resource diagnostics are known noise from plugins that
  # keep static refs (e.g. the AdMob loaders); they are not script errors.
  benign='resources still in use at exit|ObjectDB instances were leaked'
  errors="$(grep -E 'SCRIPT ERROR|Parse Error|ERROR:' <<<"$out" | grep -vE "$benign" || true)"
  warnings="$(grep -E 'SCRIPT WARNING|WARNING:' <<<"$out" | grep -vE "$benign" || true)"

  if [[ -n "$warnings" ]]; then
    echo "-- warnings:"
    echo "$warnings"
  fi
  if [[ -n "$errors" ]]; then
    echo "-- ERRORS:"
    echo "$errors"
    fail=1
  else
    echo "-- OK"
  fi
done

exit "$fail"
