local frktest = require("@frktest/frktest")
local test = frktest.test
local check = frktest.assert.check

local ObjectiveConfig = require("../src/Shared/Config/ObjectiveConfig")

return function()
    test.suite("ObjectiveConfig", function()
        test.case("niciun simbol de comanda nu scapa pe ecran", function()
            -- Indiciile contin {move}, {use}, {Tap}, {tap}, inlocuite pe client dupa felul de
            -- intrare. Un simbol scris gresit ({tapp}) ar ajunge pe ecran EXACT asa si nimeni
            -- n-ar observa pana in joc: nu da nicio eroare, doar arata a text negenerat.
            for _, step in ObjectiveConfig.STEPS do
                for _, touch in { true, false } do
                    local filled = ObjectiveConfig.fill(step.hint, touch)
                    check.is_true(string.find(filled, "{") == nil)
                    check.is_true(string.find(filled, "}") == nil)
                end
            end
            for _, goal in ObjectiveConfig.GOALS do
                for _, touch in { true, false } do
                    local filled = ObjectiveConfig.fill(goal.hint, touch)
                    check.is_true(string.find(filled, "{") == nil)
                    check.is_true(string.find(filled, "}") == nil)
                end
            end
        end)

        test.case("colectia se deschide odata cu atelierul, niciodata inainte", function()
            -- Indexul se umple DOAR reparand. Deschis mai devreme ar fi un panou gol pe care
            -- jucatorul nu are cum sa-l umple; deschis mai tarziu, ar repara fara sa vada
            -- pentru ce. Legatura e scrisa o data in unlockedAfter si testata aici.
            for step = 0, ObjectiveConfig.count() do
                local open = ObjectiveConfig.unlockedAfter(step)
                check.equal(open.index == true, open.workshop == true)
            end
        end)

        test.case("fiecare pas cere ceva deja deblocat", function()
            -- Bugul pe care il apara testul: un pas care cere atelierul, dar atelierul se
            -- deschide abia DUPA acel pas. Jucatorul ramane blocat fara nicio cale de iesire.
            local needs = {
                scrap_item = "workshop",
                build_tent = "build",
                assign_job = "people",
            }
            for index, step in ObjectiveConfig.STEPS do
                local required = needs[step.id]
                if required ~= nil then
                    local open = ObjectiveConfig.unlockedAfter(index)
                    check.is_true(open[required] == true)
                end
            end
        end)

        test.case("primii pasi nu deschid niciun panou mare", function()
            local open = ObjectiveConfig.unlockedAfter(1)
            check.equal(open.build, nil)
            check.equal(open.people, nil)
            check.equal(open.colony, nil)
            check.is_true(open.net == true)
        end)

        test.case("dupa ultimul pas totul e deschis", function()
            local open = ObjectiveConfig.unlockedAfter(ObjectiveConfig.count())
            for _, name in { "net", "workshop", "build", "people", "colony" } do
                check.is_true(open[name] == true)
            end
        end)

        test.case("titlurile incep cu un verb si nu au semne de intrebare", function()
            local verbs = {
                Place = true,
                Collect = true,
                Break = true,
                Build = true,
                Let = true,
                Put = true,
                Welcome = true,
                Make = true,
                Grow = true,
                Repair = true,
                Plant = true,
            }
            for _, list in { ObjectiveConfig.STEPS, ObjectiveConfig.GOALS } do
                for _, step in list do
                    local first = string.match(step.title, "^(%a+)")
                    check.is_true(verbs[first] == true)
                    check.equal(string.find(step.title, "?"), nil)
                end
            end
        end)

        test.case("textele incap pe cartonas", function()
            -- Cartonasul are 360 px utili. La 22 px titlul incape in ~30 de semne pe rand
            -- (doua randuri), la 15 px indiciul in ~48 (tot doua). Peste atat, textul se taie
            -- in joc si jucatorul citeste o propozitie fara final.
            for _, step in ObjectiveConfig.STEPS do
                check.is_true(#step.title <= 60)
                check.is_true(#step.hint <= 96)
            end
            for _, g in ObjectiveConfig.GOALS do
                local widest = string.gsub(g.title, "{n}", "999")
                check.is_true(#widest <= 60)
                check.is_true(#g.hint <= 96)
            end
        end)

        test.case("telurile lungi au trepte crescatoare si nu se termina brusc", function()
            for _, g in ObjectiveConfig.GOALS do
                check.is_true(#g.steps >= 2)
                for i = 2, #g.steps do
                    check.is_true(g.steps[i] > g.steps[i - 1])
                end
                -- prima treapta se ia cand nu ai nimic, ultima cade cand ai atins-o
                check.equal(ObjectiveConfig.nextStep(g, 0), g.steps[1])
                check.equal(ObjectiveConfig.nextStep(g, g.steps[#g.steps]), nil)
            end
        end)

        test.case("id-urile sunt unice si tintele pozitive", function()
            local seen: { [string]: boolean } = {}
            for _, step in ObjectiveConfig.STEPS do
                check.equal(seen[step.id], nil)
                seen[step.id] = true
                check.is_true(step.target > 0)
                check.is_true(#step.hint > 0)
            end
            for _, g in ObjectiveConfig.GOALS do
                check.is_true(#g.hint > 0)
                check.is_true(g.steps[1] > 0)
            end
        end)

        test.case("fiecare semn cerut exista in lista de semne", function()
            -- Un obiectiv care cere un semn pe care clientul nu stie sa-l aseze inseamna un
            -- jucator care citeste "du-te acolo" fara sa aiba unde. Exact asta s-a intamplat cu
            -- "inelul stralucitor", care nu exista pe ecran.
            local known: { [string]: boolean } = {}
            for _, m in ObjectiveConfig.MARKERS do
                known[m] = true
            end
            for _, list in { ObjectiveConfig.STEPS, ObjectiveConfig.GOALS } do
                for _, step in list do
                    check.is_true(known[step.marker] == true)
                end
            end
        end)

        test.case("fiecare deblocare numeste un panou care exista", function()
            local known: { [string]: boolean } = {}
            for _, name in ObjectiveConfig.PANELS do
                known[name] = true
            end
            for _, step in ObjectiveConfig.STEPS do
                if step.unlocks ~= nil then
                    check.is_true(known[step.unlocks] == true)
                end
            end
        end)

        test.case("stepAt intoarce nil dupa ultimul pas", function()
            check.not_nil(ObjectiveConfig.stepAt(1))
            check.equal(ObjectiveConfig.stepAt(ObjectiveConfig.count() + 1), nil)
        end)
    end)
end
