--!strict
-- [D70, pasul k10] DAM TOWN, pe client (doar la baraj): Canteen-ul, clopotnita cu clopotele vechi, Memory Wall si casutele
-- (DamTown.buildings, cu desene de imprumut pana la lotul A1: taverna, clopotul satului, avizierul, coliba), plimbarea
-- oamenilor iesiti din lucru (DamTown.cycle, pe drumurile lumii 2) si pagina „Your people” (Memory Wall, E).
--
-- Clopotnita are cardul ei: bonusul clopotelor vechi, fara quest (R11). Memory Wall deschide pagina oamenilor: cine
-- lucreaza unde (veteranii cu meseria de dinainte) si cine locuieste in oras. Macheta satului vechi si „Watch again” vin
-- dupa lansare (O1).
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local Assets = require(ReplicatedStorage.Shared.Config.Assets)
local RiverConfig = require(ReplicatedStorage.Shared.Config.RiverConfig)
local StationConfig = require(ReplicatedStorage.Shared.Config.StationConfig)
local Strings = require(ReplicatedStorage.Shared.Config.Strings)
local TycoonConfig = require(ReplicatedStorage.Shared.Config.TycoonConfig)
local DamTown = require(ReplicatedStorage.Shared.Modules.DamTown)
local HandMath = require(ReplicatedStorage.Shared.Modules.HandMath)

local Focus = require(script.Parent.Parent.UI.Focus)
local GroundShadow = require(script.Parent.Parent.UI.GroundShadow)
local Panels = require(script.Parent.Panels)
local PersonView = require(script.Parent.Parent.UI.PersonView)
local SoundController = require(script.Parent.SoundController)
local Theme = require(script.Parent.Parent.UI.Theme)
local Widgets = require(script.Parent.Parent.UI.Widgets)

local DamTownController = {}

export type Retired = { id: string, role: string, name: string, appearance: PersonView.Appearance }
-- un om de pe pagina: cine lucreaza (meseria, poate cea de dinainte) sau cine locuieste in oras
export type Person = { name: string, role: string, formerRole: string? }

export type Deps = {
    Plot: Frame,
    HudGui: Frame,
    CharacterPos: () -> (number, number),
    -- oamenii care lucreaza acum (ultima stare), pentru pagina
    People: () -> { Person },
}
local deps: Deps? = nil

-- [verificatorii k10b] Memory Wall: avizierul vechi, ros de vreme (ruina avizierelor din sat), nu avizierul adevarat al
-- satului, care sta si el in Dam Town (VillageController): doua aviziere la fel pareau acelasi loc
local BORROWED = {
    canteen = "tavern",
    bellTower = "bell",
    memoryWall = "board_old",
} :: { [string]: string }
local COTTAGE = "runner_hut"

local NAME_ABOVE = 4 + 18
-- [verificatorii k10b] cat de inalt e desenul de imprumut, pe cladire: eticheta si cardul stau deasupra lui, nu deasupra
-- cutiei (clopotul din Era 1 iese 96 x 134 intr-o cutie de turn de 240, iar numele plutea pe zid)
local drawnH: { [string]: number } = {}
-- ordinea meseriilor (erele, apoi tabelul fiecarei ere): pagina „Your people” e asezata dupa ea
local roleRank: { [string]: number } = {}
do
    local n = 0
    for _, roles in StationConfig.ERA_ROLES_ALL do
        for _, role in roles do
            if roleRank[role] == nil then
                n += 1
                roleRank[role] = n
            end
        end
    end
end
local walkers: { { view: PersonView.View, cycle: HandMath.Cycle, phase: number } } = {}
local retiredNow: { Retired } = {}
local shownIds = ""

local PAGE_W = 520
local window: Frame? = nil
local list: ScrollingFrame
local rows: { TextLabel } = {}

