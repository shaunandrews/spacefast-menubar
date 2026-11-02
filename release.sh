#!/usr/bin/env bash
# Cuts a release: ./release.sh 0.2.0 [--no-publish]
#
# 1. Builds a universal Stash.app at that version and zips it into site/releases/.
# 2. Regenerates site/appcast.xml (what Sparkle checks), signing each zip with
#    the EdDSA private key in ~/.config/spacefast-menubar/sparkle-private-key
#    (SPARKLE_KEY_FILE overrides). Without that key, installed copies reject
#    the update: back it up.
# 3. Points /download at the new zip and publishes site/ to its Space.
#
# Every release gets notes: site/releases/Stash-<version>.html, like the others.
# Sparkle shows them in the update window, and tools/release-log.py collects
# them into the public log at /releases/.
set -euo pipefail
cd "$(dirname "$0")"
VERSION="${1:?usage: ./release.sh <version> [--no-publish], e.g. 0.2.0}"
SITE_URL=https://stash.space.fast
KEY_FILE="${SPARKLE_KEY_FILE:-$HOME/.config/spacefast-menubar/sparkle-private-key}"
TOOLS=.build/artifacts/sparkle/Sparkle/bin

[[ -x $TOOLS/generate_appcast ]] || swift package resolve
[[ -f $KEY_FILE ]] || { echo "No Sparkle signing key at $KEY_FILE"; exit 1; }

# Publishing replaces the whole Space and the appcast is rebuilt from the zips
# here, so earlier releases have to be here too. Fresh clones don't have them.
mkdir -p site/releases
if [[ -f site/appcast.xml ]]; then
  for url in $(grep -o 'url="[^"]*\.zip"' site/appcast.xml | sed 's/url="//; s/"$//'); do
    zip="site/releases/$(basename "$url")"
    [[ -f $zip ]] || { echo "Fetching $(basename "$url")"; curl -fsSL -o "$zip" "$url"; }
  done
fi

[[ -f site/releases/Stash-$VERSION.html ]] || {
  echo "Write site/releases/Stash-$VERSION.html first (<h2>Stash $VERSION</h2><ul><li><strong>What's new.</strong> Why it matters.</li></ul>)."
  exit 1
}

UNIVERSAL=1 VERSION="$VERSION" ./build.sh
zip="Stash-$VERSION.zip"
rm -f "site/releases/$zip"
ditto -c -k --sequesterRsrc --keepParent build/Stash.app "site/releases/$zip"

$TOOLS/generate_appcast --ed-key-file "$KEY_FILE" \
  --download-url-prefix "$SITE_URL/releases/" \
  --maximum-versions 5 \
  -o site/appcast.xml site/releases
sed -i '' 's#<title>Spacefast</title>#<title>Stash</title>#' site/appcast.xml # the feed predates the name
python3 tools/release-log.py

# The site's Download button always gets the newest zip; its fine print says how big.
printf '/download /releases/%s 302\n' "$zip" > site/_redirects
size=$(du -k "site/releases/$zip" | awk '{printf "%.1f MB", $1 / 1024}')
sed -i '' -E "s#(Apple silicon and Intel · )[0-9.]+ MB#\1$size#" site/index.html

if [[ "${2:-}" != "--no-publish" ]]; then
  sf publish site --space stash --yes --wait -m "Stash $VERSION"
fi
echo "Released $VERSION. Commit site/appcast.xml, site/_redirects, site/index.html, and site/releases/*.html."
