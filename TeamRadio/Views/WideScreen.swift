import SwiftUI

extension View {
    /// The iPhone Duo's inner display, either pose: where the fold divides
    /// this view, or nil anywhere else (the outer display, iPhones, iPads).
    func onHalves(_ halves: Binding<Halves?>) -> some View {
        onGeometryChange(for: Halves?.self) { Halves.of($0) } action: { halves.wrappedValue = $0 }
    }
}

extension EnvironmentValues {
    /// The window's halves, measured once at the root (TeamRadioApp), so
    /// every tab follows a rotation at once, even one that was off screen
    /// when it happened.
    @Entry var halves: Halves? = nil
}

/// The two halves of the iPhone Duo's inner display: side by side when it's
/// held like a book (the fold upright), one above the other when it stands
/// like a laptop. Nothing is laid across the fold (Apple's iPhone Duo
/// guidance), each half is its own screen.
struct Halves: Equatable {
    /// `.horizontal`: side by side; `.vertical`: one above the other.
    let axis: Axis
    /// The fold's line in the view's own coordinates (the middle on an iPad).
    let fold: CGFloat
    /// A real fold (the iPhone Duo), not just a screen big enough for two.
    var foldable = true

    /// From the system's division region (iOS 27.1), which the inner
    /// display reports even while it's flat (with no width). Without one, a
    /// screen held sideways and two phone columns wide (an iPad in
    /// landscape) gets the same two screens, side by side; upright, or in a
    /// narrow window, it keeps the phone layout.
    static func of(_ proxy: GeometryProxy) -> Halves? {
        if #available(iOS 27.1, *), let region = proxy.reservedRegions(kind: .division, options: .includeInactive).first {
            let frame = region.frame
            let upright = frame.width == frame.height ? proxy.size.width > proxy.size.height : frame.height > frame.width
            return upright ? Halves(axis: .horizontal, fold: frame.width > 0 || frame.height > 0 ? frame.midX : proxy.size.width / 2)
                           : Halves(axis: .vertical, fold: frame.width > 0 || frame.height > 0 ? frame.midY : proxy.size.height / 2)
        }
        let size = proxy.size
        return size.width > size.height && size.width >= 740 ? Halves(axis: .horizontal, fold: size.width / 2, foldable: false) : nil
    }
}
