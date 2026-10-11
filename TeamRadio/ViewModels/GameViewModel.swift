import Foundation
import Observation

/// A driver as the picks UI needs one.
struct GameDriver: Identifiable, Equatable {
    let id: String          // Jolpica driverId
    let code: String
    let familyName: String
    let number: String?
    let teamId: String?
}

/// The prediction game on the Countdown tab: the player's picks for the next
/// grand prix, and their score for the last one.
@Observable
@MainActor
final class GameViewModel {
    enum Access: Equatable {
        case checking
        case needsICloud
        case needsName
        case ready
    }

    /// What the Countdown card shows.
    enum CardState: Equatable {
        case open
        case picked
        case locked
        case missed
        case scored(round: Race, ScoreBreakdown, Prediction)

        static func == (lhs: CardState, rhs: CardState) -> Bool {
            switch (lhs, rhs) {
            case (.open, .open), (.picked, .picked), (.locked, .locked), (.missed, .missed): true
            case let (.scored(a, b, c), .scored(d, e, f)): a.id == d.id && b == e && c == f
            default: false
            }
        }
    }

    var access: Access = .checking
    var race: Race?
    var drivers: [GameDriver] = []
    /// What's stored on the server for the next race.
    var saved: PredictionService.Saved?
    /// The picks being edited in the sheet.
    var draft = Prediction(round: "")
    var isSaving = false
    var errorText: String?
    /// The last round's picks, scored once its results are in.
    private(set) var lastScored: (race: Race, score: ScoreBreakdown, prediction: Prediction)?
    /// The official result for the last round from the scorer: rank, total
    /// players, AI comment and the AI Strategist's score. Nil until scored.
    private(set) var lastBoard: LeaderboardService.Board?

    private var userId: String?
    private var nickname: String { UserDefaults.standard.string(forKey: "chatNickname") ?? "" }

    var wildcard: Wildcard { Wildcard.forRound(race?.roundNumber ?? 1) }

    func lockDate(_ group: PickGroup) -> Date? {
        race.flatMap { GameRules.lockDate(for: $0, group: group) }
    }

    func isLocked(_ group: PickGroup, at now: Date) -> Bool {
        guard let date = lockDate(group) else { return false }
        return now >= date
    }

    /// The next group to lock and when, nil once the race has started.
    func nextLock(at now: Date) -> (group: PickGroup, date: Date)? {
        PickGroup.allCases.compactMap { g in lockDate(g).map { (g, $0) } }.first { $0.1 > now }
    }

    /// Something can still be saved: every open group is filled in.
    func canLockIn(at now: Date) -> Bool {
        let open = PickGroup.allCases.filter { !isLocked($0, at: now) }
        return !open.isEmpty && open.allSatisfy(draft.isComplete)
    }

    func cardState(at now: Date) -> CardState {
        // The last result stays up until three days before the next lock.
        if let lastScored, let first = lockDate(.quali), now < first.addingTimeInterval(-3 * 86400) {
            return .scored(round: lastScored.race, lastScored.score, lastScored.prediction)
        }
        if isLocked(.race, at: now) { return saved == nil ? .missed : .locked }
        return saved == nil ? .open : .picked
    }

    func load(race: Race?, season: [Race]) async {
        self.race = race
        guard let race else { return }
        if draft.round != race.id { draft = Prediction(round: race.id) }

        if let standings = try? await F1API.driverStandings(limit: 30) {
            drivers = standings.map {
                GameDriver(id: $0.driver.driverId, code: $0.driver.shortCode, familyName: $0.driver.familyName,
                           number: $0.driver.permanentNumber, teamId: $0.teamId)
            }
        }

        guard await ChatService.accountAvailable(), let id = await ChatService.currentUserId() else {
            access = .needsICloud
            return
        }
        userId = id
        access = nickname.isEmpty ? .needsName : .ready

        let current = await Result.async { try await PredictionService.mine(round: race.id, userId: id) }
        // A failed fetch keeps what we had; a successful one replaces it,
        // "never picked" included.
        if case .success(let fetched) = current {
            saved = fetched
            if let picks = fetched?.prediction { draft = picks }
        }
        await GameReminders.reschedule(race: race, saved: saved?.groups ?? [])
        await loadLastScore(before: race, season: season, userId: id)
    }

    private func loadLastScore(before race: Race, season: [Race], userId: String) async {
        guard let previous = season.last(where: { $0.roundNumber == race.roundNumber - 1 }),
              let mine = try? await PredictionService.mine(round: previous.id, userId: userId) else {
            lastScored = nil
            return
        }
        async let results = try? F1API.raceResults(round: previous.round)
        async let quali = try? F1API.qualifying(round: previous.round)
        let (r, q) = await (results, quali)
        guard let classification = r?.results, !classification.isEmpty else {
            lastScored = nil
            return
        }
        let wildcard = Wildcard.forRound(previous.roundNumber)
        let score = GameRules.score(mine.prediction, wildcard: wildcard,
                                    qualifying: q?.qualifyingResults ?? [], race: classification)
        lastScored = (previous, score, mine.prediction)
        lastBoard = try? await LeaderboardService.board(scope: .round, round: previous.id,
                                                        year: previous.season, user: userId)
    }

    func driver(_ id: String?) -> GameDriver? {
        drivers.first { $0.id == id }
    }

    /// Saves every group that hasn't locked yet. Only the scorer's
    /// server-time check is authoritative.
    func lockIn(now: Date = .now) async -> Bool {
        guard let userId, !nickname.isEmpty, canLockIn(at: now) else {
            if isLocked(.race, at: now) { errorText = "Picks are locked: the race has started." }
            return false
        }
        let groups = PickGroup.allCases.filter { !isLocked($0, at: now) }
        isSaving = true
        defer { isSaving = false }
        do {
            try await PredictionService.save(draft, groups: groups, userId: userId, name: nickname)
            var picks = saved?.prediction ?? Prediction(round: draft.round)
            groups.forEach { picks.take($0, from: draft) }
            saved = PredictionService.Saved(prediction: picks, groups: (saved?.groups ?? []).union(groups))
            await GameReminders.reschedule(race: race, saved: saved?.groups ?? [])
            errorText = nil
            return true
        } catch {
            errorText = "Couldn't save your picks: \(error.localizedDescription)"
            return false
        }
    }
}

extension Result where Failure == Error {
    /// `Result(catching:)` for async work.
    static func async(_ body: () async throws -> Success) async -> Result {
        do { return .success(try await body()) } catch { return .failure(error) }
    }
}
