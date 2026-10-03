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
local TitleMath = require(ReplicatedStorage.Shared.Modules.TitleMath) -- [D71] titlurile seriei zilnice
local FlowConfig = require(ReplicatedStorage.Shared.Config.FlowConfig)
local StationConfig = require(ReplicatedStorage.Shared.Config.StationConfig)
local WorldConfig = require(ReplicatedStorage.Shared.Config.WorldConfig) -- [D70, pasul k1]
local StateCopy = require(ReplicatedStorage.Shared.Modules.StateCopy) -- [D70, pasul k3]
-- [D70, pasul k3] piesele fiecarei uniri din joc (Relay-ul barajului: butoaie si cablu), pentru copia starii
local PARTS_OF = StateCopy.partsOf(FlowConfig.LINES)
local UNIONS: { [string]: boolean } = {}
for line in PARTS_OF do
    UNIONS[line] = true
end
-- [D65, D67] Platforma care deschide fiecare vanzator al erelor noi: a atelierului primei lui linii (FlowConfig).
local sellerOpenPad: { [string]: string } = {}
local sellerSeen: { [string]: boolean } = {}
for _, line in StationConfig.LINE_ORDER do
    local spec = FlowConfig.LINES[line]
    -- [D70] o piesa a unei uniri n-are vanzator (se vinde doar unita): fara garda, `sellerSeen[nil]` oprea tot clientul
    local seller = spec.seller
    if seller ~= nil and not sellerSeen[seller] then
        sellerSeen[seller] = true
        sellerOpenPad[seller] = spec.processorPad -- nil pentru taverna: e deschisa de la inceput
    end
end
local AudioLevels = require(ReplicatedStorage.Shared.Modules.AudioLevels)
local LookMath = require(ReplicatedStorage.Shared.Modules.LookMath)
local ModernMath = require(ReplicatedStorage.Shared.Modules.ModernMath)
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
local LampController = require(Controllers.LampController)
local ModernController = require(Controllers.ModernController)
local LookController = require(Controllers.LookController)
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

-- [D70, pasul k1] LUMEA, CITITA O SINGURA DATA, dupa profil: serverul pune atributul `World` inaintea lui `SaveLoaded`
-- (DataService). Cat profilul nu vine (cel mult 25 s, ca ecranul de incarcare), satul. De aici o primesc controllerele,
-- explicit (`Init({ World = world })`); nimic din client nu citeste atributul singur. O stare a altei lumi (ridicarea
-- barajului, o unealta de proba) nu se deseneaza peste harta asta: clientul asteapta reincarcarea (k8).
local world: number
-- [D70, pasul k6] barajul se poate ridica acum (TycoonState.damAvailable): masa Dam Plans il citeste la fiecare cadru
local damAvailable = false
do
    -- [verificatorul k1] cat asteptam profilul, imaginile mari ale hartii se incarca deja (satul se construieste abia
    -- dupa profil; inainte de k1 se construia in spatele cortinei si avea timp)
    task.spawn(function()
        local Assets = require(ReplicatedStorage.Shared.Config.Assets)
        local urls: { string } = {}
        for _, sprite in
            {
                Assets.tycoon.village_ground,
                Assets.tycoon.village_ground_2,
                Assets.water_tile,
                Assets.grass_tile,
                Assets.sand_tile,
            }
        do
            if Assets.has(sprite) then
                table.insert(urls, Assets.url(sprite))
            end
        end
        pcall(function()
            game:GetService("ContentProvider"):PreloadAsync(urls)
        end)
    end)
    local started = os.clock()
    while player:GetAttribute("SaveLoaded") ~= true and os.clock() - started < 25 do
        task.wait(0.1)
    end
    world = WorldConfig.sanitize(player:GetAttribute("World"))
    if player:GetAttribute("SaveLoaded") ~= true then
        warn("[Driftwood] profilul n-a venit in 25 s: clientul porneste pe harta satului")
    end
