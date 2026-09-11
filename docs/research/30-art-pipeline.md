# Pipeline de productie arta 2D pentru Driftwood

> Notă de scop: acest research acoperă **procesul de producție** al artei 2D (stil, tool-uri, dimensiuni, atlas packing, animație, outsourcing, naming, plan fazat). Limitele tehnice API/upload la nivel de motor (rezoluție reală de upload, `ImageRectOffset`/`ImageRectSize`, `ScaleType`, Open Cloud Assets API, moderare, Asphalt) sunt documentate în profunzime în `[object Object]1-sprites-assets.md` din același folder — nu le reiau exhaustiv aici, doar le citez unde afectează direct o decizie de producție, folosind aceleași surse ca să nu apară cifre contradictorii între cele două documente.

## Rezumat executiv

- **Rezoluție de lucru recomandată: mică-medie (64–512 px per element), nu 4K.** Roblox a anunțat suport 4096×4096 (30 ian. 2026), dar bug-uri raportate în mart. și iun. 2026 arată pagina de upload decal afișând în continuare limita veche de 1024×1024 — stare contradictorie, nerezolvată oficial (vezi `sprites-assets.md`). Proiectați arta pe premisa pesimistă (1024×1024 per foaie), nu pe cea optimistă.
- **Stil recomandat pentru Driftwood: pixel art low-res cu `ResampleMode.Pixelated`, sau flat/vector cu contur gros** — ambele citesc bine la dimensiuni mici de mobil. `Enum.ResamplerMode` are exact două valori: `Default` (0) și `Pixelated` (1) — sursă: create.roblox.com/docs/reference/engine/enums/ResamplerMode. `Pixelated` (nearest-neighbor) e documentat oficial ca fiind bun **doar la mărire**, nu la micșorare (produce aliasing) — sursă: devforum, 16 aug. 2021 (citat și în `sprites-assets.md`).
- **~80% din sesiunile Roblox sunt pe mobil** (surse secundare agregate, nu am găsit o pagină oficială Roblox cu cifra exactă) — orice sprite/UI trebuie citit clar la ~375–430px lățime de ecran fizic, nu doar pe monitor de Studio.
- **TexturePacker NU are exporter oficial Roblox** — exportă format generic JSON (frame → `{x,y,w,h}`), pe care trebuie să-l convertești tu într-un tabel Luau. Există o alternativă **complet gratuită**, tot de la CodeAndWeb: Free Sprite Sheet Packer (browser, fără cont, fără upload de imagini pe server).
- **Politica Roblox pe AI generativ acoperă explicit doar uneltele proprii Roblox** (Assistant, Texture/Material Generator, GenerationService) cu obligație de transparență/Content Maturity — **nu există o pagină oficială separată despre folosirea de imagini generate extern** (Midjourney, Stable Diffusion etc.) ca sprite-uri. Regula generală rămâne valabilă și acoperitoare: ești responsabil de drepturi indiferent dacă ai folosit AI, iar output brut de AI e slab protejabil legal — modifică-l manual ca să câștigi protecție (create.roblox.com/docs/generative-AI; devforum, 19 mart. 2024).
- **Afinity Designer/Photo au devenit GRATUITE pentru indivizi** (confirmat direct pe affinity.studio, accesat 8 sept. 2026) — schimbă calculul de cost al toolchain-ului pe macOS: nu mai trebuie plătit un editor vector/raster profesional.
- **Aseprite costă ~20 EUR (Steam)**, nu are build oficial confirmat nativ Apple Silicon (rulează prin Rosetta 2, sau te compilezi singur din sursă) — vs. **Krita**, complet gratuit și cross-platform.
- **Estimările de producție pentru 200 sprite-uri de item + 6 zone + UI variază enorm cu tier-ul de calitate** (calcul propriu, derivat din rate orare sursate — vezi secțiunea dedicată): de la ~200h la nivel placeholder până la peste 2000h la nivel "hand-painted polished". Diferența justifică direct planul fazat placeholder → vertical slice → lansare.
- **Rate de piață 2025-2026 pentru artiști 2D freelance**: mediana Upwork **25 USD/h** (interval 15-30 USD/h); agenții **25-80 USD/h** (Pixune); exemplu concret citat pe Reddit: **75 USD per sprite cu 4 direcții de mers**.
- **Talent Hub-ul Roblox există**, dar statusul actual de acces e neclar — un fir de discuție relativ recent arată utilizatori cărora li s-a blocat accesul ("the old place has been locked"). Nu vă bazați planul de recrutare exclusiv pe el fără să verificați direct în cont.

## Fapte verificate

