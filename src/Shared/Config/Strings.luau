--!strict
-- Tot textul vazut de jucator, dintr-un singur loc [F2, D40: textul nu minte, D43: nimic in
-- tacere]. Cheile [1]-[42] sunt cele 42 de randuri din tabelul "Ce facem" din
-- docs/research/39-feedback-and-copy.md; restul (jos de tot) sunt textul propriu al agentului J
-- (fraza de deschidere, incarcarea) care nu era in tabel dar tot jucatorul il vede -- regula
-- explicita a sarcinii F2 e "orice text vazut de jucator vine de-aici", nu doar cele 42 de randuri.
--
-- Cifrele/numele se umplu la RUNTIME din date de server sau din TycoonConfig (pretul si numele
-- platformelor sunt DATE, nu text) -- niciodata scrise de mana. De-aia jumatate din randuri sunt
-- functii, nu string-uri simple.
--
-- Tip, din legenda tabelului: A text mic 0.6-0.9s ease-out | B text mare + sunet, ease-out-back |
-- C banda HUD 3-4s | D banner overshoot | E eticheta persistenta | F panou modal | G tooltip o
-- singura data. D si F, la Driftycoon, se sting singure dupa cateva secunde in loc sa astepte un
-- tap -- jocul nu-l blocheaza niciodata pe jucator (CLAUDE.md, regula de baza), deci n-avem "pana
-- la tap" adevarat.
--
-- Nu tot randul are azi un moment care sa-l traga -- vezi raportul agentului J pentru care anume.
-- Cele fara moment raman aici oricum, gata de folosit cand vine sistemul lor (Vault, renastere,
-- energie, Index).
local Strings = {}

-- ---- [1-5] Rau -------------------------------------------------------------------------------
Strings.RIVER_FIRST_CATCH = "+1" -- [A] -- deja pe ecran: NetController.OnCaught (Widgets.FloatText)
Strings.RIVER_CATCH = "+1" -- [A] -- idem, orice prindere de volum
function Strings.riverNamedCatch(name: string): string -- [B] -- idem, NetController arata numele
    return `{name}!`
end
Strings.RIVER_NET_FULL = "Net full" -- [E] -- azi: eticheta "FULL" din NetController.refreshLabel
Strings.RIVER_NET_UPGRADED = "Nets cast wider now" -- [C]
-- Pragul de plase (a 4-a, a 8-a, a 12-a): sporul e gratuit si vine peste efectul platformei, deci
-- trebuie SPUS, altfel jucatorul nu afla niciodata ca l-a primit [D43].
function Strings.netMilestone(n: number, pct: number): string -- [C]
    return `Net {n}. Every net now catches {pct}% more.`
end

-- ---- [6-8] Sac -------------------------------------------------------------------------------
function Strings.sackAdd(n: number): string -- [A]
    return `+{n} to sack`
end
Strings.SACK_UPGRADED = "Sack holds more now" -- [C]

-- ---- [9-11] Debarcader -----------------------------------------------------------------------
function Strings.dockSell(n: number): string -- [B] -- azi: JuiceController.CoinFly ("+{n}")
    return `+{n}`
end
Strings.DOCK_FIRST_SALE = "First sale. The river pays." -- [D]
function Strings.dockPriceBonus(pct: number): string -- [A]
    return `+{pct}% sold here`
end

-- ---- [12] HUD --------------------------------------------------------------------------------
-- Eticheta pastilei cu venitul care curge si fara tine. Era "IDLE", scris direct in HUDController: jargon de gen, pe care
-- un copil nu-l stie. Quest-ul spune deja "Earn 1 coin a second while away", deci acelasi cuvant [D63].
Strings.HUD_AWAY = "AWAY"
function Strings.hudRateUp(
    formattedRate: string
): string -- [A] -- formattedRate = TycoonMath.formatRate(n)
    return `+{formattedRate}/s`
end

-- ---- [13-16] Pad -------------------------------------------------------------------------------
function Strings.padAvailable(
    name: string,
    formattedPrice: string
): string -- [E] -- cartonasul agentului U
    return `{name} — {formattedPrice}`
end
function Strings.padNeedMoreCoins(
    n: string
): string -- [A] suma deja scrisa (TycoonMath.formatNumberUp)
    return `Need {n} more coins`
end
Strings.PAD_BUILT = "Built!" -- [B]
function Strings.padNextRevealed(
    name: string,
    formattedPrice: string
): string -- [E] -- cartonasul agentului U
    return `{name} — {formattedPrice}`
end

-- ---- [17-18] Era -------------------------------------------------------------------------------
function Strings.eraBellRung(zoneName: string, pct: number): string -- [D]
    return `{zoneName} pays {pct}% more. Forever.`
end
-- [D65] Clopotul unei ere de dupa prima inmulteste TOT venitul (factorul `bells` e unul singur, ca in simulator), nu doar
-- pe al cartierului lui: "The Mill pays 10% more" ar fi spus mai putin decat face [D40].
function Strings.eraBellRungAll(pct: number): string -- [D]
    return `Every sale pays {pct}% more. Forever.`
end
function Strings.eraZoneOpen(zoneName: string): string -- [D]
    return `{zoneName} is open`
end

-- ---- [19-24] Atelier / Forge -----------------------------------------------------------------
-- [D56] Cladirea e acum Forge; colectia (reparatiile) e pusa deoparte -- textele ei raman, nefolosite.
Strings.FORGE_LIT = "The Forge is lit." -- [F]
-- [D73] platforma care porneste atelierul unei linii a unei ere noi (roata de apa, cuptorul de cupru, masina cu abur, Power
-- House): bannerul spune ce s-a deschis; prima linie a erei deschide si vanzatorul ei (Piata, Depoul)
function Strings.lineOpened(processor: string, seller: string?): string
    return if seller ~= nil
        then `The {processor} and the {seller} are open!`
        else `The {processor} is open!`
end
function Strings.workshopRepaired(pct: number): string -- [B]
    return `Repaired. +{pct}% income. Forever.`
end
function Strings.workshopItemSold(
    n: number
): string -- [A] -- fara Remote propriu azi (ScrapItem), nefolosit
    return `Sold for {n}`
end
Strings.INDEX_QUARTER = "A quarter of the river, catalogued" -- [D] -- fara acces la Index, nefolosit
Strings.INDEX_HALF = "Halfway through the Index" -- [D] -- fara acces la Index, nefolosit
function Strings.indexNewItem(name: string): string -- [B] -- fara acces la Index, nefolosit
    return `New: {name}`
end

-- ---- [25-26] Angajati ------------------------------------------------------------------------
function Strings.handHired(name: string): string -- [C]
    return `{name} hired`
end

-- ---- [27-29] Offline -------------------------------------------------------------------------
-- (fereastra de revenire e mai jos, la [Offline])
Strings.OFFLINE_VAULT_FULL = "The Vault filled up — a bigger one holds more" -- [F] -- fara Vault, nefolosit
Strings.OFFLINE_VAULT_UPGRADED = "Vault holds more now" -- [C] -- fara platforma de vault, nefolosit

-- ---- [30-33] Renastere -----------------------------------------------------------------------
Strings.REBIRTH_READY = "Move Downstream is ready" -- [E] -- fara ecran de renastere inca, nefolosit
Strings.REBIRTH_SCREEN = "Stays: Index, Rebirths. Resets: Coins, Pads. You gain: +50% income." -- [F] -- nefolosit
Strings.REBIRTH_CONFIRMED = "Moving downstream…" -- [D] -- nefolosit
Strings.REBIRTH_NEW_SET = "New finds, downstream" -- [D] -- nefolosit

-- ---- [34-36] Energie -------------------------------------------------------------------------
Strings.POWER_LOW = "Low power" -- [E] -- Era 2 (Water Wheel) nu e live, nefolosit
Strings.POWER_FLOWING = "Power flowing" -- [A] -- nefolosit
function Strings.powerQualityUpgrade(name: string): string -- [C] -- nefolosit
    return `{name} — worth more per sale`
end

-- ---- [37-38] Refuz ---------------------------------------------------------------------------
Strings.REFUSE_SACK_EMPTY = "Nothing to sell yet" -- [A]
function Strings.refuseZoneLocked(bellName: string): string -- [A]
    return `Opens after the {bellName}`
end
-- [D65] Panoul de la gardul unei zone: inchisa (spune ce o deschide) sau deschisa dar inca nefacuta in joc.
function Strings.zoneLocked(zoneName: string, bellName: string): string
    return `{zoneName} — opens with the {bellName}`
end
-- [2026-09-30] finalul ce e in joc: era urmatoare vine intr-o actualizare (TycoonConfig.comingEra). Nu promite crestere:
-- dupa clopot, cu oamenii la 2 x treapta 5, venitul are un plafon, iar un nivel peste el aduce 0 [D40, verificator]. Nici
-- "until then": absenta se plateste doar pana la 24 h (D71: 8 h plin, 16 cu Long Nights, apoi un sfert), iar actualizarea
-- n-are data.
function Strings.eraComing(zoneName: string): string
    return `{zoneName} is coming soon!`
end
Strings.ERA_COMING_SUB = "It comes in a future update. Your village keeps earning while you play."
-- [verificatorul k6] numele unei zone in mijlocul frazei: „the Dam”, nu „The Dam”
local function midName(name: string): string
    return (string.gsub(name, "^The ", "the "))
end
-- [D70, pasul k6] era urmatoare e in joc, pe alta harta (barajul, dupa l3): drumul spre ea e masa Dam Plans
function Strings.eraReady(zoneName: string): string
    return `Time to build {midName(zoneName)}!`
end
Strings.ERA_READY_SUB = "Find the Dam Plans at the end of the Wire Works."
Strings.ERA_READY_QUESTS = "All quests done! Build the Dam at the Dam Plans."
function Strings.eraReadyNext(zoneName: string): string
    return `build {midName(zoneName)}`
end
-- [verificatorul k6] pasul ghidajului spre masa Dam Plans: „Not yet” nu e o pedeapsa, deci nici textul nu graba
Strings.PLANS_WHEN_READY = "Build the Dam when you're ready"
-- [D70, pasul k6] pe meniul unei cladiri din sat, cand barajul se poate ridica: nivelurile de aici nu se pierd, intra in el
Strings.GOES_INTO_DAM = "Goes into the Dam when you build it"
function Strings.plansBuild(keyHint: string): string
    return `Build the Dam{keyHint}`
end
function Strings.eraComingNext(zoneName: string): string
    return `{zoneName} (coming soon)`
end
Strings.ERA_COMING_QUESTS = "All quests done! Your village keeps earning while you play."
-- pe un singur rand in cardul E (320 px la 18 px, 0,56 em pe litera)
function Strings.comingPlans(zoneName: string): string
    return `{zoneName} plans · coming soon`
end
-- [D73] butonul mesei cu planuri, dupa clopot: o privire spre tarusii topografilor de langa ponton, unde va fi barajul;
-- toastul spune ce sunt tarusii
function Strings.plansLook(keyHint: string): string
    return `Where's the Dam?{keyHint}`
end
Strings.DAM_SITE = "The Dam will rise here — coming soon"
function Strings.zoneSoon(zoneName: string): string
    return `{zoneName} — coming soon`
end
-- [D70, pasul j15] barajul: refuzurile serverului (DamService) si ridicarea. Propuneri; ecranul „Build the Dam” le
-- rescrie la k7.
local DAM_REJECTED: { [string]: string } = {
    soon = "The Dam is coming soon!",
    bell = "Ring the Works Bell first",
    built = "The Dam is already built",
    settling = "One moment, the village is still counting",
    changed = "Your coins changed. Look again",
    busy = "One moment, try again",
    no_profile = "Still loading your river",
    save = "The Dam is built. It saves when you leave", -- profilul s-a inchis inainte ca salvarea sa ajunga
}
function Strings.damRejected(reason: string): string
    return DAM_REJECTED[reason] or DAM_REJECTED.busy
end
Strings.DAM_BUILT = "The Dam is built!"
-- [D70, pasul k7] ECRANUL „Build the Dam” (PLAN-HARTA §2 pasul 4, §3): trei coloane, cifrele de la server (DamMath.preview)
Strings.DAM_SCREEN_TITLE = "Build the Dam"
Strings.DAM_STAYS = "Stays with you"
Strings.DAM_BECOMES = "Becomes the Dam"
Strings.DAM_GAIN = "You gain"
function Strings.damCoins(start: string, bought: string?): string
    return if bought ~= nil
        then `You start with {start} + {bought} coins you bought`
        else `You start with {start}`
end
Strings.DAM_STAYS_THINGS = "All your pearls, outfits and decor"
Strings.DAM_STAYS_BELLS = "Your bells' bonus on every sale"
Strings.DAM_STAYS_PEOPLE = "All your people, with their names"
function Strings.damLastCart(coins: string, pieces: number): string
    return if pieces == 1
        then `Last cart: 1 good sold for {coins}`
        else `Last cart: {pieces} goods sold for {coins}`
end
function Strings.damQuests(pearls: number): string
    return if pearls == 1
        then "Old quests finished: +1 pearl"
        else `Old quests finished: +{pearls} pearls`
end
function Strings.damGiven(coins: string): string
    return `Given to the Dam: {coins}`
end
Strings.DAM_BECOMES_BUILDINGS = "Your old buildings, nets and jobs"
-- fara sageata: Nunito (fontul randurilor) n-o are
function Strings.damIncome(before: string, after: string): string
    return `Income {before}/s, then {after}/s`
end
function Strings.damTopUp(coins: string): string
    return `The village adds: {coins}`
end
function Strings.damVeterans(working: number, retired: number): string
    local who = if working == 1
        then "1 veteran keeps working"
        else `{working} veterans keep working`
    return if retired > 0 then `{who}; {retired} retire by the lake` else who
