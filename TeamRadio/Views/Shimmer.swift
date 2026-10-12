import SwiftUI

/// A loading placeholder: a dim block with a soft band of light sweeping
/// across it (still under Reduce Motion).
struct Shimmer: View {
    var cornerRadius: CGFloat = 8
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        TimelineView(.animation(paused: reduceMotion)) { context in
            let phase = reduceMotion ? 0.3 : (context.date.timeIntervalSinceReferenceDate * 0.7).truncatingRemainder(dividingBy: 1)
            GeometryReader { geo in
                RoundedRectangle(cornerRadius: cornerRadius)
                    .fill(Color.white.opacity(0.06))
                    .overlay {
                        LinearGradient(colors: [.clear, .white.opacity(0.13), .clear], startPoint: .leading, endPoint: .trailing)
                            .frame(width: geo.size.width * 0.6)
                            .offset(x: CGFloat(phase) * geo.size.width * 1.6 - geo.size.width * 0.8)
                    }
                    .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
            }
        }
        .accessibilityLabel("Loading")
    }
}

/// The circuit section while its 3D map loads.
struct TrackPlaceholder: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionTitle("THE CIRCUIT")
            VStack(spacing: 12) {
                Shimmer(cornerRadius: 16).frame(height: 300)
                HStack(spacing: 8) {
                    ForEach(0..<4, id: \.self) { _ in Shimmer(cornerRadius: 12).frame(height: 52) }
                }
            }
            .padding(14)
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(Theme.card)
                    .overlay(RoundedRectangle(cornerRadius: 20).strokeBorder(Theme.glassStroke, lineWidth: 1))
            )
        }
        .transition(.opacity)
    }
}
