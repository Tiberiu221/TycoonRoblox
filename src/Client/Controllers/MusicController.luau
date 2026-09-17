--!strict
-- Muzica de fundal [D51]: bucla compusa de noi (scripts/audio/make_music.py), fara drepturi de autor
-- ale altcuiva. Un singur `Sound` in bucla, pe un `SoundGroup` "Music" -- efectele sonore au grupul lor.
--
-- [D54] NIVELUL (0..10) il alege jucatorul in panoul "Sound", iar volumul sta pe GRUP, nu pe sunet:
-- sunetul ramane fix la 1, iar estomparea urca grupul de la 0 spre tinta nivelului. Owner-ul: "muzica este
-- prea tare, nu prea este de fundal". Implicit nivelul 4 (AudioLevels), cu ~11 dB sub vechiul 0.35.
-- Intra incet, dupa prima stare primita, ca sa nu sara peste cardul capitolului.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local SoundService = game:GetService("SoundService")
local TweenService = game:GetService("TweenService")

local Assets = require(ReplicatedStorage.Shared.Config.Assets)
local AudioLevels = require(ReplicatedStorage.Shared.Modules.AudioLevels)

local MusicController = {}
local sound: Sound? = nil
local group: SoundGroup? = nil
local level = AudioLevels.DEFAULT_MUSIC
local applied = false -- nivelul din profil s-a aplicat (sau jucatorul l-a schimbat deja)
local fadeToken = 0
local trackId: number? = nil -- [D61] piesa aleasa la Init (satul: raul; balciul: dansul de seara); nil = inainte de Init

local FADE_IN_FIRST = 4
local FADE_CHANGE = 0.35

-- Estomparea, pe grup. Pornirea din liniste pune grupul la 0 INAINTE de Play/Resume: altfel un cadru ar
-- suna la volumul de dinainte -- exact "prea tare la intrare". La 0 muzica se opreste abia cand s-a stins,
-- iar la revenire continua de unde era.
local function fadeTo(target: number, seconds: number)
    local s, g = sound, group
    if s == nil or g == nil then
        return
    end
    fadeToken += 1
    local token = fadeToken
    if target > 0 and not s.IsPlaying then
        g.Volume = 0
        if s.IsPaused then
            s:Resume()
        else
            s:Play()
        end
    end
    TweenService:Create(g, TweenInfo.new(seconds), { Volume = target }):Play()
    if target <= 0 then
        task.delay(seconds, function()
            if token == fadeToken and s.IsPlaying then
                s:Pause()
            end
        end)
    end
end

-- Exista muzica urcata? Fara ea randul Music nu apare in panou: un reglaj fara muzica ar minti [D40].
function MusicController.Available(): boolean
    return (if trackId ~= nil then trackId else Assets.music.river) ~= 0
end

function MusicController.Level(): number
    return level
end

-- Din TycoonState: nivelul salvat conteaza doar la PRIMA stare. Dupa aia panoul e adevarul: o stare venita
-- intre o apasare si salvarea ei ar aduce nivelul vechi inapoi.
function MusicController.Apply(saved: number)
    if applied then
        return
    end
    applied = true
    level = if AudioLevels.valid(saved) then saved else AudioLevels.DEFAULT_MUSIC
    fadeTo(AudioLevels.volume(level, AudioLevels.MUSIC_MAX), FADE_IN_FIRST)
end

-- Din panoul "Sound": se aude pe loc.
function MusicController.SetLevel(newLevel: number)
    if not AudioLevels.valid(newLevel) then
        return
    end
    applied = true
    level = newLevel
    fadeTo(AudioLevels.volume(level, AudioLevels.MUSIC_MAX), FADE_CHANGE)
end

-- [D61] `Track` = alta piesa decat raul; `Proximity` = cat de aproape esti de sursa ei (0..1): muzicantii din balci.
-- Nivelul din panou ramane pe grup; apropierea schimba doar volumul sunetului, lin, intre 35% si 100%.
export type Options = { Track: number?, Proximity: (() -> number)? }

function MusicController.Init(options: Options?)
    local o: Options = options or {}
    local id = o.Track or Assets.music.river
    trackId = id
    if id == 0 then
        return -- neurcata inca: tace, fara eroare
    end
    local g = Instance.new("SoundGroup")
    g.Name = "Music"
    g.Volume = 0
    g.Parent = SoundService
    local s = Instance.new("Sound")
    s.Name = if o.Track ~= nil then "Theme" else "RiverTheme"
    s.SoundId = Assets.soundUrl(id)
    s.Looped = true
    s.Volume = 1 -- fix: nivelul sta pe grup [D54]
    s.SoundGroup = g
    s.Parent = SoundService
    sound, group = s, g
    local proximity = o.Proximity
    if proximity ~= nil then
        RunService.Heartbeat:Connect(function(dt: number)
            local target = 0.35 + 0.65 * math.clamp(proximity(), 0, 1)
            s.Volume += (target - s.Volume) * math.min(1, dt * 2)
        end)
    end
end

return MusicController
