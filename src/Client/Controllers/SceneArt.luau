--!strict
-- Arta procedurala de prototip, doar din primitive UI (fara upload de imagini). Se inlocuieste cu sprite-uri la pasul 4 [DECIZII D23].
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local AnimConfig = require(ReplicatedStorage.Shared.Config.AnimConfig)
local RiverConfig = require(ReplicatedStorage.Shared.Config.RiverConfig)
local WorldDecor = require(ReplicatedStorage.Shared.Modules.WorldDecor)
local Assets = require(ReplicatedStorage.Shared.Config.Assets)
local Theme = require(script.Parent.Parent.UI.Theme)

local SceneArt = {}

local function image(
    parent: Instance,
    s: Assets.Sprite,
    x: number,
    y: number,
    w: number,
    h: number,
    z: number
): ImageLabel
    local img = Instance.new("ImageLabel")
    img.Image = Assets.url(s)
    img.BackgroundTransparency = 1
    img.Position = UDim2.fromOffset(x, y)
    img.Size = UDim2.fromOffset(w, h)
    img.ResampleMode = Enum.ResamplerMode.Pixelated -- pixel-art crocant la marire [DECIZII D23]
    img.ZIndex = z
    img.Parent = parent
    return img
end

local function tiled(
    parent: Instance,
    s: Assets.Sprite,
    x: number,
    y: number,
    w: number,
    h: number,
    z: number
): ImageLabel
    local img = image(parent, s, x, y, w, h, z)
    img.ScaleType = Enum.ScaleType.Tile
    img.TileSize = UDim2.fromOffset(s.width * Assets.PIXEL_SCALE, s.height * Assets.PIXEL_SCALE)
    return img
end

local function frame(
    parent: Instance,
    x: number,
    y: number,
    w: number,
    h: number,
    color: Color3,
    z: number
): Frame
    local f = Instance.new("Frame")
    f.Position = UDim2.fromOffset(x, y)
    f.Size = UDim2.fromOffset(w, h)
    f.BackgroundColor3 = color
    f.BorderSizePixel = 0
    f.ZIndex = z
    f.Parent = parent
    return f
end

local function gradient(parent: Instance, top: Color3, bottom: Color3, rotation: number?)
    local g = Instance.new("UIGradient")
    g.Color = ColorSequence.new(top, bottom)
    g.Rotation = rotation or 90
    g.Parent = parent
end

local function rounded(parent: Instance, radius: number)
    local c = Instance.new("UICorner")
    c.CornerRadius = UDim.new(0, radius)
    c.Parent = parent
end

-- Cer, soare, dealuri, mal, apa cu valuri. Returneaza stratul de apa (pentru animatie).
export type Layers = { Fixed: Frame, Parallax: Frame, Scroll: Frame }

-- Harta de sus. Straturile, de jos in sus: iarba, nisip la maluri, apa care curge, spuma la
-- linia apei, drum, terenul jucatorului, apoi decorul (copaci, tufe, pietre, papura).
-- Decorul se aseaza determinist din seed (WorldDecor), deci lumea arata la fel la fiecare intrare.
local DECOR_COUNT = 130
local DECOR_SEED = 20260910

local function decorSprite(kind: string): Assets.Sprite?
    local sprite = (Assets.props :: any)[kind]
    if sprite ~= nil and Assets.has(sprite) then
        return sprite
    end
    return nil
end

local function buildDecor(scroll: Frame)
    local items = WorldDecor.build(DECOR_SEED, {
        width = RiverConfig.WORLD_WIDTH,
        height = RiverConfig.WORLD_HEIGHT,
        riverTop = RiverConfig.RIVER_TOP,
        riverBottom = RiverConfig.RIVER_BOTTOM,
        plot = RiverConfig.PLOT,
    }, DECOR_COUNT)

    local layer = Instance.new("Frame")
    layer.Name = "DecorLayer"
    layer.BackgroundTransparency = 1
    layer.Size = UDim2.fromScale(1, 1)
    layer.ZIndex = 5
    layer.Parent = scroll

    for _, item in items do
        local sprite = decorSprite(item.kind)
        if sprite == nil then
            continue
        end
        local w = sprite.width * Assets.PIXEL_SCALE
        local h = sprite.height * Assets.PIXEL_SCALE
        local img = image(layer, sprite, 0, 0, w, h, 5)
        -- ancorat la baza: obiectul "sta" pe punctul lui, nu e centrat pe el
        img.AnchorPoint = Vector2.new(0.5, 1)
        img.Position = UDim2.fromOffset(item.x, item.y)
        -- sortare pe adancime, la fel ca la colonisti: ce e mai jos acopera ce e mai sus
        img.ZIndex = 5 + math.clamp(math.floor(item.y / 64), 0, 40)
    end
