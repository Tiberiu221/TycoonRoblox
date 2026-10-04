--!strict
-- Redarea sunetelor: play(key, pitch?) peste Assets.sounds [F1 spec 5.6, O1]. Id 0 = inca
-- neurcat pe platforma -> tace, fara eroare (Assets.has e pentru Sprite-uri; sunetele sunt numere
-- simple in tabelul Assets.sounds, vezi manifestul de assets).
--
-- Se leaga singur la Remotes pentru reflexele lui (stropit/clinchet/vanzare/constructie/clopot);
-- orice alt controller poate chema direct SoundController.Play pentru restul (ex: butoanele de
-- meniu -- MenuBarController apartine agentului E, deci nu-l putem cabla noi de aici).
local Debris = game:GetService("Debris")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")

local Assets = require(ReplicatedStorage.Shared.Config.Assets)
local AudioLevels = require(ReplicatedStorage.Shared.Modules.AudioLevels)
local CatchSound = require(ReplicatedStorage.Shared.Modules.CatchSound)
local RiverConfig = require(ReplicatedStorage.Shared.Config.RiverConfig)
local TycoonConfig = require(ReplicatedStorage.Shared.Config.TycoonConfig)

export type Remotes = {
    NetCaught: RemoteEvent,
    Sold: RemoteEvent,
    PadBought: RemoteEvent,
}

local SoundController = {}

-- Inaltimea creste cu raritatea: RiverConfig.TIERS e deja in ordine common -> mythic.
local tierPitch: { [string]: number } = {}
for i, t in RiverConfig.TIERS do
    tierPitch[t.id] = 1 + 0.14 * (i - 1)
end

-- [D72] Ce se aude la o prindere (stropul, clinchetul gasirii, sau nimic) decide CatchSound: o plasa rapida nu mai
-- suna ca o rafala, iar clinchetul ramane rar in timp. Raza stropilor [D51] sta tot acolo.
local catchSound = CatchSound.new()
local rng = Random.new()
local characterPos: (() -> (number, number))? = nil
-- [D72] Turbina sta in rau ca o plasa, dar umple baterii (TycoonConfig.CATCH.turbine): nu face stropi de apa la fiecare
-- bucata, si nici nu intra in socoteala malului aglomerat. La fel turbina barajului (`charge`, Era 4).
local QUIET_GOODS: { [string]: boolean } = { battery = true, charge = true }
-- [D72] Casa de marcat si monedele: tare langa vanzatorul care a vandut, mai incet de departe (din Era 2 vand doi sau
-- trei deodata, fiecare o data la 1,2–8 s), si nu de doua ori in aceeasi clipa.
local SALE_NEAR = 420
local SALE_FAR = 1200
local SALE_FAR_GAIN = 0.4
local SALE_GAP = 0.6
local lastSaleAt = -math.huge

-- Cat de departe e personajul de un punct al terenului (coordonatele lui TycoonConfig); math.huge fara pozitie.
local function distanceTo(x: number?, y: number?): number
    local pos = characterPos
    if pos == nil or x == nil or y == nil then
        return math.huge
    end
    local cx, cy = pos()
    local dx = cx - TycoonConfig.PLOT_ORIGIN.x - x
    local dy = cy - TycoonConfig.PLOT_ORIGIN.y - y
    return math.sqrt(dx * dx + dy * dy)
end

-- Cat de departe e personajul de stalpul plasei.
local function distanceToNet(padId: string): number
    local pad = TycoonConfig.byId[padId]
    return if pad ~= nil then distanceTo(pad.x, pad.y) else math.huge
end

-- 3 trepte de pret [F2, docs/research/38-purchase-feel.md pct.3]: mic = usor/ascutit, mare = greu/
-- adanc -- conventia obisnuita de "juice" (mic = clinchet, mare = bubuit), nu invers.
local BUILD_PITCH_LOW = 1.18 -- < 100
local BUILD_PITCH_MID = 1.0 -- 100 - 5000
local BUILD_PITCH_HIGH = 0.82 -- > 5000

