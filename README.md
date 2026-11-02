# Spacefast for the menu bar

Your newest Spaces, one click from the menu bar.

- **Tabs** — Favorites (★), All, then one per team.
- **List or grid** — the grid shows each Space's screenshot.
- **Open** — click a Space to open it in your browser, or in a panel attached
  to the left of the list, so it runs like a mini app. Set the default under
  ⚙︎; right-click a Space to pin it to one or the other ("Always Open In").
- **Favorites** — hover and click the star, or right-click.
- **Copy URL** — hover for the link button, or right-click.
- **Resize** — drag the left edge, bottom edge, or bottom-left corner. The
  right edge stays put, so the window grows leftward.

Sign in from the menu: it opens the Spacefast approval page (the device flow)
and asks for `read` access only. The key lives in an owner-only file in
`~/Library/Application Support/Spacefast Menubar/`, like the sf CLI's login;
Sign out revokes it. Until the app has its own device client, the approval page names it
the Spacefast CLI.

```bash
./build.sh                  # build/Spacefast.app (this Mac's architecture, ad-hoc signed)
open build/Spacefast.app
```

Needs macOS 15+ and the Swift toolchain. The menu bar icon is
`Resources/MenuBarIcon.svg`, the symbol from the Spacefast brand book, drawn
as a template image.

## Website

`site/` is https://spaces-menubar.space.fast, a public Space on Shaun's Team.

```bash
./release.sh 0.1.0          # universal build → site/Spacefast-Menubar-0.1.0.zip, /download points at it
sf publish site --space spaces-menubar
```

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
swift build -c release && SPACEFAST_RENDER=site/shots SPACEFAST_DEMO_PAGES=build/demo .build/release/SpacefastMenubar
```

Downloads are ad-hoc signed and not notarized, so macOS asks before the
first launch (the page explains Open Anyway).

## Later: privacy padlocks

The dashboard marks private Spaces with a padlock, read from each Space's
Grants (`accessSummaryKind` in the monorepo's
`packages/common/src/utils/space-access.ts`).
`GET /v1/spaces/{id}/grants` needs `access.manage` on the Space, so this app's
read-only key gets `403 space_management_required`. Asking for `agent` access
would work but gives a viewer write access. The better fix is a `visibility`
field (`public | scoped | private`) on the Space list response: no extra
permission, and no per-Space request.
