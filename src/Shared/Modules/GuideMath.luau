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
local WorldMath = require(script and script.Parent.WorldMath or "./WorldMath")
local StationConfig =
    require(script and script.Parent.Parent.Config.StationConfig or "../Config/StationConfig")
local FlowConfig =
    require(script and script.Parent.Parent.Config.FlowConfig or "../Config/FlowConfig")
local StateCopy = require(script and script.Parent.StateCopy or "./StateCopy")
local TreasureConfig =
    require(script and script.Parent.Parent.Config.TreasureConfig or "../Config/TreasureConfig")

-- `scrap` = plasa de scrap [D56]: o goleste Scrap Collector-ul, nu Collector-ul
export type NetInfo = {
    padId: string,
    x: number,
    y: number,
    count: number,
    capacity: number?,
    scrap: boolean?,
    line: string?, -- [D65] linia pe care curge ce prinde plasa; nil = lemn (sau fier, cu `scrap`)
}
export type HandInfo = { nets: { string } }
-- [D65] O linie a Morii, cat ii trebuie buclei de mana: aceleasi patru numere pe care lemnul si fierul le au in
-- campurile lor cu nume (`sackRawScrap`, `shed`, `forgeIn`, `forgeOut`).
export type LineInfo = { raw: number, store: number, input: number, output: number }
-- Obiectivul venit din quest-ul activ. Cand exista, EL e obiectivul -- inaintea tuturor regulilor
-- de mai jos. Altfel sageata ar arata spre un lucru, iar bannerul de sus ar cere altul, si
-- jucatorul ar avea doua ghidaje care se contrazic.
export type QuestGoal = {
    key: string,
    text: string,
    -- [D70, pasul k5] nil la un quest fara loc in lume (un pas de venit, „Earn 1T coins a second”)
    x: number?,
    y: number?,
    padId: string?,
    price: number?,
    -- [D51] felul quest-ului (QuestConfig): "pad" | "level" | "collected" | "sawn" | "sold" | ...
    kind: string?,
    -- [D65] quest care arata un loc nou (roata de apa, dincolo de gard): isi are sageata chiar daca ghidajul tace
    always: boolean?,
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
    sackIron: number?, -- [D56] cat din `sackCut` e fier: textul tavernei spune ce duci [D40]
    sackFinds: number?, -- [D56] cat din `sackCut` sunt gasiri neprelucrate
    hands: { HandInfo }, -- hands[i].nets: plasele pe care le deserveste alergatorul, nu de mana
    firstsCollect: boolean,
    firstsSell: boolean,
    -- [D50] toate meseriile au cel putin un om: de aici ghidajul tace (vezi pickGoal). nil = nu.
    allCrewsHired: boolean?,
    -- [D51] ce trebuie pasilor buclei; nil = 0 / nimeni
    sawIn: number?, -- bustenii care asteapta la gater
    sawOut: number?, -- scandurile gata la gater
    storage: number?, -- bustenii din depozit
    forgeIn: number?, -- [D56] scrap-ul care asteapta la forja
    forgeOut: number?, -- [D56] fierul gata la forja
    shed: number?, -- [D56] scrap-ul din Scrap Shed
    crews: { [string]: number }?, -- rol -> cati oameni
    dockPileValue: number?, -- monedele care inca se scurg din gramada tavernei
    hasFished: boolean?, -- [D59] ai scos macar un peste: de acum linia NEXT poate trimite la ponton cat strangi bani
    treasureWaiting: string?, -- [D59] felul primului lucru care te asteapta la ponton (TreasureConfig), nil = nimic
    -- [D65] liniile Morii (dupa numele liniei) si cate bucati din traista cumpara fiecare vanzator. nil = doar Era 1.
    lines: { [string]: LineInfo }?,
    sellAt: { [string]: number }?,
    -- [D70, pasul k3] harta ta (nil = satul) si piesele gata din traista, pe unirea lor (butoaie + cablu -> "grid"). In alta
    -- lume decat satul nu exista bustenii, gaterul, forja, taverna: pasii lor nu se dau niciodata.
    world: number?,
    parts: { [string]: number }?,
    -- [verificatorul k3] ce e in traista, pe marfa: ce piesa a unirii duci („Take the cable…”, nu „barrels and cable”)
    sackContents: { [string]: number }?,
    -- [D70, pasul k5] ce se mai poate urca acum cu castig (AmbitionMath, aceeasi tinta ca pe linia NEXT fara quest): pasul
    -- unui quest de venit il numeste. `upgradeKind` / `upgradeId`: statia (sau "crew" si meseria) al carei Upgrade pulseaza.
    ambition: { text: string, upgradeKind: string?, upgradeId: string? }?,
    -- [D70, pasul k6] barajul se poate ridica acum (serverul, damAvailable): unde e masa Dam Plans. nil in rest.
    damPlans: { x: number, y: number }?,
}
export type Goal = {
    -- "buy" | "upgrade" | "collect" | "wait" | "cut" | "smelt" | "take" | "sell" (taverna) | "deliver" (gater,
    -- forja) | "save" | "goto"
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

-- [D63] textul pasului de cumparare, cu verbul platformei ("cast", "hire", "build"...), ca pe butonul cartonasului
local function buyStepText(padId: string?): string
    local pad = if padId ~= nil then TycoonConfig.byId[padId] else nil
    return if pad ~= nil then Strings.stepBuy(TycoonConfig.verbOf(pad)) else Strings.STEP_BUY
end

-- Unde duci ce ai in traista [D49]: bustenii la gater, [D56] scrap-ul la forja, marfa gata la taverna. Pana in D49
-- regulile b/d trimiteau la debarcader chiar si dupa ce predarea se mutase la gater (D48) -- sageata arata locul
-- gresit. Acum decide ce duci, nu o adresa fixa. Tinta e locul unde STAI [D50]: la gater si la forja, inelul din
-- fata usii, nu mijlocul cladirii; la taverna, usa.
local function logsGoal(full: boolean, immediate: boolean): Goal
    local stand = TycoonConfig.SAWMILL_STAND
    return {
        kind = "deliver",
        key = "sawmill",
        text = if full then Strings.SACK_FULL_LOGS else Strings.GUIDE_LOGS_TO_SAWMILL,
        x = stand.x,
        y = stand.y,
        immediate = immediate,
    }
end

local function scrapGoal(full: boolean, immediate: boolean): Goal
    local stand = TycoonConfig.WORKSHOP_STAND
    return {
        kind = "deliver",
        key = "forge",
        text = if full then Strings.SACK_FULL_SCRAP else Strings.GUIDE_SCRAP_TO_FORGE,
        x = stand.x,
        y = stand.y,
        immediate = immediate,
    }
end

-- [D56] Textul spune ce duci: fierul e si el "gata de vandut", deci "Sell the planks" ar fi mintit cu fier in
-- traista [D40]. Gasirile nu schimba textul cand merg cu scandurile sau fierul.
local function sellText(s: State, full: boolean): string
    local iron = s.sackIron or 0
    local finds = s.sackFinds or 0
    local planks = (s.sackCut or 0) - iron - finds
    if iron > 0 and planks > 0 then
        return if full then Strings.SACK_FULL_BOTH else Strings.GUIDE_SELL_BOTH
    elseif iron > 0 then
        return if full then Strings.SACK_FULL_IRON else Strings.GUIDE_SELL_IRON
    elseif planks <= 0 and finds > 0 then
        return if full then Strings.SACK_FULL_FINDS else Strings.guideSellFinds(finds)
    end
    return if full then Strings.SACK_FULL_PLANKS else Strings.GUIDE_SELL_PLANKS
end

local function sellGoal(s: State, full: boolean, immediate: boolean): Goal
    return {
        kind = "sell",
        key = "dock",
        text = sellText(s, full),
        x = TycoonConfig.DOCK.x,
        y = TycoonConfig.DOCK.y,
        immediate = immediate,
    }
end

-- [D65] LINIILE MORII, din tabele: locurile din TycoonConfig.LINE_PLACES, oamenii din StationConfig.LINES, cuvintele
-- din Strings.LINE_WORDS. Lemnul si fierul raman pe campurile si pe frazele lor, reglate cu owner-ul [D51, D56].
-- [D70, pasul k2] Oamenii fiecarui pas dupa meserie (StationConfig.STEP_OF_JOB), nu dupa pozitie: o unire are doar
-- atelierul si drumul spre oras, iar pozitia 3/4 ar fi fost nil. Unirea (Relay) nu e o linie cu magazie si plase: turul ei
-- de mana vine la k5, deci aici nu intra.
local EXTRA_LINES: { string } = {}
for _, line in StationConfig.LINE_ORDER do
    if line ~= "wood" and line ~= "iron" and StationConfig.LINES[line].inputs == nil then
        table.insert(EXTRA_LINES, line)
    end
end
local function stepOf(line: string, job: string): StationConfig.Step
    return StationConfig.STEP_OF_JOB[line][job]
end
-- [D70, pasul k3] UNIRILE (Relay Station): n-au magazie si nici marfa bruta; le aduci piesele, stai in inelul lor cat n-au
-- om si iei ce iese. Locurile lor sunt in JOIN_PLACES.
local JOIN_LINES: { string } = {}
for _, line in StationConfig.LINE_ORDER do
    if StationConfig.LINES[line].inputs ~= nil then
        table.insert(JOIN_LINES, line)
    end
end
-- Atelierele in care stai si din care iei marfa gata: ale liniilor Morii si ale erelor de dupa, apoi unirile.
local WORK_LINES: { string } = table.clone(EXTRA_LINES)
table.move(JOIN_LINES, 1, #JOIN_LINES, #WORK_LINES + 1, WORK_LINES)
-- Inelul unui atelier: al liniei (LINE_PLACES) sau al unirii (JOIN_PLACES).
local function standOf(line: string): { x: number, y: number }
    local places = TycoonConfig.LINE_PLACES[line] or TycoonConfig.JOIN_PLACES[line]
    return places.playerStand
end
-- Satul (lumea 1): singurul loc cu busteni, gater, forja si taverna.
local function inVillage(s: State): boolean
    return s.world == nil or s.world == 1
end
-- Piesele gata din traista (pe unirea lor).
local function partsCount(s: State): number
    local n = 0
    for _, count in s.parts or {} do
        n += count
    end
    return n
end

-- Marfa bruta a liniilor Morii din traista (nu sunt busteni: nu merg la gater).
local function extraRaw(s: State): number
    local n = 0
    for _, line in EXTRA_LINES do
        local info = if s.lines ~= nil then s.lines[line] else nil
        n += if info ~= nil then info.raw else 0
    end
    return n
end

-- Cate bucati din traista se vand la alt vanzator decat taverna. `sackCut` numara DOAR ce cumpara taverna (serverul:
-- `cut = sellBy.dock.count`), deci astea nu sunt in el -- si nu sunt nici busteni.
local function soldElsewhere(s: State): number
    local n = 0
    for seller, count in s.sellAt or {} do
        if seller ~= "dock" then
            n += count
        end
    end
    return n
end

local function rawGoal(line: string, full: boolean, immediate: boolean): Goal
    local stand = standOf(line)
    local words = Strings.LINE_WORDS[line]
    return {
        kind = "deliver",
        key = stepOf(line, "work").link,
        text = if full then Strings.sackFullRaw(line) else Strings.guideRawTo(words),
        x = stand.x,
        y = stand.y,
        immediate = immediate,
    }
end

-- Marfa bruta a unei linii a Morii din traista -> la atelierul ei; nil daca n-ai.
local function extraRawGoal(s: State, full: boolean, immediate: boolean): Goal?
    for _, line in EXTRA_LINES do
        local info = if s.lines ~= nil then s.lines[line] else nil
        if info ~= nil and info.raw > 0 then
            return rawGoal(line, full, immediate)
        end
    end
    return nil
end

-- [D70, pasul k3] Piesele gata din traista -> la inelul unirii lor, unde le lasi pe E (acolo apare cardul, nu la intrarea pe
-- care o folosesc oamenii); nil daca n-ai.
local function partsGoal(s: State, full: boolean, immediate: boolean): Goal?
    for _, line in JOIN_LINES do
        if ((s.parts or {})[line] or 0) > 0 then
            local goal = rawGoal(line, full, immediate)
            -- [verificatorul A2] sacul plin: textul vine din aceeasi regula ca toast-ul plasei (partsFullText)
            if full then
                goal.text = GuideMath.partsFullText(
                    { [line] = (s.parts or {})[line] },
                    s.sackContents
                ) or goal.text
                return goal
            end
            -- [verificatorul k3] o singura piesa in traista: textul o numeste doar pe ea
            local joins = FlowConfig.LINES[line].joins
            if joins ~= nil and s.sackContents ~= nil then
                local carried = StateCopy.partsCarried(s.sackContents, joins)
                local only: string? = nil
                local kinds = 0
                for part in carried do
                    only = part
                    kinds += 1
                end
                if kinds == 1 and only ~= nil then
                    goal.text =
                        Strings.guidePartTo(Strings.LINE_WORDS[only], Strings.LINE_WORDS[line])
                end
            end
            return goal
        end
    end
    return nil
end

-- [verificatorul A2] Textul sacului plin cu piesele unei uniri, acelasi pentru ghidaj (partsGoal) si pentru toast-ul plasei
-- (NetController): o singura piesa -> „Sack full — take the barrels to the Relay”, amandoua -> „Sack full — barrels and cable
-- to the Relay”; nil fara piese. `model`: liniile (implicit cele din joc; testele dau FlowConfig.FULL).
function GuideMath.partsFullText(
    partBy: { [string]: number }?,
    contents: { [string]: number }?,
    model: { [string]: any }?
): string?
    local lines = model or FlowConfig.LINES
    -- in ordinea liniilor (ca partsGoal), nu in ordinea tabelului: cu doua uniri, ghidajul si toast-ul numesc aceeasi
    for _, line in StationConfig.LINE_ORDER_ALL do
        local n = (partBy or {})[line] or 0
        local def = lines[line]
        if n > 0 and def ~= nil and def.joins ~= nil then
            if contents ~= nil then
                local only: string? = nil
                local kinds = 0
                for part in StateCopy.partsCarried(contents, def.joins) do
                    only = part
                    kinds += 1
                end
                if kinds == 1 and only ~= nil then
                    return Strings.sackFullPart(Strings.LINE_WORDS[only], Strings.LINE_WORDS[line])
                end
            end
            return Strings.sackFullRaw(line)
        end
    end
    return nil
end

-- Ce se vinde la alt vanzator decat taverna -> la usa lui; nil daca n-ai.
local function extraSellGoal(s: State, full: boolean, immediate: boolean): Goal?
    for _, seller in StationConfig.SELLER_ORDER do
        if seller ~= "dock" and ((s.sellAt or {})[seller] or 0) > 0 then
            local door = TycoonConfig.SELLER_PLACES[seller].door
            return {
                kind = "sell",
                key = seller,
                text = Strings.guideSellAt(Strings.LINK_WORDS[seller].label, full),
                x = door.x,
                y = door.y,
                immediate = immediate,
            }
        end
    end
    return nil
end

local function carryGoal(s: State, full: boolean): Goal
    local cut = s.sackCut or 0
    local rawScrap = s.sackRawScrap or 0
    local village = inVillage(s)
    -- [D55] scrap-ul din traista nu merge la gater: nu intra in "busteni"; [D65] nici marfa Morii, bruta sau gata;
    -- [D70] nici piesele unei uniri
    if
        village
        and s.sackCount - cut - rawScrap - extraRaw(s) - soldElsewhere(s) - partsCount(s) > 0
    then
        return logsGoal(full, not s.firstsSell)
    elseif village and rawScrap > 0 then
        return scrapGoal(full, not s.firstsSell)
    end
    local mill = extraRawGoal(s, full, not s.firstsSell)
    if mill ~= nil then
        return mill
    end
    local parts = partsGoal(s, full, not s.firstsSell)
    if parts ~= nil then
        return parts
    end
    if not village then
        -- [D70, pasul k3] la baraj nu exista taverna: ce se vinde merge la vanzatorul lui; altfel, pasul buclei
        return extraSellGoal(s, full, not s.firstsSell) or GuideMath.loopStep(s, nil)
    end
    -- ce cumpara taverna merge la ea; restul, la vanzatorul lui
    if cut <= 0 then
        local elsewhere = extraSellGoal(s, full, not s.firstsSell)
        if elsewhere ~= nil then
            return elsewhere
        end
    end
    return sellGoal(s, full, not s.firstsSell)
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

-- [D56] Meseriile dupa care ghidajul tace: ale lemnului (si Innkeeper-ul) mereu, ale fierului doar din clipa in care
-- ai Forge. Pana atunci ghidajul tace dupa cei cinci oameni ai lemnului, ca in D50; cu Forge se trezeste si merge
-- pana la cei patru oameni ai fierului -- owner-ul: jucatorul "se pierde cand ajunge la scraps".
-- [D65] La fel la Moara: cu roata de apa intra oamenii pieselor si negustorul Pietei, cu cuptorul de cupru cei ai
-- cuprului. `opened` = platformele cumparate care pornesc cate o linie (FlowConfig: `processorPad`), dupa id.
-- [D70, verificatorul j13a] Doar meseriile hartii tale (`world`, fara el satul): dupa comutator, liniile barajului n-au
-- platforma care le porneste, iar fara filtru ghidajul ar fi asteptat in sat oamenii barajului si n-ar mai fi tacut.
function GuideMath.guidedRoles(opened: { [string]: boolean }, world: number?): { string }
    local roles: { string } = {}
    local function lineIsOpen(line: string): boolean
        local pad = FlowConfig.LINES[line].processorPad
        return pad == nil or opened[pad] == true
    end
    for _, role in StationConfig.ROLES do
        if not WorldMath.allowed(world, StationConfig.ERA_OF_ROLE[role]) then
            continue
        end
        local link = StationConfig.LINK_OF[role]
        local line = StationConfig.LINE_OF[link]
        local open = false
        if line ~= nil then
            open = lineIsOpen(line)
        else
            -- omul unui vanzator: de cand e pornita prima linie a vanzatorului lui
            for _, l in StationConfig.LINE_ORDER do
                if StationConfig.LINES[l].seller == link then
                    open = lineIsOpen(l)
                    break
                end
            end
        end
        if open then
            table.insert(roles, role)
        end
    end
    return roles
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
--
-- [D56] Un singur lant de prioritati pentru amandoua liniile, cu pasii fierului intercalati langa perechea lor de
-- lemn (ordinea e in GuideMath.test). In joc oamenii lemnului sunt toti angajati inaintea Forge, deci in turul
-- fierului pasii 1, 3, 5 si 8 nu mai apar.
function GuideMath.loopStep(s: State, quest: QuestGoal?): Goal
    local crews = s.crews or {}
    local village = inVillage(s)
    -- [D70, pasul k3] in alta lume decat satul, pasii lemnului si ai fierului (1-9) nu exista: campurile lor sunt 0
    local cut = if village then s.sackCut or 0 else 0
    local rawScrap = if village then s.sackRawScrap or 0 else 0
    -- [D55] scrap-ul nu e bustean; [D65] nici marfa Morii, bruta sau gata; [D70] nici piesele unei uniri
    local logs = if village
        then s.sackCount - cut - rawScrap - extraRaw(s) - soldElsewhere(s) - partsCount(s)
        else 0
    local full = s.sackCapacity > 0 and s.sackCount >= s.sackCapacity
    local room = s.sackCapacity - s.sackCount
    local saw = TycoonConfig.SAWMILL_STAND
    local forge = TycoonConfig.WORKSHOP_STAND

    -- 1) busteni in traista -> la gater
    if logs > 0 then
        return logsGoal(full, true)
    end
    -- 2) [D56] scrap in traista -> la forja
    if rawScrap > 0 then
        return scrapGoal(full, true)
    end
    -- 2b) [D65] marfa bruta a unei linii a Morii -> la atelierul ei
    local millRaw = extraRawGoal(s, full, true)
    if millRaw ~= nil then
        return millRaw
    end
    -- 2c) [D70, pasul k3] piesele gata ale unei uniri -> la inelul ei
    local parts = partsGoal(s, full, true)
    if parts ~= nil then
        return parts
    end
    -- 3) busteni la gater si nimeni care sa-i taie -> stai in inel pana la ultimul
    local sawIn = if village then s.sawIn or 0 else 0
    if sawIn > 0 and (crews.sawyer or 0) == 0 then
        return {
            kind = "cut",
            key = "cut",
            text = Strings.stepStayCut(sawIn),
            x = saw.x,
            y = saw.y,
            immediate = true,
        }
    end
    -- 4) [D56] scrap la forja si niciun Smelter -> stai in inelul forjei pana la ultimul
    local forgeIn = if village then s.forgeIn or 0 else 0
    if forgeIn > 0 and (crews.smelter or 0) == 0 then
        return {
            kind = "smelt",
            key = "smelt",
            text = Strings.stepStaySmelt(forgeIn),
            x = forge.x,
            y = forge.y,
            immediate = true,
        }
    end
    -- 4b) [D65] la fel la atelierele Morii: marfa la intrare si niciun om al atelierului -> stai in inelul lui;
    -- [D70, pasul k3] si la unire, cat are din toate piesele (`input` = cate uniri se pot face, din Overlay)
    for _, line in WORK_LINES do
        local info = if s.lines ~= nil then s.lines[line] else nil
        local step = stepOf(line, "work")
        if info ~= nil and info.input > 0 and (crews[step.role] or 0) == 0 then
            local stand = standOf(line)
            return {
                kind = "work",
                key = `work:{line}`,
                text = Strings.stepStayWork(Strings.LINE_WORDS[line], info.input),
                x = stand.x,
                y = stand.y,
                immediate = true,
            }
        end
    end
    -- 5) scanduri gata, loc in traista, niciun Hauler -> le iei
    if village and (s.sawOut or 0) > 0 and room > 0 and (crews.hauler or 0) == 0 then
        return {
            kind = "take",
            key = "planks",
            text = Strings.STEP_TAKE_PLANKS,
            x = saw.x,
            y = saw.y,
            immediate = true,
        }
    end
    -- 6) [D56] fier gata, loc in traista, niciun Iron Hauler -> il iei
    if village and (s.forgeOut or 0) > 0 and room > 0 and (crews.ironHauler or 0) == 0 then
        return {
            kind = "take",
            key = "iron",
            text = Strings.STEP_TAKE_IRON,
            x = forge.x,
            y = forge.y,
            immediate = true,
        }
    end
    -- 6b) [D65] marfa gata la un atelier al Morii, loc in traista, niciun om care s-o duca -> o iei; [D70] si la unire
    for _, line in WORK_LINES do
        local info = if s.lines ~= nil then s.lines[line] else nil
        local hauler = stepOf(line, "haul").role
        if info ~= nil and info.output > 0 and room > 0 and (crews[hauler] or 0) == 0 then
            local stand = standOf(line)
            return {
                kind = "take",
                key = `done:{line}`,
                text = Strings.stepTakeDone(Strings.LINE_WORDS[line]),
                x = stand.x,
                y = stand.y,
                immediate = true,
            }
        end
    end
    -- 7) marfa gata in traista (scanduri, fier, gasiri) -> la taverna; [D65] ce cumpara doar Piata, la Piata
    if cut > 0 then
        return sellGoal(s, full, true)
    end
    local elsewhere = extraSellGoal(s, full, true)
    if elsewhere ~= nil then
        return elsewhere
    end
    -- 8) busteni in depozit, niciun Porter -> ii iei tu
    if village and (s.storage or 0) > 0 and (crews.porter or 0) == 0 and room > 0 then
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
    -- 9) [D56] scrap in shed, niciun Scrap Porter -> il iei tu
    if village and (s.shed or 0) > 0 and (crews.scrapPorter or 0) == 0 and room > 0 then
        local st = TycoonConfig.SCRAP_SHED_STAND
        return {
            kind = "take",
            key = "shed",
            text = Strings.STEP_TAKE_FROM_SHED,
            x = st.x,
            y = st.y,
            immediate = true,
        }
    end
    -- 9b) [D65] marfa in magazia unei linii a Morii, niciun om care s-o duca la atelier -> o iei tu
    for _, line in EXTRA_LINES do
        local info = if s.lines ~= nil then s.lines[line] else nil
        local porter = stepOf(line, "port").role
        if info ~= nil and info.store > 0 and (crews[porter] or 0) == 0 and room > 0 then
            local st = TycoonConfig.LINE_PLACES[line].storeStand
            return {
                kind = "take",
                key = `store:{line}`,
                text = Strings.stepTakeFromStore(Strings.LINE_WORDS[line]),
                x = st.x,
                y = st.y,
                immediate = true,
            }
        end
    end
    -- 10) plasele pe care le golesti tu: cea mai plina dintre cele fara omul liniei lor (cele de lemn fara
    -- Collector, cea de scrap fara Scrap Collector [D56]; [D65] ale Morii fara culegatorul liniei lor)
    local best: NetInfo? = nil
    for _, n in s.nets do
        local emptiers = if n.scrap then crews.scrapCollector else crews.collector
        if n.line ~= nil and n.line ~= "wood" and n.line ~= "iron" then
            emptiers = crews[stepOf(n.line, "collect").role]
        end
        if (emptiers or 0) == 0 and (best == nil or n.count > (best :: NetInfo).count) then
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
                text = if net.line ~= nil
                        and Strings.LINE_WORDS[net.line] ~= nil
                        and net.line ~= "wood"
                        and net.line ~= "iron"
                    then Strings.guideCollectRaw(Strings.LINE_WORDS[net.line])
                    elseif net.scrap then Strings.GUIDE_COLLECT_SCRAP
                    else Strings.GUIDE_COLLECT,
                x = net.x,
                y = net.y,
                immediate = true,
            }
        end
    end
    -- 11) nimic de facut cu mana: plasele prind
    return {
        kind = "wait",
        key = "catching",
        text = Strings.STEP_NETS_CATCHING,
        immediate = true,
    }
