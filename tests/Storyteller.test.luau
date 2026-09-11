-- Testul alegerii ponderate a evenimentelor: fara Studio, doar modulul pur.
local frktest = require("@frktest/frktest")
local test = frktest.test
local check = frktest.assert.check
local Storyteller = require("../src/Shared/Modules/Storyteller")
local EventConfig = require("../src/Shared/Config/EventConfig")

type Event = EventConfig.Event

local function ev(id: string, weight: number, requires: string?): Event
    return {
        id = id,
        title = id,
        body = "",
        tone = "neutral",
        weight = weight,
        requires = requires,
        effect = {},
    }
end

return function()
    test.suite("Storyteller", function()
        test.case("nu alege un eveniment a carui conditie nu e indeplinita", function()
            local events = { ev("gated", 100, "beds") }
            check.equal(Storyteller.pick(events, { beds = false }, {}, 0.5), nil)
            local picked = Storyteller.pick(events, { beds = true }, {}, 0.5)
            check.not_nil(picked)
        end)

        test.case("nu repeta un eveniment din jurnalul recent", function()
            local events = { ev("a", 10), ev("b", 10) }
            local picked = Storyteller.pick(events, {}, { "a" }, 0.1)
            check.not_nil(picked)
            check.equal((picked :: Event).id, "b")
        end)

        test.case("intoarce nil cand nimic nu e eligibil", function()
            local events = { ev("a", 10) }
            check.equal(Storyteller.pick(events, {}, { "a" }, 0.5), nil)
        end)

        test.case("ponderea decide: zarul mic ia primul, zarul mare ia ultimul", function()
            local events = { ev("first", 1), ev("last", 99) }
            local low = Storyteller.pick(events, {}, {}, 0)
            local high = Storyteller.pick(events, {}, {}, 0.999)
            check.equal((low :: Event).id, "first")
            check.equal((high :: Event).id, "last")
        end)

        test.case("zarul la limita superioara nu iese din lista", function()
            local events = { ev("a", 5), ev("b", 5) }
            local picked = Storyteller.pick(events, {}, {}, 1)
            check.not_nil(picked)
        end)

        test.case("jurnalul pastreaza doar ultimele intrari, cea mai noua prima", function()
            local log: { any } = {}
            for i = 1, 5 do
                Storyteller.pushLog(log, { id = `e{i}` }, 3)
            end
            check.equal(#log, 3)
            check.equal(log[1].id, "e5")
            check.equal(log[3].id, "e3")
        end)

        test.case("recentIds ia din varful jurnalului, plafonat", function()
            local log: { any } = { { id = "a" }, { id = "b" }, { id = "c" } }
            local ids = Storyteller.recentIds(log, 2)
            check.equal(#ids, 2)
            check.equal(ids[1], "a")
            check.equal(ids[2], "b")
            check.equal(#Storyteller.recentIds(log, 99), 3)
        end)

        test.case("evenimentele configurate au ponderi valide si nu se repeta ca id", function()
            local seen: { [string]: boolean } = {}
            for _, e in EventConfig.EVENTS do
                check.equal(seen[e.id], nil)
                seen[e.id] = true
                check.is_true(e.weight > 0)
                check.not_nil(EventConfig.TONES[e.tone])
            end
        end)
    end)
end
