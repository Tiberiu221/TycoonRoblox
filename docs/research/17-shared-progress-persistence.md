# Persistența progresului comun (atelierul orașului)

## Rezumat executiv

- Cea mai importantă decizie de arhitectură, luată **înainte** de orice cod: dacă "orașul" din CLAUDE.md e **o singură stare partajată de tot universul jocului** (toate serverele, permanent) sau **o stare per-instanță-de-server** (resetabilă la fiecare restart de server). Problema "hot key" descrisă în brief există DOAR în primul caz. Vezi secțiunea "Interpretarea arhitecturală critică".
- `DataStoreService` are, pe lângă bugetele de request-uri (care scalează cu numărul de jucători), o limită **per-cheie** de throughput: **4 MB/minut la scriere, 25 MB/minut la citire**, indiferent câte servere scriu pe acea cheie — asta e bottleneck-ul real la o cheie globală unică. (Sursă: create.roblox.com/docs/cloud-services/data-stores/error-codes-and-limits, accesat 2026-09-08)
- Scrierile pe **aceeași cheie** sunt serializate intern de Roblox printr-o coadă — istoric coada avea un pas fix de 7 secunde; azi execută cererile "cât mai repede posibil după ce se termină cererea anterioară", dar tot serializat, o cerere după alta. Cu multe servere concurente pe o singură cheie, coada crește. (Sursă: devforum.roblox.com — thread ProfileStore, loleris, 2024-10-11)
- **`MemoryStoreService` nu e un cache opțional, e obligatoriu** pentru orice stare cross-server citită/scrisă frecvent: acces rapid din toate serverele active, dar cu expirare obligatorie (max **45 de zile** conform documentației curente) — nu e stocare permanentă, doar buffer.
- **`ProfileStore`** (biblioteca standard de facto pentru date de jucător pe Roblox în 2025-2026) spune explicit: *"ProfileStore is not designed (and never will be) for in-game leaderboards or any kind of global state."* Deci orice document partajat al orașului trebuie construit manual peste `DataStoreService` + `MemoryStoreService`, nu peste ProfileStore.
- Pentru clasamentul contribuitorilor, `OrderedDataStore` e corect, iar `IncrementAsync` pe o **cheie per-jucător** (nu una globală) evită complet problema cheii fierbinți pentru acea parte a sistemului.
- Nu există în documentația oficială un pattern numit "leader election" — dar comunitatea a construit exact acest lucru peste `MemoryStoreService` (module `MasterServerService`, `Canopus`), pentru că problema e reală și recurentă la scară.
- `MessagingService` are limite generoase de la actualizarea din 2024, dar rămâne un canal de **notificare**, nu de adevăr — documentația nu garantează livrare 100%, deci trebuie tratat ca best-effort peste starea persistentă, nu ca sursă unică.
- Nu am putut verifica cu surse primare arhitectura internă a unor exemple mari (Adopt Me, Bee Swarm Simulator, The Hunt) — marcat explicit NEVERIFICAT mai jos, nu am inventat detalii.

## Fapte verificate

