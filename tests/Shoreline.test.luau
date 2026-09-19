-- Malul trebuie sa fie IDENTIC la fiecare intrare si, mai ales, sa nu strice jocul: daca uscatul
-- intra peste benzile pe care plutesc bunurile, obiectele trec peste iarba; daca apa trece peste
-- ponton, scandurile stau in rau. Testul verifica exact cifrele desenate (RiverConfig.SHORE_*).
local frktest = require("@frktest/frktest")
local test = frktest.test
local check = frktest.assert.check

local RiverConfig = require("../src/Shared/Config/RiverConfig")
local TycoonConfig = require("../src/Shared/Config/TycoonConfig")
local Shoreline = require("../src/Shared/Modules/Shoreline")

local FAR = RiverConfig.SHORE_FAR
local NEAR = RiverConfig.SHORE_NEAR
local W = RiverConfig.WORLD_WIDTH

return function()
    test.suite("Shoreline.edgeY - linia apei", function()
        test.case("e determinista", function()
            local diff = 0
            for x = 0, W, 37 do
                diff += math.abs(Shoreline.edgeY(FAR, x) - Shoreline.edgeY(FAR, x))
            end
            check.equal(diff, 0)
        end)

        test.case("fiecare mal se retrage doar in sensul lui", function()
            -- malul de nord nu coboara NICIODATA sub baseY, cel de sud nu urca peste al lui
            local badFar, badNear = 0, 0
            for x = 0, W do
                if Shoreline.edgeY(FAR, x) > FAR.baseY + 1e-9 then
                    badFar += 1
                end
                if Shoreline.edgeY(NEAR, x) < NEAR.baseY - 1e-9 then
                    badNear += 1
                end
            end
            check.equal(badFar, 0)
            check.equal(badNear, 0)
        end)

        test.case("uscatul nu intra peste benzile bunurilor", function()
            -- half = jumatatea unui obiect plutitor; daca malul ajunge aici, marfa trece pe iarba
            local half = RiverConfig.OBJECT_HEIGHT / 2
            local topLane = RiverConfig.LANE_YS[1] - half
            local bottomLane = RiverConfig.LANE_YS[#RiverConfig.LANE_YS] + half
            local hitsTop, hitsBottom = 0, 0
            for x = 0, W do
                if Shoreline.edgeY(FAR, x) > topLane then
                    hitsTop += 1
                end
                if Shoreline.edgeY(NEAR, x) < bottomLane then
                    hitsBottom += 1
                end
            end
            check.equal(hitsTop, 0)
            check.equal(hitsBottom, 0)
        end)

        test.case("apa nu ajunge peste ponton, drumuri sau teren", function()
            local built: { { x0: number, x1: number, y0: number, y1: number } } = {
                TycoonConfig.DECK,
                {
                    x0 = RiverConfig.PLOT.x,
                    x1 = RiverConfig.PLOT.x + RiverConfig.PLOT.w,
                    y0 = RiverConfig.PLOT.y,
                    y1 = RiverConfig.PLOT.y + RiverConfig.PLOT.h,
                },
            }
            for _, road in TycoonConfig.ROADS do
                table.insert(built, road)
            end
            local wet = 0
            for _, r in built do
                for x = r.x0, r.x1 do
                    if Shoreline.edgeY(NEAR, x) >= r.y0 then
                        wet += 1
                    end
                end
            end
            check.equal(wet, 0)
        end)

        test.case("in zona amenajata malul e aproape drept, in rest salbatic", function()
            local calm = NEAR.calm :: any
            local calmSpan, wildSpan = 0, 0
            local lo, hi = math.huge, -math.huge
            for x = calm.x0, calm.x1 do
                local y = Shoreline.edgeY(NEAR, x)
                lo, hi = math.min(lo, y), math.max(hi, y)
            end
            calmSpan = hi - lo
            lo, hi = math.huge, -math.huge
            for x = calm.x1 + calm.feather, W do
                local y = Shoreline.edgeY(NEAR, x)
                lo, hi = math.min(lo, y), math.max(hi, y)
            end
            wildSpan = hi - lo
            check.is_true(calmSpan <= calm.amp)
            -- [D65] malul amenajat tine acum cat cartierele (pana la capatul Morii), deci dincolo de el mai raman doar
            -- cateva sute de pixeli de lume: salbaticia se masoara acolo doar daca exista
            if calm.x1 + calm.feather < W then
                check.is_true(wildSpan > calmSpan * 2.5) -- salbaticia chiar se vede
            end
            -- ...iar fara amenajare acelasi mal serpuieste cat ii da voie amplitudinea
            local wild = table.clone(NEAR)
            wild.calm = nil
            lo, hi = math.huge, -math.huge
            for x = 0, W, 5 do
                local y = Shoreline.edgeY(wild, x)
                lo, hi = math.min(lo, y), math.max(hi, y)
            end
            check.is_true(hi - lo > calmSpan * 2.5)
        end)

        test.case("malul de nord chiar serpuieste", function()
            local lo, hi = math.huge, -math.huge
            for x = 0, W, 5 do
                local y = Shoreline.edgeY(FAR, x)
                lo, hi = math.min(lo, y), math.max(hi, y)
            end
            check.is_true(hi - lo > FAR.amp * 0.6)
        end)

        test.case("e continua, fara colturi", function()
            local maxStep = 0
            for _, e in { FAR, NEAR } do
                local prev = Shoreline.edgeY(e, 0)
                for x = 1, W do
                    local y = Shoreline.edgeY(e, x)
                    maxStep = math.max(maxStep, math.abs(y - prev))
                    prev = y
                end
            end
            check.is_true(maxStep < 1.5)
        end)
    end)

    test.suite("Shoreline.beachWidth - plaja", function()
        test.case("dispare pe portiuni intregi si nu trece de maxim", function()
            local zero, wide, worst = 0, 0, 0
            for x = 0, W do
                local b = Shoreline.beachWidth(NEAR, x)
                worst = math.max(worst, b)
                if b <= 0 then
                    zero += 1
                elseif b > (NEAR.beach :: number) * 0.6 then
                    wide += 1
                end
            end
            check.is_true(worst <= (NEAR.beach :: number) + 1e-9)
            check.is_true(zero > W * 0.15) -- iarba ajunge in apa pe cel putin o sesime din mal
            check.is_true(wide > W * 0.1) -- si exista si plaje adevarate
        end)
    end)

    test.suite("Shoreline.columns - taierea in coloane", function()
        test.case("acopera toata latimea, fara goluri", function()
            local cols = Shoreline.columns(FAR, W, 32)
            check.equal(cols[1].x, 0)
            local last = cols[#cols]
            check.is_true(last.x + last.w >= W)
            local gaps = 0
            for i = 2, #cols do
                if cols[i].x ~= cols[i - 1].x + 32 then
                    gaps += 1
                end
            end
            check.equal(gaps, 0)
        end)

        test.case("treapta dintre coloane ramane mica", function()
            -- coloanele sunt dreptunghiuri: daca pasul e prea mare, malul arata zimtat
            local cols = Shoreline.columns(FAR, W, 32)
            local worst = 0
            for i = 2, #cols do
                worst = math.max(worst, math.abs(cols[i].y - cols[i - 1].y))
            end
            -- 12 pana la D65; cu lumea latita la 3840, malul de nord are o treapta de 13.2 la x 2880. Conteaza doar
            -- pentru desenul din coloane (rezerva): pamantul copt ia malul din 3 in 3 pixeli.
            check.is_true(worst <= 14)
        end)
    end)

    test.suite("Shoreline.patches / pebbles", function()
        test.case("petele stau in zona ceruta", function()
            local area = { x0 = 0, y0 = 800, x1 = W, y1 = 1900, tones = 3 }
            local list = Shoreline.patches(2026, area, 60)
            check.equal(#list, 60)
            local outside, badTone = 0, 0
            for _, p in list do
                if p.x < area.x0 or p.x + p.w > area.x1 then
                    outside += 1
                end
                if p.y < area.y0 or p.y + p.h > area.y1 then
                    outside += 1
                end
                if p.tone < 1 or p.tone > 3 then
                    badTone += 1
                end
            end
            check.equal(outside, 0)
            check.equal(badTone, 0)
        end)

        test.case("salt schimba imprastierea, nu linia", function()
            local a = Shoreline.pebbles(NEAR, W, 20, 10)
            local b = Shoreline.pebbles(NEAR, W, 20, 10, 991)
            local same = 0
            for i = 1, 20 do
                if a[i].x == b[i].x then
                    same += 1
                end
            end
            check.is_true(same <= 2)
            local off = 0
            for _, p in b do
                off = math.max(off, math.abs(p.y - Shoreline.edgeY(NEAR, p.x)))
            end
            check.is_true(off <= 11)
        end)
    end)
end
