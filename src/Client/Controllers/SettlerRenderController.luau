--!strict
-- Randarea colonistilor: pool fix de ImageLabel, interpolare intre waypoint-urile primite de la server,
-- culling la marginea camerei, sortare pe adancime doar cand se schimba [DECIZII D05, RIVERKEEP 9]
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local AnimConfig = require(ReplicatedStorage.Shared.Config.AnimConfig)
local Assets = require(ReplicatedStorage.Shared.Config.Assets)
local SettlerConfig = require(ReplicatedStorage.Shared.Config.SettlerConfig)
local SceneArt = require(script.Parent.SceneArt)
local CameraController = require(script.Parent.CameraController)
local Theme = require(script.Parent.Parent.UI.Theme)

type Point = { x: number, y: number }
type Settler = {
    id: number,
    name: string,
    job: string,
    tint: number,
    x: number,
    y: number,
    path: { Point },
    legStart: number,
    speed: number,
    facing: string,
    animTime: number, -- ceas propriu de animatie, in cadre
    row: string, -- randul curent din foaie; la schimbare, animatia porneste de la cadrul 0
    needs: { [string]: number },
    task: string,
    targetKind: string?,
    -- infatisarea [D44]. Serverul le trimitea de la inceput, dar upsert nu le copia: randarea
    -- citea nil peste tot si fiecare colonist iesea corp "a", par "short", nuanta 1 -- adica
    -- toti identici, exact problema pe care sistemul de straturi o repara.
    build: string?,
    hair: string?,
    hairColor: number?,
    skin: number?,
    grace: number?, -- secunde pana se hotaraste sa plece; nil daca nu e in pericol
    leaving: number?, -- secunde pana dispare, dupa ce s-a hotarat
    traits: { string },
    frame: Frame?,
}

local SettlerRenderController = {}
local settlers: { [number]: Settler } = {}
local layer: Frame
local pool: { Frame } = {}
local visibleCount = 0
-- ceas per colonist pentru particulele de munca; se sterge cand se opreste din lucru
local sparkClock: { [number]: number } = {}
local selectedId: number? = nil

-- Straturile pornesc singure cand foile ajung pe platforma: pana atunci `Assets.has` da false
-- si totul ramane exact pe calea de acum, cu o singura foaie tintata global.
local layered = Assets.has(Assets.people.body.a) and Assets.has(Assets.people.outfit.Fisher)

local function rgbOf(list: { { number } }, index: number?): Color3
    local c = list[index or 1] or list[1]
    return Color3.fromRGB(c[1], c[2], c[3])
end

local function makeSprite(): Frame
    local holder = Instance.new("Frame")
    holder.Size = UDim2.fromOffset(SettlerConfig.WIDTH, SettlerConfig.HEIGHT)
    holder.AnchorPoint = Vector2.new(0.5, 1)
    holder.BackgroundTransparency = 1
    holder.Visible = false
    holder.ZIndex = 6

    if Assets.has(Assets.shadow) then
        local sh = Instance.new("ImageLabel")
        sh.Name = "Shadow"
        sh.Image = Assets.url(Assets.shadow)
        sh.ResampleMode = Enum.ResamplerMode.Pixelated
        sh.BackgroundTransparency = 1
        sh.AnchorPoint = Vector2.new(0.5, 0.5)
        sh.Position = UDim2.new(0.5, 0, 1, -2)
        sh.Size = UDim2.fromOffset(28, 10)
        sh.ImageTransparency = 0.25
        sh.ZIndex = 5
        sh.Parent = holder
    end

    local pick = Instance.new("TextLabel")
    pick.Name = "Pick"
    pick.AnchorPoint = Vector2.new(0.5, 1)
    pick.Position = UDim2.new(0.5, 0, 0, -6)
    pick.Size = UDim2.fromOffset(36, 36)
    pick.BackgroundTransparency = 1
    pick.Text = "▼"
    pick.TextColor3 = Theme.COLOR.gold
    pick.TextSize = 34 -- fara corespondent in Theme.TEXT (30/22/18/15/13); sageata trebuie sa ramana mare
    pick.Visible = false
    pick.ZIndex = 10
    Theme.applyFont(pick, "strong")
    Theme.punch(pick) -- sageata de selectie sta deasupra capului colonistului, peste lume
    pick.Parent = holder

    local warn = Instance.new("TextLabel")
    warn.Name = "Warn"
    warn.AnchorPoint = Vector2.new(0.5, 1)
    warn.Position = UDim2.new(0.5, 0, 0, -2)
    warn.Size = UDim2.fromOffset(30, 30)
    warn.BackgroundTransparency = 1
    warn.Text = "!"
    warn.TextColor3 = Theme.COLOR.bad
    warn.TextSize = Theme.TEXT.title
    warn.Visible = false
    warn.ZIndex = 9
    Theme.applyFont(warn, "strong")
    Theme.punch(warn) -- semnul de nevoie critica sta deasupra capului colonistului, peste lume
    warn.Parent = holder

    local body = Instance.new("ImageLabel")
    body.Name = "Body"
    body.BackgroundTransparency = 1
    body.Size = UDim2.fromScale(1, 1)
    body.ResampleMode = Enum.ResamplerMode.Pixelated
    body.ZIndex = 6
    if Assets.has(Assets.character_anim) then
        body.Image = Assets.url(Assets.character_anim)
        body.ImageRectSize = Vector2.new(AnimConfig.FRAME_WIDTH, AnimConfig.FRAME_HEIGHT)
    else
        body.BackgroundTransparency = 0
        body.BackgroundColor3 = Color3.fromRGB(63, 127, 191) -- silueta de rezerva cat timp lipseste sprite-ul; nu e o culoare de interfata din Theme
    end
    body.Parent = holder

    -- Straturile [D44]: par si tinuta peste corp. Se creeaza DOAR daca foile chiar exista pe
    -- platforma; altfel raman doua etichete goale care consuma memorie la 80 de oameni degeaba.
    -- Ordinea de desenare e corp -> par -> tinuta: palaria trebuie sa acopere parul.
    if layered then
        for i, name in { "Hair", "Outfit" } do
            local img = Instance.new("ImageLabel")
            img.Name = name
            img.BackgroundTransparency = 1
            img.Size = UDim2.fromScale(1, 1)
            img.ResampleMode = Enum.ResamplerMode.Pixelated
            img.ZIndex = 6 + i
            img.Parent = holder
        end
    end

    holder.Parent = layer
    return holder
