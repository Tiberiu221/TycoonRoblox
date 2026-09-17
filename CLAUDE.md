# Driftycoon — context de proiect

Citit automat la fiecare sesiune. Ține-l scurt: fiecare cuvânt de aici se plătește la fiecare pornire.

## Ce construim

Tycoon 2D pe Roblox, pe malul unui râu, așezat ca un sat pe flux [D57]. **Râul aduce → Collector-ul adună în depozit → Porter-ul duce
la gater → gaterul taie → Hauler-ul duce la tavernă → taverna vinde.** Venitul e **minimul
debitelor**; ce pas n-are om îl faci tu [D49]. Din Forge, a doua linie cu oamenii ei: **Fifth Net → Scrap
Collector → Scrap Shed → Scrap Porter → forja (Smelter) → Iron Hauler → tavernă**; liniile împart doar taverna
[D56]. Veriga cea mai slabă decide, iar repararea ei e decizia jucătorului [D46]. Clădirile au **niveluri fără capăt** (salt la 10/25/50), oamenii **trepte
1–5** și un al doilea om.
Fraza pentru jucător: *This stretch of river is yours. Everything that floats past is money.*

## Surse de adevăr, în ordine

1. `docs/TYCOON.md` — **planul**: 6 principii, regula celor patru motive, 22 de arii dezbătute,
   cele 48 de platforme, fazele F0–F9 și lista de sarcini. Aici se lucrează.
2. `docs/DECIZII.md` — registrul; e lege. D45 = pivotarea la tycoon și ce decizii vechi cad.
3. `scripts/economy/sim_tycoon.py` — **sursa cifrelor**. Prețurile nu se ghicesc și nu se editează de
   mână în plan: se reglează în simulator. Iese cu eroare dacă o platformă nu crește venitul.
4. `docs/research/` (37 note, index în README) și `docs/research-survival/` (24 note, index în README).

Arhivat, nu în proiect: masterplanul vechi, direcțiile concurente, documentele de colonie —
`~/Desktop/Driftwood_arhiva_2026-09-11/`. Etichetele `[MASTERPLAN x.y]` din comentariile de cod trimit acolo.

## Reguli de design care nu se negociază

- **Nimic nu se pierde.** Fără dezastre, fără furt, fără scădere; offline doar binevoitor.
- **Banii cumpără viteză, spațiu, aspect.** Niciodată noroc **care scade ceva ce ai** [D46]. Roata
  zilnică e gratuită, dă doar în plus, și își afișează șansele. Rotiri plătite nu există [D20].
- **Orice se cumpără** prinde mai mult, vinde mai scump, scapă de o corvoadă sau deschide ce urmează.
  **Nicio cumpărare nu scade venitul** — dar una care nu țintește veriga slabă poate să dea **zero**,
  și atunci ecranul spune de ce, nu inventează o cifră [D46, D40].
- **Nimic nu se întâmplă în tăcere** (D43); **textul nu minte** (D40); următorul pas se vede, nu se explică.
- Textul din joc în **engleză**; comentariile și conversația în **română**.

## Stack și reguli de cod

Roblox Studio (Apple Silicon), Luau, **2D pur în ScreenGui**, Rojo 7.7 · StyLua · selene · Lune.
`--!strict` pe fiecare modul; doar `task.*`. **Serverul e singura sursă de adevăr** pentru economie;
clientul trimite intenții pe RemoteEvent (niciodată RemoteFunction), cu validare de tip, `math.isfinite`,
ownership și limitare de rată. Module pure în `src/Shared/Modules` (primesc `now`, fără `game`).
Timp absolut (`finishAt`), niciodată „timp rămas". Râul e determinist pe seed [D13].

**Capcane cunoscute:** stylua șterge punctul-și-virgula din fața unei instrucțiuni care începe cu `(` —
restructurează cu un `local`. `BindableEvent` copiază tabelele — trimite identități. Câmpurile trimise de
server trebuie **copiate explicit** pe client (am pierdut de două ori nume/meserie/înfățișare așa).
Și invers: când serverul scoate sau redenumește un câmp, caută **toți** cititorii din client — în F0,
panoul atelierului a crăpat pe `s.materials` și nicio verificare statică nu l-a prins.
Fontul de pixeli (`display`/`strong`) are **0,56 em pe literă**: o frază de 41 de litere la mărimea titlului are 687 de
unități și iese din fereastră. Textul care se schimbă (sume, nume, bilete) trece prin `Theme.fitSize` sau se rupe pe
rânduri cu înălțimea din `Theme.textHeight`.

