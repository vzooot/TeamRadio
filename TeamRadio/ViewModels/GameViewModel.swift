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

    private var userId: String?
    private var nickname: String { UserDefaults.standard.string(forKey: "chatNickname") ?? "" }

    var lockDate: Date? { race.flatMap(GameRules.lockDate(for:)) }
    var wildcard: Wildcard { Wildcard.forRound(race?.roundNumber ?? 1) }
    var lockSessionName: String { race.map(GameRules.lockSessionName(for:)) ?? "qualifying" }

    func isLocked(at now: Date) -> Bool {
        guard let lockDate else { return false }
        return now >= lockDate
    }

    func cardState(at now: Date) -> CardState {
        // The last result stays up until three days before the next lock.
        if let lastScored, let lockDate, now < lockDate.addingTimeInterval(-3 * 86400) {
            return .scored(round: lastScored.race, lastScored.score, lastScored.prediction)
        }
        if isLocked(at: now) { return saved == nil ? .missed : .locked }
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
    }

    func driver(_ id: String?) -> GameDriver? {
        drivers.first { $0.id == id }
    }

    /// Saves the draft. Refused after the lock, though only the scorer's
    /// server-time check is authoritative.
    func lockIn(now: Date = .now) async -> Bool {
        guard let userId, !nickname.isEmpty, draft.isComplete else { return false }
        guard !isLocked(at: now) else {
            errorText = "Picks are locked: \(lockSessionName) has started."
            return false
        }
        isSaving = true
        defer { isSaving = false }
        do {
            saved = try await PredictionService.save(draft, userId: userId, name: nickname)
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
