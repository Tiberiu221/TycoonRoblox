# Sezoane, inundatia, amonte si live-ops

## Rezumat executiv

- `os.time()` pe Roblox ruleaza in **UTC by default** (nu ora locala a masinii) — asta face posibil un calcul de sezon 100% determinist, fara stare centrala: `sezonCurent = floor((os.time() - EPOCH) / (28*86400))`, evaluat identic pe orice server, la orice restart, fara sa fie nevoie de `MessagingService` sau de un DataStore central "care e sezonul acum".
- `MessagingService` este **best-effort, nu garantat** ("Delivery is best effort and not guaranteed" — citat direct din documentatie) si un server care porneste dupa ce mesajul a fost trimis nu-l primeste niciodata. Concluzie directa pentru Driftwood: nu folosi `MessagingService` ca sursa de adevar pentru "e inundatie acum?" — foloseste-l doar pentru notificari secundare (bannere, sunete), iar starea reala se calculeaza determinist din timp, la fel ca sezonul.
- Roblox a lansat in **24 august 2026** un serviciu oficial nou, **`ConfigService`** ("Experience Configs" / "Conditional Configs" / "Experiments"), exact echivalentul unui remote-config + feature-flag + A/B testing de productie: valori editabile din dashboard, publicate live in 15 secunde – 1 minut (sau rollout gradual pe 15 minute), cu segmentare pe atribute de jucator (tara, status de platitor, vechime). Asta inlocuieste orice sistem DIY de feature flags construit pe DataStore/MemoryStore — e mai simplu, mai rapid si nu consuma bugetul de request-uri al DataStore.
- `MemoryStoreService` (SortedMap / HashMap / Queue) e potrivit pentru stare runtime partajata intre servere cu TTL scurt (ex: lock distribuit "cine a procesat deja finalul inundatiei X"), NU pentru configuratie de continut — acolo e locul lui `ConfigService`.
- Game Passes sunt **permanente prin design de platforma** (Roblox le descrie explicit ca achizitie "one-time" cu beneficiu permanent) — nu poti vinde un "season pass" care expira din perspectiva proprietatii. Solutia standard: pass-ul permanent iti da flag-ul "am Season Pass", dar TRACK-ul de recompense e resetat server-side la fiecare sezon nou, citind acelasi `sezonCurent` determinist.
- Orice recompensa aleatorie platita cu Robux (direct sau indirect) intra sub politica **Paid Random Items** — obligatoriu de afisat sansele numerice exacte (suma = 100%) si de verificat `PolicyService:GetPolicyInfoForPlayerAsync().ArePaidRandomItemsRestricted`. Recomandare: tine randomizarea DOAR pe capturi gratuite din rau (exceptate explicit de politica), nu pe nimic cumparat cu Robux.
- Rollback in Roblox nu e instant: `Version History` (redesenat complet in feb-mar 2026) restaureaza o versiune veche in Studio, dar **nu publica automat** si **nu opreste serverele deja pornite** — ele ruleaza codul vechi pana cicleaza natural sau sunt oprite manual. Orice plan de rollback pentru sezon/inundatie trebuie sa includa un kill-switch (`ConfigService`) verificat la runtime, nu doar "revin la o versiune veche".
- Participarea la evenimente de platforma (The Hunt etc.) e istoric bazata pe aplicatie/selectie, dar editiile recente (The Hunt: Mega Edition, 13 martie – 4 aprilie 2025) par curate spre experiente deja mari — nu exista un canal de crestere garantat pentru un joc nou, solo-dev. Trateaza evenimentele de platforma ca fereastra de evitat (nu concura pe atentie cu ele), nu ca strategie de achizitie.
- Zona Amonte ar trebui sa foloseasca reset fix pe UTC (ex. 00:00 UTC), calculat ca `floor(os.time()/86400)` comparat cu ultima zi salvata — mult mai simplu si mai putin exploatabil decat un reset rulant de 24h per jucator, dar dezavantajeaza jucatorii din fusuri orare departate de UTC (decizie deschisa, vezi sectiunea de intrebari).

## Fapte verificate

