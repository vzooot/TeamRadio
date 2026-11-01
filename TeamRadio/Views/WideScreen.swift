import SwiftUI

extension View {
    /// The iPhone Duo unfolded: a wide, short screen gets the two-halves
    /// layouts (the left half the phone column, ending at the fold). iPhones
    /// (portrait only) and iPads (taller) keep the phone layouts.
    func onWideScreen(_ wide: Binding<Bool>) -> some View {
        onGeometryChange(for: Bool.self) { $0.size.width > $0.size.height && $0.size.height < 760 } action: { wide.wrappedValue = $0 }
    }
}

enum WideScreen {
    /// The left half's column: 18 pt margin + 440 + 18 pt gap lands the right
    /// half on the fold.
    static let column: CGFloat = 440
}
