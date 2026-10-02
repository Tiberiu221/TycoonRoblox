--!strict
-- [D62, pasul 3] DARURILE RAULUI: un butoi, o lada sau un bustean de aur trec pe rau, dincolo de plase; alergi pe punte
-- in dreptul lui si il scoti cu mana ta. Modul PUR.
--
-- De ce: dupa ce ai angajat cei cinci oameni, satul merge singur si nu mai ai NIMIC de facut cu mainile (auditul D62).
-- Darul e verbul activ de dupa automatizare: nu-l prind oamenii tai, e treaba ta. Daca il scapi, pleaca pe rau si atat:
-- n-ai avut nimic, nu pierzi nimic [P2].
--
-- Programul e DETERMINIST pe (samanta raului, fereastra de timp), ca RiverSim.schedule: serverul si clientul vad
-- acelasi dar, in acelasi loc, fara nimic de sincronizat -- ceasul e cel al serverului (GetServerTimeNow), samanta e cea
-- a raului (RiverService.BASE_SEED, trimisa deja clientului in configul raului).
--
-- Cat aduce: secunde din venitul tau de acum (cu un minim, ca in primul minut un butoi sa insemne un om angajat).
-- Media: 0.72*10 + 0.22*25 + 0.06*75 = 17.2 s de venit la fiecare 56 s, adica ~30% in plus pentru cine le prinde pe
-- toate si ~15% pentru cine prinde jumatate. E o estimare; preturile NU se schimba dupa ea (simulatorul o doar afiseaza).
local Prng = require(script and script.Parent.Prng or "./Prng")

local DriftMath = {}

export type Kind = { id: string, weight: number, seconds: number, min: number }
-- [D73] o bucata de punte de pe care se poate scoate un dar (coordonatele terenului, pe X)
export type Span = { x0: number, x1: number }
export type Gift = {
    id: number, -- fereastra de timp: un dar pe fereastra, deci si identitatea lui
    kind: string,
    enterAt: number, -- cand intra pe harta, la x = ENTER_X (timpul serverului)
    speed: number, -- px/s, spre aval (dreapta)
    y: number,
}

DriftMath.WINDOW = 56 -- secunde; un dar pe fereastra
DriftMath.KINDS = {
    { id = "barrel", weight = 72, seconds = 10, min = 6 },
    { id = "crate", weight = 22, seconds = 25, min = 15 },
    { id = "golden", weight = 6, seconds = 75, min = 40 },
} :: { Kind }
DriftMath.byId = {} :: { [string]: Kind }
for _, k in DriftMath.KINDS do
    DriftMath.byId[k.id] = k
end

-- Pe unde trece: curentul din larg, dincolo de ultima banda de plase (588) si de curentul bustenilor (552), sub cel mai
-- de jos punct al malului de nord (488, RiverConfig.SHORE_FAR): un desen de 32 px inaltime ramane cu totul in apa.
DriftMath.Y = 520
DriftMath.ENTER_X = -60
-- [D73] dincolo de marginea lumii (RiverConfig.WORLD_WIDTH, 5520): darul trece pe la toate cartierele. Pana acum iesea la
-- 2940, in mijlocul Morii, si disparea sub ochii tai; din Era 2 nimeni nu mai prindea niciunul.
DriftMath.EXIT_X = 5580
DriftMath.SPEED_MIN = 62
DriftMath.SPEED_MAX = 78
DriftMath.START_JITTER = 14 -- darul nu intra fix la inceputul ferestrei: fara metronom
-- De unde se poate scoate: cat e in dreptul puntii (TycoonConfig.DECK: x 240..1560), cu o mica marja. Asta e puntea din
-- The Landing; [D73] puntea fiecarui cartier deschis se socoteste la fel (`reaches`).
DriftMath.REACH_X0 = 200
DriftMath.REACH_X1 = 1600
DriftMath.REACH_MARGIN = 40
DriftMath.REACH = 90 -- cat de aproape in X trebuie sa fii (clientul; serverul nu stie unde stai in sat)
DriftMath.GRACE = 1.5 -- secunde de ingaduinta la capetele ferestrei de prins (drumul cererii pana la server)

function DriftMath.windowOf(now: number): number
    return math.floor(now / DriftMath.WINDOW)
end

local function pickKind(roll: number): string
    local total = 0
    for _, k in DriftMath.KINDS do
        total += k.weight
    end
    local target = math.clamp(roll, 0, 0.9999999) * total
    local acc = 0
    for _, k in DriftMath.KINDS do
        acc += k.weight
        if target < acc then
            return k.id
        end
    end
    return DriftMath.KINDS[1].id
