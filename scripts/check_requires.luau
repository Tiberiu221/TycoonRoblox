--!strict
-- Verifica STATIC ca fiecare require dintr-un scenariu construit ajunge la un modul care exista.
-- Motivul: o cale gresita (`script.Parent.Foo` scris cu alt nume) nu se vede nici la stylua, nici
-- la selene, nici la `rojo build` — apare abia cand rulezi jocul, si atunci opreste tot bootstrap-ul.
-- Rulare:
--   rojo build default.project.json --output /tmp/check.rbxl
--   lune run scripts/check_requires /tmp/check.rbxl
local fs = require("@lune/fs")
local process = require("@lune/process")
local roblox = require("@lune/roblox")

local placePath = process.args[1] or "/tmp/check.rbxl"
if not fs.isFile(placePath) then
    print(
        `nu gasesc {placePath}; ruleaza intai: rojo build default.project.json --output {placePath}`
    )
    process.exit(1)
end

local game = roblox.deserializePlace(fs.readFile(placePath))

type Problem = { script: string, path: string, reason: string }
local problems: { Problem } = {}
local checked = 0
local skipped = 0

local function fullName(inst: Instance): string
    local parts = { inst.Name }
    local current = inst.Parent
    while current ~= nil and current ~= game do
        table.insert(parts, 1, current.Name)
        current = current.Parent
    end
    return table.concat(parts, ".")
end

local function serviceByName(name: string): Instance?
    local ok, service = pcall(function()
        return game:GetService(name :: any)
    end)
    return if ok then service else nil
end

-- `:WaitForChild("Foo")` si `:FindFirstChild("Foo")` sunt echivalente cu `.Foo` pentru cautarea
-- statica; le normalizez ca sa nu am nevoie de doua seturi de tipare.
local function normalize(source: string): string
    local out = string.gsub(source, ':WaitForChild%("([%w_]+)"%)', ".%1")
    out = string.gsub(out, ':WaitForChild%("([%w_]+)",%s*[%w%.]+%)', ".%1")
    out = string.gsub(out, ':FindFirstChild%("([%w_]+)"%)', ".%1")
    return out
end

-- Aliasuri locale: `local Services = script.Parent.Services` sau `= game:GetService("X")`
local function aliasMap(source: string): { [string]: string }
    local map: { [string]: string } = {}
    for name, service in
        string.gmatch(source, 'local%s+([%w_]+)%s*=%s*game:GetService%("([%w]+)"%)')
    do
        map[name] = `@service:{service}`
    end
    for name, path in string.gmatch(source, "local%s+([%w_]+)%s*=%s*([%w_][%w_%.]*)[%s\n]") do
        if
            map[name] == nil
            and (string.find(path, "^script") ~= nil or string.find(path, "%.") ~= nil)
        then
            map[name] = path
        end
    end
    return map
end

local MAX_DEPTH = 6

local function resolve(
    source: Instance,
    path: string,
    aliases: { [string]: string },
    depth: number
): (Instance?, string)
    if depth > MAX_DEPTH then
        return nil, "skip"
    end
    local parts = string.split(path, ".")
    local root = table.remove(parts, 1) :: string

    local current: Instance?
    if root == "script" then
        current = source
    else
        local alias = aliases[root]
        if alias == nil then
            return nil, "skip"
        end
        local serviceName = string.match(alias, "^@service:([%w]+)$")
        if serviceName ~= nil then
            current = serviceByName(serviceName)
        else
            current = resolve(source, alias, aliases, depth + 1)
        end
        if current == nil then
            return nil, "skip"
        end
    end

    for _, part in parts do
        if part == "Parent" then
            current = (current :: Instance).Parent
        else
            current = (current :: Instance):FindFirstChild(part)
        end
        if current == nil then
            return nil, `lipseste "{part}"`
        end
    end
    return current, "ok"
end

