--!strict
-- [D61] IAZUL DE CONCURS, pe ecran. In pasii jucatorului:
--   1. pe jetiu, deasupra apei, cardul scrie `Cast (E)`: aceeasi undita ca acasa (UI/FishingRig), cu plutitorul in apa,
--      de partea spre care te uiti;
--   2. tabla de pe malul de nord arata runda: primii patru, timpul ramas; in pauza, podiumul rundei trecute;
--   3. cat esti langa iaz, banda de sus spune runda, timpul si locul tau;
--   4. la sfarsitul rundei vine mesajul cu locul si premiul, iar perlele zboara in pastila.
-- Starea vine de la server (PondService) si se copiaza camp cu camp [CLAUDE.md, capcana 3].
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local FairLayout = require(ReplicatedStorage.Shared.Modules.FairLayout)
local Strings = require(ReplicatedStorage.Shared.Config.Strings)

local FairScene = require(script.Parent.FairScene)
local SoundController = require(script.Parent.SoundController)
local FishingRig = require(script.Parent.Parent.UI.FishingRig)
local Focus = require(script.Parent.Parent.UI.Focus)
local Theme = require(script.Parent.Parent.UI.Theme)
local Widgets = require(script.Parent.Parent.UI.Widgets)

export type Deps = {
    World: Frame,
    CharacterPos: () -> (number, number),
    Facing: () -> string,
    WorldToHud: (number, number) -> (number, number),
    Remotes: {
        PondCast: RemoteEvent,
        PondCastResult: RemoteEvent,
        PondLand: RemoteEvent,
        PondLandResult: RemoteEvent,
        PondState: RemoteEvent,
        PondResult: RemoteEvent,
    },
    IsActionHeld: () -> boolean,
    PearlFly: (number, number, number) -> (),
    OnToast: (string, Color3?) -> (),
    SetBanner: (string?, string?) -> (),
    SetFishing: (boolean) -> (),
    SetMyTagHidden: (boolean) -> (),
}

type Row = { userId: number, name: string, species: string, cm: number }
type Round = { id: number, index: number, phase: string, fishingEndsAt: number, nextAt: number }
type State = {
    round: Round,
    ranked: { Row },
    last: { index: number, podium: { Row }, count: number }?,
}

local PondController = {}
local deps: Deps? = nil
local rig: FishingRig.Rig? = nil
local state: State? = nil
local side = "right"
local castY = 0
local me = Players.LocalPlayer.UserId

local BANNER_DISTANCE = 460 -- cat de aproape de mijlocul iazului apare banda de sus
local CARD_DISTANCE = 30 -- cardul iazului pierde doar in fata unui om chiar langa tine ("Look at")
local REFRESH = 0.25

-- Tabla (scripts/art/d61.py, pond_board 60x52 la x3): capul albastru pe y 8..13, hartia pe x 4..56 si y 14..32, in
-- pixeli de desen. Randurile se scriu pe hartie, timpul si nota dedesubt, pe lemn.
local ART = 3
local ROW_H = 13
local NAME_W = 64
local boardHead: TextLabel
local boardRows: { { name: TextLabel, fish: TextLabel } } = {}
local boardTime: TextLabel
local boardNote: TextLabel
local INK = Color3.fromRGB(58, 42, 30)

local function copyRow(raw: any): Row?
    if typeof(raw) ~= "table" or typeof(raw.userId) ~= "number" or typeof(raw.cm) ~= "number" then
        return nil
    end
    return {
        userId = raw.userId,
        name = if typeof(raw.name) == "string" then raw.name else "",
        species = if typeof(raw.species) == "string" then raw.species else "",
        cm = raw.cm,
    }
end

local function copyRows(raw: any): { Row }
    local out: { Row } = {}
    if typeof(raw) == "table" then
        for _, r in raw :: { any } do
            local row = copyRow(r)
            if row ~= nil then
                table.insert(out, row)
            end
        end
    end
    return out
end

local function apply(raw: any)
    if typeof(raw) ~= "table" or typeof(raw.round) ~= "table" then
        return
    end
    local r: any = raw.round
    if
        typeof(r.index) ~= "number"
        or typeof(r.fishingEndsAt) ~= "number"
        or typeof(r.nextAt) ~= "number"
    then
        return
    end
    local last = nil
    local l: any = raw.last
    if typeof(l) == "table" and typeof(l.index) == "number" then
        last = {
            index = l.index,
            podium = copyRows(l.podium),
            count = if typeof(l.count) == "number" then l.count else 0,
        }
    end
    state = {
        round = {
            id = if typeof(r.id) == "number" then r.id else 0,
            index = r.index,
            phase = if r.phase == "results" then "results" else "fishing",
            fishingEndsAt = r.fishingEndsAt,
            nextAt = r.nextAt,
        },
        ranked = copyRows(raw.ranked),
        last = last,
    }
