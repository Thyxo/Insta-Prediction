// Hurtig test af skabeloner, kort og relæ-stier (kører i CI før buildet):
// swiftc ios/InstaPrediction/Model/*.swift ios/Tests/main.swift -o /tmp/t && /tmp/t
import Foundation

var failures = 0
func check(_ ok: Bool, _ msg: String) { if !ok { failures += 1; print("FEJL:", msg) } else { print("ok:", msg) } }

// 1. Felter og udfyldning
let t = "🃏 {kort|kort} · {by|titel} · {by}"
check(TemplateEngine.fields(in: t) == ["kort", "by"], "felter i rækkefølge uden dubletter")
let r1 = TemplateEngine.render(t, values: ["kort": "kh", "by": "bornholm"])
check(r1.text == "🃏 hjerter konge · Bornholm · bornholm", "udfyldning med filtre: \(r1.text)")
check(r1.missing.isEmpty, "intet mangler")
let r2 = TemplateEngine.render(t, values: ["kort": "  "])
check(r2.missing == ["kort", "by"], "tomme felter mangler: \(r2.missing)")
check(r2.text == t, "manglende felter står urørt")
check(TemplateEngine.render("{ord|stor}", values: ["ord": "æble"]).text == "ÆBLE", "stor med æøå")
check(TemplateEngine.render("Tal: {tal|tal}", values: ["tal": "nr. 4 2"]).text == "Tal: 42", "kun cifre")
check(TemplateEngine.render("{x", values: ["x": "1"]).text == "{x", "ufærdig parentes er tekst")
check(TemplateEngine.render("{ugyldig felt} {a}", values: ["a": "1"]).text == "{ugyldig felt} 1", "ugyldigt navn er tekst")
check(TemplateEngine.fields(in: "{a {b}") == ["b"], "indlejret start")
check(TemplateEngine.render(String(repeating: "x", count: 151), values: [:]).tooLong, "over 150 tegn")
check(TemplateEngine.render("👋", values: [:]).length == 2, "emoji tæller som UTF-16")

// 2. Kort
let cards: [(String, String?)] = [
    ("kh", "hjerter konge"), ("KH", "hjerter konge"), ("kk", "klør konge"), ("10s", "spar 10"),
    ("ts", "spar 10"), ("Ar", "ruder es"), ("qd", "ruder dronning"), ("js", "spar knægt"),
    ("7♣️", "klør 7"), ("K♥", "hjerter konge"), ("hjerter konge", "hjerter konge"),
    ("konge af hjerter", "hjerter konge"), ("7 spar", "spar 7"), ("es i spar", "spar es"),
    ("ruder es", "ruder es"), ("x", nil), ("1x", nil), ("11h", nil), ("", nil),
]
for (inp, want) in cards { check(Card.parse(inp)?.name == want, "kort \"\(inp)\" → \(Card.parse(inp)?.name ?? "nil")") }
check(Card.parse("qh")?.short == "Q♥️", "kortikon")

// 3. Relæ-stier
let state: [String: Any] = [
    "google": ["q": " Bornholm ", "at": 1_700_000_000_000.0],
    "result": ["value": 42, "at": 5],
    "force": ["name": "", "digits": "1234"],
    "x": "tekst",
]
check(RelayPath.lookup(state, "google.q")?.value == "Bornholm", "google.q")
check(RelayPath.lookup(state, "google.q")?.at == 1_700_000_000_000, "tidsstempel")
check(RelayPath.lookup(state, "result.value")?.value == "42", "tal som tekst")
check(RelayPath.lookup(state, "force.name") == nil, "tom værdi = intet")
check(RelayPath.lookup(state, "force.digits")?.at == nil, "intet tidsstempel")
check(RelayPath.lookup(state, "nope.q") == nil, "ukendt sti")
check(RelayPath.lookup(state, "x")?.value == "tekst", "felt i roden")
if let d = try? JSONSerialization.jsonObject(with: Data(#"{"result":{"value":7.0,"at":1}}"#.utf8)) as? [String: Any] {
    check(RelayPath.lookup(d, "result.value")?.value == "7", "JSON-tal 7.0 → 7")
}

// 4. Afstand mellem ændringer
var gate = RateGate(minGap: 15)
check(gate.wait(now: 100) == 0, "første ændring med det samme")
gate.mark(now: 100)
check(gate.wait(now: 105) == 10, "venter resten af afstanden")
check(gate.wait(now: 200) == 0, "efter afstanden")

// 5. Standardindstillinger
let s = Settings()
check(s.allFields == ["ord", "kort", "tal", "dato", "navn"], "felter i standardskabeloner: \(s.allFields)")
check(s.practice, "starter i øve-tilstand")
for f in s.allFields { check(s.sources[f] != nil, "kilde for \(f)") }

// 6. Låseskærm-input
check(LockInput.mnemonica.count == 52 && Set(LockInput.mnemonica.compactMap { Card.parse($0)?.name }).count == 52, "Mnemonica: 52 forskellige kort")
let lockCases: [(String, String, String?)] = [
    ("0042", "tal", "0042"), ("", "tal", nil),
    ("132", "kort", "hjerter konge"), ("11", "kort", "klør es"), ("104", "kort", "ruder 10"),
    ("143", "kort", nil), ("15", "kort", nil), ("1", "kort", nil),
    ("7", "mnemonica", "spar es"), ("1", "mnemonica", "klør 4"), ("52", "mnemonica", "ruder 9"), ("53", "mnemonica", nil),
    ("0132", "kort", "hjerter konge"), ("1320", "kort", "hjerter konge"), ("001020", "kort", "hjerter 10"),
    ("000007", "mnemonica", "spar es"), ("0052", "mnemonica", "ruder 9"), ("5200", "mnemonica", "ruder 9"),
    ("2412", "dato", "24. december"), ("702", "dato", "7. februar"), ("7", "dato", "7."),
    ("3102", "dato", nil), ("2913", "dato", nil), ("32", "dato", nil),
]
for (inp, mode, want) in lockCases {
    check(LockInput.interpret(inp, mode: mode) == want, "lås \(mode) \"\(inp)\" → \(LockInput.interpret(inp, mode: mode) ?? "nil")")
}
check(Settings().lockCodeLength == 6, "kode: 6 cifre som standard")

// 7. Noter-input
let noteCases: [(String, String, String?)] = [
    ("Bornholm", "sidste", "Bornholm"), ("Ord\n  Bornholm  \n\n", "sidste", "Bornholm"),
    ("Ord\nBornholm", "første", "Ord"), ("Min tanke\nen rød bil", "hele", "Min tanke en rød bil"),
    ("jeg tænker på Paris!", "ord", "Paris"), ("hjerter konge", "kort", "hjerter konge"),
    ("Kort:\nKH", "kort", "hjerter konge"), ("blå", "kort", nil), ("  \n ", "sidste", nil), ("", "hele", nil),
]
for (inp, mode, want) in noteCases {
    check(NoteInput.extract(inp, mode: mode) == want, "note \(mode) \"\(inp)\" → \(NoteInput.extract(inp, mode: mode) ?? "nil")")
}
check(Settings().noteField == "ord", "noter: feltet ord som standard")

print(failures == 0 ? "ALLE TESTS OK" : "\(failures) FEJL")
exit(failures == 0 ? 0 : 1)
