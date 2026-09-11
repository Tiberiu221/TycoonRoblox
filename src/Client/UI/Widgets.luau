--!strict
-- Piesele din care se construiesc toate panourile. Un singur loc unde se decide cum arata un
-- panou, un buton sau un rand de lista.
--
-- Ramele sunt IMAGINI cu 9 felii, nu `Frame` + `UICorner`. Un dreptunghi cu colturi rotunjite nu
-- poate purta textura, si asta e diferenta cea mai vizibila intre interfata unui joc facut cu
-- grija si una generica. Coltul imaginii ramane nedeformat, mijlocul se intinde.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Assets = require(ReplicatedStorage.Shared.Config.Assets)
local Theme = require(script.Parent.Theme)

local Widgets = {}

local HOVER = TweenInfo.new(0.12, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)

local function sliced(parent: Instance, sprite: Assets.Sprite, slice: number): ImageLabel
    local img = Instance.new("ImageLabel")
    img.BackgroundTransparency = 1
    img.Image = Assets.url(sprite)
    img.ScaleType = Enum.ScaleType.Slice
    img.SliceCenter = Rect.new(slice, slice, sprite.width - slice, sprite.height - slice)
    img.SliceScale = 2 -- rama desenata la 8 px se randeaza la 16: ramane crocanta, nu subtire
    img.ResampleMode = Enum.ResamplerMode.Pixelated
    img.Size = UDim2.fromScale(1, 1)
    img.Parent = parent
    return img
end

-- Panou: rama de lemn cu pergament, umbra dedesubt, si un cadru de continut cu spatiere.
-- Intoarce (radacina, continut): pozitia se pune pe radacina, copiii se pun in continut.
function Widgets.Panel(parent: Instance, name: string, z: number): (Frame, Frame)
    local root = Instance.new("Frame")
    root.Name = name
    root.BackgroundTransparency = 1
    root.ZIndex = z
    root.Parent = parent
    Theme.shadow(root, 18, 0.45)

    if Assets.has(Assets.ui.panel) then
        local skin = sliced(root, Assets.ui.panel, Assets.UI_SLICE.panel)
        skin.Name = "Skin"
        skin.ZIndex = z
    else
        root.BackgroundTransparency = 0
        root.BackgroundColor3 = Theme.COLOR.parchment
        local c = Instance.new("UICorner")
        c.CornerRadius = UDim.new(0, 10)
        c.Parent = root
    end

    local content = Instance.new("Frame")
    content.Name = "Content"
    content.BackgroundTransparency = 1
    content.Position = UDim2.fromOffset(Theme.SPACE.lg, Theme.SPACE.lg)
    content.Size = UDim2.new(1, -Theme.SPACE.lg * 2, 1, -Theme.SPACE.lg * 2)
    content.ZIndex = z + 1
    content.Parent = root
    return root, content
end

function Widgets.Label(
    parent: Instance,
    text: string,
    size: number,
    color: Color3,
    kind: string
): TextLabel
    local l = Instance.new("TextLabel")
    l.BackgroundTransparency = 1
    l.TextXAlignment = Enum.TextXAlignment.Left
    l.TextColor3 = color
    l.TextSize = size
    l.Text = text
    l.Size = UDim2.fromOffset(200, size + 6)
    l.ZIndex = (parent :: any).ZIndex + 1
    Theme.applyFont(l, kind)
    l.Parent = parent
    return l
end

-- Text peste lume (nu peste un panou): are nevoie de placa in spate ca sa ramana lizibil
-- indiferent ce e dedesubt.
function Widgets.PlateLabel(parent: Instance, text: string, size: number, kind: string): TextLabel
    local l = Widgets.Label(parent, text, size, Theme.COLOR.onDark, kind)
    l.BackgroundColor3 = Theme.COLOR.plate
    l.BackgroundTransparency = Theme.PLATE_TRANSPARENCY
    local pad = Instance.new("UIPadding")
    pad.PaddingLeft = UDim.new(0, Theme.SPACE.sm)
    pad.PaddingRight = UDim.new(0, Theme.SPACE.sm)
    pad.Parent = l
    local c = Instance.new("UICorner")
    c.CornerRadius = UDim.new(0, 6)
    c.Parent = l
    return l