end

local function placeOf(rows: { Row }, userId: number): (number?, Row?)
    for i, row in rows do
        if row.userId == userId then
            return i, row
        end
    end
    return nil, nil
end

local function setRow(i: number, name: string, fish: string, mine: boolean)
    local cells = boardRows[i]
    cells.name.Text = name
    cells.fish.Text = fish
    local color = if mine then Theme.COLOR.warnInk else INK
    cells.name.TextColor3 = color
    cells.fish.TextColor3 = color
end

-- Tabla si banda, din starea de acum si ora serverului.
local function refresh()
    local d = deps
    local s = state
    if d == nil or s == nil then
        return
    end
    local now = Workspace:GetServerTimeNow()
    local r = s.round
    for i = 1, #boardRows do
        setRow(i, "", "", false)
    end
    local myPlace, myRow = placeOf(s.ranked, me)
    if r.phase == "fishing" then
        if #s.ranked == 0 then
            setRow(1, Strings.POND_NOBODY_YET, "", false)
        end
        for i = 1, math.min(#s.ranked, #boardRows) do
            local row = s.ranked[i]
            setRow(i, `{i}. {row.name}`, Strings.pondRow(row.species, row.cm), row.userId == me)
        end
        if myPlace ~= nil and myRow ~= nil and myPlace > #boardRows then
            local row = myRow :: Row
            setRow(#boardRows, `{myPlace}. {row.name}`, Strings.pondRow(row.species, row.cm), true)
        end
        boardTime.Text = Strings.pondTimeLeft(r.fishingEndsAt - now)
        boardNote.Text = Strings.POND_PRIZES_NOTE
    else
        local last = s.last
        if last ~= nil then
            for i, row in last.podium do
                if i <= #boardRows then
                    setRow(
                        i,
                        `{i}. {row.name}`,
                        Strings.pondRow(row.species, row.cm),
                        row.userId == me
                    )
                end
            end
        end
        boardTime.Text = Strings.pondNextIn(r.nextAt - now)
        local alone = last ~= nil
            and last.count == 1
            and last.podium[1] ~= nil
            and last.podium[1].userId == me
        boardNote.Text = if alone
            then Strings.POND_ALONE
            elseif last ~= nil then Strings.pondLast(last.index)
            else ""
    end

    -- banda de sus: doar cat esti langa iaz
    local px, py = d.CharacterPos()
    local pond = FairLayout.POND
    if Focus.distance(px, py, pond.x, pond.y) > BANNER_DISTANCE then
        d.SetBanner(nil, nil)
        return
    end
    if r.phase == "fishing" then
        local bottom = if myPlace ~= nil and myRow ~= nil
            then Strings.pondYou(myPlace, (myRow :: Row).species, (myRow :: Row).cm)
            else Strings.POND_ENTER
        d.SetBanner(Strings.pondBanner(r.index, r.fishingEndsAt - now), bottom)
    else
        d.SetBanner(Strings.pondBannerBreak(r.nextAt - now), Strings.POND_PRIZES_NOTE)
    end
end

local function buildBoard(world: Frame)
    local x, y, w, h = FairScene.Spot("pond_board")
    local left, top = x - w / 2, y - h
    local z = FairScene.Z.LABELS
    boardHead = Widgets.Label(world, Strings.POND_BOARD_TITLE, 11, Theme.COLOR.onDark, "display")
    boardHead.Position = UDim2.fromOffset(left + 4 * ART, top + 8 * ART)
    boardHead.Size = UDim2.fromOffset(52 * ART, 6 * ART)
    boardHead.TextXAlignment = Enum.TextXAlignment.Center
    boardHead.ZIndex = z
    Theme.punch(boardHead, 1)
    local paperX, paperY = left + 4 * ART + 4, top + 14 * ART + 1
    local paperW = 52 * ART - 8
    for i = 1, 4 do
        local rowY = paperY + (i - 1) * ROW_H
        local name = Widgets.Label(world, "", 10, INK, "strong")
        name.Position = UDim2.fromOffset(paperX, rowY)
        name.Size = UDim2.fromOffset(NAME_W, ROW_H)
        name.TextTruncate = Enum.TextTruncate.AtEnd
        name.ZIndex = z
        local fish = Widgets.Label(world, "", 10, INK, "strong")
        fish.Position = UDim2.fromOffset(paperX + NAME_W + 2, rowY)
        fish.Size = UDim2.fromOffset(paperW - NAME_W - 2, ROW_H)
        fish.TextXAlignment = Enum.TextXAlignment.Right
        fish.TextTruncate = Enum.TextTruncate.AtEnd
        fish.ZIndex = z
        boardRows[i] = { name = name, fish = fish }
    end
    boardTime = Widgets.Label(world, "", 13, Theme.COLOR.gold, "strong")
    boardTime.AnchorPoint = Vector2.new(0.5, 0)
    boardTime.Position = UDim2.fromOffset(x, top + 33 * ART)
    boardTime.Size = UDim2.fromOffset(w + 40, 16)
    boardTime.TextXAlignment = Enum.TextXAlignment.Center
    boardTime.ZIndex = z
    Theme.punch(boardTime, 2)
    boardNote = Widgets.Label(world, "", 10, Theme.COLOR.onDark, "strong")
    boardNote.AnchorPoint = Vector2.new(0.5, 0)
    boardNote.Position = UDim2.fromOffset(x, top + 33 * ART + 17)
    boardNote.Size = UDim2.fromOffset(w + 60, 14)
    boardNote.TextXAlignment = Enum.TextXAlignment.Center
    boardNote.ZIndex = z
    Theme.punch(boardNote, 2)
end

-- Cardul iazului: pe jetiu, deasupra apei. Cat arunci, astepti sau mulinezi, cardul se ascunde (E strange firul).
function PondController.Focus(px: number, py: number): Focus.Focus?
    local r = rig
    if r == nil or not FairLayout.inRect(FairLayout.CAST_ZONE, px, py) then
        return nil
    end
    local f: Focus.Focus = { key = "pond", distance = CARD_DISTANCE, x = px, y = py - 84 }
    if r.state() ~= "idle" then
        return f
    end
    local keyHint = if UserInputService.KeyboardEnabled then " (E)" else ""
    f.action = Strings.fishCast(keyHint)
    f.act = r.cast
    return f
end

function PondController.Init(d: Deps)
    deps = d
    buildBoard(d.World)
    rig = FishingRig.new({
        Layer = d.World,
        Origin = Vector2.zero,
        CharacterPos = d.CharacterPos,
        WorldToHud = d.WorldToHud,
        Remotes = {
            Cast = d.Remotes.PondCast,
            CastResult = d.Remotes.PondCastResult,
            Land = d.Remotes.PondLand,
            LandResult = d.Remotes.PondLandResult,
        },
        -- plutitorul cade de partea spre care te uiti, dincolo de marginea jetiului, la inaltimea ta
        Target = function(_c: FishingRig.Cast, s: string): (number, number)
            return FairLayout.bobberFor(castY, s)
        end,
        SideFor = function(c: FishingRig.Cast?): string
            if c ~= nil then
                return side
            end
            local px, py = d.CharacterPos()
            local facing = d.Facing()
            local j = FairLayout.JETTY
            side = if facing == "left"
                then "left"
                elseif facing == "right" then "right"
                elseif px < (j.x0 + j.x1) / 2 then "left"
                else "right"
            castY = py
            return side
        end,
        IsActionHeld = d.IsActionHeld,
        PearlFly = d.PearlFly,
        OnToast = d.OnToast,
        OnOutfit = function(_outfit: string)
            d.OnToast(Strings.outfitUnlocked("River Legend"), Theme.COLOR.gold)
        end,
        OnState = function(s: string)
            d.SetFishing(s ~= "idle")
            d.SetMyTagHidden(s == "reeling" or s == "landing")
        end,
        LineZ = FairScene.Z.SPARKS - 2,
        Z = FairScene.Z.CARD + 2,
    })

    d.Remotes.PondState.OnClientEvent:Connect(function(raw: any)
        apply(raw)
        refresh()
    end)
    d.Remotes.PondResult.OnClientEvent:Connect(function(raw: any)
        if
            typeof(raw) ~= "table"
            or typeof(raw.prize) ~= "number"
            or typeof(raw.index) ~= "number"
        then
            return
        end
        local place = if typeof(raw.place) == "number" then raw.place else 1
        local count = if typeof(raw.count) == "number" then raw.count else 1
        d.OnToast(
            Strings.pondResult(raw.index, place, count, raw.prize, raw.contest == true),
            Theme.COLOR.gold
        )
        SoundController.Play("chime", if raw.won == true then 1.3 else 1)
        local px, py = d.CharacterPos()
        local hx, hy = d.WorldToHud(px, py - 90)
        d.PearlFly(hx, hy, raw.prize)
        if raw.title == true then
            task.delay(1.6, function()
                d.OnToast(Strings.POND_TITLE_UNLOCKED, Theme.COLOR.gold)
            end)
        end
    end)

    local acc = 0
    RunService.PreRender:Connect(function(dt: number)
        acc += dt
        if acc >= REFRESH then
            acc = 0
            refresh()
        end
    end)
end

return PondController
