#!/bin/bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"
BUILD_ARGS=(-c release)
if [[ "${1:-}" == "--universal" ]]; then
  BUILD_ARGS+=(--arch arm64 --arch x86_64)
fi
swift build "${BUILD_ARGS[@]}"
BIN_DIR="$(swift build "${BUILD_ARGS[@]}" --show-bin-path)"
APP="$ROOT/dist/Python Teacher.app"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BIN_DIR/PythonTeacher" "$APP/Contents/MacOS/PythonTeacher"
cp "$ROOT/scripts/Info.plist" "$APP/Contents/Info.plist"
swift "$ROOT/scripts/make-icon.swift" "$ROOT/.build/PythonTeacher.iconset"
/usr/bin/iconutil -c icns "$ROOT/.build/PythonTeacher.iconset" -o "$APP/Contents/Resources/AppIcon.icns"
/usr/bin/codesign --force --sign - "$APP"
/usr/bin/codesign --verify --strict "$APP"
printf '\nBuilt: %s (%s)\nLaunch: open "%s"\n' "$APP" "$(/usr/bin/lipo -archs "$APP/Contents/MacOS/PythonTeacher")" "$APP"
