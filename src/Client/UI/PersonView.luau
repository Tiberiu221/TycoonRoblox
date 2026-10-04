--!strict
-- Un om desenat din straturi [D44]: umbra, corp, par, tinuta, plus un obiect tinut (roaba unui om care
-- cara, scandura unui client). Doar desenul si animatia: unde sta, ce face si daca se poate atinge
-- decide cine il foloseste -- oamenii tai (HandRenderController) si clientii tavernei
-- (DockController) [D50]. Scos din HandRenderController, ca un client sa nu fie o copie a lui.
--
-- [D55] ROABA. Owner-ul: "npc-urile cara driftwood-ul intr-un sac, nu intr-o roaba... si cand le pune apare un
-- ciocan". Oamenii care cara imping o roaba (fasie cu trei vederi) in care se vede CE duc (fasii cu trei
-- trepte); mersul, incarcatul si rasturnatul au randurile lor in foaie. Roaba se lipeste de mainile omului
-- dupa ancorele din scripts/art/preview_d55.py -- aceleasi cifre, ca desenul din joc sa fie cel verificat.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local AnimConfig = require(ReplicatedStorage.Shared.Config.AnimConfig)
local Assets = require(ReplicatedStorage.Shared.Config.Assets)
local TycoonConfig = require(ReplicatedStorage.Shared.Config.TycoonConfig) -- [verificatorul A4] gasirile (lookOf)
local HandConfig = require(ReplicatedStorage.Shared.Config.HandConfig)
local GoodArt = require(script.Parent.GoodArt)
local Modern = require(script.Parent.Modern)

export type Appearance = {
    body: string,
    hair: string,
    skin: { number },
    hairColor: { number },
    outfit: string,
}

export type View = {
    frame: Frame,
    -- x, y = picioarele; facing = "left" | "right" | "up" | "down"; task = "idle" | "working", iar cu roaba
    -- [D55] "push" (merge), "load" (incarca) sau "tip" (rastoarna)
    Pose: (x: number, y: number, task: string, facing: string, moving: boolean, dt: number) -> (),
    SetAppearance: (appearance: Appearance) -> (),
    -- 0 = nu tine nimic; la scandura doar 0/1. [D55] Cu roaba: treapta incarcaturii (0..3).
    SetHeld: (step: number) -> (),
    -- [D55] ce e in roaba: "driftwood" | "planks" | "scrap" | "iron" | "named" | nil
    SetCarry: (kind: string?, step: number) -> (),
    -- [D70] desenul roabei (caruciorul de fier din treapta 2 a modernizarii); aceleasi cadre
    SetBarrowArt: (sprite: Assets.Sprite) -> (),
    -- [verificatorul A2] 0 = ca de obicei, 1 = stins de tot (filmul barajului: oamenii lasa lucrul); straturile isi pastreaza
    -- transparenta lor de baza (umbra 0,25, parul lipsa 1)
    SetFade: (alpha: number) -> (),
    -- [verificatorul A4] ce duce in brate (clientul unui vanzator): marfa tocmai cumparata; nil = neschimbat
    SetHeldGood: (good: string?) -> (),
    Destroy: () -> (),
}

local PersonView = {}

PersonView.WIDTH, PersonView.HEIGHT = 40, 60 -- aceeasi cutie ca la colonisti
local W, H = AnimConfig.FRAME_WIDTH, AnimConfig.FRAME_HEIGHT

-- Sacul creste in TREPTE, ca cel al jucatorului (NetController) [research 42 pct.3].
local SACK_STEP_SCALE = { 0.6, 0.85, 1.05, 1.3 }

