--!strict
-- Locul unde stai ca sa lucreze o cladire fara om [D50, D56]: inelul de pe jos, placuta de deasupra lui si bucla care
-- ii spune serverului "sunt aici". Pana la D56 era scris direct in SawmillController; forja are acum aceeasi
-- mecanica (fara Smelter topeste doar cat stai langa ea), deci e o singura bucata, folosita de amandoua.
--
-- Serverul nu stie unde stai, deci clientul spune "sunt aici" la intrarea in raza, la iesire si o data la doua
-- secunde cat ramai; serverul tine prezenta trei secunde si o lasa sa expire singura [D49]. Inelul si placuta se
-- vad doar fara om: auriu, pulsand, cand e ceva de lucrat si nu esti acolo; verde ("Cutting — 12 left") cat stai.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Assets = require(ReplicatedStorage.Shared.Config.Assets)
local RiverConfig = require(ReplicatedStorage.Shared.Config.RiverConfig)
local TycoonConfig = require(ReplicatedStorage.Shared.Config.TycoonConfig)
local Theme = require(script.Parent.Theme)
local Widgets = require(script.Parent.Widgets)

local StandRing = {}

export type Options = {
    plot: Frame,
    name: string, -- numele instantelor ("Sawmill", "Forge")
    stand: { x: number, y: number },
    remote: RemoteEvent, -- AtSawmill / AtForge
    -- [D65] locul din FlowConfig, cand `remote` e AtPlace (acelasi remote pentru toate atelierele): pleaca in fata
    place: string?,
    characterPos: () -> (number, number),
    standHere: string, -- "Stand here to cut"
    working: (left: number) -> string, -- "Cutting — 12 left"
    -- cate asteapta sa fie lucrate si daca cladirea are om; fara om, inelul
    state: () -> (number, boolean),
    -- fara el, mereu; forja doar cat e cumparata
    active: (() -> boolean)?,
}

export type Ring = {
    Present: () -> boolean,
    Distance: () -> number,
}

-- Inelul de pe jos: sprite de 32x16 la x3.
local RING_W, RING_H = 96, 48
-- Cat de des se reaminteste serverului ca stai acolo. Sub PRESENCE_SECONDS (3) de pe server, ca prezenta sa nu
-- expire cat timp chiar esti acolo.
local PRESENCE_EVERY = 2
-- Pragul de iesire e mai larg decat cel de intrare: pe marginea razei, un pas mic in fata si inapoi ar trimite
-- "sunt aici / am plecat" la fiecare cadru, iar limita de pe server (3 mesaje, 1 pe secunda) le-ar arunca tocmai
-- pe cele care conteaza.
local PRESENCE_LEAVE_EXTRA = 20

