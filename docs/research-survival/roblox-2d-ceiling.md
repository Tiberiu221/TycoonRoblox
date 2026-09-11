# Plafonul tehnic pentru 2D complex pe Roblox

## Rezumat executiv

- Roblox **nu are camera ortografica nativa**. Trucul comunitar standard pentru un "look" 2D este `Camera.FieldOfView = 1` + camera mutata la mii de studs distanta, dar acest truc **se rupe pe graphics quality "Automatic" si pe setari joase** (obiecte distante dispar din cauza cull-ului de distanta al motorului) — adica exact pe telefoanele ieftine ale jucatorilor F2P tineri. E un risc real de fairness, nu doar de estetica.
- `EditableImage` (canvas real, pixel-level) e plafonat la **1024×1024 px**, e **actualizat o singura data pe frame la nivel global** (daca updatezi 3 EditableImage-uri simultan, dureaza 3 frame-uri sa apara toate), si necesita cont de dezvoltator **13+ age-verified SI ID-verified** plus un toggle manual in Creator Dashboard ca sa functioneze in jocul publicat. Nu e un canvas "gratuit".
- Nu exista sistem nativ de particule in GUI — `ParticleEmitter` trebuie parentat pe un `BasePart`/`Attachment` 3D, punct. Orice "particule 2D" pe un ecran GUI pur sunt simulate manual (pool de ImageLabel-uri tween-uite).
- Nu exista blend modes / shadere custom pe `GuiObject` normal (`Frame`, `ImageLabel`) — nici macar "multiply". Blend modes reale (Multiply, Add, Subtract, NormalMapBlend) exista **doar** in interiorul API-ului de desenat al `EditableImage`, nu ca proprietate seta­bila pe un obiect GUI obisnuit.
- `Workspace.StreamingEnabled` (streaming nativ de instante) **se aplica doar la descendentii lui `Workspace`** (parti 3D). O harta facuta 100% din `ScreenGui`/`Frame` nu primeste niciun beneficiu de streaming nativ — culling-ul si pooling-ul pentru un tilemap GUI mare trebuie scrise de la zero.
- Nu exista un plafon oficial publicat de tip "X GuiObject-uri = frame drop". Cea mai apropiata cifra oficiala e din 2019: cache-ul de aspect GUI a economisit **1.9 ms/frame pe o scena cu sute de SurfaceGui statice**. Proiectele comunitare serioase de tip "pixel canvas" (CanvasDraw, GradientCanvas) evita din start desenul 1-GuiObject-per-pixel/tile, exact pentru ca nu scaleaza.
- DataStore (2026): plafon de 4 194 304 bytes (4 MB) per cheie, throughput 4 MB/min scriere si 25 MB/min citire per cheie, iar spatiul total per joc a crescut recent la **500 MB + 1 MB × jucatori lifetime** (de la 100 MB, in iulie 2026). O lume de 200×200 tile-uri cu constructii ale jucatorilor salvata intr-o singura cheie JSON va lovi plafonul de 4 MB rapid — trebuie sharding pe regiuni/chunk-uri.
- Solutii comunitare gata-facute exista si sunt serioase: **CanvasDraw** (libraria cea mai folosita pentru pixel canvas pe EditableImage, suporta pana la 1024×1024 live) si **GradientCanvas/FastCanvas** (canvas de pixeli facut din Frame-uri pool-uite + UIGradient per coloana, tehnica pre-EditableImage inca relevanta pentru straturi ce trebuie sa arate "per-pixel" fara sa coste un GuiObject per pixel).
- In mai 2026 Roblox a lansat `AssetService:CreateDataModelContentAsync` — "bake" pentru continut `EditableMesh`/`EditableImage` in content static, replicat server-client, **scos din bugetul de memorie Editable\***. Practic: genereaza harta o data cu EditableImage, apoi "coace" rezultatul static; foloseste EditableImage live doar pentru zonele mici care chiar trebuie sa se schimbe in timp real.
- Recomandare arhitecturala directa: pentru o harta de minim 200×200 tile-uri cu sute de obiecte dinamice, varianta cea mai robusta si cross-device e **GUI pur (ScreenGui) cu tile atlas + pooling + chunking manual**, nu trucul de camera 3D "falsa ortografica" si nu un `EditableImage` unic ca motor de randare in timp real pentru toata harta.

## Fapte verificate

