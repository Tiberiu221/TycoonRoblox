--!strict
-- Quest-urile si capitolele. Serverul strange FAPTELE despre jucator, le da modulului pur
-- (QuestMath) si trimite clientului rezultatul. Revendicarea trece tot pe aici: e o tranzactie de
-- moneda, deci n-are ce cauta pe client [D13].
--
-- Nu exista niciun canal de evenimente si niciun contor de quest: progresul se CITESTE din stare.
-- Singurul lucru salvat e ce-ai revendicat deja.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local QuestConfig = require(ReplicatedStorage.Shared.Config.QuestConfig)
local QuestMath = require(ReplicatedStorage.Shared.Modules.QuestMath)

local Analytics = require(script.Parent.Analytics)
local DataService = require(script.Parent.DataService)
local EconomyService = require(script.Parent.EconomyService)

local QuestService = {}
local deps: {
    PushState: ((Player) -> ())?,
    Stations: { NetLevels: (Player) -> { [string]: number }, Idle: (Player) -> number }?,
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
        netLevels = if stations ~= nil then stations.NetLevels(player) else {},
        dockLevel = data.Stations.dock.level,
        idleRate = if stations ~= nil then stations.Idle(player) else 0,
        claimed = data.Quests.claimed,
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
                progress = math.min(QuestMath.progress(active, facts), active.goal),
                goal = active.goal,
                padId = active.targetPad,
                dock = active.targetDock,
                sawmill = active.targetSawmill,
                kind = active.kind,
                stationKind = stationKind,
                stationId = stationId,
            },
    }
end

-- Revendicarea unei recompense. Intoarce (reusit, motiv) -- motivul ajunge la client ca text, deci
-- nu minte: "not_done" chiar inseamna ca nu e gata, nu altceva [D40].
function QuestService.Claim(player: Player, questId: string): (boolean, string)
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
        data.Pearls += quest.reward.pearls
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
    return true, "ok"
end

function QuestService.Init(d: typeof(deps))
    deps = d
end

return QuestService
