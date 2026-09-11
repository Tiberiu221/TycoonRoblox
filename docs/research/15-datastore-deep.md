# DataStoreService în profunzime: limite, ProfileStore, schemă de date pentru Driftwood

## Rezumat executiv

- **Nu se folosește ProfileService pentru un proiect nou.** Autorul (loleris / Laimonas Mileska) a marcat oficial repo-ul ca "no longer supported" și recomandă migrarea la succesorul său, ProfileStore. Sursa: README GitHub, accesat 2026-09-08.
- **ProfileStore (MadStudioRoblox/ProfileStore, tot de la loleris) e alegerea corectă pentru Driftwood** — wrapper peste `DataStoreService` cu session locking automat, auto-save, `Reconcile()` pentru migrarea schemei. E folosit în producție de jocuri cu trafic masiv (Grow a Garden, Dead Rails) — mențiune curentă pe pagina DevForum (topic pinned, actualizat continuu), nu parte din anunțul original din 11 oct. 2024, deoarece Grow a Garden a lansat abia în martie 2025 (corectat la verificare).
- **UpdateAsync, nu SetAsync**, pentru orice date de jucător — CLAUDE.md are deja regula asta corectă. `UpdateAsync` face read-modify-write cu retry automat pe conflict; `SetAsync` doar suprascrie și poate crea inconsistență între servere concurente.
- **Nu există un cooldown fix de 6 secunde per cheie** în documentația curentă (2025-2026). Limita reală e un throughput per-cheie: 25 MB/min citire, 4 MB/min scriere, plus bugete separate per experience și per server. Confuzia veche cu "6 secunde" nu mai apare în pagina oficială de limite.
- **Un eșec de scriere nu garantează că scrierea n-a avut loc** — citat exact din documentația Roblox: "A failed write call, such as UpdateAsync(), means the game server did not receive a successful response. It does not always guarantee that the backend write did not occur." Asta impune un design idempotent pentru orice logică de retry proprie (critic pentru economia din Driftwood).
- **Orașul comun (atelierul orașului) nu poate fi salvat ca "profil de jucător"** — e stare partajată între toți jucătorii de pe un server. Trebuie o cheie DataStore separată, actualizată exclusiv prin `UpdateAsync` cu funcție de transform, cu un jurnal de contribuții per-jucător pentru a evita dublarea contribuțiilor la retry.
- **Limita de stocare crește cu numărul de utilizatori unici**: 500 MB + 1 MB × lifetime user count. Pentru un joc mic la lansare, asta nu e o grijă imediată, dar schema de date (fără date redundante per obiect din index) contează pe termen lung.
- **Testarea în Studio necesită activarea explicită** a "Enable Studio Access to API Services" din Security settings, iar pentru teste de rate-limit corecte se recomandă Team Create, nu Studio local (limitele din Run mode local sunt separate și adesea mai mici).
- **Versionarea (`ListVersionsAsync`/`GetVersionAsync`) e utilă pentru rollback la incidente** (ex. un bug care șterge inventarul cuiva), dar versiunile expiră la 30 de zile după ce sunt suprascrise — nu e un backup permanent.

## Fapte verificate

