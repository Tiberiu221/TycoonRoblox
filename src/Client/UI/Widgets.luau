--!strict
-- Piesele din care se construiesc toate panourile. Un singur loc unde se decide cum arata un
-- panou, un buton sau un rand de lista.
--
-- Ramele sunt IMAGINI cu 9 felii, nu `Frame` + `UICorner`. Un dreptunghi cu colturi rotunjite nu
-- poate purta textura, si asta e diferenta cea mai vizibila intre interfata unui joc facut cu
-- grija si una generica. Coltul imaginii ramane nedeformat, mijlocul se intinde.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")

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

-- Export public al ramei cu 9 felii, pentru compozitii noi care nu trec prin Panel/Button/Slot
-- de mai sus (placuta si cartonasul platformei, pastilele din HUD) [F2 finisaj].
function Widgets.NineSlice(
    parent: Instance,
    sprite: Assets.Sprite,
    slice: number,
    z: number
): ImageLabel
    local img = sliced(parent, sprite, slice)
    img.ZIndex = z
    return img
end

-- Insigna de NIVEL. Deliberat ALTA culoare decat pastilele obisnuite (monede, traista, IDLE,
-- valoarea de la debarcader sunt toate acelasi lemn inchis): daca nivelul arata la fel ca restul,
-- nu se mai vede din priviri care statie a ramas in urma -- si exact asta trebuie sa se vada fara
-- sa deschizi vreun panou.
-- [D62, pasul 5] Insigna pe rangul nivelului (ChainMath.rankOf): albastra sub pragul 10, apoi bronz, argint, aur. O
-- varianta inca neurcata cade pe cea albastra.
local RANK_BADGE = { "levelbadge_bronze", "levelbadge_silver", "levelbadge_gold" }
-- pe argint si pe aur, textul deschis nu se mai citeste
local RANK_TEXT = { Theme.COLOR.onDark, Theme.COLOR.ink, Theme.COLOR.ink }

local function badgeSprite(rank: number?): Assets.Sprite
    local key = if rank ~= nil then RANK_BADGE[rank] else nil
    local sprite = if key ~= nil then (Assets.ui :: any)[key] else nil
    return if sprite ~= nil and Assets.has(sprite) then sprite else Assets.ui.levelbadge
end

function Widgets.LevelBadge(parent: GuiObject, z: number, rank: number?)
    if Assets.has(Assets.ui.levelbadge) then
        parent.BackgroundTransparency = 1
        local skin = sliced(parent, badgeSprite(rank), Assets.UI_SLICE.levelbadge)
        skin.Name = "LevelSkin"
        skin.ZIndex = z
    else
        Widgets.PillBackground(parent, z)
    end
end

-- Insigna deja desenata trece pe alt rang (plasa a urcat peste un prag). Intoarce culoarea textului de pe ea.
function Widgets.SetLevelBadgeRank(parent: GuiObject, rank: number): Color3
    local skin = parent:FindFirstChild("LevelSkin")
    local sprite = badgeSprite(rank)
    if skin ~= nil and skin:IsA("ImageLabel") then
        skin.Image = Assets.url(sprite)
    end
    -- culoarea textului urmeaza insigna care chiar se vede: fara varianta urcata, insigna e tot albastra
    return if sprite ~= Assets.ui.levelbadge
        then (RANK_TEXT[rank] or Theme.COLOR.onDark)
        else Theme.COLOR.onDark
end

-- Fundalul comun al unei "pastile" (pastilele din HUD, eticheta plasei, valoarea la debarcader):
-- imaginea cu 9 felii cand arta a aparut, altfel dreptunghiul plat de azi. Un singur loc, ca toate
-- pastilele sa se actualizeze singure cand `Assets.tycoon.pill` capata un id real.
function Widgets.PillBackground(parent: GuiObject, z: number)
    if Assets.has(Assets.tycoon.pill) then
        parent.BackgroundTransparency = 1
        local skin = sliced(parent, Assets.tycoon.pill, Assets.UI_SLICE.pill)
        skin.Name = "Skin"
        skin.ZIndex = z
    else
        parent.BackgroundColor3 = Theme.COLOR.plate
        parent.BackgroundTransparency = Theme.PLATE_TRANSPARENCY
        if parent:FindFirstChildOfClass("UICorner") == nil then
            local c = Instance.new("UICorner")
            c.CornerRadius = UDim.new(0, 10)
            c.Parent = parent
        end
    end
