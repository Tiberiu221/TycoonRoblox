--!strict
-- [D70, pasul j14] „Build the Dam”, pur (DamMath.build / preview): ordinea pasilor, banii, oamenii, darurile barajului.
local frktest = require("@frktest/frktest")
local test = frktest.test
local check = frktest.assert.check

local DamMath = require("../src/Shared/Modules/DamMath")
local ChainMath = require("../src/Shared/Modules/ChainMath")
local ChainState = require("../src/Shared/Modules/ChainState")
local CrewMath = require("../src/Shared/Modules/CrewMath")
local PileMath = require("../src/Shared/Modules/PileMath")
local QuestMath = require("../src/Shared/Modules/QuestMath")
local StationConfig = require("../src/Shared/Config/StationConfig")
local TycoonConfig = require("../src/Shared/Config/TycoonConfig")

-- venitul startului de aur (golden_chain.py --dam-start; acelasi ca in ChainMath.test, „ChainState - din profil”)
local GOLDEN_DAM_INCOME = 19567696500.000008
local START = TycoonConfig.DAM_START_COINS
-- treptele meseriilor lemnului, toate diferite: medalia fiecarui veteran vine din meseria LUI [verificatorul j14]
local OLD_TIER: { [string]: number } =
    { collector = 2, porter = 3, sawyer = 5, hauler = 1, trader = 4 }
local NOW = 5000

local function damLive(era: number): boolean
    return era <= 4 -- barajul pornit, ca dupa comutatorul l3
end

-- pretul de proba: 10 monede bucata, ca suma „Last cart” sa se poata socoti
local function tenEach(counts: PileMath.Counts): number
    return PileMath.total(counts) * 10
end

local function ctx(): DamMath.Context
    return {
        now = NOW,
        userId = 4242,
        valueOfCounts = tenEach,
        model = ChainMath.FULL,
        eraIsLive = damLive,
    }
end

-- Un sat la Works Bell: toate platformele lumii 1, plasele la nivelul 30, gaterul si taverna la 30, forja la 20 (starea din
-- care golden_chain face startul de aur), cate doi oameni pe fiecare meserie a erelor 1-3, treapta 4.
local function village(coins: number, bought: number?): any
    local pads: { [string]: boolean } = {}
    local nets: { [string]: any } = {}
    local netGoods: { [string]: any } = {}
    for _, p in TycoonConfig.padsOfWorld(1) do
        pads[p.id] = true
        for _, e in p.effects do
            if e.kind == "net" then
                nets[p.id] = { level = 30 }
                netGoods[p.id] = { goods = {}, nextCatchAt = 0, caught = 0 }
            end
        end
    end
    local hands: { [string]: any } = {}
    local crews: { [string]: any } = {}
    local n = 0
    for era = 1, 3 do
        for _, role in StationConfig.ERA_ROLES_ALL[era] do
            crews[role] = { tier = OLD_TIER[role] or 4 }
            for i = 1, 2 do
                n += 1
                local key = CrewMath.personKey(role, i) :: string
                hands[key] = {
                    id = key,
                    role = role,
                    padId = TycoonConfig.CREWS[role].pad,
                    name = `Om{n}`,
                    appearance = {
                        body = "a",
                        hair = "bun",
                        skin = { 1, 2, n },
                        hairColor = { 4, 5, n },
                        outfit = "Fisher",
                    },
                    cycleStartAt = 1,
                    lastEventAt = 1,
                    carry = {},
                }
            end
        end
    end
    return {
        World = 1,
        Coins = coins,
        Pearls = 50,
        Pads = pads,
        Nets = netGoods,
        Sack = { items = {} },
        Index = {},
        Rebirths = 0,
        Hands = hands,
        Crews = crews,
        Quests = { claimed = {} },
        Stats = { coinsEarned = 0, damGift = 0 },
        Purchases = { ids = {}, passes = {}, coinsBought = bought or 0 },
        Firsts = {},
        Memories = {},
        Stations = {
            saw = { level = 30 },
            dock = { level = 30 },
            forge = { level = 20 },
            switchyard = { level = 1 },
            cableworks = { level = 1 },
            relay = { level = 1 },
            kiln = { level = 1 },
            town = { level = 1 },
            nets = nets,
        },
        Village = {},
    }
end

