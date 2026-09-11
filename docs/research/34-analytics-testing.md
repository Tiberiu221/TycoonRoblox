# Analytics, experimente și playtesting pe Roblox (2026)

## Rezumat executiv

- Roblox are un stack de analytics nativ complet gratuit: **Creator Hub Analytics** (dashboard-uri vizuale) + **`AnalyticsService`** (API Luau pentru evenimente custom) + **Experiments** (A/B testing) + **Configs** (remote config). Nu trebuie SDK extern pentru MVP.
- `AnalyticsService` are limite dure importante pentru arhitectură: **max. 100 de custom events per joc**, **max. 5 monede urmărite** în economy events, **max. 10 funnel-uri** afișate simultan în dashboard, evenimentele **nu pot fi trimise din client sau din Studio** — doar din server, în jocul publicat.
- Toate dashboard-urile de analytics au **întârziere de agregare**: majoritatea metricilor sunt zilnice (agregare completă poate dura până la **24h** pentru custom events), iar unele date de vânzări se actualizează la **48h**. Nu există date "live" pentru retenție/monetizare — nu te baza pe dashboard pentru decizii în timp real.
- Dashboard-urile complete (KPI, benchmarking) necesită **peste 10 DAU + 10 ore de joc timp de 7 zile consecutive**; comparațiile cu jocuri similare cer **100+ DAU**; rapoartele AI-generate cer **1000+ DAU**. Cu 20 de testeri într-un alpha închis, majoritatea dashboard-urilor Creator Hub **nu vor avea date suficiente** — trebuie construită telemetrie proprie (log-uri text + `AnalyticsService` events simple) pentru citit manual.
- **Experiments** (A/B testing nativ) funcționează, dar documentația spune explicit că jocurile **sub 1.000 DAU riscă să nu obțină date utile** — inutilizabil pentru Driftwood în faza de prototip/alpha.
- Pentru testare cu grup mic (closed alpha de 20 de oameni), varianta corectă e **Access = Limited → Playtesters** (sau Friends) în setările jocului publicat, NU un joc "unlisted" separat de concept — Roblox nu are un concept generic "unlisted", ci categorii explicite: **Private / Limited (Playtesters, Friends, Community Members) / Public**.
- **Paid Access** (25–1.000 Robux, one-time) poate fi folosit temporar ca "closed beta" cu obligația de a comunica transparent testerilor că e o versiune beta — opțiune secundară, nu recomandată pentru primul alpha.
- Pentru erori/crash-uri: `ScriptContext.Error` (per sesiune, în Studio/output) + **Performance Dashboard** din Creator Hub (crash rate client, memorie client/server, la scară de producție) sunt sursele oficiale. Nu există un "dashboard de erori de logică" agregat — pentru asta trebuie trimise manual erorile prin `LogService`/`AnalyticsService:LogCustomEvent` sau `HttpService` către un endpoint propriu.
- Anunțuri foarte recente (24 august 2026 și 1 septembrie 2026) arată platforma în plină expansiune pe zona de analytics: OpenCloud API-uri noi pentru analytics/experimente, segmentare avansată, "Early Harm Detection", Custom Dashboards — relevant pentru roadmap-ul pe termen mediu, nu pentru prototip.
- Extern (GameAnalytics, HttpService custom): fezabil tehnic prin `HttpService:RequestAsync`, dar necesită activarea `HttpEnabled` și nu am putut verifica o politică Roblox explicită anti-third-party-analytics — tratat ca NEVERIFICAT, cu recomandare de precauție (COPPA/privacy pentru minori).

## Fapte verificate

