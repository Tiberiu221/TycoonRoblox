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
function Strings.padNeedMoreCoins(n: number): string -- [A]
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
function Strings.eraZoneOpen(zoneName: string): string -- [D]
    return `{zoneName} is open`
end

-- ---- [19-24] Atelier / Forge -----------------------------------------------------------------
-- [D56] Cladirea e acum Forge; colectia (reparatiile) e pusa deoparte -- textele ei raman, nefolosite.
Strings.FORGE_LIT = "The Forge is lit." -- [F]
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
function Strings.offlineReturn(
    amount: string
): string -- [F] -- WelcomeBack nu se trage inca pe server, nefolosit
    return `Your river earned {amount} while you were away.`
end
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
Strings.PROMPT_DOCK_RAW = "Logs go to the sawmill first"
Strings.PROMPT_DOCK_SCRAP = "Scrap gets smelted at the Forge first" -- [D55, D56]
Strings.PROMPT_DOCK_BOTH = "Logs to the sawmill, scrap to the Forge first" -- [D55, D56]
Strings.SACK_FULL_LOGS = "Sack full — take the logs to the sawmill"
Strings.SACK_FULL_PLANKS = "Sack full — take the planks to the tavern"
Strings.SACK_FULL_SCRAP = "Sack full — take the scrap to the Forge" -- [D55, D56]
Strings.SACK_FULL_IRON = "Sack full — take the iron to the tavern" -- [D56]
Strings.SACK_FULL_BOTH = "Sack full — take the planks and iron to the tavern" -- [D56]
Strings.SACK_FULL_FINDS = "Sack full — take the finds to the tavern" -- [D56] doar gasiri: se vand si asa
-- Ghidajul [GuideMath]: ce scrie sageata deasupra tintei.
Strings.GUIDE_FIRST_PAD = "Step on the glowing pad"
function Strings.guideBuy(name: string): string
    return `Step on it to buy {name}`
end
-- Fara "(E)": pe telefon nu exista tasta. Tasta o arata cardul obiectului, cand esti langa el.
Strings.GUIDE_COLLECT = "Collect from your net"
-- [D51] PASII buclei de mana (GuideMath.loopStep): al doilea rand al liniei NEXT si eticheta sagetii.
Strings.STEP_TAKE_PLANKS = "Take the planks at the sawmill"
Strings.STEP_TAKE_FROM_STORAGE = "Take the logs from the storage"
function Strings.stepStayCut(left: number): string
    return `Stay in the ring: {left} left to cut`
end
function Strings.stepWaitNet(count: number, need: number): string
    return `Wait for your net: {count}/{need}`
end
Strings.STEP_NETS_CATCHING = "Your nets are catching"
Strings.STEP_COINS_COMING = "Coins are coming in from the tavern"
-- [D59] Indiciul pontonului pe linia NEXT: doar dupa primul peste, doar cat strangi bani pentru quest si n-ai nimic de facut
-- cu mana. Fara sageata: pescuitul e o alegere, nu un pas.
Strings.HINT_FISH_WHILE_SAVING = "While you save: fish at the pier"
function Strings.hintTreasureWaiting(phrase: string): string
    return `{string.upper(string.sub(phrase, 1, 1))}{string.sub(phrase, 2)} is waiting at your pier`
end
Strings.STEP_BUY = "Walk up to it and buy it"
Strings.STEP_UPGRADE = "Walk up to it and press Upgrade"
Strings.GUIDE_LOGS_TO_SAWMILL = "Take the logs to the sawmill"
-- acelasi text ca quest-ul `sell_once`: pe linia NEXT, al doilea rand se ascunde cand repeta primul
Strings.GUIDE_SELL_PLANKS = "Sell the planks at the tavern"
-- [D56] turul de mana al fierului; "Sell the iron at the tavern" = textul quest-ului `sell_iron`
Strings.GUIDE_SCRAP_TO_FORGE = "Take the scrap to the Forge"
Strings.GUIDE_SELL_IRON = "Sell the iron at the tavern"
Strings.GUIDE_SELL_BOTH = "Sell the planks and iron at the tavern"
Strings.STEP_TAKE_IRON = "Take the iron at the Forge"
Strings.STEP_TAKE_FROM_SHED = "Take the scrap from the Scrap Shed"
Strings.GUIDE_COLLECT_SCRAP = "Collect the scrap from the Fifth Net"
-- [D56] doar gasiri in traista: se vand si neprelucrate
function Strings.guideSellFinds(count: number): string
    return if count == 1 then "Sell the find at the tavern" else "Sell the finds at the tavern"
