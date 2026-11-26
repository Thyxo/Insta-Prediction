// Appens tilstand: felter (manuelt + relæ), skabelon, Instagram-status, afsløring og nulstilling.
import SwiftUI
import UIKit

struct FieldValue: Equatable {
    var text: String
    var at: Double          // ms siden 1970
    var source: String      // "manuelt" eller relæ-sti
}

struct LogLine: Identifiable {
    enum Kind { case info, ok, warn, error }
    let id = UUID()
    let time = Date()
    let kind: Kind
    let text: String
}

@MainActor @Observable
final class AppState {
    var s = Settings.load() {
        didSet {
            guard s != oldValue else { return }
            s.save()
            gate.minGap = s.minGap
            if s.room != oldValue.room || s.useRelay != oldValue.useRelay { connectRelay() }
            if s.keepAlive != oldValue.keepAlive || s.room != oldValue.room || s.useRelay != oldValue.useRelay { updateKeepAlive() }
            if s.notify && !oldValue.notify { Notifier.ask() }
        }
    }

    var values: [String: FieldValue] = [:]
    var relayStatus = "off"
    var loggedIn = false
    var username = ""
    var currentBio = ""
    var busy = false
    var lastError = ""
    var log: [LogLine] = []
    var loginOpen = false
    var settingsOpen = false
    var lockOpen = false
    var notesOpen = false
    /// Tælles op ved input fra låseskærmen og ved gennemført afsløring (hængelåsen blinker)
    var lockPulse = 0
    var wallpaper: UIImage? = Wallpaper.load()
    var fontsVersion = 0              // tælles op når urskrifter er fundet/importeret
    var fontLog: [String] = []
    var fontSearching = false

    @ObservationIgnored let ig = Instagram()
    @ObservationIgnored private var relay: RelayClient?
    @ObservationIgnored private let keeper = BackgroundKeeper()
    @ObservationIgnored private var gate = RateGate(minGap: 15)
    @ObservationIgnored private var resetTask: Task<Void, Never>?
    @ObservationIgnored private var lockRevealTask: Task<Void, Never>?
    @ObservationIgnored private var started = false
    /// Relæ-værdier ældre end dette tidspunkt ignoreres (sættes ved nulstilling), så gårsdagens søgning ikke tæller.
    @ObservationIgnored private var armedAt: Double = {
        let v = UserDefaults.standard.double(forKey: "insta.armedAt")
        return v > 0 ? v : Date().timeIntervalSince1970 * 1000
    }()
    @ObservationIgnored private var lastCmdAt: Double = {
        let v = UserDefaults.standard.double(forKey: "insta.lastCmdAt")
        return v > 0 ? v : Date().timeIntervalSince1970 * 1000
    }()

    static var nowMs: Double { Date().timeIntervalSince1970 * 1000 }

    var template: BioTemplate {
        s.templates.first { $0.id.uuidString == s.activeTemplate } ?? s.templates.first ?? BioTemplate(name: "Tom", text: "")
    }
    var fields: [String] { TemplateEngine.fields(in: template.text) }
    var rendered: Rendered { TemplateEngine.render(template.text, values: values.mapValues(\.text)) }

    // MARK: Start og livscyklus

    func start() async {
        guard !started else { return }
        started = true
        gate.minGap = s.minGap
        if s.templates.isEmpty { s.templates = BioTemplate.defaults }
        if !s.templates.contains(where: { $0.id.uuidString == s.activeTemplate }) { s.activeTemplate = s.templates[0].id.uuidString }
        if s.notify { Notifier.ask() }
        connectRelay()
        updateKeepAlive()
        scanFontFolder()
        if ClockFonts.list().isEmpty { Task { await findFonts(auto: true) } }
        await checkLogin()
    }

    func phase(_ p: ScenePhase) {
        switch p {
        case .active:
            scanFontFolder()
            if relay == nil || relayStatus != "online" { connectRelay() }
            Task { await checkLogin() }
        case .background:
            if !keeper.running { relay?.stop(); relayStatus = "off" }
        default: break
        }
    }

    func checkLogin() async {
        loggedIn = await ig.isLoggedIn()
        if loggedIn { await refreshProfile(quiet: true) }
    }

