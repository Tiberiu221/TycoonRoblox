--!strict
-- Unde merge fiecare om care cara [D49]. Modul PUR, acelasi pe server (care muta marfa la sosire) si
-- pe client (care il deseneaza mergand): ce vezi pe mal e exact ce se intampla in cifre.
--
--   Collector:       plasele de lemn -> depozit
--   Porter:          depozit -> intrarea gaterului
--   Hauler:          iesirea gaterului -> taverna
-- [D56] LINIA FIERULUI, cu oamenii ei, pe aceiasi pasi:
--   Scrap Collector: plasa de scrap -> shed
--   Scrap Porter:    shed -> gramada de topit a forjei
--   Iron Hauler:     gramada de fier a forjei -> taverna
-- In D55 aceiasi trei oameni duceau si scrap-ul, pe drumuri mai lungi; owner-ul n-a vazut pe nimeni ocupandu-se
-- de el. Drumul nu depinde de gramezi -- CAT se ia la fiecare oprire decide serverul (HandService).
--
-- HandMath.cycle porneste de la capat, trece pe la opriri (evenimentul "collect" = ia) si se intoarce
-- la capat ("sell" = lasa). Un ciclu fara nicio oprire e gol, deci o naveta are exact O oprire.
-- Sawyer-ul, Smelter-ul si Negustorul nu merg nicaieri: au doar un loc (`standFor`).
--
-- [D50] Oamenii merg pe drumuri, nu in linie dreapta peste cladiri: intre doua opriri trec prin
-- punctele din RoadGraph. Cat duce un om pe drum ramane debit x durata (`loadFor`), deci un drum mai
-- lung nu schimba cifra din meniu -- doar cat de des il vezi trecand.
local HandMath = require(script and script.Parent.HandMath or "./HandMath")
local RoadGraph = require(script and script.Parent.RoadGraph or "./RoadGraph")
local TycoonConfig =
    require(script and script.Parent.Parent.Config.TycoonConfig or "../Config/TycoonConfig")
local TycoonMath = require(script and script.Parent.TycoonMath or "./TycoonMath")

local HandRoutes = {}

export type Route = {
    stops: { HandMath.Stop },
    endpoint: HandMath.Point,
    returnVia: { HandMath.Point }?,
    face: string?,
}

-- `padId` pe opririle care nu sunt plase: serverul stie din el de unde ia.
HandRoutes.STORAGE_STOP = "storage"
HandRoutes.PLANKS_STOP = "planks"
HandRoutes.SHED_STOP = "shed" -- [D55] Scrap Porter-ul ia de aici
HandRoutes.IRON_STOP = "iron" -- [D55] fierul de la forja, pentru Iron Hauler

-- [D55] Plasa de scrap a Erei 1 (singura). Din config, ca serverul si clientul sa stie aceeasi.
local scrapNet: string? = nil
for _, p in TycoonConfig.PADS do
    if p.era == 1 and TycoonMath.netKind(p) == "scrap" then
        scrapNet = p.id
        break
    end
end
HandRoutes.SCRAP_NET = scrapNet

-- Unde lasa fiecare meserie ce duce, la CAPATUL drumului.
local END_PLACE: { [string]: string } = {
    collector = "storage",
    porter = "sawmill",
    hauler = "dock",
    scrapCollector = "shed", -- [D56]
    scrapPorter = "forge",
    ironHauler = "dock",
}
function HandRoutes.endPlace(role: string): string?
    return END_PLACE[role]
end

function HandRoutes.isWalker(role: string): boolean
    return END_PLACE[role] ~= nil
end

-- [D56] Ce fel de plase goleste o meserie de culegator: Collector-ul pe cele de lemn, Scrap Collector-ul pe cea de
-- scrap. nil = meseria nu goleste plase.
local NET_KIND_OF: { [string]: string } = { collector = "wood", scrapCollector = "scrap" }
function HandRoutes.netKindOf(role: string): string?
    return NET_KIND_OF[role]
end

