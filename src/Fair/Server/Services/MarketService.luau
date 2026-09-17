--!strict
-- [D60] NEGUSTORUL BALCIULUI: trei tarabe cu vitrina zilei -- patru lucruri de aspect din tot catalogul (decorul
-- satului, tinutele, titlurile de vanzare), alese din ziua de azi (MarketMath), aceleasi pentru toata lumea.
--
-- Vitrina NU e o poarta: cumpararea trece prin aceiasi validatori ca in sat si in panoul titlurilor (VillageService,
-- TitleService), iar tot catalogul ramane de cumparat si acolo. Nimic nu devine "de necumparat azi" [D46].
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local MarketMath = require(ReplicatedStorage.Shared.Modules.MarketMath)
local TitleMath = require(ReplicatedStorage.Shared.Modules.TitleMath)
local VillageConfig = require(ReplicatedStorage.Shared.Config.VillageConfig)

local Analytics = require(script.Parent.Analytics)
local DataService = require(script.Parent.DataService)
local TitleService = require(script.Parent.TitleService)
local VillageService = require(script.Parent.VillageService)

local MarketService = {}

-- Un lucru din catalog: `key` = "<fel>:<id>" (decor | outfit | title).
export type Item = { key: string, kind: string, id: string, name: string, price: number }

-- Tot catalogul de aspect, in aceeasi ordine pe orice server (din config), ca ziua sa aleaga la fel peste tot.
local POOL: { Item } = {}
for _, d in VillageConfig.DECOR do
    table.insert(
        POOL,
        { key = `decor:{d.id}`, kind = "decor", id = d.id, name = d.name, price = d.price }
    )
end
for _, o in VillageConfig.OUTFITS do
    local price = o.price
    if price ~= nil and price > 0 then
        table.insert(
            POOL,
            { key = `outfit:{o.id}`, kind = "outfit", id = o.id, name = o.name, price = price }
        )
    end
end
for _, t in TitleMath.FOR_SALE do
    table.insert(
        POOL,
        { key = `title:{t.id}`, kind = "title", id = t.id, name = t.label, price = t.price }
    )
end
MarketService.POOL = POOL
local byKey: { [string]: Item } = {}
for _, item in POOL do
    byKey[item.key] = item
end

export type Snapshot = {
    secondsLeft: number, -- pana la vitrina de maine
    items: {
        {
            key: string,
            kind: string,
            id: string,
            name: string,
            price: number,
            owned: boolean,
        }
    },
}

local function owns(data: any, item: Item): boolean
    if item.kind == "decor" then
        return typeof(data.Village) == "table" and data.Village.decor[item.id] == true
    elseif item.kind == "outfit" then
        return typeof(data.Village) == "table" and data.Village.outfits[item.id] == true
    end
    return typeof(data.Titles) == "table" and data.Titles.bought[item.id] == true
end

function MarketService.Today(now: number): { Item }
    return MarketMath.stockFor(MarketMath.dayNumber(now), POOL, MarketMath.STOCK)
end

function MarketService.Snapshot(player: Player): Snapshot
    local now = os.time()
    local data = DataService.Get(player)
    local items = {}
    for _, item in MarketService.Today(now) do
        table.insert(items, {
            key = item.key,
            kind = item.kind,
            id = item.id,
            name = item.name,
            price = item.price,
            owned = data ~= nil and owns(data, item),
        })
    end
    local day = MarketMath.dayNumber(now)
    return { secondsLeft = (day + 1) * MarketMath.DAY - now, items = items }
end

-- Intoarce (reusit, motiv, fel, id): motivele sunt cele ale validatorului lucrului, plus "unknown".
function MarketService.Buy(player: Player, key: string): (boolean, string, string, string)
    local item = byKey[key]
    if item == nil then
        return false, "unknown", "", key
    end
    local ok, reason
    if item.kind == "decor" then
        ok, reason = VillageService.BuyDecor(player, item.id)
    elseif item.kind == "outfit" then
        ok, reason = VillageService.BuyOutfit(player, item.id)
    else
        ok, reason = TitleService.Buy(player, item.id)
    end
    local data = DataService.Get(player)
    if ok and data ~= nil and not data.Firsts.FirstFairPurchase then
        data.Firsts.FirstFairPurchase = true
        Analytics.FairStep(player, "FirstFairPurchase")
    end
    return ok, reason, item.kind, item.id
end

return MarketService