- `Enum.ResamplerMode` are membrii **`Default` (0)** și **`Pixelated` (1)** — sursă: create.roblox.com/docs/reference/engine/enums/ResamplerMode, accesat 2026-09-08 — confidence: ridicata
- Proprietatea `ResampleMode` de pe `ImageLabel`/`ImageButton` a fost introdusă **16 aug. 2021**; `Pixelated` = nearest-neighbor, recomandat oficial doar la **mărirea** imaginii, nu la micșorare — sursă: devforum.roblox.com/t/resamplemode-new-property-for-image-gui-objects/1418681 — confidence: ridicata (dar sursă din 2021, verificați dacă comportamentul s-a extins de atunci)
- Roblox a anunțat suport de textură până la **4096×4096 (4K)** pentru `MeshPart`, `SurfaceAppearance`, `Texture`, `Decal`, `MaterialVariant` — sursă: devforum.roblox.com/t/4k-texture-rendering/4316229, 30 ian. 2026 — confidence: medie (contrazis de rapoarte de bug ulterioare, vezi `sprites-assets.md`)
- Documentația de specificații textură recomandă rezoluții proporționale cu dimensiunea obiectului 3D (ex. 256×256 pentru un obiect de 5×5 studs), NU e o pagină despre UI 2D în `ScreenGui` — sursă: create.roblox.com/docs/en-us/art/modeling/texture-specifications.md, accesat 2026-09-08 — confidence: ridicata (dar aplicabilitate directă la sprite-uri de `ImageLabel` NEVERIFICATĂ explicit)
- Mărimea de referință recomandată pentru icoana unui experience Roblox e **512×512 px**, pătrat, scalat ulterior până la ~150×150 în diverse locuri din platformă — sursă: create.roblox.com/docs/en-us/production/publishing/experience-icons.md, accesat 2026-09-08 — confidence: ridicata
- Publicarea de asset-uri de tip imagine către Creator Store are plafon de **200/30 zile pentru conturi verificate** și **10/30 zile pentru conturi neverificate** — sursă: create.roblox.com/docs/production/publishing/publishing-assets, accesat 2026-09-08 — confidence: medie (nu e clar dacă acest plafon se aplică și importului privat de sprite-uri pentru propriul joc, spre deosebire de publicarea publică pe Creator Store — **de testat**)
- `Enum.ScreenInsets` are membrii **`None` (0)**, **`DeviceSafeInsets` (1)**, **`CoreUISafeInsets` (2)**, **`TopbarSafeInsets` (3)** — sursă: create.roblox.com/docs/reference/engine/enums/ScreenInsets, accesat 2026-09-08 — confidence: ridicata
- Regula oficială de transparență AI: pentru interacțiuni AI extinse într-un experience e necesară eticheta de maturitate **Restricted (18+)** în chestionarul de Content Maturity, plus notificări clare la utilizator la începutul și pe parcursul sesiunii — sursă: create.roblox.com/docs/generative-AI, accesat 2026-09-08 — confidence: ridicata (dar se referă la AI **interactiv în joc**, nu la art assets statice create offline cu AI)
- "You are responsible for ensuring you have the rights to anything you upload to Roblox, regardless of whether you use generative AI" — și output-ul pur generat de AI are protecție IP limitată; modificarea lui manuală crește protejabilitatea — sursă: devforum.roblox.com/t/protecting-intellectual-property-when-using-generative-ai/2881851, 19 mart. 2024, 19:43 — confidence: ridicata (politică veche de peste 2 ani, dar necontrazisă de surse mai noi găsite)
- Community Standards interzice conținut sexual/nuditate (inclusiv straturi de modestie transparente), depicții realiste de gore/violență extremă/moarte, și arme de foc moderne realiste în afara item-urilor de joc; aplică takedown pentru infracțiuni de proprietate intelectuală — sursă: about.roblox.com/community-standards, accesat 2026-09-08 — confidence: ridicata
- Marketplace Policy (pentru item-uri de catalog/avatar, nu neapărat decal-uri de joc) interzice folosirea brandingului oficial Roblox, duplicarea item-urilor existente, lipsa autorizării IP, text excesiv pe imagine, și obscurarea UI/avatarelor altor jucători — sursă: create.roblox.com/docs/en-us/marketplace/marketplace-policy.md, accesat 2026-09-08 — confidence: ridicata
- TexturePacker (CodeAndWeb) susține "48+ game engine" în export nativ, dar **Roblox nu apare pe listă**; oferă totuși format JSON/XML generic — sursă: codeandweb.com/texturepacker, accesat 2026-09-08 — confidence: medie (pagină de marketing, nu documentație tehnică exhaustivă)
- Free Sprite Sheet Packer (CodeAndWeb) e gratuit, rulează 100% în browser, fără upload pe server, exportă format JSON hash/array (compatibil Phaser/PixiJS) — sursă: codeandweb.com/free-sprite-sheet-packer, accesat 2026-09-08 — confidence: ridicata
- **Aseprite** costă **20,49 EUR** pe Steam; cerințe minime macOS: **macOS 10.15+**, 128MB RAM — sursă: store.steampowered.com/app/431730/Aseprite/, accesat 2026-09-08 — confidence: ridicata
- Nu există build oficial confirmat nativ Apple Silicon (arm64) pentru Aseprite în sursele găsite; comunitatea întreține scripturi separate de compilare pentru M1/M2/M3 — sursă: căutare comunitară (GitHub, scripturi de build M1), accesat 2026-09-08 — confidence: scazuta (posibil ca Aseprite să fi adăugat build universal între timp — **de verificat direct pe pagina de download**)
- **Affinity Designer/Photo/Publisher sunt gratuite pentru indivizi**, fără abonament, fără licență plătită, disponibile pentru Mac și Windows (iPad "coming soon" la data accesării) — sursă: affinity.studio, accesat 2026-09-08 — confidence: ridicata (dar data exactă a tranziției la modelul gratuit NEVERIFICATĂ cu certitudine — o sursă secundară menționează 16 iul. 2026)
- **Krita** e gratuit și open-source, cross-platform inclusiv macOS — confirmare din surse secundare multiple (menționare versiune 5.2), fapt de notorietate generală în comunitatea de artă digitală — confidence: ridicata
- **Procreate rulează doar pe iPad**, nu pe macOS desktop; preț de la 12,99 USD (nivel de bază), cu o creștere de preț menționată pentru 2024 — surse secundare — confidence: medie (preț exact 2026 NEVERIFICAT)
- **~80% din sesiunile Roblox provin de pe mobil**, mobilul generând ~46% din veniturile Robux — surse secundare agregate (RoWatcher, XtendedView, Statista dec. 2024, Pocket Gamer Biz apr. 2025) — **nicio sursă oficială Roblox nu a fost accesată direct cu această cifră exactă** — confidence: medie
- Talent Hub Roblox a lansat în **Open Beta pe 6 aug. 2021** — sursă: devforum.roblox.com/t/introducing-talent-hub-open-beta-new-platform-to-find-post-work/1396502 — confidence: medie (**sursă din 2021, pre-2024 — flag explicit de posibilă perimare**); un fir mai recent arată utilizatori raportând acces blocat la platforma "veche" — sursă: devforum.roblox.com/t/how-do-i-get-access-to-the-roblox-talent-hub/1504768 — confidence: scazuta pentru statusul actual de acces
- Rate de piață pentru artiști 2D freelance (2025-2026, toate surse secundare): mediana Upwork **25 USD/h** (interval 15-30) — upwork.com/hire/2d-game-art-freelancers/cost/; agenții **25-80 USD/h** — pixune.com/blog/game-art-outsourcing-price/; exemplu concret **75 USD/sprite cu 4 direcții de mers** — reddit.com/r/gamedev/comments/1ditoxy — confidence: medie (variație mare, anecdotic)
- ImageRectOffset/ImageRectSize (necesare pentru orice atlas/spritesheet) **nu funcționează cu `ScaleType.Tile`**, confirmat oficial de staff Roblox 6 feb. 2025 — sursă citată complet în `sprites-assets.md` (devforum.roblox.com/t/imagerectoffsetsize-does-not-work-with-tile-scaletype/3409510) — confidence: ridicata — **relevant direct pentru planul de parallax**: fundalurile care trebuie să facă tile nu pot fi cadre dintr-un atlas, trebuie imagini proprii.
- **Lune** (lune-org/lune), un runtime standalone Luau cu biblioteci `fs`/`net`/`serde` incluse, e la versiunea **0.10.5** (2 iul. 2026), licență MPL-2.0 — sursă: github.com/lune-org/lune, accesat 2026-09-08 — confidence: ridicata — util pentru a scrie generatorul de manifest **direct în Luau**, în loc de Python/Node.

