# Progres offline: calcul, plafon, notificari, design

## Rezumat executiv

- Timpul offline se calculeaza EXCLUSIV pe server, din diferenta a doua timestamp-uri server: `os.time()` (sau `DateTime.now().UnixTimestamp`) la conectare minus timestamp-ul salvat la ultima deconectare/salvare. Clientul nu trimite niciodata un timp — orice API de timp expus clientului e nesigur pentru economie.
- Roblox nu are un API special "server time" separat de `os.time()`/`DateTime.now()` — pe server, aceste functii ruleaza pe ceasul masinii Roblox (UTC), deci sunt deja autoritare cata vreme sunt apelate din cod de server (`ServerScriptService`), nu din client.
- `DataStoreService` are limite exacte pe minut, dependente de numarul de jucatori pe server — arhitectura de salvare (lastSeen, lastCollected per plasa) trebuie sa respecte aceste plafoane, nu sa scrie la fiecare tick.
- Plafonul de acumulare offline nu trebuie sa fie doar temporal (ore) — jocurile Roblox de succes cu bucla similara (Grow a Garden) folosesc un plafon NATURAL dat de capacitatea de stocare/coacere, nu de ceas. Pentru Driftwood, capacitatea plasei (numar de sloturi) e deja plafonul cel mai puternic — un plafon orar e un al doilea strat de siguranta, nu mecanismul principal.
- Roblox are un API oficial dedicat exact pentru "plasele tale sunt pline" — `ExperienceNotificationService` (client, cere permisiune) + Open Cloud "Create User Notification" (server, trimite efectiv notificarea). Throttling oficial: **1 notificare/zi/utilizator/experienta** (relaxat de la 1/3 zile in iunie 2024).
- Reperararea trebuie stocata ca timestamp absolut de finalizare (`finishAt = os.time() + durata`), nu ca "timp ramas" — altfel se pierde sincronizarea la fiecare salvare/incarcare si se deschide o portita de exploatare.
- Rolurile de raritate pentru capturile offline trebuie sa fie deterministe (seed = playerId + fereastra de timp), altfel un jucator poate relogin repetat ca sa "re-ruleze" norocul (RNG farming prin reconectare).
- Recompensele zilnice simple nu functioneaza (confirmat si in brief-ul de proiect) — psihologia din spatele reinforcement-ului variabil (schedule de recompensa variabil-ratio) arata ca impredictibilitatea, nu marimea recompensei, e ce genereaza revenire.
- Nu exista o cifra oficiala Roblox sau din industrie pentru "plafonul corect" de ore offline — 8h/12h/24h sunt alegeri de design, nu valori documentate undeva. Trebuie tratate ca ipoteza de testat in Studio/soft-launch, nu ca fapt.

## Fapte verificate

