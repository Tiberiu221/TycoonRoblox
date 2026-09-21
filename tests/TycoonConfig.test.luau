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
        things[`building_{id}`] = box(p.x :: number, (p.y :: number) + 56, size[1], size[2])
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
            check.equal(#TycoonConfig.PADS, 54)
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
                check.equal(perEra[4], nil)
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
            for _, p in TycoonConfig.PADS do
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
            for _, p in TycoonConfig.PADS do
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
                for _, p in TycoonConfig.PADS do
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
                for _, p in TycoonConfig.PADS do
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
                for _, p in TycoonConfig.PADS do
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
                -- FerryController: 62x30 la x2, prinsa de baza, oglindita (prova in amonte); eticheta deasupra ei.
                local things = placed()
                local art = Assets.fair.ferry
                local ferry =
                    box(TycoonConfig.FERRY.x, TycoonConfig.FERRY.y, art.width * 2, art.height * 2)
                local top, bottom = RiverConfig.RIVER_TOP, RiverConfig.RIVER_BOTTOM
                check.is_true(ferry.y0 > top and ferry.y1 <= bottom)
                -- sub plutitor (8x8) si sub fir, care coboara pana la el
                local bob = TycoonConfig.BOBBER_AT
                check.is_true(ferry.y0 > bob.y + 8)
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
                for _, p in TycoonConfig.PADS do
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
                for _, p in TycoonConfig.PADS do
                    local role = TycoonConfig.CREW_OF_PAD[p.id]
                    if p.live and role ~= nil and p.x ~= nil and p.y ~= nil then
                        local base = (p.y :: number) + 56
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
            for _, role in StationConfig.ROLES do
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
                    for _, p in TycoonConfig.PADS do
                        if p.live and TycoonConfig.CREW_OF_PAD[p.id] ~= nil and p.y == 1564 then
                            check.is_true(
                                math.abs(lamp.x - (p.x :: number)) >= LAMP_HALF + HOUSE_HALF
                            )
                        end
                    end
                end
                for era = 1, 3 do
                    check.equal(perEra[era], 7) -- opt case pe cartier, sapte goluri intre ele
                end
            end
        )

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
    end)
end
