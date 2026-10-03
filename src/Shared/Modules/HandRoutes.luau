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
local WorldConfig =
    require(script and script.Parent.Parent.Config.WorldConfig or "../Config/WorldConfig")
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
-- [D70] CONTEXTUL in care merg oamenii: liniile (FlowConfig.GAME sau FULL), meseriile lor, locurile de pe harta si pe ce
-- drumuri se merge. Fiecare functie primeste la coada un context optional; fara el, al jocului, ca inainte. Testele cu
-- locuri inventate dau `roads = false`: drum drept. [pasul j8] `roads`: graful lumii (RoadGraph.forWorld), `true` = al
-- lumii 1 (cum era), `false` = drum drept.
export type Context = {
    flow: FlowConfig.Model,
    jobs: { [string]: Job },
    linePlaces: { [string]: TycoonConfig.LinePlaces },
    joinPlaces: { [string]: TycoonConfig.JoinPlaces },
    sellerPlaces: { [string]: TycoonConfig.SellerPlaces },
    roads: RoadGraph.Graph | boolean,
}
-- [D70] Meseria unui pas: StationConfig.STEP_JOBS (`job` cand e scrisa, ca la pasii unirii: Relay Keeper-ul sta,
-- Pylon Runner-ul duce; altfel dupa pozitie, ca in Erele 1-3), verificata la incarcare.
local function jobsFrom(lineOrder: { string }, sellerOrder: { string }): { [string]: Job }
    local out: { [string]: Job } = {}
    for _, line in lineOrder do
        local jobs = StationConfig.STEP_JOBS[line]
        for i, step in StationConfig.LINES[line].steps do
            out[step.role] = { line = line, job = jobs[i] }
        end
    end
    for _, seller in sellerOrder do
        out[StationConfig.SELLERS[seller].role] = { seller = seller, job = "sell" }
    end
    return out
end

function HandRoutes.context(
    flow: FlowConfig.Model,
    linePlaces: { [string]: TycoonConfig.LinePlaces },
    joinPlaces: { [string]: TycoonConfig.JoinPlaces },
    sellerPlaces: { [string]: TycoonConfig.SellerPlaces },
    roads: RoadGraph.Graph | boolean
): Context
    return {
        flow = flow,
        jobs = jobsFrom(flow.lineOrder, flow.sellerOrder),
        linePlaces = linePlaces,
        joinPlaces = joinPlaces,
        sellerPlaces = sellerPlaces,
        roads = roads,
    }
end
-- Contextul jocului: erele din joc (StationConfig.ENGINE_ERAS), locurile de pe harta, drumurile. Barajul n-are inca locuri.
local GAME = HandRoutes.context(
    FlowConfig.GAME,
    TycoonConfig.LINE_PLACES,
    TycoonConfig.JOIN_PLACES,
    TycoonConfig.SELLER_PLACES,
    true
)
HandRoutes.GAME = GAME

-- [D70, pasul j8] Contextul fiecarei lumi: lumea 1 e al jocului (acelasi obiect); lumea 2, barajul, cu toate liniile scrise
-- (FlowConfig.FULL: cat Era 4 doarme, GAME n-o are), locurile si drumurile ei. Facut la prima cerere.
local worldContexts: { [number]: Context } = { [1] = GAME }
function HandRoutes.forWorld(w: number?): Context
    local world = WorldConfig.sanitize(w)
    local ctx = worldContexts[world]
    if ctx == nil then
        ctx = HandRoutes.context(
            FlowConfig.FULL,
            TycoonConfig.linePlacesOf(world),
            TycoonConfig.joinPlacesOf(world),
            TycoonConfig.sellerPlacesOf(world),
            RoadGraph.forWorld(world)
        )
        worldContexts[world] = ctx
    end
    return ctx :: Context
end
-- Lumea in care lucreaza o meserie: a erei ei (veteranii barajului au meserii ale Erei 4, deci lucreaza in lumea 2).
function HandRoutes.worldOfRole(role: string): number
    return WorldConfig.worldOfEra(StationConfig.ERA_OF_ROLE[role] or 1)
end
function HandRoutes.forRole(role: string): Context
    return HandRoutes.forWorld(HandRoutes.worldOfRole(role))
