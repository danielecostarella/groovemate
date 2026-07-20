import SwiftUI
import GrooveModel

/// First-run choice screen: tell the drummer what you want, or pick one by hand.
struct DrummerPickerView: View {
    @Environment(GrooveSession.self) private var session
    @State private var promptText = ""

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Text("A real player, on call. Tell them what to play, or pick one.")
                    .font(.system(.subheadline, design: .rounded))
                    .foregroundStyle(.secondary)

                VStack(spacing: 12) {
                    ForEach(DrummerPersona.all) { persona in
                        Button {
                            session.select(persona)
                        } label: {
                            PersonaRow(persona: persona)
                        }
                        .buttonStyle(.plain)
                        .accessibilityHint(Text(persona.tagline))
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 4)
            .padding(.bottom, 24)
            .frame(maxWidth: 640)
            .frame(maxWidth: .infinity)
        }
        .background(Color.stage)
        .navigationTitle("Choose Your Drummer")
        .safeAreaInset(edge: .bottom) { promptBar }
    }

    /// The fastest way in: "suona un ritmo rock a 120" hires the right
    /// drummer, applies the request, and counts it in.
    private var promptBar: some View {
        VStack(spacing: 8) {
            if let acknowledgement = session.acknowledgement {
                Text(acknowledgement)
                    .font(.system(.footnote, design: .rounded, weight: .medium))
                    .foregroundStyle(Color.amber)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 6)
                    .glassBackground(in: Capsule(), tint: .amber)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
            CommandBar(
                text: $promptText,
                isListening: session.voice.isListening,
                onMic: { session.toggleVoice() },
                onSend: {
                    session.send(command: promptText)
                    promptText = ""
                }
            )
            .frame(maxWidth: 560)
            .onChange(of: session.voice.transcript) { _, new in
                if session.voice.isListening { promptText = new }
            }
            .onChange(of: session.voice.isListening) { was, now in
                if was && !now { promptText = "" }
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 8)
        .padding(.bottom, 8)
        .frame(maxWidth: .infinity)
        .animation(.spring(duration: 0.3), value: session.acknowledgement)
    }
}

private struct PersonaRow: View {
    let persona: DrummerPersona

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: icon)
                .font(.title2.weight(.medium))
                .foregroundStyle(gradient)
                .frame(width: 48, height: 48)
                .background(Color.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 2) {
                Text(persona.name)
                    .font(.system(.headline, design: .rounded))
                    .foregroundStyle(.primary)
                Text(persona.tagline)
                    .font(.system(.subheadline, design: .rounded))
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 8)

            Image(systemName: "chevron.right")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(.tertiary)
                .accessibilityHidden(true)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.card, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(Color.white.opacity(0.06))
        )
        .contentShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .hoverEffect(.lift)
    }

    private var icon: String {
        switch persona.id {
        case "rock": return "bolt.fill"
        case "funk": return "waveform.path"
        case "jazz": return "moon.stars.fill"
        case "studio": return "dial.medium.fill"
        case "vintage": return "radio.fill"
        default: return "sparkles"
        }
    }

    private var gradient: LinearGradient {
        LinearGradient(colors: [.amber, .ember], startPoint: .topLeading, endPoint: .bottomTrailing)
    }
}
