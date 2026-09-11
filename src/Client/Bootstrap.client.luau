--!strict
-- Client bootstrap: dezactiveaza lumea 3D, creeaza ScreenGui-urile radacina, initializeaza controller-ele [DECIZII D04, D05, D06]
-- Rescris pentru tycoon [F0 spec 4.1]: Dashboard/SettlerPanel/Build/Objective/EventBanner/
-- BuildingRender/BuildingCard si intro-ul au disparut o data cu colonia. WelcomeController,
-- DialogueController si SettlerRenderController raman in depozit (fisierele exista, dar nu se
-- mai leaga aici) -- se intorc in F1.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterGui = game:GetService("StarterGui")
local Workspace = game:GetService("Workspace")

local Net = require(ReplicatedStorage.Net.Net)
local RiverConfig = require(ReplicatedStorage.Shared.Config.RiverConfig)
local HUDController = require(script.Parent.Controllers.HUDController)
local IndexController = require(script.Parent.Controllers.IndexController)
local RiverRenderController = require(script.Parent.Controllers.RiverRenderController)
local NetController = require(script.Parent.Controllers.NetController)
local DockController = require(script.Parent.Controllers.DockController)
local PadController = require(script.Parent.Controllers.PadController)
local WorkshopController = require(script.Parent.Controllers.WorkshopController)
local UserInputService = game:GetService("UserInputService")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui") :: PlayerGui

-- Lumea 3D nu exista: camera fixa, CoreGui minim (topbar-ul ramane, D04)
local camera = Workspace.CurrentCamera
camera.CameraType = Enum.CameraType.Scriptable
camera.CFrame = CFrame.new(0, 1000, 0)
pcall(function()
    StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.All, false)
end)

local function makeRoot(name: string, displayOrder: number, insets: Enum.ScreenInsets): ScreenGui
    local gui = Instance.new("ScreenGui")
    gui.Name = name
    gui.ScreenInsets = insets -- HUD sub topbar (CoreUISafeInsets), lumea pe tot ecranul [DECIZII D06]
    gui.ResetOnSpawn = false
    gui.DisplayOrder = displayOrder
    gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    gui.Parent = playerGui
    return gui
end

-- HUD: scara dupa ecran, cu podea ca sa ramana citibil pe telefon [DECIZII D06].
-- Lumea NU mai foloseste asta: scara ei o calculeaza CameraController din viewport-ul real.
local hudScale = 1

-- Panza HUD acopera EXACT ecranul la scara curenta. Varianta veche o tinea fixa la 1920x1080:
-- cu podeaua de scara de 0.62, pe un ecran mic panza iesea din ecran, iar tot ce e ancorat la
-- dreapta (butoanele de inchidere ale panourilor, bara de meniu) ajungea in afara si nu se mai
-- putea apasa. Pozitiile in fractiuni raman corecte, cele in pixeli raman fata de coltul lor.
local function attachHudScale(gui: ScreenGui): Frame
    local canvas = Instance.new("Frame")
    canvas.Name = "Canvas"
    canvas.BackgroundTransparency = 1
    local scale = Instance.new("UIScale")
    -- Referinta de ecran: aceeasi 1920x1080 din RiverConfig ca inainte (EconomyConfig, care o
    -- purta, a disparut o data cu colonia -- vezi F0 spec 3.8).
    local ref = Vector2.new(RiverConfig.SCREEN_WIDTH, RiverConfig.SCREEN_HEIGHT)
    local function update()
        local vp = camera.ViewportSize
        hudScale = math.max(0.62, math.min(vp.X / ref.X, vp.Y / ref.Y))
        scale.Scale = hudScale
        canvas.Size = UDim2.fromOffset(math.ceil(vp.X / hudScale), math.ceil(vp.Y / hudScale))
    end
    update()
    camera:GetPropertyChangedSignal("ViewportSize"):Connect(update)
    scale.Parent = canvas
    canvas.Parent = gui
    return canvas
end

