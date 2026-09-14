--!strict
-- Oamenii: pozitia si animatia celor care merg vin DOAR din HandMath.sampleAt(ciclu, serverNow -
-- cycleStartAt), cu ciclul refacut din HandRoutes cu exact aceleasi argumente ca pe server -- nimic
-- interpolat local, nimic asteptat de la retea [F1 spec 4.4, D49]. Atins, un om deschide meniul
-- meseriei lui. Desenul (straturile, animatia, roaba) e in PersonView [D50]; aici ramane unde e omul,
-- ce face, ce spune si ce se intampla cand il atingi.
-- [D55] Cine cara impinge o roaba: merge cu ea, incarca la opriri ("collect"), rastoarna unde lasa ("drop",
-- "sell") -- nu mai bate cu ciocanul. In roaba se vede felul pe care il duce (`carryKind`, de la server).
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local HandMath = require(ReplicatedStorage.Shared.Modules.HandMath)
local HandRoutes = require(ReplicatedStorage.Shared.Modules.HandRoutes)
local Theme = require(script.Parent.Parent.UI.Theme)
local Widgets = require(script.Parent.Parent.UI.Widgets)
local PersonView = require(script.Parent.Parent.UI.PersonView)

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
    scrap: boolean?, -- [D55] drumul prin shed si atelier (acelasi argument ca pe server)
    capacity: number, -- cat duce pe un drum: debit x durata ciclului [D40, D49]
    appearance: Appearance,
    -- doar pentru rolurile STATICE (Sawyer, Innkeeper): locul in care stau. Fara ciclu n-ar avea de
    -- unde sa iasa o pozitie.
    x: number?,
    y: number?,
}

export type Deps = { Plot: Frame, OpenCrew: ((string) -> ())? }

type Hand = {
    snap: HandSnap,
    cycle: HandMath.Cycle,
    view: PersonView.View,
    frame: Frame,
    bubble: TextLabel?,
    bubbleUntil: number?,
}

local HandRenderController = {}
local deps: Deps
local tracked: { [string]: Hand } = {}

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

-- Ce spune un om cand apare prima data in sesiune: exact treaba lui, pe drumul lui [D40, D49].
local function hello(snap: HandSnap): string?
    local role = snap.role
    if role == "collector" then
        return `I'm {snap.name}. I'll empty your nets into the storage.`
    elseif role == "porter" then
        return `I'm {snap.name}. I'll carry logs from the storage to the sawmill.`
    elseif role == "sawyer" then
        return `I'm {snap.name}. I'll keep the saw running, even while you're away.`
    elseif role == "hauler" then
        return `I'm {snap.name}. I'll take the planks from the sawmill to the tavern.`
    elseif role == "trader" then
        return `I'm {snap.name}. I'll keep the tavern selling while you're away.`
    end
    return nil
end

-- [I4] O singura replica, ~5s, cand omul asta apare prima data in sesiune. Neblocant: personajul se
-- misca liber in tot acest timp.
local function showBubble(rec: Hand, text: string)
    if rec.bubble ~= nil then
        return
    end
    local bubble = Widgets.PlateLabel(deps.Plot, text, Theme.TEXT.small, "strong")
    bubble.AnchorPoint = Vector2.new(0.5, 1)
    bubble.Size = UDim2.fromOffset(280, 48)
    bubble.TextWrapped = true
    bubble.TextXAlignment = Enum.TextXAlignment.Center
    bubble.ZIndex = 9
    rec.bubble = bubble
    rec.bubbleUntil = os.clock() + 5
end

local function ensureHand(snap: HandSnap): Hand
    local existing = tracked[snap.id]
    if existing ~= nil then
        return existing
    end
    local view =
        PersonView.new(deps.Plot, snap.id, if HandRoutes.isWalker(snap.role) then "barrow" else nil)

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
    }
    tracked[snap.id] = rec
    return rec
end

local function render(dt: number)
    local now = Workspace:GetServerTimeNow()
    for _, rec in tracked do
        if not rec.frame.Visible then
            continue
        end
        local snap = rec.snap
        local x, y, state, facing
        if snap.x ~= nil and snap.y ~= nil then
            -- rol static: sta pe loc si respira, fata spre jucator
            x, y, state, facing = snap.x, snap.y, "idle", "down"
        else
            x, y, state, facing = HandMath.sampleAt(rec.cycle, now - snap.cycleStartAt)
        end
        -- [D55] cu roaba: merge, incarca la opriri de luat, rastoarna la cele de lasat si la capat
        local task = if state == "walk"
            then "push"
            elseif state == "collect" then "load"
            elseif state == "drop" or state == "sell" then "tip"
            else "idle"
        rec.view.SetCarry(snap.carryKind, loadStep(snap.carrying, snap.capacity))
        rec.view.Pose(x, y, task, facing, state == "walk", dt)

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
            rec.cycle = HandRoutes.cycleFor(
                snap.role,
                snap.index,
                snap.count,
                snap.nets,
                snap.scrap == true
            )
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
        end
    end
end

function HandRenderController.Init(d: Deps)
    deps = d
    RunService.PreRender:Connect(render)
end

return HandRenderController
