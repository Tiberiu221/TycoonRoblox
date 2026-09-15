--!strict
-- Depozitul [D49]: unde Collector-ul varsa ce strange din plase si de unde ia Porter-ul. Un loc fix,
-- ca gaterul si debarcaderul -- nu o platforma de cumparat. Tu il folosesti la fel ca ei: E cu busteni
-- in traista ii lasa aici, E cu traista fara busteni ia de aici.
--
-- Gramada de langa el e cea care spune povestea: creste cand Porter-ul (sau tu) nu tine pasul cu
-- plasele, se goleste cand tine. Atins, deschide meniul meseriei care conteaza acum.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local RiverConfig = require(ReplicatedStorage.Shared.Config.RiverConfig)
local TycoonConfig = require(ReplicatedStorage.Shared.Config.TycoonConfig)
local Assets = require(ReplicatedStorage.Shared.Config.Assets)
local Strings = require(ReplicatedStorage.Shared.Config.Strings)
local Theme = require(script.Parent.Parent.UI.Theme)
local Widgets = require(script.Parent.Parent.UI.Widgets)
local PileView = require(script.Parent.Parent.UI.PileView)
local Focus = require(script.Parent.Parent.UI.Focus)
local GroundShadow = require(script.Parent.Parent.UI.GroundShadow)

export type Deps = {
    Plot: Frame,
    Remotes: { UseStorage: RemoteEvent },
    CharacterPos: () -> (number, number),
    -- depozitul atins deschide meniul unei meserii (Collector sau Porter); dat din Bootstrap
    OpenCrew: ((string) -> ())?,
}

-- Ce stie un loc de predare despre traista ta: cat duci, cat incape, cat e brut si cat e taiat.
export type Sack = {
    count: number,
    capacity: number,
    raw: number, -- [D55] lemnul brut; scrap-ul are `rawScrap` si drumul lui
    rawScrap: number,
    finds: number, -- [D56] gasirile neprelucrate (se vand si asa; incluse in `cut`)
    iron: number,
    cut: number,
    cutValue: number,
}
export type Snapshot = { count: number, contents: { [string]: number } }

local StorageController = {}
local deps: Deps
local pile: PileView.View
local sack: Sack =
    { count = 0, capacity = 0, raw = 0, rawScrap = 0, finds = 0, iron = 0, cut = 0, cutValue = 0 }
local stored = 0
local bottleneck = "nets"

local ST = TycoonConfig.STORAGE
local STAND = TycoonConfig.STORAGE_STAND
-- Gramada are locul ei fix in config [D50]: cand era o formula lipita de cladire, pe harta noua ar
-- fi cazut peste coliba Collector-ului.
local PILE_SPOT = TycoonConfig.PILES.storage

-- Ce ar face un E acum: lasi brutul, sau iei brut daca n-ai si ai loc. nil = nimic.
local function action(): string?
    if sack.raw > 0 then
        return "store"
    elseif stored > 0 and sack.count < sack.capacity then
        return "take"
    end
    return nil
end

function StorageController.Apply(newSack: Sack, storage: Snapshot?, bn: string)
    sack = newSack
    bottleneck = bn
    if storage ~= nil then
        stored = storage.count
        pile.Set(storage.count, storage.contents)
    end
end

-- Meseria care conteaza acum la depozit: cine aduce, daca adunatul e veriga slaba (a lemnului [D56]); altfel cine ia.
-- Aceeasi alegere pentru atingerea cladirii si pentru Upgrade de pe card [D51].
function StorageController.CrewRole(): string
    return if bottleneck == "collect" then "collector" else "porter"
end

-- [D51] Cardul depozitului: lasi brutul sau iei busteni, cand are sens; Upgrade = meniul meseriei.
function StorageController.Focus(px: number, py: number): Focus.Focus?
    local d = Focus.distance(px, py, STAND.x, STAND.y)
    if d > RiverConfig.INTERACT_DISTANCE then
        return nil
    end
    local what = action()
    local keyHint = if UserInputService.KeyboardEnabled then " (E)" else ""
    local text = if what == "store"
        then Strings.promptStoreLogs(keyHint)
        elseif what == "take" then Strings.promptTakeLogs(keyHint)
        else nil
    return {
        key = "storage",
        distance = d,
        x = ST.x,
        y = ST.y - ST.h - 6,
        action = text,
        act = if text ~= nil
            then function()
                deps.Remotes.UseStorage:FireServer()
            end
            else nil,
        -- [D55] cu doar scrap in traista, cardul spune unde merge -- nu tace [D43]
        status = if text == nil and sack.rawScrap > 0
            then Strings.useResult("storage", false, "scrap_to_forge", 0, 0, false)
            else nil,
        upgradeKind = "crew",
        upgradeId = StorageController.CrewRole(),
    }
end

function StorageController.Init(d: Deps)
    deps = d

    -- [D57] umbra sub depozit: sta pe pamantul curtii, nu deasupra lui
    GroundShadow.add(deps.Plot, UDim2.fromOffset(ST.x, ST.y), ST.w, 2)
    local marker = Instance.new("Frame")
    marker.Name = "Storage"
    marker.AnchorPoint = Vector2.new(0.5, 1)
    marker.Position = UDim2.fromOffset(ST.x, ST.y)
    marker.Size = UDim2.fromOffset(ST.w, ST.h)
    marker.BackgroundTransparency = 1
    marker.ZIndex = 3
    marker.Parent = deps.Plot

    local building = (Assets.tycoon :: any).storage
    if building ~= nil and Assets.has(building) then
        local art = Instance.new("ImageLabel")
        art.Name = "Art"
        art.BackgroundTransparency = 1
        art.Image = Assets.url(building)
        art.ResampleMode = Enum.ResamplerMode.Pixelated
        art.Size = UDim2.fromScale(1, 1)
        art.ZIndex = 3
        art.Parent = marker
    else
        -- arta inca neurcata: un sopron de lemn simplu, cat sa se vada unde e depozitul [regula 6]
        marker.BackgroundTransparency = 0.15
        marker.BackgroundColor3 = Theme.COLOR.wood
        local corner = Instance.new("UICorner")
        corner.CornerRadius = UDim.new(0, 8)
        corner.Parent = marker
    end

    local tap = Instance.new("TextButton")
    tap.Name = "Tap"
    tap.Text = ""
    tap.AutoButtonColor = false
    tap.BackgroundTransparency = 1
    tap.Size = UDim2.fromScale(1, 1)
    tap.ZIndex = 5
    tap.Parent = marker
    tap.Activated:Connect(function()
        local open = deps.OpenCrew
        if open ~= nil then
            open(StorageController.CrewRole())
        end
    end)

    local label =
        Widgets.Label(marker, Strings.STORAGE_LABEL, Theme.TEXT.tiny, Theme.COLOR.onDark, "strong")
    label.AnchorPoint = Vector2.new(0.5, 1)
    label.Position = UDim2.new(0.5, 0, 1, -6)
    label.Size = UDim2.fromOffset(ST.w - 8, 18)
    label.TextXAlignment = Enum.TextXAlignment.Center
    label.ZIndex = 6
    Theme.punch(label, 2)

    pile = PileView.new(deps.Plot, PILE_SPOT.x, PILE_SPOT.y, { warnAt = 60, pill = PILE_SPOT.pill })
end

return StorageController
