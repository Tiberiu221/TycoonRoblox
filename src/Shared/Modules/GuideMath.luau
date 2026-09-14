--!strict
-- Alegerea SINGURULUI obiectiv aratat jucatorului [F1 spec 5.2]. Modul pur: primeste starea deja
-- copiata explicit de client si intoarce cel mult un Goal; GuideController doar il deseneaza.
-- Ordinea de prioritate e cea din spec, litera cu litera (a..f) -- testata in GuideMath.test.luau,
-- nu se schimba fara sa se schimbe si testul.
--
-- [D51] DOUA NIVELURI: quest-ul spune CE (linia NEXT, cu progresul lui), iar Goal-ul intors de aici e
-- PASUL de acum -- cum si unde. Owner-ul: "dupa ce pui driftwood-ul apare instant linia ghidaj catre
-- urmatorul obiectiv... trebuie sa il puna sa stea pana cand tot driftwood-ul este gata plank". Deci
-- pasul vine din STARE (ce ai in traista, ce e la gater, ce e in plase), nu din quest-ul bifat: cat
-- se taie, pasul e "stai in inel", oricare ar fi quest-ul. Si un quest de cumparare fara bani nu mai
-- trimite la platforma, ci la bucla care face banii.
local TycoonConfig =
    require(script and script.Parent.Parent.Config.TycoonConfig or "../Config/TycoonConfig")
local Strings = require(script and script.Parent.Parent.Config.Strings or "../Config/Strings")

export type NetInfo = { padId: string, x: number, y: number, count: number, capacity: number? }
export type HandInfo = { nets: { string } }
-- Obiectivul venit din quest-ul activ. Cand exista, EL e obiectivul -- inaintea tuturor regulilor
-- de mai jos. Altfel sageata ar arata spre un lucru, iar bannerul de sus ar cere altul, si
-- jucatorul ar avea doua ghidaje care se contrazic.
export type QuestGoal = {
    key: string,
    text: string,
    x: number,
    y: number,
    padId: string?,
    price: number?,
    -- [D51] felul quest-ului (QuestConfig): "pad" | "level" | "collected" | "sawn" | "sold" | ...
    kind: string?,
    progress: number?,
    goal: number?,
    -- quest de nivel: costul NIVELULUI URMATOR (se urca nivel cu nivel) si statia, ca butonul Upgrade
    -- de pe cardul ei sa pulseze
    levelCost: number?,
    upgradeKind: string?,
    upgradeId: string?,
}

export type State = {
    quest: QuestGoal?,
    coins: number,
    pads: { [string]: string }, -- padId -> "bought" | "available" | "outline"
    nets: { NetInfo },
    sackCount: number,
    sackCapacity: number,
    -- cate din traista sunt deja taiate [D49]; restul sunt busteni care merg la gater. nil = 0.
    sackCut: number?,
    sackRawScrap: number?, -- [D55] scrap brut din traista: nu e bustean, nu merge la gater
    hands: { HandInfo }, -- hands[i].nets: plasele pe care le deserveste alergatorul, nu de mana
    firstsCollect: boolean,
    firstsSell: boolean,
    -- [D50] toate meseriile au cel putin un om: de aici ghidajul tace (vezi pickGoal). nil = nu.
    allCrewsHired: boolean?,
    -- [D51] ce trebuie pasilor buclei; nil = 0 / nimeni
    sawIn: number?, -- bustenii care asteapta la gater
    sawOut: number?, -- scandurile gata la gater
    storage: number?, -- bustenii din depozit
    crews: { [string]: number }?, -- rol -> cati oameni
    dockPileValue: number?, -- monedele care inca se scurg din gramada tavernei
}
export type Goal = {
    -- "buy" | "upgrade" | "collect" | "wait" | "cut" | "take" | "sell" (taverna) | "deliver" (gater) |
    -- "save" | "goto"
    kind: string,
    key: string, -- identitate stabila, ca GuideController sa stie cand s-a schimbat obiectivul
    text: string,
    -- unde; nil = nicaieri anume (plasele prind, monedele vin): textul ramane, sageata nu
    x: number?,
    y: number?,
    -- primele trei obiective ale unui jucator nou (primul pad, prima culegere, prima vanzare):
    -- se arata FARA sa astepte cele 11s de "nicio progresie" [L2/L3]
    immediate: boolean,
    -- doar pentru "buy"/"save": cat costa tinta, ca HUD-ul sa poata desena progresul monedelor.
    -- Fara asta, linia "NEXT" ar spune un nume fara sa spuna cat mai ai de strans.
    price: number?,
    padId: string?,
    -- [D51] quest de nivel: statia al carei buton Upgrade pulseaza pe cardul obiectului
    upgradeKind: string?,
    upgradeId: string?,
}