## Detalii

### 1. Alegerea stilului: pixel art vs. vector/flat vs. hand-painted

Trei opțiuni realiste pentru un joc solo/echipă mică pe Roblox, cu argumente specifice Driftwood (2D pur în `ScreenGui`, retenție prin claritate de informație — jucătorul trebuie să recunoască instant ce a prins plasa):

| Stil | Avantaje pt. Driftwood | Riscuri | Resample recomandat |
|---|---|---|---|
| **Pixel art low-res** (16-64px "canvas" nativ, afișat scalat) | Citire instant la mărime mică; costă mai puțin per sprite (mai puține detalii de pictat); Aseprite e făcut exact pentru asta | Trebuie disciplină de paletă/grid, altfel arată amator; scalare non-integer (ex. 1.3x) produce artefacte vizibile chiar și cu `Pixelated` | `Enum.ResamplerMode.Pixelated`, DOAR când sprite-ul e afișat **mai mare** decât rezoluția nativă (documentat oficial ca sigur doar la mărire) |
| **Flat/vector cu contur gros** (stil "iconic", puține culori, umbre plate) | Se scalează fără artefacte la orice mărime (surse vectoriale în Figma/Affinity Designer, apoi export raster la rezoluția finală); ușor de menținut consecvent între 200 item-uri de echipe/artiști diferiți | Poate arăta generic/steril dacă nu are un "hook" vizual distinctiv | `Default` (bilinear) |
| **Hand-painted** (umbrire pictată, textură organică) | Aspect premium, potrivit tematic cu "orășel pe malul unui râu" | Cel mai scump per sprite (vezi estimările de mai jos); risc mare de inconsistență de stil între 200+ item-uri dacă nu ai un artist unic/foarte disciplinat cu un style guide strict | `Default` |

**Recomandare pentru Driftwood**: pixel art low-res sau flat/vector — nu hand-painted la lansare. Motivul nu e doar cost: cu ~80% din sesiuni pe mobil (cifră secundară, dar consistentă între mai multe surse) și cu incertitudinea privind rezoluția reală de upload (4K promis vs. 1024×1024 raportat încă activ în bug-uri din 2026), un stil care se bazează pe detalii fine pictate e cel mai expus la degradare vizuală la scalare/compresie.

### 2. Rezoluție de referință și plan de scalare

Nu există în documentația Roblox un "canvas de referință" oficial pentru `ScreenGui` (documentația de `position-and-size` vorbește despre `Scale` vs `Offset`, nu despre o rezoluție fixă de proiectare — sursă: create.roblox.com/docs/en-us/ui/position-and-size.md). Recomandare practică (nu e o regulă Roblox, e o convenție standard de dev 2D):

1. Proiectați layout-ul UI/scenă la o rezoluție de referință de **1280×720** (16:9), cu toate poziționările în `Scale` (procent din `AbsoluteSize` al containerului), nu în `Offset` fix.
2. Exportați fiecare sprite individual la rezoluția lui **nativă țintă** (vezi tabelul din secțiunea 4) — nu upscalați "ca să fie sigur"; documentat empiric (în `sprites-assets.md`) că imaginile încărcate mult peste dimensiunea de afișare arată, după downscale-ul intern Roblox, mai neclare decât una încărcată direct la rezoluția corectă.
3. Folosiți `UIAspectRatioConstraint` pentru elemente care nu trebuie deformate la rapoarte de aspect diferite (portret pe telefon vs. landscape pe desktop) — documentat generic în ghidul de design adaptiv (create.roblox.com/docs/en-us/production/publishing/adaptive-design.md), fără cifre exacte de breakpoint furnizate oficial.
4. Pentru fundalul general al scenei de joc (nu meniuri), folosiți `ScreenGui.ScreenInsets = Enum.ScreenInsets.None` ca fundalul să acopere tot ecranul fizic, inclusiv sub notch/gesture bar; pentru HUD-ul cu butoane interactive folosiți `DeviceSafeInsets` ca butoanele să nu cadă sub zone neatingibile — enum confirmat oficial (create.roblox.com/docs/reference/engine/enums/ScreenInsets).

### 3. Tool-uri pe macOS — tabel comparativ

| Tool | Preț (accesat 2026-09-08) | Nativ Apple Silicon? | Rol în pipeline Driftwood | Sursă |
|---|---|---|---|---|
| **Aseprite** | 20,49 EUR (Steam), licență pe viață | NEVERIFICAT — fără build arm64 oficial confirmat; rulează prin Rosetta 2 sau auto-compilare | Sprite-uri de item, animații pe grid, export nativ de spritesheet + CLI batch | store.steampowered.com/app/431730/Aseprite |
| **Krita** | Gratuit, open-source | Da (cross-platform, comunitate confirmă) | Pictură/hand-painted pentru fundaluri și elemente mai mari, alternativă gratuită la Photoshop | notorietate generală, confirmată secundar |
| **Affinity Designer/Photo** | **Gratuit pentru indivizi** (schimbare recentă, Canva) | Da (Mac nativ) | Vector pentru iconițe UI scalabile, retuș/compunere fundaluri, export batch | affinity.studio |
| **Figma** | Nivel gratuit disponibil pentru proiecte mici (limite exacte 2026 NEVERIFICATE — nu am accesat pagina de pricing curentă) | Rulează în browser/app Electron, nu e un binar "nativ" clasic | Wireframe/layout UI, colaborare cu un artist extern pe mockup-uri, handoff de specificații (spacing, culori) — NU pentru export de sprite-uri finale în joc | cunoștință generală, NEVERIFICAT pt. prețuri 2026 |
| **Procreate** | de la 12,99 USD | N/A — **doar iPad**, nu macOS desktop | Opțional, doar dacă echipa are și tabletă iPad; nu înlocuiește Aseprite/Krita pe Mac | surse secundare |

### 4. Dimensiuni recomandate de sprite pentru obiecte de râu/plase/fundaluri

Nu există o pagină Roblox oficială cu dimensiuni recomandate specifice pentru sprite-uri de `ImageLabel` într-un joc 2D (specificațiile găsite oficial, texture-specifications.md, sunt pentru texturi 3D pe obiecte cu dimensiune în studs — aplicabilitate la `ImageLabel` NEVERIFICATĂ explicit). Tabelul de mai jos e o **propunere de lucru**, nu un fapt sursă externă:

