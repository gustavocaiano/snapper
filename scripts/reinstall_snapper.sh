#!/usr/bin/env bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"

echo "Stopping old app processes..."
pkill -f "/.build/SnapZone.app/Contents/MacOS/SnapZone" 2>/dev/null || true
pkill -f "/.build/Snapper.app/Contents/MacOS/Snapper" 2>/dev/null || true

echo "Removing local app bundles..."
rm -rf "$ROOT_DIR/.build/SnapZone.app" "$ROOT_DIR/.build/SnapZone"
rm -rf "$ROOT_DIR/.build/Snapper.app" "$ROOT_DIR/.build/Snapper"

if [[ "${1:-}" == "--wipe-config" ]]; then
  echo "Removing local config folders..."
  rm -rf "$HOME/Library/Application Support/SnapZone"
  rm -rf "$HOME/Library/Application Support/Snapper"
fi

"$ROOT_DIR/scripts/build_app.sh" --run

echo "Done. Snapper is rebuilt and relaunched."
