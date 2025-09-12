#!/usr/bin/env bash

set -euo pipefail

# Build and package the ClipAI app into a DMG using /create-dmg/create-dmg
#
# Usage:
#   scripts/create_dmg.sh
#
# Optional environment overrides:
#   SCHEME=ClipAI
#   CONFIGURATION=Release
#   DERIVED_DATA_PATH=/abs/path/to/build
#   OUTPUT_DIR=/abs/path/to/dist
#   CREATE_DMG_BIN=/create-dmg/create-dmg

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

SCHEME="${SCHEME:-ClipAI}"
CONFIGURATION="${CONFIGURATION:-Release}"
DERIVED_DATA_PATH="${DERIVED_DATA_PATH:-${REPO_ROOT}/build}"
OUTPUT_DIR="${OUTPUT_DIR:-${REPO_ROOT}/dist}"
CREATE_DMG_BIN="${CREATE_DMG_BIN:-}"

XCODE_PROJECT="${REPO_ROOT}/ClipAI.xcodeproj"

# Auto-detect create-dmg if not provided via CREATE_DMG_BIN
if [[ -z "${CREATE_DMG_BIN}" ]]; then
  CANDIDATES=(
    "/create-dmg/create-dmg"
    "$(command -v create-dmg 2>/dev/null || true)"
    "/opt/homebrew/bin/create-dmg"
    "/usr/local/bin/create-dmg"
    "/usr/bin/create-dmg"
  )
  for candidate in "${CANDIDATES[@]}"; do
    if [[ -n "${candidate}" && -x "${candidate}" ]]; then
      CREATE_DMG_BIN="${candidate}"
      break
    fi
  done
fi

if [[ -z "${CREATE_DMG_BIN}" || ! -x "${CREATE_DMG_BIN}" ]]; then
  echo "Error: create-dmg not found." >&2
  echo "Searched: 'CREATE_DMG_BIN=${CREATE_DMG_BIN:-unset}', /create-dmg/create-dmg, PATH, and common Homebrew locations." >&2
  echo >&2
  echo "To install:" >&2
  echo "  - Homebrew (recommended): brew install create-dmg" >&2
  echo "  - Manual: git clone https://github.com/create-dmg/create-dmg && export CREATE_DMG_BIN=</abs/path>/create-dmg/create-dmg" >&2
  echo >&2
  echo "Alternatively, pass the binary path explicitly: CREATE_DMG_BIN=/abs/path/create-dmg ./scripts/create_dmg.sh" >&2
  exit 1
fi

mkdir -p "${OUTPUT_DIR}"

echo "[1/3] Building ${SCHEME} (${CONFIGURATION})…"
xcodebuild \
  -project "${XCODE_PROJECT}" \
  -scheme "${SCHEME}" \
  -configuration "${CONFIGURATION}" \
  -derivedDataPath "${DERIVED_DATA_PATH}" \
  -destination 'generic/platform=macOS' \
  clean build \
  CODE_SIGN_IDENTITY="" CODE_SIGNING_REQUIRED=NO CODE_SIGNING_ALLOWED=NO

APP_PATH="${DERIVED_DATA_PATH}/Build/Products/${CONFIGURATION}/${SCHEME}.app"
if [[ ! -d "${APP_PATH}" ]]; then
  echo "Error: Built app not found at '${APP_PATH}'." >&2
  exit 1
fi

echo "[2/3] Preparing DMG metadata…"
INFO_PLIST="${APP_PATH}/Contents/Info.plist"
VERSION="$((/usr/libexec/PlistBuddy -c "Print :CFBundleShortVersionString" "${INFO_PLIST}" 2>/dev/null) || true)"
BUILD_NUMBER="$((/usr/libexec/PlistBuddy -c "Print :CFBundleVersion" "${INFO_PLIST}" 2>/dev/null) || true)"
[[ -z "${VERSION}" ]] && VERSION="0.0.0"

DMG_BASENAME="${SCHEME}-${VERSION}"
if [[ -n "${BUILD_NUMBER}" ]]; then
  DMG_BASENAME+="-${BUILD_NUMBER}"
fi
DMG_PATH="${OUTPUT_DIR}/${DMG_BASENAME}.dmg"

# Use the first .icns found inside app resources as volume icon if available
VOLICON_ARGS=()
if [[ -d "${APP_PATH}/Contents/Resources" ]]; then
  ICON_CANDIDATE=$(find "${APP_PATH}/Contents/Resources" -maxdepth 1 -type f -name '*.icns' | head -n 1 || true)
  if [[ -n "${ICON_CANDIDATE}" && -f "${ICON_CANDIDATE}" ]]; then
    VOLICON_ARGS+=(--volicon "${ICON_CANDIDATE}")
  fi
fi

echo "[3/3] Creating DMG at ${DMG_PATH}…"
rm -f "${DMG_PATH}"
"${CREATE_DMG_BIN}" \
  --volname "${SCHEME}" \
  "${VOLICON_ARGS[@]}" \
  --window-pos 200 120 \
  --window-size 600 400 \
  --icon-size 128 \
  --icon "${SCHEME}.app" 150 200 \
  --app-drop-link 450 200 \
  "${DMG_PATH}" \
  "${APP_PATH}"

echo "Done: ${DMG_PATH}"


