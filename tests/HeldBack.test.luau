-- [D40, D63] Cine tine pe loc un lucru care nu aduce nimic ACUM. Regula e una pentru meniul obiectului, panoul
-- Upgrades si cartonasul unei platforme; testele pornesc de la starea in care panoul a fost prins mintind.
local frktest = require("@frktest/frktest")
local test = frktest.test
local check = frktest.assert.check

local StationConfig = require("../src/Shared/Config/StationConfig")
local TycoonConfig = require("../src/Shared/Config/TycoonConfig")
local ChainMath = require("../src/Shared/Modules/ChainMath")
local HeldBack = require("../src/Shared/Modules/HeldBack")

-- Satul imediat dupa ce s-a deschis linia fierului: cinci plase la nivelul 1, toti cei noua oameni (cate unul,
-- treapta 1), traista mare, toate cladirile la nivelul 1. Lemnul e tinut de Taverna, fierul de Forja.
local function bothLines(): ChainMath.State
    local s = ChainMath.empty()
    for i = 1, 5 do
        table.insert(s.nets, {
            base = ChainMath.netBase(i),
            baseLane = StationConfig.NET_LANES[i],
            level = 1,
            kind = StationConfig.NET_KINDS[i],
        })
    end
    s.workshop, s.sackBig = true, true
    for _, role in StationConfig.ROLES do
        s.crews[role] = { count = 1, tier = 1 }
    end
    return s
end

local function viewOf(s: ChainMath.State): HeldBack.View
    return HeldBack.viewOf(ChainMath.flow(s))
end

-- O vedere scrisa de mana: veriga slaba si plasele fiecarei linii, debitele verigilor. Liniile nepomenite sunt inchise.
local function handView(
    bottleneck: string,
    lines: { [string]: HeldBack.LineView },
    linkRates: { [string]: number }
): HeldBack.View
    for _, line in StationConfig.LINE_ORDER do
        lines[line] = lines[line] or { catch = 0, bottleneck = "" }
    end
    return { bottleneck = bottleneck, lines = lines, linkRates = linkRates }
end

-- Satul cu Moara pornita: tot ce are `bothLines`, plus roata de apa, cuptorul, plasele 6-10 si oamenii Erei 2.
local function withMill(): ChainMath.State
    local s = bothLines()
    s.wheel, s.furnace = true, true
    for i = 6, 10 do
        table.insert(s.nets, {
            base = ChainMath.netBase(i),
            baseLane = StationConfig.NET_LANES[i],
            level = 1,
            kind = StationConfig.NET_KINDS[i],
        })
    end
    return s
end

local function levelGain(s: ChainMath.State, field: string): number
    return ChainMath.gainOf(s, function(p)
        local fields: any = p
        fields[field] += 1
    end)
end

