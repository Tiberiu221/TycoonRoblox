--!strict
-- [D60] RANDURILE DE PE TABELA din bâlci. Modul pur: primeste ce a citit serverul din OrderedDataStore si scoate
-- randurile gata scrise, ca desenul sa nu mai socoteasca nimic.
--
-- Trei feluri de clasament, fiecare cu unitatea lui; cifra bruta din store e intreaga (OrderedDataStore tine doar
-- intregi), deci aici se face si intoarcerea in unitati de om: centimetri, monede pe secunda, secunde.
local BoardMath = {}

export type Entry = { userId: number, name: string, value: number, extra: string? }
export type Row = { rank: number, name: string, value: string, mine: boolean }

BoardMath.ROWS = 6 -- cate randuri incap pe un panou al scenei
BoardMath.KINDS = { "fish", "income", "era1" }

local function duration(seconds: number): string
    local m = math.floor(seconds / 60)
    local s = seconds % 60
    return if m > 0 then `{m}m {s}s` else `{s}s`
end

-- Cum se scrie cifra unui clasament. `extra` vine din DataStore-ul de langa (specia pestelui), pentru ca in
-- OrderedDataStore incape doar un numar.
function BoardMath.format(kind: string, value: number, extra: string?): string
    if kind == "fish" then
        local cm = math.floor(value) / 10 -- cifrele se tin in milimetri, ca ordinea sa fie exacta
        local name = extra or "Fish"
        return string.format("%s %.1f cm", name, cm)
    elseif kind == "income" then
        return string.format("%.2f/s", value / 100) -- sutimi de moneda pe secunda
    elseif kind == "era1" then
        return duration(math.floor(value))
    end
    return tostring(value)
end

-- Cine e mai bun: la pescuit si la venit, cifra mare; la Era 1, timpul mic. La egalitate ramane cine a ajuns primul
-- (ordinea in care le-a intors store-ul), ca sa nu sara randurile de la o citire la alta.
function BoardMath.better(kind: string, a: number, b: number): boolean
    if kind == "era1" then
        return a < b
    end
    return a > b
end

function BoardMath.rows(kind: string, entries: { Entry }, meUserId: number?): { Row }
    local sorted = table.clone(entries)
    table.sort(sorted, function(a, b)
        if a.value == b.value then
            return a.userId < b.userId
        end
        return BoardMath.better(kind, a.value, b.value)
    end)
    local out: { Row } = {}
    for i, entry in sorted do
        if i > BoardMath.ROWS then
            break
        end
        table.insert(out, {
            rank = i,
            name = entry.name,
            value = BoardMath.format(kind, entry.value, entry.extra),
            mine = meUserId ~= nil and entry.userId == meUserId,
        })
    end
    return out
end

-- Cand nu esti in primele randuri, tabela spune unde esti, nu te sterge de pe ea [D43].
function BoardMath.myLine(kind: string, entries: { Entry }, meUserId: number): Row?
    local sorted = table.clone(entries)
    table.sort(sorted, function(a, b)
        if a.value == b.value then
            return a.userId < b.userId
        end
        return BoardMath.better(kind, a.value, b.value)
    end)
    for i, entry in sorted do
        if entry.userId == meUserId then
            if i <= BoardMath.ROWS then
                return nil
            end
            return {
                rank = i,
                name = entry.name,
                value = BoardMath.format(kind, entry.value, entry.extra),
                mine = true,
            }
        end
    end
    return nil
end

-- Saptamana clasamentului, din ceasul serverului: luni 00:00 UTC e linia dintre doua saptamani.
function BoardMath.weekKey(now: number): string
    local days = math.floor(now / 86400)
    local week = math.floor((days + 3) / 7) -- 1 ianuarie 1970 a fost joi
    return tostring(week)
end

return BoardMath
