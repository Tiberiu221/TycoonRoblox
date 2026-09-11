--!strict
-- Colonistii: stare pe server, drum calculat pe server, miscare interpolata pe client [RIVERKEEP 4.1, 4.2]
-- Serverul e autoritar (colonistii produc resurse), dar NU trimite pozitii per frame: trimite
-- waypoint-uri cand se schimba drumul, iar clientul interpoleaza intre ele [DECIZII D13].
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Grid = require(ReplicatedStorage.Shared.Modules.Grid)
local Pathfind = require(ReplicatedStorage.Shared.Modules.Pathfind)
local Prng = require(ReplicatedStorage.Shared.Modules.Prng)
local RiverConfig = require(ReplicatedStorage.Shared.Config.RiverConfig)
local SettlerConfig = require(ReplicatedStorage.Shared.Config.SettlerConfig)
local WorkshopService = require(script.Parent.WorkshopService)
local BuildService = require(script.Parent.BuildService)
local DataService = require(script.Parent.DataService)
local DevState = require(script.Parent.DevState)
local StoreService = require(script.Parent.StoreService)

local TICK_SECONDS = 0.25 -- 4 Hz: destul pentru decizii, ieftin pentru CPU
local PATHS_PER_TICK = 6 -- plafon de cautari A* per tick, ca sa nu apara varfuri de CPU
local DEBUG_COUNT_ATTR = "DebugSettlerCount" -- test de stres: workspace:SetAttribute("DebugSettlerCount", 60)

export type Settler = {
    id: number,
    name: string,
    job: string,
    tint: number, -- index in paleta veche; pastrat cat timp clientul mai are varianta cu o foaie
    -- Infatisarea in trei straturi. Se rostogoleste o data, la nastere, si se salveaza: un
    -- colonist trebuie sa arate la fel dupa repornire, altfel colonia nu are chipuri, are roluri.
    build: string,
    hair: string,
    hairColor: number,
    skin: number,
    x: number,
    y: number,
    path: { { x: number, y: number } }?, -- waypoint-uri in coordonate de lume
    leg: number, -- segmentul curent din path
    legStart: number, -- momentul (server time) la care a pornit segmentul
    legTime: number, -- durata segmentului, secunde
    idleUntil: number,
    speed: number,
    needs: { [string]: number },
    task: string, -- "idle" | "goto" | "using" | "working" | "fishing" | "leaving"
    target: string?, -- id-ul cladirii tinta
    working: boolean, -- tinta e post de lucru, nu loc unde isi rezolva o nevoie
    greeting: boolean, -- se duce sa vorbeasca cu jucatorul si sta acolo pana termina
    targetKind: string?, -- felul tintei ("rest"/"food"/"joy"/"work"/"site"/"river"); alege animatia pe client
    busyUntil: number,
    zeroSince: number?, -- de cand are o nevoie la 0 (fereastra de gratie)
    leaveAt: number?, -- momentul in care chiar dispare, dupa ce a pornit spre debarcader
    homeX: number, -- centrul zonei in care se invarte cand n-are treaba
    homeY: number,
    traits: { string },
    speedMul: number,
    workMul: number,
    decayMul: number,
}

local SettlerService = {}
local map: Grid.Map
local settlers: { [number]: Settler } = {}
local order: { number } = {} -- ordine stabila, pentru round-robin la cautari de drum
local cursor = 1
local nextId = 1
local rng = Prng.new(20260910)
local deps: { Remotes: { [string]: RemoteEvent } }
local dirty: { [number]: boolean } = {}
local stats = { pathsThisTick = 0, lastPathNodes = 0, failed = 0, left = 0 }
-- ultima data cand cineva a plecat flamand de la bucatarie, pentru alerta din interfata
local hungryAt = 0

local function now(): number
    return Workspace:GetServerTimeNow()
end

-- Profilul administratorului. Bucla peste toti jucatorii scria acelasi contor de mai multe ori
-- cand erau doua conturi in acelasi server de test.
local function ownerProfile(): DataService.ProfileData?
    for _, player in Players:GetPlayers() do
        local data = DataService.Get(player)
        if data ~= nil then
            return data
        end
    end
    return nil
end

-- Cladirile ca locuri de munca/odihna: ocuparea se numara ca sa nu intre 20 de oameni intr-o coliba
local occupancy: { [string]: number } = {}

-- Toate locurile utile: cladiri terminate + santiere in lucru
local function allPlaces(): { { [string]: any } }
    local out = {}
    for _, kind in { "rest", "food", "joy", "work", "farm" } do
        for _, b in BuildService.CompletedOfKind(kind) do
            table.insert(out, b)
        end
    end
    for _, b in BuildService.Sites() do
        table.insert(out, b)
    end
    return out
end

local function buildingById(id: string): { [string]: any }?
    for _, b in allPlaces() do
        if b.id == id then
            return b
        end
    end
    return nil
end

local function doorCell(b: { [string]: any }): (number?, number?)
    local wx = b.x + b.w / 2
    local wy = b.y + b.h + RiverConfig.TILE / 2
    local cx, cy = Grid.toCell(map, wx, wy)
    return Grid.nearestWalkable(map, cx, cy, 6)
end

