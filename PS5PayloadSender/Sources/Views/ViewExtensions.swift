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

    /// Allows bounce only when content overflows the scroll view (iOS 16.4+ / macOS 13.3+).
    /// On macOS this prevents the elastic overscroll that collapses the large navigation title
    /// when the payload list is short.
    @ViewBuilder
    func scrollBounceBasedOnSize() -> some View {
        if #available(iOS 16.4, macOS 13.3, *) {
            self.scrollBounceBehavior(.basedOnSize)
        } else {
            self
        }
    }
}