end
Strings.DAM_GAIN_FREE = "A turbine and a Cable Net, free"
-- [verificatorul k6] AWAY 0 pana la oamenii noi, spus si pe ecranul barajului
function Strings.damAwayZero(newHires: number): string
    -- [verificatorul k6-k8] un fapt, nu o indemnare: sub coloane, in galben
    return `The Dam earns nothing while you're away until you hire {newHires} new workers`
end
Strings.DAM_HOLD = "Build the Dam"
Strings.DAM_NOT_YET = "Not yet"
Strings.DAM_CLOSE = "Close"
Strings.DAM_HOLD_HINT = "Hold the button to build. Not yet costs nothing."
Strings.DAM_COUNTING = "Counting your village…"
Strings.DAM_SAVING = "Saving…"
-- [D70, pasul k8] dupa ridicare, clientul se reincarca in lumea 2 (acelasi place); cartonasul din timpul drumului
Strings.DAM_OPENING = "Opening the Dam…"
Strings.DAM_TRY_AGAIN = "Try again"
Strings.DAM_CARD_TITLE = "THE DAM"
-- [D70, pasul k9] filmul (O1: 15–20 s, Skip de la secunda 3): ce scrie pe ecran, pe faze (DamMath.FILM)
Strings.DAM_FILM_LOOK = "Look how far you've come."
Strings.DAM_FILM_PEOPLE = "Everyone lends a hand."
Strings.DAM_FILM_BUILD = "The old village becomes the Dam."
Strings.DAM_FILM_SKIP = "Skip"
-- [D70, pasul k10] Dam Town: clopotele vechi, Memory Wall si pagina oamenilor
function Strings.oldBells(pct: number): string
    return `Your old bells: +{pct}% on every sale`
end
Strings.PEOPLE_TITLE = "Your people"
function Strings.peopleOpen(keyHint: string): string
    return `Your people{keyHint}`
end
function Strings.personAt(name: string, job: string): string
    return `{name} — {job}`
end
function Strings.personVeteran(name: string, job: string, was: string): string
    return `{name} — {job} (was {was})`
end
function Strings.personRetired(name: string, was: string): string
    return `{name} — lives in town (was {was})`
end
Strings.DAM_CARD_SUB = "Your people built this"
function Strings.damReloadFailed(reason: string): string
    if reason == "studio_kept" then
        return "In Studio: press Stop, then Play, to open the Dam"
    elseif reason == "studio" or reason == "studio_fresh" then
        -- [verificatorul k7-k8] Play-ul din Studio porneste implicit de la zero: barajul se pierde la Stop
        return "In Studio this save is erased at Stop: turn on keep save, then build the Dam again"
    elseif reason == "pending" then
        return "The Dam is still opening. One moment" -- [verificatorul k6-k8] un drum e deja in curs
    end
    return "The Dam didn't open yet. Try again"
end
-- [verificatorul k7-k8] monedele s-au schimbat intre chitanta si ridicare (o cumparare cu Robux): cifrele de sus sunt noi
Strings.DAM_COINS_CHANGED = "Your coins changed. Check the numbers, then hold again"
-- [D70, verificatorul j10] zona unei alte harti (barajul, vazut din sat), cand era ei e in joc: nu se deschide cu niciun
-- clopot si nu mai "vine"; spune doar unde se ridica [D40, D73]
function Strings.zoneAway(zoneName: string): string
    return `{zoneName} will rise by your pier`
end
-- [D70, pasul k6] barajul se poate ridica acum: zona din sat spune de unde, cu numele mesei intreg. [verificatorul k6-k8] Si ce
-- se ridica: panoul n-are alt nume deasupra („Build it” nu spunea ce); trece pe doua randuri (textHeight)
function Strings.zoneBuildAt(zoneName: string): string
    return `Build {midName(zoneName)} at the Dam Plans`
end

-- ---- [39] Sistem -------------------------------------------------------------------------------
Strings.SYSTEM_LOADING = "Loading your river…" -- [F]

-- ---- [40-42] Tooltip (rar, o singura data) ----------------------------------------------------
Strings.TOOLTIP_POWER = "Stations slow down without power" -- [G] -- fara bara de energie, nefolosit
Strings.TOOLTIP_INDEX = "Every repair raises your income for good" -- [G] -- fara acces la IndexController, nefolosit
Strings.TOOLTIP_REBIRTH = "A bonus that never touches what you've paid for" -- [G] -- nefolosit

-- ---- In afara celor 42: textul propriu al agentului J, tot vazut de jucator -------------------
Strings.OPENING_LINE_1 = "This stretch of river is yours."
Strings.OPENING_LINE_2 = "Everything that floats past is money."
-- Prima gasire cu nume. [D56] Colectia e pusa deoparte: gasirile se vand la taverna, cu pretul lor.
function Strings.namedFindHint(name: string): string
    return `A rare find: {name}! The tavern pays well for it.`
end

-- ---- Indemnuri de interactiune, etichete de lume ---------------------------------------------
-- Erau singurele texte ramase scrise direct in controllere. `keyHint` e " (E)" pe tastatura si ""
-- pe telefon (unde exista butonul de actiune), deci acelasi text serveste ambele.
function Strings.promptCollect(keyHint: string): string
    return `Collect{keyHint}`
end
function Strings.promptSell(keyHint: string, value: string): string
    return `Sell{keyHint} — {value}`
end
-- LANTUL PE OAMENI [D49]: fiecare loc are gestul lui pe E, iar indemnul spune exact ce face gestul
-- ACUM -- nu "Sell" la gater (acolo nu se vinde nimic) si nu "Drop" cand de fapt iei [D40].
Strings.SAWMILL_LABEL = "Sawmill"
Strings.STORAGE_LABEL = "Storage"
Strings.TAVERN_LABEL = "Tavern" -- [D50] fostul debarcader
function Strings.promptStoreLogs(keyHint: string): string
    return `Store logs{keyHint}`
end
function Strings.promptTakeLogs(keyHint: string): string
    return `Take logs{keyHint}`
end
function Strings.promptDropLogs(keyHint: string): string
    return `Drop logs{keyHint}`
end
function Strings.promptTakePlanks(keyHint: string): string
    return `Take planks{keyHint}`
end
-- [D55, D56] linia fierului: shed-ul de scrap si forja
Strings.SHED_LABEL = "Scrap Shed"
Strings.FORGE_LABEL = "Forge" -- [D58] pe acoperis, ca la taverna: era singura cladire cu Upgrade fara nume
function Strings.promptStoreScrap(keyHint: string): string
    return `Store scrap{keyHint}`
end
function Strings.promptTakeScrap(keyHint: string): string
    return `Take scrap{keyHint}`
end
function Strings.promptSmeltScrap(keyHint: string): string
    return `Smelt scrap{keyHint}`
end
function Strings.promptTakeIron(keyHint: string): string
    return `Take iron{keyHint}`
end
-- [D56] Ca la gater: fara Smelter, forja topeste doar cat stai in inelul ei.
Strings.FORGE_STAND_HERE = "Stand here to smelt"
function Strings.forgeSmelting(left: number): string
    return `Smelting — {left} left`
end
-- Fara Sawyer, gaterul taie doar cat stai langa el. Owner-ul: "nu prea se vede textul ca trebuie sa
-- stai aici" -- deci nu mai e un indemn care apare abia cand esti deja acolo, ci o placuta pe locul
-- insusi, cu un inel pe jos, vazuta de oriunde se vede gaterul [D50].
Strings.SAWMILL_STAND_HERE = "Stand here to cut"
function Strings.sawmillCutting(left: number): string
    return `Cutting — {left} left`
end
function Strings.promptSellPlanks(keyHint: string, value: string): string
    return `Sell planks{keyHint} — {value}`
end
-- [D65] CUVINTELE LOCURILOR EREI 2, pe linie (FlowConfig): aceleasi fraze ca la depozit, gater, shed si forja, cu marfa
-- si cladirile Morii. Un loc al Erei 1 nu trece pe aici: isi are frazele lui de mai sus.
export type LineWords = {
    raw: string, -- marfa bruta, asa cum o numesti cand o duci ("scrap", "ore")
    done: string, -- marfa gata ("parts", "copper")
    doneOne: string,
    store: string, -- numele magaziei, pe eticheta ei
    processor: string, -- numele atelierului
    verb: string, -- ce face atelierul: "Cast", "Smelt"
    standHere: string,
    working: string, -- "Casting", "Smelting"
    byIt: string, -- "stay by the Foundry"
    -- [D70] numele liniei, pentru o unire: „the Cable line is slower" (veriga e a altei piese din aceeasi unire)
    name: string?,
    rawUnit: string?, -- [D70, pasul k4] la unire: cum se numara ce aduci („3 parts”); implicit `raw`
    rawUnitOne: string?, -- [verificatorul k4] la singular („1 part”)
    -- [l3, verificatorul A0/k12] numele scurt al atelierului, in textele sacului plin (pe telefonul mic trebuie sa incapa sub
    -- ~48 de litere, si pe eticheta de margine a ghidajului, si pe linia NEXT)
    processorShort: string?,
}
Strings.LINE_WORDS = {
    -- Era 1: locurile ei au controllerele lor, cu textele lor; de aici se iau doar cuvintele marfii (meniuri)
    wood = {
        raw = "logs",
        done = "planks",
        doneOne = "plank",
        store = "Storage",
        processor = "Sawmill",
        verb = "Cut",
        standHere = "Stand here to cut",
        working = "Cutting",
        byIt = "stay by the Sawmill",
    },
    iron = {
        raw = "scrap",
        done = "iron",
        doneOne = "iron",
        store = "Scrap Shed",
        processor = "Forge",
        verb = "Smelt",
        standHere = "Stand here to smelt",
        working = "Smelting",
        byIt = "stay by the Forge",
    },
    parts = {
        raw = "scrap",
        done = "parts",
        doneOne = "part",
        store = "Mill Store",
        processor = "Foundry",
        verb = "Cast",
        standHere = "Stand here to cast",
        working = "Casting",
        byIt = "stay by the Foundry",
    },
    copper = {
        raw = "ore",
        done = "copper",
        doneOne = "copper",
        store = "Ore Shed",
        processor = "Copper Furnace",
        verb = "Smelt",
        standHere = "Stand here to smelt",
        working = "Smelting",
        byIt = "stay by the furnace",
    },
    -- [D67] Era 3, The Wire Works: minereul de cupru se trage in sarma (bobine), bateriile turbinei se incarca in celule
    coils = {
        raw = "ore",
        done = "coils",
        doneOne = "coil",
        store = "Works Store",
        processor = "Wire Works",
        verb = "Draw",
        standHere = "Stand here to draw wire",
        working = "Drawing wire",
        byIt = "stay by the Wire Works",
    },
    power = {
        raw = "batteries",
        done = "power cells",
        doneOne = "power cell",
        store = "Battery Shed",
        processor = "Power House",
        verb = "Charge",
        standHere = "Stand here to charge",
        working = "Charging",
        byIt = "stay by the Power House",
    },
    -- [D70] Era 4, The Dam (numele sunt propuneri, PLAN-MOTOR-UNIRE §6 intrebarea 12): doua piese, unirea lor, cristalul.
    -- [pasul k4] `rawUnit`: cum se numara marfa adusa la unire („Dropped 3 parts”), nu „3 barrels and cable”
    barrels = {
        raw = "batteries",
        done = "barrels",
        doneOne = "barrel",
        store = "Battery Store",
        processor = "Switchyard",
        verb = "Load",
        standHere = "Stand here to load barrels",
        working = "Loading barrels",
        byIt = "stay by the Switchyard",
        name = "Barrel",
    },
    cable = {
        raw = "cable ore",
        done = "cable",
        doneOne = "cable",
        store = "Cable Store",
        processor = "Cable Works",
        verb = "Spin",
        standHere = "Stand here to spin cable",
        working = "Spinning cable",
        byIt = "stay by the Cable Works",
        name = "Cable",
    },
    grid = {
        raw = "barrels and cable",
        done = "power",
        doneOne = "power",
        store = "Relay Station",
        processor = "Relay Station",
        verb = "Join",
        rawUnit = "parts",
        rawUnitOne = "part",
        processorShort = "Relay",
        standHere = "Stand here to join",
        working = "Joining",
        byIt = "stay by the Relay Station",
        name = "Power",
    },
    crystal = {
        raw = "crystal",
        done = "ingots",
        doneOne = "ingot",
        store = "Crystal Shed",
        processor = "Kiln",
        verb = "Fire",
        standHere = "Stand here to fire crystal",
        working = "Firing crystal",
        byIt = "stay by the Kiln",
        name = "Crystal",
    },
} :: { [string]: LineWords }
Strings.MARKET_LABEL = "Market"

