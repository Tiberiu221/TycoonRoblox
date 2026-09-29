--!strict
-- Oamenii: pozitia si animatia celor care merg vin DOAR din HandMath.sampleAt(ciclu, serverNow -
-- cycleStartAt), cu ciclul refacut din HandRoutes cu exact aceleasi argumente ca pe server -- nimic
-- interpolat local, nimic asteptat de la retea [F1 spec 4.4, D49]. Atins, un om deschide meniul
-- meseriei lui. Desenul (straturile, animatia, roaba) e in PersonView [D50]; aici ramane unde e omul,
-- ce face, ce spune si ce se intampla cand il atingi.
-- [D55] Cine cara impinge o roaba: merge cu ea, incarca la opriri ("collect"), rastoarna unde lasa ("drop",
-- "sell") -- nu mai bate cu ciocanul. In roaba se vede felul pe care il duce (`carryKind`, de la server).
-- [D56] Smelter-ul sta langa forja si bate cu ciocanul cat forja chiar topeste (`IsWorking`, din starea forjei de pe
-- client -- nu un camp nou pe om, care ar fi trebuit copiat inca o data).
-- [D58] Owner-ul: "cand ma apropii de npc-uri sa le vad job-ul sub ei". Meseria (numele din TycoonConfig.CREWS, ca in
-- meniul care se deschide cand il atingi) apare sub picioare cand treci pe langa om si se stinge cand pleci -- pe
-- toti deodata, strada ar fi plina de etichete.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local HandMath = require(ReplicatedStorage.Shared.Modules.HandMath)
local HandRoutes = require(ReplicatedStorage.Shared.Modules.HandRoutes)
local HandConfig = require(ReplicatedStorage.Shared.Config.HandConfig)
local Strings = require(ReplicatedStorage.Shared.Config.Strings)
local TycoonConfig = require(ReplicatedStorage.Shared.Config.TycoonConfig)
local Theme = require(script.Parent.Parent.UI.Theme)
local Widgets = require(script.Parent.Parent.UI.Widgets)
local PersonView = require(script.Parent.Parent.UI.PersonView)
local Modern = require(script.Parent.Parent.UI.Modern)

export type Appearance = PersonView.Appearance
export type HandSnap = {
    id: string,
    role: string,
    name: string,
    index: number, -- al catelea om din meseria lui (1 sau 2)
    count: number, -- cati oameni are meseria: doi Collectori isi impart plasele
    tier: number,
    nets: { string },
    cycleStartAt: number,
    carrying: number,
    carryKind: string?, -- [D55] ce se vede in roaba: felul cu cele mai multe bucati
    capacity: number, -- cat duce pe un drum: debit x durata ciclului [D40, D49]
    appearance: Appearance,
    -- doar pentru rolurile STATICE (Sawyer, Innkeeper): locul in care stau. Fara ciclu n-ar avea de
    -- unde sa iasa o pozitie.
    x: number?,
    y: number?,
}

export type Deps = {
    Plot: Frame,
    OpenCrew: ((string) -> ())?,
    -- [D58] unde e personajul tau (coordonate de lume): meseria se scrie sub oamenii de langa el
    CharacterPos: (() -> (number, number))?,
    -- [D56] cladirea omului lucreaza chiar acum (Smelter-ul: forja topeste)
    IsWorking: ((role: string) -> boolean)?,
}

type Hand = {
    snap: HandSnap,
    cycle: HandMath.Cycle,
    view: PersonView.View,
    frame: Frame,
    bubble: TextLabel?,
    bubbleUntil: number?,
    job: TextLabel, -- [D58] meseria, sub picioare
    jobStroke: UIStroke?,
    jobAlpha: number, -- 0 = stinsa, 1 = aprinsa; se misca lin spre tinta
    jobDrop: number, -- cat sta sub picioare: mai jos cand roaba e in fata omului, spre tine
}

local HandRenderController = {}
local deps: Deps
local tracked: { [string]: Hand } = {}

-- [D58] Raza in care se vede meseria: putin peste raza cardului obiectelor (RiverConfig.INTERACT_DISTANCE = 130), ca
-- numele sa apara inainte sa ajungi langa om. Aprinderea si stingerea dureaza JOB_FADE secunde.
local JOB_RADIUS = 170
local JOB_FADE = 0.2
-- Sub picioare: 4 px. Cand omul impinge roaba spre tine, ea iese 27.5 px sub picioare (in PersonView, vederea `down` a
-- roabei: de la randul 15, 20 de randuri inalta, 2.5 px pe rand), deci eticheta coboara sub ea; lateral si de la tine
-- roaba ramane in dreptul omului.
local JOB_DROP, JOB_DROP_BARROW = 4, 32
-- Incarcatura din roaba creste in TREPTE (1..3), raportat la cat duce omul pe un drum (`capacity`,
-- trimisa de server), nu la o cifra ghicita [research 42 pct.3].
local function loadStep(carrying: number, capacity: number): number
    if carrying <= 0 then
        return 0
    end
    local frac = carrying / math.max(1, capacity)
    if frac >= 0.66 then
        return 3
    elseif frac >= 0.33 then
        return 2
    end
    return 1
