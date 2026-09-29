--!strict
-- Gaterul [D48, D49]: departe de plase, la mijloc, sub alee, cu o curte in fata usii. Aici bustenii
-- devin scanduri. Doua gramezi, citite de la stanga la dreapta: ce ASTEAPTA sa fie taiat si ce A IESIT.
--
-- Fara Sawyer, gaterul taie DOAR cat stai langa el [owner, 2026-09-13: "ca eu sa prelucrez wood-ul ar
-- fi indeajuns daca doar stau langa sawmill"]. Serverul nu stie unde stai, deci clientul spune "sunt
-- aici" la intrarea in raza, la iesire si o data la doua secunde cat ramai; serverul tine prezenta
-- trei secunde si o lasa sa expire singura [D49].
--
-- E, un singur gest: lasi bustenii, apoi iei scandurile cat incap. Panza se misca doar cat taie --
-- un gater nemiscat cu gramada in fata spune singur ca lipseste cineva [D40, D43].
--
-- [D50] Locul unde stai are un inel pe jos si o placuta ("Stand here to cut"), desenate in lume, cat
-- timp n-ai Sawyer: auriu cand sunt busteni de taiat si nu esti acolo, verde ("Cutting — 12 left")
-- cat stai si taie. Panza suna rar si doar de aproape: o auzeai de oriunde, la fiecare secunda.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local RiverConfig = require(ReplicatedStorage.Shared.Config.RiverConfig)
local TycoonConfig = require(ReplicatedStorage.Shared.Config.TycoonConfig)
local Assets = require(ReplicatedStorage.Shared.Config.Assets)
local Strings = require(ReplicatedStorage.Shared.Config.Strings)
local SoundController = require(script.Parent.SoundController)
local Theme = require(script.Parent.Parent.UI.Theme)
local Widgets = require(script.Parent.Parent.UI.Widgets)
local PileView = require(script.Parent.Parent.UI.PileView)
local Focus = require(script.Parent.Parent.UI.Focus)
local StandRing = require(script.Parent.Parent.UI.StandRing)
local GroundShadow = require(script.Parent.Parent.UI.GroundShadow)
local PadArt = require(script.Parent.Parent.UI.PadArt)
local Modern = require(script.Parent.Parent.UI.Modern)

export type Deps = {
    Plot: Frame,
    Remotes: { UseSawmill: RemoteEvent, AtSawmill: RemoteEvent },
    CharacterPos: () -> (number, number),
    -- gaterul atins deschide meniul lui de niveluri; dat din Bootstrap
    OpenStation: ((string, string?) -> ())?,
}

export type Sack = {
    count: number,
    capacity: number,
    raw: number, -- [D55] lemnul brut; scrap-ul are `rawScrap` si drumul lui
    rawScrap: number,
    finds: number, -- [D56] gasirile neprelucrate (se vand si asa; incluse in `cut`)
    iron: number,
    cut: number,
    cutValue: number,
}
export type Snapshot = {
    count: number,
    contents: { [string]: number },
    out: number,
    outContents: { [string]: number },
    rate: number,
    present: boolean,
    staffed: boolean,
}

local SawmillController = {}
local deps: Deps
local blade: GuiObject? = nil
-- [D62, pasul 5] desenul cladirii: de la nivelul 25 gaterul are a doua infatisare (PadArt.station)
local buildingArt: ImageLabel? = nil
local buildingLevel = 1
local inPile: PileView.View
local outPile: PileView.View
local sack: Sack =
    { count = 0, capacity = 0, raw = 0, rawScrap = 0, finds = 0, iron = 0, cut = 0, cutValue = 0 }
local state: Snapshot = {
    count = 0,
    contents = {},
    out = 0,
    outContents = {},
    rate = 0,
    present = false,
    staffed = false,
}
local sawingUntil = 0
local lastSawSoundAt = -math.huge

local SM = TycoonConfig.SAWMILL
local STAND = TycoonConfig.SAWMILL_STAND
local PLOT_ORIGIN = TycoonConfig.PLOT_ORIGIN
local TOP_Y = SM.y - SM.h
-- [D55] Bustenii in stanga gaterului (unde lasa Porter-ul), scandurile in dreapta (de unde ia Hauler-ul):
-- drumul marfii prin gater se citeste de la stanga la dreapta, ca in desenul lui -- bustean, panza, scanduri.
local IN_SPOT = TycoonConfig.PILES.sawmillIn
local OUT_SPOT = TycoonConfig.PILES.sawmillOut
-- Cat timp dupa o taietura se mai misca panza. Starea vine de la server cel mult de doua ori pe
-- secunda cat taie, deci panza trebuie sa tina pana la urmatorul mesaj, altfel ar zvacni.
local SAWING_HOLD = 0.8
-- Sunetul panzei: cel mult o data la 4 s si doar pana la 300 px de gater, tot mai incet cu distanta.
-- La 1.2 s, oriunde ai fi, acoperea stropii plaselor -- sunetul care trebuie sa domine [owner, D50].
local SAW_SOUND_GAP = 4
local SAW_SOUND_RANGE = 300

local function distance(): number
    local cx, cy = deps.CharacterPos()
    local dx, dy = cx - PLOT_ORIGIN.x - STAND.x, cy - PLOT_ORIGIN.y - STAND.y
    return math.sqrt(dx * dx + dy * dy)
end

-- Impins din Bootstrap la fiecare TycoonState; campurile sunt copiate explicit acolo [CLAUDE.md].
-- [D62, pasul 5] Nivelul gaterului, din randurile statiilor: la pragul 25 cladirea isi schimba desenul.
function SawmillController.SetLevel(level: number)
    buildingLevel = level
    local art = buildingArt
    if art ~= nil then
        local sprite = PadArt.station("saw", level)
        art.Image = Assets.url(sprite)
        Modern.lights(art, sprite) -- [D70]
    end
end

-- [D70] Satul a urcat o treapta de modernizare: gaterul isi ia tabla si caramida (PadArt.station), apoi luminile.
function SawmillController.RefreshModern()
    SawmillController.SetLevel(buildingLevel)
end

function SawmillController.Apply(newSack: Sack, snap: Snapshot?)
    sack = newSack
    if snap == nil then
        return
    end
    -- A iesit ceva din gater intre doua mesaje? Atunci a taiat: panza se misca, clichetul suna. Nu si
    -- cand gramada de la intrare doar creste (s-a predat ceva) -- aia nu e taiere.
    if snap.out > state.out or (snap.count < state.count and snap.rate > 0) then
        local now = os.clock()
        sawingUntil = now + SAWING_HOLD
        local away = distance()
        if now - lastSawSoundAt >= SAW_SOUND_GAP and away <= SAW_SOUND_RANGE then
            lastSawSoundAt = now
            SoundController.Play("saw", nil, 1 - 0.7 * away / SAW_SOUND_RANGE)
        end
    end
    state = snap
    inPile.Set(snap.count, snap.contents)
    outPile.Set(snap.out, snap.outContents)
end

-- [D51] Cardul gaterului: lasi bustenii, sau iei scandurile. Cat tai de mana si mai sunt busteni,
-- scandurile NU se ofera: placuta spune "Cutting — N left", iar un "Take planks" aici te-ar trimite
-- la taverna cu treaba pe jumatate [owner, 2026-09-13]. Upgrade = nivelul gaterului.
function SawmillController.Focus(px: number, py: number): Focus.Focus?
    local d = Focus.distance(px, py, STAND.x, STAND.y)
    if d > RiverConfig.INTERACT_DISTANCE then
        return nil
    end
    local keyHint = if UserInputService.KeyboardEnabled then " (E)" else ""
    local cuttingByHand = not state.staffed and state.count > 0
    local text: string? = nil
    if sack.raw > 0 then
        text = Strings.promptDropLogs(keyHint)
    elseif state.out > 0 and sack.count < sack.capacity and not cuttingByHand then
        text = Strings.promptTakePlanks(keyHint)
    end
    return {
        key = "sawmill",
        distance = d,
        x = SM.x,
        y = TOP_Y - 6,
        action = text,
        act = if text ~= nil
            then function()
                deps.Remotes.UseSawmill:FireServer()
            end
            else nil,
        -- [D55] cu doar scrap in traista, cardul spune unde merge -- nu tace [D43]
        status = if text == nil and sack.rawScrap > 0
            then Strings.useResult("sawmill", false, "scrap_to_forge", 0, 0, false)
            else nil,
        upgradeKind = "saw",
    }
end

function SawmillController.Init(d: Deps)
    deps = d

    -- ---- cladirea ----
    GroundShadow.add(deps.Plot, UDim2.fromOffset(SM.x, SM.y), SM.w, 2) -- [D57]
    local marker = Instance.new("Frame")
    marker.Name = "Sawmill"
    marker.AnchorPoint = Vector2.new(0.5, 1)
    marker.Position = UDim2.fromOffset(SM.x, SM.y)
    marker.Size = UDim2.fromOffset(SM.w, SM.h)
    marker.BackgroundTransparency = 1
    marker.ZIndex = 3
    marker.Parent = deps.Plot

    local building = PadArt.station("saw", buildingLevel)
    if Assets.has(building) then
        local art = Instance.new("ImageLabel")
        art.Name = "Art"
        art.BackgroundTransparency = 1
        art.Image = Assets.url(building)
        art.ResampleMode = Enum.ResamplerMode.Pixelated
        art.Size = UDim2.fromScale(1, 1)
        art.ZIndex = 3
        art.Parent = marker
        buildingArt = art
        Modern.lights(art, building) -- [D70]
    else
        -- arta inca neurcata: un sopron de lemn simplu, cat sa se vada unde e gaterul [regula 6]
        marker.BackgroundTransparency = 0.15
        marker.BackgroundColor3 = Theme.COLOR.wood
        local corner = Instance.new("UICorner")
        corner.CornerRadius = UDim.new(0, 8)
        corner.Parent = marker
    end

    -- Panza: se misca doar cat taie. Fara pictograma, un disc de otel, ca tot sa se vada miscarea.
    local bladeArt = Widgets.Icon(marker, "saw", 34)
    if bladeArt ~= nil then
        bladeArt.AnchorPoint = Vector2.new(0.5, 0.5)
        bladeArt.Position = UDim2.new(1, -26, 0, 30)
        bladeArt.ZIndex = 4
        blade = bladeArt
    else
        local disc = Instance.new("Frame")
        disc.Name = "Blade"
        disc.AnchorPoint = Vector2.new(0.5, 0.5)
        disc.Position = UDim2.new(1, -26, 0, 30)
        disc.Size = UDim2.fromOffset(26, 26)
        disc.BackgroundColor3 = Color3.fromRGB(176, 184, 196)
        disc.ZIndex = 4
        disc.Parent = marker
        local round = Instance.new("UICorner")
        round.CornerRadius = UDim.new(1, 0)
        round.Parent = disc
        blade = disc
    end

    local tap = Instance.new("TextButton")
    tap.Name = "Tap"
    tap.Text = ""
    tap.AutoButtonColor = false
    tap.BackgroundTransparency = 1
    tap.Size = UDim2.fromScale(1, 1)
    tap.ZIndex = 5
    tap.Parent = marker
    tap.Activated:Connect(function()
        if deps.OpenStation ~= nil then
            (deps.OpenStation :: (string, string?) -> ())("saw", nil)
        end
    end)

    local label =
        Widgets.Label(marker, Strings.SAWMILL_LABEL, Theme.TEXT.tiny, Theme.COLOR.onDark, "strong")
    label.AnchorPoint = Vector2.new(0.5, 1)
    label.Position = UDim2.new(0.5, 0, 1, -6)
    label.Size = UDim2.fromOffset(SM.w - 8, 18)
    label.TextXAlignment = Enum.TextXAlignment.Center
    label.ZIndex = 6
    Theme.punch(label, 2)

    inPile = PileView.new(deps.Plot, IN_SPOT.x, IN_SPOT.y, { warnAt = 40, pill = IN_SPOT.pill })
    outPile = PileView.new(deps.Plot, OUT_SPOT.x, OUT_SPOT.y, { warnAt = 40, pill = OUT_SPOT.pill })

    -- ---- locul tau: inelul de pe jos si placuta de deasupra lui [D50], comune cu forja [D56] ----
    StandRing.new({
        plot = deps.Plot,
        name = "Sawmill",
        stand = STAND,
        remote = deps.Remotes.AtSawmill,
        characterPos = deps.CharacterPos,
        standHere = Strings.SAWMILL_STAND_HERE,
        working = Strings.sawmillCutting,
        state = function(): (number, boolean)
            return state.count, state.staffed
        end,
    })

    RunService.PreRender:Connect(function()
        local b = blade
        if b ~= nil then
            -- se leagana doar cat taie: o panza care se misca si fara marfa ar minti [D40]
            local now = os.clock()
            b.Rotation = if now < sawingUntil then math.sin(now * 22) * 18 else 0
        end
    end)
end

return SawmillController