end

-- [D59] INDICIUL PONTONULUI: cand strangi bani pentru quest si mainile n-au nimic de facut, al doilea rand al liniei NEXT
-- spune ce poti face intre timp -- doar dupa primul tau peste (stii deja ce e undita) si fara tinta in lume (pescuitul e o
-- alegere, nu un pas). Un lucru care te asteapta la ponton bate pescuitul. Pastreaza pretul, ca bara sa masoare monedele.
local function pierHint(s: State, price: number?): Goal?
    if not s.hasFished then
        return nil
    end
    local waiting = s.treasureWaiting
    local kind = if waiting ~= nil then TreasureConfig.byId[waiting] else nil
    if kind ~= nil then
        return {
            kind = "wait",
            key = `pier:{kind.id}`,
            text = Strings.hintTreasureWaiting(kind.phrase),
            immediate = true,
            price = price,
        }
    end
    return {
        kind = "wait",
        key = "pier:fish",
        text = Strings.HINT_FISH_WHILE_SAVING,
        immediate = true,
        price = price,
    }
end

-- [D70, pasul k5] Platforma quest-ului inca nu se poate cumpara (ii lipseste o conditie: alta platforma, un clopot, un
-- venit): nici bara de pret, nici „While you save” — banii singuri n-o deschid.
local function padLocked(s: State, quest: QuestGoal): boolean
    return quest.kind == "pad" and quest.padId ~= nil and s.pads[quest.padId :: string] == "outline" -- o platforma fara stare (alt fel de test, alta harta) nu e „incuiata”
