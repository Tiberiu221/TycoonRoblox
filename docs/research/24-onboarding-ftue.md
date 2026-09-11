# Onboarding și primele 5 minute (FTUE) pe Roblox

## Rezumat executiv

- Roblox tratează onboarding-ul ca disciplină oficială cu documentație dedicată: **FTUE (First-Time User Experience)** = primele minute de joc, măsurat prin **D1 retention** + "onboarding goals". Ținta explicită oficială: **FTUE cât mai scurt, ideal ≤ 5 minute** până la prima "distracție" (create.roblox.com/docs/production/analytics/retention).
- Roblox recomandă trei tehnici de onboarding, în ordinea preferinței: **elemente vizuale** (săgeți, particule, glow) > **tutoriale contextuale** (just-in-time, declanșate de acțiune) > **hint-uri temporizate** (afișate doar celor care se blochează). Tutorialele lungi, liniare, cu text sunt explicit descurajate.
- Exemplul oficial Roblox ("Plant") arată o cădere de **70,48% între pasul 1 și pasul 2** al funnel-ului de onboarding și **sub 3% completare a pasului 9**. E un exemplu ilustrativ dintr-un joc-referință, nu o medie de platformă — dar arată ordinul de mărime al pierderilor.
- Ecranul de încărcare se construiește 100% în `ReplicatedFirst` + `ReplicatedFirst:RemoveDefaultLoadingScreen()`. Roblox oferă cod complet funcțional pentru asta (inclus mai jos).
- **Experience Notifications** e mecanismul oficial de "revino mâine": API de opt-in (`ExperienceNotificationService:PromptOptIn()`), prag de eligibilitate (100+ vizite), rată de trimitere 1 notificare/zi/utilizator (relaxat din 1/3 zile în iunie 2024), text limitat la 99 caractere.
- **Localizarea automată acoperă doar 17 limbi și NU include româna.** Româna (`ro` / `ro-ro`) există doar în lista de 49 de coduri de limbă pentru tabele de localizare **manuale**. Pentru Driftwood (engleză + română), traducerea în română trebuie făcută manual, nu se poate bifa "auto-translate".
- `UserGameSettings:GetOnboardingCompleted/SetOnboardingCompleted(onboardingId)` există, dar **acceptă în prezent doar `"DynamicThumbstick"`** — nu e un API generic pentru urmărirea propriilor tutoriale. Pentru progresul propriu prin tutorial, Driftwood trebuie să-și salveze singur flag-urile în DataStore.
- Roblox recomandă cadență de conținut: update-uri mici la fiecare **2-4 săptămâni**, update-uri mari la fiecare **2-3 luni** — coincide aproape exact cu ciclul de sezon de 4 săptămâni din brief-ul Driftwood.
- `AnalyticsService:LogOnboardingFunnelStepEvent(player, step, stepName, customFields)` există special pentru urmărirea pas-cu-pas a FTUE; limită **1-100 pași**, limită **10 funnel-uri unice / experiență** (pentru `LogFunnelStepEvent` generic), **8000 combinații unice** de custom fields.
- Nu există date publice oficiale Roblox despre "% jucători care pleacă în primele 1-3 minute" la nivel de platformă — doar exemple ilustrative și anecdote de dezvoltatori (secundar, vezi mai jos).

## Fapte verificate

