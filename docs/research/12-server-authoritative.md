# Arhitectura server-autoritara si contractele RemoteEvent

## Rezumat executiv

- **Server-ul e sursa unica de adevar, punct.** Documentatia oficiala Roblox spune explicit: *"the server is the single source of truth for the entire game state, and clients are only trusted to report their own inputs."* Pentru Driftwood asta inseamna: clientul NU decide niciodata ce a prins jucatorul, cate resurse are, sau cat timp a trecut offline — doar trimite intentii ("am apasat plaseaza-plasa la pozitia X"), iar serverul calculeaza tot restul. — create.roblox.com/docs/projects/server-authority — confidenta ridicata
- **`RemoteEvent`/`UnreliableRemoteEvent` au un throttle comun de ~500 cereri/secunda per client** — suficient de generos pentru orice interactiune UI normala (plasare plasa, click reparatie), dar trebuie tratat ca plasa de siguranta a motorului, NU ca rate-limit de design; Driftwood trebuie sa impuna propriile cooldown-uri, mult mai stricte (secunde, nu cereri/secunda). — create.roblox.com/docs/reference/engine/classes/UnreliableRemoteEvent — confidenta ridicata
- **`UnreliableRemoteEvent` are plafon de 1000 bytes/eveniment** si nu garanteaza ordine sau livrare — util STRICT pentru efecte vizuale efemere (splash la prindere, particule), NICIODATA pentru orice atinge economia (prinderea unui obiect, banii, inventarul). — create.roblox.com/docs/reference/engine/classes/UnreliableRemoteEvent — confidenta ridicata
- **Simularea determinista a raului nu are nevoie de replicare per-obiect.** Pentru ca `Random.new(seed)` produce aceeasi secventa pe orice masina cu acelasi seed, serverul poate trimite doar seed-ul + parametrii sezonului o data, iar clientul regenereaza local pozitiile obiectelor din rau — traficul de retea scade de la "N update-uri/obiect/tick" la "1 mesaj la schimbare de sezon/val". — create.roblox.com/docs/reference/engine/datatypes/Random — confidenta ridicata (pentru API-ul Random), medie (pentru aplicarea la Driftwood, e recomandare de design, nu regula Roblox)
- **`DataStoreService` are limite formale, publicate, per server**: read/write standard = `60 + numPlayers × 40` cereri/minut (nivel server), plus throughput global de 25 MB/min citire si 4 MB/min scriere per experienta; cheia are maxim 4.194.304 bytes. Salvarea trebuie batch-uita (un singur `UpdateAsync` per jucator, nu unul per camp). — create.roblox.com/docs/cloud-services/data-stores/error-codes-and-limits — confidenta ridicata
- **`BindToClose` da exact 30 de secunde** intregului server (nu per jucator!) sa termine salvarile inainte de shutdown fortat — cu multi jucatori simultan la inchidere, 30s se pot epuiza rapid daca fiecare salvare asteapta un round-trip DataStore secvential; salvarile trebuie paralelizate (coroutine per jucator), nu facute in serie. — create.roblox.com/docs/reference/engine/classes/DataModel (BindToClose) — confidenta ridicata
- **Roblox recomanda oficial un "loading gate"**: `hasLoaded()`, `waitForDataLoadAsync()`, `hasErrored()` verificate O SINGURA DATA la ecranul de incarcare, inainte sa porneasca orice alt sistem — exact modelul cerut de CLAUDE.md pentru Driftwood (nimic nu ruleaza pana datele nu sunt confirmate incarcate). — create.roblox.com/docs/cloud-services/data-stores/player-data-purchasing — confidenta ridicata
- **Validarea remote-urilor trebuie sa acopere si `NaN`/`inf`** — documentatia oficiala avertizeaza explicit ca `NaN < 0` si `NaN > 1000000` sunt AMBELE false, deci verificari naive de tip `if amount > 0` pot fi ocolite; foloseste `math.isfinite()`. Critic pentru orice remote care trimite numere (cantitate materiale, pozitie plasa). — create.roblox.com/docs/scripting/security/client-server-boundary — confidenta ridicata
- **Rate-limiting recomandat oficial: algoritm token-bucket**, cu exemplu concret "5 mesaje / 10 secunde" pentru chat — acelasi model se aplica direct la plasarea plaselor/reparatii in Driftwood. — create.roblox.com/docs/scripting/security/client-server-boundary — confidenta ridicata
- **`ServerStorage` nu se replica deloc catre client** — locul corect pentru orice date/module care nu trebuie sa fie niciodata vizibile clientului (formule de economie, rate de reparatie, tabele de loot rar); `ReplicatedStorage` se replica integral catre toti clientii — deci orice RemoteEvent/RemoteFunction si orice modul PARTAJAT (nu secret) trebuie sa stea acolo. — create.roblox.com/docs/reference/engine/classes/ServerStorage, create.roblox.com/docs/reference/engine/classes/ReplicatedStorage — confidenta ridicata
- **NEVERIFICAT: limite oficiale de memorie/CPU per server Roblox.** Nu exista o pagina oficiala gasita care sa publice un plafon numeric de RAM sau CPU per instanta de server — trateaza asta ca necunoscuta si testeaza in Studio cu Microprofiler + Developer Console, nu presupune un numar.

## Fapte verificate

