import SwiftUI

/// "Tell your drummer…" — the natural-language way in. An input capsule with
/// a mic (on-device speech) and an inline send button, meant to sit in a bottom bar.
struct CommandBar: View {
    @Binding var text: String
    var isListening: Bool
    var onMic: () -> Void
    var onSend: () -> Void

    @FocusState private var focused: Bool

    var body: some View {
        HStack(spacing: 4) {
            TextField(isListening ? "Listening…" : "Tell your drummer…", text: $text, axis: .vertical)
                .lineLimit(1...3)
                .font(.system(.body, design: .rounded))
                .focused($focused)
                .submitLabel(.send)
                .onSubmit(onSend)
                .padding(.leading, 16)
                .padding(.vertical, 12)
            Button(action: onMic) {
                Image(systemName: isListening ? "waveform.circle.fill" : "mic.fill")
                    .font(.title2)
                    .foregroundStyle(isListening ? AnyShapeStyle(Color.ember) : AnyShapeStyle(Color.amber))
                    .frame(width: 44, height: 44)
                    .symbolEffect(.pulse, options: .repeating, isActive: isListening)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(isListening ? "Stop listening and send" : "Speak to your drummer")
            Button(action: onSend) {
                Image(systemName: "arrow.up.circle.fill")
                    .font(.title2)
                    .foregroundStyle(text.isEmpty ? AnyShapeStyle(.tertiary) : AnyShapeStyle(Color.amber))
                    .frame(width: 44, height: 44)
            }
            .buttonStyle(.plain)
            .disabled(text.isEmpty)
            .accessibilityLabel("Send")
        }
        .glassBackground(in: RoundedRectangle(cornerRadius: 24, style: .continuous), tint: isListening ? Color.ember : nil)
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .strokeBorder(isListening ? Color.ember.opacity(0.5) : Color.clear)
        )
        .animation(.easeInOut(duration: 0.2), value: isListening)
    }
}
