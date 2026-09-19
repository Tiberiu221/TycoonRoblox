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
local StationService = require(script.Parent.StationService)
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

-- UNEALTA DE DEZVOLTARE (named): urmatoarea prindere a fiecarei plase DETINUTE devine o gasire cu
-- nume, indiferent de sansa reala [F1 spec 3.7]. Flag EFEMER, per jucator per plasa -- nu se
-- salveaza in profil, se consuma la prima prindere de dupa comanda. PlayerRemoving il curata mai
-- jos, ca sa nu creasca tabelul la nesfarsit intre sesiuni de Studio.
local forceNamedByNet: { [Player]: { [string]: boolean } } = {}

-- Oglinda lui netEffectOf din PadService: rata/banda plasei acestei platforme.
local function netEffectOf(pad: TycoonConfig.Pad): (number?, number?)
    for _, e in pad.effects do
        if e.kind == "net" then
            return e.rate, e.lane
        end
    end
    return nil, nil
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
-- (offline, catch-up la rejoin) da acelasi rezultat fara sa salveze nimic in plus [D13]. Bunul
-- vine din TycoonMath.pickGood aplicat PRIMEI trageri a rng-ului -- ACEEASI functie pe care o
-- foloseste clientul (CatchFloat/D2) ca sa arate dinainte ce pluteste spre plasa; tier-ul vine
-- din acelasi rng, imediat dupa [F1 spec 3.1: prinderile trebuie sa ramana identice cu F0].
-- `forced`: unealta de dezvoltare (named) -- sare peste tragerea normala, tot restul e la fel.
-- [D55] Bunul tine de felul plasei (TycoonMath.netKind): plasele de lemn prind lemn, cea din larg scrap.
local function rollCatch(
    player: Player,
    pad: TycoonConfig.Pad,
    caughtIndex: number,
    forced: boolean
): Catch
    local seed = TycoonMath.catchSeed(player.UserId, pad.index, caughtIndex)
    local rng = Prng.new(seed)
    local goodId = if forced
        then "named"
        else TycoonMath.pickGood(rng:nextNumber(), TycoonMath.netKind(pad))
    -- [D65] o gasire a oricarei ere (`named`, `named2`): aceeasi tragere de treapta si acelasi catalog; era ei ii
    -- da doar valoarea (TycoonConfig.FIND_MULT)
    if TycoonMath.isFind(goodId) then
        local tier = rollTier(rng)
        local picked = ItemConfig.pickFor(tier, seed)
        return { g = goodId, c = if picked ~= nil then picked.id else nil, t = tier }
    end
    return { g = goodId }
end

