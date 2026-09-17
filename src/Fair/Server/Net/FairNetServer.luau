--!strict
-- [D60] Handlerele de remote ale BALCIULUI: valideaza forma cererii (tip, lungime, limita de rata), apoi cheama
-- serviciile. Ca NetServer din sat: fara require de servicii aici, totul vine prin Init(deps), cablat de Bootstrap.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local AudioLevels = require(ReplicatedStorage.Shared.Modules.AudioLevels)
local Net = require(ReplicatedStorage.Net.Net)
local RateLimiter = require(script.Parent.RateLimiter)

export type Deps = {
    Data: {
        ProfileLoaded: RBXScriptSignal,
        Get: (Player) -> any,
        FairVisits: (Player) -> number,
        AudioLevels: (Player) -> (number, number),
        SetAudioLevel: (Player, string, number) -> (),
    },
    Economy: { GetPearls: (Player) -> number },
    Village: { Snapshot: (Player) -> { [string]: any } },
    Wheel: {
        Snapshot: (Player) -> { [string]: any },
        Spin: (Player) -> (boolean, string, string?, number?, boolean?),
    },
    Ferry: { Depart: (Player) -> () },
    Titles: {
        Snapshot: (Player) -> { [string]: any },
        Buy: (Player, string) -> (boolean, string),
        Wear: (Player, string) -> (boolean, string),
    },
    -- ce vad ceilalti (numele, tinuta, titlul) se reface cand ti se schimba starea
    Presence: { Touch: (Player) -> () },
    Cards: { Of: (number) -> { [string]: any }? },
    Board: { State: () -> { [string]: any } },
    Market: {
        Snapshot: (Player) -> { [string]: any },
        Buy: (Player, string) -> (boolean, string, string, string),
    },
    -- [D61] iazul: undita (FishService, ca in sat) si concursul (PondService)
    Fish: {
        Cast: (Player, string?) -> (boolean, string, { [string]: any }?),
        Land: (Player, number) -> (boolean, string, { [string]: any }?, number?),
    },
    Pond: {
        CanCast: (Player) -> boolean,
        Cast: (Player) -> (),
        SendTo: (Player) -> (),
    },
}

local function isInteger(value: unknown): boolean
    return typeof(value) == "number"
        and math.isfinite(value :: number)
        and (value :: number) % 1 == 0
end

local FairNetServer = {}
local deps: Deps
local pending: { [Player]: boolean } = {}

-- Starea bâlciului pentru un jucator. Fiecare camp e prezent la FIECARE trimitere: clientul o inlocuieste intreaga.
local function buildState(player: Player): { [string]: any }
    local musicLevel, soundLevel = deps.Data.AudioLevels(player)
    return {
        pearls = deps.Economy.GetPearls(player),
        village = deps.Village.Snapshot(player),
        wheel = deps.Wheel.Snapshot(player),
        visits = deps.Data.FairVisits(player),
        titles = deps.Titles.Snapshot(player),
        market = deps.Market.Snapshot(player),
        settings = { musicLevel = musicLevel, soundLevel = soundLevel },
    }
end

-- Un singur push pe cadru per jucator, ca in sat. Fara profil nu pleaca nimic: dupa un drum cu barca, profilul vine
-- cateva secunde mai tarziu (din sat), iar pana atunci clientul ar vedea zero perle si roata "gata peste o zi".
function FairNetServer.PushState(player: Player)
    if pending[player] or deps.Data.Get(player) == nil then
        return
    end
    pending[player] = true
    task.defer(function()
        pending[player] = nil
        if player.Parent ~= Players then
            return
        end
        Net.Get("FairState"):FireClient(player, buildState(player))
        deps.Presence.Touch(player)
    end)
end

