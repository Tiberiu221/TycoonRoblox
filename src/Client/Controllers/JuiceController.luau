--!strict
-- Micile rasplati vizuale peste HUD [F1 spec 5.3, O2]: monedele care zboara de la vanzare pana la
-- contor (W4) si mica rafala de la ceremonia de clopot. Nu stie nimic despre lume sau despre
-- camera -- primeste mereu coordonate HUD deja convertite (Overlay face conversia cu WorldToHud)
-- sau coordonate SCALE relative la orice parinte i se da (Burst).
--
-- F2: FloatAt/BurstAt/RateFly/CameraPunch -- ceremonia scurta pentru ORICE cumparare, nu doar
-- clopotele [note 38 pct.1-2]. Toate primesc coordonate HUD deja convertite, ca restul fisierului.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local TycoonMath = require(ReplicatedStorage.Shared.Modules.TycoonMath)
local Strings = require(ReplicatedStorage.Shared.Config.Strings)
local CameraController = require(script.Parent.CameraController)
local HUDController = require(script.Parent.HUDController)
local SoundController = require(script.Parent.SoundController)
local Theme = require(script.Parent.Parent.UI.Theme)
local Widgets = require(script.Parent.Parent.UI.Widgets)

export type Deps = { HudGui: Frame }

local JuiceController = {}
local hudGui: Frame? = nil

function JuiceController.Init(deps: Deps)
    hudGui = deps.HudGui
end