- `AnalyticsService:LogCustomEvent(player, eventName, eventValue)` există; poți adăuga **până la 100 de custom events** per joc. Sursa: create.roblox.com/docs/production/analytics/custom-events (fără dată vizibilă pe pagină). Încredere: ridicata.
- Evenimentele de analytics (`LogCustomEvent`, `LogEconomyEvent`, `LogFunnelStepEvent` etc.) **pot fi trimise doar de pe server și doar în jocuri publicate**; nu funcționează din client sau din Studio. Sursa: create.roblox.com/docs/production/analytics/custom-events și .../funnel-events. Încredere: ridicata.
- Custom events sunt **agregate zilnic**; pot dura **până la 24 de ore** să apară în dashboard. Sursa: create.roblox.com/docs/production/analytics/custom-events. Încredere: ridicata.
- `LogEconomyEvent` acceptă: player, `AnalyticsEconomyFlowType` (Source/Sink), nume monedă, sumă (pozitivă), sold curent, `AnalyticsEconomyTransactionType`, SKU item (opțional). **Max. 5 monede** urmărite per joc. Sursa: create.roblox.com/docs/production/analytics/economy-events. Încredere: ridicata.
- `AnalyticsEconomyTransactionType` are valorile: IAP(0), Shop(1), Gameplay(2), ContextualPurchase(3), TimedReward(4), Onboarding(5). Sursa: create.roblox.com/docs/reference/engine/enums/AnalyticsEconomyTransactionType. Încredere: ridicata.
- `LogFunnelStepEvent` e pentru evenimente recurente (multiple per user, cu `funnelSessionId`); `LogOnboardingFunnelStepEvent` e pentru evenimente one-time (o dată per user). Dashboard-ul suportă **până la 10 tab-uri de funnel simultan**, și reține **cele mai recente 10 `funnelSessionId` unice per user per funnel**. Sursa: create.roblox.com/docs/production/analytics/funnel-events. Încredere: ridicata.
- `AnalyticsProgressionType` are valorile: Custom(0), Start(1), Fail(2), Complete(3). Sursa: create.roblox.com/docs/reference/engine/enums/AnalyticsProgressionType (pagina nu conținea și `AnalyticsProgressionStatus`, deci acel enum e NEVERIFICAT ca listă completă). Încredere: medie.
- Există și `LogJourneyEvent` (jurnalizare "node-uri" dintr-un journey/hartă de progres), documentat direct pe pagina `AnalyticsService`, alături de metodele deprecate `FireCustomEvent`, `FireEvent`, `FireInGameEconomyEvent`, `FireLogEvent`, `FirePlayerProgressionEvent`. Sursa: create.roblox.com/docs/reference/engine/classes/AnalyticsService. Încredere: ridicata.
- Clasele **`CustomEvent` / `CustomEventReceiver` / `CustomLog`** din Engine Reference sunt un mecanism **deprecat, fără legătură** cu `AnalyticsService:LogCustomEvent` — a nu se confunda. Sursa: create.roblox.com/docs/reference/engine/classes/CustomEvent. Încredere: ridicata.
- `AnalyticsService:GetPlayerSegmentsAsync(player)` întoarce un dicționar cu `HasData`, `WhenUserFirstPlayed` (`Enum.WhenUserFirstPlayed`: Unknown/Days0To30/Days31To90/Days91To180/Days181To365/Days366Plus) și `ActivePayerStatus` (`Enum.ActivePayerStatus`: Unknown/Never/Lapsed/Casual50Percent/Intermediate35Percent/Top15Percent). Sursa: create.roblox.com/docs/reference/engine/classes/AnalyticsService + docs/reference/engine/enums/WhenUserFirstPlayed + .../ActivePayerStatus. Încredere: ridicata.
- Dashboard-urile principale din Creator Hub Analytics sunt: **Retention, Engagement, Monetization, Acquisition, Insights, Funnel Analytics**, plus **Analytics Home** (multi-joc, vânzări avatar, achiziție prin share links) și **Analytics Dashboard** general (retenție, engagement, achiziție, demografie, feedback, monetizare). Sursa: create.roblox.com/docs/production/analytics (pagina index) + .../analytics-dashboard. Încredere: ridicata.
- Pentru KPI-uri complete pe dashboard e nevoie de **peste 10 DAU și 10 ore de joc timp de 7 zile consecutive**; pentru "Insights" e nevoie de **100+ DAU**; comparația cu jocuri similare ("benchmarking") folosește **top 1000 jocuri** după playtime pe o fereastră glisantă de **30 de zile**. Sursa: create.roblox.com/docs/production/analytics/analytics-dashboard și .../insights. Încredere: ridicata.
- Rapoarte AI-generate în Insights (analiza driverilor de revenue/DAU, detectare automată de outlieri, sumarizare feedback) sunt disponibile la **1000+ DAU**, folosind modele **Gemini 2.5** și **Meta Llama 3**. Sursa: create.roblox.com/docs/production/analytics/insights. Încredere: ridicata.
- D1/D7/D30 retention: D1 = utilizatori care au jucat prima dată într-o zi X și **s-au întors a doua zi**; D7 = s-au întors **după 1 săptămână**; D30 = s-au întors **după 1 lună**. Datele pentru zilele cele mai recente din graficele D7/D30 pot fi goale (lag natural de cohortă). Sursa: create.roblox.com/docs/production/analytics/retention. Încredere: ridicata.
- Vânzările (sales data) se actualizează **la fiecare 48 de ore**; alte metrici (active payer status, status de activitate în experiență, engagement, activitate pe platformă) se **recalculează zilnic**; exportul de grafice necesită **minim 48 de ore** de date. Sursa: create.roblox.com/docs/production/analytics/analytics-dashboard. Încredere: ridicata.
- **Experiments** (A/B testing nativ): control + **până la 2 variante**, alocare aleatorie pe procentaj configurat, durată **14–60 de zile**, o singură experiență de matchmaking activă simultan (dar mai multe experimente in-game pe chei de config diferite), **nu poți modifica cheile de config** după ce experimentul a pornit. Metrici auto-urmărite: D1/D7 retention, playtime, ARPU, ARPPU, conversion rate, session time. Jocurile cu **sub 1.000 DAU** riscă să nu obțină date utile. Sursa: create.roblox.com/docs/production/experiments. Încredere: ridicata.
- Implementare experimente în cod: `ConfigService:GetConfigForPlayerAsync(player)` (nu `GetConfigAsync()`) — apelul la `GetValue()` **înrolează** jucătorul în experimentul acelei chei. Sursa: create.roblox.com/docs/production/experiments. Încredere: ridicata.
- **Configs** (remote config): valori string (max **100.000 caractere**), număr (±1.7976931348623157e+308), JSON (max **100.000 caractere**); **max. 1.000 de configs active** per experiență, **max. 100 de condiții** per experiență, **max. 20 de condiții** per cheie. Publicarea se propagă în **15 secunde – 1 minut** (sau gradual, în ~15 minute). Sursa: create.roblox.com/docs/production/configs. Încredere: ridicata.
- Setări de acces la joc: **Private** (doar useri cu Edit permissions), **Limited** (Playtesters / Friends / Community Members), **Public**. Jocurile noi sunt **Private by default**; poți face **maximum 5 jocuri anterior-private publice pe zi**. Sursa: create.roblox.com/docs/production/publishing/publish-games-and-places. Încredere: ridicata.
- **Paid Access**: taxă unică între **25 și 1.000 Robux**; nu funcționează pe Xbox; plățile stau **în escrow până la 7 zile**; **fără refund**; poate fi activat temporar ca "closed beta" dar trebuie comunicat clar jucătorilor că e o versiune beta; jocul cu Paid Access trebuie să rămână public și nu poate combina cu servere private. Sursa: create.roblox.com/docs/production/monetization/paid-access-robux. Încredere: ridicata.
- **Private Servers**: abonament lunar în Robux setat de developer (sau gratuit); jocul trebuie să fie deja public; **nu pot coexista cu Paid Access**; schimbarea prețului **anulează toate abonamentele active**. Sursa: create.roblox.com/docs/production/monetization/private-servers. Încredere: ridicata.
- Moduri de test în Studio: **Test (F5)** — inserează avatarul la SpawnLocation/(0,100,0); **Test Here** — poziționează avatarul în fața camerei; **Run (F8)** — fără avatar, doar navigare cameră; **Server & Clients (F7)** — simulează **până la 8 clienți** plus 1 server, pornit din dropdown + Play; **Shift+F5** oprește sesiunea. **Team Test** permite testare colaborativă live cu colegi (fiecare din propriul Studio), **o singură sesiune Team Test activă simultan**. Sursa: create.roblox.com/docs/studio/testing-modes. Încredere: ridicata.
- **Performance Dashboard** (Creator Hub) monitorizează în timp real, la scară de producție (nu doar Studio): **crash rate client, memorie client, memorie server, durata sesiunii**; suportă comparație pe intervale de date. Sursa: create.roblox.com/docs/performance-optimization/monitor. Încredere: ridicata.
- `ScriptContext.Error` (eveniment, service `ScriptContext`) se declanșează la orice eroare de script din joc; semnătură `(message: string, stackTrace: string, script: Instance)`. `LogService` oferă `Error()`, `Warn()`, `Info()`, `Output()`, `Log()`, `ClearOutput()`, `GetLogHistory()` și evenimentul `MessageOut`. Ambele cer capabilitatea **"Logging"**. Sursa: create.roblox.com/docs/reference/engine/classes/ScriptContext și .../LogService. Încredere: ridicata.
- `HttpService:RequestAsync` / `GetAsync` / `PostAsync` există pentru apeluri externe (necesar pentru analytics extern precum GameAnalytics); necesită **`HttpEnabled = true`** în setările experienței și capabilitatea **"Network"**. Documentația oficială consultată nu a specificat explicit rate-limit-uri sau o listă de domenii permise/interzise. Sursa: create.roblox.com/docs/reference/engine/classes/HttpService. Încredere: medie (limite exacte NEVERIFICAT).
- Anunț oficial DevForum (24 august 2026): noi **OpenCloud API-uri** — **Analytics Query API** (`apis.roblox.com/analytics-query-api/v1/universes/{UniverseId}/metrics`, scope `universe.analytics:read`, asincron cu polling), **Experiments API** (`apis.roblox.com/creator-configs-public-api/v1/experimentation/universes/{universe_id}`, calculează Minimum Detectable Effect), **Events and Updates API**, **Thumbnail Personalization API**. Sursa: devforum.roblox.com/t/new-opencloud-apis-for-analytics-events-experiments-and-thumbnail-personalization/4828676, 24 august 2026. Încredere: ridicata.
- Anunț oficial DevForum (24 august 2026): **Conditional Configs** (live) și **Experiment Targeting** (live) — segmentare pe țară, limbă, sursă de achiziție, status new/returning, status payer; **Experiment Results Segmentation** și **Early Harm Detection** (monitorizare aproape în timp real în primele 24h pe playtime/ARPU/conversion, cu alerte la praguri catastrofale) sunt "coming soon". Program de **"Analytics and LiveOps Early Access"** deschis pentru aplicare. Sursa: devforum.roblox.com/t/evolving-experiments-and-analytics-segmentation-experiment-targeting-early-access-program-and-more/4828462, 24 august 2026. Încredere: ridicata.
- Anunț oficial DevForum (1 septembrie 2026): **Custom Dashboards** — până la **20 de dashboard-uri** per joc, widget-uri redimensionabile, grafice/carduri/tabele, partajabile echipei cu permisiuni de analytics. Sursa: devforum.roblox.com/t/analytics-custom-dashboards-to-save-organize-and-share-custom-charts/4844585, 1 septembrie 2026. Încredere: ridicata.
- GameAnalytics oferă (conform site-ului propriu, secundar) un SDK generic pentru mai multe motoare, dar pagina dedicată Roblox nu a putut fi accesată direct în această sesiune (404/redirect eșuat). **Existența și detaliile exacte ale unui SDK GameAnalytics pentru Roblox rămân NEVERIFICAT** în această cercetare — recomand verificare manuală pe docs.gameanalytics.com înainte de a te baza pe el. Încredere: scazuta.

