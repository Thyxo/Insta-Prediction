// Skabeloner: liste og editor med tegntæller og eksempel.
import SwiftUI

struct TemplatesView: View {
    @Environment(AppState.self) private var app

    var body: some View {
        @Bindable var app = app
        List {
            Section {
                ForEach($app.s.templates) { $t in
                    NavigationLink { TemplateEditor(t: $t) } label: {
                        VStack(alignment: .leading, spacing: 2) {
                            HStack {
                                Text(t.name)
                                if t.id.uuidString == app.s.activeTemplate {
                                    Image(systemName: "checkmark").foregroundStyle(Color.accentColor)
                                }
                            }
                            Text(t.text).font(.caption).foregroundStyle(.secondary).lineLimit(2)
                        }
                    }
                    .swipeActions(edge: .leading) {
                        Button("Brug") { app.s.activeTemplate = t.id.uuidString }.tint(.accentColor)
                    }
                }
                .onDelete { idx in
                    guard app.s.templates.count > idx.count else { return }
                    app.s.templates.remove(atOffsets: idx)
                }
                .onMove { app.s.templates.move(fromOffsets: $0, toOffset: $1) }
            } footer: {
                Text("Stryg til højre for at bruge en skabelon. Felter skrives {navn}. Filtre: {navn|titel}.")
            }

            Section("Filtre") {
                ForEach(TemplateEngine.filterHelp, id: \.0) { f in
                    HStack {
                        Text("|\(f.0)").font(.body.monospaced())
                        Spacer()
                        Text(f.1).foregroundStyle(.secondary)
                    }
                }
            }
        }
        .navigationTitle("Skabeloner")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    let t = BioTemplate(name: "Ny skabelon", text: "{ord}")
                    app.s.templates.append(t)
                } label: { Image(systemName: "plus") }
            }
            ToolbarItem(placement: .topBarTrailing) { EditButton() }
        }
    }
}

struct TemplateEditor: View {
    @Environment(AppState.self) private var app
    @Binding var t: BioTemplate

    private static let samples = ["ord": "bornholm", "kort": "kh", "tal": "42", "navn": "mette", "by": "valby"]

    var body: some View {
        let fields = TemplateEngine.fields(in: t.text)
        let sample = TemplateEngine.render(t.text, values: Dictionary(uniqueKeysWithValues: fields.map { ($0, Self.samples[$0] ?? $0) }))
        Form {
            Section("Navn") { TextField("Navn", text: $t.name) }
            Section {
                TextEditor(text: $t.text)
                    .frame(minHeight: 110)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)
            } header: { Text("Bio-tekst") } footer: {
                Text("\(sample.length)/\(TemplateEngine.bioLimit) tegn med eksempelværdier")
                    .foregroundStyle(sample.tooLong ? .red : .secondary)
            }
            Section("Felter") {
                if fields.isEmpty { Text("Ingen felter. Skriv fx {ord} eller {kort|kort}.").foregroundStyle(.secondary) }
                ForEach(fields, id: \.self) { f in
                    HStack {
                        Text("{\(f)}").font(.body.monospaced())
                        Spacer()
                        Text(app.s.sources[f].flatMap { $0.isEmpty ? nil : $0 } ?? "kun manuelt").foregroundStyle(.secondary)
                    }
                }
            }
            Section("Eksempel") { Text(sample.text) }
            Section {
                Button("Brug denne skabelon") { app.s.activeTemplate = t.id.uuidString }
                    .disabled(app.s.activeTemplate == t.id.uuidString)
            }
        }
        .navigationTitle(t.name)
        .navigationBarTitleDisplayMode(.inline)
    }
}
