--!strict
-- O gramada de marfa desenata langa o cladire [D49], cu o pastila cu cifra. Pana in D49 acelasi bloc era
-- copiat in gater si in debarcader; acum il folosesc depozitul, shed-ul, cele doua gramezi ale gaterului,
-- ale atelierului si taverna.
--
-- [D55] GRAMADA E UN OBIECT, NU SASE PICTOGRAME. Owner-ul: "texturile pentru cand npc-ul pune jos lemnul
-- respectiv plank-urile sunt patetice si lipsite de logica". Felul cu cele mai multe bucati se deseneaza pe
-- locul gramezii, pe TREPTE (stiva de busteni, teancul de scanduri, mormanul de scrap, lingourile), prins de
-- BAZA ca o cladire; un al doilea fel (la taverna: scanduri si fier) sta alaturi, mai mic; gasirile cu nume
-- (lazile) ca o lada mica deasupra. Fara arta urcata, pictogramele de dinainte.
--
-- CIFRA NU E DECOR. Treapta arata la fel pentru 40 de bucati si pentru 700; cifra spune diferenta, iar cand
-- gramada creste peste `warnAt` se face portocalie: veriga de dupa ea e cea slaba, si asta se vede inainte
-- sa fie citit vreun meniu [D43].
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Assets = require(ReplicatedStorage.Shared.Config.Assets)
local TycoonConfig = require(ReplicatedStorage.Shared.Config.TycoonConfig)
local TycoonMath = require(ReplicatedStorage.Shared.Modules.TycoonMath)
local Theme = require(script.Parent.Theme)
local GoodArt = require(script.Parent.GoodArt)
local Widgets = require(script.Parent.Widgets)

local PileView = {}

local WORLD_TEXT_Z = 46 -- banda textului din lume: numele cladirilor, etichetele liniilor, placa inelului (47)

export type Options = {
    warnAt: number?, -- de la atatea bucati cifra se face portocalie (implicit 25)
    pill: string?, -- unde sta cifra: "above" (implicit) | "right"
    zIndex: number?,
}

export type View = {
    Set: (count: number, contents: { [string]: number }) -> (),
    Count: () -> number,
}

-- ---- treptele [D55] ----------------------------------------------------------------------------
local FRAME_W, FRAME_H = 40, 28 -- un cadru din fasie
local SCALE = TycoonConfig.PROP_SCALE -- recuzita la x2: 80x56
-- de la cate bucati incepe fiecare treapta (1-4, 5-14, 15-39, 40+)
local STEP_AT = { 1, 5, 15, 40 }
-- ce fasie deseneaza fiecare fel; ce a ramas vechi (reeds, shards) seamana cu ruda lui
local PILE_OF: { [string]: string } = {
    driftwood = "pile_logs",
    reeds = "pile_logs",
    planks = "pile_planks",
    scrap = "pile_scrap",
    shards = "pile_scrap",
    iron = "pile_iron",
    -- [D65] marfa Morii; cat fasia ei nu e urcata, gramada o poarta pe a perechii (UI/GoodArt)
    parts = "pile_parts",
    ore = "pile_ore",
    copper = "pile_copper",
    -- [D67] marfa Wire Works
    coils = "pile_coils",
    battery = "pile_battery",
    cell = "pile_cell",
}
-- al doilea fel: la 70%, lipit in dreapta, cel mult treapta 2 -- se citeste "si asta", nu "a doua gramada"
local SECOND_SCALE = 0.7
local SECOND_MAX_STEP = 2

local function stepOf(count: number): number
    local step = 0
    for i, at in STEP_AT do
        if count >= at then
            step = i
        end
    end
    return step
end

local function pileSprite(good: string): Assets.Sprite?
    return GoodArt.pick(good, function(g: string): Assets.Sprite?
        local key = PILE_OF[g]
        return if key ~= nil then (Assets.tycoon :: any)[key] else nil
    end)
end

local function stageImage(parent: Instance, name: string, z: number): ImageLabel
    local img = Instance.new("ImageLabel")
    img.Name = name
    img.BackgroundTransparency = 1
    img.ResampleMode = Enum.ResamplerMode.Pixelated
    img.AnchorPoint = Vector2.new(0.5, 1)
    img.ImageRectSize = Vector2.new(FRAME_W, FRAME_H)
    img.Visible = false
    img.ZIndex = z
    img.Parent = parent
    return img
end

-- ---- pictogramele de dinainte, cat arta treptelor nu e urcata ------------------------------------
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
local function goodSprite(raw: string): Assets.Sprite
    if TycoonConfig.lookOf(raw) == "named" then
        return Assets.crate.common
    end
    return GoodArt.icon(raw) or Assets.goods.driftwood -- [D65]
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