## Detalii

### 1. Creator Hub Analytics — structura reală a dashboard-urilor

Din navigarea documentației oficiale (`create.roblox.com/docs/production/analytics`), structura confirmată e:

| Dashboard | Ce arată | Prag minim de date | Delay observat |
|---|---|---|---|
| Analytics Home | Multi-joc, vânzări avatar, achiziție prin share links | — | NEVERIFICAT |
| Retention | D1/D7/D30, cohorte pe zi/săptămână | 10+ DAU, 10h joc / 7 zile | cohorte D7/D30 apar cu 7/30 zile lag natural |
| Engagement | Sesiuni medii, DAU/MAU (definiții exacte pt. DAU/MAU NEVERIFICAT pe pagina Engagement) | 10+ DAU, 10h joc / 7 zile | zilnic |
| Monetization | ARPDAU, ARPPU, conversion rate | 10+ DAU, 10h joc / 7 zile | vânzări la 48h, restul zilnic |
| Acquisition | Surse utilizatori noi, conversie recomandări Home | 10+ DAU, 10h joc / 7 zile | NEVERIFICAT |
| Insights | Mișcări mari în DAU/useri noi/revenue, benchmark vs. jocuri similare | 100+ DAU (rapoarte AI la 1000+ DAU) | zilnic |
| Funnel Analytics | Progresie prin pași definiți (onboarding, shop, orice flux) | — | agregare zilnică, până la 24h |
| Custom Events | Evenimente proprii (counter/valued) | — | agregare zilnică, până la 24h |
| Economy | Surse/sink-uri de monedă, sold mediu | — | NEVERIFICAT (nu s-a specificat explicit) |
| Performance Dashboard | Crash rate client, memorie client/server, durată sesiune | — | „timp real" pe pagina oficială, dar fără cifră exactă de latență |
| Custom Dashboards (nou, 1 sept 2026) | Compun grafice/KPI/tabele proprii, până la 20/joc | — | moștenește delay-urile surselor |

Benchmarking: compară jocul cu (1) jocuri cu audiență similară (50-90 percentile, opțiune preferată), (2) jocuri din același gen, (3) toate experiențele — în funcție de câte date există. Benchmark-urile generale ("overall success") folosesc top 1000 jocuri după playtime total pe o fereastră glisantă de 30 de zile, afișate pe trepte Top 200/500/1000.

