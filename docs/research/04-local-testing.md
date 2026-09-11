# Testare Luau in afara Studio si in CI

## Rezumat executiv

- **TestEZ (Roblox/testez) e mort**: repo-ul oficial a fost **archived pe 14 septembrie 2024**. Nu se mai actualizeaza. Orice tutorial care il foloseste ca recomandare "curenta" e depasit.
- **Jest-Lua (jsdotlua/jest-lua)**, succesorul de facto, ruleaza **doar in Roblox** — nu in Lune, nu standalone. Are un issue deschis din iunie 2025 exact pe tema asta, nerezolvat.
- Pentru testare **rapida, locala, fara Studio**, singura combinatie realista in 2026 e **Lune** (runtime standalone Luau, scris in Rust) + un framework mic nativ-Luau precum **frktest** (facut special pentru ca nu exista alternative pentru Lune) sau assert-uri scrise de mana.
- **`luau` (binarul standalone de la luau-lang)** nu e un runtime de testare — e interpretorul/compilatorul de referinta, fara `task`, fara `fs`, fara `net`, fara globale Roblox (`game`, `workspace`, `Instance`). Util doar pentru sanity-check de sintaxa/tipuri, nu pentru teste.
- **Lune ofera un modul `roblox`** care poate crea `Instance`-uri reale (inclusiv `DataModel`, ceea ce Roblox insusi nu permite) si citi/scrie `.rbxl`/`.rbxm` — util pentru teste de integrare offline, dar API-ul e **mai limitat** decat motorul real.
- Pentru teste care chiar au nevoie de motorul Roblox (replicare, `DataStoreService`, fizica reala), exista **Open Cloud Luau Execution API** (beta din 25 sept 2024): ruleaza scripturi headless intr-un place, cu limite stricte — **5 minute/task, 10 task-uri concurente per place, 5 apeluri/minut per API key la creare**. Nu e gratuit nelimitat ca throughput, dar nu am gasit niciun cost in Robux/USD documentat.
- **`run-in-roblox`** (tool-ul clasic pentru CI) inca exista, dar **necesita Roblox Studio instalat efectiv pe masina** (deci un runner Windows/macOS auto-gazduit, nu `ubuntu-latest`) si un cookie `.ROBLOSECURITY` ca secret — risc de securitate si cost operational, nu recomand pentru Driftwood la stadiul actual.
- **Recomandare centrala**: separa logica de joc in module Luau "pure" (fara `game`, `workspace`, `os.time()` direct) care primesc timpul si dependintele ca parametri — acestea se testeaza instant cu `lune run`, fara Studio, fara Roblox Cloud, fara cost.
- Selene (linter) si StyLua (formatter) sunt active: Selene **0.31.0** (20 mai 2026), StyLua **2.5.2** (16 mai 2026) — ambele rulate normal in CI pe `ubuntu-latest`, fara Studio.

---

## Fapte verificate

