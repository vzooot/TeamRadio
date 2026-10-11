import SwiftUI

/// Driver of the day on the Countdown tab: open for four days after each
/// race. Before voting it asks; after voting it shows the fan result.
@Observable
@MainActor
final class DotdModel {
    var race: Race?
    var drivers: [GameDriver] = []
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
        } else {
            drivers = fallbackDrivers
        }
        userId = await ChatService.currentUserId()
        if let userId { myVote = await DotdService.myVote(round: race.id, userId: userId) }
        tally = await DotdService.tally(round: race.id)
    }

    func vote(_ driverId: String) async -> Bool {
        guard let race, let userId else {
            errorText = "Sign in to iCloud to vote."
            return false
        }
        isSaving = true
        defer { isSaving = false }
        do {
            try await DotdService.vote(driverId, round: race.id, userId: userId)
            myVote = driverId
            errorText = nil
            tally = await DotdService.tally(round: race.id)
            return true
        } catch {
            errorText = "Couldn't save your vote: \(error.localizedDescription)"
            return false
        }
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
                                Task { if await model.vote(driver.id) { dismiss() } }
                            }
                    }
                }
                .disabled(model.isSaving)
            }
            .padding(16)
            .padding(.top, 8)
        }
        .background(Theme.background)
    }
}