- `GetAsync()`/`SetAsync()`/`UpdateAsync()` la nivel de **experiență** (universul jocului): 300 + concurrentUsers × 40 (read), 300 + concurrentUsers × 20 (write) request-uri/minut; la nivel de **server**: 60 + numPlayers × 40 (read/write). Sursă: create.roblox.com/docs/cloud-services/data-stores/error-codes-and-limits, accesat 2026-09-08. Încredere: ridicata.
- Limită de **throughput per cheie**: citire 25 MB/minut, scriere 4 MB/minut, indiferent de numărul de servere care accesează acea cheie. Sursă: idem. Încredere: ridicata.
- Valoare maximă per cheie: **4.194.304 bytes (4 MB)**. Nume cheie/scope/datastore: max **50 caractere**. Sursă: idem. Încredere: ridicata.
- Metadata per cheie: nume max 50 caractere, valoare max 250 caractere, total perechi 300 caractere. Sursă: idem. Încredere: ridicata.
- `GetAsync()` poate întoarce date **desincronizate temporar** ("out of sync with the backend") din cauza cache-ului intern. Sursă: create.roblox.com/docs/cloud-services/data-stores, accesat 2026-09-08. Încredere: ridicata.
- `SetAsync()` "can cause data inconsistency if two servers try to set the same key at the same time"; `UpdateAsync()` citește ultima valoare scrisă înainte de a aplica transformarea, iar dacă funcția de transformare întoarce `nil`, scrierea e anulată. Sursă: idem. Încredere: ridicata.
- Scrierile pe aceeași cheie DataStore sunt procesate printr-o coadă internă serializată; istoric avea pas fix de **7 secunde**, înlocuit cu o coadă ce execută "as soon as all previous calls finish" (tot serial, dar fără pauza fixă). Sursă: devforum.roblox.com/t/profilestore-save-your-player-data-easy-datastore-module/3190543, loleris, 2024-10-11. Încredere: ridicata (citat direct din changelog-ul oficial al modulului).
- `MemoryStoreService`: "high throughput and low latency data service... accessible from all servers in a live session", pentru date "frequent and ephemeral... that change rapidly". Sursă: create.roblox.com/docs/cloud-services/memory-stores, accesat 2026-09-08. Încredere: ridicata.
- Expirare maximă în `MemoryStoreService`: **45 de zile** (documentația curentă, secțiunea best-practices). Sursă: create.roblox.com/docs/cloud-services/data-stores/best-practices, accesat 2026-09-08. Încredere: ridicata.
- Limită de mărime per item în MemoryStore: **32 KB** (crescută de la 1 KB pe 14 ianuarie 2022). Sursă: devforum.roblox.com/t/introducing-memorystore-high-throughput-low-latency-data-service/1475935 (anunț oficial Roblox, staff unix_system/therealbiker, 2021-09-20, cu update ulterior). Încredere: medie (valoarea de 32 KB vine dintr-un edit al thread-ului din 2022, nu am găsit-o reconfirmată explicit cu cifra exactă pe pagina curentă de doc).
- MemoryStore anunțat inițial (2021) ca **strongly consistent** prin mecanism de locking la citire, nu eventual-consistent. Sursă: devforum.roblox.com/t/introducing-memorystore-high-throughput-low-latency-data-service/1475935, reply staff unix_system, 2021-09-20. Încredere: medie — nu am găsit reconfirmare explicită pe pagina curentă de documentație (2026); tratează ca punct de verificat în Studio, nu ca certitudine.
- Limite `MessagingService` (actualizate 12 februarie 2024): mesaje trimise per server **600 + 240×jucători/minut**; mesaje primite per topic **40 + 80×servere/minut**; mesaje primite per joc (toate topicele) **400 + 200×servere/minut**; subscripții permise per server **20 + 8×jucători**; cereri de subscribe **240/minut**; mărime maximă mesaj **1 KB** (neschimbată). Sursă: devforum.roblox.com/t/enhanced-messagingservice-limits/2835576, staff jjwu_play, 2024-02-12. Încredere: ridicata.
- `DataStoreService:GetRequestBudgetForRequestType(requestType: Enum.DataStoreRequestType): number` există ca API pentru a verifica bugetul rămas înainte de a face o cerere. Sursă: create.roblox.com/docs/reference/engine/classes/DataStoreService, accesat 2026-09-08. Încredere: ridicata.
- `ProfileStore` (autor loleris/MAD STUDIO, lansat 11 octombrie 2024) e descris de comunitate ca "the industry gold standard" pentru date de jucător, dar autorul declară explicit că **nu** e făcut pentru leaderboard-uri sau stare globală. `ProfileService` (predecesorul) e marcat oficial "STABLE, BUT NO LONGER SUPPORTED". Surse: devforum.roblox.com/t/profilestore-save-your-player-data-easy-datastore-module/3190543 (2024-10-11); devforum.roblox.com/t/save-your-player-data-with-profileservice-datastore-module/667805 (2020-07-11, notă de descontinuare); devforum.roblox.com/t/what-datastore-system-is-the-best-nowadays/4658415 (2026-05-29). Încredere: ridicata.
- Coduri de eroare DataStore relevante pentru clasamente: **106** — `MaxValue`/`MinValue` trebuie să fie întregi; `PageSize` trebuie să fie într-un interval predefinit (nespecificat exact în doc). Sursă: create.roblox.com/docs/cloud-services/data-stores/error-codes-and-limits, accesat 2026-09-08. Încredere: ridicata pentru existența regulii, NEVERIFICAT pentru intervalul exact al `PageSize` și pentru limitele numerice min/max ale valorilor din `OrderedDataStore`.
- Nu există în documentația oficială un serviciu sau API numit "leader election" — pattern-ul e construit de comunitate peste `MemoryStoreService` (module: `MasterServerService` de SimonScripts, 2025-08-20; `Canopus`, un distributed lock manager, de St0nae, 2026-06-23). Surse: devforum.roblox.com/t/masterserverservice-v1-0-0-master-server-election/3890501; devforum.roblox.com/t/canopus-a-robust-distributed-lock-manager-for-server-coordination/4699717. Încredere: ridicata pentru existența și mecanismul general al modulelor (surse secundare, module comunitare recente, nu documentație oficială).