| Categorie | Dimensiune nativă propusă | Note |
|---|---|---|
| Iconiță item (index reparații, 200 obiecte) | 64×64 sau 128×128 px | Două stări minim: spart + reparat; pătrat, fundal transparent PNG |
| Obiect plutitor pe râu (randat direct în scenă) | 96×96 – 192×192 px | Depinde de "mărimea" logică a obiectului în joc; animație opțională (plutire/rotire ușoară) |
| Plasă (net) — stări | 128×128 – 256×256 px per cadru | Minim 3 stări: goală, prinde (animație scurtă), plină |
| Panou UI (atelier, magazin) cu 9-slice | Sursă 64×64 – 128×128 px, `SliceCenter` central mic | 9-slice reduce nevoia de a picta panouri mari la rezoluție mare |
| Layer de fundal (parallax, per zonă) | 1024–2048 px lățime × 400–600 px înălțime, croit să facă tile orizontal fără cusătură vizibilă | 6 zone × 3-4 layere = ~18-24 imagini; **nu** le puneți într-un atlas cu crop (`ScaleType.Tile` incompatibil cu `ImageRectOffset`, confirmat oficial — vezi `sprites-assets.md`) |
| Iconiță HUD (bani, materiale, notificări) | 32×32 sau 48×48 px | Set mic, refolosit masiv — bun candidat pentru un singur atlas comun |

### 5. Atlas packing (TexturePacker și alternative) + workflow spre Luau

TexturePacker **nu are un exporter dedicat Roblox** din cele "48+ game engine" susținute nativ (sursă: codeandweb.com/texturepacker) — dar exportul lui **generic JSON (Array)** e ușor de convertit: fiecare `frame` are `{x, y, w, h}` în pixeli, care se mapează 1:1 pe `ImageRectOffset = Vector2.new(x, y)` și `ImageRectSize = Vector2.new(w, h)`.

Alternativă **100% gratuită**: **Free Sprite Sheet Packer** (codeandweb.com/free-sprite-sheet-packer) — rulează în browser, fără cont, fără upload pe server extern, exportă exact același format JSON hash/array. Pentru 200+ item-uri mici, e suficient și elimină costul licenței TexturePacker complet.

Alternativă nativă din Aseprite: `aseprite --batch --sheet out.png --data out.json <input files>` — un singur pas de linie de comandă exportă atât foaia de sprite-uri, cât și JSON-ul cu coordonatele fiecărui cadru (confirmat în `sprites-assets.md`, secundar din documentația Aseprite CLI).

**Fluxul recomandat, capăt-la-capăt:**

1. Pictezi sprite-urile individuale în Aseprite/Krita/Affinity, exportate ca PNG-uri separate în `assets/export/<categorie>/`.
2. Le împachetezi pe categorie (item-uri unelte, item-uri lăzi, iconițe HUD etc.) cu Free Sprite Sheet Packer sau `aseprite --batch --sheet`, obținând `<categorie>.png` + `<categorie>.json`.
3. Urci fiecare `<categorie>.png` ca un singur asset `Image` prin **Asphalt** (github.com/jackTabsCode/asphalt — vezi `sprites-assets.md` pentru detalii complete de configurare `asphalt.toml`), care generează automat un manifest Luau cu asset id-ul foii.
4. Rulezi generatorul de manifest (secțiunea 12 de mai jos) care combină asset id-ul din manifestul Asphalt cu coordonatele `{x,y,w,h}` din JSON-ul de atlas, producând un singur `SpriteAtlas.luau` cu `ImageRectOffset`/`ImageRectSize` per nume de sprite.

Acest flux reduce numărul de asset-uri urcate individual de la 200+ la câteva zeci (una per categorie/foaie), consistent cu recomandarea #2 din `sprites-assets.md` de a reduce expunerea la coada de moderare.

### 6. Bugete de cadre pentru animație

Nu există o regulă Roblox oficială de "câte cadre" pentru o animație de spritesheet — e o decizie de design/buget. Reguli de bun-simț pentru un joc 2D de retenție, nu un beat-em-up cu acțiune rapidă:

- **Idle/plutire obiecte pe râu**: 2-4 cadre, loop lent (bob vertical ușor) — suficient pentru "viu", nu costă mult.
- **Plasă — cast (aruncare)**: 4-6 cadre, joacă o singură dată.
- **Plasă — prindere**: 3-5 cadre, declanșată de eveniment (server confirmă captura, apoi clientul redă animația).
- **Reparat (unealtă/atelier)**: 2-3 cadre pentru o stare de "lucru în curs" (particule/scântei), restul timpului fiind afișat static cu progress bar — reparația durează real-time/offline, nu are sens o animație lungă rulând constant pe ecran.

Modulul comunitar **SpriteClip2** (documentat complet în `sprites-assets.md`) acoperă redarea grid-based a acestor animații — nu reinventați playerul de animație.

### 7. Specificații de fundal parallax (2D pur, ScreenGui)

**Nu am găsit un tutorial oficial Roblox pentru parallax într-un `ScreenGui` pur.** Singurul fir relevant găsit pe DevForum ("An example of a Parallax UI system", 8 iun. 2025) descrie o tehnică bazată pe cameră 3D + `SurfaceGui` pentru a simula profunzime la HUD-uri de tip mech — **nu se aplică direct arhitecturii Driftwood** (fără 3D deloc, per CLAUDE.md). Tehnica de mai jos e cunoștință generală de dezvoltare 2D, nu o sursă Roblox specifică — marcată explicit ca atare:

- Fiecare layer de fundal (cer, munți îndepărtați, copaci apropiați, mal) e un `ImageLabel` separat, **nu** un cadru dintr-un atlas (incompatibilitate confirmată `ImageRectOffset` + `ScaleType.Tile`, vezi mai sus).
- Fiecare layer are lățimea sursă suficient de mare încât să nu se repete vizibil pe durata unei sesiuni tipice, SAU (mai eficient) se pun **două copii identice** cap la cap ale aceluiași `ImageLabel`, poziționate una imediat după cealaltă pe axa X; când prima iese complet din ecran, se resetează instant în spatele celei de-a doua (wrap fără cusătură).
- Viteza fiecărui layer e proporțională cu "adâncimea" lui — layerele din fundal se mișcă mai încet decât cele din prim-plan, proporțional cu viteza curentă a râului (care variază deja pe sezon, per CLAUDE.md) — folosiți un multiplicator fix per layer (ex. fundal îndepărtat ×0.2, mal apropiat ×1.0) înmulțit cu viteza curentă a râului.
- Mișcarea se face pe `Position.X.Scale` (nu `Offset`) în `RenderStepped`/`Heartbeat`, cu `dt` din delta-time pentru independență de framerate.

### 8. Politica Roblox privind arta generată de AI

Există **două politici oficiale distincte**, niciuna nu acoperă explicit "am generat un sprite cu Midjourney și îl încarc ca Decal":

