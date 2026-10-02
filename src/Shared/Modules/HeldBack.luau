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
-- [D70] `heldBy`: linia careia ii apartine veriga slaba, cand e alta piesa din aceeasi unire (nil = a liniei insesi)
export type LineView = { catch: number, bottleneck: string, heldBy: string? }
export type View = {
    bottleneck: string, -- veriga care tine TOT venitul
    lines: { [string]: LineView }, -- pe linie: cat prind plasele ei si veriga ei slaba ("" = linia e inca inchisa)
    linkRates: { [string]: number }, -- debitul fiecarei verigi, dupa nume (plasele nu: au cate un debit pe linie)
    eraBottleneck: { string }?, -- veriga care tine venitul fiecarui cartier, dupa numarul erei
}

-- Vederea, din lantul motorului. Serverul trimite aceleasi campuri (StationService.Snapshot); testele o iau de aici.
-- [D70] `model`: lantul socotit (implicit al jocului; ChainMath.FULL pentru baraj, in teste).
function HeldBack.viewOf(flow: ChainMath.Flow, model: ChainMath.Model?): View
    local m = model or ChainMath.GAME
    local lines: { [string]: LineView } = {}
    local linkRates: { [string]: number } = {}
    for _, line in m.lineOrder do
        local lf = flow.lines[line]
        lines[line] = { catch = lf.catch, bottleneck = lf.bottleneck, heldBy = lf.heldBy }
        for k, step in m.lines[line].steps do
            linkRates[step.link] = lf.values[k]
        end
    end
    for _, seller in m.sellerOrder do
        linkRates[seller] = flow.capacity[seller]
    end
    return { bottleneck = flow.bottleneck, lines = lines, linkRates = linkRates }
end

-- [D70] Liniile care se tin una pe alta printr-o UNIRE: unirea si piesele ei, in ordinea liniilor. O linie fara unire e
-- singura in grupul ei (regula de pana acum). O bucata in plus pe o piesa intra in unire doar cu una din cealalta, deci
-- veriga care o tine poate sta pe alta linie a grupului.
function HeldBack.group(line: string): { string }
    local spec = StationConfig.LINES[line]
    local union = if spec.inputs ~= nil then line else spec.into
    if union == nil then
        return { line }
    end
    local out: { string } = {}
    for _, l in StationConfig.LINE_ORDER_ALL do
        if l == union or StationConfig.LINES[l].into == union then
            table.insert(out, l)
        end
    end
    return out
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

-- [D70] `held` e o PIESA din unirea liniei `line` (nu unirea insasi, nici alta linie): doar atunci ecranul numeste linia
-- ei („the Cable line is slower”). Cand veriga e a unirii (Relay Station) sau a vanzatorului, numele verigii spune mai mult.
local function isPieceOf(held: string, line: string): boolean
    if StationConfig.LINES[held] == nil or StationConfig.LINES[held].into == nil then
        return false
    end
    return table.find(HeldBack.group(line), held) ~= nil
end

-- [D70] Prima piesa inchisa a unei uniri (plasa ei lipseste), sau nil pentru o linie care nu e unire.
local function missingPiece(view: View, line: string): string?
    local inputs = StationConfig.LINES[line].inputs
    if inputs == nil then
        return nil
    end
    for _, part in inputs do
        if not lineIsOpen(view, part) then
            return part
        end
    end
    return nil
end

