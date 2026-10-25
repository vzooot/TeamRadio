import Foundation

/// Leaderboards come from the Worker, which is the only place scores are
/// written (server/src/game.js), so nobody can post their own score.
enum LeaderboardService {
    private static let base = URL(string: "https://teamradio-push.eam-adio.workers.dev/game")!

    /// The CloudKit database this build uses, so the boards match the
    /// player's picks (it follows the signing, not Debug/Release).
    private static var environment: String { BuildSigning.isDevelopment ? "development" : "production" }

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

    /// This week's Lights Out board (`week`: "last", "all" for all-time
    /// bests, or a Monday); with `ms` it also submits a time.
    static func reaction(user: String?, name: String?, ms: Int?, week: String? = nil, limit: Int? = nil) async -> ReactionBoard? {
        #if DEBUG
        // -DemoArcade YES: a made-up week of 48 players, for screenshots
        if UserDefaults.standard.bool(forKey: "DemoArcade") {
            let rows = BoardDraftData.rows.prefix(limit ?? 20)
            // with -LightsOutPhase <seconds>, that run is the player's week
            let run = Double(UserDefaults.standard.string(forKey: "LightsOutPhase") ?? "").map { Int($0 * 1000) }
            let mine = run.flatMap { ms in BoardDraftData.rows.first { $0.ms >= ms }?.rank } ?? 17
            return ReactionBoard(total: 48, top: rows.map { .init(userId: $0.me ? (user ?? "me") : $0.name, name: $0.name, ms: $0.ms, rank: $0.rank) },
                                 me: .init(name: "You", ms: run ?? BoardDraftData.me.ms, rank: mine))
        }
        #endif
        var components = URLComponents(url: base.appending(path: "reaction"), resolvingAgainstBaseURL: false)!
        components.queryItems = [URLQueryItem(name: "env", value: environment)] + (user.map { [URLQueryItem(name: "user", value: $0)] } ?? [])
            + (week.map { [URLQueryItem(name: "week", value: $0)] } ?? [])
            + (limit.map { [URLQueryItem(name: "limit", value: String($0))] } ?? [])
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

    struct WallBoard: Decodable, Equatable {
        struct Entry: Decodable, Equatable, Identifiable {
            let userId: String
            let name: String
            let score: Int
            let rank: Int
            var id: String { userId }
        }
        struct Me: Decodable, Equatable {
            let name: String
            let score: Int
            let rank: Int
        }
        let total: Int
        let top: [Entry]
        let me: Me?
    }

    /// This week's Reaction Wall board (`week` as for Lights Out); with
    /// `score` it also submits a run.
    static func wall(user: String?, name: String?, score: Int?, week: String? = nil, limit: Int? = nil) async -> WallBoard? {
        #if DEBUG
        if UserDefaults.standard.bool(forKey: "DemoArcade") {
            let rows = BoardDraftData.rows.prefix(limit ?? 20)
            // with -WallPhase <points>, that run is the player's week
            let run = Int(UserDefaults.standard.string(forKey: "WallPhase") ?? "")
            let mine = run.map { points in BoardDraftData.rows.filter { 96 - $0.rank * 2 > points }.count + 1 } ?? 17
            return WallBoard(total: 48, top: rows.map { .init(userId: $0.me ? (user ?? "me") : $0.name, name: $0.name, score: 96 - $0.rank * 2, rank: $0.rank) },
                             me: .init(name: "You", score: run ?? 62, rank: mine))
        }
        #endif
        var components = URLComponents(url: base.appending(path: "wall"), resolvingAgainstBaseURL: false)!
        components.queryItems = [URLQueryItem(name: "env", value: environment)] + (user.map { [URLQueryItem(name: "user", value: $0)] } ?? [])
            + (week.map { [URLQueryItem(name: "week", value: $0)] } ?? [])
            + (limit.map { [URLQueryItem(name: "limit", value: String($0))] } ?? [])
        var request = URLRequest(url: components.url!)
        request.timeoutInterval = 10
        if let user, let name, let score {
            request.httpMethod = "POST"
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.httpBody = try? JSONSerialization.data(withJSONObject: ["user": user, "name": name, "score": score])
        }
        guard let (data, _) = try? await URLSession.shared.data(for: request) else { return nil }
        return try? JSONDecoder().decode(WallBoard.self, from: data)
    }

    private struct Bests: Decodable {
        let lights: Int?   // ms
        let wall: Int?
    }

    /// Personal bests live on the phone and on the server, so a new phone
    /// or a reinstall keeps them: the better of the two wins on both sides.
    static func syncBests(user: String) async {
        let defaults = UserDefaults.standard
        let lights = defaults.double(forKey: "lightsOutBest")   // seconds
        let wall = defaults.integer(forKey: "wallBest")
        let localMs = lights > 0 ? Int((lights * 1000).rounded()) : nil
        var body: [String: Any] = ["user": user]
        if let localMs { body["lights"] = localMs }
        if wall > 0 { body["wall"] = wall }
        var components = URLComponents(url: base.appending(path: "best"), resolvingAgainstBaseURL: false)!
        components.queryItems = [URLQueryItem(name: "env", value: environment)]
        var request = URLRequest(url: components.url!)
        request.httpMethod = "POST"
        request.timeoutInterval = 10
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)
        guard let (data, _) = try? await URLSession.shared.data(for: request),
              let server = try? JSONDecoder().decode(Bests.self, from: data) else { return }
        await MainActor.run {
            if let ms = server.lights, ms < localMs ?? .max { UserDefaults.standard.set(Double(ms) / 1000, forKey: "lightsOutBest") }
            if let points = server.wall, points > wall { UserDefaults.standard.set(points, forKey: "wallBest") }
        }
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

    /// One scored round of the season duel: the player's and the AI's points.
    struct DuelRound: Decodable, Equatable, Identifiable {
        let round: Int
        let name: String?
        let you: Int?
        let ai: Int?
        var id: Int { round }
    }

    private struct History: Decodable { let rounds: [DuelRound] }

    /// Points per scored round this season, for the player and the AI Strategist.
    static func history(user: String) async -> [DuelRound]? {
        var components = URLComponents(url: base.appending(path: "history"), resolvingAgainstBaseURL: false)!
        components.queryItems = [URLQueryItem(name: "user", value: user), URLQueryItem(name: "env", value: environment)]
        guard let (data, _) = try? await URLSession.shared.data(from: components.url!) else { return nil }
        return (try? JSONDecoder().decode(History.self, from: data))?.rounds
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
