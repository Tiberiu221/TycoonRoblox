--!strict
-- Migrarile profilului. Pure si idempotente: fara `game`, ca sa poata rula si sub Lune.
--   v1 -> v2  pivotul D45 la tycoon: sterge tot in afara de Index si Meta.createdAt.
--   v2 -> v3  statiile cu niveluri si gramada de la debarcader (E1.2): NU sterge nimic, doar
--             adauga campurile noi. Platformele cumparate raman -- un profil de playtest nu are
--             de ce sa fie aruncat doar pentru ca s-a adaugat un camp.
local ChainMath = require(script and script.Parent.ChainMath or "./ChainMath")
local PileMath = require(script and script.Parent.PileMath or "./PileMath")
local StationConfig =
    require(script and script.Parent.Parent.Config.StationConfig or "../Config/StationConfig")

local ProfileMigrate = {}

function ProfileMigrate.toV2(data: { [string]: any })
    local version = if data.Meta ~= nil and data.Meta.version ~= nil then data.Meta.version else 1
    if version >= 2 then
        return
    end
    local createdAt = if data.Meta ~= nil then data.Meta.createdAt else 0
    local index = data.Index
    for key in data do
        if key ~= "Index" and key ~= "Meta" then
            data[key] = nil
        end
    end
    data.Index = index or {}
    data.Meta = { version = 2, createdAt = createdAt or 0, lastSeenAt = 0 }
end

-- v3: statiile capata niveluri, iar marfa livrata asteapta intr-o gramada la debarcader.
-- Migrare ADITIVA: cine avea deja platforme le pastreaza, si primeste nivelul 1 peste tot.
function ProfileMigrate.toV3(data: { [string]: any })
    local version = if data.Meta ~= nil and data.Meta.version ~= nil then data.Meta.version else 1
    if version >= 3 then
        return
    end
    local stations = if typeof(data.Stations) == "table" then data.Stations else {}
    if typeof(stations.carry) ~= "table" then
        stations.carry = { level = 1 }
    end
    if typeof(stations.dock) ~= "table" then
        stations.dock = { level = 1 }
    end
    if typeof(stations.nets) ~= "table" then
        stations.nets = {}
    end
    -- fiecare plasa deja cumparata porneste de la nivelul 1
    if typeof(data.Nets) == "table" then
        for padId in data.Nets do
            if stations.nets[padId] == nil then
                stations.nets[padId] = { level = 1 }
            end
        end
    end
    data.Stations = stations
    if typeof(data.DockPile) ~= "table" then
        data.DockPile = { items = {}, drainedAt = 0 }
    end
    if typeof(data.Quests) ~= "table" then
        data.Quests = { claimed = {} }
    end
    if typeof(data.Pearls) ~= "number" then
        data.Pearls = 0
    end
    if typeof(data.Wheel) ~= "table" then
        data.Wheel = { lastSpinAt = 0, seed = 0, spins = 0 }
    end
    data.Meta.version = 3
end

-- v4 [D48]: gaterul intra in lant. Tot ce se preda trece acum prin el, deci are nivel si o gramada
-- a lui. Migrare ADITIVA: nimic nu se pierde -- ce era deja in gramada debarcaderului ramane acolo si
-- se vinde ca pana acum (scandura valoreaza cat bustenul).
function ProfileMigrate.toV4(data: { [string]: any })
    local version = if data.Meta ~= nil and data.Meta.version ~= nil then data.Meta.version else 1
    if version >= 4 then
        return
    end
    local stations = if typeof(data.Stations) == "table" then data.Stations else {}
    if typeof(stations.saw) ~= "table" then
        stations.saw = { level = 1 }
    end
    data.Stations = stations
    if typeof(data.SawmillPile) ~= "table" then
        data.SawmillPile = { items = {}, sawnAt = 0 }
    end
    data.Meta.version = 4
end

-- v5 [D49]: lantul pe oameni. Gramezile devin numaratori (listele cu un tabel pe bucata ar fi umflat
-- profilul), apar depozitul si iesirea gaterului, meseriile capata trepte, iar statia Carry dispare.
-- NIMIC NU SE PIERDE: marfa din gramezi se muta intreaga in numaratori, iar monedele platite pe
-- nivelurile de Carry se dau inapoi, o singura data [P2].
function ProfileMigrate.toV5(data: { [string]: any })
    local version = if data.Meta ~= nil and data.Meta.version ~= nil then data.Meta.version else 1
    if version >= 5 then
        return
    end
    local function counts(pile: any): { [string]: number }
        if typeof(pile) ~= "table" then
            return {}
        end
        if typeof(pile.counts) == "table" then
            return pile.counts
        end
        return PileMath.fromItems(if typeof(pile.items) == "table" then pile.items else {})
    end
    local sawmill = data.SawmillPile
    data.SawmillPile = {
        counts = counts(sawmill),
        sawnAt = if typeof(sawmill) == "table" then sawmill.sawnAt or 0 else 0,
    }
    local dock = data.DockPile
    data.DockPile = {
        counts = counts(dock),
        drainedAt = if typeof(dock) == "table" then dock.drainedAt or 0 else 0,
    }
    data.StoragePile = { counts = counts(data.StoragePile) }
    data.PlanksPile = { counts = counts(data.PlanksPile) }

    local crews = if typeof(data.Crews) == "table" then data.Crews else {}
    for _, role in StationConfig.ROLES do
        if typeof(crews[role]) ~= "table" then
            crews[role] = { tier = 1 }
        end
    end
    data.Crews = crews

    -- alergatorul din D46-D48 facea exact primul drum: de la plase. Acum e Collector-ul.
    if typeof(data.Hands) == "table" then
        for _, hand in data.Hands do
            if typeof(hand) == "table" and hand.role == "runner" then
                hand.role = "collector"
            end
        end
    end

    -- Carry ramane in profil (migrarile nu sterg), dar nu se mai citeste: nivelurile platite pe ea
    -- se rambursa o data, la pretul exact cu care s-au cumparat.
    local stations = data.Stations
    local carry = if typeof(stations) == "table" then stations.carry else nil
    if typeof(carry) == "table" and typeof(carry.level) == "number" and carry.refunded == nil then
        local levels = math.max(0, math.floor(carry.level) - 1)
        local refund = ChainMath.bulkCost(StationConfig.LEGACY_CARRY_UPGRADE_BASE, 1, levels)
        data.Coins = (if typeof(data.Coins) == "number" then data.Coins else 0) + refund
        carry.refunded = refund
    end

    if typeof(data.Stats) == "table" and typeof(data.Stats.sawn) ~= "number" then
        data.Stats.sawn = 0
    end
    data.Meta.version = 5
end

return ProfileMigrate
