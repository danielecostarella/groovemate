import SwiftUI

/// A bipolar-labeled feel control: "Tight ↔ Loose" and friends.
struct FeelSlider: View {
    let left: String
    let right: String
    @Binding var value: Double

    var body: some View {
        VStack(spacing: 6) {
            HStack {
                Text(left)
                    .foregroundStyle(value < 0.5 ? Color.amber : .secondary)
                Spacer()
                Text(right)
                    .foregroundStyle(value >= 0.5 ? Color.amber : .secondary)
            }
            .font(.system(.footnote, design: .rounded, weight: .semibold))
            Slider(value: $value, in: 0...1)
                .tint(.amber)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(left) to \(right)")
        .accessibilityValue("\(Int(value * 100)) percent toward \(right)")
    }
}