end
function Strings.stepStaySmelt(left: number): string
    return `Stay in the ring: {left} left to smelt`
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
    if not ok then
        if reason == "sack_full" then
            return "Sack full"
        elseif reason == "storage_empty" then
            return "The storage is empty"
        elseif reason == "nothing_cut" then
            return if staffed then "Nothing cut yet" else "Nothing cut yet — stay by the saw"
        elseif reason == "raw_only" then
            return "The tavern only buys planks and iron — logs to the sawmill, scrap to the Forge"
        -- [D55, D56] scrap-ul are drumul lui: locul care il refuza spune unde merge. Forja, nu shed-ul: shed-ul
        -- e doar magazia Scrap Collector-ului, iar in turul de mana scrap-ul merge direct la forja.
        elseif reason == "scrap_to_forge" then
            return if place == "sawmill"
                then "Scrap gets smelted at the Forge, not cut"
                else "Scrap goes to the Forge"
        elseif reason == "shed_empty" then
            return "The Scrap Shed is empty"
        elseif reason == "nothing_smelted" then
            return if staffed then "No iron yet" else "No iron yet — stay by the forge"
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
Strings.WHEEL_READY_TOAST = "A free spin is waiting at the pier"
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
Strings.BOARD_BLURB = "Pearls buy looks for your village and for you."
function Strings.shopResult(what: string, name: string, ok: boolean, reason: string): string
    if ok then
        if what == "decor" then
            return `Built: {name}`
        elseif what == "outfit" then
            return `New outfit: {name}`
        end
        return `Wearing {name}`
    end
    if reason == "pearls" then
        return "Not enough pearls"
    elseif reason == "already" then
        return "You already have it"
    elseif reason == "journal" then
        return "Complete the Journal to earn it"
    elseif reason == "not_owned" then
        return "Buy it first"
    end
    return "Can't do that right now"
end

-- [Offline] Fereastra de revenire. Un singur lucru spus, nu o lista.
Strings.WELCOME_TITLE = "Welcome back"
Strings.WELCOME_CONTINUE = "Back to the river"
Strings.WELCOME_CAPPED = "Your river keeps working for a day while you're away."
-- [D59] ce a venit pe rau cat ai lipsit (cel mult trei asteapta la ponton)
Strings.WELCOME_RIVER_TITLE = "The river brought you something"
function Strings.welcomeArrived(n: number): string
    return if n == 1 then "Something drifted to your pier" else `{n} things drifted to your pier`
end
function Strings.welcomeAway(duration: string): string
    return `You were away for {duration}`
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
    end
    return "Can't claim that"
end

-- [Statii] Panoul de nivel. Textele sunt scurte pentru ca stau pe un rand ingust, langa cifre.
-- Panoul se numeste dupa CE FACI acolo, nu dupa locul unde esti: "Riverbank" nu spunea nimic
-- cuiva care tocmai l-a deschis. Sub cele trei debite sta o propozitie care explica de ce conteaza,
-- si una care spune ce sa faci ACUM -- fara ele, panoul e trei cifre si patru butoane.
Strings.STATIONS_TITLE = "Upgrades"
Strings.STATIONS_EXPLAIN = "Your river only moves as fast as its slowest link."
Strings.STATION_BULK = "Buy levels"
function Strings.stationsAdvice(bottleneck: string): string
    if bottleneck == "nets" then
        return "Right now that is the nets — upgrade one to earn more."
    elseif bottleneck == "collect" then
        return "Right now that is collecting — hire or upgrade Collectors."
    elseif bottleneck == "port" then
        return "Right now that is carrying to the sawmill — hire or upgrade Porters."
    elseif bottleneck == "haul" then
        return "Right now that is hauling to the tavern — hire or upgrade Haulers."
    elseif bottleneck == "saw" then
        return "Right now that is the sawmill — upgrade it to earn more."
    elseif bottleneck == "scrapCollect" then
        return "Right now that is collecting scrap — hire or upgrade Scrap Collectors."
    elseif bottleneck == "scrapPort" then
        return "Right now that is carrying scrap to the Forge — hire or upgrade Scrap Porters."
    elseif bottleneck == "forge" then
        return "Right now that is the Forge — upgrade it or its Smelters to earn more."
    elseif bottleneck == "ironHaul" then
        return "Right now that is hauling iron to the tavern — hire or upgrade Iron Haulers."
    end
    return "Right now that is the tavern — upgrade it to earn more."
end
Strings.STATION_UPGRADE = "Upgrade"
-- ---- meniul unei meserii [D49] -----------------------------------------------------------------
function Strings.crewWorking(count: number, name: string, plural: string): string
    return if count == 1 then `Your {name} is on the job` else `{count} {plural} on the job`
end
-- Pe pasii de drum si la gater, fara om, pasul e al tau; la taverna, vinde singura, incet.
function Strings.crewNone(role: string, name: string): string
    if role == "trader" then
        return `No {name} — the tavern sells at 35%`
    end
    return `No {name} — you do this yourself`
