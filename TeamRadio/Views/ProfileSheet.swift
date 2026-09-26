import SwiftUI
import UIKit

// MARK: - Presenting

/// Opens a driver or team profile from anywhere in the app.
struct OpenProfileAction {
    var action: (ProfileTarget) -> Void = { _ in }
    func callAsFunction(_ target: ProfileTarget) { action(target) }
}

private struct OpenProfileKey: EnvironmentKey {
    static let defaultValue = OpenProfileAction()
}

extension EnvironmentValues {
    var openProfile: OpenProfileAction {
        get { self[OpenProfileKey.self] }
        set { self[OpenProfileKey.self] = newValue }
    }
}

extension View {
    /// Makes a row open a profile when tapped, keeping its look.
    func opensProfile(_ target: ProfileTarget?) -> some View {
        modifier(OpensProfile(target: target))
    }
}

private struct OpensProfile: ViewModifier {
    let target: ProfileTarget?
    @Environment(\.openProfile) private var openProfile

    func body(content: Content) -> some View {
        if let target {
            Button { openProfile(target) } label: { content.contentShape(Rectangle()) }
                .buttonStyle(.plain)
        } else {
            content
        }
    }
}

struct ProfileSheet: View {
    let target: ProfileTarget

    var body: some View {
        Group {
            switch target {
            case .driver(let id): DriverProfileSheet(model: DriverProfileModel(driverId: id))
            case .team(let id): TeamProfileSheet(model: TeamProfileModel(teamId: id))
            }
        }
        .id(target.id)
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
        .presentationBackground(Theme.background)
        .preferredColorScheme(.dark)
    }
}

// MARK: - Shared pieces

/// Tall header: team-colour glow, artwork on the right fading into the sheet,
/// title on the left over the fade.
private struct ProfileHeader<Title: View>: View {
    let teamId: String?
    let artwork: String          // "Cars" or "Suits"
    let height: CGFloat
    @ViewBuilder let title: Title

    private var tint: Color { Theme.teamColor(teamId) }
    private var imageName: String? {
        guard let teamId, UIImage(named: "\(artwork)/\(teamId)") != nil else { return nil }
        return "\(artwork)/\(teamId)"
    }

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            RadialGradient(colors: [tint.opacity(0.62), tint.opacity(0.18), .clear],
                           center: UnitPoint(x: 0.72, y: artwork == "Cars" ? 0.25 : 0.3),
                           startRadius: 0, endRadius: height * 1.05)

            if let imageName {
                GeometryReader { geo in
                    let w = geo.size.width
                    Image(imageName)
                        .resizable()
                        .scaledToFit()
                        // car: straight down from the top, front half showing;
                        // driver: full height on the right
                        .frame(width: artwork == "Cars" ? w * 0.95 : nil,
                               height: artwork == "Cars" ? nil : height * 1.37)
                        .mask(LinearGradient(stops: [.init(color: .clear, location: 0),
                                                     .init(color: .black, location: artwork == "Cars" ? 0.3 : 0.15)],
                                             startPoint: .leading, endPoint: .trailing))
                        .shadow(color: .black.opacity(0.45), radius: 11, x: 5, y: 12)
                        .position(x: artwork == "Cars" ? w * 0.70 : w - 105,
                                  y: artwork == "Cars" ? height * 0.30 : height * 0.74)
                }
            }

            // sink the art into the sheet
            LinearGradient(stops: [.init(color: .clear, location: artwork == "Cars" ? 0.5 : 0.55),
                                   .init(color: Theme.background, location: 1)],
                           startPoint: .top, endPoint: .bottom)

            title
                .padding(.horizontal, 20)
                .padding(.bottom, 26)
        }
        .frame(height: height)
        .clipped()
    }
}

/// Big-type stat block: small label, huge bold number + ultralight word, caption.
private struct BigStat: View {
    let label: String
    let number: String
    var word: String = ""
    var caption: String = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(Theme.dimText)
            HStack(alignment: .firstTextBaseline, spacing: 10) {
                Text(number)
                    .font(.system(size: 64, weight: .bold, design: .rounded))
                    .monospacedDigit()
                if !word.isEmpty {
                    Text(word)
                        .font(.system(size: 52, weight: .ultraLight, design: .rounded))
                }
            }
            .foregroundStyle(.white)
            .lineLimit(1)
            .minimumScaleFactor(0.6)
            if !caption.isEmpty {
                Text(caption)
                    .font(.system(size: 15))
                    .foregroundStyle(Theme.dimText)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 16)
        .overlay(alignment: .bottom) {
            Rectangle().fill(Color.white.opacity(0.08)).frame(height: 1)
        }
    }
}

