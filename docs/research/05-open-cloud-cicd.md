# Open Cloud și CI/CD pentru Driftwood

## Rezumat executiv

- Open Cloud e familia de REST API-uri oficiale ale Roblox (`apis.roblox.com`), cu autentificare prin **API keys** sau **OAuth2**, distinctă de „Legacy APIs" (cookie-based, fără garanții de stabilitate). Pentru orice automatizare de CI/CD trebuie folosit Open Cloud, nu Legacy.
- Pentru un pipeline de CI/CD solo-dev, **API key simplu** (creat din Creator Dashboard) e mecanismul corect — OAuth2 apps sunt pentru aplicații terțe cu utilizatori multipli care se autentifică cu contul Roblox propriu, nu pentru un script de deploy.
- Publicarea unui `.rbxl` se face printr-un singur `POST` la `apis.roblox.com/universes/v1/{universeId}/places/{placeId}/versions?versionType=Published`, cu fișierul trimis binar în body. Rojo CLI are deja comanda `rojo upload` care face exact asta.
- **Mantle** (tool-ul de infra-as-code pentru Roblox, folosit des în tutoriale mai vechi) este oficial neîntreținut — nu se recomandă pentru un proiect nou în 2026.
- Exemplul oficial de CI/CD publicat de Roblox însuși (`Roblox/place-ci-cd-demo`, repo activ) **nu folosește Mantle și nu folosește rbxcloud** — folosește Rojo direct (`rojo upload`) + Foreman + Selene + StyLua + Luau Execution API pentru teste. Ăsta e cel mai autoritar semnal despre „calea recomandată" în acest moment.
- Pattern-ul oficial Roblox pentru staging vs. producție este **universuri (experiențe) separate**, cu ID-uri distincte de universe/place — nu doar place-uri diferite în același universe.
- API-ul de **Luau Execution** permite rulare de teste automate headless într-un place, dar sursele oficiale se contrazic pe limita de concurență (2 vs. 10 task-uri concurente) — de verificat practic înainte de a te baza pe el masiv.
- **Secrets Store** + `HttpService:GetSecret()` e mecanismul Roblox nativ pentru chei/secrete accesate din interiorul jocului (runtime), nu pentru pipeline-ul CI în sine — pentru CI, secretele stau în GitHub Actions Secrets.
- Limitele DataStore (inclusiv cele accesate via Open Cloud v1) sunt formule dependente de numărul de jucători concurenți, nu constante fixe — relevant pentru Driftwood pentru că economia e server-authoritative și va lovi aceste cote.
- Rollback-ul de place se face din **Version History** (Studio sau Creator Dashboard) — creează o versiune nouă din una veche, nu republică automat live.

## Fapte verificate