end
-- ECHIPAJ LA MAXIM PE VERIGA SLABA: nu mai e nimic de cumparat aici in Era 1. "No gain yet" ar fi
-- sugerat ca ceva de pe meniul asta ar ajuta [D40, D49].
function Strings.crewMaxed(plural: string): string
    return `{plural} are maxed on this stretch — ring the Landing Bell`
end
Strings.MENU_TIER_UP = "Upgrade tier"
-- De ce nu se poate apasa un buton de meserie. Acelasi cuvant pe care il intoarce serverul.
function Strings.crewBlock(reason: string?, secondAt: number): string
    if reason == "max_tier" then
        return "Top tier"
    elseif reason == "max_people" then
        return "Crew full"
    elseif reason == "tier" then
        return `Needs tier {secondAt}`
    elseif reason == "no_person" then
        return "Hire one at its pad"
    end
    return "Not available"
end
function Strings.menuUpgradeCount(count: number): string
    return if count == 1 then "Upgrade" else `Upgrade x{count}`
end
Strings.STATION_BOTTLENECK = "← slowest link"
Strings.STATION_CANT_AFFORD = "not enough"
Strings.STATION_NEED_MORE = "Not enough coins for a single level"
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
    elseif bottleneck == "collect" then
        return "No gain yet — collecting is slowest"
    elseif bottleneck == "port" then
        return "No gain yet — carrying to the sawmill is slowest"
    elseif bottleneck == "haul" then
        return "No gain yet — hauling to the tavern is slowest"
    elseif bottleneck == "saw" then
        return "No gain yet — the sawmill is slowest"
    elseif bottleneck == "scrapCollect" then
        return "No gain yet — collecting scrap is slowest"
    elseif bottleneck == "scrapPort" then
        return "No gain yet — carrying scrap is slowest"
    elseif bottleneck == "forge" then
        return "No gain yet — the Forge is slowest"
    elseif bottleneck == "ironHaul" then
        return "No gain yet — hauling iron is slowest"
    end
    return "No gain yet — the tavern is slowest"
end
-- [D56] Forja cumparata, dar inca fara plasa de scrap: linia fierului n-are ce duce.
Strings.STATION_NO_SCRAP = "No gain yet — no scrap until the Fifth Net"
Strings.MENU_NO_SCRAP = "Won't earn more yet: no scrap comes in until the Fifth Net"
-- ---- ruinele [D53] ----------------------------------------------------------------------------
-- Eticheta cartonasului langa o platforma incuiata: ruina, sau avizierul unde se angajeaza un om.
Strings.PAD_EYEBROW_RUINS = "RUINS"
Strings.PAD_EYEBROW_WANTED = "HELP WANTED"
-- Ce trebuie facut intai. Primeste TycoonMath.Blocker, cu numele deja rezolvate: textul spune exact
-- conditia pe care o verifica jocul [D40].
function Strings.padNeeds(b: {
    kind: string,
    name: string?,
    level: number?,
    hire: boolean?,
    first: boolean?,
}): string
    local name = b.name or "it"
    if b.kind == "after" then
        if b.hire then
            local article = if string.find(name, "^[AEIOUaeiou]") then "an" else "a"
            return `Hire {article} {name} first`
        end
        return `Build the {name} first`
    elseif b.kind == "net" then
        return if b.first then "Cast your first net" else `Cast the {name} first`
    elseif b.kind == "level" then
        return `Upgrade {name} to level {b.level or 2} first`
    end
    return "Rebuild everything else on The Landing first"
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
    return `Tier {tier} of {maxTier} · {count} of {maxPeople} people`
end
-- Ce face cladirea, deasupra cifrei mari. Gaterul fara Sawyer si taverna fara Innkeeper spun si DE CE
-- merg cum merg [D43]; 35% = StationConfig.NO_TRADER_FACTOR.
function Strings.menuDoes(kind: string, staffed: boolean): string
    if kind == "net" then
        return "Catches"
    elseif kind == "saw" then
        return if staffed then "Cuts" else "Cuts only while you stand here"
    elseif kind == "forge" then
        -- [D56] ca gaterul: fara Smelter doar cat stai langa ea
        return if staffed then "Smelts scrap into iron" else "Smelts only while you stand here"
    end
    return if staffed then "Sells" else "Sells at 35% until you hire an Innkeeper"
