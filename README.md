# Insta Prediction 🔮

Tilskueren tænker frit på et ord, et kort eller et tal. De finder **din rigtige Instagram-profil på deres egen telefon**, og tanken står i bioen.

Vores udgave af den slags effekt, man kender fra *Hydra Pro*, bygget efter [Thyxo/thyxo](https://github.com/Thyxo/thyxo).

## Hvorfor native og ikke webapp?

| | Native iPhone-app (valgt) | Webapp (PWA) |
|---|---|---|
| Log ind på Instagram og skriv bio | ✅ Login i indbygget browser, cookies på telefonen | ❌ Browseren blokerer kald til instagram.com (CORS) |
| Kører i baggrunden (input fra Fake Google i Safari) | ✅ Lydløs lyd holder den vågen | ❌ iOS pauser webapps |
| Haptik + notifikation på uret | ✅ | ⚠️ Begrænset |
| Hurtig at rette og dele | ⚠️ Build 5–8 min, SideStore | ✅ Push = live |

En webapp kan **ikke** skrive i bioen uden en server, der holder din Instagram-session, og et login fra en server ligner mere misbrug for Instagram. Derfor er hjernen på telefonen. Input-apps (Fake Google, Noter+, Calc+) er stadig webapps og taler via relæet.

## Installér
1. Tilføj SideStore-source: `https://raw.githubusercontent.com/Thyxo/Insta-Prediction/main/sidestore/apps.json`
2. Installér **Bio**.
3. Åbn ⚙︎ → **Log ind på Instagram**. Log ind som normalt (inkl. 2FA). Din nuværende bio gemmes som standard-bio.

## Første test (fase 0)
1. **Øve-tilstand** er slået til fra start. Prøv hele rutinen uden at røre Instagram.
2. Slå øve-tilstand fra i ⚙︎. Brug gerne en tom test-konto første gang.
3. Skriv et ord i feltet `ord`, og tryk **Afslør i bio**. Loggen viser "bekræftet", når Instagram har den nye bio.
4. Tjek på en anden telefon, hvor hurtigt den nye bio kan ses.
5. Tryk **Nulstil bio**.

Virker "Kun bio" ikke, prøver "Auto" selv "Profil-formular". Fejl står i ⚙︎ → Diagnose (tag et screenshot).

## Rutine (eksempel)
1. Fake Google på din telefon, samme rum-kode som i Bio. Bio kører i baggrunden.
2. Tilskueren søger på en by, fx "Bornholm".
3. Bio får ordet (du mærker en notifikation / ser den på uret) og afslører selv, hvis *Afslør selv* er slået til.
4. "Find mig på Instagram." Bioen siger: `✨ Ordet du tænker på: Bornholm`.
5. Bagefter nulstilles bioen automatisk efter det valgte antal minutter, eller med **Nulstil bio**.

## Skabeloner
- Felter: `{ord}`, `{kort}`, `{tal}`, `{navn}` eller hvad du vil.
- Filtre: `{ord|titel}`, `{ord|stor}`, `{kort|kort}` (kh → hjerter konge), `{kort|kortikon}` (kh → K♥️), `{tal|tal}`.
- Flere felter i én bio: `🃏 {kort|kort} · 🔢 {tal}`.
- Maks 150 tegn. Tælleren viser det.

## Relæ
Samme relæ og rum-kode som Noter+, Calc+ og Fake Google. Hvert felt har en kilde (sti i rummet), fx `ord ← google.q`. Andre apps kan også sende `{"insta":{"cmd":"reveal","at":<ms>}}` eller `"reset"`.

## Risiko
Instagram har ingen officiel måde at ændre bio på. Appen bruger de samme kald som instagram.com. Det er imod Instagrams vilkår, og kontoen kan i værste fald blive låst. Hold antallet af ændringer nede (appen venter mindst 15 sek. mellem to).

## Tjek før show
- Øve-tilstand **fra**, logget ind (⚙︎ → Test forbindelse).
- Standard-bio ser naturlig ud.
- Relæ: grøn prik. Hold kørende i baggrunden: til.
- Fokus/Forstyr ikke: notifikationer fra Bio må gerne komme igennem (de er din peek).
- Out: virker Instagram ikke, afslør i Noter+.