## Detalii

### 1. Interpretarea arhitecturală critică

CLAUDE.md spune: *"Tot serverul împarte același oraș... deblocare... permanent, pentru toți jucătorii de pe server."* Pe Roblox, un "server" e o **instanță efemeră**: la fiecare publish al jocului, serverele vechi rulează versiunea veche până se golesc natural, iar jucătorii noi intră pe servere noi. Un server popular poate trăi ore sau zile, dar nu e garantat permanent — și la un joc nou, cu populație mică, serverele se golesc și dispar rapid.

Asta creează două interpretări posibil de design, cu implicații tehnice complet diferite:

**A. Oraș per-instanță de server** (mai simplu): fiecare server e propriul lui "oraș", cu progres izolat. Cheia DataStore poate fi generată per JobId sau per grup de servere. Nu există problemă de "hot key" reală, pentru că fiecare server scrie doar pe propria cheie. Dezavantaj major: "permanent" devine fals — la restart de server (frecvent, la fiecare update publicat), progresul comunitar dispare pentru jucătorii care intră pe noul server, chiar dacă tehnic rămâne salvat pe vechea instanță (irecuperabilă practic, pentru că nimeni nu se mai întoarce pe un server vechi specific).

**B. Oraș partajat la nivel de univers (toate serverele, permanent)**: o singură stare, vizibilă din orice server, orice instanță, oricând. Aici apare integral problema descrisă în brief — mii de servere concurente (la scară) încercând să citească/scrie aceeași stare. Această interpretare e singura compatibilă cu promisiunea "permanent" din CLAUDE.md și e interpretarea pe care o tratează restul acestui document.

O variantă intermediară, folosită des în jocuri Roblox cu lume persistentă la scară (technique cunoscută ca **"world sharding"**): în loc de UN oraș global, se creează N "instanțe de oraș" fixe (ex. Town-1...Town-50), fiecare cu propria cheie persistentă în DataStore, iar sistemul de matchmaking plasează jucătorii într-un oraș cu loc liber. Reduce presiunea pe o singură cheie la 1/N din trafic, păstrând totuși persistență reală (nu per-server efemer). Nu am găsit un exemplu Roblox documentat public cu numere exacte pentru acest pattern — marcat NEVERIFICAT ca implementare specifică, dar tehnica în sine (sharding pe chei multiple) e confirmată indirect de best-practices-ul oficial DataStore ("use key prefixes to organize your data").

### 2. Problema cheii fierbinți în DataStoreService

Există trei mecanisme independente care se combină la o cheie globală unică, scrisă de multe servere:

| Mecanism | Cifră | Scalează cu |
|---|---|---|
| Buget de request-uri la nivel de experiență | 300 + concurrentUsers×40 (read), 300 + concurrentUsers×20 (write) /min | Numărul total de jucători din tot jocul |
| Buget de request-uri la nivel de server | 60 + numPlayers×40 /min | Jucătorii din ACEL server |
| Throughput per cheie (nu per server) | 25 MB/min citire, 4 MB/min scriere | **Nu scalează cu nimic — plafon fix per cheie** |
| Coadă de serializare per cheie | fără pauză fixă azi, dar tot secvențial | Numărul de scrieri concurente pe ACEA cheie |

Primele două bugete cresc cu numărul de jucători, deci teoretic "țin pasul" cu scara jocului. Dar limita de **throughput per cheie** (4 MB/min scriere) **nu** scalează — e un plafon fix pe acea cheie specifică, indiferent dacă vine de la 5 servere sau 5.000. Combinat cu coada de serializare (o scriere trebuie să se termine înainte să înceapă următoarea pe aceeași cheie), rezultatul practic la scară e: latență crescândă pentru fiecare donație individuală, cu risc de erori de throttling (cod HTTP intern 429 echivalent, întors ca `nil, errorMessage` din `pcall`).

