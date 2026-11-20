#!/bin/sh
# Renders docs/menu.png, the README screenshot of the menu in light and dark mode.
# It reuses the app's own menu views, so the screenshot matches the real menu.
# Usage: sh docs/screenshot/make_screenshot.sh [output.png]
set -e
cd "$(dirname "$0")/../.."
mkdir -p build
sed '/^let app = NSApplication.shared/,$d' Sources/main.swift > build/screenshot.swift
cat docs/screenshot/make_screenshot.swift >> build/screenshot.swift
swiftc -O -o build/make_screenshot build/screenshot.swift
build/make_screenshot "${1:-docs/menu.png}"
rm build/screenshot.swift build/make_screenshot