end

-- O recuzita simpla (nu 9 felii): stalp, stalpul plasei cumparate etc. Marimea vine din sprite,
-- scalata ca orice alt obiect de lume (Assets.PIXEL_SCALE). Ancorata jos-centru implicit -- cele
-- mai multe stau "pe sol"; apelantul schimba pozitia daca are nevoie de alta ancora.
function Widgets.Prop(parent: Instance, sprite: Assets.Sprite, z: number): ImageLabel
    local img = Instance.new("ImageLabel")
    img.BackgroundTransparency = 1
    img.Image = Assets.url(sprite)
    img.ResampleMode = Enum.ResamplerMode.Pixelated
    img.AnchorPoint = Vector2.new(0.5, 1)
    img.Position = UDim2.fromScale(0.5, 1)
    img.Size =
        UDim2.fromOffset(sprite.width * Assets.PIXEL_SCALE, sprite.height * Assets.PIXEL_SCALE)
    img.ZIndex = z
    img.Parent = parent
    return img
end

-- Cauta intai in `icons` (familia de 16x16), apoi in `ui`. Jurnalul de quest-uri e un desen de
-- 28x28 si sta in `ui`, dar se cere ca orice alta pictograma -- fara cautarea asta, ar fi trebuit
-- ori sa-l duplic in manifest, ori sa dau bara de meniu pe alt drum doar pentru un buton.
function Widgets.Icon(parent: Instance, key: string, px: number): ImageLabel?
    local sprite = (Assets.icons :: any)[key] or (Assets.ui :: any)[key]
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
    -- [D52] loc pentru moneda si pret DUPA eticheta ("Upgrade (moneda) 75"), completat cu
    -- SetButtonPrice. Fara el, butonul ramane exact cum era.
    price: boolean?,
    -- [owner, 2026-09-14] loc pentru recompensa DUPA eticheta ("Claim 1 (perla)"), completat cu SetButtonReward
    reward: boolean?,
}

-- Cat din fiecare margine a butonului ramane rama desenata: textul nu intra peste ea.
local BUTTON_INSET = 12

-- Eticheta nu iese de pe desenul butonului. Cand randul (pictograma, eticheta, pretul, recompensa) e mai lat decat
-- butonul, eticheta se strange; altfel ramane la marimea ei. Fontul de pixeli are 0.56 em pe litera: "Go to Scrap
-- Collector" avea 211 pe un buton de 200 [2026-09-15]. Butoanele intinse pe scara parintelui nu se ating.
local function fitButtonRow(button: TextButton)
    local row = button:FindFirstChild("Row")
    local found = if row ~= nil then row:FindFirstChild("Label") else nil
    if row == nil or found == nil or not found:IsA("TextLabel") or button.Size.X.Scale ~= 0 then
        return
    end
    local label = found :: TextLabel
    local others, count = 0, if label.Visible then 1 else 0
    for _, child in row:GetChildren() do
        if child == label or not child:IsA("GuiObject") or not (child :: GuiObject).Visible then
            continue
        end
        count += 1
        if child:IsA("TextLabel") then
            local text = child :: TextLabel
            others += Theme.textWidth(text.Text, text.TextSize, "strong")
        else
            others += (child :: GuiObject).Size.X.Offset
        end
    end
    local room = button.Size.X.Offset
        - BUTTON_INSET * 2
        - others
        - math.max(0, count - 1) * Theme.SPACE.sm
    label.TextSize = Theme.fitSize(label.Text, Theme.TEXT.body, "strong", room)
