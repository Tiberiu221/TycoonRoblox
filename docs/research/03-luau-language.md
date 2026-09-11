# Luau: tipuri, performanta, capcane — note de cercetare pentru Driftwood

## Rezumat executiv

- Luau are un type checker gradual (nu strict ca TypeScript by default). Incepand cu **20 noiembrie 2025**, modul implicit pentru toate scripturile a devenit **`--!nonstrict`** (inainte era mai lejer definit per-loc); pentru siguranta de tip similara cu TypeScript trebuie activat explicit `--!strict` pe fiecare fisier sau global prin `Workspace.LuauTypeCheckMode`. [create.roblox.com/docs/luau/type-checking; devforum.roblox.com/t/general-release-luau's-new-type-solver/4084991]
- Un "New Type Solver" a intrat in general release pe **20 noiembrie 2025**; solverul vechi ramane disponibil pana cel putin 2026, dar feature flag-ul de Studio Beta pentru comutare a fost eliminat pe **7 ianuarie 2026**. Roblox recunoaste bug-uri de corectitudine ramase in strict mode. [devforum.roblox.com/t/general-release-luau's-new-type-solver/4084991]
- **`task` library** (`task.spawn`, `task.wait`, `task.delay`, `task.defer`, `task.cancel`) inlocuieste global functions `wait()`, `spawn()`, `delay()`, care sunt considerate legacy/deprecated si mai putin precise. [create.roblox.com/docs/reference/engine/libraries/task]
- **`buffer`** (beta din noiembrie 2023, live din decembrie 2023, suport DataStore/MemoryStore/MessagingService/TeleportService/HttpService din februarie 2024) e util pentru date binare compacte, dar e overkill pentru MVP-ul Driftwood — tabelele Luau obisnuite sunt suficiente la inceput. [devforum.roblox.com/t/introducing-luau-buffer-type-beta/2724894]
- **`vector`** e acum un tip primitiv nativ (3 componente x/y/z, ca Vector3 dar mai usor), optimizat cu fastcall si constant-folding — dar Driftwood e ScreenGui 2D pur (`UDim2`/`Vector2` pentru pozitii de `Frame`), deci beneficiul direct e limitat la calcule interne, nu la randare. [rfcs.luau.org/vector-library.html; luau.org/news/2025-12-19-luau-recap-runtime-2025]
- **Native code generation** (`--!native` per script, `@native` per functie) e disponibil implicit pe server si in Studio din **iulie 2024**, cu castig tipic **1.5x–2.5x** pe cod cu multe calcule numerice — dar trebuie aplicat selectiv (masurat cu Script Profiler), nu peste tot. [devforum.roblox.com/t/luau-native-code-generation-preview-update/2961746; create.roblox.com/docs/luau/native-code-gen]
- **Require-by-string** (`require("./Modul")`) a fost lansat pe **22 ianuarie 2025**, cu alias-uri `@self` (mai 2025) si `@game` (8 ianuarie 2026); nu suporta inca alias-uri custom generale — pentru un codebase de marimea Driftwood, `require(script.Parent.Modul)` clasic ramane mai simplu si suficient. [devforum.roblox.com/t/introducing-require-by-string/3405078]
- Performanta reala vine din reguli simple, documentate oficial: preallocare cu `table.create(n)`, evitarea alocarilor in bucle "hot", `__index` care indica direct catre un tabel (nu functie), apeluri directe la functii builtin pentru fastcall. [luau.org/performance]
- Capcanele clasice (indexare de la 1, `#` nedefinit pe array-uri cu goluri, `and/or` ca ternar defectuos pe valori falsy) sunt documentate oficial in Roblox Lua Style Guide — merita un lint/checklist intern inainte de code review. [roblox.github.io/lua-style-guide/gotchas/]
- Arhitectura recomandata (Service/Controller cu ModuleScript-uri ca singleton, injectate explicit) se potriveste 1:1 cu separarea deja descrisa in CLAUDE.md (`ServerScriptService` vs `StarterPlayerScripts`).

---

## Fapte verificate

- Luau are trei moduri de type-checking pe fisier: `--!nocheck`, `--!nonstrict`, `--!strict`, setabile pe prima linie a scriptului; default-ul global e controlabil prin `Workspace.LuauTypeCheckMode`. — sursa: create.roblox.com/docs/luau/type-checking — fara data explicita pe pagina — incredere: ridicata
- New Type Solver a trecut din Studio Beta in general release pe 20 noiembrie 2025; utilizatorii in `nocheck`/`nonstrict` primesc automat noul solver, cei in `strict` raman pe solverul vechi by default si trebuie sa opteze manual. — sursa: devforum.roblox.com/t/general-release-luau's-new-type-solver/4084991 — 20 noiembrie 2025 — incredere: ridicata
- Feature flag-ul de Studio Beta pentru New Type Solver a fost programat sa fie eliminat pe 7 ianuarie 2026. — sursa: devforum.roblox.com/t/general-release-luau's-new-type-solver/4084991 — 20 noiembrie 2025 — incredere: ridicata
- `nonstrict` a devenit modul implicit pentru template-uri noi si pentru toti utilizatorii odata cu general release-ul din noiembrie 2025. — sursa: devforum.roblox.com/t/general-release-luau's-new-type-solver/4084991 — 20 noiembrie 2025 — incredere: ridicata
- Native code generation e activat implicit pe server si in Studio pentru toate experientele incepand din iulie 2024 (dupa beta anuntat 31 august 2023). — sursa: devforum.roblox.com/t/luau-recap-july-2024/3082271 si devforum.roblox.com/t/luau-native-code-generation-preview-studio-beta/2572587 — iulie 2024 / august 2023 — incredere: ridicata
- Sintaxa `@native` marcheaza o singura functie pentru compilare nativa; `--!native` (comentariu pe prima linie) marcheaza tot scriptul. — sursa: create.roblox.com/docs/luau/native-code-gen — fara data pe pagina — incredere: ridicata
- Castigul tipic de performanta din native code generation este 1.5x–2.5x pentru cod cu calcule numerice intensive. — sursa: devforum.roblox.com/t/luau-native-code-generation-preview-update/2961746 (rezumat AI din continutul paginii, nu citat exact) — incredere: medie
- Tipul `buffer` a fost lansat in beta in noiembrie 2023, activat pentru experiente live (cu replicare pe RemoteEvent) in decembrie 2023, si a primit suport pentru DataStoreService/MemoryStoreService/MessagingService/TeleportService/HttpService in februarie 2024. — sursa: devforum.roblox.com/t/introducing-luau-buffer-type-beta/2724894 — noiembrie 2023 – februarie 2024 — incredere: ridicata
- `buffer.readbits` / `buffer.writebits` au fost adaugate in cursul lui 2025. — sursa: luau.org/news/2025-12-19-luau-recap-runtime-2025 — 19 decembrie 2025 — incredere: ridicata
- Functiile complete ale libraries `buffer`: `create`, `fromstring`, `tostring`, `len`, `readi8/u8/i16/u16/i32/u32`, `readf32/f64`, `writei8/u8/i16/u16/i32/u32`, `writef32/f64`, `readstring`/`writestring`, `readbits`/`writebits`, `copy`, `fill`. — sursa: create.roblox.com/docs/reference/engine/libraries/buffer — fara data pe pagina — incredere: ridicata
- Tipul `vector` e un tip primitiv (nu userdata clasic ca Vector3), cu suport fastcall, constante si constant-folding in compilator. — sursa: rfcs.luau.org/vector-library.html si luau.org/news/2025-12-19-luau-recap-runtime-2025 — 19 decembrie 2025 — incredere: ridicata
- La ianuarie 2025 exista un bug documentat de incompatibilitate de tip intre `Vector3` si noul tip `vector`, desi reprezinta aceeasi structura de date. — sursa: devforum.roblox.com/t/vector3-type-and-luau-vector-type-are-incompatible-with-eachother-despite-being-the-same-thing/3401731 — ianuarie 2025 — incredere: medie
- `vector.lerp` avea tipul de retur gresit specificat (`number` in loc de `vector`) intr-un bug raportat in septembrie 2025. — sursa: github.com/luau-lang/luau/issues/2024 — septembrie 2025 — incredere: medie
- String interpolation (sintaxa cu backtick si `{expr}`) a fost introdusa in Luau in februarie 2023 — inainte de fereastra 2024-2026, deci posibil deja bine cunoscuta, dar stabila si recomandata azi ca alternativa mai sigura la `string.format`. — sursa: luau.org/news/2023-02-02-luau-string-interpolation — 2 februarie 2023 — incredere: ridicata (functionalitate stabila, verificata si ulterior)
- Operatorul de impartire intreaga `//` (echivalent `math.floor(a/b)`, supraincarcabil prin metametoda `__idiv`) a fost introdus in octombrie 2023 — tot inainte de fereastra tinta, dar functional si stabil azi. — sursa: rfcs.luau.org/syntax-floor-division-operator.html si devforum.roblox.com/t/luau-recap-october-2023/2685332 — octombrie 2023 — incredere: ridicata
- Require-by-string (`require("./Modul")`, `require("../Modul")`, `require("@self/Modul")`) a fost anuntat oficial pe 22 ianuarie 2025; alias `@self` a fost adaugat pe 20 mai 2025, iar `@game` pe 8 ianuarie 2026. Alias-uri custom generale nu erau inca disponibile la anuntul initial. — sursa: devforum.roblox.com/t/introducing-require-by-string/3405078 — 22 ianuarie 2025 (+ actualizari mai 2025 / ianuarie 2026) — incredere: ridicata
- Metodele `:connect()`, `:wait()`, `:disconnect()` (litere mici) pe `RBXScriptSignal` sunt deprecate in favoarea `:Connect()`, `:Wait()`, `:Disconnect()`; desi inca functioneaza in unele cazuri, sunt considerate legacy de comunitate si forum. — sursa: devforum.roblox.com/t/are-these-event-connections-actually-deprecated/2513926 si devforum.roblox.com/t/deprecated-rbxscriptsignals-still-used/232316 — data exacta a deprecarii NEVERIFICAT (community consensus plaseaza asta in jurul anului 2014) — incredere: medie
- `task` library expune `task.spawn`, `task.defer`, `task.delay`, `task.wait`, `task.cancel`, `task.desynchronize`, `task.synchronize`, ca inlocuitor recomandat pentru globalele legacy `wait()`, `spawn()`, `delay()`. — sursa: create.roblox.com/docs/reference/engine/libraries/task — fara data pe pagina — incredere: ridicata
- `table.create(n)` prealoca doar partea de tip array a unui tabel; folosirea lui pe tabele-dictionar e contraproductiva. — sursa: rfcs.luau.org/function-table-create-find.html (existenta functiei, primar) + lua-users.org/wiki/TablePreallocation (context, secundar) — incredere: medie
- Regulile oficiale de performanta Luau includ: table literal complet la creare (nu campuri adaugate ulterior), `table.create(n)` pentru array-uri de dimensiune cunoscuta, evitarea alocarilor in bucle stranse, `__index` care indica direct catre un tabel (nu functie/lant lung), apel de metoda `obj:Method()` in loc de `obj.Method(obj)`, apel direct la functii builtin pentru optimizarea "fastcall". — sursa: luau.org/performance — fara data explicita, pagina curenta — incredere: ridicata
- GC-ul Luau e incremental; noul "paged sweeper" e de 2-3x mai rapid decat sweeping-ul cu linked list clasic; functiile din biblioteca `table` sunt de 3x+ mai rapide fata de versiuni ne-optimizate; `table.sort` are ~4x speedup mediu. — sursa: luau.org/performance — fara data explicita — incredere: ridicata
- Roblox Studio ofera "Memory tool" (categorii CoreMemory/PlaceMemory/PlaceScriptMemory) si "Luau Heap tool" (snapshot-uri de heap, grupate; obiectele sub 2 KB sunt agregate intr-un singur nod in graf) pentru diagnosticarea memoriei. — sursa: create.roblox.com/docs/studio/optimization/memory-usage — fara data explicita — incredere: ridicata
- RunService expune printre altele evenimentele `Heartbeat(deltaTime)`, `Stepped(time, deltaTime)`, `PreRender`, `PreAnimation`, `PreSimulation`, `PostSimulation`, folosite pentru bucla de joc frame-by-frame. — sursa: create.roblox.com/docs/reference/engine/classes/RunService (rezumat AI din pagina, nu citat exact) — incredere: medie
- Style guide-ul oficial Roblox recomanda PascalCase pentru toate API-urile Roblox, camelCase pentru variabile locale/membri/functii, LOUD_SNAKE_CASE pentru constante locale, si prefixul `_` pentru membri privati. — sursa: roblox.github.io/lua-style-guide/ — fara data explicita — incredere: ridicata
- Pagina oficiala de "gotchas" documenteaza explicit: `and/or` ca ternar e nesigur cand valoarea din mijloc poate fi falsy; `#` pe un array cu goluri (nil in mijloc) e nedefinit/inconsistent; `return` fara valoare difera de `return nil` in interactiune cu `table.insert`; doar ultima expresie dintr-o lista de argumente/retururi isi expandeaza toate valorile multiple; doar `Instance`-urile Roblox sunt sigure ca si chei de tabel (nu in tabele slabe). — sursa: roblox.github.io/lua-style-guide/gotchas/ — fara data explicita — incredere: ridicata
- Un ModuleScript e cache-uit dupa primul `require()`; toate apelurile ulterioare din orice script primesc acelasi tabel returnat — ceea ce face din ModuleScript un singleton natural, fara cod suplimentar. — sursa: sinteza multipla din devforum (community pattern, confirmat de comportamentul documentat al `require`) — incredere: medie (comportament, nu citat direct dintr-un singur doc oficial)

---

## Detalii

### 1. Sistemul de tipuri: strict vs nonstrict vs nocheck

Spre deosebire de TypeScript (unde `strict: true` e norma), Luau porneste istoric din `nonstrict`. Din 20 noiembrie 2025, `nonstrict` e explicit default-ul oficial pentru toate scripturile noi si pentru toti utilizatorii, iar `strict` trebuie ales activ. [create.roblox.com/docs/luau/type-checking; devforum 4084991]

```lua
--!strict
-- de la 20 nov 2025: modul care ramane pe solverul VECHI by default in strict,
-- trebuie optat manual pentru New Type Solver daca vrei feature-urile noi
-- (type functions, read-only table properties)

type NetInfo = {
    id: string,
    capacity: number,
    speedMultiplier: number,
}

local function createNet(id: string, capacity: number): NetInfo
    return { id = id, capacity = capacity, speedMultiplier = 1.0 }
end
```

Trei moduri, pe prima linie a fisierului:

| Directiva | Comportament |
|---|---|
| `--!nocheck` | Type checking complet dezactivat |
| `--!nonstrict` (default post-nov-2025) | Verifica doar variabilele adnotate explicit; restul e `any` |
| `--!strict` | Infera si verifica tipuri pentru tot codul, chiar neadnotat |

Setare globala: `Workspace.LuauTypeCheckMode` (property nou, persista "cel putin un an" conform anuntului) suprascrie default-ul per proiect; fiecare script poate suprascrie local cu directiva proprie. [devforum 4084991]

**New Type Solver (general release 20 noiembrie 2025)** aduce:
- proprietati de tabel read-only (inferate sau adnotate) — mai aproape de `readonly` din TypeScript;
- **type functions** (functii care opereaza la nivel de tip, ruland la compile-time) — analog (partial) cu tipurile conditionale din TypeScript, dar sintaxa e diferita si specifica Luau;
- refinari de tip mai bune (narrowing dupa `if`/`assert`);
- reguli de cast relaxate (mai putina nevoie de `:: any`).

Roblox insusi recunoaste ca solverul nou are inca probleme de claritate a erorilor si posibile bug-uri de corectitudine in strict mode, plus consum crescut de memorie in Studio — dar clarifica explicit ca "None of these issues can affect your experience in production, the type system only runs at edit time." [devforum 4084991]

### 2. Generice si type functions

Sintaxa generica foloseste `<T>` la functii si la aliasuri de tip:

```lua
local function firstOrDefault<T>(list: { T }, default: T): T
    return list[1] or default
end

type Result<T, E> = { ok: true, value: T } | { ok: false, error: E }
```

RFC-uri relevante (nivel Luau core, nu neaparat expuse inca 1:1 in Studio): "Generic functions", "Type alias type packs", "Support for Generic Types and Packs in User-Defined Type Functions". [rfcs.luau.org] Pentru un developer venit din TypeScript: genericele Luau sunt mai putin expresive (fara variance annotations, fara conditional types la fel de puternice), dar suficiente pentru module-uri generice de tip `Pool<T>` sau `Result<T,E>`.

### 3. Atribute pentru functii: `@native`

Sistemul de atribute (`@nume` inaintea unei declaratii de functie) e definit prin RFC "Attributes (for Functions)". [rfcs.luau.org/syntax-attributes-functions.html] Singurul atribut livrat si documentat oficial azi e `@native`:

```lua
@native
local function computeAABBOverlap(ax: number, ay: number, aw: number, ah: number,
                                    bx: number, by: number, bw: number, bh: number): boolean
    return ax < bx + bw and ax + aw > bx and ay < by + bh and ay + ah > by
end
```

Alternativ, pentru tot fisierul: `--!native` pe prima linie.

Reguli oficiale de folosire [create.roblox.com/docs/luau/native-code-gen]:
- cel mai util in cod cu calcule numerice grele si putine apeluri catre biblioteci Luau/API Roblox "grele";
- adnotarile de tip (ex. parametri `Vector3`) previn de-optimizari;
- masoara cu Script Profiler *inainte* de a activa pe scara larga — nu pune `--!native` peste tot, consuma memorie suplimentara la compilare;
- functii/scripturi foarte mari (limite exacte gasite intr-o sinteza AI a paginii oficiale, **NEVERIFICAT cuvant cu cuvant**: ~64K instructiuni per functie, ~32K blocuri de cod, ~1 milion instructiuni total per script) esueaza compilarea nativa si cad silentios pe bytecode interpretat.
- `getfenv()`/`setfenv()` (deja deprecate general) blocheaza executia nativa.

Castig tipic: **1.5x–2.5x** pe cod numeric intensiv. [devforum 2961746] Disponibil implicit pe server si Studio din iulie 2024; suport Android a fost extins si testat in productie in 2025. [devforum 3082271; luau.org/news/2025-12-19-luau-recap-runtime-2025]

### 4. `buffer` — date binare compacte

```lua
local buf = buffer.create(16)          -- 16 octeti, zero-initializati
buffer.writeu32(buf, 0, 123456)         -- little-endian
buffer.writef32(buf, 4, 1.5)
local id = buffer.readu32(buf, 0)

local fromStr = buffer.fromstring("RAW_BYTES")
local backToStr = buffer.tostring(fromStr)
```

Functii complete: `create`, `fromstring`, `tostring`, `len`, `copy`, `fill`, `readi8/u8/i16/u16/i32/u32`, `readf32/f64`, `writei8/u8/i16/u16/i32/u32`, `writef32/f64`, `readstring`/`writestring`, `readbits`/`writebits` (adaugate 2025). [create.roblox.com/docs/reference/engine/libraries/buffer; luau.org/news/2025-12-19-luau-recap-runtime-2025]

Note importante din anuntul original (devforum, nov 2023 — **rezumat, nu citat literal, incredere medie**):
- offset-urile sunt 0-based (diferit de restul limbajului, care e 1-based);
- nu exista cursor intern — trebuie tinut manual (offset curent);
- `buffer` nu poate fi salvat direct in `Attribute`-uri de Instance;
- trecerea prin API-uri Roblox copiaza continutul, nu pastreaza identitatea referintei;
- compresie Zstd "transparenta" pe fir pentru buffere suficient de mari trimise prin RemoteEvent.

Pentru Driftwood la faza de MVP: **nu e nevoie de `buffer`**. Volumul de date per obiect de rau (id, pozitie, tip, stare) e mic si tabelele Luau simple + `RemoteEvent` standard sunt suficiente. `buffer` devine relevant doar daca replici zeci/sute de obiecte pe frame catre toti clientii si latimea de banda devine bottleneck masurat (nu presupus).

### 5. `vector` — tip primitiv, nu userdata

`vector` e acum un tip de date primitiv (alaturi de `number`, `string`, `boolean`), NU un userdata ca `Vector3`. `typeof(v)` returneaza `"vector"`. Suporta fastcall, constante si constant-folding in compilator, plus (2025) lowering nativ pentru `vector.dot` folosind instructiuni CPU de produs scalar. [rfcs.luau.org/vector-library.html; luau.org/news/2025-12-19-luau-recap-runtime-2025]

```lua
local pos = vector.create(10, 5, 0)
local vel = vector.create(2, 0, 0)
local next = pos + vel * dt   -- operatori aritmetici supraincarcati nativ
```

**Atentie pentru Driftwood**: fiind `ScreenGui` 2D pur, pozitiile randate sunt `UDim2` (construit din `Vector2`), NU `Vector3`/`vector`. Tipul `vector` are 3 componente (x, y, z) — util pentru *calcule interne* (viteza curentului, interpolare), dar tot trebuie convertit manual la `UDim2.fromOffset(x, y)` pentru a muta un `Frame`. Nu exista beneficiu direct de randare din `vector`/native code gen pe partea de UI — beneficiul e strict pe bucla de simulare (fizica AABB, miscarea obiectelor pe rau), nu pe API-urile `GuiObject`.

Bug cunoscut: la ianuarie 2025, `Vector3` si `vector` erau raportate ca incompatibile la nivel de tip desi identice structural [devforum 3401731]; `vector.lerp` avea tipul de retur gresit (`number` in loc de `vector`) intr-un issue deschis in septembrie 2025 [github luau-lang/luau#2024]. Verifica in Studio versiunea curenta inainte de a te baza pe interop `Vector3`/`vector`.

### 6. String interpolation si floor division (context, nu noutate 2024+)

```lua
local name = "Ana"
local score = 42
print(`Player {name} scored {score} points`)   -- backtick + {expr}

local pages = 7 // 2   -- 3, echivalent math.floor(7/2)
```

Ambele au aparut in 2023 (interpolation feb. 2023, `//` oct. 2023) [luau.org/news/2023-02-02-luau-string-interpolation; rfcs.luau.org/syntax-floor-division-operator.html] — deci tehnic in afara ferestrei 2024-2026 ceruta, dar sunt parte stabila a limbajului azi si merita mentionate ca "asteptate" pentru cineva venit din TS/Python.

### 7. Require-by-string (2025-2026)

```lua
-- Vechi (instance-based, functioneaza mereu, fara ambiguitate):
local RiverService = require(script.Parent.RiverService)

-- Nou (require-by-string, live din 22 ianuarie 2025):
local RiverService = require("./RiverService")
local Shared = require("../Shared/Constants")
local Child = require("@self/SubModule")     -- alias adaugat 20 mai 2025
-- @game pentru radacina DataModel: adaugat 8 ianuarie 2026
```

Limitari la lansare: fara path-uri absolute, fara alias-uri custom generale (doar `./`, `../`, `@self`, mai tarziu `@game`); modulele nu asteapta automat replicarea — tot trebuie `WaitForChild`/`game.Loaded:Wait()` unde e cazul. [devforum 3405078] Config de alias-uri se face prin fisier `.luaurc` (sintaxa asemanatoare JSON). [rfcs.luau.org/require-by-string-aliases.html]

Pentru un codebase de dimensiunea Driftwood (probabil sub 50-100 module la lansare), diferenta practica intre `require(script.Parent.X)` si `require("./X")` e minora — a doua e mai portabila daca vreodata rulezi module Luau in afara Studio (ex. cu Lune, pentru teste unitare offline), dar introduce o dependenta de o feature relativ noua (sub 2 ani) cu limitari inca active.

### 8. `task` library vs globale legacy

```lua
-- EVITA:
wait(1)
spawn(function() ... end)
delay(2, function() ... end)

-- FOLOSESTE:
task.wait(1)
task.spawn(function() ... end)
task.delay(2, function() ... end)
task.defer(function() ... end)   -- ruleaza la urmatorul "resumption cycle", nu imediat
task.cancel(thread)
```

`task.spawn`/`task.delay` accepta argumente suplimentare trimise direct functiei (spre deosebire de `spawn`/`delay` clasice) si se integreaza cu scheduler-ul intern al motorului pentru precizie mai buna de timing. [create.roblox.com/docs/reference/engine/libraries/task] Un avantaj practic pentru arhitectura server-autoritara din CLAUDE.md: o eroare intr-un `task.spawn` e raportata prin output/`ScriptContext.Error` fara sa blocheze thread-ul apelant — util pentru izolarea procesarii per-jucator (ex: eroare la reparatul unui obiect al unui jucator nu trebuie sa opreasca bucla de rau pentru restul serverului).

### 9. Coroutine vs task, si pcall

- `coroutine.create`/`coroutine.resume`/`coroutine.wrap` raman disponibile pentru control fin (generatoare, cooperative multitasking explicit), dar cer gestionare manuala a erorilor — `coroutine.resume` intoarce `(success, ...)`, similar unui `pcall`.
- `task.spawn(fn)` porneste un thread nou gestionat de scheduler-ul Roblox, cu raportare automata a erorilor in Output — de preferat pentru "fire and forget" (ex: procesarea catch-ului unei plase).
- `pcall(fn, ...)` ramane unealta standard pentru apeluri care pot esua sincron (validari, apeluri DataStore, conversii): `local ok, result = pcall(fn, arg1, arg2)`.
- Pattern comun in comunitate: `task.spawn` pentru paralelism "izolat de erori", `pcall`/`xpcall` in interiorul lui pentru control fin al mesajului de eroare cand ai nevoie de stack trace curat. [sinteza devforum, incredere medie]

### 10. Performanta: reguli oficiale (luau.org/performance)

| Regula | De ce |
|---|---|
| `table.create(n)` pentru array-uri de dimensiune cunoscuta | Evita realocari repetate la crestere |
| Table literal complet la creare, nu campuri adaugate ulterior | Compilatorul poate optimiza layout-ul de la inceput |
| `__index` sa indice direct catre un tabel, nu catre o functie / lant lung | Lookup O(1) in loc de apel de functie / parcurgere lant |
| `obj:Method()` in loc de `obj.Method(obj)` | Syntactic sugar optimizat, echivalent dar mai clar |
| Apel direct la functii builtin (`math.max(x,1)`) sau localizate (`local max = math.max`) | Permite optimizarea "fastcall" a compilatorului |
| Evita alocari (tabele/userdata temporare) in bucle stranse | Reduce presiunea pe GC si numarul de "GC assists" care intrerup executia |
| Upvalue-uri imutabile quand posibil | Nu necesita alocari suplimentare de closure |

Numere de referinta din benchmark-urile oficiale: paged sweeper GC 2-3x mai rapid decat linked-list; functii `table.*` 3x+ mai rapide dupa optimizari; `table.sort` ~4x speedup mediu; nucleul interpretorului compileaza la ~16 KB cod. [luau.org/performance]

### 11. Memorie si GC

GC-ul Luau e **incremental** — ruleaza in pasi mici printre instructiunile scriptului, nu ca o pauza mare ("stop the world"), ceea ce reduce vizibilitatea unor "hiccup-uri" dar poate afecta throughput-ul prin "GC assists" (script-ul e intrerupt periodic sa ajute la colectare cand rata de alocare e mare). [luau.org/performance]

Unelte de diagnostic in Studio: **Memory tool** (categorii `CoreMemory`, `PlaceMemory`, `PlaceScriptMemory`) si **Luau Heap tool** (snapshot de heap; noduri sub 2 KB sunt agregate vizual). Semnale de leak: `LuaHeap` in crestere continua, sau `InstanceCount` care nu se stabilizeaza (referinte la Instance-uri care nu sunt eliberate). [create.roblox.com/docs/studio/optimization/memory-usage]

### 12. Capcane clasice (documentate oficial in Style Guide "gotchas")

```lua
-- 1) Indexare de la 1, nu de la 0
local t = {"a", "b", "c"}
print(t[1])   -- "a"

-- 2) `#` pe array cu goluri e NEDEFINIT/inconsistent
local a = {1, 2, 3, 4, 5}
a[4] = nil
print(#a)     -- poate fi 3 SAU 5, depinde de implementare -- NU te baza pe asta

-- 3) `and/or` ca ternar e nesigur cand valoarea "true" e falsy
local d = c and a or b     -- gresit daca `a` poate fi false/nil
local d2 = if c then a else b   -- corect, Luau are `if` ca expresie

-- 4) return vs return nil in table.insert
table.insert(t, f())   -- daca f() returneaza NIMIC (nu chiar nil), e eroare de argumente

-- 5) doar ULTIMA expresie dintr-o lista de argumente isi expandeaza toate valorile
local function two() return 1, 2 end
print(two(), two())    -- 1  1  2   (primul two() e trunchiat la o singura valoare)

-- 6) doar Instance-urile Roblox sunt sigure ca si chei de tabel; evita-le in tabele slabe (`__mode`)
```
[roblox.github.io/lua-style-guide/gotchas/]

Alte capcane comune (cunoastere generala Luau/Lua, nu neaparat citate dintr-o singura pagina):
- **String building in bucle**: `s = s .. x` in bucla creeaza un string nou de fiecare data (O(n^2) total); foloseste `table.insert` intr-un buffer + `table.concat(buffer)` la final.
- **Metatables**: fiecare lookup prin `__index` (daca e functie, nu tabel) costa un apel suplimentar; pentru obiecte create des (ex: un obiect de rau per "catch"), prefera `__index = ClassTable` (tabel direct), nu `__index = function(...) end`.
- **Closures in bucle `for`**: in Luau, fiecare iteratie a unui `for` creeaza o noua variabila locala (spre deosebire de `var` in JS pre-ES6) — deci `for i = 1, 3 do task.spawn(function() print(i) end) end` printeaza corect 1, 2, 3, nu 3, 3, 3. Nu e o capcana in Luau, dar developerii veniti din alte limbaje o asteapta gresit ca fiind o problema.

### 13. Structura de module: Service/Controller + ModuleScript ca singleton

Un `ModuleScript` e cache-uit dupa primul `require()` — orice alt `require()` ulterior, din orice script, primeste **acelasi** tabel returnat. Asta face din orice ModuleScript un singleton natural, fara boilerplate.

```lua
-- ServerScriptService/Services/RiverService.lua
--!strict
local RiverService = {}
RiverService.__index = RiverService