**Implicație directă pentru Driftwood**: cu un alpha de 20 de testeri nu atingi pragul de 10 DAU susținut 7 zile consecutiv în majoritatea zilelor (posibil da la vârf, dar inconsistent), deci Retention/Engagement/Monetization dashboard-urile oficiale vor arăta parțial gol sau incomplet. Insights (100+ DAU) și rapoartele AI (1000+ DAU) sunt inaccesibile în alpha. **Trebuie construit un tabel de urmărire manuală** (Google Sheet / DataStore export) pentru cei 20 de testeri, în paralel cu evenimentele native.

### 2. `AnalyticsService` — API-ul complet, cu limite

```lua
local AnalyticsService = game:GetService("AnalyticsService")

-- Custom event (max 100 tipuri distincte de eventName per joc)
AnalyticsService:LogCustomEvent(player, "NetPlaced") -- counter, value implicit 1
AnalyticsService:LogCustomEvent(player, "RepairDurationSeconds", 42) -- valued event

-- Economy event (max 5 monede urmărite)
AnalyticsService:LogEconomyEvent(
    player,
    Enum.AnalyticsEconomyFlowType.Source,
    "Coins",
    50,                                   -- amount, mereu pozitiv
    player.leaderstats.Coins.Value,       -- sold după tranzacție
    Enum.AnalyticsEconomyTransactionType.Gameplay,
    "driftwood_crate_common"              -- SKU opțional
)

-- Funnel recurent (ex: reparare obiect — pași repetabili per sesiune)
local funnelSessionId = HttpService:GenerateGUID(false)
AnalyticsService:LogFunnelStepEvent(player, "RepairFlow", funnelSessionId, 1, "ItemCaught")
AnalyticsService:LogFunnelStepEvent(player, "RepairFlow", funnelSessionId, 2, "MaterialsGathered")
AnalyticsService:LogFunnelStepEvent(player, "RepairFlow", funnelSessionId, 3, "RepairComplete")

-- Onboarding funnel (o singură dată per user, fără funnelSessionId)
AnalyticsService:LogOnboardingFunnelStepEvent(player, 1, "TutorialStarted")
AnalyticsService:LogOnboardingFunnelStepEvent(player, 2, "FirstNetPlaced")
AnalyticsService:LogOnboardingFunnelStepEvent(player, 3, "FirstCatch")
AnalyticsService:LogOnboardingFunnelStepEvent(player, 4, "FirstDonation")

-- Progresie
AnalyticsService:LogProgressionEvent(
    player, Enum.AnalyticsProgressionType.Complete,
    "Season1", 1, "RiverbankLevel1"
)

-- Segmentare (server-side, pentru personalizarea onboarding-ului)
local ok, segments = pcall(function()
    return AnalyticsService:GetPlayerSegmentsAsync(player)
end)
if ok and segments.HasData and segments.WhenUserFirstPlayed == Enum.WhenUserFirstPlayed.Days0To30 then
    -- arată tutorial extins
end
```

Constrângeri de reținut, toate din documentația oficială:
- **Server-only, doar în joc publicat** — nu poți testa apeluri de `AnalyticsService` în Studio și nici din LocalScript. Pentru dezvoltare, trebuie publicat (chiar și Private) și rulat ca joc real pentru ca evenimentele să ajungă în dashboard.
- **Un pas dintr-un funnel repetat de același user contează o singură dată** (prima instanță), deci nu poți folosi funnel-urile ca un simplu contor de evenimente repetate — pentru asta e Custom Events sau Economy Events.
- Dashboard Custom Events suportă breakdown pe **până la 3 câmpuri custom**; Economy Events la fel, **până la 3 câmpuri custom**.
- Rate-limit-uri exacte (apeluri pe secundă/minut către `AnalyticsService`) **NEVERIFICAT** — nicio pagină consultată nu a specificat o cifră. Recomand tratarea empirică cu prudență (nu trimite un `LogCustomEvent` per frame; grupează la nivel de eveniment de gameplay).

### 3. Experiments (A/B testing) și Configs

Experiments e construit peste Configs: creezi mai întâi o cheie de config, apoi legați un experiment de acea cheie. Flux:
1. Creezi/folosești un config existent.
2. Creator Hub → Experiments → "Create experiment".
3. Alegi tip: **in-experience** sau **matchmaking**.
4. Nume, metrică țintă (goal metric), durată **14–60 zile**.
5. Procent de rollout + specificații variante (max 2 variante + 1 control).
6. Opțional: targetare pe audiență specifică (țară, limbă, sursă de achiziție, new/returning, payer status — live din 24 aug 2026).
7. Programezi start sau pornești imediat.

Cod: în loc de `ConfigService:GetConfigAsync()` (config global), pentru experimente folosești `ConfigService:GetConfigForPlayerAsync(player)`, iar apelul la `GetValue()` **înrolează automat** jucătorul în experiment. **Nu poți schimba cheile de config după ce experimentul a pornit** — planifică variantele dinainte.

Metrici auto-măsurate de Experiments: D1/D7 retention, playtime, ARPU, ARPPU, conversion rate, session time — deci nu poți defini metrici custom direct în Experiments fără să treacă prin Custom Events/Config.

**Prag critic**: documentația spune explicit că jocurile cu **sub 1.000 DAU pot să nu obțină date statistic utile**. Driftwood în faza de prototip/alpha (20 testeri) e cu 2 ordine de mărime sub prag — Experiments devine util abia după lansare publică cu trafic organic.

Configs (independent de Experiments) e util oricum din prototip, ca sistem de tuning live fără redeploy: prețuri Developer Products, viteza râului pe sezon, plafonul de acumulare offline (8h), rata de reparare — toate pot fi valori de Config, nu hardcodate, ca să le poți ajusta din Creator Hub în timpul playtesting-ului fără să republici locul.