end

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
    row.Name = "Row" -- cautat de SetButtonText
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
    -- Eticheta exista MEREU, chiar goala: altfel SetButtonText n-ar avea ce schimba la un buton
    -- nascut fara text, si ar ajunge iar sa scrie pe `button.Text`.
    local l = Widgets.Label(row, o.text, Theme.TEXT.body, Theme.COLOR.ink, "strong")
    l.Name = "Label"
    l.TextXAlignment = Enum.TextXAlignment.Center
    l.AutomaticSize = Enum.AutomaticSize.X
    l.Size = UDim2.fromOffset(0, o.height - 8)
    l.LayoutOrder = 2
    l.ZIndex = o.z + 2
    l.Visible = o.text ~= ""
    if o.price then
        local coin = Widgets.CoinIcon(row, math.min(22, o.height - 14), o.z + 2)
        coin.Name = "PriceCoin" -- cautat de SetButtonPrice
        coin.LayoutOrder = 3
        coin.Visible = false
        local price = Widgets.Label(row, "", Theme.TEXT.body, Theme.COLOR.ink, "strong")
        price.Name = "Price" -- cautat de SetButtonPrice
        price.TextXAlignment = Enum.TextXAlignment.Center
        price.AutomaticSize = Enum.AutomaticSize.X
        price.Size = UDim2.fromOffset(0, o.height - 8)
        price.LayoutOrder = 4
        price.ZIndex = o.z + 2
        price.Visible = false
    end
    if o.reward then
        local amount = Widgets.Label(row, "", Theme.TEXT.body, Theme.COLOR.ink, "strong")
        amount.Name = "RewardAmount" -- cautat de SetButtonReward
        amount.TextXAlignment = Enum.TextXAlignment.Center
        amount.AutomaticSize = Enum.AutomaticSize.X
        amount.Size = UDim2.fromOffset(0, o.height - 8)
        amount.LayoutOrder = 5
        amount.ZIndex = o.z + 2
        amount.Visible = false
        local px = math.min(22, o.height - 14)
        local pearl = Widgets.PearlIcon(row, px, o.z + 2)
        pearl.Name = "RewardPearl"
        pearl.LayoutOrder = 6
        pearl.Visible = false
        local coin = Widgets.CoinIcon(row, px, o.z + 2)
        coin.Name = "RewardCoin"
        coin.LayoutOrder = 6
        coin.Visible = false
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
    -- butoanele care cresc dupa text (cardul obiectului) isi schimba latimea dupa ce primesc eticheta
    b:GetPropertyChangedSignal("Size"):Connect(function()
        fitButtonRow(b)
    end)
    fitButtonRow(b)
    return b
end

-- [D70, pasul k7] BUTONUL CARE SE TINE APASAT („Build the Dam”): o alegere care nu se face dintr-o atingere scapata. Se
-- umple cat il tii (mouse sau deget), iar dupa `seconds` cheama `onDone`, o singura data pe apasare; daca il lasi mai
-- devreme sau iesi de pe el, se goleste. `SetEnabled(false)` il sterge si ignora apasarile (cat se salveaza).
export type HoldButton = { button: TextButton, SetEnabled: (boolean) -> () }
function Widgets.HoldButton(
    parent: Instance,
    o: {
        text: string,
        width: number,
        height: number,
        z: number,
        seconds: number,
        onDone: () -> (),
    }
): HoldButton
    local button = Widgets.Button(parent, {
        text = o.text,
        width = o.width,
        height = o.height,
        z = o.z,
        onClick = function() end,
    })
    -- [verificatorul k7-k8] umplerea sta in interiorul ramei de lemn (8 px), sub eticheta (Row e la z + 1), in pergament
    -- deschis, ca sa se vada pe fata aurie a butonului
    local INSET = 8
    local fill = Instance.new("Frame")
    fill.Name = "HoldFill"
    fill.BackgroundColor3 = Theme.COLOR.parchment
    fill.BackgroundTransparency = 0.3
    fill.BorderSizePixel = 0
    fill.Position = UDim2.fromOffset(INSET, INSET)
    fill.Size = UDim2.new(0, 0, 1, -INSET * 2)
    fill.ZIndex = o.z
    fill.Parent = button
    local enabled = true
    local heldSince: number? = nil
    local holdInput: InputObject? = nil
    local startPos = Vector3.zero
    local function stop()
        heldSince = nil
        holdInput = nil
        fill.Size = UDim2.new(0, 0, 1, -INSET * 2)
    end
    button.InputBegan:Connect(function(input: InputObject)
        local kind = input.UserInputType
        if
            enabled
            and (kind == Enum.UserInputType.MouseButton1 or kind == Enum.UserInputType.Touch)
        then
            heldSince = os.clock()
            holdInput = input
            startPos = input.Position
            -- [verificatorul k7-k8] degetul ridicat oriunde (sau atingerea anulata) opreste tinerea, nu doar pe buton
            input:GetPropertyChangedSignal("UserInputState"):Connect(function()
                if
                    holdInput == input
                    and (
                        input.UserInputState == Enum.UserInputState.End
                        or input.UserInputState == Enum.UserInputState.Cancel
                    )
                then
                    stop()
                end
            end)
        end
    end)
    button.InputEnded:Connect(function(input: InputObject)
        local kind = input.UserInputType
        if kind == Enum.UserInputType.MouseButton1 or kind == Enum.UserInputType.Touch then
            stop()
        end
    end)
    button.MouseLeave:Connect(stop)
    RunService.RenderStepped:Connect(function()
        local since = heldSince
        if since == nil then
            return
        end
        -- [verificatorul k7-k8] pe telefon, degetul tras de pe buton (gestul de anulare) opreste tinerea
        local input = holdInput
        if
            input ~= nil
            and input.UserInputType == Enum.UserInputType.Touch
            and (input.Position - startPos).Magnitude > 48
        then
            stop()
            return
        end
        if not button.Visible or not button:IsDescendantOf(game) then
            stop()
            return
        end
        local f = math.clamp((os.clock() - since) / math.max(0.1, o.seconds), 0, 1)
        fill.Size = UDim2.new(f, -INSET * 2 * f, 1, -INSET * 2)
        if f >= 1 then
            stop()
            o.onDone()
        end
    end)
    return {
        button = button,
        SetEnabled = function(on: boolean)
            enabled = on
            if not on then
                stop()
            end
            -- [verificatorul k7-k8] stins: acelasi gri ca butoanele fara pret din meniul obiectului
            Widgets.SetButtonTone(
                button,
                if on then Theme.COLOR.gold else Color3.fromRGB(150, 144, 136)
            )
        end,
    }
