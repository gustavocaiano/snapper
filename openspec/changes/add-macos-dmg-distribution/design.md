## Context

Snapper is a native macOS 13+ menu bar app built with Swift/SwiftUI. The current CLI-only path compiles source files with `swiftc`, creates `.build/Snapper.app`, and ad-hoc signs the bundle with `codesign --sign -`. This is enough for local development, but it leaves installation and relaunching tied to terminal scripts.

The desired near-term outcome is a free distribution path, not a fully Apple-certified one. Apple Developer ID signing and notarization require Apple Developer Program membership, so the initial implementation should produce an unsigned or ad-hoc-signed DMG that is usable for personal/internal distribution while clearly documenting Gatekeeper and Accessibility permission implications.

## Goals / Non-Goals

**Goals:**

- Produce a repeatable build artifact suitable for sharing: `Snapper.app` inside a `.dmg`.
- Keep the DMG flow free and compatible with local machines that do not have Developer ID certificates.
- Make installation feel like a normal Mac app flow by including an Applications shortcut in the DMG.
- Keep the app's bundle identifier, display name, and version metadata explicit and stable.
- Document first-launch friction for unsigned builds, including Gatekeeper warnings and Accessibility permission prompts.
- Leave a clean upgrade path for future Developer ID signing and notarization.

**Non-Goals:**

- No Mac App Store distribution.
- No paid Developer ID enrollment, notarization, stapling, or release automation that requires Apple credentials.
- No `.pkg` installer as the initial default path.
- No changes to Snapper's runtime functionality, window snapping behavior, app configuration format, or onboarding UX beyond documentation if needed.

## Decisions

### Use DMG as the primary distribution container

Snapper is a single `.app` bundle, so a DMG gives the simplest Mac-native installation experience: open disk image, drag app to Applications, launch app.

Alternatives considered:

- `.pkg`: useful when installing multiple components, privileged helpers, launch daemons, or files into fixed system paths. Snapper does not need that today, and unsigned PKGs add more trust friction than value.
- `.zip`: simpler to produce, but less guided for users and easier to launch from Downloads without understanding installation.
- App Store: trusted but out of scope, likely blocked by sandbox/App Review constraints around global hotkeys and Accessibility-driven window management.

### Keep ad-hoc/local signing for the free flow

The existing build script already ad-hoc signs the app. The DMG flow should preserve this unless a real signing identity is explicitly provided later. This keeps the flow free and compatible with machines that only have Xcode Command Line Tools.

Alternatives considered:

- Developer ID signing and notarization: best public-distribution UX, but requires paid Apple Developer Program membership and credentials.
- Xcode Personal Team signing: free-ish for development, but not intended for public distribution and may introduce provisioning expiration/device limitations.

### Separate build output from release output

The current `.build/` directory is a development output location. Release packaging should create a distinct distribution output, such as `dist/`, containing the final `.app` copy and `.dmg`. This avoids confusing temporary compiler products with shareable release artifacts.

Alternatives considered:

- Put DMGs directly in `.build/`: simpler, but mixes local build cache and distributable artifacts.
- Require Xcode Archive: more official but heavier and less compatible with the current CLI-only workflow.

### Document unsigned distribution honestly

The free DMG should not pretend to be certified. Documentation should explain that unsigned/notarization-free builds can trigger Gatekeeper warnings and may require right-click → Open or Privacy & Security approval. It should also explain that Accessibility permission may need to be re-granted after rebuilds because ad-hoc signatures are not stable like Developer ID signatures.

Alternatives considered:

- Hide the warning details: simpler docs, but users will hit scary macOS dialogs without context.
- Require notarization from the start: better UX, but contradicts the free-distribution goal.

## Risks / Trade-offs

- Gatekeeper blocks or warns on downloaded DMGs/apps → Mitigation: document the unsigned status and first-launch steps clearly.
- Accessibility permission becomes stale after rebuilds or signature changes → Mitigation: preserve existing reset guidance and explain why stable Developer ID signing improves this later.
- Users run the app directly from the DMG instead of Applications → Mitigation: include an Applications shortcut and installation instructions.
- DMG layout scripting can be brittle across macOS versions → Mitigation: keep the initial layout simple and rely on built-in `hdiutil`/Finder primitives rather than complex visual customization.
- Apple distribution rules evolve → Mitigation: isolate packaging logic so future Developer ID signing/notarization can be added as an optional layer without changing app behavior.

## Migration Plan

1. Add a packaging script that builds or consumes `.build/Snapper.app` and stages release files under `dist/`.
2. Create a DMG source folder containing `Snapper.app` and an Applications symlink.
3. Generate a read-only/compressed DMG using built-in macOS tooling.
4. Verify the DMG can be opened and contains the expected install layout.
5. Update documentation with free unsigned install instructions and optional future notarization notes.

Rollback is straightforward: remove the new packaging script/docs and continue using the existing build/start scripts.

## Open Questions

- Should the DMG include a custom background/icon layout now, or stay minimal until the release flow is stable?
- Should the package script always rebuild first, or support a mode that packages an existing `.build/Snapper.app` without rebuilding?
- Should future signed distribution use the same script with optional `DEVELOPER_ID_APPLICATION`/notary settings, or a separate release script?
