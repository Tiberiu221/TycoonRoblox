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

local TycoonConfig = require(ReplicatedStorage.Shared.Config.TycoonConfig)
local Strings = require(ReplicatedStorage.Shared.Config.Strings)
local JuiceController = require(script.Parent.JuiceController)
local Theme = require(script.Parent.Parent.UI.Theme)
local Widgets = require(script.Parent.Parent.UI.Widgets)

export type Deps = { HudGui: Frame }

local CeremonyController = {}
local root: Frame
local titleLabel: TextLabel
local subtitleLabel: TextLabel
local hideToken = 0

local DURATION = 3.0 -- clopotele
local MOMENT_DURATION = 3.5 -- alte momente D/F, ceva mai lung: textul e de obicei mai lung
local FADE = 0.6

-- "Landing Bell" -> "The Landing is complete!"; pentru un nume care nu se termina in " Bell"
-- (ex. viitorul "The Charter") ramane doar numele -- nu invizibil, doar mai putin elegant. Folosit
-- doar cand nu exista o zona urmatoare cunoscuta (vezi zoneOpenText) -- adica azi, niciodata.
local function ceremonyTitle(pad: TycoonConfig.Pad): string
    local base = (pad.name:gsub(" Bell$", ""))
    return `The {base} is complete!`
end

-- Numele zonei ACESTEI ere (pentru bonusul "X pays Y% more"), din TycoonConfig.ZONES -- nu scris
-- de mana [D40]. nil pentru erele fara zona inca definita (3-4, doar in plan azi).
local function zoneNameFor(era: number): string?
    for _, z in TycoonConfig.ZONES do
        if z.era == era then
            return z.name
        end
    end
    return nil
end

-- "The Mill is open": zona pe care clopotul asta TOCMAI a deschis-o, din TycoonConfig.ZONES --
-- era+1. nil la clopotul final (The Charter, era 4): nu mai e nimic de deschis dupa el.
local function zoneOpenText(pad: TycoonConfig.Pad): string?
    local nextZone = zoneNameFor(pad.era + 1)
    if nextZone == nil then
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
            local zone = zoneNameFor(pad.era) or (pad.name:gsub(" Bell$", ""))
            return Strings.eraBellRung(zone, pct)
        end
    end
    return "Every sale pays more now" -- rezerva: n-ar trebui sa se intample, niciun clopot de azi cade aici
end

function CeremonyController.Init(deps: Deps)
    root = Instance.new("Frame")
    root.Name = "Ceremony"
    root.AnchorPoint = Vector2.new(0.5, 0)
    root.Position = UDim2.fromScale(0.5, 0.15)
    root.BackgroundColor3 = Theme.COLOR.plate
    root.BackgroundTransparency = 1
    root.Size = UDim2.fromOffset(600, 130)
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
    titleLabel.Size = UDim2.new(1, -32, 0, 46)
    titleLabel.TextXAlignment = Enum.TextXAlignment.Center
    titleLabel.TextWrapped = true
    titleLabel.ZIndex = 26
    Theme.punch(titleLabel, 3)

    subtitleLabel = Widgets.Label(root, "", Theme.TEXT.heading, Theme.COLOR.good, "strong")
    subtitleLabel.AnchorPoint = Vector2.new(0.5, 0)
    subtitleLabel.Position = UDim2.new(0.5, 0, 0, 78)
    subtitleLabel.Size = UDim2.new(1, -32, 0, 34)
    subtitleLabel.TextXAlignment = Enum.TextXAlignment.Center
    subtitleLabel.ZIndex = 26
    Theme.punch(subtitleLabel, 2)
end

-- Motorul comun al bannerului: clopotele (Play) si celelalte momente D/F de-o data (PlayMoment)
-- trec amandoua prin el, ca sa nu avem doua tween-uri/task.delay-uri intretinute separat pentru
-- acelasi desen. `burstCount = 0` -> fara rafala de monede: aia ramane semnul distinct al unei
-- CUMPARARI, nu al oricarui banner (prima vanzare, "Workshop is open" etc. n-au rafala).
local function showBanner(title: string, subtitle: string, burstCount: number, duration: number)
    if root == nil then
        return
    end
    hideToken += 1
    local token = hideToken

    titleLabel.Text = title
    subtitleLabel.Text = subtitle
    subtitleLabel.Visible = subtitle ~= ""
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
        TweenService:Create(
            root,
            TweenInfo.new(FADE, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
            { BackgroundTransparency = 1 }
        ):Play()
        TweenService:Create(
            titleLabel,
            TweenInfo.new(FADE, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
            { TextTransparency = 1 }
        ):Play()
        TweenService:Create(
            subtitleLabel,
            TweenInfo.new(FADE, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
            { TextTransparency = 1 }
        ):Play()
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
    showBanner(title, bonusText(pad), 12, DURATION)
end

-- Banner scurt pentru un moment D/F de-o data care NU e un clopot (prima vanzare, Atelierul
-- deschis etc.) [F2, tabelul din nota 39]. Fara rafala -- vezi comentariul de la showBanner.
function CeremonyController.PlayMoment(title: string, subtitle: string?)
    showBanner(title, subtitle or "", 0, MOMENT_DURATION)
end

-- Stinge bannerul curent ACUM, fara sa astepte durata lui. Folosit de "Loading your river...":
-- cand starea chiar ajunge, mesajul nu mai are ce cauta pe ecran [vazut in Studio, 2026-09-12].
function CeremonyController.HideNow()
    if root == nil or not root.Visible then
        return
    end
    hideToken += 1 -- invalideaza orice task.delay de stingere deja programat
    root.Visible = false
end

return CeremonyController