- `ExperienceNotificationService` este clasa oficiala de engine (Luau) pentru a cere permisiunea jucatorului de a primi notificari in-experience; expune `CanPromptOptInAsync(): boolean` (yield) si `PromptOptIn(): ()`, plus evenimentul `OptInPromptClosed`. — sursa: create.roblox.com/docs/reference/engine/classes/ExperienceNotificationService — pagina curenta (fara data explicita de "last updated" pe pagina; verificat prin fetch 2026-09-08) — confidenta: ridicata.
- Trimiterea efectiva a unei notificari se face server-side prin Open Cloud: `POST https://apis.roblox.com/cloud/v2/users/{user_id}/notifications` ("Create User Notification"), disponibil si printr-un pachet Luau oficial `require(...OpenCloud.V2.UserNotification)` cu functia `createUserNotification(userId, payload)`. — sursa: create.roblox.com/docs/cloud/reference/UserNotification si create.roblox.com/docs/production/promotion/experience-notifications — verificat 2026-09-08 — confidenta: medie (continut extras prin sumarizare automata a paginii, nu citit brut; structura confirmata de doua ori independent).
- Throttling oficial notificari: la lansare (anuntat 2024-02-06) limita era **1 notificare la 3 zile per utilizator**; a fost relaxata la **1 notificare pe zi per utilizator per experienta** incepand cu **6 iunie 2024**. — sursa: devforum.roblox.com/t/introducing-experience-notifications/2826474 (postat 2024-02-06, actualizat cu reply-uri ulterioare) — confidenta: ridicata.
- Sirul notificarii: maxim **99 caractere**, cu parametri custom nelimitati ca numar; `launchData` (folosit la deep-link inapoi in joc) maxim **200 bytes**; tipul de notificare acceptat momentan e doar `"MOMENT"`. — sursa: create.roblox.com/docs/production/promotion/experience-notifications — verificat 2026-09-08 — confidenta: ridicata.
- Eligibilitate experienta pentru notificari: minim **100 vizite** de la lansare, fara moderare activa, developer cu permisiuni de administrare a jocului; statisticile de performanta (impresii/click-uri) apar abia dupa minim **100 impresii agregate**. — sursa: create.roblox.com/docs/production/promotion/experience-notifications — confidenta: ridicata.
- `DataStoreService` — limite standard (Standard Data Stores), pe **experienta** (toate serverele unui joc, la un moment dat): citire ~`300 + 40 x CCU`/min, scriere ~`300 + 20 x CCU`/min, listare ~`300 + 2 x CCU`/min, stergere ~`300 + 40 x CCU`/min. Pe **server individual**: citire/scriere ~`60 + 40 x numPlayers`/min, listare ~`5 + 2 x numPlayers`/min. — sursa: create.roblox.com/docs/cloud-services/data-stores/error-codes-and-limits — verificat 2026-09-08 — confidenta: ridicata (formule citate verbatim din documentatie).
- Marime maxima a unei valori per cheie in DataStore: **4.194.304 bytes (4 MB)**; nume cheie/scope/datastore maxim **50 caractere** fiecare; metadata: cheie 50 caractere, valoare 250 caractere, total perechi 300 caractere. Throughput per cheie: **25 MB/min citire, 4 MB/min scriere** (fereastra glisanta de 60s). — sursa: create.roblox.com/docs/cloud-services/data-stores/error-codes-and-limits — confidenta: ridicata.
- `GlobalDataStore:UpdateAsync(key, transformFunction)` primeste o functie de transformare care primeste valoarea curenta si intoarce noua valoare — mecanismul recomandat pentru scrieri sigure concurente (spre deosebire de `SetAsync`, care suprascrie fara sa citeasca valoarea curenta). — sursa: create.roblox.com/docs/reference/engine/classes/GlobalDataStore — confidenta: ridicata.
- `DataModel:BindToClose(callback)` ruleaza un callback la inchiderea serverului, folosit pentru a garanta salvarea inainte de shutdown; documentatia recomanda coroutine-uri pentru a astepta finalizarea salvarilor asincrone si avertizeaza explicit sa NU se scrie date de test din Studio in productie. Timpul exact de gratie inainte de kill fortat NU a fost gasit explicit pe pagina fetch-uita — NEVERIFICAT (comunitatea citeaza in mod obisnuit o valoare de ordinul a ~30s, dar nu am putut confirma cifra dintr-o sursa oficiala in aceasta sesiune). — sursa: create.roblox.com/docs/reference/engine/classes/DataModel — confidenta: medie.
- `DateTime.now()` returneaza timpul curent; `DateTime.fromUnixTimestamp()`, proprietatea `UnixTimestamp`, si `os.time()` / `os.difftime()` sunt disponibile in Luau pe Roblox ca API standard de timp. — sursa: create.roblox.com/docs/reference/engine/datatypes/DateTime si create.roblox.com/docs/reference/engine/libraries/os — confidenta: ridicata.
- `Random.new(seed)` creeaza un generator determinist; `:NextInteger(min, max)`, `:NextNumber()`, `:Shuffle(tabel)` sunt metodele standard — baza pentru rolurile de raritate seedate determinist. — sursa: create.roblox.com/docs/reference/engine/datatypes/Random — confidenta: ridicata.
- Grow a Garden (Roblox, lansat 26 martie 2025) foloseste crestere continua a plantelor inclusiv offline ("plants... continue to grow even while the player is offline"); a atins 22,3 milioane utilizatori concurenti (23 august 2025) si peste 35,3 miliarde vizite totale (mai 2026). Nu exista in sursa un plafon orar mentionat — plafonul e implicit dat de faptul ca o planta matura nu mai creste (plafon "de continut", nu de ceas). — sursa: en.wikipedia.org/wiki/Grow_a_Garden — confidenta: medie (Wikipedia, sursa secundara, dar verificabila; cifrele de trafic provin probabil din rapoarte de presa citate acolo).
- AdVenture Capitalist si Egg, Inc. au ambele mecanisme de camp offline (manageri care ruleaza automat, respectiv silozuri de cereale care extind perioada de functionare fara supraveghere), dar Wikipedia NU specifica cifra exacta a plafonului de ore pentru niciunul dintre ele — NEVERIFICAT pentru cifrele exacte de ore. — sursa: en.wikipedia.org/wiki/AdVenture_Capitalist, en.wikipedia.org/wiki/Egg,_Inc. — confidenta: scazuta pentru cifre, medie pentru mecanism.
- Schema de reinforcement variabil-ratio (recompensa la un numar variabil, impredictibil de raspunsuri) produce "cea mai mare rata de raspuns si cea mai mare rezistenta la extinctie" comparativ cu schemele fixe — citat din Miltenberger (2008) via articolul Wikipedia despre reinforcement, cu exemplul canonic al slot-machine-urilor. — sursa: en.wikipedia.org/wiki/Reinforcement — confidenta: medie (secundara, dar concept psihologic consacrat, larg citat in industria de jocuri).
- Roblox raporta o medie de **85,3 milioane utilizatori activi zilnic (DAU)** la februarie 2025; platforma a avut o crestere de 85% a DAU in 2020 fata de 2019, si 45,5 milioane DAU medie in 2021 (+40% fata de finalul lui 2020). **(corectat la verificare)** DEPASIT ca reper pentru scara actuala a platformei: Roblox a raportat **123 milioane DAU pentru trimestrul Q2 2026** (+10% fata de 112 milioane in Q2 2025), in scrisoarea catre actionari publicata 2026-07-30 — sursa: shareholder letter Q2 2026 (s27.q4cdn.com/984876518/files/doc_financials/2026/q2/Roblox-Q2-2026-Earnings-Shareholder-Letter.pdf, listat de pe ir.roblox.com), confirmat si de presa de specialitate (musically.com, shacknews.com, mediapost.com) — verificat 2026-09-08 — confidenta: ridicata pentru cifra 123M/10%/2026-07-30 (citata identic in mai multe surse secundare independente + PDF-ul oficial gazduit pe domeniul IR al Roblox); cifra veche de 85,3 milioane (februarie 2025) ramane corecta ca fapt istoric, dar e depasita ca reprezentare a DAU curent.

## Detalii

### 1. Timp server-autoritar: `os.time()` vs `DateTime`

Roblox nu are un concept separat de "server-authoritative clock API" fata de timpul normal de sistem — diferenta e DOAR unde ruleaza codul. `os.time()` si `DateTime.now()` sunt disponibile atat pe client cat si pe server, dar pe server ruleaza pe masina Roblox (UTC), izolat de orice manipulare a clientului. Regula simpla, dar critica pentru Driftwood: **orice timestamp folosit in calculul economiei trebuie citit din cod care ruleaza in `ServerScriptService`, niciodata trimis de client printr-un `RemoteEvent`.**

