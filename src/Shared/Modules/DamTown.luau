--!strict
-- [D70, pasul k10] DAM TOWN, pur: cladirile orasului (Canteen, clopotnita cu clopotele vechi, Memory Wall, casutele) si
-- plimbarea oamenilor iesiti din lucru. Fiecare om retras pleaca de la usa casutei lui spre un loc al orasului (piata din
-- fata Canteen-ului, Memory Wall, clopotnita, strada) pe drumurile lumii 2 (RoadGraph), sta, apoi se intoarce acasa. Pur si
-- determinist: acelasi om face aceeasi plimbare pe orice client, iar testul verifica drumurile (fara decor, fara apa).
local HandMath = require(script and script.Parent.HandMath or "./HandMath")
local RoadGraph = require(script and script.Parent.RoadGraph or "./RoadGraph")
local TycoonConfig =
    require(script and script.Parent.Parent.Config.TycoonConfig or "../Config/TycoonConfig")

local DamTown = {}

DamTown.WORLD = 2
-- mersul unui om la plimbare: mai incet decat al celor care lucreaza, cu opriri lungi
DamTown.STROLL = { speed = 36, pauseNet = 7, pauseDock = 9 } :: HandMath.RunnerConfig
-- Cati se plimba deodata: ceilalti stau in casa (pagina „Your people” ii arata pe toti).
DamTown.MAX_WALKERS = 16
-- unde se opresc, in coordonatele lumii 2: pe iarba si pe piata, departe de decorul cumparat (World2Decor)
DamTown.SPOTS = {
    { x = 395, y = 1140, face = "up" }, -- piata, in fata Canteen-ului
    { x = 760, y = 1400, face = "up" }, -- Memory Wall
    { x = 800, y = 1012, face = "up" }, -- clopotnita
    { x = 470, y = 1452, face = "down" }, -- strada, langa ghirlande
} :: { { x: number, y: number, face: string } }

-- Cladirile orasului din WORLDS[2].buildings, cu numele de pe harta (textele avizierului le folosesc: „Beside the Canteen”,
-- „Beside the Memory Wall”).
export type Building = { key: string, x: number, y: number, w: number, h: number, label: string }
DamTown.LABELS = { canteen = "Canteen", bellTower = "Old Bells", memoryWall = "Memory Wall" } :: {
    [string]: string,
}
function DamTown.buildings(): { Building }
    local world = TycoonConfig.WORLDS[DamTown.WORLD]
    local out: { Building } = {}
    local spots = if world ~= nil then world.buildings or {} else {}
    for _, key in { "canteen", "bellTower", "memoryWall" } do
        local b = spots[key]
        if b ~= nil then
            table.insert(
                out,
                { key = key, x = b.x, y = b.y, w = b.w, h = b.h, label = DamTown.LABELS[key] }
            )
        end
    end
    return out
end

-- Usa casutei omului `index` (casutele, pe rand): spre strada, intre ea si acoperis, ca drumul spre oras sa mearga pe
-- strada si pe alee, nu peste iarba cu decor.
function DamTown.home(index: number): HandMath.Point
    local world = TycoonConfig.WORLDS[DamTown.WORLD]
    local cottages = if world ~= nil then world.cottages or {} else {}
    if #cottages == 0 then
        return { x = 0, y = 0 }
    end
    local c = cottages[(index - 1) % #cottages + 1]
    return { x = c.x, y = c.y - c.h - 18 }
end

-- Plimbarea omului `index`: de acasa la locul lui, pe drumuri, si inapoi.
function DamTown.cycle(index: number): HandMath.Cycle
    local home = DamTown.home(index)
    local spot = DamTown.SPOTS[(index - 1) % #DamTown.SPOTS + 1]
    local g = RoadGraph.forWorld(DamTown.WORLD)
    local there = RoadGraph.route(g, home, { x = spot.x, y = spot.y }, true)
    local via: { HandMath.Point } = {}
    for i = 2, #there - 1 do
        table.insert(via, there[i])
    end
    local back = RoadGraph.route(g, { x = spot.x, y = spot.y }, home, true)
    local returnVia: { HandMath.Point } = {}
    for i = 2, #back - 1 do
        table.insert(returnVia, back[i])
    end
    return HandMath.cycle(
        { { x = spot.x, y = spot.y, padId = "stroll", via = via, face = spot.face } },
        home,
        DamTown.STROLL,
        returnVia,
        "down"
    )
end

-- Bonusul clopotelor satului vechi (Landing, Mill, Works), in procente: placa clopotnitei il scrie. Din efectele lor
-- (`bells`), nu scris de mana [CLAUDE.md: efectele nu se ghicesc].
function DamTown.bellsPercent(): number
    local factor = 1
    for _, p in TycoonConfig.padsOfWorld(1) do
        if p.motive == "D" then
            for _, e in p.effects do
                if e.kind == "mul" and e.field == "bells" and e.factor ~= nil then
                    factor *= e.factor :: number
                end
            end
        end
    end
    return math.floor((factor - 1) * 100 + 0.5)
end

-- De cand merge ceasul plimbarii omului `index` (decalat, ca oamenii sa nu plece toti deodata).
function DamTown.phase(index: number, duration: number): number
    if duration <= 0 then
        return 0
    end
    return (index * 7.3) % duration
end

return DamTown