- TestEZ (`Roblox/testez`) a fost **archived pe 14 septembrie 2024** si e read-only de atunci. — sursa: https://github.com/Roblox/testez — verificat 2026-09-08 — încredere: ridicata
- Jest-Lua (`jsdotlua/jest-lua`) "can currently only run inside of Roblox" si documentatia cere explicit ajutor pentru portare pe Lune/Luvit. — sursa: https://github.com/jsdotlua/jest-lua — verificat 2026-09-08 — încredere: ridicata
- Issue-ul `jsdotlua/jest-lua#21` ("lune: require(script.Parent.) fails because script is nil") e deschis din **14 iunie 2025** si confirma ca portarea pe Lune nu functioneaza inca. — sursa: https://github.com/jsdotlua/jest-lua/issues/21 — verificat 2026-09-08 — încredere: ridicata
- Lune, ultima versiune **0.10.5**, lansata **2 iulie 2026**; adauga `QueryDescendants`, `registerClass`/`registerService` pentru modulul `roblox`, actualizeaza la Luau 0.709 si rbx-dom 0.728. — sursa: https://github.com/lune-org/lune/blob/main/CHANGELOG.md — verificat 2026-09-08 — încredere: ridicata
- Formula Homebrew `lune` instaleaza aceeasi versiune **0.10.5**. — sursa: https://formulae.brew.sh/formula/lune — verificat 2026-09-08 — încredere: ridicata
- Formula Homebrew `luau` (interpretorul standalone, nu Lune) instaleaza versiunea **0.737** si binarele `luau`, `luau-analyze`, `luau-ast`, `luau-compile`, `luau-reduce`. — sursa: https://formulae.brew.sh/formula/luau — verificat 2026-09-08 — încredere: ridicata
- Documentatia oficiala Luau spune ca binarul `luau` "ruleaza codul" iar `luau-analyze` face "static analysis (including type checking and linting)"; nu mentioneaza globale Roblox. — sursa: https://luau.org/getting-started/ — verificat 2026-09-08 — încredere: medie (pagina nu enumera explicit lipsa `game`/`workspace`, dedus din natura standalone a proiectului)
- Open Cloud Luau Execution API a fost anuntat ca **[Beta] pe 25 septembrie 2024**; la lansare limitele erau "up to 30 seconds" per task si "only two tasks can run at a time per place". — sursa: https://devforum.roblox.com/t/beta-open-cloud-engine-api-for-executing-luau/3172185 — verificat 2026-09-08 — încredere: ridicata
- Documentatia curenta a Luau Execution listeaza limitele actualizate: task-uri de pana la **5 minute**, **10 task-uri concurente per place**, script de pana la **4 MB**, output serializat JSON de pana la **4 MB**, output binar de pana la **256 MiB**, log-uri de pana la **450 KB**, retentie info task **24 ore**. — sursa: https://create.roblox.com/docs/en-us/cloud/reference/features/luau-execution.md — verificat 2026-09-08 — încredere: ridicata
- Rate limits documentate pentru API: creare task **5 apeluri/minut per API key owner** si **45 apeluri/minut per adresa IP**; citire task **200/minut**; listare log-uri **45/minut**. — sursa: https://create.roblox.com/docs/en-us/cloud/reference/features/luau-execution.md — verificat 2026-09-08 — încredere: ridicata
- Scope-ul de autentificare necesar e `universe.place.luau-execution-session:write` (creare) / `:read` (citire), header `x-api-key`, sau OAuth2. — sursa: https://create.roblox.com/docs/en-us/cloud/reference/features/luau-execution.md — verificat 2026-09-08 — încredere: ridicata
- Niciun pret in Robux/USD nu apare in documentatia oficiala sau in anuntul de pe DevForum pentru Luau Execution API. — sursa: https://create.roblox.com/docs/en-us/cloud/reference/features/luau-execution.md si https://devforum.roblox.com/t/beta-open-cloud-engine-api-for-executing-luau/3172185 — verificat 2026-09-08 — încredere: medie (absenta unei mentiuni nu e o confirmare ferma de "gratuit"; marchez explicit NEVERIFICAT mai jos)
- Repo-ul oficial `Roblox/place-ci-cd-demo` foloseste un concurrency-group in GitHub Actions ca sa evite request-uri paralele catre Luau Execution API, mentionand explicit limita (istorica) de "two concurrent request per universe". — sursa: https://github.com/Roblox/place-ci-cd-demo — verificat 2026-09-08 — încredere: medie (README-ul citat pare sa reflecte limita veche de 2, nu cea curenta de 10 — posibil neactualizat)
- `run-in-roblox` (rojo-rbx) necesita Roblox Studio instalat pe masina care ruleaza testele; exemplul oficial de CI (`Sleitnick/rbx-ci-test`) confirma: "Roblox Studio is needed in order to run the TestEZ unit tests," instalat printr-un action care cere un secret `ROBLOSECURITY`. — sursa: https://github.com/Sleitnick/rbx-ci-test — verificat 2026-09-08 — încredere: medie (sursa e un exemplu comunitar, nu documentatie oficiala)
- `frktest` (itsfrank) e descris explicit ca "A basic test framework for standalone Luau", creat "cand nu existau alternative pentru Lune"; versiune curenta **0.0.2**, licenta MIT, instalabil prin Wally sau Pesde. — sursa: https://github.com/itsfrank/frktest — verificat 2026-09-08 — încredere: medie (proiect mic, o singura persoana, versiune 0.0.x)
- Modulul `roblox` din Lune poate crea instante direct, inclusiv `DataModel` ("even creating a new DataModel which is not normally possible in Roblox"), prin `local Instance = roblox.Instance; Instance.new("Part")`. — sursa: https://lune.gitbook.io/lune/roblox/examples — verificat 2026-09-08 — încredere: ridicata
- API-ul `roblox.readPlaceFile`/`roblox.writePlaceFile` e in curs de inlocuire cu `fs.readFile` + `roblox.deserializePlace` / `roblox.serializePlace`, "APIs are more loosely coupled". — sursa: https://lune-org.github.io/docs/roblox/3-remodel-migration/ — verificat 2026-09-08 — încredere: medie (documentatia de referinta API nu mai listeaza explicit `readPlaceFile`, semn ca s-ar putea sa fie deja deprecat/eliminat in 0.10.5)
- Selene, linter Luau: **v0.31.0**, lansat **2026-05-20**, adauga suport pentru `EnumItem.EnumType`, `EnumItem:IsA()`. — sursa: https://github.com/Kampfkarren/selene/releases — verificat 2026-09-08 — încredere: ridicata
- StyLua, formatter Luau: **v2.5.2**, lansat **16 mai 2026**. — sursa: https://github.com/JohnnyMorganz/StyLua/releases — verificat 2026-09-08 — încredere: ridicata
- Rokit (rojo-rbx), manager de toolchain community-maintained, inlocuieste Foreman/Aftman; instalabil in CI prin action-uri terte precum `paradoxum-games/setup-rokit`. — sursa: https://github.com/rojo-rbx/rokit — verificat 2026-09-08 — încredere: medie (Rokit nu e produs oficial Roblox, e community-first, per README)

