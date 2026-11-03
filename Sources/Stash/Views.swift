import SwiftUI

enum Layout: String { case list, grid }

/// Fills the panel `PanelController` sizes: an open Space on the left, the
/// list on the right under the menu bar icon.
struct RootView: View {
    @EnvironmentObject private var store: SpacesStore
    @EnvironmentObject private var panel: PanelController

    var body: some View {
        // Trailing-aligned and clipped: as the panel widens, the Space is
        // revealed from behind the list instead of the list sliding sideways.
        // `minWidth: 0` keeps this at the panel's width.
        HStack(spacing: 0) {
            if let link = store.openSpace {
                WebPanel(link: link).frame(width: panel.spaceWidth)
                Rectangle().fill(Theme.hairline).frame(width: 1)
            }
            SpacesPanel().frame(width: panel.listWidth)
        }
        .frame(minWidth: 0, maxWidth: .infinity, maxHeight: .infinity, alignment: .trailing)
        .background(Theme.page)
        .clipped()
        .overlay(alignment: .leading) {
            ResizeArea(cursor: .resizeLeftRight, horizontal: true, vertical: false).frame(width: 6)
                .padding(.bottom, 14)
        }
        .overlay(alignment: .bottom) {
            ResizeArea(cursor: .resizeUpDown, horizontal: false, vertical: true).frame(height: 6)
                .padding(.leading, 14)
        }
        .overlay(alignment: .bottomLeading) {
            ResizeArea(cursor: .frameResize(position: .bottomLeft, directions: .all), horizontal: true, vertical: true)
                .frame(width: 14, height: 14)
        }
    }
}

struct SpacesPanel: View {
    @EnvironmentObject private var store: SpacesStore
    @AppStorage("layout") private var layout = Layout.list
    @State private var tabFades = Fades()

    var body: some View {
        list.overlay {
            if store.showingKeys {
                KeyboardHelp().transition(.opacity.combined(with: .scale(scale: 0.97)))
            }
        }
        .animation(.easeOut(duration: 0.15), value: store.showingKeys)
    }

