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
