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
local StationConfig =
    require(script and script.Parent.Parent.Config.StationConfig or "../Config/StationConfig")
local TycoonConfig =
    require(script and script.Parent.Parent.Config.TycoonConfig or "../Config/TycoonConfig")
local PileMath = require(script and script.Parent.PileMath or "./PileMath")

local FlowMath = {}

export type Catch = PileMath.Catch
type Line = FlowConfig.Line

-- Marfa bruta -> linia ei; marfa prelucrata -> linia din care iese. O marfa bruta pe care n-o cere nimeni e a
-- lemnului, ca inainte de D65 ("tot ce nu e scrap, gasire sau taiat"): nimic nu ramane blocat in traista.
local lineOfRaw: { [string]: string } = {}
local lineOfProcessed: { [string]: string } = {}
for _, line in StationConfig.LINE_ORDER do
    for _, good in FlowConfig.LINES[line].raw do
        lineOfRaw[good] = line
        local made = TycoonConfig.PROCESSED[good]
        if made ~= nil then
            lineOfProcessed[made] = line
        end
    end
end
-- Gasirile -> vanzatorul erei lor
local sellerOfFind: { [string]: string } = {}
for _, seller in StationConfig.SELLER_ORDER do
    sellerOfFind[FlowConfig.SELLERS[seller].find] = seller
end

function FlowMath.lineOfGood(good: string): string
    return lineOfRaw[good] or lineOfProcessed[good] or StationConfig.LINE_ORDER[1]
end

local function isFind(item: Catch): boolean
    return PileMath.isFindGood(item.g)
end

-- Unde se vinde o bucata: o gasire, la vanzatorul erei ei (prelucrata sau nu); restul, la vanzatorul liniei lor, dar
-- doar dupa ce au trecut prin atelier (`p`). nil = nu se vinde inca nicaieri (marfa bruta).
function FlowMath.sellerOf(item: Catch): string?
    if isFind(item) then
        return sellerOfFind[item.g] or StationConfig.SELLER_ORDER[1]
    end
    if item.p ~= true then
        return nil
    end
    return FlowConfig.LINES[FlowMath.lineOfGood(item.g)].seller
end

-- Traista, vazuta de la un loc al liniei `spec`: marfa ei bruta, gasirile erei ei (neprelucrate), restul.
function FlowMath.split(items: { Catch }, spec: Line): ({ Catch }, { Catch }, { Catch })
    local mine, finds, rest = {}, {}, {}
    for _, item in items do
        -- ce e deja prelucrat ramane in traista, orice ar fi; o gasire bruta merge doar cu marfa erei ei
        local target = rest
        if item.p ~= true then
            if isFind(item) then
                target = if item.g == spec.find then finds else rest
            elseif FlowMath.lineOfGood(item.g) == spec.line then
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
local function hintFor(items: { Catch }, spec: Line): string?
    for _, line in StationConfig.LINE_ORDER do
        local other = FlowConfig.LINES[line]
        if table.find(other.hintedBy, spec.line) ~= nil then
            for _, item in items do
                if item.p ~= true and not isFind(item) and FlowMath.lineOfGood(item.g) == line then
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
    spec: Line
): (boolean, string, number)
    local mine, finds, rest = FlowMath.split(items, spec)
    if #mine > 0 then
        local dropped = joined(mine, finds)
        PileMath.addItems(pile, dropped)
        table.clear(items)
        table.move(rest, 1, #rest, 1, items)
        return true, "dropped", #dropped
    end
    local room = capacity - #items
    if room <= 0 then
        return false, hintFor(items, spec) or "sack_full", 0
    end
    local taken = PileMath.take(pile, room)
    if #taken == 0 then
        return false, hintFor(items, spec) or spec.storeEmpty, 0
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
    spec: Line
): (boolean, string, number, number)
    local mine, finds, rest = FlowMath.split(items, spec)
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
        local reason = if room <= 0 then "sack_full" else hintFor(items, spec) or spec.nothingDone
        return false, reason, 0, 0
    end
    return true, "ok", #dropped, #taken
end

-- LA VANZATOR. Intoarce (ok, motiv, ce s-a predat). Brutul ramane in traista; ce se vinde la ALT vanzator la fel, iar
-- refuzul o spune ("other_seller"), ca jucatorul sa nu creada ca marfa lui nu se mai vinde nicaieri [D40].
function FlowMath.deliver(
    items: { Catch },
    pile: PileMath.Counts,
    seller: string
): (boolean, string, { Catch })
    local sold, rest = {}, {}
    local elsewhere = false
    for _, item in items do
        local where = FlowMath.sellerOf(item)
        if where == seller then
            table.insert(sold, item)
        else
            elsewhere = elsewhere or where ~= nil
            table.insert(rest, item)
        end
    end
    if #sold == 0 then
        local reason = if elsewhere then "other_seller" elseif #rest > 0 then "raw_only" else "empty"
        return false, reason, sold
    end
    PileMath.addItems(pile, sold)
    table.clear(items)
    table.move(rest, 1, #rest, 1, items)
    return true, "delivered", sold
end

-- Cate bucati dintr-o mana de marfa numara pentru `Stats.<soldStat>` al fiecarei linii ("Sell the iron").
function FlowMath.soldStats(items: { Catch }): { [string]: number }
    local out: { [string]: number } = {}
    for _, item in items do
        if not isFind(item) then
            local stat = FlowConfig.LINES[FlowMath.lineOfGood(item.g)].soldStat
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

return FlowMath