end

-- Ce spune un om cand apare prima data in sesiune: exact treaba lui, pe drumul lui [D40, D49]. Textele stau in
-- Strings.crewHello, pentru toate meseriile [D65].
local function hello(snap: HandSnap): string?
    return Strings.crewHello(snap.role, snap.name)
end

-- [I4] O singura replica, ~5s, cand omul asta apare prima data in sesiune. Neblocant: personajul se
-- misca liber in tot acest timp. [D62] `seconds` si `width`: replica scurta de la o treapta noua.
local function showBubble(rec: Hand, text: string, seconds: number?, width: number?)
    if rec.bubble ~= nil then
        return
    end
    local bubble = Widgets.PlateLabel(deps.Plot, text, Theme.TEXT.small, "strong")
    bubble.AnchorPoint = Vector2.new(0.5, 1)
    bubble.Size = UDim2.fromOffset(width or 280, if width ~= nil then 30 else 48)
    bubble.TextWrapped = true
    bubble.TextXAlignment = Enum.TextXAlignment.Center
    bubble.ZIndex = 47 -- [D67, audit] peste banda de adancime a lumii (felinare, oameni), ca numele cladirilor (46)
    rec.bubble = bubble
    rec.bubbleUntil = os.clock() + (seconds or 5)
end

-- Numele meseriei, cum il spune meniul ei ("Scrap Porter"); rolul brut doar daca ar lipsi din config.
local function jobName(role: string): string
    local crew = TycoonConfig.CREWS[role]
    return if crew ~= nil then crew.name else role
end

local function ensureHand(snap: HandSnap): Hand
    local existing = tracked[snap.id]
    if existing ~= nil then
        return existing
    end
    local view =
        PersonView.new(deps.Plot, snap.id, if HandRoutes.isWalker(snap.role) then "barrow" else nil)

    -- [D58] meseria: text peste lume, ca numele cladirilor (fontul de pixeli, conturat). [D67, audit] Sta pe teren, nu in
    -- om, la z 46 ca numele cladirilor: copil al omului, avea adancimea lui, iar stalpul unui felinar il taia in doua
    -- ("WORKS POR|ER"). Il muta `updateJob` dupa om, la fiecare cadru cat se vede.
    local job =
        Widgets.Label(deps.Plot, jobName(snap.role), Theme.TEXT.tiny, Theme.COLOR.onDark, "strong")
    job.Name = "Job"
    job.AnchorPoint = Vector2.new(0.5, 0)
    job.Size = UDim2.fromOffset(160, 16)
    job.TextXAlignment = Enum.TextXAlignment.Center
    job.TextTransparency = 1
    job.ZIndex = 46
    job.Visible = false
    Theme.punch(job, 2)
    -- conturul are transparenta lui, separata de a textului: se stinge odata cu el
    local jobStroke: UIStroke? = nil
    local stroke = job:FindFirstChild("Punch")
    if stroke ~= nil and stroke:IsA("UIStroke") then
        stroke.Transparency = 1
        jobStroke = stroke
    end

    -- Atins, omul deschide meniul meseriei lui: acolo se urca treapta si se angajeaza al doilea.
    local tap = Instance.new("TextButton")
    tap.Name = "Tap"
    tap.Text = ""
    tap.AutoButtonColor = false
    tap.BackgroundTransparency = 1
    tap.Size = UDim2.fromScale(1, 1)
    tap.ZIndex = 10
    tap.Parent = view.frame
    local role = snap.role
    tap.Activated:Connect(function()
        local open = deps.OpenCrew
        if open ~= nil then
            open(role)
        end
    end)

    local rec: Hand = {
        snap = snap,
        cycle = { legs = {}, duration = 0 },
        view = view,
        frame = view.frame,
        bubble = nil,
        bubbleUntil = nil,
        job = job,
        jobStroke = jobStroke,
        jobAlpha = 0,
        jobDrop = JOB_DROP,
    }
    tracked[snap.id] = rec
    return rec
end

-- [D58] Meseria de sub om: se aprinde in raza personajului tau, se stinge in afara ei, lin (fara sa clipeasca la
-- marginea razei). Proprietatile se scriu doar cand se schimba -- ruleaza pe fiecare om, la fiecare cadru.
local function updateJob(
    rec: Hand,
    x: number,
    y: number,
    barrowFront: boolean,
    px: number?,
    py: number?,
    dt: number
)
    local near = px ~= nil
        and py ~= nil
        and (x - px) * (x - px) + (y - py) * (y - py) <= JOB_RADIUS * JOB_RADIUS
    local step = if JOB_FADE > 0 then dt / JOB_FADE else 1
    local alpha = if near
        then math.min(1, rec.jobAlpha + step)
        else math.max(0, rec.jobAlpha - step)
    local job = rec.job
    if alpha ~= rec.jobAlpha then
        rec.jobAlpha = alpha
        job.TextTransparency = 1 - alpha
        local stroke = rec.jobStroke
        if stroke ~= nil then
            stroke.Transparency = 1 - alpha
        end
    end
    local visible = alpha > 0
    if job.Visible ~= visible then
        job.Visible = visible
    end
    if not visible then
        return
    end
    local target = if barrowFront then JOB_DROP_BARROW else JOB_DROP
    if rec.jobDrop ~= target then
        -- coboara si urca in ~0.15 s, cat omul coteste: fara salt de 28 px la fiecare colt
        local delta = target - rec.jobDrop
        local move = dt * 190
        rec.jobDrop = if math.abs(delta) <= move
            then target
            else rec.jobDrop + math.sign(delta) * move
    end
    -- sub talpile omului (x, y), pe teren
    local at = UDim2.fromOffset(math.round(x), math.round(y + rec.jobDrop))
    if job.Position ~= at then
        job.Position = at
    end
