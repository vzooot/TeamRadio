import SwiftUI

/// Horizontal strip of every round in the season, auto-scrolled to the next one.
struct SeasonView: View {
    let season: [Race]
    let nextRaceId: String?
    var selectedId: String? = nil
    var onSelect: ((Race) -> Void)? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionTitle("SEASON \(season.first?.season ?? "")")

            ScrollViewReader { proxy in
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 10) {
                        ForEach(season) { race in
                            Button {
                                onSelect?(race)
                            } label: {
                                RoundCard(race: race, isNext: race.id == nextRaceId,
                                          isSelected: race.id == (selectedId ?? nextRaceId))
                            }
                            .buttonStyle(.plain)
                            .id(race.id)
                        }
                    }
                    .padding(.horizontal, 2)
                    .padding(.vertical, 2)
                }
                .onAppear {
                    if let id = selectedId ?? nextRaceId {
                        proxy.scrollTo(id, anchor: .center)
                    }
                }
                .onChange(of: selectedId) { _, id in
                    if let id { withAnimation { proxy.scrollTo(id, anchor: .center) } }
                }
            }
        }
    }
}

struct RoundCard: View {
    let race: Race
    let isNext: Bool
    var isSelected = false

    private var isPast: Bool {
        guard let start = race.startDate else { return false }
        return start <= .now && !isNext
    }

    var body: some View {
        VStack(spacing: 5) {
            Text(Flags.emoji(for: race.circuit.location.country))
                .font(.system(size: 26))
                .saturation(isPast ? 0.2 : 1)

            Text("R\(race.roundNumber)")
                .font(.f1(13).italic())
                .foregroundStyle(isNext ? Theme.accent : Theme.dimText)

            Text(race.circuit.location.locality.uppercased())
                .font(.f1(12, weight: .bold))
                .foregroundStyle(isPast ? Theme.faintText : .white)
                .lineLimit(1)

            if isPast {
                Text("🏁")
                    .font(.system(size: 10))
            } else if let start = race.startDate {
                Text(start.formatted(.dateTime.day().month(.abbreviated)).uppercased())
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(isNext ? Theme.accent : Theme.dimText)
            }
        }
        .frame(width: 92)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(isSelected ? (isNext ? Theme.accent : Theme.violet).opacity(0.12) : Theme.card)
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .strokeBorder(isSelected ? (isNext ? Theme.accent : Theme.violet) : Theme.cardStroke,
                                      lineWidth: isSelected ? 1.5 : 1)
                )
                .shadow(color: (isNext ? Theme.accent : Theme.violet).opacity(isSelected ? 0.35 : 0), radius: 8)
        )
        .opacity(isPast && !isSelected ? 0.6 : 1)
    }
}
