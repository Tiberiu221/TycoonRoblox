--!strict
-- Poarta consolei de dezvoltare, citita de DevService. Modul FRUNZA: nu cere nimic altceva, ca sa
-- poata fi cerut de orice serviciu fara require incrucisat. Comutatoarele de colonie (viteza
-- timpului, pauza povestitorului) au plecat odata cu colonia in F0.
local RunService = game:GetService("RunService")

local DevState = {}

function DevState.Enabled(): boolean
    return RunService:IsStudio()
end

return DevState
