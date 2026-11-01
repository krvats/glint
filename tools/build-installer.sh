#!/usr/bin/env bash
# Builds install.sh: the installer with the whole program packed inside it.
set -euo pipefail
cd "$(dirname "$0")/.."
VERSION="$(sed -n 's/^VERSION = "\(.*\)"/\1/p' src/bin/glint | head -1)"
tar --sort=name --owner=0 --group=0 --numeric-owner --mtime='2026-01-01' -czf - -C src bin share system | base64 -w 76 > /tmp/glint.payload
python3 - "$VERSION" <<'PY'
import sys
t = open("tools/installer.sh.in").read().replace("@VERSION@", sys.argv[1])
t = t.replace("@PAYLOAD@", open("/tmp/glint.payload").read().rstrip("\n"))
open("install.sh", "w").write(t)
PY
chmod +x install.sh; bash -n install.sh
echo "install.sh built: v$VERSION, $(wc -c < install.sh) bytes"
