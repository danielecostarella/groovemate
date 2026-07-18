import SwiftUI
import GrooveModel

struct DrummerPickerView: View {
    @Environment(GrooveSession.self) private var session

    private let columns = [GridItem(.adaptive(minimum: 160), spacing: 14)]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 6) {
                Text("GrooveMate")
                    .font(.system(.subheadline, design: .rounded, weight: .semibold))
                    .foregroundStyle(Color.amber)
                    .textCase(.uppercase)
                    .kerning(2)
                Text("Choose your drummer")
                    .font(.system(.largeTitle, design: .rounded, weight: .bold))
                    .foregroundStyle(.white)
                Text("A real player, on call. Change your mind anytime.")
                    .font(.system(.callout, design: .rounded))
                    .foregroundStyle(.secondary)
                    .padding(.bottom, 12)

                LazyVGrid(columns: columns, spacing: 14) {
                    ForEach(DrummerPersona.all) { persona in
                        Button {
                            session.select(persona)
                        } label: {
                            PersonaCard(persona: persona)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .padding(20)
            .frame(maxWidth: 700)
            .frame(maxWidth: .infinity)
        }
    }
}

private struct PersonaCard: View {
    let persona: DrummerPersona

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 26, weight: .medium))
                .foregroundStyle(gradient)
                .frame(width: 52, height: 52)
                .background(Color.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 14))
            Text(persona.name)
                .font(.system(.title3, design: .rounded, weight: .bold))
                .foregroundStyle(.white)
            Text(persona.tagline)
                .font(.system(.footnote, design: .rounded))
                .foregroundStyle(.secondary)
                .lineLimit(2, reservesSpace: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(Color.card, in: RoundedRectangle(cornerRadius: 20))
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .strokeBorder(Color.white.opacity(0.07))
        )
        .contentShape(RoundedRectangle(cornerRadius: 20))
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