## Poarta, înainte de orice livrare

```
stylua --check src/ tests/ && selene src/ && lune run tests/_run.luau
rojo build default.project.json --output /tmp/check.rbxl
lune run scripts/check_requires /tmp/check.rbxl
rojo build fair.project.json --output /tmp/fair.rbxl        # [D60] balciul, place-ul al doilea
lune run scripts/check_requires /tmp/fair.rbxl
python3 scripts/economy/sim_tycoon.py --robust
python3 scripts/art/check_panel_rows.py
```
`rojo build` și `check_requires` **nu parsează Luau** — o eroare de sintaxă trece de ele; doar
stylua/selene o prind. Rulează-le mereu pe toate, nu înlănțuite după o eroare.

## Mod de lucru

- Agenții pe **Sonnet**, niciodată moștenind modelul principal. Le dai instrucțiuni clare, apoi
  **verifici tu** în cod ce raportează — au greșit de mai multe ori.
- Dus la capăt singur, apoi o listă scurtă cu ce poate verifica doar owner-ul în Studio.
- **Commit și push după fiecare lucru terminat**, cu poarta verde înainte (owner, 2026-09-17: „fă commit și push
  mereu"; înainte era „fără commit fără cerere"). Repo privat `github.com/Tiberiu221/TycoonRoblox`, ramura `main`.
  CI-ul rulează poarta la fiecare push și scrie rezultatul pe ramura `ci-status` (citit prin SSH:
  `git fetch origin ci-status && git show FETCH_HEAD:status.txt`; jurnalul pașilor picați e în `failed.log`).
  **Publicarea pe staging** nu vine din CI: după toate semnele, `publish-staging` n-a publicat niciodată. Actualizările
  satului luate drept publicări erau salvări din Studio (editarea colaborativă salvează singură satul deschis), iar
  bâlciul a rămas gol de la creare. Se publică de pe Mac cu `python3 scripts/publish_staging.py`: poarta, build,
  publicare, verificare în `updateTime`. Scriptul folosește cheia de publicare din `~/.driftwood_publish_key`; cheia din
  `~/.driftwood_api_key` are drept doar pe imagini. Rularea lui e publicare, deci cere acordul owner-ului.
  **Nu trimite owner-ul în GitHub** (nu găsește Actions). Owner-ul vede satul prin `rojo serve` + Connect în Studio, iar
  bâlciul ca fișier local (`rojo build fair.project.json -o Balci.rbxl`, deschis în Studio, fără teleport și fără
  DataStore).
- Cheile API (`~/.driftwood_api_key`, `~/.driftwood_publish_key`) — niciodată în chat, în repo sau ca argument de
  comandă.
- **Rojo toarnă proiectul în orice fereastră Studio conectată** (așa a ajuns satul peste `Balci.rbxl` și în jocul
  accidental „The Fair", universul 10766663878). De aceea fiecare proiect are `servePlaceIds` (satul doar în 132381101591529,
  bâlciul doar în 114983498774894); serverul Rojo al satului rulează detașat pe 34872 și trebuie repornit ca să citească
  o schimbare de proiect. Ce a rulat în Studio se vede în `~/Library/Logs/Roblox/*_last.log` (`CreatorOutput`, `open place`).

## Stare (2026-09-16)

**Bâlciul de seară [D60]** — scris după planul aprobat, trece poarta (420 de teste), **necomis** (începutul e în
f82e404). Bâlciul s-a văzut în Studio ca fișier local; barca și doi jucători se pot verifica doar pe staging. Detaliile
în DECIZII D60.
- **Barca:** legată în aval de ponton (`TycoonConfig.FERRY`); drumul pictat comun (`UI/RideScene`, în amonte = spre
  stânga), cererea pleacă pe negru (`RowUp`/`RowHome` → `FerryService`). Sesiunea profilului nu se închide înainte de
  teleport: `DataService.MarkTeleporting` oprește Kick-ul, iar bâlciul nu scrie `lastSeenAt` (satul plătește ca offline).
- **Bâlciul** (`src/Fair/`, serviciile satului montate fișier cu fișier în `fair.project.json`): cameră care te
  urmărește (`FairScene`, adâncime după bază), roata mutată aici (`WheelController`; în sat, `WheelSignpostController`),
  oamenii (`PresenceService`/`PresenceController`, `CrowdCodec` pe `UnreliableRemoteEvent`), cardul altuia
  (`PlayerCardController`), titlurile (T), scena cu clasamentele săptămânii (satul scrie în `LeaderboardService`,
  bâlciul citește în `BoardService`), negustorul cu vitrina zilei (`MarketService`).
