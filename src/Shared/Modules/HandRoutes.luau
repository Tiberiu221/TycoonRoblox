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
local FlowConfig =
    require(script and script.Parent.Parent.Config.FlowConfig or "../Config/FlowConfig")
local StationConfig =
    require(script and script.Parent.Parent.Config.StationConfig or "../Config/StationConfig")

local HandRoutes = {}

export type Route = {
    stops: { HandMath.Stop },
    endpoint: HandMath.Point,
    returnVia: { HandMath.Point }?,
    face: string?,
}

-- `padId` pe opririle care nu sunt plase: serverul stie din el de unde ia.
-- [D65] Numele sunt chiar locurile din FlowConfig (magazia unei linii, iesirea atelierului ei): vezi `takePlace`.
HandRoutes.STORAGE_STOP = FlowConfig.LINES.wood.store
HandRoutes.PLANKS_STOP = FlowConfig.LINES.wood.output
HandRoutes.SHED_STOP = FlowConfig.LINES.iron.store -- [D55] Scrap Porter-ul ia de aici
HandRoutes.IRON_STOP = FlowConfig.LINES.iron.output -- [D55] fierul de la forja, pentru Iron Hauler

-- [D55] Plasa de scrap a Erei 1 (singura). Din config, ca serverul si clientul sa stie aceeasi.
local scrapNet: string? = nil
for _, p in TycoonConfig.PADS do
    if p.era == 1 and TycoonMath.netKind(p) == "scrap" then
        scrapNet = p.id
        break
    end
end
HandRoutes.SCRAP_NET = scrapNet

-- [D65] CE FACE FIECARE MESERIE, din tabelul liniilor (StationConfig.LINES) si din drumul marfii (FlowConfig). Pe
-- fiecare linie pasii sunt aceiasi: primul om goleste plasele liniei la magazia ei, al doilea cara de la magazie la
-- atelier, al treilea sta la atelier, al patrulea cara marfa gata la vanzator. Pana la D65 erau trei tabele mici si un
-- `elseif` pe fiecare meserie; Era 2 ar fi dublat totul.
--   job = "collect" | "port" | "work" | "haul"; vanzatorii au meseria lor ("sell"), tot statica.
export type Job = { line: string?, seller: string?, job: string }
local JOB_OF_STEP = { "collect", "port", "work", "haul" }
local jobs: { [string]: Job } = {}
for _, line in StationConfig.LINE_ORDER do
    for i, step in StationConfig.LINES[line].steps do
        jobs[step.role] = { line = line, job = JOB_OF_STEP[i] }
    end
end
for _, seller in StationConfig.SELLER_ORDER do
    jobs[StationConfig.SELLERS[seller].role] = { seller = seller, job = "sell" }
end
function HandRoutes.jobOf(role: string): Job?
    return jobs[role]
end

-- Unde lasa fiecare meserie de drum ce duce, la CAPATUL drumului: un loc din FlowConfig sau un vanzator.
function HandRoutes.endPlace(role: string): string?
    local j = jobs[role]
    if j == nil or j.line == nil then
        return nil
    end
    local flow = FlowConfig.LINES[j.line]
    if j.job == "collect" then
        return flow.store
    elseif j.job == "port" then
        return flow.processor
    elseif j.job == "haul" then
        return flow.seller
    end
    return nil
end

function HandRoutes.isWalker(role: string): boolean
    return HandRoutes.endPlace(role) ~= nil
end

-- [D56] Ce fel de plase goleste o meserie de culegator: Collector-ul pe cele de lemn, Scrap Collector-ul pe cea de
-- scrap, [D65] Mill Collector-ul pe ale Morii, Ore Collector-ul pe cea de minereu. nil = meseria nu goleste plase.
function HandRoutes.netKindOf(role: string): string?
    local j = jobs[role]
    if j == nil or j.line == nil or j.job ~= "collect" then
        return nil
    end
    return StationConfig.LINES[j.line].netKind
end

-- De unde ia un om la o oprire care nu e plasa: numele opririi e chiar locul din FlowConfig (magazia liniei sau
-- iesirea atelierului ei). nil = oprirea e o plasa.
function HandRoutes.takePlace(stopId: string): string?
    if FlowConfig.BY_STORE[stopId] ~= nil or FlowConfig.BY_OUTPUT[stopId] ~= nil then
        return stopId
    end
    return nil
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
    local kind = HandRoutes.netKindOf(role or "collector") or "wood"
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

-- Drumul unei meserii de drum [D49, D56, D65]: opririle (de luat) si capatul (unde lasa). Locurile vin din
-- TycoonConfig.LINE_PLACES / SELLER_PLACES, numele opririlor din FlowConfig (serverul stie din ele de unde ia).
function HandRoutes.routeFor(
    role: string,
    index: number,
    count: number,
    ownedNetIds: { string }
): Route?
    local j = jobs[role]
    if j == nil or j.line == nil then
        return nil
    end
    local places = TycoonConfig.LINE_PLACES[j.line]
    local flow = FlowConfig.LINES[j.line]
    if j.job == "collect" then
        local stops: { HandMath.Stop } = {}
        for _, id in HandRoutes.collectorNets(ownedNetIds, index, count, role) do
            local pad = TycoonConfig.byId[id]
            if pad ~= nil and pad.x ~= nil and pad.y ~= nil then
                -- la plasa sta cu roaba spre dreapta, pe punte
                table.insert(stops, stop({ x = pad.x :: number, y = pad.y :: number }, id, "right"))
            end
        end
        -- la magazie rastoarna spre dreapta, unde e gramada ei [D57: magazia e in dreapta aleii]
        return onRoads(stops, point(places.storeStand), "right")
    elseif j.job == "port" then
        -- ia de la magazie (gramada in dreapta), lasa la gramada de la intrarea atelierului (in dreapta capatului)
        return onRoads(
            { stop(places.storeStand, flow.store, "right") },
            point(places.processorIn),
            "right"
        )
    elseif j.job == "haul" then
        -- ia marfa gata din dreapta atelierului (gramada in stanga opririi), o lasa la usa vanzatorului
        local door = TycoonConfig.SELLER_PLACES[flow.seller].door
        return onRoads({ stop(places.processorOut, flow.output, "left") }, point(door), "left")
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

-- Locul unui om static [D56, D65]: omul atelierului langa atelierul liniei lui, omul vanzatorului la tejgheaua lui.
-- Al doilea sta alaturi (`secondOffset`).
function HandRoutes.standFor(role: string, index: number): HandMath.Point?
    local j = jobs[role]
    if j == nil then
        return nil
    end
    local stand, offset
    if j.job == "work" and j.line ~= nil then
        local places = TycoonConfig.LINE_PLACES[j.line]
        stand, offset = places.workerStand, places.secondOffset
    elseif j.job == "sell" and j.seller ~= nil then
        local places = TycoonConfig.SELLER_PLACES[j.seller]
        stand, offset = places.stand, places.secondOffset
    else
        return nil
    end
    if index > 1 then
        return { x = stand.x + offset.x, y = stand.y + offset.y }
    end
    return point(stand)
end

return HandRoutes
