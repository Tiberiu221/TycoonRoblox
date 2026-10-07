--!strict
-- Capitolele si quest-urile, in tiparul genului idle (inspirat de Idle Miner): un capitol
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
local TycoonConfig = require(script and script.Parent.TycoonConfig or "./TycoonConfig")
local StationConfig = require(script and script.Parent.StationConfig or "./StationConfig")
local WorldConfig = require(script and script.Parent.WorldConfig or "./WorldConfig")

local QuestConfig = {}

export type Reward = { coins: number?, pearls: number? }

export type Quest = {
    id: string,
    text: string,
    -- ce se citeste din stare: "pad" (detii platforma) | "collected" / "sold" (bucati, D51) | "sawn" |
    -- "smelted" (fier topit la forja, D55) | "ironSold" (fier predat la taverna, D56) | "level" | "idle" |
    -- "fished" (pesti scosi la undita, D59) | "decor" (lucruri construite de la avizierul satului, D62) |
    -- [D65] "cast" / "partsSold" / "copperSmelted" / "copperSold" (numaratorile Morii, din Stats, pe numele lor) |
    -- [D70] "income": venitul pe secunda de pe HUD; `goal` e pragul fara pass, inmultit in joc cu 2x Flow (QuestMath.goalOf)
    -- (plus "collects" / "sells", gesturi, ramase doar ca feluri cunoscute)
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
    targetBoard: boolean?, -- sageata arata avizierul satului, de pe punte [D62]
    -- [D65] sageata arata un loc al Morii, dupa numele lui din FlowConfig: inelul unui atelier ("foundry", "furnace")
    -- sau usa unui vanzator ("market")
    targetPlace: string?,
    always: boolean?, -- [D65] sageata si cand ghidajul tace: un loc nou, pe care altfel n-ai cum sa-l gasesti
}

