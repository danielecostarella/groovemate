import SwiftUI
import GrooveModel

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
        NavigationStack {
            DrummerPickerView()
                .navigationDestination(isPresented: showsGroove) {
                    GrooveScreen()
                }
        }
        .tint(.amber)
        .onAppear(perform: applyLaunchArguments)
    }

    /// Drives the standard push/pop: a selected persona pushes the groove
    /// screen; the system back button (or swipe) deselects it.
    private var showsGroove: Binding<Bool> {
        Binding(
            get: { session.persona != nil },
            set: { isShown in
                if !isShown { session.deselect() }
            }
        )
    }

    /// Dev/verification hook: `-persona rock [-autoplay]` skips the picker.
    private func applyLaunchArguments() {
        let args = ProcessInfo.processInfo.arguments
        guard let i = args.firstIndex(of: "-persona"), i + 1 < args.count,
              let persona = DrummerPersona.all.first(where: { $0.id == args[i + 1] })
        else { return }
        session.select(persona)
        if args.contains("-autoplay") {
            Task { @MainActor in
                while session.engineState == .warmingUp {
                    try? await Task.sleep(for: .milliseconds(100))
                }
                session.play()
            }
        }
    }
}

extension Color {
    /// Near-black stage backdrop.
    static let stage = Color(red: 0.06, green: 0.055, blue: 0.07)
    static let card = Color(red: 0.11, green: 0.105, blue: 0.125)
    static let amber = Color(red: 1.0, green: 0.62, blue: 0.25)
    static let ember = Color(red: 0.95, green: 0.36, blue: 0.22)
}
