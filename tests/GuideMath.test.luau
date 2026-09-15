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
        sackRawScrap = get("sackRawScrap", 0),
        sackIron = get("sackIron", 0),
        sackFinds = get("sackFinds", 0),
        hands = get("hands", {}),
        firstsCollect = get("firstsCollect", false),
        firstsSell = get("firstsSell", false),
        sawIn = get("sawIn", 0),
        sawOut = get("sawOut", 0),
        storage = get("storage", 0),
        forgeIn = get("forgeIn", 0),
        forgeOut = get("forgeOut", 0),
        shed = get("shed", 0),
        crews = get("crews", {}),
        dockPileValue = get("dockPileValue", 0),
    } :: any
end

local TycoonConfig = require("../src/Shared/Config/TycoonConfig")
local StationConfig = require("../src/Shared/Config/StationConfig")
local Strings = require("../src/Shared/Config/Strings")
local STAND = TycoonConfig.SAWMILL_STAND
local FORGE = TycoonConfig.WORKSHOP_STAND
-- in turul fierului, oamenii lemnului sunt toti angajati [D56]
local WOOD_CREWS = { collector = 1, porter = 1, sawyer = 1, hauler = 1, trader = 1 }
local function withCrews(extra: { [string]: number }): { [string]: number }
    local out = table.clone(WOOD_CREWS)
    for role, n in extra do
        out[role] = n
    end
    return out
