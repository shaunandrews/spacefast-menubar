import Foundation

/// The signed-in API key.
struct StoredKey: Codable {
    let id: String
    let secret: String
    /// The access profile it was approved with. Keys from before 0.6.1 have
    /// none: they were read-only.
    var access: String? = nil
}

/// Kept in an owner-only file, like the sf CLI's login, not the Keychain: a
/// locally built app gets a new code identity on rebuild, and the Keychain
/// then asks for the user's password before it can read its own item.
enum KeyFile {
    private static let url = FileManager.default
        .urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        // The app was "Spacefast Menubar" before it was Stash; moving it would sign everyone out.
        .appending(path: "Spacefast Menubar/credentials.json")

    static func load() -> StoredKey? {
        guard let data = try? Data(contentsOf: url) else { return nil }
        return try? JSONDecoder().decode(StoredKey.self, from: data)
    }

    static func save(_ key: StoredKey) {
        let manager = FileManager.default
        let directory = url.deletingLastPathComponent()
        try? manager.createDirectory(at: directory, withIntermediateDirectories: true, attributes: [.posixPermissions: 0o700])
        guard let data = try? JSONEncoder().encode(key) else { return }
        manager.createFile(atPath: url.path, contents: data, attributes: [.posixPermissions: 0o600])
    }

    static func delete() {
        try? FileManager.default.removeItem(at: url)
    }
}
