--!strict
-- Plasele: fiecare intrare din TycoonState.nets e UN SINGUR obiect de lume [research 42, "Ce
-- lipseste": pct.1-3,6] -- stalp pe ponton, funie intinsa pana in apa, plasa insasi (cu ce s-a
-- prins inauntru) si pastila cu cifra, toate agatate de acelasi cadru. PadController nu mai
-- deseneaza stalpul plaselor -- il desenam noi, o singura data, aici.
-- Interactiunea de apropiere (E / butonul de atingere) foloseste STALPUL (pad.x, pad.y, pe mal)
-- ca ancora de distanta, nu punctul din apa -- personajul nu poate calca in rau (WorldMap il
-- blocheaza), deci masurata fata de un punct din banda de apa unele plase (banda 2-3) ar iesi din
-- raza de interactiune.
-- Ce face E langa o plasa o spune cardul obiectului (InteractController, prin NetController.Focus)
-- [D51]: Collect doar cand are ceva si incape, Upgrade dupa prima vanzare.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local RiverConfig = require(ReplicatedStorage.Shared.Config.RiverConfig)
local TycoonConfig = require(ReplicatedStorage.Shared.Config.TycoonConfig)
local TycoonMath = require(ReplicatedStorage.Shared.Modules.TycoonMath)
local Prng = require(ReplicatedStorage.Shared.Modules.Prng)
local CatchFloat = require(ReplicatedStorage.Shared.Modules.CatchFloat)
local NetMotion = require(ReplicatedStorage.Shared.Modules.NetMotion)
local ItemConfig = require(ReplicatedStorage.Shared.Config.ItemConfig)
local Assets = require(ReplicatedStorage.Shared.Config.Assets)
local Strings = require(ReplicatedStorage.Shared.Config.Strings)
local SceneArt = require(script.Parent.SceneArt)
local Theme = require(script.Parent.Parent.UI.Theme)
local Focus = require(script.Parent.Parent.UI.Focus)
local Widgets = require(script.Parent.Parent.UI.Widgets)

export type NetSnap = {
    padId: string,
    padIndex: number,
    lane: number,
    x: number,
    y: number,
    count: number,
    capacity: number,
    nextCatchAt: number,
    interval: number,
    caught: number,
    contents: { [string]: number }, -- good -> cate, ca sa se deseneze gramada [research 42 pct.2]
    boosted: boolean?, -- [D51] prima plasa prinde grabit, in tutorial
}

export type Deps = {
    Plot: Frame,
    Remotes: {
        CollectNet: RemoteEvent,
        NetCaught: RemoteEvent,
    },
    CharacterPos: () -> (number, number),
    OnToast: (string) -> (),
    -- plasa atinsa deschide panoul de niveluri pe ea; dat din Bootstrap
    OpenStation: ((string, string?) -> ())?,
}

-- [D53] Un bustean pe drum spre plasa, legat de MOMENTUL prinderii lui (ceasul plasei, CatchFloat).
-- Mai multi pe plasa, dintr-un pool: plasele rapide au un sir, nu unul singur care apare din senin.
type Floater = {
    frame: Frame,
    icon: ImageLabel,
    scale: UIScale,
    mode: string?, -- nil pe drum; "turn" (intra) sau "pass" (plasa plina), hotarat o data, la cot
    bornAt: number, -- cand a aparut: de acolo se estompeaza
}

-- O plasa = un singur obiect compus [research 42 pct.1]:
--  root: radacina FIXA, ancorata la stalpul de pe ponton (pad.x, pad.y) -- un stalp infipt in
--        ponton nu pluteste, deci nu se leagana niciodata.
--  bob:  subcadrul care se leagana/tresare (NetMotion) -- corpul plasei, gramada si pastila stau
--        toate aici, ca sa se miste IMPREUNA cu plasa, nu doar corpul ei.
--  body: cadrul de marimea NET_DRAW in care se deseneaza sprite-ul plasei si gramada din ea --
--        tinta pentru Splash/FloatText, ca stropii sa cada PE plasa, nu in coltul unui cadru gol.
--  rope: funia intre varful stalpului (fix) si plasa (mobila) -- lungimea ei se recalculeaza in
--        fiecare cadru, altfel s-ar rupe vizual de plasa cand aceasta se leagana.
type Assembly = {
    root: Frame,
    bob: Frame,
    body: Frame,
    art: ImageLabel?, -- nil daca Assets.tycoon.net_water inca nu s-a incarcat (desen vechi in loc)
    rope: Frame,
    bodyScale: UIScale,
    items: { ImageLabel }, -- pool fix pentru gramada din plasa [research 42 pct.2/3]
    padX: number,
    padY: number, -- pozitia stalpului (mal) -- originea fata de care se calculeaza tot restul
    lastFull: boolean,
    levelLabel: TextLabel?, -- insigna "Lv 7" de pe stalp
    boostTag: TextLabel, -- [D51] "Fast first catch", sub pastila cu numarul
}

