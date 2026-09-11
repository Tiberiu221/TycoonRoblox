--!strict
-- Client bootstrap: dezactiveaza lumea 3D, creeaza ScreenGui-urile radacina, initializeaza controller-ele [DECIZII D04, D05, D06]
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterGui = game:GetService("StarterGui")
local Workspace = game:GetService("Workspace")

local Net = require(ReplicatedStorage.Net.Net)
local BuildingConfig = require(ReplicatedStorage.Shared.Config.BuildingConfig)
local EconomyConfig = require(ReplicatedStorage.Shared.Config.EconomyConfig)
local RiverConfig = require(ReplicatedStorage.Shared.Config.RiverConfig)
local HUDController = require(script.Parent.Controllers.HUDController)
local IndexController = require(script.Parent.Controllers.IndexController)
local RiverRenderController = require(script.Parent.Controllers.RiverRenderController)
local SceneArt = require(script.Parent.Controllers.SceneArt)
local NetController = require(script.Parent.Controllers.NetController)
local WelcomeController = require(script.Parent.Controllers.WelcomeController)
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
    local function update()
        local vp = camera.ViewportSize
        local ref = EconomyConfig.REFERENCE_RESOLUTION
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
local SettlerRenderController = require(script.Parent.Controllers.SettlerRenderController)
local SettlerPanelController = require(script.Parent.Controllers.SettlerPanelController)
local BuildingRenderController = require(script.Parent.Controllers.BuildingRenderController)
local BuildingCardController = require(script.Parent.Controllers.BuildingCardController)
local BuildController = require(script.Parent.Controllers.BuildController)
local DashboardController = require(script.Parent.Controllers.DashboardController)
local EventBannerController = require(script.Parent.Controllers.EventBannerController)
local DevPanelController = require(script.Parent.Controllers.DevPanelController)
local DialogueController = require(script.Parent.Controllers.DialogueController)
local MenuBarController = require(script.Parent.Controllers.MenuBarController)
local ObjectiveController = require(script.Parent.Controllers.ObjectiveController)
local Panels = require(script.Parent.Controllers.Panels)
local layers = CameraController.Init({ WorldGui = worldGui })

-- Pozitia santierului cel mai avansat. Fara asta sageata arata spre centrul terenului, adica
-- spre iarba goala, si deruteaza mai tare decat daca ar lipsi.
local function sitePos(): (number?, number?)
    local best, bestProgress = nil, -1
    for _, b in BuildingRenderController.List() do
        local d = BuildingConfig.get(b.defId)
        if d ~= nil and b.progress < d.buildWork and b.progress > bestProgress then
            best, bestProgress = b, b.progress
        end
    end
    if best == nil then
        return nil, nil
    end
    local d = BuildingConfig.get(best.defId) :: BuildingConfig.Def
    return best.x + d.w * RiverConfig.TILE / 2, best.y
end

-- Pozitia atelierului TERMINAT, din starea serverului. Folosita si de promptul de interactiune,
-- si de semnul de obiectiv: constanta din RiverConfig e o ramasita de la prototip.
local function workshopPos(): (number?, number?)
    for _, b in BuildingRenderController.List() do
        if b.defId == "workshop" then
            local d = BuildingConfig.get(b.defId)
            if d ~= nil and b.progress >= d.buildWork then
                return b.x + d.w * RiverConfig.TILE / 2, b.y + d.h * RiverConfig.TILE
            end
        end
    end
    return nil, nil
end

-- O eroare intr-un controller nu mai opreste restul bootstrap-ului; eroarea apare in Output
local function safeInit(name: string, fn: () -> ())
    local ok, err = pcall(fn)
    if not ok then
        warn(`[Driftwood] {name} a esuat: {err}`)
    end
end

