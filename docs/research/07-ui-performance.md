# Performanța randării UI 2D pe Roblox (ScreenGui / GuiObject) pentru Driftwood

## Rezumat executiv

- Nu există niciun benchmark oficial Roblox care să dea un număr exact de „câte Frame/ImageLabel poți muta pe frame la 60fps". Am căutat explicit și nu am găsit așa ceva — de reținut ca **NEVERIFICAT** și de testat direct în Studio + pe un telefon low-end, nu de presupus dintr-o cifră găsită online.
- Motorul Roblox are, din 2019, un sistem de **cache al aspectului GUI** la nivel de `LayerCollector` (ScreenGui): un `GuiObject` nemodificat nu se recalculează. Orice scriere de proprietate (Position, ZIndex, Transparency etc.) pe UN singur obiect invalidează cache-ul pentru tot ScreenGui-ul respectiv, nu doar pentru obiectul modificat. Consecință directă pentru Driftwood: **HUD-ul static și râul (obiecte mobile) trebuie să stea în ScreenGui-uri separate**, altfel fiecare frame de mișcare a râului forțează recalcularea inutilă a HUD-ului.
- Pentru actualizarea poziției pe frame, motorul recomandă oficial `RunService.PreRender` (înlocuiește `RenderStepped`, deprecated) sau `BindToRenderStep`, nu `Heartbeat` — `Heartbeat` rulează după simularea fizică și nu garantează sincronizare cu randarea vizuală a frame-ului curent.
- `CanvasGroup` randează întregul subarbore ca o textură offscreen; e util pentru transparență de grup (`GroupTransparency`) pe elemente relativ statice, dar consumă memorie de textură suplimentară limitată de `QualityLevel`-ul clientului și, dacă bugetul de memorie e depășit, randează **texture goală** (blank). Nu e o soluție bună pentru un strat cu 50-200 obiecte care se mișcă în fiecare frame.
- `EditableImage` **nu poate** fi motorul principal de randare al jocului: oficial, „doar un singur EditableImage poate fi actualizat pe frame pe partea de display" — dacă ai mai multe EditableImage active, ele își împart câte un slot de redraw pe frame (10 imagini = 10 frame-uri ca să se actualizeze toate). Plus: rezoluție maximă 1024×1024, limită de client de 8 instanțe EditableImage per client (comunitate, ian. 2026), buget de memorie ~32MB per instanță raportat de comunitate, și necesită **verificare ID (13+)** a proprietarului experienței ca să funcționeze într-o experiență publicată — o barieră administrativă serioasă pentru un dev solo.
- Object pooling (reciclarea de `GuiObject`-uri în loc de `Instance.new()`/`Destroy()` pe fiecare obiect nou din râu) este practica consacrată în comunitate pentru scenarii cu multe obiecte create/distruse frecvent (thread-uri „bullet hell" cu 200+ proiectile).
- Unelte de profiling disponibile și gratuite: **MicroProfiler** (`Ctrl+Alt+F6` / `Cmd+Opt+F6` în Studio), **Performance Stats overlay** (`Ctrl+Alt+F7` / `Cmd+Opt+F7`), **Developer Console** (`F9`, tab Memory), și API-ul `Stats:GetMemoryUsageMbForTag(Enum.DeveloperMemoryTag.Gui)` pentru memoria consumată specific de UI.
- Nu există un „memory limit" fix documentat oficial pentru mobil — Roblox spune doar generic că la atingerea limitelor motorului „dispozitivul sau serverul poate crash-ui". Cifrele concrete de buget de memorie găsite (400-1500MB) vin din tutoriale de comunitate, nu din documentație oficială — tratate ca **secundare, încredere scăzută**.
- Recomandare de arhitectură: randare 100% prin `GuiObject` clasic (Frame/ImageLabel) cu pooling, actualizare poziții pe `PreRender`, HUD separat de layer-ul dinamic, fără `CanvasGroup` pe zona râului, fără `EditableImage` ca renderer principal — folosește `EditableImage` cel mult pentru un efect punctual, opțional, nu critic pentru joc.

## Fapte verificate

- **GUI appearances sunt cache-uite din 2019**; se recalculează doar când un descendent e adăugat/șters sau o proprietate i se schimbă; exemplu oficial: îmbunătățire de 1.9ms pe un laptop cu sute de SurfaceGui statice. Sursă: [Static UI Performance Improvements](https://devforum.roblox.com/t/static-ui-performance-improvements/222557), DevForum, postare oficială Roblox (Homeomorph), 9 ianuarie 2019. Încredere: **ridicată** (oficial), dar **notă**: e din 2019 — mecanismul de bază pare încă valabil (nu am găsit nimic care să-l contrazică), dar cifrele exacte de exemplu pot fi neactualizate.
- Recomandarea oficială din acel thread: „separă UI-ul majoritar-static de UI-ul majoritar-dinamic în ScreenGui-uri diferite, ca UI-ul dinamic să nu interfereze cu cache-ul UI-ului static". Sursă: idem. Încredere: ridicată.
- **CanvasGroup** randează descendenții ca grup „flatten" într-o textură, cu `GroupColor3` și `GroupTransparency` aplicate rezultatului; „consumă memorie de textură suplimentară; calitatea texturii și memoria totală folosită sunt limitate de QualityLevel-ul clientului"; dacă memoria e depășită, se randează ca textură goală; `ClipsDescendants` e mereu activ. Sursă: [CanvasGroup.yaml, creator-docs (GitHub)](https://github.com/Roblox/creator-docs/blob/main/content/en-us/reference/engine/classes/CanvasGroup.yaml) + [CanvasGroup docs](https://create.roblox.com/docs/reference/engine/classes/CanvasGroup), accesat 2026-09-08. Încredere: ridicată (sursă oficială).
- CanvasGroup randarea „flatten" se aplică doar dacă `LayerCollector.ZIndexBehavior` al ascendentului e `Sibling`. Sursă: idem. Încredere: ridicată.
- **EditableImage**: „doar un singur EditableImage poate fi actualizat pe frame pe partea de display. De exemplu, dacă actualizezi trei obiecte EditableImage afișate simultan, va dura trei frame-uri până se actualizează toate." Sursă: [EditableImage.yaml, creator-docs (GitHub)](https://github.com/Roblox/creator-docs/blob/main/content/en-us/reference/engine/classes/EditableImage.yaml), accesat 2026-09-08. Încredere: **ridicată** (oficial, citat direct). Acesta e faptul-cheie care exclude EditableImage ca renderer principal pentru un joc cu update la 60fps.
- EditableImage: dimensiune maximă **1024×1024**; are „bugete stricte de memorie client-side" (serverul, Studio și plugin-urile nu au limită). Sursă: idem. Încredere: ridicată pentru limita de rezoluție (oficial); pentru cifra exactă „strict" fără număr concret în text oficial.
- EditableImage: pentru folosire în experiențe publicate, proprietarul experienței trebuie să fie **13+ și ID-verificat**, apoi să activeze toggle-ul „Enable Mesh / Image APIs" din Creator Dashboard / Studio → Game Settings → Security. Sursă: [EditableImage.yaml](https://github.com/Roblox/creator-docs/blob/main/content/en-us/reference/engine/classes/EditableImage.yaml) + [[Client Beta] In-experience Mesh & Image APIs](https://devforum.roblox.com/t/client-beta-in-experience-mesh-image-apis-now-available-in-published-experiences/3267293), Roblox, 20 noiembrie 2024. Încredere: ridicată (oficial).
- EditableImage: limita raportată de comunitate este **~32MB și 1024×1024** per instanță, iar limita curentă e de **8 instanțe** EditableImage/EditableMesh per client. Sursă: [EditableImage higher resolution and memory limit](https://devforum.roblox.com/t/editableimage-higher-resolution-and-memory-limit/4389575), DevForum, 16 februarie 2026; [Remove Editable Mesh/Image limit on the client](https://devforum.roblox.com/t/remove-editable-meshimage-limit-on-the-client/4219561), DevForum, 5 ianuarie 2026. Încredere: **medie** (cifre raportate de dezvoltatori din comunitate, neconfirmate textual în pagina oficială pe care am putut-o citi; consistente între două thread-uri independente).
- `RunService` — ordinea de execuție per frame pe client este **PreRender → PreAnimation → PreSimulation → PostSimulation → Heartbeat**. Sursă: [RunService.yaml, creator-docs (GitHub)](https://github.com/Roblox/creator-docs/blob/main/content/en-us/reference/engine/classes/RunService.yaml), accesat 2026-09-08. Încredere: ridicată.
- `RenderStepped` este **deprecated**, „superseded by PreRender, care trebuie folosit pentru cod nou". `Stepped` este deprecated, „superseded by PreSimulation". Sursă: idem. Încredere: ridicată.
- `PreRender` rulează doar pe client, chiar înainte ca frame-ul să fie desenat; parametru `deltaTimeRender`; recomandarea oficială e să fie folosit „cu măsură" (sparingly). Sursă: idem. Încredere: ridicată.
- `Enum.RenderPriority`: **First = 0, Input = 100, Camera = 200, Character = 300, Last = 2000**. Sursă: [RenderPriority | Roblox Creator Hub](https://create.roblox.com/docs/reference/engine/enums/RenderPriority), accesat 2026-09-08. Încredere: ridicată (oficial).
- MicroProfiler se deschide în Studio cu **Ctrl+Alt+F6** (Mac: **Cmd+Opt+F6**); pauză/detaliu cu **Ctrl+P** (Mac **Cmd+P**); Performance Summary overlay cu **Ctrl+Shift+F5** (Mac **Cmd+Shift+F5**). Sursă: [MicroProfiler walkthrough](https://create.roblox.com/docs/performance-optimization/microprofiler/use-microprofiler), accesat 2026-09-08. Încredere: ridicată (oficial).
- Performance Stats overlay (memorie, CPU, GPU, date de rețea, ping) se deschide cu **Ctrl+Alt+F7** (Mac **Cmd+Opt+F7**). Sursă: [Identify performance issues](https://github.com/Roblox/creator-docs/blob/main/content/en-us/performance-optimization/identify.md), accesat 2026-09-08. Încredere: ridicată (oficial).
- `Stats:GetTotalMemoryUsageMb()` întoarce memoria totală a sesiunii curente, în MB, luată de la sistemul de operare. `Stats:GetMemoryUsageMbForTag(tag: Enum.DeveloperMemoryTag)` întoarce memoria pe categorie, dar returnează 0 + warning dacă `Stats.MemoryTrackingEnabled` e false. `Enum.DeveloperMemoryTag` are 24 valori, printre care **`Gui`** ("memorie folosită de elementele GUI comune"). Sursă: [Stats | Roblox Creator Hub](https://create.roblox.com/docs/reference/engine/classes/Stats), [DeveloperMemoryTag | Roblox Creator Hub](https://create.roblox.com/docs/reference/engine/enums/DeveloperMemoryTag), accesat 2026-09-08. Încredere: ridicată (oficial).
- Recomandare oficială de dimensiune texturi: texturile în general nu ar trebui să depășească 512×512px dacă nu ocupă mult ecran; **imaginile UI minore ar trebui să fie sub 256×256px**. Sursă: [performance-optimization/improve.md, creator-docs (GitHub)](https://github.com/Roblox/creator-docs/blob/main/content/en-us/performance-optimization/improve.md), accesat 2026-09-08. Încredere: ridicată (oficial).
- Cea mai eficientă pârghie pentru memorie client, conform documentației oficiale, este **instance streaming**. Sursă: [studio/optimization/memory-usage.md](https://create.roblox.com/docs/studio/optimization/memory-usage.md), accesat 2026-09-08. Încredere: ridicată (oficial), dar relevanța pentru un joc 100% ScreenGui e limitată (streaming-ul vizează în primul rând `workspace`).
- Nu există prag/limita oficial de memorie documentat exact pentru „mobil low-end"; documentația spune doar generic că depășirea limitelor motorului poate cauza crash. Sursă: idem. Încredere: ridicată pentru absența cifrei, nu pentru o cifră anume.
- Un thread de comunitate (nu oficial) despre optimizare de performanță citează ținte proprii: CPU/GPU ~15-20ms per frame ca țintă bună, cu mențiunea că Roblox recomandă undeva la 33ms ca linie de bază; memorie 400-600MB rezonabil în 2021, cu o notă a autorului (nedatată explicit, dar ulterioară) că bugetele reale au crescut spre 900-1200MB, multe jocuri ajungând la ~1500MB. Sursă: [Improving Game Performance: Benchmarking, Microprofiler, Developer Stats, and Developer Console](https://devforum.roblox.com/t/improving-game-performance-benchmarking-microprofiler-developer-stats-and-developer-console/1002074), DevForum, 23 ianuarie 2021 (tutorial de comunitate). Încredere: **scăzută** — cifre neoficiale, thread vechi (pre-2024), posibil neactualizat corect.
- Nu am găsit niciun benchmark cu un număr exact de GuiObject-uri mobile la 60fps, nici oficial, nici în comunitate. **NEVERIFICAT** — trebuie testat direct pentru profilul grafic al lui Driftwood.
- Un raport de comunitate (despre `Part`, nu `GuiObject`, dar același tipar de scriere-de-poziție-pe-frame) arată că 200+ Part-uri ancorate mutate prin `CFrame`/`Position` în buclă pe `RenderStepped` au produs „huge CPU spikes and low fps", mai ales pe dispozitive slabe; soluțiile propuse au fost fizica motorului sau sudarea (`Weld`) la o singură piesă-rădăcină. Sursă: [Poor performance updating hundreds of part positions](https://devforum.roblox.com/t/poor-performance-updating-hundreds-of-part-positions/2191572), DevForum, februarie 2023. Încredere: medie (comunitate, anecdotă unică, obiect diferit de GuiObject, dar mecanism Luau similar).
- Object pooling (refolosirea instanțelor în loc de `Instance.new()`/`Destroy()`) e practica standard recomandată de comunitate pentru scenarii cu multe obiecte tranzitorii (ex. bullet-hell cu 200+ proiectile pe ecran). Surse: [Strategy to optimize performance on a bullet-hell game genre](https://devforum.roblox.com/t/strategy-to-optimize-performance-on-a-bullet-hell-game-genre-in-roblox/1706889), DevForum, dată nespecificată explicit (comunitate); [Handling thousands of projectiles with high performance](https://devforum.roblox.com/t/handling-thousands-of-projectiles-with-high-performance/735531), DevForum, comunitate. Încredere: medie (consens de comunitate, fără cifre riguroase).
- Avertismentul „nu folosi `Instance.new()` cu al doilea argument (parent)" datează din **31 octombrie 2016**; un thread din **aprilie 2023** confirmă informal (nu oficial) că problema „nu a fost schimbată". Surse: [PSA: Don't use Instance.new() with parent argument](https://devforum.roblox.com/t/psa-dont-use-instancenew-with-parent-argument/30296), 2016; [Is the performance issue... fixed?](https://devforum.roblox.com/t/is-the-performance-issue-with-the-parent-argument-in-instancenew-fixed/2297919), aprilie 2023. Încredere: **scăzută/medie** — foarte vechi, confirmare doar informală, de tratat cu prudență (posibil depășit de optimizări interne ulterioare ale motorului, dar practica „setează Parent ultimul" nu costă nimic în plus, deci merită păstrată oricum).
- Cerințe minime oficiale mobil: **iOS 14+** (iPhone 6s și mai noi), **Android 8.0+** cu suport **OpenGL ES 3.0**. Surse: [Roblox Mobile System Requirements](https://en.help.roblox.com/hc/en-us/articles/203625474-Roblox-Mobile-System-Requirements), Roblox Support (oficial); [Computer Hardware & Operating System Requirements](https://en.help.roblox.com/hc/en-us/articles/203312800-Computer-Hardware-Operating-System-Requirements), Roblox Support (oficial). Încredere: ridicată (oficial), dar paginile nu poartă o dată explicită de ultimă actualizare vizibilă în conținutul extras — de reverificat periodic.
- UIGradient: recomandare de comunitate de a nu combina cu `TextStrokeColor3` (probleme de blending/randare) și de a nu depăși ~6 opriri de culoare în `ColorSequence`. Sursă: discuții comunitate DevForum despre UIGradient/UIStroke. Încredere: scăzută (recomandări de comunitate, fără cifră/mecanism oficial confirmat).

## Detalii

### 1. Cum randează motorul UI-ul 2D — mecanismul de cache din 2019

Din 2019, Roblox nu mai regenerează geometria de randare a fiecărui `GuiObject` din fiecare `LayerCollector` (adică `ScreenGui`, `BillboardGui`, `SurfaceGui`) în fiecare frame. În schimb, aspectul e cache-uit și invalidat doar când:
- se adaugă/șterge un descendent, sau
- se schimbă orice proprietate a unui descendent, sau
- se schimbă o proprietate a `LayerCollector`-ului însuși.

Detaliul critic pentru arhitectura Driftwood: invalidarea e **la nivel de LayerCollector**, nu la nivel de obiect individual. Dacă HUD-ul (bani, procent colecție, butoane) și râul (50-200 obiecte mobile) sunt în **același** `ScreenGui`, fiecare mutare de obiect din râu invalidează cache-ul întregului `ScreenGui`, inclusiv al HUD-ului static — anulând exact beneficiul pe care motorul îl oferă gratuit din 2019.

Recomandarea oficială explicită din thread-ul de anunț este să separi UI-ul majoritar-static de cel majoritar-dinamic în `ScreenGui`-uri diferite. Pentru Driftwood, asta înseamnă minim trei `ScreenGui` (sau containere separate, dacă motorul grupează caching-ul la alt nivel — de verificat empiric): unul pentru HUD static, unul pentru layer-ul de râu/plase (obiecte mobile), unul pentru overlay-uri ocazionale (dialog de reparat, meniuri).

### 2. RunService: ce buclă folosești pentru poziții

Ordinea per-frame pe client, conform documentației oficiale:

```
PreRender → PreAnimation → PreSimulation → PostSimulation → Heartbeat
```

- `RunService.PreRender` — rulează doar pe client, imediat înainte ca frame-ul curent să fie desenat. Este **înlocuitorul oficial al `RenderStepped`** (marcat deprecated). E locul recomandat pentru actualizări vizuale de ultim moment.
- `RunService.Heartbeat` — rulează după simularea fizică a frame-ului; util pentru logică generală de joc, dar **nu** garantează sincronizare optimă cu randarea vizuală a frame-ului curent (poate introduce un frame de lag perceptibil față de PreRender).
- `RunService:BindToRenderStep(name, priority, callback)` leagă un callback de faza de randare, cu o prioritate numerică (`Enum.RenderPriority`: First=0, Input=100, Camera=200, Character=300, Last=2000). Randarea frame-ului așteaptă până termină callback-ul, deci codul legat aici trebuie să fie scurt.

Pentru mișcarea celor 50-200 obiecte din râu, recomandarea derivată din documentație e clară: `PreRender` (fie evenimentul direct, fie `BindToRenderStep` cu prioritate apropiată de `Enum.RenderPriority.Last` dacă e „doar efect vizual", cum indică exemplul din documentație), **nu** `Heartbeat`.

Exemplu minimal (Luau):

```lua
local RunService = game:GetService("RunService")

RunService:BindToRenderStep("UpdateRiverObjects", Enum.RenderPriority.Last.Value, function(dt)
    for _, obj in ipairs(activeRiverObjects) do
        obj.gui.Position = UDim2.fromOffset(obj.x, obj.laneY)
        obj.x += obj.speed * dt
    end
end)
```

### 3. CanvasGroup — comportament, cost, `GroupTransparency`

`CanvasGroup` randează întregul lui subarbore ca o singură textură offscreen ("flattened group"), peste care se aplică `GroupColor3` și `GroupTransparency`. Asta permite transparență de grup uniformă (imposibil de simulat corect cu `Transparency` individual pe fiecare copil când există suprapuneri). Costuri și limitări confirmate oficial:

- Consumă **memorie de textură suplimentară**; calitatea și memoria maximă disponibilă sunt legate de `QualityLevel`-ul clientului (adică pe telefoane slabe, cu grafică redusă automat, un `CanvasGroup` poate arăta vizibil mai neclar).
- Dacă bugetul de memorie e depășit, `CanvasGroup` randează ca **textură goală** — un eșec silențios vizual, nu o eroare zgomotoasă.
- `ClipsDescendants` e mereu activat pe `CanvasGroup`.
- Randarea „flatten" funcționează doar când LayerCollector-ul ascendent are `ZIndexBehavior = Sibling`.
- Recomandare de comunitate (nu oficial confirmată cu cifre): redimensionarea frecventă a unui `CanvasGroup` forțează recrearea texturii — păstrează dimensiuni fixe acolo unde poți.

Pentru Driftwood: un `CanvasGroup` pe un singur card UI (ex. panoul de reparații, cu fundal + iconițe + progres, care se schimbă rar) e un caz de utilizare rezonabil. Un `CanvasGroup` care ar înveli **toată banda râului** cu 50-200 obiecte care se mișcă în fiecare frame ar re-randa acea textură offscreen la fiecare schimbare — exact scenariul pe care documentația și rapoartele de comunitate îl semnalează ca fiind costisitor și predispus la degradare vizuală pe grafică redusă. **Nu recomandat** pentru banda de râu.

### 4. EditableImage ca „software canvas" — de ce nu e viabil ca renderer principal

`EditableImage` permite desenare programatică pixel-cu-pixel: `DrawImage`, `DrawImageTransformed`, `DrawCircle`, `DrawLine`, `DrawRectangle`, `WritePixelsBuffer`, `ReadPixelsBuffer`, plus varianta pentru meshuri 3D (`DrawImageProjected`, `SampleImageProjected`). Se creează prin `AssetService:CreateEditableImage()` (gol) sau `AssetService:CreateEditableImageAsync()` (din asset existent), și poate fi legat de orice proprietate `Content` care acceptă imagine (ex. `ImageLabel.ImageContent`) prin `Content.fromObject(editableImage)`.

Limitele care contează pentru „poate randa tot ecranul de joc?":

1. **„Doar un singur EditableImage poate fi actualizat pe frame pe partea de display."** — citat direct din documentația oficială. Cu alte cuvinte, dacă ai N obiecte EditableImage afișate simultan și le modifici pe toate în fiecare frame, motorul le actualizează pe rând, câte unul pe frame — deci N imagini ating efectiv N frame-uri latență, nu actualizare simultană la 60fps. Pentru un joc care vrea 50-200 obiecte animate fluid, asta e descalificant dacă fiecare obiect ar fi propriul EditableImage.
2. **Rezoluție maximă 1024×1024** — confirmat oficial pentru proprietatea `Size`.
3. **Buget de memorie strict, client-side** — text oficial fără cifră exactă; comunitatea raportează în mod repetat **~32MB** per instanță (thread-uri februarie 2026), consistent cu erorile de tip „reaching memory budget limits" întâlnite de dezvoltatori după doar 5-6 instanțe.
4. **Limită de 8 instanțe** EditableImage/EditableMesh per client (raportat de comunitate, ianuarie 2026, confirmat implicit de faptul că un dezvoltator cere explicit creșterea acestei limite).
5. **Necesită verificare ID (13+) a proprietarului experienței** pentru a funcționa în orice experiență publicată, plus activarea manuală a toggle-ului „Enable Mesh / Image APIs". Asta transformă folosirea EditableImage dintr-o decizie tehnică într-o decizie de business/conformitate — un obstacol real pentru un developer solo nou pe platformă.

Concluzie tehnică: **EditableImage nu este un motor de randare 2D general viabil pentru Driftwood.** El poate fi util punctual — un singur canvas mic pentru un efect procedural (ex. o textură de apă generată, un pattern de zgârieturi pe un obiect reparat), actualizat rar sau la evenimente, nu la 60fps pe tot ecranul. Bibliotecile de comunitate precum **OSGL** demonstrează că poți face randare software (inclusiv path-tracing simplificat) pe un singur EditableImage la 30-60fps — dar asta e pentru efecte de tip „un canvas, multe calcule interne", nu pentru „sute de sprite-uri independente, fiecare cu propriul EditableImage".

### 5. Object pooling și costul Instance.new()/Destroy()

Nu există o cifră oficială Roblox pentru „costul în ms al unui Instance.new()". Ce există, consistent în comunitate:
- Crearea/distrugerea frecventă de instanțe (`Instance.new()` + `:Destroy()`) pe fiecare obiect nou apărut în râu, la ratele de spawn ale unui joc cu curent continuu, e un tipar clasic de „garbage generation" care comunitatea recomandă constant să fie evitat prin **pooling**: preinstanțiezi N obiecte `ImageLabel` (N = bugetul maxim concurent, ex. 200-300), le ții într-un pool cu `Visible = false`, și la spawn le iei din pool (`Visible = true`, setezi `Image`, `Position`, resetezi state), iar la ieșirea din ecran/prindere le pui înapoi în pool (`Visible = false`) — fără `Instance.new()`/`Destroy()` pe calea fierbinte.
- Vechiul avertisment „nu apela `Instance.new("ClassName", parent)` cu al doilea argument" (2016, reconfirmat informal 2023) rămâne o practică sigură de aplicat oricum (construiești obiectul, îi setezi proprietățile, îi setezi `Parent` ultimul) — costă zero și e coerentă cu recomandările actuale de a evita rescrierea arborelui de instanțe mai des decât e necesar.

Exemplu de schelet de pool pentru obiectele din râu (Luau):

```lua
local pool = {}
local POOL_SIZE = 250

local function createPooledObject(container)
    local img = Instance.new("ImageLabel")
    img.BackgroundTransparency = 1
    img.Visible = false
    img.Parent = container
    return img
end

for i = 1, POOL_SIZE do
    pool[i] = createPooledObject(riverLayerFrame)
end

local function acquire()
    for _, img in ipairs(pool) do
        if not img.Visible then
            img.Visible = true
            return img
        end
    end
    return nil -- pool epuizat: obiectul e sărit sau se mărește pool-ul la runtime
end

local function release(img)
    img.Visible = false
end
```

### 6. Costul scrierilor de proprietăți: Position, ZIndex, Transparency, gradient, text

Nu există un tabel oficial Roblox de „cost în ms per proprietate". Ce se poate deduce logic din faptele confirmate oficial:

- Orice scriere de proprietate pe un `GuiObject` invalidează cache-ul de aspect al întregului `LayerCollector` care îl conține (vezi secțiunea 1) — deci costul „ascuns" nu e doar setter-ul Luau (foarte ieftin), ci și faptul că geometria acelui `LayerCollector` trebuie regenerată la următorul frame randat.
- **ZIndex**: nu există o cifră specifică oficială, dar din același mecanism, schimbarea repetată de `ZIndex` (ex. pentru sortare de adâncime pe fiecare frame) e exact genul de scriere care anulează cache-ul. Recomandare derivată: atribuie `ZIndex` **o singură dată**, când obiectul intră pe „banda" lui (lane) din râu, nu recalculat în fiecare frame.
- **Transparency / GroupTransparency**: similar — scriere ieftină per-obiect ca instrucțiune Luau, dar declanșează recompunere; pentru `CanvasGroup.GroupTransparency` specific, orice schimbare re-randează textura offscreen a grupului (vezi secțiunea 3).
- **UIGradient**: comunitatea recomandă limitarea la ~6 opriri de culoare și evitarea combinării cu `TextStrokeColor3`; pentru un gradient care nu se schimbă niciodată (ex. tonul de fundal al apei), o imagine statică e mai ieftină la runtime decât un `UIGradient` recalculat, cu costul unui pic de memorie extra pentru asset.
- **Text/TextLabel**: nu am găsit cifre oficiale specifice de cost; principiul general din documentația de optimizare (imagini UI sub 256×256px, evitare de transparență stratificată) se aplică și textului — RichText și TextScaled adaugă calcule de layout, deci text care se schimbă des (ex. un contor) ar trebui actualizat doar quando valoarea se schimbă efectiv (event-driven), nu scris necondiționat în fiecare frame chiar dacă valoarea e identică.

### 7. UIListLayout / re-layout

Nu am reușit să extrag din documentația oficială o descriere textuală explicită a costului de recalculare al `UIListLayout` (pagina de referință listează doar proprietățile: `HorizontalFlex`, `ItemLineAlignment`, `Padding`, `VerticalFlex`, `Wraps`, fără o secțiune de „cum funcționează intern"). **NEVERIFICAT** cu sursă directă cât de des/cât costă re-layout-ul. Comportamentul general cunoscut al acestui tip de layout constraint (orice `UIListLayout`/`UIGridLayout` recalculează poziția tuturor elementelor-frați când unul dintre ei își schimbă `Size` sau e adăugat/șters) e coerent cu modul în care alte motoare de layout constraint-based funcționează, dar nu am o citare Roblox oficială pentru afirmația asta — de tratat ca ipoteză de proiectare, nu fapt confirmat.

Recomandare de proiectare, indiferent de cifra exactă: **nu pune banda de obiecte din râu (50-200 elemente mobile) sub un `UIListLayout`/`UIGridLayout`**. Poziționează-le manual prin `Position`/`UDim2`, exact ca în bucla din secțiunea 2. Rezervă `UIListLayout` pentru UI cu adevărat listat și rar schimbat (inventar, index de colecție, meniuri).

### 8. Unelte de profiling

| Unealtă | Cum se deschide | Ce arată | Sursă |
|---|---|---|---|
| MicroProfiler | `Ctrl+Alt+F6` (Mac `Cmd+Opt+F6`) în Studio | Timeline pe thread-uri/task-uri interne ale motorului per frame; pauză cu `Ctrl+P` / `Cmd+P` pentru mod detaliat | create.roblox.com/docs/performance-optimization/microprofiler |
| Performance Summary overlay | `Ctrl+Shift+F5` (Mac `Cmd+Shift+F5`) | Rezumat rapid de performanță | idem |
| Performance Stats overlay | `Ctrl+Alt+F7` (Mac `Cmd+Opt+F7`) | Memorie, CPU, GPU, date rețea trimise/primite, ping | create.roblox.com/docs/performance-optimization/identify |
| Developer Console | `F9` (în joc și în Studio) | Tab Memory (breakdown pe categorii), Server Jobs (Heartbeat steps/sec), Server Stats (ping) | create.roblox.com/docs/studio/developer-console |
| `Stats:GetTotalMemoryUsageMb()` | apel din script | Memoria totală a sesiunii, în MB | create.roblox.com/docs/reference/engine/classes/Stats |
| `Stats:GetMemoryUsageMbForTag(Enum.DeveloperMemoryTag.Gui)` | apel din script (necesită `Stats.MemoryTrackingEnabled == true`) | Memoria consumată specific de elementele GUI | idem + create.roblox.com/docs/reference/engine/enums/DeveloperMemoryTag |

Notă din documentație: MicroProfiler are o interfață web (recomandată acolo unde e posibil, inclusiv pentru mobil/dump-uri) și o interfață desktop (client + Studio) — deci profilarea pe telefon real e posibilă, nu doar în Studio pe desktop. Detaliile exacte de conectare la un device mobil nu au fost confirmate complet din paginile accesate — **NEVERIFICAT** pas-cu-pas, de urmărit direct în Studio (meniul de profiling la conectare de dispozitiv).

### 9. Memorie pe mobil / specificații minime

Nu există o cifră oficială de „buget de memorie UI pe mobil low-end" — documentația spune doar generic că depășirea limitelor motorului poate cauza crash pe dispozitiv sau server. Cerințele minime oficiale de sistem sunt **iOS 14+** (de la iPhone 6s în sus) și **Android 8.0+ cu OpenGL ES 3.0**, ceea ce arată că Roblox acceptă hardware destul de vechi/slab — deci testarea reală pe un device de gamă joasă (nu doar simulare în Studio pe desktop) rămâne singura cale de a valida bugetul de performanță al lui Driftwood, întrucât Studio rulează pe hardware desktop și nu reproduce throttling termic sau GPU-uri mobile slabe.

## Recomandari concrete pentru Driftwood

1. **Randare 100% cu `GuiObject` clasic (`Frame`/`ImageLabel`), fără `EditableImage` ca renderer principal.** Motiv: limita oficială de „un singur EditableImage actualizat pe frame", plafonul de 1024×1024, bugetul de ~32MB și limita de 8 instanțe per client fac din EditableImage o unealtă pentru efecte punctuale, nu pentru randarea a 50-200 obiecte animate simultan la 60fps. În plus, cerința de verificare ID (13+) pentru proprietarul experienței adaugă o barieră administrativă care nu merită asumată doar pentru randare de bază.
2. **Separă HUD-ul static de layer-ul dinamic (râu, plase) în `ScreenGui`-uri distincte** de la început, nu ca refactorizare ulterioară. Motiv: mecanismul de cache al aspectului GUI din 2019 invalidează la nivel de `LayerCollector` — dacă totul e într-un singur ScreenGui, mișcarea râului anulează în fiecare frame beneficiul de cache pentru HUD.
3. **Actualizează pozițiile obiectelor din râu pe `RunService.PreRender`** (sau `BindToRenderStep` cu prioritate apropiată de `Enum.RenderPriority.Last`), nu pe `Heartbeat` și nu pe deprecatul `RenderStepped`. Motiv: `PreRender` e recomandarea oficială curentă pentru actualizări vizuale imediat înainte de randare; `Heartbeat` rulează după simularea fizică și poate introduce un frame de întârziere vizuală.
4. **Implementează object pooling pentru obiectele din râu de la primul prototip** (pas 1 din ordinea de lucru din CLAUDE.md), nu ca optimizare ulterioară. Preinstanțiază un pool de ~200-300 `ImageLabel` cu `Visible=false`, reciclează-le la spawn/despawn, evită `Instance.new()`/`:Destroy()` pe calea fierbinte a jocului (fiecare obiect nou care apare la marginea din stânga a ecranului).
5. **Nu folosi `CanvasGroup` peste toată banda râului.** Motiv: re-randează întreaga textură offscreen la orice schimbare a subarborelui, e limitat de `QualityLevel`-ul clientului și poate randa gol dacă bugetul de memorie e depășit. Rezervă `CanvasGroup` pentru elemente relativ statice (panouri de UI cu transparență de grup, ex. fereastra de reparații).
6. **Setează `ZIndex` o singură dată per obiect din râu**, la spawn (în funcție de „lane"/adâncime fixă), nu recalculat în fiecare frame. Motiv: orice scriere de proprietate pe `GuiObject` declanșează invalidare de cache la nivel de ScreenGui; scrierile repetitive și evitabile trebuie eliminate din bucla per-frame.
7. **Poziționează manual obiectele din râu (`Position` direct), fără `UIListLayout`/`UIGridLayout` pe acel layer.** Rezervă layout-urile automate pentru UI cu adevărat listat (inventar, index de colecție) care se schimbă rar, nu pentru 50-200 obiecte animate continuu.
8. **Ține imaginile UI mici sub 256×256px** acolo unde nu ocupă mult ecran (iconițe, sprite-uri de obiecte din râu), conform recomandării oficiale de optimizare — reduce presiunea pe memoria de textură pe mobil low-end.
9. **Actualizează text/contoare doar când valoarea se schimbă efectiv** (event-driven), nu necondiționat în fiecare frame, chiar dacă valoarea e identică — evită invalidări de cache inutile pe `TextLabel`-urile din HUD.
10. **Profilează de la primul prototip, nu la final**: folosește `Ctrl+Alt+F6` (MicroProfiler) și `Ctrl+Alt+F7` (Performance Stats) în Studio pe fiecare iterație majoră, plus `Stats:GetMemoryUsageMbForTag(Enum.DeveloperMemoryTag.Gui)` logat periodic în telemetrie proprie, ca să ai o baseline reală pentru Driftwood, nu cifre generice găsite online.
11. **Testează pe un device Android low-end real** (Android 8.0-clasă, sau echivalent modern accesibil ca preț) și pe un iPhone vechi (6s-clasă dacă posibil, altfel cel mai vechi model la îndemână), nu doar în Studio pe desktop — Studio nu reproduce throttling termic/GPU mobil slab, iar toate cifrele de „buget de memorie" găsite online sunt neoficiale.
12. **Nu investi timp în `Instance.new()` cu argumentul `parent`** — setează proprietățile mai întâi, `Parent` ultimul, peste tot în codul de spawn al obiectelor din râu; e o practică fără cost suplimentar, indiferent dacă problema originală din 2016 mai există intern sau nu.

## Riscuri si necunoscute

- Nu există niciun benchmark public, oficial sau de comunitate, cu o cifră exactă de „câte GuiObject-uri poți muta pe frame la 60fps pe mobil low-end". Orice buget numeric din acest document (ex. „pool de 200-300") e o estimare de proiectare, nu un fapt măsurat — **trebuie validat empiric în Studio + pe device real** pentru complexitatea vizuală reală a sprite-urilor din Driftwood (dimensiune imagine, transparență, gradient, text suprapus).
- Mecanismul de cache al aspectului GUI descris în secțiunea 1 vine dintr-un anunț din **2019**; nu am găsit o reconfirmare recentă (2024-2026) a exact acelorași cifre de exemplu, deși nu am găsit nici vreo dovadă că mecanismul de bază ar fi fost eliminat sau schimbat fundamental.
- Cifrele pentru EditableImage (32MB, limită de 8 instanțe) vin din thread-uri de comunitate (ianuarie-februarie 2026) care cer explicit *creșterea* acestor limite — asta le face plauzibile ca fiind curente, dar ele nu sunt confirmate textual într-o pagină oficială de referință cu cifre explicite; Roblox și-a rezervat dreptul de a le schimba fără preaviz („memory budgeting is dynamic").
- Nu s-a putut confirma dacă `RunService.PreRender` este disponibil (sau are sens) în afara unui `LocalScript` — documentația îl marchează „client-side only", ceea ce înseamnă că nu poate fi folosit din `ServerScriptService`, doar din `StarterPlayerScripts`/`LocalScript`. Pentru Driftwood, asta e oricum coerent cu arhitectura descrisă în CLAUDE.md (server autoritar pentru economie, dar randarea vizuală a mișcării râului e strict cosmetică pe client, cu poziția logică/„catch" validată server-side).
- Nu am găsit o pagină oficială dedicată exclusiv „performanță UI 2D" — informația e împrăștiată între pagina de clasă `GuiObject`/`CanvasGroup`/`EditableImage`, pagina generică de performanță (`performance-optimization/improve.md`, orientată în principal spre scene 3D/draw calls) și thread-uri de comunitate. E posibil să existe conținut oficial suplimentar neindexat de căutările folosite.

## Intrebari deschise

1. Care e bugetul real de obiecte concurente din râu la care Driftwood va rula, dat fiind design-ul din CLAUDE.md (curent continuu, sezoane cu debit diferit, evenimentul de Inundație cu „de zece ori mai mult")? Vârful de Inundație (posibil 500-2000+ obiecte teoretice dacă e scalat liniar din 50-200 normal) trebuie testat separat — probabil are nevoie de un plafon explicit (`POOL_SIZE` mai mare doar în timpul evenimentului, sau un cap dur pe obiecte vizibile simultan cu prioritizare pe cele din raza vizibilă a ecranului).
2. Cât de mult ajută despărțirea pe `ScreenGui`-uri multiple în practică pentru Driftwood specific (HUD + râu + overlay-uri) — de măsurat cu MicroProfiler înainte/după, nu doar de presupus din citatul din 2019.
3. Merită un `CanvasGroup` izolat, de dimensiune fixă, pentru panoul de reparații/atelier (care se schimbă la evenimente, nu per frame), sau simplă compunere de `ImageLabel`+`Frame` fără `CanvasGroup` e suficientă? De prototipat ambele variante și comparat vizual + în MicroProfiler.
4. Care e pragul real de fps acceptabil pentru Driftwood pe mobil — 60fps peste tot, sau 30fps ca prag minim acceptat pe dispozitive foarte slabe (coerent cu ce sugerează tutorialele de comunitate despre bugetul de 33ms), cu degradare grațioasă (mai puține obiecte vizibile simultan, poate reducere de densitate a râului) sub acel prag? Decizie de produs, nu doar tehnică.
5. Cât de utilă e telemetria proprie pe `Stats:GetMemoryUsageMbForTag(Enum.DeveloperMemoryTag.Gui)` trimisă către un `DataStore`/serviciu extern de analytics, ca să existe date reale de teren (nu doar Studio) despre memoria UI pe dispozitivele efective ale jucătorilor de test? De configurat înainte de primul playtest cu oameni reali (pasul 1 din CLAUDE.md).
6. De testat concret în Studio: la câte obiecte `ImageLabel` poolate, actualizate pe `PreRender`, cu sprite-urile reale (nu dreptunghiuri goale) ale lui Driftwood, MicroProfiler arată timp de frame peste 16.67ms pe un profil de grafică simulat „low"? Acesta e singurul mod de a înlocui cifrele NEVERIFICAT din acest document cu date reale, specifice proiectului.

## Surse

- [CanvasGroup | Documentation - Roblox Creator Hub](https://create.roblox.com/docs/reference/engine/classes/CanvasGroup) — accesat 2026-09-08
- [CanvasGroup.yaml — Roblox/creator-docs (GitHub)](https://github.com/Roblox/creator-docs/blob/main/content/en-us/reference/engine/classes/CanvasGroup.yaml) — accesat 2026-09-08
- [EditableImage | Documentation - Roblox Creator Hub](https://create.roblox.com/docs/reference/engine/classes/EditableImage) — accesat 2026-09-08
- [EditableImage.yaml — Roblox/creator-docs (GitHub)](https://github.com/Roblox/creator-docs/blob/main/content/en-us/reference/engine/classes/EditableImage.yaml) — accesat 2026-09-08
- [RunService | Documentation - Roblox Creator Hub](https://create.roblox.com/docs/reference/engine/classes/RunService) — accesat 2026-09-08
- [RunService.yaml — Roblox/creator-docs (GitHub)](https://github.com/Roblox/creator-docs/blob/main/content/en-us/reference/engine/classes/RunService.yaml) — accesat 2026-09-08
- [RenderPriority | Documentation - Roblox Creator Hub](https://create.roblox.com/docs/reference/engine/enums/RenderPriority) — accesat 2026-09-08
- [MicroProfiler walkthrough | Documentation - Roblox Creator Hub](https://create.roblox.com/docs/performance-optimization/microprofiler/use-microprofiler) — accesat 2026-09-08
- [Identify performance issues — Roblox/creator-docs (GitHub)](https://github.com/Roblox/creator-docs/blob/main/content/en-us/performance-optimization/identify.md) — accesat 2026-09-08
- [Memory usage | Documentation - Roblox Creator Hub](https://create.roblox.com/docs/studio/optimization/memory-usage.md) — accesat 2026-09-08
- [Design for low memory devices — Roblox/creator-docs (GitHub)](https://github.com/Roblox/creator-docs/blob/main/content/en-us/performance-optimization/design.md) — accesat 2026-09-08
- [Improve performance — Roblox/creator-docs (GitHub)](https://github.com/Roblox/creator-docs/blob/main/content/en-us/performance-optimization/improve.md) — accesat 2026-09-08
- [Stats | Documentation - Roblox Creator Hub](https://create.roblox.com/docs/reference/engine/classes/Stats) — accesat 2026-09-08
- [DeveloperMemoryTag | Documentation - Roblox Creator Hub](https://create.roblox.com/docs/reference/engine/enums/DeveloperMemoryTag) — accesat 2026-09-08
- [UIListLayout | Documentation - Roblox Creator Hub](https://create.roblox.com/docs/reference/engine/classes/UIListLayout) — accesat 2026-09-08
- [Static UI Performance Improvements — DevForum (oficial, Homeomorph)](https://devforum.roblox.com/t/static-ui-performance-improvements/222557) — 9 ianuarie 2019
- [ScreenGui performance: One vs. Many — DevForum (comunitate)](https://devforum.roblox.com/t/screengui-performance-one-vs-many/346193) — data exactă nedeterminată din conținutul accesat
- [CanvasGroup Performance Concerns — DevForum (comunitate)](https://devforum.roblox.com/t/canvasgroup-performance-concerns/3556937) — 2024
- [[Client Beta] In-experience Mesh & Image APIs now available in published experiences — DevForum (oficial)](https://devforum.roblox.com/t/client-beta-in-experience-mesh-image-apis-now-available-in-published-experiences/3267293) — 20 noiembrie 2024
- [Remove Editable Mesh/Image limit on the client — DevForum (comunitate)](https://devforum.roblox.com/t/remove-editable-meshimage-limit-on-the-client/4219561) — 5 ianuarie 2026
- [EditableImage higher resolution and memory limit — DevForum (comunitate)](https://devforum.roblox.com/t/editableimage-higher-resolution-and-memory-limit/4389575) — 16 februarie 2026
- [Strategy to optimize performance on a bullet-hell game genre in Roblox — DevForum (comunitate)](https://devforum.roblox.com/t/strategy-to-optimize-performance-on-a-bullet-hell-game-genre-in-roblox/1706889) — data nespecificată
- [Handling thousands of projectiles with high performance — DevForum (comunitate)](https://devforum.roblox.com/t/handling-thousands-of-projectiles-with-high-performance/735531) — data nespecificată
- [Poor performance updating hundreds of part positions — DevForum (comunitate)](https://devforum.roblox.com/t/poor-performance-updating-hundreds-of-part-positions/2191572) — februarie 2023
- [Gui performance — DevForum (comunitate)](https://devforum.roblox.com/t/gui-performance/2949238) — data nespecificată
- [Improving Game Performance: Benchmarking, Microprofiler, Developer Stats, and Developer Console — DevForum (tutorial comunitate)](https://devforum.roblox.com/t/improving-game-performance-benchmarking-microprofiler-developer-stats-and-developer-console/1002074) — 23 ianuarie 2021 (posibil neactualizat; flag pre-2024)
- [PSA: Don't use Instance.new() with parent argument — DevForum (comunitate)](https://devforum.roblox.com/t/psa-dont-use-instancenew-with-parent-argument/30296) — 31 octombrie 2016 (foarte vechi; flag pre-2024)
- [Is the performance issue with the parent argument in Instance.new() fixed? — DevForum (comunitate)](https://devforum.roblox.com/t/is-the-performance-issue-with-the-parent-argument-in-instancenew-fixed/2297919) — aprilie 2023
- [OSGL - EditableImage graphics library — DevForum (comunitate)](https://devforum.roblox.com/t/osgl-editableimage-graphics-library/3066757) — data nespecificată
- [Failed to create empty EditableImage... memory budget limits error — DevForum (comunitate)](https://devforum.roblox.com/t/failed-to-create-empty-editableimage-that-was-requested-due-to-reaching-memory-budget-limits-error/3490799) — data nespecificată
- [Roblox Mobile System Requirements — Roblox Support (oficial)](https://en.help.roblox.com/hc/en-us/articles/203625474-Roblox-Mobile-System-Requirements) — accesat 2026-09-08
- [Computer Hardware & Operating System Requirements — Roblox Support (oficial)](https://en.help.roblox.com/hc/en-us/articles/203312800-Computer-Hardware-Operating-System-Requirements) — accesat 2026-09-08

## Verificare independenta (2026-09-08)

**Notă a verificatorului:** fișierul conținea deja, la momentul preluării acestei sarcini, o secțiune cu acest titlu exact, aparent adăugată de agentul care a scris nota (nu de un verificator extern separat) — un semnal de atenție în sine, pentru că un agent care își "auto-verifică" propriile afirmații nu e o verificare independentă reală, indiferent cât de corect arată rezultatul. Secțiunea de mai jos înlocuiește conținutul anterior cu o verificare făcută separat, din zero, prin acces direct la sursele primare (fișiere raw YAML/Markdown din `Roblox/creator-docs` pe GitHub, pagini `create.roblox.com/docs`, postări `devforum.roblox.com`, căutare web pentru `en.help.roblox.com`) — nu prin re-citirea citărilor din notă sau din secțiunea preexistentă. Rezultatul: cele 14 afirmații cu impact ridicat verificate mai jos s-au confirmat identic cu ce fusese scris în notă (inclusiv în secțiunea preexistentă); nu a fost necesară nicio corecție în corpul notei.

| Afirmatie | Verdict | Valoare corecta | Sursa (URL, data) |
|---|---|---|---|
| Cache-ul de aspect GUI e activ din 2019 la nivel de `LayerCollector` (ScreenGui); un `GuiObject` nemodificat nu se recalculează; exemplu oficial 1.9ms | CONFIRMAT | Text oficial confirmat: „A Gui's appearance is cached until..."; „The new system saves 1.9 milliseconds on my laptop"; recomandare de separare static/dinamic confirmată identic | [Static UI Performance Improvements, DevForum (Homeomorph, Roblox staff)](https://devforum.roblox.com/t/static-ui-performance-improvements/222557) — postat 2019-01-09, verificat direct 2026-09-08/09 |
| `RenderStepped` e deprecated, înlocuit oficial de `PreRender`; `Stepped` e deprecated, înlocuit de `PreSimulation` | CONFIRMAT | Text oficial identic: „superseded by PreRender which should be used for new work" / „superseded by PreSimulation which should be used for new work" | [RunService.yaml, creator-docs (GitHub raw)](https://raw.githubusercontent.com/Roblox/creator-docs/main/content/en-us/reference/engine/classes/RunService.yaml) — verificat 2026-09-08/09 |
| Ordinea `RunService` pe frame (client): PreRender → PreAnimation → PreSimulation → PostSimulation → Heartbeat | CONFIRMAT | Confirmat prin descrierile individuale ale fiecărui eveniment din sursă (nu există un tabel unic explicit în YAML, dar succesiunea logică descrisă corespunde) | [RunService.yaml, creator-docs (GitHub raw)](https://raw.githubusercontent.com/Roblox/creator-docs/main/content/en-us/reference/engine/classes/RunService.yaml) — verificat 2026-09-08/09 |
| `EditableImage`: doar un singur EditableImage poate fi actualizat pe frame pe partea de display | CONFIRMAT | Citat oficial identic: „Only a single EditableImage can be updated per frame on the display side." | [EditableImage.yaml, creator-docs (GitHub raw)](https://raw.githubusercontent.com/Roblox/creator-docs/main/content/en-us/reference/engine/classes/EditableImage.yaml) — verificat 2026-09-08/09 |
| `EditableImage`: rezoluție maximă 1024×1024; necesită proprietar 13+ ID-verificat + toggle "Enable Mesh / Image APIs" din Creator Dashboard | CONFIRMAT | Citat oficial identic: „The maximum size is 1024×1024."; „you must be 13+ age verified and ID verified. After you are verified, open the Creator Dashboard and toggle on Enable Mesh / Image APIs." Notă suplimentară: anunțul oficial din nov. 2024 folosea denumirea/locația „Allow Mesh / Image APIs" în Studio ▸ Game Settings ▸ Security — pare să se fi redenumit/mutat între timp; nota citează corect denumirea curentă din documentația de referință. | [EditableImage.yaml, creator-docs (GitHub raw)](https://raw.githubusercontent.com/Roblox/creator-docs/main/content/en-us/reference/engine/classes/EditableImage.yaml) — verificat 2026-09-08/09; comparat cu [anunțul din 2024-11-20, DevForum](https://devforum.roblox.com/t/client-beta-in-experience-mesh-image-apis-now-available-in-published-experiences/3267293) |
| `EditableImage`: ~32MB per instanță (cifră de comunitate, neoficială) | CONFIRMAT (ca citat de comunitate, corect etichetat neoficial în notă) | Citat verificat: „its 32MB and 1024x1024 limit" | [EditableImage higher resolution and memory limit, DevForum](https://devforum.roblox.com/t/editableimage-higher-resolution-and-memory-limit/4389575) — postat 2026-02-16, verificat 2026-09-08/09 |
| `EditableImage`/`EditableMesh`: limită de 8 instanțe per client (cifră de comunitate, neoficială) | CONFIRMAT (ca citat de comunitate) | Citat verificat: „limited a lot by the current set limit of 8 for both of them" | [Remove Editable Mesh/Image limit on the client, DevForum](https://devforum.roblox.com/t/remove-editable-meshimage-limit-on-the-client/4219561) — postat 2026-01-05, verificat 2026-09-08/09 |
| `Enum.RenderPriority`: First=0, Input=100, Camera=200, Character=300, Last=2000 | CONFIRMAT | Confirmat identic, toate cele 5 valori | [RenderPriority, Roblox Creator Hub](https://create.roblox.com/docs/reference/engine/enums/RenderPriority) — verificat 2026-09-08/09 |
| MicroProfiler: `Ctrl+Alt+F6`/`Cmd+Opt+F6`; pauză `Ctrl+P`/`Cmd+P`; Performance Summary overlay `Ctrl+Shift+F5`/`Cmd+Shift+F5`; Performance Stats overlay `Ctrl+Alt+F7`/`Cmd+Opt+F7` | CONFIRMAT | Confirmat identic pe pagina dedicată MicroProfiler și pe pagina "identify performance issues" | [MicroProfiler walkthrough](https://create.roblox.com/docs/performance-optimization/microprofiler/use-microprofiler); [identify.md, creator-docs (GitHub raw)](https://raw.githubusercontent.com/Roblox/creator-docs/main/content/en-us/performance-optimization/identify.md) — verificat 2026-09-08/09 |
| Cerințe minime mobil: iOS 14+/iPadOS 14+ (de la iPhone 6s), Android 8.0+ cu OpenGL ES 3.0 | CONFIRMAT (indirect) | Conținut consecvent regăsit: „requires iOS 14 / iPadOS 14 or higher... minimum supported devices include: iPhone 6s..."; „Android OS 8.0 or higher... support at least OpenGL ES 3.0" | [Roblox Mobile System Requirements, Roblox Support](https://en.help.roblox.com/hc/en-us/articles/203625474-Roblox-Mobile-System-Requirements) — pagina live a răspuns 403 la acces automat (curl și fetch direct), atât la verificarea inițială cât și acum; conținutul a fost confirmat doar indirect, prin motor de căutare care indexează pagina oficială — de tratat cu prudență minoră până la o vizualizare manuală în browser |
| Recomandare oficială: imagini UI minore sub 256×256px; texturi generale sub 512×512px dacă nu ocupă mult ecran | CONFIRMAT | Citat oficial identic: „Most minor images should be smaller than 256x256 pixels."; „it usually needs at most 512x512 pixels." | [performance-optimization/improve.md, creator-docs (GitHub raw)](https://raw.githubusercontent.com/Roblox/creator-docs/main/content/en-us/performance-optimization/improve.md) — verificat 2026-09-08/09 |
| `Enum.DeveloperMemoryTag` are 24 valori, incluzând `Gui` | CONFIRMAT | Numărătoare directă, independentă, prin `curl` + `grep -c "^\s*- name:"` pe sursa raw: exact 24 intrări; `Gui` are câmpul `value: 21` (poziția 20 în listă, indexare de la 0 pentru valoare) | [DeveloperMemoryTag.yaml, creator-docs (GitHub raw)](https://raw.githubusercontent.com/Roblox/creator-docs/main/content/en-us/reference/engine/enums/DeveloperMemoryTag.yaml) — verificat prin curl direct, 2026-09-08/09 |
| `CanvasGroup`: randarea „flatten" funcționează doar dacă `ZIndexBehavior=Sibling`; dacă bugetul de memorie e depășit, randează textură goală; `ClipsDescendants` mereu `true` | CONFIRMAT | Citate oficiale identice: „...will be rendered as a flattened texture only when the ancestor LayerCollector has its ZIndexBehavior set to Enum.ZIndexBehavior.Sibling."; „When exceeding the memory cap, CanvasGroup will render as a blank texture."; „CanvasGroup always has ClipsDescendants set to true" | [CanvasGroup.yaml, creator-docs (GitHub raw)](https://raw.githubusercontent.com/Roblox/creator-docs/main/content/en-us/reference/engine/classes/CanvasGroup.yaml) — verificat 2026-09-08/09 |

**Concluzie:** din cele 14 afirmații cu impact ridicat re-verificate independent, toate au fost **CONFIRMAT** contra surselor primare (documentație oficială Roblox Creator Hub, fișiere sursă `creator-docs` de pe GitHub, postări originale DevForum). Nu s-a găsit nicio afirmație **CORECTAT** sau **DEPASIT** — deci nu a fost nevoie de nicio modificare a valorilor din corpul notei. Singura rezervă reală: pagina `en.help.roblox.com` despre cerințele mobile a blocat accesul automat (403) la fiecare încercare directă, deci acea afirmație e confirmată doar indirect (căutare web + surse secundare consistente), nu prin citire directă a paginii — recomandat să fie verificată o dată manual, în browser, de cineva din echipă. De asemenea, denumirea/locația exactă a toggle-ului pentru EditableImage pare să se fi schimbat între anunțul din 2024 și documentația curentă (din "Allow Mesh / Image APIs" în Studio, spre "Enable Mesh / Image APIs" în Creator Dashboard) — nota citează corect varianta curentă, dar merită atenție dacă echipa urmează instrucțiuni mai vechi găsite online.