local NetController = {}
local deps: Deps
local nets: { [string]: NetSnap } = {} -- padId -> ultima stare cunoscuta
local assemblies: { [string]: Assembly } = {}
-- Nivelul fiecarei plase, ca sa scrie pe stalp. Idle Miner pune insigna de nivel pe OBIECT, nu doar
-- in panou -- asa se vede dintr-o privire care plasa a ramas in urma.
local netLevels: { [string]: number } = {} -- padId -> stalp+funie+plasa+gramada+pastila
local tugAt: { [string]: number } = {} -- padId -> cand a prins ultima data (timp de server)
local netDy: { [string]: number } = {} -- padId -> cat e ridicata/coborata plasa chiar acum
local floaters: { [string]: { [number]: Floater } } = {} -- padId -> momentul (x10, rotunjit) -> bustean
local freeFloaters: { Floater } = {}
local sackCount = 0
local sackCapacity = 0
local sackRaw = 0 -- cati busteni bruti duci: decide unde te trimite mesajul de traista plina [D49]
local currentLanes = 1
local LocalPlayer = Players.LocalPlayer

local TIER_COLORS: { [string]: Color3 } = {}
for _, tier in RiverConfig.TIERS do
    TIER_COLORS[tier.id] = Color3.fromRGB(tier.rgb[1], tier.rgb[2], tier.rgb[3])
end

-- [B5] Plasele sunt copii ai Plot-ului, in coordonate locale terenului; personajul umbla in
-- coordonate de LUME.
local PLOT_ORIGIN = TycoonConfig.PLOT_ORIGIN
local function toPlotLocal(worldX: number, worldY: number): (number, number)
    return worldX - PLOT_ORIGIN.x, worldY - PLOT_ORIGIN.y
end

-- ---- geometria stalpului, a funiei si a gramezii din plasa [research 42 pct.1-3] --------------
-- Recuzita mica se deseneaza la PROP_SCALE (x2), nu la PIXEL_SCALE (x3, cladirile adevarate) --
-- vezi comentariul de la TycoonConfig.PROP_SCALE.
local POST_W = Assets.tycoon.netpost.width * TycoonConfig.PROP_SCALE
local POST_H = Assets.tycoon.netpost.height * TycoonConfig.PROP_SCALE
local ROPE_WIDTH = 3
local NET_ITEM_CAP = 6 -- cate sprite-uri stivuite deseneaza plasa cel mult -- pastila duce restul
local NET_ITEM_MAX = 18 -- px, latura mare a unui bun stivuit -- destul de mic cat sa incapa 6
local NET_FULL_SINK = 5 -- px, cat de jos se lasa plasa in apa cand e plina [research 42 pct.3]
-- Sloturile gramezii, ca fractiuni din cadrul plasei (NET_DRAW) -- doua randuri in zigzag, ca o
-- gramada reala, nu un grid perfect.
local NET_ITEM_SLOTS = {
    { 0.26, 0.32 },
    { 0.50, 0.24 },
    { 0.74, 0.32 },
    { 0.30, 0.70 },
    { 0.52, 0.78 },
    { 0.70, 0.70 },
}

-- Ordinea GOODS tine desenul stabil intre doua stari [oglinda comentariului din
-- NetService.Snapshot]: bunul dominant (driftwood) umple primele sloturi, gasirile cu nume
-- ultimele. Peste NET_ITEM_CAP, gramada nu mai creste vizual -- pastila duce cifra exacta.
local function flattenContents(contents: { [string]: number }?): { string }
    local shown: { string } = {}
    if contents == nil then
        return shown
    end
    for _, g in TycoonConfig.GOODS do
        local n = contents[g.id] or 0
        for _ = 1, n do
            if #shown >= NET_ITEM_CAP then
                return shown
            end
            table.insert(shown, g.id)
        end
    end
    return shown
end

-- Sprite-ul unui bun stivuit sau care pluteste: obiectele cu nume folosesc lada (tierul nu se
-- pastreaza in rezumatul `contents`, doar count-ul), restul sprite-ul lor propriu [F1 spec 4.2].
local function goodSprite(good: string): Assets.Sprite
    if good == "named" then
        return Assets.crate.common
    end
    return (Assets.goods :: any)[good] or Assets.goods.driftwood
end

-- Marimea unui bun stivuit: incadrat in NET_ITEM_MAX pe latura mare, pastrand proportia -- altfel
-- bustenii (36x18) ar acoperi gramada, iar cioburile (24x18) ar disparea langa ei.
local function fitItemSize(sprite: Assets.Sprite): (number, number)
    local scale = NET_ITEM_MAX / math.max(sprite.width, sprite.height)
    return math.round(sprite.width * scale), math.round(sprite.height * scale)
