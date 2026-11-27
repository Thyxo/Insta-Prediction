// Noterne i den falske Noter-app: sektioner og datoer som i iOS 26 Noter (ren Foundation, testet).
import Foundation

struct FakeNote: Codable, Identifiable, Equatable {
    var id = UUID()
    var text: String
    var date: Date
    var pinned = false

    private var lines: [String] {
        text.components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
    }
    var isEmpty: Bool { lines.isEmpty }
    var title: String { lines.first ?? "Ny note" }
    var preview: String { lines.dropFirst().first ?? "Ingen yderligere tekst" }
}

struct NoteSection: Identifiable {
    let title: String
    var notes: [FakeNote]
    var id: String { title }
}

enum FakeNotes {
    static let weekdays = ["søndag", "mandag", "tirsdag", "onsdag", "torsdag", "fredag", "lørdag"]
    static let months = ["Januar", "Februar", "Marts", "April", "Maj", "Juni", "Juli",
                         "August", "September", "Oktober", "November", "December"]

    static var calendar: Calendar = {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = .current
        c.firstWeekday = 2
        return c
    }()

    /// Dage mellem to datoer (kalenderdage)
    static func daysAgo(_ d: Date, now: Date) -> Int {
        let c = calendar
        return c.dateComponents([.day], from: c.startOfDay(for: d), to: c.startOfDay(for: now)).day ?? 0
    }

    /// "08.45" i dag, "i går", "søndag" inden for en uge, ellers "30.10.2026"
    static func dateLabel(_ d: Date, now: Date) -> String {
        let c = calendar
        let days = daysAgo(d, now: now)
        if days <= 0 {
            let h = c.component(.hour, from: d), m = c.component(.minute, from: d)
            return String(format: "%02d.%02d", h, m)
        }
        if days == 1 { return "i går" }
        if days < 7 { return weekdays[c.component(.weekday, from: d) - 1] }
        let x = c.dateComponents([.day, .month, .year], from: d)
        return String(format: "%02d.%02d.%04d", x.day ?? 1, x.month ?? 1, x.year ?? 2000)
    }

    /// Sektionens navn for en (ikke-fastgjort) note
    static func sectionTitle(_ d: Date, now: Date) -> String {
        let days = daysAgo(d, now: now)
        if days <= 0 { return "I dag" }
        if days == 1 { return "I går" }
        if days <= 7 { return "Sidste 7 dage" }
        if days <= 30 { return "Sidste 30 dage" }
        let c = calendar
        if c.component(.year, from: d) == c.component(.year, from: now) {
            return months[c.component(.month, from: d) - 1]
        }
        return String(c.component(.year, from: d))
    }

    /// Fastgjort først, derefter efter dato (nyeste først)
    static func sections(_ notes: [FakeNote], now: Date) -> [NoteSection] {
        var out: [NoteSection] = []
        let pinned = notes.filter(\.pinned).sorted { $0.date > $1.date }
        if !pinned.isEmpty { out.append(NoteSection(title: "Fastgjort", notes: pinned)) }
        for n in notes.filter({ !$0.pinned }).sorted(by: { $0.date > $1.date }) {
            let t = sectionTitle(n.date, now: now)
            if let i = out.firstIndex(where: { $0.title == t }) { out[i].notes.append(n) } else { out.append(NoteSection(title: t, notes: [n])) }
        }
        return out
    }

    /// Søg i titel og tekst
    static func filter(_ notes: [FakeNote], _ q: String) -> [FakeNote] {
        let q = q.trimmingCharacters(in: .whitespaces)
        guard !q.isEmpty else { return notes }
        return notes.filter { $0.text.range(of: q, options: [.caseInsensitive, .diacriticInsensitive]) != nil }
    }

    /// Almindelige noter, så listen ligner en brugt telefon. Kan rettes i Noter som normalt.
    static func seed(now: Date) -> [FakeNote] {
        func ago(_ days: Int, _ h: Int, _ m: Int) -> Date {
            let c = calendar
            let d = c.date(byAdding: .day, value: -days, to: now) ?? now
            return c.date(bySettingHour: h, minute: m, second: 0, of: d) ?? d
        }
        return [
            FakeNote(text: "Indkøb\nRugbrød\nMælk\nÆg\nBananer\nKaffe", date: ago(2, 17, 12), pinned: true),
            FakeNote(text: "Ideer\nWeekendtur til Aarhus\nGave til mor\nNy cykellås", date: ago(5, 21, 40), pinned: true),
            FakeNote(text: "Huskeliste\nRing til tandlægen\nBetal licens\nAflever pakke i Netto", date: ago(24, 9, 3), pinned: true),
            FakeNote(text: "Træning\nMandag: ben\nOnsdag: ryg og biceps\nFredag: bryst og skuldre", date: ago(1, 7, 15)),
            FakeNote(text: "Film at se\nDune\nOppenheimer\nDrive\nDen skaldede frisør", date: ago(3, 22, 8)),
            FakeNote(text: "Pakkeliste\nOplader\nPas\nHøretelefoner\nSolcreme", date: ago(6, 19, 30)),
            FakeNote(text: "Pandekager\n3 æg\n3 dl hvedemel\n5 dl mælk\n1 spsk sukker\nKnivspids salt", date: ago(12, 10, 2)),
            FakeNote(text: "Bøger\nKlara og solen\nAtomic Habits\nHærværk", date: ago(19, 23, 11)),
            FakeNote(text: "Gaveideer jul\nMor: tørklæde\nFar: vinyl\nLillebror: Lego", date: ago(41, 20, 45)),
            FakeNote(text: "Lejlighed\nSkriv til viceværten om radiatoren\nMål vinduet i stuen", date: ago(67, 16, 20)),
        ]
    }
}
