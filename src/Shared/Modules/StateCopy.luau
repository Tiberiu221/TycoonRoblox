--!strict
-- [D70, pasul k3] COPIA STARII PE LINII, pura: ce primeste clientul in TycoonState despre traista (pe linii, pe vanzatori,
-- pe unire), despre gramezile fiecarei linii (magazia, atelierul, iesirea), despre fiecare vanzator si despre veriga
-- slaba a fiecarei linii. Campurile se copiaza explicit, camp cu camp [CLAUDE.md capcana 3: de doua ori s-au pierdut
-- campuri trimise de server]. Bootstrap.client o cheama pe ordinea jocului; testul ei o ruleaza pe ordinea FULL (cu
-- barajul) si cere ca fiecare camp al instantaneelor serverului (EconomyService) sa ajunga dincoace.
--
-- Liniile Erelor 1-3 ies exact ca inainte de k3 (aceleasi chei, aceleasi valori implicite): campurile unirii (`inputs`,
-- `waiting`, `partBy`) apar doar pe o unire.
local StateCopy = {}

export type StoreState = { count: number, contents: { [string]: number } }
export type ProcessorState = {
    count: number,
    contents: { [string]: number },
    out: number,
    outContents: { [string]: number },
    rate: number,
    present: boolean?,
    staffed: boolean?,
    -- [D70] doar la unire: cate piese asteapta din fiecare (linia piesei -> cate) si piesa care lipseste acum (nil = le
    -- are pe toate, sau atelierul e al altei harti)
    inputs: { [string]: number }?,
    waiting: string?,
}
export type SellerState = {
    count: number,
    value: number,
    rate: number,
    contents: { [string]: number },
}
export type FlowLine = { store: StoreState, processor: ProcessorState }
export type SackBy = {
    rawBy: { [string]: number },
    sellBy: { [string]: { count: number, value: number } },
    partBy: { [string]: number }, -- [D70] piesele gata din traista, pe unirea lor (butoaie + cablu -> "grid")
}
-- Vederea pe o linie (StationService.lineViews). Valorile implicite sunt cele cinstite: `supply` = ce prind plasele ei,
-- `heldBy` = linia insasi, `isOpen` = deschisa, `waiting` = nimic.
export type LineView = {
    catch: number,
    delivered: number,
    bottleneck: string,
    playerShare: number,
    supply: number,
    heldBy: string,
    isOpen: boolean,
    waiting: string?,
}

local function num(v: any, default: number): number
    return if typeof(v) == "number" then v else default
end

-- Traista pe linii: marfa bruta a fiecarei linii, ce cumpara fiecare vanzator si (doar la unire) piesele ei. `unions` =
-- liniile care sunt uniri (FlowConfig: `joins`), in ordinea data.
function StateCopy.sackBy(
    sack: any,
    lineOrder: { string },
    sellerOrder: { string },
    unions: { [string]: boolean }
): SackBy
    local out: SackBy = { rawBy = {}, sellBy = {}, partBy = {} }
    local rawBy: any = if typeof(sack) == "table" then sack.rawBy else nil
    local sellBy: any = if typeof(sack) == "table" then sack.sellBy else nil
    local partBy: any = if typeof(sack) == "table" then sack.partBy else nil
    for _, line in lineOrder do
        out.rawBy[line] = if typeof(rawBy) == "table" then rawBy[line] or 0 else 0
        if unions[line] then
            out.partBy[line] = if typeof(partBy) == "table" then num(partBy[line], 0) else 0
        end
    end
    for _, seller in sellerOrder do
        local entry: any = if typeof(sellBy) == "table" then sellBy[seller] else nil
        out.sellBy[seller] = {
            count = if typeof(entry) == "table" then entry.count or 0 else 0,
            value = if typeof(entry) == "table" then entry.value or 0 else 0,
        }
    end
    return out
end

-- Gramezile unei linii (TycoonState.flow.lines[line]). `parts` = piesele unirii, in ordinea retetei; nil pe o linie simpla.
function StateCopy.flowLine(entry: any, parts: { string }?): FlowLine
    local e: any = if typeof(entry) == "table" then entry else {}
    local s: any, pr: any = e.store or {}, e.processor or {}
    local processor: ProcessorState = {
        count = pr.count or 0,
        contents = table.clone(pr.contents or {}),
        out = pr.out or 0,
        outContents = table.clone(pr.outContents or {}),
        rate = pr.rate or 0,
        present = pr.present == true,
        staffed = pr.staffed == true,
    }
    if parts ~= nil then
        local inputs: { [string]: number } = {}
        for _, part in parts do
            inputs[part] = if typeof(pr.inputs) == "table" then num(pr.inputs[part], 0) else 0
        end
        processor.inputs = inputs
        processor.waiting = if typeof(pr.waiting) == "string" then pr.waiting else nil
    end
    return {
        store = { count = s.count or 0, contents = table.clone(s.contents or {}) },
        processor = processor,
    }
end

-- Gramada unui vanzator (TycoonState.flow.sellers[seller]).
function StateCopy.flowSeller(entry: any): SellerState
    local e: any = if typeof(entry) == "table" then entry else {}
    return {
        count = e.count or 0,
        value = e.value or 0,
        rate = e.rate or 0,
        contents = table.clone(e.contents or {}),
    }
end

