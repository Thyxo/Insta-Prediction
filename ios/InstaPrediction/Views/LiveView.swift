// Hovedskærmen: status, skabelon, felter, Afslør / Nulstil, bio nu og log.
import SwiftUI

struct LiveView: View {
    @Environment(AppState.self) private var app

    var body: some View {
        @Bindable var app = app
        NavigationStack {
            List {
                if app.s.practice {
                    Section {
                        Label("Øve-tilstand: Instagram ændres ikke", systemImage: "graduationcap.fill")
                            .foregroundStyle(.orange)
                    }
                }

                Section("Status") {
                    HStack {
                        Label("Instagram", systemImage: "person.crop.circle")
                        Spacer()
                        if app.loggedIn {
                            Text(app.username.isEmpty ? "Logget ind" : "@\(app.username)").foregroundStyle(.secondary)
                        } else {
                            Button("Log ind") { app.loginOpen = true }
                        }
                    }
                    HStack {
                        Label("Relæ", systemImage: "antenna.radiowaves.left.and.right")
                        Spacer()
                        Text(relayText).foregroundStyle(.secondary)
                        Circle().fill(relayColor).frame(width: 9, height: 9)
                    }
                }

                Section {
                    Button {
                        app.lockOpen = true
                    } label: {
                        HStack(spacing: 12) {
                            Image(systemName: "lock.iphone")
                                .font(.title2)
                                .foregroundStyle(.white)
                                .frame(width: 44, height: 44)
                                .background(RoundedRectangle(cornerRadius: 11).fill(
                                    LinearGradient(colors: [Color(red: 0.35, green: 0.32, blue: 0.86), Color(red: 0.76, green: 0.21, blue: 0.52)],
                                                   startPoint: .topLeading, endPoint: .bottomTrailing)))
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Låseskærm").font(.headline).foregroundStyle(.primary)
                                Text("\(lockModeLabel) → {\(app.s.lockField)}" + (app.s.lockAutoReveal ? " · afslører selv" : ""))
                                    .font(.footnote).foregroundStyle(.secondary)
                            }
                            Spacer()
                            Image(systemName: "play.fill").foregroundStyle(Color.accentColor)
                        }
                        .padding(.vertical, 4)
                    }
                    NavigationLink { LockSettings() } label: {
                        Label("Indstil låseskærm", systemImage: "slider.horizontal.3")
                    }
                } header: { Text("Input") }

                Section {
                    Picker("Skabelon", selection: $app.s.activeTemplate) {
                        ForEach(app.s.templates) { t in Text(t.name).tag(t.id.uuidString) }
                    }
                    let r = app.rendered
                    Text(r.text.isEmpty ? "–" : r.text)
                        .font(.body)
                        .textSelection(.enabled)
                    HStack {
                        Text("\(r.length)/\(TemplateEngine.bioLimit)")
                            .foregroundStyle(r.tooLong ? .red : .secondary)
                        Spacer()
                        if !r.missing.isEmpty {
                            Text("Mangler: \(r.missing.joined(separator: ", "))").foregroundStyle(.orange)
                        }
                    }
                    .font(.footnote)
                } header: { Text("Afsløring") }

                if !app.fields.isEmpty {
                    Section {
                        ForEach(app.fields, id: \.self) { key in FieldRow(key: key) }
                        Button("Ryd felter") { app.clearValues() }
                    } header: { Text("Felter") } footer: {
                        Text("Skriv selv, eller lad relæet udfylde. Kort: kh = hjerter konge, 10s = spar 10.")
                    }
                }

                Section {
                    Button {
                        Task { await app.reveal() }
                    } label: {
                        HStack {
                            Spacer()
                            if app.busy { ProgressView().tint(.white) } else { Text("Afslør i bio").bold() }
                            Spacer()
                        }
                        .foregroundStyle(.white)
                        .padding(.vertical, 6)
                    }
                    .listRowBackground(app.rendered.missing.isEmpty ? Color.accentColor : Color.gray.opacity(0.4))
                    .disabled(app.busy)

                    Button("Nulstil bio", role: .destructive) { Task { await app.resetBio() } }
                        .disabled(app.busy)
                    Button("Åbn profil i Instagram") { app.openProfile() }
                        .disabled(app.username.isEmpty)
                }

                Section {
                    Text(app.currentBio.isEmpty ? "–" : app.currentBio)
                        .foregroundStyle(.secondary)
                    Button("Hent igen") { Task { await app.refreshProfile() } }
                        .disabled(!app.loggedIn)
                } header: { Text("Bio på Instagram nu") }

                if !app.log.isEmpty {
                    Section("Log") {
                        ForEach(app.log.prefix(30)) { line in
                            HStack(alignment: .firstTextBaseline, spacing: 8) {
                                Text(line.time, format: .dateTime.hour().minute().second())
                                    .font(.caption2.monospacedDigit()).foregroundStyle(.tertiary)
                                Text(line.text).font(.footnote).foregroundStyle(color(line.kind))
                            }
                        }
                    }
                }
            }
            .navigationTitle("Bio")
            .refreshable { await app.refreshProfile() }
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    NavigationLink { TemplatesView() } label: { Image(systemName: "text.badge.plus") }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button { app.settingsOpen = true } label: { Image(systemName: "gearshape") }
                }
            }
        }
        .sheet(isPresented: $app.loginOpen) { LoginSheet() }
        .sheet(isPresented: $app.settingsOpen) { SettingsView() }
        .fullScreenCover(isPresented: $app.lockOpen) {
            LockScreen().environment(app)
        }
    }

    private var lockModeLabel: String {
        LockInput.modes.first { $0.id == app.s.lockMode }?.label ?? app.s.lockMode
    }

    private var relayText: String {
        switch app.relayStatus {
        case "online": "Online · \(RelayClient.clean(app.s.room))"
        case "connecting": "Forbinder …"
        case "offline": "Offline"
        default: "Fra"
        }
    }

    private var relayColor: Color {
        switch app.relayStatus {
        case "online": .green
        case "connecting": .yellow
        case "offline": .red
        default: .gray
        }
    }

    private func color(_ k: LogLine.Kind) -> Color {
        switch k {
        case .info: .secondary
        case .ok: .green
        case .warn: .orange
        case .error: .red
        }
    }
}

struct FieldRow: View {
    @Environment(AppState.self) private var app
    let key: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(key).font(.caption.weight(.semibold)).foregroundStyle(.secondary)
                Spacer()
                if let v = app.values[key] {
                    Text(v.source).font(.caption2).foregroundStyle(.tertiary)
                } else if let p = app.s.sources[key], !p.isEmpty {
                    Text("venter på \(p)").font(.caption2).foregroundStyle(.tertiary)
                }
            }
            TextField("Skriv \(key) …", text: Binding(
                get: { app.values[key]?.text ?? "" },
                set: { app.setManual(key, $0) }
            ))
            .textInputAutocapitalization(.never)
            .autocorrectionDisabled()
        }
    }
}