end

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
local DamController = require(Controllers.DamController) -- [D70, pasul j15]
local DamScreen = require(Controllers.DamScreen) -- [D70, pasul k7]
local DamFilm = require(Controllers.DamFilm) -- [D70, pasul k9]
local AmbientController = require(Controllers.AmbientController) -- [D62, pasul 5]
local Theme = require(UI.Theme)
local layers = CameraController.Init({ WorldGui = worldGui, World = world })

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
            -- daca te misti tu, camera se intoarce la personajul tau, lin [D70]. Incadrarea darului de pe rau ramane: te
            -- urmeaza oricum (e socotita din pozitia ta) si se stinge singura, lin, cand darul trece; stearsa aici, camera
            -- sarea ~140 px la primul pas [verificator, 2026-09-30].
            LookController.Cancel()
        end,
        World = world, -- [D70, pasul k1] spawn-ul si zidurile hartii tale
    })
end)
-- [D70, pasul k1] privirea spre satul vechi (treptele modernizarii) e doar a satului: la baraj nu porneste, iar fara ea
-- butonul „Look (V)” nu apare (LookController e tacut fara Init)
if world == 1 then
    safeInit("LookController", function()
        LookController.Init({ CharacterPos = CharacterController.Position })
    end)
end

-- [D70] Bannerul unei trepte a modernizarii (sau al felinarelor aprinse), cu butonul "Look (V)" cand locul schimbat, din
-- satul vechi, nu e pe ecran: o privire de 4 s spre el (LookController).
-- [2026-09-30] Un banner cu buton sau cu recompensa asteapta sa nu stea nimic in fata lui: un meniu, fereastra de revenire.
local function screenClear(): boolean
    return not Panels.AnyOpen() and not WelcomeController.IsOpen()
end

-- Un banner, cu „Look around (V)” spre un loc al terenului (coordonatele lui TycoonConfig) daca nu se vede de unde stai.
local function lookMoment(title: string, at: { x: number, y: number }?)
    local action: CeremonyController.Action? = nil
    if at ~= nil then
        local origin = TycoonConfig.PLOT_ORIGIN
        local x, y = at.x + origin.x, at.y + origin.y
        local keyHint = if UserInputService.KeyboardEnabled then " (V)" else ""
        action = {
            text = Strings.lookAround(keyHint),
            key = Enum.KeyCode.V,
            run = function()
                -- plasa de siguranta: butonul se vede doar fara meniu deschis, dar un meniu deschis in acelasi cadru cu V
                -- nu ramane peste sat
                Panels.CloseAll()
                LookController.Look(x, y)
            end,
            -- hotarat cand bannerul chiar apare (poate asteapta la rand): locul nu se vede de unde stai
            useful = function(): boolean
                return LookController.OffScreen(x, y)
            end,
        }
    end
    CeremonyController.PlayMoment(title, nil, action, {
        -- clopotelul suna odata cu bannerul, nu inaintea lui
        onShow = function()
            SoundController.Play("chime")
        end,
        -- anuntul asteapta sa inchizi meniul din care ai cumparat treapta (sau fereastra de revenire): peste el acoperea
        -- capul meniului, sub el nu se vedea
        ready = screenClear,
    })
end
local function modernMoment(title: string, stage: number)
    local visibleW = CameraController.VisibleSize()
    lookMoment(title, TycoonConfig.modernLookAt(stage, visibleW))
