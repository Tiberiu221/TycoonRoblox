--!strict
-- Roata: tragerea se face PE SERVER si nu se poate cere de doua ori pe zi [D13]. Clientul primeste
-- rezultatul si doar il animeaza -- nu exista niciun moment in care el il stie primul.
--
-- Samanta se salveaza in profil si avanseaza la fiecare rotire, deci sirul de premii al unui
-- jucator e reproductibil daca vreodata trebuie verificat -- fara sa fie previzibil pentru el.
--
-- [D59] Darurile raului, fara monede: perle, un lucru care vine la ponton (daca pontonul e plin, valoarea lui in perle,
-- pe loc -- iar textul spune asta) sau momeala aurie pentru undita.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Prng = require(ReplicatedStorage.Shared.Modules.Prng)
local TreasureConfig = require(ReplicatedStorage.Shared.Config.TreasureConfig)
local WheelConfig = require(ReplicatedStorage.Shared.Config.WheelConfig)
local WheelMath = require(ReplicatedStorage.Shared.Modules.WheelMath)

local DataService = require(script.Parent.DataService)
local EconomyService = require(script.Parent.EconomyService)
local FishService = require(script.Parent.FishService)
local TreasureService = require(script.Parent.TreasureService)

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

-- Intoarce (reusit, motiv, idPremiu, perle date pe loc, convertit). `convertit` = un lucru de pe rau care n-a mai avut
-- loc la ponton si a venit direct ca perle.
function WheelService.Spin(player: Player): (boolean, string, string?, number?, boolean?)
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
    local pearls, converted = 0, false
    local kind = WheelMath.kindOf(prize)
    if kind == "pearls" then
        pearls = prize.pearls :: number
    elseif kind == "treasure" then
        local treasure = prize.treasure :: string
        if not TreasureService.Grant(player, treasure) then
            pearls = TreasureConfig.byId[treasure].pearls
            converted = true
        end
    elseif kind == "bait" then
        FishService.AddBait(player, prize.bait :: number)
    end
    if pearls > 0 then
        EconomyService.AddPearls(player, pearls, "wheel")
    end
    if deps.PushState ~= nil then
        (deps.PushState :: (Player) -> ())(player)
    end
    return true, "ok", prize.id, pearls, converted
end

-- [dev] rotirea devine gata acum
function WheelService.DevReady(player: Player): boolean
    local data = DataService.Get(player)
    if data == nil then
        return false
    end
    wheelOf(data).lastSpinAt = 0
    return true
end

function WheelService.Init(d: typeof(deps))
    deps = d
end

return WheelService
