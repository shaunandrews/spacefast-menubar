#!/usr/bin/env bash
# Builds Stash.app (menubar-only, no Dock icon) into ./build.
#   UNIVERSAL=1   Apple silicon and Intel in one binary (for releases)
#   VERSION=0.2.0 the version the app reports, and Sparkle compares
#   SIGN_IDENTITY a codesigning identity (default ad-hoc)
set -euo pipefail
cd "$(dirname "$0")"

# The feed Sparkle checks, and the public half of the key release.sh signs with.
FEED_URL=https://stash.space.fast/appcast.xml
PUBLIC_ED_KEY=aQ3ewORUPOKpgWZwA/VCg1F3kYJtrip7krhgFVa80zQ=
VERSION="${VERSION:-0.2.0}"

flags=(-c release)
[[ -n "${UNIVERSAL:-}" ]] && flags+=(--arch arm64 --arch x86_64)
swift build "${flags[@]}"
bin="$(swift build "${flags[@]}" --show-bin-path)"

app=build/Stash.app
rm -rf "$app"
mkdir -p "$app/Contents/MacOS" "$app/Contents/Resources" "$app/Contents/Frameworks"
cp -R Resources/. "$app/Contents/Resources/"
cp "$bin/Stash" "$app/Contents/MacOS/Stash"
# ditto keeps the framework's symlinks intact.
ditto "$bin/Sparkle.framework" "$app/Contents/Frameworks/Sparkle.framework"
# The bundle ID predates the name Stash. Keep it: Sparkle only installs an
# update with the same ID, and preferences live under it.
cat > "$app/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleName</key><string>Stash</string>
  <key>CFBundleDisplayName</key><string>Stash</string>
  <key>CFBundleIdentifier</key><string>com.spacefast.menubar</string>
  <key>CFBundleExecutable</key><string>Stash</string>
  <key>CFBundleIconFile</key><string>AppIcon</string>
  <key>CFBundlePackageType</key><string>APPL</string>
  <key>CFBundleShortVersionString</key><string>$VERSION</string>
  <key>CFBundleVersion</key><string>$VERSION</string>
  <key>LSMinimumSystemVersion</key><string>15.0</string>
  <key>LSUIElement</key><true/>
  <key>SUFeedURL</key><string>$FEED_URL</string>
  <key>SUPublicEDKey</key><string>$PUBLIC_ED_KEY</string>
  <key>SUEnableAutomaticChecks</key><true/>
</dict>
</plist>
PLIST

# Inside out: Sparkle's helpers, the framework, then the app. No --deep.
sign=(codesign --force --sign "${SIGN_IDENTITY:--}")
sparkle="$app/Contents/Frameworks/Sparkle.framework/Versions/B"
for item in "$sparkle/XPCServices/Installer.xpc" "$sparkle/XPCServices/Downloader.xpc" \
            "$sparkle/Autoupdate" "$sparkle/Updater.app"; do
  [[ -e "$item" ]] && "${sign[@]}" "$item" >/dev/null 2>&1
done
"${sign[@]}" "$app/Contents/Frameworks/Sparkle.framework" >/dev/null 2>&1
"${sign[@]}" "$app" >/dev/null 2>&1
echo "$app"
