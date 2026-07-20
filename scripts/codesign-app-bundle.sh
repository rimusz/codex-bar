#!/usr/bin/env bash
# Sign CodexGateway.app for consistent ad-hoc or Developer ID signing.
# Usage: codesign-app-bundle.sh /path/to/CodexGateway.app [signing_identity]

set -euo pipefail

APP_BUNDLE="${1:?app bundle path required}"
IDENTITY="${2:--}"
BUNDLE_ID="com.rimusz.CodexGateway"
MACOS_DIR="$APP_BUNDLE/Contents/MacOS"
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ENTITLEMENTS="$ROOT_DIR/entitlements.plist"

xattr -cr "$APP_BUNDLE" 2>/dev/null || true

sign_nested() {
    local name="$1"
    local path="$MACOS_DIR/$name"
    [ -f "$path" ] || return 0
    echo "==> Signing $name as $BUNDLE_ID"
    codesign --force --sign "$IDENTITY" --identifier "$BUNDLE_ID" --timestamp=none "$path"
}

sign_nested "CodexGateway"
# Legacy launch path left behind by old ditto-merge updaters.
sign_nested "CodexBar"

if [ "$IDENTITY" = "-" ]; then
    echo "==> Ad-hoc signing app bundle"
    if [ -f "$ENTITLEMENTS" ]; then
        codesign --force --sign - --entitlements "$ENTITLEMENTS" --timestamp=none "$APP_BUNDLE"
    else
        codesign --force --sign - --timestamp=none "$APP_BUNDLE"
    fi
else
    echo "==> Signing app bundle with identity: $IDENTITY"
    if [ -f "$ENTITLEMENTS" ]; then
        codesign --force --deep --sign "$IDENTITY" \
            --options runtime \
            --entitlements "$ENTITLEMENTS" \
            "$APP_BUNDLE"
    else
        codesign --force --deep --sign "$IDENTITY" \
            --options runtime \
            "$APP_BUNDLE"
    fi
fi