- Server-ul Roblox e "the ultimate authority for maintaining the game's state" si sincronizeaza clientii prin "replication" — proces care sincronizeaza data model, fizica si chat. — create.roblox.com/docs/projects/client-server — fara data explicita pe pagina — confidenta ridicata
- Latenta tipica de retea intre jucatori si server Roblox: "100-300 milliseconds"; pentru testare in Studio se recomanda un delay minim simulat de 50-150ms in ambele directii. — create.roblox.com/docs/projects/client-server — confidenta ridicata
- Modelul de autoritate server: "the server is the single source of truth for the entire game state, and clients are only trusted to report their own inputs" — previne flyhack/speedhack prin faptul ca server-ul nu accepta niciodata pozitia raportata direct de client ca adevar. — create.roblox.com/docs/projects/server-authority — confidenta ridicata
- Sistemul avansat de "client prediction + rollback" (`BindToSimulation`, `Workspace.AuthorityMode`, `NextGenerationReplication`, `UseFixedSimulation`) e o functionalitate noua orientata spre jocuri cu `BasePart`/fizica 3D — NU se aplica arhitecturii Driftwood (pur ScreenGui, fara `BasePart`-uri simulate fizic). — create.roblox.com/docs/projects/server-authority — confidenta ridicata (ca exista feature-ul), confidenta medie (ca nu se aplica Driftwood — rationament propriu, nu afirmatie explicita a sursei)
- `RemoteEvent:FireServer()` = comunicare unidirectionala, asincrona (nu asteapta raspuns); `RemoteFunction:InvokeServer()` = comunicare bidirectionala, sincrona (clientul/serverul asteapta raspunsul). — create.roblox.com/docs/scripting/events/remote — confidenta ridicata
- `RemoteFunction:InvokeClient()` (server → client) e descurajat oficial: "If the client throws an error, the server throws the error too. If the client disconnects while it's being invoked, InvokeClient() throws an error." — create.roblox.com/docs/scripting/events/remote — confidenta ridicata
- `UnreliableRemoteEvent` + `RemoteEvent` impart acelasi throttle: "a limit of approximately 500 requests per second, per client". — create.roblox.com/docs/reference/engine/classes/UnreliableRemoteEvent — confidenta ridicata
- `UnreliableRemoteEvent`: "Events with payloads larger than 1000 bytes are dropped"; nu garanteaza ordine ("It is not guaranteed that the order of events will match the order of FireClient() or FireAllClients() calls") si nu garanteaza livrare (poate fi pierdut din cauza pierderii de pachete sau pentru performanta motorului). Recomandat pentru "ephemeral events... or for replicating continuously changing data". — create.roblox.com/docs/reference/engine/classes/UnreliableRemoteEvent — confidenta ridicata
- Argumentele trimise prin Remote-uri NU pot contine functii (devin `nil`), pierd metatabelele, iar instantele nereplicate catre destinatar (ex. ceva din `ServerStorage`) devin `nil`; tabelele trebuie sa fie STRICT dictionar sau STRICT array numeric, nu mixte. — create.roblox.com/docs/scripting/events/remote — confidenta ridicata
- `ServerStorage`: "Not Replicated" — continutul nu ajunge niciodata la client. — create.roblox.com/docs/reference/engine/classes/ServerStorage — confidenta ridicata
- `ReplicatedStorage`: container "replicated to all clients"; gazduieste tipic `ModuleScript`, `RemoteFunction`, `RemoteEvent` folosite si de server si de client; modificarile facute de client NU se propaga inapoi la server (pot desincroniza). — create.roblox.com/docs/reference/engine/classes/ReplicatedStorage — confidenta ridicata
- `ReplicatedFirst`: se replica la client INAINTEA oricarui alt container, dar nu se replica inapoi la server; folosit tipic pentru `LocalScript`-uri si ecrane de incarcare; `ReplicatedFirst:RemoveDefaultLoadingScreen()` elimina loading screen-ul default Roblox. — create.roblox.com/docs/reference/engine/classes/ReplicatedFirst — confidenta ridicata
- Nume de atribut (`SetAttribute`/`GetAttribute`): limitat la "100 characters or less", caractere alfanumerice + `.`, `-`, `/`, `_`; nu poate incepe cu "RBX" (rezervat motorului) din scripturi non-core. Tipuri suportate: string, boolean, number, Vector2/3, UDim/UDim2, BrickColor, Color3, CFrame, NumberSequence, ColorSequence, NumberRange, Rect, Font. — GitHub Roblox/creator-docs, Instance.yaml — confidenta ridicata
- Atributele se replica automat client-server "so that clients can access them immediately" si sunt salvate cu place-ul/asset-ul. NEVERIFICAT: limita totala de bytes per instanta pentru suma atributelor (nu am gasit un numar oficial explicit). — create.roblox.com/docs/studio/properties — confidenta medie
- `DataStoreService.UpdateAsync` "Reads the current key value from the server that last updated it before making any changes" si "Counts against both the read and write limits" (spre deosebire de `SetAsync`, care conteaza doar la scriere si poate crea inconsistenta cand doua servere scriu simultan aceeasi cheie). Callback-ul `UpdateAsync` NU are voie sa faca yield (`task.wait()` etc. interzis). — create.roblox.com/docs/scripting/data/data-stores — confidenta ridicata
- Limite oficiale `DataStoreService` (per experienta, formule cu `numPlayers`/`concurrentUsers`): vezi tabelul complet din sectiunea Detalii. Nume cheie/store/scope: maxim 50 caractere fiecare; valoare per cheie: maxim 4.194.304 bytes (4MB); coada de request-uri per tip: maxim 30; throughput global: 25MB/min citire, 4MB/min scriere. — create.roblox.com/docs/cloud-services/data-stores/error-codes-and-limits — confidenta ridicata
- `DataModel:BindToClose()`: serverul asteapta 30 de secunde ca functiile legate sa termine, apoi se inchide fortat oricum; recomandat explicit pentru a salva date nesalvate la `DataStoreService` inainte de shutdown neasteptat. — create.roblox.com/docs/reference/engine/classes/DataModel — confidenta ridicata
- Ghidul oficial de implementare a datelor de jucator recomanda un "loading gate": verifici starea de incarcare O SINGURA DATA la ecranul de loading (`hasLoaded()`, `waitForDataLoadAsync()`, `hasErrored()`), ca sa NU trebuiasca sa verifici erori de incarcare inainte de fiecare interactiune ulterioara. — create.roblox.com/docs/cloud-services/data-stores/player-data-purchasing — confidenta ridicata
- Retry-urile naive (buclă simplă) NU sunt potrivite pentru `DataStoreService` "because it does not guarantee the order in which requests are made"; pattern-ul recomandat de Roblox e un wrapper cu retry-uri secventiale garantate per cheie si exponential backoff configurabil — dar codul de referinta e explicit marcat "Don't use this code in your game as-is without extensive testing". — create.roblox.com/docs/cloud-services/data-stores/player-data-purchasing — confidenta ridicata (ca recomandare), risc explicit mentionat de sursa insasi
- Validarea la granita client-server trebuie sa acopere 3 straturi: (1) permisiuni/context (distanta, stare "alive"), (2) tip si structura (respinge payload-uri uriase sau tabele care mimeaza referinte de Instance), (3) valoare (interval numeric plauzibil, respinge `NaN`/`inf` prin `math.isfinite()`). — create.roblox.com/docs/scripting/security/client-server-boundary — confidenta ridicata
- Rate-limiting recomandat oficial: algoritm token-bucket, permite burst-uri controlate, exemplu concret "5 messages per 10 seconds" pentru chat. — create.roblox.com/docs/scripting/security/client-server-boundary — confidenta ridicata
- `ProximityPrompt`, `ClickDetector`, `DragDetector` pot fi declansate direct de exploatatori prin apeluri remote, ocolind verificarile de distanta/stare — trebuie validate pe server la fel ca orice `RemoteEvent`. — create.roblox.com/docs/scripting/security/client-server-boundary — confidenta ridicata
- Filozofia oficiala de design defensiv: "design your game so that cheating either cannot occur or provides no meaningful advantage" — proiecteaza mecanica sa fie imuna, nu doar sa detectezi si sa pedepsesti dupa fapt. Exemplu relevant pentru Driftwood: validarea tranzactiilor (donatii la atelier) trebuie sa verifice inventarul curent pe server, cu cooldown, pentru a preveni exploit-uri de duplicare. — create.roblox.com/docs/scripting/security/defensive-design — confidenta ridicata
- Detectia server-side recomandata: euristici (timp minim plauzibil de completare, rata de acumulare peste maximul legitim, cadenta de actiuni "robotica"), "honeypot" RemoteEvents (nefolosite niciodata de client-ul legitim — orice trafic pe ele = dovada de exploatare), si o scara de consecinte (logging silentios → mitigare silentioasa → restrictii temporare → kick/ban vizibil), cu intarziere deliberata a consecintelor vizibile ca sa nu inveti exploatatorul ce a declansat detectia. — create.roblox.com/docs/scripting/security/server-side-detection — confidenta ridicata
- `Random.new(seed)`: seed in intervalul `[-9007199254740991, 9007199254740991]`, rotunjit la intreg; fara seed, foloseste o sursa interna de entropie. `Random:NextInteger(min, max)` si `Random:NextNumber([min, max])` sunt deterministe pentru acelasi seed — baza pentru simularea reproductibila a raului. — create.roblox.com/docs/reference/engine/datatypes/Random — confidenta ridicata
- `MemoryStoreService`: stocare in-memory, rapida, ne-durabila, distribuita pe toate serverele unei experiente ("accessible from all servers"); potrivita pentru date efemere (cozi de matchmaking, cache). Limite: memorie = `64 KB + 1.2 KB × numarUtilizatori`; request-uri = `1000 + 120 × numarUtilizatoriConcurenti` unitati/minut; maxim 1.000.000 de elemente per structura, maxim 100MB per structura; TTL implicit 45 zile. — create.roblox.com/docs/cloud-services/memory-stores — confidenta ridicata
- Ownership de fizica (`BasePart:SetNetworkOwner()`): implicit serverul detine toate partile; motorul poate transfera automat ownership catre client pe baza proximitatii personajului; "Roblox cannot verify physics calculations when a client has ownership over a BasePart" — clientii cu ownership pot trimite date false (teleportare, trecere prin pereti). NEVERIFICAT relevanta directa pentru Driftwood (fara `BasePart`-uri simulate fizic in arhitectura GUI-only), dar confirma principiul general: orice calcul lasat clientului e falsificabil. — create.roblox.com/docs/physics/network-ownership — confidenta ridicata (ca fapt Roblox), medie (aplicabilitate la Driftwood)