end

function SceneArt.BuildBackground(layers: Layers)
    local W, H = RiverConfig.WORLD_WIDTH, RiverConfig.WORLD_HEIGHT
    local scroll = layers.Scroll
    local pixel = Assets.has(Assets.water_tile)
    if not pixel then
        local g = frame(scroll, 0, 0, W, H, Color3.new(1, 1, 1), 0)
        gradient(g, Color3.fromRGB(110, 160, 80), Color3.fromRGB(85, 130, 65))
        local water = frame(
            scroll,
            0,
            RiverConfig.RIVER_TOP,
            W,
            RiverConfig.RIVER_BOTTOM - RiverConfig.RIVER_TOP,
            Color3.new(1, 1, 1),
            1
        )
        gradient(water, Color3.fromRGB(70, 140, 175), Color3.fromRGB(35, 90, 130))
        return
    end

    tiled(scroll, Assets.grass_tile, 0, 0, W, H, 0)

    -- nisipul intra sub apa, ca marginea sa nu fie o linie dreapta
    local sandH = Assets.sand_tile.height * Assets.PIXEL_SCALE
    if Assets.has(Assets.sand_tile) then
        tiled(scroll, Assets.sand_tile, 0, RiverConfig.RIVER_TOP - sandH + 20, W, sandH, 1)
        tiled(scroll, Assets.sand_tile, 0, RiverConfig.RIVER_BOTTOM - 20, W, sandH, 1)
    end

    local tileW = Assets.water_tile.width * Assets.PIXEL_SCALE
    local water = tiled(
        scroll,
        Assets.water_tile,
        -tileW,
        RiverConfig.RIVER_TOP,
        W + tileW * 2,
        RiverConfig.RIVER_BOTTOM - RiverConfig.RIVER_TOP,
        1
    )
    -- al doilea strat de apa, translucid si mai lent: da senzatia de adancime fara shader
    local shimmer = tiled(
        scroll,
        Assets.water_tile,
        -tileW,
        RiverConfig.RIVER_TOP,
        W + tileW * 2,
        RiverConfig.RIVER_BOTTOM - RiverConfig.RIVER_TOP,
        2
    )
    shimmer.ImageTransparency = 0.55

    local foamH = if Assets.has(Assets.foam_north)
        then Assets.foam_north.height * Assets.PIXEL_SCALE
        else 0
    local foamTop, foamBottom
    if foamH > 0 then
        foamTop =
            tiled(scroll, Assets.foam_south, -tileW, RiverConfig.RIVER_TOP, W + tileW * 2, foamH, 3)
        foamBottom = tiled(
            scroll,
            Assets.foam_north,
            -tileW,
            RiverConfig.RIVER_BOTTOM - foamH,
            W + tileW * 2,
            foamH,
            3
        )
    end

    local t = 0
    RunService.PreRender:Connect(function(dt: number)
        t += dt
        water.Position = UDim2.fromOffset(-tileW + ((t * 46) % tileW), RiverConfig.RIVER_TOP)
        shimmer.Position = UDim2.fromOffset(-tileW + ((t * 22) % tileW), RiverConfig.RIVER_TOP)
        if foamTop ~= nil and foamBottom ~= nil then
            local drift = -tileW + ((t * 14) % tileW)
            foamTop.Position = UDim2.fromOffset(drift, RiverConfig.RIVER_TOP)
            foamBottom.Position = UDim2.fromOffset(drift, RiverConfig.RIVER_BOTTOM - foamH)
        end
    end)

    if Assets.has(Assets.path_tile) then
        local pathW = 96
        tiled(
            scroll,
            Assets.path_tile,
            900,
            RiverConfig.RIVER_BOTTOM + 24,
            pathW,
            H - RiverConfig.RIVER_BOTTOM - 24,
            1
        )
        tiled(scroll, Assets.path_tile, 900, 1100, W - 900, pathW, 1)
    end

    buildDecor(scroll)
