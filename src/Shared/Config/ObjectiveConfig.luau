--!strict
-- Lantul de obiective care invata jocul FARA tutorial [RIVERKEEP 2].
--
-- Regulile vin din retentia masurata pe Roblox, unde cea mai mare pierdere e chiar la prima
-- actiune ceruta, iar cauzele sunt mereu aceleasi doua: nu e clar CE trebuie facut si nu e clar
-- CUM. De aceea:
--   * UN SINGUR obiectiv pe ecran la inceput. Nu o lista.
--   * Titlul incepe cu un VERB, la prezent: "Place a net", nu "You should consider placing".
--   * Fiecare obiectiv are un singur semn in lume (`marker`). Niciodata doua semne deodata.
--   * Fiecare pas invata UN verb nou si are un efect vizibil in cateva secunde.
--   * Sistemele se deschid pe rand (`unlocks`): panourile mari nu exista pana nu sunt necesare.
-- Textele sunt in engleza (jocul e in engleza), comentariile in romana.
export type Objective = {
    id: string,
    title: string, -- verb-first, ce sa faca acum
    hint: string, -- cum, intr-o propozitie
    marker: string, -- ce se lumineaza in lume sau in interfata
    condition: string, -- ce numara serverul ca sa considere pasul terminat
    target: number,
    unlocks: string?, -- ce parte de interfata devine disponibila dupa acest pas
    reward: string?, -- ce primeste jucatorul, daca primeste ceva
}

local function objective(t: Objective): Objective
    return t
end

local ObjectiveConfig = {}

ObjectiveConfig.STEPS = {
    objective({
        id = "place_net",
        title = "Place a net in the river",
        -- Spune si DE UNDE vine plasa. Vechiul indiciu zicea doar "foloseste inelul", iar
        -- plasa aparea din neant: prima intrebare a oricui a fost "de unde am eu plase?".
        hint = "Three spots on the river are yours. Move with {move} to a glowing ring, then {use}.",
        marker = "net_slot",
        condition = "netsPlaced",
        target = 1,
    }),
    objective({
        id = "collect_net",
        title = "Collect what the river brought",
        hint = "It fills on its own while you do other things. Walk back to it and {use}.",
        marker = "net",
        condition = "collects",
        target = 1,
    }),
    objective({
        id = "scrap_item",
        title = "Break driftwood down into materials",
        hint = "{Tap} the glowing button on the right, then press Scrap on anything in the pile.",
        marker = "workshop",
        condition = "scraps",
        target = 1,
        unlocks = "workshop",
    }),
    objective({
        id = "build_tent",
        title = "Build a second bed",
        hint = "{Tap} the glowing Build button, pick Tent, then {tap} the glowing ground.",
        marker = "build",
        -- PATURI, nu "orice cladire". Cu conditia veche, cine construia o vatra ramanea cu un
        -- singur pat: nimeni nu mai venea pe apa si pasul urmator nu se putea termina niciodata.
        condition = "beds",
        target = 2,
        unlocks = "build",
    }),
    objective({
        id = "assign_job",
        title = "Put someone to work",
        hint = "{Tap} the glowing People button, then {tap} a trade letter next to someone.",
        marker = "people",
        condition = "jobsAssigned",
        target = 1,
        unlocks = "people",
    }),
    objective({
        id = "welcome_settler",
        title = "Welcome a newcomer",
        hint = "An empty bed brings someone downriver. Watch the water — it takes a moment.",
        marker = "river",
        condition = "settlersArrived",
        target = 1,
        unlocks = "colony",
    }),
}

-- REGULA: indiciul nu presupune NIMIC. Spune si ce, si CUM, si numeste comanda pe care o are
-- chiar jucatorul asta -- pe telefon nu exista tasta E, iar pe desktop nu exista "tap".
-- Simbolurile se inlocuiesc pe client, unde se stie ce fel de intrare are.
-- {Tap} la inceput de propozitie, {tap} in interiorul ei. Un singur simbol dadea "then Click
-- the glowing ground" -- majuscula la mijloc de fraza, adica exact genul de detaliu care face
-- textul sa arate generat, nu scris.
ObjectiveConfig.TOKENS = { "{move}", "{use}", "{Tap}", "{tap}" }

