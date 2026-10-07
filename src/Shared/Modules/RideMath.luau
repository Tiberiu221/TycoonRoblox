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

-- [owner, 2026-10-07: „la DAM ar trebui sa poti ajunge la balci cu o barca mai performanta”] Cu ce mergi: barca cu
-- vasle a satului (`row`) sau salupa cu aburi a barajului (`launch`). Salupa face drumul in patru secunde, nu in sase,
-- si nu se lupta cu curentul (o impinge aburul). Fara barca data: cea cu vasle, deci drumul satului ramane neschimbat.
export type Vessel = "row" | "launch"
RideMath.VESSELS = {
    row = { seconds = RideMath.SECONDS, current = 0.08 },
    launch = { seconds = 4, current = 0 },
} :: { [string]: { seconds: number, current: number } }

local function vesselOf(vessel: string?): { seconds: number, current: number }
    return RideMath.VESSELS[vessel or "row"] or RideMath.VESSELS.row
end

-- Barca cu care pleaca cineva din lumea lui: de la baraj (lumea 2) incolo, salupa.
function RideMath.vesselOfWorld(world: number): Vessel
    return if world >= 2 then "launch" else "row"
end

-- Cat tine drumul cu barca asta.
function RideMath.secondsOf(vessel: string?): number
    return vesselOf(vessel).seconds
end

-- Cat din drum e facut la momentul t. Nu e liniar: pleaca usor, se lupta cu curentul la mijloc, apoi intra in golf.
function RideMath.progress(t: number, vessel: string?): number
    local v = vesselOf(vessel)
    local x = math.clamp(t / v.seconds, 0, 1)
    local eased = x * x * (3 - 2 * x) -- pornire si oprire line
    local current = math.sin(math.pi * x) * v.current -- curentul care te tine pe loc la mijloc
    return math.clamp(eased - current, 0, 1)
end

-- Cat din drumul pictat se parcurge: scena drumului (FerryController) e mai lunga decat ecranul, iar malurile trec pe
-- langa barca exact cu atat.
RideMath.DISTANCE = 900

-- Pozitia barcii pe drum, de la `from` spre AMONTE. In sat raul curge spre dreapta (bustenii pleaca de la marginea din
-- stanga, CatchFloat.SPAWN_X), deci in amonte inseamna spre stanga: x scade. Pe drum, un cot spre mijlocul raului.
function RideMath.at(
    t: number,
    from: { x: number, y: number },
    vessel: string?
): { x: number, y: number, tilt: number }
    local p = RideMath.progress(t, vessel)
    local dx = RideMath.DISTANCE * p
    local sway = math.sin(p * math.pi) * 70
    return { x = from.x - dx, y = from.y - sway, tilt = math.sin(p * math.pi * 2) * 4 }
end

function RideMath.canSkip(t: number): boolean
    return t >= RideMath.SKIP_AFTER
end

-- Cat de inchis e ecranul la momentul t: 0 pana in ultima bucata, apoi creste spre 1, ca schimbarea de loc sa se
-- intample pe negru, nu in mijlocul apei.
function RideMath.fade(t: number, vessel: string?): number
    local left = RideMath.secondsOf(vessel) - t
    if left >= RideMath.FADE then
        return 0
    end
    return math.clamp(1 - left / RideMath.FADE, 0, 1)
end

function RideMath.done(t: number, vessel: string?): boolean
    return t >= RideMath.secondsOf(vessel)
end

return RideMath
