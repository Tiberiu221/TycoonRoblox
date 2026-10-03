--!strict
-- [D70, pasul j15] RIDICAREA BARAJULUI, pe server. Socoteala e toata in DamMath (pura, testata); aici sta doar ce cere
-- jucatorul si profilul lui: garzile care tin de sesiune, aplicarea dintr-o bucata, salvarea fortata si raspunsul.
-- Doar in sat (in balci nu se ridica nimic, iar default.project.json e singurul care il monteaza).
--
-- Refuzurile, toate cu motiv [D43], traduse de client (k7): "soon" (Era 4 nu e in joc), "bell" (Works Bell nu e sunat),
-- "built" (e deja ridicat), "settling" (plata de cand ai lipsit inca se face), "changed" (monedele cu care ai porni nu mai
-- sunt cele de pe ecran: o cumparare cu Robux intre timp), "busy" (o ridicare e deja pe drum), "no_profile", "save"
-- (profilul s-a inchis inainte ca salvarea sa ajunga; barajul e ridicat in memorie, iar sesiunea urmatoare o gaseste
-- salvata de ProfileStore la iesire).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local DamMath = require(ReplicatedStorage.Shared.Modules.DamMath)

local Analytics = require(script.Parent.Analytics)
local DataService = require(script.Parent.DataService)
local EconomyService = require(script.Parent.EconomyService)

local DamService = {}

export type Deps = {
    Now: () -> number, -- ceasul raului (RiverService.Now)
    Settled: (Player) -> boolean, -- StationService.Settled: plata de cand ai lipsit e facuta
    Invalidate: (Player) -> (), -- cache-urile starii (PadService si StationService)
    PushState: ((Player) -> ())?,
    -- [D70, pasul k8] reincarcarea in lumea 2 (FerryService.Depart spre acelasi place, cu cartonasul „THE DAM”)
    Reload: ((Player) -> string?)?, -- [verificatorul k6-k8] un motiv cand drumul nu porneste si nu raspunde nimeni
}
local deps: Deps? = nil

-- cine ridica acum (salvarea cedeaza): o a doua cerere in timpul ei primeste "busy", nu o a doua ridicare
local building: { [Player]: boolean } = {}

local function contextFor(player: Player, now: number): DamMath.Context
    return {
        now = now,
        userId = player.UserId,
        valueOfCounts = function(counts)
            return EconomyService.ValueOfCounts(player, counts)
        end,
    }
end

-- [D70, pasul k6] Barajul se poate ridica acum (Era 4 in joc, Works Bell sunat, in sat, inca neridicat): masa Dam Plans
-- devine „Build the Dam”, iar clopotul, lista de quest-uri, zona si fereastra de revenire spun drumul. Aceeasi regula ca la
-- ridicare (DamMath.blocked), deci ecranul nu promite ce serverul ar refuza.
function DamService.Available(player: Player): boolean
    local data = DataService.Get(player)
    return data ~= nil and DamMath.blocked(data) == nil
end

-- Ce s-ar intampla acum: chitanta, sau motivul pentru care nu se poate.
function DamService.Preview(player: Player): (DamMath.Receipt?, string?)
    local d = deps
    local data = DataService.Get(player)
    if d == nil or data == nil then
        return nil, "no_profile"
    end
    local receipt, why = DamMath.preview(data, contextFor(player, d.Now()))
    if receipt ~= nil and not data.Firsts.DamPreviewed then
        data.Firsts.DamPreviewed = true
        Analytics.DamStep(player, "DamPreviewed")
    end
    return receipt, why
end