end

-- Pretul unui quest de cumparare sau de nivel, cat nu ti-l permiti inca; nil = alt fel de quest sau ai banii.
local function unaffordablePrice(s: State, quest: QuestGoal): number?
    local kind = quest.kind
    if (kind ~= "pad" and kind ~= "level") or padLocked(s, quest) then
        return nil
    end
    local price = if kind == "level" then quest.levelCost else quest.price
    if price ~= nil and price > s.coins then
        return price
    end
    return nil
end

-- [D51] Pasul pentru quest-ul activ. Bucla (colectat, taiat, vandut; [D56] topit, fier vandut) -> pasul buclei.
-- Cumparare sau nivel CU banii in mana -> obiectul. FARA bani -> ce face banii: daca vin deja din gramada
-- tavernei, asteptarea; altfel pasul buclei. Alt fel de quest -> tinta lui.
local LOOP_KINDS: { [string]: boolean } = {
    collected = true,
    sawn = true,
    sold = true,
    smelted = true,
    ironSold = true,
}
-- [D65, D67] turul de mana al fiecarei ere noi: numaratorile liniilor ei, din FlowConfig ("cast", "partsSold", ...)
for _, spec in FlowConfig.LINES do
    if spec.era > 1 then
        LOOP_KINDS[spec.processedStat] = true
        if spec.soldStat ~= nil then
            LOOP_KINDS[spec.soldStat] = true
        end
    end