end

function Widgets.Icon(parent: Instance, key: string, px: number): ImageLabel?
    local sprite = (Assets.icons :: any)[key]
    if sprite == nil or not Assets.has(sprite) then
        return nil
    end
    local img = Instance.new("ImageLabel")
    img.Name = `Icon_{key}`
    img.BackgroundTransparency = 1
    img.Image = Assets.url(sprite)
    img.ResampleMode = Enum.ResamplerMode.Pixelated
    img.Size = UDim2.fromOffset(px, px)
    img.ZIndex = (parent :: any).ZIndex + 1
    img.Parent = parent
    return img
end

export type ButtonOptions = {
    text: string,
    icon: string?,
    width: number,
    height: number,
    z: number,
    onClick: () -> (),
}

-- Buton cu trei stari desenate. Un buton fara raspuns la hover si la apasare e semnul cel mai
-- sigur de interfata neterminata.
function Widgets.Button(parent: Instance, o: ButtonOptions): TextButton
    local b = Instance.new("TextButton")
    b.BackgroundTransparency = 1
    b.AutoButtonColor = false
    b.Text = ""
    b.Size = UDim2.fromOffset(o.width, o.height)
    b.ZIndex = o.z
    b.Parent = parent

    local skin: ImageLabel? = nil
    if Assets.has(Assets.ui.button) then
        -- variabila locala, nu `skin` direct: formatarea sterge punctul si virgula de dupa
        -- atribuire, iar linia urmatoare ar incepe cu paranteza si s-ar lipi de cea de dinainte
        local made = sliced(b, Assets.ui.button, Assets.UI_SLICE.button)
        made.Name = "Skin"
        made.ZIndex = o.z
        skin = made
    else
        b.BackgroundTransparency = 0
        b.BackgroundColor3 = Theme.COLOR.parchmentDim
        local c = Instance.new("UICorner")
        c.CornerRadius = UDim.new(0, 8)
        c.Parent = b
    end

    local row = Instance.new("Frame")
    row.BackgroundTransparency = 1
    row.Size = UDim2.fromScale(1, 1)
    row.ZIndex = o.z + 1
    row.Parent = b
    local layout = Instance.new("UIListLayout")
    layout.FillDirection = Enum.FillDirection.Horizontal
    layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
    layout.VerticalAlignment = Enum.VerticalAlignment.Center
    layout.Padding = UDim.new(0, Theme.SPACE.sm)
    layout.Parent = row

    if o.icon ~= nil then
        local ico = Widgets.Icon(row, o.icon, math.min(28, o.height - 10))
        if ico ~= nil then
            ico.LayoutOrder = 1
        end
    end
    if o.text ~= "" then
        local l = Widgets.Label(row, o.text, Theme.TEXT.body, Theme.COLOR.ink, "strong")
        l.TextXAlignment = Enum.TextXAlignment.Center
        l.AutomaticSize = Enum.AutomaticSize.X
        l.Size = UDim2.fromOffset(0, o.height - 8)
        l.LayoutOrder = 2
        l.ZIndex = o.z + 2
    end

    local function setState(state: string)
        if skin == nil then
            return
        end
        local current = skin :: ImageLabel
        local sprite = (Assets.ui :: any)[`button_{state}`] or Assets.ui.button
        if Assets.has(sprite) then
            current.Image = Assets.url(sprite)
        end
    end
    b.MouseEnter:Connect(function()
        setState("hover")
        TweenService:Create(row, HOVER, { Position = UDim2.fromOffset(0, -1) }):Play()
    end)
    b.MouseLeave:Connect(function()
        setState("normal")
        TweenService:Create(row, HOVER, { Position = UDim2.fromOffset(0, 0) }):Play()
    end)
    b.MouseButton1Down:Connect(function()
        setState("down")
        row.Position = UDim2.fromOffset(0, 1)
    end)
    b.MouseButton1Up:Connect(function()
        setState("hover")
        row.Position = UDim2.fromOffset(0, 0)
    end)
    b.Activated:Connect(o.onClick)
    return b
