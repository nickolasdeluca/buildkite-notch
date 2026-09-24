#!/usr/bin/env bash
# Builds a universal, Developer ID signed and notarized BuildkiteNotch.app zip.
#
#   Scripts/release.sh            # build, sign, notarize, staple -> build/BuildkiteNotch-<version>.zip
#   Scripts/release.sh --publish  # also create the GitHub release and update the Homebrew cask
#
# Configuration comes from Scripts/release.env (gitignored, see release.env.example);
# variables already exported in the environment take precedence:
#   SIGN_IDENTITY        codesign identity (default: first "Developer ID Application" in the keychain)
#   NOTARY_PROFILE       notarytool keychain profile (default: buildkite-notch)
#   APPLE_API_KEY_PATH   App Store Connect API key (.p8); with the two below, used instead of the profile
#   APPLE_API_KEY_ID
#   APPLE_API_ISSUER_ID
#   TAP_REPO             Homebrew tap repository (default: nickolasdeluca/homebrew-tap)
set -euo pipefail

cd "$(dirname "$0")/.."

ENV_FILE="Scripts/release.env"
if [[ -f "$ENV_FILE" ]]; then
    while IFS='=' read -r key value; do
        [[ -z "$key" || "$key" == \#* ]] && continue
        value="${value%\"}"
        value="${value#\"}"
        [[ -z "${!key:-}" ]] && export "$key=$value"
    done < "$ENV_FILE"
fi

APP_NAME="BuildkiteNotch"
BUNDLE="build/${APP_NAME}.app"
REPO="nickolasdeluca/buildkite-notch"
TAP_REPO="${TAP_REPO:-nickolasdeluca/homebrew-tap}"
NOTARY_PROFILE="${NOTARY_PROFILE:-buildkite-notch}"
PUBLISH=false
[[ "${1:-}" == "--publish" ]] && PUBLISH=true

VERSION="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' Resources/Info.plist)"
BUNDLE_ID="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier' Resources/Info.plist)"
ZIP="build/${APP_NAME}-${VERSION}.zip"

SIGN_IDENTITY="${SIGN_IDENTITY:-${DEVELOPER_ID:-}}"
if [[ -z "$SIGN_IDENTITY" ]]; then
    SIGN_IDENTITY="$(security find-identity -v -p codesigning | sed -n 's/.*"\(Developer ID Application: .*\)"/\1/p' | head -1)"
fi
if [[ -z "$SIGN_IDENTITY" ]]; then
    echo "error: no \"Developer ID Application\" certificate found. See README (Distribuição)." >&2
    exit 1
fi

if [[ -n "${APPLE_API_KEY_PATH:-}" && -n "${APPLE_API_KEY_ID:-}" && -n "${APPLE_API_ISSUER_ID:-}" ]]; then
    NOTARY_AUTH=(--key "$APPLE_API_KEY_PATH" --key-id "$APPLE_API_KEY_ID" --issuer "$APPLE_API_ISSUER_ID")
    NOTARY_DESCRIPTION="App Store Connect API key"
else
    NOTARY_AUTH=(--keychain-profile "$NOTARY_PROFILE")
    NOTARY_DESCRIPTION="profile ${NOTARY_PROFILE}"
fi

if $PUBLISH; then
    if [[ -n "$(git status --porcelain)" ]]; then
        echo "error: working tree is dirty; commit before publishing." >&2
        exit 1
    fi
    if gh release view "v${VERSION}" --repo "$REPO" >/dev/null 2>&1; then
        echo "error: release v${VERSION} already exists; bump the version first (make bump VERSION=x.y.z)." >&2
        exit 1
    fi
fi

echo "==> Building ${APP_NAME} ${VERSION} (universal)"
make app CONFIG=release ARCHS="arm64 x86_64"

echo "==> Signing with: ${SIGN_IDENTITY}"
codesign --force --deep --options runtime --timestamp --sign "$SIGN_IDENTITY" "$BUNDLE"
codesign --verify --strict --verbose=2 "$BUNDLE"

echo "==> Notarizing (${NOTARY_DESCRIPTION})"
rm -f "$ZIP"
ditto -c -k --keepParent "$BUNDLE" "$ZIP"
xcrun notarytool submit "$ZIP" "${NOTARY_AUTH[@]}" --wait
xcrun stapler staple "$BUNDLE"
spctl --assess --type execute --verbose "$BUNDLE"

# Re-zip so the shipped archive contains the stapled ticket.
rm -f "$ZIP"
ditto -c -k --keepParent "$BUNDLE" "$ZIP"
SHA256="$(shasum -a 256 "$ZIP" | awk '{print $1}')"
echo "==> ${ZIP}"
echo "    sha256 ${SHA256}"

$PUBLISH || exit 0

echo "==> Publishing GitHub release v${VERSION}"
NOTES="$(awk -v v="$VERSION" '$0 ~ "^## \\[?"v"\\]?" {on=1; next} /^## / {on=0} on' CHANGELOG.md)"
git tag "v${VERSION}"
git push origin "v${VERSION}"
gh release create "v${VERSION}" "$ZIP" --repo "$REPO" --title "v${VERSION}" --notes "${NOTES:-Release ${VERSION}}"

echo "==> Updating cask in ${TAP_REPO}"
TAP_DIR="$(mktemp -d)"
trap 'rm -rf "$TAP_DIR"' EXIT
gh repo clone "$TAP_REPO" "$TAP_DIR" -- --quiet
mkdir -p "$TAP_DIR/Casks"
cat > "$TAP_DIR/Casks/buildkite-notch.rb" <<EOF
cask "buildkite-notch" do
  version "${VERSION}"
  sha256 "${SHA256}"

  url "https://github.com/${REPO}/releases/download/v#{version}/${APP_NAME}-#{version}.zip"
  name "Buildkite Notch"
  desc "Notch that tracks Buildkite builds and deploys"
  homepage "https://github.com/${REPO}"

  depends_on macos: ">= :sonoma"

  app "${APP_NAME}.app"

  uninstall quit: "${BUNDLE_ID}"

  zap trash: "~/Library/Preferences/${BUNDLE_ID}.plist"
end
EOF
git -C "$TAP_DIR" add Casks/buildkite-notch.rb
git -C "$TAP_DIR" commit --quiet -m "buildkite-notch ${VERSION}"
git -C "$TAP_DIR" push --quiet origin HEAD
echo "==> Done: brew install --cask ${TAP_REPO%%/*}/tap/buildkite-notch"
