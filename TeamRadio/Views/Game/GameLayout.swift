import SwiftUI

/// An arcade game's screen, laid out for the space it gets. Phones keep
/// their one tall column exactly as designed; a short, wide screen (the
/// iPhone Duo unfolded) gets the game beside its board; and whatever is
/// shorter than the game needs (the folded iPhone Duo, a small phone) is
/// scaled down to fit instead of being cut off.
struct GameScreen<Content: View>: View {
    /// Builds the game; true asks for the side-by-side layout.
    @ViewBuilder var content: (_ sideBySide: Bool) -> Content
    /// The height the game needs at this width.
    @State private var need: CGFloat = 0

    /// At least this tall (every iPhone but the mini and the SE, iPads), the
    /// column as it always was, untouched.
    private static var tall: CGFloat { 740 }

    var body: some View {
        GeometryReader { geo in
            if geo.size.height >= Self.tall {
                content(false)
            } else {
                NaturalHeight { content(geo.size.width > geo.size.height * 1.05) }
                    .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { need = $0 }
                    .scaleEffect(need > geo.size.height ? geo.size.height / need : 1, anchor: .top)
                    .frame(width: geo.size.width, height: geo.size.height, alignment: .top)
            }
        }
    }
}

/// Gives its view the whole height on offer, or the height it needs when
/// that is more (so nothing is squeezed or cut off).
private struct NaturalHeight: Layout {
    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        guard let view = subviews.first else { return .zero }
        let width = proposal.replacingUnspecifiedDimensions().width
        let need = view.sizeThatFits(ProposedViewSize(width: width, height: nil)).height
        return CGSize(width: width, height: max(need, proposal.height ?? need))
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        subviews.first?.place(at: bounds.origin, proposal: ProposedViewSize(bounds.size))
    }
}
