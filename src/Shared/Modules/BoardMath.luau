--!strict
-- [D60] RANDURILE DE PE TABELA din bâlci. Modul pur: primeste ce a citit serverul din OrderedDataStore si scoate
-- randurile gata scrise, ca desenul sa nu mai socoteasca nimic.
--
-- Trei feluri de clasament, fiecare cu unitatea lui; cifra bruta din store e intreaga (OrderedDataStore tine doar
-- intregi), deci aici se face si intoarcerea in unitati de om: centimetri, monede pe secunda, secunde.
local TycoonMath = require(script and script.Parent.TycoonMath or "./TycoonMath")

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
        -- sutimi de moneda pe secunda; [2026-09-29] de la o mie, cu unitatile contorului de monede (TycoonMath): in Era
        -- 3 panoul mare scria "1200000000.00/s" si nu incapea in coloana lui
        local perSec = value / 100
        if perSec < 1000 then
            return string.format("%.2f/s", perSec)
        end
        -- aceeasi cifra ca pe panoul pictat de pe scena (BoardMath.compact), ca un rand sa nu spuna doua numere
        return BoardMath.compact("income", value) .. "/s"
    elseif kind == "era1" then
        return duration(math.floor(value))
    end
    return tostring(value)
end

-- [2026-09-29] aceleasi unitati ca TycoonMath.formatNumber (pana la Td); pana acum se oprea la T
local INCOME_UNITS: { string } = {}
for _, unit in TycoonMath.UNITS do
    table.insert(INCOME_UNITS, unit[1] :: string)
end

-- Cifra scurta, pentru panourile pictate pe scena: scena ii lipeste unitatea (Strings.STAGE_UNITS), iar impreuna au
-- cel mult opt litere, cat coloana ei (BoardController.VALUE_W). Specia pestelui sta in panoul mare.
BoardMath.STAGE_CHARS = 8
function BoardMath.compact(kind: string, value: number): string
    if kind == "fish" then
        return string.format("%.1f", math.floor(value) / 10)
    elseif kind == "income" then
        -- Urca la unitatea urmatoare cand numarul scris ar avea patru cifre: 999.95K s-ar rotunji la "1000.0K" si
        -- n-ar mai incapea in coloana de pe scena, asa ca se scrie "1.0M".
        -- [2026-09-29] Cifra are cel mult cinci caractere, iar cu unitatea cel mult sase: cu sufixele de doua litere de dupa
        -- T ("Qa", "Qi"...), "123.4Qi" plus "/s" ar fi avut noua litere. O unitate de doua litere pierde intai zecimala
        -- ("123Qi"); abia cand nici asa nu incape (o mie), urca la unitatea urmatoare ("1.0Sx"). Cifra se TAIE, ca pe
        -- contorul de monede: nu arata niciodata mai mult decat venitul (rotunjit, "999.95K" iesea "1.0M"). Toleranta
        -- acopera doar impartirile cu 100 si 1000, care nu sunt exacte in virgula mobila.
        local function fits(number: string, suffix: string): boolean
            return #number <= 5 and #number + #suffix <= 6
        end
        local SLACK = 1e-12
        local perSec = value / 100
        for i = 0, #INCOME_UNITS do
            local suffix = if i == 0 then "" else INCOME_UNITS[i]
            local shown = perSec / 1000 ^ i
            local number = string.format("%.1f", math.floor(shown * 10 * (1 + SLACK)) / 10)
            if fits(number, suffix) then
                return number .. suffix
            end
            local whole = string.format("%.0f", math.floor(shown * (1 + SLACK)))
            if #whole <= 3 and fits(whole, suffix) then
                return whole .. suffix
            end
        end
        return TycoonMath.formatNumber(perSec) -- peste 999 Td: scrierea stiintifica ("1e45")
    elseif kind == "era1" then
        local s = math.floor(value)
        local h, m = math.floor(s / 3600), math.floor(s / 60) % 60
        if h >= 100 then
            return ">99h" -- pe panou nu mai incape, iar in panoul mare scrie intreg
        end
        return if h > 0
            then string.format("%d:%02d:%02d", h, m, s % 60)
            else string.format("%d:%02d", m, s % 60)
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

-- [D70, 2026-09-29] VENITUL PE TABELA, INTR-UN INTREG CARE INCAPE. OrderedDataStore tine doar intregi, iar un numar
-- Luau e exact doar pana la 2^53; venitul se scrie in sutimi, deci pe la Era 6 ar fi trecut de ele. Sub ENCODE_EXACT
-- sutimi (venit sub 10 miliarde pe secunda, adica tot ce s-a scris pana azi) codul e chiar cifra, deci tabelele vechi
-- raman bune. Peste, codul e exponentul si primele 12 cifre (exponent x 10^12 + cifrele): ordinea ramane aceeasi, iar
-- precizia e de 12 cifre, mai mult decat arata orice panou. Cel mai mare cod (venitul maxim al unui numar) e sub 10^15.
BoardMath.ENCODE_EXACT = 1e12
local DIGITS = 12

-- Exponentul zecimal al lui v (v >= 1), indreptat pe valoarea insasi (log10 poate gresi cu unu pe o putere a lui 10).
local function exponent(v: number): number
    local e = math.floor(math.log10(v))
    if 10 ^ (e + 1) <= v then
        e += 1
    elseif 10 ^ e > v then
        e -= 1
    end
    return e
end

function BoardMath.encodeIncome(hundredths: number): number
    if not (hundredths >= 1) or not math.isfinite(hundredths) then
        return 0 -- nimic (sau o cifra stricata): nu intra pe tabela
    end
    local v = math.floor(hundredths)
    if v < BoardMath.ENCODE_EXACT then
        return v
    end
    local e = exponent(v)
    local digits = math.floor(v / 10 ^ (e - DIGITS + 1))
    digits = math.clamp(digits, 10 ^ (DIGITS - 1), 10 ^ DIGITS - 1)
    return e * BoardMath.ENCODE_EXACT + digits
end

function BoardMath.decodeIncome(code: number): number
    if code < BoardMath.ENCODE_EXACT then
        return code
    end
    local e = math.floor(code / BoardMath.ENCODE_EXACT)
    local digits = code - e * BoardMath.ENCODE_EXACT
    return digits * 10 ^ (e - DIGITS + 1)
end

-- Saptamana clasamentului, din ceasul serverului: luni 00:00 UTC e linia dintre doua saptamani.
function BoardMath.weekKey(now: number): string
    local days = math.floor(now / 86400)
    local week = math.floor((days + 3) / 7) -- 1 ianuarie 1970 a fost joi
    return tostring(week)
end

return BoardMath