end

-- ---- sacul de pe spatele jucatorului [research 42 pct.3, "sacul e pe spate"] -------------------
-- Creste in TREPTE, nu continuu -- se recalculeaza doar la Apply (cand se schimba sackCount), nu
-- in fiecare cadru. Doar POZITIA lui urmareste personajul in fiecare cadru, ca orice alt indemn
-- din fisierul asta. Pastila din HUD ramane a agentului F (HUDController) -- asta e doar corpul.
local SACK_STEP_SCALE = { 0.55, 0.8, 1.05, 1.3 } -- treapta 1..4
local playerSack: ImageLabel? = nil
local playerSackScale: UIScale? = nil

local function sackStep(count: number, capacity: number): number
    if count <= 0 or capacity <= 0 then
        return 0
    end
    local frac = count / capacity
    if frac >= 1 then
        return 4
    elseif frac >= 0.66 then
        return 3
    elseif frac >= 0.33 then
        return 2
    end
    return 1
end

local function updatePlayerSack()
    if playerSack == nil or playerSackScale == nil then
        return
    end
    local step = sackStep(sackCount, sackCapacity)
    playerSack.Visible = step > 0
    playerSackScale.Scale = SACK_STEP_SCALE[math.max(1, step)]
end

-- Stalpul + funia + plasa + gramada + pastila, construite o singura data per platforma si
-- pastrate pentru totdeauna (pool, nu instante de unica folosinta) [regula "pooled ImageLabels"].
local function ensureAssembly(padId: string, x: number, y: number): Assembly
    local existing = assemblies[padId]
    if existing ~= nil then
        return existing
    end
    local pad = TycoonConfig.byId[padId]
    local padX = if pad ~= nil and pad.x ~= nil then pad.x :: number else x
    local padY = if pad ~= nil and pad.y ~= nil then pad.y :: number else y

    -- radacina: fixa la stalp -- un stalp infipt in ponton nu pluteste, doar plasa (bob, mai jos)
    local root = Instance.new("Frame")
    root.Name = padId
    root.BackgroundTransparency = 1
    root.Position = UDim2.fromOffset(padX, padY)
    root.Size = UDim2.fromOffset(0, 0)
    root.ZIndex = 4
    root.Parent = deps.Plot

    if Assets.has(Assets.tycoon.netpost) then
        local post = Instance.new("ImageLabel")
        post.Name = "Post"
        post.BackgroundTransparency = 1
        post.Image = Assets.url(Assets.tycoon.netpost)
        post.ResampleMode = Enum.ResamplerMode.Pixelated
        post.AnchorPoint = Vector2.new(0.5, 1)
        post.Size = UDim2.fromOffset(POST_W, POST_H)
        post.ZIndex = 4
        post.Parent = root
    end

    -- funia: varful ei sta FIX la varful stalpului; capatul de jos (Size.Y) se recalculeaza in
    -- fiecare cadru dupa unde e plasa ACUM (updateNetMotion) -- altfel s-ar rupe vizual la
    -- leganare/tresarire in loc sa ramana intinsa intre cele doua capete.
    -- INSIGNA DE NIVEL, pe stalp. Pe ecran trebuie sa se vada care plasa a ramas in urma fara sa
    -- deschizi niciun panou -- la ei fiecare statie isi poarta nivelul scris pe ea.
    local levelPill = Instance.new("TextButton")
    levelPill.Name = "Level"
    levelPill.Text = ""
    levelPill.AutoButtonColor = false
    levelPill.AnchorPoint = Vector2.new(0.5, 1)
    levelPill.Position = UDim2.fromOffset(0, 22)
    levelPill.Size = UDim2.fromOffset(56, 22)
    levelPill.BackgroundTransparency = 1
    levelPill.ZIndex = 6
    Widgets.LevelBadge(levelPill, 6)
    levelPill.Parent = root
    -- Insigna SE APASA: scrie "Lv 1", deci e primul loc in care cauti nivelul. Owner-ul n-a gasit
    -- nicaieri cum sa urce o plasa -- panoul exista, dar nu ducea nimic din lume spre el.
    local function openThisNet()
        if deps.OpenStation ~= nil then
            (deps.OpenStation :: (string, string?) -> ())("net", padId)
        end
    end
    levelPill.Activated:Connect(openThisNet)

    local levelLabel =
        Widgets.Label(levelPill, "Lv 1", Theme.TEXT.tiny, Theme.COLOR.onDark, "display")
    levelLabel.AnchorPoint = Vector2.new(0.5, 0.5)
    levelLabel.Position = UDim2.fromScale(0.5, 0.5)
    levelLabel.Size = UDim2.fromOffset(52, 18)
    levelLabel.TextXAlignment = Enum.TextXAlignment.Center
    levelLabel.ZIndex = 7

    local rope = Instance.new("Frame")
    rope.Name = "Rope"
    rope.AnchorPoint = Vector2.new(0.5, 1)
    rope.Position = UDim2.fromOffset(0, -POST_H)
    rope.Size = UDim2.fromOffset(ROPE_WIDTH, 0)
    rope.BackgroundColor3 = Theme.COLOR.woodDark
    rope.BorderSizePixel = 0
    rope.ZIndex = 4
    rope.Parent = root

    -- bob: tot ce se leagana/tresare impreuna -- corpul plasei, gramada si pastila. Pozitia lui
    -- (fata de radacina) se rescrie in fiecare cadru, in updateNetMotion.
    local bob = Instance.new("Frame")
    bob.Name = "Bob"
    bob.BackgroundTransparency = 1
    bob.AnchorPoint = Vector2.new(0.5, 0.5)
    bob.Position = UDim2.fromOffset(x - padX, y - padY)
    bob.Size = UDim2.fromOffset(0, 0)
    bob.ZIndex = 5
    bob.Parent = root

    local body = Instance.new("Frame")
    body.Name = "Body"
    body.BackgroundTransparency = 1
    body.AnchorPoint = Vector2.new(0.5, 0.5)
    body.Size = UDim2.fromOffset(TycoonConfig.NET_DRAW.w, TycoonConfig.NET_DRAW.h)
    body.ZIndex = 5
    body.Parent = bob

    local art: ImageLabel? = nil
    if Assets.has(Assets.tycoon.net_water) then
        local img = Instance.new("ImageLabel")
        img.Name = "Art"
        img.BackgroundTransparency = 1
        img.Image = Assets.url(Assets.tycoon.net_water)
        img.ResampleMode = Enum.ResamplerMode.Pixelated
        img.Size = UDim2.fromScale(1, 1)
        img.ZIndex = 5
        img.Parent = body
        art = img
    else
        -- arta inca nu s-a incarcat: desenul vechi (Assets.net, sau cadrul procedural), cat sa nu
        -- ramana un gol -- regula 6, [F2 spec].
        SceneArt.StyleNet(body)
    end
    local bodyScale = Instance.new("UIScale")
    bodyScale.Parent = body

    -- Si plasa insasi se apasa. Suprafata e un copil al corpului, deci se leagana odata cu el si
    -- ramane mereu exact peste desen, oriunde s-ar muta plasa pe benzi.
    local tap = Instance.new("TextButton")
    tap.Name = "Tap"
    tap.Text = ""
    tap.AutoButtonColor = false
    tap.BackgroundTransparency = 1
    tap.Size = UDim2.fromScale(1, 1)
    tap.ZIndex = 7
    tap.Parent = body
    tap.Activated:Connect(openThisNet)

    -- gramada din plasa: pool FIX de NET_ITEM_CAP ImageLabel-uri, ascunse pana au ce arata --
    -- niciodata create/distruse dupa asta [regula "pooled ImageLabels, fara zgomot de instante"].
    local items: { ImageLabel } = {}
    for i = 1, NET_ITEM_CAP do
        local icon = Instance.new("ImageLabel")
        icon.Name = "Item" .. i
        icon.BackgroundTransparency = 1
        icon.ResampleMode = Enum.ResamplerMode.Pixelated
        icon.AnchorPoint = Vector2.new(0.5, 0.5)
        local slot = NET_ITEM_SLOTS[i]
        icon.Position = UDim2.fromScale(slot[1], slot[2])
        icon.Visible = false
        icon.ZIndex = 6
        icon.Parent = body
        items[i] = icon
    end

    -- "8 / 12" pe pastila mica, agatata de BOB -- se leagana cu plasa, nu sta pe nisip
    -- [research 42 pct.1, "count pill attached to the assembly, not floating on the sand"].
    local countPill = Instance.new("Frame")
    countPill.Name = "Count"
    countPill.AnchorPoint = Vector2.new(0.5, 0)
    countPill.Position = UDim2.new(0.5, 0, 0, TycoonConfig.NET_DRAW.h / 2 + 4)
    countPill.Size = UDim2.fromOffset(96, 28)
    countPill.ZIndex = 6
    Widgets.PillBackground(countPill, 6)
    countPill.Parent = bob

    local label = Instance.new("TextLabel")
    label.Name = "Text"
    label.BackgroundTransparency = 1
    label.Size = UDim2.fromScale(1, 1)
    label.TextColor3 = Theme.COLOR.onDark
    label.TextSize = 20 -- fara corespondent in Theme.TEXT (30/22/18/15/13)
    label.ZIndex = 7
    Theme.applyFont(label, "strong")
    Theme.punch(label) -- pastila sta peste apa, langa plasa
    label.Parent = countPill

    -- [D51] Prima plasa se umple de trei ori mai repede in tutorial. Meniul arata ritmul normal, deci
    -- plasa spune singura de ce acum prinde mai des [D40].
    local boostTag = Widgets.PlateLabel(bob, Strings.NET_FAST_FIRST, Theme.TEXT.tiny, "strong")
    boostTag.Name = "Boost"
    -- la stanga pastilei cu numarul: dedesubt statea peste insigna de nivel de pe stalp, iar in dreapta
    -- e fantoma plasei a doua [vazut in Studio, 2026-09-13]
    boostTag.AnchorPoint = Vector2.new(1, 0)
    boostTag.Position = UDim2.new(0.5, -54, 0, TycoonConfig.NET_DRAW.h / 2 + 7)
    boostTag.Size = UDim2.fromOffset(130, 22)
    boostTag.TextXAlignment = Enum.TextXAlignment.Center
    boostTag.TextColor3 = Theme.COLOR.gold
    boostTag.ZIndex = 7
    boostTag.Visible = false

    local record: Assembly = {
        root = root,
        bob = bob,
        body = body,
        art = art,
        rope = rope,
        bodyScale = bodyScale,
        items = items,
        padX = padX,
        padY = padY,
        lastFull = false,
        levelLabel = levelLabel,
        boostTag = boostTag,
    }
    assemblies[padId] = record
    return record
