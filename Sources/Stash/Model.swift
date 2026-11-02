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

struct Team: Decodable, Identifiable {
    let id: String
    let name: String
    let slug: String
}

/// Where a Space opens: the browser, or the panel beside the list.
enum OpenMode: String {
    case browser, app
}