-- Cladirea de tipul cerut, cea mai apropiata si cu loc liber
local function findBuilding(kind: string, fromX: number, fromY: number): { [string]: any }?
    local best, bestD = nil, math.huge
    for _, b in allPlaces() do
        if b.kind ~= kind or b.slots <= 0 then
            continue
        end
        if (occupancy[b.id] or 0) >= b.slots then
            continue
        end
        local dx, dy = (b.x + b.w / 2) - fromX, (b.y + b.h / 2) - fromY
        local d = dx * dx + dy * dy
        if d < bestD then
            best, bestD = b, d
        end
    end
    return best
end

local function releaseTarget(s: Settler)
    if s.target ~= nil then
        occupancy[s.target] = math.max(0, (occupancy[s.target] or 1) - 1)
        s.target = nil
    end
    s.targetKind = nil
    s.working = false
end

-- Un loc liber pe malul de sud, de unde se poate pescui. Nu e o cladire, deci nu ocupa sloturi.
local function fishingCell(s: Settler): (number?, number?)
    local bankY = RiverConfig.RIVER_BOTTOM + RiverConfig.TILE
    for _ = 1, 8 do
        local wx = RiverConfig.TILE * 2
            + rng:nextNumber() * (RiverConfig.WORLD_WIDTH - RiverConfig.TILE * 4)
        local cx, cy = Grid.toCell(map, wx, bankY)
        local gx, gy = Grid.nearestWalkable(map, cx, cy, 4)
        if gx ~= nil then
            return gx, gy
        end
    end
    local cx, cy = Grid.toCell(map, s.homeX, s.homeY)
    return Grid.nearestWalkable(map, cx, cy, 6)
end

-- Locul unde isi petrece timpul un colonist, dupa meserie
local function homePointFor(job: string): (number, number)
    local kind = (SettlerConfig.HOME_BY_JOB :: any)[job]
    local b = if kind
        then findBuilding(kind, RiverConfig.WORLD_WIDTH / 2, RiverConfig.WORLD_HEIGHT / 2)
        else nil
    if b ~= nil then
        return b.x + b.w / 2, b.y + b.h + RiverConfig.TILE * 2
    end
    -- pescarii stau pe malul de sud al raului
    return RiverConfig.WORLD_WIDTH * 0.4, RiverConfig.RIVER_BOTTOM + RiverConfig.TILE * 2
end