-- Vederea pe linia `line` (TycoonState.stations.lines[line]).
function StateCopy.lineView(entry: any, line: string): LineView
    local e: any = if typeof(entry) == "table" then entry else {}
    local catch = e.catch or 0
    return {
        catch = catch,
        delivered = e.delivered or 0,
        bottleneck = e.bottleneck or "",
        playerShare = e.playerShare or 0,
        supply = num(e.supply, catch),
        heldBy = if typeof(e.heldBy) == "string" then e.heldBy else line,
        isOpen = if typeof(e.isOpen) == "boolean" then e.isOpen else true,
        waiting = if typeof(e.waiting) == "string" then e.waiting else nil,
    }
end

-- [verificatorul k3] Cat e de lucrat in inelul unui atelier: tot ce asteapta la intrare; la o unire, cate uniri se pot face
-- acum (cea mai mica gramada de piese, 0 cat una lipseste). O singura regula pentru inelul Relay-ului (LineController) si
-- pentru ghidaj (Overlay).
function StateCopy.joinable(processor: {
    count: number,
    inputs: { [string]: number }?,
    waiting: string?,
}): number
    local inputs = processor.inputs
    if inputs == nil then
        return processor.count
    end
    if processor.waiting ~= nil then
        return 0
    end
    local n = math.huge
    for _, count in inputs do
        n = math.min(n, count)
    end
    return if n == math.huge then 0 else n
end

-- [verificatorul k3] Ce piese ale unei uniri duci (linia piesei -> cate), din ce e in traista (`contents`, pe marfa).
function StateCopy.partsCarried(
    contents: { [string]: number },
    joins: { { line: string, good: string } }
): { [string]: number }
    local out: { [string]: number } = {}
    for _, join in joins do
        local n = contents[join.good] or 0
        if n > 0 then
            out[join.line] = n
        end
    end
    return out
end

-- Piesele fiecarei uniri dintr-un model de linii (FlowConfig.GAME / FULL), in ordinea retetei: unirea -> piesele ei.
function StateCopy.partsOf(
    lines: { [string]: { joins: { { line: string } }? } }
): { [string]: { string } }
    local out: { [string]: { string } } = {}
    for line, spec in lines do
        local joins = spec.joins
        if joins ~= nil then
            local parts: { string } = {}
            for _, join in joins do
                table.insert(parts, join.line)
            end
            out[line] = parts
        end
    end
    return out
end

-- [verificatorul k9-k10a] CE SPUNE CARDUL UNUI VANZATOR cand n-ai nimic de vandut acolo, in ordinea refuzurilor serverului
-- (FlowMath.deliver): o piesa a unei uniri ("part", unirea ei), marfa altui vanzator ("other", vanzatorul ei), apoi marfa
-- bruta a ORICAREI linii ("raw", linia ei; si a liniilor fara vanzator, ca butoaiele si cablul barajului). Ordinea e cea
-- din tabele, nu a unui `pairs`. (nil, nil): ai ce vinde aici, sau traista n-are nimic de spus.
-- [verificatorul k12] La brut, intai liniile vanzatorului de aici (`sellerOf`: atelierul de alaturi), apoi linia cu cele mai
-- multe bucati: „scrap” si „ore” sunt cuvintele a cate doua linii, iar cu amandoua in traista cardul Pietei trimitea la
-- Forja pentru 3 bucati si tacea despre cele 9 ale Foundry-ului. `partBy` poate lipsi (traista goala, inainte de stare).
export type SellerSack = {
    rawBy: { [string]: number },
    sellBy: { [string]: { count: number, value: number } },
    partBy: { [string]: number }?,
}
function StateCopy.sellerNote(
    sack: SellerSack,
    seller: string,
    lineOrder: { string },
    sellerOrder: { string },
    sellerOf: ((string) -> string?)?,
    wordOf: ((string) -> string?)?
): (string?, string?, string?)
    local here = sack.sellBy[seller]
    if here ~= nil and here.count > 0 then
        return nil, nil
    end
    local parts = sack.partBy or {}
    for _, line in lineOrder do
        if (parts[line] or 0) > 0 then
            return "part", line
        end
    end
    for _, other in sellerOrder do
        local entry = sack.sellBy[other]
        if other ~= seller and entry ~= nil and entry.count > 0 then
            return "other", other
        end
    end
    -- [verificatorul A0/k12] linia cu cele mai multe bucati; atelierul de alaturi decide doar la egalitate (altfel 9 bucati
    -- de minereu de cupru erau trimise la Wire Works pentru una singura)
    local best: string?, most = nil, 0
    local function own(line: string): boolean
        return sellerOf ~= nil and sellerOf(line) == seller
    end
    for _, line in lineOrder do
        local n = if parts[line] == nil then sack.rawBy[line] or 0 else 0
        if n > most or (n > 0 and n == most and best ~= nil and own(line) and not own(best)) then
            best, most = line, n
        end
    end
    if best == nil then
        return nil, nil, nil
    end
    -- a doua linie din traista cu ACELASI cuvant pentru marfa bruta („scrap”, „ore”): cardul le numeste pe amandoua
    if wordOf ~= nil then
        local word = wordOf(best)
        for _, line in lineOrder do
            if
                line ~= best
                and parts[line] == nil
                and (sack.rawBy[line] or 0) > 0
                and wordOf(line) == word
            then
                return "raw", best, line
            end
        end
    end
    return "raw", best, nil
end

return StateCopy
