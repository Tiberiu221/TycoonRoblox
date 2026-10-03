--!strict
-- [D61, partea 2] PRODUSELE PE ROBUX (montat in ambele place-uri): singurul `MarketplaceService.ProcessReceipt` al
-- place-ului. Un singur script are voie sa-l seteze (ultima atribuire castiga), deci TOATE produsele trec pe aici.
--
-- Contractul (nota 27, documentatia ProfileStore, capitolul "Developer Products"):
--   * o chitanta se onoreaza O SINGURA DATA: PurchaseId-ul ei intra in `Purchases.ids` din profil (ultimele 100);
--   * `PurchaseGranted` se intoarce abia cand `LastSavedData` -- ce a ajuns sigur in DataStore -- contine chitanta.
--     Altfel, la o cadere de server intre acordare si salvare, Roblox ar crede chitanta onorata, iar profilul n-ar avea
--     nici monedele, nici semnul ca le-a primit;
--   * orice altceva intoarce `NotProcessedYet`: Roblox retrimite chitanta la urmatoarea intrare a jucatorului, pe orice
--     server al jocului -- fie el al satului sau al balciului. De aceea fiecare produs se poate onora in ambele place-uri.
--
-- Ce se vinde (MonetizationConfig): monede cat o ora din venitul tau (`hour`) si inca o data suma de la revenire
-- (`welcome2x`). Pass-urile NU trec pe aici (PassService).
--
-- Fereastra de cumparare o deschide SERVERUL (remote `ShopBuy`), nu clientul: asa se vede aici ce s-a cerut, cu limita
-- de rata, iar un produs fara rost acum (nimic de dublat) nici nu ajunge la fereastra Roblox.
local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local MonetizationConfig = require(ReplicatedStorage.Shared.Config.MonetizationConfig)
local PassMath = require(ReplicatedStorage.Shared.Modules.PassMath)

local Analytics = require(script.Parent.Analytics)
local DataService = require(script.Parent.DataService)
local EconomyService = require(script.Parent.EconomyService)

local PurchaseService = {}

export type Deps = {
    -- venitul tau de acum, in monede pe secunda. In sat vine din lant (StationService.Income); in balci, din ultima
    -- cifra masurata in sat (Records.incomePerSec), ca o chitanta retrimisa acolo sa nu ramana neonorata.
    Income: (Player) -> number,
    PushState: ((Player) -> ())?,
    -- bannerul de dupa cumparare: cheia lucrului si cate monede a adus
    OnGranted: ((Player, string, number) -> ())?,
    -- are jucatorul deja pass-ul asta? (PassService.Has)
    HasPass: (Player, string) -> boolean,
}
local deps: Deps? = nil

local SAVE_RETRY_SECONDS = 10

local function purchasesOf(data: any): { ids: { string }, passes: { [string]: boolean } }
    if typeof(data.Purchases) ~= "table" then
        data.Purchases = { ids = {}, passes = {} }
    end
    if typeof(data.Purchases.ids) ~= "table" then
        data.Purchases.ids = {}
    end
    return data.Purchases
end

-- Cate monede aduce un produs ACUM. Aceeasi cifra scrie si pe buton (Quote), deci ce vezi e ce primesti [D40].
local function coinsFor(player: Player, key: string): number
    local d = deps :: Deps
    local data = DataService.Get(player)
    if key == "hour" then
        return PassMath.hourOfFlow(d.Income(player))
    elseif key == "welcome2x" then
        local last = if data ~= nil then data.Meta.lastWelcome else 0
        return PassMath.welcomeDouble(last, d.Income(player))
    end
    return 0
end

-- Ce ar aduce fiecare produs daca l-ai cumpara acum (pentru butoane). `welcome2x` = 0 cand nu e nimic de dublat.
function PurchaseService.Quote(player: Player): { [string]: number }
    local data = DataService.Get(player)
    if deps == nil or data == nil then
        return {}
    end
    local last = data.Meta.lastWelcome
    return {
        hour = coinsFor(player, "hour"),
        welcome2x = if typeof(last) == "number" and last >= 1 then math.floor(last) else 0,
    }
end

-- Acordarea propriu-zisa. Arunca eroare daca nu se poate (profilul a plecat): chitanta ramane neonorata si se retrimite.
local function grant(player: Player, key: string): number
    local data = DataService.Get(player)
    assert(data ~= nil, "profil lipsa")
    local coins = coinsFor(player, key)
    assert(coins > 0, `produs necunoscut: {key}`)
    EconomyService.AddCoins(player, coins, `robux_{key}`)
    -- [D70, pasul j5] R: monedele cumparate trec intregi peste suma de start a barajului (D74, punctul 8)
    data.Purchases.coinsBought = PassMath.afterGrant(data.Purchases.coinsBought, coins)
    if key == "welcome2x" then
        data.Meta.lastWelcome = 0 -- o data pentru fiecare revenire
    end
    if not data.Firsts.FirstProductBought then
        data.Firsts.FirstProductBought = true
        Analytics.ShopStep(player, "FirstProductBought")
    end
    Analytics.CoinsBought(player, coins, EconomyService.GetCoins(player), key)
    return coins