-- [D50] Amestecul: cat de tare suna fiecare, fata de celelalte. Owner-ul: "ce ar trebui lasat
-- predominant ar fi cand se prinde driftwood-ul in nets". Deci stropul si clinchetul gasirilor sus,
-- banii (care vin des) jos, gaterul abia auzit -- si oricum rar (SawmillController).
local VOLUME: { [string]: number } = {
    splash = 0.7,
    chime = 0.7,
    bell = 0.6,
    build = 0.5,
    wheel = 0.45,
    click = 0.4,
    pop = 0.35,
    register = 0.3,
    coin = 0.3,
    saw = 0.12,
    -- [D59] undita: aruncarea si pestele care trage se aud, mulinetul abia (se repeta cat se strange firul)
    cast = 0.45,
    bite = 0.6,
    reel = 0.25,
    -- [D62] nivelul urcat se aude des (x1 apasat la rand), deci incet; pragul e rar si se aude
    levelup = 0.4,
    milestone = 0.65,
    -- [verificatorul A2] filmul barajului cu muzica pe 0: santierul si zidul care se inchide raman efecte
    film_build = 0.3,
    film_close = 0.5,
}

-- [D62] NIVELURILE CUMPARATE LA RAND URCA IN INALTIME, ca o scara: fiecare apasare suna putin mai sus decat cea
-- dinainte, iar dupa o pauza scara o ia de jos. Un semiton pe treapta, cel mult o octava.
local STREAK_GAP = 1.4
local STREAK_MAX = 12
local streak = 0
local lastLevelUpAt = -math.huge

-- [D54] Nivelul efectelor (0..10), ales in panoul "Sound", sta pe grupul "Effects": tabelul VOLUME ramane
-- amestecul dintre ele, iar grupul le urca sau le coboara pe toate deodata.
local effects: SoundGroup? = nil
local level = AudioLevels.DEFAULT_SOUND
local applied = false

-- Creat la prima nevoie: un controller ii poate cere un sunet inainte de Init.
local function effectsGroup(): SoundGroup
    local existing = effects
    if existing ~= nil then
        return existing
    end
    local g = Instance.new("SoundGroup")
    g.Name = "Effects"
    g.Volume = AudioLevels.volume(level, AudioLevels.SOUND_MAX)
    g.Parent = SoundService
    effects = g
    return g
end

function SoundController.Level(): number
    return level
end

-- Din TycoonState: doar la PRIMA stare, ca la muzica (MusicController.Apply).
function SoundController.Apply(saved: number)
    if applied then
        return
    end
    applied = true
    level = if AudioLevels.valid(saved) then saved else AudioLevels.DEFAULT_SOUND
    effectsGroup().Volume = AudioLevels.volume(level, AudioLevels.SOUND_MAX)
end

-- Din panoul "Sound": se aude pe loc.
function SoundController.SetLevel(newLevel: number)
    if not AudioLevels.valid(newLevel) then
        return
    end
    applied = true
    level = newLevel
    effectsGroup().Volume = AudioLevels.volume(level, AudioLevels.SOUND_MAX)
end

-- `gain` (0..1) scade si mai mult un sunet din lume dupa distanta; volumul lui de baza e in VOLUME.
function SoundController.Play(key: string, pitch: number?, gain: number?)
    local id = (Assets.sounds :: any)[key]
    if id == nil or id == 0 then
        return -- cheie necunoscuta sau sunetul inca neurcat [O1]
    end
    local sound = Instance.new("Sound")
    sound.SoundId = Assets.soundUrl(id)
    sound.PlaybackSpeed = pitch or 1
    sound.Volume = (VOLUME[key] or 0.5) * math.clamp(gain or 1, 0, 1)
    sound.SoundGroup = effectsGroup()
    sound.Parent = SoundService
    sound:Play()
    Debris:AddItem(sound, 4) -- curatenie fara sa tinem evidenta manuala a fiecarui Sound
end

