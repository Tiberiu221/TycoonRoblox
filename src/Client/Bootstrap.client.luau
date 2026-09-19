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
local FlowConfig = require(ReplicatedStorage.Shared.Config.FlowConfig)
local StationConfig = require(ReplicatedStorage.Shared.Config.StationConfig)
local AudioLevels = require(ReplicatedStorage.Shared.Modules.AudioLevels)
local LookMath = require(ReplicatedStorage.Shared.Modules.LookMath)
-- FOLDERELE DE LANGA SCRIPT SE ASTEAPTA. Roblox copiaza copiii lui StarterPlayerScripts in PlayerScripts pe rand, iar
-- scriptul asta poate porni inainte ca `Controllers` si `UI` sa fi ajuns langa el. In Studio, pe 2026-09-19:
-- "Controllers is not a valid member of PlayerScripts" la primul require, deci niciun controller pornit si doar cerul
-- albastru pe ecran. Fiecare folder se copiaza intreg, deci dupa ce au sosit amandoua, modulele din ele se gasesc
-- intre ele cu `script.Parent` ca pana acum. Se asteapta AMANDOUA inainte de primul require: controllerele cer
-- module din `UI` chiar la incarcare.
local Controllers = script.Parent:WaitForChild("Controllers")
local UI = script.Parent:WaitForChild("UI")
local HUDController = require(Controllers.HUDController)
local IndexController = require(Controllers.IndexController)
local RiverRenderController = require(Controllers.RiverRenderController)
local NetController = require(Controllers.NetController)
local DockController = require(Controllers.DockController)
local SawmillController = require(Controllers.SawmillController)
local StorageController = require(Controllers.StorageController)
local ShedController = require(Controllers.ShedController)
local ForgeController = require(Controllers.ForgeController)
local LineController = require(Controllers.LineController)
local PadController = require(Controllers.PadController)
local InteractController = require(Controllers.InteractController)
local MusicController = require(Controllers.MusicController)
local SoundController = require(Controllers.SoundController)
local CeremonyController = require(Controllers.CeremonyController)
local JuiceController = require(Controllers.JuiceController)
local AudioPanel = require(Controllers.AudioPanel)
local HandRenderController = require(Controllers.HandRenderController)
local ZoneController = require(Controllers.ZoneController)
local WorkshopController = require(Controllers.WorkshopController)
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

local CameraController = require(Controllers.CameraController)
local CharacterController = require(Controllers.CharacterController)
local DevPanelController = require(Controllers.DevPanelController)
local MenuBarController = require(Controllers.MenuBarController)
local StationPanel = require(Controllers.StationPanel)
local StationMenu = require(Controllers.StationMenu)
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
local QuestController = require(Controllers.QuestController)
local TutorialController = require(Controllers.TutorialController)
local WelcomeController = require(Controllers.WelcomeController)
-- [D60] roata s-a mutat in balci; pe punte ramane indicatorul
local WheelSignpostController = require(Controllers.WheelSignpostController)
-- [D59] pontonul: undita, ce aduce raul, avizierul satului, jurnalul
local PierController = require(Controllers.PierController)
local TreasureController = require(Controllers.TreasureController)
local VillageController = require(Controllers.VillageController)
local JournalController = require(Controllers.JournalController)
-- [D60] barca spre balci
local FerryController = require(Controllers.FerryController)
local Panels = require(Controllers.Panels)
-- [D61, partea 2] coltul cu Robux
local MonetizationConfig = require(ReplicatedStorage.Shared.Config.MonetizationConfig)
local TycoonMath = require(ReplicatedStorage.Shared.Modules.TycoonMath)
local ShopPanel = require(Controllers.ShopPanel)
local DriftController = require(Controllers.DriftController) -- [D62, pasul 3]
local AmbientController = require(Controllers.AmbientController) -- [D62, pasul 5]
local Theme = require(UI.Theme)
local layers = CameraController.Init({ WorldGui = worldGui })

