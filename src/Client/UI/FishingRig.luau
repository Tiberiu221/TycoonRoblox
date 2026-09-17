--!strict
-- [D61] UNDITA, comuna pontonului din sat (PierController) si jetiului din balci (PondController). Scoasa din
-- PierController cand a aparut al doilea loc de pescuit: firul, plutitorul, semnul muscaturii, bara de mulinat,
-- cartonasul cu ce ai prins si pasii dintre ele. Ce tine de fiecare loc vine din afara: unde cade plutitorul, de ce
-- parte stai, cum zboara perlele, ce se intampla cu un lucru adus de rau (doar in sat).
--
-- Pasii, ca in D59: arunci -> astepti -> musca (stropi, "!", sunet, bara) -> tii apasat cat pestele e in zona ->
-- bara plina -> serverul spune ce era. Pleci de unde ai aruncat si aruncarea se anuleaza in liniste: pestele nu era inca
-- al tau. Clientul nu stie ce e in apa pana nu scoate [D13]: primeste doar clipa muscaturii, dificultatea si samanta.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local Assets = require(ReplicatedStorage.Shared.Config.Assets)
local FishConfig = require(ReplicatedStorage.Shared.Config.FishConfig)
local ReelMath = require(ReplicatedStorage.Shared.Modules.ReelMath)
local RiverConfig = require(ReplicatedStorage.Shared.Config.RiverConfig)
local Strings = require(ReplicatedStorage.Shared.Config.Strings)

local CharacterController = require(script.Parent.Parent.Controllers.CharacterController)
local Panels = require(script.Parent.Parent.Controllers.Panels)
local SceneArt = require(script.Parent.Parent.Controllers.SceneArt)
local SoundController = require(script.Parent.Parent.Controllers.SoundController)
local Focus = require(script.Parent.Focus)
local Theme = require(script.Parent.Theme)
local Widgets = require(script.Parent.Widgets)

local FishingRig = {}

export type Cast = {
    castId: number,
    biteAt: number,
    kind: string,
    difficulty: number,
    reelSeed: number,
    treasure: string?,
}

-- Ce ii da un lucru adus de rau locului care stie ce sa faca cu el (satul).
export type Helpers = {
    popResult: (Assets.Sprite?, string, string, string?, Color3) -> (number, number),
    flyPearls: (number, number, number) -> (),
    characterAt: () -> (number, number),
}

export type Options = {
    Layer: Frame, -- stratul in care stau firul, plutitorul si bara
    Origin: Vector2, -- coltul stratului in lume (satul: PLOT_ORIGIN; balciul: 0, 0)
    CharacterPos: () -> (number, number), -- omul tau, in lume
    WorldToHud: (number, number) -> (number, number), -- din coordonatele stratului in HUD
    Remotes: {
        Cast: RemoteEvent,
        CastResult: RemoteEvent,
        Land: RemoteEvent,
        LandResult: RemoteEvent,
    },
    Target: (Cast, string) -> (number, number), -- unde e ce ai pe fir (stratul), dupa partea spre care stai
    SideFor: (Cast?) -> string, -- de ce parte stai: la aruncare (nil) si dupa raspunsul serverului
    IsActionHeld: () -> boolean, -- butonul rotund de pe telefon, tinut apasat
    PearlFly: (number, number, number) -> (), -- din HUD, cate perle
    OnToast: (string, Color3?) -> (),
    OnTreasure: (({ [string]: any }, Helpers) -> ())?, -- satul: comoara agatata
    OnOutfit: ((string) -> ())?, -- jurnalul complet
    OnState: ((string) -> ())?, -- balciul: eticheta ta si semnul de pescuit
    LineZ: number, -- firul, plutitorul, stropii
    Z: number, -- bara si cartonasul, deasupra cardului obiectului
}

export type Rig = {
    cast: () -> (),
    state: () -> string,
    reset: () -> (),
}

