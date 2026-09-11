--!strict
-- Plasele jucatorului: umplere pe cronometru (tick 10 Hz), colectare in sac [F0 spec 3.4].
-- Fara raul vechi de obiecte: prinderea nu mai e coliziune cu un obiect care pluteste, e un
-- cronometru per plasa (nextCatchAt) ca la orice tycoon -- rejoin-ul prinde din urma singur.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ServerStorage = game:GetService("ServerStorage")

local TycoonConfig = require(ReplicatedStorage.Shared.Config.TycoonConfig)
local TycoonMath = require(ReplicatedStorage.Shared.Modules.TycoonMath)
local ItemConfig = require(ReplicatedStorage.Shared.Config.ItemConfig)
local Prng = require(ReplicatedStorage.Shared.Modules.Prng)
local ServerTuning = require(ServerStorage.Config.ServerTuning)
local DataService = require(script.Parent.DataService)
local PadService = require(script.Parent.PadService)
local RiverService = require(script.Parent.RiverService)
local Analytics = require(script.Parent.Analytics)

type Catch = DataService.Catch

local TICK_SECONDS = 0.1
local CATCHUP_SECONDS = 5 -- peste atat, prinderile lipsa se aduna in tacere si se impinge o stare

local NetService = {}
local deps: { Remotes: { NetCaught: RemoteEvent }, PushState: ((Player) -> ())? } = {
    Remotes = nil :: any,
    PushState = nil,
}

-- Oglinda lui netEffectOf din PadService: rata/banda plasei acestei platforme.
local function netEffectOf(pad: TycoonConfig.Pad): (number?, number?)
    for _, e in pad.effects do
        if e.kind == "net" then
            return e.rate, e.lane
        end
    end
    return nil, nil
end

-- Bunurile sub minLanes cad pe driftwood -- oglinda lui income() din TycoonMath, dar pentru o
-- singura tragere, nu pentru agregat. Memoizat pe numarul de benzi (doar 1..3 posibile in F0).
local sharesCache: { [number]: { { id: string, share: number } } } = {}
local function activeShares(lanes: number): { { id: string, share: number } }
    local cached = sharesCache[lanes]
    if cached ~= nil then
        return cached
    end
    local driftwoodShare = TycoonConfig.GOODS[1].share
    local active: { { id: string, share: number } } = {}
    for _, g in TycoonConfig.GOODS do
        if g.minLanes and g.minLanes > lanes then
            driftwoodShare += g.share
        else
            table.insert(active, { id = g.id, share = g.share })
        end
    end
    active[1].share = driftwoodShare -- driftwood e mereu primul in GOODS si nu are minLanes
    sharesCache[lanes] = active
    return active
end

local function rollGood(rng: Prng.Prng, lanes: number): string
    local active = activeShares(lanes)
    local r = rng:nextNumber()
    local acc = 0
    for _, g in active do
        acc += g.share
        if r < acc then
            return g.id
        end
    end
    return active[1].id -- plasa de siguranta pentru erori de rotunjire
end

local TIER_ORDER = { "common", "uncommon", "rare", "epic", "legendary", "mythic" }
local function rollTier(rng: Prng.Prng): string
    local weights = ServerTuning.rarity_weights :: { [string]: number }
    local r = rng:nextNumber()
    local acc = 0
    for _, tier in TIER_ORDER do
        acc += weights[tier] or 0
        if r < acc then
            return tier
        end
    end
    return "common"
end

-- Determinist din (userId, index platforma, al catelea peste e in plasa asta): recalcularea
-- (offline, catch-up la rejoin) da acelasi rezultat fara sa salveze nimic in plus [D13].
local function rollCatch(
    player: Player,
    pad: TycoonConfig.Pad,
    caughtIndex: number,
    lanes: number
): Catch
    local seed = player.UserId * 7919 + pad.index * 104729 + caughtIndex
    local rng = Prng.new(seed)
    local goodId = rollGood(rng, lanes)
    if goodId == "named" then
        local tier = rollTier(rng)
        local picked = ItemConfig.pickFor(tier, seed)
        return { g = "named", c = if picked ~= nil then picked.id else nil, t = tier }
    end
    return { g = goodId }
end

