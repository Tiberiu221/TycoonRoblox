--!strict
-- [D61, partea 2] POARTA SATELOR, in balci. La arcada din sud-vest, cardul scrie `Village Gate (E)`: panoul arata cine
-- e acum in balci (numele, titlul, Era, decorurile, like-urile), cu butonul `Visit`. Cele trei machete din fata portii
-- poarta numele primelor trei sate dupa decoruri; langa una, `Visit Mara's village (E)`. Acelasi drum porneste si de pe
-- cardul unui om (PlayerCardController -> VisitController.Visit).
--
-- VIZITA e o fotografie a satului gazdei (VisitService -> VillageDiorama): ecranul se intuneca o clipa, camera trece pe
-- satul desenat in dreapta hartii, omul tau apare acolo si se plimba liber. Banda de sus spune al cui e satul. La cartea
-- de oaspeti lasi un like (unul pe zi pentru fiecare sat). `Back to the fair` (butonul de sus sau Q) te aduce inapoi,
-- langa arcada -- unde te-au vazut ceilalti stand in tot timpul asta.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local FairLayout = require(ReplicatedStorage.Shared.Modules.FairLayout)
local Strings = require(ReplicatedStorage.Shared.Config.Strings)
local VillageLook = require(ReplicatedStorage.Shared.Modules.VillageLook)
local VisitMath = require(ReplicatedStorage.Shared.Modules.VisitMath)

local CameraController = require(script.Parent.CameraController)
local CharacterController = require(script.Parent.CharacterController)
local FairScene = require(script.Parent.FairScene)
local Panels = require(script.Parent.Panels)
local SoundController = require(script.Parent.SoundController)
local VillageDiorama = require(script.Parent.VillageDiorama)
local Focus = require(script.Parent.Parent.UI.Focus)
local Theme = require(script.Parent.Parent.UI.Theme)
local Widgets = require(script.Parent.Parent.UI.Widgets)

export type Host = {
    userId: number,
    name: string,
    title: string,
    era: number,
    decor: number,
    likes: number,
    liked: boolean,
}
export type Deps = {
    World: Frame,
    HudGui: Frame,
    ScreenGui: ScreenGui, -- pentru intunericul dintre balci si sat, peste tot ecranul
    Remotes: {
        VisitList: RemoteEvent,
        VisitLook: RemoteEvent,
        VisitLookResult: RemoteEvent,
        VisitLeave: RemoteEvent,
        VisitLike: RemoteEvent,
        VisitLikeResult: RemoteEvent,
        VisitLiked: RemoteEvent,
    },
    OnToast: (string, Color3?) -> (),
    SetBanner: (string?, string?) -> (),
}

local VisitController = {}
local deps: Deps? = nil
local window: Frame
local open = false
local list: ScrollingFrame
local emptyLabel: TextLabel
local myLikesLabel: TextLabel
local myLikes = 0
local backButton: TextButton
local fade: Frame
local hosts: { Host } = {}
local visiting: Host? = nil
local busy = false -- intre cerere si raspuns, sau in timpul intunericului: un al doilea E nu porneste alta vizita
local likePending = false

-- Cutiile randului: scripts/art/check_panel_rows.py (VISIT_ROW).
local PANEL_W, PANEL_H = 600, 480
local ROW_H = 64
local BUTTON_W = 130
local Z = 76
local NEAR_GATE = 130
local NEAR_MINI = 70
local NEAR_BOOK = 110
local LIST_EVERY = 15 -- cat de des se reimprospateaza machetele
local LIST_EVERY_OPEN = 5 -- ...si lista, cat panoul e deschis
local FADE_SECONDS = 0.25
local MINI_TAG_W = 110
local MINI_NAME_CHARS = 12

type RowView = {
    frame: Frame,
    name: TextLabel,
    title: TextLabel,
    sub: TextLabel,
    button: TextButton,
}
local views: { RowView } = {}
local actions: { [number]: () -> () } = {}
local miniTags: { TextLabel } = {}
local miniHosts: { Host? } = {}

local function keyHint(): string
    return if UserInputService.KeyboardEnabled then " (E)" else ""
