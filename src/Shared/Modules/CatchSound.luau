--!strict
-- [D72] CE SE AUDE CAND PRIND PLASELE. Modul PUR: primeste ceasul si zarurile, nu le ia singur.
--
-- Owner-ul, 2026-10-02: „uita-te si la sunete ca acele plase pot deveni enervante cand sunt prea rapide (se poate face
-- ceva?)”. Cifrele din simulator: la finalul Erei 1 o plasa prinde 7–16 bucati pe secunda, cele cinci ~51; la finalul
-- Erei 3 toate plasele ~170–190. Pana acum fiecare prindere din apropiere cerea un strop (cel mult unul la 0,12 s, adica
-- ~5 pe secunda cu ceasul de 10 Hz al serverului, fara pauza, mereu acelasi), iar fiecare gasire (5% din prinderi) un
-- clinchet auzit de oriunde, fara nicio limita: ~2,5 pe secunda la finalul Erei 1, ~8 la finalul Erei 3.
--
-- Regulile, ca pasii din joc:
--   * STROPII: cat malul e linistit (o prindere la cateva secunde, inceputul jocului), se aude fiecare prindere, ca pana
--     acum. Cand se indesesc, o plasa se aude cel mult o data la ~0,75 s, toate la un loc cel mult de ~2 ori pe secunda,
--     iar fiecare strop e putin altfel (inaltime si tarie) si ceva mai incet (pana la 70%), dar tot peste casa de marcat
--     (amestecul D50: prinderea ramane sunetul principal). Spre marginea razei stropul se stinge lin, nu se taie.
--   * CLINCHETUL GASIRILOR ramane rar IN TIMP, nu doar dupa treapta. Gasirile din raza ta isi au bugetul lor, cam un
--     clinchet la `FIND_EVERY` secunde, impartit de sus in jos: intai treptele cele mai rare, apoi, cat mai ramane loc,
--     cele de sub ele (treapta de la granita suna doar uneori). Gasirile de departe au un buget mai mic si se aud mai
--     incet: un clinchet tine de ce vezi. La inceput suna orice gasire, ca pana acum. O treapta mai rara decat ultimul
--     clinchet trece peste pauza dintre clinchete, iar cea mai inalta suna mereu. O gasire care nu suna e tot o prindere:
--     langa plasa se aude stropul ei.
-- Nimic nu se ascunde [D43]: fiecare prindere isi are in continuare textul plutitor pe plasa (NetController); sunetul
-- doar nu le mai numara pe toate.
local CatchSound = {}

CatchSound.RANGE = 420 -- [D51] stropii se aud doar langa plasa care a prins, tot mai incet spre margine
CatchSound.MERGE_GAP = 0.08 -- secunde, sub o bataie de ceas a serverului (0,1 s): prinderile din aceeasi bataie fac un strop
CatchSound.NET_GAP = 0.75 -- secunde intre doi stropi ai aceleiasi plase (cu +-20% intamplator, ca sa nu bata ca un ceas)
CatchSound.ANY_GAP = 0.5 -- secunde intre doi stropi oarecare, doar cand malul e aglomerat (tot +-20%)
CatchSound.CALM_RATE = 3 -- prinderi pe secunda in raza pana la care malul e linistit: fiecare strop, la taria intreaga
CatchSound.BUSY_GAIN = 0.7 -- cel mai incet strop, cand malul e plin de plase rapide (0.7 x 0.7 = 0.49, peste casa de 0.3)
CatchSound.FIND_EVERY = 4 -- secunde: cam cat de des se aude clinchetul unei gasiri din raza ta
CatchSound.FAR_EVERY = 12 -- secunde: si al unei gasiri de departe (alt cartier, alta plasa)
CatchSound.FIND_GAP = 0.8 -- secunde intre doua clinchete, afara de o treapta mai rara decat ultimul
CatchSound.FAR_GAIN = 0.5 -- clinchetul unei gasiri de departe se aude, doar mai incet
CatchSound.HALF_LIFE = 3 -- secunde: cat de repede uita ritmul (o medie care se stinge la jumatate in atat)

-- `netNext`: cand poate suna din nou fiecare plasa; `rate`: prinderile din raza, pe secunda; `nearFinds` / `farFinds`:
-- gasirile din raza si de departe, pe secunda (medii care se sting); `at`: cand s-au stins ultima data; `chimeTier`:
-- treapta ultimului clinchet.
export type State = {
    netNext: { [string]: number },
    anyNext: number,
    chimeNext: number,
    chimeTier: number,
    rate: number,
    nearFinds: number,
    farFinds: number,
    at: number,
}

export type Kind = "splash" | "chime" | "none"
-- Ce sa se auda; `gain` 0..1 peste volumul sunetului, `pitch` peste inaltimea lui.
export type Sound = { kind: Kind, gain: number, pitch: number }

-- `tiers`: treptele gasirilor in ordine, de la cea mai des la cea mai rara, cu ponderea fiecareia (RiverConfig.TIERS).
export type Tier = { id: string, weight: number }

local SILENT: Sound = { kind = "none" :: Kind, gain = 0, pitch = 1 }
local LN2 = math.log(2)

function CatchSound.new(): State
    return {
        netNext = {},
        anyNext = -math.huge,
        chimeNext = -math.huge,
        chimeTier = 0,
        rate = 0,
        nearFinds = 0,
        farFinds = 0,
        at = -math.huge,
    }
end

local function finite(x: number): boolean
    return x == x and x > -math.huge and x < math.huge
end

