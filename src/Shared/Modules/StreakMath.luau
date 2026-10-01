--!strict
-- [D71] SERIA ZILNICA: cate zile vii in sat, una dupa alta. Modul pur: primeste ziua, nu ceasul.
--
-- Owner-ul, 2026-10-01: satul se odihneste dupa 24 h fara tine, deci revenirea zilnica e rasplatita; „trebuie monitorizat,
-- ca un fel de streak pe care jucatorul il poate avea la hub". Ce se rupe si ce nu [P2: nimic nu se pierde]:
--   * `best` (cea mai lunga serie) si `total` (zile cu revenire) doar cresc. Titlurile (TitleMath: Regular, Old Friend) se
--     leaga numai de `best`, ca un titlu castigat sa nu cada de pe om (un titlu care nu mai e al tau cade pe cel al Erei).
--   * `run` (seria de acum) poate reincepe: o zi lipsa nu o rupe, doua da. ZIUA E A TA, nu cea UTC [verificator,
--     2026-10-01]: pe ziua UTC, in California ziua se schimba la 17:00 („Day 2” in aceeasi dupa-amiaza), iar o toleranta
--     de doua zile UTC ii lasa pe cei care vin o data la trei zile sa ia aceleasi titluri. Clientul spune o data fusul lui
--     orar (`offset`, secunde fata de UTC), iar serverul il valideaza (intre -12 h si +14 h, rotunjit la 15 minute) si
--     il schimba cel mult o data pe zi UTC, ca nimeni sa nu numere o zi de doua ori mutand ceasul. Pana il spune, ziua e
--     cea UTC. Seria nu da monede, deci un fus mintit castiga cel mult o zi de titlu. Regula e spusa dinainte [D43].
-- Nicio presiune [D63, nota 41]: fara numaratoare inversa, fara mesaje „pierzi seria”, nimic de cumparat pentru ea.
local StreakMath = {}

StreakMath.DAY = 86400
StreakMath.GRACE_DAYS = 1 -- zile lipsa (ale tale) care nu rup seria
StreakMath.OFFSET_MIN = -12 * 3600
StreakMath.OFFSET_MAX = 14 * 3600
StreakMath.OFFSET_STEP = 15 * 60

-- `offset`: fusul orar al jucatorului (secunde fata de UTC); `offsetDay`: ziua UTC in care s-a schimbat ultima data
export type Streak = {
    day: number,
    run: number,
    best: number,
    total: number,
    offset: number,
    offsetDay: number,
}
-- "same": aceeasi zi (nimic nou); "first": prima zi numarata vreodata; "next": seria creste; "broke": seria reincepe
export type Event = "same" | "first" | "next" | "broke"

-- Ziua ta: ziua UTC mutata cu fusul tau orar (fara fus, ziua UTC).
function StreakMath.dayOf(now: number, offset: number?): number
    return math.floor((now + (offset or 0)) / StreakMath.DAY)
end

-- Un fus orar trimis de client, curatat: numar finit intre -12 h si +14 h, rotunjit la 15 minute; altfel nil.
function StreakMath.cleanOffset(x: unknown): number?
    if
        typeof(x) ~= "number"
        or x ~= x
        or x < StreakMath.OFFSET_MIN
        or x > StreakMath.OFFSET_MAX
    then
        return nil
    end
    return math.floor(x / StreakMath.OFFSET_STEP + 0.5) * StreakMath.OFFSET_STEP
end

local function count(x: unknown): number
    if typeof(x) ~= "number" or x ~= x or x < 0 or x == math.huge then
        return 0
    end
    return math.floor(x)
end

-- O copie curata (profil vechi sau stricat: zero, niciodata NaN sau negativ).
function StreakMath.clean(s: unknown): Streak
    local t: any = if typeof(s) == "table" then s else {}
    local run = count(t.run)
    local best = math.max(count(t.best), run)
    return {
        day = count(t.day),
        run = run,
        best = best,
        total = math.max(count(t.total), run),
        offset = StreakMath.cleanOffset(t.offset) or 0,
        offsetDay = count(t.offsetDay),
    }
end

-- Fusul orar spus de client. Se schimba cel mult o data pe zi UTC (si doar daca e altul): o copie noua si daca s-a schimbat.
function StreakMath.setOffset(s: unknown, offset: unknown, now: number): (Streak, boolean)
    local c = StreakMath.clean(s)
    local clean = StreakMath.cleanOffset(offset)
    local utcDay = StreakMath.dayOf(now)
    if clean == nil or clean == c.offset or c.offsetDay == utcDay then
        return c, false
    end
    -- [verificator] vizita de azi, deja numarata pe ceasul vechi (la incarcare, inainte sa vina fusul; sau la ora de vara),
    -- se muta pe ceasul nou fara sa se numere din nou: altfel in Japonia prima sesiune scria „Day 2”, iar in California
    -- ziua de maine se pierdea.
    if c.day > 0 and c.day >= StreakMath.dayOf(now, c.offset) then
        c.day = StreakMath.dayOf(now, clean)
    end
    c.offset, c.offsetDay = clean, utcDay
    return c, true
end

-- Revenirea din ziua `today`. Intoarce seria noua (o copie), ce s-a intamplat si daca e un record nou (seria de acum a
-- trecut de cea mai lunga de pana azi; la egalitate, nu). Aceeasi zi nu numara de doua ori: profilul se incarca la fiecare
-- drum cu barca, in sat si in balci.
function StreakMath.touch(s: unknown, today: number): (Streak, Event, boolean)
    local c = StreakMath.clean(s)
    if c.day > 0 and today <= c.day then
        return c, "same", false -- tot azi, sau ceasul a mers inapoi
    end
    local bestBefore = c.best
    local event: Event
    if c.day <= 0 or c.run <= 0 then
        c.run, event = 1, "first"
    elseif today - c.day <= 1 + StreakMath.GRACE_DAYS then
        c.run, event = c.run + 1, "next"
    else
        c.run, event = 1, "broke"
    end
    c.day = today
    c.total += 1
    c.best = math.max(c.best, c.run)
    return c, event, c.run > bestBefore and c.run >= 2
end

-- Merita spus pe ecran? Prima zi nu (orice jucator nou ar primi „Day 1”), o serie care creste da, iar o serie care
-- reincepe doar daca a fost una de cel putin doua zile (cea mai buna ramane si o spunem).
function StreakMath.worthTelling(s: Streak, event: Event): boolean
    if event == "next" then
        return s.run >= 2
    end
    return event == "broke" and s.best >= 2
end

return StreakMath
