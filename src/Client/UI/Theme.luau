--!strict
-- Vocabularul vizual al interfetei. Totul se ia de aici, nimic nu se scrie de mana in controllere:
-- asa nu ajungem cu sase nuante de gri si patru marimi de text care nu inseamna nimic.
--
-- Trei decizii, fiecare cu motivul ei:
--  * FONT: Gotham e fontul implicit DEPRECIAT al platformei. Merriweather (incercarea
--    anterioara) e un serif de ziar: intr-un joc colorat vazut de sus citeste ca "document",
--    nu ca joc -- de-aia parea ieftin indiferent cat il reglam. Titlurile trec pe FREDOKA ONE,
--    rotunjit si greu, familia in care sunt scrise jocurile mobile de constructie (Clash of
--    Clans si tot ce a copiat dupa el). Textul curent ramane NUNITO, care se potriveste cu
--    terminatiile rotunjite si ramane lizibil la marimi mici.
--  * CONTURUL e jumatate din efect. In jocurile astea, orice text care sta peste lume are un
--    contur inchis, gros, plus o umbra scurta sub el. Fara contur, acelasi font arata spalacit;
--    cu contur, se citeste peste iarba, apa sau un acoperis rosu fara sa ai nevoie de placa.
--  * IERARHIA se face din GREUTATE, nu doar din marime: Medium pentru text, Bold pentru nume si
--    butoane, ExtraBold doar pentru titlul principal al unui ecran.
--  * CULOAREA e semnal, nu decor: verde = merge, rosu = nu ai destul, auriu = atentia ta acum.
--    Restul interfetei e lemn si pergament, ca sa apartina aceleiasi lumi ca si cladirile.
local TextService = game:GetService("TextService")

local Theme = {}

local function rgb(r: number, g: number, b: number): Color3
    return Color3.fromRGB(r, g, b)
end

Theme.COLOR = {
    ink = rgb(58, 42, 30), -- textul pe pergament
    inkSoft = rgb(104, 84, 66),
    parchment = rgb(238, 227, 202),
    parchmentDim = rgb(214, 199, 168),
    wood = rgb(112, 78, 48),
    woodDark = rgb(66, 44, 27),
    onDark = rgb(240, 233, 218), -- textul peste lume, fara panou in spate
    onDarkSoft = rgb(196, 186, 168),
    good = rgb(96, 156, 88),
    warn = rgb(214, 140, 56),
    bad = rgb(190, 74, 62),
    gold = rgb(232, 178, 60),
    -- [D52] Aceleasi semnale, pentru TEXT PE PERGAMENT. Verdele, portocaliul si rosul de mai sus sunt
    -- facute pentru pastile si lume; pe hartie deschisa abia se citesc, iar randul care spune "merita
    -- acum?" din meniul obiectului trebuie citit dintr-o privire.
    goodInk = rgb(58, 116, 50),
    warnInk = rgb(160, 90, 20),
    badInk = rgb(150, 42, 34),
    cool = rgb(140, 175, 226), -- nevoia de odihna, apa, lucruri reci
    ghostOk = rgb(120, 210, 130), -- fantoma de asezare, loc valid
    ghostBad = rgb(214, 106, 100),
    plate = rgb(0, 0, 0), -- placa de sub text peste lume
}

-- Placa semi-transparenta de sub text, cand textul sta peste lume si nu peste un panou.
Theme.PLATE_TRANSPARENCY = 0.3

Theme.TEXT = {
    title = 30,
    heading = 22,
    body = 18,
    small = 15,
    tiny = 13,
}

-- Ritmul de spatiere. Tot ce e distanta in interfata e un multiplu de 4.
Theme.SPACE = { xs = 4, sm = 8, md = 12, lg = 20, xl = 32 }

Theme.WEIGHT = {
    body = Enum.FontWeight.Medium,
    strong = Enum.FontWeight.SemiBold,
    -- Regular: Fredoka One are o singura taietura, deja foarte grea. Cerand Bold, clientul ar
    -- cauta o fata care nu exista si ar sintetiza sau ar cadea pe rezerva.
    display = Enum.FontWeight.Regular,
}

-- Cautarea se face prin nume, cu plasa dedesubt. `Enum.Font.CevaGresit` arunca pe loc, iar
-- fiindca modulul asta e cerut de toate controllerele, o singura litera gresita ar opri tot
-- bootstrap-ul clientului si jocul ar porni pe ecran gol.
local function fontOr(name: string, fallback: Enum.Font): Enum.Font
    local ok, value = pcall(function()
        return (Enum.Font :: any)[name]
    end)
    if ok and value ~= nil then
        return value
    end
    warn(`[Driftwood] fontul "{name}" nu exista pe acest client; folosesc rezerva`)
    return fallback
end

-- Joc desenat in pixeli: titlurile si cifrele cer un font de pixeli, nu unul rotunjit modern.
-- `Arcade` e singurul font de pixeli din platforma; daca lipseste, cadem pe cel vechi.
local DISPLAY = fontOr("Arcade", fontOr("FredokaOne", Enum.Font.SourceSansBold))
local BODY = fontOr("Nunito", Enum.Font.SourceSans)
-- Latime fixa, pentru jurnalul consolei de dezvoltare. Acolo alinierea pe coloane e FUNCTIONALA,
-- nu decor: un jurnal cu latimi variabile nu se mai poate citi pe verticala.
local MONO = fontOr("RobotoMono", Enum.Font.Code)

