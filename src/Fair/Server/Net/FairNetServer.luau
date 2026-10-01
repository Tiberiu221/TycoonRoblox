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
        -- [D71] seria zilnica si vestea ei (o singura data, cine o ia o arata)
        Streak: (Player) -> { day: number, run: number, best: number, total: number },
        TakeStreakNews: (Player) -> { event: string, record: boolean, title: string? }?,
        SetStreakClock: (Player, unknown) -> boolean,
        AudioLevels: (Player) -> (number, number),
        SetAudioLevel: (Player, string, number) -> (),
    },
    Economy: { GetPearls: (Player) -> number },
    Village: {
        Snapshot: (Player) -> { [string]: any },
        -- [D61] croitoreasa: cumperi (al treilea argument = "la cortul ei"), porti, iti alegi infatisarea
        BuyOutfit: (Player, string, boolean?) -> (boolean, string),
        WearOutfit: (Player, string) -> (boolean, string),
        SetLook: (Player, unknown) -> (boolean, string),
    },
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
    -- [D61] gheretele
    Booth: {
        Snapshot: (Player) -> { [string]: any },
        Start: (Player, string) -> (boolean, string, number?, number?),
        Finish: (Player, unknown) -> (boolean, string, { [string]: any }?),
    },
    -- [D61, partea 2] poarta satelor
    Visits: {
        List: (Player) -> { { [string]: any } },
        Look: (Player, number) -> (boolean, string, { [string]: any }?),
        Leave: (Player) -> (),
        Like: (Player, number) -> (boolean, string, number?),
        LikesOf: (Player) -> number,
    },
    -- [D61, partea 2] coltul cu Robux (in balci: doar pass-urile)
    Shop: {
        Snapshot: (Player) -> { [string]: any },
        Prompt: (Player, string) -> (boolean, string),
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
        booth = deps.Booth.Snapshot(player),
        likes = deps.Visits.LikesOf(player), -- [D61, partea 2] cate like-uri are satul tau
        robux = deps.Shop.Snapshot(player), -- [D61, partea 2] pass-urile tale, cat de repede mergi
        settings = { musicLevel = musicLevel, soundLevel = soundLevel },
        -- [D71] seria zilnica; `news` doar in prima stare de dupa o zi noua numarata aici: { event, record, title }
        streak = (function()
            local streak = deps.Data.Streak(player)
            return { run = streak.run, best = streak.best, news = deps.Data.TakeStreakNews(player) }
        end)(),
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

    -- [D61] CROITOREASA. Tinutele trec prin aceiasi validatori ca la avizierul satului (VillageService); `true` spune
    -- ca esti la cortul ei, singurul loc unde se vand ale ei. Infatisarea e gratuita; forma ei o verifica LookMath.
    Net.Get("BuyOutfit").OnServerEvent
        :Connect(titleHandler("outfit", function(player: Player, id: string)
            return deps.Village.BuyOutfit(player, id, true)
        end))
    Net.Get("WearOutfit").OnServerEvent:Connect(titleHandler("wear", deps.Village.WearOutfit))
    Net.Get("SetLook").OnServerEvent:Connect(function(player: Player, look: unknown)
        if not RateLimiter.Allow(player, "Shop") then
            return
        end
        local ok, reason = deps.Village.SetLook(player, look)
        if not ok then
            -- reusita se vede pe om; doar refuzul are nevoie de cuvinte [D43]
            Net.Get("ShopResult"):FireClient(player, "look", "", false, reason)
        end
    end)

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

    -- [D61, partea 2] COLTUL CU ROBUX. Clientul cere un lucru din catalog; fereastra Roblox o deschide serverul, daca
    -- lucrul exista pe universul asta si are rost acum. Un refuz se spune [D43]; ce ai primit vine tot pe RobuxResult,
    -- dupa plata (PassService / PurchaseService).
    Net.Get("RobuxBuy").OnServerEvent:Connect(function(player: Player, key: unknown)
        if not RateLimiter.Allow(player, "Robux") then
            return
        end
        if typeof(key) ~= "string" or #(key :: string) > 24 then
            return
        end
        local ok, reason = deps.Shop.Prompt(player, key :: string)
        if not ok then
            Net.Get("RobuxResult"):FireClient(player, key, false, reason, 0)
        end
    end)

    -- [D61, partea 2] POARTA SATELOR. Lista celor din balci, fotografia unui sat, intoarcerea si like-ul. Toate pe
    -- aceeasi limita; userId-ul e verificat ca la cardul altui om (intreg finit), restul il hotaraste VisitService.
    Net.Get("VisitList").OnServerEvent:Connect(function(player: Player)
        if not RateLimiter.Allow(player, "Visit") then
            return
        end
        Net.Get("VisitList"):FireClient(player, deps.Visits.List(player))
    end)
    Net.Get("VisitLook").OnServerEvent:Connect(function(player: Player, userId: unknown)
        if not RateLimiter.Allow(player, "Visit") or not isInteger(userId) then
            return
        end
        local ok, reason, payload = deps.Visits.Look(player, userId :: number)
        Net.Get("VisitLookResult"):FireClient(player, ok, reason, payload)
    end)
    Net.Get("VisitLeave").OnServerEvent:Connect(function(player: Player)
        if not RateLimiter.Allow(player, "Visit") then
            return
        end
        deps.Visits.Leave(player)
    end)
    Net.Get("VisitLike").OnServerEvent:Connect(function(player: Player, userId: unknown)
        if not RateLimiter.Allow(player, "Visit") or not isInteger(userId) then
            return
        end
        local ok, reason, likes = deps.Visits.Like(player, userId :: number)
        Net.Get("VisitLikeResult"):FireClient(player, ok, reason, likes)
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

    -- [D61] Gheretele: jocul incepe pe server (samanta, ora), se joaca pe client, se socoteste pe server.
    Net.Get("BoothStart").OnServerEvent:Connect(function(player: Player, game: unknown)
        if not RateLimiter.Allow(player, "Booth") then
            return
        end
        if game ~= "ring" and game ~= "duck" then
            return
        end
        local ok, reason, seed, left = deps.Booth.Start(player, game :: string)
        if ok then
            Net.Get("BoothStarted"):FireClient(player, game, seed, left)
        else
            Net.Get("BoothStarted"):FireClient(player, game, nil, reason)
        end
    end)
    Net.Get("BoothFinish").OnServerEvent:Connect(function(player: Player, presses: unknown)
        if not RateLimiter.Allow(player, "Booth") then
            return
        end
        if typeof(presses) ~= "table" or #(presses :: { any }) > 8 then
            return
        end
        local ok, reason, result = deps.Booth.Finish(player, presses)
        Net.Get("BoothResult"):FireClient(player, ok, reason, result)
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

    -- [D71] Fusul orar al jucatorului, pentru ziua seriei zilnice: numar validat (StreakMath.cleanOffset) si limitat; se
    -- schimba cel mult o data pe zi UTC. Daca a numarat ziua de azi dupa el, starea pleaca din nou.
    Net.Get("SetClock").OnServerEvent:Connect(function(player: Player, offset: any)
        if typeof(offset) ~= "number" or not RateLimiter.Allow(player, "Clock") then
            return
        end
        if deps.Data.SetStreakClock(player, offset) then
            FairNetServer.PushState(player)
        end
    end)

    Players.PlayerRemoving:Connect(function(player: Player)
        RateLimiter.Forget(player)
        pending[player] = nil
    end)
end

return FairNetServer
