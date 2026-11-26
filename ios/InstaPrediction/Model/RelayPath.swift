// Læs en værdi i relæ-rummets tilstand med en sti som "google.q" eller "force.name".
// Tidsstemplet "at" (ms siden 1970) hentes fra samme objekt som værdien.
import Foundation

enum RelayPath {
    /// Kendte felter fra de andre apps (vises som forslag i indstillinger)
    static let known: [(path: String, label: String)] = [
        ("google.q", "Fake Google: søgning"),
        ("force.name", "Noter+: navn"),
        ("force.digits", "Noter+: tal"),
        ("result.value", "Calc+: resultat"),
        ("card.name", "Kort (fx Card Detector)"),
        ("word.text", "Ord (egen app)"),
    ]

    static func lookup(_ state: [String: Any], _ path: String) -> (value: String, at: Double?)? {
        let parts = path.split(separator: ".").map(String.init)
        guard !parts.isEmpty else { return nil }
        var node: Any = state
        var parent: [String: Any] = state
        for p in parts {
            guard let d = node as? [String: Any], let next = d[p] else { return nil }
            parent = d
            node = next
        }
        guard let value = text(node), !value.isEmpty else { return nil }
        return (value, number(parent["at"]))
    }

    static func text(_ v: Any) -> String? {
        if let s = v as? String { return s.trimmingCharacters(in: .whitespacesAndNewlines) }
        if let n = v as? Int { return String(n) }
        if let d = v as? Double { return d == d.rounded() && abs(d) < 1e15 ? String(Int(d)) : String(d) }
        return nil
    }

    static func number(_ v: Any?) -> Double? {
        if let d = v as? Double { return d }
        if let i = v as? Int { return Double(i) }
        if let s = v as? String { return Double(s) }
        return nil
    }
}

/// Mindste afstand mellem to bio-ændringer (Instagram bryder sig ikke om mange hurtige ændringer)
struct RateGate {
    var minGap: Double
    var last = -Double.infinity

    func wait(now: Double) -> Double { max(0, last + minGap - now) }
    mutating func mark(now: Double) { last = now }
}
