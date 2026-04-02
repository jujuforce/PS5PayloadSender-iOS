import SwiftUI

extension Color {
    /// `.cyan` was added in iOS 15. This falls back to the equivalent RGB value on iOS 14.
    static var cyanCompat: Color {
        if #available(iOS 15, *) {
            return .cyan
        } else {
            return Color(red: 0, green: 1, blue: 1)
        }
    }
}

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