## Detalii

### 1. RemoteEvent vs RemoteFunction vs UnreliableRemoteEvent — cand folosesti fiecare

| Tip | Directie | Blocant? | Ordine garantata | Livrare garantata | Plafon payload | Cazul Driftwood |
|---|---|---|---|---|---|---|
| `RemoteEvent` | oricare (client↔server) | Nu (asincron) | Da | Da | fara plafon documentat explicit (dar cererile mici) | plaseaza plasa, colecteaza plasa, reparatie, donatie atelier — orice atinge economia |
| `RemoteFunction` | oricare, dar cu yield | Da (asteapta raspuns) | N/A (1 request-1 response) | Da | idem | interogari sincrone rare, ex. "da-mi starea curenta a inventarului la deschiderea UI-ului" — evita pentru orice ce poate fi inlocuit cu un `RemoteEvent` + raspuns separat |
| `UnreliableRemoteEvent` | oricare | Nu | **Nu** | **Nu** | **1000 bytes** — peste, evenimentul e aruncat | strict cosmetic: stropi de apa la prindere, particule de reparatie, pozitia altor jucatori pe ecran daca ai nevoie de smoothing vizual (NU starea economica) |

Reguli de decizie pentru Driftwood:
- Orice remote care schimba bani/inventar/proprietate → **`RemoteEvent`**, validat integral pe server, niciodata `RemoteFunction:InvokeClient()` (server nu trebuie sa astepte raspunsul unui client, poate bloca/crapa daca clientul se deconecteaza).
- `RemoteFunction:InvokeServer()` e acceptabil pentru citiri simple, dar in general prefera pattern-ul "cere prin RemoteEvent, primesti raspunsul tot printr-un RemoteEvent separat" — evita yield-ul pe server per client.
- `UnreliableRemoteEvent` NU e potrivit pentru "obiectul X a fost prins" (poate fi pierdut = jucator pierde vizual confirmarea, desi serverul stie ca l-a prins) — foloseste `RemoteEvent` obisnuit pentru evenimentul de prindere, si rezerva `UnreliableRemoteEvent` doar pentru straturi pur vizuale care se pot pierde fara consecinte de joc (ex: un puls de "unda" pe apa cand un obiect trece).

### 2. Throttle-uri si plafoane de retea — tabel de referinta

| Limita | Valoare | Sursa |
|---|---|---|
| Throttle RemoteEvent/UnreliableRemoteEvent | ~500 cereri/secunda per client | create.roblox.com/docs/reference/engine/classes/UnreliableRemoteEvent |
| Plafon payload UnreliableRemoteEvent | 1000 bytes/eveniment | idem |
| Latenta tipica retea Roblox | 100-300ms | create.roblox.com/docs/projects/client-server |
| Delay simulat recomandat in testare | 50-150ms in ambele directii | idem |
| BindToClose — timp total inainte de shutdown fortat | 30 secunde (pentru TOT serverul, nu per jucator) | create.roblox.com/docs/reference/engine/classes/DataModel |

500 cereri/secunda per client e o limita a MOTORULUI, nu o limita de design — daca Driftwood se bazeaza pe acest plafon ca "protectie", un exploit poate trimite pana la aproape 500 apeluri/secunda inainte sa fie taiat de Roblox. Cooldown-urile proprii (ex. "plaseaza-plasa" o data la 2 secunde, validat cu timestamp pe server) trebuie sa fie cu ordine de marime mai stricte decat throttle-ul motorului.

### 3. DataStoreService — limite complete (per experienta)