end

local function refreshLabel(padId: string)
    local snap = nets[padId]
    local assembly = assemblies[padId]
    if snap == nil or assembly == nil then
        return
    end
    local pill = assembly.bob:FindFirstChild("Count") :: Frame
    local count = pill:FindFirstChild("Text") :: TextLabel
    local boosted = snap.boosted == true
    if assembly.boostTag.Visible ~= boosted then
        assembly.boostTag.Visible = boosted
    end
    if snap.count >= snap.capacity then
        count.Text = Strings.NET_FULL_LABEL
        count.TextColor3 = Theme.COLOR.bad
    else
        count.Text = `{snap.count} / {snap.capacity}`
        count.TextColor3 = Theme.COLOR.onDark
    end
end

-- Gramada din plasa: recalculata din `snap.contents` -- vezi NetController.OnCaught pentru cum
-- se tine la zi intre doua TycoonState complete (calea rapida NetCaught nu duce contents).
local function refreshContents(padId: string)
    local snap = nets[padId]
    local assembly = assemblies[padId]
    if snap == nil or assembly == nil then
        return
    end
    local shown = flattenContents(snap.contents)
    for i, icon in assembly.items do
        local goodId = shown[i]
        if goodId == nil then
            icon.Visible = false
            continue
        end
        local sprite = goodSprite(goodId)
        if not Assets.has(sprite) then
            icon.Visible = false
            continue
        end
        icon.Image = Assets.url(sprite)
        local w, h = fitItemSize(sprite)
        icon.Size = UDim2.fromOffset(w, h)
        icon.Visible = true
    end
