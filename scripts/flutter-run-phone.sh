#!/usr/bin/env bash
# Install PHA on the first connected physical iPhone (not a simulator).
set -euo pipefail

DART_DEFINE_FILE="${PHA_DART_DEFINE_FILE:-dart_define.json}"
MODE_FLAG="${1:-}"

if [[ ! -f "$DART_DEFINE_FILE" ]]; then
  echo "ERROR: $DART_DEFINE_FILE not found."
  echo "       cp dart_define.example.json dart_define.json"
  exit 1
fi

# Prefer explicit UDID, else pick first non-simulator iOS device.
DEVICE="${IOS_DEVICE_ID:-}"
if [[ -z "$DEVICE" ]]; then
  DEVICE="$(flutter devices --machine 2>/dev/null | python3 -c '
import json, sys
data = json.load(sys.stdin)
for d in data:
    if d.get("targetPlatform") == "ios" and not d.get("emulator", False) and d.get("id"):
        print(d["id"])
        break
')"
fi

if [[ -z "$DEVICE" ]]; then
  echo "ERROR: No physical iPhone found. Plug in the phone and trust this Mac."
  flutter devices
  exit 1
fi

echo "-> flutter run on physical device ${DEVICE} ${MODE_FLAG}"
echo "   dart defines: ${DART_DEFINE_FILE}"

mkdir -p build/ios/iphoneos .just

ARGS=(run -d "$DEVICE" --dart-define-from-file="$DART_DEFINE_FILE")
if [[ "$MODE_FLAG" == "--release" ]]; then
  ARGS+=(--release)
fi

set +e
flutter "${ARGS[@]}" 2>&1 | tee .just/flutter-run-phone.log
STATUS=${PIPESTATUS[0]}
set -e

# Flutter release sometimes builds to Release-iphoneos but looks in iphoneos/.
if [[ "$MODE_FLAG" == "--release" && ! -d build/ios/iphoneos/Runner.app && -d build/ios/Release-iphoneos/Runner.app ]]; then
  echo "-> Fixing release bundle path and installing via devicectl…"
  rm -rf build/ios/iphoneos/Runner.app
  cp -R build/ios/Release-iphoneos/Runner.app build/ios/iphoneos/Runner.app
  xcrun devicectl device install app --device "$DEVICE" build/ios/iphoneos/Runner.app
  echo "✓ Installed. Unlock the phone and open PHA."
  exit 0
fi

exit "$STATUS"