return function()
    test.suite("HeldBack - cine tine pe loc un lucru care nu aduce nimic", function()
        test.case(
            "starea prinsa pe 2026-09-19: Taverna ADUCE bani, desi nu ea tine tot venitul",
            function()
                local s = bothLines()
                local view = viewOf(s)
                check.equal(view.bottleneck, "forge")
                check.equal(view.lines.wood.bottleneck, "dock")
                check.equal(view.lines.iron.bottleneck, "forge")
                -- un nivel la Taverna aduce mai mult decat unul la Forja: randul ei n-are voie sa scrie "No gain yet".
                -- Panoul se uita deci la castig, nu la steagul "sunt eu veriga care tine venitul" (aici: fals la Taverna).
                local dock, forge = levelGain(s, "dockLevel"), levelGain(s, "forgeLevel")
                check.is_true(dock > 0)
                check.is_true(dock > forge)
                check.is_true(forge > 0)
                check.equal(levelGain(s, "sawLevel"), 0)
            end
        )

        test.case(
            "fiecare rand fara castig numeste veriga LINIEI lui, nu pe cea care tine tot venitul",
            function()
                local view = viewOf(bothLines())
                -- plasele de lemn si gaterul: le tine Taverna (lemnul ia ce ramane dupa fier), nu Forja
                local key, tie = HeldBack.by(view, "nets", "wood")
                check.equal(key, "dock")
                check.is_false(tie)
                check.equal((HeldBack.by(view, "saw", "wood")), "dock")
                check.equal((HeldBack.by(view, "collect", "wood")), "dock")
                -- plasa de scrap si oamenii fierului: ii tine Forja
                check.equal((HeldBack.by(view, "nets", "iron")), "forge")
                check.equal((HeldBack.by(view, "ironHaul", "iron")), "forge")
                -- ce n-are veriga a lui (traista, clopotul): veriga care tine venitul
                check.equal((HeldBack.by(view, nil, nil)), "forge")
            end
        )

        test.case("veriga numita chiar aduce bani cand o ridici (sau e la egalitate)", function()
            local s = bothLines()
            local view = viewOf(s)
            local fieldOf = { dock = "dockLevel", forge = "forgeLevel", saw = "sawLevel" }
            for _, ask in { { "nets", "wood" }, { "saw", "wood" }, { "nets", "iron" } } do
                local key, tie = HeldBack.by(view, ask[1], ask[2])
                check.is_false(tie)
                check.is_true(levelGain(s, fieldOf[key :: string]) > 0)
            end
        end)

        test.case("linia fierului inchisa: nimic de reparat, doar nu vine inca nimic", function()
            local s = bothLines()
            table.remove(s.nets, 5) -- Forge cumparata, fara Fifth Net
            local view = viewOf(s)
            check.equal(view.lines.iron.bottleneck, "")
            local key = HeldBack.by(view, "forge", "iron")
            check.equal(key, nil)
            -- iar verigile fierului (debit 0) nu ies "cele mai lente" pentru un rand al lemnului
            local woodKey = HeldBack.by(view, view.lines.wood.bottleneck, "wood")
            check.is_true(StationConfig.LINE_OF[woodKey :: string] ~= "iron")
        end)

        test.case(
            "la egalitate spune cu cine: randul marcat slab, dar un nivel tot zero aduce",
            function()
                -- doua plase si un gater care taie exact cat prind ele n-am cum construi din niveluri; egalitatea se pune
                -- direct in vedere: plasele si Collector-ul merg la fel, plasele sunt marcate veriga slaba
                local view = handView(
                    "nets",
                    { wood = { catch = 2, bottleneck = "nets" } },
                    { collect = 2, port = 6, saw = 5, haul = 9, dock = 8 }
                )
                local key, tie = HeldBack.by(view, "nets", "wood")
                check.equal(key, "collect")
                check.is_true(tie)
                -- (Se cheama doar la castig zero: daca plasele ar fi STRICT cele mai lente, un nivel la ele ar aduce bani
                -- si randul n-ar mai intreba. De aceea "nu e mai lenta decat mine" inseamna aici "la fel de lenta".)
            end
        )

        test.case(
            "plasele carei linii: a randului; de la Taverna, a liniei in care plasele chiar tin",
            function()
                local view = handView("nets", {
                    wood = { catch = 1, bottleneck = "dock" },
                    iron = { catch = 1, bottleneck = "nets" },
                }, {})
                check.equal(HeldBack.netsLine(view, "wood"), "wood")
                check.equal(HeldBack.netsLine(view, "iron"), "iron")
                check.equal(HeldBack.netsLine(view, nil), "iron")
                check.equal(HeldBack.netsLine(view, nil, "dock"), "iron")
                view.lines.wood.bottleneck = "nets"
                check.equal(HeldBack.netsLine(view, nil), "wood")
                -- [D65] de la Piata: doar liniile ei (aici inchise), nu plasele satului vechi
                check.equal(HeldBack.netsLine(view, nil, "market"), "parts")
            end
        )

        test.case("veriga si linia unei platforme, din efectele ei", function()
            local function of(id: string): (string?, string?)
                return HeldBack.ofPad(TycoonConfig.byId[id])
            end
            local link, line = of("first_net")
            check.equal(link, "nets")
            check.equal(line, "wood")
            link, line = of("fifth_net")
            check.equal(link, "nets")
            check.equal(line, "iron")
            link, line = of("hire_porter")
            check.equal(link, "port")
            check.equal(line, "wood")
            link, line = of("hire_smelter")
            check.equal(link, "forge")
            check.equal(line, "iron")
            link, line = of("dock_trader") -- Innkeeper-ul: veriga Tavernei, a amandurora liniilor
            check.equal(link, "dock")
            check.equal(line, nil)
            for _, id in { "bigger_sack", "workshop", "landing_bell" } do
                link, line = of(id)
                check.equal(link, nil)
                check.equal(line, nil)
            end
            -- fiecare platforma de angajare a Erei 1 isi gaseste veriga
            for _, pad in TycoonConfig.PADS do
                if pad.era == 1 then
                    for _, e in pad.effects do
                        if e.kind == "hire" then
                            check.is_true((HeldBack.ofPad(pad)) ~= nil)
                        end
                    end
                end
            end
        end)
    end)

    test.suite("HeldBack - doua cartiere [D65]", function()
        test.case(
            "vederea din motor are fiecare linie si fiecare veriga, iar Era 1 singura e ca inainte",
            function()
                local s = bothLines()
                local view = viewOf(s)
                local r = ChainMath.rates(s)
                check.equal(view.lines.wood.catch, r.woodCatch)
                check.equal(view.lines.iron.catch, r.scrapCatch)
                check.equal(view.linkRates.saw, r.sawing)
                check.equal(view.linkRates.forge, r.forging)
                check.equal(view.linkRates.dock, r.sales)
                check.equal(view.lines.parts.bottleneck, "") -- Moara inca inchisa
                check.equal(view.lines.copper.bottleneck, "")
                for _, link in StationConfig.LINKS do
                    if link ~= "nets" then
                        check.is_true(view.linkRates[link] ~= nil)
                    end
                end
            end
        )

        test.case(
            "cu Moara inchisa, veriga care tine venitul Erei 1 e chiar cea a lantului intreg",
            function()
                -- stari la intamplare (bitii de sus ai unui LCG: cei de jos au perioada scurta)
                local seed = 20260919
                local function pick(n: number): number
                    seed = (seed * 1103515245 + 12345) % 2147483648
                    return math.floor(seed / 65536) % n
                end
                for _ = 1, 400 do
                    local s = ChainMath.empty()
                    local nets = 1 + pick(5)
                    for i = 1, nets do
                        table.insert(s.nets, {
                            base = ChainMath.netBase(i),
                            baseLane = StationConfig.NET_LANES[i],
                            level = 1 + pick(30),
                            kind = StationConfig.NET_KINDS[i],
                        })
                    end
                    s.workshop = pick(2) == 1
                    s.sackBig = pick(2) == 1
                    s.sawLevel, s.dockLevel, s.forgeLevel = 1 + pick(20), 1 + pick(20), 1 + pick(20)
                    for _, role in StationConfig.ERA1_ROLES do
                        s.crews[role] = { count = pick(3), tier = 1 + pick(5) }
                    end
                    check.equal(ChainMath.eraBottleneck(s, 1), ChainMath.flow(s).bottleneck)
                    check.equal(ChainMath.eraBottleneck(s, 2), "nets") -- nimic nu curge inca la Moara
                end
            end
        )

        test.case("cu Moara pornita, fiecare cartier isi are veriga lui", function()
            local s = withMill()
            local flow = ChainMath.flow(s)
            local first, second = ChainMath.eraBottleneck(s, 1), ChainMath.eraBottleneck(s, 2)
            -- veriga Erei 1 ramane cea de dinainte de Moara; a Erei 2 e una de-a ei
            check.equal(first, ChainMath.flow(bothLines()).bottleneck)
            check.is_true(first == "nets" or StationConfig.ERA_OF_LINK[first] == 1)
            check.is_true(second == "nets" or StationConfig.ERA_OF_LINK[second] == 2)
            -- iar una dintre ele e cea care tine tot venitul
            check.is_true(flow.bottleneck == first or flow.bottleneck == second)
        end)

        test.case("Taverna nu trimite la Moara, nici Piata in satul vechi", function()
            local view = viewOf(withMill())
            -- un vanzator fara castig: veriga slaba a primei lui linii deschise (de la scump la ieftin)
            check.equal(HeldBack.lineBottleneck(view, nil, "dock"), view.lines.iron.bottleneck)
            check.equal(HeldBack.lineBottleneck(view, nil, "market"), view.lines.copper.bottleneck)
            local tavern = HeldBack.by(view, "dock", nil)
            check.is_true(tavern == "nets" or StationConfig.ERA_OF_LINK[tavern :: string] == 1)
            local market = HeldBack.by(view, "market", nil)
            check.is_true(market == "nets" or StationConfig.ERA_OF_LINK[market :: string] == 2)
            -- iar randurile Morii intreaba pe liniile ei
            local key = HeldBack.by(view, "nets", "parts")
            check.is_true(
                key ~= nil and (key == "market" or StationConfig.ERA_OF_LINK[key :: string] == 2)
            )
        end)

        test.case("linia cuprului inchisa: nimic de reparat, doar nu vine inca nimic", function()
            local s = withMill()
            table.remove(s.nets, 10) -- cuptor cumparat, fara Tenth Net
            local view = viewOf(s)
            check.equal(view.lines.copper.bottleneck, "")
            check.equal((HeldBack.by(view, "furnace", "copper")), nil)
            -- Piata se uita atunci la linia pieselor
            check.equal(HeldBack.lineBottleneck(view, nil, "market"), view.lines.parts.bottleneck)
        end)

        test.case("platformele Erei 2 isi gasesc veriga si linia", function()
            local function of(id: string): (string?, string?)
                return HeldBack.ofPad(TycoonConfig.byId[id])
            end
            local link, line = of("sixth_net")
            check.equal(link, "nets")
            check.equal(line, "parts")
            link, line = of("tenth_net")
            check.equal(link, "nets")
            check.equal(line, "copper")
            link, line = of("hire_founder")
            check.equal(link, "foundry")
            check.equal(line, "parts")
            link, line = of("hire_merchant") -- negustorul: veriga Pietei, a amandurora liniilor ei
            check.equal(link, "market")
            check.equal(line, nil)
            for _, pad in TycoonConfig.PADS do
                for _, e in pad.effects do
                    if e.kind == "hire" then
                        check.is_true((HeldBack.ofPad(pad)) ~= nil)
                    end
                end
            end
        end)
    end)
end
