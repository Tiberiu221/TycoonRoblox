--!strict
-- Funnel de onboarding [DECIZII D25, MASTERPLAN 11.2]. Functioneaza doar in joc publicat, doar pe server; in Studio esueaza silentios.
local AnalyticsService = game:GetService("AnalyticsService")

local Analytics = {}

-- Renumerotat la pivotul D45 (tycoon), extins la Era 1 completa [F1 spec 3.6], la cele 13 platforme din
-- D49, apoi cu FirstCut [D51]: fara jucatori reali inca, deci renumerotarea e sigura. Platformele Erei 1
-- de la a doua incolo sunt pasii 7..18, in ordinea lor (index + 5), toate BoughtPad<index> (PadService
-- face numele, nu numarul). [D52] Ordinea e cea noua: prima plasa, cei cinci oameni, apoi plasele.
Analytics.STEPS = {
    Joined = 1,
    BoughtFirstNet = 2,
    FirstCatch = 3,
    FirstCollect = 4,
    -- [D51] prima scandura taiata: se vede daca jucatorii se opresc la gater, intre colectare si vanzare
    FirstCut = 5,
    FirstSell = 6,
    BoughtPad2 = 7, -- first_runner (Collector)
    BoughtPad3 = 8, -- hire_porter
    BoughtPad4 = 9, -- hire_sawyer
    BoughtPad5 = 10, -- hire_hauler
    BoughtPad6 = 11, -- dock_trader (Innkeeper)
    BoughtPad7 = 12, -- second_net
    BoughtPad8 = 13, -- third_net
    BoughtPad9 = 14, -- bigger_sack
    BoughtPad10 = 15, -- far_lane_net
    BoughtPad11 = 16, -- workshop (Forge)
    -- [D56] linia fierului: plasa, shed-ul si cei patru oameni, apoi clopotul
    BoughtPad12 = 17, -- fifth_net
    BoughtPad13 = 18, -- scrap_shed
    BoughtPad14 = 19, -- hire_scrap_collector
    BoughtPad15 = 20, -- hire_scrap_porter
    BoughtPad16 = 21, -- hire_smelter
    BoughtPad17 = 22, -- hire_iron_hauler
    BoughtPad18 = 23, -- landing_bell
}

-- [D51] Quest-urile, pe un canal propriu, capitol cu capitol, in ordinea din QuestConfig. Pana acum
-- QuestService trimitea "Quest_<id>" in canalul de onboarding, unde nu exista un asemenea pas: fiecare
-- revendicare era aruncata cu un warn, iar canalul quest-urilor n-a inregistrat niciodata nimic.
function Analytics.QuestStep(player: Player, chapterId: string, step: number, questId: string)
    task.spawn(function()
        local ok, err = pcall(function()
            AnalyticsService:LogFunnelStepEvent(player, `Quests_{chapterId}`, nil, step, questId)
        end)
        if not ok then
            print(`[Analytics] quest {chapterId}/{step} {questId} (nelivrat in Studio): {err}`)
        end
    end)
end

-- [D59] Pontonul, pe un canal propriu: cati arunca undita, cati scot un peste, cati deschid ce aduce raul, cati cumpara
-- ceva cu perle. Fiecare pas o singura data pe jucator (Firsts), in ordinea asta.
Analytics.PIER_STEPS =
    { FirstCast = 1, FirstFish = 2, FirstTreasure = 3, FirstDecor = 4, FirstOutfit = 5 }

function Analytics.PierStep(player: Player, stepName: string)
    local step = Analytics.PIER_STEPS[stepName]
    if step == nil then
        warn(`[Analytics] pas de ponton necunoscut: {stepName}`)
        return
    end
    task.spawn(function()
        local ok, err = pcall(function()
            AnalyticsService:LogFunnelStepEvent(player, "Pier", nil, step, stepName)
        end)
        if not ok then
            print(`[Analytics] ponton {step} {stepName} (nelivrat in Studio): {err}`)
        end
    end)
end

