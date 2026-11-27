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
        "dato": "",
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

    // Låseskærm (input)
    var lockField = "tal"            // feltet cifrene skrives i
    var lockMode = "tal"             // tal | kort | mnemonica | dato (LockInput.modes)
    var lockCodeLength = 6           // 4 eller 6 cifre på kode-skærmen
    var lockAutoReveal = true        // afslør, så snart input er modtaget
    var lockDelay = 2.0              // sek. før afsløring (så tilskueren ikke ser noget ske)
    var lockTimeSep = "."            // 10.47 (dansk) eller 10:47
    var lockDim = 0.1                // gør baggrunden mørkere (0…0.6)
    var lockBlink = true             // hængelåsen blinker ved input/afsløring
    var lockShowZones = false        // øvelse: vis hemmelige zoner
    var lockSecretSec = 8.0          // usynligt tastatur er aktivt så længe efter sidste tryk
    // Låseskærm: målt på en rigtig iOS 26-låseskærm (se Views/ClockView.swift)
    var lockFont = ""                // importeret skriftfil ("" = SFAdaptiveNumeric hvis importeret)
    var lockWeight = 600.0           // wght
    var lockHeight = 0.284           // cifrenes højde / skærmhøjde (iOS lader dig trække uret højere)
    var lockGlass = true             // glas-gradient på uret
    var lockDateShort = true         // "tors. 26. nov." (iOS 26) eller "Torsdag 26. november"
    var lockPadlock = false          // hængelås altid synlig (ellers kun kort ved input, som Face ID)
    var lockFocus = ""               // fx "Forstyr ikke" (tom = skjult)
    var lockFooter = ""              // lille tekst i bunden, fx dit navn

    // Noter (input): tilskueren skriver i en falsk Noter-app
    var noteField = "ord"            // feltet teksten skrives i
    var noteMode = "sidste"          // NoteInput.modes
    var noteAutoReveal = true        // afslør, når der trykkes Færdig
    var noteDelay = 2.0              // sek. før afsløring
    var noteClear = false            // tøm noten efter Færdig (så den "forsvinder")
    var noteStart = ""               // tekst noten starter med, fx "Indkøb"
    var noteIdleSec = 3.0            // send, når tilskueren har stoppet med at skrive så længe (0 = fra)
    var noteOnLock = true            // send med det samme, når telefonen låses (sideknap) midt i noten
    var noteOpen = "ny"              // ny = åbner i en tom note, liste = åbner i notelisten

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
