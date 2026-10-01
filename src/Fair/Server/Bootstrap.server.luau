--!strict
-- [D60] Serverul BALCIULUI DE SEARA (place-ul al doilea). Refoloseste, montate fisier cu fisier din sat (fair.project.json),
-- serviciile care tin de profil si de aspect: DataService (acelasi profil), EconomyService (doar perlele: fara Init, deci
-- fara bucla lantului -- satul nu se simuleaza aici, il plateste la intoarcere, ca offline), VillageService (decorul,
-- tinutele), WheelService (roata, mutata aici) cu FishService si TreasureService (premiile ei: momeala, ce vine la
-- ponton). TreasureService NU porneste nici el: raul tau aduce mai departe pe ceasul lui, iar ce a venit cat ai lipsit se
-- numara la intoarcere, pe ecranul de bun venit din sat.
--
-- Ordinea Init-urilor: serviciile, apoi FairNetServer (asculta ProfileLoaded), apoi DataService (el il declanseaza).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")
local Services = script.Parent:WaitForChild("Services")
local NetFolder = script.Parent:WaitForChild("Net")

local Net = require(ReplicatedStorage.Net.Net)
local MonetizationConfig = require(ReplicatedStorage.Shared.Config.MonetizationConfig)
local FairLayout = require(ReplicatedStorage.Shared.Modules.FairLayout)
local StreakMath = require(ReplicatedStorage.Shared.Modules.StreakMath) -- [D71]
local DataService = require(Services:WaitForChild("DataService"))
local EconomyService = require(Services:WaitForChild("EconomyService"))
local VillageService = require(Services:WaitForChild("VillageService"))
local WheelService = require(Services:WaitForChild("WheelService"))
local FishService = require(Services:WaitForChild("FishService"))
local FerryService = require(Services:WaitForChild("FerryService"))
local TitleService = require(Services:WaitForChild("TitleService"))
local PresenceService = require(Services:WaitForChild("PresenceService"))
local PlayerCardService = require(Services:WaitForChild("PlayerCardService"))
local BoardService = require(Services:WaitForChild("BoardService"))
local MarketService = require(Services:WaitForChild("MarketService"))
local LeaderboardService = require(Services:WaitForChild("LeaderboardService"))
local PondService = require(Services:WaitForChild("PondService"))
local BoothService = require(Services:WaitForChild("BoothService"))
local VisitService = require(Services:WaitForChild("VisitService"))
local PassService = require(Services:WaitForChild("PassService"))
local PurchaseService = require(Services:WaitForChild("PurchaseService"))
local FairNetServer = require(NetFolder:WaitForChild("FairNetServer"))
local RateLimiter = require(NetFolder:WaitForChild("RateLimiter"))

VillageService.Init({ PushState = FairNetServer.PushState })
WheelService.Init({ PushState = FairNetServer.PushState })
-- [D61] FishService: momeala de la roata si undita de la iaz. Ceasul e al serverului, ca in sat (RiverService.Now):
-- clientul asteapta muscatura pe GetServerTimeNow. Un peste scos intra pe tabla saptamanii (ca in sat) si in concurs.
LeaderboardService.Init({ Income = nil })
FishService.Init({
    PushState = FairNetServer.PushState,
    Now = function(): number
        return Workspace:GetServerTimeNow()
    end,
    OnLanded = function(player: Player, speciesId: string, cm: number)
        LeaderboardService.FishLanded(player, speciesId, cm)
        PondService.Landed(player, speciesId, cm)
    end,
})
FerryService.Init({
    Destination = "village",
    OnFailed = function(player: Player, reason: string)
        Net.Get("FerryFailed"):FireClient(player, reason)
    end,
    TravelData = function(player: Player)
        return { from = "fair", outfit = VillageService.Snapshot(player).outfit }
    end,
})

-- tabela de pe scena: citita din minut in minut si trimisa tuturor; campionul saptamanii trecute are titlul lui
BoardService.Init({
    Push = function(state)
        Net.Get("BoardState"):FireAllClients(state)
    end,
    OnChampion = function()
        for _, player in Players:GetPlayers() do
            FairNetServer.PushState(player)
        end
    end,
})
TitleService.Init({ PushState = FairNetServer.PushState, Champion = BoardService.IsChampion })
-- oamenii din balci: pozitiile (nesigur, de zece ori pe secunda) si cine e fiecare (tinuta si titlul, din profil)
PresenceService.Init({
    Where = Net.GetUnreliable("Where"),
    Crowd = Net.GetUnreliable("Crowd"),
    People = Net.Get("People"),
    Describe = function(player: Player)
        local _, title = TitleService.Worn(player)
        local village = VillageService.Snapshot(player)
        -- [D61, partea 2] numele auriu vine cu pass-ul Supporter
        return village.outfit, title, village.look, PassService.Has(player, "supporter")
    end,
    SpeedFactor = PassService.SpeedFactor, -- [D61, partea 2] Swift Boots: pasul acceptat e mai lung
    Sit = Net.Get("Sit"),
    Stand = Net.Get("Stand"),
    Wave = Net.Get("Wave"),
    SeatResult = Net.Get("SeatResult"),
    Allow = function(player: Player, name: string): boolean
        return RateLimiter.Allow(player, name)
    end,
})

