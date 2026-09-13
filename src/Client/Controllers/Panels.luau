--!strict
-- Registru de panouri mari: doar unul poate sta deschis. Fara asta, meniul de constructii si
-- tabloul coloniei se suprapun pe aceeasi jumatate de ecran si nu se mai citeste niciunul.
-- Fiecare panou se inregistreaza cu doua functii; nimeni nu cere pe nimeni, deci nu apar
-- require-uri incrucisate intre controllere.
export type Entry = { isOpen: () -> boolean, close: () -> () }

local Panels = {}
local registry: { [string]: Entry } = {}

function Panels.Register(name: string, entry: Entry)
    registry[name] = entry
end

-- Inchide toate celelalte panouri inregistrate. Se apeleaza cand unul tocmai s-a deschis.
function Panels.CloseOthers(name: string)
    for other, entry in registry do
        if other ~= name and entry.isOpen() then
            entry.close()
        end
    end
end

-- Poarta de deblocare: la inceput jocul are un singur lucru de facut, iar panourile mari apar
-- pe rand, pe masura ce obiectivele le deschid. Un ecran plin de butoane la prima intrare e
-- exact tiparul care pierde jucatorii in primul minut.
local gate: ((string) -> boolean)? = nil
local onBlocked: ((string) -> ())? = nil

function Panels.SetGate(fn: (string) -> boolean, blocked: ((string) -> ())?)
    gate = fn
    onBlocked = blocked
end

-- Se poate deschide panoul acum? Daca nu, spune de ce, o singura data.
function Panels.CanOpen(name: string): boolean
    if gate == nil then
        return true
    end
    if (gate :: (string) -> boolean)(name) then
        return true
    end
    if onBlocked ~= nil then
        (onBlocked :: (string) -> ())(name)
    end
    return false
end

-- Inchide tot. Escape trebuie sa inchida ORICE panou, inclusiv pe cele adaugate mai tarziu --
-- inainte, tasta era legata direct de doua controllere anume, iar panourile noi (quest-uri,
-- statii) ramaneau deschise pentru ca nimeni nu le stia numele.
function Panels.CloseAll()
    for _, entry in registry do
        if entry.isOpen() then
            entry.close()
        end
    end
end

function Panels.AnyOpen(): boolean
    for _, entry in registry do
        if entry.isOpen() then
            return true
        end
    end
    return false
end

return Panels