end

-- Darul ferestrei `window`. Aceeasi samanta si aceeasi fereastra dau mereu acelasi dar.
function DriftMath.giftFor(seed: number, window: number): Gift
    local rng = Prng.new((seed * 7919 + window * 104729) % 4294967296)
    rng:nextU32()
    local kind = pickKind(rng:nextNumber())
    local jitter = rng:nextNumber() * DriftMath.START_JITTER
    local speed = DriftMath.SPEED_MIN
        + rng:nextNumber() * (DriftMath.SPEED_MAX - DriftMath.SPEED_MIN)
    return {
        id = window,
        kind = kind,
        enterAt = window * DriftMath.WINDOW + jitter,
        speed = speed,
        y = DriftMath.Y,
    }
end

-- Unde e darul la momentul `now`; nil cat inca n-a intrat sau dupa ce a iesit de pe harta.
function DriftMath.xAt(gift: Gift, now: number): number?
    local x = DriftMath.ENTER_X + (now - gift.enterAt) * gift.speed
    if now < gift.enterAt or x > DriftMath.EXIT_X then
        return nil
    end
    return x
end

-- [D73] Bucatile de punte de pe care se poate scoate un dar: puntea fiecarui cartier deschis, cu marja. `decks`: puntile
-- cartierelor, cu era lor (TycoonConfig.deckSpans); `isOpen(era)`: cartierul e deschis (clopotul erei dinainte e tras).
function DriftMath.reaches(
    decks: { { era: number, x0: number, x1: number } },
    isOpen: (number) -> boolean
): { Span }
    local out: { Span } = {}
    for _, d in decks do
        if isOpen(d.era) then
            table.insert(out, {
                x0 = d.x0 - DriftMath.REACH_MARGIN,
                x1 = d.x1 + DriftMath.REACH_MARGIN,
            })
        end
    end
    return out
end

-- Intre ce momente se poate scoate: cat trece prin dreptul puntii (fara `span`, puntea din The Landing).
function DriftMath.reachWindow(gift: Gift, span: Span?): (number, number)
    local x0 = if span ~= nil then span.x0 else DriftMath.REACH_X0
    local x1 = if span ~= nil then span.x1 else DriftMath.REACH_X1
    local from = gift.enterAt + (x0 - DriftMath.ENTER_X) / gift.speed
    local to = gift.enterAt + (x1 - DriftMath.ENTER_X) / gift.speed
    return from, to
end

-- Serverul: se poate scoate darul asta ACUM, din dreptul uneia dintre punti (fara `spans`, puntea din The Landing)?
-- (cu ingaduinta pentru drumul cererii)
function DriftMath.canGrab(gift: Gift, now: number, spans: { Span }?): boolean
    for _, span in spans or { { x0 = DriftMath.REACH_X0, x1 = DriftMath.REACH_X1 } } do
        local from, to = DriftMath.reachWindow(gift, span)
        if now >= from - DriftMath.GRACE and now <= to + DriftMath.GRACE then
            return true
        end
    end
    return false
end

-- Darurile care pot fi pe harta la `now`: al ferestrei curente si, cat inca mai pluteste, al celei dinainte.
function DriftMath.activeAt(seed: number, now: number): { Gift }
    local out: { Gift } = {}
    local current = DriftMath.windowOf(now)
    for window = current - 1, current do
        local gift = DriftMath.giftFor(seed, window)
        if DriftMath.xAt(gift, now) ~= nil then
            table.insert(out, gift)
        end
    end
    return out
end

-- Cate monede aduce: secunde din venitul de acum, cu minimul felului. Intreg, ca suma care zboara spre contor sa fie
-- exact suma primita [D40].
function DriftMath.reward(kind: string, incomePerSec: number): number
    local def = DriftMath.byId[kind]
    if def == nil then
        return 0
    end
    local income = if incomePerSec == incomePerSec and incomePerSec > 0 then incomePerSec else 0
    return math.max(def.min, math.floor(income * def.seconds))
end

-- Cat adauga, in medie, la venit cine prinde o parte `share` (0..1) din daruri: fractie din venit.
function DriftMath.expectedBonus(share: number): number
    local total, seconds = 0, 0
    for _, k in DriftMath.KINDS do
        total += k.weight
        seconds += k.weight * k.seconds
    end
    return math.clamp(share, 0, 1) * (seconds / total) / DriftMath.WINDOW
end

return DriftMath
