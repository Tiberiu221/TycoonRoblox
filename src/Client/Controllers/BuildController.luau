--!strict
-- Meniul de construcții și plasarea pe grilă: alegi o clădire, o vezi ca fantomă, o pui [RIVERKEEP 4.3]
-- Serverul validează din nou totul; fantoma verde e doar o previzualizare optimistă.
local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local Assets = require(ReplicatedStorage.Shared.Config.Assets)
local BuildingConfig = require(ReplicatedStorage.Shared.Config.BuildingConfig)
local RiverConfig = require(ReplicatedStorage.Shared.Config.RiverConfig)
local Panels = require(script.Parent.Panels)
local Theme = require(script.Parent.Parent.UI.Theme)
local Widgets = require(script.Parent.Parent.UI.Widgets)

local BuildController = {}
local menu: Frame
local menuList: ScrollingFrame
local ghost: Frame
local plotHint: Frame
local ghostArt: ImageLabel
local ghostLabel: TextLabel
local selected: BuildingConfig.Def? = nil
local rows: { [string]: { row: TextButton, cost: TextLabel, def: BuildingConfig.Def } } = {}
local deps: {
    HudGui: Frame,
    Scroll: Frame,
    CameraX: () -> (number, number),
    PlaceBuilding: RemoteEvent,
    Materials: () -> number,
    Buildings: () -> { { [string]: any } },
    OnToast: (string) -> (),
}
local scale = 1

local function overlaps(x: number, y: number, w: number, h: number): boolean
    for _, b in deps.Buildings() do
        local d = BuildingConfig.get(b.defId)
        if d == nil then
            continue
        end
        local ow, oh = d.w * RiverConfig.TILE, d.h * RiverConfig.TILE
        if x < b.x + ow and x + w > b.x and y < b.y + oh and y + h > b.y then
            return true
        end
    end
    return false
end

-- Aceleași reguli ca pe server, ca fantoma să nu mintă
local function isValid(x: number, y: number, d: BuildingConfig.Def): boolean
    local w, h = d.w * RiverConfig.TILE, d.h * RiverConfig.TILE
    if x < 0 or y < 0 or x + w > RiverConfig.WORLD_WIDTH or y + h > RiverConfig.WORLD_HEIGHT then
        return false
    end
    if
        y + h > RiverConfig.RIVER_TOP - RiverConfig.TILE
        and y < RiverConfig.RIVER_BOTTOM + RiverConfig.TILE
    then
        return false
    end
    -- aceeasi limita ca pe server: fantoma trebuie sa devina rosie exact unde serverul ar refuza
    local plot = RiverConfig.PLOT
    if x < plot.x or y < plot.y or x + w > plot.x + plot.w or y + h > plot.y + plot.h then
        return false
    end
    return not overlaps(x, y, w, h)
end

-- Poziția mouse-ului/degetului în coordonate de lume, aliniată pe grilă
local function pointerWorldCell(): (number, number)
    local pos = UserInputService:GetMouseLocation()
    local camX, camY = deps.CameraX()
    local wx = pos.X / scale + camX
    local wy = pos.Y / scale + camY
    return math.floor(wx / RiverConfig.TILE) * RiverConfig.TILE,
        math.floor(wy / RiverConfig.TILE) * RiverConfig.TILE
end

function BuildController.Select(def: BuildingConfig.Def?)
    selected = def
    ghost.Visible = def ~= nil
    if plotHint ~= nil then
        plotHint.Visible = def ~= nil
    end
    if def ~= nil then
        ghost.Size = UDim2.fromOffset(def.w * RiverConfig.TILE, def.h * RiverConfig.TILE)
        local sprite = (Assets.buildings :: any)[def.id]
        if sprite ~= nil and Assets.has(sprite) then
            ghostArt.Image = Assets.url(sprite)
            ghostArt.Visible = true
        else
            ghostArt.Visible = false
        end
        ghostLabel.Text = `{def.label}  ·  {def.cost} mat`
        deps.OnToast(`Placing {def.label} — click to build, Esc to cancel`)
    end
end

function BuildController.IsPlacing(): boolean
    return selected ~= nil
end

-- Ce nu-ti permiti se vede inainte de clic: pretul devine rosu si randul se stinge.
-- Regula e a platformei: "cand un jucator nu isi permite un obiect, pretul se afiseaza rosu".
function BuildController.RefreshCosts()
    local have = deps.Materials()
    for _, entry in rows do
        local afford = have >= entry.def.cost
        entry.cost.TextColor3 = if afford then Theme.COLOR.good else Theme.COLOR.bad
        entry.row.BackgroundTransparency = if afford then 0.35 else 0.72
        for _, child in entry.row:GetChildren() do
            if child:IsA("TextLabel") and child.Name ~= "Cost" then
                child.TextTransparency = if afford then 0 else 0.45
            elseif child:IsA("ImageLabel") then
                child.ImageTransparency = if afford then 0 else 0.5
            end
        end
    end
