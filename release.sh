#!/usr/bin/env bash
# Cuts a release: ./release.sh 0.1.0
# Builds a universal Spacefast.app, zips it into site/, and points the site's
# download link at it. Publish with: sf publish site --space <space>
set -euo pipefail
cd "$(dirname "$0")"
VERSION="${1:?usage: ./release.sh <version>, e.g. 0.1.0}"

UNIVERSAL=1 VERSION="$VERSION" ./build.sh
zip="Spacefast-Menubar-$VERSION.zip"
rm -f site/Spacefast-Menubar-*.zip
ditto -c -k --sequesterRsrc --keepParent build/Spacefast.app "site/$zip"
printf '/download /%s 302\n' "$zip" > site/_redirects
echo "site/$zip"
