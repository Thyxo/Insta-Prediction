// Indstillinger. Gemmes i UserDefaults; manglende nøgler får standardværdien (som i Mosaik).
import Foundation

struct Settings: Codable, Equatable {
    var templates = BioTemplate.defaults
    var activeTemplate = ""          // BioTemplate.id.uuidString
    /// felt → relæ-sti (tom = kun manuelt)
    var sources: [String: String] = [
        "ord": "google.q",
        "navn": "force.name",
        "tal": "result.value",
        "kort": "card.name",
    ]
    var useRelay = true
    var room = ""                    // samme rum-kode som i Fake Google / Noter+ / Calc+
    var listenCommands = true        // feltet "insta" { cmd: "reveal" | "reset" } fra andre apps
    var autoReveal = false           // afslør selv, når alle felter er udfyldt
    var minGap = 15.0                // sek. mellem to bio-ændringer
    var autoResetMin = 0             // nulstil bio efter N min (0 = fra)
    var defaultBio = ""              // din normale bio
    var practice = true              // øve-tilstand: skriver ikke til Instagram
    var method = "auto"              // auto | bio | web
    var keepAlive = true             // hold appen kørende i baggrunden (lydløs lyd)
    var notify = true                // notifikation ved input og afsløring (ses også på uret)

    init() {}

    static let key = "insta.settings.v1"

    static func load() -> Settings {
        let def = Settings()
        guard let data = UserDefaults.standard.data(forKey: key),
              let stored = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let defData = try? JSONEncoder().encode(def),
              var dict = try? JSONSerialization.jsonObject(with: defData) as? [String: Any] else { return def }
        dict.merge(stored) { _, new in new }
        guard let merged = try? JSONSerialization.data(withJSONObject: dict),
              let s = try? JSONDecoder().decode(Settings.self, from: merged) else { return def }
        return s
    }

    func save() {
        if let data = try? JSONEncoder().encode(self) { UserDefaults.standard.set(data, forKey: Self.key) }
    }

    /// Alle feltnavne i alle skabeloner
    var allFields: [String] {
        var out: [String] = []
        for t in templates { for f in TemplateEngine.fields(in: t.text) where !out.contains(f) { out.append(f) } }
        return out
    }
}
