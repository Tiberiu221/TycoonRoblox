--!strict
-- Cutia de dialog: cineva sta in fata ta si iti vorbeste [RIVERKEEP 2].
--
-- De ce arata asa si nu ca un mesaj in colt:
--   * Un mesaj in coltul ecranului, peste care jocul curge mai departe, nu se citeste. Devine
--     zgomot. Aici jocul STA: personajul nu se misca pana nu termini de citit.
--   * Portret mare in stanga, nume, text. E tiparul din jocurile cu dialog fiindca spune dintr-o
--     privire CINE vorbeste, ceea ce un text simplu nu spune.
--   * Textul apare litera cu litera. Un bloc de text aparut instant se sare; unul care se scrie
--     se citeste. Prima apasare il arata tot, a doua trece mai departe: cine vrea repede, poate.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local AnimConfig = require(ReplicatedStorage.Shared.Config.AnimConfig)
local SettlerConfig = require(ReplicatedStorage.Shared.Config.SettlerConfig)
local Assets = require(ReplicatedStorage.Shared.Config.Assets)
local DialogueConfig = require(ReplicatedStorage.Shared.Config.DialogueConfig)
local Theme = require(script.Parent.Parent.UI.Theme)
local Widgets = require(script.Parent.Parent.UI.Widgets)

local DialogueController = {}

local BOX_W, BOX_H = 1120, 240
local PORTRAIT = 168
local Z = 60

local root: Frame
local nameLabel: TextLabel
local textLabel: TextLabel
local promptIcon: ImageLabel?
local promptLabel: TextLabel
local promptButton: TextButton
local portraitLayers: { ImageLabel } = {}

local lines: { DialogueConfig.Line } = {}
local index = 0
local shown = 0 -- cate semne s-au scris pana acum
local typing = false
local active = false
local onFinished: (() -> ())? = nil

local function currentText(): string
    local line = lines[index]
    return if line ~= nil then line.text else ""
end

-- Indemnul e MEREU vizibil, doar isi schimba mesajul. Ascuns cat timp se scrie textul, caseta
-- parea inerta exact in primele secunde -- adica fix cand jucatorul se intreaba ce sa faca.
local function setPrompt(skip: boolean)
    -- Pe buton scrie verbul, nu instructiunea de folosire a butonului. "Skip" si "Continue" se
    -- inteleg dintr-o privire; "click or press E to continue" e o propozitie pe care nu o mai
    -- citeste nimeni si care oricum nu incape.
    promptLabel.Text = if skip then "Skip  " elseif index < #lines then "Continue  " else "Done  "
    promptButton.Visible = true
    local icon = promptIcon
    if icon ~= nil then
        icon.Visible = true
    end
end

local function showLine(i: number)
    index = i
    shown = 0
    typing = true
    textLabel.Text = currentText()
    textLabel.MaxVisibleGraphemes = 0
    setPrompt(true)
end

local function finishTyping()
    typing = false
    shown = #currentText()
    textLabel.MaxVisibleGraphemes = -1
    setPrompt(false)
end

local function close()
    active = false
    typing = false
    root.Visible = false
    local finish = onFinished
    onFinished = nil
    if finish ~= nil then
        finish()
    end
end

-- O apasare: daca inca se scrie, arata tot. Daca s-a terminat, treci mai departe.
local function advance()
    if not active then
        return
    end
    if typing then
        finishTyping()
        return
    end
    if index < #lines then
        showLine(index + 1)
    else
        close()
    end
end

function DialogueController.IsActive(): boolean
    return active
end

local function rgb(list: { { number } }, pick: number?): Color3
    local c = list[pick or 1] or list[1]
    return Color3.fromRGB(c[1], c[2], c[3])
end

