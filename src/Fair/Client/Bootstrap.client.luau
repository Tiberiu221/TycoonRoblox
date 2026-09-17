--!strict
-- [D60] Clientul BALCIULUI DE SEARA (place-ul al doilea). Ca in sat: lumea 2D pe straturile camerei (care te urmareste),
-- HUD-ul in zona sigura, cardul obiectului de langa tine. Aici: roata zilnica, barca spre casa si, in pasii urmatori,
-- oamenii, titlurile, tabela de pe scena si negustorul.
--
-- Starea (FairState) se INLOCUIESTE la fiecare mesaj si se copiaza camp cu camp [CLAUDE.md, capcana 3].
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterGui = game:GetService("StarterGui")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local AudioLevels = require(ReplicatedStorage.Shared.Modules.AudioLevels)
local FairLayout = require(ReplicatedStorage.Shared.Modules.FairLayout)
local Net = require(ReplicatedStorage.Net.Net)
local RiverConfig = require(ReplicatedStorage.Shared.Config.RiverConfig)
local Strings = require(ReplicatedStorage.Shared.Config.Strings)
local VillageConfig = require(ReplicatedStorage.Shared.Config.VillageConfig)

local Controllers = script.Parent:WaitForChild("Controllers")
local AudioPanel = require(Controllers:WaitForChild("AudioPanel"))
local BoardController = require(Controllers:WaitForChild("BoardController"))
local BoothController = require(Controllers:WaitForChild("BoothController"))
local CameraController = require(Controllers:WaitForChild("CameraController"))
local CharacterController = require(Controllers:WaitForChild("CharacterController"))
local FairFerryController = require(Controllers:WaitForChild("FairFerryController"))
local FairHUDController = require(Controllers:WaitForChild("FairHUDController"))
local FairInteractController = require(Controllers:WaitForChild("FairInteractController"))
local FairScene = require(Controllers:WaitForChild("FairScene"))
local MarketController = require(Controllers:WaitForChild("MarketController"))
local MenuBarController = require(Controllers:WaitForChild("MenuBarController"))
local MusicController = require(Controllers:WaitForChild("MusicController"))
local PlayerCardController = require(Controllers:WaitForChild("PlayerCardController"))
local PondController = require(Controllers:WaitForChild("PondController"))
local PresenceController = require(Controllers:WaitForChild("PresenceController"))
local Panels = require(Controllers:WaitForChild("Panels"))
local SoundController = require(Controllers:WaitForChild("SoundController"))
local TitleController = require(Controllers:WaitForChild("TitleController"))
local WheelController = require(Controllers:WaitForChild("WheelController"))
local Theme = require(script.Parent:WaitForChild("UI"):WaitForChild("Theme"))

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
    gui.ScreenInsets = insets
    gui.ResetOnSpawn = false
    gui.DisplayOrder = displayOrder
    gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    gui.Parent = playerGui
    return gui
end

-- HUD-ul pe panza scalata dupa ecran, cu podea pentru telefon -- aceeasi regula ca in sat
local function attachHudScale(gui: ScreenGui): Frame
    local canvas = Instance.new("Frame")
    canvas.Name = "Canvas"
    canvas.BackgroundTransparency = 1
    local scale = Instance.new("UIScale")
    local ref = Vector2.new(RiverConfig.SCREEN_WIDTH, RiverConfig.SCREEN_HEIGHT)
    local function update()
        local vp = camera.ViewportSize
        local s = math.max(0.62, math.min(vp.X / ref.X, vp.Y / ref.Y))
        scale.Scale = s
        canvas.Size = UDim2.fromOffset(math.ceil(vp.X / s), math.ceil(vp.Y / s))
    end
    update()
    camera:GetPropertyChangedSignal("ViewportSize"):Connect(update)
    scale.Parent = canvas
    canvas.Parent = gui
    return canvas
end

local worldGui = makeRoot("World", 1, Enum.ScreenInsets.None)
local hudGui = makeRoot("HUD", 2, Enum.ScreenInsets.CoreUISafeInsets)
local backdrop = Instance.new("Frame")
backdrop.Name = "Backdrop"
backdrop.Size = UDim2.fromScale(1, 1)
backdrop.BackgroundColor3 = FairScene.NIGHT
backdrop.BorderSizePixel = 0
backdrop.ZIndex = 0
backdrop.Parent = worldGui
local hudCanvas = attachHudScale(hudGui)