- `EditableImage.Size` este read-only, dimensiune maxima **1024×1024 px**; nu poate fi redimensionat (trebuie creat altul nou + `DrawImageTransformed` + `Destroy` pe vechiul); sursa: repo oficial `Roblox/creator-docs`, fisierul `content/en-us/reference/engine/classes/EditableImage.yaml`, https://github.com/Roblox/creator-docs/blob/main/content/en-us/reference/engine/classes/EditableImage.yaml, ultimul commit 2026-09-03; confidence: ridicata.
- "Only a single `EditableImage` can be updated per frame on the display side" — daca updatezi 3 EditableImage-uri afisate simultan, dureaza 3 frame-uri sa se actualizeze toate; sursa: acelasi fisier ca mai sus; confidence: ridicata.
- Pentru a functiona in experiente publicate, `EditableImage` necesita cont **13+ age-verified si ID-verified**, plus activare manuala din Creator Dashboard ("Enable Mesh / Image APIs"); implicit e dezactivat; sursa: EditableImage.yaml, sectiunea "Enabling for Published Experiences"; confidence: ridicata.
- `EditableImage` are "strict client-side memory budgets" (server/Studio/plugin-uri au memorie nelimitata); reutilizarea (multi-referencing) unui singur EditableImage pe mai multe `Content` ajuta la memorie; nu exista o cifra exacta publicata (MB); sursa: EditableImage.yaml; confidence: ridicata pt afirmatie, NEVERIFICAT pt cifra exacta in MB.
- `CanvasGroup` randeaza descendentii ca o textura "flattened" (real render-target), consuma memorie de textura suplimentara limitata de `QualityLevel` al clientului, randeaza ca textura goala daca depaseste bugetul de memorie, si se recomanda dimensiune statica (resize = recreare de textura); necesita `ZIndexBehavior = Sibling` pe LayerCollector-ul ancestor; sursa: `content/en-us/reference/engine/classes/CanvasGroup.yaml`, ultimul commit 2026-07-15; confidence: ridicata.
- Rebuild-ul listei interne de Z-order pentru un `LayerCollector` ruleaza la primul render sau cand se adauga/sterge un element sau i se schimba `ZIndex`; documentatia oficiala spune explicit "the more elements a LayerCollector has, the worse it performs"; sursa: `content/en-us/performance-optimization/microprofiler/tag-table.md`; confidence: ridicata.
- In ianuarie 2019 Roblox a introdus caching pentru aspectul GUI (nu se mai recalculeaza in fiecare frame daca nu s-a schimbat nimic); pe o scena demo cu "sute de SurfaceGui statice" schimbarea a economisit **1.9 ms** pe frame pe laptopul autorului, cu impact "chiar mai semnificativ pe mobil"; sursa: DevForum, "Static UI Performance Improvements", https://devforum.roblox.com/t/static-ui-performance-improvements/222557, postat 2019-01-09; confidence: ridicata (anunt oficial Roblox staff).
- `Camera` nu are nicio proprietate de proiectie ortografica — doar `FieldOfView`, `DiagonalFieldOfView`, `FieldOfViewMode`, `MaxAxisFieldOfView`, `CameraType` (toate concepte de perspectiva); sursa: `content/en-us/reference/engine/classes/Camera.yaml`; confidence: ridicata.
- Truc comunitar standard pentru "2D": `Camera.FieldOfView = 1` + camera mutata la mii de studs distanta ca sa "aplatizeze" perspectiva; folosit activ intr-un platformer 2D de productie; sursa: DevForum, topic 3932266 "Orthographic Camera Projection for Experiences and Studio", autor MightBeJames, postat 2025-09-13, https://devforum.roblox.com/t/orthographic-camera-projection-for-experiences-and-studio/3932266; confidence: ridicata (marturie directa de dezvoltator, dar e workaround comunitar, nu API oficial).
- Acelasi truc "se rupe" pe setari grafice Automatic/joase: obiectele distante dispar din cauza cull-ului de distanta al motorului, fortand jucatorii (majoritatea pe mobil/hardware slab) sa dea graphics quality la maxim ca sa vada nivelul; sursa: acelasi topic 3932266, cu screenshot-uri; confidence: ridicata; status NEVERIFICAT daca Roblox a rezolvat bug-ul pana la 10-09-2026 (nu am gasit anunt de fix in recap-urile parcurse).
- `ParticleEmitter` trebuie parentat pe un `BasePart` sau un `Attachment` dintr-un BasePart ca sa emita/randeze — nu poate fi parentat pe un `GuiObject`; sursa: `content/en-us/reference/engine/classes/ParticleEmitter.yaml`, ultimul commit 2026-09-03; confidence: ridicata.
- `ImageCombineType` (folosit de metodele `Draw*` ale `EditableImage`) include blend modes reale: `BlendSourceOver`, `Overwrite`, `Add`, `Multiply` (intuneca imaginea pentru valori < 1), `AlphaBlend`, `NormalMapBlend`, `Subtract`; sursa: `content/en-us/reference/engine/enums/ImageCombineType.yaml`, ultimul commit 2026-08-11; confidence: ridicata. Nu exista o proprietate echivalenta de "blend mode" pe `GuiObject`/`ImageLabel`/`Frame` standard (verificat direct in referinta acestor clase) — confidence: ridicata.
- `Path2D` (spline/curba 2D stroke-uita, nu shape umplut) poate fi parentat sub orice `GuiObject`; in iulie 2026 Roblox a lansat clipping pentru elemente GUI rotite si pentru Path2D "with no performance implications", opt-in via `StarterGui.ClipsDescendantsSupportsRotation`, implicit din august 2026; sursa: DevForum, "Weekly Recap: July 13 – 17" (topic 4743286), postat 2026-07-17, https://devforum.roblox.com/t/4743286; confidence: ridicata.
- `Workspace.StreamingEnabled` (streaming nativ) se aplica exclusiv la descendentii `Workspace`; instantele din `ReplicatedStorage`/`ReplicatedFirst` (si, prin extensie, `PlayerGui`) sunt explicit ineligibile pentru streaming; sursa: `content/en-us/workspace/streaming/index.md`, sectiunea "Scope", ultimul commit 2026-07-30; confidence: ridicata.
- Valorile implicite recomandate pentru streaming 3D: `StreamingMinRadius = 64` studs (zona mereu incarcata), `StreamingTargetRadius = 1024` studs (raza tinta pe hardware bun); utile ca reper de scala pentru un sistem de chunking GUI facut manual; sursa: `content/en-us/workspace/streaming/techniques.md`; confidence: ridicata.
- Ghidul oficial de replicare recomanda explicit: "Chunk up complex instance trees like maps and load them in pieces to distribute the work of replicating them across multiple frames" si sa nu trimiti volum mare de date brusc prin `RemoteEvent`; sursa: `content/en-us/performance-optimization/improve.md`, sectiunea "Networking and replication"; confidence: ridicata.
- Plafon DataStore per cheie: **4 194 304 bytes (4 MB)**; throughput 4 MB/minut scriere, 25 MB/minut citire per cheie; sursa: `content/en-us/cloud-services/data-stores/error-codes-and-limits.md`, ultimul commit 2026-08-11; confidence: ridicata.
- Pe 29 iulie 2026 Roblox a unificat limitele de request in-game si Open Cloud (baza ridicata la 300/minut per tip de request) si a crescut plafonul de storage total per joc de la 100 MB la **500 MB + 1 MB × jucatori lifetime**; sursa: DevForum, "Unifying Data Stores Open Cloud and Game APIs, and Increasing Storage Limits" (topic 4739240), https://devforum.roblox.com/t/4739240; confidence: ridicata.
- Pe 18-21 mai 2026, `AssetService:CreateDataModelContentAsync` a ajuns Full Release: permite "bake" de date `EditableMesh`/`EditableImage` in `Content` static, care "drives MeshContent and TextureContent, replicates server-to-client, and is freed from Editable\* memory budgets"; sursa: DevForum, "Weekly Recap: May 18 - 21, 2026" (topic 4647113), https://devforum.roblox.com/t/4647113; confidence: ridicata.
- CanvasDraw (libraria open-source cea mai raspandita pentru pixel-canvas pe EditableImage): rezolutie live pana la 1024×1024 (plafonul EditableImage), pana la 2048×2048 pentru imagini statice generate din fisiere; suporta target-uri `Gui`, `SurfaceGui`, `BillboardGui`, `Decal`, `Texture`, `MeshPart`; ofera `AutoRender=false` pentru a lucra manual in jurul plafonului "1 update/frame"; a ajuns Full Release in noiembrie 2024, versiune 4.20.2 la data cercetarii; sursa: DevForum, topic 1624633, https://devforum.roblox.com/t/1624633; confidence: medie (revendicari de autor/comunitate, nu documentatie oficiala Roblox, dar consistente cu limitele oficiale EditableImage verificate separat).
- Tehnica GradientCanvas/FastCanvas: un canvas de pixeli construit **fara** EditableImage, dintr-un pool de `Frame`-uri (unul per coloana de pixeli), fiecare cu un `UIGradient` ale carui color-stops codifica o coloana intreaga de pixeli — reduce drastic numarul de GuiObject-uri live fata de 1 Frame per pixel; sursa: DevForum topic 2452676 (cod sursa postat de autor, credit original github.com/boatbomber/GradientCanvas), https://devforum.roblox.com/t/2452676, postat 2023-07-04; confidence: ridicata (cod sursa inspectat direct).
- Ghidul oficial de design recomanda limitarea imaginilor UI la maxim ~512×512 px (majoritatea sub 256×256) si folosirea de sprite sheet-uri via `ImageRectOffset`/`ImageRectSize` pentru a combina multe imagini mici intr-un singur asset; sursa: `content/en-us/performance-optimization/design.md`; confidence: ridicata.

