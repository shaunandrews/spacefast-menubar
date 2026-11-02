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
                Divider()
            }
            SpacesPanel().frame(width: panel.listWidth)
        }
        .frame(minWidth: 0, maxWidth: .infinity, maxHeight: .infinity, alignment: .trailing)
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

    var body: some View {
        list
    }

    private var list: some View {
        VStack(alignment: .leading, spacing: 0) {
            if case .signedIn = store.account {
                header
                Divider()
            }
            switch store.account {
            case .signedOut: signedOut
            case .signingIn(let code, let url): signingIn(code: code, url: url)
            case .signedIn:
                content.frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            }
            Divider()
            footer
        }
    }

    // MARK: Header

    private var header: some View {
        HStack(spacing: 8) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 2) {
                    TabPill(selected: store.tab == SpacesStore.favoritesTab) {
                        store.tab = SpacesStore.favoritesTab
                    } label: {
                        Image(systemName: store.tab == SpacesStore.favoritesTab ? "star.fill" : "star")
                    }
                    .help("Favorites")
                    TabPill(selected: store.tab == SpacesStore.allTab) { store.tab = SpacesStore.allTab } label: {
                        Text("All")
                    }
                    ForEach(store.teams) { team in
                        TabPill(selected: store.tab == team.id) { store.tab = team.id } label: { Text(team.name) }
                    }
                }
            }
            Picker("Layout", selection: $layout) {
                Image(systemName: "list.bullet").tag(Layout.list).help("List")
                Image(systemName: "square.grid.2x2").tag(Layout.grid).help("Grid")
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .fixedSize()
            .controlSize(.small)
            Button {
                Task { await store.refresh() }
            } label: {
                Image(systemName: "arrow.clockwise")
            }
            .buttonStyle(.borderless)
            .disabled(store.loading)
            .help("Refresh")
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
    }

    // MARK: States

    private var signedOut: some View {
        VStack(spacing: 10) {
            Text("Sign in to see the Spaces you've made.")
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            Button("Sign in to Spacefast") { store.startSignIn() }
                .buttonStyle(.borderedProminent)
            if let error = store.error {
                Text(error).font(.caption).foregroundStyle(.red).multilineTextAlignment(.center)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(20)
    }

    private func signingIn(code: String, url: URL) -> some View {
        VStack(spacing: 10) {
            Text("Approve this code in your browser").foregroundStyle(.secondary)
            Text(code)
                .font(.system(size: 26, weight: .semibold, design: .monospaced))
                .textSelection(.enabled)
            HStack {
                Button("Open again") { NSWorkspace.shared.open(url) }
                Button("Cancel") { store.cancelSignIn() }
            }
            .controlSize(.small)
            ProgressView().controlSize(.small)
        }
        .frame(maxWidth: .infinity)
        .padding(20)
    }

    @ViewBuilder private var content: some View {
        if let error = store.error, store.spaces.isEmpty {
            VStack(alignment: .leading, spacing: 6) {
                Text("Couldn't load spaces").font(.subheadline.weight(.semibold))
                Text(error).font(.caption).foregroundStyle(.secondary).lineLimit(4)
            }
            .padding(14)
        } else if store.spaces.isEmpty {
            Group {
                if store.tab == SpacesStore.favoritesTab {
                    Text("Star a Space to keep it here.")
                } else if store.loading {
                    ProgressView().controlSize(.small)
                } else {
                    Text("No spaces here yet.")
                }
            }
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity)
            .padding(24)
        } else {
            switch layout {
            case .list:
                ScrollView {
                    VStack(spacing: 2) {
                        ForEach(store.spaces) { SpaceRow(space: $0) }
                    }
                    .padding(6)
                }
            case .grid:
                ScrollView {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 150), spacing: 10)], spacing: 12) {
                        ForEach(store.spaces) { SpaceCard(space: $0) }
                    }
                    .padding(10)
                }
            }
        }
    }

    private var footer: some View {
        HStack(spacing: 14) {
            Button("Open Dashboard") {
                store.openExternally(URL(string: "https://my.spacefast.com/")!)
            }
            .buttonStyle(.borderless)
            Spacer()
            Menu {
                Picker("Open Spaces In", selection: $store.defaultOpenMode) {
                    Text("Browser").tag(OpenMode.browser)
                    Text("Spacefast").tag(OpenMode.app)
                }
                Divider()
                if case .signedIn = store.account {
                    Button("Sign Out") { store.signOut() }
                }
                Button("Quit Spacefast") { NSApp.terminate(nil) }
            } label: {
                Image(systemName: "gearshape")
            }
            .menuStyle(.borderlessButton)
            .menuIndicator(.hidden)
            .fixedSize()
            .help("Settings")
        }
        .font(.callout)
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
    }
}

struct TabPill<Label: View>: View {
    let selected: Bool
    let action: () -> Void
    @ViewBuilder let label: Label

