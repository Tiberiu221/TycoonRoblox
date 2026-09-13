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
local GuiService = game:GetService("GuiService")
local Workspace = game:GetService("Workspace")

local Net = require(ReplicatedStorage.Net.Net)
local RiverConfig = require(ReplicatedStorage.Shared.Config.RiverConfig)
local TycoonConfig = require(ReplicatedStorage.Shared.Config.TycoonConfig)
local Strings = require(ReplicatedStorage.Shared.Config.Strings)
local HUDController = require(script.Parent.Controllers.HUDController)
local IndexController = require(script.Parent.Controllers.IndexController)
local RiverRenderController = require(script.Parent.Controllers.RiverRenderController)
local NetController = require(script.Parent.Controllers.NetController)
local DockController = require(script.Parent.Controllers.DockController)
local SawmillController = require(script.Parent.Controllers.SawmillController)
local StorageController = require(script.Parent.Controllers.StorageController)
local PadController = require(script.Parent.Controllers.PadController)
local InteractController = require(script.Parent.Controllers.InteractController)
local MusicController = require(script.Parent.Controllers.MusicController)
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
    HandRenderController.Init({ Plot = layers.Plot, OpenCrew = openCrew })
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

-- Workshop-ul apare in bara doar dupa ce platforma e cumparata [F1 spec 4.5]; Collection ramane
-- mereu deschisa, ca in F0.
local workshopUnlocked = false
-- Intrarile barii de meniu, intr-un loc: bara le deseneaza, iar tastele de mai jos le deschid.
local function isMenuUnlocked(name: string): boolean
    if name == "workshop" then
        return workshopUnlocked
    end
    if name == "music" then
        return MusicController.Available() -- fara muzica urcata, fara buton [D51]
    end
    return true
