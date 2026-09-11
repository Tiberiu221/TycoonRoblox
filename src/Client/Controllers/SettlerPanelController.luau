--!strict
-- Panoul de administrator: lista coloniștilor cu cele 3 stări, sortată după cel mai urgent [RIVERKEEP 4.1]
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local BuildingConfig = require(ReplicatedStorage.Shared.Config.BuildingConfig)
local SettlerConfig = require(ReplicatedStorage.Shared.Config.SettlerConfig)
local CameraController = require(script.Parent.CameraController)
local Panels = require(script.Parent.Panels)
local Theme = require(script.Parent.Parent.UI.Theme)
local Widgets = require(script.Parent.Parent.UI.Widgets)

local SettlerPanelController = {}
local panel: Frame
local list: ScrollingFrame
local jobInfo: TextLabel
local buildings: (() -> { { [string]: any } })? = nil
local hoverConnections: { [TextButton]: RBXScriptConnection } = {}
local rows: { Frame } = {}
local rowConnections: { [number]: RBXScriptConnection } = {}
local jobConnections: { [number]: { [string]: RBXScriptConnection } } = {}
local summary: TextLabel
local source: (() -> { { [string]: any } })? = nil
local positionOf: ((number) -> (number?, number?))? = nil
local focusedId: number? = nil
local onAlert: ((number, string?, (() -> ())?) -> ())? = nil
local onSelect: ((number?) -> ())? = nil
local setJob: ((number, string) -> ())? = nil

-- initiala fiecarei meserii, pentru butoanele compacte din rand
local JOB_INITIAL: { [string]: string } = {
    Fisher = "F",
    Crafter = "C",
    Builder = "B",
    Gardener = "G",
    Innkeeper = "I",
}

local NEED_COLORS = {
    fed = Theme.COLOR.warn,
    rested = Theme.COLOR.cool,
    content = Theme.COLOR.good,
}

-- `goto` e cuvant rezervat in Luau, deci cheile se scriu ca string-uri
-- De ce cladire are nevoie fiecare meserie ca sa aiba ce face. Pescarul n-are nevoie de nimic
-- construit -- malul e postul lui. Fara tabelul asta, un gradinar fara gradina se plimba la
-- nesfarsit si NIMIC nu spune de ce: exact intrebarea "nu inteleg ce face gradinarul".
local JOB_NEEDS: { [string]: { kind: string, what: string } } = {
    Gardener = { kind = "farm", what = "a Garden" },
    Innkeeper = { kind = "joy", what = "a Firepit or Meeting hall" },
    Crafter = { kind = "work", what = "a Workshop" },
}

local TASK_LABEL: { [string]: string } = {
    ["idle"] = "idle",
    ["wander"] = "walking",
    ["goto"] = "on the way",
    ["using"] = "resting",
    ["working"] = "working",
    ["leaving"] = "leaving!",
}

-- Camera se duce la colonistul ales si ramane pe el pana te misti tu
function SettlerPanelController.FocusOn(id: number)
    focusedId = id
    if onSelect ~= nil then
        onSelect(id)
    end
    CameraController.SetFocus(function(): (number?, number?)
        if positionOf == nil or focusedId == nil then
            return nil, nil
        end
        return positionOf(focusedId)
    end)
end

