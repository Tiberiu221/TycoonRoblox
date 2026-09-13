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

-- Mai multe plase pot prinde in aceeasi bataie de ceas a serverului -- fara prag, ar suna ca o
-- rafala de stropi in loc de un rau care curge.
local SPLASH_MIN_GAP = 0.12
local lastSplashAt = 0
-- [D51] Stropii se aud doar langa plasa care a prins, tot mai incet spre margine. Owner-ul: "cand prind
-- net-urile sunetul devine si acolo enervant, se poate face doar ca atunci cand te apropii?". Cu cinci
-- plase la nivel mare, prinderile vin de cateva ori pe secunda: auzite de oriunde, erau un zgomot.
local SPLASH_RANGE = 420
-- Clinchetul unei gasiri cu nume e rar si inseamna ceva: se aude oricum, doar mai incet de departe.
local CHIME_FAR_GAIN = 0.5
local characterPos: (() -> (number, number))? = nil

-- Cat de departe e personajul de stalpul plasei (coordonatele terenului); math.huge fara pozitie.
local function distanceToNet(padId: string): number
    local pos = characterPos
    local pad = TycoonConfig.byId[padId]
    if pos == nil or pad == nil or pad.x == nil or pad.y == nil then
        return math.huge
    end
    local cx, cy = pos()
    local dx = cx - TycoonConfig.PLOT_ORIGIN.x - (pad.x :: number)
    local dy = cy - TycoonConfig.PLOT_ORIGIN.y - (pad.y :: number)
    return math.sqrt(dx * dx + dy * dy)
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
}

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
            _good: string,
            catalog: string?,
            tier: string?
        )
            local away = distanceToNet(padId)
            if catalog ~= nil then
                local gain = if away <= SPLASH_RANGE then 1 else CHIME_FAR_GAIN
                SoundController.Play("chime", if tier ~= nil then tierPitch[tier] else 1, gain)
                return
            end
            if away > SPLASH_RANGE then
                return
            end
            if os.clock() - lastSplashAt >= SPLASH_MIN_GAP then
                lastSplashAt = os.clock()
                SoundController.Play("splash", nil, 1 - 0.65 * away / SPLASH_RANGE)
            end
        end
    )

    -- Banii suna doar cand chiar se vinde. Cand un om isi lasa marfa (HandDelivered) nu se aude
    -- nimic: aduce busteni sau scanduri, nu monede -- casa de marcat la fiecare predare minte [D40].
    remotes.Sold.OnClientEvent:Connect(function(_total: number, _itemCount: number)
        SoundController.Play("register")
        SoundController.Play("coin")
    end)

    remotes.PadBought.OnClientEvent:Connect(function(padId: string)
        local pad = TycoonConfig.byId[padId]
        SoundController.PlayBuild(if pad ~= nil then pad.price else 0)
        if padId == "landing_bell" then
            SoundController.Play("bell")
        end
    end)
end

return SoundController
