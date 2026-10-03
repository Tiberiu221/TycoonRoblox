--!strict
-- [D70] SATUL SE MODERNIZEAZA IN ERA 3. Owner-ul, 2026-09-24: "aș prefera ca de la Era 3 harta să se schimbe progresiv,
-- din ce în ce mai modernă." Treapta (ModernMath, din starea jocului) decide desenul: sarma pe strazi, carucioarele de
-- fier, tabla si caramida, geamurile, luminile (UI/Modern), plus ce apare pe teren (UI/ModernProps). La o treapta noua,
-- fiecare desen se reface o data si fiecare treapta urcata se anunta, pe rand [D43]; cine intra in joc cu satul deja
-- modernizat nu mai primeste anuntul.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local ModernMath = require(ReplicatedStorage.Shared.Modules.ModernMath)
local Assets = require(ReplicatedStorage.Shared.Config.Assets)
local RiverConfig = require(ReplicatedStorage.Shared.Config.RiverConfig)
local Strings = require(ReplicatedStorage.Shared.Config.Strings)
local TycoonConfig = require(ReplicatedStorage.Shared.Config.TycoonConfig)
local Modern = require(script.Parent.Parent.UI.Modern)
local ModernProps = require(script.Parent.Parent.UI.ModernProps)
local Focus = require(script.Parent.Parent.UI.Focus)

local ModernController = {}

export type Deps = {
    Plot: GuiObject,
    -- ce se redeseneaza la o treapta noua (cladirile vechi, casele, roabele)
    Refresh: { () -> () },
    -- anuntul unei trepte noi, urcate chiar acum
    OnStage: ((stage: number) -> ())?,
    -- [D73] o privire spre un loc al terenului (coordonatele lui TycoonConfig), cu o nota pe un toast: masa cu planurile
    -- arata tarusii topografilor de langa ponton
    Look: ((x: number, y: number, note: string) -> ())?,
    -- [D70, pasul k6] cu barajul in joc: se poate ridica acum (serverul, `damAvailable`), si ce deschide E (ecranul, k7)
    DamAvailable: (() -> boolean)?,
    OpenDam: (() -> ())?,
}

local deps: Deps? = nil
local props: ModernProps.Props? = nil
local current: number? = nil -- nil = inca nicio stare de la server
local lastPower: boolean? = nil
-- [2026-09-30] masa cu planurile barajului: treapta de la care e desenata si clopotul dupa care vorbeste (vezi Focus)
local PLANS_STAGE = ModernMath.stageOf("glass") or 4
local plansBell: string? = nil
for _, p in TycoonConfig.PADS do
    if p.motive == "D" and p.era == TycoonConfig.DAM_PLANS.era - 1 then
        plansBell = p.id
    end
end
local bellRung = false

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
    local bell = plansBell
    bellRung = bell ~= nil and facts.pads[bell] == true
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

-- [2026-09-30] Masa cu planurile barajului (de la treapta 4, la capatul Wire Works) are cardul ei: barajul vine, cat
-- Era 4 nu e inca in joc. Apare abia dupa clopotul erei dinainte: pana atunci, pe drumul spre clopot, placa ascundea
-- cartonasul de cumparare al clopotului, iar E dadea un toast in loc sa-l traga. E ii spune pe un toast, ca placuta rotii.

function ModernController.Focus(px: number, py: number): Focus.Focus?
    local stage = current
    local plans = TycoonConfig.DAM_PLANS
    local name = TycoonConfig.eraName(plans.era)
    if stage == nil or stage < PLANS_STAGE or not bellRung or name == nil then
        return nil
    end
    local distance = Focus.distance(px, py, plans.x, plans.y - 20)
    if distance > RiverConfig.INTERACT_DISTANCE then
        return nil
    end
    local h = Assets.tycoon.dam_plans.height * TycoonConfig.PROP_SCALE
    local d0 = deps
    if TycoonConfig.eraIsLive(plans.era) then
        -- [D70, pasul k6] barajul e in joc: masa e drumul spre el („Build the Dam (E)”), cat serverul spune ca se poate
        local available = d0 ~= nil and d0.DamAvailable ~= nil and d0.DamAvailable()
        local open = if d0 ~= nil then d0.OpenDam else nil
        if not available or open == nil then
            return nil
        end
        local keyHint = if UserInputService.KeyboardEnabled then " (E)" else ""
        return {
            key = "dam_plans",
            distance = distance,
            x = plans.x,
            y = plans.y - h - 8,
            action = Strings.plansBuild(keyHint),
            act = open,
        }
    end
    local status = Strings.comingPlans(name :: string)
    local d = deps
    local look = if d ~= nil then d.Look else nil
    -- [D73] barajul se va ridica langa ponton (PLAN-HARTA, sectiunea 6): E arata unde, pe tarusii topografilor (treapta
    -- "glass"), iar toastul spune ca vine
    local stakes = TycoonConfig.SURVEY_STAKES
    if look ~= nil and #stakes > 0 then
        local sx = 0
        for _, s in stakes do
            sx += s.x
        end
        local x, y = sx / #stakes, stakes[1].y - 30
        local keyHint = if UserInputService.KeyboardEnabled then " (E)" else ""
        return {
            key = "dam_plans",
            distance = distance,
            x = plans.x,
            y = plans.y - h - 8,
            action = Strings.plansLook(keyHint),
            act = function()
                look(x, y, Strings.DAM_SITE)
            end,
        }
    end
    return {
        key = "dam_plans",
        distance = distance,
        x = plans.x,
        y = plans.y - h - 8,
        status = status,
    }
end

return ModernController