---

## Detalii

### 1. `luau` (binarul standalone) vs. Lune — nu sunt acelasi lucru

`luau` este interpretorul/compilatorul de referinta al limbajului, dezvoltat de echipa Luau (fostul Roblox Luau team, acum organizatia `luau-lang`). Se instaleaza pe macOS cu:

```sh
brew install luau
```

Formula instaleaza cinci binare: `luau`, `luau-analyze`, `luau-ast`, `luau-compile`, `luau-reduce` (sursa: formulae.brew.sh/formula/luau, verificat 2026-09-08). Rulezi un fisier cu:

```sh
luau script.luau
```

**Limitare critica pentru Driftwood**: `luau` standalone are `string`, `table`, `math`, `os`, `coroutine`, `bit32` din biblioteca standard, dar **NU** are:
- `task` (schedulerul asincron — `task.wait`, `task.spawn`, `task.delay`)
- `game`, `workspace`, `Instance.new`, orice serviciu Roblox
- `fs`, `net` (I/O de fisiere si retea)

Practic, `luau` e util doar pentru: verificare rapida de sintaxa, `luau-analyze` pentru type-checking static (util in CI ca pas de lint separat de Selene), sau scripturi jucarie fara I/O. **Nu e un runtime de test viabil** pentru Driftwood — treci direct la Lune.

### 2. Lune — runtime-ul standalone potrivit

Lune (`lune-org/lune`) e un runtime Luau standalone scris in Rust, comparat de mentinatori cu Node/Deno/Bun pentru JS. Ultima versiune: **0.10.5** (2 iulie 2026), instalabila cu:

```sh
brew install lune
```

sau prin Rokit (`rokit add lune-org/lune`).

Biblioteci built-in relevante:
- **`fs`** — citire/scriere fisiere
- **`net`** — HTTP/TCP/WebSocket (util pentru testele de integrare cu Open Cloud, vezi sectiunea 5)
- **`task`** — port 1-la-1 al schedulerului Roblox (`task.wait`, `task.spawn`, `task.delay`, `task.cancel`) — deci codul de gameplay care foloseste `task.*` poate rula neschimbat sub Lune
- **`process`** — spawn de procese, argumente CLI, variabile de mediu (util in scripturi de CI)
- **`stdio`** — input/output, culori in terminal
- **`roblox`** (optional, activat implicit in binarul standard) — manipuleaza fisiere `.rbxl`/`.rbxm` si instante

Rulare:

```sh
lune run cale/catre/script.luau
```

### 3. Modulul `roblox` din Lune — cat de aproape e de Roblox real

Modulul se importa cu `local roblox = require("@lune/roblox")`. Poate:
- Crea instante reale prin `roblox.Instance.new(className)`, inclusiv **`DataModel`** — ceva ce nu poti face nici macar in Roblox Studio insusi (sursa: lune.gitbook.io/lune/roblox/examples).
- Citi/scrie place-uri si modele: API-ul vechi `roblox.readPlaceFile(path)` / `roblox.writePlaceFile(path, game)` e in tranzitie catre perechea `fs.readFile` + `roblox.deserializePlace(bytes)` / `roblox.serializePlace(datamodel)` + `fs.writeFile` (sursa: lune-org.github.io/docs/roblox/3-remodel-migration).
- Citi baza de reflectie (`roblox.getReflectionDatabase()`) pentru informatii despre clase/proprietati/enum-uri.
- Implementa proprietati/metode custom pe clase (`roblox.implementProperty`, `roblox.implementMethod`) — util daca vrei sa mock-uiesti comportament pe care rbx-dom (biblioteca Rust din spate) nu il stie inca.

**Important — API "mai limitat"**: documentatia insasi spune ca instantele Lune se comporta "as if you were scripting inside of the Roblox engine, albeit with a more limited API" (sursa: lune-org.github.io/docs/roblox/1-introduction). Nu exista replicare client-server, nu exista `DataStoreService` functional, nu exista fizica 3D reala, `RemoteEvent:FireClient` nu face nimic util fara un client real. **Deci modulul `roblox` e bun pentru manipulat `.rbxl`/`.rbxm` in build/CI (ex: injectare de date, validare de structura), nu pentru simulat gameplay-ul.**

### 4. Framework-uri de test — care sunt vii in 2026