end

local function processReceipt(receipt: { [string]: any }): Enum.ProductPurchaseDecision
    local d = deps
    local player = Players:GetPlayerByUserId(receipt.PlayerId)
    if d == nil or player == nil then
        return Enum.ProductPurchaseDecision.NotProcessedYet -- nu mai e aici: Roblox retrimite la urmatoarea intrare
    end
    local key = MonetizationConfig.keyOf(game.GameId, "product", receipt.ProductId)
    if key == nil then
        warn(`[Purchase] chitanta pentru un produs necunoscut: {receipt.ProductId}`)
        return Enum.ProductPurchaseDecision.NotProcessedYet
    end
    local purchaseId = tostring(receipt.PurchaseId)

    -- profilul poate inca sa se incarce (chitanta retrimisa vine chiar la intrare): asteptam putin, nu la nesfarsit
    local profile = DataService.Profile(player)
    local waited = 0
    while profile == nil and player.Parent == Players and waited < 30 do
        task.wait(1)
        waited += 1
        profile = DataService.Profile(player)
    end
    if profile == nil or not profile:IsActive() then
        return Enum.ProductPurchaseDecision.NotProcessedYet
    end

    local purchases = purchasesOf(profile.Data)
    if not PassMath.hasReceipt(purchases.ids, purchaseId) then
        local ok, result = pcall(grant, player, key)
        if not ok then
            warn(`[Purchase] nu am putut onora {key} ({purchaseId}): {result}`)
            return Enum.ProductPurchaseDecision.NotProcessedYet
        end
        PassMath.rememberReceipt(purchases.ids, purchaseId)
        local push = d.PushState
        if push ~= nil then
            push(player)
        end
        local onGranted = d.OnGranted
        if onGranted ~= nil then
            onGranted(player, key, result :: number)
        end
    end

    -- confirmam abia cand chitanta a ajuns sigur in DataStore
    local function saved(): boolean
        local last = profile.LastSavedData
        local lastPurchases = if typeof(last) == "table" then last.Purchases else nil
        return typeof(lastPurchases) == "table"
            and PassMath.hasReceipt(lastPurchases.ids, purchaseId)
    end
    if saved() then
        return Enum.ProductPurchaseDecision.PurchaseGranted
    end
    while profile:IsActive() do
        local before = profile.LastSavedData
        profile:Save()
        if profile.LastSavedData == before then
            profile.OnAfterSave:Wait()
        end
        if saved() then
            return Enum.ProductPurchaseDecision.PurchaseGranted
        end
        if profile:IsActive() then
            task.wait(SAVE_RETRY_SECONDS)
        end
    end
    return Enum.ProductPurchaseDecision.NotProcessedYet
end

-- Clientul cere fereastra de cumparare pentru un lucru din catalog. "soon" = inca necreat pe universul asta;
-- "owned" = pass-ul e deja al tau; "nothing" = Welcome Back x2 fara nimic de dublat; "unknown" | "no_profile".
function PurchaseService.Prompt(player: Player, key: string): (boolean, string)
    local d = deps
    local item = MonetizationConfig.byKey[key]
    local data = DataService.Get(player)
    if d == nil or data == nil then
        return false, "no_profile"
    end
    if item == nil then
        return false, "unknown"
    end
    local id = MonetizationConfig.idOf(game.GameId, key)
    if id == 0 then
        return false, "soon"
    end
    if item.kind == "pass" then
        if d.HasPass(player, key) then
            return false, "owned"
        end
    elseif key == "welcome2x" and not (data.Meta.lastWelcome >= 1) then
        return false, "nothing"
    end
    if not data.Firsts.FirstShopPrompt then
        data.Firsts.FirstShopPrompt = true
        Analytics.ShopStep(player, "FirstShopPrompt")
    end
    local ok, err = pcall(function()
        if item.kind == "pass" then
            MarketplaceService:PromptGamePassPurchase(player, id)
        else
            MarketplaceService:PromptProductPurchase(player, id)
        end
    end)
    if not ok then
        warn(`[Purchase] fereastra de cumparare nu s-a deschis pentru {key}: {err}`)
        return false, "failed"
    end
    return true, "ok"
end

-- [Studio] un produs de proba, fara Robux: aceeasi acordare, fara chitanta.
function PurchaseService.DevGrant(player: Player, key: string): number?
    local item = MonetizationConfig.byKey[key]
    if
        not RunService:IsStudio()
        or deps == nil
        or item == nil
        or item.kind ~= "product"
        or DataService.Get(player) == nil
    then
        return nil
    end
    local ok, coins = pcall(grant, player, key)
    return if ok then coins :: number else nil
end

function PurchaseService.Init(d: Deps)
    deps = d
    MarketplaceService.ProcessReceipt = processReceipt
end

return PurchaseService