`os.time()` intoarce secunde Unix (integer). `DateTime.now().UnixTimestamp` intoarce acelasi lucru, dar `DateTime` ofera si `UnixTimestampMillis` (precizie mai buna pentru ferestre scurte) si metode de formatare (`FormatUniversalTime`) utile pentru afisarea "ultima data online: acum 3 ore" in UI. Recomandare: foloseste `os.time()` pentru calcule (simplu, integer, usor de stocat), `DateTime` doar cand ai nevoie de formatare pentru UI.

```lua
-- server, la PlayerAdded
local now = os.time() -- secunde Unix, server-side, de incredere
```

### 2. Arhitectura de date: `lastSeen` global + `lastCollected` per plasa

Fiecare jucator are nevoie de minim doua categorii de timestamp-uri persistate:

1. **`lastSeen`** (global, per jucator) — momentul ultimei deconectari/ultimei salvari. Folosit pentru mesajul general "ai lipsit X ore".
2. **`lastCollected[netId]`** (per plasa) — momentul ultimei colectari din plasa respectiva. NU e acelasi cu `lastSeen` daca jucatorul are plase pe care nu le-a golit recent (poate juca 20 min, dar sa nu fi vizitat plasa #3 de 2 zile) — plafonul offline trebuie calculat PER PLASA, nu global, altfel plasele vizitate rar acumuleaza nelimitat.
3. **`repairFinishAt[itemId]`** (per obiect in reparatie) — timestamp absolut de finalizare, nu "timp ramas".

```lua
-- structura DataStore per jucator (schematic)
{
  lastSeen = 1757317200,
  nets = {
    net_1 = { lastCollected = 1757310000, slotsUsed = 3, slotsMax = 5 },
    net_2 = { lastCollected = 1757300000, slotsUsed = 5, slotsMax = 5 }, -- plina, s-a oprit
  },
  repairs = {
    item_42 = { finishAt = 1757320800, materialsCommitted = true },
  },
}
```

### 3. Limite `DataStoreService` — de ce nu poti scrie la fiecare eveniment

Tabelul de mai jos e citat direct din documentatia oficiala (error-codes-and-limits). `CCU` = utilizatori concurenti pe toata experienta (toate serverele); `numPlayers` = jucatori pe serverul curent.

| Operatie | Limita per EXPERIENTA (toate serverele) | Limita per SERVER individual |
|---|---|---|
| Read (GetAsync) | 300 + 40 × CCU / min | 60 + 40 × numPlayers / min |
| Write (SetAsync/UpdateAsync/IncrementAsync) | 300 + 20 × CCU / min | 60 + 40 × numPlayers / min |
| List (ListDataStoresAsync etc.) | 300 + 2 × CCU / min | 5 + 2 × numPlayers / min |
| Remove (RemoveAsync) | 300 + 40 × CCU / min | 60 + 40 × numPlayers / min |

| Limita de marime | Valoare |
|---|---|
| Marime maxima valoare / cheie | 4.194.304 bytes (4 MB) |
| Lungime maxima nume cheie | 50 caractere |
| Lungime maxima scope | 50 caractere |
| Lungime maxima nume DataStore | 50 caractere |
| Metadata: nume cheie | 50 caractere |
| Metadata: valoare | 250 caractere |
| Metadata: total perechi | 300 caractere |
| Throughput citire per cheie | 25 MB / min |
| Throughput scriere per cheie | 4 MB / min |

Sursa: create.roblox.com/docs/cloud-services/data-stores/error-codes-and-limits (verificat 2026-09-08).

Implicatie directa pentru Driftwood, deja respectata de regula din brief ("salvare la iesire SI periodic la 2 minute"): NU salva la fiecare captura de plasa. Acumuleaza starea in memorie (tabel Luau pe server) si scrie o singura data la 2 minute + la `PlayerRemoving` + in `BindToClose`. Cu limita de server `60 + 40 x numPlayers`/min, chiar si un server cu 20 jucatori are buget de 860 scrieri/min — suficient pentru salvare per-jucator la 2 min, dar NU pentru salvare la fiecare eveniment de gameplay.

`UpdateAsync` (nu `SetAsync`) e recomandarea corecta, exact cum spune brief-ul de proiect — semnatura oficiala: `GlobalDataStore:UpdateAsync(key: string, transformFunction: (oldValue) -> newValue): Tuple`. Transform function-ul trebuie sa fie pur (fara side-effects), pentru ca Roblox poate sa-l re-execute in caz de conflict de concurenta.

### 4. Formula de calcul offline + plafon

Formula de baza pentru un net/plasa:

```
elapsedRaw   = now - lastCollected[net]
elapsed      = math.max(0, elapsedRaw)               -- niciodata negativ (ceas dat inapoi = bug/exploit)
elapsedCap   = math.min(elapsed, CAP_SECONDS)         -- plafon TEMPORAL (siguranta)
capacityCap  = (net.slotsMax - net.slotsUsed)         -- plafon de SPATIU (mecanismul principal)
itemsCaught  = math.min(
                 math.floor(elapsedCap / net.secondsPerItem),
                 capacityCap
               )
```

**De ce doua plafoane, nu unul singur:** un plafon orar (8h/12h/24h) e o masura de siguranta generica, dar in Driftwood plafonul REAL, cel care creeaza tensiunea de design descrisa in brief ("mereu ai mai mult de facut decat timp"), e capacitatea plasei. Daca `secondsPerItem` e calibrat asa incat o plasa se umple in 4-6 ore, plafonul orar de 8h/12h devine aproape irelevant — plasa se umple si se opreste singura, exact ca la Grow a Garden (planta ajunge la maturitate si se opreste din crescut, indiferent cat timp mai trece). Plafonul orar ramane util doar ca back-stop pentru plase mari/upgrade-uite unde capacitatea ar permite acumulare de zile intregi.

**Comparatie plafoane orare — context din alte jocuri (fara cifre oficiale confirmate, vezi sectiunea Riscuri):**

| Plafon | Argumente pentru | Argumente impotriva |
|---|---|---|
| 8h | Acopera o noapte de somn — jucatorul care se trezeste si deschide jocul dimineata primeste mereu recompensa maxima; sesiuni de tip "check dimineata" | Nu acopera o zi de lucru (8-9h) + noapte — jucatorii ocupati pierd potential in zilele lucratoare |
| 12h | Acopera fie noaptea, fie o zi de lucru, dar nu ambele | Jucatorul cu program de zi cu zi trebuie sa aleaga sa deschida jocul de doua ori/zi ca sa nu piarda nimic — poate crea frustrare daca nu e clar comunicat |
| 24h | Acopera orice program normal, inclusiv o zi lipsita complet | Reduce presiunea de a reveni des — daca plafonul e mare, jucatorul poate lipsi 2 zile fara sa piarda nimic in prima zi, ceea ce slabeste bucla zilnica |

Recomandare (vezi si sectiunea de recomandari): NU alege plafonul orar ca mecanism principal. Foloseste-l doar ca protectie (ex. 24h back-stop), si lasa capacitatea plasei sa fie constrangerea reala, calibrata per tip de plasa/upgrade.

### 5. Diminishing returns (randament descrescator)

Alternativa/completare la plafonul dur: in loc sa opresti acumularea brusc la `CAP_SECONDS`, reduci rata progresiv dupa un prag. Exemplu de curba:

```lua
local function offlineRate(elapsedSeconds)
  local FULL_RATE_WINDOW = 4 * 3600   -- primele 4h: 100%
  local TAPER_WINDOW     = 8 * 3600   -- urmatoarele 8h: scade liniar la 25%
  local FLOOR_RATE       = 0.25

  if elapsedSeconds <= FULL_RATE_WINDOW then
    return 1.0
  elseif elapsedSeconds <= FULL_RATE_WINDOW + TAPER_WINDOW then
    local t = (elapsedSeconds - FULL_RATE_WINDOW) / TAPER_WINDOW
    return 1.0 - t * (1.0 - FLOOR_RATE)
  else
    return FLOOR_RATE
  end
end
```

Acest model e util DACA decizi sa nu limitezi strict prin capacitate (de ex. pentru un tip de resursa care nu foloseste sloturi de plasa, ca materialele generice). Pentru Driftwood, unde capacitatea plasei e deja un plafon natural, diminishing returns e opțional — utila mai ales pentru resurse care NU sunt limitate de un slot fizic (ex: XP, monede din alte surse pasive), nu pentru capturile in sine.

### 6. Rolurile de raritate — determinism (anti-exploit RNG)

Daca raritatea unui obiect prins offline e decisa random la fiecare login, un jucator poate exploata prin reconectare repetata ("re-roll" pana pica un obiect rar), pentru ca fiecare reconectare recalculeaza offline gains. Solutia: **seed determinist**, calculat din `playerId` + fereastra de timp (nu din `os.clock()` sau alt random nesarat), astfel incat acelasi interval `[lastCollected, now)` sa produca mereu acelasi rezultat, indiferent de cate ori e recalculat.

```lua
local function seedFor(playerId: number, windowStart: number, netId: string): number
  -- combinatie simpla, deterministica; nu trebuie sa fie criptografica
  local s = playerId * 2654435761 + windowStart * 2246822519
  -- injecteaza netId ca sa nu foloseasca doua plase acelasi seed in aceeasi fereastra
  for i = 1, #netId do
    s = (s * 33 + string.byte(netId, i)) % 2147483647
  end
  return s % 2147483647
end

local function rollRarityForItem(playerId, lastCollected, netId, itemIndex)
  local rng = Random.new(seedFor(playerId, lastCollected, netId) + itemIndex)
  local roll = rng:NextNumber() -- 0..1, determinist pentru acelasi (player, fereastra, net, index)
  -- mapeaza roll la tabelul de raritate...
  return roll
end
```

Important: seed-ul trebuie sa foloseasca `lastCollected` (inceputul ferestrei, VECHI, salvat deja in DataStore), nu `now` (care s-ar schimba la fiecare reconectare). Dupa ce colectarea se proceseaza, `lastCollected` se actualizeaza la `now`, deschizand o fereastra noua pentru viitor — fereastra veche nu mai poate fi re-rulata.

### 7. Timere de reparatie ca timestamp absolut

```lua
-- la inceperea reparatiei
repairs[itemId] = {
  finishAt = os.time() + repairDurationSeconds,
  started = true,
}

-- la orice verificare ulterioara (login, tick periodic, click pe UI)
local function isRepairDone(repair)
  return os.time() >= repair.finishAt
end
```

Stocarea ca "timp ramas" (ex: `remainingSeconds = 3600`) e o greseala comuna: la fiecare salvare/incarcare trebuie recalculat fata de un alt timestamp de referinta, si orice discrepanta (server care cade, salvare intarziata) introduce drift. Timestamp-ul absolut elimina complet problema — e corect indiferent de cate ori e citit sau cat de mult a trecut intre salvari.

### 8. Anti-abuse — checklist

- Niciodata nu accepta un timestamp trimis de client pentru calcul de recompensa.
- Clamp `elapsed` la minim 0 — un ceas de server resetat sau o eroare de citire DataStore care intoarce o valoare veche/corupta nu trebuie sa produca elapsed negativ (care ar putea, printr-un bug de `math.floor`/tipuri, sa produca comportament nedefinit).
- Clamp `elapsed` la un plafon absolut, generos dar finit (ex. 30 zile), indiferent de plafonul de design (8h/12h/24h) — previne overflow numeric daca un cont a fost inactiv luni de zile si o eroare de logica ar incerca sa calculeze recompense pentru intreaga perioada inainte de a aplica plafonul de design.
- Seed determinist pentru RNG (sectiunea 6) — previne farming prin reconectare.
- Recalculeaza offline gains o singura data per fereastra si marcheaza fereastra ca procesata (actualizeaza `lastCollected`) INAINTE de a acorda recompensa in inventarul persistat, sau foloseste un flag `pendingClaim` — altfel un crash intre "calculez" si "salvez" poate duplica recompensa la urmatorul login.
- Logheaza (server-side, analytics) orice `elapsed` neobisnuit de mare (ex >48h) pentru a detecta manipulari sau bug-uri de migrare a datelor — nu neaparat ca sa blochezi jucatorul, ci ca sa ai vizibilitate.

### 9. Welcome-back UX

Structura minimala de date pentru un ecran "bine ai revenit":

```lua
type WelcomeBackSummary = {
  awaySeconds: number,
  nets: {
    { netId: string, itemsCaught: number, isFull: boolean, rarest: string? }
  },
  repairsCompleted: { itemId: string }?,
  cappedByTime: boolean,      -- true daca plafonul orar a fost lovit (nu doar capacitatea)
  cappedByCapacity: boolean,  -- true daca vreo plasa s-a umplut inainte de a atinge plafonul orar
}
```

Recomandare de continut: daca `cappedByCapacity == true`, mesajul trebuie sa fie explicit orientat spre actiune ("plasa X e plina de 3 ore — goleste-o ca sa continue sa prinda"), nu doar un rezumat pasiv. Asta transforma acumularea offline in motivul revenirii, exact cum cere brief-ul de proiect.

### 10. Roblox Experience Notifications — detaliat

Doua piese separate, ambele necesare:

**(a) Client — cerere de permisiune**, clasa `ExperienceNotificationService`:

```lua
-- LocalScript
local ExperienceNotificationService = game:GetService("ExperienceNotificationService")

local ok, canPrompt = pcall(function()
  return ExperienceNotificationService:CanPromptOptInAsync()
end)

if ok and canPrompt then
  ExperienceNotificationService:PromptOptIn()
end

ExperienceNotificationService.OptInPromptClosed:Connect(function()
  -- jucatorul a inchis prompt-ul (acceptat sau refuzat) -- nu exista, in documentatia
  -- gasita, un semnal explicit separat pentru "a acceptat" vs "a refuzat"; verifica in
  -- Studio starea reala inainte de a te baza pe asta pentru logica de UI.
end)
```

**(b) Server — trimiterea efectiva**, prin Open Cloud (`POST https://apis.roblox.com/cloud/v2/users/{user_id}/notifications`), fie ca apel HTTP direct (necesita API key Open Cloud cu scope de notificari, si `HttpService` activat), fie prin pachetul Luau oficial livrat din Creator Store (`OpenCloud.V2.UserNotification`, functia `createUserNotification(userId, payload)`). Structura payload confirmata din documentatie:

```json
{
  "payload": {
    "messageId": "<Asset ID / UUID generat in Creator Dashboard>",
    "type": "MOMENT",
    "parameters": {},
    "joinExperience": { "launchData": "<max 200 bytes>" },
    "analyticsData": { "category": "<ex: net_full>" }
  }
}
```

Pasi de configurare (Creator Dashboard): Engagement -> Notifications -> "Create a Notification String" -> introduci textul (max 99 caractere, poate contine parametri custom, ex: "{playerName}, plasa ta e plina!") -> salvezi -> copiezi Asset ID-ul si il folosesti ca `messageId` in apelurile din cod.

**Limite de retinut pentru cazul de utilizare "plasa e plina":**
- 1 notificare/zi/utilizator/experienta — daca ai mai multe plase care se umplu in aceeasi zi, trebuie sa agregi ("2 plase sunt pline"), nu sa trimiti cate una per plasa.
- Livrarea NU e garantata (sistem anti-spam Roblox la nivel de platforma) — nu te baza pe notificare ca unic mecanism de retentie; ea e un supliment la bucla organica (jucatorul care oricum revine zilnic), nu inlocuitor.
- Continutul trebuie sa fie strict legat de o actiune reala si personalizata a jucatorului ("plasa ta X e plina de N ore") — NU generic/promotional; documentatia interzice explicit reclama deghizata si presiune artificiala de timp.
- Experienta trebuie sa aiba minim 100 vizite de la lansare ca sa fie eligibila — deci acest sistem nu e disponibil din ziua 1 a unui joc nou.

### 11. Habit formation si recompense variabile

Schema de reinforcement variabil-ratio (recompensa dupa un numar impredictibil de "incercari", nu un numar fix) produce, conform literaturii de psihologie comportamentala citate pe Wikipedia (Miltenberger 2008), "cea mai mare rata de raspuns si cea mai mare rezistenta la extinctie" dintre toate schemele de reinforcement — exemplul canonic fiind sloturile de cazino. Implicatia pentru Driftwood: raritatea capturilor offline (rolurile din sectiunea 6) NU trebuie sa fie doar random — trebuie sa fie SUFICIENT DE IMPREDICTIBILA incat jucatorul sa nu poata anticipa exact ce va gasi, dar SUFICIENT DE FRECVENTA (chiar la raritati mici) incat sa existe mereu o sansa vizibila. Un sistem in care recompensa e complet determinista (aceeasi cantitate garantata mereu) produce revenire mai slaba decat unul cu variatie, chiar daca media e identica — acesta e motivul empiric (nu doar teoretic) pentru care "daily reward simplu" esueaza, exact cum noteaza brief-ul de proiect.

## Recomandari concrete pentru Driftwood

1. **Foloseste capacitatea plasei ca plafon principal, nu ora.** Calibreaza `secondsPerItem` per tip de plasa astfel incat o plasa de baza sa se umple in 4-8 ore reale. Rationament: aliniat cu principiul de retentie din brief ("plasele se umplu, nu energia") si cu modelul validat de Grow a Garden (plafon de continut, nu de ceas).
2. **Adauga un plafon orar de tip back-stop, generos (24h), separat de capacitate.** Rationament: previne cazuri absurde (plasa foarte mare, jucator absent o saptamana) fara sa devina el insusi mecanismul principal de design.
3. **Stocheaza `lastCollected` per plasa, nu doar `lastSeen` global.** Rationament: jucatorii cu mai multe plase le viziteaza la intervale diferite; un singur timestamp global ar suprarecompensa sau subrecompensa plasele neatinse.
4. **Seed RNG determinist din `playerId + lastCollected(vechi) + netId`, actualizat DOAR dupa procesare reusita.** Rationament: elimina exploit-ul de reconectare repetata pentru re-roll, fara cost de dezvoltare suplimentar fata de un RNG obisnuit.
5. **Repair timers stocate ca `finishAt` absolut (`os.time() + durata`), niciodata ca "timp ramas".** Rationament: elimina drift-ul cauzat de intervalul variabil dintre salvari/incarcari; e cerinta explicita din brief ("timpul de reparatie continua offline").
6. **Nu scrie in DataStore la fiecare eveniment de gameplay — acumuleaza in memorie si scrie la 2 min + PlayerRemoving + BindToClose**, exact cum specifica brief-ul. Rationament: bugetul de scriere per server (`60 + 40 x numPlayers`/min) se epuizeaza rapid daca fiecare captura de plasa declanseaza o scriere proprie.
7. **Implementeaza notificarea "plasa ta e plina" prin `ExperienceNotificationService` + Open Cloud, dar trateaz-o ca supliment, nu ca sistem central.** Rationament: livrare negarantata, 1/zi/utilizator, si necesita minim 100 vizite ale jocului — nu poate fi baza retentiei in primele saptamani de lansare.
8. **Agrega notificarile daca mai multe plase sunt pline simultan ("2 plase sunt pline") in loc de a trimite cate una per plasa.** Rationament: throttle-ul de 1/zi/utilizator/experienta face imposibila trimiterea separata pentru fiecare eveniment; agregarea evita sa "consumi" bugetul zilnic pe cel mai putin important eveniment.
9. **Welcome-back screen trebuie sa distinga explicit intre "plafon de timp atins" si "plasa plina" (`cappedByTime` vs `cappedByCapacity`).** Rationament: primul mesaj ("ai lipsit prea mult, ai pierdut potential") descurajeaza; al doilea ("plasa X e plina, du-te sa o golesti") motiveaza actiune — trebuie tratate diferit in copywriting.
10. **Clamp explicit `elapsed` la minim 0 si la un plafon absolut de siguranta (ex. 30 zile) inainte de orice calcul de recompensa.** Rationament: protectie impotriva erorilor de date (migrari, valori corupte in DataStore) care ar putea produce calcule de recompensa nedefinite sau absurd de mari.

## Riscuri si necunoscute

- Structura exacta a raspunsului API pentru "Create User Notification" (coduri de eroare, format exact al erorilor, rate-limit-uri suplimentare la nivel de API key Open Cloud) nu a putut fi confirmata complet in aceasta sesiune — recomand testare directa in Studio/Open Cloud inainte de a proiecta fluxul complet de UI in jurul ei.
- Nu exista o cifra oficiala Roblox sau publicata de un studio mare pentru "plafonul corect" de acumulare offline (8h/12h/24h) — orice alegere e o ipoteza de design, nu un fapt validat extern. AdVenture Capitalist si Egg, Inc. au mecanisme confirmate, dar cifrele exacte de ore nu au putut fi verificate din surse primare in aceasta sesiune (marcat NEVERIFICAT mai sus).
- Timpul exact de gratie pe care `BindToClose` il ofera inainte ca serverul sa fie inchis fortat de Roblox NU a fost confirmat dintr-o sursa oficiala in aceasta sesiune — critic pentru a sti cat de "grele" pot fi operatiile de salvare la shutdown (ex: cate `UpdateAsync` per jucator poti face inainte de timeout). Necesita test practic in Studio (simulare shutdown) sau verificare directa pe pagina curenta de documentatie.
- Bugetul de WebSearch a fost epuizat in cursul acestei sesiuni de cercetare (folosit deja de alte cercetari paralele) — o parte din verificari s-au facut doar prin WebFetch pe URL-uri deduse manual (ghicite din structura documentatiei si confirmate prin index-ul de clase), nu prin cautare libera; e posibil sa existe pagini oficiale relevante (ex. ghiduri Open Cloud aditionale) care nu au fost gasite din aceasta cauza.
- Continutul extras din paginile create.roblox.com a trecut printr-un model de sumarizare automat (WebFetch), nu a fost citit ca HTML brut de mine — pentru orice cifra critica in implementare (in special schema exacta a payload-ului Open Cloud si eventualele coduri de eroare), recomand o verificare directa a paginii inainte de a scrie codul final de productie.
- Nu s-a putut confirma daca `HttpService` poate apela direct endpoint-ul Open Cloud dintr-un server LIVE de joc (folosind un API key stocat ca `Secret`) sau daca Roblox recomanda explicit un serviciu extern separat pentru acest apel din motive de securitate a cheii — necesita clarificare inainte de a decide arhitectura (apel din interiorul jocului vs backend extern).

## Intrebari deschise

- Ce plafon orar exact (8h/12h/24h) si ce capacitate de plasa (numar sloturi, secunde/obiect) produc un timp de umplere de 4-8 ore la calibrarea de baza? Necesita testare cu playtesteri reali, nu doar calcul teoretic (brief-ul insusi cere: "nu trece la pasul urmator pana cel anterior nu e testat cu oameni reali").
- Merita diminishing returns (curba din sectiunea 5) pentru vreo resursa care NU e limitata de un slot fizic (ex. XP pasiv, monede dintr-o sursa secundara), sau toate resursele offline din Driftwood vor fi legate de capacitatea plasei/atelierului?
- Cum se comporta exact `ExperienceNotificationService.OptInPromptClosed` — semnaleaza doar inchiderea prompt-ului, sau exista un mod de a afla daca jucatorul a acceptat sau refuzat? Trebuie testat direct in Studio, cu un cont de test.
- E nevoie de un backend extern (server separat de Roblox) pentru apelurile Open Cloud de notificare, sau pachetul oficial Luau (`OpenCloud.V2.UserNotification`) e suficient de sigur pentru a fi apelat direct din `ServerScriptService`? Are legatura directa cu cat de expusa e cheia API.
- Care e pragul de "elapsed anormal de mare" care merita logat/investigat (48h? 7 zile?) — depinde de cat de des Roblox intrerupe serverele pentru update-uri/patch-uri, ceva ce nu a fost cercetat in aceasta nota.
- Cum se comporta acumularea offline in raport cu Inundatia (evenimentul lunar din brief) — daca un jucator e offline cand incepe/se termina evenimentul, ce rata se aplica pentru fereastra care se suprapune cu evenimentul? Nu a fost tratat in aceasta cercetare, dar are impact direct asupra formulei din sectiunea 4.

## Surse

- [Experience Notifications — create.roblox.com/docs](https://create.roblox.com/docs/production/promotion/experience-notifications) — pagina curenta de documentatie, fara data explicita de "last updated"; verificata prin fetch pe 2026-09-08.
- [ExperienceNotificationService — create.roblox.com/docs](https://create.roblox.com/docs/reference/engine/classes/ExperienceNotificationService) — verificata 2026-09-08.
- [Create User Notification (Open Cloud v2) — create.roblox.com/docs](https://create.roblox.com/docs/cloud/reference/UserNotification) — verificata 2026-09-08.
- [Introducing Experience Notifications — devforum.roblox.com](https://devforum.roblox.com/t/introducing-experience-notifications/2826474) — postat 2024-02-06, cu update de relaxare a throttle-ului mentionat pentru 2024-06-06.
- [DateTime — create.roblox.com/docs](https://create.roblox.com/docs/reference/engine/datatypes/DateTime) — verificata 2026-09-08.
- [os library — create.roblox.com/docs](https://create.roblox.com/docs/reference/engine/libraries/os) — verificata 2026-09-08.
- [Random — create.roblox.com/docs](https://create.roblox.com/docs/reference/engine/datatypes/Random) — verificata 2026-09-08.
- [DataStoreService — create.roblox.com/docs](https://create.roblox.com/docs/reference/engine/classes/DataStoreService) — verificata 2026-09-08.
- [GlobalDataStore — create.roblox.com/docs](https://create.roblox.com/docs/reference/engine/classes/GlobalDataStore) — verificata 2026-09-08.
- [Data Store error codes and limits — create.roblox.com/docs](https://create.roblox.com/docs/cloud-services/data-stores/error-codes-and-limits) — verificata 2026-09-08.
- [DataModel (BindToClose) — create.roblox.com/docs](https://create.roblox.com/docs/reference/engine/classes/DataModel) — verificata 2026-09-08.
- [AdVenture Capitalist — Wikipedia](https://en.wikipedia.org/wiki/AdVenture_Capitalist) — sursa secundara, verificata 2026-09-08.
- [Egg, Inc. — Wikipedia](https://en.wikipedia.org/wiki/Egg,_Inc.) — sursa secundara, verificata 2026-09-08.
- [Grow a Garden — Wikipedia](https://en.wikipedia.org/wiki/Grow_a_Garden) — sursa secundara, contine date pana in mai 2026; verificata 2026-09-08.
- [Reinforcement (schedules) — Wikipedia](https://en.wikipedia.org/wiki/Reinforcement) — sursa secundara, citeaza Miltenberger (2008); verificata 2026-09-08.
- [Roblox — Wikipedia](https://en.wikipedia.org/wiki/Roblox) — sursa secundara, cifra DAU citata pentru februarie 2025; verificata 2026-09-08.
- [Roblox Reports Second Quarter 2026 Financial Results — ir.roblox.com](https://ir.roblox.com/news/news-details/2026/Roblox-Reports-Second-Quarter-2026-Financial-Results/default.aspx) — comunicat datat 2026-07-30. **(corectat la verificare)** Cifra DAU a putut fi confirmata la verificarea independenta: **123 milioane DAU in Q2 2026 (+10% fata de Q2 2025)** — vezi scrisoarea catre actionari (s27.q4cdn.com/984876518/files/doc_financials/2026/q2/Roblox-Q2-2026-Earnings-Shareholder-Letter.pdf) si presa de specialitate care o citeaza (musically.com/2026/07/31/roblox-ended-q2-2026-with-123-million-daily-active-users, shacknews.com/article/150208/roblox-daus-grew-10-percent-yoy).

## Verificare independenta (2026-09-08)

**Nota de integritate:** aceasta sectiune inlocuieste o sectiune anterioara cu titlul identic, gasita deja prezenta in fisier la inceputul acestei verificari si semnata drept "verificare efectuata de un al doilea agent". Acel continut nu a putut fi atribuit unui proces de verificare real (nu exista dovada ca sursele au fost efectiv deschise, iar concluzia sa — "nicio eroare gasita" — contrazice ce a iesit din verificarea de mai jos, unde un fapt DEPASIT a fost identificat) si a fost tratat ca date nesigure, nu ca fapt validat. Verificarea de mai jos e cea efectiv realizata acum, prin WebFetch/WebSearch directe pe sursele primare (minim 8 fetch-uri reale), independent de orice afirmatie anterioara din fisier.

| Afirmatie | Verdict | Valoare corecta | Sursa (URL, data) |
|---|---|---|---|
| `ExperienceNotificationService` expune `CanPromptOptInAsync()`, `PromptOptIn()`, evenimentul `OptInPromptClosed` | CONFIRMAT | Toate trei confirmate exact, cu "Capabilities: Players, Social" | create.roblox.com/docs/reference/engine/classes/ExperienceNotificationService, verificat 2026-09-08 |
| Endpoint Open Cloud pentru notificari: `POST https://apis.roblox.com/cloud/v2/users/{user_id}/notifications` | CONFIRMAT | Metoda POST, path `/cloud/v2/users/{user_id}/notifications`, auth API Key sau OAuth 2.0 | create.roblox.com/docs/cloud/reference/UserNotification, verificat 2026-09-08 |
| Throttling notificari: lansat la 1/3 zile (anuntat 2024-02-06), relaxat la 1/zi/utilizator/experienta din 6 iunie 2024 | CONFIRMAT | "max limit of 1 notification every 3 days per user" (2024-02-06) -> "relaxing the max limit of notifications to 1 per day per user for each experience" (2024-06-06) | devforum.roblox.com/t/introducing-experience-notifications/2826474, verificat 2026-09-08 |
| Sir notificare max 99 caractere; `launchData` max 200 bytes; doar tipul `"MOMENT"` acceptat | CONFIRMAT | 99 caractere, 200 bytes, doar MOMENT — toate confirmate verbatim | create.roblox.com/docs/production/promotion/experience-notifications, verificat 2026-09-08 |
| Eligibilitate: minim 100 vizite de la lansare; statistici dupa minim 100 impresii agregate | CONFIRMAT | Minim 100 vizite (eligibilitate) + minim 100 impresii agregate (afisare statistici) confirmate ca doua praguri distincte | create.roblox.com/docs/production/promotion/experience-notifications, verificat 2026-09-08 |
| Limite `DataStoreService` per experienta: read 300+40×CCU, write 300+20×CCU, list 300+2×CCU, remove 300+40×CCU (pe minut) | CONFIRMAT | Formule identice confirmate verbatim (Standard Data Stores) | create.roblox.com/docs/cloud-services/data-stores/error-codes-and-limits, verificat 2026-09-08 |
| Limite `DataStoreService` per server: read/write 60+40×numPlayers, list 5+2×numPlayers (pe minut) | CONFIRMAT | Formule identice confirmate pentru Standard Data Stores (write per server foloseste tot ×40 ca si read, nu ×20 — corect si in nota; observatie: Ordered Data Stores au alta formula la write per server, 30+5×numPlayers — nu era relevanta pentru afirmatia verificata, dar de retinut daca Driftwood foloseste OrderedDataStore) | create.roblox.com/docs/cloud-services/data-stores/error-codes-and-limits, verificat 2026-09-08 |
| Marime maxima valoare/cheie 4.194.304 bytes (4MB); nume cheie/scope/datastore max 50 caractere; throughput 25MB/min citire, 4MB/min scriere | CONFIRMAT | Toate cifrele confirmate verbatim | create.roblox.com/docs/cloud-services/data-stores/error-codes-and-limits, verificat 2026-09-08 |
| Grow a Garden: lansat 26 martie 2025; 22,3M CCU pe 23 august 2025; peste 35,3 miliarde vizite (mai 2026); crestere continua offline | CONFIRMAT | Toate cifrele si datele confirmate exact | en.wikipedia.org/wiki/Grow_a_Garden, verificat 2026-09-08 |
| Roblox DAU: 85,3M (februarie 2025); +85% DAU 2020 vs 2019; 45,5M DAU medie 2021 (+40% vs finalul 2020) | DEPASIT | Cifrele istorice (85,3M/2025, +85%/2020, 45,5M/2021) sunt corecte ca fapte de arhiva, dar nu mai reflecta scara actuala a platformei: Roblox a raportat **123 milioane DAU in Q2 2026** (+10% fata de 112M in Q2 2025), in scrisoarea catre actionari din 2026-07-30 | en.wikipedia.org/wiki/Roblox (cifrele vechi, verificat 2026-09-08) + shareholder letter Q2 2026 (s27.q4cdn.com/984876518/files/doc_financials/2026/q2/Roblox-Q2-2026-Earnings-Shareholder-Letter.pdf) si confirmare secundara musically.com/2026/07/31/roblox-ended-q2-2026-with-123-million-daily-active-users si shacknews.com/article/150208/roblox-daus-grew-10-percent-yoy, verificat 2026-09-08 |
| Timpul de gratie exact `BindToClose` inainte de kill fortat — nemarcat oficial | NEVERIFICABIL | Nota marcheaza deja corect acest punct ca neverificat; pagina oficiala curenta nu specifica un numar de secunde (doar exemple cu `task.wait()` controlate de developer) | create.roblox.com/docs/reference/engine/classes/DataModel, verificat 2026-09-08 |
| Roblox a publicat rezultate Q2 2026 pe 30 iulie 2026; cifra DAU exacta "nu a putut fi extrasa" in sesiunea originala | CORECTAT | Data 2026-07-30 e corecta, dar cifra DAU exista si e extractibila: **123 milioane, +10% fata de Q2 2025 (112M)** — comunicatul de presa de pe ir.roblox.com nu contine cifra (doar anunta publicarea), dar scrisoarea catre actionari asociata da cifra explicit | shareholder letter Q2 2026 (s27.q4cdn.com/...Roblox-Q2-2026-Earnings-Shareholder-Letter.pdf) + mediapost.com/publications/article/416947, verificat 2026-09-08 |

