import Foundation

/// Leaderboards come from the Worker, which is the only place scores are
/// written (server/src/game.js), so nobody can post their own score.
enum LeaderboardService {
    private static let base = URL(string: "https://teamradio-push.eam-adio.workers.dev/game")!

    /// Xcode builds use CloudKit's Development database, TestFlight and the
    /// App Store use Production; each has its own leaderboard.
    private static var environment: String {
        #if DEBUG
        "development"
        #else
        "production"
        #endif
    }

    enum Scope: String { case season, round }

    struct Entry: Decodable, Identifiable, Equatable {
        let userId: String
        let name: String
        let points: Int
        let exact: Int
        let rank: Int
        var id: String { userId }
    }

    struct Me: Decodable, Equatable {
        let userId: String
        let name: String
        let points: Int
        let exact: Int
        let rank: Int
        /// The AI post-race comment, round boards only.
        let comment: String?
    }

    struct Strategist: Decodable, Equatable {
        let name: String
        let points: Int
        let exact: Int
    }

    struct Board: Decodable, Equatable {
        let total: Int
        let top: [Entry]
        let me: Me?
        let strategist: Strategist?
    }

    struct ReactionBoard: Decodable, Equatable {
        struct Entry: Decodable, Equatable, Identifiable {
            let userId: String
            let name: String
            let ms: Int
            let rank: Int
            var id: String { userId }
        }
        struct Me: Decodable, Equatable {
            let name: String
            let ms: Int
            let rank: Int
        }
        let total: Int
        let top: [Entry]
        let me: Me?
    }

    /// This week's Lights Out board; with `ms` it also submits a time.
    static func reaction(user: String?, name: String?, ms: Int?) async -> ReactionBoard? {
        var components = URLComponents(url: base.appending(path: "reaction"), resolvingAgainstBaseURL: false)!
        components.queryItems = [URLQueryItem(name: "env", value: environment)] + (user.map { [URLQueryItem(name: "user", value: $0)] } ?? [])
        var request = URLRequest(url: components.url!)
        request.timeoutInterval = 10
        if let user, let name, let ms {
            request.httpMethod = "POST"
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.httpBody = try? JSONSerialization.data(withJSONObject: ["user": user, "name": name, "ms": ms])
        }
        guard let (data, _) = try? await URLSession.shared.data(for: request) else { return nil }
        return try? JSONDecoder().decode(ReactionBoard.self, from: data)
    }

    struct PlayerPicks: Decodable, Equatable {
        struct Item: Decodable, Equatable, Identifiable {
            let kind: String
            let picked: String?
            let actual: String?
            let points: Int
            let outcome: String
            var id: String { kind }
        }
        let name: String?
        let points: Int?
        let items: [Item]?
        let reasons: [String: String]?
        let error: String?
    }

    /// A player's scored picks for a round ("ai-strategist" for the AI).
    static func playerPicks(round: String, user: String) async -> PlayerPicks? {
        var components = URLComponents(url: base.appending(path: "player"), resolvingAgainstBaseURL: false)!
        components.queryItems = [URLQueryItem(name: "round", value: round), URLQueryItem(name: "user", value: user),
                                 URLQueryItem(name: "env", value: environment)]
        guard let (data, _) = try? await URLSession.shared.data(from: components.url!) else { return nil }
        return try? JSONDecoder().decode(PlayerPicks.self, from: data)
    }

    struct League: Decodable, Equatable, Identifiable {
        struct Member: Decodable, Equatable, Identifiable {
            let userId: String
            let name: String
            let points: Int
            let exact: Int
            let rank: Int
            var id: String { userId }
        }
        let code: String
        let title: String
        let members: [Member]?
        let error: String?
        var id: String { code }
    }

    /// create (title), join or leave (code); returns code + title or an error.
    static func league(_ action: String, user: String, name: String, title: String? = nil, code: String? = nil) async -> League? {
        var request = URLRequest(url: URL(string: "\(base.absoluteString)/league/\(action)?env=\(environment)")!)
        request.httpMethod = "POST"
        request.timeoutInterval = 10
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        var body = ["user": user, "name": name]
        if let title { body["title"] = title }
        if let code { body["code"] = code }
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)
        guard let (data, _) = try? await URLSession.shared.data(for: request) else { return nil }
        return try? JSONDecoder().decode(League.self, from: data)
    }

    static func leagueStandings(code: String, year: String) async -> League? {
        var components = URLComponents(url: base.appending(path: "league"), resolvingAgainstBaseURL: false)!
        components.queryItems = [URLQueryItem(name: "code", value: code), URLQueryItem(name: "env", value: environment),
                                 URLQueryItem(name: "year", value: year)]
        guard let (data, _) = try? await URLSession.shared.data(from: components.url!) else { return nil }
        return try? JSONDecoder().decode(League.self, from: data)
    }

    /// The fan vote for driver of the day (counted by the Worker).
    static func dotd(round: String) async -> DotdService.Tally? {
        var components = URLComponents(url: base.appending(path: "dotd"), resolvingAgainstBaseURL: false)!
        components.queryItems = [URLQueryItem(name: "round", value: round),
                                 URLQueryItem(name: "env", value: environment)]
        guard let (data, _) = try? await URLSession.shared.data(from: components.url!) else { return nil }
        return try? JSONDecoder().decode(DotdService.Tally.self, from: data)
    }

    static func board(scope: Scope, round: String? = nil, year: String, user: String?) async throws -> Board {
        var components = URLComponents(url: base.appending(path: "board"), resolvingAgainstBaseURL: false)!
        var items = [URLQueryItem(name: "scope", value: scope.rawValue),
                     URLQueryItem(name: "env", value: environment),
                     URLQueryItem(name: "year", value: year)]
        if let round { items.append(URLQueryItem(name: "round", value: round)) }
        if let user { items.append(URLQueryItem(name: "user", value: user)) }
        components.queryItems = items
        var request = URLRequest(url: components.url!)
        request.timeoutInterval = 15
        let (data, response) = try await URLSession.shared.data(for: request)
        if let http = response as? HTTPURLResponse, !(200..<300).contains(http.statusCode) {
            throw URLError(.badServerResponse)
        }
        return try JSONDecoder().decode(Board.self, from: data)
    }
}
