-- Neinregistrat in _run.luau (agentul F nu are voie sa-l editeze) -- de adaugat de cine ia
-- urmatorul F1 [spec sectiunea 0]: `require("./GuideMath.test")()` langa celelalte.
local frktest = require("@frktest/frktest")
local test = frktest.test
local check = frktest.assert.check

local GuideMath = require("../src/Shared/Modules/GuideMath")

local function pads(boughtIds: { string }, availableIds: { string }?): { [string]: string }
    local m: { [string]: string } = {}
    for _, id in boughtIds do
        m[id] = "bought"
    end
    if availableIds ~= nil then
        for _, id in availableIds do
            m[id] = "available"
        end
    end
    return m
end

-- Constructor cu valori implicite, ca fiecare caz sa scrie doar campurile care conteaza pentru el.
local function state(over: { [string]: any }): GuideMath.State
    local function get(key: string, default: any): any
        local v = over[key]
        if v == nil then
            return default
        end
        return v
    end
    return {
        coins = get("coins", 0),
        pads = get("pads", {}),
        nets = get("nets", {}),
        sackCount = get("sackCount", 0),
        sackCapacity = get("sackCapacity", 30),
        sackCut = get("sackCut", 0),
        hands = get("hands", {}),
        firstsCollect = get("firstsCollect", false),
        firstsSell = get("firstsSell", false),
        sawIn = get("sawIn", 0),
        sawOut = get("sawOut", 0),
        storage = get("storage", 0),
        crews = get("crews", {}),
        dockPileValue = get("dockPileValue", 0),
    } :: any
end

local TycoonConfig = require("../src/Shared/Config/TycoonConfig")
local STAND = TycoonConfig.SAWMILL_STAND