end

-- Decupeaza un cadru din foaie. Randurile desenate din profil se oglindesc pentru mers spre stanga
-- (ImageRectSize negativ pe X), asa ca o singura orientare desenata acopera ambele sensuri.
local W, H = AnimConfig.FRAME_WIDTH, AnimConfig.FRAME_HEIGHT

local function setFrame(body: ImageLabel, row: AnimConfig.Row, frameIndex: number, facing: string)
    local mirror = row.side and facing == "left"
    local offset = if mirror
        then Vector2.new(W * frameIndex + W, H * row.index)
        else Vector2.new(W * frameIndex, H * row.index)
    local size = if mirror then Vector2.new(-W, H) else Vector2.new(W, H)
    if body.ImageRectOffset ~= offset then
        body.ImageRectOffset = offset
    end
    if body.ImageRectSize ~= size then
        body.ImageRectSize = size
    end
end

-- Pozitia curenta, interpolata din waypoint-urile serverului si timpul serverului
local function positionAt(s: Settler, t: number): (number, number, boolean)
    local path = s.path
    if #path < 2 then
        return s.x, s.y, false
    end
    local elapsed = t - s.legStart
    for i = 1, #path - 1 do
        local a, b = path[i], path[i + 1]
        local dx, dy = b.x - a.x, b.y - a.y
        local dist = math.sqrt(dx * dx + dy * dy)
        local legTime = math.max(0.05, dist / s.speed)
        if elapsed <= legTime then
            local k = elapsed / legTime
            if math.abs(dx) > math.abs(dy) then
                s.facing = if dx > 0 then "right" else "left"
            elseif dy ~= 0 then
                s.facing = if dy > 0 then "down" else "up"
            end
            return a.x + dx * k, a.y + dy * k, true
        end
        elapsed -= legTime
    end
    local last = path[#path]
    return last.x, last.y, false
end

function SettlerRenderController.VisibleCount(): number
    return visibleCount
end

-- Pozitia curenta a unui colonist (pentru focus de camera din panou)
-- Cine e selectat din panou: primeste o sageata galbena deasupra capului
function SettlerRenderController.SetSelected(id: number?)
    selectedId = id
end

function SettlerRenderController.PositionOf(id: number): (number?, number?)
    local s = settlers[id]
    if s == nil then
        return nil, nil
    end
    return s.x, s.y
end

-- Lista pentru panoul de administrator
function SettlerRenderController.List(): { { [string]: any } }
    local out = {}
    for _, s in settlers do
        table.insert(out, {
            id = s.id,
            name = s.name,
            job = s.job,
            needs = s.needs,
            task = s.task,
            traits = s.traits,
            build = s.build,
            hair = s.hair,
            hairColor = s.hairColor,
            skin = s.skin,
        })
    end
    return out
end

function SettlerRenderController.Count(): number
    local n = 0
    for _ in settlers do
        n += 1
    end
    return n
end

local function upsert(u: { [string]: any }, serverTime: number)
    local s = settlers[u.id]
    if s == nil then
        s = {
            id = u.id,
            name = u.name or "",
            job = u.job or "",
            tint = u.tint or 1,
            x = u.x,
            y = u.y,
            path = {},
            legStart = serverTime,
            speed = u.sp,
            facing = "down",
            animTime = 0,
            row = "",
            needs = u.needs or {},
            task = u.task or "idle",
            targetKind = u.tk,
            traits = u.traits or {},
            frame = nil,
        }
        settlers[u.id] = s
    end
    if u.name then
        s.name = u.name
    end
    if u.job then
        s.job = u.job
    end
    if u.tint then
        s.tint = u.tint
    end
    s.x, s.y, s.speed, s.legStart = u.x, u.y, u.sp, u.t
    if u.needs then
        s.needs = u.needs
    end
    if u.task then
        s.task = u.task
    end
    s.targetKind = u.tk
    -- Se scriu MEREU, chiar si cand serverul trimite nil: cu `if u.gr then`, un colonist care
    -- si-a rezolvat nevoia ar ramane cu numaratoarea aprinsa pentru totdeauna.
    s.grace = u.gr
    s.leaving = u.lv
    if u.traits then
        s.traits = u.traits
    end
    -- statice: vin doar odata cu numele si meseria, deci se scriu cand EXISTA in mesaj
    if u.build then
        s.build = u.build
    end
    if u.hair then
        s.hair = u.hair
    end
    if u.hc then
        s.hairColor = u.hc
    end
    if u.sk then
        s.skin = u.sk
    end
    local pts: { Point } = {}
    for _, p in u.p or {} do
        table.insert(pts, { x = p[1], y = p[2] })
    end
    s.path = pts
end

-- Asociere STABILA colonist -> Frame. Ordinea de parcurgere a tabelelor nu e garantata in Lua,
-- deci fara asta acelasi sprite ar sari de la un colonist la altul si ar clipi.
local freeFrames: { Frame } = {}

local function acquireFrame(s: Settler): Frame?
    if s.frame ~= nil then
        return s.frame
    end
    local frame = table.remove(freeFrames)
    if frame == nil then
        if #pool >= SettlerConfig.HARD_CAP then
            return nil
        end
        frame = makeSprite()
        table.insert(pool, frame)
    end
    s.frame = frame
    return frame
end

local function releaseFrame(s: Settler)
    local frame = s.frame
    if frame == nil then
        return
    end
    s.frame = nil
    if frame.Visible then
        frame.Visible = false
    end
    table.insert(freeFrames, frame)
end

-- Scrie o proprietate doar daca s-a schimbat: fiecare scriere invalideaza cache-ul de UI [D05]
local function setIfChanged(inst: Instance, prop: string, value: any)
    if (inst :: any)[prop] ~= value then
        (inst :: any)[prop] = value
    end
end

local function render(dt: number)
    local t = Workspace:GetServerTimeNow()
    local shown = 0
    for _, s in settlers do
        local x, y, moving = positionAt(s, t)
        s.x, s.y = x, y
        local onScreen = CameraController.IsVisible(
            x - SettlerConfig.WIDTH / 2,
            y - SettlerConfig.HEIGHT,
            SettlerConfig.WIDTH,
            SettlerConfig.HEIGHT
        )
        if not onScreen then
            releaseFrame(s)
            continue
        end
        local frame = acquireFrame(s)
        if frame == nil then
            continue
        end
        shown += 1
        frame.Position = UDim2.fromOffset(math.round(x), math.round(y))
        setIfChanged(frame, "ZIndex", 6 + math.clamp(math.floor(y / 64), 0, 40))

        local body = frame:FindFirstChild("Body") :: ImageLabel
        local frameIndex = 0
        local row: AnimConfig.Row? = nil
        if Assets.has(Assets.character_anim) or layered then
            local r = AnimConfig.rowFor(s.task, s.facing, moving, s.targetKind, s.job)
            if r.id ~= s.row then
                s.row = r.id
                s.animTime = 0
            else
                s.animTime += dt * r.fps
            end
            frameIndex = math.floor(s.animTime) % AnimConfig.FRAMES_PER_ROW
            row = r
            setFrame(body, r, frameIndex, s.facing)
        end

        if layered then
            -- corpul e desenat pe o rampa neutra si primeste nuanta de piele prin tint; parul si
            -- tinuta la fel. Asa doi oameni cu aceeasi meserie pot arata complet diferit, dar
            -- poarta aceeasi palarie -- exact cerinta.
            local bodySheet = (Assets.people.body :: any)[s.build or "a"]
            if bodySheet ~= nil then
                setIfChanged(body, "Image", Assets.url(bodySheet))
            end
            setIfChanged(body, "ImageColor3", rgbOf(SettlerConfig.SKIN, s.skin))

            local hair = frame:FindFirstChild("Hair") :: ImageLabel?
            if hair ~= nil and row ~= nil then
                local sheet = (Assets.people.hair :: any)[s.hair or "short"]
                -- "bald" e o foaie goala si nu s-a urcat (id 0): stratul se ascunde, in loc sa
                -- incerce sa incarce rbxassetid://0 la fiecare colonist chel
                if sheet ~= nil and Assets.has(sheet) then
                    setIfChanged(hair, "Image", Assets.url(sheet))
                    setIfChanged(hair, "ImageTransparency", 0)
                else
                    setIfChanged(hair, "ImageTransparency", 1)
                end
                setIfChanged(hair, "ImageColor3", rgbOf(SettlerConfig.HAIR_COLORS, s.hairColor))
                setFrame(hair, row, frameIndex, s.facing)
            end

            local outfit = frame:FindFirstChild("Outfit") :: ImageLabel?
            if outfit ~= nil and row ~= nil then
                -- tinuta NU se tinteaza: culorile ei fixe sunt semnalul de meserie
                local sheet = (Assets.people.outfit :: any)[s.job]
                if sheet ~= nil then
                    setIfChanged(outfit, "Image", Assets.url(sheet))
                    setIfChanged(outfit, "ImageTransparency", 0)
                else
                    setIfChanged(outfit, "ImageTransparency", 1) -- fara meserie inca, fara tinuta
                end
                setFrame(outfit, row, frameIndex, s.facing)
            end
        else
            local tint = SettlerConfig.TINTS[s.tint] or SettlerConfig.TINTS[1]
            setIfChanged(body, "ImageColor3", Color3.fromRGB(tint[1], tint[2], tint[3]))
        end

        local pick = frame:FindFirstChild("Pick") :: TextLabel
        if selectedId == s.id then
            setIfChanged(pick, "Visible", true)
            pick.Position =
                UDim2.new(0.5, 0, 0, -6 - math.floor((0.5 + 0.5 * math.sin(t * 4)) * 10))
        else
            setIfChanged(pick, "Visible", false)
        end

        local worst = 100
        for _, need in SettlerConfig.NEEDS do
            worst = math.min(worst, s.needs[need.id] or 100)
        end
        local warn = frame:FindFirstChild("Warn") :: TextLabel
        if worst < SettlerConfig.NEED_WARN then
            setIfChanged(warn, "Visible", true)
            local pulse = 0.5 + 0.5 * math.sin(t * 5)
            warn.TextTransparency = 0.15 * pulse
            warn.Position = UDim2.new(0.5, 0, 0, -2 - math.floor(pulse * 6))
        else
            setIfChanged(warn, "Visible", false)
        end

        -- Semnul vizibil al muncii, dupa felul postului: frunze la gradina, scantei la atelier,
        -- praf la santier, caldura la vatra. Ritmat, nu la fiecare cadru: la 40 de oameni care
        -- muncesc simultan, o particula per cadru per om ar ineca si ecranul, si procesorul.
        if s.task == "working" and s.targetKind ~= nil then
            sparkClock[s.id] = (sparkClock[s.id] or 0) + dt
            if (sparkClock[s.id] :: number) >= 0.45 then
                sparkClock[s.id] = 0
                SceneArt.WorkSpark(
                    frame,
                    s.targetKind :: string,
                    SettlerConfig.WIDTH,
                    SettlerConfig.HEIGHT
                )
            end
        elseif sparkClock[s.id] ~= nil then
            sparkClock[s.id] = nil
        end

        setIfChanged(frame, "Visible", true)
    end
    visibleCount = shown
end

function SettlerRenderController.Init(deps: {
    Scroll: Frame,
    SettlersFull: RemoteEvent,
    SettlerPaths: RemoteEvent,
    SettlerLeft: RemoteEvent,
    OnToast: (string) -> (),
})
    layer = Instance.new("Frame")
    layer.Name = "SettlerLayer"
    layer.BackgroundTransparency = 1
    layer.Size = UDim2.fromScale(1, 1)
    layer.ZIndex = 6
    layer.Parent = deps.Scroll

    deps.SettlersFull.OnClientEvent:Connect(
        function(list: { { [string]: any } }, serverTime: number)
            for _, old in settlers do
                releaseFrame(old)
            end
            table.clear(settlers)
            for _, u in list do
                upsert(u, serverTime)
            end
        end
    )
    deps.SettlerPaths.OnClientEvent:Connect(
        function(updates: { { [string]: any } }, serverTime: number)
            for _, u in updates do
                upsert(u, serverTime)
            end
        end
    )

    deps.SettlerLeft.OnClientEvent:Connect(function(id: number, name: string)
        local gone = settlers[id]
        if gone ~= nil then
            releaseFrame(gone)
        end
        settlers[id] = nil
        deps.OnToast(`{name} has left on the river.`)
    end)

    RunService.PreRender:Connect(render)
end

return SettlerRenderController