-- [D65] CUVINTELE LANTULUI, CA TABEL. Pana la D65 fiecare functie de mai jos (`menuHeldBack`, `menuGoTo`, `menuDoes`,
-- `menuUnit`, `stationNoEffect`...) avea verigile Erei 1 insirate intr-un `if`; Era 2 ar fi dublat fiecare lista.
-- Textele Erei 1 sunt aceleasi, litera cu litera.
--   subject  cine tine pe loc: ACTIUNEA, nu omul -- cat n-ai angajat pe nimeni pasul il faci tu, iar "the Porter is
--            slower" ar fi mintit [D40, D63]
--   goTo     meniul care repara veriga ("Go to Porter")
--   label    randul verigii din capul panoului Upgrades
--   advice   sfatul panoului Upgrades, dupa "Right now that is " (randul are 66 de litere de pixeli)
export type LinkWords = { subject: string, goTo: string, label: string, advice: string }
Strings.LINK_WORDS = {
    collect = {
        subject = "collecting",
        goTo = "Collector",
        label = "Collect",
        advice = "collecting — hire or upgrade Collectors.",
    },
    port = {
        subject = "carrying logs",
        goTo = "Porter",
        label = "Carry",
        advice = "carrying logs — hire or upgrade Porters.",
    },
    saw = {
        subject = "the Sawmill",
        goTo = "Sawmill",
        label = "Sawmill",
        advice = "the Sawmill — upgrade it to earn more.",
    },
    haul = {
        subject = "hauling planks",
        goTo = "Hauler",
        label = "Haul",
        advice = "hauling planks — hire or upgrade Haulers.",
    },
    scrapCollect = {
        subject = "collecting scrap",
        goTo = "Scrap Collector",
        label = "Collect scrap",
        advice = "scrap pickup — hire or upgrade Scrap Collectors.",
    },
    scrapPort = {
        subject = "carrying scrap",
        goTo = "Scrap Porter",
        label = "Carry scrap",
        advice = "carrying scrap — hire or upgrade Scrap Porters.",
    },
    forge = {
        subject = "the Forge",
        goTo = "Forge",
        label = "Forge",
        advice = "the Forge — upgrade it or its Smelters.",
    },
    ironHaul = {
        subject = "hauling iron",
        goTo = "Iron Hauler",
        label = "Haul iron",
        advice = "hauling iron — hire or upgrade Iron Haulers.",
    },
    dock = {
        subject = "the Tavern",
        goTo = "Tavern",
        label = "Tavern",
        advice = "the Tavern — upgrade it to earn more.",
    },
    -- Era 2, The Mill
    millCollect = {
        subject = "collecting scrap",
        goTo = "Mill Collector",
        label = "Collect scrap",
        advice = "scrap pickup — hire or upgrade Mill Collectors.",
    },
    millPort = {
        subject = "carrying scrap",
        goTo = "Mill Porter",
        label = "Carry scrap",
        advice = "carrying scrap — hire or upgrade Mill Porters.",
    },
    foundry = {
        subject = "the Foundry",
        goTo = "Foundry",
        label = "Foundry",
        advice = "the Foundry — upgrade it or its Founders.",
    },
    partsHaul = {
        subject = "hauling parts",
        goTo = "Parts Hauler",
        label = "Haul parts",
        advice = "hauling parts — hire or upgrade Parts Haulers.",
    },
    oreCollect = {
        subject = "collecting ore",
        goTo = "Ore Collector",
        label = "Collect ore",
        advice = "ore pickup — hire or upgrade Ore Collectors.",
    },
    orePort = {
        subject = "carrying ore",
        goTo = "Ore Porter",
        label = "Carry ore",
        advice = "carrying ore — hire or upgrade Ore Porters.",
    },
    furnace = {
        subject = "the Copper Furnace",
        goTo = "Copper Furnace",
        label = "Furnace",
        advice = "the Furnace — upgrade it or its Coppersmiths.",
    },
    copperHaul = {
        subject = "hauling copper",
        goTo = "Copper Hauler",
        label = "Haul copper",
        advice = "hauling copper — hire or upgrade Copper Haulers.",
    },
    market = {
        subject = "the Market",
        goTo = "Market",
        label = "Market",
        advice = "the Market — upgrade it to earn more.",
    },
    -- [D67] Era 3, The Wire Works
    worksCollect = {
        subject = "collecting ore",
        goTo = "Works Collector",
        label = "Collect ore",
        advice = "ore pickup — hire or upgrade Works Collectors.",
    },
    worksPort = {
        subject = "carrying ore",
        goTo = "Works Porter",
        label = "Carry ore",
        advice = "carrying ore — hire or upgrade Works Porters.",
    },
    wireworks = {
        subject = "the Wire Works",
        goTo = "Wire Works",
        label = "Wire Works",
        advice = "the Wire Works — upgrade it or its Wiredrawers.",
    },
    coilHaul = {
        subject = "hauling coils",
        goTo = "Coil Hauler",
        label = "Haul coils",
        advice = "hauling coils — hire or upgrade Coil Haulers.",
    },
    batteryCollect = {
        subject = "battery pickup", -- [2026-10-02] „collecting batteries” nu incapea pe randul panoului Upgrades
        goTo = "Battery Collector",
        label = "Collect power",
        advice = "batteries — hire or upgrade Battery Collectors.",
    },
    batteryPort = {
        subject = "carrying batteries",
        goTo = "Battery Porter",
        label = "Carry power",
        advice = "carrying batteries — hire more Battery Porters.",
    },
    powerhouse = {
        subject = "the Power House",
        goTo = "Power House",
        label = "Power House",
        advice = "the Power House — upgrade it or Electricians.",
    },
    powerHaul = {
        subject = "hauling cells", -- [2026-10-02] „hauling power cells” nu incapea pe randul panoului Upgrades
        goTo = "Power Hauler",
        label = "Haul cells",
        advice = "hauling cells — hire or upgrade Power Haulers.",
    },
    depot = {
        subject = "the Depot",
        goTo = "Depot",
        label = "Depot",
        advice = "the Depot — upgrade it to earn more.",
    },
    -- [D70] Era 4, The Dam (propuneri): butoaiele, cablul, unirea lor, cristalul, orasul
    damCollect = {
        subject = "battery pickup",
        goTo = "Dam Collector",
        label = "Collect batteries",
        advice = "battery pickup — hire or upgrade Dam Collectors.",
    },
    damPort = {
        subject = "carrying batteries",
        goTo = "Dam Porter",
        label = "Carry batteries",
        advice = "carrying batteries — hire or upgrade Dam Porters.",
    },
    switchyard = {
        subject = "the Switchyard",
        goTo = "Switchyard",
        label = "Switchyard",
        advice = "the Switchyard — upgrade it or Switchmen.",
    },
    barrelHaul = {
        subject = "hauling barrels",
        goTo = "Barrel Hauler",
        label = "Haul barrels",
        advice = "hauling barrels — hire or upgrade Barrel Haulers.",
    },
    cableCollect = {
        subject = "collecting ore",
        goTo = "Cable Collector",
        label = "Collect ore",
        advice = "cable ore — hire or upgrade Cable Collectors.",
    },
    cablePort = {
        subject = "carrying cable ore",
        goTo = "Cable Porter",
        label = "Carry ore",
        advice = "carrying ore — hire or upgrade Cable Porters.",
    },
    cableworks = {
        subject = "the Cable Works",
        goTo = "Cable Works",
        label = "Cable Works",
        advice = "the Cable Works — upgrade it or Cablemakers.",
    },
    cableHaul = {
        subject = "hauling cable",
        goTo = "Cable Hauler",
        label = "Haul cable",
        advice = "hauling cable — hire or upgrade Cable Haulers.",
    },
    relay = {
        subject = "the Relay Station",
        goTo = "Relay Station",
        label = "Relay",
        advice = "the Relay Station — upgrade it or Relay Keepers.",
    },
    pylonRun = {
        subject = "running power",
        goTo = "Pylon Runner",
        label = "Run power",
        advice = "running power — hire or upgrade Pylon Runners.",
    },
    crystalCollect = {
        subject = "collecting crystal",
        goTo = "Crystal Collector",
        label = "Collect crystal",
        advice = "crystal pickup — hire or upgrade Crystal Collectors.",
    },
    crystalPort = {
        subject = "carrying crystal",
        goTo = "Crystal Porter",
        label = "Carry crystal",
        advice = "carrying crystal — hire or upgrade Crystal Porters.",
    },
    kiln = {
        subject = "the Kiln",
        goTo = "Kiln",
        label = "Kiln",
        advice = "the Kiln — upgrade it or its Crystalsmiths.",
    },
    ingotHaul = {
        subject = "hauling ingots",
        goTo = "Ingot Hauler",
        label = "Haul ingots",
        advice = "hauling ingots — hire or upgrade Ingot Haulers.",
    },
    town = {
        subject = "the Switch House",
        goTo = "Switch House",
        label = "Switch House",
        advice = "the Switch House — upgrade it to earn more.",
    },
} :: { [string]: LinkWords }
-- Plasele au cate un nume pe linie: "your nets" (mai multe) si "the scrap net" (una singura) nu se acorda la fel.
-- [D67] `verb`: turbina nu se arunca in apa ca o plasa, se construieste (implicit "cast").
export type NetWords = {
    subject: string,
    plural: boolean,
    label: string,
    castFirst: string,
    verb: string?,
}
Strings.NET_WORDS = {
    wood = { subject = "your nets", plural = true, label = "Nets", castFirst = "your first net" },
    iron = {
        subject = "the scrap net",
        plural = false,
        label = "Scrap net",
        castFirst = "the Fifth Net",
    },
    parts = {
        subject = "the Mill nets",
        plural = true,
        label = "Mill nets",
        castFirst = "the Sixth Net",
    },
    copper = {
        subject = "the ore net",
        plural = false,
        label = "Ore net",
        castFirst = "the Tenth Net",
    },
    coils = {
        subject = "the Works nets",
        plural = true,
        label = "Works nets",
        castFirst = "the Eleventh Net",
    },
    power = {
        subject = "the turbine",
        plural = false,
        label = "Turbine",
        castFirst = "the First Turbine",
        verb = "build",
    },
    -- [D70] Era 4: turbina din zid umple butoaiele; unirea (`grid`) n-are plase
    barrels = {
        subject = "the Dam Turbine",
        plural = false,
        label = "Dam Turbine",
        castFirst = "the Dam Turbine",
        verb = "build",
    },
    cable = {
        subject = "the cable nets",
        plural = true,
        label = "Cable nets",
        castFirst = "a Cable Net",
    },
    crystal = {
        subject = "the crystal net",
        plural = false,
        label = "Crystal net",
        castFirst = "the Crystal Net",
    },
} :: { [string]: NetWords }
-- O cladire cu niveluri: ce face (cu om / doar cat stai tu langa ea) si verbul pragurilor ("cuts twice as fast").
export type BuildingWords = { does: string, alone: string, verb: string, much: boolean? }
Strings.BUILDING_WORDS = {
    net = { does = "Catches", alone = "Catches", verb = "catches", much = true },
    -- [D67] turbina sta in rau ca o plasa, dar nu prinde nimic: umple baterii (TycoonConfig.wordsKindOf)
    turbine = { does = "Fills batteries", alone = "Fills batteries", verb = "fills", much = true },
    saw = { does = "Cuts", alone = "Cuts only while you stand here", verb = "cuts" },
    -- [D56] ca gaterul: fara Smelter doar cat stai langa ea
    forge = {
        does = "Smelts scrap into iron",
        alone = "Smelts only while you stand here",
        verb = "smelts",
    },
    -- 35% = StationConfig.NO_TRADER_FACTOR
    dock = { does = "Sells", alone = "Sells at 35% until you hire an Innkeeper", verb = "sells" },
    foundry = {
        does = "Casts scrap into machine parts",
        alone = "Casts only while you stand here",
        verb = "casts",
    },
    furnace = {
        does = "Smelts ore into copper",
        alone = "Smelts only while you stand here",
        verb = "smelts",
    },
    market = { does = "Sells", alone = "Sells at 35% until you hire a Merchant", verb = "sells" },
    -- [D67] Era 3
    wireworks = {
        does = "Draws ore into coils of wire",
        alone = "Draws only while you stand here",
        verb = "draws",
    },
    powerhouse = {
        does = "Charges batteries into power cells",
        alone = "Charges only while you stand here",
        verb = "charges",
    },
    depot = { does = "Sells", alone = "Sells at 35% until you hire a Clerk", verb = "sells" },
    -- [D70] Era 4 (propuneri)
    switchyard = {
        does = "Loads batteries into barrels",
        alone = "Loads only while you stand here",
        verb = "loads",
    },
    cableworks = {
        does = "Spins ore into cable",
        alone = "Spins only while you stand here",
        verb = "spins",
    },
    relay = {
        does = "Joins barrels and cable",
        alone = "Joins only while you stand here",
        verb = "joins",
    },
    kiln = {
        does = "Fires crystal into ingots",
        alone = "Fires only while you stand here",
        verb = "fires",
    },
    town = { does = "Sells", alone = "Sells at 35% until you hire a Dispatcher", verb = "sells" },
} :: { [string]: BuildingWords }
function Strings.promptStoreRaw(words: LineWords, keyHint: string): string
    return `Store {words.raw}{keyHint}`
end
function Strings.promptTakeRaw(words: LineWords, keyHint: string): string
    return `Take {words.raw}{keyHint}`
end
function Strings.promptProcess(words: LineWords, keyHint: string): string
    return `{words.verb} {words.raw}{keyHint}`
end
function Strings.promptTakeDone(words: LineWords, keyHint: string): string
    return `Take {words.done}{keyHint}`
end
function Strings.lineWorking(words: LineWords, left: number): string
    return `{words.working} — {left} left`
end
-- [verificatorul k3] o singura piesa a unirii in traista: textele o numesc doar pe ea („cable”), nu „barrels and cable”
function Strings.guidePartTo(part: LineWords, union: LineWords): string
    return `Take the {part.done} to the {union.processor}`
end
function Strings.sackFullPart(part: LineWords, union: LineWords): string
    return `Sack full — take the {part.done} to the {union.processorShort or union.processor}`
end
function Strings.promptDropPart(part: LineWords, keyHint: string): string
    return `Drop {part.done}{keyHint}`
end
-- [D70, pasul k4] piesele duse la un vanzator: „Barrels and cable go to the Relay Station first”
-- [verificatorul k9-k10a] Cardul unui vanzator, cand n-ai nimic de vandut acolo (StateCopy.sellerNote): unde merge ce
-- duci, nu un refuz. Scurte, ca placa cardului sa ramana pe cel mult doua randuri (testul din StateCopy).
function Strings.sellerElsewhere(seller: string): string
    local words = Strings.LINK_WORDS[seller]
    return `Your sack has goods for the {if words ~= nil then words.goTo else "Tavern"}`
end
-- „Logs go to the Sawmill”, „Scrap goes to the Foundry”, „Cable ore goes to the Cable Works”
function Strings.rawGoesTo(line: LineWords): string
    local raw = line.raw
    local verb = if string.sub(raw, -1) == "s" then "go" else "goes"
    return `{string.upper(string.sub(raw, 1, 1))}{string.sub(raw, 2)} {verb} to the {line.processor}`
