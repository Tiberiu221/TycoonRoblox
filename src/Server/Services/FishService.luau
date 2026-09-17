--!strict
-- [D59] UNDITA, pe server. Ce prinzi se trage aici, la aruncare, din samanta profilului, si nu se spune clientului pana
-- nu scoate pestele [D13] -- clientul primeste doar clipa muscaturii, dificultatea si samanta barei (ReelMath), ca s-o
-- deseneze la fel. Scoaterea se crede doar dupa timpul celui mai bun jucator posibil pe EXACT acea bara.
--
-- Aruncarea in asteptare sta in memorie, nu in profil: nimic de valoare nu e in joc cat pestele e inca in apa. O
-- aruncare noua o inlocuieste pe cea veche (pleci si revii), iar una lasata in apa se uita singura.
--
-- Daca te asteapta ceva la ponton (TreasureService), aruncarea il agata pe el: aceeasi bara, alta dificultate.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local FishConfig = require(ReplicatedStorage.Shared.Config.FishConfig)
local FishMath = require(ReplicatedStorage.Shared.Modules.FishMath)
local Prng = require(ReplicatedStorage.Shared.Modules.Prng)
local ReelMath = require(ReplicatedStorage.Shared.Modules.ReelMath)
local TreasureConfig = require(ReplicatedStorage.Shared.Config.TreasureConfig)

local Analytics = require(script.Parent.Analytics)
local DataService = require(script.Parent.DataService)
local EconomyService = require(script.Parent.EconomyService)
local TreasureService = require(script.Parent.TreasureService)
local VillageService = require(script.Parent.VillageService)

local FishService = {}
local deps: {
    PushState: ((Player) -> ())?,
    Now: (() -> number)?,
    -- [D60] un peste scos: clasamentul balciului (LeaderboardService), doar in sat
    OnLanded: ((Player, string, number) -> ())?,
} =
    { PushState = nil, Now = nil, OnLanded = nil }

-- Un lucru agatat se prinde repede: sta deja langa ponton.
local TREASURE_BITE = 1.5
local JOURNAL_OUTFIT = "legend"

type Pending = {
    castId: number,
    biteAt: number,
    kind: string, -- "fish" | "treasure"
    difficulty: number,
    reelSeed: number,
    species: string?,
    size: number?,
    treasure: string?,
}
local pending: { [Player]: Pending } = {}
local forced: { [Player]: string } = {} -- [dev] specia urmatoarei aruncari
local nextCastId = 0

local function now(): number
    local clock = deps.Now
    return if clock ~= nil then clock() else os.clock()
end

local function fishingOf(data: any)
    if typeof(data.Fishing) ~= "table" then
        data.Fishing = { seed = 0, casts = 0, bait = 0, species = {} }
    end
    local f = data.Fishing
    if typeof(f.species) ~= "table" then
        f.species = {}
    end
    f.bait = if typeof(f.bait) == "number" and math.isfinite(f.bait) then math.max(0, f.bait) else 0
    return f
end

local function push(player: Player)
    local pushState = deps.PushState
    if pushState ~= nil then
        pushState(player)
    end
end

export type Cast = {
    castId: number,
    biteAt: number,
    kind: string,
    difficulty: number,
    reelSeed: number,
    treasure: string?,
}

export type Result = {
    kind: string, -- "fish" | "treasure"
    pearls: number,
    species: string?,
    size: number?,
    isNew: boolean?,
    isRecord: boolean?,
    baited: boolean?,
    treasure: string?,
    note: number?, -- indexul biletului din sticla (TreasureConfig.NOTES)
    outfit: string?, -- tinuta primita chiar acum (jurnalul complet)
}

export type Snapshot = {
    bait: number,
    species: { [string]: { count: number, best: number } },
    fished: number,
}

function FishService.Snapshot(player: Player): Snapshot
    local data = DataService.Get(player)
    if data == nil then
        return { bait = 0, species = {}, fished = 0 }
    end
    local f = fishingOf(data)
    local species = {}
    for id, entry in f.species do
        if typeof(entry) == "table" then
            species[id] = { count = entry.count or 0, best = entry.best or 0 }
        end
    end
    return { bait = f.bait, species = species, fished = data.Stats.fished or 0 }
end

