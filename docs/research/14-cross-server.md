# Servere multiple, MemoryStore, MessagingService si orasul comun din Driftwood

## Rezumat executiv

- Roblox NU are un server unic global. Fiecare "server" e un proces izolat (RCC instance), efemer, cu propria lui memorie — nu exista nicio modalitate nativa prin care doi jucatori din servere diferite sa vada aceeasi lume 3D/2D in timp real. Orice "stare comuna intre TOATE serverele" e limitata la date abstracte (numere, flag-uri JSON), sincronizate prin polling, nu prin randare live.
- Opțiunea (a) din brief — "un singur oraș global pentru tot jocul" — **nu e fezabila ca lume vizuala unica**. E fezabila doar ca *stare de progres agregata* (ex: "zona X e deblocata pentru toata lumea"), sincronizata cu intarziere (secunde-minute) prin DataStore/MemoryStore. Trebuie clarificat explicit acest lucru pentru ca vine dintr-un fundal software unde "server global" inseamna altceva.
- CLAUDE.md deja specifica "tot serverul imparte acelasi oras" — asta e deja **optiunea (b): oras per-server**, nu (a). Cercetarea confirma ca (b) e exact modelul folosit de jocurile mari de tip social-simulator (Adopt Me, Bee Swarm Simulator): lume comuna *in interiorul unui server*, nu global.
- Problema reala a optiunii (b): serverele Roblox sunt efemere (ore, nu zile) — cand un server se goleste si se inchide, un server nou porneste GOL. Daca starea orasului traieste doar in memoria serverului, "progresul permanent" din CLAUDE.md dispare la fiecare ciclu de server. Trebuie persistat explicit via DataStore, indiferent de optiune.
- Recomandare: **optiunea (c) modificata — "oras per-server, persistat pe un ID de shard stabil"**: fiecare instanta de server care porneste "revendica" un shard (un slot dintr-un numar mic si fix de orase, ex. 20-50), incarca starea lui din DataStore, o salveaza periodic si la `BindToClose`. Jucatorii raman impreuna cat timp serverul e viu (matchmaking normal Roblox ii pune impreuna), iar progresul supravietuieste restart-urilor de server pentru ca traieste in DataStore, cheiat pe shard ID, nu pe JobId efemer.
- MemoryStoreSortedMap si MemoryStoreQueue au **o singura partitie fiecare** — un contor global unic (ex. "un singur oras pentru tot jocul") ar lovi plafonul de throughput al unei singure partitii la scara mare. Asta e un argument tehnic suplimentar impotriva optiunii (a) pur si simplu.
- Pentru evenimente programate (Inundatia lunara, schimbarea de sezon), nu e nevoie de MessagingService/MemoryStore deloc — pattern-ul dominant folosit de jocuri mari (confirmat de comunitate pentru Grow a Garden) e RNG cu seed determinist derivat din `Workspace:GetServerTimeNow()`, calculat independent pe fiecare server, fara nicio comunicare intre servere.
- MessagingService si MemoryStoreService raman utile pentru lucruri cu adevarat globale si mici ca volum: anunturi, leaderboard-uri, un contor de tip "high bid" sau "primii N donatori", nu pentru starea completa a orasului.
- `TeleportToPrivateServer` e **deprecated** in documentatia curenta — pentru redirectionarea jucatorilor catre un shard/oras specific trebuie folosit `TeleportAsync` cu `TeleportOptions.ReservedServerAccessCode`.

## Fapte verificate

