// Indstillinger for låseskærm-input: felt, fortolkning, afsløring og udseende.
import PhotosUI
import SwiftUI

struct LockSettings: View {
    @Environment(AppState.self) private var app
    @State private var pick: PhotosPickerItem?

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
                Toggle("Højt ur (iOS 26)", isOn: $app.s.lockClockTall)
                Picker("Klokkeslæt", selection: $app.s.lockTimeSep) {
                    Text("10.47").tag(".")
                    Text("10:47").tag(":")
                }
                .pickerStyle(.segmented)
                Picker("Statuslinje", selection: $app.s.lockStatus) {
                    Text("Operatør + batteri").tag("lock")
                    Text("Ingen").tag("none")
                }
                if app.s.lockStatus == "lock" {
                    TextField("Operatør", text: $app.s.lockCarrier)
                }
            } header: { Text("Udseende") } footer: {
                Text("Vælg samme billede som din rigtige låseskærm (fra Fotos).")
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