- **Profil v10.** `check_requires` verifică și remote-urile nesigure. Ecranul de încărcare așteaptă profilul
  (`SaveLoaded`).
- **Aspectul (2026-09-17):** owner-ul a văzut bâlciul în Studio și l-a găsit „super cheap". Fundalul e acum copt ca
  macheta (`scripts/art/d60_ground.py` scrie `prop_fair_ground/glow.png` și `FairScenery.luau`; rulează-l din nou după
  orice mutare în `FairLayout`), cu pădure, lumină moale, scântei și ghirlande. Imaginile sunt urcate. La a doua
  privire au plecat punctele gri de pe poiană. Etichetele trofeelor au testul lor de text, iar tabelele stau în lumina
  scenei.
- **Amânat pe D61:** iazul, gheretele, poarta satelor, croitoreasa, colțul cu Robux.

**Pontonul: undița, ce aduce râul, perlele pe sat, roata la locul ei [D59]** — plan aprobat de owner. Pontonul intră în
râu și se merge pe el (`WorldMap` cu trecere); la capăt, undița fără eșec (`ReelMath`: doar ținut apăsat scoți orice
pește; serverul crede scoaterea abia după jocul perfect pe aceeași bară), 12 pești, jurnalul (K); ce aduce râul la 4–8
min, cel mult trei te așteaptă (`TreasureMath`, și offline); avizierul satului (B): 10 decoruri cu loc fix și 3 ținute pe
perle; roata e un timonier pe punte, cu card E, fără monede (darurile râului, iconițele puse de cod). **Perlele cumpără
doar aspect** (amendează D46 pct. 4); totul plătește în perle, simulatorul neatins (41m52s). Quest-ul `Catch a fish at the
pier` în capitolul 2, cu săgeată deși ghidajul tace; indiciul pe linia NEXT. Profil **v9**; 40 de imagini și 3 sunete
urcate și aprobate. Trece poarta (367 de teste). **Comis pe 2026-09-15, neverificat încă în Studio.**
Prima trecere a owner-ului prin Studio (aceeași zi) a găsit texte care ies din cutie și florile peste numele caselor.
Reparate și comise în f82e404:
- **„Welcome back":** suma stă pe rândul ei.
- **Bannerul biletului:** trece pe mai multe rânduri.
- **Butoanele:** eticheta se strânge până încape (`fitButtonRow`).
- **Placa de pe cardul E:** crește după text.
- **Frazele Stations:** scurtate.
- **Etichetele de pe punte:** pe două rânduri.
- **Florile:** mutate sub nume.
- **Test nou:** decorul cumpărat nu acoperă etichetele.
- **Play-ul din Studio:** pornește iar de la zero, cu butonul „keep save" (vezi nota de staging de la arhivă).

Trece poarta (368 de teste).

**Al cui e fiecare lucru [D58]** — numele meseriei sub fiecare casă și „Forge" pe acoperișul forjei; meseria sub oameni
cât treci pe lângă ei (`HandRenderController`); „Upgrade (U)" pe cardul obiectului, butonul crește după text
(`Theme.textWidth`), a doua apăsare pe U închide meniul; X-ul panourilor desenat (fontul de pixeli n-are „✕"; 3 imagini
urcate și aprobate). Plasa din stânga hărții era Sixth Net-ul Erei 2, dat de butonul de dev „buy to 24": uneltele de dev
nu mai dau platforme care nu sunt în joc, iar plasele fără loc pe hartă nu se mai desenează. Trece poarta (328 de
teste). **Comis pe 2026-09-15, neverificat încă în Studio.**

