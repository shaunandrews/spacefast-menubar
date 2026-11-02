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
./build.sh                  # build/Spacefast.app
open build/Spacefast.app
```

Needs macOS 15+ and the Swift toolchain. The build signs with your first Apple
Development certificate (`SIGN_IDENTITY` overrides), else ad-hoc. The menu bar
icon is `Resources/MenuBarIcon.svg`, drawn as a template image.

## Later: privacy padlocks

The dashboard marks private Spaces with a padlock, read from each Space's
Grants (`accessSummaryKind` in the monorepo's
`packages/common/src/utils/space-access.ts`).
`GET /v1/spaces/{id}/grants` needs `access.manage` on the Space, so this app's
read-only key gets `403 space_management_required`. Asking for `agent` access
would work but gives a viewer write access. The better fix is a `visibility`
field (`public | scoped | private`) on the Space list response: no extra
permission, and no per-Space request.