end

-- Colecteaza plasa asta. Nu exista un remot care sa spuna "refuzat, traista plina" -- verificam AICI,
-- pe ultimul TycoonState cunoscut, inainte sa tragem CollectNet [instructiuni F0, sectiunea lipsa].
local function collect(padId: string)
    if sackCapacity > 0 and sackCount >= sackCapacity then
        -- unde sa te duci depinde de ce duci: bustenii la gater, scandurile la taverna [D49]
        deps.OnToast(if sackRaw > 0 then Strings.SACK_FULL_LOGS else Strings.SACK_FULL_PLANKS)
        return
    end
    deps.Remotes.CollectNet:FireServer(padId)
end

-- [D51] Cardul plasei celei mai apropiate. Ancora de distanta e STALPUL (pad.x, pad.y, pe mal), NU
-- plasa din apa -- vezi comentariul de sus. Collect doar cand are ceva si incape in traista; Upgrade
-- oricand (InteractController il arata dupa prima vanzare).
function NetController.Focus(px: number, py: number): Focus.Focus?
    local bestId: string? = nil
    local bestD = RiverConfig.INTERACT_DISTANCE
    for padId in nets do
        local pad = TycoonConfig.byId[padId]
        if pad ~= nil and pad.x ~= nil and pad.y ~= nil then
            local d = Focus.distance(px, py, pad.x :: number, pad.y :: number)
            if d <= bestD then
                bestId, bestD = padId, d
            end
        end
    end
    if bestId == nil then
        return nil
    end
    local id = bestId :: string
    local snap = nets[id]
    local pad = TycoonConfig.byId[id]
    local action: string? = nil
    local status: string? = nil
    if snap.boosted == true and snap.count < snap.capacity then
        -- [D51] prima plasa, in tutorial: se goleste abia plina (TycoonMath.collectLocked, pe server)
        status = Strings.netFilling(snap.count, snap.capacity)
    elseif snap.count > 0 then
        if sackCapacity > 0 and sackCount >= sackCapacity then
            status = Strings.CARD_SACK_FULL
        else
            local keyHint = if UserInputService.KeyboardEnabled then " (E)" else ""
            action = Strings.promptCollect(keyHint)
        end
    end
    return {
        key = `net:{id}`,
        distance = bestD,
        x = pad.x :: number,
        y = (pad.y :: number) - 56,
        action = action,
        act = if action ~= nil
            then function()
                collect(id)
            end
            else nil,
        status = status,
        upgradeKind = "net",
        upgradeId = id,
    }
