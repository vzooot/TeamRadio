import SwiftUI

/// The tabs on the iPhone Duo's inner display held like a book: a rail of
/// our own down the trailing edge, as tall as the two screens beside it,
/// in place of the system's short floating bar. Glass with the trio glow,
/// the selected tab lit like a session chip; the Paddock carries the unread
/// count (red once a private message waits).
struct DuoDock: View {
    struct Item: Identifiable {
        let tag: Int
        let symbol: String
        let name: String
        var id: Int { tag }
    }

    @Binding var selection: Int
    let items: [Item]
    /// Unread room messages and whether a private one is among them.
    let unread: Int
    let privateUnread: Bool

    var body: some View {
        VStack(spacing: 0) {
            ForEach(items) { item in
                Spacer(minLength: 6)
                button(item)
            }
            Spacer(minLength: 6)
        }
        .frame(width: 62)
        .frame(maxHeight: 420)
        .background(
            Capsule()
                .fill(LinearGradient(colors: [Theme.card, Color.black.opacity(0.75)], startPoint: .top, endPoint: .bottom))
                .overlay(Capsule().strokeBorder(Theme.glassStroke, lineWidth: 1))
        )
        .trioGlow(cornerRadius: 31)
    }

    private func button(_ item: Item) -> some View {
        let on = selection == item.tag
        return Button {
            selection = item.tag
        } label: {
            Image(systemName: item.symbol)
                .environment(\.symbolVariants, .none)
                .font(.system(size: 19, weight: on ? .semibold : .regular))
                .foregroundStyle(on ? Color.white : Theme.dimText)
                .frame(width: 46, height: 46)
                .background {
                    if on {
                        Circle()
                            .fill(LinearGradient(colors: [Color(white: 0.04), Color(white: 0.1)], startPoint: .top, endPoint: .bottom))
                            .overlay(Circle().strokeBorder(Theme.accent.opacity(0.9), lineWidth: 2.5).blur(radius: 4))
                            .overlay(Circle().strokeBorder(LinearGradient(colors: [.white.opacity(0.95), Theme.accent], startPoint: .topLeading, endPoint: .bottomTrailing), lineWidth: 1.6))
                            .shadow(color: Theme.accent.opacity(0.55), radius: 8)
                    }
                }
                .overlay(alignment: .topTrailing) {
                    if item.tag == RootView.Tab.paddock, unread > 0 {
                        Text(unread > 99 ? "99+" : "\(unread)")
                            .font(.system(size: 11, weight: .bold).monospacedDigit())
                            .foregroundStyle(.white)
                            .padding(.horizontal, 5)
                            .frame(minWidth: 18, minHeight: 18)
                            .background(Capsule().fill(privateUnread ? Theme.live : Theme.accent))
                            .offset(x: 4, y: -2)
                    }
                }
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(item.name)
        .accessibilityValue(item.tag == RootView.Tab.paddock && unread > 0 ? "\(unread) unread" : "")
        .accessibilityAddTraits(on ? .isSelected : [])
    }
}
