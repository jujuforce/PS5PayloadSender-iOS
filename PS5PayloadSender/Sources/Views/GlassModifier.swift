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
                            ErasedShape(shape)
                                .stroke(Color.white.opacity(0.15), lineWidth: 1)
                        )
                )
                .clipShape(ErasedShape(shape))
        } else {
            // iOS 14: no Material API — use tint if provided, otherwise semi-transparent white
            self
                .background(
                    ErasedShape(shape)
                        .fill(tint.map { $0.opacity(0.35) } ?? Color.white.opacity(0.15))
                        .overlay(
                            ErasedShape(shape)
                                .stroke((tint ?? Color.white).opacity(0.25), lineWidth: 1)
                        )
                )
                .clipShape(ErasedShape(shape))
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