local GuideMath = {}

-- Unde duci ce ai in traista [D49]: bustenii la gater, scandurile la taverna. Pana in D49 regulile
-- b/d trimiteau la debarcader chiar si dupa ce predarea se mutase la gater (D48) -- sageata arata
-- locul gresit. Acum decide ce duci, nu o adresa fixa. Tinta e locul unde STAI [D50]: la gater, inelul
-- din fata usii, nu mijlocul cladirii; la taverna, usa.
local function carryGoal(s: State, full: boolean): Goal
    local cut = s.sackCut or 0
    -- [D55] scrap-ul din traista nu merge la gater: nu intra in "busteni"
    if s.sackCount - cut - (s.sackRawScrap or 0) > 0 then
        local stand = TycoonConfig.SAWMILL_STAND
        return {
            kind = "deliver",
            key = "sawmill",
            text = if full then Strings.SACK_FULL_LOGS else Strings.GUIDE_LOGS_TO_SAWMILL,
            x = stand.x,
            y = stand.y,
            immediate = not s.firstsSell,
        }
    end
    return {
        kind = "sell",
        key = "dock",
        text = if full then Strings.SACK_FULL_PLANKS else Strings.GUIDE_SELL_PLANKS,
        x = TycoonConfig.DOCK.x,
        y = TycoonConfig.DOCK.y,
        immediate = not s.firstsSell,
    }
end

-- [D50] Sageata si dara ghideaza doar pana ai cate un om la fiecare meserie. Owner-ul: "doar pana
-- jucatorul ajunge sa aiba toate npc-urile". Dupa aia lantul merge singur, iar o sageata care tot
-- arata ar fi zgomot.
function GuideMath.allCrewsHired(counts: { [string]: number }, roles: { string }): boolean
    for _, role in roles do
        if (counts[role] or 0) < 1 then
            return false
        end
    end
    return #roles > 0
end

local function boughtCount(pads: { [string]: string }): number
    local n = 0
    for _, status in pads do
        if status == "bought" then
            n += 1
        end
    end
    return n
end