-- [D61] Din lume in panza HUD-ului (perlele care zboara de la iaz spre pastila), ca worldToHud din sat: prin originea si
-- scara camerei, minus coltul panzei, impartit la scara HUD-ului.
local function worldToHud(x: number, y: number): (number, number)
    local camX, camY = CameraController.WorldOrigin()
    local scale = CameraController.Scale()
    local hud = hudCanvas.AbsolutePosition - backdrop.AbsolutePosition
    local uiScale = hudCanvas:FindFirstChildOfClass("UIScale")
    local s = if uiScale ~= nil then uiScale.Scale else 1
    return ((x - camX) * scale - hud.X) / s, ((y - camY) * scale - hud.Y) / s
end

local function safeInit(name: string, fn: () -> ())
    local ok, err = pcall(fn)
    if not ok then
        warn(`[Fair] {name} a esuat: {err}`)
    end
end

local layers = CameraController.Init({
    WorldGui = worldGui,
    WorldWidth = FairLayout.SIZE.w,
    WorldHeight = FairLayout.SIZE.h,
    PlotOrigin = { x = 0, y = 0 },
})
safeInit("FairScene", function()
    FairScene.Build(layers.Scroll)
end)
safeInit("CharacterController", function()
    CharacterController.Init({
        Scroll = layers.Scroll,
        OnMove = CameraController.Follow,
        IsBlocked = function(x: number, y: number): boolean
            return not FairLayout.isWalkable(x, y)
        end,
        Spawn = FairLayout.SPAWN,
        ZIndexFor = FairScene.ZIndexFor,
    })
end)

FairHUDController.Init({
    HudGui = hudCanvas,
    SetStick = CharacterController.SetStick,
    Interact = function()
        FairInteractController.Interact()
    end,
    PanelsOpen = Panels.AnyOpen,
})
safeInit("FairInteractController", function()
    FairInteractController.Init({
        World = layers.Scroll,
        Z = FairScene.Z.CARD,
        CharacterPos = CharacterController.Position,
        OnToast = FairHUDController.Toast,
    })
end)

-- roata zilnica: fereastra de sus, cardul la stalpul ei din lume, perlele spre pastila
safeInit("WheelController", function()
    local x, y, _, h = FairScene.Spot("wheel")
    WheelController.Init({
        HudGui = hudCanvas,
        Stand = { x = x, y = y, cardY = y - h - 8 },
        World = layers.Scroll,
        Remotes = { SpinWheel = Net.Get("SpinWheel"), WheelResult = Net.Get("WheelResult") },
        OnToast = FairHUDController.Toast,
        PearlFly = FairHUDController.PearlFly,
    })
    FairInteractController.AddSource(WheelController.Focus)
end)

safeInit("FairFerryController", function()
    FairFerryController.Init({
        PlayerGui = playerGui,
        Remotes = { RowHome = Net.Get("RowHome"), FerryFailed = Net.Get("FerryFailed") },
        OnToast = FairHUDController.Toast,
    })
    FairInteractController.AddSource(FairFerryController.Focus)
end)

-- scena: clasamentele saptamanii, trofeele, campionul; cardul "Leaderboards (E)" in fata ei
safeInit("BoardController", function()
    BoardController.Init({
        World = layers.Scroll,
        HudGui = hudCanvas,
        BoardState = Net.Get("BoardState"),
    })
    FairInteractController.AddSource(BoardController.Focus)
end)

-- negustorul: vitrina zilei pe cele trei tarabe
safeInit("MarketController", function()
    MarketController.Init({
        World = layers.Scroll,
        HudGui = hudCanvas,
        MarketBuy = Net.Get("MarketBuy"),
        OnRestock = function()
            Net.Get("RequestState"):FireServer()
        end,
    })
    FairInteractController.AddSource(MarketController.Focus)
end)

