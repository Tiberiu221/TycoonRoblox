local frktest = require("@frktest/frktest")
local test = frktest.test
local check = frktest.assert.check

local TycoonConfig = require("../src/Shared/Config/TycoonConfig")
local RiverConfig = require("../src/Shared/Config/RiverConfig")
local HandRoutes = require("../src/Shared/Modules/HandRoutes")
local VillageConfig = require("../src/Shared/Config/VillageConfig")
local Assets = require("../src/Shared/Config/Assets")
local Strings = require("../src/Shared/Config/Strings")

type Box = { x0: number, x1: number, y0: number, y1: number }

local function box(cx: number, bottom: number, w: number, h: number): Box
    return { x0 = cx - w / 2, x1 = cx + w / 2, y0 = bottom - h, y1 = bottom }
end

local function hit(a: Box, b: Box): boolean
    return a.x0 < b.x1 and b.x0 < a.x1 and a.y0 < b.y1 and b.y0 < a.y1
end

-- Marimea cladirii unei platforme cumparate; PadController o prinde la 8 px sub platforma.
-- [D53] Ruinele au amprenta cladirii lor, deci aceleasi cutii le acopera si pe ele. Atelierul nou e 64x48
-- (192x144). [D55] Cea mai LATA amprenta a fiecarui loc: colibele mari (doi oameni), taraba mare, shed-ul.
-- Avizierul (48x64) si colibele mici incap in ele.
local BOUGHT = {
    bigger_sack = { 48, 48 },
    dock_trader = { 128, 80 },
    landing_bell = { 120, 168 },
    workshop = { 192, 144 },
    first_runner = { 144, 120 },
    hire_porter = { 120, 102 },
    hire_sawyer = { 120, 102 },
    hire_hauler = { 120, 102 },
    scrap_shed = { 120, 96 },
    -- [D56] colibele mari ale oamenilor fierului
    hire_scrap_collector = { 120, 102 },
    hire_scrap_porter = { 120, 102 },
    hire_smelter = { 120, 102 },
    hire_iron_hauler = { 120, 102 },
}

-- [D50] Tot ce se deseneaza pe teren, in afara platformelor si drumurilor: cladirile (prinse de
-- baza), pontonul, oamenii (48x72, prinsi de picioare), gramezile cu cifra lor, cladirile
-- platformelor cumparate.
local function placed(): { [string]: Box }
    local things: { [string]: Box } = {}
    local ST, SM, TV = TycoonConfig.STORAGE, TycoonConfig.SAWMILL, TycoonConfig.TAVERN
    things.storage = box(ST.x, ST.y, ST.w, ST.h)
    things.sawmill = box(SM.x, SM.y, SM.w, SM.h)
    things.tavern = box(TV.x, TV.y, TV.w, TV.h)
    -- [D59] avizierul satului (40x44 la x2) sta pe punte; [D60] langa el, unde era roata, indicatorul ei (28x36 la x2)
    local post = Assets.props.signpost
    things.wheel =
        box(TycoonConfig.WHEEL_STAND.x, TycoonConfig.WHEEL_STAND.y, post.width * 2, post.height * 2)
    things.board = box(TycoonConfig.VILLAGE_BOARD.x, TycoonConfig.VILLAGE_BOARD.y, 80, 88)
    local PIER = TycoonConfig.PIER -- [D59] pontonul lung, 32x104 la x3, centrat
    things.pier = { x0 = PIER.x - 48, x1 = PIER.x + 48, y0 = PIER.y - 156, y1 = PIER.y + 156 }
    -- [D59] decorul cumparat cu perle care sta pe teren: acelasi test ca orice cladire (pontonul si apa au testul lor)
    for _, d in VillageConfig.DECOR do
        if d.ground == "land" then
            local art = (Assets.decor :: any)[d.sprite]
            for i, spot in d.spots do
                things[`decor_{d.id}_{i}`] =
                    box(spot.x, spot.y, art.width * d.scale, art.height * d.scale)
            end
        end
    end
    things.spawn = box(TycoonConfig.SPAWN.x, TycoonConfig.SPAWN.y, 48, 72)
    for _, role in { "sawyer", "trader", "smelter" } do
        for index = 1, 2 do
            local s = HandRoutes.standFor(role, index) :: { x: number, y: number }
            things[`{role}_{index}`] = box(s.x, s.y, 48, 72)
        end
    end
    for name, p in TycoonConfig.PILES do
        -- [D55] treapta cea mai mare (40x28 la x2 = 80x56), prinsa de baza, si cifra (52x24) deasupra ei sau,
        -- cand deasupra e o cladire, in dreapta
        if p.pill == "right" then
            things[`pile_{name}`] = { x0 = p.x - 40, x1 = p.x + 40 + 56, y0 = p.y - 56, y1 = p.y }
        else
            things[`pile_{name}`] = { x0 = p.x - 40, x1 = p.x + 40, y0 = p.y - 56 - 26, y1 = p.y }
        end
    end
    for id, size in BOUGHT do
        local p = TycoonConfig.byId[id]
        things[`building_{id}`] = box(p.x :: number, TycoonConfig.buildingBase(p), size[1], size[2])
    end
    return things
end

