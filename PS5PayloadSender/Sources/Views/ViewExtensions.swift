import SwiftUI

extension View {
    /// Dismisses the keyboard when scrolling, on iOS 16+. No-op on iOS 15.
    @ViewBuilder
    func scrollDismissesKeyboardCompat() -> some View {
        if #available(iOS 16.0, *) {
            self.scrollDismissesKeyboard(.interactively)
        } else {
            self
        }
    }
}
