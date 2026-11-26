// Indstillinger: Instagram, relæ og kilder, afsløring, standard-bio og diagnose.
import SwiftUI

struct SettingsView: View {
    @Environment(AppState.self) private var app
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        @Bindable var app = app
        NavigationStack {
            Form {
                Section {
                    Toggle("Øve-tilstand", isOn: $app.s.practice)
                } footer: {
                    Text("Når den er slået til, skrives der ikke til Instagram. Alt andet kører som ved et show.")
                }

                Section("Instagram") {
                    if app.loggedIn {
                        LabeledContent("Konto", value: app.username.isEmpty ? "Logget ind" : "@\(app.username)")
                        Button("Test forbindelse (læs bio)") { Task { await app.refreshProfile() } }
                        Button("Log ud", role: .destructive) { Task { await app.logout() } }
                    } else {
                        Button("Log ind på Instagram") {
                            dismiss()
                            // Login-arket åbnes fra hovedskærmen, når dette ark er lukket
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) { app.loginOpen = true }
                        }
                    }
                    Picker("Metode", selection: $app.s.method) {
                        Text("Auto").tag("auto")
                        Text("Kun bio").tag("bio")
                        Text("Profil-formular").tag("web")
                    }
                    Stepper("Mindst \(Int(app.s.minGap)) sek. mellem ændringer", value: $app.s.minGap, in: 5...120, step: 5)
                }

                Section {
                    TextEditor(text: $app.s.defaultBio)
                        .frame(minHeight: 80)
                    Button("Brug bioen fra Instagram nu") { app.s.defaultBio = app.currentBio }
                        .disabled(app.currentBio.isEmpty)
                } header: { Text("Standard-bio") } footer: {
                    Text("Den sættes tilbage ved \"Nulstil bio\". Den bliver gemt automatisk første gang, du logger ind.")
                }

                Section {
                    Toggle("Brug relæet", isOn: $app.s.useRelay)
                    if app.s.useRelay {
                        TextField("Rum-kode", text: $app.s.room)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                        Toggle("Lyt efter kommandoer", isOn: $app.s.listenCommands)
                        Toggle("Hold kørende i baggrunden", isOn: $app.s.keepAlive)
                    }
                } header: { Text("Relæ") } footer: {
                    Text("Samme rum-kode som i Fake Google, Noter+ og Calc+. Baggrund er nødvendig, når input kommer fra en anden app på samme telefon. Det bruger lidt mere strøm.")
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
                                .textInputAutocapitalization(.never)
                                .autocorrectionDisabled()
                                .foregroundStyle(.secondary)
                            }
                        }
                    } header: { Text("Kilder") } footer: {
                        Text("Kendte stier: " + RelayPath.known.map { "\($0.path) (\($0.label))" }.joined(separator: ", ") + ". Tom = kun manuelt.")
                    }
                }

                Section("Afsløring") {
                    Toggle("Afslør selv, når alle felter er udfyldt", isOn: $app.s.autoReveal)
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

                Section("Diagnose") {
                    if !app.lastError.isEmpty {
                        Text(app.lastError).font(.footnote).foregroundStyle(.red).textSelection(.enabled)
                    }
                    LabeledContent("Version", value: version)
                }
            }
            .navigationTitle("Indstillinger")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) { Button("Færdig") { dismiss() } }
            }
        }
    }

    private var version: String {
        let i = Bundle.main.infoDictionary
        return "\(i?["CFBundleShortVersionString"] as? String ?? "?") (\(i?["CFBundleVersion"] as? String ?? "?"))"
    }
}
