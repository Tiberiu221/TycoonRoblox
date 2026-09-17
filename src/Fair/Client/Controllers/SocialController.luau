--!strict
-- [D61] MESELE SI WAVE. Langa o banca sau o masa libera, cardul "Sit (E)": omul trece pe loc, cu fata spre noi, desenat
-- sub mobila, iar serverul verifica locul; daca il refuza (ocupat intre timp, prea departe), te ridici si un toast spune
-- de ce. Asezat, cardul "Stand up (E)"; orice pas te ridica oricum. Wave (G sau butonul
-- din bara): bratele sus doua secunde si o mana deasupra ta; ceilalti vad tot. Nimic de aici nu da recompense: e locul
-- unde se strange lumea.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local FairLayout = require(ReplicatedStorage.Shared.Modules.FairLayout)
local RiverConfig = require(ReplicatedStorage.Shared.Config.RiverConfig)
local Strings = require(ReplicatedStorage.Shared.Config.Strings)

local CharacterController = require(script.Parent.CharacterController)
local FairScene = require(script.Parent.FairScene)
local PresenceController = require(script.Parent.PresenceController)
local SoundController = require(script.Parent.SoundController)
local Focus = require(script.Parent.Parent.UI.Focus)
local Theme = require(script.Parent.Parent.UI.Theme)

export type Deps = {
    Remotes: { Sit: RemoteEvent, Stand: RemoteEvent, Wave: RemoteEvent, SeatResult: RemoteEvent },
    OnToast: (string, Color3?) -> (),
}

local SocialController = {}
local deps: Deps? = nil
local mySeat: FairLayout.Seat? = nil
local waveUntil = 0
local waveToken = 0

local WAVE_SECONDS = 2
local HEAD = RiverConfig.CHARACTER.HEIGHT

local function standUp()
    CharacterController.StandUp()
end

-- Te-ai ridicat (orice pas sau "Stand up"): serverul afla ca locul e liber.
local function onStood()
    mySeat = nil
    local d = deps
    if d ~= nil then
        d.Remotes.Stand:FireServer()
    end
end

local function sit(seat: FairLayout.Seat)
    local d = deps
    if d == nil or CharacterController.IsSeated() then
        return
    end
    mySeat = seat
    CharacterController.SitAt(seat.x, seat.y, seat.z, onStood)
    d.Remotes.Sit:FireServer(seat.id)
    SoundController.Play("pop")
end

-- Raspunsul serverului. Primit: stai deja acolo. Refuzat: te ridici de pe locul acela (daca inca stai pe el).
local function onSeatResult(seatId: unknown, ok: unknown, reason: unknown)
    local d = deps
    if d == nil or ok == true or typeof(seatId) ~= "string" then
        return
    end
    local seated = mySeat
    if seated ~= nil and seated.id == seatId and CharacterController.IsSeated() then
        CharacterController.StandUp()
    end
    d.OnToast(
        Strings.seatRejected(if typeof(reason) == "string" then reason else ""),
        Theme.COLOR.bad
    )
end

-- Asezat: "Stand up". Altfel, cel mai apropiat loc liber: "Sit".
function SocialController.Focus(px: number, py: number): Focus.Focus?
    if deps == nil then
        return nil
    end
    local keyHint = if UserInputService.KeyboardEnabled then " (E)" else ""
    local seated = mySeat
    if seated ~= nil and CharacterController.IsSeated() then
        if os.clock() < waveUntil then
            return nil -- mana de deasupra ta ar sta sub card
        end
        return {
            key = `stand:{seated.id}`,
            distance = 0,
            x = seated.x,
            y = seated.y - HEAD - 40, -- deasupra numelui si a titlului tau
            action = Strings.standCard(keyHint),
            act = standUp,
        }
    end
    local seat, distance = FairLayout.nearestSeat(px, py, FairLayout.SEAT_REACH, function(s)
        return PresenceController.IsSeatTaken(s.x, s.y)
    end)
    if seat == nil then
        return nil
    end
    local target = seat :: FairLayout.Seat
    local _, hostY, _, hostH = FairScene.Spot(target.host)
    return {
        key = `seat:{target.id}`,
        distance = distance,
        x = target.x,
        y = hostY - hostH - 8, -- deasupra bancii sau a mesei
        action = Strings.sitCard(keyHint),
        act = function()
            sit(target)
        end,
    }
end

-- Wave: o data la doua secunde. Cu undita in mana, bratele raman pe undita; mana tot apare.
function SocialController.Wave()
    local d = deps
    local now = os.clock()
    if d == nil or now < waveUntil then
        return
    end
    waveUntil = now + WAVE_SECONDS
    d.Remotes.Wave:FireServer()
    PresenceController.WaveMine()
    if CharacterController.Task() ~= nil then
        return
    end
    CharacterController.SetTask("cheer", nil)
    waveToken += 1
    local token = waveToken
    task.delay(WAVE_SECONDS, function()
        if token == waveToken and CharacterController.Task() == "cheer" then
            CharacterController.SetTask(nil, nil)
        end
    end)
end

function SocialController.Init(d: Deps)
    deps = d
    d.Remotes.SeatResult.OnClientEvent:Connect(onSeatResult)
end

return SocialController
