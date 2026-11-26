// Bio-skabeloner: tekst med felter i krøllede parenteser, fx "🃏 Dit kort: {kort|kort} · {by|titel}".
// Ren Swift (kun Foundation), testes i Tests/main.swift.
import Foundation

struct BioTemplate: Codable, Equatable, Identifiable {
    var id = UUID()
    var name: String
    var text: String

    static let defaults: [BioTemplate] = [
        BioTemplate(name: "Ord", text: "✨ Ordet du tænker på: {ord|titel}"),
        BioTemplate(name: "Kort", text: "🃏 Dit kort er {kort|kort}"),
        BioTemplate(name: "Kort + tal", text: "🃏 {kort|kort} · 🔢 {tal}"),
        BioTemplate(name: "Dato", text: "📅 Din dag er {dato}"),
        BioTemplate(name: "Navn", text: "Hej {navn|titel} 👋 Jeg vidste, du ville kigge her"),
    ]
}

struct Placeholder: Equatable {
    let key: String
    let filters: [String]
    let range: Range<String.Index>
}

struct Rendered: Equatable {
    let text: String
    let missing: [String]
    /// Instagram tæller som JavaScript (UTF-16). Det er det strengeste mål.
    var length: Int { text.utf16.count }
    var tooLong: Bool { length > TemplateEngine.bioLimit }
}

enum TemplateEngine {
    static let bioLimit = 150
    /// Filtre der kan sættes efter feltet: {navn|stor}
    static let filterHelp: [(String, String)] = [
        ("stor", "STORE BOGSTAVER"),
        ("lille", "små bogstaver"),
        ("titel", "Stort forbogstav"),
        ("kort", "kh → hjerter konge"),
        ("kortikon", "kh → K♥️"),
        ("tal", "kun cifre"),
    ]

    static func placeholders(in text: String) -> [Placeholder] {
        var out: [Placeholder] = []
        var i = text.startIndex
        while i < text.endIndex, let open = text[i...].firstIndex(of: "{") {
            let after = text.index(after: open)
            guard let close = text[after...].firstIndex(of: "}") else { break }
            let inner = text[after..<close]
            if inner.contains("{") { i = after; continue }
            let parts = inner.split(separator: "|", omittingEmptySubsequences: false)
                .map { $0.trimmingCharacters(in: .whitespaces).lowercased() }
            let key = parts[0]
            if !key.isEmpty, key.allSatisfy({ $0.isLetter || $0.isNumber || $0 == "_" }) {
                out.append(Placeholder(key: key, filters: parts.dropFirst().filter { !$0.isEmpty },
                                       range: open..<text.index(after: close)))
            }
            i = text.index(after: close)
        }
        return out
    }

    /// Feltnavne i rækkefølge, uden dubletter
    static func fields(in text: String) -> [String] {
        var seen: [String] = []
        for p in placeholders(in: text) where !seen.contains(p.key) { seen.append(p.key) }
        return seen
    }

    static func render(_ text: String, values: [String: String]) -> Rendered {
        var out = ""
        var missing: [String] = []
        var cursor = text.startIndex
        for p in placeholders(in: text) {
            out += text[cursor..<p.range.lowerBound]
            let raw = values[p.key]?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            if raw.isEmpty {
                if !missing.contains(p.key) { missing.append(p.key) }
                out += text[p.range]
            } else {
                out += p.filters.reduce(raw) { apply($1, to: $0) }
            }
            cursor = p.range.upperBound
        }
        out += text[cursor...]
        return Rendered(text: out, missing: missing)
    }

    static func apply(_ filter: String, to v: String) -> String {
        let da = Locale(identifier: "da_DK")
        switch filter {
        case "stor": return v.uppercased(with: da)
        case "lille": return v.lowercased(with: da)
        case "titel":
            guard let f = v.first else { return v }
            return String(f).uppercased(with: da) + v.dropFirst()
        case "kort": return Card.parse(v)?.name ?? v
        case "kortikon": return Card.parse(v)?.short ?? v
        case "tal":
            let d = v.filter(\.isNumber)
            return d.isEmpty ? v : d
        default: return v
        }
    }
}