Sursă: create.roblox.com/docs/cloud-services/data-stores/error-codes-and-limits, accesat 2026-09-08.

### 3. MemoryStoreService ca write-through cache

`MemoryStoreService` rezolvă exact acest tip de problemă: stare partajată, citită/scrisă frecvent de toate serverele, dar care nu trebuie neapărat persistentă la nesfârșit. API relevant (`MemoryStoreSortedMap`, confirmat din reference oficial):

```lua
local MemoryStoreService = game:GetService("MemoryStoreService")
local townCache = MemoryStoreService:GetSortedMap("TownStateCache")

-- SetAsync(key, value, expiration, sortKey)
townCache:SetAsync("MainTown", townStateTable, 45 * 24 * 60 * 60) -- max 45 zile

-- UpdateAsync(key, transformFunction, expiration) — la fel ca DataStore UpdateAsync
townCache:UpdateAsync("MainTown", function(current)
    current = current or DEFAULT_TOWN_STATE
    current.projects[projectId].donated[itemId] += 1
    return current
end, 45 * 24 * 60 * 60)
```

Pattern-ul "write-through": fiecare server scrie DONAȚIILE în `MemoryStoreSortedMap` imediat (rapid, vizibil cross-server aproape instant), iar DataStoreService primește o copie **periodică**, agregată, de la un singur server (leader), nu de la fiecare donație individuală. Asta transformă "1000 scrieri/minut pe cheia DataStore de la 1000 de servere" în "1 scriere/minut pe cheia DataStore, de la 1 server", eliminând complet problema de throughput per cheie pentru partea de DataStore — MemoryStore absoarbe frecvența, DataStore doar persistă rezultatul.

Limitare de reținut: mărimea maximă per item MemoryStore e **32 KB**, mult mai mic decât cei 4 MB per cheie DataStore. Documentul de stare al orașului trebuie ținut compact (ID-uri, contoare — nu text descriptiv, nu istoricul complet de donații).

### 4. Leader election / server coordonator

Roblox nu are un concept nativ de "server principal" — orice server e egal. Pentru a evita ca TOATE serverele să scrie simultan în DataStore, comunitatea a construit pattern-uri de **distributed lock** peste `MemoryStoreService`, exploatând faptul că are TTL (expirare) automat și `UpdateAsync` atomic:

```lua
local LEASE_KEY = "TownLeaderLease"
local LEASE_TTL = 30 -- secunde
local leaseStore = MemoryStoreService:GetSortedMap("Coordination")

local function tryBecomeLeader(serverId)
    local success, isLeader = pcall(function()
        return leaseStore:UpdateAsync(LEASE_KEY, function(current)
            if current == nil or current.expiresAt < os.time() then
                return { owner = serverId, expiresAt = os.time() + LEASE_TTL }
            end
            return current -- altcineva deține deja lease-ul valid
        end, LEASE_TTL + 5)
    end)
    return success and isLeader and isLeader.owner == serverId
end
```

Server-ul care câștigă lease-ul face flush-ul periodic către DataStore și broadcast-ul de deblocări prin MessagingService; toate celelalte servere doar citesc din MemoryStore cache. Dacă leader-ul crapă, lease-ul expiră automat (TTL) și alt server preia rolul la următoarea încercare — fără intervenție manuală. Acesta e exact pattern-ul descris de modulul comunitar **Canopus** (St0nae, 2026-06-23), construit pe `MemoryStoreService` pentru că oferă "built-in TTL, atomic UpdateAsync, and sub-100ms round trips", cu heartbeat pentru a extinde automat TTL-ul cât timp procesul rulează, backoff exponențial cu jitter la contenție, și eliberare automată a lock-ului dacă serverul crapă (lease-ul expiră singur). Un al doilea modul comunitar, **MasterServerService** (SimonScripts, 2025-08-20), oferă exact aceeași funcționalitate ca bibliotecă gata de folosit, cu callback `OnBecameMaster`.

Notă: aceste module sunt surse secundare — proiecte individuale de dezvoltatori, publicate pe DevForum în 2025-2026, nu servicii oficiale Roblox. Mecanismul (lock distribuit peste MemoryStore cu TTL) e solid și verificabil din API-ul oficial, dar codul concret al modulelor nu a fost auditat de mine.

### 5. Eventual consistency și UX