-- Un rand de colonist: nume si meserie in stanga, cele trei nevoi ca bare in mijloc,
-- butoanele de meserie in dreapta. Nevoile sunt bare, nu cifre: o bara pe rosu se vede din
-- coltul ochiului, un "34" nu.
local function makeRow(index: number): Frame
    local row = Widgets.Row(list, 64, 31)
    row.LayoutOrder = index

    local name = Widgets.Label(row, "", Theme.TEXT.body, Theme.COLOR.ink, "strong")
    name.Name = "PersonName"
    name.Position = UDim2.fromOffset(14, 6)
    name.Size = UDim2.fromOffset(230, 24)
    name.ZIndex = 33

    local jobLine = Widgets.Label(row, "", Theme.TEXT.tiny, Theme.COLOR.inkSoft, "body")
    jobLine.Name = "Job"
    jobLine.Position = UDim2.fromOffset(14, 30)
    jobLine.Size = UDim2.fromOffset(250, 18)
    jobLine.TextTruncate = Enum.TextTruncate.AtEnd
    jobLine.ZIndex = 33

    local task = Widgets.Label(row, "", Theme.TEXT.tiny, Theme.COLOR.wood, "strong")
    task.Name = "Task"
    task.Position = UDim2.fromOffset(14, 46)
    task.Size = UDim2.fromOffset(250, 16)
    task.ZIndex = 33

    for i, need in SettlerConfig.NEEDS do
        local label = Widgets.Label(row, need.label, Theme.TEXT.tiny, Theme.COLOR.inkSoft, "body")
        label.Position = UDim2.fromOffset(276, 8 + (i - 1) * 18)
        label.Size = UDim2.fromOffset(58, 14)
        label.ZIndex = 33

        local track, fill =
            Widgets.Bar(row, 120, 10, NEED_COLORS[need.id] or Theme.COLOR.onDarkSoft, 33)
        track.Name = `Bar_{need.id}`
        track.Position = UDim2.fromOffset(336, 10 + (i - 1) * 18)
        fill.Name = "Fill"
    end

    -- butoane de meserie: administratorul decide cine ce face [RIVERKEEP 4.2]
    for i, job in SettlerConfig.JOBS do
        local jb = Instance.new("TextButton")
        jb.Name = `Job_{job}`
        -- randul are 654 px utili, iar ultimii 8 ii ia bara de derulare: al cincilea buton
        -- iesea din rand si cadea peste ea
        jb.Position = UDim2.fromOffset(466 + (i - 1) * 34, 18)
        jb.Size = UDim2.fromOffset(30, 30)
        jb.BackgroundColor3 = Theme.COLOR.parchmentDim
        jb.TextColor3 = Theme.COLOR.inkSoft
        jb.TextSize = 15
        jb.Text = JOB_INITIAL[job] or job:sub(1, 1)
        jb.AutoButtonColor = false
        jb.ZIndex = 34
        Theme.applyFont(jb, "strong")
        local jc = Instance.new("UICorner")
        jc.CornerRadius = UDim.new(0, 6)
        jc.Parent = jb
        jb.Parent = row
    end

    return row
end

local JOB_HINT = "Tap a trade letter to see what it does."

-- Ce ii lipseste ca sa poata lucra, sau nil daca are tot. Se calculeaza pe CLIENT, din lista de
-- cladiri pe care o are deja: nu cere nimic in plus de la server.
local function missingWorkplace(job: string): string?
    local need = JOB_NEEDS[job]
    if need == nil or buildings == nil then
        return nil
    end
    for _, b in (buildings :: () -> { { [string]: any } })() do
        local d = BuildingConfig.get(b.defId)
        if d ~= nil and d.kind == need.kind and b.progress >= d.buildWork then
            return nil
        end
    end
    return need.what
end

local function describeJob(job: string)
    if jobInfo == nil then
        return
    end
    local info = (SettlerConfig.JOB_INFO :: any)[job]
    if info == nil then
        jobInfo.Text = JOB_HINT
        return
    end
    local blocked = missingWorkplace(job)
    if blocked ~= nil then
        -- avertisment INAINTE sa dai meseria, nu dupa ce omul se plimba degeaba zece minute
        jobInfo.Text = `{job} — {info}  ⚠ You have not built {blocked} yet.`
        jobInfo.TextColor3 = Theme.COLOR.warn
    else
        jobInfo.Text = `{job} — {info}`
        jobInfo.TextColor3 = Theme.COLOR.ink
    end
end

local function computeAlert()
    if source == nil or onAlert == nil then
        return
    end
    local worstName, worstValue, worstId, count = nil, 100, nil, 0
    for _, person in source() do
        local w = math.min(
            person.needs.fed or 100,
            person.needs.rested or 100,
            person.needs.content or 100
        )
        if w < SettlerConfig.NEED_WARN then
            count += 1
            if w < worstValue then
                worstName, worstValue, worstId = person.name, w, person.id
            end
        end
    end
    onAlert(
        count,
        worstName,
        if worstId ~= nil
            then function()
                SettlerPanelController.FocusOn(worstId :: number)
            end
            else nil
    )