    private var list: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
            switch store.account {
            case .signedOut: signedOut
            case .signingIn(let code, let url): signingIn(code: code, url: url)
            case .signedIn:
                content.frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            }
        }
    }

    // MARK: Header

    private var signedIn: Bool {
        if case .signedIn = store.account { return true }
        return false
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 6) {
                Text("Stash").font(Theme.font(19, .medium)).foregroundStyle(Theme.text)
                Spacer()
                DashboardButton { store.openExternally(URL(string: "https://my.spacefast.com/")!) }
                if signedIn {
                    LayoutToggle(layout: $layout)
                    RefreshButton(loading: store.loading) { Task { await store.refresh() } }
                }
                SettingsMenu()
            }
            if signedIn { tabs }
        }
        .padding(.horizontal, 12)
        .padding(.top, 12)
        .padding(.bottom, 8)
    }

    /// The tabs sit in a rounded track, like spacefast.com's All / Remixable
    /// toggle. When they all fit they share the track's width; when they
    /// don't, the strip scrolls and fades at whichever end has more.
    private var tabs: some View {
        ViewThatFits(in: .horizontal) {
            tabRow(fill: true)
            ScrollViewReader { proxy in
                ScrollView(.horizontal, showsIndicators: false) { tabRow(fill: false) }
                    .onScrollGeometryChange(for: Fades.self) { geometry in
                        Fades(leading: geometry.contentOffset.x > 1,
                              trailing: geometry.contentOffset.x + geometry.containerSize.width < geometry.contentSize.width - 1)
                    } action: { _, new in
                        withAnimation(.easeOut(duration: 0.15)) { tabFades = new }
                    }
                    .mask { FadeMask(fades: tabFades) }
                    .onChange(of: store.tab) { _, tab in
                        withAnimation(.easeOut(duration: 0.2)) { proxy.scrollTo(tab, anchor: .center) }
                    }
            }
        }
        .background(Theme.slab, in: Capsule())
    }

    private func tabRow(fill: Bool) -> some View {
        HStack(spacing: 2) {
            TabPill(id: SpacesStore.favoritesTab, selected: store.tab == SpacesStore.favoritesTab, fill: fill) {
                store.tab = SpacesStore.favoritesTab
            } label: {
                Image(systemName: store.tab == SpacesStore.favoritesTab ? "star.fill" : "star")
            }
            .help("Favorites")
            .id(SpacesStore.favoritesTab)
            if store.showDiscover {
                TabPill(id: SpacesStore.discoverTab, selected: store.tab == SpacesStore.discoverTab, fill: fill) {
                    store.tab = SpacesStore.discoverTab
                } label: {
                    Image(systemName: store.tab == SpacesStore.discoverTab ? "binoculars.fill" : "binoculars")
                }
                .help("Discover: Spaces people are sharing")
                .id(SpacesStore.discoverTab)
            }
            TabPill(id: SpacesStore.allTab, selected: store.tab == SpacesStore.allTab, fill: fill) {
                store.tab = SpacesStore.allTab
            } label: {
                Text("All")
            }
            .id(SpacesStore.allTab)
            ForEach(store.teams) { team in
                TabPill(id: team.id, selected: store.tab == team.id, fill: fill) { store.tab = team.id } label: {
                    Text(team.name)
                }
                .id(team.id)
            }
        }
        .padding(3)
        // One green pill behind the row, moved to wherever the selected tab
        // is: it slides, rather than one pill vanishing as another appears.
        .backgroundPreferenceValue(TabFrames.self) { frames in
            GeometryReader { proxy in
                if let anchor = frames[store.tab] {
                    let frame = proxy[anchor]
                    Capsule()
                        .fill(Theme.green)
                        .frame(width: frame.width, height: frame.height)
                        .position(x: frame.midX, y: frame.midY)
                        .animation(.spring(response: 0.36, dampingFraction: 0.74), value: frame)
                }
            }
        }
    }

    // MARK: States

    private var signedOut: some View {
        VStack(alignment: .leading, spacing: 14) {
            CardStack(symbol: "sparkle")
            (Text("Every Space you've made,\n") + Text("one click away.").foregroundColor(Theme.accent))
                .font(Theme.font(24, .medium))
                .foregroundStyle(Theme.text)
                .lineSpacing(1)
            Text("Sign in to see your Spaces here. Stash only asks to read them.")
                .font(Theme.font(13))
                .foregroundStyle(Theme.muted)
                .fixedSize(horizontal: false, vertical: true)
            GreenPill(title: "Sign in with Spacefast") { store.startSignIn() }
            if let error = store.error {
                Text(error).font(Theme.font(12)).foregroundStyle(.red)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(20)
    }

    private func signingIn(code: String, url: URL) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Approve this code in your browser.")
                .font(Theme.font(15, .medium))
                .foregroundStyle(Theme.text)
            Text(code)
                .font(Theme.mono(26, .semibold))
                .foregroundStyle(Theme.accent)
                .textSelection(.enabled)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(Theme.slab, in: RoundedRectangle(cornerRadius: Theme.rowRadius))
            HStack(spacing: 8) {
                SlabPill(title: "Open again") { NSWorkspace.shared.open(url) }
                SlabPill(title: "Cancel") { store.cancelSignIn() }
                ProgressView().controlSize(.small).padding(.leading, 4)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(20)
    }

    @ViewBuilder private var content: some View {
        if let error = store.error, store.spaces.isEmpty {
            EmptyNote(symbol: "exclamationmark", title: "Couldn't load your Spaces.", detail: error)
        } else if store.spaces.isEmpty {
            if store.tab == SpacesStore.favoritesTab {
                EmptyNote(symbol: "star.fill", title: "Nothing starred yet.", detail: "Hover a Space and hit ☆ to keep it here.")
            } else if store.loading {
                ProgressView().controlSize(.small).frame(maxWidth: .infinity).padding(28)
            } else if store.tab == SpacesStore.discoverTab {
                EmptyNote(symbol: "binoculars.fill", title: "Nothing on Discover yet.", detail: "Check back soon.")
            } else {
                EmptyNote(symbol: "sparkle", title: "No Spaces here yet.", detail: "Ask your AI to put something on Spacefast.")
            }
        } else {
            ScrollViewReader { proxy in
                ScrollView {
                    switch layout {
                    case .list:
                        VStack(spacing: 2) {
                            ForEach(store.spaces) { SpaceRow(space: $0) }
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                    case .grid:
                        LazyVGrid(columns: [GridItem(.adaptive(minimum: 150), spacing: 10)], spacing: 14) {
                            ForEach(store.spaces) { SpaceCard(space: $0) }
                        }
                        .padding(10)
                    }
                }
                .onChange(of: store.scrollTarget) { _, id in
                    guard let id else { return }
                    withAnimation(.easeOut(duration: 0.15)) { proxy.scrollTo(id) }
                }
            }
        }
    }
}

/// List or grid, as two icons in a slab track.
struct LayoutToggle: View {
    @Binding var layout: Layout

    var body: some View {
        HStack(spacing: 2) {
            segment(.list, "list.bullet", "List")
            segment(.grid, "square.grid.2x2", "Grid")
        }
        .padding(3)
        .background(Theme.slab, in: Capsule())
    }

    private func segment(_ value: Layout, _ symbol: String, _ help: String) -> some View {
        Button { layout = value } label: {
            Image(systemName: symbol)
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(layout == value ? Theme.text : Theme.faint)
                .frame(width: 26, height: 20)
                .background(layout == value ? Theme.raised : .clear, in: Capsule())
                .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .help(help)
    }
}

struct TabPill<Label: View>: View {
    let id: String
    let selected: Bool
    var fill = false
    let action: () -> Void
    @ViewBuilder let label: Label
    @State private var hovering = false

    var body: some View {
        Button(action: action) {
            label
                .font(Theme.font(13, .medium))
                .foregroundStyle(selected ? Theme.ink : hovering ? Theme.text : Theme.muted)
                .lineLimit(1)
                // Never squeezed: a tab is its full name or the strip scrolls.
                .fixedSize()
                .padding(.horizontal, 11)
                .padding(.vertical, 5)
                .frame(maxWidth: fill ? .infinity : nil)
                .background { if hovering && !selected { Capsule().fill(Theme.raised) } }
                .contentShape(Capsule())
                .anchorPreference(key: TabFrames.self, value: .bounds) { [id: $0] }
                .animation(.easeOut(duration: 0.18), value: selected)
        }
        .buttonStyle(.plain)
        .onHover { hovering = $0 }
    }
}

/// Where each tab is, so the one green pill can move to the selected one.
struct TabFrames: PreferenceKey {
    static let defaultValue: [String: Anchor<CGRect>] = [:]
    static func reduce(value: inout [String: Anchor<CGRect>], nextValue: () -> [String: Anchor<CGRect>]) {
        value.merge(nextValue()) { $1 }
    }
}

/// Refresh: the arrow at rest, a centered spinning ring while loading.
struct RefreshButton: View {
    let loading: Bool
    let action: () -> Void
    @State private var hovering = false

    var body: some View {
        Button(action: action) {
            ZStack {
                if loading {
                    Spinner()
                } else {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(hovering ? Theme.text : Theme.muted)
                }
            }
            .frame(width: 26, height: 26)
            .background(hovering ? Theme.raised : Theme.slab, in: Circle())
            .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .disabled(loading)
        .onHover { hovering = $0 }
        .help("Refresh")
    }
}

/// Opens the Spacefast dashboard: a plain label on the slab, first in the header's controls.
struct DashboardButton: View {
    let action: () -> Void
    @State private var hovering = false

    var body: some View {
        Button(action: action) {
            Text("Dashboard")
                .font(Theme.font(12, .medium))
                .foregroundStyle(hovering ? Theme.text : Theme.muted)
                .padding(.horizontal, 11)
                .frame(height: 26)
                .background(hovering ? Theme.raised : Theme.slab, in: Capsule())
                .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .onHover { hovering = $0 }
        .help("Open the Spacefast dashboard")
    }
}

/// Settings, behind a round gear in the header.
struct SettingsMenu: View {
    @EnvironmentObject private var store: SpacesStore
    @State private var hovering = false

    var body: some View {
        Menu {
            Picker("Open Spaces In", selection: $store.defaultOpenMode) {
                Text("Browser").tag(OpenMode.browser)
                Text("Stash").tag(OpenMode.app)
            }
            Toggle("Show Discover", isOn: $store.showDiscover)
            Toggle("Open at Login", isOn: Binding(get: { LaunchAtLogin.isEnabled }, set: { LaunchAtLogin.set($0) }))
            Button("Keyboard Shortcuts") { store.showingKeys = true }
            Divider()
            Button("Check for Updates…") { Updates.shared.checkForUpdates() }
            Button("Release Notes") { store.openExternally(URL(string: "https://stash.space.fast/releases/")!) }
            Text(Updates.shared.versionLabel)
            Divider()
            if case .signedIn = store.account {
                Button("Sign Out") { store.signOut() }
            }
            Button("Quit Stash") { NSApp.terminate(nil) }
        } label: {
            Image(systemName: "gearshape.fill")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(hovering ? Theme.text : Theme.muted)
                .frame(width: 26, height: 26)
                .background(hovering ? Theme.raised : Theme.slab, in: Circle())
                .contentShape(Circle())
        }
        .menuStyle(.button)
        .buttonStyle(.plain)
        .menuIndicator(.hidden)
        .fixedSize()
        .onHover { hovering = $0 }
        .help("Settings")
    }
}

struct EmptyNote: View {
    var symbol = "sparkle"
    let title: String
    let detail: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            CardStack(symbol: symbol).padding(.bottom, 8)
            Text(title).font(Theme.font(15, .medium)).foregroundStyle(Theme.text)
            Text(detail).font(Theme.font(13)).foregroundStyle(Theme.muted).lineLimit(4)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(20)
    }
}

// MARK: - Space views

struct SpaceRow: View {
    let space: Space
    @EnvironmentObject private var store: SpacesStore
    @State private var hovering = false
    @State private var tilt = 0.0

    var body: some View {
        HStack(spacing: 10) {
            SpaceThumbnail(space: space, radius: 6)
                .frame(width: 48)
                // The little screenshot tips up when the row's hovered, a
                // different way each time, like the grid's cards.
                .scaleEffect(hovering ? 1.08 : 1, anchor: .center)
                .rotationEffect(.degrees(hovering ? tilt : 0), anchor: .center)
                .shadow(color: .black.opacity(hovering ? 0.18 : 0), radius: 4, y: 2)
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    if store.isNewOnDiscover(space) { NewDot() }
                    Text(space.displayTitle).font(Theme.font(14, .medium)).foregroundStyle(Theme.text).lineLimit(1)
                    SpaceBadges(space: space)
                    if store.isFreshest(space) { Sticker(text: "fresh", tilt: -4) }
                }
                if let credit = space.credit {
                    Text("\(credit)'s").font(Theme.font(12, .medium)).foregroundStyle(Theme.accent).lineLimit(1)
                } else {
                    Text(space.defaultHostname ?? space.slug).font(Theme.font(12)).foregroundStyle(Theme.muted).lineLimit(1)
                }
            }
            Spacer(minLength: 8)
            if hovering {
                SpaceActions(space: space)
            } else {
                Text(space.createdAt.compactAge).font(Theme.mono(11)).foregroundStyle(Theme.faint)
            }
        }
        .frame(height: 34)
        .padding(.horizontal, 8)
        .padding(.vertical, 7)
        .background(background, in: RoundedRectangle(cornerRadius: Theme.rowRadius))
        .animation(.easeOut(duration: 0.14), value: background)
        .animation(.spring(response: 0.3, dampingFraction: 0.65), value: hovering)
        .contentShape(Rectangle())
        .onHover { inside in
            if inside {
                tilt = Double.random(in: 2...5) * (Bool.random() ? 1 : -1)
                store.hover(space)
            }
            hovering = inside
        }
        .onTapGesture { store.open(space) }
        .contextMenu { SpaceMenu(space: space) }
    }

    private var background: Color {
        if store.openSpace?.id == space.id { return Theme.greenSoft }
        return store.selectedID == space.id ? Theme.wash : .clear
    }
}

struct SpaceCard: View {
    let space: Space
    @EnvironmentObject private var store: SpacesStore
    @State private var hovering = false
    /// Picked fresh on every hover: how far, and which way, the card tips.
    @State private var tilt = 0.0

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            SpaceThumbnail(space: space)
                .overlay {
                    let open = store.openSpace?.id == space.id
                    let selected = store.selectedID == space.id
                    RoundedRectangle(cornerRadius: Theme.thumbRadius)
                        .strokeBorder(open ? Theme.accent : selected ? Theme.text.opacity(0.5) : Theme.hairline,
                                      lineWidth: open || selected ? 2 : 1)
                }
                // Picked up off the pile: a small lift and a tilt, both around
                // the card's center, with the tilt different every time.
                .scaleEffect(hovering ? 1.015 : 1, anchor: .center)
                .rotationEffect(.degrees(hovering ? tilt : 0), anchor: .center)
                .shadow(color: .black.opacity(hovering ? 0.22 : 0), radius: 10, y: 5)
                .overlay(alignment: .topLeading) {
                    if store.isFreshest(space) { Sticker(text: "fresh").padding(8) }
                }
                .overlay(alignment: .topTrailing) {
                    if hovering {
                        SpaceActions(space: space, floating: true)
                            .padding(8)
                            .transition(.opacity.combined(with: .offset(y: -4)))
                    }
                }
                .animation(.spring(response: 0.3, dampingFraction: 0.7), value: hovering)
            VStack(alignment: .leading, spacing: 2) {
                if let credit = space.credit {
                    Text("\(credit)'s").font(Theme.font(11, .medium)).foregroundStyle(Theme.accent).lineLimit(1)
                }
                HStack(spacing: 5) {
                    if store.isNewOnDiscover(space) { NewDot() }
                    Text(space.displayTitle).font(Theme.font(14, .medium)).foregroundStyle(Theme.text).lineLimit(1)
                    SpaceBadges(space: space)
                }
                if space.credit == nil {
                    Text(space.createdAt.compactAge).font(Theme.mono(11)).foregroundStyle(Theme.faint)
                }
            }
            .padding(.horizontal, 2)
        }
        .contentShape(Rectangle())
        .onHover { inside in
            if inside {
                tilt = Double.random(in: 0.4...1.3) * (Bool.random() ? 1 : -1)
                store.hover(space)
            }
            hovering = inside
        }
        .onTapGesture { store.open(space) }
        .contextMenu { SpaceMenu(space: space) }
        .help(space.defaultHostname ?? space.slug)
    }
}

