--!strict
-- Cata hrana intra si cata iese pe minut. Modul PUR, ca sa poata fi verificat fara Studio.
--
-- Exista ca sa fie citit de JUCATOR, nu doar de cod: un depozit care scade incet nu se observa
-- pana e gol. Doua numere, intrare si iesire, spun dintr-o privire daca mai poti creste colonia
-- sau trebuie sa muti oameni pe productie. Asta e decizia de administrator din joc.
local SettlerConfig =
    require(script and script.Parent.Parent.Config.SettlerConfig or "../Config/SettlerConfig")

local FoodBalance = {}

-- Cat de des mananca un colonist: de la satul (maxim) pana la pragul la care pleaca sa manance,
-- cu viteza de scadere a nevoii "fed".
function FoodBalance.mealsPerMinute(): number
    local need = nil
    for _, n in SettlerConfig.NEEDS do
        if n.id == "fed" then
            need = n
        end
    end
    if need == nil or need.decayPerMinute <= 0 then
        return 0
    end
    local span = SettlerConfig.NEED_MAX - SettlerConfig.NEED_SEEK
    local minutesBetweenMeals = span / need.decayPerMinute
    if minutesBetweenMeals <= 0 then
        return 0
    end
    return 1 / minutesBetweenMeals
end

function FoodBalance.consumptionPerMinute(population: number): number
    return math.max(0, population) * FoodBalance.mealsPerMinute() * SettlerConfig.MEAL_FOOD_COST
end

-- Pescarii produc oriunde pe mal. Gradinarii produc doar daca exista o gradina construita.
function FoodBalance.productionPerMinute(
    fishers: number,
    gardeners: number,
    gardenSlots: number
): number
    local uptime = SettlerConfig.WORK_UPTIME
    -- pescarii peste numarul de locuri de pe rau nu produc nimic in plus
    local fishing = math.min(math.max(0, fishers), SettlerConfig.FISH_SPOTS)
    local fromFish = fishing * (60 / SettlerConfig.FISH_SECONDS) * SettlerConfig.FISH_FOOD * uptime
    local working = math.min(math.max(0, gardeners), math.max(0, gardenSlots))
    local fromGarden = working
        * (60 / SettlerConfig.FARM_SECONDS)
        * SettlerConfig.GARDEN_FOOD
        * uptime
    return fromFish + fromGarden
end

-- Cati oameni mai poate hrani colonia cu productia curenta
function FoodBalance.supportedPopulation(production: number): number
    local per = FoodBalance.mealsPerMinute() * SettlerConfig.MEAL_FOOD_COST
    if per <= 0 then
        return 0
    end
    return math.floor(production / per)
end

return FoodBalance