Limite Configs: string/JSON max 100.000 caractere, număr ±1.7976931348623157e+308, **max 1.000 configs active**, **max 100 condiții/experiență**, **max 20 condiții/cheie**. Propagare 15s–1min (sau gradual ~15min). `SetTestingValue()` permite testare fără să afectezi producția; `ConfigSnapshot:Refresh()` + evenimentul `UpdateAvailable` pentru live-update în joc.

### 4. Analytics extern (GameAnalytics, HttpService custom)

Tehnic, `HttpService:RequestAsync`/`PostAsync`/`GetAsync` permit trimiterea de date către orice endpoint extern, cu condiția `HttpEnabled = true` (setare din Studio/Game Settings) și capabilitatea "Network" pe script. Nu am găsit, în sursele oficiale consultate în această sesiune, o interdicție explicită a analytics-ului terț (spre deosebire de reguli clare pe alte teme, precum interdicția server-side de a expune date sensibile). **Politica exactă (Terms of Use / Community Standards) nu a putut fi verificată direct** — paginile `en.help.roblox.com` au întors 403 Forbidden la fiecare încercare de fetch în această sesiune. Tratează asta ca NEVERIFICAT și, înainte de a integra orice SDK extern, citește manual Community Standards + Terms of Use (en.help.roblox.com) — în special clauzele despre COPPA/date ale minorilor, pentru că o parte semnificativă din baza de useri Roblox e sub 13 ani, iar trimiterea de identificatori de jucător către servicii terțe are implicații legale directe.

Pentru **GameAnalytics** specific: site-ul oficial (docs.gameanalytics.com) confirmă existența unui SDK generic multi-engine, dar pagina dedicată integrării Roblox nu a putut fi accesată (404 pe URL-ul așteptat, redirect eșuat). Nu pot confirma dacă SDK-ul Roblox al GameAnalytics e activ/întreținut în 2026, nici costurile. **Recomandare**: nu construi dependințe pe GameAnalytics fără verificare manuală directă pe site-ul lor.

**Alternativă mai sigură pe termen scurt**: `HttpService` către un endpoint propriu simplu (ex. un Google Sheet via Apps Script webhook, sau un mic backend) — păstrează controlul deplin asupra datelor și evită orice ambiguitate de policy legată de SDK-uri terțe.

### 5. Playtesting — metode disponibile în Studio și pe platformă

| Metodă | Cum se activează | Ce testează | Limite |
|---|---|---|---|
| **Test (F5)** | Buton Play din Studio | Un singur client, avatar spawnat | Solo, fără rețea reală |
| **Test Here** | Din meniul Play | Avatar poziționat la camera curentă | Solo |
| **Run (F8)** | Buton Run | Fără avatar, doar navigare | Debugging pur |
| **Server & Clients (F7)** | Dropdown "Server & Clients" → alege nr. clienți → Play | Simulează 1 server + N clienți local, pe aceeași mașină | **Max 8 clienți** simultan; tipic se folosesc 1-2 |
| **Team Test** | Un coleg pornește sesiunea, restul se alătură din propriile instanțe Studio | Test colaborativ live, cu useri reali distincți | **O singură sesiune Team Test activă** simultan |
| **Client/Server toggle (solo play)** | Comută viewport-ul (bordură albastră = client) | Verifici ce rulează pe fiecare parte | Output marcat albastru (client) / verde (server) |
| **Joc publicat, Private/Limited** | Publish → Access = Private sau Limited (Playtesters/Friends) | Test real, cu clienți Roblox reali, pe useri diverși, pe device-uri diferite (telefon/desktop) | Necesită publish; `AnalyticsService` funcționează abia aici |

Shortcut-uri: **F5** test, **F7** server & clients, **F8** run, **Shift+F5** stop.

Sursa (studio/testing-modes) menționează și un flux separat de testare pe device fizic prin **"Roblox Quest app"** — nu a fost documentat în profunzime pe pagina consultată; presupun că e vorba de o aplicație/flow pentru testare pe VR/Quest, dar detaliile exacte sunt NEVERIFICAT — dacă Driftwood nu vizează VR, e irelevant.

### 6. Cum rulezi un closed alpha cu 20 de oameni

Pași concreți, bazați pe setările confirmate de Access:

1. **Publică jocul** (File → Publish to Roblox), cu nume/descriere reale (chiar dacă provizorii) — publicarea e obligatorie pentru ca `AnalyticsService` să funcționeze deloc.
2. Setează **Audience = Limited → Playtesters** (sau Friends, dacă cei 20 sunt cunoscuți personal) din Creator Dashboard → Access Settings. Jocul rămâne invizibil publicului larg dar accesibil grupului ales.
3. Invită cei 20 de testeri (link direct către joc; ei trebuie să aibă cont Roblox).
4. Instrumentează minim, înainte de alpha:
   - `LogOnboardingFunnelStepEvent` pe pașii FTUE (vezi planul din secțiunea 8).
   - `LogEconomyEvent` pentru orice sursă/consum de monedă.
   - `LogCustomEvent` pentru evenimentele-cheie de gameplay (prima plasă pusă, primul obiect prins, prima reparație, prima donație la atelier).
   - Un `pcall` global pe `ScriptContext.Error` care trimite eroarea (mesaj + stack trace + numele scriptului + UserId) fie printr-un `LogCustomEvent("ClientError", 1, {Message=...})`, fie printr-un `HttpService:PostAsync` către un canal propriu (ex. un webhook Discord — simplu de configurat, feedback instant vizibil pentru echipă, fără să depinzi de dashboard-urile cu delay de 24h).
5. **Nu te baza pe Creator Hub Analytics pentru date în timpul alpha-ului** — 20 de useri nu ating pragul de 10 DAU susținut 7 zile, iar delay-ul de 24-48h face iterația lentă. În schimb:
   - Ține un tabel manual (Sheet) cu: UserId, ziua 1 revenit? (da/nu), sesiune medie (minute), unde s-a blocat în onboarding, ce a spus în feedback.
   - Colectează feedback direct (Discord privat cu cei 20, sau un formular Google Forms — link trimis în joc printr-un `TextLabel`/`ImageButton` care deschide un `MessageBoxService`/prompt sau pur și simplu afișezi linkul ca text, pentru că nu poți deschide URL-uri direct din joc fără acordul jucătorului).