| Tip request | Formula server (implicit) | Formula globala experienta |
|---|---|---|
| Standard Read/Write | `60 + numPlayers × 40` cereri/min | `300 + concurrentUsers × 40` (read) / `300 + concurrentUsers × 20` (write) |
| Standard List/Remove | `5 + numPlayers × 2` (list) | `300 + concurrentUsers × 2` (list) / `300 + concurrentUsers × 40` (remove) |
| Ordered Read | `60 + numPlayers × 40` | `300 + concurrentUsers × 40` |
| Ordered Write | `30 + numPlayers × 5` | `300 + concurrentUsers × 20` |
| Ordered List | `5 + numPlayers × 2` | `300 + concurrentUsers × 2` |

Limite de dimensiune si structura:
- Nume key/store/scope: maxim **50 caractere** fiecare
- Valoare per cheie: maxim **4.194.304 bytes** (4 MB)
- Coada de request-uri per tip: maxim **30**
- Throughput global per experienta: **25 MB/min citire, 4 MB/min scriere**

Sursa: create.roblox.com/docs/cloud-services/data-stores/error-codes-and-limits — confidenta ridicata.

**Implicatie directa pentru Driftwood:** cu un singur jucator per server-slot (economie personala pe teren + oras comun), rata de `60 + numPlayers × 40` e generoasa pentru salvare la 2 minute (cerinta din CLAUDE.md) — dar NU salva camp cu camp (inventar separat de progres separat de atelier); batch-uieste tot profilul jucatorului intr-un singur `UpdateAsync` per ciclu de salvare, ca sa nu epuizezi bugetul de request-uri odata cu cresterea numarului de sisteme (inventar, index reparatii, atelier, sezon).

### 4. Simularea raului — replicare determinista cu seed, nu snapshot per obiect

Abordarea clasica de netcode (server trimite pozitia fiecarui obiect in fiecare tick) ar insemna, pentru un rau cu zeci de obiecte plutitoare, trafic proportional cu numarul de obiecte × frecventa tick-ului — inutil de scump pentru Driftwood, unde traiectoria fiecarui obiect e complet predictibila (viteza + directie + timp de start).

Model recomandat (design propriu, bazat pe `Random.new(seed)` documentat de Roblox):

```lua
-- SERVER: RiverSimulationService.luau
-- Un singur seed pe sesiune de sezon, nu unul per obiect
local seasonSeed = os.time() -- sau un id de sezon stabil, generat o data la inceputul sezonului
local rng = Random.new(seasonSeed)

-- Server-ul CALCULEAZA (nu doar genereaza vizual) fiecare obiect care va aparea:
-- {id, spawnTick, lane, itemType, baseSpeed}, folosind rng in ordine determinista
-- Aceste date sunt AUTORITARE: serverul stie exact ce obiect trece pe unde, la ce tick,
-- fara sa fi trimis niciun mesaj — pentru ca poate re-deriva aceeasi secventa oricand.

-- La connect, server-ul trimite O SINGURA DATA:
riverConfigRemote:FireClient(player, {
    seed = seasonSeed,
    seasonStartTick = seasonStartTick,
    flowSpeed = currentSeason.flowSpeed,
    spawnTable = currentSeason.spawnWeights, -- date mici, statice per sezon
})
```

```lua
-- CLIENT: RiverRenderController.luau
-- Clientul regenereaza ACEEASI secventa local, doar pentru RANDARE (nu pentru autoritate)
local rng = Random.new(receivedSeed)
-- ... deriva pozitiile obiectelor vizibile in fereastra curenta, identic cu ce calculeaza serverul

-- Cand jucatorul interactioneaza (plaseaza plasa, prinde ceva), clientul NU decide rezultatul —
-- trimite doar intentia + id-ul obiectului tinta; serverul verifica daca id-ul + tick-ul
-- corespund cu ce a calculat el insusi (acelasi seed → acelasi rezultat) inainte sa acorde orice.
```

Avantaje verificate din documentatie:
- `Random.new(seed)` e determinist per seed — confirmat oficial. Server si client, cu acelasi seed, produc aceeasi secventa de `NextNumber`/`NextInteger`.
- Traficul de retea pentru rau scade la un singur mesaj de configurare per sezon (+ eventual un "heartbeat" de sincronizare la reconectare), nu un stream continuu.

Riscuri de design (NEVERIFICAT ca fapt Roblox, e rationament propriu):
- Daca Luau schimba implementarea generatorului `Random` intre versiuni de motor, secventele client/server ar putea diverge — NEVERIFICAT daca Roblox garanteaza stabilitate cross-versiune a algoritmului; de testat explicit (genereaza aceeasi secventa pe doua sesiuni Studio la date diferite, cu acelasi seed).
- Deriva de clock: daca clientul calculeaza "ce tick suntem acum" din ceasul lui local in loc de un tick primit de la server, desincronizarea se acumuleaza — serverul trebuie sa trimita periodic (nu doar la join) un "ancora" de sincronizare (tick curent + timestamp server), nu doar seed-ul o singura data.
- Server-ul ramane AUTORITAR asupra rezultatului prinderii — regenerarea pe client e doar pentru randare fluida; validarea finala ("obiectul cu id X era intr-adevar la pozitia Y la tick Z, in raza plasei jucatorului") se face independent, recalculat pe server, niciodata acceptand coordonatele trimise de client ca atare.

### 5. Snapshot vs delta — recomandare pentru Driftwood

Nu exista o pagina Roblox care sa prescrie "snapshot vs delta" ca pattern numit — e terminologie generica de netcode, aplicata aici. Recomandare:

- **State-ul lent-schimbator** (bani, inventar, nivel index reparatii, progres atelier oras) → **delta explicit prin `RemoteEvent`**, trimis DOAR cand se schimba, cu payload mic (`{type="currencyChanged", newAmount=1234}`), nu re-trimis la fiecare tick.
- **State-ul rapid-schimbator dar predictibil** (pozitiile obiectelor din rau) → **deloc replicat ca date brute**; derivat din seed + tick, cum e descris mai sus.
- **State global de sezon/eveniment** (viteza raului, tip inundatie activa) → **un singur `RemoteEvent` la schimbare de faza**, nu poll continuu.
- Nu exista nevoie de un "full snapshot" periodic gen shooter-e 3D (unde pozitiile fizice trebuie resincronizate des) — pentru ca Driftwood nu are `BasePart`-uri fizice replicate de motor; toata replicarea e explicita, prin remote-uri proprii, deci riscul de desincronizare al motorului (relevant pt jocuri 3D cu fizica) nu se aplica in acelasi fel. Ramane totusi riscul de desincronizare LOGICA (client si server calculeaza diferit din seed) — de acoperit cu re-ancorare periodica (ex. la fiecare 60s, server retrimite tick-ul curent).

### 6. Attributes/ValueObjects vs Remotes pentru state

