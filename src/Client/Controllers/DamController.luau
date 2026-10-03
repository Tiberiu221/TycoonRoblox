--!strict
-- [D70, pasul j15] BARAJUL, pe client: cererile catre DamService si raspunsurile lui. Ecranul „Build the Dam” (k7), filmul
-- (k9) si reincarcarea in lumea 2 (k8) se asaza peste el; pana atunci, cine cere (masa Dam Plans, k6) primeste chitanta, iar
-- orice refuz sau ridicare se spune intr-un toast [D43]. Chitanta se copiaza camp cu camp (CLAUDE.md, capcana 3).
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Strings = require(ReplicatedStorage.Shared.Config.Strings)
local Theme = require(script.Parent.Parent.UI.Theme)

local DamController = {}

export type Veteran =
    { key: string, role: string, name: string, formerRole: string?, medal: number? }
export type Receipt = {
    lastCart: number,
    pieces: number,
    questPearls: number,
    questsClosed: number,
    coinsBefore: number,
    kept: number,
    start: number,
    coinsAfter: number,
    gift: number,
    topUp: number,
    incomeBefore: number,
    incomeAfter: number,
    veterans: { Veteran },
    retired: number,
}

export type Deps = {
    Remotes: {
        DamPreview: RemoteEvent,
        DamPreviewResult: RemoteEvent,
        BuildDam: RemoteEvent,
        DamBuilt: RemoteEvent,
        DamRejected: RemoteEvent,
        DamFilmSeen: RemoteEvent,
        DamReloadFailed: RemoteEvent, -- [D70, pasul k8]
        DamCardSeen: RemoteEvent, -- [verificatorul k9-k10a]
    },
    OnToast: (string, Color3?) -> (),
    -- cine asculta (ecranul, k7): chitanta noua sau motivul; ridicarea gata
    OnPreview: ((Receipt?, string?) -> ())?,
    OnBuilt: ((Receipt) -> ())?,
    -- [D70, pasul k7] ecranul spune refuzul unei ridicari pe randul lui (altfel, un toast)
    OnRejected: ((string) -> ())?,
    -- [D70, pasul k8] reincarcarea in lumea 2 n-a plecat (motivele barcii)
    OnReloadFailed: ((string) -> ())?,
}
local deps: Deps? = nil
local lastPreview: Receipt? = nil

local function num(x: any): number
    return if typeof(x) == "number" and x == x then x else 0
end

local function copyReceipt(raw: any): Receipt?
    if typeof(raw) ~= "table" then
        return nil
    end
    local veterans: { Veteran } = {}
    if typeof(raw.veterans) == "table" then
        for i, v in raw.veterans do
            if typeof(v) == "table" then
                veterans[i] = {
                    key = tostring(v.key),
                    role = tostring(v.role),
                    name = tostring(v.name),
                    formerRole = if typeof(v.formerRole) == "string" then v.formerRole else nil,
                    medal = if typeof(v.medal) == "number" then v.medal else nil,
                }
            end
        end
    end
    return {
        lastCart = num(raw.lastCart),
        pieces = num(raw.pieces),
        questPearls = num(raw.questPearls),
        questsClosed = num(raw.questsClosed),
        coinsBefore = num(raw.coinsBefore),
        kept = num(raw.kept),
        start = num(raw.start),
        coinsAfter = num(raw.coinsAfter),
        gift = num(raw.gift),
        topUp = num(raw.topUp),
        incomeBefore = num(raw.incomeBefore),
        incomeAfter = num(raw.incomeAfter),
        veterans = veterans,
        retired = num(raw.retired),
    }
end
DamController.copyReceipt = copyReceipt

-- Ce s-ar intampla acum: raspunsul vine pe OnPreview.
function DamController.RequestPreview()
    local d = deps
    if d ~= nil then
        d.Remotes.DamPreview:FireServer()
    end
end

-- [verificatorul j15] Refuzurile adevarate („bell”, „built”, „changed”, „soon”) in rosu, cele de asteptare in galben;
-- vestea buna ramane aurie.
local WAIT_REASONS: { [string]: boolean } =
    { busy = true, settling = true, no_profile = true, save = true }
local function refuse(d: Deps, reason: string)
    d.OnToast(
        Strings.damRejected(reason),
        if WAIT_REASONS[reason] then Theme.COLOR.warn else Theme.COLOR.bad
    )
end

-- Ridica barajul cu monedele de pe ultima chitanta vazuta. Fara chitanta, intai previzualizarea (ceruta acum).
function DamController.Build(): boolean
    local d = deps
    local seen = lastPreview
    if d == nil then
        return false
    end
    if seen == nil then
        DamController.RequestPreview()
        return false
    end
    d.Remotes.BuildDam:FireServer(seen.coinsAfter)
    return true
end

-- [D70, pasul k8] dupa film (k9; pana atunci, dupa ridicare): serverul noteaza filmul vazut si reincarca jocul in lumea 2.
-- O cerere repetata (dupa un drum care n-a plecat) incearca din nou.
function DamController.FilmSeen()
    local d = deps
    if d ~= nil then
        d.Remotes.DamFilmSeen:FireServer()
    end
end

-- [verificatorul k9-k10a] la baraj: cartonasul „THE DAM” al filmului pierdut s-a vazut (serverul doar il noteaza)
function DamController.CardSeen()
    local d = deps
    if d ~= nil then
        d.Remotes.DamCardSeen:FireServer()
    end
end

function DamController.LastPreview(): Receipt?
    return lastPreview
end

function DamController.Init(d: Deps)
    deps = d
    d.Remotes.DamPreviewResult.OnClientEvent:Connect(function(raw: unknown, reason: unknown)
        local receipt = copyReceipt(raw)
        local why = if typeof(reason) == "string" then reason else nil
        -- o previzualizare refuzata de limita („busy”) nu sterge chitanta buna de dinainte: serverul verifica oricum
        -- „changed” la ridicare [verificatorul j15]
        if receipt ~= nil or why ~= "busy" then
            lastPreview = receipt
        end
        local onPreview = d.OnPreview
        if onPreview ~= nil then
            onPreview(receipt, why)
        elseif receipt == nil then
            refuse(d, why or "busy")
        end
    end)
    d.Remotes.DamRejected.OnClientEvent:Connect(function(reason: unknown)
        local why = if typeof(reason) == "string" then reason else "busy"
        local onRejected = d.OnRejected
        if onRejected ~= nil then
            onRejected(why)
        else
            refuse(d, why)
        end
        -- „changed”: monedele de pe ecran nu mai sunt cele adevarate, deci o chitanta noua. [verificatorul k6-k8] Cea veche
        -- se uita: stiut ca veche, nu mai poate arma butonul (nici dupa un „busy”) si nu mai pleaca la Build
        if reason == "changed" then
            lastPreview = nil
            DamController.RequestPreview()
        end
    end)
    d.Remotes.DamReloadFailed.OnClientEvent:Connect(function(reason: unknown)
        local why = if typeof(reason) == "string" then reason else "failed"
        local onFailed = d.OnReloadFailed
        if onFailed ~= nil then
            onFailed(why)
        else
            d.OnToast(Strings.damReloadFailed(why), Theme.COLOR.warn)
        end
    end)
    d.Remotes.DamBuilt.OnClientEvent:Connect(function(raw: unknown)
        local receipt = copyReceipt(raw)
        lastPreview = nil
        if receipt == nil then
            return
        end
        local onBuilt = d.OnBuilt
        if onBuilt ~= nil then
            onBuilt(receipt)
        else
            d.OnToast(Strings.DAM_BUILT, Theme.COLOR.gold)
        end
    end)
end

return DamController
