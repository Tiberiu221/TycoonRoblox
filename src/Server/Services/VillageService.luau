--!strict
-- [D59] SATUL: ce cumperi cu perle la avizier -- decorul (fiecare lucru cu locul lui) si tinutele jucatorului. Doar aspect:
-- nimic de aici nu atinge venitul, deci nu trece prin simulator. Serverul e singurul care scade perle [D13].
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local VillageConfig = require(ReplicatedStorage.Shared.Config.VillageConfig)

local Analytics = require(script.Parent.Analytics)
local DataService = require(script.Parent.DataService)
local EconomyService = require(script.Parent.EconomyService)

local VillageService = {}
local deps: { PushState: ((Player) -> ())? } = { PushState = nil }

local function villageOf(data: any)
    if typeof(data.Village) ~= "table" then
        data.Village = { decor = {}, outfits = {}, outfit = VillageConfig.DEFAULT_OUTFIT }
    end
    local v = data.Village
    if typeof(v.decor) ~= "table" then
        v.decor = {}
    end
    if typeof(v.outfits) ~= "table" then
        v.outfits = {}
    end
    v.outfits[VillageConfig.DEFAULT_OUTFIT] = true -- tinuta de la inceput e mereu a ta
    if
        typeof(v.outfit) ~= "string"
        or VillageConfig.outfitById[v.outfit] == nil
        or not v.outfits[v.outfit]
    then
        v.outfit = VillageConfig.DEFAULT_OUTFIT
    end
    return v
end

local function push(player: Player)
    local pushState = deps.PushState
    if pushState ~= nil then
        pushState(player)
    end
end

export type Snapshot = {
    decor: { [string]: boolean },
    outfits: { [string]: boolean },
    outfit: string,
}

function VillageService.Snapshot(player: Player): Snapshot
    local data = DataService.Get(player)
    if data == nil then
        return {
            decor = {},
            outfits = { [VillageConfig.DEFAULT_OUTFIT] = true },
            outfit = VillageConfig.DEFAULT_OUTFIT,
        }
    end
    local v = villageOf(data)
    return { decor = table.clone(v.decor), outfits = table.clone(v.outfits), outfit = v.outfit }
end

-- Intoarce (reusit, motiv). Motivele ajung la client ca text [D40]: "unknown" | "already" | "pearls" | "no_profile".
function VillageService.BuyDecor(player: Player, id: string): (boolean, string)
    local data = DataService.Get(player)
    if data == nil then
        return false, "no_profile"
    end
    local decor = VillageConfig.decorById[id]
    if decor == nil then
        return false, "unknown"
    end
    local v = villageOf(data)
    if v.decor[id] then
        return false, "already"
    end
    -- plata si marcarea in acelasi cadru, fara nimic intre ele: TrySpendPearls verifica si scade dintr-o data
    if not EconomyService.TrySpendPearls(player, decor.price, "decor") then
        return false, "pearls"
    end
    v.decor[id] = true
    if not data.Firsts.FirstDecor then
        data.Firsts.FirstDecor = true
        Analytics.PierStep(player, "FirstDecor")
    end
    push(player)
    return true, "ok"
end

-- Cumperi o tinuta si o si imbraci. "journal" = River Legend: nu se vinde, vine din jurnalul complet.
function VillageService.BuyOutfit(player: Player, id: string): (boolean, string)
    local data = DataService.Get(player)
    if data == nil then
        return false, "no_profile"
    end
    local outfit = VillageConfig.outfitById[id]
    if outfit == nil then
        return false, "unknown"
    end
    local v = villageOf(data)
    if v.outfits[id] then
        return false, "already"
    end
    local price = outfit.price
    if price == nil then
        return false, "journal"
    end
    if not EconomyService.TrySpendPearls(player, price, "outfit") then
        return false, "pearls"
    end
    v.outfits[id] = true
    v.outfit = id
    if not data.Firsts.FirstOutfit then
        data.Firsts.FirstOutfit = true
        Analytics.PierStep(player, "FirstOutfit")
    end
    push(player)
    return true, "ok"
end

-- Schimbi intre tinutele pe care le ai: gratuit. "not_owned" = n-o ai inca.
function VillageService.WearOutfit(player: Player, id: string): (boolean, string)
    local data = DataService.Get(player)
    if data == nil then
        return false, "no_profile"
    end
    if VillageConfig.outfitById[id] == nil then
        return false, "unknown"
    end
    local v = villageOf(data)
    if not v.outfits[id] then
        return false, "not_owned"
    end
    v.outfit = id
    push(player)
    return true, "ok"
end

-- O tinuta primita, nu cumparata (River Legend, la jurnalul complet). O si imbraci. True doar prima data.
function VillageService.GrantOutfit(player: Player, id: string): boolean
    local data = DataService.Get(player)
    if data == nil or VillageConfig.outfitById[id] == nil then
        return false
    end
    local v = villageOf(data)
    if v.outfits[id] then
        return false
    end
    v.outfits[id] = true
    v.outfit = id
    return true
end

-- [dev] decorul si tinutele de la zero; perlele raman
function VillageService.DevReset(player: Player): boolean
    local data = DataService.Get(player)
    if data == nil then
        return false
    end
    data.Village = {
        decor = {},
        outfits = { [VillageConfig.DEFAULT_OUTFIT] = true },
        outfit = VillageConfig.DEFAULT_OUTFIT,
    }
    push(player)
    return true
end

function VillageService.Init(d: typeof(deps))
    deps = d
end

return VillageService