- **`Attributes`** (`Instance:SetAttribute`/`GetAttribute`): se replica automat catre client cand instanta e intr-un container replicat (`ReplicatedStorage`/`Workspace`), fara remote explicit. Nume limitat la 100 caractere. Nu exista o limita oficiala GASITA pentru dimensiunea totala per instanta — NEVERIFICAT, trateaza cu prudenta (nu stoca structuri mari, gen tot inventarul, ca atribute).
- **`ValueObject`-uri** (`IntValue`, `StringValue` etc.) sunt un pattern mai vechi, pre-Attributes; documentatia actuala Roblox nu le mai promoveaza activ (nu au aparut in niciuna din paginile cercetate ca recomandare curenta) — Attributes sunt inlocuitorul modern, mai usor de folosit din Studio si din cod.
- **Recomandare Driftwood:** Attributes pentru STARE PUBLICA MICA si non-secreta care beneficiaza de replicare automata + editare vizuala in Studio (ex: `player.Character` n-are sens aici, dar un `Folder` per teren de jucator cu attribute `workshopSlotsUsed`, `currentSeasonId` ar functiona). Pentru orice date SENSIBILE la economie (bani, inventar complet, retete de reparatie descoperite) → NU attributes pe instante vizibile clientului; tine starea reala intr-un tabel Lua server-side (in `ServerStorage`/ServerScriptService, nereplicat) si trimite catre client doar prin `RemoteEvent`-uri explicite, cu payload minim, DUPA validare. Attributes replicate automat = orice le vede clientul le poate citi (nu le poate scrie inapoi ca sa conteze, dar tot expun informatie care ar trebui ascunsa, ex. loot rar disponibil).

### 7. ReplicatedStorage vs ServerStorage vs ReplicatedFirst — layout recomandat

| Container | Se replica la client? | Continut Driftwood |
|---|---|---|
| `ServerScriptService` | Nu (scripturi server) | Toate serviciile server (`RiverSimulationService`, `EconomyService`, `WorkshopService`, `DataService`) |
| `ServerStorage` | **Nu** | Tabele/module cu formule secrete: rate de reparatie reale, tabele de loot ponderat, praguri anti-cheat, `ServerConfig` cu valori pe care nu vrei sa le vada clientul explicit |
| `ReplicatedStorage` | **Da, integral** | `RemoteEvent`/`RemoteFunction`-urile (folder `Remotes`), module PARTAJATE (constante non-secrete: dimensiuni ecran logice, id-uri de item-uri, `Shared/ItemDefinitions` — nume, sprite id, DAR nu si pretul/raritatea daca vrei sa le ascunzi), `Packages` (librarii third-party) |
| `ReplicatedFirst` | Da, PRIMUL (inainte de tot restul) | `LocalScript` pentru ecranul de incarcare custom + `ReplicatedFirst:RemoveDefaultLoadingScreen()`, orice modul de care ecranul de loading are nevoie inainte ca restul jocului sa existe |
| `StarterPlayerScripts` | Se cloneaza in `PlayerGui`/`Backpack` la fiecare client | Controllere client (`RiverRenderController`, `NetPlacementController`, `UIController`) |

### 8. Validarea fiecarui remote — checklist concret pentru Driftwood

Pentru fiecare `RemoteEvent` care schimba stare (ex. `PlaceNetRemote`, `CollectCatchRemote`, `RepairItemRemote`, `DonateToWorkshopRemote`):

1. **Verificare de tip** — fiecare argument primit e exact tipul asteptat (`typeof(arg) == "number"`), nu doar "trece testul" din intamplare. Respinge orice altceva imediat.
2. **Verificare de plauzibilitate numerica** — `math.isfinite(arg)` pentru orice numar (blocheaza `NaN`/`inf`), plus interval logic (ex. `slotIndex` intre 1 si numarul real de sloturi din atelierul jucatorului respectiv, nu un numar arbitrar).
3. **Verificare de ownership** — jucatorul care a trimis request-ul e intr-adevar proprietarul obiectului/terenului la care se refera (id-ul terenului/plasei apartine `player.UserId`-ului care a apelat remote-ul, verificat din starea server, NU din ce trimite clientul).
4. **Cooldown pe server, cu timestamp server** — nu te baza pe "clientul nu a trimis de curand"; tine `lastActionTick[player.UserId]` server-side si respinge orice apel mai devreme de pragul minim, INDIFERENT de ce spune clientul.
5. **Verificare de stare curenta** — ex. la `CollectCatchRemote`, verifica pe server ca obiectul cu id-ul dat chiar exista inca necolectat, in raza plasei jucatorului, la tick-ul curent calculat server-side din seed — nu accepta coordonatele trimise de client ca adevar.
6. **Idempotenta / anti-duplicare** — pentru actiuni cu efect ireversibil (donatie la atelier, consumare material la reparatie), foloseste un pattern de tip "verifica + rezerva + confirma" server-side, nu "verifica apoi scrie" in doi pasi separati care pot fi rulati de doua ori in paralel (race condition clasica de exploit).

```lua
-- Exemplu de schelet de validare (design propriu, urmand principiile din
-- create.roblox.com/docs/scripting/security/client-server-boundary si defensive-design)
local COOLDOWN_SECONDS = 1.5
local lastPlaceTick: {[number]: number} = {}

placeNetRemote.OnServerEvent:Connect(function(player, laneIndex)
    -- 1. tip
    if typeof(laneIndex) ~= "number" then return end
    -- 2. plauzibilitate
    if not (math.isfinite(laneIndex) and laneIndex == math.floor(laneIndex)) then return end
    if laneIndex < 1 or laneIndex > MAX_LANES then return end
    -- 3. ownership -- laneIndex apartine terenului jucatorului? (verificat din starea server)
    local plot = PlotService:GetPlotForPlayer(player)
    if not plot or not plot:OwnsLane(laneIndex) then return end
    -- 4. cooldown server-side
    local now = os.clock()
    if lastPlaceTick[player.UserId] and now - lastPlaceTick[player.UserId] < COOLDOWN_SECONDS then
        return
    end
    lastPlaceTick[player.UserId] = now
    -- 5. verificare de stare curenta (ex. slotul nu e deja ocupat)
    if plot:IsLaneOccupied(laneIndex) then return end
    -- abia acum: efectul real, autoritar
    plot:PlaceNet(laneIndex)
end)
```

### 9. Rate limiting per jucator — pattern token-bucket

Documentatia recomanda explicit token-bucket, cu exemplul "5 mesaje/10 secunde" pentru chat. Pentru Driftwood, fiecare tip de actiune (plasare plasa, colectare, reparatie, donatie) ar trebui sa aiba propriul bucket, dimensionat dupa cat de des un jucator LEGITIM ar declansa acea actiune:

