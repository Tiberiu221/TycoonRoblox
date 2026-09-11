--!strict
-- Handlere de remote: valideaza input-ul (tip, isfinite, rate limit), apoi apeleaza Service-urile [MASTERPLAN 4.3.4]
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Net = require(ReplicatedStorage.Net.Net)
local RateLimiter = require(script.Parent.RateLimiter)

export type Deps = {
    River: { GetConfigFor: (Player) -> { [string]: any } },
    Nets: {
        PlaceNet: (Player, number) -> (boolean, string | number),
        CollectNet: (Player, number) -> (boolean, { string }, { [string]: number }),
        Snapshot: (Player) -> { [string]: any },
    },
    Build: {
        Place: (Player, string, number, number) -> (boolean, string),
        SendTo: (Player) -> (),
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

local function isInteger(value: unknown): boolean
    return typeof(value) == "number"
        and math.isfinite(value :: number)
        and (value :: number) % 1 == 0
end

local function sendState(player: Player)
    Net.Get("RiverConfig"):FireClient(player, deps.River.GetConfigFor(player))
    Net.Get("StateSnapshot"):FireClient(player, deps.Nets.Snapshot(player))
    -- si cladirile: transmisia de la incarcarea profilului pleaca inainte ca clientul sa fie
    -- gata sa asculte, deci fara asta asezarea ramane invizibila pana la prima constructie
    deps.Build.SendTo(player)
end

function NetServer.Init(d: Deps)
    deps = d

    Net.Get("RequestState").OnServerEvent:Connect(function(player: Player)
        if RateLimiter.Allow(player, "RequestState") then
            sendState(player)
        end
    end)

    Net.Get("PlaceNet").OnServerEvent:Connect(function(player: Player, slotId: unknown)
        if not RateLimiter.Allow(player, "PlaceNet") or not isInteger(slotId) then
            return
        end
        local ok, result = deps.Nets.PlaceNet(player, slotId :: number)
        if ok then
            Net.Get("NetPlaced"):FireClient(player, result, slotId)
        else
            Net.Get("NetRejected"):FireClient(player, slotId, result)
        end
    end)

    Net.Get("CollectNet").OnServerEvent:Connect(function(player: Player, netId: unknown)
        if not RateLimiter.Allow(player, "CollectNet") or not isInteger(netId) then
            return
        end
        local ok, items, inventory = deps.Nets.CollectNet(player, netId :: number)
        if ok then
            Net.Get("NetCollected"):FireClient(player, netId, items, inventory)
        end
    end)

    local function sendWorkshop(player: Player)
        Net.Get("WorkshopState"):FireClient(player, deps.Workshop.Snapshot(player))
    end
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
            -- la reusita, `reason` e id-ul obiectului din catalog: clientul il foloseste ca sa
            -- arate ce anume a intrat in colectie, cu numele si replica lui
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
    -- dupa fiecare colectare din plasa, atelierul se schimba (gramada)
    Net.Get("CollectNet").OnServerEvent:Connect(function(player: Player)
        task.defer(sendWorkshop, player)
    end)

    Net.Get("PlaceBuilding").OnServerEvent
        :Connect(function(player: Player, defId: unknown, x: unknown, y: unknown)
            if not RateLimiter.Allow(player, "PlaceNet") then
                return
            end
            if typeof(defId) ~= "string" or not isInteger(x) or not isInteger(y) then
                return
            end
            local ok, reason = deps.Build.Place(player, defId :: string, x :: number, y :: number)
            if not ok then
                Net.Get("BuildRejected"):FireClient(player, reason)
            end
        end)

    Players.PlayerRemoving:Connect(function(player: Player)
        RateLimiter.Forget(player)
    end)
end

return NetServer