-- Lumea se deseneaza din margine in margine (ScreenInsets.None): altfel raman benzi nepictate
-- langa crestatura si marginile telefonului. Doar HUD-ul sta in zona sigura.
local worldGui = makeRoot("World", 1, Enum.ScreenInsets.None)
local hudGui = makeRoot("HUD", 2, Enum.ScreenInsets.CoreUISafeInsets) -- static; ScreenGui separat [D05]
-- Fundal care umple mereu ecranul: fara el, marginile lumii lasa sa se vada cerul 3D
local backdrop = Instance.new("Frame")
backdrop.Name = "Backdrop"
backdrop.Size = UDim2.fromScale(1, 1)
backdrop.BackgroundColor3 = Color3.fromRGB(58, 92, 48)
backdrop.BorderSizePixel = 0
backdrop.ZIndex = 0
backdrop.Parent = worldGui

local hudCanvas = attachHudScale(hudGui)

local CameraController = require(script.Parent.Controllers.CameraController)
local CharacterController = require(script.Parent.Controllers.CharacterController)
local DevPanelController = require(script.Parent.Controllers.DevPanelController)
local MenuBarController = require(script.Parent.Controllers.MenuBarController)
local Panels = require(script.Parent.Controllers.Panels)
local layers = CameraController.Init({ WorldGui = worldGui })

-- O eroare intr-un controller nu mai opreste restul bootstrap-ului; eroarea apare in Output
local function safeInit(name: string, fn: () -> ())
    local ok, err = pcall(fn)
    if not ok then
        warn(`[Driftwood] {name} a esuat: {err}`)
    end
end

safeInit("CharacterController", function()
    CharacterController.Init({
        Scroll = layers.Scroll,
        OnMove = CameraController.Follow,
        OnPlayerInput = function()
            -- daca te misti tu, camera se intoarce la personajul tau
            CameraController.SetFocus(nil)
        end,
    })
end)
safeInit("RiverRenderController", function()
    RiverRenderController.Init({
        Layers = layers,
        RiverConfig = Net.Get("RiverConfig"),
    })
end)
safeInit("PadController", function()
    PadController.Init({
        Scroll = layers.Scroll,
        Remotes = {
            BuyPad = Net.Get("BuyPad"),
            PadBought = Net.Get("PadBought"),
            PadRejected = Net.Get("PadRejected"),
        },
        CharacterPos = CharacterController.Position,
        OnToast = HUDController.Toast,
    })
end)
safeInit("DockController", function()
    DockController.Init({
        Scroll = layers.Scroll,
        Remotes = {
            SellSack = Net.Get("SellSack"),
            Sold = Net.Get("Sold"),
        },
        CharacterPos = CharacterController.Position,
    })
end)
safeInit("NetController", function()
    NetController.Init({
        Scroll = layers.Scroll,
        Remotes = {
            CollectNet = Net.Get("CollectNet"),
            NetCaught = Net.Get("NetCaught"),
        },
        CharacterPos = CharacterController.Position,
        OnToast = HUDController.Toast,
    })
end)

HUDController.Init({
    HudGui = hudCanvas,
    SetStick = CharacterController.SetStick,
    PanelsOpen = Panels.AnyOpen,
    Interact = function()
        NetController.Interact()
    end,
})
safeInit("WorkshopController", function()
    WorkshopController.Init({
        HudGui = hudCanvas,
        Remotes = {
            RequestWorkshop = Net.Get("RequestWorkshop"),
            WorkshopState = Net.Get("WorkshopState"),
            StartRepair = Net.Get("StartRepair"),
            CollectRepair = Net.Get("CollectRepair"),
            ScrapItem = Net.Get("ScrapItem"),
            WorkshopRejected = Net.Get("WorkshopRejected"),
        },
        OnToast = HUDController.Toast,
    })
end)
safeInit("IndexController", function()
    IndexController.Init({
        HudGui = hudCanvas,
        Remotes = {
            WorkshopState = Net.Get("WorkshopState"),
            RequestWorkshop = Net.Get("RequestWorkshop"),
        },
    })
    -- rasplata reparatiei: obiectul care tocmai a intrat in colectie se arata cu numele lui
    Net.Get("RepairDone").OnClientEvent:Connect(function(catalogId: string)
        IndexController.Celebrate(catalogId)
    end)
end)

