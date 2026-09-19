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
    local r = ChainMath.rates(s)
    return {
        bottleneck = r.bottleneck,
        woodBottleneck = r.woodBottleneck,
        ironBottleneck = r.ironBottleneck,
        rates = r :: any,
    }
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
                check.equal(view.woodBottleneck, "dock")
                check.equal(view.ironBottleneck, "forge")
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
            check.equal(view.ironBottleneck, "")
            local key = HeldBack.by(view, "forge", "iron")
            check.equal(key, nil)
            -- iar verigile fierului (debit 0) nu ies "cele mai lente" pentru un rand al lemnului
            local woodKey = HeldBack.by(view, view.woodBottleneck, "wood")
            check.is_true(StationConfig.LINE_OF[woodKey :: string] ~= "iron")
        end)

        test.case(
            "la egalitate spune cu cine: randul marcat slab, dar un nivel tot zero aduce",
            function()
                -- doua plase si un gater care taie exact cat prind ele n-am cum construi din niveluri; egalitatea se pune
                -- direct in vedere: plasele si Collector-ul merg la fel, plasele sunt marcate veriga slaba
                local view: HeldBack.View = {
                    bottleneck = "nets",
                    woodBottleneck = "nets",
                    ironBottleneck = "",
                    rates = {
                        woodCatch = 2,
                        catch = 2,
                        collect = 2,
                        port = 6,
                        sawing = 5,
                        haul = 9,
                        sales = 8,
                    },
                }
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
                local view: HeldBack.View = {
                    bottleneck = "nets",
                    woodBottleneck = "dock",
                    ironBottleneck = "nets",
                    rates = {},
                }
                check.equal(HeldBack.netsLine(view, "wood"), "wood")
                check.equal(HeldBack.netsLine(view, "iron"), "iron")
                check.equal(HeldBack.netsLine(view, nil), "iron")
                view.woodBottleneck = "nets"
                check.equal(HeldBack.netsLine(view, nil), "wood")
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
end
