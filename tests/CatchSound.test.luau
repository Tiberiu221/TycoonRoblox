-- [D72] Ce se aude cand prind plasele: stropi rari si mai incet cand malul e plin, clinchetul gasirilor rar in timp.
local frktest = require("@frktest/frktest")
local test = frktest.test
local check = frktest.assert.check

local CatchSound = require("../src/Shared/Modules/CatchSound")
local RiverConfig = require("../src/Shared/Config/RiverConfig")

local TIERS = RiverConfig.TIERS :: { any }

-- zaruri deterministe in [0, 1)
local function dice(seed: number): () -> number
    local x = seed
    return function()
        x = (x * 1103515245 + 12345) % 2147483648
        return x / 2147483648
    end
end

-- treapta unei gasiri dupa ponderi, din zarul `r`
local function tierOf(r: number): string
    local total = 0
    for _, t in TIERS do
        total += t.weight
    end
    local acc = 0
    for _, t in TIERS do
        acc += t.weight / total
        if r < acc then
            return t.id
        end
    end
    return TIERS[#TIERS].id
end

-- `nets` plase, fiecare cu `perNet` prinderi pe secunda, timp de `seconds`; `findEvery`: a cata prindere e o gasire
-- (0 = niciuna). Intoarce cati stropi, cate clinchete si taria ultimului strop.
local function play(nets: number, perNet: number, seconds: number, away: number, findEvery: number)
    local s = CatchSound.new()
    local roll = dice(7)
    local splashes, chimes, lastGain = 0, 0, 0
    local catches = 0
    local events: { { at: number, pad: string } } = {}
    for n = 1, nets do
        local t = (n - 1) / (nets * perNet)
        while t < seconds do
            table.insert(events, { at = t, pad = `net{n}` })
            t += 1 / perNet
        end
    end
    table.sort(events, function(a, b)
        return a.at < b.at
    end)
    for _, e in events do
        catches += 1
        local find = if findEvery > 0 and catches % findEvery == 0 then tierOf(roll()) else nil
        local sound =
            CatchSound.onCatch(s, TIERS, e.pad, away, find, 1000 + e.at, roll(), roll(), roll())
        if sound.kind == "splash" then
            splashes += 1
            lastGain = sound.gain
        elseif sound.kind == "chime" then
            chimes += 1
        end
    end
    return splashes, chimes, lastGain
end

local function catchKind(
    s: CatchSound.State,
    pad: string,
    away: number,
    find: string?,
    at: number,
    roll3: number
)
    return CatchSound.onCatch(s, TIERS, pad, away, find, at, 0.5, 0.5, roll3).kind
end

return function()
    test.suite("CatchSound: stropii plaselor [D72]", function()
        test.case(
            "la inceput nu se schimba nimic: o plasa lenta se aude la fiecare prindere, tare",
            function()
                -- prima plasa, nivelul 1: o prindere la ~3 s
                local splashes, _, gain = play(1, 1 / 3, 60, 0, 0)
                check.equal(splashes, 20)
                check.is_true(gain >= 0.85 - 1e-9)
            end
        )

        test.case("doua-trei plase lente: se aude fiecare prindere", function()
            -- First, Second si Third Net la nivelul 1 (0,33 / 0,48 / 0,69 pe secunda), pe ceasul de 10 Hz al serverului
            local s = CatchSound.new()
            local roll = dice(11)
            local events: { { at: number, pad: string } } = {}
            for n, rate in { 0.33, 0.48, 0.69 } do
                local t = 0.37 * n
                while t < 300 do
                    table.insert(events, { at = math.floor(t * 10) / 10, pad = `net{n}` })
                    t += 1 / rate
                end
            end
            table.sort(events, function(a, b)
                return a.at < b.at
            end)
            local heard, sameTick, last = 0, 0, -1
            for _, e in events do
                local sound = CatchSound.onCatch(
                    s,
                    TIERS,
                    e.pad,
                    100,
                    nil,
                    1000 + e.at,
                    roll(),
                    roll(),
                    roll()
                )
                if sound.kind == "splash" then
                    heard += 1
                end
                if e.at == last then
                    sameTick += 1 -- doua prinderi in aceeasi bataie de ceas fac un singur strop
                end
                last = e.at
            end
            check.equal(heard, #events - sameTick)
        end)

        test.case(
            "o plasa rapida se aude cam o data la trei sferturi de secunda, dar se aude",
            function()
                local splashes = play(1, 12, 30, 0, 0)
                check.is_true(splashes <= 30 / (CatchSound.NET_GAP * 0.8) + 1)
                check.is_true(splashes >= 30 / (CatchSound.NET_GAP * 1.2) - 1)
            end
        )

        test.case(
            "finalul Erei 1 (cinci plase, ~51 pe secunda): cel mult doi stropi pe secunda",
            function()
                local splashes, _, gain = play(5, 10, 30, 0, 0)
                check.is_true(splashes <= 30 / (CatchSound.ANY_GAP * 0.8) + 1)
                check.is_true(splashes >= 20)
                -- mai incet decat pe un mal linistit, dar tot peste casa de marcat (0.3, fata de 0.7 al stropului) [D50]
                check.is_true(gain <= CatchSound.BUSY_GAIN + 1e-9)
                check.is_true(gain >= CatchSound.BUSY_GAIN * 0.85 - 1e-9)
                check.is_true(0.7 * gain > 0.3)
            end
        )

        test.case("departe de plase nu se aude niciun strop [D51]", function()
            local splashes = play(5, 10, 10, CatchSound.RANGE + 1, 0)
            check.equal(splashes, 0)
        end)

        test.case(
            "spre marginea razei stropul se stinge lin, iar clinchetul coboara lin spre jumatate",
            function()
                check.equal(CatchSound.splashGain(0, 0), 1)
                check.is_true(
                    CatchSound.splashGain(CatchSound.RANGE / 2, 0)
                        > CatchSound.splashGain(CatchSound.RANGE * 0.9, 0)
                )
                check.is_true(CatchSound.splashGain(CatchSound.RANGE - 1, 0) < 0.01)
                check.equal(CatchSound.splashGain(CatchSound.RANGE, 0), 0)
                check.equal(CatchSound.chimeGain(0), 1)
                check.is_true(
                    math.abs(CatchSound.chimeGain(CatchSound.RANGE - 1) - CatchSound.FAR_GAIN)
                        < 0.01
                )
                check.equal(CatchSound.chimeGain(CatchSound.RANGE), CatchSound.FAR_GAIN)
                check.equal(CatchSound.chimeGain(math.huge), CatchSound.FAR_GAIN)
            end
        )

        test.case("taria scade lin cu ritmul si nu coboara sub prag", function()
            local last = 2
            for rate = 0, 400, 5 do
                local g = CatchSound.splashGain(0, rate)
                check.is_true(g <= last + 1e-12)
                check.is_true(g >= CatchSound.BUSY_GAIN - 1e-12)
                last = g
            end
        end)
    end)

    test.suite("CatchSound: clinchetul gasirilor [D72]", function()
        test.case(
            "sansa clinchetului: la inceput orice gasire, apoi treptele de sus intai, ultima mereu",
            function()
                local function chance(rate: number, id: string): number
                    for i, t in TIERS do
                        if t.id == id then
                            return CatchSound.chimeChance(TIERS, rate, i)
                        end
                    end
                    error(id)
                end
                check.equal(chance(0, "common"), 1)
                check.equal(chance(0.2, "common"), 1)
                -- finalul Erei 1: ~2,5 gasiri pe secunda -> epic si legendary mereu, rare doar uneori, uncommon deloc
                check.equal(chance(2.5, "uncommon"), 0)
                check.is_true(chance(2.5, "rare") > 0 and chance(2.5, "rare") < 0.25)
                check.equal(chance(2.5, "epic"), 1)
                check.equal(chance(2.5, "legendary"), 1)
                -- finalul Erei 3: ~9,5 pe secunda -> rare deloc, epic foarte rar, legendary mereu
                check.equal(chance(9.5, "rare"), 0)
                check.is_true(chance(9.5, "epic") < 0.05)
                check.equal(chance(9.5, "legendary"), 1)
                check.equal(chance(1e9, TIERS[#TIERS].id), 1)
                check.equal(chance(1e9, "legendary"), 0)
                -- oricat de multe gasiri: cam un clinchet la FIND_EVERY secunde, nu mai mult
                local total = 0
                for _, t in TIERS do
                    total += t.weight
                end
                for _, rate in { 0.5, 1, 2.5, 6, 9.5, 20 } do
                    local expected = 0
                    for i, t in TIERS do
                        if i < #TIERS then
                            expected += rate * t.weight / total * CatchSound.chimeChance(
                                TIERS,
                                rate,
                                i
                            )
                        end
                    end
                    check.is_true(expected <= 1 / CatchSound.FIND_EVERY + 1e-9)
                    check.is_true(
                        expected
                            >= 1 / CatchSound.FIND_EVERY
                                - rate * TIERS[#TIERS].weight / total
                                - 1e-9
                    )
                end
            end
        )

        test.case("la inceput fiecare gasire suna", function()
            local s = CatchSound.new()
            for k = 1, 10 do
                local sound =
                    CatchSound.onCatch(s, TIERS, "net1", 0, "common", 1000 + 30 * k, 0.5, 0.5, 0)
                check.equal(sound.kind, "chime")
                check.equal(sound.gain, 1)
            end
        end)

        test.case(
            "finalul Erei 1, langa plase: un clinchet la cateva secunde, nu 2,5 pe secunda",
            function()
                local _, chimes = play(5, 10, 120, 0, 20)
                -- 300 de gasiri in doua minute; pana acum, 300 de clinchete
                check.is_true(chimes <= 120 / CatchSound.FIND_EVERY * 1.5)
                check.is_true(chimes >= 120 / CatchSound.FIND_EVERY * 0.5)
            end
        )

        test.case("finalul Erei 3 (~190 pe secunda): tot rar", function()
            local _, chimes = play(15, 12.7, 120, 0, 20)
            check.is_true(chimes <= 120 / CatchSound.FIND_EVERY * 1.5)
            check.is_true(chimes >= 120 / CatchSound.FIND_EVERY * 0.5)
        end)

        test.case(
            "gasirile de departe au bugetul lor, mai mic: clinchetul tine de ce vezi",
            function()
                local _, chimes = play(15, 12.7, 120, math.huge, 20)
                check.is_true(chimes <= 120 / CatchSound.FAR_EVERY * 1.6)
                check.is_true(chimes >= 2)
            end
        )

        test.case("o gasire de departe se aude mai incet; o prindere de departe, deloc", function()
            local s = CatchSound.new()
            local far = CatchSound.onCatch(s, TIERS, "net1", math.huge, "rare", 1000, 0.5, 0.5, 0)
            check.equal(far.kind, "chime")
            check.equal(far.gain, CatchSound.FAR_GAIN)
            check.equal(catchKind(s, "net1", math.huge, nil, 1010, 0), "none")
        end)

        test.case(
            "o gasire care nu suna e tot o prindere: langa plasa se aude stropul ei",
            function()
                local s = CatchSound.new()
                s.nearFinds = 50 -- un mal plin de gasiri: „common” nu mai suna
                check.equal(catchKind(s, "net1", 0, "common", 1000, 0), "splash")
            end
        )

        test.case(
            "treapta cea mai inalta suna mereu, oricat de multe gasiri ar veni si oricat de des",
            function()
                local s = CatchSound.new()
                s.nearFinds, s.farFinds = 1e6, 1e6
                local top = TIERS[#TIERS].id
                check.equal(catchKind(s, "net1", 0, top, 1000, 0.99), "chime")
                check.equal(catchKind(s, "net1", 0, top, 1000.1, 0.99), "chime")
                check.equal(catchKind(s, "net2", math.huge, top, 1000.2, 0.99), "chime")
            end
        )

        test.case(
            "o treapta mai rara trece peste pauza dintre clinchete; una mai comuna, nu",
            function()
                local s = CatchSound.new()
                check.equal(catchKind(s, "net1", 0, "epic", 1000, 0), "chime")
                check.is_true(catchKind(s, "net1", 0, "common", 1000.1, 0) ~= "chime")
                check.equal(catchKind(s, "net2", 0, "mythic", 1000.2, 0), "chime")
                check.is_true(catchKind(s, "net3", 0, "epic", 1000.3, 0) ~= "chime")
            end
        )

        test.case("finalul Erei 1: fiecare gasire mythic din raza suna", function()
            local s = CatchSound.new()
            local roll = dice(5)
            local mythic, heard = 0, 0
            for k = 0, 50 * 600 do
                local t = 1000 + math.floor(k / 5) / 10 -- ~50 pe secunda, pe ceasul de 10 Hz
                local find = if roll() < 0.05 then tierOf(roll()) else nil
                local sound =
                    CatchSound.onCatch(s, TIERS, `net{k % 5}`, 0, find, t, roll(), roll(), roll())
                if find == "mythic" then
                    mythic += 1
                    if sound.kind == "chime" then
                        heard += 1
                    end
                end
            end
            check.is_true(mythic > 0)
            check.equal(heard, mythic)
        end)
    end)

    test.suite("CatchSound: ceasul [D72]", function()
        test.case("un ceas care merge inapoi sau nu e un numar nu strica nimic", function()
            local s = CatchSound.new()
            CatchSound.onCatch(s, TIERS, "net1", 0, nil, 1000, 0.5, 0.5, 0)
            local back = CatchSound.onCatch(s, TIERS, "net1", 0, nil, 500, 0.5, 0.5, 0)
            check.is_true(back.gain == back.gain)
            check.is_true(s.rate == s.rate and s.rate < 10)
            check.equal(catchKind(s, "net1", 0, nil, 0 / 0, 0), "none")
            check.equal(catchKind(s, "net1", 0, nil, math.huge, 0), "none")
        end)

        test.case(
            "dupa o pauza lunga, malul se linisteste si stropul revine la taria intreaga",
            function()
                local s = CatchSound.new()
                for k = 0, 400 do
                    CatchSound.onCatch(s, TIERS, `net{k % 5}`, 0, nil, 1000 + k * 0.02, 0.5, 0.5, 0)
                end
                check.is_true(s.rate > 10)
                local later = CatchSound.onCatch(s, TIERS, "net1", 0, nil, 1100, 0.5, 0.5, 0)
                check.equal(later.kind, "splash")
                check.is_true(later.gain >= 0.85 * 0.925 - 1e-9)
            end
        )
    end)
end