| Framework | Status | Ruleaza in Lune? | Ruleaza in Roblox? | Ultima activitate cunoscuta |
|---|---|---|---|---|
| **TestEZ** (`Roblox/testez`) | **Archived** | Nu (nativ) | Da | Archived 2024-09-14 |
| **TestEZ (fork LastTalon)** | Fork comunitar, activitate neclara | Nedocumentat explicit | Da (mostenit) | Nu am putut verifica o data de release recenta |
| **testez-luau** (`lrockreal/testez-luau`) | "Roblox-independent fork" | Neconfirmat direct (pretinde independenta de Roblox) | Da | NEVERIFICAT — nu am gasit date de release |
| **Jest-Lua** (`jsdotlua/jest-lua`) | Activ, folosit intern de Roblox | **Nu** — issue deschis din 2025-06-14 | Da, "battle-tested" | Activ (470+ commits) |
| **frktest** (`itsfrank/frktest`) | Activ, mic, proiect de o persoana | **Da — nativ pentru asta** | Nu vizat | v0.0.2, MIT |
| Lune Web Test Runner (comunitar) | Foarte tanar (dashboard web) | Da | N/A | Postat 2025-12-07, adoptie necunoscuta |

Concluzie practica: **pentru Driftwood, in 2026, nu exista un framework de test matur si activ nativ-Lune echivalent cu Jest sau TestEZ**. Optiunile reale sunt (a) `frktest` — mic dar face treaba, sau (b) assert-uri scrise de mana cu `assert()` + un mic reporter propriu (10-20 linii de Luau), ambele rulate cu `lune run`.

### 5. Structurarea codului: module "pure" fara globale Roblox

Regula: orice modul care contine **logica de business** (calcul acumulare offline, coliziuni AABB, formule de reparatie, costuri economie) nu trebuie sa citeasca direct `os.time()`, `game`, `workspace`, `DateTime.now()`, `tick()`. In schimb, primeste aceste valori ca parametri sau prin injectie de dependinta. Asta permite rularea identica sub `lune run` (fara Roblox) si sub Roblox real, cu acelasi cod.

```lua
-- src/Shared/Modules/OfflineAccrual.luau
--!strict

local OfflineAccrual = {}

export type AccrualConfig = {
	ratePerSecond: number, -- unitati de resursa per secunda
	capSeconds: number,    -- plafonul de acumulare, ex. 8 * 3600
}

-- "now" e injectat, nu citit din os.time() sau DateTime.now() direct.
-- Asta face functia 100% determinista si testabila fara Roblox si fara Lune.
function OfflineAccrual.calculate(lastSeenUnix: number, now: number, config: AccrualConfig): number
	local elapsed = math.max(0, now - lastSeenUnix)
	local cappedElapsed = math.min(elapsed, config.capSeconds)
	return cappedElapsed * config.ratePerSecond
end

return OfflineAccrual
```

In codul de productie (server real), apelul arata asa:

```lua
-- ServerScriptService/Systems/RiverNetSystem.server.luau
local OfflineAccrual = require(ReplicatedStorage.Shared.Modules.OfflineAccrual)

local gained = OfflineAccrual.calculate(
	playerData.lastSeenUnix,
	os.time(), -- singurul loc unde apare os.time() in tot fluxul
	{ ratePerSecond = 0.5, capSeconds = 8 * 3600 }
)
```

`os.time()` exista si in Lune, si in `luau` standalone, si in Roblox — deci chiar daca l-ai lasat neinjectat undeva, codul tot ruleaza peste tot. Motivul real pentru injectie e **determinismul testelor**: vrei sa testezi "ce se intampla dupa exact 8 ore si 1 secunda offline" fara sa astepti 8 ore sau sa manipulezi ceasul sistemului.

Acelasi principiu se aplica pentru `task.wait` (injecteaza un scheduler mock in teste care au nevoie de timp simulat) si pentru orice `Instance` — daca logica are nevoie doar de pozitie/dimensiune, foloseste tabele Luau simple (`{x, y, width, height}`), nu referinte catre `Frame`/`GuiObject`. Asta elimina complet nevoia de mock-uri de Instance pentru cea mai testata logica (coliziuni, economie).

### 6. Exemplu Driftwood: coliziune AABB plasa/obiect

```lua
-- src/Shared/Modules/AABB.luau
--!strict

local AABB = {}

export type Box = {
	x: number,
	y: number,
	width: number,
	height: number,
}

-- Coliziune AABB standard. Marginile care doar se ating NU se considera
-- coliziune (folosim < / > stricte), ca sa evitam prinderi false la limita.
function AABB.intersects(a: Box, b: Box): boolean
	return a.x < b.x + b.width
		and a.x + a.width > b.x
		and a.y < b.y + b.height
		and a.y + a.height > b.y
end

return AABB
```

### 7. Teste cu `frktest`, rulate prin `lune run`

Instalare (Wally):

```toml
# wally.toml
[dev-dependencies]
frktest = "itsfrank/frktest@0.0.2"
```