end

-- Fereastra completa: rama, banderola cu titlu, buton de inchidere, si un corp gol pentru
-- continut. Toate panourile mari trec prin ea, ca sa nu ajungem iar cu patru stiluri diferite.
export type WindowOptions = {
    name: string,
    title: string,
    icon: string?,
    width: number,
    height: number,
    z: number,
    onClose: () -> (),
}

-- Panourile sunt dimensionate pentru desktop. Panza HUD e insa viewport/hudScale, deci pe un
-- telefon de 896x414 are doar ~1445x668 unitati logice, iar o fereastra de 700 inaltime iesea
-- pe sub marginea de jos: randurile de jos deveneau inaccesibile, fara niciun semn ca exista.
-- Aici e singurul loc prin care trec toate panourile, deci se repara o data pentru toate.
local function fitToCanvas(root: Frame, canvas: Frame, wantW: number, wantH: number)
    local availW, availH = canvas.Size.X.Offset, canvas.Size.Y.Offset
    if availW <= 0 or availH <= 0 then
        root.Size = UDim2.fromOffset(wantW, wantH) -- parinte fara marime fixa: lasam cum era
        return
    end
    local margin = Theme.SPACE.lg * 2
    root.Size = UDim2.fromOffset(
        math.min(wantW, math.max(240, availW - margin)),
        math.min(wantH, math.max(200, availH - margin))
    )
end

function Widgets.Window(parent: Instance, o: WindowOptions): (Frame, Frame)
    local root, content = Widgets.Panel(parent, o.name, o.z)
    root.Size = UDim2.fromOffset(o.width, o.height)
    if parent:IsA("Frame") then
        local canvas = parent :: Frame
        fitToCanvas(root, canvas, o.width, o.height)
        -- panza isi schimba marimea la rotirea telefonului si la redimensionarea ferestrei
        canvas:GetPropertyChangedSignal("Size"):Connect(function()
            fitToCanvas(root, canvas, o.width, o.height)
        end)
    end

    local header = Instance.new("Frame")
    header.Name = "Header"
    header.BackgroundTransparency = 1
    header.Size = UDim2.new(1, 0, 0, 44)
    header.ZIndex = o.z + 2
    header.Parent = content

    local titleX = 0
    if o.icon ~= nil then
        local ico = Widgets.Icon(header, o.icon, 34)
        if ico ~= nil then
            ico.Position = UDim2.fromOffset(0, 2)
            ico.ZIndex = o.z + 3
            titleX = 44
        end
    end
    local title = Widgets.Label(header, o.title, Theme.TEXT.title, Theme.COLOR.ink, "display")
    title.Position = UDim2.fromOffset(titleX, 0)
    title.Size = UDim2.new(1, -titleX - 48, 0, 38)
    title.ZIndex = o.z + 3

    -- linie de separare sub titlu: grupeaza fara sa adauge inca o rama
    local rule = Instance.new("Frame")
    rule.Name = "Rule"
    rule.Position = UDim2.fromOffset(0, 40)
    rule.Size = UDim2.new(1, 0, 0, 2)
    rule.BackgroundColor3 = Theme.COLOR.wood
    rule.BackgroundTransparency = 0.55
    rule.BorderSizePixel = 0
    rule.ZIndex = o.z + 3
    rule.Parent = header

    Widgets.CloseButton(root, o.z + 4, o.onClose)

    local body = Instance.new("Frame")
    body.Name = "Body"
    body.BackgroundTransparency = 1
    body.Position = UDim2.fromOffset(0, 56)
    body.Size = UDim2.new(1, 0, 1, -56)
    body.ZIndex = o.z + 2
    body.Parent = content
    return root, body
end