1. **create.roblox.com/docs/generative-AI** — guvernează folosirea uneltelor **proprii Roblox** (Assistant, Material/Texture Generator, Code Assist, `GenerationService`). Cere: conformitate cu Community Standards (conținutul care încalcă regulile "is not served to users" automat pentru API-urile Roblox), și, pentru **AI interactiv în joc** (chat/imagini/3D generate la cererea jucătorului), etichetă obligatorie **Restricted (18+)** în Content Maturity plus notificări explicite către utilizator. **Nu se aplică** la un sprite static creat offline cu un tool AI extern și încărcat manual ca asset.
2. **devforum.roblox.com/t/protecting-intellectual-property-when-using-generative-ai** (19 mart. 2024) — politica generală de IP: ești responsabil de drepturi indiferent de tool folosit; nu introduce nume de branduri/celebrități/IP-uri străine în prompt; output-ul pur AI-generat (neatins) are protecție legală proprie limitată — **modifică-l manual** (recolorare, retușare, integrare cu elemente desenate de mână) ca să câștige protejabilitate.

**Concluzie practică pentru Driftwood**: nu există o obligație oficială de "disclosure" pe fiecare sprite generat cu AI extern, dar există risc legal real dacă output-ul e folosit brut și nemodificat (protecție IP slabă asupra propriei voastre arte — oricine poate folosi aceleași instrumente pentru a genera ceva similar). Comunitatea semnalează informal (secundar, X/bloxpulse) că disclosure-ul pentru thumbnail-uri AI e rar respectat în practică — nu vă bazați pe asta ca precedent, regulile scrise sunt cele de mai sus.

### 9. Capcane de moderare specifice artei

Pe lângă regulile explicite din Community Standards (nuditate, gore realist, arme de foc realiste, IP), practica raportată de comunitate (surse secundare, neconfirmate oficial) arată **fals-pozitive frecvente**:

- Figuri umanoide desenate simplu sunt uneori marcate eronat ca fiind conținut nepotrivit.
- Texturi abstracte/decorative (gradient, pattern) sunt uneori respinse fără motiv aparent — atribuit clasificatorului automat, nu unei reguli explicite.
- Apelul se face prin "Violations & Appeals" sau formularul de Support (detaliat complet cu termene exacte de 30 zile/6 luni UE în `sprites-assets.md`).

**Implicație de plan**: pentru 200 de item-uri + fundaluri + UI, așteptați-vă la un procent mic dar nenul de respingeri fals-pozitive care necesită re-upload sau apel — nu programați lansarea imediat după un upload masiv, lăsați marjă de câteva zile (nu doar "câteva ore" cât spune documentația oficială — vezi riscurile din `sprites-assets.md`).

### 10. Estimări de producție — 200 sprite-uri item + 6 zone + UI

**Important**: cifrele din tabelul de mai jos sunt un **calcul derivat de acest research**, nu un fapt citat dintr-o sursă externă unică. Metodologia: am pornit de la scope-ul Driftwood (200 item-uri × 2 stări = 400 iconițe; 6 zone × ~4 layere = 24 fundaluri; ~80 elemente UI; ~60 cadre de animație pentru plase/obiecte) și am aplicat timp-per-element pe 3 tier-uri de calitate, apoi am convertit în cost folosind ratele de piață sursate mai sus (Upwork 25 USD/h median, Pixune 25-80 USD/h agenție).

| Tier | Iconițe item (400 buc.) | Fundaluri (24 layere) | UI (~80 elem.) | Animație (~60 cadre) | **Total ore** | **Cost estimat (25-50 USD/h)** |
|---|---|---|---|---|---|---|
| **1 — Placeholder** (formă simplă, culoare solidă, fără umbre) | 0,3h/buc → 120h | 1h/layer → 24h | 0,5h/elem → 40h | 0,5h/cadru → 30h | **~214h** (~5-6 săpt. full-time, 1 pers.) | ~5.350-10.700 USD |
| **2 — Producție/stilizat** (contur, umbre plate, coerent stilistic — nivel "soft launch") | 1,25h/buc → 500h | 6h/layer → 144h | 1,5h/elem → 120h | 1h/cadru → 60h | **~824h** (~20-21 săpt., ~5 luni, 1 pers.) | ~20.600-41.200 USD |
| **3 — Hand-painted/polished** (umbrire detaliată, variație, iluminare) | 3,5h/buc → 1400h | 16h/layer → 384h | 3h/elem → 240h | 2h/cadru → 120h | **~2144h** (~53 săpt., ~1 an, 1 pers.) | ~53.600-107.200 USD |

Reperul extern folosit pentru calibrare (nu inventat): "two hours per frame... at a salary of $20-$30 per hour" pentru animație de personaj, citat din 2dwillneverdie.com (sursă secundară) — aplicat proporțional pe tier-ul 2/3 de mai sus. Interval mare între tier-uri = argumentul central pentru planul fazat de la secțiunea 13: **nu proiectați bugetul de artă pe tier-ul 3 pentru lansare**.

### 11. Outsourcing — Talent Hub, Fiverr, ArtStation

| Canal | Rată tipică (2025-2026, surse secundare) | Note | Sursă |
|---|---|---|---|
| **Upwork** | mediană **25 USD/h**, interval 15-30 USD/h | Cel mai documentat interval, pagină dedicată de pricing | upwork.com/hire/2d-game-art-freelancers/cost/ |
| **Agenții outsourcing** (ex. Pixune) | **25-80 USD/h** | Preț mai mare, dar management de proiect inclus, util pt. volum de 200+ sprite-uri | pixune.com/blog/game-art-outsourcing-price/ |
| **Fiverr** | preț per proiect, nu per oră — necotat exact în cercetare | Multe pachete "Roblox art" dedicate; verificați portofoliul individual înainte de angajare | fiverr.com/gigs/roblox-art |
| **Reddit r/gamedev (anecdotă)** | **75 USD/sprite** cu 4 direcții de mers | Un singur exemplu, nu o medie de piață | reddit.com/r/gamedev/comments/1ditoxy |
| **Roblox Talent Hub** | Necotat (fără informații de preț în anunțul oficial) | Status de acces actual **neclar** (posibil restricționat față de 2021) — verificați direct în contul Creator Dashboard | devforum.roblox.com (2021, + fir 2025 despre acces blocat) |
| **RoHire, Devoted Fusion** (agregatoare comunitare de joburi Roblox) | Necotat | **Surse secundare, neverificate independent** — verificați legitimitatea înainte de a plăti orice avans | găsite via căutare, nu verificate în profunzime |

