import Foundation

/// Codable both ways: favorites keep a snapshot so their tab shows instantly.
struct Space: Codable, Identifiable {
    struct Thumbnail: Codable { let url: String? }

    let id: String
    let slug: String
    let title: String?
    let teamId: String?
    let teamSlug: String?
    let defaultHostname: String?
    let liveUrl: String?
    let thumbnail: Thumbnail?
    let createdAt: Date
    /// Changes when the Space is republished; keys the dark thumbnail cache.
    let updatedAt: Date?
    /// Discover entries only: who made it, and where to start a copy.
    var credit: String? = nil
    var remixUrl: String? = nil

    var displayTitle: String { title?.isEmpty == false ? title! : slug }
    var liveURL: URL? { liveUrl.flatMap(URL.init(string:)) }
    var thumbnailURL: URL? { thumbnail?.url.flatMap(URL.init(string:)) }
    var dashboardURL: URL? {
        guard let teamSlug else { return nil }
        return URL(string: "https://my.spacefast.com/\(teamSlug)/\(slug)")
    }
    var link: SpaceLink? {
        liveURL.map { SpaceLink(id: id, title: displayTitle, url: $0) }
    }
}

/// What the Space panel needs to open a Space.
struct SpaceLink: Codable, Hashable {
    let id: String
    let title: String
    let url: URL
}

/// One Show & Tell entry, as `GET /v1/show-and-tell/entries` returns it.
struct DiscoverEntry: Decodable {
    let id: String
    let title: String
    let credit: String?
    let liveUrl: String
    let screenshotUrl: String?
    let remixUrl: String?
    let publishedAt: Date
}

extension Space {
    /// A Discover entry shown like any other Space. Its id is the entry's
    /// (`sat_…`), not a Space id, and it has no team or dashboard.
    init(discover entry: DiscoverEntry) {
        let host = URL(string: entry.liveUrl)?.host()
        self.init(
            id: entry.id, slug: host?.components(separatedBy: ".").first ?? entry.id, title: entry.title,
            teamId: nil, teamSlug: nil, defaultHostname: host, liveUrl: entry.liveUrl,
            thumbnail: Thumbnail(url: entry.screenshotUrl), createdAt: entry.publishedAt,
            updatedAt: entry.publishedAt, credit: entry.credit, remixUrl: entry.remixUrl)
    }

    var isDiscoverEntry: Bool { id.hasPrefix("sat_") }

    /// Made in the last 12 hours. Not on Discover, where everything's someone else's.
    var isFresh: Bool { !isDiscoverEntry && Date().timeIntervalSince(createdAt) < 12 * 3600 }
}

struct Team: Decodable, Identifiable {
    let id: String
    let name: String
    let slug: String
}

/// Where a Space opens: the browser, or the panel beside the list.
enum OpenMode: String {
    case browser, app
}
