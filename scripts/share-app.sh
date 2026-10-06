#!/bin/bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"
bash "$ROOT/scripts/package-app.sh" --universal
VERSION="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$ROOT/scripts/Info.plist")"
STAGE="$ROOT/.build/share/Python Teacher"
ZIP="$ROOT/dist/Python-Teacher-$VERSION-macOS.zip"
rm -rf "$STAGE" "$ZIP"
mkdir -p "$STAGE"
/usr/bin/ditto "$ROOT/dist/Python Teacher.app" "$STAGE/Python Teacher.app"
cp "$ROOT/scripts/HOW-TO-OPEN.txt" "$STAGE/HOW TO OPEN.txt"
/usr/bin/xattr -cr "$STAGE"
/usr/bin/codesign --verify --strict "$STAGE/Python Teacher.app"
/usr/bin/ditto -c -k --norsrc --noextattr --keepParent "$STAGE" "$ZIP"
printf '\nShareable zip: %s\nSend this file to your friends; it includes "HOW TO OPEN.txt".\n' "$ZIP"