end

-- Personajul jucatorului foloseste aceeasi foaie ca si colonistii; setter-ul isi tine singur
-- ceasul de animatie, ca sa nu duplicam logica in CharacterController.
export type Pose = (moving: boolean, facing: string, dt: number, running: boolean) -> ()

function SceneArt.MakeCharacter(parent: Instance): (GuiObject, Pose)
    local c = RiverConfig.CHARACTER
    if Assets.has(Assets.character_anim) then
        local img = image(parent, Assets.character_anim, 0, 0, c.WIDTH, c.HEIGHT, 6)
        img.AnchorPoint = Vector2.new(0.5, 1)

        -- Straturile jucatorului [D44]. Corpul se deseneaza pe o rampa neutra si primeste nuanta
        -- prin tint, la fel ca la colonisti; tinuta e `keeper`, pe care NICIUN colonist nu o
        -- primeste -- de aici se vede cine e administratorul, nu doar din inelul de sub picioare.
        -- Cat timp foile nu sunt incarcate, ramane foaia dintr-o bucata, netonata, ca acum.
        local playerLayered = Assets.has(Assets.people.body.a)
            and Assets.has(Assets.people.outfit.keeper)
        local extra: { ImageLabel } = {}
        if playerLayered then
            img.Image = Assets.url(Assets.people.body.b)
            img.ImageColor3 = Color3.fromRGB(231, 188, 150)
            for i, sheet in { Assets.people.hair.long, Assets.people.outfit.keeper } do
                local l = Instance.new("ImageLabel")
                l.Name = if i == 1 then "Hair" else "Outfit"
                l.BackgroundTransparency = 1
                l.Image = Assets.url(sheet)
                l.ResampleMode = Enum.ResamplerMode.Pixelated
                l.Size = UDim2.fromScale(1, 1)
                l.ZIndex = 6 + i
                if i == 1 then
                    l.ImageColor3 = Color3.fromRGB(92, 62, 40)
                end
                l.Parent = img
                table.insert(extra, l)
            end
        end
        -- INELUL DE SUB PICIOARE: singurul semn permanent care spune "asta esti tu". Nuanta
        -- singura nu ajunge -- la departare toate siluetele se citesc la fel, iar jucatorul
        -- pierde secunde bune cautandu-se pe ecran. Nu pulseaza: pulsul e limbajul obiectivelor,
        -- si doua lucruri care pulseaza pe acelasi ecran se anuleaza reciproc.
        local ring = Instance.new("Frame")
        ring.Name = "YouRing"
        ring.AnchorPoint = Vector2.new(0.5, 0.5)
        ring.Position = UDim2.new(0.5, 0, 1, -4)
        ring.Size = UDim2.fromOffset(40, 18)
        ring.BackgroundColor3 = Theme.COLOR.gold
        ring.BackgroundTransparency = 0.82
        ring.BorderSizePixel = 0
        ring.ZIndex = 4
        local rc = Instance.new("UICorner")
        rc.CornerRadius = UDim.new(1, 0)
        rc.Parent = ring
        local rs = Instance.new("UIStroke")
        rs.Color = Theme.COLOR.gold
        rs.Thickness = 2
        rs.Transparency = 0.25
        rs.Parent = ring
        ring.Parent = img
        if Assets.has(Assets.shadow) then
            local sh =
                image(img, Assets.shadow, 0, 0, 16 * Assets.PIXEL_SCALE, 6 * Assets.PIXEL_SCALE, 5)
            sh.AnchorPoint = Vector2.new(0.5, 0.5)
            sh.Position = UDim2.new(0.5, 0, 1, -4)
        end
        local w, h = AnimConfig.FRAME_WIDTH, AnimConfig.FRAME_HEIGHT
        img.ImageRectSize = Vector2.new(w, h)
        local animTime = 0
        local currentRow = ""
        local dustClock = 0
        return img,
            function(moving: boolean, facing: string, dt: number, running: boolean)
                -- Alergarea are acum randuri DESENATE (pas lung, ambele picioare in aer, brate
                -- care leagana). Inainte era doar ciclul de mers invartit mai repede.
                local row = if moving and running
                    then AnimConfig.runRow(facing)
                    else AnimConfig.rowFor("idle", facing, moving, nil, nil)
                if row.id ~= currentRow then
                    currentRow = row.id
                    animTime = 0
                else
                    animTime += dt * row.fps
                end
                -- Praf sub picioare: detaliul care face diferenta dintre "sprite care aluneca"
                -- si "cineva care calca pe pamant". Mai des cand alergi.
                if moving then
                    dustClock += dt
                    local every = if running then 0.11 else 0.2
                    if dustClock >= every then
                        dustClock = 0
                        local side = if math.random() < 0.5 then -6 else 6
                        SceneArt.FootDust(img, c.WIDTH / 2 + side, c.HEIGHT - 2, side, running)
                    end
                else
                    dustClock = 0
                end
                local index = math.floor(animTime) % AnimConfig.FRAMES_PER_ROW
                local mirror = row.side and facing == "left"
                local offset = if mirror
                    then Vector2.new(w * index + w, h * row.index)
                    else Vector2.new(w * index, h * row.index)
                local size = if mirror then Vector2.new(-w, h) else Vector2.new(w, h)
                img.ImageRectOffset = offset
                img.ImageRectSize = size
                -- straturile trebuie sa arate ACELASI cadru, altfel palaria ramane in urma capului
                for _, l in extra do
                    l.ImageRectOffset = offset
                    l.ImageRectSize = size
                end
            end
    end
    local body = frame(parent, 0, 0, c.WIDTH, c.HEIGHT, Color3.fromRGB(63, 127, 191), 6)
    body.AnchorPoint = Vector2.new(0.5, 1)
    rounded(body, 6)
    local head = frame(body, 8, 4, c.WIDTH - 16, 24, Color3.fromRGB(241, 200, 160), 7)
    rounded(head, 8)
    local bobT = 0
    return body,
        function(moving: boolean, _facing: string, dt: number)
            bobT = if moving then bobT + dt * 8 else 0
            head.Position = UDim2.fromOffset(8, if math.floor(bobT) % 2 == 1 then 6 else 4)
        end
