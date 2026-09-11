--!strict
-- Sloturi si plase pe mal; interactiune prin apropiere (E / buton), serverul decide [DECIZII D07 v2, D13]
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Assets = require(ReplicatedStorage.Shared.Config.Assets)
local ItemConfig = require(ReplicatedStorage.Shared.Config.ItemConfig)
local RiverConfig = require(ReplicatedStorage.Shared.Config.RiverConfig)
local SceneArt = require(script.Parent.SceneArt)
local Theme = require(script.Parent.Parent.UI.Theme)

export type Deps = {
    Scroll: Frame,
    Remotes: { [string]: RemoteEvent },
    CharacterPos: () -> (number, number),
    -- pozitia atelierului REAL, din starea serverului: cea din RiverConfig e o ramasita de la
    -- prototip si nu mai corespunde cladirii asezate
    WorkshopPos: (() -> (number?, number?))?,
    OnInventory: ({ [string]: number }) -> (),
    OnToast: (string) -> (),
    OnWorkshop: () -> (),
}
export type Target = {
    kind: "slot" | "net",
    slotId: number,
    netId: number?,
    x: number,
    y: number,
    label: string,
}

local NetController = {}
local deps: Deps
local markers: { [number]: TextLabel } = {}
local netFrames: { [number]: Frame } = {}
local netBySlot: { [number]: number } = {}
local netContents: { [number]: number } = {}
local pending = false
local prompt: TextLabel
local current: Target? = nil

local function slotCenter(slotId: number): (number, number)
    return RiverConfig.NET_SLOT_XS[slotId], RiverConfig.LANE_YS[slotId]
end

local function showNet(netId: number, slotId: number, contents: number, capacity: number)
    local frame = netFrames[netId]
    if frame == nil then
        frame = Instance.new("Frame")
        frame.Name = `Net{netId}`
        local cx, cy = slotCenter(slotId)
        frame.AnchorPoint = Vector2.new(0.5, 0.5)
        frame.Position = UDim2.fromOffset(cx, cy)
        frame.Size = UDim2.fromOffset(RiverConfig.NET_WIDTH, RiverConfig.NET_HEIGHT)
        frame.ZIndex = 4
        SceneArt.StyleNet(frame)
        local label = Instance.new("TextLabel")
        label.Name = "Count"
        label.AnchorPoint = Vector2.new(0.5, 0)
        label.Position = UDim2.new(0.5, 0, 1, 4)
        label.Size = UDim2.fromOffset(120, 26)
        label.BackgroundColor3 = Theme.COLOR.plate
        label.BackgroundTransparency = 0.3
        label.TextColor3 = Theme.COLOR.onDark
        label.TextSize = 20 -- fara corespondent in Theme.TEXT (30/22/18/15/13)
        label.ZIndex = 5
        Theme.applyFont(label, "strong")
        Theme.punch(label) -- numarul din plasa sta peste apa, langa plasa
        local corner = Instance.new("UICorner")
        corner.CornerRadius = UDim.new(0, 6)
        corner.Parent = label
        label.Parent = frame
        frame.Parent = deps.Scroll
        netFrames[netId] = frame
        netBySlot[slotId] = netId
        -- plasa inlocuieste inelul: cele doua stari (loc liber / plasa pusa) nu trebuie sa
        -- arate niciodata in acelasi timp pe acelasi slot [task: distinctie ceruta de owner]
        markers[slotId].Visible = false
    end
    netContents[netId] = contents
    local count = frame:FindFirstChild("Count") :: TextLabel
    count.Text = `{contents} / {capacity}`
end