end
-- [verificatorul A0/k12] doua linii cu acelasi cuvant pentru marfa bruta, amandoua in traista: „Scrap goes to the Foundry
-- and the Forge” (intai atelierul celei cu mai multe bucati)
function Strings.rawGoesToBoth(line: LineWords, other: LineWords): string
    return `{Strings.rawGoesTo(line)} and the {other.processor}`
end
function Strings.partsToJoin(union: LineWords): string
    return `{string.upper(string.sub(union.raw, 1, 1))}{string.sub(union.raw, 2)} go to the {union.processor} first`
end
-- [D70, pasul k3] la o unire (Relay Station), piesa care lipseste: „Waiting for cable”, „Waiting for barrels”
function Strings.joinWaiting(part: LineWords): string
    return `Waiting for {part.done}`
end
function Strings.promptSellAt(keyHint: string, value: string): string
    return `Sell{keyHint} — {value}`
end
Strings.PROMPT_MARKET_RAW = "Scrap and ore get worked in the Mill first"
-- [D65, D67] Ce cumpara fiecare vanzator: pentru refuzul lui, cand ii aduci ce nu e al lui.
export type SellerWords = { buys: string, rawOnly: string }
Strings.SELLER_WORDS = {
    dock = {
        buys = "planks and iron",
        rawOnly = "The Tavern buys planks and iron, not logs or scrap",
    },
    market = {
        buys = "parts and copper",
        rawOnly = "The Market buys machine parts and copper, not scrap or ore",
    },
    depot = {
        buys = "coils and power cells",
        rawOnly = "The Depot buys coils and power cells, not ore or batteries",
    },
    -- [D70] orasul barajului (Switch House; numele sunt propuneri)
    town = {
        buys = "ingots and power",
        rawOnly = "The Switch House buys ingots and power, not batteries, ore or crystal",
    },
} :: { [string]: SellerWords }
-- Ce a facut un gest la un loc al Erei 2 (`UseResult`), ca `useResult` pentru Era 1. nil = locul nu e al ei.
function Strings.placeResult(
    line: string?,
    seller: string?,
    isStore: boolean,
    ok: boolean,
    reason: string,
    dropped: number,
    taken: number,
    staffed: boolean,
    elsewhere: string? -- [D67] vanzatorul care cumpara ce ai adus (clientul il stie din traista), daca e altul
): string?
    if seller ~= nil then
        local here = Strings.SELLER_WORDS[seller] or Strings.SELLER_WORDS.market
        local hereName = (Strings.LINK_WORDS[seller] or Strings.LINK_WORDS.market).goTo
        if ok then
            return nil -- vanzarea se anunta cand se scurge gramada, nu la predare
        elseif reason == "raw_only" then
            return here.rawOnly
        elseif reason == "part_to_relay" then
            -- [D70, pasul k4] butoaiele si cablul nu se vand singure: se unesc intai
            return Strings.partsToJoin(Strings.LINE_WORDS.grid)
        elseif reason == "other_seller" then
            -- [D67] cu trei vanzatori, "ce ai adus" poate fi al oricaruia: numele vine din traista, altfel nu se ghiceste
            local other = if elsewhere ~= nil then Strings.LINK_WORDS[elsewhere] else nil
            return if other ~= nil
                then `The {other.goTo} buys that — the {hereName} buys {here.buys}`
                else `That sells elsewhere — the {hereName} buys {here.buys}`
        end
        return nil
    end
    local words = if line ~= nil then Strings.LINE_WORDS[line] else nil
    if words == nil then
        return nil
    end
    local function raw(n: number): string
        if n == 1 and words.rawUnitOne ~= nil then
            return `1 {words.rawUnitOne}`
        end
        return `{n} {words.rawUnit or words.raw}`
    end
    local function done(n: number): string
        return if n == 1 then `1 {words.doneOne}` else `{n} {words.done}`
    end
    if not ok then
        if reason == "sack_full" then
            return "Sack full"
        elseif string.sub(reason, -6) == "_empty" then
            -- magazia liniei (FlowConfig `storeEmpty`: mill_store_empty, ..., [D70] dam_store_empty, crystal_shed_empty)
            return `The {words.store} is empty`
        elseif string.sub(reason, 1, 8) == "nothing_" then
            -- atelierul liniei (FlowConfig `nothingDone`: nothing_cast, ..., [D70] nothing_loaded, nothing_joined)
            return if staffed then `No {words.done} yet` else `No {words.done} yet — {words.byIt}`
        elseif reason == "no_wheel" then
            return "Build the Water Wheel first"
        elseif reason == "no_furnace" then
            return "Build the Copper Furnace first"
        elseif reason == "no_ore_shed" then
            return "Build the Ore Shed first"
        elseif reason == "ore_to_furnace" then
            return "Ore goes to the Copper Furnace"
        -- [D67] Era 3
        elseif reason == "no_steam" then
            return "Build the Steam Engine first"
        elseif reason == "no_powerhouse" then
            return "Build the Power House first"
        elseif reason == "no_battery_shed" then
            return "Build the Battery Shed first"
        elseif reason == "batteries_to_powerhouse" then
            return "Batteries go to the Power House"
        -- [D70, pasul k4] Era 4: Crystal Shed si Kiln sunt platforme; magaziile si atelierele barajului sunt acolo de la el
        elseif reason == "no_crystal_shed" then
            return "Build the Crystal Shed first"
        elseif reason == "no_kiln" then
            return "Build the Kiln first"
        elseif reason == "batteries_to_switchyard" then
            return "Batteries go to the Switchyard"
        elseif reason == "cable_ore_to_cableworks" then
            return "Cable ore goes to the Cable Works"
        elseif reason == "crystal_to_kiln" then
            return "Crystal goes to the Kiln"
        end
        return nil
    end
    if isStore then
        return if dropped > 0 then `Stored {raw(dropped)}` else `Took {raw(taken)}`
    end
    if dropped > 0 and taken > 0 then
        return `Dropped {raw(dropped)} · took {done(taken)}`
    elseif dropped > 0 then
        -- [verificatorul k3] la o unire, „stay by” ar minti cat lipseste cealalta piesa: placa de deasupra inelului spune
        -- singura daca se uneste ceva („Waiting for barrels” sau „Joining — N left”)
        return if staffed or words.rawUnit ~= nil
            then `Dropped {raw(dropped)}`
            else `Dropped {raw(dropped)} — {words.byIt}`
    end
    return `Took {done(taken)}`
end
Strings.PROMPT_DOCK_RAW = "Logs go to the Sawmill first"
Strings.PROMPT_DOCK_SCRAP = "Scrap gets smelted at the Forge first" -- [D55, D56]
Strings.PROMPT_DOCK_BOTH = "Logs to the Sawmill, scrap to the Forge first" -- [D55, D56]
Strings.SACK_FULL_LOGS = "Sack full — take the logs to the Sawmill"
Strings.SACK_FULL_PLANKS = "Sack full — take the planks to the Tavern"
Strings.SACK_FULL_SCRAP = "Sack full — take the scrap to the Forge" -- [D55, D56]
Strings.SACK_FULL_IRON = "Sack full — take the iron to the Tavern" -- [D56]
Strings.SACK_FULL_BOTH = "Sack full — take the planks and iron to the Tavern" -- [D56]
Strings.SACK_FULL_FINDS = "Sack full — take the finds to the Tavern" -- [D56] doar gasiri: se vand si asa
-- [D65] marfa Morii: bruta la atelierul liniei ei, gata la Piata
function Strings.sackFullRaw(line: string): string
    local words = Strings.LINE_WORDS[line] or Strings.LINE_WORDS.wood
    -- [l3] unirea (doua piese): „Sack full — barrels and cable to the Relay”, nu 59 de litere care nu incap pe telefon
    if words.rawUnit ~= nil then
        return `Sack full — {words.raw} to the {words.processorShort or words.processor}`
    end
    return `Sack full — take the {words.raw} to the {words.processor}`
end
-- [D65, D67] marfa gata a unui vanzator al erelor noi: "Sack full — sell at the Market" / "... at the Depot"
-- [D67] felinarele de pe strada se aprind cu primul curent vandut: anuntul, o singura data [D43]
Strings.LAMPS_ON = "Your first power is sold — the street lamps are on!"
-- [D75] la baraj, primul curent vandut la Switch House aprinde orasul de peste rau
Strings.TOWN_LIT = "Your power reaches the town — its lights come on!"
-- [D70] treptele modernizarii satului vechi, anuntate cand vin. A cincea tace cand vine odata cu primul curent vandut
-- (atunci o anunta LAMPS_ON); altfel (al doilea Works Porter luat dupa primul curent) are fraza ei.
-- [D70] butonul de pe bannerul unei trepte: o privire de 4 s spre satul vechi, unde s-a schimbat ceva
function Strings.lookAround(keyHint: string): string
    return `Look{keyHint}`
end
Strings.MODERN_STAGE = {
    "Wire comes to every street!",
    "Iron carts for everyone!",
    "Tin roofs and brick for the old village!",
    "Glass in every window!",
    "The old village lights up!",
} :: { string }
function Strings.sackFullSell(seller: string): string
    return `Sack full — sell at the {(Strings.LINK_WORDS[seller] or Strings.LINK_WORDS.market).goTo}`
end
-- Ghidajul [GuideMath]: ce scrie sageata deasupra tintei.
Strings.GUIDE_FIRST_PAD = "Step on the glowing pad"
function Strings.guideBuy(name: string): string
    return `Step on it to buy {name}`
end
-- Fara "(E)": pe telefon nu exista tasta. Tasta o arata cardul obiectului, cand esti langa el.
Strings.GUIDE_COLLECT = "Collect from your net"
-- [D51] PASII buclei de mana (GuideMath.loopStep): al doilea rand al liniei NEXT si eticheta sagetii.
Strings.STEP_TAKE_PLANKS = "Take the planks at the Sawmill"
Strings.STEP_TAKE_FROM_STORAGE = "Take the logs from the Storage"
function Strings.stepStayCut(left: number): string
    return `Stay in the ring: {left} left to cut`
end
function Strings.stepWaitNet(count: number, need: number): string
    return `Wait for your net: {count}/{need}`
end
Strings.STEP_NETS_CATCHING = "Your nets are catching"
Strings.STEP_COINS_COMING = "Coins are coming in from the Tavern"
-- [D59] Indiciul pontonului pe linia NEXT: doar dupa primul peste, doar cat strangi bani pentru quest si n-ai nimic de facut
-- cu mana. Fara sageata: pescuitul e o alegere, nu un pas.
Strings.HINT_FISH_WHILE_SAVING = "While you save: fish at the pier"
function Strings.hintTreasureWaiting(phrase: string): string
    return `{string.upper(string.sub(phrase, 1, 1))}{string.sub(phrase, 2)} is waiting at your pier`
end
Strings.STEP_BUY = "Walk up to it and buy it"
-- [D63] Pasul spune ACELASI verb ca butonul cartonasului si ca quest-ul (TycoonConfig.verbOf). Vazut cu sonda in primul
-- minut al unui joc proaspat: quest-ul zicea "Cast your first net", butonul "Cast it — free", iar pasul "buy it".
function Strings.stepBuy(verb: string): string
    if verb == "cast" then
        return "Walk up to it and cast it"
    elseif verb == "hire" then
        return "Walk up to the sign and hire"
    elseif verb == "get" then
        return "Walk up to it and get it"
    elseif verb == "ring" then
        return "Walk up to it and ring it"
    end
    return "Walk up to it and build it"
end
Strings.STEP_UPGRADE = "Walk up to it and press Upgrade"
Strings.GUIDE_LOGS_TO_SAWMILL = "Take the logs to the Sawmill"
-- acelasi text ca quest-ul `sell_once`: pe linia NEXT, al doilea rand se ascunde cand repeta primul
Strings.GUIDE_SELL_PLANKS = "Sell the planks at the Tavern"
-- [D56] turul de mana al fierului; "Sell the iron at the tavern" = textul quest-ului `sell_iron`
Strings.GUIDE_SCRAP_TO_FORGE = "Take the scrap to the Forge"
Strings.GUIDE_SELL_IRON = "Sell the iron at the Tavern"
Strings.GUIDE_SELL_BOTH = "Sell the planks and iron at the Tavern"
Strings.STEP_TAKE_IRON = "Take the iron at the Forge"
Strings.STEP_TAKE_FROM_SHED = "Take the scrap from the Scrap Shed"
Strings.GUIDE_COLLECT_SCRAP = "Collect the scrap from the Fifth Net"
-- [D56] doar gasiri in traista: se vand si neprelucrate
function Strings.guideSellFinds(count: number): string
    return if count == 1 then "Sell the find at the Tavern" else "Sell the finds at the Tavern"
end
function Strings.stepStaySmelt(left: number): string
    return `Stay in the ring: {left} left to smelt`
end
-- [D65] Aceiasi pasi pe o linie a Morii, din cuvintele liniei (LINE_WORDS): aceleasi fraze ca la lemn si la fier.
function Strings.guideRawTo(words: LineWords): string
    return `Take the {words.raw} to the {words.processor}`
end
function Strings.stepStayWork(words: LineWords, left: number): string
    return `Stay in the ring: {left} left to {string.lower(words.verb)}`
end
function Strings.stepTakeDone(words: LineWords): string
    return `Take the {words.done} at the {words.processor}`
end
function Strings.stepTakeFromStore(words: LineWords): string
    return `Take the {words.raw} from the {words.store}`
end
function Strings.guideCollectRaw(words: LineWords): string
    return `Collect the {words.raw} from your net`
end
function Strings.guideSellAt(sellerLabel: string, full: boolean): string
    return if full then `Sack full — sell at the {sellerLabel}` else `Sell at the {sellerLabel}`
end
function Strings.guideSaving(name: string): string
    return `Saving for {name}`