function StandRing.new(o: Options): Ring
    local stand = o.stand
    local origin = TycoonConfig.PLOT_ORIGIN

    local ring: GuiObject
    if Assets.has(Assets.ui.groundring) then
        local img = Instance.new("ImageLabel")
        img.Name = `{o.name}StandRing`
        img.BackgroundTransparency = 1
        img.Image = Assets.url(Assets.ui.groundring)
        img.ResampleMode = Enum.ResamplerMode.Pixelated
        ring = img
    else
        -- arta inca neurcata: acelasi inel, dintr-un chenar rotunjit
        local frame = Instance.new("Frame")
        frame.Name = `{o.name}StandRing`
        frame.BackgroundTransparency = 1
        local corner = Instance.new("UICorner")
        corner.CornerRadius = UDim.new(1, 0)
        corner.Parent = frame
        local stroke = Instance.new("UIStroke")
        stroke.Thickness = 4
        stroke.Parent = frame
        ring = frame
    end
    ring.AnchorPoint = Vector2.new(0.5, 0.5)
    ring.Position = UDim2.fromOffset(stand.x, stand.y - 4)
    ring.Size = UDim2.fromOffset(RING_W, RING_H)
    ring.ZIndex = 2 -- pe jos: sub oameni, sub gramezi
    ring.Visible = false
    ring.Parent = o.plot
    local ringScale = Instance.new("UIScale")
    ringScale.Parent = ring

    local sign = Widgets.PlateLabel(o.plot, o.standHere, Theme.TEXT.body, "strong")
    sign.Name = `{o.name}StandSign`
    sign.AnchorPoint = Vector2.new(0.5, 1)
    sign.Position = UDim2.fromOffset(stand.x, stand.y - RING_H / 2 - 4)
    -- [D67, audit] placa creste dupa text: "Stand here to draw wire" si "Drawing wire — 1200 left" ieseau din 220 px
    local function fit(text: string)
        local width = Theme.textWidth(text, Theme.TEXT.body, "strong") + 2 * Theme.SPACE.sm + 4
        sign.Size = UDim2.fromOffset(math.max(220, math.ceil(width)), 30)
    end
    fit(o.standHere)
    sign.TextXAlignment = Enum.TextXAlignment.Center
    sign.ZIndex = 47 -- [D67, audit] peste banda de adancime a lumii (felinare, oameni), ca numele cladirilor (46)
    sign.Visible = false
    Theme.punch(sign, 2)

    local toldPresent = false
    local lastPresenceAt = 0

    local function distance(): number
        local cx, cy = o.characterPos()
        local dx, dy = cx - origin.x - stand.x, cy - origin.y - stand.y
        return math.sqrt(dx * dx + dy * dy)
    end

    RunService.PreRender:Connect(function()
        local now = os.clock()
        local active = o.active == nil or (o.active :: () -> boolean)()
        local waiting, staffed = o.state()

        -- PREZENTA. Doar fara om: cu el, cladirea merge oricum si nu mai conteaza unde stai.
        local away = distance()
        local here = away <= RiverConfig.INTERACT_DISTANCE
        local inRange = if toldPresent
            then away <= RiverConfig.INTERACT_DISTANCE + PRESENCE_LEAVE_EXTRA
            else here
        local wantPresent = active and inRange and not staffed
        if wantPresent ~= toldPresent then
            toldPresent = wantPresent
            lastPresenceAt = now
            if o.place ~= nil then
                o.remote:FireServer(o.place, wantPresent)
            else
                o.remote:FireServer(wantPresent)
            end
        elseif wantPresent and now - lastPresenceAt >= PRESENCE_EVERY then
            lastPresenceAt = now
            if o.place ~= nil then
                o.remote:FireServer(o.place, true)
            else
                o.remote:FireServer(true)
            end
        end

        -- Inelul si placuta: doar fara om [D49].
        local showRing = active and not staffed
        if ring.Visible ~= showRing then
            ring.Visible = showRing
        end
        local signText: string? = nil
        local color, alpha, scale = Theme.COLOR.onDarkSoft, 0.55, 1
        if showRing and waiting > 0 then
            if toldPresent then
                signText = o.working(waiting)
                color, alpha = Theme.COLOR.good, 0.05
            else
                -- ceva de lucrat si nimeni acolo: inelul pulseaza, ca sa te cheme
                local pulse = (math.sin(now * 3.2) + 1) / 2
                signText = o.standHere
                color, alpha, scale = Theme.COLOR.gold, 0.35 - 0.3 * pulse, 0.94 + 0.1 * pulse
            end
        end
        if ring:IsA("ImageLabel") then
            ring.ImageColor3 = color
            ring.ImageTransparency = alpha
        else
            local stroke = ring:FindFirstChildOfClass("UIStroke")
            if stroke ~= nil then
                stroke.Color = color
                stroke.Transparency = alpha
            end
        end
        ringScale.Scale = scale
        local showSign = signText ~= nil
        if showSign and sign.Text ~= signText then
            sign.Text = signText :: string
            fit(signText :: string)
        end
        if showSign then
            sign.TextColor3 = if toldPresent then Theme.COLOR.good else Theme.COLOR.gold
        end
        if sign.Visible ~= showSign then
            sign.Visible = showSign
        end
    end)

    return {
        Present = function(): boolean
            return toldPresent
        end,
        Distance = distance,
    }
end

return StandRing
