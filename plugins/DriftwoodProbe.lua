--!nocheck
-- Sonda Driftwood: raporteaza din INTERIORUL Studio ce nu se vede din afara.
--
-- DE CE EXISTA: nu pot deschide Studio si nu pot vedea ecranul. Un screenshot costa mult si
-- oricum nu raspunde la intrebarile care ma incurca cel mai des: s-a rezolvat fontul cerut sau
-- a cazut pe rezerva? a crapat vreun controller la bootstrap? ce dimensiuni are chiar elementul
-- la rezolutia reala, nu la cea de referinta? Toate astea sunt TEXT, deci ieftine.
--
-- Instalare:  bash scripts/install_plugin.sh
-- Folosire:   porneste serverul (python3 scripts/probe_server.py), intra in Play, apasa "Probe".
--
-- Fisierul asta NU face parte din joc: nu e sub src/, nu intra in rojo, nu se livreaza.
local HttpService = game:GetService("HttpService")
local LogService = game:GetService("LogService")
local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")

local ENDPOINT = "http://127.0.0.1:8787/report"

-- Elementele despre care vreau adevarul. Un dump al intregului arbore ar fi enorm si scump;
-- astea sunt cele pe care le-am construit sau modificat si pe care nu le pot vedea.
-- F0 (tycoon): HUD-ul nou, debarcaderul si primele platforme, dupa numele din controllere.
local WATCH = {
    "Coins",
    "Toast",
    "ActionButton",
    "MenuBar",
    "Dock",
    "first_net",
    "second_net",
    "bigger_sack",
}

local toolbar = plugin:CreateToolbar("Driftwood")
local button = toolbar:CreateButton("Probe", "Trimite un raport de interfata la serverul local", "")
button.ClickableWhenViewportHidden = true

local function describe(inst)
    local out = {
        name = inst.Name,
        class = inst.ClassName,
        visible = (inst :: any).Visible,
    }
    local ok = pcall(function()
        local g = inst :: GuiObject
        out.absPos = { math.round(g.AbsolutePosition.X), math.round(g.AbsolutePosition.Y) }
        out.absSize = { math.round(g.AbsoluteSize.X), math.round(g.AbsoluteSize.Y) }
        out.zindex = g.ZIndex
    end)
    out.measured = ok
    if inst:IsA("TextLabel") or inst:IsA("TextButton") then
        local t = inst :: TextLabel
        out.text = string.sub(t.Text, 1, 80)
        out.textSize = t.TextSize
        -- ASTA e intrebarea centrala: fontul cerut s-a incarcat sau a cazut pe rezerva?
        pcall(function()
            out.fontFamily = t.FontFace.Family
            out.fontWeight = t.FontFace.Weight.Name
        end)
        out.legacyFont = t.Font.Name
        local stroke = t:FindFirstChild("Punch")
        out.outlined = stroke ~= nil and (stroke :: UIStroke).Thickness or 0
        -- text taiat: se vede in joc ca "..." si e cel mai des reclamat defect de interfata
        out.truncated = t.TextFits == false
    end
    return out
end

local function collect()
    local report = {
        at = os.date("%H:%M:%S"),
        placeId = game.PlaceId,
        running = game:GetService("RunService"):IsRunning(),
    }

    local camera = Workspace.CurrentCamera
    if camera ~= nil then
        report.viewport = { math.round(camera.ViewportSize.X), math.round(camera.ViewportSize.Y) }
    end

    -- fonturile pe care le cere tema: exista familia pe clientul asta?
    local fonts = {}
    for _, name in { "FredokaOne", "Nunito", "Merriweather", "LuckiestGuy", "Montserrat" } do
        local ok, value = pcall(function()
            return (Enum.Font :: any)[name]
        end)
        fonts[name] = ok and value ~= nil
    end
    report.fontsAvailable = fonts

    -- elementele urmarite
    local found, missing = {}, {}
    local player = Players.LocalPlayer
    local gui = player ~= nil and player:FindFirstChild("PlayerGui") or nil
    if gui ~= nil then
        local roots = {}
        for _, child in gui:GetChildren() do
            if child:IsA("ScreenGui") then
                table.insert(roots, {
                    name = child.Name,
                    displayOrder = child.DisplayOrder,
                    insets = child.ScreenInsets.Name,
                    enabled = child.Enabled,
                    descendants = #child:GetDescendants(),
                })
            end
        end
        report.screenGuis = roots

        for _, want in WATCH do
            local hit = gui:FindFirstChild(want, true)
            if hit ~= nil then
                table.insert(found, describe(hit))
            else
                table.insert(missing, want)
            end
        end
    else
        report.note = "fara LocalPlayer: intra in Play, apoi apasa Probe din nou"
    end
    report.watched = found
    report.missing = missing

    -- erorile din consola: exact ce ma opreste sa vad daca bootstrap-ul a picat pe la mijloc
    local errors = {}
    local okLog = pcall(function()
        for _, entry in LogService:GetLogHistory() do
            if entry.messageType == Enum.MessageType.MessageError
                or entry.messageType == Enum.MessageType.MessageWarning
            then
                table.insert(errors, {
                    kind = entry.messageType.Name,
                    text = string.sub(entry.message, 1, 220),
                })
            end
        end
    end)
    if okLog then
        -- doar ultimele: consola tine mult si raportul trebuie sa ramana ieftin
        local tail = {}
        local from = math.max(1, #errors - 24)
        for i = from, #errors do
            table.insert(tail, errors[i])
        end
        report.problems = tail
        report.problemCount = #errors
    end

    return report
end

local function send()
    local report = collect()
    local body = HttpService:JSONEncode(report)
    local ok, err = pcall(function()
        HttpService:RequestAsync({
            Url = ENDPOINT,
            Method = "POST",
            Headers = { ["Content-Type"] = "application/json" },
            Body = body,
        })
    end)
    if ok then
        print(`[Driftwood] raport trimis: {#body} octeti`)
        return
    end
    -- Rezerva: daca HTTP e blocat, scriem in Output ca sa se poata copia de acolo.
    warn(`[Driftwood] HTTP a esuat ({err}). Raportul e mai jos, intre marcaje.`)
    print("----8<---- DRIFTWOOD PROBE ----8<----")
    print(body)
    print("----8<---- SFARSIT ----8<----")
end

button.Click:Connect(function()
    -- Plugin-urile au voie sa porneasca HTTP in Studio; fara asta RequestAsync cade din prima.
    pcall(function()
        HttpService.HttpEnabled = true
    end)
    send()
end)