-- [D51] BUCLA DE MANA, pasul de acum, in ordinea in care nu sare nimic peste nimic: ce ai in traista
-- merge unde trebuie, ce asteapta la gater se taie INAINTE sa pleci, scandurile gata se iau, apoi se
-- vand, iar abia la urma te intorci la plase. Un pas facut de un om al tau nu mai e al tau. `quest` =
-- quest-ul activ, doar ca sa stie cat mai ceri de la plasa in primul quest.
function GuideMath.loopStep(s: State, quest: QuestGoal?): Goal
    local crews = s.crews or {}
    local cut = s.sackCut or 0
    local raw = s.sackCount - cut - (s.sackRawScrap or 0) -- [D55] scrap-ul nu e bustean
    local full = s.sackCapacity > 0 and s.sackCount >= s.sackCapacity
    local room = s.sackCapacity - s.sackCount
    local stand = TycoonConfig.SAWMILL_STAND

    -- 1) busteni in traista -> la gater
    if raw > 0 then
        return {
            kind = "deliver",
            key = "sawmill",
            text = if full then Strings.SACK_FULL_LOGS else Strings.GUIDE_LOGS_TO_SAWMILL,
            x = stand.x,
            y = stand.y,
            immediate = true,
        }
    end
    -- 2) busteni la gater si nimeni care sa-i taie -> stai in inel pana la ultimul
    local sawIn = s.sawIn or 0
    if sawIn > 0 and (crews.sawyer or 0) == 0 then
        return {
            kind = "cut",
            key = "cut",
            text = Strings.stepStayCut(sawIn),
            x = stand.x,
            y = stand.y,
            immediate = true,
        }
    end
    -- 3) scanduri gata, loc in traista, niciun Hauler -> le iei
    if (s.sawOut or 0) > 0 and room > 0 and (crews.hauler or 0) == 0 then
        return {
            kind = "take",
            key = "planks",
            text = Strings.STEP_TAKE_PLANKS,
            x = stand.x,
            y = stand.y,
            immediate = true,
        }
    end
    -- 4) scanduri in traista -> la taverna
    if cut > 0 then
        return {
            kind = "sell",
            key = "dock",
            text = if full then Strings.SACK_FULL_PLANKS else Strings.GUIDE_SELL_PLANKS,
            x = TycoonConfig.DOCK.x,
            y = TycoonConfig.DOCK.y,
            immediate = true,
        }
    end
    -- 5) busteni in depozit, niciun Porter -> ii iei tu
    if (s.storage or 0) > 0 and (crews.porter or 0) == 0 and room > 0 then
        local st = TycoonConfig.STORAGE_STAND
        return {
            kind = "take",
            key = "storage",
            text = Strings.STEP_TAKE_FROM_STORAGE,
            x = st.x,
            y = st.y,
            immediate = true,
        }
    end
    -- 6) plasele, cat timp le golesti tu: cea mai plina
    if (crews.collector or 0) == 0 then
        local best: NetInfo? = nil
        for _, n in s.nets do
            if best == nil or n.count > (best :: NetInfo).count then
                best = n
            end
        end
        if best ~= nil then
            local net = best :: NetInfo
            -- primul quest cere o plasa plina: pana se strange cat lipseste, asteptarea E pasul
            if quest ~= nil and quest.kind == "collected" and quest.goal ~= nil then
                local need = math.max(1, quest.goal - (quest.progress or 0))
                need = math.min(need, net.capacity or need)
                if net.count < need then
                    return {
                        kind = "wait",
                        key = `wait:{net.padId}`,
                        text = Strings.stepWaitNet(net.count, need),
                        x = net.x,
                        y = net.y,
                        immediate = true,
                    }
                end
            end
            if net.count > 0 and room > 0 then
                return {
                    kind = "collect",
                    key = `net:{net.padId}`,
                    text = Strings.GUIDE_COLLECT,
                    x = net.x,
                    y = net.y,
                    immediate = true,
                }
            end
        end
    end
    -- 7) nimic de facut cu mana: plasele prind
    return {
        kind = "wait",
        key = "catching",
        text = Strings.STEP_NETS_CATCHING,
        immediate = true,
    }
end

-- [D51] Pasul pentru quest-ul activ. Bucla (colectat, taiat, vandut) -> pasul buclei. Cumparare sau
-- nivel CU banii in mana -> obiectul. FARA bani -> ce face banii: daca vin deja din gramada tavernei,
-- asteptarea; altfel pasul buclei. Alt fel de quest -> tinta lui.
local function questGoal(s: State, quest: QuestGoal): Goal
    local kind = quest.kind
    if kind == "collected" or kind == "sawn" or kind == "sold" then
        return GuideMath.loopStep(s, quest)
    end
    if kind == "pad" or kind == "level" then
        local price = if kind == "level" then quest.levelCost else quest.price
        if price ~= nil and price > s.coins then
            local missing = math.ceil(price - s.coins)
            if (s.dockPileValue or 0) >= missing then
                return {
                    kind = "wait",
                    key = `coming:{quest.key}`,
                    text = Strings.STEP_COINS_COMING,
                    immediate = true,
                    price = price,
                }
            end
            local step = GuideMath.loopStep(s, nil)
            step.key = `earn:{quest.key}:{step.key}`
            step.price = price
            return step
        end
        return {
            kind = if kind == "level" then "upgrade" else "buy",
            key = `quest:{quest.key}`,
            text = if kind == "level" then Strings.STEP_UPGRADE else Strings.STEP_BUY,
            x = quest.x,
            y = quest.y,
            immediate = true,
            price = price,
            padId = quest.padId,
            upgradeKind = quest.upgradeKind,
            upgradeId = quest.upgradeId,
        }
    end
    return {
        kind = "goto",
        key = `quest:{quest.key}`,
        text = quest.text,
        x = quest.x,
        y = quest.y,
        immediate = true,
        price = quest.price,
        padId = quest.padId,
    }
