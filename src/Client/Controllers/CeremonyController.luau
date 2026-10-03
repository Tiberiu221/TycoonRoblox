--!strict
-- Ceremonia de clopot [F1 spec 5.4, C5]: 3 secunde, NE-BLOCANTA -- banner + rafala de monede.
-- Sunetul de clopot il porneste SoundController, agatat de acelasi PadBought (evitam sa-l sune
-- de doua ori). Generic pe orice platforma cu motiv "D" (clopot de sfarsit de era), desi in F1
-- doar Landing Bell e `live`: cand vine Era 2 clopotul de Moara merge fara sa se atinga fisierul.
--
-- F2: bannerul (showBanner) e acum refolosit si de PlayMoment, pentru momente D/F de-o data care
-- nu sunt clopote (prima vanzare etc.) [39]. "Panou modal" (F) se stinge singur ca oricare banner
-- D -- jocul nu-l blocheaza niciodata pe jucator sa apese ceva [CLAUDE.md, regula de baza], deci
-- n-avem un "pana la tap" adevarat aici.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")

local TycoonConfig = require(ReplicatedStorage.Shared.Config.TycoonConfig)
local WorldConfig = require(ReplicatedStorage.Shared.Config.WorldConfig)
local Strings = require(ReplicatedStorage.Shared.Config.Strings)
local JuiceController = require(script.Parent.JuiceController)
local Theme = require(script.Parent.Parent.UI.Theme)
local Widgets = require(script.Parent.Parent.UI.Widgets)

export type Deps = { HudGui: Frame }
-- [D70] Un buton pe banner ("Look (V)"): textul, tasta care il apasa si ce face. Bannerul cu buton sta mai mult (ACTION_SECONDS),
-- iar apasarea il stinge. `useful`, citit cand bannerul chiar apare: butonul se arata doar daca inca are rost (locul
-- privirii nu se vede de unde stai).
export type Action = { text: string, key: Enum.KeyCode?, run: () -> (), useful: (() -> boolean)? }
-- [2026-09-30] Ce insoteste un moment: `onShow`, chemat cand bannerul chiar apare (sunetul lui, ca sa nu sune inaintea
-- unui banner care asteapta la rand); `ready`, cat e fals momentul asteapta (anuntul cu Look asteapta sa inchizi meniul
-- din care ai cumparat: altfel iesea peste el, sau sub el).
export type Extras = { onShow: (() -> ())?, ready: (() -> boolean)? }

local CeremonyController = {}
local root: Frame
local titleLabel: TextLabel
local subtitleLabel: TextLabel
local actionButton: TextButton
local currentAction: Action? = nil
local hideToken = 0

local DURATION = 3.0 -- clopotele
local MOMENT_DURATION = 3.5 -- alte momente D/F, ceva mai lung: textul e de obicei mai lung
local FADE = 0.6
local WIDTH = 600
local MIN_HEIGHT = 130
local SIDE = 32 -- cat lasa textul din latimea bannerului (16 de fiecare parte)
local ACTION_H = 40
local ACTION_MIN_W = 180
local ACTION_SECONDS = 7 -- cu un buton de apasat: copilul citeste, apoi alege
-- [2026-09-30] Bannerul cu buton sta tot sub panouri: apare doar cu panourile inchise (`ready`), iar daca deschizi un
-- meniu cat e pe ecran, butonul pleaca (nu se apasa ceva acoperit, nici cu V).
local BASE_Z = 25
-- [2026-09-30] Un singur banner deodata, dar niciunul nu-l mai sterge pe altul abia aparut (bannerul treptei si cel al
-- pragului 10, al capitolului, al biletului din sticla): un moment venit cat bannerul de acum sta primele MIN_SHOWN
-- secunde (unul cu buton, ACTION_HOLD) asteapta la rand. Dupa atat, bannerul de acum poate fi inlocuit.
local MIN_SHOWN = 2.5
local ACTION_HOLD = 4
local READY_RETRY = 0.5
local busyUntil = 0
type Waiting = { show: () -> (), ready: (() -> boolean)? }
local waiting: { Waiting } = {}
local flushGen = 0 -- doar ultima programare a cozii conteaza
local schedule: (number) -> () -- mai jos, dupa flush
local currentReady: (() -> boolean)? = nil -- `ready` al bannerului cu buton de pe ecran
-- momentul de pe ecran, ca un clopot care il inlocuieste abia aparut sa-l poata pune inapoi la rand (fara sunet)
local currentItem: Waiting? = nil
-- stingerea bannerului de acum: oprita cand vine altul, altfel ii stingea textul abia aparut
local fades: { Tween } = {}

