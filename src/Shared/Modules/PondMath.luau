--!strict
-- [D61] CONCURSUL DE LA IAZ, socotit fara joc. Modul pur: primeste ora (`now`, secunde UTC), nu o citeste.
--
-- In pasii jucatorului:
--   * la fiecare 6 minute incepe o runda: 4 minute de pescuit, apoi 2 minute cu rezultatele pe tabla;
--   * castiga cel mai mare peste scos in runda; la egalitate, cine l-a scos primul;
--   * premiile se dau la sfarsitul rundei: 20/12/8 perle pentru primii trei, cand au prins cel putin doi, si 3 pentru
--     oricine altcineva a prins ceva (si pentru cine a fost singur -- un concurs are nevoie de doi).
--
-- Ceasul e ora serverului (os.time), aceeasi pe toate serverele: cine vine stie cand incepe urmatoarea runda.
-- Premiile sunt mici intentionat: pescuitul in sine aduce ~8 perle pe minut, iar cine castiga toate rundele ia in plus
-- 3,3 pe minut (PearlBudget.test tine pragul).
local PondMath = {}

PondMath.CYCLE = 360 -- o runda si pauza ei, in secunde
PondMath.FISHING = 240 -- din care atat se pescuieste
PondMath.PRIZES = { 20, 12, 8 } -- locurile 1-3, doar cu cel putin MIN_RIVALS pescari
PondMath.TAKE_PART = 3 -- oricine altcineva a prins ceva, si cine a fost singur
PondMath.MIN_RIVALS = 2

export type Round = {
    id: number, -- runda de la 1970: unica, spune ce runda s-a incheiat
    index: number, -- a cata runda din ziua UTC (1..240), cea scrisa pe tabla
    phase: string, -- "fishing" | "results"
    startsAt: number,
    fishingEndsAt: number,
    nextAt: number, -- cand incepe urmatoarea
}

export type Catch = { userId: number, name: string, species: string, cm: number, at: number }

function PondMath.roundAt(now: number): Round
    local id = math.floor(now / PondMath.CYCLE)
    local startsAt = id * PondMath.CYCLE
    local dayStart = math.floor(startsAt / 86400) * 86400
    return {
        id = id,
        index = math.floor((startsAt - dayStart) / PondMath.CYCLE) + 1,
        phase = if now < startsAt + PondMath.FISHING then "fishing" else "results",
        startsAt = startsAt,
        fishingEndsAt = startsAt + PondMath.FISHING,
        nextAt = startsAt + PondMath.CYCLE,
    }
end

-- Tine minte pestele doar daca e mai mare decat cel mai bun al omului din runda. Intoarce true daca s-a schimbat ceva
-- (atunci tabla se trimite din nou).
function PondMath.record(best: { [number]: Catch }, catch: Catch): boolean
    local old = best[catch.userId]
    if old ~= nil and old.cm >= catch.cm then
        return false
    end
    best[catch.userId] = catch
    return true
end

-- Cel mai bun peste al fiecaruia, in ordinea locurilor: cm descrescator, apoi cine l-a scos primul, apoi userId (ca
-- ordinea sa nu sara intre doua trimiteri).
function PondMath.rank(best: { [number]: Catch }): { Catch }
    local list: { Catch } = {}
    for _, c in best do
        table.insert(list, c)
    end
    table.sort(list, function(a: Catch, b: Catch): boolean
        if a.cm ~= b.cm then
            return a.cm > b.cm
        end
        if a.at ~= b.at then
            return a.at < b.at
        end
        return a.userId < b.userId
    end)
    return list
end

-- A cata pozitie are omul in clasament (sau nil daca n-a prins nimic in runda).
function PondMath.placeOf(ranked: { Catch }, userId: number): number?
    for i, c in ranked do
        if c.userId == userId then
            return i
        end
    end
    return nil
end

-- Premiul fiecaruia, in ordinea din `ranked`.
function PondMath.prizes(ranked: { Catch }): { number }
    local out: { number } = {}
    local contest = #ranked >= PondMath.MIN_RIVALS
    for i = 1, #ranked do
        local prize = if contest then PondMath.PRIZES[i] else nil
        out[i] = prize or PondMath.TAKE_PART
    end
    return out
end

-- Cat ia pe minut cine castiga toate rundele, doar din premii (pentru bugetul perlelor).
function PondMath.bestPerMinute(): number
    return PondMath.PRIZES[1] / (PondMath.CYCLE / 60)
end

return PondMath