end

-- Starea vine din TycoonState, inlocuita in intregime la fiecare mesaj [F0 spec 4.1].
function NetController.Apply(
    list: { NetSnap },
    newSackCount: number,
    newSackCapacity: number,
    lanes: number,
    levels: { [string]: number }?,
    newSackRaw: number?
)
    sackCount, sackCapacity = newSackCount, newSackCapacity
    sackRaw = newSackRaw or sackCount
    currentLanes = lanes
    netLevels = levels or netLevels
    updatePlayerSack()
    local seen: { [string]: boolean } = {}
    for _, snap in list do
        nets[snap.padId] = snap
        seen[snap.padId] = true
        local rec = assemblies[snap.padId]
        if rec ~= nil and rec.levelLabel ~= nil then
            (rec.levelLabel :: TextLabel).Text = `Lv {netLevels[snap.padId] or 1}`
        end
        local assembly = ensureAssembly(snap.padId, snap.x, snap.y)
        if not assembly.root.Visible then
            assembly.root.Visible = true
        end
        refreshLabel(snap.padId)
        refreshContents(snap.padId)
    end
    -- nimic nu se pierde, deci o plasa nu ar trebui sa dispara niciodata -- dar daca totusi
    -- lipseste din starea serverului, mai bine ascunsa decat sa arate o cifra invechita
    for padId, assembly in assemblies do
        if not seen[padId] and assembly.root.Visible then
            assembly.root.Visible = false
        end
    end
end

local function acquireFloater(): Floater
    local free = table.remove(freeFloaters)
    if free ~= nil then
        return free
    end
    local frame = Instance.new("Frame")
    frame.Name = "Float"
    frame.AnchorPoint = Vector2.new(0.5, 0.5)
    frame.BackgroundTransparency = 1
    frame.Size = UDim2.fromOffset(30, 22)
    frame.ZIndex = 5 -- deasupra cutiei plasei (4): pluteste PE apa, spre ea
    frame.Visible = false
    frame.Parent = deps.Plot

    local icon = Instance.new("ImageLabel")
    icon.Name = "Icon"
    icon.BackgroundTransparency = 1
    icon.ResampleMode = Enum.ResamplerMode.Pixelated
    icon.AnchorPoint = Vector2.new(0.5, 0.5)
    icon.Position = UDim2.fromScale(0.5, 0.5)
    icon.ZIndex = 5
    icon.Parent = frame

    local scale = Instance.new("UIScale")
    scale.Parent = frame

    return { frame = frame, icon = icon, scale = scale, mode = nil, bornAt = 0 }
end

local function releaseFloater(rec: Floater)
    rec.frame.Visible = false
    table.insert(freeFloaters, rec)
end

-- Sprite-ul + luciul (obiectele cu nume) al unui bustean. Se aplica o singura data, cand bustenul apare
-- pe drum -- Prng.new e ieftin, dar nu gratuit la zeci de busteni.
local function applyGoodVisual(rec: Floater, good: string)
    local oldGlow = rec.frame:FindFirstChild("Glow")
    if oldGlow ~= nil then
        oldGlow:Destroy()
    end
    local sprite = goodSprite(good)
    if Assets.has(sprite) then
        rec.icon.Image = Assets.url(sprite)
        rec.icon.ImageColor3 = Color3.new(1, 1, 1)
        rec.icon.BackgroundTransparency = 1
        rec.icon.Size = UDim2.fromOffset(
            sprite.width * Assets.PIXEL_SCALE * 0.5,
            sprite.height * Assets.PIXEL_SCALE * 0.5
        )
    else
        -- placeholder cat timp lipseste sprite-ul (reeds/scrap/shards inainte de arta F1)
        rec.icon.Image = ""
        rec.icon.BackgroundTransparency = 0
        rec.icon.BackgroundColor3 = if good == "named"
            then Theme.COLOR.gold
            else Color3.fromRGB(150, 105, 60)
        rec.icon.Size = UDim2.fromOffset(20, 16)
        local iconCorner = Instance.new("UICorner")
        iconCorner.CornerRadius = UDim.new(0, 4)
        iconCorner.Parent = rec.icon
    end
    if good == "named" then
        -- luciu discret: tierul ramane secret pana la prindere, dar "e ceva special" se vede acum
        local glow = Instance.new("UIStroke")
        glow.Name = "Glow"
        glow.Color = Theme.COLOR.gold
        glow.Thickness = 3
        glow.Transparency = 0.2
        glow.Parent = rec.frame
        TweenService:Create(
            glow,
            TweenInfo.new(0.6, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true),
            { Transparency = 0.75 }
        ):Play()
    end
