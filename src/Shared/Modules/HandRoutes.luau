--!strict
-- Unde merge fiecare om care cara [D49]. Modul PUR, acelasi pe server (care muta marfa la sosire) si
-- pe client (care il deseneaza mergand): ce vezi pe mal e exact ce se intampla in cifre.
--
--   Collector: plasele lui -> depozit
--   Porter:    depozit -> intrarea gaterului
--   Hauler:    iesirea gaterului -> taverna
--
-- [D55] CU RESTURILE (shed-ul, atelierul si plasa de scrap cumparate, `scrap = true`):
--   Collector: plasele lui -> shed (lasa scrap-ul, daca plasa de scrap e a lui) -> depozit (lasa lemnul)
--   Porter:    shed (ia scrap) -> depozit (ia busteni) -> gater (lasa bustenii) -> atelier (lasa scrap-ul)
--   Hauler:    atelier (ia fier) -> iesirea gaterului (ia scanduri) -> taverna
-- Ordinea opririlor e si prioritatea marfii: fierul si scrap-ul se iau intai (valoreaza mai mult), ca in
-- ChainMath. Drumul nu depinde de gramezi -- CAT se ia la fiecare oprire decide serverul (HandService).
--
-- HandMath.cycle porneste de la capat, trece pe la opriri (evenimentul "collect" = ia) si se intoarce
-- la capat ("sell" = lasa). Un ciclu fara nicio oprire e gol, deci o naveta are exact O oprire.
-- Sawyer-ul si Negustorul nu merg nicaieri: au doar un loc (`standFor`).
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

-- `padId` pe opririle care nu sunt plase: serverul stie din el de unde ia sau unde lasa.
HandRoutes.STORAGE_STOP = "storage"
HandRoutes.PLANKS_STOP = "planks"
HandRoutes.SHED_STOP = "shed" -- [D55] Collector-ul lasa aici, Porter-ul ia de aici
HandRoutes.IRON_STOP = "iron" -- [D55] fierul de la atelier, pentru Hauler
HandRoutes.SAWMILL_DROP = "sawmill" -- [D55] Porter-ul lasa bustenii inainte de atelier

-- [D55] Plasa de scrap a Erei 1 (singura). Din config, ca serverul si clientul sa stie aceeasi.
local scrapNet: string? = nil
for _, p in TycoonConfig.PADS do
    if p.era == 1 and TycoonMath.netKind(p) == "scrap" then
        scrapNet = p.id
        break
    end
end
HandRoutes.SCRAP_NET = scrapNet

-- Unde lasa fiecare meserie ce i-a ramas la CAPATUL drumului.
function HandRoutes.endPlace(role: string, scrap: boolean?): string?
    if role == "collector" then
        return "storage"
    elseif role == "porter" then
        return if scrap then "forge" else "sawmill"
    elseif role == "hauler" then
        return "dock"
    end
    return nil
end

function HandRoutes.isWalker(role: string): boolean
    return role == "collector" or role == "porter" or role == "hauler"
end

-- Plasele Collector-ului cu numarul `index` din `count`: plasele detinute, in grupuri consecutive cat
-- mai egale, ca fiecare sa mearga pe bucata lui de mal. Unul singur le ia pe TOATE -- in D46 un
-- alergator avea doar primele trei, dar debitul unei meserii nu depinde de cate plase are [D49].
function HandRoutes.collectorNets(ownedNetIds: { string }, index: number, count: number): { string }
    local people = math.max(1, count)
    local per = math.max(1, math.ceil(#ownedNetIds / people))
    return HandMath.runnerNets(ownedNetIds, index, per)
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

-- `scrap` [D55]: lantul resturilor e intreg (shed, atelier si plasa de scrap cumparate). Fara el drumurile
-- sunt exact cele de dinainte.
function HandRoutes.routeFor(
    role: string,
    index: number,
    count: number,
    ownedNetIds: { string },
    scrap: boolean?
): Route?
    local S = TycoonConfig
    if role == "collector" then
        local stops: { HandMath.Stop } = {}
        local hasScrapNet = false
        for _, id in HandRoutes.collectorNets(ownedNetIds, index, count) do
            local pad = TycoonConfig.byId[id]
            if pad ~= nil and pad.x ~= nil and pad.y ~= nil then
                -- la plasa sta cu roaba spre dreapta, pe punte
                table.insert(stops, stop({ x = pad.x :: number, y = pad.y :: number }, id, "right"))
                hasScrapNet = hasScrapNet or id == HandRoutes.SCRAP_NET
            end
        end
        if scrap and hasScrapNet then
            table.insert(stops, stop(S.SCRAP_SHED_STAND, HandRoutes.SHED_STOP, "left", true))
        end
        return onRoads(stops, point(S.STORAGE_STAND), "right")
    elseif role == "porter" then
        if scrap then
            return onRoads({
                stop(S.SCRAP_SHED_STAND, HandRoutes.SHED_STOP, "left"),
                stop(S.STORAGE_STAND, HandRoutes.STORAGE_STOP, "right"),
                stop(S.SAWMILL_IN, HandRoutes.SAWMILL_DROP, "right", true),
            }, point(S.FORGE_IN), "right")
        end
        return onRoads(
            { stop(S.STORAGE_STAND, HandRoutes.STORAGE_STOP, "right") },
            point(S.SAWMILL_IN),
            "right"
        )
    elseif role == "hauler" then
        if scrap then
            return onRoads({
                stop(S.FORGE_OUT, HandRoutes.IRON_STOP, "left"),
                stop(S.SAWMILL_OUT, HandRoutes.PLANKS_STOP, "left"),
            }, point(S.DOCK), "left")
        end
        return onRoads(
            { stop(S.SAWMILL_OUT, HandRoutes.PLANKS_STOP, "left") },
            point(S.DOCK),
            "left"
        )
    end
    return nil
end

-- Ciclul unui om; gol (durata 0) pentru cine nu merge sau n-are inca pe unde.
function HandRoutes.cycleFor(
    role: string,
    index: number,
    count: number,
    ownedNetIds: { string },
    scrap: boolean?
): HandMath.Cycle
    local route = HandRoutes.routeFor(role, index, count, ownedNetIds, scrap)
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

-- Locul unui om static: Sawyer-ul in curtea gaterului, Innkeeper-ul la tejgheaua tavernei. Al doilea
-- sta alaturi.
function HandRoutes.standFor(role: string, index: number): HandMath.Point?
    local stand = if role == "sawyer"
        then TycoonConfig.SAWYER_STAND
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
