// Indstillinger som i iOS: få rækker på forsiden, detaljer et niveau nede.
import SwiftUI

struct SettingsView: View {
    @Environment(AppState.self) private var app
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        @Bindable var app = app
        NavigationStack {
            List {
                Section {
                    Toggle(isOn: $app.s.practice) {
                        Label { Text("Øve-tilstand") } icon: { SettingsIcon(symbol: "graduationcap.fill", color: .orange) }
                    }
                } footer: {
                    Text("Skriver ikke til Instagram. Alt andet kører som ved et show.")
                }

                Section {
                    link("Instagram", "person.crop.circle.fill", .pink) { InstagramSettings() }
                    link("Skabeloner", "text.quote", .purple) { TemplatesView() }
                    link("Låseskærm", "lock.iphone", .indigo) { LockSettings() }
                    link("Afsløring", "sparkles", .orange) { RevealSettings() }
                    link("Relæ", "antenna.radiowaves.left.and.right", .green) { RelaySettings() }
                }

                Section {
                    link("Log", "list.bullet.rectangle", .gray) { LogView() }
                } footer: {
                    Text("Bio \(version)")
                }
            }
            .navigationTitle("Indstillinger")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) { Button("Færdig") { dismiss() } }
            }
        }
        .preferredColorScheme(.dark)
    }

    private func link<D: View>(_ title: String, _ symbol: String, _ color: Color, @ViewBuilder _ dest: () -> D) -> some View {
        NavigationLink {
            dest()
        } label: {
            Label { Text(title) } icon: { SettingsIcon(symbol: symbol, color: color) }
        }
    }

    private var version: String {
        let i = Bundle.main.infoDictionary
        return "\(i?["CFBundleShortVersionString"] as? String ?? "?") (\(i?["CFBundleVersion"] as? String ?? "?"))"
    }
}

// MARK: Instagram

struct InstagramSettings: View {
    @Environment(AppState.self) private var app

    var body: some View {
        @Bindable var app = app
        Form {
            Section {
                if app.loggedIn {
                    LabeledContent("Konto", value: app.username.isEmpty ? "Logget ind" : "@\(app.username)")
                    Button("Test forbindelse") { Task { await app.refreshProfile() } }
                    Button("Åbn profil i Instagram") { app.openProfile() }
                    Button("Log ud", role: .destructive) { Task { await app.logout() } }
                } else {
                    Button("Log ind på Instagram") {
                        app.settingsOpen = false
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) { app.loginOpen = true }
                    }
                }
            }

            Section {
                Text(app.currentBio.isEmpty ? "–" : app.currentBio).foregroundStyle(.secondary)
            } header: { Text("Bio på Instagram nu") }

            Section {
                TextEditor(text: $app.s.defaultBio).frame(minHeight: 80)
                Button("Brug bioen fra Instagram nu") { app.s.defaultBio = app.currentBio }
                    .disabled(app.currentBio.isEmpty)
            } header: { Text("Standard-bio") } footer: {
                Text("Den sættes tilbage ved Nulstil. Gemmes automatisk første gang, du logger ind.")
            }

            Section("Avanceret") {
                Picker("Metode", selection: $app.s.method) {
                    Text("Auto").tag("auto")
                    Text("Kun bio").tag("bio")
                    Text("Profil-formular").tag("web")
                }
                Stepper("Mindst \(Int(app.s.minGap)) sek. mellem ændringer", value: $app.s.minGap, in: 5...120, step: 5)
            }
        }
        .navigationTitle("Instagram")
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: Afsløring

struct RevealSettings: View {
    @Environment(AppState.self) private var app

    var body: some View {
        @Bindable var app = app
        Form {
            Section {
                Toggle("Afslør selv, når alle felter er udfyldt", isOn: $app.s.autoReveal)
            } footer: {
                Text("Gælder input fra relæet. Låseskærmen har sin egen indstilling.")
            }
            Section {
                Picker("Nulstil bio bagefter", selection: $app.s.autoResetMin) {
                    Text("Aldrig").tag(0)
                    Text("Efter 1 min").tag(1)
                    Text("Efter 2 min").tag(2)
                    Text("Efter 5 min").tag(5)
                    Text("Efter 10 min").tag(10)
                    Text("Efter 30 min").tag(30)
                }
                Toggle("Notifikationer (også på uret)", isOn: $app.s.notify)
            }
        }
        .navigationTitle("Afsløring")
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: Relæ

struct RelaySettings: View {
    @Environment(AppState.self) private var app

    var body: some View {
        @Bindable var app = app
        Form {
            Section {
                Toggle("Brug relæet", isOn: $app.s.useRelay)
                if app.s.useRelay {
                    TextField("Rum-kode", text: $app.s.room)
                        .textInputAutocapitalization(.never).autocorrectionDisabled()
                    Toggle("Lyt efter kommandoer", isOn: $app.s.listenCommands)
                    Toggle("Hold kørende i baggrunden", isOn: $app.s.keepAlive)
                }
            } footer: {
                Text("Samme rum-kode som i Fake Google, Noter+ og Calc+.")
            }
            if app.s.useRelay {
                Section {
                    ForEach(app.s.allFields, id: \.self) { key in
                        HStack {
                            Text("{\(key)}").font(.body.monospaced())
                            TextField("relæ-sti", text: Binding(
                                get: { app.s.sources[key] ?? "" },
                                set: { app.s.sources[key] = $0 }
                            ))
                            .multilineTextAlignment(.trailing)
                            .textInputAutocapitalization(.never).autocorrectionDisabled()
                            .foregroundStyle(.secondary)
                        }
                    }
                } header: { Text("Kilder") } footer: {
                    Text(RelayPath.known.map { "\($0.path): \($0.label)" }.joined(separator: "\n"))
                }
            }
        }
        .navigationTitle("Relæ")
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: Log

struct LogView: View {
    @Environment(AppState.self) private var app

    var body: some View {
        List {
            if !app.lastError.isEmpty {
                Section("Seneste fejl") {
                    Text(app.lastError).font(.footnote).foregroundStyle(.red).textSelection(.enabled)
                }
            }
            Section {
                if app.log.isEmpty { Text("Intet endnu").foregroundStyle(.secondary) }
                ForEach(app.log) { line in
                    VStack(alignment: .leading, spacing: 2) {
                        Text(line.time, format: .dateTime.hour().minute().second())
                            .font(.caption2.monospacedDigit()).foregroundStyle(.tertiary)
                        Text(line.text).font(.footnote)
                    }
                }
            }
        }
        .navigationTitle("Log")
        .navigationBarTitleDisplayMode(.inline)
    }
}