end

-- [F1 spec 4.2, D53] Predictia: acelasi calcul ca pe server (catchSeed + prima tragere + pickGood),
-- deci se stie DINAINTE ce va prinde plasa. Bustenii vin de la marginea lumii pe curentul de langa plase
-- si intra exact la momentul prinderii (CatchFloat); la o plasa plina trec pe langa.
-- Leganarea plaselor + tresarirea de la ultima prindere. Ruleaza in aceeasi bucla cu plutirile:
-- o a doua conexiune PreRender ar costa mai mult decat calculul in sine (12 plase, un sinus).
local function updateNetMotion(now: number)
    for padId, snap in nets do
        local assembly = assemblies[padId]
        if assembly == nil or not assembly.root.Visible then
            continue
        end
        local full = snap.count >= snap.capacity
        local dy, scale =
            NetMotion.sample(now, NetMotion.phaseFor(snap.padIndex), full, tugAt[padId])
        if full then
            dy += NET_FULL_SINK -- se lasa mai jos in apa: sufocarea se vede, nu doar se citeste
        end
        netDy[padId] = dy
        local baseX, baseY = snap.x - assembly.padX, snap.y - assembly.padY
        assembly.bob.Position = UDim2.fromOffset(math.round(baseX), math.round(baseY + dy))
        assembly.bodyScale.Scale = scale

        -- funia: de la varful stalpului (fix, local -POST_H) pana la plasa curenta -- recalculata
        -- aici, altfel s-ar rupe vizual de plasa la fiecare leganare/tresarire.
        local ropeLen = math.max(0, -POST_H - (baseY + dy))
        assembly.rope.Size = UDim2.fromOffset(ROPE_WIDTH, math.round(ropeLen))

        -- pline: sprite intunecat + schimbat pe net_water_full -- doar la TRANZITIE, nu in fiecare
        -- cadru (Image/ImageColor3 nu costa nimic la citire, dar scrierea repetata tot n-are rost).
        if assembly.art ~= nil and assembly.lastFull ~= full then
            assembly.lastFull = full
            local sprite = if full and Assets.has(Assets.tycoon.net_water_full)
                then Assets.tycoon.net_water_full
                else Assets.tycoon.net_water
            assembly.art.Image = Assets.url(sprite)
            assembly.art.ImageColor3 = if full
                then Color3.fromRGB(140, 140, 150)
                else Color3.new(1, 1, 1)
        end
    end
end

local function updateFloaters()
    local now = Workspace:GetServerTimeNow()
    updateNetMotion(now)
    for padId, snap in nets do
        local recs = floaters[padId]
        if recs == nil then
            recs = {}
            floaters[padId] = recs
        end
        local assembly = assemblies[padId]
        if assembly == nil or not assembly.root.Visible then
            for key, rec in recs do
                releaseFloater(rec)
                recs[key] = nil
            end
            continue
        end
        local full = snap.count >= snap.capacity
        if full then
            -- plina, ceasul merge mai departe in ritm, ca pe server (TycoonMath.netTick): bustenii
            -- continua sa vina, iar cand o golesti, cei deja pe drum intra
            local _, nextAt =
                TycoonMath.netTick(snap.nextCatchAt, snap.interval, now, snap.count, snap.capacity)
            snap.nextCatchAt = nextAt
        end
        local travel = CatchFloat.travel(snap.x)
        local stride = CatchFloat.stride(snap.interval, travel)
        -- bustenul aterizeaza unde e plasa ACUM, nu unde ar sta ea nemiscata
        local netY = snap.y + (netDy[padId] or 0)
        local seen: { [number]: boolean } = {}
        for _, t in CatchFloat.slots(snap.nextCatchAt, snap.interval, travel, now, stride) do
            local key = math.round(t * 10)
            seen[key] = true
            local rec = recs[key]
            if rec == nil then
                rec = acquireFloater()
                rec.mode = nil
                rec.bornAt = math.max(t - travel, now)
                -- CE bun: acelasi calcul ca pe server, pe indexul prinderii prezise la momentul lui
                local index = snap.caught + math.round((t - snap.nextCatchAt) / snap.interval)
                local seed =
                    TycoonMath.catchSeed(LocalPlayer.UserId, snap.padIndex, math.max(0, index))
                applyGoodVisual(rec, TycoonMath.pickGood(Prng.new(seed):nextNumber(), currentLanes))
                recs[key] = rec
            end
            if rec.mode == nil and CatchFloat.inTurn(snap.x, snap.y, t, now) then
                rec.mode = if full then "pass" else "turn"
            end
            local x, y, alpha, scale =
                CatchFloat.at(snap.x, netY, t, now, rec.mode or "turn", key, rec.bornAt)
            rec.frame.Position = UDim2.fromOffset(math.round(x), math.round(y))
            rec.icon.ImageTransparency = alpha
            rec.scale.Scale = scale
            local visible = alpha < 0.98
            if rec.frame.Visible ~= visible then
                rec.frame.Visible = visible
            end
        end
        for key, rec in recs do
            if not seen[key] then
                releaseFloater(rec)
                recs[key] = nil
            end
        end
    end
