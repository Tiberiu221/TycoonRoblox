--!strict
-- HUD-ul permanent: doar ce trebuie sa vada jucatorul TOT timpul [DECIZII D05].
--
-- Rescris pentru tycoon [F0 spec 4.2]: cifrele de colonie (hrana, materiale, gramada, oameni,
-- paturi) au disparut -- un singur numar conteaza acum, monedele, plus rata pe secunda si cat de
-- plina e traista. Restul (joystick, buton de interactiune, mesaje scurte) ramane neschimbat:
-- nu tine de colonie, tine de cum se joaca orice ecran 2D pe telefon.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local GuideMath = require(ReplicatedStorage.Shared.Modules.GuideMath)
local TycoonMath = require(ReplicatedStorage.Shared.Modules.TycoonMath)
local TycoonConfig = require(ReplicatedStorage.Shared.Config.TycoonConfig)
local AmbitionMath = require(ReplicatedStorage.Shared.Modules.AmbitionMath)
local HudLayout = require(ReplicatedStorage.Shared.Modules.HudLayout)
local Assets = require(ReplicatedStorage.Shared.Config.Assets)
local Strings = require(ReplicatedStorage.Shared.Config.Strings)
local Theme = require(script.Parent.Parent.UI.Theme)
local Widgets = require(script.Parent.Parent.UI.Widgets)

