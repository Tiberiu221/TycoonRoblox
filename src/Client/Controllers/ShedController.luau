--!strict
-- Shed-ul de scrap [D55]: al doilea depozit, doar pentru scrap. Owner-ul: "primii oameni ar trebui sa poata
-- cara scraps nu la storage de wood (driftwood) ci alt storage separat, deblocabil, evident."
--
-- Cladirea (si ruina ei, cat nu e cumparat) o deseneaza PadController, ca pe orice platforma. Aici: gramada
-- de langa el, eticheta si gestul tau pe E -- lasi scrap-ul din traista, sau iei scrap cand n-ai. Ca la
-- depozit, Upgrade deschide meniul meseriei care conteaza acum: cine aduce (Scrap Collector) sau cine ia (Scrap
-- Porter) [D56: meseriile fierului; pana atunci aceiasi Collector si Porter ai lemnului].
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local RiverConfig = require(ReplicatedStorage.Shared.Config.RiverConfig)
local TycoonConfig = require(ReplicatedStorage.Shared.Config.TycoonConfig)
local Strings = require(ReplicatedStorage.Shared.Config.Strings)
local Theme = require(script.Parent.Parent.UI.Theme)
local Widgets = require(script.Parent.Parent.UI.Widgets)
local PileView = require(script.Parent.Parent.UI.PileView)
local Focus = require(script.Parent.Parent.UI.Focus)

export type Deps = {
    Plot: Frame,
    Remotes: { UseShed: RemoteEvent },
}

export type Sack = {
    count: number,
    capacity: number,
    raw: number,
    rawScrap: number,
    finds: number, -- [D56] gasirile neprelucrate (se vand si asa; incluse in `cut`)
    iron: number,
    cut: number,
    cutValue: number,
}
export type Snapshot = { count: number, contents: { [string]: number } }

local ShedController = {}
local deps: Deps
local pile: PileView.View
local label: TextLabel
local sack: Sack =
    { count = 0, capacity = 0, raw = 0, rawScrap = 0, finds = 0, iron = 0, cut = 0, cutValue = 0 }
local stored = 0
local owned = false
local bottleneck = "" -- [D56] veriga slaba a liniei fierului

local STAND = TycoonConfig.SCRAP_SHED_STAND
local PAD = TycoonConfig.byId.scrap_shed
local PILE_SPOT = TycoonConfig.PILES.shed
-- sopronul e 120x96, prins de baza la 56 px sub platforma (PadController)
local SHED_W, SHED_H = 120, 96

local function shedBase(): (number, number)
    return PAD.x :: number, (PAD.y :: number) + 56
end

-- Ce ar face un E acum: lasi scrap-ul, sau iei scrap daca n-ai si ai loc. nil = nimic.
local function action(): string?
    if sack.rawScrap > 0 then
        return "store"
    elseif stored > 0 and sack.count < sack.capacity then
        return "take"
    end
    return nil
end

function ShedController.Apply(newSack: Sack, shed: Snapshot?, isOwned: boolean, bn: string)
    sack = newSack
    owned = isOwned
    bottleneck = bn
    label.Visible = owned
    if shed ~= nil then
        stored = shed.count
        pile.Set(shed.count, shed.contents)
    end
end

-- Meseria care conteaza acum la shed, ca la depozit: cine aduce, daca adunatul scrap-ului e veriga slaba a liniei
-- fierului; altfel cine ia.
function ShedController.CrewRole(): string
    return if bottleneck == "scrapCollect" then "scrapCollector" else "scrapPorter"
end

function ShedController.Focus(px: number, py: number): Focus.Focus?
    if not owned then
        return nil
    end
    local d = Focus.distance(px, py, STAND.x, STAND.y)
    if d > RiverConfig.INTERACT_DISTANCE then
        return nil
    end
    local what = action()
    local keyHint = if UserInputService.KeyboardEnabled then " (E)" else ""
    local text = if what == "store"
        then Strings.promptStoreScrap(keyHint)
        elseif what == "take" then Strings.promptTakeScrap(keyHint)
        else nil
    local x, base = shedBase()
    return {
        key = "shed",
        distance = d,
        x = x,
        y = base - SHED_H - 6,
        action = text,
        act = if text ~= nil
            then function()
                deps.Remotes.UseShed:FireServer()
            end
            else nil,
        upgradeKind = "crew",
        upgradeId = ShedController.CrewRole(),
    }
end

function ShedController.Init(d: Deps)
    deps = d
    local x, base = shedBase()
    label =
        Widgets.Label(deps.Plot, Strings.SHED_LABEL, Theme.TEXT.tiny, Theme.COLOR.onDark, "strong")
    label.AnchorPoint = Vector2.new(0.5, 1)
    label.Position = UDim2.fromOffset(x, base - 6)
    label.Size = UDim2.fromOffset(SHED_W - 8, 18)
    label.TextXAlignment = Enum.TextXAlignment.Center
    label.ZIndex = 6
    label.Visible = false
    Theme.punch(label, 2)
    pile = PileView.new(deps.Plot, PILE_SPOT.x, PILE_SPOT.y, { warnAt = 60, pill = PILE_SPOT.pill })
end

return ShedController