6. Ce să măsori concret la 20 de testeri (pentru că analytics agregat nu ajută la acest volum):
   - **Completare FTUE** (pas cu pas, din `LogOnboardingFunnelStepEvent` — vezi și în output-ul de Studio dacă publici ca Private și te uiți în timp real la `LogService`/webhook).
   - **Revenire D1** manuală (cine s-a logat a doua zi) — cu 20 de oameni, un simplu tabel bate orice dashboard cu prag de 10 DAU.
   - **Timp până la primul "aha moment"** (prima plasă + primul obiect prins) — cronometrat din `LogFunnelStepEvent`.
   - **Rata de folosire a acumulării offline** — cine se loghează dimineața să colecteze ce a adus plasa peste noapte (dovada directă a motorului de retenție descris în brief).
   - **Erori de script per sesiune** — din `ScriptContext.Error` trimis către webhook.
7. **Paid Access temporar** e o alternativă doar dacă vrei testeri necunoscuți dinainte (nu prieteni/comunitate) — cost mic (25-1000 Robux), dar trebuie comunicat explicit că e o versiune beta, iar Roblox reține plățile în escrow până la 7 zile și **nu oferă refund**. Pentru un cerc închis de 20 de oameni cunoscuți, **Limited → Playtesters e simplu, gratuit și suficient** — nu recomand Paid Access la acest stadiu.

### 7. Erori și crash-uri

- `ScriptContext.Error` — eveniment global, se declanșează pentru **orice** eroare de script din joc (client sau server, în funcție de unde-l conectezi), cu `(message, stackTrace, script)`. E singurul hook programatic pentru captarea centralizată a erorilor de logică.
- `LogService` — oferă acces la istoricul de log (`GetLogHistory()`) și evenimentul `MessageOut` (mesaj, tip, context) — util pentru a intercepta și `warn()`/`print()`, nu doar erori.
- **Performance Dashboard** (Creator Hub) — singurul dashboard oficial agregat, la scară de producție (nu Studio): **crash rate client, memorie client, memorie server, durată sesiune**, cu comparație pe intervale de date. Nu acoperă erori de logică/script individuale — doar crash-uri și memorie.
- **Nu există un dashboard oficial de "erori de script agregate pe toți jucătorii"** confirmat în sursele consultate. Pentru asta, arhitectura standard e: `ScriptContext.Error:Connect(...)` pe server → serializezi mesaj+stack+UserId+timestamp → trimiți fie prin `AnalyticsService:LogCustomEvent(player, "ScriptError", 1, {Message=...})` (rămâne în Custom Events dashboard, cu 24h delay), fie printr-un webhook extern (Discord/Slack) pentru vizibilitate instant. Recomand ambele: extern pentru reacție rapidă în alpha, Custom Event pentru istoric agregat pe termen lung.

### 8. Plan de instrumentare pentru prototip (pasul 1 din CLAUDE.md: râul + o plasă + prins/nu-prins)

**Onboarding funnel** (`LogOnboardingFunnelStepEvent`, o dată per user):
1. `GameJoined`
2. `TutorialSeen` (dacă există un ecran de tutorial)
3. `FirstNetPlaced`
4. `FirstCatch`
5. `ReturnedNextDay` — **acesta nu poate fi trimis din `LogOnboardingFunnelStepEvent` la eveniment discret**; se deduce din retenția D1 nativă sau dintr-un `LogCustomEvent("Login", 1, {DaysSinceFirst=n})` calculat pe server la fiecare join.

**Funnel recurent** (`LogFunnelStepEvent`, cu `funnelSessionId` per instanță de reparație — pas 3 din roadmap, dar util să-l ai planificat din prototip):
1. `ItemCaught`
2. `RepairStarted`
3. `RepairComplete` sau `Donated`

**Custom Events** (evenimente simple, counter sau valued):
- `NetPlaced` (counter)
- `ItemCaught` (counter, cu custom field `itemType`)
- `OfflineCatchClaimed` (valued = numărul de obiecte acumulate offline — măsoară direct motorul de retenție din brief)
- `SessionLengthSeconds` (valued, trimis la disconnect)
- `ScriptError` (counter, cu custom field `scriptName`)

**Economy Events** (din momentul în care apare prima monedă/resursă):
- Source: `Gameplay` (monede din prins/reparat), `Onboarding` (bonus de start)
- Sink: `Shop` (cheltuieli), `ContextualPurchase` (skip reparație)

**Progression Events**:
- `LogProgressionEvent(player, Start/Complete/Fail, "TutorialPath", 1, "PlaceFirstNet")`

**Dashboard-uri de urmărit manual** (nu Creator Hub, ci un Sheet propriu), până la depășirea pragului de 100+ DAU:
- Retenție D1 (tabel per UserId)
- Timp până la primul catch
- Rata de completare a fiecărui pas din onboarding funnel (cine s-a blocat unde)
- Numărul de erori de script per sesiune
- Feedback calitativ (Discord/Forms)

## Recomandari concrete pentru Driftwood

