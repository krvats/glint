#!/usr/bin/env bash
# Makes assets/social-preview.png (1280x640) for GitHub's "Social preview".
# Needs internet (for the public-domain Hokusai print and the fonts) and any one of: chromium, google-chrome, firefox.
set -euo pipefail
cd "$(dirname "$0")/.."
mkdir -p assets
HTML="file://$PWD/tools/social-preview.html"; OUT="$PWD/assets/social-preview.png"
for b in chromium chromium-browser google-chrome google-chrome-stable chrome brave; do
  if command -v "$b" >/dev/null 2>&1; then
    "$b" --headless --disable-gpu --hide-scrollbars --force-device-scale-factor=1 --window-size=1280,640 \
         --virtual-time-budget=15000 --screenshot="$OUT" "$HTML" >/dev/null 2>&1 && { echo "made $OUT"; exit 0; }
  fi
done
if command -v firefox >/dev/null 2>&1; then
  firefox --headless --window-size 1280,640 --screenshot "$OUT" "$HTML" >/dev/null 2>&1 && { echo "made $OUT"; exit 0; }
fi
echo "No headless browser found. Open tools/social-preview.html in any browser, set the window to exactly 1280x640"
echo "(DevTools > device toolbar), and take a screenshot. Save it as assets/social-preview.png"; exit 1