end

-- Particule (fum de cos, flacara, praf de santier). Toate sunt actualizate de o singura bucla:
-- o conexiune PreRender per cladire ar costa mult mai mult decat o lista parcursa o data.
type Particle = {
    f: Frame,
    host: GuiObject,
    t: number,
    dur: number,
    x: number,
    y: number,
    size: number,
    rise: number,
    sway: number,
    fade: number,
}

local particles: { Particle } = {}
local particleLoop: RBXScriptConnection? = nil

local function stepParticles(dt: number)
    for i = #particles, 1, -1 do
        local p = particles[i]
        if p.host.Parent == nil then
            p.f:Destroy()
            table.remove(particles, i)
            continue
        end
        if not p.host.Visible then
            continue
        end
        p.t += dt
        local k = (p.t % p.dur) / p.dur
        local size = math.round(p.size * (0.55 + k * 1.05))
        p.f.Position = UDim2.fromOffset(
            math.round(p.x + math.sin((p.t + p.x) * 1.8) * p.sway),
            math.round(p.y - k * p.rise)
        )
        p.f.Size = UDim2.fromOffset(size, size)
        -- apare repede si se stinge lin: fara asta, particula ar sari brusc inapoi la opac
        local alpha = math.min(1, k * 6) * (1 - k)
        p.f.BackgroundTransparency = math.clamp(1 - alpha * (1 - p.fade), 0, 1)
    end
end