local activeObjects: { [number]: RiverObject } = {}

function RiverService.Init(deps: { Workshop: WorkshopServiceType, Net: NetServiceType })
    -- dependency injection explicita: RiverService primeste ce-i trebuie,
    -- nu face require() catre alte servicii direct in top-level (evita
    -- probleme de ordine de incarcare / require circular)
    RiverService._workshop = deps.Workshop
    RiverService._net = deps.Net
end

function RiverService.Update(dt: number)
    for id, obj in activeObjects do
        -- ...
    end
end

return RiverService
```

```lua
-- ServerScriptService/Main.server.lua (bootstrap, ordine explicita)
local RiverService = require(script.Parent.Services.RiverService)
local WorkshopService = require(script.Parent.Services.WorkshopService)
local NetService = require(script.Parent.Services.NetService)

WorkshopService.Init({})
NetService.Init({ Workshop = WorkshopService })
RiverService.Init({ Workshop = WorkshopService, Net = NetService })
```

Pattern-ul e confirmat de comunitate (tutoriale "ServiceProvider", biblioteci ca `Karen` pentru injectie de dependinte cu ordine de initializare) [devforum 3477646; github.com/Kylaaa/Karen] — nu e un API oficial Roblox, ci o conventie stabilita. Recomandarea practica: **injectie explicita prin `.Init(deps)`**, nu `require()` incrucisat intre servicii la nivel de fisier — reduce riscul de require circular si face dependintele vizibile la un singur loc (bootstrap script).

### 14. Exemple orientate pe bucla de joc 2D

**Object pool** (reduce presiunea pe GC pentru obiecte de rau create/distruse des):

```lua
--!strict
type RiverObject = { active: boolean, x: number, y: number, kind: string }

