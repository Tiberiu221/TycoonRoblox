--!strict
-- Migrarile profilului. Pure si idempotente: fara `game`, ca sa poata rula si sub Lune.
--   v1 -> v2  pivotul D45 la tycoon: sterge tot in afara de Index si Meta.createdAt.
--   v2 -> v3  statiile cu niveluri si gramada de la debarcader (E1.2): NU sterge nimic, doar
--             adauga campurile noi. Platformele cumparate raman -- un profil de playtest nu are
--             de ce sa fie aruncat doar pentru ca s-a adaugat un camp.
local AudioLevels = require(script and script.Parent.AudioLevels or "./AudioLevels")
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

-- v6 [D54]: nivelurile sunetului. Pana acum muzica era doar pornita sau oprita (Settings.music); acum
-- muzica si efectele au fiecare un nivel 0..10. Cine oprise muzica o gaseste la 0, nu repornita.
-- `music` ramane in profil (migrarile nu sterg), necitit. Un profil fara Settings (dinaintea D51, adus
-- aici inainte de Reconcile) primeste implicitele.
function ProfileMigrate.toV6(data: { [string]: any })
    local version = if data.Meta ~= nil and data.Meta.version ~= nil then data.Meta.version else 1
    if version >= 6 then
        return
    end
    local settings = if typeof(data.Settings) == "table" then data.Settings else {}
    if not AudioLevels.valid(settings.musicLevel) then
        settings.musicLevel = if settings.music == false then 0 else AudioLevels.DEFAULT_MUSIC
    end
    if not AudioLevels.valid(settings.soundLevel) then
        settings.soundLevel = AudioLevels.DEFAULT_SOUND
    end
    data.Settings = settings
    data.Meta.version = 6
end

-- v7 [D55]: resturile au drumul lor. Grămezile shed-ului si ale atelierului, nivelul forjei, numaratoarea
-- fierului topit -- toate ADITIVE. Nimic nu se muta: scrap-ul, reeds si shards deja prinse stau in
-- depozit / la gater / la taverna si trec mai departe exact ca inainte (gaterul le lasa neschimbate), deci
-- se vand. Un profil sub v7 fara Stations sau Stats (adus aici inainte de Reconcile) le primeste goale.
function ProfileMigrate.toV7(data: { [string]: any })
    local version = if data.Meta ~= nil and data.Meta.version ~= nil then data.Meta.version else 1
    if version >= 7 then
        return
    end
    local function pile(key: string, extra: { [string]: any }?)
        if typeof(data[key]) ~= "table" then
            data[key] = { counts = {} }
        end
        if typeof(data[key].counts) ~= "table" then
            data[key].counts = {}
        end
        for field, value in extra or {} do
            if data[key][field] == nil then
                data[key][field] = value
            end
        end
    end
    pile("ScrapPile")
    pile("ForgePile", { smeltedAt = 0 })
    pile("IronPile")
    if typeof(data.Stations) == "table" and typeof(data.Stations.forge) ~= "table" then
        data.Stations.forge = { level = 1 }
    end
    if typeof(data.Stats) == "table" and data.Stats.smelted == nil then
        data.Stats.smelted = 0
    end
    data.Meta.version = 7
end

-- v8 [D56]: linia fierului cu oamenii ei. ADITIV: treapta celor patru meserii noi (toV5 e inghetat, nu le mai
-- adauga) si numaratoarea fierului predat. Si un singur lucru mutat, ca sa nu se piarda: ce duceau oamenii de lemn
-- pe drumurile D55 ajunge in gramada lui -- scrap-ul brut la shed, fierul la gramada de fier a forjei, de unde il
-- iau oamenii fierului; lemnul, scandurile si gasirile raman in roaba.
function ProfileMigrate.toV8(data: { [string]: any })
    local version = if data.Meta ~= nil and data.Meta.version ~= nil then data.Meta.version else 1
    if version >= 8 then
        return
    end
    if typeof(data.Crews) == "table" then
        for _, role in StationConfig.LINE_STEPS.iron do
            if typeof(data.Crews[role]) ~= "table" then
                data.Crews[role] = { tier = 1 }
            end
        end
    end
    if typeof(data.Stats) == "table" and data.Stats.ironSold == nil then
        data.Stats.ironSold = 0
    end
    local function counts(key: string): { [string]: number }
        if typeof(data[key]) ~= "table" then
            data[key] = { counts = {} }
        end
        if typeof(data[key].counts) ~= "table" then
            data[key].counts = {}
        end
        return data[key].counts
    end
    if typeof(data.Hands) == "table" then
        for _, hand in data.Hands do
            if typeof(hand) ~= "table" or typeof(hand.carry) ~= "table" then
                continue
            end
            if hand.role ~= "collector" and hand.role ~= "porter" and hand.role ~= "hauler" then
                continue
            end
            local keep = {}
            for _, item in hand.carry do
                if typeof(item) == "table" and item.g == "scrap" and item.p ~= true then
                    PileMath.add(counts("ScrapPile"), item)
                elseif typeof(item) == "table" and item.g == "iron" then
                    PileMath.add(counts("IronPile"), item)
                else
                    table.insert(keep, item)
                end
            end
            hand.carry = keep
        end
    end
    data.Meta.version = 8
