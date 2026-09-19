--!strict
-- CINE TINE PE LOC un lucru care nu aduce nimic ACUM [D40, D52, D56]. Modul pur.
--
-- Un nivel, un om sau o platforma care nu apasa pe veriga slaba da exact zero, iar ecranul spune DE CE. Pana pe
-- 2026-09-19 trei locuri raspundeau fiecare in felul lui: meniul obiectului (corect: dupa castigul real si dupa veriga
-- slaba a LINIEI lui), panoul Upgrades (dupa un steag "sunt eu veriga slaba?") si cartonasul unei platforme (dupa
-- veriga care tine tot venitul). Cu amandoua liniile pornite, ultimele doua minteau: cu lemnul tinut de Taverna si
-- fierul de Forja, randul Tavernei scria "No gain yet — the Forge is slowest" desi un nivel acolo aducea +0.30/s (mai
-- mult decat unul la Forja), iar o plasa de lemn scria tot "the Forge", desi o tinea Taverna. Acum toate trei intreaba
-- aici, iar regula e una: INTAI castigul real (daca e peste zero, nu se scrie nimic), apoi veriga slaba a liniei.
local StationConfig =
    require(script and script.Parent.Parent.Config.StationConfig or "../Config/StationConfig")
local TycoonConfig =
    require(script and script.Parent.Parent.Config.TycoonConfig or "../Config/TycoonConfig")
local ChainMath = require(script and script.Parent.ChainMath or "./ChainMath")
local TycoonMath = require(script and script.Parent.TycoonMath or "./TycoonMath")

local HeldBack = {}

-- Ce stie clientul despre lant (StationService.Snapshot, vederea plata a Erei 1).
export type View = {
    bottleneck: string,
    woodBottleneck: string?,
    ironBottleneck: string?,
    rates: { [string]: any },
}

-- Campul din `rates` cu debitul fiecarei verigi. Plasele au cate unul pe linie (vezi `rateOf`).
local RATE_FIELD: { [string]: string } = {
    collect = "collect",
    port = "port",
    saw = "sawing",
    haul = "haul",
    scrapCollect = "scrapCollect",
    scrapPort = "scrapPort",
    forge = "forging",
    ironHaul = "ironHaul",
    dock = "sales",
}

-- [D56] Debitul unei verigi, pe linia intrebata: plasele de lemn si plasa de scrap sunt debite diferite.
function HeldBack.rateOf(view: View, link: string, line: string?): number
    local field = RATE_FIELD[link]
    if link == "nets" then
        field = if line == "iron"
            then "scrapCatch"
            elseif line == "wood" then "woodCatch"
            else "catch"
    end
    local value = if field ~= nil then view.rates[field] else nil
    return if typeof(value) == "number" then value else 0
end

-- [D56] O veriga intra in comparatie doar pe linia intrebata (plasele si taverna sunt ale amandurora); ale fierului
-- deloc cat linia lui e inchisa -- altfel debitul lor (0) ar iesi "cel mai lent" si ecranul ar trimite la o veriga care
-- nu tine nimic [D40].
local function inLine(view: View, link: string, line: string?): boolean
    local of = StationConfig.LINE_OF[link]
    if of == "iron" and (view.ironBottleneck or "") == "" then
        return false
    end
    return line == nil or of == nil or of == line
end

-- Veriga slaba a unei linii; pentru ce n-are linie (taverna, traista, clopotul), cea care tine venitul.
function HeldBack.lineBottleneck(view: View, line: string?): string
    if line == "iron" then
        return view.ironBottleneck or ""
    elseif line == "wood" then
        return view.woodBottleneck or view.bottleneck
    end
    return view.bottleneck
end

-- Veriga care tine pe loc veriga `mine` (nil = un lucru fara veriga a lui, de pilda traista), si daca e doar la
-- egalitate cu ea. SE CHEAMA DOAR CAND CASTIGUL E ZERO: atunci exista sigur una la fel de lenta sau mai lenta. Cu doua
-- marfuri debitele nu se compara intre linii: veriga slaba o spune serverul; comparatia de debite ramane pentru
-- egalitati (eu sunt marcata slaba, dar alta merge exact la fel). Intoarce nil cand linia fierului e inca inchisa: nu e
-- o veriga de reparat, doar nu vine inca nimic.
function HeldBack.by(view: View, mine: string?, line: string?): (string?, boolean)
    local bottleneck = HeldBack.lineBottleneck(view, line)
    if line == "iron" and bottleneck == "" then
        return nil, false
    end
    if bottleneck ~= mine and bottleneck ~= "" then
        return bottleneck, false
    end
    local mineRate = if mine ~= nil then HeldBack.rateOf(view, mine, line) else math.huge
    local best, bestRate = "dock", math.huge
    -- [D65] Vederea de aici e cea plata, a Erei 1: se compara doar verigile ei. Piata Erei 2 n-are linie (ca taverna),
    -- deci fara marginea asta ar fi iesit "cea mai lenta" cu debit 0. Vederea pe linii vine cu docs/PLAN-ERA2.md, pasul 3.
    for _, link in StationConfig.ERA_LINKS[1] do
        if link ~= mine and inLine(view, link, line) then
            local rate = HeldBack.rateOf(view, link, line)
            if rate < bestRate then
                best, bestRate = link, rate
            end
        end
    end
    return best, bestRate >= mineRate - 1e-9
end

-- Plasele carei linii, cand veriga numita e "nets": a liniei intrebate; fara linie (de la taverna), a liniei in care
-- plasele chiar tin.
function HeldBack.netsLine(view: View, line: string?): string
    if line ~= nil then
        return line
    end
    return if view.ironBottleneck == "nets" and view.woodBottleneck ~= "nets"
        then "iron"
        else "wood"
end

-- Veriga si linia unei PLATFORME, din efectele ei: o plasa tine de linia a ce prinde, un om de linia meseriei lui
-- (Innkeeper-ul: veriga tavernei, fara linie). Restul (traista, Forge, clopotul) n-au nici veriga, nici linie.
function HeldBack.ofPad(pad: TycoonConfig.Pad): (string?, string?)
    for _, e in pad.effects do
        if e.kind == "net" then
            -- aceeasi intrebare ca pe server (StationService.rowFor): linia pe care curge ce prinde plasa
            return "nets", ChainMath.lineOfNetKind(TycoonMath.netKind(pad))
        elseif e.kind == "hire" and e.field ~= nil then
            local link = StationConfig.LINK_OF[e.field]
            return link, if link ~= nil then StationConfig.LINE_OF[link] else nil
        end
    end
    return nil, nil
end

return HeldBack
