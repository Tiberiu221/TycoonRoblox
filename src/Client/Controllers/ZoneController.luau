--!strict
-- Zonele erelor urmatoare: vizibile de la inceput, estompate si ingradite; fiecare se deschide cu clopotul erei
-- dinainte [F1 spec 4.6, aria B4]. Doar decor -- nu blocheaza mersul.
-- [D65] Pana la D65 exista o singura zona inchisa (The Mill), iar deschisa scria "coming soon", fiindca Era 2 nu avea
-- nimic de cumparat. Acum sunt oricate (TycoonConfig.ZONES): una cu platforme `live` isi pierde panoul cand se
-- deschide, una care inca nu exista in joc (The Wire Works) ramane anuntata.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Assets = require(ReplicatedStorage.Shared.Config.Assets)
local RiverConfig = require(ReplicatedStorage.Shared.Config.RiverConfig)
local Strings = require(ReplicatedStorage.Shared.Config.Strings)
local TycoonConfig = require(ReplicatedStorage.Shared.Config.TycoonConfig)
local Theme = require(script.Parent.Parent.UI.Theme)
local Widgets = require(script.Parent.Parent.UI.Widgets)

export type Deps = { Plot: Frame }

local ZoneController = {}
local deps: Deps

type ZoneView = {
    fade: Frame,
    fence: { GuiObject },
    sign: TextLabel,
    status: string?,
}
local views: { [string]: ZoneView } = {}

-- [D65] PESTE tot ce sta pe teren, nu sub: de cand ruinele Morii se vad din prima zi (platformele ei sunt `live`), un
-- val pus sub ele le-ar fi lasat luminate pe un pamant intunecat. Asa, tot ce e dincolo de gard e in aceeasi umbra --
-- si omul tau, daca trece gardul. Pana la D65 era 1 (sub tot), fiindca dincolo de gard nu era nimic desenat.
local Z = 200
local SIGN_W = 280
local EASE = TweenInfo.new(1.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)

-- Gardul se intinde pe toata inaltimea terenului, pe linia dintre doua zone [TycoonConfig.ZONES]. Din
-- RiverConfig.PLOT, nu cifre batute in cuie: pana in D50 se oprea la y 1220, iar pe harta noua jumatate din teren ar
-- fi ramas fara gard.
local FENCE_TOP = RiverConfig.PLOT.y
local FENCE_BOTTOM = RiverConfig.PLOT.y + RiverConfig.PLOT.h

-- Clopotul care deschide zona unei ere: platforma cu motivul D a erei dinainte.
local function bellNameBefore(era: number): string
    for _, p in TycoonConfig.PADS do
        if p.era == era - 1 and p.motive == "D" then
            return p.name
        end
    end
    return "next Bell"
end

-- O zona are ce juca in ea doar daca era ei are platforme `live`.
local function isBuilt(era: number): boolean
    for _, p in TycoonConfig.PADS do
        if p.era == era and p.live then
            return true
        end
    end
    return false
end

-- "locked" -> "open" [F1 spec 4.6]: gardul si estomparea se sterg USOR, nu dispar brusc -- se schimba doar la o
-- tranzitie reala, nu la fiecare TycoonState. `zones` = starea fiecarei zone, dupa id ("open" | "locked").
function ZoneController.Apply(zones: { [string]: string })
    for _, zone in TycoonConfig.ZONES do
        local view = views[zone.id]
        local status = zones[zone.id] or "locked"
        if view == nil or view.status == status then
            continue
        end
        view.status = status
        local open = status == "open"
        local built = isBuilt(zone.era)
        -- deschisa si construita: nu mai e nimic de anuntat; deschisa dar inca nefacuta: "coming soon"
        view.sign.Text = if not open
            then Strings.zoneLocked(zone.name, bellNameBefore(zone.era))
            elseif built then ""
            else Strings.zoneSoon(zone.name)
        view.sign.Visible = view.sign.Text ~= ""
        -- panoul creste dupa text: "The Wire Works — opens with the Mill Bell" are 41 de litere, adica doua randuri
        -- la latimea asta (fontul de pixeli are 0.56 em pe litera) [CLAUDE.md, capcana textului care iese din cutie]
        local height = Theme.textHeight(view.sign.Text, Theme.TEXT.small, "strong", SIGN_W - 16)
        view.sign.Size = UDim2.fromOffset(SIGN_W, math.max(30, height + 12))
        -- o zona deschisa dar nefacuta ramane estompata: acolo chiar nu e nimic de facut inca
        local clear = open and built
        -- valul sta peste tot terenul zonei: odata sters, iese de tot din drum (nu ramane un strat gol peste butoane)
        view.fade.Visible = true
        local fadeTween = TweenService:Create(
            view.fade,
            EASE,
            { BackgroundTransparency = if clear then 1 else 0.7 }
        )
        fadeTween.Completed:Once(function()
            if view.status == "open" and clear then
                view.fade.Visible = false
            end
        end)
        fadeTween:Play()
        for _, part in view.fence do
            if part:IsA("ImageLabel") then
                TweenService:Create(part, EASE, { ImageTransparency = if clear then 1 else 0 })
                    :Play()
            elseif part:IsA("Frame") then
                TweenService
                    :Create(part, EASE, { BackgroundTransparency = if clear then 1 else 0.1 })
                    :Play()
            end
        end
    end
