--!strict
-- [D61, partea 2] CE FAC PASS-URILE SI PRODUSELE, in cifre. Modul pur.
--
-- Pass-urile tale stau in profil (`Purchases.passes`, copia de la PassService): daca verificarea Roblox pica la
-- intrare, ramai cu ce ai platit [P2]. De aici citesc toti -- lantul, offline-ul, mersul, titlurile -- deci un pass are
-- un singur loc in care "exista".
--
-- Factorii stau in AFARA formulelor lantului: TycoonMath si ChainMath sunt portari bit-exacte ale simulatorului,
-- pazite de teste de aur. `2x Flow` se pune pe `priceMult` dupa ce starea e facuta (PadService, StationService), exact
-- combinatorul folosit de platformele "Market" / "Lighthouse" din erele viitoare.
local PassMath = {}

PassMath.FLOW_FACTOR = 2 -- 2x Flow: venitul in monede, peste tot unde apare
PassMath.SPEED_FACTOR = 1.5 -- Swift Boots (D60 zicea x2: la x2 traversezi balciul in 1,6 s si nu mai vezi nimic)
-- [D66, D71] CAT LUCREAZA SATUL FARA TINE (OfflineCalc): la viteza intreaga o noapte, 16 h cu Long Nights; apoi un sfert
-- din viteza pana la 24 h; dupa aceea satul se odihneste pana revii. Simulatorul citeste cifrele de aici
-- (check_config_constants): raman numere scrise ca atare.
PassMath.OFFLINE_HOURS = 8 -- viteza intreaga, fara pass [D66; pana atunci 24, si apoi nimic]
PassMath.OFFLINE_HOURS_LONG = 16 -- ...cu Long Nights [D66; pana atunci 48]
PassMath.OFFLINE_STOP_HOURS = 24 -- [D71] dupa atatea ore satul se odihneste (si cu Long Nights)
PassMath.OFFLINE_SLOW = 0.25 -- [D71] intre viteza intreaga si oprire, satul merge la un sfert
PassMath.HOUR_SECONDS = 3600
PassMath.HOUR_MIN_COINS = 60 -- One Hour of Flow, pe un sat fara venit inca: macar cat primii oameni
PassMath.PURCHASE_IDS_KEPT = 100 -- ultimele chitante tinute minte (tiparul ProfileStore pentru produse)

-- Ai pass-ul asta? `data` = profilul (sau orice tabel cu `Purchases.passes`).
function PassMath.has(data: any, key: string): boolean
    if typeof(data) ~= "table" then
        return false
    end
    local purchases = data.Purchases
    local passes = if typeof(purchases) == "table" then purchases.passes else nil
    return typeof(passes) == "table" and passes[key] == true
end

function PassMath.flowFactor(data: any): number
    return if PassMath.has(data, "flow2x") then PassMath.FLOW_FACTOR else 1
end

function PassMath.speedFactor(data: any): number
    return if PassMath.has(data, "swift") then PassMath.SPEED_FACTOR else 1
end

-- [D71] Curba lui OfflineCalc pentru jucatorul asta, in secunde. Long Nights tine viteza intreaga 16 h (cat promitea),
-- iar oprirea de la 24 h e aceeasi pentru toti: revenirea zilnica e rasplatita, nu cumparata.
function PassMath.offlineCurve(data: any): { full: number, stop: number, slow: number }
    local hours = if PassMath.has(data, "nights")
        then PassMath.OFFLINE_HOURS_LONG
        else PassMath.OFFLINE_HOURS
    return {
        full = hours * 3600,
        stop = PassMath.OFFLINE_STOP_HOURS * 3600,
        slow = PassMath.OFFLINE_SLOW,
    }
end

-- One Hour of Flow: monede cat o ora din venitul de acum (cel putin HOUR_MIN_COINS). Intreg, ca suma de pe buton sa fie
-- exact suma primita [D40].
function PassMath.hourOfFlow(incomePerSec: number): number
    local income = if incomePerSec == incomePerSec and incomePerSec > 0 then incomePerSec else 0
    return math.max(PassMath.HOUR_MIN_COINS, math.floor(income * PassMath.HOUR_SECONDS))
end

-- Welcome Back x2: inca o data suma platita la revenire. Daca nu e nimic de dublat (chitanta a venit dupa ce suma a fost
-- deja dublata), nu ramai cu mana goala: primesti o ora de venit, taiata la pretul mai mic al produsului.
function PassMath.welcomeDouble(lastWelcome: number, incomePerSec: number): number
    if lastWelcome == lastWelcome and lastWelcome >= 1 then
        return math.floor(lastWelcome)
    end
    return math.floor(PassMath.hourOfFlow(incomePerSec) * 0.8)
end

-- Chitantele deja onorate (tiparul ProfileStore, "Developer Products"): lista scurta, cele mai vechi ies primele.
function PassMath.hasReceipt(ids: unknown, purchaseId: string): boolean
    return typeof(ids) == "table" and table.find(ids :: { string }, purchaseId) ~= nil
end

function PassMath.rememberReceipt(ids: { string }, purchaseId: string)
    if table.find(ids, purchaseId) ~= nil then
        return
    end
    while #ids >= PassMath.PURCHASE_IDS_KEPT do
        table.remove(ids, 1)
    end
    table.insert(ids, purchaseId)
end

return PassMath
