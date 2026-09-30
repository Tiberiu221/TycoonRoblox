--!strict
-- Punctul de intrare al agentului F [F1 spec 4.9, 5]: leaga Guide/Sound/Ceremony/Juice la Remotes
-- si la starea trimisa de server. Bootstrap (agentul E) cheama Overlay.Init O SINGURA DATA, apoi
-- Overlay.Apply(snapshot) la fiecare TycoonState -- acelasi snapshot copiat explicit pe care E il
-- da si celorlalte controllere. Overlay insusi nu deseneaza nimic direct -- orice desen trece
-- printr-un sub-controller (JuiceController/CeremonyController/HUDController/GuideController).
--
-- F2 (finisaj): orchestreaza ceremonia scurta pentru ORICE cumparare, nu doar cele 4 clopote
-- [docs/research/38-purchase-feel.md], plus refuzul "Need N more coins", prima vanzare si doua
-- refuzuri de proximitate care erau tacute azi [docs/research/39-feedback-and-copy.md, D43].
-- Foloseste API-ul expus de agentul U (PadController.PadScreenPos/Flash, HUDController.
-- RateAnchor/PulseRate) DEFENSIV, cu rezerva -- la momentul scrierii doar primele doua existau
-- inca (PadController le avea, HUDController inca nu); vezi raportul.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Net = require(ReplicatedStorage.Net.Net)
local FlowConfig = require(ReplicatedStorage.Shared.Config.FlowConfig)
local ItemConfig = require(ReplicatedStorage.Shared.Config.ItemConfig)
local RiverConfig = require(ReplicatedStorage.Shared.Config.RiverConfig)
local StationConfig = require(ReplicatedStorage.Shared.Config.StationConfig)
local TycoonConfig = require(ReplicatedStorage.Shared.Config.TycoonConfig)
local Strings = require(ReplicatedStorage.Shared.Config.Strings)
local GuideMath = require(ReplicatedStorage.Shared.Modules.GuideMath)
local AmbitionMath = require(ReplicatedStorage.Shared.Modules.AmbitionMath)
local ChainMath = require(ReplicatedStorage.Shared.Modules.ChainMath)
local HandRoutes = require(ReplicatedStorage.Shared.Modules.HandRoutes)
local TycoonMath = require(ReplicatedStorage.Shared.Modules.TycoonMath)
local CeremonyController = require(script.Parent.CeremonyController)
local GuideController = require(script.Parent.GuideController)
local HUDController = require(script.Parent.HUDController)
local InteractController = require(script.Parent.InteractController)
local JuiceController = require(script.Parent.JuiceController)
local LineController = require(script.Parent.LineController)
local NetController = require(script.Parent.NetController)
local PadController = require(script.Parent.PadController)
local SoundController = require(script.Parent.SoundController)
local Pop = require(script.Parent.Parent.UI.Pop)
local Theme = require(script.Parent.Parent.UI.Theme)

-- ---- contractul cu Bootstrap [F1 spec 2.1] --------------------------------------------------
export type NetSnap = {
    padId: string,
    padIndex: number,
    lane: number,
    x: number,
    y: number,
    count: number,
    capacity: number,
    nextCatchAt: number,
    interval: number,
    caught: number,
}
export type HandSnap = {
    id: string,
    role: string,
    name: string,
    index: number?,
    count: number?,
    nets: { string },
    cycleStartAt: number,
    carrying: number,
    appearance: any, -- Overlay nu citeste aspectul -- doar HandRenderController (agentul E) il foloseste
}
export type Firsts = {
    collect: boolean,
    sell: boolean,
    named: boolean,
    runner: boolean,
    bell: boolean,
}
export type Snapshot = {
    coins: number,
    pearls: number,
    incomePerSec: number,
    pads: { [string]: string },
    padDeltas: { [string]: number }, -- [F2] venit/s adaugat de fiecare pad NEcumparat -- de la server, niciodata ghicit
    nets: { NetSnap },
    dock: { count: number, value: number, rate: number, contents: { [string]: number } },
    quests: {
        active: {
            id: string,
            text: string,
            progress: number,
            goal: number,
            padId: string?,
            dock: boolean?,
            sawmill: boolean?,
            forge: boolean?, -- [D56] sageata spre inelul forjei
            fish: boolean?, -- [D59] sageata spre capatul pontonului
            board: boolean?, -- [D62] sageata spre avizierul satului
            place: string?, -- [D65] un loc al Morii, dupa numele lui din FlowConfig
            always: boolean?, -- [D65] sageata si cand ghidajul tace
            kind: string?,
            stationKind: string?,
            stationId: string?,
        }?,
    }?,
    sack: {
        count: number,
        capacity: number,
        value: number,
        contents: { [string]: number }?,
        cut: number?,
        rawScrap: number?,
        finds: number?,
        -- [D65] pe linii si pe vanzatori
        rawBy: { [string]: number }?,
        sellBy: { [string]: { count: number, value: number } }?,
    },
    -- [D65] gramezile fiecarei linii (magazia, atelierul) si ale fiecarui vanzator, dupa nume
    flow: {
        lines: {
            [string]: {
                store: { count: number },
                processor: { count: number, out: number },
            },
        },
    }?,
    lanes: number,
    hands: { HandSnap },
    zones: { [string]: string },
    workshop: boolean,
    firsts: Firsts,
    -- cati oameni are fiecare meserie (ghidajul tace cand toate au cel putin unul [D50]; pasii buclei
    -- sar peste ce face un om [D51]) si costul urmatorului nivel al fiecarei statii
    -- [D63] randurile intregi, cum le copiaza bootstrap-ul: din ele alege AmbitionMath tinta fara sfarsit
    stations: {
        crews: { AmbitionMath.CrewRow },
        rows: { AmbitionMath.StationRow & { costs: { number } } },
    }?,
    -- [D51] gramezile de la gater si depozit: pasii buclei le citesc; [D56] si ale liniei fierului
    sawmill: { count: number, out: number }?,
    storage: { count: number }?,
    forge: { count: number, out: number }?,
    shed: { count: number }?,
    -- [D59] cati pesti ai scos si ce te asteapta la ponton: indiciul de pe linia NEXT
    fishing: { fished: number }?,
    river: { waiting: { string } }?,
}
export type Deps = {
    HudGui: Frame,
    -- [2026-09-30] niciun meniu si nicio fereastra de revenire deschise: anuntul de dupa clopot le asteapta
    ScreenClear: (() -> boolean)?,
    WorldScroll: Frame,
    Plot: Frame,
    CharacterPos: () -> (number, number),
    WorldToHud: (number, number) -> (number, number),
    Remotes: {
        NetCaught: RemoteEvent,
        Sold: RemoteEvent,
        HandDelivered: RemoteEvent,
        PadBought: RemoteEvent,
        PadRejected: RemoteEvent,
        StationUpgraded: RemoteEvent, -- [D62] un nivel cumparat
        CrewUpgraded: RemoteEvent, -- [D62] o treapta sau al doilea om
    },
    -- [D62] omul unei meserii se bucura cand ii cumperi o treapta (HandRenderController)
    CheerCrew: ((string) -> ())?,
}

