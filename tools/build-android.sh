#!/usr/bin/env bash
# Headless release export of one game → builds/<slug>-<versionName>.aab
# Usage: tools/build-android.sh <slug>
# Requires: Android export configured in the Godot editor once (SDK/JDK paths,
# keystore in export_credentials.cfg — which is gitignored).
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
GODOT="${GODOT:-/Applications/Godot.app/Contents/MacOS/Godot}"

if [[ ! -x "$GODOT" ]]; then
  echo "error: Godot binary not found at $GODOT (install Godot 4, or set \$GODOT)" >&2
  exit 1
fi

slug="${1:?usage: tools/build-android.sh <slug>}"

# Release signing: the shared studio upload key lives OUTSIDE the repo
# (~/keystores/). Godot picks these env vars up when the preset's keystore
# fields are empty, so no credentials ever touch a tracked file.
KEYSTORE="$HOME/keystores/studio-upload.keystore"
if [[ -f "$KEYSTORE" && -f "$HOME/keystores/studio-upload.pass" ]]; then
  export GODOT_ANDROID_KEYSTORE_RELEASE_PATH="$KEYSTORE"
  export GODOT_ANDROID_KEYSTORE_RELEASE_USER="zintara-upload"
  GODOT_ANDROID_KEYSTORE_RELEASE_PASSWORD="$(cat "$HOME/keystores/studio-upload.pass")"
  export GODOT_ANDROID_KEYSTORE_RELEASE_PASSWORD
else
  echo "warning: ~/keystores/studio-upload.keystore missing — release will be unsigned" >&2
fi
dir="$(find "$ROOT/games" -maxdepth 1 -type d -name "[0-9][0-9][0-9]-$slug" | head -1)"
if [[ -z "$dir" ]]; then
  echo "error: no game '$slug' under games/" >&2
  exit 1
fi

ver="$(sed -nE 's|^version/name="(.*)"|\1|p' "$dir/export_presets.cfg" | head -1)"
out="$ROOT/builds/$slug-${ver:-0.0.0}.aab"
mkdir -p "$ROOT/builds"

echo "exporting $(basename "$dir") v${ver:-?} → $out"
"$GODOT" --headless --path "$dir" --export-release "Android" "$out"

if [[ ! -f "$out" ]]; then
  echo "error: export produced no file — open the project in the Godot editor and check" >&2
  echo "  Editor Settings → Export → Android (SDK/JDK paths) and the Android preset keystore" >&2
  exit 1
fi

size_mb="$(du -m "$out" | cut -f1)"
echo "built $out (${size_mb} MB)"
if (( size_mb > 40 )); then
  echo "warning: over the 40 MB target — check asset compression" >&2
fi