```lua
-- tests/OfflineAccrual.test.luau
local frktest = require("@frktest/frktest")
local test = frktest.test
local check = frktest.assert.check

local OfflineAccrual = require("../src/Shared/Modules/OfflineAccrual")

return function()
	test.suite("OfflineAccrual.calculate", function()
		test.case("acumuleaza normal sub plafon", function()
			local config = { ratePerSecond = 1, capSeconds = 8 * 3600 }
			local result = OfflineAccrual.calculate(1000, 1000 + 3600, config)
			check.equal(result, 3600)
		end)

		test.case("respecta plafonul de 8 ore", function()
			local config = { ratePerSecond = 2, capSeconds = 8 * 3600 }
			-- jucatorul a lipsit 100 de ore, dar plafonul e 8
			local result = OfflineAccrual.calculate(0, 100 * 3600, config)
			check.equal(result, 8 * 3600 * 2)
		end)

		test.case("nu produce valori negative daca ceasul merge inapoi", function()
			local config = { ratePerSecond = 1, capSeconds = 100 }
			local result = OfflineAccrual.calculate(5000, 4000, config)
			check.equal(result, 0)
		end)
	end)
end
```

```lua
-- tests/AABB.test.luau
local frktest = require("@frktest/frktest")
local test = frktest.test
local check = frktest.assert.check

local AABB = require("../src/Shared/Modules/AABB")

return function()
	test.suite("AABB.intersects", function()
		test.case("plasa prinde obiectul cand cutiile se suprapun", function()
			local net = { x = 100, y = 50, width = 40, height = 20 }
			local debris = { x = 120, y = 55, width = 10, height = 10 }
			check.equal(AABB.intersects(net, debris), true)
		end)

		test.case("nu prinde daca obiectul e complet la dreapta plasei", function()
			local net = { x = 100, y = 50, width = 40, height = 20 }
			local debris = { x = 200, y = 55, width = 10, height = 10 }
			check.equal(AABB.intersects(net, debris), false)
		end)

		test.case("marginile care se ating exact nu se considera coliziune", function()
			local net = { x = 0, y = 0, width = 10, height = 10 }
			local debris = { x = 10, y = 0, width = 10, height = 10 }
			check.equal(AABB.intersects(net, debris), false)
		end)
	end)
end
```

Punct de intrare pentru rulare (structura recomandata de `frktest`):

```lua
-- tests/_run.luau
require("./OfflineAccrual.test")()
require("./AABB.test")()

local console_reporter = require("@frktest/reporters/console_reporter")
console_reporter.init()

local frktest = require("@frktest/frktest")
frktest.run()
```

```sh
lune run tests/_run.luau
```

**Nota despre API-ul exact de `frktest`**: doar `check.equal` e confirmat direct din sursele consultate. README-ul insusi spune ca restul asertiunilor "should be self-explanatory" si recomanda autocomplete-ul din LSP (`assert.check.|`) — deci **verifica in Studio/editor lista completa de functii `check.*` inainte sa te bazezi pe nume precum `is_true`/`is_false`/`not_equal`**; nu le-am putut confirma din sursa si nu le folosesc in exemplele de mai sus (NEVERIFICAT).

### 8. Open Cloud Luau Execution API — pentru teste de integrare reale

Cand testul chiar are nevoie de motorul Roblox (de exemplu: verifici ca `UpdateAsync` din `DataStoreService` salveaza corect intr-un place de test, sau ca un `RemoteEvent` valideaza corect pe server), singura cale headless e Open Cloud Luau Execution API.

**Endpoint-uri** (baza: `https://apis.roblox.com`, toate sub `/cloud/v2/`):

| Actiune | Metoda + path | Rate limit |
|---|---|---|
| Creeaza binary input (payload > text) | `POST /universes/{universe_id}/luau-execution-session-task-binary-inputs` | 5/min per API key |
| Creeaza task (place curent) | `POST /universes/{universe_id}/places/{place_id}/luau-execution-session-tasks` | 5/min per API key, 45/min per IP |
| Creeaza task (versiune specifica) | `POST /universes/{universe_id}/places/{place_id}/versions/{version_id}/luau-execution-session-tasks` | 5/min per API key, 45/min per IP |
| Citeste status task | `GET /universes/{universe_id}/places/{place_id}/versions/{version_id}/luau-execution-sessions/{session_id}/tasks/{task_id}` | 200/min |
| Listeaza log-uri task | `.../tasks/{task_id}/logs` | 45/min |

**Limite de executie**: script max **4 MB**, timp de rulare max **5 minute** (`timeout`), pana la **10 task-uri concurente per place**, raspuns JSON serializat max **4 MB**, output binar max **256 MiB**, log-uri retinute max **450 KB**, informatia despre task expira dupa **24 de ore** (sursa: create.roblox.com/docs/en-us/cloud/reference/features/luau-execution.md).

**Autentificare**: header `x-api-key` cu un API key Open Cloud care are scope `universe.place.luau-execution-session:write` (creare) sau `:read` (citire), sau OAuth2 (`https://apis.roblox.com/oauth/v1/authorize` / `/token`).

**Status task** (enum, din schema): `STATE_UNSPECIFIED`, `QUEUED`, `PROCESSING`, `CANCELLED`, `COMPLETE`, `FAILED`.

