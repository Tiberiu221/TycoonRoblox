--!strict
-- [D61, partea 2] PASS-URILE (montat in ambele place-uri). Un pass se cumpara o data si e al tau pentru totdeauna;
-- Roblox tine minte cine il are, noi tinem o COPIE in profil (`Purchases.passes`):
--   * la intrare intrebam Roblox (UserOwnsGamePassAsync, cu pcall) si trecem in copie ce ai cumparat in alta parte;
--   * daca intrebarea pica, ramai cu copia -- ce ai platit nu dispare pentru ca un serviciu a raspuns prost [P2];
--   * la cumparare (PromptGamePassPurchaseFinished) copia se scrie pe loc, deci efectul se vede imediat.
-- Toata lumea citeste pass-urile din profil, prin PassMath: lantul (2x Flow), offline-ul (Long Nights), mersul (Swift
-- Boots), titlurile (Supporter). Un pass are deci un singur loc in care "exista".
--
-- Cand un pass se schimba, se golesc cele doua cache-uri de stare ale satului (PadService, StationService): altfel
-- venitul de pe HUD s-ar dubla abia la urmatoarea cumparatura.
local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local MonetizationConfig = require(ReplicatedStorage.Shared.Config.MonetizationConfig)
local PassMath = require(ReplicatedStorage.Shared.Modules.PassMath)

local Analytics = require(script.Parent.Analytics)
local DataService = require(script.Parent.DataService)

local PassService = {}

export type Deps = {
    PushState: ((Player) -> ())?,
    -- ce trebuie refacut cand un pass se schimba (cache-urile de stare ale satului; in balci, lista People)
    Invalidate: ((Player) -> ())?,
    -- bannerul de dupa cumparare
    OnGranted: ((Player, string) -> ())?,
}
local deps: Deps = {}

local function passesOf(data: any): { [string]: boolean }
    if typeof(data.Purchases) ~= "table" then
        data.Purchases = { ids = {}, passes = {} }
    end
    if typeof(data.Purchases.passes) ~= "table" then
        data.Purchases.passes = {}
    end
    return data.Purchases.passes
end

-- Un pas din palnia magazinului, o singura data pe jucator.
local function firstStep(player: Player, flag: string)
    local data = DataService.Get(player)
    if data ~= nil and not data.Firsts[flag] then
        data.Firsts[flag] = true
        Analytics.ShopStep(player, flag)
    end
end

local function changed(player: Player)
    local invalidate = deps.Invalidate
    if invalidate ~= nil then
        invalidate(player)
    end
    local push = deps.PushState
    if push ~= nil then
        push(player)
    end
end

-- Copia din profil, cum o trimitem clientului: cheia -> true, doar pentru pass-urile din catalog.
function PassService.Snapshot(player: Player): { [string]: boolean }
    local out: { [string]: boolean } = {}
    local data = DataService.Get(player)
    if data == nil then
        return out
    end
    for _, item in MonetizationConfig.ITEMS do
        if item.kind == "pass" and PassMath.has(data, item.key) then
            out[item.key] = true
        end
    end
    return out
end

function PassService.Has(player: Player, key: string): boolean
    return PassMath.has(DataService.Get(player), key)
end

-- Cat de repede merge omul asta (Swift Boots). Serverul balciului il da lui FairPresence; clientul il afla din stare.
function PassService.SpeedFactor(player: Player): number
    return PassMath.speedFactor(DataService.Get(player))
end

-- Scrie copia din profil. Intoarce true daca s-a schimbat ceva.
local function set(player: Player, key: string, owned: boolean): boolean
    local data = DataService.Get(player)
    local item = MonetizationConfig.byKey[key]
    if data == nil or item == nil or item.kind ~= "pass" then
        return false
    end
    local passes = passesOf(data)
    if (passes[key] == true) == owned then
        return false
    end
    passes[key] = if owned then true else nil
    return true
