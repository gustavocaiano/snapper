# Snapper Developer Notes

This file documents the local build, DMG packaging, and recommended GitHub Releases flow for Snapper.

## Local Requirements

- macOS 13+
- Xcode 15+ or Command Line Tools
- `swiftc`, `codesign`, `ditto`, and `hdiutil` available on `PATH`
- Optional: XcodeGen if you want to regenerate/open the Xcode project

## Build the Local App Bundle

```bash
./scripts/build_app.sh
```

Output:

```text
.build/Snapper.app
```

Build and launch:

```bash
./scripts/build_app.sh --run
```

The local build is ad-hoc signed with:

```text
codesign --sign -
```

That keeps the development path free and compatible with machines that do not have Developer ID certificates.

## Build the DMG

```bash
./scripts/package_dmg.sh
```

What the script does:

1. Recreates a clean `dist/` release output.
2. Builds `.build/Snapper.app` using the existing local ad-hoc signing flow.
3. Copies the app into `dist/Snapper.app` with `ditto`.
4. Stages DMG contents in `dist/dmg-staging/`.
5. Adds an `Applications -> /Applications` shortcut.
6. Adds `Install Snapper.txt` with unsigned-build guidance.
7. Creates a compressed read-only `dist/Snapper.dmg` with `hdiutil`.

Expected outputs:

```text
dist/Snapper.app
dist/Snapper.dmg
```

## Validate the DMG Manually

```bash
hdiutil attach dist/Snapper.dmg
```

Check that the mounted volume contains:

- `Snapper.app`
- `Applications` shortcut
- `Install Snapper.txt`

Inspect metadata:

```bash
plutil -p /Volumes/Snapper/Snapper.app/Contents/Info.plist
codesign --display --verbose=2 /Volumes/Snapper/Snapper.app
```

Detach afterwards:

```bash
hdiutil detach /Volumes/Snapper
```

## Publish to GitHub Releases Manually

Do **not** commit generated DMGs to the repository. Publish them as GitHub Release assets.

Recommended flow:

```bash
./scripts/release.sh
```

The script asks only for the version. It then builds `dist/Snapper.dmg`, creates and pushes a `vX.Y.Z` tag, creates the GitHub Release, and uploads the DMG.

You can also pass the version directly:

```bash
./scripts/release.sh 0.1.0
```

The stable download URL after release is:

```text
https://github.com/gustavocaiano/snapper/releases/latest/download/Snapper.dmg
```

Manual `gh` equivalent:

```bash
./scripts/package_dmg.sh
git tag -a v0.1.0 -m "Snapper v0.1.0"
git push origin v0.1.0
gh release create v0.1.0 dist/Snapper.dmg \
  --verify-tag \
  --title "Snapper v0.1.0" \
  --notes "Free ad-hoc signed DMG. Not Developer ID notarized yet."
```

If you only want to upload to an existing release:

```bash
gh release upload v0.1.0 dist/Snapper.dmg --clobber
```

## CI/CD Recommendation

Use GitHub Actions for release builds, triggered by version tags such as `v0.1.0`.

For the current free distribution path:

- Build on a pinned macOS runner, e.g. `macos-15`.
- Run `./scripts/package_dmg.sh`.
- Create a **draft** or **prerelease** GitHub Release.
- Upload `dist/Snapper.dmg` as a release asset.
- Clearly state that the asset is ad-hoc signed and not notarized.

For a polished public distribution path later:

- Import a Developer ID Application certificate from GitHub Actions secrets.
- Sign `Snapper.app` with the Developer ID identity.
- Create the DMG.
- Submit for notarization with `xcrun notarytool`.
- Staple the notarization ticket with `xcrun stapler`.
- Publish the release.

Minimal tag-triggered shape:

```yaml
name: Release DMG

on:
  push:
    tags:
      - "v*"

permissions:
  contents: write

jobs:
  release:
    runs-on: macos-15
    steps:
      - uses: actions/checkout@v4
      - name: Build DMG
        run: ./scripts/package_dmg.sh
      - name: Create GitHub Release
        env:
          GH_TOKEN: ${{ github.token }}
        run: |
          gh release create "${{ github.ref_name }}" dist/Snapper.dmg \
            --draft \
            --title "Snapper ${{ github.ref_name }}" \
            --notes "Free ad-hoc signed DMG. Not Developer ID notarized yet."
```

References:

- GitHub CLI release create: https://cli.github.com/manual/gh_release_create
- GitHub CLI release upload: https://cli.github.com/manual/gh_release_upload
- GitHub Actions permissions: https://docs.github.com/en/actions/writing-workflows/workflow-syntax-for-github-actions#permissions
- GitHub-hosted macOS runners: https://docs.github.com/en/actions/reference/runners/github-hosted-runners
- Apple packaging for distribution: https://developer.apple.com/documentation/xcode/packaging-mac-software-for-distribution
- Apple notarization: https://developer.apple.com/documentation/security/notarizing_your_app_before_distribution