end
-- Ce a facut un E la depozit, la gater sau la debarcader. Refuzurile se spun mereu (un E care nu
-- face nimic, in tacere, e exact ce D43 interzice); reusitele doar cand nu se vad singure.
function Strings.useResult(
    place: string,
    ok: boolean,
    reason: string,
    dropped: number,
    taken: number,
    staffed: boolean
): string?
    if not ok and reason == "closed" then
        return Strings.CLOSED_HERE -- [D70] un loc al altei harti
    end
    if not ok then
        if reason == "sack_full" then
            return "Sack full"
        elseif reason == "storage_empty" then
            return "The Storage is empty"
        elseif reason == "nothing_cut" then
            return if staffed then "Nothing cut yet" else "Nothing cut yet — stay by the saw"
        elseif reason == "raw_only" and place == "dock" then
            -- [D70, pasul k4] doar la taverna: la Piata, la Depou si la Switch House spune vanzatorul lor (placeResult)
            return "The Tavern buys planks and iron, not logs or scrap"
        -- [D55, D56] scrap-ul are drumul lui: locul care il refuza spune unde merge. Forja, nu shed-ul: shed-ul
        -- e doar magazia Scrap Collector-ului, iar in turul de mana scrap-ul merge direct la forja.
        elseif reason == "scrap_to_forge" then
            return if place == "sawmill"
                then "Scrap gets smelted at the Forge, not cut"
                else "Scrap goes to the Forge"
        elseif reason == "shed_empty" then
            return "The Scrap Shed is empty"
        elseif reason == "nothing_smelted" then
            return if staffed then "No iron yet" else "No iron yet — stay by the Forge"
        end
        return nil
    end
    local function scrap(n: number): string
        return `{n} scrap`
    end
    local function iron(n: number): string
        return `{n} iron`
    end
    local function logs(n: number): string
        return if n == 1 then "1 log" else `{n} logs`
    end
    local function planks(n: number): string
        return if n == 1 then "1 plank" else `{n} planks`
    end
    if place == "storage" then
        return if dropped > 0 then `Stored {logs(dropped)}` else `Took {logs(taken)}`
    elseif place == "sawmill" then
        if dropped > 0 and taken > 0 then
            return `Dropped {logs(dropped)} · took {planks(taken)}`
        elseif dropped > 0 then
            return if staffed
                then `Dropped {logs(dropped)}`
                else `Dropped {logs(dropped)} — stay close to cut them`
        end
        return `Took {planks(taken)}`
    elseif place == "shed" then
        return if dropped > 0 then `Stored {scrap(dropped)}` else `Took {scrap(taken)}`
    elseif place == "forge" then
        if dropped > 0 and taken > 0 then
            return `Dropped {scrap(dropped)} · took {iron(taken)}`
        elseif dropped > 0 then
            return if staffed
                then `Dropped {scrap(dropped)}`
                else `Dropped {scrap(dropped)} — stay close to smelt it`
        end
        return `Took {iron(taken)}`
    end
    return nil -- la debarcader se vede singur: gramada creste, apoi pleaca barca
end
-- [Roata] O rotire gratuita pe zi [D46]. Sansele se afiseaza, nu se ascund.
Strings.WHEEL_TITLE = "Lucky Wheel"
-- [D59] Eticheta din lume, pe doua randuri: roata si avizierul stau la 86 unul de altul pe punte, iar
-- "Lucky Wheel" (80) si "Village Board" (94) pe cate un rand se lipeau intr-unul [vazut in Studio, 2026-09-15].
Strings.WHEEL_TAG = "Lucky\nWheel"
Strings.WHEEL_SPIN = "Spin — free"
function Strings.wheelNextSpin(duration: string): string
    return `Next free spin in {duration}`
end
function Strings.wheelWonPearls(n: number): string
    return `+{n} pearl` .. (if n == 1 then "!" else "s!")
end
function Strings.wheelRejected(reason: string): string
    if reason == "not_ready" then
        return "Come back tomorrow for a free spin"
    end
    return "Can't spin right now"
end

-- Prima litera mare, pentru frazele care incep cu un nume din config ("a chest" -> "A chest").
local function capital(text: string): string
    return `{string.upper(string.sub(text, 1, 1))}{string.sub(text, 2)}`
end

-- [D59] ROATA LA PONTON: darurile raului, fara monede. Cardul E, ca la orice obiect.
function Strings.wheelCard(keyHint: string): string
    return `Spin the wheel{keyHint}`
end
Strings.WHEEL_READY_TOAST = "Your free spin is ready"
-- [D60] In sat, unde statea roata, ramane un indicator: roata s-a mutat in balci, iar rotirea zilnica te asteapta acolo.
Strings.WHEEL_MOVED_TAG = "Wheel moved\nto the fair"
Strings.WHEEL_MOVED = "The wheel moved to the fair"
Strings.WHEEL_READY_AT_FAIR = "A free spin is waiting at the fair"
-- pe cardul timonierului (240 lat): mai scurt decat ceasul din fereastra
function Strings.wheelCardWait(duration: string): string
    return `Next spin in {duration}`
end
function Strings.wheelWonTreasure(phrase: string): string
    return `{capital(phrase)} is drifting to your pier!`
end
function Strings.wheelWonConverted(n: number): string
    return `Your pier is full: +{n} pearls instead`
end
function Strings.wheelWonBait(n: number): string
    return `+{n} golden bait!`
end

-- [D59] UNDITA. Cardul spune ce face E; bara spune ce tii apasat. Fara esec, deci fara "missed"/"lost".
function Strings.fishCast(keyHint: string): string
    return `Cast{keyHint}`
end
-- pe cardul de 240: numele scurt al lucrului ("Hook the Golden Driftwood (E)" nu incape)
local HOOK_NAMES: { [string]: string } =
    { bottle = "bottle", chest = "chest", golden = "driftwood" }
function Strings.fishHook(kindId: string, keyHint: string): string
    return `Hook the {HOOK_NAMES[kindId] or "catch"}{keyHint}`
end
function Strings.fishBait(n: number): string
    return `Golden bait ×{n}`
end
Strings.FISH_HOLD_KEY = "Hold E to reel"
Strings.FISH_HOLD_TOUCH = "Hold to reel"
Strings.FISH_BITE = "!"
function Strings.fishCaught(name: string, cm: number): string
    return `{name} · {cm} cm`
end
function Strings.pearlsGained(n: number): string
    return `+{n} pearl{if n == 1 then "" else "s"}`
end
Strings.FISH_NEW = "New!"
Strings.FISH_RECORD = "Record!"
Strings.FISH_BAIT_USED = "Bait ×2"
function Strings.fishRejected(reason: string): string
    if reason == "expired" then
        return "Your line was out too long. Cast again"
    elseif reason == "not_here" then
        return "Cast from the jetty, over the water" -- [D61] iazul din balci
    end
    return "Cast again"
end

-- [D59] CE ADUCE RAUL
function Strings.treasureArrived(phrase: string): string
    return `{capital(phrase)} drifted to your pier`
end
function Strings.treasureOpened(name: string, n: number): string
    return `{name} · +{n} pearls`
end
Strings.NOTE_TITLE = "A note in a bottle"
Strings.JOURNAL_COMPLETE_TITLE = "Journal complete!"
function Strings.outfitUnlocked(name: string): string
    return `New outfit: {name}`
end

-- [D59] JURNALUL: pestii (siluete pana la prima prindere) si ce ai scos din rau, cu biletele citite
Strings.JOURNAL_TITLE = "Journal"
Strings.JOURNAL_TAB_FISH = "Fish"
Strings.JOURNAL_TAB_RIVER = "River"
function Strings.journalFishCount(n: number, total: number): string
    return `Fish caught {n}/{total}`
end
Strings.JOURNAL_REWARD = "Catch every fish to earn the River Legend outfit"
Strings.JOURNAL_UNKNOWN = "???"
Strings.JOURNAL_NOT_CAUGHT = "Not caught yet"
function Strings.journalCaught(count: number, best: number): string
    return `Caught {count} · best {best} cm`
end
Strings.TIER_NAMES = {
    common = "Common",
    uncommon = "Uncommon",
    rare = "Rare",
    epic = "Epic",
    legendary = "Legendary",
} :: { [string]: string }
function Strings.journalTreasure(pearls: number): string
    return `+{pearls} pearls each`
end
function Strings.journalFound(n: number): string
    return `Things hooked from the river: {n}`
end
function Strings.journalNotes(n: number, total: number): string
    return `Notes found {math.min(n, total)}/{total}`
end
Strings.JOURNAL_NO_NOTES = "Bottles carry notes. Hook one at the pier."

-- [D59] AVIZIERUL SATULUI: perlele cumpara aspect, pentru sat si pentru tine
Strings.BOARD_TITLE = "Village Board"
Strings.BOARD_TAG = "Village\nBoard" -- vezi WHEEL_TAG
Strings.BOARD_TAB_VILLAGE = "Village"
Strings.BOARD_TAB_OUTFITS = "Outfits"
function Strings.boardCard(keyHint: string): string
    return `Village Board{keyHint}`
end
Strings.BOARD_BUILD = "Build"
Strings.BOARD_BUILT = "Built"
Strings.BOARD_BUY = "Buy"
Strings.BOARD_WEAR = "Wear"
Strings.BOARD_WEARING = "Wearing"
function Strings.boardJournal(n: number, total: number): string
    return `Complete the Journal ({n}/{total})`
end
Strings.BOARD_AT_TAILOR = "Sold by the tailor at the fair" -- [D61]
Strings.BOARD_BLURB = "Pearls buy looks for your village and for you."
function Strings.shopResult(what: string, name: string, ok: boolean, reason: string): string
    if ok then
        if what == "decor" then
            return `Built: {name}`
        elseif what == "outfit" then
            return `New outfit: {name}`
        elseif what == "title" then
            return `New title: {name}` -- [D60]
        end
        return `Wearing {name}`
    end
    if reason == "pearls" then
        return "Not enough pearls"
    elseif reason == "already" then
        return "You already have it"
    elseif reason == "journal" then
        return "Complete the Journal to earn it"
    elseif reason == "tailor" then
        return "The tailor at the fair sells that one" -- [D61]
    elseif reason == "soon" then
        return "The tailor is still sewing that one" -- [D61] foaia tinutei inca nu e urcata
    elseif reason == "pass" then
        return "That one comes with the Supporter pass" -- [D61, partea 2]
    elseif reason == "not_owned" then
        return "Buy it first"
    elseif reason == "not_earned" then
        return "You haven't earned that title yet" -- [D60]
    end
    return "Can't do that right now"
end

-- [Offline] Fereastra de revenire. Un singur lucru spus, nu o lista.
Strings.WELCOME_TITLE = "Welcome back"
-- deasupra sumei, care sta pe randul ei cu moneda: fraza intreaga nu incapea in fereastra [2026-09-15]
Strings.WELCOME_EARNED = "Your river earned"
Strings.WELCOME_CONTINUE = "Back to the river"
-- [D59] ce a venit pe rau cat ai lipsit (cel mult trei asteapta la ponton)
Strings.WELCOME_RIVER_TITLE = "The river brought you something"
function Strings.welcomeArrived(n: number): string
    return if n == 1 then "Something drifted to your pier" else `{n} things drifted to your pier`
end
function Strings.welcomeAway(duration: string): string
    return `You were away for {duration}`
end
-- [D71] fara monede si fara ceva pe rau, dar cu o zi noua in serie: fereastra se deschide doar pentru ea
Strings.WELCOME_STREAK_TITLE = "Good to see you again"
-- [D70, pasul k6] la baraj, cat lipsesc oameni (AWAY 0): ce s-a intamplat si pe cine sa angajezi. Doar primul care lipseste
-- (lantul `after` il face singurul de cumparat acum); adevarat oricine ar fi el [verificatorul j13b].
Strings.WELCOME_STALLED_TITLE = "Welcome back to the Dam"
function Strings.welcomeStalled(name: string, missing: number?): string
    local article = if string.find(name, "^[AEIOUaeiou]") then "an" else "a"
    -- [verificatorul k6] cand lipsesc mai multi, un singur om nu-l porneste: spune cati si pe cine intai
    if missing ~= nil and missing > 1 then
        return `Your Dam earned nothing while you were away. It needs {missing} new workers: hire {article} {name} first!`
    end
    return `Your Dam earned nothing while you were away. Hire {article} {name} to keep it running!`
end
-- [D70, pasul k6, verificatorul k6] in sat, cu barajul gata de ridicat: regula intreaga, spusa dinainte (D70, D74 pct. 8):
-- suma de start, monedele cumparate trec peste ea, restul intra in baraj, iar pana la oamenii noi barajul nu castiga cat lipsesti
function Strings.damStartRule(sum: string, newHires: number): string
    return `Build the Dam and you start there with {sum}, plus any coins you bought; the rest goes into the Dam. `
        .. `Until you hire its {newHires} new workers, it earns nothing while you're away.`
end

-- [D60] Balciul de seara (place-ul al doilea)
Strings.FAIR_ROW_HOME = "Row home"
Strings.FAIR_FERRY_TAG = "Ferry home"
Strings.FAIR_ROWING_HOME = "Rowing home..."
function Strings.fairRowHomeCard(keyHint: string): string
    return `Row home{keyHint}`
end
-- [D60] Titlurile: ce scrie sub numele tau in balci. Panoul spune de unde vine fiecare.
Strings.TITLES_TITLE = "Titles"
Strings.TITLES_BLURB = "Your title shows under your name at the fair."
function Strings.titlesWorn(label: string): string
    return `Your title: {label}`
end
Strings.TITLES_EARNED = "Earned"
Strings.TITLES_TO_EARN = "Still to earn"
Strings.TITLES_FOR_SALE = "For pearls"
Strings.TITLE_FROM = {
    era = "How far your river has come",
    legend = "Every fish in the Journal",
    record = "Your biggest fish so far",
    champion = "Biggest fish of last week",
    pond = "Rounds won at the Contest Pond",
    sharpshooter = "Perfect games at the booths",
    -- [D71] seria zilnica (cea mai lunga; o zi lipsa nu o rupe)
    regular = "A 7-day streak",
    old_friend = "A 30-day streak",
    decor = "From your village decor",
    sale = "Bought with pearls",
}
function Strings.titleLegendProgress(n: number, total: number): string
    return `Catch every fish ({n}/{total})`
