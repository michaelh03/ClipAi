#!/usr/bin/env bash

set -euo pipefail

# Build and package the ClipAI app into a DMG using /create-dmg/create-dmg
# Optionally sign and notarize the app and DMG for distribution
#
# Usage:
#   scripts/create_dmg.sh [--notarize]
#
# Options:
#   --notarize    Sign and notarize the app and DMG for distribution
#
# Notarization Requirements:
# Before using --notarize, ensure you have:
# 1. Valid Developer ID Application certificate installed in Keychain
# 2. App-specific password for notarization stored in Keychain with label "notarization-password"
#    Create with: xcrun notarytool store-credentials "notarization-password" --apple-id "your@email.com" --team-id "TEAMID"
# 3. (Optional) Developer ID Installer certificate for DMG signing - if not found, DMG won't be signed
#
# Environment Variables (optional overrides):
#   SCHEME=ClipAI
#   CONFIGURATION=Release
#   DERIVED_DATA_PATH=/abs/path/to/build
#   OUTPUT_DIR=/abs/path/to/dist
#   CREATE_DMG_BIN=/create-dmg/create-dmg
#   SIGNING_IDENTITY="Developer ID Application: Your Name (TEAMID)"
#   INSTALLER_IDENTITY="Developer ID Installer: Your Name (TEAMID)"
#   KEYCHAIN_PROFILE="notarization-password"
#   BUNDLE_ID="com.yourcompany.clipai"
#
# Notarization Process:
# 1. Signs the app bundle with Developer ID Application certificate
# 2. Creates and signs the DMG with Developer ID Installer certificate
# 3. Submits DMG to Apple for notarization
# 4. Waits for notarization to complete
# 5. Staples the notarization ticket to the DMG
#
# Note: Notarization can take several minutes to complete

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

# Parse command line arguments
NOTARIZE=false
while [[ $# -gt 0 ]]; do
  case $1 in
    --notarize)
      NOTARIZE=true
      shift
      ;;
    *)
      echo "Unknown option: $1" >&2
      echo "Usage: $0 [--notarize]" >&2
      exit 1
      ;;
  esac
done

SCHEME="${SCHEME:-ClipAI}"
CONFIGURATION="${CONFIGURATION:-Release}"
DERIVED_DATA_PATH="${DERIVED_DATA_PATH:-${REPO_ROOT}/build}"
OUTPUT_DIR="${OUTPUT_DIR:-${REPO_ROOT}/dist}"
CREATE_DMG_BIN="${CREATE_DMG_BIN:-}"

# Notarization settings (only used when --notarize is specified)
SIGNING_IDENTITY="${SIGNING_IDENTITY:-}"
INSTALLER_IDENTITY="${INSTALLER_IDENTITY:-}"
KEYCHAIN_PROFILE="${KEYCHAIN_PROFILE:-notarization-password}"
BUNDLE_ID="${BUNDLE_ID:-com.yourcompany.clipai}"

XCODE_PROJECT="${REPO_ROOT}/ClipAI.xcodeproj"

# Build number set to date of build in format YYYYMMDDHHSS
BUILD_NUMBER_DATE="$(date +"%Y%m%d%H%S")"

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