Documentația oficială confirmă explicit: *"The values you retrieve using GetAsync() sometimes can be out of sync with the backend due to the caching behavior."* Pentru orașul comun, asta înseamnă că un jucător care se alătură unui server chiar în momentul deblocării unei zone poate vedea, pentru câteva secunde, starea veche. Consecințe de design:

- Nu afișa niciodată bara de progres a orașului ca fiind "live, instant, exact" — tratează-o explicit ca aproximativă, cu actualizare la interval (ex. la fiecare donație validată local, plus resincronizare la 30-60s din MemoryStore).
- Deblocarea zonei trebuie să fie un eveniment **idempotent și ireversibil odată aplicat local**: primul server care vede pragul atins o aplică local imediat (UX bun, fără așteptare), iar restul serverelor se aliniază fie prin `MessagingService`, fie la următoarea resincronizare — nu contează ordinea exactă, pentru că starea finală convergentă e aceeași.

### 6. MessagingService pentru broadcast de deblocări

```lua
local MessagingService = game:GetService("MessagingService")

-- pe serverul leader, după ce flush-ul de DataStore a confirmat completarea proiectului:
MessagingService:PublishAsync("TownUnlock", {
    projectId = projectId,
    zoneId = zoneId,
    timestamp = os.time(),
})

-- pe FIECARE server (inclusiv leader-ul, care primește propriul mesaj):
MessagingService:SubscribeAsync("TownUnlock", function(message)
    local data = message.Data
    applyZoneUnlockLocally(data.zoneId) -- actualizează starea locală + UI clienți din acest server
end)
```

Limitele actuale (verificate, februarie 2024): mesaj max **1 KB** — suficient pentru un ID de proiect/zonă, insuficient pentru starea completă a orașului. `MessagingService` trebuie folosit **doar** ca notificare "ceva s-a schimbat, resincronizează", nu ca transport al datelor propriu-zise. Documentația nu specifică o garanție explicită de livrare (at-least-once vs. best-effort) — NEVERIFICAT — deci proiectează sistemul să funcționeze corect **chiar dacă un mesaj se pierde**: fiecare server trebuie să facă oricum o resincronizare periodică (poll) din MemoryStore/DataStore, independent de mesaje, ca plasă de siguranță.

### 7. Design ledger donații — model de date

Recomandare: **NU** ține istoricul complet de donații în documentul partajat al orașului (ar crește nemărginit, lovind atât limita de 4 MB DataStore cât și cea de 32 KB MemoryStore). Separă în trei straturi:

1. **Ledger per-jucător** (append-only, în profilul propriu al jucătorului, via ProfileStore) — istoric complet, fără limită de contenție pentru că fiecare jucător are propria cheie.
2. **Agregat partajat** (documentul orașului, în MemoryStore + DataStore) — doar contoare curente per proiect/item, fără istoric.
3. **Clasament contribuitori** (OrderedDataStore, cheie = UserId) — doar scorul total, actualizat atomic prin `IncrementAsync`.

```lua
-- (1) în profilul jucătorului (ProfileStore) — istoric personal
profile.Data.DonationHistory[#profile.Data.DonationHistory + 1] = {
    projectId = projectId, itemId = itemId, qty = qty, at = os.time(),
}

-- (2) agregatul partajat (MemoryStore, sincronizat periodic în DataStore de leader)
townCache:UpdateAsync("MainTown", function(state)
    state = state or DEFAULT_TOWN_STATE
    local p = state.projects[projectId]
    p.donated[itemId] = (p.donated[itemId] or 0) + qty
    return state
end, 45 * 24 * 60 * 60)

-- (3) clasament — cheie per jucător, deci FĂRĂ problemă de hot key
local contributorsStore = DataStoreService:GetOrderedDataStore("TownContributors")
contributorsStore:IncrementAsync(tostring(player.UserId), qty)
```

### 8. OrderedDataStore pentru clasament contribuitori

`OrderedDataStore` moștenește toate metodele din `GlobalDataStore` (inclusiv `IncrementAsync`), plus `GetSortedAsync(ascending, pageSize, minValue, maxValue): DataStorePages`. Eroarea **106** confirmă că `MinValue`/`MaxValue` trebuie să fie întregi, iar `PageSize` trebuie să fie într-un "interval predefinit" — documentația oficială nu specifică cifrele exacte ale acestui interval și nici limitele min/max ale valorilor stocabile; **NEVERIFICAT**, de testat direct în Studio înainte de a proiecta clasamente foarte mari.