end
function Strings.titlePondProgress(n: number, goal: number): string
    return `Win pond rounds ({n}/{goal})`
end
function Strings.titleSharpshooterProgress(n: number, goal: number): string
    return `Play perfect booth games ({n}/{goal})`
end
-- [D71] din seria de acum (ce numara copilul zi de zi), cu regula blanda spusa dinainte [D43]. Pe randurile „Still to
-- earn” sub-eticheta ia toata latimea randului (TitleController), deci textul nu se mai taie.
function Strings.titleStreakProgress(run: number, goal: number): string
    return `Streak {run}/{goal} days. A missed day won't break it.`
end
function Strings.titleDecorHint(decorName: string): string
    return `Build the {decorName} in your village`
end
-- [D61] Concursul de la iaz: tabla de pe mal, banda de sus cat esti aproape, rezultatul tau la sfarsitul rundei.
Strings.POND_BOARD_TITLE = "CONTEST POND"
Strings.POND_PRIZES_NOTE = "Prizes when the round ends"
Strings.POND_ALONE = "You were the only one fishing"
Strings.POND_ENTER = "Land a fish to enter"
Strings.POND_NOBODY_YET = "No catches yet"
Strings.POND_TITLE_UNLOCKED = "New title: Pond Champion"
local function clock(seconds: number): string
    local s = math.max(0, math.floor(seconds))
    return string.format("%d:%02d", math.floor(s / 60), s % 60)
end
function Strings.ordinal(n: number): string
    local tens = n % 100
    local suffix = if tens >= 11 and tens <= 13
        then "th"
        elseif n % 10 == 1 then "st"
        elseif n % 10 == 2 then "nd"
        elseif n % 10 == 3 then "rd"
        else "th"
    return `{n}{suffix}`
end
function Strings.pondTimeLeft(seconds: number): string
    return `{clock(seconds)} left`
end
function Strings.pondNextIn(seconds: number): string
    return `Next round in {clock(seconds)}`
end
function Strings.pondBanner(index: number, seconds: number): string
    return `POND CONTEST · round {index} · {clock(seconds)} left`
end
function Strings.pondBannerBreak(seconds: number): string
    return `POND CONTEST · next round in {clock(seconds)}`
end
function Strings.pondYou(place: number, species: string, cm: number): string
    return `You: {Strings.ordinal(place)} · {species} {math.floor(cm)} cm`
end
function Strings.pondRow(species: string, cm: number): string
    return `{species} {math.floor(cm)}`
end
function Strings.pondLast(index: number): string
    return `Round {index}`
end
function Strings.pondResult(
    index: number,
    place: number,
    count: number,
    prize: number,
    contest: boolean
): string
    if not contest then
        return `Round {index}: you were the only one fishing · +{prize} pearls`
    end
    return `Round {index}: {Strings.ordinal(place)} of {count} · +{prize} pearls`
end

-- [D61] Gheretele de joc: cardul, panoul si ce ai castigat. Premiile se dau la primele jocuri din zi; panoul o spune.
Strings.BOOTH_TITLES = { ring = "Ring Toss", duck = "Hook a Duck" }
Strings.BOOTH_HELP = {
    ring = "Throw when the ring is over a bottle",
    duck = "Drop the hook when a duck is under it",
}
Strings.BOOTH_HINT = {
    ring = "Prizes: 1 hit 1 · 3 hits 4 · 5 hits 10 pearls",
    duck = "Bigger numbers swim faster",
}
Strings.BOOTH_ACTION = { ring = "Throw", duck = "Hook" }
Strings.BOOTH_AGAIN = "Play again"
Strings.BOOTH_WAIT = "Getting ready..."
Strings.BOOTH_NO_PRIZE = "Play for fun, prizes are back tomorrow"
Strings.SHARPSHOOTER_UNLOCKED = "New title: Sharpshooter"
function Strings.boothCard(game: string, keyHint: string): string
    return `Play {(Strings.BOOTH_TITLES :: any)[game] or "a game"}{keyHint}`
end
function Strings.boothProgress(game: string, done: number, total: number, score: number): string
    if game == "ring" then
        return `Rings {done}/{total} · Hits {score}`
    end
    return `Hooks {done}/{total} · Score {score}`
end
function Strings.boothPrizeGames(used: number, total: number): string
    return `Prize games today {used}/{total}`
end
function Strings.boothResult(game: string, score: number, prize: number, prizeGame: boolean): string
    local what = if game == "ring" then `{score} hits` else `Score {score}`
    if not prizeGame then
        return `{what} · just for fun`
    end
    if prize <= 0 then
        return `{what} · no prize this time`
    end
    return `{what} · +{prize} pearls`
end
function Strings.boothRejected(reason: string): string
    if reason == "too_far" then
        return "Walk up to the booth to play"
    elseif reason == "invalid" or reason == "no_game" then
        return "That game didn't count. Play again"
    end
    return "Try again in a moment"
end

-- [D61] Mesele si Wave.
function Strings.sitCard(keyHint: string): string
    return `Sit{keyHint}`
end
function Strings.standCard(keyHint: string): string
    return `Stand up{keyHint}`
end
Strings.WAVE = "Wave"
function Strings.seatRejected(reason: string): string
    if reason == "taken" then
        return "Someone is sitting there"
    end
    return "Walk up to the seat"
end

-- [D60] Oamenii din balci: cardul de langa cineva si panoul cu ce a facut.
function Strings.lookAtCard(name: string, keyHint: string): string
    return `Look at {name}{keyHint}`
end
function Strings.cardEra(era: number, name: string): string
    return `Era {era}: {name}`
end
Strings.CARD_INCOME = "Income"
Strings.CARD_INCOME_UNKNOWN = "Not measured yet"
Strings.CARD_FISH = "Biggest fish"
Strings.CARD_NO_FISH = "None yet"
Strings.CARD_TREASURES = "Pulled from the river"
Strings.CARD_LIKES = "Village likes" -- [D61, partea 2]
Strings.CARD_STREAK = "Daily streak" -- [D71]
-- [D71] seria de acum si cea mai lunga; pe un rand de 220 la 15 px
function Strings.cardStreak(run: number, best: number): string
    if run <= 0 then
        return "Not started"
    end
    return if best > run then `{Strings.streakDays(run)} (best {best})` else Strings.streakDays(run)
end
Strings.CARD_DECOR = "Village decor"
Strings.CARD_JOURNAL = "Journal"
Strings.CARD_ADD_FRIEND = "Add friend"
Strings.CARD_GONE = "They just left the fair"
function Strings.cardFish(name: string, cm: number): string
    return `{name}, {cm} cm`
end
function Strings.cardOf(n: number, total: number): string
    return `{n}/{total}`
end
-- [D60] Scena, adica tabela balciului: trei clasamente ale saptamanii, trofeele si campionul.
Strings.STAGE_TITLES = { fish = "BIGGEST FISH", income = "RICHEST RIVER", era1 = "FASTEST ERA 1" }
Strings.STAGE_UNITS = { fish = "cm", income = "/s", era1 = "" }
Strings.STAGE_EMPTY = "No one yet"
Strings.STAGE_EMPTY_BOARD = "No one yet\nthis week" -- pe hartia unui panou gol, pe doua randuri
Strings.STAGES_TITLE = "Leaderboards"
Strings.STAGES_BLURB = "This week's best. The boards start over every Monday."
Strings.STAGES_EMPTY = "No one yet this week. It could be you."
Strings.STAGES_TABS = { fish = "Fish", income = "Income", era1 = "Era 1", trophies = "Trophies" }
Strings.STAGES_TROPHIES_BLURB = "The biggest of each fish, ever."
Strings.TROPHY_NONE = "Not caught yet"
-- [2026-09-17] sub un trofeu fara record, cand altele au; cand niciunul n-are, o singura fraza sub tot randul
Strings.TROPHY_OPEN = "No record"
Strings.TROPHIES_EMPTY = "No record catches yet"
Strings.CHAMPION_TAG = "Champion of the Week"
function Strings.stagesCard(keyHint: string): string
    return `Leaderboards{keyHint}`
end
function Strings.trophyLine(cm: number): string
    return string.format("%.1f cm", cm)
end
-- [D60] Negustorul: vitrina zilei, patru lucruri de aspect, aceleasi pentru toata lumea.
Strings.MARKET_TITLE = "Market"
function Strings.marketCard(keyHint: string): string
    return `Market{keyHint}`
end
Strings.MARKET_BLURB = "Four looks a day. The rest stays on the Village Board and in Titles."
function Strings.marketRestock(duration: string): string
    return `New stock in {duration}`
end
Strings.MARKET_KIND = { decor = "For your village", outfit = "Outfit", title = "Title" }
Strings.MARKET_OWNED = "Owned"
-- [D61] Croitoreasa: infatisarea (gratuita) si tinutele. Panoul arata omul tau mare, intors pe rand.
Strings.TAILOR_TITLE = "Tailor"
function Strings.tailorCard(keyHint: string): string
    return `Tailor{keyHint}`
end
Strings.TAILOR_TAB_LOOK = "Look"
Strings.TAILOR_TAB_OUTFITS = "Outfits"
Strings.TAILOR_SAVE = "Save look"
Strings.TAILOR_SAVED = "Saved"
Strings.TAILOR_ONLY_HERE = "Only at the tailor"
Strings.TAILOR_SOON = "Still being sewn" -- foaia tinutei inca nu e urcata: nu se vinde si nu se poate proba
Strings.OUTFIT_WITH_PASS = "Comes with the Supporter pass" -- [D61, partea 2] nu se cumpara cu perle
Strings.TAILOR_FIELDS = { body = "Build", hair = "Hair", hairColor = "Hair color", skin = "Skin" }
function Strings.tailorField(field: string): string
    return (Strings.TAILOR_FIELDS :: any)[field] or field
end
Strings.TAILOR_HAIR = { short = "Short", long = "Long", bun = "Bun", bald = "None" }
function Strings.tailorHair(style: string): string
    return (Strings.TAILOR_HAIR :: any)[style] or style
end
function Strings.tailorChoice(index: number, total: number): string
    return `{index} of {total}`
end
function Strings.tailorTrying(name: string): string
    return `Trying on: {name}`
end
function Strings.tailorWearing(name: string): string
    return `Wearing: {name}`
end
-- [D62, pasul 3] Darurile raului: un butoi, o lada sau un bustean de aur trec pe rau; il scoti de pe punte.
function Strings.driftCard(keyHint: string): string
    return `Grab it{keyHint}`
end
Strings.DRIFT_NAMES = { barrel = "barrel", crate = "crate", golden = "golden log" }
function Strings.driftSeen(kind: string): string
    local name = (Strings.DRIFT_NAMES :: any)[kind] or "barrel"
    return `A {name} is drifting by. Run along the deck and grab it!`
end
Strings.DRIFT_GOLDEN = "A golden log is drifting by!"
-- [D73] serverul n-a dat darul: a trecut de punte, sau ai scos deja unul mai nou (fiecare dar se plateste o data) [D43]
Strings.DRIFT_GONE = "It drifted past the deck."
Strings.DRIFT_NEWER = "You already caught a newer gift."

-- [D61, partea 2] Coltul cu Robux. Numele si frazele lucrurilor stau in MonetizationConfig; pretul vine de la Roblox.
Strings.SHOP_TITLE = "Shop"
-- cardul tarabei cu copertina aurie din balci (ShopController)
function Strings.shopCard(keyHint: string): string
    return `Shop{keyHint}`
end
Strings.SHOP_BLURB = "Speed, room and looks. Never luck. Nothing you buy is ever lost."
Strings.SHOP_OWNED = "Owned"
Strings.SHOP_BUY = "Buy"
function Strings.shopPrice(robux: number): string
    return `R$ {robux}`
end
function Strings.shopHourNow(amount: string): string
    return `Coins worth one hour of your income. Right now: +{amount} coins.`
end
function Strings.shopGranted(name: string): string
    return `{name} is yours. Forever.`
end
function Strings.shopCoins(amount: string): string
    return `+{amount} coins`
end
function Strings.shopRefused(reason: string): string
    if reason == "soon" then
        return "Opens soon"
    elseif reason == "owned" then
        return "You already own it"
    elseif reason == "nothing" then
        return "Nothing to double right now"
    elseif reason == "village" then
        return "Sold in your village, where your income is known"
    end
    return "The purchase window didn't open. Try again."
end
-- fereastra "Welcome back": inca o data suma de acolo
function Strings.welcomeDouble(price: number?): string
    return if price ~= nil then `Double it  R${price}` else "Double it"
end
Strings.WELCOME_DOUBLED = "Doubled!"
-- [D71] Curba de cand lipsesti, spusa cand ai trecut de viteza intreaga (OfflineCalc): orele adevarate (8, sau 16 cu Long
-- Nights), apoi un sfert din viteza pana la 24 h, apoi odihna. Nu in rosu: nu e o pedeapsa [P2, nota 16].
-- [verificator] nota „slow” spune si oprirea, dinainte [D43]: altfel afli de ea abia dupa prima zi pierduta
function Strings.welcomeSlow(fullHours: number, stopHours: number): string
    local full, stop = math.floor(fullHours + 0.5), math.floor(stopHours + 0.5)
    return `Your village worked at full speed for {full} hours, then at quarter speed. It rests after {stop} hours.`
end
function Strings.welcomeRested(fullHours: number, stopHours: number): string
    local full, stop = math.floor(fullHours + 0.5), math.floor(stopHours + 0.5)
    return `Full speed for {full} hours, then quarter speed. After {stop} hours your village rests until you come back.`
end
-- [D71] Seria zilnica (StreakMath): o zi lipsa nu o rupe. Fara presiune: nicio numaratoare, nimic de pierdut.
-- `record`: seria de acum a trecut de cea mai lunga (la egalitate, nu); `title`: un titlu al seriei castigat azi.
function Strings.streakNext(run: number, record: boolean, title: string?): string
    if title ~= nil then
        return `Day {run} of your streak! New title: {title}`
    end
    return if record
        then `Day {run} of your streak! Your best yet.`
        else `Day {run} of your streak!`
