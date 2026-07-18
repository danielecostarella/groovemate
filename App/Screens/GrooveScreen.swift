import SwiftUI
import GrooveModel

struct GrooveScreen: View {
    @Environment(GrooveSession.self) private var session
    @State private var commandText = ""

    var body: some View {
        @Bindable var session = session
        let spec = session.spec

        VStack(spacing: 0) {
            header
            ScrollView {
                VStack(spacing: 22) {
                    BeatIndicator(position: session.position, beatsPerBar: Int(spec.beatsPerBar))
                        .padding(.top, 8)

                    transport

                    TempoControl(
                        bpm: Binding(
                            get: { session.spec.bpm },
                            set: { var s = session.spec; s.bpm = $0; session.spec = s }
                        ),
                        onTap: { session.tapTempo() }
                    )

                    feelSliders

                    StyleRow(
                        selected: spec.style,
                        select: { style in
                            var s = session.spec
                            s.style = style
                            s.bpm = min(max(s.bpm, style.tempoRange.lowerBound), style.tempoRange.upperBound)
                            session.spec = s
                        }
                    )

                    fillControl
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 90)
                .frame(maxWidth: 640)
                .frame(maxWidth: .infinity)
            }
        }
        .safeAreaInset(edge: .bottom) {
            CommandBar(text: $commandText, acknowledgement: session.acknowledgement) {
                session.send(command: commandText)
                commandText = ""
            }
        }
    }

    private var header: some View {
        HStack {
            Button {
                session.stop()
                withAnimation { session.deselect() }
            } label: {
                Label("Drummers", systemImage: "chevron.left")
                    .font(.system(.callout, design: .rounded, weight: .medium))
            }
            .tint(.amber)
            Spacer()
            if let persona = session.persona {
                VStack(spacing: 1) {
                    Text(persona.name)
                        .font(.system(.headline, design: .rounded, weight: .bold))
                        .foregroundStyle(.white)
                    Text(session.engineState == .warmingUp ? "warming up…" : persona.tagline)
                        .font(.system(.caption2, design: .rounded))
                        .foregroundStyle(.secondary)
                }
            }
            Spacer()
            // Balance the leading button.
            Label("Drummers", systemImage: "chevron.left")
                .font(.system(.callout, design: .rounded, weight: .medium))
                .hidden()
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 10)
    }

    private var transport: some View {
        Button {
            session.togglePlayback()
        } label: {
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: session.isPlaying ? [.ember, .amber] : [.amber, .ember],
                            startPoint: .topLeading, endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 92, height: 92)
                    .shadow(color: .ember.opacity(session.isPlaying ? 0.55 : 0.25), radius: 24, y: 6)
                Image(systemName: session.isPlaying ? "stop.fill" : "play.fill")
                    .font(.system(size: 34, weight: .bold))
                    .foregroundStyle(Color.stage)
                    .contentTransition(.symbolEffect(.replace))
            }
        }
        .buttonStyle(.plain)
        .disabled(session.engineState == .warmingUp)
        .opacity(session.engineState == .warmingUp ? 0.5 : 1)
        .accessibilityLabel(session.isPlaying ? "Stop" : "Play")
    }

    private var feelSliders: some View {
        VStack(spacing: 14) {
            FeelSlider(
                left: "Tight", right: "Loose",
                value: Binding(
                    get: { 1 - session.spec.tightness },
                    set: { var s = session.spec; s.tightness = 1 - $0; session.spec = s }
                )
            )
            FeelSlider(
                left: "Simple", right: "Complex",
                value: Binding(
                    get: { session.spec.complexity },
                    set: { var s = session.spec; s.complexity = $0; session.spec = s }
                )
            )
            FeelSlider(
                left: "Soft", right: "Powerful",
                value: Binding(
                    get: { session.spec.intensity },
                    set: { var s = session.spec; s.intensity = $0; session.spec = s }
                )
            )
            FeelSlider(
                left: "Straight", right: "Swung",
                value: Binding(
                    get: { session.spec.swing },
                    set: { var s = session.spec; s.swing = $0; session.spec = s }
                )
            )
        }
        .padding(18)
        .background(Color.card, in: RoundedRectangle(cornerRadius: 20))
    }

    private var fillControl: some View {
        HStack {
            Label("Fills", systemImage: "wand.and.rays")
                .font(.system(.callout, design: .rounded, weight: .medium))
                .foregroundStyle(.white)
            Spacer()
            Picker("Fills", selection: Binding(
                get: { session.spec.fillEveryBars },
                set: { var s = session.spec; s.fillEveryBars = $0; session.spec = s }
            )) {
                Text("Off").tag(0)
                Text("Every 2").tag(2)
                Text("Every 4").tag(4)
                Text("Every 8").tag(8)
            }
            .pickerStyle(.segmented)
            .frame(maxWidth: 320)
        }
        .padding(16)
        .background(Color.card, in: RoundedRectangle(cornerRadius: 20))
    }
}