local LEAVE_DISTANCE = 40 -- te-ai miscat de unde ai aruncat: aruncarea se anuleaza
local CAST_TIMEOUT = 5 -- fara raspuns de la server, cardul revine
-- varful batului fata de picioare, cu fata spre dreapta: celula (15, hy-8) din randul `fish` al tinutelor jucatorului,
-- la PIXEL_SCALE 3 (scripts/art/settlers.py)
local ROD_TIP_X, ROD_TIP_Y = 22, -58
local BAR_W, BAR_H = 200, 30
local RESULT_SECONDS = 2.4

local function tierColor(difficulty: number): Color3
    local t = RiverConfig.TIERS[math.clamp(difficulty, 1, #RiverConfig.TIERS)]
    return Color3.fromRGB(t.rgb[1], t.rgb[2], t.rgb[3])
end

local function setLine(frame: Frame, ax: number, ay: number, bx: number, by: number)
    local dx, dy = bx - ax, by - ay
    local length = math.sqrt(dx * dx + dy * dy)
    frame.Position = UDim2.fromOffset((ax + bx) / 2, (ay + by) / 2)
    frame.Size = UDim2.fromOffset(length + 1, 2)
    frame.Rotation = math.deg(math.atan2(dy, dx))
    frame.Visible = true
end

function FishingRig.new(o: Options): Rig
    local state = "idle" -- "idle" | "casting" | "waiting" | "reeling" | "landing"
    local cast: Cast? = nil
    local progress = 0
    local side = "right"
    local castSentAt = 0
    local castFromX, castFromY = 0, 0
    local lastReelSound = 0

    -- ---- piesele, facute o singura data ----
    local function line(): Frame
        local f = Instance.new("Frame")
        f.Name = "FishingLine"
        f.AnchorPoint = Vector2.new(0.5, 0.5)
        f.BackgroundColor3 = Color3.fromRGB(226, 232, 238)
        f.BackgroundTransparency = 0.15
        f.BorderSizePixel = 0
        f.ZIndex = o.LineZ
        f.Visible = false
        f.Parent = o.Layer
        return f
    end
    local lineA = line()
    local lineB = line()

    local bobber = Instance.new("ImageLabel")
    bobber.Name = "Bobber"
    bobber.BackgroundTransparency = 1
    bobber.AnchorPoint = Vector2.new(0.5, 0.8)
    bobber.ZIndex = o.LineZ
    bobber.Visible = false
    if Assets.has(Assets.tycoon.bobber) then
        bobber.Image = Assets.url(Assets.tycoon.bobber)
        bobber.ResampleMode = Enum.ResamplerMode.Pixelated
        bobber.Size = UDim2.fromOffset(
            Assets.tycoon.bobber.width * Assets.PIXEL_SCALE,
            Assets.tycoon.bobber.height * Assets.PIXEL_SCALE
        )
    else
        bobber.BackgroundTransparency = 0
        bobber.BackgroundColor3 = Theme.COLOR.bad
        bobber.Size = UDim2.fromOffset(14, 14)
    end
    bobber.Parent = o.Layer

    local splashHost = Instance.new("Frame")
    splashHost.Name = "BiteSplash"
    splashHost.AnchorPoint = Vector2.new(0.5, 0.5)
    splashHost.BackgroundTransparency = 1
    splashHost.Size = UDim2.fromOffset(40, 24)
    splashHost.ZIndex = o.LineZ + 1
    splashHost.Parent = o.Layer

    local biteMark =
        Widgets.Label(o.Layer, Strings.FISH_BITE, Theme.TEXT.title, Theme.COLOR.gold, "display")
    biteMark.Name = "BiteMark"
    biteMark.AnchorPoint = Vector2.new(0.5, 1)
    biteMark.Size = UDim2.fromOffset(40, 36)
    biteMark.TextXAlignment = Enum.TextXAlignment.Center
    biteMark.ZIndex = o.Z
    biteMark.Visible = false
    Theme.punch(biteMark, 3)

    local bar = Instance.new("Frame")
    bar.Name = "ReelBar"
    bar.AnchorPoint = Vector2.new(0.5, 0.5)
    bar.Size = UDim2.fromOffset(BAR_W, BAR_H)
    bar.BackgroundTransparency = 1
    bar.ZIndex = o.Z
    bar.Visible = false
    bar.Parent = o.Layer
    Widgets.PillBackground(bar, o.Z)

    local zone = Instance.new("Frame")
    zone.Name = "Zone"
    zone.AnchorPoint = Vector2.new(0.5, 0.5)
    zone.Position = UDim2.fromScale(0.5, 0.5)
    zone.BackgroundColor3 = Theme.COLOR.gold
    zone.BackgroundTransparency = 0.55
    zone.BorderSizePixel = 0
    zone.ZIndex = o.Z + 1
    zone.Parent = bar
    local zc = Instance.new("UICorner")
    zc.CornerRadius = UDim.new(0, 6)
    zc.Parent = zone

    local marker = Instance.new("ImageLabel")
    marker.Name = "Fish"
    marker.AnchorPoint = Vector2.new(0.5, 0.5)
    marker.BackgroundTransparency = 1
    marker.ResampleMode = Enum.ResamplerMode.Pixelated
    marker.Size = UDim2.fromOffset(32, 28)
    marker.ZIndex = o.Z + 2
    marker.Parent = bar

    local track, fill = Widgets.Bar(bar, BAR_W, 8, Theme.COLOR.good, o.Z)
    track.Position = UDim2.fromOffset(0, BAR_H + 4)

    local hint = Widgets.PlateLabel(bar, "", Theme.TEXT.tiny, "strong")
    hint.AnchorPoint = Vector2.new(0.5, 1)
    hint.Position = UDim2.new(0.5, 0, 0, -6)
    hint.Size = UDim2.fromOffset(170, 22)
    hint.TextXAlignment = Enum.TextXAlignment.Center
    hint.ZIndex = o.Z + 1

    -- ---- pasii ----
    local function setState(s: string)
        state = s
        local onState = o.OnState
        if onState ~= nil then
            onState(s)
        end
    end

    local function characterAt(): (number, number)
        local cx, cy = o.CharacterPos()
        return cx - o.Origin.X, cy - o.Origin.Y
    end

    local function hideWorld()
        lineA.Visible = false
        lineB.Visible = false
        bobber.Visible = false
        biteMark.Visible = false
        bar.Visible = false
    end

    local function reset()
        cast = nil
        progress = 0
        hideWorld()
        CharacterController.SetTask(nil, nil)
        setState("idle")
    end

    local function startCast()
        if state ~= "idle" then
            return
        end
        castSentAt = os.clock()
        castFromX, castFromY = characterAt()
        side = o.SideFor(nil)
        CharacterController.SetTask("fishing", side)
        SoundController.Play("cast")
        setState("casting")
        o.Remotes.Cast:FireServer()
    end

    local function showBar(c: Cast, tx: number, ty: number)
        local spec = ReelMath.spec(c.difficulty)
        -- deasupra lucrului de pe fir, de partea lui: in aval pentru pesti, in amonte pentru ce aduce raul
        local cx = if c.kind == "treasure" then tx + 10 else tx + 35
        bar.Position = UDim2.fromOffset(cx, ty - 84)
        zone.Size = UDim2.fromOffset(math.max(12, spec.zone * 2 * (BAR_W - 20)), BAR_H - 10)
        local sprite = if c.kind == "treasure" and c.treasure ~= nil
            then (Assets.treasure :: any)[c.treasure :: string]
            else Assets.icons.fish
        if sprite ~= nil and Assets.has(sprite) then
            marker.Image = Assets.url(sprite)
            marker.BackgroundTransparency = 1
        else
            marker.Image = ""
            marker.BackgroundTransparency = 0
        end
        -- pestele nu se stie, dar culoarea raritatii lui da (dificultatea): "asta trage tare"
        marker.ImageColor3 = if c.kind == "treasure"
            then Color3.new(1, 1, 1)
            else tierColor(c.difficulty)
        marker.BackgroundColor3 = tierColor(c.difficulty)
        hint.Text = if UserInputService.KeyboardEnabled
            then Strings.FISH_HOLD_KEY
            else Strings.FISH_HOLD_TOUCH
        fill.Size = UDim2.fromScale(0, 1)
        bar.Visible = true
    end

    local function playBite(tx: number, ty: number)
        SoundController.Play("bite")
        splashHost.Position = UDim2.fromOffset(tx, ty)
        SceneArt.Splash(splashHost, 0.5, 0.6)
        biteMark.Position = UDim2.fromOffset(tx, ty - 26)
        biteMark.Visible = true
        local scale = biteMark:FindFirstChildOfClass("UIScale") or Instance.new("UIScale")
        scale.Parent = biteMark
        scale.Scale = 0.4
        TweenService:Create(
            scale,
            TweenInfo.new(0.35, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
            { Scale = 1 }
        ):Play()
        task.delay(1.2, function()
            biteMark.Visible = false
        end)
    end

    -- Rezultatul, deasupra ta: iconita, ce e si cat valoreaza; se ridica si se stinge. Intoarce unde a aparut.
    local function popResult(
        icon: Assets.Sprite?,
        line1: string,
        line2: string,
        tag: string?,
        color: Color3
    ): (number, number)
        local px, py = characterAt()
        local wx, wy = px, py - 84
        local card = Instance.new("Frame")
        card.Name = "CatchResult"
        card.AnchorPoint = Vector2.new(0.5, 1)
        card.Position = UDim2.fromOffset(wx, wy)
        card.Size = UDim2.fromOffset(250, 62)
        card.BackgroundColor3 = Theme.COLOR.plate
        card.BackgroundTransparency = Theme.PLATE_TRANSPARENCY
        card.ZIndex = o.Z + 2
        card.Parent = o.Layer
        local corner = Instance.new("UICorner")
        corner.CornerRadius = UDim.new(0, 10)
        corner.Parent = card
        local stroke = Instance.new("UIStroke")
        stroke.Color = color
        stroke.Thickness = 2
        stroke.Parent = card
        if icon ~= nil and Assets.has(icon) then
            local img = Instance.new("ImageLabel")
            img.BackgroundTransparency = 1
            img.Image = Assets.url(icon)
            img.ResampleMode = Enum.ResamplerMode.Pixelated
            img.AnchorPoint = Vector2.new(0, 0.5)
            img.Position = UDim2.new(0, 8, 0.5, 0)
            local s = math.min(56 / icon.width, 46 / icon.height)
            img.Size = UDim2.fromOffset(icon.width * s, icon.height * s)
            img.ZIndex = o.Z + 3
            img.Parent = card
        end
        local first = Widgets.Label(card, line1, Theme.TEXT.small, Theme.COLOR.onDark, "strong")
        first.Position = UDim2.fromOffset(70, 8)
        first.Size = UDim2.fromOffset(172, 22)
        first.TextTruncate = Enum.TextTruncate.AtEnd
        first.ZIndex = o.Z + 3
        local second = Widgets.Label(card, line2, Theme.TEXT.small, Theme.COLOR.cool, "display")
        second.Position = UDim2.fromOffset(70, 34)
        second.Size = UDim2.fromOffset(100, 20)
        second.ZIndex = o.Z + 3
        if tag ~= nil then
            local t = Widgets.Label(card, tag, Theme.TEXT.tiny, Theme.COLOR.gold, "display")
            t.AnchorPoint = Vector2.new(1, 0)
            t.Position = UDim2.new(1, -8, 0, 36)
            t.Size = UDim2.fromOffset(80, 18)
            t.TextXAlignment = Enum.TextXAlignment.Right
            t.ZIndex = o.Z + 3
        end
        local scale = Instance.new("UIScale")
        scale.Scale = 0.6
        scale.Parent = card
        TweenService:Create(
            scale,
            TweenInfo.new(0.3, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
            { Scale = 1 }
        ):Play()
        task.delay(RESULT_SECONDS, function()
            TweenService:Create(
                card,
                TweenInfo.new(0.4, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
                { Position = UDim2.fromOffset(wx, wy - 30), BackgroundTransparency = 1 }
            ):Play()
            for _, child in card:GetDescendants() do
                if child:IsA("TextLabel") then
                    TweenService:Create(child, TweenInfo.new(0.4), { TextTransparency = 1 }):Play()
                elseif child:IsA("ImageLabel") then
                    TweenService:Create(child, TweenInfo.new(0.4), { ImageTransparency = 1 }):Play()
                elseif child:IsA("UIStroke") then
                    TweenService:Create(child, TweenInfo.new(0.4), { Transparency = 1 }):Play()
                end
            end
            task.delay(0.45, function()
                card:Destroy()
            end)
        end)
        return wx, wy
    end

    -- perlele zboara din rezultat in pastila lor
    local function flyPearls(wx: number, wy: number, pearls: number)
        if pearls <= 0 then
            return
        end
        local hx, hy = o.WorldToHud(wx, wy - 30)
        o.PearlFly(hx, hy, pearls)
    end

    local function onLanded(result: { [string]: any })
        local pearls = if typeof(result.pearls) == "number" then result.pearls else 0
        if result.kind == "treasure" then
            local onTreasure = o.OnTreasure
            if onTreasure ~= nil then
                onTreasure(result, {
                    popResult = popResult,
                    flyPearls = flyPearls,
                    characterAt = characterAt,
                })
            end
            return
        end
        local species = FishConfig.byId[result.species or ""]
        if species == nil then
            return
        end
        local tierIndex = 1
        for i, t in FishConfig.TIERS do
            if t.id == species.tier then
                tierIndex = i
            end
        end
        SoundController.Play("chime", 1 + 0.14 * (tierIndex - 1))
        local tag = if result.isNew
            then Strings.FISH_NEW
            elseif result.isRecord then Strings.FISH_RECORD
            elseif result.baited then Strings.FISH_BAIT_USED
            else nil
        local wx, wy = popResult(
            (Assets.fish :: any)[species.id],
            Strings.fishCaught(species.name, result.size or species.minCm),
            Strings.pearlsGained(pearls),
            tag,
            tierColor(tierIndex)
        )
        flyPearls(wx, wy, pearls)
        local onOutfit = o.OnOutfit
        if typeof(result.outfit) == "string" and onOutfit ~= nil then
            onOutfit(result.outfit)
        end
    end

    local function update(dt: number)
        if state == "idle" then
            return
        end
        local px, py = characterAt()
        -- Pleci de unde ai aruncat: pestele nu era inca al tau. NU si cat se asteapta raspunsul scoaterii: atunci
        -- serverul l-a platit deja, iar un reset ar arunca rezultatul care vine -- fara popup, fara perle [D43].
        if state ~= "landing" and Focus.distance(px, py, castFromX, castFromY) > LEAVE_DISTANCE then
            reset()
            return
        end
        if state == "casting" then
            if os.clock() - castSentAt > CAST_TIMEOUT then
                reset()
            end
            return
        end
        local c = cast :: Cast
        local tx, ty = o.Target(c, side)
        local now = Workspace:GetServerTimeNow()
        local tipX = px + (if side == "left" then -ROD_TIP_X else ROD_TIP_X)
        local tipY = py + ROD_TIP_Y
        -- plutitorul se leagana pe apa; la muscatura se scufunda
        local sink = if state == "waiting"
            then math.sin(os.clock() * 3) * 2
            else 5 + math.sin(os.clock() * 14) * 2
        local by = ty + sink
        if c.kind == "fish" then
            bobber.Position = UDim2.fromOffset(tx, by)
            bobber.Visible = true
        end
        -- firul, lasat putin: doua bucati, cu mijlocul mai jos
        local midX, midY = (tipX + tx) / 2, (tipY + by) / 2 + 10
        setLine(lineA, tipX, tipY, midX, midY)
        setLine(lineB, midX, midY, tx, by - 8)

        if state == "waiting" then
            if now >= c.biteAt then
                setState("reeling")
                playBite(tx, ty)
                showBar(c, tx, ty)
            end
            return
        end
        if state ~= "reeling" then
            return
        end
        local t = now - c.biteAt
        local pos = ReelMath.fishAt(t, c.reelSeed, c.difficulty)
        local inside = ReelMath.inZone(pos, c.difficulty)
        local holding = not Panels.AnyOpen()
            and (UserInputService:IsKeyDown(Enum.KeyCode.E) or o.IsActionHeld())
        local before = progress
        progress = ReelMath.step(progress, dt, holding, inside, c.difficulty)
        marker.Position = UDim2.new(0, 10 + math.clamp(pos, 0, 1) * (BAR_W - 20), 0.5, 0)
        zone.BackgroundTransparency = if inside then 0.25 else 0.55
        fill.Size = UDim2.fromScale(progress, 1)
        fill.BackgroundColor3 = if holding and not inside
            then Theme.COLOR.warn
            else Theme.COLOR.good
        if progress > before and os.clock() - lastReelSound > 0.24 then
            lastReelSound = os.clock()
            SoundController.Play("reel")
        end
        if progress >= 1 then
            setState("landing")
            o.Remotes.Land:FireServer(c.castId)
        end
    end

    o.Remotes.CastResult.OnClientEvent:Connect(
        function(
            castId: number?,
            biteAt: any,
            kind: string?,
            difficulty: number?,
            reelSeed: number?,
            treasure: string?
        )
            if castId == nil then
                -- un refuz intarziat al unei aruncari deja uitate nu are voie sa strice aruncarea de acum
                if state ~= "casting" then
                    return
                end
                reset()
                o.OnToast(
                    Strings.fishRejected(if typeof(biteAt) == "string" then biteAt else ""),
                    Theme.COLOR.bad
                )
                return
            end
            if state ~= "casting" or typeof(biteAt) ~= "number" then
                return -- ai plecat intre timp
            end
            local c: Cast = {
                castId = castId,
                biteAt = biteAt,
                kind = kind or "fish",
                difficulty = difficulty or 1,
                reelSeed = reelSeed or 1,
                treasure = treasure,
            }
            cast = c
            progress = 0
            side = o.SideFor(c)
            CharacterController.SetTask("fishing", side)
            setState("waiting")
        end
    )

    o.Remotes.LandResult.OnClientEvent:Connect(
        function(castId: number, ok: boolean, reason: string?, result: any, wait: number?)
            local c = cast
            if c == nil or castId ~= c.castId then
                return
            end
            if not ok then
                if reason == "too_soon" and typeof(wait) == "number" then
                    -- bara s-a umplut putin inaintea socotelii serverului (cadre, latenta): mai incearca o data
                    task.delay(math.clamp(wait, 0.05, 3) + 0.05, function()
                        local current = cast
                        if state == "landing" and current ~= nil and current.castId == castId then
                            o.Remotes.Land:FireServer(castId)
                        end
                    end)
                    return
                end
                reset()
                o.OnToast(Strings.fishRejected(reason or ""), Theme.COLOR.bad)
                return
            end
            reset()
            if typeof(result) == "table" then
                onLanded(result)
            end
        end
    )

    RunService.PreRender:Connect(update)

    return {
        cast = startCast,
        state = function(): string
            return state
        end,
        reset = reset,
    }
end

return FishingRig
