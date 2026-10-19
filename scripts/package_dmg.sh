#!/usr/bin/env bash
set -euo pipefail

APP_NAME="maxguspicker1824"
VOL_NAME="Maxgus Picker 1824"
BUILD_DIR="build"
APP_BUNDLE="${BUILD_DIR}/${APP_NAME}.app"
STAGING_DIR="${BUILD_DIR}/dmg-staging"

if [ ! -d "${APP_BUNDLE}" ]; then
    echo "==> ${APP_BUNDLE} not found. Running bundle_app.sh first..."
    ./scripts/bundle_app.sh release
fi

if [ -n "${VERSION:-}" ]; then
    CLEAN_VERSION="${VERSION#v}"
else
    CLEAN_VERSION="$(/usr/libexec/PlistBuddy -c "Print :CFBundleShortVersionString" "${APP_BUNDLE}/Contents/Info.plist" 2>/dev/null || echo "1.0.0")"
fi

DMG_VERSIONED="${BUILD_DIR}/${APP_NAME}-${CLEAN_VERSION}.dmg"
DMG_LATEST="${BUILD_DIR}/${APP_NAME}.dmg"

echo "==> Preparing DMG staging directory..."
rm -rf "${STAGING_DIR}" "${DMG_VERSIONED}" "${DMG_LATEST}"
mkdir -p "${STAGING_DIR}"

cp -R "${APP_BUNDLE}" "${STAGING_DIR}/${APP_NAME}.app"
ln -s /Applications "${STAGING_DIR}/Applications"

echo "==> Creating compressed DMG (${DMG_VERSIONED})..."
hdiutil create \
    -volname "${VOL_NAME}" \
    -srcfolder "${STAGING_DIR}" \
    -ov \
    -format UDZO \
    "${DMG_VERSIONED}"

cp "${DMG_VERSIONED}" "${DMG_LATEST}"
rm -rf "${STAGING_DIR}"

echo "==> Generating SHA-256 checksums..."
(
    cd "${BUILD_DIR}"
    shasum -a 256 "$(basename "${DMG_VERSIONED}")" > "$(basename "${DMG_VERSIONED}").sha256"
    shasum -a 256 "$(basename "${DMG_LATEST}")" > "$(basename "${DMG_LATEST}").sha256"
)

echo "==> Done! DMG packages created at:"
echo "    - ${DMG_VERSIONED}"
echo "    - ${DMG_LATEST}"