**Contracte și drepturi**: politica oficială de IP (secțiunea 8) se aplică indiferent de cine desenează — cereți explicit în contract transfer complet de drepturi (work-for-hire / cesiune de drepturi patrimoniale) pentru orice sprite comandat extern, altfel riscați ca artistul să poată revinde/refolosi aceleași asset-uri altui client, inclusiv unui concurent. Niciun detaliu oficial Roblox despre clauze contractuale standard nu a fost găsit — aceasta e practică generală de industrie, nu o regulă Roblox.

### 12. Convenții de naming/versionare + generator de manifest în Luau

**Convenție de naming propusă** (nu e un standard Roblox, e o propunere de lucru pentru consistență pe 200+ fișiere):

```
<categorie>_<slug>[_<variantă>][_<stare>][_f<NN>].png

item_lantern-bronze_broken.png
item_lantern-bronze_repaired.png
zone_downstream_bg-far.png
zone_downstream_bg-mid.png
ui_icon_workshop-slot.png
net_basic_cast_f03.png
```

Categorii fixe: `item`, `zone`, `ui`, `net`, `fx`. Slug în kebab-case, fără spații/diacritice. Sufixul `_fNN` (2 cifre) doar pentru cadre de animație secvențială.

**Structură de foldere propusă:**

```
assets/
  src/              -- fișiere sursă .aseprite / .kra / .afdesign (git-lfs recomandat, sunt binare)
  export/<categorie>/  -- PNG-uri flat, exportate determinist (script, nu manual)
  atlas/<categorie>.json  -- coordonate frame, din Free Sprite Sheet Packer / aseprite --batch
  asphalt.toml      -- config Asphalt pentru upload + manifest de asset id
```

**Versionare**: nu redenumiți fișierul la fiecare retuș (asta rupe orice referință). Țineți un `CHANGELOG.md` per categorie cu data și tier-ul ("2026-09-10: item_lantern-bronze trecut de la tier 1 la tier 2"), ca să puteți filtra rapid ce mai are nevoie de o trecere de artă înainte de lansare.

**Generator de manifest — scris în Luau, rulat prin Lune** (lune-org/lune v0.10.5, confirmat activ — vezi Fapte verificate). Ideea: combină manifestul de asset id-uri generat de Asphalt cu coordonatele `{x,y,w,h}` din JSON-ul de atlas, producând un singur modul cu tot ce are nevoie codul de joc:

```lua
-- generate_atlas.luau — rulat cu `lune run generate_atlas`
-- ATENȚIE: sintaxa exactă a modulelor @lune/fs și @lune/serde trebuie verificată
-- în documentația curentă (lune-org.github.io/docs) — API-ul se poate schimba.
local fs = require("@lune/fs")
local serde = require("@lune/serde")

local ASSET_IDS = require("./AsphaltManifest") -- generat de Asphalt: { ["items.png"] = "rbxassetid://123..." }
local ATLAS_DIR = "assets/atlas"

local output = { Sheets = {} }

for _, fileName in fs.readDir(ATLAS_DIR) do
	if fileName:match("%.json$") then
		local raw = fs.readFile(ATLAS_DIR .. "/" .. fileName)
		local atlas = serde.decode("json", raw) -- { frames = { [name] = { frame = {x,y,w,h} } } }
		local sheetKey = fileName:gsub("%.json$", "")
		local imageId = ASSET_IDS[sheetKey .. ".png"]

		local sprites = {}
		for spriteName, data in atlas.frames do
			sprites[spriteName] = {
				Offset = Vector2.new(data.frame.x, data.frame.y),
				Size = Vector2.new(data.frame.w, data.frame.h),
			}
		end

		output.Sheets[sheetKey] = { ImageId = imageId, Sprites = sprites }
	end
end

fs.writeFile("src/shared/SpriteAtlas.luau",
	"return " .. serde.encode("json", output)) -- sau serializare manuală ca tabel Luau, nu JSON, pt. performanță la require()
```

Modulul rezultat (`SpriteAtlas.luau`) se consumă în cod astfel:

```lua
local SpriteAtlas = require(ReplicatedStorage.SpriteAtlas)

local function applySprite(imageLabel: ImageLabel, sheetKey: string, spriteName: string)
	local sheet = SpriteAtlas.Sheets[sheetKey]
	local sprite = sheet.Sprites[spriteName]
	imageLabel.Image = sheet.ImageId
	imageLabel.ImageRectOffset = sprite.Offset
	imageLabel.ImageRectSize = sprite.Size
end

applySprite(itemIcon, "items", "lantern-bronze_repaired")
```

Acest pattern elimină complet gestionarea manuală a ID-urilor și coordonatelor pentru 200+ sprite-uri — un singur fișier generat, regenerat automat de fiecare dată când rulați exportul + Asphalt.

### 13. Plan fazat: placeholder → vertical slice → lansare

1. **Placeholder (tier 1, ~200h calculate mai sus)** — forme geometrice simple, culoare solidă per categorie de item (ex. toate uneltele = albastru, toate lăzile = maro), fără animație reală (poate un singur cadru de "bob"). Scop: testabil de oameni reali cât mai repede, conform regulii din CLAUDE.md ("Nu trece la pasul următor până cel anterior nu e testat"). Tool: Aseprite/Krita, export direct, fără atlas (număr mic de sprite-uri unice la acest punct — doar prototipul din pasul 1 al ordinii de lucru din CLAUDE.md: râul, un tip de obiect, plasă simplă).
2. **Vertical slice (tier 2 parțial, ~1 zonă completă + set reprezentativ de item-uri, nu toate 200)** — o singură zonă (fundal complet cu parallax, 15-20 item-uri reprezentative din categorii diferite, UI-ul de bază: HUD, atelier, index colecție) la calitate de "producție" (tier 2). Scop: validează stilul vizual final și pipeline-ul tehnic complet (export → atlas → Asphalt → manifest Luau → randare în joc) la scară mică, înainte de a-l aplica la 200 de item-uri. Aici decideți DEFINITIV stilul (secțiunea 1) — schimbarea lui după acest punct costă tot ce ați produs până atunci.
3. **Lansare (tier 2 complet pe toate cele 200 item-uri + 6 zone + UI, ~824h calculate mai sus)** — aplicați pipeline-ul validat la vertical slice la scară completă. Tier 3 (hand-painted) rămâne opțiune post-lansare pentru item-urile cele mai vizibile/rare (ex. obiectele de iarnă, epavele valoroase din CLAUDE.md), nu pentru toate 200 de la început — consistent cu principiul de retenție din CLAUDE.md (colecțiile incomplete/vizibile motivează revenirea; un "art pass" vizibil de îmbunătățire a item-urilor rare poate fi el însuși un motiv de revenire).

