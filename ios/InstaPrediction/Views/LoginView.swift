// Login på instagram.com i en indbygget browser. iOS gemmer cookies; vi ser aldrig koden.
import SwiftUI
import WebKit

struct LoginSheet: View {
    @Environment(AppState.self) private var app
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            LoginWebView()
                .ignoresSafeArea(edges: .bottom)
                .navigationTitle("Log ind på Instagram")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) { Button("Luk") { dismiss() } }
                }
        }
        .task {
            // Tjek jævnligt om sessionid-cookien er kommet (login + evt. 2FA er færdig)
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 1_500_000_000)
                if await app.ig.isLoggedIn() {
                    await app.didLogin()
                    dismiss()
                    return
                }
            }
        }
    }
}

struct LoginWebView: UIViewRepresentable {
    func makeUIView(context: Context) -> WKWebView {
        let cfg = WKWebViewConfiguration()
        cfg.websiteDataStore = .default()
        let wv = WKWebView(frame: .zero, configuration: cfg)
        wv.customUserAgent = Instagram.userAgent
        wv.allowsBackForwardNavigationGestures = true
        wv.load(URLRequest(url: Instagram.loginURL))
        return wv
    }

    func updateUIView(_ uiView: WKWebView, context: Context) {}
}