-- Muta din plasa in sac pana cand sacul se umple sau plasa se goleste. Gasirile cu nume merg in sac ca orice
-- alt bun, la valoarea lor de tier, si se vand la taverna [D56: colectia e pusa deoparte -- pana atunci, dupa
-- Atelier, ocoleau sacul spre gramada lui, F1 spec 3.1]. Ce nu incape in sac ramane in plasa -- nimic nu se pierde. Daca plasa era PLINA inainte de colectare, cronometrul reporneste
-- de acum -- o plasa plina nu banca prinderile ratate cat a stat plina [F0 spec 3.4].
function NetService.Collect(player: Player, padId: string): (boolean, string?)
    local data = DataService.Get(player)
    if data == nil then
        return false, "no_profile"
    end
    local net = data.Nets[padId]
    if net == nil then
        return false, "no_net"
    end
    local capacity = TycoonMath.sackCapacity(PadService.StateFor(player))
    local netCapacity = StationService.NetCapacity(player, padId)
    -- [D51] prima plasa, in tutorial, se goleste abia plina; clientul nu ofera gestul, deci aici se
    -- ajunge doar fortat
    if TycoonMath.collectLocked(padId, data.Stats.collected or 0, #net.goods, netCapacity) then
        return false, "filling"
    end
    local remaining: { Catch } = {}
    local sackRoom = capacity - #data.Sack.items
    local moved = 0
    for _, item in net.goods do
        if sackRoom > 0 then
            table.insert(data.Sack.items, item)
            sackRoom -= 1
            moved += 1
        else
            table.insert(remaining, item)
        end
    end
    net.goods = remaining
    if moved == 0 then
        return false, "sack_full"
    end
    -- [D51] ritmul primei plase depinde de cat ai colectat (TycoonMath.catchBoost): instantaneul de mai
    -- jos trimite deja ritmul de dupa colectare.
    -- [D53] Golirea NU mai reporneste ceasul la "acum + interval": plina, ceasul a mers mai departe in
    -- ritm (NetService.tick), deci urmatoarea prindere vine la momentul ei, iar bustenii deja pe drum intra.
    data.Stats.collected = (data.Stats.collected or 0) + moved
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
    for padId, net in data.Nets do
        local pad = TycoonConfig.byId[padId]
        if pad == nil then
            continue
        end
        local rate, lane = netEffectOf(pad)
        if rate == nil or lane == nil then
            continue
        end
        -- [D58] O plasa fara loc pe harta (erele 2-4) nu se trimite: `x = pad.x or 0` o desena lipita de marginea din
        -- stanga a raului, ca "un al 6-lea net buguit" [owner, 2026-09-14]. Plasa ramane in profil, neatinsa.
        local x = pad.x
        if x == nil then
            continue
        end
        -- CE e in plasa, nu doar cat: clientul deseneaza marfa stivuita, deci are nevoie de
        -- feluri, nu de un numar [F3, marfa capata corp]. Cel mult 12 obiecte, deci rezumatul e
        -- mic; ordinea GOODS tine desenul stabil intre doua stari.
        local contents: { [string]: number } = {}
        for _, item: Catch in net.goods do
            contents[item.g] = (contents[item.g] or 0) + 1
        end
        table.insert(result, {
            padId = padId,
            contents = contents,
            padIndex = pad.index, -- pentru TycoonMath.catchSeed pe client [F1 spec 2.1, D2]
            lane = lane,
            x = x,
            y = TycoonConfig.LANE_Y[lane] or 0,
            count = #net.goods,
            capacity = StationService.NetCapacity(player, padId),
            caught = net.caught, -- indexul URMATOAREI prinderi -- vezi catchSeed
            nextCatchAt = net.nextCatchAt,
            interval = StationService.Interval(player, padId),
            -- [D51] plasa prinde grabit, in tutorial: clientul scrie asta pe ea
            boosted = TycoonMath.catchBoost(padId, data.Stats.collected or 0) > 1,
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
    for padId, net in data.Nets do
        while #net.goods < StationService.NetCapacity(player, padId) do
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

-- UNEALTA DE DEZVOLTARE (named): vezi forceNamedByNet mai sus.
function NetService.DevForceNamed(player: Player): number
    local data = DataService.Get(player)
    if data == nil then
        return 0
    end
    local set = forceNamedByNet[player]
    if set == nil then
        set = {}
        forceNamedByNet[player] = set
    end
    local n = 0
    for padId in data.Nets do
        set[padId] = true
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
        local forcedSet = forceNamedByNet[player]
        for padId, net in data.Nets do
            local pad = TycoonConfig.byId[padId]
            if pad == nil then
                continue
            end
            local rate = netEffectOf(pad)
            if rate == nil then
                continue
            end
            -- Intervalul vine din NIVELUL plasei, nu din rata fixa scrisa pe platforma: o plasa
            -- urcata prinde mai des, si asta trebuie sa se vada in ceas, nu doar in cifra din HUD.
            local interval = StationService.Interval(player, padId)
            local netCapacity = StationService.NetCapacity(player, padId)
            local pushedState = false
            -- [D53] Cate prinderi acum si unde ramane ceasul -- TycoonMath.netTick. Plina, ceasul NU mai sta
            -- pe loc: sare la primul moment de dupa `now`, ca ritmul sa ramana acelasi si clientul sa poata
            -- arata bustenii venind de departe si inainte de golire.
            local catches, nextAt =
                TycoonMath.netTick(net.nextCatchAt, interval, now, #net.goods, netCapacity)
            for _ = 1, catches do
                -- verificat DIN NOU la fiecare tragere: un backlog lung poate trece de la
                -- "prinde din urma" la "live" chiar in aceeasi bucla, pe masura ce se apropie de now
                local catchingUp = (now - net.nextCatchAt) > CATCHUP_SECONDS
                local forced = forcedSet ~= nil and forcedSet[padId] == true
                local catch = rollCatch(player, pad, net.caught, forced)
                if forced then
                    forcedSet[padId] = nil
                end
                table.insert(net.goods, catch)
                net.caught += 1
                net.nextCatchAt += interval
                if not data.Firsts.FirstCatch then
                    data.Firsts.FirstCatch = true
                    Analytics.Funnel(player, "FirstCatch")
                end
                if TycoonMath.isFind(catch.g) and not data.Firsts.FirstNamed then
                    data.Firsts.FirstNamed = true
                end
                if catchingUp then
                    pushedState = true
                else
                    deps.Remotes.NetCaught:FireClient(
                        player,
                        padId,
                        #net.goods,
                        netCapacity,
                        catch.g,
                        catch.c,
                        catch.t
                    )
                end
            end
            net.nextCatchAt = nextAt
            if pushedState and deps.PushState ~= nil then
                deps.PushState(player)
            end
        end
    end
end

Players.PlayerRemoving:Connect(function(player: Player)
    forceNamedByNet[player] = nil
end)

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