local Overlay = {}
local deps: Deps
local lastSnapshot: Snapshot? = nil
local gotFirstState = false

-- Culoarea tierului pentru toast-ul de "prima gasire cu nume" [F1 spec 5.5, L4] -- aceeasi paleta
-- ca restul jocului (RiverConfig.TIERS), nu accentul per-obiect din ItemConfig.
local tierColor: { [string]: Color3 } = {}
for _, t in RiverConfig.TIERS do
    tierColor[t.id] = Color3.fromRGB(t.rgb[1], t.rgb[2], t.rgb[3])
end

-- [D65] Platformele cumparate, ca multime: `guidedRoles` intreaba de cele care pornesc cate o linie.
local function openedPads(s: Snapshot): { [string]: boolean }
    local out: { [string]: boolean } = {}
    for id, status in s.pads do
        out[id] = status == "bought"
    end
    return out
end

-- [D65] Liniile Morii pentru bucla de mana: marfa lor bruta din traista si gramezile lor (TycoonState.flow).
local function millLines(s: Snapshot): { [string]: GuideMath.LineInfo }
    local out: { [string]: GuideMath.LineInfo } = {}
    local flow = s.flow
    for _, line in StationConfig.LINE_ORDER do
        local entry = if flow ~= nil then flow.lines[line] else nil
        if line ~= "wood" and line ~= "iron" and entry ~= nil then
            out[line] = {
                raw = if s.sack.rawBy ~= nil then s.sack.rawBy[line] or 0 else 0,
                store = entry.store.count,
                input = entry.processor.count,
                output = entry.processor.out,
            }
        end
    end
    return out
end

-- Cate bucati din traista cumpara fiecare vanzator.
local function sellAt(s: Snapshot): { [string]: number }
    local out: { [string]: number } = {}
    for seller, entry in s.sack.sellBy or {} do
        out[seller] = entry.count
    end
    return out
end