-- [D61] concursul de la iaz: runda dupa ceas, tabla la toti, rezultatul fiecaruia
PondService.Init({
    Push = function(player: Player?, state: { [string]: any })
        if player ~= nil then
            Net.Get("PondState"):FireClient(player, state)
        else
            Net.Get("PondState"):FireAllClients(state)
        end
    end,
    Result = function(player: Player, result: { [string]: any })
        Net.Get("PondResult"):FireClient(player, result)
    end,
    PushState = FairNetServer.PushState,
    PositionOf = PresenceService.PositionOf,
})

-- [D61, partea 2] poarta satelor: fotografia satului altui om din balci, si like-urile
VisitService.Init({
    PlaceAt = PresenceService.PlaceAt,
    OnLiked = function(host: Player, visitorName: string, likes: number)
        Net.Get("VisitLiked"):FireClient(host, visitorName, likes)
        FairNetServer.PushState(host)
    end,
    Now = function(): number
        return os.time()
    end,
})

-- [D61, partea 2] COLTUL CU ROBUX, in balci. Taraba vinde doar pass-urile; produsele pe monede se vand in sat, unde
-- serverul stie venitul tau de acum. ProcessReceipt exista totusi si aici: Roblox retrimite o chitanta neonorata pe
-- serverul pe care intri data viitoare, fie el al balciului -- atunci se plateste din ultima cifra masurata in sat.
PassService.Init({
    PushState = FairNetServer.PushState, -- PushState reface si lista People (numele auriu, pasul mai lung)
    OnGranted = function(player: Player, key: string)
        Net.Get("RobuxResult"):FireClient(player, key, true, "ok", 0)
    end,
})
PurchaseService.Init({
    Income = function(player: Player): number
        local data = DataService.Get(player)
        local records: any = if data ~= nil then data.Records else nil
        return if typeof(records) == "table" and typeof(records.incomePerSec) == "number"
            then records.incomePerSec / 100
            else 0
    end,
    PushState = FairNetServer.PushState,
    OnGranted = function(player: Player, key: string, coins: number)
        Net.Get("RobuxResult"):FireClient(player, key, true, "ok", coins)
    end,
    HasPass = PassService.Has,
})

-- [Studio] Perle de proba in Balci.rbxl. Fisierul local porneste cu profil proaspat la fiecare Play (fara DataStore), deci
-- cu 0 perle: croitoreasa si negustorul n-ar avea cum sa fie incercati. Atributul `DevPearls` (numar) de pe Workspace
-- da perlele la incarcarea profilului. Doar in Studio, ca `DevPasses`: pe un server adevarat atributul nu e citit.
if RunService:IsStudio() then
    DataService.ProfileLoaded:Connect(function(player: Player)
        local raw = Workspace:GetAttribute("DevPearls")
        if typeof(raw) == "number" and raw == raw and raw > 0 then
            EconomyService.AddPearls(player, math.min(math.floor(raw), 100000), "dev")
            task.defer(FairNetServer.PushState, player)
        end
        -- [D71] `DevStreak`: seria zilnica de azi (pastila, cardul, titlurile seriei)
        local devStreak = Workspace:GetAttribute("DevStreak")
        local data = DataService.Get(player) :: any
        if
            typeof(devStreak) == "number"
            and devStreak == devStreak
            and devStreak > 0
            and data ~= nil
        then
            local n = math.min(math.floor(devStreak), 3650)
            local streak = StreakMath.clean(data.Streak)
            data.Streak = {
                day = StreakMath.dayOf(os.time(), streak.offset),
                run = n,
                best = n,
                total = n,
                offset = streak.offset,
                offsetDay = streak.offsetDay,
            }
            task.defer(FairNetServer.PushState, player)
        end
    end)
end

-- [D71] seria zilnica si in balci: o zi noua in timpul jocului (miezul noptii tale) se numara si se spune, ca in sat
-- (bucla din StationService). Altfel, cine iesea din joc direct de aici pierdea ziua in care a jucat.
task.spawn(function()
    while true do
        task.wait(30)
        for _, player in Players:GetPlayers() do
            if DataService.TouchStreak(player) then
                FairNetServer.PushState(player)
            end
        end
    end
end)

-- [D61] gheretele de joc
BoothService.Init({ PushState = FairNetServer.PushState, PositionOf = PresenceService.PositionOf })

FairNetServer.Init({
    Data = DataService,
    Economy = EconomyService,
    Village = VillageService,
    Wheel = WheelService,
    Ferry = FerryService,
    Titles = TitleService,
    Presence = PresenceService,
    Cards = PlayerCardService,
    Board = BoardService,
    Market = MarketService,
    Fish = FishService,
    Pond = PondService,
    Booth = BoothService,
    Visits = VisitService,
    Shop = {
        Snapshot = function(player: Player): { [string]: any }
            return {
                passes = PassService.Snapshot(player),
                quote = {}, -- produsele pe monede se vand doar in sat
                speed = PassService.SpeedFactor(player),
            }
        end,
        Prompt = function(player: Player, key: string): (boolean, string)
            local item = MonetizationConfig.byKey[key]
            if item ~= nil and item.where ~= "shop" then
                return false, "village" -- se vinde doar in sat
            end
            return PurchaseService.Prompt(player, key)
        end,
    },
})
DataService.Init({ Place = "fair" })

print(
    `[Fair] balciul e deschis: {#FairLayout.SPOTS} obiecte, cel mult {FairLayout.MAX_PLAYERS} de oameni`
)