-- egalitate adanca, ca sa se vada ca ceva n-a fost atins
local function same(a: any, b: any): boolean
    if typeof(a) ~= "table" or typeof(b) ~= "table" then
        return a == b
    end
    for k, v in a do
        if not same(v, b[k]) then
            return false
        end
    end
    for k in b do
        if a[k] == nil then
            return false
        end
    end
    return true
end

return function()
    test.suite("DamMath - Build the Dam, pur [D70, pasul j14]", function()
        test.case("garzile: o singura data, dupa Works Bell, cu Era 4 in joc", function()
            local data = village(1e12)
            check.equal(DamMath.blocked(data, damLive), nil)
            check.equal(
                DamMath.blocked(data, function(era: number): boolean
                    return era <= 3
                end),
                "soon"
            )
            local noBell = village(1e12)
            noBell.Pads.works_bell = nil
            check.equal(DamMath.blocked(noBell, damLive), "bell")
            local receipt, why = DamMath.build(noBell, ctx())
            check.equal(receipt, nil)
            check.equal(why, "bell")
            -- azi Era 4 nu e in joc: fara `eraIsLive`, nimic nu se ridica
            if not TycoonConfig.eraIsLive(4) then
                check.equal(DamMath.blocked(village(1e12)), "soon")
            end
        end)

        test.case("a doua chemare nu face nimic", function()
            local data = village(50e12)
            local first = DamMath.build(data, ctx())
            check.not_nil(first)
            local after = DamMath.deepCopy(data)
            local again, why = DamMath.build(data, ctx())
            check.equal(again, nil)
            check.equal(why, "built")
            check.is_true(same(data, after))
            -- si cu lumea pusa inapoi pe 1 (o unealta de proba): tot o singura data [verificatorul j14]
            data.World = 1
            data.Coins += 7e13
            local back = DamMath.deepCopy(data)
            local third, why3 = DamMath.build(data, ctx())
            check.equal(third, nil)
            check.equal(why3, "built")
            check.is_true(same(data, back))
        end)

        test.case("banii: monede noi + dar = C + completare, pe toate ramurile", function()
            for _, case in
                {
                    { 50e12, 0 }, -- peste suma: darul
                    { 10e12, 0 }, -- sub suma: satul completeaza
                    { START, 0 }, -- exact suma
                    { 50e12, 3e12 }, -- monede Robux in mana: raman peste suma
                    { 2e12, 5e12 }, -- contorul mai mare decat monedele: R = C
                    { 0, 0 },
                } :: { { number } }
            do
                local data = village(case[1], case[2])
                local r = DamMath.build(data, ctx()) :: DamMath.Receipt
                check.equal(r.coinsBefore, case[1]) -- traista si gramezile goale: „Last cart” n-aduce nimic
                check.equal(r.kept, math.min(case[1], case[2]))
                check.equal(r.coinsAfter, START + r.kept)
                check.equal(data.Coins, r.coinsAfter)
                check.equal(r.coinsAfter + r.gift, r.coinsBefore + r.topUp)
                check.is_true(r.gift == 0 or r.topUp == 0)
                check.equal(data.Stats.damGift, r.gift)
                check.equal(data.Purchases.coinsBought, r.kept)
                check.equal(data.World, 2)
            end
            local over = DamMath.build(village(50e12), ctx()) :: DamMath.Receipt
            check.equal(over.gift, 50e12 - START)
            check.equal(over.topUp, 0)
            local under = DamMath.build(village(10e12), ctx()) :: DamMath.Receipt
            check.equal(under.gift, 0)
            check.equal(under.topUp, START - 10e12)
        end)

        test.case(
            "„Last cart”: traista, gramezile, plasele si ce duc oamenii, vandute si golite",
            function()
                local data = village(1e12)
                data.Sack.items = { { g = "driftwood" }, { g = "planks", p = true } }
                data.StoragePile = { counts = { driftwood = 5 } }
                data.DockPile = { counts = { planks = 3 }, drainedAt = 7 }
                data.Nets.first_net.goods = { { g = "driftwood" }, { g = "driftwood" } }
                data.Hands[CrewMath.personKey("hauler", 2) :: string].carry =
                    { { g = "planks", p = true } }
                data.Hands[CrewMath.personKey("collector", 1) :: string].carry =
                    { { g = "driftwood" } } -- un veteran: ce duce se vinde si el
                local r = DamMath.build(data, ctx()) :: DamMath.Receipt
                check.equal(r.pieces, 2 + 5 + 3 + 2 + 1 + 1)
                check.equal(r.lastCart, r.pieces * 10)
                check.equal(data.Stats.coinsEarned, r.lastCart)
                check.equal(r.coinsBefore, 1e12 + r.lastCart)
                check.equal(#data.Sack.items, 0)
                check.equal(next(data.StoragePile.counts), nil)
                check.equal(next(data.DockPile.counts), nil)
                check.equal(data.DockPile.drainedAt, 7) -- doar marfa pleaca, nu si ceasul gramezii
                check.equal(#data.Nets.first_net.goods, 0)
                check.not_nil(data.Nets.first_net) -- plasa ramane in profil, cu nivelul ei
                for _, hand in data.Hands do
                    check.equal(#hand.carry, 0)
                end
                -- gramezile barajului nu sunt ale satului: nu se ating
                for _, field in DamMath.OLD_PILES do
                    check.is_false(string.find(field, "Relay", 1, true) ~= nil)
                    check.is_false(field == "TownPile")
                end
            end
        )

        test.case("quest-urile satului se platesc in perle si se inchid", function()
            local data = village(1e12)
            local want = QuestMath.settleWorld({}, 1)
            local r = DamMath.build(data, ctx()) :: DamMath.Receipt
            check.equal(r.questPearls, want.pearls)
            check.equal(r.questsClosed, #want.quests)
            check.equal(data.Pearls, 50 + want.pearls)
            for _, id in want.quests do
                check.is_true(data.Quests.claimed[id] == true)
            end
        end)

        test.case(
            "oamenii: cinci veterani cu numele si chipul lor (copii), ceilalti iesiti din lucru",
            function()
                local data = village(1e12)
                local before = DamMath.deepCopy(data.Hands)
                -- referintele chipurilor de dinainte: ale veteranilor trebuie sa fie tabele noi
                local skinRef: { [string]: any } = {}
                for key, hand in data.Hands do
                    skinRef[key] = hand.appearance.skin
                end
                local keysBefore: { [string]: boolean } = {}
                for key in data.Hands do
                    keysBefore[key] = true
                end
                local r = DamMath.build(data, ctx()) :: DamMath.Receipt
                check.equal(#r.veterans, 5)
                -- singurele chei sterse sunt cele cinci vechi; restul sunt toate acolo
                local removed = 0
                for key in keysBefore do
                    if data.Hands[key] == nil then
                        removed += 1
                    end
                end
                check.equal(removed, 5)
                for _, v in DamMath.VETERANS do
                    local oldKey = CrewMath.personKey(v.from, 1) :: string
                    local newKey = CrewMath.personKey(v.to, 1) :: string
                    local old = before[oldKey]
                    local hand = data.Hands[newKey]
                    check.equal(data.Hands[oldKey], nil)
                    check.equal(hand.role, v.to)
                    check.equal(hand.name, old.name)
                    check.equal(hand.formerRole, v.from)
                    check.equal(hand.formerKey, oldKey)
                    check.equal(hand.medal, OLD_TIER[v.from]) -- treapta veche a meseriei lui, ca medalie
                    check.is_false(rawequal(hand.appearance.skin, skinRef[oldKey]))
                    check.equal(hand.retired, nil)
                    check.equal(hand.cycleStartAt, NOW)
                    check.equal(#hand.carry, 0)
                    check.is_true(same(hand.appearance.skin, old.appearance.skin))
                    check.is_true(same(hand.appearance.hairColor, old.appearance.hairColor))
                    check.equal(data.Crews[v.to].tier, 1)
                end
                -- copii, nu referinte: chipul veteranului nu se schimba cu al altcuiva
                local vet = data.Hands[CrewMath.personKey("damCollector", 1) :: string]
                -- fotografia satului e luata INAINTE de orice schimbare: era 3, toti oamenii, coliba Collector-ului
                local photo = data.Memories.oldVillage
                check.equal(photo.era, 3)
                check.equal(photo.crews.collector, 2)
                check.equal(#photo.hands, 54)
                for _, h in photo.hands do
                    for _, hand in data.Hands do
                        check.is_false(rawequal(h.appearance.skin, hand.appearance.skin))
                    end
                end
                vet.appearance.skin[1] = 99
                for _, h in data.Memories.oldVillage.hands do
                    check.is_true(
                        h.appearance == nil
                            or h.appearance.skin == nil
                            or h.appearance.skin[1] ~= 99
                    )
                end
                -- fiecare meserie a barajului adusa de veterani are exact un om; ceilalti oameni nu se mai numara
                local crews = CrewMath.fromProfile(data.Hands, data.Crews, ChainMath.FULL)
                for _, v in DamMath.VETERANS do
                    check.equal(crews[v.to].count, 1)
                    check.equal(crews[v.from].count, 0)
                end
                local retired = 0
                for _, hand in data.Hands do
                    if hand.retired == true then
                        retired += 1
                    end
                end
                check.equal(retired, r.retired)
                local everyone = 0
                for _ in before do
                    everyone += 1
                end
                check.equal(retired, everyone - 5)
            end
        )

        test.case(
            "un veteran care lipseste vine nou, cu un nume pe care nu-l mai poarta nimeni",
            function()
                local data = village(1e12)
                data.Hands[CrewMath.personKey("trader", 1) :: string] = nil
                local r = DamMath.build(data, ctx()) :: DamMath.Receipt
                local dispatcher = data.Hands[CrewMath.personKey("dispatcher", 1) :: string]
                check.not_nil(dispatcher)
                check.equal(dispatcher.formerRole, nil)
                check.equal(dispatcher.medal, nil)
                local names: { [string]: number } = {}
                for _, hand in data.Hands do
                    names[hand.name] = (names[hand.name] or 0) + 1
                end
                check.equal(names[dispatcher.name], 1)
                check.equal(#r.veterans, 5)
            end
        )

        test.case(
            "darurile barajului: turbina, Cable Net si casele veteranilor, fara angajare",
            function()
                check.equal(#DamMath.GIFTS, 7)
                for _, pad in DamMath.GIFTS do
                    check.equal(pad.era, 4) -- doar ale Erei 4, nu ale erelor de dupa ea din lumea 2
                end
                local data = village(1e12)
                DamMath.build(data, ctx())
                for _, pad in DamMath.GIFTS do
                    check.is_true(data.Pads[pad.id] == true)
                end
                check.equal(data.Nets.dam_turbine.nextCatchAt, NOW)
                check.equal(data.Stations.nets.dam_turbine.level, 1)
                check.equal(data.Stations.nets.cable_net.level, 1)
                check.is_true(data.Firsts.DamBuilt == true)
                -- platformele satului raman cumparate (clopotele, traista mare, titlul din balci)
                for _, p in TycoonConfig.padsOfWorld(1) do
                    check.is_true(data.Pads[p.id] == true)
                end
            end
        )

        test.case("venitul: dupa ridicare e startul de aur, si mai mare decat inainte", function()
            local data = village(1e12)
            -- venitul de dinainte, socotit pe satul neatins, cu acelasi model
            local copy = DamMath.deepCopy(data)
            local st0 = ChainState.from(copy, copy.Pads, ChainMath.FULL)
            local before = ChainMath.valueWith(
                ChainMath.FULL,
                st0,
                ChainMath.flowWith(ChainMath.FULL, st0, false)
            )
            local r = DamMath.build(data, ctx()) :: DamMath.Receipt
            check.equal(r.incomeBefore, before)
            check.is_true(before > 0)
            check.equal(r.incomeAfter, GOLDEN_DAM_INCOME)
            check.is_true(r.incomeAfter >= r.incomeBefore)
            local st = ChainState.from(data, data.Pads, ChainMath.FULL)
            check.is_true(st.dam)
            check.equal(st.bells, 1.3310000000000004)
            -- chitanta e scrisa si in profil (placa de pe coama, Memory Wall)
            check.equal(data.Memories.dam.coinsAfter, r.coinsAfter)
            check.equal(data.Memories.dam.at, NOW)
        end)

        test.case(
            "previzualizarea spune exact ce face ridicarea, fara sa atinga profilul",
            function()
                local data = village(50e12, 2e12)
                data.Sack.items = { { g = "driftwood" } }
                local before = DamMath.deepCopy(data)
                local seen = DamMath.preview(data, ctx()) :: DamMath.Receipt
                check.is_true(same(data, before))
                local done = DamMath.build(data, ctx()) :: DamMath.Receipt
                check.is_true(same(seen, done))
                local _, why = DamMath.preview(data, ctx())
                check.equal(why, "built")
            end
        )
    end)
end