-- Doua trasaturi distincte, cu efectele lor inmultite
local function rollTraits(): ({ string }, number, number, number)
    local a = rng:nextInteger(1, #SettlerConfig.TRAITS)
    local b = rng:nextInteger(1, #SettlerConfig.TRAITS)
    if b == a then
        b = (b % #SettlerConfig.TRAITS) + 1
    end
    local ta, tb = SettlerConfig.TRAITS[a], SettlerConfig.TRAITS[b]
    return { ta.id, tb.id }, ta.speed * tb.speed, ta.work * tb.work, ta.decay * tb.decay
end

local jobCursor = 0
-- Cui trebuie sa-i mearga datele STATICE (nume, meserie, nuanta, trasaturi) la urmatorul update.
-- packUpdate trimite doar ce se schimba des: pozitie, nevoi, drum. Numele si meseria veneau
-- EXCLUSIV prin SendFull, deci un colonist nou aparea pe client fara nume si fara meserie
-- (in panou: un rand gol care se plimba), iar SetJob nu ajungea niciodata la client.
local needsStatic: { [number]: boolean } = {}

local function spawn(): Settler
    -- pe rand, nu la intamplare: garanteaza ca exista mereu constructori
    jobCursor += 1
    local job = SettlerConfig.JOBS[((jobCursor - 1) % #SettlerConfig.JOBS) + 1]
    local hx, hy = homePointFor(job)
    local hcx, hcy = Grid.toCell(map, hx, hy)
    local scx, scy = Grid.nearestWalkable(map, hcx, hcy, 10)
    local cx, cy = scx or 1, scy or 1
    local wx, wy = Grid.toWorld(map, cx, cy)
    local id = nextId
    nextId += 1
    local settler: Settler = {
        id = id,
        name = SettlerConfig.randomName(rng),
        job = job,
        tint = rng:nextInteger(1, #SettlerConfig.TINTS),
        build = SettlerConfig.BUILDS[rng:nextInteger(1, #SettlerConfig.BUILDS)],
        hair = SettlerConfig.HAIR_STYLES[rng:nextInteger(1, #SettlerConfig.HAIR_STYLES)],
        hairColor = rng:nextInteger(1, #SettlerConfig.HAIR_COLORS),
        skin = rng:nextInteger(1, #SettlerConfig.SKIN),
        x = wx,
        y = wy,
        path = nil,
        leg = 0,
        legStart = 0,
        legTime = 0,
        idleUntil = now() + rng:nextNumber() * 2,
        needs = {
            fed = 70 + rng:nextNumber() * 30,
            rested = 70 + rng:nextNumber() * 30,
            content = 70 + rng:nextNumber() * 30,
        },
        task = "idle",
        target = nil,
        targetKind = nil,
        working = false,
        greeting = false,
        busyUntil = 0,
        zeroSince = nil,
        homeX = hx,
        homeY = hy,
        traits = {},
        speedMul = 1,
        workMul = 1,
        decayMul = 1,
        speed = SettlerConfig.SPEED_MIN
            + rng:nextNumber() * (SettlerConfig.SPEED_MAX - SettlerConfig.SPEED_MIN),
    }
    local traits, speedMul, workMul, decayMul = rollTraits()
    settler.traits = traits
    settler.speedMul = speedMul
    settler.workMul = workMul
    settler.decayMul = decayMul
    settler.speed *= speedMul
    settlers[id] = settler
    table.insert(order, id)
    -- AICI, nu la fiecare apelant: exista trei cai care cheama spawn() si doua uitasera sa
    -- marcheze. Un colonist fara nume pe client e un rand gol in panou care se plimba.
    needsStatic[id] = true
    return settler
end

local function despawn(id: number)
    -- fara asta, un colonist sters cat timp ocupa o cladire lasa locul ocupat pe veci si
    -- cladirea pare plina la nesfarsit
    local s = settlers[id]
    if s ~= nil then
        releaseTarget(s)
    end
    settlers[id] = nil
    local at = table.find(order, id)
    if at then
        table.remove(order, at)
    end
end

function SettlerService.SetCount(target: number)
    target = math.clamp(math.floor(target), 0, SettlerConfig.HARD_CAP)
    while #order > target do
        despawn(order[#order])
    end
    while #order < target do
        local s = spawn()
        dirty[s.id] = true
    end
    if deps ~= nil then
        for _, player in Players:GetPlayers() do
            SettlerService.SendFull(player)
        end
    end
end

-- Calculeaza drumul pana la o celula si il pregateste pentru trimitere (o singura cautare A*)
local function pathToCell(s: Settler, gx: number, gy: number): boolean
    local scx, scy = Grid.toCell(map, s.x, s.y)
    local sx, sy = Grid.nearestWalkable(map, scx, scy)
    if sx == nil then
        return false
    end
    local st = { expanded = 0 }
    local cells = Pathfind.find(map, sx, sy, gx, gy, SettlerConfig.PATH_BUDGET, st)
    stats.lastPathNodes = st.expanded
    if cells == nil or #cells < 2 then
        stats.failed += 1
        s.idleUntil = now() + 1
        return false
    end
    local simple = Pathfind.simplify(cells)
    local points = table.create(#simple)
    for i, c in simple do
        local wx, wy = Grid.toWorld(map, c.x, c.y)
        points[i] = { x = wx, y = wy }
    end
    points[1] = { x = s.x, y = s.y }
    s.path = points
    s.leg = 1
    s.legStart = now()
    local dx, dy = points[2].x - points[1].x, points[2].y - points[1].y
    s.legTime = math.max(0.05, math.sqrt(dx * dx + dy * dy) / s.speed)
    dirty[s.id] = true
    return true
end

local function stopMoving(s: Settler)
    s.path = nil
    s.leg = 0
    dirty[s.id] = true
end

-- Nevoia cea mai joasa, daca e sub pragul de cautare
local function lowestNeed(s: Settler): ({ [string]: any }?, number)
    local worst, worstValue = nil, math.huge
    for _, need in SettlerConfig.NEEDS do
        local v = s.needs[need.id] or 100
        if v < worstValue then
            worst, worstValue = need, v
        end
    end
    return worst, worstValue
end

-- Decide ce face colonistul acum: intai nevoile, apoi munca, apoi plimbare
local function decide(s: Settler, t: number)
    if s.task == "leaving" or s.greeting then
        return
    end
    local need, value = lowestNeed(s)
    if need ~= nil and value < SettlerConfig.NEED_SEEK then
        local b = findBuilding(need.kind, s.x, s.y)
        if b ~= nil then
            local cx, cy = doorCell(b)
            if cx ~= nil and pathToCell(s, cx, cy) then
                releaseTarget(s)
                s.target = b.id
                s.targetKind = b.kind
                occupancy[b.id] = (occupancy[b.id] or 0) + 1
                s.task = "goto"
                return
            end
        end
    end
    -- constructorii merg la santier. Daca nu exista NICIUN constructor, pune mana oricine e
    -- liber: altfel o colonie fara constructori ramane cu santierul neterminat pentru totdeauna.
    local anyBuilder = false
    for _, other in settlers do
        if other.job == "Builder" then
            anyBuilder = true
            break
        end
    end
    local canBuild = s.job == "Builder" or not anyBuilder
    if canBuild and value >= SettlerConfig.NEED_SEEK and BuildService.HasSites() then
        local site = findBuilding("site", s.x, s.y)
        if site ~= nil then
            local cx, cy = doorCell(site)
            if cx ~= nil and pathToCell(s, cx, cy) then
                releaseTarget(s)
                s.target = site.id
                s.targetKind = site.kind
                s.working = true
                occupancy[site.id] = (occupancy[site.id] or 0) + 1
                s.task = "goto"
                return
            end
        end
    end
    -- mestesugarii merg la atelier daca e ceva de reparat
    if s.job == "Crafter" and value >= SettlerConfig.NEED_SEEK then
        local b = findBuilding("work", s.x, s.y)
        if b ~= nil and WorkshopService.HasWork() then
            local cx, cy = doorCell(b)
            if cx ~= nil and pathToCell(s, cx, cy) then
                releaseTarget(s)
                s.target = b.id
                s.targetKind = b.kind
                s.working = true
                occupancy[b.id] = (occupancy[b.id] or 0) + 1
                s.task = "goto"
                return
            end
        end
    end
    -- gradinarul la gradina, hangiul la sala de adunare: fiecare meserie are un post de lucru
    local WORK_KIND: { [string]: string } = { Gardener = "farm", Innkeeper = "joy" }
    local workKind = WORK_KIND[s.job]
    if workKind ~= nil and value >= SettlerConfig.NEED_SEEK then
        local b = findBuilding(workKind, s.x, s.y)
        if b ~= nil then
            local cx, cy = doorCell(b)
            if cx ~= nil and pathToCell(s, cx, cy) then
                releaseTarget(s)
                s.target = b.id
                s.targetKind = b.kind
                s.working = true
                occupancy[b.id] = (occupancy[b.id] or 0) + 1
                s.task = "goto"
                return
            end
        end
    end
    -- pescarii se duc pe mal si pescuiesc; e postul lor de lucru, nu o cladire.
    -- Raul are locuri limitate: cine nu prinde loc se invarte prin colonie, ca oricine fara treaba.
    local atRiver = 0
    for _, other in settlers do
        if other.task == "fishing" or other.targetKind == "river" then
            atRiver += 1
        end
    end
    if
        s.job == "Fisher"
        and value >= SettlerConfig.NEED_SEEK
        and atRiver < SettlerConfig.FISH_SPOTS
    then
        local gx, gy = fishingCell(s)
        if gx ~= nil and gy ~= nil and pathToCell(s, gx, gy) then
            releaseTarget(s)
            s.targetKind = "river"
            s.task = "goto"
            return
        end
    end
    -- fara treaba: se invarte in jurul locului lui, nu traverseaza harta aiurea
    local hcx, hcy = Grid.toCell(map, s.homeX, s.homeY)
    local r = SettlerConfig.WANDER_RADIUS_CELLS
    for _ = 1, 12 do
        local gx = hcx + rng:nextInteger(-r, r)
        local gy = hcy + rng:nextInteger(-r, r)
        if Grid.isWalkable(map, gx, gy) and pathToCell(s, gx, gy) then
            s.task = "wander"
            return
        end
    end
    s.idleUntil = t + 2
end

local greetArrived: ((Settler) -> ())? = nil

local function onArrived(s: Settler, t: number)
    stopMoving(s)
    if s.task == "leaving" then
        return -- si-a facut bagajul in acelasi tick: nu-l punem inapoi pe "idle"
    end
    if s.greeting then
        s.task = "greeting"
        local notify = greetArrived
        greetArrived = nil
        if notify ~= nil then
            notify(s)
        end
        return
    end
    if s.task == "goto" and s.targetKind == "river" then
        s.task = "fishing"
        s.busyUntil = t + SettlerConfig.FISH_SECONDS
        return
    end
    if s.task == "goto" and s.target ~= nil then
        local b = buildingById(s.target)
        if s.working then
            s.task = "working"
            s.busyUntil = t
                + (
                    if s.targetKind == "farm"
                        then SettlerConfig.FARM_SECONDS
                        else SettlerConfig.WORK_SECONDS
                )
            return
        end
        -- masa costa hrana din depozit. Daca nu ajunge, colonistul pleaca asa cum a venit:
        -- foamea trebuie sa se vada, nu sa fie acoperita de o restaurare gratuita.
        if b ~= nil and b.kind == "food" then
            if not StoreService.TakeFood(SettlerConfig.MEAL_FOOD_COST) then
                releaseTarget(s)
                s.task = "idle"
                s.idleUntil = t + 6
                hungryAt = t
                return
            end
        end
        s.task = "using"
        s.busyUntil = t + 6
        return
    end
    releaseTarget(s)
    s.task = "idle"
    s.idleUntil = t
        + SettlerConfig.IDLE_MIN
        + rng:nextNumber() * (SettlerConfig.IDLE_MAX - SettlerConfig.IDLE_MIN)
end

-- Colonistul se duce langa jucator si ramane acolo pana se termina discutia.
function SettlerService.SendToGreet(worldX: number, worldY: number): boolean
    local id = order[1]
    if id == nil then
        return false
    end
    local s = settlers[id]
    if s == nil then
        return false
    end
    local cx, cy = Grid.toCell(map, worldX, worldY)
    local gx, gy = Grid.nearestWalkable(map, cx, cy, 8)
    if gx == nil or gy == nil then
        return false
    end
    releaseTarget(s)
    s.greeting = true
    s.task = "goto"
    return pathToCell(s, gx, gy)
end

function SettlerService.OnGreetArrived(fn: (Settler) -> ())
    greetArrived = fn
end

-- Discutia s-a terminat: colonistul isi vede de treaba
function SettlerService.EndGreet()
    for _, s in settlers do
        if s.greeting then
            s.greeting = false
            s.task = "idle"
            s.idleUntil = now()
            dirty[s.id] = true
        end
    end
end

local function advance(s: Settler, t: number, dt: number)
    -- cine sta de vorba cu jucatorul nu are nevoi si nu pleaca nicaieri
    if s.greeting and s.task == "greeting" then
        return
    end
    -- 1. nevoile scad mereu, indiferent ce face
    for _, need in SettlerConfig.NEEDS do
        local v = (s.needs[need.id] or 100) - need.decayPerMinute * s.decayMul * dt / 60
        s.needs[need.id] = math.clamp(v, 0, SettlerConfig.NEED_MAX)
    end

    -- 2. daca e intr-o cladire care ii reface nevoia, se reface
    if s.task == "using" and s.target ~= nil then
        local b = buildingById(s.target)
        if b ~= nil then
            for _, need in SettlerConfig.NEEDS do
                if need.kind == b.kind then
                    s.needs[need.id] = math.min(
                        SettlerConfig.NEED_MAX,
                        (s.needs[need.id] or 0) + SettlerConfig.RESTORE_PER_SECOND * dt
                    )
                end
            end
        end
        if t >= s.busyUntil then
            releaseTarget(s)
            s.task = "idle"
            s.idleUntil = t
        end
        return
    end

    -- 3. pescuitul tine cat tine, apoi se reia daca nevoile sunt in regula
    if s.task == "fishing" then
        if t >= s.busyUntil then
            StoreService.AddFood(SettlerConfig.FISH_FOOD * s.workMul)
            local _, value = lowestNeed(s)
            if value < SettlerConfig.NEED_SEEK then
                releaseTarget(s)
                s.task = "idle"
                s.idleUntil = t
            else
                s.busyUntil = t + SettlerConfig.FISH_SECONDS
            end
        end
        return
    end

    -- 4. munca la atelier: fiecare unitate scurteaza o reparatie a jucatorului
    if s.task == "working" then
        if t >= s.busyUntil then
            local stillUseful: boolean
            if s.targetKind == "site" then
                stillUseful = BuildService.BuilderWork(SettlerConfig.BUILD_YIELD * s.workMul)
            elseif s.targetKind == "farm" then
                StoreService.AddFood(SettlerConfig.GARDEN_FOOD * s.workMul)
                stillUseful = true
            elseif s.targetKind == "joy" then
                -- Acelasi bine, impartit la toata colonia. Un hangiu acopere INNKEEPER_COVERS
                -- oameni la putere intreaga; peste atat, fiecare primeste mai putin si iti
                -- trebuie inca un hangiu (si inca un loc in sala).
                local reach = SettlerConfig.INNKEEPER_COVERS / math.max(1, #order)
                SettlerService.BoostNeed(
                    "content",
                    SettlerConfig.INNKEEPER_CONTENT * s.workMul * math.min(1, reach)
                )
                stillUseful = true
            else
                WorkshopService.SettlerWork(SettlerConfig.WORK_YIELD_PROGRESS * s.workMul)
                stillUseful = WorkshopService.HasWork()
            end
            s.busyUntil = t
                + (
                    if s.targetKind == "farm"
                        then SettlerConfig.FARM_SECONDS
                        else SettlerConfig.WORK_SECONDS
                )
            local _, value = lowestNeed(s)
            if value < SettlerConfig.NEED_SEEK or not stillUseful then
                releaseTarget(s)
                s.task = "idle"
                s.idleUntil = t
            end
        end
        return
    end

    -- 5. fereastra de gratie: la 0 pe orice nevoie, pleaca abia dupa cateva minute
    local _, worstValue = lowestNeed(s)
    if worstValue <= SettlerConfig.NEED_LEAVE then
        s.zeroSince = s.zeroSince or t
        if t - s.zeroSince > SettlerConfig.LEAVE_GRACE_SECONDS and s.task ~= "leaving" then
            s.task = "leaving"
            releaseTarget(s)
            s.leaveAt = t + SettlerConfig.LEAVE_WALK_SECONDS
            stats.left += 1
        end
    else
        s.zeroSince = nil
        -- s-a rezolvat inainte sa plece: anulam si drumul spre debarcader
        if s.task == "leaving" then
            s.task = "idle"
            s.leaveAt = nil
        end
    end

    -- 6. mers pe drum
    local path = s.path
    if path == nil then
        if t >= s.idleUntil and stats.pathsThisTick < PATHS_PER_TICK then
            stats.pathsThisTick += 1
            decide(s, t)
        end
        return
    end
    if t < s.legStart + s.legTime then
        return
    end
    local nextPoint = path[s.leg + 1]
    s.x, s.y = nextPoint.x, nextPoint.y
    s.leg += 1
    if s.leg >= #path then
        onArrived(s, t)
        return
    end
    s.legStart = t
    local a, b = path[s.leg], path[s.leg + 1]
    local dx, dy = b.x - a.x, b.y - a.y
    s.legTime = math.max(0.05, math.sqrt(dx * dx + dy * dy) / s.speed)
end

local function packUpdate(s: Settler): { [string]: any }
    local points = {}
    if s.path ~= nil then
        for i = s.leg, #s.path do
            table.insert(points, { math.round(s.path[i].x), math.round(s.path[i].y) })
        end
    end
    -- `gr` = cate secunde mai are pana se hotaraste sa plece, `lv` = cate pana dispare efectiv.
    -- Fara ele clientul nu putea deosebi un colonist nemultumit de unul care isi face bagajul.
    -- ACELASI ceas ca `zeroSince` si `leaveAt`, adica now() = Workspace:GetServerTimeNow().
    -- os.time() e alt ceas si ar da o numaratoare fara sens; pe deasupra, un `local now` aici
    -- ar umbri chiar functia now() pentru tot restul blocului.
    local t = now()
    local grace: number? = nil
    if s.zeroSince ~= nil and s.task ~= "leaving" then
        grace = math.max(0, SettlerConfig.LEAVE_GRACE_SECONDS - (t - s.zeroSince))
    end
    return {
        id = s.id,
        needs = s.needs,
        task = s.task,
        gr = grace,
        lv = if s.leaveAt ~= nil then math.max(0, s.leaveAt - t) else nil,
        tk = s.targetKind,
        x = math.round(s.x),
        y = math.round(s.y),
        t = s.legStart,
        sp = s.speed,
        p = points,
    }
end

function SettlerService.SendFull(player: Player)
    local list = {}
    for _, id in order do
        local s = settlers[id]
        local u = packUpdate(s)
        u.name = s.name
        u.job = s.job
        u.tint = s.tint
        u.build = s.build
        u.hair = s.hair
        u.hc = s.hairColor
        u.sk = s.skin
        u.traits = s.traits
        table.insert(list, u)
    end
    deps.Remotes.SettlersFull:FireClient(player, list, now())
end

function SettlerService.Stats(): { [string]: any }
    return {
        count = #order,
        failed = stats.failed,
        left = stats.left,
        lastPathNodes = stats.lastPathNodes,
    }
end

-- Barci cu oameni noi: vin doar daca ai unde sa-i culci [RIVERKEEP 4.4]
local lastArrival = 0

local function maybeArrive(t: number, scale: number)
    local profile = ownerProfile()
    local arrivedBefore = if profile ~= nil then (profile.Stats.settlersArrived or 0) else 0
    local wait = if arrivedBefore > 0
        then SettlerConfig.ARRIVAL_INTERVAL
        else SettlerConfig.FIRST_ARRIVAL_INTERVAL
    if t - lastArrival < wait / scale then
        return
    end
    lastArrival = t
    local beds = BuildService.Beds()
    if #order >= beds then
        return -- fara paturi libere, nimeni nu se opreste aici
    end
    local s = spawn()
    dirty[s.id] = true
    if profile ~= nil then
        profile.Stats.settlersArrived = (profile.Stats.settlersArrived or 0) + 1
    end
    deps.Remotes.SettlerArrived:FireAllClients(s.name, s.job)
end

local function tick()
    local t = now()
    -- In Studio, consola de dezvoltare poate accelera timpul simulat: nevoile scad mai repede si
    -- barcile vin mai des, ca sa se poata testa in minute ce altfel dureaza ore. In productie e 1.
    local scale = DevState.TimeScale()
    stats.pathsThisTick = 0
    -- round-robin: fiecare tick incepe de unde a ramas, ca sa nu fie mereu aceiasi favorizati
    local n = #order
    for k = 1, n do
        local idx = ((cursor + k - 2) % n) + 1
        local s = settlers[order[idx]]
        if s ~= nil then
            advance(s, t, TICK_SECONDS * scale)
        end
    end
    cursor = n > 0 and ((cursor % n) + 1) or 1
    maybeArrive(t, scale)

    -- Cine s-a hotarat sa plece merge intai spre debarcader si dispare abia dupa aceea. Inainte
    -- era sters in ACELASI tick in care se hotara, deci clientul nu apuca sa arate nimic si omul
    -- se evapora cu un mesaj dupa fapt.
    for i = #order, 1, -1 do
        local s = settlers[order[i]]
        if s ~= nil and s.task == "leaving" and t >= (s.leaveAt or 0) then
            deps.Remotes.SettlerLeft:FireAllClients(s.id, s.name)
            despawn(s.id)
        end
    end

    local updates = {}
    for id in dirty do
        local s = settlers[id]
        if s ~= nil then
            local u = packUpdate(s)
            if needsStatic[id] then
                u.name = s.name
                u.job = s.job
                u.tint = s.tint
                u.build = s.build
                u.hair = s.hair
                u.hc = s.hairColor
                u.sk = s.skin
                u.traits = s.traits
                needsStatic[id] = nil
            end
            table.insert(updates, u)
        end
    end
    table.clear(dirty)
    if #updates > 0 then
        deps.Remotes.SettlerPaths:FireAllClients(updates, t)
    end
end

-- Administratorul schimba meseria unui colonist; el isi muta si "locul" unde sta cand n-are treaba
function SettlerService.SetJob(id: number, job: string): boolean
    local s = settlers[id]
    if s == nil or table.find(SettlerConfig.JOBS, job) == nil then
        return false
    end
    -- doar o schimbare REALA conteaza: altfel pasul "da-i cuiva o meserie" se termina apasand
    -- pe meseria pe care omul o avea deja, fara ca jucatorul sa fi ales nimic
    local changed = s.job ~= job
    s.job = job
    s.homeX, s.homeY = homePointFor(job)
    if changed then
        local profile = ownerProfile()
        if profile ~= nil then
            profile.Stats.jobsAssigned = (profile.Stats.jobsAssigned or 0) + 1
        end
    end
    releaseTarget(s)
    s.task = "idle"
    s.idleUntil = 0
    stopMoving(s)
    dirty[s.id] = true
    needsStatic[s.id] = true -- altfel meseria noua nu ajunge niciodata pe client
    return true
end

-- Cati colonisti sunt acum
-- Numele primului colonist, pentru replica de deschidere
function SettlerService.FirstName(): string?
    local id = order[1]
    if id == nil then
        return nil
    end
    local s = settlers[id]
    return if s ~= nil then s.name else nil
end

-- UNELTE DE DEZVOLTARE. Toate trec prin poarta din DevService, care exista doar in Studio.

-- Da aceeasi meserie tuturor. Fara asta, ca sa vezi ce face un gradinar trebuia sa dai meseria
-- om cu om si sa astepti; acum vezi toata colonia facand un singur lucru, imediat.
function SettlerService.SetAllJobs(job: string): number
    local n = 0
    for _, id in order do
        if SettlerService.SetJob(id, job) then
            n += 1
        end
    end
    return n
end

-- Impinge un colonist in fereastra de plecare, ca sa se poata verifica avertismentul fara sa
-- astepti ora de scadere a nevoilor. Intoarce numele lui.
function SettlerService.ForceLeaving(): string?
    local id = order[1]
    if id == nil then
        return nil
    end
    local s = settlers[id]
    if s == nil then
        return nil
    end
    for _, need in SettlerConfig.NEEDS do
        s.needs[need.id] = 0
    end
    -- il asezam deja aproape de capatul ferestrei: raman cateva secunde de privit
    s.zeroSince = now() - SettlerConfig.LEAVE_GRACE_SECONDS + 8
    dirty[s.id] = true
    return s.name
end

function SettlerService.Count(): number
    return #order
end

-- Modifica o nevoie la toata lumea (evenimente, unelte de test). Delta poate fi negativ.
function SettlerService.BoostNeed(needId: string, delta: number): number
    local touched = 0
    for _, s in settlers do
        local current = s.needs[needId]
        if current ~= nil then
            s.needs[needId] = math.clamp(current + delta, 0, SettlerConfig.NEED_MAX)
            dirty[s.id] = true
            touched += 1
        end
    end
    return touched
end

-- Umple toate nevoile: unealta de test, ca sa nu astepti ca lumea sa se linisteasca
function SettlerService.FillNeeds()
    for _, s in settlers do
        for _, need in SettlerConfig.NEEDS do
            s.needs[need.id] = SettlerConfig.NEED_MAX
        end
        s.zeroSince = nil
        dirty[s.id] = true
    end
end

function SettlerService.DrainNeeds(to: number)
    for _, s in settlers do
        for _, need in SettlerConfig.NEEDS do
            s.needs[need.id] = math.min(s.needs[need.id] or 100, to)
        end
        dirty[s.id] = true
    end
end

-- Un colonist la intamplare isi schimba meseria. Intoarce numele si noua meserie.
function SettlerService.RerollRandomJob(): (string?, string?)
    if #order == 0 then
        return nil, nil
    end
    local s = settlers[order[rng:nextInteger(1, #order)]]
    if s == nil then
        return nil, nil
    end
    -- daca zarul da aceeasi meserie, se ia urmatoarea din lista: schimbarea trebuie sa se vada
    local jobs = SettlerConfig.JOBS
    local index = rng:nextInteger(1, #jobs)
    if jobs[index] == s.job then
        index = (index % #jobs) + 1
    end
    local job = jobs[index]
    SettlerService.SetJob(s.id, job)
    return s.name, job
end

-- Adauga oameni doar daca sunt paturi libere. Intoarce cati au intrat efectiv.
function SettlerService.Add(count: number): number
    local added = 0
    for _ = 1, math.max(0, math.floor(count)) do
        if #order >= BuildService.Beds() or #order >= SettlerConfig.HARD_CAP then
            break
        end
        local s = spawn()
        dirty[s.id] = true
        added += 1
        -- si sosirile din evenimente conteaza: altfel obiectivul "vine cineva nou" nu se
        -- termina daca omul a venit prin povestitor
        local data = ownerProfile()
        if data ~= nil then
            data.Stats.settlersArrived = (data.Stats.settlersArrived or 0) + 1
        end
    end
    if added > 0 then
        for _, player in Players:GetPlayers() do
            SettlerService.SendFull(player)
        end
    end
    return added
end

-- Lista pentru tabloul coloniei: cate persoane pe meserie si media fiecarei nevoi
-- A plecat cineva flamand de la bucatarie in ultimele 30 de secunde?
function SettlerService.Hungry(): boolean
    return now() - hungryAt < 30
end

function SettlerService.Summary(): { [string]: any }
    local byJob: { [string]: number } = {}
    for _, job in SettlerConfig.JOBS do
        byJob[job] = 0
    end
    local totals: { [string]: number } = {}
    local worst = SettlerConfig.NEED_MAX
    local unhappy = 0
    local n = 0
    for _, s in settlers do
        n += 1
        byJob[s.job] = (byJob[s.job] or 0) + 1
        local low = SettlerConfig.NEED_MAX
        for _, need in SettlerConfig.NEEDS do
            local v = s.needs[need.id] or 100
            totals[need.id] = (totals[need.id] or 0) + v
            low = math.min(low, v)
        end
        worst = math.min(worst, low)
        if low < SettlerConfig.NEED_WARN then
            unhappy += 1
        end
    end
    local averages: { [string]: number } = {}
    for _, need in SettlerConfig.NEEDS do
        averages[need.id] = if n > 0 then math.round((totals[need.id] or 0) / n) else 100
    end
    return { count = n, byJob = byJob, averages = averages, worst = worst, unhappy = unhappy }
end

-- Salvarea: numele, meseria, nevoile si trasaturile fiecarui om. Pozitia se salveaza si ea,
-- ca sa nu apara toti gramada in acelasi loc la reintrare.
function SettlerService.SaveInto(data: DataService.ProfileData)
    local list = {}
    for _, id in order do
        local s = settlers[id]
        if s == nil then
            continue
        end
        table.insert(list, {
            id = s.id,
            name = s.name,
            job = s.job,
            tint = s.tint,
            build = s.build,
            hair = s.hair,
            hairColor = s.hairColor,
            skin = s.skin,
            x = math.round(s.x),
            y = math.round(s.y),
            needs = { fed = s.needs.fed, rested = s.needs.rested, content = s.needs.content },
            traits = s.traits,
            speedMul = s.speedMul,
            workMul = s.workMul,
            decayMul = s.decayMul,
            speed = s.speed,
        })
    end
    data.Settlers = { list = list, nextId = nextId }
end

-- Reincarcarea: fara oameni salvati, colonia porneste cu numarul de start.
function SettlerService.LoadFrom(data: DataService.ProfileData)
    for _, id in order do
        settlers[id] = nil
    end
    table.clear(order)
    occupancy = {}

    local saved = data.Settlers
    if saved == nil or #saved.list == 0 then
        SettlerService.SetCount(SettlerConfig.START_COUNT)
        return
    end
    nextId = math.max(1, saved.nextId or 1)
    for _, entry in saved.list do
        local s: Settler = {
            id = entry.id,
            name = entry.name,
            job = entry.job,
            tint = entry.tint,
            -- Profilele de dinainte de straturi n-au infatisare: se ROSTOGOLESTE una acum si se
            -- salveaza la urmatorul autosave. Nu se pune prima valoare din fiecare lista --
            -- asta ar face toata colonia veche identica, adica exact problema pe care o reparam.
            build = entry.build or SettlerConfig.BUILDS[rng:nextInteger(1, #SettlerConfig.BUILDS)],
            hair = entry.hair
                or SettlerConfig.HAIR_STYLES[rng:nextInteger(1, #SettlerConfig.HAIR_STYLES)],
            hairColor = entry.hairColor or rng:nextInteger(1, #SettlerConfig.HAIR_COLORS),
            skin = entry.skin or rng:nextInteger(1, #SettlerConfig.SKIN),
            x = entry.x,
            y = entry.y,
            path = nil,
            leg = 0,
            legStart = 0,
            legTime = 0,
            idleUntil = now(),
            needs = entry.needs,
            task = "idle",
            target = nil,
            targetKind = nil,
            working = false,
            greeting = false,
            busyUntil = 0,
            zeroSince = nil,
            homeX = entry.x,
            homeY = entry.y,
            traits = entry.traits,
            speedMul = entry.speedMul,
            workMul = entry.workMul,
            decayMul = entry.decayMul,
            speed = entry.speed,
        }
        s.homeX, s.homeY = homePointFor(s.job)
        settlers[s.id] = s
        needsStatic[s.id] = true -- colonistii incarcati din profil nu trec prin spawn()
        table.insert(order, s.id)
        nextId = math.max(nextId, s.id + 1)
        dirty[s.id] = true
    end
    for _, player in Players:GetPlayers() do
        SettlerService.SendFull(player)
    end
end

function SettlerService.Init(d: typeof(deps))
    deps = d
    -- aceeasi grila ca BuildService: cladirile plasate blocheaza automat trecerea
    map = BuildService.Grid()

    -- Colonistii vin din profil, nu din aer. Populam abia dupa ce s-a incarcat, ca sa avem si
    -- grila cu cladiri refacuta si oamenii salvati din sesiunea trecuta.
    lastArrival = now()
    DataService.ProfileLoaded:Connect(function(player: Player)
        local data = DataService.Get(player)
        if data ~= nil then
            SettlerService.LoadFrom(data)
        end
    end)

    -- salvare periodica: profilul se scrie oricum de ProfileStore, noi doar il tinem la zi
    task.spawn(function()
        while true do
            task.wait(15)
            local data = ownerProfile()
            if data ~= nil then
                SettlerService.SaveInto(data)
            end
        end
    end)
    Players.PlayerRemoving:Connect(function(player: Player)
        local data = DataService.Get(player)
        if data ~= nil then
            SettlerService.SaveInto(data)
        end
    end)

    Workspace:GetAttributeChangedSignal(DEBUG_COUNT_ATTR):Connect(function()
        if not RunService:IsStudio() then
            return -- unealta de test: in productie nu are ce cauta
        end
        local v = Workspace:GetAttribute(DEBUG_COUNT_ATTR)
        if typeof(v) == "number" then
            SettlerService.SetCount(v)
        end
    end)
    if deps.Remotes.SetSettlerJob ~= nil then
        deps.Remotes.SetSettlerJob.OnServerEvent:Connect(
            function(_player: Player, id: unknown, job: unknown)
                if typeof(id) == "number" and typeof(job) == "string" then
                    SettlerService.SetJob(id, job)
                end
            end
        )
    end

    Players.PlayerAdded:Connect(function(player: Player)
        task.defer(SettlerService.SendFull, player)
    end)
    for _, player in Players:GetPlayers() do
        task.defer(SettlerService.SendFull, player)
    end

    local acc = 0
    RunService.Heartbeat:Connect(function(dt: number)
        acc += dt
        if acc >= TICK_SECONDS then
            acc = 0
            tick()
        end
    end)
end

return SettlerService