## Detalii

### 1. Cate GuiObject-uri poti avea inainte sa doara?

Roblox nu publica un numar fix. Documentatia oficiala confirma insa mecanismul de cost, ceea ce e mai util decat un numar magic: fiecare `LayerCollector` (un `ScreenGui`, o `SurfaceGui` etc.) tine o **lista interna de Z-order** care se reconstruieste integral la primul render si de fiecare data cand un element e adaugat, sters, sau isi schimba `ZIndex`. Citat direct: "the more elements a LayerCollector has, the worse it performs." Separat, `UpdateUILayouts/Layout` reface pozitia/dimensiunea elementelor administrate de `UILayout` (`UIListLayout`, `UIGridLayout` etc.) si de orice tween activ (`TweenService`, `GuiObject:TweenSize/TweenPosition`) — costul creste cu numarul de elemente resize-uite/repozitionate, nu doar cu numarul total de elemente statice.

Singurul reper cantitativ oficial e din 2019: Roblox a adaugat caching pentru aspectul GUI (randare re-folosita atata timp cat nimic nu s-a schimbat in acel Gui), masurat la **1.9 ms/frame economisiti** pe o scena cu sute de SurfaceGui statice, cu impact mai mare pe mobil. Implicatie directa de design: **separa UI static de UI dinamic in `ScreenGui`/LayerCollector-uri diferite**, pentru ca schimbarea unui singur descendent invalideaza cache-ul intregului Gui parinte, nu doar al elementului schimbat.

