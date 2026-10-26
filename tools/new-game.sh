#!/usr/bin/env bash
# Create games/NNN-<slug> from games/_template.
# Usage: tools/new-game.sh <slug> ["Display Name"]
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"

# shellcheck source=/dev/null
source "$ROOT/studio.cfg"
if [[ -z "${PACKAGE_PREFIX:-}" ]]; then
  echo "error: PACKAGE_PREFIX is empty — fill in studio.cfg first (e.g. com.mystudio)" >&2
  exit 1
fi

slug="${1:?usage: tools/new-game.sh <slug> [\"Display Name\"]}"
if [[ ! "$slug" =~ ^[a-z][a-z0-9-]*$ ]]; then
  echo "error: slug must be lowercase letters/digits/hyphens, starting with a letter" >&2
  exit 1
fi
name="${2:-$slug}"

if compgen -G "$ROOT/games/[0-9][0-9][0-9]-$slug" > /dev/null; then
  echo "error: a game with slug '$slug' already exists" >&2
  exit 1
fi

# Next number in creation order (001, 002, ...).
last="$(find "$ROOT/games" -maxdepth 1 -type d -name '[0-9][0-9][0-9]-*' \
  | sed -E 's|.*/([0-9]{3})-.*|\1|' | sort | tail -1)"
next="$(printf '%03d' $(( 10#${last:-0} + 1 )))"

dir="$ROOT/games/$next-$slug"
pkg="$PACKAGE_PREFIX.$(tr '-' '_' <<<"$slug")"   # Android package ids can't contain hyphens

rsync -a --exclude='.godot' "$ROOT/games/_template/" "$dir/"

sed -i '' "s|config/name=\"_template\"|config/name=\"$name\"|" "$dir/project.godot"
sed -i '' "s|package/unique_name=\"com.example.template\"|package/unique_name=\"$pkg\"|" "$dir/export_presets.cfg"
sed -i '' "s|package/name=\"_template\"|package/name=\"$name\"|" "$dir/export_presets.cfg"
sed -i '' "s|# GAME: _template|# GAME: $name|" "$dir/GAME.md"

mkdir -p "$ROOT/marketing/$slug"

# Install the Android gradle build template (needed by the AdMob plugin's
# gradle builds; android/build is gitignored). Matches the installed Godot.
GODOT_BIN="${GODOT:-/Applications/Godot.app/Contents/MacOS/Godot}"
if [[ -x "$GODOT_BIN" ]]; then
  gd_ver="$("$GODOT_BIN" --version | sed -E 's/^([0-9]+\.[0-9]+\.[0-9]+\.[a-z]+).*/\1/')"
  src_zip="$HOME/Library/Application Support/Godot/export_templates/$gd_ver/android_source.zip"
  if [[ -f "$src_zip" ]]; then
    mkdir -p "$dir/android/build"
    unzip -qo "$src_zip" -d "$dir/android/build"
    echo "$gd_ver" > "$dir/android/.build_version"
    touch "$dir/android/.gdignore"
    echo "installed Android build template ($gd_ver)"
  else
    echo "warning: export templates not found at $src_zip — install via Godot editor" >&2
  fi
fi

echo "created $dir"
echo "  display name: $name"
echo "  package id:   $pkg  (versionCode 1, versionName 0.1.0)"
echo
echo "next steps:"
echo "  1. fill in $dir/GAME.md"
echo "  2. open the project in Godot and greybox the core loop"
echo "  3. add the game to README.md and docs/games-log.md (status: prototype)"
echo "  4. tools/check.sh $slug"