local function addParticle(
    host: GuiObject,
    color: Color3,
    x: number,
    y: number,
    size: number,
    rise: number,
    dur: number,
    phase: number,
    sway: number,
    fade: number
)
    local f = Instance.new("Frame")
    f.Name = "Particle"
    f.AnchorPoint = Vector2.new(0.5, 1)
    f.BackgroundColor3 = color
    f.BorderSizePixel = 0
    f.Size = UDim2.fromOffset(size, size)
    f.ZIndex = host.ZIndex + 2
    rounded(f, math.max(2, math.floor(size / 3)))
    f.Parent = host
    table.insert(particles, {
        f = f,
        host = host,
        t = phase * dur,
        dur = dur,
        x = x,
        y = y,
        size = size,
        rise = rise,
        sway = sway,
        fade = fade,
    })
    if particleLoop == nil then
        particleLoop = RunService.PreRender:Connect(stepParticles)
    end
end

-- Fum care iese dintr-un cos, pozitionat in fractiuni din cadrul cladirii
function SceneArt.AddSmoke(host: GuiObject, fx: number, fy: number)
    local w, h = host.Size.X.Offset, host.Size.Y.Offset
    local x, y = math.round(w * fx), math.round(h * fy)
    for i = 1, 3 do
        addParticle(
            host,
            Color3.fromRGB(214, 214, 208),
            x,
            y,
            math.round(w * 0.13),
            h * 0.85,
            2.6,
            (i - 1) / 3,
            5,
            0.35
        )
    end
end

-- Flacara care palpaie plus scantei; pentru vatra si pentru forja
function SceneArt.AddFire(host: GuiObject, fx: number, fy: number)
    local w, h = host.Size.X.Offset, host.Size.Y.Offset
    local x, y = math.round(w * fx), math.round(h * fy)
    addParticle(
        host,
        Color3.fromRGB(255, 176, 74),
        x,
        y,
        math.round(w * 0.3),
        h * 0.12,
        0.42,
        0,
        1,
        0.55
    )
    addParticle(
        host,
        Color3.fromRGB(255, 226, 150),
        x,
        y,
        math.round(w * 0.18),
        h * 0.08,
        0.31,
        0.5,
        1,
        0.4
    )
    for i = 1, 2 do
        addParticle(
            host,
            Color3.fromRGB(255, 208, 120),
            x,
            y,
            math.max(3, math.round(w * 0.07)),
            h * 0.9,
            1.5,
            (i - 1) / 2,
            7,
            0.2
        )
    end
end

-- Praf de santier: puffuri joase si maronii cat timp se lucreaza
-- Praf sub picioare. Sta AICI, dupa addParticle, si se cheama prin tabelul modulului din
-- MakeCharacter: campul se cauta la apel, deci ordinea functiilor din fisier nu mai conteaza.
function SceneArt.FootDust(host: GuiObject, x: number, y: number, side: number, running: boolean)
    addParticle(
        host,
        Color3.fromRGB(206, 190, 158),
        x,
        y,
        if running then 7 else 5,
        if running then 14 else 9,
        if running then 0.5 else 0.42,
        0,
        side * 0.6,
        0.35
    )
end

-- Ce se vede deasupra cuiva care MUNCESTE, dupa felul postului. Pana acum toate meseriile
-- foloseau acelasi rand de animatie ("work"), deci un gradinar, un mestesugar si un hangiu
-- aratau identic -- de aici intrebarea "nu inteleg ce face gradinarul". Particulele nu cer
-- sprite-uri noi si spun ce se intampla acolo dintr-o privire.
local WORK_FX: { [string]: { rgb: Color3, size: number, rise: number, sway: number } } = {
    farm = { rgb = Color3.fromRGB(122, 176, 96), size = 5, rise = 13, sway = 7 }, -- frunze
    work = { rgb = Color3.fromRGB(240, 176, 84), size = 3, rise = 9, sway = 3 }, -- scantei
    site = { rgb = Color3.fromRGB(198, 184, 152), size = 5, rise = 10, sway = 4 }, -- praf
    joy = { rgb = Color3.fromRGB(236, 196, 120), size = 4, rise = 15, sway = 9 }, -- caldura
}

function SceneArt.WorkSpark(host: GuiObject, kind: string, w: number, h: number)
    local fx = WORK_FX[kind]
    if fx == nil then
        return
    end
    local side = (math.random() - 0.5) * w * 0.7
    addParticle(host, fx.rgb, w / 2 + side, h * 0.45, fx.size, fx.rise, 0.75, 0, fx.sway, 0.4)