-- [D61] gheretele de joc: numele deasupra lor, cardul si panoul cu cele doua jocuri
safeInit("BoothController", function()
    BoothController.Init({
        World = layers.Scroll,
        HudGui = hudCanvas,
        Remotes = {
            BoothStart = Net.Get("BoothStart"),
            BoothStarted = Net.Get("BoothStarted"),
            BoothFinish = Net.Get("BoothFinish"),
            BoothResult = Net.Get("BoothResult"),
        },
        OnToast = FairHUDController.Toast,
        PearlFly = FairHUDController.PearlFly,
    })
    FairInteractController.AddSource(BoothController.Focus)
end)

-- ceilalti oameni: pozitiile, numele si titlurile lor, si cardul "Look at ... (E)" langa fiecare
safeInit("PlayerCardController", function()
    PlayerCardController.Init({
        HudGui = hudCanvas,
        Remotes = { LookAt = Net.Get("LookAt"), LookAtResult = Net.Get("LookAtResult") },
        OnToast = FairHUDController.Toast,
    })
end)
safeInit("PresenceController", function()
    PresenceController.Init({
        World = layers.Scroll,
        ZIndexFor = FairScene.ZIndexFor,
        LabelZ = FairScene.Z.LABELS,
        LocalUserId = player.UserId,
        CharacterPos = CharacterController.Position,
        Facing = CharacterController.Facing,
        IsMoving = CharacterController.IsMoving,
        Remotes = {
            Where = Net.GetUnreliable("Where"),
            Crowd = Net.GetUnreliable("Crowd"),
            People = Net.Get("People"),
        },
        OnLookAt = function(person)
            PlayerCardController.Open(person.userId)
        end,
        LookAtText = Strings.lookAtCard,
    })
    FairInteractController.AddSource(PresenceController.Focus)
end)

-- [D61] iazul de concurs: undita de pe jetiu, tabla de pe mal, banda de sus
safeInit("PondController", function()
    PondController.Init({
        World = layers.Scroll,
        CharacterPos = CharacterController.Position,
        Facing = CharacterController.Facing,
        WorldToHud = worldToHud,
        Remotes = {
            PondCast = Net.Get("PondCast"),
            PondCastResult = Net.Get("PondCastResult"),
            PondLand = Net.Get("PondLand"),
            PondLandResult = Net.Get("PondLandResult"),
            PondState = Net.Get("PondState"),
            PondResult = Net.Get("PondResult"),
        },
        IsActionHeld = FairHUDController.IsActionHeld,
        PearlFly = FairHUDController.PearlFly,
        OnToast = FairHUDController.Toast,
        SetBanner = FairHUDController.SetBanner,
        SetFishing = PresenceController.SetFishing,
        SetMyTagHidden = PresenceController.SetMyTagHidden,
    })
    FairInteractController.AddSource(PondController.Focus)
end)

safeInit("TitleController", function()
    TitleController.Init({
        HudGui = hudCanvas,
        Remotes = { BuyTitle = Net.Get("BuyTitle"), WearTitle = Net.Get("WearTitle") },
    })
end)

-- raspunsul cumparaturilor din balci: titlurile si vitrina negustorului
Net.Get("ShopResult").OnClientEvent
    :Connect(function(what: string, id: string, ok: boolean, reason: string)
        local decor = VillageConfig.decorById[id]
        local outfit = VillageConfig.outfitById[id]
        local name = if what == "decor" and decor ~= nil
            then decor.name
            elseif what == "outfit" and outfit ~= nil then outfit.name
            else TitleController.LabelOf(id)
        FairHUDController.Toast(
            Strings.shopResult(what, name, ok, reason),
            if ok then Theme.COLOR.gold else Theme.COLOR.bad
        )
        if ok then
            SoundController.Play("chime")
        end
    end)

safeInit("MusicController", function()
    MusicController.Init()
end)
safeInit("AudioPanel", function()
    AudioPanel.Init({ HudGui = hudCanvas, SetAudio = Net.Get("SetAudio") })
end)

-- bara din dreapta si tastele ei (aceleasi taste ca in sat, unde exista acelasi lucru)
local menuEntries = {
    {
        name = "wheel",
        icon = "spin",
        label = Strings.WHEEL_TITLE,
        key = "L",
        open = WheelController.Toggle,
    },
    {
        name = "titles",
        icon = "people",
        label = Strings.TITLES_TITLE,
        key = "T",
        open = TitleController.Toggle,
    },
    {
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
        IsUnlocked = function(_name: string): boolean
            return true
        end,
        Entries = menuEntries,
    })
