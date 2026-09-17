--!strict
-- [D60] Pachetul cu oamenii din balci: dus-intors fara pierderi si sub limita unui UnreliableRemoteEvent.
local frktest = require("@frktest/frktest")
local test = frktest.test
local check = frktest.assert.check

local CrowdCodec = require("../src/Shared/Modules/CrowdCodec")
local FairLayout = require("../src/Shared/Modules/FairLayout")

return function()
    test.suite("CrowdCodec", function()
        test.case("fiecare om iese exact cum a intrat (pozitii rotunjite la pixel)", function()
            local entries = {
                { slot = 1, x = 810.4, y = 1330.6, facing = "up", moving = true },
                { slot = 24, x = 0, y = FairLayout.SIZE.h, facing = "left", moving = false },
                { slot = 7, x = FairLayout.SIZE.w, y = 0, facing = "right", moving = true },
                { slot = 255, x = 12, y = 34, facing = "down", moving = false },
            }
            local back = CrowdCodec.decode(CrowdCodec.encode(entries))
            check.equal(#back, #entries)
            for i, e in entries do
                check.equal(back[i].slot, e.slot)
                check.equal(back[i].x, math.round(e.x))
                check.equal(back[i].y, math.round(e.y))
                check.equal(back[i].facing, e.facing)
                check.equal(back[i].moving, e.moving)
            end
        end)

        test.case("un server plin incape de departe in limita de 1000 de octeti", function()
            local entries = {}
            for i = 1, FairLayout.MAX_PLAYERS do
                table.insert(
                    entries,
                    { slot = i, x = 1600, y = 1600, facing = "down", moving = true }
                )
            end
            check.equal(
                buffer.len(CrowdCodec.encode(entries)),
                FairLayout.MAX_PLAYERS * CrowdCodec.BYTES
            )
            check.is_true(buffer.len(CrowdCodec.encode(entries)) < 1000)
        end)

        test.case("un pachet stricat da o lista goala", function()
            check.equal(#CrowdCodec.decode(nil), 0)
            check.equal(#CrowdCodec.decode("hello"), 0)
            check.equal(#CrowdCodec.decode(buffer.create(7)), 0)
            check.equal(#CrowdCodec.decode(buffer.create(0)), 0)
        end)
    end)
end