-- [D60] Balciul, pe canalul lui: cati urca in barca, cati ajung, cati isi pun un titlu, cati vad tabela, cati cumpara
-- ceva acolo. Fiecare pas o singura data pe jucator (Firsts).
Analytics.FAIR_STEPS = {
    FirstRide = 1,
    FirstFairVisit = 2,
    FirstTitleWorn = 3,
    FirstBoardSeen = 4,
    FirstFairPurchase = 5,
    -- [D61] iazul, gheretele, mesele
    FirstPondCast = 6,
    FirstPondRound = 7,
    FirstBoothGame = 8,
    FirstSit = 9,
    FirstWave = 10,
    -- [D61, partea 2] croitoreasa si poarta satelor
    FirstLookSaved = 11,
    FirstVillageVisit = 12,
    FirstLikeGiven = 13,
}

function Analytics.FairStep(player: Player, stepName: string)
    local step = Analytics.FAIR_STEPS[stepName]
    if step == nil then
        warn(`[Analytics] pas de balci necunoscut: {stepName}`)
        return
    end
    task.spawn(function()
        local ok, err = pcall(function()
            AnalyticsService:LogFunnelStepEvent(player, "Fair", nil, step, stepName)
        end)
        if not ok then
            print(`[Analytics] balci {step} {stepName} (nelivrat in Studio): {err}`)
        end
    end)
end

-- [D61, partea 2] Coltul cu Robux, pe canalul lui: cati ajung la fereastra Roblox de cumparare, cati iau un pass, cati
-- iau un produs. Fiecare pas o singura data pe jucator (Firsts); apelantul tine steagul.
Analytics.SHOP_STEPS = { FirstShopPrompt = 1, FirstPassBought = 2, FirstProductBought = 3 }

function Analytics.ShopStep(player: Player, stepName: string)
    local step = Analytics.SHOP_STEPS[stepName]
    if step == nil then
        warn(`[Analytics] pas de magazin necunoscut: {stepName}`)
        return
    end
    task.spawn(function()
        local ok, err = pcall(function()
            AnalyticsService:LogFunnelStepEvent(player, "Shop", nil, step, stepName)
        end)
        if not ok then
            print(`[Analytics] magazin {step} {stepName} (nelivrat in Studio): {err}`)
        end
    end)
end

-- [D61, partea 2] Monede cumparate cu Robux (One Hour of Flow, Welcome Back x2): sursa IAP, cu soldul de DUPA. Merge
-- doar din server si doar in jocul publicat (nota 27): in Studio esueaza in tacere, ca restul.
-- [D71] REVENIREA ZILNICA: o data pe zi numarata (ziua jucatorului, seria zilnica, StreakMath). Valoarea e seria de acum; cate zile
-- au revenit jucatorii si cat de lungi sunt seriile se citesc din tabloul de analytics al experientei.
function Analytics.DailyReturn(player: Player, run: number, total: number)
    task.spawn(function()
        local ok, err = pcall(function()
            AnalyticsService:LogCustomEvent(player, "DailyReturn", run)
        end)
        if not ok then
            print(`[Analytics] revenire zilnica {run} (din {total}) (nelivrat in Studio): {err}`)
        end
    end)
end

function Analytics.CoinsBought(player: Player, amount: number, balance: number, sku: string)
    task.spawn(function()
        local ok, err = pcall(function()
            AnalyticsService:LogEconomyEvent(
                player,
                Enum.AnalyticsEconomyFlowType.Source,
                "Coins",
                amount,
                balance,
                Enum.AnalyticsEconomyTransactionType.IAP.Name,
                sku
            )
        end)
        if not ok then
            print(`[Analytics] monede cumparate {sku} (nelivrat in Studio): {err}`)
        end
    end)
end

function Analytics.Funnel(player: Player, stepName: string)
    local step = Analytics.STEPS[stepName]
    if step == nil then
        warn(`[Analytics] pas de funnel necunoscut: {stepName}`)
        return
    end
    task.spawn(function()
        local ok, err = pcall(function()
            AnalyticsService:LogOnboardingFunnelStepEvent(player, step, stepName)
        end)
        if not ok then
            print(`[Analytics] funnel {step} {stepName} (nelivrat in Studio): {err}`)
        end
    end)
end

return Analytics
