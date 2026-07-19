import SwiftUI

/// "Tell your drummer…" — the natural-language way in. An input capsule with
/// an inline send button, meant to sit in a bottom bar.
struct CommandBar: View {
    @Binding var text: String
    var onSend: () -> Void

    @FocusState private var focused: Bool

    var body: some View {
        HStack(spacing: 4) {
            TextField("Tell your drummer…", text: $text, axis: .vertical)
                .lineLimit(1...3)
                .font(.system(.body, design: .rounded))
                .focused($focused)
                .submitLabel(.send)
                .onSubmit(onSend)
                .padding(.leading, 16)
                .padding(.vertical, 12)
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
        .background(Color.card, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .strokeBorder(Color.white.opacity(0.1))
        )
    }
}
