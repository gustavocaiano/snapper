#!/usr/bin/env bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
APP_PATH="$ROOT_DIR/.build/Snapper.app"

if [[ ! -d "$APP_PATH" ]]; then
  echo "Snapper app bundle not found at $APP_PATH"
  echo "Run ./scripts/build_app.sh first."
  exit 1
fi

pkill -f "/.build/Snapper.app/Contents/MacOS/Snapper" 2>/dev/null || true
tccutil reset Accessibility com.snapper.app || true
open "$APP_PATH"

echo "Reset done. In System Settings > Privacy & Security > Accessibility, enable Snapper again."
