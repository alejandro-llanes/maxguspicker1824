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
swift build -c "${CONFIG}"

BIN_PATH="$(swift build -c "${CONFIG}" --show-bin-path)/${APP_NAME}"

echo "==> Assembling ${APP_BUNDLE}..."
rm -rf "${APP_BUNDLE}"
mkdir -p "${MACOS_DIR}" "${RESOURCES_DIR}"

cp "${BIN_PATH}" "${MACOS_DIR}/${APP_NAME}"
chmod +x "${MACOS_DIR}/${APP_NAME}"
cp "Resources/Info.plist" "${CONTENTS_DIR}/Info.plist"
printf "APPL????" > "${CONTENTS_DIR}/PkgInfo"

echo "==> Signing ${APP_BUNDLE} with entitlements..."
codesign --force --deep --sign - --entitlements "Resources/${APP_NAME}.entitlements" "${APP_BUNDLE}"

LSREGISTER="/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister"
if [ -x "${LSREGISTER}" ]; then
    echo "==> Registering ${APP_BUNDLE} with LaunchServices..."
    "${LSREGISTER}" -f "${APP_BUNDLE}" || true
fi

echo "==> Done! Application bundle created at: ${APP_BUNDLE}"