-- [D55] ROABA. Un pixel de om = 2.5 px de lume (16x24 -> 40x60); roaba se deseneaza la aceeasi scara, ca
-- pixelii ei sa fie cat ai omului. Ancore (pixeli de celula a omului -> coltul cadrului de roaba 24x20):
-- lateral spre dreapta (13, 2), spre tine (-5, 15), de la tine (-5, -10). `front` = peste om.
local PX = PersonView.WIDTH / W
local BARROW_W, BARROW_H = 24, 20
local LOAD_W, LOAD_H = 16, 9
local BARROW_AT = {
    side = { x = 13, y = 2, front = true, frame = 0, load = { x = 6, y = 2, over = false } },
    down = { x = -5, y = 15, front = true, frame = 1, load = { x = 4, y = 3, over = false } },
    up = { x = -5, y = -10, front = false, frame = 2, load = { x = 4, y = 0, over = true } },
}
-- Roata, in pixeli de cadru lateral: rasturnatul se roteste in jurul ei.
local WHEEL = { x = 19, y = 16 }
-- Inclinarea roabei pe cele patru cadre ale randului `tip`: ridica manerele, varsa, coboara.
local TIP_ANGLE = { 0, 14, 30, 10 }
local LOAD_SPRITE: { [string]: string } = {
    driftwood = "load_logs",
    reeds = "load_logs",
    planks = "load_planks",
    scrap = "load_scrap",
    shards = "load_scrap",
    iron = "load_iron",
    named = "load_crate",
    -- [D65] marfa Morii; cat fasia ei nu e urcata, roaba o poarta pe a perechii (UI/GoodArt)
    parts = "load_parts",
    ore = "load_ore",
    copper = "load_copper",
    -- [D67] marfa Wire Works
    coils = "load_coils",
    battery = "load_battery",
    cell = "load_cell",
    -- [D75, lotul A4] marfa barajului; cat fasia ei nu e urcata, caruciorul o poarta pe a perechii (UI/GoodArt)
    barrel = "load_barrel",
    cable = "load_cable",
    grid = "load_grid",
    crystal = "load_crystal",
    ingot = "load_ingot",
}

local function rgbOf(triple: { number }): Color3
    return Color3.fromRGB(triple[1] or 255, triple[2] or 255, triple[3] or 255)
end

local function setIfChanged(inst: Instance, prop: string, value: any)
    if (inst :: any)[prop] ~= value then
        (inst :: any)[prop] = value
    end
end

-- Decupeaza un cadru din foaia de 16x24: randurile "side" se oglindesc pentru mers spre stanga.
local function setFrame(img: ImageLabel, row: AnimConfig.Row, frameIndex: number, facing: string)
    local mirror = row.side and facing == "left"
    local offset = if mirror
        then Vector2.new(W * frameIndex + W, H * row.index)
        else Vector2.new(W * frameIndex, H * row.index)
    local size = if mirror then Vector2.new(-W, H) else Vector2.new(W, H)
    setIfChanged(img, "ImageRectOffset", offset)
    setIfChanged(img, "ImageRectSize", size)
end

local function layer(parent: Instance, name: string, z: number): ImageLabel
    local img = Instance.new("ImageLabel")
    img.Name = name
    img.BackgroundTransparency = 1
    img.Size = UDim2.fromScale(1, 1)
    img.ResampleMode = Enum.ResamplerMode.Pixelated
    img.ZIndex = z
    img.Parent = parent
    return img
end