end

-- TEXTUL UNUI Widgets.Button SE SCHIMBA DOAR AICI. Butonul isi deseneaza eticheta intr-un copil
-- (Row/Label), iar `button.Text` e al TextButton-ului insusi: scris acolo, apare A DOUA eticheta,
-- cu fontul implicit, peste prima. Asa arata `Claim` din lista de quest-uri -- scris peste `Go!`.
function Widgets.SetButtonText(button: TextButton, text: string)
    local row = button:FindFirstChild("Row")
    local label = if row ~= nil then row:FindFirstChild("Label") else nil
    if label ~= nil and label:IsA("TextLabel") then
        label.Text = text
        label.Visible = text ~= ""
    end
    fitButtonRow(button)
end

-- [D53] Pictograma dinaintea etichetei unui Widgets.Button: ascunsa cand butonul nu mai inseamna ce arata
-- ea (moneda de pe butonul cartonasului, cand cartonasul spune "Hire a Hauler first").
function Widgets.SetButtonIcon(button: TextButton, visible: boolean)
    local row = button:FindFirstChild("Row")
    if row == nil then
        return
    end
    for _, child in row:GetChildren() do
        if
            child:IsA("ImageLabel")
            and child.Name ~= "PriceCoin"
            and child.Name ~= "RewardPearl"
            and child.Name ~= "RewardCoin"
        then
            child.Visible = visible
        end
    end
    fitButtonRow(button)
end

-- [D52] Pretul din interiorul unui Widgets.Button nascut cu `price = true`: moneda si cifra, in
-- culoarea data (rosu cand nu ajung banii). `nil` le ascunde -- un buton blocat nu arata un pret.
function Widgets.SetButtonPrice(button: TextButton, text: string?, color: Color3?)
    local row = button:FindFirstChild("Row")
    if row == nil then
        return
    end
    local coin = row:FindFirstChild("PriceCoin")
    if coin ~= nil and coin:IsA("GuiObject") then
        coin.Visible = text ~= nil
    end
    local price = row:FindFirstChild("Price")
    if price ~= nil and price:IsA("TextLabel") then
        price.Text = text or ""
        price.Visible = text ~= nil
        price.TextColor3 = color or Theme.COLOR.ink
    end
    fitButtonRow(button)
end

-- Recompensa dintr-un Widgets.Button nascut cu `reward = true`: cifra, apoi moneda ei -- perla ("pearls") sau moneda
-- de aur ("coins"). `nil` le ascunde: "Go!" nu promite nimic, doar "Claim" arata ce iei.
function Widgets.SetButtonReward(button: TextButton, amount: string?, currency: string?)
    local row = button:FindFirstChild("Row")
    if row == nil then
        return
    end
    local label = row:FindFirstChild("RewardAmount")
    if label ~= nil and label:IsA("TextLabel") then
        label.Text = amount or ""
        label.Visible = amount ~= nil
    end
    local wanted = if currency == "coins" then "RewardCoin" else "RewardPearl"
    for _, name in { "RewardPearl", "RewardCoin" } do
        local icon = row:FindFirstChild(name)
        if icon ~= nil and icon:IsA("GuiObject") then
            icon.Visible = amount ~= nil and name == wanted
        end
    end
    fitButtonRow(button)
