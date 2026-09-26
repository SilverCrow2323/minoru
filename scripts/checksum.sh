#!/usr/bin/env bash
# scripts/checksum.sh — sha256 of the built .love
set -euo pipefail
cd "$(dirname "$0")/.."

VERSION="$(cat VERSION)"
OUT="dist/minoru-${VERSION}.love"

if [ ! -f "$OUT" ]; then
  echo "ERRORE: $OUT non esiste. Lancia prima scripts/build.sh."
  exit 1
fi

sha256sum "$OUT" > "$OUT.sha256"
echo "[ok] checksum: $OUT.sha256"
cat "$OUT.sha256"