-- Taie snapshot-ul mare la campurile de care are nevoie GuideMath, copiate explicit
-- [CLAUDE.md capcana 3] -- GuideMath ramane pur si nu stie de forma completa a lui Snapshot.
local function toGuideState(s: Snapshot): GuideMath.State
    local nets: { GuideMath.NetInfo } = table.create(#s.nets)
    for i, n in s.nets do
        -- tinta unei plase e stalpul ei de pe punte, unde stai ca s-o golesti -- nu plasa din apa,
        -- unde dara de ghidaj ar fi intrat in rau [D50]
        local pad = TycoonConfig.byId[n.padId]
        local y = if pad ~= nil and pad.y ~= nil then pad.y :: number else n.y
        nets[i] = {
            padId = n.padId,
            x = n.x,
            y = y,
            count = n.count,
            capacity = n.capacity,
            scrap = pad ~= nil and TycoonMath.netKind(pad) == "scrap", -- [D56] o goleste Scrap Collector-ul
            -- [D65] linia pe care curge ce prinde: plasele Morii le goleste culegatorul liniei lor
            line = if pad ~= nil then ChainMath.lineOfNetKind(TycoonMath.netKind(pad)) else nil,
        }
    end
    -- Doar culegatorii golesc plasele [D49]: Porter-ul si Hauler-ul primesc si ei lista plaselor (ca
    -- sa-si refaca drumul), dar o plasa nu e "automatizata" pentru ca exista un Porter. [D56] Fiecare culegator
    -- doar plasele felului lui -- aceeasi functie ca drumul lui, altfel ghidajul ar crede ca plasa de scrap e
    -- golita de Collector-ul de lemn.
    local hands: { GuideMath.HandInfo } = {}
    for _, h in s.hands do
        if HandRoutes.netKindOf(h.role) ~= nil then
            table.insert(
                hands,
                { nets = HandRoutes.collectorNets(h.nets, h.index or 1, h.count or 1, h.role) }
            )
        end
    end
    -- Quest-ul activ devine obiectiv de ghidaj: aici i se afla locul in lume, o singura data, din
    -- platforma pe care o tinteste, de la usa tavernei sau de la locul tau de la gater [D50].
    local quest: GuideMath.QuestGoal? = nil
    local active = s.quests ~= nil and s.quests.active or nil
    if active ~= nil then
        local x, y
        if active.padId ~= nil then
            local pad = TycoonConfig.byId[active.padId]
            if pad ~= nil and pad.x ~= nil and pad.y ~= nil then
                x, y = pad.x :: number, pad.y :: number
            end
        elseif active.dock then
            x, y = TycoonConfig.DOCK.x, TycoonConfig.DOCK.y
        elseif active.sawmill then
            -- locul unde stai ca sa tai, cu inelul lui: acolo trebuie sa ajungi, nu in cladire
            x, y = TycoonConfig.SAWMILL_STAND.x, TycoonConfig.SAWMILL_STAND.y
        elseif active.forge then
            x, y = TycoonConfig.WORKSHOP_STAND.x, TycoonConfig.WORKSHOP_STAND.y -- [D56] inelul forjei
        elseif active.fish then
            x, y = TycoonConfig.FISH_STAND.x, TycoonConfig.FISH_STAND.y -- [D59] capatul pontonului
        elseif active.board then
            x, y = TycoonConfig.VILLAGE_BOARD.x, TycoonConfig.VILLAGE_BOARD.y -- [D62] avizierul satului
        elseif active.place ~= nil then
            -- [D65] un loc al Morii, dupa numele lui din FlowConfig: inelul atelierului sau usa vanzatorului
            local spec = FlowConfig.BY_PROCESSOR[active.place]
            local seller = TycoonConfig.SELLER_PLACES[active.place]
            if spec ~= nil then
                local stand = TycoonConfig.LINE_PLACES[spec.line].playerStand
                x, y = stand.x, stand.y
            elseif seller ~= nil then
                x, y = seller.door.x, seller.door.y
            end
        end
        if x ~= nil and y ~= nil then
            local pad = if active.padId ~= nil then TycoonConfig.byId[active.padId] else nil
            -- [D51] quest de nivel: costul URMATORULUI nivel al statiei (se urca nivel cu nivel)
            local levelCost: number? = nil
            local stations = s.stations
            if active.kind == "level" and stations ~= nil then
                for _, row in stations.rows do
                    if row.kind == active.stationKind and row.id == active.stationId then
                        levelCost = row.costs[1]
                    end
                end
            end
            quest = {
                key = active.id,
                text = active.text,
                x = x,
                y = y,
                padId = if pad ~= nil and s.pads[active.padId :: string] ~= "bought"
                    then active.padId
                    else nil,
                price = if pad ~= nil and active.kind == "pad" then pad.price else nil,
                kind = active.kind,
                progress = active.progress,
                goal = active.goal,
                levelCost = levelCost,
                upgradeKind = active.stationKind,
                upgradeId = active.stationId,
                always = active.always == true, -- [D65] sageata si cand ghidajul tace
            }
        end
    end
    local counts: { [string]: number } = {}
    local stations = s.stations
    if stations ~= nil then
        for _, c in stations.crews do
            counts[c.role] = c.count
        end
    end
    local contents = s.sack.contents or {}
    return {
        -- [D56, D65] oamenii unei linii conteaza doar din clipa in care ai platforma care o porneste (Forge, roata de
        -- apa, cuptorul de cupru): GuideMath.guidedRoles
        allCrewsHired = GuideMath.allCrewsHired(counts, GuideMath.guidedRoles(openedPads(s))),
        crews = counts,
        sawIn = if s.sawmill ~= nil then s.sawmill.count else 0,
        sawOut = if s.sawmill ~= nil then s.sawmill.out else 0,
        storage = if s.storage ~= nil then s.storage.count else 0,
        forgeIn = if s.forge ~= nil then s.forge.count else 0,
        forgeOut = if s.forge ~= nil then s.forge.out else 0,
        shed = if s.shed ~= nil then s.shed.count else 0,
        dockPileValue = s.dock.value,
        quest = quest,
        coins = s.coins,
        pads = s.pads,
        nets = nets,
        sackCount = s.sack.count,
        sackCapacity = s.sack.capacity,
        sackCut = s.sack.cut or 0,
        sackRawScrap = s.sack.rawScrap or 0, -- [D55]
        sackIron = contents.iron or 0, -- [D56]
        sackFinds = s.sack.finds or 0,
        hands = hands,
        firstsCollect = s.firsts.collect,
        firstsSell = s.firsts.sell,
        -- [D59] indiciul pontonului de pe linia NEXT: dupa primul peste; un lucru care asteapta la ponton il bate
        hasFished = s.fishing ~= nil and s.fishing.fished > 0,
        treasureWaiting = if s.river ~= nil then s.river.waiting[1] else nil,
        lines = millLines(s),
        sellAt = sellAt(s),
    }
end

-- Pozitia pe HUD a unui pad, din API-ul agentului U cand exista [F2 spec Agent U pct.5]; altfel
-- rezerva: coordonatele statice din TycoonConfig, convertite chiar de noi. PadScreenPos intoarce
-- coordonate PLOT (asa arata azi implementarea lui, desi numele sugereaza altceva) -- trecem MEREU
-- prin WorldToHud, pe oricare cale am luat pozitia [apel defensiv, F2 instructiuni].
local function padScreenPos(padId: string): (number?, number?)
    local pc: any = PadController
    local plotX: number, plotY: number
    if pc.PadScreenPos ~= nil then
        plotX, plotY = pc.PadScreenPos(padId)
    else
        local pad = TycoonConfig.byId[padId]
        if pad == nil or pad.x == nil or pad.y == nil then
            return nil, nil
        end
        plotX, plotY = pad.x :: number, pad.y :: number
    end
    return deps.WorldToHud(plotX, plotY)
end

-- [D62] UNDE SE VEDE UN NIVEL CUMPARAT: obiectul din lume (sare) si locul de deasupra lui, pe HUD (cifra, rafala,
-- "+N/s"). Plasele si forja sunt platforme; gaterul si taverna sunt cladiri fixe, cu numele lor in stratul terenului.
local STATION_MARKER: { [string]: string } = { saw = "Sawmill", dock = "Tavern" }

local function stationSpot(kind: string, id: string?): (number?, number?, string)
    if kind == "net" and id ~= nil then
        local pad = TycoonConfig.byId[id]
        local x, y = padScreenPos(id)
        return x, y, if pad ~= nil then pad.name else ""
    elseif kind == "forge" then
        local x, y = padScreenPos("workshop")
        return x, y, Strings.FORGE_LABEL
    end
    -- [2026-09-29] cladirile Morii si ale Wire Works: fiecare linie isi spune singura unde e (LineController)
    local spot = LineController.StationSpot(kind)
    if spot ~= nil then
        local x, y = deps.WorldToHud(spot.x, spot.y)
        return x, y, spot.name
    end
    if kind ~= "saw" and kind ~= "dock" then
        return nil, nil, "" -- o statie necunoscuta nu-si pune efectul pe alta cladire
    end
    local at = if kind == "saw" then TycoonConfig.SAWMILL else TycoonConfig.TAVERN
    local x, y = deps.WorldToHud(at.x, at.y - at.h / 2)
    return x, y, if kind == "saw" then Strings.SAWMILL_LABEL else Strings.TAVERN_LABEL
end

local function popStation(kind: string, id: string?)
    local spot = LineController.StationSpot(kind)
    if kind == "net" and id ~= nil then
        NetController.Celebrate(id)
    elseif kind == "forge" then
        PadController.Pop("workshop")
    elseif spot ~= nil then
        if spot.pad ~= nil then
            PadController.Pop(spot.pad)
        elseif spot.art ~= nil then
            Pop.play(spot.art, 1.1)
        end
    else
        local marker = deps.Plot:FindFirstChild(STATION_MARKER[kind] or "")
        if marker ~= nil and marker:IsA("GuiObject") then
            Pop.play(marker, 1.1)
        end
    end
end

-- A cata plasa e cea tocmai cumparata: numaram platformele cu efect de plasa marcate "bought" in
-- ultima stare. Snapshot-ul vine dupa PadBought, deci ea insasi e deja numarata.
local function netCountAfter(snapshot: Snapshot?): number
    if snapshot == nil then
        return 0
    end
    local n = 0
    for _, p in TycoonConfig.PADS do
        if snapshot.pads[p.id] == "bought" then
            for _, e in p.effects do
                if e.kind == "net" then
                    n += 1
                    break
                end
            end
        end
    end
    return n
end

local function isNetPad(pad: TycoonConfig.Pad): boolean
    for _, e in pad.effects do
        if e.kind == "net" then
            return true
        end
    end
    return false
end

-- O banda HUD in plus, dincolo de ceremonia scurta -- una singura per cumparare, aleasa dupa
-- efectul care CHIAR se schimba in joc azi [F2, tabelul din nota 39]. nil pentru pad-urile fara
-- un efect "de anuntat" (netele simple, banda noua) -- rata zburatoare le acopera deja pe alea.
local function effectAnnouncement(pad: TycoonConfig.Pad): string?
    if pad.id == "workshop" then
        return Strings.FORGE_LIT -- [D56] platforma `workshop` e acum Forge
    end
    for _, e in pad.effects do
        if e.kind == "flag" and e.field == "sackBig" then
            return Strings.SACK_UPGRADED
        end
        if e.kind == "mul" and e.field == "rateMult" then
            return Strings.RIVER_NET_UPGRADED
        end
        if e.kind == "mul" and e.field == "priceMult" and e.factor ~= nil then
            local pct = math.floor(((e.factor :: number) - 1) * 100 + 0.5)
            return Strings.dockPriceBonus(pct)
        end
        if e.kind == "hire" then
            return Strings.handHired(pad.name) -- orice meserie angajata [D49]
        end
    end
    return nil
end

-- "+N to sack" cand o plasa culeasa cu mana varsa in traista intre doua stari [39, randul Sac] --
-- dedus dintr-o diferenta intre doua instantanee, nu dintr-un Remote nou (CollectNet n-are unul
-- distinct de urmatorul TycoonState). `old` e starea DINAINTE de update-ul curent.
--
-- Cifra vine din SAC, nu din cat a scazut plasa: alergatorul isi goleste plasele in propriul lui
-- brat si vinde direct la debarcader, deci o plasa care scade nu inseamna neaparat ca ai primit
-- tu ceva. Fara asta, "+3 to sack" aparea si la fiecare tura a alergatorului -- un text fals [D40].
local function announceSackGains(old: Snapshot?, new: Snapshot)
    if old == nil then
        return
    end
    local gained = new.sack.count - old.sack.count
    if gained <= 0 then
        return
    end
    -- plasa care tocmai s-a golit cel mai mult e cea de langa care sta jucatorul: acolo se arata
    local oldByPad: { [string]: NetSnap } = {}
    for _, n in old.nets do
        oldByPad[n.padId] = n
    end
    local bestDrop, bestNet = 0, nil :: NetSnap?
    for _, n in new.nets do
        local prev = oldByPad[n.padId]
        if prev ~= nil and prev.count - n.count > bestDrop then
            bestDrop = prev.count - n.count
            bestNet = n
        end
    end
    if bestNet == nil then
        return
    end
    local x, y = deps.WorldToHud((bestNet :: NetSnap).x, (bestNet :: NetSnap).y)
    JuiceController.FloatAt(x, y, Strings.sackAdd(gained), Theme.COLOR.good)
end

-- ---- refuzurile de proximitate [F2 spec Agent J pct.3] ---------------------------------------
-- Azi ambele erau tacute: mersul la debarcader cu traista goala si apropierea de gardul Erei 2
-- nu faceau NIMIC vizibil (D43). Verificare independenta de NetController/ZoneController (ale
-- agentului U) -- doar din starea si pozitia pe care Overlay le are deja.
local PROXIMITY_COOLDOWN = 2.5 -- nu repeta mesajul cat stai pe loc
local DOCK_REFUSAL_RADIUS = 70
local lastDockRefusalAt = -math.huge
local lastZoneRefusalAt = -math.huge

local function checkProximityRefusals()
    local snap = lastSnapshot
    if snap == nil then
        return
    end
    local cx, cy = deps.CharacterPos()
    local px = cx - TycoonConfig.PLOT_ORIGIN.x
    local py = cy - TycoonConfig.PLOT_ORIGIN.y
    local now = os.clock()

    if snap.sack.count <= 0 then
        local dx = px - TycoonConfig.DOCK.x
        local dy = py - TycoonConfig.DOCK.y
        -- doar chiar la usa tavernei [D50]: usa e acum langa drumul mare, iar la raza de interactiune
        -- mesajul ar fi aparut la fiecare trecere pe langa ea, cu traista goala
        if math.sqrt(dx * dx + dy * dy) <= DOCK_REFUSAL_RADIUS then
            if now - lastDockRefusalAt > PROXIMITY_COOLDOWN then
                lastDockRefusalAt = now
                local x, y = deps.WorldToHud(TycoonConfig.DOCK.x, TycoonConfig.DOCK.y - 40)
                JuiceController.FloatAt(x, y, Strings.REFUSE_SACK_EMPTY, Theme.COLOR.onDarkSoft)
            end
        else
            lastDockRefusalAt = -math.huge -- pleci din raza -- rearmat imediat, ca la platforme
        end
    end

    -- [D65] gardul oricarei zone inca inchise: cand te apropii, spune ce clopot o deschide
    local atFence = false
    for _, zone in TycoonConfig.ZONES do
        if
            zone.era > 1
            and snap.zones[zone.id] ~= "open"
            and px < zone.x0
            and zone.x0 - px <= 90
        then
            atFence = true
            if now - lastZoneRefusalAt > PROXIMITY_COOLDOWN then
                lastZoneRefusalAt = now
                local bellName = "next Bell"
                for _, p in TycoonConfig.PADS do
                    if p.era == zone.era - 1 and p.motive == "D" then
                        bellName = p.name
                    end
                end
                local x, y = deps.WorldToHud(zone.x0 - 20, py)
                JuiceController.FloatAt(
                    x,
                    y,
                    Strings.refuseZoneLocked(bellName),
                    Theme.COLOR.onDarkSoft
                )
            end
            break
        end
    end
    if not atFence then
        lastZoneRefusalAt = -math.huge
    end
end

-- [D51] Pasul ghidajului, linia NEXT si contextul cardului obiectului, din aceeasi stare: la fiecare
-- TycoonState si la fiecare prindere (numarul din plasa se schimba intre doua stari).
local function refreshGuide(snapshot: Snapshot)
    local goal = GuideController.Apply(toGuideState(snapshot))
    local stations = snapshot.stations
    -- [D63] tinta fara sfarsit: HUD-ul o arata doar cand n-are nici quest, nici pas de ghidaj
    HUDController.SetAmbition(
        if stations ~= nil
            then AmbitionMath.pick(stations.rows, stations.crews, StationConfig.MILESTONES)
            else nil
    )
    HUDController.SetStep(goal, snapshot.coins)
    InteractController.SetContext(
        goal,
        snapshot.firsts.sell,
        snapshot.coins,
        if stations ~= nil then stations.rows else nil
    )
end

function Overlay.Init(d: Deps)
    deps = d

    SoundController.Init(deps.Remotes, deps.CharacterPos)
    JuiceController.Init({ HudGui = deps.HudGui })
    CeremonyController.Init({ HudGui = deps.HudGui })
    GuideController.Init({
        WorldScroll = deps.WorldScroll,
        Plot = deps.Plot,
        HudGui = deps.HudGui,
        CharacterPos = deps.CharacterPos,
        WorldToHud = deps.WorldToHud,
        TagTop = PadController.TagTop,
        Card = InteractController.Shown,
    })

    -- [39, Sistem] "Loading your river..." -- doar daca prima stare chiar intarzie (0.3s), ca sa
    -- nu clipeasca pe calea rapida (obisnuita). Nu blocheaza -- se stinge singura, ca orice banner.
    -- 1,2s, nu 0,3: profilul se incarca in mod normal in ~0,5-1s, deci la 0,3 bannerul aparea
    -- MEREU, si ramanea pe ecran 3,5s peste fraza de deschidere. Acum apare doar daca serverul
    -- chiar intarzie, si se stinge in clipa in care starea ajunge [vazut in Studio, 2026-09-12].
    task.delay(1.2, function()
        if not gotFirstState then
            CeremonyController.PlayMoment(Strings.SYSTEM_LOADING)
        end
    end)

    RunService.PreRender:Connect(checkProximityRefusals)

    -- [L4] Prima gasire cu nume: un toast, o singura data pe profil. [D56] Colectia e pusa deoparte: toastul spune
    -- doar adevarul de azi -- gasirea merge cu marfa si se vinde bine la taverna.
    deps.Remotes.NetCaught.OnClientEvent:Connect(
        function(
            padId: string,
            count: number,
            _capacity: number,
            _good: string,
            catalog: string?,
            _tier: string?
        )
            if lastSnapshot == nil then
                return
            end
            local snap = lastSnapshot :: Snapshot
            -- [D51] Prinderile vin intre doua stari complete: fara asta, ghidajul scria "Wait for your
            -- net: 0/12" langa o plasa care arata 8/12 [vazut in Studio, 2026-09-13].
            for _, n in snap.nets do
                if n.padId == padId and type(count) == "number" then
                    n.count = count
                end
            end
            refreshGuide(snap)
            if catalog == nil then
                return
            end
            if snap.firsts.named then
                return -- nu e prima
            end
            local item = ItemConfig.get(catalog)
            local name = if item ~= nil then item.name else "something new"
            local color = if item ~= nil then tierColor[item.tier] else nil
            HUDController.Toast(Strings.namedFindHint(name), color)
        end
    )

    -- [W4] "+N" de la taverna pana la contor. Prima vanzare din joc [39, Debarcader] primeste in plus
    -- un banner -- e un prim persistent (nu se repeta), deci se verifica pe starea DINAINTE de
    -- vanzarea asta.
    -- `Sold` inseamna acum "s-a scurs un lot din gramada in monede", nu "am apasat Sell". Bannerul
    -- primei vanzari NU mai sta aici: un lot se poate scurge si din marfa adusa de o Mana, si atunci
    -- bannerul ar minti. El se trage din tranzitia lui `firsts.sell` (vezi Overlay.Apply).
    -- [D65] Monedele pleaca de la usa vanzatorului care a vandut: taverna sau Piata Morii.
    deps.Remotes.Sold.OnClientEvent:Connect(
        function(total: number, _itemCount: number, seller: string?)
            local place = TycoonConfig.SELLER_PLACES[seller or "dock"]
                or TycoonConfig.SELLER_PLACES.dock
            local fromX, fromY = deps.WorldToHud(place.door.x, place.door.y)
            JuiceController.CoinFly(fromX, fromY, total)
        end
    )
    -- Unde isi lasa un om marfa [D49]: Collector-ul la depozit, Porter-ul la intrarea gaterului,
    -- Hauler-ul la usa tavernei [D50]. "+N" apare chiar acolo, ca drumul marfii sa se vada.
    -- [D65] Din tabelele drumului marfii, pentru orice linie: magazia, intrarea atelierului, usa vanzatorului.
    local DROP_AT: { [string]: { x: number, y: number } } = {}
    for line, spec in FlowConfig.LINES do
        local places = TycoonConfig.LINE_PLACES[line]
        DROP_AT[spec.store] = places.storeStand
        DROP_AT[spec.processor] = places.processorIn
    end
    for seller, places in TycoonConfig.SELLER_PLACES do
        DROP_AT[seller] = places.door
    end
    deps.Remotes.HandDelivered.OnClientEvent:Connect(
        function(_handId: string, itemCount: number, place: string)
            -- UN OM ADUCE MARFA, NU BANI. Monedele le arunca scurgerea gramezii de la debarcader --
            -- daca le-am arunca si aici, aceiasi bani s-ar vedea de doua ori.
            local at = DROP_AT[place] or TycoonConfig.DOCK
            local fromX, fromY = deps.WorldToHud(at.x, at.y)
            JuiceController.FloatAt(fromX, fromY, `+{itemCount}`, Theme.COLOR.onDark)
        end
    )

    -- Reparatia umple Indexul -- Bootstrap leaga acelasi Remote la IndexController.Celebrate
    -- (arata OBIECTUL); noi adaugam doar cifra, "+1% income forever" [39, Atelier] -- indexBonus e
    -- o constanta STATICA (TycoonConfig.MODEL), aceeasi la orice reparatie, deci nu se ghiceste
    -- [D40]. Conectat direct la Net (nu prin deps.Remotes, care nu-l are) ca sa nu atingem
    -- Bootstrap.client.luau doar pentru un Remote in plus.
    Net.Get("RepairDone").OnClientEvent:Connect(function(_catalogId: string)
        local pct = math.floor(TycoonConfig.MODEL.indexBonus * 100 + 0.5)
        HUDController.Toast(Strings.workshopRepaired(pct))
    end)

    -- [F2] Fiecare cumparare e un eveniment, nu doar cele 4 clopote [note 38 pct.1]: fulger pe
    -- placuta, rafala mica la pad, sunetul de constructie pe treapta de pret, "+delta/s" zburand
    -- spre rata, si camera care sare peste ~500 monede. Clopotele pastreaza in plus bannerul de 3s.
    deps.Remotes.PadBought.OnClientEvent:Connect(function(padId: string)
        local pad = TycoonConfig.byId[padId]
        if pad == nil then
            return
        end

        local pc: any = PadController
        if pc.Flash ~= nil then
            pc.Flash(padId)
        end

        local px, py = padScreenPos(padId)
        if px ~= nil and py ~= nil then
            local x, y = px :: number, py :: number
            JuiceController.BurstAt(x, y, 5)
            JuiceController.FloatAt(x, y - 20, Strings.PAD_BUILT, Theme.COLOR.gold)
            local snap = lastSnapshot
            local delta = if snap ~= nil then snap.padDeltas[padId] else nil
            if delta ~= nil and delta > 0 then
                JuiceController.RateFly(x, y, delta)
            end
        end

        -- sunetul de constructie il porneste SoundController singur (auto-conectat la PadBought
        -- prin SoundController.Init, mai sus) -- daca l-am chema si de-aici, s-ar auzi de doua ori.
        if pad.price > 500 then
            JuiceController.CameraPunch()
        end

        if pad.motive == "D" then
            CeremonyController.Play(padId)
            -- [2026-09-30] clopotul ultimei ere din joc: dupa bannerul lui, ce vine (la rand, cu clopotelul lui)
            local coming = TycoonConfig.comingEra()
            if coming ~= nil and coming.era == pad.era + 1 then
                CeremonyController.PlayMoment(
                    Strings.eraComing(coming.name),
                    Strings.ERA_COMING_SUB,
                    nil,
                    {
                        onShow = function()
                            SoundController.Play("chime")
                        end,
                        -- dupa clopot revendici quest-ul lui: anuntul vine cand inchizi Quests, nu sub fereastra
                        ready = deps.ScreenClear,
                    }
                )
            end
        else
            local text = effectAnnouncement(pad)
            if text ~= nil then
                HUDController.Toast(text)
            end
        end

        -- pragul de plase: se anunta SEPARAT de efectul platformei, fiindca e un al doilea lucru
        -- primit la aceeasi cumparare -- si e gratuit [TycoonConfig.NET_MILESTONES]
        if isNetPad(pad) then
            local n = netCountAfter(lastSnapshot)
            local bonus = TycoonConfig.NET_MILESTONES[n]
            if bonus ~= nil then
                local pct = math.floor((bonus - 1) * 100 + 0.5)
                task.delay(0.9, function()
                    HUDController.Toast(Strings.netMilestone(n, pct), Theme.COLOR.good)
                end)
            end
        end
    end)

    -- [D62] UN NIVEL CUMPARAT SE VEDE SI SE AUDE. Pana acum doar refuzul era anuntat: din 333 de cumparaturi ale
    -- Erei 1, 313 (nivelurile si treptele) treceau cu un clic de buton si atat, iar pragul la care debitul se
    -- dubleaza nu se deosebea de un nivel oarecare [D43]. Meniul are efectul lui (StationMenu.OnUpgraded); aici e
    -- lumea: obiectul sare, cifra pluteste, castigul zboara spre venit. La prag: banner, rafala mare, camera.
    deps.Remotes.StationUpgraded.OnClientEvent:Connect(
        function(
            kind: string,
            id: string?,
            level: number,
            _count: number,
            milestone: number?,
            incomeDelta: number
        )
            popStation(kind, id)
            local x, y, name = stationSpot(kind, id)
            if x ~= nil and y ~= nil then
                JuiceController.BurstAt(x, y, if milestone ~= nil then 12 else 3)
                JuiceController.FloatAt(x, y - 20, Strings.levelReached(level), Theme.COLOR.gold)
                if incomeDelta > 0 then
                    JuiceController.RateFly(x, y, incomeDelta)
                end
            end
            if milestone ~= nil then
                JuiceController.CameraPunch()
                -- [2026-09-30] fanfara odata cu bannerul ei (poate asteapta la rand in spatele altuia); pana atunci,
                -- clicul are sunetul unui nivel obisnuit
                local shownNow = CeremonyController.PlayMoment(
                    Strings.milestoneTitle(name, milestone),
                    Strings.milestoneNow(
                        TycoonConfig.wordsKindOf(kind, id),
                        StationConfig.MILESTONE_MULT
                    ),
                    nil,
                    { onShow = SoundController.PlayMilestone }
                )
                if not shownNow then
                    SoundController.PlayLevelUp()
                end
            else
                SoundController.PlayLevelUp()
            end
        end
    )

    deps.Remotes.CrewUpgraded.OnClientEvent:Connect(
        function(role: string, what: string, value: number, incomeDelta: number)
            local crew = TycoonConfig.CREWS[role]
            if crew == nil then
                return
            end
            PadController.Pop(crew.pad)
            local x, y = padScreenPos(crew.pad)
            if x ~= nil and y ~= nil then
                JuiceController.BurstAt(x, y, 3)
                if what == "tier" then
                    JuiceController.FloatAt(x, y - 20, Strings.tierReached(value), Theme.COLOR.gold)
                end
                if incomeDelta > 0 then
                    JuiceController.RateFly(x, y, incomeDelta)
                end
            end
            SoundController.PlayLevelUp()
            if what == "tier" then
                local cheer = deps.CheerCrew
                if cheer ~= nil then
                    cheer(role)
                end
            else
                -- al doilea om: prima angajare are toastul ei ("Porter hired"); a doua tacea
                HUDController.Toast(Strings.secondHired(crew.name))
            end
        end
    )

    -- [39, Refuz] "Need N more coins" langa platforma, in loc de "Not enough coins" -- un calcul
    -- din pretul real si ultimele monede cunoscute, niciodata un text ghicit [D40]. Doar motivul
    -- "coins": celelalte (locked/owned/no_profile) sunt curse rare intre doua click-uri, fara
    -- text nou pentru ele.
    deps.Remotes.PadRejected.OnClientEvent:Connect(function(padId: string, reason: string)
        if reason ~= "coins" then
            return
        end
        local pad = TycoonConfig.byId[padId]
        local snap = lastSnapshot
        if pad == nil or snap == nil then
            return
        end
        local missing = math.ceil(pad.price - snap.coins)
        if missing <= 0 then
            return -- starea noastra locala e invechita -- mai bine tacem decat sa spunem o cifra falsa
        end
        local text = Strings.padNeedMoreCoins(TycoonMath.formatNumberUp(missing))
        local px, py = padScreenPos(padId)
        if px ~= nil and py ~= nil then
            JuiceController.FloatAt(px, py, text, Theme.COLOR.bad)
        else
            HUDController.Toast(text, Theme.COLOR.bad)
        end
    end)
end

-- Cheamat de Bootstrap la fiecare TycoonState, cu ACELASI snapshot copiat explicit pe care E il
-- da si celorlalte controllere [F1 spec 4.9, 2.1].
function Overlay.Apply(snapshot: Snapshot)
    if not gotFirstState then
        CeremonyController.HideNow() -- daca "Loading your river..." apucase sa apara, pleaca acum
    end
    gotFirstState = true
    announceSackGains(lastSnapshot, snapshot)
    -- prima vanzare a JUCATORULUI: se vede in tranzitia flagului, nu intr-un lot scurs oarecare
    local prev = lastSnapshot
    if prev ~= nil and not prev.firsts.sell and snapshot.firsts.sell then
        CeremonyController.PlayMoment(Strings.DOCK_FIRST_SALE)
    end
    lastSnapshot = snapshot
    refreshGuide(snapshot)
end

return Overlay
