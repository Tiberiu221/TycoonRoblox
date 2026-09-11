--!strict
-- Depozitul coloniei: hrana [RIVERKEEP 5].
--
-- De ce exista: pana acum trei din cinci meserii nu produceau nimic. Pescarul pescuia fara
-- rezultat, gradinarul si hangiul nu aveau ce face. Hrana e lucrul care leaga meseriile de
-- populatie: mai multi oameni mananca mai mult, deci ai nevoie de mai multi producatori, deci
-- de mai multe paturi, deci de mai multe materiale. Fara ea, coloniile mari nu costa nimic.
--
-- Modul FRUNZA (cere doar DataService), ca sa poata fi cerut din SettlerService fara cerc.
local Players = game:GetService("Players")

local DataService = require(script.Parent.DataService)

local StoreService = {}
local deps: { Remotes: { [string]: RemoteEvent }? } = { Remotes = nil }

local FOOD_CAP = 400

local function ownerData(): (Player?, DataService.ProfileData?)
    for _, player in Players:GetPlayers() do
        local data = DataService.Get(player)
        if data ~= nil then
            return player, data
        end
    end
    return nil, nil
end

function StoreService.Food(): number
    local _, data = ownerData()
    if data == nil then
        return 0
    end
    return data.Stores.food or 0
end

function StoreService.Cap(): number
    return FOOD_CAP
end

-- Adauga hrana, plafonat. Intoarce cat a intrat efectiv: surplusul peste plafon se pierde,
-- ceea ce da un motiv sa ai unde depozita mai tarziu.
function StoreService.AddFood(amount: number): number
    local _, data = ownerData()
    if data == nil then
        return 0
    end
    local before = data.Stores.food or 0
    local after = math.clamp(before + amount, 0, FOOD_CAP)
    data.Stores.food = after
    return after - before
end

-- Ia hrana daca exista. Intoarce false si nu ia nimic daca nu ajunge: colonistul pleaca
-- flamand, iar jucatorul vede problema in loc sa intre in datorie ascunsa.
function StoreService.TakeFood(amount: number): boolean
    local _, data = ownerData()
    if data == nil then
        return false
    end
    local have = data.Stores.food or 0
    if have < amount then
        return false
    end
    data.Stores.food = have - amount
    return true
end

function StoreService.Init(d: { Remotes: { [string]: RemoteEvent }? })
    deps = d
    DataService.ProfileLoaded:Connect(function(player: Player)
        local data = DataService.Get(player)
        if data == nil then
            return
        end
        if data.Stores == nil then
            data.Stores = { food = 40 }
        end
    end)
end

function StoreService.Deps(): { Remotes: { [string]: RemoteEvent }? }
    return deps
end

return StoreService
