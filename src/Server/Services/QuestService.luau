--!strict
-- Quest-urile si capitolele. Serverul strange FAPTELE despre jucator, le da modulului pur
-- (QuestMath) si trimite clientului rezultatul. Revendicarea trece tot pe aici: e o tranzactie de
-- moneda, deci n-are ce cauta pe client [D13].
--
-- Nu exista niciun canal de evenimente si niciun contor de quest: progresul se CITESTE din stare.
-- Singurul lucru salvat e ce-ai revendicat deja.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local FlowConfig = require(ReplicatedStorage.Shared.Config.FlowConfig)
local QuestConfig = require(ReplicatedStorage.Shared.Config.QuestConfig)
local QuestMath = require(ReplicatedStorage.Shared.Modules.QuestMath)
local VillageLook = require(ReplicatedStorage.Shared.Modules.VillageLook)
local PassMath = require(ReplicatedStorage.Shared.Modules.PassMath)
local WorldConfig = require(ReplicatedStorage.Shared.Config.WorldConfig)

local Analytics = require(script.Parent.Analytics)
local DataService = require(script.Parent.DataService)
local EconomyService = require(script.Parent.EconomyService)

-- [D65, D67] Numaratorile din Stats ale liniilor erelor noi ("cast", "partsSold", "drawn", "cellsSold"...) si nivelul
-- vanzatorilor lor ("market", "depot"), pe numele lor: o era noua nu cere aici un rand scris de mana.
local function eraStats(data: any): { [string]: number }
    local out: { [string]: number } = {}
    for _, spec in FlowConfig.LINES do
        if spec.era > 1 then
            out[spec.processedStat] = data.Stats[spec.processedStat] or 0
            if spec.soldStat ~= nil then
                out[spec.soldStat] = data.Stats[spec.soldStat] or 0
            end
        end
    end
    return out
end

local function sellerLevels(data: any): { [string]: number }
    local out: { [string]: number } = {}
    for seller, spec in FlowConfig.SELLERS do
        local station = data.Stations[spec.station]
        if spec.era > 1 and station ~= nil then
            out[seller] = station.level
        end
    end
    return out
end

local QuestService = {}
local deps: {
    PushState: ((Player) -> ())?,
    Stations: {
        NetLevels: (Player) -> { [string]: number },
        Idle: (Player) -> number,
        Income: (Player) -> number, -- [D70, pasul j11] quest-urile de venit
    }?,
} =
    { PushState = nil, Stations = nil }

local function factsFor(player: Player): QuestMath.Facts?
    local data = DataService.Get(player)
    if data == nil then
        return nil
    end
    local stations = deps.Stations
    return {
        pads = data.Pads,
        collects = data.Stats.collects,
        sells = data.Stats.sells,
        sawn = data.Stats.sawn or 0,
        collected = data.Stats.collected or 0,
        sold = data.Stats.sold or 0,
        smelted = data.Stats.smelted or 0,
        ironSold = data.Stats.ironSold or 0, -- [D56]
        fished = data.Stats.fished or 0, -- [D59]
        decor = VillageLook.decorCount(data), -- [D62] cate lucruri ai construit de la avizier (din catalog)
        -- [D65, D67] numaratorile erelor noi si nivelul vanzatorilor lor, pe numele lor (din FlowConfig)
        stats = eraStats(data),
        levels = sellerLevels(data),
        netLevels = if stations ~= nil then stations.NetLevels(player) else {},
        dockLevel = data.Stations.dock.level,
        idleRate = if stations ~= nil then stations.Idle(player) else 0,
        claimed = data.Quests.claimed,
        -- [D70, pasul j11] venitul de pe HUD (cu pass-urile), factorul 2x Flow pentru pragurile de venit, lumea
        income = if stations ~= nil then stations.Income(player) else 0,
        flowFactor = PassMath.flowFactor(data),
        world = WorldConfig.sanitize(data.World),
    }
end

export type Snapshot = {
    chapter: { id: string, title: string, subtitle: string },
    quests: { QuestMath.QuestState },
    completed: number,
    total: number,
    claimable: number,
    -- [D51] a revendicat vreodata ceva, in orice capitol: tutorialul arata cartea doar pana atunci
    everClaimed: boolean,
    -- quest-ul activ, gata de folosit ca obiectiv de ghidaj: un singur adevar pentru sageata,
    -- pentru linia din HUD si pentru banner
    active: {
        id: string,
        text: string,
        progress: number,
        goal: number,
        padId: string?,
        dock: boolean?,
        sawmill: boolean?,
        forge: boolean?, -- [D56] inelul forjei
        fish: boolean?, -- [D59] capatul pontonului, unde pescuiesti
        board: boolean?, -- [D62] avizierul satului, de pe punte
        place: string?, -- [D65] un loc al Morii, dupa numele lui din FlowConfig ("foundry", "market"...)
        always: boolean?, -- [D65] sageata si cand ghidajul tace (un loc nou, dincolo de gard)
        -- [D51] felul quest-ului si, la unul de nivel, statia: ghidajul alege pasul din ele
        kind: string,
        stationKind: string?,
        stationId: string?,
    }?,
}