- Roblox a lansat documentație unificată Open Cloud (organizată pe „Features" și pe „Domains") — anunț actualizat 13 martie 2026. Sursă: https://devforum.roblox.com/t/your-brand-new-cloud-api-reference-documentation-is-here/4139597 (13 martie 2026); confidence: ridicata.
- Toate endpoint-urile Open Cloud moderne suportă autentificare prin API key sau OAuth2; Legacy APIs folosesc cookie și „pot include breaking changes fără notificare". Sursă: https://create.roblox.com/docs/cloud (verificat 8 sept 2026); confidence: ridicata.
- Cheile API se creează din Creator Dashboard, pot fi restricționate la un joc anume, la un set de scope-uri, la IP-uri (notație CIDR, ex. `192.168.0.0/24`) și la o dată de expirare; dacă o cheie nu e folosită/actualizată 60 de zile, expiră automat. Sursă: https://create.roblox.com/docs/cloud/auth/api-keys (verificat 8 sept 2026); confidence: ridicata.
- Documentația avertizează explicit să NU pui restricție de IP pe o cheie folosită din interiorul unui place Roblox (server-side, din joc), pentru că IP-urile serverelor Roblox nu sunt fixe/predictibile. Sursă: https://create.roblox.com/docs/cloud/auth/api-keys; confidence: ridicata.
- OAuth2: access token valid 15 minute, refresh token valid 90 de zile (folosibil o singură dată pentru a genera un token nou), authorization code valid 1 minut (folosibil o singură dată). Sursă: https://create.roblox.com/docs/cloud/auth/oauth2-reference (verificat 8 sept 2026); confidence: ridicata.
- Place Publishing API: `POST https://apis.roblox.com/universes/v1/{universeId}/places/{placeId}/versions?versionType=Published`, header `x-api-key: <key>`, `Content-Type: application/octet-stream` pentru `.rbxl` sau `application/xml` pentru `.rbxlx`, body = fișierul binar (`--data-binary`). Scope necesar: `universe-places` (Write). Răspuns: `{"versionNumber": N}`. Sursă: https://github.com/Roblox/creator-docs/blob/main/content/en-us/cloud/guides/usage-place-publishing.md (verificat 8 sept 2026); confidence: ridicata.
- Limita de mărime pentru place-uri publicate prin Studio e 100 MB (104.857.600 bytes); peste asta, „Save to Roblox" și „Publish to Roblox" pot eșua. Nu am găsit un număr separat, documentat explicit pentru limita de mărime specifică Open Cloud (poate diferi ușor). Sursă: https://create.roblox.com/docs/production/publishing/publish-experiences-and-places (verificat 8 sept 2026); confidence: medie — limita exactă pt Open Cloud e NEVERIFICAT.
- Mantle: „Mantle is no longer maintained. Do not expect responses to tickets, bug fixes, or new features." Sursă: https://github.com/blake-mealey/mantle (README, verificat 8 sept 2026); confidence: ridicata.
- Repo-ul oficial `Roblox/place-ci-cd-demo` demonstrează CI/CD cu Rojo (`rojo upload`), Selene (lint), StyLua (format) și Luau Execution API pentru teste; branch de deploy = `production`; folosește `Roblox/setup-foreman@v1` pentru instalare unelte. Sursă: https://github.com/Roblox/place-ci-cd-demo (README + `.github/workflows/cicd.yml`, verificat 8 sept 2026); confidence: ridicata.
- Exemplul oficial Roblox folosește un universe/place de test SEPARAT de cel de producție (`ROBLOX_TEST_UNIVERSE_ID`/`ROBLOX_TEST_PLACE_ID` vs `ROBLOX_PRODUCTION_UNIVERSE_ID`/`ROBLOX_PRODUCTION_PLACE_ID`), nu doar un place secundar în același universe. Sursă: idem, README secțiunea „How to setup"; confidence: ridicata.
- „The Engine Open Cloud API for Executing Luau is currently limited to two concurrent request per universe" — citat direct din README-ul oficial Roblox, cu mențiunea că echipa vrea să ridice limita în viitor. Sursă: https://github.com/Roblox/place-ci-cd-demo (verificat 8 sept 2026); confidence: ridicata. **Contrazice** o altă sursă (rezumat WebSearch al paginii de doc Luau Execution) care menționează „limit of 10 concurrent tasks per place, max 5 minutes per task" — sursa exactă a acelui număr nu a putut fi confirmată direct din pagina oficială la fetch (pagina a răspuns cu conținut insuficient pentru extragere completă); confidence: scazuta pentru cifra de 10.
- MemoryStore prin Open Cloud suportă doar **Queues** și **Sorted Maps**, nu și **HashMaps** (HashMaps există doar în API-ul in-game `MemoryStoreService`). Sursă: https://devforum.roblox.com/t/hashmap-support-for-open-cloud-memory-stores-api/4589938 + https://github.com/Roblox/creator-docs/blob/main/content/en-us/cloud-services/memory-stores/index.md (verificat 8 sept 2026); confidence: medie.
- Messaging API v2: `POST https://apis.roblox.com/cloud/v2/universes/{universe}:publishMessage`, body JSON `{"topic": "...", "message": "..."}`, header `Authorization: Bearer <token>` (sau `x-api-key`). Scope necesar: `universe-messaging-service:publish`. Sursă: https://create.roblox.com/docs/cloud/guides/usage-messaging (verificat 8 sept 2026); confidence: ridicata.
- Limite DataStore (in-game, aplicabile și cotei partajate cu Open Cloud v1): Read `300 + concurrentUsers×40`/min, Write `300 + concurrentUsers×20`/min, List `300 + concurrentUsers×2`/min; valoare max per cheie 4.194.304 bytes (4 MB); storage total = `500 MB + 1 MB × lifetime user count`. Sursă: https://github.com/Roblox/creator-docs/blob/main/content/en-us/cloud-services/data-stores/error-codes-and-limits.md (verificat 8 sept 2026); confidence: ridicata. Notă: baza de stocare a crescut recent de la 100 MB la 500 MB (schimbare semnalată iulie 2026) — posibil ca surse mai vechi să arate încă 100 MB; confidence pentru schimbarea recentă: medie (sursă secundară: bloxbot.ai/guide/roblox-datastore-limits-july-2026).
- Apelurile Open Cloud v1 pentru DataStore și apelurile in-game (`DataStoreService`) **partajează aceeași cotă/counter** per tip de request. Sursă: rezumat din căutare pe baza https://create.roblox.com/docs/cloud/guides/data-stores/throttling (verificat 8 sept 2026); confidence: medie.
- Rate limits generale Open Cloud: pentru API keys, limita se aplică „across all API keys per owner" (user sau grup); pentru OAuth2, limita e per access token. Header-e de monitorizare: `x-ratelimit-limit`, `x-ratelimit-remaining`, `x-ratelimit-reset`. Sursă: https://create.roblox.com/docs/cloud/reference/rate-limits (verificat 8 sept 2026); confidence: ridicata.
- Version History: rollback-ul (din Studio: Window → Version History → „Open Local Copy" → File → Save to Roblox As) creează o versiune NOUĂ suprapusă peste live; restaurarea NU republică automat serverele live — trebuie publicat manual și eventual repornite serverele. Sursă: https://create.roblox.com/docs/projects/version-history (verificat 8 sept 2026); confidence: ridicata.
- Secrets Store: `HttpService:GetSecret()` citește un secret setat la nivel de experience via Open Cloud sau (pentru testare locală) din Studio → File → Experience Settings → Security → Local Secrets; necesită „Allow HTTP Requests" activat. Secretul nu e printabil/afișabil în cod. Sursă: https://create.roblox.com/docs/cloud-services/secrets (verificat 8 sept 2026); confidence: ridicata.
- Open Cloud Assets API: creare/update de asset per call — limită de mărime raportată în documentație ca 20 MB, dar un angajat Roblox a indicat 30 MB ca limită reală în practică (discrepanță confirmată în forum); decal-urile trebuie sub 8000×8000 px și nu pot fi actualizate (doar create). Sursă: https://devforum.roblox.com/t/add-an-open-cloud-endpoint-for-uploading-roblox-models-and-plugins/2668833 + https://create.roblox.com/docs/cloud/guides/usage-assets (verificat 8 sept 2026); confidence: medie (discrepanță semnalată explicit).
- DevEx: rata standard e $0.0038/Robux (efectivă din 5 septembrie 2025, +8,5% față de $0.0035 anterior), minim 30.000 Robux/cash-out. Există și o rată separată, mai mare, de $0.0054/Robux, dar **doar** pentru „US 18+ eligible in-game spend", efectivă din 8 iunie 2026 — nu se aplică automat tuturor încasărilor. Sursă: https://create.roblox.com/docs/production/monetization/developer-exchange (verificat 8 sept 2026, sursă secundară de sinteză generalistprogrammer.com pt datele exacte); confidence: medie — recomand verificare directă pe pagina oficială înainte de a proiecta modelul financiar.
- Open Cloud „Engine API for Updating Scripts" (permite update la `Source` pe Script/LocalScript/ModuleScript direct, fără publish complet de place) e în beta din 13 februarie 2024, funcționează doar pe experiențe cu Team Create activ, editează sesiunea Team Create (nu serverele live direct), necesită minim 2 apeluri (async). Sursă: https://devforum.roblox.com/t/open-cloud-engine-api-for-updating-scripts-beta/2836619 (13 feb 2024) — **sursă din 2024, posibil depășită/actualizată între timp**; confidence: scazuta pentru statusul curent (2026).

## Detalii

### 1. Harta API-urilor Open Cloud relevante pentru Driftwood

| Domeniu | Ce face | Endpoint / mecanism | Auth | Note |
|---|---|---|---|---|
| Places (publish) | Publică un `.rbxl`/`.rbxlx` ca noua versiune a unui place | `POST /universes/v1/{universeId}/places/{placeId}/versions?versionType=Published` (`apis.roblox.com`) | API key (`x-api-key`) sau OAuth2 | Scope: `universe-places` write. Folosit de `rojo upload`. |
| DataStore | Citește/scrie/listează chei în DataStore-uri, din afara jocului | `apis.roblox.com/datastores/v1/...` (v1) și variante v2 | API key / OAuth2 | Partajează cota cu apelurile in-game din `DataStoreService`. Util pentru unelte admin/migrări de date offline pentru Driftwood, NU pentru operare normală în joc. |
| MemoryStore | Queues și Sorted Maps peste rețea | `apis.roblox.com` (cloud v2, memory-store) | API key / OAuth2 | Fără HashMaps prin Open Cloud. |
| Messaging | Trimite mesaje cross-server prin `MessagingService` | `POST /cloud/v2/universes/{universe}:publishMessage` | API key / OAuth2 | Scope `universe-messaging-service:publish`; topicul trebuie subscris în joc via `MessagingService:SubscribeAsync()`. Util pt. a anunța din CI un eveniment (ex. „Inundația" din brief) fără redeploy. |
| Luau Execution | Rulează cod Luau headless într-un place, pentru teste automate/config | `apis.roblox.com/cloud/v2/universes/{universeId}/places/{placeId}/luau-execution-session-tasks` (+ variante binary-inputs) | API key / OAuth2 | Max 5 min/task (raportat); concurență limitată — vezi discrepanța de mai sus. Baza CI de teste automate din exemplul oficial Roblox. |
| Groups | Citire (și parțial scriere) date de grup, roluri | Open Cloud Groups API (beta, lansat cu Users API) | API key / OAuth2 | Relevant doar dacă Driftwood publică sub un grup Roblox (recomandat pentru multi-owner/DevEx pe echipă). |
| Inventory | Listează obiectele deținute de un user (game passes, badges etc.) | Open Cloud Inventory API (beta) | API key / OAuth2 | Util pentru validare server-side a deținerii de Game Passes fără a te baza doar pe `MarketplaceService` in-game. Semnalată ca având probleme de acuratețe/actualizare în forum (2026). |
| Assets | Upload/update de assets (modele, decaluri, animații) | Open Cloud Assets API | API key / OAuth2 | Limită ~20-30 MB/asset (discrepanță documentată); decal max 8000×8000 px. |
| Engine API (script update) | Editează `Source` pe scripturi direct în sesiunea Team Create | Open Cloud „Instance"/script endpoints | API key / OAuth2 | Beta din 2024, doar Team Create, nu afectează serverele live direct — NU e un înlocuitor pentru publish. |

„Engine API" ca termen generic în documentația 2026 desemnează familia modernă Open Cloud (auth API key/OAuth2, garanții de stabilitate), în opoziție cu „Legacy APIs" (cookie-based, fără garanții). Nu e un produs separat de „Open Cloud" — e denumirea folosită acum pentru tot ce ține de acces programatic la engine/platformă. Sursă: https://create.roblox.com/docs/cloud (verificat 8 sept 2026).

### 2. Autentificare: API key vs OAuth2 — ce alegi pentru Driftwood

Pentru pipeline-ul de CI/CD (GitHub Actions rulând fără interacțiune umană), **API key** e alegerea corectă:

- Creezi cheia din Creator Dashboard → API Keys.
- Îi dai un nume descriptiv per scop (ex. `driftwood-ci-staging-publish`, `driftwood-ci-luau-tests`) — recomandarea oficială e o cheie separată per aplicație/utilizare, nu una singură universală.
- Restrângi scope-urile la minimul necesar (pentru publish: `universe-places` write pe place-ul de staging; pentru teste: `universe.place.luau-execution-session:write`).
- Restrângi accesul la jocul/universul specific (nu „toate jocurile mele").
- **NU** pui restricție de IP dacă vrei să rulezi din GitHub-hosted runners (IP-uri dinamice) — restricția de IP e utilă doar dacă rulezi pe un runner self-hosted cu IP static.
- Cheia expiră automat după 60 de zile de neutilizare — dacă pipeline-ul rulează rar, ai nevoie de un cron/keep-alive sau just accepți regenerarea periodică.

OAuth2 apps sunt pentru cazul în care construiești un produs terț pe care alți useri Roblox și-l conectează la contul lor (ex. un dashboard SaaS pentru alți dezvoltatori). Nu se potrivește modelului „un singur owner, un pipeline de deploy propriu".

### 3. Publicarea unui `.rbxl` din CI

Există trei căi echivalente, în ordine de recomandare pentru Driftwood:

**A. `rojo upload` (calea folosită de Roblox însuși în exemplul oficial):**

```bash
rojo upload default.project.json \
  --api_key "$ROBLOX_API_KEY" \
  --universe_id "$ROBLOX_UNIVERSE_ID" \
  --asset_id "$ROBLOX_PLACE_ID"
```

Rojo construiește intern `.rbxl`-ul din proiectul Rojo (`default.project.json`) și îl trimite direct la endpoint-ul de mai sus. Nu ai nevoie de un pas separat de „build apoi upload" dacă folosești `rojo upload` — dar poți și separa cu `rojo build -o place.rbxl` urmat de un `curl` manual.

**B. `curl` direct (control maxim, zero dependențe suplimentare):**

```bash
curl -sSL --fail \
  --header "x-api-key: $ROBLOX_API_KEY" \
  --header "Content-Type: application/octet-stream" \
  --data-binary "@place.rbxl" \
  --request POST \
  "https://apis.roblox.com/universes/v1/${ROBLOX_UNIVERSE_ID}/places/${ROBLOX_PLACE_ID}/versions?versionType=Published"
```

**C. `rbxcloud` CLI (Rust, Sleitnick):**

```bash
rbxcloud experience publish \
  --filename place.rbxl \
  --place-id "$ROBLOX_PLACE_ID" \
  --universe-id "$ROBLOX_UNIVERSE_ID" \
  --version-type published \
  --api-key "$ROBLOX_API_KEY"
```

`rbxcloud` acoperă și DataStore, MemoryStore, Messaging, Luau Execution, Assets, Groups, Inventory, User — deci e util dacă vrei un singur binar pentru toate operațiile Open Cloud din pipeline, nu doar publish. Sursă: https://sleitnick.github.io/rbxcloud/ (verificat 8 sept 2026).

**De evitat:** Mantle — neîntreținut, risc de breaking changes necorectate dacă Roblox schimbă API-ul.

Parametrul `versionType` acceptă `Published` (devine versiunea live, vizibilă jucătorilor) sau `Saved` (salvează o versiune fără a o face live) — al doilea e util pentru un pas de „build & save" fără a expune imediat schimbarea.

### 4. Environments: staging/prod ca universuri separate

Exemplul oficial Roblox (`place-ci-cd-demo`) tratează test și producție ca **experiențe (universuri) complet separate**, fiecare cu propriul `universeId`/`placeId`, nu ca două place-uri în același universe. Motivul practic: un universe separat izolează complet DataStore-urile (cheile de DataStore sunt scope-uite per universe), MemoryStore-urile, și orice date de test nu ating vreodată datele reale ale jucătorilor.

Pentru Driftwood, dat fiind că economia e complet server-authoritative cu DataStore (conform brief-ului), universuri separate pentru dev/staging vs. producție evită orice risc de a corupe/testa pe datele reale ale jucătorilor din greșeală — un scenariu grav având în vedere accent pe „nu pierdem progresul jucătorului".

Alternativa (place secundar în același universe) e mai simplă de configurat dar riscantă: un bug într-un script de test ar putea, teoretic, atinge alte sisteme server-side care sunt per-universe (MessagingService topics, unele MemoryStore-uri) chiar dacă DataStore-urile pot fi izolate manual prin prefixare de chei.

### 5. Luau Execution API pentru teste automate

Fluxul (conform exemplului oficial): CI creează un task cu `universeId`, `placeId` și un script Luau de rulat → Roblox lansează un server headless, încarcă place-ul, rulează scriptul → CI face polling până la completare → primești valorile de return și log-urile. Se pot da payload-uri binare de input/output (util pentru a injecta stare de test sau a extrage un `.rbxm` serializat).

**Contradicție de surse pe limita de concurență** (semnalată explicit, așa cum cere metoda de cercetare):
- README-ul oficial `Roblox/place-ci-cd-demo` (sursă primară, cea mai de încredere): „currently limited to two concurrent request per universe" — și de aceea folosește un `concurrency group` în GitHub Actions ca să serializeze job-urile de test.
- O altă sinteză (indirectă, din pagina de doc a feature-ului) menționează „10 concurrent tasks per place, max 5 minutes per task" — nu am putut confirma acest număr direct dintr-un citat textual la fetch.

**Recomandare:** proiectează pipeline-ul presupunând limita mai restrictivă (2 concurente/universe) și un timeout de 5 minute per task, cu un `concurrency:` group în GitHub Actions exact ca în exemplul oficial. Verifică empiric limita reală în Studio/practică înainte de a paraleliza suite de teste.

### 6. Rollback / versionare de place

Nu există un API Open Cloud dedicat „rollback" — mecanismul e prin **Version History**:

- **Studio:** Window → Version History → click pe „⋮" lângă versiunea dorită → „Open Local Copy" → în noua sesiune, File → Save to Roblox As → suprascrii place-ul țintă.
- **Creator Dashboard:** Creations → jocul tău → Configure → Places → place-ul → Version History → alegi versiunea.
- Restaurarea creează o **versiune nouă** (nu retrogradează in-place) — trebuie apoi publicată explicit ca să devină live, iar dacă vrei ca serverele deja pornite să preia schimbarea, trebuie repornite (Roblox nu „hot-swap"-uiește place-ul pe servere active).
- Filtrare disponibilă în UI după interval de dată, tip de salvare, „published saves", colaborator, și notă de versiune atașată.

Pentru un pipeline CI, echivalentul programatic e „republică versiunea N anterioară": poți descărca o versiune anterioară via Open Cloud (endpoint de citire a unei versiuni de place, dacă disponibil — de verificat exact în doc) sau, mai simplu, ține în artifact-urile GitHub Actions fiecare `.rbxl` publicat cu versionNumber-ul primit ca răspuns, și republică acel fișier direct din artifact în caz de rollback (mai simplu și mai rapid decât orice API de rollback nativ).

### 7. Secrets: unde stau cheile

Există DOUĂ contexte diferite de „secrete", de nu confundat:

1. **Secrete pentru CI (pipeline-ul de deploy)** — cheia API Open Cloud folosită de GitHub Actions ca să publice place-ul. Acestea stau în **GitHub Actions Secrets** (`Settings → Secrets and variables → Actions`), NU în Roblox Secrets Store. Exemplul oficial le referă ca `${{ secrets.ROBLOX_API_KEY }}`.
2. **Secrete pentru runtime (cod care rulează în joc)** — ex. dacă serverul jocului Driftwood ar trebui să apeleze un API extern (nu e cazul curent conform brief-ului, dar posibil pentru viitor: verificări anti-fraudă, webhook-uri Discord la evenimente etc). Pentru acestea folosești `HttpService:GetSecret("numeSecret")` — secretul e setat via Open Cloud (Secrets management) sau, pentru dezvoltare locală, din Studio → File → Experience Settings → Security → Local Secrets. Necesită `HttpService.HttpEnabled = true` (echivalent „Allow HTTP Requests" în UI).

### 8. Limite DataStore — tabel complet

| Tip request | Formula (per minut, la nivel de experiență) |
|---|---|
| Read (Standard/Ordered) | `300 + concurrentUsers × 40` |
| Write (Standard/Ordered) | `300 + concurrentUsers × 20` |
| List (`ListDataStoresAsync`, `ListKeysAsync`, `ListVersionsAsync`) | `300 + concurrentUsers × 2` |
| Remove | `300 + concurrentUsers × 40` |

| Limite server-level (per server de joc, nu global) | Valoare |
|---|---|
| Standard: Read/Write/Remove | `60 + numPlayers × 40` /min |
| Standard: List | `5 + numPlayers × 2` /min |
| Ordered: Read | `60 + numPlayers × 40` /min |
| Ordered: Write | `30 + numPlayers × 5` /min |
| Ordered: List/Remove | `5 + numPlayers × 2` /min |

| Limite de date | Valoare |
|---|---|
| Nume DataStore | 50 caractere |
| Nume cheie | 50 caractere |
| Scope | 50 caractere |
| Valoare per cheie | 4.194.304 bytes (4 MB) |
| Metadata: cheie | 50 caractere |
| Metadata: valoare | 250 caractere |
| Storage total | `500 MB + 1 MB × lifetime user count` (bază recent crescută de la 100 MB — verifică oficial înainte de a planifica capacitate) |
| Throughput read | 25 MB/min per cheie |
| Throughput write | 4 MB/min per cheie |
| Coadă de request-uri | max 30 per tip, peste asta requesturi respinse (erori 301-306) |

Sursă pentru tot tabelul: https://github.com/Roblox/creator-docs/blob/main/content/en-us/cloud-services/data-stores/error-codes-and-limits.md (verificat 8 sept 2026); confidence: ridicata pentru formule, medie pentru cifra de 500 MB (posibil schimbare recentă, verifică pagina live).

## Recomandari concrete pentru Driftwood

1. **Folosește `rojo upload` ca mecanism principal de publish în CI**, nu Mantle. Motiv: e calea validată chiar de Roblox în propriul lor exemplu de referință (`place-ci-cd-demo`), Mantle e neîntreținut, iar `rbxcloud` adaugă o dependență Rust suplimentară de care nu ai nevoie doar pentru publish (dar ține-l în minte dacă vrei să scripezi și DataStore/Messaging din CI mai târziu).

2. **Creează două experiențe (universuri) Roblox separate de la început: `Driftwood-Staging` și `Driftwood` (producție)**, fiecare cu propriile DataStore-uri implicit izolate. Nu folosi un singur universe cu place-uri multiple pentru asta — copiază exact pattern-ul din exemplul oficial Roblox.

3. **Creează câte o cheie API Open Cloud separată pentru fiecare scop**: una pentru publish-staging (`universe-places` write, restricționată la universe-ul de staging), una pentru publish-producție (idem, restricționată la universe-ul de producție, folosită DOAR manual/prin promote controlat), una pentru teste Luau Execution. Nu refolosi aceeași cheie pentru staging și producție — dacă o cheie de staging e compromisă (ex. leak din log CI), nu vrei să aibă acces și la producție.

4. **Pipeline recomandat**: push pe `main` → lint (Selene) + format check (StyLua) → `rojo build` → teste automate via Luau Execution API pe universe-ul de staging → dacă toate trec, `rojo upload` automat pe place-ul de **staging**. Promovarea la producție rămâne un pas **manual** (workflow separat, trigger manual `workflow_dispatch`, sau aprobare de tip GitHub Environment) — nu automatiza publish-ul direct pe producție, mai ales cât Driftwood încă e în etapa de prototip (brief-ul spune explicit „nu trece la pasul următor până cel anterior nu e testat cu oameni reali" — publish automat pe prod contravine acestui principiu).

5. **Folosește GitHub Environments cu „required reviewers"** pentru job-ul de promote-to-production, ca poartă de aprobare manuală nativă în GitHub Actions, în loc de un simplu `if:` condiționat de branch.

6. **Presupune limita de concurență Luau Execution la 2 task-uri/universe** (cea mai restrictivă și cea confirmată din sursa oficială) și pune un `concurrency:` group în workflow exact ca în exemplul Roblox, ca să nu pice job-uri de test din cauza rate-limitului.

7. **Nu te baza pe rollback automat prin API** — păstrează fiecare `.rbxl` publicat ca artifact în GitHub Actions (`actions/upload-artifact`), etichetat cu `versionNumber`-ul primit din răspunsul de publish. Rollback = republici artifact-ul anterior, e mai rapid și mai predictibil decât Version History manual din UI.

8. **Ține cheile Open Cloud în GitHub Actions Secrets**, niciodată în cod sau în `default.project.json`. Pentru orice secret folosit în interiorul jocului (nu e cazul acum, dar posibil la integrarea de webhook-uri Discord pentru evenimente de tip „Inundația"), folosește Secrets Store + `HttpService:GetSecret()`, nu hardcodare.

9. **Testează practic limita de 60 de zile de auto-expirare a cheilor API** — dacă pipeline-ul de CI rulează des (probabil, în faza de prototip), nu e o problemă; dacă proiectul intră într-o pauză lungă, cheile expiră silențios și primul deploy după pauză va eșua cu 401 — pune un mesaj de alertă/verificare periodică.

10. **Nu investi timp acum în MemoryStore prin Open Cloud** pentru sistemele descrise în brief (râu, plase, reparat, atelier) — acestea sunt in-game realtime, deci folosesc `MemoryStoreService` direct din Luau server-side, nu Open Cloud. Open Cloud MemoryStore e util doar dacă vrei unelte externe (dashboard admin, scripturi de migrare) care ating aceleași structuri din afara jocului.

## Riscuri si necunoscute

- **Limita de mărime pentru publish via Open Cloud** nu e confirmată separat de limita generală de 100 MB pentru Studio — posibil identică, posibil diferită (mai mică, având în vedere transferul HTTP). NEVERIFICAT direct pe pagina de referință a endpoint-ului.
- **Rate limit exact (requests/minut) pentru endpoint-ul de Place Publishing** nu a putut fi extras dintr-o pagină oficială — doar mecanismul general (per owner pentru API key, per token pentru OAuth2, header-e `x-ratelimit-*`) e confirmat. NEVERIFICAT numărul exact.
- **Contradicția de concurență Luau Execution (2 vs. 10)** trebuie rezolvată empiric în Studio/CI real înainte de a proiecta o suită mare de teste automate.
- **Discrepanța de mărime pentru Assets API (20 MB documentat vs. 30 MB confirmat de staff Roblox pe forum)** — posibil documentația să fi fost actualizată între timp; verifică live.
- **Rata DevEx de $0.0054/Robux (US 18+)** e nouă (8 iunie 2026) și condiționată — nu presupune că se aplică la toți banii încasați de Driftwood; verifică exact ce calificări se aplică înainte de a construi proiecții financiare.
- **Statusul curent (2026) al „Engine API for Updating Scripts"** — sursa găsită e din februarie 2024; nu știm dacă a ieșit din beta, a fost extinsă la mai multe tipuri de instanțe, sau abandonată. NEVERIFICAT pentru starea actuală.
- **Numărul maxim de place-uri per universe** — nu a fost găsită o limită documentată explicit; presupunerea că „nu există limită practică relevantă pentru Driftwood" e rezonabilă dar NEVERIFICATĂ.
- Nu am putut confirma dacă Open Cloud API-urile au vreun cost separat de utilizare — nu există nicio mențiune de preț pe paginile oficiale consultate; tratez ca „inclus, fără cost separat documentat", dar marchez ca NEVERIFICAT explicit (sursele terțe care menționau „freemium" erau agregatoare nesigure, nu Roblox).

## Intrebari deschise

1. Confirmă în Studio, cu un cont real, limita exactă de concurență pentru Luau Execution API înainte de a construi suita de teste automate a Driftwood.
2. Decide dacă publish-ul pe staging va fi complet automat la fiecare push pe `main`, sau dacă vrei și acolo o poartă manuală minimă (recomandarea de mai sus e automat pe staging, manual pe producție).
3. Decide organizarea de grup Roblox: dacă Driftwood va fi publicat sub un grup Roblox (relevant pentru DevEx cash-out în echipă/viitor) — asta schimbă cum se configurează cheile API (owner = grup vs. owner = user individual) și cine are acces la Creator Dashboard.
4. Testează concret în Studio fluxul „Version History → Open Local Copy → Save to Roblox As" cel puțin o dată manual, ca să înțelegi timpul și pașii înainte să te bazezi pe el ca plasă de siguranță în producție.
5. Verifică dacă vrei să adopți `rbxcloud` CLI de la început (pentru a scripta și DataStore/Messaging din unelte externe, ex. un panou de admin pentru evenimentul „Inundația") sau doar `rojo upload` minimal pentru publish.
6. Stabilește cine (ce cont Roblox) deține cheile API de producție și cum sunt rotite — proiectul e încă solo, dar brief-ul menționează colaborare („colaborare cu alți creatori" implicit prin Team Create) care ar putea necesita separarea de permisiuni mai devreme decât crezi.

## Surse

- https://create.roblox.com/docs/cloud — Cloud API reference (Roblox Creator Hub), verificat 8 sept 2026
- https://create.roblox.com/docs/cloud/auth/api-keys — API Keys, verificat 8 sept 2026
- https://create.roblox.com/docs/cloud/auth/oauth2-reference — OAuth 2.0 authentication, verificat 8 sept 2026
- https://github.com/Roblox/creator-docs/blob/main/content/en-us/cloud/guides/usage-place-publishing.md — Place Publishing usage guide, verificat 8 sept 2026
- https://create.roblox.com/docs/production/publishing/publish-experiences-and-places — Create and publish games and places, verificat 8 sept 2026
- https://github.com/blake-mealey/mantle — Mantle README (status: neîntreținut), verificat 8 sept 2026
- https://github.com/Roblox/place-ci-cd-demo — README + `.github/workflows/cicd.yml`, exemplu oficial Roblox de CI/CD, verificat 8 sept 2026
- https://sleitnick.github.io/rbxcloud/ — documentație rbxcloud CLI, verificat 8 sept 2026
- https://github.com/Sleitnick/rbxcloud — repo rbxcloud CLI, verificat 8 sept 2026
- https://create.roblox.com/docs/cloud/reference/rate-limits — Rate limits, verificat 8 sept 2026
- https://github.com/Roblox/creator-docs/blob/main/content/en-us/cloud-services/data-stores/error-codes-and-limits.md — DataStore error codes & limits, verificat 8 sept 2026
- https://create.roblox.com/docs/projects/version-history — Version History, verificat 8 sept 2026
- https://create.roblox.com/docs/cloud-services/secrets — Secrets stores, verificat 8 sept 2026
- https://create.roblox.com/docs/cloud/guides/usage-messaging — Messaging usage guide, verificat 8 sept 2026
- https://github.com/Roblox/creator-docs/blob/main/content/en-us/cloud-services/memory-stores/index.md — Memory stores index, verificat 8 sept 2026
- https://devforum.roblox.com/t/hashmap-support-for-open-cloud-memory-stores-api/4589938 — HashMap support request (confirmă lipsa HashMaps în Open Cloud), verificat 8 sept 2026
- https://create.roblox.com/docs/cloud/guides/usage-assets — Assets usage guide, verificat 8 sept 2026
- https://devforum.roblox.com/t/add-an-open-cloud-endpoint-for-uploading-roblox-models-and-plugins/2668833 — discrepanță limită mărime Assets API, verificat 8 sept 2026
- https://devforum.roblox.com/t/your-brand-new-cloud-api-reference-documentation-is-here/4139597 — anunț documentație unificată (13 martie 2026)
- https://devforum.roblox.com/t/open-cloud-engine-api-for-updating-scripts-beta/2836619 — Engine API for Updating Scripts [Beta] (13 feb 2024 — posibil depășit)
- https://create.roblox.com/docs/production/monetization/developer-exchange — Developer Exchange Program, verificat 8 sept 2026
- https://generalistprogrammer.com/tutorials/roblox-devex-guide-how-to-cash-out-robux — sursă secundară, sinteză rate DevEx 2026 (folosită doar pentru datele exacte de efectivitate a ratelor), verificat 8 sept 2026
