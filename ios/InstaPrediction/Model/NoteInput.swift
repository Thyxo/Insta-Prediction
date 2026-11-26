// Noter-input: hvad Bio tager fra det, der skrives i den falske Noter-app.
import Foundation

enum NoteInput {
    static let modes: [(id: String, label: String, help: String)] = [
        ("sidste", "Sidste linje", "Det, der står på den sidste linje. Tilskueren kan skrive en overskrift først."),
        ("første", "Første linje", "Overskriften (første linje)."),
        ("hele", "Hele noten", "Alle linjer samlet med mellemrum."),
        ("ord", "Sidste ord", "Kun det sidste ord, uden tegn."),
        ("kort", "Kort", "Et kort skrevet som \"hjerter konge\", \"KH\" eller \"K♥\". Sidste linje."),
    ]

    /// nil = intet brugbart
    static func extract(_ text: String, mode: String) -> String? {
        let lines = text.components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
        guard let first = lines.first, let last = lines.last else { return nil }
        switch mode {
        case "første": return first
        case "hele": return lines.joined(separator: " ")
        case "ord":
            let w = last.split(separator: " ").last.map { String($0).trimmingCharacters(in: .punctuationCharacters) }
            return (w?.isEmpty ?? true) ? nil : w
        case "kort": return Card.parse(last)?.name
        default: return last
        }
    }
}
