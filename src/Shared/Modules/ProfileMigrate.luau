--!strict
-- Migrarea profilului la schema v2 (pivotul D45 la tycoon) [F0 spec 1.3]. Sterge tot in afara
-- de Index si Meta.createdAt; restul se reumple din PROFILE_TEMPLATE la profile:Reconcile().
-- Pura si idempotenta: fara `game`, ca sa poata rula si sub Lune.
local ProfileMigrate = {}

function ProfileMigrate.toV2(data: { [string]: any })
    local version = if data.Meta ~= nil and data.Meta.version ~= nil then data.Meta.version else 1
    if version >= 2 then
        return
    end
    local createdAt = if data.Meta ~= nil then data.Meta.createdAt else 0
    local index = data.Index
    for key in data do
        if key ~= "Index" and key ~= "Meta" then
            data[key] = nil
        end
    end
    data.Index = index or {}
    data.Meta = { version = 2, createdAt = createdAt or 0, lastSeenAt = 0 }
end

return ProfileMigrate
