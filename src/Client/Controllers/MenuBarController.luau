--!strict
-- Bara de butoane din dreapta: constructii, oameni, colonie, atelier.
--
-- De ce exista: pana acum panourile se deschideau DOAR de la tastatura (B, Tab, C). Pe telefon,
-- unde e majoritatea jucatorilor de pe platforma, jumatate din joc era pur si simplu inaccesibil.
-- Butoanele apar pe rand, pe masura ce obiectivele le deblocheaza, deci ecranul de la inceput
-- ramane gol.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local Assets = require(ReplicatedStorage.Shared.Config.Assets)
local Theme = require(script.Parent.Parent.UI.Theme)
local Widgets = require(script.Parent.Parent.UI.Widgets)

local MenuBarController = {}

type Entry = { name: string, icon: string, label: string, key: string, open: () -> () }

local buttons: { [string]: Frame } = {}
local bar: Frame
local isUnlocked: (string) -> boolean = function(_name: string): boolean
    return true
end

local BUTTON = 62
-- [D59] punctul de pe o intrare (roata: rotirea gratuita e gata). Tinut minte si inainte de Init.
local badgeWanted: { [string]: boolean } = {}
local badgeDots: { [string]: Frame } = {}

-- Arata PE CE BUTON trebuie apasat acum. Cartonasul de obiectiv scria "Open Build" si nimic
-- nu spunea unde e Build: jucatorul trebuia sa ghiceasca din patru pictograme fara text.
-- Un inel auriu care pulseaza plus o sageata care arata spre buton rezolva exact intrebarea
-- "unde apas", fara sa adauge inca un rand de text pe care oricum nu-l citeste nimeni.
local highlighted: string? = nil
local halo: Frame? = nil
local haloTween: Tween? = nil

local function clearHalo()
    local h = halo
    if h ~= nil then
        h.Visible = false
    end
    local t = haloTween
    if t ~= nil then
        t:Cancel()
        haloTween = nil
    end
end

-- Unde e butonul unei intrari, in AbsolutePosition (sistemul zonei sigure, CoreUISafeInsets -- vezi Bootstrap).
-- 0,0,0,0 cat timp nu se vede: tutorialul asteapta, nu aprinde un loc gol.
function MenuBarController.EntryRect(name: string): (number, number, number, number)
    local holder = buttons[name]
    if holder == nil or not holder.Visible then
        return 0, 0, 0, 0
    end
    local p, s = holder.AbsolutePosition, holder.AbsoluteSize
    return p.X, p.Y, s.X, s.Y
end

local function applyBadge(name: string)
    local holder = buttons[name]
    if holder == nil then
        return
    end
    local dot = badgeDots[name]
    if dot == nil then
        local d = Instance.new("Frame")
        d.Name = "Badge"
        d.AnchorPoint = Vector2.new(0.5, 0.5)
        d.Position = UDim2.new(1, -8, 0, 8)
        d.Size = UDim2.fromOffset(18, 18)
        d.BackgroundTransparency = 1
        d.ZIndex = 24
        if Assets.has(Assets.ui.badge) then
            local img = Instance.new("ImageLabel")
            img.BackgroundTransparency = 1
            img.Image = Assets.url(Assets.ui.badge)
            img.ResampleMode = Enum.ResamplerMode.Pixelated
            img.Size = UDim2.fromScale(1, 1)
            img.ZIndex = 24
            img.Parent = d
        else
            d.BackgroundTransparency = 0
            d.BackgroundColor3 = Theme.COLOR.bad
            local c = Instance.new("UICorner")
            c.CornerRadius = UDim.new(1, 0)
            c.Parent = d
        end
        d.Parent = holder
        badgeDots[name] = d
        dot = d
    end
    dot.Visible = badgeWanted[name] == true
end

-- [D59] Un punct pe butonul unei intrari: e ceva de luat acolo (rotirea zilnica). Fara cifra.
function MenuBarController.SetBadge(name: string, on: boolean)
    if badgeWanted[name] == on then
        return
    end
    badgeWanted[name] = on
    applyBadge(name)
end

function MenuBarController.Highlight(name: string?)
    if highlighted == name then
        return -- acelasi buton: nu repornim tween-ul, s-ar stivui la fiecare reimprospatare
    end
    highlighted = name
    clearHalo()
    if name == nil then
        return
    end
    local holder = buttons[name]
    if holder == nil or not holder.Visible then
        return
    end
    local h = halo
    if h == nil then
        h = Instance.new("Frame")
        h.Name = "Halo"
        h.BackgroundTransparency = 1
        h.BorderSizePixel = 0
        h.ZIndex = 19 -- sub buton, ca sa nu inghita apasarea
        local corner = Instance.new("UICorner")
        corner.CornerRadius = UDim.new(0, 14)
        corner.Parent = h
        local edge = Instance.new("UIStroke")
        edge.Name = "Edge"
        edge.Color = Theme.COLOR.gold
        edge.Thickness = 3
        edge.Parent = h
        -- COPIL AL BUTONULUI, nu al barei: butoanele sunt asezate de un UIListLayout, deci
        -- Position ramane (0,0) si un inel pozitionat dupa ea ar sta in coltul barei.
        h.AnchorPoint = Vector2.new(0.5, 0.5)
        h.Position = UDim2.fromScale(0.5, 0.5)
        h.Size = UDim2.fromOffset(BUTTON + 16, BUTTON + 16)
        halo = h
    end
    local ring = h :: Frame
    ring.Parent = holder
    ring.Visible = true
    local edge = ring:FindFirstChild("Edge") :: UIStroke?
    if edge ~= nil then
        edge.Transparency = 0
        local pulse = TweenService:Create(
            edge,
            TweenInfo.new(0.85, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true),
            { Transparency = 0.55 }
        )
        haloTween = pulse
        pulse:Play()
    end
