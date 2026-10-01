--!strict
-- [D60] TITLURILE, pe server: ce scrie sub numele tau in balci. Regulile sunt in TitleMath (pur, testat); aici doar
-- faptele din profil, perlele si alegerea ta.
--   * castigate (gratuite): Era la care ai ajuns, jurnalul complet, recordul tau, decorul cumparat, campionul saptamanii;
--   * cumparate (600/1000/1600 de perle, scumpe intentionat): le cumperi o data si le porti cand vrei.
-- Titlul purtat se verifica la fiecare citire: unul care nu mai e al tau (campionatul a trecut) cade pe cel al Erei.
-- Montat langa serviciile satului (fair.project.json), deci le cere ca frati.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local FishConfig = require(ReplicatedStorage.Shared.Config.FishConfig)
local TitleMath = require(ReplicatedStorage.Shared.Modules.TitleMath)
local PassMath = require(ReplicatedStorage.Shared.Modules.PassMath)
local StreakMath = require(ReplicatedStorage.Shared.Modules.StreakMath)
local TycoonMath = require(ReplicatedStorage.Shared.Modules.TycoonMath)

local Analytics = require(script.Parent.Analytics)
local DataService = require(script.Parent.DataService)
local EconomyService = require(script.Parent.EconomyService)

local TitleService = {}
local deps: {
    PushState: ((Player) -> ())?,
    -- #1 la peste saptamana trecuta (BoardService); pana il leaga cineva, nimeni nu e campion
    Champion: ((Player) -> boolean)?,
} =
    { PushState = nil, Champion = nil }

local function titlesOf(data: any)
    if typeof(data.Titles) ~= "table" then
        data.Titles = { bought = {}, worn = "era" }
    end
    local t = data.Titles
    if typeof(t.bought) ~= "table" then
        t.bought = {}
    end
    if typeof(t.worn) ~= "string" then
        t.worn = "era"
    end
    return t
end

local function push(player: Player)
    local pushState = deps.PushState
    if pushState ~= nil then
        pushState(player)
    end
end

-- Faptele din care ies titlurile, din profil. nil fara profil.
function TitleService.Facts(player: Player): TitleMath.Facts?
    local data = DataService.Get(player)
    if data == nil then
        return nil
    end
    local species, record = 0, nil :: TitleMath.Record?
    local fishing: any = data.Fishing
    local caught = if typeof(fishing) == "table" and typeof(fishing.species) == "table"
        then fishing.species
        else {}
    for id, entry in caught do
        local def = FishConfig.byId[id]
        if def == nil or typeof(entry) ~= "table" then
            continue
        end
        if (entry.count or 0) > 0 then
            species += 1
        end
        local best = entry.best or 0
        if best > (if record ~= nil then record.cm else 0) then
            record = { fish = def.name, cm = best }
        end
    end
    local champion = deps.Champion
    return {
        era = TycoonMath.era(data.Pads or {}),
        species = species,
        speciesTotal = #FishConfig.SPECIES,
        record = record,
        decor = table.clone(data.Village.decor or {}),
        champion = champion ~= nil and champion(player),
        bought = table.clone(titlesOf(data).bought),
        -- [D61] iazul si gheretele
        pondWins = if typeof(data.Fair) == "table" and typeof(data.Fair.pond) == "table"
            then data.Fair.pond.wins or 0
            else 0,
        perfectGames = if typeof(data.Fair) == "table"
                and typeof(data.Fair.booth) == "table"
            then data.Fair.booth.perfect or 0
            else 0,
        -- [D61, partea 2] pass-ul Supporter (doar aspect): titlul lui
        supporter = PassMath.has(data, "supporter"),
        -- [D71] cea mai lunga serie zilnica
        streakBest = StreakMath.clean((data :: any).Streak).best,
    }
end

