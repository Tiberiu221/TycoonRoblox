--!nocheck
-- Sonda Driftwood: raporteaza din INTERIORUL Studio ce nu se vede din afara si, din 2026-09-19, porneste singura un Play.
--
-- DE CE EXISTA: nu pot deschide Studio si nu pot vedea ecranul. Un screenshot costa mult si oricum nu raspunde la
-- intrebarile care ma incurca cel mai des: a crapat vreun controller la bootstrap? ce text iese din cutia lui? ce panou e
-- deschis? Toate astea sunt TEXT, deci ieftine.
--
-- [2026-09-19] Owner-ul a dat Play si a vazut doar cerul: bootstrap-ul clientului murise la primul require, iar eu n-aveam
-- cum sa aflu fara el. De atunci sonda are TREI roluri, dupa fereastra in care ruleaza:
--   edit    -- fereastra de editare. Comenzi: `play` (porneste un test, StudioTestService), `report`.
--              Un Play pornit de aici ruleaza pe un PROFIL DE PROBA, niciodata pe salvarea owner-ului: inainte de
--              start pune atributul `ProbeRun` pe Workspace (partile de joc se cloneaza din fereastra de editare, deci
--              il au din prima clipa), iar DataService il citeste doar in Studio. La sfarsit il sterge.
--   server  -- partea de server a unui Play. Comenzi: `stop` (opreste testul), `client:<comanda>` (o trimite clientului
--              printr-un atribut replicat), `report` (erorile serverului), `dev:<id>|<comanda>:<arg>` (o comanda din
--              consola de dev, data jocului prin BindableFunction-ul `ServerStorage.DevProbe`, fara HTTP din joc;
--              raspunsul e tiparit ca al clientului).
--   client  -- partea de client a unui Play. N-are voie la HTTP, deci isi TIPARESTE raspunsurile in Output, in bucati
--              marcate `[[PROBE id i/n]]`; de acolo ajung in jurnalul Studio, pe care il citeste scripts/probe.py.
--              Comenzi: `report`, `frames`, `texts[:radacina]`, `overlaps[:radacina]`, `find:<Nume>` (orice element cu
--              numele asta: clasa, daca se vede, cutia, imaginea, textul), `fire:<Remote>:<arg,arg>` (aceeasi cerere pe
--              care o trimite jocul la un buton: BuyPad, CollectNet, ClaimQuest...), `ui:<actiune>` (o da jocului, care
--              in Studio stie sa deschida un panou dupa nume: `open:quests`, `close`, `station:net:first_net`,
--              `crew:porter`).
--
-- Instalare:  bash scripts/install_plugin.sh      Folosire: python3 scripts/probe.py --help
-- Fisierul asta NU face parte din joc: nu e sub src/, nu intra in rojo, nu se livreaza.
local HttpService = game:GetService("HttpService")
local LogService = game:GetService("LogService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local BASE = "http://127.0.0.1:8787"
local POLL_SECONDS = 2
local CHUNK = 700 -- o linie de jurnal prea lunga risca sa fie taiata; bucatile se lipesc la citire

local role = "edit"
if RunService:IsRunning() then
    if RunService:IsClient() and not RunService:IsServer() then
        role = "client"
    elseif RunService:IsServer() and not RunService:IsClient() then
        role = "server"
    else
        role = "solo" -- Play Solo vechi: o singura fereastra, si server, si client
    end
end

local function httpOn()
    -- Plugin-urile au voie sa porneasca HTTP in Studio; fara asta RequestAsync cade din prima.
    pcall(function()
        HttpService.HttpEnabled = true
    end)
end

-- ---- ce se vede ---------------------------------------------------------------------------------------------------
local function playerGui(): Instance?
    local player = Players.LocalPlayer
    return player ~= nil and player:FindFirstChild("PlayerGui") or nil
end

-- Vizibil cu adevarat: el si toti parintii lui, pana la un ScreenGui pornit.
local function shown(inst: Instance): boolean
    local node: Instance? = inst
    while node ~= nil do
        if node:IsA("GuiObject") and not node.Visible then
            return false
        elseif node:IsA("LayerCollector") then
            return node.Enabled
        end
        node = node.Parent
    end
    return false
end

local function box(g: GuiObject): { number }
    return {
        math.round(g.AbsolutePosition.X),
        math.round(g.AbsolutePosition.Y),
        math.round(g.AbsoluteSize.X),
        math.round(g.AbsoluteSize.Y),
    }
end

local function findRoot(name: string?): Instance?
    local gui = playerGui()
    if gui == nil or name == nil or name == "" then
        return gui
    end
    return gui:FindFirstChild(name, true)
end

local function problems(limit: number): ({ any }, number)
    local all = {}
    pcall(function()
        for _, entry in LogService:GetLogHistory() do
            if
                entry.messageType == Enum.MessageType.MessageError
                or entry.messageType == Enum.MessageType.MessageWarning
            then
                table.insert(all, { kind = entry.messageType.Name, text = string.sub(entry.message, 1, 260) })
            end
        end
    end)
    local tail = {}
    for i = math.max(1, #all - limit + 1), #all do
        table.insert(tail, all[i])
    end
    return tail, #all
end

local function collectReport(): { [string]: any }
    local report: { [string]: any } = {
        role = role,
        at = os.date("%H:%M:%S"),
        placeId = game.PlaceId,
        running = RunService:IsRunning(),
    }
    local camera = Workspace.CurrentCamera
    if camera ~= nil then
        report.viewport = { math.round(camera.ViewportSize.X), math.round(camera.ViewportSize.Y) }
    end
    local gui = playerGui()
    if gui ~= nil then
        local roots = {}
        for _, child in gui:GetChildren() do
            if child:IsA("ScreenGui") then
                table.insert(roots, {
                    name = child.Name,
                    enabled = child.Enabled,
                    order = child.DisplayOrder,
                    descendants = #child:GetDescendants(),
                })
            end
        end
        report.screenGuis = roots
    end
    report.problems, report.problemCount = problems(40)
    return report
end

-- Panourile: copiii directi ai fiecarui ScreenGui, cu steagul Visible -- ca sa stiu ce e deschis acum.
local function collectFrames(): { any }
    local out = {}
    local gui = playerGui()
    if gui == nil then
        return out
    end
    for _, screen in gui:GetChildren() do
        if screen:IsA("ScreenGui") and screen.Enabled then
            for _, child in screen:GetChildren() do
                if child:IsA("GuiObject") then
                    table.insert(out, { gui = screen.Name, name = child.Name, visible = child.Visible, box = box(child) })
                    -- HUD-ul sta tot intr-o panza scalata ("Canvas"): panourile sunt copiii EI
                    if child.Name == "Canvas" then
                        for _, panel in child:GetChildren() do
                            if panel:IsA("GuiObject") then
                                table.insert(out, {
                                    gui = screen.Name,
                                    name = panel.Name,
                                    visible = panel.Visible,
                                    box = box(panel),
                                })
                            end
                        end
                    end
                end
            end
        end
    end
    return out
end

-- Tot textul care se vede acum sub `rootName` (sau in tot PlayerGui): ce scrie, cat de mare, unde, si daca incape.
local function collectTexts(rootName: string?): { any }
    local out = {}
    local root = findRoot(rootName)
    if root == nil then
        return out
    end
    for _, d in root:GetDescendants() do
        if (d:IsA("TextLabel") or d:IsA("TextButton") or d:IsA("TextBox")) and d.Text ~= "" and shown(d) then
            table.insert(out, {
                name = d.Name,
                parent = d.Parent and d.Parent.Name or "",
                text = string.sub(d.Text, 1, 70),
                size = d.TextSize,
                scaled = d.TextScaled,
                fits = d.TextFits,
                auto = d.AutomaticSize ~= Enum.AutomaticSize.None, -- cu AutomaticSize, TextFits nu e de incredere
                box = box(d),
                button = d:IsA("TextButton"),
            })
            if #out >= 220 then
                break
            end
        end
    end
    return out
end

-- Texte care se calca intre ele: doua texte vizibile, niciunul parintele celuilalt, cu dreptunghiurile suprapuse.
local function collectOverlaps(rootName: string?): { any }
    local root = findRoot(rootName)
    local items = {}
    if root ~= nil then
        for _, d in root:GetDescendants() do
            if (d:IsA("TextLabel") or d:IsA("TextButton")) and d.Text ~= "" and shown(d) then
                table.insert(items, d)
            end
        end
    end
    local out = {}
    for i = 1, #items do
        for j = i + 1, #items do
            local a, b = items[i], items[j]
            if a:IsDescendantOf(b) or b:IsDescendantOf(a) then
                continue
            end
            local ap, as, bp, bs = a.AbsolutePosition, a.AbsoluteSize, b.AbsolutePosition, b.AbsoluteSize
            local w = math.min(ap.X + as.X, bp.X + bs.X) - math.max(ap.X, bp.X)
            local h = math.min(ap.Y + as.Y, bp.Y + bs.Y) - math.max(ap.Y, bp.Y)
            if w > 2 and h > 2 then
                table.insert(out, {
                    a = a.Name .. ": " .. string.sub(a.Text, 1, 30),
                    b = b.Name .. ": " .. string.sub(b.Text, 1, 30),
                    overlap = { math.round(w), math.round(h) },
                })
                if #out >= 40 then
                    return out
                end
            end
        end
    end
    return out
end

-- Orice element cu numele asta din PlayerGui: exista? se vede? unde? ce imagine sau text are?
local function collectFind(name: string): { any }
    local out = {}
    local gui = playerGui()
    if gui == nil or name == "" then
        return out
    end
    for _, d in gui:GetDescendants() do
        if d.Name == name then
            local row: { [string]: any } = { class = d.ClassName, parent = d.Parent and d.Parent.Name or "" }
            if d:IsA("GuiObject") then
                row.shown = shown(d)
                row.box = box(d)
            end
            if d:IsA("ImageLabel") or d:IsA("ImageButton") then
                row.image = d.Image
            elseif d:IsA("TextLabel") or d:IsA("TextButton") then
                row.text = string.sub(d.Text, 1, 70)
            end
            table.insert(out, row)
            if #out >= 24 then
                break
            end
        end
    end
    return out
end

-- ---- iesirea -------------------------------------------------------------------------------------------------------
local function post(report: { [string]: any })
    httpOn()
    local body = HttpService:JSONEncode(report)
    local ok, err = pcall(function()
        HttpService:RequestAsync({
            Url = `{BASE}/report?who={if role == "solo" then "server" else role}`,
            Method = "POST",
            Headers = { ["Content-Type"] = "application/json" },
            Body = body,
        })
    end)
    if ok then
        print(`[Driftwood] raport trimis ({role}): {#body} octeti`)
    else
        warn(`[Driftwood] HTTP a esuat ({err})`)
    end
end

-- Clientul nu are HTTP: raspunsul merge in Output, in bucati, si de acolo in jurnalul Studio.
local function emit(id: string, payload: any)
    local body = HttpService:JSONEncode(payload)
    local n = math.max(1, math.ceil(#body / CHUNK))
    for i = 1, n do
        print(`[[PROBE {id} {i}/{n}]]{string.sub(body, (i - 1) * CHUNK + 1, i * CHUNK)}`)
    end
end

-- ---- comenzile clientului --------------------------------------------------------------------------------------
local function runClient(id: string, cmd: string)
    local verb, arg = string.match(cmd, "^(%w+):?(.*)$")
    if verb == "report" then
        emit(id, collectReport())
    elseif verb == "frames" then
        emit(id, collectFrames())
    elseif verb == "texts" then
        emit(id, collectTexts(arg))
    elseif verb == "overlaps" then
        emit(id, collectOverlaps(arg))
    elseif verb == "find" then
        emit(id, collectFind(arg))
    elseif verb == "fire" then
        -- `fire:<Remote>:<arg1>,<arg2>`: ACEEASI cerere pe care o trimite jocul cand apesi un buton (BuyPad, CollectNet,
        -- ClaimQuest, UpgradeStation...). Serverul e singura sursa de adevar si valideaza tot, deci asta e jucat de-adevaratelea,
        -- nu o scurtatura de dev. Clientul Roblox ignora tastele sintetice; intentiile insa pleaca la fel.
        local remoteName, rest = string.match(arg, "^([%w_]+):?(.*)$")
        local folder = ReplicatedStorage:FindFirstChild("Remotes")
        local remote = folder and folder:FindFirstChild(remoteName or "")
        if remote == nil or not remote:IsA("RemoteEvent") then
            emit(id, { error = "remote lipsa", remote = remoteName })
            return
        end
        local args = {}
        for piece in string.gmatch(rest or "", "[^,]+") do
            table.insert(args, tonumber(piece) or piece)
        end
        remote:FireServer(table.unpack(args))
        emit(id, { ok = true, fired = remoteName, args = args })
    elseif verb == "ui" then
        -- jocul (doar in Studio) asculta atributul asta si deschide/inchide panoul cerut; raspunsul vine dupa un cadru
        Workspace:SetAttribute("DevUi", `{id}|{arg}`)
        task.wait(0.6)
        emit(id, { ok = true, ui = arg, frames = collectFrames() })
    else
        emit(id, { error = "comanda necunoscuta", cmd = cmd })
    end
end

if role == "client" then
    local last = ReplicatedStorage:GetAttribute("ProbeCmd") -- ce era deja acolo e vechi
    ReplicatedStorage:GetAttributeChangedSignal("ProbeCmd"):Connect(function()
        local raw = ReplicatedStorage:GetAttribute("ProbeCmd")
        if typeof(raw) ~= "string" or raw == last then
            return
        end
        last = raw
        local id, cmd = string.match(raw, "^([%w_]+)|(.*)$")
        if id ~= nil then
            local ok, err = pcall(runClient, id, cmd)
            if not ok then
                emit(id, { error = tostring(err) })
            end
        end
    end)
    print("[Driftwood] sonda (client) asculta")
    return
end

-- ---- comenzile editorului si ale serverului ---------------------------------------------------------------------
local function runHost(cmd: string)
    local verb, arg = string.match(cmd, "^(%w+):?(.*)$")
    if verb == "report" then
        post(collectReport())
    elseif verb == "play" and role == "edit" then
        task.spawn(function()
            print("[Driftwood] pornesc un Play de proba (StudioTestService)")
            Workspace:SetAttribute("ProbeRun", true) -- partile de joc se cloneaza de aici: il au din prima clipa
            local ok, result = pcall(function()
                return game:GetService("StudioTestService"):ExecutePlayModeAsync({ probe = true })
            end)
            Workspace:SetAttribute("ProbeRun", nil)
            print(`[Driftwood] Play incheiat: {ok} {tostring(result)}`)
        end)
    elseif verb == "stop" and role ~= "edit" then
        print("[Driftwood] opresc testul")
        pcall(function()
            game:GetService("StudioTestService"):EndTest("probe")
        end)
    elseif verb == "dev" and role ~= "edit" then
        -- `dev:<id>|<comanda>:<arg>`: consola de dev a jocului, fara HTTP din joc
        local id, rest = string.match(arg, "^([%w_]+)|(.*)$")
        if id == nil then
            return
        end
        local command, value = string.match(rest, "^(%w+):?(.*)$")
        local bridge = game:GetService("ServerStorage"):FindFirstChild("DevProbe")
        if bridge == nil or not bridge:IsA("BindableFunction") then
            emit(id, { error = "jocul n-are ServerStorage.DevProbe (versiune veche sau nu ruleaza in Studio)" })
            return
        end
        local okInvoke, reply = pcall(function()
            return bridge:Invoke(command, tonumber(value) or (if value ~= "" then value else nil))
        end)
        emit(id, { ok = okInvoke, reply = tostring(reply) })
    elseif verb == "client" and role ~= "edit" then
        if role == "solo" then
            local id, rest = string.match(arg, "^([%w_]+)|(.*)$")
            if id ~= nil then
                pcall(runClient, id, rest)
            end
        else
            ReplicatedStorage:SetAttribute("ProbeCmd", arg) -- `id|comanda`, replicat catre client
        end
    else
        warn(`[Driftwood] comanda nepotrivita pentru {role}: {cmd}`)
    end
end

local toolbar = plugin:CreateToolbar("Driftwood")
local button = toolbar:CreateButton("Probe", "Trimite un raport de interfata la serverul local", "")
button.ClickableWhenViewportHidden = true
button.Click:Connect(function()
    post(collectReport())
end)

-- PARTEA DE SERVER A UNUI PLAY decide daca e unul de proba, chiar la incarcare: fereastra de editare citeste sonda doar
-- la pornirea Studio-ului, deci poate rula o versiune care nu pune `ProbeRun`; partea de server o citeste proaspata la
-- fiecare Play. Jocul (DataService, doar in Studio) asteapta `ProbeDecided` cel mult doua secunde inainte sa aleaga profilul.
if role == "server" or role == "solo" then
    if Workspace:GetAttribute("ProbeRun") ~= true then
        httpOn()
        local ok, response = pcall(function()
            return HttpService:RequestAsync({ Url = `{BASE}/proberun`, Method = "GET" })
        end)
        if ok and response ~= nil and response.Success and response.Body == "1" then
            Workspace:SetAttribute("ProbeRun", true)
        end
    end
    Workspace:SetAttribute("ProbeDecided", true)
    print(`[Driftwood] Play de proba: {Workspace:GetAttribute("ProbeRun") == true}`)
end

if role == "edit" and Workspace:GetAttribute("ProbeRun") ~= nil then
    Workspace:SetAttribute("ProbeRun", nil) -- ramas de la un Play de proba intrerupt (Studio inchis la mijloc)
end
print(`[Driftwood] sonda incarcata ({role}), bucla de comenzi pornita`)
task.spawn(function()
    local who = if role == "solo" then "server" else role
    while true do
        task.wait(POLL_SECONDS)
        httpOn()
        local ok, response = pcall(function()
            return HttpService:RequestAsync({ Url = `{BASE}/cmd?who={who}`, Method = "GET" })
        end)
        if ok and response ~= nil and response.Success and response.Body ~= "" and response.Body ~= "[]" then
            local okDecode, decoded = pcall(function()
                return HttpService:JSONDecode(response.Body)
            end)
            if okDecode and typeof(decoded) == "table" then
                for _, cmd in decoded do
                    if typeof(cmd) == "string" then
                        local okRun, err = pcall(runHost, cmd)
                        if not okRun then
                            warn(`[Driftwood] {cmd}: {err}`)
                        end
                    end
                end
            end
        end
    end
end)