Concluzia practica, confirmata indirect de faptul ca toate proiectele serioase de "pixel canvas" din comunitate (CanvasDraw, GradientCanvas) refuza explicit modelul 1-GuiObject-per-pixel/tile: pentru o harta de 200×200 = 40 000 de celule, a avea 40 000 de `Frame`/`ImageLabel` vii simultan e o idee proasta indiferent de hardware. Solutia standard e **object pooling** (reciclezi un numar fix, mic, de GuiObject-uri vizibile, le repozitionezi/re-texturezi cand camera se misca) — exact tehnica pe care Roblox insusi o recomanda oficial pentru NPC-uri ("Pool NPC models with frequent respawning... this process is called pooling") si care se aplica identic la tile-uri de GUI.

### 2. EditableImage ca "adevarat canvas" 2D

`EditableImage` e singurul mod de a desena pixel-cu-pixel in Roblox (metodele `DrawCircle`, `DrawLine`, `DrawRectangle`, `DrawImage`, `DrawImageTransformed`, `ReadPixelsBuffer`/`WritePixelsBuffer`). Limitarile concrete, verificate direct in referinta:

| Limitare | Valoare | Sursa |
|---|---|---|
| Rezolutie maxima | 1024×1024 px, fixa (nu se poate redimensiona un EditableImage existent) | EditableImage.yaml |
| Update pe frame | O singura instanta EditableImage se poate actualiza pe frame **la nivel global de client**; 3 EditableImage-uri afisate = 3 frame-uri pana apar toate | EditableImage.yaml |
| Memorie | Buget strict client-side, cifra exacta nepublicata; server/Studio/plugin = nelimitat | EditableImage.yaml |
| Acces in productie | Cont dezvoltator 13+ age-verified + ID-verified + toggle manual "Enable Mesh / Image APIs" in Creator Dashboard | EditableImage.yaml |
| Permisiuni asset | Poti incarca doar imagini detinute/partajate cu owner-ul experientei, cu userul Studio, sau cu jucatorul (client-side) | EditableImage.yaml |

Throttling-ul de "1 update/frame global" e motivul pentru care CanvasDraw ofera explicit `AutoRender = false` + `Canvas:Render()` manual — daca ai mai multe canvas-uri (de ex. minimap + fereastra de inventar pictata + un layer de teren modificabil), nu le poti actualiza pe toate live in fiecare frame; trebuie sa alegi ce se randeaza cand.

Noutate cheie 2026: `AssetService:CreateDataModelContentAsync` (Full Release mai 2026) permite sa "coci" continut EditableImage/EditableMesh generat dinamic intr-un `Content` static, care se **replica server→client** si iese complet din bugetul de memorie Editable*. Pattern recomandat: genereaza harta/tile atlas-ul o singura data cu EditableImage (pe server sau la load), apoi bake, apoi doar zonele care chiar trebuie sa ramana editabile live (ex: o portiune mica unde jucatorul picteaza/sapa in acel moment) raman pe EditableImage viu.

### 3. Lighting, shadows si "multiply" fara shadere

Roblox nu are un sistem de shadere programabile pentru GUI. Ce ai la dispozitie, verificat direct in reference:

- **Compunere pe `GuiObject` normal**: doar alpha blending standard prin `BackgroundTransparency`/`ImageTransparency` si tint prin `Color3`/`ImageColor3` (care functioneaza ca un multiply implicit al texturii cu culoarea, dar nu e un "blend mode" configurabil). Nu exista proprietate `BlendMode` pe `Frame`/`ImageLabel`.
- **`UIGradient`**: gradient liniar/radial/conic de culoare si transparenta pe un singur `GuiObject` — util pentru "vignette", tranzitii orizont zi/noapte, sau (vezi GradientCanvas mai jos) ca trick de compresie de date.
- **Blend modes reale** (`Add`, `Multiply`, `Subtract`, `NormalMapBlend`, `AlphaBlend`, `Overwrite`) exista **doar** ca parametru al metodelor `Draw*` din API-ul `EditableImage` — adica poti face un layer de "lumina" corect din punct de vedere al compunerii aditive/multiplicative, dar numai daca acel layer e deja un canvas EditableImage, nu un `Frame` obisnuit peste scena.