end

local function questGoal(s: State, quest: QuestGoal): Goal
    local kind = quest.kind
    if kind ~= nil and LOOP_KINDS[kind] then
        return GuideMath.loopStep(s, quest)
    end
    if kind == "income" then
        -- [D70, pasul k5] un pas de venit: nicio tinta in lume si niciun pret (bara NEXT ramane venitul spre prag); pasul
        -- numeste ce se mai poate urca acum cu castig (AmbitionMath sare meseriile la maxim)
        local a = s.ambition
        return {
            kind = "upgrade",
            key = `income:{quest.key}`,
            text = if a ~= nil then a.text else quest.text,
            immediate = true,
            upgradeKind = if a ~= nil then a.upgradeKind else nil,
            upgradeId = if a ~= nil then a.upgradeId else nil,
        }
    end
    if padLocked(s, quest) then
        -- [D70, pasul k5] platforma inca incuiata: sageata spre ea (cartonasul ei spune ce-i lipseste), fara pret
        return {
            kind = "goto",
            key = `locked:{quest.key}`,
            text = quest.text,
            x = quest.x,
            y = quest.y,
            immediate = true,
            padId = quest.padId,
        }
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
            if step.key == "catching" then -- [D59] mainile n-au nimic de facut: indiciul pontonului, daca il stii
                local hint = pierHint(s, price)
                if hint ~= nil then
                    return hint
                end
            end
            step.key = `earn:{quest.key}:{step.key}`
            step.price = price
            return step
        end
        return {
            kind = if kind == "level" then "upgrade" else "buy",
            key = `quest:{quest.key}`,
            text = if kind == "level" then Strings.STEP_UPGRADE else buyStepText(quest.padId),
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
    -- [D70, pasul k6] barajul se poate ridica si nu mai e niciun quest al satului: sageata spre masa Dam Plans, si cand
    -- ghidajul tace (toti oamenii angajati): e singurul pas care duce mai departe
    local plans = s.damPlans
    if plans ~= nil and s.quest == nil then
        return {
            kind = "goto",
            key = "dam_plans",
            text = Strings.PLANS_WHEN_READY, -- [verificatorul k6] „Not yet” nu e o pedeapsa
            -- [verificatorul k6] ghidajul se retrage langa masa: cardul ei se masoara din (x, y - 20), iar isGoalCard accepta
            -- SAME_PLACE. [k6-k8] Tinta ramane la baza mesei, ca inelul auriu sa stea in fata ei, nu sub ea
            x = plans.x,
            y = plans.y,
            immediate = true,
        }
    end
    if s.allCrewsHired then
        -- [D50] toti oamenii angajati: ghidajul tace de tot -- [D59] cu doua exceptii numite. Quest-ul care invata undita
        -- isi are sageata (fara ea, capitolul 2 ar cere un lucru nou fara sa arate unde). Iar cat strangi bani pentru un
        -- quest, linia NEXT poate spune indiciul pontonului: text, fara tinta.
        local silentQuest = s.quest
        if silentQuest ~= nil then
            -- [D62] ...si quest-ul care arata avizierul satului: tot un lucru nou, tot fara alta cale de a-l gasi
            -- [verificatorul k5] si pasul unui quest de venit: la baraj, toti oamenii sunt angajati cand vine „Earn 1T”, iar
            -- fara el linia NEXT n-ar spune ce sa urci
            if
                silentQuest.kind == "fished"
                or silentQuest.kind == "decor"
                or silentQuest.kind == "income"
                or silentQuest.always
            then
                return questGoal(s, silentQuest) -- [D65] `always`: roata de apa, dincolo de gardul abia cazut
            end
            local price = unaffordablePrice(s, silentQuest)
            if price ~= nil then
                return pierHint(s, price)
            end
        end
        return nil
    end
    -- 0) quest activ: are intaietate absoluta. E acelasi obiectiv pe care il scrie bannerul de sus
    -- si linia "NEXT" din HUD, deci cele doua nu se pot contrazice niciodata; pasul lui vine din stare.
    local quest = s.quest
    if quest ~= nil then
        return questGoal(s, quest)
    end

    -- a) nimic cumparat -- primul pas al oricarei sesiuni noi, gratis, mereu imediat (prima plasa e a satului)
    if inVillage(s) and boughtCount(s.pads) == 0 then
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

