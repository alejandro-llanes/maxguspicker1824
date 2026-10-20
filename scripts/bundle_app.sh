#!/usr/bin/env bash
set -euo pipefail

CONFIG="${1:-release}"
APP_NAME="maxguspicker1824"
BUILD_DIR="build"
APP_BUNDLE="${BUILD_DIR}/${APP_NAME}.app"
CONTENTS_DIR="${APP_BUNDLE}/Contents"
MACOS_DIR="${CONTENTS_DIR}/MacOS"
RESOURCES_DIR="${CONTENTS_DIR}/Resources"

echo "==> Building ${APP_NAME} (${CONFIG})..."
if [ "${UNIVERSAL:-0}" = "1" ]; then
    swift build -c "${CONFIG}" --arch arm64 --arch x86_64
    BIN_PATH="$(swift build -c "${CONFIG}" --arch arm64 --arch x86_64 --show-bin-path)/${APP_NAME}"
else
    swift build -c "${CONFIG}"
    BIN_PATH="$(swift build -c "${CONFIG}" --show-bin-path)/${APP_NAME}"
fi

echo "==> Assembling ${APP_BUNDLE}..."
rm -rf "${APP_BUNDLE}"
mkdir -p "${MACOS_DIR}" "${RESOURCES_DIR}"

cp "${BIN_PATH}" "${MACOS_DIR}/${APP_NAME}"
chmod +x "${MACOS_DIR}/${APP_NAME}"
cp "Resources/Info.plist" "${CONTENTS_DIR}/Info.plist"
if [ -f "Resources/AppIcon.icns" ]; then
    cp "Resources/AppIcon.icns" "${RESOURCES_DIR}/AppIcon.icns"
fi

if [ -n "${VERSION:-}" ]; then
    CLEAN_VERSION="${VERSION#v}"
    echo "==> Setting CFBundleShortVersionString to ${CLEAN_VERSION}..."
    /usr/libexec/PlistBuddy -c "Set :CFBundleShortVersionString ${CLEAN_VERSION}" "${CONTENTS_DIR}/Info.plist"
fi

printf "APPL????" > "${CONTENTS_DIR}/PkgInfo"

echo "==> Signing ${APP_BUNDLE} with entitlements..."
codesign --force --deep --sign - --entitlements "Resources/${APP_NAME}.entitlements" "${APP_BUNDLE}"
touch "${APP_BUNDLE}"

echo "==> Done! Application bundle created at: ${APP_BUNDLE}"


