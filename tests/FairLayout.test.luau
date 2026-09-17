--!strict
-- [D60] Asezarea bâlciului: nimic nu intra in altceva, totul e pe harta, iar locul unde acostezi e liber.
-- Testul asta e chiar verificarea care a prins suprapunerile pe macheta (felinare in scena, roata in iaz).
local frktest = require("@frktest/frktest")
local test = frktest.test
local check = frktest.assert.check

local FairLayout = require("../src/Shared/Modules/FairLayout")
local Assets = require("../src/Shared/Config/Assets")
local FishConfig = require("../src/Shared/Config/FishConfig")
local Strings = require("../src/Shared/Config/Strings")

-- Fontul de pixeli: 0,5586 em pe litera, randul ~1,1 em (vezi Theme.textWidth / capcana din CLAUDE.md).
local EM = 0.5586
local TINY, SMALL = 13, 15

local function spotBox(id: string): FairLayout.Rect
    for _, spot in FairLayout.SPOTS do
        if spot.id == id then
            local art = (Assets.fair :: any)[spot.sprite]
            return FairLayout.boxOf(spot, art.width, art.height)
        end
    end
    error(`loc necunoscut: {id}`)
end

local function textWidth(text: string, size: number): number
    local widest = 0
    for _, line in string.split(text, "\n") do
        widest = math.max(widest, #line * EM * size)
    end
    return widest
end

local function pairKey(a: string, b: string): string
    return if a < b then `{a}_{b}` else `{b}_{a}`
end

return function()
    test.suite("FairLayout", function()
        test.case("fiecare obiect are desenul lui in Assets.fair", function()
            local missing = {}
            for _, spot in FairLayout.SPOTS do
                local art = (Assets.fair :: any)[spot.sprite]
                if art == nil or art.width == nil then
                    table.insert(missing, `{spot.id} ({spot.sprite})`)
                elseif not Assets.has(art) then
                    table.insert(missing, `{spot.id}: desen neurcat`)
                end
            end
            check.equal(table.concat(missing, ", "), "")
        end)

        test.case("id-urile sunt unice", function()
            local seen: { [string]: boolean } = {}
            local twice = {}
            for _, spot in FairLayout.SPOTS do
                if seen[spot.id] then
                    table.insert(twice, spot.id)
                end
                seen[spot.id] = true
            end
            check.equal(table.concat(twice, ", "), "")
        end)

        test.case("nimic nu intra in altceva, in afara perechilor care au voie", function()
            local boxes: { { id: string, box: FairLayout.Rect } } = {}
            for _, spot in FairLayout.SPOTS do
                local art = (Assets.fair :: any)[spot.sprite]
                table.insert(
                    boxes,
                    { id = spot.id, box = FairLayout.boxOf(spot, art.width, art.height) }
                )
            end
            local clashes = {}
            for i = 1, #boxes do
                for j = i + 1, #boxes do
                    local a, b = boxes[i], boxes[j]
                    if
                        FairLayout.overlap(a.box, b.box)
                        and not (FairLayout.TOUCHING :: any)[pairKey(a.id, b.id)]
                    then
                        table.insert(clashes, `{a.id} x {b.id}`)
                    end
                end
            end
            check.equal(table.concat(clashes, ", "), "")
        end)

        test.case("totul sta pe harta, iar apa ramane a barcii", function()
            local outside, onWater = {}, {}
            for _, spot in FairLayout.SPOTS do
                local art = (Assets.fair :: any)[spot.sprite]
                local box = FairLayout.boxOf(spot, art.width, art.height)
                if
                    box.x0 < 0
                    or box.x1 > FairLayout.SIZE.w
                    or box.y0 < 0
                    or box.y1 > FairLayout.SIZE.h
                then
                    table.insert(outside, spot.id)
                end
                -- doar debarcaderul si barca au voie sa atinga raul de jos
                if box.y1 > FairLayout.WATER_Y and spot.id ~= "dock" and spot.id ~= "ferry" then
                    table.insert(onWater, spot.id)
                end
            end
            check.equal(table.concat(outside, ", "), "")
            check.equal(table.concat(onWater, ", "), "")
        end)

        test.case("acostezi pe un loc liber, de unde se ajunge la vatra", function()
            local spawn = FairLayout.SPAWN
            local blocked = {}
            for _, spot in FairLayout.SPOTS do
                local art = (Assets.fair :: any)[spot.sprite]
                local box = FairLayout.boxOf(spot, art.width, art.height)
                if
                    spawn.x > box.x0 - 24
                    and spawn.x < box.x1 + 24
                    and spawn.y > box.y0 - 24
                    and spawn.y < box.y1 + 24
                then
                    table.insert(blocked, spot.id)
                end
            end
            check.equal(table.concat(blocked, ", "), "")
            check.is_false(FairLayout.onFloor(spawn.x, spawn.y)) -- acostezi pe iarba, apoi urci in poiana
            check.is_true(FairLayout.onFloor(FairLayout.CENTER.x, FairLayout.CENTER.y))
        end)

        test.case("fiecare margine are eticheta ei si un loc pe harta", function()
            local seen: { [string]: boolean } = {}
            local bad = {}
            for _, edge in FairLayout.EDGES do
                if seen[edge.id] or edge.label == "" then
                    table.insert(bad, edge.id)
                end
                seen[edge.id] = true
                if
                    edge.x < 0
                    or edge.x > FairLayout.SIZE.w
                    or edge.y < 0
                    or edge.y > FairLayout.SIZE.h
                then
                    table.insert(bad, `{edge.id} (in afara hartii)`)
                end
            end
            check.equal(table.concat(bad, ", "), "")
            check.equal(#FairLayout.EDGES, 8)
        end)

        test.case("se merge pe mal si in poiana, nu in rau, in iaz sau in afara hartii", function()
            check.is_true(FairLayout.isWalkable(FairLayout.SPAWN.x, FairLayout.SPAWN.y))
            check.is_true(FairLayout.isWalkable(FairLayout.CENTER.x, FairLayout.CENTER.y))
            check.is_false(FairLayout.isWalkable(810, FairLayout.WATER_Y))
            check.is_false(FairLayout.isWalkable(810, FairLayout.SIZE.h - 10))
            check.is_false(FairLayout.isWalkable(FairLayout.POND.x, FairLayout.POND.y))
            check.is_false(FairLayout.isWalkable(-1, 500))
            check.is_false(FairLayout.isWalkable(FairLayout.SIZE.w + 1, 500))
            check.is_false(FairLayout.isWalkable(500, -1))
        end)

        test.case("etichetele din lume nu intra peste obiecte care nu sunt ale lor", function()
            -- Aceleasi socoteli ca in controllere: BoardController (trofeele, campionul), MarketController (firma),
            -- FairScene (barca spre casa, placutele marginilor inchise). O placuta a unei margini sta pe obiectul ei.
            -- `shows`: doua etichete care nu apar niciodata impreuna (cele patru ale trofeelor si fraza de sub rand
            -- cand niciun trofeu n-are record) nu au cum sa se calce
            local tags: { { id: string, box: FairLayout.Rect, host: string?, shows: string? } } = {}
            local function centered(
                id: string,
                cx: number,
                top: number,
                w: number,
                h: number,
                host: string?,
                shows: string?
            )
                table.insert(tags, {
                    id = id,
                    box = { x0 = cx - w / 2, x1 = cx + w / 2, y0 = top, y1 = top + h },
                    host = host,
                    shows = shows,
                })
            end
            local tag = FairLayout.TROPHY_TAG
            for i = 1, 4 do
                local b = spotBox(`trophy_{i}`)
                centered(
                    `trophy_tag_{i}`,
                    (b.x0 + b.x1) / 2,
                    b.y1 + tag.gap,
                    tag.w,
                    tag.h,
                    nil,
                    "records"
                )
            end
            local first, last = spotBox("trophy_1"), spotBox("trophy_4")
            centered(
                "trophy_caption",
                (first.x0 + last.x1) / 2,
                first.y1 + tag.gap,
                (last.x0 + last.x1) / 2 - (first.x0 + first.x1) / 2 + tag.w,
                20,
                nil,
                "no_records"
            )
            local plinth = spotBox("plinth")
            local cw = math.ceil(textWidth(Strings.CHAMPION_TAG, TINY)) + 20
            centered("champion", (plinth.x0 + plinth.x1) / 2, plinth.y0 - 4 - 36, cw, 36)
            local stall = spotBox("stall_1")
            local mw = math.ceil(textWidth(Strings.MARKET_TITLE, SMALL)) + 24
            centered("market_sign", (stall.x0 + stall.x1) / 2, stall.y0 - 6 - 26, mw, 26)
            -- [2026-09-17] etichetele marginilor sunt doar text cu contur (FairScene.tag): titlul la SMALL, dedesubt
            -- "Opens soon" la TINY
            local ferry = spotBox("ferry")
            centered(
                "ferry_tag",
                (ferry.x0 + ferry.x1) / 2,
                ferry.y0 - 16 - 9,
                math.ceil(textWidth(Strings.FAIR_FERRY_TAG, SMALL)) + 12,
                18
            )
            -- [D61] numele gheretelor, deasupra lor (BoothController), ca firma negustorului
            for _, booth in FairLayout.BOOTHS do
                local b = spotBox(booth.spot)
                local w = math.ceil(textWidth(booth.label, SMALL)) + 24
                centered(`booth_sign_{booth.spot}`, (b.x0 + b.x1) / 2, b.y0 - 6 - 26, w, 26)
            end
            local hosts = { tailor = "tent", gate = "arch", games = "booth_1", pond = "pond_dock" }
            for _, edge in FairLayout.EDGES do
                if not edge.open then
                    local w = math.max(
                        math.ceil(textWidth(edge.label, SMALL)) + 12,
                        math.ceil(textWidth(Strings.FAIR_OPENS_SOON, TINY)) + 12
                    )
                    centered(`plaque_{edge.id}`, edge.x, edge.y - 17, w, 35, hosts[edge.id])
                end
            end

            local hits = {}
            for i, label in tags do
                for _, spot in FairLayout.SPOTS do
                    if
                        spot.id ~= label.host and FairLayout.overlap(label.box, spotBox(spot.id))
                    then
                        table.insert(hits, `{label.id} x {spot.id}`)
                    end
                end
                for j = i + 1, #tags do
                    local other = tags[j]
                    local apart = label.shows ~= nil
                        and other.shows ~= nil
                        and label.shows ~= other.shows
                    if not apart and FairLayout.overlap(label.box, other.box) then
                        table.insert(hits, `{label.id} x {other.id}`)
                    end
                end
                local b = label.box
                if b.x0 < 0 or b.x1 > FairLayout.SIZE.w or b.y0 < 0 or b.y1 > FairLayout.SIZE.h then
                    table.insert(hits, `{label.id} iese din harta`)
                end
            end
            check.equal(table.concat(hits, ", "), "")
        end)

        test.case("textul de sub trofee incape in eticheta lui", function()
            -- [2026-09-17] cutiile nu se atingeau, dar "Not caught yet" era mai lat decat cutia: in Studio, cele patru
            -- etichete se calcau. Aici se masoara fiecare rand care poate ajunge pe eticheta.
            local tag = FairLayout.TROPHY_TAG
            local wide = {}
            local function fits(what: string, text: string, width: number)
                if textWidth(text, TINY) > width then
                    table.insert(wide, `{what} ({math.ceil(textWidth(text, TINY))} > {width})`)
                end
            end
            for _, species in FishConfig.SPECIES do
                fits(species.name, species.name, tag.w)
                fits(`{species.name} max`, Strings.trophyLine(species.maxCm), tag.w)
            end
            fits("nume taiat", string.rep("W", tag.chars), tag.w)
            fits("fara record", Strings.TROPHY_OPEN, tag.w)
            -- trei randuri incap pe inaltime
            check.is_true(3 * TINY * 1.1 <= tag.h)
            local first, last = spotBox("trophy_1"), spotBox("trophy_4")
            local rowWidth = (last.x0 + last.x1) / 2 - (first.x0 + first.x1) / 2 + tag.w
            fits("niciun record", Strings.TROPHIES_EMPTY, rowWidth)
            check.equal(table.concat(wide, ", "), "")
        end)

        test.case("jetiul duce de pe malul de sud in iaz, iar de pe el se arunca in apa", function()
            local j = FairLayout.JETTY
            local midX = (j.x0 + j.x1) / 2
            for y = j.y0, j.y1, 12 do
                check.is_true(FairLayout.isWalkable(midX, y))
            end
            -- la baza lui se ajunge de pe mal, iar capatul lui e in apa
            check.is_true(FairLayout.isWalkable(midX, j.y1 + 16))
            check.is_false(FairLayout.inPond(midX, j.y1 + 16))
            check.is_true(FairLayout.inPond(midX, j.y0))
            -- langa jetiu nu se merge
            check.is_false(FairLayout.isWalkable(j.x0 - 30, j.y0 + 40))
            check.is_false(FairLayout.isWalkable(j.x1 + 30, j.y0 + 40))
            -- se arunca doar de pe jetiu, de deasupra apei; plutitorul cade in apa, nu pe scanduri, de ambele parti
            local z = FairLayout.CAST_ZONE
            local bad = {}
            for y = z.y0, z.y1, 7 do
                if not FairLayout.inPond(midX, y) then
                    table.insert(bad, `aruncare de pe mal la y {y}`)
                end
                for _, side in { "left", "right" } do
                    local bx, by = FairLayout.bobberFor(y, side)
                    if not FairLayout.inPond(bx, by) or FairLayout.inRect(j, bx, by) then
                        table.insert(bad, `plutitor {side} la y {y}`)
                    end
                end
            end
            check.is_true(z.x0 >= j.x0 and z.x1 <= j.x1 and z.y0 >= j.y0 and z.y1 <= j.y1)
            check.equal(table.concat(bad, ", "), "")
        end)

        test.case(
            "locurile de stat jos sunt langa obiectul lor, pe pamant, si nu se calca",
            function()
                local hosts: { [string]: FairLayout.Spot } = {}
                for _, spot in FairLayout.SPOTS do
                    hosts[spot.id] = spot
                end
                local bad = {}
                local seen: { [string]: boolean } = {}
                for i, seat in FairLayout.SEATS do
                    local host = hosts[seat.host]
                    if host == nil then
                        table.insert(bad, `{seat.id}: fara obiect`)
                        continue
                    end
                    if seen[seat.id] then
                        table.insert(bad, `{seat.id} de doua ori`)
                    end
                    seen[seat.id] = true
                    if seat.z ~= host.y then
                        table.insert(bad, `{seat.id}: z nu e baza obiectului`)
                    end
                    -- omul sta chiar in spatele obiectului, care ii acopera picioarele
                    if
                        seat.y >= seat.z
                        or seat.z - seat.y > 20
                        or math.abs(seat.x - host.x) > 60
                    then
                        table.insert(bad, `{seat.id}: nu sta la obiectul lui`)
                    end
                    if not FairLayout.isWalkable(seat.x, seat.y) then
                        table.insert(bad, `{seat.id} in apa`)
                    end
                    if FairLayout.seatById(seat.id) ~= seat then
                        table.insert(bad, `{seat.id} nu se gaseste dupa id`)
                    end
                    for k = i + 1, #FairLayout.SEATS do
                        local o = FairLayout.SEATS[k]
                        if math.abs(o.x - seat.x) < 100 and math.abs(o.y - seat.y) < 40 then
                            table.insert(bad, `{seat.id} x {o.id}: etichetele s-ar calca`)
                        end
                    end
                end
                check.equal(table.concat(bad, ", "), "")
                check.is_true(#FairLayout.SEATS >= 10)
            end
        )

        test.case("cel mai apropiat loc liber, pana la distanta data", function()
            local a = FairLayout.SEATS[1]
            local seat, distance = FairLayout.nearestSeat(a.x + 3, a.y + 4, FairLayout.SEAT_REACH)
            check.equal(seat, a)
            check.equal(distance, 5)
            -- prea departe: nimic
            local far =
                FairLayout.nearestSeat(a.x, a.y + FairLayout.SEAT_REACH + 1, FairLayout.SEAT_REACH)
            check.equal(far, nil)
            -- ocupat: se sare peste el
            local skipped = FairLayout.nearestSeat(a.x, a.y, FairLayout.SEAT_REACH, function(s)
                return s == a
            end)
            check.is_true(skipped ~= a)
            -- la masa, locul mai apropiat dintre cele doua
            local left, right = FairLayout.seatById("table_1_a"), FairLayout.seatById("table_1_b")
            assert(left ~= nil and right ~= nil, "mesele")
            check.equal(
                FairLayout.nearestSeat(left.x + 10, left.y + 20, FairLayout.SEAT_REACH),
                left
            )
            check.equal(
                FairLayout.nearestSeat(right.x - 10, right.y + 20, FairLayout.SEAT_REACH),
                right
            )
        end)

        test.case("fiecare gheretă are jocul ei", function()
            local games: { [string]: boolean } = {}
            for _, booth in FairLayout.BOOTHS do
                spotBox(booth.spot) -- da eroare daca locul nu exista
                check.is_true(booth.game == "ring" or booth.game == "duck")
                check.is_true(games[booth.game] == nil)
                games[booth.game] = true
            end
            check.equal(#FairLayout.BOOTHS, 2)
        end)

        test.case("la fiecare margine se ajunge pe jos", function()
            local unreachable = {}
            for _, edge in FairLayout.EDGES do
                if not FairLayout.isWalkable(edge.x, edge.y) then
                    table.insert(unreachable, edge.id)
                end
            end
            check.equal(table.concat(unreachable, ", "), "")
        end)
    end)
end
