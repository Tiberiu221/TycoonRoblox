--!strict
-- Alegerea evenimentului: modul pur, ca sa poata fi testat fara Studio [MASTERPLAN 3.5].
-- Primeste lista de evenimente, ce conditii sunt indeplinite acum si ce s-a intamplat recent;
-- intoarce evenimentul ales. Nu atinge `game` si nu are stare proprie.
local EventConfig =
    require(script and script.Parent.Parent.Config.EventConfig or "../Config/EventConfig")

export type Conditions = { [string]: boolean }

local Storyteller = {}

-- Un eveniment e eligibil daca isi are conditia indeplinita si nu a mai iesit de curand.
function Storyteller.eligible(
    e: EventConfig.Event,
    conditions: Conditions,
    recent: { string }
): boolean
    if e.requires ~= nil and not conditions[e.requires] then
        return false
    end
    for _, id in recent do
        if id == e.id then
            return false
        end
    end
    return true
end

-- Alegere ponderata. `roll` e un numar in [0,1) (vine din Prng, ca sa fie determinist la nevoie).
-- Intoarce nil cand nimic nu e eligibil, ca apelantul sa poata amana in loc sa forteze ceva.
function Storyteller.pick(
    events: { EventConfig.Event },
    conditions: Conditions,
    recent: { string },
    roll: number
): EventConfig.Event?
    local total = 0
    local pool: { EventConfig.Event } = {}
    for _, e in events do
        if Storyteller.eligible(e, conditions, recent) then
            total += e.weight
            table.insert(pool, e)
        end
    end
    if total <= 0 then
        return nil
    end
    local target = math.clamp(roll, 0, 0.999999) * total
    local acc = 0
    for _, e in pool do
        acc += e.weight
        if target < acc then
            return e
        end
    end
    return pool[#pool]
end

-- Jurnalul pastreaza doar ultimele `size` intrari, cea mai noua prima.
function Storyteller.pushLog(log: { any }, entry: any, size: number): { any }
    table.insert(log, 1, entry)
    while #log > size do
        table.remove(log)
    end
    return log
end

-- Ultimele `gap` id-uri din jurnal: cu ele se evita repetarea aceluiasi eveniment.
function Storyteller.recentIds(log: { any }, gap: number): { string }
    local out: { string } = {}
    for i = 1, math.min(gap, #log) do
        table.insert(out, log[i].id)
    end
    return out
end

return Storyteller