-- Imbraca portretul dupa infatisarea vorbitorului. Fara `look`, sau fara foi pe straturi,
-- ramane foaia dintr-o bucata -- mai bine un portret generic decat unul gresit.
local function dress(look: { [string]: any }?)
    local base, hairL, outfitL = portraitLayers[1], portraitLayers[2], portraitLayers[3]
    if base == nil then
        return
    end
    local layered = Assets.has(Assets.people.body.a)
    if look == nil or not layered then
        base.Image = Assets.url(Assets.character_anim)
        base.ImageColor3 = Color3.new(1, 1, 1)
        for _, l in { hairL, outfitL } do
            if l ~= nil then
                l.ImageTransparency = 1
            end
        end
        return
    end
    local bodySheet = (Assets.people.body :: any)[look.build or "a"]
    if bodySheet ~= nil then
        base.Image = Assets.url(bodySheet)
    end
    base.ImageColor3 = rgb(SettlerConfig.SKIN, look.skin)
    if hairL ~= nil then
        local sheet = (Assets.people.hair :: any)[look.hair or "short"]
        if sheet ~= nil and Assets.has(sheet) then
            hairL.Image = Assets.url(sheet)
            hairL.ImageColor3 = rgb(SettlerConfig.HAIR_COLORS, look.hairColor)
            hairL.ImageTransparency = 0
        else
            hairL.ImageTransparency = 1 -- chel
        end
    end
    if outfitL ~= nil then
        local sheet = (Assets.people.outfit :: any)[look.job or ""]
        if sheet ~= nil and Assets.has(sheet) then
            outfitL.Image = Assets.url(sheet)
            outfitL.ImageTransparency = 0
        else
            outfitL.ImageTransparency = 1
        end
    end
end

-- `look` = infatisarea vorbitorului (build, hair, hairColor, skin, job), ca portretul sa fie
-- chiar el, nu un desen generic
function DialogueController.Play(
    speaker: string,
    sceneId: string,
    look: { [string]: any }?,
    finished: (() -> ())?
)
    local scene = DialogueConfig.get(sceneId)
    if scene == nil or #scene.lines == 0 then
        if finished ~= nil then
            finished()
        end
        return
    end
    lines = scene.lines
    onFinished = finished
    active = true
    nameLabel.Text = speaker
    dress(look)

    root.Visible = true
    root.Position = UDim2.new(0.5, 0, 1, 120)
    local slide = TweenService:Create(
        root,
        TweenInfo.new(0.3, Enum.EasingStyle.Quart, Enum.EasingDirection.Out),
        { Position = UDim2.new(0.5, 0, 1, -40) }
    )
    slide:Play()
    showLine(1)
end

