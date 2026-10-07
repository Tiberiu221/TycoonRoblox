# Driftycoon — context de proiect

Citit automat la fiecare sesiune. Ține-l scurt: fiecare cuvânt de aici se plătește la fiecare pornire.

## Ce construim

Tycoon 2D pe Roblox, pe malul unui râu, așezat ca un sat pe flux [D57]. **Râul aduce → Collector-ul adună în depozit → Porter-ul duce
la gater → gaterul taie → Hauler-ul duce la tavernă → taverna vinde.** Venitul e **minimul
debitelor**; ce pas n-are om îl faci tu [D49]. Din Forge, a doua linie cu oamenii ei: **Fifth Net → Scrap
Collector → Scrap Shed → Scrap Porter → forja (Smelter) → Iron Hauler → tavernă**; liniile împart doar taverna
[D56]. După Landing Bell, **Era 2 „The Mill"** repetă schema la dreapta pe hartă: scrap → piese de mașini (turnătorie),
apoi minereu → cupru (cuptor), vândute la **Piață** [D65]. Veriga cea mai slabă decide, iar repararea ei e decizia
jucătorului [D46]. Clădirile au **niveluri fără capăt** (salt la 10/25/50), oamenii **trepte
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

- **Nimic nu se pierde.** Fără dezastre, fără furt, fără scădere; offline doar binevoitor. **Singura excepție scrisă
  [D70]:** la schimbarea de hartă aleasă de jucător („Build the Dam", drumul spre Era 8) toți pornesc cu aceeași sumă
  (9T [D78]: `DamRun.start_sum` din `sim_tycoon.py`, în joc `TycoonConfig.DAM_START_COINS`). Ce e peste ea intră în construcție,
  e scris pe placă și e anunțat dinainte. Nimic plătit nu se taie, iar venitul crește.
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

**Capcane cunoscute:** Scriptul de pornire al clientului (`Bootstrap.client.luau`) **așteaptă folderele de lângă el**
(`script.Parent:WaitForChild("Controllers")`, la fel `UI`) înainte de primul `require`: Roblox le copiază în PlayerScripts
pe rând, iar pe 2026-09-19 satul a pornit cu cer albastru și atât („Controllers is not a valid member of
PlayerScripts"). `check_requires` pică acum la `script.Parent.X` într-un asemenea script. Ceasul jurnalului Studio
(`~/Library/Logs/Roblox`) rămâne în urmă cât doarme Mac-ul: caută după text, nu după oră. stylua șterge punctul-și-virgula din fața unei instrucțiuni care începe cu `(` —
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
lune run scripts/check_compile                             # fiecare fisier chiar se compileaza (limitele Luau)
rojo build default.project.json --output /tmp/check.rbxl
lune run scripts/check_requires /tmp/check.rbxl
rojo build fair.project.json --output /tmp/fair.rbxl        # [D60] balciul, place-ul al doilea
lune run scripts/check_requires /tmp/fair.rbxl
python3 scripts/economy/sim_tycoon.py --robust
python3 scripts/art/check_panel_rows.py
python3 scripts/art/village_ground.py --check              # [D62] pamantul copt e la zi cu harta (ambele lumi)
```
`rojo build` și `check_requires` **nu parsează Luau** — o eroare de sintaxă trece de ele; doar
stylua/selene o prind. Rulează-le mereu pe toate, nu înlănțuite după o eroare.
**selene pică CI-ul și la un singur avertisment** (cod 1). Nu-i trece ieșirea prin `tail`/`grep`: pipe-ul ascunde codul
(așa a picat D61 pasul 3 pe CI, deși local părea verde).

## Mod de lucru

- Agenții pe **Sonnet**, niciodată moștenind modelul principal. **Excepție (owner, 2026-09-24):** verificatorii (logică, aspect,
  reguli, verificări în general, adică `verify-work` și auditurile) rulează pe **Opus 5.5**. Le dai instrucțiuni clare, apoi
  **verifici tu** în cod ce raportează — au greșit de mai multe ori.
- Dus la capăt singur, apoi o listă scurtă cu ce poate verifica doar owner-ul în Studio.
- **Commit și push după fiecare lucru terminat**, cu poarta verde înainte (owner, 2026-09-17: „fă commit și push
  mereu"; înainte era „fără commit fără cerere"). Repo privat `github.com/Tiberiu221/TycoonRoblox`, ramura `main`.
  CI-ul rulează poarta la fiecare push și scrie rezultatul pe ramura `ci-status` (citit prin SSH:
  `git fetch origin ci-status && git show FETCH_HEAD:status.txt`; jurnalul pașilor picați e în `failed.log`).
  **Publicarea pe staging:** CI-ul publică la fiecare push (`scripts/ci_publish.sh`), dar **satul nu se publică cât e
  deschis în Studio**. Roblox răspunde 409 „Server is busy" cât trăiește sesiunea de editare colaborativă, adică încă
  câteva minute după închidere. Așa a picat publicarea satului la fiecare push, până pe 2026-09-17. Actualizările
  satului luate atunci drept publicări erau salvări automate din Studio, iar bâlciul a rămas gol de la creare.
  Când owner-ul vrea satul pe staging, închide fereastra satului din Studio, iar eu public din nou: un push, fie și un
  commit gol. Varianta de pe Mac e `python3 scripts/publish_staging.py`. Are aceeași poartă și aceleași reîncercări,
  dar cere o cheie de publicare în `~/.driftwood_publish_key`, care încă nu există. Cheia din `~/.driftwood_api_key`
  are drept doar pe imagini. Rularea scriptului e publicare, deci cere acordul owner-ului.
  **Nu trimite owner-ul în GitHub** (nu găsește Actions). Owner-ul vede satul prin `rojo serve` + Connect în Studio, iar
  bâlciul ca fișier local (`lune run scripts/build_balci [perle] [pass-uri]` scrie `Balci.rbxl`, deschis în Studio,
  fără teleport și fără DataStore). Scriptul pune pe Workspace atributele `DevPearls` și `DevPasses`, citite doar în
  Studio: fișierul local pornește mereu cu profil proaspăt, deci fără ele n-ai cu ce cumpăra o ținută.
- Cheile API (`~/.driftwood_api_key`, `~/.driftwood_publish_key`) — niciodată în chat, în repo sau ca argument de
  comandă.
- **Rojo toarnă proiectul în orice fereastră Studio conectată** (așa a ajuns satul peste `Balci.rbxl` și în jocul
  accidental „The Fair", universul 10766663878). De aceea fiecare proiect are `servePlaceIds` (satul doar în 132381101591529,
  bâlciul doar în 114983498774894); serverul Rojo al satului rulează detașat pe 34872 și trebuie repornit ca să citească
  o schimbare de proiect. Ce a rulat în Studio se vede în `~/Library/Logs/Roblox/*_last.log` (`CreatorOutput`, `open place`).

## Stare (2026-10-04) [D75, D76, loturile A1–A2–A4]

**Arta barajului e desenată și legată în cod; owner-ul a aprobat planșele A1, A2 și A4 și urcarea lor, în ordinea A1 → A4 → A2
[D76].** Pământul copt (A3, `prop_dam_ground` / `_2`) nu intră în acord: se cere separat. A4 (`scripts/art/a4_*.py`, planșa
`a4_plate.py`): clădirile, casele, marfa și ținutele barajului (70). „Look across (E)” rămâne pe cardul Switch House.
- **Schimbări voite în sat [D76, A4]:** cardul plasei cu sacul plin spune unde duci marfa (`GuideMath.cardFullText`, prin
  Overlay: fraza săgeții când ea e pe drumul traistei). Placa se rupe pe rânduri echilibrate, iar cardul E ocolește panourile
  fixe ale HUD-ului (`GuideMath.cardPlacement`: locuri cu nume, păstrat cât e liber; testat pe plimbări, PLAN §16). Clienții tavernei, ai Pieței și ai Depoului pleacă cu marfa
  vândută (`FlowMath.soldGood`);
  după Works Bell, cristalul plutește pe curentul din larg (D68), acum că desenul lui e urcat.
- **Urcarea [D76]:** A1 (16), A4 (70) și A2 (13 desene, piesa filmului și două sunete) sunt urcate, toate aprobate de
  moderare (2026-10-04). Mai au ID 0 doar pământul copt al barajului (A3, cerere separată) și coafura `bald` (intenționat).
  `upload_assets.py` scrie marfa în tabelul `goods` (`goods_barrel` ar fi căzut peste `props.barrel`).
Detaliile, rundele de verificator și ce urmează la urcare: `docs/PLAN-MOTOR-UNIRE.md`, nota „A1 și A2, starea”.
- **A1** (`scripts/art/a1_*.py`, planșa `a1_plate.py`): zidul de piatră, deversorul, spuma, fața turbinei (pe grila zidului),
  Old Bells, Memory Wall, căsuțele, stâlpii, orășelul pictat (se aprinde cu primul curent, cu Look (V); LookController pornește
  în orice lume), cristalul pe curentul din larg.
- **A2** (`scripts/art/a2_*.py`, `scripts/audio/a2_film.py`, planșa `a2_plate.py`): filmul, cu decorul pur în `DamFilmSet`.
- **l1 și l3 făcute [D77]:** barajul e în joc (`ENGINE_ERAS = 4`, 23 de platforme `live`; comutatorul local a ieșit).
  l1 = jucat cap-coadă cu sonda, fără erori. A3 (pământul copt al barajului) e urcat și aprobat (2026-10-06), cu
  `BAKED_DISTRICTS.dam_town` / `dam`. Owner-ul s-a uitat în joc: „pare ok”. **Lansarea:** producția se publică manual (D77).
  **Recopt și urcat din nou tot pe 2026-10-06** (owner: „tot iarba rămâne? parcă nu a evoluat deloc jocul”): la baraj, iarbă
  uscată cu pete de pământ bătătorit, străzi pavate cu borduri, curți de prundiș, fără flori (`village_ground.py`, doar sub
  `dam`); decorul împrăștiat are felurile lui (`WorldDecor.DAM_KINDS`: cioturi, bușteni, pietre, butoaie). Satul, neatins.
- **Barca spre bâlci (2026-10-07):** barca bâlciului redesenată și salupa cu aburi a barajului (`d60.py` `ferry` / `launch`,
  62x30, urcate și aprobate), la pixelul hărții (×3; `FERRY` la x 449, `FERRY_TAG_BASE`). `RideMath.Vessel`: salupa face
  drumul în 4 s; `RideScene` alege desenul, textul și fumul pe drum; la debarcaderul bâlciului, fiecare își vede barca lui
  (atributul `World`). Auditul bâlciului: satul așteaptă profilul până la 150 s, cu „Still loading your save...”.
- **Folderul de lucru al scripturilor de artă și sunet:** `scripts/art/scratch.py` (`DRIFTWOOD_SCRATCH`, altfel `.scratch/` din
  repo, ignorat de git). Nicio cale de scratchpad al unei sesiuni nu mai e scrisă în scripturi. Desenele loturilor urcate se
  citesc din `assets/sprites` când lipsește copia de lucru (`scratch.sprite`).
- **Sonda duce profilul de la un Play la altul:** `probe.py export F`, apoi `probe.py play --profile F` (doar pe profil de
  probă; `ProbeCarry` refuză un profil pe care JSON l-ar schimba). Așa se face Stop/Play-ul de după „Build the Dam” (l1).
- **Capcană:** stylua a căzut o dată cu „Abort trap” în poartă; rulat din nou, trece. Verificatorii primesc intervalul de
  commit-uri (`base: "A B"`), ca lucrul necomis să nu le intre în diff.

## Stare (2026-10-03) [D74, pașii j1–j15, k1–k12, A0]

**Barajul (lumea 2) e în date și în modulele pure, adormit; jocul viu e neschimbat.** Pașii, cu dependențe și verificări:
`docs/PLAN-MOTOR-UNIRE.md` §16 (j1–j15, k1–k12, l1–l3); singurul commit care schimbă jocul viu e l3. D74: așezarea aprobată,
recomandările owner-ului luate (O1, provizoriu).
- **Martorul lumii 1** (`tests/WorldIdentity.test.luau`): `tests/witness/world1.txt` (erele 1–3, după eră) nu se schimbă
  niciodată din cauza barajului; `engine.txt` (listele motorului) se rescrie doar la l3. `WORLD_WITNESS=write` le rescrie.
- **Lumile:** `WorldConfig` (era → lume), `TycoonConfig.WORLDS[1|2]` și accesoriile (`padsOfWorld`, `linePlacesOf`, …; fără
  lume = satul), `RiverConfig.WORLDS`, `RoadGraph.forWorld` (lumea 2 ocolește zidul și canalul), `HandRoutes.forWorld` /
  contextul implicit pe meserie, `WorldMap.forWorld`, `DriftMath.reachesFor`. Testul de așezare: `tests/World2Layout.test.luau`.
- **Era 4 în config:** 23 de platforme `live = false` cu locurile din planșă, 15 meserii, `DAM_START_COINS` (35T), plasele pe
  rang (`ChainMath.netIdentity`), profil **v19** (`World`, `Memories`, `Purchases.coinsBought` = monedele Robux în mână).
  Simulatorul verifică prețurile, ce dă barajul, rangurile și condițiile Erei 4 (`check_config_era4`, `check_era4_after`).
- **În joc acum:** 11 descrieri de platforme erau tăiate cu „…” pe cartonaș; scurtate și măsurate cu lățimile Nunito
  (`tests/fonts/NunitoWidths.luau`, din `scripts/art/nunito_widths.py`).
- **Serverul pe lume (j10–j13):** `WorldMath` (poarta `allowed`, era fiecărui lucru, zonele pe lume, `bellBefore`,
  `zoneSign` / `fenceText` = textul zonelor), refuzul „That's not on this map” la orice cerere a altei hărți; Dam Bell cere
  4T/s (8T cu 2x Flow); capitolele 10–12 (`QuestConfig.chaptersOfWorld`, quest-ul de venit, `settleWorld`); `ChainState`
  (starea lanțului din profil, pură); unirea la Relay în `EconomyService` (`assemble`, `dropJoin`, `DropAt` întoarce restul);
  oamenii retrași; `CrewMath.unhired` / `stalledWelcome` (fereastra „AWAY 0”).
- **Ridicarea (j14–j15):** `DamMath.build` / `preview` (pur: Last cart, quest-urile în perle, START + R, veteranii, darurile;
  venitul de după = startul de aur 19,57B/s), `DamService` + remote-urile `DamPreview` / `BuildDam` / … + `DamController` pe
  client (fără ecran încă), `DataService.SaveNow` (comun cu chitanțele Robux), `dev world N`, `dev dam [build]`.
- **Clientul pe lume (k1–k11, fiecare cu notă „făcut” în PLAN §16):** clientul pornește după lume și îngheață la o stare a altei
  lumi (k1); platformele, zonele, panoul pe lume (k2, `ChainHead` pe două coloane la baraj, k4); liniile barajului, Relay-ul
  (`LineController.join`), copia stării (`StateCopy`, testată pe FULL), ghidajul pe lume (k3); textele și refuzurile Erei 4,
  indiciile pe card înainte de E (`FlowMath.hintAt`, k4); contorul quest-urilor fără paranteze, pasul de venit (k5); drumul din
  sat spre baraj (`damAvailable`, `TycoonConfig.beyond`, masa Dam Plans, k6); ecranul „Build the Dam” cu `Widgets.HoldButton`
  (k7); reîncărcarea în lumea 2 prin `FerryService.Depart(player, trip)` (k8); filmul (`DamMath.frameAt`, `DamFilm`, provizoriu
  până la A2, k9); ținutele și prenumele, Dam Town și „Your people” (k10); bâlciul pentru gazdele de după baraj (k11).
- **Schimbări voite și în sat (D43/D40):** contorul listei fără paranteze; un quest pe o platformă încuiată n-are preț; la Piață și
  Depou, refuzul „raw_only” e al lor, iar cardurile atelierelor și vânzătorilor spun unde merge marfa adusă greșit. [2026-10-04]
  Clienții tavernei, ai Pieței și ai Depoului pleacă acasă cu marfa care tocmai a plecat din grămadă (`FlowMath.soldGood`; o
  găsire, ca ladă). Înainte: la tavernă mereu scândura, la Piață și la Depou mereu piesa de mașină a Morii.
- **Comutatorul local** (`era4_flip.py`) a ieșit la l3 [D77]: barajul e în joc.
- **Capcane noi:** `rojo serve` pica pe o legătură `Packages/Packages -> Packages` (ștearsă; caut-o întâi dacă serve nu
  pornește). Proba j13 cu Studio e amânată: pluginul Rojo se reconectează doar la Connect. `check_requires` ia drept câmp
  și un comentariu de forma `Modul.camp` (scrie altfel). Nunito n-are „→”.
- **k12 (fără urcare):** `village_ground.py --world 2` coace `prop_dam_ground` / `_2` (`dam_ground.lock`; `--check` pe ambele lumi),
  `SceneArt.BAKED_GROUND` pe lume. ID-urile rămân 0 până la acordul owner-ului. Odată cu urcarea intră și `BAKED_DISTRICTS` `dam_town`
  / `dam` (testul World2Ground le ține împreună).
- **A0, planșele (așteaptă owner-ul):** `python3 scripts/art/a0_dam.py` scrie în folderul de lucru `a0_dam_wall.png` (A piatră,
  recomandat; B beton cu stavile) și `a0_dam_film.png` (șase cadre-cheie). Pământul lumii 2 se vede cu `--world 2 --preview`.
- **Verificatorii k6–k11 sunt reparați** (pagina „Your people” era goală, filmul cădea la `Init`, oamenii retrași stăteau unul
  peste altul; notele sunt în PLAN §16). **Schimbări voite în sat:** cardul unui vânzător fără ce vinde spune unde merge marfa
  (`StateCopy.sellerNote`), iar eticheta de margine a ghidajului rămâne în ecran.
- **Indicatorul de margine al ghidajului (în satul viu):** `GuideMath.edgePlacement` / `edgeIndicator` (pure, testate pe
  șase ecrane). Indicatorul stă pe inelul marginilor și ocolește panourile fixe (atributul `GuideBlocker`). Capetele libere se
  calculează exact. Între capete alege după unghiul spre țintă, cu histerezis. Eticheta trece pe două rânduri echilibrate,
  iar pe telefonul cel mai mic rămâne doar săgeata. Unsprezece runde de verificator; limitele rămase (du-te-vino lângă
  colțul cu cifre) le alege owner-ul în Studio (PLAN §16, a unsprezecea rundă).
- **Capcane noi:** un verificator a lăsat odată legătura `src/src -> src`; buclele de legături strică testele („Too many
  levels of symbolic links”), deci caut-o cu `find . -maxdepth 4 -type l`. Commit-ul se face doar după „GATE fail=0” explicit,
  nu după un `grep` care trece și la eroare.
- **Urmează:** aprobarea A0 de către owner, apoi A1–A4 (fiecare urcare cere acordul) și l1–l3. Proba l1 cere Studio conectat
  la Rojo (`lsof -nP -iTCP:34872` să arate ESTABLISHED).

## Stare (2026-10-02) [D72]

**Plasele rapide nu mai sună ca o rafală** (`CatchSound`, pur, cu teste; `SoundController` doar îl întreabă). Cât malul e
liniștit, se aude fiecare prindere; aglomerat, cel mult ~2 stropi pe secundă, mai încet, dar peste casa de marcat.
Clinchetul găsirilor se împarte de sus în jos, cam unul la 4 s pentru găsirile din rază și unul la 12 s pentru cele de
departe, iar „mythic” sună mereu. Turbina nu face stropi. Casa de marcat se aude după distanța până la vânzător. Clopotul
sună la fiecare eră. Nimic nu e auzit încă în Studio: judecata e a owner-ului, cu plasele la nivel mare.
- **Motorul, pașii e–g** (PLAN-MOTOR-UNIRE §12–13): Era 4 stă în `StationConfig` / `TycoonConfig`, dar jocul rulează
  doar erele din `StationConfig.ENGINE_ERAS` (3); listele `_ALL` și `ChainMath.FULL` au și barajul. `ChainMath` știe
  unirea, bazinul și liniile închise, verificat la bit pe `GOLDEN_ERA4`. Platformele Erei 4 vin cu harta (pașii j–k).
  Pasul h (§14): `HeldBack` numește cealaltă piesă a unirii („the Cable line is slower”) și ce lipsește; cuvintele
  barajului sunt propuneri. Pasul i (§15): `FlowConfig.GAME` / `FULL`, unirea fizică la Relay (`assemble`, `dropJoin`,
  `part_to_relay`), ordinea de scurgere a orașului, `StationConfig.STEP_JOBS`, `HandRoutes` cu context. Urmează j
  (serverul, profilul v19, harta barajului).
- **Harta [D73]:** bannerele atelierelor noi cu „Look (V)”, ruinele din cartiere închise spun clopotul, panoul barajului
  „will rise by your pier”, darurile râului la toate cartierele deschise, felinarele de la treapta „wire”, masa Dam Plans
  arată țărușii. Ce cere artă sau ritm (mijlocul erelor, cristalul pe râu, recuzita Morii, primul cadru) așteaptă owner-ul.

## Stare (2026-10-01) [D71]

**Satul lucrează fără tine pe o curbă, iar seria zilnică se vede la bâlci.** Nimic nu e văzut încă în Studio.
- **Curba** (`OfflineCalc`, `PassMath.offlineCurve`): viteză întreagă 8 h (16 h cu Long Nights), un sfert până la 24 h,
  apoi odihnă. Poarta `check_windfall` se măsoară pe o zi întreagă (22,4% din Era 2). Suma barajului rămâne pe noaptea de
  8 h (`NIGHT_HOURS`). Fereastra de revenire primește un tabel (`StationService.WelcomeInfo`), nu argumente pe poziții.
- **Seria zilnică** (`StreakMath`, profil **v18** `Streak`; barajul trece pe v19): ziua jucătorului (fusul orar trimis de
  client prin `SetClock`, validat, schimbat cel mult o dată pe zi), o zi lipsă nu o rupe, două da; titlurile Regular (7) și
  Old Friend (30) din cea mai lungă serie, anunțate. Pastila de sub perle, rândul de pe card, toast-urile; se numără și în
  timpul jocului, în sat și în bâlci.
- **Unelte:** `dev away <ore>` (curba și fereastra), `dev streak <n>`; în `Balci.rbxl`, al treilea argument al
  `build_balci` (`DevStreak`).
- **Așteaptă owner-ul:** acordul pentru `python3 scripts/create_monetization.py --update nights` (descrierea Long Nights de
  pe Roblox); judecata curbei se face cu pass-urile stinse (rândul `robux`).

## Stare (2026-09-29) [D70]

**Modernizarea Erei 3 e în cod, iar motorul lanțului știe să unească piese.** Nimic nu e văzut încă în Studio.
- **Modernizarea** (`docs/PLAN-HARTA.md` §5, „Făcut"): cinci trepte din `ModernMath`, citite de `ModernController`.
  Desenul se alege în `UI/Modern`, recuzita (stâlpi, sârmă, tamburi, Dam Plans, țăruși) se face în `UI/ModernProps`, iar
  locurile, testate să nu calce nimic, stau în `TycoonConfig`. Toate 18 imagini sunt urcate și aprobate. Macheta din bâlci
  arată treapta gazdei. Fiecare treaptă vine cu un banner și, când locul nu se vede, cu „Look (V)": o privire de ~4 s spre satul vechi
  (`LookController` + `GlanceMath`, locurile în `TycoonConfig.modernLookAt`).
- **Motorul** (`docs/PLAN-MOTOR-UNIRE.md`, pașii a–c): chei opționale pe linii (`closeFlag`, `inputs`, `into`, `value`,
  `pool`); Erele 1–3 ies neschimbate la bit, iar `check_lines` fixează 22 de reguli. Pașii d–i sunt făcuți, j–l sunt în §16, cu hotărârile
  din D70 „Runda 4" (piesele se vând doar unite, startul e 35T cu AWAY 0 până la cei 6 oameni, cristalul se vinde și în
  Era 4) și „Runda 5" (veteranii pe butoaie, cablul de mână, Pylon Runner, fără găsiri sub baraj, pauza reparată din
  cifre).
- **Pasul d (Era 4 în simulator) e făcut, cu șase runde de verificator** (2026-10-01, §11 din plan). Owner-ul a ales
  varianta 1 (D70 Runda 6): Dam Bell se deschide la 4T/s, fără a doua turbină și a patra plasă. Era 4 ține 45m16s reali
  (scara de la 8,5); capitolul, jucat a treia oară în `DamRun`, ~44 de minute, cu pasul „Earn 1T coins a second”.
- **Finalul ce e în joc (2026-09-30):** după clopotul ultimei ere din joc vine bannerul „The Dam is coming soon!”, iar
  ultimul capitol, lista de quest-uri (rândul de final) și masa „Dam Plans” spun același lucru. Toate citesc
  `TycoonConfig.comingEra()`, deci tac singure când Era 4 intră în joc. **Plafonul de după clopot** (verificatorul, cu
  simulatorul): cu oamenii la 2 × treapta 5, venitul se oprește la ~1,63B/s (+35% față de clopot), atins în ~45 de minute
  reale. Orice nivel peste plafon aduce 0. Textele nu promit creștere; dacă merită un joc real după clopot, e o decizie de
  economie a owner-ului.
- **Capcana sondei:** dacă Studio nu e conectat la Rojo, Play-ul rulează codul vechi, fără nicio eroare. Verifică înainte:
  `lsof -nP -iTCP:34872` trebuie să arate o legătură `ESTABLISHED`, nu doar `LISTEN`.
- **Baza unei clădiri de pe platformă e `TycoonConfig.buildingBase(p)`** (y + 48 + 8). Orice desen pus față de o clădire
  (fum, fir, card, inel, nume) o citește de acolo. Cine o socotea singur greșea cu 48 px: fumul Power House, roata de apă
  pe scânduri, planșele Morii. Sweep-ul și reparațiile din 2026-09-29 sunt în commit, cu cinci runde de verificator.
- **Ghidajul și cardul E:** cardul unui loc are `at` (punctul din care se măsoară). Ghidajul își retrage săgeata doar
  pentru cardul locului spre care arată (`InteractController.Shown`). O regulă după geometria cardului a produs cazuri noi
  la fiecare rundă. **Ce card ia tasta E** e în `GuideMath.pickCard` (2026-09-30): darul de pe râu, apoi undița aruncată
  (ține E cât mulinezi), apoi, lângă țintă (70 px), cardul țintei, altfel cel mai apropiat. Lângă o platformă-țintă,
  cartonașul ei bate cardul unui obiect.
- **Capcană de straturi:** cardul E stă în `Scroll` (Z 12), peste tot `Plot`-ul (Z 5) și peste săgeata ghidajului (Z 9).
  Ce trebuie să stea peste el se pune tot în `Scroll`, peste 12 (vezi `FishingRig` cu `Over`/`OverOrigin`: bara și
  cartonașul prinderii). Un ZIndex mare în `Plot` nu ajunge.

## Stare (2026-09-24) [D67 după audit, D68]

**Un verificator după fiecare lucru** (owner: *„lasă și un agent să verifice mereu ce s-a lucrat; mă interesează mult logica
și aspectul jocului"*). Înainte de commit rulează `Workflow({scriptPath: ".claude/workflows/verify-work.js", args: {what,
base: "HEAD"}})`: trei recenzenți pe Opus 5.5 (logică, aspect, reguli), iar fiecare constatare trece printr-un sceptic. Ce rămâne în
picioare se repară înainte de push.
- **Auditul Erei 3** (șapte lentile plus criticul acoperirii) și reparațiile lui sunt în DECIZII D67, „După auditul din
  2026-09-24". Pe scurt: textul turbinei, grămezile Erei 3, poza „la lucru", hornurile, felinarul dublat, etichetele,
  quest-urile prea lungi, numele de eră din bâlci, felinarele satului vizitat.
- **Arta aprobată și urcată:** colibele Wire Works cu acoperiș pe meserie, plus turbina și roata de apă care se învârt
  (`UI/Spin`). Toate 18 imagini sunt aprobate de moderare.
- **Hotărâri [D69]:** 2D pentru totdeauna (fără lobby 3D), fără niciun dezastru (Inundația din D19 e anulată), numele
  „Driftwood" e bun, dar nu contează acum.
- **Harta se schimbă [D70], DECIS în regulile mari:**
  - Era 3 se modernizează treptat.
  - La Era 4, un film scurt în care oamenii desfac satul și ridică barajul. Primii cinci lucrează mai departe, ceilalți
    pleacă. Toți pornesc cu aceeași sumă (`DamRun.start_sum`; în joc `TycoonConfig.DAM_START_COINS`): 9T de la D78.
  - De la Era 4: 3 linii pe eră (două fac piese, a treia le unește), iar marfa erei vechi o duce un om pe drum în era nouă.
  - Fiecare eră are alt cumpărător. Din Era 6, roboții iau locul unor oameni.
  - La Era 8, un drum spre o hartă SF, iar racheta se construiește pe etape. Planul: `docs/PLAN-HARTA.md`.
- **Era 4, „The Dam" [D68]: înlocuită de D70 și D74** (`docs/PLAN-ERA4.md` e istorie). Barajul vinde curentul dus pe
  stâlpi; cristalul se vede pe râu de la finalul Erei 3.

## Stare (2026-09-21) [D66]

**O singură monedă; Moara pe scara x3000; satul lucrează fără tine o noapte (8 h, 16 h cu Long Nights).** Owner-ul a
cumpărat toată Era 2 cu banii unei absențe. A respins banii separați pe cartiere și orice monedă nouă (*„nu vreau alte
monede"*). Detaliile și cifrele sunt în DECIZII D66.
- **Simulatorul:** `ERA2_MULT = 3000`, a șasea plasă gratis (`ERA2["free_units"]`), `ERA2_LADDER_START = 7.5`. Era 2
  durează 47m34s reale și trece `--robust`. O noapte de la finalul Erei 1 plătește 8 din 26 de deblocări (20%).
- **Poarta nouă `check_windfall`:** pică dacă o noapte de absență de la sfârșitul unei ere sare peste 25% din era
  următoare. Orice eră nouă trebuie să treacă pe aici.
- **Numerele mari:** `TycoonMath.formatNumber` merge până la `Td` (10^42), apoi „1e45”, în cinci caractere (2026-09-29);
  venitul de pe tabla din bâlci e codat (`BoardMath.encodeIncome`), ca să încapă și la Era 8.
- `scripts/create_monetization.py --update <cheie>` rescrie descrierea unui pass pe Roblox.
- **Era 3, „The Wire Works" [D67]: în joc (`live`)**, cu arta ei (54 de imagini urcate și aprobate), jucată cap-coadă cu
  sonda pe 2026-09-21, fără erori. Planul și ce s-a hotărât: `docs/PLAN-ERA3.md`. Felinarele de pe strada fiecărui cartier
  se aprind cu primul curent vândut (`LampController`, `firsts.power`). Pământul recopt cu cartierul e urcat.
  **Rămâne:** verificarea owner-ului în Studio.

## Stare (2026-09-19, seara) [D65]

**Era 2 e construită și în joc (`live`), cu desene de împrumut; nevăzută încă de owner în Studio.** Planul pe pași și ce
a rămas: `docs/PLAN-ERA2.md`.
- **O eră nouă = rânduri în tabele.** Liniile și vânzătorii în `StationConfig`, drumul mărfii în `FlowConfig` /
  `FlowMath`, locurile în `TycoonConfig.DISTRICTS` / `LINE_PLACES` / `SELLER_PLACES`, cuvintele în `Strings`
  (`LINE_WORDS`, `LINK_WORDS`, `NET_WORDS`, `BUILDING_WORDS`), quest-urile în `QuestConfig.ALL_CHAPTERS` (în joc intră
  doar capitolele erelor `live`). Clientul Morii e un singur controller după tabel (`LineController`); controllerele
  Erei 1 au rămas cele scrise de mână.
- **Arta Morii e urcată** (2026-09-21, cu acordul owner-ului; 50 de imagini și cele două felii de pământ recopt, 52
  din 52 aprobate de moderare; planșe cu `python3 scripts/art/preview_d65.py`). Moara e cărămidă, tablă și cupru.
  Codul încearcă întâi desenul propriu (`UI/GoodArt`, `PadArt`, `LineController`) și cade pe al perechii din Era 1 doar
  dacă lipsește (`TycoonConfig.PAD_LOOKS_LIKE`, `GOOD_LOOKS_LIKE`, `HandConfig.OUTFIT_LOOKS_LIKE`). Ținuta unui om
  vine din rol la citire (`VillageLook`). `BAKED_DISTRICTS.mill = true`: pământul Morii vine din imaginea coaptă.
- **Decorul împrăștiat nu acoperă casele cartierelor noi** (`TycoonConfig.homeClearRects` → `WorldDecor.village`);
  satul vechi rămâne exact cum era (test). Roata de apă stă în râu, la marginea punții (`PadArt.ART_OFFSET`).
- **Jucată cu sonda pe profil de probă, fără erori:** clopotul Erei 1, roata de apă, turul de mână al pieselor, oamenii,
  plasele, cuptorul, turul cuprului, clopotul Morii; niveluri, trepte și al doilea om pe drumul adevărat. Unelte:
  `dev "chapter:4"` (sare la începutul unui capitol), `dev "up:foundry 3"`, `client "ui:panel:foundry"`,
  `client "ui:goto:x:y"`.
- **Capcană a sondei:** cu fereastra Studio ascunsă, Play-ul are viewport 1×1 și `PreRender` nu rulează: cardurile de
  lângă obiecte, cartonașele platformelor și „textul nu încape" nu se pot judeca atunci. Textele și starea, da.
- **Clienții** tavernei și ai Pieței vin din aceeași componentă (`UI/CustomerCrowd`), cu locurile din
  `TycoonConfig.SELLER_PLACES`. Mutarea s-a făcut întocmai, dar mersul lor (pe `PreRender`) n-a putut fi văzut cu sonda.
- **Rămâne:** verificarea owner-ului în Studio, cu arta Morii la locul ei (prima lui privire, pe 2026-09-21, a fost
  cu desenele de împrumut).

## Stare (2026-09-19, noaptea) [D63]

Owner-ul a lăsat lucrul peste noapte: logica și monetizarea, „să vrei să joci", meniuri pentru copii, Era 2 dacă Era 1
e gata. Detaliile și sursele sunt în DECIZII D63. **Nimic din ce urmează n-a fost văzut în Studio.**
- **Făcute:** scriptul de pornire al clientului așteaptă folderele de lângă el (ecranul gol de la Play); cuvintele
  jocului pentru copii („tier" → „level", verbul din quest pe butonul cartonașului, fraze scurte); linia NEXT nu mai
  dispare după ultimul quest (`AmbitionMath`); pe „Welcome back" butonul auriu e cel gratuit; pictograme proprii
  pentru ofertele din Shop (`scripts/art/d63_shop_icons.py`; urcate, iar iconițele de 512 px din `assets/store/` au intrat pe
  pass-uri la creare).
- **Sonda din Studio** (`plugins/DriftwoodProbe.lua`, `scripts/probe.py`, `scripts/probe_server.py`) pornește și
  oprește singură un Play și citește clientul prin jurnalul Studio. Fereastra de editare o încarcă abia după o
  repornire a Studio-ului. Cu ea se verifică tot ce e nevăzut: `python3 scripts/probe.py play`, `wait-boot`, `errors`,
  `client texts`.
- **Era 1, jucată de sondă pe 2026-09-19, fără nicio eroare:** turul de mână, cele cinci angajări (36 de monede),
  peștele (21 de perle), primul decor, niveluri până la 32, linia fierului, clopotul; toate panourile satului fără
  text care nu încape sau se calcă (la 1704×809). Un joc de probă: `python3 scripts/probe.py play`, `wait-boot`, apoi
  `client fire:BuyPad:first_net` (aceleași cereri ca butoanele jocului; `AtSawmill:true` se retrimite la ~7 s),
  `dev coins:30`, `client ui:station:net:first_net`, `client texts:HUD`, `errors`, `stop`. Rulează mereu pe **profil de
  probă** (jocul scrie `save: probe run`), iar comenzile de dev sunt refuzate pe o salvare adevărată.
- **Ce NU vede sonda:** animațiile. Cât Studio e în fundal, clientul nu-și rulează tween-urile (contorul de monede
  rămâne în urmă, textele plutitoare îngheață): e artefact de test, nu defect. Sărbătorirea nivelurilor, bannerele și
  zborul monedelor le poate judeca doar owner-ul.
- **De făcut cu sonda, nu pe nevăzute:** textul e prea mic pe telefon (interfața e la 62%: 13 px → ~8 px). Cere
  emulatorul de dispozitiv din Studio pus pe un telefon.
- **Era 2 [D64]:** owner-ul a respins multiplicatoarele din D63. **Regula unei ere:** începi cu marfa apărută la
  finalul erei dinainte, iar spre final apare una nouă, cu plasa, atelierul și oamenii ei; fiecare eră își vinde marfa
  la clădirea ei (Era 2: o Piață). Roadmap-ul până la Era 8 e în D64 (a treia variantă; primele două, respinse): piese de mașini → cupru →
  curent electric → cristale → piese de navă → roboți → barje plutitoare → rachetă. Trei reguli: reperul fiecărei ere se
  face din ce produci deja, o singură poveste (scrap-ul din Era 1 vine de la o navă prăbușită în amonte), iar marfa nouă
  apare când o poți folosi. Fiecare renaștere = o planetă nouă; **se construiește doar Era 2**. Marfa nouă de la finalul Erei 2 e de
  confirmat (propus: cupru). Owner-ul, 2026-09-19 seara: „dacă totul are sens și logică în Era 1, se poate trece mai
  departe".
- **Economia Erei 2 [D65]** iese din `sim_tycoon.py` (rulează după Era 1, din starea ei): cadrul e un număr, M = 40
  (monedele cartierului nou × M, bucățile pe secundă ca în Era 1); ~57 de minute reale, 112/s → ~5.080/s, nicio
  cumpărătură care scade venitul. `scripts/economy/sim_era2.py` a rămas unealta de „ce-ar fi dacă" (nu e în poartă).
- **Motorul lanțului merge pe un tabel de linii (2026-09-19, pașii a–f din `docs/PLAN-MOTOR-N-LINII.md`).** Forma
  liniilor e dată: `LINE_ORDER` / `LINES` / `PROCESSORS` / `SELLERS`, în `sim_tycoon.py` și în `StationConfig`; restul
  tabelelor (`LINE_STEPS`, `LINK_OF`, `LINKS`, …) se derivă din ele. În `ChainMath`, `Flow` e adevărul, iar `Rates` e
  vederea plată a Erei 1, aceeași pe care o primește clientul. Era 1 e neschimbată la bit (tabelul de aur, 80.000 de
  stări la întâmplare față de motorul vechi). `check_lines.py` (rulat de simulator) și suita „liniile ca date" din
  `tests/ChainMath.test.luau` dovedesc cu linii de probă că motorul duce a treia linie și al doilea vânzător.
  **O eră nouă = rânduri în tabele**, plus ce a rămas scris pentru două linii (lista e la sfârșitul planului):
  deblocările și scara prețurilor din simulator, cusătura cu profilul din `StationService.StateFrom`, grămezile,
  meniurile, ghidajul. `State` rămâne plat: o clădire nouă își aduce câmpurile, citite după numele din tabel.
- **„De ce nu aduce nimic" are o singură regulă: `Shared/Modules/HeldBack`** (2026-09-19). Întâi câștigul real
  (`gain` > 0 → nu se scrie nimic), apoi veriga slabă a LINIEI lucrului, nu cea care ține tot venitul. O folosesc
  meniul obiectului, panoul Upgrades și cartonașul platformei. Panoul și cartonașul mințeau cu amândouă liniile
  pornite (rândul Tavernei scria „the Forge is slowest" deși un nivel la ea aducea cel mai mult). Un text nou de felul
  ăsta întreabă tot acolo.
- **Cifrele din colțul HUD-ului stau pe o grilă** (`Shared/Modules/HudLayout`, cu test): monede, perle și sac pe
  rândul de sus, rata și AWAY dedesubt, linia NEXT cât blocul. Văzut în Play-ul owner-ului cu sonda: cutiile cad pe
  grilă. Pozițiile pastilelor nu se mai scriu de mână în `HUDController`.
- **Colțul cu Robux e viu pe staging (2026-09-19):** owner-ul a dat cheii API (`bebe`) permisiunile `game-pass` și
  `developer-product`; `python3 scripts/create_monetization.py` a creat cele patru pass-uri și cele două produse
  (fără dubluri: întâi listează) și a scris ID-urile în `MonetizationConfig.IDS`. Prețurile se citesc de la Roblox;
  magazinul arată `R$ 799 / 149 / 349 / 199 / 99`. Pe producție se creează la lansare (`--universe production`).
  **Creatorul deține automat pass-urile lui:** în Play-urile owner-ului toate patru sunt active (venit dublu, pas iute),
  deci ritmul pe care îl simte el nu e al unui jucător obișnuit; se sting din rândul `robux` al consolei de dev.
  Play-urile de probă ale sondei nu întreabă Roblox ce deții.
- **Așteaptă owner-ul:** verificarea în Studio a lui D61–D63 (animațiile le vede doar el); emulatorul de dispozitiv pe un
  telefon, pentru textul mic; o cumpărare de test pe staging (costă Robux reali, deci doar cu acordul lui).

## Stare (2026-09-18)

**Planul aprobat pe 2026-09-18** (`~/.claude/plans/lexical-percolating-bunny.md`): D61 partea a doua (croitoreasa, poarta
satelor, colțul cu Robux), apoi D62 pașii 3–5 (darurile râului, undița și avizierul devreme, satul care crește la
vedere). Owner-ul: „tot ce știi sigur că funcționează, fără presupus. nu uita de monetizare".

**Croitoreasa și poarta satelor [D61, partea 2]** — comise, **neverificate încă în Studio.** Detaliile în DECIZII.
- **Croitoreasa (55d9056):** `Tailor (E)` la cort; `Look` gratuit (`LookMath`, profil **v12** `Village.look`) și ținutele
  (`TailorController`, remote-uri `BuyOutfit` / `WearOutfit` / `SetLook`). `UI/Portrait` e singurul desen de portret.
- **Patru ținute noi** (`festival`, `minstrel`, `lampkeeper`, `harvest`), urcate pe 2026-09-19, deci de vânzare. O
  ținută a cărei foaie lipsește (ID 0) scrie `Still being sewn`, iar serverul îi refuză cumpărarea (`"soon"`).
- **Poarta satelor:** vizita e o **fotografie** a satului gazdei, desenată în bâlci (`VillageLook` pur → `VisitService` →
  `VillageDiorama`), nu un teleport. `VisitController`: panoul porții, machetele, întunericul, `Back to the fair` (Q),
  cartea de oaspeți cu un like pe zi (`VisitMath`, profil **v13** `Fair.likes` / `Fair.liked`).
- **Mutate în module comune, ca să nu existe două liste:** alegerea desenului unei platforme (`UI/PadArt`, din
  `PadController`) și lista oamenilor (`VillageLook.hands`, din `HandService.Snapshot`).
- `CameraController.SetWorld` / `ResetWorld` și `CharacterController.Teleport` sunt noi și comune ambelor place-uri.
- De verificat cu doi clienți (Test → Clients and Servers) în `Balci.rbxl`.

**Colțul cu Robux [D61, partea 2]** — codul e gata, **nimic nu se vinde încă**: ID-urile din `MonetizationConfig.IDS` sunt
0, deci fiecare rând scrie `Opens soon`. **Neverificat încă în Studio.**
- **Catalogul:** `2x Flow`, `Swift Boots` (×1,5), `Long Nights` (48 h), `Supporter` (titlu, nume auriu, ținută), `One Hour
  of Flow` (doar în sat), `Welcome Back x2` (doar pe fereastra de revenire). Prețurile se citesc de la Roblox.
- **Servicii, montate în ambele place-uri:** `PassService` (copia din profil, `Purchases.passes`; un „nu" de la Roblox nu
  șterge nimic) și `PurchaseService` (singurul `ProcessReceipt`, tiparul ProfileStore; fereastra de cumpărare o deschide
  serverul, prin `RobuxBuy`). Efectele se citesc din profil prin `PassMath` (pur).
- **`2x Flow` stă pe `priceMult`, după `TycoonMath.stateFor`,** în `PadService.StateFor` și `StationService.StateFrom`.
  Formulele pure și testele de aur rămân neatinse; la schimbarea unui pass se golesc ambele cache-uri.
- **Client:** `ShopPanel` (comun; tasta P; în sat apare după prima vânzare), `Double it` pe `WelcomeController`,
  `CharacterController.SetSpeedFactor`, numele auriu în `PresenceController`. Profil **v14**.
- **De probă în Studio:** rândul `robux` din consola de dev; în `Balci.rbxl`, atributul `DevPasses` pe Workspace.
- **Așteaptă owner-ul:** crearea celor șase lucruri (sau permisiuni pe cheia API ca să le creez eu).
- **Taraba** cu copertină aurie e pe harta bâlciului din 2026-09-19 (`FairLayout.SPOTS.shop`, marginea `Shop`,
  `ShopController` cu cardul `Shop (E)`), iar fundalul bâlciului e recopt cu poteca și lumina ei.
- Trece poarta (485 de teste).

**Darurile râului [D62, pasul 3]** — comise, **neverificate încă în Studio.** La 56 s trece pe râu un butoi, o ladă sau
un buștean de aur; de pe punte, `Grab it (E)` dă monede cât 10 / 25 / 75 s din venitul de acum (cu minim).
- `DriftMath` (pur): program determinist pe sămânța râului și fereastra de timp, același pe server și pe client.
- `DriftService.Grab`: verifică momentul și `Stats.lastDrift` (profil **v15**), nu poziția. `DriftController`: desenul,
  cardul, camera care se mută lin spre dar (pe telefon râul din larg iese din ecran).
- **Nu intră în prețuri:** simulatorul doar afișează estimarea (~15% cu jumătate prinse). Amendează D59.
- Butoiul și lada pe apă sunt urcate (2026-09-19).

**Undița și avizierul, devreme [D62, pasul 4]** — comise, **neverificate încă în Studio.** `Catch a fish` s-a mutat în
capitolul 1, după al cincilea om; quest nou `Build something in your village` (felul `decor`, ținta `targetBoard`), cu
săgeată spre avizier chiar dacă ghidajul tace. La pasul acela ai cel puțin 21 de perle; primul decor costă 20.

**Satul crește la vedere [D62, pasul 5, prima parte]** — comis, **neverificat încă în Studio.**
- **De acum:** treapta meseriei ca cinci pătrățele deasupra acoperișului (`PadController`, din `crewTiers`) și fum la
  hornurile caselor mari și al tavernei (`PadArt.CHIMNEY`, `SceneArt.AddSmoke`).
- **Cu arta urcată (2026-09-19):** plasa pe ranguri la pragurile 10 / 25 / 50 (`ChainMath.rankOf`,
  `PadArt.netSprite`), insigna `Lv N` bronz / argint / aur (`Widgets.SetLevelBadgeRank`), păsările
  (`AmbientController`). O variantă care lipsește (ID 0) cade pe desenul de bază.

**Satul crește la vedere [D62, pasul 5, a doua parte]** (2026-09-19) — comis, arta urcată, **neverificat în Studio.**
- **Pământul satului copt** într-o singură imagine cu alfa (`scripts/art/village_ground.py` → `prop_village_ground`):
  uscatul opac, apa transparentă cu tente de adâncime, râul animat curge pe dedesubt. Geometria vine din joc prin
  `scripts/art/village_geometry.luau`. `SceneArt.BuildBackground` o folosește când e urcată; până atunci, dalele de azi.
- **După orice mutare în `TycoonConfig` (DECK, ROADS, YARDS, DECOR) sau în malurile din `RiverConfig`:** rulează din nou
  `python3 scripts/art/village_ground.py`, altfel pică poarta (`--check`, amprenta din `village_ground.lock`). La baraj
  (`WORLDS[2]`, `RiverConfig.WORLDS[2]`): `--world 2`, cu `dam_ground.lock` [k12]. După
  recoacere, imaginea trebuie urcată din nou, cu acordul owner-ului.
- **Clădirile la pragul 25:** gaterul, taverna și forja au a doua înfățișare (`scripts/art/d62_grand.py`,
  `ChainMath.isGrand`, `PadArt.station`). Depozitul nu are niveluri, deci nici variantă.

**Arta D61–D62, urcată pe 2026-09-19** după aprobarea owner-ului pe planșe: 22 de imagini noi și fundalul bâlciului
recopt, toate aprobate de moderare. Nimic desenat nu mai așteaptă (doar coafura `bald` are ID 0, intenționat: n-are
foaie). Starea moderării se citește cu `python3 scripts/upload_assets.py --status <nume...>`: o imagine respinsă rămâne
cu ID în `Assets.luau`, dar în joc se vede goală, iar jocul n-are cum să știe.

**De ce nu prinde jocul [D62]** — owner-ul: „nu te prinde deloc, nu mă atrage deloc". Auditul și cifrele sunt în
DECIZII D62; citește-l înainte de orice lucru nou pe sat. Comise și publicate pe staging, **nevăzute încă în Studio:**
- **Pasul 1 (86e4a62):** nivelurile și treptele se simt (`StationUpgraded` / `CrewUpgraded` / `QuestClaimed`, `UI/Pop`,
  banner la pragurile 10/25/50, bară până la prag în meniu). Recompensa capitolului se plătește în sfârșit.
- **Pasul 2 (5a12a14):** oamenii capitolului 1 costă 5/6/7/8/10 și vin în ~2 minute; oamenii fierului 700–1100. Era 1
  la 33m36s reali.
- **Sunetele `sfx_levelup` și `sfx_milestone`** sunt urcate și aprobate de moderare (bb301c1).
- **Planul din 2026-09-18 e scris în întregime.** Rămân aprobarea și urcarea artei, ID-urile pentru Robux și
  verificarea în Studio.
- **Unealtă:** `python3 scripts/economy/tune_tycoon.py eval NUME=valoare` încarcă simulatorul adevărat, suprascrie
  constante în memorie și măsoară porțile de ritm. Nu schimba constante din ochi: „jucătorul e veriga slabă" a stricat
  toată curba.

## Stare (2026-09-17)

**Iazul, gheretele, mesele [D61, partea 1]** — plan aprobat, comis pe pași (4c05c81 … fc3960b), CI verde, **publicat pe
staging** (ambele place-uri, 11:10Z). Trece poarta (442 de teste). **Neverificat încă în Studio.**
- **Iazul:** jetiul pe malul de sud, aceeași undiță ca acasă (`UI/FishingRig`, comun cu `PierController`).
- **Concursul:** runde de 6 min după ceas (`PondMath`, `PondService`), tabla pe mal, banda de sus, `Pond Champion`.
- **Gheretele:** `Ring Toss` și `Hook a Duck` (`BoothMath`, `BoothService`, `BoothController`); premiu doar la primele
  5 jocuri pe zi UTC; titlul `Sharpshooter`.
- **Mesele:** `Sit (E)` și Wave pe G (`SocialController`, `PresenceService`); muzicanții animați; melodia bâlciului, mai
  tare lângă ei (`MusicController.Init({Track, Proximity})`).
- **Profilul și rețeaua:** profil **v11**; `Crowd` poartă și flagurile stă jos / face cu mâna / pescuiește.
- **Rămâne pentru D61, partea a doua:** croitoreasa și poarta satelor. Colțul cu Robux vine după ce vedem bâlciul jucat.

**Bâlciul de seară [D60]** — comis (6f96cbf) și publicat pe staging (primul run complet verde: e89b842). Bâlciul s-a
văzut în Studio ca fișier local; barca și doi jucători se pot verifica doar pe staging. Detaliile în DECIZII D60.
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
- **Amânat pe D61:** poarta satelor, croitoreasa, colțul cu Robux (iazul și gheretele s-au făcut, vezi mai sus).

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
