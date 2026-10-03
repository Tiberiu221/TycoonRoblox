-- Quest-urile se citesc DIN STARE, nu din evenimente. Testele apara exact clasa de bug pe care
-- decizia asta o face imposibila: "am facut deja lucrul, dar quest-ul nu s-a bifat".
local frktest = require("@frktest/frktest")
local test = frktest.test
local check = frktest.assert.check

local QuestConfig = require("../src/Shared/Config/QuestConfig")
local QuestMath = require("../src/Shared/Modules/QuestMath")

local CHAPTER = QuestConfig.CHAPTERS[1]

local function facts(over: { [string]: any }?): QuestMath.Facts
    local f: QuestMath.Facts = {
        pads = {},
        collects = 0,
        sells = 0,
        sawn = 0,
        collected = 0,
        sold = 0,
        netLevels = {},
        dockLevel = 1,
        idleRate = 0,
        claimed = {},
    }
    for k, v in over or {} do
        (f :: any)[k] = v
    end
    return f
end

local function stateOf(list: { QuestMath.QuestState }, id: string): string
    for _, q in list do
        if q.id == id then
            return q.state
        end
    end
    return "missing"
end

return function()
    test.suite("QuestMath - progresul se citeste din stare", function()
        test.case("un quest facut INAINTE sa se deschida e gata pe loc", function()
            -- exact bugul pe care decizia il face imposibil: nimeni nu numara evenimente
            local f = facts({ netLevels = { first_net = 9 } })
            local quest = QuestConfig.byId.net_two
            check.equal(QuestMath.progress(quest, f), 9)
            check.is_true(QuestMath.isDone(quest, f))
        end)

        test.case("fiecare fel de quest citeste campul lui", function()
            check.equal(
                QuestMath.progress(
                    QuestConfig.byId.cast_first,
                    facts({ pads = { first_net = true } })
                ),
                1
            )
            -- [D51] bucati, nu gesturi: o colectare de 7 bustenii inseamna 7
            check.equal(
                QuestMath.progress(
                    QuestConfig.byId.collect_once,
                    facts({ collected = 7, collects = 1 })
                ),
                7
            )
            check.equal(
                QuestMath.progress(QuestConfig.byId.sell_once, facts({ sold = 12, sells = 1 })),
                12
            )
            check.equal(QuestMath.progress(QuestConfig.byId.saw_once, facts({ sawn = 6 })), 6)
            check.equal(
                QuestMath.progress(QuestConfig.byId.idle_one, facts({ idleRate = 3.5 })),
                3.5
            )
            -- [D59] pesti scosi la undita
            check.equal(QuestMath.progress(QuestConfig.byId.catch_fish, facts({ fished = 2 })), 2)
            check.equal(QuestMath.progress(QuestConfig.byId.catch_fish, facts()), 0)
            -- [D62] lucruri construite de la avizierul satului
            check.equal(QuestMath.progress(QuestConfig.byId.buy_decor, facts({ decor = 3 })), 3)
            check.equal(QuestMath.progress(QuestConfig.byId.buy_decor, facts()), 0)
        end)

        test.case(
            "[D62] dupa al cincilea om vin undita si avizierul, apoi capitolul continua ca inainte",
            function()
                local order: { string } = {}
                for _, q in QuestConfig.CHAPTERS[1].quests do
                    table.insert(order, q.id)
                end
                local at: { [string]: number } = {}
                for i, id in order do
                    at[id] = i
                end
                check.equal(at.catch_fish, at.hire_trader + 1)
                check.equal(at.buy_decor, at.catch_fish + 1)
                check.equal(at.net_two, at.buy_decor + 1)
                check.equal(at.cast_second, at.net_two + 1)
                -- quest-ul de pescuit s-a MUTAT, nu s-a copiat: un id apare o singura data in tot jocul
                local seen: { [string]: number } = {}
                for _, chapter in QuestConfig.CHAPTERS do
                    for _, q in chapter.quests do
                        seen[q.id] = (seen[q.id] or 0) + 1
                    end
                end
                for id, n in seen do
                    check.equal(`{id}:{n}`, `{id}:1`)
                end
                -- fiecare isi are sageata, chiar daca ghidajul tace atunci
                check.is_true(QuestConfig.byId.catch_fish.targetFish == true)
                check.is_true(QuestConfig.byId.buy_decor.targetBoard == true)
            end
        )

        test.case(
            "[D67] fiecare text de quest incape pe randul listei (270 px), cel mult cu un punct mai mic",
            function()
                -- Fontul de pixeli are 0,5585 em pe litera (CLAUDE.md). QuestController micsoreaza textul cat sa incapa
                -- (Theme.fitSize), dar sub 14 randul ar parea altfel decat vecinii lui: "Cast a fourteenth net, further
                -- out" (34 de litere) se taia in "..." inainte sa existe testul.
                -- [D70] un quest de venit are si eticheta cu 2x Flow (QuestMath.textOf): se masoara si ea
                local doubled = facts({ flowFactor = 2 })
                for _, chapter in QuestConfig.ALL_CHAPTERS do
                    for _, q in chapter.quests do
                        for _, text in { q.text, QuestMath.textOf(q, doubled) } do
                            local width = #text * 0.5585 * 14
                            if width > 270 then
                                error(
                                    `"{text}" ({q.id}) are {math.ceil(width)} px la marimea 14, randul are 270`
                                )
                            end
                        end
                    end
                end
            end
        )

        test.case("un quest de nivel pe o plasa o numeste ca in lume", function()
            local TycoonConfig = require("../src/Shared/Config/TycoonConfig")
            local seen = 0
            for _, chapter in QuestConfig.ALL_CHAPTERS do
                for _, q in chapter.quests do
                    local station, padId = QuestMath.stationTarget(q)
                    -- prima plasa e "your net" in turul de mana: singura, n-are cu cine se confunda
                    if
                        q.kind == "level"
                        and station == "net"
                        and padId ~= nil
                        and padId ~= "first_net"
                    then
                        local name = TycoonConfig.byId[padId].name
                        if string.find(q.text, name, 1, true) == nil then
                            print(`[QuestMath] {q.id}: "{q.text}" nu spune "{name}"`)
                        end
                        check.not_nil(string.find(q.text, name, 1, true))
                        seen += 1
                    end
                end
            end
            check.is_true(seen >= 10)
        end)

        test.case("Go! si bara de progres inteleg aceeasi statie din `arg`", function()
            -- Butonul Go! deschide panoul pe statia din stationTarget, iar bara citeste nivelul
            -- aceleiasi statii. Daca ar parsa fiecare separat, Go! ar putea deschide Dock-ul in
            -- timp ce bara urmareste o plasa.
            local seen = 0
            for _, chapter in QuestConfig.ALL_CHAPTERS do
                for _, q in chapter.quests do
                    if q.kind == "level" then
                        seen += 1
                        local station, padId = QuestMath.stationTarget(q)
                        check.not_nil(station)
                        local over: { [string]: any } = {}
                        if station == "net" then
                            check.not_nil(padId)
                            over.netLevels = { [padId :: string] = 7 }
                        elseif station == "dock" then
                            over.dockLevel = 7
                        else
                            -- [D65, D67] un alt vanzator (Piata, Depoul): nivelul lui vine pe numele lui
                            check.is_true(station == "market" or station == "depot")
                            over.levels = { [station :: string] = 7 }
                        end
                        check.equal(QuestMath.progress(q, facts(over)), 7)
                    end
                end
            end
            check.is_true(seen >= 2)
            -- si un quest care nu e de nivel nu trimite nicaieri
            local firstStation = QuestMath.stationTarget(CHAPTER.quests[1])
            check.is_true(firstStation == nil)
        end)

        test.case("un quest necunoscut nu crapa, doar sta la zero", function()
            local bogus = { id = "x", text = "x", kind = "nope", goal = 1, reward = {} }
            check.equal(QuestMath.progress(bogus :: any, facts()), 0)
        end)
    end)

    test.suite("QuestMath - ordinea si starile", function()
        test.case("profil proaspat: primul e activ, restul inchise", function()
            local list = QuestMath.chapterStates(CHAPTER, facts())
            check.equal(stateOf(list, "cast_first"), "active")
            check.equal(stateOf(list, "collect_once"), "locked")
            check.equal(stateOf(list, "cast_second"), "locked") -- ultimul din capitolul 1
            check.equal(stateOf(list, "ring_bell"), "missing") -- e in capitolul 2
        end)

        test.case("terminat dar nerevendicat ramane in lista, cu Claim", function()
            local f = facts({ pads = { first_net = true } })
            local list = QuestMath.chapterStates(CHAPTER, f)
            check.equal(stateOf(list, "cast_first"), "done")
            check.equal(stateOf(list, "collect_once"), "active")
            check.equal(QuestMath.claimable(CHAPTER, f), 1)
        end)

        test.case(
            "lista: de revendicat sus, apoi nefacute, revendicatele la coada [owner]",
            function()
                local rows = {
                    { id = "a", state = "claimed" },
                    { id = "b", state = "claimed" },
                    { id = "c", state = "done" },
                    { id = "d", state = "active" },
                    { id = "e", state = "locked" },
                    { id = "f", state = "locked" },
                    { id = "g", state = "done" },
                }
                local order = QuestMath.displayOrder(rows, function(r)
                    return r.state
                end)
                local ids = {}
                for i, r in order do
                    ids[i] = r.id
                end
                check.equal(table.concat(ids, ","), "c,g,d,e,f,a,b")
                -- lista primita ramane neatinsa: butonul Claim citeste randul afisat, nu indexul din capitol
                check.equal(rows[1].id, "a")
                -- pe capitolul adevarat: dupa primele doua revendicate si al treilea terminat
                local f = facts({
                    pads = { first_net = true },
                    collected = 12,
                    sawn = 12,
                    claimed = { cast_first = true, collect_once = true },
                })
                local real = QuestMath.displayOrder(QuestMath.chapterStates(CHAPTER, f), function(q)
                    return q.state
                end)
                check.equal(real[1].id, "saw_once")
                check.equal(real[1].state, "done")
                check.equal(real[2].state, "active")
                check.equal(real[#real].id, "collect_once")
                check.equal(real[#real - 1].id, "cast_first")
            end
        )

        test.case("dupa revendicare nu se mai poate revendica", function()
            local f = facts({ pads = { first_net = true }, claimed = { cast_first = true } })
            check.equal(stateOf(QuestMath.chapterStates(CHAPTER, f), "cast_first"), "claimed")
            check.equal(QuestMath.claimable(CHAPTER, f), 0)
        end)

        test.case("un singur quest activ, oricat de departe ai ajunge", function()
            for _, f in
                {
                    facts(),
                    facts({ pads = { first_net = true }, collected = 9 }),
                    facts({
                        pads = { first_net = true, second_net = true },
                        collected = 30,
                        sawn = 30,
                        sold = 20,
                        netLevels = { first_net = 7 },
                    }),
                }
            do
                local active = 0
                for _, q in QuestMath.chapterStates(CHAPTER, f) do
                    if q.state == "active" then
                        active += 1
                    end
                end
                check.is_true(active <= 1)
            end
        end)

        test.case("active() e chiar primul neterminat", function()
            local f = facts({ pads = { first_net = true }, collected = 12 })
            local quest = QuestMath.active(CHAPTER, f) :: QuestConfig.Quest
            check.equal(quest.id, "saw_once")
            -- cu doar 11 bustean colectati, plasa plina inca nu e bifata
            local short = facts({ pads = { first_net = true }, collected = 11 })
            check.equal((QuestMath.active(CHAPTER, short) :: QuestConfig.Quest).id, "collect_once")
        end)

        test.case("tot capitolul terminat: nu mai e niciun activ", function()
            local f = facts({
                pads = {
                    first_net = true,
                    first_runner = true,
                    hire_porter = true,
                    hire_sawyer = true,
                    hire_hauler = true,
                    dock_trader = true,
                    second_net = true,
                },
                collected = 50,
                sawn = 50,
                sold = 50,
                -- [D62] un peste scos si un lucru construit de la avizier
                fished = 1,
                decor = 1,
                -- si prima plasa peste nivelul 2: fara el, quest-ul `net_two` ramane deschis
                netLevels = { first_net = 12 },
            })
            check.is_true(QuestMath.active(CHAPTER, f) == nil)
            check.equal(QuestMath.completed(CHAPTER, f), #CHAPTER.quests)
        end)

        test.case("progresul afisat nu trece niciodata de tinta", function()
            local f = facts({ collected = 999, sawn = 999, sold = 999 })
            for _, q in QuestMath.chapterStates(CHAPTER, f) do
                check.is_true(q.progress <= q.goal)
            end
        end)
    end)

    test.suite("QuestConfig - forma capitolului", function()
        test.case("id-uri unice in tot jocul, fiecare quest cu recompensa", function()
            -- 13: lantul de mana (prinzi, strangi, tai, vinzi), cei cinci oameni, [D62] undita si avizierul satului,
            -- apoi nivelul 2 si a doua plasa [D52]
            check.equal(#CHAPTER.quests, 13)
            local seen: { [string]: boolean } = {}
            local dupes, noReward = 0, 0
            local all = {}
            for _, ch in QuestConfig.ALL_CHAPTERS do
                for _, q in ch.quests do
                    table.insert(all, q)
                end
            end
            for _, q in all do
                if seen[q.id] then
                    dupes += 1
                end
                seen[q.id] = true
                if (q.reward.coins or 0) + (q.reward.pearls or 0) <= 0 then
                    noReward += 1
                end
            end
            check.equal(dupes, 0)
            check.equal(noReward, 0)
        end)

        test.case(
            "nicio recompensa de quest in monede: monedele vin doar din vanzare [D51]",
            function()
                -- 95 de monede in primele quest-uri cumparau plasele 2 si 3 inainte ca lemnul sa treaca
                -- prin lant -- exact ce a vazut owner-ul
                for _, ch in QuestConfig.ALL_CHAPTERS do
                    check.is_true(ch.reward.coins == nil)
                    for _, q in ch.quests do
                        check.is_true(q.reward.coins == nil)
                    end
                end
            end
        )

        test.case("fiecare tinta de quest e o platforma care exista chiar in joc", function()
            local TycoonConfig = require("../src/Shared/Config/TycoonConfig")
            local FlowConfig = require("../src/Shared/Config/FlowConfig")
            local missing = 0
            for _, ch in QuestConfig.ALL_CHAPTERS do
                for _, q in ch.quests do
                    if q.targetPad ~= nil and TycoonConfig.byId[q.targetPad] == nil then
                        missing += 1
                    end
                    -- [D65] un loc al Morii: atelierul unei linii sau un vanzator, din tabelul drumului marfii
                    -- [D70] si locurile barajului, scrise dar adormite (FlowConfig.FULL)
                    -- si exact cum il citeste clientul (Overlay): inelul atelierului sau al unirii, ori usa vanzatorului
                    if q.targetPlace ~= nil then
                        local spec = FlowConfig.FULL.byProcessor[q.targetPlace]
                        local places = if spec ~= nil
                            then TycoonConfig.LINE_PLACES[spec.line]
                                or TycoonConfig.JOIN_PLACES[spec.line]
                            else nil
                        local seller = TycoonConfig.SELLER_PLACES[q.targetPlace]
                        local stand = if places ~= nil then places.playerStand else nil
                        local door = if seller ~= nil then seller.door else nil
                        if stand == nil and door == nil then
                            print(`[QuestMath] {q.id}: locul "{q.targetPlace}" n-are inel sau usa`)
                            missing += 1
                        end
                    end
                    if q.kind == "pad" and TycoonConfig.byId[q.arg :: string] == nil then
                        missing += 1
                    end
                end
            end
            check.equal(missing, 0)
        end)

        test.case("niciun quest nu cere ceva ce inca nu se poate cumpara", function()
            -- BUGUL PE CARE IL APARA: prima varianta cerea Negustorul (care vrea 3 plase) imediat
            -- dupa prima Mana, cand aveai doar 2 -- si niciun quest nu cerea a treia plasa. Ai fi
            -- ramas blocat, cu bannerul aratand spre ceva ce nu puteai lua. Testul parcurge toate
            -- capitolele in ordine si verifica, la fiecare pas, ca deblocarea ceruta e chiar
            -- disponibila cu ce ai cumparat pana atunci.
            -- CU NIVELURI: plasa urmatoare apare abia cand cea dinainte e la PREV_NET_LEVEL. Fara
            -- `levels`, testul ar fi trecut si cu lista veche -- care cerea a treia plasa cat timp
            -- a doua era inca la nivelul 1, adica exact contradictia vazuta in Studio.
            local TycoonMath = require("../src/Shared/Modules/TycoonMath")
            local TycoonConfig = require("../src/Shared/Config/TycoonConfig")
            -- [D65] TOATE capitolele scrise, cu toate platformele socotite in joc: ordinea Erei 2 se verifica inainte
            -- ca platformele ei sa devina `live`, nu dupa.
            local livePads: { TycoonConfig.Pad } = {}
            for _, p in TycoonConfig.PADS do
                local copy = table.clone(p)
                copy.live = true
                table.insert(livePads, copy)
            end
            local bought: { [string]: boolean } = {}
            local levels: { [string]: number } = {}
            local blocked = {}
            -- [D70] la baraj: ce da el gratis (pret 0 in Era 4: turbina, Cable Net, veteranii) e al tau de la intrare,
            -- conditiile se numara pe lista lumii 2 (R3), iar un quest de venit implineste o conditie de venit de dupa el
            local WorldConfig = require("../src/Shared/Config/WorldConfig")
            local income = 0
            local world = 1
            local function listOf(w: number): { TycoonConfig.Pad }
                local out = {}
                for _, p in livePads do
                    if WorldConfig.worldOfEra(p.era) == w then
                        table.insert(out, p)
                    end
                end
                return out
            end
            for _, ch in QuestConfig.ALL_CHAPTERS do
                local chWorld = WorldConfig.worldOfEra(ch.era)
                if chWorld ~= world then
                    world = chWorld
                    for _, p in listOf(world) do
                        if p.price == 0 and p.era == ch.era then
                            bought[p.id] = true
                            levels[p.id] = levels[p.id] or 1
                        end
                    end
                end
                for _, q in ch.quests do
                    if q.kind == "income" then
                        income = math.max(income, q.goal)
                    elseif q.kind == "level" then
                        local station, netId = QuestMath.stationTarget(q)
                        if station == "net" and netId ~= nil then
                            if not bought[netId :: string] then
                                table.insert(blocked, `{q.id} urca {netId}, care nu e cumparata`)
                            end
                            levels[netId :: string] = math.max(levels[netId :: string] or 1, q.goal)
                        end
                    elseif q.kind == "pad" then
                        local padId = q.arg :: string
                        local status =
                            TycoonMath.padStatuses(bought, listOf(world), levels, income, 1)[padId]
                        if status ~= "available" then
                            table.insert(
                                blocked,
                                `{q.id} cere {padId}, dar e "{status or "ascunsa"}"`
                            )
                        end
                        bought[padId] = true
                        levels[padId] = levels[padId] or 1
                    end
                end
            end
            for _, line in blocked do
                print("  ! " .. line)
            end
            check.equal(#blocked, 0)
        end)

        test.case("quest-ul de nivel cere EXACT nivelul care deschide plasa urmatoare", function()
            -- Daca quest-ul ar cere 5 si poarta ar fi 2, plasa urmatoare s-ar deschide la 2 in timp
            -- ce banda de obiectiv inca cere 5 -- lumea si ghidajul s-ar contrazice iar.
            local TycoonConfig = require("../src/Shared/Config/TycoonConfig")
            -- [D56] quest-urile in sir, peste capitole: nivelul plasei a patra incheie capitolul 2, iar plasa a
            -- cincea vine in capitolul 3
            local all = {}
            for _, ch in QuestConfig.ALL_CHAPTERS do
                for _, q in ch.quests do
                    table.insert(all, q)
                end
            end
            local seen = 0
            for i, q in all do
                local nextQ = all[i + 1]
                local station = QuestMath.stationTarget(q)
                if station == "net" and nextQ ~= nil and nextQ.kind == "pad" then
                    seen += 1
                    check.equal(q.goal, TycoonConfig.PREV_NET_LEVEL)
                end
            end
            -- inaintea plasei 2, 3, 4 si a Forge (dupa ea, plasa 5); [D65] la fel la Moara: 7, 8, 9 si cuptorul de cupru;
            -- [D67] si la Wire Works: 12, 13, 14 si Power House
            check.equal(seen, 14) -- [D70] +2: plasele de cablu
        end)

        test.case("textul unui quest de nivel spune nivelul pe care il si cere", function()
            -- "Upgrade First Net to level 5" cu goal = 2 ar minti exact acolo unde jucatorul se uita
            -- cel mai des [D40]. Cifra din text trebuie sa fie chiar `goal`.
            for _, ch in QuestConfig.ALL_CHAPTERS do
                for _, q in ch.quests do
                    if q.kind == "level" then
                        check.is_true(string.find(q.text, `level {q.goal}`, 1, true) ~= nil)
                    end
                end
            end
        end)

        test.case("ultimul quest inchide chiar era: dupa el nu mai e nimic de cumparat", function()
            local TycoonConfig = require("../src/Shared/Config/TycoonConfig")
            local bought: { [string]: boolean } = {}
            for _, ch in QuestConfig.ALL_CHAPTERS do
                for _, q in ch.quests do
                    if q.kind == "pad" then
                        bought[q.arg :: string] = true
                    end
                end
            end
            -- [D65] la fel Era 2: capitolele ei cer fiecare platforma a ei, iar ultimul quest e clopotul Morii
            -- [D70] erele fara capitole scrise inca nu se numara: capitolele 10-12 ale barajului vin la pasul j11
            local chaptered: { [number]: boolean } = {}
            for _, ch in QuestConfig.ALL_CHAPTERS do
                chaptered[ch.era] = true
            end
            local left = 0
            for _, p in TycoonConfig.PADS do
                -- [D70] ce da barajul gratis (pret 0 in Era 4) n-are quest
                local damGift = p.era == 4 and p.price == 0
                if chaptered[p.era] and not bought[p.id] and not damGift then
                    left += 1
                end
            end
            check.equal(left, 0)
            for era = 1, 2 do
                local last: QuestConfig.Quest? = nil
                for _, ch in QuestConfig.ALL_CHAPTERS do
                    if ch.era == era then
                        last = ch.quests[#ch.quests]
                    end
                end
                local pad = TycoonConfig.byId[(last :: QuestConfig.Quest).arg :: string]
                check.equal(pad.motive, "D")
                check.equal(pad.era, era)
            end
        end)

        test.case(
            "chapterClosedBy: capitolul se incheie la ULTIMA revendicare, oricare ar fi ea [D62]",
            function()
                local first = QuestConfig.CHAPTERS[1]
                local claimed: { [string]: boolean } = {}
                -- toate, mai putin doua: nicio revendicare din cele doua nu-l incheie singura
                for i, q in first.quests do
                    if i > 2 then
                        claimed[q.id] = true
                    end
                end
                check.is_true(QuestMath.chapterClosedBy(first.quests[1].id, claimed) == nil)
                -- a doua ramasa il incheie, chiar daca nu e ultimul quest din lista
                claimed[first.quests[2].id] = true
                check.equal(QuestMath.chapterClosedBy(first.quests[1].id, claimed), first)
                -- un quest din alt capitol nu incheie capitolul 1
                local second = QuestConfig.CHAPTERS[2]
                check.is_true(QuestMath.chapterClosedBy(second.quests[1].id, claimed) == nil)
                check.is_true(QuestMath.chapterClosedBy("nu_exista", claimed) == nil)
            end
        )

        test.case("fiecare capitol are o recompensa de platit la incheiere [D62]", function()
            for _, ch in QuestConfig.ALL_CHAPTERS do
                check.is_true((ch.reward.pearls or 0) + (ch.reward.coins or 0) > 0)
            end
        end)

        test.case("[D65] in joc sunt doar capitolele erelor cu platforme `live`", function()
            local TycoonConfig = require("../src/Shared/Config/TycoonConfig")
            local want = 0
            for _, ch in QuestConfig.ALL_CHAPTERS do
                if TycoonConfig.eraIsLive(ch.era) then
                    want += 1
                end
            end
            check.equal(#QuestConfig.CHAPTERS, want)
            for _, ch in QuestConfig.CHAPTERS do
                check.is_true(TycoonConfig.eraIsLive(ch.era))
            end
            -- altfel, dupa clopotul Erei 1, capitolul 4 ar cere o roata de apa pe care n-o poti construi
            check.equal(#QuestConfig.ALL_CHAPTERS, 12) -- [D67] capitolele 7-9, ale Erei 3; [D70] 10-12, ale barajului
        end)

        test.case("[D65] quest-urile Morii se citesc din numaratorile si nivelurile ei", function()
            local function of(id: string): QuestConfig.Quest
                return QuestConfig.byId[id]
            end
            local f = facts({})
            f.stats = { cast = 4, partsSold = 12, copperSmelted = 0, copperSold = 3 }
            f.levels = { market = 7 }
            check.equal(QuestMath.progress(of("cast_parts"), f), 4)
            check.is_true(QuestMath.isDone(of("sell_parts"), f))
            check.equal(QuestMath.progress(of("smelt_copper"), f), 0)
            check.equal(QuestMath.progress(of("sell_copper"), f), 3)
            check.equal(QuestMath.progress(of("market_ten"), f), 7)
            check.equal((QuestMath.stationTarget(of("market_ten"))), "market")
            -- fara numaratori (un profil vechi, o stare de test): zero, nu eroare
            check.equal(QuestMath.progress(of("cast_parts"), facts({})), 0)
        end)
    end)
    -- [D70, pasul j11] quest-urile pe lume, quest-ul de venit, R7 si plata de la trecere
    test.suite("QuestMath - barajul [D70, pasul j11]", function()
        local function facts(
            claimed: { [string]: boolean },
            extra: { [string]: any }?
        ): QuestMath.Facts
            local f: any = {
                pads = {},
                collects = 0,
                sells = 0,
                sawn = 0,
                collected = 0,
                sold = 0,
                netLevels = {},
                dockLevel = 1,
                idleRate = 0,
                claimed = claimed,
            }
            for k, v in extra or {} do
                f[k] = v
            end
            return f
        end

        test.case("totul revendicat si AWAY 0: capitolul curent nu mai e 1 (R7)", function()
            -- pe capitolele satului (fara lume in fapte), ca testul sa nu depinda de comutatorul l3
            local village = QuestConfig.chaptersOfWorld(1)
            local claimed: { [string]: boolean } = {}
            for _, ch in village do
                for _, q in ch.quests do
                    claimed[q.id] = true
                end
            end
            local f = facts(claimed)
            local current = QuestMath.currentChapter(f)
            check.is_true(current.id ~= QuestConfig.CHAPTERS[1].id)
            check.equal(current.id, village[#village].id)
            check.is_true(QuestMath.isLastOfWorld(current, nil))
            check.is_false(QuestMath.isLastOfWorld(village[1], 1))
            -- quest-ul AWAY, revendicat demult si acum sub tinta, nu mai e activ
            check.equal(QuestMath.active(QuestConfig.CHAPTERS[1], f), nil)
        end)

        test.case(
            "quest-ul de venit: pragul din StationConfig, dublu cu 2x Flow; contorul ca pe HUD",
            function()
                local StationConfig = require("../src/Shared/Config/StationConfig")
                local bell = QuestConfig.byId.earn_bell
                local kiln = QuestConfig.byId.earn_kiln
                check.equal(bell.kind, "income")
                check.equal(bell.goal, StationConfig.DAM_BELL_INCOME)
                check.equal(kiln.goal, StationConfig.KILN_INCOME)
                local plain = facts({}, { income = 5e12, flowFactor = 1 })
                local doubled = facts({}, { income = 5e12, flowFactor = 2 })
                check.equal(QuestMath.goalOf(bell, plain), 4e12)
                check.equal(QuestMath.goalOf(bell, doubled), 8e12)
                check.is_true(QuestMath.isDone(bell, plain))
                check.is_false(QuestMath.isDone(bell, doubled))
                check.equal(QuestMath.counterText(bell, 5e12, 8e12), "5T/8T")
                check.equal(QuestMath.counterText(bell, 9e12, 8e12), "8T/8T")
                check.equal(QuestMath.counterText(QuestConfig.byId.spin_cable, 3, 10), "3/10")
                -- starea capitolului poarta tinta cu pass-ul
                local chapter = nil
                for _, ch in QuestConfig.ALL_CHAPTERS do
                    if ch.id == "cold_fire" then
                        chapter = ch
                    end
                end
                local seen = 0
                for _, st in QuestMath.chapterStates(chapter :: any, doubled) do
                    if st.id == "earn_bell" then
                        check.equal(st.goal, 8e12)
                        -- eticheta spune aceeasi cifra ca tinta si ca cartonasul clopotului (D40)
                        check.equal(st.text, "Earn 8T coins a second")
                        seen += 1
                    end
                end
                check.equal(seen, 1)
                check.equal(QuestMath.textOf(kiln, doubled), "Earn 2T coins a second")
                -- fara pass, textul din config; iar textul din config e chiar pragul din StationConfig
                local TycoonMath = require("../src/Shared/Modules/TycoonMath")
                local Strings = require("../src/Shared/Config/Strings")
                for _, ch in QuestConfig.ALL_CHAPTERS do
                    for _, q in ch.quests do
                        if q.kind == "income" then
                            check.equal(
                                q.text,
                                Strings.earnPerSecond(TycoonMath.formatNumber(q.goal))
                            )
                            check.equal(QuestMath.textOf(q, plain), q.text)
                            check.equal(QuestMath.textOf(q, facts({})), q.text)
                        else
                            check.equal(QuestMath.textOf(q, doubled), q.text)
                        end
                    end
                end
            end
        )

        test.case("capitolele pe lume: satul are 1-9, barajul (adormit) inca niciunul", function()
            local TycoonConfig = require("../src/Shared/Config/TycoonConfig")
            local village = QuestConfig.chaptersOfWorld(1)
            local villageInGame = 0
            for _, ch in QuestConfig.CHAPTERS do
                if ch.era <= 3 then
                    villageInGame += 1
                end
            end
            check.equal(#village, villageInGame)
            -- independent de comutator: barajul are capitolele lui abia cand Era 4 e in joc (l3)
            check.equal(#QuestConfig.chaptersOfWorld(2), if TycoonConfig.eraIsLive(4) then 3 else 0)
            check.is_true(QuestConfig.chaptersOfWorld(nil)[1] == village[1])
            -- toate capitolele scrise ale barajului sunt ale Erei 4, in ordinea simulatorului
            local dam = {}
            for _, ch in QuestConfig.ALL_CHAPTERS do
                if ch.era == 4 then
                    table.insert(dam, ch.id)
                end
            end
            check.equal(table.concat(dam, ","), "the_dam,miles_of_cable,cold_fire")
        end)

        test.case(
            "la trecere: tot ce n-ai revendicat din sat, in perle, cu capitolele neincheiate",
            function()
                local total = 0
                local quests = 0
                for _, ch in QuestConfig.ALL_CHAPTERS do
                    if ch.era <= 3 then
                        total += ch.reward.pearls or 0
                        for _, q in ch.quests do
                            total += q.reward.pearls or 0
                            quests += 1
                        end
                    end
                end
                local nothing = QuestMath.settleWorld({}, 1)
                check.equal(nothing.pearls, total)
                check.equal(#nothing.quests, quests)
                -- capitolul 1 revendicat in intregime: nici quest-urile, nici recompensa lui
                local claimed: { [string]: boolean } = {}
                local first = QuestConfig.ALL_CHAPTERS[1]
                local firstSum = first.reward.pearls or 0
                for _, q in first.quests do
                    claimed[q.id] = true
                    firstSum += q.reward.pearls or 0
                end
                local rest = QuestMath.settleWorld(claimed, 1)
                check.equal(rest.pearls, total - firstSum)
                check.equal(#rest.quests, quests - #first.quests)
                -- un capitol inceput: quest-urile ramase si recompensa capitolului
                local half = table.clone(claimed)
                half[QuestConfig.ALL_CHAPTERS[2].quests[1].id] = true
                local paidHalf = QuestMath.settleWorld(half, 1)
                check.equal(
                    paidHalf.pearls,
                    rest.pearls - (QuestConfig.ALL_CHAPTERS[2].quests[1].reward.pearls or 0)
                )
                -- totul revendicat: nimic
                local all: { [string]: boolean } = {}
                for _, id in nothing.quests do
                    all[id] = true
                end
                check.equal(QuestMath.settleWorld(all, 1).pearls, 0)
            end
        )

        test.case(
            "serverul refuza quest-urile altei lumi; uneltele de dev nu scriu venitul",
            function()
                local fs = require("@lune/fs")
                local service = fs.readFile("src/Server/Services/QuestService.luau")
                local claim =
                    string.match(service, "function QuestService%.Claim%(.-\nend") :: string
                check.is_true(string.find(claim, "chaptersOfWorld(facts.world)", 1, true) ~= nil)
                check.is_true(string.find(claim, '"closed"', 1, true) ~= nil)
                local dev = fs.readFile("src/Server/Services/DevService.luau")
                check.is_true(string.find(dev, 'quest.kind ~= "income"', 1, true) ~= nil)
            end
        )
    end)
end
