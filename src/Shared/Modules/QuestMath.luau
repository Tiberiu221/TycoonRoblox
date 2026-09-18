--!strict
-- Starea quest-urilor, calculata DIN STARE, nu din evenimente. Modul pur: primeste o mana de
-- "fapte" despre jucator si intoarce, pentru fiecare quest, cat s-a facut si in ce stare e.
--
-- DE CE ASA: o lista de sarcini care numara evenimente ("+1 la fiecare colectare") se strica in
-- exact acelasi fel de fiecare data -- un eveniment ratat la deconectare, o comanda de dezvoltare,
-- o migrare de profil, si quest-ul ramane blocat desi jucatorul a facut lucrul. Citind din stare,
-- clasa asta de bug nu poate exista: daca ai deja platforma, quest-ul e gata, indiferent cand ai
-- luat-o. Singurul lucru care se SALVEAZA e ce ai revendicat -- restul se recalculeaza.
local QuestConfig =
    require(script and script.Parent.Parent.Config.QuestConfig or "../Config/QuestConfig")

local QuestMath = {}

export type Facts = {
    pads: { [string]: boolean },
    collects: number,
    sells: number,
    sawn: number, -- bucati taiate la gater, de oricine [D49]
    collected: number, -- bucati colectate de jucator din plase [D51]
    sold: number, -- bucati predate la taverna [D51]
    smelted: number?, -- bucati de fier topite la forja, de oricine [D55]
    ironSold: number?, -- bucati de fier predate la taverna, de oricine [D56]
    fished: number?, -- pesti scosi la undita [D59]
    netLevels: { [string]: number },
    dockLevel: number,
    idleRate: number,
    claimed: { [string]: boolean },
}

export type QuestState = {
    id: string,
    text: string,
    progress: number,
    goal: number,
    state: string, -- "locked" | "active" | "done" | "claimed"
    reward: QuestConfig.Reward,
}

-- Cat s-a facut din quest-ul asta, dupa faptele de acum.
-- Spre ce statie trimite un quest de nivel: ("net", padId), ("dock", nil) sau
-- nimic. Acelasi format de `arg` din care citeste `progress` -- de-aia il citeste si el de aici:
-- butonul Go! si bara de progres nu au voie sa inteleaga doua statii diferite din acelasi text.
function QuestMath.stationTarget(quest: QuestConfig.Quest): (string?, string?)
    if quest.kind ~= "level" then
        return nil, nil
    end
    local arg = quest.arg or ""
    if arg == "dock" then
        return arg, nil
    end
    local padId = string.match(arg, "^net:(.+)$")
    if padId ~= nil then
        return "net", padId
    end
    return nil, nil
end

function QuestMath.progress(quest: QuestConfig.Quest, facts: Facts): number
    local kind = quest.kind
    if kind == "pad" then
        return if facts.pads[quest.arg or ""] == true then 1 else 0
    elseif kind == "collects" then
        return facts.collects
    elseif kind == "sawn" then
        return facts.sawn
    elseif kind == "sells" then
        return facts.sells
    elseif kind == "collected" then
        return facts.collected or 0
    elseif kind == "sold" then
        return facts.sold or 0
    elseif kind == "smelted" then
        return facts.smelted or 0
    elseif kind == "ironSold" then
        return facts.ironSold or 0
    elseif kind == "fished" then
        return facts.fished or 0
    elseif kind == "idle" then
        return facts.idleRate
    elseif kind == "level" then
        local station, padId = QuestMath.stationTarget(quest)
        if station == "dock" then
            return facts.dockLevel
        elseif station == "net" and padId ~= nil then
            return facts.netLevels[padId] or 0
        end
    end
    return 0
end

function QuestMath.isDone(quest: QuestConfig.Quest, facts: Facts): boolean
    return QuestMath.progress(quest, facts) >= quest.goal
end