-- ---- indicatorul de margine [verificatorii A0, k12] ---------------------------------------------------
-- Unde sta indicatorul de margine (sageata cu eticheta, cand tinta e in afara ecranului). Locurile lui posibile sunt un
-- inel de-a lungul marginilor panzei, la `margin` (EDGE_MARGIN) de ele si cat sa ramana eticheta intreaga. Punctul firesc
-- (clampToEdge) se strange pe inel; daca acolo nu-l acopera niciun panou FIX al HUD-ului (atributul GuideBlocker: bara de
-- meniu, cifrele din stanga-sus, joystick-ul si butonul E pe telefon), ramane acolo, deci aluneca lin si pe langa colturi.
-- Altfel merge pe inel pana la primul loc liber, de o parte si de alta (si dupa colt, pe marginea vecina), si il alege pe
-- cel care arata cel mai bine spre tinta: unghiul lui vazut din mijlocul ecranului, fata de directia tintei.
-- Toast-urile, bannerele si monedele in zbor nu conteaza: sunt trecatoare si il faceau sa sara prin ecran.
-- Histerezis, ca o banda: capatul din cadrul trecut (`previous`) ramane cat nu arata cu mai mult de EDGE_BAND mai rau decat
-- celalalt; asa nu tremura langa mijlocul barei de meniu, dar nici nu ramane la capatul celalalt al ecranului.
-- `half`: jumatate din latimea etichetei; `top` / `bottom`: cat urca si cat coboara grupul fata de punctul lui.
export type EdgeQuery = {
    x: number,
    y: number,
    w: number,
    h: number,
    half: number,
    top: number,
    bottom: number,
    blockers: { Rect },
    margin: number?,
    previous: { x: number, y: number }?,
}
GuideMath.EDGE_GAP = 8
GuideMath.EDGE_KEEP = 12 -- cat de aproape de locul din cadrul trecut ca sa fie „acelasi capat”
GuideMath.EDGE_BAND = math.rad(15) -- cat de mult mai rau poate arata capatul vechi inainte sa-l lase
-- [verificatorul A0/k12, a saptea runda] eticheta indicatorului trece pe doua randuri peste latimea asta: textele lungi ale
-- ghidajului („Sack full — take the planks and iron to the Tavern”, ~500 px) acopereau altfel toata marginea de sus pe un
-- telefon mic, iar indicatorul ajungea jos, departe de tinta
GuideMath.EDGE_LABEL_MAX = 320 -- „... barrels and cable to the Relay Station” ramane pe doua randuri