    func didLogin() async {
        loggedIn = true
        add(.ok, "Logget ind på Instagram")
        await refreshProfile(quiet: false)
    }

    func logout() async {
        await ig.logout()
        loggedIn = false
        username = ""
        currentBio = ""
        add(.info, "Logget ud")
    }

    func refreshProfile(quiet: Bool = false) async {
        do {
            let p = try await ig.profile()
            username = p.username
            currentBio = p.biography
            if s.defaultBio.isEmpty && !p.biography.isEmpty {
                s.defaultBio = p.biography
                add(.info, "Din nuværende bio er gemt som standard-bio")
            }
            if !quiet { add(.ok, "Læste profil @\(p.username)") }
        } catch {
            if case IGError.notLoggedIn = error { loggedIn = false }
            lastError = error.localizedDescription
            if !quiet { add(.error, "Kunne ikke læse profil: \(error.localizedDescription)") }
        }
    }

    // MARK: Felter

    func setManual(_ key: String, _ text: String) {
        if text.isEmpty { values[key] = nil; return }
        values[key] = FieldValue(text: text, at: Self.nowMs, source: "manuelt")
    }

    func clearValues() {
        values = [:]
        arm()
    }

    private func arm() {
        armedAt = Self.nowMs
        UserDefaults.standard.set(armedAt, forKey: "insta.armedAt")
    }

    // MARK: Låseskærm