- Limita valoare per cheie (Data): **4.194.304 caractere** (4 MB) per cheie. Sursă: https://create.roblox.com/docs/cloud-services/data-stores/error-codes-and-limits — accesat 2026-09-08. Încredere: ridicată.
- Lungime maximă nume data store, nume cheie, scope: **50 caractere** fiecare. Aceeași sursă. Încredere: ridicată.
- Metadata (user-defined): nume cheie metadata max **50 caractere**, valoare max **250 caractere**, total perechi cheie-valoare max **300 caractere** (fără limită de număr de perechi). Aceeași sursă. Încredere: ridicată.
- Throughput per cheie: **citire 25 MB/minut**, **scriere 4 MB/minut**, calculat pe fereastră glisantă de 60 de secunde, rotunjit în sus la KB. Aceeași sursă. Încredere: ridicată.
- Coadă de request-uri: fiecare coadă (Set/Ordered set/Get/Ordered get) are limită de **30 de request-uri**; peste asta, request-urile pică cu coduri de eroare 301-306. Aceeași sursă. Încredere: ridicată.
- Buget la nivel de experience (shared între game server și Open Cloud): Read = `300 + concurrentUsers × 40`, Write = `300 + concurrentUsers × 20`, List = `300 + concurrentUsers × 2`, Remove = `300 + concurrentUsers × 40` (per minut, standard data stores; identic ca formă pentru ordered). Aceeași sursă. Încredere: ridicată.
- Buget implicit per server (dacă nu apelezi `SetRateLimitForRequestType`): Standard Read/Write/Remove = `60 + numPlayers × 40`, Standard List = `5 + numPlayers × 2`, Ordered Write = `30 + numPlayers × 5`, Ordered List/Remove = `5 + numPlayers × 2` / `30 + numPlayers × 5`. Aceeași sursă. Încredere: ridicată.
- Limită de stocare: **500 MB + 1 MB × numărul de utilizatori unici din toată istoria jocului** (lifetime user count), calculată pe dimensiunea comprimată a ultimei versiuni a fiecărei chei. Aceeași sursă. Încredere: ridicată.
- Versiunile create de `SetAsync`/`UpdateAsync`/`IncrementAsync` (prima scriere per cheie în fiecare oră UTC creează o versiune nouă) **expiră la 30 de zile** după ce sunt suprascrise de o versiune nouă; ultima versiune nu expiră niciodată. Sursă: https://create.roblox.com/docs/cloud-services/data-stores/versioning-listing-and-caching — accesat 2026-09-08. Încredere: ridicată.
- `GetAsync()` folosește un cache local de **4 secunde**; scrierile prin `SetAsync`/`UpdateAsync` actualizează imediat cache-ul local și resetează timer-ul. Se poate ocoli cu `DataStoreGetOptions.UseCache = false`. Aceeași sursă. Încredere: ridicată.
- `UpdateAsync`: dacă alt server a modificat cheia între citire și scriere, funcția de transform e **rechemată automat** cu valoarea nouă, până reușește sau întoarce `nil` (caz în care scrierea e anulată). Funcția de transform **nu are voie să facă yield**. Sursă: https://create.roblox.com/docs/reference/engine/classes/GlobalDataStore — accesat 2026-09-08. Încredere: ridicată.
- Un eșec de scriere (pcall failure) **nu garantează** că backend-ul n-a aplicat scrierea — verificare recomandată printr-un `GetAsync` ulterior cu `UseCache = false`. Sursă: https://create.roblox.com/docs/cloud-services/data-stores/error-codes-and-limits — accesat 2026-09-08. Încredere: ridicată.
- `BindToClose`: serverul așteaptă **maximum 30 de secunde** ca toate funcțiile legate să termine, apoi se închide oricum. Se pot lega mai multe funcții, rulează în paralel. Sursă: https://create.roblox.com/docs/reference/engine/classes/DataModel — accesat 2026-09-08. Încredere: ridicată.
- `BatchGetAsync()` pe `OrderedDataStore` e limitat la max **100 de chei per request** (implicit configurabil server-side) — funcționează doar pe `OrderedDataStore`, aruncă eroare pe `DataStore` standard. Aceeași sursă (GlobalDataStore). Încredere: ridicată.
- `GetSortedAsync` (OrderedDataStore): page size minim **1**, maxim **100** (cod eroare 106 PageSizeGreater/PageSizeLesser). Sursă: error-codes-and-limits. Încredere: ridicată.
- `SetRateLimitForRequestType`: constrângeri exacte per tip — `GetAsync` baseLimit [0,60] perPlayerLimit [0,40]; `SetIncrementAsync` [0,60]/[0,40]; `GetSortedAsync` [0,5]/[0,2]; `SetIncrementSortedAsync` [0,30]/[0,5]; `ListAsync`, `GetVersionAsync`, `RemoveVersionAsync` [0,5]/[0,2]; categoriile Standard*/Ordered* [0,10000]/[0,200]. `UpdateAsync` și `OnUpdate` **nu pot fi configurate** cu această funcție. Sursă: DataStoreService reference, create.roblox.com — accesat 2026-09-08. Încredere: ridicată.
- ProfileStore: auto-save implicit **300 secunde** (crescut față de cele 30 secunde din ProfileService), pentru a reduce apelurile la DataStore, coordonat via `MessagingService` pentru predare rapidă de sesiune. Sursă: anunț DevForum, "ProfileStore - Save your player data easy (DataStore Module)", loleris, 11 octombrie 2024. Încredere: ridicată.
- ProfileStore e folosit de **Grow a Garden** (30+ miliarde vizite) și **Dead Rails** (5+ miliarde vizite) — informație aflată azi în postarea DevForum (topic pinned de resurse, editat continuu de autor), **nu** face parte din anunțul original din 11 oct. 2024, pentru că Grow a Garden a lansat abia pe 26 martie 2025 (confirmat: en.wikipedia.org/wiki/Grow_a_Garden, accesat 2026-09-08) — deci fraza "conform anunțului din 11 oct. 2024" e o atribuire de dată greșită (corectat la verificare). Faptul în sine (GaG/Dead Rails folosesc ProfileStore) rămâne plauzibil ca stare curentă a postării, dar data trebuie eliminată din citare. Încredere: medie (afirmație a autorului, nu verificată independent, dar autorul e credibil și verificabil ca dezvoltator Roblox cunoscut).
- ProfileService (predecesorul) README spune explicit: **"This project is no longer supported"**, cu recomandare de migrare la ProfileStore. Sursă: github.com/MadStudioRoblox/ProfileService — accesat 2026-09-08. Încredere: ridicată.
- ProfileStore e disponibil ca pachet Wally: `lm-loleris/profilestore`, versiune **1.0.3**, `realm = "server"`. Sursă: raw.githubusercontent.com/MadStudioRoblox/ProfileStore/main/wally.toml — accesat 2026-09-08. Încredere: ridicată.
- ProfileStore.Mock oferă un mediu de testare izolat (nu scrie pe cheile live) chiar și cu API Services activat în Studio. Sursă: madstudioroblox.github.io/ProfileStore/api/ — accesat 2026-09-08. Încredere: ridicată.
- `Profile:Reconcile()` completează câmpurile lipsă din `Profile.Data` pe baza template-ului dat la `ProfileStore.New(store_name, template)` — mecanismul recomandat de migrare de schemă. Aceeași sursă. Încredere: ridicată.
- Open Cloud DataStore API v2 (`/cloud/v2/universes/{universe_id}/data-stores/...`) e API-ul curent recomandat; endpoint-urile vechi `/datastores/v1/...` și `/ordered-data-stores/v1/...` sunt marcate explicit **"Not Recommended"** cu "Recommended Alternatives" către v2. Sursă: https://create.roblox.com/docs/cloud/reference/DataStore — accesat 2026-09-08. Încredere: ridicată.
- Traficul Open Cloud și traficul din server-ul de joc **împart același buget** de request-uri per experience — trafic Open Cloud poate fi throttled de uzul din joc și invers. Aceeași sursă (error-codes-and-limits). Încredere: ridicată.
- Data Stores Manager din Creator Hub (Configure → Data Stores Manager) permite vizualizare, editare, ștergere și **revert la o versiune anterioară** a unei chei, direct din UI web, fără cod. Necesită permisiuni "View/Edit/Delete Data Stores" pentru membri de grup. Sursă: https://create.roblox.com/docs/cloud-services/data-stores/data-stores-manager — accesat 2026-09-08. Încredere: ridicată.

## Detalii

### 1. Tabel complet de limite (2025-2026, sursă oficială)

| Componentă | Limită | Notă |
|---|---|---|
| Data (valoare per cheie) | 4.194.304 caractere (≈4 MB) | Serializat JSON; verifică cu `HttpService:JSONEncode()` |
| Nume data store | 50 caractere | |
| Nume cheie | 50 caractere | |
| Scope | 50 caractere | Legacy — preferă listare cu prefix pentru proiecte noi |
| Metadata: nume cheie | 50 caractere | |
| Metadata: valoare | 250 caractere | |
| Metadata: total perechi | 300 caractere | Fără limită de număr de perechi |
| Throughput citire per cheie | 25 MB/minut | Fereastră glisantă 60s, rotunjit la KB |
| Throughput scriere per cheie | 4 MB/minut | Idem |
| Coadă de request-uri | 30 request-uri/coadă | Peste asta → erori 301-306 |
| `BatchGetAsync` chei per request | implicit 100 (server-configurabil) | Doar pe `OrderedDataStore` |
| `GetSortedAsync` page size | 1-100 | |
| Stocare totală | 500 MB + 1 MB × lifetime users | Doar ultima versiune a fiecărei chei contează |
| Retenție versiuni suprascrise | 30 zile | Ultima versiune nu expiră |
| Cache local `GetAsync` | 4 secunde | Ocolibil cu `DataStoreGetOptions.UseCache = false` |
| `BindToClose` timeout total server | 30 secunde | Pentru toate funcțiile legate, rulate în paralel |

