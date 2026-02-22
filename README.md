# Snapper

Snapper is a native macOS 13+ menu bar app built with Swift and SwiftUI for creating custom snap zones and moving focused windows with global shortcuts.

## Requirements

- macOS 13 Ventura or newer
- Full Xcode 15+ (recommended, for signing/debugging) OR Command Line Tools only
- Accessibility permission enabled for Snapper

## Generate the Project

This repository uses XcodeGen.

```bash
xcodegen generate
open Snapper.xcodeproj
```

## Build Without Xcode App (CLI Only)

If you only have Command Line Tools installed, you can still build and run a local `.app` bundle:

```bash
./scripts/build_app.sh --run
```

This outputs:

`./.build/Snapper.app`

To restart without rebuilding (keeps current permission state):

```bash
./scripts/start_snapper.sh
```

If Accessibility gets stuck after renames/rebuilds:

```bash
./scripts/fix_accessibility.sh
```

## Clean Reinstall (CLI)

If you already have an older local build running and want a clean reinstall:

```bash
./scripts/reinstall_snapper.sh
```

Optional full reset (also deletes local app config):

```bash
./scripts/reinstall_snapper.sh --wipe-config
```

Notes:
- This path is great for local testing and iteration.
- Launch-at-login and Accessibility trust are more reliable when the app is signed (full Xcode workflow).
- Rebuilding changes the ad-hoc signature hash, so macOS may ask for Accessibility permission again.

## Key Features

- Menu bar app (`LSUIElement = true`) with zone list and quick actions
- On-screen editor overlays your real displays with drag-to-create zones
- Global shortcuts using Carbon `RegisterEventHotKey`
- Window move/resize using Accessibility API (`AXUIElement`)
- Auto-save JSON config at:
  `~/Library/Application Support/Snapper/config.json`
- Launch at Login toggle powered by `SMAppService`

## Project Structure

- `Snapper/App` - app lifecycle, state, and Carbon event handler
- `Snapper/Models` - data models (`SnapperZone`, `HotKey`, `AppConfig`)
- `Snapper/Services` - persistence, hotkeys, AX window control, displays, login item, on-screen editor manager
- `Snapper/Views` - menu popover, on-screen editor, shortcut recorder, onboarding UI
- `Snapper/Utilities` - geometry helpers and keycode/modifier mapping
