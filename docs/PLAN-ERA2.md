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

Lumea are 2880 × 1920. Era 1 ține x 240–1860; `TycoonConfig.ZONES[2]` („mill", x 1860–2880) e deja rezervat, cu ceață,
gard și panoul „The Mill — coming soon". Cartierul Morii are nevoie de cam cât Era 1 (~1600 px), deci lumea se lățește
la **3840** (`RiverConfig.WORLD_WIDTH`). Pământul copt e o imagine de 960 × 640 (3 px de lume pe pixel), iar Roblox
micșorează orice imagine peste 1024: pământul se coace deci **pe felii de 2880 px** (`prop_village_ground`,
`prop_village_ground_2`). Ambele felii se recoc (drumurile Morii intră și în prima) și se urcă din nou, cu acord.

## Pașii

| # | Ce | Stare |
|---|---|---|
| 1 | **Simulatorul și configul pur.** Era 2 în `sim_tycoon.py` (linii, clădiri, oameni, deblocări, porți, `--robust`), `StationConfig` (cadrul M = 40, plase pe ere, roluri, linii, Piața), `ChainMath` (câmpurile stării, `netBase` / `netUpgradeBase` pe ere, `tierCost` pe rol), tabelul de aur cu stări de Era 2 | **făcut** (2026-09-19): Era 1 neschimbată (prețuri, tabel de aur), 12 stări de aur pentru Era 2, `--robust` pe constantele Morii |
| 2 | **Platformele și oamenii în `TycoonConfig`:** marfa (`mill_scrap`, `parts`, `ore`, `copper`, găsirile erei), `CATCH`, cele 18 platforme cu preț (verificat de simulator), loc pe hartă și condiții, `CREWS` pentru cele 9 meserii, geometria cartierului (punte, drumuri, curți, locurile grămezilor) | **în parte:** marfa, `CATCH`, cele 18 platforme (`live = false`, cu loc prin `MILL_DX`) și `CREWS` sunt în config, cu prețurile verificate de simulator; geometria cartierului vine cu harta (pasul 5) |
| 3 | **Vederea generică pentru client.** `StationService.Snapshot` trimite, pe lângă vederea plată a Erei 1, `lines` (pe linie: prins, livrat, veriga slabă) și debitul fiecărei verigi; `HeldBack`, `StationMenu.CHAIN` și `StationPanel.CHAIN_ROWS` se derivă din `StationConfig`, nu mai sunt scrise de mână | |
| 4 | **Serverul.** Profil v16 (`Stations.foundry / .market / .furnace`, grămezile Morii, treptele celor 9 meserii); `EconomyService` pe tabel de cartiere (magazie → atelier → vânzător), cu Era 1 pe același tabel; `StationService` (`StateFrom`, `LevelOf`, `UpgradeBase`, rândurile clădirilor); `HandRoutes` / `HandService` pe tabel; remote-urile locurilor; `TycoonMath.padStatuses` (Era 2 se deschide cu Landing Bell) | |
| 5 | **Clientul.** Lumea lățită și zona Morii deschisă; clădirile cartierului (magazia, turnătoria cu inelul ei, Piața cu clienți, cuptorul, magazia de minereu) din controllere generalizate; oamenii pe drumurile noi; plasele și ce plutește pe râu (scrap, minereu); meniurile și panoul Upgrades pe cartier; copierea câmp cu câmp din `Bootstrap` | |
| 6 | **Quest-urile și ghidajul:** capitolele 4–6 (roata și turul de mână, oamenii; plasele; cuprul și Mill Bell), `QuestMath` (fapte pe linie), `GuideMath.loopStep` pe cartier, textele | |
| 7 | **Arta pe planșe**, apoi urcată cu acord: roata de apă, turnătoria, Piața, cuptorul de cupru, magazia de minereu, ruinele lor, nouă ținute, colibele, pictogramele mărfii (piesă, minereu, cupru), încărcăturile roabei, cele două felii de pământ | |
| 8 | **Era 2 jucată cu sonda**, pe profil de probă, cap-coadă; apoi de owner | |

## Ce s-a hotărât pe drum

- **Plasele Morii prind tot scrap** (regula owner-ului: pornești cu marfa pe care o știi), dar e altă marfă în grămezi
  (`mill_scrap`): merge la turnătorie și se vinde ca piese de mașini, de 40 de ori mai scumpe decât scândura.
- **Găsirile cartierului nou** valorează și ele de 40 de ori mai mult (`named2`), ca media unei bucăți să rămână în
  oglindă cu Era 1 (66 și 142 de monede).
- **Numele verigilor:** `millCollect`, `millPort`, `foundry`, `partsHaul`, `oreCollect`, `orePort`, `furnace`,
  `copperHaul`, `market`. Liniile: `parts`, `copper`. Felurile plaselor: `mill`, `ore`.
- **Liniile de probă** din `check_lines.py` și din suita „liniile ca date" se numesc `probeA` / `probeB` / `stall`, ca să
  nu se ciocnească de cele adevărate.
