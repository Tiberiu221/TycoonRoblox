--!strict
-- Muzica de fundal [D51]: bucla compusa de noi (scripts/audio/make_music.py), fara drepturi de autor
-- ale altcuiva. Un singur `Sound` in bucla, pe un `SoundGroup` "Music" -- efectele sonore raman in
-- afara lui, deci oprirea muzicii nu le atinge.
--
-- Butonul din bara (tasta M) o porneste si o opreste, iar alegerea se tine minte in profil (remote
-- `SetMusic`): cine a oprit-o o data nu trebuie s-o opreasca la fiecare intrare. Intra incet, dupa
-- prima stare primita, ca sa nu sara peste cardul capitolului.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")
local TweenService = game:GetService("TweenService")

local Assets = require(ReplicatedStorage.Shared.Config.Assets)

export type Deps = {
    SetMusic: RemoteEvent,
    -- dupa fiecare schimbare: bara isi stinge butonul, HUD-ul spune "Music off"
    OnChanged: ((boolean) -> ())?,
}

local MusicController = {}
local deps: Deps
local sound: Sound? = nil
local enabled = true
local knowsPreference = false
local fadeToken = 0

local VOLUME = 0.35 -- sub efecte: stropii si banii trebuie sa se auda peste ea
local FADE_IN_FIRST = 4
local FADE_TOGGLE = 1.2

local function fadeTo(on: boolean, seconds: number)
    local s = sound
    if s == nil then
        return
    end
    fadeToken += 1
    local token = fadeToken
    if on then
        if not s.IsPlaying then
            s.Volume = 0
            s:Play()
        end
        TweenService:Create(s, TweenInfo.new(seconds), { Volume = VOLUME }):Play()
    else
        TweenService:Create(s, TweenInfo.new(seconds), { Volume = 0 }):Play()
        task.delay(seconds, function()
            -- pauza abia cand s-a stins, si doar daca intre timp nu s-a repornit
            if token == fadeToken and not enabled and s.IsPlaying then
                s:Pause()
            end
        end)
    end
end

-- Exista muzica urcata? Fara ea butonul nu apare: un buton de muzica fara muzica ar minti [D40].
function MusicController.Available(): boolean
    return Assets.music.river ~= 0
end

function MusicController.IsOn(): boolean
    return enabled
end

-- Din TycoonState: preferinta salvata conteaza doar la prima stare; dupa aia, butonul e adevarul.
function MusicController.Apply(musicOn: boolean)
    if knowsPreference then
        return
    end
    knowsPreference = true
    enabled = musicOn
    fadeTo(enabled, FADE_IN_FIRST)
    local changed = deps.OnChanged
    if changed ~= nil then
        changed(enabled)
    end
end

function MusicController.Toggle()
    if sound == nil then
        return
    end
    enabled = not enabled
    fadeTo(enabled, FADE_TOGGLE)
    deps.SetMusic:FireServer(enabled)
    local changed = deps.OnChanged
    if changed ~= nil then
        changed(enabled)
    end
end

function MusicController.Init(d: Deps)
    deps = d
    local id = Assets.music.river
    if id == 0 then
        return -- neurcata inca: tace, fara eroare
    end
    local group = Instance.new("SoundGroup")
    group.Name = "Music"
    group.Volume = 1
    group.Parent = SoundService
    local s = Instance.new("Sound")
    s.Name = "RiverTheme"
    s.SoundId = Assets.soundUrl(id)
    s.Looped = true
    s.Volume = 0
    s.SoundGroup = group
    s.Parent = SoundService
    sound = s
end

return MusicController