```lua
local pages = contributorsStore:GetSortedAsync(false, 25) -- descrescător, top 25
local topPage = pages:GetCurrentPage()
for rank, entry in ipairs(topPage) do
    print(rank, entry.key, entry.value) -- entry.key = UserId, entry.value = total donat
end
```

Pentru că fiecare `IncrementAsync` scrie pe o cheie **per jucător**, nu pe una comună, clasamentul nu suferă deloc de problema cheii fierbinți — scalează natural cu numărul de jucători, exact ca datele lor de profil.

### 9. Anti-abuz la donații

Documentația Roblox nu tratează asta — e integral o decizie de design de joc, nu o limitare de platformă. Recomandări concrete:

- **Validare pe server a itemului donat**: acceptă doar `itemId`-uri din lista curentă `project.required` a proiectului activ. Orice altceva e respins înainte să atingă orice store. Asta elimină prin construcție "donațiile de gunoi" — nu mai există un vector de atac, pentru că nu există buton "donează orice".
- **Rate limit per jucător**: un debounce simplu (ex. un donation call / 1-2 secunde per jucător) e suficient ca plasă tehnică; abuzul real e oricum limitat de faptul că donațiile consumă obiecte deja reparate — un jucător nu poate genera "muniție" de donații mai repede decât permite bucla de reparat + spațiul limitat din atelier, care e deja motorul de fricțiune descris în CLAUDE.md.
- **Opțional — plafon per jucător per proiect** (ex. maxim 30-40% din cerința unui proiect poate veni de la un singur jucător): păstrează caracterul de "obligație socială" din brief — previne ca un singur jucător cu resurse mari să anuleze complet tensiunea cooperativă. E o alegere de design, nu o cerință tehnică.

### 10. Migrații la adăugarea de zone noi

Documentul partajat trebuie versionat explicit:

```lua
local SCHEMA_VERSION = 3

local function reconcileTownState(state)
    state = state or {}
    state.schemaVersion = state.schemaVersion or 1
    state.projects = state.projects or {}
    -- adaugă proiecte noi introduse în update-uri ulterioare, fără să atingă cele existente
    for projectId, definition in pairs(ProjectDefinitions) do
        if state.projects[projectId] == nil then
            state.projects[projectId] = { donated = {}, completedAt = nil }
        end
    end
    state.schemaVersion = SCHEMA_VERSION
    return state
end
```

Regula critică: la un deploy, servere pe versiunea VECHE și pe versiunea NOUĂ a jocului pot rula simultan (Roblox lasă serverele vechi să se golească natural). Funcția de transformare din `UpdateAsync`/`MemoryStoreSortedMap:UpdateAsync` trebuie să fie **aditivă și defensivă** — niciodată să presupună că forma datelor e deja cea mai nouă, niciodată să șteargă/redenumească un câmp existent fără o perioadă de tranziție.

## Recomandari concrete pentru Driftwood

