--!strict
-- [D54] Nivelurile sunetului, alese de jucator: muzica si efectele, fiecare de la 0 la 10. Modul PUR:
-- aceeasi validare pe server (remote-ul SetAudio) si aceeasi curba pe client (volumul grupurilor).
--
-- Owner-ul: "muzica este prea tare, nu prea este de fundal. userul ar trebui sa poata selecta nivelul
-- audio". Pana acum muzica avea un volum fix de 0.35, iar piesa e masterizata tare (varfuri la -3 dBFS).
local AudioLevels = {}

AudioLevels.MAX_LEVEL = 10
AudioLevels.DEFAULT_MUSIC = 4 -- de fundal: 0.6 x 0.16 = 0.096, cu ~11 dB sub vechiul 0.35
AudioLevels.DEFAULT_SOUND = 10 -- efectele raman amestecul de pana acum
AudioLevels.MUSIC_MAX = 0.6 -- volumul muzicii la nivelul 10
AudioLevels.SOUND_MAX = 1 -- multiplicatorul efectelor la nivelul 10

-- Un nivel venit de la client: doar un intreg finit, intre 0 si MAX_LEVEL.
function AudioLevels.valid(level: any): boolean
    return type(level) == "number"
        and math.isfinite(level)
        and level == math.floor(level)
        and level >= 0
        and level <= AudioLevels.MAX_LEVEL
end

-- Volumul unui nivel. Curba e patratica: urechea aude in decibeli, iar cu o dreapta primii pasi ar fi
-- sarit mult, iar ultimii abia s-ar fi auzit.
function AudioLevels.volume(level: number, max: number): number
    local t = math.clamp(level, 0, AudioLevels.MAX_LEVEL) / AudioLevels.MAX_LEVEL
    return max * t * t
end

return AudioLevels
