--!strict
-- Consola de dezvoltare: un singur remote, o comanda pe apel, DOAR in Studio [F0 spec 3.6].
-- Poarta e verificata pe SERVER, nu pe client: in productie handler-ul nici nu se conecteaza,
-- deci un pachet trimis de mana nu are ce sa faca. Fiecare comanda intoarce o linie de raspuns,
-- afisata in jurnalul panoului.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TycoonConfig = require(ReplicatedStorage.Shared.Config.TycoonConfig)
local TycoonMath = require(ReplicatedStorage.Shared.Modules.TycoonMath)

local DataService = require(script.Parent.DataService)
local DevState = require(script.Parent.DevState)
local EconomyService = require(script.Parent.EconomyService)
local NetService = require(script.Parent.NetService)
local PadService = require(script.Parent.PadService)

local DevService = {}
local deps: { Remotes: { [string]: RemoteEvent }, PushState: ((Player) -> ())? }

local function number(value: unknown, fallback: number): number
    if typeof(value) == "number" and math.isfinite(value :: number) then
        return value :: number
    end
    return fallback
end

type Handler = (player: Player, arg: unknown) -> string

local HANDLERS: { [string]: Handler } = {
    coins = function(player: Player, arg: unknown): string
        local delta = number(arg, 50)
        EconomyService.AddCoins(player, delta, "dev")
        return `coins {if delta >= 0 then "+" else ""}{delta} → {EconomyService.GetCoins(player)}`
    end,

    setcoins = function(player: Player, arg: unknown): string
        local n = math.max(0, number(arg, 0))
        local data = DataService.Get(player)
        if data == nil then
            return "no profile"
        end
        data.Coins = n
        return `coins set to {n}`
    end,

    reset = function(player: Player, _arg: unknown): string
        local ok = DataService.Reset(player)
        if not ok then
            return "no profile"
        end
        PadService.Invalidate(player)
        return "profile reset to a fresh save (Index kept)"
    end,

    fill = function(player: Player, _arg: unknown): string
        local n = NetService.DevFill(player)
        return `{n} items added across your nets`
    end,

    sack = function(player: Player, _arg: unknown): string
        local n = EconomyService.DevFillSack(player)
        return `{n} driftwood added to the sack`
    end,

    skip = function(player: Player, arg: unknown): string
        local seconds = number(arg, 60)
        local n = NetService.DevSkip(player, seconds)
        return `{n} nets moved {seconds}s ahead`
    end,

    buyto = function(player: Player, arg: unknown): string
        local k = math.clamp(math.floor(number(arg, 2)), 1, #TycoonConfig.PADS + 1)
        local granted = 0
        for _, pad in TycoonConfig.PADS do
            if pad.index >= k then
                break
            end
            if PadService.DevGrant(player, pad.id) then
                granted += 1
            end
        end
        return `granted {granted} pads (up to index {k - 1})`
    end,

    state = function(player: Player, _arg: unknown): string
        local data = DataService.Get(player)
        if data == nil then
            return "no profile"
        end
        local sack = EconomyService.SackSnapshot(player)
        local padsOwned = 0
        for _ in data.Pads do
            padsOwned += 1
        end
        local income = TycoonMath.formatRate(EconomyService.IncomePerSec(player))
        return `coins {TycoonMath.formatNumber(data.Coins)} · income {income}/s · {padsOwned} pads · sack {sack.count}/{sack.capacity}`
    end,
}

function DevService.Run(player: Player, command: string, arg: unknown): string
    local handler = HANDLERS[command]
    if handler == nil then
        return `unknown command: {command}`
    end
    local ok, result = pcall(handler, player, arg)
    if deps.PushState ~= nil then
        deps.PushState(player)
    end
    if not ok then
        return `error: {result}`
    end
    return result :: string
end

function DevService.Init(d: typeof(deps))
    deps = d
    if not DevState.Enabled() then
        print("[Driftwood] consola de dezvoltare e inactiva in afara Studio")
        return
    end
    local remote = deps.Remotes.DevCommand
    if remote == nil then
        return
    end
    remote.OnServerEvent:Connect(function(player: Player, command: unknown, arg: unknown)
        if typeof(command) ~= "string" or #(command :: string) > 32 then
            return
        end
        local reply = DevService.Run(player, command :: string, arg)
        remote:FireClient(player, command, reply)
    end)
    print("[Driftwood] consola de dezvoltare activa in Studio")
end

return DevService
