#!/usr/bin/env bash
set -euo pipefail
mkdir -p build
xcrun simctl list devices available --json > build/devices.json
DEVICE_ID=$(python3 - <<'PY'
import json
with open('build/devices.json') as f:
    devices = json.load(f)['devices']
for runtime, items in reversed(list(devices.items())):
    if 'iOS' not in runtime:
        continue
    for device in items:
        if device['name'].startswith('iPhone') and device.get('isAvailable', True):
            print(device['udid'])
            raise SystemExit(0)
raise SystemExit('No available iPhone simulator runtime found.')
PY
)
echo "Selected iPhone simulator: $DEVICE_ID"
xcodebuild -project Qiling.xcodeproj -scheme Qiling \
  -destination "platform=iOS Simulator,id=$DEVICE_ID" \
  -derivedDataPath build/DerivedData \
  -resultBundlePath build/TestResults.xcresult \
  -parallel-testing-enabled NO CODE_SIGNING_ALLOWED=NO test 2>&1 | tee build/xcodebuild.log
xcrun simctl boot "$DEVICE_ID" 2>/dev/null || true
xcrun simctl bootstatus "$DEVICE_ID" -b
xcrun simctl install "$DEVICE_ID" build/DerivedData/Build/Products/Debug-iphonesimulator/Qiling.app
APP_PATH=build/DerivedData/Build/Products/Debug-iphonesimulator/Qiling.app
APP_BUNDLE_ID=$(/usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier' "$APP_PATH/Info.plist")
xcrun simctl launch "$DEVICE_ID" "$APP_BUNDLE_ID" --demo
sleep 3
xcrun simctl io "$DEVICE_ID" screenshot build/native-home.png