end

-- Culoarea unui Widgets.Button. Cand exista arta, fundalul e TRANSPARENT si skin-ul e un sprite --
-- `BackgroundColor3` nu se vede deloc, deci se nuanteaza imaginea (se inmulteste cu culoarea).
-- `nil` = inapoi la aspectul normal.
function Widgets.SetButtonTone(button: TextButton, tone: Color3?)
    local skin = button:FindFirstChild("Skin")
    if skin ~= nil and skin:IsA("ImageLabel") then
        skin.ImageColor3 = tone or Color3.new(1, 1, 1)
    else
        button.BackgroundColor3 = tone or Theme.COLOR.parchmentDim
    end
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
            ico.Name = "TitleIcon" -- cautat de SetWindowTitle
            ico.Position = UDim2.fromOffset(0, 2)
            ico.ZIndex = o.z + 3
            titleX = 44
        end
    end
    local title = Widgets.Label(header, o.title, Theme.TEXT.title, Theme.COLOR.ink, "display")
    title.Name = "Title" -- cautat de SetWindowTitle
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

-- Titlul si pictograma unei ferestre deja construite. O fereastra refolosita pentru obiecte diferite
-- (meniul unei statii: plasa, gaterul, debarcaderul) trebuie sa-si schimbe numele fara sa se
-- reconstruiasca. Pictograma lipsa cade pe `fallbackIcon`, ca titlul sa nu ramana cu un gol in stanga.
function Widgets.SetWindowTitle(
    root: Instance,
    text: string,
    iconKey: string?,
    fallbackIcon: string?
)
    local header = root:FindFirstChild("Header", true)
    if header == nil then
        return
    end
    local title = header:FindFirstChild("Title")
    if title ~= nil and title:IsA("TextLabel") then
        title.Text = text
    end
    local ico = header:FindFirstChild("TitleIcon")
    if iconKey ~= nil and ico ~= nil and ico:IsA("ImageLabel") then
        local function spriteOf(key: string): Assets.Sprite?
            local sp = (Assets.icons :: any)[key] or (Assets.ui :: any)[key]
            return if sp ~= nil and Assets.has(sp) then sp else nil
        end
        local sprite = spriteOf(iconKey :: string)
            or (if fallbackIcon ~= nil then spriteOf(fallbackIcon :: string) else nil)
        if sprite ~= nil then
            ico.Image = Assets.url(sprite :: Assets.Sprite)
        end
    end
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
-- [D58] X-ul e DESENAT (Assets.ui.close, in trei stari, x2 ca ramele). Inainte scria U+2715 cu fontul de pixeli, care
-- n-are glifa -- nici fonturile de rezerva -- iar pe ecran aparea patratelul caracterului lipsa. Fara arta, rezerva
-- scrie U+00D7, pe care fontul o are.
function Widgets.CloseButton(parent: GuiObject, z: number, onClick: () -> ()): TextButton
    local b = Instance.new("TextButton")
    b.Name = "Close"
    b.AnchorPoint = Vector2.new(1, 0)
    b.Position = UDim2.new(1, -10, 0, 10)
    b.AutoButtonColor = false
    b.Text = ""
    b.ZIndex = z
    local normal = Assets.ui.close
    if Assets.has(normal) then
        b.Size = UDim2.fromOffset(normal.width * 2, normal.height * 2)
        b.BackgroundTransparency = 1
        local skin = Instance.new("ImageLabel")
        skin.Name = "Skin"
        skin.BackgroundTransparency = 1
        skin.Image = Assets.url(normal)
        skin.ResampleMode = Enum.ResamplerMode.Pixelated
        skin.Size = UDim2.fromScale(1, 1)
        skin.ZIndex = z
        skin.Parent = b
        local function show(sprite: Assets.Sprite)
            skin.Image = Assets.url(if Assets.has(sprite) then sprite else normal)
        end
        b.MouseEnter:Connect(function()
            show(Assets.ui.close_hover)
        end)
        b.MouseLeave:Connect(function()
            show(normal)
        end)
        b.MouseButton1Down:Connect(function()
            show(Assets.ui.close_down)
        end)
        b.MouseButton1Up:Connect(function()
            show(Assets.ui.close_hover)
        end)
        -- pe telefon nu vine MouseLeave dupa atingere: fara asta, panoul redeschis ar pastra butonul luminat
        b.Activated:Connect(function()
            show(normal)
        end)
    else
        b.Size = UDim2.fromOffset(38, 38)
        b.BackgroundColor3 = Color3.fromRGB(150, 62, 52)
        b.Text = "×"
        b.TextColor3 = Color3.fromRGB(250, 238, 232)
        b.TextSize = 30
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
        b.Activated:Connect(function()
            b.BackgroundColor3 = Color3.fromRGB(150, 62, 52) -- ca mai sus: fara MouseLeave pe telefon
        end)
    end
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