return function()
    test.suite("TycoonConfig", function()
        test.case("54 de platforme, index = pozitia in lista", function()
            -- Bugul pe care il apara testul: daca `index` se dezalinieaza de pozitia reala,
            -- padStatuses (care merge prin PADS in ordine) si greedyRun (care citeste PRICES[k])
            -- ar arata/cumpara platforma gresita fara nicio eroare.
            -- [D56] +4: oamenii fierului. [D65] 18 + 18: Era 2 e Era 1 in oglinda, platforma cu platforma, iar
            -- ramasitele erelor 2-4 de dinainte de D46 (35 de platforme, niciodata `live`) au iesit.
            -- [D67] +18: Era 3 e Moara in oglinda.
            -- [D70] +23: Era 4, barajul, adormita (pasul j2).
            check.equal(#TycoonConfig.PADS, 77)
            for i, p in TycoonConfig.PADS do
                check.equal(p.index, i)
            end
        end)

        test.case(
            "Era 1 are 18 deblocari, Era 2 si Era 3 la fel: fiecare e cea dinainte in oglinda [D65, D67]",
            function()
                -- Era 1 a scazut de la 12 la 10 cand Sorting Crate si Dock Stall au devenit niveluri
                -- ale debarcaderului, iar Weighted Nets pragul de nivel 10 al plaselor. Apoi 11 cu
                -- Sawyer-ul [D48], 13 cu Porter-ul si Hauler-ul [D49], 14 cu shed-ul de scrap [D55],
                -- 18 cu cei patru oameni ai fierului [D56]. Era 2: aceeasi schema, fara traista (o ai
                -- deja), cu roata de apa in fata. Erele urmatoare nu exista inca [D64].
                local perEra: { [number]: number } = {}
                for _, p in TycoonConfig.PADS do
                    perEra[p.era] = (perEra[p.era] or 0) + 1
                end
                check.equal(perEra[1], 18)
                check.equal(perEra[2], 18)
                check.equal(perEra[3], 18)
                -- [D70] Era 4 nu e in oglinda: 16 cumparate si 7 date de baraj (turbina, Cable Net, cei cinci veterani)
                check.equal(perEra[4], 23)
                check.equal(perEra[5], nil)
            end
        )

        test.case(
            "[l3] Era 4 e in joc: toate randurile ei, iar ce vine gratis cu barajul costa 0",
            function()
                local free = 0
                for _, p in TycoonConfig.PADS do
                    if p.era == 4 then
                        check.is_true(p.live)
                        if p.price == 0 then
                            free += 1
                        end
                    end
                end
                check.is_true(TycoonConfig.eraIsLive(4))
                check.equal(free, 7)
                for _, id in
                    {
                        "dam_turbine",
                        "cable_net",
                        "hire_dam_collector",
                        "hire_dam_porter",
                        "hire_switchman",
                        "hire_barrel_hauler",
                        "hire_dispatcher",
                    }
                do
                    check.equal(TycoonConfig.byId[id].price, 0)
                end
                check.equal(TycoonConfig.DAM_START_COINS, 9000000000000) -- [D78]
            end
        )

        test.case(
            "descrierea fiecarei platforme incape pe randul cartonasului (Nunito, 15 px)",
            function()
                -- [D70, verificator 2026-10-03] Randul are 380 px (HUDController: cartonasul 440 minus 2 x 30), un singur rand.
                -- 11 descrieri vii ieseau din el si se taiau cu "…". Latimile literelor sunt ale fontului din Studio
                -- (scripts/art/nunito_widths.py); suma lor iese cu cel mult ~5 px fata de textul randat, deci limita e 376. Un
                -- caracter pe care fontul nu-l are nu e in tabel, deci pica testul.
                local widths = require("./fonts/NunitoWidths") :: { [string]: number }
                local SIZE, LIMIT = 15, 376
                for _, p in TycoonConfig.PADS do
                    local w = 0
                    for _, code in utf8.codes(p.blurb) do
                        local ch = utf8.char(code)
                        check.not_nil(widths[ch])
                        w += (widths[ch] or 1000) * SIZE / 1000
                    end
                    if w > LIMIT then
                        print(
                            `[TycoonConfig] descrierea lui {p.id} are ~{math.floor(w)} px: {p.blurb}`
                        )
                    end
                    check.is_true(w <= LIMIT)
                end
            end
        )

        test.case("[D70] turbina barajului e turbina (cuvinte, verb, desen), plasele nu", function()
            check.is_true(TycoonConfig.isTurbine(TycoonConfig.byId.first_turbine))
            check.is_true(TycoonConfig.isTurbine(TycoonConfig.byId.dam_turbine))
            check.is_false(TycoonConfig.isTurbine(TycoonConfig.byId.first_net))
            check.is_false(TycoonConfig.isTurbine(TycoonConfig.byId.cable_net))
            check.equal(TycoonConfig.wordsKindOf("net", "dam_turbine"), "turbine")
            check.equal(TycoonConfig.wordsKindOf("net", "cable_net"), "net")
            check.equal(TycoonConfig.verbOf(TycoonConfig.byId.dam_turbine), "build")
            check.equal(TycoonConfig.verbOf(TycoonConfig.byId.crystal_net), "cast")
        end)

        test.case(
            "[D70] desenele de imprumut ale barajului: fiecare platforma alta pereche",
            function()
                local seen: { [string]: string } = {}
                for _, p in TycoonConfig.PADS do
                    local target = TycoonConfig.PAD_LOOKS_LIKE[p.id]
                    if p.era == 4 and target ~= nil then
                        check.equal(seen[target], nil)
                        seen[target] = p.id
                        check.not_nil(TycoonConfig.byId[target])
                        check.is_true(TycoonConfig.byId[target].era < 4)
                    end
                end
            end
        )

        test.case(
            "[D70] clopotul barajului cere venitul din StationConfig, plasele lui au rang",
            function()
                local StationConfig = require("../src/Shared/Config/StationConfig")
                local bell = TycoonConfig.byId.dam_bell
                check.equal((bell.needs :: any).income, StationConfig.DAM_BELL_INCOME)
                check.is_true((bell.needs :: any).all)
                -- rangul si era cadrului, ca `unlock_net_ranked` din simulator (acolo le verifica PAD_NETS_ERA4)
                local ranks = {
                    dam_turbine = 5,
                    cable_net = 1,
                    second_cable_net = 2,
                    third_cable_net = 3,
                    crystal_net = 5,
                }
                for _, p in TycoonConfig.PADS do
                    local isNet = false
                    for _, e in p.effects do
                        isNet = isNet or e.kind == "net"
                    end
                    if p.era == 4 and isNet then
                        check.equal(p.netRank, ranks[p.id])
                        check.equal(p.netEra, 4)
                    elseif p.era < 4 then
                        check.equal(p.netRank, nil)
                        check.equal(p.netEra, nil)
                    end
                end
            end
        )

        test.case(
            "[D70] platformele din drumul marfii (FlowConfig) exista, in era liniei lor",
            function()
                local FlowConfig = require("../src/Shared/Config/FlowConfig")
                for line, spec in FlowConfig.LINES_ALL do
                    for _, id in { spec.storePad, spec.processorPad } do
                        if id ~= nil then
                            local p = TycoonConfig.byId[id]
                            check.not_nil(p)
                            check.equal(p.era, spec.era)
                        end
                    end
                    if line == "crystal" then
                        check.equal(spec.processorPad, "crystal_kiln")
                        check.equal(spec.storePad, "crystal_shed")
                    end
                end
            end
        )

        test.case("id-urile sunt unice", function()
            -- Un id duplicat ar insemna ca al doilea suprascrie primul in byId, si o platforma
            -- ar deveni imposibil de cumparat (numele ar exista, dar id-ul ar duce la alta).
            local seen = {}
            for _, p in TycoonConfig.PADS do
                check.is_true(seen[p.id] == nil)
                seen[p.id] = true
            end
        end)

        test.case("byId gaseste exact aceeasi platforma", function()
            for _, p in TycoonConfig.PADS do
                check.is_true(TycoonConfig.byId[p.id] == p)
            end
        end)

        test.case("motivul e unul din C/V/A/D", function()
            local valid = { C = true, V = true, A = true, D = true }
            for _, p in TycoonConfig.PADS do
                check.is_true(valid[p.motive] == true)
            end
        end)

        test.case("fiecare era se termina cu propriul clopot (motiv D)", function()
            -- Regula celor patru motive: D deschide urmatorul. Daca clopotul nu e ultimul,
            -- padStatuses ar putea arata platforme din era urmatoare inainte de a termina asta.
            -- ultima platforma a fiecarei ere, oricare ar fi numarul lor
            local lastOfEra: { [number]: number } = {}
            for _, p in TycoonConfig.PADS do
                lastOfEra[p.era] = math.max(lastOfEra[p.era] or 0, p.index)
            end
            for _, p in TycoonConfig.PADS do
                check.equal(p.motive == "D", p.index == lastOfEra[p.era])
            end
        end)

        test.case("fiecare platforma are cel putin un efect", function()
            -- O platforma fara efect n-ar misca venitul deloc -- exact ce interzice regula
            -- celor patru motive in simulator.
            for _, p in TycoonConfig.PADS do
                check.is_true(#p.effects >= 1)
            end
        end)

        test.case(
            "ce prinde fiecare fel de plasa insumeaza 1, din bunuri cu valoare [D55]",
            function()
                local valued: { [string]: boolean } = {}
                for _, g in TycoonConfig.GOODS do
                    valued[g.id] = true
                end
                for _, parts in TycoonConfig.CATCH do
                    local sum = 0
                    for _, part in parts do
                        sum += part.share
                        check.is_true(valued[part.id] == true)
                    end
                    check.is_true(math.abs(sum - 1) < 1e-9)
                end
            end
        )

        test.case(
            "fierul valoreaza cat scrap-ul din care iese, scandura cat bustenul [D55]",
            function()
                local value: { [string]: number } = {}
                for _, g in TycoonConfig.GOODS do
                    value[g.id] = g.value
                end
                check.equal(value.iron, value.scrap)
                check.equal(value.planks, value.driftwood)
                check.is_true(value.iron > value.planks)
            end
        )

        test.case("platformele live au pozitie in lume", function()
            -- O platforma jucabila fara pozitie n-ar avea unde sa fie desenata/atinsa.
            for _, p in TycoonConfig.PADS do
                if p.live then
                    check.is_true(p.x ~= nil)
                    check.is_true(p.y ~= nil)
                end
            end
        end)

        -- F1: toata Era 1 e live (angajatul, atelierul, clopotul inclusiv). [D65] O ERA INTRA IN JOC INTREAGA SAU DELOC:
        -- cu jumatate din platforme live, clopotul ei (care cere tot restul erei) n-ar putea fi tras niciodata.
        test.case("live = Era 1 intreaga; orice alta era, toata sau deloc", function()
            local liveByEra: { [number]: number } = {}
            local countByEra: { [number]: number } = {}
            for _, p in TycoonConfig.PADS do
                countByEra[p.era] = (countByEra[p.era] or 0) + 1
                if p.live then
                    liveByEra[p.era] = (liveByEra[p.era] or 0) + 1
                end
            end
            check.equal(liveByEra[1], 18)
            for era, count in countByEra do
                local live = liveByEra[era] or 0
                check.is_true(live == 0 or live == count)
                check.equal(TycoonConfig.eraIsLive(era), live == count)
            end
        end)

        -- Latimea de desen a plasei vine acum din config (NET_DRAW), nu din cutia veche de 144:
        -- testul trebuie sa se miste odata cu ea, altfel pazeste o cifra care nu mai exista.
        test.case("plasele Erei 1 nu se suprapun, cu un spatiu de respiro intre ele", function()
            local byLane: { [number]: { number } } = {}
            for _, p in TycoonConfig.PADS do
                for _, e in p.effects do
                    if e.kind == "net" and p.era == 1 then
                        local lane = e.lane :: number
                        byLane[lane] = byLane[lane] or {}
                        table.insert(byLane[lane], p.x :: number)
                    end
                end
            end
            for _, xs in byLane do
                table.sort(xs)
                for i = 2, #xs do
                    check.is_true(xs[i] - xs[i - 1] >= TycoonConfig.NET_DRAW.w + 40)
                end
            end
        end)

        test.case("nicio platforma live nu se suprapune cu alta sau cu taverna", function()
            -- Platformele sunt BUTOANE de PAD_SIZE: doua cutii care se ating fura clicuri una
            -- alteia si se calca in desen. Bugul l-am prins mutand Dock Trader langa debarcader --
            -- coltul lui intra peste prima plasa cu 6 pixeli, cat sa nu se vada, dar sa conteze.
            local half = TycoonConfig.PAD_SIZE / 2
            local live: { { id: string, x: number, y: number } } = {}
            for _, p in TycoonConfig.padsOfWorld(1) do
                if p.live and p.x ~= nil and p.y ~= nil then
                    table.insert(live, { id = p.id, x = p.x :: number, y = p.y :: number })
                end
            end
            local clashes = 0
            for i = 1, #live do
                for j = i + 1, #live do
                    local a, b = live[i], live[j]
                    if
                        math.abs(a.x - b.x) < TycoonConfig.PAD_SIZE
                        and math.abs(a.y - b.y) < TycoonConfig.PAD_SIZE
                    then
                        clashes += 1
                    end
                end
            end
            check.equal(clashes, 0)

            -- si niciuna peste taverna (cladirea, prinsa de baza) [D50]
            local T = TycoonConfig.TAVERN
            local overTavern = 0
            for _, p in live do
                if
                    math.abs(p.x - T.x) < half + T.w / 2
                    and p.y + half > T.y - T.h
                    and p.y - half < T.y
                then
                    overTavern += 1
                end
            end
            check.equal(overTavern, 0)
        end)

        test.case("cladirile, oamenii si gramezile nu se calca si stau in zona", function()
            -- [D50] Tot ce se deseneaza pe teren, cu marimea reala. Doua lucruri care se suprapun
            -- se calca in desen, iar doua apasabile isi fura clicurile. Atingerea (margine pe
            -- margine) e voie: omul de la tejghea sta lipit de taverna.
            local things = placed()
            local clashes = {}
            local names = {}
            for name in things do
                table.insert(names, name)
            end
            table.sort(names)
            for i = 1, #names do
                for j = i + 1, #names do
                    if hit(things[names[i]], things[names[j]]) then
                        table.insert(clashes, `{names[i]} x {names[j]}`)
                    end
                end
            end
            local half = TycoonConfig.PAD_SIZE / 2
            for _, p in TycoonConfig.padsOfWorld(1) do
                if p.live and p.x ~= nil and p.y ~= nil then
                    local px, py = p.x :: number, p.y :: number
                    local padBox =
                        { x0 = px - half, x1 = px + half, y0 = py - half, y1 = py + half }
                    for _, name in names do
                        if name ~= `building_{p.id}` and hit(things[name], padBox) then
                            table.insert(clashes, `{name} x {p.id}`)
                        end
                    end
                end
            end
            for _, c in clashes do
                print("  ! " .. c)
            end
            check.equal(#clashes, 0)

            local landing = TycoonConfig.ZONES[1]
            local bottom = RiverConfig.PLOT.y + RiverConfig.PLOT.h
            -- [D59] Decorul cumparat poate iesi putin pe sub marginea terenului: florile stau in fata caselor,
            -- pe iarba de sub randul cu nume (in curti acopereau numele, vazut in Studio pe 2026-09-15). Acolo
            -- nu construieste nimeni, nu umbla nimeni, iar copacii din seed raman la 90 de teren.
            local GARDEN = 32
            local outside = {}
            for _, name in names do
                local b = things[name]
                local limit = if string.sub(name, 1, 6) == "decor_" then bottom + GARDEN else bottom
                if b.x0 < landing.x0 or b.x1 > landing.x1 or b.y1 > limit then
                    table.insert(outside, name)
                end
            end
            for _, name in outside do
                print("  ! in afara terenului: " .. name)
            end
            check.equal(#outside, 0)
        end)

        test.case("[D65] clientii fiecarui vanzator au loc: nu se calca, nu stau in usa", function()
            for seller, places in TycoonConfig.SELLER_PLACES do
                local spots = places.customerSpots
                check.is_true(#spots >= 4)
                for i, a in spots do
                    for j, b in spots do
                        if i < j then
                            local d = math.sqrt((a.x - b.x) ^ 2 + (a.y - b.y) ^ 2)
                            if d < 36 then
                                print(
                                    `  ! {seller}: clientii {i} si {j} se calca ({math.floor(d)} px)`
                                )
                            end
                            check.is_true(d >= 36)
                        end
                    end
                    -- usa e locul unde lasi marfa, iar langa ea sta omul vanzatorului
                    for _, keep in { places.door, places.stand } do
                        check.is_true(math.sqrt((a.x - keep.x) ^ 2 + (a.y - keep.y) ^ 2) >= 30)
                    end
                end
                -- Piata ii are in aceleasi locuri ca taverna, mutate cu tot cartierul
                local dx = places.door.x - TycoonConfig.SELLER_PLACES.dock.door.x
                check.equal(
                    places.customerEntry.x,
                    TycoonConfig.SELLER_PLACES.dock.customerEntry.x + dx
                )
                check.equal(spots[1].x, TycoonConfig.SELLER_PLACES.dock.customerSpots[1].x + dx)
            end
        end)

        test.case(
            "nimic construit nu sta pe drum, iar locurile de predare sunt langa drum",
            function()
                -- Platformele si cladirile stau LANGA drumuri, nu pe ele; doar plasele stau pe punte.
                -- Oamenii si gramezile au voie pe marginea drumului: acolo lasa si iau marfa.
                local things = placed()
                -- [D65] drumurile tuturor cartierelor: platformele Morii stau langa ale ei
                local roads: { Box } = {}
                for _, district in TycoonConfig.DISTRICTS do
                    for _, r in district.roads do
                        table.insert(roads, { x0 = r.x0, x1 = r.x1, y0 = r.y0, y1 = r.y1 })
                    end
                end
                local onRoad = {}
                local check_names = { "storage", "sawmill", "tavern", "wheel", "board", "spawn" }
                -- [D59] decorul de pe teren nu sta pe drum, in afara de ce atarna peste el (ghirlanda)
                for _, d in VillageConfig.DECOR do
                    if d.ground == "land" and not d.overRoad then
                        for i in d.spots do
                            table.insert(check_names, `decor_{d.id}_{i}`)
                        end
                    end
                end
                for _, name in check_names do
                    for _, r in roads do
                        if hit(things[name], r) then
                            table.insert(onRoad, name)
                        end
                    end
                end
                local half = TycoonConfig.PAD_SIZE / 2
                for _, p in TycoonConfig.padsOfWorld(1) do
                    local isNet = false
                    for _, e in p.effects do
                        isNet = isNet or e.kind == "net"
                    end
                    if p.live and not isNet and p.x ~= nil and p.y ~= nil then
                        local px, py = p.x :: number, p.y :: number
                        local boxes =
                            { { x0 = px - half, x1 = px + half, y0 = py - half, y1 = py + half } }
                        if things[`building_{p.id}`] ~= nil then
                            table.insert(boxes, things[`building_{p.id}`])
                        end
                        for _, b in boxes do
                            for _, r in roads do
                                if hit(b, r) then
                                    table.insert(onRoad, p.id)
                                end
                            end
                        end
                    end
                end
                for _, name in onRoad do
                    print("  ! pe drum: " .. name)
                end
                check.equal(#onRoad, 0)

                -- de unde pleaca si unde ajung oamenii: pe drum sau la cel mult 60 px de el
                local function gap(p: { x: number, y: number }, r: Box): number
                    local dx = math.max(r.x0 - p.x, 0, p.x - r.x1)
                    local dy = math.max(r.y0 - p.y, 0, p.y - r.y1)
                    return math.sqrt(dx * dx + dy * dy)
                end
                for _, spot in
                    {
                        TycoonConfig.STORAGE_STAND,
                        TycoonConfig.SAWMILL_STAND,
                        TycoonConfig.SAWMILL_IN,
                        TycoonConfig.SAWMILL_OUT,
                        TycoonConfig.DOCK,
                        TycoonConfig.SCRAP_SHED_STAND,
                        TycoonConfig.FORGE_IN,
                        TycoonConfig.FORGE_OUT,
                        TycoonConfig.WORKSHOP_STAND,
                        -- [D65] locurile Morii, din tabel
                        TycoonConfig.LINE_PLACES.parts.storeStand,
                        TycoonConfig.LINE_PLACES.parts.playerStand,
                        TycoonConfig.LINE_PLACES.parts.processorIn,
                        TycoonConfig.LINE_PLACES.parts.processorOut,
                        TycoonConfig.LINE_PLACES.copper.storeStand,
                        TycoonConfig.LINE_PLACES.copper.playerStand,
                        TycoonConfig.LINE_PLACES.copper.processorIn,
                        TycoonConfig.LINE_PLACES.copper.processorOut,
                        TycoonConfig.SELLER_PLACES.market.door,
                    }
                do
                    local nearest = math.huge
                    for _, r in roads do
                        nearest = math.min(nearest, gap(spot, r))
                    end
                    check.is_true(nearest <= 60)
                end
                -- plasele stau pe punte
                for _, p in TycoonConfig.padsOfWorld(1) do
                    for _, e in p.effects do
                        if e.kind == "net" and p.live then
                            -- puntea cartierului ei
                            local d = TycoonConfig.DECK
                            for _, district in TycoonConfig.DISTRICTS do
                                if district.era == p.era then
                                    d = district.deck
                                end
                            end
                            check.is_true(
                                (p.x :: number) >= d.x0
                                    and (p.x :: number) <= d.x1
                                    and (p.y :: number) >= d.y0
                                    and (p.y :: number) <= d.y1
                            )
                        end
                    end
                end
            end
        )

        test.case(
            "[D60] indicatorul rotii mutate (unde statea timonierul) sta in zona si nu atinge nimic",
            function()
                -- Indicatorul are un card E ca orice obiect, deci o platforma de langa el i-ar fura cardul.
                -- Prins de baza (AnchorPoint 0.5,1), 28x36 la x2, pe punte.
                local art = Assets.props.signpost
                local w, h = art.width * 2, art.height * 2
                local x0, x1 =
                    TycoonConfig.WHEEL_STAND.x - w / 2, TycoonConfig.WHEEL_STAND.x + w / 2
                local y0, y1 = TycoonConfig.WHEEL_STAND.y - h, TycoonConfig.WHEEL_STAND.y
                local deck = TycoonConfig.DECK
                check.is_true(
                    TycoonConfig.WHEEL_STAND.y >= deck.y0 and TycoonConfig.WHEEL_STAND.y <= deck.y1
                )
                check.is_true(
                    TycoonConfig.VILLAGE_BOARD.y >= deck.y0
                        and TycoonConfig.VILLAGE_BOARD.y <= deck.y1
                )

                local landing = nil
                for _, z in TycoonConfig.ZONES do
                    if z.id == "landing" then
                        landing = z
                    end
                end
                check.not_nil(landing)
                check.is_true(x0 >= (landing :: any).x0)
                check.is_true(x1 <= (landing :: any).x1)

                local half = TycoonConfig.PAD_SIZE / 2
                local clashes = 0
                for _, p in TycoonConfig.padsOfWorld(1) do
                    if p.live and p.x ~= nil and p.y ~= nil then
                        local px, py = p.x :: number, p.y :: number
                        if
                            px + half > x0
                            and px - half < x1
                            and py + half > y0
                            and py - half < y1
                        then
                            clashes += 1
                        end
                    end
                end
                check.equal(clashes, 0)
                -- taverna, Innkeeper-ul si restul le verifica testul de mai sus (`placed`)
            end
        )

        test.case(
            "[D59] pontonul lung: locul de pescuit, plutitorul, ce aduce raul, decorul de pe el si de pe apa",
            function()
                local things = placed()
                local pier = things.pier
                local walk = TycoonConfig.PIER_WALK
                local top, bottom = RiverConfig.RIVER_TOP, RiverConfig.RIVER_BOTTOM
                -- trecerea e pe scandurile pontonului si ajunge pana la mal
                check.is_true(walk.x0 >= pier.x0 and walk.x1 <= pier.x1 and walk.y0 >= pier.y0)
                check.is_true(pier.y1 > bottom)
                -- picioarele tale la capat, pe trecere
                local stand = TycoonConfig.FISH_STAND
                check.is_true(
                    stand.x > walk.x0
                        and stand.x < walk.x1
                        and stand.y > walk.y0
                        and stand.y < bottom
                )
                -- plutitorul: in apa, in aval (dreapta) de ponton, departe de prima plasa
                local bob = TycoonConfig.BOBBER_AT
                check.is_true(bob.y > top and bob.y < bottom and bob.x > pier.x1)
                local firstNet = TycoonConfig.byId.first_net
                check.is_true(bob.x < (firstNet.x :: number) - TycoonConfig.PAD_SIZE)
                -- ce aduce raul: in apa, in amonte (stanga), fara sa atinga pontonul sau vecinul (cutia cea mai mare: 60x48)
                local slots: { Box } = {}
                for _, slot in TycoonConfig.TREASURE_SLOTS do
                    local b =
                        { x0 = slot.x - 30, x1 = slot.x + 30, y0 = slot.y - 24, y1 = slot.y + 24 }
                    check.is_true(b.y0 > top and b.y1 < bottom)
                    check.is_true(b.x1 <= pier.x0)
                    for _, other in slots do
                        check.is_false(hit(b, other))
                    end
                    table.insert(slots, b)
                end
                check.equal(#slots, 3)
                -- decorul de pe ponton sta pe ponton; cel de pe apa, in apa, fara sa atinga pontonul sau ce aduce raul
                for _, d in VillageConfig.DECOR do
                    local art = (Assets.decor :: any)[d.sprite]
                    for _, spot in d.spots do
                        local b = box(spot.x, spot.y, art.width * d.scale, art.height * d.scale)
                        if d.ground == "pier" then
                            check.is_true(
                                b.x0 >= pier.x0
                                    and b.x1 <= pier.x1
                                    and b.y0 >= pier.y0
                                    and b.y1 <= pier.y1
                            )
                        elseif d.ground == "water" then
                            check.is_true(b.y0 > top and b.y1 <= bottom)
                            check.is_false(hit(b, pier))
                            for _, slot in slots do
                                check.is_false(hit(b, slot))
                            end
                        else
                            check.equal(d.ground, "land")
                        end
                    end
                end
            end
        )

        test.case(
            "[D60] barca balciului sta pe apa, intre plutitor si mal, fara sa atinga nimic de pe ponton",
            function()
                -- FerryController: 62x30 la pixelul hartii (x3), prinsa de baza, oglindita (prova in amonte); eticheta deasupra ei.
                local things = placed()
                local art = Assets.fair.ferry
                local ferry = box(
                    TycoonConfig.FERRY.x,
                    TycoonConfig.FERRY.y,
                    art.width * Assets.PIXEL_SCALE,
                    art.height * Assets.PIXEL_SCALE
                )
                local top, bottom = RiverConfig.RIVER_TOP, RiverConfig.RIVER_BOTTOM
                check.is_true(ferry.y0 > top and ferry.y1 <= bottom)
                -- sub plutitor (8x8) si sub fir, care coboara pana la el
                local bob = TycoonConfig.BOBBER_AT
                check.is_true(ferry.y0 > bob.y + 8)
                -- [2026-10-07] placuta (18 px, baza la FERRY_TAG_BASE) sub plutitor (8x10 la x3, ancora 0,8: pana la
                -- bob.y + 6) si deasupra desenului: primele trei randuri ale lui sunt goale (cosul salupei incepe la 3)
                local tagBase = TycoonConfig.FERRY_TAG_BASE
                check.is_true(tagBase - 18 >= bob.y + 6)
                check.is_true(tagBase <= ferry.y0 + 3 * Assets.PIXEL_SCALE)
                -- ponton, avizier, indicator; niciun lucru adus de rau, niciun decor de pe apa
                for _, name in { "pier", "board", "wheel" } do
                    check.is_false(hit(ferry, things[name]))
                end
                for _, slot in TycoonConfig.TREASURE_SLOTS do
                    local b =
                        { x0 = slot.x - 30, x1 = slot.x + 30, y0 = slot.y - 24, y1 = slot.y + 24 }
                    check.is_false(hit(ferry, b))
                end
                for _, d in VillageConfig.DECOR do
                    if d.ground == "water" then
                        local dart = (Assets.decor :: any)[d.sprite]
                        for _, spot in d.spots do
                            local b =
                                box(spot.x, spot.y, dart.width * d.scale, dart.height * d.scale)
                            check.is_false(hit(ferry, b))
                        end
                    end
                end
                -- prima plasa (48x28 la x3, pe banda ei) incepe dupa barca
                local firstNet = TycoonConfig.byId.first_net
                check.is_true(ferry.x1 < (firstNet.x :: number) - 72)
                -- urci de pe marginea pontonului, de pe scanduri, nu din apa
                local walk = TycoonConfig.PIER_WALK
                local board = TycoonConfig.FERRY_BOARD
                check.is_true(board.x > walk.x0 and board.x < walk.x1 and board.y > walk.y0)
                check.is_true(board.y < bottom)
                -- de pe locul de urcat, cardul barcii e mai aproape decat locul de pescuit (70)
                local stand = TycoonConfig.FISH_STAND
                check.is_true(math.sqrt((board.x - stand.x) ^ 2 + (board.y - stand.y) ^ 2) > 70)
            end
        )

        test.case(
            "[D59] decorul cumparat nu acopera numele caselor, iar etichetele roții si avizierului nu se ating",
            function()
                -- Textul din lume e in fontul de pixeli: 572/1024 em pe litera, randul ~1.03 em, contur de 2.
                -- Vazut in Studio, 2026-09-15: florile cumparate stateau peste numele a patru case, iar "Lucky Wheel"
                -- si "Village Board" se citeau "Lucky WheelVillage Board".
                local EM = 572 / 1024
                local TINY = 13
                local function textBox(cx: number, top: number, text: string): Box
                    local lines, widest = 0, 0
                    for _, part in string.split(text, "\n") do
                        lines += 1
                        widest = math.max(widest, #part)
                    end
                    local half = widest * EM * TINY / 2 + 2
                    return {
                        x0 = cx - half,
                        x1 = cx + half,
                        y0 = top - 2,
                        y1 = top + lines * TINY * 1.03 + 2,
                    }
                end

                -- numele de sub casa unei meserii: PadController.worldName, varful la baza cadrului + 10 (pad.y + 58)
                local names: { [string]: Box } = {}
                for _, p in TycoonConfig.padsOfWorld(1) do
                    local role = TycoonConfig.CREW_OF_PAD[p.id]
                    local crew = if role ~= nil then TycoonConfig.CREWS[role] else nil
                    if p.live and crew ~= nil and p.x ~= nil and p.y ~= nil then
                        names[p.id] = textBox(p.x :: number, (p.y :: number) + 58, crew.name)
                    end
                end
                check.is_true(next(names) ~= nil)

                local covered = {}
                for _, d in VillageConfig.DECOR do
                    if d.ground == "land" then
                        local art = (Assets.decor :: any)[d.sprite]
                        for i, spot in d.spots do
                            local b = box(spot.x, spot.y, art.width * d.scale, art.height * d.scale)
                            for padId, label in names do
                                if hit(b, label) then
                                    table.insert(covered, `decor_{d.id}_{i} peste numele {padId}`)
                                end
                            end
                        end
                    end
                end
                check.equal(table.concat(covered, ", "), "")

                -- [D62, pasul 5] treapta meseriei sta DEASUPRA acoperisului casei (cinci patratele, 42 px late). Casa
                -- mica are 28 px de desen, cea mare 34, la x3, cu baza la pad.y + 56: banda in care pot aparea
                -- patratelele, pentru oricare din ele, nu are voie sa fie acoperita de un decor cumparat.
                local overPips = {}
                for _, p in TycoonConfig.padsOfWorld(1) do
                    local role = TycoonConfig.CREW_OF_PAD[p.id]
                    if p.live and role ~= nil and p.x ~= nil and p.y ~= nil then
                        local base = TycoonConfig.buildingBase(p)
                        -- cea mai inalta si cea mai scunda casa a meseriei, pe ecran (taraba Innkeeper-ului e la x2,
                        -- coliba Collector-ului e mai inalta decat restul)
                        local tall, short = 34 * 3, 28 * 3
                        if p.id == "dock_trader" then
                            tall = Assets.tycoon.stall_2.height * TycoonConfig.PROP_SCALE
                            short = Assets.tycoon.stall.height * TycoonConfig.PROP_SCALE
                        elseif p.id == "first_runner" then
                            tall = Assets.tycoon.runner_hut_2.height * 3
                            short = Assets.tycoon.runner_hut.height * 3
                        end
                        local band: Box = {
                            x0 = (p.x :: number) - 23,
                            x1 = (p.x :: number) + 23,
                            y0 = base - tall - 16 - 2,
                            y1 = base - short - 10 + 2,
                        }
                        for _, d in VillageConfig.DECOR do
                            if d.ground == "land" then
                                local art = (Assets.decor :: any)[d.sprite]
                                for i, spot in d.spots do
                                    local b = box(
                                        spot.x,
                                        spot.y,
                                        art.width * d.scale,
                                        art.height * d.scale
                                    )
                                    if hit(b, band) then
                                        table.insert(
                                            overPips,
                                            `decor_{d.id}_{i} peste treapta {p.id}`
                                        )
                                    end
                                end
                            end
                        end
                    end
                end
                check.equal(table.concat(overPips, ", "), "")

                -- sub indicatorul rotii si sub avizier (baza + 2): cele doua etichete de pe punte
                local wheel = textBox(
                    TycoonConfig.WHEEL_STAND.x,
                    TycoonConfig.WHEEL_STAND.y + 2,
                    Strings.WHEEL_MOVED_TAG
                )
                local board = textBox(
                    TycoonConfig.VILLAGE_BOARD.x,
                    TycoonConfig.VILLAGE_BOARD.y + 2,
                    Strings.BOARD_TAG
                )
                check.is_false(hit(wheel, board))
            end
        )

        test.case("preturile Erei 1 sunt exact cele din simulator", function()
            -- Tiparite de `python3 scripts/economy/sim_tycoon.py` pe modelul cu niveluri si
            -- gatuire. ATENTIE: lista de aici nu citeste simulatorul -- asa a putut config-ul sa
            -- ramana cu 2500/2800/13000 cand simulatorul deriva 1500/1600/10000, si testul trecea.
            -- Garda reala e acum in simulator (`check_config_prices`), care citeste chiar fisierul
            -- Luau. Testul ramane ca document al cifrelor. Erele 2-4 se re-deriva cand devin live.
            -- [D52] Re-derivate pe ordinea noua: oamenii iau primele trepte ale scarii, pe venitul
            -- plat al unei singure plase, deci ies ieftini; plasele de dupa ei, scumpe.
            -- [D55] Re-derivate cu lantul resturilor: lemnul fara reeds/shards valoreaza mai putin, iar shed-ul
            -- de scrap sta intre atelier si plasa a cincea.
            -- [D56] Linia fierului: Forge, plasa a cincea, apoi shed-ul si cei patru oameni in rafala (secunde de
            -- venit, nu scara), deci clopotul vine mai ieftin decat in D55.
            local era1 = {
                first_net = 0,
                -- [D62] oamenii capitolului 1 vin in rafala (secunde de venit, nu scara): erau 12/15/18/20/25
                first_runner = 5,
                hire_porter = 6,
                hire_sawyer = 7,
                hire_hauler = 8,
                dock_trader = 10,
                second_net = 28,
                third_net = 90,
                bigger_sack = 80,
                far_lane_net = 900,
                workshop = 5500,
                fifth_net = 7000,
                -- [D62] rafala scurta a fierului: erau 2500 / 2500 / 2800 / 3500 / 3500
                scrap_shed = 700,
                hire_scrap_collector = 700,
                hire_scrap_porter = 800,
                hire_smelter = 900,
                hire_iron_hauler = 1100,
                landing_bell = 8000,
            }
            local seen = 0
            for _, p in TycoonConfig.PADS do
                if p.era == 1 then
                    seen += 1
                    check.equal(p.price, era1[p.id])
                end
            end
            check.equal(seen, 18)
        end)

        test.case("fiecare deblocare a Erei 1 spune cand devine cumparabila", function()
            -- Fara `needs`, ordinea din tabel ar forta cumparaturi moarte (a treia plasa inaintea
            -- primei Maini, cand caratul e deja gatuirea).
            for _, p in TycoonConfig.PADS do
                if p.era == 1 then
                    check.is_true(p.needs ~= nil)
                end
            end
        end)

        test.case("fiecare meserie are o platforma de angajare in era ei, si invers", function()
            -- CREWS e singura legatura dintre o platforma si omul pe care il aduce [D49]: PadService
            -- angajeaza prin ea, meniul o citeste, simulatorul ii verifica pretul celui de-al doilea.
            local StationConfig = require("../src/Shared/Config/StationConfig")
            -- [D70] toate meseriile scrise, si ale Erei 4 adormite
            for _, role in StationConfig.ROLES_ALL do
                local crew = TycoonConfig.CREWS[role]
                check.not_nil(crew)
                local p = TycoonConfig.byId[crew.pad]
                check.not_nil(p)
                -- [D65, D67] oamenii fiecarei ere se angajeaza in cartierul lor
                check.equal(p.era, StationConfig.ERA_OF_ROLE[role])
                check.equal(TycoonConfig.CREW_OF_PAD[crew.pad], role)
                check.equal(p.effects[1].kind, "hire")
                check.equal(p.effects[1].field, role)
                check.is_true(crew.secondPrice > p.price)
            end
            for _, p in TycoonConfig.PADS do
                for _, e in p.effects do
                    if e.kind == "hire" then
                        check.equal(TycoonConfig.CREW_OF_PAD[p.id], e.field)
                    end
                end
            end
        end)

        test.case(
            "oamenii vin in ordinea raului: `after` trimite la o platforma dinainte",
            function()
                -- O conditie spre o platforma de mai jos in tabel, sau inexistenta, ar tine angajarea
                -- incuiata pentru totdeauna, fara nicio eroare.
                local chain = {
                    hire_porter = "first_runner",
                    hire_sawyer = "hire_porter",
                    hire_hauler = "hire_sawyer",
                    -- [D52] Innkeeper-ul inchide cei cinci, iar plasa a doua il asteapta
                    dock_trader = "hire_hauler",
                    second_net = "dock_trader",
                    -- [D56] fierul: forja intai, apoi plasa care aduce scrap; shed-ul cere plasa a cincea prin
                    -- `netsOwned`, apoi oamenii fierului, in ordinea raului
                    fifth_net = "workshop",
                    hire_scrap_collector = "scrap_shed",
                    hire_scrap_porter = "hire_scrap_collector",
                    hire_smelter = "hire_scrap_porter",
                    hire_iron_hauler = "hire_smelter",
                }
                for id, before in chain do
                    local p = TycoonConfig.byId[id]
                    check.equal((p.needs :: any).after, before)
                end
                for _, p in TycoonConfig.PADS do
                    local after = p.needs and p.needs.after
                    if after ~= nil then
                        local prev = TycoonConfig.byId[after]
                        check.not_nil(prev)
                        check.is_true(prev.index < p.index)
                    end
                end
            end
        )

        test.case(
            "[D67] felinarele stau intre case, nu peste ele, si doar cu Era 3 in joc",
            function()
                local lamps = TycoonConfig.streetLamps()
                if not TycoonConfig.eraIsLive(3) then
                    check.equal(#lamps, 0)
                    return
                end
                local RiverConfig = require("../src/Shared/Config/RiverConfig")
                -- capul felinarului (partea lui cea mai lata) are 8 px, casa mare 40 px (cu tot ce sta la usa ei), la scara 3
                local LAMP_HALF, HOUSE_HALF = 4 * 3, 40 * 3 / 2
                local perEra: { [number]: number } = {}
                for _, lamp in lamps do
                    perEra[lamp.era] = (perEra[lamp.era] or 0) + 1
                    check.is_true(lamp.x > 0 and lamp.x < RiverConfig.WORLD_WIDTH)
                    for _, p in TycoonConfig.padsOfWorld(1) do
                        if p.live and TycoonConfig.CREW_OF_PAD[p.id] ~= nil and p.y == 1564 then
                            check.is_true(
                                math.abs(lamp.x - (p.x :: number)) >= LAMP_HALF + HOUSE_HALF
                            )
                        end
                    end
                end
                for era = 1, 3 do
                    -- opt case pe cartier, sapte goluri intre ele; [D67, audit] trei raman goale, unde lucreaza un om:
                    -- omul atelierului, al doilea om de la gater / Foundry / Wire Works, Porter-ul care isi rastoarna roaba
                    check.equal(perEra[era], 4)
                end
                -- niciun felinar peste un om care lucreaza pe loc (cutia lui 40x60, prinsa de talpi)
                for _, lamp in lamps do
                    -- [D70] felinarele satului: oamenii satului (lumea 2 are felinarele ei, WORLDS[2])
                    for _, place in TycoonConfig.linePlacesOf(1) do
                        local w = place.workerStand
                        for _, spot in { w, { x = w.x + place.secondOffset.x, y = w.y } } do
                            local apart = math.abs(lamp.x - spot.x) >= 15 + 20
                            check.is_true(apart)
                        end
                        -- nici peste roaba Porter-ului (in dreapta lui, la gura atelierului) sau a Hauler-ului (in stanga)
                        local pin, pout = place.processorIn, place.processorOut
                        check.is_true(lamp.x + 15 <= pin.x - 20 or lamp.x - 15 >= pin.x + 73)
                        check.is_true(lamp.x + 15 <= pout.x - 73 or lamp.x - 15 >= pout.x + 20)
                    end
                end
                -- nici peste un felinar pus de mana [D57]: cel dintre curti (x 1215) statea chiar sub cel de la x 1205
                for _, lamp in lamps do
                    for _, item in TycoonConfig.DECOR do
                        if item.sprite == "lantern" then
                            check.is_true(math.abs(lamp.x - item.x) >= 60)
                        end
                    end
                end
            end
        )

        -- [D70] Obstacolele tari de pe teren: cladirile fixe, platformele cu cladiri sau case, oamenii care lucreaza pe
        -- loc cu roabele lor, inelele si gramezile atelierelor, aleile, felinarele si decorul care nu se poate calca
        -- (tufele si gardurile, da: un stalp in fata unui gard e firesc).
        local function hardObstacles(): { { any } }
            local out: { { any } } = {}
            local function add(name: string, x0: number, y0: number, x1: number, y1: number)
                table.insert(out, { name, x0, y0, x1, y1 })
            end
            local function bottom(name: string, cx: number, by: number, w: number, h: number)
                add(name, cx - w / 2, by - h, cx + w / 2, by)
            end
            for _, k in
                {
                    "STORAGE",
                    "SAWMILL",
                    "TAVERN",
                    "MILL_STORE",
                    "FOUNDRY",
                    "MARKET",
                    "WORKS_STORE",
                    "WIRE_WORKS",
                    "DEPOT",
                }
            do
                local b = (TycoonConfig :: any)[k]
                bottom(k, b.x, b.y, b.w, b.h)
            end
            for _, p in TycoonConfig.padsOfWorld(1) do
                if p.live and p.x ~= nil and p.y ~= nil then
                    local net = false
                    for _, e in p.effects do
                        if e.kind == "net" then
                            net = true
                        end
                    end
                    if not net then
                        local home = TycoonConfig.CREW_OF_PAD[p.id] ~= nil
                        bottom(
                            `pad {p.id}`,
                            p.x :: number,
                            TycoonConfig.buildingBase(p),
                            if home then 128 else 192,
                            if home then 110 else 144
                        )
                    end
                end
            end
            for name, pl in TycoonConfig.linePlacesOf(1) do -- [D70] stalpii satului, langa oamenii satului
                local w = pl.workerStand
                bottom(`{name}.worker`, w.x, w.y, 40, 60)
                bottom(`{name}.second`, w.x + pl.secondOffset.x, w.y, 40, 60)
                add(
                    `{name}.inBarrow`,
                    pl.processorIn.x - 20,
                    pl.processorIn.y - 60,
                    pl.processorIn.x + 73,
                    pl.processorIn.y
                )
                add(
                    `{name}.outBarrow`,
                    pl.processorOut.x - 73,
                    pl.processorOut.y - 60,
                    pl.processorOut.x + 20,
                    pl.processorOut.y
                )
                add(
                    `{name}.ring`,
                    pl.playerStand.x - 48,
                    pl.playerStand.y - 28,
                    pl.playerStand.x + 48,
                    pl.playerStand.y + 20
                )
                for _, pile in { pl.inPile, pl.outPile, pl.storePile } do
                    add(`{name}.pile`, pile.x - 40, pile.y - 82, pile.x + 40, pile.y)
                end
            end
            for _, d in TycoonConfig.DECOR do
                local soft = d.sprite == "bush"
                    or d.sprite == "fence"
                    or d.sprite == "flowers"
                    or d.sprite == "rock_small"
                local art = (Assets.props :: any)[d.sprite] or (Assets.tycoon :: any)[d.sprite]
                if art ~= nil and not soft then
                    bottom(`decor {d.sprite}`, d.x, d.y, art.width * d.scale, art.height * d.scale)
                end
            end
            for _, district in TycoonConfig.DISTRICTS do
                for _, r in district.roads do
                    if r.y1 == 1420 then
                        add(`lane {r.id}`, r.x0 - 12, 1300, r.x1 + 12, 1420)
                    end
                end
            end
            for _, l in TycoonConfig.streetLamps() do
                add("lamp", l.x - 15, 1372, l.x + 15, l.y)
            end
            return out
        end
        local function clashes(
            obstacles: { { any } },
            x0: number,
            y0: number,
            x1: number,
            y1: number
        ): string?
            for _, b in obstacles do
                if x0 < b[4] and b[2] < x1 and y0 < b[5] and b[3] < y1 then
                    return b[1]
                end
            end
            return nil
        end

        test.case("[D70] stalpii cu sarma stau pe marginea strazii fara sa calce nimic", function()
            local poles = TycoonConfig.wirePoles()
            if not TycoonConfig.eraIsLive(3) then
                check.equal(#poles, 0)
                return
            end
            check.equal(#poles, 15) -- capatul de vest, patru pe cartier, doi de legatura
            check.equal(poles[1].kind, "end")
            check.equal(poles[#poles].kind, "line") -- se opreste in fata curtii Power House
            local obstacles = hardObstacles()
            -- gardul primului cartier inca inchis: el si ceata lui (ZoneController, Z 200/201) acopera tot ce trece de el.
            -- Gardul e desenat culcat, centrat pe linie: jumatate din inaltimea foii lui cade spre partea luminata.
            local fenceArt = (Assets.props :: any).fence
            local fence = math.huge
            for _, zone in TycoonConfig.ZONES do
                if not TycoonConfig.eraIsLive(zone.era) then
                    fence = math.min(fence, zone.x0 - fenceArt.height * Assets.PIXEL_SCALE / 2)
                end
            end
            for i, pole in poles do
                -- stalpul (x+-6) si traversa cu izolatorii (x-15..x+12), de la baza pana la 162 px deasupra
                local hit = clashes(obstacles, pole.x - 6, pole.y - 162, pole.x + 6, pole.y)
                    or clashes(obstacles, pole.x - 15, pole.y - 162, pole.x + 12, pole.y - 126)
                if hit ~= nil then
                    error(`stalpul de la x {pole.x} calca {hit}`)
                end
                -- toata foaia (la capat: si ancora, 60 px spre margine) sta pe partea luminata a gardului
                local reach = if pole.kind == "end" and pole.mirror then 60 else 24
                check.is_true(pole.x + reach <= fence)
                if i > 1 then
                    local span = pole.x - poles[i - 1].x
                    check.is_true(span > 100 and span <= 480)
                end
            end
            -- [D70, dupa verificator] ancora stalpului de capat se prinde in pamant in fata bradului de la capatul strazii
            -- (singurul loc liber intre el si taraba Innkeeper-ului): bradul sta in spate, deci ancora se deseneaza peste
            -- el, si nimic altceva nu e acolo.
            local first = poles[1]
            for _, b in obstacles do
                local x0, y0, x1, y1 = first.x - 60, first.y - 162, first.x + 24, first.y
                if x0 < b[4] and b[2] < x1 and y0 < b[5] and b[3] < y1 then
                    check.equal(b[1], "decor tree_pine")
                    check.is_true(b[5] < first.y) -- bradul sta in spatele stalpului
                end
            end
        end)

        -- [D70, dupa verificator] Toate firele din joc, din aceeasi lista ca desenul (ModernConfig.wireSpans): intre stalpi
        -- si, de la treapta 4, pana la izolatorul de pe acoperisul Power House. `wireThrough` spune daca vreun fir intra
        -- in dreptunghiul dat (cu grosimea lui).
        local ModernConfig = require("../src/Shared/Config/ModernConfig")
        local function allSpans(): { ModernConfig.Span }
            local height = (Assets.tycoon :: any).wire_pole.height
            check.equal((Assets.tycoon :: any).wire_pole_end.height, height)
            local house = TycoonConfig.byId[ModernConfig.POWER_FEED.pad]
            local art = (Assets.tycoon :: any).power_house
            local fx, fy = ModernConfig.feedPoint(
                house.x :: number,
                TycoonConfig.buildingBase(house),
                art.width,
                art.height,
                Assets.PIXEL_SCALE
            )
            return ModernConfig.wireSpans(
                TycoonConfig.wirePoles(),
                height,
                Assets.PIXEL_SCALE,
                { x = fx, y = fy }
            )
        end
        local function wireThrough(
            x0: number,
            y0: number,
            x1: number,
            y1: number
        ): (number?, number?)
            local half = ModernConfig.WIRE.thickness / 2
            for _, span in allSpans() do
                for k = 0, 200 do
                    local x, y = ModernConfig.wirePoint(span.ax, span.ay, span.bx, span.by, k / 200)
                    if x >= x0 and x <= x1 and y + half > y0 and y - half < y1 then
                        return x, y
                    end
                end
            end
            return nil, nil
        end

        test.case("[D70] firul spre Power House pleaca de la ultimul stalp, peste curte", function()
            if not TycoonConfig.eraIsLive(3) then
                return
            end
            local spans = allSpans()
            local feed = spans[#spans]
            check.equal(feed.stage, ModernConfig.POWER_FEED.stage)
            -- firul apare cand apare si Power House: treapta lui e cea care cere platforma ei
            local ModernMath = require("../src/Shared/Modules/ModernMath")
            check.equal(ModernMath.STAGES[feed.stage].pad, ModernConfig.POWER_FEED.pad)
            local span = feed.bx - feed.ax
            check.is_true(span > 100 and span <= 480)
            check.is_true(feed.by < feed.ay) -- urca spre acoperis
        end)

        -- [D70, dupa verificator] Sarma trece prin fata cladirilor de pe marginea de nord a strazii (adancimea ei e a
        -- stalpilor, 5 + 1418/64), deci peste numele de sub case si tarabe si peste firmele de pe acoperisuri, care stau
        -- in cadrul platformei. La sageata de 6% firul din fata taia varful literelor din "Merchant" si "Clerk". Cutia
        -- numelui: 10 px sub baza cadrului platformei (y + 48), 18 px inalta; firma de pe acoperis: 30 px sub varful
        -- cladirii (PadController, FORGE_SIGN_Y). Textul de 13 px sta centrat in cutie (2,5 .. 15,5), iar conturul
        -- literelor adauga 2 px: literele ocupa 0,5 .. 17,5 din cutie.
        test.case("[D70] sarma nu trece peste numele de sub case si de pe acoperisuri", function()
            local Strings = require("../src/Shared/Config/Strings")
            local function clear(text: string, cx: number, top: number)
                local w = #text * 0.56 * 13 + 4 -- fontul de pixeli (0,56 em) la Theme.TEXT.tiny, cu contur
                local x, y = wireThrough(cx - w / 2, top + 0.5, cx + w / 2, top + 17.5)
                if x ~= nil then
                    error(
                        `sarma trece peste {text} (x {math.floor(x)}, y {math.floor(y :: number)})`
                    )
                end
            end
            local checked = 0
            for _, p in TycoonConfig.PADS do
                local role = TycoonConfig.CREW_OF_PAD[p.id]
                local crew = if role ~= nil then TycoonConfig.CREWS[role] else nil
                if p.live and crew ~= nil and p.x ~= nil and p.y ~= nil then
                    clear(crew.name, p.x :: number, (p.y :: number) + 58)
                    checked += 1
                end
            end
            -- firmele de pe acoperis (PadController.ROOF_SIGN), cladiri de 48 px inaltime x3
            for id, text in
                {
                    workshop = Strings.FORGE_LABEL,
                    copper_furnace = Strings.LINE_WORDS.copper.processor,
                    power_house = Strings.LINE_WORDS.power.processor,
                }
            do
                local p = TycoonConfig.byId[id]
                if p.live then
                    clear(text, p.x :: number, TycoonConfig.buildingBase(p) - 144 + 30)
                    checked += 1
                end
            end
            check.is_true(checked > 3)
        end)

        test.case("[D70] recuzita modernizarii nu calca nimic", function()
            local obstacles = hardObstacles()
            for _, pole in TycoonConfig.wirePoles() do
                table.insert(obstacles, { "pole", pole.x - 15, pole.y - 162, pole.x + 12, pole.y })
            end
            -- [D70, dupa verificator] nici firele: trec prin fata recuzitei din spatele lor (adancimea stalpilor e mai mare),
            -- deci o recuzita prin care trece firul pare agatata de el
            local function place(name: string, x: number, y: number, w: number, h: number)
                local hit = clashes(obstacles, x - w / 2, y - h, x + w / 2, y)
                if hit ~= nil then
                    error(`{name} de la ({x}, {y}) calca {hit}`)
                end
                if wireThrough(x - w / 2, y - h, x + w / 2, y) ~= nil then
                    error(`{name} de la ({x}, {y}) e taiat de sarma`)
                end
            end
            local plans = TycoonConfig.DAM_PLANS
            place("masa planurilor", plans.x, plans.y, 48 * 2, 44 * 2)
            for _, stake in TycoonConfig.SURVEY_STAKES do
                place("tarusul", stake.x, stake.y, 12 * 2, 26 * 2)
            end
            for _, prop in TycoonConfig.FIELD_PROPS do
                local art = (Assets.tycoon :: any)[prop.sprite]
                check.not_nil(art)
                place(prop.sprite, prop.x, prop.y, art.width * 3, art.height * 3)
            end
        end)

        -- [D63] Pentru copii: butonul cartonasului spune ACELASI verb ca quest-ul care te trimite acolo. "Cast a second
        -- net" pe linia NEXT si "Buy for 28" pe buton erau doua cuvinte pentru acelasi gest.
        test.case("verbul platformei e primul cuvant al quest-ului care o cere", function()
            local QuestConfig = require("../src/Shared/Config/QuestConfig")
            local verbs =
                { cast = "Cast", hire = "Hire", get = "Get", ring = "Ring", build = "Build" }
            local checked = 0
            -- [D67] toate capitolele scrise, si ale erelor inca in constructie
            for _, chapter in QuestConfig.ALL_CHAPTERS do
                for _, quest in chapter.quests do
                    -- doar quest-urile de cumparare: `arg` e chiar id-ul platformei (nu "net:<id>", care e un nivel)
                    local pad = if quest.arg ~= nil then TycoonConfig.byId[quest.arg] else nil
                    if pad ~= nil and quest.targetPad == pad.id then
                        local word = verbs[TycoonConfig.verbOf(pad)]
                        check.not_nil(word)
                        check.equal(string.sub(quest.text, 1, #word + 1), word .. " ")
                        checked += 1
                    end
                end
            end
            check.is_true(checked >= 15)
            -- textele butonului, din Strings
            check.equal(Strings.padBuyFor("cast", "28"), "Cast for 28")
            check.equal(Strings.padBuyFor("hire", "5"), "Hire for 5")
            check.equal(Strings.padBuyFor("orice", "5.5K"), "Build for 5.5K")
            check.equal(Strings.padTakeFree("cast"), "Cast it — free")
        end)

        -- [D70, pasul k6] ce urmeaza dupa ultima era a hartii tale: cu barajul adormit „coming soon”, dupa l3 drumul spre el
        test.case(
            "dupa ultima era a satului: barajul vine (adormit) sau se ridica (in joc)",
            function()
                local beyond = TycoonConfig.beyond(1)
                assert(beyond ~= nil, "dupa Wire Works urmeaza barajul")
                check.equal(beyond.era, 4)
                check.equal(beyond.name, "The Dam")
                check.equal(beyond.kind, if TycoonConfig.eraIsLive(4) then "build" else "soon")
                -- la baraj, dupa l3: ceata Erei 5 („The river beyond”), nu din nou barajul
                if TycoonConfig.eraIsLive(4) then
                    local dam = TycoonConfig.beyond(2) :: TycoonConfig.Beyond
                    check.equal(dam.kind, "soon")
                    check.equal(dam.era, 5)
                end
                -- cartonasul mesei: butonul (240 px, fontul de pixeli la 18) incape
                local build = Strings.plansBuild(" (E)")
                check.is_true((utf8.len(build) :: number) * 18 * 0.5586 + 16 <= 240)
            end
        )

        test.case(
            "[2026-09-30] finalul ce e in joc: era urmatoare, dupa ultima era din joc",
            function()
                -- [D70, pasul k6] dupa l3 barajul e in joc: finalul satului e drumul spre el (testul de mai sus)
                if TycoonConfig.eraIsLive(4) then
                    return
                end
                local coming = TycoonConfig.comingEra()
                assert(coming ~= nil, "azi o era urmeaza (Era 4, The Dam)")
                check.equal(TycoonConfig.eraIsLive(coming.era), false)
                -- toate erele cu zona dinaintea ei sunt in joc: e chiar urmatoarea, nu una de peste doua
                for _, zone in TycoonConfig.ZONES do
                    if zone.era < coming.era then
                        check.equal(TycoonConfig.eraIsLive(zone.era), true)
                    end
                end
                check.equal(coming.era, 4)
                check.equal(coming.name, "The Dam")
                -- clopotul ultimei ere din joc e cel dupa care vine anuntul
                local bells = 0
                for _, p in TycoonConfig.PADS do
                    if p.motive == "D" and p.era == coming.era - 1 and p.live then
                        bells += 1
                    end
                end
                check.equal(bells, 1)
                check.equal(Strings.eraComing(coming.name), "The Dam is coming soon!")
                check.equal(TycoonConfig.eraName(3), "The Wire Works")
                -- masa cu planuri e a barajului (Era 4), nu a "erei care urmeaza": cand barajul intra in joc, tace
                check.equal(TycoonConfig.DAM_PLANS.era, 4)
                check.equal(TycoonConfig.eraName(TycoonConfig.DAM_PLANS.era), "The Dam")
                -- cardul ei pe un singur rand: 320 px, 18 px pe litera la 0,56 em, 16 px de margine (InteractController)
                local plans = Strings.comingPlans("The Dam")
                check.is_true((utf8.len(plans) :: number) * 18 * 0.5586 + 16 <= 320)
                -- [D73] dupa clopot, butonul ei (240 px) arata tarusii topografilor de langa ponton
                local look = Strings.plansLook(" (E)")
                check.is_true((utf8.len(look) :: number) * 18 * 0.5586 + 16 <= 240)
                check.is_true(#TycoonConfig.SURVEY_STAKES > 0)
            end
        )

        test.case(
            "[D70] Look (V): privirea arata ce s-a schimbat, pe ecranul mare si pe telefon",
            function()
                local W, H = RiverConfig.WORLD_WIDTH, RiverConfig.WORLD_HEIGHT
                -- camera centrata pe loc si tinuta in lume (CameraController.OriginFor); ecranul mare = 1600 x 900 de lume
                -- (REFERENCE_HEIGHT 900), telefonul ~990 x 460 (MIN_SCALE 0.85 pe ~390 pt de inaltime)
                local BIG_W, BIG_H, PHONE_W, PHONE_H = 1600, 900, 990, 460
                local function sees(
                    stage: number,
                    w: number,
                    h: number,
                    x: number,
                    y: number
                ): boolean
                    local at = TycoonConfig.modernLookAt(stage, w)
                    assert(at ~= nil, "treapta fara privire")
                    local x0 = math.clamp(at.x - w / 2, 0, W - w)
                    local y0 = math.clamp(at.y - h / 2, 0, H - h)
                    return x >= x0 and x <= x0 + w and y >= y0 and y <= y0 + h
                end
                check.equal(#TycoonConfig.MODERN_LOOK_AT, 5)
                check.equal(TycoonConfig.modernLookAt(6, BIG_W), nil)
                local street = nil
                for _, road in TycoonConfig.ROADS do
                    if road.id == "street" then
                        street = road
                    end
                end
                assert(street ~= nil, "strada satului")
                for stage = 1, 5 do
                    for _, w in { BIG_W, PHONE_W } do
                        local at = TycoonConfig.modernLookAt(stage, w) :: { x: number, y: number }
                        check.is_true(at.x >= street.x0 and at.x <= street.x1) -- in satul vechi
                    end
                end
                -- 1: stalpii satului
                for _, x in TycoonConfig.WIRE_POLE_XS do
                    check.is_true(sees(1, BIG_W, BIG_H, x, TycoonConfig.WIRE_POLE_BASE_Y))
                end
                -- 3 si 5: cladirile care trec la tabla si caramida, apoi la firme si becuri, pe ecranul mare
                local buildings: { { x: number, y: number } } = {}
                for _, b in { TycoonConfig.TAVERN, TycoonConfig.STORAGE, TycoonConfig.SAWMILL } do
                    table.insert(buildings, { x = b.x, y = b.y })
                end
                for _, id in { "scrap_shed", "workshop" } do
                    local p = TycoonConfig.byId[id]
                    table.insert(buildings, { x = p.x :: number, y = TycoonConfig.buildingBase(p) })
                end
                for _, b in buildings do
                    check.is_true(sees(3, BIG_W, BIG_H, b.x, b.y))
                    check.is_true(sees(5, BIG_W, BIG_H, b.x, b.y))
                end
                -- 3 pe telefon: gaterul si forja intregi (acoperisul si talpa), si pe un Android mai scund (941 x 424)
                local saw = TycoonConfig.SAWMILL
                local forge = TycoonConfig.byId.workshop
                local forgeBase = TycoonConfig.buildingBase(forge)
                local forgeH = Assets.tycoon.workshop_e1.height * Assets.PIXEL_SCALE
                local forgeW = Assets.tycoon.workshop_e1.width * Assets.PIXEL_SCALE
                for _, size in { { PHONE_W, PHONE_H }, { 941, 424 } } do
                    local w, h = size[1], size[2]
                    check.is_true(sees(3, w, h, saw.x - saw.w / 2, saw.y - saw.h))
                    check.is_true(sees(3, w, h, saw.x + saw.w / 2, saw.y))
                    check.is_true(
                        sees(3, w, h, (forge.x :: number) - forgeW / 2, forgeBase - forgeH)
                    )
                    check.is_true(sees(3, w, h, (forge.x :: number) + forgeW / 2, forgeBase))
                end
                -- 4: tarusii de langa punte, pe ecranul mare
                for _, stake in TycoonConfig.SURVEY_STAKES do
                    check.is_true(sees(4, BIG_W, BIG_H, stake.x, stake.y))
                end
                -- 4 si 5: casele meseriilor, cu geamurile lor. Pe ecranul mare toate; pe telefon (si pe unul mai scund), casele din
                -- mijloc intregi (toate sapte se intind pe ~1080 px), cu talpa deasupra joystick-ului si a butonului E: pe 844x390,
                -- cu HUD-ul la 0,62 si camera la 0,85, ele urca ~156 px de lume de la marginea de jos
                local huts: { TycoonConfig.Pad } = {}
                for _, p in TycoonConfig.PADS do
                    if p.era == 1 and string.sub(p.id, 1, 5) == "hire_" and p.x ~= nil then
                        table.insert(huts, p)
                    end
                end
                check.is_true(#huts >= 5)
                table.sort(huts, function(a, b)
                    return (a.x :: number) < (b.x :: number)
                end)
                local HUT_W, HUT_H = 120, 102 -- coliba cu doi oameni (40 x 34, x3)
                for i, p in huts do
                    local x, base = p.x :: number, TycoonConfig.buildingBase(p)
                    for _, stage in { 4, 5 } do
                        check.is_true(sees(stage, BIG_W, BIG_H, x, base))
                        if i > 1 and i < #huts then
                            for _, size in { { PHONE_W, PHONE_H }, { 941, 424 } } do
                                local w, h = size[1], size[2]
                                check.is_true(sees(stage, w, h, x - HUT_W / 2, base - HUT_H))
                                check.is_true(sees(stage, w, h, x + HUT_W / 2, base))
                            end
                            local at =
                                TycoonConfig.modernLookAt(stage, PHONE_W) :: { x: number, y: number }
                            local bottom = math.clamp(at.y - PHONE_H / 2, 0, H - PHONE_H) + PHONE_H
                            check.is_true(base <= bottom - 150)
                        end
                    end
                end
            end
        )
    end)
end
