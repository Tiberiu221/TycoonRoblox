--!strict
-- Plasele jucatorului: prindere live (tick 10 Hz, server decide) + acumulare offline la login [DECIZII D13, D15, D28]
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ServerStorage = game:GetService("ServerStorage")
local Workspace = game:GetService("Workspace")

local AABB = require(ReplicatedStorage.Shared.Modules.AABB)
local RiverSim = require(ReplicatedStorage.Shared.Modules.RiverSim)
local OfflineCalc = require(ReplicatedStorage.Shared.Modules.OfflineCalc)
local ItemConfig = require(ReplicatedStorage.Shared.Config.ItemConfig)
local Prng = require(ReplicatedStorage.Shared.Modules.Prng)
local RiverConfig = require(ReplicatedStorage.Shared.Config.RiverConfig)
local EconomyConfig = require(ReplicatedStorage.Shared.Config.EconomyConfig)
local ServerTuning = require(ServerStorage.Config.ServerTuning)
local Analytics = require(script.Parent.Analytics)
local DataService = require(script.Parent.DataService)

type ProfileData = DataService.ProfileData
type NetData = DataService.NetData

local TICK_SECONDS = 0.1
local DEBUG_OFFLINE_ATTR = "DebugOfflineSeconds" -- Studio: workspace:SetAttribute("DebugOfflineSeconds", 5 * 3600)

local NetService = {}
local caught: { [Player]: { [number]: boolean } } = {} -- obiecte deja prinse in sesiunea curenta (nu se salveaza)
local deps: {
    River: typeof(require(script.Parent.RiverService)),
    Remotes: { [string]: RemoteEvent },
}

local function tierOf(net: NetData): { capacity: number, ratePerHour: number }
    return (EconomyConfig.NET_TIERS :: any)[net.tier]
end

function NetService.NetBox(slotId: number): AABB.Box
    return {
        x = RiverConfig.NET_SLOT_XS[slotId] - RiverConfig.NET_WIDTH / 2,
        y = RiverConfig.LANE_YS[slotId] - RiverConfig.NET_HEIGHT / 2,
        width = RiverConfig.NET_WIDTH,
        height = RiverConfig.NET_HEIGHT,
    }
end

function NetService.UnlockedSlots(_player: Player): number
    return ServerTuning.prototype_unlocked_net_slots -- progresia din D28 intra cu Indexul (pasul 4)
end

-- `net.items` tine acum id-uri din CATALOG, nu nume de tier. Profilele facute inainte de Index
-- au tiere acolo; le convertim la prima atingere, in loc sa refuzam sa le citim.
local function resolveCaught(value: string, seed: number): (string, string)
    local direct = ItemConfig.get(value)
    if direct ~= nil then
        return direct.id, direct.tier
    end
    local picked = ItemConfig.pickFor(value, seed)
    if picked ~= nil then
        return picked.id, picked.tier
    end
    return "", value -- catalog gol pentru tierul asta: pastram macar tierul
end

local function rollTier(rng: Prng.Prng): string
    local r = rng:nextNumber()
    local acc = 0
    for _, tier in RiverConfig.TIERS do
        acc += tier.weight
        if r < acc then
            return tier.id
        end
    end
    return "common"
end

-- Acumularea offline: capacitatea e plafonul principal, 24h back-stop; roluri seedate din (userId, netId, lastSeenAt) [DECIZII D15]
local function applyOffline(player: Player, data: ProfileData, now: number): { [string]: any }
    local since = data.Meta.lastSeenAt
    local debug = Workspace:GetAttribute(DEBUG_OFFLINE_ATTR)
    if typeof(debug) == "number" and debug > 0 then
        since = now - math.floor(debug)
    end
    local summary =
        { nets = {}, total = 0, cappedByTime = false, cappedByCapacity = false, awaySeconds = 0 }
    if since <= 0 then
        return summary
    end
    summary.awaySeconds = math.max(0, now - since)
    for key, net in data.Nets do
        local tier = tierOf(net)
        local slotsFree = tier.capacity - #net.items
        local result = OfflineCalc.computeOffline(
            now,
            math.max(since, net.lastCollectedAt),
            3600 / tier.ratePerHour,
            slotsFree
        )
        if result.itemsCaught > 0 then
            local rng = Prng.new(player.UserId * 7919 + net.id * 104729 + since)
            local best = "common"
            for _ = 1, result.itemsCaught do
                local t = rollTier(rng)
                -- acelasi generator alege si obiectul: recalcularea da acelasi rezultat [D13]
                local picked = ItemConfig.pickFor(t, math.floor(rng:nextNumber() * 1e9))
                table.insert(net.items, if picked ~= nil then picked.id else t)
                best = t -- ordinea tierelor din config e de la comun la rar; ultimul nu e neaparat cel mai rar, pastram simplu
            end
            data.Stats.catches += result.itemsCaught
            summary.total += result.itemsCaught
            table.insert(summary.nets, {
                netId = net.id,
                slotId = net.slotId,
                items = result.itemsCaught,
                best = best,
                full = #net.items >= tier.capacity,
            })
        end
        summary.cappedByTime = summary.cappedByTime or result.cappedByTime
        summary.cappedByCapacity = summary.cappedByCapacity or result.cappedByCapacity
        local _ = key
    end
    return summary