local Pool = {}
Pool._free: { RiverObject } = table.create(64)
Pool._active: { RiverObject } = {}

function Pool.acquire(kind: string): RiverObject
    local obj = table.remove(Pool._free)
    if not obj then
        obj = { active = false, x = 0, y = 0, kind = kind }
    end
    obj.active = true
    obj.kind = kind
    table.insert(Pool._active, obj)
    return obj
end

function Pool.release(obj: RiverObject)
    obj.active = false
    local idx = table.find(Pool._active, obj)
    if idx then
        table.remove(Pool._active, idx)
    end
    table.insert(Pool._free, obj)
end
```

**Bucla cu pas fix (fixed timestep) folosind `RunService.Heartbeat`:**

```lua
--!strict
local RunService = game:GetService("RunService")

local FIXED_DT = 1 / 30   -- 30 update-uri de simulare pe secunda
local accumulator = 0.0

RunService.Heartbeat:Connect(function(deltaTime: number)
    accumulator += deltaTime
    -- plafon de siguranta: nu incerca sa recuperezi mai mult de X pasi
    -- dintr-o data dupa un frame-drop / lag spike
    local maxSteps = 5
    while accumulator >= FIXED_DT and maxSteps > 0 do
        -- Update-ul simularii cu pas CONSTANT (deterministic, independent de framerate)
        RiverService.Update(FIXED_DT)
        accumulator -= FIXED_DT
        maxSteps -= 1
    end
end)
```

**Coliziune AABB (Axis-Aligned Bounding Box) — exact ce trebuie pentru plase vs obiecte de rau:**

```lua
--!strict
export type AABB = { x: number, y: number, w: number, h: number }