private struct FactRow: View {
    let label: String
    let value: String

    var body: some View {
        HStack {
            Text(label)
                .font(.system(size: 15))
                .foregroundStyle(Theme.dimText)
            Spacer()
            Text(value)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(.white)
                .multilineTextAlignment(.trailing)
        }
        .padding(.vertical, 12)
        .overlay(alignment: .bottom) {
            Rectangle().fill(Color.white.opacity(0.08)).frame(height: 1)
        }
    }
}

private func ordinal(_ position: String?) -> String {
    guard let position, let n = Int(position) else { return "—" }
    return String(format: "%02d", n)
}

private func pointsCaption(_ points: String?, gap: Double?) -> String {
    guard let points else { return "" }
    guard let gap else { return "\(points) points" }
    return gap == 0 ? "\(points) points · leader" : "\(points) points · \(Int(gap)) behind the leader"
}

private func plural(_ n: Int, _ word: String) -> String { "\(n) \(word)\(n == 1 ? "" : "s")" }

// MARK: - Driver

struct DriverProfileSheet: View {
    @State var model: DriverProfileModel
    @Environment(\.openProfile) private var openProfile

    private var teamId: String? { model.standing?.teamId }
    private var tint: Color { Theme.teamColor(teamId) }

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                ProfileHeader(teamId: teamId, artwork: "Suits", height: 320) {
                    VStack(alignment: .leading, spacing: 2) {
                        if let number = model.driver?.permanentNumber {
                            Text(number)
                                .font(.system(size: 32, weight: .black, design: .rounded))
                                .foregroundStyle(tint)
                                .padding(.bottom, 60)
                        }
                        Text(model.driver?.givenName ?? " ")
                            .font(.system(size: 46, weight: .black, design: .rounded))
                        Text(model.driver?.familyName ?? " ")
                            .font(.system(size: 42, weight: .ultraLight, design: .rounded))
                        Text([model.driver?.shortCode, model.standing?.teamName, model.driver?.nationality]
                                .compactMap { $0 }.joined(separator: "  ·  "))
                            .font(.system(size: 15, weight: .medium))
                            .foregroundStyle(tint)
                            .padding(.top, 6)
                    }
                    .foregroundStyle(.white)
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                }

                if model.isLoading && model.standing == nil {
                    ProgressView().tint(tint).padding(.top, 40)
                } else if model.failed {
                    Text("Couldn't load this driver right now.")
                        .foregroundStyle(Theme.dimText)
                        .padding(.top, 40)
                } else {
                    VStack(spacing: 0) {
                        BigStat(label: "Drivers' championship", number: ordinal(model.standing?.position), word: "POS",
                                caption: pointsCaption(model.standing?.points, gap: model.leaderGap))
                        BigStat(label: "Season", number: String(format: "%02d", Int(model.standing?.wins ?? "") ?? 0), word: "WINS",
                                caption: [plural(model.podiums, "podium"), plural(model.poles, "pole"),
                                          model.dnfs > 0 ? "\(model.dnfs) DNF" : nil].compactMap { $0 }.joined(separator: " · "))
                        if let first = model.firstEntry {
                            BigStat(label: "Career", number: first.season, word: "",
                                    caption: careerCaption(first))
                        }

                        if !model.rounds.isEmpty {
                            roundStrip.padding(.top, 20)
                        }

                        VStack(spacing: 0) {
                            if let teamId {
                                FactRow(label: "Team", value: model.standing?.teamName ?? "—")
                                    .opensProfile(.team(teamId))
                            }
                            if model.careerStarts > 0 {
                                FactRow(label: "Career", value: "\(plural(model.careerStarts, "start")) · \(plural(model.careerWins, "win"))")
                            }
                            if let dob = model.driver?.dateOfBirth, let date = Self.isoDate.date(from: dob) {
                                FactRow(label: "Date of birth", value: date.formatted(date: .long, time: .omitted))
                            }
                        }
                        .padding(.top, 20)
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 40)
                }
            }
        }
        .scrollIndicators(.hidden)
        .task { await model.load() }
    }

    private func careerCaption(_ first: Race) -> String {
        var parts = ["First entry \(first.raceName)"]
        if let win = model.firstWin { parts.append("first win \(win.season) \(win.raceName)") }
        return parts.joined(separator: " · ")
    }

    private var roundStrip: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Race by race")
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(Theme.dimText)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    ForEach(model.rounds) { r in
                        VStack(spacing: 3) {
                            Text(String(format: "R%02d", r.round))
                                .font(.system(size: 10, weight: .semibold))
                                .foregroundStyle(Theme.faintText)
                            Text(r.label)
                                .font(.f1(15).italic())
                                .foregroundStyle(r.isRetirement ? Theme.live : r.isWin ? tint : .white)
                        }
                        .frame(width: 48, height: 52)
                        .background(
                            RoundedRectangle(cornerRadius: 10)
                                .fill(r.isWin ? tint.opacity(0.14) : Color.white.opacity(0.04))
                                .overlay(RoundedRectangle(cornerRadius: 10)
                                    .strokeBorder(r.isRetirement ? Theme.live.opacity(0.5) : r.isWin ? tint.opacity(0.6) : Color.white.opacity(0.08),
                                                  lineWidth: 1))
                        )
                    }
                }
            }
        }
    }

    private static let isoDate: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        f.locale = Locale(identifier: "en_US_POSIX")
        return f
    }()
}

