--!strict
-- [PLAN-MOTOR-UNIRE §16, l1] Sonda din Studio: profilul unui Play de proba dus in Play-ul urmator. O salvare de proba se pierde
-- la Stop (ProfileStore.Mock), iar drumul spre baraj trece printr-o reincarcare (in Studio: Stop, apoi Play). `dev export`
-- da profilul ca JSON (DevService), iar `probe.py play --profile` il pune inapoi (DataService, doar intr-un Play de proba).
-- Aici: unde schimba drumul prin JSON profilul (o cheie numerica scrisa ca text, un tablou cu goluri, un NaN, o cifra
-- rotunjita), ca exportul sa refuze, in loc sa duca in Play-ul urmator alt profil decat cel jucat [D40].
local ProbeCarry = {}

local function keyText(k: any): string
    return if typeof(k) == "string" then k else `[{tostring(k)}]`
end

local function join(path: string?, k: any): string
    return if path == nil then keyText(k) else `{path}.{keyText(k)}`
end

-- Primul loc in care `b` nu e `a` (calea, de exemplu "Stations.nets.first_net.level"), sau nil daca sunt la fel. Un tabel
-- gol e la fel cu altul gol: JSON nu deosebeste [] de {}, iar profilul nu tine nimic in diferenta asta.
function ProbeCarry.firstDiff(a: any, b: any, path: string?): string?
    local here = path or "(root)"
    if typeof(a) ~= typeof(b) then
        return here
    end
    if typeof(a) == "number" then
        -- NaN nu e egal nici cu el insusi, deci nu trece prin JSON
        return if a == a and a == b then nil else here
    end
    if typeof(a) ~= "table" then
        return if a == b then nil else here
    end
    for k, v in a do
        if typeof(k) ~= "string" and typeof(k) ~= "number" then
            return join(path, k)
        end
        local diff = ProbeCarry.firstDiff(v, b[k], join(path, k))
        if diff ~= nil then
            return diff
        end
    end
    for k in b do
        if a[k] == nil then
            return join(path, k)
        end
    end
    return nil
end

return ProbeCarry
