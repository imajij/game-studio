#!/usr/bin/env bash
# Headless unit tests for a game's pure sim code (no GUT, no dependencies).
# Usage: tools/test.sh [<slug>|all]     (default: all)
#
# Games without a tests/run_tests.gd are skipped, not failed.
#
# NOTE ON EXIT CODES: the AdMob addon aborts the engine during headless
# teardown (SIGABRT / exit 134) in every game in this repo, long after the
# tests themselves have finished and printed. So pass/fail is read from the
# runner's own summary line rather than from Godot's exit status.
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
ran_any=0
for d in "${dirs[@]}"; do
  game="$(basename "$d")"
  if [[ ! -f "$d/tests/run_tests.gd" ]]; then
    continue
  fi
  ran_any=1
  echo "== $game: tests"

  # The global class_name cache must exist or every suite fails to parse.
  "$GODOT" --headless --path "$d" --import >/dev/null 2>&1

  out="$("$GODOT" --headless --path "$d" --script res://tests/run_tests.gd 2>&1)"
  echo "$out" | grep -vE 'Godot Engine|godotengine\.org|libc\+\+abi|recursive_mutex'

  summary="$(grep -oE '[0-9]+ checks, [0-9]+ failure\(s\)' <<<"$out" | tail -1)"
  if [[ -z "$summary" ]]; then
    echo "-- ERROR: the test runner produced no summary (did it crash before finishing?)"
    fail=1
    continue
  fi
  failures="$(sed -E 's/.*, ([0-9]+) failure\(s\)/\1/' <<<"$summary")"
  if [[ "$failures" != "0" ]]; then
    echo "-- FAILED: $summary"
    fail=1
  else
    echo "-- OK: $summary"
  fi
done

if [[ "$ran_any" == "0" ]]; then
  echo "no games with tests/run_tests.gd matched '$target'"
fi

exit "$fail"
