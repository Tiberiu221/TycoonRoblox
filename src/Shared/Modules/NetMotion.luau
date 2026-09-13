--!strict
-- Cum se misca o plasa pe apa [F2, finisaj]. Modul PUR: primeste timpul, nu-l citeste; nu stie
-- nimic despre Roblox. Aceeasi idee ca la CatchFloat (plutirea bunului) si HandMath (traseul
-- angajatului) -- miscarea sta intr-un loc reglabil si testabil, nu imprastiata prin controller.
--
-- Doua miscari suprapuse:
--   * leganarea: plasa pluteste, deci nu sta niciodata perfect nemiscata. Faza vine din indexul
--     platformei, altfel toate plasele de pe mal s-ar misca la unison si s-ar vedea trucul.
--   * tresarirea: la prindere, plasa e trasa in jos de greutate si revine. Un singur impuls
--     sin(pi*k), deci porneste din 0 si se INTOARCE exact in 0 -- fara salt la sfarsit.
-- O plasa plina se leagana mai incet si mai putin: se vede ca e grea inainte sa citesti "FULL".

local NetMotion = {}

local BOB_AMP = 3.0 -- px
local BOB_PERIOD = 2.4 -- secunde
local BOB_AMP_FULL = 1.5
local BOB_PERIOD_FULL = 3.4

local TUG_SECONDS = 0.28
local TUG_DIP = 5.0 -- px in jos, la varf
local TUG_SCALE = 0.07 -- +7% la varf

NetMotion.BOB_AMP = BOB_AMP
NetMotion.TUG_SECONDS = TUG_SECONDS

-- Faza legaranii pentru platforma cu indexul dat: numere iraționale mici, ca doua plase vecine
-- sa nu cada niciodata in acelasi ritm.
function NetMotion.phaseFor(padIndex: number): number
    return (padIndex * 0.73) % (2 * math.pi)
end

-- Decalajul pe verticala (px, pozitiv = in jos) si scara plasei la momentul `now`.
-- `tugAt` = cand a prins ultima data (timp absolut de server), sau nil.
function NetMotion.sample(
    now: number,
    phase: number,
    full: boolean,
    tugAt: number?
): (number, number)
    local amp = if full then BOB_AMP_FULL else BOB_AMP
    local period = if full then BOB_PERIOD_FULL else BOB_PERIOD
    local dy = math.sin(now * (2 * math.pi) / period + phase) * amp
    local scale = 1.0

    if tugAt ~= nil then
        local t = now - tugAt
        if t >= 0 and t < TUG_SECONDS then
            local impulse = math.sin(math.pi * (t / TUG_SECONDS))
            dy += TUG_DIP * impulse
            scale += TUG_SCALE * impulse
        end
    end
    return dy, scale
end

return NetMotion
