import SwiftUI

/// Standings tab: the complete drivers' and constructors' championships.
struct StandingsTabView: View {
    enum Mode: String, CaseIterable {
        case drivers = "DRIVERS"
        case constructors = "CONSTRUCTORS"
    }

    @State private var model = StandingsViewModel()
    @State private var mode: Mode = .drivers

    var body: some View {
        ZStack {
            Theme.background.ignoresSafeArea()

            RadialGradient(
                colors: [Theme.accent.opacity(0.14), .clear],
                center: .top, startRadius: 0, endRadius: 380
            )
            .ignoresSafeArea()

            RadialGradient(
                colors: [Theme.live.opacity(0.10), .clear],
                center: .bottomTrailing, startRadius: 0, endRadius: 460
            )
            .ignoresSafeArea()

            RadialGradient(
                colors: [Theme.violet.opacity(0.08), .clear],
                center: .leading, startRadius: 0, endRadius: 420
            )
            .ignoresSafeArea()

            switch model.phase {
            case .loading:
                LoadingView()
            case .failed(let message):
                ErrorView(message: message) {
                    Task { await model.load() }
                }
            case .loaded:
                loadedContent
            }
        }
        .task { await model.load() }
    }

    private var loadedContent: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 9) {
                        TrioSlashes(height: 24)
                        Text("STANDINGS")
                    }
                        .font(.f1(30).italic())
                        .foregroundStyle(Theme.chromeText)
                    Text("WORLD CHAMPIONSHIP")
                        .font(.f1(12, weight: .semibold))
                        .tracking(2)
                        .foregroundStyle(Theme.dimText)
                }
                .padding(.top, 8)

                modePicker

                if mode == .drivers {
                    fullDriversList
                } else {
                    fullConstructorsList
                }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 32)
        }
        .refreshable { await model.load() }
    }

    private var modePicker: some View {
        HStack(spacing: 6) {
            ForEach(Mode.allCases, id: \.self) { candidate in
                let isSelected = candidate == mode
                Button {
                    mode = candidate
                } label: {
                    Text(candidate.rawValue)
                        .font(.f1(14).italic())
                        .tracking(1)
                        .foregroundStyle(isSelected ? Theme.onAccent : Theme.dimText)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 9)
                        .background(
                            RoundedRectangle(cornerRadius: 10)
                                .fill(isSelected ? AnyShapeStyle(Theme.accentGradient) : AnyShapeStyle(Color.white.opacity(0.06)))
                        )
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var fullDriversList: some View {
        VStack(spacing: 0) {
            let leaderPoints = Double(model.drivers.first?.points ?? "") ?? 0
            ForEach(model.drivers) { entry in
                FullDriverRow(entry: entry, leaderPoints: leaderPoints)
                if entry.id != model.drivers.last?.id {
                    Divider().overlay(Color.white.opacity(0.06))
                }
            }
        }
        .background(
            RoundedRectangle(cornerRadius: 18)
                .fill(Theme.card)
                .overlay(
                    RoundedRectangle(cornerRadius: 18)
                        .strokeBorder(Theme.glassStroke, lineWidth: 1)
                )
        )
        .clipShape(RoundedRectangle(cornerRadius: 18))
    }

    private var fullConstructorsList: some View {
        VStack(spacing: 0) {
            let leaderPoints = Double(model.constructors.first?.points ?? "") ?? 0
            ForEach(model.constructors) { entry in
                FullConstructorRow(entry: entry, leaderPoints: leaderPoints)
                if entry.id != model.constructors.last?.id {
                    Divider().overlay(Color.white.opacity(0.06))
                }
            }
        }
        .background(
            RoundedRectangle(cornerRadius: 18)
                .fill(Theme.card)
                .overlay(
                    RoundedRectangle(cornerRadius: 18)
                        .strokeBorder(Theme.glassStroke, lineWidth: 1)
                )
        )
        .clipShape(RoundedRectangle(cornerRadius: 18))
    }
}

struct FullDriverRow: View {
    let entry: DriverStanding
    let leaderPoints: Double

    private var gapToLeader: String? {
        guard entry.position != "1",
              let points = Double(entry.points), leaderPoints > points else { return nil }
        return "-\(Int(leaderPoints - points))"
    }

    var body: some View {
        HStack(spacing: 12) {
            Text(entry.position)
                .font(.f1Digits(18))
                .foregroundStyle(entry.position == "1" ? Theme.accent : .white)
                .frame(width: 30, alignment: .center)

            RoundedRectangle(cornerRadius: 2)
                .fill(Theme.teamColor(entry.teamId))
                .frame(width: 4, height: 30)

            VStack(alignment: .leading, spacing: 1) {
                HStack(spacing: 6) {
                    Text(entry.driver.shortCode)
                        .font(.f1(16).italic())
                        .foregroundStyle(.white)
                    if let number = entry.driver.permanentNumber {
                        Text("#\(number)")
                            .font(.system(size: 11, weight: .bold).monospacedDigit())
                            .foregroundStyle(Theme.faintText)
                    }
                    Text("\(entry.driver.givenName) \(entry.driver.familyName)")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(Theme.dimText)
                        .lineLimit(1)
                }
                Text(entry.teamName)
                    .font(.system(size: 11))
                    .foregroundStyle(Theme.faintText)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 1) {
                Text("\(entry.points) PTS")
                    .font(.f1Digits(15))
                    .foregroundStyle(entry.position == "1" ? Theme.accent : .white)
                HStack(spacing: 6) {
                    if let wins = Int(entry.wins), wins > 0 {
                        Text("\(wins)W")
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundStyle(Theme.dimText)
                    }
                    if let gap = gapToLeader {
                        Text(gap)
                            .font(.system(size: 10, weight: .semibold).monospacedDigit())
                            .foregroundStyle(Theme.faintText)
                    }
                }
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 9)
    }
}

struct FullConstructorRow: View {
    let entry: ConstructorStanding
    let leaderPoints: Double

    private var gapToLeader: String? {
        guard entry.position != "1",
              let points = Double(entry.points), leaderPoints > points else { return nil }
        return "-\(Int(leaderPoints - points))"
    }

    var body: some View {
        HStack(spacing: 12) {
            Text(entry.position)
                .font(.f1Digits(18))
                .foregroundStyle(entry.position == "1" ? Theme.accent : .white)
                .frame(width: 30, alignment: .center)

            RoundedRectangle(cornerRadius: 2)
                .fill(Theme.teamColor(entry.constructor.constructorId))
                .frame(width: 4, height: 30)

            Text(entry.constructor.name)
                .font(.f1(16).italic())
                .foregroundStyle(.white)

            Spacer()

            VStack(alignment: .trailing, spacing: 1) {
                Text("\(entry.points) PTS")
                    .font(.f1Digits(15))
                    .foregroundStyle(entry.position == "1" ? Theme.accent : .white)
                HStack(spacing: 6) {
                    if let wins = Int(entry.wins), wins > 0 {
                        Text("\(wins)W")
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundStyle(Theme.dimText)
                    }
                    if let gap = gapToLeader {
                        Text(gap)
                            .font(.system(size: 10, weight: .semibold).monospacedDigit())
                            .foregroundStyle(Theme.faintText)
                    }
                }
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 9)
    }
}