-- Intoarce (reusit, motiv, aruncarea). Aruncarea nu spune ce e in apa, doar cat de greu se scoate.
function FishService.Cast(player: Player): (boolean, string, Cast?)
    local data = DataService.Get(player)
    if data == nil then
        return false, "no_profile", nil
    end
    local f = fishingOf(data)
    local t = now()
    if f.seed == 0 then
        f.seed = (player.UserId * 2246822519 + os.time()) % 4294967296
    end
    local rng = Prng.new(f.seed)
    rng:nextU32()
    local biteRoll, tierRoll, speciesRoll, sizeRoll =
        rng:nextNumber(), rng:nextNumber(), rng:nextNumber(), rng:nextNumber()
    local reelSeed = rng:nextU32()
    f.seed = rng:nextU32()
    f.casts = (f.casts or 0) + 1
    nextCastId += 1

    local p: Pending
    local waiting = TreasureService.FirstWaiting(player)
    local treasure = if waiting ~= nil then TreasureConfig.byId[waiting] else nil
    if treasure ~= nil then
        p = {
            castId = nextCastId,
            biteAt = t + TREASURE_BITE,
            kind = "treasure",
            difficulty = treasure.difficulty,
            reelSeed = reelSeed,
            treasure = treasure.id,
        }
    else
        local species = FishMath.pickSpecies(tierRoll, speciesRoll)
        local force = forced[player]
        if force ~= nil and FishConfig.byId[force] ~= nil then
            species = FishConfig.byId[force]
            forced[player] = nil
        end
        p = {
            castId = nextCastId,
            biteAt = t
                + FishConfig.BITE_MIN
                + biteRoll * (FishConfig.BITE_MAX - FishConfig.BITE_MIN),
            kind = "fish",
            difficulty = FishMath.tierOf(species).difficulty,
            reelSeed = reelSeed,
            species = species.id,
            size = FishMath.size(species, sizeRoll),
        }
    end
    pending[player] = p
    if not data.Firsts.FirstCast then
        data.Firsts.FirstCast = true
        Analytics.PierStep(player, "FirstCast")
    end
    return true,
        "ok",
        {
            castId = p.castId,
            biteAt = p.biteAt,
            kind = p.kind,
            difficulty = p.difficulty,
            reelSeed = p.reelSeed,
            treasure = p.treasure,
        }
end

local function journalComplete(f: any): boolean
    for _, s in FishConfig.SPECIES do
        if typeof(f.species[s.id]) ~= "table" then
            return false
        end
    end
    return true
end

-- Intoarce (reusit, motiv, rezultat, cat mai ai de asteptat). "too_soon" vine cu secundele ramase: clientul retrimite.
function FishService.Land(player: Player, castId: number): (boolean, string, Result?, number?)
    local data = DataService.Get(player)
    if data == nil then
        return false, "no_profile", nil, nil
    end
    local p = pending[player]
    if p == nil or p.castId ~= castId then
        return false, "no_cast", nil, nil
    end
    local t = now()
    if t > p.biteAt + FishConfig.EXPIRE_AFTER_BITE then
        pending[player] = nil
        return false, "expired", nil, nil
    end
    local earliest = p.biteAt
        + ReelMath.minSeconds(p.reelSeed, p.difficulty)
        - FishConfig.LAND_TOLERANCE
    if t < earliest then
        return false, "too_soon", nil, earliest - t
    end
    -- INTAI se consuma aruncarea, apoi se plateste: doua scoateri ale aceleiasi aruncari n-ar plati de doua ori.
    pending[player] = nil

    if p.kind == "treasure" then
        local kind, pearls, note = TreasureService.Open(player)
        if kind == nil then
            return false, "gone", nil, nil
        end
        push(player)
        return true, "ok", { kind = "treasure", treasure = kind, pearls = pearls, note = note }, nil
    end

    local species = FishConfig.byId[p.species or ""]
    if species == nil then
        return false, "no_cast", nil, nil
    end
    local f = fishingOf(data)
    local entry = f.species[species.id]
    local size = p.size or species.minCm
    local isNew = typeof(entry) ~= "table"
    local isRecord = not isNew and size > (entry.best or 0)
    if isNew then
        entry = { count = 0, best = 0 }
        f.species[species.id] = entry
    end
    entry.count = (entry.count or 0) + 1
    entry.best = math.max(entry.best or 0, size)
    local baited = f.bait > 0
    if baited then
        f.bait -= 1
    end
    local pearls = FishMath.pearlsFor(species, isNew, baited)
    EconomyService.AddPearls(player, pearls, "fish")
    data.Stats.fished = (data.Stats.fished or 0) + 1
    if not data.Firsts.FirstFish then
        data.Firsts.FirstFish = true
        Analytics.PierStep(player, "FirstFish")
    end
    TreasureService.StartRiver(player) -- de la primul peste, raul incepe sa aduca (a doua oara nu schimba nimic)
    local onLanded = deps.OnLanded
    if onLanded ~= nil then
        onLanded(player, species.id, size)
    end
    local outfit: string? = nil
    if isNew and journalComplete(f) and VillageService.GrantOutfit(player, JOURNAL_OUTFIT) then
        outfit = JOURNAL_OUTFIT
    end
    push(player)
    return true,
        "ok",
        {
            kind = "fish",
            species = species.id,
            size = size,
            pearls = pearls,
            isNew = isNew,
            isRecord = isRecord,
            baited = baited,
            outfit = outfit,
        },
        nil
end

-- Momeala aurie, de la roata.
function FishService.AddBait(player: Player, n: number)
    local data = DataService.Get(player)
    if data == nil or not math.isfinite(n) or n <= 0 then
        return
    end
    local f = fishingOf(data)
    f.bait += math.floor(n)
end

-- [dev] specia urmatoarei aruncari (daca nu te asteapta nimic la ponton)
function FishService.DevForce(player: Player, speciesId: string): boolean
    if FishConfig.byId[speciesId] == nil then
        return false
    end
    forced[player] = speciesId
    return true
end

function FishService.Init(d: typeof(deps))
    deps = d
    Players.PlayerRemoving:Connect(function(player: Player)
        pending[player] = nil
        forced[player] = nil
    end)
end

return FishService
