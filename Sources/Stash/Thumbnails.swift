import AppKit
import CryptoKit

/// Space screenshots from mShots, in light or dark. The API's thumbnail URL is
/// an mShots URL (signed, so private Spaces work); `color_scheme=dark` asks
/// mShots to render with prefers-color-scheme: dark. While a screenshot is
/// still being made, mShots redirects to its "Generating Preview" image, so
/// that answer means "ask again shortly", never a thumbnail to keep.
@MainActor
final class Thumbnails: ObservableObject {
    static let shared = Thumbnails()

    @Published private(set) var images: [URL: NSImage] = [:]
    private var loading: Set<URL> = []

    private let directory = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
        .appending(path: "Spacefast Menubar/thumbnails")

    init() {
        // Left by 0.2–0.4, which rendered dark thumbnails in a hidden web view.
        try? FileManager.default.removeItem(at: directory.deletingLastPathComponent().appending(path: "dark-thumbnails"))
    }

    func url(for space: Space, dark: Bool) -> URL? {
        guard let base = space.thumbnailURL, !base.isFileURL else { return nil }
        guard dark, var components = URLComponents(url: base, resolvingAgainstBaseURL: false) else { return base }
        components.queryItems = (components.queryItems ?? []) + [URLQueryItem(name: "color_scheme", value: "dark")]
        return components.url
    }

    func image(for space: Space, dark: Bool) -> NSImage? {
        url(for: space, dark: dark).flatMap { images[$0] }
    }

    func load(_ space: Space, dark: Bool) async {
        guard let url = url(for: space, dark: dark), images[url] == nil, !loading.contains(url) else { return }
        loading.insert(url)
        defer { loading.remove(url) }

        let file = directory.appending(path: Self.key(url) + ".jpg")
        if let data = try? Data(contentsOf: file), let image = NSImage(data: data) {
            images[url] = image
            return
        }
        // A first screenshot takes mShots a few seconds; keep asking for about a minute.
        for attempt in 0..<12 {
            guard !Task.isCancelled, let (data, response) = try? await URLSession.shared.data(from: url) else { return }
            if response.url?.path.hasSuffix("/mshots/v1/default") == false, let image = NSImage(data: data) {
                images[url] = image
                try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
                try? data.write(to: file)
                return
            }
            try? await Task.sleep(for: .seconds(attempt < 3 ? 2 : 5))
        }
    }

    /// The URL changes when the Space is republished (it names the version),
    /// so it keys the disk cache.
    private static func key(_ url: URL) -> String {
        SHA256.hash(data: Data(url.absoluteString.utf8)).prefix(16).map { String(format: "%02x", $0) }.joined()
    }
}
