--!strict
-- [D70, pasul k4] CAPUL PANOULUI STATIONS (U), pur: verigile unui cartier (plasele, pasii, vanzatorul) si unde stau. In sat
-- un cartier are cel mult 11 verigi, pe o coloana, ca din D56. La baraj sunt 18 (butoaie 5, cablu 5, unirea 2 + orasul 1,
-- cristal 5): pe o coloana ar fi impins lista cladirilor la un rand si jumatate [verificatorul k2]. De la 12 verigi capul
-- trece pe DOUA coloane, rupte intre doua linii (nu la mijlocul uneia), cu numele si cifrele mai stranse.
--
-- StationPanel deseneaza din `rowsFor` / `layout` / `CELL`; testul (ChainHead.test) masoara aritmetica inaltimii pe ambele
-- lumi si latimea numelor.
local StationConfig =
    require(script and script.Parent.Parent.Config.StationConfig or "../Config/StationConfig")
local Strings = require(script and script.Parent.Parent.Config.Strings or "../Config/Strings")

local ChainHead = {}

-- O veriga din cap. `group`: a cata grupa (linia, cu vanzatorul ei) e; doua coloane se rup doar intre grupe.
export type Row = { key: string, line: string?, icon: string, label: string, group: number }
-- Unde sta fiecare veriga: coloana (1 / 2) si randul in coloana (1..). `rows` = randurile celei mai lungi coloane.
export type Layout = { columns: number, rows: number, cells: { { column: number, row: number } } }
-- Cutiile unei verigi, fata de inceputul coloanei ei (x, latime): pictograma, numele, cifra, semnul verigii slabe.
export type Cell = {
    icon: number,
    name: number,
    nameW: number,
    value: number,
    valueW: number,
    warn: number,
    warnW: number,
    warnText: string,
}

ChainHead.STEP = 20 -- inaltimea unei verigi
ChainHead.ONE_COLUMN_MAX = 11 -- cel mai lung cartier al satului (Era 1: lemnul 5, taverna 1, fierul 5)
ChainHead.SECOND_COLUMN_X = 284 -- unde incepe a doua coloana (continutul panoului are 560)
ChainHead.CELL = {
    -- o coloana: exact ca inainte de k4
    [1] = {
        icon = 0,
        name = 28,
        nameW = 120,
        value = 150,
        valueW = 120,
        warn = 282,
        warnW = 200,
        warnText = Strings.STATION_BOTTLENECK,
    },
    -- doua coloane: 268 pe coloana, 16 intre ele
    [2] = {
        icon = 0,
        name = 20,
        nameW = 100,
        value = 122,
        valueW = 72,
        warn = 198,
        warnW = 70,
        warnText = Strings.STATION_BOTTLENECK_SHORT,
    },
} :: { [number]: Cell }

-- dupa meseria pasului (StationConfig.STEP_JOBS), nu dupa pozitie [D70: la unire, al doilea pas duce]
local JOB_ICONS = { collect = "capacity", port = "carry", haul = "speed" }

-- [D56, D65] Verigile unui cartier: pe fiecare linie plasele ei, pasii, apoi vanzatorul (o singura data). [D70] O unire
-- n-are plase (intra ce aduc piesele ei), iar o piesa n-are vanzator (se vinde prin unire).
-- `eraLines`: liniile pe era (implicit ale jocului; testele dau StationConfig.ERA_LINES_ALL, cu barajul adormit).
function ChainHead.rowsFor(era: number, eraLines: { { string } }?): { Row }
    local out: { Row } = {}
    local sellersSeen: { [string]: boolean } = {}
    for group, line in (eraLines or StationConfig.ERA_LINES)[era] do
        if StationConfig.LINES[line].netKind ~= nil then
            table.insert(out, {
                key = "nets",
                line = line,
                icon = "net",
                label = Strings.NET_WORDS[line].label,
                group = group,
            })
        end
        for k, step in StationConfig.LINES[line].steps do
            table.insert(out, {
                key = step.link,
                line = line,
                icon = if step.kind ~= "processor"
                    then JOB_ICONS[StationConfig.STEP_JOBS[line][k]] or "carry"
                    elseif step.link == "saw" then "saw"
                    else "hammer",
                label = Strings.LINK_WORDS[step.link].label,
                group = group,
            })
        end
        local seller = StationConfig.LINES[line].seller
        if seller ~= nil and not sellersSeen[seller] then
            sellersSeen[seller] = true
            table.insert(out, {
                key = seller,
                icon = "crate",
                label = Strings.LINK_WORDS[seller].label,
                group = group,
            })
        end
    end
    return out
end

-- Asezarea: o coloana pana la ONE_COLUMN_MAX verigi; altfel doua, rupte la granita dintre grupe care face coloanele cat
-- mai egale (cea mai lunga cat mai scurta).
function ChainHead.layout(rows: { Row }): Layout
    local n = #rows
    local cells: { { column: number, row: number } } = {}
    if n <= ChainHead.ONE_COLUMN_MAX then
        for i = 1, n do
            cells[i] = { column = 1, row = i }
        end
        return { columns = 1, rows = n, cells = cells }
    end
    local split, best = n, n
    for i = 1, n - 1 do
        if rows[i].group ~= rows[i + 1].group then
            local longest = math.max(i, n - i)
            if longest < best then
                split, best = i, longest
            end
        end
    end
    for i = 1, n do
        cells[i] = if i <= split then { column = 1, row = i } else { column = 2, row = i - split }
    end
    return { columns = 2, rows = best, cells = cells }
end

-- Cat coboara tot ce sta sub cap, fata de capul de 7 verigi de dinainte de D55 (StationPanel: HEAD_SHIFT).
function ChainHead.shift(rows: number): number
    return (rows - 7) * ChainHead.STEP
end

return ChainHead
