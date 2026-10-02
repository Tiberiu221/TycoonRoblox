--!strict
-- GESTURILE DRUMULUI MARFII, pe orice linie [D49, D55, D56, D65]. Modul PUR: lucreaza pe traista (o lista de bucati)
-- si pe gramezi (numaratori PileMath), fara `game`, fara profil, fara ceas. EconomyService ii da gramezile din profil
-- si trimite starea; tot ce DECIDE sta aici, ca sa se poata testa.
--
-- Patru gesturi, aceleasi pe fiecare linie din FlowConfig:
--   useStore      la magazie: lasi marfa bruta a liniei; daca n-ai, iei din magazie cat incape
--   useProcessor  la atelier, un singur gest: lasi marfa bruta, apoi iei ce e gata cat incape
--   deliver       la vanzator: lasi ce e prelucrat (si gasirile erei lui); brutul ramane in traista
--   process       o "taietura": cate bucati apuca atelierul in `dt` secunde, cu restul sub 1 pastrat
-- GASIRILE merg cu marfa [D56]: locul unde lasi marfa bruta le ia si pe ele, trec neschimbate prin atelier si se vand
-- la vanzatorul erei lor. Nimic nu se pierde si nimic nu ramane blocat in traista.
local FlowConfig =
    require(script and script.Parent.Parent.Config.FlowConfig or "../Config/FlowConfig")
local TycoonConfig =
    require(script and script.Parent.Parent.Config.TycoonConfig or "../Config/TycoonConfig")
local PileMath = require(script and script.Parent.PileMath or "./PileMath")

local FlowMath = {}

export type Catch = PileMath.Catch
type Line = FlowConfig.Line

-- [D70] MODELUL: tabelele de cautare ale unei liste de ere (FlowConfig.GAME / FULL). Toate functiile primesc la coada un
-- model optional; fara el, al jocului (erele din joc), ca inainte.
export type Model = {
    flow: FlowConfig.Model,
    lineOfRaw: { [string]: string },
    lineOfProcessed: { [string]: string },
    sellerOfFind: { [string]: string },
}
-- [D70] La o unire: linia fiecarei piese (FlowConfig `joins`) -> gramada ei la atelierul unirii. In gramada, cheia e
-- bunul piesei (un butoi gata: "barrel").
export type JoinPiles = { [string]: PileMath.Counts }

-- Marfa bruta -> linia ei; marfa prelucrata -> linia din care iese. O marfa bruta pe care n-o cere nimeni e a
-- lemnului, ca inainte de D65 ("tot ce nu e scrap, gasire sau taiat"): nimic nu ramane blocat in traista.
function FlowMath.model(flow: FlowConfig.Model): Model
    local lineOfRaw: { [string]: string } = {}
    local lineOfProcessed: { [string]: string } = {}
    for _, line in flow.lineOrder do
        local spec = flow.lines[line]
        for _, good in spec.raw do
            lineOfRaw[good] = line
            local made = TycoonConfig.PROCESSED[good]
            if made ~= nil then
                lineOfProcessed[made] = line
            end
        end
    end
    -- [D70] iesirea fiecarei linii e a ei: pe Erele 1-3 sunt chiar valorile din PROCESSED (nimic nou), iar produsul unei
    -- uniri, care nu iese din marfa bruta (`raw` e gol), isi primeste aici linia
    for _, line in flow.lineOrder do
        local out = flow.lines[line].output
        local known = lineOfProcessed[out]
        assert(known == nil or known == line, `FlowMath: {out} iese din doua linii`)
        lineOfProcessed[out] = line
    end
    -- Gasirile -> vanzatorul erei lor. [D70] Orasul n-are gasiri.
    local sellerOfFind: { [string]: string } = {}
    for _, seller in flow.sellerOrder do
        local find = flow.sellers[seller].find
        if find ~= nil then
            sellerOfFind[find] = seller
        end
    end
    return {
        flow = flow,
        lineOfRaw = lineOfRaw,
        lineOfProcessed = lineOfProcessed,
        sellerOfFind = sellerOfFind,
    }
end
local GAME = FlowMath.model(FlowConfig.GAME)
FlowMath.GAME = GAME
FlowMath.FULL = FlowMath.model(FlowConfig.FULL)

