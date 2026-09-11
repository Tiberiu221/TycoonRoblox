# Monetizare pe Roblox: MarketplaceService, ProcessReceipt, PolicyService

## Rezumat executiv

- Contractul de cumpărare pe Roblox e centrat pe callback-ul unic `MarketplaceService.ProcessReceipt`. Trebuie idempotent (verificare `PurchaseId` în DataStore) și trebuie să returneze `Enum.ProductPurchaseDecision.PurchaseGranted` sau `.NotProcessedYet` — Roblox reîncearcă automat livrarea data viitoare când userul se conectează, deci codul de livrare NU trebuie să presupună o singură rulare.
- Game Passes și Developer Products au preț permis **1–1.000.000.000 Robux**. Nu există un preț „minim recomandat" documentat oficial; presetările comune (99, 199, 499 Robux etc.) sunt convenție de piață, nu regulă Roblox — le marchez explicit ca NEVERIFICAT/secundar mai jos.
- **Începând cu 30 mai 2026, vânzările cross-game de Passes și Developer Products se dezactivează.** Dacă Driftwood ar fi vrut vreodată să vândă un pass dintr-un joc separat (hub, world-map etc.), trebuie migrat pe `PromptRobuxTransferAsync` (comision 10%, interval 10–500 Robux) înainte de acea dată.
- `PolicyService:GetPolicyInfoForPlayerAsync(player)` întoarce un dicționar cu 11 câmpuri verificate (vezi tabel). Cel mai relevant pentru Driftwood: `ArePaidRandomItemsRestricted` — dacă vindem vreodată o „ladă misterioasă" plătită cu Robux, trebuie fie să afișăm procentele exacte de drop, fie să oferim o cale alternativă gratuită pentru userii restricționați.
- **DevEx**: rata standard e 0,0038 $/Robux câștigat (confirmă brifingul), prag minim 30.000 Robux câștigați, o cerere/lună, procesare 5–10 zile lucrătoare. Există o rată superioară **0,0054 $/Robux** pentru cumpărături de la useri US verificați 18+ — dar condiționată de cerințe de avatar 3D (R15 sau formă non-umană) pe care Driftwood, fiind 2D pur fără avatar vizibil, ar putea automat să le îndeplinească ca „nonhuman-form / fără personaj vizibil" — de verificat explicit cu suportul Roblox înainte de a mizui pe asta.
- **Engagement-Based Payouts (Premium) a fost eliminat pe 24 iulie 2025**, înlocuit de **Creator Rewards**: 5 Robux/zi per „Active Spender" (cheltuit ≥9,99$ în ultimele 60 zile) dacă experiența e printre primele 3 jucate de acel user în ziua respectivă, timp de 10+ minute. Plus „Audience Expansion": 35% revenue share din primii 100$ cheltuiți de useri noi/reactivați aduși prin Share Link, dacă jocul menține 100+ DAU timp de 60 de zile. Asta confirmă exact mecanica din brief, cu numerele exacte.
- Testarea în Studio a fluxului `ProcessReceipt` **prin Test Mode oficial cheltuie Robux reali** (nu simulare) — documentat explicit; comportamentul promptelor de cumpărare direct în Play/Test mode local (fără Test Mode extern) nu e documentat public găsit în această sesiune — marchez NEVERIFICAT, de testat manual.
- Nu există un API de „gifting" pentru Game Passes/Developer Products create de developer în `MarketplaceService` (nu apare în referință). Singurul mecanism P2P de transfer de valoare e Robux Transfers (Robux, nu iteme).
- Analytics de economie: `AnalyticsService:LogEconomyEvent(...)` funcționează **doar pe server și doar în joc publicat** — nu merge din Studio sau client. Trebuie planificat ca parte a QA post-lansare, nu testabil local.

## Fapte verificate