| Actiune | Cooldown minim recomandat (design propriu, de calibrat cu testare) |
|---|---|
| Plaseaza/muta plasa | 1-2s (previne spam-click, dar nu incetineste jocul legitim) |
| Colecteaza obiect prins | 0.3-0.5s (poate fi actiune rapida, repetata) |
| Porneste reparatie | 1s |
| Doneaza la atelier | 1-2s |

Aceste cifre NU vin din documentatie Roblox — sunt puncte de plecare care trebuie calibrate empiric in Studio/playtesting, nu adevaruri gasite.

### 10. Latenta la plasarea plaselor — optimistic UI + confirmare server

Cu latenta tipica de 100-300ms (confirmat oficial), un click care asteapta round-trip complet inainte sa arate feedback ar simti "lag" perceptibil. Pattern recomandat (design propriu, aplicand principiile oficiale de validare server + UX standard, NU un feature Roblox numit):

1. Clientul, la click, arata IMEDIAT plasa in stare "pending" (semi-transparenta / cu un indicator de asteptare) — pur vizual, ZERO efect asupra economiei.
2. Clientul trimite `PlaceNetRemote:FireServer(laneIndex)`.
3. Serverul valideaza (checklist de mai sus) si, daca accepta, raspunde cu un `RemoteEvent` de confirmare (`NetPlacedConfirmedRemote:FireClient(player, {laneIndex, netId})`) care schimba plasa din "pending" in "activa".
4. Daca serverul respinge (cooldown, slot ocupat, etc.), trimite `NetPlacementRejectedRemote:FireClient(player, {laneIndex, reason})` — clientul scoate starea "pending" si, optional, arata un motiv scurt.
5. **Niciodata** nu presupune clientul ca plasarea a reusit doar pentru ca a trimis cererea — starea "activa" reala vine STRICT din confirmarea serverului.

### 11. Join/leave si gate-ul de incarcare a datelor

Pattern recomandat oficial (parafrazat, nu cod Roblox verbatim, dar principiul e documentat): la `PlayerAdded`, porneste incarcarea datelor din `DataStoreService`; NU permite interactiune cu niciun sistem de gameplay pana `hasLoaded()`-echivalentul propriu nu confirma succesul. Daca incarcarea esueaza (`hasErrored()`-echivalent), NU lasa jucatorul sa joace cu date goale (ar insemna suprascrierea progresului real la urmatoarea salvare) — arata un ecran de eroare/retry, nu un fallback silentios la date default.

```lua
-- Schelet: DataService.luau (server)
Players.PlayerAdded:Connect(function(player)
    local profile = DataService:LoadProfileAsync(player) -- gate: yield pana la succes/esec
    if not profile then
        -- esec de incarcare: NU lasa jucatorul sa joace cu date goale
        player:Kick("Nu am putut incarca datele tale. Reincearca.")
        return
    end
    PlayerProfiles[player.UserId] = profile
    readyRemote:FireClient(player) -- abia acum clientul poate porni UI-ul de joc
end)

Players.PlayerRemoving:Connect(function(player)
    local profile = PlayerProfiles[player.UserId]
    if profile then
        DataService:SaveProfileAsync(player.UserId, profile) -- salvare la iesire (cerinta CLAUDE.md)
        PlayerProfiles[player.UserId] = nil
    end
end)

game:BindToClose(function()
    -- 30 de secunde TOTAL pentru tot serverul (nu per jucator) — paralelizeaza salvarile
    local threads = {}
    for userId, profile in PlayerProfiles do
        table.insert(threads, task.spawn(function()
            DataService:SaveProfileAsync(userId, profile)
        end))
    end
    -- asteapta toate thread-urile sau cel putin un timeout intern < 30s
end)
```

Salvarea periodica la 2 minute (cerinta CLAUDE.md) se implementeaza cu un `task.spawn` per jucator care ruleaza pe bucla proprie, NU cu un singur loop global care salveaza toti jucatorii secvential (ar bloca/intarzia inutil la multi jucatori si ar consuma bugetul `DataStoreService` in rafale in loc de uniform).

### 12. Server tick, CPU si memorie — ce e confirmat si ce nu

- Frame budget: 60 FPS = 16.67ms/frame, 30 FPS = 33.33ms/frame — sunt ratele de referinta afisate in Microprofiler pentru consistenta cadrelor, NU un "server tick rate" oficial documentat separat. — create.roblox.com/docs/studio/microprofiler — confidenta ridicata (pentru cifre), medie (ca "tick rate al serverului" — motorul nu documenteaza explicit un Hz fix garantat pentru server sub sarcina)
- Task scheduler-ul ruleaza `Heartbeat`/`PreSimulation`/`PostSimulation` in fiecare "frame" al serverului, coordonand input, fizica, si reluarea `task.wait()`-urilor — dar pagina oficiala NU specifica un Hz garantat sau un buget CPU per tick. — create.roblox.com/docs/performance-optimization/microprofiler/task-scheduler — confidenta ridicata (ce face), NEVERIFICAT (Hz fix / buget CPU)
- **NEVERIFICAT explicit:** plafon de memorie RAM sau CPU per instanta de server Roblox. Nu am gasit o pagina create.roblox.com care sa publice un numar (ex. "X GB RAM per server"). Comunitatea vorbeste adesea informal despre limite in jur de cativa GB, dar asta NU a fost confirmat dintr-o sursa primara in aceasta cercetare — trateaza ca necunoscut si testeaza direct in Studio (Developer Console → Server Stats → Memory) pe un prototip cu numarul realist de obiecte simultane din rau.
- Recomandare practica pentru Driftwood: profileaza CU Microprofiler (`Ctrl+F6` deschide, conform documentatiei oficiale mentionate in pagina microprofiler) simularea raului cu numarul maxim planificat de obiecte simultane pe ecran, INAINTE de a presupune orice buget.

## Recomandari concrete pentru Driftwood