-- [D62] Un nivel (sau o treapta) cumparat. Pana se urca sunetul lui, "pop"-ul de azi tine locul.
function SoundController.PlayLevelUp()
    local now = os.clock()
    streak = if now - lastLevelUpAt <= STREAK_GAP then math.min(streak + 1, STREAK_MAX) else 0
    lastLevelUpAt = now
    local pitch = 2 ^ (streak / 12)
    if Assets.sounds.levelup ~= 0 then
        SoundController.Play("levelup", pitch)
    else
        SoundController.Play("pop", pitch)
    end
end

-- [D62] Un prag trecut (debitul se dubleaza): mai mare decat un nivel, mai mic decat clopotul erei.
function SoundController.PlayMilestone()
    if Assets.sounds.milestone ~= 0 then
        SoundController.Play("milestone")
    else
        SoundController.Play("chime", 1.3)
    end
end

-- Sunetul de constructie, cu inaltimea dupa banda de pret a platformei [F2, note 38 pct.3] --
-- 9 monede si 200 000 nu mai sunau identic. `price` vine din TycoonConfig, niciodata ghicit.
function SoundController.PlayBuild(price: number)
    local pitch = BUILD_PITCH_MID
    if price < 100 then
        pitch = BUILD_PITCH_LOW
    elseif price > 5000 then
        pitch = BUILD_PITCH_HIGH
    end
    SoundController.Play("build", pitch)
end

-- `pos` = pozitia personajului in lume; fara ea (nil) stropii tac, ca sa nu sune de oriunde.
function SoundController.Init(remotes: Remotes, pos: (() -> (number, number))?)
    characterPos = pos
    remotes.NetCaught.OnClientEvent:Connect(
        function(
            padId: string,
            _count: number,
            _capacity: number,
            good: string,
            catalog: string?,
            tier: string?
        )
            if QUIET_GOODS[good] then
                return
            end
            local sound = CatchSound.onCatch(
                catchSound,
                RiverConfig.TIERS,
                padId,
                distanceToNet(padId),
                if catalog ~= nil then tier or "common" else nil,
                os.clock(),
                rng:NextNumber(),
                rng:NextNumber(),
                rng:NextNumber()
            )
            if sound.kind == "chime" then
                SoundController.Play(
                    "chime",
                    if tier ~= nil then tierPitch[tier] else 1,
                    sound.gain
                )
            elseif sound.kind == "splash" then
                SoundController.Play("splash", sound.pitch, sound.gain)
            end
        end
    )

    -- Banii suna doar cand chiar se vinde. Cand un om isi lasa marfa (HandDelivered) nu se aude
    -- nimic: aduce busteni sau scanduri, nu monede -- casa de marcat la fiecare predare minte [D40].
    remotes.Sold.OnClientEvent:Connect(function(_total: number, _itemCount: number, seller: string?)
        local now = os.clock()
        if now - lastSaleAt < SALE_GAP then
            return -- doi vanzatori in aceeasi clipa: monedele zboara de la amandoi, casa suna o data
        end
        lastSaleAt = now
        local place = TycoonConfig.SELLER_PLACES[seller or "dock"]
            or TycoonConfig.SELLER_PLACES.dock
        local away = distanceTo(place.door.x, place.door.y)
        local far = math.clamp((away - SALE_NEAR) / (SALE_FAR - SALE_NEAR), 0, 1)
        local gain = 1 - (1 - SALE_FAR_GAIN) * far
        SoundController.Play("register", nil, gain)
        SoundController.Play("coin", nil, gain)
    end)

    remotes.PadBought.OnClientEvent:Connect(function(padId: string)
        local pad = TycoonConfig.byId[padId]
        SoundController.PlayBuild(if pad ~= nil then pad.price else 0)
        -- [D72] clopotul fiecarei ere (motivul D), nu doar al primei: Mill Bell si Works Bell sunau ca orice cumparatura
        if pad ~= nil and pad.motive == "D" then
            SoundController.Play("bell")
        end
    end)
end

return SoundController
