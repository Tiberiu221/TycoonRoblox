--!strict
-- Client bootstrap: dezactiveaza lumea 3D, creeaza ScreenGui-urile radacina, initializeaza controller-ele [DECIZII D04, D05, D06]
-- Rescris pentru tycoon [F0 spec 4.1]: Dashboard/SettlerPanel/Build/Objective/EventBanner/
-- BuildingRender/BuildingCard si intro-ul au disparut o data cu colonia.
-- F1 [spec 4.9]: Plot-ul terenului, alergatorii (HandRenderController), zona Erei 2
-- (ZoneController) si punte spre Overlay-ul agentului F (onboarding/sunet/ceremonie). Vechile
-- SettlerRenderController/DialogueController au fost scoase -- inlocuite de HandRenderController.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterGui = game:GetService("StarterGui")
local Workspace = game:GetService("Workspace")

local Net = require(ReplicatedStorage.Net.Net)
local RiverConfig = require(ReplicatedStorage.Shared.Config.RiverConfig)
local TycoonConfig = require(ReplicatedStorage.Shared.Config.TycoonConfig)
local Strings = require(ReplicatedStorage.Shared.Config.Strings)
local AudioLevels = require(ReplicatedStorage.Shared.Modules.AudioLevels)
local HUDController = require(script.Parent.Controllers.HUDController)
local IndexController = require(script.Parent.Controllers.IndexController)
local RiverRenderController = require(script.Parent.Controllers.RiverRenderController)
local NetController = require(script.Parent.Controllers.NetController)
local DockController = require(script.Parent.Controllers.DockController)
local SawmillController = require(script.Parent.Controllers.SawmillController)
local StorageController = require(script.Parent.Controllers.StorageController)
local ShedController = require(script.Parent.Controllers.ShedController)
local ForgeController = require(script.Parent.Controllers.ForgeController)
local PadController = require(script.Parent.Controllers.PadController)
local InteractController = require(script.Parent.Controllers.InteractController)
local MusicController = require(script.Parent.Controllers.MusicController)
local SoundController = require(script.Parent.Controllers.SoundController)
local AudioPanel = require(script.Parent.Controllers.AudioPanel)
local HandRenderController = require(script.Parent.Controllers.HandRenderController)
local ZoneController = require(script.Parent.Controllers.ZoneController)
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
local StationPanel = require(script.Parent.Controllers.StationPanel)
local StationMenu = require(script.Parent.Controllers.StationMenu)
-- Deschide panoul de niveluri direct pe o statie. Un singur loc, dat ca functie celor care au
-- obiecte in lume (plase, debarcader, platforme cumparate) si listei de quest-uri -- nimeni nu cere
-- StationPanel direct, deci nu apar require-uri incrucisate intre controllere (vezi Panels).
local function openStation(kind: string, id: string?)
    -- meniul OBIECTULUI atins, nu lista cu toate statiile [owner, 2026-09-12; D48]
    StationMenu.OpenAt(kind, id)
end
-- Meniul unei meserii [D49]: acelasi meniu, pe felul "crew". Il deschid oamenii atinsi, depozitul si
-- platformele de angajare cumparate.
local function openCrew(role: string)
    StationMenu.OpenAt("crew", role)
end
local QuestController = require(script.Parent.Controllers.QuestController)
local TutorialController = require(script.Parent.Controllers.TutorialController)
local WelcomeController = require(script.Parent.Controllers.WelcomeController)
local WheelController = require(script.Parent.Controllers.WheelController)
-- [D59] pontonul: undita, ce aduce raul, avizierul satului, jurnalul
local PierController = require(script.Parent.Controllers.PierController)
local TreasureController = require(script.Parent.Controllers.TreasureController)
local VillageController = require(script.Parent.Controllers.VillageController)
local JournalController = require(script.Parent.Controllers.JournalController)
local Panels = require(script.Parent.Controllers.Panels)
local layers = CameraController.Init({ WorldGui = worldGui })

-- Agentul F scrie Overlay.luau chiar acum, in paralel -- daca fisierul inca nu exista cand
-- rulez poarta, ramanem fara el in loc sa picam tot bootstrap-ul [F1 spec 4.9].
local OverlayModule = script.Parent.Controllers:FindFirstChild("Overlay")
local Overlay: any = nil
if OverlayModule ~= nil then
    local ok, mod = pcall(require, OverlayModule :: any)
    if ok then
        Overlay = mod
    else
        warn(`[Driftwood] Overlay a esuat la incarcare: {tostring(mod)}`)
    end