-- [verificatorul A0/k12, a opta runda] INDICATORUL INTREG: cu eticheta, daca locul ei liber arata spre tinta (cel mult
-- EDGE_LABEL_OFF departe); altfel doar sageata (`q` cu half si bottom ale sagetii), la locul ei bun. Pe telefonul cel mai
-- mic, o eticheta pe doua randuri atinge si cifrele din stanga-sus, si bara de meniu, deci n-are loc sus: indicatorul ar fi
-- ajuns jos, cu 114 grade departe de tinta. Linia NEXT din HUD spune oricum acelasi text.
GuideMath.EDGE_LABEL_OFF = math.rad(60)
function GuideMath.edgeOff(x: number, y: number, q: EdgeQuery): number
    local mx, my = q.w / 2, q.h / 2
    local d = math.abs(math.atan2(y - my, x - mx) - math.atan2(q.y - my, q.x - mx)) % (2 * math.pi)
    return if d > math.pi then 2 * math.pi - d else d
end
-- `labelShown`: eticheta se vedea in cadrul trecut; ascunsa, revine abia la 10 grade sub prag (nu clipeste la prag)
function GuideMath.edgeIndicator(
    q: EdgeQuery,
    arrowOnly: EdgeQuery,
    labelShown: boolean?
): (number, number, boolean)
    local x, y = GuideMath.edgePlacement(q)
    local limit = GuideMath.EDGE_LABEL_OFF - (if labelShown == false then math.rad(10) else 0)
    local heldOff = GuideMath.edgeOff(x, y, q)
    if heldOff <= limit then
        return x, y, true
    end
    -- [a noua runda] capatul tinut de histerezis a trecut de prag: intai cel mai bun capat, fara cadrul trecut (altfel
    -- eticheta disparea un cadru, iar sageata sarea printr-un al treilea loc)
    if q.previous ~= nil then
        local fresh = table.clone(q)
        fresh.previous = nil
        local fx, fy = GuideMath.edgePlacement(fresh)
        -- [a unsprezecea runda] cel mai bun capat se ia daca e sub prag si cu cel putin 5 grade mai bun decat cel tinut. Doua
        -- capete aflate amandoua langa 60 de grade nu-si mai iau locul unul altuia la fiecare 0,3 grade (runda a zecea), iar
        -- la mersul intr-o directie eticheta nu mai dispare un cadru (pragul absolut de 50 de grade al rundei a zecea)
        local freshOff = GuideMath.edgeOff(fx, fy, q)
        if freshOff <= limit and freshOff <= heldOff - math.rad(5) then
            return fx, fy, true
        end
    end
    local ax, ay = GuideMath.edgePlacement(arrowOnly)
    return ax, ay, false
