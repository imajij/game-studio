#!/bin/bash
# usage: publish-chain.sh <slug> <appid>
set -u
SP=/private/tmp/claude-501/-Users-ajijuttam-projects/ee1e86c8-38ea-4c68-87b1-276d48aa0f0f/scratchpad
slug="$1"; APPID="$2"
echo "=== DRIVER $slug"
ego-browser nodejs < "$SP/run2-$slug.mjs" 2>&1 | tee "$SP/log-$slug-driver.txt" | grep -E 'saved|MISS|miss|uploaded|aab|release|error|Error|url' | tail -30
TRACK=$(grep -o 'tracks/[0-9]*' "$SP/log-$slug-driver.txt" | head -1 | cut -d/ -f2)
echo "=== TRACK=$TRACK"
echo "=== IARC $slug"
ego-browser nodejs < "$SP/iarc2-$slug.mjs" 2>&1 | grep -E 'iarc|error' | tail -8
echo "=== DATA SAFETY $slug"
ego-browser nodejs < "$SP/ds2-$slug.mjs" 2>&1 | grep -E 'ds|safety|saved|error|answered' | tail -10
if [ -n "$TRACK" ]; then
  sed -e "s|__APPID__|$APPID|" -e "s|__TRACK__|$TRACK|" -e 's|taskSpace(4)|taskSpace(12)|' "$SP/track-fix.mjs" > "$SP/track2-$slug.mjs"
  echo "=== TRACK FIX $slug"
  ego-browser nodejs < "$SP/track2-$slug.mjs" 2>&1 | grep -E 'track|countries|testers|state|progress|error' | tail -12
fi
sed -e "s|__APPID__|$APPID|" -e "s|__NAME__|$slug|" "$SP/submit2-template.mjs" > "$SP/submit2-$slug.mjs"
echo "=== SUBMIT $slug"
ego-browser nodejs < "$SP/submit2-$slug.mjs" 2>&1 | tail -6
echo "=== CHAIN DONE $slug"