end
safeInit("RiverRenderController", function()
    RiverRenderController.Init({
        Layers = layers,
        RiverConfig = Net.Get("RiverConfig"),
        World = world, -- [D70, pasul k1] fundalul, raul si decorul din larg ale hartii tale
    })
end)
-- [D62, pasul 5] pasarile care trec peste sat (doar desen)
safeInit("AmbientController", function()
    AmbientController.Init({ Scroll = layers.Scroll, World = world })
end)
-- [D62, pasul 3] darurile raului: devreme, ca sa prinda configul raului (samanta); zborul monedelor se leaga mai jos
safeInit("DriftController", function()
    DriftController.Init({
        Plot = layers.Plot,
        CharacterPos = CharacterController.Position,
        RiverConfig = Net.Get("RiverConfig"),
        Remotes = { GrabDrift = Net.Get("GrabDrift"), DriftGrabbed = Net.Get("DriftGrabbed") },
        OnToast = HUDController.Toast,
        World = world, -- [D70, pasul k1] puntile de pe care se scoate un dar si zidul peste care nu se vede
    })
end)
safeInit("ZoneController", function()
    ZoneController.Init({ Plot = layers.Plot, World = world })
end)
-- [D67] felinarele de pe strada: se aprind cu primul curent vandut, iar prima aprindere se anunta [D43]
safeInit("LampController", function()
    LampController.Init({
        Plot = layers.Plot,
        World = world, -- [D70, pasul k2] felinarele strazii hartii tale
        OnFirstLight = function()
            -- felinarele se aprind si in satul vechi: privirea e cea a treptei luminilor
            modernMoment(Strings.LAMPS_ON, ModernMath.stageOf("lights") or 0)
        end,
    })
end)
-- [D70] satul vechi se modernizeaza pe trepte in Era 3; fiecare treapta noua se anunta [D43], pe rand, dupa toastul
-- cumparaturii care a urcat-o (ModernController o tine la coada)
-- [D70, pasul k1] doar in sat: treptele lui, stalpii, masa Dam Plans
if world == 1 then
    safeInit("ModernController", function()
        ModernController.Init({
            Plot = layers.Plot,
            Refresh = {
                SawmillController.RefreshModern,
                DockController.RefreshModern,
                StorageController.RefreshModern,
                PadController.RefreshModern,
                HandRenderController.SetModern,
                LampController.RefreshModern, -- [D73] felinarele apar odata cu stalpii
            },
            OnStage = function(stage: number)
                local line = Strings.MODERN_STAGE[stage]
                if line ~= nil then
                    modernMoment(line, stage)
                end
            end,
            Look = function(x: number, y: number, note: string)
                Panels.CloseAll()
                HUDController.Toast(note)
                local origin = TycoonConfig.PLOT_ORIGIN
                LookController.Look(x + origin.x, y + origin.y)
            end,
            -- [D70, pasul k6] cu barajul in joc, masa il ridica: E deschide ecranul „Build the Dam” (k7)
            DamAvailable = function(): boolean
                return damAvailable
            end,
            OpenDam = function()
                DamScreen.Open()
            end,
        })
        -- [2026-09-30] masa cu planurile barajului: cardul ei spune ce vine
        InteractController.AddSource(ModernController.Focus)
    end)
end
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
        World = world, -- [D70, pasul k2] doar platformele hartii tale, cu conditiile ei
    })
end)
-- Depozitul [D49]: aici varsa Collector-ul ce strange din plase, de aici ia Porter-ul.
-- [D65] liniile si vanzatorii Erei 2 (LineController), dupa numele liniei si al vanzatorului
local millLines: { [string]: LineController.Line } = {}
local millSellers: { [string]: LineController.Seller } = {}
-- [D70, pasul k1] LUCRURILE SATULUI (depozitul, shed-ul, forja, Moara, Wire Works, gaterul, taverna) pornesc doar in sat:
-- la baraj locurile lor sunt ale altor cladiri. Starea nu le mai cere nimic acolo (vezi `world == 1` din TycoonState).
if world == 1 then
    safeInit("StorageController", function()
        StorageController.Init({
            Plot = layers.Plot,
            Remotes = { UseStorage = Net.Get("UseStorage") },
            CharacterPos = CharacterController.Position,
            OpenCrew = openCrew,
        })
    end)
end
-- [D55, D56] Shed-ul de scrap si forja: gramezile lor si gestul tau pe E. Fara Smelter, forja topeste doar cat stai
-- in inelul ei, ca gaterul.
if world == 1 then
    safeInit("ShedController", function()
        ShedController.Init({ Plot = layers.Plot, Remotes = { UseShed = Net.Get("UseShed") } })
    end)
