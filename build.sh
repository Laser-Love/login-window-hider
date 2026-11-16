#!/bin/sh
# Builds "Login Window Hider.app" into ./build (works on Apple Silicon and Intel Macs).
# Usage: sh build.sh            build only
#        sh build.sh install    build, then copy to /Applications and open it
set -e
cd "$(dirname "$0")"
NAME="Login Window Hider"
EXE="LoginWindowHider"
APP="build/$NAME.app"
rm -rf build
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp Info.plist "$APP/Contents/Info.plist"

# App icon: render every size macOS needs, then pack them into AppIcon.icns.
swiftc -O -o build/make_icon Icon/make_icon.swift
ICONSET="build/AppIcon.iconset"
mkdir -p "$ICONSET"
for s in 16 32 128 256 512; do
  build/make_icon "$s" "$ICONSET/icon_${s}x${s}.png"
  build/make_icon "$((s * 2))" "$ICONSET/icon_${s}x${s}@2x.png"
done
iconutil -c icns "$ICONSET" -o "$APP/Contents/Resources/AppIcon.icns"
rm -rf "$ICONSET" build/make_icon

for arch in arm64 x86_64; do
  swiftc -O -target "$arch-apple-macos13.0" -o "build/$EXE-$arch" Sources/main.swift
done
lipo -create "build/$EXE-arm64" "build/$EXE-x86_64" -output "$APP/Contents/MacOS/$EXE"
rm "build/$EXE-arm64" "build/$EXE-x86_64"

codesign --force --sign - "$APP"
echo "Built: $APP"

if [ "$1" = "install" ]; then
  pkill -x "$EXE" 2>/dev/null || true
  pkill -x LoginHider 2>/dev/null || true          # the app's old name
  rm -rf "/Applications/Login Hider.app" "/Applications/$NAME.app"
  cp -R "$APP" /Applications/
  open "/Applications/$NAME.app"
  echo "Installed to /Applications and opened."
fi
