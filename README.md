# Bio – forudsigelsen står i din rigtige Instagram-bio

En iPhone-app (SwiftUI) til close-up mentalisme. Tilskueren tænker frit på et kort, et tal, en dato eller et ord. Du får informationen i hemmelighed, og Bio skriver den i **din rigtige Instagram-bio**. Tilskueren finder selv din profil på **sin egen telefon**, og forudsigelsen står der.

**Effekten:** *"Tænk på et kort. Lås min telefon op med det som kode."* Koden ryster som forkert. *"Ikke min kode. Men tjek lige min Instagram."* I bioen står `🃏 Dit kort er hjerter konge`.

- Ingen falsk app hos tilskueren. Det er din ægte profil på deres telefon.
- Du rører ikke deres telefon.
- Input via en falsk iOS 26-låseskærm, manuelt eller fra dine andre apps via relæet.

🌐 **Hjemmeside:** https://thyxo.github.io/Insta-Prediction/

---

## 1. Installér
Bio er ikke på App Store. Den installeres med **SideStore** (eller AltStore/LiveContainer).

1. Har du ikke SideStore: installér det fra en computer med **[iLoader](https://iloader.app)** (gratis, et almindeligt Apple-ID er nok).
2. I SideStore → **Sources** → **+**, indsæt:
   ```
   https://raw.githubusercontent.com/Thyxo/Insta-Prediction/main/sidestore/apps.json
   ```
3. Installér **Bio**. Nye versioner kommer som opdateringer.

Eller hent IPA'en direkte: https://github.com/Thyxo/Insta-Prediction/releases/latest

Første gang: slå **Indstillinger → Anonymitet & sikkerhed → Udviklertilstand** til. Med et gratis Apple-ID skal apps fornyes hver 7. dag (SideStore kan gøre det selv).

## 2. Første opsætning (5 minutter)
1. **Log ind:** åbn Bio → tryk **Log ind** (chippen øverst) → log ind på Instagram som normalt, også med to-trins-kode. Din kode bliver på telefonen. Din nuværende bio gemmes som *standard-bio*.
2. **Øve-tilstand** er slået til fra start (orange chip "Øve"). Så skrives der intet til Instagram. Prøv alt igennem først.
3. **Urskrift** (så uret ligner din rigtige låseskærm): ⚙︎ → **Låseskærm** → **Urskrift** → **Vælg zip eller .otf fra Filer** → vælg zip-filen med iOS 26-urskrifterne. Eller læg zip-filen i **Filer → På min iPhone → Bio**, så henter Bio den selv. Tryk **Som min iPhone (målt)**.
4. **Baggrund:** ⚙︎ → **Låseskærm** → **Vælg baggrund** → samme billede som din rigtige låseskærm.
5. **Klar til show:** tryk på den orange **Øve**-chip for at slå øve-tilstand fra.

## 3. Rutine: kort som pinkode
**Opsætning:** ⚙︎ → Låseskærm → *Fortolk som:* **Kort (værdi + kulør)** → feltet `{kort}`. Skabelon **Kort**.

1. Tryk **Låseskærm** i Bio. Telefonen ligner nu din låste iPhone.
2. *"Tænk på et kort. Brug det som min pinkode: værdien, og så kuløren som et tal."*

   | Kulør | Ciffer |
   |---|---|
   | ♣️ Klør | 1 |
   | ♥️ Hjerter | 2 |
   | ♠️ Spar | 3 |
   | ♦️ Ruder | 4 |

   Hjerter konge = 13 og 2 = `132`. Koden har 4 cifre, så nuller er fyld: `0132` eller `1320`.
3. Tilskueren stryger op og taster. Koden ryster og vibrerer som **forkert kode**.
4. Bio afslører efter 2 sek. Hængelåsen øverst åbner kort, når bioen er skiftet (kun du ved, hvad det betyder).
5. *"Ikke min kode … men tjek lige min Instagram."* Tilskueren søger dig frem på sin egen telefon.
6. Bagefter: 5 hurtige tryk øverst til højre → tilbage i Bio → **↺ Nulstil**.

## 4. Rutine: du taster selv (usynligt tastatur)
Du har fået informationen på anden vis (peek, force, memdeck).

1. Låseskærmen står fremme. **Langt tryk på uret** (½ sek.).
2. I 8 sek. er hele skærmen et usynligt tastatur:

   | | | |
   |:-:|:-:|:-:|
   | 1 | 2 | 3 |
   | 4 | 5 | 6 |
   | 7 | 8 | 9 |
   | ✕ slet | 0 | ✓ færdig |

3. Tast fx `7` (Mnemonica: spar es) og **✓**. Bioen skiftes.

## 5. Låseskærm: genveje
| Hvad | Sådan |
|---|---|
| Kode-skærm | Stryg op |
| Usynligt tastatur | Langt tryk på uret |
| Sort skærm (telefonen "slukket") | Dobbelttryk · tryk vækker |
| Panik (annullér afsløring) | Hold øverst til venstre i 1 sek. |
| Tilbage til Bio | 5 hurtige tryk øverst til højre |

**Fortolk cifrene som:**
| Valg | Eksempel |
|---|---|
| Tal | `1234` → 1234 |
| Kort (værdi + kulør) | `132` → hjerter konge |
| Kort (Mnemonica 1–52) | `7` → spar es |
| Dato (DDMM) | `2412` → 24. december |

Øv dig med ⚙︎ → Låseskærm → **Vis hemmelige zoner**. Så kan du se zonerne og tastaturet.

## 6. Skabeloner
Bioen bygges af en skabelon med felter i `{ }`. Vælg skabelon øverst på bio-kortet.

| Skabelon | Bliver til |
|---|---|
| `🃏 Dit kort er {kort\|kort}` | 🃏 Dit kort er hjerter konge |
| `✨ Ordet du tænker på: {ord\|titel}` | ✨ Ordet du tænker på: Bornholm |
| `📅 Din dag er {dato}` | 📅 Din dag er 24. december |
| `🃏 {kort\|kort} · 🔢 {tal}` | 🃏 hjerter konge · 🔢 42 |

**Filtre:** `|titel` (Stort forbogstav), `|stor`, `|lille`, `|kort` (kh → hjerter konge), `|kortikon` (kh → K♥️), `|tal` (kun cifre).
Maks 150 tegn, tælleren står på kortet. Gør bioen naturlig: den skal ligne noget, du selv kunne have skrevet.

## 7. Indstillinger (⚙︎)
1. **Øve-tilstand:** skriver ikke til Instagram.
2. **Instagram:** konto, test forbindelse, standard-bio (den Nulstil sætter tilbage).
3. **Skabeloner:** lav og ret dine bio-tekster.
4. **Låseskærm:** input, afsløring, urskrift, baggrund, øvelse.
5. **Afsløring:** nulstil automatisk efter 1–30 min, notifikationer.
6. **Relæ:** rum-kode til input fra Fake Google, Noter+ og Calc+.
7. **Log:** hvad der er sket, og den seneste fejl.

## 8. Tjek før show
- [ ] Øve-chippen er væk (øve-tilstand fra).
- [ ] Chippen viser `@ditnavn` med grøn prik. Ellers: ⚙︎ → Instagram → Test forbindelse.
- [ ] Standard-bio ser naturlig ud.
- [ ] Låseskærm: rigtig baggrund og urskrift (grønt flueben under Urskrift).
- [ ] Forstyr ikke til, så ingen notifikationer dukker op midt i effekten.
- [ ] Out: virker Instagram ikke, så afslør med "Jeg skrev det ned før" (Noter+).

## 9. Godt at vide
- **Instagram har ingen officiel måde at ændre bio på.** Bio bruger de samme kald som instagram.com. Det er imod Instagrams vilkår, og i værste fald kan kontoen blive låst. Bio venter mindst 15 sek. mellem to ændringer.
- Tilskuerens Instagram kan vise en gammel udgave af din profil. Bed dem **søge** dig frem frem for at trykke på et gammelt link.
- Bioen kan højst være 150 tegn.
- Urskrifterne er Apples og må ikke deles. Derfor ligger de ikke i appen, men hentes på din telefon.

## 10. Projekt
```
ios/project.yml                 XcodeGen
ios/InstaPrediction/
  Model/                        Ren logik (testet): skabeloner, kort, låseskærm-input, relæ
  App/                          AppState, Instagram, relæ, skrifter, zip, baggrund
  Views/                        HomeView, LockScreen, PasscodeView, ClockView, indstillinger
ios/Tests/main.swift            Hurtige tests (kører før hvert build)
site/                           Hjemmesiden (GitHub Pages)
sidestore/apps.json             SideStore-source (opdateres af CI)
.github/workflows/ios.yml       Test → build → release → SideStore
.github/workflows/pages.yml     Udgiver site/ til GitHub Pages
```
Push til `main` = nyt build og ny version i SideStore.