end
function Strings.streakAgain(best: number): string
    return `A new streak starts today. Your best is {best} days.`
end
-- pastila din balci: eticheta mica si valoarea
Strings.STREAK_LABEL = "Streak"
function Strings.streakDays(n: number): string
    return if n == 1 then "1 day" else `{n} days`
end

-- [D61, partea 2] Poarta satelor: vizitezi satul altui om din balci, ca fotografie; un like pe zi pentru fiecare sat.
Strings.VISIT_TITLE = "Village Gate"
function Strings.visitCard(keyHint: string): string
    return `Village Gate{keyHint}`
end
Strings.VISIT_BLURB = "Visit the village of anyone at the fair. Look around; nothing can be taken."
Strings.VISIT_EMPTY = "Nobody else is at the fair right now."
function Strings.visitMyLikes(likes: number): string
    return if likes == 1 then "Your village has 1 like" else `Your village has {likes} likes`
end
Strings.VISIT_BUTTON = "Visit"
Strings.VISIT_CARD_BUTTON = "Visit village"
function Strings.visitRowSub(era: number, decor: number, likes: number): string
    return `Era {era} · {decor} decorations · {likes} likes`
end
function Strings.visitMiniCard(name: string, keyHint: string): string
    return `Visit {name}'s village{keyHint}`
end
function Strings.visitBannerTop(name: string): string
    return `{name}'s village`
end
function Strings.visitBannerBottom(era: number, decor: number, likes: number): string
    return `Era {era} · {decor} decorations · {likes} likes`
end
-- [D70, pasul k11] gazda a ridicat barajul: vizitatorul vede satul ei de dinainte, cu semnul acesta in locul erei
function Strings.visitBuilding(decor: number, likes: number): string
    return `Building the Dam · {decor} decorations · {likes} likes`
end
Strings.VISIT_GUEST_BOOK = "Guest Book"
function Strings.visitLikeCard(keyHint: string): string
    return `Leave a like{keyHint}`
end
Strings.VISIT_LIKED_TODAY = "Liked today"
function Strings.visitBack(keyHint: string): string
    return `Back to the fair{keyHint}`
end
function Strings.visitLikedToast(name: string): string
    return `{name} liked your village`
end
function Strings.visitLikeGiven(name: string): string
    return `You liked {name}'s village`
end
function Strings.visitRefused(reason: string): string
    if reason == "gone" then
        return "They just left the fair"
    elseif reason == "already" then
        return "You already liked this village today"
    elseif reason == "self" then
        return "That's your own village"
    end
    return "Can't do that right now"
end
-- marginile balciului care se deschid in D61: placuta lor spune asta, ca nimeni sa nu astepte degeaba [D43]
Strings.FAIR_OPENS_SOON = "Opens soon"
-- Barca de la ponton, in amonte, spre balci. Eticheta de pe apa, cardul si drumul.
Strings.FERRY_TAG = "Ferry to the Fair"
function Strings.ferryCard(keyHint: string): string
    return `Row up to the fair{keyHint}`
end
Strings.FERRY_SKIP = "Skip"
Strings.FERRY_ROWING = "Rowing up to the fair..."
-- De ce n-a plecat barca (FerryService). Spune ce s-a intamplat si ce poti face; satul merge mai departe [D40, D43].
function Strings.ferryFailed(reason: string): string
    if reason == "studio" then
        return "The ferry only sails in the published game"
    elseif reason == "closed" then
        return "The fair isn't open in this game yet"
    elseif reason == "no_profile" then
        return "Your save is still loading. Try again in a moment"
    end
    return "The ferry couldn't leave. Try again in a moment"
end

-- [Tutorial] Deschiderea. O propozitie pe pas, niciodata doua.
Strings.TUTORIAL_CHAPTER_TITLE = "Chapter 1 — The Landing"
Strings.TUTORIAL_TAP_ANYWHERE = "Tap anywhere to continue"
-- [D51] cartea vine dupa prima vanzare, cand ai ceva de luat din ea
Strings.TUTORIAL_CLAIM_REWARDS = "Claim your rewards here!"

-- [Quest-uri] Lista de sarcini si bannerul. Scurt: stau pe randuri inguste, langa contoare.
Strings.QUESTS_TITLE = "Quests"
Strings.QUEST_LOCKED = "Quest locked"
Strings.QUEST_GO = "Go!"
Strings.QUEST_CLAIM = "Claim"
Strings.QUEST_DONE = "done"
function Strings.questRejected(reason: string): string
    if reason == "not_done" then
        return "Not finished yet"
    elseif reason == "already" then
        return "Already claimed"
    elseif reason == "closed" then
        return Strings.CLOSED_HERE -- [D70] un quest al altei harti
    end
    return "Can't claim that"
end

-- [D70, pasul j11] Pragul de venit in cifrele HUD-ului ("Earn 4T coins a second"): textul unui quest de venit si, cu
-- " first", cartonasul clopotului barajului. Un singur sablon, ca cele doua sa spuna mereu aceeasi cifra.
function Strings.earnPerSecond(goalText: string): string
    return `Earn {goalText} coins a second`
end

-- [Statii] Panoul de nivel. Textele sunt scurte pentru ca stau pe un rand ingust, langa cifre.
-- Panoul se numeste dupa CE FACI acolo, nu dupa locul unde esti: "Riverbank" nu spunea nimic
-- cuiva care tocmai l-a deschis. Sub cele trei debite sta o propozitie care explica de ce conteaza,
-- si una care spune ce sa faci ACUM -- fara ele, panoul e trei cifre si patru butoane.
Strings.STATIONS_TITLE = "Upgrades"
Strings.STATIONS_EXPLAIN = "Your river only moves as fast as its slowest link."
Strings.STATION_BULK = "Buy levels"
-- Randul intreg din panoul Stations are 560 la marimea mica (15), adica 66 de litere de pixeli: frazele mai lungi
-- ieseau din panou [2026-09-15]. Numele meseriei ramane intreg, locul se spune scurt.
function Strings.stationsAdvice(bottleneck: string): string
    if bottleneck == "nets" then
        return "Right now that is the nets — upgrade one to earn more."
    end
    local words = Strings.LINK_WORDS[bottleneck] or Strings.LINK_WORDS.dock
    return `Right now that is {words.advice}`
end
Strings.STATION_UPGRADE = "Upgrade"
-- ---- meniul unei meserii [D49] -----------------------------------------------------------------
function Strings.crewWorking(count: number, name: string, plural: string): string
    return if count == 1 then `Your {name} is on the job` else `{count} {plural} on the job`
end
-- Pe pasii de drum si la gater, fara om, pasul e al tau; la taverna, vinde singura, incet.
function Strings.crewNone(role: string, name: string): string
    if role == "trader" then
        return `No {name} — the Tavern sells slowly`
    elseif role == "merchant" then
        return `No {name} — the Market sells slowly`
    end
    return `No {name} — you do this yourself`
end
-- ECHIPAJ LA MAXIM PE VERIGA SLABA: nu mai e nimic de cumparat aici in Era 1. "No gain yet" ar fi
-- sugerat ca ceva de pe meniul asta ar ajuta [D40, D49].
function Strings.crewMaxed(plural: string, bell: string): string
    return `{plural} are at their best here — ring the {bell}`
end
-- [2026-09-30] clopotul e deja tras: nu mai trimite la el, ci la cartierul unde mai e de crescut (EraWords)
function Strings.crewMaxedNext(plural: string, zoneName: string): string
    return `{plural} are at their best here — build up {zoneName}`
end
function Strings.crewMaxedComing(plural: string, zoneName: string): string
    return `{plural} are at their best — more comes with {zoneName}`
end
-- [D70, pasul k6] era urmatoare e in joc pe alta harta: drumul spre ea
function Strings.crewMaxedBuild(plural: string, zoneName: string): string
    local name = string.gsub(zoneName, "^The ", "the ")
    return `{plural} are at their best — time to build {name}`
end
function Strings.crewMaxedDone(plural: string): string
    return `{plural} are at their best here`
end
Strings.MENU_TIER_UP = "Level up"
-- De ce nu se poate apasa un buton de meserie. Acelasi cuvant pe care il intoarce serverul.
function Strings.crewBlock(reason: string?, secondAt: number): string
    if reason == "max_tier" then
        return "Top level"
    elseif reason == "max_people" then
        return "All hired"
    elseif reason == "tier" then
        return `Needs level {secondAt}`
    elseif reason == "no_person" then
        return "Hire one at its pad"
    end
    return "Not available"
end
function Strings.menuUpgradeCount(count: number): string
    return if count == 1 then "Upgrade" else `Upgrade x{count}`
end
Strings.STATION_BOTTLENECK = "← slowest link"
Strings.STATION_BOTTLENECK_SHORT = "← slowest" -- [D70, pasul k4] capul pe doua coloane (barajul, ChainHead)
Strings.STATION_CANT_AFFORD = "not enough"
Strings.STATION_NEED_MORE = "Not enough coins yet"
function Strings.stationLevel(level: number): string
    return `Level {level}`
end
function Strings.stationNextBoost(level: number): string
    return `Next boost at level {level}`