    /// Cifre fra kode-skærmen eller det usynlige tastatur
    func lockCaptured(_ digits: String, via: String) {
        guard let text = LockInput.interpret(digits, mode: s.lockMode) else {
            add(.warn, "Låseskærm: \"\(digits)\" passer ikke som \(s.lockMode)")
            return
        }
        values[s.lockField] = FieldValue(text: text, at: Self.nowMs, source: "låseskærm")
        add(.info, "\(s.lockField) ← \(text) (\(via): \(digits))")
        lockPulse += 1
        guard s.lockAutoReveal else { return }
        lockRevealTask?.cancel()
        let delay = s.lockDelay
        lockRevealTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
            guard let self, !Task.isCancelled else { return }
            if self.rendered.missing.isEmpty {
                await self.reveal()
            } else {
                self.add(.warn, "Venter på: \(self.rendered.missing.joined(separator: ", "))")
            }
        }
    }

    /// Noter: tilskueren har trykket Færdig. Gentaget tekst ignoreres.
    func noteCaptured(_ note: String) {
        guard let text = NoteInput.extract(note, mode: s.noteMode) else {
            if !note.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                add(.warn, "Noter: intet brugbart som \(s.noteMode)")
            }
            return
        }
        if values[s.noteField]?.text == text, values[s.noteField]?.source == "noter" { return }
        values[s.noteField] = FieldValue(text: text, at: Self.nowMs, source: "noter")
        add(.info, "\(s.noteField) ← \(text) (noter)")
        guard s.noteAutoReveal else { return }
        lockRevealTask?.cancel()
        let delay = s.noteDelay
        lockRevealTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
            guard let self, !Task.isCancelled else { return }
            if self.rendered.missing.isEmpty {
                await self.reveal()
            } else {
                self.add(.warn, "Venter på: \(self.rendered.missing.joined(separator: ", "))")
            }
        }
    }

    /// Panik på låseskærmen: drop ventende afsløring og låseskærmens værdi
    func lockPanic() {
        lockRevealTask?.cancel()
        if values[s.lockField]?.source == "låseskærm" { values[s.lockField] = nil }
        add(.info, "Panik: ventende afsløring annulleret")
    }

    /// Find låseskærmens urskrifter i iOS på telefonen og kopiér dem ind i appen
    func findFonts(auto: Bool) async {
        guard !fontSearching else { return }
        fontSearching = true
        defer { fontSearching = false }
        let r = await Task.detached(priority: .userInitiated) { ClockFonts.findOnDevice() }.value
        ClockFonts.didAdd()
        fontLog = r.log
        fontsVersion += 1
        if r.found.isEmpty {
            if !auto { add(.warn, "Fandt ingen urskrifter på telefonen (se Urskrift → Detaljer)") }
        } else {
            add(.ok, "Urskrifter fundet på telefonen: \(r.found.count)")
        }
    }

    /// Skrifter lagt i Bio-mappen i Filer
    func scanFontFolder() {
        let got = ClockFonts.scanDocuments()
        if !got.isEmpty {
            fontsVersion += 1
            add(.ok, "Skrifter hentet fra Filer: \(got.count)")
        }
    }

    func importFonts(_ urls: [URL]) {
        let got = ClockFonts.importFiles(urls)
        fontsVersion += 1
        add(got.isEmpty ? .warn : .ok, got.isEmpty ? "Ingen skrift i filen" : "Importeret: \(got.count) skrift(er)")
    }

    func downloadFont(_ link: String) async {
        do {
            let name = try await ClockFonts.download(link)
            fontsVersion += 1
            add(.ok, "Hentet skrift: \(name)")
        } catch {
            add(.error, "Kunne ikke hente skrift: \(error.localizedDescription)")
        }
    }

    func setWallpaper(_ data: Data?) {
        Wallpaper.save(data)
        wallpaper = Wallpaper.load()
    }

    // MARK: Relæ

    func connectRelay() {
        relay?.stop()
        relay = nil
        guard s.useRelay, RelayClient.clean(s.room).count >= 3 else { relayStatus = "off"; return }
        let r = RelayClient(room: s.room,
                            onState: { [weak self] st in self?.handle(st) },
                            onStatus: { [weak self] st in self?.relayStatus = st })
        relay = r
        r.start()
    }

    private func handle(_ st: [String: Any]) {
        if s.listenCommands, let c = st["insta"] as? [String: Any], let cmd = c["cmd"] as? String,
           let at = RelayPath.number(c["at"]), at > lastCmdAt {
            lastCmdAt = at
            UserDefaults.standard.set(at, forKey: "insta.lastCmdAt")
            add(.info, "Kommando fra relæ: \(cmd)")
            switch cmd {
            case "reveal": Task { await reveal() }
            case "reset": Task { await resetBio() }
            default: break
            }
        }

        var changed = false
        for key in s.allFields {
            guard let path = s.sources[key], !path.isEmpty, let hit = RelayPath.lookup(st, path) else { continue }
            let at = hit.at ?? Self.nowMs
            guard at > armedAt else { continue }
            if let old = values[key], old.text == hit.value, old.source == path { continue }
            if let old = values[key], old.source == "manuelt", old.at > at { continue }
            values[key] = FieldValue(text: hit.value, at: at, source: path)
            changed = true
            add(.info, "\(key) ← \(hit.value)")
            if s.notify { Notifier.post(key, hit.value) }
        }
        if changed, s.autoReveal, fields.allSatisfy({ values[$0] != nil }), rendered.missing.isEmpty {
            Task { await reveal() }
        }
    }

    private func publishStatus(_ text: String, ok: Bool) {
        guard let relay else { return }
        let patch: [String: Any] = ["instaStatus": ["bio": text, "ok": ok, "practice": s.practice, "at": Self.nowMs]]
        Task { await relay.publish(patch) }
    }

    // MARK: Baggrund

    func updateKeepAlive() {
        if s.keepAlive && s.useRelay && RelayClient.clean(s.room).count >= 3 { keeper.start() } else { keeper.stop() }
    }

    // MARK: Afsløring

    func reveal() async {
        let r = rendered
        guard !fields.isEmpty || !r.text.isEmpty else { add(.warn, "Skabelonen er tom"); return }
        guard r.missing.isEmpty else { add(.warn, "Mangler: \(r.missing.joined(separator: ", "))"); haptic(.warning); return }
        resetTask?.cancel()
        let ok = await write(r.text, label: "Afsløring")
        if ok && s.autoResetMin > 0 {
            let min = s.autoResetMin
            resetTask = Task { [weak self] in
                try? await Task.sleep(nanoseconds: UInt64(min) * 60 * 1_000_000_000)
                guard !Task.isCancelled else { return }
                await self?.resetBio()
            }
        }
    }

    func resetBio() async {
        resetTask?.cancel()
        guard !s.defaultBio.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            add(.warn, "Ingen standard-bio. Gem din normale bio i indstillinger først.")
            haptic(.warning)
            return
        }
        if await write(s.defaultBio, label: "Nulstilling") { clearValues() }
    }

    @discardableResult
    private func write(_ text: String, label: String) async -> Bool {
        guard !busy else { add(.warn, "Vent, en ændring er i gang"); return false }
        guard text.utf16.count <= TemplateEngine.bioLimit else {
            add(.error, "\(label): \(text.utf16.count) tegn, Instagram tillader \(TemplateEngine.bioLimit)")
            haptic(.error)
            return false
        }
        busy = true
        defer { busy = false }

        let wait = gate.wait(now: Date().timeIntervalSince1970)
        if wait > 0 {
            add(.info, "Venter \(Int(wait.rounded(.up))) sek. (mindste afstand)")
            try? await Task.sleep(nanoseconds: UInt64(wait * 1_000_000_000))
        }
        gate.mark(now: Date().timeIntervalSince1970)

        if s.practice {
            lockPulse += 1
            add(.ok, "ØVE · \(label): \(text)")
            haptic(.success)
            if s.notify { Notifier.post("Øve: \(label)", text) }
            publishStatus(text, ok: true)
            return true
        }

        do {
            let method = try await ig.setBio(text, method: s.method)
            var confirmed = false
            if let p = try? await ig.profile() {
                username = p.username
                currentBio = p.biography
                confirmed = p.biography.trimmingCharacters(in: .whitespacesAndNewlines) == text.trimmingCharacters(in: .whitespacesAndNewlines)
            }
            lockPulse += 1
            add(confirmed ? .ok : .warn, "\(label) (\(method)): " + (confirmed ? "bekræftet" : "sendt, men ikke bekræftet"))
            lastError = ""
            haptic(.success)
            if s.notify { Notifier.post("✓ \(label)", text) }
            publishStatus(text, ok: true)
            return true
        } catch {
            if case IGError.notLoggedIn = error { loggedIn = false }
            lastError = error.localizedDescription
            add(.error, "\(label) fejlede: \(error.localizedDescription)")
            haptic(.error)
            if s.notify { Notifier.post("Fejl: \(label)", error.localizedDescription) }
            publishStatus(text, ok: false)
            return false
        }
    }

    func openProfile() {
        let name = username
        guard !name.isEmpty else { return }
        if let app = URL(string: "instagram://user?username=\(name)"), UIApplication.shared.canOpenURL(app) {
            UIApplication.shared.open(app)
        } else if let web = URL(string: "https://www.instagram.com/\(name)/") {
            UIApplication.shared.open(web)
        }
    }

    // MARK: Hjælpere

    func add(_ kind: LogLine.Kind, _ text: String) {
        log.insert(LogLine(kind: kind, text: text), at: 0)
        if log.count > 60 { log.removeLast(log.count - 60) }
    }

    private func haptic(_ t: UINotificationFeedbackGenerator.FeedbackType) {
        guard !lockOpen, !notesOpen else { return }   // tilskueren kan holde telefonen
        UINotificationFeedbackGenerator().notificationOccurred(t)
    }
}

/// Låseskærmens baggrund (samme billede som din rigtige låseskærm), gemt i Application Support
enum Wallpaper {
    static var url: URL {
        let dir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent("wallpaper.jpg")
    }

    static func load() -> UIImage? {
        guard let d = try? Data(contentsOf: url) else { return nil }
        return UIImage(data: d)
    }

    static func save(_ data: Data?) {
        guard let data, let img = UIImage(data: data) else { try? FileManager.default.removeItem(at: url); return }
        // Gem i skærmstørrelse, så det er hurtigt at vise
        let maxSide: CGFloat = 2800
        let scale = min(1, maxSide / max(img.size.width, img.size.height))
        let size = CGSize(width: img.size.width * scale, height: img.size.height * scale)
        let out = UIGraphicsImageRenderer(size: size).image { _ in img.draw(in: CGRect(origin: .zero, size: size)) }
        try? out.jpegData(compressionQuality: 0.9)?.write(to: url, options: .atomic)
    }
}
