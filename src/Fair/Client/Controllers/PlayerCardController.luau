--!strict
-- [D60] CARDUL ALTUI JUCATOR. Langa cineva, cardul scrie `Look at Mara (E)`; apesi si vezi ce a facut: Era, venitul pe
-- secunda, cel mai mare peste, cate lucruri a scos din rau, cate decoruri are satul, jurnalul. Plus `Add friend`.
-- Nimic nu sare singur pe ecran: panoul apare doar cand apesi. Cifrele le trimite serverul, din profilul omului.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local StarterGui = game:GetService("StarterGui")

local LookMath = require(ReplicatedStorage.Shared.Modules.LookMath)
local Strings = require(ReplicatedStorage.Shared.Config.Strings)
local TycoonMath = require(ReplicatedStorage.Shared.Modules.TycoonMath)

local Panels = require(script.Parent.Panels)
local SoundController = require(script.Parent.SoundController)
local Portrait = require(script.Parent.Parent.UI.Portrait)
local Theme = require(script.Parent.Parent.UI.Theme)
local Widgets = require(script.Parent.Parent.UI.Widgets)

export type Deps = {
    HudGui: Frame,
    Remotes: { LookAt: RemoteEvent, LookAtResult: RemoteEvent },
    OnToast: (string, Color3?) -> (),
    -- [D61, partea 2] `Visit village`: fotografia satului lui, prin poarta satelor (VisitController.Visit)
    OnVisit: ((userId: number) -> ())?,
}

local PlayerCardController = {}
local deps: Deps? = nil
local window: Frame
local open = false
local shownUserId = 0
local portrait: Frame
local nameLabel: TextLabel
local titleLabel: TextLabel
local eraLabel: TextLabel
local values: { [string]: TextLabel } = {}
local friendButton: TextButton
local visitButton: TextButton

local PANEL_W, PANEL_H = 480, 460
local Z = 72
local ROWS = { "income", "fish", "treasures", "decor", "likes", "journal" }
local ROW_STEP = 32 -- sase randuri intre portret si butoane (cutiile: check_panel_rows.py, PLAYER_CARD)
local BUTTON_W = 210

-- Portretul: omul in tinuta lui si [D61] cu chipul lui, cadrul idle spre tine (UI/Portrait, comun cu avizierul).
local function drawPortrait(outfit: string, look: LookMath.Look)
    Portrait.draw(portrait, outfit, look, 64, 96, Z + 3)
end