**Cost**: nu am gasit niciun pret in Robux sau USD in documentatia Open Cloud sau in anuntul original — marchez explicit **NEVERIFICAT** daca exista vreo taxare la volum mare; la volumul mic pe care l-ar genera CI-ul Driftwood (cateva zeci de rulari/zi), probabil ramane in limitele gratuite documentate, dar nu e confirmat oficial ca "gratuit garantat".

**Viabilitate ca integration test runner**: da, dar cu compromisuri serioase pentru un solo/mic studio:
1. Necesita un **place de test separat** (nu productia), cu universe/place ID propriu.
2. Concurenta redusa (istoric 2, acum 10 per place) inseamna ca **nu poti paraleliza masiv** — `Roblox/place-ci-cd-demo` foloseste explicit un `concurrency:` group in GitHub Actions ca sa serializeze job-urile.
3. 5 apeluri/minut la creare task e o limita reala daca ai o suita mare de teste de integrare — trebuie batch-uite in scripturi mai putine, mai mari, nu un task per test.
4. Nu inlocuieste testele unitare rapide — e potrivit pentru **cateva teste de fum (smoke tests)** rulate la publish, nu pentru bucla de dezvoltare zi cu zi.

### 9. `run-in-roblox` — inca exista, dar cu cost operational mare

`rojo-rbx/run-in-roblox` (ultima versiune referentiata: **v0.3.0**) porneste efectiv Roblox Studio ca proces, incarca un place/model/script si pipe-uieste output-ul (`print`/`warn`) inapoi in stdout, ca sa poata fi citit de un test runner extern (de obicei TestEZ). Exemplul comunitar `Sleitnick/rbx-ci-test` confirma explicit: **"Roblox Studio is needed in order to run the TestEZ unit tests."**

Implicatii practice:
- Nu ruleaza pe `ubuntu-latest` (runner-ul GitHub-hosted implicit, gratuit) — Studio exista doar pe Windows/macOS, deci ai nevoie de `windows-latest`/`macos-latest` (GitHub-hosted, mai scump la minut) sau un **runner auto-gazduit (self-hosted)**.
- Necesita un secret `.ROBLOSECURITY` (cookie-ul de autentificare al unui cont Roblox) pentru ca Studio sa se logheze — **e efectiv o parola de cont in secretele CI**, un risc de securitate real daca repo-ul sau organizatia sunt compromise.
- Combinat cu faptul ca TestEZ (framework-ul cu care e demonstrat aproape peste tot) e archived, `run-in-roblox` devine o solutie din ce in ce mai izolata tehnologic.

### 10. Exemplu de GitHub Actions: lint + teste unitare + (optional) integrare cloud

```yaml
# .github/workflows/ci.yaml
name: CI

on:
  pull_request:
  push:
    branches: [main]

jobs:
  lint-and-unit-tests:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      # Instaleaza toolchain-ul (lune, selene, stylua) din rokit.toml
      # Actiune terta comunitara, nu oficiala Roblox — verifica versiunea
      # inainte de a o pinni in productie.
      - name: Install Rokit toolchain
        uses: paradoxum-games/setup-rokit@v1

      - name: Lint (Selene)
        run: selene src

      - name: Format check (StyLua)
        run: stylua --check src

      - name: Unit tests (Lune + frktest)
        run: lune run tests/_run.luau

  cloud-integration-tests:
    needs: lint-and-unit-tests
    if: github.ref == 'refs/heads/main'
    runs-on: ubuntu-latest
    # Serializare obligatorie: Open Cloud Luau Execution permite
    # doar 10 task-uri concurente per place si 5 creari/minut per API key.
    concurrency:
      group: roblox-luau-execution
      cancel-in-progress: false
    steps:
      - uses: actions/checkout@v4
      - name: Run smoke tests via Open Cloud
        env:
          ROBLOX_API_KEY: ${{ secrets.ROBLOX_API_KEY }}
          ROBLOX_TEST_UNIVERSE_ID: ${{ vars.ROBLOX_TEST_UNIVERSE_ID }}
          ROBLOX_TEST_PLACE_ID: ${{ vars.ROBLOX_TEST_PLACE_ID }}
        run: python scripts/run_cloud_smoke_tests.py
```

Modelul de mai sus (job separat pentru cloud, cu `concurrency:` group si declansare doar pe `main`) reflecta direct patternul din `Roblox/place-ci-cd-demo` (sursa oficiala).

---

## Recomandari concrete pentru Driftwood