- FTUE = "the first few minutes of gameplay"; succes măsurat prin D1 retention + "onboarding goals". — https://create.roblox.com/docs/production/game-design/onboarding — actualizat 2026-09-03 — confidence: ridicata
- Recomandare oficială: FTUE "ideally in 5 minutes or less after entering your game". — https://create.roblox.com/docs/production/analytics/retention — actualizat 2026-09-03 — confidence: ridicata
- Cele trei practici de nivel înalt pentru onboarding: "Teach the essentials", "Get to the fun quickly", "Leave players wanting more". — https://create.roblox.com/docs/production/game-design/onboarding — actualizat 2026-09-03 — confidence: ridicata
- Cele trei tehnici recomandate: elemente vizuale, tutoriale contextuale ("just in time"), hint-uri temporizate. — https://create.roblox.com/docs/production/game-design/onboarding-techniques — actualizat 2026-09-03 — confidence: ridicata
- În exemplul oficial "Plant": Step 1 (In Farm) = 100%, Step 2 (Plant Seed) = 29,52% (cădere de 70,48%), Step 9 (Return to Farm) < 3%. — https://devforum.roblox.com/t/improving-onboarding-through-funnel-events/3064458 — 2024-07-12 — confidence: medie (exemplu ilustrativ dintr-un singur joc-referință Roblox, nu statistică de platformă)
- Hint temporizat recomandat: dacă majoritatea jucătorilor apasă un buton în ~10s, afișează hint-ul la 11s. — https://create.roblox.com/docs/production/game-design/onboarding-techniques — actualizat 2026-09-03 — confidence: ridicata (exemplu ipotetic din documentație, nu date empirice)
- Update-uri mici recomandate la fiecare 2-4 săptămâni, update-uri mari la fiecare 2-3 luni pentru D30 retention. — https://create.roblox.com/docs/production/analytics/retention — actualizat 2026-09-03 — confidence: ridicata
- `ReplicatedFirst` replichează instanțe către client înaintea oricărui alt conținut; `ReplicatedFirst:RemoveDefaultLoadingScreen()` elimină ecranul default. — https://create.roblox.com/docs/players/loading-screens — actualizat 2026-09-03 — confidence: ridicata
- `ContentProvider:PreloadAsync(contentIdList, callback?)` — preîncarcă assets, e blocant (yields); best practice: preîncarcă doar assets esențiale, nu tot Workspace-ul; lasă jucătorii să sară peste loading sau auto-skip după un timp. — https://create.roblox.com/docs/reference/engine/classes/ContentProvider — actualizat 2026-09-03 — confidence: ridicata
- `ExperienceNotificationService:PromptOptIn()` afișează promptul de opt-in (text nepersonalizabil, standardizat); nu apare dacă utilizatorul are <13 ani, are deja notificările pornite, sau a văzut promptul în ultimele 30 de zile. — https://create.roblox.com/docs/production/promotion/experience-notifications — actualizat 2026-09-03 — confidence: ridicata
- Eligibilitate pentru API-ul de notificări: minim 100 de vizite de la lansare, jocul să nu fie sub moderare, developerul să aibă drepturi de management. — https://create.roblox.com/docs/production/promotion/experience-notifications — actualizat 2026-09-03 — confidence: ridicata
- Limită de livrare: 1 notificare/zi/utilizator/experiență. Anterior era 1 la 3 zile; relaxat la 1/zi pe 6 iunie 2024. — https://devforum.roblox.com/t/updates-to-notification-rate-limits/3007106 — 2024-06-06 — confidence: ridicata
- Text-ul notificării e limitat la 99 de caractere, poate include parametri custom nelimitați ca număr. — https://create.roblox.com/docs/production/promotion/experience-notifications — actualizat 2026-09-03 — confidence: ridicata
- `joinExperience.launchData` (citit via `Player:GetJoinData()`) e limitat la maxim 200 bytes. — https://create.roblox.com/docs/production/promotion/experience-notifications — actualizat 2026-09-03 — confidence: ridicata
- Tipul `type` acceptat de `UserNotification` e în prezent doar `"MOMENT"`. — https://create.roblox.com/docs/production/promotion/experience-notifications — actualizat 2026-09-03 — confidence: ridicata
- Analytics de notificări necesită minim 100 de impresii agregate pentru a afișa statistici. — https://create.roblox.com/docs/production/promotion/experience-notifications — actualizat 2026-09-03 — confidence: ridicata
- Traducerea automată acoperă exact 17 limbi (fără română): Arabic, Chinese Simplified, Chinese Traditional, English, French, German, Hindi, Indonesian, Italian, Japanese, Korean, Polish, Portuguese, Russian, Spanish, Thai, Turkish, Vietnamese. — https://create.roblox.com/docs/production/localization/automatic-translations — actualizat 2026-09-03 — confidence: ridicata
- Tabelele de localizare (manuale) acceptă 49 de coduri de limbă/locale, inclusiv Romanian (`ro`, locale `ro-ro`). — https://create.roblox.com/docs/production/localization/language-codes — actualizat 2026-09-03 — confidence: ridicata
- Cota de traducere automată se calculează per-caracter × per-limbă (ex: "hello" = 5 caractere × 10 limbi = 50 unități de cotă); există cotă inițială + cotă lunară reînnoibilă. — https://create.roblox.com/docs/production/localization/automatic-translations — actualizat 2026-09-03 — confidence: ridicata
- Automatic Text Capture (ATC) poate dura până la câteva zile să apară în Translator Portal când e capturat din joc live; captura din Studio apare în 1-2 minute. — https://create.roblox.com/docs/production/localization/automatic-translations — actualizat 2026-09-03 — confidence: ridicata
- `UserGameSettings:SetOnboardingCompleted(onboardingId)` acceptă în prezent DOAR `"DynamicThumbstick"` ca ID valid; orice alt ID aruncă eroare. Procesul e ireversibil (developer poate forța completarea, nu poate reseta). — https://create.roblox.com/docs/reference/engine/classes/UserGameSettings — accesat 2026-09-08 — confidence: ridicata
- `AnalyticsService:LogOnboardingFunnelStepEvent(player, step, stepName, customFields?)` — step limitat la 1-100; pașii omiși sunt considerați completați automat. — https://create.roblox.com/docs/reference/engine/classes/AnalyticsService — accesat 2026-09-08 — confidence: ridicata
- `AnalyticsService:LogFunnelStepEvent` (funnel generic) e limitat la 10 funnel-uri unice per experiență și 8000 combinații unice de custom fields per experiență. — https://create.roblox.com/docs/reference/engine/classes/AnalyticsService — accesat 2026-09-08 — confidence: ridicata
- D1/D7/D30 retention se calculează pe cohorte după data primei intrări în joc; datele D7/D30 pentru zilele recente sunt incomplete până trec 7, respectiv 30 de zile. — https://create.roblox.com/docs/production/analytics/retention — actualizat 2026-09-03 — confidence: ridicata
- Roblox nu publică un benchmark numeric fix pentru "D1 retention bun"; oferă doar comparație relativă față de experiențe similare/gen, în dashboard. — https://create.roblox.com/docs/production/analytics/retention + https://devforum.roblox.com/t/analytics-new-experience-overview-with-insights-benchmarks-realtime/3108840 — 2024-08-08 — confidence: medie
- `GuiBase2d.AutoLocalize` (bool) — când e true, se aplică localizare automată acelui obiect și descendenților, folosind intrările din tabelul cloud de localizare. — https://create.roblox.com/docs/reference/engine/classes/GuiBase2d — accesat 2026-09-08 — confidence: ridicata
- Anecdotă de dezvoltator: "~70% dintre jucători intră, stau lângă spawn ~3 minute, apoi pleacă" într-un joc aflat în testare. — https://devforum.roblox.com/t/why-are-people-spending-less-than-3-minutes-at-our-game/2843046 — 2024-02-18 — **SECUNDAR**, un singur joc, fără context de cauză confirmată — confidence: scazuta