end

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
safeInit("ZoneController", function()
    ZoneController.Init({ Plot = layers.Plot })
end)
safeInit("PadController", function()
    PadController.Init({
        Plot = layers.Plot,
        Remotes = {
            BuyPad = Net.Get("BuyPad"),
            PadBought = Net.Get("PadBought"),
            PadRejected = Net.Get("PadRejected"),
        },
        CharacterPos = CharacterController.Position,
        OnToast = HUDController.Toast,
        OpenStation = openStation,
    })
end)
-- Depozitul [D49]: aici varsa Collector-ul ce strange din plase, de aici ia Porter-ul.
safeInit("StorageController", function()
    StorageController.Init({
        Plot = layers.Plot,
        Remotes = { UseStorage = Net.Get("UseStorage") },
        CharacterPos = CharacterController.Position,
        OpenCrew = openCrew,
    })
end)
-- [D55, D56] Shed-ul de scrap si forja: gramezile lor si gestul tau pe E. Fara Smelter, forja topeste doar cat stai
-- in inelul ei, ca gaterul.
safeInit("ShedController", function()
    ShedController.Init({ Plot = layers.Plot, Remotes = { UseShed = Net.Get("UseShed") } })
end)
safeInit("ForgeController", function()
    ForgeController.Init({
        Plot = layers.Plot,
        Remotes = { UseForge = Net.Get("UseForge"), AtForge = Net.Get("AtForge") },
        CharacterPos = CharacterController.Position,
    })
end)
-- Gaterul [D48, D49]: aici se taie; fara Sawyer, doar cat stai langa el.
safeInit("SawmillController", function()
    SawmillController.Init({
        Plot = layers.Plot,
        Remotes = { UseSawmill = Net.Get("UseSawmill"), AtSawmill = Net.Get("AtSawmill") },
        CharacterPos = CharacterController.Position,
        OpenStation = openStation,
    })
end)
safeInit("DockController", function()
    DockController.Init({
        Plot = layers.Plot,
        Remotes = {
            DeliverDock = Net.Get("DeliverDock"),
            -- gramada de la ponton are nevoie sa stie CAND s-a vandut, ca sa plece pe apa exact in
            -- clipa vanzarii [research 42 pct.6] -- Overlay asculta acelasi Sold pentru "+N", cele
            -- doua raspunsuri la un singur eveniment coexista fara conflict.
            Sold = Net.Get("Sold"),
        },
        CharacterPos = CharacterController.Position,
        OpenStation = openStation,
    })
end)
safeInit("NetController", function()
    NetController.Init({
        Plot = layers.Plot,
        Remotes = {
            CollectNet = Net.Get("CollectNet"),
            NetCaught = Net.Get("NetCaught"),
        },
        CharacterPos = CharacterController.Position,
        OnToast = HUDController.Toast,
        OpenStation = openStation,
    })
end)
safeInit("HandRenderController", function()
    HandRenderController.Init({
        Plot = layers.Plot,
        OpenCrew = openCrew,
        CharacterPos = CharacterController.Position, -- [D58] meseria scrisa sub om, cand treci pe langa el
        -- [D56] Smelter-ul bate cu ciocanul doar cat forja chiar topeste
        IsWorking = function(role: string): boolean
            return role == "smelter" and ForgeController.Working()
        end,
    })
end)
-- [D51] cardul obiectului de langa tine: E, U si butoanele lui
safeInit("InteractController", function()
    InteractController.Init({
        Plot = layers.Plot,
        CharacterPos = CharacterController.Position,
        OpenStation = openStation,
        OnToast = HUDController.Toast,
    })
end)