1. **Structureaza de la inceput logica de economie (acumulare offline, cost reparatii, formule de sezon) in module pure sub `src/Shared/Modules/`**, fara `game`/`workspace`/`os.time()` direct in interior. Motiv: e singura investitie care face testele posibile fara Studio, fara cloud, fara cost — si e ieftina daca o faci din prototip, scumpa daca o refactorizezi dupa.
2. **Instaleaza `lune` prin Homebrew (`brew install lune`, v0.10.5) si scrie testele de unitate cu `frktest` (v0.0.2, Wally)**, rulate cu `lune run tests/_run.luau`. Nu investi in TestEZ (archived) sau Jest-Lua (nu ruleaza in Lune inca).
3. **Nu folosi `run-in-roblox`** pentru Driftwood in stadiul curent (proiect nou, solo/echipa mica) — costul unui runner Windows self-hosted plus riscul unui cookie `.ROBLOSECURITY` in secrete nu se justifica atata timp cat logica critica poate fi testata pur.
4. **Adauga Selene (v0.31.0) si StyLua (v2.5.2) ca pasi de CI pe `ubuntu-latest`**, inaintea testelor unitare — sunt rapide, ieftine, nu au nevoie de Studio si prind erori de sintaxa/stil inainte de orice testare de logica.
5. **Foloseste modulul `roblox` din Lune doar pentru manipulare de fisiere `.rbxl`/`.rbxm` in build/CI** (ex: injectat date de configurare in place-ul de build), nu ca inlocuitor pentru teste de gameplay — API-ul e explicit "mai limitat" decat motorul real.
6. **Rezerva Open Cloud Luau Execution API pentru un numar mic de "smoke tests" de integrare** (ex: "se salveaza corect un `UpdateAsync` in place-ul de test dupa un ciclu complet de reparatie"), rulate doar la push pe `main`, intr-un job separat cu `concurrency:` group — nu incerca sa ruleze acolo toata suita de teste, din cauza limitei de 5 creari/minut si 10 task-uri concurente per place.
7. **Creeaza un al doilea Place (universe/place separat) dedicat testelor de integrare**, distinct de productie, inainte de a folosi Luau Execution API — altfel risti sa rulezi scripturi de test pe date reale.
8. **Foloseste tabele Luau simple (`{x, y, width, height}`) pentru coliziuni si logica de pozitionare, nu referinte `Frame`/`GuiObject`**, exact ca in exemplul `AABB.luau` de mai sus — elimina nevoia de mock-uri de Instance pentru cea mai testata parte a jocului (plase/obiecte pe rau).
9. **Pinneste versiunile de toolchain in `rokit.toml`** (lune, selene, stylua) de la inceput, ca sa eviti derapaje intre ce ruleaza local si ce ruleaza in CI — Rokit e community-maintained, nu oficial Roblox, deci schimbarile de comportament sunt posibile intre versiuni majore.
10. **Verifica manual in Studio, o singura data, comportamentul real al `check.*` din `frktest`** (autocomplete LSP) inainte sa scrii suita completa de teste — doar `check.equal` a putut fi confirmat din sursele publice consultate.

---

## Riscuri si necunoscute

- **`frktest` e un proiect de o singura persoana, versiune 0.0.2** — risc de abandon sau breaking changes fara avertisment. Nu exista o "a doua optiune" matura pentru testare nativ-Lune in acest moment (2026-09).
- **Costul real (daca exista) al Open Cloud Luau Execution API la volum** nu e documentat public — NEVERIFICAT. Trebuie testat direct cu un API key de test inainte de a te baza pe el in CI de productie.
- **API-ul `roblox.readPlaceFile`/`writePlaceFile` pare in tranzitie/deprecare** catre `deserializePlace`/`serializePlace` — cod scris azi dupa tutoriale vechi se poate rupe la un upgrade de Lune. Verifica CHANGELOG.md la fiecare `brew upgrade lune`.
- **Limita de concurenta a Luau Execution API a crescut de la 2 la 10 intre 2024 si 2026**, dar exemplul oficial `place-ci-cd-demo` inca mentioneaza limita veche de 2 in text — posibil documentatie neactualizata a exemplului; **verifica limita curenta direct din raspunsul API (header-ele de rate-limit), nu doar din README-uri**.
- **Nu am putut confirma statusul exact de mentenanta al `LastTalon/testez` sau `lrockreal/testez-luau`** (fork-uri comunitare ale TestEZ) — nu recomand sa te bazezi pe ele fara sa verifici direct data ultimului commit in Studio/browser inainte de decizie.
- **`run-in-roblox` nu pare oficial deprecat** (nu am gasit un anunt de deprecare), dar activitatea de dezvoltare pare redusa; combinat cu TestEZ archived, ecosistemul din jurul lui se subtiaza.

---

## Intrebari deschise

1. Merita sa investesti timp acum in integrare cu Open Cloud Luau Execution API, sau ramai doar cu teste pure + Lune pana cand Driftwood are un sistem (ex: DataStore/UpdateAsync) suficient de complex incat testele pure nu mai sunt suficiente? (decizie de prioritizare, nu tehnica)
2. Cate din cele 7 sisteme de baza din CLAUDE.md (rau/plase, reparat, atelier, index, sezoane, amonte, inundatie) pot fi complet exprimate ca module pure testabile, versus cate au nevoie inevitabil de `Instance`/replicare reala? Necesita audit modul-cu-modul pe masura ce se scrie codul.
3. Testeaza manual in Studio: cat de mult din `frktest.assert.check` e disponibil (autocomplete LSP) — lista completa de asertiuni nu a putut fi confirmata din surse publice.
4. Testeaza direct cu un API key real: exista vreun cost sau plafon de volum ascuns pentru Luau Execution API dincolo de rate limits — nu apare in documentatia publica.
5. Daca echipa creste, merita reconsiderat `run-in-roblox` + un runner self-hosted dedicat (fara cookie de cont personal, cu un cont de serviciu) pentru teste care chiar au nevoie de Studio complet?

