--!strict
-- Comutatoare de dezvoltare, citite de restul serviciilor. Modul FRUNZA: nu cere nimic altceva,
-- ca sa poata fi cerut de SettlerService si StorytellerService fara require incrucisat.
-- In productie nimic nu scrie aici, deci valorile raman cele implicite.
local RunService = game:GetService("RunService")

local DevState = {}

local timeScale = 1
local storytellerPaused = false

-- Cat de repede curge timpul simulat (nevoi, munca, povestitor). 1 = normal.
function DevState.TimeScale(): number
    return timeScale
end

function DevState.SetTimeScale(value: number)
    if not RunService:IsStudio() then
        return -- unealta de test: in productie e inerta, orice s-ar trimite
    end
    timeScale = math.clamp(value, 1, 120)
end

function DevState.StorytellerPaused(): boolean
    return storytellerPaused
end

function DevState.SetStorytellerPaused(value: boolean)
    if not RunService:IsStudio() then
        return
    end
    storytellerPaused = value
end

function DevState.Enabled(): boolean
    return RunService:IsStudio()
end

return DevState
