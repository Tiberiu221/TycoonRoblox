--!strict
-- Lista de quest-uri. Copiaza panoul din Idle Miner [poza 4 si 12]: titlul capitolului cu bara lui,
-- apoi quest-urile -- terminate sus cu butonul auriu `Claim`, activul cu `Go!`, restul `Quest locked` cu
-- lacat. [owner, 2026-09-14] Cele revendicate coboara la coada (QuestMath.displayOrder), iar recompensa nu mai
-- e un rand de text: sta pe buton, "Claim 1 (perla)".
--
-- `Go!` NU teleporteaza: inchide panoul si lasa quest-ul sa fie obiectivul sagetii (GuideMath
-- regula 0). La noi mergi pe mal -- asta e diferenta fata de ei, si e a noastra.
-- `Claim` se APASA. N-ar costa nimic sa dam recompensa singuri, dar apasatul ala e mica rasplata
-- fizica de la capatul unei sarcini, si daca o automatizam se pierde.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Strings = require(ReplicatedStorage.Shared.Config.Strings)
local TycoonMath = require(ReplicatedStorage.Shared.Modules.TycoonMath)
local QuestConfig = require(ReplicatedStorage.Shared.Config.QuestConfig)
local QuestMath = require(ReplicatedStorage.Shared.Modules.QuestMath)

local Panels = require(script.Parent.Panels)
local SoundController = require(script.Parent.SoundController)
local Theme = require(script.Parent.Parent.UI.Theme)
local Widgets = require(script.Parent.Parent.UI.Widgets)

export type QuestState = {
    id: string,
    text: string,
    progress: number,
    goal: number,
    state: string,
    reward: { coins: number?, pearls: number? },
}

export type Snapshot = {
    chapter: { id: string, title: string, subtitle: string },
    quests: { QuestState },
    completed: number,
    total: number,
    claimable: number,
    active: { id: string, text: string, progress: number, goal: number }?,
}

export type Deps = {
    HudGui: Frame,
    Remotes: { ClaimQuest: RemoteEvent, QuestRejected: RemoteEvent, QuestClaimed: RemoteEvent },
    -- [D62] perlele revendicate zboara de la butonul Claim spre contor (JuiceController.PearlFly, in coordonatele
    -- panzei HUD); capitolul incheiat are bannerul lui (CeremonyController.PlayMoment)
    PearlFly: ((number, number, number) -> ())?,
    OnChapterDone: ((string, string) -> ())?,
    OnToast: (string, Color3?) -> (),
    -- Go! la un quest de nivel deschide panoul de niveluri pe statia lui; dat din Bootstrap
    OpenStation: ((string, string?) -> ())?,
}

local QuestController = {}
local deps: Deps
-- [D62] de pe ce rand s-a apasat Claim pentru fiecare quest: de acolo pleaca perlele cand serverul confirma
local claimedFrom: { [string]: number } = {}
local window: Frame
local open = false
local lastSnapshot: Snapshot? = nil

local PANEL_W, PANEL_H = 560, 520
-- [owner, 2026-09-14] 60, nu 74: randul "Reward: 1 pearl" a iesit, recompensa sta pe butonul Claim.
-- Cutiile: scripts/art/check_panel_rows.py (QUEST_ROW).
local ROW_H = 60
local BUTTON_W = 130
local Z = 65

local chapterTitle: TextLabel
local chapterCount: TextLabel
local chapterFill: Frame
local list: ScrollingFrame

type RowView = {
    frame: Frame,
    text: TextLabel,
    counter: TextLabel,
    fill: Frame,
    track: Frame,
    button: TextButton,
    lock: TextLabel,
    lockIcon: ImageLabel?,
}

local views: { RowView } = {}
-- Randurile in ordinea din panou: butonul unui rand citeste de aici, nu din ordinea capitolului.
local shown: { QuestState } = {}

