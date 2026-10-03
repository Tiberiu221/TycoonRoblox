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
        lines = over.lines, -- [D65] liniile Morii si ce cumpara fiecare vanzator; nil = doar Era 1
        sellAt = over.sellAt,
        allCrewsHired = over.allCrewsHired,
        world = over.world, -- [D70, pasul k3] harta ta (nil = satul) si piesele din traista, pe unirea lor
        parts = over.parts,
        sackContents = over.sackContents,
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
            local before = GuideMath.guidedRoles({})
            local after = GuideMath.guidedRoles({ workshop = true })
            check.equal(#after, #StationConfig.ERA1_ROLES)
            check.equal(#before, #StationConfig.ERA1_ROLES - #StationConfig.LINE_STEPS.iron)
            local counts = withCrews({})
            check.is_true(GuideMath.allCrewsHired(counts, before))
            check.is_false(GuideMath.allCrewsHired(counts, after))
            for _, role in StationConfig.LINE_STEPS.iron do
                counts[role] = 1
            end
            check.is_true(GuideMath.allCrewsHired(counts, after))
        end)

        test.case("[D65] la fel la Moara: roata de apa si cuptorul de cupru il trezesc", function()
            local era1 = GuideMath.guidedRoles({ workshop = true })
            local wheel = GuideMath.guidedRoles({ workshop = true, water_wheel = true })
            local all = GuideMath.guidedRoles({
                workshop = true,
                water_wheel = true,
                copper_furnace = true,
            })
            -- cu roata: cei patru ai pieselor si negustorul Pietei; cu cuptorul, si cei patru ai cuprului
            check.equal(#wheel, #era1 + #StationConfig.LINE_STEPS.parts + 1)
            check.equal(#all, #StationConfig.ERA1_ROLES + #StationConfig.ERA2_ROLES)
            check.is_true(table.find(wheel, "merchant") ~= nil)
            check.is_true(table.find(wheel, "coppersmith") == nil)
            local counts: { [string]: number } = {}
            for _, role in era1 do
                counts[role] = 1
            end
            check.is_true(GuideMath.allCrewsHired(counts, era1))
            check.is_false(GuideMath.allCrewsHired(counts, wheel)) -- ghidajul se trezeste
        end)

        test.case("[D67] si la Wire Works: masina cu abur si Power House il trezesc", function()
            local mill = { workshop = true, water_wheel = true, copper_furnace = true }
            local era2 = GuideMath.guidedRoles(mill)
            local steam = GuideMath.guidedRoles({
                workshop = true,
                water_wheel = true,
                copper_furnace = true,
                steam_engine = true,
            })
            local all = GuideMath.guidedRoles({
                workshop = true,
                water_wheel = true,
                copper_furnace = true,
                steam_engine = true,
                power_house = true,
            })
            -- cu masina: cei patru ai bobinelor si Clerk-ul Depoului; cu Power House, si cei patru ai curentului
            check.equal(#steam, #era2 + #StationConfig.LINE_STEPS.coils + 1)
            -- toate meseriile satului (Erele 1-3), nu cele ale barajului: alta harta
            check.equal(
                #all,
                #StationConfig.ERA1_ROLES + #StationConfig.ERA2_ROLES + #StationConfig.ERA3_ROLES
            )
            check.is_true(table.find(steam, "clerk") ~= nil)
            check.is_true(table.find(steam, "electrician") == nil)
        end)

        test.case("[D70] ghidajul asteapta doar oamenii hartii tale", function()
            local everything = {
                workshop = true,
                water_wheel = true,
                copper_furnace = true,
                steam_engine = true,
                power_house = true,
                crystal_kiln = true,
            }
            for _, role in GuideMath.guidedRoles(everything) do
                check.is_true((StationConfig.ERA_OF_ROLE[role] or 1) <= 3)
            end
            check.equal(#GuideMath.guidedRoles(everything), #GuideMath.guidedRoles(everything, 1))
            -- la baraj, doar meseriile Erei 4 (azi niciuna in joc; dupa comutator, ale liniilor deschise)
            for _, role in GuideMath.guidedRoles(everything, 2) do
                check.equal(StationConfig.ERA_OF_ROLE[role], 4)
            end
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
            check.is_true(string.find(planks.text, "Tavern", 1, true) ~= nil)
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
                    text = "Catch a fish",
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
            "[D62] quest-ul care arata avizierul satului isi are sageata chiar daca ghidajul tace",
            function()
                local board = TycoonConfig.VILLAGE_BOARD
                local st = state({ pads = pads({ "first_net" }), crews = WOOD_CREWS })
                st.allCrewsHired = true
                st.quest = {
                    key = "buy_decor",
                    text = "Build something in your village",
                    x = board.x,
                    y = board.y,
                    kind = "decor",
                    progress = 0,
                    goal = 1,
                }
                local g = GuideMath.pickGoal(st) :: GuideMath.Goal
                check.equal(g.kind, "goto")
                check.equal(g.x, board.x)
                check.equal(g.y, board.y)
                check.equal(g.text, "Build something in your village")
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
            check.is_true(string.find(logs.text, "Sawmill", 1, true) ~= nil)
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

    test.suite("GuideMath - turul de mana al Morii [D65]", function()
        local PARTS = TycoonConfig.LINE_PLACES.parts
        local MARKET = TycoonConfig.SELLER_PLACES.market
        -- toti oamenii Erei 1 sunt angajati cand ajungi la Moara
        local ERA1: { [string]: number } = {}
        for _, role in StationConfig.ERA1_ROLES do
            ERA1[role] = 1
        end
        local function crews(extra: { [string]: number }): { [string]: number }
            local out = table.clone(ERA1)
            for role, n in extra do
                out[role] = n
            end
            return out
        end
        local function line(raw: number, store: number, input: number, output: number)
            return { parts = { raw = raw, store = store, input = input, output = output } }
        end

        test.case("scrap-ul Morii din traista merge la turnatorie, nu la gater", function()
            local g = GuideMath.loopStep(
                state({ sackCount = 8, lines = line(8, 0, 0, 0), crews = crews({}) }),
                nil
            )
            check.equal(g.kind, "deliver")
            check.equal(g.key, "foundry")
            check.equal(g.text, "Take the scrap to the Foundry")
            check.equal(g.x, PARTS.playerStand.x)
            check.equal(g.y, PARTS.playerStand.y)
            -- plina: aceeasi tinta, cu textul traistei pline
            local full = GuideMath.loopStep(
                state({
                    sackCount = 30,
                    sackCapacity = 30,
                    lines = line(30, 0, 0, 0),
                    crews = crews({}),
                }),
                nil
            )
            check.equal(full.text, "Sack full — take the scrap to the Foundry")
        end)

        test.case("cat se toarna fara Founder, pasul e inelul turnatoriei", function()
            local g =
                GuideMath.loopStep(state({ lines = line(0, 0, 6, 0), crews = crews({}) }), nil)
            check.equal(g.kind, "work")
            check.equal(g.text, "Stay in the ring: 6 left to cast")
            check.equal(g.x, PARTS.playerStand.x)
            -- cu Founder angajat nu mai e pasul tau
            local hired = GuideMath.loopStep(
                state({ lines = line(0, 0, 6, 0), crews = crews({ founder = 1 }) }),
                nil
            )
            check.is_true(hired.kind ~= "work")
        end)

        test.case("piesele gata se iau, apoi se vand la Piata", function()
            local take =
                GuideMath.loopStep(state({ lines = line(0, 0, 0, 5), crews = crews({}) }), nil)
            check.equal(take.kind, "take")
            check.equal(take.text, "Take the parts at the Foundry")
            -- `sackCut` numara doar ce cumpara taverna (serverul: cut = sellBy.dock.count): piesele nu sunt in el
            local sell = GuideMath.loopStep(
                state({
                    sackCount = 5,
                    sackCut = 0,
                    sellAt = { market = 5, dock = 0 },
                    lines = line(0, 0, 0, 0),
                    crews = crews({}),
                }),
                nil
            )
            check.equal(sell.kind, "sell")
            check.equal(sell.key, "market")
            check.equal(sell.text, "Sell at the Market")
            check.equal(sell.x, MARKET.door.x)
            check.equal(sell.y, MARKET.door.y)
        end)

        test.case("scanduri si piese in aceeasi traista: intai taverna, apoi Piata", function()
            local st = state({
                sackCount = 9,
                sackCut = 4,
                sellAt = { dock = 4, market = 5 },
                lines = line(0, 0, 0, 0),
                crews = crews({}),
            })
            check.equal(GuideMath.loopStep(st, nil).key, "dock")
            st.sackCount, st.sackCut, st.sellAt = 5, 0, { dock = 0, market = 5 }
            check.equal(GuideMath.loopStep(st, nil).key, "market")
            -- iar fara quest, traista plina de piese trimite tot la Piata, nu la gater
            local full = GuideMath.pickGoal(state({
                pads = pads({ "first_net" }),
                sackCount = 30,
                sackCapacity = 30,
                sackCut = 0,
                sellAt = { dock = 0, market = 30 },
                lines = line(0, 0, 0, 0),
                crews = crews({}),
            })) :: GuideMath.Goal
            check.equal(full.key, "market")
            check.equal(full.text, "Sack full — sell at the Market")
        end)

        test.case("magazia Morii fara Mill Porter, plasele ei fara Mill Collector", function()
            local store =
                GuideMath.loopStep(state({ lines = line(0, 7, 0, 0), crews = crews({}) }), nil)
            check.equal(store.kind, "take")
            check.equal(store.text, "Take the scrap from the Mill Store")
            check.equal(store.x, PARTS.storeStand.x)
            local net =
                { padId = "sixth_net", x = 2300, y = 812, count = 4, capacity = 12, line = "parts" }
            local collect = GuideMath.loopStep(
                state({ nets = { net }, lines = line(0, 0, 0, 0), crews = crews({}) }),
                nil
            )
            check.equal(collect.kind, "collect")
            check.equal(collect.key, "net:sixth_net")
            check.equal(collect.text, "Collect the scrap from your net")
            -- cu Mill Collector, plasa nu mai e a ta
            local hired = GuideMath.loopStep(
                state({
                    nets = { net },
                    lines = line(0, 0, 0, 0),
                    crews = crews({ millCollector = 1 }),
                }),
                nil
            )
            check.equal(hired.key, "catching")
        end)

        test.case("quest-ul care arata roata de apa are sageata si cand ghidajul tace", function()
            local st = state({ pads = pads({ "first_net" }), coins = 9999, allCrewsHired = true })
            st.quest = {
                key = "build_wheel",
                text = "Build the Water Wheel",
                x = 2010,
                y = 812,
                padId = "water_wheel",
                price = 5000,
                kind = "pad",
                always = true,
            }
            local g = GuideMath.pickGoal(st) :: GuideMath.Goal
            check.is_true(g ~= nil)
            check.equal(g.kind, "buy")
            check.equal(g.padId, "water_wheel")
            -- fara `always`, ghidajul care tace ramane tacut
            st.quest.always = nil
            check.is_true(GuideMath.pickGoal(st) == nil)
        end)

        test.case("fara Moara, bucla Erei 1 e cea de pana acum", function()
            -- aceleasi stari, cu si fara campurile Morii goale: acelasi pas
            for _, over in
                {
                    { sackCount = 12 },
                    { sackCount = 12, sackCut = 12 },
                    { sackCount = 5, sackRawScrap = 5 },
                    { sawIn = 3 },
                    { sawOut = 3 },
                    { storage = 9 },
                }
            do
                local plain = GuideMath.loopStep(state(over), nil)
                local withMill = table.clone(over) :: any
                withMill.lines = line(0, 0, 0, 0)
                withMill.sellAt = { dock = (over :: any).sackCut or 0, market = 0 }
                local same = GuideMath.loopStep(state(withMill), nil)
                check.equal(same.key, plain.key)
                check.equal(same.text, plain.text)
            end
        end)
    end)

    test.suite("GuideMath - barajul (lumea 2) [D70, pasul k3]", function()
        -- locurile satului: la baraj, nicio tinta nu e aici si nicio cheie nu e a lor
        local VILLAGE_KEYS: { [string]: boolean } = {
            sawmill = true,
            forge = true,
            dock = true,
            storage = true,
            shed = true,
            cut = true,
            smelt = true,
            planks = true,
            iron = true,
            ["pad:first_net"] = true,
        }
        local VILLAGE_SPOTS = {
            TycoonConfig.SAWMILL_STAND,
            TycoonConfig.WORKSHOP_STAND,
            TycoonConfig.DOCK,
            TycoonConfig.STORAGE_STAND,
            TycoonConfig.SCRAP_SHED_STAND,
        }
        local function villageTarget(goal: GuideMath.Goal?): boolean
            if goal == nil then
                return false
            end
            local g = goal :: GuideMath.Goal
            -- cheia, si sub prefixul „earn:...:” al unui quest fara bani
            local key = string.match(g.key, "([^:]+)$") or g.key
            if VILLAGE_KEYS[g.key] or VILLAGE_KEYS[key] then
                return true
            end
            for _, spot in VILLAGE_SPOTS do
                if g.x == spot.x and g.y == spot.y then
                    return true
                end
            end
            return false
        end
        -- starile care, in sat, trimit la gater, forja, taverna, depozit, shed sau prima plasa
        local CASES: { { [string]: any } } = {
            { sackCount = 5 }, -- busteni in traista
            { sackCount = 5, sackCapacity = 5 }, -- traista plina de „busteni”
            { sackCount = 3, sackRawScrap = 3 },
            { sackCount = 4, sackCut = 4, firstsSell = true },
            { sawIn = 3 },
            { forgeIn = 2 },
            { sawOut = 2 },
            { forgeOut = 2 },
            { storage = 4 },
            { shed = 4 },
            { pads = {} }, -- nimic cumparat
        }
        test.case(
            "in sat, starile cazurilor chiar trimit la locurile satului (testul are rost)",
            function()
                local hits = 0
                for _, over in CASES do
                    local loop = GuideMath.loopStep(state(over), nil)
                    local pick = GuideMath.pickGoal(state(over))
                    if villageTarget(loop) or villageTarget(pick) then
                        hits += 1
                    end
                end
                check.equal(hits, #CASES)
            end
        )
        test.case(
            "la baraj, nicio stare nu trimite la gater, forja, taverna, depozit, shed sau prima plasa",
            function()
                for _, over in CASES do
                    local s = table.clone(over)
                    s.world = 2
                    check.is_false(villageTarget(GuideMath.loopStep(state(s), nil)))
                    check.is_false(villageTarget(GuideMath.pickGoal(state(s))))
                    -- si un quest de cumparare fara bani (pasul buclei, cu prefixul lui)
                    s.quest = { key = "q", text = "Buy", x = 1, y = 1, kind = "pad", price = 1e9 }
                    check.is_false(villageTarget(GuideMath.pickGoal(state(s))))
                end
            end
        )
        -- [D70, pasul k5] primul tur de mana la baraj: veteranii duc butoaiele, tu faci cablul de la plasa pana la Switch House
        test.case("turul cablului, pas cu pas, cu Era 4 in joc", function()
            if not TycoonConfig.eraIsLive(4) then
                return -- adormit: liniile barajului nu sunt in joc (verificat pe harta comutatorului)
            end
            local veterans =
                { damCollector = 1, damPorter = 1, switchman = 1, barrelHauler = 1, dispatcher = 1 }
            local function lines(over: { [string]: any }): { [string]: GuideMath.LineInfo }
                local out: { [string]: GuideMath.LineInfo } = {}
                for _, line in StationConfig.LINE_ORDER do
                    out[line] = { raw = 0, store = 0, input = 0, output = 0 }
                end
                for line, info in over do
                    out[line] = info
                end
                return out
            end
            local function step(over: { [string]: any }): GuideMath.Goal
                local s = table.clone(over)
                s.world = 2
                s.crews = veterans
                s.pads = s.pads or { dam_turbine = "bought", cable_net = "bought" }
                return GuideMath.loopStep(state(s), nil)
            end
            local cableNet = TycoonConfig.byId.cable_net
            local net = {
                padId = "cable_net",
                x = cableNet.x :: number,
                y = cableNet.y :: number,
                count = 5,
                capacity = 12,
                line = "cable",
            }
            check.equal(step({ nets = { net }, lines = lines({}) }).key, "net:cable_net")
            local raw = step({
                sackCount = 5,
                lines = lines({ cable = { raw = 5, store = 0, input = 0, output = 0 } }),
            })
            check.equal(raw.text, Strings.guideRawTo(Strings.LINE_WORDS.cable))
            check.equal(
                step({ lines = lines({ cable = { raw = 0, store = 0, input = 5, output = 0 } }) }).key,
                "work:cable"
            )
            check.equal(
                step({ lines = lines({ cable = { raw = 0, store = 0, input = 0, output = 5 } }) }).key,
                "done:cable"
            )
            check.equal(
                step({ sackCount = 5, parts = { grid = 5 }, lines = lines({}) }).key,
                "relay"
            )
            check.equal(
                step({ lines = lines({ grid = { raw = 0, store = 0, input = 5, output = 0 } }) }).key,
                "work:grid"
            )
            check.equal(
                step({ lines = lines({ grid = { raw = 0, store = 0, input = 0, output = 5 } }) }).key,
                "done:grid"
            )
            local sell = step({ sackCount = 5, sellAt = { town = 5 }, lines = lines({}) })
            check.equal(sell.key, "town")
            check.equal(sell.x, TycoonConfig.SELLER_PLACES.town.door.x)
        end)

        test.case("piesele din traista merg la inelul unirii lor (cu Era 4 in joc)", function()
            if not TycoonConfig.eraIsLive(4) then
                return -- adormit: nicio unire in joc (verificat pe harta comutatorului)
            end
            local stand = TycoonConfig.JOIN_PLACES.grid.playerStand
            local goal =
                GuideMath.loopStep(state({ world = 2, sackCount = 3, parts = { grid = 3 } }), nil)
            check.equal(goal.x, stand.x)
            check.equal(goal.y, stand.y)
            check.equal(goal.text, Strings.guideRawTo(Strings.LINE_WORDS.grid))
            -- [verificatorul k3] doar cablu in traista: textul numeste doar cablul
            local cableOnly = GuideMath.loopStep(
                state({
                    world = 2,
                    sackCount = 3,
                    parts = { grid = 3 },
                    sackContents = { cable = 3 },
                }),
                nil
            )
            check.equal(
                cableOnly.text,
                Strings.guidePartTo(Strings.LINE_WORDS.cable, Strings.LINE_WORDS.grid)
            )
            check.equal(cableOnly.x, stand.x)
            local bothParts = GuideMath.loopStep(
                state({
                    world = 2,
                    sackCount = 3,
                    parts = { grid = 3 },
                    sackContents = { cable = 1, barrel = 2 },
                }),
                nil
            )
            check.equal(bothParts.text, Strings.guideRawTo(Strings.LINE_WORDS.grid))
            -- traista plina de piese: tot acolo, cu textul traistei pline
            local full = GuideMath.pickGoal(state({
                world = 2,
                sackCount = 30,
                sackCapacity = 30,
                parts = { grid = 30 },
                pads = { dam_turbine = "bought" },
            }))
            check.is_true(full ~= nil)
            check.equal((full :: GuideMath.Goal).x, stand.x)
            check.equal((full :: GuideMath.Goal).text, Strings.sackFullRaw("grid"))
            -- piese la Relay si niciun Relay Keeper: stai in inelul lui; curent gata si niciun Pylon Runner: il iei
            local lines = { grid = { raw = 0, store = 0, input = 2, output = 0 } }
            local work = GuideMath.loopStep(state({ world = 2, lines = lines }), nil)
            check.equal(work.key, "work:grid")
            check.equal(work.x, stand.x)
            lines.grid = { raw = 0, store = 0, input = 0, output = 4 }
            local take = GuideMath.loopStep(state({ world = 2, lines = lines }), nil)
            check.equal(take.key, "done:grid")
            check.equal(take.x, stand.x)
        end)
    end)

    test.suite("GuideMath - pasii de venit si platformele incuiate [D70, pasul k5]", function()
        local ambition =
            { text = "Relay Station to level 10", upgradeKind = "relay", upgradeId = nil }
        test.case(
            "un quest de venit: fara sageata si fara pret; pasul numeste ce se mai poate urca",
            function()
                local st = state({ coins = 5, pads = pads({ "first_net" }, { "second_net" }) })
                st.quest = {
                    key = "earn_1t",
                    text = "Earn 1T coins a second",
                    kind = "income",
                    progress = 1,
                    goal = 10,
                }
                st.ambition = ambition
                local g = GuideMath.pickGoal(st) :: GuideMath.Goal
                check.equal(g.x, nil)
                check.equal(g.price, nil)
                check.equal(g.text, ambition.text)
                check.equal(g.upgradeKind, "relay")
                -- [verificatorul k5] si cu toti oamenii angajati (ghidajul tace): la baraj asa vine „Earn 1T”
                st.allCrewsHired = true
                local silent = GuideMath.pickGoal(st) :: GuideMath.Goal
                check.not_nil(silent)
                check.equal(silent.text, ambition.text)
                check.equal(silent.x, nil)
                check.equal(silent.price, nil)
                st.allCrewsHired = false
                -- fara tinta de urcat: textul quest-ului, tot fara pret
                st.ambition = nil
                local plain = GuideMath.pickGoal(st) :: GuideMath.Goal
                check.equal(plain.text, "Earn 1T coins a second")
                check.equal(plain.price, nil)
            end
        )
        test.case(
            "o platforma inca incuiata: sageata spre ea, fara pret si fara „While you save”",
            function()
                local st = state({ coins = 5, pads = pads({ "first_net" }) })
                st.pads.second_net = "outline"
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
                check.equal(g.x, 820)
                check.equal(g.price, nil)
                check.equal(g.kind, "goto")
                -- cu toti oamenii angajati (ghidajul tace) si dupa primul peste: nici indiciul pontonului cu pret
                local quiet = state({
                    coins = 5,
                    pads = pads({ "first_net" }),
                    allCrewsHired = true,
                    hasFished = true,
                })
                quiet.pads.second_net = "outline"
                quiet.hasFished = true
                quiet.quest = st.quest
                check.equal(GuideMath.pickGoal(quiet), nil)
            end
        )
    end)

    test.suite("GuideMath - drumul spre baraj [D70, pasul k6]", function()
        test.case(
            "barajul se poate ridica: fara quest, sageata spre Dam Plans, si cand ghidajul tace",
            function()
                local at = TycoonConfig.DAM_PLANS
                local st = state({ allCrewsHired = true, pads = pads({ "first_net" }) })
                st.damPlans = { x = at.x, y = at.y }
                local g = GuideMath.pickGoal(st) :: GuideMath.Goal
                check.equal(g.key, "dam_plans")
                check.equal(g.x, at.x)
                check.equal(g.text, Strings.PLANS_WHEN_READY)
                -- [verificatorul k6] cardul mesei se masoara din (x, y - 20): e cardul tintei, deci ghidajul se retrage
                check.is_true(GuideMath.isGoalCard(g, at.x, at.y - 20))
                -- un quest activ are intaietate (al satului, inca de facut)
                st.quest = {
                    key = "q",
                    text = "Cast a net",
                    x = 1,
                    y = 2,
                    kind = "pad",
                    padId = "second_net",
                }
                st.allCrewsHired = false
                check.equal((GuideMath.pickGoal(st) :: GuideMath.Goal).key, "quest:q")
                -- fara baraj gata, ghidajul tace ca inainte
                local quiet = state({ allCrewsHired = true, pads = pads({ "first_net" }) })
                check.equal(GuideMath.pickGoal(quiet), nil)
            end
        )
    end)

    test.suite("GuideMath - langa tinta, cardul E al tintei [2026-09-30]", function()
        local function dist(ax: number, ay: number, bx: number, by: number): number
            return math.sqrt((ax - bx) ^ 2 + (ay - by) ^ 2)
        end
        local function place(key: string, x: number, y: number): GuideMath.Goal
            return { kind = "goto", key = key, text = "", x = x, y = y, immediate = true }
        end

        test.case("capatul pontonului: pescuitul bate barca cat ghidajul s-a retras", function()
            -- cardul pontonului se masoara din FISH_STAND, al barcii din FERRY_BOARD (fara `at`: nu e un loc-tinta)
            local fish, ferry = TycoonConfig.FISH_STAND, TycoonConfig.FERRY_BOARD
            local goal = place("quest:catch_fish", fish.x, fish.y)
            local band = 0
            for y = fish.y, fish.y + GuideMath.NEAR_DISTANCE - 1 do
                local px, py = fish.x, y
                local cards: { GuideMath.CardCandidate } = {
                    { distance = dist(px, py, ferry.x, ferry.y), content = true },
                    { distance = dist(px, py, fish.x, fish.y), at = fish, content = true },
                }
                local pick, why = GuideMath.pickCard(cards, goal, px, py)
                check.equal(pick, 2)
                check.equal(why, "goal")
                -- undita aruncata tine E: cardul pontonului (fara nimic de aratat) bate barca [verificator]
                local busy: { GuideMath.CardCandidate } = {
                    cards[1],
                    { distance = cards[2].distance, at = fish, content = false, holds = true },
                }
                local busyPick, busyWhy = GuideMath.pickCard(busy, goal, px, py)
                check.equal(busyPick, 2)
                check.equal(busyWhy, "holds")
                check.equal((GuideMath.pickCard(busy, nil, px, py)), 2)
                local ferryNearer = cards[1].distance < cards[2].distance
                if ferryNearer then
                    band += 1
                end
                -- fara tinta acolo (alt pas), ramane cel mai apropiat
                check.equal((GuideMath.pickCard(cards, nil, px, py)), if ferryNearer then 1 else 2)
            end
            check.equal(band > 0, true) -- fasia exista: fara regula, aici se vedea doar barca
            -- din dreptul barcii (mai departe de tinta decat NEAR_DISTANCE) barca e iar a ta
            local bx, by = ferry.x, ferry.y
            check.equal(GuideMath.nearGoal(goal, bx, by), false)
            local atBoat: { GuideMath.CardCandidate } = {
                { distance = 0, content = true },
                { distance = dist(bx, by, fish.x, fish.y), at = fish, content = true },
            }
            check.equal((GuideMath.pickCard(atBoat, goal, bx, by)), 1)
        end)

        test.case("avizierul: cardul lui bate placuta rotii langa tinta", function()
            -- amandoua se masoara de la 20 px deasupra locului; tinta ghidajului e locul avizierului
            local board, wheel = TycoonConfig.VILLAGE_BOARD, TycoonConfig.WHEEL_STAND
            local goal = place("quest:buy_decor", board.x, board.y)
            local boardAt = { x = board.x, y = board.y - 20 }
            local band = 0
            for x = board.x - GuideMath.NEAR_DISTANCE + 1, board.x do
                local px, py = x, board.y
                local cards: { GuideMath.CardCandidate } = {
                    { distance = dist(px, py, wheel.x, wheel.y - 20), content = true },
                    { distance = dist(px, py, boardAt.x, boardAt.y), at = boardAt, content = true },
                }
                if cards[1].distance < cards[2].distance then
                    band += 1
                end
                check.equal((GuideMath.pickCard(cards, goal, px, py)), 2)
            end
            check.equal(band > 0, true)
        end)

        test.case("cardul tintei fara nimic de aratat nu castiga; cel mai apropiat, da", function()
            local goal = place("step:cut", 100, 100)
            local cards: { GuideMath.CardCandidate } = {
                { distance = 30, content = true },
                { distance = 10, at = { x = 100, y = 100 }, content = false },
                { distance = 50, content = true },
            }
            local pick, why = GuideMath.pickCard(cards, goal, 100, 110)
            check.equal(pick, 2) -- cel mai apropiat; InteractController il ascunde (n-are ce arata)
            check.equal(why, "near")
            check.equal((GuideMath.pickCard({}, goal, 100, 110)), nil)
        end)

        test.case("darul de pe rau bate cardul tintei si undita aruncata", function()
            -- ghidajul arata plasa (Collect / Filling up), iar pe rau trece un butoi: E il prinde, ca inainte
            local goal = place("net:first_net", 620, 812)
            local cards: { GuideMath.CardCandidate } = {
                { distance = 12, at = { x = 620, y = 812 }, content = true },
                { distance = 2, content = true, urgent = true },
                { distance = 1, content = true, urgent = true },
            }
            local pick, why = GuideMath.pickCard(cards, goal, 620, 800)
            check.equal(pick, 3) -- cel mai apropiat dar
            check.equal(why, "urgent")
            local quiet = table.clone(cards)
            quiet[3] = { distance = 1, content = false, urgent = true } -- un dar fara nimic de aratat nu ia nimic
            check.equal((GuideMath.pickCard(quiet, goal, 620, 800)), 2)
            -- cat astepti muscatura trece un butoi: E il ia (si, tinut, mulineaza mai departe) [verificator]
            local fishing = table.clone(cards)
            table.insert(fishing, { distance = 40, content = false, holds = true })
            local fp, fw = GuideMath.pickCard(fishing, goal, 620, 800)
            check.equal(fp, 3)
            check.equal(fw, "urgent")
            -- fara dar, undita aruncata tine E inaintea cardului tintei
            local rod: { GuideMath.CardCandidate } = {
                cards[1],
                { distance = 40, content = false, holds = true },
            }
            local rp, rw = GuideMath.pickCard(rod, goal, 620, 800)
            check.equal(rp, 2)
            check.equal(rw, "holds")
        end)

        test.case(
            "acelasi loc: 24 px de toleranta, iar o platforma de cumparat n-are card E",
            function()
                local goal = place("quest:x", 200, 300)
                check.equal(GuideMath.isGoalCard(goal, 224, 276), true)
                check.equal(GuideMath.isGoalCard(goal, 225, 300), false)
                check.equal(GuideMath.isGoalCard(nil, 200, 300), false)
                local pad = table.clone(goal)
                pad.padId = "second_net"
                check.equal(GuideMath.isGoalCard(pad, 200, 300), false)
            end
        )

        test.case(
            "platforma-tinta: cartonasul ei bate cardul unui obiect, doar langa ea",
            function()
                local goal: GuideMath.Goal = {
                    kind = "buy",
                    key = "pad:x",
                    text = "",
                    x = 500,
                    y = 500,
                    immediate = true,
                    padId = "hire_merchant",
                }
                check.equal(GuideMath.padIsGoal(goal, 540, 540, "hire_merchant"), true)
                check.equal(GuideMath.padIsGoal(goal, 540, 540, "hire_clerk"), false)
                check.equal(GuideMath.padIsGoal(goal, 540, 540, nil), false)
                check.equal(GuideMath.padIsGoal(goal, 600, 500, "hire_merchant"), false) -- 100 px: ghidajul inca arata
                local save = table.clone(goal)
                save.kind = "save" -- "strangi pentru X" nu e un loc: nimic nu castiga din cauza lui
                check.equal(GuideMath.padIsGoal(save, 500, 500, "hire_merchant"), false)
                check.equal(GuideMath.nearGoal(save, 500, 500), false)
            end
        )
    end)
end