## Detalii

### 1. Cadrul oficial FTUE și D1 retention

Documentația Roblox (`/docs/production/game-design/onboarding`, ultima actualizare 2026-09-03 — foarte recentă) definește onboarding-ul/FTUE ca fiind "the first few minutes of gameplay that new players experience" și îl leagă direct de două metrici: **D1 retention** și **onboarding goals**. Funnel-ul de jucători ("Player Funnel") e descris explicit ca o piramidă inversată — lat sus, îngust jos — pentru că "fewer players complete each step" la fiecare pas al onboarding-ului. Toate jocurile pierd jucători pe acest traseu; obiectivul e minimizarea pierderii, nu eliminarea ei.

Cele trei practici recomandate, în ordine:

1. **Teach the essentials** — controale de navigare/interacțiune + Core Loop-ul jocului. Jucătorul trebuie să înțeleagă *ce* trebuie să facă și *de ce*.
2. **Get to the fun quickly** — "New players typically decide their interest in a game within minutes." Demonstrează valoare rapid prin progresie (XP thresholds mici la început), motivatori sociali, și itemi/monedă de start.
3. **Leave players wanting more** — obiective pe termen scurt/mediu/lung vizibile (skill tree, season pass, colecții) + "moments of joy" (recompense, animații, efecte la milestone-uri).

Pentru D1 retention specific, `/docs/production/analytics/retention` (actualizat 2026-09-03) dă rețeta operațională:

- Tutorial scurt sau tooltip-uri contextuale — evită tutorialele lungi.
- Livrează un "moment de bucurie" după prima completare a core loop-ului.
- Arată o previzualizare a progresului posibil.
- **"ideally in 5 minutes or less after entering your game"** — asta e ținta explicită de durată pentru FTUE.

### 2. Funnel-ul de onboarding: date concrete și cum se măsoară

Postarea oficială devforum "Improving Onboarding through Funnel Events" (2024-07-12, autor cont oficial Roblox `BreakfastCandy`) folosește jocul-referință **Plant** (plantezi semințe, vinzi recolta, reinvestești) ca studiu de caz — foarte similar structural cu Driftwood (buclă simplă de colectare→procesare→reinvestire). Numerele din exemplu:

- Step 1 (In Farm) = 100% — toți jucătorii care intră prima dată.
- Step 2 (Plant Seed) = 29,52% — o cădere de **70,48%** doar la primul pas de acțiune.
- Step 9 (Return to Farm) < 3% completare finală.

Roblox atribuie explicit cauzele probabile ale căderii mari de la Step 1→2 (excluzând bug-uri): (a) obiectivul nu e clar, (b) procesul în sine nu e clar. Soluția lor documentată a fost banală: **o iconiță deasupra ghiveciului care arăta că poți planta acolo** — nu text, nu cutscene, un singur indiciu vizual persistent.

Pentru instrumentare, `AnalyticsService:LogOnboardingFunnelStepEvent(player: Player, step: number, stepName: string, customFields: Dictionary?)` e API-ul dedicat FTUE (limitat la pașii 1-100). Pentru funnel-uri custom recurente (ex: flux de reparație), `AnalyticsService:LogFunnelStepEvent(player, funnelName, funnelSessionId, step?, stepName, customFields?)` — limitat la **10 funnel-uri unice per experiență** și **8000 combinații unice de custom fields**.

```lua
local AnalyticsService = game:GetService("AnalyticsService")

-- Pasul 1 al FTUE Driftwood
AnalyticsService:LogOnboardingFunnelStepEvent(player, 1, "Joined Game")
-- ...
AnalyticsService:LogOnboardingFunnelStepEvent(player, 2, "Placed First Net")
AnalyticsService:LogOnboardingFunnelStepEvent(player, 3, "Caught First Item")
AnalyticsService:LogOnboardingFunnelStepEvent(player, 4, "Repaired First Item")
AnalyticsService:LogOnboardingFunnelStepEvent(player, 5, "Donated to Workshop")
```

Notă importantă: **pașii omiși sunt considerați completați automat** ("if any steps are skipped, the intermediate steps will be considered completed") — deci dacă vrei date curate, loghează fiecare pas efectiv, nu doar pe cele "cheie".

### 3. Cele trei tehnici de onboarding (ordinea contează)