Sursă pentru tot tabelul: https://create.roblox.com/docs/cloud-services/data-stores/error-codes-and-limits, accesat 2026-09-08, excepție `BindToClose` de la https://create.roblox.com/docs/reference/engine/classes/DataModel.

### 2. Bugete de request-uri (per minut)

**La nivel de experience** (shared între toate serverele + Open Cloud):

| Tip | Standard DataStore | Ordered DataStore |
|---|---|---|
| Read | 300 + concurrentUsers × 40 | 300 + concurrentUsers × 40 |
| Write | 300 + concurrentUsers × 20 | 300 + concurrentUsers × 20 |
| List | 300 + concurrentUsers × 2 | 300 + concurrentUsers × 2 |
| Remove | 300 + concurrentUsers × 40 | 300 + concurrentUsers × 40 |

**La nivel de server individual** (implicit, dacă nu apelezi `SetRateLimitForRequestType`):

| Tip | Standard | Ordered |
|---|---|---|
| Read | 60 + numPlayers × 40 | 60 + numPlayers × 40 |
| Write | 60 + numPlayers × 40 | 30 + numPlayers × 5 |
| List | 5 + numPlayers × 2 | 5 + numPlayers × 2 |
| Remove | 60 + numPlayers × 40 | 30 + numPlayers × 5 |

`UpdateAsync()` consumă **din ambele** bugete (read + write) la fiecare apel. Pentru Driftwood, cu servere probabil de 10-30 jucători, bugetul de bază e generos pentru autosave la 2 minute + save la ieșire, dar **nu** e generos pentru polling frecvent al progresului orașului comun de către fiecare client.

Sursă: https://create.roblox.com/docs/cloud-services/data-stores/error-codes-and-limits, accesat 2026-09-08.

### 3. Coduri de eroare relevante și strategie de retry

Coduri **ne-retryabile** (bug de cod, nu se rezolvă prin retry):
- `101 KeyNameEmpty`, `102 KeyNameLimit` — cheie invalidă
- `103 ValueNotAllowed`, `104 CantStoreValue`, `105 ValueTooLarge` — tip/dimensiune de date invalidă
- `106 MaxValueInvalid/MinValueInvalid/PageSizeGreater/PageSizeLesser`, `107 MinMaxOrderInvalid` — parametri greșiți pentru `GetSortedAsync`

Coduri **retryabile** (throttling, tranzitoriu):
- `301-306` (*Throttle) — coada plină, request abandonat; retry cu backoff
- `StandardRead/Write/List/RemoveExperienceThrottled` și variantele `GameServerThrottled` — buget depășit
- `DatastoreThrottled`, `KeyThrottled` — trafic prea mare pe un data store/cheie specifică
- `InternalServerError`, coduri `501-505` — eroare tranzitorie pe partea Roblox; recomandare oficială: **retry cu exponential backoff**

Codurile `511 AttributeSizeTooLarge`, `512 UserIdLimitExceeded`, `513 AttributeFormatError` sunt legate strict de metadata/UserIds și indică o problemă de date, nu throttling.

Sursă: https://create.roblox.com/docs/cloud-services/data-stores/error-codes-and-limits, accesat 2026-09-08.

### 4. Semantica exactă a operațiilor

```lua
local DataStoreService = game:GetService("DataStoreService")
local store = DataStoreService:GetDataStore("PlayerGame")

-- SetAsync: suprascrie necondiționat. Rapid, dar riscant cu servere concurente.
store:SetAsync("User_1234", 50)

-- UpdateAsync: read-modify-write cu retry automat pe conflict.
-- Funcția de transform NU are voie să facă yield (fără task.wait()).
local newValue, keyInfo = store:UpdateAsync("User_1234", function(current, keyInfo)
    local userIds = keyInfo and keyInfo:GetUserIds() or {}
    local metadata = keyInfo and keyInfo:GetMetadata() or {}
    return (current or 0) + 10, userIds, metadata
end)

-- IncrementAsync: doar pentru valori întregi, echivalent scurt pentru UpdateAsync.
store:IncrementAsync("Player_1234", 1)

-- RemoveAsync: creează un "tombstone", GetAsync ulterior întoarce nil,
-- dar versiunile vechi rămân accesibile prin ListVersionsAsync/GetVersionAsync
-- până la ștergerea permanentă după 30 de zile.
local oldValue, keyInfo = store:RemoveAsync("User_1234")
```

Dacă funcția de transform din `UpdateAsync` întoarce `nil`, scrierea e **anulată** (nu eroare, doar niciun efect). Dacă alt server modifică cheia între citirea și scrierea ta, Roblox reapelează funcția de transform cu valoarea proaspătă — de câte ori e nevoie, până reușește sau primești `nil`. Asta face `UpdateAsync` sigur pentru concurrent access, **dar nu idempotent automat** — dacă funcția ta de transform are efecte secundare (ex. loghează un eveniment extern), acelea se pot executa de mai multe ori.

Sursă: https://create.roblox.com/docs/reference/engine/classes/GlobalDataStore, accesat 2026-09-08.

### 5. Versionare și rollback

```lua
local maxDate = DateTime.fromUniversalTime(2026, 09, 07, 12, 0)
local pages = store:ListVersionsAsync("User_1234", Enum.SortDirection.Descending, nil, maxDate.UnixTimestampMillis)
local items = pages:GetCurrentPage()
if #items > 0 then
    local value, keyInfo = store:GetVersionAsync("User_1234", items[1].Version)
    -- Restaurare: rescrie ca versiune nouă (nu există "rollback" nativ, doar suprascriere cu date vechi)
    local setOptions = Instance.new("DataStoreSetOptions")
    setOptions:SetMetadata(keyInfo:GetMetadata())
    store:SetAsync("User_1234", value, nil, setOptions)
end
```

Există și `GetVersionAtTimeAsync()` și `RemoveVersionAsync()`, menționate în error-codes-and-limits, dar nedetaliate separat în ghidul principal — util pentru unelte de administrare (ex. rollback pentru un jucător care reclamă pierdere de progres).

