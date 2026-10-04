--!strict
-- [D75, lotul A2] Decorul filmului barajului (DamFilmSet, pur) si cronologia lui noua (DamMath.frameAt: `rise`, `built`).
local frktest = require("@frktest/frktest")
local test = frktest.test
local check = frktest.assert.check

local DamFilmSet = require("../src/Shared/Modules/DamFilmSet")
local DamMath = require("../src/Shared/Modules/DamMath")
local RiverConfig = require("../src/Shared/Config/RiverConfig")
local Shoreline = require("../src/Shared/Modules/Shoreline")
local TycoonConfig = require("../src/Shared/Config/TycoonConfig")

local function phase(name: string): DamMath.FilmPhase
    for _, p in DamMath.FILM do
        if p.phase == name then
            return p
        end
    end
    error("faza lipsa: " .. name)
end

return function()
    test.suite("DamFilmSet - zidul care creste [D75, lotul A2]", function()
        test.case(
            "zidul sta pe linia barajului din lumea 2, pe grila, de la un mal la altul",
            function()
                local wall = DamFilmSet.wall()
                local dam = (TycoonConfig.WORLDS[2] :: any).wall
                check.equal(wall.x0 % 3, 0)
                check.equal(wall.top % 3, 0)
                check.equal(wall.bottom % 3, 0)
                check.is_true(math.abs(wall.x0 - dam.x) <= 1)
                check.equal(wall.x1 - wall.x0, dam.w)
                -- intra in ambele maluri ale satului, pe toata latimea lui
                local river = (RiverConfig.WORLDS :: any)[1]
                for x = wall.x0, wall.x1, 6 do
                    check.is_true(wall.top < Shoreline.edgeY(river.SHORE_FAR, x))
                    check.is_true(wall.bottom > Shoreline.edgeY(river.SHORE_NEAR, x))
                end
                -- si nu trece de marginea de sus a puntii (oamenii stau pe ea, in fata zidului)
                check.is_true(wall.bottom <= TycoonConfig.DECK.y0)
            end
        )
        test.case("jumatatile cresc pe grila si se ating exact la capat", function()
            local wall = DamFilmSet.wall()
            local lastN, lastS = -1, -1
            for i = 0, 20 do
                local n, s = DamFilmSet.halves(i / 20)
                check.equal(n % 3, 0)
                check.is_true(n >= lastN and s >= lastS)
                check.is_true(n + s <= wall.bottom - wall.top)
                lastN, lastS = n, s
            end
            local n, s = DamFilmSet.halves(1)
            check.equal(n + s, wall.bottom - wall.top)
            check.equal(select(1, DamFilmSet.halves(0)), 0)
        end)
        test.case(
            "capetele neterminate nu se opresc pe treptele zidului (directorul A2)",
            function()
                local wall = DamFilmSet.wall()
                local span = wall.bottom - wall.top
                local lastN, lastS = 0, 0
                for i = 0, 400 do
                    local n, s = DamFilmSet.halves(i / 400)
                    local nRows, sRows = n / 3, s / 3
                    check.is_false(
                        nRows >= DamFilmSet.SKIP_NORTH.from and nRows <= DamFilmSet.SKIP_NORTH.to
                    )
                    if i < 400 then
                        check.is_false(
                            sRows >= DamFilmSet.SKIP_SOUTH.from
                                and sRows <= DamFilmSet.SKIP_SOUTH.to
                        )
                    end
                    check.is_true(n + s <= span)
                    check.is_true(n >= lastN and s >= lastS)
                    lastN, lastS = n, s
                end
            end
        )
        test.case("plasele de pe linia zidului ies din apa, celelalte nu", function()
            local x0, x1 = DamFilmSet.liftRange()
            local lifted = {}
            for _, p in TycoonConfig.padsOfWorld(1) do
                local net = false
                for _, e in p.effects do
                    net = net or e.kind == "net"
                end
                if net and p.x ~= nil and p.x >= x0 and p.x <= x1 then
                    lifted[p.id] = true
                end
            end
            check.is_true(lifted.first_net == true)
            check.is_true(lifted.second_net == true)
            local wall = DamFilmSet.wall()
            for id in lifted do
                local p = TycoonConfig.byId[id]
                -- doar plasele pe care zidul chiar le-ar acoperi (stalpul langa el)
                check.is_true(
                    math.abs((p.x :: number) - (wall.x0 + wall.x1) / 2)
                        <= (wall.x1 - wall.x0) / 2 + 60
                )
            end
        end)
    end)

    test.suite("DamFilmSet - oamenii si santierul [D75, lotul A2]", function()
        test.case("toti oamenii ajung pe punte inainte de cartonas", function()
            local people, card = phase("people"), phase("card")
            local deck = TycoonConfig.DECK
            local walkers = DamFilmSet.walkers()
            check.equal(#walkers, DamFilmSet.WALKERS)
            local kinds = {}
            for _, w in walkers do
                kinds[w.kind] = true
                check.is_true(DamFilmSet.arrivesAt(w) <= card.from - people.from)
                check.is_true(w.toX >= deck.x0 and w.toX <= deck.x1)
                check.is_true(w.toY >= deck.y0 and w.toY <= deck.y1)
                -- pornesc de pe o alee, sub punte, si merg si intr-o parte (mersul din profil se vede)
                check.is_true(w.fromY > deck.y1)
                check.is_true(math.abs(w.toX - w.fromX) >= 60)
                check.equal(w.path[1].x, w.fromX)
                check.equal(w.path[#w.path].x, w.toX)
                local x, y, moving = DamFilmSet.walkerAt(w, 0)
                check.equal(x, w.fromX)
                check.equal(y, w.fromY)
                check.is_false(moving)
                local ex, ey, still = DamFilmSet.walkerAt(w, card.from - people.from)
                check.equal(ex, w.toX)
                check.equal(ey, w.toY)
                check.is_false(still)
            end
            -- toate cele patru randuri ale foii (gol, grinda, piatra, felinar)
            for k = 0, 3 do
                check.is_true(kinds[k] == true)
            end
        end)
        test.case("doi oameni nu stau unul peste altul pe punte", function()
            local walkers = DamFilmSet.walkers()
            for i = 1, #walkers do
                for j = i + 1, #walkers do
                    local a, b = walkers[i], walkers[j]
                    local apart = math.abs(a.toX - b.toX) >= 24 or math.abs(a.toY - b.toY) >= 16
                    check.is_true(apart)
                end
            end
        end)
        test.case(
            "pe punte nimeni nu sta pe stalpi, insigne, recuzita, roata sau avizier",
            function()
                local posts = DamFilmSet.deckPosts()
                check.is_true(#posts >= 4)
                local boxes = DamFilmSet.propBoxes()
                for _, w in DamFilmSet.walkers() do
                    for _, px in posts do
                        check.is_true(math.abs(w.toX - px) >= DamFilmSet.POST_CLEAR)
                    end
                    local me = DamFilmSet.personBox(w.toX, w.toY)
                    for _, b in boxes do
                        local hit = me.x0 < b.x1 and b.x0 < me.x1 and me.y0 < b.y1 and b.y0 < me.y1
                        check.is_false(hit)
                    end
                    for _, b in DamFilmSet.deckObstacles() do
                        local hit = me.x0 < b.x1 and b.x0 < me.x1 and me.y0 < b.y1 and b.y0 < me.y1
                        check.is_false(hit)
                    end
                end
                -- recuzita nu sta nici ea pe stalpi (cu insignele lor), pe roata sau pe avizierul satului
                for _, b in boxes do
                    for _, px in posts do
                        check.is_true(b.x1 <= px - 28 or b.x0 >= px + 28)
                    end
                    for _, o in DamFilmSet.deckObstacles() do
                        check.is_false(b.x0 < o.x1 and o.x0 < b.x1 and b.y0 < o.y1 and o.y0 < b.y1)
                    end
                end
                check.is_true(DamFilmSet.FADE_IN > 0 and DamFilmSet.FADE_IN <= 1)
            end
        )
        -- [verificatorul A2] in linie dreapta, siluetele treceau peste depozit, gramada lui si gater: acum talpile stau tot
        -- drumul pe un drum al satului sau pe punte (unde nu e construit nimic)
        test.case("drumul fiecarui om e pe drumuri si pe punte, nu prin cladiri", function()
            local people, card = phase("people"), phase("card")
            local deck = TycoonConfig.DECK
            local function onWay(x: number, y: number): boolean
                if x >= deck.x0 and x <= deck.x1 and y >= deck.y0 and y <= deck.y1 + 12 then
                    return true
                end
                for _, r in TycoonConfig.ROADS do
                    if x >= r.x0 and x <= r.x1 and y >= r.y0 - 12 and y <= r.y1 then
                        return true
                    end
                end
                return false
            end
            for _, w in DamFilmSet.walkers() do
                for i = 0, 100 do
                    local x, y = DamFilmSet.walkerAt(w, (card.from - people.from) * i / 100)
                    check.is_true(onWay(x, y))
                end
            end
        end)
        test.case("pe punte nimeni nu sta exact in spatele altuia", function()
            local walkers = DamFilmSet.walkers()
            check.equal(#walkers, DamFilmSet.WALKERS)
            local tall = DamFilmSet.CELL_H * DamFilmSet.PERSON_SCALE
            for i = 1, #walkers do
                for j = i + 1, #walkers do
                    local a, b = walkers[i], walkers[j]
                    if a.toY ~= b.toY and math.abs(a.toY - b.toY) < tall then
                        check.is_true(math.abs(a.toX - b.toX) >= 12)
                    end
                end
            end
        end)
        -- [verificatorul A2] ce nu incape intreg in cadru nu se arata (DamFilm), deci nimic nu e taiat de margine
        test.case("o recuzita se arata doar intreaga in cadru", function()
            local boxes = DamFilmSet.propBoxes()
            check.is_true(DamFilmSet.fitsView(boxes[1], 1205)) -- macaraua
            check.is_true(DamFilmSet.fitsView(boxes[3], 1205)) -- gramada
            check.is_false(DamFilmSet.fitsView(boxes[2], 1440)) -- caruta: pe 16:10 ar fi doar manerul
            check.is_true(DamFilmSet.fitsView(boxes[2], 1600))
            for _, vw in { 1000, 1205, 1350, 1440, 1500, 1600 } do
                for _, b in boxes do
                    if DamFilmSet.fitsView(b, vw) then
                        local camX = math.max(0, DamFilmSet.camera(900) - vw / 2)
                        check.is_true(b.x0 >= camX and b.x1 <= camX + vw)
                    end
                end
            end
        end)
        -- [verificatorul A2] pe alee omul priveste deja spre locul lui de pe punte
        test.case("pe alee si pe punte omul priveste in aceeasi parte", function()
            local people = phase("people")
            for _, w in DamFilmSet.walkers() do
                local _, _, _, onAlley = DamFilmSet.walkerAt(w, 0.2)
                local _, _, _, onDeck = DamFilmSet.walkerAt(w, DamFilmSet.arrivesAt(w) - 0.05)
                check.equal(onAlley, onDeck)
                check.is_true(people.from >= 0)
            end
        end)
        -- [verificatorul A2] macaraua si gramada se vad de la rau de la latimea 1205 in sus (caruta, abia pe 16:9)
        test.case("macaraua si gramada sunt in cadru la rau", function()
            local cx = DamFilmSet.camera(900)
            local boxes = DamFilmSet.propBoxes()
            for _, vw in { 1205, 1440, 1600 } do
                local camX = math.max(0, cx - vw / 2)
                for k, b in boxes do
                    if k ~= 2 or vw >= 1600 then
                        check.is_true(b.x0 >= camX and b.x1 <= camX + vw)
                    end
                end
            end
        end)
        test.case("oamenii de pe zid stau pe capetele neterminate", function()
            local wall = DamFilmSet.wall()
            for _, built in { 0.15, 0.5, 0.9 } do
                local n, s = DamFilmSet.halves(built)
                for _, w in DamFilmSet.workers(built) do
                    check.is_true(w.x >= wall.x0 + 16 and w.x <= wall.x1 - 16)
                    local onNorth = math.abs(w.y - (wall.top + n)) <= 8
                    local onSouth = math.abs(w.y - (wall.bottom - s)) <= 30
                    check.is_true(onNorth or onSouth)
                end
            end
        end)
        test.case("pe zidul inchis oamenii nu stau unul peste altul", function()
            local list = DamFilmSet.workers(1)
            for i = 1, #list do
                for j = i + 1, #list do
                    local a = DamFilmSet.personBox(list[i].x, list[i].y)
                    local b = DamFilmSet.personBox(list[j].x, list[j].y)
                    check.is_false(a.x0 < b.x1 and b.x0 < a.x1 and a.y0 < b.y1 and b.y0 < a.y1)
                end
            end
        end)
        test.case("macaraua, caruta si gramada stau pe punte, langa zid, nu pe el", function()
            local wall = DamFilmSet.wall()
            local deck = TycoonConfig.DECK
            for _, p in DamFilmSet.props() do
                check.is_true(p.y >= deck.y0 and p.y <= deck.y1)
                check.is_true(p.x < wall.x0 - 20 or p.x > wall.x1 + 20)
            end
        end)
        test.case("clopotul se leagana peste Works Bell, dus-intors", function()
            local bell = DamFilmSet.bell()
            check.not_nil(bell)
            local pad = TycoonConfig.byId.works_bell
            check.equal((bell :: DamFilmSet.Prop).y, TycoonConfig.buildingBase(pad))
            local seen = {}
            for i = 0, 7 do
                seen[DamFilmSet.bellFrame(i * 0.18)] = true
            end
            check.is_true(seen[0] and seen[1] and seen[2] or false)
        end)
    end)

    test.suite("DamMath.frameAt - camera la rau si zidul [D75, lotul A2]", function()
        test.case(
            "camera urca la rau la inceputul fazei build, zidul se inchide inainte de cartonas",
            function()
                local build, card = phase("build"), phase("card")
                check.equal(DamMath.frameAt(build.from - 0.01, false).rise, 0)
                check.equal(DamMath.frameAt(build.from - 0.01, false).built, 0)
                check.equal(DamMath.frameAt(build.from + DamMath.FILM_RISE_SECONDS, false).rise, 1)
                check.equal(DamMath.frameAt(build.from, false).built, DamMath.FILM_BUILT_FROM)
                check.equal(DamMath.frameAt(card.from - DamMath.FILM_MEET_BEFORE, false).built, 1)
                check.is_true(
                    DamMath.frameAt(card.from - DamMath.FILM_MEET_BEFORE - 0.2, false).built < 1
                )
                check.equal(DamMath.frameAt(card.from + 1, false).built, 1)
                -- urca lin, fara salturi; cu miscare redusa sare
                local last = 0
                for i = 0, 40 do
                    local r = DamMath.frameAt(build.from + i * 0.025, false).rise
                    check.is_true(r >= last and r - last < 0.1)
                    last = r
                end
                check.equal(DamMath.frameAt(build.from + 0.1, false, true).rise, 1)
            end
        )
        test.case("intre benzile negre se vad zidul (si puntea, cand incape)", function()
            local wall = DamFilmSet.wall()
            local deck = TycoonConfig.DECK
            local function band(vh: number): (number, number)
                local _, cy = DamFilmSet.camera(vh)
                return cy - vh / 2 + DamFilmSet.BAR * vh, cy + vh / 2 - DamFilmSet.BAR * vh
            end
            -- desktop / tableta (900 de lume): de la malul de nord pana la marginea de jos a puntii
            local top, bottom = band(900)
            check.is_true(top <= wall.top - 10 and bottom >= deck.y1)
            -- telefoanele (scara 0.85): zidul aproape intreg, cu ambele capete in lucru vazute
            for _, h in { 390, 430, 581 } do
                local vh = h / 0.85
                local t2, b2 = band(vh)
                local n, so = DamFilmSet.halves(0.3)
                check.is_true(t2 <= wall.top + 25 and b2 >= wall.bottom - 25)
                check.is_true(t2 < wall.top + n and b2 > wall.bottom - so)
            end
            local cx = DamFilmSet.camera(900)
            check.is_true(cx > wall.x0 and cx < wall.x1)
        end)
        test.case("la clopot camera porneste din dreptul lui: Works Bell e in cadru", function()
            local bell = DamFilmSet.bell() :: DamFilmSet.Prop
            local worldW = (RiverConfig.WORLDS :: any)[1].WORLD_WIDTH
            for _, vw in { 993, 1205, 1600, 2276 } do
                local camX = math.clamp(bell.x - vw / 2, 0, math.max(0, worldW - vw))
                check.is_true(bell.x - 60 >= camX and bell.x + 60 <= camX + vw)
            end
            -- [verificatorul A2] si pe verticala: tot clopotul intre benzile negre, si pe telefonul cel mai mic
            local worldH = (RiverConfig.WORLDS :: any)[1].WORLD_HEIGHT
            local midY = DamFilmSet.bellMidY() :: number
            local top = bell.y - 56 * 3
            for _, vh in { 459, 506, 684, 900 } do
                local camY = math.clamp(midY - vh / 2, 0, math.max(0, worldH - vh))
                check.is_true(top >= camY + DamFilmSet.BAR * vh)
                check.is_true(bell.y <= camY + vh - DamFilmSet.BAR * vh)
            end
        end)
    end)
end
