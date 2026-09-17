--!strict
-- [D61] CONCURSUL DE LA IAZ, pe server. Runda merge dupa ora serverului (PondMath), la fel pe toate serverele. Aici se
-- tine minte cel mai mare peste al fiecaruia din runda (in memorie: o runda tine 4 minute), se dau premiile cand se
-- termina pescuitul si se trimite tabla tuturor.
--
-- Pestii vin din FishService (OnLanded), aceiasi ca la pontonul din sat: perlele lor, jurnalul si recordurile se
-- socotesc acolo. Aici e doar concursul. Premiul il ia cine e in balci cand se termina runda (scrie pe tabla); cine
-- pleaca dispare de pe tabla, ca sa nu para ca a castigat cineva care nu mai e aici.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local FairLayout = require(ReplicatedStorage.Shared.Modules.FairLayout)
local FishConfig = require(ReplicatedStorage.Shared.Config.FishConfig)
local PondMath = require(ReplicatedStorage.Shared.Modules.PondMath)
local TitleMath = require(ReplicatedStorage.Shared.Modules.TitleMath)

local Analytics = require(script.Parent.Analytics)
local DataService = require(script.Parent.DataService)
local EconomyService = require(script.Parent.EconomyService)

local PondService = {}

export type Deps = {
    Push: (Player?, { [string]: any }) -> (), -- tabla: la un om, sau la toti (nil)
    Result: (Player, { [string]: any }) -> (), -- rezultatul tau, la sfarsitul rundei
    PushState: (Player) -> (), -- perlele si titlurile, dupa premiu
    PositionOf: (Player) -> (number?, number?), -- din PresenceService
    Now: (() -> number)?, -- ora serverului (implicit os.time)
}

type Last = { index: number, podium: { PondMath.Catch }, count: number }

local TICK = 0.5
local deps: Deps? = nil
local round: PondMath.Round? = nil
local best: { [number]: PondMath.Catch } = {}
local last: Last? = nil
local settledId = -1 -- ultima runda careia i s-au dat premiile

local function now(): number
    local d = deps
    local clock = if d ~= nil then d.Now else nil
    return if clock ~= nil then clock() else os.time()
end

local function pondOf(data: any): { wins: number, rounds: number }
    if typeof(data.Fair) ~= "table" then
        data.Fair = { firstVisit = 0, visits = 0 }
    end
    if typeof(data.Fair.pond) ~= "table" then
        data.Fair.pond = { wins = 0, rounds = 0 }
    end
    return data.Fair.pond
end

local function row(c: PondMath.Catch): { [string]: any }
    return { userId = c.userId, name = c.name, species = c.species, cm = c.cm }
end

-- Tabla, asa cum o vede oricine: runda, clasamentul ei si podiumul rundei trecute.
local function view(): { [string]: any }
    local r = round :: PondMath.Round
    local ranked = {}
    for _, c in PondMath.rank(best) do
        table.insert(ranked, row(c))
    end
    local lastView = nil
    local l = last
    if l ~= nil then
        local podium = {}
        for _, c in l.podium do
            table.insert(podium, row(c))
        end
        lastView = { index = l.index, podium = podium, count = l.count }
    end
    return {
        round = {
            id = r.id,
            index = r.index,
            phase = r.phase,
            fishingEndsAt = r.fishingEndsAt,
            nextAt = r.nextAt,
        },
        ranked = ranked,
        last = lastView,
    }
end

local function broadcast()
    local d = deps
    if d == nil or round == nil then
        return
    end
    d.Push(nil, view())
end

-- Sfarsitul pescuitului: premiile, rundele din profil, rezultatul fiecaruia si podiumul pe tabla.
local function settle(r: PondMath.Round)
    local d = deps
    if d == nil or settledId == r.id then
        return
    end
    settledId = r.id
    local ranked = PondMath.rank(best)
    best = {}
    if #ranked == 0 then
        return -- nimeni n-a prins nimic: tabla pastreaza podiumul de dinainte
    end
    local prizes = PondMath.prizes(ranked)
    local contest = #ranked >= PondMath.MIN_RIVALS
    for i, c in ranked do
        local player = Players:GetPlayerByUserId(c.userId)
        local data = if player ~= nil then DataService.Get(player) else nil
        if player == nil or data == nil then
            continue
        end
        local prize = prizes[i]
        EconomyService.AddPearls(player, prize, "pond")
        local pond = pondOf(data)
        pond.rounds += 1
        local won = contest and i == 1
        if won then
            pond.wins += 1
        end
        if not data.Firsts.FirstPondRound then
            data.Firsts.FirstPondRound = true
            Analytics.FairStep(player, "FirstPondRound")
        end
        d.Result(player, {
            index = r.index,
            place = i,
            count = #ranked,
            prize = prize,
            contest = contest,
            won = won,
            wins = pond.wins,
            -- titlul se castiga exact la pragul lui: o singura data, cu mesajul lui
            title = won and pond.wins == TitleMath.POND_WINS,
        })
        d.PushState(player)
    end
    local podium = {}
    for i = 1, math.min(3, #ranked) do
        podium[i] = ranked[i]
    end
    last = { index = r.index, podium = podium, count = #ranked }
end

local function tick()
    local r = PondMath.roundAt(now())
    local prev = round
    round = r
    if prev == nil then
        if r.phase == "results" then
            settledId = r.id -- pornit in pauza: nimic de impartit
        end
        broadcast()
        return
    end
    if prev.id ~= r.id then
        -- runda trecuta s-a terminat fara sa-i fi vazut pauza (server oprit o clipa): premiile ei tot se dau
        settle(prev)
        best = {}
        broadcast()
    elseif prev.phase ~= r.phase then
        settle(r)
        broadcast()
    end
end

-- Arunci de pe jetiu? Pozitia e cea din pachetele de miscare, cu toleranta pentru ultimul pas.
function PondService.CanCast(player: Player): boolean
    local d = deps
    if d == nil then
        return false
    end
    local x, y = d.PositionOf(player)
    if x == nil or y == nil then
        return false
    end
    return FairLayout.inRect(FairLayout.CAST_ZONE, x, y, FairLayout.CAST_TOLERANCE)
end

-- O aruncare primita la iaz (pentru palnia balciului).
function PondService.Cast(player: Player)
    local data = DataService.Get(player)
    if data ~= nil and not data.Firsts.FirstPondCast then
        data.Firsts.FirstPondCast = true
        Analytics.FairStep(player, "FirstPondCast")
    end
end

-- Un peste scos la iaz (FishService.OnLanded). Intra in concurs doar cat se pescuieste.
function PondService.Landed(player: Player, speciesId: string, cm: number)
    local r = round
    local def = FishConfig.byId[speciesId]
    if r == nil or r.phase ~= "fishing" or def == nil or not math.isfinite(cm) then
        return
    end
    local changed = PondMath.record(best, {
        userId = player.UserId,
        name = player.DisplayName,
        species = def.name,
        cm = cm,
        at = os.clock(),
    })
    if changed then
        broadcast()
    end
end

-- Cine intra (sau cere starea) primeste tabla.
function PondService.SendTo(player: Player)
    local d = deps
    if d ~= nil and round ~= nil then
        d.Push(player, view())
    end
end

function PondService.Init(d: Deps)
    deps = d
    tick()
    local acc = 0
    RunService.Heartbeat:Connect(function(dt: number)
        acc += dt
        if acc >= TICK then
            acc = 0
            tick()
        end
    end)
    Players.PlayerRemoving:Connect(function(player: Player)
        if best[player.UserId] ~= nil then
            best[player.UserId] = nil
            broadcast()
        end
    end)
end

return PondService
