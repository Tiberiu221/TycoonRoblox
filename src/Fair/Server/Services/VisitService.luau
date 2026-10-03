--!strict
-- [D61, partea 2] POARTA SATELOR. Din balci vizitezi satul altui om de acolo, ca FOTOGRAFIE: profilul gazdei e incarcat
-- pe serverul asta (e si ea in balci), iar VillageLook scoate din el doar ce se vede. Nimic din economia nimanui nu
-- trece pe aici -- satul adevarat, cu plasele, gramezile si banii lui, ramane in place-ul lui.
--   List  -- cine e acum in balci: numele, titlul, Era, cate decoruri, cate like-uri, daca i-ai dat deja azi
--   Look  -- fotografia satului cuiva; de acum "esti in vizita" (ceilalti te vad stand langa arcada)
--   Like  -- un like pe zi pentru fiecare sat, doar cat esti in vizita acolo; gazda afla pe loc
--   Leave -- te-ai intors in balci
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local FairLayout = require(ReplicatedStorage.Shared.Modules.FairLayout)
local VillageLook = require(ReplicatedStorage.Shared.Modules.VillageLook)
local VisitMath = require(ReplicatedStorage.Shared.Modules.VisitMath)

local Analytics = require(script.Parent.Analytics)
local DataService = require(script.Parent.DataService)
local TitleService = require(script.Parent.TitleService)

local VisitService = {}

export type Host = {
    userId: number,
    name: string,
    title: string,
    era: number,
    decor: number,
    likes: number,
    liked: boolean, -- i-ai dat deja like azi
    building: boolean, -- [D70, pasul k11] gazda a ridicat barajul: se vede satul ei de dinainte, cu „Building the Dam”
}
export type Deps = {
    -- ceilalti te vad langa arcada cat esti in vizita (PresenceService)
    PlaceAt: (Player, number, number) -> (),
    -- gazda afla pe loc: cine i-a dat like si cate are acum
    OnLiked: (host: Player, visitorName: string, likes: number) -> (),
    Now: () -> number,
}

local deps: Deps? = nil
local visiting: { [Player]: number } = {} -- vizitatorul -> userId-ul gazdei

local function fairOf(data: any): any
    if typeof(data.Fair) ~= "table" then
        data.Fair = { firstVisit = 0, visits = 0 }
    end
    local fair = data.Fair
    if typeof(fair.likes) ~= "number" or fair.likes ~= fair.likes then
        fair.likes = 0
    end
    if typeof(fair.liked) ~= "table" then
        fair.liked = { day = 0, ids = {} }
    end
    return fair
end

local function today(): number
    local d = deps
    return VisitMath.dayOf(if d ~= nil then d.Now() else os.time())
end

local function hostEntry(viewer: Player, host: Player): Host?
    local data = DataService.Get(host)
    local viewerData = DataService.Get(viewer)
    if data == nil or viewerData == nil then
        return nil
    end
    local look, building = VillageLook.forVisitors(data)
    local _, title = TitleService.Worn(host)
    return {
        userId = host.UserId,
        name = host.DisplayName,
        title = title,
        era = look.era,
        decor = look.decorCount,
        likes = math.floor(fairOf(data).likes),
        liked = VisitMath.likedToday(fairOf(viewerData).liked, today(), host.UserId),
        building = building,
    }
end

-- Cine e acum in balci (fara tine), cu profilul incarcat. Ordinea: cele mai multe decoruri intai, ca la machete.
function VisitService.List(viewer: Player): { Host }
    local list: { Host } = {}
    for _, other in Players:GetPlayers() do
        if other ~= viewer then
            local entry = hostEntry(viewer, other)
            if entry ~= nil then
                table.insert(list, entry)
            end
        end
    end
    table.sort(list, function(a: Host, b: Host): boolean
        if a.decor ~= b.decor then
            return a.decor > b.decor
        elseif a.likes ~= b.likes then
            return a.likes > b.likes
        end
        return a.userId < b.userId
    end)
    return list
end

-- Fotografia satului. "self" | "gone" (a plecat din balci sau profilul nu e incarcat) | "no_profile".
function VisitService.Look(
    viewer: Player,
    userId: number
): (boolean, string, { host: Host, village: VillageLook.Snapshot }?)
    local d = deps
    if d == nil or DataService.Get(viewer) == nil then
        return false, "no_profile", nil
    end
    if userId == viewer.UserId then
        return false, "self", nil
    end
    local host = Players:GetPlayerByUserId(userId)
    local data = if host ~= nil then DataService.Get(host) else nil
    if host == nil or data == nil then
        return false, "gone", nil
    end
    local entry = hostEntry(viewer, host)
    if entry == nil then
        return false, "gone", nil
    end
    visiting[viewer] = userId
    -- coordonatele tale din vizita sunt ale altei harti: cat esti plecat, ceilalti te vad langa arcada
    d.PlaceAt(viewer, FairLayout.GATE_STAND.x, FairLayout.GATE_STAND.y)
    local viewerData = DataService.Get(viewer)
    if viewerData ~= nil and not viewerData.Firsts.FirstVillageVisit then
        viewerData.Firsts.FirstVillageVisit = true
        Analytics.FairStep(viewer, "FirstVillageVisit")
    end
    local village = VillageLook.forVisitors(data)
    return true, "ok", { host = entry, village = village }
end

function VisitService.Leave(viewer: Player)
    visiting[viewer] = nil
end

function VisitService.IsVisiting(viewer: Player): boolean
    return visiting[viewer] ~= nil
end

-- Un like pe zi pentru fiecare sat, doar cat esti in vizita acolo. Intoarce si cate like-uri are satul acum.
-- "not_visiting" | "self" | "already" | "gone" | "no_profile".
function VisitService.Like(viewer: Player, userId: number): (boolean, string, number?)
    local d = deps
    local viewerData = DataService.Get(viewer)
    if d == nil or viewerData == nil then
        return false, "no_profile", nil
    end
    if visiting[viewer] ~= userId then
        return false, "not_visiting", nil
    end
    local host = Players:GetPlayerByUserId(userId)
    local hostData = if host ~= nil then DataService.Get(host) else nil
    if host == nil or hostData == nil then
        return false, "gone", nil -- a plecat: profilul ei nu mai e aici, n-avem unde scrie
    end
    local mine = fairOf(viewerData)
    local day = today()
    local refusal = VisitMath.refusal(mine.liked, day, viewer.UserId, userId)
    if refusal ~= nil then
        return false, refusal, math.floor(fairOf(hostData).likes)
    end
    mine.liked = VisitMath.withLike(mine.liked, day, userId)
    local theirs = fairOf(hostData)
    theirs.likes = math.floor(theirs.likes) + 1
    if not viewerData.Firsts.FirstLikeGiven then
        viewerData.Firsts.FirstLikeGiven = true
        Analytics.FairStep(viewer, "FirstLikeGiven")
    end
    d.OnLiked(host, viewer.DisplayName, theirs.likes)
    return true, "ok", theirs.likes
end

-- Cate like-uri are satul tau (pentru FairState si cardul tau).
function VisitService.LikesOf(player: Player): number
    local data = DataService.Get(player)
    return if data ~= nil then math.floor(fairOf(data).likes) else 0
end

function VisitService.Init(d: Deps)
    deps = d
    Players.PlayerRemoving:Connect(function(player: Player)
        visiting[player] = nil
    end)
end

return VisitService
