--!strict
-- Capitolele si quest-urile. Copiaza structura din Idle Miner [capturile owner-ului]: un capitol
-- are un titlu, o bara de progres si o lista de quest-uri care se deschid IN ORDINE -- unul singur
-- activ, restul "Quest locked" cu lacat, iar cele terminate raman in lista cu butonul `Claim`.
--
-- FIECARE QUEST PREDA UN LUCRU. Nu sunt sarcini puse ca sa existe: capitolul 1 e chiar drumul prin
-- care jucatorul descopera, pe rand, ca se cumpara calcand, ca plasa se goleste, unde se fac banii,
-- ca se urca nivelul, ca treaba se da altcuiva, si ca venitul pasiv se castiga.
--
-- PROGRESUL NU SE NUMARA PE EVENIMENTE, se CITESTE din stare (QuestMath): daca un jucator a urcat
-- debarcaderul la nivel 5 inainte sa se deschida quest-ul care cere asta, quest-ul e gata pe loc.
-- Asa nu exista "am facut deja, dar nu s-a bifat" -- clasa de bug care strica orice lista de
-- sarcini, si care nu poate aparea daca nimeni nu numara nimic.
local QuestConfig = {}

export type Reward = { coins: number?, pearls: number? }

export type Quest = {
    id: string,
    text: string,
    -- ce se citeste din stare: "pad" (detii platforma) | "collected" / "sold" (bucati, D51) | "sawn" |
    -- "smelted" (fier topit la forja, D55) | "ironSold" (fier predat la taverna, D56) | "level" | "idle" |
    -- "fished" (pesti scosi la undita, D59) (plus "collects" / "sells", gesturi, ramase doar ca feluri cunoscute)
    kind: string,
    arg: string?, -- padId pentru "pad"; "net:<padId>" / "dock" pentru "level"
    goal: number,
    reward: Reward,
    -- unde arata sageata cat timp quest-ul e activ; nil = nicaieri (nu ai unde sa te duci)
    targetPad: string?,
    targetDock: boolean?,
    targetSawmill: boolean?, -- sageata arata gaterul [D48]
    targetForge: boolean?, -- sageata arata inelul forjei [D56]
    targetFish: boolean?, -- sageata arata capatul pontonului, unde pescuiesti [D59]
}

export type Chapter = {
    id: string,
    title: string,
    subtitle: string,
    reward: Reward,
    quests: { Quest },
}