end

local function shortName(name: string): string
    if #name <= MINI_NAME_CHARS then
        return name
    end
    return string.sub(name, 1, MINI_NAME_CHARS - 1) .. "."
end

-- ---- machetele din fata portii -----------------------------------------------------------------------------------
local function refreshMinis()
    local plain: { VisitMath.Host } = {}
    local byId: { [number]: Host } = {}
    for _, h in hosts do
        table.insert(plain, { userId = h.userId, name = h.name, decor = h.decor, likes = h.likes })
        byId[h.userId] = h
    end
    local top = VisitMath.top(plain, VisitMath.MINIATURES)
    for i = 1, VisitMath.MINIATURES do
        local entry = top[i]
        local host = if entry ~= nil then byId[entry.userId] else nil
        miniHosts[i] = host
        local tag = miniTags[i]
        if tag ~= nil then
            tag.Text = if host ~= nil then shortName(host.name) else ""
            tag.Visible = host ~= nil
        end
    end
end

local function buildMinis(world: Frame)
    for i = 1, VisitMath.MINIATURES do
        local x, y = FairScene.Spot(`mini_{i}`)
        local tag = Widgets.Label(world, "", Theme.TEXT.tiny, Theme.COLOR.onDark, "strong")
        tag.Name = `MiniTag{i}`
        tag.AnchorPoint = Vector2.new(0.5, 0)
        tag.Position = UDim2.fromOffset(x, y + 2)
        tag.Size = UDim2.fromOffset(MINI_TAG_W, 16)
        tag.TextXAlignment = Enum.TextXAlignment.Center
        tag.TextTruncate = Enum.TextTruncate.AtEnd
        tag.ZIndex = FairScene.Z.LABELS
        tag.Visible = false
        Theme.punch(tag, 2)
        miniTags[i] = tag
    end
end

-- ---- panoul portii -----------------------------------------------------------------------------------------------
local function buildRow(index: number): RowView
    local frame = Instance.new("Frame")
    frame.Name = `Row{index}`
    frame.BackgroundTransparency = 1
    frame.Size = UDim2.new(1, 0, 0, ROW_H)
    frame.LayoutOrder = index
    frame.ZIndex = Z + 2
    frame.Parent = list
    Widgets.PillBackground(frame, Z + 2)

    local name = Widgets.Label(frame, "", Theme.TEXT.small, Theme.COLOR.onDark, "strong")
    name.Position = UDim2.fromOffset(Theme.SPACE.md, 6)
    name.Size = UDim2.fromOffset(330, 20)
    name.TextTruncate = Enum.TextTruncate.AtEnd
    name.ZIndex = Z + 3

    local title = Widgets.Label(frame, "", Theme.TEXT.tiny, Theme.COLOR.gold, "strong")
    title.Position = UDim2.fromOffset(Theme.SPACE.md, 26)
    title.Size = UDim2.fromOffset(330, 16)
    title.TextTruncate = Enum.TextTruncate.AtEnd
    title.ZIndex = Z + 3

    local sub = Widgets.Label(frame, "", Theme.TEXT.tiny, Theme.COLOR.onDarkSoft, "body")
    sub.Position = UDim2.fromOffset(Theme.SPACE.md, 43)
    sub.Size = UDim2.fromOffset(330, 16)
    sub.TextTruncate = Enum.TextTruncate.AtEnd
    sub.ZIndex = Z + 3

    local button = Widgets.Button(frame, {
        text = Strings.VISIT_BUTTON,
        width = BUTTON_W,
        height = 44,
        z = Z + 3,
        onClick = function()
            local act = actions[index]
            if act ~= nil then
                act()
            end
        end,
    })
    button.AnchorPoint = Vector2.new(1, 0.5)
    button.Position = UDim2.new(1, -Theme.SPACE.md, 0.5, 0)
    Widgets.SetButtonTone(button, Theme.COLOR.gold)
    return { frame = frame, name = name, title = title, sub = sub, button = button }
end