-- "+N" de la (fromX, fromY) [coordonate HUD] pana la contorul de monede; la sosire, contorul
-- "sare" (HUDController.PulseCoins) si se aude un pop [F1 spec 5.3, W4, O2].
function JuiceController.CoinFly(fromX: number, fromY: number, amount: number)
    if hudGui == nil or amount <= 0 then
        return
    end
    local gui = hudGui :: Frame
    local toX, toY = HUDController.CoinAnchor()

    local row = Instance.new("Frame")
    row.Name = "CoinFly"
    row.AnchorPoint = Vector2.new(0.5, 0.5)
    row.Position = UDim2.fromOffset(fromX, fromY)
    row.Size = UDim2.fromOffset(0, 30)
    row.AutomaticSize = Enum.AutomaticSize.X
    row.BackgroundColor3 = Theme.COLOR.plate
    row.BackgroundTransparency = Theme.PLATE_TRANSPARENCY
    row.ZIndex = 18
    row.Parent = gui
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 8)
    corner.Parent = row
    local padding = Instance.new("UIPadding")
    padding.PaddingLeft = UDim.new(0, 6)
    padding.PaddingRight = UDim.new(0, 8)
    padding.Parent = row
    local layout = Instance.new("UIListLayout")
    layout.FillDirection = Enum.FillDirection.Horizontal
    layout.VerticalAlignment = Enum.VerticalAlignment.Center
    layout.Padding = UDim.new(0, 5)
    layout.Parent = row

    local coin = Widgets.CoinIcon(row, 18, 19)
    coin.LayoutOrder = 1
    local label = Widgets.Label(
        row,
        `+{TycoonMath.formatNumber(amount)}`,
        Theme.TEXT.body,
        Theme.COLOR.gold,
        "display"
    )
    label.LayoutOrder = 2
    label.AutomaticSize = Enum.AutomaticSize.X
    label.Size = UDim2.fromOffset(0, Theme.TEXT.body + 4)
    label.ZIndex = 19
    Theme.punch(label, 2)

    local duration = 0.6
    TweenService:Create(
        row,
        TweenInfo.new(duration, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
        { Position = UDim2.fromOffset(toX, toY) }
    ):Play()
    task.delay(duration, function()
        row:Destroy()
        HUDController.PulseCoins()
        SoundController.Play("pop")
    end)
end

-- Cadru fara desen, doar ancora: pentru functiile de mai jos, care primesc o pozitie HUD (offset)
-- in loc de un parinte gata pozitionat -- se distruge singur dupa `life` secunde.
local function anchorAt(hudX: number, hudY: number, z: number, life: number): Frame
    local anchor = Instance.new("Frame")
    anchor.Name = "Anchor"
    anchor.AnchorPoint = Vector2.new(0.5, 0.5)
    anchor.BackgroundTransparency = 1
    anchor.Position = UDim2.fromOffset(hudX, hudY)
    anchor.Size = UDim2.fromOffset(0, 0)
    anchor.ZIndex = z
    task.delay(life, function()
        anchor:Destroy()
    end)
    return anchor
end

-- Text mic, ease-out, langa un punct din lume deja convertit in coordonate HUD [39, tip A] -- ex.
-- "Need 6 more coins" langa o platforma, "+3 to sack" langa o plasa. Widgets.FloatText face
-- animatia; aici doar ii dam o ancora la pozitia ceruta, fiindca el asteapta un parinte, nu (x, y).
function JuiceController.FloatAt(hudX: number, hudY: number, text: string, color: Color3)
    if hudGui == nil then
        return
    end
    local anchor = anchorAt(hudX, hudY, 19, 1.1)
    anchor.Parent = hudGui :: Frame
    Widgets.FloatText(anchor, text, color, 20)
end

-- Rafala de monede la o pozitie HUD fixa (nu intr-un panou) -- ceremonia scurta la ORICE pad
-- cumparat, nu doar la clopote [F2, note 38 pct.1]. Reutilizeaza Burst de mai jos.
function JuiceController.BurstAt(hudX: number, hudY: number, count: number)
    if hudGui == nil then
        return
    end
    local anchor = anchorAt(hudX, hudY, 17, 0.9)
    anchor.Parent = hudGui :: Frame
    JuiceController.Burst(anchor, 0.5, 0.5, 18, count)
end

-- "+{delta}/s" de la (fromX, fromY) [coordonate HUD] pana la rata din HUD -- oglinda lui CoinFly
-- de mai jos, dar tinta e HUDController.RateAnchor(), nu CoinAnchor() [F2, note 38 pct.2].
-- Apelat DEFENSIV: la momentul scrierii, agentul U inca nu expusese RateAnchor/PulseRate (doar
-- CoinAnchor/PulseCoins) -- fara ele, cadem pe coltul monedelor, cu un offset in jos (asa sta rata
-- azi fata de monede in HUDController), ca sageata sa tot aiba o tinta rezonabila pe ecran.
function JuiceController.RateFly(fromX: number, fromY: number, delta: number)
    if hudGui == nil or delta <= 0 then
        return
    end
    local gui = hudGui :: Frame
    local hud: any = HUDController
    local toX: number, toY: number
    if hud.RateAnchor ~= nil then
        toX, toY = hud.RateAnchor()
    else
        local cx, cy = HUDController.CoinAnchor()
        toX, toY = cx, cy + 34
    end

    local label = Widgets.Label(
        gui,
        Strings.hudRateUp(TycoonMath.formatRate(delta)),
        Theme.TEXT.body,
        Theme.COLOR.gold,
        "display"
    )
    label.AnchorPoint = Vector2.new(0.5, 0.5)
    label.Position = UDim2.fromOffset(fromX, fromY)
    label.AutomaticSize = Enum.AutomaticSize.X
    label.Size = UDim2.fromOffset(0, Theme.TEXT.body + 6)
    label.TextXAlignment = Enum.TextXAlignment.Center
    label.BackgroundColor3 = Theme.COLOR.plate
    label.BackgroundTransparency = Theme.PLATE_TRANSPARENCY
    label.ZIndex = 19
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 8)
    corner.Parent = label
    Theme.punch(label, 2)

    local duration = 0.6
    TweenService:Create(
        label,
        TweenInfo.new(duration, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
        { Position = UDim2.fromOffset(toX, toY) }
    ):Play()
    task.delay(duration, function()
        label:Destroy()
        if hud.PulseRate ~= nil then
            hud.PulseRate()
        else
            HUDController.PulseCoins() -- rezerva: tot mai bine decat sa cada tacut fara nicio reactie
        end
        SoundController.Play("pop")
    end)
end

-- "Punch" de camera la cumparaturi peste ~500 de monede [F2, note 38 pct.5]. Se smuceste LUMEA,
-- nu HUD-ul: prima varianta misca panza HUD si sareau monedele si butoanele, in timp ce malul
-- statea pe loc. Decalajul il tine CameraController, in aceeasi bucla in care urmareste
-- personajul, si se stinge singur in ~0,22 s -- un tween pe Scroll ar fi suprascris la cadrul
-- urmator de Follow.
function JuiceController.CameraPunch()
    CameraController.Punch(6 + math.random() * 4)
end

-- Mica explozie de monede, parentata oriunde (banner de ceremonie etc.), in coordonate SCALE ale
-- parintelui -- nu-i pasa unde e, doar arunca `count` puncte aurii care se imprastie si se sting.
function JuiceController.Burst(
    parent: Instance,
    xScale: number,
    yScale: number,
    z: number,
    count: number
)
    for _ = 1, count do
        local dot = Widgets.CoinIcon(parent, 8 + math.random(0, 6), z)
        dot.AnchorPoint = Vector2.new(0.5, 0.5)
        dot.Position = UDim2.fromScale(xScale, yScale)
        local stroke = dot:FindFirstChildOfClass("UIStroke")
        local angle = math.random() * math.pi * 2
        local dist = 36 + math.random() * 46
        local dx, dy = math.cos(angle) * dist, math.sin(angle) * dist - 18 -- usor in sus
        local duration = 0.5 + math.random() * 0.25
        TweenService
            :Create(dot, TweenInfo.new(duration, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
                Position = UDim2.new(xScale, dx, yScale, dy),
                BackgroundTransparency = 1,
                ImageTransparency = 1,
            })
            :Play()
        if stroke ~= nil then
            TweenService
                :Create(
                    stroke,
                    TweenInfo.new(duration, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
                    { Transparency = 1 }
                )
                :Play()
        end
        task.delay(duration + 0.1, function()
            dot:Destroy()
        end)
    end
end

return JuiceController