end

function NetService.PlaceNet(player: Player, slotId: number): (boolean, string | number)
    local data = DataService.Get(player)
    if data == nil then
        return false, "no_profile"
    end
    if slotId < 1 or slotId > NetService.UnlockedSlots(player) then
        return false, "slot_locked"
    end
    for _, net in data.Nets do
        if net.slotId == slotId then
            return false, "slot_occupied"
        end
    end
    local id = data.NextNetId
    data.NextNetId += 1
    local now = os.time()
    data.Nets[tostring(id)] = {
        id = id,
        slotId = slotId,
        tier = "start",
        placedAt = now,
        lastCollectedAt = now,
        items = {},
    }
    if not data.Firsts.PlacedFirstNet then
        data.Firsts.PlacedFirstNet = true
        Analytics.Funnel(player, "PlacedFirstNet")
    end
    data.Stats.netsPlaced = (data.Stats.netsPlaced or 0) + 1 -- pentru lantul de obiective
    return true, id
end

function NetService.CollectNet(
    player: Player,
    netId: number
): (boolean, { string }, { [string]: number })
    local data = DataService.Get(player)
    if data == nil then
        return false, {}, {}
    end
    local net = data.Nets[tostring(netId)]
    if net == nil then
        return false, {}, data.Inventory
    end
    local items = net.items
    net.items = {}
    net.lastCollectedAt = os.time()
    local now = os.time()
    for _, entry in items do
        local id = data.NextItemId
        data.NextItemId += 1
        local catalog, tier = resolveCaught(entry, id)
        data.Pile[tostring(id)] = { id = id, tier = tier, caughtAt = now, catalog = catalog }
    end
    data.Stats.collects += 1
    return true, items, data.Inventory
end

function NetService.Snapshot(player: Player): { [string]: any }
    local data = DataService.Get(player)
    if data == nil then
        return { nets = {}, inventory = {}, unlockedSlots = 0 }
    end
    local nets = {}
    for _, net in data.Nets do
        table.insert(nets, {
            id = net.id,
            slotId = net.slotId,
            tier = net.tier,
            contents = #net.items,
            capacity = tierOf(net).capacity,
        })
    end
    return {
        nets = nets,
        inventory = data.Inventory,
        unlockedSlots = NetService.UnlockedSlots(player),
    }
end

local function tick(now: number)
    local objects = deps.River.ActiveObjects(now)
    for _, player in Players:GetPlayers() do
        local data = DataService.Get(player)
        if data == nil then
            continue
        end
        local seen = caught[player]
        if seen == nil then
            seen = {}
            caught[player] = seen
        end
        for _, net in data.Nets do
            local capacity = tierOf(net).capacity
            if #net.items >= capacity then
                continue
            end
            local netBox = NetService.NetBox(net.slotId)
            for _, obj in objects do
                if seen[obj.id] or obj.lane ~= net.slotId then
                    continue
                end
                local objBox = RiverSim.box(obj, RiverConfig, now)
                if objBox ~= nil and AABB.intersects(netBox, objBox) then
                    seen[obj.id] = true
                    -- obiectul anume se deduce din id-ul lucrului de pe rau: determinist, deci
                    -- clientul ajunge la acelasi nume fara sa i-l mai trimitem separat
                    local picked = ItemConfig.pickFor(obj.tier, obj.id)
                    table.insert(net.items, if picked ~= nil then picked.id else obj.tier)
                    data.Stats.catches += 1
                    if not data.Firsts.CaughtFirstItem then
                        data.Firsts.CaughtFirstItem = true
                        Analytics.Funnel(player, "CaughtFirstItem")
                    end
                    deps.Remotes.ObjectCaught:FireClient(
                        player,
                        obj.id,
                        net.id,
                        #net.items,
                        capacity,
                        obj.tier
                    )
                    if #net.items >= capacity then
                        break
                    end
                end
            end
        end
    end
end

function NetService.Init(d: typeof(deps))
    deps = d
    DataService.ProfileLoaded:Connect(function(player: Player)
        local data = DataService.Get(player)
        if data == nil then
            return
        end
        if not data.Firsts.Joined then
            data.Firsts.Joined = true
            Analytics.Funnel(player, "Joined")
        end
        local summary = applyOffline(player, data, os.time())
        data.Meta.lastSeenAt = os.time()
        deps.Remotes.RiverConfig:FireClient(player, deps.River.GetConfigFor(player))
        deps.Remotes.StateSnapshot:FireClient(player, NetService.Snapshot(player))
        if summary.total > 0 then
            if not data.Firsts.SawOfflineHook then
                data.Firsts.SawOfflineHook = true
                Analytics.Funnel(player, "SawOfflineHook")
            end
            deps.Remotes.WelcomeBack:FireClient(player, summary)
        end
    end)
    local accumulator = 0
    RunService.Heartbeat:Connect(function(dt: number)
        accumulator += dt
        if accumulator >= TICK_SECONDS then
            accumulator = 0
            tick(deps.River.Now())
        end
    end)
    Players.PlayerRemoving:Connect(function(player: Player)
        caught[player] = nil
    end)
end

return NetService