function FairNetServer.Init(d: Deps)
    deps = d

    deps.Data.ProfileLoaded:Connect(function(player: Player)
        FairNetServer.PushState(player)
        Net.Get("BoardState"):FireClient(player, deps.Board.State())
        deps.Pond.SendTo(player)
    end)
    Net.Get("RequestState").OnServerEvent:Connect(function(player: Player)
        if RateLimiter.Allow(player, "RequestState") then
            FairNetServer.PushState(player)
            Net.Get("BoardState"):FireClient(player, deps.Board.State())
            deps.Pond.SendTo(player)
        end
    end)

    -- Barca spre casa: acelasi drum ca in sat, invers. Si refuzul limitei primeste raspuns (clientul asteapta pe negru).
    Net.Get("RowHome").OnServerEvent:Connect(function(player: Player)
        if not RateLimiter.Allow(player, "Ferry") then
            Net.Get("FerryFailed"):FireClient(player, "busy")
            return
        end
        deps.Ferry.Depart(player)
    end)

    -- Roata zilnica, mutata din sat: tragerea e pe server, clientul doar animeaza premiul primit.
    Net.Get("SpinWheel").OnServerEvent:Connect(function(player: Player)
        if not RateLimiter.Allow(player, "SpinWheel") then
            return
        end
        local ok, reason, prizeId, pearls, converted = deps.Wheel.Spin(player)
        if ok then
            Net.Get("WheelResult"):FireClient(player, prizeId, pearls or 0, converted == true)
        else
            Net.Get("WheelResult"):FireClient(player, nil, 0, false, reason)
        end
    end)

    -- Titlurile: id-uri scurte, verificate apoi de TitleService fata de TitleMath.
    local function titleHandler(what: string, act: (Player, string) -> (boolean, string))
        return function(player: Player, id: unknown)
            if not RateLimiter.Allow(player, "Shop") then
                return
            end
            if typeof(id) ~= "string" or #(id :: string) > 32 then
                return
            end
            local ok, reason = act(player, id :: string)
            Net.Get("ShopResult"):FireClient(player, what, id, ok, reason)
        end
    end
    Net.Get("BuyTitle").OnServerEvent:Connect(titleHandler("title", deps.Titles.Buy))
    -- vitrina negustorului: cheia se verifica in MarketService, cumpararea o face validatorul lucrului
    Net.Get("MarketBuy").OnServerEvent:Connect(function(player: Player, key: unknown)
        if not RateLimiter.Allow(player, "Shop") then
            return
        end
        if typeof(key) ~= "string" or #(key :: string) > 40 then
            return
        end
        local ok, reason, what, id = deps.Market.Buy(player, key :: string)
        Net.Get("ShopResult"):FireClient(player, what, id, ok, reason)
    end)
    Net.Get("WearTitle").OnServerEvent:Connect(titleHandler("wear_title", deps.Titles.Wear))

    -- Cardul altui om: doar cineva de pe server, cu limita (un E tinut apasat nu cere de zece ori pe secunda).
    Net.Get("LookAt").OnServerEvent:Connect(function(player: Player, userId: unknown)
        if not RateLimiter.Allow(player, "LookAt") then
            return
        end
        if
            typeof(userId) ~= "number"
            or not math.isfinite(userId :: number)
            or (userId :: number) % 1 ~= 0
        then
            return
        end
        local card = deps.Cards.Of(userId :: number)
        Net.Get("LookAtResult"):FireClient(player, card, userId)
    end)

    -- [D61] Iazul: aceeasi undita ca in sat. Se arunca doar de pe jetiu (pozitia o stie PresenceService); raspunsul are
    -- aceeasi forma ca in sat, ca undita comuna (UI/FishingRig) sa-l citeasca la fel.
    Net.Get("PondCast").OnServerEvent:Connect(function(player: Player)
        if not RateLimiter.Allow(player, "Fishing") then
            return
        end
        if not deps.Pond.CanCast(player) then
            Net.Get("PondCastResult"):FireClient(player, nil, "not_here")
            return
        end
        local ok, reason, cast = deps.Fish.Cast(player, "pond")
        if ok and cast ~= nil then
            deps.Pond.Cast(player)
            Net.Get("PondCastResult"):FireClient(
                player,
                cast.castId,
                cast.biteAt,
                cast.kind,
                cast.difficulty,
                cast.reelSeed,
                nil
            )
        else
            Net.Get("PondCastResult"):FireClient(player, nil, reason)
        end
    end)
    Net.Get("PondLand").OnServerEvent:Connect(function(player: Player, castId: unknown)
        if not RateLimiter.Allow(player, "Fishing") or not isInteger(castId) then
            return
        end
        local ok, reason, result, wait = deps.Fish.Land(player, castId :: number)
        Net.Get("PondLandResult"):FireClient(player, castId, ok, reason, result, wait)
    end)

    -- [D54] nivelul muzicii sau al efectelor, din panoul "Sound": acelasi profil ca in sat
    Net.Get("SetAudio").OnServerEvent:Connect(function(player: Player, kind: any, level: any)
        if kind ~= "music" and kind ~= "sound" then
            return
        end
        if not AudioLevels.valid(level) or not RateLimiter.Allow(player, "SetAudio") then
            return
        end
        deps.Data.SetAudioLevel(player, kind, level)
    end)

    Players.PlayerRemoving:Connect(function(player: Player)
        RateLimiter.Forget(player)
        pending[player] = nil
    end)
end

return FairNetServer
