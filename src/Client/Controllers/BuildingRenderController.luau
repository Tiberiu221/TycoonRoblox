--!strict
-- Desenează clădirile din starea trimisă de server: terminate sau șantiere în lucru [RIVERKEEP 4.3]
-- Un Frame per clădire, creat o singură dată și actualizat, nu recreat (altfel clipește).
-- Cât timp se construiește se vede o schelă; la terminare apare clădirea reală, cu fum și sărbătoare.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Assets = require(ReplicatedStorage.Shared.Config.Assets)
local BuildingConfig = require(ReplicatedStorage.Shared.Config.BuildingConfig)
local RiverConfig = require(ReplicatedStorage.Shared.Config.RiverConfig)
local SceneArt = require(script.Parent.SceneArt)
local Theme = require(script.Parent.Parent.UI.Theme)

local BuildingRenderController = {}
local layer: Frame
local views: { [number]: Frame } = {}
local latest: { { [string]: any } } = {}
local beds = 0
local onSelect: ((number) -> ())? = nil

-- Unde stă coșul pe fiecare sprite, în fracțiuni din cadrul clădirii. Cine lipsește nu scoate fum.
local CHIMNEYS: { [string]: { x: number, y: number } } = {
    cottage = { x = 0.74, y = 0.13 },
    kitchen = { x = 0.24, y = 0.05 },
    workshop = { x = 0.74, y = 0.10 },
}
-- Afumătoarea are două coșuri
local CHIMNEYS_EXTRA: { [string]: { { x: number, y: number } } } = {
    smokehouse = { { x = 0.30, y = 0.09 }, { x = 0.73, y = 0.09 } },
}

local function spriteFor(defId: string): Assets.Sprite?
    local s = (Assets.buildings :: any)[defId]
    if s ~= nil and Assets.has(s) then
        return s
    end
    if Assets.has(Assets.house) then
        return Assets.house
    end
    return nil
end

local function makeView(b: { [string]: any }, d: BuildingConfig.Def): Frame
    local w, h = d.w * RiverConfig.TILE, d.h * RiverConfig.TILE
    local holder = Instance.new("Frame")
    holder.Name = `B{b.id}`
    holder.Position = UDim2.fromOffset(b.x, b.y)
    holder.Size = UDim2.fromOffset(w, h)
    holder.BackgroundTransparency = 1
    holder.ZIndex = 3
    holder.Parent = layer

    -- Toata cladirea e un buton. Apasatul pe cladire e verbul principal al jocului si pana acum
    -- nu exista deloc: puteai ridica o cladire, dar nu o puteai intreba nimic.
    local hit = Instance.new("TextButton")
    hit.Name = "Hit"
    hit.BackgroundTransparency = 1
    hit.Text = ""
    hit.AutoButtonColor = false
    hit.Size = UDim2.fromScale(1, 1)
    hit.ZIndex = 7
    hit.Parent = holder
    hit.Activated:Connect(function()
        if onSelect ~= nil then
            onSelect(b.id)
        end
    end)

    local sprite = spriteFor(d.id)
    if sprite ~= nil then
        local img = Instance.new("ImageLabel")
        img.Name = "Art"
        img.Image = Assets.url(sprite)
        img.ResampleMode = Enum.ResamplerMode.Pixelated
        img.ScaleType = Enum.ScaleType.Fit
        img.BackgroundTransparency = 1
        img.AnchorPoint = Vector2.new(0.5, 0.5)
        img.Position = UDim2.fromScale(0.5, 0.5)
        img.Size = UDim2.fromScale(1, 1)
        img.Visible = false
        img.ZIndex = 3
        img.Parent = holder
    else
        local box = Instance.new("Frame")
        box.Name = "Art"
        box.AnchorPoint = Vector2.new(0.5, 0.5)
        box.Position = UDim2.fromScale(0.5, 0.5)
        box.Size = UDim2.fromScale(1, 1)
        box.BackgroundColor3 = Color3.fromRGB(170, 110, 80)
        box.Visible = false
        box.ZIndex = 3
        local corner = Instance.new("UICorner")
        corner.CornerRadius = UDim.new(0, 8)
        corner.Parent = box
        box.Parent = holder
    end

    -- schela: se vede doar cât timp se lucrează
    local scaffold = Instance.new("ImageLabel")
    scaffold.Name = "Scaffold"
    scaffold.BackgroundTransparency = 1
    scaffold.ResampleMode = Enum.ResamplerMode.Pixelated
    scaffold.ScaleType = Enum.ScaleType.Stretch
    scaffold.Size = UDim2.fromScale(1, 1)
    scaffold.ZIndex = 3
    scaffold.Visible = false
    if Assets.has(Assets.buildings.scaffold) then
        scaffold.Image = Assets.url(Assets.buildings.scaffold)
    else
        scaffold.BackgroundTransparency = 0.4
        scaffold.BackgroundColor3 = Color3.fromRGB(150, 130, 95)
    end
    scaffold.Parent = holder

    local label = Instance.new("TextLabel")
    label.Name = "Label"
    label.AnchorPoint = Vector2.new(0.5, 0)
    label.Position = UDim2.new(0.5, 0, 1, 4)
    label.Size = UDim2.fromOffset(math.max(120, w), 24)
    label.BackgroundColor3 = Theme.COLOR.plate
    label.BackgroundTransparency = Theme.PLATE_TRANSPARENCY
    label.TextColor3 = Theme.COLOR.onDark
    label.TextSize = Theme.TEXT.small
    label.Text = d.label
    label.ZIndex = 4
    Theme.applyFont(label, "display") -- era Enum.Font.GothamBold, fontul depreciat al platformei
    Theme.punch(label) -- eticheta sta peste iarba: fara contur se spala pe orice fundal deschis
    local lc = Instance.new("UICorner")
    lc.CornerRadius = UDim.new(0, 5)
    lc.Parent = label
    label.Parent = holder

    -- bara de progres a șantierului, ascunsă când e gata
    local barBg = Instance.new("Frame")
    barBg.Name = "BarBg"
    barBg.AnchorPoint = Vector2.new(0.5, 1)
    barBg.Position = UDim2.new(0.5, 0, 0, -6)
    barBg.Size = UDim2.fromOffset(math.max(100, w - 16), 10)
    barBg.BackgroundColor3 = Color3.fromRGB(20, 28, 36)
    barBg.BorderSizePixel = 0
    barBg.ZIndex = 5
    local bc = Instance.new("UICorner")
    bc.CornerRadius = UDim.new(0, 4)
    bc.Parent = barBg
    local fill = Instance.new("Frame")
    fill.Name = "Fill"
    fill.Size = UDim2.fromScale(0, 1)
    fill.BackgroundColor3 = Color3.fromRGB(235, 200, 120)
    fill.BorderSizePixel = 0
    fill.ZIndex = 6
    local fc = Instance.new("UICorner")
    fc.CornerRadius = UDim.new(0, 4)
    fc.Parent = fill
    fill.Parent = barBg
    barBg.Parent = holder

    return holder