-- Lista care se poate derula, pe fundal scobit. Bara de derulare ramane vizibila: fara ea,
-- jucatorul nu are cum sa stie ca mai exista continut sub margine.
function Widgets.List(parent: Instance, z: number, padding: number?): ScrollingFrame
    local holder = Widgets.Slot(parent, z)
    local list = Instance.new("ScrollingFrame")
    list.Name = "List"
    list.BackgroundTransparency = 1
    list.BorderSizePixel = 0
    list.Position = UDim2.fromOffset(8, 8)
    list.Size = UDim2.new(1, -16, 1, -16)
    list.ScrollBarThickness = 8
    list.ScrollBarImageColor3 = Theme.COLOR.wood
    list.ScrollBarImageTransparency = 0.25
    list.CanvasSize = UDim2.fromOffset(0, 0)
    list.AutomaticCanvasSize = Enum.AutomaticSize.Y
    list.ZIndex = z + 1
    list.Parent = holder
    local layout = Instance.new("UIListLayout")
    layout.Padding = UDim.new(0, padding or Theme.SPACE.sm)
    layout.SortOrder = Enum.SortOrder.LayoutOrder
    layout.Parent = list
    return list
end

-- Rand de lista: fundal discret care se lumineaza la trecerea mausului, ca sa se vada ca e viu
function Widgets.Row(parent: Instance, height: number, z: number): TextButton
    local row = Instance.new("TextButton")
    row.BackgroundColor3 = Theme.COLOR.parchmentDim
    row.BackgroundTransparency = 0.35
    row.AutoButtonColor = false
    row.Text = ""
    row.Size = UDim2.new(1, -10, 0, height)
    row.ZIndex = z
    local c = Instance.new("UICorner")
    c.CornerRadius = UDim.new(0, 8)
    c.Parent = row
    row.MouseEnter:Connect(function()
        row.BackgroundTransparency = 0.1
    end)
    row.MouseLeave:Connect(function()
        row.BackgroundTransparency = 0.35
    end)
    row.Parent = parent
    return row
end

-- Butonul de inchidere din coltul unui panou. Fiecare panou trebuie sa aiba unul VIZIBIL:
-- Escape apartine meniului platformei si nu ajunge niciodata la joc, iar pe telefon nici nu
-- exista tastatura.
function Widgets.CloseButton(parent: GuiObject, z: number, onClick: () -> ()): TextButton
    local b = Instance.new("TextButton")
    b.Name = "Close"
    b.AnchorPoint = Vector2.new(1, 0)
    b.Position = UDim2.new(1, -10, 0, 10)
    b.Size = UDim2.fromOffset(38, 38)
    b.BackgroundColor3 = Color3.fromRGB(150, 62, 52)
    b.AutoButtonColor = false
    b.Text = "✕"
    b.TextColor3 = Color3.fromRGB(250, 238, 232)
    b.TextSize = 22
    b.ZIndex = z
    Theme.applyFont(b, "strong")
    local c = Instance.new("UICorner")
    c.CornerRadius = UDim.new(0, 8)
    c.Parent = b
    b.MouseEnter:Connect(function()
        b.BackgroundColor3 = Color3.fromRGB(184, 78, 66)
    end)
    b.MouseLeave:Connect(function()
        b.BackgroundColor3 = Color3.fromRGB(150, 62, 52)
    end)
    b.Activated:Connect(onClick)
    b.Parent = parent
    return b
end

-- Casuta scobita: randuri de lista, campuri, sloturi
function Widgets.Slot(parent: Instance, z: number): Frame
    local f = Instance.new("Frame")
    f.BackgroundTransparency = 1
    f.ZIndex = z
    f.Parent = parent
    if Assets.has(Assets.ui.slot) then
        local skin = sliced(f, Assets.ui.slot, Assets.UI_SLICE.slot)
        skin.ZIndex = z
    else
        f.BackgroundTransparency = 0.2
        f.BackgroundColor3 = Theme.COLOR.parchmentDim
        local c = Instance.new("UICorner")
        c.CornerRadius = UDim.new(0, 6)
        c.Parent = f
    end
    return f
