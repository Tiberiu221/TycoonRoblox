--!strict
-- Atelierul jucatorului: gramada nesortata, sloturi limitate, timp real absolut (finishAt), dezmembrare [DECIZII D14, D16]
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ItemConfig = require(ReplicatedStorage.Shared.Config.ItemConfig)
local RepairConfig = require(ReplicatedStorage.Shared.Config.RepairConfig)
local DataService = require(script.Parent.DataService)
local Analytics = require(script.Parent.Analytics)

local Players = game:GetService("Players")

local WorkshopService = {}
local deps: { Remotes: { [string]: RemoteEvent }? } = { Remotes = nil }

-- Colonia are un singur administrator: profilul lui e cel la care lucreaza colonistii [RIVERKEEP 1]
local function ownerData(): (Player?, DataService.ProfileData?)
    for _, player in Players:GetPlayers() do
        local data = DataService.Get(player)
        if data ~= nil then
            return player, data
        end
    end
    return nil, nil
end

-- Exista ceva de lucru? (reparatie activa sau obiecte in gramada si slot liber)
function WorkshopService.HasWork(): boolean
    local _, data = ownerData()
    if data == nil then
        return false
    end
    if next(data.Workshop.repairs) ~= nil then
        return true
    end
    return next(data.Pile) ~= nil
end

-- O unitate de munca a unui colonist: scurteaza reparatia activa; daca nu exista, o porneste el
function WorkshopService.SettlerWork(secondsOff: number): boolean
    local player, data = ownerData()
    if player == nil or data == nil then
        return false
    end
    local best = nil
    for _, r in data.Workshop.repairs do
        if best == nil or r.finishAt < best.finishAt then
            best = r
        end
    end
    if best ~= nil then
        best.finishAt = math.max(os.time(), best.finishAt - secondsOff)
        return true
    end
    -- Niciun slot activ: colonistul incepe singur cea mai veche piesa pe care si-o PERMITE.
    -- Cu "cea mai veche" pur si simplu, o piesa scumpa in varful gramezii bloca atelierul la
    -- nesfarsit, chiar daca dedesubt statea una gratuita.
    local oldest = nil
    for _, item in data.Pile do
        local rule = (RepairConfig.TIERS :: any)[item.tier]
        local affordable = rule == nil or data.Materials >= rule.materialsCost
        if affordable and (oldest == nil or item.caughtAt < oldest.caughtAt) then
            oldest = item
        end
    end
    if oldest == nil then
        return false
    end
    for slot = 1, RepairConfig.WORKSHOP_SLOTS_FREE do
        if data.Workshop.repairs[tostring(slot)] == nil then
            local ok = WorkshopService.StartRepair(player, oldest.id, slot)
            return ok
        end
    end
    return false
end

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

-- Sloturile de reparatie cresc cu Indexul. Textul din interfata scria "Unlocks with progress"
-- de la inceput, dar functia asta isi ignora argumentul si intorcea mereu 3: nimic nu deblocase
-- vreodata nimic. Acum e adevarat. Doar CRESTE -- nimeni nu pierde un slot pe care il avea.
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
        return { pile = {}, repairs = {}, slots = 0, repaired = {}, materials = 0, now = os.time() }
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
        repaired = data.Repaired,
        index = data.Index, -- ce s-a reparat vreodata, per obiect din catalog
        materials = data.Materials,
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
    if data.Materials < rule.materialsCost then
        return false, "not_enough_materials"
    end
    data.Materials -= rule.materialsCost
    data.Pile[tostring(itemId)] = nil
    local now = os.time()
    data.Workshop.repairs[tostring(slotIndex)] = {
        itemId = itemId,
        tier = item.tier,
        startedAt = now,
        finishAt = now + rule.repairSeconds,
        catalog = item.catalog, -- ce obiect anume; fara asta slotul ar arata iar "rare crate"
    }
    if not data.Firsts.StartedFirstRepair then
        data.Firsts.StartedFirstRepair = true
        Analytics.Funnel(player, "StartedFirstRepair")
    end
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
    data.Repaired[r.tier] = (data.Repaired[r.tier] or 0) + 1
    -- Intrarea in Index e SINGURUL lucru pe care reparatia il produce si dezmembrarea nu.
    -- Pana acum reparatia scria doar contorul de mai sus, pe care nu-l citea nimeni: cine
    -- intelegea jocul dezmembra tot si nu repara niciodata nimic.
    local catalog = r.catalog
    if catalog ~= nil and catalog ~= "" then
        data.Index[catalog] = (data.Index[catalog] or 0) + 1
    end
    data.Stats.repairs += 1
    if not data.Firsts.FirstRepairComplete then
        data.Firsts.FirstRepairComplete = true
        Analytics.Funnel(player, "FirstRepairComplete")
    end
    return true, r.catalog or r.tier
end

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
    data.Stats.scraps = (data.Stats.scraps or 0) + 1 -- pentru lantul de obiective
    data.Materials += (RepairConfig.TIERS :: any)[item.tier].scrapYield
    return true, "ok"
end

-- Obiecte puse direct in gramada (povestitor, unelte de dezvoltare). Intoarce cate au intrat.
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

-- Materialele se schimba din mai multe locuri (constructii, dezmembrare, evenimente);
-- trece totul prin functia asta ca sa nu ajunga niciodata negative.
function WorkshopService.AddMaterials(player: Player, delta: number): number
    local data = DataService.Get(player)
    if data == nil then
        return 0
    end
    data.Materials = math.max(0, data.Materials + math.floor(delta))
    return data.Materials
end

-- Retrimite starea atelierului. Fara asta, o schimbare de materiale nu se vede pana la
-- urmatoarea actiune a jucatorului.
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

function WorkshopService.Init(d: { Remotes: { [string]: RemoteEvent }? })
    deps = d
end

return WorkshopService