end

-- O plasa "de mana" e una care NU apare in lista niciunui alergator -- alea le culege automatizarea.
local function isHandNet(padId: string, hands: { HandInfo }): boolean
    for _, h in hands do
        for _, id in h.nets do
            if id == padId then
                return true
            end
        end
    end
    return false
end

function GuideMath.pickGoal(s: State): Goal?
    if s.allCrewsHired then
        return nil -- [D50] toti oamenii angajati: ghidajul tace de tot
    end
    -- 0) quest activ: are intaietate absoluta. E acelasi obiectiv pe care il scrie bannerul de sus
    -- si linia "NEXT" din HUD, deci cele doua nu se pot contrazice niciodata; pasul lui vine din stare.
    local quest = s.quest
    if quest ~= nil then
        return questGoal(s, quest)
    end

    -- a) nimic cumparat -- primul pas al oricarei sesiuni noi, gratis, mereu imediat
    if boughtCount(s.pads) == 0 then
        local p = TycoonConfig.byId["first_net"]
        if p ~= nil and p.x ~= nil and p.y ~= nil then
            return {
                kind = "buy",
                key = "pad:first_net",
                text = Strings.GUIDE_FIRST_PAD,
                x = p.x :: number,
                y = p.y :: number,
                immediate = true,
                price = p.price,
                padId = p.id,
            }
        end
    end

    -- b) traista plina -- mai urgent decat orice cumparare, altfel plasele de mana raman blocate
    if s.sackCapacity > 0 and s.sackCount >= s.sackCapacity then
        return carryGoal(s, true)
    end

    -- c) cea mai ieftina platforma DISPONIBILA si ACCESIBILA acum (pot fi doua disponibile deodata)
    local best: TycoonConfig.Pad? = nil
    for id, status in s.pads do
        if status ~= "available" then
            continue
        end
        local p = TycoonConfig.byId[id]
        if p == nil or p.x == nil or p.y == nil or p.price > s.coins then
            continue
        end
        if best == nil or p.price < (best :: TycoonConfig.Pad).price then
            best = p
        end
    end
    if best ~= nil then
        local p = best :: TycoonConfig.Pad
        return {
            kind = "buy",
            key = `pad:{p.id}`,
            text = Strings.guideBuy(p.name),
            x = p.x :: number,
            y = p.y :: number,
            immediate = false, -- "primul pad" e doar a), asta e a doua+ platforma
            price = p.price,
            padId = p.id,
        }
    end

    -- d) traista neagoala si (n-ai vandut niciodata SAU e pe jumatate) -- gater sau debarcader
    if s.sackCount > 0 and (not s.firstsSell or s.sackCount * 2 >= s.sackCapacity) then
        return carryGoal(s, false)
    end

    -- e) o plasa culeasa CU MANA are ceva inauntru (cele automatizate nu au nevoie de indemn)
    for _, n in s.nets do
        if n.count > 0 and not isHandNet(n.padId, s.hands) then
            return {
                kind = "collect",
                key = `net:{n.padId}`,
                -- textul de atingere ("Tap Collect") e substituit de GuideController, care stie
                -- de UserInputService -- modulul asta ramane pur, fara `game`
                text = Strings.GUIDE_COLLECT,
                x = n.x,
                y = n.y,
                immediate = not s.firstsCollect,
            }
        end
    end

    -- f) NIMIC DE FACUT ACUM: nu-ti ajung banii de nimic, traista e aproape goala, plasele inca
    -- se umplu. Pana acum aici se intorcea `nil`, adica jucatorul ramanea fara niciun reper fix
    -- cand stransul dureaza cel mai mult -- exact momentul in care owner-ul a spus "playerul nu
    -- stie pentru ce strange banii". Obiectivul devine tinta economisirii: cea mai ieftina
    -- platforma disponibila, oricat ar costa. NU e imediat: sageata tot nu sare, doar linia fixa
    -- din HUD stie ce sa scrie.
    local cheapest: TycoonConfig.Pad? = nil
    for id, status in s.pads do
        if status ~= "available" then
            continue
        end
        local p = TycoonConfig.byId[id]
        if p == nil or p.x == nil or p.y == nil then
            continue
        end
        if cheapest == nil or p.price < (cheapest :: TycoonConfig.Pad).price then
            cheapest = p
        end
    end
    if cheapest ~= nil then
        local p = cheapest :: TycoonConfig.Pad
        return {
            kind = "save",
            key = `save:{p.id}`,
            text = Strings.guideSaving(p.name),
            x = p.x :: number,
            y = p.y :: number,
            immediate = false,
            price = p.price,
            padId = p.id,
        }
    end

    return nil -- g) chiar nimic de aratat
