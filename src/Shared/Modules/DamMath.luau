--!strict
-- [D70, pasul j14] „BUILD THE DAM”: trecerea din satul de pe rau (lumea 1) la baraj (lumea 2), PURA. Muta profilul dintr-o
-- bucata si intoarce chitanta; serverul (DamService, j15) o aplica si o salveaza, clientul arata chitanta (k7). In
-- PLAN-MOTOR-UNIRE §16 se numea `WorldMath.buildDam`: sta aici, intr-un modul al ei, ca WorldMath (citit de fiecare
-- serviciu la fiecare cerere) sa nu traga dupa el quest-urile, oamenii si fotografia satului.
--
-- ORDINEA (PLAN-MOTOR-UNIRE §16, j14), fiecare pas pe ce a lasat cel dinainte:
--   1. garzile: o singura data (a doua chemare nu face nimic), dupa Works Bell, cu Era 4 in joc;
--   2. `Memories.oldVillage`: fotografia satului de dinainte (VillageLook.of), copie adanca;
--   3. „Last cart”: tot ce a ramas pe drum se vinde la pret intreg -- traista, gramezile erelor 1-3, plasele satului si
--      ce duce fiecare om. Nimic nu se pierde (CLAUDE.md, singura exceptie scrisa: D70);
--   4. quest-urile nerevendicate ale satului se platesc in perle (QuestMath.settleWorld) si se inchid;
--   5. banii: R = min(C, Purchases.coinsBought); monedele noi = START + R; darul = max(0, C - R - START), completarea =
--      max(0, START - (C - R)). Invarianta: monede noi + dar = C + completare;
--   6. `World = 2`;
--   7. cei cinci veterani (primul om al meseriilor lemnului din Era 1) trec pe meseriile barajului cu numele si chipul lor
--      (copiate, nu referinte), `formerRole`, `formerKey` si treapta veche ca medalie; ceilalti oameni ies din lucru
--      (`retired`, locuiesc in Dam Town). Singurele chei sterse sunt cele cinci vechi ale veteranilor;
--   8. cele 7 platforme pe care le da barajul (pret 0 in Era 4: turbina, Cable Net, casele veteranilor), puse direct, fara
--      angajare: oamenii lor sunt chiar veteranii;
--   9. `Firsts.DamBuilt` si chitanta, in `Memories.dam`.
local ChainMath = require(script and script.Parent.ChainMath or "./ChainMath")
local ChainState = require(script and script.Parent.ChainState or "./ChainState")
local CrewMath = require(script and script.Parent.CrewMath or "./CrewMath")
local PileMath = require(script and script.Parent.PileMath or "./PileMath")
local QuestMath = require(script and script.Parent.QuestMath or "./QuestMath")
local TycoonMath = require(script and script.Parent.TycoonMath or "./TycoonMath")
local VillageLook = require(script and script.Parent.VillageLook or "./VillageLook")
local FlowConfig =
    require(script and script.Parent.Parent.Config.FlowConfig or "../Config/FlowConfig")
local HandConfig =
    require(script and script.Parent.Parent.Config.HandConfig or "../Config/HandConfig")
local StationConfig =
    require(script and script.Parent.Parent.Config.StationConfig or "../Config/StationConfig")
local Strings = require(script and script.Parent.Parent.Config.Strings or "../Config/Strings")
local TycoonConfig =
    require(script and script.Parent.Parent.Config.TycoonConfig or "../Config/TycoonConfig")
local WorldConfig =
    require(script and script.Parent.Parent.Config.WorldConfig or "../Config/WorldConfig")

local DamMath = {}

-- Cei cinci veterani (PLAN-HARTA §2, pasul 8): Collector, Porter, Sawyer, Hauler si Innkeeper-ul din Era 1 lucreaza deja
-- ca Dam Collector, Dam Porter, Switchman, Barrel Hauler si Dispatcher.
DamMath.VETERANS = {
    { from = "collector", to = "damCollector" },
    { from = "porter", to = "damPorter" },
    { from = "sawyer", to = "switchman" },
    { from = "hauler", to = "barrelHauler" },
    { from = "trader", to = "dispatcher" },
} :: { { from: string, to: string } }