export type Chapter = {
    id: string,
    era: number, -- [D65] capitolele unei ere intra in joc odata cu platformele ei (vezi CHAPTERS, la sfarsit)
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
local ALL_CHAPTERS: { Chapter } = {
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
        era = 1,
        title = "Chapter 1",
        subtitle = "The Landing",
        -- [D62] platita la ultima revendicare din capitol (pana atunci campul exista, dar nu-l platea nimeni). 6, nu 5:
        -- cu cele 14 perle ale quest-urilor fac 20, exact cat costa primul lucru de la avizierul satului.
        reward = { pearls = 6 },
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
                text = "Sell the planks at the Tavern",
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
                -- [D59] UNDITA. [D62, pasul 4] Mutata aici din capitolul 2: dupa al cincilea om satul merge singur si
                -- astepti oricum ~50 s banii pentru nivelul plasei, iar ghidajul tacea exact atunci -- prima pauza a
                -- jocului n-avea nimic in ea. Quest-ul isi are sageata spre capatul pontonului chiar daca ghidajul
                -- tace (exceptie numita, in GuideMath). Un peste, nu zece: pescuitul doar adauga, nu se cere.
                -- Id-ul ramane acelasi: cine l-a revendicat deja in capitolul 2 il are revendicat si aici.
                id = "catch_fish",
                text = "Catch a fish", -- [D61] si pestii de la iazul din balci se numara
                kind = "fished",
                goal = 1,
                reward = { pearls = 3 },
                targetFish = true,
            },
            {
                -- [D62, pasul 4] AVIZIERUL SATULUI nu era aratat de niciun quest: perlele se strangeau fara ca
                -- jucatorul sa afle pe ce se dau. Aici are destule: 12 din quest-uri + 3 de la peste + cel putin 6 pe
                -- primul peste (1 + bonusul speciei noi) = 21, iar primul lucru de la avizier costa 20
                -- [PearlBudget.test]. Cumperi, si il vezi aparand in sat.
                id = "buy_decor",
                text = "Build something in your village",
                kind = "decor",
                goal = 1,
                reward = { pearls = 2 },
                targetBoard = true,
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
        era = 1,
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
        era = 1,
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
                -- randul din lista are 270 la marimea 15: "...in the deep channel" (36 de litere) se taia in "..."
                text = "Cast a fifth net for scrap",
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
                text = "Sell the iron at the Tavern",
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
    -- ---- [D65] ERA 2 · THE MILL, in oglinda Erei 1 --------------------------------------------------------
    -- Aceeasi lectie, a doua oara, intr-un loc nou: roata de apa porneste turnatoria si Piata, plasa a sasea aduce
    -- scrap, faci UN tur de mana (culegi, torni stand in inel, vinzi la Piata), apoi cei cinci oameni la rand si
    -- plasele. Ordinea urmeaza cumpararile din simulator (ERA2.quest_unlocks) si conditiile platformelor
    -- (TycoonConfig.needs); testul QuestMath o tine.
    {
        id = "mill",
        era = 2,
        title = "Chapter 4",
        subtitle = "The Mill",
        reward = { pearls = 10 },
        quests = {
            {
                -- dincolo de gardul abia cazut: sageata vine si daca ghidajul tace (toti oamenii Erei 1 sunt angajati)
                id = "build_wheel",
                text = "Build the Water Wheel",
                kind = "pad",
                arg = "water_wheel",
                goal = 1,
                reward = { pearls = 3 },
                targetPad = "water_wheel",
                always = true,
            },
            {
                id = "cast_sixth",
                text = "Cast a sixth net",
                kind = "pad",
                arg = "sixth_net",
                goal = 1,
                reward = { pearls = 2 },
                targetPad = "sixth_net",
            },
            {
                -- turul de mana: culegi scrap-ul din plasa a sasea, il duci la turnatorie si stai in inel cat se toarna
                id = "cast_parts",
                text = "Cast 10 parts at the Foundry",
                kind = "cast",
                goal = 10,
                reward = { pearls = 2 },
                targetPlace = "foundry",
            },
            {
                id = "sell_parts",
                text = "Sell the parts at the Market",
                kind = "partsSold",
                goal = 10,
                reward = { pearls = 2 },
                targetPlace = "market",
            },
            {
                id = "hire_mill_collector",
                text = "Hire a Mill Collector",
                kind = "pad",
                arg = "hire_mill_collector",
                goal = 1,
                reward = { pearls = 1 },
                targetPad = "hire_mill_collector",
            },
            {
                id = "hire_mill_porter",
                text = "Hire a Mill Porter",
                kind = "pad",
                arg = "hire_mill_porter",
                goal = 1,
                reward = { pearls = 1 },
                targetPad = "hire_mill_porter",
            },
            {
                id = "hire_founder",
                text = "Hire a Founder",
                kind = "pad",
                arg = "hire_founder",
                goal = 1,
                reward = { pearls = 1 },
                targetPad = "hire_founder",
            },
            {
                id = "hire_parts_hauler",
                text = "Hire a Parts Hauler",
                kind = "pad",
                arg = "hire_parts_hauler",
                goal = 1,
                reward = { pearls = 1 },
                targetPad = "hire_parts_hauler",
            },
            {
                id = "hire_merchant",
                text = "Hire a Merchant",
                kind = "pad",
                arg = "hire_merchant",
                goal = 1,
                reward = { pearls = 2 },
                targetPad = "hire_merchant",
            },
            {
                -- plasa urmatoare apare abia cand asta e la TycoonConfig.PREV_NET_LEVEL (ca in capitolul 1)
                id = "sixth_two",
                text = "Upgrade Sixth Net to level 2",
                kind = "level",
                arg = "net:sixth_net",
                goal = 2,
                reward = { pearls = 1 },
                targetPad = "sixth_net",
            },
            {
                id = "cast_seventh",
                text = "Cast a seventh net",
                kind = "pad",
                arg = "seventh_net",
                goal = 1,
                reward = { pearls = 2 },
                targetPad = "seventh_net",
            },
        },
    },
    {
        id = "full_stream",
        era = 2,
        title = "Chapter 5",
        subtitle = "Full Stream",
        reward = { pearls = 12 },
        quests = {
            {
                id = "seventh_two",
                text = "Upgrade Seventh Net to level 2",
                kind = "level",
                arg = "net:seventh_net",
                goal = 2,
                reward = { pearls = 1 },
                targetPad = "seventh_net",
            },
            {
                id = "cast_eighth",
                text = "Cast an eighth net",
                kind = "pad",
                arg = "eighth_net",
                goal = 1,
                reward = { pearls = 2 },
                targetPad = "eighth_net",
            },
            {
                id = "eighth_two",
                text = "Upgrade Eighth Net to level 2",
                kind = "level",
                arg = "net:eighth_net",
                goal = 2,
                reward = { pearls = 1 },
                targetPad = "eighth_net",
            },
            {
                id = "cast_ninth",
                text = "Cast a ninth net, further out",
                kind = "pad",
                arg = "ninth_net",
                goal = 1,
                reward = { pearls = 3 },
                targetPad = "ninth_net",
            },
            {
                id = "market_ten",
                text = "Upgrade the Market to level 10",
                kind = "level",
                arg = "market",
                goal = 10,
                reward = { pearls = 3 },
            },
            {
                id = "ninth_two",
                text = "Upgrade Ninth Net to level 2",
                kind = "level",
                arg = "net:ninth_net",
                goal = 2,
                reward = { pearls = 1 },
                targetPad = "ninth_net",
            },
        },
    },
    {
        -- linia cuprului, ca linia fierului in capitolul 3: cuptorul, plasa care aduce minereu, un tur de mana, apoi
        -- magazia si cei patru oameni la rand
        id = "copper",
        era = 2,
        title = "Chapter 6",
        subtitle = "The Copper Line",
        reward = { pearls = 12 },
        quests = {
            {
                id = "build_furnace",
                text = "Build the Copper Furnace",
                kind = "pad",
                arg = "copper_furnace",
                goal = 1,
                reward = { pearls = 3 },
                targetPad = "copper_furnace",
            },
            {
                id = "cast_tenth",
                text = "Cast a tenth net for ore",
                kind = "pad",
                arg = "tenth_net",
                goal = 1,
                reward = { pearls = 3 },
                targetPad = "tenth_net",
            },
            {
                id = "smelt_copper",
                text = "Smelt 10 copper at the Furnace",
                kind = "copperSmelted",
                goal = 10,
                reward = { pearls = 2 },
                targetPlace = "furnace",
            },
            {
                id = "sell_copper",
                text = "Sell the copper at the Market",
                kind = "copperSold",
                goal = 10,
                reward = { pearls = 2 },
                targetPlace = "market",
            },
            {
                id = "build_ore_shed",
                text = "Build the Ore Shed",
                kind = "pad",
                arg = "ore_shed",
                goal = 1,
                reward = { pearls = 1 },
                targetPad = "ore_shed",
            },
            {
                id = "hire_ore_collector",
                text = "Hire an Ore Collector",
                kind = "pad",
                arg = "hire_ore_collector",
                goal = 1,
                reward = { pearls = 1 },
                targetPad = "hire_ore_collector",
            },
            {
                id = "hire_ore_porter",
                text = "Hire an Ore Porter",
                kind = "pad",
                arg = "hire_ore_porter",
                goal = 1,
                reward = { pearls = 1 },
                targetPad = "hire_ore_porter",
            },
            {
                id = "hire_coppersmith",
                text = "Hire a Coppersmith",
                kind = "pad",
                arg = "hire_coppersmith",
                goal = 1,
                reward = { pearls = 1 },
                targetPad = "hire_coppersmith",
            },
            {
                id = "hire_copper_hauler",
                text = "Hire a Copper Hauler",
                kind = "pad",
                arg = "hire_copper_hauler",
                goal = 1,
                reward = { pearls = 2 },
                targetPad = "hire_copper_hauler",
            },
            {
                id = "ring_mill_bell",
                text = "Ring the Mill Bell",
                kind = "pad",
                arg = "mill_bell",
                goal = 1,
                reward = { pearls = 8 },
                targetPad = "mill_bell",
            },
        },
    },
    {
        -- ---- [D67] ERA 3 · THE WIRE WORKS, in oglinda Morii ------------------------------------------------------
        -- Aceeasi lectie, a treia oara: masina cu abur porneste Wire Works si Depoul, plasa a unsprezecea aduce minereu de
        -- cupru, faci UN tur de mana (culegi, tragi sarma stand in inel, vinzi la Depot), apoi cei cinci oameni si plasele.
        id = "wire_works",
        era = 3,
        title = "Chapter 7",
        subtitle = "The Wire Works",
        reward = { pearls = 10 },
        quests = {
            {
                -- dincolo de gardul abia cazut: sageata vine si daca ghidajul tace (toti oamenii Morii sunt angajati)
                id = "build_steam",
                text = "Build the Steam Engine",
                kind = "pad",
                arg = "steam_engine",
                goal = 1,
                reward = { pearls = 3 },
                targetPad = "steam_engine",
                always = true,
            },
            {
                id = "cast_eleventh",
                text = "Cast an eleventh net",
                kind = "pad",
                arg = "eleventh_net",
                goal = 1,
                reward = { pearls = 2 },
                targetPad = "eleventh_net",
            },
            {
                -- turul de mana: culegi minereul din plasa a unsprezecea, il duci la Wire Works si stai in inel cat se trage
                id = "draw_coils",
                text = "Draw 10 coils at the Wire Works",
                kind = "drawn",
                goal = 10,
                reward = { pearls = 2 },
                targetPlace = "wireworks",
            },
            {
                id = "sell_coils",
                text = "Sell the coils at the Depot",
                kind = "coilsSold",
                goal = 10,
                reward = { pearls = 2 },
                targetPlace = "depot",
            },
            {
                id = "hire_works_collector",
                text = "Hire a Works Collector",
                kind = "pad",
                arg = "hire_works_collector",
                goal = 1,
                reward = { pearls = 1 },
                targetPad = "hire_works_collector",
            },
            {
                id = "hire_works_porter",
                text = "Hire a Works Porter",
                kind = "pad",
                arg = "hire_works_porter",
                goal = 1,
                reward = { pearls = 1 },
                targetPad = "hire_works_porter",
            },
            {
                id = "hire_wiredrawer",
                text = "Hire a Wiredrawer",
                kind = "pad",
                arg = "hire_wiredrawer",
                goal = 1,
                reward = { pearls = 1 },
                targetPad = "hire_wiredrawer",
            },
            {
                id = "hire_coil_hauler",
                text = "Hire a Coil Hauler",
                kind = "pad",
                arg = "hire_coil_hauler",
                goal = 1,
                reward = { pearls = 1 },
                targetPad = "hire_coil_hauler",
            },
            {
                id = "hire_clerk",
                text = "Hire a Clerk",
                kind = "pad",
                arg = "hire_clerk",
                goal = 1,
                reward = { pearls = 2 },
                targetPad = "hire_clerk",
            },
            {
                -- plasa urmatoare apare abia cand asta e la TycoonConfig.PREV_NET_LEVEL
                id = "eleventh_two",
                text = "Upgrade Eleventh Net to level 2",
                kind = "level",
                arg = "net:eleventh_net",
                goal = 2,
                reward = { pearls = 1 },
                targetPad = "eleventh_net",
            },
            {
                id = "cast_twelfth",
                text = "Cast a twelfth net",
                kind = "pad",
                arg = "twelfth_net",
                goal = 1,
                reward = { pearls = 2 },
                targetPad = "twelfth_net",
            },
        },
    },
    {
        id = "miles_of_wire",
        era = 3,
        title = "Chapter 8",
        subtitle = "Miles of Wire",
        reward = { pearls = 12 },
        quests = {
            {
                id = "twelfth_two",
                text = "Upgrade Twelfth Net to level 2",
                kind = "level",
                arg = "net:twelfth_net",
                goal = 2,
                reward = { pearls = 1 },
                targetPad = "twelfth_net",
            },
            {
                id = "cast_thirteenth",
                text = "Cast a thirteenth net",
                kind = "pad",
                arg = "thirteenth_net",
                goal = 1,
                reward = { pearls = 2 },
                targetPad = "thirteenth_net",
            },
            {
                id = "thirteenth_two",
                text = "Upgrade Thirteenth Net to level 2",
                kind = "level",
                arg = "net:thirteenth_net",
                goal = 2,
                reward = { pearls = 1 },
                targetPad = "thirteenth_net",
            },
            {
                id = "cast_fourteenth",
                text = "Cast a fourteenth net",
                kind = "pad",
                arg = "fourteenth_net",
                goal = 1,
                reward = { pearls = 3 },
                targetPad = "fourteenth_net",
            },
            {
                id = "depot_ten",
                text = "Upgrade the Depot to level 10",
                kind = "level",
                arg = "depot",
                goal = 10,
                reward = { pearls = 3 },
            },
            {
                id = "fourteenth_two",
                text = "Upgrade Fourteenth Net to level 2",
                kind = "level",
                arg = "net:fourteenth_net",
                goal = 2,
                reward = { pearls = 1 },
                targetPad = "fourteenth_net",
            },
        },
    },
    {
        -- linia curentului, ca linia cuprului in capitolul 6: Power House, turbina care umple baterii, un tur de mana,
        -- apoi magazia si cei patru oameni la rand
        id = "power_line",
        era = 3,
        title = "Chapter 9",
        subtitle = "The Power Line",
        reward = { pearls = 12 },
        quests = {
            {
                id = "build_power_house",
                text = "Build the Power House",
                kind = "pad",
                arg = "power_house",
                goal = 1,
                reward = { pearls = 3 },
                targetPad = "power_house",
            },
            {
                id = "build_turbine",
                text = "Build the First Turbine",
                kind = "pad",
                arg = "first_turbine",
                goal = 1,
                reward = { pearls = 3 },
                targetPad = "first_turbine",
            },
            {
                id = "charge_cells",
                text = "Charge 10 power cells",
                kind = "cellsMade",
                goal = 10,
                reward = { pearls = 2 },
                targetPlace = "powerhouse",
            },
            {
                id = "sell_cells",
                text = "Sell power cells at the Depot",
                kind = "cellsSold",
                goal = 10,
                reward = { pearls = 2 },
                targetPlace = "depot",
            },
            {
                id = "build_battery_shed",
                text = "Build the Battery Shed",
                kind = "pad",
                arg = "battery_shed",
                goal = 1,
                reward = { pearls = 1 },
                targetPad = "battery_shed",
            },
            {
                id = "hire_battery_collector",
                text = "Hire a Battery Collector",
                kind = "pad",
                arg = "hire_battery_collector",
                goal = 1,
                reward = { pearls = 1 },
                targetPad = "hire_battery_collector",
            },
            {
                id = "hire_battery_porter",
                text = "Hire a Battery Porter",
                kind = "pad",
                arg = "hire_battery_porter",
                goal = 1,
                reward = { pearls = 1 },
                targetPad = "hire_battery_porter",
            },
            {
                id = "hire_electrician",
                text = "Hire an Electrician",
                kind = "pad",
                arg = "hire_electrician",
                goal = 1,
                reward = { pearls = 1 },
                targetPad = "hire_electrician",
            },
            {
                id = "hire_power_hauler",
                text = "Hire a Power Hauler",
                kind = "pad",
                arg = "hire_power_hauler",
                goal = 1,
                reward = { pearls = 2 },
                targetPad = "hire_power_hauler",
            },
            {
                id = "ring_works_bell",
                text = "Ring the Works Bell",
                kind = "pad",
                arg = "works_bell",
                goal = 1,
                reward = { pearls = 8 },
                targetPad = "works_bell",
            },
        },
    },
    {
        -- ---- [D70] ERA 4 · THE DAM (lumea 2), ADORMITA pana la comutatorul l3 (CHAPTERS ia doar erele in joc) ----------
        -- Ordinea e a capitolului din simulator (DamRun, a treia rulare): un tur de mana pe cablu (plasa, Cable Works,
        -- Relay Station, Switch House), cei sase oameni in rafala, apoi plasele de cablu in ordinea DAM_CHAPTER, fiecare
        -- dupa ce o urci pe cea dinainte la nivelul 2. Veteranii si turbina vin cu barajul, deci n-au quest.
        id = "the_dam",
        era = 4,
        title = "Chapter 10",
        subtitle = "The Dam",
        reward = { pearls = 12 },
        quests = {
            {
                -- turul de mana: culegi minereul din Cable Net, il duci la Cable Works si stai in inel cat se toarce; sageata
                -- vine si daca ghidajul tace (o harta noua)
                id = "spin_cable",
                text = "Spin cable at the Cable Works",
                kind = "cableSpun",
                goal = 10,
                reward = { pearls = 2 },
                targetPlace = "cableworks",
                always = true,
            },
            {
                id = "join_power",
                text = "Join barrels and cable 10 times",
                kind = "gridJoined",
                goal = 10,
                reward = { pearls = 2 },
                targetPlace = "relay",
            },
            {
                id = "sell_power",
                text = "Sell power at the Switch House",
                kind = "gridSold",
                goal = 10,
                reward = { pearls = 2 },
                targetPlace = "town",
            },
            {
                id = "hire_cable_collector",
                text = "Hire a Cable Collector",
                kind = "pad",
                arg = "hire_cable_collector",
                goal = 1,
                reward = { pearls = 1 },
                targetPad = "hire_cable_collector",
            },
            {
                id = "hire_cable_porter",
                text = "Hire a Cable Porter",
                kind = "pad",
                arg = "hire_cable_porter",
                goal = 1,
                reward = { pearls = 1 },
                targetPad = "hire_cable_porter",
            },
            {
                id = "hire_cablemaker",
                text = "Hire a Cablemaker",
                kind = "pad",
                arg = "hire_cablemaker",
                goal = 1,
                reward = { pearls = 1 },
                targetPad = "hire_cablemaker",
            },
            {
                id = "hire_cable_hauler",
                text = "Hire a Cable Hauler",
                kind = "pad",
                arg = "hire_cable_hauler",
                goal = 1,
                reward = { pearls = 1 },
                targetPad = "hire_cable_hauler",
            },
            {
                id = "hire_relay_keeper",
                text = "Hire a Relay Keeper",
                kind = "pad",
                arg = "hire_relay_keeper",
                goal = 1,
                reward = { pearls = 1 },
                targetPad = "hire_relay_keeper",
            },
            {
                id = "hire_pylon_runner",
                text = "Hire a Pylon Runner",
                kind = "pad",
                arg = "hire_pylon_runner",
                goal = 1,
                reward = { pearls = 2 },
                targetPad = "hire_pylon_runner",
            },
            {
                id = "cable_net_two",
                text = "Upgrade Cable Net to level 2",
                kind = "level",
                arg = "net:cable_net",
                goal = 2,
                reward = { pearls = 1 },
                targetPad = "cable_net",
            },
            {
                id = "cast_second_cable",
                text = "Cast Cable Net II", -- numele din lume (ca „Cast the Crystal Net”)
                kind = "pad",
                arg = "second_cable_net",
                goal = 1,
                reward = { pearls = 2 },
                targetPad = "second_cable_net",
            },
        },
    },
    {
        -- pasul de venit inaintea Kiln-ului (KILN_INCOME): fara el, cine strange pentru Kiln de la a treia plasa sta peste o
        -- ora pe un venit care nu mai creste (simulatorul, PLAN-MOTOR-UNIRE §11)
        id = "miles_of_cable",
        era = 4,
        title = "Chapter 11",
        subtitle = "Miles of Cable",
        reward = { pearls = 12 },
        quests = {
            {
                id = "second_cable_two",
                text = "Upgrade Cable Net II to level 2",
                kind = "level",
                arg = "net:second_cable_net",
                goal = 2,
                reward = { pearls = 1 },
                targetPad = "second_cable_net",
            },
            {
                id = "cast_third_cable",
                text = "Cast Cable Net III",
                kind = "pad",
                arg = "third_cable_net",
                goal = 1,
                reward = { pearls = 3 },
                targetPad = "third_cable_net",
            },
            {
                id = "third_cable_two",
                text = "Upgrade Cable Net III to level 2",
                kind = "level",
                arg = "net:third_cable_net",
                goal = 2,
                reward = { pearls = 1 },
                targetPad = "third_cable_net",
            },
            {
                -- un prag de venit din StationConfig (cel al capitolului din simulator / al platformei); cu 2x Flow cere
                -- dublu (QuestMath.goalOf)
                id = "earn_kiln",
                text = "Earn 1T coins a second",
                kind = "income",
                goal = StationConfig.KILN_INCOME,
                reward = { pearls = 3 },
            },
            {
                id = "build_kiln",
                text = "Build the Kiln",
                kind = "pad",
                arg = "crystal_kiln",
                goal = 1,
                reward = { pearls = 3 },
                targetPad = "crystal_kiln",
            },
        },
    },
    {
        -- linia cristalului, ca linia curentului in capitolul 9; clopotul cere si venitul (DAM_BELL_INCOME), deci capitolul
        -- il cere inaintea lui, cu acelasi prag ca platforma
        id = "cold_fire",
        era = 4,
        title = "Chapter 12",
        subtitle = "Cold Fire",
        reward = { pearls = 12 },
        quests = {
            {
                id = "cast_crystal",
                text = "Cast the Crystal Net",
                kind = "pad",
                arg = "crystal_net",
                goal = 1,
                reward = { pearls = 3 },
                targetPad = "crystal_net",
            },
            {
                id = "fire_ingots",
                text = "Fire 10 ingots at the Kiln",
                kind = "ingotsFired",
                goal = 10,
                reward = { pearls = 2 },
                targetPlace = "kiln",
            },
            {
                id = "sell_ingots",
                text = "Sell ingots at the Switch House",
                kind = "ingotsSold",
                goal = 10,
                reward = { pearls = 2 },
                targetPlace = "town",
            },
            {
                id = "build_crystal_shed",
                text = "Build the Crystal Shed",
                kind = "pad",
                arg = "crystal_shed",
                goal = 1,
                reward = { pearls = 1 },
                targetPad = "crystal_shed",
            },
            {
                id = "hire_crystal_collector",
                text = "Hire a Crystal Collector",
                kind = "pad",
                arg = "hire_crystal_collector",
                goal = 1,
                reward = { pearls = 1 },
                targetPad = "hire_crystal_collector",
            },
            {
                id = "hire_crystal_porter",
                text = "Hire a Crystal Porter",
                kind = "pad",
                arg = "hire_crystal_porter",
                goal = 1,
                reward = { pearls = 1 },
                targetPad = "hire_crystal_porter",
            },
            {
                id = "hire_crystalsmith",
                text = "Hire a Crystalsmith",
                kind = "pad",
                arg = "hire_crystalsmith",
                goal = 1,
                reward = { pearls = 1 },
                targetPad = "hire_crystalsmith",
            },
            {
                id = "hire_ingot_hauler",
                text = "Hire an Ingot Hauler",
                kind = "pad",
                arg = "hire_ingot_hauler",
                goal = 1,
                reward = { pearls = 2 },
                targetPad = "hire_ingot_hauler",
            },
            {
                -- un prag de venit din StationConfig (cel al capitolului din simulator / al platformei); cu 2x Flow cere
                -- dublu (QuestMath.goalOf)
                id = "earn_bell",
                text = "Earn 4T coins a second",
                kind = "income",
                goal = StationConfig.DAM_BELL_INCOME,
                reward = { pearls = 3 },
            },
            {
                id = "ring_dam_bell",
                text = "Ring the Dam Bell",
                kind = "pad",
                arg = "dam_bell",
                goal = 1,
                reward = { pearls = 8 },
                targetPad = "dam_bell",
            },
        },
    },
}

-- [D65] TOATE capitolele scrise (testele le verifica pe toate) si cele DIN JOC: ale erelor cu platforme `live`. Cat
-- Era 2 nu e in joc, capitolul 4 ar fi cerut o roata de apa pe care n-o poti construi.
QuestConfig.ALL_CHAPTERS = ALL_CHAPTERS
local liveChapters: { Chapter } = {}
for _, chapter in ALL_CHAPTERS do
    if TycoonConfig.eraIsLive(chapter.era) then
        table.insert(liveChapters, chapter)
    end
end
QuestConfig.CHAPTERS = liveChapters

-- [D70, pasul j11] Capitolele din joc ale unei lumi (satul: 1-9; barajul: 10-12, cand Era 4 e in joc). Fara lume, satul.
local chaptersByWorld: { [number]: { Chapter } } = {}
for _, chapter in liveChapters do
    local w = WorldConfig.worldOfEra(chapter.era)
    chaptersByWorld[w] = chaptersByWorld[w] or {}
    table.insert(chaptersByWorld[w], chapter)
end
function QuestConfig.chaptersOfWorld(w: any): { Chapter }
    return chaptersByWorld[WorldConfig.sanitize(w)] or {}
end

QuestConfig.byId = {} :: { [string]: Quest }
for _, chapter in ALL_CHAPTERS do
    for _, quest in chapter.quests do
        QuestConfig.byId[quest.id] = quest
    end
end

return QuestConfig