-- Mediile se sting de la ultima prindere pana acum. Un ceas care merge inapoi nu le umfla.
local function decay(s: State, now: number)
    if finite(s.at) and now > s.at then
        local k = 0.5 ^ ((now - s.at) / CatchSound.HALF_LIFE)
        s.rate *= k
        s.nearFinds *= k
        s.farFinds *= k
    end
    if not finite(s.at) or now > s.at then
        s.at = now
    end
end

-- Fiecare prindere adauga ln2/HALF_LIFE: cu λ prinderi pe secunda, media se asaza pe λ.
local function bump(x: number): number
    return x + LN2 / CatchSound.HALF_LIFE
end

-- Cat de departe e plasa, ca fractie din raza (0 langa ea, 1 la margine si dincolo).
local function edge(away: number): number
    return math.clamp(away / CatchSound.RANGE, 0, 1)
end

-- Taria unui strop la distanta `away` de plasa, cu ritmul din raza `rate`: se stinge lin spre marginea razei.
function CatchSound.splashGain(away: number, rate: number): number
    local e = edge(away)
    local near = 1 - e * e
    local busy = if rate <= CatchSound.CALM_RATE
        then 1
        else math.max(CatchSound.BUSY_GAIN, math.sqrt(CatchSound.CALM_RATE / rate))
    return near * busy
end

-- Taria unui clinchet: intreaga langa plasa, FAR_GAIN de la marginea razei incolo, lin intre ele.
function CatchSound.chimeGain(away: number): number
    local e = edge(away)
    return 1 - (1 - CatchSound.FAR_GAIN) * e * e
end

-- Cu ce sansa suna o gasire de treapta `index` (in `tiers`), cand vin `findRate` gasiri pe secunda si bugetul e de un
-- clinchet la `every` secunde. Clinchetele se impart de sus in jos: treptele de deasupra iau intai, cea de la granita ia
-- ce a mai ramas (o sansa intre 0 si 1), cele de dedesubt nimic. Ultima treapta suna mereu.
function CatchSound.chimeChance(
    tiers: { Tier },
    findRate: number,
    index: number,
    every: number?
): number
    local total = 0
    for _, t in tiers do
        total += t.weight
    end
    if index >= #tiers or total <= 0 or not finite(findRate) or findRate <= 0 then
        return 1
    end
    local above = 0
    for i = index + 1, #tiers do
        above += tiers[i].weight
    end
    local budget = 1 / (every or CatchSound.FIND_EVERY)
    local aboveRate = findRate * above / total
    local ownRate = findRate * (tiers[index] or { weight = 0 }).weight / total
    if aboveRate >= budget then
        return 0
    end
    if ownRate <= budget - aboveRate then
        return 1
    end
    return (budget - aboveRate) / ownRate
end

local function tierIndex(tiers: { Tier }, id: string?): number?
    for i, t in tiers do
        if t.id == id then
            return i
        end
    end
    return nil
end

-- Un strop, daca plasa si malul il lasa. `roll1`, `roll2` in [0, 1): inaltimea, taria si pauza pana la urmatorul.
local function splash(
    s: State,
    padId: string,
    away: number,
    now: number,
    roll1: number,
    roll2: number
): Sound
    if away > CatchSound.RANGE then
        return SILENT
    end
    if now < (s.netNext[padId] or -math.huge) or now < s.anyNext then
        return SILENT
    end
    s.netNext[padId] = now + CatchSound.NET_GAP * (0.8 + 0.4 * roll1)
    -- pauza comuna doar cand malul e aglomerat: cu doua-trei plase lente se aude fiecare prindere
    local anyGap = if s.rate > CatchSound.CALM_RATE
        then CatchSound.ANY_GAP * (0.8 + 0.4 * roll2)
        else CatchSound.MERGE_GAP
    s.anyNext = now + anyGap
    local gain = CatchSound.splashGain(away, s.rate) * (0.85 + 0.15 * roll2)
    return { kind = "splash" :: Kind, gain = gain, pitch = 0.92 + 0.16 * roll1 }
end

-- O prindere a plasei `padId`, la distanta `away` (unitatile terenului; math.huge fara pozitie). `find`: treapta gasirii,
-- daca e una (nil pentru o prindere obisnuita). `roll1..3` in [0, 1). Schimba `s` si spune ce sa se auda.
function CatchSound.onCatch(
    s: State,
    tiers: { Tier },
    padId: string,
    away: number,
    find: string?,
    now: number,
    roll1: number,
    roll2: number,
    roll3: number
): Sound
    if not finite(now) then
        return SILENT
    end
    decay(s, now)
    local near = away <= CatchSound.RANGE
    if near then
        s.rate = bump(s.rate)
    end
    if find ~= nil then
        local index = tierIndex(tiers, find) or 1
        -- ritmul de dinainte de gasirea asta: o gasire rara nu-si scade singura sansa
        local chance = if near
            then CatchSound.chimeChance(tiers, s.nearFinds, index, CatchSound.FIND_EVERY)
            else CatchSound.chimeChance(tiers, s.farFinds, index, CatchSound.FAR_EVERY)
        if near then
            s.nearFinds = bump(s.nearFinds)
        else
            s.farFinds = bump(s.farFinds)
        end
        local free = now >= s.chimeNext or index > s.chimeTier or index >= #tiers
        if roll3 < chance and free then
            s.chimeNext = now + CatchSound.FIND_GAP
            s.chimeTier = index
            return { kind = "chime" :: Kind, gain = CatchSound.chimeGain(away), pitch = 1 }
        end
    end
    return splash(s, padId, away, now, roll1, roll2)
end

return CatchSound