end

-- [D59] PONTONUL: undita (jurnalul, momeala, samanta), ce aduce raul si satul (decor, tinute). Totul aditiv: un profil
-- vechi n-a pescuit, n-a primit nimic de pe rau si poarta tinuta de la inceput. ACELEASI campuri ca sablonul din
-- DataService (un profil nou nu trece pe aici).
function ProfileMigrate.toV9(data: { [string]: any })
    local version = if data.Meta ~= nil and data.Meta.version ~= nil then data.Meta.version else 1
    if version >= 9 then
        return
    end
    if typeof(data.Stats) == "table" then
        data.Stats.fished = data.Stats.fished or 0
        data.Stats.treasures = data.Stats.treasures or 0
    end
    if typeof(data.Fishing) ~= "table" then
        data.Fishing = { seed = 0, casts = 0, bait = 0, species = {} }
    end
    if typeof(data.River) ~= "table" then
        data.River = { started = false, waiting = {}, nextAt = 0, seed = 0, total = 0, notes = 0 }
    end
    if typeof(data.Village) ~= "table" then
        data.Village = { decor = {}, outfits = { keeper = true }, outfit = "keeper" }
    end
    data.Meta.version = 9
end

-- [D60] BALCIUL: titlurile (cumparate, purtat), vizitele, recordurile de pe tabela si timpul jucat efectiv. Totul
-- aditiv: un profil vechi n-a cumparat niciun titlu, poarta titlul Erei lui si n-a fost niciodata la balci. ACELEASI
-- campuri ca sablonul din DataService.
function ProfileMigrate.toV10(data: { [string]: any })
    local version = if data.Meta ~= nil and data.Meta.version ~= nil then data.Meta.version else 1
    if version >= 10 then
        return
    end
    if typeof(data.Stats) == "table" then
        data.Stats.playSeconds = data.Stats.playSeconds or 0
    end
    if typeof(data.Titles) ~= "table" then
        data.Titles = { bought = {}, worn = "era" }
    end
    if typeof(data.Fair) ~= "table" then
        data.Fair = { firstVisit = 0, visits = 0 }
    end
    if typeof(data.Records) ~= "table" then
        data.Records = { era1Seconds = 0, incomePerSec = 0, weeklyFishMm = 0, weeklyFishWeek = "" }
    end
    data.Meta.version = 10
end

-- [D61] Iazul si gheretele: rundele castigate si jucate, jocurile cu premiu din ziua curenta, jocurile perfecte.
-- Aditiv, in tabela Fair (pe care o face toV10 daca lipseste).
function ProfileMigrate.toV11(data: { [string]: any })
    local version = if data.Meta ~= nil and data.Meta.version ~= nil then data.Meta.version else 1
    if version >= 11 then
        return
    end
    if typeof(data.Fair) ~= "table" then
        data.Fair = { firstVisit = 0, visits = 0 }
    end
    if typeof(data.Fair.pond) ~= "table" then
        data.Fair.pond = { wins = 0, rounds = 0 }
    end
    if typeof(data.Fair.booth) ~= "table" then
        data.Fair.booth = { day = 0, prizeGames = 0, perfect = 0 }
    end
    data.Meta.version = 11
end

-- [D61] Croitoreasa: infatisarea jucatorului (patru indici in paletele oamenilor, vezi LookMath). Aditiv: cine n-a
-- ales nimic ramane cu chipul de dinainte (corpul b, parul lung, pielea a doua, satenul = toate 2).
function ProfileMigrate.toV12(data: { [string]: any })
    local version = if data.Meta ~= nil and data.Meta.version ~= nil then data.Meta.version else 1
    if version >= 12 then
        return
    end
    if typeof(data.Village) ~= "table" then
        data.Village = { decor = {}, outfits = { keeper = true }, outfit = "keeper" }
    end
    if typeof(data.Village.look) ~= "table" then
        data.Village.look = { body = 2, hair = 2, skin = 2, hairColor = 2 }
    end
    data.Meta.version = 12
end

