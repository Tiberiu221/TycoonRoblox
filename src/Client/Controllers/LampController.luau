--!strict
-- [D67] FELINARELE DE PE STRADA. Roadmap-ul owner-ului (D64): cu curentul electric, "satul se lumineaza". Stau intre
-- case, pe marginea de sud a strazii fiecarui cartier in joc (TycoonConfig.streetLamps): stinse pana la primul curent
-- vandut, apoi aprinse, cu lumina lor calda dedesubt. Prima aprindere se anunta, ca nimic sa nu se intample in tacere
-- [D43]; cine intra in joc cu ele deja aprinse nu mai primeste anuntul. Desenul lor e in UI/StreetLamps (comun cu
-- satul vizitat din balci).
local StreetLamps = require(script.Parent.Parent.UI.StreetLamps)

local LampController = {}

local lamps: StreetLamps.Lamps? = nil
local lit: boolean? = nil -- nil = inca nicio stare de la server
local onFirstLight: (() -> ())? = nil

function LampController.Init(deps: { Plot: GuiObject, OnFirstLight: (() -> ())? })
    onFirstLight = deps.OnFirstLight
    lamps = StreetLamps.draw(deps.Plot, false)
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
