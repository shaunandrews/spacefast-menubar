import AppKit
import WebKit

/// Dark-mode thumbnails. The API's screenshots are taken in light mode, so in
/// dark mode the app loads each Space in a hidden dark-appearance web view and
/// snapshots it. One at a time, cached on disk until the Space is republished.
/// A Space with no dark theme comes out looking like its light thumbnail; a
/// private one (its sign-in gate answers 403) keeps the regular thumbnail.
@MainActor
final class DarkThumbnails: NSObject, ObservableObject, WKNavigationDelegate {
    static let shared = DarkThumbnails()

    @Published private(set) var images: [String: NSImage] = [:]

    private var queue: [Space] = []
    private var pending: Set<String> = []
    /// Private Spaces and failures, by cache key: not retried this session.
    private var skipped: Set<String> = []
    private var running = false
    private var finished: CheckedContinuation<Bool, Never>?
    /// Which load the timeout belongs to, so a slow one can't end the next.
    private var loadNumber = 0

    private let directory = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
        .appending(path: "Spacefast Menubar/dark-thumbnails")

    /// The page renders at a desktop size, offscreen; the snapshot is scaled
    /// to the API thumbnail's width.
    private lazy var webView: WKWebView = {
        let view = WKWebView(frame: NSRect(x: 0, y: 0, width: 1440, height: 993))
        view.appearance = NSAppearance(named: .darkAqua) // prefers-color-scheme: dark
        view.navigationDelegate = self
        let window = NSWindow(contentRect: NSRect(x: -30_000, y: -30_000, width: 1440, height: 993),
                              styleMask: [.borderless], backing: .buffered, defer: false)
        window.isReleasedWhenClosed = false
        window.isExcludedFromWindowsMenu = true
        window.ignoresMouseEvents = true
        window.contentView = view
        window.orderFrontRegardless()
        return view
    }()

    func request(_ space: Space) {
        guard !Demo.isRendering, images[space.id] == nil, space.liveURL != nil else { return }
        let key = cacheKey(space)
        guard !pending.contains(key), !skipped.contains(key) else { return }
        if let image = NSImage(contentsOf: file(key)) {
            images[space.id] = image
            return
        }
        pending.insert(key)
        queue.append(space)
        // Claimed now, not when the task starts: one drain, one web view.
        if !running {
            running = true
            Task { await drain() }
        }
    }

    private func drain() async {
        while !queue.isEmpty {
            let space = queue.removeFirst()
            let key = cacheKey(space)
            if let image = await render(space) {
                images[space.id] = image
                try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
                if let tiff = image.tiffRepresentation, let rep = NSBitmapImageRep(data: tiff),
                   let jpeg = rep.representation(using: .jpeg, properties: [.compressionFactor: 0.8]) {
                    try? jpeg.write(to: file(key))
                }
            } else {
                skipped.insert(key)
            }
            pending.remove(key)
        }
        running = false
    }

    private func render(_ space: Space) async -> NSImage? {
        guard let url = space.liveURL else { return nil }
        loadNumber += 1
        let number = loadNumber
        webView.load(URLRequest(url: url))
        let loaded = await withCheckedContinuation { continuation in
            finished = continuation
            Task {
                try? await Task.sleep(for: .seconds(20))
                if self.loadNumber == number { self.finish(false) }
            }
        }
        guard loaded else { return nil }
        try? await Task.sleep(for: .milliseconds(900)) // fonts, images, client rendering
        let config = WKSnapshotConfiguration()
        config.snapshotWidth = 802
        return try? await webView.takeSnapshot(configuration: config)
    }

    private func finish(_ loaded: Bool) {
        finished?.resume(returning: loaded)
        finished = nil
    }

    /// A private Space's sign-in gate (403), or any failing page: stop there,
    /// which ends the load as failed.
    func webView(
        _ webView: WKWebView, decidePolicyFor navigationResponse: WKNavigationResponse
    ) async -> WKNavigationResponsePolicy {
        guard navigationResponse.isForMainFrame,
              let status = (navigationResponse.response as? HTTPURLResponse)?.statusCode else { return .allow }
        return status < 400 ? .allow : .cancel
    }

    nonisolated func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        MainActor.assumeIsolated { finish(true) }
    }

    nonisolated func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        MainActor.assumeIsolated { finish(false) }
    }

    nonisolated func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
        MainActor.assumeIsolated { finish(false) }
    }

    private func cacheKey(_ space: Space) -> String {
        "\(space.id)-\(Int(space.updatedAt?.timeIntervalSince1970 ?? 0))"
    }

    private func file(_ key: String) -> URL { directory.appending(path: "\(key).jpg") }
}

