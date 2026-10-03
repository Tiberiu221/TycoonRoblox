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

return StateCopy