- `os.time()` in Luau pe Roblox foloseste implicit timpul UTC ("time" — accepta un tabel optional, default UTC). — sursa: create.roblox.com/docs/reference/engine/libraries/os — verificat 2026-09-08 — confidenta: ridicata.
- `MessagingService:PublishAsync(topic, message)` si `MessagingService:SubscribeAsync(topic, callback)` — topicurile sunt string-uri de 1-80 caractere; livrarea e "best effort, not guaranteed", latenta tipica 1-2 secunde; callback-ul primeste `{Data=..., Sent=<unix time>}`. — sursa: create.roblox.com/docs/reference/engine/classes/MessagingService — verificat 2026-09-08 (fetch integral) — confidenta: ridicata.
- Limite exacte `MessagingService` (subiecte la schimbare, citate direct din pagina oficiala): vezi tabelul din sectiunea Detalii. — sursa: create.roblox.com/docs/reference/engine/classes/MessagingService — confidenta: ridicata.
- Ghidul oficial "Cross-server messaging" confirma ca nu exista garantie de livrare si nu exista mecanism de "replay" pentru un server care porneste dupa ce un mesaj a fost publicat. — sursa: create.roblox.com/docs/cloud-services/cross-server-messaging — verificat 2026-09-08 — confidenta: medie (continut extras prin sumarizare automata, dar coroborat cu pagina de referinta a clasei).
- `MemoryStoreService` ofera trei structuri (`SortedMap`, `Queue`, `HashMap`); marime: 64 KB + 1.2 KB × utilizatori concurenti, plafon 100 MB per structura, maxim 1.000.000 iteme per structura; buget de request-uri: 1000 + 120 × CCU unitati/minut; TTL implicit 45 zile, cu auto-expirare. — sursa: create.roblox.com/docs/cloud-services/memory-stores — verificat 2026-09-08 — confidenta: medie (sumarizare automata a paginii; cifrele sunt de ordinul corect pentru acest serviciu, dar merita reconfirmare vizuala directa in Studio inainte de a proiecta pe ele).
- `MemoryStoreHashMap`: `SetAsync(key, value, expiration)`, `GetAsync(key)`, `UpdateAsync(key, transformFn, expiration)`, `RemoveAsync(key)`, `ListItemsAsync(count)` — toate cer capacitatea "DataStore" si sunt yielding. — sursa: create.roblox.com/docs/reference/engine/classes/MemoryStoreHashMap — verificat 2026-09-08 — confidenta: ridicata.
- **`ConfigService`** (nou, "Experience Configs"): `ConfigService:GetConfigAsync()` (global) si `ConfigService:GetConfigForPlayerAsync(player)` (per-jucator, aplica si conditii/experimente); pe snapshot: `GetValue(key)`, `Refresh()`, `GetValueChangedSignal(key)`, `UpdateAvailable`. Doar server-side. Publicare: "aproape instant (intre 15 secunde si 1 minut)" sau rollout gradual pe 15 minute. Limite: pana la 1000 de configuri active per experienta, 100 de conditii per joc, 20 de conditii per cheie, valori string/JSON pana la 100.000 caractere. — sursa: create.roblox.com/docs/production/configs — verificat 2026-09-08 — confidenta: medie-ridicata (continut extras prin sumarizare automata a unei pagini complexe; structura API si limitele numerice sunt citate ca atare din pagina, dar recomand o citire directa in Studio inainte de implementare, feature fiind foarte nou).
- `ConfigService` a fost anuntat oficial pe 24 august 2026 ("Optimize Testing and Live Updates with Roblox's Analytics...", pe about.roblox.com/newsroom, si confirmat separat in Weekly Recap devforum din 28 august 2026). — sursa: about.roblox.com/newsroom/2026/08 (titlu confirmat prin rezultat de cautare, continutul integral nu a putut fi extras direct in aceasta sesiune) + create.roblox.com/docs/production/configs — verificat 2026-09-08 — confidenta: medie (data si titlul sunt sigure; detaliile provin din pagina de documentatie, nu din articolul de newsroom in sine).
- **Experiments** (A/B testing) foloseste acelasi `ConfigService`, dar prin `GetConfigForPlayerAsync()`; maxim 2 variante + control, durata 14-60 zile, cel mult un experiment de matchmaking activ simultan, cheia de config se blocheaza cat experimentul e activ; documentatia avertizeaza explicit ca jocurile cu sub 1000 DAU "might struggle to get useful data from experiments". — sursa: create.roblox.com/docs/production/experiments — verificat 2026-09-08 — confidenta: medie-ridicata.
- Game Passes: pret minim 1 Robux, maxim 1 miliard Robux; documentatia le descrie ca beneficiu permanent, potrivite pentru achizitii unice, spre deosebire de Developer Products (recurente); pass-urile promovate pe pagina "Buy Robux" nu pot acorda iteme aleatorii platite. — sursa: create.roblox.com/docs/production/monetization/game-passes — verificat 2026-09-08 — confidenta: medie (sumarizare automata, dar consistenta cu structura generala cunoscuta a platformei).
- Politica **Paid Random Items**: orice item aleator cumparabil (direct sau indirect) cu Robux trebuie sa afiseze toate rezultatele posibile si sansele numerice exacte, insumand 100%; pentru utilizatori restrictionati regional (`ArePaidRandomItemsRestricted = true` din `PolicyService:GetPolicyInfoForPlayerAsync()`), dezvoltatorul trebuie sa aplice unul din 5 tratamente (cale gratuita alternativa, ordine predeterminata dezvaluita, cumparare directa la valoare asteptata, ascunderea mecanicii, sau blocarea cumpararii). Randomizarea din recompense **gratuite** (ex. o cufar deschis dupa ce gasesti o cheie fara plata) e explicit exceptata de la disclosure. — sursa: create.roblox.com/docs/production/monetization/paid-random-items — verificat 2026-09-08 (fetch integral) — confidenta: ridicata.
- `PolicyService:GetPolicyInfoForPlayerAsync(player)` returneaza un dictionar cu (cel putin) `ArePaidRandomItemsRestricted`, `IsPaidItemTradingAllowed`, `IsEligibleToPurchaseCommerceProduct`. — sursa: create.roblox.com/docs/reference/engine/classes/PolicyService — verificat 2026-09-08 — confidenta: ridicata.
- `require()` accepta `ModuleScript | string | number` — al treilea caz incarca un `ModuleScript` publicat dupa asset ID, potential util pentru continut/reguli inlocuibile fara republish complet al experientei (tehnica avansata, cu compromisuri de latenta si securitate). — sursa: create.roblox.com/docs/reference/engine/globals/LuaGlobals — verificat 2026-09-08 — confidenta: medie (semnatura confirmata; comportamentul exact la runtime nu a fost detaliat in pagina).
- **Version History** (Roblox Studio): redesenat complet, anuntat 27 februarie 2026, cu update pe 6 martie 2026 (notele de publish devin optionale in versiunea finala). Acces: `Window > Version History` (dockable) sau Creator Dashboard. Restaurarea unei versiuni vechi creeaza o versiune NOUA local — **nu publica automat**; locurile publice trebuie republicate manual, iar serverele deja pornite continua pe codul vechi pana repornesc. — sursa: create.roblox.com/docs/projects/version-history + devforum.roblox.com, "Redesigned Place Version History in Studio", postat de LuckyRainGG (Roblox Staff), 27 feb 2026, actualizat 6 mar 2026 — verificat 2026-09-08 — confidenta: ridicata.
- Limite `DataStoreService` (reconfirmate independent): per experienta — citire 300+40×CCU/min, scriere 300+20×CCU/min, listare 300+2×CCU/min, stergere 300+40×CCU/min; per server — citire/scriere 60+40×numPlayers/min (standard), listare 5+2×numPlayers/min; valoare maxima per cheie 4.194.304 caractere (~4MB). — sursa: create.roblox.com/docs/cloud-services/data-stores/error-codes-and-limits — verificat 2026-09-08 — confidenta: ridicata.
- "The Hunt: Mega Edition" (eveniment oficial de platforma) a rulat 13 martie – 4 aprilie 2025 (sursa secundara wiki), cu marele premiu de **1 milion USD**, anuntat oficial de Roblox pe 8 aprilie 2025 intr-un articol de newsroom cu titlul "Millions Join The Hunt: Mega Edition, One Takes $1 Million Top Prize". — sursa: about.roblox.com/newsroom/2025/04 (titlu si data confirmate prin cautare, continutul integral nu a putut fi extras in aceasta sesiune — NEVERIFICAT pentru numarul exact de jucatori participanti) + roblox.fandom.com/wiki/The_Hunt:_Mega_Edition (secundara, wiki) — confidenta: medie.
- Model istoric de participare la evenimente de platforma tip "Egg Hunt": Roblox publica un anunt cu termen limita de aplicare (survey), orice dezvoltator cu un joc existent poate "voluntaria" jocul, castigatorii primesc un obiect de colectie brandat asignat jocului lor si trafic garantat; "nu se asteapta mult" tehnic, dar selectia nu e garantata. — sursa: devforum.roblox.com, "Games Needed for Egg Hunt 2020!" (chewbeccca, Developer Relations, ian. 2020) si "Roblox 2019 Events: Updates, Calendar & More" (nov. 2018) — **ATENTIE: surse din 2018-2020, posibil depasite fata de formatul actual (hub curat) al lui The Hunt din 2024-2025+** — confidenta: scazuta-medie pentru aplicabilitate in 2026.
- Lista (secundara, wiki) a evenimentelor recurente de platforma din 2025: The Hunt: Mega Edition, The Hatch, RIA (Roblox Innovation Awards) 2025, Inspire 2025, RDC 2025, The Takeover, Halloween Spotlight, Black Friday 2025, Creator Showdown. — sursa: roblox.fandom.com/wiki/Developer_Events ("This Week On Roblox") — confidenta: scazuta (wiki comunitar, nu confirmat oficial in aceasta sesiune, dar util ca lista de tipuri de evenimente si cadenta aproximativa).
- Discutie comunitara (nu oficiala) despre cum jocuri mari tip Grow a Garden par sa livreze continut "live" fara soft-shutdown vizibil: ipoteza dominanta a comunitatii e publicarea continutului INACTIV in prealabil (behind a flag), activat ulterior printr-un semnal (MessagingService/DataStore/MemoryStore) sau printr-un timer sincronizat pe toate serverele. — sursa: devforum.roblox.com, "How does Grow a Garden Publish Updates?" (iulie 2025) — **speculatie comunitara, secundara, neconfirmata oficial** — confidenta: scazuta pentru mecanism exact, dar pattern-ul (continut dezactivat + flag de activare) e in linie cu ce permite acum oficial `ConfigService`.