**Important**: versiunile se creează doar la **prima scriere per cheie în fiecare oră UTC**. Scrieri succesive în aceeași oră suprascriu, nu creează versiuni noi. Deci granularitatea de rollback e "cel mult o versiune pe oră", nu per-scriere.

Sursă: https://create.roblox.com/docs/cloud-services/data-stores/versioning-listing-and-caching, accesat 2026-09-08.

### 6. ProfileStore — API complet și cum se folosește

ProfileStore (github.com/MadStudioRoblox/ProfileStore, licență Apache-2.0) e un `ModuleScript` unic care rulează doar pe server. Se instalează fie din Roblox Library (link în tutorial), fie prin Wally (`lm-loleris/profilestore@1.0.3`), fie copiind `ProfileStore.luau` din GitHub.

**Modulul (nivel global):**
- `ProfileStore.New(store_name, template?) -> ProfileStore` — echivalentul `GetDataStore()`. `template` populează `Profile.Data` pentru profile noi (deep-copy).
- `ProfileStore.SetConstant(name, value)` — ajustare de constante interne (`AUTO_SAVE_PERIOD`, `SESSION_STEAL`, `ASSUME_DEAD`, etc.) pentru dezvoltatori avansați.
- `.IsClosing`, `.IsCriticalState`, `.OnError`, `.OnCriticalToggle`, `.DataStoreState` — semnale/proprietăți pentru monitorizare.

**Pe obiectul ProfileStore:**
- `:StartSessionAsync(profile_key, {Cancel = fn, Steal = bool}) -> Profile | nil` — pornește sesiunea cu session lock. `Cancel` e o funcție apelată repetat pentru a opri așteptarea dacă jucătorul a plecat deja (util când DataStore e lent). `Steal = true` **ocolește lock-ul** — doar pentru debugging, niciodată pentru logica normală de load.
- `:GetAsync(profile_key, version?) -> Profile | nil` — citire fără sesiune, fără auto-save, ideal pentru unelte de admin/citire read-only.
- `:MessageAsync(profile_key, message)` — trimite un mesaj către un profil indiferent dacă are sesiune activă acum; folosește 1-2 apeluri `UpdateAsync` — recomandat doar pentru date critice gen cadouri, nu pentru orice notificare (folosește `MessagingService` direct pentru restul).
- `:VersionQuery(profile_key, sort_direction?, min_date?, max_date?) -> VersionQuery` — wrapper peste `ListVersionsAsync` pentru rollback.
- `:RemoveAsync(profile_key)` — șterge profilul.
- `.Mock` — reflectă întregul API dar scrie pe date store-uri "fake", separate, uitate la shutdown-ul serverului. Recomandat pentru Studio.

**Pe obiectul Profile (după `StartSessionAsync`):**
- `.Data` — tabelul pe care îl citești/scrii; salvat automat cât timp `Profile:IsActive() == true`.
- `.LastSavedData` — ultima versiune confirmată ca salvată (util pentru verificare achiziții).
- `:IsActive()`, `:Reconcile()`, `:EndSession()`, `:Save()`, `:AddUserId()`/`:RemoveUserId()` (GDPR).
- Semnale: `.OnSave` (înainte de fiecare salvare), `.OnLastSave(reason: "Manual"|"External"|"Shutdown")` (ultima salvare — locul pentru penalizări la deconectare în combat, dacă ar fi cazul în Driftwood), `.OnSessionEnd` (nu mai modifica `Data` după asta), `.OnAfterSave(lastSavedData)`.

**Tipar standard de utilizare** (adaptat din tutorialul oficial):

```lua
local ProfileStore = require(game.ServerScriptService.ProfileStore)
local Players = game:GetService("Players")

local PROFILE_TEMPLATE = { Cash = 0, Items = {} }
local PlayerStore = ProfileStore.New("PlayerStore", PROFILE_TEMPLATE)
local Profiles: {[Player]: typeof(PlayerStore:StartSessionAsync())} = {}

local function onPlayerAdded(player)
    local profile = PlayerStore:StartSessionAsync(`{player.UserId}`, {
        Cancel = function() return player.Parent ~= Players end,
    })
    if profile ~= nil then
        profile:AddUserId(player.UserId) -- GDPR
        profile:Reconcile() -- completează câmpuri lipsă din template
        profile.OnSessionEnd:Connect(function()
            Profiles[player] = nil
            player:Kick(`Sesiunea de date s-a încheiat — te rog reintră`)
        end)
        if player.Parent == Players then
            Profiles[player] = profile
        else
            profile:EndSession()
        end
    else
        player:Kick(`Nu s-a putut încărca profilul — te rog reintră`)
    end
end

for _, player in Players:GetPlayers() do task.spawn(onPlayerAdded, player) end
Players.PlayerAdded:Connect(onPlayerAdded)
Players.PlayerRemoving:Connect(function(player)
    local profile = Profiles[player]
    if profile then profile:EndSession() end
end)
```

Sursă: https://madstudioroblox.github.io/ProfileStore/tutorial/ și /api/, accesate 2026-09-08.

### 7. De ce session locking, și de ce contează pentru Driftwood

Session locking rezolvă problema: doi jucători (sau același jucător pe două tab-uri/servere) accesează simultan același profil → ultima scriere câștigă, cealaltă se pierde, sau mai rău, poți crea "dupe"-uri de itemi dacă logica ta presupune greșit exclusivitate. ProfileStore ține evidența cărui server "deține" cheia și transferă lock-ul grațios când alt server cere sesiune (fără să eșueze noua cerere). Pentru Driftwood, cu economie server-authoritative și obiecte donate la atelierul orașului, session locking previne exact scenariul de duplicare a materialelor rare descris implicit în regulile CLAUDE.md ("server autoritar pentru orice ține de economie").

### 8. Problema specifică Driftwood: orașul comun (progres partajat pe server)

CLAUDE.md spune explicit: **"Tot serverul împarte același oraș"** și progresul de deblocare de zonă e "permanent, pentru toți jucătorii de pe server". Asta înseamnă că starea orașului **nu e per-jucător** — trebuie un data store separat, cu o cheie per instanță de oraș (posibil una singură, dacă Driftwood are un singur "oraș" logic per univers, sau una per server-shard dacă design-ul evoluează spre mai multe orașe).

