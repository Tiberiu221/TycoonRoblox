--!strict
-- Roata: tragerea se face PE SERVER si nu se poate cere de doua ori pe zi [D13]. Clientul primeste
-- rezultatul si doar il animeaza -- nu exista niciun moment in care el il stie primul.
--
-- Samanta se salveaza in profil si avanseaza la fiecare rotire, deci sirul de premii al unui
-- jucator e reproductibil daca vreodata trebuie verificat -- fara sa fie previzibil pentru el.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Prng = require(ReplicatedStorage.Shared.Modules.Prng)
local WheelConfig = require(ReplicatedStorage.Shared.Config.WheelConfig)
local WheelMath = require(ReplicatedStorage.Shared.Modules.WheelMath)

local DataService = require(script.Parent.DataService)
local EconomyService = require(script.Parent.EconomyService)

local WheelService = {}
local deps: { PushState: ((Player) -> ())? } = { PushState = nil }

local function wheelOf(data: any)
    if typeof(data.Wheel) ~= "table" then
        data.Wheel = { lastSpinAt = 0, seed = 0, spins = 0 }
    end
    return data.Wheel
end

export type Snapshot = { ready: boolean, secondsLeft: number, spins: number }

function WheelService.Snapshot(player: Player): Snapshot
    local data = DataService.Get(player)
    if data == nil then
        return { ready = false, secondsLeft = WheelConfig.COOLDOWN, spins = 0 }
    end
    local w = wheelOf(data)
    local now = os.time() -- ceasul de PERETE: 24h inseamna 24h reale, nu 24h de sesiune
    return {
        ready = WheelMath.ready(now, w.lastSpinAt),
        secondsLeft = WheelMath.secondsLeft(now, w.lastSpinAt),
        spins = w.spins,
    }
end

-- Intoarce (reusit, motiv, idPremiu, monede, perle).
function WheelService.Spin(player: Player): (boolean, string, string?, number?, number?)
    local data = DataService.Get(player)
    if data == nil then
        return false, "no_profile"
    end
    local w = wheelOf(data)
    local now = os.time()
    if not WheelMath.ready(now, w.lastSpinAt) then
        return false, "not_ready"
    end
    -- INTAI se consuma rotirea, apoi se trage: invers, doua cereri venite in acelasi cadru ar
    -- trece amandoua de verificare si ar da doua premii pentru o singura zi.
    w.lastSpinAt = now
    w.spins += 1
    if w.seed == 0 then
        w.seed = (player.UserId * 2654435761 + now) % 4294967296
    end
    local rng = Prng.new(w.seed)
    Prng.nextU32(rng)
    local roll = Prng.nextNumber(rng)
    w.seed = Prng.nextU32(rng)

    local prize = WheelMath.pick(roll)
    local coins = WheelMath.coinsOf(prize, EconomyService.IncomePerSec(player))
    local pearls = prize.pearls or 0
    if coins > 0 then
        EconomyService.AddCoins(player, coins, "wheel")
    end
    if pearls > 0 then
        data.Pearls += pearls
    end
    if deps.PushState ~= nil then
        (deps.PushState :: (Player) -> ())(player)
    end
    return true, "ok", prize.id, coins, pearls
end

function WheelService.Init(d: typeof(deps))
    deps = d
end

return WheelService
