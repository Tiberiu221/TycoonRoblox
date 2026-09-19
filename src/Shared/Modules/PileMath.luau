--!strict
-- Gramezile ca NUMARATORI [D49]. Pana la D49 o gramada era o lista cu un tabel pe bucata: un
-- Collector care lucreaza fara Porter adauga zeci de mii de bucati pe ora IN PROFIL (limita DataStore
-- e 4 MB -- un salvat esuat pierde progres), iar fiecare bucata scoasa cu `table.remove(pile, 1)`
-- muta toata lista. Cu numaratori, marimea tine de catalog, nu de volum: gramada nu are plafon.
--
-- O gramada tine un singur fel de marfa (bruta la depozit si la intrarea gaterului, taiata la iesire si
-- la debarcader), deci nu are nevoie de marcajul `p`. Il capata bucatile scoase dintr-o gramada de
-- marfa taiata, cand ajung in traista sau in spinarea unui om, unde brutul si taiatul se amesteca.
-- Modul PUR.
local PileMath = {}

export type Catch = { g: string, c: string?, t: string?, p: boolean? }
export type Counts = { [string]: number }

-- [D65] Gasirile au cate un fel pe era (`named`, `named2`, ...): toate isi tin catalogul si tier-ul in cheie, ca o
-- gramada sa nu le amestece. Cheile Erei 1 (`named|<catalog>|<tier>`) raman exact cum erau.
local function findGoodOf(key: string): string?
    return string.match(key, "^(named%d*)|")
end

function PileMath.isFindGood(good: string): boolean
    return string.match(good, "^named%d*$") ~= nil
end

-- Cheia unei bucati. Bunurile obisnuite: felul lor. Obiectele cu nume isi pastreaza catalogul si
-- tier-ul, de care depind pretul si Atelierul: "named|<catalog>|<tier>".
function PileMath.keyOf(item: Catch): string
    if PileMath.isFindGood(item.g) then
        return `{item.g}|{item.c or ""}|{item.t or ""}`
    end
    return item.g
end

function PileMath.itemOf(key: string, cut: boolean?): Catch
    local item: Catch
    local findGood = findGoodOf(key)
    if findGood ~= nil then
        local c, t = string.match(key, "^named%d*|([^|]*)|([^|]*)$")
        item = {
            g = findGood,
            c = if c ~= nil and c ~= "" then c else nil,
            t = if t ~= nil and t ~= "" then t else nil,
        }
    else
        item = { g = key }
    end
    if cut then
        item.p = true
    end
    return item
end

function PileMath.total(counts: Counts): number
    local n = 0
    for _, v in counts do
        n += v
    end
    return n
end

function PileMath.add(counts: Counts, item: Catch, n: number?)
    local key = PileMath.keyOf(item)
    counts[key] = (counts[key] or 0) + (n or 1)
end

function PileMath.addItems(counts: Counts, items: { Catch })
    for _, item in items do
        PileMath.add(counts, item)
    end
end

-- Scoate cel mult `n` bucati, in ordinea cheilor: aceeasi gramada da mereu aceleasi bucati, pe server
-- si in teste. `cut` = bucatile ies marcate ca taiate (din gramezile de marfa taiata).
function PileMath.take(counts: Counts, n: number, cut: boolean?): { Catch }
    local out: { Catch } = {}
    local want = math.floor(n)
    if want <= 0 then
        return out
    end
    local keys: { string } = {}
    for key, v in counts do
        if v > 0 then
            table.insert(keys, key)
        end
    end
    table.sort(keys)
    for _, key in keys do
        local take = math.min(counts[key], want - #out)
        for _ = 1, take do
            table.insert(out, PileMath.itemOf(key, cut))
        end
        local left = counts[key] - take
        counts[key] = if left > 0 then left else nil
        if #out >= want then
            break
        end
    end
    return out
end

-- Pe feluri de bun, pentru desen: gramada de langa cladire nu arata catalogul.
function PileMath.contents(counts: Counts): { [string]: number }
    local out: { [string]: number } = {}
    for key, v in counts do
        local g = findGoodOf(key) or key
        out[g] = (out[g] or 0) + v
    end
    return out
end

-- O lista veche (profil v4) -> numaratori. Ce nu arata a bucata se sare, nu crapa migrarea.
function PileMath.fromItems(items: { any }): Counts
    local counts: Counts = {}
    for _, item in items do
        if type(item) == "table" and type(item.g) == "string" then
            PileMath.add(counts, item :: Catch)
        end
    end
    return counts
end

return PileMath
