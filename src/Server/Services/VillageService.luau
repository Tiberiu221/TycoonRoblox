--!strict
-- [D59] SATUL: ce cumperi cu perle la avizier -- decorul (fiecare lucru cu locul lui) si tinutele jucatorului. Doar aspect:
-- nimic de aici nu atinge venitul, deci nu trece prin simulator. Serverul e singurul care scade perle [D13].
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Assets = require(ReplicatedStorage.Shared.Config.Assets)
local LookMath = require(ReplicatedStorage.Shared.Modules.LookMath)
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
    -- [D61] infatisarea: mereu patru indici valizi (un camp stricat cade pe chipul de la inceput)
    if not LookMath.valid(v.look) then
        v.look = LookMath.clean(v.look)
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
    look: LookMath.Look, -- [D61]
}

function VillageService.Snapshot(player: Player): Snapshot
    local data = DataService.Get(player)
    if data == nil then
        return {
            decor = {},
            outfits = { [VillageConfig.DEFAULT_OUTFIT] = true },
            outfit = VillageConfig.DEFAULT_OUTFIT,
            look = table.clone(LookMath.DEFAULT),
        }
    end
    local v = villageOf(data)
    return {
        decor = table.clone(v.decor),
        outfits = table.clone(v.outfits),
        outfit = v.outfit,
        look = LookMath.clean(v.look),
    }
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
-- [D61] "tailor" = se vinde doar la croitoreasa din balci: `atTailor` e adevarat doar pe drumul ei (FairNetServer).
-- "soon" = foaia tinutei inca nu e urcata: n-ai avea ce vedea pe om, deci nu se iau perle pe ea [D40].
function VillageService.BuyOutfit(player: Player, id: string, atTailor: boolean?): (boolean, string)
    local data = DataService.Get(player)
    if data == nil then
        return false, "no_profile"
    end
    local outfit = VillageConfig.outfitById[id]
    if outfit == nil then
        return false, "unknown"
    end
    if outfit.tailor and atTailor ~= true then
        return false, "tailor"
    end
    local sheet = (Assets.people.outfit :: any)[id]
    if sheet == nil or not Assets.has(sheet) then
        return false, "soon"
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

-- [D61] Infatisarea aleasa la croitoreasa: gratuita, oricand. Ce vine de la client se valideaza intreg (patru indici
-- din palete); o infatisare pe jumatate buna se refuza, nu se carpeste. "invalid" | "no_profile".
function VillageService.SetLook(player: Player, look: unknown): (boolean, string)
    local data = DataService.Get(player)
    if data == nil then
        return false, "no_profile"
    end
    if not LookMath.valid(look) then
        return false, "invalid"
    end
    local v = villageOf(data)
    v.look = LookMath.clean(look)
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
        look = table.clone(LookMath.DEFAULT),
    }
    push(player)
    return true
end

function VillageService.Init(d: typeof(deps))
    deps = d
end

return VillageService
