import SwiftUI
import GrooveEngine

/// Pulsing beat dots plus a bar counter — the visual heartbeat of the drummer.
struct BeatIndicator: View {
    let position: DrumEngine.PlaybackPosition
    let beatsPerBar: Int

    var body: some View {
        VStack(spacing: 8) {
            HStack(spacing: 14) {
                ForEach(0..<max(beatsPerBar, 1), id: \.self) { beat in
                    let isCurrent = position.isPlaying && Int(position.beat) == beat
                    Circle()
                        .fill(isCurrent ? Color.amber : Color.white.opacity(0.12))
                        .frame(width: isCurrent ? 16 : 10, height: isCurrent ? 16 : 10)
                        .shadow(color: .amber.opacity(isCurrent ? 0.6 : 0), radius: 8)
                        .animation(.easeOut(duration: 0.1), value: isCurrent)
                }
            }
            .frame(height: 20)
            Text(position.isPlaying ? "Bar \(position.barIndex + 1)" : "Ready")
                .font(.system(.caption, design: .rounded, weight: .medium))
                .foregroundStyle(.secondary)
                .monospacedDigit()
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(position.isPlaying ? "Playing, bar \(position.barIndex + 1)" : "Stopped")
    }
}