function QuestService.Snapshot(player: Player): Snapshot?
    local facts = factsFor(player)
    if facts == nil then
        return nil
    end
    local chapter = QuestMath.currentChapter(facts)
    local active = QuestMath.active(chapter, facts)
    local stationKind: string?, stationId: string? = nil, nil
    if active ~= nil then
        stationKind, stationId = QuestMath.stationTarget(active)
    end
    return {
        chapter = { id = chapter.id, title = chapter.title, subtitle = chapter.subtitle },
        quests = QuestMath.chapterStates(chapter, facts),
        completed = QuestMath.completed(chapter, facts),
        total = #chapter.quests,
        claimable = QuestMath.claimable(chapter, facts),
        everClaimed = next(facts.claimed) ~= nil,
        active = if active == nil
            then nil
            else {
                id = active.id,
                text = active.text,
                progress = math.min(
                    QuestMath.progress(active, facts),
                    QuestMath.goalOf(active, facts)
                ),
                goal = QuestMath.goalOf(active, facts), -- [D70] pragul de venit cu 2x Flow
                padId = active.targetPad,
                dock = active.targetDock,
                sawmill = active.targetSawmill,
                forge = active.targetForge, -- [D56] sageata spre inelul forjei
                fish = active.targetFish, -- [D59] sageata spre capatul pontonului
                board = active.targetBoard, -- [D62] sageata spre avizierul satului
                place = active.targetPlace, -- [D65]
                always = active.always, -- [D65]
                kind = active.kind,
                stationKind = stationKind,
                stationId = stationId,
            },
    }
end

-- Ce s-a platit la o revendicare reusita [D62]: recompensa quest-ului si, daca revendicarea a incheiat capitolul,
-- recompensa capitolului (`chapter*`). Pana la D62 campul `reward` al capitolului exista in config, dar nu-l platea
-- nimeni: capitolul 1 dadea 15 perle, iar cel mai ieftin lucru de la avizier costa 20.
export type Claimed = {
    pearls: number,
    coins: number,
    chapterTitle: string?,
    chapterSubtitle: string?,
    chapterPearls: number,
    chapterCoins: number,
    nextSubtitle: string?,
}

-- Revendicarea unei recompense. Intoarce (reusit, motiv, ce s-a platit) -- motivul ajunge la client ca text, deci
-- nu minte: "not_done" chiar inseamna ca nu e gata, nu altceva [D40].
function QuestService.Claim(player: Player, questId: string): (boolean, string, Claimed?)
    local data = DataService.Get(player)
    local facts = factsFor(player)
    if data == nil or facts == nil then
        return false, "no_profile"
    end
    local quest = QuestConfig.byId[questId]
    if quest == nil then
        return false, "unknown"
    end
    if data.Quests.claimed[questId] then
        return false, "already"
    end
    -- [D70, pasul j11] un quest al altei lumi (al satului, cand esti la baraj): s-a platit la trecere (settleWorld)
    local inWorld = false
    for _, chapter in QuestConfig.chaptersOfWorld(facts.world) do
        for _, q in chapter.quests do
            inWorld = inWorld or q.id == questId
        end
    end
    if not inWorld then
        return false, "closed"
    end
    if not QuestMath.isDone(quest, facts) then
        return false, "not_done"
    end
    -- ORDINEA CONTEAZA: intai se marcheaza, apoi se plateste. Invers, doua cereri venite in acelasi
    -- cadru ar trece amandoua de verificare si ar plati de doua ori.
    data.Quests.claimed[questId] = true
    if quest.reward.coins ~= nil then
        EconomyService.AddCoins(player, quest.reward.coins, "quest")
    end
    if quest.reward.pearls ~= nil then
        EconomyService.AddPearls(player, quest.reward.pearls, "quest")
    end
    local paid: Claimed = {
        pearls = quest.reward.pearls or 0,
        coins = quest.reward.coins or 0,
        chapterTitle = nil,
        chapterSubtitle = nil,
        chapterPearls = 0,
        chapterCoins = 0,
        nextSubtitle = nil,
    }
    -- [D62] ultimul quest al capitolului: se plateste si capitolul
    local closed = QuestMath.chapterClosedBy(questId, data.Quests.claimed)
    if closed ~= nil then
        paid.chapterTitle = closed.title
        paid.chapterSubtitle = closed.subtitle
        paid.chapterPearls = closed.reward.pearls or 0
        paid.chapterCoins = closed.reward.coins or 0
        if paid.chapterCoins > 0 then
            EconomyService.AddCoins(player, paid.chapterCoins, "chapter")
        end
        if paid.chapterPearls > 0 then
            EconomyService.AddPearls(player, paid.chapterPearls, "chapter")
        end
        for i, chapter in QuestConfig.CHAPTERS do
            if chapter == closed and QuestConfig.CHAPTERS[i + 1] ~= nil then
                paid.nextSubtitle = QuestConfig.CHAPTERS[i + 1].subtitle
            end
        end
    end
    -- Canalul quest-urilor: fara el, la playtest vom sti CATI au renuntat, dar nu si UNDE. Un pas per
    -- quest revendicat, pe capitolul lui -- exact granularitatea la care se vede blocajul [D51].
    for _, chapter in QuestConfig.CHAPTERS do
        for index, q in chapter.quests do
            if q.id == questId then
                Analytics.QuestStep(player, chapter.id, index, questId)
            end
        end
    end

    if deps.PushState ~= nil then
        (deps.PushState :: (Player) -> ())(player)
    end
    return true, "ok", paid
end

function QuestService.Init(d: typeof(deps))
    deps = d
end

return QuestService