end

local function refresh()
    if source == nil or not panel.Visible then
        return
    end
    local people = source()
    table.sort(people, function(a, b)
        local aw = math.min(a.needs.fed or 100, a.needs.rested or 100, a.needs.content or 100)
        local bw = math.min(b.needs.fed or 100, b.needs.rested or 100, b.needs.content or 100)
        return aw < bw
    end)

    local warned = 0
    for i, person in people do
        local row = rows[i]
        if row == nil then
            row = makeRow(i)
            rows[i] = row
        end
        row.Visible = true
        local button = row :: TextButton
        if rowConnections[i] then
            rowConnections[i]:Disconnect()
        end
        local personId = person.id
        rowConnections[i] = button.Activated:Connect(function()
            SettlerPanelController.FocusOn(personId)
        end)
        -- butoanele de meserie: evidentiaza meseria curenta si trimite schimbarea la server
        for _, job in SettlerConfig.JOBS do
            local jb = row:FindFirstChild(`Job_{job}`) :: TextButton
            local active = person.job == job
            local bg = if active then Theme.COLOR.gold else Theme.COLOR.parchmentDim
            local fg = if active then Theme.COLOR.ink else Theme.COLOR.inkSoft
            if jb.BackgroundColor3 ~= bg then
                jb.BackgroundColor3 = bg
                jb.TextColor3 = fg
            end
            if jobConnections[i] == nil then
                jobConnections[i] = {}
            end
            local existing = jobConnections[i][job]
            if existing then
                existing:Disconnect()
            end
            local pid = person.id
            jobConnections[i][job] = jb.Activated:Connect(function()
                describeJob(job)
                if setJob ~= nil then
                    setJob(pid, job)
                end
            end)
            -- pe desktop se afla doar trecand cu mausul, fara sa schimbi nimic
            if hoverConnections[jb] == nil then
                hoverConnections[jb] = jb.MouseEnter:Connect(function()
                    describeJob(job)
                end)
            end
        end

        local nameLabel = row:FindFirstChild("PersonName") :: TextLabel
        local jobLabel = row:FindFirstChild("Job") :: TextLabel
        local taskLabel = row:FindFirstChild("Task") :: TextLabel
        nameLabel.Text = person.name
        local traitText = ""
        if person.traits ~= nil and #person.traits > 0 then
            local labels = {}
            for _, id in person.traits do
                for _, t in SettlerConfig.TRAITS do
                    if t.id == id then
                        table.insert(labels, t.label)
                    end
                end
            end
            traitText = ` · {table.concat(labels, ", ")}`
        end
        jobLabel.Text = `{person.job}{traitText}`
        -- Daca sta degeaba pentru ca ii lipseste postul de lucru, ASTA se scrie, nu "idle".
        -- "idle" e o stare; "needs a Garden" e o instructiune.
        local blocked = missingWorkplace(person.job)
        if blocked ~= nil and person.task == "idle" then
            taskLabel.Text = `needs {blocked}`
            taskLabel.TextColor3 = Theme.COLOR.warn
        else
            taskLabel.Text = TASK_LABEL[person.task] or person.task
            taskLabel.TextColor3 = Theme.COLOR.inkSoft
        end
        local worst = 100
        for _, need in SettlerConfig.NEEDS do
            local v = person.needs[need.id] or 100
            worst = math.min(worst, v)
            local bar = row:FindFirstChild(`Bar_{need.id}`) :: Frame
            local fill = bar:FindFirstChild("Fill") :: Frame
            fill.Size = UDim2.fromScale(math.clamp(v / SettlerConfig.NEED_MAX, 0, 1), 1)
            fill.BackgroundColor3 = if v < SettlerConfig.NEED_WARN
                then Theme.COLOR.bad
                else (NEED_COLORS[need.id] or Theme.COLOR.inkSoft)
        end
        row.BackgroundColor3 = if worst < SettlerConfig.NEED_WARN
            then Theme.COLOR.bad
            else Theme.COLOR.parchmentDim
        if worst < SettlerConfig.NEED_WARN then
            warned += 1
        end
    end
    for i = #people + 1, #rows do
        rows[i].Visible = false
    end
    list.CanvasSize = UDim2.fromOffset(0, #people * 58)
    summary.Text = if warned > 0
        then `{#people} settlers · {warned} need attention · click a row to jump there`
        else `{#people} settlers · all well`
    summary.TextColor3 = if warned > 0 then Theme.COLOR.bad else Theme.COLOR.inkSoft
end

-- Cand jucatorul se misca singur, selectia dispare odata cu focusul
function SettlerPanelController.ClearSelection()
    focusedId = nil
    if onSelect ~= nil then
        onSelect(nil)
    end
end

function SettlerPanelController.Toggle()
    if panel == nil then
        return
    end
    if not panel.Visible and not Panels.CanOpen("people") then
        return
    end
    panel.Visible = not panel.Visible
    if panel.Visible then
        Panels.CloseOthers("settlers")
        refresh()
    end
end

function SettlerPanelController.IsOpen(): boolean
    return panel ~= nil and panel.Visible
end

function SettlerPanelController.Close()
    if panel ~= nil then
        panel.Visible = false
    end
end

function SettlerPanelController.Init(deps: {
    HudGui: Frame,
    GetSettlers: () -> { { [string]: any } },
    PositionOf: (number) -> (number?, number?),
    OnSelect: (number?) -> (),
    OnAlert: (number, string?, (() -> ())?) -> (),
    SetJob: (number, string) -> (),
    GetBuildings: (() -> { { [string]: any } })?,
})
    source = deps.GetSettlers
    buildings = deps.GetBuildings
    positionOf = deps.PositionOf
    onSelect = deps.OnSelect
    onAlert = deps.OnAlert
    setJob = deps.SetJob

    local root, body = Widgets.Window(deps.HudGui, {
        name = "SettlerPanel",
        title = "People",
        icon = "people",
        width = 720,
        height = 660,
        z = 30,
        onClose = SettlerPanelController.Close,
    })
    root.AnchorPoint = Vector2.new(0, 0.5)
    root.Position = UDim2.new(0, Theme.SPACE.lg, 0.5, 0)
    root.Visible = false
    panel = root

    summary = Widgets.Label(body, "", Theme.TEXT.small, Theme.COLOR.inkSoft, "body")
    summary.Size = UDim2.new(1, 0, 0, 20)

    -- TEXT.small, nu tiny: e singurul lucru care spune ce inseamna literele de pe butoane
    local legend = Widgets.Label(
        body,
        "F fisher · C crafter · B builder · G gardener · I innkeeper",
        Theme.TEXT.small,
        Theme.COLOR.inkSoft,
        "body"
    )
    legend.Position = UDim2.fromOffset(0, 22)
    legend.Size = UDim2.new(1, 0, 0, 20)

    -- Ce FACE meseria pe care o atingi. Butoanele aveau cate o litera si nimic altceva: pasul de
    -- tutorial cerea "alege o meserie" iar jucatorul alegea orbeste, fara sa stie ce schimba.
    jobInfo = Widgets.Label(body, JOB_HINT, Theme.TEXT.small, Theme.COLOR.ink, "strong")
    jobInfo.AnchorPoint = Vector2.new(0, 1)
    jobInfo.Position = UDim2.fromScale(0, 1)
    jobInfo.Size = UDim2.new(1, 0, 0, 36)
    jobInfo.TextWrapped = true
    jobInfo.TextYAlignment = Enum.TextYAlignment.Top

    list = Widgets.List(body, 30)
    local holder = list.Parent :: Frame
    holder.Position = UDim2.fromOffset(0, 48)
    holder.Size = UDim2.new(1, 0, 1, -48 - 40)

    Panels.Register("settlers", {
        isOpen = SettlerPanelController.IsOpen,
        close = SettlerPanelController.Close,
    })

    UserInputService.InputBegan:Connect(function(input: InputObject, processed: boolean)
        if not processed and input.KeyCode == Enum.KeyCode.Tab then
            SettlerPanelController.Toggle()
        end
    end)

    local acc = 0
    RunService.Heartbeat:Connect(function(dt: number)
        acc += dt
        if acc >= 0.5 then
            acc = 0
            refresh()
            computeAlert()
        end
    end)
end

return SettlerPanelController