Comunitatea a impins asta destul de departe: proiectul "Radiosity Engine" (raytracing/global illumination baked via EditableImage, folosit ca lightmap pe parti 3D, nu pe GUI 2D) arata ca low-level pixel access + Parallel Luau permit calcule de iluminare surprinzator de sofisticate offline/la load — dar la cost de randare temporar oprita cat se calculeaza, si e gandit pentru scene 3D, nu pentru un layer GUI peste o harta 2D. Concluzia practica pentru un joc 2D: zi/noapte si "mood lighting" ieftine se fac cel mai bine cu **un singur `Frame`/`ImageLabel` semi-transparent, colorat, peste toata harta** (± `UIGradient` pentru variatie orizont-zenit), nu cu tinting per-tile — per-tile ar insemna sa actualizezi Color3/Transparency pe mii de obiecte simultan, ceea ce revine la problema de la sectiunea 1.

### 4. Particule

Nu exista particule native in GUI. `ParticleEmitter` cere explicit un `BasePart` sau `Attachment` 3D ca parinte. Optiuni reale pentru "particule 2D" pe un ecran GUI:

1. Pool de `ImageLabel`-uri mici, animate manual (pozitie/transparenta/scale prin `TweenService` sau printr-un loop pe `RenderStepped`) — cost: fiecare particula activa e un GuiObject tween-uit, deci se aplica exact costurile de la sectiunea 1 (rebuild Z-order, `UpdateUILayouts`). Practic, limiteaza numarul de particule simultane la zeci, nu la mii.
2. Particule 3D reale randate intr-un `ViewportFrame` (scena 3D separata, camera proprie) compus peste UI — mai scump de configurat, dar iti da acces la `ParticleEmitter` complet (viteza, culoare pe `NumberSequence`/`ColorSequence`, forma etc.); util doar pentru efecte punctuale (o explozie, un splash), nu ca strat permanent peste toata harta.
3. Efecte "pixel" desenate direct intr-un `EditableImage` (ex. stropi de apa, scantei) — beneficiezi de blend modes reale, dar te lovesti de plafonul "1 update/frame" daca acel canvas se suprapune cu alte canvase EditableImage active.

### 5. Camera 3D falsa "ortografica" vs. GUI pur vs. hibrid SurfaceGui

Roblox **nu are** camera ortografica (confirmat direct in `Camera.yaml` — nicio proprietate de tip `Orthographic`). Cererea de feature exista public din cel putin 2018 si a fost redeschisa/consolidata in septembrie 2025 (topic 3932266), fara sa gasim un anunt de implementare in recap-urile parcurse pana in septembrie 2026 — deci status **NEVERIFICAT/probabil neimplementat**.

Trucul folosit de developeri e `Camera.FieldOfView = 1` + camera la mii de studs distanta, ceea ce elimina aproape toata distorsiunea de perspectiva. Problema documentata: pe **Automatic sau setari grafice joase** (adica exact ce ruleaza pe telefoanele ieftine — populatia majoritara F2P/tanara pe Roblox), motorul isi reduce distanta de randare/culling, iar obiecte la mii de studs distanta **dispar complet**, stricand jocul pentru acei jucatori pana forteaza manual graphics quality la maxim. Pentru Driftwood, unde cerinta explicita e "fair pentru jucatori gratuiti, audienta tanara", acest risc e suficient de serios cat sa elimine varianta "camera 3D falsa" ca solutie principala pentru toata harta.

Trei arhitecturi posibile, cu compromisuri:

| Arhitectura | Avantaje | Dezavantaje |
|---|---|---|
| **ScreenGui pur** (Frame/ImageLabel, fara Workspace 3D pentru harta) | Fara bug-ul de cull la distanta; rezolutie independenta de "studs"; usor de facut pooling/atlas; ImageRectOffset/ImageRectSize ieftin pentru tile-uri | Fara streaming nativ (trebuie scris manual); fara particule native; fara blend modes native; layout cost creste cu numarul de elemente |
| **SurfaceGui pe parti 3D** (harta = grid de parti cu SurfaceGui) | Poti combina cu lighting 3D real (umbre, `LightInfluence`), fizica reala pe fiecare "tile"-parte daca vrei coliziuni 3D; `PixelsPerStud`/`CanvasSize` dau control clar peste rezolutia texturii | Fiecare tile = o instanta `BasePart` + o `SurfaceGui`, deci costul e dublu fata de GUI pur (draw calls 3D + layout GUI); "flattening" catre 2D pur necesita in continuare camera trick sau camera de sus fixa |
| **Camera 3D + FOV mic ("falsa ortografica")** | Arata bine pe hardware bun; usor de facut daca lumea ta e deja 3D | Bug documentat de disparitie pe Automatic/mobil; nu rezolva nimic legat de GUI overlay (HUD tot ramane GUI separat) |

Recomandare: **ScreenGui pur pentru harta/tile-uri**, eventual cu un strat 3D minimal separat (nu camera "falsa ortografica" globala) doar daca vrei umbre reale pe obiecte specifice (ex. constructii mari), compus prin `ViewportFrame`/`SurfaceGui` local, nu ca motor principal.

### 6. Streaming si sincronizarea unei lumi mutabile mari

`Workspace.StreamingEnabled` (streaming nativ Roblox) functioneaza **doar** pe descendentii `Workspace` — parti si modele 3D. `ReplicatedStorage`, `ReplicatedFirst` si (prin acelasi principiu) orice GUI din `PlayerGui`/`StarterGui` sunt **explicit ineligibile**. Deci daca harta e GUI pur, nu primesti niciun beneficiu automat de streaming — trebuie sa implementezi tu:

