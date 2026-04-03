import SwiftUI

// MARK: - Private shape type-eraser (AnyShape requires iOS 16)
private struct ErasedShape: Shape, @unchecked Sendable {
    private let _path: @Sendable (CGRect) -> Path
    init<S: Shape>(_ shape: S) { _path = { shape.path(in: $0) } }
    func path(in rect: CGRect) -> Path { _path(rect) }
}

extension View {
    @ViewBuilder
    func glassCard(
        tint: Color? = nil,
        interactive: Bool = false,
        shape: some Shape = RoundedRectangle(cornerRadius: 18)
    ) -> some View {
        if #available(iOS 26.0, macOS 26.0, *) {
            self.modifier(LiquidGlassModifier(tint: tint, interactive: interactive, shape: AnyShape(shape)))
        } else if #available(iOS 15.0, *) {
            self
                .background(
                    ErasedShape(shape)
                        .fill(.ultraThinMaterial)
                        .overlay(
                            // Tint overlay for selected state; plain white border otherwise.
                            ErasedShape(shape)
                                .stroke(tint?.opacity(0.55) ?? Color.white.opacity(0.15), lineWidth: tint != nil ? 1.5 : 1)
                        )
                )
                .clipShape(ErasedShape(shape))
        } else {
            // iOS 14: no Material API — approximate the frosted glass look with a
            // higher-opacity white fill. Selected cards get a brighter fill + vivid
            // blue border. Border colour is hardcoded because the tint arrives
            // pre-dimmed (.blue.opacity(0.2)) and compounding opacity kills it.
            let isSelected = tint != nil
            self
                .background(
                    ErasedShape(shape)
                        .fill(isSelected ? Color.appBlue.opacity(0.30) : Color.white.opacity(0.18))
                        .overlay(
                            ErasedShape(shape)
                                .stroke(
                                    isSelected ? Color.appBlue : Color.white.opacity(0.25),
                                    lineWidth: isSelected ? 2 : 1
                                )
                        )
                )
                .clipShape(ErasedShape(shape))
        }
    }
}

extension View {
    /// Solid-fill capsule — primary action button style, consistent across all OS versions.
    func primaryButtonStyle(color: Color) -> some View {
        self
            .background(Capsule().fill(color))
            .clipShape(Capsule())
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