-- Starea intregului capitol. Quest-urile se deschid IN ORDINE: primul neterminat e "active", tot
-- ce e dupa el sta "locked". Ce e terminat ramane in lista pana il revendici -- apasatul ala e
-- mica rasplata fizica, si daca l-am da automat s-ar pierde.
function QuestMath.chapterStates(chapter: QuestConfig.Chapter, facts: Facts): { QuestState }
    local out: { QuestState } = {}
    local blocked = false
    for _, quest in chapter.quests do
        local progress = QuestMath.progress(quest, facts)
        local done = progress >= quest.goal
        local state: string
        if facts.claimed[quest.id] then
            state = "claimed"
        elseif blocked then
            state = "locked"
        elseif done then
            state = "done"
        else
            state = "active"
            blocked = true -- tot ce urmeaza dupa primul neterminat e inchis
        end
        table.insert(out, {
            id = quest.id,
            text = quest.text,
            progress = math.min(progress, quest.goal),
            goal = quest.goal,
            state = state,
            reward = quest.reward,
        })
    end
    return out
end

-- Ordinea din lista de quest-uri [owner, 2026-09-14]: "quest-urile deja colectate pot trece jos in coada si sus pot
-- aparea doar cele la care trebuie sa dai claim si sub ele cele care nu sunt facute inca". Intai de revendicat, apoi
-- activul si cele incuiate, la urma cele revendicate; in fiecare grup, ordinea capitolului. Intoarce o lista noua;
-- `stateOf` citeste starea unui rand (clientul are tipul lui de rand, copiat din instantaneu).
local DISPLAY_RANK: { [string]: number } = { done = 1, active = 2, locked = 3, claimed = 4 }

function QuestMath.displayOrder<T>(rows: { T }, stateOf: (T) -> string): { T }
    local out = table.clone(rows)
    local position: { [any]: number } = {}
    for i, row in rows do
        position[row] = i
    end
    table.sort(out, function(a: T, b: T): boolean
        local ra, rb = DISPLAY_RANK[stateOf(a)] or 2, DISPLAY_RANK[stateOf(b)] or 2
        if ra ~= rb then
            return ra < rb
        end
        return position[a] < position[b]
    end)
    return out
end

-- Quest-ul pe care il arata bannerul si spre care trage sageata: primul neterminat.
function QuestMath.active(chapter: QuestConfig.Chapter, facts: Facts): QuestConfig.Quest?
    for _, quest in chapter.quests do
        if not QuestMath.isDone(quest, facts) then
            return quest
        end
    end
    return nil
end

-- Cate recompense asteapta sa fie luate: cifra din bulina rosie de pe carte.
function QuestMath.claimable(chapter: QuestConfig.Chapter, facts: Facts): number
    local n = 0
    for _, q in QuestMath.chapterStates(chapter, facts) do
        if q.state == "done" then
            n += 1
        end
    end
    return n
end

-- Cate quest-uri sunt terminate, pentru bara capitolului (3/9).
function QuestMath.completed(chapter: QuestConfig.Chapter, facts: Facts): number
    local n = 0
    for _, quest in chapter.quests do
        if QuestMath.isDone(quest, facts) then
            n += 1
        end
    end
    return n
end

-- Capitolul la care se afla jucatorul: primul care nu e terminat si revendicat in intregime.
-- [D62] Capitolul pe care il INCHEIE revendicarea lui `questId`: toate quest-urile lui sunt acum revendicate (cu
-- `questId` cu tot). nil daca mai e ceva de luat in capitol. Un quest se revendica o singura data, deci si
-- recompensa capitolului se plateste o singura data, fara un camp nou in profil.
function QuestMath.chapterClosedBy(
    questId: string,
    claimed: { [string]: boolean }
): QuestConfig.Chapter?
    for _, chapter in QuestConfig.CHAPTERS do
        local mine = false
        local all = true
        for _, quest in chapter.quests do
            if quest.id == questId then
                mine = true
            elseif not claimed[quest.id] then
                all = false
            end
        end
        if mine then
            return if all then chapter else nil
        end
    end
    return nil
end

function QuestMath.currentChapter(facts: Facts): QuestConfig.Chapter
    for _, chapter in QuestConfig.CHAPTERS do
        for _, quest in chapter.quests do
            if not (QuestMath.isDone(quest, facts) and facts.claimed[quest.id]) then
                return chapter
            end
        end
    end
    return QuestConfig.CHAPTERS[#QuestConfig.CHAPTERS]
end

return QuestMath
