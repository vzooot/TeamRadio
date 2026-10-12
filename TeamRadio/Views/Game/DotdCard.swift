import SwiftUI
import UIKit

/// Driver of the day on the Countdown tab: open for four days after each
/// race. Before voting it asks; after voting it shows the fan result.
@Observable
@MainActor
final class DotdModel {
    var race: Race?
    var drivers: [GameDriver] = []
    /// True when `drivers` is the race's finishing order (results are out).
    var driversInFinishingOrder = false
    var myVote: String?
    var tally: DotdService.Tally?
    var isSaving = false
    var errorText: String?
    private var userId: String?

    func load(season: [Race], fallbackDrivers: [GameDriver]) async {
        guard let race = DotdService.openRace(in: season) else {
            self.race = nil
            return
        }
        self.race = race
        // Ballot in finishing order once the results are out, else by standings.
        if let results = try? await F1API.raceResults(round: race.round)?.results, !results.isEmpty {
            drivers = results.map {
                GameDriver(id: $0.driver.driverId, code: $0.driver.shortCode, familyName: $0.driver.familyName,
                           number: $0.driver.permanentNumber, teamId: $0.constructor.constructorId)
            }
            driversInFinishingOrder = true
        } else {
            drivers = fallbackDrivers
            driversInFinishingOrder = false
        }
        userId = await ChatService.currentUserId()
        if let userId { myVote = await DotdService.myVote(round: race.id, userId: userId) }
        tally = await DotdService.tally(round: race.id)
    }

    /// Shows the vote at once (card, bars, total) and saves in the
    /// background; a failed save puts the old state back.
    func vote(_ driverId: String) {
        guard let race, let userId else {
            errorText = "Sign in to iCloud to vote."
            return
        }
        let previousVote = myVote, previousTally = tally
        guard driverId != previousVote else { return }
        myVote = driverId
        tally = Self.adjusted(tally, from: previousVote, to: driverId)
        errorText = nil
        Task {
            do {
                try await DotdService.vote(driverId, round: race.id, userId: userId)
            } catch {
                myVote = previousVote
                tally = previousTally
                errorText = "Couldn't save your vote: \(error.localizedDescription)"
            }
        }
    }

    /// The server's count with this device's change applied, until the
    /// server catches up on the next load.
    static func adjusted(_ tally: DotdService.Tally?, from old: String?, to new: String) -> DotdService.Tally {
        var counts = Dictionary(uniqueKeysWithValues: (tally?.votes ?? []).map { ($0.driverId, $0.count) })
        var total = tally?.total ?? 0
        if let old, let c = counts[old], c > 0 { counts[old] = c - 1 } else { total += 1 }
        counts[new, default: 0] += 1
        let votes = counts.filter { $0.value > 0 }.sorted { $0.value > $1.value }.map {
            DotdService.Tally.Vote(driverId: $0.key, count: $0.value, pct: Int((Double($0.value) / Double(max(total, 1)) * 100).rounded()))
        }
        return DotdService.Tally(total: total, votes: votes)
    }

    func driver(_ id: String?) -> GameDriver? {
        drivers.first { $0.id == id }
    }
}

struct DotdCard: View {
    let model: DotdModel
    let onVote: () -> Void

    var body: some View {
        if let race = model.race {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("FAN VOTE · R\(race.round) \(PicksCard.shortName(race))")
                            .font(.f1(11, weight: .bold))
                            .tracking(2)
                            .foregroundStyle(Color(red: 1, green: 0.75, blue: 0.2))
                        Text("DRIVER OF THE DAY")
                            .font(.f1(22))
                            .foregroundStyle(.white)
                    }
                    Spacer()
                    Image(systemName: "star.circle.fill")
                        .font(.system(size: 28))
                        .foregroundStyle(Color(red: 1, green: 0.75, blue: 0.2))
                }
                if model.myVote == nil {
                    Text("Who impressed you most in \(race.raceName.replacingOccurrences(of: " Grand Prix", with: ""))? Vote, then see what the other fans picked.")
                        .font(.system(size: 13))
                        .foregroundStyle(Theme.dimText)
                        .fixedSize(horizontal: false, vertical: true)
                    Button(action: onVote) { Text("VOTE NOW") }
                        .buttonStyle(GamePrimaryButtonStyle())
                } else {
                    results
                    Button(action: onVote) { Text("CHANGE VOTE") }
                        .buttonStyle(GameOutlineButtonStyle())
                }
            }
            .padding(18)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(Theme.card)
                    .overlay(RoundedRectangle(cornerRadius: 20)
                        .strokeBorder(Color(red: 1, green: 0.75, blue: 0.2).opacity(0.45), lineWidth: 1))
            )
        }
    }

    @ViewBuilder
    private var results: some View {
        let votes = Array((model.tally?.votes ?? []).prefix(3))
        VStack(alignment: .leading, spacing: 8) {
            ForEach(votes) { v in
                let d = model.driver(v.driverId)
                HStack(spacing: 10) {
                    Text(d?.code ?? v.driverId.uppercased())
                        .font(.f1(15))
                        .foregroundStyle(.white)
                        .frame(width: 44, alignment: .leading)
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            Capsule().fill(Color.white.opacity(0.06))
                            Capsule().fill(Theme.teamColor(d?.teamId))
                                .frame(width: max(6, geo.size.width * CGFloat(v.pct) / 100))
                        }
                    }
                    .frame(height: 10)
                    Text("\(v.pct)%")
                        .font(.f1Digits(14))
                        .foregroundStyle(.white)
                        .lineLimit(1)
                        .fixedSize()
                        .frame(minWidth: 50, alignment: .trailing)
                }
            }
            Text(footer)
                .font(.system(size: 12))
                .foregroundStyle(Theme.dimText)
        }
    }

    private var footer: String {
        let mine = model.driver(model.myVote)?.code ?? "—"
        let total = model.tally?.total ?? 0
        return "Your vote: \(mine) · \(total) \(total == 1 ? "vote" : "votes") so far"
    }
}

struct DotdSheet: View {
    @Bindable var model: DotdModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                if let race = model.race {
                    Text("R\(race.round) · \(race.raceName.uppercased())")
                        .font(.f1(11, weight: .bold))
                        .tracking(2)
                        .foregroundStyle(Color(red: 1, green: 0.75, blue: 0.2))
                }
                Text("DRIVER OF THE DAY")
                    .font(.f1(24))
                    .foregroundStyle(.white)
                Text("Tap the driver who impressed you most. You can change your vote for four days after the race.")
                    .font(.system(size: 13))
                    .foregroundStyle(Theme.dimText)
                if let error = model.errorText {
                    Text(error).font(.system(size: 12)).foregroundStyle(Theme.live)
                }
                LazyVGrid(columns: [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)], spacing: 10) {
                    ForEach(model.drivers) { driver in
                        DriverTile(driver: driver, selected: driver.id == model.myVote, tag: nil)
                            .onTapGesture {
                                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                                model.vote(driver.id)
                                dismiss()
                            }
                    }
                }
            }
            .padding(16)
            .padding(.top, 8)
        }
        .background(Theme.background)
    }
}
