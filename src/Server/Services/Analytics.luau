--!strict
-- Funnel de onboarding [DECIZII D25, MASTERPLAN 11.2]. Functioneaza doar in joc publicat, doar pe server; in Studio esueaza silentios.
local AnalyticsService = game:GetService("AnalyticsService")

local Analytics = {}

Analytics.STEPS = {
    Joined = 1,
    PlacedFirstNet = 2,
    CaughtFirstItem = 3,
    ReachedWorkshop = 4,
    StartedFirstRepair = 5,
    FirstRepairComplete = 6,
    SawOfflineHook = 7,
    NotificationOptInShown = 8,
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