-- [D70, verificatorul k6] Cati oameni noi cere barajul pana castiga si cat lipsesti (AWAY 0): meseriile liniilor deschise de
-- la ridicare (fara platforma care sa le porneasca) si ale vanzatorului lor, fara veterani. Azi 6: cablul (4) si unirea (2).
function DamMath.newHires(): number
    local veteran: { [string]: boolean } = {}
    for _, v in DamMath.VETERANS do
        veteran[v.to] = true
    end
    local roles: { [string]: boolean } = {}
    for _, line in StationConfig.LINE_ORDER_ALL do
        local spec = FlowConfig.LINES_ALL[line]
        if
            spec.era == WorldConfig.FIRST_ERA[2]
            and spec.processorPad == nil
            and spec.storePad == nil
        then
            for _, step in StationConfig.LINES[line].steps do
                roles[step.role] = true
            end
            local seller = StationConfig.LINES[line].seller
            if seller ~= nil then
                roles[StationConfig.SELLERS[seller].role] = true
            end
        end
    end
    local n = 0
    for role in roles do
        if not veteran[role] then
            n += 1
        end
    end
    return n
end

-- Ce da barajul: platformele Erei 4 (prima a lumii 2) cu pretul 0 (turbina, Cable Net, cele cinci case ale veteranilor).
-- Doar ale ei: o plasa gratuita a Erei 5 vine cu era ei, nu la ridicare [verificatorul j14].
local GIFTS: { TycoonConfig.Pad } = {}
for _, p in TycoonConfig.padsOfWorld(2) do
    if p.era == WorldConfig.FIRST_ERA[2] and p.price == 0 then
        table.insert(GIFTS, p)
    end
end
DamMath.GIFTS = GIFTS

export type Context = {
    now: number, -- ceasul raului (RiverService.Now): plasele daruite si drumurile veteranilor pornesc de aici
    userId: number, -- samanta unui veteran care lipseste (un profil ciudat): ca la HandService.Hire
    -- pretul unei gramezi la multiplicatorul de acum (EconomyService.ValueOfCounts): „Last cart” vinde la pret intreg
    valueOfCounts: (PileMath.Counts) -> number,
    model: ChainMath.Model?, -- venitul inainte si dupa; fara el, al jocului
    eraIsLive: ((number) -> boolean)?, -- cine e in joc (testele il dau); fara el, TycoonConfig.eraIsLive
}

export type Veteran =
    { key: string, role: string, name: string, formerRole: string?, medal: number? }

export type Receipt = {
    lastCart: number, -- monedele din „Last cart”
    pieces: number, -- cate bucati s-au vandut acolo
    questPearls: number, -- perlele quest-urilor ramase
    questsClosed: number,
    coinsBefore: number, -- C: monedele dupa „Last cart”
    kept: number, -- R: monedele cumparate cu Robux inca in mana
    start: number, -- START
    coinsAfter: number, -- START + R
    gift: number, -- „Given to the Dam”
    topUp: number, -- „The village adds”
    incomeBefore: number,
    incomeAfter: number,
    veterans: { Veteran },
    retired: number,
}

local function deepCopy<T>(value: T): T
    if typeof(value) ~= "table" then
        return value
    end
    local out = {}
    for k, v in value :: any do
        out[deepCopy(k)] = deepCopy(v)
    end
    return out :: any
end
DamMath.deepCopy = deepCopy

local function finite(x: any): number
    return if typeof(x) == "number" and x == x and math.abs(x) ~= math.huge then x else 0
end

local function income(data: any, m: ChainMath.Model): number
    local st = ChainState.from(data, data.Pads, m)
    return ChainMath.valueWith(m, st, ChainMath.flowWith(m, st, false))
end

-- Garzile: nil = se poate ridica; altfel motivul ("built": e deja ridicat, "soon": Era 4 nu e in joc, "bell": Works Bell
-- nu e sunat). Le citesc si previzualizarea si serverul.
function DamMath.blocked(data: any, eraIsLive: ((number) -> boolean)?): string?
    -- o singura data, oricare ar fi lumea de acum (o unealta de proba o poate pune inapoi pe 1): ridicarea lasa urme
    -- in `Firsts` si in `Memories` [verificatorul j14]
    local firsts = if typeof(data.Firsts) == "table" then data.Firsts else {}
    local memories = if typeof(data.Memories) == "table" then data.Memories else {}
    if WorldConfig.sanitize(data.World) ~= 1 or firsts.DamBuilt == true or memories.dam ~= nil then
        return "built"
    end
    local live = eraIsLive or TycoonConfig.eraIsLive
    if not live(WorldConfig.FIRST_ERA[2]) then
        return "soon"
    end
    local bell = TycoonConfig.bellOf(WorldConfig.FIRST_ERA[2] - 1)
    if bell == nil or data.Pads[bell.id] ~= true then
        return "bell"
    end
    return nil
