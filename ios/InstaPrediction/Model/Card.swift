// Spillekort fra hurtig-input: "kh", "10s", "Ar", "qd", "hjerter konge", "K♥".
// Sidste tegn er kulør (h=hjerter, r/d=ruder, k/c=klør, s=spar). Resten er værdi
// (a/e/1=es, 2–10, t=10, j/b/kn=knægt, q/d=dronning, k=konge).
import Foundation

struct Card: Equatable {
    enum Suit: String, CaseIterable {
        case hjerter, ruder, klør, spar
        var symbol: String {
            switch self { case .hjerter: "♥️"; case .ruder: "♦️"; case .klør: "♣️"; case .spar: "♠️" }
        }
    }

    let rank: Int      // 1…13
    let suit: Suit

    var rankName: String {
        switch rank { case 1: "es"; case 11: "knægt"; case 12: "dronning"; case 13: "konge"; default: String(rank) }
    }
    var rankShort: String {
        switch rank { case 1: "A"; case 11: "J"; case 12: "Q"; case 13: "K"; default: String(rank) }
    }
    /// "hjerter konge"
    var name: String { "\(suit.rawValue) \(rankName)" }
    /// "K♥️"
    var short: String { rankShort + suit.symbol }

    private static func suitFrom(word w: String) -> Suit? {
        switch w {
        case "hjerter", "hjerte", "hearts", "heart", "♥": .hjerter
        case "ruder", "diamonds", "diamond", "♦": .ruder
        case "klør", "klöver", "clubs", "club", "♣": .klør
        case "spar", "spades", "spade", "♠": .spar
        default: nil
        }
    }

    private static func rankFrom(word w: String) -> Int? {
        switch w {
        case "a", "e", "es", "ace", "1": return 1
        case "t", "ti": return 10
        case "j", "b", "kn", "knægt", "bonde", "jack": return 11
        case "q", "d", "dronning", "dame", "queen": return 12
        case "k", "konge", "king": return 13
        case "to": return 2
        case "tre": return 3
        case "fire": return 4
        case "fem": return 5
        case "seks": return 6
        case "syv": return 7
        case "otte": return 8
        case "ni": return 9
        default:
            if let n = Int(w), (2...10).contains(n) { return n }
            return nil
        }
    }

    static func parse(_ input: String) -> Card? {
        let t = input.lowercased()
            .replacingOccurrences(of: "\u{FE0F}", with: "")
            .replacingOccurrences(of: "♡", with: "♥").replacingOccurrences(of: "♢", with: "♦")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard !t.isEmpty else { return nil }

        // Hele ord: "hjerter konge", "konge af hjerter", "7 spar"
        let words = t.split { $0 == " " || $0 == "-" || $0 == "," }.map(String.init).filter { $0 != "af" && $0 != "of" }
        if words.count >= 2 {
            var suit: Suit?, rank: Int?
            for w in words {
                if suit == nil, let s = suitFrom(word: w) { suit = s; continue }
                if rank == nil, let r = rankFrom(word: w) { rank = r }
            }
            if let suit, let rank { return Card(rank: rank, suit: suit) }
            return nil
        }

        // Kort form: "kh", "10s", "k♥"
        guard t.count >= 2, let last = t.last else { return nil }
        let suit: Suit?
        switch last {
        case "h", "♥": suit = .hjerter
        case "r", "d", "♦": suit = .ruder
        case "k", "c", "♣": suit = .klør
        case "s", "♠": suit = .spar
        default: suit = nil
        }
        guard let suit, let rank = rankFrom(word: String(t.dropLast())) else { return nil }
        return Card(rank: rank, suit: suit)
    }
}
