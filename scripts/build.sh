#!/usr/bin/env bash
# scripts/build.sh — builds dist/minoru-<version>.love
# Whitelist (include list), not blacklist: nothing unexpected (secrets,
# tests, docs, VCS cruft) can ever sneak in.
set -euo pipefail
cd "$(dirname "$0")/.."

VERSION="$(cat VERSION)"
OUT="dist/minoru-${VERSION}.love"

mkdir -p dist
rm -f "$OUT"

zip -q -r "$OUT" \
  conf.lua \
  main.lua \
  minoru/ \
  LICENSE \
  NOTICE.md \
  -x '*.DS_Store' '*.swp' '*~'

echo "[ok] built $OUT ($(du -h "$OUT" | cut -f1))"
