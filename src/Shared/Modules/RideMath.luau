--!strict
-- [D60] DRUMUL CU BARCA, in amonte, de la pontonul tau la bâlci. Modul pur: unde e barca la momentul t, cand apare
-- butonul de sarit si cand se face schimbarea de loc.
--
-- Sase secunde, cu `Skip` de la a doua calatorie incolo (owner, 2026-09-16). Barca merge IMPOTRIVA curentului, deci
-- inainteaza mai greu la mijloc: curba de mai jos incetineste acolo si accelereaza la final, cand intra in golful
-- bâlciului.
local RideMath = {}

RideMath.SECONDS = 6
RideMath.SKIP_AFTER = 1.2 -- cat sta pana apare butonul, ca sa nu-l apesi din greseala la pornire
RideMath.FADE = 0.45 -- ultima bucata, in care ecranul se inchide spre bâlci

-- Cat din drum e facut la momentul t. Nu e liniar: pleaca usor, se lupta cu curentul la mijloc, apoi intra in golf.
function RideMath.progress(t: number): number
    local x = math.clamp(t / RideMath.SECONDS, 0, 1)
    local eased = x * x * (3 - 2 * x) -- pornire si oprire line
    local current = math.sin(math.pi * x) * 0.08 -- curentul care te tine pe loc la mijloc
    return math.clamp(eased - current, 0, 1)
end

-- Cat din drumul pictat se parcurge: scena drumului (FerryController) e mai lunga decat ecranul, iar malurile trec pe
-- langa barca exact cu atat.
RideMath.DISTANCE = 900

-- Pozitia barcii pe drum, de la `from` spre AMONTE. In sat raul curge spre dreapta (bustenii pleaca de la marginea din
-- stanga, CatchFloat.SPAWN_X), deci in amonte inseamna spre stanga: x scade. Pe drum, un cot spre mijlocul raului.
function RideMath.at(
    t: number,
    from: { x: number, y: number }
): { x: number, y: number, tilt: number }
    local p = RideMath.progress(t)
    local dx = RideMath.DISTANCE * p
    local sway = math.sin(p * math.pi) * 70
    return { x = from.x - dx, y = from.y - sway, tilt = math.sin(p * math.pi * 2) * 4 }
end

function RideMath.canSkip(t: number): boolean
    return t >= RideMath.SKIP_AFTER
end

-- Cat de inchis e ecranul la momentul t: 0 pana in ultima bucata, apoi creste spre 1, ca schimbarea de loc sa se
-- intample pe negru, nu in mijlocul apei.
function RideMath.fade(t: number): number
    local left = RideMath.SECONDS - t
    if left >= RideMath.FADE then
        return 0
    end
    return math.clamp(1 - left / RideMath.FADE, 0, 1)
end

function RideMath.done(t: number): boolean
    return t >= RideMath.SECONDS
end

return RideMath