end

-- Gramezile satului (erele lumii 1): magazia, intrarea si iesirea fiecarui atelier, gramada fiecarui vanzator.
local function oldPiles(): { string }
    local out: { string } = {}
    for _, line in StationConfig.LINE_ORDER_ALL do
        local spec = FlowConfig.LINES_ALL[line]
        if WorldConfig.worldOfEra(spec.era) == 1 then
            for _, field in { spec.storePile, spec.inputPile, spec.outputPile } do
                if field ~= nil and not table.find(out, field) then
                    table.insert(out, field)
                end
            end
        end
    end
    for _, seller in StationConfig.SELLER_ORDER_ALL do
        local spec = FlowConfig.SELLERS_ALL[seller]
        if WorldConfig.worldOfEra(spec.era) == 1 and not table.find(out, spec.pile) then
            table.insert(out, spec.pile)
        end
    end
    return out
end
DamMath.OLD_PILES = oldPiles()

-- 3. „LAST CART”: strange tot ce a ramas pe drum intr-o singura gramada, o goleste din profil si o vinde. Intoarce
-- (monedele, bucatile).
local function lastCart(data: any, ctx: Context): (number, number)
    local cart: PileMath.Counts = {}
    if typeof(data.Sack) == "table" and typeof(data.Sack.items) == "table" then
        PileMath.addItems(cart, data.Sack.items)
        data.Sack.items = {}
    end
    for _, field in DamMath.OLD_PILES do
        local pile = data[field]
        if typeof(pile) == "table" and typeof(pile.counts) == "table" then
            for key, n in pile.counts do
                cart[key] = (cart[key] or 0) + n
            end
            pile.counts = {}
        end
    end
    for padId, net in data.Nets do
        local pad = TycoonConfig.byId[padId]
        if pad ~= nil and WorldConfig.worldOfEra(pad.era) == 1 and typeof(net.goods) == "table" then
            PileMath.addItems(cart, net.goods)
            net.goods = {} -- plasa ramane in profil, cu nivelul ei (amintirea satului)
        end
    end
    for _, hand in data.Hands do
        if typeof(hand.carry) == "table" then
            PileMath.addItems(cart, hand.carry)
            hand.carry = {}
        end
    end
    local pieces = PileMath.total(cart)
    if pieces == 0 then
        return 0, 0
    end
    local coins = finite(ctx.valueOfCounts(cart))
    data.Coins += coins
    data.Stats.coinsEarned = (data.Stats.coinsEarned or 0) + coins
    return coins, pieces
end

-- Omul nou al unei meserii a barajului, cand meseria veche n-are pe nimeni (un profil de proba): ca HandService.Hire,
-- din aceeasi samanta.
local function freshHand(role: string, key: string, ctx: Context, used: { [string]: boolean }): any
    local pad = TycoonConfig.byId[TycoonConfig.CREWS[role].pad]
    local seed = TycoonMath.catchSeed(ctx.userId, pad.index, 0)
    local identity = HandConfig.appearanceFor(seed)
    return {
        id = key,
        role = role,
        padId = pad.id,
        name = HandConfig.nameAvoiding(seed, used),
        appearance = {
            body = identity.body,
            hair = identity.hair,
            skin = deepCopy(identity.skin),
            hairColor = deepCopy(identity.hairColor),
            outfit = HandConfig.ROLE_OUTFIT[role] or HandConfig.ROLE_OUTFIT.collector,
        },
        cycleStartAt = ctx.now,
        lastEventAt = ctx.now,
        carry = {},
    }
end

