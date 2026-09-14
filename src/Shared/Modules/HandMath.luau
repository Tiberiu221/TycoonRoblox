--!strict
-- Traseul si ceasul unui alergator [F1, aria I]. Modul PUR, acelasi pe server (care decide cand se
-- strange o plasa si cand se vinde) si pe client (care il deseneaza mergand) -- deci ce vezi pe
-- mal e exact ce se intampla in cifre. Timpul vine ca parametru; nimic din `game`.
--
-- Un ciclu: debarcader -> plasa 1 -> ... -> plasa n -> debarcader. La fiecare plasa o pauza in
-- care strange (evenimentul "collect" cade la SOSIRE), la debarcader o pauza in care vinde
-- ("sell", tot la sosire). Ciclurile se repeta de la `cycleStartAt`, fara capat.
--
-- [D50] Pe drumuri: `via` sunt punctele prin care trece omul INAINTE sa ajunga la oprire, iar
-- `returnVia` cele de pe drumul inapoi. Devin doar picioare de mers -- nimic nu se strange si nu se
-- lasa pe drum, deci evenimentele raman exact la opriri.
--
-- [D55] O oprire poate fi si de LASAT (`drop`): Collector-ul lasa scrap-ul la shed inainte de depozit,
-- Porter-ul lasa bustenii la gater inainte sa duca scrap-ul la atelier. Evenimentul ei e "drop". `face` e
-- incotro sta omul in pauza -- spre gramada lui, ca roaba sa se rastoarne peste ea, nu spre rau.

export type Point = { x: number, y: number }
export type Stop = {
    x: number,
    y: number,
    padId: string, -- plasa, sau locul: "storage" | "shed" | "planks" | "iron" | "sawmill" | "forge"
    via: { Point }?,
    drop: boolean?,
    face: string?,
}
export type Leg = {
    t0: number,
    t1: number,
    kind: string, -- "walk" | "collect" | "drop" | "sell"
    from: Point,
    to: Point,
    padId: string?,
    face: string?,
}
export type Cycle = { legs: { Leg }, duration: number }
export type Event = { at: number, kind: string, padId: string? } -- "collect" | "drop" | "sell"
export type RunnerConfig = { speed: number, pauseNet: number, pauseDock: number }

local HandMath = {}

-- Plasele alergatorului cu numarul `runnerIndex` (1..): a k-a grupa de `perRunner` din plasele
-- DETINUTE, in ordinea platformelor. Exact ca simulatorul: automate sunt primele runners*3 plase.
function HandMath.runnerNets(
    ownedNetPadIds: { string },
    runnerIndex: number,
    perRunner: number
): { string }
    local result: { string } = {}
    local first = (runnerIndex - 1) * perRunner + 1
    for i = first, math.min(#ownedNetPadIds, first + perRunner - 1) do
        table.insert(result, ownedNetPadIds[i])
    end
    return result
end

local function distance(a: Point, b: Point): number
    local dx, dy = b.x - a.x, b.y - a.y
    return math.sqrt(dx * dx + dy * dy)
end

function HandMath.cycle(
    stops: { Stop },
    dock: Point,
    cfg: RunnerConfig,
    returnVia: { Point }?,
    dockFace: string?
): Cycle
    local legs: { Leg } = {}
    if #stops == 0 then
        return { legs = legs, duration = 0 }
    end
    local t = 0
    local here: Point = { x = dock.x, y = dock.y }
    local function walkTo(to: Point)
        local d = distance(here, to)
        local dt = d / cfg.speed
        table.insert(legs, { t0 = t, t1 = t + dt, kind = "walk", from = here, to = to })
        t += dt
        here = to
    end
    for _, s in stops do
        for _, p in s.via or {} do
            walkTo({ x = p.x, y = p.y })
        end
        walkTo({ x = s.x, y = s.y })
        table.insert(legs, {
            t0 = t,
            t1 = t + cfg.pauseNet,
            kind = if s.drop then "drop" else "collect",
            from = here,
            to = here,
            padId = s.padId,
            face = s.face,
        })
        t += cfg.pauseNet
    end
    for _, p in returnVia or {} do
        walkTo({ x = p.x, y = p.y })
    end
    walkTo({ x = dock.x, y = dock.y })
    table.insert(
        legs,
        { t0 = t, t1 = t + cfg.pauseDock, kind = "sell", from = here, to = here, face = dockFace }
    )
    t += cfg.pauseDock
    return { legs = legs, duration = t }
end

-- Unde e alergatorul la `t` secunde de la inceputul ciclurilor si ce face:
-- x, y, stare ("walk" | "collect" | "drop" | "sell" | "idle"), directie ("left" | "right" | "up" |
-- "down") si daca duce marfa (intre prima strangere si vanzare). In pauza, directia e `face` al opririi
-- (spre gramada), altfel "up".
function HandMath.sampleAt(c: Cycle, t: number): (number, number, string, string, boolean)
    if c.duration <= 0 or #c.legs == 0 then
        return 0, 0, "idle", "down", false
    end
    local tc = math.max(0, t) % c.duration
    local firstCollect = c.duration
    for _, leg in c.legs do
        if leg.kind == "collect" then
            firstCollect = leg.t0
            break
        end
    end
    local sellAt = c.legs[#c.legs].t0
    local carrying = tc >= firstCollect and tc < sellAt
    for _, leg in c.legs do
        if tc < leg.t1 or leg == c.legs[#c.legs] then
            if leg.kind ~= "walk" then
                return leg.to.x, leg.to.y, leg.kind, leg.face or "up", carrying
            end
            local span = leg.t1 - leg.t0
            local k = if span > 0 then math.clamp((tc - leg.t0) / span, 0, 1) else 1
            local dx, dy = leg.to.x - leg.from.x, leg.to.y - leg.from.y
            local facing = if math.abs(dx) >= math.abs(dy)
                then (if dx >= 0 then "right" else "left")
                else (if dy >= 0 then "down" else "up")
            return leg.from.x + dx * k, leg.from.y + dy * k, "walk", facing, carrying
        end
    end
    return c.legs[1].from.x, c.legs[1].from.y, "idle", "down", false
end

-- Evenimentele din intervalul (fromT, toT], in timp absolut, in ordine. `startAt` = inceputul
-- primului ciclu. Plafonat la UN ciclu: dupa o absenta lunga plasele sunt oricum pline pana la
-- capacitate, deci un singur ciclu le goleste pe toate; venitul automat din absenta e al
-- Seifului (aria J, F2), nu al acestei functii.
function HandMath.eventsBetween(c: Cycle, startAt: number, fromT: number, toT: number): { Event }
    local events: { Event } = {}
    if c.duration <= 0 or toT <= fromT then
        return events
    end
    local from = math.max(fromT, toT - c.duration, startAt)
    if toT <= from then
        return events
    end
    local kFirst = math.max(0, math.floor((from - startAt) / c.duration))
    local kLast = math.floor((toT - startAt) / c.duration)
    for k = kFirst, kLast do
        local base = startAt + k * c.duration
        for _, leg in c.legs do
            if leg.kind == "collect" or leg.kind == "drop" or leg.kind == "sell" then
                local at = base + leg.t0
                if at > from and at <= toT then
                    table.insert(events, { at = at, kind = leg.kind, padId = leg.padId })
                end
            end
        end
    end
    return events
end

return HandMath
