// Låseskærm-input: cifre fra kode-skærmen eller det usynlige tastatur → tekst til et felt.
import Foundation

enum LockInput {
    /// Fortolkninger af cifrene
    static let modes: [(id: String, label: String, help: String)] = [
        ("tal", "Tal", "Cifrene som de er: 1234"),
        ("kort", "Kort (værdi + kulør)", "Sidste ciffer er kulør (1 klør, 2 hjerter, 3 spar, 4 ruder). 132 = hjerter konge. Nuller er fyld: 0132 eller 1320."),
        ("mnemonica", "Kort (Mnemonica 1–52)", "Plads i Tamariz' stak: 7 = spar es. Nuller foran er fyld: 0007."),
        ("dato", "Dato (DDMM)", "2412 = 24. december, 7 = 7."),
    ]

    /// Mnemonica (Juan Tamariz), plads 1…52. Skrevet som kort-input (k = klør, h, s, r = ruder).
    static let mnemonica: [String] = [
        "4k", "2h", "7r", "3k", "4h", "6r", "as", "5h", "9s", "2s", "qh", "3r", "qk",
        "8h", "6s", "5s", "9h", "kk", "2r", "jh", "3s", "8s", "6h", "10k", "5r", "kr",
        "2k", "3h", "8r", "5k", "ks", "jr", "8k", "10s", "kh", "jk", "7s", "10h", "ar",
        "4s", "7h", "4r", "ak", "9k", "js", "qr", "7k", "qs", "10r", "6k", "ah", "9r",
    ]

    /// CHaSeD: 1 klør, 2 hjerter, 3 spar, 4 ruder
    static let suitCode: [Character: Card.Suit] = ["1": .klør, "2": .hjerter, "3": .spar, "4": .ruder]

    static let months = ["januar", "februar", "marts", "april", "maj", "juni", "juli",
                         "august", "september", "oktober", "november", "december"]
    static let monthDays = [31, 29, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31]

    static func interpret(_ raw: String, mode: String) -> String? {
        let d = raw.filter(\.isNumber)
        guard !d.isEmpty else { return nil }
        // Kode-skærmen kræver 4/6 cifre: nuller foran/bagved er fyld (0132, 1320, 000007)
        let trimmed = String(d.drop { $0 == "0" }.reversed().drop { $0 == "0" }.reversed())
        let lead = String(d.drop { $0 == "0" })
        switch mode {
        case "kort":
            let d = trimmed
            guard d.count >= 2, d.count <= 3, let suit = suitCode[d.last!],
                  let rank = Int(d.dropLast()), (1...13).contains(rank) else { return nil }
            return Card(rank: rank, suit: suit).name
        case "mnemonica":
            guard let n = Int(lead) ?? Int(trimmed), (1...52).contains(n) else {
                if let n = Int(trimmed), (1...52).contains(n) { return Card.parse(mnemonica[n - 1])?.name }
                return nil
            }
            return Card.parse(mnemonica[n - 1])?.name
        case "dato":
            if d.count <= 2 {
                guard let day = Int(d), (1...31).contains(day) else { return nil }
                return "\(day)."
            }
            guard d.count <= 4, let day = Int(d.dropLast(2)), let m = Int(d.suffix(2)),
                  (1...12).contains(m), (1...monthDays[m - 1]).contains(day) else { return nil }
            return "\(day). \(months[m - 1])"
        default:
            return d
        }
    }
}
