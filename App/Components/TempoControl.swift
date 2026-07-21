import SwiftUI

struct TempoControl: View {
    @Binding var bpm: Double
    var onTap: () -> Void

    var body: some View {
        VStack(spacing: 8) {
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text("\(Int(bpm.rounded()))")
                    .font(.system(.largeTitle, design: .rounded, weight: .bold))
                    .monospacedDigit()
                    .foregroundStyle(.primary)
                    .contentTransition(.numericText())
                    .animation(.snappy, value: Int(bpm.rounded()))
                    .accessibilityIdentifier("bpmValue")
                Text("BPM")
                    .font(.system(.subheadline, design: .rounded, weight: .semibold))
                    .foregroundStyle(.secondary)
                Spacer()
                Button(action: onTap) {
                    Label("Tap", systemImage: "hand.tap.fill")
                        .font(.system(.subheadline, design: .rounded, weight: .semibold))
                }
                .buttonStyle(.bordered)
                .buttonBorderShape(.capsule)
                .tint(.amber)
                .accessibilityLabel("Tap tempo")
                .accessibilityIdentifier("tapTempoButton")
            }
            HStack(spacing: 8) {
                Image(systemName: "tortoise.fill")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                    .accessibilityHidden(true)
                CustomSlider(value: $bpm, range: 40...220, step: 1)
                Image(systemName: "hare.fill")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                    .accessibilityHidden(true)
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Tempo")
            .accessibilityValue("\(Int(bpm.rounded())) BPM")
            .accessibilityAdjustableAction { direction in
                switch direction {
                case .increment: bpm = min(bpm + 1, 220)
                case .decrement: bpm = max(bpm - 1, 40)
                default: break
                }
            }
        }
        .padding(16)
        .background(Color.card, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .accessibilityElement(children: .contain)
    }
}
