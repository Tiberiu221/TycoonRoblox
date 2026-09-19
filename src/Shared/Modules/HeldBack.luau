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

-- Ce stie clientul despre lant (StationService.Snapshot): VEDEREA PE LINII [D65], aceeasi pentru orice era. Pana la
-- D65 era vederea plata a Erei 1 (`woodBottleneck`, `ironBottleneck`, `rates.sawing`...), iar regula de mai jos avea
-- numele liniilor ei batute in cuie.
export type LineView = { catch: number, bottleneck: string }
export type View = {
    bottleneck: string, -- veriga care tine TOT venitul
    lines: { [string]: LineView }, -- pe linie: cat prind plasele ei si veriga ei slaba ("" = linia e inca inchisa)
    linkRates: { [string]: number }, -- debitul fiecarei verigi, dupa nume (plasele nu: au cate un debit pe linie)
    eraBottleneck: { string }?, -- veriga care tine venitul fiecarui cartier, dupa numarul erei
}

-- Vederea, din lantul motorului. Serverul trimite aceleasi campuri (StationService.Snapshot); testele o iau de aici.
function HeldBack.viewOf(flow: ChainMath.Flow): View
    local lines: { [string]: LineView } = {}
    local linkRates: { [string]: number } = {}
    for _, line in StationConfig.LINE_ORDER do
        local lf = flow.lines[line]
        lines[line] = { catch = lf.catch, bottleneck = lf.bottleneck }
        for k, step in StationConfig.LINES[line].steps do
            linkRates[step.link] = lf.values[k]
        end
    end
    for _, seller in StationConfig.SELLER_ORDER do
        linkRates[seller] = flow.capacity[seller]
    end
    return { bottleneck = flow.bottleneck, lines = lines, linkRates = linkRates }
end

-- Liniile unui vanzator, in ordinea in care vinde (intai marfa mai scumpa); nil = `key` nu e un vanzator.
local function sellerLines(key: string?): { string }?
    local seller = if key ~= nil then StationConfig.SELLERS[key] else nil
    return if seller ~= nil then seller.priority else nil
end

local function lineIsOpen(view: View, line: string): boolean
    local lv = view.lines[line]
    return lv ~= nil and lv.bottleneck ~= ""
end

-- [D56] Debitul unei verigi, pe linia intrebata: plasele fiecarei linii sunt debite diferite. Fara linie, plasele
-- inseamna tot ce se prinde.
function HeldBack.rateOf(view: View, link: string, line: string?): number
    if link ~= "nets" then
        return view.linkRates[link] or 0
    end
    if line ~= nil then
        local lv = view.lines[line]
        return if lv ~= nil then lv.catch else 0
    end
    local total = 0
    for _, lv in view.lines do
        total += lv.catch
    end
    return total
end

-- Veriga slaba a unei linii ("" cat e inchisa). Fara linie:
--   * un VANZATOR (taverna, Piata): veriga slaba a primei linii deschise din randul lui. In Era 1 e exact veriga care
--     tine venitul (o linie tinuta de o veriga a ei castiga cat bucata ei, iar randul vanzatorului e de la scump la
--     ieftin); din Era 2, fiecare vanzator ramane astfel in cartierul lui: taverna nu trimite la turnatorie;
--   * orice altceva (traista, clopotul): veriga care tine tot venitul.
function HeldBack.lineBottleneck(view: View, line: string?, mine: string?): string
    if line ~= nil then
        local lv = view.lines[line]
        return if lv ~= nil then lv.bottleneck else ""
    end
    local mineLines = sellerLines(mine)
    if mineLines ~= nil then
        for _, l in mineLines do
            if lineIsOpen(view, l) then
                return view.lines[l].bottleneck
            end
        end
    end
    return view.bottleneck
end

-- Veriga care tine pe loc veriga `mine` (nil = un lucru fara veriga a lui, de pilda traista), si daca e doar la
-- egalitate cu ea. SE CHEAMA DOAR CAND CASTIGUL E ZERO: atunci exista sigur una la fel de lenta sau mai lenta. Cu mai
-- multe marfuri debitele nu se compara intre linii: veriga slaba o spune serverul; comparatia de debite ramane pentru
-- egalitati (eu sunt marcata slaba, dar alta merge exact la fel). Intoarce nil cand linia intrebata e inca inchisa:
-- nu e o veriga de reparat, doar nu vine inca nimic.
function HeldBack.by(view: View, mine: string?, line: string?): (string?, boolean)
    local bottleneck = HeldBack.lineBottleneck(view, line, mine)
    if line ~= nil and bottleneck == "" then
        return nil, false
    end
    if bottleneck ~= mine and bottleneck ~= "" then
        return bottleneck, false
    end
    -- Cu cine ma compar: plasele, pasii si vanzatorul liniei mele; de la un vanzator, liniile lui deschise. O linie
    -- inchisa nu intra: debitul ei (0) ar iesi "cel mai lent" si ecranul ar trimite la o veriga care nu tine nimic.
    local among: { string } = if line ~= nil
        then { line }
        else sellerLines(mine) or StationConfig.LINE_ORDER
    local mineRate = if mine ~= nil then HeldBack.rateOf(view, mine, line) else math.huge
    local best: string? = nil
    local bestRate = math.huge
    local function consider(link: string, rate: number)
        if link ~= mine and rate < bestRate then
            best, bestRate = link, rate
        end
    end
    for _, l in among do
        if lineIsOpen(view, l) then
            consider("nets", view.lines[l].catch)
            for _, step in StationConfig.LINES[l].steps do
                consider(step.link, view.linkRates[step.link] or 0)
            end
        end
    end
    for _, l in among do
        local seller = StationConfig.LINES[l].seller
        consider(seller, view.linkRates[seller] or 0)
    end
    return best or StationConfig.LINES[among[1]].seller, bestRate >= mineRate - 1e-9
end

-- Plasele carei linii, cand veriga numita e "nets": a liniei intrebate; fara linie (de la un vanzator), a liniei lui in
-- care plasele chiar tin, in ordinea liniilor.
function HeldBack.netsLine(view: View, line: string?, mine: string?): string
    if line ~= nil then
        return line
    end
    local mineLines = sellerLines(mine)
    local first: string? = nil
    for _, l in StationConfig.LINE_ORDER do
        if mineLines == nil or table.find(mineLines, l) ~= nil then
            first = first or l
            local lv = view.lines[l]
            if lv ~= nil and lv.bottleneck == "nets" then
                return l
            end
        end
    end
    return first or StationConfig.LINE_ORDER[1]
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