-- Monedele. Sunt ImageLabel SI cand sprite-ul lipseste (imagine goala + fundal colorat), nu
-- Frame -- asa apelantul poate anima `ImageTransparency` si `BackgroundTransparency` in aceeasi
-- tranzitie, fara sa stie care din cele doua variante a primit. Inainte era Frame, iar zborul
-- monedelor din JuiceController stingea doar fundalul; cu sprite, moneda ar fi ramas opaca si
-- ar fi disparut brusc la capat.
local function currencyIcon(
    parent: Instance,
    key: string,
    fallback: Color3,
    edge: Color3,
    px: number,
    z: number
): ImageLabel
    local icon = Instance.new("ImageLabel")
    icon.Name = `{key}Icon`
    icon.Size = UDim2.fromOffset(px, px)
    icon.ZIndex = z
    icon.BackgroundTransparency = 1
    local sprite = (Assets.icons :: any)[key]
    if sprite ~= nil and Assets.has(sprite) then
        icon.Image = Assets.url(sprite)
        icon.ResampleMode = Enum.ResamplerMode.Pixelated
    else
        icon.Image = ""
        icon.BackgroundTransparency = 0
        icon.BackgroundColor3 = fallback
        local c = Instance.new("UICorner")
        c.CornerRadius = UDim.new(1, 0)
        c.Parent = icon
        local stroke = Instance.new("UIStroke")
        stroke.Color = edge
        stroke.Thickness = math.max(1, math.floor(px / 12))
        stroke.Parent = icon
    end
    icon.Parent = parent
    return icon
end

function Widgets.CoinIcon(parent: Instance, px: number, z: number): ImageLabel
    return currencyIcon(parent, "coin", Theme.COLOR.gold, Color3.fromRGB(158, 112, 30), px, z)
end

function Widgets.PearlIcon(parent: Instance, px: number, z: number): ImageLabel
    return currencyIcon(parent, "pearl", Theme.COLOR.cool, Color3.fromRGB(120, 150, 180), px, z)
end

-- Inel de progres (coins/price) fara imagini: un UIGradient cu doua trepte dure, pus pe conturul
-- unui cerc, coloreaza `progress` din circumferinta cu `bright` si restul cu `dim`. Intoarce
-- (cadrul, functia care actualizeaza progresul) -- apelantul retine ambele.
function Widgets.Ring(
    parent: Instance,
    diameter: number,
    thickness: number,
    z: number
): (Frame, (progress: number, bright: Color3, dim: Color3) -> ())
    local ring = Instance.new("Frame")
    ring.Name = "Ring"
    ring.BackgroundTransparency = 1
    ring.Size = UDim2.fromOffset(diameter, diameter)
    ring.ZIndex = z
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(1, 0)
    corner.Parent = ring
    local stroke = Instance.new("UIStroke")
    stroke.Thickness = thickness
    stroke.Parent = ring
    local grad = Instance.new("UIGradient")
    grad.Parent = stroke
    ring.Parent = parent

    local function setProgress(progress: number, bright: Color3, dim: Color3)
        -- capetele 0 si 1 sunt obligatorii si treptele trebuie strict crescatoare, altfel
        -- ColorSequence.new arunca -- de-aia pragul se tine departe de 0 si de 1
        local p = math.clamp(progress, 0.001, 0.998)
        local p2 = math.min(p + 0.001, 0.999)
        grad.Color = ColorSequence.new({
            ColorSequenceKeypoint.new(0, bright),
            ColorSequenceKeypoint.new(p, bright),
            ColorSequenceKeypoint.new(p2, dim),
            ColorSequenceKeypoint.new(1, dim),
        })
    end
    return ring, setProgress
