--!strict
-- O gramada de marfa desenata langa o cladire [D49]: cateva pictograme dupa ce contine (in ordinea
-- GOODS, ca desenul sa stea pe loc) si o pastila cu cifra. Pana in D49 acelasi bloc era copiat in
-- gater si in debarcader; acum il folosesc depozitul, cele doua gramezi ale gaterului si debarcaderul.
--
-- CIFRA NU E DECOR. Sase pictograme arata la fel pentru 7 bucati si pentru 700; cifra spune
-- diferenta, iar cand gramada creste peste `warnAt` se face portocalie: veriga de dupa ea e cea slaba,
-- si asta se vede inainte sa fie citit vreun meniu [D43].
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Assets = require(ReplicatedStorage.Shared.Config.Assets)
local TycoonConfig = require(ReplicatedStorage.Shared.Config.TycoonConfig)
local TycoonMath = require(ReplicatedStorage.Shared.Modules.TycoonMath)
local Theme = require(script.Parent.Theme)
local Widgets = require(script.Parent.Widgets)

local PileView = {}

export type Options = {
    warnAt: number?, -- de la atatea bucati cifra se face portocalie (implicit 25)
    pill: string?, -- unde sta cifra: "above" (implicit) | "right"
    zIndex: number?,
}

export type View = {
    Set: (count: number, contents: { [string]: number }) -> (),
    Count: () -> number,
}

local ITEM_CAP = 6
local ITEM_MAX = 16 -- px, latura mare a unei pictograme
local SLOTS = {
    { -16, -8 },
    { 2, -14 },
    { 18, -8 },
    { -12, 8 },
    { 6, 14 },
    { 20, 6 },
}

-- Obiectele cu nume folosesc lada; un bun fara arta urcata cade pe bustean, nu dispare.
local function goodSprite(good: string): Assets.Sprite
    if good == "named" then
        return Assets.crate.common
    end
    local sprite = (Assets.goods :: any)[good]
    if sprite == nil or not Assets.has(sprite) then
        return Assets.goods.driftwood
    end
    return sprite
end

local function flatten(contents: { [string]: number }): { string }
    local shown: { string } = {}
    for _, g in TycoonConfig.GOODS do
        for _ = 1, contents[g.id] or 0 do
            if #shown >= ITEM_CAP then
                return shown
            end
            table.insert(shown, g.id)
        end
    end
    return shown
end

function PileView.new(parent: Instance, cx: number, cy: number, options: Options?): View
    local opts: Options = options or {}
    local warnAt = opts.warnAt or 25
    local z = opts.zIndex or 3
    local icons: { ImageLabel } = {}
    for i = 1, ITEM_CAP do
        local icon = Instance.new("ImageLabel")
        icon.Name = "Pile" .. i
        icon.BackgroundTransparency = 1
        icon.ResampleMode = Enum.ResamplerMode.Pixelated
        icon.AnchorPoint = Vector2.new(0.5, 0.5)
        icon.Position = UDim2.fromOffset(cx + SLOTS[i][1], cy + SLOTS[i][2])
        icon.Visible = false
        icon.ZIndex = z
        icon.Parent = parent
        icons[i] = icon
    end

    local pill = Instance.new("Frame")
    pill.Name = "PileCount"
    pill.BackgroundTransparency = 1
    pill.Size = UDim2.fromOffset(52, 24)
    if opts.pill == "right" then
        pill.AnchorPoint = Vector2.new(0, 0.5)
        pill.Position = UDim2.fromOffset(cx + 32, cy)
    else
        pill.AnchorPoint = Vector2.new(0.5, 1)
        pill.Position = UDim2.fromOffset(cx, cy - 26)
    end
    pill.Visible = false
    pill.ZIndex = z + 1
    Widgets.PillBackground(pill, z + 1)
    pill.Parent = parent
    local label = Widgets.Label(pill, "0", Theme.TEXT.small, Theme.COLOR.onDark, "display")
    label.AnchorPoint = Vector2.new(0.5, 0.5)
    label.Position = UDim2.fromScale(0.5, 0.5)
    label.Size = UDim2.fromOffset(48, 20)
    label.TextXAlignment = Enum.TextXAlignment.Center
    label.ZIndex = z + 2

    local current = 0
    local view: View = {
        Set = function(count: number, contents: { [string]: number })
            current = count
            label.Text = TycoonMath.formatNumber(count)
            label.TextColor3 = if count >= warnAt then Theme.COLOR.warn else Theme.COLOR.onDark
            pill.Visible = count > 0
            local shown = flatten(contents)
            for i, icon in icons do
                local goodId = shown[i]
                local sprite = if goodId ~= nil then goodSprite(goodId) else nil
                if sprite == nil or not Assets.has(sprite) then
                    icon.Visible = false
                    continue
                end
                icon.Image = Assets.url(sprite)
                local scale = ITEM_MAX / math.max(sprite.width, sprite.height)
                icon.Size = UDim2.fromOffset(
                    math.round(sprite.width * scale),
                    math.round(sprite.height * scale)
                )
                icon.Visible = true
            end
        end,
        Count = function(): number
            return current
        end,
    }
    return view
end

return PileView