local function overlaps(a: AABB, b: AABB): boolean
    return a.x < b.x + b.w
        and a.x + a.w > b.x
        and a.y < b.y + b.h
        and a.y + a.h > b.y
end

-- marcat @native daca profiling-ul arata ca e hot path
-- (ex: verificat pentru fiecare pereche plasa x obiect, in fiecare frame)
```

Cele trei exemple folosesc doar Luau standard (tabele, functii, `RunService`) — nu au nevoie de `buffer` sau `vector` pentru un MVP; pot fi migrate ulterior daca profiling-ul (Script Profiler / MicroProfiler) arata nevoie reala.

---

## Recomandari concrete pentru Driftwood

1. **Foloseste `--!strict` pe toate modulele noi din ziua 1**, explicit pe fiecare fisier (nu te baza pe default-ul global, care e acum `nonstrict` din noiembrie 2025). Motiv: developerul e obisnuit cu TypeScript strict; `strict` prinde greseli de tip la editare, inainte de a ajunge in Studio Output. Verifica insa in Studio daca solverul nou (implicit din nov. 2025) functioneaza corect cu `--!strict` in versiunea curenta — Roblox insusi recunoaste bug-uri ramase.

2. **Interzice global `wait()`, `spawn()`, `delay()`** in codebase (via convenite de echipa / code review, Roblox nu are linter automat inclus) — foloseste exclusiv `task.wait`, `task.spawn`, `task.delay`, `task.defer`. Motiv: precizie mai buna de timing, argumente suplimentare acceptate direct, raportare de erori mai buna prin scheduler-ul intern.

3. **Nu introduce `buffer` sau `vector` la faza de prototip (pasul 1-2 din CLAUDE.md).** Motiv: complexitate suplimentara fara beneficiu masurat la volumul MVP (un rau, un tip de obiect, plasa simpla). Reevalueaza cand ai zeci de obiecte simultane replicate pe frame catre toti clientii si profiling-ul arata bottleneck de banda/CPU.

4. **Cand introduci `vector` pentru calcule interne de fizica (viteza curentului, interpolare pozitie), converteste explicit la `UDim2`/`Vector2` doar la randare** — nu incerca sa faci `Frame.Position` sa accepte direct `vector`, API-ul `GuiObject.Position` cere `UDim2`. Documenteaza aceasta granita clar in cod (comentariu sau tip separat `ScreenPos` vs `SimPos`).

5. **Aplica `@native` (sau `--!native` per script) doar dupa ce Script Profiler arata un hot path real** — candidat evident: bucla de update a obiectelor de rau + verificarile AABB plasa-vs-obiect, rulate in fiecare frame pentru potential zeci-sute de perechi. Nu aplica peste tot din start (consuma memorie de compilare fara beneficiu pe cod care nu e bottleneck).

6. **Foloseste `table.create(n)` cu o capacitate estimata** pentru array-urile de obiecte de rau active si pentru pool-urile de obiecte (netele, particule vizuale) — estimeaza `n` din designul jocului (ex: maxim ~100-200 obiecte simultane pe server) mai degraba decat sa lasi tabelele sa creasca organic.

7. **Adopta pattern-ul Service (server) / Controller (client), fiecare ca ModuleScript singleton, cu injectie explicita prin `.Init(deps)` intr-un bootstrap script** — se mapeaza direct pe separarea deja decisa `ServerScriptService` vs `StarterPlayerScripts` din CLAUDE.md. Evita `require()` incrucisat direct intre servicii la nivel de fisier, pentru a preveni require circular.

8. **Nu migra la require-by-string doar de dragul noutatii.** `require(script.Parent.X)` clasic e mai simplu, fara dependinta de o feature cu <2 ani de maturitate si limitari inca active (fara alias-uri custom complete). Reevalueaza doar daca vrei sa rulezi teste unitare pe module Luau in afara Studio (ex: cu Lune).

9. **Foloseste `pcall` explicit in jurul oricarui apel `DataStoreService` (`UpdateAsync` etc.) si al oricarui handler de `RemoteEvent` primit de la client** — nu te baza pe `task.spawn` singur pentru izolare de erori in cazurile unde ai nevoie de un rezultat de succes/esec pentru retry logic (cerinta explicita din CLAUDE.md: "UpdateAsync + retry logic").

10. **Foloseste `table.concat` in loc de concatenare `..` in bucle** pentru orice constructie de string in cod care ruleaza des (ex: chei DataStore compuse, log-uri de debug in bucla de simulare) — evita alocari O(n^2).

---

## Riscuri si necunoscute

- **New Type Solver (general release nov. 2025) inca are bug-uri de corectitudine recunoscute oficial in `--!strict`.** Un modul care trece de type-check azi ar putea afisa erori diferite dupa un update de Studio in urmatoarele luni. Recomandare: nu bloca CI/code-review strict pe zero warnings de tip pana solverul se stabilizeaza — trateaza type-check-ul ca ajutor, nu ca gate absolut, cel putin in T1 2026.
- **Limitele exacte de compilare native code generation** (64K instructiuni/functie, 32K blocuri, 1M instructiuni/script) provin dintr-un rezumat AI al paginii oficiale, nu dintr-un citat literal verificat manual — **NEVERIFICAT cuvant cu cuvant**. Inainte de a proiecta arhitectura in jurul acestor limite, verifica direct pagina create.roblox.com/docs/luau/native-code-gen in Studio/browser.
- **Limita de 50 MB pentru buffere trimise prin RemoteEvent** (mentionata intr-un rezumat al postarii originale de beta din nov. 2023) nu a fost re-confirmata pe o pagina curenta 2025-2026 — posibil schimbata sau deja invechita. Marcheaza NEVERIFICAT pana la o sursa 2025+.
- **Comportamentul exact al `#` pe array-uri cu goluri** e prin design nedefinit in Lua/Luau (nu doar "inconsistent din greseala") — orice cod care se bazeaza pe el implicit e un bug latent, indiferent de ce observi empiric intr-o versiune de Studio.
- **Interopul `Vector3` <-> `vector`** a avut bug-uri raportate cel putin pana in septembrie 2025; daca Driftwood ramane 100% ScreenGui (fara `Vector3`/parts 3D), acest risc probabil nu se aplica direct, dar merita reverificat daca la un moment dat se foloseste `Vector3` pentru altceva (ex: sunet 3D, camera).
- **RunService — semnaturile exacte ale evenimentelor** (`Heartbeat`, `Stepped`, `PreRender` etc.) au fost obtinute printr-o sinteza de cautare, nu dintr-un fetch complet si citat al paginii oficiale `create.roblox.com/docs/reference/engine/classes/RunService`. Verifica in Studio (autocomplete) inainte de a scrie bucla de simulare finala.
- **Data exacta a deprecarii `:connect`/`:wait`/`:disconnect`** (litere mici) nu a putut fi confirmata cu o sursa primara datata — comunitatea plaseaza asta undeva in jurul lui 2014, dar e NEVERIFICAT. Practic nu conteaza pentru cod nou (foloseste mereu `:Connect`/`:Wait`/`:Disconnect` cu majuscula), dar merita stiut daca gasesti cod vechi copiat de pe forumuri.

