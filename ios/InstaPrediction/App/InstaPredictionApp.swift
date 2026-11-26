// Insta Prediction: tilskuerens tanke dukker op i din rigtige Instagram-bio.
import SwiftUI

@main
struct InstaPredictionApp: App {
    @State private var app = AppState()
    @Environment(\.scenePhase) private var phase

    var body: some Scene {
        WindowGroup {
            LiveView()
                .environment(app)
                .preferredColorScheme(.dark)
                .task { await app.start() }
                .onChange(of: phase) { _, p in app.phase(p) }
        }
    }
}