end
-- Cand statia nu e veriga slaba, un nivel nu aduce NIMIC acum. Textul o spune pe fata: e regula
-- "textul nu minte" [D40], si e chiar lectia pe care jocul vrea s-o predea.
-- Scurt SI corect gramatical. Prima varianta lipea "the nets" de "is" ("the nets is the slowest
-- link") si, in plus, era atat de lung incat intra peste nota din dreapta cartonasului.
function Strings.stationNoEffect(bottleneck: string): string
    if bottleneck == "nets" then
        return "No gain yet — nets are slowest"
    end
    local words = Strings.LINK_WORDS[bottleneck] or Strings.LINK_WORDS.dock
    return `No gain yet — {words.subject} is slowest`
end
-- [D56] Forja cumparata, dar inca fara plasa de scrap: linia fierului n-are ce duce.
-- [D65] La fel orice linie care se deschide cu plasa ei: piesele cu Sixth Net, cuprul cu Tenth Net.
function Strings.lineNotOpen(line: string?): string
    local words = Strings.NET_WORDS[line or "iron"] or Strings.NET_WORDS.iron
    return `No gain yet — {words.verb or "cast"} {words.castFirst} first`
end
-- ---- ruinele [D53] ----------------------------------------------------------------------------
-- Eticheta cartonasului langa o platforma incuiata: ruina, sau avizierul unde se angajeaza un om.
Strings.PAD_EYEBROW_RUINS = "RUINS"
Strings.PAD_EYEBROW_NOT_BUILT = "NOT BUILT YET" -- [D67, audit] turbina incuiata: umbra ei, nu o ruina
Strings.PAD_EYEBROW_WANTED = "HELP WANTED"
-- Ce trebuie facut intai. Primeste TycoonMath.Blocker, cu numele deja rezolvate: textul spune exact
-- conditia pe care o verifica jocul [D40].
function Strings.padNeeds(
    b: {
        kind: string,
        name: string?,
        level: number?,
        hire: boolean?,
        first: boolean?,
        ring: boolean?,
        zone: string?,
        goalText: string?,
        fresh: boolean?, -- [D70, pasul k4] o lume noua (barajul): acolo n-a fost nimic de reconstruit
    }
): string
    local name = b.name or "it"
    if b.kind == "after" then
        if b.ring then
            return `Ring the {name} first` -- [D65] prima platforma a unui cartier cere clopotul celui dinainte
        end
        if b.hire then
            local article = if string.find(name, "^[AEIOUaeiou]") then "an" else "a"
            return `Hire {article} {name} first`
        end
        return `Build the {name} first`
    elseif b.kind == "net" then
        return if b.first then "Cast your first net" else `Cast the {name} first`
    elseif b.kind == "level" then
        return `Upgrade {name} to level {b.level or 2} first`
    elseif b.kind == "income" then
        return `{Strings.earnPerSecond(b.goalText or "more")} first` -- [D70] Dam Bell
    end
    if b.fresh then
        return `Build everything else at {b.zone or "The Dam"} first` -- [D70, pasul k4]
    end
    return `Rebuild everything else on {b.zone or "The Landing"} first`
end

-- ---- meniul obiectului, simplu [D52] ----------------------------------------------------------
-- Owner-ul, pe meniul cu sase pastile si debite pe secunda: "nu prea inteleg nimic din ele daca inchid
-- un ochi". Fiecare text raspunde la o singura intrebare: unde sunt, cat face, merita acum, cat costa.
function Strings.menuLevelStep(level: number, toLevel: number): string
    return `Level {level} → Level {toLevel}`
end
function Strings.menuTierLine(
    tier: number,
    maxTier: number,
    count: number,
    maxPeople: number
): string
    return `Level {tier} of {maxTier} · {count} of {maxPeople} people`
end
-- Ce face cladirea, deasupra cifrei mari. Gaterul fara Sawyer si taverna fara Innkeeper spun si DE CE
-- merg cum merg [D43]; 35% = StationConfig.NO_TRADER_FACTOR.
function Strings.menuDoes(kind: string, staffed: boolean): string
    local words = Strings.BUILDING_WORDS[kind] or Strings.BUILDING_WORDS.dock
    return if staffed then words.does else words.alone
end
-- Ce face omul: aceleasi cuvinte ca pe platforma lui. [D56] Fiecare linie cu oamenii ei.
function Strings.crewDoes(role: string): string
    if role == "collector" then
        return "Empties your nets into the Storage"
    elseif role == "porter" then
        return "Carries logs from the Storage to the Sawmill"
    elseif role == "sawyer" then
        return "Keeps the saw running"
    elseif role == "hauler" then
        return "Carries planks from the Sawmill to the Tavern"
    elseif role == "scrapCollector" then
        return "Empties the Fifth Net into the Scrap Shed"
    elseif role == "scrapPorter" then
        return "Carries scrap from the Scrap Shed to the Forge"
    elseif role == "smelter" then
        return "Keeps the Forge smelting"
    elseif role == "ironHauler" then
        return "Carries iron from the Forge to the Tavern"
    elseif role == "millCollector" then
        return "Empties the Mill nets into the Mill Store"
    elseif role == "millPorter" then
        return "Carries scrap from the Mill Store to the Foundry"
    elseif role == "founder" then
        return "Keeps the Foundry casting"
    elseif role == "partsHauler" then
        return "Carries machine parts from the Foundry to the Market"
    elseif role == "oreCollector" then
        return "Empties the Tenth Net into the Ore Shed"
    elseif role == "orePorter" then
        return "Carries ore from the Ore Shed to the Copper Furnace"
    elseif role == "coppersmith" then
        return "Keeps the Copper Furnace smelting"
    elseif role == "copperHauler" then
        return "Carries copper from the Copper Furnace to the Market"
    elseif role == "merchant" then
        return "Runs the Market"
    -- [D67] Era 3
    elseif role == "worksCollector" then
        return "Empties the Works nets into the Works Store"
    elseif role == "worksPorter" then
        return "Carries ore from the Works Store to the Wire Works"
    elseif role == "wiredrawer" then
        return "Keeps the Wire Works drawing"
    elseif role == "coilHauler" then
        return "Carries coils from the Wire Works to the Depot"
    elseif role == "clerk" then
        return "Runs the Depot"
    elseif role == "batteryCollector" then
        return "Takes full batteries to the Battery Shed"
    elseif role == "batteryPorter" then
        return "Carries batteries from the Battery Shed to the Power House"
    elseif role == "electrician" then
        return "Keeps the Power House charging"
    elseif role == "powerHauler" then
        return "Carries power cells from the Power House to the Depot"
    end
    return "Runs the Tavern"
end
-- Ce spune un om cand apare prima data in sesiune: exact treaba lui, pe drumul lui [D40, D49]; o singura replica.
local CREW_HELLO: { [string]: string } = {
    collector = "I'll empty your nets into the Storage.",
    porter = "I'll carry logs from the Storage to the Sawmill.",
    sawyer = "I'll keep the saw running, even while you're away.",
    hauler = "I'll take the planks from the Sawmill to the Tavern.",
    trader = "I'll keep the Tavern selling while you're away.",
    scrapCollector = "I'll empty the Fifth Net into the Scrap Shed.",
    scrapPorter = "I'll carry scrap from the Scrap Shed to the Forge.",
    smelter = "I'll keep the Forge smelting, even while you're away.",
    ironHauler = "I'll take the iron from the Forge to the Tavern.",
    -- [D65] Era 2
    millCollector = "I'll empty the Mill nets into the Mill Store.",
    millPorter = "I'll carry scrap from the Mill Store to the Foundry.",
    founder = "I'll keep the Foundry casting, even while you're away.",
    partsHauler = "I'll take the machine parts from the Foundry to the Market.",
    merchant = "I'll keep the Market selling while you're away.",
    oreCollector = "I'll empty the Tenth Net into the Ore Shed.",
    orePorter = "I'll carry ore from the Ore Shed to the Copper Furnace.",
    coppersmith = "I'll keep the Copper Furnace smelting, even while you're away.",
    copperHauler = "I'll take the copper from the Copper Furnace to the Market.",
    -- [D67] Era 3
    worksCollector = "I'll empty the Works nets into the Works Store.",
    worksPorter = "I'll carry ore from the Works Store to the Wire Works.",
    wiredrawer = "I'll keep the Wire Works drawing, even while you're away.",
    coilHauler = "I'll take the coils from the Wire Works to the Depot.",
    clerk = "I'll keep the Depot selling while you're away.",
    batteryCollector = "I'll take the full batteries to the Battery Shed.",
    batteryPorter = "I'll carry batteries from the Battery Shed to the Power House.",
    electrician = "I'll keep the Power House charging, even while you're away.",
    powerHauler = "I'll take the power cells from the Power House to the Depot.",
}
function Strings.crewHello(role: string, name: string): string?
    local job = CREW_HELLO[role]
    return if job ~= nil then `I'm {name}. {job}` else nil
end
-- Unitatea de sub cifra mare. Bustenii pana la gater, scandurile de acolo incolo -- cuvintele pe care
-- jocul le foloseste deja ("Store logs", "Sell planks"). [D56] Pe linia fierului: scrap pana la forja, fier de acolo.
-- [D65] Dupa veriga si linia ei: plasele si pasii dinaintea atelierului numara marfa bruta, atelierul si ce vine dupa
-- el marfa gata; un vanzator, marfa gata a primei lui linii (taverna: scanduri; Piata: piese). `beforeProcessor` il
-- stie cine intreaba (StationConfig.LINES), ca fisierul asta sa ramana doar text.
function Strings.menuUnit(line: string?, beforeProcessor: boolean): string
    local words = Strings.LINE_WORDS[line or "wood"] or Strings.LINE_WORDS.wood
    return `{if beforeProcessor then words.raw else words.done} a minute`
end
-- [D62] Un nivel cumparat se vede in lume: cifra lui pluteste deasupra obiectului. La un prag (10/25/50...) un
-- banner spune ce s-a dublat, cu aceleasi cuvinte ca randul "Level 10: catches twice as much" din meniu [D40].
function Strings.levelReached(level: number): string
    return `Level {level}`
end
function Strings.tierReached(tier: number): string
    return `Level {tier}`
end
-- [D62] Capitolul incheiat: bannerul si ce urmeaza.
function Strings.chapterDone(title: string, subtitle: string): string
    return `{title} complete · {subtitle}`
end
function Strings.chapterDoneReward(pearls: number, nextSubtitle: string?): string
    local reward = if pearls == 1 then "+1 pearl" else `+{pearls} pearls`
    return if nextSubtitle ~= nil then `{reward} · Next: {nextSubtitle}` else reward
end
Strings.CREW_TIER_THANKS = "Better tools. Thanks!"
function Strings.secondHired(name: string): string
    return `Second {name} hired`
end
function Strings.milestoneTitle(name: string, level: number): string
    return `{name} · Level {level}`
end
function Strings.milestoneNow(kind: string, mult: number): string
    local how = if mult == 2 then "twice" else `{mult}x`
    local words = Strings.BUILDING_WORDS[kind] or Strings.BUILDING_WORDS.dock
    local verb = string.upper(string.sub(words.verb, 1, 1)) .. string.sub(words.verb, 2)
    return `{verb} {how} as {if words.much then "much" else "fast"} now`
end
function Strings.menuMilestoneDone(kind: string, level: number, mult: number): string
    return `Level {level} reached! {Strings.milestoneNow(kind, mult)}`
end
function Strings.menuMilestone(kind: string, level: number, mult: number): string
    local how = if mult == 2 then "twice" else `{mult}x`
    local words = Strings.BUILDING_WORDS[kind] or Strings.BUILDING_WORDS.dock
    return `Level {level}: {words.verb} {how} as {if words.much then "much" else "fast"}`
end
-- Castigul real al cumparaturii, pe minut. `amount` nil = mai mic decat se poate scrie cu o zecimala:
-- nu devine "+0", care ar parea ca nu aduce nimic [D40].
local function earns(what: string, amount: string?): string
    return if amount == nil
        then `{what} earns a little more`
        else `{what} earns +{amount} coins a minute`
end
function Strings.menuEarnsLevel(amount: string?): string
    return earns("Next level", amount)
end
function Strings.menuEarnsTier(amount: string?): string
    return earns("Next level", amount)
end
function Strings.menuEarnsSecond(name: string, amount: string?): string
    return earns(`A second {name}`, amount)
end
-- Cand cumparatura de aici nu aduce nimic: CINE tine venitul in loc. `tie` = veriga aia e doar la fel
-- de lenta (egalitate): "slower" ar fi mintit tocmai atunci [D40]. [D56] `line` = pe linia fierului plasa e una.
-- [D70] `holder` = linia careia ii apartine veriga, cand e alta piesa din aceeasi unire: „the Cable line is slower”.
function Strings.menuHeldBack(link: string, tie: boolean, line: string?, holder: string?): string
    -- [D63] Pentru copii: aceleasi cuvinte ca in `stationNoEffect` ("No gain yet — ..."), fara contractie si fara
    -- drumul intreg ("carrying scrap to the Forge" era jumatate de rand). Subiectul ramane ACTIUNEA, nu omul: cat n-ai
    -- angajat pe nimeni, pasul il faci tu, iar "the Porter is slower" ar fi mintit [D40].
    local subject, verb = "the Tavern", "is"
    local holderWords = if holder ~= nil then Strings.LINE_WORDS[holder] else nil
    if link == "nets" then
        local nets = Strings.NET_WORDS[holder or line or "wood"] or Strings.NET_WORDS.wood
        subject, verb = nets.subject, if nets.plural then "are" else "is"
    elseif holderWords ~= nil and holderWords.name ~= nil then
        subject = `the {holderWords.name} line`
    elseif Strings.LINK_WORDS[link] ~= nil then
        subject = Strings.LINK_WORDS[link].subject
    end
    return `No gain yet — {subject} {verb} ` .. (if tie then "just as slow" else "slower")
end
function Strings.menuGoTo(link: string): string
    local words = Strings.LINK_WORDS[link]
    return `Go to {if words ~= nil then words.goTo else "Nets"}`
end
-- Butoanele meseriei. Blocat: motivul sta chiar pe buton, fara pret. Fara om, butonul ramane cu
-- eticheta lui, stins: randul de deasupra spune deja "Hire one at its pad".
function Strings.menuCrewButton(what: string, block: string?, secondAt: number): string
    if block == "max_tier" then
        return "Top level"
    elseif block == "max_people" then
        return "All hired"
    elseif block == "tier" then
        return `Hire a second at level {secondAt}`
    end
    return if what == "tier" then Strings.MENU_TIER_UP else "Hire a second"
end
-- [D70, pasul j10] refuzul unui lucru al altei harti (satul vechi cand esti la baraj): rar, doar intr-o cursa
Strings.CLOSED_HERE = "That's not on this map"
function Strings.upgradeRejected(reason: string): string
    if reason == "coins" then
        return "Not enough coins"
    elseif reason == "locked" then
        return "Build it first"
    elseif reason == "max_tier" then
        return "Already at the top level"
    elseif reason == "max_people" then
        return "That crew is full"
    elseif reason == "tier" then
        return "Level up first"
    elseif reason == "no_person" then
        return "Hire the first one at its pad"
    elseif reason == "closed" then
        return Strings.CLOSED_HERE -- [D70] un lucru al altei harti
    end
    return "Can't upgrade that"
end

-- linia "NEXT" din HUD, cand banii au ajuns: nu mai lipseste nimic, doar du-te si calca
Strings.OBJ_READY = "ready!"
-- [D63] Tinta fara sfarsit de pe linia NEXT (AmbitionMath), cand nu mai e niciun quest si ghidajul tace: pragul urmator
-- al cladirii sau al plasei care tine venitul in loc, nivelul urmator al meseriei, sau al doilea om.
function Strings.ambitionText(what: string, name: string, target: number): string
    if what == "secondHire" then
        return `Hire a second {name}`
    end
    return `{name} to level {target}`
end
Strings.NET_FULL_LABEL = "FULL" -- eticheta de pe plasa, scurta prin definitie
Strings.NET_FAST_FIRST = "Fast first catch" -- [D51] prima plasa, in tutorial
function Strings.netFilling(count: number, capacity: number): string
    return `Filling up: {count}/{capacity}`
end
-- [D51] cardul obiectului. [D58] Tasta sta langa verb, ca la E ("Sell (E) — 40"): owner-ul a cerut o tasta pentru
-- Upgrade fara sa stie ca U exista deja -- nu scria nicaieri.
function Strings.cardUpgrade(cost: string?, keyHint: string): string
    return if cost ~= nil then `Upgrade{keyHint} · {cost}` else `Upgrade{keyHint}`
end
Strings.CARD_SACK_FULL = "Sack full"
-- [D54] panoul "Sound": nivelul muzicii si al efectelor, 0..10
Strings.MENU_SOUND = "Sound"
Strings.AUDIO_TITLE = "Sound"
Strings.AUDIO_MUSIC = "Music"
Strings.AUDIO_SOUNDS = "Sounds"
function Strings.audioLevel(level: number): string
    return if level <= 0 then "Off" else `{level * 10}%`
end
-- Cartonasul de la apropiere e o CONFIRMARE, nu un indemn: nimic nu se mai cumpara calcand pe
-- obiect. "Step on it to build" a iesit -- ar fi mintit din clipa in care mersul nu mai cumpara.
Strings.PAD_EYEBROW = "BUY"
-- [D63] VERBUL DE PE BUTON E CEL DIN QUEST. Quest-ul spune "Cast a second net", "Hire a Porter", "Build the Forge",
-- "Get a Bigger Sack", "Ring the Landing Bell", iar butonul spunea "Buy for 28" la toate: un copil trebuia sa faca singur
-- legatura dintre cele doua. `verb`: "cast" | "hire" | "get" | "ring" | orice altceva = "build".
local PAD_VERBS: { [string]: string } = { cast = "Cast", hire = "Hire", get = "Get", ring = "Ring" }
function Strings.padTakeFree(verb: string): string
    return `{PAD_VERBS[verb] or "Build"} it — free`
end
function Strings.padBuyFor(verb: string, price: string): string
    return `{PAD_VERBS[verb] or "Build"} for {price}`
end
function Strings.padNeedMore(missing: string): string
    return `Need {missing} more`
end
-- Cat ai si cat iti ramane. Owner-ul a cerut explicit sa se vada CAT esti pe cale sa cheltui.
function Strings.padSpend(have: string, left: string): string
    return `{have} → {left} left`
end
Strings.MENU_COLLECTION = "Collection"
Strings.MENU_WORKSHOP = "Workshop"

return Strings
