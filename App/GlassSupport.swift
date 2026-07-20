import SwiftUI

@available(iOS 26.0, *)
private func resolvedGlass(tint: Color?, interactive: Bool) -> Glass {
    var glass: Glass = .regular
    if let tint { glass = glass.tint(tint) }
    if interactive { glass = glass.interactive() }
    return glass
}

extension View {
    /// Real Liquid Glass on iOS 26+ — translucent, refracts the content behind
    /// it, adapts to light/dark. Falls back to a material approximation on
    /// iOS 17–25, where `.glassEffect()` doesn't exist. Reserved for the
    /// floating navigation layer (transport, command bar) per the HIG; content
    /// cards stay opaque.
    @ViewBuilder
    func glassBackground<S: InsettableShape>(in shape: S, tint: Color? = nil, interactive: Bool = false) -> some View {
        if #available(iOS 26.0, *) {
            self.glassEffect(resolvedGlass(tint: tint, interactive: interactive), in: shape)
        } else {
            self.background {
                ZStack {
                    shape.fill(.ultraThinMaterial)
                    if let tint { shape.fill(tint.opacity(0.18)) }
                }
                .overlay(shape.strokeBorder(Color.white.opacity(0.1)))
            }
        }
    }
}