-- `held` = "sack" | "plank" | "part" | nil
function PersonView.new(parent: Instance, name: string, held: string?): View
    local holder = Instance.new("Frame")
    holder.Name = name
    holder.Size = UDim2.fromOffset(PersonView.WIDTH, PersonView.HEIGHT)
    holder.AnchorPoint = Vector2.new(0.5, 1)
    holder.BackgroundTransparency = 1
    holder.ZIndex = 6
    holder.Parent = parent

    -- transparenta de baza a fiecarui strat, inmultita cu stingerea (SetFade); la 0, exact ce era
    local fade = 0
    local baseT: { [Instance]: number } = {}
    local function setT(img: ImageLabel, base: number)
        baseT[img] = base
        setIfChanged(
            img,
            "ImageTransparency",
            if fade > 0 then 1 - (1 - base) * (1 - fade) else base
        )
    end

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
        baseT[sh] = 0.25
        sh.ZIndex = 5
        sh.Parent = holder
    end

    -- Straturile [D44] pornesc doar daca foile chiar exista. Fara ele, o silueta simpla tinuta.
    local layered = Assets.has(Assets.people.body.a) and Assets.has(Assets.people.outfit.Fisher)
    local body = layer(holder, "Body", 6)
    if layered then
        body.ImageRectSize = Vector2.new(W, H)
    else
        body.BackgroundTransparency = 0
        body.BackgroundColor3 = Color3.fromRGB(63, 127, 191) -- rezerva cat timp lipsesc foile
    end
    local hair = if layered then layer(holder, "Hair", 7) else nil
    local outfit = if layered then layer(holder, "Outfit", 8) else nil

    -- [D55] Roaba: un cadru gol (se roteste la rasturnat, cu tot ce e in el) cu desenul roabei si incarcatura.
    -- Incarcatura e SORA desenului, nu copilul lui: un copil se deseneaza mereu peste parinte, iar lateral si
    -- spre tine incarcatura trebuie sa stea IN cutie, in spatele peretelui din fata.
    local barrow: Frame? = nil
    local barrowImg: ImageLabel? = nil
    local cargo: ImageLabel? = nil
    local cargoKind: string? = nil
    local cargoStep = 0
    if held == "barrow" and Assets.has(Assets.tycoon.barrow) then
        local rig = Instance.new("Frame")
        rig.Name = "Barrow"
        rig.BackgroundTransparency = 1
        rig.Size = UDim2.fromOffset(BARROW_W * PX, BARROW_H * PX)
        rig.ZIndex = 9
        rig.Parent = holder
        barrow = rig
        local b = Instance.new("ImageLabel")
        b.Name = "Art"
        b.BackgroundTransparency = 1
        b.Image = Assets.url(Modern.barrow()) -- [D70] roaba, sau caruciorul de fier al treptei de acum
        b.ImageRectSize = Vector2.new(BARROW_W, BARROW_H)
        b.ResampleMode = Enum.ResamplerMode.Pixelated
        b.Size = UDim2.fromScale(1, 1)
        b.ZIndex = 2
        b.Parent = rig
        barrowImg = b
        local c = Instance.new("ImageLabel")
        c.Name = "Cargo"
        c.BackgroundTransparency = 1
        c.ImageRectSize = Vector2.new(LOAD_W, LOAD_H)
        c.ResampleMode = Enum.ResamplerMode.Pixelated
        c.Size = UDim2.fromOffset(LOAD_W * PX, LOAD_H * PX)
        c.Visible = false
        c.ZIndex = 1
        c.Parent = rig
        cargo = c
    end

    -- Obiectul tinut: sacul pe spate (creste in trepte), scandura in brate.
    local item: ImageLabel? = nil
    local itemScale: UIScale? = nil
    local sprite: Assets.Sprite? = if held == "sack"
        then Assets.tycoon.sack
        elseif
            held == "plank"
        then Assets.goods.planks -- [D65] clientul Pietei pleaca cu o piesa de masina (desenul ei cand e urcat, altfel al perechii)

        elseif held == "part" then GoodArt.icon("parts") -- [inventarul A4] „good:<marfa>”: clientul unui vanzator pleaca cu ce a cumparat (Depoul, Switch House)

        elseif held ~= nil and string.sub(held, 1, 5) == "good:" then GoodArt.icon(
            string.sub(held, 6)
        )
        else nil
    if sprite ~= nil and Assets.has(sprite) then
        local s = Instance.new("ImageLabel")
        s.Name = if held == "sack" then "Sack" else "Plank"
        s.BackgroundTransparency = 1
        s.Image = Assets.url(sprite)
        s.ResampleMode = Enum.ResamplerMode.Pixelated
        s.AnchorPoint = Vector2.new(0.5, 1)
        if held == "sack" then
            s.Position = UDim2.fromScale(0.5, 0.65)
            s.Size = UDim2.fromOffset(
                sprite.width * Assets.PIXEL_SCALE * 0.55,
                sprite.height * Assets.PIXEL_SCALE * 0.55
            )
        else
            s.Position = UDim2.fromScale(0.5, 0.8)
            s.Size = UDim2.fromOffset(sprite.width * 1.5, sprite.height * 1.5)
        end
        s.ZIndex = 9
        s.Visible = false
        s.Parent = holder
        item = s
        if held == "sack" then
            local scale = Instance.new("UIScale")
            scale.Parent = s
            itemScale = scale
        end
    end

    local appearance: Appearance? = nil
    local animTime = 0
    local rowId = ""

    -- [D55] Roaba lipita de mainile omului, pentru directia si cadrul de acum.
    local function placeBarrow(task: string, facing: string, frameIndex: number)
        local rig, b, c = barrow, barrowImg, cargo
        if rig == nil or b == nil or c == nil then
            return
        end
        local view = if task == "load" or task == "tip"
            then "side"
            elseif facing == "up" or facing == "down" then facing
            else "side"
        local at = BARROW_AT[view]
        local mirror = view == "side" and facing == "left"
        -- rasturnatul: roaba se roteste in jurul rotii, iar incarcatura aluneca in fata si se stinge
        local angle = if task == "tip" then TIP_ANGLE[frameIndex + 1] or 0 else 0
        local cellX = if mirror then W - at.x - BARROW_W else at.x
        -- pozitia coltului cadrului in pixeli ai lui `holder` (40x60, colt sus-stanga)
        local left, top = cellX * PX, at.y * PX
        -- Rotation se invarte in jurul MIJLOCULUI; ca roata sa ramana pe loc, mijlocul se muta cu cat s-ar
        -- fi mutat roata: centru = centru0 + d - R(unghi) * d, cu d = roata fata de mijloc.
        local pivotX = if mirror then BARROW_W - WHEEL.x else WHEEL.x
        local rot = if mirror then -angle else angle
        local dx, dy = (pivotX - BARROW_W / 2) * PX, (WHEEL.y - BARROW_H / 2) * PX
        local rad = math.rad(rot)
        local rx = dx * math.cos(rad) - dy * math.sin(rad)
        local ry = dx * math.sin(rad) + dy * math.cos(rad)
        local cx0, cy0 = left + BARROW_W * PX / 2, top + BARROW_H * PX / 2
        setIfChanged(rig, "AnchorPoint", Vector2.new(0.5, 0.5))
        setIfChanged(rig, "Position", UDim2.fromOffset(cx0 + dx - rx, cy0 + dy - ry))
        setIfChanged(rig, "Rotation", rot)
        setIfChanged(rig, "ZIndex", if at.front then 9 else 4)
        setIfChanged(
            b,
            "ImageRectOffset",
            Vector2.new((at.frame + (if mirror then 1 else 0)) * BARROW_W, 0)
        )
        setIfChanged(
            b,
            "ImageRectSize",
            Vector2.new(if mirror then -BARROW_W else BARROW_W, BARROW_H)
        )
        local loadX = if mirror then BARROW_W - at.load.x - LOAD_W else at.load.x
        local slide = if task == "tip" and frameIndex >= 2 then 4 else 0
        setIfChanged(
            c,
            "Position",
            UDim2.fromOffset((loadX + (if mirror then -slide else slide)) * PX, at.load.y * PX)
        )
        setIfChanged(c, "ZIndex", if at.load.over then 3 else 1)
        setT(c, if task == "tip" and frameIndex == 3 then 0.6 else 0)
        local loadSprite: Assets.Sprite? = nil
        if cargoKind ~= nil then
            loadSprite = GoodArt.pick(cargoKind :: string, function(g: string): Assets.Sprite?
                local key = LOAD_SPRITE[g]
                return if key ~= nil then (Assets.tycoon :: any)[key] else nil
            end) or Assets.tycoon.load_logs
        end
        local show = cargoStep > 0 and loadSprite ~= nil and Assets.has(loadSprite)
        setIfChanged(c, "Visible", show)
        if show then
            setIfChanged(c, "Image", Assets.url(loadSprite))
            local offset = Vector2.new(
                (math.clamp(cargoStep, 1, 3) - 1 + (if mirror then 1 else 0)) * LOAD_W,
                0
            )
            setIfChanged(c, "ImageRectOffset", offset)
            setIfChanged(
                c,
                "ImageRectSize",
                Vector2.new(if mirror then -LOAD_W else LOAD_W, LOAD_H)
            )
        end
    end

    local view: View = {
        frame = holder,
        SetHeldGood = function(good: string?)
            local img = item
            -- o gasire se duce ca lada ei (ca in PileView.goodSprite), cat o marfa: 36 px de lata
            local find = good ~= nil and TycoonConfig.lookOf(good) == "named"
            local bought = if find
                then Assets.crate.common
                elseif good ~= nil then GoodArt.icon(good)
                else nil
            if img == nil or bought == nil or not Assets.has(bought) then
                return
            end
            local k = if find then 36 / bought.width else 1.5
            setIfChanged(img, "Image", Assets.url(bought))
            setIfChanged(img, "Size", UDim2.fromOffset(bought.width * k, bought.height * k))
        end,
        SetFade = function(alpha: number)
            local a = math.clamp(alpha, 0, 1)
            if a == fade then
                return
            end
            fade = a
            for _, d in holder:GetDescendants() do
                if d:IsA("ImageLabel") then
                    local base = baseT[d] or 0
                    setIfChanged(d, "ImageTransparency", 1 - (1 - base) * (1 - a))
                end
            end
            if not layered then
                body.BackgroundTransparency = a
            end
        end,
        SetAppearance = function(a: Appearance)
            appearance = a
        end,
        SetCarry = function(kind: string?, step: number)
            cargoKind = kind
            cargoStep = step
        end,
        SetHeld = function(step: number)
            if barrow ~= nil then
                cargoStep = step
                return
            end
            local img = item
            if img == nil then
                return
            end
            setIfChanged(img, "Visible", step > 0)
            local scale = itemScale
            if scale ~= nil then
                setIfChanged(scale, "Scale", SACK_STEP_SCALE[math.clamp(step, 1, 4)])
            end
        end,
        Pose = function(
            x: number,
            y: number,
            task: string,
            facing: string,
            moving: boolean,
            dt: number
        )
            holder.Position = UDim2.fromOffset(math.round(x), math.round(y))
            setIfChanged(holder, "ZIndex", 6 + math.clamp(math.floor(y / 64), 0, 40))

            local withBarrow = barrow ~= nil
            local row = if withBarrow
                then AnimConfig.barrowRow(task, facing)
                else AnimConfig.rowFor(task, facing, moving, nil, nil)
            if row.id ~= rowId then
                rowId = row.id
                animTime = 0
            elseif withBarrow and not moving and task ~= "load" and task ~= "tip" then
                animTime = 1 -- sta pe loc cu mainile pe manere: un singur cadru, fara pas
            else
                animTime += dt * row.fps
            end
            local frameIndex = math.floor(animTime) % AnimConfig.FRAMES_PER_ROW
            -- incarcatul si rasturnatul se joaca O DATA pe pauza (0.6 s la 5 cadre/s = 3 cadre), apoi raman
            -- pe ultimul cadru: o bucla ar incarca de doua ori aceeasi plasa
            if withBarrow and (task == "load" or task == "tip") then
                frameIndex = math.min(math.floor(animTime), AnimConfig.FRAMES_PER_ROW - 1)
            end
            setFrame(body, row, frameIndex, facing)
            placeBarrow(task, facing, frameIndex)

            local a = appearance
            if a == nil then
                return
            end
            if hair ~= nil or outfit ~= nil then
                local bodySheet = (Assets.people.body :: any)[a.body]
                if bodySheet ~= nil then
                    setIfChanged(body, "Image", Assets.url(bodySheet))
                end
                setIfChanged(body, "ImageColor3", rgbOf(a.skin))
            end
            if hair ~= nil then
                local hairSheet = (Assets.people.hair :: any)[a.hair]
                if hairSheet ~= nil and Assets.has(hairSheet) then
                    setIfChanged(hair, "Image", Assets.url(hairSheet))
                    setT(hair, 0)
                    setIfChanged(hair, "ImageColor3", rgbOf(a.hairColor))
                    setFrame(hair, row, frameIndex, facing)
                else
                    setT(hair, 1) -- chel: foaia nu s-a incarcat (id 0)
                end
            end
            if outfit ~= nil then
                local outfitSheet = (Assets.people.outfit :: any)[a.outfit]
                if outfitSheet == nil or not Assets.has(outfitSheet) then
                    -- [D65] tinuta inca neurcata: omul o poarta pe a meseriei-pereche din Era 1
                    local borrowed = HandConfig.OUTFIT_LOOKS_LIKE[a.outfit]
                    if borrowed ~= nil then
                        outfitSheet = (Assets.people.outfit :: any)[borrowed]
                    end
                end
                if outfitSheet ~= nil and Assets.has(outfitSheet) then
                    setIfChanged(outfit, "Image", Assets.url(outfitSheet))
                    setT(outfit, 0)
                    setFrame(outfit, row, frameIndex, facing)
                else
                    setT(outfit, 1)
                end
            end
        end,
        SetBarrowArt = function(art: Assets.Sprite)
            local b = barrowImg
            if b ~= nil and Assets.has(art) then
                local url = Assets.url(art)
                if b.Image ~= url then
                    b.Image = url
                end
            end
        end,
        Destroy = function()
            holder:Destroy()
        end,
    }
    return view
end

return PersonView