-- `cx`, `baseY` = mijlocul si BAZA gramezii (TycoonConfig.PILES) [D55].
function PileView.new(parent: Instance, cx: number, baseY: number, options: Options?): View
    local opts: Options = options or {}
    local warnAt = opts.warnAt or 25
    local z = opts.zIndex or 3

    local main = stageImage(parent, "PileMain", z)
    main.Position = UDim2.fromOffset(cx, baseY)
    main.Size = UDim2.fromOffset(FRAME_W * SCALE, FRAME_H * SCALE)
    local second = stageImage(parent, "PileSecond", z + 1)
    second.Position = UDim2.fromOffset(cx + FRAME_W * SCALE * 0.42, baseY + 2)
    second.Size = UDim2.fromOffset(FRAME_W * SCALE * SECOND_SCALE, FRAME_H * SCALE * SECOND_SCALE)
    local crate = Instance.new("ImageLabel")
    crate.Name = "PileCrate"
    crate.BackgroundTransparency = 1
    crate.ResampleMode = Enum.ResamplerMode.Pixelated
    crate.AnchorPoint = Vector2.new(0.5, 1)
    crate.Position = UDim2.fromOffset(cx - FRAME_W * SCALE * 0.3, baseY)
    crate.Size = UDim2.fromOffset(28, 24)
    crate.Visible = false
    crate.ZIndex = z + 2
    crate.Parent = parent
    if Assets.has(Assets.crate.common) then
        crate.Image = Assets.url(Assets.crate.common)
    end

    -- rezerva: pictogramele de dinainte, in jurul locului gramezii
    local iconY = baseY - 22
    local icons: { ImageLabel } = {}
    for i = 1, ITEM_CAP do
        local icon = Instance.new("ImageLabel")
        icon.Name = "Pile" .. i
        icon.BackgroundTransparency = 1
        icon.ResampleMode = Enum.ResamplerMode.Pixelated
        icon.AnchorPoint = Vector2.new(0.5, 0.5)
        icon.Position = UDim2.fromOffset(cx + SLOTS[i][1], iconY + SLOTS[i][2])
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
        pill.Position = UDim2.fromOffset(cx + FRAME_W * SCALE / 2 + 4, baseY - FRAME_H * SCALE / 2)
    else
        pill.AnchorPoint = Vector2.new(0.5, 1)
        pill.Position = UDim2.fromOffset(cx, baseY - FRAME_H * SCALE - 2)
    end
    pill.Visible = false
    -- [D70, dupa verificator] cifra sta in banda textului din lume (46/47, ca numele cladirilor si etichetele liniilor),
    -- peste adancimea lumii: sarma stalpilor din Era 3 (5 + y/64) trecea prin ea, iar dupa cifra asta vezi veriga slaba
    pill.ZIndex = WORLD_TEXT_Z
    Widgets.PillBackground(pill, WORLD_TEXT_Z)
    pill.Parent = parent
    local label = Widgets.Label(pill, "0", Theme.TEXT.small, Theme.COLOR.onDark, "display")
    label.AnchorPoint = Vector2.new(0.5, 0.5)
    label.Position = UDim2.fromScale(0.5, 0.5)
    label.Size = UDim2.fromOffset(48, 20)
    label.TextXAlignment = Enum.TextXAlignment.Center
    label.ZIndex = WORLD_TEXT_Z + 1

    local function showStage(
        img: ImageLabel,
        good: string?,
        count: number,
        maxStep: number
    ): boolean
        local sprite = if good ~= nil then pileSprite(good :: string) else nil
        local step = math.min(stepOf(count), maxStep)
        if sprite == nil or step <= 0 then
            img.Visible = false
            return false
        end
        img.Image = Assets.url(sprite :: Assets.Sprite)
        img.ImageRectOffset = Vector2.new((step - 1) * FRAME_W, 0)
        img.Visible = true
        return true
    end

    local current = 0
    local view: View = {
        Set = function(count: number, contents: { [string]: number })
            current = count
            label.Text = TycoonMath.formatNumber(count)
            label.TextColor3 = if count >= warnAt then Theme.COLOR.warn else Theme.COLOR.onDark
            pill.Visible = count > 0

            -- felurile care au o treapta, ordonate dupa cate bucati (la egalitate, ordinea GOODS)
            local kinds: { { good: string, n: number, order: number } } = {}
            for i, g in TycoonConfig.GOODS do
                local n = contents[g.id] or 0
                if n > 0 and PILE_OF[g.id] ~= nil then
                    table.insert(kinds, { good = g.id, n = n, order = i })
                end
            end
            -- ordine stabila intre doua stari: altfel, la egalitate, cele doua desene si-ar schimba locul
            table.sort(kinds, function(a, b)
                if a.n ~= b.n then
                    return a.n > b.n
                end
                return a.order < b.order
            end)
            local first, secondKind = kinds[1], kinds[2]
            local drawn = showStage(
                main,
                if first ~= nil then first.good else nil,
                if first ~= nil then first.n else 0,
                #STEP_AT
            )
            showStage(
                second,
                if secondKind ~= nil then secondKind.good else nil,
                if secondKind ~= nil then secondKind.n else 0,
                SECOND_MAX_STEP
            )
            crate.Visible = drawn and (contents.named or 0) > 0 and Assets.has(Assets.crate.common)

            -- fara arta treptelor (sau doar lazi), pictogramele de dinainte
            local shown = if drawn then {} else flatten(contents)
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