## Recomandari concrete pentru Driftwood

1. **Proiectați arta la rezoluție mică-medie (max. 512×512 per sprite individual, ideal 64-256px)**, indiferent de promisiunea 4K — riscul documentat de downscale silențios la 1024×1024 (per `sprites-assets.md`) face ca arta detaliată la rezoluție mare să fie un risc de calitate, nu un avantaj garantat.
2. **Alegeți pixel art low-res sau flat/vector, nu hand-painted, pentru lansare** — argumentul central e costul (secțiunea 10: diferență de 10x în ore între tier 1 și tier 3) combinat cu claritatea pe ecrane mici de mobil (~80% din sesiuni, cifră secundară dar consistentă).
3. **Folosiți `ResampleMode.Pixelated` doar unde imaginea e afișată mai mare decât rezoluția nativă** — aplicat greșit (la micșorare) produce aliasing documentat oficial.
4. **Nu cumpărați TexturePacker** — folosiți Free Sprite Sheet Packer (gratuit, browser) sau exportul CLI nativ al Aseprite (`--batch --sheet`), care produc format JSON compatibil cu generatorul de manifest propus în secțiunea 12.
5. **Folosiți Affinity Designer (acum gratuit)** pentru orice iconiță vectorială UI care trebuie să rămână crisp la scalare — economisiți costul de licență care exista înainte de trecerea la modelul gratuit.
6. **Nu bazați planul de recrutare exclusiv pe Talent Hub** — verificați direct în Creator Dashboard dacă aveți acces (statusul e neclar din surse 2025), și pregătiți Upwork/Fiverr ca alternativă cu rate documentate (secțiunea 11).
7. **Cereți explicit cesiune completă de drepturi în orice contract de outsourcing** — politica Roblox de IP vă face responsabili de conținut indiferent de cine l-a creat; fără cesiune clară, riscați dispute ulterioare sau refolosirea acelorași asset-uri de către artist la alt client.
8. **Construiți fundalurile de parallax ca imagini separate per layer, niciodată ca și crop dintr-un atlas** — incompatibilitatea `ImageRectOffset`/`ScaleType.Tile` e confirmată oficial și afectează direct orice fundal care trebuie să facă tile continuu (esențial pentru un râu care curge continuu, conform CLAUDE.md).
9. **Adoptați convenția de naming `<categorie>_<slug>_<variantă>_<stare>` de la prima zi**, nu retroactiv la 50 de sprite-uri — retro-fit-ul costă timp și introduce erori de referință în cod.
10. **Automatizați complet lanțul export → atlas → Asphalt → manifest Luau** înainte de a produce cele 200 de item-uri finale — testați-l la scară mică în faza de vertical slice (pasul 2 din planul fazat), nu la 200 de fișiere dintr-o dată.
11. **Rezervați 1-2 zile de marjă de moderare** înainte de orice eveniment/lansare programată care depinde de un upload mare și recent de artă — nu vă bazați pe cifra optimistă de "câteva ore" din documentația oficială.
12. **Planificați explicit un "al doilea art pass" post-lansare** pentru item-urile rare/de sezon (iarnă, epave valoroase) ca mecanism de retenție suplimentar, nu ca simplă îmbunătățire tehnică — se aliniază cu principiul din CLAUDE.md că orice recompensă trebuie legată de o buclă pe care jucătorul deja o vrea (aici: colecția vizibilă).

## Riscuri si necunoscute

- **Rezoluția reală de upload rămâne contradictorie** (4K anunțat vs. 1024×1024 raportat activ în bug-uri din 2026) — cel mai mare risc pentru planificarea rezoluției de lucru; vezi analiza completă în `sprites-assets.md`.
- **Nu există confirmare că plafonul de 200 imagini/30 zile (conturi verificate) se aplică și importului privat de sprite-uri pentru propriul joc**, spre deosebire de publicarea publică pe Creator Store — dacă se aplică și privat, upload-ul a 200+ sprite-uri individuale (fără atlas) ar depăși plafonul lunar; motiv suplimentar puternic să folosiți atlas-uri (câteva zeci de foi, nu 200+ fișiere individuale).
- **Statusul de acces la Talent Hub e neclar** — sursa oficială e din 2021 (posibil perimată), un fir mai recent sugerează restricționare. Nu bugetați recrutare pe acest canal fără verificare directă.
- **Prețul curent Figma și disponibilitatea nivelului gratuit pentru 2026 nu au fost verificate** în acest research — verificați direct pe figma.com/pricing înainte de a-l include în bugetul de tool-uri.
- **Data exactă a tranziției Affinity la modelul gratuit nu e confirmată cu certitudine** (o sursă secundară menționează 16 iul. 2026, nu am găsit anunțul oficial cu dată explicită) — verificați dacă modelul gratuit rămâne stabil sau e o promoție temporară.
- **Estimările de ore din secțiunea 10 sunt un calcul intern al acestui research**, nu un fapt citat — scope-ul exact al celor 200 item-uri, 6 zone, UI poate diferi semnificativ de presupunerile folosite (2 stări per item, 4 layere per zonă, 80 elemente UI); recalculați cu scope-ul real de îndată ce design-ul de sistem al Indexului de reparații e finalizat.
- **API-ul exact al Lune (`@lune/fs`, `@lune/serde`) nu a fost verificat linie-cu-linie** — codul din secțiunea 12 e ilustrativ, verificați sintaxa curentă în lune-org.github.io/docs înainte de a-l folosi în producție.

## Intrebari deschise

1. Testați empiric (nu presupuneți) rezoluția efectivă de upload pentru un `Decal`/`Image` pe contul/grupul Driftwood — decide dacă lucrați nativ la 512, 1024 sau mai mult per foaie de atlas (întrebare comună cu `sprites-assets.md`, punctul 1 din Intrebari deschise de acolo).
2. Verificați dacă plafonul de "200 imagini/30 zile" (publishing-assets) se aplică și importului privat prin Asset Manager/Open Cloud pentru propriul joc, sau doar publicării publice pe Creator Store.
3. Decideți stilul vizual final (pixel art vs. flat/vector) **înainte** de vertical slice — schimbarea lui după ce produceți 20+ sprite-uri costă tot ce ați produs.
4. Verificați accesul curent la Talent Hub din contul de Creator Dashboard al proiectului — încă funcțional, restricționat, sau înlocuit de altceva?
5. Obțineți cotații reale (nu doar rate orare medii) de la 2-3 artiști/agenții pentru un set-test de 10 sprite-uri la tier 2, ca reper de cost real înainte de a angaja pentru toate cele 200.
6. Testați `aseprite --batch --sheet` + Free Sprite Sheet Packer pe un set mic (10-15 sprite-uri) și confirmați că JSON-ul rezultat se mapează corect prin generatorul de manifest din secțiunea 12, înainte de a construi restul pipeline-ului pe acest flux.
7. Confirmați dacă un build nativ Apple Silicon oficial pentru Aseprite există acum (verificați aseprite.org/download direct) — schimbă recomandarea de tool pentru performanță pe Mac-uri M-series.