end)
do
    local keys: { [Enum.KeyCode]: () -> () } = {}
    for _, entry in menuEntries do
        local ok, code = pcall(function()
            return (Enum.KeyCode :: any)[entry.key]
        end)
        if ok and code ~= nil then
            keys[code] = entry.open
        end
    end
    UserInputService.InputBegan:Connect(function(input: InputObject, processed: boolean)
        if processed then
            return
        end
        if input.KeyCode == Enum.KeyCode.Q or input.KeyCode == Enum.KeyCode.Escape then
            Panels.CloseAll()
            return
        end
        local action = keys[input.KeyCode]
        if action ~= nil then
            action()
        end
    end)
end

-- Starea balciului, copiata camp cu camp.
Net.Get("FairState").OnClientEvent:Connect(function(raw: { [string]: any })
    local rawVillage: any = raw.village or {}
    local village = {
        decor = table.clone(rawVillage.decor or {}),
        outfits = table.clone(rawVillage.outfits or {}),
        outfit = rawVillage.outfit or "keeper",
    }
    local rawWheel: any = raw.wheel or {}
    local wheel = {
        ready = rawWheel.ready == true,
        secondsLeft = rawWheel.secondsLeft or 0,
        spins = rawWheel.spins or 0,
    }
    local rawSettings: any = raw.settings or {}
    local musicLevel = if AudioLevels.valid(rawSettings.musicLevel)
        then rawSettings.musicLevel :: number
        else AudioLevels.DEFAULT_MUSIC
    local soundLevel = if AudioLevels.valid(rawSettings.soundLevel)
        then rawSettings.soundLevel :: number
        else AudioLevels.DEFAULT_SOUND
    local visits = if typeof(raw.visits) == "number" then raw.visits :: number else 0
    local rawTitles: any = raw.titles or {}
    local earned = {}
    for i, e in (rawTitles.earned or {}) do
        earned[i] = { id = e.id, label = e.label }
    end
    local forSale = {}
    for i, e in (rawTitles.forSale or {}) do
        forSale[i] = { id = e.id, label = e.label, price = e.price, owned = e.owned == true }
    end
    local titles = {
        worn = rawTitles.worn or "era",
        label = rawTitles.label or "",
        earned = earned,
        forSale = forSale,
        species = rawTitles.species or 0,
        speciesTotal = rawTitles.speciesTotal or 0,
        decor = table.clone(rawTitles.decor or {}),
        pondWins = if typeof(rawTitles.pondWins) == "number" then rawTitles.pondWins else 0,
        perfectGames = if typeof(rawTitles.perfectGames) == "number"
            then rawTitles.perfectGames
            else 0,
    }
    -- [D61] gheretele: cate jocuri cu premiu mai ai azi
    local rawBooth: any = raw.booth or {}
    local booth = {
        left = if typeof(rawBooth.left) == "number" then rawBooth.left else 0,
        perfect = if typeof(rawBooth.perfect) == "number" then rawBooth.perfect else 0,
    }
    local pearls = if typeof(raw.pearls) == "number" then raw.pearls :: number else 0
    local rawMarket: any = raw.market or {}
    local marketItems = {}
    for i, e in (rawMarket.items or {}) do
        marketItems[i] = {
            key = e.key,
            kind = e.kind,
            id = e.id,
            name = e.name,
            price = e.price,
            owned = e.owned == true,
        }
    end
    local market = { secondsLeft = rawMarket.secondsLeft or 0, items = marketItems }

    FairHUDController.SetPearls(pearls)
    TitleController.Apply(titles, pearls)
    MarketController.Apply(market, pearls)
    BoothController.Apply(booth)
    MusicController.Apply(musicLevel)
    SoundController.Apply(soundLevel)
    AudioPanel.Refresh()
    WheelController.Apply(wheel)
    CharacterController.SetOutfit(village.outfit)
    FairFerryController.Apply(village.outfit, visits)
end)

-- cerem starea de cateva ori: primul mesaj se poate pierde daca serverul nu e gata
Net.Get("RequestState"):FireServer()
task.delay(1, function()
    Net.Get("RequestState"):FireServer()
end)
task.delay(3, function()
    Net.Get("RequestState"):FireServer()
end)

print("[Fair] client bootstrap complet")
