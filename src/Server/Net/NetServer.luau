--!strict
-- Handlere de remote: valideaza input-ul (tip, isfinite, rate limit), apoi apeleaza Service-urile
-- [F0 spec 3.5]. Fara require-uri de servicii aici (doar Net/RateLimiter/TycoonConfig, module
-- fara stare de joc) -- totul altceva vine prin Init(deps), cablat de Bootstrap.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Net = require(ReplicatedStorage.Net.Net)
local TycoonConfig = require(ReplicatedStorage.Shared.Config.TycoonConfig)
local RateLimiter = require(script.Parent.RateLimiter)

export type Deps = {
    River: { GetConfigFor: (Player) -> { [string]: any }, Now: () -> number },
    Data: { ProfileLoaded: RBXScriptSignal },
    Pads: {
        Buy: (Player, string) -> (boolean, string?),
        Statuses: (Player) -> { [string]: string },
    },
    Nets: { Collect: (Player, string) -> (boolean, string?), Snapshot: (Player) -> { any } },
    Economy: {
        GetCoins: (Player) -> number,
        IncomePerSec: (Player) -> number,
        SellMult: (Player) -> number,
        SackSnapshot: (Player) -> { count: number, capacity: number, value: number },
        Sell: (Player) -> (boolean, number, number),
    },
    Workshop: {
        Snapshot: (Player) -> { [string]: any },
        StartRepair: (Player, number, number) -> (boolean, string),
        CollectRepair: (Player, number) -> (boolean, string),
        ScrapItem: (Player, number) -> (boolean, string),
    },
}

local NetServer = {}
local deps: Deps
local pending: { [Player]: boolean } = {}

local function isInteger(value: unknown): boolean
    return typeof(value) == "number"
        and math.isfinite(value :: number)
        and (value :: number) % 1 == 0
end

local function isValidPadId(value: unknown): boolean
    return typeof(value) == "string"
        and #(value :: string) <= 40
        and TycoonConfig.byId[value :: string] ~= nil
end

local function buildTycoonState(player: Player): { [string]: any }
    return {
        coins = deps.Economy.GetCoins(player),
        incomePerSec = deps.Economy.IncomePerSec(player),
        sellMult = deps.Economy.SellMult(player),
        serverTime = deps.River.Now(),
        pads = deps.Pads.Statuses(player),
        nets = deps.Nets.Snapshot(player),
        sack = deps.Economy.SackSnapshot(player),
    }
end

-- Un singur push pe cadru per jucator: Buy/Collect/Sell/tick-ul de plase pot cere fiecare o
-- retrimitere in aceeasi bucla, dar clientul are nevoie doar de ULTIMA stare, nu de una per apel.
function NetServer.PushState(player: Player)
    if pending[player] then
        return
    end
    pending[player] = true
    task.defer(function()
        pending[player] = nil
        if player.Parent ~= Players then
            return
        end
        Net.Get("TycoonState"):FireClient(player, buildTycoonState(player))
    end)
end

local function sendWorkshop(player: Player)
    Net.Get("WorkshopState"):FireClient(player, deps.Workshop.Snapshot(player))
end

function NetServer.Init(d: Deps)
    deps = d

    -- La incarcarea profilului: raul (vizual) + instantaneul tycoon complet. Firs-ul "Joined" e
    -- decis de DataService, nu de aici -- el e cel care are deja `data` in mana la momentul asta.
    deps.Data.ProfileLoaded:Connect(function(player: Player)
        Net.Get("RiverConfig"):FireClient(player, deps.River.GetConfigFor(player))
        NetServer.PushState(player)
    end)

    Net.Get("RequestState").OnServerEvent:Connect(function(player: Player)
        if not RateLimiter.Allow(player, "RequestState") then
            return
        end
        Net.Get("RiverConfig"):FireClient(player, deps.River.GetConfigFor(player))
        NetServer.PushState(player)
    end)

    Net.Get("BuyPad").OnServerEvent:Connect(function(player: Player, padId: unknown)
        if not RateLimiter.Allow(player, "BuyPad") or not isValidPadId(padId) then
            return
        end
        local ok, reason = deps.Pads.Buy(player, padId :: string)
        if ok then
            Net.Get("PadBought"):FireClient(player, padId)
        else
            Net.Get("PadRejected"):FireClient(player, padId, reason)
        end
    end)

    Net.Get("CollectNet").OnServerEvent:Connect(function(player: Player, padId: unknown)
        if not RateLimiter.Allow(player, "CollectNet") or not isValidPadId(padId) then
            return
        end
        -- Un colect care nu incape nicaieri (sack_full) nu are remote de refuz: clientul isi
        -- verifica singur sacul. Nu se trimite nimic pe ramura aia [F0 spec: not spelled out].
        deps.Nets.Collect(player, padId :: string)
    end)

    Net.Get("SellSack").OnServerEvent:Connect(function(player: Player)
        if not RateLimiter.Allow(player, "SellSack") then
            return
        end
        local ok, total, itemCount = deps.Economy.Sell(player)
        if ok then
            Net.Get("Sold"):FireClient(player, total, itemCount)
        end
    end)

    -- Atelierul: neschimbat fata de pasul anterior, doar mutat sub noile deps.
    Net.Get("RequestWorkshop").OnServerEvent:Connect(function(player: Player)
        if RateLimiter.Allow(player, "RequestState") then
            sendWorkshop(player)
        end
    end)
    Net.Get("StartRepair").OnServerEvent
        :Connect(function(player: Player, itemId: unknown, slotIndex: unknown)
            if
                not RateLimiter.Allow(player, "CollectNet")
                or not isInteger(itemId)
                or not isInteger(slotIndex)
            then
                return
            end
            local ok, reason =
                deps.Workshop.StartRepair(player, itemId :: number, slotIndex :: number)
            if not ok then
                Net.Get("WorkshopRejected"):FireClient(player, reason)
            end
            sendWorkshop(player)
        end)
    Net.Get("CollectRepair").OnServerEvent:Connect(function(player: Player, slotIndex: unknown)
        if not RateLimiter.Allow(player, "CollectNet") or not isInteger(slotIndex) then
            return
        end
        local ok, reason = deps.Workshop.CollectRepair(player, slotIndex :: number)
        if ok then
            Net.Get("RepairDone"):FireClient(player, reason)
        else
            Net.Get("WorkshopRejected"):FireClient(player, reason)
        end
        sendWorkshop(player)
    end)
    Net.Get("ScrapItem").OnServerEvent:Connect(function(player: Player, itemId: unknown)
        if not RateLimiter.Allow(player, "CollectNet") or not isInteger(itemId) then
            return
        end
        local ok, reason = deps.Workshop.ScrapItem(player, itemId :: number)
        if not ok then
            Net.Get("WorkshopRejected"):FireClient(player, reason)
        end
        sendWorkshop(player)
    end)

    Players.PlayerRemoving:Connect(function(player: Player)
        RateLimiter.Forget(player)
        pending[player] = nil
    end)
end

return NetServer