function FlowMath.lineOfGood(good: string, m: Model?): string
    local mm = m or GAME
    return mm.lineOfRaw[good] or mm.lineOfProcessed[good] or mm.flow.lineOrder[1]
end

local function isFind(item: Catch): boolean
    return PileMath.isFindGood(item.g)
end

-- Unde se vinde o bucata: o gasire, la vanzatorul erei ei (prelucrata sau nu); restul, la vanzatorul liniei lor, dar
-- doar dupa ce au trecut prin atelier (`p`). nil = nu se vinde inca nicaieri (marfa bruta).
function FlowMath.sellerOf(item: Catch, m: Model?): string?
    local mm = m or GAME
    if isFind(item) then
        return mm.sellerOfFind[item.g] or mm.flow.sellerOrder[1]
    end
    if item.p ~= true then
        return nil
    end
    -- [D70] o piesa n-are vanzator (`seller` nil): se vinde doar unita
    return mm.flow.lines[FlowMath.lineOfGood(item.g, mm)].seller
end

-- [D70] Unirea in care merge o bucata gata a unei piese (un butoi -> "grid"); nil pentru orice altceva.
function FlowMath.partOf(item: Catch, m: Model?): string?
    if item.p ~= true or isFind(item) then
        return nil
    end
    local mm = m or GAME
    return mm.flow.lines[FlowMath.lineOfGood(item.g, mm)].into
end

-- Traista, vazuta de la un loc al liniei `spec`: marfa ei bruta, gasirile erei ei (neprelucrate), restul.
function FlowMath.split(items: { Catch }, spec: Line, m: Model?): ({ Catch }, { Catch }, { Catch })
    local mine, finds, rest = {}, {}, {}
    if spec.joins ~= nil then
        -- [D70] la unire: piesele ei, gata prelucrate; brutul, gasirile si restul raman in traista. Un rand al
        -- barajului cerut cu modelul jocului (Erele 1-3) pica aici, nu „nu face nimic” in tacere.
        assert(
            (m or GAME).flow.lines[spec.line] == spec,
            `FlowMath: linia {spec.line} nu e a modelului`
        )
        for _, item in items do
            table.insert(if FlowMath.partOf(item, m) == spec.line then mine else rest, item)
        end
        return mine, finds, rest
    end
    for _, item in items do
        -- ce e deja prelucrat ramane in traista, orice ar fi; o gasire bruta merge doar cu marfa erei ei
        local target = rest
        if item.p ~= true then
            if isFind(item) then
                target = if item.g == spec.find then finds else rest
            elseif FlowMath.lineOfGood(item.g, m) == spec.line then
                target = mine
            end
        end
        table.insert(target, item)
    end
    return mine, finds, rest
end