-- A doua verificare: `Modul.Functie(...)` unde modulul nu defineste `Functie`.
-- Exact asta a scapat cand HUDController a ramas fara SetWorkshop/SetAlert: stylua, selene si
-- rojo build au trecut toate, iar apelul a crapat abia in joc.
-- Culegerea numelor publice e DELIBERAT generoasa (orice `nume =` la inceput de linie intra),
-- ca sa ratam mai degraba un bug decat sa raportam unul fals.
local function publicNames(source: string): { [string]: boolean }
    local names: { [string]: boolean } = {}
    for name in string.gmatch(source, "function%s+[%w_]+[%.:]([%w_]+)") do
        names[name] = true
    end
    for name in string.gmatch(source, "[%w_]+%.([%w_]+)%s*=") do
        names[name] = true
    end
    for name in string.gmatch(source, "export%s+type%s+([%w_]+)") do
        names[name] = true
    end
    for name in string.gmatch(source, "\n%s*([%w_]+)%s*=") do
        names[name] = true
    end
    for name in string.gmatch(source, '%["([%w_]+)"%]%s*=') do
        names[name] = true
    end
    -- `return { nume = valoare }` pe o singura linie: si aici sunt campuri publice
    for name in string.gmatch(source, "[{,]%s*([%w_]+)%s*=") do
        names[name] = true
    end
    return names
end

local apiChecked = 0

-- `local Foo = require(<cale>)`: numele local -> modulul cerut. Aliasurile obisnuite nu acopera
-- forma asta, pentru ca valoarea e un apel, nu o cale.
local function requireMap(source: string): { [string]: string }
    local map: { [string]: string } = {}
    for name, path in
        string.gmatch(source, "local%s+([%w_]+)%s*=%s*require%(%s*([%w_][%w_%.]*)%s*%)")
    do
        map[name] = path
    end
    return map
end

-- Modulele din Packages sunt ale altcuiva: isi construiesc API-ul cum vor (metatabele, fabrici),
-- iar euristica de aici ar da alarme false pe ele.
local function isOurs(inst: Instance): boolean
    local current: Instance? = inst
    while current ~= nil do
        if current.Name == "Packages" or current.Name == "ServerPackages" then
            return false
        end
        current = current.Parent
    end
    return true
end

local function checkModuleApi(inst: Instance, source: string, aliases: { [string]: string })
    -- caile din interiorul require(...) nu sunt accesari de camp; fara asta, `require(Net.Net)`
    -- s-ar raporta ca "Net nu defineste Net"
    local body = string.gsub(source, "require%b()", "require()")
    for alias, path in requireMap(source) do
        local target = resolve(inst, path, aliases, 0)
        if target == nil or not target:IsA("ModuleScript") or not isOurs(target) then
            continue
        end
        local names = publicNames((target :: any).Source :: string)
        local seen: { [string]: boolean } = {}
        -- `[^%w_%.:]` si nu `[^%w_]`: altfel `deps.RiverConfig.OnClientEvent` ar fi luat drept
        -- acces pe modulul RiverConfig, care doar se intampla sa aiba acelasi nume local
        for field in string.gmatch(body, `[^%w_%.:]{alias}%.([%w_]+)`) do
            if seen[field] then
                continue
            end
            seen[field] = true
            apiChecked += 1
            if not names[field] then
                table.insert(problems, {
                    script = fullName(inst),
                    path = `{alias}.{field}`,
                    reason = `{target.Name} nu defineste "{field}"`,
                })
            end
        end
    end
end

-- A treia verificare: tipare de cod care compileaza, trec de lint, si totusi sunt gresite.
-- Deocamdata unul singur, dar unul care a costat o sesiune intreaga de depanare.
type Rule = { pattern: string, why: string }

local BAD_PATTERNS: { Rule } = {
    {
        pattern = "ProfileLoaded:Connect%(function%([^)]*,",
        why = "handler-ul de ProfileLoaded primeste al doilea argument: semnalul trece printr-un "
            .. "BindableEvent, care COPIAZA tabelele. Ia profilul cu DataService.Get(player).",
    },
}

local function checkPatterns(inst: Instance, source: string)
    for _, rule in BAD_PATTERNS do
        if string.find(source, rule.pattern) ~= nil then
            table.insert(problems, {
                script = fullName(inst),
                path = "tipar interzis",
                reason = rule.why,
            })
        end
    end
end