end

-- [verificatorul A0/k12, a opta runda] Cea mai ingusta latime a textului (cel mult `max`) la care ramane pe tot atatea randuri
-- cat la `max`: randuri echilibrate („Take the scrap from” / „the Scrap Shed”, nu „...the Scrap” / „Shed”) si o placa cat
-- textul. `heightAt(w)`: inaltimea textului rupt la latimea w (Theme.textHeight in joc). `lo`: de unde incepe cautarea.
function GuideMath.balancedWidth(heightAt: (number) -> number, max: number, lo: number): number
    local target = heightAt(max) + 0.5
    local a, b = math.max(1, math.min(lo, max)), max
    if heightAt(a) <= target then
        return math.ceil(a)
    end
    for _ = 1, 12 do
        local mid = (a + b) / 2
        if heightAt(mid) <= target then
            b = mid
        else
            a = mid
        end
    end
    return math.ceil(b)
end

function GuideMath.edgePlacement(q: EdgeQuery): (number, number)
    local gap = GuideMath.EDGE_GAP
    local margin = q.margin or 0
    local minX = math.min(math.max(q.half + gap, margin), q.w / 2)
    local maxX = math.max(math.min(q.w - q.half - gap, q.w - margin), q.w / 2)
    local minY = math.min(math.max(q.top + gap, margin), q.h / 2)
    local maxY = math.max(math.min(q.h - q.bottom - gap, q.h - margin), q.h / 2)
    local W, H = maxX - minX, maxY - minY
    local P = 2 * (W + H)
    local cx, cy = math.clamp(q.x, minX, maxX), math.clamp(q.y, minY, maxY)
    if P <= 0 then
        return cx, cy
    end
    -- un punct al inelului, dupa distanta parcursa din coltul din stanga-sus, in sensul acelor de ceasornic
    local function at(d: number): (number, number)
        local s = d % P
        if s < W then
            return minX + s, minY
        end
        s -= W
        if s < H then
            return maxX, minY + s
        end
        s -= H
        if s < W then
            return maxX - s, maxY
        end
        return minX, maxY - (s - W)
    end
    local function blocked(x: number, y: number): boolean
        for _, b in q.blockers do
            if
                x + q.half + gap > b.x
                and x - q.half - gap < b.x + b.w
                and y + q.bottom + gap > b.y
                and y - q.top - gap < b.y + b.h
            then
                return true
            end
        end
        return false
    end
    if not blocked(cx, cy) then
        return cx, cy
    end
    -- pozitia pe inel a punctului strans: latura e cea pe care a cazut (punctul firesc sta pe marginea panzei, deci strans
    -- pe inel atinge mereu o latura); un punct strict inauntru ia latura cea mai apropiata
    local start: number
    if cy <= minY then
        start = cx - minX
    elseif cx >= maxX then
        start = W + cy - minY
    elseif cy >= maxY then
        start = W + H + maxX - cx
    elseif cx <= minX then
        start = 2 * W + H + maxY - cy
    else
        local m = math.min(cy - minY, maxX - cx, maxY - cy, cx - minX)
        start = if m == cy - minY
            then cx - minX
            elseif m == maxX - cx then W + cy - minY
            elseif m == maxY - cy then W + H + maxX - cx
            else 2 * W + H + maxY - cy
    end
    -- [a noua runda] INTERVALELE EXACTE acoperite de panouri, pe fiecare latura a inelului (nu esantioane pe pasi: un gol de
    -- cativa pixeli era gasit sau ratat dupa faza pasului, iar indicatorul clipea). Deschise: capetele lor sunt libere.
    local spans: { { number } } = {}
    local function add(a: number, b: number, from: number, to: number)
        local lo, hi = math.max(math.min(a, b), from), math.min(math.max(a, b), to)
        if hi > lo then
            table.insert(spans, { lo, hi })
        end
    end
    for _, b in q.blockers do
        local xLo, xHi = b.x - q.half - gap, b.x + b.w + q.half + gap
        local yLo, yHi = b.y - q.bottom - gap, b.y + b.h + q.top + gap
        if minY > yLo and minY < yHi then -- sus: x creste cu s
            add(xLo - minX, xHi - minX, 0, W)
        end
        if maxX > xLo and maxX < xHi then -- dreapta: y creste cu s
            add(W + yLo - minY, W + yHi - minY, W, W + H)
        end
        if maxY > yLo and maxY < yHi then -- jos: x scade cu s
            add(W + H + maxX - xHi, W + H + maxX - xLo, W + H, 2 * W + H)
        end
        if minX > xLo and minX < xHi then -- stanga: y scade cu s
            add(2 * W + H + maxY - yHi, 2 * W + H + maxY - yLo, 2 * W + H, P)
        end
    end
    -- portiunea acoperita care contine punctul de plecare, crescuta cat se ating intervalele (si peste coltul de la 0/P)
    local lo, hi = start, start
    local grew = true
    while grew do
        grew = false
        for _, span in spans do
            for _, shift in { -P, 0, P } do
                local a, b = span[1] + shift, span[2] + shift
                if a <= hi and b >= lo and (a < lo or b > hi) then
                    lo, hi = math.min(lo, a), math.max(hi, b)
                    grew = true
                end
            end
        end
        if hi - lo >= P then
            return cx, cy -- inelul e acoperit tot: ramane la locul lui (panourile stau oricum peste el)
        end
    end
    local ahead, behind = hi, lo
    local ax, ay = at(ahead)
    local bx, by = at(behind)
    -- cat de rau arata un capat spre tinta: unghiul dintre el si directia tintei, vazute din mijlocul ecranului
    local mx, my = q.w / 2, q.h / 2
    local aim = math.atan2(q.y - my, q.x - mx)
    local function off(x: number, y: number): number
        local d = math.abs(math.atan2(y - my, x - mx) - aim) % (2 * math.pi)
        return if d > math.pi then 2 * math.pi - d else d
    end
    local da, db = off(ax, ay), off(bx, by)
    local prev = q.previous
    if prev ~= nil then
        local keep, band = GuideMath.EDGE_KEEP, GuideMath.EDGE_BAND
        if math.abs(ax - prev.x) <= keep and math.abs(ay - prev.y) <= keep and da <= db + band then
            return ax, ay
        elseif
            math.abs(bx - prev.x) <= keep
            and math.abs(by - prev.y) <= keep
            and db <= da + band
        then
            return bx, by
        end
    end
    if da < db or (da == db and ahead - start <= start - behind) then
        return ax, ay
    end
    return bx, by