end

-- Catch-per-catch, mai ieftin decat un TycoonState intreg [F0 spec 1.4/3.4]. Pop vizual la plasa,
-- apoi oglindim local caught/nextCatchAt/contents ca urmatoarea plutire sa porneasca si gramada sa
-- ramana la zi fara sa astepte urmatorul TycoonState [F1 spec 4.2, research 42 pct.2] -- calea
-- rapida (NetCaught) nu duce `contents`, doar server-ul il calculeaza pe deplin.
function NetController.OnCaught(
    padId: string,
    count: number,
    capacity: number,
    good: string,
    catalog: string?,
    tier: string?
)
    local snap = nets[padId]
    if snap ~= nil then
        snap.count = count
        snap.capacity = capacity
        snap.contents[good] = (snap.contents[good] or 0) + 1
    end
    refreshLabel(padId)
    refreshContents(padId)
    tugAt[padId] = Workspace:GetServerTimeNow() -- plasa e trasa in jos de ce tocmai a cazut in ea
    local assembly = assemblies[padId]
    if assembly ~= nil then
        SceneArt.Splash(assembly.body, 0.5, 0.5)
        if good == "named" then
            local item = if catalog ~= nil then ItemConfig.get(catalog) else nil
            local name = if item ~= nil then item.name else "Find"
            local color = TIER_COLORS[tier or "common"] or Theme.COLOR.gold
            Widgets.FloatText(assembly.body, name, color, 8)
        else
            local label = TycoonConfig.GOOD_NAMES[good] or good
            Widgets.FloatText(assembly.body, `+1 {label}`, Theme.COLOR.good, 8)
        end
    end
    if snap ~= nil then
        snap.caught += 1
        snap.nextCatchAt += snap.interval
    end
end

function NetController.Init(d: Deps)
    deps = d

    -- sacul de pe spate [research 42 pct.3]: un singur exemplar, urmareste personajul in fiecare
    -- cadru; marimea (treapta) se schimba doar la Apply, cand sackCount/sackCapacity se schimba.
    if Assets.has(Assets.tycoon.sack) then
        local sack = Instance.new("ImageLabel")
        sack.Name = "PlayerSack"
        sack.BackgroundTransparency = 1
        sack.Image = Assets.url(Assets.tycoon.sack)
        sack.ResampleMode = Enum.ResamplerMode.Pixelated
        sack.AnchorPoint = Vector2.new(0.5, 1)
        sack.Size = UDim2.fromOffset(
            Assets.tycoon.sack.width * TycoonConfig.PROP_SCALE,
            Assets.tycoon.sack.height * TycoonConfig.PROP_SCALE
        )
        sack.ZIndex = 7 -- deasupra personajului (6): se vede clar pe spate, nu ingropat sub el
        sack.Visible = false
        sack.Parent = deps.Plot
        playerSack = sack
        local scale = Instance.new("UIScale")
        scale.Parent = sack
        playerSackScale = scale
    end

    RunService.PreRender:Connect(function()
        local cx, cy = deps.CharacterPos()
        local px, py = toPlotLocal(cx, cy)
        if playerSack ~= nil then
            -- usor sus si intr-o parte fata de picioare (ancora personajului): "pe spate", nu pe
            -- fata lui -- fara logica de directie, ca sa ramana ieftin la 60 de cadre/secunda.
            playerSack.Position = UDim2.fromOffset(math.round(px) + 14, math.round(py) - 44)
        end
    end)
    RunService.PreRender:Connect(updateFloaters)

    deps.Remotes.NetCaught.OnClientEvent:Connect(
        function(
            padId: string,
            count: number,
            capacity: number,
            good: string,
            catalog: string?,
            tier: string?
        )
            NetController.OnCaught(padId, count, capacity, good, catalog, tier)
        end
    )
end

return NetController