/// A Space's screenshot, dark in dark mode (the light one shows until the dark
/// one arrives), at any size: a card's or a row's little one.
struct SpaceThumbnail: View {
    let space: Space
    var radius = Theme.thumbRadius
    @ObservedObject private var thumbnails = Thumbnails.shared
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        Thumbnail(url: space.thumbnailURL, radius: radius,
                  image: thumbnails.image(for: space, dark: colorScheme == .dark)
                      ?? thumbnails.image(for: space, dark: false))
            .task(id: "\(space.thumbnailURL?.absoluteString ?? "")-\(colorScheme)") {
                await thumbnails.load(space, dark: colorScheme == .dark)
            }
    }
}

struct Thumbnail: View {
    let url: URL?
    var radius = Theme.thumbRadius
    /// The screenshot `Thumbnails` loaded; blank until it arrives.
    var image: NSImage? = nil

    var body: some View {
        Theme.slab
            .aspectRatio(1.45, contentMode: .fit)
            .overlay {
                if let image {
                    Image(nsImage: image).resizable().aspectRatio(contentMode: .fill)
                } else if let url, url.isFileURL {
                    // Demo screenshots: drawn now, since the render won't wait.
                    NSImage(contentsOf: url).map { Image(nsImage: $0).resizable().aspectRatio(contentMode: .fill) }
                } else if url == nil {
                    Image(systemName: "photo").foregroundStyle(Theme.faint)
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: radius))
            .overlay(RoundedRectangle(cornerRadius: radius).strokeBorder(Theme.hairline))
    }
}

