# Ce face o cumpărare să pară un eveniment

Owner-ul, după playtest: upgrade-urile "sunt aruncate acolo — calci pe ele când ai bani". Înainte de
research am citit codul curent (`PadController.luau`, `SceneArt.Flourish`, `SoundController.luau`,
`CeremonyController.luau`, `Overlay.luau`, `GuideController.luau`) ca să știu exact ce lipsește, nu
doar ce fac alții — diagnosticul e la punctul 5 și explică reclamația.

## 1. Tycoons pe platformă/buton (Roblox)

Restaurant Tycoon 2 rămâne cel mai bine cotat tycoon Roblox în 2026 (mobi.gg, „top 14 of 2026",
accesat 2026-09-12); upgrade-urile trec prin meniul Restaurant Management, iar reclama crește
explicit „popularitatea" — un efect numit, nu doar un preț plătit (restaurant-tycoon-2.fandom.com/
wiki/Upgrades, accesat 2026-09-12, prin sinteză motor de căutare — încredere medie). Miner's Haven
arată în magazin listă cu imagine + descriere + preț + un slider 1-99 de cumpărare multiplă per
dropper/upgrader (minershaven.fandom.com/wiki/Shop, accesat 2026-09-12; încredere medie, fandom
blocat direct HTTP 402, ca și în notele 19/21). Bee Swarm Simulator vinde Gumdrops în trepte fixe
3/30/300, nu bucată cu bucată (bee-swarm-simulator.fandom.com/wiki/Gumdrop_Shop, accesat
2026-09-12). Pentru Theme Park Tycoon 2 și Pet Simulator 99, feedback-ul exact la cumpărare: NEVERIFICAT — surse
doar generice. Nu există clasament public oficial de „top grossing" pe joc; cel mai apropiat proxy e
popularitatea din liste editoriale și CCU — Steal a Brainrot (tycoon-adjacent), 25,4-25,8M CCU în
oct. 2025, deja documentat în nota 19.
Relevant ca anti-exemplu: un kit generic de tycoon vândut pe DevForum (folosit ca bază pentru mulți
tycoons mici) anunță explicit doar etichete de preț, sunete, dependențe între butoane și butoane
premium (devforum.roblox.com/t/a-very-advanced-kit-for-tycoons-ruixeys-tycoonkit/1850596, accesat
direct 2026-09-12) — nimic despre cameră, ecran sau text de efect. Exact profilul „funcțional dar mut".

## 2. Niveluri și meniu, nu buton unic

Game UI Database (peste 1.300 de jocuri, 55.000 capturi) confirmă tiparul dominant pentru ecranele
de upgrade: nivel curent vs. următor și efect curent vs. următor arătate alăturat, cost vizibil
înainte de confirmare (gameuidatabase.com/index.php?scrn=73, accesat direct 2026-09-12; încredere
medie — descriere sintetizată automat, nu HTML citit brut). „Buy Max"/„hold to buy" e o cerință
recurentă de comunitate în jocurile idle (ex. IdleOn, steamcommunity.com/app/1476970/discussions/2/
3450339739939006250, accesat 2026-09-12) — utilă doar la niveluri repetabile, nu la pad-uri unice
ca la noi azi.

## 3. Clash of Clans

Atingi clădirea → card de upgrade cu cost și durată; un buton „Finish Now" oferă finalizare instant
cu gemme (clashofclansuser-guide.blogspot.com; sportskeeda.com/esports/how-upgrade-clash-clans-clan-
capital-building-costs-and-more; accesate 2026-09-12). Atingerea iconiței constructorului arată ce
se construiește acum ȘI o listă de construcții sugerate — un „ce fac în continuare" integrat în UI,
nu doar o săgeată; constructorul inactiv stă vizibil „odihnindu-se" la Builder Hut — starea lui de
liber e un obiect din lume, nu text (clashofclans.fandom.com/wiki/Builder, prin sinteză motor de
căutare, fandom blocat direct HTTP 402; încredere medie).

## 4. Ce cumperi în continuare, fără perete de text

