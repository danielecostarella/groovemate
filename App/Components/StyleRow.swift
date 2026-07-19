import SwiftUI
import GrooveModel

/// Style selection as a standard segmented control with a section label.
struct StyleRow: View {
    let selected: Style
    var select: (Style) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Style")
                .font(.system(.subheadline, design: .rounded, weight: .semibold))
                .foregroundStyle(.primary)
            Picker("Style", selection: Binding(get: { selected }, set: select)) {
                ForEach(Style.allCases) { style in
                    Text(style.displayName).tag(style)
                }
            }
            .pickerStyle(.segmented)
        }
        .accessibilityElement(children: .contain)
    }
}
