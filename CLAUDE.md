# CLAUDE.md

Insta Prediction: native iOS-app (Swift/SwiftUI, XcodeGen, ingen .xcodeproj i git). Den skriver en forudsigelse i performerens **rigtige** Instagram-bio. Dansk UI, visningsnavn "Bio". Se README.md (performer) og PLAN.md (faser). Reference: https://github.com/Thyxo/thyxo.

- **Arbejd og push altid direkte på `main`** (ejerens ønske). Push til `main` = udgivelse.
- Bygges i GitHub Actions (`.github/workflows/ios.yml`) uden signering → GitHub Release + `sidestore/apps.json` opdateres automatisk. Hæv `MARKETING_VERSION` i `ios/project.yml` ved større ændringer. CI committer `apps.json`, så kør `git pull` før push.
- `ios/InstaPrediction/Model/` er ren Swift (kun Foundation) og testes med `ios/Tests/main.swift` (kører i CI før buildet):
  `swiftc -swift-version 5 ios/InstaPrediction/Model/*.swift ios/Tests/main.swift -o /tmp/t && /tmp/t`
- `App/Instagram.swift`: login-session fra WKWebView (`WKWebsiteDataStore.default()`), kald med URLSession og samme user agent.
- `App/Relay.swift` er kopieret fra Mosaik (samme relæ som Noter+/Calc+: `https://relay-production-03f5.up.railway.app`, Railway-projekt magic-relay).

## Låseskærm (input)
- `Views/LockScreen.swift` + `PasscodeView.swift`: falsk iOS 26-låseskærm, inspireret af Thyxo/ClockPlus (samme genveje: stryg op = kode-skærm, langt tryk på uret = usynligt 3×4-tastatur, dobbelttryk = sort, 5 tryk øverst til højre = ud, hold øverst til venstre = panik).
- Cifre → `AppState.lockCaptured` → `LockInput.interpret` (tal | kort CHaSeD | Mnemonica | dato) → feltet `lockField` → evt. afsløring efter `lockDelay`.
- Ingen haptik fra Bio, mens låseskærmen vises (kun kode-skærmens "forkert kode"-vibration, som en rigtig iPhone).
- Statuslinjen er iOS' egen (ægte). Ejeren vil ikke have en tegnet.
- Baggrund gemmes i Application Support (`Wallpaper`).
- **Uret** (`Views/ClockView.swift`) tegnes med CoreText. Målt på ejerens iOS 26-låseskærm (1179×2556): `SFAdaptiveNumeric-VF.otf`, wght 600, wdth 100, HGHT ≈ 230; cifrene fylder 86 % af bredden og 28,4 % af højden, top = safe area + 55 pt. Dato `tors. 26. nov.` 22 pt semibold, top = safe area + 25 pt. Knapper 57 pt, centrum 75 pt fra siden og bund-inset + 45 pt.
- **Apples skrifter må ikke i repoet eller IPA'en** (repo og releases er offentlige). `ClockFonts.findOnDevice()` finder dem i iOS på telefonen (FontServices.framework m.fl.) ved første start og kopierer dem til Application Support/Fonts. Reserve: zip eller .otf fra Filer (`App/ZipReader.swift` pakker ud), filer lagt i Bio-mappen i Filer (Documents, `UIFileSharingEnabled`) hentes ved start, eller direkte link.

## Noter (input)
- `Views/NotesView.swift` (kun iOS 26): klon af iOS 26 Noter efter ejerens skærmoptagelse. Bygget på systemets egne dele (NavigationStack, `.searchable` + `DefaultToolbarItem(kind: .search)` i bundlinjen, `ToolbarSpacer`, `.glassProminent` ✓, `swipeActions`, `ShareLink`, Menu), så glas og animationer er ægte. Kun værktøjslinjen over tastaturet er tegnet.
- Noterne (`Model/FakeNotes.swift`: sektioner/datoer som Noter, eksempel-noter) gemmes i `AppState.fakeNotes` og kan rettes i appen.
- Kun noter oprettet i denne omgang tæller. Ved ✓/tilbage → `AppState.noteCaptured` → `NoteInput.extract` → feltet `noteField` → evt. afsløring efter `noteDelay`.
- **Pause sender:** hver tastning i tilskuerens note kalder `AppState.noteTyped`; efter `noteIdleSec` (standard 3) uden tastning → `noteCaptured(now: true, idle: true)`. En ventende afsløring venter på `busy` og sender så den nyeste tekst.
- Efter hver Noter-afsløring logges tid fra udløser (pause/låsning/Færdig) og fra sidste tast (`logNoteTiming`), vist nederst på forsiden.
- **Låsning sender:** når scenePhase bliver inactive/background med tilskuerens note åben (`AppState.activeNoteID`), kaldes `noteCaptured(now: true)` uden ventetid (`noteOnLock`). `BackgroundTime` (beginBackgroundTask) + lydløs keeper (startes mens Noter er åben) giver tid til kaldet. Ingen notifikationer, mens Noter/låseskærm vises (de ville lyse op på bordet).
- Ud: 5 tryk øverst til højre eller hold øverst til venstre i 1 sek.
- Appen er dansk lokaliseret (`da.lproj`, `CFBundleLocalizations`), så systemtekster (Søg, Kopiér, Del, tastaturforslag) er danske.

## UI
- Designsystem = iOS' egne komponenter, som ejerens app Mindtrace: `List`/`Form` i `.insetGrouped`, mørk, teal accent (`Theme.accent` i `Views/Theme.swift`), farvede ikon-firkanter (`SettingsIcon`), store pille-knapper (`PillButton`). Ingen egne baggrunde eller hjemmeside-agtige kort.
- Hovedskærm `Views/HomeView.swift`: Konto, Forudsigelse (skabelon, felter, bio-preview, Afslør/Nulstil), Input (låseskærm). Alt andet i Indstillinger.
- Skal føles som en app: `.scrollBounceBehavior(.basedOnSize)`, så hovedskærmen ikke hopper op og ned.
- Hold hovedskærmen rolig: ingen nye sektioner dér uden ejerens ønske.

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
- **Login huskes af Bio selv:** `CookieVault` gemmer Instagram-cookies i Application Support (fil-beskyttelse untilFirstUserAuthentication) og lægger dem tilbage i WebKit, hvis WebKit har glemt dem (sker i LiveContainer). Log ud sletter filen.
- **Samme user agent** i login-vinduet og i kaldene (`Instagram.userAgent`).
- **Ræk ikke ud efter kodeordet.** Login sker kun i WKWebView; vi læser cookies, aldrig felter.
- **Øve-tilstand er standard** ved første start. Den må ikke slås fra automatisk.
- **Mindste afstand** mellem ændringer (`minGap`, standard 15 sek.). Sænk den ikke under 5.
- **Baggrund** = lydløs `AVAudioEngine` (`UIBackgroundModes: audio`). Uden den sætter iOS appen på pause, og relæ-input fra Safari når ikke frem.
- Bio maks 150 tegn, talt som UTF-16 (`Rendered.length`).