-- Un subtitlu lung se citeste mai greu decat unul de patru cuvinte: biletele din sticla [D59] au pana la 74 de litere,
-- iar 3.5 s ajung doar pentru ultimul rand pana sa se stinga.
local function readingExtra(subtitle: string): number
    return math.clamp(((utf8.len(subtitle) or #subtitle) - 40) * 0.06, 0, 2.5)
end

-- "Landing Bell" -> "The Landing is complete!"; pentru un nume care nu se termina in " Bell"
-- (ex. viitorul "The Charter") ramane doar numele -- nu invizibil, doar mai putin elegant. Folosit
-- doar cand nu exista o zona urmatoare cunoscuta (vezi zoneOpenText) -- adica azi, niciodata.
local function ceremonyTitle(pad: TycoonConfig.Pad): string
    -- [2026-09-30] numele cartierului, ca pe gard si pe cartonase ("The Wire Works", nu "The Works")
    local zone = TycoonConfig.eraName(pad.era)
    if zone ~= nil then
        return `{zone} is complete!`
    end
    local base = (pad.name:gsub(" Bell$", ""))
    return `The {base} is complete!`
end

-- Numele zonei ACESTEI ere (pentru bonusul "X pays Y% more"), din TycoonConfig.ZONES -- nu scris
-- de mana [D40]. nil pentru erele fara zona inca definita (3-4, doar in plan azi).
local function zoneNameFor(era: number): string?
    -- [D70, pasul k2] zona erei pe harta ei (Era 4 e Dam Town, la baraj)
    for _, z in TycoonConfig.zonesOf(WorldConfig.worldOfEra(era)) do
        if z.era == era then
            return z.name
        end
    end
    return nil
end

-- "The Mill is open": zona pe care clopotul asta TOCMAI a deschis-o, din TycoonConfig.ZONES --
-- era+1. nil la clopotul final (The Charter, era 4): nu mai e nimic de deschis dupa el.
-- [D65] Doar daca zona aia chiar are ce juca in ea (platforme `live`): la clopotul Morii bannerul scria "The Wire Works
-- is open", iar panoul de la gard "The Wire Works — coming soon" [D40; vazut cu sonda, 2026-09-19]. Atunci ramane
-- "The Mill is complete!".
local function zoneOpenText(pad: TycoonConfig.Pad): string?
    local nextZone = zoneNameFor(pad.era + 1)
    if nextZone == nil or not TycoonConfig.eraIsLive(pad.era + 1) then
        return nil
    end
    -- [D70] zona urmatoare e pe alta harta (Works Bell -> barajul): nu „se deschide” aici; ce urmeaza spune masa Dam Plans
    if WorldConfig.worldOfEra(pad.era + 1) ~= WorldConfig.worldOfEra(pad.era) then
        return nil
    end
    return Strings.eraZoneOpen(nextZone)
end

-- Bonusul se citeste direct din efectul "bells" al platformei -- nu se scrie de mana un procent
-- care s-ar putea dezalinia de TycoonConfig [CLAUDE.md: preturile/efectele nu se ghicesc].
local function bonusText(pad: TycoonConfig.Pad): string
    for _, e in pad.effects do
        if e.kind == "mul" and e.field == "bells" and e.factor ~= nil then
            local pct = math.floor((e.factor :: number - 1) * 100 + 0.5)
            if pad.era > 1 then
                return Strings.eraBellRungAll(pct) -- [D65] de la a doua era, clopotul inmulteste tot satul
            end
            local zone = zoneNameFor(pad.era) or (pad.name:gsub(" Bell$", ""))
            return Strings.eraBellRung(zone, pct)
        end
    end
    return "Every sale pays more now" -- rezerva: n-ar trebui sa se intample, niciun clopot de azi cade aici
end

-- [D70] Butonul bannerului (clic, atingere sau tasta lui): bannerul se stinge, apoi se face ce scrie pe buton.
local function runAction()
    local action = currentAction
    if action == nil or not root.Visible or not actionButton.Visible then
        return
    end
    CeremonyController.HideNow()
    action.run()
end

function CeremonyController.Init(deps: Deps)
    root = Instance.new("Frame")
    root.Name = "Ceremony"
    root.AnchorPoint = Vector2.new(0.5, 0)
    root.Position = UDim2.fromScale(0.5, 0.15)
    root.BackgroundColor3 = Theme.COLOR.plate
    root.BackgroundTransparency = 1
    root.Size = UDim2.fromOffset(WIDTH, MIN_HEIGHT)
    root.ZIndex = 25
    root.Visible = false
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 16)
    corner.Parent = root
    root.Parent = deps.HudGui

    titleLabel = Widgets.Label(root, "", Theme.TEXT.title + 6, Theme.COLOR.gold, "display")
    -- Centrat pe MIJLOCUL cutiei: cu AnchorPoint 0.5 si pozitia x = 0, textul se centra pe marginea
    -- din stanga si jumatate din el iesea din cutie [vazut in Studio la "First sale", 2026-09-13].
    titleLabel.AnchorPoint = Vector2.new(0.5, 0)
    titleLabel.Position = UDim2.new(0.5, 0, 0, 22)
    titleLabel.Size = UDim2.new(1, -SIDE, 0, 46)
    titleLabel.TextXAlignment = Enum.TextXAlignment.Center
    titleLabel.TextWrapped = true
    titleLabel.ZIndex = 26
    Theme.punch(titleLabel, 3)

    subtitleLabel = Widgets.Label(root, "", Theme.TEXT.heading, Theme.COLOR.good, "strong")
    subtitleLabel.AnchorPoint = Vector2.new(0.5, 0)
    subtitleLabel.Position = UDim2.new(0.5, 0, 0, 78)
    subtitleLabel.Size = UDim2.new(1, -SIDE, 0, 34)
    subtitleLabel.TextXAlignment = Enum.TextXAlignment.Center
    subtitleLabel.TextWrapped = true
    subtitleLabel.ZIndex = 26
    Theme.punch(subtitleLabel, 2)

    actionButton = Widgets.Button(root, {
        text = "",
        width = ACTION_MIN_W,
        height = ACTION_H,
        z = 27,
        onClick = function()
            runAction()
        end,
    })
    actionButton.Name = "Action"
    actionButton.AnchorPoint = Vector2.new(0.5, 0)
    actionButton.Visible = false
    Widgets.SetButtonTone(actionButton, Theme.COLOR.gold)
    UserInputService.InputBegan:Connect(function(input: InputObject, processed: boolean)
        local action = currentAction
        if
            not processed
            and action ~= nil
            and action.key ~= nil
            and input.KeyCode == action.key
        then
            runAction()
        end
    end)
    -- [2026-09-30] cat sta un meniu peste bannerul cu buton, butonul (si V) se ascund; revin cand il inchizi
    RunService.Heartbeat:Connect(function()
        local ready = currentReady
        if currentAction ~= nil and ready ~= nil then
            local clear = ready()
            if actionButton.Visible ~= clear then
                actionButton.Visible = clear
            end
        end
    end)
end

-- Inaltimile se socotesc din text la fiecare banner. Biletul din sticla [D59] are pana la 74 de litere: pe un singur
-- rand de 568, la 0.56 em pe litera, avea 762 de unitati si iesea din placa; acum se rupe pe randuri, iar placa creste
-- cat ele. Cu titlu si subtitlu pe cate un rand, marimile ies exact cele de dinainte (46, 34, 130).
local function layoutBanner(title: string, subtitle: string, withAction: boolean)
    local width = WIDTH - SIDE
    local titleH = math.max(46, Theme.textHeight(title, titleLabel.TextSize, "display", width) + 10)
    titleLabel.Size = UDim2.new(1, -SIDE, 0, titleH)
    local subY = 22 + titleH + 10
    local subH = if subtitle ~= ""
        then math.max(34, Theme.textHeight(subtitle, subtitleLabel.TextSize, "strong", width) + 12)
        else 34
    subtitleLabel.Position = UDim2.new(0.5, 0, 0, subY)
    subtitleLabel.Size = UDim2.new(1, -SIDE, 0, subH)
    local bottom = subY + subH
    if withAction then
        -- [D70] butonul sta sub subtitlu, sau in locul lui cand bannerul n-are subtitlu
        local top = if subtitle ~= "" then subY + subH + 8 else subY
        actionButton.Position = UDim2.new(0.5, 0, 0, top)
        bottom = top + ACTION_H
    end
    root.Size = UDim2.fromOffset(WIDTH, math.max(MIN_HEIGHT, bottom + 18))
end

-- Motorul comun al bannerului: clopotele (Play) si celelalte momente D/F de-o data (PlayMoment)
-- trec amandoua prin el, ca sa nu avem doua tween-uri/task.delay-uri intretinute separat pentru
-- acelasi desen. `burstCount = 0` -> fara rafala de monede: aia ramane semnul distinct al unei
-- CUMPARARI, nu al oricarui banner (prima vanzare, "Workshop is open" etc. n-au rafala).
local function showBanner(
    title: string,
    subtitle: string,
    burstCount: number,
    duration: number,
    action: Action?
)
    if root == nil then
        return
    end
    hideToken += 1
    local token = hideToken
    for _, fade in fades do
        fade:Cancel()
    end
    table.clear(fades)
    busyUntil = os.clock() + math.min(duration, if action ~= nil then ACTION_HOLD else MIN_SHOWN)
    root.ZIndex = BASE_Z

    titleLabel.Text = title
    subtitleLabel.Text = subtitle
    subtitleLabel.Visible = subtitle ~= ""
    currentAction = action
    if action ~= nil then
        Widgets.SetButtonText(actionButton, action.text)
        local label = Theme.textWidth(action.text, Theme.TEXT.body, "strong")
        actionButton.Size =
            UDim2.fromOffset(math.max(ACTION_MIN_W, math.ceil(label + 56)), ACTION_H)
    end
    actionButton.Visible = action ~= nil
    layoutBanner(title, subtitle, action ~= nil)
    root.Visible = true
    root.BackgroundTransparency = 1
    titleLabel.TextTransparency = 0
    subtitleLabel.TextTransparency = 0

    local scale = root:FindFirstChildOfClass("UIScale") or Instance.new("UIScale")
    scale.Parent = root
    scale.Scale = 0.8
    TweenService:Create(
        scale,
        TweenInfo.new(0.4, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
        { Scale = 1 }
    ):Play()
    TweenService:Create(
        root,
        TweenInfo.new(0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
        { BackgroundTransparency = 0.25 }
    ):Play()

    if burstCount > 0 then
        JuiceController.Burst(root, 0.5, 0.62, 27, burstCount)
    end

    task.delay(duration, function()
        if hideToken ~= token then
            return -- alt banner a pornit deja -- lasam noua sa se stinga singura
        end
        -- butonul pleaca odata cu inceputul stingerii: nu se apasa ceva ce abia se mai vede
        currentAction = nil
        currentItem = nil
        actionButton.Visible = false
        local info = TweenInfo.new(FADE, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
        fades = {
            TweenService:Create(root, info, { BackgroundTransparency = 1 }),
            TweenService:Create(titleLabel, info, { TextTransparency = 1 }),
            TweenService:Create(subtitleLabel, info, { TextTransparency = 1 }),
        }
        for _, fade in fades do
            fade:Play()
        end
        task.delay(FADE + 0.05, function()
            if hideToken == token then
                root.Visible = false
            end
        end)
    end)
end

-- Cheamat de Overlay la FIECARE PadBought; ignora in tacere orice pad care nu e "D" -- restul
-- cumpararilor au doar ceremonia scurta a lui Overlay (Flash/rafala mica/sunet/rata) [F2, note 38
-- pct.1]. Titlul e "X is open" (zona pe care clopotul asta o deschide) cand exista una cunoscuta;
-- la clopotul final (fara zona urmatoare) cade pe vechiul "The X is complete!".
function CeremonyController.Play(padId: string)
    local pad = TycoonConfig.byId[padId]
    if pad == nil or pad.motive ~= "D" then
        return
    end
    local title = zoneOpenText(pad) or ceremonyTitle(pad)
    -- [2026-09-30] clopotul vine pe loc (sunetul lui a pornit deja), dar momentul abia aparut pe care il inlocuieste
    -- nu se pierde: revine la rand dupa clopot, fara sa-si mai cante sunetul
    local replaced = currentItem
    if replaced ~= nil and os.clock() < busyUntil then
        table.insert(waiting, 1, replaced)
    end
    currentItem = nil
    showBanner(title, bonusText(pad), 12, DURATION)
    if #waiting > 0 then
        schedule(math.max(0, busyUntil - os.clock()) + 0.05)
    end
end

-- Urmatorul moment de la rand, cand bannerul de acum s-a eliberat: primul care e gata (un anunt care asteapta sa
-- inchizi meniul nu le tine pe celelalte in loc).
local function flush()
    if #waiting == 0 then
        return
    end
    local left = busyUntil - os.clock()
    if left > 0 then
        schedule(left + 0.05)
        return
    end
    local pick: number? = nil
    for i, item in waiting do
        local ready = item.ready
        if ready == nil or ready() then
            pick = i
            break
        end
    end
    if pick ~= nil then
        local item = table.remove(waiting, pick) :: Waiting
        item.show()
    end
    if #waiting > 0 then
        schedule(math.max(READY_RETRY, busyUntil - os.clock() + 0.05))
    end
end
function schedule(delay: number)
    flushGen += 1
    local gen = flushGen
    task.delay(delay, function()
        if gen == flushGen then
            flush()
        end
    end)
end

-- Banner scurt pentru un moment D/F de-o data care NU e un clopot (prima vanzare, Atelierul
-- deschis etc.) [F2, tabelul din nota 39]. Fara rafala -- vezi comentariul de la showBanner. [D70] Cu `action`, bannerul
-- are un buton (si tasta lui) si sta ACTION_SECONDS. [2026-09-30] Intoarce true cand bannerul a aparut pe loc, false
-- cand asteapta la rand (atunci `extras.onShow` vine odata cu el).
function CeremonyController.PlayMoment(
    title: string,
    subtitle: string?,
    action: Action?,
    extras: Extras?
): boolean
    local sub = subtitle or ""
    local onShow = if extras ~= nil then extras.onShow else nil
    local ready = if extras ~= nil then extras.ready else nil
    local function display(withSound: boolean)
        -- butonul se hotaraste acum, nu cand a venit momentul: poate ai ajuns intre timp chiar in locul privirii
        local a = action
        local useful = if a ~= nil then a.useful else nil
        if useful ~= nil and not useful() then
            a = nil
        end
        local duration = MOMENT_DURATION + readingExtra(sub)
        if a ~= nil then
            duration = math.max(duration, ACTION_SECONDS)
        end
        showBanner(title, sub, 0, duration, a)
        currentReady = if a ~= nil then ready else nil
        currentItem = {
            show = function()
                display(false)
            end,
            ready = ready,
        }
        if withSound and onShow ~= nil then
            onShow()
        end
    end
    local function show()
        display(true)
    end
    -- in fata lui asteapta doar momente care nu sunt gata (meniul e inca deschis): nu le asteapta si el
    local readyAhead = false
    for _, item in waiting do
        if item.ready == nil or (item.ready :: () -> boolean)() then
            readyAhead = true
            break
        end
    end
    if os.clock() >= busyUntil and not readyAhead and (ready == nil or ready()) then
        show()
        return true
    end
    table.insert(waiting, { show = show, ready = ready })
    schedule(math.max(0, busyUntil - os.clock()) + 0.05)
    return false
end

-- [2026-09-30] Marginea de jos a bannerului de pe ecran, in px de ecran (nil = niciunul): toast-urile ies sub el.
function CeremonyController.BottomY(): number?
    if root == nil or not root.Visible then
        return nil
    end
    local canvas = root.Parent
    if canvas == nil or not canvas:IsA("GuiObject") then
        return nil
    end
    -- din asezare, nu din AbsoluteSize: la intrare bannerul creste din 80% (UIScale), iar toast-ul ar fi iesit sub el
    local frame = canvas :: GuiObject
    local units = frame.Size.Y.Offset
    local scale = if units > 0 then frame.AbsoluteSize.Y / units else 1
    return frame.AbsolutePosition.Y
        + root.Position.Y.Scale * frame.AbsoluteSize.Y
        + root.Size.Y.Offset * scale
end

-- Stinge bannerul curent ACUM, fara sa astepte durata lui. Folosit de "Loading your river...":
-- cand starea chiar ajunge, mesajul nu mai are ce cauta pe ecran [vazut in Studio, 2026-09-12].
function CeremonyController.HideNow()
    if root == nil or not root.Visible then
        return
    end
    hideToken += 1 -- invalideaza orice task.delay de stingere deja programat
    currentAction = nil
    currentItem = nil
    actionButton.Visible = false
    root.Visible = false
    -- locul s-a eliberat: urmatorul moment de la rand vine acum
    busyUntil = 0
    if #waiting > 0 then
        schedule(0)
    end
end

return CeremonyController