Recomandare de implementare:

```lua
local CityStore = DataStoreService:GetDataStore("CityState")
local CITY_KEY = "MainTown" -- sau per-shard id, dacă apare nevoia

local function contributeToProject(playerUserId, projectId, itemId, contributionId)
    -- contributionId = id unic generat client-server (ex. tostring(playerUserId)..":"..os.time())
    -- folosit ca idempotency key, pentru că UpdateAsync poate re-executa transformFunction,
    -- iar un retry extern (al codului tău, nu al Roblox) ar putea aplica de două ori
    -- aceeași contribuție dacă nu verifici jurnalul.
    local ok, result = pcall(function()
        return CityStore:UpdateAsync(CITY_KEY, function(current)
            current = current or { Projects = {}, AppliedContributions = {} }
            if current.AppliedContributions[contributionId] then
                return current -- deja aplicată, nu duplica
            end
            current.AppliedContributions[contributionId] = true
            local project = current.Projects[projectId] or { Donated = {} }
            project.Donated[itemId] = (project.Donated[itemId] or 0) + 1
            current.Projects[projectId] = project
            return current
        end)
    end)
    return ok, result
end
```

`AppliedContributions` crește nemărginit în timp — pentru un joc real ar trebui curățat periodic (ex. păstrează doar ultimele N sau contribuțiile din ultimele 24h), altfel lovești limita de 4 MB per cheie. Alternativ: folosește chei separate per proiect de construcție (`CityState/Project_<id>`) ca să ții payload-urile mici.

### 9. OrderedDataStore pentru clasamente

Pentru orice clasament în Driftwood (ex. "top colectori săptămâna asta", "top donatori la atelier"):

```lua
local scoreStore = DataStoreService:GetOrderedDataStore("WeeklyDonations")
scoreStore:SetAsync(tostring(player.UserId), totalDonated)

local pages = scoreStore:GetSortedAsync(false, 10) -- descending, top 10
local top = pages:GetCurrentPage()
for rank, entry in ipairs(top) do
    print(entry.key, entry.value, rank)
end
```

`OrderedDataStore` **nu suportă versionare sau metadata** — `DataStoreKeyInfo` e mereu `nil`. Nu folosi `OrderedDataStore` pentru date de profil (ProfileStore chiar spune explicit că nu e proiectat pentru leaderboard-uri sau stare globală, deci clasamentele merg direct pe `DataStoreService`, nu prin ProfileStore).

### 10. Testare în Studio

1. File → Experience Settings → Security → activează **"Enable Studio Access to API Services"** (doar pe o versiune de test a jocului, nu pe live).
2. Folosește `ProfileStore.Mock` în Studio ca să nu scrii pe cheile live accidental:
```lua
local RunService = game:GetService("RunService")
local PlayerStore = ProfileStore.New("PlayerStore", PROFILE_TEMPLATE)
if RunService:IsStudio() then PlayerStore = PlayerStore.Mock end
```
3. Pentru teste de rate-limit realiste, Roblox recomandă explicit **Team Create** în loc de Run mode local — limitele din Run mode local sunt un set static separat, adesea mai restrictiv decât producția.

Sursă: https://create.roblox.com/docs/cloud-services/data-stores (secțiunea "Enable Studio access") și error-codes-and-limits, accesate 2026-09-08.

### 11. Open Cloud DataStore API — unelte de admin în afara jocului

API v2 curent, autentificare prin API Key în header `x-api-key`, bază `https://apis.roblox.com/cloud/v2/universes/{universe_id}/data-stores/...`. Endpoint-uri: List Data Stores, Delete/Undelete Data Store, List/Create/Get/Update/Delete/Increment Data Store Entry, List Data Store Entry Revisions, Snapshot Data Stores. Există și un set analog pentru Ordered Data Stores și Memory Stores. Endpoint-urile vechi `/datastores/v1/...` sunt marcate "Not Recommended".

**Atenție critică**: traficul Open Cloud și traficul din jocul live **consumă din același buget** per experience — un tool de admin care face polling agresiv poate throttle jucătorii reali și invers. Roblox recomandă fie un timeout simplu (`60 / budget_dorit` secunde între cereri), fie un leaky bucket rate limiter — cu exemplu de cod Node.js oficial în documentație.

Pentru unelte fără cod: **Data Stores Manager** din Creator Hub (Configure → Data Stores Manager) — browsing, editare, ștergere, comparare și revert de versiuni, direct din UI web, cu control de permisiuni per membru de grup (View/Edit/Delete Data Stores).

Sursă: https://create.roblox.com/docs/cloud/reference/DataStore și https://create.roblox.com/docs/cloud-services/data-stores/data-stores-manager, accesate 2026-09-08.

## Recomandari concrete pentru Driftwood

1. **Adoptă ProfileStore (nu ProfileService, nu cod custom peste DataStoreService) pentru toate datele de jucător.** Motiv: session locking gata implementat, adoptat la scară masivă, ProfileService e oficial descontinuat de propriul autor.
2. **Definește `PROFILE_TEMPLATE` complet încă din prototip** (vezi schema Luau de mai jos) și cheamă `profile:Reconcile()` la fiecare load. Motiv: orice câmp nou adăugat mai târziu (sezoane, index de reparații, etc.) se completează automat la jucătorii existenți fără cod de migrare manual.
3. **Nu ține progresul orașului comun în profilul de jucător.** Motiv: e stare partajată — trebuie DataStore separat, actualizat prin `UpdateAsync` cu jurnal de idempotență per contribuție, exact ca în secțiunea 8.
4. **Salvează la 2 minute (cum spune deja CLAUDE.md) + la `PlayerRemoving` + în `BindToClose`.** Motiv: `BindToClose` are doar 30 de secunde bugetate pentru shutdown — dacă salvarea periodică e la 2 minute, pierderea maximă de progres la un crash e limitată la acel interval; salvarea la `PlayerRemoving` acoperă ieșirea normală.
5. **Folosește `ProfileStore.Mock` în Studio, nu date live.** Motiv: elimină riscul de a strica progresul jucătorilor reali în timpul dezvoltării, fără să dezactivezi complet testarea persistenței.
6. **Pentru clasamente (top colectori, top donatori), folosește `OrderedDataStore` direct, separat de ProfileStore.** Motiv: ProfileStore explicit nu e făcut pentru asta; `GetSortedAsync` cu pagini de max 100 e suficient pentru orice clasament realist la scara unui joc nou.
7. **Nu construi propria logică de retry peste `UpdateAsync` fără idempotency key, mai ales pentru orice implică bani/materiale rare.** Motiv: un eșec de scriere nu garantează că backend-ul n-a aplicat totuși modificarea — retry naiv poate duplica resurse (exact tipul de bug pe care regula "server autoritar" din CLAUDE.md vrea să-l evite).
8. **Folosește Open Cloud v2, nu v1, dacă construiești vreodată un panou de admin extern** (ex. pentru suport clienți / rollback manual). Motiv: v1 e marcat oficial "Not Recommended", iar traficul lui consumă din același buget ca jocul live.
9. **Pentru rollback la incidente, exportă/verifică cu `ListVersionsAsync`/`GetVersionAsync` înainte de orice update major de schemă.** Motiv: versiunile expiră la 30 de zile — nu e un backup pe termen lung, dar acoperă incidente descoperite rapid.
10. **Nu depăși 4 KB-ul "practic" per profil de jucător** chiar dacă limita tehnică e 4 MB. Motiv: indexul de reparații are minim 200 de obiecte — dacă stochezi un tabel complet per obiect (nume, descriere, etc.) per jucător, riști să umfli inutil dimensiunea; stochează doar ID-uri de obiecte deblocate/reparate, nu date statice duplicate (acelea stau într-un `ModuleScript` de configurare, nu în DataStore).