-- Agentul F scrie Overlay.luau chiar acum, in paralel -- daca fisierul inca nu exista cand
-- rulez poarta, ramanem fara el in loc sa picam tot bootstrap-ul [F1 spec 4.9].
local OverlayModule = Controllers:FindFirstChild("Overlay")
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
-- [D62, pasul 5] pasarile care trec peste sat (doar desen)
safeInit("AmbientController", function()
    AmbientController.Init({ Scroll = layers.Scroll })
end)
-- [D62, pasul 3] darurile raului: devreme, ca sa prinda configul raului (samanta); zborul monedelor se leaga mai jos
safeInit("DriftController", function()
    DriftController.Init({
        Plot = layers.Plot,
        CharacterPos = CharacterController.Position,
        RiverConfig = Net.Get("RiverConfig"),
        Remotes = { GrabDrift = Net.Get("GrabDrift"), DriftGrabbed = Net.Get("DriftGrabbed") },
        OnToast = HUDController.Toast,
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
-- [D65] liniile si vanzatorii Erei 2 (LineController), dupa numele liniei si al vanzatorului
local millLines: { [string]: LineController.Line } = {}
local millSellers: { [string]: LineController.Seller } = {}
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
    -- [D65] ERA 2, The Mill: locurile liniilor ei, dupa tabel. Magazia Morii, turnatoria si Piata sunt cladiri fixe
    -- (apar cu roata de apa); magazia de minereu si cuptorul de cupru sunt platforme, deci le deseneaza PadController.
    -- Pana la arta lor (docs/PLAN-ERA2.md, pasul 7) poarta desenele perechii din Era 1.
    LineController.Init({
        Plot = layers.Plot,
        Remotes = { UsePlace = Net.Get("UsePlace"), AtPlace = Net.Get("AtPlace") },
        CharacterPos = CharacterController.Position,
    })
    -- `own` = desenul cladirii (scripts/art/d65_mill.py), `borrowed` = al perechii din Era 1, purtat cat al ei nu e
    -- urcat; ruina se vede pe locul ei cat Moara e inchisa
    local function fixedBuilding(
        spot: { x: number, y: number, w: number, h: number },
        own: string,
        borrowed: string,
        label: string
    ): LineController.Building
        return {
            x = spot.x,
            y = spot.y,
            w = spot.w,
            h = spot.h,
            sprite = own,
            borrowed = borrowed,
            ruin = "ruin_" .. own,
            label = label,
        }
    end
    millLines.parts = LineController.line(
        "parts",
        fixedBuilding(
            TycoonConfig.MILL_STORE,
            "mill_store",
            "storage",
            Strings.LINE_WORDS.parts.store
        ),
        fixedBuilding(
            TycoonConfig.FOUNDRY,
            "foundry",
            "sawmill",
            Strings.LINE_WORDS.parts.processor
        )
    )
    millLines.copper = LineController.line("copper", nil, nil)
    millSellers.market = LineController.seller(
        "market",
        fixedBuilding(TycoonConfig.MARKET, "market", "tavern", Strings.MARKET_LABEL)
    )
    for _, line in millLines do
        InteractController.AddSource(line.FocusStore)
        InteractController.AddSource(line.FocusProcessor)
    end
    for _, seller in millSellers do
        InteractController.AddSource(seller.Focus)
    end
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
            if role == "smelter" then
                return ForgeController.Working()
            end
            -- [D65] omul unui atelier al Morii: cat atelierul liniei lui chiar lucreaza
            local line = StationConfig.LINE_OF[StationConfig.LINK_OF[role] or ""]
            local controller = if line ~= nil then millLines[line] else nil
            return controller ~= nil and controller.Working()
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
safeInit("WheelSignpostController", function()
    WheelSignpostController.Init({ Plot = layers.Plot, OnToast = HUDController.Toast })
end)
safeInit("WelcomeController", function()
    WelcomeController.Init({
        HudGui = hudCanvas,
        WelcomeBack = Net.Get("WelcomeBack"),
        RobuxBuy = Net.Get("RobuxBuy"), -- [D61, partea 2] `Double it`
    })
end)
safeInit("QuestController", function()
    QuestController.Init({
        HudGui = hudCanvas,
        Remotes = {
            ClaimQuest = Net.Get("ClaimQuest"),
            QuestRejected = Net.Get("QuestRejected"),
            QuestClaimed = Net.Get("QuestClaimed"),
        },
        OnToast = HUDController.Toast,
        OpenStation = openStation,
        PearlFly = JuiceController.PearlFly,
        OnChapterDone = function(title: string, subtitle: string)
            SoundController.PlayMilestone()
            CeremonyController.PlayMoment(title, subtitle)
        end,
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
        CharacterPos = CharacterController.Position, -- [D65] panoul se deschide pe cartierul in care stai
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
-- [D61, partea 2] `Shop` apare abia dupa prima vanzare: un magazin aratat inainte de prima moneda castigata strica si
-- jocul, si conversia (nota 41). Restul intrarilor sunt mereu acolo.
local shopUnlocked = false
local function isMenuUnlocked(name: string): boolean
    return name ~= "shop" or shopUnlocked
end
local menuEntries = {
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
        -- [D61, partea 2] coltul cu Robux: viteza, spatiu, aspect. Dupa prima vanzare.
        name = "shop",
        icon = "coin",
        label = Strings.SHOP_TITLE,
        key = "P",
        open = ShopPanel.Toggle,
    },
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
safeInit("ShopPanel", function()
    ShopPanel.Init({ HudGui = hudCanvas, RobuxBuy = Net.Get("RobuxBuy"), Place = "village" })
end)
-- [D61, partea 2] ce ai primit pe Robux, sau de ce nu s-a deschis fereastra de cumparare [D43]
Net.Get("RobuxResult").OnClientEvent
    :Connect(function(key: unknown, ok: unknown, reason: unknown, coins: unknown)
        local item = if typeof(key) == "string" then MonetizationConfig.byKey[key] else nil
        if ok ~= true then
            HUDController.Toast(
                Strings.shopRefused(if typeof(reason) == "string" then reason else ""),
                Theme.COLOR.bad
            )
            return
        end
        SoundController.Play("chime")
        local amount = if typeof(coins) == "number" then coins else 0
        if amount > 0 then
            HUDController.Toast(
                Strings.shopCoins(TycoonMath.formatNumber(amount)),
                Theme.COLOR.gold
            )
            if key == "welcome2x" then
                WelcomeController.OnDoubled(amount)
            end
        elseif item ~= nil then
            HUDController.Toast(Strings.shopGranted(item.name), Theme.COLOR.gold)
        end
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

-- [D63] SONDA DIN STUDIO deschide panouri dupa nume, ca sa le poata citi textul fara ca cineva sa apese ceva: clientul
-- Roblox ignora tastele si clicurile sintetice. Sonda scrie atributul `DevUi` pe Workspace (`<id>|<actiune>`):
--   open:<nume>          un panou din bara de meniu (journal, board, quests, shop, audio) sau `stations` (lista veche)
--   station:<fel>:<id>   meniul unei cladiri sau al unei plase (station:net:first_net, station:saw)
--   panel:<fel>:<id>     lista veche, deschisa pe randul unei statii (panel:foundry): trece singura pe cartierul ei
--   crew:<rol>           meniul unei meserii (crew:porter)
--   goto:<x>:<y>         muta omul tau intr-un loc de pe teren (coordonatele din TycoonConfig), ca sonda sa poata citi
--                        cardul obiectului de langa el; panourile raman cum sunt
--   close                inchide tot
-- Doar in Studio: intr-un joc publicat atributul nu e ascultat deloc.
if game:GetService("RunService"):IsStudio() then
    Workspace:GetAttributeChangedSignal("DevUi"):Connect(function()
        local raw = Workspace:GetAttribute("DevUi")
        if typeof(raw) ~= "string" then
            return
        end
        local action = string.match(raw, "^[%w_]+|(.*)$") or raw
        local verb, a, b = string.match(action, "^(%w+):?([^:]*):?(.*)$")
        if verb == "goto" then
            local gx, gy = tonumber(a), tonumber(b)
            if gx ~= nil and gy ~= nil then
                CharacterController.Teleport(
                    TycoonConfig.PLOT_ORIGIN.x + gx,
                    TycoonConfig.PLOT_ORIGIN.y + gy
                )
            end
            return
        end
        Panels.CloseAll()
        if verb == "open" and a == "stations" then
            StationPanel.Toggle()
        elseif verb == "open" then
            for _, entry in menuEntries do
                if entry.name == a then
                    entry.open()
                end
            end
        elseif verb == "station" then
            openStation(a, if b ~= "" then b else nil)
        elseif verb == "panel" then
            StationPanel.OpenAt(a, if b ~= "" then b else nil)
        elseif verb == "crew" then
            openCrew(a)
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
        -- [D65] un loc al Erei 2 (sau un refuz pe care il stie doar ea, ca "other_seller" la taverna)
        if text == nil then
            local store, processor = FlowConfig.BY_STORE[place], FlowConfig.BY_PROCESSOR[place]
            local spec = store or processor
            text = Strings.placeResult(
                if spec ~= nil then spec.line else nil,
                if FlowConfig.SELLERS[place] ~= nil then place else nil,
                store ~= nil,
                ok,
                reason,
                dropped,
                taken,
                staffedAt[place] == true
            )
        end
        if text ~= nil then
            HUDController.Toast(text)
        end
        -- [D62] lasatul si luatul marfii se aud: pana acum gestul de la depozit, gater, forja si taverna era mut
        if ok and dropped + taken > 0 then
            SoundController.Play("pop", if dropped > 0 then 0.8 else 1.15)
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
        -- [D63] tinta fara sfarsit de pe linia NEXT: apasarea deschide meniul cladirii, al plasei sau al meseriei ei
        OpenAmbition = function(a)
            if a.what == "milestone" then
                openStation(a.kind, a.id)
            else
                openCrew(a.kind)
            end
        end,
    })
end)

DriftController.SetHud(worldToHud, JuiceController.CoinFly) -- [D62, pasul 3] monedele darului zboara spre contor

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
safeInit("FerryController", function()
    FerryController.Init({
        Plot = layers.Plot,
        PlayerGui = playerGui,
        Remotes = { RowUp = Net.Get("RowUp"), FerryFailed = Net.Get("FerryFailed") },
        OnToast = HUDController.Toast,
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
                StationUpgraded = Net.Get("StationUpgraded"),
                CrewUpgraded = Net.Get("CrewUpgraded"),
            },
            CheerCrew = HandRenderController.Cheer,
        })
        -- [D62] meniul deschis isi arata si el nivelul cumparat (sta de obicei peste obiectul din lume)
        Net.Get("StationUpgraded").OnClientEvent:Connect(
            function(kind: string, id: string?, _level: number, _count: number, milestone: number?)
                StationMenu.OnUpgraded(kind, id, milestone)
            end
        )
        Net.Get("CrewUpgraded").OnClientEvent:Connect(function(role: string)
            StationMenu.OnCrewUpgraded(role)
        end)
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
    -- [D65] fiecare zona din TycoonConfig.ZONES, copiata dupa id (o zona pe care serverul n-o trimite ramane inchisa)
    local zones: { [string]: string } = {}
    for _, zone in TycoonConfig.ZONES do
        local status = raw.zones[zone.id]
        zones[zone.id] = if typeof(status) == "string" then status else "locked"
    end
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
        -- [D65] pe linii si pe vanzatori, copiate camp cu camp [CLAUDE.md capcana 3]
        rawBy = {} :: { [string]: number },
        sellBy = {} :: { [string]: { count: number, value: number } },
    }
    for _, line in StationConfig.LINE_ORDER do
        sackState.rawBy[line] = if typeof(sack.rawBy) == "table" then sack.rawBy[line] or 0 else 0
    end
    for _, seller in StationConfig.SELLER_ORDER do
        local entry: any = if typeof(sack.sellBy) == "table" then sack.sellBy[seller] else nil
        sackState.sellBy[seller] = {
            count = if typeof(entry) == "table" then entry.count or 0 else 0,
            value = if typeof(entry) == "table" then entry.value or 0 else 0,
        }
    end

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
                    board = a.board, -- [D62] sageata spre avizierul satului
                    place = a.place, -- [D65] un loc al Morii (inelul unui atelier, usa Pietei)
                    always = a.always == true, -- [D65] sageata si cand ghidajul tace
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
    local stationLines: { [string]: { catch: number, delivered: number, bottleneck: string, playerShare: number } } =
        {}
    local stationLinkRates: { [string]: number } = {}
    for _, line in StationConfig.LINE_ORDER do
        local entry: any = if typeof(rawStations.lines) == "table"
            then rawStations.lines[line] or {}
            else {}
        stationLines[line] = {
            catch = entry.catch or 0,
            delivered = entry.delivered or 0,
            bottleneck = entry.bottleneck or "",
            playerShare = entry.playerShare or 0,
        }
    end
    for _, link in StationConfig.LINKS do
        local rate = if typeof(rawStations.linkRates) == "table"
            then rawStations.linkRates[link]
            else nil
        stationLinkRates[link] = if typeof(rate) == "number" then rate else 0
    end
    local stationEraBottleneck: { string } = {}
    for era in StationConfig.ERA_LINES do
        local link = if typeof(rawStations.eraBottleneck) == "table"
            then rawStations.eraBottleneck[era]
            else nil
        stationEraBottleneck[era] = if typeof(link) == "string" then link else ""
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
        -- [D65] vederea pe linii, pentru orice era (copiata camp cu camp)
        lines = stationLines,
        linkRates = stationLinkRates,
        eraBottleneck = stationEraBottleneck,
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
    -- [D65] DRUMUL MARFII PE LINII (TycoonState.flow): magazia si atelierul fiecarei linii, gramada fiecarui vanzator
    local rawFlow: any = raw.flow or {}
    local flowLines: { [string]: { store: LineController.StoreState, processor: LineController.ProcessorState } } =
        {}
    for _, line in StationConfig.LINE_ORDER do
        local entry: any = if typeof(rawFlow.lines) == "table"
            then rawFlow.lines[line] or {}
            else {}
        local s: any, pr: any = entry.store or {}, entry.processor or {}
        flowLines[line] = {
            store = { count = s.count or 0, contents = table.clone(s.contents or {}) },
            processor = {
                count = pr.count or 0,
                contents = table.clone(pr.contents or {}),
                out = pr.out or 0,
                outContents = table.clone(pr.outContents or {}),
                rate = pr.rate or 0,
                present = pr.present == true,
                staffed = pr.staffed == true,
            },
        }
        staffedAt[FlowConfig.LINES[line].processor] = pr.staffed == true
    end
    local flowSellers: { [string]: LineController.SellerState } = {}
    for _, seller in StationConfig.SELLER_ORDER do
        local entry: any = if typeof(rawFlow.sellers) == "table"
            then rawFlow.sellers[seller] or {}
            else {}
        flowSellers[seller] = {
            count = entry.count or 0,
            value = entry.value or 0,
            rate = entry.rate or 0,
            contents = table.clone(entry.contents or {}),
        }
    end
    -- [D55] cati oameni are fiecare meserie: casa lor din lume creste cu ei
    local crewCounts: { [string]: number } = {}
    local crewTiers: { [string]: number } = {} -- [D62, pasul 5] treapta se vede ca buline sub numele casei
    for _, c in crewRows do
        crewCounts[c.role] = c.count or 0
        crewTiers[c.role] = c.tier or 1
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
        -- [D61] infatisarea aleasa la croitoreasa; curatata aici, ca un camp lipsa sa cada pe chipul de la inceput
        look = LookMath.clean(rawVillage.look),
    }

    local rawFair: any = raw.fair or {}
    local fair = { visits = rawFair.visits or 0 } -- [D60]

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
        flow = { lines = flowLines, sellers = flowSellers },
        sawmill = sawmill,
        dock = dock,
        stations = stations,
        quests = quests,
        wheel = wheel,
        fishing = fishing,
        river = river,
        village = village,
        fair = fair,
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
            -- [D65] pe linii si pe vanzatori: bucla de mana a Morii (GuideMath) citeste de aici
            rawBy = sackState.rawBy,
            sellBy = sackState.sellBy,
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
    WheelSignpostController.Apply(snapshot.wheel)
    -- [D59] pontonul
    PierController.Apply(snapshot.river.waiting)
    TreasureController.Apply(snapshot.river.waiting)
    JournalController.Apply(snapshot.fishing, snapshot.river)
    VillageController.Apply(
        snapshot.village,
        snapshot.pearls,
        JournalController.SpeciesCaught(snapshot.fishing)
    )
    FerryController.Apply(snapshot.village.outfit, snapshot.fair.visits, snapshot.village.look)
    -- [D61, partea 2] pass-urile tale si ce ar aduce produsele acum; Swift Boots se simte pe loc
    ShopPanel.Apply(raw.robux)
    CharacterController.SetSpeedFactor(ShopPanel.State().speed)
    if shopUnlocked ~= (snapshot.firsts.sell == true) then
        shopUnlocked = snapshot.firsts.sell == true
        MenuBarController.Refresh()
    end
    if snapshot.quests ~= nil then
        HUDController.SetQuest(snapshot.quests.active, snapshot.quests.claimable)
        QuestController.Apply(snapshot.quests)
    end
    HUDController.SetSack(sackCount, sackCapacity)
    -- [D62, pasul 5] nivelul cladirilor lantului, pentru a doua lor infatisare de la pragul 25. Inainte de
    -- PadController.Apply, ca prima desenare a forjei sa aleaga deja desenul potrivit (altfel ar "creste" la intrare).
    for _, row in snapshot.stations.rows do
        if row.kind == "saw" then
            SawmillController.SetLevel(row.level)
        elseif row.kind == "dock" then
            DockController.SetLevel(row.level)
        elseif row.kind == "forge" then
            PadController.SetBuildingLevel("workshop", row.level)
        elseif row.kind == "furnace" then
            PadController.SetBuildingLevel("copper_furnace", row.level) -- [D65]
        end
    end
    PadController.SetCrews(crewCounts, crewTiers) -- [D55] inainte de Apply: prima desenare alege deja casa potrivita
    PadController.SetChain(snapshot.stations) -- [D63] cartonasul unei platforme fara castig spune cine o tine, pe linia ei
    PadController.Apply(
        snapshot.pads,
        snapshot.coins,
        snapshot.padDeltas,
        snapshot.bottleneck,
        snapshot.stations.netLevels
    )
    -- [D55, D65] ce pluteste in larg: marfa pe care plasele tale inca n-o prind. Scrap-ul pana la Fifth Net; minereul
    -- de cand porneste Moara pana la Tenth Net (marfa noua apare cand o poti folosi [D64]).
    RiverRenderController.SetPromise(
        if snapshot.pads.fifth_net ~= "bought"
            then "scrap"
            elseif
                snapshot.pads.water_wheel == "bought" and snapshot.pads.tenth_net ~= "bought"
            then "ore"
            else nil
    )
    NetController.SetSack(sackState.rawBy, sackState.sellBy) -- [D65]
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
    -- [D65] locurile Morii: fiecare linie isi ia gramezile, platformele care o deschid si veriga ei slaba
    for line, controller in millLines do
        local entry = snapshot.flow.lines[line]
        local lineView = snapshot.stations.lines[line]
        controller.Apply(
            sackState,
            entry.store,
            entry.processor,
            snapshot.pads,
            if lineView ~= nil then lineView.bottleneck else ""
        )
    end
    for seller, controller in millSellers do
        controller.Apply(
            sackState,
            snapshot.flow.sellers[seller],
            snapshot.pads.water_wheel == "bought"
        )
    end
    SawmillController.Apply(sackState, snapshot.sawmill)
    DockController.Apply(sackState, snapshot.dock)
    StationPanel.Apply(snapshot.stations)
    StationMenu.Apply(snapshot.stations)
    HandRenderController.Apply(snapshot.hands)
    ZoneController.Apply(snapshot.zones)

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