-- Plasele culegatorului cu numarul `index` din `count`: plasele detinute de felul lui, in grupuri consecutive cat
-- mai egale, ca fiecare sa mearga pe bucata lui de mal. Unul singur le ia pe TOATE -- in D46 un alergator avea doar
-- primele trei, dar debitul unei meserii nu depinde de cate plase are [D49]. Fara `role`, Collector-ul (lemnul).
function HandRoutes.collectorNets(
    ownedNetIds: { string },
    index: number,
    count: number,
    role: string?
): { string }
    local kind = NET_KIND_OF[role or "collector"] or "wood"
    local mine: { string } = {}
    for _, id in ownedNetIds do
        local pad = TycoonConfig.byId[id]
        if pad ~= nil and TycoonMath.netKind(pad) == kind then
            table.insert(mine, id)
        end
    end
    local people = math.max(1, count)
    local per = math.max(1, math.ceil(#mine / people))
    local group = HandMath.runnerNets(mine, index, per)
    -- [D56] mai multi oameni decat plase (doi Scrap Collectori pe singura plasa de scrap): trec toti pe la toate,
    -- altfel al doilea ar sta pe loc
    if #group == 0 then
        return mine
    end
    return group
end

local function point(p: { x: number, y: number }): HandMath.Point
    return { x = p.x, y = p.y }
end

local function stop(
    p: { x: number, y: number },
    padId: string,
    face: string,
    drop: boolean?
): HandMath.Stop
    return { x = p.x, y = p.y, padId = padId, face = face, drop = drop }
end

-- Punctele de pe drum dintre doua locuri, fara capete. Locurile sunt toate din config (plase, usi,
-- curtea gaterului), deci cheile sunt putine: fiecare drum se cauta o singura data.
local viaCache: { [string]: { HandMath.Point } } = {}
local function viaBetween(from: HandMath.Point, to: HandMath.Point): { HandMath.Point }
    local key = `{from.x},{from.y}>{to.x},{to.y}`
    local cached = viaCache[key]
    if cached ~= nil then
        return cached
    end
    local points = RoadGraph.route(RoadGraph.fromConfig(), from, to)
    local via: { HandMath.Point } = {}
    for i = 2, #points - 1 do
        table.insert(via, points[i])
    end
    viaCache[key] = via
    return via
end

-- O ruta pe drumuri: fiecare oprire isi primeste drumul de la locul dinainte, iar capatul pe cel
-- de la ultima oprire. `face` = incotro sta omul la capat (spre gramada unde lasa).
local function onRoads(stops: { HandMath.Stop }, endpoint: HandMath.Point, face: string?): Route
    local here = endpoint
    for _, s in stops do
        local at = { x = s.x, y = s.y }
        s.via = viaBetween(here, at)
        here = at
    end
    local back = if #stops > 0 then viaBetween(here, endpoint) else nil
    return { stops = stops, endpoint = endpoint, returnVia = back, face = face }
end

-- Drumul unei meserii de drum [D49, D56]: opririle (de luat) si capatul (unde lasa).
function HandRoutes.routeFor(
    role: string,
    index: number,
    count: number,
    ownedNetIds: { string }
): Route?
    local S = TycoonConfig
    if role == "collector" or role == "scrapCollector" then
        local stops: { HandMath.Stop } = {}
        for _, id in HandRoutes.collectorNets(ownedNetIds, index, count, role) do
            local pad = TycoonConfig.byId[id]
            if pad ~= nil and pad.x ~= nil and pad.y ~= nil then
                -- la plasa sta cu roaba spre dreapta, pe punte
                table.insert(stops, stop({ x = pad.x :: number, y = pad.y :: number }, id, "right"))
            end
        end
        if role == "scrapCollector" then
            -- la shed rastoarna spre dreapta, unde e gramada lui [D57: shed-ul e in dreapta aleii]
            return onRoads(stops, point(S.SCRAP_SHED_STAND), "right")
        end
        return onRoads(stops, point(S.STORAGE_STAND), "right")
    elseif role == "porter" then
        return onRoads(
            { stop(S.STORAGE_STAND, HandRoutes.STORAGE_STOP, "right") },
            point(S.SAWMILL_IN),
            "right"
        )
    elseif role == "hauler" then
        return onRoads(
            { stop(S.SAWMILL_OUT, HandRoutes.PLANKS_STOP, "left") },
            point(S.DOCK),
            "left"
        )
    elseif role == "scrapPorter" then
        -- [D56, D57] ia de la shed (gramada in dreapta), lasa la gramada de topit a forjei (in dreapta capatului)
        return onRoads(
            { stop(S.SCRAP_SHED_STAND, HandRoutes.SHED_STOP, "right") },
            point(S.FORGE_IN),
            "right"
        )
    elseif role == "ironHauler" then
        -- [D56] ia fierul din dreapta forjei (gramada in stanga opririi), il lasa la usa tavernei
        return onRoads({ stop(S.FORGE_OUT, HandRoutes.IRON_STOP, "left") }, point(S.DOCK), "left")
    end
    return nil
end

-- Ciclul unui om; gol (durata 0) pentru cine nu merge sau n-are inca pe unde.
function HandRoutes.cycleFor(
    role: string,
    index: number,
    count: number,
    ownedNetIds: { string }
): HandMath.Cycle
    local route = HandRoutes.routeFor(role, index, count, ownedNetIds)
    if route == nil then
        return { legs = {}, duration = 0 }
    end
    return HandMath.cycle(
        route.stops,
        route.endpoint,
        TycoonConfig.RUNNER,
        route.returnVia,
        route.face
    )
end

-- CAT DUCE UN OM PE DRUM = debitul meseriei x durata ciclului [D40, D49]: impartit la cat dureaza
-- drumul, iese exact cifra din meniu, oricat de lung ar fi traseul. Cel putin o bucata.
function HandRoutes.loadFor(rate: number, duration: number): number
    if rate <= 0 or duration <= 0 then
        return 0
    end
    return math.max(1, math.floor(rate * duration + 0.5))
end

-- Locul unui om static: Sawyer-ul in curtea gaterului, Smelter-ul langa forja [D56], Innkeeper-ul la tejgheaua
-- tavernei. Al doilea sta alaturi.
function HandRoutes.standFor(role: string, index: number): HandMath.Point?
    local stand = if role == "sawyer"
        then TycoonConfig.SAWYER_STAND
        elseif role == "smelter" then TycoonConfig.SMELTER_STAND
        elseif role == "trader" then TycoonConfig.TRADER_STAND
        else nil
    if stand == nil then
        return nil
    end
    local offset = TycoonConfig.SECOND_STAND_OFFSET[role]
    if index > 1 and offset ~= nil then
        return { x = stand.x + offset.x, y = stand.y + offset.y }
    end
    return point(stand)
end

return HandRoutes