1. **Decide explicit, înainte de pasul 5 din ordinea de lucru din CLAUDE.md, dacă orașul e per-server sau universe-wide.** Motiv: schimbă complet arhitectura (nu doar codul) — dacă răspunsul e "per-server", nu ai deloc problema cheii fierbinți descrisă în brief; dacă e "universe-wide", ai nevoie de tot ce descrie acest document.
2. **Nu folosi ProfileStore pentru documentul orașului.** Motiv: autorul spune explicit că nu e proiectat pentru asta; folosește `DataStoreService` + `MemoryStoreService` construite manual, cum e descris în secțiunile 3, 6 și 7.
3. **Separă ledger-ul de donații (per-jucător, în ProfileStore) de agregatul partajat (orașul, în MemoryStore→DataStore) și de clasament (OrderedDataStore).** Motiv: fiecare strat are propriul model de contenție; combinarea lor într-un singur document ar duce fie la depășirea limitei de 4 MB, fie la re-crearea problemei cheii fierbinți pentru date care n-ar trebui să o aibă.
4. **Implementează un lease de leader peste `MemoryStoreSortedMap` (TTL ~30s, heartbeat) încă din prototipul acestui sistem**, nu ca optimizare ulterioară. Motiv: fără el, orice test cu mai mult de un server concurent (Team Create, sau producție cu trafic real) va lovi coada de serializare pe cheia DataStore a orașului.
5. **Tratează `MessagingService` strict ca notificare best-effort, cu resincronizare periodică (poll la 30-60s) ca plasă de siguranță**, niciodată ca singură sursă de adevăr pentru o deblocare. Motiv: documentația nu garantează livrare 100%; un mesaj pierdut nu trebuie să lase un server "în urmă" permanent.
6. **Validează server-side că `itemId`-ul donat e în lista curentă cerută de proiectul activ, înainte de orice altă procesare.** Motiv: elimină prin construcție vectorul de "donații de gunoi", fără nevoie de logică anti-abuz suplimentară complexă.
7. **Folosește `IncrementAsync` pe cheie per-UserId pentru clasamentul de contribuitori, niciodată pe o cheie agregată comună.** Motiv: transformă un potențial hot-key în N chei independente, fără costuri suplimentare de design.
8. **Verifică în Studio, cu teste explicite, limitele numerice exacte pentru `OrderedDataStore` (range valori, `PageSize` maxim) înainte de a proiecta UI-ul de clasament.** Motiv: documentația oficială nu le specifică exact — sunt marcate NEVERIFICAT în acest document.
9. **Ține documentul orașului compact (contoare, ID-uri, flag-uri booleene) — niciodată text descriptiv sau istoric.** Motiv: limita de 32 KB per item în MemoryStore e mult mai strictă decât cei 4 MB din DataStore, iar write-through cache-ul trece prin MemoryStore la fiecare donație.
10. **Construiește `reconcileTownState()` aditiv de la primul commit, chiar dacă la lansare există un singur proiect/zonă.** Motiv: adăugarea de zone noi (explicit în roadmap-ul CLAUDE.md) va necesita structura asta oricum; e mult mai ieftin s-o ai de la început decât să migrezi un document live mai târziu.

## Riscuri si necunoscute

- **Riscul principal e conceptual, nu tehnic**: dacă echipa presupune "server" = "instanță curentă" în cod, dar "permanent pentru toți jucătorii" în design, cele două nu se potrivesc, și progresul comun se va simți fals-permanent (dispare la fiecare restart de server) fără ca nimeni să-și dea seama până la lansare.
- MemoryStore descris ca "strongly consistent" doar într-un reply de staff din 2021, nereconfirmat explicit în documentația curentă (2026) — dacă acest comportament s-a schimbat, pattern-ul de leader election de la secțiunea 4 (care presupune atomicitate pe lease) trebuie retestat.
- Nu există un API oficial "flush" sau "clear" pentru MemoryStore (confirmat din anunțul din 2021) — dacă documentul orașului trebuie resetat manual (ex. la un sezon nou), va trebui `SetAsync` cu valoare goală sau `RemoveAsync`, nu un helper dedicat.
- Nu am găsit în documentația oficială o garanție de ordine sau de livrare pentru `MessagingService:SubscribeAsync` — dacă două evenimente de deblocare vin aproape simultan, ordinea de aplicare pe fiecare server nu e garantată identică; design-ul trebuie să fie comutativ (aplicarea în orice ordine dă aceeași stare finală).
- Limitele exacte ale `OrderedDataStore` (range valori, `PageSize`) nu sunt documentate public — risc de erori 106 la scară, netestabile dinainte decât empiric în Studio.
- Nu am putut verifica cu surse primare cum funcționează intern sistemele de progres comunitar din jocuri mari Roblox (ex. evenimente cu contor global, "The Hunt", Adopt Me, Bee Swarm Simulator) — **NEVERIFICAT**, nu am inclus cifre sau mecanisme specifice ale acestor jocuri pentru că nu le-am putut confirma din surse oficiale sau devforum.

## Intrebari deschise

1. Orașul e per-server sau universe-wide? (decizie de produs, nu tehnică — trebuie luată de owner înainte de pasul 5 din CLAUDE.md)
2. Dacă e universe-wide: se acceptă un singur oraș global, sau world sharding (N orașe fixe, matchmaking între ele)? Depinde de populația așteptată la lansare.
3. Cât de des trebuie să facă leader-ul flush către DataStore — la fiecare prag atins, sau la interval fix (ex. 60s)? Trade-off direct între "cât de repede se vede deblocarea" și "câte scrieri DataStore pe minut".
4. Ce se întâmplă cu documentul orașului dacă TOATE serverele sunt jos simultan (ex. un update planificat) chiar când un lease de leader era activ? De testat: lease-ul expiră oricum după TTL, dar merită un test explicit de recovery la boot.
5. Plafonul per-jucător per-proiect (recomandarea 10 de mai sus) — se dorește ca lever de design, sau se preferă libertate totală de donație? Decizie de product design, nu tehnică.
6. De testat direct în Studio (Team Create, nu Run mode local — Run mode local are limite separate, adesea mai restrictive): comportamentul real de contenție pe `UpdateAsync` cu 3-5 "servere" concurente scriind pe aceeași cheie de test, pentru a calibra intervalul de flush al leader-ului cu date reale, nu doar teoretice din documentație.

