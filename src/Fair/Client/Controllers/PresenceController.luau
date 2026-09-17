--!strict
-- [D60] CEILALTI OAMENI DIN BALCI. Pana acum clientul nu desena niciun alt jucator: tinutele si decorul n-aveau
-- privitori. Aici:
--   * pozitia ta pleaca la server de zece ori pe secunda (doar cand s-a schimbat ceva, altfel o data pe secunda);
--   * ceilalti vin intr-un singur pachet (CrowdCodec) si se misca lin intre doua pachete, cu o zecime de secunda
--     in urma (asa se interpoleaza intre doua pozitii stiute, nu se ghiceste);
--   * fiecare om e desenat ca tine (SceneArt.MakeCharacter, cu tinuta lui), cu NUMELE deasupra capului si TITLUL sub
--     nume; si deasupra ta scrie ce vad ceilalti.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local CrowdCodec = require(ReplicatedStorage.Shared.Modules.CrowdCodec)
local FairPresence = require(ReplicatedStorage.Shared.Modules.FairPresence)
local RiverConfig = require(ReplicatedStorage.Shared.Config.RiverConfig)

local SceneArt = require(script.Parent.SceneArt)
local Focus = require(script.Parent.Parent.UI.Focus)
local Theme = require(script.Parent.Parent.UI.Theme)
local Widgets = require(script.Parent.Parent.UI.Widgets)

export type Person = { slot: number, userId: number, name: string, outfit: string, title: string }
export type Deps = {
    World: Frame,
    ZIndexFor: (number) -> number,
    LabelZ: number,
    LocalUserId: number,
    CharacterPos: () -> (number, number),
    Facing: () -> string,
    IsMoving: () -> boolean,
    Remotes: { Where: UnreliableRemoteEvent, Crowd: UnreliableRemoteEvent, People: RemoteEvent },
    -- "Look at Mara (E)": cardul altui om (PlayerCardController)
    OnLookAt: (Person) -> (),
    LookAtText: (string, string) -> string,
}

type Sample = { x: number, y: number, t: number }
type Tag = { host: Frame, name: TextLabel, title: TextLabel }
type Other = {
    card: Person,
    sprite: GuiObject,
    pose: SceneArt.Pose,
    setOutfit: SceneArt.SetOutfit,
    tag: Tag,
    older: Sample?,
    newer: Sample?,
    facing: string,
    moving: boolean,
    fishing: boolean, -- [D61] cu undita pe jetiu
    x: number,
    y: number,
}

local PresenceController = {}
local deps: Deps? = nil
local others: { [number]: Other } = {} -- dupa slot
local mine: Person? = nil
local myTag: Tag? = nil
-- [D61] ce spui tu despre tine: undita (doar aspect; serverul o crede doar pe jetiu) si eticheta ascunsa cat mulinezi
local myFishing = false
local myTagHidden = false

local SEND_EVERY = 1 / FairPresence.RATE
local HEARTBEAT = 1 -- cat stai pe loc, pozitia pleaca totusi o data pe secunda
local DELAY = 1 / FairPresence.RATE -- cu cat ramane desenul in urma, ca sa fie mereu intre doua pozitii stiute
local HEAD = RiverConfig.CHARACTER.HEIGHT
local LOOK_DISTANCE = 80
local NAME_W = 220

local function makeTag(parent: Frame, z: number): Tag
    local host = Instance.new("Frame")
    host.Name = "PersonTag"
    host.AnchorPoint = Vector2.new(0.5, 1)
    host.BackgroundTransparency = 1
    host.Size = UDim2.fromOffset(NAME_W, 36)
    host.ZIndex = z
    host.Parent = parent
    local name = Widgets.Label(host, "", Theme.TEXT.tiny, Theme.COLOR.onDark, "strong")
    name.Position = UDim2.fromOffset(0, 0)
    name.Size = UDim2.fromOffset(NAME_W, 17)
    name.TextXAlignment = Enum.TextXAlignment.Center
    name.TextTruncate = Enum.TextTruncate.AtEnd
    name.ZIndex = z + 1
    Theme.punch(name, 2)
    local title = Widgets.Label(host, "", Theme.TEXT.tiny, Theme.COLOR.gold, "strong")
    title.Position = UDim2.fromOffset(0, 18)
    title.Size = UDim2.fromOffset(NAME_W, 17)
    title.TextXAlignment = Enum.TextXAlignment.Center
    title.TextTruncate = Enum.TextTruncate.AtEnd
    title.ZIndex = z + 1
    Theme.punch(title, 2)
    return { host = host, name = name, title = title }
end

local function placeTag(tag: Tag, x: number, y: number)
    tag.host.Position = UDim2.fromOffset(math.round(x), math.round(y - HEAD - 4))
end

local function setCard(tag: Tag, card: Person)
    tag.name.Text = card.name
    tag.title.Text = card.title
end

local function forget(slot: number)
    local o = others[slot]
    if o == nil then
        return
    end
    o.sprite:Destroy()
    o.tag.host:Destroy()
    others[slot] = nil
end

