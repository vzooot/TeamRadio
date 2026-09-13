import SwiftUI

/// Hero card for the upcoming grand prix.
struct RaceHeroView: View {
    let race: Race

    var body: some View {
        ZStack(alignment: .topLeading) {
            RoundedRectangle(cornerRadius: 20)
                .fill(
                    LinearGradient(
                        colors: [Theme.card,
                                 Theme.violet.opacity(0.16),
                                 Theme.accent.opacity(0.24)],
                        startPoint: .topLeading, endPoint: .bottomTrailing
                    )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .strokeBorder(Theme.glassStroke, lineWidth: 1)
                )

            Text(Flags.emoji(for: race.circuit.location.country))
                .font(.system(size: 110))
                .opacity(0.14)
                .rotationEffect(.degrees(-12))
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
                .offset(x: 14, y: 18)
                .clipShape(RoundedRectangle(cornerRadius: 20))

            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 8) {
                    Text("ROUND \(race.roundNumber)")
                        .font(.f1(13).italic())
                        .tracking(1)
                        .foregroundStyle(Theme.onAccent)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(Theme.accentGradient, in: RoundedRectangle(cornerRadius: 7))

                    if race.isSprintWeekend {
                        Text("SPRINT")
                            .font(.f1(13).italic())
                            .tracking(1)
                            .foregroundStyle(.black)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 5)
                            .background(.yellow, in: RoundedRectangle(cornerRadius: 7))
                    }

                    Spacer()

                    Text(race.season)
                        .font(.f1(15).italic())
                        .foregroundStyle(Theme.dimText)
                }

                Text(race.raceName.uppercased())
                    .font(.f1(32).italic())
                    .foregroundStyle(Theme.chromeText)
                    .lineLimit(2)
                    .minimumScaleFactor(0.6)

                VStack(alignment: .leading, spacing: 3) {
                    Text(race.circuit.circuitName)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.85))
                    Text("\(Flags.emoji(for: race.circuit.location.country)) \(race.circuit.location.locality), \(race.circuit.location.country) · \(weekendRange)")
                        .font(.system(size: 13))
                        .foregroundStyle(Theme.dimText)
                }
            }
            .padding(18)
        }
    }

    /// e.g. "21–23 AUG"
    private var weekendRange: String {
        let sessions = race.sessions
        guard let first = sessions.first?.date, let last = sessions.last?.date else { return "" }
        let day = Date.FormatStyle().day(.defaultDigits)
        let month = Date.FormatStyle().month(.abbreviated)
        let dayMonth = Date.FormatStyle().day(.defaultDigits).month(.abbreviated)
        if Calendar.current.isDate(first, equalTo: last, toGranularity: .month) {
            return "\(first.formatted(day))–\(last.formatted(day)) \(last.formatted(month))".uppercased()
        }
        return "\(first.formatted(dayMonth)) – \(last.formatted(dayMonth))".uppercased()
    }
}
