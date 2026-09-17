--!strict
-- [D60] PREZENTA IN BALCI: ce se accepta dintr-un pachet de pozitie si cum se misca ceilalti intre doua pachete.
-- Modul pur, folosit si de server (validare), si de client (interpolare).
--
-- Pozitia e doar ASPECT: nicio cifra din economie nu trece pe aici. Un pachet stricat poate cel mult sa-si
-- raporteze gresit propria pozitie; aspectul si titlul le pune serverul, din profil [D60].
local FairLayout = require(script and script.Parent.FairLayout or "./FairLayout")

local FairPresence = {}

FairPresence.RATE = 10 -- pachete pe secunda, in ambele sensuri
FairPresence.SPEED = 320 * 1.6 -- cel mai repede se merge in joc (RiverConfig.CHARACTER, alergand)
FairPresence.SLACK = 1.5 -- pachetele nesigure intarzie si vin cate doua deodata
FairPresence.FACINGS = { up = true, down = true, left = true, right = true }

function FairPresence.isValidFacing(value: unknown): boolean
    return typeof(value) == "string" and FairPresence.FACINGS[value :: string] == true
end

-- Cat de departe poate ajunge cineva in `dt` secunde, cu marja pentru pachetele intarziate.
function FairPresence.maxStep(dt: number): number
    return FairPresence.SPEED * math.max(dt, 1 / FairPresence.RATE) * FairPresence.SLACK + 8
end

local function finite(n: unknown): boolean
    return typeof(n) == "number" and n == n and n ~= math.huge and n ~= -math.huge
end

export type Sample = { x: number, y: number, t: number }

-- Un pachet se accepta daca are numere adevarate, cade pe un loc unde se poate merge si nu sare mai departe decat
-- se poate alerga de la ultimul pachet bun. Un pachet respins nu se corecteaza: ramane ultimul bun.
function FairPresence.accept(prev: Sample?, x: unknown, y: unknown, t: number): boolean
    if not finite(x) or not finite(y) then
        return false
    end
    local nx, ny = x :: number, y :: number
    if not FairLayout.isWalkable(nx, ny) then
        return false
    end
    if prev == nil then
        return true
    end
    local p = prev :: Sample
    local dist = math.sqrt((nx - p.x) ^ 2 + (ny - p.y) ^ 2)
    return dist <= FairPresence.maxStep(t - p.t)
end

-- Pozitia desenata intre doua pachete: `alpha` = cat din intervalul dintre ele a trecut (0..1, taiat la capete).
function FairPresence.lerp(
    ax: number,
    ay: number,
    bx: number,
    by: number,
    alpha: number
): (number, number)
    local a = math.clamp(alpha, 0, 1)
    return ax + (bx - ax) * a, ay + (by - ay) * a
end

return FairPresence