end

-- Bara de progres sau de nevoie
function Widgets.Bar(
    parent: Instance,
    width: number,
    height: number,
    color: Color3,
    z: number
): (Frame, Frame)
    local track = Instance.new("Frame")
    track.BackgroundColor3 = Color3.fromRGB(74, 58, 44)
    track.BorderSizePixel = 0
    track.Size = UDim2.fromOffset(width, height)
    track.ZIndex = z
    local tc = Instance.new("UICorner")
    tc.CornerRadius = UDim.new(0, math.floor(height / 2))
    tc.Parent = track
    track.Parent = parent

    local fill = Instance.new("Frame")
    fill.BackgroundColor3 = color
    fill.BorderSizePixel = 0
    fill.Size = UDim2.fromScale(1, 1)
    fill.ZIndex = z + 1
    local fc = Instance.new("UICorner")
    fc.CornerRadius = UDim.new(0, math.floor(height / 2))
    fc.Parent = fill
    fill.Parent = track
    return track, fill
end

-- Cip de resursa pentru HUD: pictograma plus numar, pe placa
-- `name` scrie sub cifra ce reprezinta. Fara el, primul lucru pe care il vede un jucator nou
-- sunt cinci pictograme fara text si cinci numere fara unitate -- iar "gramada" nu se ghiceste
-- dintr-o iconita. Numele e mic intentionat: dupa a treia sesiune nu-l mai citeste nimeni, dar
-- pana atunci e singurul lucru care leaga cifra de lume.
function Widgets.Chip(
    parent: Instance,
    iconKey: string,
    z: number,
    name: string?
): (Frame, TextLabel)
    local chip = Instance.new("Frame")
    chip.BackgroundColor3 = Theme.COLOR.plate
    chip.BackgroundTransparency = Theme.PLATE_TRANSPARENCY
    chip.Size = UDim2.fromOffset(120, if name ~= nil then 52 else 40)
    chip.ZIndex = z
    local c = Instance.new("UICorner")
    c.CornerRadius = UDim.new(0, 8)
    c.Parent = chip
    chip.Parent = parent

    local layout = Instance.new("UIListLayout")
    layout.FillDirection = Enum.FillDirection.Horizontal
    layout.VerticalAlignment = Enum.VerticalAlignment.Center
    layout.Padding = UDim.new(0, Theme.SPACE.sm)
    layout.Parent = chip
    local pad = Instance.new("UIPadding")
    pad.PaddingLeft = UDim.new(0, Theme.SPACE.sm)
    pad.PaddingRight = UDim.new(0, Theme.SPACE.sm)
    pad.Parent = chip

    local ico = Widgets.Icon(chip, iconKey, 26)
    if ico ~= nil then
        ico.LayoutOrder = 1
    end
    local value = Widgets.Label(chip, "0", Theme.TEXT.body, Theme.COLOR.onDark, "strong")
    value.LayoutOrder = 2
    value.AutomaticSize = Enum.AutomaticSize.X
    value.Size = UDim2.fromOffset(0, 26)
    value.ZIndex = z + 1

    if name ~= nil then
        -- eticheta sta SUB rand, in afara asezarii orizontale, ca sa nu imparta latimea cu cifra
        local caption = Widgets.Label(chip, name, Theme.TEXT.tiny, Theme.COLOR.onDarkSoft, "body")
        caption.Name = "Caption"
        caption.AnchorPoint = Vector2.new(0.5, 1)
        caption.Position = UDim2.new(0.5, 0, 1, -2)
        caption.Size = UDim2.fromOffset(112, 14)
        caption.TextXAlignment = Enum.TextXAlignment.Center
        caption.ZIndex = z + 1
        -- randul cu pictograma si cifra urca, ca sa faca loc etichetei
        pad.PaddingBottom = UDim.new(0, 14)
    end
    return chip, value
end

return Widgets