-- Prima linie deschisa din randul unui vanzator (cea pe care o intreaba lineBottleneck), sau nil.
local function firstOpenOf(view: View, seller: string?): string?
    local lines = sellerLines(seller)
    if lines ~= nil then
        for _, l in lines do
            if lineIsOpen(view, l) then
                return l
            end
        end
    end
    return nil
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
-- [D70] Al treilea raspuns: linia careia ii apartine veriga, cand e alta piesa din unirea liniei intrebate („the Cable
-- line is slower”), sau nil. Cand acea piesa e inca inchisa (plasa ei lipseste), cheia e nil, iar linia spune ce
-- lipseste („cast a Cable Net first”).
function HeldBack.by(view: View, mine: string?, line: string?): (string?, boolean, string?)
    local bottleneck = HeldBack.lineBottleneck(view, line, mine)
    if line ~= nil and bottleneck == "" then
        -- [D70] o unire inchisa: ii lipseste o piesa (plasa ei) — spune care
        return nil, false, missingPiece(view, line)
    end
    -- linia a carei veriga se cere: cea intrebata, sau, de la un vanzator, prima lui linie deschisa (ca lineBottleneck)
    local asked = line or firstOpenOf(view, mine)
    local holder: string? = nil
    if asked ~= nil then
        local lv = view.lines[asked]
        local held = if lv ~= nil then lv.heldBy else nil
        if held ~= nil and held ~= asked and isPieceOf(held, asked) then
            if not lineIsOpen(view, held) then
                return nil, false, held
            end
            holder = held
        end
    end
    if bottleneck ~= mine and bottleneck ~= "" then
        return bottleneck, false, holder
    end
    -- Cu cine ma compar: plasele, pasii si vanzatorul liniei mele (si ale grupului ei, la o unire); de la un vanzator,
    -- liniile lui deschise. O linie inchisa nu intra: debitul ei (0) ar iesi "cel mai lent" si ecranul ar trimite la o
    -- veriga care nu tine nimic.
    local among: { string } = if line ~= nil
        then HeldBack.group(line)
        else sellerLines(mine) or StationConfig.LINE_ORDER
    local mineRate = if mine ~= nil then HeldBack.rateOf(view, mine, line) else math.huge
    local best: string? = nil
    local bestLine: string? = nil
    local bestRate = math.huge
    local function consider(link: string, rate: number, of: string?)
        -- plasele fiecarei linii sunt alt debit: „nets” de pe alta piesa nu sunt plasele mele
        local isMine = link == mine and (link ~= "nets" or of == line)
        if not isMine and rate < bestRate then
            best, bestLine, bestRate = link, of, rate
        end
    end
    for _, l in among do
        if lineIsOpen(view, l) then
            if StationConfig.LINES[l].netKind ~= nil then
                consider("nets", view.lines[l].catch, l)
            end
            for _, step in StationConfig.LINES[l].steps do
                consider(step.link, view.linkRates[step.link] or 0, l)
            end
        end
    end
    local fallback: string? = nil
    for _, l in among do
        local seller = StationConfig.LINES[l].seller -- o piesa n-are vanzator: se vinde prin unire
        if seller ~= nil then
            fallback = fallback or seller
            consider(seller, view.linkRates[seller] or 0, nil)
        end
    end
    local other = if line ~= nil
            and bestLine ~= nil
            and bestLine ~= line
            and isPieceOf(bestLine, line)
        then bestLine
        else nil
    return best or fallback or "nets", bestRate >= mineRate - 1e-9, other
end

-- Plasele carei linii, cand veriga numita e "nets": a liniei intrebate; fara linie (de la un vanzator), a liniei lui in
-- care plasele chiar tin, in ORDINEA VANZATORULUI (ca lineBottleneck). [D70] O unire n-are plase: ale piesei care o tine.
function HeldBack.netsLine(view: View, line: string?, mine: string?): string
    if line ~= nil then
        return line
    end
    local function ownerOfNets(l: string): string?
        local lv = view.lines[l]
        if lv == nil or lv.bottleneck ~= "nets" then
            return nil
        end
        local held = lv.heldBy
        if
            held ~= nil
            and held ~= ""
            and StationConfig.LINES[held] ~= nil
            and StationConfig.LINES[held].netKind ~= nil
        then
            return held
        end
        return if StationConfig.LINES[l].netKind ~= nil then l else nil
    end
    local mineLines = sellerLines(mine)
    for _, l in mineLines or StationConfig.LINE_ORDER do
        local owner = ownerOfNets(l)
        if owner ~= nil then
            return owner
        end
    end
    -- nicio linie cu plasele la rand: prima linie cu plase a vanzatorului, in ordinea liniilor
    for _, l in StationConfig.LINE_ORDER_ALL do
        if
            (mineLines == nil or table.find(mineLines, l) ~= nil)
            and StationConfig.LINES[l].netKind ~= nil
        then
            return l
        end
    end
    return StationConfig.LINE_ORDER[1]
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