1. **Foloseste EXCLUSIV `RemoteEvent` pentru orice atinge economia** (prindere, bani, inventar, reparatie, donatie). Rationament: `RemoteFunction` blocheaza serverul asteptand clientul (risc de crash/hang la deconectare), iar `UnreliableRemoteEvent` poate pierde/reordona — inacceptabil cand rezultatul trebuie sa fie exact.
2. **Rezerva `UnreliableRemoteEvent` strict pentru cosmetic** (particule, unde vizuale pe apa) — niciodata pentru ceva ce clientul trebuie sa vada garantat.
3. **Nu replica obiectele raului individual.** Trimite un singur mesaj de configurare de sezon (`seed`, `flowSpeed`, `spawnWeights`) la connect si la fiecare schimbare de sezon; clientul deriva pozitiile local din `Random.new(seed)`. Reduce traficul de la "per-obiect-per-tick" la "per-schimbare-de-sezon".
4. **Re-ancoreaza periodic tick-ul** (ex. la fiecare 60s, un `RemoteEvent` mic cu tick-ul curent server) ca sa previi deriva de clock intre client si server pe sesiuni lungi — mai ales relevant cu acumulare offline de pana la 8 ore (cerinta CLAUDE.md), unde clientul reconectat trebuie resincronizat rapid si corect.
5. **Structureaza codul in 4 zone clare**: `ServerScriptService/Services/*` (autoritate, validare, DataStore), `ServerStorage/Config` (formule/tabele secrete), `ReplicatedStorage/Remotes` + `ReplicatedStorage/Shared` (contracte + module partajate non-secrete), `StarterPlayerScripts/Controllers` (randare, input, UI). Vezi layout complet in sectiunea 13.
6. **Valideaza fiecare remote cu checklist-ul din sectiunea 8** — tip, plauzibilitate (`math.isfinite`), ownership, cooldown server-side cu timestamp server, stare curenta, anti-duplicare. Nu sari niciun pas, nici pentru remote-uri care par "inofensive" (ex. muta plasa).
7. **Cooldown-urile proprii trebuie sa fie cu ordine de marime mai stricte decat throttle-ul motorului** (~500/s) — motorul e plasa de siguranta finala, nu design de rate-limit.
8. **Optimistic UI la plasarea plaselor**: arata "pending" imediat, confirma/respinge explicit prin remote separat de la server — nu lasa jucatorul sa astepte 100-300ms fara feedback vizual, dar nu acorda niciodata efectul real fara confirmare server.
9. **Gate strict de incarcare la join**: nimic din UI de gameplay nu porneste inainte ca serverul sa confirme (`readyRemote`) ca profilul a fost incarcat cu succes din `DataStoreService`; la esec, nu lasa jucatorul sa joace cu date goale — kick cu mesaj, nu fallback silentios.
10. **Salvare paralelizata, nu secventiala**, in `BindToClose` — cu bugetul fix de 30 de secunde per server (nu per jucator), o bucla `for` secventiala peste toti jucatorii risca sa nu termine la sale server-uri aglomerate.
11. **Un singur `UpdateAsync` per profil de jucator per ciclu de salvare** (nu cate unul per sub-sistem: inventar, index reparatii, atelier) — respecta bugetul `DataStoreService` (`60 + numPlayers × 40`/min) si evita conditii de cursa intre salvari partiale.
12. **Attributes doar pentru stare mica, publica, ne-sensibila** (ex. numar sloturi ocupate in atelier, vizibil oricum pe ecran altor jucatori conform mecanicii de "obligatie sociala" din CLAUDE.md); starea sensibila a economiei ramane in tabele Lua server-side, expusa clientului STRICT prin remote-uri, cu payload minim.
13. **Profileaza in Studio cu Microprofiler INAINTE de a presupune un buget de CPU/memorie per server** — nu exista un numar oficial public gasit; testeaza cu numarul realist maxim de obiecte simultane in rau si numarul planificat de jucatori simultani per server.

## Riscuri si necunoscute

- **Plafon oficial de memorie/CPU per server Roblox: NEVERIFICAT.** Niciuna dintre paginile oficiale gasite (performance-optimization, microprofiler, task-scheduler) nu publica un numar. Risc: planificarea capacitatii (cati jucatori simultani per server, cate obiecte in rau) se face fara un plafon confirmat — trebuie descoperit empiric in Studio, nu presupus dintr-o sursa terta.
- **Sistemul nou "server authority" cu `BindToSimulation`/`AuthorityMode`/`NextGenerationReplication`** pare orientat spre jocuri cu fizica 3D (`BasePart`) si client-side prediction/rollback — posibil sa nu se aplice deloc unei arhitecturi GUI-only ca Driftwood, dar merita reverificat daca Roblox extinde acest sistem si la alte tipuri de state (ar putea deveni relevant daca se decide vreodata migrarea partiala catre 2.5D mentionata in CLAUDE.md).
- **Limita totala de bytes per instanta pentru suma atributelor**: nu a fost gasita explicit. Daca exista o limita practica nedocumentata, un design care pune prea multe attribute pe un singur `Folder` per teren de jucator ar putea esua silentios sau trunchia date — de testat direct in Studio cu un numar mare de attribute inainte de a te baza pe ele pentru stare compusa.
- **Stabilitatea pe termen lung a algoritmului `Random`**: NEVERIFICAT daca Roblox garanteaza ca `Random.new(seed)` produce EXACT aceeasi secventa intre versiuni de motor/patch-uri viitoare. Daca nu, arhitectura "seed-based river simulation" ar putea desincroniza client/server dupa un update Roblox — riscul se atenueaza daca server-ul ramane singura sursa AUTORITARA de adevar (asa cum e recomandat oricum) si clientul doar randeaza, dar merita un test de regresie dupa fiecare update major de motor.
- **`DataStoreService` best-practices oficiale recomanda explicit un wrapper cu retry si backoff, dar codul de referinta al Roblox e marcat "don't use as-is without extensive testing"** — Driftwood nu poate copia orbeste acel cod; trebuie fie adaptat si testat temeinic, fie inlocuit cu o librarie comunitara matura (ex. ProfileService, mentionata frecvent in comunitate ca standard de facto — NEVERIFICAT ca recomandare oficiala Roblox, e alegere de ecosistem, de cercetat separat).

## Intrebari deschise