end

-- ---- unde sta textul de deasupra tintei [D52] ----------------------------------------------------
-- Eticheta ghidajului sta in LUME, iar HUD-ul se deseneaza peste lume. Cand tinta ajunge langa un colt
-- ocupat -- monedele, traista si linia NEXT stau sus-stanga, iar taverna ajunge exact acolo cand esti la
-- gater -- textul ramanea sub panouri si nu se mai citea [vazut in Studio, 2026-09-13]. Regula: deasupra
-- tintei daca e loc; altfel sub inel; altfel deloc (acelasi text sta oricum pe linia NEXT). Si nu iese
-- din ecran pe laterale. Totul in coordonatele panzei HUD; controller-ul face conversiile.
export type Rect = { x: number, y: number, w: number, h: number }
export type LabelQuery = {
    centerX: number, -- mijlocul tintei, pe orizontala
    aboveY: number, -- varful etichetei cand sta deasupra tintei
    belowY: number, -- varful etichetei cand sta sub inel
    width: number,
    height: number,
    screenW: number,
    screenH: number,
    blockers: { Rect }, -- panourile HUD vizibile
    current: string, -- "above" | "below" | "hidden": unde a stat pana acum
}

GuideMath.LABEL_MARGIN = 8 -- fata de marginea ecranului si de panouri
-- inapoi deasupra doar cu loc in plus: fara el, la marginea unui panou eticheta ar sari la fiecare pas
GuideMath.LABEL_RETURN = 12

-- Intoarce locul ("above" | "below" | "hidden") si cat se muta eticheta pe orizontala ca sa ramana
-- intreaga pe ecran (aceleasi unitati ca intrarea).
function GuideMath.labelPlacement(q: LabelQuery): (string, number)
    local margin = GuideMath.LABEL_MARGIN
    local left = q.centerX - q.width / 2
    local shift = 0
    if q.width <= q.screenW - 2 * margin then
        if left < margin then
            shift = margin - left
        elseif left + q.width > q.screenW - margin then
            shift = q.screenW - margin - (left + q.width)
        end
    end
    local x = left + shift
    local function fits(y: number, pad: number): boolean
        if y < pad or y + q.height > q.screenH - pad then
            return false
        end
        for _, b in q.blockers do
            if
                x < b.x + b.w + pad
                and b.x < x + q.width + pad
                and y < b.y + b.h + pad
                and b.y < y + q.height + pad
            then
                return false
            end
        end
        return true
    end
    local abovePad = if q.current == "above" then margin else margin + GuideMath.LABEL_RETURN
    if fits(q.aboveY, abovePad) then
        return "above", shift
    elseif fits(q.belowY, margin) then
        return "below", shift
    end
    return "hidden", shift
end

return GuideMath
