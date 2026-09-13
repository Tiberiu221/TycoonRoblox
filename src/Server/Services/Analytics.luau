--!strict
-- Funnel de onboarding [DECIZII D25, MASTERPLAN 11.2]. Functioneaza doar in joc publicat, doar pe server; in Studio esueaza silentios.
local AnalyticsService = game:GetService("AnalyticsService")

local Analytics = {}

-- Renumerotat la pivotul D45 (tycoon), extins la Era 1 completa [F1 spec 3.6], la cele 13 platforme din
-- D49, apoi cu FirstCut [D51]: fara jucatori reali inca, deci renumerotarea e sigura. Platformele Erei 1
-- de la a doua incolo sunt pasii 7..18, in ordinea lor (index + 5), toate BoughtPad<index> (PadService
-- face numele, nu numarul). [D52] Ordinea e cea noua: prima plasa, cei cinci oameni, apoi plasele.
Analytics.STEPS = {
    Joined = 1,
    BoughtFirstNet = 2,
    FirstCatch = 3,
    FirstCollect = 4,
    -- [D51] prima scandura taiata: se vede daca jucatorii se opresc la gater, intre colectare si vanzare
    FirstCut = 5,
    FirstSell = 6,
    BoughtPad2 = 7, -- first_runner (Collector)
    BoughtPad3 = 8, -- hire_porter
    BoughtPad4 = 9, -- hire_sawyer
    BoughtPad5 = 10, -- hire_hauler
    BoughtPad6 = 11, -- dock_trader (Innkeeper)
    BoughtPad7 = 12, -- second_net
    BoughtPad8 = 13, -- third_net
    BoughtPad9 = 14, -- bigger_sack
    BoughtPad10 = 15, -- far_lane_net
    BoughtPad11 = 16, -- workshop
    BoughtPad12 = 17, -- fifth_net
    BoughtPad13 = 18, -- landing_bell
}

-- [D51] Quest-urile, pe un canal propriu, capitol cu capitol, in ordinea din QuestConfig. Pana acum
-- QuestService trimitea "Quest_<id>" in canalul de onboarding, unde nu exista un asemenea pas: fiecare
-- revendicare era aruncata cu un warn, iar canalul quest-urilor n-a inregistrat niciodata nimic.
function Analytics.QuestStep(player: Player, chapterId: string, step: number, questId: string)
    task.spawn(function()
        local ok, err = pcall(function()
            AnalyticsService:LogFunnelStepEvent(player, `Quests_{chapterId}`, nil, step, questId)
        end)
        if not ok then
            print(`[Analytics] quest {chapterId}/{step} {questId} (nelivrat in Studio): {err}`)
        end
    end)
end

function Analytics.Funnel(player: Player, stepName: string)
    local step = Analytics.STEPS[stepName]
    if step == nil then
        warn(`[Analytics] pas de funnel necunoscut: {stepName}`)
        return
    end
    task.spawn(function()
        local ok, err = pcall(function()
            AnalyticsService:LogOnboardingFunnelStepEvent(player, step, stepName)
        end)
        if not ok then
            print(`[Analytics] funnel {step} {stepName} (nelivrat in Studio): {err}`)
        end
    end)
end

return Analytics
