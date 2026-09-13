import SwiftUI

/// Top of the drivers' championship, with constructor color bars.
struct StandingsView: View {
    let standings: [DriverStanding]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionTitle("DRIVERS' CHAMPIONSHIP")

            VStack(spacing: 0) {
                ForEach(standings) { entry in
                    StandingRow(entry: entry, isLeader: entry.position == "1")
                    if entry.id != standings.last?.id {
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
}

struct StandingRow: View {
    let entry: DriverStanding
    let isLeader: Bool

    var body: some View {
        HStack(spacing: 12) {
            Text(entry.position)
                .font(.f1Digits(20))
                .foregroundStyle(isLeader ? Theme.accent : .white)
                .frame(width: 30, alignment: .center)

            RoundedRectangle(cornerRadius: 2)
                .fill(Theme.teamColor(entry.teamId))
                .frame(width: 4, height: 30)

            VStack(alignment: .leading, spacing: 1) {
                HStack(spacing: 6) {
                    Text(entry.driver.shortCode)
                        .font(.f1(17).italic())
                        .foregroundStyle(.white)
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
                    .font(.f1Digits(16))
                    .foregroundStyle(isLeader ? Theme.accent : .white)
                if let wins = Int(entry.wins), wins > 0 {
                    Text("\(wins) \(wins == 1 ? "WIN" : "WINS")")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(Theme.faintText)
                }
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
    }
}