-- Titlul purtat (id + eticheta), sau cel al Erei daca cel ales nu mai e al tau.
function TitleService.Worn(player: Player): (string, string)
    local facts = TitleService.Facts(player)
    local data = DataService.Get(player)
    if facts == nil or data == nil then
        return "era", TitleMath.eraTitle(1)
    end
    local worn = titlesOf(data).worn
    local label = TitleMath.label(worn, facts)
    if label == nil then
        return "era", TitleMath.label("era", facts) :: string
    end
    return worn, label
end

-- Ce vede panoul: titlul purtat, cele castigate, cele de vanzare si progresul spre cele inca necastigate.
export type Snapshot = {
    worn: string,
    label: string,
    earned: { { id: string, label: string } },
    forSale: { { id: string, label: string, price: number, owned: boolean } },
    species: number,
    speciesTotal: number,
    decor: { [string]: boolean },
    pondWins: number, -- [D61] progresul titlurilor din balci
    perfectGames: number,
    streakBest: number, -- [D71]
    streakRun: number,
}

function TitleService.Snapshot(player: Player): Snapshot
    local facts = TitleService.Facts(player)
    local worn, label = TitleService.Worn(player)
    local forSale = {}
    for _, entry in TitleMath.FOR_SALE do
        table.insert(forSale, {
            id = entry.id,
            label = entry.label,
            price = entry.price,
            owned = facts ~= nil and facts.bought[entry.id] == true,
        })
    end
    return {
        worn = worn,
        label = label,
        earned = if facts ~= nil then TitleMath.earned(facts) else {},
        forSale = forSale,
        species = if facts ~= nil then facts.species else 0,
        speciesTotal = #FishConfig.SPECIES,
        decor = if facts ~= nil then facts.decor else {},
        pondWins = if facts ~= nil then facts.pondWins or 0 else 0,
        perfectGames = if facts ~= nil then facts.perfectGames or 0 else 0,
        streakBest = if facts ~= nil then facts.streakBest or 0 else 0,
        streakRun = (function()
            local data = DataService.Get(player)
            return StreakMath.clean(if data ~= nil then (data :: any).Streak else nil).run
        end)(),
    }
end

-- Intoarce (reusit, motiv): "unknown" | "already" | "pearls" | "no_profile". Cumparat, il si porti.
function TitleService.Buy(player: Player, id: string): (boolean, string)
    local data = DataService.Get(player)
    if data == nil then
        return false, "no_profile"
    end
    local price = TitleMath.priceOf(id)
    if price == nil then
        return false, "unknown"
    end
    local titles = titlesOf(data)
    if titles.bought[id] then
        return false, "already"
    end
    -- plata si marcarea in acelasi cadru, fara nimic intre ele
    if not EconomyService.TrySpendPearls(player, price, "title") then
        return false, "pearls"
    end
    titles.bought[id] = true
    titles.worn = id
    if not data.Firsts.FirstFairPurchase then
        data.Firsts.FirstFairPurchase = true
        Analytics.FairStep(player, "FirstFairPurchase")
    end
    if not data.Firsts.FirstTitleWorn then
        data.Firsts.FirstTitleWorn = true
        Analytics.FairStep(player, "FirstTitleWorn")
    end
    push(player)
    return true, "ok"
end

-- Intoarce (reusit, motiv): "not_earned" | "no_profile". Schimbi intre titlurile tale: gratuit.
function TitleService.Wear(player: Player, id: string): (boolean, string)
    local data = DataService.Get(player)
    local facts = TitleService.Facts(player)
    if data == nil or facts == nil then
        return false, "no_profile"
    end
    if not TitleMath.canWear(id, facts) then
        return false, "not_earned"
    end
    titlesOf(data).worn = id
    if not data.Firsts.FirstTitleWorn then
        data.Firsts.FirstTitleWorn = true
        Analytics.FairStep(player, "FirstTitleWorn")
    end
    push(player)
    return true, "ok"
end

function TitleService.Init(d: typeof(deps))
    deps = d
end

return TitleService
