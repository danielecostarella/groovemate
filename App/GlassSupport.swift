import SwiftUI

@available(iOS 26.0, *)
private func resolvedGlass(tint: Color?, interactive: Bool) -> Glass {
    var glass: Glass = .regular
    if let tint { glass = glass.tint(tint) }
    if interactive { glass = glass.interactive() }
    return glass
}

/// `.glassEffect()` is disabled app-wide for now: on-device it was
/// intercepting taps on ordinary, unrelated buttons (even ones with no glass
/// on them at all — sliders kept working, only taps broke), which is worse
/// than losing the visual polish. Flip this back on once that's understood.
private let liquidGlassEnabled = false

extension View {
    /// Real Liquid Glass on iOS 26+ — translucent, refracts the content behind
    /// it, adapts to light/dark. Falls back to a material approximation on
    /// iOS 17–25, where `.glassEffect()` doesn't exist. Reserved for the
    /// floating navigation layer (transport, command bar) per the HIG; content
    /// cards stay opaque.
    @ViewBuilder
    func glassBackground<S: InsettableShape>(in shape: S, tint: Color? = nil, interactive: Bool = false) -> some View {
        if liquidGlassEnabled, #available(iOS 26.0, *) {
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