    var body: some View {
        Button(action: action) {
            label
                .font(.callout.weight(selected ? .semibold : .regular))
                .foregroundStyle(selected ? .primary : .secondary)
                .lineLimit(1)
                .padding(.horizontal, 9)
                .padding(.vertical, 4)
                .background(selected ? Color.primary.opacity(0.1) : .clear, in: Capsule())
                .contentShape(Capsule())
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Space views

struct SpaceRow: View {
    let space: Space
    @EnvironmentObject private var store: SpacesStore
    @State private var hovering = false

    var body: some View {
        HStack(spacing: 10) {
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 5) {
                    Text(space.displayTitle).lineLimit(1)
                    SpaceBadges(space: space)
                }
                Text(space.defaultHostname ?? space.slug)
                    .font(.caption).foregroundStyle(.secondary).lineLimit(1)
            }
            Spacer(minLength: 8)
            if hovering {
                SpaceActions(space: space)
            } else {
                Text(space.createdAt, format: .relative(presentation: .numeric, unitsStyle: .abbreviated))
                    .font(.caption).foregroundStyle(.tertiary)
            }
        }
        .frame(height: 33)
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .background(background, in: RoundedRectangle(cornerRadius: 6))
        .contentShape(Rectangle())
        .onHover { hovering = $0 }
        .onTapGesture { store.open(space) }
        .contextMenu { SpaceMenu(space: space) }
    }

    private var background: Color {
        if store.openSpace?.id == space.id { return .accentColor.opacity(0.2) }
        return hovering ? .primary.opacity(0.08) : .clear
    }
}

struct SpaceCard: View {
    let space: Space
    @EnvironmentObject private var store: SpacesStore
    @State private var hovering = false

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Thumbnail(url: space.thumbnailURL)
                .overlay(alignment: .topTrailing) {
                    if hovering {
                        SpaceActions(space: space)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 3)
                            .background(.regularMaterial, in: Capsule())
                            .padding(6)
                    }
                }
                .overlay {
                    RoundedRectangle(cornerRadius: 8)
                        .strokeBorder(store.openSpace?.id == space.id ? Color.accentColor
                            : Color.primary.opacity(hovering ? 0.35 : 0.1), lineWidth: store.openSpace?.id == space.id ? 2 : 1)
                }
            VStack(alignment: .leading, spacing: 1) {
                HStack(spacing: 4) {
                    Text(space.displayTitle).font(.callout.weight(.medium)).lineLimit(1)
                    SpaceBadges(space: space)
                }
                Text(space.createdAt, format: .relative(presentation: .numeric, unitsStyle: .abbreviated))
                    .font(.caption).foregroundStyle(.secondary)
            }
        }
        .contentShape(Rectangle())
        .onHover { hovering = $0 }
        .onTapGesture { store.open(space) }
        .contextMenu { SpaceMenu(space: space) }
        .help(space.defaultHostname ?? space.slug)
    }
}

struct Thumbnail: View {
    let url: URL?

    var body: some View {
        Color.primary.opacity(0.06)
            .aspectRatio(1.45, contentMode: .fit)
            .overlay {
                if let url {
                    AsyncImage(url: url) { phase in
                        if let image = phase.image {
                            image.resizable().aspectRatio(contentMode: .fill)
                        }
                    }
                } else {
                    Image(systemName: "photo").foregroundStyle(.tertiary)
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}

/// A star for favorites, a panel glyph for Spaces set to open in Spacefast.
struct SpaceBadges: View {
    let space: Space
    @EnvironmentObject private var store: SpacesStore

    var body: some View {
        if store.isFavorite(space) {
            Image(systemName: "star.fill").font(.caption2).foregroundStyle(.yellow)
        }
        if store.openOverride(for: space) == .app {
            Image(systemName: "sidebar.left").font(.caption2).foregroundStyle(.secondary)
                .help("Opens in Spacefast")
        }
    }
}

/// Star, copy URL, and open-in-dashboard, shown on hover.
struct SpaceActions: View {
    let space: Space
    @EnvironmentObject private var store: SpacesStore
    @State private var copied = false

    var body: some View {
        HStack(spacing: 8) {
            Button { store.toggleFavorite(space) } label: {
                Image(systemName: store.isFavorite(space) ? "star.fill" : "star")
            }
            .help(store.isFavorite(space) ? "Unfavorite" : "Favorite")
            if let live = space.liveUrl {
                Button {
                    copy(live)
                    copied = true
                    Task {
                        try? await Task.sleep(for: .seconds(1.2))
                        copied = false
                    }
                } label: {
                    Image(systemName: copied ? "checkmark" : "link")
                }
                .help(copied ? "Copied" : "Copy URL")
            }
            if let dashboard = space.dashboardURL {
                Button { store.openExternally(dashboard) } label: {
                    Image(systemName: "slider.horizontal.3")
                }
                .help("Open in dashboard")
            }
        }
        .buttonStyle(.borderless)
    }
}

struct SpaceMenu: View {
    let space: Space
    @EnvironmentObject private var store: SpacesStore

    var body: some View {
        if let live = space.liveURL {
            Button("Open in Browser") { store.open(space, in: .browser) }
            Button("Open in Spacefast") { store.open(space, in: .app) }
            Picker("Always Open In", selection: Binding(
                get: { store.openOverride(for: space) },
                set: { store.setOpenOverride($0, for: space) }
            )) {
                Text("Default").tag(OpenMode?.none)
                Text("Browser").tag(OpenMode?.some(.browser))
                Text("Spacefast").tag(OpenMode?.some(.app))
            }
            Divider()
            Button(store.isFavorite(space) ? "Unfavorite" : "Favorite") { store.toggleFavorite(space) }
            Button("Copy URL") { copy(live.absoluteString) }
        }
        if let dashboard = space.dashboardURL {
            Button("Open in Dashboard") { store.openExternally(dashboard) }
        }
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