end

function BuildController.ToggleMenu()
    if menu == nil then
        return
    end
    if not menu.Visible and not Panels.CanOpen("build") then
        return
    end
    menu.Visible = not menu.Visible
    if menu.Visible then
        BuildController.RefreshCosts()
        Panels.CloseOthers("build")
    else
        BuildController.Select(nil)
    end
end

function BuildController.IsMenuOpen(): boolean
    return menu ~= nil and menu.Visible
end

function BuildController.CloseMenu()
    if menu ~= nil and menu.Visible then
        menu.Visible = false
        BuildController.Select(nil)
    end
end

-- Meniul de constructii: cate un cartonas per cladire, cu pictograma, ce face si cat costa.
-- Randul stins spune din prima ca nu ti-l permiti, in loc sa afli dupa clic.
local function buildMenu()
    for i, def in BuildingConfig.DEFS do
        local row = Widgets.Row(menuList, 78, 33)
        row.LayoutOrder = i

        local sprite = (Assets.buildings :: any)[def.id]
        if sprite ~= nil and Assets.has(sprite) then
            local icon = Instance.new("ImageLabel")
            icon.Name = "Icon"
            icon.Position = UDim2.fromOffset(10, 9)
            icon.Size = UDim2.fromOffset(60, 60)
            icon.BackgroundColor3 = Theme.COLOR.parchmentDim
            icon.BackgroundTransparency = 0.4
            icon.Image = Assets.url(sprite)
            icon.ResampleMode = Enum.ResamplerMode.Pixelated
            icon.ScaleType = Enum.ScaleType.Fit
            icon.ZIndex = 34
            local ic = Instance.new("UICorner")
            ic.CornerRadius = UDim.new(0, 6)
            ic.Parent = icon
            icon.Parent = row
        end

        local name = Widgets.Label(row, def.label, Theme.TEXT.body, Theme.COLOR.ink, "strong")
        name.Position = UDim2.fromOffset(82, 10)
        name.Size = UDim2.fromOffset(210, 22)
        name.ZIndex = 34

        local size =
            Widgets.Label(row, `{def.w}×{def.h}`, Theme.TEXT.tiny, Theme.COLOR.inkSoft, "body")
        size.Position = UDim2.fromOffset(82, 32)
        size.Size = UDim2.fromOffset(60, 16)
        size.ZIndex = 34

        local blurb = Widgets.Label(row, def.blurb, Theme.TEXT.tiny, Theme.COLOR.inkSoft, "body")
        blurb.Position = UDim2.fromOffset(82, 50)
        blurb.Size = UDim2.fromOffset(300, 18)
        blurb.TextTruncate = Enum.TextTruncate.AtEnd
        blurb.ZIndex = 34

        local cost =
            Widgets.Label(row, tostring(def.cost), Theme.TEXT.heading, Theme.COLOR.good, "display")
        cost.Name = "Cost"
        cost.Position = UDim2.new(1, -96, 0, 18)
        cost.Size = UDim2.fromOffset(56, 26)
        cost.TextXAlignment = Enum.TextXAlignment.Right
        cost.ZIndex = 34

        local costIcon = Widgets.Icon(row, "materials", 22)
        if costIcon ~= nil then
            costIcon.Position = UDim2.new(1, -34, 0, 20)
            costIcon.ZIndex = 34
        end

        row.Activated:Connect(function()
            if deps.Materials() < def.cost then
                deps.OnToast(
                    `Not enough materials for {def.label} — scrap crates in the workshop`
                )
                return
            end
            BuildController.Select(def)
        end)
        rows[def.id] = { row = row, cost = cost, def = def }
    end
end