## Surse

- [ResamplerMode (enum reference)](https://create.roblox.com/docs/reference/engine/enums/ResamplerMode) — Roblox Creator Hub, accesat 2026-09-08
- [ImageLabel (class reference)](https://create.roblox.com/docs/reference/engine/classes/ImageLabel) — Roblox Creator Hub, accesat 2026-09-08
- [ScreenInsets (enum reference)](https://create.roblox.com/docs/reference/engine/enums/ScreenInsets) — Roblox Creator Hub, accesat 2026-09-08
- [Texture specifications](https://create.roblox.com/docs/en-us/art/modeling/texture-specifications.md) — Roblox Creator Hub, accesat 2026-09-08
- [Experience icons](https://create.roblox.com/docs/en-us/production/publishing/experience-icons.md) — Roblox Creator Hub, accesat 2026-09-08
- [Publishing assets to the Creator Store](https://create.roblox.com/docs/production/publishing/publishing-assets) — Roblox Creator Hub, accesat 2026-09-08
- [Textures and decals](https://create.roblox.com/docs/en-us/parts/textures-decals.md) — Roblox Creator Hub, accesat 2026-09-08
- [UI position and size](https://create.roblox.com/docs/en-us/ui/position-and-size.md) — Roblox Creator Hub, accesat 2026-09-08
- [Adaptive design](https://create.roblox.com/docs/en-us/production/publishing/adaptive-design.md) — Roblox Creator Hub, accesat 2026-09-08
- [Marketplace validation system](https://create.roblox.com/docs/en-us/marketplace/validation-system.md) — Roblox Creator Hub, accesat 2026-09-08
- [Marketplace policy](https://create.roblox.com/docs/en-us/marketplace/marketplace-policy.md) — Roblox Creator Hub, accesat 2026-09-08
- [Games with Generative AI](https://create.roblox.com/docs/generative-AI) — Roblox Creator Hub, accesat 2026-09-08
- [Build (AI tool)](https://create.roblox.com/docs/en-us/ai/build.md) — Roblox Creator Hub, accesat 2026-09-08
- [Roblox Community Standards](https://about.roblox.com/community-standards) — Roblox Corporate, accesat 2026-09-08
- [4k Texture Rendering](https://devforum.roblox.com/t/4k-texture-rendering/4316229) — DevForum Announcements, 30 ian. 2026
- [Introducing Texture Streaming](https://devforum.roblox.com/t/introducing-texture-streaming/4144855) — DevForum Announcements, 12 dec. 2025
- [Protecting Intellectual Property When Using Generative AI](https://devforum.roblox.com/t/protecting-intellectual-property-when-using-generative-ai/2881851) — DevForum Announcements, 19 mart. 2024
- [Introducing Talent Hub Open Beta](https://devforum.roblox.com/t/introducing-talent-hub-open-beta-new-platform-to-find-post-work/1396502) — DevForum Announcements, 6 aug. 2021 (**sursă veche, flag perimare**)
- [How do I get access to the ROBLOX Talent Hub?](https://devforum.roblox.com/t/how-do-i-get-access-to-the-roblox-talent-hub/1504768) — DevForum, dată nespecificată (post-2021)
- [I need help with sprite sheet in roblox files](https://devforum.roblox.com/t/i-need-help-with-sprite-sheet-in-roblox-files/3873899) — DevForum Scripting Support, 11 aug. 2025
- [An example of a Parallax UI system](https://devforum.roblox.com/t/an-example-of-a-parallax-ui-system/3683271) — DevForum Community Resources, 8 iun. 2025 (tehnică 3D/SurfaceGui, nu se aplică direct la Driftwood)
- [ImageRectOffset/Size does not work with Tile ScaleType](https://devforum.roblox.com/t/imagerectoffsetsize-does-not-work-with-tile-scaletype/3409510) — DevForum Bugs, răspuns oficial 6 feb. 2025 (citat complet în `sprites-assets.md`)
- [TexturePacker](https://www.codeandweb.com/texturepacker) — CodeAndWeb, accesat 2026-09-08 (sursă comercială/marketing)
- [Free Sprite Sheet Packer](https://www.codeandweb.com/free-sprite-sheet-packer) — CodeAndWeb, accesat 2026-09-08
- [Aseprite (Steam store page)](https://store.steampowered.com/app/431730/Aseprite/) — Valve/Steam, accesat 2026-09-08
- [Affinity — free for individuals](https://www.affinity.studio/) — Canva/Affinity, accesat 2026-09-08
- [LUASprites (GitHub)](https://github.com/AJSteinhauser/LUASprites) — AJSteinhauser, ultima actualizare iun. 2023 (sursă comunitară, posibil perimată — Asphalt e recomandarea principală, vezi `sprites-assets.md`)
- [Lune (standalone Luau runtime, GitHub)](https://github.com/lune-org/lune) — lune-org, v0.10.5, 2 iul. 2026
- [Upwork — 2D Game Artists cost](https://www.upwork.com/hire/2d-game-art-freelancers/cost/) — Upwork, accesat 2026-09-08 (secundar)
- [Pixune — Game Art Outsourcing Cost Guide](https://pixune.com/blog/game-art-outsourcing-price/) — Pixune, accesat 2026-09-08 (secundar)
- [Reddit r/gameDevClassifieds — pixel artist pricing](https://www.reddit.com/r/gameDevClassifieds/comments/ewqtu1/) — Reddit, accesat 2026-09-08 (secundar, anecdotic)
- [Reddit r/gamedev — contract rate for a game artist](https://www.reddit.com/r/gamedev/comments/1ditoxy/) — Reddit, accesat 2026-09-08 (secundar, anecdotic)
- [2D Will Never Die — How much do sprites cost](https://2dwillneverdie.com/blog/how-much-do-sprites-cost/) — blog, accesat 2026-09-08 (secundar)
- [RoWatcher / XtendedView / Statista / Pocket Gamer Biz — statistici mobil vs. desktop Roblox] — surse secundare agregate, accesate 2026-09-08, nicio sursă oficială Roblox directă găsită pentru cifra de 80%
- `[object Object]1-sprites-assets.md` — research intern Driftwood (aceeași sesiune de proiect), pentru limitele tehnice API/upload/moderare complete
