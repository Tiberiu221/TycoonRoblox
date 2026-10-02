--!strict
-- [D62, pasul 3] DARURILE RAULUI, pe server. Programul e in DriftMath (determinist pe samanta raului si fereastra de
-- timp), deci serverul nu "lanseaza" nimic si nu tine nicio lista: cand clientul spune "am scos darul ferestrei N",
-- serverul reface darul acela si verifica:
--   * MOMENTUL -- darul chiar trece acum prin dreptul puntii (cu o mica ingaduinta pentru drumul cererii);
--   * O SINGURA DATA -- fereastra e mai noua decat ultima scoasa (`Stats.lastDrift`, in profil: nici o reintrare, nici
--     alt server -- toate au acelasi program -- nu-l mai dau o data);
--   * RATA (RateLimiter, in NetServer).
-- Pozitia ta NU se verifica: in sat serverul nu stie unde stai nici la cules, nici la predat. Cine trimite cererea fara
-- sa alerge castiga cel mult cat unul care le prinde pe toate (~30% venit), in propriul lui sat.
--
-- Plata: secunde din venitul tau de ACUM (StationService.Income, cu tot cu 2x Flow), cu minimul felului.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local DriftMath = require(ReplicatedStorage.Shared.Modules.DriftMath)
local TycoonConfig = require(ReplicatedStorage.Shared.Config.TycoonConfig)

local DataService = require(script.Parent.DataService)
local EconomyService = require(script.Parent.EconomyService)

local DriftService = {}

export type Deps = {
    Seed: () -> number, -- samanta raului (RiverService), aceeasi pe care o are clientul
    Now: () -> number, -- ceasul serverului (RiverService.Now)
    Income: (Player) -> number, -- venitul de acum, monede pe secunda
    PushState: ((Player) -> ())?,
}
local deps: Deps? = nil

-- [D73] Puntile cartierelor deschise ale jucatorului (si in joc): de pe oricare se poate scoate darul care trece.
local function reachesOf(data: any): { DriftMath.Span }
    return DriftMath.reaches(TycoonConfig.deckSpans(), function(era: number): boolean
        if not TycoonConfig.eraIsLive(era) then
            return false
        end
        local bell = TycoonConfig.bellOf(era - 1)
        return era == 1 or (bell ~= nil and data.Pads[bell.id] == true)
    end)
end

-- "no_profile" | "bad_id" | "taken" (l-ai scos deja) | "gone" (nu mai e in dreptul puntii) | "ok"
function DriftService.Grab(player: Player, giftId: number): (boolean, string, string?, number?)
    local d = deps
    local data = DataService.Get(player)
    if d == nil or data == nil then
        return false, "no_profile", nil, nil
    end
    local now = d.Now()
    local current = DriftMath.windowOf(now)
    -- doar darul ferestrei de acum sau al celei dinainte poate fi pe harta
    if giftId ~= current and giftId ~= current - 1 then
        return false, "bad_id", nil, nil
    end
    local stats = data.Stats
    local last = if typeof(stats.lastDrift) == "number" then stats.lastDrift else 0
    if giftId <= last then
        return false, "taken", nil, nil
    end
    local gift = DriftMath.giftFor(d.Seed(), giftId)
    if not DriftMath.canGrab(gift, now, reachesOf(data)) then
        return false, "gone", nil, nil
    end
    local coins = DriftMath.reward(gift.kind, d.Income(player))
    stats.lastDrift = giftId
    stats.drifts = (if typeof(stats.drifts) == "number" then stats.drifts else 0) + 1
    EconomyService.AddCoins(player, coins, "drift")
    local push = d.PushState
    if push ~= nil then
        push(player)
    end
    return true, "ok", gift.kind, coins
end

function DriftService.Init(d: Deps)
    deps = d
end

return DriftService
