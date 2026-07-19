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
            }
            Slider(value: $bpm, in: 40...220, step: 1) {
                Text("Tempo")
            } minimumValueLabel: {
                Image(systemName: "tortoise.fill")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                    .accessibilityHidden(true)
            } maximumValueLabel: {
                Image(systemName: "hare.fill")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                    .accessibilityHidden(true)
            }
            .tint(.amber)
        }
        .padding(16)
        .background(Color.card, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .accessibilityElement(children: .contain)
    }
}