-- 7. Oamenii: veteranii pe meseriile barajului, ceilalti iesiti din lucru.
local function movePeople(data: any, ctx: Context): ({ Veteran }, number)
    local used: { [string]: boolean } = {}
    for _, hand in data.Hands do
        if typeof(hand.name) == "string" then
            used[hand.name] = true
        end
    end
    local veterans: { Veteran } = {}
    local moved: { [string]: any } = {}
    for _, v in DamMath.VETERANS do
        local oldKey = CrewMath.personKey(v.from, 1) :: string
        local newKey = CrewMath.personKey(v.to, 1) :: string
        local old = data.Hands[oldKey]
        local hand: any
        if data.Hands[newKey] ~= nil then
            -- cineva lucreaza deja acolo: nu se scrie peste el (garzile o impiedica; asta e plasa de siguranta)
            hand = data.Hands[newKey]
        elseif typeof(old) == "table" and typeof(old.appearance) == "table" then
            local look = old.appearance
            local saved = data.Crews[v.from]
            local medal = if typeof(saved) == "table"
                then math.clamp(math.floor(finite(saved.tier)), 1, StationConfig.TIER_MAX)
                else 1
            hand = {
                id = newKey,
                role = v.to,
                padId = TycoonConfig.CREWS[v.to].pad,
                name = old.name,
                appearance = {
                    body = look.body,
                    hair = look.hair,
                    skin = deepCopy(look.skin),
                    hairColor = deepCopy(look.hairColor),
                    -- tinuta noii meserii; pana vine foaia ei, desenul de imprumut (VillageLook o ia din rol la citire)
                    outfit = HandConfig.ROLE_OUTFIT[v.to] or look.outfit,
                },
                cycleStartAt = ctx.now,
                lastEventAt = ctx.now,
                carry = {},
                formerRole = v.from,
                formerKey = oldKey,
                medal = medal,
            }
            data.Hands[oldKey] = nil
        else
            hand = freshHand(v.to, newKey, ctx, used)
            used[hand.name] = true
        end
        moved[newKey] = hand
        data.Crews[v.to] = { tier = 1 }
        table.insert(veterans, {
            key = newKey,
            role = v.to,
            name = hand.name,
            formerRole = hand.formerRole,
            medal = hand.medal,
        })
    end
    local retired = 0
    for _, hand in data.Hands do
        if hand.retired ~= true then
            hand.retired = true
            retired += 1
        end
    end
    for key, hand in moved do
        hand.retired = nil -- cine lucra deja la baraj (plasa de siguranta de mai sus) nu iese din lucru
        data.Hands[key] = hand
    end
    return veterans, retired
end

-- 8. Ce da barajul, pus direct: platforma, plasa ei (prinde de acum) si nivelul 1.
local function giveGifts(data: any, ctx: Context)
    if typeof(data.Stations) ~= "table" then
        data.Stations = {}
    end
    if typeof(data.Stations.nets) ~= "table" then
        data.Stations.nets = {}
    end
    for _, pad in DamMath.GIFTS do
        data.Pads[pad.id] = true
        for _, e in pad.effects do
            if e.kind == "net" then
                if data.Nets[pad.id] == nil then
                    data.Nets[pad.id] = { goods = {}, nextCatchAt = ctx.now, caught = 0 }
                end
                if data.Stations.nets[pad.id] == nil then
                    data.Stations.nets[pad.id] = { level = 1 }
                end
            end
        end
    end
end

-- RIDICAREA. Muta `data` si intoarce chitanta; sau (nil, motiv) fara sa atinga nimic.
function DamMath.build(data: any, ctx: Context): (Receipt?, string?)
    local why = DamMath.blocked(data, ctx.eraIsLive)
    if why ~= nil then
        return nil, why
    end
    local m = ctx.model or ChainMath.GAME
    local incomeBefore = income(data, m)
    -- 2. fotografia satului, inainte de orice schimbare
    if typeof(data.Memories) ~= "table" then
        data.Memories = {}
    end
    data.Memories.oldVillage = deepCopy(VillageLook.of(data))
    -- 3.
    local cartCoins, pieces = lastCart(data, ctx)
    -- 4.
    local settled = QuestMath.settleWorld(data.Quests.claimed, 1)
    data.Pearls += settled.pearls
    for _, id in settled.quests do
        data.Quests.claimed[id] = true
    end
    -- 5.
    local c = math.max(0, finite(data.Coins))
    local bought = if typeof(data.Purchases) == "table"
        then finite(data.Purchases.coinsBought)
        else 0
    local r = math.clamp(bought, 0, c)
    local start = TycoonConfig.DAM_START_COINS
    local gift = math.max(0, c - r - start)
    local topUp = math.max(0, start - (c - r))
    data.Coins = start + r
    data.Stats.damGift = gift
    if typeof(data.Purchases) == "table" then
        data.Purchases.coinsBought = r
    end
    -- 6.
    data.World = WorldConfig.worldOfEra(WorldConfig.FIRST_ERA[2])
    -- 7. si 8.
    local veterans, retired = movePeople(data, ctx)
    giveGifts(data, ctx)
    -- 9.
    data.Firsts.DamBuilt = true
    local receipt: Receipt = {
        lastCart = cartCoins,
        pieces = pieces,
        questPearls = settled.pearls,
        questsClosed = #settled.quests,
        coinsBefore = c,
        kept = r,
        start = start,
        coinsAfter = data.Coins,
        gift = gift,
        topUp = topUp,
        incomeBefore = incomeBefore,
        incomeAfter = income(data, m),
        veterans = veterans,
        retired = retired,
    }
    data.Memories.dam = deepCopy(receipt)
    data.Memories.dam.at = ctx.now
    return receipt, nil
