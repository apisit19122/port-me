#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."

mkdir -p .build/icon-module-cache
swift -module-cache-path .build/icon-module-cache assets/make-icon.swift

ICONSET="PortMe.iconset"
rm -rf "$ICONSET"
mkdir "$ICONSET"
trap 'rm -rf "$ICONSET"' EXIT

for size in 16 32 128 256 512; do
  sips -z "$size" "$size" assets/icon-1024.png --out "$ICONSET/icon_${size}x${size}.png" >/dev/null
  doubled_size=$((size * 2))
  sips -z "$doubled_size" "$doubled_size" assets/icon-1024.png --out "$ICONSET/icon_${size}x${size}@2x.png" >/dev/null
done

iconutil -c icns "$ICONSET" -o assets/PortMe.icns
echo "สร้าง assets/PortMe.icns เสร็จแล้ว"
