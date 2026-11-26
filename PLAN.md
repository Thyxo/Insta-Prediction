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

- Login én gang på serveren (brugernavn + kode + 2FA-kode) → gem session-cookie.
- Bio-opdatering = samme kald som når du redigerer profil i Instagram-webappen.
- Lib-valg: Node `instagram-private-api` eller et rent `fetch`-kald mod web-endpointet. Prototype afgør hvilket der er mest stabilt.

Risici, og hvad vi gør:
| Risiko | Modtræk |
|---|---|
| Brud på Instagrams vilkår → konto kan låses | Brug en **dedikeret performer-konto**, ikke familiens private |
| "Mistænkelig aktivitet"-tjek ved login fra Railway | Login fra samme IP fast; genbrug session; ingen gentagne logins |
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
| **0. Spike** (½ dag) | Node-script: login + skift bio på test-konto. Mål tid fra kald → synlig i app | Ved vi om det holder |
| **1. MVP** | `insta-service` på Railway + Kontrol-PWA med manuelt input og én skabelon | Første rigtige show-test |
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
1. Har du en separat performer-konto på Instagram, eller skal vi oprette én?
2. Skal hjernen ligge i den eksisterende `relay`-service eller som ny service i `magic-relay`?
3. Hvilket input er vigtigst først: Fake Google, Noter+ eller manuel peek?
4. Webapp først (hurtig) eller direkte native iPhone-app?