1. Cati jucatori simultani per server-slot planuiesti pentru Driftwood (CLAUDE.md mentioneaza "tot serverul imparte acelasi oras")? Numarul afecteaza direct bugetul `DataStoreService` (`60 + numPlayers × 40`) si trebuie stabilit inainte de a dimensiona frecventa de salvare.
2. Foloseste o librarie comunitara matura pentru persistenta (ex. ProfileService/ProfileStore) sau construiesti propriul wrapper peste `DataStoreService`? Roblox insusi avertizeaza ca exemplul lui de cod nu e productie-ready — decizia trebuie luata explicit, nu implicit.
3. Cate obiecte simultane planuiesti sa existe "in rau" pe ecran, in cel mai incarcat sezon (Iarna, cu epave rare/grele conform CLAUDE.md)? Numarul determina daca replicarea bazata pe seed ramane suficienta sau daca ai nevoie si de un mecanism de "eveniment special" pentru obiecte unice, ne-deterministe (ex. un obiect legendar generat manual de un GM/eveniment, care NU vine din seed).
4. Cum se comporta exact `Random.new(seed)` cross-versiune de motor — de testat manual in Studio (genereaza aceeasi secventa la interval de cateva zile/actualizari Studio si compara).
5. Care e plafonul real de memorie/CPU per server pentru locul tau specific — de masurat in Studio cu Microprofiler + Developer Console (Server Stats), nu presupus.
6. Exista o limita practica (nedocumentata oficial) pentru numarul/dimensiunea totala de attributes per instanta — de testat empiric daca planuiesti sa te bazezi pe attributes pentru mai mult decat 2-3 valori simple per obiect.
7. Cum gestionezi exact "Inundatia" (evenimentul lunar de server din CLAUDE.md) la nivel de remote-uri — e un `RemoteEvent` de tip "faza de sezon schimbata" (ca in modelul din sectiunea 5), sau are nevoie de propriul contract separat cu payload mai mare (lista de obiecte pierdute, de exemplu)? De proiectat explicit inainte de implementare.

## Surse

- create.roblox.com/docs/projects/client-server — "Client-server runtime" — fara data explicita pe pagina, accesat 2026
- create.roblox.com/docs/projects/server-authority — "Server authority model" — fara data explicita pe pagina, accesat 2026
- create.roblox.com/docs/projects/server-authority/techniques — "Server authority techniques" — fara data explicita pe pagina, accesat 2026
- create.roblox.com/docs/scripting/events/remote — "Remote events and callbacks" — fara data explicita pe pagina, accesat 2026
- create.roblox.com/docs/reference/engine/classes/RemoteEvent — referinta API — fara data explicita pe pagina, accesat 2026
- create.roblox.com/docs/reference/engine/classes/UnreliableRemoteEvent — referinta API + descriere — fara data explicita, copyright afisat 2026, accesat 2026
- create.roblox.com/docs/scripting/security/client-server-boundary — "Securing the client-server boundary" — fara data explicita, accesat 2026
- create.roblox.com/docs/scripting/security/defensive-design — "Defensive design tactics" — fara data explicita, accesat 2026
- create.roblox.com/docs/scripting/security/server-side-detection — "Server-side detection and consequencing" — fara data explicita, accesat 2026
- create.roblox.com/docs/scripting/security/network-ownership — "Network ownership, movement validation, and physics" (listata in index, continut detaliat nefetch-uit integral in aceasta cercetare) — accesat 2026
- create.roblox.com/docs/scripting/security/access-control — "Access control and confidentiality" (listata in index, nefetch-uita integral) — accesat 2026
- create.roblox.com/docs/scripting/security/third-party-vulnerabilities — "Vulnerabilities from third-party assets" (listata in index, nefetch-uita integral) — accesat 2026
- create.roblox.com/docs/scripting/security/security-tactics — "Security and cheat mitigation tactics" (listata in index, nefetch-uita integral) — accesat 2026
- create.roblox.com/docs/reference/engine/classes/ServerStorage — referinta API — fara data explicita, accesat 2026
- create.roblox.com/docs/reference/engine/classes/ReplicatedStorage — referinta API — fara data explicita, accesat 2026
- create.roblox.com/docs/reference/engine/classes/ReplicatedFirst — referinta API — fara data explicita, accesat 2026
- create.roblox.com/docs/reference/engine/classes/DataModel — referinta API, sectiunea `BindToClose` — fara data explicita, accesat 2026
- create.roblox.com/docs/reference/engine/classes/RunService — referinta API, evenimente Heartbeat/Stepped/PreSimulation/PostSimulation — fara data explicita, accesat 2026
- create.roblox.com/docs/reference/engine/classes/DataStoreService — referinta API, formule de rate limit — fara data explicita, accesat 2026
- create.roblox.com/docs/reference/engine/classes/MemoryStoreService — referinta API — fara data explicita, accesat 2026
- create.roblox.com/docs/reference/engine/datatypes/Random — referinta API, `Random.new(seed)` — fara data explicita, accesat 2026
- create.roblox.com/docs/scripting/data/data-stores — "Data stores" (ghid) — fara data explicita, accesat 2026
- create.roblox.com/docs/cloud-services/data-stores — "Data stores" — fara data explicita, accesat 2026
- create.roblox.com/docs/cloud-services/data-stores/error-codes-and-limits — "Data store error codes and limits" — fara data explicita, accesat 2026
- create.roblox.com/docs/cloud-services/data-stores/best-practices — "Best practices for data stores" — fara data explicita, accesat 2026
- create.roblox.com/docs/cloud-services/data-stores/player-data-purchasing — "Implement player data and purchasing systems" — fara data explicita, accesat 2026
- create.roblox.com/docs/cloud-services/memory-stores — "Memory stores" — fara data explicita, accesat 2026
- create.roblox.com/docs/studio/properties — "Properties and attributes" in Studio — fara data explicita, accesat 2026
- create.roblox.com/docs/studio/microprofiler — "MicroProfiler" — fara data explicita, accesat 2026
- create.roblox.com/docs/performance-optimization/microprofiler/task-scheduler — "Task scheduler" — fara data explicita, accesat 2026
- create.roblox.com/docs/physics/network-ownership — "Network ownership" — fara data explicita, accesat 2026
- create.roblox.com/docs/llms.txt — index de pagini oficiale Roblox (folosit pentru a localiza URL-urile corecte de mai sus) — accesat 2026
- raw.githubusercontent.com/Roblox/creator-docs/main/content/en-us/reference/engine/classes/Instance.yaml — sursa oficiala a documentatiei (GitHub Roblox/creator-docs), pentru limita de 100 caractere pe nume de attribut — accesat 2026

**Nota metodologica:** in aceasta sesiune de cercetare, bugetul de interogari WebSearch al sesiunii era deja epuizat (folosit de cercetari anterioare din acelasi proiect) inainte de a incepe acest subiect — toata cercetarea de mai sus s-a facut EXCLUSIV prin WebFetch pe URL-uri de documentatie primara Roblox (inclusiv varianta `.md` a paginilor si fisierul index `llms.txt`), fara surse secundare (fara devforum, fara YouTube, fara bloguri). Asta inseamna acoperire mai ingusta pe "experienta comunitatii" (numere de CPU/memorie per server, exemple de proiecte reale) fata de celelalte note din acest masterplan, dar acuratete mai mare pe fapte primare — orice camp unde nu exista sursa primara e marcat explicit NEVERIFICAT mai sus, nu ghicit.