## Schema de date Luau propusă pentru Driftwood

```lua
-- PlayerProfileTemplate.lua (ModuleScript, ServerScriptService)
-- Folosit ca al doilea argument la ProfileStore.New()

return {
    -- Meta / versiune schemă, pentru migrări viitoare mai complexe decât Reconcile()
    SchemaVersion = 1,

    -- Economie
    Cash = 0,

    -- Plase (câte deține jucătorul, nu poziția lor curentă — aia e stare de runtime)
    NetCount = 1,

    -- Acumulare offline: timestamp-ul ultimei deconectări/salvări reale,
    -- folosit la login pentru a calcula ce a "prins" plasa cât timp era offline,
    -- plafonat (ex. 8 ore) conform regulii din CLAUDE.md
    LastSeenUnix = 0,

    -- Atelier: sloturi disponibile (crescute prin Game Pass) și obiecte în reparație
    WorkshopSlots = 3,
    RepairQueue = {}, -- { [slotIndex] = { ItemId = string, StartedUnix = number, DurationSec = number } }

    -- Inventar de obiecte prinse/reparate/nedonate încă
    Inventory = {}, -- { [itemInstanceId] = { ItemId = string, Repaired = bool } }

    -- Index de reparații (colecție) — doar ID-uri, nu date statice despre obiect
    RepairIndex = {}, -- { [itemId] = true }  -- set de obiecte reparate cel puțin o dată

    -- Progres monetizare (owned game passes cache-uite local ca să eviți
    -- MarketplaceService:UserOwnsGamePassAsync() la fiecare check;
    -- sursa de adevăr rămâne totuși Marketplace, asta e doar cache)
    OwnedGamePasses = {}, -- { [gamePassId] = true }

    -- GDPR / audit
    FirstJoinUnix = 0,

    -- Sezon curent văzut de jucător (pentru UI "ce e nou în sezonul X")
    LastSeenSeasonId = "",
}
```

```lua
-- CityStateTemplate.lua — cheie separată, NU per jucător
return {
    SchemaVersion = 1,
    UnlockedZones = {}, -- { [zoneId] = true }
    Projects = {},      -- { [projectId] = { Donated = { [itemId] = count }, CompletedUnix = number|nil } }
    AppliedContributions = {}, -- idempotency ledger, vezi secțiunea 8; curăță periodic
}
```

```lua
-- PlayerDataService.lua (ServerScriptService) — schelet de implementare
local ProfileStore = require(script.Parent.ProfileStore)
local PROFILE_TEMPLATE = require(script.Parent.PlayerProfileTemplate)
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local PlayerStore = ProfileStore.New("PlayerStore_v1", PROFILE_TEMPLATE)
if RunService:IsStudio() then
    PlayerStore = PlayerStore.Mock
end

local Profiles: {[Player]: any} = {}

local OFFLINE_CAP_SECONDS = 8 * 3600

local function applyOfflineAccumulation(profile)
    local now = os.time()
    local elapsed = math.clamp(now - profile.Data.LastSeenUnix, 0, OFFLINE_CAP_SECONDS)
    -- TODO: calculează ce au prins plasele în `elapsed` secunde, aplică la Inventory
    profile.Data.LastSeenUnix = now
end

local function onPlayerAdded(player)
    local profile = PlayerStore:StartSessionAsync(`{player.UserId}`, {
        Cancel = function() return player.Parent ~= Players end,
    })
    if not profile then
        player:Kick("Nu s-a putut încărca profilul. Te rog reintră.")
        return
    end
    profile:AddUserId(player.UserId)
    profile:Reconcile()
    if profile.Data.FirstJoinUnix == 0 then
        profile.Data.FirstJoinUnix = os.time()
    end
    applyOfflineAccumulation(profile)

    profile.OnSessionEnd:Connect(function()
        Profiles[player] = nil
        player:Kick("Sesiunea de date s-a încheiat pe alt server. Te rog reintră.")
    end)

    if player.Parent ~= Players then
        profile:EndSession()
        return
    end
    Profiles[player] = profile
end

for _, player in Players:GetPlayers() do
    task.spawn(onPlayerAdded, player)
end
Players.PlayerAdded:Connect(onPlayerAdded)

Players.PlayerRemoving:Connect(function(player)
    local profile = Profiles[player]
    if profile then
        profile.Data.LastSeenUnix = os.time()
        profile:EndSession()
    end
end)

-- Autosave suplimentar la 2 minute, pe lângă cel intern al ProfileStore (300s),
-- dacă vrei un interval mai agresiv conform regulii din CLAUDE.md:
task.spawn(function()
    while true do
        task.wait(120)
        for player, profile in pairs(Profiles) do
            if profile:IsActive() then
                profile.Data.LastSeenUnix = os.time()
                profile:Save()
            end
        end
    end
end)

game:BindToClose(function()
    if RunService:IsStudio() then return end
    local remaining = 0
    for _, profile in pairs(Profiles) do
        if profile:IsActive() then
            remaining += 1
            task.spawn(function()
                profile:EndSession()
                remaining -= 1
            end)
        end
    end
    while remaining > 0 do
        task.wait(0.1)
    end
end)
```