**Satul pe flux [D57]** — după dezbaterea cu machete, harta Erei 1 e reașezată: curtea lemnului lângă tavernă, curtea
fierului spre Moară, patru drumuri (strada satului, două alei, piața), casele pe un rând peste stradă; nimic pe iarbă
goală (`TycoonConfig.YARDS`, `UI/GroundShadow`, `TycoonConfig.DECOR`, drumuri fără umbră, piața de piatră, iarbă peste
margini — 3 fișiere de artă noi). Tot aici: reflectorul tutorialului pe telefonul cu notch și lista de quest-uri
(de revendicat sus, „Claim 1 (perlă)"). Trece poarta (328 de teste). **Comis pe 2026-09-15, neverificat încă în Studio.**

**Linia fierului cu oamenii ei; atelierul devine Forge, colecția așteaptă [D56]** — plan aprobat de owner,
comis pe 2026-09-15; trecea poarta cu 326 de teste. Patru meserii noi (Scrap Collector, Scrap
Porter, Smelter, Iron Hauler), fiecare cu avizier → colibă lângă locul ei; forja topește fără Smelter doar cât
stai în inelul ei (`UI/StandRing`, comun cu gaterul; prezența pe loc, remote `AtForge`); Workshop și Collection
**parcate intenționat** (fără intrare, cod și profil neatinse); găsirile merg cu marfa și se vând la tavernă.
Economia pe două linii (timpul tău pe linii, veriga slabă pe linie), capitolul 3 „The Iron Line", ghidajul se
trezește la Forge, profil **v8**, Era 1 la 41m52s reali, fierul 35% din bani. 13 fișiere de artă urcate și
aprobate. **Neverificat încă în Studio.**

**Resturile pe drumul lor, roabele, grămezile la gater, colibele care cresc [D55]** — comis (ab45455). Fifth Net
prinde doar scrap; oamenii împing roabe, grămezile sunt pe trepte (bușteni stânga / scânduri dreapta la gater),
avizierele stau lângă meserii și devin colibe care cresc la al doilea om. Neverificat încă în Studio.

**Nivelul sunetului [D54]** — scris și trece poarta (299 teste): muzica implicit la nivelul 4 din 10
(~11 dB sub cât era), efectele la 10; panoul „Sound" pe tasta M (−, zece segmente, +) în locul
comutatorului de muzică; volumul pe `SoundGroup`-uri („Music", „Effects"), curba în `AudioLevels`;
remote `SetAudio`, profil **v6** (muzica oprită rămâne la 0). Persistența se vede doar publicat.
Neverificat încă în Studio.

**Ruinele malului, bușteni care vin pe râu, atelierul nou [D53]** — scris și trece poarta (291 teste):
ceasul plasei nu se oprește plină (`TycoonMath.netTick`), `CatchFloat` rescris (de la marginea lumii,
cotul în plasă, trecere pe lângă plasa plină), decorul din larg cu ce nu se poate prinde încă, ruine
pentru toate platformele Erei 1 cu cartonașul condiției (`TycoonMath.padBlocker`), avizierele, atelierul
nou; textul ghidajului nu mai cade sub HUD (`GuideMath.labelPlacement`). Arta (10 sprite-uri) aprobată de
owner pe previzualizare și **urcată** (moderare „Reviewing" la urcare). Neverificat încă în Studio.

**Oamenii înaintea plaselor, meniul obiectului simplu [D52]** — jucat de owner în Studio (270 teste): un
tur de mână, apoi cei cinci oameni la rând (13/15/18/20/25), abia apoi plasele; simulatorul urmează
quest-ul (Era 1 la 33m59s reali). Compromis ales de owner: poarta verigilor coborâtă de la 5% la 0,5%,
gaterul și taverna rar merită urcate în Era 1. Meniul obiectului pe minut, cu rândul „merită acum?" din
câștigul real (`gain` pe rândurile clădirilor, „Go to" spre veriga care ține venitul) și prețul pe
buton (`Widgets.SetButtonPrice`).

**Primul minut ghidat, cardul obiectului, sunetul plaselor, muzica [D51]** — jucat de owner în Studio
(lacătul „Filling up 12/12" adăugat după) (266 teste): capitolul 1 rescris (plasa plină, tot tăiat, tot vândut, „Sell 40 planks"), toate recompensele
în perle, `Stats.collected/sold`, prima plasă grăbită (`TycoonMath.catchBoost`), `GuideMath.loopStep`
(pasul din stare, „stai în inel până la ultimul"), linia NEXT pe două rânduri, tutorialul cu cartea după
prima vânzare, `InteractController` (acțiunea care e cazul + Upgrade, E/U), stropii doar aproape,
muzica compusă de noi (aprobată de owner, urcată) cu butonul M ținut minte în profil.

**Harta în buclă, taverna, dâra de ghidaj, sunetul [D50]** — jucat de owner în Studio:
`RoadGraph` (oamenii și dâra merg pe `TycoonConfig.ROADS`), `TavernCrowd` (clienții după vânzarea
reală), `PersonView` (omul desenat, comun oamenilor și clienților), taverna cu clienți, inelul „Stand
here to cut", amestecul de sunet, ghidajul care tace după cinci meserii; artă nouă urcată (taverna,
săgeata, inelul, două ținute). Economia neschimbată.

**Lanțul pe oameni [D49]** — jucat de owner în Studio: simulatorul pe șase verigi cu `--robust`
(Era 1 la 27m05s reali), `ChainMath` + `CrewMath` + `HandRoutes` + `PileMath` (module pure, testate),
profil **v5** (grămezi ca numărători, `Crews`, Carry rambursat), depozitul, gaterul cu curtea lui,
prezența la gater, cele cinci meserii cu trepte și al doilea om, meniul meseriei, 13 platforme în
Era 1, quest-uri și ghidaj pe bușteni/scânduri.

## Stare, arhivă (2026-09-12)

**Era 1 rescrisă pe structura Idle Miner [D46].** Ce e gata și trece poarta:
`sim_tycoon.py` rescris (două axe + gâtuire, 405 cumpărături / 27m43s reali, verifică și prețurile din config);
`ChainMath` + `StationConfig` (port bit-exact, teste de aur); grămada de la debarcader care se
scurge în monede; `StationService` + panoul de nivel cu x1/x10/x50/Max; Negustorul ca NPC static;
`QuestMath`/`QuestService`/`QuestController` (capitolul 1, nouă quest-uri); tutorialul cu reflector
și săgeată; perlele; roata zilnică; venitul offline legat în sfârșit (`OfflineCalc` + `WelcomeBack`
+ `WelcomeController`, toate trei scrise demult și nefolosite). Profil **v3**, migrare aditivă.

**Arta Erei 1 e gata** (2026-09-12): 16 sprite-uri noi + `sfx_wheel`, generate de
`scripts/art/tycoon_e1.py` / `scripts/audio/make_sounds.py`, **urcate**, legate în cod. Moneda,
perla, bulina, insigna de nivel și reflectorul nu mai sunt `Frame`+`UICorner`. Roata stă acum și ca
**obiect în lume**, lângă debarcader, și se aprinde singură când e o rotire de luat.

**Gaterul în lanț + meniul obiectului** (2026-09-12, D48): patru verigi, Sawyer (35% → 100%), profil
**v4**, predarea la gater, meniul de niveluri al obiectului atins; Era 1 la 31m35s reali.

**Cumpărarea se confirmă, nivelul se atinge din lume** (2026-09-12, D47): cartonaș cu preț și rest,
plasa următoare cere nivelul 2 la cea dinainte, simulatorul verifică prețurile din config.

**Rămas:** impulsurile temporare de NPC („Activate all") — **nefăcute intenționat**: un ×N gratuit
repetat schimbă exact cifrele din care simulatorul derivă toate prețurile, deci se reglează după ce
Era 1 e jucată o dată cap-coadă. Apoi capitolele 2-3, Era 2, poarta F1 (playtest cu ≥5 oameni).

## Stare, arhivă (2026-09-11)

Planul tycoon e scris (`docs/TYCOON.md`). **F0 e scris** (2026-09-11): schema v2, `TycoonConfig`/
`TycoonMath` (port exact al simulatorului, testat), `PadService`, `EconomyService`, `NetService` pe
cronometru, sacul, debarcaderul, HUD-ul nou; codul de colonie e scos. **Poarta F0 trecută în Studio**
de owner. **F1 e scris** (Era 1 completă: alergătorul, atelierul, clopotul, prinderea vizibilă,
ghidajul, sunetele); poarta lui e playtest-ul cu ≥5 oameni din afară.
**[2026-09-15]** Staging = universul 10765888327 (place 132381101591529), „Driftycoon (Staging)", privat, cu acces la
API din Studio. Totuși Play-ul din Studio pornește **de la zero** (ProfileStore.Mock, ales de owner pe 2026-09-15);
butonul „keep save" din consola de dev păstrează salvarea reală pentru Play-urile următoare (revenirea, offline).
Bâlciul [D60] = place-ul **114983498774894** din același univers (creat pe 2026-09-16; numele din Creator Hub e încă
cel automat, cheia locală n-are `universe.place:write` ca să-l schimbe). Producția =
universul 10766553412 (place 101083147721008), „Driftycoon", gol și privat, fără acces la API din Studio. Ambele pe
contul personal (userId 11640386677). Rămas la owner: numele, terenuri multiple, lobby/DevEx, D19 (2FA + ID făcute pe
2026-09-11; grupul Roblox abandonat pe 2026-09-15, vezi D01). **Fiscalul (W-8BEN):** pagina Finances → Taxes nu apare pe
cont (0 Robux câștigați, 2026-09-15); se depune când apare, **înainte de primul cash-out** — de verificat la primele vânzări.