/// A green star for favorites, a panel glyph for Spaces set to open in Stash.
struct SpaceBadges: View {
    let space: Space
    @EnvironmentObject private var store: SpacesStore

    var body: some View {
        if store.isFavorite(space) {
            Image(systemName: "star.fill").font(.system(size: 9, weight: .bold)).foregroundStyle(Theme.accent)
                .transition(.scale(scale: 0.2).combined(with: .opacity))
        }
        if store.openOverride(for: space) == .app {
            Image(systemName: "sidebar.left").font(.system(size: 9, weight: .semibold)).foregroundStyle(Theme.muted)
                .help("Opens in Stash")
        }
    }
}

/// The star, with a little show. Starring: it ducks, springs up with a twist,
/// and throws out a ring and specks. Unstarring: it deflates with a wobble and
/// a few grey specks drop out.
struct FavoriteButton: View {
    let space: Space
    @EnvironmentObject private var store: SpacesStore
    @State private var starred = 0
    @State private var unstarred = 0

    var body: some View {
        let on = store.isFavorite(space)
        ActionIcon(help: on ? "Unfavorite" : "Favorite") {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) { store.toggleFavorite(space) }
            if on { unstarred += 1 } else { starred += 1 }
        } glyph: {
            Image(systemName: on ? "star.fill" : "star")
                .foregroundStyle(on ? Theme.accent : Theme.muted)
                .keyframeAnimator(initialValue: StarFrame(), trigger: starred) { star, frame in
                    star.scaleEffect(frame.scale, anchor: .center).rotationEffect(.degrees(frame.angle), anchor: .center)
                } keyframes: { _ in
                    KeyframeTrack(\.scale) {
                        CubicKeyframe(0.8, duration: 0.08)
                        SpringKeyframe(1.16, duration: 0.15, spring: .snappy)
                        SpringKeyframe(1, duration: 0.4, spring: .bouncy)
                    }
                    KeyframeTrack(\.angle) {
                        CubicKeyframe(-12, duration: 0.08)
                        SpringKeyframe(8, duration: 0.15, spring: .snappy)
                        SpringKeyframe(0, duration: 0.4, spring: .bouncy)
                    }
                }
                .keyframeAnimator(initialValue: StarFrame(), trigger: unstarred) { star, frame in
                    star.scaleEffect(frame.scale, anchor: .center).rotationEffect(.degrees(frame.angle), anchor: .center)
                } keyframes: { _ in
                    KeyframeTrack(\.scale) {
                        CubicKeyframe(0.82, duration: 0.14)
                        SpringKeyframe(1, duration: 0.4, spring: .bouncy)
                    }
                    KeyframeTrack(\.angle) {
                        CubicKeyframe(-10, duration: 0.07)
                        CubicKeyframe(8, duration: 0.08)
                        CubicKeyframe(-4, duration: 0.08)
                        CubicKeyframe(0, duration: 0.1)
                    }
                }
                .overlay {
                    StarBurst(trigger: starred)
                    StarDrop(trigger: unstarred)
                }
        }
    }
}