end

local function buildZone(
    zone: { id: string, name: string, era: number, x0: number, x1: number }
): ZoneView
    local fade = Instance.new("Frame")
    fade.Name = zone.id .. "Fade"
    -- Doar USCATUL de dincolo de gard se estompeaza. Cand acoperea si raul, jumatate de ecran
    -- era o banda intunecata cu o muchie dreapta prin apa, care arata a defect de randare, nu a
    -- zona inca inchisa [vazut in Studio, 2026-09-12].
    fade.Position = UDim2.fromOffset(zone.x0, RiverConfig.RIVER_BOTTOM)
    fade.Size =
        UDim2.fromOffset(zone.x1 - zone.x0, RiverConfig.WORLD_HEIGHT - RiverConfig.RIVER_BOTTOM)
    fade.BackgroundColor3 = Color3.fromRGB(10, 14, 18)
    fade.BackgroundTransparency = 0.7
    fade.BorderSizePixel = 0
    fade.ZIndex = Z
    fade.Parent = deps.Plot

    local fence: { GuiObject } = {}
    if Assets.has(Assets.props.fence) then
        -- gardul rotit 90 de grade: un sprite orizontal devine un stalp vertical, iar sirul lor
        -- de sus in jos deseneaza linia de granita
        local fw = Assets.props.fence.width * Assets.PIXEL_SCALE
        local fh = Assets.props.fence.height * Assets.PIXEL_SCALE
        local count = math.ceil((FENCE_BOTTOM - FENCE_TOP) / fw)
        for i = 0, count do
            local img = Instance.new("ImageLabel")
            img.Name = "Fence" .. i
            img.Image = Assets.url(Assets.props.fence)
            img.BackgroundTransparency = 1
            img.ResampleMode = Enum.ResamplerMode.Pixelated
            img.AnchorPoint = Vector2.new(0.5, 0.5)
            img.Rotation = 90
            img.Size = UDim2.fromOffset(fw, fh)
            img.Position = UDim2.fromOffset(zone.x0, FENCE_TOP + i * fw)
            img.ZIndex = Z + 1
            img.Parent = deps.Plot
            table.insert(fence, img)
        end
    else
        -- fara sprite inca: o linie simpla de lemn tine locul gardului
        local line = Instance.new("Frame")
        line.Name = "FenceLine"
        line.Position = UDim2.fromOffset(zone.x0 - 2, FENCE_TOP)
        line.Size = UDim2.fromOffset(4, FENCE_BOTTOM - FENCE_TOP)
        line.BackgroundColor3 = Theme.COLOR.woodDark
        line.BackgroundTransparency = 0.1
        line.BorderSizePixel = 0
        line.ZIndex = Z + 1
        line.Parent = deps.Plot
        table.insert(fence, line)
    end

    -- semnul: numele zonei si conditia de deblocare, langa gard
    local sign = Widgets.PlateLabel(deps.Plot, "", Theme.TEXT.small, "strong")
    sign.Position = UDim2.fromOffset(zone.x0 + 14, FENCE_TOP + 40)
    sign.Size = UDim2.fromOffset(SIGN_W, 30)
    sign.TextWrapped = true
    sign.ZIndex = Z + 2
    return { fade = fade, fence = fence, sign = sign, status = nil }
end

function ZoneController.Init(d: Deps)
    deps = d
    local locked: { [string]: string } = {}
    for _, zone in TycoonConfig.ZONES do
        if zone.era > 1 then
            views[zone.id] = buildZone(zone)
            locked[zone.id] = "locked"
        end
    end
    ZoneController.Apply(locked)
end

return ZoneController