function ObjectiveConfig.fill(text: string, touch: boolean): string
    local out = string.gsub(text, "{move}", if touch then "the stick" else "WASD")
    out = string.gsub(out, "{use}", if touch then "press the round button" else "press E")
    out = string.gsub(out, "{Tap}", if touch then "Tap" else "Click")
    out = string.gsub(out, "{tap}", if touch then "tap" else "click")
    return out
end

-- Dupa lant urmeaza telurile lungi. Fiecare are TREPTE, nu o singura tinta: cand atingi una,
-- apare urmatoarea. Altfel cartonasul se goleste dupa tutorial si jucatorul ramane fara directie,
-- exact in momentul in care jocul ar trebui sa devina al lui.
export type Goal = {
    id: string,
    title: string, -- {n} se inlocuieste cu treapta curenta
    hint: string,
    marker: string,
    condition: string,
    steps: { number },
}

local function goal(t: Goal): Goal
    return t
end

ObjectiveConfig.GOALS = {
    goal({
        id = "beds",
        title = "Make room for {n}",
        hint = "An empty bed brings someone downriver.",
        marker = "build",
        condition = "beds",
        steps = { 6, 12, 20, 32, 50 },
    }),
    goal({
        id = "gardens",
        title = "Plant {n} gardens",
        hint = "Fishing feeds a small colony. Gardens feed a growing one.",
        marker = "build",
        condition = "gardens",
        steps = { 1, 2, 4 },
    }),
    goal({
        id = "population",
        title = "Grow to {n} settlers",
        hint = "Keep them fed, rested and content or they drift away.",
        marker = "people",
        condition = "population",
        steps = { 10, 20, 35, 50, 80 },
    }),
    goal({
        id = "repairs",
        title = "Repair {n} things the river brought",
        hint = "The workshop turns broken things back into whole ones.",
        marker = "workshop",
        condition = "repairs",
        steps = { 1, 5, 15, 40 },
    }),
}

-- Treapta curenta a unui tel: prima nedepasita. Daca toate sunt atinse, intoarce nil si telul
-- iese din lista.
function ObjectiveConfig.nextStep(g: Goal, have: number): number?
    for _, target in g.steps do
        if have < target then
            return target
        end
    end
    return nil
end

-- Ce semne stie clientul sa aseze in lume si ce panouri exista. Sunt aici ca sa poata fi
-- verificate automat: un obiectiv care cere un semn inexistent lasa jucatorul fara indicatie,
-- iar unul care deblocheaza un panou inexistent il lasa blocat.
ObjectiveConfig.MARKERS = { "net_slot", "net", "workshop", "build", "site", "people", "river" }
ObjectiveConfig.PANELS = { "net", "workshop", "build", "people", "colony", "index" }

function ObjectiveConfig.stepAt(index: number): Objective?
    return ObjectiveConfig.STEPS[index]
end

function ObjectiveConfig.count(): number
    return #ObjectiveConfig.STEPS
end

-- Ce e deschis dupa `index` pasi terminati. Panourile mari nu apar de la inceput: un ecran plin
-- de butoane la prima intrare e exact tiparul care pierde jucatorii.
function ObjectiveConfig.unlockedAfter(index: number): { [string]: boolean }
    local open: { [string]: boolean } = { net = true }
    for i = 1, math.min(index, #ObjectiveConfig.STEPS) do
        local step = ObjectiveConfig.STEPS[i]
        if step.unlocks ~= nil then
            open[step.unlocks] = true
        end
    end
    if index >= #ObjectiveConfig.STEPS then
        open.workshop = true
        open.build = true
        open.people = true
        open.colony = true
    end
    -- Colectia se umple DOAR reparand, deci apare exact cand apare atelierul. Deschisa mai
    -- devreme ar fi un panou gol pe care nu ai cum sa-l umpli; mai tarziu, ai repara fara sa
    -- vezi pentru ce.
    open.index = open.workshop
    return open
end

return ObjectiveConfig
