import SwiftUI

struct TempoControl: View {
    @Binding var bpm: Double
    var onTap: () -> Void

    var body: some View {
        VStack(spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                Text("\(Int(bpm.rounded()))")
                    .font(.system(size: 44, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(.white)
                    .contentTransition(.numericText())
                    .animation(.snappy, value: Int(bpm.rounded()))
                Text("BPM")
                    .font(.system(.headline, design: .rounded, weight: .semibold))
                    .foregroundStyle(.secondary)
                Spacer()
                Button(action: onTap) {
                    Label("Tap", systemImage: "hand.tap.fill")
                        .font(.system(.callout, design: .rounded, weight: .semibold))
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .background(Color.white.opacity(0.08), in: Capsule())
                }
                .buttonStyle(.plain)
                .foregroundStyle(Color.amber)
            }
            Slider(value: $bpm, in: 40...220, step: 1)
                .tint(.amber)
        }
        .padding(18)
        .background(Color.card, in: RoundedRectangle(cornerRadius: 20))
        .accessibilityElement(children: .contain)
    }
}
