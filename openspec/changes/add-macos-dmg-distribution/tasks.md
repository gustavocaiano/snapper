## 1. Release Packaging Script

- [ ] 1.1 Add a script that creates a clean distribution output directory separate from `.build/`.
- [ ] 1.2 Have the script build or verify `.build/Snapper.app` before packaging.
- [ ] 1.3 Copy `Snapper.app` into a temporary DMG staging directory using metadata-preserving copy behavior.
- [ ] 1.4 Add an Applications shortcut or equivalent install guidance to the DMG staging directory.
- [ ] 1.5 Generate a compressed read-only `Snapper.dmg` with built-in macOS tooling.

## 2. Free Signing Behavior

- [ ] 2.1 Preserve the existing ad-hoc/local signing behavior for the default free packaging path.
- [ ] 2.2 Ensure the packaging flow does not require Developer ID certificates, notarization credentials, or App Store Connect access.
- [ ] 2.3 Keep the output structure compatible with a future optional Developer ID signing/notarization layer.

## 3. Metadata and Install Experience

- [ ] 3.1 Verify the packaged app keeps the Snapper bundle name, executable name, bundle identifier, version metadata, and Accessibility usage description.
- [ ] 3.2 Verify the generated DMG mounts and exposes `Snapper.app` plus the Applications shortcut or install guidance.
- [ ] 3.3 Verify a user can copy `Snapper.app` from the DMG to `/Applications` without using repository terminal scripts.

## 4. Documentation

- [ ] 4.1 Document how to build the free DMG distribution artifact.
- [ ] 4.2 Document how users install Snapper from the DMG.
- [ ] 4.3 Document unsigned/ad-hoc distribution limitations, including Gatekeeper warnings and Accessibility permission prompts.
- [ ] 4.4 Document that Developer ID signing and notarization are the future path for smoother public distribution.

## 5. Validation

- [ ] 5.1 Run the packaging command from a clean local state and confirm it produces the expected DMG.
- [ ] 5.2 Inspect the DMG contents and app metadata.
- [ ] 5.3 Confirm existing build/start/reinstall scripts still work for local development.