/// Star, copy URL, and open-in-dashboard: one connected bar, shown on hover.
/// Over a screenshot it floats. Copying earns a sticker.
struct SpaceActions: View {
    let space: Space
    var floating = false
    @EnvironmentObject private var store: SpacesStore
    @State private var copied = false

    var body: some View {
        ActionBar(floating: floating) {
            FavoriteButton(space: space)
            if let live = space.liveUrl {
                ActionIcon(help: copied ? "Copied" : "Copy URL") {
                    copy(live)
                    copied = true
                    Task {
                        try? await Task.sleep(for: .seconds(1.4))
                        copied = false
                    }
                } glyph: {
                    Image(systemName: copied ? "checkmark" : "link")
                }
                .overlay(alignment: .leading) {
                    if copied {
                        Sticker(text: "Copied!", tilt: -8)
                            .fixedSize()
                            .offset(x: -66)
                            .transition(.scale(scale: 0.4).combined(with: .opacity))
                    }
                }
            }
            if let dashboard = space.dashboardURL {
                ActionIcon(help: "Open in dashboard") { store.openExternally(dashboard) } glyph: {
                    Image(systemName: "slider.horizontal.3")
                }
            }
        }
        .animation(.spring(response: 0.3, dampingFraction: 0.55), value: copied)
    }
}

