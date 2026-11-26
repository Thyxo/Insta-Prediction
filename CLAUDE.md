# CLAUDE.md

Insta Prediction: native iOS-app (Swift/SwiftUI, XcodeGen, ingen .xcodeproj i git). Den skriver en forudsigelse i performerens **rigtige** Instagram-bio. Dansk UI, visningsnavn "Bio". Se README.md (performer) og PLAN.md (faser). Reference: https://github.com/Thyxo/thyxo.

- Bygges i GitHub Actions (`.github/workflows/ios.yml`) uden signering → GitHub Release + `sidestore/apps.json` opdateres automatisk. Hæv `MARKETING_VERSION` i `ios/project.yml` ved større ændringer. CI committer `apps.json`, så kør `git pull` før push.
- `ios/InstaPrediction/Model/` er ren Swift (kun Foundation) og testes med `ios/Tests/main.swift` (kører i CI før buildet):
  `swiftc -swift-version 5 ios/InstaPrediction/Model/*.swift ios/Tests/main.swift -o /tmp/t && /tmp/t`
- `App/Instagram.swift`: login-session fra WKWebView (`WKWebsiteDataStore.default()`), kald med URLSession og samme user agent.
- `App/Relay.swift` er kopieret fra Mosaik (samme relæ som Noter+/Calc+: `https://relay-production-03f5.up.railway.app`, Railway-projekt magic-relay).

## Relæ-felter
- Læser (standard): `google.q` (Fake Google), `force.name` / `force.digits` (Noter+), `result.value` (Calc+), `card.name`. Kan ændres pr. felt i indstillinger.
- Læser kommandoer: `insta { cmd: "reveal" | "reset", at }`.
- Skriver status: `instaStatus { bio, ok, practice, at }`.
- Relæ-værdier med `at` ældre end sidste nulstilling ignoreres (`insta.armedAt`).

## Nemme at ødelægge
- **Ingen officiel API kan skrive bio.** Endpoints er uofficielle og kan ændre sig:
  - læs: `GET /api/v1/accounts/edit/web_form_data/`
  - skriv A: `POST /api/v1/accounts/set_biography/` (`raw_text`), rører kun bioen
  - skriv B: `POST /api/v1/web/accounts/edit/` (hele formularen). Send altid alle felter fra `web_form_data`, ellers kan navn/link blive tømt. Stop hvis `username` mangler.
  - Headers: `X-IG-App-ID: 936619743392459`, `X-CSRFToken` (cookie `csrftoken`), `X-Requested-With`, `Referer`.
- **Samme user agent** i login-vinduet og i kaldene (`Instagram.userAgent`).
- **Ræk ikke ud efter kodeordet.** Login sker kun i WKWebView; vi læser cookies, aldrig felter.
- **Øve-tilstand er standard** ved første start. Den må ikke slås fra automatisk.
- **Mindste afstand** mellem ændringer (`minGap`, standard 15 sek.). Sænk den ikke under 5.
- **Baggrund** = lydløs `AVAudioEngine` (`UIBackgroundModes: audio`). Uden den sætter iOS appen på pause, og relæ-input fra Safari når ikke frem.
- Bio maks 150 tegn, talt som UTF-16 (`Rendered.length`).