## Detalii

### 1. Calculul determinist al sezonului (fara stare centrala)

Cerinta din brief: cicluri de 4 saptamani REALE (28 zile), fara sa pedepseasca absenta. Solutia corecta e sa NU stochezi "sezonul curent" nicaieri — il calculezi mereu din timp, pe orice server, la orice moment:

```lua
-- server, modul SeasonSystem
local SEASON_LENGTH = 28 * 24 * 60 * 60 -- 28 zile in secunde
local SEASON_EPOCH = 1704067200 -- ancora aleasa de design, ex. 2024-01-01T00:00:00Z

local SEASONS = { "Vara", "Toamna", "Iarna", "Primavara" } -- ordine ciclica

local function getSeasonIndex(now: number?)
    now = now or os.time() -- os.time() e UTC pe Roblox, fara conversie
    local elapsed = now - SEASON_EPOCH
    local cycleIndex = math.floor(elapsed / SEASON_LENGTH)
    return (cycleIndex % #SEASONS) + 1, cycleIndex
end

local function getSeasonName(now: number?)
    local idx = getSeasonIndex(now)
    return SEASONS[idx]
end

-- timpul ramas pana la urmatorul sezon (pentru UI / countdown client)
local function getSecondsUntilNextSeason(now: number?)
    now = now or os.time()
    local elapsed = now - SEASON_EPOCH
    local intoCurrent = elapsed % SEASON_LENGTH
    return SEASON_LENGTH - intoCurrent
end
```

