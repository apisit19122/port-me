#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."

swift build -c release
[ -f assets/PortMe.icns ] || ./scripts/make-icon.sh

APP="dist/PortMe.app"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp .build/release/PortMe "$APP/Contents/MacOS/PortMe"
cp scripts/Info.plist "$APP/Contents/Info.plist"
cp assets/PortMe.icns "$APP/Contents/Resources/PortMe.icns"

codesign --force --sign - "$APP"
echo "สร้าง $APP เสร็จแล้ว"