-- [D61, partea 2] Poarta satelor: like-urile primite de satul tau si cele date de tine azi (un like pe zi pentru
-- fiecare sat, vezi VisitMath). Aditiv, in tabela Fair (pe care o face toV10 daca lipseste).
function ProfileMigrate.toV13(data: { [string]: any })
    local version = if data.Meta ~= nil and data.Meta.version ~= nil then data.Meta.version else 1
    if version >= 13 then
        return
    end
    if typeof(data.Fair) ~= "table" then
        data.Fair = { firstVisit = 0, visits = 0 }
    end
    if typeof(data.Fair.likes) ~= "number" then
        data.Fair.likes = 0
    end
    if typeof(data.Fair.liked) ~= "table" then
        data.Fair.liked = { day = 0, ids = {} }
    end
    data.Meta.version = 13
end

-- [D61, partea 2] Coltul cu Robux: pass-urile tale (copia din profil: daca verificarea Roblox pica la intrare, ramai cu
-- ce ai platit), chitantele deja onorate (tiparul ProfileStore pentru produse) si suma platita la ultima revenire
-- (`Welcome Back x2` o mai da o data). Aditiv.
function ProfileMigrate.toV14(data: { [string]: any })
    local version = if data.Meta ~= nil and data.Meta.version ~= nil then data.Meta.version else 1
    if version >= 14 then
        return
    end
    if typeof(data.Purchases) ~= "table" then
        data.Purchases = { ids = {}, passes = {} }
    end
    if typeof(data.Purchases.ids) ~= "table" then
        data.Purchases.ids = {}
    end
    if typeof(data.Purchases.passes) ~= "table" then
        data.Purchases.passes = {}
    end
    if typeof(data.Meta.lastWelcome) ~= "number" then
        data.Meta.lastWelcome = 0
    end
    data.Meta.version = 14
end

-- [D62, pasul 3] Darurile raului: cate ai scos si care a fost ultimul (fereastra de timp, DriftMath). Ultimul se tine
-- minte ca acelasi dar sa nu se poata lua de doua ori -- nici dupa o reintrare, nici de pe alt server (toate serverele
-- au acelasi program). Aditiv.
function ProfileMigrate.toV15(data: { [string]: any })
    local version = if data.Meta ~= nil and data.Meta.version ~= nil then data.Meta.version else 1
    if version >= 15 then
        return
    end
    if typeof(data.Stats) ~= "table" then
        data.Stats = {}
    end
    if typeof(data.Stats.drifts) ~= "number" then
        data.Stats.drifts = 0
    end
    if typeof(data.Stats.lastDrift) ~= "number" then
        data.Stats.lastDrift = 0
    end
    data.Meta.version = 15
end

-- [D65] ERA 2, "The Mill": nivelurile turnatoriei, ale cuptorului de cupru si ale Pietei, gramezile cartierului
-- (magazia Morii -> turnatorie -> piese; magazia de minereu -> cuptor -> cupru; gramada Pietei), treptele celor noua
-- meserii si numaratorii quest-urilor ei. Aditiv: nimic din Era 1 nu se muta si nu se pierde. Campurile de gramezi sunt
-- cele din FlowConfig (Shared/Config), iar meseriile cele din StationConfig.ERA2_ROLES.
function ProfileMigrate.toV16(data: { [string]: any })
    local version = if data.Meta ~= nil and data.Meta.version ~= nil then data.Meta.version else 1
    if version >= 16 then
        return
    end
    if typeof(data.Stations) ~= "table" then
        data.Stations = {}
    end
    for _, kind in { "foundry", "furnace", "market" } do
        if typeof(data.Stations[kind]) ~= "table" then
            data.Stations[kind] = { level = 1 }
        end
    end
    for _, pile in { "MillPile", "PartsPile", "OrePile", "CopperPile" } do
        if typeof(data[pile]) ~= "table" then
            data[pile] = { counts = {} }
        end
    end
    for _, pile in { "FoundryPile", "FurnacePile" } do
        if typeof(data[pile]) ~= "table" then
            data[pile] = { counts = {}, processedAt = 0 }
        end
    end
    if typeof(data.MarketPile) ~= "table" then
        data.MarketPile = { counts = {}, drainedAt = 0 }
    end
    if typeof(data.Crews) ~= "table" then
        data.Crews = {}
    end
    for _, role in StationConfig.ERA2_ROLES do
        if typeof(data.Crews[role]) ~= "table" then
            data.Crews[role] = { tier = 1 }
        end
    end
    if typeof(data.Stats) ~= "table" then
        data.Stats = {}
    end
    for _, stat in { "cast", "partsSold", "copperSmelted", "copperSold" } do
        if typeof(data.Stats[stat]) ~= "number" then
            data.Stats[stat] = 0
        end
    end
    data.Meta.version = 16
end

return ProfileMigrate
