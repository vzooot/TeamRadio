import CloudKit
import Foundation

/// Driver of the day: one vote per player and race, stored in CloudKit's
/// public database as `dotd-<round>-<userId>` so a second ballot is
/// impossible. The Worker counts the votes cast inside the window
/// (server/src/game.js) and serves the tally, so nobody can stuff the box.
enum DotdService {
    private static var database: CKDatabase { ChatService.container.publicCloudDatabase }

    /// Voting opens two hours after the race starts and stays open four days.
    static func window(for race: Race) -> (opens: Date, closes: Date)? {
        guard let start = race.startDate else { return nil }
        return (start.addingTimeInterval(2 * 3600), start.addingTimeInterval(96 * 3600))
    }

    /// The race whose vote is open right now, if any.
    static func openRace(in season: [Race], at now: Date = .now) -> Race? {
        season.last { race in
            guard let w = window(for: race) else { return false }
            return now >= w.opens && now < w.closes
        }
    }

    private static func recordID(round: String, userId: String) -> CKRecord.ID {
        CKRecord.ID(recordName: "dotd-\(round)-\(userId)")
    }

    /// The player's own vote (a driverId), or nil.
    static func myVote(round: String, userId: String) async -> String? {
        guard let record = try? await database.record(for: recordID(round: round, userId: userId)) else { return nil }
        return record["driverId"] as? String
    }

    static func vote(_ driverId: String, round: String, userId: String) async throws {
        let id = recordID(round: round, userId: userId)
        let record: CKRecord
        do {
            record = try await database.record(for: id)
        } catch let error as CKError where error.code == .unknownItem {
            record = CKRecord(recordType: "DotdVote", recordID: id)
        }
        record["round"] = round
        record["userId"] = userId
        record["driverId"] = driverId
        _ = try await database.save(record)
    }

    struct Tally: Decodable, Equatable {
        struct Vote: Decodable, Equatable, Identifiable {
            let driverId: String
            let count: Int
            let pct: Int
            var id: String { driverId }
        }
        var total: Int
        var votes: [Vote]
    }

    static func tally(round: String) async -> Tally? {
        await LeaderboardService.dotd(round: round)
    }
}
