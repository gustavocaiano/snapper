#!/usr/bin/env bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
DMG_PATH="$ROOT_DIR/dist/Snapper.dmg"
VERSIONED_DMG_PATH=""
VERSIONED_DMG_NAME=""

usage() {
  cat <<'USAGE'
Usage:
  ./scripts/release.sh
  ./scripts/release.sh 0.1.0
  ./scripts/release.sh v0.1.0

Creates a Snapper GitHub Release by:
  1. Asking only for the version if no argument is provided
  2. Building dist/Snapper.dmg
  3. Creating and pushing a git tag
  4. Uploading a versioned DMG asset, e.g. Snapper_v0_1_0.dmg

Requirements:
  - gh authenticated with release permissions
  - origin remote pointing to the GitHub repo
  - no tracked or staged working tree changes
USAGE
}

fail() {
  echo "Error: $1" >&2
  exit 1
}

require_tool() {
  command -v "$1" >/dev/null 2>&1 || fail "Required tool '$1' was not found."
}

trim() {
  local value="$*"
  value="${value#"${value%%[![:space:]]*}"}"
  value="${value%"${value##*[![:space:]]}"}"
  printf '%s' "$value"
}

if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
  usage
  exit 0
fi

if [[ "$#" -gt 1 ]]; then
  usage
  exit 1
fi

cd "$ROOT_DIR"

require_tool git
require_tool gh
require_tool shasum

if [[ -n "$(git status --porcelain --untracked-files=no)" ]]; then
  git status --short --untracked-files=no
  fail "Commit or stash tracked/staged changes before creating a release."
fi

UNTRACKED_FILES="$(git ls-files --others --exclude-standard)"
if [[ -n "$UNTRACKED_FILES" ]]; then
  echo "Warning: untracked files are not part of the release tag:"
  printf '%s\n' "$UNTRACKED_FILES" | sed 's/^/  - /'
  echo
fi

gh auth status >/dev/null 2>&1 || fail "GitHub CLI is not authenticated. Run: gh auth login"
git config --get remote.origin.url >/dev/null || fail "No origin remote configured."

VERSION="${1:-}"
if [[ -z "$VERSION" ]]; then
  read -r -p "Release version (e.g. 0.1.0): " VERSION
fi

VERSION="$(trim "$VERSION")"
[[ -n "$VERSION" ]] || fail "Version cannot be empty."

TAG="$VERSION"
if [[ "$TAG" != v* ]]; then
  TAG="v$TAG"
fi

if [[ ! "$TAG" =~ ^v[0-9]+\.[0-9]+\.[0-9]+([-+][0-9A-Za-z.-]+)?$ ]]; then
  fail "Version must look like 0.1.0, v0.1.0, or v0.1.0-beta.1."
fi

echo "Preparing release: $TAG"
ASSET_VERSION="${TAG//./_}"
ASSET_VERSION="${ASSET_VERSION//-/_}"
ASSET_VERSION="${ASSET_VERSION//+/_}"
VERSIONED_DMG_NAME="Snapper_${ASSET_VERSION}.dmg"
VERSIONED_DMG_PATH="$ROOT_DIR/dist/$VERSIONED_DMG_NAME"

git fetch --tags origin >/dev/null 2>&1 || fail "Could not fetch tags from origin."

if git rev-parse -q --verify "refs/tags/$TAG" >/dev/null; then
  fail "Tag $TAG already exists locally."
fi

if git ls-remote --exit-code --tags origin "refs/tags/$TAG" >/dev/null 2>&1; then
  fail "Tag $TAG already exists on origin."
fi

if gh release view "$TAG" >/dev/null 2>&1; then
  fail "GitHub Release $TAG already exists."
fi

echo "Building DMG..."
"$ROOT_DIR/scripts/package_dmg.sh"

[[ -f "$DMG_PATH" ]] || fail "Expected DMG was not created at $DMG_PATH."
cp "$DMG_PATH" "$VERSIONED_DMG_PATH"

SHA256="$(shasum -a 256 "$VERSIONED_DMG_PATH" | cut -d ' ' -f 1)"
NOTES_FILE="$(mktemp)"
trap 'rm -f "$NOTES_FILE"' EXIT

cat > "$NOTES_FILE" <<NOTES
## Snapper $TAG

Free macOS DMG build.

### Install

1. Download \`$VERSIONED_DMG_NAME\`.
2. Open the DMG.
3. Drag \`Snapper.app\` to Applications.
4. Launch Snapper from \`/Applications\`.
5. Grant Accessibility permission when prompted.

### Distribution note

This build is ad-hoc signed and not Developer ID notarized yet. macOS may show a Gatekeeper warning on first launch. Use right-click → Open or Privacy & Security approval if needed.

### SHA-256

\`$SHA256\`
NOTES

echo "Creating git tag $TAG..."
git tag -a "$TAG" -m "Snapper $TAG"

echo "Pushing tag $TAG..."
git push origin "$TAG"

echo "Creating GitHub Release and uploading DMG..."
RELEASE_URL="$(gh release create "$TAG" "$VERSIONED_DMG_PATH" --verify-tag --title "Snapper $TAG" --notes-file "$NOTES_FILE")"

echo
echo "Release created: $RELEASE_URL"
echo "Download URL: https://github.com/gustavocaiano/snapper/releases/download/$TAG/$VERSIONED_DMG_NAME"