Notă: apelul suplimentar `profile:Save()` la fiecare 2 minute costă câte un `UpdateAsync` per jucător activ — la o experiență cu multe servere/jucători simultan, verifică bugetul din secțiunea 2 înainte să scazi intervalul sub 120s. Auto-save-ul intern al ProfileStore (300s) singur ar fi suficient pentru majoritatea cazurilor; intervalul de 2 minute din CLAUDE.md e o marjă de siguranță suplimentară, nu o necesitate tehnică dictată de ProfileStore.

## Riscuri si necunoscute

- **Orașul comun per "server" vs. un singur oraș global**: CLAUDE.md zice "tot serverul împarte același oraș", dar Roblox rulează multe instanțe de server în paralel pentru aceeași experience. Dacă intenția e **un singur oraș pentru tot jocul** (nu unul per instanță de server), atunci toate serverele trebuie să scrie pe *aceeași* cheie DataStore, ceea ce crește mult riscul de conflict la `UpdateAsync` (retry-uri dese) la scară. Dacă intenția e **un oraș per server-instanță** (fiecare shard/server are propriul oraș, resetat la fiecare sesiune de server), arhitectura e mult mai simplă dar contravine textului din CLAUDE.md. **Trebuie clarificat cu owner-ul înainte de a implementa pasul 5 (atelierul orașului) din ordinea de lucru.**
- **`AppliedContributions` (jurnal idempotență) crește nemărginit** — fără o strategie de curățare (TTL, arhivare, sau chei separate per fereastră de timp), va lovi limita de 4 MB per cheie pe termen lung, la scară.
- Nu am putut verifica un istoric complet de release-uri/changelog pentru ProfileStore (pagina GitHub Releases nu conține release-uri publicate separat de commit-uri) — versiunea Wally confirmată e 1.0.3, dar data exactă a acelei versiuni: **NEVERIFICAT**.
- Numărul exact de stele/adopție curentă pe GitHub pentru ProfileStore la data cercetării (333 la un moment din fetch) e o cifră care se schimbă constant — **nu o cita ca fixă în masterplan**, doar ca ordin de mărime.
- Nu există în documentația oficială curentă o mențiune explicită a unui "write cooldown de 6 secunde per cheie" (regulă veche, larg citată în tutoriale mai vechi de comunitate). Tratez asta ca **înlocuit** de sistemul de throughput (4 MB/min scriere) — dar dacă găsești comportament neașteptat de throttling la scriere rapidă repetată pe aceeași cheie în Studio, testează explicit înainte de a presupune că regula veche a dispărut complet.
- `SetRateLimitForRequestType` afectează doar limitele **per server**, nu pe cele per experience — la scară mică (jocul nou, puțini jucători), probabil nu ai nevoie să-l atingi deloc.

## Intrebari deschise

1. Un singur oraș global pentru tot jocul, sau un oraș per instanță de server (shard)? Decizia asta schimbă complet arhitectura din secțiunea 8 și trebuie luată înainte de pasul 5 din ordinea de lucru din CLAUDE.md.
2. Ce se întâmplă cu progresul orașului comun când Roblox face un release de update și toate serverele vechi se opresc simultan (`ServerRestartScheduled`)? Trebuie testat explicit în Studio/Team Create dacă `UpdateAsync` concurent de la mai multe servere pe aceeași cheie de oraș produce retry-uri vizibile la scară mică (ex. 3-5 servere de test).
3. Cât de mare va deveni realist un profil de jucător cu 200+ obiecte în indexul de reparații plus inventar plus coadă de reparații? Trebuie măsurat cu `HttpService:JSONEncode()` pe un profil "plin" de test, ca să confirmi că rămâi confortabil sub 4 MB (probabil nicio problemă, dar de verificat, nu presupus).
4. Merită folosit `DataStoreOptions` cu `AllScopes` pentru organizarea datelor de sezon (ex. un scope per sezon), sau e suficientă listarea cu prefix recomandată pentru proiecte noi? Necesită o decizie de design înainte de a implementa sezoanele (pasul 7).
5. Cât de des vrei să update-uiești clasamentele (OrderedDataStore) — la fiecare donație, sau batched la interval fix? Frecvența afectează bugetul de write per server, mai ales dacă un eveniment ca Inundația generează activitate în rafală.

## Surse

- Data stores (ghid principal) — https://create.roblox.com/docs/cloud-services/data-stores — accesat 2026-09-08
- Data store error codes and limits — https://create.roblox.com/docs/cloud-services/data-stores/error-codes-and-limits — accesat 2026-09-08
- Data store versioning, listing, and caching — https://create.roblox.com/docs/cloud-services/data-stores/versioning-listing-and-caching — accesat 2026-09-08
- GlobalDataStore (referință API) — https://create.roblox.com/docs/reference/engine/classes/GlobalDataStore — accesat 2026-09-08
- DataStoreService (referință API) — https://create.roblox.com/docs/reference/engine/classes/DataStoreService — accesat 2026-09-08
- DataModel — BindToClose — https://create.roblox.com/docs/reference/engine/classes/DataModel — accesat 2026-09-08
- Data and memory stores (Open Cloud v2 API, listă endpoint-uri) — https://create.roblox.com/docs/cloud/reference/DataStore — accesat 2026-09-08
- Data Stores Manager — https://create.roblox.com/docs/cloud-services/data-stores/data-stores-manager — accesat 2026-09-08
- ProfileStore — repo GitHub (MadStudioRoblox) — https://github.com/MadStudioRoblox/ProfileStore — accesat 2026-09-08
- ProfileStore — documentație API completă — https://madstudioroblox.github.io/ProfileStore/api/ — accesat 2026-09-08
- ProfileStore — tutorial oficial — https://madstudioroblox.github.io/ProfileStore/tutorial/ — accesat 2026-09-08
- ProfileStore — wally.toml (raw) — https://raw.githubusercontent.com/MadStudioRoblox/ProfileStore/main/wally.toml — accesat 2026-09-08
- "ProfileStore - Save your player data easy and safe (DataStore Module)" — DevForum, autor loleris — https://devforum.roblox.com/t/profilestore-save-your-player-data-easy-and-safe-datastore-module/3190543 — publicat 11 octombrie 2024, accesat 2026-09-08
- ProfileService — repo GitHub (MadStudioRoblox, descontinuat) — https://github.com/MadStudioRoblox/ProfileService — accesat 2026-09-08
- Proiect Driftwood — brief intern — /Users/tiberiubojan/Downloads/CLAUDE.md — context, nu sursă externă

