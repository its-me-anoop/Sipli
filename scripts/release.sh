#!/usr/bin/env bash
#
# release.sh — archive the Sipli app (+ embedded widget, watch app, and watch
# widgets) and upload the build to App Store Connect / TestFlight.
#
# Archiving the `WaterQuest` scheme produces ONE .xcarchive that already embeds
# SipliWidget, SipliWatch, and SipliWatchWidgetsExtension — do not archive them
# separately.
#
# ---------------------------------------------------------------------------
# Prerequisites (one-time, human):
#   1. An Apple Distribution certificate + private key in the login keychain.
#      Verify:  security find-identity -v -p codesigning | grep "Apple Distribution"
#      If absent: sign in to the team K6623R3GP5 Apple ID in
#      Xcode ▸ Settings ▸ Accounts and let it generate the cert (or import a .p12).
#   2. An App Store Connect API key for a non-interactive upload (recommended):
#        export ASC_KEY_ID=XXXXXXXXXX
#        export ASC_ISSUER_ID=xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx
#      Place the key at ~/.appstoreconnect/private_keys/AuthKey_${ASC_KEY_ID}.p8
#      (or point ASC_KEY_PATH at it). If these are unset, the export step falls
#      back to whatever account is signed in to Xcode (Organizer-style upload).
#
# The build number must not collide with a build already on App Store Connect.
# Bump CURRENT_PROJECT_VERSION (uniformly across all targets) before releasing,
# e.g.  xcrun agvtool new-version -all <N>
# ---------------------------------------------------------------------------

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PROJECT="${REPO_ROOT}/WaterQuest.xcodeproj"
SCHEME="WaterQuest"
CONFIG="Release"
EXPORT_OPTS="${REPO_ROOT}/ExportOptions.plist"
STAMP="$(date +%Y%m%d-%H%M%S)"
ARCHIVE_PATH="${REPO_ROOT}/build/Sipli-${STAMP}.xcarchive"
EXPORT_DIR="${REPO_ROOT}/build/export-${STAMP}"

echo "▸ Project : ${PROJECT}"
echo "▸ Scheme  : ${SCHEME} (${CONFIG})"
echo "▸ Archive : ${ARCHIVE_PATH}"

# --- Preflight: local distribution identity (informational) ------------------
# Not fatal: with Xcode 27+ automatic signing and a signed-in account,
# -exportArchive uses Apple's cloud-managed distribution signing even when no
# local Apple Distribution cert exists (verified on the 4.0 build 7 upload).
# The one hard server-side gate is the Program License Agreement — if export
# fails with "PLA Update available", accept it at developer.apple.com.
if ! security find-identity -v -p codesigning | grep -q "Apple Distribution"; then
  echo "▸ Note    : no local 'Apple Distribution' identity — relying on cloud signing"
  echo "  via the Xcode-signed-in account (requires an up-to-date PLA acceptance)."
fi

# --- (1) Archive app + all embedded targets ----------------------------------
xcodebuild \
  -project "${PROJECT}" \
  -scheme "${SCHEME}" \
  -configuration "${CONFIG}" \
  -destination 'generic/platform=iOS' \
  -archivePath "${ARCHIVE_PATH}" \
  -allowProvisioningUpdates \
  clean archive

# --- (2) Export + upload to TestFlight ---------------------------------------
# ExportOptions.plist sets destination=upload, so -exportArchive uploads directly.
AUTH_ARGS=()
ASC_KEY_PATH="${ASC_KEY_PATH:-${HOME}/.appstoreconnect/private_keys/AuthKey_${ASC_KEY_ID:-}.p8}"
if [[ -n "${ASC_KEY_ID:-}" && -n "${ASC_ISSUER_ID:-}" && -f "${ASC_KEY_PATH}" ]]; then
  echo "▸ Auth    : App Store Connect API key ${ASC_KEY_ID}"
  AUTH_ARGS=(
    -authenticationKeyPath "${ASC_KEY_PATH}"
    -authenticationKeyID "${ASC_KEY_ID}"
    -authenticationKeyIssuerID "${ASC_ISSUER_ID}"
  )
else
  echo "▸ Auth    : no API key found — relying on the Xcode-signed-in account."
  echo "  (set ASC_KEY_ID / ASC_ISSUER_ID and place AuthKey_<id>.p8 for CI-style upload)"
fi

xcodebuild -exportArchive \
  -archivePath "${ARCHIVE_PATH}" \
  -exportPath "${EXPORT_DIR}" \
  -exportOptionsPlist "${EXPORT_OPTS}" \
  -allowProvisioningUpdates \
  "${AUTH_ARGS[@]}"

echo "✓ Upload submitted. The build appears under TestFlight once App Store"
echo "  Connect finishes processing (a few minutes up to ~1 hour)."
