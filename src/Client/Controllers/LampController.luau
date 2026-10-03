--!strict
-- [D67] FELINARELE DE PE STRADA. Roadmap-ul owner-ului (D64): cu curentul electric, "satul se lumineaza". Stau intre
-- case, pe marginea de sud a strazii fiecarui cartier in joc (TycoonConfig.streetLamps): stinse pana la primul curent
-- vandut, apoi aprinse, cu lumina lor calda dedesubt. Prima aprindere se anunta, ca nimic sa nu se intample in tacere
-- [D43]; cine intra in joc cu ele deja aprinse nu mai primeste anuntul. Desenul lor e in UI/StreetLamps (comun cu
-- satul vizitat din balci).
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ModernMath = require(ReplicatedStorage.Shared.Modules.ModernMath)
local Modern = require(script.Parent.Parent.UI.Modern)
local StreetLamps = require(script.Parent.Parent.UI.StreetLamps)

local LampController = {}

local lamps: StreetLamps.Lamps? = nil
local lit: boolean? = nil -- nil = inca nicio stare de la server
local onFirstLight: (() -> ())? = nil
local world = 1 -- [D70, pasul k2]

-- [D73] Felinarele apar odata cu stalpii si sarma (treapta "wire" a modernizarii, Clerk-ul Erei 3), nu din primul minut:
-- pana atunci stateau stinse pe strazile tuturor cartierelor, doua ere la rand, fara sa faca nimic.
local WIRE_STAGE = ModernMath.stageOf("wire") or 1

function LampController.Init(deps: { Plot: GuiObject, OnFirstLight: (() -> ())?, World: number? })
    onFirstLight = deps.OnFirstLight
    world = deps.World or 1
    lamps = StreetLamps.draw(deps.Plot, false, world)
    LampController.RefreshModern()
end

-- Dupa fiecare treapta noua a modernizarii (ModernController.Refresh): felinarele se vad de la treapta "wire".
function LampController.RefreshModern()
    local l = lamps
    if l ~= nil then
        -- [D70] la baraj felinarele stau de la inceput (curentul e al lui); in sat, de la treapta „wire”
        l.show(world ~= 1 or Modern.stage >= WIRE_STAGE)
    end
end

-- `on` = s-a vandut deja curent (TycoonState.firsts.power).
function LampController.Apply(on: boolean)
    if lit == on then
        return
    end
    local justNow = lit == false and on -- aprinse chiar acum, nu gasite aprinse la intrare
    lit = on
    local l = lamps
    if l == nil then
        return
    end
    l.set(on)
    if justNow and l.count > 0 and onFirstLight ~= nil then
        onFirstLight()
    end
end

return LampController
