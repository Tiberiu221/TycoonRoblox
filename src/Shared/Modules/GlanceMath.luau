--!strict
-- [D70] DRUMUL CAMEREI LA "LOOK (V)", pur (primeste `now`). O privire pleaca din punctul in care sta camera acum (poate
-- trasa spre un dar de pe rau, sau in mijlocul altei priviri), merge lin spre loc, sta acolo HOLD secunde, apoi se
-- intoarce lin la om, oriunde a ajuns el intre timp. Drumul dureaza dupa lungime: peste toata harta, 0,9 s fixe ar fi
-- fost o smucitura (~100 px pe cadru). Anularea (ai pornit la drum) si o privire noua pornesc din punctul de acum, deci
-- camera nu sare niciodata.
local GlanceMath = {}

GlanceMath.HOLD = 2.0
GlanceMath.MIN_SECONDS = 0.6
GlanceMath.MAX_SECONDS = 1.6
GlanceMath.PX_PER_SECOND = 2500 -- peste MIN_SECONDS: o secunda in plus la fiecare 2500 px de drum

export type Glance = {
    fromX: number,
    fromY: number,
    toX: number,
    toY: number,
    startedAt: number,
    goSeconds: number,
    -- intoarcerea pornita mai devreme (anulare); nil = cea obisnuita, dupa HOLD
    backAt: number?,
    backFromX: number,
    backFromY: number,
    backSeconds: number,
}

local function smooth(k: number): number
    local c = math.clamp(k, 0, 1)
    return c * c * (3 - 2 * c)
end

local function dist(ax: number, ay: number, bx: number, by: number): number
    return math.sqrt((ax - bx) ^ 2 + (ay - by) ^ 2)
end

-- Cat tine un drum de `distance` px de lume (dus sau intors).
function GlanceMath.seconds(distance: number): number
    return math.clamp(
        GlanceMath.MIN_SECONDS + distance / GlanceMath.PX_PER_SECOND,
        GlanceMath.MIN_SECONDS,
        GlanceMath.MAX_SECONDS
    )
end

function GlanceMath.start(
    fromX: number,
    fromY: number,
    toX: number,
    toY: number,
    now: number
): Glance
    local go = GlanceMath.seconds(dist(fromX, fromY, toX, toY))
    return {
        fromX = fromX,
        fromY = fromY,
        toX = toX,
        toY = toY,
        startedAt = now,
        goSeconds = go,
        backAt = nil,
        backFromX = toX,
        backFromY = toY,
        backSeconds = go,
    }
end

-- Punctul pe care il urmareste camera la `now`, cu omul in (px, py); nil = privirea s-a terminat (camera e la om).
function GlanceMath.point(g: Glance, now: number, px: number, py: number): (number?, number?)
    local backAt = g.backAt
    local fromX, fromY, secs = g.backFromX, g.backFromY, g.backSeconds
    if backAt == nil then
        local t = now - g.startedAt
        if t < g.goSeconds then
            local k = smooth(t / g.goSeconds)
            return g.fromX + (g.toX - g.fromX) * k, g.fromY + (g.toY - g.fromY) * k
        elseif t < g.goSeconds + GlanceMath.HOLD then
            return g.toX, g.toY
        end
        backAt = g.startedAt + g.goSeconds + GlanceMath.HOLD
    end
    local k = (now - (backAt :: number)) / secs
    if k >= 1 then
        return nil, nil
    end
    local e = smooth(k)
    return fromX + (px - fromX) * e, fromY + (py - fromY) * e
end

-- Ai pornit la drum: intoarcerea incepe acum, din punctul de acum. Una deja pornita (dupa HOLD, sau o anulare) merge
-- mai departe neschimbata: reluata din repaus, camera se oprea brusc la mijlocul drumului. O privire terminata ramane
-- terminata.
function GlanceMath.cancel(g: Glance, now: number, px: number, py: number): Glance
    if g.backAt ~= nil or now >= g.startedAt + g.goSeconds + GlanceMath.HOLD then
        return g
    end
    local x, y = GlanceMath.point(g, now, px, py)
    if x == nil or y == nil then
        return g
    end
    local c = table.clone(g)
    c.backAt = now
    c.backFromX, c.backFromY = x, y
    c.backSeconds = GlanceMath.seconds(dist(x, y, px, py))
    return c
end

return GlanceMath