-- Tinta cea mai apropiata de personaj (slot liber sau plasa cu continut)
function NetController.NearestTarget(charX: number, charY: number): Target?
    local best: Target? = nil
    local bestD = RiverConfig.INTERACT_DISTANCE
    for slotId = 1, #RiverConfig.NET_SLOT_XS do
        local sx, sy = slotCenter(slotId)
        -- distanta pana la marginea de sud a plasei (personajul sta pe mal, nu in apa)
        local d = math.sqrt((charX - sx) ^ 2 + (charY - (RiverConfig.RIVER_BOTTOM + 30)) ^ 2)
        if d >= bestD then
            continue
        end
        local netId = netBySlot[slotId]
        if netId == nil then
            best =
                { kind = "slot", slotId = slotId, netId = nil, x = sx, y = sy, label = "Place net" }
            bestD = d
        elseif (netContents[netId] or 0) > 0 then
            best =
                { kind = "net", slotId = slotId, netId = netId, x = sx, y = sy, label = "Collect" }
            bestD = d
        end
    end
    -- atelierul: pozitia vine din cladirile asezate, nu dintr-o constanta
    local wx, wy = nil, nil
    if deps.WorkshopPos ~= nil then
        wx, wy = (deps.WorkshopPos :: () -> (number?, number?))()
    end
    if wx ~= nil and wy ~= nil then
        local d2 = math.sqrt((charX - wx) ^ 2 + (charY - (wy + 20)) ^ 2)
        if d2 < bestD then
            best = {
                kind = "workshop",
                slotId = 0,
                netId = nil,
                x = wx,
                y = wy,
                label = "Enter workshop",
            }
        end
    end
    return best
end

function NetController.Interact()
    if current == nil or pending then
        return
    end
    pending = true
    task.delay(1, function()
        pending = false
    end)
    if current.kind == "slot" then
        deps.Remotes.PlaceNet:FireServer(current.slotId)
    elseif current.kind == "net" then
        deps.Remotes.CollectNet:FireServer(current.netId)
    else
        pending = false
        deps.OnWorkshop()
    end
end

function NetController.SlotPos(slotId: number): Vector2
    local sx, sy = slotCenter(slotId)
    return Vector2.new(sx, sy)
end

-- Primul slot fara plasa: acolo arata sageata la primul obiectiv
function NetController.FreeSlotPos(): Vector2?
    for slotId = 1, #RiverConfig.NET_SLOT_XS do
        if netBySlot[slotId] == nil then
            local sx, sy = slotCenter(slotId)
            return Vector2.new(sx, sy)
        end
    end
    return nil
end

-- Plasa care are ceva de colectat; daca niciuna nu are, prima plasa pusa
function NetController.FullNetPos(): Vector2?
    local fallback: Vector2? = nil
    for slotId, netId in netBySlot do
        local sx, sy = slotCenter(slotId)
        if (netContents[netId] or 0) > 0 then
            return Vector2.new(sx, sy)
        end
        if fallback == nil then
            fallback = Vector2.new(sx, sy)
        end
    end
    return fallback
end

function NetController.HasAnyNet(): boolean
    return next(netBySlot) ~= nil
end