## Surse

- [DataStore Limits](https://create.roblox.com/docs/cloud-services/data-stores/error-codes-and-limits) — create.roblox.com, accesat 2026-09-08
- [Data Stores](https://create.roblox.com/docs/cloud-services/data-stores) — create.roblox.com, accesat 2026-09-08
- [Data Store Best Practices](https://create.roblox.com/docs/cloud-services/data-stores/best-practices) — create.roblox.com, accesat 2026-09-08
- [Memory Stores](https://create.roblox.com/docs/cloud-services/memory-stores) — create.roblox.com, accesat 2026-09-08
- [MemoryStoreService (class reference)](https://create.roblox.com/docs/reference/engine/classes/MemoryStoreService) — create.roblox.com, accesat 2026-09-08
- [MemoryStoreSortedMap (class reference)](https://create.roblox.com/docs/reference/engine/classes/MemoryStoreSortedMap) — create.roblox.com, accesat 2026-09-08
- [GlobalDataStore (class reference)](https://create.roblox.com/docs/reference/engine/classes/GlobalDataStore) — create.roblox.com, accesat 2026-09-08
- [OrderedDataStore (class reference)](https://create.roblox.com/docs/reference/engine/classes/OrderedDataStore) — create.roblox.com, accesat 2026-09-08
- [DataStoreService (class reference)](https://create.roblox.com/docs/reference/engine/classes/DataStoreService) — create.roblox.com, accesat 2026-09-08
- [MessagingService (class reference)](https://create.roblox.com/docs/reference/engine/classes/MessagingService) — create.roblox.com, accesat 2026-09-08
- [Introducing MemoryStore - High Throughput, Low Latency Data Service](https://devforum.roblox.com/t/introducing-memorystore-high-throughput-low-latency-data-service/1475935) — DevForum, Roblox staff (unix_system, therealbiker), publicat 2021-09-20, cu update de spec pe 2022-01-14
- [Enhanced MessagingService Limits](https://devforum.roblox.com/t/enhanced-messagingservice-limits/2835576) — DevForum, Roblox staff (jjwu_play), 2024-02-12
- [ProfileStore - Save your player data easy](https://devforum.roblox.com/t/profilestore-save-your-player-data-easy-datastore-module/3190543) — DevForum, loleris (MAD STUDIO), 2024-10-11 (sursă secundară, modul comunitar de facto-standard)
- [Save your player data with ProfileService!](https://devforum.roblox.com/t/save-your-player-data-with-profileservice-datastore-module/667805) — DevForum, 2020-07-11, notă de descontinuare (sursă secundară, flag: pre-2024, verifică relevanța)
- [What datastore system is the best nowadays?](https://devforum.roblox.com/t/what-datastore-system-is-the-best-nowadays/4658415) — DevForum, discuție comunitară, 2026-05-29 (sursă secundară)
- [MasterServerService | v1.0.0 Master Server Election](https://devforum.roblox.com/t/masterserverservice-v1-0-0-master-server-election/3890501) — DevForum, SimonScripts, 2025-08-20 (sursă secundară, modul comunitar)
- [Canopus: A Robust Distributed Lock Manager for Server Coordination](https://devforum.roblox.com/t/canopus-a-robust-distributed-lock-manager-for-server-coordination/4699717) — DevForum, St0nae, 2026-06-23 (sursă secundară, modul comunitar)
- [GlobalStockService | Manage Global Stocks Across Servers](https://devforum.roblox.com/t/globalstockservice-manage-global-stocks-across-servers/3875976) — DevForum, SimonScripts, 2025-08-12 (sursă secundară, exemplu de pattern de stare partajată fără hot key, via seeding determinist)
- Document intern conex: `docs/research/[object Object]1-datastore-deep.md` (aceeași bază de proiect) — acoperă limitele generale DataStore și un prim schelet de idempotency pentru orașul comun; acest document extinde specific pe MemoryStore, leader election, MessagingService, ledger de donații și anti-abuz.
