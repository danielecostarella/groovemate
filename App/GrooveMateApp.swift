import SwiftUI

@main
struct GrooveMateApp: App {
    @State private var session = GrooveSession()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(session)
                .preferredColorScheme(.dark)
        }
    }
}

struct RootView: View {
    @Environment(GrooveSession.self) private var session

    var body: some View {
        ZStack {
            Color.stage.ignoresSafeArea()
            if session.persona == nil {
                DrummerPickerView()
            } else {
                GrooveScreen()
                    .transition(.move(edge: .trailing).combined(with: .opacity))
            }
        }
        .animation(.spring(duration: 0.45), value: session.persona?.id)
    }
}

extension Color {
    /// Near-black stage backdrop.
    static let stage = Color(red: 0.06, green: 0.055, blue: 0.07)
    static let card = Color(red: 0.11, green: 0.105, blue: 0.125)
    static let amber = Color(red: 1.0, green: 0.62, blue: 0.25)
    static let ember = Color(red: 0.95, green: 0.36, blue: 0.22)
}