function NetController.Init(d: Deps)
    deps = d
    for slotId = 1, #RiverConfig.NET_SLOT_XS do
        local sx, sy = slotCenter(slotId)
        -- INELUL. Textul obiectivului spune "inelul stralucitor de pe apa", deci pe apa trebuie
        -- sa fie un inel, si trebuie sa straluceasca. Varianta de dinainte era un dreptunghi
        -- palid pe care nu-l vedeai, iar indiciul era o minciuna.
        local m = Instance.new("TextLabel")
        m.Name = `Slot{slotId}`
        m.AnchorPoint = Vector2.new(0.5, 0.5)
        m.Position = UDim2.fromOffset(sx, sy)
        m.Size = UDim2.fromOffset(96, 96)
        -- glow-ul inelului de pe apa foloseste 3 nuante de aur pal (fundal/inel/puls) pentru
        -- sclipire; niciuna nu are corespondent apropiat in Theme.COLOR, iar reducerea la un
        -- singur token (gold) ar aplatiza efectul
        m.BackgroundColor3 = Color3.fromRGB(255, 244, 200)
        m.BackgroundTransparency = 0.86
        m.Text = ""
        m.ZIndex = 4
        local corner = Instance.new("UICorner")
        corner.CornerRadius = UDim.new(1, 0) -- cerc, nu dreptunghi
        corner.Parent = m
        local ring = Instance.new("UIStroke")
        ring.Name = "Ring"
        ring.Thickness = 5
        ring.Color = Color3.fromRGB(255, 226, 130) -- parte din acelasi glow, vezi comentariul de la m.BackgroundColor3
        ring.Transparency = 0.1
        ring.Parent = m

        -- al doilea inel, mai mare, care se umfla si se stinge: asa se citeste ca "aici"
        local pulse = Instance.new("Frame")
        pulse.Name = "Pulse"
        pulse.AnchorPoint = Vector2.new(0.5, 0.5)
        pulse.Position = UDim2.fromScale(0.5, 0.5)
        pulse.Size = UDim2.fromScale(1, 1)
        pulse.BackgroundTransparency = 1
        pulse.ZIndex = 3
        local pc = Instance.new("UICorner")
        pc.CornerRadius = UDim.new(1, 0)
        pc.Parent = pulse
        local ps = Instance.new("UIStroke")
        ps.Name = "Ring"
        ps.Thickness = 3
        ps.Color = Color3.fromRGB(255, 236, 170) -- parte din acelasi glow, vezi comentariul de la m.BackgroundColor3
        ps.Parent = pulse
        pulse.Parent = m

        -- VIATA INELULUI, in trei tween-uri TweenService independente, fiecare creat O SINGURA
        -- DATA aici la Init (nu in PreRender, nu in showNet la fiecare stare noua): un tween cu
        -- RepeatCount -1 pornit din nou la fiecare reimprospatare s-ar stivui peste cele vechi si
        -- niciunul nu s-ar mai opri [bug real gasit in varianta veche: vezi mai jos la PreRender].
        -- Fiecare durata are un jitter random mic, ca cele trei inele de pe rau sa nu respire la
        -- unison -- sincron ar arata a masinarie, nu a apa care curge sub ele.

        -- 1. Respiratia inelului principal: opacitatea urca si coboara lent (~2.6-3.8s pe sens),
        -- ca sa nu mai stea "mort" cat timp slotul e liber.
        local breatheTime = 2.6 + math.random() * 1.2
        local breathe = TweenService:Create(
            ring,
            TweenInfo.new(breatheTime, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true),
            { Transparency = 0.6 }
        )
        task.delay(math.random() * breatheTime, function()
            breathe:Play()
        end)

        -- 2. Inelul Pulse e o unda pe apa: se dilata si se stinge complet (~2-3s), apoi o ia de
        -- la capat -- fara reverse, o unda adevarata nu se retrage, doar dispare si vine alta.
        -- Fiindca la capete e complet transparent, saltul de reinceput nu se vede (nu mai
        -- sare intre valori departate ca varianta veche cu phase = (t * 1.6) % 1).
        ps.Transparency = 0.2
        local rippleTime = 2 + math.random()
        local rippleGrow = TweenService:Create(
            pulse,
            TweenInfo.new(rippleTime, Enum.EasingStyle.Sine, Enum.EasingDirection.Out, -1, false),
            { Size = UDim2.fromScale(1.6, 1.6) }
        )
        local rippleFade = TweenService:Create(
            ps,
            TweenInfo.new(rippleTime, Enum.EasingStyle.Sine, Enum.EasingDirection.Out, -1, false),
            { Transparency = 1 }
        )
        task.delay(math.random() * rippleTime, function()
            rippleGrow:Play()
            rippleFade:Play()
        end)

        -- 3. Plutire usoara pe verticala (~2.4-3.4s pe sens): tot inelul sta pe apa care se
        -- misca sub el. Sigur pentru interactiune: slotCenter() ramane sursa de adevar pentru
        -- pozitia slotului (NearestTarget, SlotPos etc.), deci butonul E tinteste tot centrul
        -- nominal, indiferent unde a ajuns inelul in bataia lui de 5px.
        local bobTime = 2.4 + math.random()
        local bob = TweenService:Create(
            m,
            TweenInfo.new(bobTime, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true),
            { Position = UDim2.fromOffset(sx, sy - 5) }
        )
        task.delay(math.random() * bobTime, function()
            bob:Play()
        end)

        if Assets.has(Assets.icons.net) then
            local ghost = Instance.new("ImageLabel")
            ghost.BackgroundTransparency = 1
            ghost.Image = Assets.url(Assets.icons.net)
            ghost.ResampleMode = Enum.ResamplerMode.Pixelated
            ghost.ImageTransparency = 0.35
            ghost.AnchorPoint = Vector2.new(0.5, 0.5)
            ghost.Position = UDim2.fromScale(0.5, 0.5)
            ghost.Size = UDim2.fromOffset(44, 44)
            ghost.ZIndex = 5
            ghost.Parent = m
        end

        m.Parent = deps.Scroll
        markers[slotId] = m
    end

    prompt = Instance.new("TextLabel")
    prompt.AnchorPoint = Vector2.new(0.5, 1)
    prompt.Size = UDim2.fromOffset(220, 40)
    prompt.BackgroundColor3 = Theme.COLOR.plate
    prompt.BackgroundTransparency = 0.2
    prompt.TextColor3 = Theme.COLOR.gold
    prompt.TextSize = Theme.TEXT.heading
    prompt.ZIndex = 8
    prompt.Visible = false
    Theme.applyFont(prompt, "strong")
    Theme.punch(prompt) -- indemnul de interactiune urmareste tinta peste lume
    local pc = Instance.new("UICorner")
    pc.CornerRadius = UDim.new(0, 8)
    pc.Parent = prompt
    prompt.Parent = deps.Scroll

    RunService.PreRender:Connect(function()
        -- Pulsul si plutirea inelelor sunt tween-uri TweenService pornite o singura data mai sus,
        -- la Init; nu se mai recalculeaza nimic manual aici pe cadru. Ramane doar tinta curenta
        -- si indemnul de interactiune, care depind de pozitia personajului.
        current = NetController.NearestTarget(deps.CharacterPos())
        if current ~= nil then
            local keyHint = if UserInputService.KeyboardEnabled then " (E)" else ""
            prompt.Text = current.label .. keyHint
            prompt.Position =
                UDim2.fromOffset(current.x, current.y - RiverConfig.NET_HEIGHT / 2 - 12)
            prompt.Visible = true
        else
            prompt.Visible = false
        end
    end)
    UserInputService.InputBegan:Connect(function(input: InputObject, processed: boolean)
        if not processed and input.KeyCode == Enum.KeyCode.E then
            NetController.Interact()
        end
    end)

    deps.Remotes.NetPlaced.OnClientEvent:Connect(function(netId: number, slotId: number)
        pending = false
        showNet(netId, slotId, 0, 8)
    end)
    deps.Remotes.NetRejected.OnClientEvent:Connect(function(_slotId: number, reason: string)
        pending = false
        deps.OnToast(`Cannot place net: {reason}`)
    end)
    deps.Remotes.ObjectCaught.OnClientEvent:Connect(
        function(objectId: number, netId: number, contents: number, capacity: number, tier: string)
            local frame = netFrames[netId]
            if frame ~= nil then
                netContents[netId] = contents
                local count = frame:FindFirstChild("Count") :: TextLabel
                count.Text = `{contents} / {capacity}`
            end
            if tier ~= "common" and tier ~= "uncommon" then
                -- Alegerea obiectului e determinista din id-ul lucrului de pe rau, deci clientul
                -- ajunge la ACELASI obiect ca serverul fara sa i se trimita nimic in plus.
                local picked = ItemConfig.pickFor(tier, objectId)
                deps.OnToast(
                    if picked ~= nil then `Caught: {picked.name}` else `Caught a {tier} item!`
                )
            end
        end
    )
    deps.Remotes.NetCollected.OnClientEvent:Connect(
        function(netId: number, items: { string }, inventory: { [string]: number })
            pending = false
            local frame = netFrames[netId]
            if frame ~= nil then
                netContents[netId] = 0
                local count = frame:FindFirstChild("Count") :: TextLabel
                count.Text = "0 / 8"
            end
            deps.OnInventory(inventory)
            deps.OnToast(`Collected {#items} items`)
        end
    )
    deps.Remotes.StateSnapshot.OnClientEvent:Connect(function(snapshot: { [string]: any })
        for _, net in snapshot.nets do
            showNet(net.id, net.slotId, net.contents, net.capacity or 8)
        end
        deps.OnInventory(snapshot.inventory)
    end)
end

return NetController
