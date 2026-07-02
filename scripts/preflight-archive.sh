#!/usr/bin/env bash
#
# preflight-archive.sh <path/to/Sipli.xcarchive>
#
# Validates an archive against every known cause of the 2026-07-01
# "Invalid Binary" saga BEFORE it is uploaded/submitted. All checks are
# deterministic; any failure exits non-zero with a specific message.
#
set -euo pipefail

A="${1:?usage: preflight-archive.sh <xcarchive>}"
APP="$A/Products/Applications/Sipli.app"
WATCH="$APP/Watch/SipliWatch.app"
BUNDLES=(
  "$APP"
  "$APP/PlugIns/SipliWidget.appex"
  "$WATCH"
  "$WATCH/PlugIns/SipliWatchWidgetsExtension.appex"
)
FAIL=0
err() { echo "✗ $*" >&2; FAIL=1; }
ok()  { echo "✓ $*"; }

pb() { /usr/libexec/PlistBuddy -c "Print :$2" "$1/Info.plist" 2>/dev/null || true; }

# 0. Beta build-environment stamps (the root cause of builds 7/8/9).
#    Beta *seed* builds have a >=5000 build segment plus a trailing lowercase
#    letter (26A5368g, 27A5209h). GM builds can legitimately end in a short
#    letter suffix (e.g. SDK build 23F81a), so match the seed pattern only.
for B in "${BUNDLES[@]}"; do
  for K in BuildMachineOSBuild DTXcodeBuild DTPlatformBuild DTSDKBuild; do
    V="$(pb "$B" "$K")"
    if [[ "$V" =~ [5-9][0-9]{3}[a-z]$ ]]; then
      err "$K=$V in $(basename "$B") is a BETA-SEED stamp — archive was made with beta Xcode or on beta macOS"
    fi
  done
  SDK="$(pb "$B" DTSDKName)"
  if [[ "$SDK" == *27.0* ]]; then
    err "DTSDKName=$SDK in $(basename "$B") — built against a beta SDK"
  fi
done
[[ $FAIL == 0 ]] && ok "no beta toolchain/OS stamps"

# 1. No Siri entitlement AND no SiriKit usage string (AppIntents needs
#    neither; either one alone is a capability cross-check mismatch —
#    the thread-676166 class of silent Invalid Binary).
if codesign -d --entitlements :- "$APP" 2>/dev/null | grep -q "com.apple.developer.siri"; then
  err "com.apple.developer.siri entitlement present on Sipli.app"
elif /usr/libexec/PlistBuddy -c "Print :NSSiriUsageDescription" "$APP/Info.plist" >/dev/null 2>&1; then
  err "NSSiriUsageDescription present without SiriKit — remove it (AppIntents needs no Siri config)"
else
  ok "no Siri entitlement, no Siri usage string"
fi

# 2. No dev artifacts in the shipping bundle.
STRAYS="$(find "$APP" -name "*.storekit" -o -name "icon.json" -o -name "Gemini_Generated_Image*" 2>/dev/null)"
if [[ -n "$STRAYS" ]]; then
  err "dev artifacts shipped in bundle: $STRAYS"
else
  ok "no dev artifacts in bundle"
fi

# 3. Privacy manifests: one per bundle, lint-clean.
COUNT="$(find "$A/Products" -name "PrivacyInfo.xcprivacy" | wc -l | tr -d ' ')"
if [[ "$COUNT" != "4" ]]; then
  err "expected 4 PrivacyInfo.xcprivacy (one per bundle), found $COUNT"
else
  find "$A/Products" -name "PrivacyInfo.xcprivacy" -exec plutil -lint {} \; >/dev/null && ok "4 privacy manifests, lint-clean"
fi

# 4. Watch app rules: display name, companion id, version parity.
[[ "$(pb "$WATCH" CFBundleDisplayName)" == "Sipli" ]] || err "watch CFBundleDisplayName != Sipli"
[[ "$(pb "$WATCH" WKCompanionAppBundleIdentifier)" == "com.waterquest.hydration" ]] || err "watch companion bundle id mismatch"
APPV="$(pb "$APP" CFBundleShortVersionString)/$(pb "$APP" CFBundleVersion)"
for B in "${BUNDLES[@]:1}"; do
  BV="$(pb "$B" CFBundleShortVersionString)/$(pb "$B" CFBundleVersion)"
  [[ "$BV" == "$APPV" ]] || err "version mismatch: $(basename "$B") is $BV, app is $APPV"
done
[[ $FAIL == 0 ]] && ok "watch rules + uniform versions ($APPV)"

# 5. Binary hygiene: no test or beta frameworks linked.
for B in "${BUNDLES[@]}"; do
  X="$B/$(pb "$B" CFBundleExecutable)"
  if otool -L "$X" 2>/dev/null | grep -Eiq 'xctest|/Testing\.framework|StoreKitTest|AppIntentsTesting|Xcode-beta'; then
    err "suspicious framework linkage in $(basename "$B")"
  fi
done
[[ $FAIL == 0 ]] && ok "binary linkage clean"

# 6. Code seal intact.
if codesign --verify --deep --strict "$APP" 2>/dev/null; then
  ok "code seal verifies"
else
  err "codesign --verify failed on Sipli.app"
fi

if [[ $FAIL != 0 ]]; then
  echo "✗ PREFLIGHT FAILED — do not upload this archive." >&2
  exit 1
fi
echo "✓ PREFLIGHT PASSED — archive is safe to upload."
