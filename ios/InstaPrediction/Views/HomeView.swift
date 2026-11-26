// Hovedskærmen i iOS' egen stil (som Mindtrace): grupperet liste, teal accent, store pille-knapper.
// Ingen hoppen: listen ruller kun, hvis indholdet er højere end skærmen.
import SwiftUI

struct HomeView: View {
    @Environment(AppState.self) private var app

    var body: some View {
        @Bindable var app = app
        NavigationStack {
            List {
                accountSection
                bioSection
                lockSection
            }
            .listStyle(.insetGrouped)
            .scrollBounceBehavior(.basedOnSize)
            .scrollDismissesKeyboard(.interactively)
            .navigationTitle("Bio")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { app.settingsOpen = true } label: { Image(systemName: "gearshape") }
                        .accessibilityLabel("Indstillinger")
                }
            }
        }
        .tint(Theme.accent)
        .sheet(isPresented: $app.loginOpen) { LoginSheet() }
        .sheet(isPresented: $app.settingsOpen) { SettingsView() }
        .fullScreenCover(isPresented: $app.lockOpen) { LockScreen().environment(app) }
    }

    // MARK: Konto

    private var accountSection: some View {
        @Bindable var app = app
        return Section {
            Button {
                if app.loggedIn { app.openProfile() } else { app.loginOpen = true }
            } label: {
                HStack(spacing: 12) {
                    SettingsIcon(symbol: "person.fill", color: .pink)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(app.loggedIn ? (app.username.isEmpty ? "Logget ind" : "@\(app.username)") : "Log ind på Instagram")
                            .foregroundStyle(.primary)
                        if app.loggedIn {
                            Text(app.s.practice ? "Øve-tilstand · skriver ikke" : "Klar · skriver til bioen")
                                .font(.footnote)
                                .foregroundStyle(app.s.practice ? .orange : Theme.accent)
                        }
                    }
                    Spacer()
                    Image(systemName: "chevron.right").font(.footnote.weight(.semibold)).foregroundStyle(.tertiary)
                }
            }
            Toggle(isOn: $app.s.practice) {
                Label { Text("Øve-tilstand") } icon: { SettingsIcon(symbol: "graduationcap.fill", color: .orange) }
            }
            if app.s.useRelay && RelayClient.clean(app.s.room).count >= 3 {
                HStack(spacing: 12) {
                    SettingsIcon(symbol: "antenna.radiowaves.left.and.right", color: .green)
                    Text("Relæ")
                    Spacer()
                    Text(app.relayStatus == "online" ? "Online" : "Forbinder …").foregroundStyle(.secondary)
                }
            }
        } header: { Text("Konto") }
    }

    // MARK: Bio

    private var bioSection: some View {
        @Bindable var app = app
        let r = app.rendered
        return Section {
            Picker(selection: $app.s.activeTemplate) {
                ForEach(app.s.templates) { t in Text(t.name).tag(t.id.uuidString) }
            } label: {
                Label { Text("Skabelon") } icon: { SettingsIcon(symbol: "text.quote", color: .purple) }
            }
            .pickerStyle(.menu)

            ForEach(app.fields, id: \.self) { key in
                HStack {
                    Text(key.prefix(1).uppercased() + key.dropFirst())
                    Spacer(minLength: 16)
                    TextField(placeholder(key), text: Binding(
                        get: { app.values[key]?.text ?? "" },
                        set: { app.setManual(key, $0) }
                    ))
                    .multilineTextAlignment(.trailing)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .foregroundStyle(Theme.accent)
                    if let v = app.values[key], v.source != "manuelt" {
                        Image(systemName: v.source == "låseskærm" ? "lock.fill" : "antenna.radiowaves.left.and.right")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                }
            }

            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Bio").foregroundStyle(.secondary)
                    Spacer()
                    Text("\(r.length) / \(TemplateEngine.bioLimit)")
                        .monospacedDigit()
                        .foregroundStyle(r.tooLong ? .red : .secondary)
                }
                .font(.subheadline)
                Text(preview(r.text))
                    .font(.body)
                    .fixedSize(horizontal: false, vertical: true)
                    .animation(.snappy, value: r.text)
            }
            .padding(.vertical, 4)

            HStack(spacing: 12) {
                PillButton(title: "Afslør", symbol: "sparkles", color: Theme.accent, busy: app.busy) {
                    Task { await app.reveal() }
                }
                PillButton(title: "Nulstil", symbol: "arrow.counterclockwise", color: Color(.systemGray3), busy: false) {
                    Task { await app.resetBio() }
                }
            }
            .disabled(app.busy)
            .listRowInsets(EdgeInsets(top: 12, leading: 16, bottom: 12, trailing: 16))
        } header: {
            Text("Forudsigelse")
        } footer: {
            if let last = app.log.first {
                Text(last.text).foregroundStyle(color(last.kind))
                    .animation(.easeInOut(duration: 0.25), value: last.id)
            }
        }
    }

    // MARK: Låseskærm

    private var lockSection: some View {
        Section {
            Button { app.lockOpen = true } label: {
                HStack(spacing: 12) {
                    SettingsIcon(symbol: "lock.fill", color: .indigo)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Åbn låseskærm").foregroundStyle(.primary)
                        Text(lockSubtitle).font(.footnote).foregroundStyle(.secondary)
                    }
                    Spacer()
                    Image(systemName: "chevron.right").font(.footnote.weight(.semibold)).foregroundStyle(.tertiary)
                }
            }
        } header: { Text("Input") }
    }

    // MARK: Hjælpere

    private var lockSubtitle: String {
        let mode = LockInput.modes.first { $0.id == app.s.lockMode }?.label ?? app.s.lockMode
        return "\(mode) → \(app.s.lockField)"
    }

    /// Manglende felter vises som "…" i stedet for {ord|titel}
    private func preview(_ text: String) -> String {
        let t = text.replacingOccurrences(of: #"\{[^}]*\}"#, with: "…", options: .regularExpression)
        return t.isEmpty ? " " : t
    }

    private func placeholder(_ key: String) -> String {
        switch key {
        case "kort": "fx kh"
        case "tal": "fx 42"
        case "dato": "fx 24. december"
        case "ord": "fx Bornholm"
        case "navn": "fx Sofie"
        default: "Skriv"
        }
    }

    private func color(_ k: LogLine.Kind) -> Color {
        switch k {
        case .info: .secondary
        case .ok: Theme.accent
        case .warn: .orange
        case .error: .red
        }
    }
}

/// Stor pille-knap som i Mindtrace
struct PillButton: View {
    let title: String
    let symbol: String
    let color: Color
    let busy: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                if busy { ProgressView().tint(.white) } else { Image(systemName: symbol) }
                Text(title)
            }
            .font(.headline)
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity, minHeight: 50)
            .background(Capsule().fill(color))
            .contentShape(Capsule())
        }
        .buttonStyle(PressStyle())
    }
}

/// Lidt mindre og mørkere ved tryk
struct PressStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .opacity(configuration.isPressed ? 0.8 : 1)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}
