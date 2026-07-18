import SwiftUI
import GrooveModel

/// Horizontal style chips.
struct StyleRow: View {
    let selected: Style
    var select: (Style) -> Void

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(Style.allCases) { style in
                    let isOn = style == selected
                    Button {
                        select(style)
                    } label: {
                        Text(style.displayName)
                            .font(.system(.callout, design: .rounded, weight: .semibold))
                            .padding(.horizontal, 16)
                            .padding(.vertical, 9)
                            .background(
                                isOn
                                    ? AnyShapeStyle(LinearGradient(colors: [.amber, .ember], startPoint: .leading, endPoint: .trailing))
                                    : AnyShapeStyle(Color.card),
                                in: Capsule()
                            )
                            .foregroundStyle(isOn ? Color.stage : .white)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 2)
        }
        .accessibilityLabel("Style")
    }
}