end
local menuEntries = {
    {
        name = "wheel",
        icon = "clock",
        label = Strings.WHEEL_TITLE,
        key = "L",
        open = WheelController.Toggle,
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
        name = "index",
        icon = "crate",
        label = Strings.MENU_COLLECTION,
        key = "C",
        open = IndexController.Toggle,
    },
    {
        -- [D51] muzica pornita/oprita, tinuta minte in profil
        name = "music",
        icon = "music",
        label = Strings.MENU_MUSIC,
        key = "M",
        open = MusicController.Toggle,
    },
    {
        name = "workshop",
        icon = "hammer",
        label = Strings.MENU_WORKSHOP,
        -- R (Repair), nu W: W e mersul inainte -- legata, tasta ar fi deschis atelierul la fiecare pas
        key = "R",
        open = WorkshopController.Toggle,
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
    local announced = false
    MusicController.Init({
        SetMusic = Net.Get("SetMusic"),
        OnChanged = function(on: boolean)
            MenuBarController.SetDimmed("music", not on)
            -- prima aplicare (preferinta din profil) nu se anunta; doar apasarea butonului
            if announced then
                HUDController.Toast(Strings.musicToggled(on))
            end
            announced = true
        end,
    })
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
    -- U: meniul obiectului de langa tine [D51]; departe de orice obiect, lista veche, ascunsa
    keys[Enum.KeyCode.U] = function()
        if not InteractController.OpenUpgrade() then
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
local sawmillStaffed = false
Net.Get("UseResult").OnClientEvent
    :Connect(function(place: string, ok: boolean, reason: string, dropped: number, taken: number)
        local text = Strings.useResult(place, ok, reason, dropped, taken, sawmillStaffed)
        if text ~= nil then
            HUDController.Toast(text)
        end
    end)

-- CAT DE JOS INCEPE HUD-UL. HUD-ul sta sub bara de sus a Roblox-ului (CoreUISafeInsets); lumea si
-- stratul tutorialului acopera tot ecranul. Un AbsolutePosition din HUD e masurat de SUB bara, unul din
-- lume sau din tutorial de la marginea ecranului -- deci trecerea dintre ele adauga sau scade bara.
-- Fara ea, reflectorul tutorialului incadra monedele in loc de tinta lui, cu exact inaltimea barii mai
-- sus [vazut in Studio, 2026-09-13].
local function hudInset(): Vector2
    local topLeft = GuiService:GetGuiInset()
    return topLeft
end

-- Plot-local (world pixels, inainte de + PLOT_ORIGIN) -> pixeli pe panza HUD, pentru Overlay
-- [F1 spec 4.9]: trece prin originea/scara camerei (lumea, pixeli de ecran), scade bara de sus si
-- abia apoi imparte la scara HUD-ului.
local function worldToHud(x: number, y: number): (number, number)
    local worldX = TycoonConfig.PLOT_ORIGIN.x + x
    local worldY = TycoonConfig.PLOT_ORIGIN.y + y
    local camX, camY = CameraController.WorldOrigin()
    local scale = CameraController.Scale()
    local inset = hudInset()
    local vx = (worldX - camX) * scale - inset.X
    local vy = (worldY - camY) * scale - inset.Y
    return vx / hudScale, vy / hudScale
end

-- SPATIUL TUTORIALULUI E ALTUL. `worldToHud` intoarce coordonate in PANZA HUD-ului, care are si
-- scalare (UIScale) si decalaj (ScreenInsets). Stratul tutorialului n-are niciuna, ca sa poata
-- intuneca ecranul pana in colturi -- deci o coordonata de panza pusa acolo cade in alta parte.
-- Sageata arata spre prima plasa, deci are nevoie de coordonate de ECRAN, nu de panza.
local function worldToScreen(x: number, y: number): (number, number)
    local hx, hy = worldToHud(x, y)
    local origin = hudCanvas.AbsolutePosition
    local inset = hudInset()
    return origin.X + hx * hudScale + inset.X, origin.Y + hy * hudScale + inset.Y
end

-- Un dreptunghi citit din HUD (AbsolutePosition) -> ecran, pentru stratul tutorialului.
local function hudRectToScreen(x: number, y: number, w: number, h: number)
    local inset = hudInset()
    return x + inset.X, y + inset.Y, w, h
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

    TutorialController.Init({
        Screen = screen,
        WorldToScreen = worldToScreen,
        -- lista de quest-uri se deschide din butonul cu cartea, din bara din dreapta [owner, 2026-09-13]
        QuestButtonRect = function()
            local x, y, w, h = MenuBarController.EntryRect("quests")
            return hudRectToScreen(x, y, w, h)
        end,
        QuestsOpen = QuestController.IsOpen,
        OpenQuests = QuestController.Open,
    })
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
    -- brut / taiat [D49]: fiecare loc de predare decide din asta ce face un E
    local sackState = {
        count = sackCount,
        capacity = sackCapacity,
        raw = sack.raw or 0,
        cut = sack.cut or 0,
        cutValue = sack.cutValue or 0,
    }
    -- CE duce jucatorul, nu doar cat -- DockController deseneaza gramada de la ponton cu ea
    -- [research 42 pct.6]. table.clone, acelasi motiv ca la nets.contents de mai sus.
    local sackContents: { [string]: number } = table.clone(sack.contents)

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
        rates = {
            catch = rawRates.catch or 0,
            collect = rawRates.collect or 0,
            port = rawRates.port or 0,
            sawing = rawRates.sawing or 0,
            haul = rawRates.haul or 0,
            sales = rawRates.sales or 0,
            delivered = rawRates.delivered or 0,
            bottleneck = rawRates.bottleneck or "nets",
        },
        crews = crewRows,
        -- cat faci tu pe fiecare pas fara om; meniul meseriei o spune ("you do this yourself") [D49]
        playerShare = rawStations.playerShare or 0,
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
    sawmillStaffed = sawmill.staffed
    -- Depozitul [D49], acelasi tipar.
    local rawStorage: any = raw.storage or {}
    local storage = {
        count = rawStorage.count or 0,
        contents = table.clone(rawStorage.contents or {}),
    }

    local rawSettings: any = raw.settings or {}
    local snapshot = {
        -- [D51] preferintele: muzica pornita implicit, oprita doar daca profilul spune explicit
        settings = { music = rawSettings.music ~= false },
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
        pile = raw.pile,
        storage = storage,
        sawmill = sawmill,
        dock = dock,
        stations = stations,
        quests = quests,
        wheel = wheel,
        bottleneck = raw.bottleneck or "nets",
        firsts = firsts,
        sack = {
            count = sackCount,
            capacity = sackCapacity,
            value = sackValue,
            contents = sackContents,
            raw = sackState.raw,
            cut = sackState.cut,
            cutValue = sackState.cutValue,
        },
    }

    HUDController.SetCoins(snapshot.coins)
    HUDController.SetPearls(snapshot.pearls)
    HUDController.SetIncome(snapshot.incomePerSec)
    HUDController.SetIdle(snapshot.stations.idle)
    MusicController.Apply(snapshot.settings.music)
    TutorialController.Apply({
        firstNetBought = snapshot.pads.first_net == "bought",
        firstSale = snapshot.firsts.sell == true,
        everClaimed = snapshot.quests ~= nil and snapshot.quests.everClaimed,
        claimable = if snapshot.quests ~= nil then snapshot.quests.claimable else 0,
    })
    WheelController.Apply(snapshot.wheel)
    if snapshot.quests ~= nil then
        HUDController.SetQuest(snapshot.quests.active, snapshot.quests.claimable)
        QuestController.Apply(snapshot.quests)
    end
    HUDController.SetSack(sackCount, sackCapacity)
    PadController.Apply(
        snapshot.pads,
        snapshot.coins,
        snapshot.padDeltas,
        snapshot.bottleneck,
        snapshot.stations.netLevels
    )
    RiverRenderController.SetLanes(snapshot.lanes)
    PadController.SetWorkshop(snapshot.workshop, snapshot.pile)
    NetController.Apply(
        snapshot.nets,
        sackCount,
        sackCapacity,
        snapshot.lanes,
        snapshot.stations.netLevels,
        sackState.raw
    )
    StorageController.Apply(sackState, snapshot.storage, snapshot.stations.bottleneck)
    SawmillController.Apply(sackState, snapshot.sawmill)
    DockController.Apply(sackState, snapshot.dock)
    StationPanel.Apply(snapshot.stations)
    StationMenu.Apply(snapshot.stations)
    HandRenderController.Apply(snapshot.hands)
    ZoneController.Apply(snapshot.zones.mill)

    if workshopUnlocked ~= snapshot.workshop then
        workshopUnlocked = snapshot.workshop
        MenuBarController.Refresh()
    end

    if Overlay ~= nil then
        local ok, err = pcall(Overlay.Apply, snapshot)
        if not ok then
            warn(`[Driftwood] Overlay.Apply a esuat: {err}`)
        end
    end
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
