# Planul de construcție al Erei 2, „The Mill" [D65]

**Aprobat de owner pe 2026-09-19** („confirm. poți să te apuci"). Schema și cifrele sunt în DECIZII D65; economia iese din
`scripts/economy/sim_tycoon.py` (Era 2 e acolo de la pasul 1). Fișierul ăsta ține ordinea de lucru și ce e făcut, ca să
se poată relua după o pauză. Fiecare pas se termină cu poarta verde, commit și push.

**Regulile care țin toată construcția:**
- **Era 1 nu se schimbă.** Prețurile ei (verificate de simulator față de config), tabelul de aur și profilurile existente.
- **Nimic scris a doua oară de mână.** Unde Era 1 are o funcție pe clădire (`UseShed` / `UseForge`, `ShedSnapshot` /
  `ForgeSnapshot`, `routeFor` cu un `elseif` pe meserie), Era 2 NU primește o copie: codul devine tabel (cartierul,
  linia, clădirea), iar Era 1 trece pe același tabel. Altfel Era 3 ar fi a treia copie.
- **Arta întâi pe planșe**, apoi urcată cu acordul owner-ului. Până atunci, clădirile Erei 2 împrumută desenele Erei 1
  (turnătoria pe al gaterului, Piața pe al tavernei), ca jocul să se poată juca și verifica cu sonda.
- **Serverul n-are teste Lune.** Tot ce ține de servicii se verifică într-un Play de probă (`scripts/probe.py`).

## Harta

Lumea avea 2880 × 1920. Era 1 ține x 240–1860; `TycoonConfig.ZONES[2]` („mill", x 1860–2880) e deja rezervat, cu ceață,
gard și panoul „The Mill — coming soon". Cartierul Morii are nevoie de cam cât Era 1 (~1600 px), deci lumea se lățește
la **3840** (`RiverConfig.WORLD_WIDTH`). Pământul copt e o imagine de 960 × 640 (3 px de lume pe pixel), iar Roblox
micșorează orice imagine peste 1024: pământul se coace deci **pe felii de 2880 px** (`prop_village_ground`,
`prop_village_ground_2`). Ambele felii se recoc (drumurile Morii intră și în prima) și se urcă din nou, cu acord.

## Pașii

| # | Ce | Stare |
|---|---|---|
| 1 | **Simulatorul și configul pur.** Era 2 în `sim_tycoon.py` (linii, clădiri, oameni, deblocări, porți, `--robust`), `StationConfig` (cadrul M = 40, plase pe ere, roluri, linii, Piața), `ChainMath` (câmpurile stării, `netBase` / `netUpgradeBase` pe ere, `tierCost` pe rol), tabelul de aur cu stări de Era 2 | **făcut** (2026-09-19): Era 1 neschimbată (prețuri, tabel de aur), 12 stări de aur pentru Era 2, `--robust` pe constantele Morii |
| 2 | **Platformele și oamenii în `TycoonConfig`:** marfa (`mill_scrap`, `parts`, `ore`, `copper`, găsirile erei), `CATCH`, cele 18 platforme cu preț (verificat de simulator), loc pe hartă și condiții, `CREWS` pentru cele 9 meserii, geometria cartierului (punte, drumuri, curți, locurile grămezilor) | **făcut** (2026-09-19): cele 18 platforme au loc prin `MILL_DX` și condiții în lanț; geometria stă în `TycoonConfig.DISTRICTS`, `LINE_PLACES`, `SELLER_PLACES` |
| 3 | **Vederea generică pentru client.** `StationService.Snapshot` trimite, pe lângă vederea plată a Erei 1, `lines` (pe linie: prins, livrat, veriga slabă), debitul fiecărei verigi și veriga care ține venitul fiecărui cartier; `HeldBack`, `StationMenu` și `StationPanel` se derivă din `StationConfig` | **făcut** (2026-09-19): `HeldBack` pe vederea generică (taverna nu trimite la turnătorie), `ChainMath.eraBottleneck`, cuvintele lanțului ca tabele în `Strings` (textele Erei 1 ținute literă cu literă de `tests/ChainWords.test.luau`), panoul Upgrades pe cartier |
| 4 | **Serverul.** Profil v16 (`Stations.foundry / .market / .furnace`, grămezile Morii, treptele celor 9 meserii); `EconomyService` pe tabel de cartiere (magazie → atelier → vânzător), cu Era 1 pe același tabel; `StationService` (`StateFrom`, `LevelOf`, `UpgradeBase`, rândurile clădirilor); `HandRoutes` / `HandService` pe tabel; remote-urile locurilor; `TycoonMath.padStatuses` (Era 2 se deschide cu Landing Bell) | **făcut** (2026-09-19): drumul mărfii e tabel (`FlowConfig`, `FlowMath`), `EconomyService` merge peste el cu numele vechi ca înveliș; profil v16; `StationService` după tabel; `HandRoutes` / `HandService` fără `elseif` pe meserie; `TycoonState.flow`; `Sold` cu vânzătorul; remote-urile `UsePlace` / `AtPlace` cu ambele capete |
| 5a | **Harta.** `RiverConfig.WORLD_WIDTH = 3840`, zonele (`mill` 1860–3560, `wire_works` doar anunțată), `ZoneController` pe oricâte zone, decorul și pământul copt pe cartiere și pe felii | **făcut** (2026-09-19). Împrăștierea smocurilor și a pietricelelor are acum zarul ei la fiecare încercare: un cartier nou nu mai mută nimic din cele coapte deja (12 pixeli diferență în satul vechi, față de 567) |
| 5 | **Clientul.** clădirile cartierului din controllere generalizate; oamenii pe drumurile noi; plasele și ce plutește pe râu; meniurile și panoul Upgrades pe cartier; copierea câmp cu câmp din `Bootstrap` | **făcut** (2026-09-19): `LineController` (magazie, atelier cu inel, vânzător, după tabel), `PadArt` cu desenele perechii din Era 1 (`TycoonConfig.PAD_LOOKS_LIKE`), `PadController` fără „Era 1" bătut în cuie, râul promite marfa liniei următoare, traista plină trimite la atelierul sau la vânzătorul potrivit, oamenii noi se prezintă, macheta satului vizitat din bâlci desenează și Moara. Piața are clienții ei (2026-09-20): mulțimea tavernei s-a mutat întocmai în `UI/CustomerCrowd`, locurile stau în `TycoonConfig.SELLER_PLACES` (ale Pieței, mutate cu `MILL_DX`), iar cine cumpără de la Piață pleacă cu o piesă în brațe. **Rămâne:** controllerele Erei 1 n-au trecut pe `LineController` |
| 6 | **Quest-urile și ghidajul:** capitolele 4–6, `QuestMath`, `GuideMath.loopStep` pe cartier, textele | **făcut** (2026-09-19): capitolele „The Mill", „Full Stream", „The Copper Line", în oglinda Erei 1 (în joc intră doar capitolele erelor `live`); bucla de mână a Morii din tabele, lângă perechile ei din Era 1; săgeata roții de apă vine și când ghidajul tace; ținta fără sfârșit alege rândul care aduce cel mai mult |
| 7 | **Arta pe planșe**, apoi urcată cu acord: roata de apă, turnătoria, Piața, cuptorul de cupru, magazia de minereu, ruinele lor, nouă ținute, colibele, pictogramele mărfii (piesă, minereu, cupru), încărcăturile roabei, cele două felii de pământ | **făcut, urcat** (2026-09-21, cu acordul owner-ului pe planșe): 50 de imagini (`scripts/art/d65_mill.py`, `d65_crew.py`, 9 ținute în `settlers.py`) și cele două felii de pământ recopt, **52 din 52 aprobate de moderare**; ID-urile sunt în `Assets`, `BAKED_DISTRICTS.mill = true`. Codul încearcă întâi desenul propriu și cade pe cel al perechii din Era 1 doar dacă lipsește (`UI/GoodArt`, `PadArt`, `LineController`, `HandConfig.OUTFIT_LOOKS_LIKE`); tabelele de împrumut au rămas ca plasă de siguranță. Planșele se refac cu `python3 scripts/art/preview_d65.py` |
| 8 | **Era 2 jucată cu sonda**, pe profil de probă, cap-coadă; apoi de owner | **făcut cu sonda** (2026-09-19), prin aceleași cereri ca butoanele jocului: clopotul Erei 1, roata de apă, turul de mână (plasă → turnătorie, stat în inel → Piață), cei cinci oameni, plasele, cuptorul, turul cuprului, magazia, cei patru oameni, clopotul Morii; niveluri, trepte și al doilea om pe drumul adevărat. Fără erori. **Platformele Erei 2 sunt `live`.** Ce nu vede sonda cu fereastra Studio ascunsă: cardurile de lângă obiecte și cartonașele platformelor (merg pe `PreRender`), animațiile, așezarea textelor. Rămâne owner-ul |

## Unelte noi pentru verificat Era 2

- `python3 scripts/probe.py dev "chapter:4"` aduce profilul de probă la începutul capitolului 4 (Era 1 terminată, clopotul
  tras, quest-urile revendicate); `chapter:6` la linia cuprului, `chapter:7` la sfârșit. Doar pe profil de probă.
- `dev "up:foundry 3"`, `dev "up:net:sixth_net 2"`: niveluri pe drumul adevărat (`StationService.Upgrade`).
- `client "ui:panel:foundry"`: lista Upgrades pe rândul unei stații (trece singură pe cartierul ei).
- `client "ui:goto:2660:1405"`: mută omul într-un loc de pe teren. Cardurile se văd doar cu fereastra Studio la vedere.

## Ce s-a hotărât pe drum

- **Plasele Morii prind tot scrap** (regula owner-ului: pornești cu marfa pe care o știi), dar e altă marfă în grămezi
  (`mill_scrap`): merge la turnătorie și se vinde ca piese de mașini, de 40 de ori mai scumpe decât scândura.
- **Găsirile cartierului nou** valorează și ele de 40 de ori mai mult (`named2`), ca media unei bucăți să rămână în
  oglindă cu Era 1 (66 și 142 de monede).
- **Numele verigilor:** `millCollect`, `millPort`, `foundry`, `partsHaul`, `oreCollect`, `orePort`, `furnace`,
  `copperHaul`, `market`. Liniile: `parts`, `copper`. Felurile plaselor: `mill`, `ore`.
- **Liniile de probă** din `check_lines.py` și din suita „liniile ca date" se numesc `probeA` / `probeB` / `stall`, ca să
  nu se ciocnească de cele adevărate.
- **Era 2 a intrat în joc cu desene de împrumut** (2026-09-19): fiecare platformă a Morii poartă desenul perechii din
  Era 1, clădirile fixe la fel (magazia pe al depozitului, turnătoria pe al gaterului, Piața pe al tavernei), marfa la
  fel (`GOOD_LOOKS_LIKE`), oamenii poartă ținuta meseriei-pereche. Totul se schimbă dintr-un singur loc când vine arta.
- **O eră intră în joc întreagă sau deloc** (test): cu jumătate din platforme `live`, clopotul ei n-ar putea fi tras.
- **Clopotul Morii spune „Every sale pays 10% more"**, nu „The Mill pays…": factorul `bells` e unul pentru tot satul, ca
  în simulator. Iar bannerul „X is open" apare doar dacă zona următoare chiar are ce juca în ea.
- **Oamenii au prenume unice în sat:** 18 meserii cu câte doi oameni nu mai încap în bazinul de 16 prenume.
- **Ce a arătat prima privire a owner-ului în Studio (2026-09-21)** și ce s-a reparat: Moara părea o copie a satului
  (desenele de împrumut: bușteni în Mill Store, pânza de gater la Foundry, roata norocului în locul roții de apă) și
  avea o dungă în iarbă unde se termina felia veche de pământ: arta și pământul recopt au fost urcate; trei copaci
  acopereau numele colibelor Morii: decorul împrăștiat nu mai are voie peste casele cartierelor noi
  (`TycoonConfig.homeClearRects`, `WorldDecor.village`; satul vechi e neschimbat, cu test); panoul „The Wire Works"
  ieșea din lume: semnul unei zone încape acum în zona lui; cuptorul de cupru își poartă numele pe acoperiș, ca forja;
  roata de apă stă în râu, cu baza la marginea punții (`PadArt.ART_OFFSET`), nu peste scânduri.
- **[D66, 2026-09-21] O singură monedă, Moara pe scara x3000.** Owner-ul a cumpărat toată Era 2 cu banii unei absențe
  și a respins banii separați pe cartiere. Moara valorează acum de 3000 de ori satul, a șasea plasă e gratis, scara de
  așteptare a Erei 2 pornește la 7,5, iar satul lucrează fără tine 8 h (16 h cu Long Nights). O noapte de la finalul
  Erei 1 plătește doar începutul Morii (8 din 26 de deblocări). Detaliile, în DECIZII D66.
