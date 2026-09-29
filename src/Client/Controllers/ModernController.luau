--!strict
-- [D70] SATUL SE MODERNIZEAZA IN ERA 3. Owner-ul, 2026-09-24: "aș prefera ca de la Era 3 harta să se schimbe progresiv,
-- din ce în ce mai modernă." Treapta (ModernMath, din starea jocului) decide desenul: sarma pe strazi, carucioarele de
-- fier, tabla si caramida, geamurile, luminile (UI/Modern), plus ce apare pe teren (UI/ModernProps). La o treapta noua,
-- fiecare desen se reface o data si fiecare treapta urcata se anunta, pe rand [D43]; cine intra in joc cu satul deja
-- modernizat nu mai primeste anuntul.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ModernMath = require(ReplicatedStorage.Shared.Modules.ModernMath)
local Modern = require(script.Parent.Parent.UI.Modern)
local ModernProps = require(script.Parent.Parent.UI.ModernProps)

local ModernController = {}

export type Deps = {
    Plot: GuiObject,
    -- ce se redeseneaza la o treapta noua (cladirile vechi, casele, roabele)
    Refresh: { () -> () },
    -- anuntul unei trepte noi, urcate chiar acum
    OnStage: ((stage: number) -> ())?,
}

local deps: Deps? = nil
local props: ModernProps.Props? = nil
local current: number? = nil -- nil = inca nicio stare de la server
local lastPower: boolean? = nil

-- Anunturile vin pe rand, fiecare dupa cel dinainte: primul dupa toastul cumparaturii care a urcat treapta (serverul
-- trimite PadBought / CrewUpgraded inaintea starii, iar HUDController.Toast tine 2,6 s), iar un salt peste mai multe
-- trepte le spune pe toate, nu doar pe ultima [D43].
local ANNOUNCE_GAP = 2.8
local nextFreeAt = 0

local function queueAnnouncement(announce: (stage: number) -> (), stage: number)
    local now = os.clock()
    local at = math.max(now + ANNOUNCE_GAP, nextFreeAt)
    nextFreeAt = at + ANNOUNCE_GAP
    task.delay(at - now, announce, stage)
end

function ModernController.Init(d: Deps)
    deps = d
    props = ModernProps.draw(d.Plot, Modern.stage)
end

function ModernController.Apply(facts: ModernMath.Facts)
    local stage = ModernMath.stage(facts)
    -- primul curent s-a vandut chiar in starea asta: felinarele il anunta deja (LAMPS_ON), deci treapta 5 tace
    local lampsJustLit = lastPower == false and facts.powerSold
    lastPower = facts.powerSold
    if stage == current then
        return
    end
    local from = current
    current = stage
    Modern.stage = stage
    local p = props
    if p ~= nil then
        p.set(stage)
    end
    local d = deps
    if d == nil then
        return
    end
    for _, refresh in d.Refresh do
        refresh()
    end
    local announce = d.OnStage
    -- cine intra in joc cu satul deja modernizat nu primeste anuntul (prima stare), nici o treapta care coboara
    if announce == nil or from == nil or stage <= from then
        return
    end
    for s = from + 1, stage do
        local step = ModernMath.STAGES[s]
        if not (lampsJustLit and step ~= nil and step.power == true) then
            queueAnnouncement(announce, s)
        end
    end
end

return ModernController
