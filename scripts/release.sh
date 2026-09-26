#!/usr/bin/env bash
# scripts/release.sh — build + checksum + reminders.
# Does NOT commit, tag, or push: those are deliberately manual.
set -euo pipefail
cd "$(dirname "$0")/.."

VERSION="$(cat VERSION)"

bash scripts/build.sh
bash scripts/checksum.sh

echo
echo "Prossimi passi (manuali, di proposito):"
echo "  1. prova il .love:  love dist/minoru-${VERSION}.love"
echo "  2. commit:          git add -A && git commit -m \"release: v${VERSION}\""
echo "  3. tag:             git tag -a v${VERSION} -m \"v${VERSION}\""
echo "  4. push:            git push && git push --tags"
echo "  5. la CI crea la release GitHub automaticamente sul tag v*"
