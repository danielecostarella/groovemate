import SwiftUI
import GrooveModel

struct GrooveScreen: View {
    @Environment(GrooveSession.self) private var session
    @State private var commandText = ""

    var body: some View {
        let spec = session.spec

        VStack(spacing: 0) {
            // Fixed hero: the drummer's heartbeat and tempo, always visible.
            VStack(spacing: 12) {
                BeatIndicator(position: session.position, beatsPerBar: Int(spec.beatsPerBar))
                TempoControl(
                    bpm: Binding(
                        get: { session.spec.bpm },
                        set: { var s = session.spec; s.bpm = $0; session.spec = s }
                    ),
                    onTap: { session.tapTempo() }
                )
            }
            .padding(.horizontal, 20)
            .padding(.top, 8)
            .frame(maxWidth: 560)
            .frame(maxWidth: .infinity)

            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    section("Feel") { feelCard }
                    section("Groove") { grooveCard }
                }
                .padding(.horizontal, 20)
                .padding(.top, 12)
                .padding(.bottom, 12)
                .frame(maxWidth: 560)
                .frame(maxWidth: .infinity)
            }
            .scrollDismissesKeyboard(.interactively)
        }
        .background(Color.stage)
        .safeAreaInset(edge: .bottom) { bottomBar }
        .navigationTitle(session.persona?.name ?? "GrooveMate")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if session.engineState == .warmingUp {
                ToolbarItem(placement: .topBarTrailing) {
                    ProgressView()
                        .accessibilityLabel("Warming up")
                }
            }
        }
    }

    // MARK: - Sections

    private func section(_ title: String, @ViewBuilder content: () -> some View) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.system(.footnote, design: .rounded, weight: .semibold))
                .foregroundStyle(.secondary)
                .textCase(.uppercase)
                .padding(.leading, 4)
                .accessibilityAddTraits(.isHeader)
            content()
        }
    }

    private var feelCard: some View {
        VStack(spacing: 10) {
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
        .padding(16)
        .background(Color.card, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private var grooveCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            StyleRow(
                selected: session.spec.style,
                select: { style in
                    var s = session.spec
                    s.style = style
                    s.bpm = min(max(s.bpm, style.tempoRange.lowerBound), style.tempoRange.upperBound)
                    session.spec = s
                }
            )

            Divider().overlay(Color.white.opacity(0.08))

            HStack(spacing: 12) {
                Text("Fills")
                    .font(.system(.subheadline, design: .rounded, weight: .semibold))
                    .foregroundStyle(.primary)
                Spacer(minLength: 8)
                Picker("Fills", selection: Binding(
                    get: { session.spec.fillEveryBars },
                    set: { var s = session.spec; s.fillEveryBars = $0; session.spec = s }
                )) {
                    Text("Off").tag(0)
                    Text("2").tag(2)
                    Text("4").tag(4)
                    Text("8").tag(8)
                }
                .pickerStyle(.segmented)
                .frame(maxWidth: 240)
                .accessibilityLabel("Play a fill every how many bars")
            }
        }
        .padding(16)
        .background(Color.card, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    // MARK: - Bottom bar (transport + command, in thumb reach)

    private var bottomBar: some View {
        VStack(spacing: 10) {
            if let acknowledgement = session.acknowledgement {
                Text(acknowledgement)
                    .font(.system(.footnote, design: .rounded, weight: .medium))
                    .foregroundStyle(Color.amber)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 6)
                    .background(Color.amber.opacity(0.12), in: Capsule())
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
            HStack(spacing: 12) {
                playButton
                CommandBar(text: $commandText) {
                    session.send(command: commandText)
                    commandText = ""
                }
            }
            .frame(maxWidth: 560)
        }
        .padding(.horizontal, 20)
        .padding(.top, 10)
        .padding(.bottom, 8)
        .frame(maxWidth: .infinity)
        .background(.ultraThinMaterial)
        .animation(.spring(duration: 0.3), value: session.acknowledgement)
    }

    private var playButton: some View {
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
                    .frame(width: 52, height: 52)
                    .shadow(color: .ember.opacity(session.isPlaying ? 0.5 : 0.25), radius: 12, y: 3)
                if session.engineState == .warmingUp {
                    ProgressView()
                        .tint(Color.stage)
                } else {
                    Image(systemName: session.isPlaying ? "stop.fill" : "play.fill")
                        .font(.title3.weight(.bold))
                        .foregroundStyle(Color.stage)
                        .contentTransition(.symbolEffect(.replace))
                }
            }
        }
        .buttonStyle(.plain)
        .disabled(session.engineState == .warmingUp)
        .accessibilityLabel(session.isPlaying ? "Stop" : "Play")
    }
}
