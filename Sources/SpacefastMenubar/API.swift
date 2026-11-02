import Foundation

/// The slice of the Spacefast API the menubar uses: device sign-in and the
/// Space list. Each response decodes only the fields read here.
struct SpacefastAPI {
    static let origin = URL(string: "https://api.spacefast.com")!
    static let client = "spacefast-macos/0.1.0"

    var token: String?

    struct Failure: LocalizedError {
        let message: String
        let code: String
        let status: Int
        var errorDescription: String? { message }
    }

    struct DeviceStart: Decodable {
        let deviceCode: String
        let userCode: String
        let verificationUrl: String
        let interval: Double
        let expiresAt: Date
    }

    enum DevicePoll {
        case pending
        case approved(id: String, secret: String)
        case ended(String)
    }

    func startDevice() async throws -> DeviceStart {
        // No clientId yet: the server defaults to the CLI's. `read` is all a
        // viewer needs.
        try await request("/v1/auth/device", method: "POST", body: ["access": "read"], authenticated: false)
    }

    func pollDevice(_ deviceCode: String) async throws -> DevicePoll {
        struct Poll: Decodable {
            struct Key: Decodable { let id: String; let secret: String }
            let status: String
            let apiKey: Key?
        }
        do {
            let poll: Poll = try await request(
                "/v1/auth/device/poll", method: "POST", body: ["deviceCode": deviceCode], authenticated: false
            )
            switch poll.status {
            case "approved":
                guard let key = poll.apiKey else { return .ended("Sign-in finished without a key.") }
                return .approved(id: key.id, secret: key.secret)
            case "denied": return .ended("Sign-in was denied.")
            case "expired": return .ended("That code expired. Try again.")
            case "consumed": return .ended("That code was already used. Try again.")
            default: return .pending
            }
        } catch let failure as Failure where ["authorization_pending", "slow_down"].contains(failure.code) {
            // RFC 8628 reports "keep waiting" as an error code, not a status.
            return .pending
        }
    }

    func listSpaces(team: String? = nil) async throws -> [Space] {
        var path = "/v1/spaces?limit=100"
        if let team, let encoded = team.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) {
            path += "&team=\(encoded)"
        }
        return try await request(path)
    }

    func listTeams() async throws -> [Team] {
        try await request("/v1/teams")
    }

    func getSpace(_ id: String) async throws -> Space {
        try await request("/v1/spaces/\(id)")
    }

    func revokeKey(_ id: String) async throws {
        let _: Empty = try await request("/v1/api-keys/\(id)", method: "DELETE")
    }

    private struct Empty: Decodable {}
    private struct Envelope<T: Decodable>: Decodable { let data: T }
    private struct Problem: Decodable { let code: String?; let detail: String?; let title: String? }

    private func request<T: Decodable>(
        _ path: String, method: String = "GET", body: [String: String]? = nil, authenticated: Bool = true
    ) async throws -> T {
        var request = URLRequest(url: URL(string: path, relativeTo: Self.origin)!)
        request.httpMethod = method
        request.setValue("application/json", forHTTPHeaderField: "accept")
        request.setValue(Self.client, forHTTPHeaderField: "x-spacefast-client")
        if authenticated, let auth = token {
            request.setValue("Bearer \(auth)", forHTTPHeaderField: "authorization")
        }
        if let body {
            request.setValue("application/json", forHTTPHeaderField: "content-type")
            request.httpBody = try JSONEncoder().encode(body)
        }

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await URLSession.shared.data(for: request)
        } catch {
            throw Failure(message: "Couldn't reach Spacefast. Check your connection.", code: "network", status: 0)
        }
        let status = (response as? HTTPURLResponse)?.statusCode ?? 0

        guard (200..<300).contains(status) else {
            let problem = try? JSONDecoder().decode(Problem.self, from: data)
            throw Failure(
                message: problem?.detail ?? problem?.title ?? "Spacefast answered \(status).",
                code: problem?.code ?? "http_\(status)",
                status: status
            )
        }
        if T.self == Empty.self { return Empty() as! T }

        return try Self.decoder.decode(Envelope<T>.self, from: data).data
    }

    private static let decoder: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .custom { decoder in
            let raw = try decoder.singleValueContainer().decode(String.self)
            let formatter = ISO8601DateFormatter()
            formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            if let date = formatter.date(from: raw) { return date }
            formatter.formatOptions = [.withInternetDateTime]
            if let date = formatter.date(from: raw) { return date }
            throw DecodingError.dataCorrupted(.init(codingPath: decoder.codingPath, debugDescription: raw))
        }
        return decoder
    }()
}