return function()
    test.suite("GuideMath - regula 0: quest-ul activ bate tot", function()
        test.case("un quest de cumparare CU banii in mana: pasul e platforma", function()
            local st = state({ pads = pads({ "first_net" }), coins = 20 })
            st.quest = {
                key = "cast_second",
                text = "Cast a second net",
                x = 820,
                y = 812,
                padId = "second_net",
                price = 13,
                kind = "pad",
            }
            local g = GuideMath.pickGoal(st) :: GuideMath.Goal
            check.equal(g.kind, "buy")
            check.equal(g.key, "quest:cast_second")
            check.equal(g.padId, "second_net")
            check.equal(g.x, 820)
            check.equal(g.price, 13)
        end)

        test.case(
            "FARA bani: nu trimite la platforma, ci la bucla care face banii [D51]",
            function()
                -- owner-ul: "te impinge sa iti faci net-uri cat mai multe dar fara materiale"
                local st = state({ pads = pads({ "first_net" }), coins = 5, sackCount = 12 })
                st.quest = {
                    key = "cast_second",
                    text = "Cast a second net",
                    x = 820,
                    y = 812,
                    padId = "second_net",
                    price = 13,
                    kind = "pad",
                }
                local g = GuideMath.pickGoal(st) :: GuideMath.Goal
                check.equal(g.kind, "deliver") -- ai busteni in traista: la gater
                check.equal(g.x, STAND.x)
                check.equal(g.price, 13) -- linia NEXT masoara monedele
                check.is_true(g.padId == nil)
                -- iar daca banii care lipsesc vin deja din gramada tavernei, pasul e asteptarea, fara tinta
                st.dockPileValue = 8
                local wait = GuideMath.pickGoal(st) :: GuideMath.Goal
                check.equal(wait.kind, "wait")
                check.is_true(wait.x == nil)
            end
        )

        test.case("quest de nivel: conteaza costul nivelului urmator", function()
            local st = state({ pads = pads({ "first_net" }), coins = 3 })
            st.quest = {
                key = "net_two",
                text = "Upgrade your net to level 2",
                x = 620,
                y = 812,
                kind = "level",
                levelCost = 1,
                upgradeKind = "net",
                upgradeId = "first_net",
            }
            local g = GuideMath.pickGoal(st) :: GuideMath.Goal
            check.equal(g.kind, "upgrade")
            check.equal(g.upgradeKind, "net")
            check.equal(g.upgradeId, "first_net")
            st.coins = 0
            check.is_true((GuideMath.pickGoal(st) :: GuideMath.Goal).kind ~= "upgrade")
        end)

        test.case("fara quest, regulile vechi raman neatinse", function()
            local st = state({
                pads = pads({ "first_net" }),
                sackCount = 30,
                sackCapacity = 30,
                sackCut = 30,
            })
            local g = GuideMath.pickGoal(st) :: GuideMath.Goal
            check.equal(g.kind, "sell")
        end)

        test.case("un quest fara tinta in lume are kind 'goto', nu 'buy'", function()
            local st = state({ pads = pads({ "first_net" }) })
            st.quest = { key = "idle_one", text = "Earn 1 a second", x = 300, y = 830 }
            local g = GuideMath.pickGoal(st) :: GuideMath.Goal
            check.equal(g.kind, "goto")
        end)
    end)

    test.suite("GuideMath.loopStep -- bucla de mana, fara sa sara peste nimic [D51]", function()
        local function loopQuest(kind: string, goal: number, progress: number): GuideMath.QuestGoal
            return {
                key = "q",
                text = "q",
                x = 0,
                y = 0,
                kind = kind,
                goal = goal,
                progress = progress,
            }
        end

        test.case("cat se taie, pasul e inelul -- nu taverna (cazul din captura)", function()
            -- 4 busteni la gater, 5 scanduri gata, quest-ul de taiat deja bifat: owner-ul a vazut dara
            -- plecand spre taverna. Pasul ramane "stai in inel".
            local st = state({ pads = pads({ "first_net" }), sawIn = 4, sawOut = 5 })
            st.quest = loopQuest("sold", 12, 0)
            local g = GuideMath.pickGoal(st) :: GuideMath.Goal
            check.equal(g.kind, "cut")
            check.equal(g.x, STAND.x)
            check.is_true(string.find(g.text, "4", 1, true) ~= nil)
        end)

        test.case("ordinea: busteni in traista > taiat > scanduri de luat > vandut", function()
            local q = loopQuest("sold", 12, 0)
            local function step(over: { [string]: any }): GuideMath.Goal
                local st = state(over)
                st.quest = q
                return GuideMath.pickGoal(st) :: GuideMath.Goal
            end
            check.equal(step({ sackCount = 12, sawIn = 3 }).kind, "deliver")
            check.equal(step({ sawIn = 3, sawOut = 9 }).kind, "cut")
            check.equal(step({ sawOut = 12 }).kind, "take")
            check.equal(step({ sackCount = 12, sackCut = 12 }).kind, "sell")
            check.equal(step({ sackCount = 12, sackCut = 12 }).x, TycoonConfig.DOCK.x)
            -- traista plina de scanduri si scanduri gata: nu mai incap, deci vinzi
            check.equal(step({ sackCount = 30, sackCut = 30, sawOut = 5 }).kind, "sell")
        end)

        test.case("un pas facut de un om al tau nu mai e al tau", function()
            local q = loopQuest("sold", 40, 12)
            local function step(over: { [string]: any }): GuideMath.Goal
                local st = state(over)
                st.quest = q
                return GuideMath.pickGoal(st) :: GuideMath.Goal
            end
            check.equal(step({ sawIn = 5, crews = { sawyer = 1 } }).kind, "wait")
            check.equal(step({ sawOut = 5, crews = { hauler = 1 } }).kind, "wait")
            check.equal(step({ storage = 8 }).kind, "take")
            check.equal(step({ storage = 8, crews = { porter = 1 } }).kind, "wait")
        end)

        test.case("primul quest: asteapta plasa plina, apoi colecteaza", function()
            local net = { padId = "first_net", x = 620, y = 812, count = 7, capacity = 12 }
            local st = state({ pads = pads({ "first_net" }), nets = { net } })
            st.quest = loopQuest("collected", 12, 0)
            local g = GuideMath.pickGoal(st) :: GuideMath.Goal
            check.equal(g.kind, "wait")
            check.equal(g.x, 620)
            check.is_true(string.find(g.text, "7/12", 1, true) ~= nil)
            net.count = 12
            check.equal((GuideMath.pickGoal(st) :: GuideMath.Goal).kind, "collect")
            -- dupa o colectare partiala de 7, mai lipsesc 5: asteptarea e pana la 5, nu pana la 12
            net.count = 3
            st.quest = loopQuest("collected", 12, 7)
            local partial = GuideMath.pickGoal(st) :: GuideMath.Goal
            check.is_true(string.find(partial.text, "3/5", 1, true) ~= nil)
        end)

        test.case("nimic de facut cu mana: plasele prind, fara tinta", function()
            local st = state({
                pads = pads({ "first_net" }),
                nets = { { padId = "first_net", x = 620, y = 812, count = 0, capacity = 12 } },
                crews = { collector = 1 },
            })
            st.quest = loopQuest("sold", 40, 12)
            local g = GuideMath.pickGoal(st) :: GuideMath.Goal
            check.equal(g.kind, "wait")
            check.is_true(g.x == nil)
        end)
    end)

    test.suite("GuideMath.pickGoal -- prioritate a..f", function()
        test.case("a) nimic cumparat -> First Net, imediat", function()
            local g = GuideMath.pickGoal(state({ pads = pads({}) })) :: GuideMath.Goal
            check.is_true(g ~= nil)
            check.equal(g.kind, "buy")
            check.equal(g.key, "pad:first_net")
            check.is_true(g.immediate)
        end)

        test.case("b) traista plina trece inaintea unei platforme accesibile", function()
            local g = GuideMath.pickGoal(state({
                pads = pads({ "first_net" }, { "second_net" }),
                coins = 999,
                sackCount = 30,
                sackCapacity = 30,
                sackCut = 30,
            })) :: GuideMath.Goal
            check.equal(g.kind, "sell")
            check.equal(g.key, "dock")
        end)

        test.case("tinta e locul unde stai: inelul gaterului, usa tavernei [D50]", function()
            local TycoonConfig = require("../src/Shared/Config/TycoonConfig")
            local logs = GuideMath.pickGoal(state({
                pads = pads({ "first_net" }),
                sackCount = 30,
                sackCapacity = 30,
            })) :: GuideMath.Goal
            check.equal(logs.x, TycoonConfig.SAWMILL_STAND.x)
            check.equal(logs.y, TycoonConfig.SAWMILL_STAND.y)
            local planks = GuideMath.pickGoal(state({
                pads = pads({ "first_net" }),
                sackCount = 30,
                sackCapacity = 30,
                sackCut = 30,
            })) :: GuideMath.Goal
            check.equal(planks.x, TycoonConfig.DOCK.x)
            check.equal(planks.y, TycoonConfig.DOCK.y)
            check.is_true(string.find(planks.text, "tavern", 1, true) ~= nil)
        end)

        test.case("cu cate un om la fiecare meserie, ghidajul tace de tot [D50]", function()
            local StationConfig = require("../src/Shared/Config/StationConfig")
            local counts = {}
            for _, role in StationConfig.ROLES do
                counts[role] = 1
            end
            check.is_true(GuideMath.allCrewsHired(counts, StationConfig.ROLES))
            counts[StationConfig.ROLES[#StationConfig.ROLES]] = 0
            check.is_false(GuideMath.allCrewsHired(counts, StationConfig.ROLES))
            check.is_false(GuideMath.allCrewsHired({}, StationConfig.ROLES))
            -- chiar si cu traista plina si un quest activ: nicio tinta
            local st = state({ pads = pads({ "first_net" }), sackCount = 30, sackCapacity = 30 })
            st.quest = { key = "idle_one", text = "Earn 1 a second", x = 300, y = 830 }
            st.allCrewsHired = true
            check.is_true(GuideMath.pickGoal(st) == nil)
        end)

        test.case("b/d) bustenii duc la gater, scandurile la debarcader [D49]", function()
            -- Bugul pe care il apara: dupa D48 predarea era la gater, dar sageata si textul trimiteau
            -- inca la debarcader. Acum decide ce ai in traista, nu o adresa fixa.
            local logs = GuideMath.pickGoal(state({
                pads = pads({ "first_net" }),
                sackCount = 30,
                sackCapacity = 30,
            })) :: GuideMath.Goal
            check.equal(logs.kind, "deliver")
            check.equal(logs.key, "sawmill")
            check.is_true(string.find(logs.text, "sawmill", 1, true) ~= nil)
            -- amestec: cat timp mai ai busteni, primul drum e la gater (acolo iei si scandurile)
            local mixed = GuideMath.pickGoal(state({
                pads = pads({ "first_net" }),
                sackCount = 12,
                sackCapacity = 30,
                sackCut = 5,
            })) :: GuideMath.Goal
            check.equal(mixed.key, "sawmill")
            local planks = GuideMath.pickGoal(state({
                pads = pads({ "first_net" }),
                sackCount = 12,
                sackCapacity = 30,
                sackCut = 12,
            })) :: GuideMath.Goal
            check.equal(planks.key, "dock")
            check.is_true(string.find(planks.text, "planks", 1, true) ~= nil)
        end)

        test.case("b) dupa prima vanzare, traista plina nu mai e imediata", function()
            local g = GuideMath.pickGoal(state({
                pads = pads({ "first_net" }),
                sackCount = 30,
                sackCapacity = 30,
                firstsSell = true,
            })) :: GuideMath.Goal
            check.is_false(g.immediate)
        end)

        test.case("c) cea mai ieftina platforma disponibila si accesibila", function()
            local g = GuideMath.pickGoal(state({
                pads = pads({ "first_net" }, { "second_net", "bigger_sack" }),
                coins = 100, -- isi permite pe amandoua: Second Net (9) < Bigger Sack (18)
            })) :: GuideMath.Goal
            check.equal(g.kind, "buy")
            check.equal(g.key, "pad:second_net")
            check.is_false(g.immediate)
        end)

        test.case(
            "c) o platforma disponibila dar neaccesibila nu e obiectiv de CUMPARARE",
            function()
                -- ...dar nici nu ramane jucatorul fara reper: cade pe f), tinta de economisire
                local g = GuideMath.pickGoal(state({
                    pads = pads({ "first_net" }, { "second_net" }),
                    coins = 0,
                })) :: GuideMath.Goal
                check.equal(g.kind, "save")
                check.equal(g.padId, "second_net")
                check.is_false(g.immediate) -- sageata tot nu sare; doar linia fixa din HUD o foloseste
            end
        )

        test.case(
            "f) tinta de economisire e cea mai IEFTINA disponibila, cu pret cu tot",
            function()
                local g = GuideMath.pickGoal(state({
                    pads = pads({ "first_net" }, { "bigger_sack", "second_net" }),
                    coins = 0,
                })) :: GuideMath.Goal
                check.equal(g.kind, "save")
                check.equal(g.padId, "second_net") -- 9 < 18
                check.is_true((g.price :: number) > 0)
            end
        )

        test.case("f) fara nicio platforma disponibila nu se inventeaza obiectiv", function()
            local g = GuideMath.pickGoal(state({
                pads = pads({ "first_net" }),
                coins = 0,
            }))
            check.is_true(g == nil)
        end)

        test.case("d) traista neagoala, niciodata vanduta -> debarcader, imediat", function()
            local g = GuideMath.pickGoal(state({
                pads = pads({ "first_net" }),
                sackCount = 1,
                sackCapacity = 30,
                sackCut = 1,
            })) :: GuideMath.Goal
            check.equal(g.kind, "sell")
            check.is_true(g.immediate)
        end)

        test.case("d) sub jumatate si deja vandut o data -> inca fara obiectiv", function()
            local g = GuideMath.pickGoal(state({
                pads = pads({ "first_net" }),
                sackCount = 5,
                sackCapacity = 30,
                firstsSell = true,
            }))
            check.is_true(g == nil)
        end)

        test.case("d) pe jumatate si deja vandut o data -> debarcader, dar nu imediat", function()
            local g = GuideMath.pickGoal(state({
                pads = pads({ "first_net" }),
                sackCount = 15,
                sackCapacity = 30,
                sackCut = 15,
                firstsSell = true,
            })) :: GuideMath.Goal
            check.equal(g.kind, "sell")
            check.is_false(g.immediate)
        end)

        test.case("e) o plasa culeasa cu mana cu marfa -> Collect, imediat prima data", function()
            local g = GuideMath.pickGoal(state({
                pads = pads({ "first_net" }),
                nets = { { padId = "first_net", x = 520, y = 840, count = 3 } },
            })) :: GuideMath.Goal
            check.equal(g.kind, "collect")
            check.equal(g.key, "net:first_net")
            check.is_true(g.immediate)
        end)

        test.case("e) dupa prima culegere, aceeasi plasa nu mai e imediata", function()
            local g = GuideMath.pickGoal(state({
                pads = pads({ "first_net" }),
                nets = { { padId = "first_net", x = 520, y = 840, count = 3 } },
                firstsCollect = true,
            })) :: GuideMath.Goal
            check.is_false(g.immediate)
        end)

        test.case("e) o plasa deservita de un alergator nu e obiectiv de mana", function()
            local g = GuideMath.pickGoal(state({
                pads = pads({ "first_net" }),
                nets = { { padId = "first_net", x = 520, y = 840, count = 3 } },
                hands = { { nets = { "first_net" } } },
            }))
            check.is_true(g == nil)
        end)

        test.case("f) nimic de facut -> fara obiectiv", function()
            local g = GuideMath.pickGoal(state({ pads = pads({ "first_net" }) }))
            check.is_true(g == nil)
        end)

        test.case("prioritate: sac plin bate o platforma accesibila si o culegere", function()
            local g = GuideMath.pickGoal(state({
                pads = pads({ "first_net" }, { "second_net" }),
                coins = 999,
                sackCount = 30,
                sackCapacity = 30,
                sackCut = 30,
                nets = { { padId = "first_net", x = 520, y = 840, count = 3 } },
            })) :: GuideMath.Goal
            check.equal(g.key, "dock")
        end)

        test.case(
            "prioritate: o platforma accesibila bate vanzarea pe jumatate si culegerea",
            function()
                local g = GuideMath.pickGoal(state({
                    pads = pads({ "first_net" }, { "second_net" }),
                    coins = 999,
                    sackCount = 20,
                    sackCapacity = 30,
                    firstsSell = true,
                    nets = { { padId = "first_net", x = 520, y = 840, count = 3 } },
                })) :: GuideMath.Goal
                check.equal(g.key, "pad:second_net")
            end
        )
    end)

    test.suite("GuideMath.labelPlacement [D52]", function()
        -- Ecran 1600x900, eticheta 300x34 deasupra unei tinte din mijloc; panourile sunt cele din colt.
        local function query(over: { [string]: any }): GuideMath.LabelQuery
            local q: { [string]: any } = {
                centerX = 800,
                aboveY = 300,
                belowY = 430,
                width = 300,
                height = 34,
                screenW = 1600,
                screenH = 900,
                blockers = {},
                current = "above",
            }
            for k, v in over do
                q[k] = v
            end
            return q :: any
        end
        -- colturile HUD-ului din captura owner-ului: monedele, traista, linia NEXT
        local TOP_LEFT = { x = 0, y = 0, w = 420, h = 230 }

        test.case("loc liber: deasupra tintei, pe loc", function()
            local place, shift = GuideMath.labelPlacement(query({}))
            check.equal(place, "above")
            check.equal(shift, 0)
        end)

        test.case("taverna sub monede si linia NEXT: textul trece sub inel", function()
            local place = GuideMath.labelPlacement(
                query({ centerX = 180, aboveY = 150, belowY = 330, blockers = { TOP_LEFT } })
            )
            check.equal(place, "below")
        end)

        test.case("ocupat si deasupra, si dedesubt: nu se deseneaza deloc", function()
            local low = { x = 0, y = 300, w = 420, h = 100 }
            local place = GuideMath.labelPlacement(
                query({ centerX = 180, aboveY = 150, belowY = 330, blockers = { TOP_LEFT, low } })
            )
            check.equal(place, "hidden")
        end)

        test.case("langa marginea din stanga: se muta ca sa inceapa pe ecran", function()
            local _, shift = GuideMath.labelPlacement(query({ centerX = 60 }))
            -- mijlocul la 60, jumatate 150: ar incepe la -90; margin 8 -> se muta 98
            check.equal(shift, 98)
            local _, right = GuideMath.labelPlacement(query({ centerX = 1560 }))
            check.equal(right, -(1560 + 150 - (1600 - 8)))
        end)

        test.case("deasupra marginii de sus a ecranului: trece dedesubt", function()
            local place = GuideMath.labelPlacement(query({ aboveY = -20 }))
            check.equal(place, "below")
        end)

        test.case("nu sare la fiecare pas: inapoi deasupra doar cu loc in plus", function()
            -- panoul se termina la 290; deasupra ar incepe la 300 (10 px, sub margin + return = 20)
            local panel = { x = 700, y = 200, w = 200, h = 90 }
            local stay =
                GuideMath.labelPlacement(query({ current = "below", blockers = { panel } }))
            check.equal(stay, "below")
            -- aceeasi geometrie, dar eticheta statea deja deasupra: ramane (10 px >= margin 8)
            local keep =
                GuideMath.labelPlacement(query({ current = "above", blockers = { panel } }))
            check.equal(keep, "above")
            -- cu 30 px liberi se intoarce deasupra
            local back = GuideMath.labelPlacement(
                query({ current = "below", aboveY = 320, belowY = 450, blockers = { panel } })
            )
            check.equal(back, "above")
        end)
    end)
end