end

function HandRoutes.jobOf(role: string, w: Context?): Job?
    return (w or GAME).jobs[role]
end

-- Unde lasa fiecare meserie de drum ce duce, la CAPATUL drumului: un loc din FlowConfig sau un vanzator.
function HandRoutes.endPlace(role: string, w: Context?): string?
    local ctx = w or GAME
    local j = ctx.jobs[role]
    if j == nil or j.line == nil then
        return nil
    end
    local flow = ctx.flow.lines[j.line]
    if j.job == "collect" then
        return flow.store
    elseif j.job == "port" then
        return flow.processor
    elseif j.job == "haul" then
        -- [D70] o piesa nu se vinde: merge la atelierul unirii ei (Relay-ul)
        local into = flow.into
        if into ~= nil then
            return ctx.flow.lines[into].processor
        end
        return flow.seller
    end
    return nil
end

function HandRoutes.isWalker(role: string, w: Context?): boolean
    return HandRoutes.endPlace(role, w) ~= nil
end

-- [D56] Ce fel de plase goleste o meserie de culegator: Collector-ul pe cele de lemn, Scrap Collector-ul pe cea de
-- scrap, [D65] Mill Collector-ul pe ale Morii, Ore Collector-ul pe cea de minereu. nil = meseria nu goleste plase.
function HandRoutes.netKindOf(role: string, w: Context?): string?
    local j = (w or GAME).jobs[role]
    if j == nil or j.line == nil or j.job ~= "collect" then
        return nil
    end
    return StationConfig.LINES[j.line].netKind
end

-- De unde ia un om la o oprire care nu e plasa: numele opririi e chiar locul din FlowConfig (magazia liniei sau
-- iesirea atelierului ei). nil = oprirea e o plasa.
function HandRoutes.takePlace(stopId: string, w: Context?): string?
    local flow = (w or GAME).flow
    if flow.byStore[stopId] ~= nil or flow.byOutput[stopId] ~= nil then
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
    role: string?,
    w: Context?
): { string }
    local kind = HandRoutes.netKindOf(role or "collector", w) or "wood"
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
-- curtea gaterului), deci cheile sunt putine: fiecare drum se cauta o singura data. [D70, pasul j8] Cate o memorie pe
-- graf (pe lume): aceleasi coordonate pot fi alt drum pe alta harta.
local viaCaches: { [RoadGraph.Graph]: { [string]: { HandMath.Point } } } = {}
local function viaBetween(
    graph: RoadGraph.Graph,
    from: HandMath.Point,
    to: HandMath.Point
): { HandMath.Point }
    local viaCache = viaCaches[graph]
    if viaCache == nil then
        viaCache = {}
        viaCaches[graph] = viaCache
    end
    local key = `{from.x},{from.y}>{to.x},{to.y}`
    local cached = viaCache[key]
    if cached ~= nil then
        return cached
    end
    local points = RoadGraph.route(graph, from, to)
    local via: { HandMath.Point } = {}
    for i = 2, #points - 1 do
        table.insert(via, points[i])
    end
    viaCache[key] = via
    return via
end

-- O ruta pe drumuri: fiecare oprire isi primeste drumul de la locul dinainte, iar capatul pe cel
-- de la ultima oprire. `face` = incotro sta omul la capat (spre gramada unde lasa). [D70] `roads = false`: drum drept.
local function onRoads(
    stops: { HandMath.Stop },
    endpoint: HandMath.Point,
    face: string?,
    roads: RoadGraph.Graph | boolean
): Route
    local graph: RoadGraph.Graph? = if roads == true
        then RoadGraph.fromConfig()
        elseif roads == false then nil
        else roads :: RoadGraph.Graph
    local function via(from: HandMath.Point, to: HandMath.Point): { HandMath.Point }
        return if graph ~= nil then viaBetween(graph, from, to) else {}
    end
    local here = endpoint
    for _, s in stops do
        local at = { x = s.x, y = s.y }
        s.via = via(here, at)
        here = at
    end
    local back = if #stops > 0 then via(here, endpoint) else nil
    return { stops = stops, endpoint = endpoint, returnVia = back, face = face }
end