---

## Intrebari deschise

1. **Trebuie setat `Workspace.LuauTypeCheckMode` global pe `strict`**, sau e suficient `--!strict` per fisier? Testeaza in Studio ambele si verifica daca proprietatea persista corect la publish/republish si la colaborare in echipa (daca la un moment dat se alatura un al doilea developer).
2. **Merita sa se scrie chiar acum module de test unitare cu Lune (runtime Luau standalone)** pentru logica pura (AABB, calcul offline-accumulation), profitand de require-by-string pentru portabilitate, sau e suficient testarea manuala in Studio pentru volumul MVP? Necesita o evaluare separata a Lune ca unealta (nu a fost cercetat in profunzime aici).
3. **La ce prag de obiecte simultane pe rau merita introdus `@native`** pe bucla de update/coliziune? Trebuie masurat cu Script Profiler dupa ce exista un prototip functional (pasul 1 din CLAUDE.md), nu decis teoretic acum.
4. **`buffer` merita vreodata pentru salvarea datelor in DataStore** (nu doar pentru replicare), avand in vedere ca `buffer.tostring()` poate produce output non-UTF8 nepotrivit pentru DataStore fara encoding suplimentar? De testat separat daca planul de persistenta creste in complexitate (ex: sute de obiecte per jucator in inventar).
5. **Cate module server (Services) si module client (Controllers) sunt anticipate la scara "sisteme de baza" din CLAUDE.md** (rau, reparat, atelier, index, sezoane, amonte, inundatie)? Merita un document separat de arhitectura care sa fixeze granitele fiecarui Service inainte de a scrie cod, ca sa se evite un singur Service monolit.