end

-- Text care apare langa ceva, urca si se stinge: rasplata vizibila pentru un +1 sau +N. Fara ea,
-- o cifra se schimba undeva si nimeni nu leaga schimbarea de actiunea care tocmai s-a intamplat
-- [DECIZII D43].
function Widgets.FloatText(parent: GuiObject, text: string, color: Color3, z: number): TextLabel
    local tag = Instance.new("TextLabel")
    tag.Name = "FloatText"
    tag.BackgroundTransparency = 1
    tag.AnchorPoint = Vector2.new(0.5, 1)
    tag.Position = UDim2.fromScale(0.5, 0)
    tag.Size = UDim2.fromOffset(140, 28)
    tag.TextColor3 = color
    tag.TextSize = Theme.TEXT.heading
    tag.Text = text
    tag.ZIndex = z
    Theme.applyFont(tag, "display")
    Theme.punch(tag, 2)
    tag.Parent = parent
    local rise = TweenService:Create(
        tag,
        TweenInfo.new(0.9, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
        { Position = UDim2.new(0.5, 0, 0, -34), TextTransparency = 1 }
    )
    rise:Play()
    task.delay(1, function()
        tag:Destroy()
    end)
    return tag
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
    chip.Size = UDim2.fromOffset(120, if name ~= nil then 52 else 40)
    chip.ZIndex = z
    Widgets.PillBackground(chip, z) -- pastila cu 9 felii cand exista arta, altfel placa de azi
    chip.Parent = parent

    -- continutul intr-un frame separat de fundal: skin-ul cu 9 felii de mai sus e un copil direct
    -- al lui `chip`, iar UIListLayout repozitioneaza TOTI copiii directi ai parintelui lui -- daca
    -- randul ar sta chiar in `chip`, skin-ul (marimea intregii pastile) ar intra si el in asezarea
    -- orizontala si ar strica randul. Acelasi tipar radacina/continut ca la Widgets.Panel.
    local content = Instance.new("Frame")
    content.Name = "Content"
    content.BackgroundTransparency = 1
    content.Size = UDim2.fromScale(1, 1)
    content.ZIndex = z + 1
    content.Parent = chip

    local layout = Instance.new("UIListLayout")
    layout.FillDirection = Enum.FillDirection.Horizontal
    layout.VerticalAlignment = Enum.VerticalAlignment.Center
    layout.Padding = UDim.new(0, Theme.SPACE.sm)
    layout.Parent = content
    local pad = Instance.new("UIPadding")
    pad.PaddingLeft = UDim.new(0, Theme.SPACE.sm)
    pad.PaddingRight = UDim.new(0, Theme.SPACE.sm)
    pad.Parent = content

    local ico = Widgets.Icon(content, iconKey, 26)
    if ico ~= nil then
        ico.LayoutOrder = 1
    end
    local value = Widgets.Label(content, "0", Theme.TEXT.body, Theme.COLOR.onDark, "strong")
    value.LayoutOrder = 2
    value.AutomaticSize = Enum.AutomaticSize.X
    value.Size = UDim2.fromOffset(0, 26)
    value.ZIndex = z + 2

    if name ~= nil then
        -- Eticheta se parenteaza pe CHIP, nu pe `content`: content are UIListLayout, iar acesta
        -- rearanjeaza TOTI copiii lui, indiferent de AnchorPoint/Position. Cu eticheta inauntru,
        -- ea intra prima in rand (LayoutOrder 0) si impingea pictograma si cifra AFARA din pastila
        -- -- pe ecran se vedea "Sack" in pastila si "0/30" langa ea, pe iarba [vazut 2026-09-12].
        local caption = Widgets.Label(chip, name, Theme.TEXT.tiny, Theme.COLOR.onDarkSoft, "body")
        caption.Name = "Caption"
        caption.AnchorPoint = Vector2.new(0.5, 1)
        caption.Position = UDim2.new(0.5, 0, 1, -2)
        caption.Size = UDim2.fromOffset(112, 14)
        caption.TextXAlignment = Enum.TextXAlignment.Center
        caption.ZIndex = z + 2
        -- randul cu pictograma si cifra urca, ca sa faca loc etichetei
        pad.PaddingBottom = UDim.new(0, 14)
    end
    return chip, value
end

return Widgets
