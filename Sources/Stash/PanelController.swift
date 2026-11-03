import AppKit
import Combine
import SwiftUI
import WebKit

/// Borderless panels can't become key by default; the Space panel's web view needs key.
final class Panel: NSPanel {
    override var canBecomeKey: Bool { true }
}

/// Owns the status item and the panel hanging off it. The panel's frame is
/// set here, never by SwiftUI: the list sits under the menu bar icon and an
/// open Space grows out to its left. (`MenuBarExtra` sizes its window from the
/// content and doesn't reliably shrink back, which left blank bands.)
@MainActor
final class PanelController: NSObject, ObservableObject {
    @Published private(set) var listWidth: CGFloat = PanelController.stored("listWidth", default: 360)
    @Published private(set) var spaceWidth: CGFloat = PanelController.stored("spaceWidth", default: 640)
    private var height: CGFloat = PanelController.stored("panelHeight", default: 560)

    private let store: SpacesStore
    /// None while rendering the website's screenshots.
    private let statusItem = Demo.isRendering ? nil : NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    private let panel = Panel(contentRect: NSRect(x: 0, y: 0, width: 360, height: 560),
                              styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
    private var clickMonitor: Any?
    private var keyMonitor: Any?
    private var drag: (width: CGFloat, height: CGFloat, mouse: NSPoint)?
    private var bag = Set<AnyCancellable>()

    private static let minList: CGFloat = 320
    private static let minSpace: CGFloat = 420

    init(store: SpacesStore) {
        self.store = store
        super.init()

        let background = Self.background()
        let hosting = NSHostingView(rootView: RootView().environmentObject(store).environmentObject(self))
        hosting.sizingOptions = []
        hosting.frame = background.bounds
        hosting.autoresizingMask = [.width, .height]
        background.addSubview(hosting)

        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.level = .popUpMenu
        panel.hidesOnDeactivate = false
        panel.collectionBehavior = [.moveToActiveSpace, .fullScreenAuxiliary]
        panel.contentView = background

        if let button = statusItem?.button {
            button.image = Self.mark
            button.target = self
            button.action = #selector(toggle)
            button.sendAction(on: [.leftMouseDown, .rightMouseDown])
        }

        // Opening or closing a Space, or signing in and out, changes the frame.
        store.$openSpace.dropFirst().removeDuplicates { $0?.id == $1?.id }
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in self?.reframe(duration: 0.3) }
            .store(in: &bag)
        store.$account.dropFirst().receive(on: RunLoop.main)
            .sink { [weak self] _ in self?.reframe(duration: 0.25) }
            .store(in: &bag)

        store.openedExternally.receive(on: RunLoop.main)
            .sink { [weak self] in self?.hide() }
            .store(in: &bag)

        keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            // Not `?? event` on the closure's result: a handled key returns nil.
            let handled = MainActor.assumeIsolated { self?.handleKey(event) ?? false }
            return handled ? nil : event
        }
    }

    // MARK: Keyboard

    /// How many cards a grid row holds at the list's width. Mirrors the grid's
    /// `.adaptive(minimum: 150)` columns, 10pt spacing, and 10pt padding.
    private var gridColumns: Int { max(1, Int((listWidth - 20 + 10) / 160)) }

    private var webViewHasFocus: Bool {
        guard let responder = panel.firstResponder as? NSView else { return false }
        return sequence(first: responder, next: \.superview).contains { $0 is WKWebView }
    }

    /// The panel's whole key map; `?` shows it in the app.
    private func handleKey(_ event: NSEvent) -> Bool {
        guard panel.isKeyWindow else { return false }
        let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        let command = flags.contains(.command)
        let key = event.charactersIgnoringModifiers ?? ""

        // A focused Space gets its own typing; only the keys that leave it are ours.
        if webViewHasFocus {
            if event.keyCode == 53 || (command && key == "w") {
                if command { store.closeSpace() }
                panel.makeFirstResponder(nil)
                return true
            }
            return false
        }
        if event.keyCode == 53 { // esc: the topmost thing closes first
            if store.showingKeys { store.showingKeys = false }
            else if store.openSpace != nil { store.closeSpace() }
            else { hide() }
            return true
        }
        guard case .signedIn = store.account else { return false }

        let grid = UserDefaults.standard.string(forKey: "layout") == Layout.grid.rawValue
        let step = grid ? gridColumns : 1
        switch event.keyCode {
        case 126: store.moveSelection(by: -step) // up
        case 125: store.moveSelection(by: step) // down
        // Left and right move between cards in the grid, between teams in the
        // list; with ⌘ they always switch teams.
        case 123: command || !grid ? store.switchTab(by: -1) : store.moveSelection(by: -1)
        case 124: command || !grid ? store.switchTab(by: 1) : store.moveSelection(by: 1)
        case 115: store.selectEdge(last: false) // home
        case 119: store.selectEdge(last: true) // end
        case 36, 76: // return
            guard let space = store.selectedSpace else { return true }
            let other: OpenMode = store.openMode(for: space) == .app ? .browser : .app
            store.open(space, in: command ? other : nil)
        case 48 where flags.contains(.control): store.switchTab(by: flags.contains(.shift) ? -1 : 1) // ⌃⇥
        default:
            switch (command, key.lowercased()) {
            case (true, let digit) where Int(digit).map((1...9).contains) == true:
                store.selectTab(at: Int(digit)! - 1)
            case (true, "c"): store.copySelectedURL()
            case (true, "w"): store.closeSpace()
            case (_, "r"): Task { await store.refresh() }
            case (false, "["): store.switchTab(by: -1)
            case (false, "]"): store.switchTab(by: 1)
            case (false, "f"): store.selectedSpace.map(store.toggleFavorite)
            case (false, "d"): store.selectedSpace?.dashboardURL.map(store.openExternally)
            case (false, "g"):
                UserDefaults.standard.set((grid ? Layout.list : .grid).rawValue, forKey: "layout")
            case (false, "?"), (false, "/"): store.showingKeys.toggle()
            default: return false
            }
        }
        store.keyboardUsed()
        return true
    }

    // MARK: Showing

    @objc private func toggle() {
        panel.isVisible ? hide() : show()
    }

    func show() {
        let target = frame()
        panel.setFrame(target.offsetBy(dx: 0, dy: 8), display: false)
        panel.alphaValue = 0
        panel.orderFrontRegardless()
        panel.makeKey()
        animate(to: target, alpha: 1, duration: 0.2)
        statusItem?.button?.highlight(true)
        clickMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] _ in
            MainActor.assumeIsolated { self?.hide() }
        }
        Task { await store.refresh() }
    }

    func hide() {
        guard panel.isVisible else { return }
        if let clickMonitor { NSEvent.removeMonitor(clickMonitor) }
        clickMonitor = nil
        statusItem?.button?.highlight(false)
        NSAnimationContext.runAnimationGroup({ ctx in
            ctx.duration = 0.12
            panel.animator().alphaValue = 0
        }, completionHandler: { [weak self] in
            MainActor.assumeIsolated {
                guard let self, self.panel.alphaValue == 0 else { return }
                self.panel.orderOut(nil)
            }
        })
    }

    // MARK: Frame

    /// The list centered under the icon (kept on screen), an open Space to its left.
    private func frame() -> NSRect {
        guard let button = statusItem?.button, let buttonWindow = button.window,
              let screen = buttonWindow.screen ?? NSScreen.main else { return panel.frame }
        let icon = buttonWindow.convertToScreen(button.convert(button.bounds, to: nil))
        let visible = screen.visibleFrame
        let signedIn = if case .signedIn = store.account { true } else { false }
        let width = listWidth + (signedIn && store.openSpace != nil ? spaceWidth + 1 : 0)
        let h = signedIn ? min(max(height, 300), visible.height - 16) : 300
        let listX = min(icon.midX - listWidth / 2, visible.maxX - 8 - listWidth)
        let x = max(listX + listWidth - width, visible.minX + 8)
        return NSRect(x: x, y: visible.maxY - 6 - h, width: width, height: h)
    }

    private func reframe(duration: TimeInterval) {
        guard panel.isVisible else { return }
        animate(to: frame(), duration: duration)
    }

    private func animate(to frame: NSRect, alpha: CGFloat? = nil, duration: TimeInterval) {
        NSAnimationContext.runAnimationGroup { ctx in
            ctx.duration = duration
            ctx.timingFunction = CAMediaTimingFunction(controlPoints: 0.2, 0.9, 0.25, 1)
            panel.animator().setFrame(frame, display: true)
            if let alpha { panel.animator().alphaValue = alpha }
        }
    }

    func stageDemo(listWidth: CGFloat, spaceWidth: CGFloat) {
        self.listWidth = listWidth
        self.spaceWidth = spaceWidth
    }

    // MARK: Resizing

    /// The left edge widens whatever is leftmost: the open Space, else the list.
    func beginResize() {
        drag = (store.openSpace == nil ? listWidth : spaceWidth, height, NSEvent.mouseLocation)
    }

    func updateResize(horizontal: Bool, vertical: Bool) {
        guard let drag, let visible = panel.screen?.visibleFrame else { return }
        let mouse = NSEvent.mouseLocation
        if horizontal {
            let width = drag.width + (drag.mouse.x - mouse.x)
            if store.openSpace == nil {
                listWidth = min(max(width, Self.minList), 900)
            } else {
                spaceWidth = min(max(width, Self.minSpace), visible.width - listWidth - 24)
            }
        }
        if vertical {
            height = min(max(drag.height + (drag.mouse.y - mouse.y), 300), visible.height - 16)
        }
        panel.setFrame(frame(), display: true)
    }

    func endResize() {
        drag = nil
        let defaults = UserDefaults.standard
        defaults.set(listWidth, forKey: "listWidth")
        defaults.set(spaceWidth, forKey: "spaceWidth")
        defaults.set(height, forKey: "panelHeight")
    }

    // MARK: Pieces

    private static func stored(_ key: String, default value: CGFloat) -> CGFloat {
        let saved = UserDefaults.standard.double(forKey: key)
        return saved > 0 ? saved : value
    }

    /// The Spacefast mark from Resources/MenuBarIcon.svg, as a template so it
    /// follows the menu bar's appearance.
    private static let mark: NSImage? = Theme.mark(height: 14)
        ?? NSImage(systemSymbolName: "sparkles.rectangle.stack", accessibilityDescription: "Stash")

    /// A solid slab with big rounded corners and a hairline edge, like
    /// spacefast.com's sections, instead of the system popover's glass.
    private static func background() -> NSView { SlabView(frame: NSRect(x: 0, y: 0, width: 360, height: 560)) }
}

/// The panel's ground: white or near-black with the appearance, which a
/// layer's CGColor doesn't follow on its own.
final class SlabView: NSView {
    override init(frame: NSRect) {
        super.init(frame: frame)
        wantsLayer = true
        layer?.cornerRadius = Theme.panelRadius
        layer?.cornerCurve = .continuous
        layer?.masksToBounds = true
        layer?.borderWidth = 1
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) is not used") }

    override var wantsUpdateLayer: Bool { true }

    override func updateLayer() {
        let dark = effectiveAppearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
        layer?.backgroundColor = NSColor(white: dark ? 0.055 : 1, alpha: 1).cgColor
        layer?.borderColor = NSColor(white: dark ? 1 : 0, alpha: dark ? 0.12 : 0.12).cgColor
    }
}