---

## Surse

- [Type checking — Documentation, Roblox Creator Hub](https://create.roblox.com/docs/luau/type-checking) — fara data explicita pe pagina, continut curent la 2026-09
- [Native code generation — Documentation, Roblox Creator Hub](https://create.roblox.com/docs/luau/native-code-gen) — fara data explicita, continut curent la 2026-09
- [task — Documentation, Roblox Creator Hub](https://create.roblox.com/docs/reference/engine/libraries/task) — fara data explicita, continut curent la 2026-09
- [buffer — Documentation, Roblox Creator Hub](https://create.roblox.com/docs/reference/engine/libraries/buffer) — fara data explicita, continut curent la 2026-09
- [RunService — Documentation, Roblox Creator Hub](https://create.roblox.com/docs/reference/engine/classes/RunService) — fara data explicita, continut curent la 2026-09
- [Memory usage — Documentation, Roblox Creator Hub](https://create.roblox.com/docs/studio/optimization/memory-usage) — fara data explicita, continut curent la 2026-09
- [[General Release] Luau's New Type Solver — Announcements, Developer Forum](https://devforum.roblox.com/t/general-release-luau's-new-type-solver/4084991) — 20 noiembrie 2025
- [Luau Native Code Generation Preview Update — Announcements, Developer Forum](https://devforum.roblox.com/t/luau-native-code-generation-preview-update/2961746) — 2023-2024 (thread activ)
- [Luau Native Code Generation Preview [Studio Beta] — Announcements, Developer Forum](https://devforum.roblox.com/t/luau-native-code-generation-preview-studio-beta/2572587) — 31 august 2023
- [Luau Recap: July 2024 — Announcements, Developer Forum](https://devforum.roblox.com/t/luau-recap-july-2024/3082271) — 23 iulie 2024
- [Introducing Luau buffer type [Beta] — Announcements, Developer Forum](https://devforum.roblox.com/t/introducing-luau-buffer-type-beta/2724894) — noiembrie 2023 (thread activ pana in 2024)
- [Introducing Require-by-String — Announcements, Developer Forum](https://devforum.roblox.com/t/introducing-require-by-string/3405078) — 22 ianuarie 2025
- [Vector library — Luau RFCs](https://rfcs.luau.org/vector-library.html) — fara data explicita
- [vector.lerp return type definition is incorrect — Issue #2024, luau-lang/luau (GitHub)](https://github.com/luau-lang/luau/issues/2024) — septembrie 2025
- [Vector3 type and Luau vector type are incompatible — Studio Bugs, Developer Forum](https://devforum.roblox.com/t/vector3-type-and-luau-vector-type-are-incompatible-with-eachother-despite-being-the-same-thing/3401731) — ianuarie 2025
- [String Interpolation — Luau news](https://luau.org/news/2023-02-02-luau-string-interpolation/) — 2 februarie 2023
- [Floor division operator — Luau RFCs](https://rfcs.luau.org/syntax-floor-division-operator.html) — fara data explicita (asociat cu octombrie 2023)
- [Luau Recap: October 2023 — Announcements, Developer Forum](https://devforum.roblox.com/t/luau-recap-october-2023/2685332) — 1 noiembrie 2023
- [Roblox Lua Style guide (oficial)](https://roblox.github.io/lua-style-guide/) — fara data explicita
- [Gotchas — Roblox Lua Style guide](https://roblox.github.io/lua-style-guide/gotchas/) — fara data explicita
- [How we make Luau fast — Performance, luau.org](https://luau.org/performance) — fara data explicita
- [Luau Recap for 2025: Runtime — luau.org news](https://luau.org/news/2025-12-19-luau-recap-runtime-2025/) — 19 decembrie 2025
- [table.create and table.find — Luau RFCs](https://rfcs.luau.org/function-table-create-find.html) — fara data explicita
- [Table Preallocation — lua-users wiki (secundar, comunitate Lua generala, nu Luau specific)](https://lua-users.org/wiki/TablePreallocation) — fara data explicita
- [Attributes (for Functions) — Luau RFCs](https://rfcs.luau.org/syntax-attributes-functions.html) — fara data explicita
- [Generic functions — Luau RFCs](https://rfcs.luau.org/generic-functions.html) — fara data explicita
- [Introduction to ServiceProvider - The Service pattern — Community Tutorials, Developer Forum (secundar)](https://devforum.roblox.com/t/introduction-to-serviceprovider-the-service-pattern/3477646) — fara data explicita
- [Karen — singleton/dependency-injection manager pentru Roblox (secundar, GitHub community)](https://github.com/Kylaaa/Karen) — fara data explicita
- [Are these event connections actually deprecated? — Scripting Support, Developer Forum (secundar)](https://devforum.roblox.com/t/are-these-event-connections-actually-deprecated/2513926) — fara data explicita