end

-- ---- langa tinta: al cui card se vede [2026-09-30] ---------------------------------------------------
-- Sub NEAR_DISTANCE de tinta ghidajul se retrage (n-ar mai arata nimic util), deci acolo cardul E trebuie sa fie chiar
-- al tintei. InteractController alegea cel mai apropiat card, iar intre doua locuri ramanea o fasie fara sageata si
-- fara cardul tintei: la capatul pontonului se vedea doar barca (E te trimitea la balci in loc sa pescuiesti), la
-- avizier doar placuta rotii. Acum, langa tinta, cardul ei castiga cat e in raza lui, iar ghidajul ramane aprins cat
-- se vede cardul altui loc.
GuideMath.NEAR_DISTANCE = 70
-- Cat de aproape e punctul unui card (campul `at`) de tinta ca sa fie acelasi loc. Avizierul isi masoara cardul de
-- la 20 px mai sus decat tinta, de aici toleranta.
GuideMath.SAME_PLACE = 24

-- Esti destul de aproape de tinta cat ghidajul sa se retraga. Un pas fara loc ("save", sau fara x/y) n-are unde.
function GuideMath.nearGoal(goal: Goal?, px: number, py: number): boolean
    if goal == nil or goal.kind == "save" or goal.x == nil or goal.y == nil then
        return false
    end
    local dx, dy = px - (goal.x :: number), py - (goal.y :: number)
    return math.sqrt(dx * dx + dy * dy) < GuideMath.NEAR_DISTANCE
end

-- Cardul masurat din (x, y) e chiar al locului tintei: inelul unui atelier, usa, pontonul, avizierul, plasa din care
-- culegi. O platforma de cumparat (padId) n-are card E: cartonasul ei e al PadController.
function GuideMath.isGoalCard(goal: Goal?, x: number, y: number): boolean
    if goal == nil or goal.padId ~= nil or goal.x == nil or goal.y == nil then
        return false
    end
    return math.abs(x - (goal.x :: number)) <= GuideMath.SAME_PLACE
        and math.abs(y - (goal.y :: number)) <= GuideMath.SAME_PLACE
end

export type CardCandidate = {
    distance: number,
    at: { x: number, y: number }?,
    content: boolean, -- are ce arata: actiune, stare sau Upgrade
    holds: boolean?, -- o treaba in curs tine tasta E (undita aruncata)
    urgent: boolean?, -- ceva trecator (darul de pe rau)
}

-- Care card E se vede, si de ce. In ordine:
--   "urgent" -- ceva trecator (darul de pe rau, cel mai apropiat): trece pe langa tine o singura data, deci se ia si cat
--             pescuiesti (E il ia, iar tinut mai departe mulineaza).
--   "holds"  -- o treaba in curs tine tasta E (undita aruncata: E mulineaza); cardul nu se arata, iar E nu face altceva.
--             Fara ea, dupa aruncare castiga barca de langa ponton, iar E-ul de mulinat te ducea in balci.
--   "goal"   -- langa tinta, cardul ei, daca sursa lui l-a dat (e in raza lui) si are ce arata.
--   "near"   -- altfel, cel mai apropiat.
-- "urgent" si "goal" bat si cartonasul unei platforme mai apropiate; "near" se masoara cu el (InteractController).
function GuideMath.pickCard(
    cards: { CardCandidate },
    goal: Goal?,
    px: number,
    py: number
): (number?, string)
    local near = GuideMath.nearGoal(goal, px, py)
    local best: number? = nil
    local urgent: number? = nil
    local holds: number? = nil
    local own: number? = nil
    for i, c in cards do
        if c.holds and holds == nil then
            holds = i
        end
        if
            c.urgent
            and c.content
            and (urgent == nil or c.distance < cards[urgent :: number].distance)
        then
            urgent = i
        end
        local at = c.at
        if
            own == nil
            and near
            and c.content
            and at ~= nil
            and GuideMath.isGoalCard(goal, at.x, at.y)
        then
            own = i
        end
        if best == nil or c.distance < cards[best :: number].distance then
            best = i
        end
    end
    if urgent ~= nil then
        return urgent, "urgent"
    elseif holds ~= nil then
        return holds, "holds"
    elseif own ~= nil then
        return own, "goal"
    end
    return best, "near"
end

-- Langa o platforma-tinta, cartonasul ei de cumparare bate cardul unui obiect mai apropiat (usa unui vanzator, la
-- 129 px de coliba meseriei): E cumpara ce arata ghidajul.
function GuideMath.padIsGoal(goal: Goal?, px: number, py: number, padId: string?): boolean
    return padId ~= nil and goal ~= nil and goal.padId == padId and GuideMath.nearGoal(goal, px, py)
end

return GuideMath
