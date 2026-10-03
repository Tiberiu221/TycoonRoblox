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

local function cottagesOf(): { TycoonConfig.Box }
    local world = TycoonConfig.WORLDS[DamTown.WORLD]
    return if world ~= nil then world.cottages or {} else {}
end

-- [verificatorii k10b] CINE STA UNDE: cate 5-6 oameni pe o casuta si 4 locuri pentru 16 oameni. Fiecare om isi are locul
-- lui la usa (cinci locuri de-a lungul casutei, apoi al doilea rand) si la oprire (trei, dupa casuta lui), iar casuta si
-- locul se aleg cu pasi diferiti, ca doi oameni sa nu faca acelasi drum. Inainte, oamenii 4 si 16 mergeau lipiti si 4-5
-- stateau pe acelasi pixel la usa.
local DOOR_STEP, DOOR_ROW, SPOT_STEP, SPOT_ROW = 20, 14, 18, 14

-- Usa casutei omului `index` (casutele, pe rand): spre strada, intre ea si acoperis, ca drumul spre oras sa mearga pe
-- strada si pe alee, nu peste iarba cu decor.
function DamTown.home(index: number): HandMath.Point
    local cottages = cottagesOf()
    if #cottages == 0 then
        return { x = 0, y = 0 }
    end
    local c = cottages[(index - 1) % #cottages + 1]
    local k = (index - 1) // #cottages -- al catelea om al casutei
    local row = k // 5 -- al doilea rand sta mai sus si intre locurile primului
    return {
        x = c.x + (k % 5 - 2) * DOOR_STEP + row * DOOR_STEP / 2,
        y = c.y - c.h - 18 - row * DOOR_ROW,
    }
end

-- Locul omului `index`: casuta se schimba la fiecare om, locul la fiecare casuta umpluta, iar cei trei vecini de casuta
-- care merg la acelasi loc stau unul langa altul.
function DamTown.spotOf(index: number): { x: number, y: number, face: string }
    local n = math.max(1, #cottagesOf())
    local k = (index - 1) // n
    local spot = DamTown.SPOTS[k % #DamTown.SPOTS + 1]
    -- dupa ce s-au umplut toate locurile, urmatorii stau pe un al doilea rand, putin mai jos
    local row = k // #DamTown.SPOTS
    return {
        x = spot.x + ((index - 1) % n - (n - 1) / 2) * SPOT_STEP,
        y = spot.y + row * SPOT_ROW,
        face = spot.face,
    }
end

-- Plimbarea omului `index`: de acasa la locul lui, pe drumuri, si inapoi.
function DamTown.cycle(index: number): HandMath.Cycle
    local home = DamTown.home(index)
    local spot = DamTown.spotOf(index)
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

-- De cand merge ceasul plimbarii omului `index` (decalat, ca oamenii sa nu plece toti deodata). [verificatorii k10b] Pe
-- fractia de aur a ciclului: doi oameni cu acelasi drum pleaca la o fractiune buna de ciclu unul de altul, nu la 0,9 s.
function DamTown.phase(index: number, duration: number): number
    if duration <= 0 then
        return 0
    end
    return ((index * 0.6180339887) % 1) * duration
end

return DamTown