# Validate notarization requirements if --notarize is specified
if [[ "${NOTARIZE}" == "true" ]]; then
  echo "Validating notarization requirements..."

  # Auto-detect signing identities if not provided
  if [[ -z "${SIGNING_IDENTITY}" ]]; then
    SIGNING_IDENTITY=$(security find-identity -v -p codesigning | grep "Developer ID Application" | head -n 1 | sed -n 's/.*"\(.*\)".*/\1/p' || true)
  fi

  if [[ -z "${INSTALLER_IDENTITY}" ]]; then
    INSTALLER_IDENTITY=$(security find-identity -v -p codesigning | grep "Developer ID Installer" | head -n 1 | sed -n 's/.*"\(.*\)".*/\1/p' || true)
  fi

  # Validate signing identities
  if [[ -z "${SIGNING_IDENTITY}" ]]; then
    echo "Error: No Developer ID Application certificate found." >&2
    echo "Please install a valid Developer ID Application certificate in your Keychain." >&2
    exit 1
  fi

  if [[ -z "${INSTALLER_IDENTITY}" ]]; then
    echo "Warning: No Developer ID Installer certificate found." >&2
    echo "DMG will be created but not signed. Install a Developer ID Installer certificate to sign the DMG." >&2
  fi

  # Validate keychain profile
  echo "Checking keychain profile '${KEYCHAIN_PROFILE}'..."
  # Test the keychain profile by trying to access it
  if ! xcrun notarytool history --keychain-profile "${KEYCHAIN_PROFILE}" >/dev/null 2>&1; then
    echo "Error: Keychain profile '${KEYCHAIN_PROFILE}' not found." >&2
    echo "Create it with: xcrun notarytool store-credentials \"${KEYCHAIN_PROFILE}\" --apple-id \"your@email.com\" --team-id \"TEAMID\"" >&2
    exit 1
  fi

  echo "✓ Signing identity: ${SIGNING_IDENTITY}"
  if [[ -n "${INSTALLER_IDENTITY}" ]]; then
    echo "✓ Installer identity: ${INSTALLER_IDENTITY}"
  else
    echo "⚠ Installer identity: Not found (DMG won't be signed)"
  fi
  echo "✓ Keychain profile: ${KEYCHAIN_PROFILE}"
fi

mkdir -p "${OUTPUT_DIR}"

if [[ "${NOTARIZE}" == "true" ]]; then
  echo "[1/5] Building ${SCHEME} (${CONFIGURATION})…"
  # Build without signing; we'll sign the built app bundle explicitly below
  xcodebuild \
    -project "${XCODE_PROJECT}" \
    -scheme "${SCHEME}" \
    -configuration "${CONFIGURATION}" \
    -derivedDataPath "${DERIVED_DATA_PATH}" \
    -destination 'generic/platform=macOS' \
    clean build \
    CODE_SIGN_IDENTITY="" \
    CODE_SIGNING_REQUIRED=NO \
    CODE_SIGNING_ALLOWED=NO \
    DEVELOPMENT_TEAM="" \
    CURRENT_PROJECT_VERSION="${BUILD_NUMBER_DATE}"
else
  echo "[1/3] Building ${SCHEME} (${CONFIGURATION})…"
  # Build without signing
  xcodebuild \
    -project "${XCODE_PROJECT}" \
    -scheme "${SCHEME}" \
    -configuration "${CONFIGURATION}" \
    -derivedDataPath "${DERIVED_DATA_PATH}" \
    -destination 'generic/platform=macOS' \
    clean build \
    CODE_SIGN_IDENTITY="" \
    CODE_SIGNING_REQUIRED=NO \
    CODE_SIGNING_ALLOWED=NO \
    DEVELOPMENT_TEAM="" \
    CURRENT_PROJECT_VERSION="${BUILD_NUMBER_DATE}"
fi

APP_PATH="${DERIVED_DATA_PATH}/Build/Products/${CONFIGURATION}/${SCHEME}.app"
if [[ ! -d "${APP_PATH}" ]]; then
  echo "Error: Built app not found at '${APP_PATH}'." >&2
  exit 1
fi

if [[ "${NOTARIZE}" == "true" ]]; then
  echo "[2/5] Preparing DMG metadata…"
else
  echo "[2/3] Preparing DMG metadata…"