-- Ridicarea. `expectedKeep` = monedele cu care porneste jucatorul, asa cum le-a vazut pe ecran (chitanta previzualizarii):
-- daca nu mai sunt aceleasi, nu se ridica nimic ("changed"), iar clientul cere o previzualizare noua.
function DamService.Build(player: Player, expectedKeep: number): (DamMath.Receipt?, string?)
    local d = deps
    local data = DataService.Get(player)
    local profile = DataService.Profile(player)
    if d == nil or data == nil or profile == nil then
        return nil, "no_profile"
    end
    if building[player] then
        return nil, "busy"
    end
    if not d.Settled(player) then
        return nil, "settling"
    end
    local ctx = contextFor(player, d.Now())
    local seen, why = DamMath.preview(data, ctx)
    if seen == nil then
        return nil, why
    end
    if not math.isfinite(expectedKeep) or math.abs(seen.coinsAfter - expectedKeep) > 0.5 then
        return nil, "changed"
    end
    -- dintr-o bucata: nimic nu cedeaza intre previzualizare si ridicare
    local receipt = DamMath.build(data, ctx)
    if receipt == nil then
        return nil, "changed"
    end
    d.Invalidate(player)
    player:SetAttribute("World", data.World)
    Analytics.DamStep(player, "DamBuilt") -- o singura data: a doua ridicare e refuzata ("built")
    local push = d.PushState
    if push ~= nil then
        push(player)
    end
    -- abia cand ridicarea a ajuns sigur in DataStore se spune „gata”: urmeaza reincarcarea in lumea 2 (k8)
    building[player] = true
    local world = data.World
    local ok = DataService.SaveNow(profile, function(last: any): boolean
        return typeof(last) == "table" and last.World == world
    end)
    building[player] = nil
    if not ok then
        return nil, "save"
    end
    return receipt, nil
end

-- Filmul s-a vazut (sau s-a sarit): la reincarcare nu mai porneste singur. [D70, pasul k8] Apoi clientul, construit pentru
-- satul vechi, se reincarca in lumea 2: acelasi drum ca barca (salvarea e deja facuta la ridicare). O cerere repetata
-- (dupa un drum care n-a plecat) incearca din nou; cine e deja in lumea 2 cu harta ei nu mai are de ce sa plece.
-- [verificatorul k7-k8] Intoarce motivul cand reincarcarea nu porneste ("no_profile", "not_built", [k6-k8] "busy" cand un drum
-- e deja in curs), ca ecranul sa nu astepte in tacere; nil = drumul a plecat (sau raspunde FerryService prin `onFailed`).
function DamService.FilmSeen(player: Player): string?
    local data = DataService.Get(player)
    if data == nil then
        return "no_profile"
    end
    if data.Firsts.DamBuilt ~= true then
        return "not_built"
    end
    if not data.Firsts.DamFilmSeen then
        data.Firsts.DamFilmSeen = true
        Analytics.DamStep(player, "DamFilmSeen")
    end
    local d = deps
    local reload = if d ~= nil then d.Reload else nil
    -- doar clientul construit pe satul vechi o cere (cel din lumea 2 n-are masa Dam Plans); o cerere in plus il reincarca
    -- doar pe el, cu limita de rata a barajului (NetServer)
    if reload ~= nil and data.World ~= 1 then
        -- nil: drumul a plecat (sau raspunde el prin `onFailed`); "busy": unul e deja in curs, iar cererea asta primeste
        -- raspunsul ei pe loc [verificatorul k6-k8]
        return reload(player)
    end
    return "not_built"
end

-- [verificatorul k9-k10a] Filmul s-a pierdut: barajul e ridicat (si salvat inainte de film), dar jucatorul a iesit din joc
-- in cele 17 s. Clientul lumii 2 arata atunci cartonasul „THE DAM” si cere CardSeen.
function DamService.FilmPending(player: Player): boolean
    local data = DataService.Get(player)
    return data ~= nil and data.Firsts.DamBuilt == true and data.Firsts.DamFilmSeen ~= true
end

-- Cartonasul s-a vazut la baraj: doar noteaza filmul (fara reincarcare: clientul e deja pe harta barajului).
function DamService.CardSeen(player: Player)
    local data = DataService.Get(player)
    if data ~= nil and data.Firsts.DamBuilt == true and not data.Firsts.DamFilmSeen then
        data.Firsts.DamFilmSeen = true
        Analytics.DamStep(player, "DamFilmSeen")
    end
end

function DamService.Init(d: Deps)
    deps = d
    Players.PlayerRemoving:Connect(function(player: Player)
        building[player] = nil
    end)
end

return DamService