end
-- [D65] liniile dupa tabel (LineController): in ambele lumi; ce linii si vanzatori se deseneaza, dupa lume (k3 = barajul)
safeInit("LineController", function()
    LineController.Init({
        Plot = layers.Plot,
        Remotes = {
            UsePlace = Net.Get("UsePlace"),
            AtPlace = Net.Get("AtPlace"),
            Sold = Net.Get("Sold"), -- [D65] clientii Pietei vin dupa vanzarile ei
        },
        CharacterPos = CharacterController.Position,
    })
end)
if world == 1 then
    safeInit("ForgeController", function()
        ForgeController.Init({
            Plot = layers.Plot,
            Remotes = { UseForge = Net.Get("UseForge"), AtForge = Net.Get("AtForge") },
            CharacterPos = CharacterController.Position,
        })
        -- [D65] ERA 2, The Mill: locurile liniilor ei, dupa tabel. Magazia Morii, turnatoria si Piata sunt cladiri fixe
        -- (apar cu roata de apa); magazia de minereu si cuptorul de cupru sunt platforme, deci le deseneaza PadController.
        -- Pana la arta lor (docs/PLAN-ERA2.md, pasul 7) poarta desenele perechii din Era 1.
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
        -- [D67] ERA 3, The Wire Works, la fel: Works Store, Wire Works si Depot sunt cladiri fixe (apar cu masina cu abur);
        -- Battery Shed si Power House sunt platforme. Pana la arta lor (docs/PLAN-ERA3.md, pasul 7) poarta desenele Morii.
        millLines.coils = LineController.line(
            "coils",
            fixedBuilding(
                TycoonConfig.WORKS_STORE,
                "works_store",
                "mill_store",
                Strings.LINE_WORDS.coils.store
            ),
            fixedBuilding(
                TycoonConfig.WIRE_WORKS,
                "wire_works",
                "foundry",
                Strings.LINE_WORDS.coils.processor
            )
        )
        millLines.power = LineController.line("power", nil, nil)
        millSellers.depot = LineController.seller(
            "depot",
            fixedBuilding(TycoonConfig.DEPOT, "depot", "market", Strings.LINK_WORDS.depot.label)
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
end
-- [D70, pasul k3] LINIILE ALTEI HARTI (barajul), toate din tabele: liniile si vanzatorii erelor ei, cu cladirile fixe din
-- `TycoonConfig.WORLDS[world].buildings` (dupa numele locului: magazia, atelierul, unirea). Ce sta pe o platforma (Crystal
-- Shed, Kiln) il deseneaza PadController. Pana la arta barajului (A0-A4), fiecare cladire poarta desenul unei cladiri din
-- erele dinainte, fiecare alta (doua cladiri identice una langa alta ar parea acelasi loc). In sat nu se intra aici.
local WORLD_BUILDING_ART: { [string]: { own: string, borrowed: string } } = {
    damStore = { own = "dam_store", borrowed = "works_store" },
    switchyard = { own = "switchyard", borrowed = "wire_works" },
    cableStore = { own = "cable_store", borrowed = "mill_store" },
    cableworks = { own = "cable_works", borrowed = "foundry" },
    relay = { own = "relay_station", borrowed = "copper_furnace" }, -- un atelier, nu o taraba [verificatorul k3]
    town = { own = "switch_house", borrowed = "depot" },
}
if world ~= 1 then
    safeInit("WorldLines", function()
        local spots: { [string]: { x: number, y: number, w: number, h: number } } = (
            TycoonConfig.WORLDS[world] :: any
        ).buildings or {}
        local function fixedAt(
            spot: { x: number, y: number, w: number, h: number }?,
            artKey: string,
            label: string
        ): LineController.Building?
            local look = WORLD_BUILDING_ART[artKey]
            if spot == nil or look == nil then
                return nil
            end
            return {
                x = spot.x,
                y = spot.y,
                w = spot.w,
                h = spot.h,
                sprite = look.own,
                borrowed = look.borrowed,
                label = label,
            }
        end
        for _, line in StationConfig.LINE_ORDER do
            local spec = FlowConfig.LINES[line]
            if WorldConfig.worldOfEra(spec.era) ~= world then
                continue
            end
            local words = Strings.LINE_WORDS[line]
            if spec.joins ~= nil then
                local building = fixedAt(spots[spec.processor], spec.processor, words.processor)
                if building ~= nil then
                    millLines[line] = LineController.join(line, building)
                end
            else
                local store = spec.store
                millLines[line] = LineController.line(
                    line,
                    if store ~= nil then fixedAt(spots[store], store, words.store) else nil,
                    fixedAt(spots[spec.processor], spec.processor, words.processor)
                )
            end
        end
        for _, seller in StationConfig.SELLER_ORDER do
            local spec = FlowConfig.SELLERS[seller]
            if WorldConfig.worldOfEra(spec.era) ~= world then
                continue
            end
            local building = fixedAt(
                TycoonConfig.SELLER_PLACES[seller].building,
                seller,
                Strings.LINK_WORDS[seller].label
            )
            if building ~= nil then
                millSellers[seller] = LineController.seller(seller, building)
            end
        end
        for _, line in millLines do
            InteractController.AddSource(line.FocusStore)
            InteractController.AddSource(line.FocusProcessor)
        end
        for _, seller in millSellers do
            InteractController.AddSource(seller.Focus)
        end
    end)
end
-- [D70, pasul k1] la baraj, din taverna ramane doar pontonul (acelasi loc, pe malul lacului)
safeInit("DockController", function()
    if world ~= 1 then
        DockController.BuildPier(layers.Plot)
        return
    end
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
        World = world, -- [D70, pasul k1] de unde pornesc plutitorii spre plase (fata zidului, la baraj)
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
        Scroll = layers.Scroll,
        CharacterPos = CharacterController.Position,
        OpenStation = openStation,
        OnToast = HUDController.Toast,
        -- [2026-09-30] cat tine o privire "Look", cardul nu se vede (camera nu e pe tine)
        Looking = LookController.Active,
        ViewTop = function(): number
            local _, camY = CameraController.WorldOrigin()
            return camY - TycoonConfig.PLOT_ORIGIN.y
        end,
    })
end)

