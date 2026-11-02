import Combine
import SwiftUI

// Plain AppKit entry point (see main.swift): the UI lives in PanelController's
// own panel, which sets its frame itself.
@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var controller: PanelController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        if Demo.isRendering {
            Task {
                await Demo.run()
                NSApp.terminate(nil)
            }
            return
        }
        controller = PanelController(store: SpacesStore())
    }
}

@MainActor
final class SpacesStore: ObservableObject {
    enum Account {
        case signedOut
        case signingIn(userCode: String, verificationURL: URL)
        case signedIn(StoredKey)
    }

    /// The fixed tabs; every other tab is a team id.
    static let favoritesTab = "favorites"
    static let allTab = "all"
    private static let shown = 20

    @Published private(set) var account: Account
    @Published private(set) var teams: [Team] = []
    @Published private(set) var spacesByTab: [String: [Space]] = [:]
    /// Starred Spaces, newest star first, as snapshots so the tab shows
    /// instantly and keeps Spaces older than the lists reach.
    @Published private(set) var favorites: [Space] {
        didSet { UserDefaults.standard.set(try? JSONEncoder().encode(favorites), forKey: "favorites") }
    }
    /// The Space open in the panel beside the list, if any.
    @Published private(set) var openSpace: SpaceLink?
    private var webModels: [String: WebModel] = [:]
    @Published var defaultOpenMode: OpenMode {
        didSet { UserDefaults.standard.set(defaultOpenMode.rawValue, forKey: "openIn") }
    }
    /// Per-Space overrides of `defaultOpenMode`.
    @Published private(set) var openModes: [String: OpenMode] {
        didSet { UserDefaults.standard.set(openModes.mapValues(\.rawValue), forKey: "openModes") }
    }
    @Published private(set) var error: String?
    @Published private(set) var loading = false
    @Published var tab: String {
        didSet {
            UserDefaults.standard.set(tab, forKey: "tab")
            Task { await loadTab() }
        }
    }

    var spaces: [Space] { tab == Self.favoritesTab ? favorites : spacesByTab[tab] ?? [] }

    private var timer: Timer?
    private var signIn: Task<Void, Never>?
    /// Made-up Spaces for the website's screenshots: no key file, no network.
    private let isDemo: Bool
    private var api: SpacefastAPI? {
        guard !isDemo, case .signedIn(let key) = account else { return nil }
        return SpacefastAPI(token: key.secret)
    }

    init(demo: Bool = false) {
        isDemo = demo
        account = demo ? .signedOut : KeyFile.load().map(Account.signedIn) ?? .signedOut
        let defaults = UserDefaults.standard
        tab = defaults.string(forKey: "tab") ?? Self.allTab
        favorites = defaults.data(forKey: "favorites")
            .flatMap { try? JSONDecoder().decode([Space].self, from: $0) } ?? []
        defaultOpenMode = defaults.string(forKey: "openIn").flatMap(OpenMode.init) ?? .browser
        openModes = (defaults.dictionary(forKey: "openModes") as? [String: String] ?? [:])
            .compactMapValues(OpenMode.init)
        guard !demo else { return }
        Task { await refresh() }
        timer = Timer.scheduledTimer(withTimeInterval: 300, repeats: true) { [weak self] _ in
            Task { await self?.refresh() }
        }
    }

    func stageDemo(teams: [Team], spaces: [Space], favorites: [Space], inApp: [String], tab: String, open: SpaceLink?) {
        guard isDemo else { return }
        account = .signedIn(StoredKey(id: "demo", secret: ""))
        self.teams = teams
        spacesByTab = [Self.allTab: spaces]
        for team in teams { spacesByTab[team.id] = spaces.filter { $0.teamId == team.id } }
        self.favorites = favorites
        openModes = Dictionary(uniqueKeysWithValues: inApp.map { ($0, .app) })
        self.tab = tab
        openSpace = open
    }

    func refresh() async {
        guard let api else { return }
        if let teams = try? await api.listTeams() {
            self.teams = teams
            if ![Self.allTab, Self.favoritesTab].contains(tab), !teams.contains(where: { $0.id == tab }) {
                tab = Self.allTab
            }
        }
        await loadTab()
    }

