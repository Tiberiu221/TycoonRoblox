--!strict
-- Atelierul jucatorului: gramada (Pile) -> reparatie -> Index permanent, sau dezmembrare -> monede
-- [DECIZII D14, D16, D17]. Dormant in F0 (platforma Workshop nu e live, Pile ramane gol pe cale
-- normala de joc) dar functional: revine cand platforma Workshop intra live [F0 owner notes].
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ItemConfig = require(ReplicatedStorage.Shared.Config.ItemConfig)
local RepairConfig = require(ReplicatedStorage.Shared.Config.RepairConfig)
local TycoonMath = require(ReplicatedStorage.Shared.Modules.TycoonMath)
local DataService = require(script.Parent.DataService)
local PadService = require(script.Parent.PadService)
local EconomyService = require(script.Parent.EconomyService)

local WorkshopService = {}
local deps: { Remotes: { [string]: RemoteEvent }?, PushState: ((Player) -> ())? } =
    { Remotes = nil, PushState = nil }

-- Cat din catalog a fost reparat macar o data. Numara obiecte DISTINCTE: al doilea exemplar din
-- acelasi lucru nu mai adauga nimic la colectie, deci nici la progres.
function WorkshopService.IndexProgress(data: DataService.ProfileData): (number, number, number)
    local found = 0
    for _, count in data.Index do
        if count > 0 then
            found += 1
        end
    end
    local total = ItemConfig.count()
    return found, total, if total > 0 then found / total else 0
end

-- Sloturile de reparatie cresc cu Indexul. Doar CRESTE -- nimeni nu pierde un slot pe care il avea.
local function slotsFor(data: DataService.ProfileData): number
    local _, _, frac = WorkshopService.IndexProgress(data)
    local extra = 0
    for _, gate in RepairConfig.SLOT_GATES do
        if frac >= gate then
            extra += 1
        end
    end
    return RepairConfig.WORKSHOP_SLOTS_FREE + extra
end

function WorkshopService.Snapshot(player: Player): { [string]: any }
    local data = DataService.Get(player)
    if data == nil then
        return { pile = {}, repairs = {}, slots = 0, index = {}, now = os.time() }
    end
    local pile = {}
    for _, item in data.Pile do
        table.insert(pile, { id = item.id, tier = item.tier, catalog = item.catalog })
    end
    table.sort(pile, function(a, b)
        return a.id < b.id
    end)
    local repairs = {}
    for slot, r in data.Workshop.repairs do
        repairs[slot] = {
            itemId = r.itemId,
            tier = r.tier,
            startedAt = r.startedAt,
            finishAt = r.finishAt,
            catalog = r.catalog,
        }
    end
    return {
        pile = pile,
        repairs = repairs,
        slots = slotsFor(data),
        index = data.Index, -- ce s-a reparat vreodata, per obiect din catalog
        now = os.time(),
    }
end

function WorkshopService.StartRepair(
    player: Player,
    itemId: number,
    slotIndex: number
): (boolean, string)
    local data = DataService.Get(player)
    if data == nil then
        return false, "no_profile"
    end
    if slotIndex < 1 or slotIndex > slotsFor(data) then
        return false, "slot_invalid"
    end
    if data.Workshop.repairs[tostring(slotIndex)] ~= nil then
        return false, "slot_busy"
    end
    local item = data.Pile[tostring(itemId)]
    if item == nil then
        return false, "item_missing"
    end
    local rule = (RepairConfig.TIERS :: any)[item.tier]
    if rule == nil then
        return false, "item_missing"
    end
    data.Pile[tostring(itemId)] = nil
    local now = os.time()
    data.Workshop.repairs[tostring(slotIndex)] = {
        itemId = itemId,
        tier = item.tier,
        startedAt = now,
        finishAt = now + rule.repairSeconds,
        catalog = item.catalog, -- ce obiect anume; fara asta slotul ar arata iar "rare crate"
    }
    return true, "ok"
end

function WorkshopService.CollectRepair(player: Player, slotIndex: number): (boolean, string)
    local data = DataService.Get(player)
    if data == nil then
        return false, "no_profile"
    end
    local r = data.Workshop.repairs[tostring(slotIndex)]
    if r == nil then
        return false, "slot_empty"
    end
    if os.time() < r.finishAt then
        return false, "not_finished"
    end
    data.Workshop.repairs[tostring(slotIndex)] = nil
    -- Intrarea in Index e SINGURUL lucru pe care reparatia il produce si dezmembrarea nu.
    local catalog = r.catalog
    if catalog ~= nil and catalog ~= "" then
        local isNew = (data.Index[catalog] or 0) == 0
        data.Index[catalog] = (data.Index[catalog] or 0) + 1
        if isNew then
            -- o intrare noua in Index urca bonusul de vanzare: starea din cache e acum veche
            PadService.Invalidate(player)
            if deps.PushState ~= nil then
                deps.PushState(player)
            end
        end
    end
    data.Stats.repairs += 1
    return true, r.catalog or r.tier
end

-- Dezmembrarea plateste acum in monede, nu in materiale (Materials a disparut cu v2): obiectul cu
-- nume valoreaza cat ar valora vandut la debarcader, nu un tarif fix de resurse.
function WorkshopService.ScrapItem(player: Player, itemId: number): (boolean, string)
    local data = DataService.Get(player)
    if data == nil then
        return false, "no_profile"
    end
    local item = data.Pile[tostring(itemId)]
    if item == nil then
        return false, "item_missing"
    end
    data.Pile[tostring(itemId)] = nil
    data.Stats.scraps += 1
    local state = PadService.StateFor(player)
    local mult = TycoonMath.sellMultiplier(state, state.indexFound, state.rebirths)
    local value = TycoonMath.itemValue("named", item.tier, state) * mult
    EconomyService.AddCoins(player, value, "scrap")
    if deps.PushState ~= nil then
        deps.PushState(player)
    end
    return true, "ok"
end

-- Obiecte puse direct in gramada (unelte de dezvoltare; mai tarziu, alte surse in F1+).
function WorkshopService.AddToPile(player: Player, count: number, tier: string?): number
    local data = DataService.Get(player)
    if data == nil then
        return 0
    end
    local now = os.time()
    local added = 0
    for _ = 1, math.max(0, math.floor(count)) do
        local id = data.NextItemId
        data.NextItemId += 1
        data.Pile[tostring(id)] = { id = id, tier = tier or "common", caughtAt = now }
        added += 1
    end
    return added
end

-- Retrimite starea atelierului. Fara asta, o schimbare (reparatie/dezmembrare) nu se vede pana
-- la urmatoarea actiune a jucatorului.
function WorkshopService.PushState(player: Player)
    local remote = deps.Remotes and deps.Remotes.WorkshopState
    if remote ~= nil then
        remote:FireClient(player, WorkshopService.Snapshot(player))
    end
end

-- UNEALTA DE DEZVOLTARE: umple Indexul cu N obiecte DISTINCTE, ca sa se poata verifica pragurile
-- de 25% si 50% care deschid sloturile, fara sa repari 36 de obiecte pe rand.
function WorkshopService.DevFillIndex(player: Player, count: number): number
    local data = DataService.Get(player)
    if data == nil then
        return 0
    end
    local added = 0
    for _, it in ItemConfig.ITEMS do
        if added >= count then
            break
        end
        if (data.Index[it.id] or 0) == 0 then
            data.Index[it.id] = 1
            added += 1
        end
    end
    return added
end

function WorkshopService.Init(d: typeof(deps))
    deps = d
end

return WorkshopService