fi
INFO_PLIST="${APP_PATH}/Contents/Info.plist"
# Ensure CFBundleVersion is the date-based build number
/usr/libexec/PlistBuddy -c "Set :CFBundleVersion ${BUILD_NUMBER_DATE}" "${INFO_PLIST}" 2>/dev/null || /usr/libexec/PlistBuddy -c "Add :CFBundleVersion string ${BUILD_NUMBER_DATE}" "${INFO_PLIST}"
VERSION="$((/usr/libexec/PlistBuddy -c "Print :CFBundleShortVersionString" "${INFO_PLIST}" 2>/dev/null) || true)"
BUILD_NUMBER="$((/usr/libexec/PlistBuddy -c "Print :CFBundleVersion" "${INFO_PLIST}" 2>/dev/null) || true)"
[[ -z "${VERSION}" ]] && VERSION="0.0.0"
[[ -z "${BUILD_NUMBER}" ]] && BUILD_NUMBER="${BUILD_NUMBER_DATE}"

DMG_BASENAME="${SCHEME}-${VERSION}"
if [[ -n "${BUILD_NUMBER}" ]]; then
  DMG_BASENAME+="-${BUILD_NUMBER}"
fi
DMG_PATH="${OUTPUT_DIR}/${DMG_BASENAME}.dmg"

# Sign the app if notarization is enabled (after Info.plist updates)
if [[ "${NOTARIZE}" == "true" ]]; then
  echo "[3/5] Signing app bundle…"
  codesign --force --options runtime --timestamp --deep \
    --entitlements "${REPO_ROOT}/ClipAI/ClipAI.entitlements" \
    --sign "${SIGNING_IDENTITY}" "${APP_PATH}"

  # Verify the signature
  echo "Verifying app signature…"
  codesign --verify --verbose "${APP_PATH}"
fi

# Use the first .icns found inside app resources as volume icon if available
VOLICON_ARGS=()
if [[ -d "${APP_PATH}/Contents/Resources" ]]; then
  ICON_CANDIDATE=$(find "${APP_PATH}/Contents/Resources" -maxdepth 1 -type f -name '*.icns' | head -n 1 || true)
  if [[ -n "${ICON_CANDIDATE}" && -f "${ICON_CANDIDATE}" ]]; then
    VOLICON_ARGS+=(--volicon "${ICON_CANDIDATE}")
  fi
fi

if [[ "${NOTARIZE}" == "true" ]]; then
  echo "[4/5] Creating DMG at ${DMG_PATH}…"
else
  echo "[3/3] Creating DMG at ${DMG_PATH}…"
fi
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

# Sign and notarize the DMG if requested
if [[ "${NOTARIZE}" == "true" ]]; then
  echo "[5/5] Signing and notarizing DMG…"

  # Sign the DMG if installer identity is available
  if [[ -n "${INSTALLER_IDENTITY}" ]]; then
    echo "Signing DMG with ${INSTALLER_IDENTITY}…"
    codesign --force --sign "${INSTALLER_IDENTITY}" "${DMG_PATH}"

    # Verify DMG signature
    echo "Verifying DMG signature…"
    codesign --verify --verbose "${DMG_PATH}"
  else
    echo "Skipping DMG signing (no Developer ID Installer certificate found)"
  fi

  # Submit for notarization
  echo "Submitting DMG for notarization…"
  SUBMIT_OUTPUT=$(xcrun notarytool submit "${DMG_PATH}" \
    --keychain-profile "${KEYCHAIN_PROFILE}" \
    --wait \
    --timeout 30m)

  echo "${SUBMIT_OUTPUT}"

  # Check if notarization was successful
  if echo "${SUBMIT_OUTPUT}" | grep -q "status: Accepted"; then
    echo "✓ Notarization successful!"

    # Staple the notarization ticket
    echo "Stapling notarization ticket…"
    xcrun stapler staple "${DMG_PATH}"

    # Verify stapling
    echo "Verifying stapled ticket…"
    xcrun stapler validate "${DMG_PATH}"

    if [[ -n "${INSTALLER_IDENTITY}" ]]; then
      echo "✓ DMG successfully signed, notarized, and stapled!"
    else
      echo "✓ DMG successfully notarized and stapled (not signed - no installer certificate)!"
    fi
  else
    echo "✗ Notarization failed. Check the output above for details." >&2
    exit 1
  fi
fi

echo "Done: ${DMG_PATH}"