struct SpaceMenu: View {
    let space: Space
    @EnvironmentObject private var store: SpacesStore

    var body: some View {
        if let live = space.liveURL {
            Button("Open in Browser") { store.open(space, in: .browser) }
            Button("Open in Stash") { store.open(space, in: .app) }
            Picker("Always Open In", selection: Binding(
                get: { store.openOverride(for: space) },
                set: { store.setOpenOverride($0, for: space) }
            )) {
                Text("Default").tag(OpenMode?.none)
                Text("Browser").tag(OpenMode?.some(.browser))
                Text("Stash").tag(OpenMode?.some(.app))
            }
            Divider()
            if let remix = space.remixUrl.flatMap(URL.init(string:)) {
                Button("Remix") { store.openExternally(remix) }
            }
            Button(store.isFavorite(space) ? "Unfavorite" : "Favorite") { store.toggleFavorite(space) }
            Button("Copy URL") { copy(live.absoluteString) }
        }
        if let dashboard = space.dashboardURL {
            Button("Open in Dashboard") { store.openExternally(dashboard) }
        }
    }
}

/// Marks what's new on Discover.
struct NewDot: View {
    var body: some View {
        Circle().fill(Theme.accent).frame(width: 6, height: 6)
            .accessibilityLabel("New")
    }
}