-- Desenul unei cladiri, incadrat in cutia ei (pastreaza proportiile), prins de baza.
local function drawFitted(
    plot: Frame,
    key: string,
    x: number,
    y: number,
    w: number,
    h: number,
    name: string
): (GuiObject?, number)
    local sprite = (Assets.tycoon :: any)[key]
    if sprite == nil or not Assets.has(sprite) then
        return nil, h
    end
    local k = math.min(w / sprite.width, h / sprite.height)
    local img = Instance.new("ImageLabel")
    img.Name = name
    img.BackgroundTransparency = 1
    img.Image = Assets.url(sprite)
    img.ResampleMode = Enum.ResamplerMode.Pixelated
    img.AnchorPoint = Vector2.new(0.5, 1)
    img.Position = UDim2.fromOffset(x, y)
    img.Size = UDim2.fromOffset(sprite.width * k, sprite.height * k)
    img.ZIndex = 5 + math.clamp(math.floor(y / 64), 0, 40)
    img.Parent = plot
    GroundShadow.add(img, UDim2.fromScale(0.5, 1), sprite.width * k, img.ZIndex - 1)
    return img, sprite.height * k
end

local function keyHint(): string
    return if UserInputService.KeyboardEnabled then " (E)" else ""
end

local function crewName(role: string): string
    local crew = TycoonConfig.CREWS[role]
    return if crew ~= nil then crew.name else role
end

-- Pagina „Your people”: cine lucreaza (cu meseria de dinainte, la veterani), apoi cine locuieste in oras.
local function refreshPage()
    local d = deps
    if d == nil then
        return
    end
    local lines: { string } = {}
    -- [verificatorii k10b] in ordine: intai veteranii, apoi ceilalti, dupa meserie si nume; retrasii dupa meseria de
    -- dinainte si nume (starea vine in ordinea unui dictionar)
    local function rank(role: string): number
        return roleRank[role] or math.huge
    end
    local working = table.clone(d.People())
    table.sort(working, function(a: Person, b: Person): boolean
        if (a.formerRole ~= nil) ~= (b.formerRole ~= nil) then
            return a.formerRole ~= nil
        end
        if rank(a.role) ~= rank(b.role) then
            return rank(a.role) < rank(b.role)
        end
        return a.name < b.name
    end)
    local living = table.clone(retiredNow)
    table.sort(living, function(a: Retired, b: Retired): boolean
        if rank(a.role) ~= rank(b.role) then
            return rank(a.role) < rank(b.role)
        end
        return a.name < b.name
    end)
    for _, p in working do
        local former = p.formerRole
        table.insert(
            lines,
            if former ~= nil
                then Strings.personVeteran(p.name, crewName(p.role), crewName(former))
                else Strings.personAt(p.name, crewName(p.role))
        )
    end
    for _, r in living do
        table.insert(lines, Strings.personRetired(r.name, crewName(r.role)))
    end
    for i, text in lines do
        local row = rows[i]
        if row == nil then
            row = Widgets.Label(list, "", Theme.TEXT.small, Theme.COLOR.ink, "body")
            row.Size = UDim2.new(1, -12, 0, 24)
            row.LayoutOrder = i
            row.ZIndex = 72
            rows[i] = row
        end
        row.Text = text
        -- numele, meseria si meseria de dinainte pot fi lungi: textul se strange pana incape pe rand
        row.TextSize = Theme.fitSize(text, Theme.TEXT.small, "body", PAGE_W - 40)
        row.Visible = true
    end
    for i = #lines + 1, #rows do
        rows[i].Visible = false
    end
end

function DamTownController.OpenPeople()
    local w = window
    if w == nil or not Panels.CanOpen("people") then
        return
    end
    Panels.CloseOthers("people")
    refreshPage()
    w.Visible = true
end

local function isOpen(): boolean
    local w = window
    return w ~= nil and w.Visible
end

function DamTownController.ClosePeople()
    local w = window
    if w ~= nil then
        w.Visible = false
    end
end

-- Cardurile clopotnitei si ale Memory Wall (WORLDS[2].cards).
function DamTownController.Focus(px: number, py: number): Focus.Focus?
    local world = TycoonConfig.WORLDS[DamTown.WORLD]
    local cards = if world ~= nil then world.cards or {} else {}
    for _, b in DamTown.buildings() do
        local at = cards[b.key]
        if at ~= nil then
            local d = Focus.distance(px, py, at.x, at.y)
            if d <= RiverConfig.INTERACT_DISTANCE then
                local top = b.y - (drawnH[b.key] or b.h) - NAME_ABOVE - 6
                if b.key == "bellTower" then
                    return {
                        key = "old_bells",
                        at = at,
                        distance = d,
                        x = b.x,
                        y = top,
                        status = Strings.oldBells(DamTown.bellsPercent()),
                    }
                elseif b.key == "memoryWall" then
                    return {
                        key = "memory_wall",
                        at = at,
                        distance = d,
                        x = b.x,
                        y = top,
                        action = Strings.peopleOpen(keyHint()),
                        act = function()
                            SoundController.Play("click")
                            DamTownController.OpenPeople()
                        end,
                    }
                end
            end
        end
    end
    return nil