local function buildRow(index: number): RowView
    local frame = Instance.new("Frame")
    frame.Name = `Quest{index}`
    frame.BackgroundTransparency = 1
    frame.Size = UDim2.new(1, 0, 0, ROW_H)
    frame.LayoutOrder = index
    frame.ZIndex = Z + 2
    frame.Parent = list
    Widgets.PillBackground(frame, Z + 2)

    local text = Widgets.Label(frame, "", Theme.TEXT.small, Theme.COLOR.onDark, "strong")
    text.Position = UDim2.fromOffset(Theme.SPACE.md, 10)
    text.Size = UDim2.fromOffset(270, 20)
    text.TextTruncate = Enum.TextTruncate.AtEnd
    text.ZIndex = Z + 3

    -- contorul se termina la 8 px inaintea butonului (mai lat cu recompensa pe el)
    local counter = Widgets.Label(frame, "", Theme.TEXT.tiny, Theme.COLOR.onDarkSoft, "display")
    counter.AnchorPoint = Vector2.new(1, 0)
    counter.Position = UDim2.fromOffset(Theme.SPACE.md + 334, 12)
    counter.Size = UDim2.fromOffset(60, 18)
    counter.TextXAlignment = Enum.TextXAlignment.Right
    counter.ZIndex = Z + 3

    local track, fill = Widgets.Bar(frame, 290, 6, Theme.COLOR.good, Z + 3)
    track.Position = UDim2.fromOffset(Theme.SPACE.md, 38)

    -- Lacatul si textul se aprind/sting impreuna: un lacat singur peste un rand gol ar arata a
    -- eroare de desen, nu a quest inchis.
    local lockIcon = Widgets.Icon(frame, "lock", 18)
    local lockX = Theme.SPACE.md
    if lockIcon ~= nil then
        lockIcon.Position = UDim2.fromOffset(Theme.SPACE.md, 21)
        lockIcon.Visible = false
        lockIcon.ZIndex = Z + 4
        lockX = Theme.SPACE.md + 24
    end

    local lock =
        Widgets.Label(frame, Strings.QUEST_LOCKED, Theme.TEXT.small, Theme.COLOR.onDarkSoft, "body")
    lock.Position = UDim2.fromOffset(lockX, 19)
    lock.Size = UDim2.fromOffset(282, 22)
    lock.Visible = false
    lock.ZIndex = Z + 4

    local button = Widgets.Button(frame, {
        text = Strings.QUEST_GO,
        width = BUTTON_W,
        height = 44,
        z = Z + 3,
        reward = true,
        onClick = function()
            local row = shown[index]
            if row == nil then
                return
            end
            if row.state == "done" then
                SoundController.Play("register")
                claimedFrom[row.id] = index
                deps.Remotes.ClaimQuest:FireServer(row.id)
            else
                SoundController.Play("click")
                -- Quest de NIVEL: Go! deschide direct panoul pe statia ceruta. Pentru el nu exista
                -- o tinta in lume spre care sa arate sageata, deci doar inchiderea listei nu ducea
                -- nicaieri -- exact de-aia owner-ul n-a gasit unde se urca nivelul.
                -- NU `local kind, id = if cfg then stationTarget(cfg) else nil, nil`: o expresie
                -- `if` da o SINGURA valoare, deci `id` ar fi iesit mereu nil.
                local cfg = QuestConfig.byId[row.id]
                local kind: string?, id: string? = nil, nil
                if cfg ~= nil then
                    kind, id = QuestMath.stationTarget(cfg)
                end
                QuestController.Close()
                if kind ~= nil and deps.OpenStation ~= nil then
                    (deps.OpenStation :: (string, string?) -> ())(kind :: string, id)
                end
                -- altfel: sageata arata tinta din lume -- nu te duce ea acolo
            end
        end,
    })
    button.AnchorPoint = Vector2.new(1, 0.5)
    button.Position = UDim2.new(1, -Theme.SPACE.md, 0.5, 0)

    return {
        frame = frame,
        text = text,
        counter = counter,
        fill = fill,
        track = track,
        button = button,
        lock = lock,
        lockIcon = lockIcon,
    }