## Verificare independenta (2026-09-08)

Verificare efectuată independent pe 2026-09-09, prin fetch direct al surselor primare (create.roblox.com/docs, github.com/Roblox/creator-docs, github.com/MadStudioRoblox, devforum.roblox.com, en.wikipedia.org). Toate cele 15 afirmații verificate s-au confirmat ca fiind corecte și curente — nu a fost necesară nicio corecție în corpul notei.

| Afirmație | Verdict | Valoare corectă | Sursă (URL, dată) |
|---|---|---|---|
| Limită valoare per cheie: 4.194.304 caractere (~4 MB) | CONFIRMAT | 4.194.304 caractere per cheie | https://create.roblox.com/docs/cloud-services/data-stores/error-codes-and-limits — verificat 2026-09-09 |
| Nume data store / nume cheie / scope: max 50 caractere fiecare | CONFIRMAT | 50 caractere fiecare | https://create.roblox.com/docs/cloud-services/data-stores/error-codes-and-limits — verificat 2026-09-09 |
| Metadata: cheie max 50, valoare max 250, total perechi max 300 caractere | CONFIRMAT | 50 / 250 / 300 caractere | https://create.roblox.com/docs/cloud-services/data-stores/error-codes-and-limits — verificat 2026-09-09 |
| Throughput per cheie: citire 25 MB/min, scriere 4 MB/min (fereastră 60s) | CONFIRMAT | 25 MB/min citire, 4 MB/min scriere | https://create.roblox.com/docs/cloud-services/data-stores/error-codes-and-limits — verificat 2026-09-09 |
| Coadă de request-uri: limită 30/coadă, peste asta erori 301-306 | CONFIRMAT | 30 request-uri per coadă | https://create.roblox.com/docs/cloud-services/data-stores/error-codes-and-limits — verificat 2026-09-09 |
| Buget per experience: Read=300+CCU×40, Write=300+CCU×20, List=300+CCU×2, Remove=300+CCU×40 | CONFIRMAT | Formulele din notă sunt exacte (valorile curente; un anunț anterior din apr. 2025 propusese provizoriu 250+CCU×40, ulterior ajustat la 300 în documentația live) | https://create.roblox.com/docs/cloud-services/data-stores/error-codes-and-limits — verificat 2026-09-09; context: https://devforum.roblox.com/t/datastores-access-and-storage-updates/3597255 (7 apr. 2025) |
| Buget implicit per server: Standard R/W/Remove=60+players×40, List=5+players×2; Ordered Write=30+players×5 | CONFIRMAT | Formulele din notă sunt exacte | https://create.roblox.com/docs/cloud-services/data-stores/error-codes-and-limits — verificat 2026-09-09 |
| Stocare totală: 500 MB + 1 MB × lifetime unique users (pe dimensiunea comprimată) | CONFIRMAT | 500 MB + 1 MB/utilizator unic — în vigoare din 29 iulie 2026 (anterior fusese 100 MB + 1 MB/utilizator, conform anunțului din apr. 2025) | https://create.roblox.com/docs/cloud-services/data-stores/error-codes-and-limits — verificat 2026-09-09; https://devforum.roblox.com/t/unifying-data-stores-open-cloud-and-game-apis-and-increasing-storage-limits/4739240 (15 iul. 2026) |
| Retenție versiuni: 30 zile după suprascriere; versiune nouă doar la prima scriere/cheie/oră UTC | CONFIRMAT | 30 zile; ultima versiune nu expiră niciodată | https://create.roblox.com/docs/cloud-services/data-stores/versioning-listing-and-caching — verificat 2026-09-09 |
| Cache local `GetAsync`: 4 secunde, ocolibil cu `DataStoreGetOptions.UseCache=false` | CONFIRMAT | 4 secunde | https://create.roblox.com/docs/cloud-services/data-stores/versioning-listing-and-caching — verificat 2026-09-09 |
| `UpdateAsync`: transform function rechemată automat la conflict, `nil` anulează scrierea, funcția nu are voie să facă yield | CONFIRMAT | Exact ca în notă | https://github.com/Roblox/creator-docs/blob/main/content/en-us/reference/engine/classes/GlobalDataStore.yaml — verificat 2026-09-09 |
| `BindToClose`: server așteaptă max 30 secunde total, funcțiile multiple rulează în paralel | CONFIRMAT | 30 secunde, paralel | https://create.roblox.com/docs/reference/engine/classes/DataModel — verificat 2026-09-09 |
| `BatchGetAsync`: max 100 chei implicit (configurabil server-side), doar pe `OrderedDataStore` | CONFIRMAT | 100 chei implicit, eroare pe `DataStore` standard | https://github.com/Roblox/creator-docs/blob/main/content/en-us/reference/engine/classes/GlobalDataStore.yaml — verificat 2026-09-09 |
| ProfileStore: auto-save implicit crescut de la 30s (ProfileService) la 300s | CONFIRMAT | 300 secunde | https://devforum.roblox.com/t/profilestore-save-your-player-data-easy-and-safe-datastore-module/3190543 — verificat 2026-09-09 |
| ProfileService README: "This project is no longer supported", recomandă migrarea la ProfileStore | CONFIRMAT | Citat exact confirmat | https://github.com/MadStudioRoblox/ProfileService — verificat 2026-09-09 |
| Grow a Garden a lansat abia pe 26 martie 2025 (folosit în notă pentru a corecta atribuirea de dată a mențiunii ProfileStore din postarea DevForum) | CONFIRMAT | 26 martie 2025 | https://en.wikipedia.org/wiki/Grow_a_Garden — verificat 2026-09-09 |

Notă metodologică: pentru claim-urile de comportament API (`UpdateAsync`, `BatchGetAsync`) paginile de referință randate pe create.roblox.com nu au putut fi extrase complet cu unelte automate (conțin doar semnătura metodei, fără corpul descriptiv), așa că verificarea s-a făcut pe sursa YAML brută din repo-ul oficial `Roblox/creator-docs` de pe GitHub, care alimentează exact aceleași pagini — considerată sursă primară echivalentă.