- MarketplaceService are metodele `PromptGamePassPurchase(player, gamePassId)`, `PromptProductPurchase(player, productId, equipIfPurchased?, currencyType?)`, `PromptPremiumPurchase(player)` (marcată Deprecated în referința curentă), `PromptSubscriptionPurchase(player, subscriptionId)`, `UserOwnsGamePassAsync(userId, gamePassId): boolean` (yields), `GetProductInfo(assetId, infoType)` (Deprecated, înlocuit de `GetProductInfoAsync`); sursă: https://create.roblox.com/docs/reference/engine/classes/MarketplaceService — accesat 2026-09-08; încredere: ridicata.
- Callback-ul `ProcessReceipt(receiptInfo): Enum.ProductPurchaseDecision` primește `PurchaseId`, `PlayerId`, `ProductId`, `PlaceIdWherePurchased`, `CurrencySpent`, `CurrencyType` (mereu `Enum.CurrencyType.Robux`); userul trebuie să fie pe server pentru a fi invocat; callback-ul poate face yield indefinit și poate rula pe mai multe servere simultan dacă userul intră pe alt server înainte de finalizare; sursă: https://raw.githubusercontent.com/Roblox/creator-docs/main/content/en-us/reference/engine/classes/MarketplaceService.yaml — accesat 2026-09-08; încredere: ridicata.
- Prețul unui Pass sau Developer Product: minim 1 Robux, maxim 1.000.000.000 Robux; sursă: https://raw.githubusercontent.com/Roblox/creator-docs/main/content/en-us/production/monetization/passes.md și .../developer-products.md — accesat 2026-09-08; încredere: ridicata.
- „Starting May 30, 2026, cross-game pass sales will be disabled" (identic pentru developer products); sursă: aceleași fișiere ca mai sus; încredere: ridicata.
- `PolicyService:GetPolicyInfoForPlayerAsync(player)` întoarce dicționar cu: `AreAdsAllowed`, `ArePaidRandomItemsRestricted`, `IsContentSharingAllowed`, `IsEligibleToPurchaseCommerceProduct`, `IsEligibleToPurchaseSubscription`, `IsPaidItemTradingAllowed`, `IsPhotoToAvatarAllowed`, `IsSubjectToChinaPolicies`, `AllowedExternalLinkReferences` (câmp legacy, întoarce mereu array gol), `IsEndlessContentLoadAllowed`, `IsEndlessContentAutoplayAllowed`; sursă: https://raw.githubusercontent.com/Roblox/creator-docs/main/content/en-us/reference/engine/classes/PolicyService.yaml — accesat 2026-09-08; încredere: ridicata.
- Pentru useri unde `ArePaidRandomItemsRestricted = true`, dezvoltatorul trebuie să aplice unul din 6 tratamente documentate (cale gratuită, ordine predeterminată, cumpărare directă garantată, ascundere, blocare cu mesaj, teleportare afară); sursă: https://raw.githubusercontent.com/Roblox/creator-docs/main/content/en-us/production/monetization/paid-random-items.md — accesat 2026-09-08; încredere: ridicata.
- Rata DevEx standard: 0,0038 $/Robux câștigat = 114$ pentru 30.000 Robux; prag minim 30.000 Robux câștigați; o cerere completă pe lună calendaristică; procesare ~10 zile lucrătoare (prima dată) / ~5 zile lucrătoare (recurent); rata veche 0,0035 $/Robux se aplică soldurilor câștigate înainte de 5 septembrie 2025, 10am PT; sursă: https://raw.githubusercontent.com/Roblox/creator-docs/main/content/en-us/production/monetization/developer-exchange.md — accesat 2026-09-08; încredere: ridicata.
- Rata superioară 0,0054 $/Robux (US 18+) se aplică doar Robux câștigați din Passes/Developer Products/Subscriptions/Private Servers de la useri US verificați 18+ (facial age estimation sau ID guvernamental), ȘI doar dacă personajul jucabil petrece 100% din timpul activ ca avatar R15 (standard/advanced) sau formă non-umană custom; jocurile fără personaj vizibil (ex. strategie top-down) se califică automat ca „nonhuman-form"; intrată în vigoare **8 iunie 2026**; sursă: https://raw.githubusercontent.com/Roblox/creator-docs/main/content/en-us/production/monetization/18-plus-devex-rate.md — accesat 2026-09-08; încredere: ridicata.
- Engagement-Based Payouts (plăți per timp petrecut de useri Premium) e depreciat oficial din **24 iulie 2025**, înlocuit de Creator Rewards; sursă: https://raw.githubusercontent.com/Roblox/creator-docs/main/content/en-us/production/monetization/engagement-based-payouts.md — accesat 2026-09-08; încredere: ridicata.
- Creator Rewards — Daily Engagement: 5 Robux/zi per Active Spender (a cheltuit ≥9,99$ USD oriunde pe Roblox în ultimele 60 zile, cont nu New/Reactivated în acea perioadă) dacă experiența e printre primele 3 jucate în ziua respectivă și userul stă 10+ minute; Audience Expansion: 35% revenue share din primii 100$ Qualifying Purchases (Robux/Premium/UGC subscriptions) ale unui user nou/reactivat adus prin Share Link, link direct sau căutare de nume, condiționat de 100+ DAU medie pe experiență timp de 60 zile după alăturare; Creator Awards plătite ca Earned Robux cu **hold de 60 de zile**; sursă: https://raw.githubusercontent.com/Roblox/creator-docs/main/content/en-us/creator-rewards.md — accesat 2026-09-08; încredere: ridicata.
- Test Mode pentru vânzări externe de Developer Products: „Items for sale in test mode cost actual Robux" — nu e simulare, cheltuiește Robux reali; produsele în test mode sunt vizibile doar developer-ului și membrilor grupului; după test reușit (status `Closed` în ProcessReceipt), Roblox permite activarea vânzărilor externe; sursă: https://raw.githubusercontent.com/Roblox/creator-docs/main/content/en-us/production/monetization/developer-products.md — accesat 2026-09-08; încredere: ridicata.
- Prețuri Subscriptions: minim 49 Robux (fără plafon superior documentat) sau tarife fixe în monedă locală 2,99$/4,99$/7,99$/9,99$/14,99$; plată creator 70% din valoare/lună dacă e în Robux, 70% prima lună + 100% lunile următoare dacă e în monedă locală; preț Robux modificabil o dată la 60 zile; indisponibil pentru local currency în Argentina, China, Columbia, India, Indonezia, Japonia, Rusia, Taiwan, Turcia, UAE, Ucraina, Vietnam; sursă: https://raw.githubusercontent.com/Roblox/creator-docs/main/content/en-us/production/monetization/subscriptions.md — accesat 2026-09-08; încredere: ridicata.
- Managed/Regional Pricing: prețul regional nu poate fi sub 30% sau peste 100% din prețul default; API `GetUsersPriceLevelsAsync` întoarce un nivel 1–1000 per user pentru a preveni arbitrajul de preț la gifting/trading; sursă: https://raw.githubusercontent.com/Roblox/creator-docs/main/content/en-us/production/monetization/regional-pricing.md — accesat 2026-09-08; încredere: ridicata.
- Robux Transfers: comision 10% pentru joc, 90% către destinatar; sumă permisă 10–500 Robux per transfer; Robux câștigați din transferuri sunt eligibili DevEx fără taxe suplimentare de platformă; API server-side `PromptRobuxTransferAsync(sender, recipientUserId, amount)`; sursă: https://raw.githubusercontent.com/Roblox/creator-docs/main/content/en-us/production/monetization/robux-transfers.md — accesat 2026-09-08; încredere: ridicata.
- Revenue share standard (non-abonament) pentru tranzacții marketplace: 70% către creator / 30% reținut de Roblox (confirmă cifra din brief); sursă: https://raw.githubusercontent.com/Roblox/creator-docs/main/content/en-us/production/monetization/roblox-plus.md — accesat 2026-09-08; încredere: medie (documentul discută explicit acest split doar în contextul reducerilor Roblox Plus, nu ca declarație generală separată, dar coroborează cu cifra explicită de 70%/30% din pagina de Subscriptions).
- `AnalyticsService:LogEconomyEvent(player, flowType, currencyName, amount, currentBalance, transactionType, itemSKU?)` — `flowType` e `Enum.AnalyticsEconomyFlowType.Source`/`.Sink`; `transactionType` valori: `IAP`, `TimedReward`, `Onboarding` (doar Source), `Shop`, `Gameplay` (Source/Sink), `ContextualPurchase` (doar Sink); evenimentele merg **doar din server, doar în joc publicat** — nu din Studio, nu din client; sursă: https://raw.githubusercontent.com/Roblox/creator-docs/main/content/en-us/production/analytics/economy-events.md — accesat 2026-09-08; încredere: ridicata.
- Subscriptions cumpărate cu Robux nu sunt eligibile pentru refund; pentru local currency, refund-ul în fereastra de 30 zile anulează hold-ul plății, refund-ul în afara ferestrei deduce suma din soldul de Robux al developerului; sursă: subscriptions.md (același ca mai sus); încredere: ridicata.
- Nu am găsit în sesiunea curentă o pagină oficială separată despre politica generală de refund/chargeback pentru Game Passes și Developer Products (spre deosebire de Subscriptions și Paid Access, care au reguli explicite); pagina Creator Rewards menționează doar că „rewards may be withheld for accounts that generate a disproportionately high percentage of chargeback" — deci chargeback-urile sunt urmărite de Roblox mai larg, dar mecanismul exact de recuperare a Robux-ilor de la developer pentru un Pass/Developer Product charged-back rămâne NEVERIFICAT în sesiunea asta.

