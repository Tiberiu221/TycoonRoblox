--!strict
-- [D70, pasul k9] FILMUL BARAJULUI, dupa ridicare (O1: 15–20 s, Skip de la secunda 3 la prima vizionare). Cronologia e
-- in DamMath.FILM / `frameAt` (pura, testata); aici doar se deseneaza: benzile negre, textul fiecarei faze, camera care trece
-- peste satul tau de la Wire Works la Landing, amurgul, cartonasul „THE DAM”. Mersul se opreste, panourile se inchid, HUD-ul
-- se stinge. Cu „miscare redusa” (GuiService.ReducedMotionEnabled) camera sare, nu aluneca.
--
-- [D75, lotul A2] Decorul fazelor (DamFilmSet, pur): Works Bell se leagana la clopot; la „people” siluetele pleaca spre rau;
-- la „build” camera urca la rau, plasele de pe linia zidului ies din apa, iar zidul creste din ambele maluri peste schele,
-- cu oamenii la lucru, macaraua, caruta si gramada de piatra. Muzica filmului (MusicController.PlayCue), santierul si
-- inchiderea zidului se aud. Fiecare desen si sunet cu ID 0 lipseste pur si simplu; zidul cade pe piatra simpla.
local GuiService = game:GetService("GuiService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Assets = require(ReplicatedStorage.Shared.Config.Assets)
local DamFilmSet = require(ReplicatedStorage.Shared.Modules.DamFilmSet)
local DamMath = require(ReplicatedStorage.Shared.Modules.DamMath)
local Strings = require(ReplicatedStorage.Shared.Config.Strings)
local TycoonConfig = require(ReplicatedStorage.Shared.Config.TycoonConfig)

local CameraController = require(script.Parent.CameraController)
local CharacterController = require(script.Parent.CharacterController)
local MusicController = require(script.Parent.MusicController)
local NetController = require(script.Parent.NetController)
local RiverRenderController = require(script.Parent.RiverRenderController)
local Panels = require(script.Parent.Panels)
local SoundController = require(script.Parent.SoundController)
local Theme = require(script.Parent.Parent.UI.Theme)
local Widgets = require(script.Parent.Parent.UI.Widgets)

local DamFilm = {}

export type Deps = {
    SetHudVisible: (boolean) -> (),
    Plot: Frame?, -- [D75, lotul A2] terenul satului: decorul filmului se pune peste el, in coordonatele lui
    -- [directorul A2] stratul lumii (CameraController): amurgul se lasa peste teren, iar siluetele stau peste amurg, in lume
    -- (lumina lor de asfintit nu se stinge sub el si nu aluneca fata de camera)
    Scroll: Frame?,
}
local deps: Deps? = nil

local gui: ScreenGui -- de la margine la margine (ScreenInsets.None): amurgul, benzile, cartonasul
local safeGui: ScreenGui -- in zona sigura a telefonului: Skip nu ajunge sub crestatura sau sub bara de jos
local stage: Frame
local topBar: Frame
local bottomBar: Frame
local dusk: Frame
local caption: TextLabel
local card: Frame? = nil -- nil cat Init n-a ajuns la capat: Play nu blocheaza nimic atunci
local cardTitle: TextLabel
local cardSub: TextLabel
local skipButton: TextButton

local SKIP_W, SKIP_H, EDGE = 120, 40, 16
-- [verificatorul k9-k10a] cartonasul singur (filmul pierdut la o iesire): cat sta, apoi cat se ridica peste harta noua
local CARD_HOLD, CARD_FADE = 3, 1
local cardOnly = false
local cardDone: (() -> ())? = nil

local playing = false
local startedAt = 0
local seenBefore = false
local onDone: (() -> ())? = nil
local lastPhase = ""
local reduced = false

-- unde trece camera: de la mijlocul ultimului cartier al satului (Wire Works) la primul (Landing), pe strada; [D75, lotul
-- A2] apoi (`rise`) urca la rau, in dreptul zidului care creste
-- [verificatorul A2] pornirea e in dreptul clopotului Works Bell (la clopot se leagana el), nu in mijlocul cartierului: de
-- acolo, pe 16:9 si pe telefon, clopotul ramanea in afara cadrului
local function panPoint(pan: number, rise: number): (number, number)
    local districts = TycoonConfig.districtsOf(1)
    local first, last = districts[1].deck, districts[#districts].deck
    local bell = DamFilmSet.bell()
    local eastX = if bell ~= nil then bell.x else (last.x0 + last.x1) / 2
    local westX = (first.x0 + first.x1) / 2
    local origin = TycoonConfig.PLOT_ORIGIN
    local x, y = eastX + (westX - eastX) * pan, 1100
    local _, visibleH = CameraController.VisibleSize()
    local riverX, riverY = DamFilmSet.camera(visibleH)
    return origin.x + x + (riverX - x) * rise, origin.y + y + (riverY - y) * rise
end

local panNow, riseNow = 0, 0
local function focusGetter(): (number?, number?)
    if not playing then
        return nil, nil
    end
    return panPoint(panNow, riseNow)
end

-- [D75, lotul A2] DECORUL FILMULUI, facut la Play in terenul satului si sters la capat. Un desen cu ID 0 nu se face.
local S = Assets.PIXEL_SCALE
local P = DamFilmSet.PERSON_SCALE
local CW, CH = DamFilmSet.CELL_W, DamFilmSet.CELL_H
type Figure = { img: ImageLabel, walker: DamFilmSet.Walker?, right: string, left: string? }
-- [directorul A2] in stratul lumii (Scroll): amurgul peste teren (Plot e la 5), oamenii peste amurg
local DUSK_Z = 10
type Set = {
    items: { Instance },
    bell: ImageLabel?,
    north: Frame,
    south: Frame,
    southArt: ImageLabel?,
    scaffold: ImageLabel?,
    edgeN: ImageLabel?,
    edgeS: ImageLabel?,
    crane: ImageLabel?,
    dust: { ImageLabel },
    walkers: { Figure },
    workers: { Figure },
    layer: Frame,
    builtProps: { ImageLabel },
}
local set: Set? = nil
local closedHeard = false
-- [directorul A2] santierul si zidul care se inchide, fata de piesa (amestecul facut in scripts/audio/a2_film.py)
local FILM_BUILD_VOLUME = 0.45
local FILM_CLOSE_VOLUME = 0.7

local function depthZ(y: number): number
    return 5 + math.clamp(math.floor(y / 64), 0, 40)
end

-- Un desen (sau un cadru dintr-o foaie), ancorat jos-mijloc; nil cand nu e urcat.
local function sheet(
    items: { Instance },
    parent: Instance,
    sprite: Assets.Sprite,
    frameW: number,
    frameH: number,
    scale: number,
    name: string
): ImageLabel?
    if not Assets.has(sprite) then
        return nil
    end
    local img = Instance.new("ImageLabel")
    img.Name = name
    img.BackgroundTransparency = 1
    img.Image = Assets.url(sprite)
    img.ResampleMode = Enum.ResamplerMode.Pixelated
    img.AnchorPoint = Vector2.new(0.5, 1)
    img.Size = UDim2.fromOffset(frameW * scale, frameH * scale)
    img.ImageRectSize = Vector2.new(frameW, frameH)
    img.Visible = false
    img.Parent = parent
    table.insert(items, img)
    return img
end

-- Cadrul `frame` din randul `row` al unei foi de oameni (16 x 24); randurile privesc spre dreapta. Spre stanga: foaia
-- desenata spre stanga (lumina asfintitului tot pe stanga), sau, cat nu e urcata, cea oglindita (ca PersonView).
local function personFrame(fig: Figure, row: number, frame: number, facing: string)
    local img = fig.img
    local own = if facing == "left" then fig.left else nil
    local mirror = facing == "left" and own == nil
    local image = own or fig.right
    if img.Image ~= image then
        img.Image = image
    end
    img.ImageRectOffset = Vector2.new(CW * frame + (if mirror then CW else 0), CH * row)
    img.ImageRectSize = Vector2.new(if mirror then -CW else CW, CH)
end

local function figure(
    items: { Instance },
    layer: Frame,
    right: Assets.Sprite,
    left: Assets.Sprite,
    name: string
): Figure?
    local img = sheet(items, layer, right, CW, CH, P, name)
    if img == nil then
        return nil
    end
    return {
        img = img,
        right = Assets.url(right),
        left = if Assets.has(left) then Assets.url(left) else nil,
    }
end

local function buildSet(): Set?
    local d = deps
    local plot = if d ~= nil then d.Plot else nil
    if plot == nil then
        return nil
    end
    local t = Assets.tycoon
    local items: { Instance } = {}
    local wall = DamFilmSet.wall()
    -- [directorul A2] zidul uscat al filmului: fara deversorul, gura turbinei si treapta lor, care ar fi iesit in jumatati
    local wallArt = t.film_wall
    local fullH = wallArt.height * S
    -- cele doua jumatati ale zidului: un cadru care taie desenul zidului lumii 2 (sus, malul de nord; jos, capatul de
    -- sud), sau piatra simpla cat desenul nu e urcat
    local function half(name: string): (Frame, ImageLabel?)
        local clip = Instance.new("Frame")
        clip.Name = name
        clip.BorderSizePixel = 0
        clip.ClipsDescendants = true
        clip.ZIndex = 6
        clip.Visible = false
        clip.Position = UDim2.fromOffset(wall.x0, wall.top)
        clip.Size = UDim2.fromOffset(wall.x1 - wall.x0, 0)
        local art: ImageLabel? = nil
        if Assets.has(wallArt) then
            clip.BackgroundTransparency = 1
            local img = Instance.new("ImageLabel")
            img.BackgroundTransparency = 1
            img.Image = Assets.url(wallArt)
            img.ResampleMode = Enum.ResamplerMode.Pixelated
            img.Size = UDim2.fromOffset(wallArt.width * S, fullH)
            img.ZIndex = 6
            img.Parent = clip
            art = img
        else
            clip.BackgroundColor3 = Color3.fromRGB(128, 124, 116)
            clip.BackgroundTransparency = 0
        end
        clip.Parent = plot
        table.insert(items, clip)
        return clip, art
    end
    local north = half("FilmWallNorth")
    local south, southArt = half("FilmWallSouth")
    local scaffold = sheet(
        items,
        plot,
        t.film_scaffold,
        t.film_scaffold.width,
        t.film_scaffold.height,
        S,
        "FilmScaffold"
    )
    if scaffold ~= nil then
        -- un etaj de schela repetat pe verticala, pe toata deschiderea, fix in lume [verificatorul A2: mutat cu jumatatea de
        -- nord, aluneca]; sub jumatatile de piatra (Z 6), care o acopera pe masura ce cresc
        scaffold.AnchorPoint = Vector2.new(0, 0)
        scaffold.ScaleType = Enum.ScaleType.Tile
        scaffold.TileSize = UDim2.fromOffset(t.film_scaffold.width * S, t.film_scaffold.height * S)
        scaffold.ImageRectSize = Vector2.zero
        scaffold.Position = UDim2.fromOffset(wall.x0, wall.top)
        scaffold.Size = UDim2.fromOffset(wall.x1 - wall.x0, wall.bottom - wall.top)
        scaffold.ZIndex = 5
    end
    local edgeN = sheet(
        items,
        plot,
        t.film_wall_edge_n,
        t.film_wall_edge_n.width,
        t.film_wall_edge_n.height,
        S,
        "FilmEdgeN"
    )
    local edgeS = sheet(
        items,
        plot,
        t.film_wall_edge_s,
        t.film_wall_edge_s.width,
        t.film_wall_edge_s.height,
        S,
        "FilmEdgeS"
    )
    for _, e in { edgeN, edgeS } do
        if e ~= nil then
            e.ZIndex = 7
        end
    end
    local props = DamFilmSet.props()
    local builtProps: { ImageLabel } = {}
    local crane = sheet(
        items,
        plot,
        t.film_crane,
        t.film_crane.width / 2,
        t.film_crane.height,
        S,
        "FilmCrane"
    )
    if crane ~= nil then
        crane.Position = UDim2.fromOffset(props.crane.x, props.crane.y)
        crane.ZIndex = depthZ(props.crane.y)
        table.insert(builtProps, crane)
    end
    for _, p in
        {
            { sprite = t.film_stone_cart, at = props.cart, name = "FilmCart" },
            { sprite = t.film_stone_pile, at = props.pile, name = "FilmPile" },
        }
    do
        local img = sheet(items, plot, p.sprite, p.sprite.width, p.sprite.height, S, p.name)
        if img ~= nil then
            img.Position = UDim2.fromOffset(p.at.x, p.at.y)
            img.ZIndex = depthZ(p.at.y)
            table.insert(builtProps, img)
        end
    end
    local dust: { ImageLabel } = {}
    for i = 1, 2 do
        local img = sheet(
            items,
            plot,
            t.film_dust,
            t.film_dust.width / 3,
            t.film_dust.height,
            S,
            `FilmDust{i}`
        )
        if img ~= nil then
            img.ZIndex = 8
            table.insert(dust, img)
        end
    end
    -- oamenii, in stratul de peste amurg (in lume, la originea terenului), adancimea intre ei dupa talpi
    local scroll = if d ~= nil then d.Scroll else nil
    local layer = Instance.new("Frame")
    layer.Name = "FilmFigures"
    layer.BackgroundTransparency = 1
    layer.Size = UDim2.fromOffset(0, 0)
    layer.Position = UDim2.fromOffset(TycoonConfig.PLOT_ORIGIN.x, TycoonConfig.PLOT_ORIGIN.y)
    layer.ZIndex = if scroll ~= nil then DUSK_Z + 1 else 40
    layer.Parent = scroll or plot
    table.insert(items, layer)
    local walkers: { Figure } = {}
    for i, w in DamFilmSet.walkers() do
        local fig = figure(items, layer, t.film_walkers, t.film_walkers_l, `FilmWalker{i}`)
        if fig ~= nil then
            fig.walker = w
            table.insert(walkers, fig)
        end
    end
    local workers: { Figure } = {}
    for i = 1, #DamFilmSet.workers(0) do
        local fig = figure(items, layer, t.film_workers, t.film_workers_l, `FilmWorker{i}`)
        if fig ~= nil then
            table.insert(workers, fig)
        end
    end
    -- Works Bell, leganat peste desenul platformei lui (acelasi loc, aceeasi marime)
    local bell: ImageLabel? = nil
    local at = DamFilmSet.bell()
    if at ~= nil then
        bell = sheet(
            items,
            plot,
            t.film_works_bell_swing,
            t.film_works_bell_swing.width / 3,
            t.film_works_bell_swing.height,
            S,
            "FilmBell"
        )
        if bell ~= nil then
            bell.Position = UDim2.fromOffset(at.x, at.y)
            bell.ZIndex = 4 -- peste platformele terenului (PadController, Z 3)
        end
    end
    return {
        items = items,
        bell = bell,
        north = north,
        south = south,
        southArt = southArt,
        scaffold = scaffold,
        edgeN = edgeN,
        edgeS = edgeS,
        crane = crane,
        dust = dust,
        walkers = walkers,
        workers = workers,
        layer = layer,
        builtProps = builtProps,
    }
end

local function clearSet()
    local s = set
    set = nil
    if s ~= nil then
        for _, item in s.items do
            item:Destroy()
        end
    end
    NetController.SetFilmLift(nil, nil, nil)
    RiverRenderController.SetCalm(0)
end

local function renderSet(frame: DamMath.FilmFrame, t: number)
    local s = set
    local x0, x1 = DamFilmSet.liftRange()
    local atRiver = frame.phase == "build" or frame.phase == "card"
    local lift = if atRiver then frame.rise else 0
    NetController.SetFilmLift(x0, x1, lift)
    -- [verificatorul A2] cat urca zidul, raul se linisteste: nimic nu mai pluteste prin zid sau spre plasele scoase
    RiverRenderController.SetCalm(lift)
    if s == nil then
        return
    end
    local bell = s.bell
    if bell ~= nil then
        bell.Visible = frame.phase == "bells"
        local f = DamFilmSet.bellFrame(t)
        bell.ImageRectOffset = Vector2.new(f * bell.ImageRectSize.X, 0)
    end
    -- siluetele, de la „people” pana la capat
    local peopleFrom = DamMath.FILM[3].from
    local walking = t >= peopleFrom
    for i, fig in s.walkers do
        local w = fig.walker :: DamFilmSet.Walker
        fig.img.Visible = walking
        if walking then
            -- [verificatorul A2] apar din amurg, nu dintr-odata
            fig.img.ImageTransparency = 1 - math.clamp((t - peopleFrom) / DamFilmSet.FADE_IN, 0, 1)
            local x, y, moving, facing = DamFilmSet.walkerAt(w, t - peopleFrom)
            fig.img.Position = UDim2.fromOffset(math.round(x), math.round(y))
            fig.img.ZIndex = depthZ(y)
            local step = if moving then math.floor((t + i * 0.13) * DamFilmSet.WALK_FPS) % 4 else 0
            personFrame(fig, w.kind, step, facing)
        end
    end
    -- zidul, schelele si santierul, in „build”
    local building = frame.phase == "build"
    -- [verificatorul A2] zidul inchis, recuzita si oamenii de pe zid raman si sub cartonasul care se lasa (o secunda)
    local shown = atRiver
    local wall = DamFilmSet.wall()
    local northH, southH = DamFilmSet.halves(frame.built)
    s.north.Visible = shown and northH > 0
    s.north.Size = UDim2.fromOffset(wall.x1 - wall.x0, northH)
    s.south.Visible = shown and southH > 0
    s.south.Position = UDim2.fromOffset(wall.x0, wall.bottom - southH)
    s.south.Size = UDim2.fromOffset(wall.x1 - wall.x0, southH)
    local southArt = s.southArt
    if southArt ~= nil then
        southArt.Position = UDim2.fromOffset(0, southH - southArt.Size.Y.Offset)
    end
    local northFront, southFront = wall.top + northH, wall.bottom - southH
    local gap = southFront - northFront
    local scaffold = s.scaffold
    if scaffold ~= nil then
        scaffold.Visible = building and gap > 0
    end
    local edgeN, edgeS = s.edgeN, s.edgeS
    -- [directorul A2] ancorate jos: marginea de nord incepe chiar pe capatul jumatatii (randul 0 pe front), cea de sud se
    -- termina pe al ei; cand golul scade sub ea, marginea de nord pleaca si o inchide cea de sud
    if edgeN ~= nil then
        local h = edgeN.Size.Y.Offset
        edgeN.Visible = building and gap >= h
        edgeN.Position = UDim2.fromOffset((wall.x0 + wall.x1) / 2, northFront + h)
    end
    if edgeS ~= nil then
        edgeS.Visible = building and gap > 0
        edgeS.Position = UDim2.fromOffset((wall.x0 + wall.x1) / 2, southFront)
    end
    local crane = s.crane
    if crane ~= nil then
        crane.ImageRectOffset = Vector2.new((math.floor(t / 0.9) % 2) * crane.ImageRectSize.X, 0)
    end
    for _, p in s.builtProps do
        p.Visible = shown
    end
    -- [directorul A2] praful de nord iese din pietrele care se aseaza (pe marginea neterminata), nu de pe zidul gata
    local fronts =
        { { x = wall.x0 + 100, y = northFront + 15 }, { x = wall.x0 + 150, y = southFront } }
    for i, puff in s.dust do
        puff.Visible = building and gap > 0
        puff.Position = UDim2.fromOffset(fronts[i].x, fronts[i].y)
        puff.ImageRectOffset = Vector2.new((math.floor(t / 0.12 + i) % 3) * puff.ImageRectSize.X, 0)
    end
    local spots = DamFilmSet.workers(frame.built)
    for i, fig in s.workers do
        local spot = spots[i]
        fig.img.Visible = shown and spot ~= nil
        if spot ~= nil then
            fig.img.Position = UDim2.fromOffset(spot.x, spot.y)
            fig.img.ZIndex = depthZ(spot.y)
            personFrame(fig, spot.kind, math.floor((t + i * 0.21) * 7) % 4, spot.facing)
        end
    end
end

-- Cartonasul „THE DAM”: fundalul si textele apar impreuna din negru (`a` = cat de transparente sunt).
local function cardAlpha(a: number)
    local c = card
    if c == nil then
        return
    end
    c.BackgroundTransparency = a
    cardTitle.TextTransparency = a
    cardSub.TextTransparency = a
end

local function finish()
    if not playing then
        return
    end
    playing = false
    -- cartonasul ramane pe ecran: urmeaza reincarcarea (k8), cu acelasi cartonas ca TeleportGui
    local c = card
    if c ~= nil then
        c.Visible = true
    end
    cardAlpha(0)
    skipButton.Visible = false
    caption.Visible = false
    CameraController.ReleaseFocus(focusGetter)
    clearSet()
    MusicController.EndCue()
    local done = onDone
    onDone = nil
    if done ~= nil then
        done()
    end
end

-- [verificatorul k9-k10a] Textul sta in mijlocul benzii de jos si nu ajunge niciodata la Skip: e centrat, iar jumatatea lui
-- se opreste la 8 px de marginea din stanga a butonului (ambele ScreenGui au originea in coltul ecranului).
local function placeCaption()
    local size = stage.AbsoluteSize
    local barH = bottomBar.AbsoluteSize.Y
    local h = math.clamp(barH - 6, 18, 36)
    local half = math.max(60, skipButton.AbsolutePosition.X - 8 - size.X / 2)
    caption.Size = UDim2.fromOffset(math.min(half * 2, size.X * 0.9), h)
    caption.Position = UDim2.fromOffset(size.X / 2, size.Y - barH / 2)
end

local function render(t: number)
    local frame = DamMath.frameAt(t, seenBefore, reduced)
    local barH = 0.12 * frame.bars
    topBar.Size = UDim2.fromScale(1, barH)
    bottomBar.Size = UDim2.fromScale(1, barH)
    panNow = frame.pan
    riseNow = frame.rise
    renderSet(frame, t)
    -- amurgul: se lasa in „people”, ramane in „build”
    local duskAmount = if frame.phase == "people"
        then frame.progress
        elseif frame.phase == "build" or frame.phase == "card" then 1
        else 0
    dusk.BackgroundTransparency = 1 - 0.45 * duskAmount
    local isCard = frame.phase == "card"
    local c = card :: Frame
    c.Visible = isCard
    -- [verificatorul k9-k10a] fundalul si textele apar impreuna din negru, nu textele intai peste sat
    cardAlpha(if reduced then 0 else 1 - math.clamp(frame.progress * 3, 0, 1))
    caption.Visible = not isCard and frame.text ~= nil
    caption.Text = if not isCard then frame.text or "" else ""
    placeCaption()
    skipButton.Visible = frame.skip and not frame.done
    if frame.phase ~= lastPhase then
        lastPhase = frame.phase
        -- [directorul A2] cu piesa filmului urcata, clopotul si clopotelul nu se mai pun peste ea (ea are clopotul ei, in Re)
        local cued = Assets.music.dam_film ~= 0
        if frame.phase == "bells" and not cued then
            SoundController.Play("bell")
        elseif frame.phase == "build" then
            -- [D75, lotul A2] santierul, pe grupul muzicii, la volumul din amestecul facut cu piesa
            MusicController.PlayCueSfx(Assets.sounds.film_build, FILM_BUILD_VOLUME)
        elseif frame.phase == "card" and Assets.sounds.film_close == 0 and not cued then
            SoundController.Play("chime")
        end
    end
    MusicController.CueSync(t)
    -- [D75, lotul A2] zidul se inchide (cu FILM_MEET_BEFORE inaintea cartonasului): piatra, apoi apa care se strange
    if frame.built >= 1 and not closedHeard then
        closedHeard = true
        MusicController.PlayCueSfx(Assets.sounds.film_close, FILM_CLOSE_VOLUME)
    end
    if frame.done then
        finish()
    end
end

local function enter()
    Panels.CloseAll()
    CharacterController.SetLocked(true)
    local d = deps
    if d ~= nil then
        d.SetHudVisible(false)
    end
    gui.Enabled = true
    safeGui.Enabled = true
end

local function leave()
    dusk.BackgroundTransparency = 1 -- amurgul sta in lume: altfel ar ramane peste sat dupa film
    gui.Enabled = false
    safeGui.Enabled = false
    CameraController.ReleaseFocus(focusGetter)
    CharacterController.SetLocked(false)
    local d = deps
    if d ~= nil then
        d.SetHudVisible(true)
    end
end

-- Porneste filmul. `seen`: s-a mai vazut (Skip de la inceput). `done`: la capat sau la Skip (reincarcarea, k8).
-- [verificatorul k9-k10a] Daca desenul filmului n-a putut fi facut (Init a cazut), nu se blocheaza nimic: `done` pleaca
-- direct, ca barajul ridicat sa duca totusi in lumea 2.
function DamFilm.Play(seen: boolean, done: () -> ())
    if playing or cardOnly then
        return
    end
    local c = card
    if c == nil then
        done()
        return
    end
    local ok, value = pcall(function()
        return GuiService.ReducedMotionEnabled
    end)
    reduced = ok and value == true
    seenBefore = seen
    onDone = done
    playing = true
    startedAt = os.clock()
    lastPhase = ""
    closedHeard = false
    enter()
    c.Visible = false
    clearSet()
    local ok2, made = pcall(buildSet)
    set = if ok2 then made else nil
    MusicController.PlayCue(Assets.music.dam_film)
    CameraController.SetFocus(focusGetter)
    render(0)
end

-- [verificatorul k9-k10a] FILMUL PIERDUT: ai iesit din joc in cele 17 s, iar barajul era deja ridicat si salvat. La prima
-- intrare la baraj, doar cartonasul „THE DAM / Your people built this” (filmul are nevoie de satul vechi), care se ridica
-- peste harta noua. `done`: dupa ce s-a vazut (serverul noteaza filmul, ca sa nu mai vina).
function DamFilm.PlayCard(done: () -> ())
    local c = card
    if playing or cardOnly or c == nil then
        done()
        return
    end
    cardOnly = true
    cardDone = done
    startedAt = os.clock()
    enter()
    topBar.Size = UDim2.fromScale(1, 0)
    bottomBar.Size = UDim2.fromScale(1, 0)
    dusk.BackgroundTransparency = 1
    caption.Visible = false
    skipButton.Visible = false
    c.Visible = true
    cardAlpha(0)
    -- [directorul A2] cartonasul singur are finalul piesei filmului (acordul de la secunda 14), nu clopotelul
    if Assets.music.dam_film ~= 0 then
        MusicController.PlayCue(Assets.music.dam_film, DamMath.FILM[#DamMath.FILM].from)
    else
        SoundController.Play("chime")
    end
end

local function renderCard(t: number)
    if t < CARD_HOLD then
        return
    end
    cardAlpha(math.clamp((t - CARD_HOLD) / CARD_FADE, 0, 1))
    if t >= CARD_HOLD + CARD_FADE then
        cardOnly = false
        local c = card
        if c ~= nil then
            c.Visible = false
        end
        MusicController.EndCue()
        leave()
        local done = cardDone
        cardDone = nil
        if done ~= nil then
            done()
        end
    end
end

function DamFilm.Skip()
    if playing then
        finish()
    end
end

-- [D70, pasul k9] sonda din Studio: sare la secunda `t` a filmului (`cinematic:seek:<t>`), ca textele fiecarei faze sa se
-- poata citi fara sa astepti.
function DamFilm.Seek(t: number)
    if playing then
        startedAt = os.clock() - math.max(0, t)
        MusicController.CueSync(t)
    end
end

-- [directorul A2] ecranul „Build the Dam” s-a deschis: piesa filmului se incarca de acum, ca filmul sa porneasca cu ea
function DamFilm.Preload()
    MusicController.Preload(Assets.music.dam_film)
end

function DamFilm.IsPlaying(): boolean
    return playing or cardOnly
end

-- Reincarcarea n-a plecat (Studio, un drum esuat): filmul se ridica, ca ecranul barajului sa spuna ce urmeaza.
function DamFilm.Stop()
    clearSet()
    MusicController.EndCue()
    playing = false
    onDone = nil
    cardOnly = false
    cardDone = nil
    if gui ~= nil then
        leave()
    end
end

function DamFilm.Init(d: Deps)
    deps = d
    local playerGui = Players.LocalPlayer:WaitForChild("PlayerGui") :: PlayerGui
    local function screen(name: string, order: number, insets: Enum.ScreenInsets): ScreenGui
        local g = Instance.new("ScreenGui")
        g.Name = name
        g.IgnoreGuiInset = true
        g.ScreenInsets = insets
        g.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
        g.ResetOnSpawn = false
        g.DisplayOrder = order
        g.Enabled = false
        g.Parent = playerGui
        return g
    end
    -- [verificatorul k9-k10a] de la margine la margine, ca tutorialul si cartonasul drumului (RideScene): altfel pe
    -- telefonul cu crestatura ramane o fasie de sat luminat langa cartonasul negru
    gui = screen("DamFilm", 60, Enum.ScreenInsets.None)
    safeGui = screen("DamFilmControls", 61, Enum.ScreenInsets.DeviceSafeInsets)

    -- un Frame radacina: Widgets citeste ZIndex-ul parintelui, iar un ScreenGui n-are (aici cadea Init-ul inainte)
    local function root(parent: ScreenGui, name: string): Frame
        local f = Instance.new("Frame")
        f.Name = name
        f.Size = UDim2.fromScale(1, 1)
        f.BackgroundTransparency = 1
        f.BorderSizePixel = 0
        f.ZIndex = 1
        f.Parent = parent
        return f
    end
    stage = root(gui, "Stage")
    local controls = root(safeGui, "Controls")

    dusk = Instance.new("Frame")
    dusk.Name = "Dusk"
    dusk.Size = UDim2.fromScale(1, 1)
    dusk.BackgroundColor3 = Color3.fromRGB(70, 34, 52)
    dusk.BackgroundTransparency = 1
    dusk.BorderSizePixel = 0
    dusk.ZIndex = 1
    -- [directorul A2] in lume, peste teren si sub oamenii filmului (stratul lor e DUSK_Z + 1); fara strat, peste ecran
    local scroll = d.Scroll
    if scroll ~= nil then
        dusk.ZIndex = DUSK_Z
        dusk.Parent = scroll
    else
        dusk.Parent = stage
    end

    local function bar(name: string, anchorY: number): Frame
        local f = Instance.new("Frame")
        f.Name = name
        f.AnchorPoint = Vector2.new(0, anchorY)
        f.Position = UDim2.fromScale(0, anchorY)
        f.Size = UDim2.fromScale(1, 0)
        f.BackgroundColor3 = Color3.new(0, 0, 0)
        f.BorderSizePixel = 0
        f.ZIndex = 2
        f.Parent = stage
        return f
    end
    topBar = bar("TopBar", 0)
    bottomBar = bar("BottomBar", 1)

    caption = Widgets.Label(stage, "", Theme.TEXT.heading, Theme.COLOR.onDark, "display")
    caption.AnchorPoint = Vector2.new(0.5, 0.5)
    caption.TextXAlignment = Enum.TextXAlignment.Center
    caption.TextScaled = true
    caption.ZIndex = 3
    Theme.punch(caption, 2)

    local c = Instance.new("Frame")
    c.Name = "Card"
    c.Size = UDim2.fromScale(1, 1)
    c.BackgroundColor3 = Color3.new(0, 0, 0)
    c.BorderSizePixel = 0
    c.Visible = false
    c.ZIndex = 4
    c.Parent = stage
    -- ca ecranul de incarcare si cartonasul drumului (DamScreen): fontul de pixeli, scalat
    cardTitle = Instance.new("TextLabel")
    cardTitle.AnchorPoint = Vector2.new(0.5, 0.5)
    cardTitle.Position = UDim2.fromScale(0.5, 0.46)
    cardTitle.Size = UDim2.fromScale(0.8, 0.12)
    cardTitle.BackgroundTransparency = 1
    cardTitle.TextColor3 = Color3.fromRGB(240, 233, 218)
    cardTitle.Font = Enum.Font.Arcade
    cardTitle.TextScaled = true
    cardTitle.Text = Strings.DAM_CARD_TITLE
    cardTitle.ZIndex = 5
    cardTitle.Parent = c
    cardSub = cardTitle:Clone()
    cardSub.Position = UDim2.fromScale(0.5, 0.58)
    cardSub.Size = UDim2.fromScale(0.8, 0.04)
    cardSub.TextColor3 = Color3.fromRGB(196, 186, 168)
    cardSub.Text = Strings.DAM_CARD_SUB
    cardSub.Parent = c

    skipButton = Widgets.Button(controls, {
        text = Strings.DAM_FILM_SKIP,
        width = SKIP_W,
        height = SKIP_H,
        z = 6,
        onClick = DamFilm.Skip,
    })
    skipButton.AnchorPoint = Vector2.new(1, 1)
    skipButton.Position = UDim2.new(1, -EDGE, 1, -EDGE)
    skipButton.Visible = false
    card = c -- abia acum: Play stie ca desenul e intreg

    RunService.RenderStepped:Connect(function()
        if playing then
            render(os.clock() - startedAt)
        elseif cardOnly then
            renderCard(os.clock() - startedAt)
        end
    end)
end

return DamFilm
