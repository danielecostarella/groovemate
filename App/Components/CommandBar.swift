import SwiftUI

/// "Tell your drummer…" — the natural-language way in.
struct CommandBar: View {
    @Binding var text: String
    let acknowledgement: String?
    var onSend: () -> Void

    @FocusState private var focused: Bool

    var body: some View {
        VStack(spacing: 8) {
            if let acknowledgement {
                Text(acknowledgement)
                    .font(.system(.footnote, design: .rounded, weight: .medium))
                    .foregroundStyle(Color.amber)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 6)
                    .background(Color.amber.opacity(0.12), in: Capsule())
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
            HStack(spacing: 10) {
                TextField("Tell your drummer…", text: $text, axis: .vertical)
                    .lineLimit(1...3)
                    .font(.system(.body, design: .rounded))
                    .focused($focused)
                    .submitLabel(.send)
                    .onSubmit(onSend)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(Color.card, in: Capsule())
                    .overlay(Capsule().strokeBorder(Color.white.opacity(0.1)))
                Button(action: onSend) {
                    Image(systemName: "arrow.up.circle.fill")
                        .font(.system(size: 32))
                        .foregroundStyle(text.isEmpty ? Color.white.opacity(0.2) : Color.amber)
                }
                .buttonStyle(.plain)
                .disabled(text.isEmpty)
                .accessibilityLabel("Send")
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 8)
        .padding(.bottom, 10)
        .background(.ultraThinMaterial)
        .animation(.spring(duration: 0.3), value: acknowledgement)
    }
}
