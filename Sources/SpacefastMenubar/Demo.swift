import AppKit
import SwiftUI

/// Renders the panel with made-up Spaces for the website's screenshots, never
/// your own. Run the bare binary (its own preferences, no status item):
///
///     SPACEFAST_RENDER=site/shots SPACEFAST_DEMO_PAGES=build/demo .build/release/SpacefastMenubar
///
/// `SPACEFAST_DEMO_PAGES` holds `<slug>.png` screenshots of tools/demo-pages.
@MainActor
enum Demo {
    static let renderURL = ProcessInfo.processInfo.environment["SPACEFAST_RENDER"].map { URL(fileURLWithPath: $0) }
    static let pagesURL = ProcessInfo.processInfo.environment["SPACEFAST_DEMO_PAGES"].map { URL(fileURLWithPath: $0) }
    static var isRendering: Bool { renderURL != nil }

    /// The open Space's page, preferring a capture at the panel's own shape.
    static func pageImage(for id: String) -> NSImage? {
        guard let slug = spaces.first(where: { $0.id == id })?.slug, let pagesURL else { return nil }
        return NSImage(contentsOf: pagesURL.appending(path: "\(slug)-panel.png"))
            ?? NSImage(contentsOf: pagesURL.appending(path: "\(slug).png"))
    }

    static let teams = [
        Team(id: "personal", name: "Personal", slug: "personal"),
        Team(id: "studio", name: "Northwind Studio", slug: "northwind"),
    ]

    static let spaces: [Space] = {
        let entries: [(slug: String, title: String, team: String, hoursAgo: Double)] = [
            ("habit-garden", "Habit Garden", "personal", 0.6),
            ("q4-launch", "Q4 Launch Plan", "studio", 3),
            ("lisbon-in-may", "Lisbon in May", "personal", 7),
            ("synth-pad", "Synth Pad", "personal", 26),
            ("brand-moodboard", "Brand Moodboard", "studio", 50),
            ("sourdough-log", "Sourdough Starter Log", "personal", 74),
            ("pricing-calculator", "Pricing Calculator", "studio", 120),
            ("book-club", "Book Club Picks", "personal", 190),
        ]
        return entries.map { entry in
            Space(
                id: "spc_demo_\(entry.slug)", slug: entry.slug, title: entry.title,
                teamId: entry.team, teamSlug: entry.team, defaultHostname: "\(entry.slug).space.fast",
                liveUrl: "https://\(entry.slug).space.fast/",
                thumbnail: Space.Thumbnail(url: pagesURL?.appending(path: "\(entry.slug).png").absoluteString),
                createdAt: Date().addingTimeInterval(-entry.hoursAgo * 3600))
        }
    }()

    private struct Scene {
        let name: String
        let layout: Layout
        let listWidth: CGFloat
        let open: Bool
    }

    private static let scenes = [
        Scene(name: "list", layout: .list, listWidth: 360, open: false),
        Scene(name: "grid", layout: .grid, listWidth: 540, open: false),
        Scene(name: "panel", layout: .list, listWidth: 360, open: true),
    ]
    private static let height: CGFloat = 560

    static func run() async {
        guard let out = renderURL else { return }
        try? FileManager.default.createDirectory(at: out, withIntermediateDirectories: true)
        let store = SpacesStore(demo: true)
        let panel = PanelController(store: store)
        let byID = Dictionary(uniqueKeysWithValues: spaces.map { ($0.id, $0) })
        let favorites = ["habit-garden", "q4-launch"].compactMap { byID["spc_demo_\($0)"] }
        let inApp = ["spc_demo_habit-garden", "spc_demo_pricing-calculator"]

        for scene in scenes {
            UserDefaults.standard.set(scene.layout.rawValue, forKey: "layout")
            store.stageDemo(teams: teams, spaces: spaces, favorites: favorites, inApp: inApp,
                            tab: SpacesStore.allTab, open: scene.open ? spaces[0].link : nil)
            panel.stageDemo(listWidth: scene.listWidth, spaceWidth: 680)
            let width = scene.listWidth + (scene.open ? 681 : 0)

            for (appearance, suffix) in [(NSAppearance.Name.aqua, "light"), (.darkAqua, "dark")] {
                let host = NSHostingView(rootView:
                    RootView()
                        .background(Color(nsColor: .windowBackgroundColor))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .environmentObject(store).environmentObject(panel))
                host.appearance = NSAppearance(named: appearance)
                host.frame = NSRect(x: 0, y: 0, width: width, height: height)
                // Never on screen: far off to the side, and see-through.
                let window = NSWindow(contentRect: NSRect(x: -30_000, y: -30_000, width: width, height: height),
                                      styleMask: [.borderless], backing: .buffered, defer: false)
                window.isReleasedWhenClosed = false
                window.alphaValue = 0
                window.backgroundColor = .clear
                window.contentView = host
                window.orderFrontRegardless()
                try? await Task.sleep(for: .milliseconds(600))
                host.layoutSubtreeIfNeeded()
                if let rep = host.bitmapImageRepForCachingDisplay(in: host.bounds) {
                    host.cacheDisplay(in: host.bounds, to: rep)
                    try? rep.representation(using: .png, properties: [:])?
                        .write(to: out.appending(path: "\(scene.name)-\(suffix).png"))
                }
                window.orderOut(nil)
                window.close()
            }
        }
    }
}
