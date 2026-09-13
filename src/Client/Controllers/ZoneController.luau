--!strict
-- Zona urmatoarei ere: vizibila de la inceput, estompata si ingradita, se deschide cu clopotul
-- erei dinainte [F1 spec 4.6, aria B4]. Doar decor -- nu blocheaza mersul (Era 2 nu are inca
-- platforme, deci nu e nimic de facut acolo pana se deschide oricum).
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Assets = require(ReplicatedStorage.Shared.Config.Assets)
local RiverConfig = require(ReplicatedStorage.Shared.Config.RiverConfig)
local TycoonConfig = require(ReplicatedStorage.Shared.Config.TycoonConfig)
local Theme = require(script.Parent.Parent.UI.Theme)
local Widgets = require(script.Parent.Parent.UI.Widgets)

export type Deps = { Plot: Frame }

local ZoneController = {}
local deps: Deps
local fade: Frame
local fenceParts: { GuiObject } = {}
local signLabel: TextLabel
local lastStatus: string? = nil

local Z = 1 -- sub tot ce se cumpara/alearga, deasupra fundalului
local EASE = TweenInfo.new(1.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)

-- Gardul se intinde pe toata inaltimea terenului, pe linia dintre "The Landing" si "The Mill"
-- [TycoonConfig.ZONES]. Din RiverConfig.PLOT, nu cifre batute in cuie: pana in D50 se oprea la
-- y 1220, iar pe harta noua jumatate din teren ar fi ramas fara gard.
local FENCE_TOP = RiverConfig.PLOT.y
local FENCE_BOTTOM = RiverConfig.PLOT.y + RiverConfig.PLOT.h

-- "locked" -> "open" [F1 spec 4.6]: gardul si estomparea se sterg USOR, nu dispar brusc -- se
-- cheama o singura data pe tranzitie reala, nu la fiecare TycoonState.
function ZoneController.Apply(millStatus: string)
    if millStatus == lastStatus then
        return
    end
    lastStatus = millStatus
    local open = millStatus == "open"
    signLabel.Text = if open
        then "The Mill — coming soon"
        else "The Mill — opens with the Landing Bell"
    TweenService:Create(fade, EASE, { BackgroundTransparency = if open then 1 else 0.7 }):Play()
    for _, part in fenceParts do
        if part:IsA("ImageLabel") then
            TweenService:Create(part, EASE, { ImageTransparency = if open then 1 else 0 }):Play()
        elseif part:IsA("Frame") then
            TweenService:Create(part, EASE, { BackgroundTransparency = if open then 1 else 0.1 })
                :Play()
        end
    end
end

function ZoneController.Init(d: Deps)
    deps = d
    local mill = TycoonConfig.ZONES[2] -- { id = "mill", x0 = 1860, x1 = 2880, ... }

    fade = Instance.new("Frame")
    fade.Name = "MillFade"
    -- Doar USCATUL de dincolo de gard se estompeaza. Cand acoperea si raul, jumatate de ecran
    -- era o banda intunecata cu o muchie dreapta prin apa, care arata a defect de randare, nu a
    -- zona inca inchisa [vazut in Studio, 2026-09-12].
    fade.Position = UDim2.fromOffset(mill.x0, RiverConfig.RIVER_BOTTOM)
    fade.Size =
        UDim2.fromOffset(mill.x1 - mill.x0, RiverConfig.WORLD_HEIGHT - RiverConfig.RIVER_BOTTOM)
    fade.BackgroundColor3 = Color3.fromRGB(10, 14, 18)
    fade.BackgroundTransparency = 0.7
    fade.BorderSizePixel = 0
    fade.ZIndex = Z
    fade.Parent = deps.Plot

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
            img.Position = UDim2.fromOffset(mill.x0, FENCE_TOP + i * fw)
            img.ZIndex = Z + 1
            img.Parent = deps.Plot
            table.insert(fenceParts, img)
        end
    else
        -- fara sprite inca: o linie simpla de lemn tine locul gardului
        local line = Instance.new("Frame")
        line.Name = "FenceLine"
        line.Position = UDim2.fromOffset(mill.x0 - 2, FENCE_TOP)
        line.Size = UDim2.fromOffset(4, FENCE_BOTTOM - FENCE_TOP)
        line.BackgroundColor3 = Theme.COLOR.woodDark
        line.BackgroundTransparency = 0.1
        line.BorderSizePixel = 0
        line.ZIndex = Z + 1
        line.Parent = deps.Plot
        table.insert(fenceParts, line)
    end

    -- semnul: numele zonei si conditia de deblocare, langa garda
    signLabel = Widgets.PlateLabel(deps.Plot, "", Theme.TEXT.small, "strong")
    signLabel.Position = UDim2.fromOffset(mill.x0 + 14, FENCE_TOP + 40)
    signLabel.Size = UDim2.fromOffset(280, 30)
    signLabel.TextWrapped = true
    signLabel.ZIndex = Z + 2

    ZoneController.Apply("locked")
end

return ZoneController