local function joined(a: { Catch }, b: { Catch }): { Catch }
    local out = table.clone(a)
    table.move(b, 1, #b, #out + 1, out)
    return out
end

-- Cand n-ai ce face aici: duci marfa bruta a unei linii care isi spune drumul la locurile asteia? (In Era 1:
-- depozitul si gaterul spun "scrap_to_forge"; shed-ul si forja nu spun nimic despre busteni.)
local function hintFor(items: { Catch }, spec: Line, m: Model?): string?
    local flow = (m or GAME).flow
    for _, line in flow.lineOrder do
        local other = flow.lines[line]
        if table.find(other.hintedBy, spec.line) ~= nil then
            for _, item in items do
                if
                    item.p ~= true
                    and not isFind(item)
                    and FlowMath.lineOfGood(item.g, m) == line
                then
                    return other.hint
                end
            end
        end
    end
    return nil
end

-- LA MAGAZIE. Muteaza `items` (traista) si `pile`. Intoarce (ok, ce s-a intamplat, cate bucati).
function FlowMath.useStore(
    items: { Catch },
    pile: PileMath.Counts,
    capacity: number,
    spec: Line,
    m: Model?
): (boolean, string, number)
    local mine, finds, rest = FlowMath.split(items, spec, m)
    if #mine > 0 then
        local dropped = joined(mine, finds)
        PileMath.addItems(pile, dropped)
        table.clear(items)
        table.move(rest, 1, #rest, 1, items)
        return true, "dropped", #dropped
    end
    local room = capacity - #items
    if room <= 0 then
        return false, hintFor(items, spec, m) or "sack_full", 0
    end
    local taken = PileMath.take(pile, room)
    if #taken == 0 then
        return false, hintFor(items, spec, m) or spec.storeEmpty :: string, 0
    end
    table.move(taken, 1, #taken, #items + 1, items)
    return true, "took", #taken
end

-- LA ATELIER, un singur gest. Intoarce (ok, motiv, cate ai lasat, cate ai luat).
function FlowMath.useProcessor(
    items: { Catch },
    input: PileMath.Counts,
    output: PileMath.Counts,
    capacity: number,
    spec: Line,
    m: Model?
): (boolean, string, number, number)
    local mine, finds, rest = FlowMath.split(items, spec, m)
    local dropped: { Catch } = {}
    if #mine > 0 then
        dropped = joined(mine, finds)
        PileMath.addItems(input, dropped)
        table.clear(items)
        table.move(rest, 1, #rest, 1, items)
    end
    local room = capacity - #items
    local taken = if room > 0 then PileMath.take(output, room, true) else {}
    table.move(taken, 1, #taken, #items + 1, items)
    if #dropped == 0 and #taken == 0 then
        local reason = if room <= 0
            then "sack_full"
            else hintFor(items, spec, m) or spec.nothingDone
        return false, reason, 0, 0
    end
    return true, "ok", #dropped, #taken
end

-- [D70] LA UNIRE, ce lasa un om sau tu: fiecare piesa a unirii in gramada ei (`inputs`, pe linia piesei); restul se
-- intoarce (dropped, rest), ca nimic sa nu se piarda. Nu atinge `items`. O gramada lipsa e o greseala a serverului:
-- pica, nu pierde bucati.
function FlowMath.dropJoin(
    inputs: JoinPiles,
    items: { Catch },
    spec: Line,
    m: Model?
): ({ Catch }, { Catch })
    local mine, _, rest = FlowMath.split(items, spec, m)
    -- intai toate gramezile, apoi bucatile: o gramada lipsa nu lasa jumatate din piese puse si jumatate in traista
    for _, item in mine do
        local part = FlowMath.lineOfGood(item.g, m)
        assert(inputs[part] ~= nil, `FlowMath: unirea {spec.line} n-are gramada piesei {part}`)
    end
    for _, item in mine do
        PileMath.add(inputs[FlowMath.lineOfGood(item.g, m)], item)
    end
    return mine, rest
end

-- [D70] LA UNIRE, un singur gest, ca `useProcessor`: lasi piesele, apoi iei ce e unit cat incape.
function FlowMath.useJoin(
    items: { Catch },
    inputs: JoinPiles,
    output: PileMath.Counts,
    capacity: number,
    spec: Line,
    m: Model?
): (boolean, string, number, number)
    local dropped, rest = FlowMath.dropJoin(inputs, items, spec, m)
    if #dropped > 0 then
        table.clear(items)
        table.move(rest, 1, #rest, 1, items)
    end
    local room = capacity - #items
    local taken = if room > 0 then PileMath.take(output, room, true) else {}
    table.move(taken, 1, #taken, #items + 1, items)
    if #dropped == 0 and #taken == 0 then
        local reason = if room <= 0
            then "sack_full"
            else hintFor(items, spec, m) or spec.nothingDone
        return false, reason, 0, 0
    end
    return true, "ok", #dropped, #taken
end

-- LA VANZATOR. Intoarce (ok, motiv, ce s-a predat). Brutul ramane in traista; ce se vinde la ALT vanzator la fel, iar
-- refuzul o spune ("other_seller"), ca jucatorul sa nu creada ca marfa lui nu se mai vinde nicaieri [D40].
function FlowMath.deliver(
    items: { Catch },
    pile: PileMath.Counts,
    seller: string,
    m: Model?
): (boolean, string, { Catch })
    local sold, rest = {}, {}
    local elsewhere = false
    local part: string? = nil
    for _, item in items do
        local where = FlowMath.sellerOf(item, m)
        if where == seller then
            table.insert(sold, item)
        else
            elsewhere = elsewhere or where ~= nil
            part = part or FlowMath.partOf(item, m)
            table.insert(rest, item)
        end
    end
    if #sold == 0 then
        -- [D70] o piesa nu se vinde nicaieri: refuzul spune unde merge (Relay-ul), inaintea lui "other_seller"
        local reason = if part ~= nil
            then (m or GAME).flow.lines[part].partRefusal :: string
            elseif elsewhere then "other_seller"
            elseif #rest > 0 then "raw_only"
            else "empty"
        return false, reason, sold
    end
    PileMath.addItems(pile, sold)
    table.clear(items)
    table.move(rest, 1, #rest, 1, items)
    return true, "delivered", sold
end

-- Cate bucati dintr-o mana de marfa numara pentru `Stats.<soldStat>` al fiecarei linii ("Sell the iron").
function FlowMath.soldStats(items: { Catch }, m: Model?): { [string]: number }
    local out: { [string]: number } = {}
    local mm = m or GAME
    for _, item in items do
        if not isFind(item) then
            local stat = mm.flow.lines[FlowMath.lineOfGood(item.g, mm)].soldStat
            if stat ~= nil then
                out[stat] = (out[stat] or 0) + 1
            end
        end
    end
    return out
end

-- O PRELUCRARE: cate bucati apuca atelierul in `dt` secunde la viteza `speed`. `carry` e restul sub 1 de la tick-ul
-- dinainte: nicio bucata nu se pierde la rotunjire. Marfa bruta a liniei iese prelucrata (TycoonConfig.PROCESSED),
-- orice altceva (gasirile venite cu ea, marfa veche) trece neschimbat. Intoarce (restul nou, cate a prelucrat).
-- Atelier gol sau oprit (`speed` <= 0): restul se pierde, ca sa nu se adune "taieturi" pentru marfa care nu se taie.
function FlowMath.process(
    input: PileMath.Counts,
    output: PileMath.Counts,
    carry: number,
    speed: number,
    dt: number,
    spec: Line
): (number, number)
    if speed <= 0 or next(input) == nil then
        return 0, 0
    end
    local carried = carry + speed * dt
    local whole = math.floor(carried)
    if whole <= 0 then
        return carried, 0
    end
    local batch = PileMath.take(input, whole)
    for _, item in batch do
        if table.find(spec.raw, item.g) ~= nil then
            item.g = TycoonConfig.PROCESSED[item.g] or item.g
        end
        PileMath.add(output, item)
    end
    return carried - whole, #batch
end

-- [D70] Piesa care lipseste la unire (linia ei, in ordinea retetei), sau nil daca sunt toate: "Waiting for cable".
function FlowMath.joinWaiting(inputs: JoinPiles, spec: Line): string?
    for _, join in spec.joins :: { FlowConfig.Join } do
        local counts = inputs[join.line]
        if counts == nil or (counts[join.good] or 0) <= 0 then
            return join.line
        end
    end
    return nil
end

-- [D70] O UNIRE: cate unitati face atelierul unirii in `dt` secunde. Fiecare ia cate o bucata din fiecare piesa
-- (reteta 1:1), deci face min(intregi, butoaie, cablu). Restul sub 1 ca la `process`: cu o piesa lipsa se pierde, iar
-- capacitatea nefolosita nu se strange (unirea nu face rafale peste viteza ei). Intoarce (restul nou, cate a unit).
function FlowMath.assemble(
    inputs: JoinPiles,
    output: PileMath.Counts,
    carry: number,
    speed: number,
    dt: number,
    spec: Line
): (number, number)
    if speed <= 0 or FlowMath.joinWaiting(inputs, spec) ~= nil then
        return 0, 0
    end
    local carried = carry + speed * dt
    local whole = math.floor(carried)
    if whole <= 0 then
        return carried, 0
    end
    local joins = spec.joins :: { FlowConfig.Join }
    local made = whole
    for _, join in joins do
        made = math.min(made, inputs[join.line][join.good])
    end
    for _, join in joins do
        local counts = inputs[join.line]
        local left = counts[join.good] - made
        counts[join.good] = if left > 0 then left else nil
    end
    PileMath.add(output, { g = spec.output }, made)
    return carried - whole, made
end

-- [D70] Ordinea in care scurge un vanzator gramada lui (al patrulea argument al PileMath.take): iesirile liniilor din
-- `priority`, ca ChainMath, doar unde ordinea cheilor n-o da singura (FlowConfig `takeOrder`: azi, orasul). nil = ordinea
-- cheilor, ca inainte.
function FlowMath.drainOrder(seller: string, m: Model?): { string }?
    local spec = (m or GAME).flow.sellers[seller]
    return if spec ~= nil then spec.takeOrder else nil
end

return FlowMath
