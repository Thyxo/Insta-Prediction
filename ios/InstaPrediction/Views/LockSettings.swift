// Indstillinger for låseskærm-input: felt, fortolkning, afsløring og udseende.
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
                    app.lockOpen = true
                } label: {
                    Label("Åbn låseskærm", systemImage: "lock.iphone").bold()
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
                Picker("Kode-længde", selection: $app.s.lockCodeLength) {
                    Text("4 cifre").tag(4)
                    Text("6 cifre").tag(6)
                }
                .pickerStyle(.segmented)
            } header: { Text("Input") } footer: {
                Text((LockInput.modes.first { $0.id == app.s.lockMode }?.help ?? "") + example)
            }

            Section {
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
                Toggle("Hængelåsen blinker", isOn: $app.s.lockBlink)
            } header: { Text("Afsløring") } footer: {
                Text("Hængelåsen åbner kort, når input er modtaget, og igen når bioen er skiftet. Ingen vibration fra Bio, mens låseskærmen vises.")
            }

            Section {
                PhotosPicker(selection: $pick, matching: .images) {
                    Label(app.wallpaper == nil ? "Vælg baggrund …" : "Skift baggrund …", systemImage: "photo")
                }
                if app.wallpaper != nil {
                    Button("Fjern baggrund", role: .destructive) { app.setWallpaper(nil) }
                }
                VStack(alignment: .leading) {
                    Text("Mørkere baggrund: \(Int(app.s.lockDim * 100)) %")
                    Slider(value: $app.s.lockDim, in: 0...0.6)
                }
                Picker("Dato", selection: $app.s.lockDateShort) {
                    Text("tors. 26. nov.").tag(true)
                    Text("Torsdag 26. november").tag(false)
                }
                Picker("Klokkeslæt", selection: $app.s.lockTimeSep) {
                    Text("10.47").tag(".")
                    Text("10:47").tag(":")
                }
                .pickerStyle(.segmented)
                TextField("Fokus i bunden, fx Forstyr ikke", text: $app.s.lockFocus)
                TextField("Lille tekst i bunden, fx dit navn", text: $app.s.lockFooter)
                Toggle("Hængelås altid synlig", isOn: $app.s.lockPadlock)
            } header: { Text("Udseende") } footer: {
                Text("Vælg samme billede som din rigtige låseskærm (fra Fotos). iOS 26 viser ingen hængelås; uden den åbner den kun kort ved input, som et Face ID-forsøg.")
            }

            Section {
                if fonts.isEmpty {
                    Text("Ingen urskrift endnu. Uret bruger en strakt systemskrift.")
                        .foregroundStyle(.secondary)
                } else {
                    Picker("Skrift", selection: $app.s.lockFont) {
                        Text("Auto (\(ClockFonts.preferred.replacingOccurrences(of: "-VF.otf", with: "")))").tag("")
                        ForEach(fonts, id: \.self) { f in Text(f.replacingOccurrences(of: "-VF.otf", with: "")).tag(f) }
                    }
                }
                Button {
                    Task { await app.findFonts(auto: false) }
                } label: {
                    HStack {
                        Label("Find skrifterne på telefonen", systemImage: "magnifyingglass")
                        if app.fontSearching { Spacer(); ProgressView() }
                    }
                }
                .disabled(app.fontSearching)
                Button {
                    importing = true
                } label: {
                    Label("Importér skriftfiler (.otf) …", systemImage: "square.and.arrow.down")
                }
                HStack {
                    TextField("…eller link til en .otf", text: $fontLink)
                        .textInputAutocapitalization(.never).autocorrectionDisabled()
                        .keyboardType(.URL)
                    Button("Hent") {
                        let l = fontLink
                        Task { await app.downloadFont(l); fontLink = "" }
                    }
                    .disabled(fontLink.isEmpty)
                }
                if !app.fontLog.isEmpty {
                    DisclosureGroup("Detaljer") {
                        ForEach(app.fontLog, id: \.self) { Text($0).font(.caption2).foregroundStyle(.secondary) }
                    }
                }
                if !fonts.isEmpty {
                    Button("Slet importerede skrifter", role: .destructive) {
                        for f in fonts { ClockFonts.delete(f) }
                        fonts = ClockFonts.list()
                        app.s.lockFont = ""
                    }
                }
                VStack(alignment: .leading) {
                    Text("Tykkelse: \(Int(app.s.lockWeight))")
                    Slider(value: $app.s.lockWeight, in: 200...900, step: 10)
                }
                VStack(alignment: .leading) {
                    Text("Højde: \(String(format: "%.1f", app.s.lockHeight * 100)) % af skærmen")
                    Slider(value: $app.s.lockHeight, in: 0.12...0.45, step: 0.002)
                }
                Toggle("Glas-effekt", isOn: $app.s.lockGlass)
                Button("Som min iPhone (målt)") {
                    app.s.lockWeight = 600
                    app.s.lockHeight = 0.284
                    app.s.lockGlass = true
                    app.s.lockDateShort = true
                    app.s.lockPadlock = false
                }
            } header: { Text("Urskrift") } footer: {
                Text("Låseskærmens egne urskrifter ligger i iOS. Bio leder selv efter dem ved første start og kopierer dem ind (kun på telefonen). Virker det ikke, så importér SFAdaptiveNumeric-VF.otf fra Filer eller indsæt et direkte link. Målt på din låseskærm: tykkelse 600, højde 28,4 %.")
            }

            Section {
                TextField("Operatør", text: $app.s.lockCarrier)
                Toggle("Lydløs-ikon", isOn: $app.s.lockSilent)
                Stepper("Signal: \(app.s.lockSignal) af 4 streger", value: $app.s.lockSignal, in: 0...4)
                Toggle("Procent i batteriet", isOn: $app.s.lockBatteryPct)
                Toggle("Streg under batteriet", isOn: $app.s.lockGrabber)
            } header: { Text("Statuslinje") } footer: {
                Text("Batteriniveauet er telefonens rigtige. Klokken vises ikke i statuslinjen på en låseskærm.")
            }

            Section {
                Toggle("Vis hemmelige zoner (øvelse)", isOn: $app.s.lockShowZones)
                Stepper("Usynligt tastatur: \(Int(app.s.lockSecretSec)) sek.", value: $app.s.lockSecretSec, in: 4...20, step: 1)
            } header: { Text("Øvelse") }

            Section("Genveje") {
                row("Kode-skærm", "Stryg op")
                row("Usynligt tastatur", "Langt tryk på uret")
                row("Tastatur", "1 2 3 / 4 5 6 / 7 8 9 / ✕ 0 ✓")
                row("Sort skærm", "Dobbelttryk · tryk vækker")
                row("Panik", "Hold øverst til venstre 1 sek.")
                row("Tilbage til Bio", "5 tryk øverst til højre")
            }
        }
        .fileImporter(isPresented: $importing,
                      allowedContentTypes: [UTType(filenameExtension: "otf") ?? .font, UTType(filenameExtension: "ttf") ?? .font, .font, .data],
                      allowsMultipleSelection: true) { result in
            guard case .success(let urls) = result else { return }
            let got = ClockFonts.importFiles(urls)
            fonts = ClockFonts.list()
            app.add(got.isEmpty ? .warn : .ok, got.isEmpty ? "Ingen skrift kunne læses" : "Importeret: \(got.joined(separator: ", "))")
        }
        .onChange(of: app.fontsVersion) { _, _ in fonts = ClockFonts.list() }
        .navigationTitle("Låseskærm")
        .navigationBarTitleDisplayMode(.inline)
        .onChange(of: pick) { _, item in
            guard let item else { return }
            Task {
                let data = try? await item.loadTransferable(type: Data.self)
                app.setWallpaper(data)
                pick = nil
            }
        }
        .onChange(of: app.s.lockMode) { _, m in
            // Kort-tilstande skriver naturligt i {kort}
            if (m == "kort" || m == "mnemonica") && app.s.allFields.contains("kort") { app.s.lockField = "kort" }
            if m == "tal" && app.s.allFields.contains("tal") { app.s.lockField = "tal" }
            if m == "dato" && app.s.allFields.contains("dato") { app.s.lockField = "dato" }
            // Kort og datoer passer bedst i en 4-cifret kode
            if m != "tal" { app.s.lockCodeLength = 4 }
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