-- [2026-09-30] toast-urile ies sub bannerul de pe ecran (HUDController nu poate cere CeremonyController: bucla prin Juice)
HUDController.SetToastFloor(CeremonyController.BottomY)
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
-- [D70, pasul k7] ecranul „Build the Dam” (il deschide masa Dam Plans, k6), apoi cererile si raspunsurile (j15)
safeInit("DamFilm", function()
    DamFilm.Init({
        SetHudVisible = function(visible: boolean)
            hudGui.Enabled = visible
        end,
    })
end)
safeInit("DamScreen", function()
    DamScreen.Init({ HudGui = hudCanvas })
end)
safeInit("DamController", function()
    DamController.Init({
        Remotes = {
            DamPreview = Net.Get("DamPreview"),
            DamPreviewResult = Net.Get("DamPreviewResult"),
            BuildDam = Net.Get("BuildDam"),
            DamBuilt = Net.Get("DamBuilt"),
            DamRejected = Net.Get("DamRejected"),
            DamFilmSeen = Net.Get("DamFilmSeen"),
            DamReloadFailed = Net.Get("DamReloadFailed"), -- [D70, pasul k8]
        },
        OnToast = function(text: string, color: Color3?)
            HUDController.Toast(text, color)
        end,
        OnPreview = DamScreen.OnPreview,
        OnBuilt = DamScreen.OnBuilt,
        OnRejected = DamScreen.OnRejected,
        OnReloadFailed = DamScreen.OnReloadFailed,
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
            -- bannerul capitolului (si fanfara lui) vine cand inchizi Quests, din care l-ai revendicat: sub panou nu se
            -- vedea; perlele zboara pe loc
            CeremonyController.PlayMoment(title, subtitle, nil, {
                onShow = function()
                    SoundController.PlayMilestone()
                end,
                ready = screenClear,
            })
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
        IsBought = PadController.IsBought,
        -- [D70, pasul k6] in sat, cu barajul gata de ridicat: nivelurile de aici intra in el
        DamAvailable = function(): boolean
            return damAvailable
        end,
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
        IsBought = PadController.IsBought,
        World = world, -- [D70, pasul k2] cartierele hartii tale
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
-- [D71] seria zilnica vazuta ultima data (nil pana la prima stare)
local streakSeen: { run: number, best: number }? = nil
-- [D71] Fusul orar al jucatorului (secunde fata de UTC), din ceasul local: ziua seriei zilnice e ziua lui, nu cea UTC.
-- Il spunem serverului o singura data, dupa prima stare (profilul e incarcat); serverul il valideaza.
local function localClockOffset(): number
    local now = DateTime.now()
    local l = now:ToLocalTime()
    return DateTime.fromUniversalTime(l.Year, l.Month, l.Day, l.Hour, l.Minute, l.Second).UnixTimestamp
        - now.UnixTimestamp
end

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
--   cinematic:play       [D70, pasul k9] porneste filmul barajului (fara reincarcare; la capat se ridica)
--   cinematic:seek:<t>   sare la secunda t a filmului, ca textul fiecarei faze sa se poata citi
-- Doar in Studio: intr-un joc publicat atributul nu e ascultat deloc.
if game:GetService("RunService"):IsStudio() then
    Workspace:GetAttributeChangedSignal("DevUi"):Connect(function()
        local raw = Workspace:GetAttribute("DevUi")
        if typeof(raw) ~= "string" then
            return
        end
        local action = string.match(raw, "^[%w_]+|(.*)$") or raw
        local verb, a, b = string.match(action, "^(%w+):?([^:]*):?(.*)$")
        if verb == "cinematic" then
            if a == "play" then
                DamFilm.Play(true, DamFilm.Stop)
            elseif a == "seek" then
                DamFilm.Seek(tonumber(b) or 0)
            end
            return
        end
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
-- [D67] ce e in traista, pe vanzatori (din ultimul TycoonState): un refuz "other_seller" numeste vanzatorul potrivit
local lastSellBy: { [string]: { count: number, value: number } } = {}
local function sellerElsewhere(place: string): string?
    for _, seller in StationConfig.SELLER_ORDER do
        local entry = lastSellBy[seller]
        if seller ~= place and entry ~= nil and entry.count > 0 then
            return seller
        end
    end
    return nil
end
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
                staffedAt[place] == true,
                sellerElsewhere(place)
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
        Scroll = layers.Scroll,
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
        World = world, -- [D70, pasul k2b] decorul sta pe locurile lumii (la baraj, uscatul in piata Dam Town)
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
            ScreenClear = screenClear,
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
            -- [D73] atelierul unei linii noi s-a deschis: bannerul cu „Look around (V)” spre el
            LookMoment = function(title: string, x: number, y: number)
                lookMoment(title, { x = x, y = y })
            end,
            World = world, -- [D70, pasul k1]
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
-- [D70, pasul k1] GARDA LUMII: clientul e construit pentru o singura harta. Daca lumea profilului se schimba (ridicarea
-- barajului, o unealta de proba), starea noua nu se mai deseneaza peste harta asta: ramane ultima stare a ei pana la
-- reincarcare (k8). Si atributul, si campul `world` din stare o spun.
local frozen = false
Players.LocalPlayer:GetAttributeChangedSignal("World"):Connect(function()
    if WorldConfig.sanitize(Players.LocalPlayer:GetAttribute("World")) ~= world then
        frozen = true
    end
end)
Net.Get("TycoonState").OnClientEvent:Connect(function(raw: { [string]: any })
    if frozen or WorldConfig.sanitize(raw.world) ~= world then
        frozen = true
        return
    end
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
    -- [D65] fiecare zona a hartii tale, copiata dupa id (o zona pe care serverul n-o trimite ramane inchisa). [D70] Pe
    -- lumea ta: la baraj, Dam Town si ceata Erei 5
    local zones: { [string]: string } = {}
    for _, zone in TycoonConfig.zonesOf(world) do
        local status = raw.zones[zone.id]
        zones[zone.id] = if typeof(status) == "string" then status else "locked"
    end
    local firsts = {
        collect = raw.firsts.collect,
        sell = raw.firsts.sell,
        named = raw.firsts.named,
        runner = raw.firsts.runner,
        bell = raw.firsts.bell,
        power = raw.firsts.power == true, -- [D67] copiat explicit, ca orice camp nou [CLAUDE.md, capcana 3]
    }
    local sack = raw.sack
    local sackCount, sackCapacity, sackValue = sack.count, sack.capacity, sack.value
    -- CE duce jucatorul, nu doar cat -- DockController deseneaza gramada de la ponton cu ea
    -- [research 42 pct.6]. table.clone, acelasi motiv ca la nets.contents de mai sus.
    local sackContents: { [string]: number } = table.clone(sack.contents)
    -- brut / taiat [D49]: fiecare loc de predare decide din asta ce face un E. [D55] `raw` = lemnul brut,
    -- `rawScrap` = scrap-ul brut (forja), `iron` = fierul, gata de vandut; [D56] `finds` = gasirile neprelucrate,
    -- care se vand si asa (sunt numarate si in `cut`).
    local sackBy =
        StateCopy.sackBy(sack, StationConfig.LINE_ORDER, StationConfig.SELLER_ORDER, UNIONS)
    local sackState = {
        count = sackCount,
        capacity = sackCapacity,
        raw = sack.raw or 0,
        rawScrap = sack.rawScrap or 0,
        finds = sack.finds or 0,
        iron = sackContents.iron or 0,
        cut = sack.cut or 0,
        cutValue = sack.cutValue or 0,
        -- [D65] pe linii si pe vanzatori, [D70, pasul k3] si piesele pe unirea lor: copiate camp cu camp (StateCopy)
        rawBy = sackBy.rawBy,
        sellBy = sackBy.sellBy,
        partBy = sackBy.partBy,
        contents = sackContents, -- [verificatorul k3] ce piesa a unirii duci (cardul Relay-ului)
    }
    lastSellBy = sackState.sellBy -- [D67]

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
                -- [D70, pasul k5] contorul scris de server ("3/10", la venit "966B/1T")
                counter = if typeof(q.counter) == "string"
                    then q.counter
                    else `{math.floor(q.progress)}/{q.goal}`,
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
            lastOfWorld = rawQuests.lastOfWorld == true, -- [D70] ultimul capitol al lumii tale: randul de final
            -- [D70] era care vine pe harta ta (de la server), pentru randul de final
            coming = if typeof(rawQuests.coming) == "string" then rawQuests.coming else nil,
            -- [D70, pasul k6] "soon" sau "build" (barajul, in joc pe alta harta: masa Dam Plans)
            comingKind = if typeof(rawQuests.comingKind) == "string"
                then rawQuests.comingKind
                else nil,
            active = if a == nil
                then nil
                else {
                    id = a.id,
                    text = a.text,
                    progress = a.progress,
                    goal = a.goal,
                    counter = if typeof(a.counter) == "string"
                        then a.counter
                        else `{math.floor(a.progress)}/{a.goal}`, -- [D70, pasul k5]
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
    -- [D65] vederea pe linii; [D70, pasul k3] cu `supply`, `heldBy`, `isOpen`, `waiting` (StateCopy)
    local stationLines: { [string]: StateCopy.LineView } = {}
    local stationLinkRates: { [string]: number } = {}
    for _, line in StationConfig.LINE_ORDER do
        local entry: any = if typeof(rawStations.lines) == "table"
            then rawStations.lines[line] or {}
            else {}
        stationLines[line] = StateCopy.lineView(entry, line)
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
        -- [D70, pasul k3] ale cui plase tin venitul, cand veriga e "nets" ("" altfel)
        netsLine = if typeof(rawStations.netsLine) == "string" then rawStations.netsLine else "",
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
        -- [D70, pasul k3] la o unire si cate piese din fiecare si ce lipseste (StateCopy)
        local copied = StateCopy.flowLine(entry, PARTS_OF[line])
        flowLines[line] = copied
        staffedAt[FlowConfig.LINES[line].processor] = copied.processor.staffed == true
    end
    local flowSellers: { [string]: LineController.SellerState } = {}
    for _, seller in StationConfig.SELLER_ORDER do
        local entry: any = if typeof(rawFlow.sellers) == "table"
            then rawFlow.sellers[seller] or {}
            else {}
        flowSellers[seller] = StateCopy.flowSeller(entry)
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
    -- [D71] seria zilnica, copiata camp cu camp
    local rawStreak: any = if typeof(rawFair.streak) == "table" then rawFair.streak else {}
    local fair = {
        visits = rawFair.visits or 0, -- [D60]
        streakRun = if typeof(rawStreak.run) == "number" then rawStreak.run else 0,
        streakBest = if typeof(rawStreak.best) == "number" then rawStreak.best else 0,
    }

    local rawSettings: any = raw.settings or {}
    damAvailable = raw.damAvailable == true -- [D70, pasul k6] copiat explicit
    local snapshot = {
        world = world, -- [D70, pasul k1] harta pentru care e construit clientul (starea altei harti nu ajunge aici)
        damAvailable = damAvailable, -- [D70, pasul k6] masa Dam Plans, zona barajului, fereastra de revenire
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
            partBy = sackState.partBy, -- [D70, pasul k3] piesele, pe unirea lor (GuideMath, Overlay)
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
        -- [D70] la baraj tutorialul satului e de mult trecut (First Net nici nu e in statusurile hartii)
        firstNetBought = world ~= 1 or snapshot.pads.first_net == "bought",
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
    -- [D71] o zi noua in timpul jocului (miezul noptii tale): seria creste si se spune. La intrare o spune fereastra de
    -- revenire, deci prima stare doar retine seria.
    local run, best = snapshot.fair.streakRun, snapshot.fair.streakBest
    local seen = streakSeen
    if seen ~= nil and run > seen.run and run >= 2 then
        -- recordul si titlul, din cea mai lunga serie de dinainte (TitleMath: pragurile titlurilor seriei)
        local title = TitleMath.streakTitleReached(seen.best, best)
        HUDController.Toast(Strings.streakNext(run, run > seen.best, title), Theme.COLOR.gold)
    end
    if streakSeen == nil then
        Net.Get("SetClock"):FireServer(localClockOffset())
    end
    streakSeen = { run = run, best = best }
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
    -- [D70] treapta modernizarii, din platformele cumparate, oamenii meseriilor si primul curent vandut. INAINTE de orice
    -- desenare din starea asta: ce apare acum (casa noua, al doilea om) se deseneaza direct pe treapta noua si isi
    -- pastreaza "rasaritul" [D55], iar redesenarea treptei atinge doar ce era deja pe harta.
    local boughtPads: { [string]: boolean } = {}
    for padId, status in snapshot.pads do
        if status == "bought" then
            boughtPads[padId] = true
        end
    end
    local crewCountsNow: { [string]: number } = {}
    for _, crew in snapshot.stations.crews do
        crewCountsNow[crew.role] = crew.count
    end
    if world == 1 then
        ModernController.Apply({
            pads = boughtPads,
            crews = crewCountsNow,
            powerSold = snapshot.firsts.power == true,
        })
    end
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
        elseif row.kind == "powerhouse" then
            PadController.SetBuildingLevel("power_house", row.level) -- [D67]
        end
    end
    PadController.SetCrews(crewCounts, crewTiers) -- [D55] inainte de Apply: prima desenare alege deja casa potrivita
    PadController.SetChain(snapshot.stations) -- [D63] cartonasul unei platforme fara castig spune cine o tine, pe linia ei
    -- [D70, pasul k2] venitul de acum si 2x Flow: conditia de venit a Dam Bell, spusa ca pe server
    PadController.SetIncome(
        snapshot.incomePerSec,
        if typeof(raw.flowFactor) == "number" then raw.flowFactor else 1
    )
    PadController.Apply(
        snapshot.pads,
        snapshot.coins,
        snapshot.padDeltas,
        snapshot.bottleneck,
        snapshot.stations.netLevels
    )
    -- [D55, D65] ce pluteste in larg: marfa pe care plasele tale inca n-o prind. Scrap-ul pana la Fifth Net; minereul
    -- de cand porneste Moara pana la Tenth Net (marfa noua apare cand o poti folosi [D64]).
    -- [D70] la baraj, nimic promis inca (marfa lui o aduc plasele lui)
    RiverRenderController.SetPromise(
        if world ~= 1
            then nil
            elseif snapshot.pads.fifth_net ~= "bought" then "scrap"
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
    -- [D70, pasul k1] lucrurile satului, doar in sat (la baraj nu sunt pornite)
    if world == 1 then
        StorageController.Apply(sackState, snapshot.storage, snapshot.stations.woodBottleneck)
        ShedController.Apply(
            sackState,
            snapshot.shed,
            snapshot.pads.scrap_shed == "bought",
            snapshot.stations.ironBottleneck
        )
        ForgeController.Apply(sackState, snapshot.forge, snapshot.workshop == true)
    end
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
    -- [D65, D67] un vanzator se deschide odata cu prima lui linie: Piata cu roata de apa, Depoul cu masina cu abur;
    -- [D70, pasul k3] fara platforma (Switch House-ul barajului), e deschis de la inceput
    for seller, controller in millSellers do
        local openPad = sellerOpenPad[seller]
        controller.Apply(
            sackState,
            snapshot.flow.sellers[seller],
            openPad == nil or snapshot.pads[openPad] == "bought"
        )
    end
    if world == 1 then
        SawmillController.Apply(sackState, snapshot.sawmill)
        DockController.Apply(sackState, snapshot.dock)
    end
    StationPanel.Apply(snapshot.stations)
    StationMenu.Apply(snapshot.stations)
    HandRenderController.Apply(snapshot.hands)
    ZoneController.Apply(snapshot.zones, snapshot.damAvailable) -- [D70, pasul k6]
    -- [D73] darurile se scot de pe puntea oricarui cartier deschis; [D70] aceeasi regula ca serverul, din platforme
    DriftController.SetPads(boughtPads)
    LampController.Apply(snapshot.firsts.power == true) -- [D67]

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

-- [verificatorul k1] harta e construita: cortina de incarcare (Loading.client) o asteapta, ca satul sa nu apara pe bucati
Players.LocalPlayer:SetAttribute("ClientBuilt", true)
print("[Driftwood] client bootstrap complet")
