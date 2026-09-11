--!strict
-- Funnel de onboarding [DECIZII D25, MASTERPLAN 11.2]. Functioneaza doar in joc publicat, doar pe server; in Studio esueaza silentios.
local AnalyticsService = game:GetService("AnalyticsService")

local Analytics = {}

-- Renumerotat la pivotul D45 (tycoon): fara jucatori reali inca, deci renumerotarea e sigura [F0 spec 3.7]
Analytics.STEPS = {
    Joined = 1,
    BoughtFirstNet = 2,
    FirstCatch = 3,
    FirstCollect = 4,
    FirstSell = 5,
    BoughtSecondNet = 6,
    BoughtPad5 = 7,
}

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
