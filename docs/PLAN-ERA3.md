# Planul de construcție al Erei 3, „The Wire Works" [D67]

**Aprobat de owner pe 2026-09-21** („Da, construiește-o", cu **Depot și Clerk**). Schema și cifrele sunt în DECIZII D67;
derivarea s-a făcut întâi în `scripts/economy/sim_era3.py`, iar la pasul 1 Era 3 intră în `sim_tycoon.py`. Fișierul ăsta
ține ordinea de lucru și ce e făcut, ca să se poată relua după o pauză. Fiecare pas se termină cu poarta verde, commit și
push.

**Regulile care țin toată construcția** (aceleași ca la Moară, `docs/PLAN-ERA2.md`):
- **Era 1 și Moara nu se schimbă.** Prețurile lor (verificate de simulator față de config), tabelele de aur, profilurile
  existente. Ieșirea simulatorului pentru primele două ere rămâne bit cu bit aceeași.
- **Nimic scris a treia oară.** Unde Moara a primit cod anume (`run_era2`, `check_run_era2`, `netEraMult` cu două
  ramuri, `StateFrom` cu `water_wheel`), codul devine tabel pe ere, iar Moara trece pe același tabel. A patra eră trebuie
  să fie doar rânduri.
- **Arta întâi pe planșe**, apoi urcată cu acordul owner-ului. Până atunci, Era 3 împrumută desenele Morii (Wire Works
  pe al turnătoriei, Depot pe al Pieței, turbina pe al plasei).
- **Serverul n-are teste Lune.** Tot ce ține de servicii se verifică într-un Play de probă (`scripts/probe.py`).

## Numele (din D67)

| Ce | Moara | Era 3 |
|---|---|---|
| poarta erei | Water Wheel (`water_wheel`, `wheel`) | Steam Engine (`steam_engine`, `steam`) |
| plasele | Sixth…Tenth Net (`mill`, `ore`) | Eleventh…Fourteenth Net (`works`), First Turbine (`turbine`) |
| magazia | Mill Store | Works Store |
| atelierul | Foundry (`foundry`) | Wire Works (`wireworks`) |
| vânzătorul | Market (`market`), Merchant | Depot (`depot`), Clerk |
| linia întâi | `parts`: scrap → piese de mașini | `coils`: minereu de cupru → bobine |
| atelierul târziu | Copper Furnace (`furnace`) | Power House (`powerhouse`) |
| magazia târzie | Ore Shed | Battery Shed |
| linia târzie | `copper`: minereu → cupru | `power`: baterii → celule de energie |
| oamenii | Mill Collector, Mill Porter, Founder, Parts Hauler, Merchant, Ore Collector, Ore Porter, Coppersmith, Copper Hauler | Works Collector, Works Porter, Wiredrawer, Coil Hauler, Clerk, Battery Collector, Battery Porter, Electrician, Power Hauler |
| clopotul | Mill Bell | Works Bell |

## Pașii

| # | Ce | Stare |
|---|---|---|
| 1 | **Simulatorul și configul pur.** Era 3 în `sim_tycoon.py`; funcțiile Morii devin funcții pe eră (rulare, porți, raport, `--robust`, absența de o noapte, id-urile platformelor). `StationConfig` (cadrul, liniile, clădirile, oamenii), `ChainMath` / `CrewMath` (înmulțitorul pe eră, câmpurile stării), tabelul de aur cu stări de Era 3 | **făcut** (2026-09-21): `run_era` / `check_run_era` / `report_era` / `robust_era` / `era_mult` pentru orice eră (cele ale Morii au rămas ca învelișuri); `StationConfig.ERA_MULT`, `ERA_ROLES`, `ERA_OF_ROLE`, liniile `coils` / `power`, Depoul; `ChainMath.netEraMult` pe tabel; 10 stări de aur pentru Era 3 (`golden_chain.py --era3`). Era 1 și Moara ies bit cu bit la fel: ieșirea simulatorului, tabelele de aur, `sim_era2.py`, `tune_tycoon.py`. Bateria valorează 3,5 × cadrul (preț exact) |
| 2 | **Platformele și oamenii în `TycoonConfig`:** marfa, `CATCH`, cele 18 platforme cu preț (verificat de simulator), loc pe hartă și condiții, `CREWS`, geometria cartierului | **în parte** (2026-09-21): marfa și `CATCH`, desenele de împrumut (`GOOD_LOOKS_LIKE`, `PAD_LOOKS_LIKE`), cele 18 platforme (`live = false`, prețuri verificate de simulator, locuri cu `WORKS_DX`), `CREWS`, `LINE_PLACES` / `SELLER_PLACES` / clădirile fixe. **Rămâne:** cartierul în `DISTRICTS` (puntea, drumurile, curțile), odată cu harta (5a) |
| 3 | **Vederea generică pentru client:** ce a rămas pe două cartiere în `HeldBack`, meniuri, panoul Upgrades | **în parte** (2026-09-21): cuvintele lanțului (`LINE_WORDS`, `LINK_WORDS`, `NET_WORDS` cu `verb` pentru turbină, `BUILDING_WORDS`), `crewDoes`, `CREW_HELLO`, motivele de refuz; `QuestMath.stationTarget` pe orice vânzător. **Rămâne:** ce mai e scris pe două cartiere în meniuri și panouri (de văzut cu sonda) |
| 4 | **Serverul:** profil v17 (clădirile, grămezile și oamenii Erei 3), `StationService.StateFrom` pe tabel, drumul mărfii (`FlowConfig`), `HandRoutes`, `padStatuses`, zonele | **în parte** (2026-09-21): profil v17 (`ProfileMigrate.toV17` și șablonul), `FlowConfig` (bobinele, curentul, Depoul), `QuestService` și `GuideMath` iau numărătorile din `FlowConfig`, `TycoonMath.era` numără doar platformele `live`. `StationService`: clădirile, rândurile panoului și steagurile liniilor se derivă din `FlowConfig` / `StationConfig` (nu mai sunt liste scrise de mână); zonele din `NetServer` se deschid cu clopotul erei dinainte, pe tabel. **Rămâne:** drumul mărfii, oamenii și nivelurile jucate cu sonda |
| 5a | **Harta:** lumea mai lată, zona `wire_works` deschisă, `dam` anunțată, decorul, a treia felie de pământ copt | **făcut** (2026-09-21): lumea are 5520 (`RiverConfig.WORLD_WIDTH`), malul amenajat și terenul fără decor merg până la 5320, zona `wire_works` e 3560–5240 (deschisă de Mill Bell, estompată cu „coming soon" cât Era 3 nu e în joc), `dam` e anunțată. Cartierul `works` stă în `TycoonConfig.DISTRICTS` (se desenează abia când e în joc). **Nimic din ce s-a văzut nu se mută:** decorul și smocurile/pietricelele pământului copt se împrăștie pe fâșii fixe, fiecare cu sămânța ei (`RiverConfig.DECOR_STRIPS`, test); recoacerea locală lasă satul identic la pixel și Moara identică până la x 3600. A doua felie coaptă are acum 880 px, **neurcată**: `SceneArt` desenează felia urcată doar pe lățimea ei nativă și pune dale în rest. Nu e nevoie de o a treia felie (a doua acoperă 2880–5760) |
| 5 | **Clientul:** clădirile fixe, turbina (se învârte și umple baterii, nu prinde din râu), colibele, clienții Depoului, felinarele care se aprind, macheta din bâlci | **scris** (2026-09-21), cu desene de împrumut: Works Store, Wire Works și Depot prin `LineController` (cu hornurile lor); `PadArt` caută desenul pe tot lanțul de perechi (Era 3 → Moara → Era 1), Steam Engine poartă cuptorul de cupru; turbina e roata de apă a Morii, fără bușteni care plutesc spre ea (`NetController`); numele Power House pe acoperiș; refuzul unui vânzător numește vânzătorul potrivit din traistă, iar „Sack full" trimite și la Depot; macheta din bâlci desenează și Wire Works. Ținutele de împrumut, 20 de prenume în plus. **Rămâne:** felinarele (cu arta lor, la pasul 7) și verificarea cu sonda |
| 6 | **Quest-urile și ghidajul:** capitolele 7–9, bucla de mână a cartierului, textele | **în parte** (2026-09-21): capitolele 7–9 („The Wire Works", „Miles of Wire", „The Power Line"), în joc doar când Era 3 e `live`; turbina „se construiește" (`TycoonConfig.verbOf`). **Rămâne:** bucla de mână a cartierului în ghidaj, verificată cu sonda |
| 7 | **Arta pe planșe**, apoi urcată cu acord | **desenată** (2026-09-21), **așteaptă aprobarea owner-ului**: 57 de imagini în `assets/sprites`. `scripts/art/d67_works.py` face 7 clădiri, 7 ruine, turbina, bobinele, bateria, celula și felinarul stins / aprins / lumina lui. `scripts/art/d67_crew.py` face 16 colibe, taraba Clerk-ului, 3 încărcături și 3 grămezi. `settlers.py` face 9 ținute. Wire Works e fier nituit, sticlă, alamă și portelan, cu lumina albastră a curentului; linia curentului are ardezia ei și paratrăsnete. Intrările din `Assets` există cu ID 0. Planșele se refac cu `python3 scripts/art/preview_d67.py`. **Rămâne:** urcarea (cu acord), pământul recopt cu cartierul Wire Works (odată cu `live`), felinarele în joc |
| 8 | **Era 3 jucată cu sonda**, pe profil de probă, cap-coadă; apoi de owner | de făcut |