function DialogueController.Init(deps: { HudGui: Frame })
    local window, body = Widgets.Window(deps.HudGui, {
        name = "Dialogue",
        title = "",
        icon = nil,
        width = BOX_W,
        height = BOX_H,
        z = Z,
        onClose = close,
    })
    window.AnchorPoint = Vector2.new(0.5, 1)
    window.Position = UDim2.new(0.5, 0, 1, -64) -- la -40 statea lipita de marginea de jos
    window.Visible = false
    root = window

    -- fereastra standard vine cu titlu si buton de inchidere; aici nu isi au locul
    local header = body.Parent:FindFirstChild("Header")
    if header ~= nil then
        header:Destroy()
    end
    local closeBtn = window:FindFirstChild("Close")
    if closeBtn ~= nil then
        closeBtn:Destroy()
    end
    body.Position = UDim2.fromOffset(0, 0)
    body.Size = UDim2.fromScale(1, 1)

    -- portretul: chiar sprite-ul colonistului, marit, intr-o caseta scobita
    local frame = Widgets.Slot(body, Z + 2)
    frame.Size = UDim2.fromOffset(PORTRAIT, PORTRAIT)
    -- Portretul e CHIAR vorbitorul: aceleasi trei straturi ca in lume (corp, par, tinuta), cu
    -- nuanta lui de piele si de par. Inainte era foaia dintr-o bucata -- acum desenata pe rampe
    -- neutre, deci primul om din joc ar fi vorbit cu piele si par gri.
    if Assets.has(Assets.character_anim) then
        for i, name in { "Portrait", "PortraitHair", "PortraitOutfit" } do
            local img = Instance.new("ImageLabel")
            img.Name = name
            img.BackgroundTransparency = 1
            img.Image = Assets.url(Assets.character_anim)
            img.ResampleMode = Enum.ResamplerMode.Pixelated
            img.AnchorPoint = Vector2.new(0.5, 1)
            img.Position = UDim2.new(0.5, 0, 1, -10)
            img.Size = UDim2.fromOffset(16 * 6, 24 * 6) -- 96x144, incape in cadrul de 168
            -- randul "idle_down": se uita spre jucator cat vorbeste
            img.ImageRectOffset =
                Vector2.new(0, AnimConfig.ROWS.idle_down.index * AnimConfig.FRAME_HEIGHT)
            img.ImageRectSize = Vector2.new(AnimConfig.FRAME_WIDTH, AnimConfig.FRAME_HEIGHT)
            img.ZIndex = Z + 2 + i
            -- straturile de sus pornesc ascunse; le aprinde `dress` doar daca exista foi pe straturi
            img.ImageTransparency = if i == 1 then 0 else 1
            img.Parent = frame
            portraitLayers[i] = img
        end
    end

    local textX = PORTRAIT + Theme.SPACE.lg

    nameLabel = Widgets.Label(body, "", 24, Theme.COLOR.wood, "display")
    nameLabel.Position = UDim2.fromOffset(textX, 2)
    nameLabel.Size = UDim2.new(1, -textX, 0, 30)
    nameLabel.ZIndex = Z + 3

    textLabel = Widgets.Label(body, "", 22, Theme.COLOR.ink, "body")
    textLabel.Position = UDim2.fromOffset(textX, 40)
    textLabel.Size = UDim2.new(1, -textX, 0, 110)
    textLabel.TextWrapped = true
    textLabel.TextYAlignment = Enum.TextYAlignment.Top
    textLabel.ZIndex = Z + 3

    -- BUTON ADEVARAT, nu o legenda in colt. Owner-ul a semnalat de doua ori ca nu se intelege
    -- ca poti apasa ca sa mergi mai departe -- si avea dreptate: un text mic, auriu, lipit de
    -- marginea de jos arata a subtitlu, nu a comanda. Regula: daca ceva se poate apasa, trebuie
    -- sa ARATE ca un buton, nu sa fie explicat ca e unul.
    promptButton = Widgets.Button(body, {
        text = "",
        width = 208,
        height = 48,
        z = Z + 4,
        onClick = function()
            advance()
        end,
    })
    promptButton.Name = "Continue"
    promptButton.AnchorPoint = Vector2.new(1, 1)
    promptButton.Position = UDim2.new(1, -24, 1, -20)

    promptLabel = Widgets.Label(promptButton, "", Theme.TEXT.body, Theme.COLOR.ink, "display")
    promptLabel.AnchorPoint = Vector2.new(0.5, 0.5)
    promptLabel.Position = UDim2.fromScale(0.5, 0.5)
    promptLabel.Size = UDim2.fromScale(1, 1)
    promptLabel.TextXAlignment = Enum.TextXAlignment.Center
    promptLabel.ZIndex = Z + 6

    local chevron = Widgets.Icon(promptButton, "arrow", 22)
    if chevron ~= nil then
        chevron.AnchorPoint = Vector2.new(1, 0.5)
        chevron.Position = UDim2.new(1, -14, 0.5, 0)
        chevron.Rotation = 180
        chevron.ZIndex = Z + 6
        promptIcon = chevron
        -- clipeste incet: ochiul prinde miscarea si intelege ca acolo trebuie apasat
        TweenService:Create(
            chevron,
            TweenInfo.new(0.7, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true),
            { ImageTransparency = 0.65 }
        ):Play()
    end

    -- toata cutia e apasabila: pe telefon nu exista tastatura, iar o tinta mica ar fi o gluma
    local hit = Instance.new("TextButton")
    hit.BackgroundTransparency = 1
    hit.Text = ""
    hit.Size = UDim2.fromScale(1, 1)
    hit.ZIndex = Z + 5
    hit.Parent = window
    hit.Activated:Connect(advance)

    UserInputService.InputBegan:Connect(function(input: InputObject, processed: boolean)
        if not active or processed then
            return
        end
        if
            input.KeyCode == Enum.KeyCode.E
            or input.KeyCode == Enum.KeyCode.Space
            or input.KeyCode == Enum.KeyCode.Return
        then
            advance()
        end
    end)

    RunService.PreRender:Connect(function(dt: number)
        if not active or not typing then
            return
        end
        shown += dt * DialogueConfig.CHARS_PER_SECOND
        -- GRAFEME, nu octeti si nici puncte de cod. `MaxVisibleGraphemes` numara grafeme, iar
        -- daca ii dam un total gresit, textul se opreste inainte de final sau se termina prea
        -- devreme. Conteaza si pentru diacritice.
        local total = 0
        for _ in utf8.graphemes(currentText()) do
            total += 1
        end
        if shown >= total then
            finishTyping()
        else
            textLabel.MaxVisibleGraphemes = math.floor(shown)
        end
    end)
end

return DialogueController
