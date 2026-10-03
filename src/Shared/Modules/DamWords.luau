--!strict
-- [D70, pasul k7] CE SCRIE ECRANUL „Build the Dam”, pur: trei coloane din chitanta serverului (DamMath.preview), cu cifrele
-- scrise ca pe HUD (TycoonMath.formatNumber). PLAN-HARTA §3: ce ramane cu tine, ce devine barajul, ce castigi. Un rand
-- care n-are ce spune lipseste („Given to the Dam” doar cu bani peste suma, „The village adds” doar cu mai putin), ca
-- ecranul sa nu arate un 0 care pare o pierdere [D40].
local Strings = require(script and script.Parent.Parent.Config.Strings or "../Config/Strings")
local TycoonMath = require(script and script.Parent.TycoonMath or "./TycoonMath")
local DamMath = require(script and script.Parent.DamMath or "./DamMath")

local DamWords = {}

-- Campurile chitantei pe care le citeste ecranul (DamController.Receipt le are pe toate).
export type Receipt = {
    lastCart: number,
    pieces: number,
    questPearls: number,
    coinsAfter: number,
    start: number,
    kept: number,
    gift: number,
    topUp: number,
    incomeBefore: number,
    incomeAfter: number,
    veterans: { any },
    retired: number,
}
export type Column = { title: string, rows: { string } }

local function n(x: number): string
    return TycoonMath.formatNumber(x)
end

function DamWords.columns(r: Receipt): { Column }
    local stays: { string } = {
        Strings.damCoins(n(r.start), if r.kept > 0 then n(r.kept) else nil),
        Strings.DAM_STAYS_THINGS,
        Strings.DAM_STAYS_BELLS,
        Strings.DAM_STAYS_PEOPLE,
    }
    local becomes: { string } = { Strings.DAM_BECOMES_BUILDINGS }
    if r.pieces > 0 then
        table.insert(becomes, Strings.damLastCart(n(r.lastCart), r.pieces))
    end
    if r.questPearls > 0 then
        table.insert(becomes, Strings.damQuests(r.questPearls))
    end
    if r.gift > 0 then
        table.insert(becomes, Strings.damGiven(n(r.gift)))
    end
    local gain: { string } = {
        Strings.damIncome(
            TycoonMath.formatRate(r.incomeBefore),
            TycoonMath.formatRate(r.incomeAfter)
        ),
    }
    if r.topUp > 0 then
        table.insert(gain, Strings.damTopUp(n(r.topUp)))
    end
    table.insert(gain, Strings.damVeterans(#r.veterans, r.retired))
    table.insert(gain, Strings.DAM_GAIN_FREE)
    -- [verificatorul k6] AWAY 0 pana la oamenii noi, spus dinainte [D43]
    table.insert(gain, Strings.damAwayZero(DamMath.newHires()))
    return {
        { title = Strings.DAM_STAYS, rows = stays },
        { title = Strings.DAM_BECOMES, rows = becomes },
        { title = Strings.DAM_GAIN, rows = gain },
    }
end

-- Dupa un refuz: se mai poate tine butonul? Nu dupa ce barajul e ridicat („built”, „save”) sau cand nu se poate deloc
-- („soon”, „bell”); „save” nu ofera „Try again” [verificatorul j15]. Celelalte sunt asteptari sau o chitanta noua.
local FINAL: { [string]: boolean } = { built = true, save = true, soon = true, bell = true }
function DamWords.canRetry(reason: string): boolean
    return not FINAL[reason]
end

return DamWords
