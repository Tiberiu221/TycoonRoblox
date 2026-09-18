--!strict
-- [D61, partea 2] VIZITELE: like-ul si satele scoase in fata portii. Modul pur.
--
-- Un like pe zi (UTC) pentru fiecare sat: profilul vizitatorului tine ziua si satele carora le-a dat deja azi
-- (`Fair.liked = { day, ids }`); a doua zi lista se goleste singura. Gazda tine doar un numar (`Fair.likes`).
-- In fata portii stau machetele primelor trei sate din balci, dupa cate decoruri au.
local VisitMath = {}

VisitMath.DAY = 86400
VisitMath.MINIATURES = 3

export type Liked = { day: number, ids: { [string]: boolean } }
export type Host = { userId: number, name: string, decor: number, likes: number }

function VisitMath.dayOf(now: number): number
    return math.floor(now / VisitMath.DAY)
end

local function clean(liked: unknown, day: number): Liked
    if typeof(liked) == "table" then
        local l = liked :: any
        if l.day == day and typeof(l.ids) == "table" then
            return { day = day, ids = table.clone(l.ids) }
        end
    end
    return { day = day, ids = {} } -- alta zi (sau un camp stricat): lista de azi e goala
end

-- I-ai dat deja like azi satului `hostId`?
function VisitMath.likedToday(liked: unknown, day: number, hostId: number): boolean
    return clean(liked, day).ids[tostring(hostId)] == true
end

-- De ce nu se poate da like, sau nil daca se poate: "self" | "already".
function VisitMath.refusal(liked: unknown, day: number, visitorId: number, hostId: number): string?
    if visitorId == hostId then
        return "self"
    elseif VisitMath.likedToday(liked, day, hostId) then
        return "already"
    end
    return nil
end

-- Lista de azi, cu satul `hostId` adaugat. Tabel NOU: apelantul il pune in profil.
function VisitMath.withLike(liked: unknown, day: number, hostId: number): Liked
    local out = clean(liked, day)
    out.ids[tostring(hostId)] = true
    return out
end

-- Satele scoase in fata portii: cele mai multe decoruri intai, apoi like-urile, apoi userId (ca ordinea sa fie
-- aceeasi la toata lumea). Un sat fara niciun decor nu are ce arata pe macheta.
function VisitMath.top(hosts: { Host }, n: number?): { Host }
    local list: { Host } = {}
    for _, h in hosts do
        if h.decor > 0 then
            table.insert(list, h)
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
    local out: { Host } = {}
    for i = 1, math.min(n or VisitMath.MINIATURES, #list) do
        out[i] = list[i]
    end
    return out
end

return VisitMath