local function applyPeople(list: unknown)
    local d = deps
    if d == nil or typeof(list) ~= "table" then
        return
    end
    local seen: { [number]: boolean } = {}
    for _, raw in list :: { any } do
        if typeof(raw) ~= "table" or typeof(raw.slot) ~= "number" then
            continue
        end
        -- copiat camp cu camp [CLAUDE.md, capcana 3]
        local card: Person = {
            slot = raw.slot,
            userId = if typeof(raw.userId) == "number" then raw.userId else 0,
            name = if typeof(raw.name) == "string" then raw.name else "",
            outfit = if typeof(raw.outfit) == "string" then raw.outfit else "keeper",
            title = if typeof(raw.title) == "string" then raw.title else "",
        }
        if card.userId == d.LocalUserId then
            mine = card
            local tag = myTag
            if tag ~= nil then
                setCard(tag, card)
            end
            continue
        end
        seen[card.slot] = true
        local o = others[card.slot]
        if o ~= nil and o.card.userId ~= card.userId then
            forget(card.slot) -- slotul a trecut la altcineva
            o = nil
        end
        if o == nil then
            local sprite, pose, setOutfit = SceneArt.MakeCharacter(d.World)
            sprite.Visible = false -- pana la prima pozitie
            local tag = makeTag(d.World, d.LabelZ)
            tag.host.Visible = false
            o = {
                card = card,
                sprite = sprite,
                pose = pose,
                setOutfit = setOutfit,
                tag = tag,
                older = nil,
                newer = nil,
                facing = "down",
                moving = false,
                fishing = false,
                x = 0,
                y = 0,
            }
            others[card.slot] = o
        end
        local other = o :: Other
        other.card = card
        other.setOutfit(card.outfit)
        setCard(other.tag, card)
    end
    for slot in others do
        if not seen[slot] then
            forget(slot)
        end
    end
end

local function applyCrowd(packet: unknown)
    local now = os.clock()
    for _, e in CrowdCodec.decode(packet) do
        local o = others[e.slot]
        if o == nil then
            continue
        end
        o.older = o.newer
        o.newer = { x = e.x, y = e.y, t = now }
        o.facing = e.facing
        o.moving = e.moving
        o.fishing = e.fishing == true
    end
end

local function draw(dt: number)
    local d = deps
    if d == nil then
        return
    end
    local renderAt = os.clock() - DELAY
    for _, o in others do
        local newer = o.newer
        if newer == nil then
            continue
        end
        local older = o.older or newer
        local span = newer.t - older.t
        local alpha = if span > 0 then (renderAt - older.t) / span else 1
        o.x, o.y = FairPresence.lerp(older.x, older.y, newer.x, newer.y, alpha)
        o.sprite.Visible = true
        o.tag.host.Visible = true
        o.sprite.Position = UDim2.fromOffset(math.round(o.x), math.round(o.y))
        o.sprite.ZIndex = d.ZIndexFor(o.y)
        o.pose(o.moving, o.facing, dt, false, if o.fishing and not o.moving then "fishing" else nil)
        placeTag(o.tag, o.x, o.y)
    end
    local tag = myTag
    if tag ~= nil then
        local x, y = d.CharacterPos()
        tag.host.Visible = mine ~= nil and not myTagHidden
        placeTag(tag, x, y)
    end
end

-- [D61] Cu undita in apa (PondController): ceilalti te vad pescuind.
function PresenceController.SetFishing(on: boolean)
    myFishing = on
end

-- [D61] Cat e bara de mulinat deasupra ta, numele si titlul tau se ascund (ar sta sub bara).
function PresenceController.SetMyTagHidden(hidden: boolean)
    myTagHidden = hidden
end

-- Cel mai apropiat om, pentru cardul "Look at Mara (E)".
function PresenceController.Focus(px: number, py: number): Focus.Focus?
    local d = deps
    if d == nil then
        return nil
    end
    local best: Other? = nil
    local bestDistance = LOOK_DISTANCE
    for _, o in others do
        if o.newer == nil then
            continue
        end
        local distance = Focus.distance(px, py, o.x, o.y)
        if distance <= bestDistance then
            best, bestDistance = o, distance
        end
    end
    if best == nil then
        return nil
    end
    local other = best :: Other
    local keyHint = if UserInputService.KeyboardEnabled then " (E)" else ""
    local card = other.card
    return {
        key = `person:{card.userId}`,
        distance = bestDistance,
        x = other.x,
        y = other.y - HEAD - 40, -- deasupra numelui si a titlului
        action = d.LookAtText(card.name, keyHint),
        act = function()
            d.OnLookAt(card)
        end,
    }
end

-- Cartea de vizita a cuiva de pe server (dupa userId), daca e inca aici.
function PresenceController.CardOf(userId: number): Person?
    for _, o in others do
        if o.card.userId == userId then
            return o.card
        end
    end
    return nil
end

function PresenceController.Init(d: Deps)
    deps = d
    myTag = makeTag(d.World, d.LabelZ)
    d.Remotes.People.OnClientEvent:Connect(applyPeople)
    d.Remotes.Crowd.OnClientEvent:Connect(applyCrowd)
    d.Remotes.People:FireServer() -- lista intreaga, chiar daca a plecat inainte sa ascultam
    task.delay(3, function()
        if mine == nil then
            d.Remotes.People:FireServer()
        end
    end)

    local lastSent = -math.huge
    local sentX, sentY, sentFacing, sentMoving, sentFishing = math.huge, math.huge, "", false, false
    RunService.PreRender:Connect(function(dt: number)
        draw(dt)
        local now = os.clock()
        if now - lastSent < SEND_EVERY then
            return
        end
        local x, y = d.CharacterPos()
        local facing, moving = d.Facing(), d.IsMoving()
        local changed = math.abs(x - sentX) >= 1
            or math.abs(y - sentY) >= 1
            or facing ~= sentFacing
            or moving ~= sentMoving
            or myFishing ~= sentFishing
        if not changed and now - lastSent < HEARTBEAT then
            return
        end
        lastSent = now
        sentX, sentY, sentFacing, sentMoving, sentFishing = x, y, facing, moving, myFishing
        d.Remotes.Where:FireServer(x, y, facing, moving, myFishing)
    end)
end

return PresenceController