HUDController.Init({
    HudGui = hudCanvas,
    SetStick = CharacterController.SetStick,
    PanelsOpen = Panels.AnyOpen,
    Interact = function()
        InteractController.Interact()
    end,
})
-- [D56] INTENTIONAT FARA INTRARE: atelierul de reparat si colectia sunt puse deoparte (butoanele din bara au iesit,
-- forja nu mai deschide panoul). Raman initializate, ascunse, ca remote-urile lor sa ramana folosite pe ambele parti
-- (check_requires) si codul sa fie gata cand colectia revine cu locul si pictogramele ei. Nu e o scapare.
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
-- Fereastra de revenire: scrisa de mult, dar niciodata pornita din Bootstrap -- deci nu s-a vazut
-- niciodata. Acum serverul chiar trage `WelcomeBack` (StationService), deci are ce arata.
safeInit("WheelController", function()
    WheelController.Init({
        HudGui = hudCanvas,
        Plot = layers.Plot, -- roata sta si ca obiect in lume, langa debarcader
        Remotes = { SpinWheel = Net.Get("SpinWheel"), WheelResult = Net.Get("WheelResult") },
        OnToast = HUDController.Toast,
    })
end)
safeInit("WelcomeController", function()
    WelcomeController.Init({ HudGui = hudCanvas, WelcomeBack = Net.Get("WelcomeBack") })
end)
safeInit("QuestController", function()
    QuestController.Init({
        HudGui = hudCanvas,
        Remotes = {
            ClaimQuest = Net.Get("ClaimQuest"),
            QuestRejected = Net.Get("QuestRejected"),
        },
        OnToast = HUDController.Toast,
        OpenStation = openStation,
    })
end)
-- Meniul de niveluri al unui singur obiect. Refuzurile de nivel se anunta de aici, o singura data.
safeInit("StationMenu", function()
    StationMenu.Init({
        HudGui = hudCanvas,
        Remotes = {
            UpgradeStation = Net.Get("UpgradeStation"),
            UpgradeCrew = Net.Get("UpgradeCrew"),
            UpgradeRejected = Net.Get("UpgradeRejected"),
        },
        OnToast = HUDController.Toast,
    })
end)
safeInit("StationPanel", function()
    StationPanel.Init({
        HudGui = hudCanvas,
        Remotes = {
            UpgradeStation = Net.Get("UpgradeStation"),
            UpgradeRejected = Net.Get("UpgradeRejected"),
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
        Panels.CloseAll()
    end
end)

-- Intrarile barii de meniu, intr-un loc: bara le deseneaza, iar tastele de mai jos le deschid. [D56] "Workshop" (R)
-- si "Collection" (C) au iesit: colectia e pusa deoparte (vezi WorkshopController mai sus).
local function isMenuUnlocked(_name: string): boolean
    return true
end
local menuEntries = {
    {
        name = "wheel",
        icon = "spin", -- [D59] timonierul, nu ceasul
        label = Strings.WHEEL_TITLE,
        key = "L",
        open = WheelController.Toggle,
    },
    {
        -- [D59] jurnalul pestilor si al raului
        name = "journal",
        icon = "fish",
        label = Strings.JOURNAL_TITLE,
        key = "K",
        open = JournalController.Toggle,
    },
    {
        -- [D59] avizierul satului: perlele cumpara aspect (sta si in lume, pe punte)
        name = "board",
        icon = "pearl",
        label = Strings.BOARD_TITLE,
        key = "B",
        open = VillageController.Toggle,
    },
    {
        name = "quests",
        icon = "book",
        label = Strings.QUESTS_TITLE,
        key = "J", -- nu Q: Q inchide toate panourile (vezi handler-ul global)
        open = QuestController.Toggle,
    },
    -- "Upgrades" NU mai e in bara [owner, 2026-09-12]: nivelul se urca atingand obiectul. Lista
    -- veche ramane pe tasta U, nepromovata, pana se decide ce face.
    {
        -- [D54] panoul "Sound": nivelul muzicii si al efectelor, tinut minte in profil. Mereu in bara:
        -- efectele exista si fara muzica (randul Music se ascunde singur cand ea lipseste).
        name = "sound",
        icon = "music",
        label = Strings.MENU_SOUND,
        key = "M",
        open = AudioPanel.Toggle,
    },
}
safeInit("MenuBarController", function()
    MenuBarController.Init({
        HudGui = hudCanvas,
        IsUnlocked = isMenuUnlocked,
        Entries = menuEntries,
    })
end)
safeInit("MusicController", function()
    MusicController.Init()
end)
safeInit("AudioPanel", function()
    AudioPanel.Init({ HudGui = hudCanvas, SetAudio = Net.Get("SetAudio") })
end)

-- TASTELE BARII DE MENIU. Pana acum apareau doar in tooltip ("Quests (J)") si nu erau legate nicaieri
-- -- tooltip-ul mintea [D40]. Legate aici, dintr-un singur tabel, ca bara si tastele sa nu se
-- desparta. `processed`: nu cand scrii in chat.
do
    local keys: { [Enum.KeyCode]: () -> () } = {}
    for _, entry in menuEntries do
        local ok, code = pcall(function()
            return (Enum.KeyCode :: any)[entry.key]
        end)
        if ok and code ~= nil then
            keys[code] = function()
                if isMenuUnlocked(entry.name) then
                    entry.open()
                end
            end
        end
    end
    -- U: meniul obiectului de langa tine [D51]; departe de orice obiect, lista veche, ascunsa. [D58] U scrie acum pe
    -- butonul Upgrade, deci se poarta ca J si M: a doua apasare inchide meniul. Inainte, cu meniul deschis, cardul era
    -- ascuns, iar U deschidea lista veche peste el.
    keys[Enum.KeyCode.U] = function()
        if StationMenu.IsOpen() then
            StationMenu.Close()
        elseif not InteractController.OpenUpgrade() then
            StationPanel.Toggle()
        end
    end
    UserInputService.InputBegan:Connect(function(input: InputObject, processed: boolean)
        if processed then
            return
        end
        local action = keys[input.KeyCode]
        if action ~= nil then
            action()
        end
    end)
end

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

-- CE A FACUT UN E la depozit, la gater sau la debarcader [D49]. Refuzurile se spun mereu -- un E care
-- nu face nimic in tacere e exact ce D43 interzice; reusitele doar cand nu se vad singure.
-- [D56] "Are om" pe locul lui: gaterul are Sawyer, forja Smelter. Pana acum gaterul raspundea pentru orice loc.
local staffedAt: { [string]: boolean } = { sawmill = false, forge = false }
Net.Get("UseResult").OnClientEvent
    :Connect(function(place: string, ok: boolean, reason: string, dropped: number, taken: number)
        local text = Strings.useResult(place, ok, reason, dropped, taken, staffedAt[place] == true)
        if text ~= nil then
            HUDController.Toast(text)
        end
    end)

-- UNDE INCEPE FIECARE STRAT. HUD-ul sta in zona sigura a interfetei (CoreUISafeInsets); lumea si stratul
-- tutorialului acopera tot ecranul. AbsolutePosition are UN SINGUR sistem, al zonei sigure, oricare ar fi
-- ScreenInsets-ul stratului (raspunsul Roblox pe DevForum: "The AbsolutePosition property uses the
-- CoreUISafeInsets viewport coordinate system") -- deci un element dintr-un strat pe tot ecranul are
-- AbsolutePosition negativ cu cat e zona nesigura din stanga si de sus.
-- In D51 adunam doar bara de sus (`GuiService:GetGuiInset`), ceea ce pe desktop ajunge. Pe un telefon cu notch,
-- tinut orizontal, zona sigura incepe si cu ~48 px mai la dreapta: reflectorul tutorialului cadea langa butonul
-- cu cartea, nu peste el [owner, iPhone XR in Studio, 2026-09-14]. Acum decalajul se citeste din straturile
-- insesi: coltul unui strat = AbsolutePosition-ul lui, iar diferenta dintre doua colturi e drumul dintre
-- straturi, oricare ar fi zona nesigura (bara, notch, marginea de jos).
local tutorialScreen: Frame? = nil

-- Plot-local (world pixels, inainte de + PLOT_ORIGIN) -> pixeli pe panza HUD, pentru Overlay
-- [F1 spec 4.9]: trece prin originea/scara camerei (pixeli din stratul lumii), scade coltul panzei HUD
-- masurat din coltul lumii si abia apoi imparte la scara HUD-ului.
local function worldToHud(x: number, y: number): (number, number)
    local worldX = TycoonConfig.PLOT_ORIGIN.x + x
    local worldY = TycoonConfig.PLOT_ORIGIN.y + y
    local camX, camY = CameraController.WorldOrigin()
    local scale = CameraController.Scale()
    local hud = hudCanvas.AbsolutePosition - backdrop.AbsolutePosition
    local vx = (worldX - camX) * scale - hud.X
    local vy = (worldY - camY) * scale - hud.Y
    return vx / hudScale, vy / hudScale
end

-- Coltul stratului tutorialului (inainte sa existe, al lumii: amandoua acopera tot ecranul).
local function tutorialOrigin(): Vector2
    local s = tutorialScreen
    return if s ~= nil then s.AbsolutePosition else backdrop.AbsolutePosition
end

-- SPATIUL TUTORIALULUI E ALTUL. `worldToHud` intoarce coordonate in PANZA HUD-ului, care are si
-- scalare (UIScale) si decalaj (ScreenInsets). Stratul tutorialului n-are niciuna, ca sa poata
-- intuneca ecranul pana in colturi -- deci o coordonata de panza pusa acolo cade in alta parte.
-- Sageata arata spre prima plasa, deci are nevoie de coordonate de ECRAN, nu de panza.
local function worldToScreen(x: number, y: number): (number, number)
    local camX, camY = CameraController.WorldOrigin()
    local scale = CameraController.Scale()
    local shift = backdrop.AbsolutePosition - tutorialOrigin()
    return (TycoonConfig.PLOT_ORIGIN.x + x - camX) * scale + shift.X,
        (TycoonConfig.PLOT_ORIGIN.y + y - camY) * scale + shift.Y
end

-- Un dreptunghi citit din AbsolutePosition (un buton din HUD) -> coordonate in stratul tutorialului.
local function absRectToScreen(x: number, y: number, w: number, h: number)
    local origin = tutorialOrigin()
    return x - origin.X, y - origin.Y, w, h
end

-- Tutorialul se porneste DUPA `worldToHud`: are nevoie de el ca sa arate spre prima plasa, care e
-- in lume, nu in HUD. Pornit mai sus, prindea o variabila inca nedefinita.
-- Stratul tutorialului are ScreenGui-ul LUI, fara insets si peste HUD: intunericul trebuie sa
-- acopere ecranul pana in colturi, inclusiv fasia de sus pe care o lasa CoreUISafeInsets -- pe
-- telefon fasia aia e lata si un reflector care se opreste sub ea arata a defect.
safeInit("TutorialController", function()
    local tutorialGui = Instance.new("ScreenGui")
    tutorialGui.Name = "Tutorial"
    tutorialGui.ResetOnSpawn = false
    tutorialGui.IgnoreGuiInset = true
    tutorialGui.ScreenInsets = Enum.ScreenInsets.None
    tutorialGui.DisplayOrder = 3
    tutorialGui.Parent = playerGui

    local screen = Instance.new("Frame")
    screen.Name = "Screen"
    screen.BackgroundTransparency = 1
    screen.Size = UDim2.fromScale(1, 1)
    screen.Parent = tutorialGui
    tutorialScreen = screen

    TutorialController.Init({
        Screen = screen,
        WorldToScreen = worldToScreen,
        -- lista de quest-uri se deschide din butonul cu cartea, din bara din dreapta [owner, 2026-09-13]
        QuestButtonRect = function()
            local x, y, w, h = MenuBarController.EntryRect("quests")
            return absRectToScreen(x, y, w, h)
        end,
        QuestsOpen = QuestController.IsOpen,
        OpenQuests = QuestController.Open,
    })
end)

-- [D59] Pontonul, dupa `worldToHud` (perlele zboara din lume in HUD): ce aduce raul, undita, avizierul, jurnalul.
safeInit("TreasureController", function()
    TreasureController.Init({
        Plot = layers.Plot,
        Remotes = { TreasureArrived = Net.Get("TreasureArrived") },
        OnToast = HUDController.Toast,
    })
end)
safeInit("PierController", function()
    PierController.Init({
        Plot = layers.Plot,
        CharacterPos = CharacterController.Position,
        WorldToHud = worldToHud,
        Remotes = {
            Cast = Net.Get("Cast"),
            CastResult = Net.Get("CastResult"),
            Land = Net.Get("Land"),
            LandResult = Net.Get("LandResult"),
        },
        OnToast = HUDController.Toast,
    })
end)
safeInit("VillageController", function()
    VillageController.Init({
        HudGui = hudCanvas,
        Plot = layers.Plot,
        Remotes = {
            BuyDecor = Net.Get("BuyDecor"),
            BuyOutfit = Net.Get("BuyOutfit"),
            WearOutfit = Net.Get("WearOutfit"),
            ShopResult = Net.Get("ShopResult"),
        },
        OnToast = HUDController.Toast,
    })
end)
safeInit("JournalController", function()
    JournalController.Init({ HudGui = hudCanvas })
end)

if Overlay ~= nil then
    safeInit("Overlay", function()
        Overlay.Init({
            HudGui = hudCanvas,
            WorldScroll = layers.Scroll,
            Plot = layers.Plot, -- dara de ghidaj si inelul tintei stau pe jos [D50]
            CharacterPos = CharacterController.Position,
            WorldToHud = worldToHud,
            Remotes = {
                NetCaught = Net.Get("NetCaught"),
                Sold = Net.Get("Sold"),
                HandDelivered = Net.Get("HandDelivered"),
                PadBought = Net.Get("PadBought"),
                PadRejected = Net.Get("PadRejected"),
            },
        })
    end)
end

-- Starea intreaga a tycoon-ului, inlocuita in intregime la fiecare mesaj -- niciodata combinata
-- camp cu camp cu ce era inainte [F0 spec 4.1, CLAUDE.md capcana 3]. Fiecare controller primeste
-- doar campurile de care are nevoie, copiate explicit. `snapshot` string acelasi tabel, cu TOATE
-- campurile din F1 spec 2.1, e cel trimis mai departe la Overlay.Apply -- un singur loc unde se
-- construieste, ca sa nu se dezalinieze de ce vad propriile mele controllere [F1 spec 4.9].
Net.Get("TycoonState").OnClientEvent:Connect(function(raw: { [string]: any })
    -- `pads` e o harta plata (id -> statut): table.clone o inlocuieste in intregime dintr-o
    -- lovitura, exact "wholesale". Buclele explicite de mai jos raman pentru ca acolo fiecare
    -- intrare are mai multe campuri numite -- genul de structura unde s-au pierdut campuri
    -- inainte [CLAUDE.md capcana 3].
    local pads: { [string]: string } = table.clone(raw.pads)
    -- cat adauga la venit/s fiecare platforma inca necumparata -- cartonasul de la apropiere [F2
    -- spec Agent U pct.2] il citeste, niciodata un numar scris de mana [CLAUDE.md capcana 3]
    local padDeltas: { [string]: number } = table.clone(raw.padDeltas)
    local nets: { NetController.NetSnap } = {}
    for i, n in raw.nets do
        nets[i] = {
            padId = n.padId,
            padIndex = n.padIndex,
            lane = n.lane,
            x = n.x,
            y = n.y,
            count = n.count,
            capacity = n.capacity,
            nextCatchAt = n.nextCatchAt,
            interval = n.interval,
            caught = n.caught,
            boosted = n.boosted == true, -- [D51] eticheta "Fast first catch"
            -- CE e in plasa, nu doar cat -- NetController deseneaza gramada din ea [research 42
            -- pct.2]. table.clone: campurile trimise de server trebuie copiate explicit, altfel
            -- raman legate de tabelul brut al remote-ului [CLAUDE.md capcana 3].
            contents = table.clone(n.contents),
        }
    end
    local hands: { HandRenderController.HandSnap } = {}
    for i, h in raw.hands do
        local handNets: { string } = table.clone(h.nets)
        local a = h.appearance
        hands[i] = {
            id = h.id,
            role = h.role,
            name = h.name,
            index = h.index or 1,
            count = h.count or 1,
            tier = h.tier or 1,
            nets = handNets,
            cycleStartAt = h.cycleStartAt,
            carrying = h.carrying,
            carryKind = h.carryKind, -- [D55] ce se vede in roaba
            capacity = h.capacity or 0,
            -- locul fix al rolurilor statice; nil pentru cele care umbla [CLAUDE.md capcana 3:
            -- fiecare camp trimis de server se copiaza EXPLICIT, altfel se pierde tacut]
            x = h.x,
            y = h.y,
            appearance = {
                body = a.body,
                hair = a.hair,
                skin = { a.skin[1], a.skin[2], a.skin[3] },
                hairColor = { a.hairColor[1], a.hairColor[2], a.hairColor[3] },
                outfit = a.outfit,
            },
        }
    end
    local zones = { landing = raw.zones.landing, mill = raw.zones.mill }
    local firsts = {
        collect = raw.firsts.collect,
        sell = raw.firsts.sell,
        named = raw.firsts.named,
        runner = raw.firsts.runner,
        bell = raw.firsts.bell,
    }
    local sack = raw.sack
    local sackCount, sackCapacity, sackValue = sack.count, sack.capacity, sack.value
    -- CE duce jucatorul, nu doar cat -- DockController deseneaza gramada de la ponton cu ea
    -- [research 42 pct.6]. table.clone, acelasi motiv ca la nets.contents de mai sus.
    local sackContents: { [string]: number } = table.clone(sack.contents)
    -- brut / taiat [D49]: fiecare loc de predare decide din asta ce face un E. [D55] `raw` = lemnul brut,
    -- `rawScrap` = scrap-ul brut (forja), `iron` = fierul, gata de vandut; [D56] `finds` = gasirile neprelucrate,
    -- care se vand si asa (sunt numarate si in `cut`).
    local sackState = {
        count = sackCount,
        capacity = sackCapacity,
        raw = sack.raw or 0,
        rawScrap = sack.rawScrap or 0,
        finds = sack.finds or 0,
        iron = sackContents.iron or 0,
        cut = sack.cut or 0,
        cutValue = sack.cutValue or 0,
    }

    -- Quest-urile: capitolul, lista si quest-ul activ. Copiate camp cu camp [CLAUDE.md capcana 3].
    local rawWheel: any = raw.wheel or {}
    local wheel = {
        ready = rawWheel.ready == true,
        secondsLeft = rawWheel.secondsLeft or 0,
        spins = rawWheel.spins or 0,
    }

    local rawQuests: any = raw.quests
    local quests = nil
    if rawQuests ~= nil then
        local questRows = {}
        for i, q in (rawQuests.quests or {}) do
            questRows[i] = {
                id = q.id,
                text = q.text,
                progress = q.progress,
                goal = q.goal,
                state = q.state,
                reward = { coins = q.reward.coins, pearls = q.reward.pearls },
            }
        end
        local a: any = rawQuests.active
        quests = {
            chapter = {
                id = rawQuests.chapter.id,
                title = rawQuests.chapter.title,
                subtitle = rawQuests.chapter.subtitle,
            },
            quests = questRows,
            completed = rawQuests.completed,
            total = rawQuests.total,
            claimable = rawQuests.claimable,
            everClaimed = rawQuests.everClaimed == true, -- [D51] reflectorul pe carte, o singura data
            active = if a == nil
                then nil
                else {
                    id = a.id,
                    text = a.text,
                    progress = a.progress,
                    goal = a.goal,
                    padId = a.padId,
                    dock = a.dock,
                    sawmill = a.sawmill,
                    forge = a.forge, -- [D56] sageata spre inelul forjei
                    fish = a.fish, -- [D59] sageata spre capatul pontonului
                    kind = a.kind, -- [D51] ghidajul alege pasul dupa felul quest-ului
                    stationKind = a.stationKind,
                    stationId = a.stationId,
                },
        }
    end

    -- Gramada de la debarcader. Copiata camp cu camp, ca tot ce vine de la server [CLAUDE.md
    -- capcana 3]: un `table.clone` de suprafata pe `raw` ar impartasi tabelul interior.
    -- panoul statiilor: randurile, debitele si veriga slaba
    local rawStations: any = raw.stations or {}
    local stationRows = {}
    for i, r in (rawStations.rows or {}) do
        stationRows[i] = {
            kind = r.kind,
            id = r.id,
            name = r.name,
            level = r.level,
            output = r.output,
            nextOutput = r.nextOutput,
            nextMilestone = r.nextMilestone,
            costs = table.clone(r.costs or {}),
            maxCount = r.maxCount,
            maxCost = r.maxCost,
            bottleneck = r.bottleneck,
            gain = r.gain or 0, -- [D52] castigul real al unui nivel, pentru randul colorat din meniu
            line = r.line, -- [D56] "wood" | "iron" | nil (taverna)
        }
    end
    local rawRates: any = rawStations.rates or {}
    -- meseriile, cate un rand pe meserie [D49]; copiate camp cu camp [CLAUDE.md capcana 3]
    local crewRows = {}
    for i, c in (rawStations.crews or {}) do
        crewRows[i] = {
            role = c.role,
            name = c.name,
            plural = c.plural,
            pad = c.pad,
            count = c.count,
            tier = c.tier,
            maxTier = c.maxTier,
            maxPeople = c.maxPeople,
            output = c.output,
            nextOutput = c.nextOutput,
            secondOutput = c.secondOutput,
            tierCost = c.tierCost,
            tierGain = c.tierGain or 0,
            tierBlock = c.tierBlock,
            secondPrice = c.secondPrice,
            secondGain = c.secondGain or 0,
            hireBlock = c.hireBlock,
            tierAffordable = c.tierAffordable == true,
            secondAffordable = c.secondAffordable == true,
            maxed = c.maxed == true,
            bottleneck = c.bottleneck == true,
            line = c.line, -- [D56]
        }
    end
    -- nivelurile, pe padId, pentru insignele din lume
    local netLevels: { [string]: number } = {}
    for _, r in stationRows do
        if r.kind == "net" and r.id ~= nil then
            netLevels[r.id] = r.level
        end
    end
    local stations = {
        rows = stationRows,
        netLevels = netLevels,
        idle = rawStations.idle or 0,
        bottleneck = rawStations.bottleneck or "nets",
        -- [D56] veriga slaba a fiecarei linii ("" cat linia fierului e inchisa): meniul unui obiect cu castig zero
        -- spune ce il tine IN LINIA LUI
        woodBottleneck = rawStations.woodBottleneck or "nets",
        ironBottleneck = rawStations.ironBottleneck or "",
        rates = {
            catch = rawRates.catch or 0,
            -- [D55] cele doua marfuri: ce prind plasele de lemn si cea de scrap, forja, ce se livreaza din fiecare
            woodCatch = rawRates.woodCatch or 0,
            scrapCatch = rawRates.scrapCatch or 0,
            collect = rawRates.collect or 0,
            port = rawRates.port or 0,
            sawing = rawRates.sawing or 0,
            haul = rawRates.haul or 0,
            -- [D56] verigile liniei fierului, fiecare cu oamenii ei
            scrapCollect = rawRates.scrapCollect or 0,
            scrapPort = rawRates.scrapPort or 0,
            forging = rawRates.forging or 0,
            ironHaul = rawRates.ironHaul or 0,
            sales = rawRates.sales or 0,
            wood = rawRates.wood or 0,
            scrap = rawRates.scrap or 0,
            delivered = rawRates.delivered or 0,
            bottleneck = rawRates.bottleneck or "nets",
            woodBottleneck = rawRates.woodBottleneck or "nets",
            ironBottleneck = rawRates.ironBottleneck or "",
        },
        crews = crewRows,
        -- cat faci tu pe fiecare pas fara om; meniul meseriei o spune ("you do this yourself") [D49], pe linii [D56]
        playerShare = rawStations.playerShare or 0,
        ironPlayerShare = rawStations.ironPlayerShare or 0,
    }

    local rawDock: any = raw.dock or {}
    local dock = {
        count = rawDock.count or 0,
        value = rawDock.value or 0,
        rate = rawDock.rate or 0,
        contents = table.clone(rawDock.contents or {}),
    }
    -- Gramada gaterului [D48], copiata camp cu camp ca debarcaderul: un camp lipsa aici ar lasa pe
    -- ecran cifra de la mesajul anterior [CLAUDE.md, capcana 3].
    local rawSawmill: any = raw.sawmill or {}
    local sawmill = {
        count = rawSawmill.count or 0,
        contents = table.clone(rawSawmill.contents or {}),
        out = rawSawmill.out or 0,
        outContents = table.clone(rawSawmill.outContents or {}),
        rate = rawSawmill.rate or 0,
        present = rawSawmill.present == true,
        staffed = rawSawmill.staffed == true,
    }
    staffedAt.sawmill = sawmill.staffed
    -- Depozitul [D49], acelasi tipar.
    local rawStorage: any = raw.storage or {}
    local storage = {
        count = rawStorage.count or 0,
        contents = table.clone(rawStorage.contents or {}),
    }
    -- [D55, D56] Shed-ul de scrap si forja, acelasi tipar: camp cu camp.
    local rawShed: any = raw.shed or {}
    local shed = {
        count = rawShed.count or 0,
        contents = table.clone(rawShed.contents or {}),
    }
    local rawForge: any = raw.forge or {}
    local forge = {
        count = rawForge.count or 0,
        contents = table.clone(rawForge.contents or {}),
        out = rawForge.out or 0,
        outContents = table.clone(rawForge.outContents or {}),
        rate = rawForge.rate or 0,
        present = rawForge.present == true, -- [D56] ca la gater
        staffed = rawForge.staffed == true,
    }
    staffedAt.forge = forge.staffed
    -- [D55] cati oameni are fiecare meserie: casa lor din lume creste cu ei
    local crewCounts: { [string]: number } = {}
    for _, c in crewRows do
        crewCounts[c.role] = c.count or 0
    end

    -- [D59] Pontonul, camp cu camp [CLAUDE.md capcana 3]: undita (momeala, cati pesti, jurnalul), ce asteapta la ponton,
    -- satul (decor, tinute).
    local rawFishing: any = raw.fishing or {}
    local fishSpecies: { [string]: { count: number, best: number } } = {}
    for id, e in (rawFishing.species or {}) do
        fishSpecies[id] = { count = e.count or 0, best = e.best or 0 }
    end
    local fishing =
        { bait = rawFishing.bait or 0, fished = rawFishing.fished or 0, species = fishSpecies }
    local rawRiver: any = raw.river or {}
    local river = {
        waiting = table.clone(rawRiver.waiting or {}),
        started = rawRiver.started == true,
        notes = rawRiver.notes or 0,
        found = rawRiver.found or 0,
    }
    local rawVillage: any = raw.village or {}
    local village = {
        decor = table.clone(rawVillage.decor or {}),
        outfits = table.clone(rawVillage.outfits or {}),
        outfit = rawVillage.outfit or "keeper",
    }

    local rawSettings: any = raw.settings or {}
    local snapshot = {
        -- [D54] nivelurile sunetului, copiate explicit; o valoare lipsa sau stricata cade pe implicit
        settings = {
            musicLevel = if AudioLevels.valid(rawSettings.musicLevel)
                then rawSettings.musicLevel :: number
                else AudioLevels.DEFAULT_MUSIC,
            soundLevel = if AudioLevels.valid(rawSettings.soundLevel)
                then rawSettings.soundLevel :: number
                else AudioLevels.DEFAULT_SOUND,
        },
        coins = raw.coins,
        pearls = raw.pearls or 0,
        incomePerSec = raw.incomePerSec,
        sellMult = raw.sellMult,
        serverTime = raw.serverTime,
        lanes = raw.lanes,
        pads = pads,
        padDeltas = padDeltas,
        nets = nets,
        hands = hands,
        zones = zones,
        workshop = raw.workshop,
        storage = storage,
        shed = shed,
        forge = forge,
        sawmill = sawmill,
        dock = dock,
        stations = stations,
        quests = quests,
        wheel = wheel,
        fishing = fishing,
        river = river,
        village = village,
        bottleneck = raw.bottleneck or "nets",
        firsts = firsts,
        sack = {
            count = sackCount,
            capacity = sackCapacity,
            value = sackValue,
            contents = sackContents,
            raw = sackState.raw,
            rawScrap = sackState.rawScrap,
            finds = sackState.finds,
            cut = sackState.cut,
            cutValue = sackState.cutValue,
        },
    }

    HUDController.SetCoins(snapshot.coins)
    HUDController.SetPearls(snapshot.pearls)
    HUDController.SetIncome(snapshot.incomePerSec)
    HUDController.SetIdle(snapshot.stations.idle)
    -- [D54] doar prima stare conteaza (vezi Apply); panoul deschis inainte de ea se redeseneaza
    MusicController.Apply(snapshot.settings.musicLevel)
    SoundController.Apply(snapshot.settings.soundLevel)
    AudioPanel.Refresh()
    TutorialController.Apply({
        firstNetBought = snapshot.pads.first_net == "bought",
        firstSale = snapshot.firsts.sell == true,
        everClaimed = snapshot.quests ~= nil and snapshot.quests.everClaimed,
        claimable = if snapshot.quests ~= nil then snapshot.quests.claimable else 0,
    })
    WheelController.Apply(snapshot.wheel)
    -- [D59] pontonul
    PierController.Apply(snapshot.river.waiting)
    TreasureController.Apply(snapshot.river.waiting)
    JournalController.Apply(snapshot.fishing, snapshot.river)
    VillageController.Apply(
        snapshot.village,
        snapshot.pearls,
        JournalController.SpeciesCaught(snapshot.fishing)
    )
    if snapshot.quests ~= nil then
        HUDController.SetQuest(snapshot.quests.active, snapshot.quests.claimable)
        QuestController.Apply(snapshot.quests)
    end
    HUDController.SetSack(sackCount, sackCapacity)
    PadController.SetCrews(crewCounts) -- [D55] inainte de Apply: prima desenare alege deja casa potrivita
    PadController.Apply(
        snapshot.pads,
        snapshot.coins,
        snapshot.padDeltas,
        snapshot.bottleneck,
        snapshot.stations.netLevels
    )
    RiverRenderController.SetScrapNet(snapshot.pads.fifth_net == "bought")
    NetController.Apply(
        snapshot.nets,
        sackCount,
        sackCapacity,
        snapshot.lanes,
        snapshot.stations.netLevels,
        sackState.raw,
        sackState.rawScrap,
        sackState.iron,
        sackState.finds
    )
    StorageController.Apply(sackState, snapshot.storage, snapshot.stations.woodBottleneck)
    ShedController.Apply(
        sackState,
        snapshot.shed,
        snapshot.pads.scrap_shed == "bought",
        snapshot.stations.ironBottleneck
    )
    ForgeController.Apply(sackState, snapshot.forge, snapshot.workshop == true)
    SawmillController.Apply(sackState, snapshot.sawmill)
    DockController.Apply(sackState, snapshot.dock)
    StationPanel.Apply(snapshot.stations)
    StationMenu.Apply(snapshot.stations)
    HandRenderController.Apply(snapshot.hands)
    ZoneController.Apply(snapshot.zones.mill)

    if Overlay ~= nil then
        local ok, err = pcall(Overlay.Apply, snapshot)
        if not ok then
            warn(`[Driftwood] Overlay.Apply a esuat: {err}`)
        end
    end
end)

-- cerem starea de cateva ori: primul mesaj se poate pierde daca serverul nu e gata. [D56] Starea atelierului nu se
-- mai cere: panourile lui nu au intrare.
Net.Get("RequestState"):FireServer()
task.delay(1, function()
    Net.Get("RequestState"):FireServer()
end)
task.delay(3, function()
    Net.Get("RequestState"):FireServer()
end)

print("[Driftwood] client bootstrap complet")