end

-- Fumul, focul și praful se atașează o singură dată, când clădirea își schimbă starea
local function attachEffects(view: Frame, d: BuildingConfig.Def, complete: boolean)
    if view:GetAttribute("Effects") == (if complete then "done" else "site") then
        return
    end
    for _, child in view:GetChildren() do
        if child.Name == "Particle" then
            child:Destroy()
        end
    end
    view:SetAttribute("Effects", if complete then "done" else "site")
    if not complete then
        SceneArt.AddDust(view)
        return
    end
    local one = CHIMNEYS[d.id]
    if one ~= nil then
        SceneArt.AddSmoke(view, one.x, one.y)
    end
    local many = CHIMNEYS_EXTRA[d.id]
    if many ~= nil then
        for _, c in many do
            SceneArt.AddSmoke(view, c.x, c.y)
        end
    end
    if d.id == "firepit" then
        SceneArt.AddFire(view, 0.5, 0.72)
    end
end

function BuildingRenderController.Beds(): number
    return beds
end

function BuildingRenderController.List(): { { [string]: any } }
    return latest
end

local function apply(list: { { [string]: any } })
    latest = list
    local seen: { [number]: boolean } = {}
    for _, b in list do
        local d = BuildingConfig.get(b.defId)
        if d == nil then
            continue
        end
        seen[b.id] = true
        local view = views[b.id]
        local isNew = view == nil
        if view == nil then
            view = makeView(b, d)
            views[b.id] = view
        end
        local complete = b.progress >= d.buildWork
        local art = view:FindFirstChild("Art") :: GuiObject
        local scaffold = view:FindFirstChild("Scaffold") :: ImageLabel
        local barBg = view:FindFirstChild("BarBg") :: Frame
        local fill = barBg:FindFirstChild("Fill") :: Frame
        local label = view:FindFirstChild("Label") :: TextLabel

        if complete then
            -- trecerea de la schelă la clădire se sărbătorește o singură dată
            local justFinished = not isNew and scaffold.Visible
            if scaffold.Visible then
                scaffold.Visible = false
            end
            if not art.Visible then
                art.Visible = true
            end
            if barBg.Visible then
                barBg.Visible = false
            end
            if label.Text ~= d.label then
                label.Text = d.label
            end
            attachEffects(view, d, true)
            if justFinished then
                SceneArt.Flourish(art, view)
            end
        else
            if art.Visible then
                art.Visible = false
            end
            if not scaffold.Visible then
                scaffold.Visible = true
            end
            if not barBg.Visible then
                barBg.Visible = true
            end
            local pct = math.clamp(b.progress / d.buildWork, 0, 1)
            fill.Size = UDim2.fromScale(pct, 1)
            local text = `{d.label} — {math.floor(pct * 100)}%`
            if label.Text ~= text then
                label.Text = text
            end
            attachEffects(view, d, false)
        end
    end
    for id, view in views do
        if not seen[id] then
            view:Destroy()
            views[id] = nil
        end
    end
end

function BuildingRenderController.Init(deps: {
    Scroll: Frame,
    BuildingsState: RemoteEvent,
    OnSelect: ((number) -> ())?,
})
    onSelect = deps.OnSelect
    layer = Instance.new("Frame")
    layer.Name = "BuildingLayer"
    layer.BackgroundTransparency = 1
    layer.Size = UDim2.fromScale(1, 1)
    layer.ZIndex = 3
    layer.Parent = deps.Scroll

    deps.BuildingsState.OnClientEvent:Connect(
        function(list: { { [string]: any } }, bedCount: number)
            beds = bedCount
            apply(list)
        end
    )
end

return BuildingRenderController