end

-- Oamenii iesiti din lucru (ultima stare): cel mult MAX_WALKERS se plimba, ceilalti stau in casa (pagina ii arata).
function DamTownController.Apply(retired: { Retired })
    retiredNow = retired
    local d = deps
    if d == nil then
        return
    end
    local ids: { string } = {}
    for i = 1, math.min(#retired, DamTown.MAX_WALKERS) do
        table.insert(ids, retired[i].id)
    end
    local key = table.concat(ids, ",")
    if key == shownIds then
        return
    end
    shownIds = key
    for _, w in walkers do
        w.view.Destroy()
    end
    table.clear(walkers)
    for i = 1, math.min(#retired, DamTown.MAX_WALKERS) do
        local view = PersonView.new(d.Plot, `Townsfolk{i}`)
        view.SetAppearance(retired[i].appearance)
        local cycle = DamTown.cycle(i)
        table.insert(
            walkers,
            { view = view, cycle = cycle, phase = DamTown.phase(i, cycle.duration) }
        )
    end
    if isOpen() then
        refreshPage()
    end
end

function DamTownController.Init(d: Deps)
    deps = d
    -- cladirile orasului, cu numele lor deasupra (textele avizierului le folosesc: „Beside the Canteen”)
    for _, b in DamTown.buildings() do
        local art, h = drawFitted(d.Plot, BORROWED[b.key], b.x, b.y, b.w, b.h, b.label)
        drawnH[b.key] = h
        if art ~= nil then
            local label =
                Widgets.Label(d.Plot, b.label, Theme.TEXT.tiny, Theme.COLOR.onDark, "strong")
            label.AnchorPoint = Vector2.new(0.5, 1)
            label.Position = UDim2.fromOffset(b.x, b.y - h - 4)
            label.Size = UDim2.fromOffset(math.max(b.w, 120), 18)
            label.TextXAlignment = Enum.TextXAlignment.Center
            label.ZIndex = 46
            Theme.punch(label, 2)
        end
    end
    local world = TycoonConfig.WORLDS[DamTown.WORLD]
    for i, c in (if world ~= nil then world.cottages or {} else {}) do
        drawFitted(d.Plot, COTTAGE, c.x, c.y, c.w, c.h, `Cottage{i}`)
    end

    -- pagina „Your people”
    local root, body = Widgets.Window(d.HudGui, {
        name = "YourPeople",
        title = Strings.PEOPLE_TITLE,
        icon = "people",
        width = PAGE_W,
        height = 520,
        z = 70,
        onClose = DamTownController.ClosePeople,
    })
    root.AnchorPoint = Vector2.new(0.5, 0.5)
    root.Position = UDim2.fromScale(0.5, 0.5)
    root.Visible = false
    window = root
    -- [verificatorii k10b] lista sta intr-un cadru care trebuie dimensionat (Widgets.Slot nu-i da marime): fara asta
    -- pagina iesea goala
    list = Widgets.List(body, 71, Theme.SPACE.xs)
    local holder = list.Parent :: Frame
    holder.Position = UDim2.fromOffset(0, 0)
    holder.Size = UDim2.fromScale(1, 1)
    Panels.Register("people", { isOpen = isOpen, close = DamTownController.ClosePeople })

    RunService.PreRender:Connect(function(dt: number)
        if #walkers == 0 then
            return
        end
        local now = Workspace:GetServerTimeNow()
        for _, w in walkers do
            local x, y, kind, facing = HandMath.sampleAt(w.cycle, now + w.phase)
            w.view.Pose(x, y, "idle", facing, kind == "walk", dt)
        end
    end)
end

return DamTownController