Din `/docs/production/game-design/onboarding-techniques` (actualizat 2026-09-03), documentul e explicit: "Players who don't understand what to do in the first few minutes are likely to quit, but so are players who are bored by lengthy and prescriptive tutorials."

**Elemente vizuale** (prioritate #1) — săgeți, particule, glow, poteci luminoase, semne in-world. Trei tehnici de claritate:
- *Prominență* — plasate în linia vizuală naturală a jucătorului, nu ca pop-up ignorabil.
- *Highlight-uri* — mai eficiente decât textul ("Open your inventory by clicking the backpack button" vs. o săgeată care arată direct butonul).
- *Hint-uri* — indicii persistente care ghidează fără să oblige.

Beneficii documentate: claritate, accesibilitate (nu necesită traducere, funcționează pe mobil unde textul e greu de citit), imersiune (nu blochează explorarea), feedback.

**Tutoriale contextuale ("just in time")** — declanșate de acțiune naturală (ex: intri într-o zonă nouă, prinzi primul obiect rupt), nu într-o secvență fixă la început. Beneficii: retenție mai bună a informației (înveți făcând), onboarding mai rapid (amâni informația neesențială), încărcare cognitivă redusă (nu tot deodată). Exemplu citat: în *Squishmallows*, tutorialul de combinare apare doar când jucătorul are deja 2 Squishmallow-uri identice în inventar — nu în intro.

**Hint-uri temporizate** — pentru jucătorii care se blochează. Exemplu concret din documentație: dacă majoritatea jucătorilor apasă un buton în ~10 secunde, afișezi hint-ul (highlight) la 11 secunde — suficient de repede cât să nu frustreze, suficient de târziu cât să nu enerveze pe cei care s-au descurcat singuri.

### 4. Ecranul de încărcare — cod complet și funcțional

`ReplicatedFirst` e serviciul care replichează instanțe către client **înaintea** oricărui alt conținut, exact de aceea e locul unde se pune loading screen-ul custom. Cod oficial (din `/docs/players/loading-screens`, actualizat 2026-09-03), pus într-un `LocalScript` sub `ReplicatedFirst`:

```lua
local Players = game:GetService("Players")
local ReplicatedFirst = game:GetService("ReplicatedFirst")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local loadingScreen = Instance.new("ScreenGui")
loadingScreen.IgnoreGuiInset = true
loadingScreen.Parent = playerGui

local textLabel = Instance.new("TextLabel")
textLabel.Size = UDim2.new(1, 0, 1, 0)
textLabel.BackgroundColor3 = Color3.fromRGB(0, 20, 40)
textLabel.Text = "Loading"
textLabel.Parent = loadingScreen

-- Elimină ecranul default Roblox
ReplicatedFirst:RemoveDefaultLoadingScreen()

task.wait(5)  -- durată minimă forțată, pentru consistență vizuală

if not game:IsLoaded() then
	game.Loaded:Wait()
end

loadingScreen:Destroy()
```

Documentația recomandă și varianta cu `TweenService` pentru animații (fade-in, rotație continuă a unui "loading ring"), și menționează separat că teleportarea între place-uri folosește alt mecanism (`Teleport between places`), nu `ReplicatedFirst`.

**Preload de assets** — `ContentProvider:PreloadAsync(contentIdList, callback?)` e blocant (yields) și acceptă un callback opțional `(assetId, assetFetchStatus)` pentru progres. Best practices oficiale: preîncarcă **doar assets esențiale** (loading screen, UI, zona de start), NU tot Workspace-ul — pop-in ocazional e acceptabil, timpul mare de încărcare nu. Și: **lasă jucătorii să sară peste ecranul de încărcare, sau auto-skip după un timp** — asta e o recomandare directă împotriva blocării forțate.

```lua
local ContentProvider = game:GetService("ContentProvider")

local assetsToPreload = {
    "rbxassetid://NET_ICON_ID",
    "rbxassetid://RIVER_BG_ID",
    "rbxassetid://UI_FRAME_ID",
}

ContentProvider:PreloadAsync(assetsToPreload, function(assetId, status)
    print("Preloaded:", assetId, status)
end)
```

### 5. Experience Notifications — mecanismul oficial de "revino mâine"

Lansat public în martie 2024 (API live din februarie 2024, conform devforum 2826474, "Introducing Experience Notifications", 2024-02-06). E sistemul construit special pentru re-engagement, deci exact ce cere brief-ul Driftwood pentru "de ce se întoarce cineva mâine".

**Eligibilitate** (pentru a putea trimite notificări):
- Minim 100 de vizite de la lansarea jocului.
- Jocul să nu fie sub moderare.
- Developerul să aibă drepturi de management pe joc.

**Flux de opt-in** (doar 13+, promptul are text fix, nepersonalizabil):

```lua
local ExperienceNotificationService = game:GetService("ExperienceNotificationService")

local function canPromptOptIn()
    local success, canPrompt = pcall(function()
        return ExperienceNotificationService:CanPromptOptInAsync()
    end)
    return success and canPrompt
end

if canPromptOptIn() then
    pcall(function()
        ExperienceNotificationService:PromptOptIn()
    end)
end

ExperienceNotificationService.OptInPromptClosed:Connect(function()
    print("Opt-in prompt closed")
end)
```

Promptul **nu apare** dacă utilizatorul: are sub 13 ani, are deja notificările pornite pentru joc, sau a văzut promptul în ultimele 30 de zile — deci nu poți re-cere insistent.

**Trimiterea efectivă** se face din server, prin pachetul `OpenCloud` (din Creator Store → Toolbox → Packages), mutat în `ServerScriptService`:

```lua
local ServerScriptService = game:GetService("ServerScriptService")
local OCUserNotification = require(ServerScriptService.OpenCloud.V2.UserNotification)

local userNotification = {
    payload = {
        messageId = "ID_STRING_CREAT_IN_DASHBOARD",
        type = "MOMENT", -- singurul tip suportat momentan
        parameters = {
            ["netCount"] = {int64Value = 3},
        },
        joinExperience = { launchData = "riverbank_spawn" }, -- max 200 bytes
    }
}

local result = OCUserNotification.createUserNotification(recipientPlayerID, userNotification)
if result.statusCode ~= 200 then
    warn(result.statusCode, result.error.code, result.error.message)
end
```

**Limite dure:**

| Limită | Valoare | Sursă |
|---|---|---|
| Notificări per utilizator per experiență | 1 / zi (relaxat din 1/3 zile în iunie 2024) | devforum 3007106, 2024-06-06 |
| Lungime text notificare | 99 caractere (incl. parametri) | create.roblox.com/docs, 2026-09-03 |
| `launchData` | max 200 bytes | create.roblox.com/docs, 2026-09-03 |
| Vizite minime pentru eligibilitate API | 100 de la lansare | create.roblox.com/docs, 2026-09-03 |
| Impresii minime pentru statistici | 100 agregate | create.roblox.com/docs, 2026-09-03 |
| Vârstă minimă pentru opt-in | 13 ani | create.roblox.com/docs, 2026-09-03 |
| Interval re-prompt opt-in | 30 zile | create.roblox.com/docs, 2026-09-03 |
| Tip de notificare suportat | doar `"MOMENT"` | create.roblox.com/docs, 2026-09-03 |

Reguli de conținut explicite (interzis): reclame deghizate în notificare organică, presiune falsă de timp ("cumpără în următoarele 10 minute"), bait-and-switch cu "gratis", trimitere directă spre ecran de cumpărare fără consimțământ explicit. Și regula centrală: **"Games should not require users to turn on notifications in order to participate or advance in gameplay."** — pentru Driftwood, asta înseamnă că acumularea offline NU poate fi condiționată de opt-in la notificări.

### 6. Skip de tutorial și memorarea progresului jucătorului

`UserGameSettings.AllTutorialsDisabled` (bool, read-only) — reflectă dacă jucătorul a dezactivat global tutorialele din setările Roblox; poate fi citit pentru a respecta preferința.

`UserGameSettings:GetOnboardingCompleted(onboardingId): boolean` / `SetOnboardingCompleted(onboardingId): ()` — **atenție, capcană**: în prezent acceptă **DOAR** `"DynamicThumbstick"` ca `onboardingId` valid (tutorialul nativ Roblox pentru controale mobile). Orice alt ID aruncă eroare. **Nu e un API generic pentru propriile tutoriale ale jocului.** Pentru Driftwood, urmărirea "a văzut tutorialul plasei" trebuie implementată manual: un flag boolean salvat în DataStore-ul propriu al jucătorului (ex. `playerData.tutorialSteps.netPlaced = true`), verificat la login pentru a decide dacă se arată din nou secvența de onboarding.

### 7. Localizare: engleză + română

Roblox are **două sisteme separate**, cu acoperire de limbi diferită:

1. **Traducere automată** — 17 limbi, gratuit/inclus, se activează din Creator Dashboard fără cod. Lista completă: Arabic, Chinese (Simplified), Chinese (Traditional), English, French, German, Hindi, Indonesian, Italian, Japanese, Korean, Polish, Portuguese, Russian, Spanish, Thai, Turkish, Vietnamese. **Româna NU e în listă.**
2. **Tabele de localizare cloud (manuale)** — 49 de coduri de limbă/locale acceptate, inclusiv `ro` / `ro-ro` (Romanian - Română).

Mecanismul de captură automată de text (ATC) prinde string-uri din UI cu `GuiBase2d.AutoLocalize = true` (implicit pare activ pe elementele text standard) și le adaugă în tabelul de localizare cu valoare goală — durează "up to a few days" din joc live, sau 1-2 minute din testare în Studio (`Window → Localization`). Pentru română, tot ce ajunge captat automat va rămâne **necompletat** până cineva scrie manual traducerea în Translator Portal sau prin CSV upload.

Cota de traducere automată (relevantă doar pentru cele 17 limbi automate) e per-caracter × per-limbă: "hello" (5 caractere) tradus în 10 limbi = 50 de unități de cotă, cu cotă inițială + cotă lunară reînnoibilă.

Pentru string-uri dinamice sau context-dependente (ex: "plasă" cu sens diferit în context diferit), API-ul de scripting:

```lua
local LocalizationService = game:GetService("LocalizationService")

local ok, translator = pcall(function()
    return LocalizationService:GetTranslatorForPlayerAsync(player)
end)

if ok then
    local text = translator:Translate(script, "net_placed_message")
end
```

Recomandare practică: pentru Driftwood, cu doar EN + RO, complexitatea sistemului cloud (Translator Portal, Context overrides, chei) e probabil overkill inițial — o alternativă mai simplă e un `ModuleScript` propriu cu un dicționar `{en = {...}, ro = {...}}` indexat după `Players.LocalPlayer.LocaleId`, fără a depinde de tabelul cloud Roblox. Rămâne de testat în Studio care abordare e mai ușor de întreținut pe termen lung (vezi Întrebări deschise).

### 8. Cadență de conținut și sezoane

Din `/docs/production/analytics/retention` (secțiunea D30): "**A common frequency is to release smaller updates on the existing mechanics every 2-4 weeks, and bigger updates of new features every 2-3 months.**" Sezonul de 4 săptămâni din brief-ul Driftwood cade exact la limita superioară a intervalului recomandat pentru update-uri mici — validare directă a deciziei de design existente.

### 9. Primele 5 minute — script propus pentru Driftwood

Bazat pe cadrul oficial (teach essentials → get to fun quickly → leave wanting more) + tehnicile recomandate (vizual > contextual > timed hint) + ținta de 5 minute:

| Timp | Ce se întâmplă | Tehnică folosită | Eveniment de logat |
|---|---|---|---|
| 0:00-0:05 | Ecran de încărcare custom (`ReplicatedFirst`), preload doar UI + primele sprite-uri de râu/plasă | `ContentProvider:PreloadAsync` pe asset-uri esențiale | `LogOnboardingFunnelStepEvent(1, "Joined Game")` |
| 0:05-0:15 | Spawn direct pe malul râului, camera arată imediat râul curgând cu 1-2 obiecte vizibile plutind | Vizual — nu text, nu dialog NPC | — |
| 0:15-0:30 | Un indicator vizual persistent (glow/săgeată) arată unde se plasează plasa; jucătorul plasează prima plasă printr-un singur click/tap | Elemente vizuale (prominență + highlight) | `LogOnboardingFunnelStepEvent(2, "Placed First Net")` |
| 0:30-1:00 | Primul obiect e prins automat de plasă — recompensă vizuală clară (particule + sunet) | "Moment of joy" | `LogOnboardingFunnelStepEvent(3, "Caught First Item")` |
| 1:00-2:00 | Tutorial contextual declanșat DOAR acum (nu la intro): un indicator arată atelierul, jucătorul duce obiectul, vede că e "rupt" și are nevoie de materiale + timp | Tutorial contextual just-in-time | `LogOnboardingFunnelStepEvent(4, "Reached Workshop")` |
| 2:00-3:00 | Reparația pornește (timer vizibil); între timp jucătorul e lăsat liber să exploreze malul, plaseze a doua plasă | Hint temporizat DOAR dacă jucătorul stă inactiv >15-20s | `LogOnboardingFunnelStepEvent(5, "Started First Repair")` |
| 3:00-4:00 | Primul obiect reparat — moment de bucurie mare (animație + opțiune "păstrează sau donează"); dacă donează, se arată vizual progresul comun al orașului (chiar dacă nu se deblochează nimic încă) | Progression preview + social hook | `LogOnboardingFunnelStepEvent(6, "First Repair Complete")` |
| 4:00-4:30 | UI arată explicit: "plasele tale strâng obiecte și cât ești offline" — un singur banner/tooltip, nu un ecran de tutorial separat | Comunicare explicită a buclei offline (critică pentru retenție, cf. brief) | `LogOnboardingFunnelStepEvent(7, "Saw Offline Hook")` |
| 4:30-5:00 | Prompt de opt-in la notificări, declanșat contextual (ex: "vrei să știi când plasa se umple?"), NU la intro | `ExperienceNotificationService:PromptOptIn()` — doar dacă `CanPromptOptInAsync()` e true | `LogOnboardingFunnelStepEvent(8, "Notification Opt-in Shown")` |

Restul celor 7 sisteme (index de colecție, sezoane, amonte, inundație, monetizare) rămân **complet ascunse** în primele 5 minute — progressive disclosure, nu overload.

## Recomandari concrete pentru Driftwood

1. **Instrumentează funnel-ul de la ziua 1** cu `AnalyticsService:LogOnboardingFunnelStepEvent`, folosind exact pașii din tabelul de mai sus. Fără asta, orice discuție despre "unde pierdem jucători" e ghicit, nu măsurat — și Roblox oferă dashboard-ul gratuit dacă logezi corect.
2. **Nu construi tutorial text/dialog pentru plasarea plasei.** Folosește un indicator vizual persistent (glow pe zona de plasare) — conform documentației oficiale, e mai eficient și accesibil (funcționează și fără traducere completă în română).
3. **Amână tutorialul de reparație/atelier până când jucătorul prinde efectiv primul obiect** (tutorial contextual, nu la intro) — reduce încărcarea cognitivă din primele 15 secunde, care sunt cele mai critice pentru abandon.
4. **Comunică bucla offline explicit, o singură dată, cu un banner scurt, nu un ecran separat de "cum funcționează".** E mecanismul central de retenție din brief; dacă jucătorul nu-l vede clar în primele 5 minute, motivul de a reveni mâine nu există.
5. **Nu cere opt-in la notificări în primele 30 de secunde.** Contextualizează-l ("vrei să afli când plasa se umple?") undeva după minutul 4, respectând regula Roblox că notificările nu pot fi cerință pentru progres.
6. **Construiește ecranul de încărcare direct pe codul oficial din `/docs/players/loading-screens`** — e deja testat de Roblox, minimizează riscul de bug-uri de ordine de încărcare. Preîncarcă DOAR sprite-urile din primele 5 minute (plasă, râu, prim obiect), nu tot setul de 200+ obiecte din indexul de colecție.
7. **Nu te baza pe traducerea automată pentru română** — nu există. Bugetează timp/cost pentru traducere manuală (Translator Portal sau CSV) încă din faza de prototip, sau construiește un dicționar propriu simplu în `ModuleScript` dacă textul rămâne puțin (recomandat pentru MVP).
8. **Nu folosi `UserGameSettings:SetOnboardingCompleted` pentru propriul tutorial** — acceptă doar `"DynamicThumbstick"`. Salvează propriile flaguri de tutorial în DataStore, alături de restul datelor jucătorului, cu `UpdateAsync`.
9. **Aliniază cadența de conținut Driftwood (sezoane de 4 săptămâni) cu recomandarea oficială** de update-uri mici la 2-4 săptămâni — deja aliniat, nu schimba nimic aici, dar adaugă update-uri "mari" (sisteme noi) la fiecare 2-3 luni pentru D30 retention.
10. **Pentru jucătorii care se alătură unui server cu orașul deja parțial/complet deblocat**: arată explicit progresul comun ca parte din "leave players wanting more" — un indicator vizual mare al procentului de colecție/deblocări, nu o explicație textuală. Testează în Studio dacă un jucător nou într-un oraș avansat simte FOMO motivant sau descurajare (vezi Întrebări deschise — nu există sursă oficială Roblox pe acest caz specific).

## Riscuri si necunoscute

- **Nu există date oficiale Roblox despre procentul de jucători care abandonează în primele 1-3 minute la nivel de platformă.** Singurele numere concrete sunt exemplul "Plant" (un joc de referință, nu medie) și o anecdotă de dezvoltator (un singur joc, cauze neconfirmate). Orice cifră tip "X% dintre jucători pleacă în primul minut" găsită în bloguri/YouTube trebuie tratată ca NEVERIFICAT până testată direct pe Driftwood.
- **`UserGameSettings:SetOnboardingCompleted` fiind limitat la `"DynamicThumbstick"` e o constatare din documentația de referință curentă (accesată 2026-09-08) — Roblox poate extinde lista de ID-uri acceptate în viitor fără să anunțe extensiv; verifică din nou înainte de a construi pe acest API.**
- **Regulile de "dark patterns" pentru notificări** (fără presiune falsă de timp, fără bait-and-switch) sunt destul de stricte — designul de reamintire pentru acumularea offline trebuie revizuit cu atenție să nu pară manipulativ (ex: "plasa se revarsă, vino acum!" ar putea fi interpretat ca presiune de timp falsă, deși pragul de 8h e real).
- **API-ul de notificări cere pachetul OpenCloud din Creator Store** — o dependință externă (chiar dacă oficială Roblox) care trebuie verificată pentru actualizări/breaking changes separat de codul propriu.
- **Traducerea manuală în română înseamnă cost de timp/bani recurent** — orice string nou adăugat trebuie tradus manual, nu se auto-completează; asta poate încetini iterația rapidă dacă textul UI se schimbă des în prototipare.
- **Analytics dashboard-ul Roblox pentru benchmark D1/D7/D30 necesită prag minim de trafic** (100+ DAU pentru insights, 100+ impresii pentru notificări) — un joc nou, mic, nu va avea acces la comparații relevante în primele săptămâni.

## Intrebari deschise

1. **Cât de mult conținut din tutorial-ul de 5 minute trebuie să fie skippabil pentru jucătorii recurenți** (ex: un prieten invitat de un jucător care revine)? Nu există API generic Roblox pentru asta (vezi limitarea `SetOnboardingCompleted`) — trebuie proiectat propriul sistem de flag-uri, testat în Studio cu conturi multiple.
2. **Ce simte un jucător nou care intră într-un server cu orașul deja mult deblocat** — motivează ("vreau să ajung acolo") sau descurajează ("nu mai am ce contribui")? Nu există sursă Roblox pe acest caz specific de joc shared-world; necesită playtest direct cu oameni reali, conform ordinii de lucru din brief.
3. **Merită tabelul cloud de localizare Roblox (cu Translator Portal, Context, chei) față de un `ModuleScript` propriu cu dicționar EN/RO**, dat fiind că automat nu acoperă româna oricum? De testat costul de întreținere real în Studio pe un set mic de string-uri înainte de a decide.
4. **Care e pragul optim de timp de inactivitate pentru hint-ul temporizat** la plasarea primei plase — documentația dă un exemplu ipotetic (10s→11s), dar valoarea reală pentru Driftwood trebuie găsită prin playtesting/Experiments, nu presupusă.
5. **Ce conținut exact intră în bannerul despre bucla offline** (0:00-4:30 din scriptul de mai sus) — un singur tooltip poate fi insuficient dacă mecanismul de "8 ore plafon" nu e intuitiv; de validat cu useri reali dacă înțeleg conceptul din prima expunere sau necesită un al doilea punct de atingere (ex: la login-ul din ziua 2, când primesc efectiv recompensa offline).
6. **Trebuie prompt-ul de notificări arătat în prima sesiune sau amânat pentru a doua vizită** (când jucătorul a văzut deja valoarea buclei offline și motivul de a fi notificat e mai clar)? Regula celor 30 de zile de cooldown la re-prompt face ca momentul primei cereri să conteze mult.

## Surse

- [Onboarding](https://create.roblox.com/docs/production/game-design/onboarding) — Roblox Creator Documentation — actualizat 2026-09-03
- [Onboarding techniques](https://create.roblox.com/docs/production/game-design/onboarding-techniques) — Roblox Creator Documentation — actualizat 2026-09-03
- [Retention](https://create.roblox.com/docs/production/analytics/retention) — Roblox Creator Documentation — actualizat 2026-09-03
- [Loading screens](https://create.roblox.com/docs/players/loading-screens) — Roblox Creator Documentation — actualizat 2026-09-03
- [Experience notifications](https://create.roblox.com/docs/production/promotion/experience-notifications) — Roblox Creator Documentation — actualizat 2026-09-03
- [Localization (overview)](https://create.roblox.com/docs/production/localization) — Roblox Creator Documentation — actualizat 2026-09-03
- [Automatic translation](https://create.roblox.com/docs/production/localization/automatic-translations) — Roblox Creator Documentation — actualizat 2026-09-03
- [Language codes](https://create.roblox.com/docs/production/localization/language-codes) — Roblox Creator Documentation — actualizat 2026-09-03
- [Manual translations](https://create.roblox.com/docs/production/localization/manual-translations) — Roblox Creator Documentation — actualizat 2026-09-03
- [Localize with scripting](https://create.roblox.com/docs/production/localization/localize-with-scripting) — Roblox Creator Documentation — actualizat 2026-09-03
- [ExperienceNotificationService (Class Reference)](https://create.roblox.com/docs/reference/engine/classes/ExperienceNotificationService) — Roblox Creator Documentation — accesat 2026-09-08
- [ContentProvider (Class Reference)](https://create.roblox.com/docs/reference/engine/classes/ContentProvider) — Roblox Creator Documentation — accesat 2026-09-08
- [AnalyticsService (Class Reference)](https://create.roblox.com/docs/reference/engine/classes/AnalyticsService) — Roblox Creator Documentation — accesat 2026-09-08
- [UserGameSettings (Class Reference)](https://create.roblox.com/docs/reference/engine/classes/UserGameSettings) — Roblox Creator Documentation — accesat 2026-09-08
- [ReplicatedFirst (Class Reference)](https://create.roblox.com/docs/reference/engine/classes/ReplicatedFirst) — Roblox Creator Documentation — accesat 2026-09-08
- [GuiBase2d (Class Reference)](https://create.roblox.com/docs/reference/engine/classes/GuiBase2d) — Roblox Creator Documentation — accesat 2026-09-08
- [Learn More About First-Time User Experience & Onboarding](https://devforum.roblox.com/t/learn-more-about-first-time-user-experience-onboarding/2621940) — DevForum, anunț oficial Roblox (BreakfastCandy) — 2023-09-28 (update inclus din 2023-12-07) — **anterior 2024, tratat ca posibil parțial depășit dar confirmat de doc-urile curente**
- [Improving Onboarding through Funnel Events](https://devforum.roblox.com/t/improving-onboarding-through-funnel-events/3064458) — DevForum, anunț oficial Roblox (BreakfastCandy) — 2024-07-12
- [Introducing Experience Notifications](https://devforum.roblox.com/t/introducing-experience-notifications/2826474) — DevForum, anunț oficial Roblox (raftwarz) — 2024-02-06 (update-uri incluse până 2024-06-06)
- [Updates to Notification Rate Limits](https://devforum.roblox.com/t/updates-to-notification-rate-limits/3007106) — DevForum, anunț oficial Roblox (konormcgregor15) — 2024-06-06
- [Analytics: New Experience Overview with Insights, Benchmarks, Realtime](https://devforum.roblox.com/t/analytics-new-experience-overview-with-insights-benchmarks-realtime/3108840) — DevForum, anunț oficial Roblox (quazotheduck) — 2024-08-08
- [Analytics: View retention by acquisition source and select your benchmark set](https://devforum.roblox.com/t/analytics-view-retention-by-acquisition-source-and-select-your-benchmark-set/4010157) — DevForum, anunț oficial Roblox (signal_zzz) — 2025-10-16
- [Evolving Experiments and Analytics](https://devforum.roblox.com/t/evolving-experiments-and-analytics-segmentation-experiment-targeting-early-access-program-and-more/4828462) — DevForum, anunț oficial Roblox (OrogeneIstari) — 2026-08-24
- [Why are people spending less than 3 minutes at our game?](https://devforum.roblox.com/t/why-are-people-spending-less-than-3-minutes-at-our-game/2843046) — DevForum, discuție comunitate — **SECUNDAR** — 2024-02-18