---

## Surse

- [lune-org/lune](https://github.com/lune-org/lune) — GitHub repo, README, verificat 2026-09-08
- [lune-org/lune CHANGELOG.md](https://github.com/lune-org/lune/blob/main/CHANGELOG.md) — istoric versiuni, verificat 2026-09-08
- [lune-org/lune/releases](https://github.com/lune-org/lune/releases) — verificat 2026-09-08
- [Homebrew: lune](https://formulae.brew.sh/formula/lune) — verificat 2026-09-08 (v0.10.5)
- [Homebrew: luau](https://formulae.brew.sh/formula/luau) — verificat 2026-09-08 (v0.737)
- [luau.org — Getting Started](https://luau.org/getting-started/) — verificat 2026-09-08
- [Lune docs — The Roblox Library (introducere)](https://lune-org.github.io/docs/roblox/1-introduction/) — verificat 2026-09-08
- [Lune docs — Roblox API reference](https://lune-org.github.io/docs/api-reference/roblox/) — verificat 2026-09-08
- [Lune — Roblox examples (GitBook)](https://lune.gitbook.io/lune/roblox/examples) — verificat 2026-09-08
- [Lune docs — Migrating from Remodel](https://lune-org.github.io/docs/roblox/3-remodel-migration/) — verificat 2026-09-08
- [Lune docs — Task library](https://lune-org.github.io/docs/api-reference/task/) — verificat 2026-09-08
- [create.roblox.com — Luau Execution reference (.md)](https://create.roblox.com/docs/en-us/cloud/reference/features/luau-execution.md) — verificat 2026-09-08
- [create.roblox.com — Luau Execution overview (.md)](https://create.roblox.com/docs/en-us/cloud/features/luau-execution.md) — verificat 2026-09-08
- [DevForum — [Beta] Open Cloud Engine API for Executing Luau](https://devforum.roblox.com/t/beta-open-cloud-engine-api-for-executing-luau/3172185) — postat 2024-09-25, verificat 2026-09-08
- [Roblox/place-ci-cd-demo](https://github.com/Roblox/place-ci-cd-demo) — exemplu oficial CI/CD, verificat 2026-09-08
- [Roblox/open-cloud-execution-binary-payloads-example](https://github.com/Roblox/open-cloud-execution-binary-payloads-example) — verificat 2026-09-08
- [Roblox/testez](https://github.com/Roblox/testez) — archived 2024-09-14, verificat 2026-09-08
- [LastTalon/testez](https://github.com/LastTalon/testez) — fork comunitar, verificat 2026-09-08 (secundar, status neclar)
- [lrockreal/testez-luau](https://github.com/lrockreal/testez-luau) — fork comunitar, verificat 2026-09-08 (secundar, status neclar)
- [jsdotlua/jest-lua](https://github.com/jsdotlua/jest-lua) — verificat 2026-09-08
- [jsdotlua/jest-lua issue #21](https://github.com/jsdotlua/jest-lua/issues/21) — deschis 2025-06-14, verificat 2026-09-08
- [Roblox/jest-roblox](https://github.com/Roblox/jest-roblox) — verificat 2026-09-08
- [itsfrank/frktest](https://github.com/itsfrank/frktest) — v0.0.2, verificat 2026-09-08
- [DevForum — [Lune] Offline Unit-Testing framework with a web interface](https://devforum.roblox.com/t/lune-offline-unit-testing-framework-with-a-web-interface/4127221) — postat 2025-12-07, secundar/comunitar, verificat 2026-09-08
- [rojo-rbx/run-in-roblox](https://github.com/rojo-rbx/run-in-roblox) — v0.3.0, verificat 2026-09-08
- [Sleitnick/rbx-ci-test](https://github.com/Sleitnick/rbx-ci-test) — exemplu comunitar CI cu run-in-roblox + TestEZ + Selene, secundar, verificat 2026-09-08
- [Kampfkarren/selene releases](https://github.com/Kampfkarren/selene/releases) — v0.31.0, 2026-05-20, verificat 2026-09-08
- [JohnnyMorganz/StyLua releases](https://github.com/JohnnyMorganz/StyLua/releases) — v2.5.2, 2026-05-16, verificat 2026-09-08
- [rojo-rbx/rokit](https://github.com/rojo-rbx/rokit) — manager de toolchain, verificat 2026-09-08
- [paradoxum-games/setup-rokit](https://github.com/paradoxum-games/setup-rokit) — GitHub Action tert, secundar, verificat 2026-09-08