end

-- La intrare: intrebam Roblox despre fiecare pass creat pe universul asta. Raspunsul "da" se scrie in copie. Raspunsul
-- "nu" NU sterge nimic: UserOwnsGamePassAsync tine raspunsurile in memorie pe server si poate spune "nu" despre un
-- pass abia cumparat in alta parte, iar prima regula a jocului e ca nimic nu se pierde [P2] -- mai bine un pass
-- rambursat ramas activ decat unul platit disparut. O intrebare picata nu atinge nimic.
local function verify(player: Player)
    -- [D63] Un Play de proba al sondei nu intreaba Roblox ce detii. Creatorul unui pass il detine automat, deci owner-ul
    -- (si sonda, care joaca din contul lui) ar avea mereu venit dublu si pas iute, iar ritmul masurat n-ar mai fi al unui
    -- jucator obisnuit. In jocurile de proba pass-urile se dau doar din consola de dev (`pass <cheie>`).
    if DataService.StudioSave(player) == "probe" then
        return
    end
    local any = false
    for _, item in MonetizationConfig.ITEMS do
        if item.kind ~= "pass" then
            continue
        end
        local id = MonetizationConfig.idOf(game.GameId, item.key)
        if id == 0 then
            continue -- pass-ul nu exista inca pe universul asta: copia (de proba, din Studio) ramane cum e
        end
        local ok, owns = pcall(function()
            return MarketplaceService:UserOwnsGamePassAsync(player.UserId, id)
        end)
        if player.Parent ~= Players then
            return
        end
        if ok and owns == true then
            any = set(player, item.key, true) or any
        elseif not ok then
            warn(`[Pass] nu am putut verifica {item.key} pentru {player.Name}: {owns}`)
        end
    end
    if any then
        changed(player)
    end
end

-- [Studio] Pass-uri de proba, fara Robux. In sat, din consola de dev (`pass <cheie>`); in Balci.rbxl (profil proaspat la
-- fiecare Play), din atributul `DevPasses` al Workspace-ului: "swift,supporter".
function PassService.DevToggle(player: Player, key: string): (boolean, boolean)
    if not RunService:IsStudio() then
        return false, false
    end
    local item = MonetizationConfig.byKey[key]
    if item == nil or item.kind ~= "pass" then
        return false, false
    end
    local now = not PassService.Has(player, key)
    set(player, key, now)
    changed(player)
    return true, now
end

local function devAttribute(player: Player)
    if not RunService:IsStudio() then
        return
    end
    local raw = Workspace:GetAttribute("DevPasses")
    if typeof(raw) ~= "string" then
        return
    end
    local any = false
    for key in string.gmatch(raw, "[%w_]+") do
        any = set(player, key, true) or any
    end
    if any then
        changed(player)
    end
end

function PassService.Init(d: Deps)
    deps = d
    local function onLoaded(player: Player)
        devAttribute(player)
        task.spawn(verify, player)
    end
    DataService.ProfileLoaded:Connect(onLoaded)
    for _, player in Players:GetPlayers() do
        if DataService.Get(player) ~= nil then
            onLoaded(player)
        end
    end

    -- Cumparat chiar acum, in joc: efectul se vede pe loc. (Pass-urile NU trec prin ProcessReceipt: detinerea e a
    -- Roblox-ului, noi doar reactionam -- nota 27.)
    MarketplaceService.PromptGamePassPurchaseFinished:Connect(
        function(player: Player, passId: number, wasPurchased: boolean)
            if not wasPurchased then
                return
            end
            local key = MonetizationConfig.keyOf(game.GameId, "pass", passId)
            if key == nil then
                return
            end
            if set(player, key, true) then
                firstStep(player, "FirstPassBought")
                changed(player)
            end
            local onGranted = deps.OnGranted
            if onGranted ~= nil then
                onGranted(player, key)
            end
        end
    )
end

return PassService
