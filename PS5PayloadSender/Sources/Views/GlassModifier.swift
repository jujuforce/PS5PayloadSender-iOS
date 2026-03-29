import SwiftUI

extension View {
    @ViewBuilder
    func glassCard(
        tint: Color? = nil,
        interactive: Bool = false,
        shape: some Shape = RoundedRectangle(cornerRadius: 18)
    ) -> some View {
        if #available(iOS 26.0, macOS 26.0, *) {
            self.modifier(LiquidGlassModifier(tint: tint, interactive: interactive, shape: AnyShape(shape)))
        } else {
            self
                .background {
                    AnyShape(shape)
                        .fill(.ultraThinMaterial)
                        .overlay(
                            AnyShape(shape)
                                .stroke(.white.opacity(0.15), lineWidth: 1)
                        )
                }
                .clipShape(AnyShape(shape))
        }
    }
}

@available(iOS 26.0, macOS 26.0, *)
private struct LiquidGlassModifier: ViewModifier {
    let tint: Color?
    let interactive: Bool
    let shape: AnyShape

    func body(content: Content) -> some View {
        if let tint {
            if interactive {
                content.glassEffect(.regular.tint(tint).interactive(), in: shape)
            } else {
                content.glassEffect(.regular.tint(tint), in: shape)
            }
        } else {
            if interactive {
                content.glassEffect(.regular.interactive(), in: shape)
            } else {
                content.glassEffect(.regular, in: shape)
            }
        }
    }
}