-- Muta din plasa in sac pana cand sacul se umple sau plasa se goleste. Daca plasa era PLINA
-- inainte de colectare, cronometrul reporneste de acum -- o plasa plina nu banca prinderile
-- ratate cat a stat plina [F0 spec 3.4].
function NetService.Collect(player: Player, padId: string): (boolean, string?)
    local data = DataService.Get(player)
    if data == nil then
        return false, "no_profile"
    end
    local net = data.Nets[padId]
    if net == nil then
        return false, "no_net"
    end
    local pad = TycoonConfig.byId[padId]
    local capacity = TycoonMath.sackCapacity(PadService.StateFor(player))
    local wasFull = #net.goods >= TycoonConfig.NET_CAPACITY
    local moved = 0
    while #net.goods > 0 and #data.Sack.items < capacity do
        local item = table.remove(net.goods) -- din capat, O(1); ordinea nu conteaza, toate merg in sac
        if item ~= nil then
            table.insert(data.Sack.items, item)
            moved += 1
        end
    end
    if moved == 0 then
        return false, "sack_full"
    end
    if wasFull and pad ~= nil then
        local rate = netEffectOf(pad)
        if rate ~= nil then
            net.nextCatchAt = RiverService.Now()
                + TycoonMath.netInterval(rate, PadService.StateFor(player))
        end
    end
    data.Stats.collects += 1
    if not data.Firsts.FirstCollect then
        data.Firsts.FirstCollect = true
        Analytics.Funnel(player, "FirstCollect")
    end
    if deps.PushState ~= nil then
        deps.PushState(player)
    end
    return true, nil
end

function NetService.Snapshot(player: Player): { { [string]: any } }
    local data = DataService.Get(player)
    local result = {}
    if data == nil then
        return result
    end
    local state = PadService.StateFor(player)
    for padId, net in data.Nets do
        local pad = TycoonConfig.byId[padId]
        if pad == nil then
            continue
        end
        local rate, lane = netEffectOf(pad)
        if rate == nil or lane == nil then
            continue
        end
        table.insert(result, {
            padId = padId,
            lane = lane,
            x = pad.x or 0,
            y = TycoonConfig.LANE_Y[lane] or 0,
            count = #net.goods,
            capacity = TycoonConfig.NET_CAPACITY,
            nextCatchAt = net.nextCatchAt,
            interval = TycoonMath.netInterval(rate, state),
        })
    end
    return result
end

-- UNEALTA DE DEZVOLTARE (fill): umple toate plasele detinute pana la capacitate, cu driftwood simplu.
function NetService.DevFill(player: Player): number
    local data = DataService.Get(player)
    if data == nil then
        return 0
    end
    local added = 0
    for _, net in data.Nets do
        while #net.goods < TycoonConfig.NET_CAPACITY do
            table.insert(net.goods, { g = "driftwood" })
            added += 1
        end
    end
    return added
end

-- UNEALTA DE DEZVOLTARE (skip): muta toate cronometrele inapoi, ca urmatorul tick sa prinda din urma.
function NetService.DevSkip(player: Player, seconds: number): number
    local data = DataService.Get(player)
    if data == nil then
        return 0
    end
    local n = 0
    for _, net in data.Nets do
        net.nextCatchAt -= seconds
        n += 1
    end
    return n
end

local function tick(now: number)
    for _, player in Players:GetPlayers() do
        local data = DataService.Get(player)
        if data == nil then
            continue
        end
        local state = PadService.StateFor(player)
        for padId, net in data.Nets do
            local pad = TycoonConfig.byId[padId]
            if pad == nil then
                continue
            end
            local rate = netEffectOf(pad)
            if rate == nil then
                continue
            end
            local interval = TycoonMath.netInterval(rate, state)
            local pushedState = false
            while now >= net.nextCatchAt and #net.goods < TycoonConfig.NET_CAPACITY do
                -- verificat DIN NOU la fiecare tragere: un backlog lung poate trece de la
                -- "prinde din urma" la "live" chiar in aceeasi bucla, pe masura ce se apropie de now
                local catchingUp = (now - net.nextCatchAt) > CATCHUP_SECONDS
                local catch = rollCatch(player, pad, net.caught, state.lanes)
                table.insert(net.goods, catch)
                net.caught += 1
                net.nextCatchAt += interval
                if not data.Firsts.FirstCatch then
                    data.Firsts.FirstCatch = true
                    Analytics.Funnel(player, "FirstCatch")
                end
                if catchingUp then
                    pushedState = true
                else
                    deps.Remotes.NetCaught:FireClient(
                        player,
                        padId,
                        #net.goods,
                        TycoonConfig.NET_CAPACITY,
                        catch.g,
                        catch.c
                    )
                end
            end
            if pushedState and deps.PushState ~= nil then
                deps.PushState(player)
            end
        end
    end
end

function NetService.Init(d: typeof(deps))
    deps = d
    local accumulator = 0
    RunService.Heartbeat:Connect(function(dt: number)
        accumulator += dt
        if accumulator >= TICK_SECONDS then
            accumulator = 0
            tick(RiverService.Now())
        end
    end)
end

return NetService
