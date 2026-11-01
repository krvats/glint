#!/usr/bin/env bash
# Updates an EXISTING Glint install in place with the fixed files from this zip.
# Keeps your settings, shortcuts and theme sync exactly as they are. Run:  bash apply-fix.sh
set -euo pipefail
here="$(cd "$(dirname "$0")" && pwd)"
if command -v glint >/dev/null 2>&1; then bindir="$(dirname "$(readlink -f "$(command -v glint)")")"
else bindir="${GLINT_PREFIX:-$HOME/.local}/bin"; fi
mkdir -p "$bindir"
install -m755 "$here/src/bin/glint" "$bindir/glint"
install -m755 "$here/src/bin/glint-gui" "$bindir/glint-gui"
echo "✓ updated glint and glint-gui in $bindir"
sharedir="${GLINT_PREFIX:-$HOME/.local}/share/glint"
mkdir -p "$sharedir/quickshell" && install -m644 "$here/src/share/quickshell/glint-pill.qml" "$sharedir/quickshell/glint-pill.qml"
echo "✓ installed the Caelestia hover icon (turn on with: glint pill on)"
"$bindir/glint" migrate >/dev/null 2>&1 || true      # picks up the old ~/.config/cdisplay folder if it is still there
echo "✓ settings kept"
echo; "$bindir/glint" doctor || true
echo; echo "Done. Type  glint  to open it,  glint popup  for the small panel,  glint pill on  for the hover icon. To remove everything later: glint uninstall --all"
