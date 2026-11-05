# Stash

Your newest Spacefast Spaces, one click from the menu bar.

- **Tabs** — Favorites (★), All, then one per team.
- **List or grid** — the grid shows each Space's screenshot.
- **Open** — click a Space to open it in your browser, or in a panel attached
  to the left of the list, so it runs like a mini app. Set the default under
  ⚙︎; right-click a Space to pin it to one or the other ("Always Open In").
- **Favorites** — hover and click the star, or right-click.
- **Copy URL** — hover for the link button, or right-click.
- **Resize** — drag the left edge, bottom edge, or bottom-left corner.
- **Keyboard** — arrows move, ⌘← ⌘→ switch teams, Return opens, ⌘C copies the
  link. `?` shows the rest.
- **Dark thumbnails** — in dark mode, Spaces with a dark theme show it: the
  API's mShots URL plus `color_scheme=dark`. Thumbnails mShots is still making
  are retried, not shown as "Generating Preview".
- **Open at Login** — on after the first launch; ⚙︎ turns it off.
- **Discover** — the binoculars tab, after ★: Show & Tell from spacefast.com/discover
  (`GET /v1/show-and-tell/entries`, no sign-in). Entries newer than your last
  visit get a dot. ⚙︎ › Show Discover hides it.
- **Updates** — Sparkle checks daily; ⚙︎ › Check for Updates… checks now.

Sign in from the menu: it opens the Spacefast approval page (the device flow)
and asks for full (`agent`) access: since November 2026 read-only keys get no
thumbnails, and private Spaces in the panel and padlocks need it too. A key
from before 0.6.1 is read-only; Stash revokes it and asks you to sign in once
more. The key lives in an owner-only file in
`~/Library/Application Support/Spacefast Menubar/`, like the sf CLI's login;
Sign out revokes it. Until the app has its own device client, the approval page names it
the Spacefast CLI.

```bash
./build.sh                  # build/Stash.app (this Mac's architecture, ad-hoc signed)
open build/Stash.app
```

Needs macOS 15+ and the Swift toolchain. MIT licensed. The UI is set in
Strichpunkt Sans, bundled in `Resources/Fonts` under the SIL Open Font License
(`OFL.txt` there); the look lives in `Sources/Stash/Theme.swift`. The app icon is a
placeholder from `swift tools/make-icon.swift`. The menu bar icon is
`Resources/MenuBarIcon.svg`, the S symbol from the Spacefast brand book, drawn
as a template image.

## Releasing

```bash
./release.sh 0.3.0          # build, zip, sign the appcast, point /download at it, publish
```

Write `site/releases/Stash-<version>.html` first; release.sh stops without
it. The notes show in Sparkle's update window and on the public log at
https://stash.space.fast/releases/, which `tools/release-log.py` rebuilds.

Installed copies check `https://stash.space.fast/appcast.xml` and only accept
zips signed
with the EdDSA key in `~/.config/spacefast-menubar/sparkle-private-key` (a copy
is in the login Keychain, account `spacefast-menubar`). **Back that key up:**
without it, existing installs can never update again. The public half is in
`build.sh`.

## Website

`site/` is https://stash.space.fast, a public Space on Shaun's Team. Until
0.3.1 the feed lived at spaces-menubar.space.fast, which redirects here for
now; builds from 0.3.1 on check stash.space.fast directly.
`sf publish site` updates it; `release.sh` does that for you.

The screenshots in `site/shots/` use made-up Spaces, never a real account.
To redo them, capture the demo pages, then render the panel offscreen:

```bash
mkdir -p build/demo && for f in tools/demo-pages/*.html; do
  "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome" --headless=new --hide-scrollbars \
    --window-size=1440,900 --screenshot="$PWD/build/demo/$(basename "$f" .html).png" "file://$PWD/$f"
done
"/Applications/Google Chrome.app/Contents/MacOS/Google Chrome" --headless=new --hide-scrollbars \
  --force-device-scale-factor=2 --window-size=680,520 \
  --screenshot="$PWD/build/demo/habit-garden-panel.png" "file://$PWD/tools/demo-pages/habit-garden.html"
swift build -c release && bin=$(swift build -c release --show-bin-path)
STASH_RENDER=site/shots STASH_DEMO_PAGES=build/demo DYLD_FRAMEWORK_PATH="$bin" "$bin/Stash"
```

Downloads are ad-hoc signed and not notarized, so macOS asks before the
first launch (the page explains Open Anyway).

## Later: privacy padlocks

The dashboard marks private Spaces with a padlock, read from each Space's
Grants (`accessSummaryKind` in the monorepo's
`packages/common/src/utils/space-access.ts`).
`GET /v1/spaces/{id}/grants` needs `access.manage` on the Space, so this app's
read-only key got `403 space_management_required`. Since 0.6.1 Stash signs in
with `agent` access, which can read Grants, so padlocks are buildable now. A
`visibility` field (`public | scoped | private`) on the Space list response
would still be better: no per-Space request.
