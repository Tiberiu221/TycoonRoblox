--!strict
-- Consola de dezvoltare: un singur remote, o comanda pe apel, DOAR in Studio [F0 spec 3.6].
-- Poarta e verificata pe SERVER, nu pe client: in productie handler-ul nici nu se conecteaza,
-- deci un pachet trimis de mana nu are ce sa faca. Fiecare comanda intoarce o linie de raspuns,
-- afisata in jurnalul panoului.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")
local TycoonConfig = require(ReplicatedStorage.Shared.Config.TycoonConfig)
local TycoonMath = require(ReplicatedStorage.Shared.Modules.TycoonMath)
local StationConfig = require(ReplicatedStorage.Shared.Config.StationConfig)
local StreakMath = require(ReplicatedStorage.Shared.Modules.StreakMath) -- [D71]
local QuestConfig = require(ReplicatedStorage.Shared.Config.QuestConfig)
local VillageConfig = require(ReplicatedStorage.Shared.Config.VillageConfig)
local QuestMath = require(ReplicatedStorage.Shared.Modules.QuestMath)
local CrewMath = require(ReplicatedStorage.Shared.Modules.CrewMath)

local DataService = require(script.Parent.DataService)
local DevState = require(script.Parent.DevState)
local EconomyService = require(script.Parent.EconomyService)
local HandService = require(script.Parent.HandService)
local NetService = require(script.Parent.NetService)
local PadService = require(script.Parent.PadService)
local StationService = require(script.Parent.StationService)
local FishService = require(script.Parent.FishService)
local TreasureService = require(script.Parent.TreasureService)
local VillageService = require(script.Parent.VillageService)
local WheelService = require(script.Parent.WheelService)
local PassService = require(script.Parent.PassService)
local PurchaseService = require(script.Parent.PurchaseService)

local DevService = {}
local deps: { Remotes: { [string]: RemoteEvent }, PushState: ((Player) -> ())? }

local function number(value: unknown, fallback: number): number
    if typeof(value) == "number" and math.isfinite(value :: number) then
        return value :: number
    end
    return fallback
end

type Handler = (player: Player, arg: unknown) -> string