- **Chunking**: imparte harta de 200×200 in regiuni (ex. 16×16 sau 32×32 tile-uri per chunk); instantiezi/populezi doar chunk-urile din raza vizibila + o margine tampon, distrugi/ascunzi restul.
- **Pooling** pe tile-uri si pe orice obiect dinamic (nu creezi/distrugi GuiObject-uri constant — le reciclezi).
- Ca reper de scala, valorile implicite ale streaming-ului 3D nativ al Roblox sunt `StreamingMinRadius = 64` studs (zona mereu incarcata) si `StreamingTargetRadius = 1024` studs (raza tinta pe hardware bun) — un punct de plecare rezonabil pentru cate "randuri" de chunk-uri sa tii incarcate in jurul jucatorului intr-un sistem echivalent facut manual pentru GUI.

Pentru **sincronizarea constructiilor jucatorilor** (stare mutabila, potential sute-mii de obiecte plasate), ghidul oficial de replicare da doua reguli directe si citabile: "chunk up complex instance trees like maps and load them in pieces to distribute the work of replicating them across multiple frames" si evita sa trimiti volum mare de date brusc printr-un `RemoteEvent` — trimite doar ce s-a schimbat, nu tot inventarul/toata harta.

Pentru **persistenta** (salvare intre sesiuni), limitele DataStore (actualizate iulie 2026) sunt hard:

| Limita | Valoare (2026) |
|---|---|
| Marime maxima per cheie | 4 194 304 bytes (4 MB) |
| Throughput scriere | 4 MB/minut per cheie |
| Throughput citire | 25 MB/minut per cheie |
| Storage total per joc | 500 MB + 1 MB × jucatori lifetime (crescut de la 100 MB pe 29 iulie 2026) |
| Buget request unificat (in-game + Open Cloud) | Baza 300/minut per tip de request + multiplicator CCU |

Implicatie directa: **nu salva toata lumea intr-o singura cheie JSON**. O harta de 200×200 cu sute de constructii ale jucatorilor, fiecare cu tip/pozitie/rotatie/owner/metadata, poate depasi usor cativa MB comprimati JSON. Solutia standard (si folosita chiar de CanvasDraw pentru imagini, care revendica sa incapa "o imagine 1024×1024 comprimata intr-o singura cheie DataStore") e **sharding pe regiune**: o cheie per chunk/regiune, salvata doar cand chunk-ul respectiv s-a modificat, nu la fiecare autosave global.

### 7. Ce a construit deja comunitatea (referinte directe de arhitectura)

- **CanvasDraw** (boatbomber si colaboratori, Full Release noiembrie 2024, v4.20.2 la data cercetarii) — libraria cea mai matura pentru pixel-canvas pe EditableImage: rezolutie live pana la 1024×1024, pana la 2048×2048 pentru imagini statice generate din fisiere, compresie de imagine pentru DataStore, suport `Gui`/`SurfaceGui`/`BillboardGui`/`Decal`/`Texture`/`MeshPart`, folosita in productie pentru raycastere, raytracere, editoare de tilemap, simulari "falling sand". https://devforum.roblox.com/t/1624633
- **GradientCanvas/FastCanvas** (boatbomber, fork citat in interiorul CanvasDraw) — tehnica de canvas fara EditableImage: pool de `Frame` + `UIGradient` per coloana de pixeli, in loc de un `Frame` per pixel. Utila azi mai ales ca **model mental**: cand chiar ai nevoie de un rezultat "per-pixel" ieftin (ex. o masca de fog-of-war, un gradient de apa), gandeste-te la compresie prin `UIGradient`/atlas inainte sa presupui ca ai nevoie de EditableImage sau de mii de GuiObject-uri. https://devforum.roblox.com/t/2452676
- **Radiosity Engine** (lightmapping bazat pe EditableImage, raytracing/GI/umbre soft, calculat offline in Studio) — demonstreaza plafonul superior al ce se poate face cu EditableImage pentru iluminat, dar e gandit pentru scene 3D (lightmap-uri pe parti), nu pentru un layer GUI 2D live. https://devforum.roblox.com/t/3191321
- **"Orthographic Camera Projection for Experiences and Studio"** (cerere de feature, sept. 2025) — cea mai buna sursa curenta pentru limitarile trucului de camera falsa-ortografica, cu exemple concrete dintr-un platformer 2D real in productie. https://devforum.roblox.com/t/3932266

## Ce putem fura pentru Driftwood

