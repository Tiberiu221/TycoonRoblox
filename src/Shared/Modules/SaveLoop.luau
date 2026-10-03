--!strict
-- [D70, verificatorul j15] SALVAREA FORTATA, pura: salveaza pana cand ce trebuia sa ajunga in DataStore chiar a ajuns
-- (`isSaved` citeste `LastSavedData`), cat profilul e inca al nostru. O folosesc chitantele Robux (PurchaseService) si
-- ridicarea barajului (DamService), prin DataService.SaveNow. Modul fara `game`: profilul si asteptarea vin din afara,
-- ca bucla sa se poata testa cu un profil fals.
--
-- DE CE CU TERMEN: in ProfileStore, o salvare care nu ajunge la DataStore (o eroare, o limita) nu mai aprinde
-- `OnAfterSave`, iar `Save()` muta profilul la coada autosave-ului (~5 min). O asteptare fara termen tinea raspunsul la
-- „Build the Dam” (si confirmarea unei chitante) pana atunci. Acum se asteapta cel mult `retry` secunde si se reincearca.
local SaveLoop = {}

-- Pasul cu care se uita bucla dupa salvare (secunde).
SaveLoop.STEP = 0.1

export type Profile = {
    LastSavedData: any,
    IsActive: (self: any) -> boolean,
    Save: (self: any) -> (),
    OnAfterSave: {
        Connect: (self: any, listener: (any) -> ()) -> { Disconnect: (self: any) -> () },
    },
}

-- true = a ajuns; false = profilul s-a inchis inainte (verificat inca o data la sfarsit: salvarea de inchidere poate sa-l
-- fi dus deja). `wait(s)` cedeaza (task.wait in joc).
function SaveLoop.run(
    profile: Profile,
    isSaved: (any) -> boolean,
    wait: (number) -> (),
    retry: number
): boolean
    if isSaved(profile.LastSavedData) then
        return true
    end
    while profile:IsActive() do
        local finished = false
        local connection = profile.OnAfterSave:Connect(function()
            finished = true
        end)
        local before = profile.LastSavedData
        profile:Save()
        local waited = 0
        while
            not finished
            and profile.LastSavedData == before
            and profile:IsActive()
            and waited < retry
        do
            wait(SaveLoop.STEP)
            waited += SaveLoop.STEP
        end
        connection:Disconnect()
        if isSaved(profile.LastSavedData) then
            return true
        end
        -- salvarea a ajuns, dar fara ce cautam (datele s-au schimbat intre timp): o pauza, apoi din nou. Daca n-a ajuns
        -- deloc, am asteptat deja `retry` secunde: din nou, pe loc.
        if (finished or profile.LastSavedData ~= before) and profile:IsActive() then
            wait(retry)
        end
    end
    return isSaved(profile.LastSavedData)
end

return SaveLoop