-- ---- REMOTE-URI FOLOSITE PE AMANDOUA PARTILE -------------------------------------------------
-- Bugul pe care il apara: un `Net.Get("X").OnServerEvent:Connect(...)` care nu ajunge niciodata in
-- fisier (o inserare de cod esuata in tacere, o stergere la un refactor). Clientul trage remote-ul,
-- nimeni nu asculta, si butonul pur si simplu nu face nimic -- fara nicio eroare, nicaieri.
-- S-a intamplat exact asa cu ClaimQuest si SpinWheel.
local remoteSide: { [string]: { server: boolean, client: boolean } } = {}
local remoteNames: { string } = {}

local function noteRemotes(inst: Instance, source: string)
    local full = fullName(inst)
    local isServer = string.find(full, "ServerScriptService", 1, true) ~= nil
    local isClient = string.find(full, "StarterPlayer", 1, true) ~= nil
    if not isServer and not isClient then
        return
    end
    for name in string.gmatch(source, 'Net%.Get%(%s*"([%w_]+)"%s*%)') do
        local entry = remoteSide[name]
        if entry == nil then
            entry = { server = false, client = false }
            remoteSide[name] = entry
        end
        if isServer then
            entry.server = true
        else
            entry.client = true
        end
    end
end

local function collectRemoteNames(inst: Instance, source: string)
    if inst.Name ~= "Net" then
        return
    end
    local block = string.match(source, "REMOTE_NAMES[^=]*=%s*{(.-)\n}")
    if block == nil then
        return
    end
    -- DOAR numele, adica sirul cu care INCEPE un rand din tabel. Un `string.gmatch` lacom peste tot
    -- blocul aduna si sirurile din comentarii ("locked", "owned", ...) si raporteaza remote-uri
    -- care nu exista.
    for line in string.gmatch(block, "[^\n]+") do
        local name = string.match(line, '^%s*"([%w_]+)",')
        if name ~= nil then
            table.insert(remoteNames, name)
        end
    end
end

local function scan(inst: Instance)
    if inst:IsA("ModuleScript") or inst:IsA("Script") or inst:IsA("LocalScript") then
        local source = normalize((inst :: any).Source :: string)
        local aliases = aliasMap(source)
        for path in string.gmatch(source, "require%(%s*([%w_][%w_%.]*)%s*%)") do
            local target, reason = resolve(inst, path, aliases, 0)
            if target == nil then
                if reason ~= "skip" then
                    table.insert(
                        problems,
                        { script = fullName(inst), path = path, reason = reason }
                    )
                else
                    skipped += 1
                end
            elseif not target:IsA("ModuleScript") then
                table.insert(problems, {
                    script = fullName(inst),
                    path = path,
                    reason = `nu e ModuleScript ({target.ClassName})`,
                })
            else
                checked += 1
            end
        end
        checkModuleApi(inst, source, aliases)
        checkPatterns(inst, source)
        noteRemotes(inst, source)
        collectRemoteNames(inst, source)
    end
    for _, child in inst:GetChildren() do
        scan(child)
    end
end

scan(game)

local remotesChecked = 0
for _, name in remoteNames do
    local entry = remoteSide[name]
    remotesChecked += 1
    if entry == nil then
        table.insert(problems, {
            script = "Shared.Net.Net",
            path = name,
            reason = "remote declarat dar nefolosit nicaieri",
        })
    elseif not entry.server then
        table.insert(problems, {
            script = "Shared.Net.Net",
            path = name,
            reason = "remote folosit doar pe CLIENT -- nimeni nu asculta pe server",
        })
    elseif not entry.client then
        table.insert(problems, {
            script = "Shared.Net.Net",
            path = name,
            reason = "remote folosit doar pe SERVER -- clientul nu-l atinge",
        })
    end
end

print(
    `require-uri verificate: {checked}   ·   campuri de modul verificate: {apiChecked}   ·   remote-uri: {remotesChecked}   ·   sarite: {skipped}`
)
if #problems == 0 then
    print("toate caile si campurile se rezolva")
    process.exit(0)
end
for _, p in problems do
    print(`  ! {p.script}: {p.path} — {p.reason}`)
end
print(`{#problems} probleme`)
process.exit(1)