Recomandarea „sugerat" din CoC (pct. 3) e cel mai apropiat precedent extern pentru arhitectura pe
care Driftycoon o are deja: `GuideController.luau` arată UN SINGUR obiectiv deodată (săgeată din
lume + indicator de margine + text), amânat 11s dacă jucătorul tot progresează. Documentația oficială
Roblox confirmă independent aceeași ordine de prioritate — elemente vizuale înaintea textului
(create.roblox.com/docs/production/game-design/onboarding-techniques, actualizat 2026-09-03, deja
verificat în nota 24). Ce lipsește nu e „un ghidaj", ci diferențierea vizuală a pad-urilor: azi orice
platformă viitoare (stare „outline") arată identic — doar numele, fără preț sau pictogramă
(`PadController.styleOutline`) — indiferent dacă e următoarea sau a treia din coadă.

## 5. Anti-patternuri

Supraaglomerarea UI e citată constant ca sursă de confuzie în ghidurile de UX mobil (games.
themindstudios.com; medium.com/@etiennebadia/the-problems-with-ui-design-in-mobile-games-dev;
accesate 2026-09-12; încredere medie, surse secundare). Cel mai clar anti-pattern găsit e chiar în
codul nostru: `Overlay.luau` leagă `CeremonyController.Play` de FIECARE `PadBought`, dar
`CeremonyController.Play` iese tăcut dacă `pad.motive ~= "D"` — deci 44 din cele 48 de platforme
(toate în afara celor 4 clopote) nu ating niciodată banner-ul, rafala de monede sau cele 3 secunde
de ceremonie deja construite (`JuiceController.Burst`, deja scris). Restul feedback-ului per
cumpărare e un singur sunet („build") și un pop de 650ms pe pad (`SceneArt.Flourish`) — fără cameră,
fără text de efect, identic la 9 monede și la 200.000. Ăsta e, găsit în cod, motivul exact al
reclamației owner-ului — canonic descris drept lipsă de „juice" (Jonasson & Purho, „Juice It or Lose
It", Nordic Game Jam, mai 2012; gdcvault.com/play/1016487, accesat 2026-09-12).

## Ce facem la Driftycoon

Ordonat după impact/oră.

1. **Lărgește gate-ul din `CeremonyController.Play`** (azi `pad.motive ~= "D"`) la o versiune SCURTĂ
   (900-1200ms, fără cele 3s de banner) pentru orice pad cu motiv V/C care e ținta curentă a
   `GuideController` — reutilizează `JuiceController.Burst` deja scris, cu `count=4-6` în loc de 12.
   Zero cod nou, doar o condiție și un apel. Cel mai mare impact/oră posibil.
2. **Adaugă „+0.4/s" zburător** — delta de `incomePerSec` față de starea anterioară (deja calculată
   server-side de `TycoonMath`), zburând de la pad spre cifra de venit din HUD la fiecare
   `PadBought`, pe tiparul `JuiceController.CoinFly` cu altă țintă. Răspunde direct la „ce a făcut
   banul meu" — lipsește complet azi.
3. **3 trepte de sunet „build"** (preț <100 / 100-5.000 / >5.000): pitch sau variantă diferită;
   `sfx_build.ogg` există deja ca asset, `SoundController.Play` acceptă deja `pitch`. Sub o oră.
4. **Extinde `PadController.styleOutline`** să arate prețul (gri) și pictograma efectului, nu doar
   numele — reduce misterul platformelor viitoare fără text în plus.
5. **Un „punch" mic de cameră** (offset 6-10px, 150-250ms, easing Back — rețeta exactă e în
   docs/research/11-juice-effects.md secțiunea 2) doar la cumpărături peste ~500 monede, ca să nu
   obosească la fiecare Second Net de 9.
6. **La `PadRejected` cu motiv „coins"**, arată suma exactă care lipsește („Need 42 more"), nu doar
   „Not enough coins" — un calcul, nu un string nou; ține de regula D40 (textul nu minte).
7. **Pulsul pad-ului afordabil** (`styleAvailable`) să se strângă ușor cu timpul (tween-ul de la
   0,7s spre ~0,4s după 15-20s neatins) — nudge ieftin pentru ce jucătorul poate cumpăra dar ignoră.
8. **Leagă viitorul `ZoneController`** de `PadBought` pe cele 4 clopote, ca gardul zonei următoare
   să se lumineze exact în cele 3 secunde de ceremonie — C5 cere asta explicit în plan.
9. **Prima apariție „available" a unei stații** (Sawmill, Smelter etc.) arată o dată un rând sub
   preț („+3 coins/s per driftwood"), apoi dispare — preview de efect, ca la cardul CoC, fără să
   aglomereze pad-urile deja cunoscute.
10. **„Buy max"/hold-to-buy: amână.** Nu se aplică cât pad-urile sunt unice, nu niveluri repetabile;
    revine când apar stații cu niveluri (Sawmill II, F3+) — notat aici ca să nu se piardă decizia.

## Surse

- mobi.gg — „Roblox best tycoon games: the top 14 of 2026" — accesat 2026-09-12
- restaurant-tycoon-2.fandom.com/wiki/Upgrades — accesat 2026-09-12 (sinteză, fandom indirect)
- minershaven.fandom.com/wiki/Shop — accesat 2026-09-12 (sinteză; acces direct blocat HTTP 402)
- bee-swarm-simulator.fandom.com/wiki/Gumdrop_Shop — accesat 2026-09-12
- devforum.roblox.com/t/a-very-advanced-kit-for-tycoons-ruixeys-tycoonkit/1850596 — accesat direct 2026-09-12
- gameuidatabase.com/index.php?scrn=73 — accesat direct 2026-09-12
- steamcommunity.com/app/1476970/discussions/2/3450339739939006250 — accesat 2026-09-12
- clashofclansuser-guide.blogspot.com/2017/06/user-guide-clash-of-clans.html — accesat 2026-09-12
- sportskeeda.com/esports/how-upgrade-clash-clans-clan-capital-building-costs-and-more — accesat 2026-09-12
- clashofclans.fandom.com/wiki/Builder — accesat 2026-09-12 (sinteză; acces direct blocat HTTP 402)
- create.roblox.com/docs/production/game-design/onboarding-techniques — actualizat 2026-09-03 (verificat și în nota 24)
- games.themindstudios.com — accesat 2026-09-12
- medium.com/@etiennebadia/the-problems-with-ui-design-in-mobile-games-dev — accesat 2026-09-12
- gdcvault.com/play/1016487/juice-it-or-lose — „Juice It or Lose It", Jonasson & Purho, mai 2012 — accesat 2026-09-12
- docs/research/11-juice-effects.md, docs/research/19-case-fisch-gag.md, docs/research/24-onboarding-ftue.md — note interne, citite pentru context
- Cod propriu citit pentru diagnostic: `src/Client/Controllers/PadController.luau`, `SceneArt.luau`, `SoundController.luau`, `CeremonyController.luau`, `Overlay.luau`, `GuideController.luau`, `src/Server/Services/PadService.luau`
