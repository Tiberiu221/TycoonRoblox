--!strict
-- [D60] CLASAMENTELE BALCIULUI, scrise din SAT (acolo se intampla lucrurile); balciul doar le citeste (BoardService).
-- Trei clasamente SAPTAMANALE, care incep din nou lunea (BoardMath.weekKey), ca sa poata castiga si cineva nou:
--   * cel mai mare peste: OrderedDataStore FairFish_<saptamana>, in milimetri; specia sta alaturi (FairFishSpecies_);
--   * cel mai mare venit pe secunda: FairIncome_<saptamana>, in sutimi, esantionat o data pe minut;
--   * cel mai scurt drum pana la clopotul Erei 1: FairEra1_<saptamana>, secunde de joc efectiv (Stats.playSeconds).
-- Recordul fiecarei specii, de cand e jocul, sta in FairFishRecords (o cheie pe specie): trofeele din fata scenei.
--
-- Bugetul DataStore: se scrie DOAR la un record nou (al tau, pe saptamana), iar venitul cel mult o data pe minut.
-- Play-ul din Studio pornit de la zero (store Mock) nu scrie nimic: tabelele raman ale jocului, nu ale testelor.
local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local BoardMath = require(ReplicatedStorage.Shared.Modules.BoardMath)
local FishConfig = require(ReplicatedStorage.Shared.Config.FishConfig)

local DataService = require(script.Parent.DataService)

local LeaderboardService = {}

LeaderboardService.STORES = {
    fish = "FairFish_",
    fishSpecies = "FairFishSpecies_",
    income = "FairIncome_",
    era1 = "FairEra1_",
    records = "FairFishRecords",
}
local INCOME_EVERY = 60

local deps: { Income: ((Player) -> number)? } = { Income = nil }
-- cel mai mare venit trimis in saptamana asta, pe jucator (store-ul pastreaza oricum maximul)
local incomeSent: { [Player]: { week: string, value: number } } = {}

local function canWrite(player: Player): boolean
    return DataService.StudioSave(player) ~= "fresh"
end

local function recordsOf(data: any)
    if typeof(data.Records) ~= "table" then
        data.Records = { era1Seconds = 0, incomePerSec = 0, weeklyFishMm = 0, weeklyFishWeek = "" }
    end
    return data.Records
end

-- Scrie `value` doar daca e mai bun decat ce e deja in store (acelasi jucator poate juca pe doua servere).
local function keepBest(storeName: string, key: string, value: number, lowerIsBetter: boolean)
    task.spawn(function()
        local ok, err = pcall(function()
            DataStoreService:GetOrderedDataStore(storeName):UpdateAsync(key, function(old: number?)
                if old ~= nil and (if lowerIsBetter then old <= value else old >= value) then
                    return nil -- nimic de schimbat
                end
                return value
            end)
        end)
        if not ok then
            warn(`[Leaderboard] {storeName} n-a putut fi scris: {err}`)
        end
    end)
end

-- Un peste scos la undita (FishService). `cm` e marimea lui.
function LeaderboardService.FishLanded(player: Player, speciesId: string, cm: number)
    local data = DataService.Get(player)
    local species = FishConfig.byId[speciesId]
    if data == nil or species == nil or not math.isfinite(cm) or cm <= 0 then
        return
    end
    local records = recordsOf(data)
    local week = BoardMath.weekKey(os.time())
    if records.weeklyFishWeek ~= week then
        records.weeklyFishWeek = week
        records.weeklyFishMm = 0
    end
    local mm = math.floor(cm * 10)
    if mm <= records.weeklyFishMm or not canWrite(player) then
        return
    end
    records.weeklyFishMm = mm
    local key = tostring(player.UserId)
    keepBest(LeaderboardService.STORES.fish .. week, key, mm, false)
    task.spawn(function()
        pcall(function()
            DataStoreService:GetDataStore(LeaderboardService.STORES.fishSpecies .. week)
                :SetAsync(key, species.name)
        end)
    end)
    -- trofeul speciei: cel mai mare exemplar prins vreodata, cu numele celui care l-a prins
    task.spawn(function()
        local ok, err = pcall(function()
            DataStoreService:GetDataStore(LeaderboardService.STORES.records)
                :UpdateAsync(speciesId, function(old: any)
                    if typeof(old) == "table" and typeof(old.mm) == "number" and old.mm >= mm then
                        return nil
                    end
                    return { mm = mm, userId = player.UserId, name = player.DisplayName }
                end)
        end)
        if not ok then
            warn(`[Leaderboard] recordul pentru {speciesId} n-a putut fi scris: {err}`)
        end
    end)
end

-- Clopotul Erei 1 a sunat (o cumparare adevarata, nu unealta de dezvoltare): timpul de joc de pana acum intra pe tabela.
function LeaderboardService.EraBell(player: Player, padId: string)
    if padId ~= "landing_bell" then
        return
    end
    local data = DataService.Get(player)
    if data == nil then
        return
    end
    local records = recordsOf(data)
    if records.era1Seconds > 0 then
        return -- prima data conteaza
    end
    local seconds = math.max(1, DataService.PlaySeconds(player))
    records.era1Seconds = seconds
    if canWrite(player) then
        keepBest(
            LeaderboardService.STORES.era1 .. BoardMath.weekKey(os.time()),
            tostring(player.UserId),
            seconds,
            true
        )
    end
end

-- Venitul de acum: pe card (Records.incomePerSec) si, daca e un maxim al saptamanii, pe tabela. Se cheama din minut in
-- minut si cand urci in barca (cat profilul e inca aici), ca ceilalti sa vada venitul cu care ai plecat.
function LeaderboardService.SampleIncome(player: Player)
    local data = DataService.Get(player)
    local income = deps.Income
    if data == nil or income == nil then
        return
    end
    local value = math.floor(math.max(0, income(player)) * 100)
    recordsOf(data).incomePerSec = value -- cardul din balci arata ultimul venit masurat
    if value <= 0 or not canWrite(player) then
        return
    end
    local week = BoardMath.weekKey(os.time())
    local sent = incomeSent[player]
    if sent ~= nil and sent.week == week and sent.value >= value then
        return
    end
    incomeSent[player] = { week = week, value = value }
    keepBest(LeaderboardService.STORES.income .. week, tostring(player.UserId), value, false)
end

function LeaderboardService.Init(d: typeof(deps))
    deps = d
    Players.PlayerRemoving:Connect(function(player: Player)
        incomeSent[player] = nil
    end)
    task.spawn(function()
        while true do
            task.wait(INCOME_EVERY)
            for _, player in Players:GetPlayers() do
                LeaderboardService.SampleIncome(player)
            end
        end
    end)
end

return LeaderboardService
