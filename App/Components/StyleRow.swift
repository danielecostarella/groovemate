import SwiftUI
import GrooveModel

/// Style selection limited to the current drummer's repertoire.
struct StyleRow: View {
    let styles: [Style]
    let selected: Style
    var select: (Style) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Style")
                .font(.system(.subheadline, design: .rounded, weight: .semibold))
                .foregroundStyle(.primary)
            Picker("Style", selection: Binding(get: { selected }, set: select)) {
                ForEach(styles) { style in
                    Text(style.displayName).tag(style)
                }
            }
            .pickerStyle(.segmented)
        }
        .accessibilityElement(children: .contain)
    }
}
