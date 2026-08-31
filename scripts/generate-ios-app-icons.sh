#!/usr/bin/env bash
# Regenerate all iOS App Store / home-screen icons from the master source.
# Master file: assets/app-icon-source.png (1024×1024 PNG)
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SRC="$ROOT/assets/app-icon-source.png"
DEST="$ROOT/ios/Runner/Assets.xcassets/AppIcon.appiconset"

if [[ ! -f "$SRC" ]]; then
  echo "ERROR: Missing $SRC"
  exit 1
fi

generate() {
  sips -s format png -z "$2" "$2" "$SRC" --out "$DEST/$1" >/dev/null
}

generate "Icon-App-20x20@1x.png" 20
generate "Icon-App-20x20@2x.png" 40
generate "Icon-App-20x20@3x.png" 60
generate "Icon-App-29x29@1x.png" 29
generate "Icon-App-29x29@2x.png" 58
generate "Icon-App-29x29@3x.png" 87
generate "Icon-App-40x40@1x.png" 40
generate "Icon-App-40x40@2x.png" 80
generate "Icon-App-40x40@3x.png" 120
generate "Icon-App-60x60@2x.png" 120
generate "Icon-App-60x60@3x.png" 180
generate "Icon-App-76x76@1x.png" 76
generate "Icon-App-76x76@2x.png" 152
generate "Icon-App-83.5x83.5@2x.png" 167
cp "$SRC" "$DEST/Icon-App-1024x1024@1x.png"
# Ensure App Store marketing icon is opaque RGB PNG (no alpha channel).
sips -s format png -s formatOptions low "$DEST/Icon-App-1024x1024@1x.png" >/dev/null 2>&1 || true

echo "✓ iOS AppIcon updated from assets/app-icon-source.png"
