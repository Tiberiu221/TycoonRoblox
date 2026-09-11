--!strict
-- Deschiderea jocului: primul colonist vine LA jucator si ii vorbeste [RIVERKEEP 2].
--
-- De ce e un serviciu separat si nu inca o linie in altul: e singura secventa din joc in care
-- controlul ii e luat jucatorului. Orice loc unde jucatorul poate ramane blocat trebuie sa aiba
-- o iesire evidenta, si e mai usor sa garantezi asta cand toata secventa sta intr-un fisier.
--
-- Plasa de siguranta: daca colonistul nu poate ajunge (drum blocat, hartă schimbata), dupa
-- cateva secunde se vorbeste oricum. Jucatorul NU ramane blocat, indiferent ce se intampla.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local RiverConfig = require(ReplicatedStorage.Shared.Config.RiverConfig)
local DataService = require(script.Parent.DataService)
local SettlerService = require(script.Parent.SettlerService)

local WALK_TIMEOUT = 7 -- dupa atat, se vorbeste chiar daca nu a ajuns
local STAND_OFFSET = 76 -- cat de aproape sta de jucator: destul cat sa nu se suprapuna

local IntroService = {}
local deps: { Remotes: { [string]: RemoteEvent } }
local running = false

local function play(player: Player, name: string)
    local remote = deps.Remotes.IntroTalk
    if remote ~= nil then
        remote:FireClient(player, name, "intro")
    end
end

function IntroService.Start(player: Player)
    if running then
        return
    end
    local data = DataService.Get(player)
    if data == nil then
        return
    end
    running = true

    local name = SettlerService.FirstName() or "A newcomer"
    local begin = deps.Remotes.IntroBegin
    if begin ~= nil then
        begin:FireClient(player)
    end

    local spoken = false
    local function speak()
        if spoken then
            return
        end
        spoken = true
        play(player, name)
    end

    SettlerService.OnGreetArrived(function()
        speak()
    end)
    local walking = SettlerService.SendToGreet(
        RiverConfig.CHARACTER.START_X + STAND_OFFSET,
        RiverConfig.CHARACTER.START_Y
    )
    if not walking then
        -- nu are drum: vorbim pe loc, mai bine o replica fara plimbare decat un jucator blocat
        speak()
        return
    end
    task.delay(WALK_TIMEOUT, speak)
end

function IntroService.Finish(player: Player)
    if not running then
        return
    end
    running = false
    SettlerService.EndGreet()
    local data = DataService.Get(player)
    if data ~= nil then
        data.Firsts.Intro = true
    end
end

function IntroService.Init(d: typeof(deps))
    deps = d

    if deps.Remotes.IntroDone ~= nil then
        deps.Remotes.IntroDone.OnServerEvent:Connect(function(player: Player)
            IntroService.Finish(player)
        end)
    end

    DataService.ProfileLoaded:Connect(function(player: Player)
        local data = DataService.Get(player)
        if data == nil or data.Firsts.Intro then
            return
        end
        -- lasam clientul sa termine bootstrap-ul si camera sa se aseze
        task.delay(1.2, function()
            if player.Parent == Players then
                IntroService.Start(player)
            end
        end)
    end)
end

return IntroService