// MARK: - Team

struct TeamProfileSheet: View {
    @State var model: TeamProfileModel

    private var tint: Color { Theme.teamColor(model.teamId) }

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                ProfileHeader(teamId: model.teamId, artwork: "Cars", height: 280) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(model.constructor?.name ?? model.standing?.constructor.name ?? " ")
                            .font(.system(size: 46, weight: .black, design: .rounded))
                            .foregroundStyle(.white)
                        Text([TeamFacts.base[model.teamId], model.constructor?.nationality].compactMap { $0 }.first ?? "")
                            .font(.system(size: 15, weight: .medium))
                            .foregroundStyle(tint)
                    }
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                }

                if model.isLoading && model.standing == nil {
                    ProgressView().tint(tint).padding(.top, 40)
                } else if model.failed {
                    Text("Couldn't load this team right now.")
                        .foregroundStyle(Theme.dimText)
                        .padding(.top, 40)
                } else {
                    VStack(spacing: 0) {
                        BigStat(label: "Constructors' championship", number: ordinal(model.standing?.position), word: "POS",
                                caption: pointsCaption(model.standing?.points, gap: model.leaderGap))
                        BigStat(label: "Season", number: String(format: "%02d", Int(model.standing?.wins ?? "") ?? 0), word: "WINS",
                                caption: "\(plural(model.podiums, "podium")) · \(plural(model.poles, "pole"))")
                        if let top = model.drivers.first {
                            BigStat(label: "Top scorer", number: top.points, word: "PTS",
                                    caption: "\(top.driver.givenName) \(top.driver.familyName)")
                        }

                        VStack(alignment: .leading, spacing: 10) {
                            Text("Drivers")
                                .font(.system(size: 15, weight: .medium))
                                .foregroundStyle(Theme.dimText)
                            ForEach(model.drivers) { entry in
                                driverRow(entry)
                                    .opensProfile(.driver(entry.id))
                            }
                        }
                        .padding(.top, 20)

                        VStack(spacing: 0) {
                            if let base = TeamFacts.base[model.teamId] {
                                FactRow(label: "Base", value: base)
                            }
                            if let nationality = model.constructor?.nationality {
                                FactRow(label: "Nationality", value: nationality)
                            }
                        }
                        .padding(.top, 20)
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 40)
                }
            }
        }
        .scrollIndicators(.hidden)
        .task { await model.load() }
    }

    private func driverRow(_ entry: DriverStanding) -> some View {
        HStack(spacing: 14) {
            Text(entry.driver.permanentNumber ?? "")
                .font(.system(size: 26, weight: .black, design: .rounded))
                .foregroundStyle(tint)
                .frame(width: 44, alignment: .leading)
            VStack(alignment: .leading, spacing: 1) {
                Text(entry.driver.shortCode)
                    .font(.f1(17).italic())
                    .foregroundStyle(.white)
                Text("\(entry.driver.givenName) \(entry.driver.familyName)")
                    .font(.system(size: 13))
                    .foregroundStyle(Theme.dimText)
            }
            Spacer()
            Text("\(entry.points) PTS")
                .font(.f1Digits(17))
                .foregroundStyle(.white)
            Image(systemName: "chevron.right")
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(Theme.faintText)
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(Color.white.opacity(0.04))
                .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(Color.white.opacity(0.08), lineWidth: 1))
        )
    }
}