1. **Tile atlas + `ImageRectOffset`/`ImageRectSize`** in loc de un asset de imagine separat per tip de tile — recomandare oficiala Roblox, reduce numarul de asset-uri si de draw calls la randare. Cost: **mic**.
2. **Object pooling pentru tile-uri si obiecte dinamice** (reciclezi un numar fix de `Frame`/`ImageLabel`, le reproiectezi cand camera/viewport-ul se misca), dupa modelul oficial de pooling pentru NPC-uri, aplicat la GUI. Cost: **mediu** (arhitectura de baza a randarii, trebuie facuta corect de la inceput).
3. **Chunking manual al lumii** in regiuni (ex. 32×32 tile-uri), incarcate/descarcate dupa pozitia jucatorului, cu raze de referinta similare streaming-ului 3D nativ (64/1024 studs echivalent adaptat la tile-uri). Cost: **mediu**.
4. **Separarea UI static de UI dinamic** in `ScreenGui`/LayerCollector-uri distincte, ca sa profiti de cache-ul de aspect GUI al motorului (1.9 ms/frame demonstrat oficial) si sa nu invalidezi tot HUD-ul cand se misca un singur element. Cost: **mic**.
5. **Overlay unic zi/noapte** (un `Frame`/`ImageLabel` semi-transparent peste toata harta, ± `UIGradient` pe orizont) in loc de tinting per-tile. Cost: **mic**.
6. **Sharding DataStore pe regiune/chunk** pentru constructiile jucatorilor, salvat incremental doar la modificare, nu ca un blob JSON unic pentru toata harta. Cost: **mediu**.
7. **Evaluarea CanvasDraw ca dependinta gata-facuta** pentru un layer specific unde chiar ai nevoie de pixel canvas real (ex. minimap generat procedural, un strat de "vopsea"/teren sapat de jucatori) — nu reinventa un motor de pixel-drawing de la zero. Cost: **mic** (integrare biblioteca existenta), dar cu **risc organizational**: cere cont de dezvoltator 13+ ID-verified plus toggle manual Dashboard — de verificat cine din echipa detine acel cont.
8. **`CreateDataModelContentAsync` pentru straturi generate o singura data** (ex. harta de teren generata procedural la start) — genereaza cu EditableImage, apoi "bake" static, eliberand bugetul de memorie Editable* pentru straturi care chiar trebuie sa ramana live. Cost: **mediu** (feature relativ nou, mai 2026, necesita test dedicat pe cont dezvoltator real).
9. **`CanvasGroup` pentru ferestre/paneluri UI statice** (inventar, fereastra de crafting) unde vrei opacitate/tint de grup ieftin — nu pentru tile-uri care se redimensioneaza des (recreeaza textura la resize). Cost: **mic**.

## Ce NU merge pentru noi

- **EditableImage ca motor principal de randare pentru toata harta in timp real** — throttling-ul de "1 update/frame global" inseamna ca daca ai si un minimap, si un overlay de lumina, si un strat de teren editabil, toate pe EditableImage, se vor actualiza pe rand, nu simultan; plus bugetul de memorie strict si nepublicat, plus cerinta de cont 13+ ID-verified care poate bloca un membru tanar din echipa sa activeze feature-ul in productie.
- **Camera 3D + FOV extrem de mic ca "orthographic" pentru toata harta** — bug documentat de disparitie a obiectelor pe graphics quality Automatic/joase, adica exact pe hardware-ul jucatorilor F2P tineri pe care jocul trebuie sa ramana corect pentru ei (cerinta explicita de fairness a proiectului).
- **Un GuiObject per tile sau per pixel pe o harta de 200×200+** — 40 000+ instante vii simultan fara pooling, fara streaming nativ (GUI nu beneficiaza de `StreamingEnabled`), garantat sa produca frame drops; toate proiectele comunitare serioase de pixel-canvas evita explicit acest model.
- **Shadere custom / post-procesare globala tip multiply pe intreaga scena GUI** — nu exista API de shadere pe `GuiObject`; blend modes reale exista doar in interiorul unui `EditableImage`, deci "un filtru global de culoare peste tot ecranul" nu poate fi un shader ieftin — trebuie simulat cu overlay-uri de transparenta (vezi sectiunea 3).
- **Particule GUI native ca strat permanent peste harta** — nu exista `ParticleEmitter` in GUI; orice simulare de particule 2D permanenta (ploaie, frunze, scantei de-a lungul intregii harti) trebuie construita manual si va concura pe acelasi buget de GuiObject-uri ca restul tile-urilor, deci trebuie limitata strict (zeci, nu mii, de particule simultane).
- **Un JSON unic per lume in DataStore** pentru constructiile jucatorilor — plafonul de 4 MB per cheie e usor de atins la scara "sute de obiecte plasate de jucatori pe o harta mare"; necesita sharding de la inceputul design-ului de date, nu ca patch ulterior.

## Riscuri si necunoscute