local function show(card: { [string]: any })
    shownUserId = card.userId
    nameLabel.Text = card.name
    titleLabel.Text = card.title
    local era = math.clamp(card.era, 1, #Strings.ERA_NAMES)
    eraLabel.Text = Strings.cardEra(card.era, Strings.ERA_NAMES[era])
    values.income.Text = if card.incomePerSec > 0
        then `{TycoonMath.formatNumber(card.incomePerSec)}/s`
        else Strings.CARD_INCOME_UNKNOWN
    values.fish.Text = if card.fish ~= nil
        then Strings.cardFish(card.fish, math.floor(card.fishCm))
        else Strings.CARD_NO_FISH
    values.treasures.Text = tostring(card.treasures)
    values.decor.Text = tostring(card.decor)
    values.likes.Text = tostring(card.likes)
    values.journal.Text = Strings.cardOf(card.species, card.speciesTotal)
    drawPortrait(card.outfit, card.look)
    local other = card.userId ~= Players.LocalPlayer.UserId
    friendButton.Visible = other
    visitButton.Visible = other and (deps :: Deps).OnVisit ~= nil
    Panels.CloseOthers("card")
    open = true
    window.Visible = true
    SoundController.Play("click")
end

-- Cere cardul cuiva; panoul se deschide cand vine raspunsul.
function PlayerCardController.Open(userId: number)
    local d = deps
    if d ~= nil then
        d.Remotes.LookAt:FireServer(userId)
    end
end

function PlayerCardController.IsOpen(): boolean
    return open
end

function PlayerCardController.Close()
    open = false
    if window ~= nil then
        window.Visible = false
    end
end

function PlayerCardController.Init(d: Deps)
    deps = d
    local root, body = Widgets.Window(d.HudGui, {
        name = "PlayerCard",
        title = "",
        icon = "people",
        width = PANEL_W,
        height = PANEL_H,
        z = Z,
        onClose = PlayerCardController.Close,
    })
    window = root
    window.AnchorPoint = Vector2.new(0.5, 0.5)
    window.Position = UDim2.fromScale(0.5, 0.5)
    window.Visible = false

    portrait = Instance.new("Frame")
    portrait.Name = "Portrait"
    portrait.Position = UDim2.fromOffset(0, 0)
    portrait.Size = UDim2.fromOffset(96, 104)
    portrait.ZIndex = Z + 2
    portrait.Parent = body
    Widgets.PillBackground(portrait, Z + 2)

    nameLabel = Widgets.Label(body, "", Theme.TEXT.heading, Theme.COLOR.ink, "display")
    nameLabel.Position = UDim2.fromOffset(112, 4)
    nameLabel.Size = UDim2.new(1, -112, 0, 28)
    nameLabel.TextTruncate = Enum.TextTruncate.AtEnd
    nameLabel.ZIndex = Z + 1
    titleLabel = Widgets.Label(body, "", Theme.TEXT.body, Theme.COLOR.warnInk, "strong")
    titleLabel.Position = UDim2.fromOffset(112, 38)
    titleLabel.Size = UDim2.new(1, -112, 0, 24)
    titleLabel.TextTruncate = Enum.TextTruncate.AtEnd
    titleLabel.ZIndex = Z + 1
    eraLabel = Widgets.Label(body, "", Theme.TEXT.small, Theme.COLOR.inkSoft, "body")
    eraLabel.Position = UDim2.fromOffset(112, 70)
    eraLabel.Size = UDim2.new(1, -112, 0, 20)
    eraLabel.ZIndex = Z + 1

    local labels: { [string]: string } = {
        income = Strings.CARD_INCOME,
        fish = Strings.CARD_FISH,
        treasures = Strings.CARD_TREASURES,
        decor = Strings.CARD_DECOR,
        likes = Strings.CARD_LIKES,
        journal = Strings.CARD_JOURNAL,
    }
    for i, key in ROWS do
        local y = 116 + (i - 1) * ROW_STEP
        local label =
            Widgets.Label(body, labels[key], Theme.TEXT.small, Theme.COLOR.inkSoft, "body")
        label.Position = UDim2.fromOffset(0, y)
        label.Size = UDim2.fromOffset(200, 24)
        label.ZIndex = Z + 1
        local value = Widgets.Label(body, "", Theme.TEXT.small, Theme.COLOR.ink, "strong")
        value.AnchorPoint = Vector2.new(1, 0)
        value.Position = UDim2.new(1, 0, 0, y)
        value.Size = UDim2.fromOffset(220, 24)
        value.TextXAlignment = Enum.TextXAlignment.Right
        value.TextTruncate = Enum.TextTruncate.AtEnd
        value.ZIndex = Z + 1
        values[key] = value
    end

    friendButton = Widgets.Button(body, {
        text = Strings.CARD_ADD_FRIEND,
        icon = "people",
        width = BUTTON_W,
        height = 48,
        z = Z + 2,
        onClick = function()
            local other = Players:GetPlayerByUserId(shownUserId)
            if other == nil then
                d.OnToast(Strings.CARD_GONE)
                return
            end
            -- fereastra Roblox de prietenie; jucatorul confirma acolo
            pcall(function()
                StarterGui:SetCore("PromptSendFriendRequest", other)
            end)
        end,
    })
    friendButton.AnchorPoint = Vector2.new(0, 1)
    friendButton.Position = UDim2.fromScale(0, 1)

    -- [D61, partea 2] satul lui, ca fotografie: acelasi drum ca de la poarta satelor
    visitButton = Widgets.Button(body, {
        text = Strings.VISIT_CARD_BUTTON,
        width = BUTTON_W,
        height = 48,
        z = Z + 2,
        onClick = function()
            local visit = d.OnVisit
            if visit ~= nil and shownUserId ~= 0 then
                PlayerCardController.Close()
                visit(shownUserId)
            end
        end,
    })
    visitButton.AnchorPoint = Vector2.new(1, 1)
    visitButton.Position = UDim2.fromScale(1, 1)
    Widgets.SetButtonTone(visitButton, Theme.COLOR.gold)

    d.Remotes.LookAtResult.OnClientEvent:Connect(function(card: any, _userId: unknown)
        if typeof(card) ~= "table" then
            d.OnToast(Strings.CARD_GONE)
            return
        end
        -- copiat camp cu camp [CLAUDE.md, capcana 3]
        show({
            userId = if typeof(card.userId) == "number" then card.userId else 0,
            name = if typeof(card.name) == "string" then card.name else "",
            title = if typeof(card.title) == "string" then card.title else "",
            outfit = if typeof(card.outfit) == "string" then card.outfit else "keeper",
            look = LookMath.clean(card.look), -- [D61]
            era = if typeof(card.era) == "number" then card.era else 1,
            likes = if typeof(card.likes) == "number" then card.likes else 0, -- [D61, partea 2]
            incomePerSec = if typeof(card.incomePerSec) == "number" then card.incomePerSec else 0,
            fish = if typeof(card.fish) == "string" then card.fish else nil,
            fishCm = if typeof(card.fishCm) == "number" then card.fishCm else 0,
            treasures = if typeof(card.treasures) == "number" then card.treasures else 0,
            decor = if typeof(card.decor) == "number" then card.decor else 0,
            species = if typeof(card.species) == "number" then card.species else 0,
            speciesTotal = if typeof(card.speciesTotal) == "number" then card.speciesTotal else 0,
        })
    end)

    Panels.Register(
        "card",
        { isOpen = PlayerCardController.IsOpen, close = PlayerCardController.Close }
    )
end

return PlayerCardController
