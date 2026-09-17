--!strict
-- [D60] BARCA SPRE CASA, in balci. Aceeasi barca cu care ai venit sta la debarcader; langa ea, cardul scrie
-- `Row home (E)`. Drumul pictat (UI/RideScene) merge acum in aval, cu curentul, iar la capat se vad casele si felinarele
-- satului. Pe negru, serverul te duce acasa (FerryService); satul te primeste cu banii de cat ai lipsit, ca offline.
-- Daca barca nu pleaca, ramai in balci, iar toastul spune de ce [D43].
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local Strings = require(ReplicatedStorage.Shared.Config.Strings)

local CharacterController = require(script.Parent.CharacterController)
local FairScene = require(script.Parent.FairScene)
local Panels = require(script.Parent.Panels)
local SoundController = require(script.Parent.SoundController)
local Focus = require(script.Parent.Parent.UI.Focus)
local RideScene = require(script.Parent.Parent.UI.RideScene)
local Theme = require(script.Parent.Parent.UI.Theme)

export type Deps = {
    PlayerGui: PlayerGui,
    Remotes: { RowHome: RemoteEvent, FerryFailed: RemoteEvent },
    OnToast: (string, Color3?) -> (),
}

local FairFerryController = {}
local deps: Deps? = nil

-- de unde urci: pe mal, in dreapta capatului debarcaderului, langa barca (apa incepe la FairLayout.WATER_Y)
local BOARD = { x = 880, y = 1500 }
local BOARD_DISTANCE = 90
local WAIT_LIMIT = 35
local visits = 0
local outfit = "keeper"
local ferryX, ferryY, _, ferryH = 0, 0, 0, 0

local function boat(): ImageLabel?
    return FairScene.SpriteOf("ferry")
end

local function place(x: number, y: number, visible: boolean)
    local b = boat()
    if b ~= nil then
        b.Position = UDim2.fromOffset(x, y)
        b.Visible = visible
    end
end

local function comeBack(reason: string)
    local d = deps
    if d == nil or RideScene.State() ~= "waiting" then
        return
    end
    place(ferryX, ferryY, true)
    CharacterController.SetHidden(false)
    CharacterController.SetLocked(false)
    RideScene.ComeBack()
    d.OnToast(Strings.ferryFailed(reason), Theme.COLOR.warn)
end

function FairFerryController.Focus(px: number, py: number): Focus.Focus?
    if deps == nil or RideScene.State() ~= "idle" then
        return nil
    end
    local distance = Focus.distance(px, py, BOARD.x, BOARD.y)
    if distance > BOARD_DISTANCE then
        return nil
    end
    local keyHint = if UserInputService.KeyboardEnabled then " (E)" else ""
    return {
        key = "ferry",
        distance = distance,
        -- deasupra barcii si a placutei ei, in dreapta locului de urcat (omul nu sta sub card)
        x = ferryX + 30,
        y = ferryY - ferryH - 30,
        action = Strings.fairRowHomeCard(keyHint),
        act = FairFerryController.Board,
    }
end

function FairFerryController.Board()
    local d = deps
    if d == nil then
        return
    end
    local started = RideScene.Start({
        Outfit = outfit,
        CanSkip = visits > 1, -- prima vizita e si primul drum inapoi
        OnPushOff = function(k: number)
            place(ferryX + 24 * k, ferryY + 12 * k, true)
        end,
        OnLeft = function()
            place(ferryX, ferryY, false)
        end,
        OnArrived = function()
            d.Remotes.RowHome:FireServer()
        end,
    })
    if not started then
        return
    end
    Panels.CloseAll()
    CharacterController.SetLocked(true)
    CharacterController.SetHidden(true)
    SoundController.Play("splash", 0.8)
end

-- Din FairState: tinuta cu care stai in barca si de cate ori ai ajuns in balci.
function FairFerryController.Apply(newOutfit: string, fairVisits: number)
    outfit = newOutfit
    visits = fairVisits
end

function FairFerryController.Init(d: Deps)
    deps = d
    ferryX, ferryY, _, ferryH = FairScene.Spot("ferry")
    RideScene.Init({
        PlayerGui = d.PlayerGui,
        Upstream = false,
        RowingText = Strings.FAIR_ROWING_HOME,
        Destination = "village",
    })
    d.Remotes.FerryFailed.OnClientEvent:Connect(function(reason: unknown)
        comeBack(if typeof(reason) == "string" then reason else "failed")
    end)
    RunService.Heartbeat:Connect(function()
        if RideScene.WaitingFor() > WAIT_LIMIT then
            comeBack("timeout")
        end
    end)
end

return FairFerryController