-- ORDINEA E VERIFICATA FATA DE CONDITIILE DEBLOCARILOR (TycoonConfig.needs). Prima varianta cerea
-- Negustorul imediat dupa prima Mana, cand el cerea trei plase si niciun quest nu cerea a treia:
-- jucatorul ar fi ramas blocat, cu bannerul aratand spre ceva ce nu putea lua. Iar clopotul cere TOT
-- restul erei cumparat, deci nu poate incheia un capitol in care jumatate din platforme n-au fost
-- cerute niciodata. De aici doua capitole, si testul care le tine in ordine.
QuestConfig.CHAPTERS = {
    {
        -- CAPITOLUL 1 PREDA LANTUL IN ORDINEA LUI [D49]: prinzi, strangi, tai, vinzi -- intai tot de
        -- mana, o singura data, apoi TOTI CINCI oamenii la rand, fiecare luandu-ti de pe umeri pasul pe
        -- care tocmai l-ai facut, si abia apoi plasele [D52]. Owner-ul: "vreau ca playerul sa faca o
        -- singura data un tur net - sawmill - tavern iar al doilea tur sa isi deblocheze treptat
        -- npc-urile. in prezent te pune sa iti faci x nets si mai apoi npc-urile, ceea ce este gresit".
        --
        -- [D51] Owner-ul: "te impinge sa iti faci net-uri cat mai multe dar fara materiale". Doua cauze,
        -- amandoua reparate aici: (1) bucla se bifa dintr-un singur bustean (1 colectare, 1 scandura,
        -- 1 predare), deci jucatorul n-o facea niciodata cu adevarat; acum cere o plasa plina, taiata si
        -- vanduta toata. (2) Primele recompense dadeau 95 de monede, cat plasele 2 si 3 -- se cumparau
        -- din recompense, nu din lemn vandut. Acum toate recompensele sunt perle: monedele vin doar din
        -- vanzare. Ordinea urmeaza ordinea cumpararilor din simulator.
        id = "landing",
        title = "Chapter 1",
        subtitle = "The Landing",
        reward = { pearls = 5 },
        quests = {
            {
                id = "cast_first",
                text = "Cast your first net",
                kind = "pad",
                arg = "first_net",
                goal = 1,
                reward = { pearls = 1 },
                targetPad = "first_net",
            },
            {
                -- O plasa PLINA (12, capacitatea de la nivelul 1): prima data se umple mai repede, doar
                -- pentru tutorial (TycoonMath.catchBoost) [owner, 2026-09-13].
                id = "collect_once",
                text = "Collect a full net",
                kind = "collected",
                goal = 12,
                reward = { pearls = 1 },
                targetPad = "first_net",
            },
            {
                -- Nimic nu se vinde brut: bustenii trec prin gater, iar fara Sawyer taie doar cat stai
                -- langa el [D49]. TOATE cele 12: owner-ul, "trebuie sa il puna sa stea pana cand tot
                -- driftwood-ul este gata plank".
                id = "saw_once",
                text = "Cut the logs into planks",
                kind = "sawn",
                goal = 12,
                reward = { pearls = 1 },
                targetSawmill = true,
            },
            {
                -- Id-ul ramane `sell_once` (un quest redenumit s-ar putea revendica a doua oara):
                -- se schimba doar ce cere si unde arata. Taverna primeste doar ce e taiat.
                id = "sell_once",
                text = "Sell the planks at the tavern",
                kind = "sold",
                goal = 12,
                reward = { pearls = 2 },
                targetDock = true,
            },
            {
                -- Id-ul vechi (`hire_hand`), acum pentru Collector: id-urile de quest nu se schimba.
                id = "hire_hand",
                text = "Hire a Collector",
                kind = "pad",
                arg = "first_runner",
                goal = 1,
                reward = { pearls = 1 },
                targetPad = "first_runner",
            },
            {
                id = "hire_porter",
                text = "Hire a Porter",
                kind = "pad",
                arg = "hire_porter",
                goal = 1,
                reward = { pearls = 1 },
                targetPad = "hire_porter",
            },
            {
                id = "hire_sawyer",
                text = "Hire a Sawyer",
                kind = "pad",
                arg = "hire_sawyer",
                goal = 1,
                reward = { pearls = 1 },
                targetPad = "hire_sawyer",
            },
            {
                id = "hire_hauler",
                text = "Hire a Hauler",
                kind = "pad",
                arg = "hire_hauler",
                goal = 1,
                reward = { pearls = 1 },
                targetPad = "hire_hauler",
            },
            {
                -- Ultimul din cei cinci: de aici taverna vinde singura si jocul merge si cand nu esti acolo.
                -- 3 perle, nu 1: aici se incheie ce preda capitolul, iar cele 2 perle ale lui `sell_forty` (scos
                -- in D52) nu se pierd din total.
                id = "hire_trader",
                text = "Hire an Innkeeper",
                kind = "pad",
                arg = "dock_trader",
                goal = 1,
                reward = { pearls = 3 },
                targetPad = "dock_trader",
            },
            {
                -- Nivelul 2, nu 5: exact cat cere TycoonConfig.PREV_NET_LEVEL ca sa apara a doua
                -- plasa. Cu 5, lumea deschidea plasa urmatoare la nivelul 2 in timp ce banda de
                -- obiectiv inca cerea 5 -- owner-ul a vazut contradictia in Studio (2026-09-12).
                id = "net_two",
                text = "Upgrade your net to level 2",
                kind = "level",
                arg = "net:first_net",
                goal = 2,
                reward = { pearls = 1 },
                targetPad = "first_net",
            },
            {
                id = "cast_second",
                text = "Cast a second net",
                kind = "pad",
                arg = "second_net",
                goal = 1,
                reward = { pearls = 1 },
                targetPad = "second_net",
            },
        },
    },
    {
        id = "deeper",
        title = "Chapter 2",
        subtitle = "Deeper Water",
        reward = { pearls = 8 },
        quests = {
            {
                -- Plasa urmatoare apare abia cand asta e la TycoonConfig.PREV_NET_LEVEL. Fara
                -- quest-ul asta, banda ar cere plasa urmatoare cat timp ea sta inca incuiata.
                id = "second_two",
                text = "Upgrade Second Net to level 2",
                kind = "level",
                arg = "net:second_net",
                goal = 2,
                reward = { pearls = 1 },
                targetPad = "second_net",
            },
            {
                id = "cast_third",
                text = "Cast a third net",
                kind = "pad",
                arg = "third_net",
                goal = 1,
                reward = { pearls = 2 },
                targetPad = "third_net",
            },
            {
                id = "big_sack",
                text = "Get a Bigger Sack",
                kind = "pad",
                arg = "bigger_sack",
                goal = 1,
                reward = { pearls = 1 },
                targetPad = "bigger_sack",
            },
            {
                -- [D59] UNDITA SE INVATA AICI: dupa traista mare incepe prima strangere lunga de bani (plasa a patra,
                -- al doilea Collector), iar ghidajul tace deja (cei cinci oameni sunt angajati). Quest-ul isi are
                -- sageata spre capatul pontonului chiar si asa -- o singura exceptie numita, in GuideMath. Un peste,
                -- nu zece: pescuitul doar adauga, nu se cere [D59].
                id = "catch_fish",
                text = "Catch a fish at the pier",
                kind = "fished",
                goal = 1,
                reward = { pearls = 3 },
                targetFish = true,
            },
            {
                -- Plasa urmatoare apare abia cand asta e la TycoonConfig.PREV_NET_LEVEL. Fara
                -- quest-ul asta, banda ar cere plasa urmatoare cat timp ea sta inca incuiata.
                id = "third_two",
                text = "Upgrade Third Net to level 2",
                kind = "level",
                arg = "net:third_net",
                goal = 2,
                reward = { pearls = 1 },
                targetPad = "third_net",
            },
            {
                id = "cast_fourth",
                text = "Cast a fourth net, further out",
                kind = "pad",
                arg = "far_lane_net",
                goal = 1,
                reward = { pearls = 3 },
                targetPad = "far_lane_net",
            },
            {
                -- Venitul pasiv cere toate cinci meseriile [D49]: fara oricare om, pasul lui sta cand nu esti
                -- acolo. Oamenii vin toti in capitolul 1 [D52]; quest-ul ramane aici, cand venitul chiar se simte.
                id = "idle_one",
                text = "Earn 1 coin a second while away",
                kind = "idle",
                goal = 1,
                reward = { pearls = 2 },
            },
            {
                id = "dock_ten",
                text = "Upgrade the Tavern to level 10",
                kind = "level",
                arg = "dock",
                goal = 10,
                reward = { pearls = 2 },
            },
            {
                -- Plasa urmatoare apare abia cand asta e la TycoonConfig.PREV_NET_LEVEL. Fara
                -- quest-ul asta, banda ar cere plasa urmatoare cat timp ea sta inca incuiata.
                id = "fourth_two",
                text = "Upgrade Fourth Net to level 2",
                kind = "level",
                arg = "net:far_lane_net",
                goal = 2,
                reward = { pearls = 1 },
                targetPad = "far_lane_net",
            },
        },
    },
    {
        -- [D56] CAPITOLUL 3 PREDA LINIA FIERULUI CA PE A LEMNULUI: forja, plasa care aduce scrap, un tur de mana
        -- (culegi, topesti stand in inel, vinzi), apoi shed-ul si cei patru oameni la rand, fiecare luandu-ti un pas
        -- de pe umeri. Owner-ul: "scraps nu are om npc care se ocupa de transport la storage, dupa transport la
        -- workshop, dupa cineva care prelucreaza, dupa cineva care le duce la tavern". Id-urile deja salvate in
        -- profiluri raman acolo unde sensul e acelasi (profilul tine quest-urile luate pe id).
        id = "iron",
        title = "Chapter 3",
        subtitle = "The Iron Line",
        reward = { pearls = 8 },
        quests = {
            {
                id = "build_workshop",
                text = "Build the Forge",
                kind = "pad",
                arg = "workshop",
                goal = 1,
                reward = { pearls = 3 },
                targetPad = "workshop",
            },
            {
                id = "cast_fifth",
                text = "Cast a fifth net in the deep channel",
                kind = "pad",
                arg = "fifth_net",
                goal = 1,
                reward = { pearls = 3 },
                targetPad = "fifth_net",
            },
            {
                -- turul de mana: culegi scrap-ul, il duci la forja si stai in inel cat se topeste
                id = "smelt_iron",
                text = "Smelt 10 iron at the Forge",
                kind = "smelted",
                goal = 10,
                reward = { pearls = 2 },
                targetForge = true,
            },
            {
                id = "sell_iron",
                text = "Sell the iron at the tavern",
                kind = "ironSold",
                goal = 10,
                reward = { pearls = 2 },
                targetDock = true,
            },
            {
                id = "build_shed",
                text = "Build the Scrap Shed",
                kind = "pad",
                arg = "scrap_shed",
                goal = 1,
                reward = { pearls = 1 },
                targetPad = "scrap_shed",
            },
            {
                id = "hire_scrap_collector",
                text = "Hire a Scrap Collector",
                kind = "pad",
                arg = "hire_scrap_collector",
                goal = 1,
                reward = { pearls = 1 },
                targetPad = "hire_scrap_collector",
            },
            {
                id = "hire_scrap_porter",
                text = "Hire a Scrap Porter",
                kind = "pad",
                arg = "hire_scrap_porter",
                goal = 1,
                reward = { pearls = 1 },
                targetPad = "hire_scrap_porter",
            },
            {
                id = "hire_smelter",
                text = "Hire a Smelter",
                kind = "pad",
                arg = "hire_smelter",
                goal = 1,
                reward = { pearls = 1 },
                targetPad = "hire_smelter",
            },
            {
                id = "hire_iron_hauler",
                text = "Hire an Iron Hauler",
                kind = "pad",
                arg = "hire_iron_hauler",
                goal = 1,
                reward = { pearls = 2 },
                targetPad = "hire_iron_hauler",
            },
            {
                id = "ring_bell",
                text = "Ring the Landing Bell",
                kind = "pad",
                arg = "landing_bell",
                goal = 1,
                reward = { pearls = 5 },
                targetPad = "landing_bell",
            },
        },
    },
} :: { Chapter }

QuestConfig.byId = {} :: { [string]: Quest }
for _, chapter in QuestConfig.CHAPTERS do
    for _, quest in chapter.quests do
        QuestConfig.byId[quest.id] = quest
    end
end

return QuestConfig