local HANDLERS: { [string]: Handler } = {
    coins = function(player: Player, arg: unknown): string
        local delta = number(arg, 50)
        EconomyService.AddCoins(player, delta, "dev")
        return `coins {if delta >= 0 then "+" else ""}{delta} → {EconomyService.GetCoins(player)}`
    end,

    setcoins = function(player: Player, arg: unknown): string
        local n = math.max(0, number(arg, 0))
        local data = DataService.Get(player)
        if data == nil then
            return "no profile"
        end
        data.Coins = n
        EconomyService.TrimBought(data) -- [D70, pasul j5]
        return `coins set to {n}`
    end,

    -- [2026-09-15] Play-ul din Studio porneste de la zero; "keep save" pastreaza salvarea reala pentru Play-urile urmatoare
    keepsave = function(player: Player, _arg: unknown): string
        local ok, keep = DataService.ToggleKeepSave(player)
        if not ok then
            return "could not store the switch (is Studio API access on?)"
        end
        local now = if DataService.StudioSave(player) == "kept"
            then "this Play is on your saved game"
            else "this Play started fresh"
        return if keep
            then `keep save ON: next Play continues your saved game ({now})`
            else `keep save OFF: next Play starts fresh ({now})`
    end,

    reset = function(player: Player, _arg: unknown): string
        local ok = DataService.Reset(player)
        if not ok then
            return "no profile"
        end
        PadService.Invalidate(player)
        StationService.Invalidate(player) -- si lantul: altfel venitul ramane cel dinainte de reset
        return "profile reset to a fresh save (Index kept)"
    end,

    fill = function(player: Player, _arg: unknown): string
        local n = NetService.DevFill(player)
        return `{n} items added across your nets`
    end,

    sack = function(player: Player, _arg: unknown): string
        local n = EconomyService.DevFillSack(player)
        return `{n} driftwood added to the sack`
    end,

    skip = function(player: Player, arg: unknown): string
        local seconds = number(arg, 60)
        local n = NetService.DevSkip(player, seconds)
        return `{n} nets moved {seconds}s ahead`
    end,

    buyto = function(player: Player, arg: unknown): string
        local k = math.clamp(math.floor(number(arg, 2)), 1, #TycoonConfig.PADS + 1)
        local granted, notInGame = 0, 0
        for _, pad in TycoonConfig.PADS do
            if pad.index >= k then
                break
            end
            -- [D58] erele fara loc pe harta nu se dau (PadService.DevGrant le refuza); raspunsul spune cate au ramas
            if not pad.live then
                notInGame += 1
            elseif PadService.DevGrant(player, pad.id) then
                granted += 1
            end
        end
        local skipped = if notInGame > 0 then `; {notInGame} not in the game yet (Era 2+)` else ""
        return `granted {granted} pads (up to index {k - 1}){skipped}`
    end,

    -- UNEALTA F1: acorda platformele pana la Collector INCLUSIV (id-ul vechi `first_runner` [D49]), ca
    -- sa se poata testa omul fara sa cumperi platformele dinainte de mana.
    runner = function(player: Player, _arg: unknown): string
        local target = TycoonConfig.byId["first_runner"]
        if target == nil then
            return "first_runner missing from TycoonConfig"
        end
        local granted = 0
        for _, pad in TycoonConfig.PADS do
            if pad.index > target.index then
                break
            end
            if PadService.DevGrant(player, pad.id) then
                granted += 1
            end
        end
        return `granted {granted} pads (up to and including the Collector)`
    end,

    -- UNEALTA F1: urmatoarea prindere a FIECAREI plase detinute devine o gasire cu nume, ca sa se
    -- poata testa Atelierul/vanzarea de obiecte cu nume fara sa astepti sansa reala (~5%).
    named = function(player: Player, _arg: unknown): string
        local n = NetService.DevForceNamed(player)
        return `next catch of {n} net(s) forced to a named find`
    end,

    -- UNEALTA F1: acorda toata Era 1 (inclusiv Landing Bell), ca sa se poata testa ceremonia de
    -- clopot si zona Mill fara sa cumperi restul platformelor de mana.
    bell = function(player: Player, _arg: unknown): string
        local granted = 0
        for _, pad in TycoonConfig.PADS do
            if pad.era ~= 1 then
                continue
            end
            if PadService.DevGrant(player, pad.id) then
                granted += 1
            end
        end
        return `granted {granted} pad(s): all of Era 1`
    end,

    -- UNEALTA F1: starea angajatilor, ca sa poti verifica ciclul alergatorului fara sa astepti
    -- sa-l vezi in Studio.
    hands = function(player: Player, _arg: unknown): string
        local data = DataService.Get(player)
        if data == nil then
            return "no profile"
        end
        local lines = {}
        for id, hand in data.Hands do
            local started = string.format("%.1f", hand.cycleStartAt)
            local lastEvent = string.format("%.1f", hand.lastEventAt)
            table.insert(
                lines,
                `{id} "{hand.name}": carrying {#hand.carry}, cycleStartAt {started}, lastEventAt {lastEvent}`
            )
        end
        if #lines == 0 then
            return "no hands yet"
        end
        return table.concat(lines, " | ")
    end,

    -- UNEALTA D49: face gestul de la debarcader fara sa mergi pana acolo -- lasa ce e taiat din traista.
    sell = function(player: Player, _arg: unknown): string
        local ok, reason, count = EconomyService.DeliverDock(player)
        if not ok then
            return `nothing delivered ({reason})`
        end
        return `delivered {count} cut item(s) to the dock`
    end,

    -- UNEALTA D48/D49: pune busteni in gramada gaterului (`saw 40`), ca gatuirea lui sa se vada in
    -- Studio fara zece drumuri, si spune cat taie acum. Fara Sawyer si fara tine langa el, 0/s.
    saw = function(player: Player, arg: unknown): string
        local n = tonumber(arg) or 20
        local added = EconomyService.DevFillPile(player, "sawmill", n)
        local sm = EconomyService.SawmillSnapshot(player)
        local rate = TycoonMath.formatRate(sm.rate)
        local secs = if sm.rate > 0 then string.format("%.1f", sm.count / sm.rate) else "inf"
        return `+{added} logs · to cut {sm.count} · cut {sm.out} · {rate}/s · done in {secs}s`
    end,

    -- UNEALTA D49: umple o gramada (`pile storage 200`, `pile planks 50`, `pile dock 30`), ca fiecare
    -- om sa aiba de lucru in Studio fara sa astepti lantul intreg.
    pile = function(player: Player, arg: unknown): string
        local text = if typeof(arg) == "string" then arg :: string else ""
        local place, amount = string.match(text, "^(%a+)%s*(%d*)$")
        local n = tonumber(amount) or 50
        local added = EconomyService.DevFillPile(player, place or "", n)
        if added == 0 then
            return "usage: pile storage|sawmill|planks|dock|shed|forge|iron|millStore|foundry|parts|oreShed|furnace|copper|market [n]"
        end
        return `+{added} in {place}`
    end,

    -- UNEALTA D49: pune o meserie la o treapta si un numar de oameni (`crew porter 3 2`), ca meniul
    -- meseriei si al doilea om sa se poata vedea fara sa strangi banii.
    crew = function(player: Player, arg: unknown): string
        local data = DataService.Get(player)
        local text = if typeof(arg) == "string" then arg :: string else ""
        local role, tierText, peopleText = string.match(text, "^(%a+)%s*(%d*)%s*(%d*)$")
        local def = if role ~= nil then TycoonConfig.CREWS[role] else nil
        -- [D70] doar meseriile din joc (StationConfig.ROLES): ale barajului adormit au rand in CREWS, dar nu in lant
        if data == nil or def == nil or table.find(StationConfig.ROLES, role :: string) == nil then
            return "usage: crew <role> [tier] [people]   (roles: StationConfig.ROLES, e.g. porter, smelter, founder, merchant)"
        end
        local tier = math.clamp(tonumber(tierText) or 1, 1, StationConfig.TIER_MAX)
        local want = math.clamp(tonumber(peopleText) or 1, 1, StationConfig.MAX_PEOPLE)
        data.Crews[role :: string] = { tier = tier }
        if data.Pads[def.pad] ~= true then
            PadService.DevGrant(player, def.pad) -- aduce si primul om
        end
        local people = CrewMath.fromProfile(data.Hands, data.Crews)[role :: string].count
        while people < want and HandService.Hire(player, role :: string) do
            people += 1
        end
        StationService.Invalidate(player)
        if deps.PushState ~= nil then
            deps.PushState(player)
        end
        return `{role}: tier {tier}, {people} people`
    end,

    -- UNEALTA E1.2: starea gramezii de la debarcader -- cate bucati asteapta si cat de repede
    -- se scurg. Asa se vede daca vanzarea a devenit veriga slaba.
    dock = function(player: Player, _arg: unknown): string
        local d = EconomyService.DockSnapshot(player)
        local rate = TycoonMath.formatRate(d.rate)
        local secs = if d.rate > 0 then string.format("%.1f", d.count / d.rate) else "inf"
        return `pile {d.count} · worth {TycoonMath.formatNumber(d.value)} · {rate}/s · empties in {secs}s`
    end,

    state = function(player: Player, _arg: unknown): string
        local data = DataService.Get(player)
        if data == nil then
            return "no profile"
        end
        local sack = EconomyService.SackSnapshot(player)
        local padsOwned = 0
        for _ in data.Pads do
            padsOwned += 1
        end
        local income = TycoonMath.formatRate(EconomyService.IncomePerSec(player))
        local dock = EconomyService.DockSnapshot(player)
        local sawmill = EconomyService.SawmillSnapshot(player)
        local storage = EconomyService.StorageSnapshot(player)
        return `coins {TycoonMath.formatNumber(data.Coins)} · income {income}/s · {padsOwned} pads · sack {sack.count}/{sack.capacity} ({sack.cut} cut) · storage {storage.count} · sawmill {sawmill.count} in / {sawmill.out} out · dock pile {dock.count}`
    end,

    -- [D59] pontonul: perle, pestele urmator, un lucru adus acum, roata gata, satul de la zero
    pearls = function(player: Player, arg: unknown): string
        local n = number(arg, 100)
        EconomyService.AddPearls(player, n, "dev")
        return `pearls +{n} → {math.floor(EconomyService.GetPearls(player))}`
    end,

    fish = function(player: Player, arg: unknown): string
        local id = if typeof(arg) == "string" then arg :: string else "goldcarp"
        return if FishService.DevForce(player, id) then `next fish: {id}` else `unknown fish: {id}`
    end,

    treasure = function(player: Player, arg: unknown): string
        local kind = if typeof(arg) == "string" then arg :: string else "chest"
        return if TreasureService.DevArrive(player, kind)
            then `{kind} is drifting to the pier`
            else `no room at the pier (or unknown kind: {kind})`
    end,

    wheel = function(player: Player, _arg: unknown): string
        return if WheelService.DevReady(player)
            then "wheel ready (spin it at the fair)"
            else "no profile"
    end,

    -- [D61, partea 2] un pass de proba, fara Robux (comutator): pass flow2x | swift | nights | supporter
    pass = function(player: Player, arg: unknown): string
        local key = if typeof(arg) == "string" then arg else ""
        local ok, now = PassService.DevToggle(player, key)
        if not ok then
            return "usage: pass flow2x | swift | nights | supporter"
        end
        return `pass {key}: {if now then "ON" else "off"}`
    end,

    -- [D61, partea 2] un produs de proba, fara chitanta: buy hour | welcome2x
    buy = function(player: Player, arg: unknown): string
        local key = if typeof(arg) == "string" then arg else ""
        local coins = PurchaseService.DevGrant(player, key)
        if coins == nil then
            return "usage: buy hour | welcome2x"
        end
        return `{key}: +{coins} coins`
    end,

    -- [D71] absenta de proba: `away 12` muta ultima vedere cu 12 ore in urma si face socoteala din nou (curba de 8/16/24
    -- de ore si fereastra de revenire). Mock-ul din Studio n-are `lastSeenAt`, deci fara asta curba nu se vede.
    away = function(player: Player, arg: unknown): string
        local data = DataService.Get(player)
        local hours = number(arg, 10)
        if data == nil or hours <= 0 then
            return "usage: away <hours>   (e.g. away 3, away 12, away 30)"
        end
        data.Meta.lastSeenAt = os.time() - math.floor(hours * 3600)
        StationService.SettleOffline(player)
        return `settled {hours} h away (see the Welcome back window)`
    end,

    -- [D71] seria zilnica de proba: `streak 6` = ieri a fost ziua 6, deci intrarea de azi ar fi a 7-a (titlul Regular).
    -- Se vede la urmatoarea zi numarata; in balci, la urmatorul drum cu barca.
    streak = function(player: Player, arg: unknown): string
        local data = DataService.Get(player) :: any
        local run = math.max(0, math.floor(number(arg, 6)))
        if data == nil then
            return "no profile"
        end
        local streak = StreakMath.clean(data.Streak)
        local best = math.max(run, streak.best)
        data.Streak = {
            day = StreakMath.dayOf(os.time(), streak.offset) - 1,
            run = run,
            best = best,
            total = math.max(run, best),
            offset = streak.offset,
            offsetDay = streak.offsetDay,
        }
        DataService.TouchStreak(player)
        if deps.PushState ~= nil then
            deps.PushState(player)
        end
        return `streak: yesterday was day {run}; today counted (now {data.Streak.run}, best {data.Streak.best})`
    end,

    village = function(player: Player, _arg: unknown): string
        return if VillageService.DevReset(player)
            then "village decor and outfits reset"
            else "no profile"
    end,

    -- [D65] Cumpara niveluri PE DRUMUL ADEVARAT (StationService.Upgrade, cu monedele tale): `up foundry 3`,
    -- `up net:sixth_net 2`. Sonda nu poate trimite un `nil` la mijlocul unei cereri, iar cladirile n-au id.
    up = function(player: Player, arg: unknown): string
        local text = if typeof(arg) == "string" then arg :: string else ""
        local target, countText = string.match(text, "^([%a_:]+)%s*(%d*)$")
        if target == nil then
            return "usage: up saw|dock|forge|foundry|furnace|market|net:<padId> [count]"
        end
        local kind, id = string.match(target, "^(%a+):(.+)$")
        local count = tonumber(countText) or 1
        local ok, reason, done = StationService.Upgrade(player, kind or target, id, count)
        if not ok then
            return `refused: {reason}`
        end
        local pushState = deps.PushState
        if pushState ~= nil then
            pushState(player)
        end
        return `{target}: level {if done ~= nil then done.level else "?"}`
    end,

    -- [D65] UNEALTA ERELOR: aduce profilul la INCEPUTUL capitolului N (chapter 4 = Era 2, cu clopotul Erei 1 tras):
    -- fiecare quest de dinainte e facut (platforma data, nivelul urcat, numaratoarea la tinta) si revendicat, fara
    -- recompense. Altfel Era 2 s-ar putea verifica doar dupa o ora de joc. Quest-urile se citesc din stare, deci aici
    -- se scrie STAREA, nu un steag "sarit".
    chapter = function(player: Player, arg: unknown): string
        local data = DataService.Get(player)
        if data == nil then
            return "no profile"
        end
        local upTo = math.clamp(math.floor(number(arg, 4)), 1, #QuestConfig.CHAPTERS + 1)
        local stats: any = data.Stats
        local done = 0
        for index, chapter in QuestConfig.CHAPTERS do
            if index >= upTo then
                break
            end
            for _, quest in chapter.quests do
                if quest.kind == "pad" then
                    PadService.DevGrant(player, quest.arg or "")
                elseif quest.kind == "level" then
                    local station, padId = QuestMath.stationTarget(quest)
                    local stations: any = data.Stations
                    if station == "net" and padId ~= nil then
                        local entry = stations.nets[padId] or { level = 1 }
                        entry.level = math.max(entry.level, quest.goal)
                        stations.nets[padId] = entry
                    elseif station ~= nil and typeof(stations[station]) == "table" then
                        stations[station].level = math.max(stations[station].level or 1, quest.goal)
                    end
                elseif quest.kind == "decor" then
                    -- primele `goal` lucruri din catalogul avizierului
                    local village: any = data.Village
                    village.decor = village.decor or {}
                    for i = 1, math.min(quest.goal, #VillageConfig.DECOR) do
                        village.decor[VillageConfig.DECOR[i].id] = true
                    end
                elseif quest.kind ~= "idle" and quest.kind ~= "income" then -- [D70] venitul nu se scrie
                    -- o numaratoare din Stats, pe numele felului ("collected", "sold", "sawn", "fished", "cast"...)
                    stats[quest.kind] = math.max(stats[quest.kind] or 0, quest.goal)
                end
                data.Quests.claimed[quest.id] = true
                done += 1
            end
        end
        PadService.Invalidate(player)
        StationService.Invalidate(player)
        local pushState = deps.PushState
        if pushState ~= nil then
            pushState(player)
        end
        return `{done} quests done and claimed: now at chapter {upTo}`
    end,
}

function DevService.Run(player: Player, command: string, arg: unknown): string
    local handler = HANDLERS[command]
    if handler == nil then
        return `unknown command: {command}`
    end
    local ok, result = pcall(handler, player, arg)
    if deps.PushState ~= nil then
        deps.PushState(player)
    end
    if not ok then
        return `error: {result}`
    end
    return result :: string
end

function DevService.Init(d: typeof(deps))
    deps = d
    if not DevState.Enabled() then
        print("[Driftwood] consola de dezvoltare e inactiva in afara Studio")
        return
    end
    local remote = deps.Remotes.DevCommand
    if remote == nil then
        return
    end
    -- [D63] Canalul sondei din Studio: aceleasi comenzi ca in consola, cerute de plugin printr-un BindableFunction, fara
    -- HTTP din joc (podul vechi, DevBridge, depinde de "Allow HTTP requests" si n-a raspuns in sesiunea owner-ului).
    -- REFUZA orice comanda daca Play-ul nu e unul de proba: un test automat n-are voie pe salvarea adevarata.
    local probe = Instance.new("BindableFunction")
    probe.Name = "DevProbe"
    probe.OnInvoke = function(command: unknown, arg: unknown): string
        local player = Players:GetPlayers()[1]
        if player == nil then
            return "no player"
        elseif typeof(command) ~= "string" then
            return "bad command"
        elseif command ~= "state" and DataService.StudioSave(player) ~= "probe" then
            return "refused: not a probe run (this Play is on a real or manual save)"
        end
        return DevService.Run(player, command :: string, arg)
    end
    probe.Parent = ServerStorage
    remote.OnServerEvent:Connect(function(player: Player, command: unknown, arg: unknown)
        if typeof(command) ~= "string" or #(command :: string) > 32 then
            return
        end
        local reply = DevService.Run(player, command :: string, arg)
        remote:FireClient(player, command, reply)
    end)
    -- Ce fel de salvare are Play-ul asta, spus o data in jurnalul consolei si in Output: altfel progresul care dispare la
    -- Stop (sau care ramane) ar parea o eroare [D43].
    DataService.ProfileLoaded:Connect(function(player: Player)
        local mode = DataService.StudioSave(player)
        if mode == nil then
            return
        end
        local line = if mode == "kept"
            then "save: your saved game (keep save ON)"
            elseif
                mode == "probe"
            then "save: probe run, fresh profile (your saved game is untouched)"
            else "save: fresh, erased at Stop (keep save OFF)"
        print(`[Driftwood] {line}`)
        remote:FireClient(player, "savemode", line)
    end)
    print("[Driftwood] consola de dezvoltare activa in Studio")
end

return DevService