- **Nu exista un numar oficial de GuiObject-uri inainte de frame drop** — depinde puternic de device, de cate proprietati se schimba pe frame, si de cum sunt organizate LayerCollector-urile. Trebuie masurat empiric pe hardware low-end real (Shift+F2 pentru Render Stats, F9 pentru Developer Console), nu presupus dintr-un numar gasit online.
- **Statusul feature-ului de camera ortografica in septembrie 2026 e NEVERIFICAT** — cererea publica exista din 2025 fara confirmare de implementare in sursele parcurse; daca Roblox il livreaza, ar schimba semnificativ calculul intre arhitectura GUI-pur si o arhitectura 3D "adevarat 2D".
- **Bugetul exact de memorie (in MB) pentru EditableImage nu e publicat** — planificarea trebuie sa includa teste de memorie pe device-uri low-end reale inainte de a decide cate canvase EditableImage simultane isi permite jocul.
- **`AssetService:CreateDataModelContentAsync` e foarte nou (mai 2026)** — nu am gasit date de performanta/benchmark comunitare la scara mare (ex. bake frecvent pe sute de jucatori simultan); de tratat ca pariu tehnic care trebuie prototipat devreme, nu ca solutie garantata.
- **Cerinta de cont 13+ ID-verified pentru EditableImage** poate fi un blocaj organizational, nu doar tehnic, daca echipa Driftwood e mica/tanara — de clarificat cine detine contul de "owner" al experientei si daca acea persoana poate/vrea sa faca verificarea de identitate.
- **Compresia de imagine revendicata de CanvasDraw** ("o imagine 1024×1024 intr-o singura cheie DataStore") e o afirmatie de autor/comunitate, nu documentatie oficiala Roblox — de validat direct daca se decide adoptarea bibliotecii, nu de luat ca fapt garantat.

## Surse

- EditableImage — referinta oficiala. https://github.com/Roblox/creator-docs/blob/main/content/en-us/reference/engine/classes/EditableImage.yaml — ultimul commit 2026-09-03.
- CanvasGroup — referinta oficiala. https://github.com/Roblox/creator-docs/blob/main/content/en-us/reference/engine/classes/CanvasGroup.yaml — ultimul commit 2026-07-15.
- ParticleEmitter — referinta oficiala. https://github.com/Roblox/creator-docs/blob/main/content/en-us/reference/engine/classes/ParticleEmitter.yaml — ultimul commit 2026-09-03.
- Camera — referinta oficiala (fara proprietate ortografica). https://github.com/Roblox/creator-docs/blob/main/content/en-us/reference/engine/classes/Camera.yaml
- ImageCombineType — enum oficial de blend modes. https://github.com/Roblox/creator-docs/blob/main/content/en-us/reference/engine/enums/ImageCombineType.yaml — ultimul commit 2026-08-11.
- Path2D — ghid si referinta oficiala. https://github.com/Roblox/creator-docs/blob/main/content/en-us/ui/2D-paths.md
- Performance Optimization — MicroProfiler tag table (cost Z-order/layout UI). https://github.com/Roblox/creator-docs/blob/main/content/en-us/performance-optimization/microprofiler/tag-table.md
- Performance Optimization — Design for performance (draw calls, marime imagini). https://github.com/Roblox/creator-docs/blob/main/content/en-us/performance-optimization/design.md
- Performance Optimization — Improve performance (networking/replication, pooling NPC). https://github.com/Roblox/creator-docs/blob/main/content/en-us/performance-optimization/improve.md
- Instance streaming — scope si comportament. https://github.com/Roblox/creator-docs/blob/main/content/en-us/workspace/streaming/index.md — ultimul commit 2026-07-30.
- Instance streaming — tehnici si valori implicite (raze). https://github.com/Roblox/creator-docs/blob/main/content/en-us/workspace/streaming/techniques.md
- Data Stores — coduri de eroare si limite (4 MB/cheie, throughput). https://github.com/Roblox/creator-docs/blob/main/content/en-us/cloud-services/data-stores/error-codes-and-limits.md — ultimul commit 2026-08-11.
- DevForum — "Static UI Performance Improvements" (cache aspect GUI, 1.9 ms). https://devforum.roblox.com/t/static-ui-performance-improvements/222557 — 2019-01-09.
- DevForum — "Orthographic Camera Projection for Experiences and Studio" (truc FOV/distanta, bug pe Automatic). https://devforum.roblox.com/t/orthographic-camera-projection-for-experiences-and-studio/3932266 — 2025-09-13.
- DevForum — "Weekly Recap: July 13 – 17" (Path2D clipping, DataStore 500 MB). https://devforum.roblox.com/t/4743286 — 2026-07-17.
- DevForum — "Unifying Data Stores Open Cloud and Game APIs, and Increasing Storage Limits" (limite DataStore 2026). https://devforum.roblox.com/t/4739240 — 2026-07-15/29.
- DevForum — "Weekly Recap: May 18 - 21, 2026" (CreateDataModelContentAsync Full Release). https://devforum.roblox.com/t/4647113 — 2026-05-21.
- DevForum — CanvasDraw (libraria pixel-canvas pe EditableImage). https://devforum.roblox.com/t/1624633 — actualizat continuu, verificat 2026-09-10.
- DevForum — GradientCanvas/FastCanvas (pixel canvas fara EditableImage, Frame+UIGradient). https://devforum.roblox.com/t/2452676 — 2023-07-04.
- DevForum — "EditableImage Baked Lighting: (Raytraced Global Illumination + Soft Shadows)" (Radiosity Engine, lightmapping 3D via EditableImage). https://devforum.roblox.com/t/3191321 — sursa secundara/comunitara.
