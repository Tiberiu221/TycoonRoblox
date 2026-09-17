--!strict
-- [D60] BARCA SPRE BALCI, in sat. In pasii jucatorului:
--   1. la ponton, in aval, sta legata o barca cu felinar la prova, cu eticheta "Ferry to the Fair". Pe marginea
--      pontonului, in dreptul ei, cardul scrie `Row up to the fair (E)`;
--   2. apesi: barca se desprinde, iar ecranul trece in drumul pictat (UI/RideScene): raul in amonte, malurile care raman
--      in urma, seara care se lasa, apoi luminile balciului. Sase secunde; `Skip` apare abia de la al doilea drum;
--   3. pe negru, serverul te muta in balci (FerryService). Daca nu poate, ecranul se deschide inapoi pe ponton, iar un
--      toast spune de ce. Satul a mers tot timpul [D43].
-- In Studio teleportul nu exista: drumul se vede intreg, apoi toastul spune ca barca pleaca doar in jocul publicat.
--
-- Barca e legata cu prova in amonte, ca orice barca pe un rau: desenul are felinarul la prova in dreapta, deci se
-- oglindeste.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local Assets = require(ReplicatedStorage.Shared.Config.Assets)
local Strings = require(ReplicatedStorage.Shared.Config.Strings)
local TycoonConfig = require(ReplicatedStorage.Shared.Config.TycoonConfig)

local CharacterController = require(script.Parent.CharacterController)
local Panels = require(script.Parent.Panels)
local SoundController = require(script.Parent.SoundController)
local Focus = require(script.Parent.Parent.UI.Focus)
local RideScene = require(script.Parent.Parent.UI.RideScene)
local Theme = require(script.Parent.Parent.UI.Theme)
local Widgets = require(script.Parent.Parent.UI.Widgets)

export type Deps = {
    Plot: Frame,
    PlayerGui: PlayerGui,
    Remotes: { RowUp: RemoteEvent, FerryFailed: RemoteEvent },
    OnToast: (string, Color3?) -> (),
}

local FerryController = {}
local deps: Deps? = nil

local FERRY = TycoonConfig.FERRY
local BOARD = TycoonConfig.FERRY_BOARD
local SPRITE = Assets.fair.ferry
local BOAT_SCALE = 2 -- ca avizierul si indicatorul de pe punte
local BOAT_H = SPRITE.height * BOAT_SCALE
local BOARD_DISTANCE = 60 -- cardul apare doar pe marginea pontonului, in dreptul barcii
-- deasupra capului tau cand stai la FERRY_BOARD (picioarele la y 734, capul la 662): omul se deseneaza peste teren
local CARD_Y = BOARD.y - 78
local WAIT_LIMIT = 35 -- fara teleport si fara raspuns, ecranul se deschide inapoi (serverul renunta la 20 s)

local visits = 0
local outfit = "keeper"
local worldBoat: ImageLabel
local worldTag: TextLabel

local function showWorldBoat(visible: boolean)
    worldBoat.Position = UDim2.fromOffset(FERRY.x, FERRY.y)
    worldBoat.Visible = visible
    worldTag.Visible = visible
end

-- Barca n-a plecat: lumea revine, cu barca legata si cu tine pe ponton, iar toastul spune de ce.
local function comeBack(reason: string)
    local d = deps
    if d == nil or RideScene.State() ~= "waiting" then
        return
    end
    showWorldBoat(true)
    CharacterController.SetHidden(false)
    CharacterController.SetLocked(false)
    RideScene.ComeBack()
    d.OnToast(Strings.ferryFailed(reason), Theme.COLOR.warn)
end

-- Cardul barcii: doar pe marginea pontonului, in dreptul ei, si doar cat barca e legata.
function FerryController.Focus(px: number, py: number): Focus.Focus?
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
        x = FERRY.x,
        y = CARD_Y,
        action = Strings.ferryCard(keyHint),
        act = FerryController.Board,
    }
end

-- Urci in barca: drumul pictat porneste, iar cererea pleaca la server abia la capatul lui (pe negru).
function FerryController.Board()
    local d = deps
    if d == nil then
        return
    end
    local started = RideScene.Start({
        Outfit = outfit,
        CanSkip = visits > 0,
        OnPushOff = function(k: number)
            -- barca se desprinde de ponton si iese in rau
            worldBoat.Position = UDim2.fromOffset(FERRY.x - 24 * k, FERRY.y - 30 * k)
        end,
        OnLeft = function()
            showWorldBoat(false)
        end,
        OnArrived = function()
            d.Remotes.RowUp:FireServer()
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

-- Din TycoonState: tinuta cu care stai in barca si de cate ori ai ajuns in balci (Skip apare de la al doilea drum).
function FerryController.Apply(newOutfit: string, fairVisits: number)
    outfit = newOutfit
    visits = fairVisits
end

function FerryController.Init(d: Deps)
    deps = d
    worldBoat = Instance.new("ImageLabel")
    worldBoat.Name = "Ferry"
    worldBoat.BackgroundTransparency = 1
    worldBoat.AnchorPoint = Vector2.new(0.5, 1)
    worldBoat.Size = UDim2.fromOffset(SPRITE.width * BOAT_SCALE, BOAT_H)
    worldBoat.ZIndex = 5 -- peste barca vanzarii (4), care pleaca din spatele ei
    if Assets.has(SPRITE) then
        worldBoat.Image = Assets.url(SPRITE)
        worldBoat.ResampleMode = Enum.ResamplerMode.Pixelated
        RideScene.Mirror(worldBoat, SPRITE)
    else
        worldBoat.BackgroundTransparency = 0
        worldBoat.BackgroundColor3 = Theme.COLOR.wood
    end
    worldBoat.Parent = d.Plot

    worldTag =
        Widgets.Label(d.Plot, Strings.FERRY_TAG, Theme.TEXT.tiny, Theme.COLOR.onDark, "strong")
    worldTag.AnchorPoint = Vector2.new(0.5, 1)
    worldTag.Size = UDim2.fromOffset(
        math.ceil(Theme.textWidth(Strings.FERRY_TAG, Theme.TEXT.tiny, "strong")) + 8,
        18
    )
    worldTag.TextXAlignment = Enum.TextXAlignment.Center
    worldTag.ZIndex = 6
    Theme.punch(worldTag, 2)
    worldTag.Position = UDim2.fromOffset(FERRY.x, FERRY.y - BOAT_H - 2)
    showWorldBoat(true)

    RideScene.Init({
        PlayerGui = d.PlayerGui,
        Upstream = true,
        RowingText = Strings.FERRY_ROWING,
        Destination = "fair",
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

return FerryController
