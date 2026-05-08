## 1. Release Packaging Script

- [x] 1.1 Add a script that creates a clean distribution output directory separate from `.build/`.
- [x] 1.2 Have the script build or verify `.build/Snapper.app` before packaging.
- [x] 1.3 Copy `Snapper.app` into a temporary DMG staging directory using metadata-preserving copy behavior.
- [x] 1.4 Add an Applications shortcut or equivalent install guidance to the DMG staging directory.
- [x] 1.5 Generate a compressed read-only `Snapper.dmg` with built-in macOS tooling.

## 2. Free Signing Behavior

- [x] 2.1 Preserve the existing ad-hoc/local signing behavior for the default free packaging path.
- [x] 2.2 Ensure the packaging flow does not require Developer ID certificates, notarization credentials, or App Store Connect access.
- [x] 2.3 Keep the output structure compatible with a future optional Developer ID signing/notarization layer.

## 3. Metadata and Install Experience

- [x] 3.1 Verify the packaged app keeps the Snapper bundle name, executable name, bundle identifier, version metadata, and Accessibility usage description.
- [x] 3.2 Verify the generated DMG mounts and exposes `Snapper.app` plus the Applications shortcut or install guidance.
- [x] 3.3 Verify a user can copy `Snapper.app` from the DMG to `/Applications` without using repository terminal scripts.

## 4. Documentation

- [x] 4.1 Document how to build the free DMG distribution artifact.
- [x] 4.2 Document how users install Snapper from the DMG.
- [x] 4.3 Document unsigned/ad-hoc distribution limitations, including Gatekeeper warnings and Accessibility permission prompts.
- [x] 4.4 Document that Developer ID signing and notarization are the future path for smoother public distribution.

## 5. Validation

- [x] 5.1 Run the packaging command from a clean local state and confirm it produces the expected DMG.
- [x] 5.2 Inspect the DMG contents and app metadata.
- [x] 5.3 Confirm existing build/start/reinstall scripts still work for local development.
