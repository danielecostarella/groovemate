import ActivityKit
import WidgetKit
import SwiftUI

struct GrooveActivityWidget: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: GrooveActivityAttributes.self) { context in
            LockScreenView(attributes: context.attributes, state: context.state)
                .activityBackgroundTint(Color.stage)
                .activitySystemActionForegroundColor(Color.amber)
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    DrumGlyph(isPlaying: context.state.isPlaying)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    Text("\(context.state.bpm)")
                        .font(.system(.title2, design: .rounded, weight: .bold))
                        .foregroundStyle(Color.amber)
                        .monospacedDigit()
                }
                DynamicIslandExpandedRegion(.bottom) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("\(context.state.personaName) · \(context.state.styleName)")
                            .font(.system(.subheadline, design: .rounded, weight: .semibold))
                            .foregroundStyle(.white)
                        Text(context.state.isPlaying ? "Playing" : "Paused")
                            .font(.system(.caption, design: .rounded))
                            .foregroundStyle(.white.opacity(0.6))
                    }
                }
            } compactLeading: {
                DrumGlyph(isPlaying: context.state.isPlaying)
                    .frame(width: 20, height: 20)
            } compactTrailing: {
                Text("\(context.state.bpm)")
                    .font(.system(.footnote, design: .rounded, weight: .bold))
                    .foregroundStyle(Color.amber)
                    .monospacedDigit()
            } minimal: {
                DrumGlyph(isPlaying: context.state.isPlaying)
                    .frame(width: 16, height: 16)
            }
            .widgetURL(URL(string: "groovemate://now-playing"))
            .keylineTint(Color.amber)
        }
    }
}

/// A small animated glyph — pulses while the drummer plays, still when paused.
private struct DrumGlyph: View {
    let isPlaying: Bool

    var body: some View {
        Image(systemName: "waveform")
            .font(.system(size: 14, weight: .bold))
            .foregroundStyle(Color.amber)
            .symbolEffect(.variableColor.iterative, isActive: isPlaying)
    }
}

private struct LockScreenView: View {
    let attributes: GrooveActivityAttributes
    let state: GrooveActivityAttributes.ContentState

    var body: some View {
        HStack(spacing: 14) {
            ZStack {
                Circle().fill(
                    LinearGradient(colors: [Color.amber, Color.ember], startPoint: .topLeading, endPoint: .bottomTrailing)
                )
                Image(systemName: "waveform")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundStyle(Color.stage)
                    .symbolEffect(.variableColor.iterative, isActive: state.isPlaying)
            }
            .frame(width: 48, height: 48)

            VStack(alignment: .leading, spacing: 3) {
                Text(state.personaName)
                    .font(.system(.headline, design: .rounded, weight: .bold))
                    .foregroundStyle(.white)
                Text("\(state.styleName) · \(state.bpm) BPM")
                    .font(.system(.subheadline, design: .rounded))
                    .foregroundStyle(.white.opacity(0.65))
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 3) {
                Text(state.isPlaying ? "Playing" : "Paused")
                    .font(.system(.caption, design: .rounded, weight: .semibold))
                    .foregroundStyle(state.isPlaying ? Color.amber : .white.opacity(0.5))
                if state.isPlaying {
                    Text(state.startedAt, style: .timer)
                        .font(.system(.caption, design: .rounded))
                        .foregroundStyle(.white.opacity(0.5))
                        .monospacedDigit()
                }
            }
        }
        .padding(16)
    }
}

// Mirrors the app's brand colors — kept in sync manually since widget
// extensions and the app don't share a SwiftUI module.
private extension Color {
    static let stage = Color(red: 0.06, green: 0.055, blue: 0.07)
    static let amber = Color(red: 1.0, green: 0.62, blue: 0.25)
    static let ember = Color(red: 0.95, green: 0.36, blue: 0.22)
}