end

local function render(dt: number)
    local now = Workspace:GetServerTimeNow()
    local px: number?, py: number? = nil, nil
    local characterPos = deps.CharacterPos
    if characterPos ~= nil then
        local cx, cy = characterPos()
        px, py = cx - TycoonConfig.PLOT_ORIGIN.x, cy - TycoonConfig.PLOT_ORIGIN.y
    end
    for _, rec in tracked do
        if not rec.frame.Visible then
            continue
        end
        local snap = rec.snap
        local x, y, state, facing
        if snap.x ~= nil and snap.y ~= nil then
            -- rol static: sta pe loc si respira, fata spre jucator
            x, y, state, facing = snap.x, snap.y, "idle", "down"
            local isWorking = deps.IsWorking
            local pose = HandConfig.WORKING_POSE[snap.role]
            if pose ~= nil and isWorking ~= nil and isWorking(snap.role) then
                -- [D56] cu fata spre atelierul lui, ciocanul in mana
                state, facing = "working", pose
            end
        else
            x, y, state, facing = HandMath.sampleAt(rec.cycle, now - snap.cycleStartAt)
        end
        -- [D55] cu roaba: merge, incarca la opriri de luat, rastoarna la cele de lasat si la capat
        local task = if state == "walk"
            then "push"
            elseif state == "collect" then "load"
            elseif state == "drop" or state == "sell" then "tip"
            elseif state == "working" then "working"
            else "idle"
        rec.view.SetCarry(snap.carryKind, loadStep(snap.carrying, snap.capacity))
        rec.view.Pose(x, y, task, facing, state == "walk", dt)
        -- roaba sta sub picioare doar cand omul o impinge spre tine; la incarcat si rasturnat e intoarsa lateral
        local barrowFront = HandRoutes.isWalker(snap.role)
            and facing == "down"
            and task ~= "load"
            and task ~= "tip"
        updateJob(rec, x, y, barrowFront, px, py, dt)

        if rec.bubble ~= nil then
            rec.bubble.Position =
                UDim2.fromOffset(math.round(x), math.round(y) - PersonView.HEIGHT - 18)
            if os.clock() >= (rec.bubbleUntil :: number) then
                rec.bubble:Destroy()
                rec.bubble = nil
            end
        end
    end
end

-- Starea vine din TycoonState, inlocuita in intregime la fiecare mesaj [F0 spec 4.1]. Ciclul se
-- reconstruieste de fiecare data -- ieftin (drumurile sunt memorate in HandRoutes) si evita orice
-- cache invechit cand plasele omului se schimba.
function HandRenderController.Apply(hands: { HandSnap })
    local seen: { [string]: boolean } = {}
    for _, snap in hands do
        seen[snap.id] = true
        local isNew = tracked[snap.id] == nil
        local rec = ensureHand(snap)
        rec.snap = snap
        rec.view.SetAppearance(snap.appearance)
        if snap.x == nil then
            rec.cycle = HandRoutes.cycleFor(snap.role, snap.index, snap.count, snap.nets)
        end
        if not rec.frame.Visible then
            rec.frame.Visible = true
        end
        local line = if isNew then hello(snap) else nil
        if line ~= nil then
            showBubble(rec, line)
        end
    end
    -- nimic nu se pierde, deci un om nu ar trebui sa dispara -- simetric cu NetController
    for id, rec in tracked do
        if not seen[id] and rec.frame.Visible then
            rec.frame.Visible = false
            rec.job.Visible = false -- [D67, audit] eticheta sta pe teren, nu in om: se ascunde separat
        end
    end
end

-- [D62] Oamenii unei meserii spun ceva cand le cumperi o treapta: treapta nu le schimba infatisarea, deci altfel
-- cumparatura nu s-ar vedea nicaieri in lume.
function HandRenderController.Cheer(role: string)
    for _, rec in tracked do
        if rec.snap.role == role and rec.frame.Visible then
            showBubble(rec, Strings.CREW_TIER_THANKS, 2.5, 200)
        end
    end
end

-- [D70] Satul a urcat o treapta de modernizare: roabele tuturor devin carucioare de fier (UI/Modern, treapta 2).
function HandRenderController.SetModern()
    local sprite = Modern.barrow()
    for _, rec in tracked do
        rec.view.SetBarrowArt(sprite)
    end
end

function HandRenderController.Init(d: Deps)
    deps = d
    RunService.PreRender:Connect(render)
end

return HandRenderController