local HUDController = {}
local coinPill: Frame
local coinRow: Frame
local coinValue: TextLabel
local ratePill: Frame
local pearlPill: Frame
local pearlValue: TextLabel
local idlePill: Frame
local idleValue: TextLabel
local objPill: TextButton
local objBadge: Frame
local objBadgeLabel: TextLabel
local questActive: { text: string, progress: number, goal: number, counter: string }? = nil
local ambition: AmbitionMath.Ambition? = nil -- [D63] tinta fara sfarsit, cand nu e niciun quest
local questClaimable = 0 -- cat timp e ceva de revendicat, apasarea pe linia NEXT duce tot la lista de quest-uri
local objText: TextLabel
local objNeed: TextLabel
local objFill: Frame
local objTrack: Frame
local objStep: TextLabel -- [D51] al doilea rand: pasul de acum
local rateValue: TextLabel
local sackValue: TextLabel
local sackChip: Frame
local toastLabel: TextLabel
-- Cartonasul de la apropiere [F3 spec item 5]: fix jos-centru in HUD, marime fixa -- nu mai urca
-- deasupra platformei (asta traia in PadController pana acum) -- deci nu mai poate acoperi
-- niciodata raul sau alta platforma, indiferent unde esti pe mal. PadController tot decide CAND
-- (raza de 220px) si CE (care pad, afordabil sau nu); aici traieste doar desenul.
-- 204, nu 148: cartonasul e acum o CONFIRMARE -- are in plus sprânceana, randul cu cat iti ramane
-- si butonul de cumparare. Cutiile sunt verificate de scripts/art/check_panel_rows.py.
local APPROACH_W, APPROACH_H = 440, 204
local APPROACH_INSET_X, APPROACH_INSET_Y = 30, 20
local APPROACH_LEFT_W = 140 -- [D73] coloana din stanga a cartonasului: castigul si pretul
local APPROACH_BOTTOM_MARGIN = 132
local approachCard: Frame
local approachEyebrow: TextLabel
local approachName: TextLabel
local approachBlurb: TextLabel
local approachDelta: TextLabel
local approachNote: TextLabel
local approachPrice: TextLabel
local approachCoin: ImageLabel
local approachSpend: TextLabel
local approachBuy: TextButton
local approachCanBuy = false -- ce arata butonul ACUM; apasarea nu face nimic cand e stins
local approachBuyFn: (() -> ())? = nil -- dat de PadController; HUD-ul nu stie sa cumpere singur
local approachId: string? = nil -- padId-ul curent, nil = ascuns
local approachRuin = false -- [D53] cartonasul arata acum o ruina incuiata, nu o cumparare
local APPROACH_POP = TweenInfo.new(0.18, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
-- pastilele monede/rata [F2 spec Agent U pct.3]: monede sus si mare, rata sub ea, sacul la dreapta
-- Linia "NEXT" e si BANNERUL DE QUEST. La ei sunt doua lucruri diferite (o linie de obiectiv si o
-- banda de quest sus); la noi ar fi spus mereu acelasi lucru pe doua randuri, asa ca e unul singur:
-- cand exista quest activ, scrie quest-ul si contorul lui (0/1) si se poate APASA ca sa deschida
-- lista; cand nu, ramane reperul vechi ("Saving for ...", cu bara si cat mai lipseste).
-- Linia "NEXT": singurul lucru din HUD care raspunde, permanent, la "ce fac acum si de ce".
-- Pana la ea, cand nu-ti ajungeau banii ghidajul tacea complet (GuideMath intorcea nil) -- adica
-- exact in cele cateva minute de strans, jucatorul ramanea fara niciun reper. Sageata ramane
-- nagul rar (11s fara progres); asta e reperul fix, mic si linistit.
-- Pastila venitului pasiv. NU exista de la inceput: apare abia cand lantul poate merge fara tine
-- (o Mana care cara si un Negustor care vinde). Momentul ala e rasplata jocului -- ai cumparat
-- scaparea de o corvoada -- si se vede prin faptul ca in HUD apare ceva ce nu era [Idle Miner].
-- [D63] Marimile si locurile pastilelor vin din HudLayout (o grila, un bloc drept); aici raman doar numele scurte.
local GRID = HudLayout.rects()
local IDLE_W, IDLE_H = GRID.away.w, GRID.away.h
-- A doua moneda sta LANGA prima, la aceeasi inaltime: doua monede despartite de alte pastile nu se
-- mai citesc ca pereche. Chipul traistei si pastila IDLE se muta la dreapta lor.
local PEARL_PILL_W = GRID.pearl.w
local OBJ_W, OBJ_H = GRID.objective.w, HudLayout.OBJ_H
local OBJ_H_STEP = HudLayout.OBJ_H_STEP -- [D51] cu randul pasului
local COIN_PILL_W, COIN_PILL_H = GRID.coin.w, GRID.coin.h
local RATE_PILL_W, RATE_PILL_H = GRID.rate.w, GRID.rate.h
local coinTicker: ((number) -> ())? = nil
local rateTicker: ((number) -> ())? = nil
-- treimea de sus, centrat: liber la orice latime, si acolo se uita ochiul
local TOAST_HOME = UDim2.fromScale(0.5, 0.26)
-- Comenzile de atingere. Panza HUD e viewport/hudScale, deci astea sunt unitati logice:
-- pe un telefon de 896x414 factorul e 0.62, adica baza de 170 iese ~105 px fizici.
local STICK_BASE = 170
local STICK_KNOB = 76
local STICK_RADIUS = 58
local STICK_DEADZONE = 10
local STICK_MARGIN = 44
local ACTION_SIZE = 108
local toastToken = 0
-- [2026-09-30] marginea de jos (px de ecran) a bannerului de pe ecran, sau nil: toast-ul iese sub el, nu sub placa lui
local toastFloor: (() -> number?)? = nil
local fps = 60
local touchButtons: { TextButton } = {}
-- [D59] atingerea care tine apasat butonul de actiune (undita se mulineaza tinand apasat); nil = nimeni
local actionHeldBy: InputObject? = nil
local lastSackFull = false

local function touchButton(
    parent: Instance,
    text: string,
    onDown: () -> (),
    onUp: () -> ()
): TextButton
    local b = Instance.new("TextButton")
    b.AnchorPoint = Vector2.new(0.5, 1)
    b.Size = UDim2.fromOffset(112, 112)
    b.BackgroundColor3 = Theme.COLOR.plate
    b.BackgroundTransparency = 0.42
    b.TextColor3 = Theme.COLOR.onDark
    b.TextSize = 40
    b.Text = text
    b.AutoButtonColor = false
    b.ZIndex = 10
    Theme.applyFont(b, "strong")
    local c = Instance.new("UICorner")
    c.CornerRadius = UDim.new(0, 18)
    c.Parent = b
    b.InputBegan:Connect(function(input: InputObject)
        if
            input.UserInputType == Enum.UserInputType.Touch
            or input.UserInputType == Enum.UserInputType.MouseButton1
        then
            onDown()
        end
    end)
    b.InputEnded:Connect(function(input: InputObject)
        if
            input.UserInputType == Enum.UserInputType.Touch
            or input.UserInputType == Enum.UserInputType.MouseButton1
        then
            onUp()
        end
    end)
    b.Parent = parent
    table.insert(touchButtons, b)
    return b
end

local TICK_UP = TweenInfo.new(0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)

-- Numarul afisat urca lin spre o tinta noua (~250ms); o scadere (o cheltuiala) se vede imediat,
-- fara animatie [F2 spec Agent U pct.3]. TweenService nu poate anima un numar Lua simplu, deci
-- tweenuim un NumberValue ascuns si recitim valoarea lui la fiecare pas, formatata cu `format`.
local function newTicker(label: TextLabel, format: (number) -> string): (number) -> ()
    local holder = Instance.new("NumberValue")
    local conn: RBXScriptConnection? = nil
    return function(target: number)
        if conn ~= nil then
            conn:Disconnect()
            conn = nil
        end
        -- `holder.Value` e chiar cifra afisata ACUM (in mijlocul unui tween, e valoarea
        -- intermediara) -- de-aici pleaca urmatoarea urcare. Daca am porni de la ultima tinta,
        -- o a doua vanzare venita in timpul primei ar face numarul sa sara inainte.
        if target <= holder.Value then
            holder.Value = target -- o scadere (o cheltuiala) se vede imediat, fara animatie
            label.Text = format(target)
            return
        end
        conn = holder:GetPropertyChangedSignal("Value"):Connect(function()
            label.Text = format(holder.Value)
        end)
        TweenService:Create(holder, TICK_UP, { Value = target }):Play()
    end
end

function HUDController.Init(
    deps: {
        HudGui: Frame,
        SetStick: (number, number) -> (),
        Interact: () -> (),
        OpenQuests: (() -> ())?,
        -- [D63] linia NEXT arata o tinta fara sfarsit: apasarea deschide meniul obiectului ei, nu lista de quest-uri
        OpenAmbition: ((AmbitionMath.Ambition) -> ())?,
        PanelsOpen: (() -> boolean)?,
    }
)
    -- Numarul central: monedele. Mare, cu pictograma, pe pastila proprie -- SINGURUL numar la
    -- care contribuie toata bucla [DECIZII D45]. Rata sta sub el (o completare, nu al doilea numar
    -- principal), sacul trece la DREAPTA grupului -- ierarhie clara in loc de trei randuri
    -- stivuite [F2 spec Agent U pct.3].
    coinPill = Instance.new("Frame")
    coinPill.Name = "CoinPill"
    coinPill.Position = UDim2.fromOffset(GRID.coin.x, GRID.coin.y)
    coinPill.Size = UDim2.fromOffset(COIN_PILL_W, COIN_PILL_H)
    coinPill.ZIndex = 12
    Widgets.PillBackground(coinPill, 12)
    coinPill:SetAttribute("GuideBlocker", true) -- [verificatorii A0, k12] indicatorul ghidajului il ocoleste
    coinPill.Parent = deps.HudGui

    coinRow = Instance.new("Frame")
    coinRow.Name = "Coins"
    coinRow.BackgroundTransparency = 1
    coinRow.Position = UDim2.fromOffset(Theme.SPACE.md, 0)
    coinRow.Size = UDim2.new(1, -Theme.SPACE.md * 2, 1, 0)
    coinRow.ZIndex = 13
    coinRow.Parent = coinPill
    local coinLayout = Instance.new("UIListLayout")
    coinLayout.FillDirection = Enum.FillDirection.Horizontal
    coinLayout.VerticalAlignment = Enum.VerticalAlignment.Center
    coinLayout.Padding = UDim.new(0, Theme.SPACE.sm)
    coinLayout.Parent = coinRow
    local coinIcon = Widgets.CoinIcon(coinRow, 30, 13)
    coinIcon.LayoutOrder = 1
    coinValue = Widgets.Label(coinRow, "0", Theme.TEXT.title, Theme.COLOR.onDark, "display")
    coinValue.LayoutOrder = 2
    coinValue.AutomaticSize = Enum.AutomaticSize.X
    coinValue.Size = UDim2.fromOffset(0, Theme.TEXT.title + 4)
    coinValue.ZIndex = 14
    Theme.punch(coinValue)
    coinTicker = newTicker(coinValue, TycoonMath.formatNumber)

    -- rata: cat de repede creste numarul de sus, cat timp nu faci nimic -- pe pastila ei, direct
    -- sub cea a monedelor. TEXT.body, nu small: la scara HUD-ului pe un ecran de laptop, 15 px
    -- ajungeau la ~12 si rata abia se citea (vazut in Studio, 2026-09-11)
    pearlPill = Instance.new("Frame")
    pearlPill.Name = "PearlPill"
    pearlPill.Position = UDim2.fromOffset(GRID.pearl.x, GRID.pearl.y)
    pearlPill.Size = UDim2.fromOffset(PEARL_PILL_W, COIN_PILL_H)
    pearlPill.ZIndex = 12
    Widgets.PillBackground(pearlPill, 12)
    pearlPill:SetAttribute("GuideBlocker", true) -- [verificatorii A0, k12] indicatorul ghidajului il ocoleste
    pearlPill.Parent = deps.HudGui

    local pearlDot = Widgets.PearlIcon(pearlPill, 22, 13)
    pearlDot.AnchorPoint = Vector2.new(0, 0.5)
    pearlDot.Position = UDim2.fromOffset(Theme.SPACE.md, COIN_PILL_H / 2)

    pearlValue = Widgets.Label(pearlPill, "0", Theme.TEXT.heading, Theme.COLOR.onDark, "display")
    pearlValue.AnchorPoint = Vector2.new(1, 0.5)
    pearlValue.Position = UDim2.fromOffset(PEARL_PILL_W - Theme.SPACE.md, COIN_PILL_H / 2)
    pearlValue.Size = UDim2.fromOffset(PEARL_PILL_W - 52, Theme.TEXT.heading + 6)
    pearlValue.TextXAlignment = Enum.TextXAlignment.Right
    pearlValue.ZIndex = 13

    ratePill = Instance.new("Frame")
    ratePill.Name = "RatePill"
    ratePill.Position = UDim2.fromOffset(GRID.rate.x, GRID.rate.y)
    ratePill.Size = UDim2.fromOffset(RATE_PILL_W, RATE_PILL_H)
    ratePill.ZIndex = 12
    Widgets.PillBackground(ratePill, 12)
    ratePill:SetAttribute("GuideBlocker", true) -- [verificatorii A0, k12] indicatorul ghidajului il ocoleste
    ratePill.Parent = deps.HudGui

    rateValue = Widgets.Label(ratePill, "+0.0/s", Theme.TEXT.body, Theme.COLOR.gold, "strong")
    rateValue.Position = UDim2.fromOffset(Theme.SPACE.sm, (RATE_PILL_H - Theme.TEXT.body) / 2 - 2)
    rateValue.Size = UDim2.fromOffset(RATE_PILL_W - Theme.SPACE.sm * 2, Theme.TEXT.body + 6)

    idlePill = Instance.new("Frame")
    idlePill.Name = "IdlePill"
    -- [D63] Pe randul al doilea, exact sub perle si sac, langa rata: pana acum statea la coada randului de sus, la
    -- jumatatea inaltimii, si lungea tot grupul cu ~180 de unitati.
    idlePill.Position = UDim2.fromOffset(GRID.away.x, GRID.away.y)
    idlePill.Size = UDim2.fromOffset(IDLE_W, IDLE_H)
    idlePill.ZIndex = 12
    idlePill.Visible = false
    Widgets.PillBackground(idlePill, 12)
    idlePill:SetAttribute("GuideBlocker", true) -- [verificatorii A0, k12] indicatorul ghidajului il ocoleste
    idlePill.Parent = deps.HudGui

    -- Fulgerul inaintea cuvantului. Daca sprite-ul lipseste, Widgets.Icon da nil si cuvantul
    -- ramane singur la stanga -- de-aici `eyebrowX` calculat, nu o constanta.
    local idleBolt = Widgets.Icon(idlePill, "idle", 18)
    local eyebrowX = Theme.SPACE.sm
    if idleBolt ~= nil then
        idleBolt.AnchorPoint = Vector2.new(0, 0.5)
        idleBolt.Position = UDim2.fromOffset(Theme.SPACE.sm, IDLE_H / 2)
        idleBolt.ZIndex = 13
        eyebrowX = Theme.SPACE.sm + 18 + 4
    end

    local idleEyebrow =
        Widgets.Label(idlePill, Strings.HUD_AWAY, Theme.TEXT.tiny, Theme.COLOR.cool, "strong")
    idleEyebrow.Position = UDim2.fromOffset(eyebrowX, (IDLE_H - Theme.TEXT.tiny) / 2 - 2)
    idleEyebrow.Size = UDim2.fromOffset(42, Theme.TEXT.tiny + 6)
    idleEyebrow.ZIndex = 13

    -- cifra incepe dupa cuvant, nu pe sub el: cutiile nu se calca, deci sonda tace cat nu se calca nici literele
    local idleValueX = eyebrowX + 42 + 4
    idleValue = Widgets.Label(idlePill, "0.0/s", Theme.TEXT.body, Theme.COLOR.cool, "strong")
    idleValue.AnchorPoint = Vector2.new(1, 0)
    idleValue.Position =
        UDim2.fromOffset(IDLE_W - Theme.SPACE.sm, (IDLE_H - Theme.TEXT.body) / 2 - 2)
    idleValue.Size = UDim2.fromOffset(IDLE_W - Theme.SPACE.sm - idleValueX, Theme.TEXT.body + 6)
    idleValue.TextXAlignment = Enum.TextXAlignment.Right
    idleValue.ZIndex = 13

    -- ---- linia "NEXT" -------------------------------------------------------------------------
    objPill = Instance.new("TextButton")
    objPill.Name = "Objective"
    objPill.AutoButtonColor = false
    objPill.Text = ""
    objPill.Position = UDim2.fromOffset(GRID.objective.x, GRID.objective.y)
    objPill.Size = UDim2.fromOffset(OBJ_W, OBJ_H)
    objPill.ZIndex = 12
    objPill.Visible = false
    Widgets.PillBackground(objPill, 12)
    objPill:SetAttribute("GuideBlocker", true) -- [verificatorii A0, k12] indicatorul ghidajului il ocoleste
    objPill.Parent = deps.HudGui

    local eyebrow = Widgets.Label(objPill, "NEXT", Theme.TEXT.tiny, Theme.COLOR.gold, "strong")
    eyebrow.Position = UDim2.fromOffset(Theme.SPACE.md, 6)
    eyebrow.Size = UDim2.fromOffset(48, 14) -- fraza incepe la +52: cutia cuvantului se opreste inaintea ei
    eyebrow.ZIndex = 13

    objText = Widgets.Label(objPill, "", Theme.TEXT.small, Theme.COLOR.onDark, "strong")
    objText.Position = UDim2.fromOffset(Theme.SPACE.md + 52, 4)
    objText.Size = UDim2.fromOffset(OBJ_W - Theme.SPACE.md * 2 - 52, 18)
    objText.TextTruncate = Enum.TextTruncate.AtEnd
    objText.ZIndex = 13

    -- [D51] PASUL: cum si unde, acum. Quest-ul spune ce; randul asta spune ce faci in secunda asta,
    -- exact textul de pe sageata din lume.
    objStep = Widgets.Label(objPill, "", Theme.TEXT.small, Theme.COLOR.gold, "strong")
    objStep.Position = UDim2.fromOffset(Theme.SPACE.md, 26)
    objStep.Size = UDim2.fromOffset(OBJ_W - Theme.SPACE.md * 2, 18)
    objStep.TextTruncate = Enum.TextTruncate.AtEnd
    objStep.ZIndex = 13
    objStep.Visible = false

    objTrack, objFill =
        Widgets.Bar(objPill, OBJ_W - Theme.SPACE.md * 2 - 86, 8, Theme.COLOR.gold, 13)
    objTrack.Position = UDim2.fromOffset(Theme.SPACE.md, OBJ_H - 20)

    objNeed = Widgets.Label(objPill, "", Theme.TEXT.tiny, Theme.COLOR.onDarkSoft, "body")
    objNeed.Position = UDim2.fromOffset(OBJ_W - Theme.SPACE.md - 80, OBJ_H - 26)
    objNeed.Size = UDim2.fromOffset(80, 16)
    objNeed.TextXAlignment = Enum.TextXAlignment.Right
    objNeed.ZIndex = 13

    -- bulina rosie cu cate recompense asteapta. Sta pe coltul liniei, nu langa ea: pe coltul unui
    -- lucru pe care il poti apasa, o bulina inseamna "aici ai ceva de luat" fara niciun cuvant.
    objBadge = Instance.new("Frame")
    objBadge.Name = "Badge"
    objBadge.AnchorPoint = Vector2.new(0.5, 0.5)
    objBadge.Position = UDim2.fromScale(1, 0)
    objBadge.Size = UDim2.fromOffset(26, 26)
    objBadge.BackgroundColor3 = Theme.COLOR.bad
    objBadge.BorderSizePixel = 0
    objBadge.Visible = false
    objBadge.ZIndex = 14
    objBadge.Parent = objPill
    if Assets.has(Assets.ui.badge) then
        local badgeImg = Instance.new("ImageLabel")
        badgeImg.Name = "BadgeArt"
        badgeImg.BackgroundTransparency = 1
        badgeImg.Image = Assets.url(Assets.ui.badge)
        badgeImg.ResampleMode = Enum.ResamplerMode.Pixelated
        badgeImg.Size = UDim2.fromScale(1, 1)
        badgeImg.ZIndex = 14
        badgeImg.Parent = objBadge
        objBadge.BackgroundTransparency = 1
    else
        local badgeCorner = Instance.new("UICorner")
        badgeCorner.CornerRadius = UDim.new(1, 0)
        badgeCorner.Parent = objBadge
    end
    objBadgeLabel = Widgets.Label(objBadge, "0", Theme.TEXT.tiny, Theme.COLOR.onDark, "display")
    objBadgeLabel.AnchorPoint = Vector2.new(0.5, 0.5)
    objBadgeLabel.Position = UDim2.fromScale(0.5, 0.5)
    objBadgeLabel.Size = UDim2.fromOffset(24, 18)
    objBadgeLabel.TextXAlignment = Enum.TextXAlignment.Center
    objBadgeLabel.ZIndex = 15

    objPill.Activated:Connect(function()
        local a, openAmbition = ambition, deps.OpenAmbition
        if questActive == nil and questClaimable == 0 and a ~= nil and openAmbition ~= nil then
            openAmbition(a)
            return
        end
        local onOpen = deps.OpenQuests
        if onOpen ~= nil then
            onOpen()
        end
    end)
    rateValue.ZIndex = 13
    Theme.punch(rateValue, 2)
    rateTicker = newTicker(rateValue, function(n: number): string
        return `+{TycoonMath.formatRate(n)}/s`
    end)

    -- traista: cat mai poti duce inainte sa trebuiasca sa mergi la debarcader. Se incalzeste
    -- si se aprinde rosu cand se umple -- semnalul de "du-te si vinde" [DECIZII D40, D43]. La
    -- dreapta grupului monede+rata, centrata pe inaltimea lui [F2 spec Agent U pct.3].
    sackChip, sackValue = Widgets.Chip(deps.HudGui, "capacity", 12, "Sack")
    sackChip:SetAttribute("GuideBlocker", true) -- [verificatorii A0, k12]
    -- [D63] pe randul de sus, la aceeasi inaltime cu monedele si perlele (era mai inalt si cobora intre randuri)
    sackChip.Position = UDim2.fromOffset(GRID.sack.x, GRID.sack.y)
    sackChip.Size = UDim2.fromOffset(GRID.sack.w, GRID.sack.h)

    -- Mesajele scurte stau in TREIMEA DE SUS, centrat, si urca stingandu-se -- pozitia clasica
    -- de "Not enough gold!" din jocurile mobile de constructie.
    toastLabel = Widgets.PlateLabel(deps.HudGui, "", Theme.TEXT.heading, "display")
    toastLabel.Name = "Toast"
    toastLabel.AnchorPoint = Vector2.new(0.5, 0.5)
    toastLabel.Position = TOAST_HOME
    toastLabel.AutomaticSize = Enum.AutomaticSize.XY -- pastila se strange pe mesaje scurte
    toastLabel.Size = UDim2.fromOffset(0, 46)
    toastLabel.TextXAlignment = Enum.TextXAlignment.Center
    toastLabel.TextWrapped = true -- [F1 5.5] mesajele lungi (gasirea cu nume) trec pe doua randuri
    toastLabel.TextColor3 = Theme.COLOR.gold
    toastLabel.BackgroundTransparency = 0.2
    toastLabel.Visible = false
    toastLabel.ZIndex = 16
    Theme.punch(toastLabel)
    -- Plafon de latime: fara el, un mesaj lung ar iesi din ecranul ingust al unui telefon pe
    -- verticala (P6, telefon intai) -- AutomaticSize creste apoi pe inaltime cand da de plafon.
    local toastConstraint = Instance.new("UISizeConstraint")
    toastConstraint.MaxSize = Vector2.new(480, 10000)
    toastConstraint.Parent = toastLabel

    -- cartonasul de la apropiere: un singur exemplar, fix jos-centru, ascuns pana la primul pad
    -- "available" din raza [F3 spec item 5]. Randuri manuale (nu AutomaticSize + UIListLayout): la
    -- marime FIXA, un cursor `y` calculat in Luau e usor de verificat fara Studio, si nu se misca
    -- niciodata cand un pad n-are `note` -- randul ramane, doar gol.
    approachCard = Instance.new("Frame")
    approachCard.Name = "ApproachCard"
    approachCard.AnchorPoint = Vector2.new(0.5, 1)
    -- marginea de jos e ocupata de joystick si de butonul de actiune, iar in Studio bara de
    -- comenzi mai taie din ecran: cartonasul sta mai sus, ca sa se vada intreg [vazut 2026-09-12]
    approachCard.Position = UDim2.new(0.5, 0, 1, -APPROACH_BOTTOM_MARGIN)
    approachCard.Size = UDim2.fromOffset(APPROACH_W, APPROACH_H)
    approachCard.Visible = false
    approachCard.ZIndex = 9
    approachCard.Parent = deps.HudGui
    if Assets.has(Assets.tycoon.card) then
        Widgets.NineSlice(approachCard, Assets.tycoon.card, Assets.UI_SLICE.card, 9)
    else
        approachCard.BackgroundColor3 = Theme.COLOR.parchment
        approachCard.BackgroundTransparency = 0
        local cardCorner = Instance.new("UICorner")
        cardCorner.CornerRadius = UDim.new(0, 10)
        cardCorner.Parent = approachCard
        local cardStroke = Instance.new("UIStroke")
        cardStroke.Color = Theme.COLOR.woodDark
        cardStroke.Thickness = 3
        cardStroke.Parent = approachCard
    end
    Theme.shadow(approachCard, 14, 0.5)

    local approachContent = Instance.new("Frame")
    approachContent.Name = "Content"
    approachContent.BackgroundTransparency = 1
    -- Rama cartonasului e un sprite cu 9 felii: coltul ei netintins are 10px de sprite, adica ~30
    -- pe ecran. Cu o margine de doar 12, textul intra SUB rama si se taie ("Your first net" se
    -- vedea "our first net") [vazut in Studio, 2026-09-12]. Marginea trebuie sa depaseasca rama.
    local INSET_X, INSET_Y = APPROACH_INSET_X, APPROACH_INSET_Y
    approachContent.Position = UDim2.fromOffset(INSET_X, INSET_Y)
    approachContent.Size = UDim2.new(1, -INSET_X * 2, 1, -INSET_Y * 2)
    approachContent.ZIndex = 10
    approachContent.Parent = approachCard
    local contentW = APPROACH_W - INSET_X * 2
    -- doua coloane, latimi fixe (numere curate, nu fractii). [D73] Stanga 140, nu 180: tine doar „+X/s” (cel mult ~85 px
    -- in fontul de pixeli) si pretul; nota din dreapta (Nunito 13) avea 200 px, iar „Copper reaches the Market on its
    -- own” (218) sau nota Mill Bell (221) se taiau la capat
    local leftW, rightW = APPROACH_LEFT_W, contentW - APPROACH_LEFT_W

    -- Randurile, de sus in jos. `y` e in coordonatele continutului (380 lat, 164 inalt).
    -- PERGAMENT, deci cerneala si lemn -- auriul pe pergament are contrast 1.9:1 si nu se citeste.
    approachEyebrow = Widgets.Label(
        approachContent,
        Strings.PAD_EYEBROW,
        Theme.TEXT.tiny,
        Theme.COLOR.wood,
        "strong"
    )
    approachEyebrow.Position = UDim2.fromOffset(0, 0)
    approachEyebrow.Size = UDim2.fromOffset(contentW, 14)

    approachName =
        Widgets.Label(approachContent, "", Theme.TEXT.heading, Theme.COLOR.ink, "display")
    approachName.Position = UDim2.fromOffset(0, 14)
    approachName.Size = UDim2.fromOffset(contentW, 24)
    approachName.TextTruncate = Enum.TextTruncate.AtEnd

    -- CE e platforma asta -- vine direct din config (blurb), niciodata inventat aici [F2 task]
    approachBlurb =
        Widgets.Label(approachContent, "", Theme.TEXT.small, Theme.COLOR.inkSoft, "body")
    approachBlurb.Position = UDim2.fromOffset(0, 38)
    approachBlurb.Size = UDim2.fromOffset(contentW, 18)
    approachBlurb.TextTruncate = Enum.TextTruncate.AtEnd

    -- venitul exact (stanga) si efectul care NU se vede in venit (dreapta, doar cand pad-ul are
    -- unul) -- pe acelasi rand, ca marimea cartonasului sa ramana FIXA indiferent de continut
    approachDelta = Widgets.Label(approachContent, "", Theme.TEXT.small, Theme.COLOR.gold, "strong")
    approachDelta.Position = UDim2.fromOffset(0, 60)
    approachDelta.Size = UDim2.fromOffset(leftW, 20)

    approachNote = Widgets.Label(approachContent, "", Theme.TEXT.tiny, Theme.COLOR.inkSoft, "body")
    approachNote.AnchorPoint = Vector2.new(1, 0)
    approachNote.Position = UDim2.new(1, 0, 0, 62)
    approachNote.Size = UDim2.fromOffset(rightW, 18)
    approachNote.TextXAlignment = Enum.TextXAlignment.Right
    approachNote.TextTruncate = Enum.TextTruncate.AtEnd

    approachCoin = Widgets.CoinIcon(approachContent, 18, approachContent.ZIndex + 1)
    approachCoin.Position = UDim2.fromOffset(0, 86)

    approachPrice =
        Widgets.Label(approachContent, "", Theme.TEXT.small, Theme.COLOR.wood, "display")
    approachPrice.Position = UDim2.fromOffset(24, 84)
    approachPrice.Size = UDim2.fromOffset(leftW - 24, 22)

    -- Cat ai si cat iti ramane: "343 → 330 left". Owner-ul a cerut sa se vada CAT cheltui.
    approachSpend =
        Widgets.Label(approachContent, "", Theme.TEXT.small, Theme.COLOR.inkSoft, "strong")
    approachSpend.AnchorPoint = Vector2.new(1, 0)
    approachSpend.Position = UDim2.new(1, 0, 0, 86)
    approachSpend.Size = UDim2.fromOffset(rightW, 20)
    approachSpend.TextXAlignment = Enum.TextXAlignment.Right

    -- Butonul. Cumpararea NU se mai intampla calcand pe obiect: se intampla aici, cu tasta E sau
    -- apasand obiectul -- dar numai cat cartonasul asta e ridicat pentru el.
    approachBuy = Widgets.Button(approachContent, {
        text = "",
        icon = "coin",
        width = contentW,
        height = 44,
        z = approachContent.ZIndex + 1,
        onClick = function()
            if approachCanBuy and approachBuyFn ~= nil then
                (approachBuyFn :: () -> ())()
            end
        end,
    })
    approachBuy.Position = UDim2.fromOffset(0, 114)

    local showTouch = UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled

    -- JOYSTICK, nu patru butoane. Cele patru pastrate de 112 px stateau imprastiate peste lume
    -- si peste cladiri, mancau o treime din ecranul de telefon si dadeau doar 8 directii.
    -- Un joystick sta intr-un colt, da directie analogica si nu acopera nimic din joc.
    local base = Instance.new("Frame")
    base.Name = "MoveStick"
    base.AnchorPoint = Vector2.new(0, 1)
    base.Position = UDim2.new(0, STICK_MARGIN, 1, -STICK_MARGIN)
    base.Size = UDim2.fromOffset(STICK_BASE, STICK_BASE)
    base.BackgroundColor3 = Theme.COLOR.plate
    base.BackgroundTransparency = 0.55
    base.ZIndex = 10
    base.Visible = showTouch
    base:SetAttribute("GuideBlocker", true) -- [verificatorii A0, k12] doar cat se vede (pe telefon)
    base.Parent = deps.HudGui
    local baseRound = Instance.new("UICorner")
    baseRound.CornerRadius = UDim.new(1, 0)
    baseRound.Parent = base
    local baseEdge = Instance.new("UIStroke")
    baseEdge.Color = Theme.COLOR.onDarkSoft
    baseEdge.Thickness = 2
    baseEdge.Transparency = 0.5
    baseEdge.Parent = base

    local knob = Instance.new("Frame")
    knob.Name = "Knob"
    knob.AnchorPoint = Vector2.new(0.5, 0.5)
    knob.Position = UDim2.fromScale(0.5, 0.5)
    knob.Size = UDim2.fromOffset(STICK_KNOB, STICK_KNOB)
    knob.BackgroundColor3 = Theme.COLOR.parchment
    knob.BackgroundTransparency = 0.15
    knob.ZIndex = 11
    knob.Parent = base
    local knobRound = Instance.new("UICorner")
    knobRound.CornerRadius = UDim.new(1, 0)
    knobRound.Parent = knob

    -- Deplasarea se masoara fata de PUNCTUL IN CARE AI ATINS, nu fata de centrul desenat.
    -- Asa nu trebuie sa nimeresti mijlocul cu degetul, si scap si de nepotrivirea dintre
    -- coordonatele de input si AbsolutePosition sub decupajul de sus al platformei.
    local active: InputObject? = nil
    local origin = Vector2.zero

    local function release()
        active = nil
        knob.Position = UDim2.fromScale(0.5, 0.5)
        deps.SetStick(0, 0)
    end

    local function drive(at: Vector2)
        local delta = at - origin
        local len = delta.Magnitude
        local clamped = if len > STICK_RADIUS then delta.Unit * STICK_RADIUS else delta
        knob.Position = UDim2.new(0.5, clamped.X, 0.5, clamped.Y)
        if len < STICK_DEADZONE then
            deps.SetStick(0, 0) -- zona moarta: degetul asezat pe ecran nu inseamna "mergi"
            return
        end
        deps.SetStick(clamped.X / STICK_RADIUS, clamped.Y / STICK_RADIUS)
    end

    base.InputBegan:Connect(function(input: InputObject)
        if
            input.UserInputType == Enum.UserInputType.Touch
            or input.UserInputType == Enum.UserInputType.MouseButton1
        then
            active = input
            origin = Vector2.new(input.Position.X, input.Position.Y)
            drive(origin)
        end
    end)
    UserInputService.InputChanged:Connect(function(input: InputObject)
        if input == active then
            drive(Vector2.new(input.Position.X, input.Position.Y))
        end
    end)
    UserInputService.InputEnded:Connect(function(input: InputObject)
        if input == active then
            release()
        end
    end)

    local action = touchButton(deps.HudGui, "", deps.Interact, function() end)
    action.Name = "ActionButton"
    action:SetAttribute("GuideBlocker", true) -- [verificatorii A0, k12]
    -- [D59] Butonul se si TINE apasat (bara undiței). Degetul care a apasat e urmarit pana se ridica oriunde pe ecran:
    -- InputEnded-ul butonului nu vine daca degetul aluneca de pe el, iar undita ar ramane "tinuta" singura.
    action.InputBegan:Connect(function(input: InputObject)
        if
            input.UserInputType == Enum.UserInputType.Touch
            or input.UserInputType == Enum.UserInputType.MouseButton1
        then
            actionHeldBy = input
        end
    end)
    UserInputService.InputEnded:Connect(function(input: InputObject)
        if input == actionHeldBy then
            actionHeldBy = nil
        end
    end)
    action.AnchorPoint = Vector2.new(1, 1)
    action.Position = UDim2.new(1, -STICK_MARGIN, 1, -STICK_MARGIN)
    action.Size = UDim2.fromOffset(ACTION_SIZE, ACTION_SIZE)
    action.BackgroundColor3 = Theme.COLOR.gold
    action.BackgroundTransparency = 0.1
    action.Visible = showTouch
    local actionRound = action:FindFirstChildOfClass("UICorner")
    if actionRound ~= nil then
        actionRound.CornerRadius = UDim.new(1, 0) -- rotund, nu patrat cu colturi taiate
    end
    local actionIcon = Widgets.Icon(action, "hammer", 40)
    if actionIcon ~= nil then
        actionIcon.AnchorPoint = Vector2.new(0.5, 0.5)
        actionIcon.Position = UDim2.fromScale(0.5, 0.5)
        actionIcon.ZIndex = 12
    end

    local frames, elapsed = 0, 0
    RunService.Heartbeat:Connect(function(dt: number)
        frames += 1
        elapsed += dt
        if elapsed >= 0.5 then
            fps = math.floor(frames / elapsed + 0.5)
            frames, elapsed = 0, 0
        end
        -- Butoanele de pe ecran stau sub panouri: pe telefon, cu panoul deschis, jucatorul
        -- apasa panoul cand vrea sa mearga. Le ascundem cat timp e ceva deschis.
        if not showTouch then
            return
        end
        local blocked = deps.PanelsOpen ~= nil and (deps.PanelsOpen :: () -> boolean)()
        for _, b in touchButtons do
            if b.Visible == blocked then
                b.Visible = not blocked
            end
        end
        if base.Visible == blocked then
            base.Visible = not blocked
            if blocked then
                release() -- altfel personajul ramane mergand in directia in care era degetul
            end
        end
    end)
end

-- Diagnosticul se citeste din consola de dezvoltare, nu se afiseaza peste lume
function HUDController.Perf(): number
    return fps
end

-- floor: monedele curg fractionar pe server, dar jucatorul numara in bucati [F0 spec 4.2].
-- Urca lin spre valoarea noua; o cheltuiala (scadere) se vede imediat [F2 spec Agent U pct.3].
function HUDController.SetCoins(coins: number)
    if coinTicker ~= nil then
        coinTicker(coins)
    end
end

-- Punctul de sosire pentru monedele care zboara de la debarcader [F1 spec 5.3, W4]. Centrul
-- pictogramei de moneda, in coordonate HUD (aceleasi unitati offset ca WorldToHud) -- pastila +
-- inset-ul fix al randului dinauntru, ca JuiceController sa nu aiba nevoie de Frame-uri.
function HUDController.CoinAnchor(): (number, number)
    if coinPill == nil then
        return 0, 0
    end
    return coinPill.Position.X.Offset + Theme.SPACE.md + 15,
        coinPill.Position.Y.Offset + COIN_PILL_H / 2
end

-- Punctul de sosire pentru eticheta "+delta/s" zburatoare la o cumparare [F2 spec Agent U pct.5] --
-- centrul pastilei de rata, in aceleasi coordonate ca CoinAnchor de mai sus.
function HUDController.RateAnchor(): (number, number)
    if ratePill == nil then
        return 0, 0
    end
    return ratePill.Position.X.Offset + RATE_PILL_W / 2,
        ratePill.Position.Y.Offset + RATE_PILL_H / 2
end

-- Contorul "sare" cand monedele zburatoare ajung la el [F1 spec 5.3, O2] -- acelasi truc UIScale
-- ca pulsul traistei pline mai jos.
function HUDController.PulseCoins()
    if coinValue == nil then
        return
    end
    local scale = coinValue:FindFirstChildOfClass("UIScale") or Instance.new("UIScale")
    scale.Parent = coinValue
    scale.Scale = 1.25
    TweenService:Create(
        scale,
        TweenInfo.new(0.3, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
        { Scale = 1 }
    ):Play()
end

-- [D59] Butonul de actiune de pe ecran e tinut apasat acum (undita).
function HUDController.IsActionHeld(): boolean
    return actionHeldBy ~= nil
end

-- [D59] Unde aterizeaza perlele care zboara (de la undita, din rau, de la roata): pictograma perlei din pastila ei.
function HUDController.PearlAnchor(): (number, number)
    if pearlPill == nil then
        return 0, 0
    end
    return pearlPill.Position.X.Offset + Theme.SPACE.md + 11,
        pearlPill.Position.Y.Offset + COIN_PILL_H / 2
end

function HUDController.PulsePearls()
    if pearlValue == nil then
        return
    end
    local scale = pearlValue:FindFirstChildOfClass("UIScale") or Instance.new("UIScale")
    scale.Parent = pearlValue
    scale.Scale = 1.3
    TweenService:Create(
        scale,
        TweenInfo.new(0.3, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
        { Scale = 1 }
    ):Play()
end

-- Acelasi puls, pentru rata -- aterizarea etichetei "+delta/s" la o cumparare [F2 spec Agent U pct.5].
function HUDController.PulseRate()
    if rateValue == nil then
        return
    end
    local scale = rateValue:FindFirstChildOfClass("UIScale") or Instance.new("UIScale")
    scale.Parent = rateValue
    scale.Scale = 1.25
    TweenService:Create(
        scale,
        TweenInfo.new(0.3, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
        { Scale = 1 }
    ):Play()
end

-- Aceeasi regula ca la monede: urca lin, niciodata brusc [F2 spec Agent U pct.3].
function HUDController.SetIncome(perSec: number)
    if rateTicker ~= nil then
        rateTicker(perSec)
    end
end

-- Se incalzeste cu cat se apropie de plin, si devine rosie cand chiar e plina -- semnalul care
-- spune "du-te la debarcader" inainte ca o colectare sa fie refuzata in tacere [D40, D43].
function HUDController.SetSack(count: number, capacity: number)
    if sackValue == nil then
        return
    end
    sackValue.Text = `{count}/{capacity}`
    local full = capacity > 0 and count >= capacity
    local warm = capacity > 0 and count >= capacity * 0.75
    local color = if full
        then Theme.COLOR.bad
        elseif warm then Theme.COLOR.warn
        else Theme.COLOR.onDark
    if sackValue.TextColor3 ~= color then
        sackValue.TextColor3 = color
    end
    -- Un singur puls, chiar in clipa in care se umple -- nu la fiecare stare de TycoonState cat
    -- ramane plina. UIScale + Back/Out, acelasi truc ca SceneArt.Flourish (marime mare instant,
    -- revine tweenuit): mai simplu decat sa refacem manual Size dus-intors.
    if full and not lastSackFull then
        local scale = sackChip:FindFirstChildOfClass("UIScale") or Instance.new("UIScale")
        scale.Parent = sackChip
        scale.Scale = 1.18
        TweenService:Create(
            scale,
            TweenInfo.new(0.35, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
            { Scale = 1 }
        ):Play()
    end
    lastSackFull = full
end

-- `color`: implicit auriu (D40/D43 -- mesajele scurte sunt mereu vizibile). Optional, ca sa poata
-- purta culoarea tierului la o gasire cu nume [F1 spec 5.5, L4] fara sa schimbe apelantii vechi.
function HUDController.SetToastFloor(floor: () -> number?)
    toastFloor = floor
end

-- Unde sta toast-ul acum: in treimea de sus, sau sub bannerul de pe ecran (cel cu Look sta 7 s).
local function toastHome(): UDim2
    local floorOf = toastFloor
    local bottom = if floorOf ~= nil then floorOf() else nil
    local canvas = toastLabel.Parent
    if bottom == nil or canvas == nil or not canvas:IsA("GuiObject") then
        return TOAST_HOME
    end
    local frame = canvas :: GuiObject
    local units = frame.Size.Y.Offset
    local scale = if units > 0 then frame.AbsoluteSize.Y / units else 1
    local homeY = frame.AbsolutePosition.Y + TOAST_HOME.Y.Scale * frame.AbsoluteSize.Y
    local half = math.max(toastLabel.AbsoluteSize.Y, 46 * scale) / 2
    local need = bottom + 8 * scale + half
    if homeY >= need or scale <= 0 then
        return TOAST_HOME
    end
    return TOAST_HOME + UDim2.fromOffset(0, (need - homeY) / scale)
end

function HUDController.Toast(message: string, color: Color3?)
    toastToken += 1
    local token = toastToken
    toastLabel.Text = message
    local home = toastHome()
    toastLabel.Position = home
    toastLabel.TextTransparency = 0
    toastLabel.TextColor3 = color or Theme.COLOR.gold
    toastLabel.BackgroundTransparency = 0.2
    toastLabel.Visible = true
    -- mica sarita la intrare: mesajul se face observat fara sa ceara o apasare. UIScale, nu Size --
    -- AutomaticSize.XY (mai jos) calculeaza deja marimea din text, ca mesajele lungi sa treaca pe
    -- doua randuri in loc sa iasa din ecran pe telefon [F1 spec 5.5, P6].
    local pop = toastLabel:FindFirstChildOfClass("UIScale") or Instance.new("UIScale")
    pop.Parent = toastLabel
    pop.Scale = 0.85
    TweenService:Create(
        pop,
        TweenInfo.new(0.22, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
        { Scale = 1 }
    ):Play()
    task.delay(2.6, function()
        if toastToken ~= token then
            return
        end
        -- urca si se stinge, nu dispare brusc: ochiul urmareste miscarea si citeste pana la capat
        local away = TweenInfo.new(0.55, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
        TweenService:Create(toastLabel, away, {
            Position = home - UDim2.fromOffset(0, 44),
            TextTransparency = 1,
            BackgroundTransparency = 1,
        }):Play()
        task.delay(0.6, function()
            if toastToken == token then
                toastLabel.Visible = false
            end
        end)
    end)
end

-- [D63] verbul de pe buton e cel din quest-ul platformei ("Cast", "Hire", "Build", "Get", "Ring"), nu "Buy" la toate
local function padVerb(pad: TycoonConfig.Pad): string
    return TycoonConfig.verbOf(pad)
end

local function formatPadPrice(pad: TycoonConfig.Pad): string
    return if pad.price == 0 then "FREE" else TycoonMath.formatNumber(pad.price)
end

-- Impins de PadController cand platforma cea mai apropiata (sub 220px) sau afordabilitatea ei se
-- schimba [F3 spec item 5]. Fix jos-centru: nu mai are nevoie sa stie UNDE e platforma in lume, doar
-- CE sa arate -- de-aia PadController trimite `pad` direct, nu o pozitie de ecran.
-- Obiectivul curent, scris o singura data cand se schimba (textul) si actualizat continuu doar
-- unde conteaza (bara si "N more"). `goal` vine din GuideMath -- acelasi din care traieste si
-- sageata, deci cele doua nu se pot contrazice niciodata.
-- Venitul pasiv. Zero inseamna "lantul nu merge fara tine", deci pastila nici nu se arata:
-- o pastila care scrie 0.0/s ar fi un reprosf permanent, nu o informatie.
function HUDController.SetPearls(n: number)
    if pearlValue ~= nil then
        pearlValue.Text = TycoonMath.formatNumber(n)
    end
end

function HUDController.SetIdle(perSec: number)
    if idlePill == nil then
        return
    end
    local on = perSec > 0
    idlePill.Visible = on
    if on then
        idleValue.Text = `{TycoonMath.formatRate(perSec)}/s`
    end
end

-- Quest-ul activ si cate recompense asteapta. Cand exista quest, EL scrie pe linie: e acelasi
-- obiectiv pe care il arata si sageata (GuideMath regula 0), deci nu se pot contrazice.
-- Dreptunghiul liniei de obiectiv, in coordonate de ecran. Tutorialul are nevoie de el ca sa taie
-- gaura reflectorului EXACT peste elementul real -- nu peste niste cifre scrise de mana, care s-ar
-- dezalinia la alta rezolutie.
function HUDController.ObjectiveRect(): (number, number, number, number)
    if objPill == nil then
        return 0, 0, 0, 0
    end
    local p, sz = objPill.AbsolutePosition, objPill.AbsoluteSize
    return p.X, p.Y, sz.X, sz.Y
end

function HUDController.SetQuest(
    active: { text: string, progress: number, goal: number, counter: string }?,
    claimable: number
)
    if objPill == nil then
        return
    end
    questActive = active
    questClaimable = claimable
    objBadge.Visible = claimable > 0
    if claimable > 0 then
        objBadgeLabel.Text = tostring(claimable)
    end
    if active ~= nil then
        objPill.Visible = true
        objText.Text = active.text
        objTrack.Visible = true
        objFill.Size =
            UDim2.fromScale(math.clamp(active.progress / math.max(1, active.goal), 0, 1), 1)
        objNeed.Text = active.counter -- [D70, pasul k5] acelasi contor ca in lista ("966B/1T" la venit)
        objNeed.TextColor3 = if active.progress >= active.goal
            then Theme.COLOR.good
            else Theme.COLOR.onDarkSoft
    end
end

-- [D51] Pasul ales de GuideMath, dupa ce SetQuest a scris quest-ul. Cu quest: randul al doilea spune
-- pasul, iar cand pasul are un pret (o cumparare sau un nivel), bara si cifra din dreapta masoara
-- monedele, nu 0/1 -- "Cast a second net · 2 more". Fara quest: linia scrie chiar pasul, pe un rand.
-- Cheamat de Overlay la fiecare stare, dupa GuideController.Apply.
-- [D63] Tinta fara sfarsit (AmbitionMath), data de Overlay INAINTE de SetStep. Se vede doar cand linia ar fi disparut:
-- fara quest activ si cu ghidajul tacut. Pana acum, dupa ultimul capitol HUD-ul nu mai spunea nimic despre "ce urmeaza".
function HUDController.SetAmbition(a: AmbitionMath.Ambition?)
    ambition = a
end

function HUDController.SetStep(goal: GuideMath.Goal?, coinsNow: number)
    if objPill == nil then
        return -- o stare sosita inaintea HUD-ului; urmatoarea o gaseste construit
    end
    local quest = questActive
    local stepText: string? = nil
    if quest ~= nil then
        if goal ~= nil and goal.text ~= quest.text then
            stepText = goal.text
        end
    elseif goal ~= nil then
        objPill.Visible = true
        objText.Text = goal.text
        objTrack.Visible = false
        objNeed.Text = ""
    elseif ambition ~= nil then
        local a = ambition :: AmbitionMath.Ambition
        objPill.Visible = true
        objText.Text = Strings.ambitionText(a.what, a.name, a.target)
        objStep.Visible = false
        objPill.Size = UDim2.fromOffset(OBJ_W, OBJ_H)
        objTrack.Position = UDim2.fromOffset(Theme.SPACE.md, OBJ_H - 20)
        objNeed.Position = UDim2.fromOffset(OBJ_W - Theme.SPACE.md - 80, OBJ_H - 26)
        objTrack.Visible = true
        objFill.Size = UDim2.fromScale(math.clamp(a.progress / math.max(1, a.goal), 0, 1), 1)
        objNeed.Text = `{a.level}/{a.target}`
        objNeed.TextColor3 = Theme.COLOR.onDarkSoft
        return
    else
        objPill.Visible = false
        return
    end
    objStep.Text = stepText or ""
    objStep.Visible = stepText ~= nil
    local h = if stepText ~= nil then OBJ_H_STEP else OBJ_H
    objPill.Size = UDim2.fromOffset(OBJ_W, h)
    objTrack.Position = UDim2.fromOffset(Theme.SPACE.md, h - 20)
    objNeed.Position = UDim2.fromOffset(OBJ_W - Theme.SPACE.md - 80, h - 26)

    local price = if goal ~= nil then goal.price else nil
    if price == nil or price <= 0 then
        return -- bara ramane a quest-ului (0/1, 7/12), scrisa de SetQuest
    end
    objTrack.Visible = true
    objFill.Size = UDim2.fromScale(math.clamp(coinsNow / price, 0, 1), 1)
    local missing = math.max(0, math.ceil(price - coinsNow))
    objNeed.Text = if missing > 0
        then `{TycoonMath.formatNumberUp(missing)} more`
        else Strings.OBJ_READY
    objNeed.TextColor3 = if missing > 0 then Theme.COLOR.onDarkSoft else Theme.COLOR.good
end

-- [D70, verificator] Descrierea platformei sta pe un singur rand. Textele din config sunt masurate sa incapa la marimea
-- lor (testul configuratiei, cu latimile Nunito); daca unul tot nu incape, se strange, nu se taie cu "…".
local function setBlurb(text: string)
    approachBlurb.Text = text
    approachBlurb.TextSize =
        Theme.fitSize(text, Theme.TEXT.small, "body", approachBlurb.Size.X.Offset)
end

function HUDController.ShowApproachCard(
    pad: TycoonConfig.Pad,
    deltaPerSec: number,
    affordable: boolean,
    noGainText: string?, -- [D63] ce scrie cartonasul cand platforma nu aduce nimic acum (il face PadController)
    coins: number
)
    local isNew = approachId ~= pad.id or approachRuin
    approachId = pad.id
    -- [D53] de pe o ruina, randurile cumpararii revin
    if approachRuin then
        approachRuin = false
        approachEyebrow.Text = Strings.PAD_EYEBROW
        approachDelta.Visible = true
        approachCoin.Visible = true
        approachPrice.Visible = true
        approachSpend.Visible = true
        Widgets.SetButtonIcon(approachBuy, true)
    end
    approachName.Text = pad.name
    setBlurb(pad.blurb)
    -- CARTONASUL NU MINTE. Cu lantul cu trei verigi, o platforma care nu apasa pe gatuire aduce
    -- exact zero -- si atunci scrie de ce, in loc sa arate "+0.0/s" ca si cum ar fi o cifra [D40].
    -- CAND SPUNE DE CE E ZERO, ARE NEVOIE DE TOT RANDUL. Mesajul e mai lung decat o cifra si
    -- intra peste nota din dreapta -- doua texte unul peste altul, exact ce nu trebuie.
    local noGain = deltaPerSec <= 0
    if noGain then
        local text = noGainText or Strings.stationNoEffect("nets")
        local width = APPROACH_W - APPROACH_INSET_X * 2
        approachDelta.Text = text
        approachDelta.TextSize = Theme.fitSize(text, Theme.TEXT.small, "strong", width)
        approachDelta.TextColor3 = Theme.COLOR.bad
        approachDelta.Size = UDim2.fromOffset(width, 20)
    else
        approachDelta.Text = `+{TycoonMath.formatRate(deltaPerSec)}/s`
        approachDelta.TextSize = Theme.TEXT.small -- fraza de mai sus a putut-o micsora
        approachDelta.TextColor3 = Theme.COLOR.good
        approachDelta.Size = UDim2.fromOffset(APPROACH_LEFT_W, 20)
    end
    approachNote.Visible = not noGain
    approachNote.Text = pad.note or ""
    approachPrice.Text = formatPadPrice(pad)
    approachPrice.TextColor3 = if affordable then Theme.COLOR.wood else Theme.COLOR.bad

    -- Trei stari ale butonului, fiecare spune exact ce se intampla daca apesi [D40]:
    -- gratis, platesti (cu cat ramai), sau inca nu ajung banii (si cati lipsesc).
    local keyHint = if UserInputService.KeyboardEnabled then " (E)" else ""
    local verb = padVerb(pad)
    if pad.price <= 0 then
        approachCanBuy = true
        approachSpend.Text = ""
        Widgets.SetButtonText(approachBuy, Strings.padTakeFree(verb) .. keyHint)
        Widgets.SetButtonTone(approachBuy, Theme.COLOR.gold)
    elseif affordable then
        approachCanBuy = true
        approachSpend.Text = Strings.padSpend(
            TycoonMath.formatNumber(coins),
            TycoonMath.formatNumber(coins - pad.price)
        )
        Widgets.SetButtonText(
            approachBuy,
            Strings.padBuyFor(verb, TycoonMath.formatNumber(pad.price)) .. keyHint
        )
        Widgets.SetButtonTone(approachBuy, Theme.COLOR.gold)
    else
        approachCanBuy = false
        approachSpend.Text = ""
        Widgets.SetButtonText(
            approachBuy,
            Strings.padNeedMore(TycoonMath.formatNumberUp(pad.price - coins))
        )
        -- stins, nu ascuns: se vede ca exista o actiune, doar ca nu e inca la indemana
        Widgets.SetButtonTone(approachBuy, Color3.fromRGB(150, 144, 136))
    end

    if isNew or not approachCard.Visible then
        approachCard.Visible = true
        -- un mic puls la intrare, ca aparitia sa se simta -- acelasi truc Back/Out ca restul HUD-ului
        local scale = approachCard:FindFirstChildOfClass("UIScale") or Instance.new("UIScale")
        scale.Parent = approachCard
        scale.Scale = 0.92
        TweenService:Create(scale, APPROACH_POP, { Scale = 1 }):Play()
    end
end

-- [D53] CARTONASUL UNEI RUINE: acelasi cadru, alt mod. Nu se cumpara nimic, deci randurile de venit, pret si
-- rest se ascund, iar butonul, stins si fara moneda, spune ce trebuie facut intai ("Hire a Hauler first").
-- Textul vine din TycoonMath.padBlocker, adica exact conditia pe care o verifica jocul [D40].
function HUDController.ShowRuinCard(pad: TycoonConfig.Pad, eyebrow: string, reason: string)
    local isNew = approachId ~= pad.id or not approachRuin
    approachId = pad.id
    approachRuin = true
    -- butonul stins tot raspunde: PadController.TryBuyFocused spune conditia ca toast [D43]
    approachCanBuy = true
    approachEyebrow.Text = eyebrow
    approachName.Text = pad.name
    setBlurb(pad.blurb)
    approachDelta.Visible = false
    approachNote.Visible = false
    approachCoin.Visible = false
    approachPrice.Visible = false
    approachSpend.Visible = false
    Widgets.SetButtonText(approachBuy, reason)
    Widgets.SetButtonIcon(approachBuy, false)
    Widgets.SetButtonTone(approachBuy, Color3.fromRGB(150, 144, 136))
    if isNew or not approachCard.Visible then
        approachCard.Visible = true
        local scale = approachCard:FindFirstChildOfClass("UIScale") or Instance.new("UIScale")
        scale.Parent = approachCard
        scale.Scale = 0.92
        TweenService:Create(scale, APPROACH_POP, { Scale = 1 }):Play()
    end
end

-- Ce face butonul cartonasului. Il da PadController, o singura data: el stie ce platforma e tinta
-- si trimite cererea; HUD-ul doar deseneaza [F3 spec item 5 -- continutul aici, decizia acolo].
function HUDController.SetApproachBuy(fn: () -> ())
    approachBuyFn = fn
end

-- "hides when you walk away" [F2 spec Agent U pct.2] -- imediat, fara animatie de iesire.
function HUDController.HideApproachCard()
    approachId = nil
    if approachCard ~= nil then
        approachCard.Visible = false
    end
end

return HUDController