Avantaje fata de o varianta cu stare centrala (DataStore "current_season" scris de un singur server "master"):
- **niciun single point of failure** — orice server, inclusiv unul pornit la 3 dimineata dupa un restart de platforma, calculeaza acelasi sezon;
- **niciun cost de DataStore/MemoryStore** pentru citirea sezonului — e un calcul local, gratuit, apelabil oricat de des;
- **testabil determinist in Studio** — poti simula orice sezon trecand un `now` custom in functii, fara sa atingi retea.

`cycleIndex` (nu doar indexul din 1-4) merita pastrat/logat — e identificatorul unic al "instantei" curente de sezon (ex: sezonul #37), util pentru orice eveniment care trebuie sa se intample o singura data per ciclu (vezi sectiunea urmatoare, acelasi principiu se aplica Inundatiei).

**Decizie de design nerezolvata (vezi Intrebari deschise):** daca `SEASON_EPOCH` ar trebui ales sa alinieze "Iarna" din joc cu iarna calendaristica reala macar la lansare — dupa cateva cicluri de 28 de zile, alinierea cu anotimpurile reale se pierde oricum (28 zile ≠ ~91 zile ale unui anotimp real), deci probabil nu conteaza, dar merita o decizie explicita, nu implicita.

### 2. Inundatia (eveniment lunar de server) — arhitectura tehnica

Cerinta: eveniment programat, anuntat din timp, care aduce 10x mai mult loot dar "ia" orice obiect nefixat pe teren.

**Regula de aur, derivata direct din faptul ca `MessagingService` nu are livrare garantata:** starea "e inundatie acum?" trebuie sa fie un calcul determinist din timp (la fel ca sezonul), NU rezultatul unui mesaj primit. `MessagingService` poate fi folosit pentru UX (o notificare instant, un sunet de sirena la toate serverele simultan), dar niciodata ca singura sursa care decide daca inundatia e activa — altfel un server care a ratat mesajul (restart, lag, deploy) ramane blocat in starea gresita.

```lua
-- server, modul FloodSystem
local FLOOD_INTERVAL = 28 * 24 * 60 * 60      -- o data pe "luna" de joc (aliniat cu sezonul, optional)
local FLOOD_DURATION = 3 * 60 * 60             -- 3 ore
local FLOOD_WARNING_LEAD = 48 * 60 * 60        -- anunt cu 48h inainte
local FLOOD_ANCHOR = SEASON_EPOCH              -- refoloseste aceeasi ancora

local function getFloodWindowId(now: number?)
    now = now or os.time()
    return math.floor((now - FLOOD_ANCHOR) / FLOOD_INTERVAL) -- id unic per instanta de inundatie
end

local function getFloodState(now: number?)
    now = now or os.time()
    local windowId = getFloodWindowId(now)
    local windowStart = FLOOD_ANCHOR + windowId * FLOOD_INTERVAL
    local floodStart = windowStart -- momentul exact al inundatiei in fereastra
    local floodEnd = floodStart + FLOOD_DURATION

    if now >= floodStart and now < floodEnd then
        return "ACTIVE", windowId, floodEnd
    elseif now < floodStart and (floodStart - now) <= FLOOD_WARNING_LEAD then
        return "WARNING", windowId, floodStart
    else
        return "IDLE", windowId, floodStart
    end
end
```

**Kill switch obligatoriu:** inainte de a aplica orice efect al inundatiei (spawn loot x10, stergere obiecte nefixate), verifica un config boolean prin `ConfigService`:

```lua
local ConfigService = game:GetService("ConfigService")

local function isFloodEnabled()
    local ok, snapshot = pcall(function()
        return ConfigService:GetConfigAsync()
    end)
    if not ok then return true end -- fail-open sau fail-closed: decizie de design, vezi Riscuri
    local enabled = snapshot:GetValue("flood_event_enabled")
    return enabled ~= false -- default true daca nu exista cheia
end
```

Cu asta, daca logica de inundatie are un bug care distruge obiecte gresit, poti opri evenimentul global in sub un minut, din dashboard, **fara redeploy de cod**.

**Idempotenta pe procesarea "ce se sterge la finalul inundatiei":** pentru ca fiecare server proceseaza singur momentul de tranzitie, foloseste `windowId` (nu un timestamp brut) ca marca — un server care re-verifica la fiecare tick trebuie sa stearga obiectele nefixate O SINGURA DATA per `windowId`, nu la fiecare verificare cat timp `now >= floodEnd`:

```lua
local processedWindows = {} -- in-memory, per server; suficient cat timp fiecare server e independent

local function onHeartbeatCheckFlood()
    local state, windowId, edgeTime = getFloodState()
    if state == "ACTIVE" and not processedWindows["start_" .. windowId] then
        processedWindows["start_" .. windowId] = true
        -- spawn loot x10 pentru toti jucatorii de pe server
    end
    -- la finalul ferestrei (cand starea revine la IDLE dupa ce a fost ACTIVE):
    if state == "IDLE" and processedWindows["start_" .. windowId] and not processedWindows["end_" .. windowId] then
        processedWindows["end_" .. windowId] = true
        -- sterge orice obiect NEFIXAT de pe malurile jucatorilor prezenti pe acest server
    end
end
```

Daca exista un efect global CROSS-server (ex. un leaderboard "cate obiecte a pierdut orasul X luna asta", agregat peste toate serverele), acolo ai nevoie de coordonare reala — foloseste `MemoryStoreHashMap:UpdateAsync()` ca lock distribuit ("primul server care reuseste sa scrie `flood_windowId_settled = true` face agregarea"), nu `MessagingService`.

**Ce se intampla cu obiectele nefixate:** regula "ia orice nu e fixat pe teren" trebuie sa verifice un flag explicit per obiect (`isAnchored` / `isFixed`), setat cand jucatorul termina reparatia si il aseaza definitiv — nu o presupunere implicita. Server-ul sterge (sau muta inapoi in rau, pentru feedback vizual) orice obiect din zona jucatorului care nu are acest flag, la tranzitia `ACTIVE -> IDLE`.

**Corectitudine pentru absenti:** pentru ca inundatia se calculeaza determinist din timp, un jucator offline in timpul ferestrei nu a "participat" si nu a "pierdut" nimic activ (nu avea obiecte nefixate expuse in timp real fata de un server pe care nu era conectat — depinde totusi de arhitectura: daca orasul e simulat si cand jucatorul e offline, obiectele lui nefixate raman expuse riscului chiar in absenta lui). **Decizie explicita de design necesara** (vezi Intrebari deschise): fie (a) inundatia afecteaza doar obiectele expuse in momentul cand jucatorul era ultima data online inainte de fereastra, fie (b) inundatia proceseaza absolut toate terenurile indiferent de prezenta, tratand-o ca pe un risc "always-on" pe care jucatorul trebuie sa-l anticipeze prin pre-anuntul de 48h. Brief-ul ("fara sa pedepseasca pe nimeni" e principiu general de retentie, nu specific inundatiei) nu transeaza clar acest caz.

### 3. Amonte — reset zilnic: UTC fix vs. rulant per jucator

Doua arhitecturi posibile:

| Aspect | Reset fix UTC (ex. 00:00 UTC) | Reset rulant 24h per jucator |
|---|---|---|
| Stocare necesara | 1 numar per jucator: `lastResetDay = floor(lastVisit/86400)` | 1 timestamp per jucator: `lastResetAt` |
| Logica de verificare | `floor(os.time()/86400) > player.lastResetDay` | `os.time() - player.lastResetAt >= 86400` |
| Corectitudine geografica | Favorizeaza jucatorii ale caror ore de varf cad langa miezul noptii UTC (ex. Europa de Vest, coasta de est SUA) | Egal pentru toata lumea, indiferent de fus orar |
| Exploatabil? | Nu — momentul e fix, nu poate fi "farmat" prin reconectare | Potential — un jucator poate reveni cu 1 minut mai devreme fata de reset-ul lui teoretic pentru a "trage" reset-ul mai des daca logica nu e stricta pe `>=` |
| Simplitate implementare | Foarte simpla, un singur `os.time()/86400` global | Necesita stocare + verificare per jucator, mai multa suprafata de bug |
| Compatibil cu "revino maine dimineata" (motorul de retentie din brief) | Da, in mod natural pentru fusul orar dominant al playerbase-ului | Da, dar poate crea un obicei "trebuie sa ma loghez la exact ora X" care nu se aliniaza cu rutina reala |

**Recomandare:** reset FIX pe UTC, pentru simplitate si pentru ca `os.time()` fiind deja UTC nativ pe Roblox face implementarea trivial de corecta. Compromisul geografic (jucatorii din Asia/Oceania primesc reset-ul la o ora locala mai putin comoda) e o problema reala DOAR daca playerbase-ul e cunoscut a fi predominant non-vestic — de investigat empiric dupa lansare (Roblox Analytics din Creator Dashboard arata distributia geografica a jucatorilor).

```lua
local function getUpstreamDay(now: number?)
    now = now or os.time()
    return math.floor(now / 86400) -- "ziua UTC" curenta, numar intreg crescator
end

local function hasUpstreamReset(player)
    local currentDay = getUpstreamDay()
    if player.data.upstreamLastDay == nil or player.data.upstreamLastDay < currentDay then
        player.data.upstreamLastDay = currentDay
        return true -- s-a resetat acum
    end
    return false
end
```

### 4. Live-ops tooling: ce sa folosesti pentru ce

| Nevoie | Instrument recomandat | De ce |
|---|---|---|
| Feature flag / kill switch (ex. "flood_event_enabled") | `ConfigService` (boolean config) | Editabil din dashboard, live in ~15s-1min, fara redeploy, fara buget de DataStore |
| Parametri de tuning (ex. multiplicator loot inundatie, durata reparatie) | `ConfigService` (number/JSON config), eventual cu Conditional Configs pentru segmentare (ex. valoare diferita pentru jucatori noi) | Acelasi motiv; plus targetare pe atribute de jucator fara cod suplimentar |
| Testare A/B (ex. doua formulari de recompensa la Season Pass) | `ConfigService:GetConfigForPlayerAsync()` + Experiments | Nativ, cu calcul de semnificatie statistica inclus — dar necesita >1000 DAU pentru rezultate utile |
| Lock distribuit / idempotenta cross-server (ex. "cine agregha statistica lunii") | `MemoryStoreHashMap` / `SortedMap` cu `UpdateAsync` | TTL scurt, throughput mare, nu consuma bugetul DataStore |
| Stare persistenta per jucator (progres sezon, ultima reparatie) | `DataStoreService` cu `UpdateAsync`, salvare periodica | Persistenta reala, durabila; nu e pentru citiri/scrieri frecvente in bucla de joc |
| Notificare instant multi-server (ex. banner "Inundatia a inceput!") | `MessagingService` | Potrivit EXACT pentru asta — UX, nu logica de stare |

### 5. Rollback si "ce se intampla cand publici o schimbare gresita"

Fluxul Roblox nu are un echivalent direct de "git revert + deploy" instant:

1. Publici o schimbare (locul e live imediat pentru jucatorii care se conecteaza dupa publish; serverele deja pornite continua sa ruleze codul VECHI pana cicleaza — nu exista hot-reload de cod pentru scripturi obisnuite).
2. Daca descoperi o problema, deschizi `Version History` (Window > Version History in Studio, sau din Creator Dashboard), gasesti versiunea anterioara buna, o restaurezi — asta creeaza o versiune NOUA locala, dar **nu o publica automat**.
3. Trebuie sa publici manual versiunea restaurata.
4. Serverele deja pornite cu codul defect continua sa ruleze pana ies din joc jucatorii sau pana le opresti manual (soft-shutdown / kick programat).

Pentru Driftwood, asta inseamna ca planul de rollback trebuie sa aiba DOUA componente, nu una:
- **Cod:** disciplina de publish-notes (obligatorii la publish in noul Version History) ca sa poti gasi rapid ultima versiune stabila.
- **Comportament runtime:** orice logica noua riscanta (in special legata de sezon/inundatie, care ruleaza pe TOATE serverele simultan) trebuie sa fie protejata de un `ConfigService` kill-switch verificat la fiecare evaluare — asta e rollback-ul REAL "instant", nu Version History.

### 6. Sablon calendar live-ops pe 6 luni

Sablon concret, pornind de la `SEASON_EPOCH` ales la lansare (ziua 0 = ziua de lansare). Fiecare "Luna de joc" = un ciclu de 28 zile (sezon), NU o luna calendaristica — dupa 6 cicluri (168 zile / 24 saptamani), s-a dezaliniat deja ~2 saptamani fata de 6 luni calendaristice reale (182-184 zile); tabelul de mai jos foloseste zile relative la lansare (Ziua 0), nu date calendaristice, tocmai din acest motiv.

| Ciclu (sezon) | Zile relative | Sezon | Inundatie (fereastra) | Alte actiuni live-ops |
|---|---|---|---|---|
| 1 | 0-27 | Vara | Ziua ~14 (mijlocul ciclului) | Soft-launch; `ConfigService` cu toate flag-urile noi setate safe-default; fara Season Pass inca (colecteaza date de retentie organica) |
| 2 | 28-55 | Toamna | Ziua ~42 | Lansare Season Pass #1 (track nou, Game Pass permanent); prim test A/B via Experiments pe pretul unui Developer Product |
| 3 | 56-83 | Iarna | Ziua ~70 | Verifica daca Inundatia #2 a avut nevoie de kill-switch; ajusteaza multiplicator loot via `ConfigService` daca telemetria arata dezechilibru |
| 4 | 84-111 | Primavara | Ziua ~98 | Season Pass #2; revizuire index reparatii (adauga obiecte noi in pool-ul sezonier) |
| 5 | 112-139 | Vara | Ziua ~126 | Evaluare: merita aplicat la un eveniment de platforma (daca trafic organic suficient)? Vezi Intrebari deschise #6 |
| 6 | 140-167 | Toamna | Ziua ~154 | Season Pass #3; retrospectiva pe 6 luni: rata de retentie per sezon, rata de participare la Inundatie (activi vs. absenti), decizie go/no-go pe extinderea Amonte |

Note pentru sablon:
- Pozitia exacta a Inundatiei in fiecare ciclu (aici plasata la mijlocul celor 28 de zile) e arbitrara — poate fi mutata sa cada constant intr-o zi a saptamanii favorabila (weekend), calculata din `(SEASON_EPOCH + windowId*FLOOD_INTERVAL)` ajustat cu un offset fix ales sa cada sambata, verificabil cu `os.date("!*t", floodStart).wday`.
- Fiecare Season Pass nou trebuie publicat cu cel putin 48-72h inainte de inceputul ciclului (pre-anunt), folosind acelasi principiu de countdown determinist ca la Inundatie.
- "Alte actiuni live-ops" din coloana finala sunt sloturi pentru experimente `ConfigService`/`Experiments`, nu continut nou obligatoriu in fiecare ciclu — suprapunerea a prea multe schimbari simultan face imposibila atribuirea cauzala a variatiilor de retentie.

## Recomandari concrete pentru Driftwood

1. **Nu stoca "sezonul curent" nicaieri.** Calculeaza-l mereu din `os.time()` si o ancora fixa (`SEASON_EPOCH`), pe fiecare server, la fiecare citire. Elimina o clasa intreaga de bug-uri de sincronizare (nu poate exista "server desincronizat", pentru ca nu exista stare de sincronizat).
2. **Foloseste acelasi principiu pentru Inundatie**, cu un `windowId` determinist derivat din timp — `MessagingService` doar pentru UX (sunet, banner), niciodata ca sursa de adevar pentru "e activa acum".
3. **Adopta `ConfigService` (lansat oficial 24 aug. 2026) ca sistem principal de feature-flags si tuning**, in locul unui sistem DIY pe DataStore/MemoryStore. E gratuit in bugetul de request-uri obisnuit, editabil din dashboard fara cod, cu rollout gradual pe 15 minute — util pentru a testa parametrii Inundatiei (multiplicator loot, durata) pe un procent mic de servere inainte de rollout complet.
4. **Implementeaza kill-switch explicit pentru Inundatie** (`flood_event_enabled` boolean in `ConfigService`), verificat inainte de orice efect distructiv (stergerea obiectelor nefixate). E singurul mecanism de "oprire de urgenta" cu adevarat instant disponibil pe platforma.
5. **Season Pass ca Game Pass permanent + track resetabil server-side.** Vinde pass-ul o singura data (permanent, conform designului de platforma pentru Game Passes); verifica detinerea cu `MarketplaceService:UserOwnsGamePassAsync()`; progresul/recompensele din track se stocheaza per-sezon (`cycleIndex` din sectiunea 1) si se reseteaza logic la fiecare sezon nou, fara sa afecteze proprietatea pass-ului.
6. **Nu pune randomizare platita cu Robux in bucla de recompense a Inundatiei sau Season Pass-ului**, ca sa eviti complet obligatia de disclosure a sanselor (Paid Random Items policy). Daca vrei un element de suspans/varietate, foloseste randomizare pe capturi GRATUITE din rau (exceptata de politica) sau recompense garantate/predeterminate pentru orice e cumparat cu bani reali.
7. **Reset Amonte pe UTC fix**, nu rulant per jucator — mai simplu de implementat corect, imun la exploatare prin reconectare cronometrata. Reevalueaza dupa lansare daca distributia geografica reala a playerbase-ului justifica un reset regionalizat.
8. **Trateaza evenimentele de platforma (The Hunt etc.) ca fereastra de evitat pentru propriul lansament/eveniment, nu ca strategie de crestere.** Nu bugeta timp de dezvoltare pe "aplicam la The Hunt" fara o baza de jucatori existenta — istoricul sugereaza favorizarea experientelor mari; verifica din nou cand Driftwood are trafic real, prin devforum.roblox.com categoria Announcements.
9. **Foloseste `windowId` (nu timestamp brut) pentru orice procesare "o singura data per eveniment"** — atat la Sezon cat si la Inundatie — ca sa eviti dubla procesare la restart de server sau la lag intre tick-uri.
10. **Documenteaza in `Version History` fiecare publish legat de sezon/inundatie cu note explicite** ("Flood tuning v3 — reduced loot multiplier 10x->6x") ca sa poti gasi rapid punctul de restaurare — dar nu te baza pe restaurare ca mecanism de reactie rapida; foloseste kill-switch-ul din `ConfigService` pentru asta.

## Riscuri si necunoscute

- `ConfigService` e o functionalitate lansata cu doar cateva saptamani inainte de data curenta a cercetarii (24 aug. 2026 vs. 8 sept. 2026) — comportamentul in productie, eventualele limitari nedocumentate inca, si stabilitatea API-ului nu au istoric lung. Testeaza-l intens in Studio inainte sa il faci dependinta critica pentru kill-switch-ul Inundatiei.
- Nu s-a putut confirma daca `ConfigService:GetConfigAsync()` are un comportament de tip "fail-open" sau "fail-closed" cand reteaua pica dupa prima incarcare — documentatia mentioneaza ca "returneaza ultimele valori disponibile si incearca reconectarea", dar nu specifica raspunsul EXACT pentru primul apel esuat. Pentru un kill-switch de siguranta, decizia dintre fail-open (inundatia continua daca ConfigService e indisponibil) si fail-closed (se opreste) trebuie testata explicit in Studio, nu presupusa.
- Regulile exacte de eligibilitate/aplicare pentru evenimente de platforma tip The Hunt in 2025-2026 NU au putut fi confirmate direct dintr-un anunt oficial recent in aceasta sesiune (sursele gasite sunt fie vechi 2018-2020, fie articole secundare fara detalii de proces). NEVERIFICAT.
- Numarul exact de jucatori/experiente participante la The Hunt: Mega Edition 2025 nu a putut fi extras (articolul de newsroom nu a fost citit integral in aceasta sesiune). NEVERIFICAT.
- Limitele numerice pentru `MemoryStoreService` si `ConfigService` au fost obtinute prin sumarizare automata a paginilor (nu citire caracter-cu-caracter) — recomand o verificare vizuala directa in Creator Hub inainte de a proiecta limite de capacitate stricte pe ele.
- Comportamentul exact al `require(assetId)` pentru "hot-swap" de continut fara republish NU a fost confirmat in detaliu (doar semnatura functiei) — e o tehnica avansata, mentionata ca optiune, nu ca recomandare ferma.

## Intrebari deschise

1. `SEASON_EPOCH` trebuie ales sa alinieze un sezon anume (ex. Iarna) cu iarna calendaristica reala la data lansarii, sau e complet arbitrar? Alegerea afecteaza doar prima impresie la lansare, nu mecanica pe termen lung (cele 28 de zile oricum se dezaliniaza de anotimpurile reale in timp).
2. Ce se intampla cu obiectele nefixate ale unui jucator OFFLINE in timpul ferestrei de Inundatie — sunt expuse riscului la fel ca ale unui jucator activ, sau sunt protejate implicit de faptul ca jucatorul nu era conectat? Brief-ul nu specifica, iar decizia are impact direct pe perceptia de corectitudine.
3. Reset Amonte: UTC fix confirmat ca decizie, sau merita testat un reset "per regiune" (ex. 3 fusuri orare de reset) dupa ce exista date reale de playerbase?
4. Kill-switch `ConfigService`: fail-open sau fail-closed la eroare de retea? Trebuie decis explicit si testat in Studio (simulare offline) inainte de lansare.
5. Season Pass: track-ul de recompense se pierde complet la trecerea intre sezoane, sau exista un "grace period" de cateva zile in care jucatorii mai pot revendica recompensele sezonului anterior? Nu exista o norma de platforma pentru asta — e alegere de design.
6. Merita bugetat timp pentru a aplica formal la un eveniment de platforma (The Hunt sau echivalent) dupa ce Driftwood are trafic organic, sau resursele sunt mai bine investite in propriile evenimente (Inundatia)? De revizuit cand exista date de trafic reale.
7. Pentru statistici cross-server (daca sunt dorite, ex. "orasul X a pierdut Y obiecte luna asta la nivel de platforma"), e nevoie de arhitectura MemoryStore-lock descrisa in Detalii — merita complexitatea aditionala, sau ramane doar per-server (coerent cu principiul brief-ului ca "tot serverul imparte acelasi oras")?

## Surse

- create.roblox.com/docs/reference/engine/classes/MessagingService — "MessagingService | Documentation" — verificat 2026-09-08
- create.roblox.com/docs/cloud-services/cross-server-messaging — "Cross-server messaging | Documentation" — verificat 2026-09-08
- create.roblox.com/docs/cloud-services/memory-stores — "Memory stores | Documentation" — verificat 2026-09-08
- create.roblox.com/docs/reference/engine/classes/MemoryStoreHashMap — "MemoryStoreHashMap | Documentation" — verificat 2026-09-08
- create.roblox.com/docs/reference/engine/classes/MemoryStoreService — "MemoryStoreService | Documentation" — verificat 2026-09-08
- create.roblox.com/docs/production/configs — "Experience configs | Documentation" — verificat 2026-09-08
- create.roblox.com/docs/production/experiments — "Experiments | Documentation" — verificat 2026-09-08
- about.roblox.com/newsroom/2026/08 — "Optimize Testing and Live Updates with Roblox's Analytics..." — publicat 24 august 2026, verificat prin cautare 2026-09-08
- create.roblox.com/docs/production/monetization/game-passes — "Game passes | Documentation" — verificat 2026-09-08
- create.roblox.com/docs/production/monetization/paid-random-items — "Paid random items policy guidelines | Documentation" — verificat 2026-09-08
- create.roblox.com/docs/reference/engine/classes/PolicyService — "PolicyService | Documentation" — verificat 2026-09-08
- create.roblox.com/docs/reference/engine/globals/LuaGlobals — "Lua Globals | Documentation" — verificat 2026-09-08
- create.roblox.com/docs/reference/engine/libraries/os — "os | Documentation" — verificat 2026-09-08
- create.roblox.com/docs/cloud-services/data-stores/error-codes-and-limits — "Data store errors and limits | Documentation" — verificat 2026-09-08
- create.roblox.com/docs/projects/version-history — "Version History | Documentation" — verificat 2026-09-08
- devforum.roblox.com — "Redesigned Place Version History in Studio" (LuckyRainGG, Roblox Staff) — postat 27 februarie 2026, actualizat 6 martie 2026, verificat 2026-09-08
- about.roblox.com/newsroom/2025/04 — "Millions Join The Hunt: Mega Edition, One Takes $1 Million Top Prize" — publicat 8 aprilie 2025, verificat prin cautare 2026-09-08
- roblox.fandom.com/wiki/The_Hunt:_Mega_Edition — sursa secundara (wiki) — verificat prin cautare 2026-09-08
- roblox.fandom.com/wiki/Developer_Events ("This Week On Roblox") — sursa secundara (wiki) — verificat prin cautare 2026-09-08
- devforum.roblox.com — "Games Needed for Egg Hunt 2020!" (chewbeccca, Developer Relations) — postat ianuarie 2020, posibil depasit — verificat 2026-09-08
- devforum.roblox.com — "Roblox 2019 Events: Updates, Calendar & More" — postat noiembrie 2018, posibil depasit — verificat prin cautare 2026-09-08
- devforum.roblox.com — "How does Grow a Garden Publish Updates?" — postat iulie 2025, discutie comunitara/secundara — verificat 2026-09-08
