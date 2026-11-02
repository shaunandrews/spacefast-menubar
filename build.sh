#!/usr/bin/env bash
# Builds Spacefast.app (menubar-only, no Dock icon) into ./build.
set -euo pipefail
cd "$(dirname "$0")"

swift build -c release
app=build/Spacefast.app
rm -rf "$app"
mkdir -p "$app/Contents/MacOS" "$app/Contents/Resources"
cp Resources/* "$app/Contents/Resources/" 2>/dev/null || true
cp .build/release/SpacefastMenubar "$app/Contents/MacOS/Spacefast"
cat > "$app/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleName</key><string>Spacefast</string>
  <key>CFBundleIdentifier</key><string>com.spacefast.menubar</string>
  <key>CFBundleExecutable</key><string>Spacefast</string>
  <key>CFBundlePackageType</key><string>APPL</string>
  <key>CFBundleShortVersionString</key><string>0.1.0</string>
  <key>LSMinimumSystemVersion</key><string>15.0</string>
  <key>LSUIElement</key><true/>
</dict>
</plist>
PLIST
# Sign with a stable identity, so a Keychain "Always Allow" survives rebuilds.
# Ad-hoc signing is a new identity every build, and macOS asks for your
# password again each time. SIGN_IDENTITY overrides; the default is your first
# Apple Development certificate, else ad-hoc.
identity="${SIGN_IDENTITY:-$(security find-identity -v -p codesigning | grep -m1 -o '"Apple Development[^"]*"' | tr -d '"')}"
codesign --force --sign "${identity:--}" "$app" >/dev/null
echo "$app"
