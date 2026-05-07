## Why

Snapper currently works as a native macOS app, but users must build or launch it through terminal scripts, which makes installation feel like a developer-only workflow. A free, unsigned DMG distribution would let users install and launch Snapper like a normal Mac app while keeping paid Developer ID notarization optional for later.

## What Changes

- Add a repeatable release flow that builds Snapper into a distributable `.app` bundle.
- Add a DMG packaging flow for direct, free macOS distribution.
- Include a Finder-friendly DMG layout with `Snapper.app` and an Applications shortcut.
- Preserve the current local development scripts and ad-hoc signing workflow.
- Document unsigned-app expectations, including Gatekeeper warnings, Accessibility permission prompts, and when paid Developer ID notarization would be needed.

## Capabilities

### New Capabilities
- `macos-dmg-distribution`: Defines how Snapper is packaged into an installable macOS DMG and what user-facing installation behavior is expected.

### Modified Capabilities

None.

## Impact

- Affected areas: release/build scripts, README or release documentation, generated app bundle metadata, and distribution artifacts under a build/dist output directory.
- No app runtime behavior, zone snapping behavior, hotkey behavior, Accessibility API usage, or user configuration schema should change.
- No paid Apple Developer Program membership should be required for the initial implementation.
- Future Developer ID signing and notarization should remain possible without redesigning the release flow.
