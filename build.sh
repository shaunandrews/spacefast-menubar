#!/usr/bin/env bash
# Builds Spacefast.app (menubar-only, no Dock icon) into ./build.
#   UNIVERSAL=1   Apple silicon and Intel in one binary (for releases)
#   VERSION=0.2.0 the version the app reports (default 0.1.0)
#   SIGN_IDENTITY a codesigning identity (default ad-hoc)
set -euo pipefail
cd "$(dirname "$0")"

flags=(-c release)
[[ -n "${UNIVERSAL:-}" ]] && flags+=(--arch arm64 --arch x86_64)
swift build "${flags[@]}"
bin="$(swift build "${flags[@]}" --show-bin-path)/SpacefastMenubar"

app=build/Spacefast.app
rm -rf "$app"
mkdir -p "$app/Contents/MacOS" "$app/Contents/Resources"
cp Resources/* "$app/Contents/Resources/" 2>/dev/null || true
cp "$bin" "$app/Contents/MacOS/Spacefast"
cat > "$app/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleName</key><string>Spacefast</string>
  <key>CFBundleIdentifier</key><string>com.spacefast.menubar</string>
  <key>CFBundleExecutable</key><string>Spacefast</string>
  <key>CFBundlePackageType</key><string>APPL</string>
  <key>CFBundleShortVersionString</key><string>${VERSION:-0.1.0}</string>
  <key>LSMinimumSystemVersion</key><string>15.0</string>
  <key>LSUIElement</key><true/>
</dict>
</plist>
PLIST
codesign --force --sign "${SIGN_IDENTITY:--}" "$app" >/dev/null
echo "$app"