// MARK: - Tab fades

/// Which ends of the tab strip have more tabs past them.
struct Fades: Equatable {
    var leading = false
    var trailing = false
}

/// Fades the tab strip's ends where it scrolls, so a cut-off tab reads as
/// "more this way" rather than a clipped edge.
struct FadeMask: View {
    let fades: Fades

    var body: some View {
        HStack(spacing: 0) {
            LinearGradient(colors: [.black.opacity(fades.leading ? 0 : 1), .black], startPoint: .leading, endPoint: .trailing)
                .frame(width: 24)
            Color.black
            LinearGradient(colors: [.black, .black.opacity(fades.trailing ? 0 : 1)], startPoint: .leading, endPoint: .trailing)
                .frame(width: 24)
        }
    }
}

// MARK: - Keyboard help

struct KeyboardHelp: View {
    @EnvironmentObject private var store: SpacesStore

    private let rows: [(keys: [String], action: String)] = [
        (["↑", "↓"], "Move"),
        (["←", "→"], "Switch team · move in the grid"),
        (["⌘←", "⌘→"], "Switch team"),
        (["⌘1–9"], "Jump to a tab"),
        (["↩"], "Open"),
        (["⌘↩"], "Open the other way"),
        (["⌘C"], "Copy URL"),
        (["F"], "Favorite"),
        (["D"], "Open in dashboard"),
        (["G"], "List or grid"),
        (["R"], "Refresh"),
        (["⌘W"], "Close the open Space"),
        (["esc"], "Close"),
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Keyboard").font(Theme.font(16, .medium)).foregroundStyle(Theme.text)
                Spacer()
                RoundButton(symbol: "xmark", size: 22, help: "Close") { store.showingKeys = false }
            }
            Grid(alignment: .leading, horizontalSpacing: 12, verticalSpacing: 7) {
                ForEach(rows, id: \.action) { row in
                    GridRow {
                        HStack(spacing: 3) {
                            ForEach(row.keys, id: \.self) { key in
                                Text(key)
                                    .font(Theme.mono(11, .medium))
                                    .foregroundStyle(Theme.text)
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(Theme.raised, in: RoundedRectangle(cornerRadius: 5))
                            }
                        }
                        Text(row.action).font(Theme.font(13)).foregroundStyle(Theme.muted)
                    }
                }
            }
        }
        .padding(16)
        .frame(maxWidth: 310)
        .background(Theme.slab, in: RoundedRectangle(cornerRadius: Theme.panelRadius))
        .overlay(RoundedRectangle(cornerRadius: Theme.panelRadius).strokeBorder(Theme.hairline))
        .shadow(color: .black.opacity(0.5), radius: 24, y: 10)
        .padding(12)
    }
}