-- Fonturile noi exista doar prin tipul Font, nu prin Enum.Font: FontFace + FontWeight.
-- pcall pentru ca o versiune veche de client ar cadea altfel la bootstrap.
local function makeFont(family: Enum.Font, weight: Enum.FontWeight): Font?
    local ok, font = pcall(function()
        local f = Font.fromEnum(family)
        f.Weight = weight
        return f
    end)
    return if ok then font else nil
end

-- "strong" (cifre, etichete scurte, indemnuri) merge tot pe fontul de pixeli: sunt texte
-- scurte, peste lume, unde consistenta cu arta conteaza mai mult decat lizibilitatea unei
-- fraze lungi. "body" (frazele intregi, ex. descrierea de pe cartonas) ramane pe Nunito.
local function familyOf(kind: string): Enum.Font
    return if kind == "display" or kind == "strong"
        then DISPLAY
        elseif kind == "mono" then MONO
        else BODY
end

function Theme.applyFont(label: TextLabel | TextButton, kind: string)
    local family = familyOf(kind)
    local weight = if kind == "display"
        then Theme.WEIGHT.display
        elseif kind == "strong" then Theme.WEIGHT.strong
        else Theme.WEIGHT.body
    local font = makeFont(family, weight)
    local target = label :: any
    if font ~= nil then
        target.FontFace = font
    else
        target.Font = if kind == "mono" then MONO elseif kind == "body" then BODY else DISPLAY
    end
end

-- [D58] Latimea unui text pe un singur rand, cu familia pe care o pune applyFont. Pentru butoanele care cresc dupa
-- eticheta ("Upgrade (U) · 1.2K"): fontul de pixeli are litere late (0.56 em fiecare), iar o latime fixa taia textul.
function Theme.textWidth(text: string, size: number, kind: string): number
    local ok, bounds = pcall(function()
        return TextService:GetTextSize(text, size, familyOf(kind), Vector2.new(4096, size * 2))
    end)
    return if ok then (bounds :: Vector2).X else (utf8.len(text) or #text) * size * 0.6
end

-- Inaltimea unui text rupt pe randuri la latimea data, pentru cutiile care cresc dupa text: cu o inaltime fixa,
-- al doilea rand cade peste ce e dedesubt sau pe langa placa.
function Theme.textHeight(text: string, size: number, kind: string, width: number): number
    local ok, bounds = pcall(function()
        return TextService:GetTextSize(text, size, familyOf(kind), Vector2.new(width, 4096))
    end)
    if ok then
        return (bounds :: Vector2).Y
    end
    return math.ceil(Theme.textWidth(text, size, kind) / math.max(1, width)) * size * 1.1
end

-- Cea mai mare marime, cel mult `size`, la care textul incape pe un rand in `width`. Plasa de sub textele care se
-- schimba (sume, nume): pe un ecran ingust fereastra se strange, iar textul trebuie sa se stranga cu ea, nu sa iasa
-- din rama [vazut in Studio, 2026-09-15: o fraza de 687 de unitati intr-un corp de 420].
function Theme.fitSize(text: string, size: number, kind: string, width: number): number
    local s = size
    while s > Theme.TEXT.tiny and Theme.textWidth(text, s, kind) > width do
        s -= 1
    end
    return s
end

-- Contur inchis pentru textul care sta PESTE LUME (nu peste un panou deschis). Asta e jumatate
-- din aspectul jocurilor mobile de constructie: acelasi font, fara contur, arata spalacit peste
-- iarba sau peste apa si are nevoie de o placa neagra sub el ca sa se citeasca. Cu contur, nu.
-- PE PERGAMENT NU SE PUNE: text inchis conturat cu inchis se imbacseste si devine o pata.
function Theme.punch(label: TextLabel | TextButton, thickness: number?)
    local target = label :: any
    if label:FindFirstChild("Punch") ~= nil then
        return -- deja conturat; a doua trecere ar dubla grosimea
    end
    pcall(function()
        local stroke = Instance.new("UIStroke")
        stroke.Name = "Punch"
        stroke.Color = Color3.fromRGB(38, 26, 18)
        -- grosimea urmeaza marimea textului: un contur fix arata gros la 13 px si absent la 30
        stroke.Thickness = thickness or math.max(2, math.floor(target.TextSize / 7))
        stroke.LineJoinMode = Enum.LineJoinMode.Round
        stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual
        stroke.Parent = label
    end)
    -- conturul vechi de 1 px al Roblox ar dubla marginea si ar innegri terminatiile rotunjite
    target.TextStrokeTransparency = 1
end

-- Umbra nativa. Instanta e noua, deci o incercam si mergem mai departe daca nu exista.
function Theme.shadow(parent: GuiObject, blur: number, transparency: number)
    local ok = pcall(function()
        local s = Instance.new("UIShadow" :: any)
        s.BlurRadius = UDim.new(0, blur)
        s.Color = Color3.fromRGB(24, 16, 10)
        s.Offset = UDim2.fromOffset(0, math.max(2, blur // 3))
        s.Transparency = transparency
        s.ZIndex = -1
        s.Parent = parent
    end)
    if not ok then
        -- rezerva: un chenar inchis, discret, in locul umbrei
        local stroke = Instance.new("UIStroke")
        stroke.Thickness = 2
        stroke.Color = Color3.fromRGB(38, 26, 18)
        stroke.Transparency = 0.45
        stroke.Parent = parent
    end
end

return Theme