1. **Instrumentează din prototip, nu după.** Adaugă `AnalyticsService` calls (onboarding funnel + custom events de bază) direct în pasul 1 din roadmap (râul + o plasă), pentru că oricum trebuie publicat jocul (chiar Private) ca să testezi mecanica — costul marginal de a adăuga 4-5 apeluri e minim, iar fără date de la primul playtest nu poți compara „înainte/după" la pasul 2.
2. **Nu te baza pe Creator Hub Analytics în alpha (20 testeri).** Construiește un tabel manual de urmărire (Sheet) și un webhook Discord pentru erori/evenimente critice — dashboard-urile native au praguri (10+ DAU/7 zile, 100+ DAU pentru Insights) și delay de 24-48h, incompatibile cu iterația rapidă pe 20 de oameni.
3. **Folosește Configs de la început pentru orice număr „de tunat”** (plafon offline 8h, viteză râu pe sezon, prețuri Developer Products, rata de reparație) — propagare în sub 1 minut, fără republish, testabil live cu `SetTestingValue()`. Evită hardcodarea acestor valori.
4. **Amână Experiments (A/B testing nativ) până după lansarea publică** — documentația spune explicit că sub 1.000 DAU nu obții date statistic utile; în alpha, testează variante prin discuții directe cu cei 20 de testeri, nu prin split A/B.
5. **Setează Access = Limited → Playtesters pentru closed alpha**, nu Paid Access — e gratuit, simplu, reversibil, și potrivit pentru un cerc cunoscut de 20 de oameni. Rezervă Paid Access doar dacă mai târziu vrei testeri necunoscuți dinainte și accepți limitările lui (fără refund, escrow 7 zile).
6. **Centralizează erorile prin `ScriptContext.Error` → webhook extern**, în plus față de `LogCustomEvent("ScriptError", ...)`. Cu 20 de testeri, vrei să afli despre un crash în minute, nu să aștepți 24h agregarea din Custom Events dashboard.
7. **Separă clar `LogFunnelStepEvent` (recurent) de `LogOnboardingFunnelStepEvent` (o dată/user)** — reparatul obiectelor (sistemul 2 din brief) e recurent și trebuie tratat ca funnel cu `funnelSessionId`, în timp ce fluxul de prim-contact (prima plasă, primul catch) e onboarding, o singură dată per user.
8. **Bugetează evenimentele custom cu grijă la plafonul de 100.** Cu Driftwood având 7 sisteme (râu, reparat, atelier, index, sezoane, amonte, inundație) + monetizare, riști să depășești 100 de tipuri de evenimente dacă instrumentezi granular fiecare acțiune. Grupează cu custom fields (ex. un singur `ItemCaught` cu field `itemType`, nu un eveniment separat per tip de obiect din cele 200+ din index).
9. **Nu integra GameAnalytics sau alt SDK extern fără verificare manuală directă** a docs.gameanalytics.com și a Community Standards/Terms of Use Roblox (en.help.roblox.com), în special pentru conformitate cu politica privind minorii — sursele oficiale relevante au fost inaccesibile (403) în această cercetare, deci decizia trebuie validată separat, nu luată pe baza acestei note.
10. **Planifică deja acum câmpul `funnelSessionId` și `AnalyticsEconomyTransactionType`** pentru sistemul de monetizare din brief: Game Passes → `TransactionType = IAP` la achiziție, `TimedReward` pentru orice bonus zilnic viitor, `Onboarding` pentru bonusul de start — le poți mapa 1:1 pe enum-ul oficial, fără nevoie de valori custom.

## Riscuri si necunoscute

- **Rate-limit exact pe apelurile `AnalyticsService`** — nicio sursă oficială consultată nu specifică o cifră (req/min sau throttling). Risc: dacă instrumentezi prea agresiv (ex. per-frame), poți pierde evenimente silențios sau declanșa erori nedocumentate. Testează empiric în Studio+publish, cu volum mic la început.
- **Politica exactă Roblox privind SDK-uri de analytics terțe și trimiterea de date despre jucători către servicii externe** — NEVERIFICAT, paginile `en.help.roblox.com` (Terms of Use, Community Standards) au întors 403 la fetch în această sesiune. Implicații legale (COPPA, GDPR) pot fi semnificative dat fiind procentul mare de useri minori pe Roblox.
- **Existența și maturitatea unui SDK GameAnalytics oficial pentru Roblox în 2026** — NEVERIFICAT, pagina dedicată a întors 404.
- **Delay exact pentru dashboard-ul Economy** — nu a fost specificat explicit în pagina consultată (presupunere: zilnic, ca restul, dar neconfirmat).
- **AnalyticsProgressionStatus** (enum separat de `AnalyticsProgressionType`) — menționat ca parametru al `LogProgressionEvent` de rezumatul inițial al API-ului, dar pagina de enum dedicată nu a fost găsită/confirmată separat; lista completă de valori rămâne NEVERIFICAT.
- **"Roblox Quest app" pentru testare pe device** — menționat tangențial în docs/studio/testing-modes, fără detalii; relevanța pentru Driftwood (joc 2D ScreenGui, fără plan VR) e probabil nulă, dar flow-ul nu a fost investigat.
- **Comportamentul exact al Performance Dashboard sub 100 DAU** (dacă are și el un prag minim de date, similar cu Retention/Insights) — nu a fost specificat explicit în sursa consultată.
- Toate cifrele de mai sus provin din pagini de documentație **fără dată de ultimă modificare vizibilă** (create.roblox.com/docs nu afișează timestamp pe pagină) — există risc ca Roblox să fi schimbat limitele (100 custom events, 5 monede, 10 funnels) între momentul redactării documentației și septembrie 2026. Recomand o verificare rapidă în Creator Hub live înainte de a proiecta arhitectura finală de evenimente.

## Intrebari deschise

