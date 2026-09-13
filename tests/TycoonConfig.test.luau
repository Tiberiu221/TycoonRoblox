local frktest = require("@frktest/frktest")
local test = frktest.test
local check = frktest.assert.check

local TycoonConfig = require("../src/Shared/Config/TycoonConfig")
local RiverConfig = require("../src/Shared/Config/RiverConfig")
local HandRoutes = require("../src/Shared/Modules/HandRoutes")

type Box = { x0: number, x1: number, y0: number, y1: number }

local function box(cx: number, bottom: number, w: number, h: number): Box
    return { x0 = cx - w / 2, x1 = cx + w / 2, y0 = bottom - h, y1 = bottom }
end

local function hit(a: Box, b: Box): boolean
    return a.x0 < b.x1 and b.x0 < a.x1 and a.y0 < b.y1 and b.y0 < a.y1
end

-- Marimea cladirii unei platforme cumparate; PadController o prinde la 8 px sub platforma.
-- [D53] Ruinele au amprenta cladirii lor, deci aceleasi cutii le acopera si pe ele. Atelierul nou e 64x48
-- (192x144), iar Porter/Sawyer/Hauler au un avizier (24x32 la x2), vizibil de la inceput.
local BOUGHT = {
    bigger_sack = { 48, 48 },
    dock_trader = { 96, 80 },
    landing_bell = { 120, 168 },
    workshop = { 192, 144 },
    first_runner = { 120, 108 },
    hire_porter = { 48, 64 },
    hire_sawyer = { 48, 64 },
    hire_hauler = { 48, 64 },
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
    things.wheel = box(TycoonConfig.WHEEL_STAND.x, TycoonConfig.WHEEL_STAND.y, 120, 120)
    local PIER = TycoonConfig.PIER -- pontonul inalt, 32x56 la x3, centrat
    things.pier = { x0 = PIER.x - 48, x1 = PIER.x + 48, y0 = PIER.y - 84, y1 = PIER.y + 84 }
    things.spawn = box(TycoonConfig.SPAWN.x, TycoonConfig.SPAWN.y, 48, 72)
    for _, role in { "sawyer", "trader" } do
        for index = 1, 2 do
            local s = HandRoutes.standFor(role, index) :: { x: number, y: number }
            things[`{role}_{index}`] = box(s.x, s.y, 48, 72)
        end
    end
    for name, p in TycoonConfig.PILES do
        -- pictogramele (x -24..28, y -22..22) si cifra (52x24): deasupra sau in dreapta
        if p.pill == "right" then
            things[`pile_{name}`] = { x0 = p.x - 24, x1 = p.x + 84, y0 = p.y - 22, y1 = p.y + 22 }
        else
            things[`pile_{name}`] = { x0 = p.x - 26, x1 = p.x + 28, y0 = p.y - 50, y1 = p.y + 22 }
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
        test.case("48 de platforme, index = pozitia in lista", function()
            -- Bugul pe care il apara testul: daca `index` se dezalinieaza de pozitia reala,
            -- padStatuses (care merge prin PADS in ordine) si greedyRun (care citeste PRICES[k])
            -- ar arata/cumpara platforma gresita fara nicio eroare.
            check.equal(#TycoonConfig.PADS, 48)
            for i, p in TycoonConfig.PADS do
                check.equal(p.index, i)
            end
        end)

        test.case("Era 1 are 13 deblocari, Era 2 are 11, erele 3-4 cate 12", function()
            -- Era 1 a scazut de la 12 la 10 cand Sorting Crate si Dock Stall au devenit niveluri
            -- ale debarcaderului, iar Weighted Nets pragul de nivel 10 al plaselor. Apoi 11 cu
            -- Sawyer-ul [D48], iar Era 2 a pierdut gaterul, mutat in lantul Erei 1. Apoi 13 cu
            -- Porter-ul si Hauler-ul [D49]. Erele 2-4 sunt inca in forma veche: se rescriu cand
            -- devin live.
            local perEra = { [1] = 0, [2] = 0, [3] = 0, [4] = 0 }
            for _, p in TycoonConfig.PADS do
                perEra[p.era] = (perEra[p.era] or 0) + 1
            end
            check.equal(perEra[1], 13)
            check.equal(perEra[2], 11)
            check.equal(perEra[3], 12)
            check.equal(perEra[4], 12)
        end)

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

        test.case("ponderile GOODS insumeaza 1", function()
            local sum = 0
            for _, g in TycoonConfig.GOODS do
                sum += g.share
            end
            check.is_true(math.abs(sum - 1) < 1e-9)
        end)

        test.case("primul bun (driftwood) nu are minLanes", function()
            -- income() presupune ca GOODS[1] e bunul pe care cad ponderile celorlalte -- daca
            -- driftwood ar avea minLanes, portul din TycoonMath s-ar rupe in tacere.
            check.equal(TycoonConfig.GOODS[1].id, "driftwood")
            check.equal(TycoonConfig.GOODS[1].minLanes, nil)
        end)

        test.case("platformele live au pozitie in lume", function()
            -- O platforma jucabila fara pozitie n-ar avea unde sa fie desenata/atinsa.
            for _, p in TycoonConfig.PADS do
                if p.live then
                    check.is_true(p.x ~= nil)
                    check.is_true(p.y ~= nil)
                end
            end
        end)

        -- F1: toata Era 1 e live (angajatul, atelierul, clopotul inclusiv); erele 2-4 inca nu.
        test.case("live = exact cele 13 deblocari ale Erei 1", function()
            local liveCount = 0
            for _, p in TycoonConfig.PADS do
                check.equal(p.live, p.era == 1)
                if p.live then
                    liveCount += 1
                end
            end
            check.equal(liveCount, 13)
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
            local outside = {}
            for _, name in names do
                local b = things[name]
                if b.x0 < landing.x0 or b.x1 > landing.x1 or b.y1 > bottom then
                    table.insert(outside, name)
                end
            end
            for _, name in outside do
                print("  ! in afara terenului: " .. name)
            end
            check.equal(#outside, 0)
        end)

        test.case(
            "nimic construit nu sta pe drum, iar locurile de predare sunt langa drum",
            function()
                -- Platformele si cladirile stau LANGA drumuri, nu pe ele; doar plasele stau pe punte.
                -- Oamenii si gramezile au voie pe marginea drumului: acolo lasa si iau marfa.
                local things = placed()
                local roads: { Box } = {}
                for _, r in TycoonConfig.ROADS do
                    table.insert(roads, { x0 = r.x0, x1 = r.x1, y0 = r.y0, y1 = r.y1 })
                end
                local onRoad = {}
                for _, name in { "storage", "sawmill", "tavern", "wheel", "spawn" } do
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
                            local d = TycoonConfig.DECK
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

        test.case("roata zilnica sta in zona si nu atinge nimic", function()
            -- Roata e un BUTON in lume, ca si platformele, deci poate fura clicuri exact la fel.
            -- Prinsa de baza (AnchorPoint 0.5,1), la 40 de pixeli de sprite si PIXEL_SCALE 3.
            local w = 40 * 3
            local x0, x1 = TycoonConfig.WHEEL_STAND.x - w / 2, TycoonConfig.WHEEL_STAND.x + w / 2
            local y0, y1 = TycoonConfig.WHEEL_STAND.y - w, TycoonConfig.WHEEL_STAND.y

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
                    if px + half > x0 and px - half < x1 and py + half > y0 and py - half < y1 then
                        clashes += 1
                    end
                end
            end
            check.equal(clashes, 0)
            -- taverna, Innkeeper-ul si restul le verifica testul de mai sus (`placed`)
        end)

        test.case("preturile Erei 1 sunt exact cele din simulator", function()
            -- Tiparite de `python3 scripts/economy/sim_tycoon.py` pe modelul cu niveluri si
            -- gatuire. ATENTIE: lista de aici nu citeste simulatorul -- asa a putut config-ul sa
            -- ramana cu 2500/2800/13000 cand simulatorul deriva 1500/1600/10000, si testul trecea.
            -- Garda reala e acum in simulator (`check_config_prices`), care citeste chiar fisierul
            -- Luau. Testul ramane ca document al cifrelor. Erele 2-4 se re-deriva cand devin live.
            -- [D52] Re-derivate pe ordinea noua: oamenii iau primele trepte ale scarii, pe venitul
            -- plat al unei singure plase, deci ies ieftini; plasele de dupa ei, scumpe.
            local era1 = {
                first_net = 0,
                first_runner = 13,
                hire_porter = 15,
                hire_sawyer = 18,
                hire_hauler = 20,
                dock_trader = 25,
                second_net = 30,
                third_net = 100,
                bigger_sack = 90,
                far_lane_net = 900,
                workshop = 7000,
                fifth_net = 7500,
                landing_bell = 10000,
            }
            local seen = 0
            for _, p in TycoonConfig.PADS do
                if p.era == 1 then
                    seen += 1
                    check.equal(p.price, era1[p.id])
                end
            end
            check.equal(seen, 13)
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

        test.case("fiecare meserie are o platforma de angajare in Era 1, si invers", function()
            -- CREWS e singura legatura dintre o platforma si omul pe care il aduce [D49]: PadService
            -- angajeaza prin ea, meniul o citeste, simulatorul ii verifica pretul celui de-al doilea.
            local StationConfig = require("../src/Shared/Config/StationConfig")
            for _, role in StationConfig.ROLES do
                local crew = TycoonConfig.CREWS[role]
                check.not_nil(crew)
                local p = TycoonConfig.byId[crew.pad]
                check.not_nil(p)
                check.equal(p.era, 1)
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
    end)
end
