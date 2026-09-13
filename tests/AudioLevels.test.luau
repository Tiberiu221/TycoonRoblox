-- [D54] Nivelurile sunetului: curba, implicitele si validarea remote-ului.
local frktest = require("@frktest/frktest")
local test = frktest.test
local check = frktest.assert.check

local AudioLevels = require("../src/Shared/Modules/AudioLevels")

return function()
    test.suite("AudioLevels [D54]", function()
        test.case("nivelul 0 tace, iar curba creste la fiecare pas", function()
            check.equal(AudioLevels.volume(0, AudioLevels.MUSIC_MAX), 0)
            local previous = 0
            for level = 1, AudioLevels.MAX_LEVEL do
                local v = AudioLevels.volume(level, AudioLevels.MUSIC_MAX)
                check.is_true(v > previous)
                previous = v
            end
            check.is_true(math.abs(previous - AudioLevels.MUSIC_MAX) < 1e-9)
        end)

        test.case("muzica implicita e de fundal: cel putin 9 dB sub vechiul 0.35", function()
            local v = AudioLevels.volume(AudioLevels.DEFAULT_MUSIC, AudioLevels.MUSIC_MAX)
            check.is_true(20 * math.log10(v / 0.35) <= -9)
        end)

        test.case("efectele implicite raman amestecul de pana acum", function()
            check.equal(AudioLevels.volume(AudioLevels.DEFAULT_SOUND, AudioLevels.SOUND_MAX), 1)
        end)

        test.case("trece doar un intreg finit intre 0 si 10", function()
            for _, ok in { 0, 4, 10 } do
                check.is_true(AudioLevels.valid(ok))
            end
            for _, bad in { -1, 11, 3.5, 0 / 0, math.huge, -math.huge, "5", true, {} } do
                check.is_false(AudioLevels.valid(bad))
            end
            check.is_false(AudioLevels.valid(nil))
        end)
    end)
end