## Detalii

### 1. Fluxul complet de cumpărare (Game Pass vs Developer Product)

**Game Pass** = cumpărare unică, deținere permanentă, verificabilă direct cu `UserOwnsGamePassAsync`. **NU** trece prin `ProcessReceipt` (ownership-ul e proprietatea Roblox, nu un „consumabil" pe care developerul trebuie să-l acorde el însuși) — developerul doar reacționează la evenimentul `PromptGamePassPurchaseFinished` pentru a acorda beneficiul, și verifică la fiecare `PlayerAdded` cu `UserOwnsGamePassAsync` (ownership-ul persistă pe partea Roblox, developerul persistă doar efectul aplicat, dacă e nevoie).

**Developer Product** = cumpărare repetabilă, consumabilă. Trece obligatoriu prin `ProcessReceipt`, indiferent dacă e cumpărat din interiorul jocului (`PromptProductPurchase`) sau din tab-ul Store al paginii jocului (cumpărare „externă"). Documentația e explicită: **„Do not use the `PromptProductPurchaseFinished` event to process purchases... The firing of `PromptProductPurchaseFinished` does not mean that a user has successfully purchased an item."**

### 2. Contractul `ProcessReceipt` — idempotență și retry

```lua
local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local DataStoreService = game:GetService("DataStoreService")

local purchaseHistoryStore = DataStoreService:GetDataStore("PurchaseHistory_v1")

local productFunctions = {}

-- fiecare Developer Product are un handler care întoarce true dacă a livrat cu succes
productFunctions[111111] = function(player)
    -- ex: acordă un pachet de materiale rare
    local ok = pcall(function()
        -- logica de livrare, server-authoritative
    end)
    return ok
end

local function processReceipt(receiptInfo)
    local player = Players:GetPlayerByUserId(receiptInfo.PlayerId)
    if not player then
        -- userul nu mai e pe acest server -> Roblox reîncearcă la următorul join
        return Enum.ProductPurchaseDecision.NotProcessedYet
    end

    local purchaseIdKey = "PurchaseId_" .. receiptInfo.PurchaseId

    -- idempotență: verifică dacă am procesat deja acest PurchaseId
    local alreadyGranted
    local ok1 = pcall(function()
        alreadyGranted = purchaseHistoryStore:GetAsync(purchaseIdKey)
    end)
    if ok1 and alreadyGranted then
        -- livrat deja într-o rulare anterioară (server crash între livrare și return)
        return Enum.ProductPurchaseDecision.PurchaseGranted
    end

    local handler = productFunctions[receiptInfo.ProductId]
    local success = handler and handler(player)

    if not success then
        return Enum.ProductPurchaseDecision.NotProcessedYet
    end

    -- marchează PurchaseId ca procesat ÎNAINTE de a returna PurchaseGranted
    local ok2 = pcall(function()
        purchaseHistoryStore:UpdateAsync(purchaseIdKey, function()
            return true
        end)
    end)
    if not ok2 then
        -- nu am putut confirma idempotența -> mai bine reîncercăm decât să riscăm o
        -- dublă livrare nedetectabilă; dacă handler-ul e idempotent per user, e sigur
        return Enum.ProductPurchaseDecision.NotProcessedYet
    end

    return Enum.ProductPurchaseDecision.PurchaseGranted
end

MarketplaceService.ProcessReceipt = processReceipt
```

Puncte critice confirmate din documentație:
- `receiptInfo` conține `PurchaseId` (identificator unic al tranzacției — cheia de idempotență), `PlayerId`, `ProductId`, `PlaceIdWherePurchased`, `CurrencySpent`, `CurrencyType` (mereu `Enum.CurrencyType.Robux`).
- Dacă handler-ul întoarce `NotProcessedYet`, Roblox reîncearcă automat **la următoarea intrare a userului pe orice server al jocului** — nu trebuie construit un sistem propriu de retry.
- Callback-ul poate rula pe **mai multe servere simultan** dacă userul se mută pe alt server înainte ca `ProcessReceipt` să termine — de aici nevoia strictă de idempotență via DataStore, nu doar variabile în memorie.
- Doar un singur script poate seta `MarketplaceService.ProcessReceipt` per joc (ultima atribuire câștigă) — centralizează totul într-un singur modul de „Economy Server".
- Roblox însuși **nu ține istoricul cumpărăturilor per user** — dacă vrei istoric pentru suport clienți/audit, trebuie salvat manual în DataStore (exact ce face schema de mai sus).

### 3. Game Pass — flux minimal

```lua
-- SERVER: acordă beneficiul la achiziție + la fiecare join (re-verificare ownership)
local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")

local PASS_EXTRA_NET = 123456789 -- înlocuiește cu ID real

local function grantExtraNet(player)
    -- aplică efectul (ex: crește limita de plase a jucătorului)
end

local function onPlayerAdded(player)
    local ok, owns = pcall(function()
        return MarketplaceService:UserOwnsGamePassAsync(player.UserId, PASS_EXTRA_NET)
    end)
    if ok and owns then
        grantExtraNet(player)
    end
end

local function onPromptGamePassPurchaseFinished(player, passId, wasPurchased)
    if wasPurchased and passId == PASS_EXTRA_NET then
        grantExtraNet(player)
    end
end

Players.PlayerAdded:Connect(onPlayerAdded)
MarketplaceService.PromptGamePassPurchaseFinished:Connect(onPromptGamePassPurchaseFinished)
```

```lua
-- CLIENT: buton de cumpărare
local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local player = Players.LocalPlayer

local PASS_EXTRA_NET = 123456789

buyButton.Activated:Connect(function()
    local ok, owns = pcall(function()
        return MarketplaceService:UserOwnsGamePassAsync(player.UserId, PASS_EXTRA_NET)
    end)
    if ok and owns then
        return -- deja deține, nu mai prompta
    end
    MarketplaceService:PromptGamePassPurchase(player, PASS_EXTRA_NET)
end)
```

Notă de performanță: `UserOwnsGamePassAsync` face yield și suportă batching transparent dacă e apelat concurent pentru mai mulți useri/passuri — nu blochează dramatic, dar tot recomand caching local (tabel `player -> Set<passId>` populat la join) ca să nu reinterogheze API-ul la fiecare verificare de UI.

### 4. PolicyService — tabel complet de câmpuri

| Câmp | Tip | Relevanță pentru Driftwood |
|---|---|---|
| `AreAdsAllowed` | boolean | Dacă implementăm Immersive Ads (nemenționat în brief, dar util de știut) |
| `ArePaidRandomItemsRestricted` | boolean | **Critic** dacă vindem cutii/lăzi cu conținut aleator plătit cu Robux |
| `IsContentSharingAllowed` | boolean | Upload/share de conținut generat de user |
| `IsEligibleToPurchaseCommerceProduct` | boolean | Doar relevant dacă am vinde merch fizic prin Shopify (nu e cazul Driftwood) |
| `IsEligibleToPurchaseSubscription` | boolean | Verifică înainte de a afișa oferta de abonament |
| `IsPaidItemTradingAllowed` | boolean | Dacă permitem trading de iteme cumpărate |
| `IsPhotoToAvatarAllowed` | boolean | Nerelevant (fără avatar 3D) |
| `IsSubjectToChinaPolicies` | boolean | China are reguli suplimentare de conținut/monetizare — verifică înainte de a afișa orice mecanism de tip loot/random |
| `AllowedExternalLinkReferences` | array | **Legacy — întoarce mereu array gol**, nu te baza pe el pentru linkuri externe |
| `IsEndlessContentLoadAllowed` | boolean | Relevant dacă râul generează conținut „infinit" tip scroll — verifică pentru useri minori |
| `IsEndlessContentAutoplayAllowed` | boolean | Similar, pentru orice auto-play de conținut |

```lua
local PolicyService = game:GetService("PolicyService")

local function getPolicy(player)
    local ok, policyInfo = pcall(function()
        return PolicyService:GetPolicyInfoForPlayerAsync(player)
    end)
    if not ok then
        warn("PolicyService failed for", player.Name, policyInfo)
        return nil
    end
    return policyInfo
end

Players.PlayerAdded:Connect(function(player)
    local policy = getPolicy(player)
    if policy then
        player:SetAttribute("PaidRandomItemsRestricted", policy.ArePaidRandomItemsRestricted)
        player:SetAttribute("SubjectToChinaPolicies", policy.IsSubjectToChinaPolicies)
    end
end)
```

Politica de iteme aleatoare plătite prevede 6 tratamente valide dacă `ArePaidRandomItemsRestricted = true`: cale gratuită de obținere, ordine predeterminată dezvăluită dinainte, cumpărare directă garantată la preț echivalent valorii așteptate, ascunderea completă a mecanicii, blocare cu mesaj de eroare, sau teleportarea userului în afara zonei cu mecanica respectivă.

### 5. Testare în Studio și extern

Confirmat oficial: **Test Mode pentru vânzări externe cheltuiește Robux reali** — nu e un mediu sandbox. Fluxul documentat: activezi Test Mode din Creator Hub → produsul devine vizibil doar ție/grupului tău → cumperi din tab-ul Store al paginii jocului → intri în joc → `ProcessReceipt` trebuie să seteze statusul pe „Closed" → abia apoi poți activa vânzarea externă reală.

Pentru promptele **din interiorul jocului** (`PromptProductPurchase`, `PromptGamePassPurchase`) apelate direct dintr-o sesiune de Play/Test în Studio: documentația oficială consultată în această sesiune nu descrie explicit comportamentul (dacă se cheltuiesc Robux reali, dacă promptul e simulat, sau dacă necesită jocul publicat live) — **NEVERIFICAT**, marchez ca întrebare deschisă mai jos, de testat manual cu o sumă mică înainte de a construi fluxul de QA al echipei.

### 6. Analytics de economie — `LogEconomyEvent`

```lua
local AnalyticsService = game:GetService("AnalyticsService")

-- exemplu: jucătorul cumpără un Developer Product de 500 de piese de reparat
AnalyticsService:LogEconomyEvent(
    player,
    Enum.AnalyticsEconomyFlowType.Source,
    "RepairParts",              -- numele resursei interne
    500,                         -- cantitate câștigată
    player.RepairParts.Value,   -- soldul curent DUPĂ tranzacție
    Enum.AnalyticsEconomyTransactionType.IAP.Name,
    "500RepairPartsBundle"      -- SKU unic, opțional dar recomandat
)

-- exemplu: jucătorul cheltuie piese pentru skip la reparație
AnalyticsService:LogEconomyEvent(
    player,
    Enum.AnalyticsEconomyFlowType.Sink,
    "RepairParts",
    80,
    player.RepairParts.Value,
    Enum.AnalyticsEconomyTransactionType.Gameplay.Name
)
```

Restricție critică: **funcționează doar din server și doar în jocul publicat** — nu apare nimic în dashboard dacă testezi din Studio sau din client. Trebuie tratat ca instrumentare de producție, verificată abia după primul deploy live.

### 7. Prețuri și structuri sugerate pentru Driftwood

Constrângeri oficiale confirmate:
- Passes / Developer Products: 1–1.000.000.000 Robux (fără plafon inferior practic diferit de 1).
- Subscriptions: minim 49 Robux, sau tarife fixe 2,99$/4,99$/7,99$/9,99$/14,99$ (doar dacă e nevoie de monedă locală — Driftwood, fiind un joc mic la lansare, poate rămâne doar pe Robux ca să evite verificarea de identitate cerută pentru local currency).
- Regional Pricing: dacă e activat, prețul afișat unui user poate scădea până la 30% din prețul default, niciodată sub asta și niciodată peste 100%.

**Presetările de „preț comun" de mai jos NU sunt confirmate oficial — sunt convenție de piață observată empiric în comunitate, marchez explicit NEVERIFICAT / încredere scăzută, includ doar ca punct de plecare pentru A/B testing prin Managed Pricing:**

| Produs | Tip | Preț sugerat (Robux) | Confidence |
|---|---|---|---|
| Plasă suplimentară | Game Pass | 149–249 | scăzută (convenție) |
| Slot extra atelier | Game Pass | 149–249 | scăzută (convenție) |
| Viteză reparație crescută | Game Pass | 199–349 | scăzută (convenție) |
| Materiale rare (pachet mic) | Developer Product | 25–49 | scăzută (convenție) |
| Materiale rare (pachet mare) | Developer Product | 99–149 | scăzută (convenție) |
| Skip timp reparație (unitate) | Developer Product | 19–39 | scăzută (convenție) |
| Extindere temporară spațiu | Developer Product | 49–99 | scăzută (convenție) |
| Skin plasă (cosmetic) | Game Pass sau Developer Product | 39–99 | scăzută (convenție) |
| Decorațiune mal (cosmetic) | Developer Product | 25–75 | scăzută (convenție) |

Recomand tratarea acestor cifre ca ipoteze de test, nu ca preț final — folosește **Managed Pricing / price optimization** oficial (permite Roblox să testeze automat variante de preț) în loc de a fixa manual pe baza intuiției.

### 8. Cosmetice fără avatar 3D — decizie de arhitectură

Fiindcă Driftwood e „2D pur în ScreenGui" fără parts 3D, cosmeticele (skin-uri de plasă, decorațiuni de mal, efecte vizuale) **nu pot fi vândute prin Avatar Marketplace/Catalog** (acela e pentru wearables 3D pe avatarul standard Roblox). Trebuie implementate ca:
- **Game Pass** dacă e o achiziție permanentă (ex: „set de skin-uri clasice pentru plasă"), verificat cu `UserOwnsGamePassAsync` și aplicat prin schimbarea unui `ImageLabel`/`Frame` la render.
- **Developer Product** dacă e o achiziție repetabilă/consumabilă (ex: „cutie cosmetică surpriză" — atenție, dacă are conținut aleator, se aplică politica de la secțiunea 4/PolicyService).

### 9. Chirurgical: efectul faptului că nu există avatar 3D asupra ratei DevEx 18+

Cerința pentru rata 0,0054 $/Robux este ca personajul jucabil să petreacă 100% din timpul activ ca avatar R15 SAU „formă non-umană custom", iar FAQ-ul oficial confirmă explicit: **„Games without a visible player character... meet the custom nonhuman-form criteria."** Driftwood nu randează niciun avatar 3D (totul e Frame/ImageLabel) — deci pare să se califice automat la acest criteriu tehnic. Rămâne un NEVERIFICAT dacă evaluatorii Roblox interpretează „joc 2D fără avatar vizibil deloc" identic cu exemplul lor de „strategie top-down" — recomand o confirmare directă cu suportul Roblox/DevEx înainte de a construi proiecții financiare pe baza ratei superioare.

## Recomandari concrete pentru Driftwood

1. **Construiește un singur modul server „EconomyServer" care deține `MarketplaceService.ProcessReceipt`.** Doar un script poate seta acest callback per joc — centralizarea evită bug-uri de suprascriere silențioasă când echipa crește.
2. **Folosește `PurchaseId` din `receiptInfo` ca cheie DataStore pentru idempotență, nu presupune că `ProcessReceipt` rulează o singură dată.** Roblox retrimite explicit purchase-uri nefinalizate (`NotProcessedYet`) și poate rula callback-ul pe mai multe servere simultan — schema din secțiunea 2 e obligatorie, nu opțională.
3. **Nu folosi `PromptProductPurchaseFinished`/`PromptGamePassPurchaseFinished` ca sursă de adevăr pentru livrare de Developer Products** — doar pentru Game Passes (unde ownership-ul e garantat de Roblox), folosește evenimentul doar ca „trigger de UI/UX", nu ca autorizare de livrare economică.
4. **Verifică `PolicyService:GetPolicyInfoForPlayerAsync` la fiecare `PlayerAdded` și cache-uiește rezultatul pe atribute de player**, nu reinterogheze la fiecare acțiune de cumpărare — mai ales `ArePaidRandomItemsRestricted`, dacă vreodată introduceți orice mecanism de recompensă aleatoare plătită (chiar și indirect, gen „chei" cumpărate cu Robux).
5. **Nu vindeți nimic ca „ladă misterioasă plătită direct cu Robux" fără procente de drop afișate explicit** — regula Roblox e strictă (procentele trebuie să sumeze exact 100% și să fie accesibile înainte de cumpărare), iar brief-ul are deja regula „anti pay-to-win" care se potrivește natural cu asta: fă loot-ul din râu 100% gratuit/gameplay, nu vindeți acces plătit la conținut aleator.
6. **Migrați orice viitor mecanism cross-game (hub + zone separate, eventual) pe `PromptRobuxTransferAsync` înainte de 30 mai 2026**, dată de la care vânzarea de Passes/Developer Products cross-game se dezactivează definitiv. Dacă Driftwood rămâne un singur joc (place unic), nu vă afectează — dar rețineți limitarea dacă planificați expansiune multi-place.
7. **Nu construiți roadmap-ul de monetizare în jurul `PromptPremiumPurchase`/Engagement-Based Payouts** — programul e depreciat din 24 iulie 2025. Proiectați bucla zilnică (din brief) în jurul mecanicii exacte Creator Rewards: sesiuni de 10+ minute, în primele 3 jocuri ale zilei ale unui „Active Spender" (a cheltuit ≥9,99$ în 60 zile) — asta confirmă și cuantifică exact recomandarea deja prezentă în brief.
8. **Instrumentați `AnalyticsService:LogEconomyEvent` din prima versiune a economiei server-side**, dar acceptați că nu puteți verifica datele decât după primul deploy public (nu merge în Studio) — planificați un smoke-test dedicat imediat după primul deploy live pentru a confirma că evenimentele ajung în dashboard.
9. **Cereți confirmare directă de la Roblox (support/DevEx) dacă Driftwood se califică pentru rata DevEx 0,0054 $/Robux ca joc „fără personaj vizibil"** — dacă da, e o diferență de +42% la fiecare cash-out DevEx pentru achizițiile de la useri US 18+ verificați, ceea ce schimbă calculul de unit economics al proiectului.
10. **Tratați skin-urile de plasă și decorațiunile de mal ca Game Passes/Developer Products, nu ca avatar items** — Driftwood nu are avatar 3D vizibil, deci Catalogul/Marketplace de avatar Roblox nu e canalul corect de vânzare pentru cosmeticele proprii jocului.
11. **Nu promiteți ferm sume/procente din DevEx la investitori/parteneri fără marja rezervei de 30 de zile** — payout-urile din Passes/Developer Products au un hold de cca. 5 zile înainte de a intra în soldul de Robux, iar Creator Awards (Creator Rewards) au un hold de 60 de zile — modelați cash-flow-ul cu aceste întârzieri.

## Riscuri si necunoscute

- **Comportamentul exact al promptelor de cumpărare în Studio Play/Test mode local** (fără Test Mode extern activat) nu a fost găsit documentat oficial în această sesiune. Dacă echipa testează cu Robux reali fără să știe, poate cheltui accidental sume mici repetat în timpul dezvoltării.
- **Nu există confirmare oficială clară asupra politicii de refund/chargeback pentru Game Passes și Developer Products** (spre deosebire de Subscriptions și Paid Access, unde regulile sunt explicite). Nu se știe exact dacă/cum Roblox recuperează Robux de la developer când un Pass e charged-back, sau dacă doar contul userului e afectat.
- **Calificarea Driftwood pentru rata DevEx 18+ (0,0054 $/Robux) e o interpretare, nu o confirmare oficială** — depinde de cum Roblox clasifică un joc „2D pur ScreenGui fără avatar" față de exemplul lor explicit „strategie top-down fără personaj vizibil".
- **Nu există un API de gifting nativ pentru Passes/Developer Products create de developer** (bazat pe absența din referința MarketplaceService) — dacă brief-ul viitor cere gifting explicit de iteme (nu doar Robux), va trebui construit manual (ex: userul A cumpără un Developer Product care acordă un item userului B, cu validare server-side), nu există un `PromptGiftPurchase` gata făcut.
- **Presetările de preț din tabelul de la secțiunea 7 sunt neverificate oficial** — orice cifră exactă de preț trebuie tratată ca ipoteză de test A/B, nu ca fapt.
- **Managed Pricing/Regional Pricing e activat by-default** pentru Passes noi și pentru Subscriptions în Robux — dacă echipa nu vrea variație regională de preț la lansare (pentru simplitate/testare), trebuie dezactivat explicit per item din Creator Hub.

## Intrebari deschise

1. Confirmă cu Roblox/DevEx dacă Driftwood (2D ScreenGui, fără avatar 3D vizibil) se califică pentru rata US 18+ de 0,0054 $/Robux ca „nonhuman-form / fără personaj vizibil".
2. Testați manual în Studio (Play Solo și/sau Team Test) apelarea `PromptProductPurchase`/`PromptGamePassPurchase` cu un Developer Product de preț minim (1 Robux) pentru a documenta intern comportamentul real (se cheltuie Robux? apare un prompt real? e nevoie de joc publicat live?).
3. Decideți dacă Driftwood va oferi vreodată vânzare externă (Store tab) — dacă da, planificați bugetul de Robux pentru Test Mode (cheltuiește Robux reali) în ciclul de QA.
4. Decideți politica internă de refund/suport clienți pentru Developer Products, având în vedere lipsa unei politici oficiale explicite Roblox pentru acest tip de produs (spre deosebire de Subscriptions).
5. Dacă/când Driftwood ajunge la scară multi-place (hub + zone), planificați migrarea la `PromptRobuxTransferAsync` înainte de 30 mai 2026.
6. Verificați dacă e nevoie de Subscriptions în roadmap (brief-ul actual nu le menționează) — dacă da, decideți Robux-only (fără verificare ID) vs. monedă locală (necesită verificare ID/telefon a developer-ului).
7. Stabiliți intern cine (rol/persoană) monitorizează pragul „Active Spender" și mecanica Creator Rewards în dashboard-ul Creator Hub, pentru a corela decizii de design (sesiuni 10+ minute, primele 3 jocuri ale zilei) cu date reale după lansare.

## Surse

- MarketplaceService — referință clasă: https://create.roblox.com/docs/reference/engine/classes/MarketplaceService (accesat 2026-09-08)
- MarketplaceService — descrieri complete (YAML sursă): https://raw.githubusercontent.com/Roblox/creator-docs/main/content/en-us/reference/engine/classes/MarketplaceService.yaml (accesat 2026-09-08)
- PolicyService — referință clasă: https://create.roblox.com/docs/reference/engine/classes/PolicyService (accesat 2026-09-08)
- PolicyService — descrieri complete (YAML sursă): https://raw.githubusercontent.com/Roblox/creator-docs/main/content/en-us/reference/engine/classes/PolicyService.yaml (accesat 2026-09-08)
- Developer Products: https://raw.githubusercontent.com/Roblox/creator-docs/main/content/en-us/production/monetization/developer-products.md (accesat 2026-09-08)
- Passes: https://raw.githubusercontent.com/Roblox/creator-docs/main/content/en-us/production/monetization/passes.md (accesat 2026-09-08)
- Subscriptions: https://raw.githubusercontent.com/Roblox/creator-docs/main/content/en-us/production/monetization/subscriptions.md (accesat 2026-09-08)
- Paid random items policy: https://raw.githubusercontent.com/Roblox/creator-docs/main/content/en-us/production/monetization/paid-random-items.md (accesat 2026-09-08)
- Developer Exchange (DevEx): https://raw.githubusercontent.com/Roblox/creator-docs/main/content/en-us/production/monetization/developer-exchange.md (accesat 2026-09-08)
- U.S. 18+ DevEx rate: https://raw.githubusercontent.com/Roblox/creator-docs/main/content/en-us/production/monetization/18-plus-devex-rate.md (accesat 2026-09-08)
- Creator Rewards: https://raw.githubusercontent.com/Roblox/creator-docs/main/content/en-us/creator-rewards.md (accesat 2026-09-08)
- Engagement-Based Payouts (deprecated): https://raw.githubusercontent.com/Roblox/creator-docs/main/content/en-us/production/monetization/engagement-based-payouts.md (accesat 2026-09-08)
- Robux Transfers: https://raw.githubusercontent.com/Roblox/creator-docs/main/content/en-us/production/monetization/robux-transfers.md (accesat 2026-09-08)
- Managed Pricing: https://raw.githubusercontent.com/Roblox/creator-docs/main/content/en-us/production/monetization/managed-pricing.md (accesat 2026-09-08)
- Regional Pricing: https://raw.githubusercontent.com/Roblox/creator-docs/main/content/en-us/production/monetization/regional-pricing.md (accesat 2026-09-08)
- Paid Access in Robux: https://raw.githubusercontent.com/Roblox/creator-docs/main/content/en-us/production/monetization/paid-access-robux.md (accesat 2026-09-08)
- Commerce Products: https://raw.githubusercontent.com/Roblox/creator-docs/main/content/en-us/production/monetization/commerce-products.md (accesat 2026-09-08)
- Roblox Plus (revenue share context): https://raw.githubusercontent.com/Roblox/creator-docs/main/content/en-us/production/monetization/roblox-plus.md (accesat 2026-09-08)
- Economy Events / LogEconomyEvent: https://raw.githubusercontent.com/Roblox/creator-docs/main/content/en-us/production/analytics/economy-events.md (accesat 2026-09-08)
- Studio Testing Modes (fără secțiune de purchase testing): https://raw.githubusercontent.com/Roblox/creator-docs/main/content/en-us/studio/testing-modes.md (accesat 2026-09-08)
- Monetization index: https://raw.githubusercontent.com/Roblox/creator-docs/main/content/en-us/production/monetization/index.md (accesat 2026-09-08)
- Repository oficial de documentație Roblox (sursă primară a tuturor fișierelor .md/.yaml de mai sus): https://github.com/Roblox/creator-docs (branch main, accesat 2026-09-08)

**Notă de metodologie**: bugetul de căutări web (WebSearch) al sesiunii curente era epuizat înainte de a începe cercetarea (folosit de alte sesiuni în paralel), deci nu s-au putut face căutări generale de tip „common Robux price points" sau surse secundare (Reddit/DevForum/YouTube) pentru validarea empirică a presetărilor de preț din secțiunea 7. Tot conținutul de mai sus vine din citirea directă, verbatim, a fișierelor sursă .md/.yaml din repository-ul oficial Roblox/creator-docs (care alimentează exact paginile de pe create.roblox.com/docs) — o sursă primară echivalentă sau superioară căutării web, dar fără acoperirea surselor secundare/comunitate cerută explicit în instrucțiuni. Orice cifră marcată „convenție"/NEVERIFICAT de mai sus ar beneficia de o rundă separată de verificare prin WebSearch când bugetul se resetează.

## Verificare independenta (2026-09-08)

Verificare efectuata independent, cu acces web live (WebSearch/WebFetch), contra surselor primare (create.roblox.com/docs live, DevForum, raw creator-docs). Toate cele 14 afirmatii-cheie de mai jos au fost confirmate ca fiind corecte la data verificarii; nu s-a gasit nicio cifra, data sau regula gresita sau depasita, deci nu a fost necesara nicio modificare in corpul notei.

| Afirmatie | Verdict | Valoare corecta | Sursa (URL, data) |
|---|---|---|---|
| Pret Pass/Developer Product: minim 1, maxim 1.000.000.000 Robux | CONFIRMAT | 1 – 1.000.000.000 Robux | https://create.roblox.com/docs/production/monetization/passes ; https://create.roblox.com/docs/production/monetization/developer-products (accesat 2026-09-08) |
| Vanzari cross-game de Passes/Developer Products dezactivate incepand cu 30 mai 2026 | CONFIRMAT | „Starting May 30, 2026, cross-game pass/developer product sales will be disabled" | https://create.roblox.com/docs/production/monetization/passes ; .../developer-products (accesat 2026-09-08) |
| DevEx rata standard 0,0038 $/Robux ($114 la 30.000 Robux), prag minim 30.000 Robux, o cerere/luna calendaristica, procesare ~10 zile (prima data) / ~5 zile (recurent) | CONFIRMAT | 0,0038 $/Robux; prag 30.000; 1x/luna; 10/5 zile lucratoare | https://create.roblox.com/docs/production/monetization/developer-exchange (accesat 2026-09-08) |
| Rata DevEx veche 0,0035 $/Robux se aplica soldurilor de Robux castigati inainte de 5 septembrie 2025, ora 10:00 PT | CONFIRMAT | Exact — cutoff 5 sept. 2025, 10am PT, rata veche 0,0035 $ ($105 la 30.000 Robux) | https://create.roblox.com/docs/production/monetization/developer-exchange (accesat 2026-09-08) |
| Rata DevEx US 18+ 0,0054 $/Robux, in vigoare din 8 iunie 2026; jocurile fara personaj vizibil se califica automat drept „nonhuman-form" | CONFIRMAT | 0,0054 $/Robux; efectiv 8 iunie 2026; citat oficial „Games without a visible player character... meet the custom nonhuman-form criteria" | https://create.roblox.com/docs/production/monetization/18-plus-devex-rate (accesat 2026-09-08) |
| Engagement-Based Payouts (Premium) eliminat pe 24 iulie 2025, inlocuit de Creator Rewards | CONFIRMAT | Data exacta 24 iulie 2025 | https://create.roblox.com/docs/production/monetization/engagement-based-payouts (accesat 2026-09-08); corroborat de Tubefilter/MediaPost, iunie-iulie 2025 |
| Creator Rewards — Daily Engagement: 5 Robux/zi per Active Spender (≥9,99$ cheltuiti in ultimele 60 zile), daca experienta e in primele 3 jucate acea zi, 10+ minute; Audience Expansion: 35% revenue share din primii 100$ Qualifying Purchases, conditionat de 100+ DAU medie timp de 60 zile; Creator Awards platite ca Earned Robux cu hold de 60 zile | CONFIRMAT | Toate cifrele exacte (5 Robux, 9,99$, 60 zile, top 3, 10 min, 35%, 100$, 100 DAU, hold 60 zile) | https://create.roblox.com/docs/creator-rewards (accesat 2026-09-08) |
| PolicyService:GetPolicyInfoForPlayerAsync intoarce exact 11 campuri: AreAdsAllowed, ArePaidRandomItemsRestricted, IsContentSharingAllowed, IsEligibleToPurchaseCommerceProduct, IsEligibleToPurchaseSubscription, IsPaidItemTradingAllowed, IsPhotoToAvatarAllowed, IsSubjectToChinaPolicies, AllowedExternalLinkReferences (legacy, mereu gol), IsEndlessContentLoadAllowed, IsEndlessContentAutoplayAllowed | CONFIRMAT | Lista exacta, fara campuri lipsa sau in plus | https://create.roblox.com/docs/reference/engine/classes/PolicyService (pagina live + YAML sursa, accesat 2026-09-08) |
| Robux Transfers: jocul primeste 10%, destinatarul 90%; suma permisa 10–500 Robux/transfer; API `PromptRobuxTransferAsync` | CONFIRMAT | 10%/90%; interval 10–500 Robux (precizare: Roblox insusi „nu retine comision" — cei 10% raman la joc, nu la platforma, dar impartirea numerica e identica cu ce scrie nota) | https://create.roblox.com/docs/production/monetization/robux-transfers (accesat 2026-09-08) |
| Subscriptions: minim 49 Robux; tarife fixe monedа locala 2,99$/4,99$/7,99$/9,99$/14,99$; plata creator 70%/luna in Robux, 70% prima luna + 100% lunile urmatoare in moneda locala; pret Robux modificabil 1x/60 zile; indisponibil in 11-12 tari listate | CONFIRMAT | Toate cifrele exacte, inclusiv lista de tari excluse | https://create.roblox.com/docs/production/monetization/subscriptions (accesat 2026-09-08) |
| Regional/Managed Pricing: pretul regional nu poate fi sub 30% sau peste 100% din pretul default; `GetUsersPriceLevelsAsync` intoarce nivel 1–1000 | CONFIRMAT | Exact — reducere maxima 70% (deci minim 30% din pret), niciodata peste 100%; niveluri 1–1000 | https://create.roblox.com/docs/production/monetization/regional-pricing (accesat 2026-09-08) |
| Revenue share standard marketplace (Passes/Developer Products): 70% creator / 30% Roblox | CONFIRMAT — sursa mai buna decat cea citata in nota | 70%/30%, valabil pentru toti dezvoltatorii indiferent de Premium (unificat din 2 aprilie 2020) | https://devforum.roblox.com/t/unified-marketplace-fee-for-dev-products-and-game-passes/507109 (anunt oficial Roblox Staff, accesat 2026-09-08) — nota originala cita doar roblox-plus.md cu incredere „medie"; exista o sursa DevForum oficiala mai directa |
| Test Mode extern (Store tab) cheltuieste Robux reali; comportamentul promptelor `PromptProductPurchase`/`PromptGamePassPurchase` in Play Solo/Team Test local ramane nedocumentat oficial | CONFIRMAT (partea Test Mode extern) / NEVERIFICABIL (partea Play Solo/Team Test) | Test Mode extern = Robux reali, confirmat oficial. Pentru Play Solo/Team Test: cea mai buna dovada secundara gasita (fire DevForum „Mock Purchases", „Robux after purchase shows in purchase prompt as 2,147,483,647 while play testing") sugereaza ca promptul apare dar NU se retrag Robux reali in acest mod local — insa nu exista o pagina oficiala create.roblox.com/en.help.roblox.com care sa afirme explicit acest lucru, deci ramane recomandarea notei (testati manual) valabila | https://create.roblox.com/docs/production/monetization/developer-products (Test Mode, accesat 2026-09-08); https://create.roblox.com/docs/studio/testing-modes (nu mentioneaza purchase prompts, accesat 2026-09-08); https://devforum.roblox.com/t/mock-purchases/13632 ; https://devforum.roblox.com/t/robux-after-purchase-shows-in-purchase-prompt-as-2147483647-while-play-testing/4111553 (fire-uri comunitate, nu anunt oficial) |
| `AnalyticsService:LogEconomyEvent` functioneaza doar din server si doar in joc publicat (nu Studio, nu client) | CONFIRMAT | Citat oficial: „Events can only be sent from the server and in published games. Events can't be sent from the client or Studio." | https://create.roblox.com/docs/production/analytics/economy-events (accesat 2026-09-08) |

Nicio afirmatie din tabel nu a necesitat corectare (CORECTAT) sau marcare drept depasita (DEPASIT) — toate cifrele, datele si regulile verificate independent coincid cu sursele primare live la 2026-09-08. Singurul punct ramas neverificabil oficial este comportamentul exact al promptelor de cumparare in Play Solo/Team Test local (Studio), exact asa cum semnalase deja nota originala; dovezile secundare gasite (fire-uri DevForum) intaresc, dar nu inlocuiesc, recomandarea de testare manuala din nota.
