--!strict
-- [D61] GHERETELE DE JOC, pe server. Clientul joaca si trimite doar clipele in care a apasat; serverul a dat samanta,
-- stie de cand a inceput jocul si socoteste scorul cu aceleasi functii ca desenul (BoothMath). Premiul se da doar la
-- primele BoothMath.PRIZE_GAMES jocuri din ziua UTC, la un loc pentru ambele gherete; jocurile de dupa sunt de placere,
-- iar panoul o spune dinainte [D43, D40].
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local BoothMath = require(ReplicatedStorage.Shared.Modules.BoothMath)
local FairLayout = require(ReplicatedStorage.Shared.Modules.FairLayout)
local TitleMath = require(ReplicatedStorage.Shared.Modules.TitleMath)

local Analytics = require(script.Parent.Analytics)
local DataService = require(script.Parent.DataService)
local EconomyService = require(script.Parent.EconomyService)

local BoothService = {}

export type Deps = {
    PushState: (Player) -> (), -- perlele, jocurile cu premiu ramase si titlurile
    PositionOf: (Player) -> (number?, number?), -- din PresenceService
}

type Running = { game: string, seed: number, startedAt: number }

local NEAR = 150 -- cat de aproape de gheretă (baza ei) trebuie sa fii ca sa incepi
local deps: Deps? = nil
local running: { [Player]: Running } = {}
local counter = 0

local function boothOf(data: any): { day: number, prizeGames: number, perfect: number }
    if typeof(data.Fair) ~= "table" then
        data.Fair = { firstVisit = 0, visits = 0 }
    end
    if typeof(data.Fair.booth) ~= "table" then
        data.Fair.booth = { day = 0, prizeGames = 0, perfect = 0 }
    end
    local b = data.Fair.booth
    -- o zi noua: jocurile cu premiu o iau de la capat
    local today = BoothMath.dayKey(os.time())
    if b.day ~= today then
        b.day = today
        b.prizeGames = 0
    end
    return b
end

local function nearBooth(player: Player, game: string): boolean
    local d = deps
    if d == nil then
        return false
    end
    local px, py = d.PositionOf(player)
    if px == nil or py == nil then
        return false
    end
    for _, booth in FairLayout.BOOTHS do
        if booth.game == game then
            for _, spot in FairLayout.SPOTS do
                if spot.id == booth.spot then
                    return math.sqrt((px - spot.x) ^ 2 + (py - spot.y) ^ 2) <= NEAR
                end
            end
        end
    end
    return false
end

export type Snapshot = { left: number, perfect: number }

-- Cate jocuri cu premiu mai ai azi si cate jocuri perfecte ai (pentru panou si pentru titlu).
function BoothService.Snapshot(player: Player): Snapshot
    local data = DataService.Get(player)
    if data == nil then
        return { left = BoothMath.PRIZE_GAMES, perfect = 0 }
    end
    local b = boothOf(data)
    return { left = math.max(0, BoothMath.PRIZE_GAMES - b.prizeGames), perfect = b.perfect }
end

-- Intoarce (reusit, motiv, samanta, jocuri cu premiu ramase azi).
function BoothService.Start(player: Player, game: string): (boolean, string, number?, number?)
    if BoothMath.GAMES[game] == nil then
        return false, "unknown", nil, nil
    end
    local data = DataService.Get(player)
    if data == nil then
        return false, "no_profile", nil, nil
    end
    if not nearBooth(player, game) then
        return false, "too_far", nil, nil
    end
    counter += 1
    local seed = (player.UserId * 2654435761 + os.time() * 97 + counter * 40503) % 4294967296
    running[player] = { game = game, seed = seed, startedAt = os.clock() }
    local b = boothOf(data)
    return true, "ok", seed, math.max(0, BoothMath.PRIZE_GAMES - b.prizeGames)
end

-- Intoarce (reusit, motiv, rezultat). Jocul se consuma inainte de orice socoteala: un pachet trimis de doua ori nu
-- plateste de doua ori.
function BoothService.Finish(
    player: Player,
    presses: unknown
): (boolean, string, { [string]: any }?)
    local g = running[player]
    if g == nil then
        return false, "no_game", nil
    end
    running[player] = nil
    local elapsed = os.clock() - g.startedAt
    if not BoothMath.valid(g.game, presses, elapsed) then
        return false, "invalid", nil
    end
    local data = DataService.Get(player)
    if data == nil then
        return false, "no_profile", nil
    end
    -- doar aruncarile verificate (1..throws): o cheie in plus trimisa de client nu ajunge la scor
    local clean = table.move(presses :: { number }, 1, BoothMath.GAMES[g.game].throws, 1, {})
    local score, results = BoothMath.score(g.game, g.seed, clean)
    local b = boothOf(data)
    local prize = 0
    local prizeGame = b.prizeGames < BoothMath.PRIZE_GAMES
    if prizeGame then
        b.prizeGames += 1
        prize = BoothMath.prize(g.game, score)
        if prize > 0 then
            EconomyService.AddPearls(player, prize, "booth")
        end
    end
    local perfect = BoothMath.perfect(g.game, score)
    local title = false
    if perfect then
        b.perfect += 1
        title = b.perfect == TitleMath.PERFECT_GAMES
    end
    if not data.Firsts.FirstBoothGame then
        data.Firsts.FirstBoothGame = true
        Analytics.FairStep(player, "FirstBoothGame")
    end
    local d = deps
    if d ~= nil then
        d.PushState(player)
    end
    return true,
        "ok",
        {
            game = g.game,
            score = score,
            results = results,
            prize = prize,
            prizeGame = prizeGame,
            left = math.max(0, BoothMath.PRIZE_GAMES - b.prizeGames),
            perfect = perfect,
            title = title,
        }
end

function BoothService.Init(d: Deps)
    deps = d
    Players.PlayerRemoving:Connect(function(player: Player)
        running[player] = nil
    end)
end

return BoothService
