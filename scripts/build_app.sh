#!/usr/bin/env bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
BUILD_DIR="$ROOT_DIR/.build"
APP_DIR="$BUILD_DIR/Snapper.app"
EXECUTABLE_PATH="$BUILD_DIR/Snapper"

SOURCES=(
  "$ROOT_DIR/Snapper/App/SnapperApp.swift"
  "$ROOT_DIR/Snapper/App/AppDelegate.swift"
  "$ROOT_DIR/Snapper/App/AppState.swift"
  "$ROOT_DIR/Snapper/Models/ZoneModel.swift"
  "$ROOT_DIR/Snapper/Services/AccessibilityManager.swift"
  "$ROOT_DIR/Snapper/Services/ConfigurationManager.swift"
  "$ROOT_DIR/Snapper/Services/HotKeyManager.swift"
  "$ROOT_DIR/Snapper/Services/LoginItemManager.swift"
  "$ROOT_DIR/Snapper/Services/OnScreenZoneEditorManager.swift"
  "$ROOT_DIR/Snapper/Services/ScreenManager.swift"
  "$ROOT_DIR/Snapper/Services/GlobalDragEventMonitor.swift"
  "$ROOT_DIR/Snapper/Services/ZoneSnapOverlayManager.swift"
  "$ROOT_DIR/Snapper/Services/ShiftDragSnapController.swift"
  "$ROOT_DIR/Snapper/Services/WindowManager.swift"
  "$ROOT_DIR/Snapper/Utilities/Extensions.swift"
  "$ROOT_DIR/Snapper/Utilities/KeyCodeMapping.swift"
  "$ROOT_DIR/Snapper/Utilities/ZoneGeometry.swift"
  "$ROOT_DIR/Snapper/Views/MenuBar/MenuBarPopoverView.swift"
  "$ROOT_DIR/Snapper/Views/Onboarding/AccessibilityPromptView.swift"
  "$ROOT_DIR/Snapper/Views/ShortcutRecorder/ShortcutRecorderView.swift"
  "$ROOT_DIR/Snapper/Views/Shared/SnapperMarkView.swift"
  "$ROOT_DIR/Snapper/Views/SnapPreview/SnapPreviewOverlayView.swift"
  "$ROOT_DIR/Snapper/Views/ZoneEditor/ZoneDetailView.swift"
  "$ROOT_DIR/Snapper/Views/ZoneEditor/OnScreenZoneEditorView.swift"
  "$ROOT_DIR/Snapper/Views/ZoneEditor/ZoneOverlayView.swift"
)

mkdir -p "$BUILD_DIR"

echo "Compiling Snapper..."
swiftc -target arm64-apple-macos13.0 -O -o "$EXECUTABLE_PATH" "${SOURCES[@]}"

echo "Bundling app..."
mkdir -p "$APP_DIR/Contents/MacOS" "$APP_DIR/Contents/Resources"
cp "$EXECUTABLE_PATH" "$APP_DIR/Contents/MacOS/Snapper"
cp "$ROOT_DIR/Snapper/Info.plist" "$APP_DIR/Contents/Info.plist"
cp "$ROOT_DIR/Snapper/Resources/Snapper.icns" "$APP_DIR/Contents/Resources/Snapper.icns"
cp "$ROOT_DIR/Snapper/Resources/MenuBarIconTemplate.png" "$APP_DIR/Contents/Resources/MenuBarIconTemplate.png"

plutil -replace CFBundleExecutable -string "Snapper" "$APP_DIR/Contents/Info.plist"
plutil -replace CFBundleIdentifier -string "com.snapper.app" "$APP_DIR/Contents/Info.plist"
plutil -replace CFBundleIconFile -string "Snapper" "$APP_DIR/Contents/Info.plist"
plutil -replace CFBundleIconName -string "AppIcon" "$APP_DIR/Contents/Info.plist"
plutil -replace CFBundleName -string "Snapper" "$APP_DIR/Contents/Info.plist"
plutil -replace CFBundleShortVersionString -string "1.0.0" "$APP_DIR/Contents/Info.plist"
plutil -replace CFBundleVersion -string "1" "$APP_DIR/Contents/Info.plist"

chmod +x "$APP_DIR/Contents/MacOS/Snapper"

echo "Signing app..."
codesign --force --deep --sign - --identifier "com.snapper.app" -r="designated => identifier \"com.snapper.app\"" "$APP_DIR"

echo "Built: $APP_DIR"

if [[ "${1:-}" == "--run" ]]; then
  open "$APP_DIR"
fi
