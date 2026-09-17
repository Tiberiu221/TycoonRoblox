--!strict
-- [D60] TABELA DE PE SCENA, citita in balci. Clasamentele le scrie satul (LeaderboardService); aici se citesc:
--   * la pornire si apoi din minut in minut, primii 10 din fiecare clasament al saptamanii (GetSortedAsync);
--   * o data pe ora, campionul: primul la peste saptamana TRECUTA (titlul "Champion of the Week");
--   * la cinci minute, trofeele: recordul fiecarei specii, de cand e jocul.
-- Totul pleaca la toti (BoardState), iar cine intra primeste ultima citire. Numele se iau o data si se tin minte.
local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local BoardMath = require(ReplicatedStorage.Shared.Modules.BoardMath)
local FishConfig = require(ReplicatedStorage.Shared.Config.FishConfig)

local BoardService = {}

-- aceleasi nume ca LeaderboardService (satul); aici doar se citesc
local STORES = {
    fish = "FairFish_",
    fishSpecies = "FairFishSpecies_",
    income = "FairIncome_",
    era1 = "FairEra1_",
    records = "FairFishRecords",
}
local TOP = 10
local BOARD_EVERY = 60
local CHAMPION_EVERY = 3600
local TROPHIES_EVERY = 300
local WEEK = 7 * 86400

export type Trophy = { species: string, name: string, cm: number, userId: number }
export type State = {
    week: string,
    boards: { [string]: { BoardMath.Entry } },
    champion: { userId: number, name: string }?,
    trophies: { Trophy },
}

export type Deps = {
    Push: (State) -> (), -- dupa fiecare citire: la toti
    OnChampion: () -> (), -- s-a schimbat campionul: titlurile celor de aici se refac
}
local deps: Deps? = nil
local state: State =
    { week = "", boards = { fish = {}, income = {}, era1 = {} }, champion = nil, trophies = {} }
local names: { [number]: string } = {}
local speciesOf: { [string]: string } = {} -- "<saptamana>:<userId>:<mm>" -> specia
-- aceeasi eroare a aceluiasi store se spune o data, nu din minut in minut (2026-09-17: trei avertismente pe minut in
-- jurnalul Studio)
local lastError: { [string]: string } = {}

local function nameOf(userId: number): string
    local cached = names[userId]
    if cached ~= nil then
        return cached
    end
    local here = Players:GetPlayerByUserId(userId)
    if here ~= nil then
        names[userId] = here.DisplayName
        return here.DisplayName
    end
    local ok, name = pcall(function()
        return Players:GetNameFromUserIdAsync(userId)
    end)
    local result = if ok and typeof(name) == "string" then name else `Player {userId}`
    names[userId] = result
    return result
end

local function readTop(
    storeName: string,
    ascending: boolean,
    count: number
): { { userId: number, value: number } }
    local out = {}
    local ok, err = pcall(function()
        local pages = DataStoreService:GetOrderedDataStore(storeName)
            :GetSortedAsync(ascending, count)
        for _, item in pages:GetCurrentPage() do
            local userId = tonumber(item.key)
            if userId ~= nil and typeof(item.value) == "number" then
                table.insert(out, { userId = userId, value = item.value })
            end
        end
    end)
    if not ok then
        local message = tostring(err)
        if lastError[storeName] ~= message then
            lastError[storeName] = message
            warn(`[Board] {storeName} n-a putut fi citit: {message}`)
        end
    else
        lastError[storeName] = nil
    end
    return out
end

local function readBoards()
    local week = BoardMath.weekKey(os.time())
    local boards: { [string]: { BoardMath.Entry } } = {}
    for _, kind in BoardMath.KINDS do
        local entries: { BoardMath.Entry } = {}
        for _, item in readTop(STORES[kind] .. week, kind == "era1", TOP) do
            local extra: string? = nil
            if kind == "fish" then
                local key = `{week}:{item.userId}:{item.value}`
                extra = speciesOf[key]
                if extra == nil then
                    local ok, species = pcall(function()
                        return DataStoreService:GetDataStore(STORES.fishSpecies .. week)
                            :GetAsync(tostring(item.userId))
                    end)
                    if ok and typeof(species) == "string" then
                        speciesOf[key] = species
                        extra = species
                    end
                end
            end
            table.insert(entries, {
                userId = item.userId,
                name = nameOf(item.userId),
                value = item.value,
                extra = extra,
            })
        end
        boards[kind] = entries
    end
    state.week = week
    state.boards = boards
end

local function readChampion()
    local lastWeek = BoardMath.weekKey(os.time() - WEEK)
    local top = readTop(STORES.fish .. lastWeek, false, 1)
    local first = top[1]
    local previous = state.champion
    local before = if previous ~= nil then previous.userId else nil
    local after = if first ~= nil then first.userId else nil
    state.champion = if first ~= nil
        then { userId = first.userId, name = nameOf(first.userId) }
        else nil
    local d = deps
    if before ~= after and d ~= nil then
        d.OnChampion()
    end
end

local function readTrophies()
    local trophies: { Trophy } = {}
    for _, species in FishConfig.SPECIES do
        -- tot in pcall: fara acces la API (Studio), chiar si GetDataStore crapa
        local ok, record = pcall(function()
            return DataStoreService:GetDataStore(STORES.records):GetAsync(species.id)
        end)
        if ok and typeof(record) == "table" and typeof(record.mm) == "number" then
            table.insert(trophies, {
                species = species.name,
                name = if typeof(record.name) == "string" then record.name else "",
                cm = record.mm / 10,
                userId = if typeof(record.userId) == "number" then record.userId else 0,
            })
        end
    end
    table.sort(trophies, function(a: Trophy, b: Trophy): boolean
        return a.cm > b.cm
    end)
    state.trophies = trophies
end

local function push()
    local d = deps
    if d ~= nil then
        d.Push(state)
    end
end

function BoardService.State(): State
    return state
end

-- A fost cineva primul la peste saptamana trecuta? (titlul "Champion of the Week", TitleService)
function BoardService.IsChampion(player: Player): boolean
    local champion = state.champion
    return champion ~= nil and champion.userId == player.UserId
end

function BoardService.Init(d: Deps)
    deps = d
    if game.PlaceId == 0 then
        -- fisierul local din Studio (Balci.rbxl): DataStore exista doar intr-un place publicat, deci tabela ramane
        -- goala, iar panourile scriu "No one yet"
        print(
            "[Board] fisier local, nepublicat: tabela ramane goala (DataStore merge doar in place-ul publicat)"
        )
        push()
        return
    end
    task.spawn(function()
        readChampion()
        readTrophies()
        readBoards()
        push()
        local sinceChampion, sinceTrophies = 0, 0
        while true do
            task.wait(BOARD_EVERY)
            sinceChampion += BOARD_EVERY
            sinceTrophies += BOARD_EVERY
            if sinceChampion >= CHAMPION_EVERY then
                sinceChampion = 0
                readChampion()
            end
            if sinceTrophies >= TROPHIES_EVERY then
                sinceTrophies = 0
                readTrophies()
            end
            readBoards()
            push()
        end
    end)
end

return BoardService
