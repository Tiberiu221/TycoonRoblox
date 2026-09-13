-- [D53] Bustenii vin de la marginea lumii pe curentul de langa plase si cotesc in plasa.
local frktest = require("@frktest/frktest")
local test = frktest.test
local check = frktest.assert.check

local CatchFloat = require("../src/Shared/Modules/CatchFloat")
local TycoonConfig = require("../src/Shared/Config/TycoonConfig")

local function near(a: number, b: number, eps: number?): boolean
    return math.abs(a - b) < (eps or 1e-6)
end

-- plasele Erei 1: pozitia platformei si banda de pe efectul ei (pe ecran banda nu se muta cu nivelul)
local function eraNets(): { { id: string, x: number, y: number } }
    local out = {}
    for _, p in TycoonConfig.PADS do
        if p.era ~= 1 or p.x == nil then
            continue
        end
        for _, e in p.effects do
            if e.kind == "net" then
                table.insert(
                    out,
                    { id = p.id, x = p.x :: number, y = TycoonConfig.LANE_Y[e.lane or 1] }
                )
            end
        end
    end
    table.sort(out, function(a, b)
        return a.x < b.x
    end)
    return out
end

return function()
    test.suite("CatchFloat - drumul", function()
        test.case("drumul tine cat marginea lumii pana la plasa, la viteza curentului", function()
            check.is_true(near(CatchFloat.travel(620), (620 + 64) / 130))
            check.is_true(CatchFloat.travel(1420) > CatchFloat.travel(620))
        end)

        test.case("cotul creste cu coborarea: banda de langa mal nu e un plonjon", function()
            check.is_true(near(CatchFloat.turnFor(732), 216)) -- banda 1: coboara 180
            check.is_true(near(CatchFloat.turnFor(660), 129.6)) -- banda 2: coboara 108
            check.is_true(near(CatchFloat.turnFor(588), 120)) -- banda 3: minimul
            -- panta cea mai abrupta a smoothstep-ului e 1.5 x coborare / cot
            for _, y in { 732, 660, 588 } do
                local slope = (y - TycoonConfig.NEAR_CURRENT_Y) * 1.5 / CatchFloat.turnFor(y)
                check.is_true(slope <= 1.26)
            end
        end)

        test.case("porneste de la marginea lumii, estompat, si apare in FADE_IN", function()
            local t, travel = 100, CatchFloat.travel(620)
            local born = t - travel
            local x, y, alpha = CatchFloat.at(620, 732, t, born, "turn", 7, born)
            check.is_true(near(x, CatchFloat.SPAWN_X))
            check.is_true(near(alpha, 1))
            check.is_true(
                math.abs(y - TycoonConfig.NEAR_CURRENT_Y) <= CatchFloat.JITTER + CatchFloat.BOB
            )
            local _, _, later =
                CatchFloat.at(620, 732, t, born + CatchFloat.FADE_IN, "turn", 7, born)
            check.is_true(near(later, 0))
        end)

        test.case(
            "la momentul prinderii e chiar in plasa, apoi se micsoreaza si se stinge",
            function()
                local x, y, alpha, scale = CatchFloat.at(820, 732, 50, 50, "turn", 3, 0)
                check.is_true(near(x, 820) and near(y, 732))
                check.is_true(near(alpha, 0) and near(scale, 1))
                local _, _, gone, small =
                    CatchFloat.at(820, 732, 50, 50 + CatchFloat.SINK, "turn", 3, 0)
                check.is_true(near(gone, 1) and near(small, 0.4))
            end
        )

        test.case("plasa plina: trece drept pe langa ea si se stinge dupa PASS", function()
            local t = 50
            local _, y = CatchFloat.at(820, 732, t, t, "pass", 3, 0)
            check.is_true(math.abs(y - CatchFloat.lineY(3)) <= CatchFloat.BOB + 1e-6)
            local after = t + CatchFloat.PASS / CatchFloat.SPEED
            local _, _, alpha = CatchFloat.at(820, 732, t, after, "pass", 3, 0)
            check.is_true(near(alpha, 1))
        end)

        test.case("cotul se hotaraste o singura data, la intrarea in el", function()
            local turn = CatchFloat.turnFor(732)
            local before = 100 - (turn + 1) / CatchFloat.SPEED
            local inside = 100 - (turn - 1) / CatchFloat.SPEED
            check.is_false(CatchFloat.inTurn(620, 732, 100, before))
            check.is_true(CatchFloat.inTurn(620, 732, 100, inside))
        end)
    end)

    test.suite("CatchFloat - cati busteni si care", function()
        test.case("plasa inceata: fiecare prindere are bustean", function()
            check.equal(CatchFloat.stride(3, CatchFloat.travel(620)), 1)
        end)

        test.case("plasa rapida: cel mult MAX_IN_FLIGHT pe drum, la cel putin MIN_GAP", function()
            for _, interval in { 0.68, 0.2, 0.033, 0.01 } do
                local travel = CatchFloat.travel(1420)
                local stride = CatchFloat.stride(interval, travel)
                check.is_true(stride * interval >= CatchFloat.MIN_GAP - 1e-9)
                local slots = CatchFloat.slots(1000, interval, travel, 1000, stride)
                local ahead = 0
                for _, t in slots do
                    if t > 1000 then
                        ahead += 1
                    end
                end
                check.is_true(ahead <= CatchFloat.MAX_IN_FLIGHT + 1)
            end
        end)

        test.case("aceiasi busteni de la un cadru la altul, oricat avanseaza ceasul", function()
            local interval, travel = 0.5, CatchFloat.travel(1020)
            local stride = CatchFloat.stride(interval, travel)
            local a = CatchFloat.slots(1000, interval, travel, 1000, stride)
            -- un cadru mai tarziu, iar ceasul a trecut la momentul urmator
            local b = CatchFloat.slots(1000 + interval, interval, travel, 1000.016, stride)
            local inA: { [number]: boolean } = {}
            for _, t in a do
                inA[math.round(t * 10)] = true
            end
            local shared = 0
            for _, t in b do
                if inA[math.round(t * 10)] then
                    shared += 1
                end
            end
            check.is_true(shared >= #a - 1)
            for _, t in a do
                check.equal(math.round(t / interval) % stride, 0)
                check.is_true(t > 1000 - CatchFloat.LINGER - 1e-9 and t <= 1000 + travel + 1e-9)
            end
        end)

        test.case("interval nul: niciun bustean", function()
            check.equal(#CatchFloat.slots(1000, 0, 5, 1000, 1), 0)
        end)
    end)

    test.suite("CatchFloat - niciun drum prin alta plasa", function()
        test.case("linia si cotul trec pe deasupra plaselor din amonte", function()
            local nets = eraNets()
            check.equal(#nets, 5)
            local halfW, halfH = 27, 21 -- bustean de 54 lat, lada unei gasiri de 42 inalta
            local boxHalfW, boxHalfH = TycoonConfig.NET_DRAW.w / 2, TycoonConfig.NET_DRAW.h / 2
            for i, net in nets do
                for seed = 0, 8 do
                    for step = 0, 400 do
                        local now = 100 - step * 0.02
                        if now < 100 - CatchFloat.travel(net.x) then
                            break
                        end
                        local x, y = CatchFloat.at(net.x, net.y, 100, now, "turn", seed, 0)
                        for j = 1, i - 1 do
                            local up = nets[j]
                            local apartX = math.abs(x - up.x) < boxHalfW + halfW
                            local apartY = math.abs(y - up.y) < boxHalfH + halfH
                            if apartX and apartY then
                                print(`  ! {net.id} trece prin {up.id} la x={x} y={y}`)
                            end
                            check.is_false(apartX and apartY)
                        end
                    end
                end
            end
        end)
    end)
end
