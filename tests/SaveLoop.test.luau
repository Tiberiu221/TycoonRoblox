--!strict
-- [D70, verificatorul j15] Salvarea fortata (SaveLoop), pe un profil fals: chitantele Robux si barajul depind de ea.
local frktest = require("@frktest/frktest")
local test = frktest.test
local check = frktest.assert.check

local SaveLoop = require("../src/Shared/Modules/SaveLoop")

-- Un profil fals. `plan` spune ce face fiecare Save(), pe rand: "sync" (scrie pe loc si anunta), "async:N" (scrie si
-- anunta dupa N asteptari), "fail" (nu scrie si nu anunta, ca o eroare de DataStore), "close" (sesiunea se inchide, cu
-- salvarea de inchidere care scrie datele).
local function fakeProfile(data: { [string]: any }, plan: { string })
    local listeners: { [number]: ((any) -> ())? } = {}
    local pending: { remaining: number }? = nil
    local profile: any = {
        LastSavedData = nil,
        active = true,
        saves = 0,
        waits = 0,
    }
    local function finish()
        profile.LastSavedData = table.clone(data)
        for _, fn in listeners do
            if fn ~= nil then
                fn(profile.LastSavedData)
            end
        end
    end
    function profile:IsActive(): boolean
        return profile.active
    end
    function profile:Save()
        profile.saves += 1
        local step = plan[profile.saves] or "sync"
        if step == "sync" then
            finish()
        elseif step == "close" then
            finish()
            profile.active = false
        elseif string.sub(step, 1, 6) == "async:" then
            pending = { remaining = tonumber(string.sub(step, 7)) :: number }
        end
        -- "fail": nimic
    end
    profile.OnAfterSave = {
        Connect = function(_self: any, fn: (any) -> ())
            table.insert(listeners, fn)
            local index = #listeners
            return {
                Disconnect = function(_c: any)
                    listeners[index] = nil
                end,
            }
        end,
    }
    local function wait(_s: number)
        profile.waits += 1
        local p = pending
        if p ~= nil then
            p.remaining -= 1
            if p.remaining <= 0 then
                pending = nil
                finish()
            end
        end
    end
    return profile, wait
end

local function hasReceipt(last: any): boolean
    return typeof(last) == "table" and last.receipt == true
end

return function()
    test.suite("SaveLoop - salvarea fortata [D70, verificatorul j15]", function()
        test.case("deja salvat: true, fara nicio salvare", function()
            local profile, wait = fakeProfile({ receipt = true }, {})
            profile.LastSavedData = { receipt = true }
            check.is_true(SaveLoop.run(profile, hasReceipt, wait, 10))
            check.equal(profile.saves, 0)
        end)

        test.case("salvarea scrie pe loc: true, fara asteptare", function()
            local profile, wait = fakeProfile({ receipt = true }, { "sync" })
            check.is_true(SaveLoop.run(profile, hasReceipt, wait, 10))
            check.equal(profile.saves, 1)
            check.equal(profile.waits, 0)
        end)

        test.case("salvarea ajunge dupa cateva asteptari: true", function()
            local profile, wait = fakeProfile({ receipt = true }, { "async:3" })
            check.is_true(SaveLoop.run(profile, hasReceipt, wait, 10))
            check.equal(profile.saves, 1)
            check.equal(profile.waits, 3)
        end)

        test.case(
            "o salvare care pica nu tine bucla pana la autosave: reincearca dupa termen",
            function()
                local profile, wait = fakeProfile({ receipt = true }, { "fail", "sync" })
                check.is_true(SaveLoop.run(profile, hasReceipt, wait, 1))
                check.equal(profile.saves, 2)
                -- cel mult `retry` secunde in pasi de SaveLoop.STEP, apoi a doua salvare, fara alta pauza
                check.is_true(profile.waits <= math.ceil(1 / SaveLoop.STEP) + 1)
            end
        )

        test.case(
            "sesiunea se inchide: false, dar adevarat daca salvarea de inchidere a dus datele",
            function()
                local closing, wait1 = fakeProfile({ receipt = true }, { "close" })
                check.is_true(SaveLoop.run(closing, hasReceipt, wait1, 10))
                local gone, wait2 = fakeProfile({ receipt = false }, { "close" })
                check.is_false(SaveLoop.run(gone, hasReceipt, wait2, 10))
            end
        )

        test.case("ajunge, dar fara ce cautam: o pauza, apoi din nou", function()
            local data = { receipt = false }
            local profile, wait = fakeProfile(data, { "sync", "sync" })
            local calls = 0
            local function isSaved(last: any): boolean
                calls += 1
                if calls == 2 then
                    data.receipt = true -- chitanta intra in profil abia acum
                end
                return hasReceipt(last)
            end
            check.is_true(SaveLoop.run(profile, isSaved, wait, 5))
            check.equal(profile.saves, 2)
            check.equal(profile.waits, 1) -- pauza de `retry` dintre ele
        end)
    end)
end
