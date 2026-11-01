import SwiftUI

/// The iPhone Duo's right half beside the results (approved draft B,
/// build/mockups/duo2/sheet-2-results.png): the championship as it stood
/// after the round picked on the left, with the places each driver or team
/// gained or lost in that round and the points it brought. A round whose
/// race hasn't run yet shows the table it goes into.
struct StandingsAfterRound: View {
    let model: ResultsViewModel

    @State private var teams = false
    @State private var drivers: [DriverStanding] = []
    @State private var driversBefore: [DriverStanding] = []
    @State private var constructors: [ConstructorStanding] = []
    @State private var constructorsBefore: [ConstructorStanding] = []
    /// Spoiler mode (shared with the results): blurred until tapped.
    @AppStorage("spoilerMode") private var spoilerMode = false
    @State private var revealed = false
    @Environment(\.champion) private var champion

    private var isShielded: Bool { spoilerMode && !revealed }

    /// The last round whose race is in, up to the one picked.
    private var after: Int? {
        guard let round = model.calendarRace?.roundNumber else { return nil }
        return model.raceResults?.isEmpty == false ? round : round - 1
    }

    private var subtitle: String {
        guard let after, after > 0 else { return "BEFORE THE FIRST RACE" }
        let place = model.pickerRaces.first { $0.roundNumber == after }?.circuit.location.locality.uppercased() ?? ""
        let prefix = after == model.calendarRace?.roundNumber ? "AFTER" : "GOING IN · AFTER"
        return "\(prefix) ROUND \(after) · \(place)"
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                header
                    // the rounds strip's height on the left, so the two
                    // switches line up
                    .padding(.bottom, 48)
                picker
                VStack(spacing: 16) {
                    // the title is settled and this is the latest round
                    if !teams, let champion, model.selectedRound == model.pickerRaces.last?.round {
                        ChampionCrown(champion: champion)
                    }
                    table
                }
                .blur(radius: isShielded ? 18 : 0)
                .allowsHitTesting(!isShielded)
                .overlay(alignment: .top) {
                    if isShielded {
                        SpoilerShield(text: "Tap to reveal the standings").frame(height: 300)
                    }
                }
                .contentShape(Rectangle())
                .onTapGesture { if isShielded { revealed = true } }
                .animation(.easeInOut(duration: 0.25), value: isShielded)
                .opacity(model.isSwitching ? 0.35 : 1)
            }
            .padding(.bottom, 32)
        }
        .scrollIndicators(.hidden)
        .onChange(of: model.selectedRound) { _, _ in revealed = false }
        .onChange(of: spoilerMode) { _, _ in revealed = false }
        .task(id: after) {
            guard let after, after > 0 else { return }
            async let d = try? F1API.driverStandings(limit: 40, after: "\(after)")
            async let c = try? F1API.constructorStandings(limit: 20, after: "\(after)")
            async let db = after > 1 ? try? F1API.driverStandings(limit: 40, after: "\(after - 1)") : []
            async let cb = after > 1 ? try? F1API.constructorStandings(limit: 20, after: "\(after - 1)") : []
            let (nd, nc, ndb, ncb) = await (d, c, db, cb)
            withAnimation(.snappy) {
                drivers = nd ?? []
                constructors = nc ?? []
                driversBefore = ndb ?? []
                constructorsBefore = ncb ?? []
            }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(alignment: .top, spacing: 9) {
                TrioSlashes(height: 24).padding(.top, 6)
                Text("STANDINGS")
            }
            .font(.f1(30).italic())
            .foregroundStyle(Theme.chromeText)
            Text(subtitle)
                .font(.f1(12, weight: .semibold))
                .tracking(2)
                .foregroundStyle(Theme.dimText)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .padding(.top, 8)
    }

    private var picker: some View {
        HStack(spacing: 6) {
            ForEach(["DRIVERS", "CONSTRUCTORS"], id: \.self) { title in
                let isSelected = (title == "CONSTRUCTORS") == teams
                Button { teams = title == "CONSTRUCTORS" } label: {
                    Text(title)
                        .font(.f1(14).italic())
                        .tracking(1)
                        .foregroundStyle(isSelected ? Theme.onAccent : Theme.dimText)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 9)
                        .background(RoundedRectangle(cornerRadius: 10)
                            .fill(isSelected ? AnyShapeStyle(Theme.accentGradient) : AnyShapeStyle(Color.white.opacity(0.06))))
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var table: some View {
        VStack(spacing: 0) {
            if teams {
                ForEach(constructors) { entry in
                    let before = constructorsBefore.first { $0.id == entry.id }
                    MoveRow(position: entry.position, code: entry.constructor.name.uppercased(), name: "", detail: nil,
                            tint: Theme.teamColor(entry.constructor.constructorId), points: entry.points,
                            before: before.map { ($0.position, $0.points) })
                        .opensProfile(.team(entry.id))
                    if entry.id != constructors.last?.id { Divider().overlay(Color.white.opacity(0.06)) }
                }
            } else {
                ForEach(drivers) { entry in
                    let before = driversBefore.first { $0.id == entry.id }
                    MoveRow(position: entry.position, code: entry.driver.shortCode, name: entry.driver.familyName,
                            detail: entry.teamName, tint: Theme.teamColor(entry.teamId), points: entry.points,
                            before: before.map { ($0.position, $0.points) })
                        .opensProfile(.driver(entry.id))
                    if entry.id != drivers.last?.id { Divider().overlay(Color.white.opacity(0.06)) }
                }
            }
        }
        .background(
            RoundedRectangle(cornerRadius: 18)
                .fill(Theme.card)
                .overlay(RoundedRectangle(cornerRadius: 18).strokeBorder(Theme.glassStroke, lineWidth: 1))
        )
        .clipShape(RoundedRectangle(cornerRadius: 18))
    }
}

/// A standings line with the move since the round before (▲2, ▼1, –) and
/// the points that round brought.
private struct MoveRow: View {
    let position: String
    let code: String
    let name: String
    let detail: String?
    let tint: Color
    let points: String
    let before: (position: String, points: String)?

    private static let climb = Color(red: 0.3, green: 0.9, blue: 0.5)
    private var lead: Bool { position == "1" }

    private var moved: Int? {
        guard let before, let was = Int(before.position), let now = Int(position) else { return nil }
        return was - now
    }

    private var gained: Int? {
        guard let before, let was = Double(before.points), let now = Double(points) else { return nil }
        return Int(now - was)
    }

    var body: some View {
        HStack(spacing: 10) {
            Group {
                if let moved, moved != 0 {
                    HStack(spacing: 1) {
                        Image(systemName: moved > 0 ? "arrowtriangle.up.fill" : "arrowtriangle.down.fill").font(.system(size: 7))
                        Text("\(abs(moved))").font(.system(size: 11, weight: .bold).monospacedDigit())
                    }
                    .foregroundStyle(moved > 0 ? Self.climb : Theme.live)
                } else {
                    Text("–").font(.system(size: 11, weight: .bold)).foregroundStyle(Theme.faintText)
                }
            }
            .frame(width: 24)
            Text(position)
                .font(.f1Digits(17))
                .foregroundStyle(lead ? Theme.accent : .white)
                .frame(width: 26)
            RoundedRectangle(cornerRadius: 2).fill(tint).frame(width: 4, height: 28)
            VStack(alignment: .leading, spacing: 1) {
                HStack(spacing: 6) {
                    Text(code).font(.f1(15).italic()).foregroundStyle(.white).lineLimit(1)
                    if !name.isEmpty {
                        Text(name).font(.system(size: 12, weight: .medium)).foregroundStyle(Theme.dimText).lineLimit(1)
                    }
                }
                if let detail { Text(detail).font(.system(size: 10.5)).foregroundStyle(Theme.faintText).lineLimit(1) }
            }
            Spacer(minLength: 4)
            VStack(alignment: .trailing, spacing: 1) {
                Text("\(points) PTS").font(.f1Digits(14)).foregroundStyle(lead ? Theme.accent : .white)
                if let gained, gained > 0 {
                    Text("+\(gained)").font(.system(size: 10, weight: .bold).monospacedDigit()).foregroundStyle(Self.climb)
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
    }
}
