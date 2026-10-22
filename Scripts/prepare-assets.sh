#!/usr/bin/env bash
set -euo pipefail
ICON_DIR=Resources/Assets.xcassets/AppIcon.appiconset
mkdir -p "$ICON_DIR"
# Normalize the generated source for Apple's required 1024px opaque icon.
sips --resampleHeightWidth 1024 1024 Art/AppIconSource.png --out "$ICON_DIR/AppIcon.png" >/dev/null
