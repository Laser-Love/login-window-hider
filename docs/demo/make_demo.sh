#!/bin/sh
# Renders docs/demo.gif, the animated illustration at the top of the README.
# It reuses the app's own menu row code, so the menu in the animation matches the real one.
# Usage: sh docs/demo/make_demo.sh [folder-for-preview-stills]
set -e
cd "$(dirname "$0")/../.."
mkdir -p build
# The app's code without its last lines (which start the app), followed by the demo renderer.
sed '/^let app = NSApplication.shared/,$d' Sources/main.swift > build/demo.swift
cat docs/demo/make_demo.swift >> build/demo.swift
swiftc -O -o build/make_demo build/demo.swift
build/make_demo docs/demo.gif "$@"
rm build/demo.swift build/make_demo