end

-- PREVIZUALIZAREA (ecranul „Build the Dam”, k7): aceeasi socoteala pe o copie. Profilul nu se atinge.
function DamMath.preview(data: any, ctx: Context): (Receipt?, string?)
    return DamMath.build(deepCopy(data), ctx)
end

-- [D70, pasul k9] FILMUL, ca date (O1: 15–20 s, siluete la apus; arta lui vine cu lotul A2). Fiecare faza are textul ei
-- (Strings), iar `frameAt` spune ce se vede la secunda `t`: faza, cat din ea a trecut, benzile negre, panoramarea camerei
-- (0 = Wire Works, 1 = Landing) si daca „Skip” se arata (de la secunda 3 la prima vizionare, imediat la reluari). Pur, ca
-- sonda sa poata sari la orice secunda (`cinematic:seek`) si testele sa fixeze cronologia.
export type FilmPhase = { phase: string, from: number, to: number, text: string?, sub: string? }
DamMath.FILM = {
    { phase = "bells", from = 0, to = 2 },
    { phase = "look", from = 2, to = 7, text = Strings.DAM_FILM_LOOK },
    { phase = "people", from = 7, to = 11, text = Strings.DAM_FILM_PEOPLE },
    { phase = "build", from = 11, to = 14, text = Strings.DAM_FILM_BUILD },
    {
        phase = "card",
        from = 14,
        to = 17,
        text = Strings.DAM_CARD_TITLE,
        sub = Strings.DAM_CARD_SUB,
    },
} :: { FilmPhase }
DamMath.FILM_SECONDS = 17
DamMath.FILM_SKIP_AT = 3
DamMath.FILM_BARS_IN = 0.5 -- cat intra benzile negre

export type FilmFrame = {
    phase: string,
    text: string?,
    sub: string?,
    progress: number, -- 0..1 in faza
    bars: number, -- 0..1: benzile negre
    pan: number, -- 0..1: camera, de la Wire Works (0) la Landing (1)
    skip: boolean,
    done: boolean,
}

local function smooth(x: number): number
    local c = math.clamp(x, 0, 1)
    return c * c * (3 - 2 * c)
end

-- `seen`: filmul s-a mai vazut (Skip de la inceput). `reduced`: miscare redusa (GuiService.ReducedMotionEnabled): camera
-- sare, nu aluneca, iar benzile apar dintr-odata.
function DamMath.frameAt(t: number, seen: boolean, reduced: boolean?): FilmFrame
    local at = math.max(0, t)
    local current = DamMath.FILM[#DamMath.FILM]
    for _, p in DamMath.FILM do
        if at >= p.from and at < p.to then
            current = p
            break
        end
    end
    local progress = math.clamp((at - current.from) / (current.to - current.from), 0, 1)
    local look = DamMath.FILM[2]
    local panRaw = (at - look.from) / (look.to - look.from)
    local pan = if reduced then (if panRaw > 0 then 1 else 0) else smooth(panRaw)
    return {
        phase = current.phase,
        text = current.text,
        sub = current.sub,
        progress = progress,
        bars = if reduced then 1 else math.clamp(at / DamMath.FILM_BARS_IN, 0, 1),
        pan = pan,
        skip = seen or at >= DamMath.FILM_SKIP_AT,
        done = at >= DamMath.FILM_SECONDS,
    }
end

return DamMath