HUDController.Init({
    HudGui = hudCanvas,
    VisibleCount = RiverRenderController.VisibleCount,
    SettlerCount = SettlerRenderController.VisibleCount,
    Diagnostics = function(): string
        local vp = camera.ViewportSize
        local vw, vh = CameraController.VisibleSize()
        local cx, cy = CameraController.WorldOrigin()
        return string.format(
            "vp %dx%d | scale %.2f | visible %dx%d | cam %d,%d | buildings %d",
            vp.X,
            vp.Y,
            CameraController.Scale(),
            vw,
            vh,
            cx,
            cy,
            #BuildingRenderController.List()
        )
    end,
    SetStick = CharacterController.SetStick,
    PanelsOpen = Panels.AnyOpen,
    Interact = function()
        NetController.Interact()
    end,
})
safeInit("RiverRenderController", function()
    RiverRenderController.Init({
        Layers = layers,
        RiverConfig = Net.Get("RiverConfig"),
        ObjectCaught = Net.Get("ObjectCaught"),
    })
end)
safeInit("NetController", function()
    NetController.Init({
        Scroll = layers.Scroll,
        Remotes = {
            PlaceNet = Net.Get("PlaceNet"),
            NetPlaced = Net.Get("NetPlaced"),
            NetRejected = Net.Get("NetRejected"),
            CollectNet = Net.Get("CollectNet"),
            NetCollected = Net.Get("NetCollected"),
            ObjectCaught = Net.Get("ObjectCaught"),
            StateSnapshot = Net.Get("StateSnapshot"),
        },
        CharacterPos = CharacterController.Position,
        WorkshopPos = workshopPos,
        OnInventory = HUDController.SetInventory,
        OnToast = HUDController.Toast,
        OnWorkshop = function()
            WorkshopController.Open()
        end,
    })
end)
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
local currentMaterials = 0
Net.Get("WorkshopState").OnClientEvent:Connect(function(s: { [string]: any })
    currentMaterials = s.materials or 0
    local repaired = 0
    for _, n in s.repaired do
        repaired += n
    end
    HUDController.SetWorkshop(#s.pile, repaired, s.materials)
end)
-- Escape apartine meniului platformei si nu ajunge niciodata la joc. Q inchide panourile.
UserInputService.InputBegan:Connect(function(input: InputObject, processed: boolean)
    if processed then
        return
    end
    if input.KeyCode == Enum.KeyCode.Q or input.KeyCode == Enum.KeyCode.Escape then
        for _, close in
            {
                WorkshopController.Close,
                BuildController.CloseMenu,
                SettlerPanelController.Close,
                DashboardController.Close,
            }
        do
            close()
        end
    end
end)
Net.Get("RequestWorkshop"):FireServer()
safeInit("SettlerRenderController", function()
    SettlerRenderController.Init({
        Scroll = layers.Scroll,
        SettlersFull = Net.Get("SettlersFull"),
        SettlerPaths = Net.Get("SettlerPaths"),
        SettlerLeft = Net.Get("SettlerLeft"),
        OnToast = HUDController.Toast,
    })
end)
safeInit("BuildingRenderController", function()
    BuildingRenderController.Init({
        Scroll = layers.Scroll,
        BuildingsState = Net.Get("BuildingsState"),
        -- apasatul pe cladire deschide cartonasul ei. Nu si cat timp asezi alta cladire
        -- (clicul ala inseamna "pune-o aici") sau cat timp cineva vorbeste cu jucatorul.
        OnSelect = function(id: number)
            if BuildController.IsPlacing() or DialogueController.IsActive() then
                return
            end
            BuildingCardController.Show(id)
        end,
    })
    -- coliziunea jucatorului urmeaza cladirile reale, nu lista de prototip din RiverConfig
    Net.Get("BuildingsState").OnClientEvent:Connect(function(list: { { [string]: any } })
        CharacterController.SetBuildings(list)
    end)
end)
safeInit("BuildingCardController", function()
    BuildingCardController.Init({
        Scroll = layers.Scroll,
        GetSettlers = SettlerRenderController.List,
        GetBuildings = BuildingRenderController.List,
        Open = { workshop = WorkshopController.Toggle },
        IsUnlocked = ObjectiveController.IsUnlocked,
    })
end)
safeInit("BuildController", function()
    BuildController.Init({
        HudGui = hudCanvas,
        Scroll = layers.Scroll,
        CameraX = CameraController.WorldOrigin,
        PlaceBuilding = Net.Get("PlaceBuilding"),
        Materials = function()
            return currentMaterials
        end,
        Buildings = BuildingRenderController.List,
        OnToast = HUDController.Toast,
    })
end)
CameraController.OnScaleChanged(BuildController.SetScale)
Net.Get("BuildRejected").OnClientEvent:Connect(function(reason: string)
    HUDController.Toast(`Cannot build: {reason}`)
end)
Net.Get("BuildingDone").OnClientEvent:Connect(function(label: string)
    HUDController.Toast(`{label} finished!`)
end)
Net.Get("SettlerArrived").OnClientEvent:Connect(function(name: string, job: string)
    HUDController.Toast(`{name} arrived by boat — {job}`)
    -- si pe apa: obiectivul spune "uita-te la apa", deci acolo trebuie sa se vada ceva
    SceneArt.ArrivalBoat(layers.Scroll, name)
end)
safeInit("SettlerPanelController", function()
    SettlerPanelController.Init({
        HudGui = hudCanvas,
        GetSettlers = SettlerRenderController.List,
        PositionOf = SettlerRenderController.PositionOf,
        OnSelect = SettlerRenderController.SetSelected,
        OnAlert = HUDController.SetAlert,
        GetBuildings = BuildingRenderController.List,
        SetJob = function(id: number, job: string)
            Net.Get("SetSettlerJob"):FireServer(id, job)
        end,
    })
end)
safeInit("CharacterController", function()
    CharacterController.Init({
        Scroll = layers.Scroll,
        OnMove = CameraController.Follow,
        OnPlayerInput = function()
            -- daca te misti tu, camera si selectia se intorc la personajul tau
            CameraController.SetFocus(nil)
            SettlerPanelController.ClearSelection()
        end,
    })
end)
Net.Get("ColonyStats").OnClientEvent:Connect(function(s: { [string]: any })
    HUDController.SetColony(s.population or 0, s.beds or 0)
    HUDController.SetFood(s.food or 0, s.hungry == true)
end)
safeInit("DashboardController", function()
    DashboardController.Init({
        HudGui = hudCanvas,
        ColonyStats = Net.Get("ColonyStats"),
        RequestColony = Net.Get("RequestColony"),
        ObjectiveState = Net.Get("ObjectiveState"),
    })
end)
safeInit("EventBannerController", function()
    EventBannerController.Init({
        HudGui = hudCanvas,
        ColonyEvent = Net.Get("ColonyEvent"),
    })
end)
safeInit("DialogueController", function()
    DialogueController.Init({ HudGui = hudCanvas })

    -- Deschiderea: jucatorul e blocat cat timp colonistul vine si vorbeste. Plasa de siguranta e
    -- si aici, nu doar pe server: daca replica nu ajunge in 14 secunde, controlul se da inapoi.
    local introToken = 0
    Net.Get("IntroBegin").OnClientEvent:Connect(function()
        introToken += 1
        local token = introToken
        CharacterController.SetLocked(true)
        ObjectiveController.SetHidden(true)
        MenuBarController.SetHidden(true)
        task.delay(14, function()
            if token == introToken and not DialogueController.IsActive() then
                CharacterController.SetLocked(false)
                ObjectiveController.SetHidden(false)
                MenuBarController.SetHidden(false)
            end
        end)
    end)
    Net.Get("IntroTalk").OnClientEvent:Connect(function(speaker: string, sceneId: string)
        introToken += 1
        CharacterController.SetLocked(true)
        -- infatisarea vorbitorului, ca portretul sa fie CHIAR omul care a venit la tine pe mal,
        -- nu o foaie generica. Il cautam dupa nume printre colonistii pe care ii are clientul.
        local look: { [string]: any }? = nil
        for _, p in SettlerRenderController.List() do
            if p.name == speaker then
                look = p
                break
            end
        end
        DialogueController.Play(speaker, sceneId, look, function()
            CharacterController.SetLocked(false)
            ObjectiveController.SetHidden(false)
            MenuBarController.SetHidden(false)
            Net.Get("IntroDone"):FireServer()
        end)
    end)
end)
safeInit("ObjectiveController", function()
    ObjectiveController.Init({
        HudGui = hudCanvas,
        Scroll = layers.Scroll,
        SlotPos = NetController.SlotPos,
        ObjectiveState = Net.Get("ObjectiveState"),
        ObjectiveDone = Net.Get("ObjectiveDone"),
        RequestObjectives = Net.Get("RequestObjectives"),
        PlayerPos = CharacterController.Position,
        HudScale = function(): number
            return hudScale
        end,
        OnToast = HUDController.Toast,
        -- unde arata sageata pentru fiecare fel de sarcina, calculat din starea vie
        Targets = {
            net_slot = function(): (number?, number?)
                local p = NetController.FreeSlotPos()
                return if p ~= nil then p.X else nil, if p ~= nil then p.Y else nil
            end,
            net = function(): (number?, number?)
                local p = NetController.FullNetPos()
                return if p ~= nil then p.X else nil, if p ~= nil then p.Y else nil
            end,
            workshop = workshopPos,
            build = sitePos,
            site = sitePos,
            -- acolo unde trage barca, nu in mijlocul lumii: sageata si barca trebuie sa arate
            -- acelasi loc, altfel pasul "uita-te la apa" trimite jucatorul aiurea
            river = function(): (number?, number?)
                return RiverConfig.LANDING.x, RiverConfig.LANDING.y
            end,
        },
        -- ce deschide fiecare sarcina cand apesi pe cartonas
        Openers = {
            workshop = WorkshopController.Toggle,
            build = BuildController.ToggleMenu,
            people = SettlerPanelController.Toggle,
            colony = DashboardController.Toggle,
        },
        OnUnlockChanged = function()
            MenuBarController.Refresh()
        end,
        -- sarcina curenta aprinde inelul pe butonul care trebuie apasat
        OnMarkerPanel = MenuBarController.Highlight,
    })
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
    -- atelierul se ghideaza singur dupa pasul curent: aprinde Scrap, opreste Repair
    WorkshopController.SetStepSource(ObjectiveController.CurrentStepId)
    MenuBarController.Init({
        HudGui = hudCanvas,
        IsUnlocked = ObjectiveController.IsUnlocked,
        Entries = {
            {
                name = "build",
                icon = "build",
                label = "Build",
                key = "B",
                open = BuildController.ToggleMenu,
            },
            {
                name = "people",
                icon = "people",
                label = "People",
                key = "Tab",
                open = SettlerPanelController.Toggle,
            },
            {
                name = "index",
                icon = "crate",
                label = "Collection",
                key = "C",
                open = IndexController.Toggle,
            },
            {
                name = "workshop",
                icon = "hammer",
                label = "Workshop",
                -- E merge doar langa cladire; butonul asta merge de oriunde
                key = "click",
                open = WorkshopController.Toggle,
            },
            {
                name = "colony",
                icon = "colony",
                label = "Colony",
                key = "C",
                open = DashboardController.Toggle,
            },
        },
    })
    -- panourile mari se deschid pe rand, pe masura ce obiectivele le deblocheaza
    Panels.SetGate(function(name: string): boolean
        -- nimic nu se deschide peste o discutie: ecranul e al ei pana se termina
        if DialogueController.IsActive() then
            return false
        end
        return ObjectiveController.IsUnlocked(name)
    end, function(name: string)
        local what = if name == "build"
            then "Building opens once you have materials."
            elseif name == "people" then "The people list opens after your first build."
            elseif name == "colony" then "The colony board opens once your settlement grows."
            else "Not yet — follow the task on the left."
        HUDController.Toast(what)
    end)
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
                "%d fps | vp %dx%d | scale %.2f | visible %dx%d | cam %d,%d | objects %d | settlers %d | buildings %d",
                HUDController.Perf(),
                vp.X,
                vp.Y,
                CameraController.Scale(),
                vw,
                vh,
                cx,
                cy,
                RiverRenderController.VisibleCount(),
                SettlerRenderController.VisibleCount(),
                #BuildingRenderController.List()
            )
        end,
    })
end)
safeInit("WelcomeController", function()
    WelcomeController.Init({
        HudGui = hudCanvas,
        WelcomeBack = Net.Get("WelcomeBack"),
        CollectNet = Net.Get("CollectNet"),
    })
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