function BuildController.Init(d: typeof(deps))
    deps = d

    local root, body = Widgets.Window(deps.HudGui, {
        name = "BuildMenu",
        title = "Build",
        icon = "build",
        width = 520,
        height = 700,
        z = 30,
        onClose = BuildController.CloseMenu,
    })
    root.AnchorPoint = Vector2.new(1, 0.5)
    root.Position = UDim2.new(1, -Theme.SPACE.lg - 86, 0.5, 0)
    root.Visible = false
    menu = root

    local hint = Widgets.Label(
        body,
        -- A doua propozitie raspunde intrebarii pe care jocul o starnea si nu o lamurea:
        -- de ce sta santierul la 0%. Cladirile nu apar, le RIDICA oamenii tai.
        "Pick one, then click the lit ground. Your settlers walk over and build it.",
        Theme.TEXT.tiny,
        Theme.COLOR.inkSoft,
        "body"
    )
    hint.Size = UDim2.new(1, 0, 0, 18)

    menuList = Widgets.List(body, 32)
    local holder = menuList.Parent :: Frame
    holder.Position = UDim2.fromOffset(0, 26)
    holder.Size = UDim2.new(1, 0, 1, -26)
    buildMenu()
    Panels.Register("build", {
        isOpen = BuildController.IsMenuOpen,
        close = BuildController.CloseMenu,
    })

    ghost = Instance.new("Frame")
    ghost.Name = "BuildGhost"
    ghost.BackgroundColor3 = Theme.COLOR.ghostOk
    ghost.BackgroundTransparency = 0.55
    ghost.Visible = false
    ghost.ZIndex = 20
    local gc = Instance.new("UICorner")
    gc.CornerRadius = UDim.new(0, 6)
    gc.Parent = ghost
    local gs = Instance.new("UIStroke")
    gs.Thickness = 3
    gs.Color = Theme.COLOR.ghostOk
    gs.Parent = ghost
    -- conturul terenului pe care se poate construi, vizibil doar in modul de asezare
    plotHint = Instance.new("Frame")
    plotHint.Name = "PlotHint"
    plotHint.Position = UDim2.fromOffset(RiverConfig.PLOT.x, RiverConfig.PLOT.y)
    plotHint.Size = UDim2.fromOffset(RiverConfig.PLOT.w, RiverConfig.PLOT.h)
    -- Indiciul pasului spune "aseaz-o pe pamantul LUMINAT". La 0.93 transparenta terenul era
    -- invizibil, deci textul promitea ceva ce nu se vedea si jucatorul ghicea unde poate pune.
    plotHint.BackgroundColor3 = Theme.COLOR.gold
    plotHint.BackgroundTransparency = 0.82
    plotHint.Visible = false
    plotHint.ZIndex = 2
    local ps = Instance.new("UIStroke")
    ps.Thickness = 5
    ps.Color = Theme.COLOR.gold
    ps.Transparency = 0.1
    ps.Parent = plotHint
    -- rama respira incet: ochiul prinde miscarea si intelege ca acolo se poate pune
    TweenService:Create(
        ps,
        TweenInfo.new(1.1, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true),
        { Transparency = 0.5 }
    ):Play()
    local pc = Instance.new("UICorner")
    pc.CornerRadius = UDim.new(0, 8)
    pc.Parent = plotHint
    plotHint.Parent = deps.Scroll

    ghostArt = Instance.new("ImageLabel")
    ghostArt.Name = "GhostArt"
    ghostArt.BackgroundTransparency = 1
    ghostArt.Size = UDim2.fromScale(1, 1)
    ghostArt.ResampleMode = Enum.ResamplerMode.Pixelated
    ghostArt.ScaleType = Enum.ScaleType.Fit
    ghostArt.ImageTransparency = 0.25
    ghostArt.Visible = false
    ghostArt.ZIndex = 21
    ghostArt.Parent = ghost

    ghostLabel = Instance.new("TextLabel")
    ghostLabel.Size = UDim2.fromScale(1, 1)
    ghostLabel.BackgroundTransparency = 1
    ghostLabel.TextColor3 = Theme.COLOR.onDark
    ghostLabel.TextSize = Theme.TEXT.body
    ghostLabel.ZIndex = 21
    Theme.applyFont(ghostLabel, "strong")
    Theme.punch(ghostLabel) -- eticheta fantomei sta peste teren cat timp plasezi cladirea
    ghostLabel.Parent = ghost
    ghost.Parent = deps.Scroll

    UserInputService.InputBegan:Connect(function(input: InputObject, processed: boolean)
        if processed then
            return
        end
        if input.KeyCode == Enum.KeyCode.B then
            BuildController.ToggleMenu()
        elseif input.KeyCode == Enum.KeyCode.Escape and selected ~= nil then
            BuildController.Select(nil)
        elseif input.UserInputType == Enum.UserInputType.MouseButton1 and selected ~= nil then
            local x, y = pointerWorldCell()
            if isValid(x, y, selected) then
                deps.PlaceBuilding:FireServer(selected.id, x, y)
                BuildController.Select(nil)
            else
                deps.OnToast("Cannot build there")
            end
        end
    end)

    RunService.PreRender:Connect(function()
        if selected == nil then
            return
        end
        local x, y = pointerWorldCell()
        ghost.Position = UDim2.fromOffset(x, y)
        local ok = isValid(x, y, selected)
        local color = if ok then Theme.COLOR.ghostOk else Theme.COLOR.ghostBad
        if ghost.BackgroundColor3 ~= color then
            ghost.BackgroundColor3 = color
        end
    end)
end

function BuildController.SetScale(value: number)
    scale = value
end

return BuildController