local function refreshPanel()
    if not open then
        return
    end
    emptyLabel.Visible = #hosts == 0
    myLikesLabel.Text = Strings.visitMyLikes(myLikes)
    for i, host in hosts do
        local view = views[i]
        if view == nil then
            view = buildRow(i)
            views[i] = view
        end
        view.frame.Visible = true
        view.name.Text = host.name
        view.title.Text = host.title
        view.sub.Text = Strings.visitRowSub(host.era, host.decor, host.likes)
        local userId = host.userId
        actions[i] = function()
            VisitController.Visit(userId)
        end
    end
    for i = #hosts + 1, #views do
        views[i].frame.Visible = false
        actions[i] = nil
    end
    list.CanvasSize = UDim2.fromOffset(0, #hosts * (ROW_H + Theme.SPACE.sm))
end

-- ---- intrarea si iesirea -----------------------------------------------------------------------------------------
-- Ecranul se intuneca, se face schimbarea pe intuneric, apoi se lumineaza: fara el, harta ar sari dintr-un cadru in altul.
local function throughDark(switch: () -> ())
    busy = true
    fade.Visible = true
    local tweenIn = TweenService:Create(
        fade,
        TweenInfo.new(FADE_SECONDS, Enum.EasingStyle.Sine, Enum.EasingDirection.Out),
        { BackgroundTransparency = 0 }
    )
    tweenIn:Play()
    task.delay(FADE_SECONDS, function()
        local ok, err = pcall(switch)
        if not ok then
            warn(`[Visit] schimbarea a esuat: {err}`)
        end
        local tweenOut = TweenService:Create(
            fade,
            TweenInfo.new(FADE_SECONDS, Enum.EasingStyle.Sine, Enum.EasingDirection.In),
            { BackgroundTransparency = 1 }
        )
        tweenOut:Play()
        task.delay(FADE_SECONDS, function()
            fade.Visible = false
            busy = false
        end)
    end)
end

local function showBanner()
    local d = deps
    local host = visiting
    if d == nil or host == nil then
        return
    end
    d.SetBanner(
        Strings.visitBannerTop(host.name),
        Strings.visitBannerBottom(host.era, host.decor, host.likes)
    )
end

local function enter(host: Host, village: VillageLook.Snapshot)
    Panels.CloseAll()
    throughDark(function()
        visiting = host
        VillageDiorama.Show(village)
        local o, s = VillageDiorama.ORIGIN, VillageDiorama.SIZE
        CameraController.SetWorld(o.x, o.y, s.w, s.h)
        local ax, ay = VillageDiorama.ToWorld(VillageDiorama.ARRIVE.x, VillageDiorama.ARRIVE.y)
        CharacterController.Teleport(ax, ay, "down")
        backButton.Visible = true
        showBanner()
    end)
end

function VisitController.IsVisiting(): boolean
    return visiting ~= nil
end

-- Te intorci langa arcada. Si serverul afla, ca urmatoarele pachete de pozitie sa fie iar ale tale.
function VisitController.Leave()
    local d = deps
    if d == nil or visiting == nil or busy then
        return
    end
    SoundController.Play("click")
    throughDark(function()
        visiting = nil
        likePending = false
        VillageDiorama.Hide()
        CameraController.ResetWorld()
        CharacterController.Teleport(FairLayout.GATE_STAND.x, FairLayout.GATE_STAND.y, "down")
        backButton.Visible = false
        d.SetBanner(nil, nil)
        d.Remotes.VisitLeave:FireServer()
        d.Remotes.VisitList:FireServer()
    end)
end

-- Cere fotografia satului cuiva (din panou, de la o macheta sau de pe cardul unui om).
function VisitController.Visit(userId: number)
    local d = deps
    if d == nil or busy or visiting ~= nil then
        return
    end
    busy = true
    SoundController.Play("click")
    d.Remotes.VisitLook:FireServer(userId)
    -- fara raspuns (pachet pierdut, limita de rata): dupa 3 s se poate incerca din nou
    task.delay(3, function()
        if busy and visiting == nil and not fade.Visible then
            busy = false
        end
    end)
end

local function like()
    local d = deps
    local host = visiting
    if d == nil or host == nil or likePending or host.liked then
        return
    end
    likePending = true
    SoundController.Play("click")
    d.Remotes.VisitLike:FireServer(host.userId)
    task.delay(3, function()
        likePending = false
    end)
end

-- ---- panoul --------------------------------------------------------------------------------------------------------
function VisitController.IsOpen(): boolean
    return open
end

function VisitController.Close()
    open = false
    window.Visible = false
end

function VisitController.Open()
    local d = deps
    if d == nil or visiting ~= nil or not Panels.CanOpen("visit") then
        return
    end
    Panels.CloseOthers("visit")
    open = true
    window.Visible = true
    SoundController.Play("click")
    d.Remotes.VisitList:FireServer()
    refreshPanel()
end

-- Din FairState: cate like-uri a strans satul tau (scris sus, in panoul portii).
function VisitController.SetLikes(likes: number)
    myLikes = math.max(0, math.floor(likes))
    refreshPanel()
end

-- ---- cardurile din lume --------------------------------------------------------------------------------------------
function VisitController.Focus(px: number, py: number): Focus.Focus?
    if deps == nil or busy then
        return nil
    end
    local host = visiting
    if host ~= nil then
        -- in vizita: doar cartea de oaspeti
        local bx, by =
            VillageDiorama.ToWorld(VillageDiorama.GUEST_BOOK.x, VillageDiorama.GUEST_BOOK.y)
        local distance = Focus.distance(px, py, bx, by)
        if distance > NEAR_BOOK then
            return nil
        end
        return {
            key = "visit:book",
            distance = distance,
            x = bx,
            y = by - 72,
            action = if host.liked then nil else Strings.visitLikeCard(keyHint()),
            act = if host.liked then nil else like,
            status = if host.liked then Strings.VISIT_LIKED_TODAY else nil,
        }
    end
    -- machetele: cea mai apropiata care are un sat pe ea
    local best: Focus.Focus? = nil
    for i = 1, VisitMath.MINIATURES do
        local mini = miniHosts[i]
        if mini ~= nil then
            local x, y, _, h = FairScene.Spot(`mini_{i}`)
            local distance = Focus.distance(px, py, x, y + 10)
            if distance <= NEAR_MINI and (best == nil or distance < best.distance) then
                local userId = mini.userId
                best = {
                    key = `visit:mini_{i}`,
                    distance = distance,
                    x = x,
                    y = y - h - 8,
                    action = Strings.visitMiniCard(shortName(mini.name), keyHint()),
                    act = function()
                        VisitController.Visit(userId)
                    end,
                }
            end
        end
    end
    if best ~= nil then
        return best
    end
    local x, y, _, h = FairScene.Spot("arch")
    local distance = Focus.distance(px, py, x, y + 10)
    if distance > NEAR_GATE then
        return nil
    end
    return {
        key = "visit:gate",
        distance = distance,
        x = x,
        y = y - h - 8,
        action = Strings.visitCard(keyHint()),
        act = VisitController.Open,
    }
end

function VisitController.Init(d: Deps)
    deps = d
    VillageDiorama.Init(d.World)
    buildMinis(d.World)

    local root, body = Widgets.Window(d.HudGui, {
        name = "VillageGate",
        title = Strings.VISIT_TITLE,
        icon = "people",
        width = PANEL_W,
        height = PANEL_H,
        z = Z,
        onClose = VisitController.Close,
    })
    window = root
    window.AnchorPoint = Vector2.new(0.5, 0.5)
    window.Position = UDim2.fromScale(0.5, 0.5)
    window.Visible = false

    local blurb =
        Widgets.Label(body, Strings.VISIT_BLURB, Theme.TEXT.tiny, Theme.COLOR.inkSoft, "body")
    blurb.Position = UDim2.fromOffset(0, 0)
    blurb.Size = UDim2.new(1, 0, 0, 18)
    blurb.TextTruncate = Enum.TextTruncate.AtEnd
    blurb.ZIndex = Z + 1

    myLikesLabel = Widgets.Label(body, "", Theme.TEXT.small, Theme.COLOR.ink, "strong")
    myLikesLabel.Position = UDim2.fromOffset(0, 22)
    myLikesLabel.Size = UDim2.new(1, 0, 0, 20)
    myLikesLabel.TextTruncate = Enum.TextTruncate.AtEnd
    myLikesLabel.ZIndex = Z + 1

    list = Widgets.List(body, Z + 1, Theme.SPACE.sm)
    local holder = list.Parent :: Frame
    holder.Position = UDim2.fromOffset(0, 50)
    holder.Size = UDim2.new(1, 0, 1, -50)

    emptyLabel =
        Widgets.Label(holder, Strings.VISIT_EMPTY, Theme.TEXT.small, Theme.COLOR.ink, "body")
    emptyLabel.AnchorPoint = Vector2.new(0.5, 0.5)
    emptyLabel.Position = UDim2.fromScale(0.5, 0.5)
    emptyLabel.Size = UDim2.new(1, -40, 0, 24)
    emptyLabel.TextXAlignment = Enum.TextXAlignment.Center
    emptyLabel.ZIndex = Z + 3

    -- intoarcerea: mereu la vedere cat esti in vizita (pe telefon nu exista Q), sub banda cu numele satului
    local backText = Strings.visitBack(if UserInputService.KeyboardEnabled then " (Q)" else "")
    backButton = Widgets.Button(d.HudGui, {
        text = backText,
        width = math.ceil(Theme.textWidth(backText, Theme.TEXT.body, "strong")) + 48,
        height = 44,
        z = 14,
        onClick = VisitController.Leave,
    })
    backButton.Name = "BackToFair"
    backButton.AnchorPoint = Vector2.new(0.5, 0)
    backButton.Position = UDim2.new(0.5, 0, 0, 78)
    backButton.Visible = false
    Widgets.SetButtonTone(backButton, Theme.COLOR.gold)

    -- intunericul dintre balci si sat: peste tot ecranul, deasupra HUD-ului
    fade = Instance.new("Frame")
    fade.Name = "VisitFade"
    fade.BackgroundColor3 = Color3.new(0, 0, 0)
    fade.BackgroundTransparency = 1
    fade.BorderSizePixel = 0
    fade.Size = UDim2.fromScale(1, 1)
    fade.ZIndex = 1000
    fade.Visible = false
    fade.Parent = d.ScreenGui

    d.Remotes.VisitList.OnClientEvent:Connect(function(raw: unknown)
        local fresh: { Host } = {}
        if typeof(raw) == "table" then
            for _, e in raw :: { any } do
                if typeof(e) == "table" and typeof(e.userId) == "number" then
                    -- copiat camp cu camp [CLAUDE.md, capcana 3]
                    table.insert(fresh, {
                        userId = e.userId,
                        name = if typeof(e.name) == "string" then e.name else "?",
                        title = if typeof(e.title) == "string" then e.title else "",
                        era = if typeof(e.era) == "number" then e.era else 1,
                        decor = if typeof(e.decor) == "number" then e.decor else 0,
                        likes = if typeof(e.likes) == "number" then e.likes else 0,
                        liked = e.liked == true,
                    })
                end
            end
        end
        hosts = fresh
        refreshMinis()
        refreshPanel()
    end)

    d.Remotes.VisitLookResult.OnClientEvent:Connect(
        function(ok: unknown, reason: unknown, payload: unknown)
            busy = false
            if ok ~= true or typeof(payload) ~= "table" then
                d.OnToast(
                    Strings.visitRefused(if typeof(reason) == "string" then reason else ""),
                    Theme.COLOR.bad
                )
                d.Remotes.VisitList:FireServer() -- poate a plecat: lista se reface
                return
            end
            local p = payload :: any
            local h: any = p.host
            if typeof(h) ~= "table" or typeof(p.village) ~= "table" then
                return
            end
            local host: Host = {
                userId = h.userId,
                name = if typeof(h.name) == "string" then h.name else "?",
                title = if typeof(h.title) == "string" then h.title else "",
                era = if typeof(h.era) == "number" then h.era else 1,
                decor = if typeof(h.decor) == "number" then h.decor else 0,
                likes = if typeof(h.likes) == "number" then h.likes else 0,
                liked = h.liked == true,
            }
            -- fotografia, copiata camp cu camp [CLAUDE.md, capcana 3]: un camp lipsa e un tabel gol, nu o eroare la desen
            local v: any = p.village
            local function tableOr(value: unknown): { [any]: any }
                return if typeof(value) == "table" then value :: { [any]: any } else {}
            end
            local rawStations = tableOr(v.stations)
            local hands: { VillageLook.HandSnap } = {}
            for _, hand in tableOr(v.hands) do
                if
                    typeof(hand) == "table"
                    and typeof(hand.id) == "string"
                    and typeof(hand.role) == "string"
                    and typeof(hand.appearance) == "table"
                then
                    table.insert(hands, {
                        id = hand.id,
                        role = hand.role,
                        name = if typeof(hand.name) == "string" then hand.name else "",
                        index = if typeof(hand.index) == "number" then hand.index else 1,
                        count = if typeof(hand.count) == "number" then hand.count else 1,
                        tier = if typeof(hand.tier) == "number" then hand.tier else 1,
                        nets = tableOr(hand.nets),
                        cycleStartAt = if typeof(hand.cycleStartAt) == "number"
                            then hand.cycleStartAt
                            else 0,
                        carrying = if typeof(hand.carrying) == "number" then hand.carrying else 0,
                        carryKind = if typeof(hand.carryKind) == "string"
                            then hand.carryKind
                            else nil,
                        capacity = if typeof(hand.capacity) == "number" then hand.capacity else 0,
                        appearance = hand.appearance,
                        x = if typeof(hand.x) == "number" then hand.x else nil,
                        y = if typeof(hand.y) == "number" then hand.y else nil,
                    })
                end
            end
            local village: VillageLook.Snapshot = {
                era = host.era,
                pads = tableOr(v.pads),
                netLevels = tableOr(v.netLevels),
                stations = {
                    saw = if typeof(rawStations.saw) == "number" then rawStations.saw else 1,
                    dock = if typeof(rawStations.dock) == "number" then rawStations.dock else 1,
                    forge = if typeof(rawStations.forge) == "number" then rawStations.forge else 1,
                },
                crews = tableOr(v.crews),
                tiers = tableOr(v.tiers), -- [D62] treapta meseriilor, pentru bulinele de sub case
                hands = hands,
                decor = tableOr(v.decor),
                decorCount = host.decor,
            }
            enter(host, village)
        end
    )

    d.Remotes.VisitLikeResult.OnClientEvent:Connect(
        function(ok: unknown, reason: unknown, likes: unknown)
            likePending = false
            local host = visiting
            if host == nil then
                return
            end
            if typeof(likes) == "number" then
                host.likes = likes
            end
            if ok == true then
                host.liked = true
                SoundController.Play("chime")
                d.OnToast(Strings.visitLikeGiven(host.name), Theme.COLOR.gold)
            else
                local why = if typeof(reason) == "string" then reason else ""
                if why == "already" then
                    host.liked = true
                end
                d.OnToast(Strings.visitRefused(why), Theme.COLOR.bad)
            end
            showBanner()
        end
    )

    -- gazda afla pe loc cine i-a dat like
    d.Remotes.VisitLiked.OnClientEvent:Connect(function(visitorName: unknown)
        if typeof(visitorName) == "string" then
            SoundController.Play("chime")
            d.OnToast(Strings.visitLikedToast(visitorName), Theme.COLOR.gold)
        end
    end)

    -- machetele (si lista, cat panoul e deschis) se reimprospateaza singure; in vizita nu cerem nimic
    local lastAsked = os.clock()
    d.Remotes.VisitList:FireServer()
    RunService.Heartbeat:Connect(function()
        if visiting ~= nil then
            return
        end
        local every = if open then LIST_EVERY_OPEN else LIST_EVERY
        if os.clock() - lastAsked >= every then
            lastAsked = os.clock()
            d.Remotes.VisitList:FireServer()
        end
    end)

    Panels.Register("visit", { isOpen = VisitController.IsOpen, close = VisitController.Close })
end

return VisitController