-- Drumul unei meserii de drum [D49, D56, D65]: opririle (de luat) si capatul (unde lasa). Locurile vin din
-- TycoonConfig.LINE_PLACES / SELLER_PLACES, numele opririlor din FlowConfig (serverul stie din ele de unde ia).
-- [D70] nil si pentru o linie fara loc pe harta (barajul, pana la harta lui).
function HandRoutes.routeFor(
    role: string,
    index: number,
    count: number,
    ownedNetIds: { string },
    w: Context?
): Route?
    local ctx = w or GAME
    local j = ctx.jobs[role]
    if j == nil or j.line == nil then
        return nil
    end
    local flow = ctx.flow.lines[j.line]
    if j.job == "collect" or j.job == "port" then
        local places = ctx.linePlaces[j.line]
        if places == nil then
            return nil
        end
        if j.job == "collect" then
            local stops: { HandMath.Stop } = {}
            for _, id in HandRoutes.collectorNets(ownedNetIds, index, count, role, ctx) do
                local pad = TycoonConfig.byId[id]
                if pad ~= nil and pad.x ~= nil and pad.y ~= nil then
                    -- la plasa sta cu roaba spre dreapta, pe punte
                    table.insert(
                        stops,
                        stop({ x = pad.x :: number, y = pad.y :: number }, id, "right")
                    )
                end
            end
            -- la magazie rastoarna spre dreapta, unde e gramada ei [D57: magazia e in dreapta aleii]
            return onRoads(stops, point(places.storeStand), "right", ctx.roads)
        end
        -- ia de la magazie (gramada in dreapta), lasa la gramada de la intrarea atelierului (in dreapta capatului)
        return onRoads(
            { stop(places.storeStand, flow.store :: string, "right") },
            point(places.processorIn),
            "right",
            ctx.roads
        )
    elseif j.job == "haul" then
        -- ia marfa gata din dreapta atelierului (gramada in stanga opririi): al liniei, sau al unirii (Pylon Runner-ul)
        local line = ctx.linePlaces[j.line]
        local union = ctx.joinPlaces[j.line]
        local out = if line ~= nil
            then line.processorOut
            elseif union ~= nil then union.processorOut
            else nil
        if out == nil then
            return nil
        end
        local pickUp = { stop(out, flow.output, "left") }
        local into = flow.into
        if into ~= nil then
            -- [D70] o piesa: la intrarea ei in Relay, cu fata spre gramada ei
            local join = ctx.joinPlaces[into]
            local drop = if join ~= nil then join.inputIn[j.line] else nil
            if join == nil or drop == nil then
                return nil
            end
            local pile = join.inPiles[j.line]
            local face = if pile ~= nil and pile.x < drop.x then "left" else "right"
            return onRoads(pickUp, point(drop), face, ctx.roads)
        end
        -- o lasa la usa vanzatorului
        local seller = ctx.sellerPlaces[flow.seller :: string]
        if seller == nil then
            return nil
        end
        return onRoads(pickUp, point(seller.door), "left", ctx.roads)
    end
    return nil
end

-- Ciclul unui om; gol (durata 0) pentru cine nu merge sau n-are inca pe unde.
function HandRoutes.cycleFor(
    role: string,
    index: number,
    count: number,
    ownedNetIds: { string },
    w: Context?
): HandMath.Cycle
    local route = HandRoutes.routeFor(role, index, count, ownedNetIds, w)
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
-- Al doilea sta alaturi (`secondOffset`). [D70] Relay Keeper-ul sta la Relay (locurile unirii); nil fara loc pe harta.
function HandRoutes.standFor(role: string, index: number, w: Context?): HandMath.Point?
    local ctx = w or GAME
    local j = ctx.jobs[role]
    if j == nil then
        return nil
    end
    local stand, offset
    if j.job == "work" and j.line ~= nil then
        local line = ctx.linePlaces[j.line]
        local union = ctx.joinPlaces[j.line]
        if line ~= nil then
            stand, offset = line.workerStand, line.secondOffset
        elseif union ~= nil then
            stand, offset = union.workerStand, union.secondOffset
        else
            return nil
        end
    elseif j.job == "sell" and j.seller ~= nil then
        local places = ctx.sellerPlaces[j.seller]
        if places == nil then
            return nil
        end
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
