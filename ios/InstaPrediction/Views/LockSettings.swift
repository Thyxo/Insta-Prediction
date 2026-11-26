// Indstillinger for låseskærm-input: input, afsløring, udseende og urskrift.
import PhotosUI
import SwiftUI
import UniformTypeIdentifiers

struct LockSettings: View {
    @Environment(AppState.self) private var app
    @State private var pick: PhotosPickerItem?
    @State private var importing = false
    @State private var fonts = ClockFonts.list()
    @State private var fontLink = ""

    var body: some View {
        @Bindable var app = app
        Form {
            Section {
                Button {
                    app.settingsOpen = false
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { app.lockOpen = true }
                } label: {
                    Label("Åbn låseskærm", systemImage: "play.fill").bold()
                }
            } footer: {
                Text("Tilbage til Bio: 5 hurtige tryk øverst til højre.")
            }

            Section {
                Picker("Fortolk som", selection: $app.s.lockMode) {
                    ForEach(LockInput.modes, id: \.id) { m in Text(m.label).tag(m.id) }
                }
                Picker("Skriv i feltet", selection: $app.s.lockField) {
                    ForEach(fieldChoices, id: \.self) { f in Text("{\(f)}").tag(f) }
                }
                Picker("Kode", selection: $app.s.lockCodeLength) {
                    Text("4 cifre").tag(4)
                    Text("6 cifre").tag(6)
                }
                .pickerStyle(.segmented)
            } header: { Text("Input") } footer: {
                Text((LockInput.modes.first { $0.id == app.s.lockMode }?.help ?? "") + example)
            }

            Section("Afsløring") {
                Toggle("Afslør med det samme", isOn: $app.s.lockAutoReveal)
                if app.s.lockAutoReveal {
                    Picker("Vent først", selection: $app.s.lockDelay) {
                        Text("0 sek.").tag(0.0)
                        Text("2 sek.").tag(2.0)
                        Text("5 sek.").tag(5.0)
                        Text("10 sek.").tag(10.0)
                        Text("30 sek.").tag(30.0)
                    }
                }
                Toggle("Hængelås blinker ved input", isOn: $app.s.lockBlink)
            }

            Section {
                fontStatus
                if !fonts.isEmpty {
                    Picker("Skrift", selection: $app.s.lockFont) {
                        Text("Auto").tag("")
                        ForEach(fonts, id: \.self) { f in Text(f.replacingOccurrences(of: "-VF.otf", with: "")).tag(f) }
                    }
                }
                Button {
                    importing = true
                } label: {
                    Label("Vælg zip eller .otf fra Filer …", systemImage: "folder")
                }
                Button {
                    Task { await app.findFonts(auto: false) }
                } label: {
                    HStack {
                        Label("Søg i iOS på telefonen", systemImage: "magnifyingglass")
                        if app.fontSearching { Spacer(); ProgressView() }
                    }
                }
                .disabled(app.fontSearching)
                DisclosureGroup("Flere muligheder") {
                    HStack {
                        TextField("Direkte link til .otf", text: $fontLink)
                            .textInputAutocapitalization(.never).autocorrectionDisabled()
                            .keyboardType(.URL)
                        Button("Hent") {
                            let l = fontLink
                            Task { await app.downloadFont(l); fontLink = "" }
                        }
                        .disabled(fontLink.isEmpty)
                    }
                    if !fonts.isEmpty {
                        Button("Slet skrifter", role: .destructive) {
                            for f in fonts { ClockFonts.delete(f) }
                            fonts = ClockFonts.list()
                            app.s.lockFont = ""
                        }
                    }
                    ForEach(app.fontLog, id: \.self) { Text($0).font(.caption2).foregroundStyle(.secondary) }
                }
            } header: { Text("Urskrift") } footer: {
                Text("Vælg zip-filen med urskrifterne direkte. Eller læg den i Filer → På min iPhone → Bio, så henter Bio den selv. Skrifterne bliver kun på telefonen.")
            }

            Section("Ur") {
                VStack(alignment: .leading) {
                    Text("Tykkelse: \(Int(app.s.lockWeight))")
                    Slider(value: $app.s.lockWeight, in: 200...900, step: 10)
                }
                VStack(alignment: .leading) {
                    Text("Højde: \(String(format: "%.1f", app.s.lockHeight * 100)) % af skærmen")
                    Slider(value: $app.s.lockHeight, in: 0.12...0.45, step: 0.002)
                }
                Toggle("Glas-effekt", isOn: $app.s.lockGlass)
                Picker("Klokkeslæt", selection: $app.s.lockTimeSep) {
                    Text("10.47").tag(".")
                    Text("10:47").tag(":")
                }
                .pickerStyle(.segmented)
                Picker("Dato", selection: $app.s.lockDateShort) {
                    Text("tors. 26. nov.").tag(true)
                    Text("Torsdag 26. november").tag(false)
                }
                Button("Som min iPhone (målt)") {
                    app.s.lockWeight = 600
                    app.s.lockHeight = 0.284
                    app.s.lockGlass = true
                    app.s.lockDateShort = true
                    app.s.lockPadlock = false
                }
            }

            Section {
                PhotosPicker(selection: $pick, matching: .images) {
                    Label(app.wallpaper == nil ? "Vælg baggrund …" : "Skift baggrund …", systemImage: "photo")
                }
                if app.wallpaper != nil {
                    Button("Fjern baggrund", role: .destructive) { app.setWallpaper(nil) }
                    VStack(alignment: .leading) {
                        Text("Mørkere: \(Int(app.s.lockDim * 100)) %")
                        Slider(value: $app.s.lockDim, in: 0...0.6)
                    }
                }
                TextField("Fokus, fx Forstyr ikke", text: $app.s.lockFocus)
                TextField("Tekst i bunden, fx dit navn", text: $app.s.lockFooter)
                Toggle("Hængelås altid synlig", isOn: $app.s.lockPadlock)
            } header: { Text("Baggrund og bund") } footer: {
                Text("Vælg samme billede som din rigtige låseskærm.")
            }

            Section {
                Toggle("Vis hemmelige zoner", isOn: $app.s.lockShowZones)
                Stepper("Usynligt tastatur: \(Int(app.s.lockSecretSec)) sek.", value: $app.s.lockSecretSec, in: 4...20, step: 1)
                DisclosureGroup("Genveje") {
                    row("Kode-skærm", "Stryg op")
                    row("Usynligt tastatur", "Langt tryk på uret")
                    row("Tastatur", "1 2 3 / 4 5 6 / 7 8 9 / ✕ 0 ✓")
                    row("Sort skærm", "Dobbelttryk")
                    row("Panik", "Hold øverst til venstre")
                    row("Tilbage til Bio", "5 tryk øverst til højre")
                }
            } header: { Text("Øvelse") }
        }
        .navigationTitle("Låseskærm")
        .navigationBarTitleDisplayMode(.inline)
        .fileImporter(isPresented: $importing,
                      allowedContentTypes: [.zip, UTType(filenameExtension: "otf") ?? .font, .font, .data],
                      allowsMultipleSelection: true) { result in
            guard case .success(let urls) = result else { return }
            app.importFonts(urls)
        }
        .onChange(of: app.fontsVersion) { _, _ in fonts = ClockFonts.list() }
        .onChange(of: pick) { _, item in
            guard let item else { return }
            Task {
                let data = try? await item.loadTransferable(type: Data.self)
                app.setWallpaper(data)
                pick = nil
            }
        }
        .onChange(of: app.s.lockMode) { _, m in
            if (m == "kort" || m == "mnemonica") && app.s.allFields.contains("kort") { app.s.lockField = "kort" }
            if m == "tal" && app.s.allFields.contains("tal") { app.s.lockField = "tal" }
            if m == "dato" && app.s.allFields.contains("dato") { app.s.lockField = "dato" }
            if m != "tal" { app.s.lockCodeLength = 4 }
        }
    }

    @ViewBuilder
    private var fontStatus: some View {
        if let f = ClockFonts.resolve(app.s.lockFont) {
            Label(f.replacingOccurrences(of: "-VF.otf", with: ""), systemImage: "checkmark.circle.fill")
                .foregroundStyle(.green)
        } else {
            Label("Ingen urskrift endnu (bruger systemskrift)", systemImage: "exclamationmark.circle")
                .foregroundStyle(.orange)
        }
    }

    private var fieldChoices: [String] {
        var f = app.s.allFields
        if !f.contains(app.s.lockField) { f.append(app.s.lockField) }
        return f
    }

    private var example: String {
        let sample: String
        switch app.s.lockMode {
        case "kort": sample = "132"
        case "mnemonica": sample = "7"
        case "dato": sample = "2412"
        default: sample = "1234"
        }
        guard let out = LockInput.interpret(sample, mode: app.s.lockMode) else { return "" }
        return "\nEksempel: \(sample) → \(out)"
    }

    private func row(_ a: String, _ b: String) -> some View {
        HStack {
            Text(a)
            Spacer()
            Text(b).foregroundStyle(.secondary).multilineTextAlignment(.trailing)
        }
        .font(.footnote)
    }
}