end

-- Ascunsa cat timp cineva vorbeste cu jucatorul
function MenuBarController.SetHidden(value: boolean)
    if bar ~= nil then
        bar.Visible = not value
    end
end

function MenuBarController.Refresh()
    for name, holder in buttons do
        local shouldShow = isUnlocked(name)
        if holder.Visible ~= shouldShow then
            holder.Visible = shouldShow
            if shouldShow then
                -- butonul nou intra cu un salt scurt: altfel apare din neant si nu se observa
                holder.Size = UDim2.fromOffset(BUTTON, BUTTON * 0.6)
                local grow = TweenService:Create(
                    holder,
                    TweenInfo.new(0.32, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
                    { Size = UDim2.fromOffset(BUTTON, BUTTON) }
                )
                grow:Play()
            end
        end
    end
end

function MenuBarController.Init(deps: {
    HudGui: Frame,
    IsUnlocked: (string) -> boolean,
    Entries: { Entry },
})
    isUnlocked = deps.IsUnlocked

    bar = Instance.new("Frame")
    bar.Name = "MenuBar"
    bar.AnchorPoint = Vector2.new(1, 0.5)
    bar.Position = UDim2.new(1, -Theme.SPACE.lg, 0.5, 0)
    -- Inaltimea urmeaza NUMARUL de intrari, nu o cifra scrisa de mana. Era fixata la 4; a cincea
    -- intrare (Collection) ar fi iesit din bara si ar fi ramas neapasabila.
    local slots = #deps.Entries
    bar.Size = UDim2.fromOffset(BUTTON, BUTTON * slots + Theme.SPACE.sm * math.max(0, slots - 1))
    bar.BackgroundTransparency = 1
    bar.ZIndex = 20
    -- [verificatorii A0, k12] sta peste indicatorul de margine al ghidajului (Z 17): acela aluneca pe margine cat s-o ocoleasca
    bar:SetAttribute("GuideBlocker", true)
    bar.Parent = deps.HudGui
    local layout = Instance.new("UIListLayout")
    layout.Padding = UDim.new(0, Theme.SPACE.sm)
    layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
    layout.VerticalAlignment = Enum.VerticalAlignment.Center
    layout.Parent = bar

    local showKeys = UserInputService.KeyboardEnabled

    for i, entry in deps.Entries do
        local holder = Instance.new("Frame")
        holder.Name = entry.name
        holder.BackgroundTransparency = 1
        holder.Size = UDim2.fromOffset(BUTTON, BUTTON)
        holder.LayoutOrder = i
        holder.Visible = false
        holder.ZIndex = 20
        holder.Parent = bar

        local button = Widgets.Button(holder, {
            text = "",
            icon = entry.icon,
            width = BUTTON,
            height = BUTTON,
            z = 20,
            onClick = entry.open,
        })
        button.Size = UDim2.fromScale(1, 1)

        -- eticheta apare la trecerea cu mausul; pe telefon nu are cine sa treaca, deci nu exista
        if showKeys then
            local tip = Widgets.PlateLabel(
                holder,
                `{entry.label}  ({entry.key})`,
                Theme.TEXT.small,
                "strong"
            )
            tip.AnchorPoint = Vector2.new(1, 0.5)
            tip.Position = UDim2.new(0, -Theme.SPACE.sm, 0.5, 0)
            tip.Size = UDim2.fromOffset(190, 30)
            tip.TextXAlignment = Enum.TextXAlignment.Right
            tip.Visible = false
            tip.ZIndex = 22
            button.MouseEnter:Connect(function()
                tip.Visible = true
            end)
            button.MouseLeave:Connect(function()
                tip.Visible = false
            end)
        end

        buttons[entry.name] = holder
    end

    -- pictogramele lipsa nu trebuie sa lase butoane goale
    for name, holder in buttons do
        local icon = holder:FindFirstChildWhichIsA("ImageLabel", true)
        if icon == nil and not Assets.has(Assets.ui.button) then
            holder.Visible = false
            buttons[name] = holder
        end
    end

    for name in badgeWanted do
        applyBadge(name)
    end
    MenuBarController.Refresh()
end

return MenuBarController
