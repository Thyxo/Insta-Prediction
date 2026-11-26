# Insta Prediction: plan

Vores egen udgave af *Hydra Pro* (Shameer Salim, Ellusionist, ca. 96 $). Bygget efter [Thyxo/thyxo](https://github.com/Thyxo/thyxo): `guides/magi.md`, `guides/webapps.md` og relæet `magic-relay`.

## 1. Effekten (én sætning)

> Tilskueren tænker frit på et ord, et kort eller et tal, finder **din rigtige Instagram-profil på sin egen telefon**, og tanken står allerede i din bio.

Eksempel: til julefrokost i Valby tænker Mette på "Bornholm". Du siger "Find mig på Instagram". I bioen står `📍 Næste tur: Bornholm 🇩🇰`.

Salgsargumenterne fra Hydra Pro, som vi skal leve op til:
- Ingen force, ingen falsk app hos tilskueren, du rører ikke deres telefon.
- Flere input (capture) → én skabelon → flere output.
- Skabeloner med flere felter ("kort + tal + by" i samme bio).
- Hurtig: bioen er opdateret, før tilskueren har fundet profilen.

## 2. Metode: tre led

```
 INPUT (capture)          HJERNE (Railway)            OUTPUT (afsløring)
 ─────────────────        ───────────────────         ────────────────────
 Fake Google       ─┐                              ┌─ Instagram-bio
 Noter+ / Notes    ─┤     relæ-rum  ──►  bio-       ├─ Noter+ / Mosaik
 Calc+ (tal)       ─┼──►  {insta:{…}}    service   ─┼─ Webhook / custom API
 Clock+ (låseskærm)─┤     skabelon +               └─ (senere) Instagram Notes
 Kort / Memdeck+   ─┤     værdier → tekst
 Swipe (fakehome)  ─┤
 Kontrol-app       ─┘
```

### Input
Vi har det meste allerede. Hver app skriver bare et nyt felt i relæ-rummet:

| Input | App (findes) | Felt |
|---|---|---|
| Søgning | Fake Google | `googleLive.q` |
| Noter | Noter+ / Notes | `note` |
| Tal | Calc+, Stopwatch+, fakehome-swipe | `number` |
| Låseskærm / klokkeslæt | Clock+ | `time` |
| Kort | Card Detector, Memdeck+ | `card` |
| Manuelt / peek | **Ny:** Kontrol-PWA | alle |

### Hjernen (nyt: `insta-service` på Railway, projekt `magic-relay`)
- Lytter på relæ-rummet (SSE `GET /r/:kode/events`).
- Når alle felter i aktiv skabelon er udfyldt (eller performeren trykker "Afslør"), bygges teksten og sendes til output.
- Gemmer standard-bio og sætter den tilbage efter showet ("Nulstil" eller automatisk efter X min).
- Hemmeligheder (Instagram-session) ligger som Railway-variabler, **aldrig i en webapp**.

### Output: Instagram-bio
**Vigtigt:** Metas officielle API (Graph API) kan **ikke** skrive i bioen. Hydra må bruge Instagrams uofficielle app-/web-API med en logget-ind session. Det gør vi også:

**"Connect konto" (OAuth) virker ikke til bio.** Instagram API with Instagram Login (Business/Creator) kan læse `biography`, men opdatering er "not supported". Den kan kun lave opslag, stories, kommentarer og DM'er, og alt det får et "lige nu"-tidsstempel, der afslører effekten.

**Valgt løsning: login inde i vores egen iPhone-app (som Hydra):**
- Native SwiftUI-app (SideStore) med en indbygget `WKWebView`, hvor du logger ind på instagram.com som normalt (inkl. 2FA).
- Appen gemmer session-cookien i Keychain. Koden ser vi aldrig.
- Bio-opdatering = samme kald som "Rediger profil" på instagram.com, sendt **fra din egen telefon** (din IP, din enhed). Det giver langt færre sikkerhedstjek end et login fra en Railway-server.
- En webapp (PWA) kan ikke gøre det: browseren blokerer kald til instagram.com fra et andet domæne (CORS), og vi kan ikke læse cookien.
- Railway-relæet bruges stadig til input fra de andre apps. Selve skrivningen til Instagram sker fra telefonen.
- Reserve: samme kald fra en server (Node) med session-cookie, hvis telefonen ikke kan.

Risici, og hvad vi gør:
| Risiko | Modtræk |
|---|---|
| Brud på Instagrams vilkår → konto kan låses | Test først på en **tom test-konto**, derefter @danieltryller (show-kontoen) |
| "Mistænkelig aktivitet"-tjek | Kaldet kommer fra din egen telefon; genbrug session; ingen gentagne logins |
| Rate-limit ved mange ændringer | Maks ca. 1 ændring pr. minut, kø + "for hurtigt"-advarsel |
| Tilskuerens app viser gammel bio (cache) | Opdater **før** de søger; bed dem søge frem for at trykke på et gammelt link |
| Instagram ændrer API | Output er et plugin; fallback til Noter+/Mosaik i samme rum |
| Bio maks 150 tegn | Skabelon-editor viser tegntæller |

### Andre output (samme skabelon)
- **Noter+ / Mosaik** via relæet (findes).
- **Webhook**: POST til valgfri URL = "custom API" som i Hydra.
- **Senere:** Instagram Notes (den lille boble i DM), profilnavn, fastgjort kommentar.

## 3. Kontrol-PWA (performerens app)

Vanilla JS-webapp på Vercel efter `guides/webapps.md`. Ligger på performerens telefon, forklædt som fx "Påmindelser".

Skærme:
1. **Skabeloner**: liste + editor. `Mit kort i dag: {kort} · {by}` med felttyper (ord, tal, kort, dato) og tegntæller. Gemmes i `localStorage` (`insta:v1`) + i relæ-rummet som backup ("cloud sync").
2. **Live**: viser indkomne værdier (peek), status (rum online, Instagram ok), stor "Afslør"-knap og "Nulstil bio".
3. **Indstillinger** (hemmelig menu, 5 tryk øverst til højre): rum-kode, auto-afslør til/fra, auto-nulstil efter N min, standard-bio, øve-tilstand (skriver ikke til Instagram, viser bare tekst).

Regler fra `magi.md`: dansk UI, panik = hold 1 sek. → neutral, tilstand går aldrig selv tilbage, virker uden net (viser sidste værdi).

## 4. Faser

| Fase | Indhold | Resultat |
|---|---|---|
| **0. Spike** (½ dag) | Mini-iPhone-app: WebView-login + knap "Skift bio" på test-konto. Mål tid fra kald → synlig hos tilskuer | Ved vi om det holder |
| **1. MVP** | iPhone-appen får skabelon, manuel peek/input, "Afslør" og "Nulstil" | Første rigtige show-test |
| **2. Input** | Koble Fake Google, Noter+, Calc+, Clock+ på via relæ-felter | "Capture methods" |
| **3. Skabeloner** | Flere felter, flere afsløringer, auto-afslør, cloud-backup | Hydra Pro-niveau |
| **4. Ekstra** | Webhook-output, Noter+/Mosaik-output, temaer | Feature-paritet |
| **5. Native (valgfri)** | SwiftUI-app + Apple Watch-peek via GitHub Actions/SideStore | Håndfri afsløring |

## 5. Repo-struktur (forslag)

```
web/            Kontrol-PWA (index.html, app.js, styles.css, sw.js, manifest)
server/         insta-service (Bun/Node): relæ-lytter, skabeloner, Instagram-output
  outputs/      instagram.js, webhook.js, relay.js
  templates.js  ren logik + tests
tests/
CLAUDE.md       efter skabelonen, med "Nemme at ødelægge"
README.md       til performeren: opsætning, rutine, nulstilling
```

## 6. Tjek før show
- Bio er nulstillet, og standard-bio ser naturlig ud (ikke tom).
- Øve-tilstand er **slået fra**.
- Railway-service kører, Instagram-status grøn i Kontrol-appen.
- Out: virker Instagram ikke, afslør i Noter+ eller med klassisk "skrevet i forvejen".

## 7. Åbne spørgsmål
1. ~~Konto~~ → @danieltryller (efter test på en tom konto).
2. ~~Webapp eller native~~ → native iPhone-app (krævet af login-metoden).
3. Hvilket input er vigtigst først: Fake Google, Noter+ eller manuel peek?