end

-- Cifra si moneda de pe butonul Claim. Perlele intai (toate recompensele de quest sunt perle, D51); monedele doar
-- daca un quest ar da numai monede.
local function rewardOf(r: { coins: number?, pearls: number? }): (string?, string)
    if r.pearls ~= nil and r.pearls > 0 then
        return tostring(r.pearls), "pearls"
    elseif r.coins ~= nil and r.coins > 0 then
        return TycoonMath.formatNumber(r.coins), "coins"
    end
    return nil, "pearls"
end

local function refresh(snap: Snapshot)
    chapterTitle.Text = `{snap.chapter.title} — {string.upper(snap.chapter.subtitle)}`
    chapterCount.Text = `{snap.completed}/{snap.total}`
    chapterFill.Size =
        UDim2.fromScale(math.clamp(snap.completed / math.max(1, snap.total), 0, 1), 1)

    shown = QuestMath.displayOrder(snap.quests, function(q: QuestState): string
        return q.state
    end)
    for i, row in shown do
        local view = views[i]
        if view == nil then
            view = buildRow(i)
            views[i] = view
        end
        view.frame.Visible = true
        local locked = row.state == "locked"
        view.lock.Visible = locked
        local li = view.lockIcon
        if li ~= nil then
            li.Visible = locked
        end
        view.text.Visible = not locked
        view.counter.Visible = not locked
        view.track.Visible = not locked
        view.button.Visible = not locked

        if locked then
            continue
        end
        view.text.Text = row.text
        view.counter.Text = `({math.floor(row.progress)}/{row.goal})`
        view.fill.Size = UDim2.fromScale(math.clamp(row.progress / math.max(1, row.goal), 0, 1), 1)

        -- Prin Widgets, nu pe `button.Text`: acolo s-ar fi scris `Claim` PESTE eticheta `Go!` a
        -- butonului, iar auriul pe BackgroundColor3 nu se vedea deloc sub sprite.
        if row.state == "done" then
            Widgets.SetButtonText(view.button, Strings.QUEST_CLAIM)
            Widgets.SetButtonReward(view.button, rewardOf(row.reward))
            Widgets.SetButtonTone(view.button, Theme.COLOR.gold)
            view.text.TextColor3 = Theme.COLOR.onDark
        elseif row.state == "claimed" then
            view.button.Visible = false
            view.text.TextColor3 = Theme.COLOR.onDarkSoft
            view.counter.Text = Strings.QUEST_DONE
        else
            Widgets.SetButtonText(view.button, Strings.QUEST_GO)
            Widgets.SetButtonReward(view.button, nil)
            Widgets.SetButtonTone(view.button, Theme.COLOR.cool)
            view.text.TextColor3 = Theme.COLOR.onDark
        end
    end
    for i = #shown + 1, #views do
        views[i].frame.Visible = false
    end
    list.CanvasSize = UDim2.fromOffset(0, #shown * (ROW_H + Theme.SPACE.sm))
end

function QuestController.Apply(snap: Snapshot?)
    if snap == nil then
        return
    end
    lastSnapshot = snap
    if open then
        refresh(snap)
    end
end

function QuestController.IsOpen(): boolean
    return open
end

function QuestController.Close()
    open = false
    window.Visible = false
end

function QuestController.Open()
    Panels.CloseOthers("quests")
    open = true
    window.Visible = true
    SoundController.Play("click")
    if lastSnapshot ~= nil then
        refresh(lastSnapshot)
    end
end

function QuestController.Toggle()
    if open then
        QuestController.Close()
    else
        QuestController.Open()
    end
end

function QuestController.Init(d: Deps)
    deps = d
    local root, body = Widgets.Window(deps.HudGui, {
        name = "QuestPanel",
        title = Strings.QUESTS_TITLE,
        icon = "book",
        width = PANEL_W,
        height = PANEL_H,
        z = Z,
        onClose = QuestController.Close,
    })
    window = root
    -- CENTRATA. Widgets.Window nu pozitioneaza nimic -- fiecare panou isi alege locul, iar
    -- Workshop/Collection se centrau deja. Al meu ramasese in coltul stanga-sus, peste bara
    -- Roblox-ului.
    window.AnchorPoint = Vector2.new(0.5, 0.5)
    window.Position = UDim2.fromScale(0.5, 0.5)
    window.Visible = false

    chapterTitle = Widgets.Label(body, "", Theme.TEXT.body, Theme.COLOR.ink, "display")
    chapterTitle.Position = UDim2.fromOffset(0, 0)
    chapterTitle.Size = UDim2.fromOffset(400, 24)
    chapterTitle.ZIndex = Z + 1

    chapterCount = Widgets.Label(body, "", Theme.TEXT.small, Theme.COLOR.wood, "display")
    chapterCount.AnchorPoint = Vector2.new(1, 0)
    chapterCount.Position = UDim2.new(1, 0, 0, 2)
    chapterCount.Size = UDim2.fromOffset(80, 20)
    chapterCount.TextXAlignment = Enum.TextXAlignment.Right
    chapterCount.ZIndex = Z + 1

    local track, fill = Widgets.Bar(body, PANEL_W - Theme.SPACE.lg * 2, 8, Theme.COLOR.gold, Z + 1)
    track.Position = UDim2.fromOffset(0, 32)
    chapterFill = fill

    -- Widgets.List intoarce ScrollingFrame-ul DINAUNTRU; ce trebuie asezat e containerul lui.
    -- Pozitionand lista, o mutam in interiorul unui container de 0x0 -- si panoul iesea GOL.
    list = Widgets.List(body, Z + 1, Theme.SPACE.sm)
    local listHolder = list.Parent :: Frame
    listHolder.Position = UDim2.fromOffset(0, 52)
    listHolder.Size = UDim2.new(1, 0, 1, -52)

    -- [D62] Serverul a platit: perlele zboara de la butonul apasat (sau din mijlocul ferestrei) spre contor. Pozitia
    -- butonului e pe ecran; panza HUD e scalata (UIScale), deci se imparte la scara ei.
    deps.Remotes.QuestClaimed.OnClientEvent:Connect(
        function(questId: string, paid: { [string]: any })
            local pearls = if typeof(paid.pearls) == "number" then paid.pearls else 0
            local chapterPearls = if typeof(paid.chapterPearls) == "number"
                then paid.chapterPearls
                else 0
            local fly = deps.PearlFly
            local index = claimedFrom[questId]
            claimedFrom[questId] = nil
            if fly ~= nil and pearls + chapterPearls > 0 then
                local view = if index ~= nil then views[index] else nil
                local source: GuiObject = if view ~= nil and open then view.button else window
                local uiScale = deps.HudGui:FindFirstChildOfClass("UIScale")
                local s = if uiScale ~= nil then uiScale.Scale else 1
                local center = source.AbsolutePosition
                    + source.AbsoluteSize / 2
                    - deps.HudGui.AbsolutePosition
                fly(center.X / s, center.Y / s, pearls + chapterPearls)
            end
            local title, subtitle = paid.chapterTitle, paid.chapterSubtitle
            local onChapter = deps.OnChapterDone
            if onChapter ~= nil and typeof(title) == "string" and typeof(subtitle) == "string" then
                local nextSubtitle = if typeof(paid.nextSubtitle) == "string"
                    then paid.nextSubtitle
                    else nil
                onChapter(
                    Strings.chapterDone(title, subtitle),
                    Strings.chapterDoneReward(chapterPearls, nextSubtitle)
                )
            end
        end
    )

    deps.Remotes.QuestRejected.OnClientEvent:Connect(function(reason: string)
        deps.OnToast(Strings.questRejected(reason), Theme.COLOR.bad)
    end)

    Panels.Register("quests", { isOpen = QuestController.IsOpen, close = QuestController.Close })
end

return QuestController
