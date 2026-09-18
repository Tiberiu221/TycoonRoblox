--!strict
-- [D63] TINTA FARA SFARSIT de pe linia NEXT. Modul pur.
--
-- De ce: linia NEXT e singurul lucru din HUD care raspunde permanent la "ce fac acum si de ce" [P3: urmatorul pas e
-- mereu vizibil]. Dar cand se terminau quest-urile si ghidajul tacea, linia DISPAREA cu totul -- adica exact dupa
-- capitolul 3, cand jucatorul are cel mai mult de urcat si niciun reper. Nivelurile nu se termina niciodata, iar fiecare
-- prag (10 / 25 / 50 / 100 ...) dubleaza debitul si se sarbatoreste: pragul urmator e o tinta mereu la indemana.
--
-- Ce alege, in ordine, ca tinta sa fie si ADEVARATA [D40] -- adica sa creasca venitul acum, nu doar un numar:
--   1. veriga care tine venitul in loc, daca e o cladire sau o plasa: pragul ei urmator;
--   2. veriga slaba, daca e o meserie: nivelul ei urmator, sau al doilea om cand nivelul o permite;
--   3. altfel (veriga slaba e la maxim sau nu se stie): cladirea cea mai aproape de pragul ei.
-- Primeste randurile pe care clientul le are deja din starea statiilor; nu stie nimic de `game`.
local AmbitionMath = {}

export type StationRow = {
    kind: string,
    id: string?,
    name: string,
    level: number,
    nextMilestone: number?,
    bottleneck: boolean?,
    gain: number?,
}
export type CrewRow = {
    role: string,
    name: string,
    count: number,
    tier: number,
    maxTier: number,
    maxPeople: number,
    tierBlock: string?,
    hireBlock: string?,
    bottleneck: boolean?,
}
export type Ambition = {
    what: string, -- "milestone" | "crewLevel" | "secondHire"
    kind: string, -- felul randului: "net" | "saw" | "dock" | "forge", sau rolul meseriei
    id: string?, -- id-ul plasei, cand e o plasa
    name: string,
    target: number, -- nivelul tintit (pragul, nivelul meseriei) sau 2 (al doilea om)
    level: number, -- unde esti acum, in aceeasi unitate ca `target`: cifra din dreapta barei ("12/25")
    progress: number, -- unde esti acum, in aceeasi unitate ca `goal`
    goal: number,
}

-- Pragul dinaintea nivelului asta (0 sub primul): bara masoara drumul DE LA ultimul prag, altfel la nivelul 26 din 50 ar
-- arata deja pe jumatate plina si n-ar mai parea ca inainteaza.
local function floorOf(level: number, nextMilestone: number, milestones: { number }): number
    local floor = 0
    for _, t in milestones do
        if t <= level and t < nextMilestone then
            floor = t
        end
    end
    return floor
end

local function milestoneOf(row: StationRow, milestones: { number }): Ambition?
    local nextAt = row.nextMilestone
    if nextAt == nil or nextAt <= row.level then
        return nil
    end
    local floor = floorOf(row.level, nextAt, milestones)
    return {
        what = "milestone",
        kind = row.kind,
        id = row.id,
        name = row.name,
        target = nextAt,
        level = row.level,
        progress = row.level - floor,
        goal = nextAt - floor,
    }
end

function AmbitionMath.pick(
    rows: { StationRow },
    crews: { CrewRow },
    milestones: { number }
): Ambition?
    -- 1. cladirea sau plasa care tine venitul in loc (un nivel acolo chiar aduce ceva)
    for _, row in rows do
        if row.bottleneck == true and (row.gain or 0) > 0 then
            local a = milestoneOf(row, milestones)
            if a ~= nil then
                return a
            end
        end
    end
    -- 2. meseria care tine venitul in loc
    for _, crew in crews do
        if crew.bottleneck == true and crew.count > 0 then
            if crew.tier < crew.maxTier and crew.tierBlock == nil then
                return {
                    what = "crewLevel",
                    kind = crew.role,
                    name = crew.name,
                    target = crew.tier + 1,
                    level = crew.tier,
                    progress = crew.tier,
                    goal = crew.maxTier,
                }
            elseif crew.count < crew.maxPeople and crew.hireBlock == nil then
                return {
                    what = "secondHire",
                    kind = crew.role,
                    name = crew.name,
                    target = crew.count + 1,
                    level = crew.count,
                    progress = crew.count,
                    goal = crew.maxPeople,
                }
            end
        end
    end
    -- 3. cel mai apropiat prag, oriunde: nivelurile nu se termina, deci tinta asta exista mereu
    local best: Ambition? = nil
    for _, row in rows do
        local a = milestoneOf(row, milestones)
        if a ~= nil then
            local b = best
            if b == nil or (a.goal - a.progress) < (b.goal - b.progress) then
                best = a
            end
        end
    end
    return best
end

return AmbitionMath