-- Escape apartine meniului platformei si nu ajunge niciodata la joc. Q inchide panourile.
UserInputService.InputBegan:Connect(function(input: InputObject, processed: boolean)
    if processed then
        return
    end
    if input.KeyCode == Enum.KeyCode.Q or input.KeyCode == Enum.KeyCode.Escape then
        WorkshopController.Close()
        IndexController.Close()
    end
end)

safeInit("MenuBarController", function()
    MenuBarController.Init({
        HudGui = hudCanvas,
        -- Colectia e mereu deschisa in F0; Workshop-ul ramane in cod dar ascuns pana in F1
        -- (nu exista inca o cladire de atelier in lumea tycoon-ului) [F0 spec 4.7].
        IsUnlocked = function(_name: string): boolean
            return true
        end,
        Entries = {
            {
                name = "index",
                icon = "crate",
                label = "Collection",
                key = "C",
                open = IndexController.Toggle,
            },
        },
    })
end)

safeInit("DevPanelController", function()
    DevPanelController.Init({
        HudGui = hudCanvas,
        DevCommand = Net.Get("DevCommand"),
        Diagnostics = function(): string
            local vp = camera.ViewportSize
            local vw, vh = CameraController.VisibleSize()
            local cx, cy = CameraController.WorldOrigin()
            return string.format(
                "%d fps | vp %dx%d | scale %.2f | visible %dx%d | cam %d,%d | river objects %d",
                HUDController.Perf(),
                vp.X,
                vp.Y,
                CameraController.Scale(),
                vw,
                vh,
                cx,
                cy,
                RiverRenderController.VisibleCount()
            )
        end,
    })
end)

-- Starea intreaga a tycoon-ului, inlocuita in intregime la fiecare mesaj -- niciodata combinata
-- camp cu camp cu ce era inainte [F0 spec 4.1, CLAUDE.md capcana 3]. Fiecare controller primeste
-- doar campurile de care are nevoie, copiate explicit.
Net.Get("TycoonState").OnClientEvent:Connect(function(raw: { [string]: any })
    -- `pads` e o harta plata (id -> statut): table.clone o inlocuieste in intregime dintr-o
    -- lovitura, exact "wholesale". Bucla explicita de mai jos, pe `nets`, ramane pentru ca acolo
    -- fiecare intrare are mai multe campuri numite -- genul de structura unde s-au pierdut campuri
    -- inainte [CLAUDE.md capcana 3].
    local pads: { [string]: string } = table.clone(raw.pads)
    local nets: { NetController.NetSnap } = {}
    for i, n in raw.nets do
        nets[i] = {
            padId = n.padId,
            lane = n.lane,
            x = n.x,
            y = n.y,
            count = n.count,
            capacity = n.capacity,
            nextCatchAt = n.nextCatchAt,
            interval = n.interval,
        }
    end
    local sack = raw.sack
    local sackCount, sackCapacity, sackValue = sack.count, sack.capacity, sack.value

    HUDController.SetCoins(raw.coins)
    HUDController.SetIncome(raw.incomePerSec)
    HUDController.SetSack(sackCount, sackCapacity)
    PadController.Apply(pads, raw.coins)
    NetController.Apply(nets, sackCount, sackCapacity)
    DockController.Apply(sackCount, sackCapacity, sackValue)
end)

-- cerem starea de cateva ori: primul mesaj se poate pierde daca serverul nu e gata
Net.Get("RequestState"):FireServer()
Net.Get("RequestWorkshop"):FireServer()
task.delay(1, function()
    Net.Get("RequestState"):FireServer()
    Net.Get("RequestWorkshop"):FireServer()
end)
task.delay(3, function()
    Net.Get("RequestState"):FireServer()
end)

print("[Driftwood] client bootstrap complet")