- MemoryStoreService: cota de memorie per experienta = `64 KB + 1.2 KB * numar de utilizatori`; sursa: https://create.roblox.com/docs/cloud-services/memory-stores (accesat 2026-09-08, pagina dateaza ©2026); confidenta: ridicata.
- MemoryStoreService: cota de request-uri = `1000 + 120 * utilizatori concurenti` unitati/minut la nivel de experienta (nu per server); sursa: https://create.roblox.com/docs/cloud-services/memory-stores (2026-09-08); confidenta: ridicata.
- MemoryStore: maximum 1.000.000 de itemi per sorted map sau queue; maxim 100 MB marime totala (incl. chei); valoare per item maxim 32 KB; expirare intre 0 si 3.888.000 secunde (~45 zile); sursa: https://create.roblox.com/docs/cloud-services/memory-stores (2026-09-08); confidenta: ridicata.
- MemoryStore: `MemoryStoreSortedMap` si `MemoryStoreQueue` primesc **o singura partitie** fiecare; doar `MemoryStoreHashMap` e distribuit automat pe mai multe partitii; sursa: https://create.roblox.com/docs/cloud-services/memory-stores/per-partition-limits (2026-09-08); confidenta: ridicata.
- MemoryStore: `GetRangeAsync` intoarce maxim 100 de itemi per apel (arata in exemplul oficial); sursa: https://create.roblox.com/docs/reference/engine/classes/MemoryStoreSortedMap (2026-09-08); confidenta: medie (nu apare explicit ca "limita hard", ci ca marime de batch in exemplu).
- MemoryStoreQueue: `GetQueue(name, invisibilityTimeout)` are timeout implicit de 30 secunde; `ReadAsync(count, allOrNothing, waitTimeout)`; sursa: https://create.roblox.com/docs/reference/engine/classes/MemoryStoreQueue (2026-09-08); confidenta: ridicata.
- MessagingService: dimensiune maxima mesaj = 1 KB; trimitere = `600 + 240 * jucatori pe acel server`/minut; primire per topic = `40 + 80 * numar de servere`/minut; primire pe tot jocul = `400 + 200 * numar de servere`/minut; abonamente per server = `20 + 8 * jucatori`; `SubscribeAsync` = 240 cereri/minut; livrare "best effort", nu garantata; latenta tipica 1-2 secunde; nume topic 1-80 caractere; sursa: https://raw.githubusercontent.com/Roblox/creator-docs/main/content/en-us/reference/engine/classes/MessagingService.yaml (sursa oficiala Roblox pe GitHub, root al paginii create.roblox.com/docs/reference/engine/classes/MessagingService), verificat 2026-09-08; confidenta: ridicata (dar pagina randata public nu afiseaza aceste cifre — vezi risc mai jos).
- DataStoreService: nume DataStore/cheie/scope maxim 50 caractere; valoare maxim 4.194.304 bytes (4 MB) per cheie; sursa: https://create.roblox.com/docs/cloud-services/data-stores/error-codes-and-limits (2026-09-08); confidenta: ridicata.
- DataStoreService: storage total per experienta = `500 MB + 1 MB * numar de utilizatori unici in istoricul jocului`; sursa: idem; confidenta: ridicata.
- DataStoreService: throughput per cheie: citire max 25 MB/minut, scriere max 4 MB/minut; sursa: idem; confidenta: ridicata.
- DataStoreService (Standard): citire `300 + 40*CCU`/min, scriere `300 + 20*CCU`/min, list `300 + 2*CCU`/min, remove `300 + 40*CCU`/min — formule la nivel de experienta; sursa: idem; confidenta: medie (pagina prezinta si un set separat "server-level" cu formule diferite, posibil vechi/redundant — vezi riscuri).
- Publicarea unei actualizari NU inchide fortat serverele vechi; developerul poate fie sa restarteze manual din Configure > Server Management (migrare activa, jucatorii sunt teleportati automat catre versiunea noua), fie sa lase serverele vechi sa se goleasca natural; sursa: https://create.roblox.com/docs/projects/update-games (2026-09-08); confidenta: ridicata.
- "Delay server restart" (soft shutdown): jucatorilor li se da intre **1 si 60 de minute** sa paraseasca serverul de bunavoie inainte de deconectare fortata; sursa: idem; confidenta: ridicata.
- `DataModel.ServerRestartScheduled(restartTime: DateTime, source: Enum.CloseReason, attributes: Dictionary)` — eveniment care anunta un restart programat; sursa: https://create.roblox.com/docs/reference/engine/classes/DataModel (2026-09-08); confidenta: ridicata.
- `Enum.CloseReason` are valorile: Unknown(0), RobloxMaintenance(1), DeveloperShutdown(2), DeveloperUpdate(3), ServerEmpty(4), OutOfMemory(5), Moderation(6); sursa: https://create.roblox.com/docs/reference/engine/enums/CloseReason (2026-09-08); confidenta: ridicata.
- `TeleportToPrivateServer` e marcat **deprecated**; metoda curenta e `TeleportAsync` cu `TeleportOptions.ReservedServerAccessCode` / `TeleportOptions.ShouldReserveServer`; teleportarea poate fi apelata doar din server-side scripts; sursa: https://create.roblox.com/docs/projects/teleport (2026-09-08); confidenta: ridicata.
- Reserved/private servers: un private server e o functie pe abonament, pretul se seteaza de dezvoltator (poate fi si gratuit), schimbarea pretului **anuleaza toate abonamentele active**; jocul trebuie sa fie public inainte de a activa functia; nu poate coexista cu acces platit direct al jocului; sursa: https://create.roblox.com/docs/production/monetization/private-servers (2026-09-08); confidenta: ridicata.
- Roblox a lansat in 2025 un sistem nou de matchmaking bazat pe "signals" ponderate (nu doar "server fill" simplu): pasii sunt cerere → filtrare servere eligibile (exclude pline/private/reserved/in inchidere) → scorare → potrivire cu cel mai bun scor → intrare; sursa: https://create.roblox.com/docs/matchmaking (2026-09-08); confidenta: ridicata.
- Semnale implicite si ponderi: Friends=15, Latency=3, Text Chat=3, Occupancy=2, Play History=2, Language=2, Age=1, Voice Chat=1, Device Type=0 (inactiv); ponderea Friends e mai mare decat suma tuturor celorlalte; formula ocupare: `occupancySignalScore = jucatori_in_server / capacitate_server`; sursa: https://create.roblox.com/docs/matchmaking/scoring si https://create.roblox.com/docs/matchmaking/attributes-and-signals (2026-09-08); confidenta: ridicata.
- Custom matchmaking: maxim 2 semnale custom per joc, maxim 5 atribute per jucator si 5 per server; configurare din Creator Dashboard > Creations > Custom Matchmaking; sursa: https://create.roblox.com/docs/matchmaking/customize-matchmaking (2026-09-08); confidenta: ridicata.
- Roblox a introdus in beta serverele de pana la **700 de jucatori** (anunt oficial DevForum, 13 august 2020); sursa secundara confirma ca optiunea de 700 era inca mentionata activ intr-un thread din 20 ianuarie 2024 ("Server Player Limit"); sursa: devforum.roblox.com, cautare "Max Player Count Increased" / "Server Player Limit"; confidenta: medie (2020 e vechi, marcat NEVERIFICAT daca mai e valabil identic azi ca implicit vs. optional). **(corectat la verificare)**: exista un anunt oficial ulterior, DevForum, 13 aprilie 2023, "Experience Join Improvements: Server Size, Join Queues and Social Slots Reservations" (https://devforum.roblox.com/t/experience-join-improvements-server-size-join-queues-and-social-slots-reservations/2294621), care confirma ca maximul **accesibil tuturor dezvoltatorilor a fost fixat la 200 jucatori/server**, in timp ce 700 ramane o capabilitate de beta/nivel superior, nu implicit disponibila general; confidenta: ridicata.
- Adopt Me (cel mai jucat joc de tip "oras comun + teren propriu" de pe Roblox) si-a redus dimensiunea serverului public de la **48 la 35 de jucatori**, motivul citat de comunitate fiind performanta pe device-uri slabe; sursa: Reddit r/AdoptMeRBX, thread "Adopt me changed the server size from 48 to 35" (~2025, data exacta nu e afisata de Reddit, doar "1 year ago" fata de accesare 2026-09-08); sursa **secundara**, confidenta: scazuta — neconfirmat oficial de dezvoltatorii Adopt Me/Uplift Games.
- Bee Swarm Simulator ruleaza **6 hive-uri (terenuri) per server**, fiecare hive fiind spatiul unui jucator, in interiorul aceluiasi server impartasit; sursa: Bee Swarm Simulator Wiki (Fandom), pagina "Hive"; sursa **secundara** (wiki comunitate), confidenta: medie — confirma modelul "server comun + teren individual" deja ales de Driftwood.
- Pattern-ul comunitar dominant (confirmat in 3 thread-uri DevForum separate, iunie-decembrie 2025) pentru "stare identica pe toate serverele" tip stoc de shop/eveniment recurent este: **RNG cu seed determinist derivat din timp** (`Workspace:GetServerTimeNow()` sau `os.time()`), calculat independent de fiecare server, FARA MessagingService/MemoryStoreService; motivul dat explicit: MemoryStore + leader-election + lock-uri distribuite sunt "overcomplicated" pentru cazul in care fiecare server oricum trebuie sa afiseze acelasi rezultat calculabil, nu sa imparta o resursa cu adevarat limitata; surse: https://devforum.roblox.com/t/reverse-engineering-on-how-the-stock-system-in-grow-a-garden-works/3767345 (iunie 2025), https://devforum.roblox.com/t/memorystoreservice-and-distributed-locking/4197296 (decembrie 2025), https://devforum.roblox.com/t/random-global-event-system/3781269 (iunie 2025); sursa **secundara** (comunitate, reverse-engineering neconfirmat de Roblox/Grow a Garden), confidenta: medie.
- `Workspace:GetServerTimeNow(): number` exista ca API oficial si e recomandat de comunitate in locul lui `os.time()` pentru sincronizare intre servere pentru ca e ancorat de ceasul serverelor Roblox, nu de ceasul local al masinii; sursa: https://create.roblox.com/docs/reference/engine/classes/Workspace (2026-09-08); confidenta: ridicata pentru existenta API-ului, medie pentru recomandarea de utilizare (vine din comunitate, nu explicit din documentatie).

## Detalii

### 1. Ce e de fapt un "server" pe Roblox

Un loc publicat (place) ruleaza in mai multe instante de server independente (RCC — Roblox Cloud Compute instances), fiecare cu propriul proces, propria memorie, propriul `game.JobId`. Cand un jucator apasa Play, Roblox foloseste sistemul de matchmaking (vezi sectiunea 6) ca sa-l aloce unui server existent sau sa porneasca unul nou. Serverele sunt **efemere**: nu exista un server "principal" care traieste permanent — orice server poate fi inchis oricand (jucatorii pleaca -> `ServerEmpty`, mentenanta Roblox -> `RobloxMaintenance`, developer forteaza -> `DeveloperShutdown`, sau developer publica update -> `DeveloperUpdate`; toate astea sunt valori concrete in `Enum.CloseReason`).

Consecinta directa pentru Driftwood: **orice stare care trebuie sa supravietuiasca unui ciclu de server (adica orice progres "permanent" mentionat in CLAUDE.md) trebuie scrisa explicit in DataStore**, nu tinuta doar in variabile Lua pe server. Asta e valabil si pentru varianta cea mai simpla (oras per-server): daca serverul se goleste si se inchide, un jucator care revine mai tarziu ajunge cu mare probabilitate pe un server NOU, care nu stie nimic despre orasul vechi — decat daca acel progres a fost salvat sub o cheie stabila si reincarcat.

### 2. MemoryStoreService — cand si cum

MemoryStoreService ofera trei structuri: `MemoryStoreSortedMap`, `MemoryStoreHashMap`, `MemoryStoreQueue`, obtinute prin `MemoryStoreService:GetSortedMap(name)`, `:GetHashMap(name)`, `:GetQueue(name, invisibilityTimeout)`.

**Limite (per experienta, nu per server):**

| Resursa | Limita | Sursa |
|---|---|---|
| Memorie totala | 64 KB + 1.2 KB × utilizatori | create.roblox.com/docs/cloud-services/memory-stores |
| Request units/minut | 1000 + 120 × utilizatori concurenti | idem |
| Itemi per sorted map/queue | 1.000.000 | idem |
| Marime totala structura | 100 MB (incl. chei la sorted map) | idem |
| Marime per item | 32 KB | idem |
| Expirare (`expiration`) | 0 - 3.888.000 secunde (~45 zile) | idem |
| Partitii per sorted map | 1 | .../memory-stores/per-partition-limits |
| Partitii per queue | 1 | idem |
| Partitii per hash map | multiple, auto-distribuite | idem |
| `GetRangeAsync` batch | pana la 100 itemi/apel | reference/MemoryStoreSortedMap |
| `ReadAsync` (queue) batch | pana la 100 itemi/apel | reference/MemoryStoreQueue |
| Invisibility timeout implicit (queue) | 30 secunde | reference/MemoryStoreQueue |

Consumul de "request units" nu e 1:1 cu apelurile: `GetRangeAsync` consuma cate o unitate per item intors (minim 1), `ReadAsync` consuma 1 unitate per item plus 1 unitate la fiecare 2 secunde de asteptare (`waitTimeout`), `UpdateAsync` consuma minim 2 unitati, `ListItemsAsync` consuma 1 unitate per partitie scanata plus 1 per item.

**Cel mai important detaliu tehnic pentru decizia orasului comun**: `MemoryStoreSortedMap` si `MemoryStoreQueue` traiesc **intr-o singura partitie**, indiferent cate chei ai in ele. Doar `MemoryStoreHashMap` se distribuie automat pe mai multe partitii — dar chiar si acolo, o cheie individuala accesata foarte des ramane limitata la throughput-ul partitiei ei; documentatia recomanda explicit "sharding" (impartirea unei chei fierbinti in mai multe chei, ex. `stock:1`, `stock:2`, ...) cand ai un singur punct de acces cu trafic mare.

Practic: daca ai implementa optiunea (a) "un singur oras pentru tot jocul" ca un `MemoryStoreSortedMap` cu o cheie unica "town_state", TOATE serverele active (potential sute, la un joc popular) ar bate in aceeasi partitie, cu acelasi plafon de throughput (documentatia da un exemplu ilustrativ de ~50.000 RPM per partitie, dar precizeaza explicit ca cifra reala "fluctueaza" si nu e garantata — deci NEVERIFICAT ca numar exact).

### 3. MessagingService — cross-server messaging

`MessagingService:PublishAsync(topic, message)` / `:SubscribeAsync(topic, callback)`. Pagina publica de referinta (create.roblox.com/docs/reference/engine/classes/MessagingService) NU afiseaza cifrele de limitare in continutul extras de noi (posibil randate doar prin JS sau intr-o sectiune neaccesata de fetch); cifrele exacte au fost gasite in sursa YAML brута de pe GitHub-ul oficial Roblox/creator-docs, care alimenteaza acea pagina:

| Limita | Valoare |
|---|---|
| Marime maxima mesaj | 1 KB |
| Trimitere (per server) | 600 + 240 × jucatori pe acel server / minut |
| Primire per topic (tot jocul) | 40 + 80 × numar de servere / minut |
| Primire total joc | 400 + 200 × numar de servere / minut |
| Abonamente active per server | 20 + 8 × jucatori pe acel server |
| Cereri de subscribe | 240 / minut |
| Lungime nume topic | 1-80 caractere |
| Livrare | "best effort", nu garantata |
| Latenta tipica | 1-2 secunde |

Aceste formule scaleaza cu **numarul de servere active**, nu cu numarul total de jucatori din joc — asta inseamna ca la un joc cu multe servere mici, limita de primire per topic creste, dar fiecare server individual tot trimite in functie doar de jucatorii lui locali. E gandit pentru broadcast usor (anunturi, "cineva a gasit item rar"), nu pentru sincronizarea unei stari complexe de joc.

### 4. DataStoreService ca "stare globala" cu UpdateAsync

| Limita | Valoare | Nivel |
|---|---|---|
| Nume DataStore/cheie/scope | 50 caractere max | — |
| Valoare per cheie | 4.194.304 bytes (4 MB) | per cheie |
| Storage total | 500 MB + 1 MB × utilizatori unici in istoric | per experienta |
| Throughput citire per cheie | 25 MB/minut | per cheie |
| Throughput scriere per cheie | 4 MB/minut | per cheie |
| Citire (Standard) | 300 + 40×CCU / minut | per experienta |
| Scriere (Standard) | 300 + 20×CCU / minut | per experienta |
| List | 300 + 2×CCU / minut | per experienta |
| Remove | 300 + 40×CCU / minut | per experienta |

(CCU = concurrent users / jucatori concurenti in intreaga experienta, nu per server.)

Pattern-ul standard pentru "o singura cheie actualizata de mai multe servere" e `UpdateAsync` cu functie de transformare — Roblox garanteaza ca transformarea vede ultima valoare scrisa si o rescrie atomic, dar **documentatia oficiala nu specifica un timp exact de "lock" sau retry intern** in continutul pe care l-am putut extrage; regula de aur din comunitate si din bunele practici oficiale (data-stores/best-practices) e: implementeaza propriul retry cu exponential backoff (2s, 4s, 8s...) si NU presupune ca `UpdateAsync` rezolva singur coliziunile la trafic mare — la multe servere care scriu simultan pe aceeasi cheie, riscul e coada de retry-uri, nu coruptie de date (Roblox serializeaza scrierile per cheie), dar throughput-ul per cheie (4 MB/minut scriere) devine bottleneck-ul real la scara mare.

### 5. TeleportService, reserved si private servers

`TeleportAsync(placeId, players, teleportOptions)` — apelabil doar din server. Pentru un shard/oras specific:
```lua
local TeleportService = game:GetService("TeleportService")
local options = Instance.new("TeleportOptions")
options.ShouldReserveServer = true -- creeaza un server rezervat nou
local accessCode = TeleportService:ReserveServerAsync(game.PlaceId)
options.ReservedServerAccessCode = accessCode
TeleportService:TeleportAsync(game.PlaceId, {player}, options)
```
Datele trimise prin `TeleportOptions:SetTeleportData()` sunt singurul mod nesigur (needat prin DataStore) de a duce date intre placuri/servere la teleportare; orice altceva "local" se pierde la teleport.

Private servers (VIP servers) sunt o functie pe **abonament lunar** platit de jucator catre dezvoltator, nu un mecanism tehnic de sharding gratuit — schimbarea pretului anuleaza abonamentele active, iar jocul trebuie sa fie deja public. Nu se potriveste ca mecanism implicit pentru "orasul tuturor", dar poate fi baza pentru un mod "oras privat cu prietenii" ca feature separat, monetizabil.

### 6. Matchmaking nou (2025) si "server fill"

Roblox a inlocuit vechea logica simpla de umplere a serverelor cu un sistem de "signals" ponderate. Pentru fiecare jucator care intra: se filtreaza serverele eligibile (nu pline, nu private/reserved, nu in curs de inchidere), se scoreaza fiecare server dupa o suma ponderata de semnale, jucatorul intra pe cel cu scorul cel mai mare.

Semnale implicite si ponderi: Friends=15, Latency=3, Text Chat=3, Occupancy=2, Play History=2, Language=2, Age=1, Voice Chat=1, Device Type=0. Ponderea Friends e mai mare decat suma tuturor celorlalte — daca un jucator are prieteni pe un server, e trimis acolo aproape indiferent de alti factori. "Occupancy" (`jucatori_in_server / capacitate_server`) exista dar are pondere mica (2) — Roblox NU incearca agresiv sa umple serverele la maxim inainte de a deschide unul nou; asta inseamna ca jucatorii solo, fara prieteni in joc, se pot imprastia pe mai multe servere partial goale, ceea ce slabeste senzatia de "oras comun viu" daca populatia jocului e mica la lansare.

Se pot defini pana la 2 semnale custom si 5 atribute custom per jucator/server, configurabile din Creator Dashboard > Creations > Custom Matchmaking — util ulterior daca Driftwood vrea sa influenteze explicit gruparea (ex: prioritizeaza jucatori care au deja progres in acelasi "oras" logic).

### 7. Cum rezolva jocurile mari problema (surse secundare, comunitate)

Nu exista documentatie tehnica oficiala din partea Adopt Me, Pet Simulator 99, Bee Swarm Simulator sau Grow a Garden despre arhitectura lor interna — tot ce urmeaza e din surse secundare (wiki-uri, DevForum comunitate, reverse-engineering, Reddit) si trebuie tratat ca atare.

- **Bee Swarm Simulator**: 6 hive-uri (terenuri individuale) intr-un singur server — exact modelul "server comun + teren propriu" pe care Driftwood il are deja in CLAUDE.md. Nu exista dovezi de stare "globala" cross-toate-serverele pentru hive-uri.
- **Adopt Me**: dimensiunea serverului public a fost redusa recent de la 48 la 35 de jucatori (sursa secundara Reddit, neconfirmata oficial), motivul citat fiind performanta. Are un "Trading Hub" descris de un blog tert ca zona de listari cross-server pentru tranzactionare — sugereaza ca partea de "trading" foloseste un backend global separat (probabil DataStore/Open Cloud), NU intreaga lume a jocului.
- **Grow a Garden**: sistemul de "stock" (restock la fiecare 5 minute, identic pe toate serverele) e reverse-engineered de comunitate ca fiind determinist: fiecare server calculeaza independent, folosind `Workspace:GetServerTimeNow()` impartit la intervalul de 5 minute ca "tick", hash-uit cu o cheie secreta, alimentand `Random.new(seed)`. Niciun apel MessagingService/MemoryStore implicat — rezultatul e identic pe toate serverele pentru ca toate calculeaza aceeasi formula cu acelasi ceas. Aceeasi discutie sugereaza ca evenimentele de vreme ("weather events") probabil folosesc un pattern similar, desi asta nu e confirmat oficial (NEVERIFICAT).
- Consensul explicit din 3 thread-uri DevForum separate (2025): pentru "acelasi rezultat pe toate serverele" fara sa fie o resursa cu adevarat epuizabila/impartita, folositi RNG determinist pe timp, NU MemoryStoreService — un developer descrie explicit incercarea cu MemoryStore ca fiind nevoie de "master server, tracking, coada pentru cazul cand MSS pica" — adica mult mai complex decat trebuie.
- MemoryStoreService/DataStoreService raman necesare doar cand resursa e **cu adevarat limitata si comuna** (ex: primele 1.000.000 de obiecte pescuite global, un top de donatori, un stoc cu adevarat finit care nu se poate regenera determinist).

### 8. Cele trei optiuni pentru Driftwood, evaluate

**(a) Un oras global pentru tot jocul (toate serverele)**
- Retentie: teoretic cea mai puternica poveste sociala ("tot jocul construieste un singur oras"), dar practic invizibila jucatorului — nu poate vedea sau interactiona live cu jucatori de pe alte servere, deci "comunul" se reduce la un progres-bara abstract actualizat cu intarziere.
- Cost inginerie: mare. Necesita o cheie/partitie globala (DataStore + MemoryStore ca cache), risc de bottleneck pe o singura partitie MemoryStore, logica de reconciliere/eventual-consistency, UI care explica de ce ce vede jucatorul nu se schimba instant cand altcineva de pe alt server doneaza.
- Abuz: greu de "griefuit" direct (nimeni nu poate strica fizic ce a facut altcineva de pe alt server), dar usor de exploatat prin farming/multi-accounting agregat, pentru ca fiecare server contribuie la acelasi numar.
- Verdict: nepotrivit ca implementare literala a unui "oras" vizual; util doar pentru un contor secundar tip "obiective globale ale comunitatii" (ex: eveniment sezonier promotional), nu pentru mecanica principala din CLAUDE.md.

**(b) Oras per-server, care reseteaza**
- Retentie: buna cat timp serverul traieste (jucatorii vad impreuna progresul), dar contrazice direct principiul din CLAUDE.md ("deblocare permanenta") — daca serverul moare si progresul cu el, jucatorii invata ca nimic nu conteaza pe termen lung, exact opusul obligatiei sociale dorite.
- Cost inginerie: minim (e ce ai deja implicit daca nu faci nimic special).
- Abuz: risc mare — cineva poate sa astepte ca serverul sa se goleasca aproape complet si sa "resteze" progresul comunitatii pentru ceilalti fara sa vrea, sau progresul dispare pur si simplu cand serverul e reciclat de un `DeveloperUpdate`.
- Verdict: nepotrivit ca atare pentru mecanica de "atelier al orasului" — trebuie cel putin persistat.

**(c) Orase named/sharded, persistate independent** (recomandat, vezi mai jos)
- Retentie: pastreaza senzatia de "oras al meu, al nostru" (jucatorii vad si interactioneaza live cu ceilalti de pe acelasi shard), IAR progresul supravietuieste restart-urilor de server pentru ca e legat de un ID de shard stabil, nu de JobId efemer.
- Cost inginerie: moderat — reutilizeaza exact pattern-ul deja planificat pentru salvarea datelor de jucator (DataStore + UpdateAsync + retry), aplicat unei singure "entitati oras" per shard in loc de per jucator.
- Abuz: similar cu (b) in interiorul unui shard (posibil griefing local — cineva strica reparatul altcuiva, doneaza gresit), dar limitat la populatia acelui shard, nu propaga la tot jocul.
- Verdict: cel mai bun echilibru intre promisiunea din CLAUDE.md si constrangerile reale ale platformei.

## Recomandari concrete pentru Driftwood

1. **Adoptati explicit varianta (c): "oras-shard persistat"**, nu (a) sau (b) brut. Redefiniti in CLAUDE.md ce inseamna "tot serverul imparte acelasi oras": e corect ca enunt (jucatorii dintr-un server vad acelasi oras), dar trebuie adaugat ca acel oras are un `TownId` stabil, independent de `game.JobId`, salvat in DataStore. Motiv: pastreaza promisiunea de progres permanent fara sa cereti platformei ceva ce nu suporta (o lume vizuala unica pentru tot jocul).

2. **Model de date minimal pentru orasul-shard**, folosind un `OrderedDataStore`/`DataStore` standard cheiat pe `TownId` (nu pe jucator):
```lua
-- DataStore "TownState", cheie = TownId (ex: "town_014")
{
  townId = "town_014",
  unlockedZones = {"dock", "mill", "market"}, -- lista de zone deblocate permanent
  workshopDonations = { -- progres curent spre urmatorul deblocaj
    ["repair_kit_set_3"] = 12, -- din 20 necesare
  },
  lastServerJobId = "xxxxxxxx-...",
  lastSavedAt = 1234567890, -- os.time()
  version = 7 -- crescut la fiecare UpdateAsync reusit, pt debugging conflicte
}
```

3. **Atribuirea shard-ului la boot de server**: la pornire, fiecare server incearca sa "revendice" un `TownId` liber sau cel mai putin populat, dintr-o lista fixa mica (ex. 20-50 de orase, nu unul per server efemer — evitati proliferarea nelimitata). Pastrati in `MemoryStoreSortedMap` (o singura partitie, deci volum mic si controlat: doar N intrari, N = numar de orase, nu numar de jucatori) o harta `TownId -> numar_jucatori_activi`, actualizata la `PlayerAdded`/`PlayerRemoving`; serverul nou alege shard-ul cu cea mai mica populatie curenta (similar cu semnalul "Occupancy" din matchmaking-ul Roblox, dar controlat de voi, nu de Roblox).

4. **Salvare**: la boot, `GetAsync(TownId)` din DataStore incarca starea; la fiecare 2 minute (deja planificat pentru jucatori in CLAUDE.md) plus la `game:BindToClose()`, faceti `UpdateAsync(TownId, transformFn)` care aplica doar diferentele acumulate local (nu suprascrie orbeste), pentru a reduce sansa de a pierde progres facut concurent de un alt server care detine temporar acelasi shard (posibil doar in tranzitie, ex. cand shard-ul isi schimba serverul "curent").

5. **Nu folositi MessagingService pentru sincronizare live intre servere ale aceluiasi shard** — in practica, un shard e "detinut" de UN SINGUR server la un moment dat (jucatorii aceluiasi shard sunt pusi de matchmaking-ul vostru pe acelasi server); MessagingService ramane util doar pentru cazuri opționale: anuntarea catre alte servere ca un shard tocmai s-a inchis si populatia lui trebuie redirectionata, sau un panou "orase active acum" in lobby.

6. **Evenimentele programate (Inundatia lunara, schimbarea de sezon) — implementati-le determinist pe timp, nu prin broadcast**: folositi `Workspace:GetServerTimeNow()`, calculati faza curenta cu aceeasi formula pe toate serverele (`os.time() // durata_ciclu` sau echivalent), fara nicio comunicare intre servere. E exact pattern-ul validat de comunitate pentru Grow a Garden si evita complet limitele MessagingService/MemoryStore pentru aceasta parte.

7. **Rezervati MemoryStoreService doar pentru lucruri cu adevarat limitate si globale** — ex. un contor "primii 100 de donatori ai unui set rar primesc un cosmetic exclusiv" (`MemoryStoreSortedMap`, o singura cheie/partitie, dar volum mic de operatii pentru ca e un eveniment rar, nu update la fiecare prindere de obiect).

8. **Pentru "orase private cu prietenii" ca feature ulterior de monetizare**, folositi `TeleportAsync` + `TeleportOptions.ReservedServerAccessCode` (nu `TeleportToPrivateServer`, care e deprecated) impreuna cu feature-ul oficial de Private Servers (abonament lunar) — dar tineti minte ca schimbarea pretului anuleaza abonamentele active, deci pretul trebuie stabilit cu grija inainte de lansare.

9. **Testati in Studio cu multi-server emulation** (Test > Multiple Players / Server pe mai multe ferestre in Studio) inainte sa presupuneti ca sincronizarea via DataStore functioneaza — comportamentul de `UpdateAsync` sub scriere concurenta reala nu poate fi validat complet local, dar fluxul de boot/claim/save al shard-ului poate.

## Riscuri si necunoscute

- Cifrele exacte de MessagingService au fost gasite doar in sursa YAML de pe GitHub (root al documentatiei), NU in continutul extras de pe pagina publica randata — posibil ca pagina publica sa aiba acele cifre intr-o sectiune neaccesata de instrumentul nostru de fetch (JS-randat) sau posibil ca ele sa fi fost mutate/eliminate din randare. Recomandare: verificati manual pagina https://create.roblox.com/docs/reference/engine/classes/MessagingService in browser inainte sa proiectati bugete stricte pe ea.
- DataStoreService: pagina de limite arata **doua seturi diferite de formule** (unul etichetat generic per "experienta", altul aparent per "server", cu cifre diferite: 300+40×CCU vs 60+40×numPlayers) — posibil ca unul sa fie invechit sau ca noi sa fi interpretat gresit contextul din extragerea automata. NEVERIFICAT care e cel corect si actual; trebuie confirmat manual pe pagina oficiala inainte de a dimensiona traficul de salvare al shard-urilor.
- Nu exista o cifra oficiala confirmata pentru "Max Players" implicit/maxim per server in 2025-2026 — informatia gasita (700, in beta) e din 2020, redevine mentionata in 2024, dar NEVERIFICAT daca mai e valabila identic azi sau daca necesita aprobare speciala peste un anumit prag. **(corectat la verificare)**: rezolvat partial — anuntul oficial DevForum din 13 aprilie 2023 confirma 200 jucatori/server ca maxim accesibil general; 700 ramane restrictionat (nivel beta/aprobare speciala), nu un implicit disponibil in 2026. Vezi tabelul de verificare independenta de mai jos.
- Toate cifrele despre Adopt Me, Bee Swarm Simulator si Grow a Garden sunt din surse secundare (Reddit, Fandom, DevForum comunitate) — niciuna confirmata oficial de studiourile respective. Arhitectura lor reala ramane necunoscuta; ce am descris e cel mult plauzibil, nu garantat.
- `UpdateAsync` — documentatia oficiala accesata de noi nu descrie explicit comportamentul de locking/retry intern; presupunerea ca Roblox serializeaza corect scrierile concurente pe aceeasi cheie se bazeaza pe cunoastere generala a API-ului, nu pe un citat direct gasit acum. Trebuie verificat in documentatia completa (sectiunea GlobalDataStore, poate cu exemple de cod) inainte de a proiecta logica critica de merge pe `TownState`.
- Bugetul de cautare web (WebSearch) al sesiunii curente s-a epuizat devreme in cercetare; toata cercetarea de dupa acel punct s-a facut prin fetch direct de URL-uri si prin navigare reala in browser (Google/DevForum), ceea ce a limitat acoperirea comparativ cu cautari libere multiple.

## Intrebari deschise

1. Cate "orase" (shard-uri) ar trebui sa existe la lansare? Depinde de populatia asteptata simultan — trebuie estimat un CCU tinta inainte de a fixa numarul (prea putine = shard-uri supra-aglomerate care lovesc limitele DataStore per-cheie; prea multe = orase goale, se pierde senzatia de "comun").
2. Cat de des trebuie salvat `TownState` pentru a nu depasi 4 MB/minut scriere per cheie, avand in vedere ca toate donatiile/deblocarile dintr-un shard scriu pe aceeasi cheie? Trebuie testat volumul real de date per salvare.
3. Ce se intampla cu progresul unui shard cand serverul care il detine e reciclat de un `DeveloperUpdate` in mijlocul unei sesiuni active? Necesita testare explicita in Studio a secventei `ServerRestartScheduled` -> `BindToClose` -> salvare -> shard "eliberat" pentru urmatorul server care porneste.
4. Merita implementat un semnal de matchmaking custom (Roblox permite pana la 2) ca sa influentati direct alocarea jucatorilor pe shard-ul lor anterior, in loc sa gestionati voi complet alocarea prin cod? Necesita un test comparativ intre "matchmaking Roblox standard + redirect prin cod" vs. "semnal custom".
5. Cifrele reale de DataStoreService (per-experienta vs per-server, contradictia observata) trebuie confirmate manual pe pagina oficiala inainte de a proiecta bugetul de scriere al shard-urilor.
6. Care e comportamentul exact al `UpdateAsync` sub scriere concurenta din mai multe surse (ex. daca vreodata doua servere ating temporar acelasi `TownId`) — necesita fie citirea directa a sectiunii complete GlobalDataStore din documentatie, fie un test dedicat in Studio cu doua sesiuni server simulate.

## Surse

- https://create.roblox.com/docs/cloud-services/memory-stores — MemoryStoreService overview, cote si bune practici — accesat 2026-09-08
- https://create.roblox.com/docs/cloud-services/memory-stores/per-partition-limits — limite per partitie — accesat 2026-09-08
- https://create.roblox.com/docs/reference/engine/classes/MemoryStoreSortedMap — API SortedMap — accesat 2026-09-08
- https://create.roblox.com/docs/reference/engine/classes/MemoryStoreQueue — API Queue — accesat 2026-09-08
- https://create.roblox.com/docs/reference/engine/classes/MemoryStoreService — API general MemoryStoreService — accesat 2026-09-08
- https://raw.githubusercontent.com/Roblox/creator-docs/main/content/en-us/reference/engine/classes/MessagingService.yaml — sursa oficiala GitHub cu limitele MessagingService — accesat 2026-09-08
- https://create.roblox.com/docs/reference/engine/classes/MessagingService — pagina publica MessagingService (fara cifre in continutul extras) — accesat 2026-09-08
- https://create.roblox.com/docs/cloud-services/cross-server-messaging — ghid de utilizare MessagingService — accesat 2026-09-08
- https://create.roblox.com/docs/cloud-services/data-stores — DataStoreService overview — accesat 2026-09-08
- https://create.roblox.com/docs/cloud-services/data-stores/error-codes-and-limits — limite DataStoreService — accesat 2026-09-08
- https://create.roblox.com/docs/reference/engine/classes/GlobalDataStore — API GetAsync/SetAsync/UpdateAsync — accesat 2026-09-08
- https://create.roblox.com/docs/projects/teleport — TeleportService, reserved servers, TeleportOptions — accesat 2026-09-08
- https://create.roblox.com/docs/production/monetization/private-servers — Private/VIP servers — accesat 2026-09-08
- https://create.roblox.com/docs/projects/update-games — soft shutdown, "Delay server restart" (1-60 min), migrare la update — accesat 2026-09-08
- https://create.roblox.com/docs/reference/engine/classes/DataModel — BindToClose, ServerRestartScheduled, JobId, PrivateServerId — accesat 2026-09-08
- https://create.roblox.com/docs/reference/engine/enums/CloseReason — valorile enum CloseReason — accesat 2026-09-08
- https://create.roblox.com/docs/matchmaking — matchmaking nou 2025, pasii de alocare server — accesat 2026-09-08
- https://create.roblox.com/docs/matchmaking/scoring — semnale implicite si ponderi — accesat 2026-09-08
- https://create.roblox.com/docs/matchmaking/attributes-and-signals — atribute built-in, formula occupancy — accesat 2026-09-08
- https://create.roblox.com/docs/matchmaking/customize-matchmaking — semnale custom, limite (2 semnale, 5 atribute) — accesat 2026-09-08
- https://create.roblox.com/docs/matchmaking/glossary — glosar termeni matchmaking — accesat 2026-09-08
- https://create.roblox.com/docs/reference/engine/classes/Workspace — `GetServerTimeNow()` — accesat 2026-09-08
- https://devforum.roblox.com/t/reverse-engineering-on-how-the-stock-system-in-grow-a-garden-works/3767345 — (secundar, comunitate) pattern determinist pentru stoc global — Artzified, iunie 2025
- https://devforum.roblox.com/t/memorystoreservice-and-distributed-locking/4197296 — (secundar, comunitate) discutie despre alternativa deterministica vs MemoryStore — decembrie 2025
- https://devforum.roblox.com/t/random-global-event-system/3781269 — (secundar, comunitate) leader-election vs deterministic pentru evenimente globale — iunie 2025
- https://devforum.roblox.com — cautare "Max Player Count Increased" (anunt oficial, 700 jucatori/server, beta) — 13 august 2020, referit din nou intr-un thread "Server Player Limit" din 20 ianuarie 2024
- Reddit r/AdoptMeRBX — "Adopt me changed the server size from 48 to 35" — (secundar) ~2025, accesat 2026-09-08
- Bee Swarm Simulator Wiki (Fandom), pagina "Hive" — (secundar) "There are 6 hives in a server" — accesat 2026-09-08
- rpgstash.com, "Adopt Me Trading Hub Guide" — (secundar, blog tert) descrierea Trading Hub ca listari cross-server — 14 august 2026, accesat 2026-09-08
- IGN, "All Weather Events in Grow a Garden" — (secundar) descrie weather events ca "universal experiences shared across servers" — 12 august 2025, accesat 2026-09-08

## Verificare independenta (2026-09-08)

Verificare efectuata independent, cu fetch direct pe sursele primare (create.roblox.com/docs, devforum.roblox.com), nu doar pe baza citatelor din nota originala.

| Afirmatie | Verdict | Valoare corecta | Sursa (URL, data) |
|---|---|---|---|
| MemoryStore: cota memorie = 64 KB + 1.2 KB × utilizatori | CONFIRMAT | Identic cu nota | https://create.roblox.com/docs/cloud-services/memory-stores, verificat 2026-09-09 |
| MemoryStore: cota request units = 1000 + 120 × utilizatori concurenti/minut | CONFIRMAT | Identic cu nota | https://create.roblox.com/docs/cloud-services/memory-stores, verificat 2026-09-09 |
| MemoryStore: max 1.000.000 itemi, max 100 MB total, max 32 KB/item, expirare 0-3.888.000 s | CONFIRMAT | Identic cu nota | https://create.roblox.com/docs/cloud-services/memory-stores, verificat 2026-09-09 |
| MemoryStoreSortedMap si MemoryStoreQueue = o singura partitie; doar MemoryStoreHashMap e distribuit pe mai multe partitii | CONFIRMAT | Identic cu nota (limita reala per-partitie ramane nepublicata, doar exemplu ilustrativ ~50.000 RPM, cum a semnalat deja nota) | https://create.roblox.com/docs/cloud-services/memory-stores/per-partition-limits, verificat 2026-09-09 |
| MemoryStoreService:GetQueue — invisibility timeout implicit 30 secunde | CONFIRMAT | Identic cu nota | https://create.roblox.com/docs/reference/engine/classes/MemoryStoreService, verificat 2026-09-09 |
| MessagingService: mesaj max 1 KB; trimitere 600+240×jucatori/min; primire per topic 40+80×servere/min; primire totala 400+200×servere/min; abonamente 20+8×jucatori; subscribe 240/min; nume topic 1-80 caractere | CONFIRMAT | Identic cu nota — cifrele exista in sursa YAML oficiala; confirmat direct ca pagina publica randata (create.roblox.com/docs/reference/engine/classes/MessagingService) NU contine aceste cifre in continutul extras, exact cum a semnalat nota | https://raw.githubusercontent.com/Roblox/creator-docs/main/content/en-us/reference/engine/classes/MessagingService.yaml, verificat 2026-09-09 |
| DataStore: nume/cheie/scope max 50 caractere; valoare max 4.194.304 bytes (4 MB)/cheie | CONFIRMAT | Identic cu nota | https://create.roblox.com/docs/cloud-services/data-stores/error-codes-and-limits, verificat 2026-09-09 |
| DataStore: storage total = 500 MB + 1 MB × utilizatori unici in istoric | CONFIRMAT | Identic cu nota | https://create.roblox.com/docs/cloud-services/data-stores/error-codes-and-limits, verificat 2026-09-09 |
| DataStore: throughput per cheie — citire 25 MB/min, scriere 4 MB/min | CONFIRMAT | Identic cu nota | https://create.roblox.com/docs/cloud-services/data-stores/error-codes-and-limits, verificat 2026-09-09 |
| DataStore Standard: citire 300+40×CCU, scriere 300+20×CCU, list 300+2×CCU, remove 300+40×CCU (per experienta) | CONFIRMAT, cu clarificare | Ambele seturi de formule de pe pagina sunt reale si simultane, nu contradictorii/invechite: cel "per experienta" (300+40×CCU etc., citat de nota) e un buget global, iar cel "per server" (60+40×numPlayers pentru citire/remove, 60+40×numPlayers pentru scriere Standard) e un buget separat aplicat fiecarui server in parte. Riscul semnalat in nota ("NEVERIFICAT care e cel corect") e rezolvat: nu exista contradictie, sunt doua bugete diferite care se aplica impreuna. | https://create.roblox.com/docs/cloud-services/data-stores/error-codes-and-limits, verificat 2026-09-09 |
| "Delay server restart" (soft shutdown) — jucatorii au intre 1 si 60 minute sa plece voluntar | CONFIRMAT | Identic cu nota | https://create.roblox.com/docs/projects/update-games, verificat 2026-09-09 |
| TeleportToPrivateServer e deprecated; folositi TeleportAsync + TeleportOptions.ReservedServerAccessCode | CONFIRMAT | Identic cu nota — metoda apare cu eticheta "Deprecated" in referinta API TeleportService | https://create.roblox.com/docs/reference/engine/classes/TeleportService, verificat 2026-09-09 |
| Matchmaking 2025: ponderi semnale implicite — Friends=15, Latency=3, Text Chat=3, Occupancy=2, Play History=2, Language=2, Age=1, Voice Chat=1, Device Type=0 | CONFIRMAT | Identic cu nota | https://create.roblox.com/docs/matchmaking/scoring, verificat 2026-09-09 |
| Custom matchmaking: max 2 semnale custom/joc, max 5 atribute per jucator si 5 per server | CONFIRMAT | Identic cu nota | https://create.roblox.com/docs/matchmaking/customize-matchmaking, verificat 2026-09-09 |
| Roblox a introdus in beta servere de pana la 700 jucatori (13 august 2020), fara precizare daca mai e valabil in 2025-2026 | DEPASIT | Exista un anunt oficial ulterior (13 aprilie 2023) care fixeaza maximul **accesibil tuturor dezvoltatorilor la 200 jucatori/server**; 700 ramane un nivel superior/beta, nu un implicit general disponibil. Nota a gasit doar surse din 2020 si 2024 si a ratat clarificarea oficiala din 2023. | https://devforum.roblox.com/t/experience-join-improvements-server-size-join-queues-and-social-slots-reservations/2294621 (13 aprilie 2023), verificat 2026-09-09 |
| Adopt Me a redus dimensiunea serverului public de la 48 la 35 jucatori (~2025) | NEVERIFICABIL | Nicio sursa oficiala Uplift Games/Adopt Me gasita. Cea mai buna dovada secundara: cont X "Adopt Me! News" (neoficial, agregator de comunitate) a postat aceeasi cifra (48→35) in jurul lunii august 2025, ceea ce corespunde cu thread-ul Reddit citat deja in nota — deci exista corroborare intre doua surse secundare independente, dar tot niciuna oficiala. Nivelul de incredere "scazut" deja atribuit de nota ramane corect. | https://x.com/AMNews_Updates/status/1958901772874829825 (cont neoficial, ~aug 2025), verificat 2026-09-09; corroboreaza Reddit r/AdoptMeRBX deja citat in nota |

**Concluzie verificare**: din cele 15 afirmatii-cheie reverificate, 13 sunt CONFIRMATE identic pe surse primare, 1 e DEPASITA (limita de 700 jucatori/server — corectata mai sus in text) si 1 ramane NEVERIFICABILA la nivel de sursa primara (cifrele Adopt Me, deja marcate corect ca nesigure in nota originala). Nu s-a gasit nicio eroare de calcul sau cifra inventata in formulele MemoryStore/MessagingService/DataStore/matchmaking; recomandarile de arhitectura din nota (optiunea (c), "oras-shard persistat") nu sunt afectate de corectia gasita.