end

function SceneArt.AddDust(host: GuiObject)
    local w, h = host.Size.X.Offset, host.Size.Y.Offset
    for i = 1, 2 do
        addParticle(
            host,
            Color3.fromRGB(198, 178, 143),
            math.round(w * (0.3 + i * 0.22)),
            math.round(h * 0.95),
            math.round(w * 0.12),
            h * 0.3,
            1.9,
            (i - 1) / 2,
            4,
            0.5
        )
    end
end

-- Sarbatoare la terminarea unei cladiri: un salt scurt si un inel care se stinge.
-- `art` trebuie ancorat in centru: UIScale scaleaza si obiectul pe care e pus, nu doar copiii,
-- deci pe un obiect ancorat in coltul stanga-sus cladirea ar sari in diagonala [DECIZII D06].
function SceneArt.Flourish(art: GuiObject, host: GuiObject)
    local scale = art:FindFirstChildOfClass("UIScale") or Instance.new("UIScale")
    scale.Scale = 1.18
    scale.Parent = art
    local pop = TweenService:Create(
        scale,
        TweenInfo.new(0.65, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
        { Scale = 1 }
    )
    pop:Play()

    local ring = Instance.new("Frame")
    ring.Name = "Flourish"
    ring.AnchorPoint = Vector2.new(0.5, 0.5)
    ring.Position = UDim2.fromScale(0.5, 0.7)
    ring.Size = UDim2.fromScale(0.3, 0.2)
    ring.BackgroundTransparency = 1
    ring.ZIndex = host.ZIndex + 3
    rounded(ring, 999)
    local stroke = Instance.new("UIStroke")
    stroke.Thickness = 4
    stroke.Color = Color3.fromRGB(255, 232, 150)
    stroke.Parent = ring
    ring.Parent = host
    local grow = TweenService:Create(
        ring,
        TweenInfo.new(0.8, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
        { Size = UDim2.fromScale(1.5, 1.1) }
    )
    grow:Play()
    local dim = TweenService:Create(
        stroke,
        TweenInfo.new(0.8, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
        { Transparency = 1 }
    )
    dim:Play()
    task.delay(0.9, function()
        ring:Destroy()
    end)
end

-- Barca de sosire. Obiectivul spune "uita-te la apa", deci pe apa trebuie sa se INTAMPLE ceva;
-- pana acum sosirea era doar o linie de text intr-un colt. Barca vine din amonte, incetineste
-- in dreptul terenului (acolo se uita jucatorul), sta cat sa i se citeasca numele, apoi pleaca.
-- Nu blocheaza nimic si nu asteapta nimeni dupa ea.
function SceneArt.ArrivalBoat(scroll: Frame, name: string)
    if not Assets.has(Assets.props.boat) then
        return
    end
    local sprite = Assets.props.boat
    local w = sprite.width * Assets.PIXEL_SCALE
    local h = sprite.height * Assets.PIXEL_SCALE
    local landing, laneY = RiverConfig.LANDING.x, RiverConfig.LANDING.y

    local boat = image(scroll, sprite, math.floor(landing), math.floor(laneY), w, h, 7)
    boat.AnchorPoint = Vector2.new(0.5, 0.5)
    boat.Position = UDim2.fromOffset(-w, laneY) -- intra din afara ecranului, din amonte

    local plate = Instance.new("TextLabel")
    plate.AnchorPoint = Vector2.new(0.5, 1)
    plate.Position = UDim2.new(0.5, 0, 0, -8)
    plate.Size = UDim2.fromOffset(260, 30)
    plate.BackgroundColor3 = Color3.fromRGB(24, 20, 16)
    plate.BackgroundTransparency = 1 -- apare abia cand barca ajunge la mal
    plate.TextColor3 = Color3.fromRGB(255, 236, 186)
    plate.TextTransparency = 1
    plate.TextSize = 20
    plate.Text = `{name} steps ashore`
    plate.ZIndex = 8
    rounded(plate, 8)
    Theme.applyFont(plate, "display")
    plate.Parent = boat

    local function tween(
        obj: Instance,
        seconds: number,
        style: Enum.EasingStyle,
        dir: Enum.EasingDirection,
        goal: { [string]: any }
    )
        local t = TweenService:Create(obj, TweenInfo.new(seconds, style, dir), goal)
        t:Play()
        return t
    end

    -- 1. coboara pe rau si incetineste in dreptul terenului
    local arrive = tween(boat, 4.5, Enum.EasingStyle.Quad, Enum.EasingDirection.Out, {
        Position = UDim2.fromOffset(landing, laneY),
    })
    arrive.Completed:Connect(function()
        tween(plate, 0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.Out, {
            BackgroundTransparency = 0.25,
            TextTransparency = 0,
        })
        -- 2. sta cat se citeste numele, apoi 3. pleaca la vale si se stinge
        task.delay(2.4, function()
            if boat.Parent == nil then
                return
            end
            tween(plate, 0.4, Enum.EasingStyle.Quad, Enum.EasingDirection.In, {
                BackgroundTransparency = 1,
                TextTransparency = 1,
            })
            tween(boat, 4, Enum.EasingStyle.Quad, Enum.EasingDirection.In, {
                Position = UDim2.fromOffset(RiverConfig.WORLD_WIDTH + w, laneY),
                ImageTransparency = 1,
            })
            task.delay(4.2, function()
                boat:Destroy()
            end)
        end)
    end)
end

-- Lada din scanduri; culoarea de accent vine de la tier
function SceneArt.StyleCrate(f: Frame, accent: Color3, tier: string?)
    for _, child in f:GetChildren() do
        child:Destroy()
    end
    local sprite = if tier then (Assets.crate :: any)[tier] else nil
    if sprite ~= nil and Assets.has(sprite) then
        f.BackgroundTransparency = 1
        local img = image(f, sprite, 0, 0, f.Size.X.Offset, f.Size.Y.Offset, f.ZIndex)
        img.Size = UDim2.fromScale(1, 1)
        return
    end
    f.BackgroundTransparency = 0
    f.BackgroundColor3 = Color3.fromRGB(150, 105, 60)
    rounded(f, 5)
    local g = Instance.new("UIGradient")
    g.Color = ColorSequence.new(Color3.fromRGB(190, 140, 85), Color3.fromRGB(120, 80, 45))
    g.Rotation = 90
    g.Parent = f
    local stroke = Instance.new("UIStroke")
    stroke.Thickness = 3
    stroke.Color = accent
    stroke.Parent = f
    for i = 1, 2 do
        local plank = frame(
            f,
            0,
            math.floor(f.Size.Y.Offset * i / 3),
            f.Size.X.Offset,
            2,
            Color3.fromRGB(95, 60, 35),
            f.ZIndex + 1
        )
        plank.BackgroundTransparency = 0.2
    end
    local band =
        frame(f, math.floor(f.Size.X.Offset / 2) - 4, 0, 8, f.Size.Y.Offset, accent, f.ZIndex + 1)
    band.BackgroundTransparency = 0.35
end

-- Plasa: cadru de lemn cu ochiuri din linii
function SceneArt.StyleNet(f: Frame)
    if Assets.has(Assets.net) then
        f.BackgroundTransparency = 1
        local img = image(f, Assets.net, 0, 0, 0, 0, f.ZIndex)
        img.Size = UDim2.fromScale(1, 1)
        return
    end
    f.BackgroundColor3 = Color3.fromRGB(235, 220, 170)
    f.BackgroundTransparency = 0.55
    rounded(f, 8)
    local stroke = f:FindFirstChildOfClass("UIStroke") or Instance.new("UIStroke")
    stroke.Thickness = 4
    stroke.Color = Color3.fromRGB(120, 85, 45)
    stroke.Parent = f
    local w, h = f.Size.X.Offset, f.Size.Y.Offset
    for i = 1, 5 do
        frame(f, math.floor(w * i / 6), 0, 2, h, Color3.fromRGB(250, 240, 200), f.ZIndex).BackgroundTransparency =
            0.3
    end
    for i = 1, 2 do
        frame(f, 0, math.floor(h * i / 3), w, 2, Color3.fromRGB(250, 240, 200), f.ZIndex).BackgroundTransparency =
            0.3
    end
end

return SceneArt