    private func loadTab() async {
        guard let api, !loading else { return }
        let tab = self.tab
        loading = true
        do {
            if tab == Self.favoritesTab {
                await refreshFavorites(with: api)
            } else {
                let team = tab == Self.allTab ? nil : teams.first { $0.id == tab }?.slug
                let all = try await api.listSpaces(team: team)
                spacesByTab[tab] = Array(all.sorted { $0.createdAt > $1.createdAt }.prefix(Self.shown))
            }
            error = nil
        } catch let failure as SpacefastAPI.Failure where failure.status == 401 {
            forget()
            error = "Your sign-in expired. Sign in again."
        } catch {
            self.error = error.localizedDescription
        }
        loading = false
        // The tab may have changed while this one loaded.
        if self.tab != tab { await loadTab() }
    }

    /// Re-reads each starred Space; a deleted one drops out, any other
    /// failure keeps the snapshot.
    private func refreshFavorites(with api: SpacefastAPI) async {
        let fresh = await withTaskGroup(of: (String, Space?, Bool).self) { group in
            for space in favorites {
                group.addTask {
                    do { return (space.id, try await api.getSpace(space.id), false) } catch let failure as SpacefastAPI.Failure where failure.status == 404 {
                        return (space.id, nil, true)
                    } catch {
                        return (space.id, nil, false)
                    }
                }
            }
            return await group.reduce(into: [String: (Space?, Bool)]()) { $0[$1.0] = ($1.1, $1.2) }
        }
        favorites = favorites.compactMap { space in
            guard let (updated, gone) = fresh[space.id] else { return space }
            return gone ? nil : updated ?? space
        }
    }

    // MARK: Favorites and opening

    func isFavorite(_ space: Space) -> Bool { favorites.contains { $0.id == space.id } }

    func toggleFavorite(_ space: Space) {
        if isFavorite(space) {
            favorites.removeAll { $0.id == space.id }
        } else {
            favorites.insert(space, at: 0)
        }
    }

    func openMode(for space: Space) -> OpenMode { openModes[space.id] ?? defaultOpenMode }
    func openOverride(for space: Space) -> OpenMode? { openModes[space.id] }
    func setOpenOverride(_ mode: OpenMode?, for space: Space) { openModes[space.id] = mode }

    func open(_ space: Space, in mode: OpenMode? = nil) {
        guard let link = space.link else { return }
        switch mode ?? openMode(for: space) {
        case .browser: openExternally(link.url)
        case .app: openSpace = link
        }
    }

    /// Fires when something opens outside the app, so the panel gets out of the way.
    let openedExternally = PassthroughSubject<Void, Never>()

    func openExternally(_ url: URL) {
        NSWorkspace.shared.open(url)
        openedExternally.send()
    }

    func closeSpace() { openSpace = nil }

    func webModel(for link: SpaceLink) -> WebModel {
        if let model = webModels[link.id] { return model }
        let model = WebModel(url: link.url)
        webModels[link.id] = model
        return model
    }

    /// Device sign-in: open the approval page, poll until it's approved.
    func startSignIn() {
        signIn?.cancel()
        error = nil
        signIn = Task {
            let api = SpacefastAPI()
            do {
                let start = try await api.startDevice()
                guard let url = URL(string: start.verificationUrl) else { return }
                account = .signingIn(userCode: start.userCode, verificationURL: url)
                NSWorkspace.shared.open(url)

                let interval = max(start.interval, 2)
                while !Task.isCancelled, Date() < start.expiresAt {
                    try await Task.sleep(for: .seconds(interval))
                    switch try await api.pollDevice(start.deviceCode) {
                    case .pending:
                        continue
                    case .approved(let id, let secret):
                        let key = StoredKey(id: id, secret: secret)
                        KeyFile.save(key)
                        account = .signedIn(key)
                        await refresh()
                        return
                    case .ended(let message):
                        account = .signedOut
                        error = message
                        return
                    }
                }
                if !Task.isCancelled {
                    account = .signedOut
                    error = "That code expired. Try again."
                }
            } catch is CancellationError {
            } catch {
                account = .signedOut
                self.error = error.localizedDescription
            }
        }
    }

    func cancelSignIn() {
        signIn?.cancel()
        account = .signedOut
    }

    func signOut() {
        if case .signedIn(let key) = account {
            // Best effort: drop the key server-side too.
            Task { try? await SpacefastAPI(token: key.secret).revokeKey(key.id) }
        }
        forget()
        error = nil
    }

    private func forget() {
        KeyFile.delete()
        account = .signedOut
        teams = []
        spacesByTab = [:]
    }
}
