#!/bin/sh
# Builds the app and packages it as dist/Login-Window-Hider.dmg (drag the app into Applications).
# Usage: sh make_dmg.sh
set -e
cd "$(dirname "$0")"
sh build.sh
NAME="Login Window Hider"
STAGE="build/dmg"
rm -rf "$STAGE" dist
mkdir -p "$STAGE" dist
cp -R "build/$NAME.app" "$STAGE/"
ln -s /Applications "$STAGE/Applications"
hdiutil create -volname "$NAME" -srcfolder "$STAGE" -ov -format UDZO "dist/Login-Window-Hider.dmg" >/dev/null
rm -rf "$STAGE"
echo "Made: dist/Login-Window-Hider.dmg"
