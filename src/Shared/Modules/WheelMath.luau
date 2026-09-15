--!strict
-- Alegerea premiului si ceasul roții. Modul PUR: primeste o tragere in [0,1) si intoarce premiul,
-- deci se poate testa exact, fara noroc. Tragerea o face serverul [D13] -- clientul doar animeaza
-- spre rezultatul primit, ca sa nu existe niciun moment in care el "stie" inainte.
local WheelConfig =
    require(script and script.Parent.Parent.Config.WheelConfig or "../Config/WheelConfig")

local WheelMath = {}

function WheelMath.totalWeight(): number
    local total = 0
    for _, p in WheelConfig.PRIZES do
        total += p.weight
    end
    return total
end

-- Premiul pentru o tragere in [0, 1). Parcurgerea e in ordinea din config, deci acelasi roll da
-- acelasi premiu oriunde -- si testul poate verifica marginile exact.
function WheelMath.pick(roll: number): WheelConfig.Prize
    local total = WheelMath.totalWeight()
    local target = math.clamp(roll, 0, 0.9999999) * total
    local acc = 0
    for _, p in WheelConfig.PRIZES do
        acc += p.weight
        if target < acc then
            return p
        end
    end
    return WheelConfig.PRIZES[#WheelConfig.PRIZES]
end

-- [D59] Ce fel de dar e: "pearls" | "treasure" | "bait". Un premiu fara niciunul e o greseala de config (testul o prinde).
function WheelMath.kindOf(prize: WheelConfig.Prize): string?
    if prize.pearls ~= nil then
        return "pearls"
    elseif prize.treasure ~= nil then
        return "treasure"
    elseif prize.bait ~= nil then
        return "bait"
    end
    return nil
end

function WheelMath.ready(now: number, lastSpinAt: number): boolean
    return lastSpinAt <= 0 or now - lastSpinAt >= WheelConfig.COOLDOWN
end

function WheelMath.secondsLeft(now: number, lastSpinAt: number): number
    if WheelMath.ready(now, lastSpinAt) then
        return 0
    end
    return math.max(0, WheelConfig.COOLDOWN - (now - lastSpinAt))
end

-- Procentul afisat langa fiecare premiu. Se calculeaza din ACELEASI ponderi pe care le foloseste
-- tragerea, nu dintr-un tabel scris de mana [D40: textul nu minte].
function WheelMath.percentOf(prize: WheelConfig.Prize): number
    return prize.weight / WheelMath.totalWeight() * 100
end

-- [D59] Unghiul (grade, 0 = sus, in sensul acelor de ceasornic) al mijlocului feliei `index` pe fata roatii. Spitele
-- timonierului stau la multipli de 360/n, iar premiile intre ele -- de aici il citesc si iconitele, si oprirea sub ac.
function WheelMath.sliceAngle(index: number): number
    return (index - 0.5) * 360 / #WheelConfig.PRIZES
end

return WheelMath