1. Confirmă manual în Studio (după primul publish) dacă apelurile `AnalyticsService` chiar eșuează silențios din Studio/client, sau doar sunt ignorate de dashboard — testează cu un `pcall` și verifică valoarea de retur.
2. Decide dacă merită să aplici acum la programul **"Analytics and LiveOps Early Access"** (survey.roblox.com/jfe/form/SV_3JDitbPNoTvwS58, anunțat 24 aug 2026) — poate oferi acces devreme la Experiment Results Segmentation și Early Harm Detection, utile mai târziu la scalare, dar probabil irelevante acum la 20 de testeri.
3. Citește manual Community Standards + Terms of Use (en.help.roblox.com) pentru clauzele despre analytics terț și date ale minorilor, înainte de a decide dacă folosești `HttpService` către un serviciu extern (inclusiv webhook Discord pentru erori — verifică dacă trimiterea de UserId către Discord ridică probleme de policy).
4. Testează practic în Studio: publică jocul ca Private, rulează Server & Clients cu 2-3 clienți, verifică dacă `LogService`/`ScriptContext.Error` din output apar distinct per client vs. server (documentația spune că output-ul e colorat albastru/verde, dar comportamentul exact cu erori de rețea/RemoteEvent nu a fost verificat).
5. Stabilește un prag intern (ex. „instrumentăm doar sisteme 1-3 din roadmap la prototip") pentru bugetul de 100 custom events, ca să nu ajungi să reproiectezi schema de evenimente la jumătatea dezvoltării.
6. Verifică dacă „Community Members" (a treia opțiune sub Limited access, alături de Playtesters și Friends) presupune crearea unui Roblox Group — dacă da, ar putea fi utilă pentru extinderea alpha-ului de la 20 la un cerc mai larg fără a face jocul public.

## Surse

- [AnalyticsService (Engine Reference)](https://create.roblox.com/docs/reference/engine/classes/AnalyticsService) — data exactă nespecificată pe pagină, consultat 2026-09-08.
- [AnalyticsEconomyTransactionType (Enum)](https://create.roblox.com/docs/reference/engine/enums/AnalyticsEconomyTransactionType) — consultat 2026-09-08.
- [AnalyticsProgressionType (Enum)](https://create.roblox.com/docs/reference/engine/enums/AnalyticsProgressionType) — consultat 2026-09-08.
- [WhenUserFirstPlayed (Enum)](https://create.roblox.com/docs/reference/engine/enums/WhenUserFirstPlayed) — consultat 2026-09-08.
- [ActivePayerStatus (Enum)](https://create.roblox.com/docs/reference/engine/enums/ActivePayerStatus) — consultat 2026-09-08.
- [CustomEvent (Engine Reference, deprecat)](https://create.roblox.com/docs/reference/engine/classes/CustomEvent) — consultat 2026-09-08.
- [ScriptContext (Engine Reference)](https://create.roblox.com/docs/reference/engine/classes/ScriptContext) — consultat 2026-09-08.
- [LogService (Engine Reference)](https://create.roblox.com/docs/reference/engine/classes/LogService) — consultat 2026-09-08.
- [HttpService (Engine Reference)](https://create.roblox.com/docs/reference/engine/classes/HttpService) — consultat 2026-09-08.
- [Analytics — index](https://create.roblox.com/docs/production/analytics) — consultat 2026-09-08.
- [Get started with Analytics](https://create.roblox.com/docs/production/analytics/get-started) — consultat 2026-09-08.
- [Analytics Dashboard](https://create.roblox.com/docs/production/analytics/analytics-dashboard) — consultat 2026-09-08.
- [Retention](https://create.roblox.com/docs/production/analytics/retention) — consultat 2026-09-08.
- [Engagement](https://create.roblox.com/docs/production/analytics/engagement) — consultat 2026-09-08.
- [Monetization](https://create.roblox.com/docs/production/analytics/monetization) — consultat 2026-09-08.
- [Insights](https://create.roblox.com/docs/production/analytics/insights) — consultat 2026-09-08.
- [Funnel Events](https://create.roblox.com/docs/production/analytics/funnel-events) — consultat 2026-09-08.
- [Custom Events](https://create.roblox.com/docs/production/analytics/custom-events) — consultat 2026-09-08.
- [Economy Events](https://create.roblox.com/docs/production/analytics/economy-events) — consultat 2026-09-08.
- [Analytics essentials (game design)](https://create.roblox.com/docs/production/game-design/analytics-essentials) — consultat 2026-09-08.
- [Onboarding (game design)](https://create.roblox.com/docs/production/game-design/onboarding) — consultat 2026-09-08.
- [Experiments](https://create.roblox.com/docs/production/experiments) — consultat 2026-09-08.
- [Configs](https://create.roblox.com/docs/production/configs) — consultat 2026-09-08.
- [Studio Testing Modes](https://create.roblox.com/docs/studio/testing-modes) — consultat 2026-09-08.
- [Performance Monitor / Performance Dashboard](https://create.roblox.com/docs/performance-optimization/monitor) — consultat 2026-09-08.
- [Publish Games and Places (Access settings)](https://create.roblox.com/docs/production/publishing/publish-games-and-places) — consultat 2026-09-08.
- [Paid Access in Robux](https://create.roblox.com/docs/production/monetization/paid-access-robux) — consultat 2026-09-08.
- [Private Servers](https://create.roblox.com/docs/production/monetization/private-servers) — consultat 2026-09-08.
- [DataStore Error Codes and Limits](https://create.roblox.com/docs/cloud-services/data-stores/error-codes-and-limits) — consultat 2026-09-08 (context general, nu strict analytics).
- [DevForum: New OpenCloud APIs for Analytics, Events, Experiments, and Thumbnail Personalization](https://devforum.roblox.com/t/new-opencloud-apis-for-analytics-events-experiments-and-thumbnail-personalization/4828676) — 24 august 2026.
- [DevForum: Evolving Experiments and Analytics: Segmentation, Experiment Targeting, Early Access Program, and More](https://devforum.roblox.com/t/evolving-experiments-and-analytics-segmentation-experiment-targeting-early-access-program-and-more/4828462) — 24 august 2026.
- [DevForum: Analytics — Custom Dashboards to Save, Organize and Share Custom Charts](https://devforum.roblox.com/t/analytics-custom-dashboards-to-save-organize-and-share-custom-charts/4844585) — 1 septembrie 2026.
- [GameAnalytics — What is GameAnalytics? (docs.gameanalytics.com)](https://docs.gameanalytics.com/) — secundar, fără dată vizibilă, pagina Roblox-specifică nu a putut fi confirmată (404/redirect eșuat), consultat 2026-09-08.
- en.help.roblox.com (Terms of Use, Community Standards) — **surse consultate dar inaccesibile în această sesiune (HTTP 403)**; conținutul relevant despre analytics terț și minori rămâne neverificat direct, notat explicit ca NEVERIFICAT în text.