end

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

    test.suite("GuideMath.loopStep -- linia fierului [D56]", function()
        local function step(over: { [string]: any }, kind: string?): GuideMath.Goal
            local st = state(over)
            st.quest = {
                key = "q",
                text = "q",
                x = 0,
                y = 0,
                kind = kind or "smelted",
                goal = 10,
                progress = 0,
            }
            return GuideMath.pickGoal(st) :: GuideMath.Goal
        end

        test.case("cele unsprezece ramuri, in ordine: fiecare bate urmatoarea", function()
            local woodNet = { padId = "first_net", x = 620, y = 812, count = 4, capacity = 12 }
            -- fiecare stare are si ce ar declansa ramura urmatoare; pasul ales trebuie sa fie tot primul
            local cases: { { over: { [string]: any }, kind: string, key: string } } = {
                {
                    over = { sackCount = 6, sackRawScrap = 3, sawIn = 2 },
                    kind = "deliver",
                    key = "sawmill",
                },
                {
                    over = { sackCount = 3, sackRawScrap = 3, sawIn = 2 },
                    kind = "deliver",
                    key = "forge",
                },
                { over = { sawIn = 2, forgeIn = 5 }, kind = "cut", key = "cut" },
                { over = { forgeIn = 5, sawOut = 4 }, kind = "smelt", key = "smelt" },
                { over = { sawOut = 4, forgeOut = 3 }, kind = "take", key = "planks" },
                {
                    over = { forgeOut = 3, sackCount = 2, sackCut = 2 },
                    kind = "take",
                    key = "iron",
                },
                { over = { sackCount = 2, sackCut = 2, storage = 9 }, kind = "sell", key = "dock" },
                { over = { storage = 9, shed = 7 }, kind = "take", key = "storage" },
                { over = { shed = 7, nets = { woodNet } }, kind = "take", key = "shed" },
                { over = { nets = { woodNet } }, kind = "collect", key = "net:first_net" },
                { over = {}, kind = "wait", key = "catching" },
            }
            for i, c in cases do
                local g = step(c.over, "sold")
                check.equal(g.kind, c.kind)
                check.equal(g.key, c.key)
                if g.key ~= c.key then
                    print(`ramura {i}: asteptat {c.key}, iesit {g.key}`)
                end
            end
        end)

        test.case("turul de mana al fierului: forja, inelul, fierul, taverna", function()
            local crews = withCrews({})
            local toForge = step({ sackCount = 12, sackRawScrap = 12, crews = crews })
            check.equal(toForge.key, "forge")
            check.equal(toForge.x, FORGE.x)
            check.equal(toForge.text, Strings.GUIDE_SCRAP_TO_FORGE)
            local ring = step({ forgeIn = 12, crews = crews })
            check.equal(ring.kind, "smelt")
            check.equal(ring.x, FORGE.x)
            check.equal(ring.text, Strings.stepStaySmelt(12))
            local take = step({ forgeOut = 12, crews = crews })
            check.equal(take.key, "iron")
            check.equal(take.text, Strings.STEP_TAKE_IRON)
            local sell =
                step({ sackCount = 12, sackCut = 12, sackIron = 12, crews = crews }, "ironSold")
            check.equal(sell.key, "dock")
            check.equal(sell.text, Strings.GUIDE_SELL_IRON)
        end)

        test.case("un pas facut de un om al fierului nu mai e al tau", function()
            check.is_true(step({ forgeIn = 5, crews = withCrews({ smelter = 1 }) }).kind ~= "smelt")
            check.is_true(
                step({ forgeOut = 5, crews = withCrews({ ironHauler = 1 }) }).key ~= "iron"
            )
            check.equal(step({ shed = 5, crews = withCrews({}) }).key, "shed")
            check.is_true(step({ shed = 5, crews = withCrews({ scrapPorter = 1 }) }).key ~= "shed")
        end)

        test.case("plasele pe linii: fiecare culegator doar plasele felului lui", function()
            local woodNet = { padId = "first_net", x = 620, y = 812, count = 9, capacity = 12 }
            local scrapNet =
                { padId = "fifth_net", x = 1100, y = 812, count = 3, capacity = 12, scrap = true }
            local nets = { woodNet, scrapNet }
            -- Collector-ul lemnului angajat: plasa de scrap ramane a ta, chiar daca e mai goala
            local scrap = step({ nets = nets, crews = { collector = 1 } })
            check.equal(scrap.key, "net:fifth_net")
            check.equal(scrap.text, Strings.GUIDE_COLLECT_SCRAP)
            -- doar Scrap Collector: plasa de lemn e a ta
            local wood = step({ nets = nets, crews = { scrapCollector = 1 } })
            check.equal(wood.key, "net:first_net")
            check.equal(wood.text, Strings.GUIDE_COLLECT)
            -- amandoi: nimic de cules cu mana
            check.equal(
                step({ nets = nets, crews = { collector = 1, scrapCollector = 1 } }).key,
                "catching"
            )
        end)

        test.case("textul tavernei spune ce duci [D40]", function()
            local function sellText(over: { [string]: any }): string
                return step(over, "sold").text
            end
            check.equal(sellText({ sackCount = 8, sackCut = 8 }), Strings.GUIDE_SELL_PLANKS)
            check.equal(
                sellText({ sackCount = 8, sackCut = 8, sackIron = 8 }),
                Strings.GUIDE_SELL_IRON
            )
            check.equal(
                sellText({ sackCount = 8, sackCut = 8, sackIron = 3 }),
                Strings.GUIDE_SELL_BOTH
            )
            -- o gasire langa scanduri nu schimba textul; singura in traista are textul ei
            check.equal(
                sellText({ sackCount = 8, sackCut = 8, sackFinds = 1 }),
                Strings.GUIDE_SELL_PLANKS
            )
            check.equal(
                sellText({ sackCount = 1, sackCut = 1, sackFinds = 1 }),
                Strings.guideSellFinds(1)
            )
            local full =
                step({ sackCount = 30, sackCapacity = 30, sackCut = 30, sackIron = 30 }, "sold")
            check.equal(full.text, Strings.SACK_FULL_IRON)
            -- traista plina doar de gasiri: nu "planks" [revizia D56]
            local finds =
                step({ sackCount = 30, sackCapacity = 30, sackCut = 30, sackFinds = 30 }, "sold")
            check.equal(finds.text, Strings.SACK_FULL_FINDS)
        end)

        test.case("fara quest: traista plina de scrap trimite la forja, nu la gater", function()
            local g = GuideMath.pickGoal(state({
                pads = pads({ "first_net" }),
                sackCount = 30,
                sackCapacity = 30,
                sackRawScrap = 30,
            })) :: GuideMath.Goal
            check.equal(g.key, "forge")
            check.equal(g.text, Strings.SACK_FULL_SCRAP)
        end)

        test.case("ghidajul tace dupa oamenii lemnului, se trezeste cu Forge", function()
            local before = GuideMath.guidedRoles(false)
            local after = GuideMath.guidedRoles(true)
            check.equal(#after, #StationConfig.ROLES)
            check.equal(#before, #StationConfig.ROLES - #StationConfig.LINE_STEPS.iron)
            local counts = withCrews({})
            check.is_true(GuideMath.allCrewsHired(counts, before))
            check.is_false(GuideMath.allCrewsHired(counts, after))
            for _, role in StationConfig.LINE_STEPS.iron do
                counts[role] = 1
            end
            check.is_true(GuideMath.allCrewsHired(counts, after))
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

        test.case(
            "[D59] quest-ul care invata undita isi are sageata chiar daca ghidajul tace",
            function()
                local stand = TycoonConfig.FISH_STAND
                local st = state({ pads = pads({ "first_net" }), crews = WOOD_CREWS })
                st.allCrewsHired = true
                st.quest = {
                    key = "catch_fish",
                    text = "Catch a fish at the pier",
                    x = stand.x,
                    y = stand.y,
                    kind = "fished",
                    progress = 0,
                    goal = 1,
                }
                local g = GuideMath.pickGoal(st) :: GuideMath.Goal
                check.equal(g.kind, "goto")
                check.equal(g.x, stand.x)
                check.equal(g.y, stand.y)
                -- orice alt quest (chiar si o cumparare pe care n-o poti plati, fara pescuit) ramane in tacere
                st.quest =
                    { key = "idle_one", text = "Earn 1 a second", x = 300, y = 830, kind = "idle" }
                check.is_true(GuideMath.pickGoal(st) == nil)
            end
        )

        test.case(
            "[D59] indiciul pontonului: dupa primul peste, cat strangi bani, fara tinta",
            function()
                local function questFourth(): GuideMath.QuestGoal
                    return {
                        key = "cast_fourth",
                        text = "Cast a fourth net, further out",
                        x = 1220,
                        y = 812,
                        padId = "far_lane_net",
                        price = 900,
                        kind = "pad",
                    }
                end
                -- ghidajul tace: oamenii lemnului sunt toti angajati
                local st = state({ pads = pads({ "first_net" }), coins = 100, crews = WOOD_CREWS })
                st.allCrewsHired = true
                st.quest = questFourth()
                check.is_true(GuideMath.pickGoal(st) == nil) -- n-ai pescuit inca: tacerea din D50 ramane
                st.hasFished = true
                local g = GuideMath.pickGoal(st) :: GuideMath.Goal
                check.equal(g.kind, "wait")
                check.equal(g.text, Strings.HINT_FISH_WHILE_SAVING)
                check.is_true(g.x == nil) -- linia NEXT, fara sageata
                check.equal(g.price, 900) -- bara masoara monedele
                st.coins = 1000 -- ai banii: fara indiciu
                check.is_true(GuideMath.pickGoal(st) == nil)

                -- ghidajul vorbeste: indiciul doar cand mainile n-au nimic de facut
                local busy = state({ pads = pads({ "first_net" }), coins = 100, sackCount = 12 })
                busy.quest = questFourth()
                busy.hasFished = true
                check.equal((GuideMath.pickGoal(busy) :: GuideMath.Goal).kind, "deliver")
                local idle = state({
                    pads = pads({ "first_net" }),
                    coins = 100,
                    nets = { { padId = "first_net", x = 620, y = 812, count = 0, capacity = 12 } },
                    crews = { collector = 1 },
                })
                idle.quest = questFourth()
                idle.hasFished = true
                local hint = GuideMath.pickGoal(idle) :: GuideMath.Goal
                check.equal(hint.text, Strings.HINT_FISH_WHILE_SAVING)
                check.equal(hint.price, 900)
            end
        )

        test.case("[D59] un lucru care te asteapta la ponton bate indiciul de pescuit", function()
            local st = state({ pads = pads({ "first_net" }), coins = 100, crews = WOOD_CREWS })
            st.allCrewsHired = true
            st.hasFished = true
            st.treasureWaiting = "chest"
            st.quest = {
                key = "q",
                text = "q",
                x = 1220,
                y = 812,
                padId = "far_lane_net",
                price = 900,
                kind = "pad",
            }
            local g = GuideMath.pickGoal(st) :: GuideMath.Goal
            check.equal(g.text, "A chest is waiting at your pier")
            st.treasureWaiting = "golden"
            check.equal(
                (GuideMath.pickGoal(st) :: GuideMath.Goal).text,
                "Golden Driftwood is waiting at your pier"
            )
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
