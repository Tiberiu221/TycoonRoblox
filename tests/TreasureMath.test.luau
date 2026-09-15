-- [D59] Ce aduce raul: te asteapta, nu pleaca, cel mult trei. Testele apara exact promisiunile scrise pe ecran si in
-- bilete [D40]: nimic nu expira, plafonul e trei, ceasul sta cat pontonul e plin, primul e mereu sticla.
local frktest = require("@frktest/frktest")
local test = frktest.test
local check = frktest.assert.check

local TreasureConfig = require("../src/Shared/Config/TreasureConfig")
local TreasureMath = require("../src/Shared/Modules/TreasureMath")

local function fresh(): TreasureMath.State
    return { started = false, waiting = {}, nextAt = 0, seed = 42, total = 0, notes = 0 }
end

return function()
    test.suite("TreasureMath - ceasul raului", function()
        test.case("pana la primul peste raul nu aduce nimic", function()
            local st = fresh()
            check.equal(#TreasureMath.advance(st, 1e9), 0)
            check.equal(#st.waiting, 0)
        end)

        test.case("primul vine la FIRST_DELAY dupa primul peste si e o sticla", function()
            local st = fresh()
            check.is_true(TreasureMath.start(st, 1000))
            check.is_false(TreasureMath.start(st, 2000)) -- a doua oara nu mai reporneste nimic
            check.equal(#TreasureMath.advance(st, 1000 + TreasureConfig.FIRST_DELAY - 1), 0)
            local arrived = TreasureMath.advance(st, 1000 + TreasureConfig.FIRST_DELAY)
            check.equal(#arrived, 1)
            check.equal(arrived[1], TreasureConfig.FIRST_KIND)
        end)

        test.case(
            "cat lipsesti se aduna cel mult trei, iar ceasul sta cat pontonul e plin",
            function()
                local st = fresh()
                TreasureMath.start(st, 0)
                local arrived = TreasureMath.advance(st, 10 * 24 * 3600) -- zece zile
                check.equal(#arrived, TreasureConfig.MAX_WAITING)
                check.equal(#st.waiting, TreasureConfig.MAX_WAITING)
                check.equal(st.nextAt, 0)
                check.equal(#TreasureMath.advance(st, 20 * 24 * 3600), 0)
            end
        )

        test.case("scoti unul: ceasul porneste de acum, in interval, nu din trecut", function()
            local st = fresh()
            TreasureMath.start(st, 0)
            TreasureMath.advance(st, 1e7)
            local now = 1e7 + 5
            local kind = TreasureMath.take(st, now)
            check.not_nil(kind)
            check.equal(#st.waiting, TreasureConfig.MAX_WAITING - 1)
            check.is_true(st.nextAt >= now + TreasureConfig.INTERVAL_MIN)
            check.is_true(st.nextAt <= now + TreasureConfig.INTERVAL_MAX)
            check.equal(#TreasureMath.advance(st, now), 0) -- nu vine pe loc un altul
        end)

        test.case("nimic nu expira: ce asteapta ramane oricat trece", function()
            local st = fresh()
            TreasureMath.start(st, 0)
            TreasureMath.advance(st, 600)
            local before = #st.waiting
            check.is_true(before >= 1)
            TreasureMath.advance(st, 1e9)
            check.is_true(#st.waiting >= before)
        end)

        test.case("pontonul deja plin la primul peste: ceasul sta pana scoti unul", function()
            -- daruri ale roatii inainte sa fi pescuit vreodata: trei la ponton, apoi primul peste porneste raul
            local st = fresh()
            for _ = 1, TreasureConfig.MAX_WAITING do
                TreasureMath.grant(st, "chest")
            end
            TreasureMath.start(st, 1000)
            check.equal(st.nextAt, 0)
            check.equal(#TreasureMath.advance(st, 1000 + 3600), 0)
            -- scoti unul: urmatorul vine dupa un interval intreg, nu pe loc
            local now = 1000 + 3600
            TreasureMath.take(st, now)
            check.is_true(st.nextAt >= now + TreasureConfig.INTERVAL_MIN)
            check.equal(#TreasureMath.advance(st, now + 1), 0)
        end)

        test.case("un ceas dat inapoi nu aduce nimic in plus", function()
            local st = fresh()
            TreasureMath.start(st, 5000)
            check.equal(#TreasureMath.advance(st, 100), 0)
        end)

        test.case("aceeasi stare da aceleasi sosiri (samanta avanseaza determinist)", function()
            local a, b = fresh(), fresh()
            TreasureMath.start(a, 0)
            TreasureMath.start(b, 0)
            local ra, rb = TreasureMath.advance(a, 900), TreasureMath.advance(b, 900)
            check.equal(#ra, #rb)
            for i = 1, #ra do
                check.equal(ra[i], rb[i])
            end
        end)
    end)

    test.suite("TreasureMath - darul roatii si biletele", function()
        test.case(
            "darul roatii vine la ponton; cu pontonul plin, nu (roata plateste in perle)",
            function()
                local st = fresh()
                for _ = 1, TreasureConfig.MAX_WAITING do
                    check.is_true(TreasureMath.grant(st, "chest"))
                end
                check.is_false(TreasureMath.grant(st, "bottle"))
                check.is_false(TreasureMath.grant(fresh(), "nu-exista"))
            end
        )

        test.case("biletele vin in ordine, apoi de la capat", function()
            local st = fresh()
            check.equal(TreasureMath.nextNote(st), 1)
            check.equal(TreasureMath.nextNote(st), 2)
            st.notes = #TreasureConfig.NOTES
            check.equal(TreasureMath.nextNote(st), 1)
        end)

        test.case("felurile si ponderile: perle fixe > 0, ponderi care se aduna la 100", function()
            local total = 0
            for _, k in TreasureConfig.KINDS do
                total += k.weight
                check.is_true(k.pearls > 0)
            end
            check.equal(total, 100)
            check.not_nil(TreasureConfig.byId[TreasureConfig.FIRST_KIND])
            local counts: { [string]: number } = {}
            for i = 0, 9999 do
                local id = TreasureMath.pickKind((i + 0.5) / 10000)
                counts[id] = (counts[id] or 0) + 1
            end
            for _, k in TreasureConfig.KINDS do
                check.is_true(math.abs((counts[k.id] or 0) / 10000 - k.weight / 100) < 0.001)
            end
        end)
    end)
end