// MARK: - Resizing

/// A drag edge on the panel. AppKit owns the cursor here: SwiftUI's
/// push/pop gets out of balance and the hosting view resets it.
struct ResizeArea: NSViewRepresentable {
    let cursor: NSCursor
    let horizontal: Bool
    let vertical: Bool
    @EnvironmentObject private var panel: PanelController

    func makeNSView(context: Context) -> ResizeView { ResizeView() }

    func updateNSView(_ view: ResizeView, context: Context) {
        view.cursor = cursor
        view.onBegin = { panel.beginResize() }
        view.onChange = { panel.updateResize(horizontal: horizontal, vertical: vertical) }
        view.onEnd = { panel.endResize() }
    }

    final class ResizeView: NSView {
        var cursor: NSCursor = .arrow
        var onBegin: () -> Void = {}
        var onChange: () -> Void = {}
        var onEnd: () -> Void = {}
        private var area: NSTrackingArea?
        private var dragging = false

        override func updateTrackingAreas() {
            super.updateTrackingAreas()
            if let area { removeTrackingArea(area) }
            let tracking = NSTrackingArea(
                rect: .zero, options: [.mouseEnteredAndExited, .mouseMoved, .cursorUpdate, .activeAlways, .inVisibleRect],
                owner: self)
            addTrackingArea(tracking)
            area = tracking
        }

        override func resetCursorRects() { addCursorRect(bounds, cursor: cursor) }
        override func cursorUpdate(with event: NSEvent) { cursor.set() }
        override func mouseEntered(with event: NSEvent) { cursor.set() }
        override func mouseMoved(with event: NSEvent) { cursor.set() }
        override func mouseExited(with event: NSEvent) { if !dragging { NSCursor.arrow.set() } }
        override var mouseDownCanMoveWindow: Bool { false }
        override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

        override func mouseDown(with event: NSEvent) {
            dragging = true
            cursor.set()
            onBegin()
        }

        override func mouseDragged(with event: NSEvent) {
            cursor.set()
            onChange()
        }

        override func mouseUp(with event: NSEvent) {
            dragging = false
            onEnd()
            if !bounds.contains(convert(event.locationInWindow, from: nil)) { NSCursor.arrow.set() }
        }
    }
}

private func copy(_ text: String) {
    NSPasteboard.general.clearContents()
    NSPasteboard.general.setString(text, forType: .string)
}
