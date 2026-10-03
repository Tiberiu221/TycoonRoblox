--!strict
-- [D70, pasul k7] Ecranul „Build the Dam”: trei coloane din chitanta serverului (DamWords), fara randuri cu 0, in cutiile
-- ecranului (cel mult 5 randuri pe coloana), cu literele pe care le are Nunito; dupa „save” nu se mai incearca.
local frktest = require("@frktest/frktest")
local test = frktest.test
local check = frktest.assert.check
local fs = require("@lune/fs")

local DamWords = require("../src/Shared/Modules/DamWords")
local Strings = require("../src/Shared/Config/Strings")

local widths = require("./fonts/NunitoWidths") :: { [string]: number }

local function receipt(over: { [string]: any }?): DamWords.Receipt
    local r: any = {
        lastCart = 4.2e12,
        pieces = 1830,
        questPearls = 45,
        coinsAfter = 35e12,
        start = 35e12,
        kept = 0,
        gift = 0,
        topUp = 0,
        incomeBefore = 1.21e9,
        incomeAfter = 19.6e9,
        veterans = { {}, {}, {}, {}, {} },
        retired = 49,
    }
    for k, v in over or {} do
        r[k] = v
    end
    return r
end

local function rowsOf(columns: { DamWords.Column }): { string }
    local out: { string } = {}
    for _, c in columns do
        table.insert(out, c.title)
        for _, row in c.rows do
            table.insert(out, row)
        end
    end
    return out
end

return function()
    test.suite("DamWords - ecranul „Build the Dam” [D70, pasul k7]", function()
        test.case("trei coloane, fiecare cu titlul ei si cel mult 5 randuri", function()
            local columns = DamWords.columns(receipt({ gift = 3e12, kept = 2e12 }))
            check.equal(#columns, 3)
            check.equal(columns[1].title, Strings.DAM_STAYS)
            check.equal(columns[2].title, Strings.DAM_BECOMES)
            check.equal(columns[3].title, Strings.DAM_GAIN)
            for _, c in columns do
                check.is_true(#c.rows >= 1 and #c.rows <= 5)
            end
            check.equal(columns[1].rows[1], "You start with 35T + 2T coins you bought")
            check.not_nil(table.find(columns[2].rows, "Given to the Dam: 3T"))
            check.not_nil(table.find(columns[3].rows, "Income 1.21B/s, then 19.6B/s"))
            -- [verificatorul k6-k8] regula AWAY 0 nu e un castig: nu sta in „You gain”, ci separat, ca fapt
            local _, away = DamWords.columns(receipt())
            check.equal(away, Strings.damAwayZero(6))
            check.not_nil(string.find(away, "earns nothing", 1, true))
            for _, c in columns do
                check.equal(table.find(c.rows, away), nil)
            end
        end)

        test.case("un rand fara ce spune lipseste: fara 0 care pare o pierdere", function()
            local plain = rowsOf(DamWords.columns(receipt({ pieces = 0, questPearls = 0 })))
            for _, row in plain do
                check.equal(string.find(row, "Given to the Dam", 1, true), nil)
                check.equal(string.find(row, "The village adds", 1, true), nil)
                check.equal(string.find(row, "Last cart", 1, true), nil)
                check.equal(string.find(row, "Old quests", 1, true), nil)
            end
            check.equal(DamWords.columns(receipt())[1].rows[1], "You start with 35T")
            local poor = rowsOf(DamWords.columns(receipt({ topUp = 30e12 })))
            check.not_nil(table.find(poor, "The village adds: 30T"))
        end)

        test.case(
            "toate literele ecranului sunt in Nunito (si „Saving…”, sageata)",
            function()
                local all = rowsOf(DamWords.columns(receipt({ gift = 1, topUp = 1, kept = 1 })))
                table.insert(all, Strings.damAwayZero(6))
                for _, text in
                    {
                        Strings.DAM_HOLD_HINT,
                        Strings.DAM_COUNTING,
                        Strings.DAM_SAVING,
                        Strings.DAM_BUILT,
                        Strings.damRejected("save"),
                        Strings.damRejected("changed"),
                    }
                do
                    table.insert(all, text)
                end
                for _, text in all do
                    for _, code in utf8.codes(text) do
                        local ch = utf8.char(code)
                        if widths[ch] == nil then
                            print(`  ! litera lipsa „{ch}” in: {text}`)
                        end
                        check.not_nil(widths[ch])
                    end
                end
                -- titlurile coloanelor, in fontul de pixeli la 18, incap in coloana de 192 px
                for _, title in { Strings.DAM_STAYS, Strings.DAM_BECOMES, Strings.DAM_GAIN } do
                    check.is_true((utf8.len(title) :: number) * 18 * 0.5586 <= 192)
                end
            end
        )

        test.case("dupa „save” sau „built” nu se mai incearca; la asteptari, da", function()
            check.is_false(DamWords.canRetry("save"))
            check.is_false(DamWords.canRetry("built"))
            check.is_false(DamWords.canRetry("soon"))
            check.is_true(DamWords.canRetry("busy"))
            check.is_true(DamWords.canRetry("changed"))
            check.is_true(DamWords.canRetry("settling"))
        end)

        test.case("masa deschide ecranul, iar ecranul primeste chitanta si refuzurile", function()
            local boot = fs.readFile("src/Client/Bootstrap.client.luau")
            for _, needle in
                {
                    "DamScreen.Open()",
                    "OnPreview = DamScreen.OnPreview",
                    "OnBuilt = DamScreen.OnBuilt",
                    "OnRejected = DamScreen.OnRejected",
                }
            do
                check.not_nil(string.find(boot, needle, 1, true))
            end
            local screen = fs.readFile("src/Client/Controllers/DamScreen.luau")
            check.not_nil(string.find(screen, "seconds = HOLD_SECONDS", 1, true))
            check.not_nil(string.find(screen, "local HOLD_SECONDS = 1.5", 1, true))
        end)
    end)
end