end
-- Ce face omul: aceleasi cuvinte ca pe platforma lui. [D56] Fiecare linie cu oamenii ei.
function Strings.crewDoes(role: string): string
    if role == "collector" then
        return "Empties your nets into the storage"
    elseif role == "porter" then
        return "Carries logs from the storage to the sawmill"
    elseif role == "sawyer" then
        return "Keeps the saw running"
    elseif role == "hauler" then
        return "Carries planks from the sawmill to the tavern"
    elseif role == "scrapCollector" then
        return "Empties the Fifth Net into the Scrap Shed"
    elseif role == "scrapPorter" then
        return "Carries scrap from the Scrap Shed to the Forge"
    elseif role == "smelter" then
        return "Keeps the Forge smelting"
    elseif role == "ironHauler" then
        return "Carries iron from the Forge to the tavern"
    end
    return "Runs the tavern"
end
-- Unitatea de sub cifra mare. Bustenii pana la gater, scandurile de acolo incolo -- cuvintele pe care
-- jocul le foloseste deja ("Store logs", "Sell planks"). [D56] Pe linia fierului: scrap pana la forja, fier de acolo.
function Strings.menuUnit(what: string): string
    if what == "net" or what == "collector" or what == "porter" then
        return "logs a minute"
    elseif what == "scrapNet" or what == "scrapCollector" or what == "scrapPorter" then
        return "scrap a minute"
    elseif what == "forge" or what == "smelter" or what == "ironHauler" then
        return "iron a minute"
    end
    return "planks a minute"
end
function Strings.menuMilestone(kind: string, level: number, mult: number): string
    local how = if mult == 2 then "twice" else `{mult}x`
    if kind == "net" then
        return `Level {level}: catches {how} as much`
    elseif kind == "saw" then
        return `Level {level}: cuts {how} as fast`
    elseif kind == "forge" then
        return `Level {level}: smelts {how} as fast`
    end
    return `Level {level}: sells {how} as fast`
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
    return earns("Next tier", amount)
end
function Strings.menuEarnsSecond(name: string, amount: string?): string
    return earns(`A second {name}`, amount)
end
-- Cand cumparatura de aici nu aduce nimic: CINE tine venitul in loc. `tie` = veriga aia e doar la fel
-- de lenta (egalitate): "slower" ar fi mintit tocmai atunci [D40]. [D56] `line` = pe linia fierului plasa e una.
function Strings.menuHeldBack(link: string, tie: boolean, line: string?): string
    local subject, verb = "the tavern", "is"
    if link == "nets" and line == "iron" then
        subject = "the scrap net"
    elseif link == "nets" then
        subject, verb = "your nets", "are"
    elseif link == "collect" then
        subject = "collecting"
    elseif link == "port" then
        subject = "carrying to the sawmill"
    elseif link == "saw" then
        subject = "the sawmill"
    elseif link == "haul" then
        subject = "hauling to the tavern"
    elseif link == "scrapCollect" then
        subject = "collecting scrap"
    elseif link == "scrapPort" then
        subject = "carrying scrap to the Forge"
    elseif link == "forge" then
        subject = "the Forge"
    elseif link == "ironHaul" then
        subject = "hauling iron to the tavern"
    end
    return `Won't earn more yet: {subject} {verb} ` .. (if tie then "just as slow" else "slower")
end
function Strings.menuGoTo(link: string): string
    local names: { [string]: string } = {
        nets = "Nets",
        collect = "Collector",
        port = "Porter",
        saw = "Sawmill",
        haul = "Hauler",
        scrapCollect = "Scrap Collector",
        scrapPort = "Scrap Porter",
        forge = "Forge",
        ironHaul = "Iron Hauler",
        dock = "Tavern",
    }
    return `Go to {names[link] or "Nets"}`
end
-- Butoanele meseriei. Blocat: motivul sta chiar pe buton, fara pret. Fara om, butonul ramane cu
-- eticheta lui, stins: randul de deasupra spune deja "Hire one at its pad".
function Strings.menuCrewButton(what: string, block: string?, secondAt: number): string
    if block == "max_tier" then
        return "Top tier"
    elseif block == "max_people" then
        return "Crew full"
    elseif block == "tier" then
        return `Hire a second at tier {secondAt}`
    end
    return if what == "tier" then Strings.MENU_TIER_UP else "Hire a second"
end
function Strings.upgradeRejected(reason: string): string
    if reason == "coins" then
        return "Not enough coins"
    elseif reason == "locked" then
        return "Build it first"
    elseif reason == "max_tier" then
        return "Already at the top tier"
    elseif reason == "max_people" then
        return "That crew is full"
    elseif reason == "tier" then
        return "Upgrade the tier first"
    elseif reason == "no_person" then
        return "Hire the first one at its pad"
    end
    return "Can't upgrade that"
end

-- linia "NEXT" din HUD, cand banii au ajuns: nu mai lipseste nimic, doar du-te si calca
Strings.OBJ_READY = "ready!"
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
Strings.PAD_TAKE_FREE = "Take it — free"
function Strings.padBuyFor(price: string): string
    return `Buy for {price}`
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
