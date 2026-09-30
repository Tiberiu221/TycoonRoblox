--!strict
-- Meniul UNUI obiect [owner, 2026-09-12: "cand dau click pe ceva sa am meniu special al obiectului
-- pentru upgrade, nu sa am toate upgrade-urile intr-un singur meniu"]. Doua feluri, aceeasi fereastra:
--   * o CLADIRE (plasa, gater, taverna): nivel fara capat, x1/x10/Max;
--   * o MESERIE (Collector, Porter, Sawyer, Hauler, Innkeeper [D49]; Scrap Collector, Scrap Porter, Smelter,
--     Iron Hauler [D56]): treapta 1-5 si al doilea om.
-- Il deschide obiectul atins, un om atins, cardul de la apropiere, `Go!` sau butonul "Go to" de aici.
--
-- SIMPLU, CITIT DINTR-O PRIVIRE [D52]. Owner-ul, pe varianta cu sase pastile de lant si debite pe
-- secunda: "nu prea inteleg nimic din ele daca inchid un ochi". De sus in jos, cate o intrebare:
--   nivelul        -- unde sunt si unde ajung cu cumparatura aleasa
--   caseta         -- ce face obiectul si CAT, pe minut: acum -> dupa (pe secunda, +3% iesea "+0.0")
--   randul mic     -- urmatorul prag (cladire) sau cine face treaba (meserie) [D43]
--   randul colorat -- merita ACUM? Verde: cat castigi pe minut. Portocaliu: cine tine venitul in loc,
--                     cu butonul care te duce acolo. Din castigul real trimis de server, nu din
--                     "veriga slaba": la egalitate intre doua verigi, aia ar fi mintit [D40]
--   butonul        -- cat costa, scris chiar pe el
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local ChainMath = require(ReplicatedStorage.Shared.Modules.ChainMath)
local HeldBack = require(ReplicatedStorage.Shared.Modules.HeldBack)
local StationConfig = require(ReplicatedStorage.Shared.Config.StationConfig)
local EraWords = require(ReplicatedStorage.Shared.Modules.EraWords)
local Strings = require(ReplicatedStorage.Shared.Config.Strings)
local TycoonConfig = require(ReplicatedStorage.Shared.Config.TycoonConfig)
local TycoonMath = require(ReplicatedStorage.Shared.Modules.TycoonMath)
local Panels = require(script.Parent.Panels)
local SoundController = require(script.Parent.SoundController)
local Pop = require(script.Parent.Parent.UI.Pop)
local Theme = require(script.Parent.Parent.UI.Theme)
local Widgets = require(script.Parent.Parent.UI.Widgets)

export type Row = {
    kind: string,
    id: string?,
    name: string,
    level: number,
    output: number,
    nextOutput: number,
    nextMilestone: number?,
    costs: { number },
    maxCount: number,
    maxCost: number,
    bottleneck: boolean,
    gain: number, -- [D52] cat creste venitul cu un nivel aici; 0 = nu aduce nimic pe loc
    line: string?, -- [D56] "wood" | "iron"; nil = taverna
}

export type CrewRow = {
    role: string,
    name: string,
    plural: string,
    pad: string,
    count: number,
    tier: number,
    maxTier: number,
    maxPeople: number,
    output: number,
    nextOutput: number?,
    secondOutput: number?,
    tierCost: number?,
    tierGain: number,
    tierBlock: string?,
    secondPrice: number?,
    secondGain: number,
    hireBlock: string?,
    tierAffordable: boolean,
    secondAffordable: boolean,
    maxed: boolean,
    bottleneck: boolean,
    line: string?, -- [D56]
}

export type Snapshot = {
    rows: { Row },
    crews: { CrewRow },
    bottleneck: string,
    -- [D65] vederea pe linii (HeldBack.View): veriga slaba a fiecarei linii ("" = inca inchisa) si debitul verigilor
    lines: { [string]: HeldBack.LineView },
    linkRates: { [string]: number },
    playerShare: number,
}

export type Deps = {
    HudGui: Frame,
    Remotes: {
        UpgradeStation: RemoteEvent,
        UpgradeCrew: RemoteEvent,
        UpgradeRejected: RemoteEvent,
    },
    OnToast: (string, Color3?) -> (),
    -- [2026-09-30] platforma e cumparata (PadController): un clopot tras nu mai e trimis ca pas urmator
    IsBought: ((padId: string) -> boolean)?,
}

local StationMenu = {}
local deps: Deps
local window: Frame
local open = false
local target: { kind: string, id: string? }? = nil
local lastSnapshot: Snapshot? = nil
local bulkIndex = 1

-- Corpul iese 560x336; cutiile: scripts/art/check_panel_rows.py (STATION_MENU).
local PANEL_W, PANEL_H = 600, 432
local Z = 62
local BODY_W = PANEL_W - Theme.SPACE.lg * 2
local BOX_Y, BOX_H = 36, 104
local SUB_Y = 148
-- [D62] bara spre pragul urmator, in golul dintre randul pragului (148-168) si randul colorat (176)
local BAR_Y, BAR_H = 169, 5
local STATUS_Y, STATUS_H = 176, 44
local GO_W = 200
local GREY = Color3.fromRGB(150, 144, 136)

-- x1, x10, Max. Pasul de 50 ramane pe server (StationConfig.BULK_STEPS si `row.costs`), dar meniul
-- simplu nu-l mai arata; `step` e indexul in BULK_STEPS/costs, nil = "Max". Eticheta si pasul stau in
-- ACEEASI intrare: tinute separat, scoaterea lui x50 ar fi facut "Max" sa cumpere pasul de 50.
type Bulk = { label: string, step: number? }
local BULK: { Bulk } = {
    { label = "x1", step = 1 },
    { label = "x10", step = 2 },
    { label = "Max", step = nil },
}

-- Verigile, in ordinea StationConfig.LINKS: ce meniu o repara ("Go to"). Omul unui atelier si al unui vanzator imparte
-- veriga cu cladirea lui: "Go to" duce la cladire, al carei nivel e reparatia. Plasele sunt ale tuturor liniilor.
-- [D65] Din tabelul liniilor, pentru orice era: pana aici lista era scrisa de mana, cu cele zece verigi ale Erei 1.
type Link = { key: string, kind: string, role: string?, icon: string }
local WALK_ICONS = { "capacity", "carry", "hammer", "speed" } -- dupa locul pasului in linie: aduna, cara, (atelier), duce
local CHAIN: { Link } = { { key = "nets", kind = "net", icon = "net" } }
-- omul cladirii (Sawyer, Smelter, Founder...; Innkeeper, Merchant): fara el, cladirea merge doar cu tine / incet
local ROLE_OF_BUILDING: { [string]: string } = {}
for _, line in StationConfig.LINE_ORDER do
    for k, step in StationConfig.LINES[line].steps do
        if step.kind == "processor" then
            ROLE_OF_BUILDING[step.link] = step.role
            table.insert(CHAIN, {
                key = step.link,
                kind = step.link,
                icon = if step.link == "saw" then "saw" else "hammer",
            })
        else
            table.insert(CHAIN, {
                key = step.link,
                kind = "crew",
                role = step.role,
                icon = WALK_ICONS[k] or "carry",
            })
        end
    end
end
for _, seller in StationConfig.SELLER_ORDER do
    ROLE_OF_BUILDING[seller] = StationConfig.SELLERS[seller].role
    table.insert(CHAIN, { key = seller, kind = seller, icon = "crate" })
end
local LINK_OF_ROLE: { [string]: string } = StationConfig.LINK_OF

local levelLabel: TextLabel
local captionLabel: TextLabel
local rateLabel: TextLabel
local unitLabel: TextLabel
local subLabel: TextLabel
-- [D62] Drumul pana la pragul urmator (10, 25, 50...), unde debitul se dubleaza: o tinta apropiata, care se vede
-- umplandu-se la fiecare nivel cumparat. `milestoneFlashUntil`: cat randul pragului spune ca tocmai l-ai trecut.
local milestoneTrack: Frame
local milestoneFill: Frame
local milestoneFlashUntil = 0
local milestoneFlashText = ""
local statusLabel: TextLabel
local goButton: TextButton
local goLink: Link? = nil
local goLine: string? = nil -- [D56] "Go to Nets": plasele carei linii
-- cladire
local buildingGroup: { GuiObject } = {}
local bulkButtons: { TextButton } = {}
local upgradeButton: TextButton
-- meserie
local crewGroup: { GuiObject } = {}
local tierButton: TextButton
local hireButton: TextButton

local function linkByKey(key: string): Link
    for _, c in CHAIN do
        if c.key == key then
            return c
        end
    end
    return CHAIN[1]
end

local function findRow(): Row?
    local snap, t = lastSnapshot, target
    if snap == nil or t == nil or t.kind == "crew" then
        return nil
    end
    for _, row in snap.rows do
        if row.kind == t.kind and (t.id == nil or row.id == t.id) then
            return row
        end
    end
    return nil
end

local function findCrew(role: string?): CrewRow?
    local snap = lastSnapshot
    if snap == nil or role == nil then
        return nil
    end
    for _, c in snap.crews do
        if c.role == role then
            return c
        end
    end
    return nil
end

local function targetExists(): boolean
    local t = target
    if t == nil then
        return false
    end
    if t.kind == "crew" then
        return findCrew(t.id) ~= nil
    end
    return findRow() ~= nil
end

local function countFor(row: Row): number
    local step = BULK[bulkIndex].step
    if step == nil then
        return row.maxCount
    end
    return StationConfig.BULK_STEPS[step] or 1
end

-- Pretul afisat pe buton. "Max" fara niciun nivel platibil arata pretul unui singur nivel, in rosu:
-- un "0" ar fi parut gratis.
local function costFor(row: Row, count: number): number
    local step = BULK[bulkIndex].step
    if step == nil then
        return if count >= 1 then row.maxCost else row.costs[1] or 0
    end
    return row.costs[step] or 0
end

local function setGroup(group: { GuiObject }, visible: boolean)
    for _, g in group do
        g.Visible = visible
    end
end

-- Felul cladirii (net/saw/dock) nu e acelasi cuvant cu veriga lantului (nets/saw/dock).
local function linkKeyOf(kind: string): string
    return if kind == "net" then "nets" else kind
end

-- Unitatea de sub cifra mare, dupa veriga si linia ei; un vanzator numara marfa primei lui linii (taverna: scanduri).
local function unitOf(link: string, line: string?): string
    local seller = StationConfig.SELLERS[link]
    if seller ~= nil then
        for _, l in StationConfig.LINE_ORDER do
            if StationConfig.LINES[l].seller == link then
                return Strings.menuUnit(l, false)
            end
        end
    end
    return Strings.menuUnit(line, link == "nets" or StationConfig.BEFORE_PROCESSOR[link] == true)
end

-- Un echipaj la maxim pe veriga slaba: textul vine din EraWords (acelasi in panoul Upgrades) [2026-09-30].
local function maxedText(plural: string, padId: string): string
    local isBought = deps.IsBought
    return EraWords.maxedCrew(plural, padId, function(id: string): boolean
        return isBought ~= nil and isBought(id)
    end)
end

-- Debitul dupa `count` niveluri. Debitul unei cladiri e proportional cu ChainMath.levelOutput (oamenii
-- doar il inmultesc), deci raportul e exact -- si pentru x10 sau Max, nu doar pentru +1.
local function outputAfter(row: Row, count: number): number
    if count <= 1 then
        return row.nextOutput
    end
    local kind = linkKeyOf(row.kind)
    local now = ChainMath.levelOutput(1, row.level, kind)
    if now <= 0 then
        return row.nextOutput
    end
    return row.output * ChainMath.levelOutput(1, row.level + count, kind) / now
end

-- Castigul pe minut, scris; nil cand e prea mic pentru o zecimala (textul spune "a little more").
local function perMinuteGain(gain: number): string?
    local text = TycoonMath.formatPerMinute(gain)
    return if text == "0" then nil else text
end

-- Randul colorat se rupe pe doua randuri; la marimea 18, doua randuri de Nunito au 49 si randul are 44, deci textul
-- lung trecea de marginile lui [2026-09-15]. Se alege cea mai mare marime la care incape.
local function fitStatusText()
    local width = BODY_W - GO_W - 12
    local size = Theme.TEXT.body
    while
        size > Theme.TEXT.small
        and Theme.textHeight(statusLabel.Text, size, "body", width) > STATUS_H
    do
        size -= 1
    end
    statusLabel.TextSize = size
end

local function showStatus(text: string, color: Color3)
    statusLabel.Text = text
    fitStatusText()
    statusLabel.TextColor3 = color
    goLink = nil
    goLine = nil
    goButton.Visible = false
end

local function showHeldBack(snap: Snapshot, mine: string, line: string?)
    -- [D63] cine il tine pe loc: aceeasi regula ca in panoul Upgrades si pe cartonasul platformei (HeldBack)
    local key, tie = HeldBack.by(snap, mine, line)
    if key == nil then
        -- [D56] Forge fara plasa de scrap: nu e o veriga de reparat, doar nu vine inca nimic
        showStatus(Strings.lineNotOpen(line), Theme.COLOR.warnInk)
        return
    end
    local link = linkByKey(key)
    -- plasele carei linii: a obiectului; de la un vanzator, a liniei lui in care plasele tin
    local netsLine = HeldBack.netsLine(snap, line, mine)
    statusLabel.Text = Strings.menuHeldBack(link.key, tie, netsLine)
    fitStatusText()
    statusLabel.TextColor3 = Theme.COLOR.warnInk
    goLink = link
    goLine = netsLine
    Widgets.SetButtonText(goButton, Strings.menuGoTo(link.key))
    goButton.Visible = true
end

local function renderBuilding(row: Row, snap: Snapshot)
    local mineKey = linkKeyOf(row.kind)
    Widgets.SetWindowTitle(window, row.name, linkByKey(mineKey).icon, "hammer")
    setGroup(crewGroup, false)
    setGroup(buildingGroup, true)

    local count = countFor(row)
    local shown = math.max(1, count) -- "Max" fara niciun nivel platibil arata urmatorul nivel
    local affordable = count >= 1 and row.maxCount >= count
    levelLabel.Text = Strings.menuLevelStep(row.level, row.level + shown)

    -- cladirea are om? (gaterul Sawyer, forja Smelter, taverna Innkeeper; la fel cladirile Morii)
    local staffed = true
    local keeper = ROLE_OF_BUILDING[row.kind]
    if keeper ~= nil then
        local crew = findCrew(keeper)
        staffed = crew ~= nil and crew.count > 0
    end
    local words = TycoonConfig.wordsKindOf(row.kind, row.id)
    captionLabel.Text = Strings.menuDoes(words, staffed)
    local now = TycoonMath.formatPerMinute(row.output)
    rateLabel.Text = `{now} → {TycoonMath.formatPerMinute(outputAfter(row, shown))}`
    -- [D56] plasa de scrap prinde scrap, nu busteni
    unitLabel.Text = unitOf(mineKey, row.line)

    local milestone = row.nextMilestone
    if os.clock() < milestoneFlashUntil then
        subLabel.Text = milestoneFlashText
        subLabel.TextColor3 = Theme.COLOR.goodInk
    else
        subLabel.Text = if milestone ~= nil
            then Strings.menuMilestone(words, milestone, StationConfig.MILESTONE_MULT)
            else ""
        subLabel.TextColor3 = Theme.COLOR.inkSoft
    end
    -- bara: de la pragul dinainte (sau nivelul 1) pana la urmatorul
    milestoneTrack.Visible = milestone ~= nil
    if milestone ~= nil then
        local from = 1
        for _, m in StationConfig.MILESTONES do
            if m <= row.level then
                from = m
            end
        end
        local share = math.clamp((row.level - from) / math.max(1, milestone - from), 0, 1)
        TweenService:Create(
            milestoneFill,
            TweenInfo.new(0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
            { Size = UDim2.fromScale(share, 1) }
        ):Play()
    end

    if row.gain > 0 then
        showStatus(Strings.menuEarnsLevel(perMinuteGain(row.gain)), Theme.COLOR.goodInk)
    else
        showHeldBack(snap, mineKey, row.line)
    end

    for i, b in bulkButtons do
        Widgets.SetButtonTone(b, if i == bulkIndex then Theme.COLOR.gold else nil)
    end
    Widgets.SetButtonText(upgradeButton, Strings.menuUpgradeCount(shown))
    Widgets.SetButtonPrice(
        upgradeButton,
        TycoonMath.formatNumber(costFor(row, count)),
        if affordable then Theme.COLOR.ink else Theme.COLOR.badInk
    )
    Widgets.SetButtonTone(upgradeButton, if affordable then Theme.COLOR.gold else GREY)
end

-- Un buton de meserie: eticheta (sau motivul blocarii), pretul pe el si tonul.
local function renderCrewButton(
    button: TextButton,
    what: string,
    price: number?,
    affordable: boolean,
    block: string?
)
    Widgets.SetButtonText(button, Strings.menuCrewButton(what, block, StationConfig.SECOND_AT_TIER))
    if price == nil then
        Widgets.SetButtonPrice(button, nil)
        Widgets.SetButtonTone(button, GREY)
    else
        Widgets.SetButtonPrice(
            button,
            TycoonMath.formatNumber(price),
            if affordable then Theme.COLOR.ink else Theme.COLOR.badInk
        )
        Widgets.SetButtonTone(button, if affordable then Theme.COLOR.gold else GREY)
    end
end

local function renderCrew(crew: CrewRow, snap: Snapshot)
    local mineKey = LINK_OF_ROLE[crew.role] or "collect"
    Widgets.SetWindowTitle(window, crew.name, linkByKey(mineKey).icon, "people")
    setGroup(buildingGroup, false)
    setGroup(crewGroup, true)

    levelLabel.Text = Strings.menuTierLine(crew.tier, crew.maxTier, crew.count, crew.maxPeople)
    captionLabel.Text = Strings.crewDoes(crew.role)
    local now = TycoonMath.formatPerMinute(crew.output)
    local after = crew.nextOutput
    rateLabel.Text = if crew.count > 0 and after ~= nil
        then `{now} → {TycoonMath.formatPerMinute(after)}`
        else now
    unitLabel.Text = unitOf(mineKey, crew.line)

    -- cine face treaba: omul angajat, sau tu [D43]. Aici se vede ce ti-a luat o angajare care, cu o
    -- singura plasa, nu misca venitul [D52].
    if crew.count == 0 then
        subLabel.Text = Strings.crewNone(crew.role, crew.name)
        subLabel.TextColor3 = Theme.COLOR.badInk
    else
        subLabel.Text = Strings.crewWorking(crew.count, crew.name, crew.plural)
        subLabel.TextColor3 = Theme.COLOR.inkSoft
    end

    if crew.count == 0 then
        showStatus(Strings.crewBlock("no_person", StationConfig.SECOND_AT_TIER), Theme.COLOR.ink)
    elseif crew.maxed and crew.bottleneck then
        -- ECHIPAJ LA MAXIM PE VERIGA SLABA: nimic de cumparat aici -- trimite la clopot [D40, D49]
        showStatus(maxedText(crew.plural, crew.pad), Theme.COLOR.warnInk)
    elseif crew.tierGain > 0 then
        showStatus(Strings.menuEarnsTier(perMinuteGain(crew.tierGain)), Theme.COLOR.goodInk)
    elseif crew.secondGain > 0 then
        showStatus(
            Strings.menuEarnsSecond(crew.name, perMinuteGain(crew.secondGain)),
            Theme.COLOR.goodInk
        )
    else
        showHeldBack(snap, mineKey, crew.line)
    end

    renderCrewButton(tierButton, "tier", crew.tierCost, crew.tierAffordable, crew.tierBlock)
    renderCrewButton(hireButton, "hire", crew.secondPrice, crew.secondAffordable, crew.hireBlock)
end

local function render()
    local snap, t = lastSnapshot, target
    if snap == nil or t == nil then
        return
    end
    if t.kind == "crew" then
        local crew = findCrew(t.id)
        if crew ~= nil then
            renderCrew(crew, snap)
        end
        return
    end
    local row = findRow()
    if row ~= nil then
        renderBuilding(row, snap)
    end
end

function StationMenu.IsOpen(): boolean
    return open
end

function StationMenu.Close()
    open = false
    window.Visible = false
end

-- Muta meniul pe alt obiect fara sa-l inchida ("Go to"). Intoarce false daca obiectul nu are ce
-- arata (o plasa necumparata).
local function retarget(kind: string, id: string?): boolean
    local previous = target
    milestoneFlashUntil = 0 -- "Level 10 reached!" e al obiectului de dinainte
    target = { kind = kind, id = id }
    if not targetExists() then
        target = previous
        return false
    end
    render()
    return true
end

-- Deschide meniul pe o cladire sau pe o meserie ("crew", rol). A doua atingere pe ACELASI obiect il
-- inchide; pe altul, il muta.
function StationMenu.OpenAt(kind: string, id: string?)
    local t = target
    if open and t ~= nil and t.kind == kind and t.id == id then
        StationMenu.Close()
        return
    end
    if not Panels.CanOpen("station") then
        return
    end
    local previous = target
    milestoneFlashUntil = 0
    target = { kind = kind, id = id }
    if not targetExists() then
        target = previous
        return -- statia inca nu e a ta (o plasa necumparata): n-ai ce urca
    end
    Panels.CloseOthers("station")
    open = true
    window.Visible = true
    SoundController.Play("click")
    render()
end

-- [D62] Serverul a confirmat un nivel (sau o treapta) pe obiectul deschis: cifra de sus sare, iar la un prag randul
-- lui spune cateva secunde ce s-a dublat. Lumea are efectul ei (Overlay); meniul sta de obicei peste obiect, deci
-- fara asta cumparatura nu s-ar vedea deloc cat e deschis.
function StationMenu.OnUpgraded(kind: string, id: string?, milestone: number?)
    local t = target
    if not open or t == nil or t.kind ~= kind or (kind == "net" and t.id ~= id) then
        return
    end
    Pop.play(levelLabel, 1.12, 0.3)
    Pop.play(rateLabel, 1.08, 0.3)
    if milestone ~= nil then
        milestoneFlashText = Strings.menuMilestoneDone(
            TycoonConfig.wordsKindOf(kind, id),
            milestone,
            StationConfig.MILESTONE_MULT
        )
        milestoneFlashUntil = os.clock() + 3
        render()
        task.delay(3.1, function()
            if open then
                render()
            end
        end)
    end
end

function StationMenu.OnCrewUpgraded(role: string)
    local t = target
    if open and t ~= nil and t.kind == "crew" and t.id == role then
        Pop.play(levelLabel, 1.12, 0.3)
        Pop.play(rateLabel, 1.08, 0.3)
    end
end

function StationMenu.Apply(snap: Snapshot?)
    if snap == nil then
        return
    end
    lastSnapshot = snap
    if not open then
        return
    end
    if not targetExists() then
        StationMenu.Close()
        return
    end
    render()
end

local function label(
    parent: Instance,
    text: string,
    size: number,
    color: Color3,
    kind: string
): TextLabel
    local l = Widgets.Label(parent, text, size, color, kind)
    l.ZIndex = Z + 3
    return l
end

-- "Go to": duce meniul pe veriga care tine venitul in loc -- cladirea, sau meseria care o tine. Pe o
-- meserie fara om, meniul ei spune "Hire one at its pad", nu arata un buton mort [D52]. [D56] La plase: prima
-- plasa a liniei (`line`), nu prima plasa oarecare.
local function openLink(c: Link, line: string?)
    local snap = lastSnapshot
    if snap == nil then
        return
    end
    local ok = false
    if c.kind == "crew" then
        ok = retarget("crew", c.role)
    elseif c.kind == "net" then
        for _, row in snap.rows do
            if row.kind == "net" and (line == nil or row.line == line) then
                ok = retarget("net", row.id)
                break
            end
        end
    else
        ok = retarget(c.kind, nil)
    end
    if ok then
        SoundController.Play("click")
    end
end

function StationMenu.Init(d: Deps)
    deps = d
    local root, body = Widgets.Window(deps.HudGui, {
        name = "StationMenu",
        title = "",
        icon = "net",
        width = PANEL_W,
        height = PANEL_H,
        z = Z,
        onClose = StationMenu.Close,
    })
    window = root
    window.AnchorPoint = Vector2.new(0.5, 0.5)
    window.Position = UDim2.fromScale(0.5, 0.5)
    window.Visible = false

    -- 1. nivelul (la meserie: treapta si oamenii)
    -- ancorate la mijlocul inaltimii: saltul de la un nivel cumparat (Pop) creste din locul textului, nu din colt
    levelLabel = label(body, "", Theme.TEXT.heading, Theme.COLOR.ink, "display")
    levelLabel.AnchorPoint = Vector2.new(0, 0.5)
    levelLabel.Position = UDim2.fromOffset(0, 14)
    levelLabel.Size = UDim2.fromOffset(BODY_W, 28)

    -- 2. caseta: ce face si cat, pe minut
    local box = Widgets.Slot(body, Z + 2)
    box.Name = "Output"
    box.Position = UDim2.fromOffset(0, BOX_Y)
    box.Size = UDim2.fromOffset(BODY_W, BOX_H)
    captionLabel = label(box, "", Theme.TEXT.small, Theme.COLOR.inkSoft, "body")
    captionLabel.Position = UDim2.fromOffset(16, 10)
    captionLabel.Size = UDim2.fromOffset(BODY_W - 32, 20)
    rateLabel = label(box, "", Theme.TEXT.title, Theme.COLOR.ink, "display")
    rateLabel.AnchorPoint = Vector2.new(0, 0.5)
    rateLabel.Position = UDim2.fromOffset(16, 32 + 19)
    rateLabel.Size = UDim2.fromOffset(BODY_W - 32, 38)
    unitLabel = label(box, "", Theme.TEXT.small, Theme.COLOR.inkSoft, "body")
    unitLabel.Position = UDim2.fromOffset(16, 74)
    unitLabel.Size = UDim2.fromOffset(BODY_W - 32, 20)

    -- 3. pragul urmator (cladire) sau cine face treaba (meserie)
    subLabel = label(body, "", Theme.TEXT.small, Theme.COLOR.inkSoft, "body")
    subLabel.Position = UDim2.fromOffset(0, SUB_Y)
    subLabel.Size = UDim2.fromOffset(BODY_W, 20)

    milestoneTrack, milestoneFill = Widgets.Bar(body, BODY_W, BAR_H, Theme.COLOR.gold, Z + 3)
    milestoneTrack.Position = UDim2.fromOffset(0, BAR_Y)
    milestoneFill.Size = UDim2.fromScale(0, 1)
    table.insert(buildingGroup, milestoneTrack)

    -- 4. randul colorat si "Go to"
    statusLabel = label(body, "", Theme.TEXT.body, Theme.COLOR.ink, "body")
    statusLabel.Position = UDim2.fromOffset(0, STATUS_Y)
    statusLabel.Size = UDim2.fromOffset(BODY_W - GO_W - 12, STATUS_H)
    statusLabel.TextWrapped = true
    statusLabel.TextYAlignment = Enum.TextYAlignment.Center
    goButton = Widgets.Button(body, {
        text = "",
        width = GO_W,
        height = STATUS_H,
        z = Z + 3,
        onClick = function()
            local link = goLink
            if link ~= nil then
                openLink(link, goLine)
            end
        end,
    })
    goButton.Position = UDim2.fromOffset(BODY_W - GO_W, STATUS_Y)
    goButton.Visible = false

    -- 5a. cladirea: x1 / x10 / Max si butonul mare, cu pretul pe el
    for i, bulk in BULK do
        local b = Widgets.Button(body, {
            text = bulk.label,
            width = 84,
            height = 36,
            z = Z + 3,
            onClick = function()
                bulkIndex = i
                SoundController.Play("click")
                render()
            end,
        })
        b.Position = UDim2.fromOffset((i - 1) * 92, 232)
        Widgets.SetButtonTone(b, if i == bulkIndex then Theme.COLOR.gold else nil)
        bulkButtons[i] = b
        table.insert(buildingGroup, b)
    end
    upgradeButton = Widgets.Button(body, {
        text = Strings.STATION_UPGRADE,
        icon = "levelup",
        width = BODY_W,
        height = 56,
        z = Z + 3,
        price = true,
        onClick = function()
            local row = findRow()
            if row == nil then
                return
            end
            local count = countFor(row)
            if count < 1 then
                deps.OnToast(Strings.STATION_NEED_MORE, Theme.COLOR.bad)
                return
            end
            SoundController.Play("click")
            deps.Remotes.UpgradeStation:FireServer(row.kind, row.id, count)
        end,
    })
    upgradeButton.Position = UDim2.fromOffset(0, 280)
    table.insert(buildingGroup, upgradeButton)

    -- 5b. meseria: treapta si al doilea om, fiecare cu pretul pe buton
    local function crewBuy(what: string)
        local t = target
        local crew = if t ~= nil then findCrew(t.id) else nil
        if crew == nil then
            return
        end
        local price = if what == "tier" then crew.tierCost else crew.secondPrice
        if price == nil then
            local block = if what == "tier" then crew.tierBlock else crew.hireBlock
            deps.OnToast(Strings.crewBlock(block, StationConfig.SECOND_AT_TIER), Theme.COLOR.bad)
            return
        end
        SoundController.Play("click")
        deps.Remotes.UpgradeCrew:FireServer(crew.role, what)
    end
    tierButton = Widgets.Button(body, {
        text = Strings.MENU_TIER_UP,
        icon = "levelup",
        width = BODY_W,
        height = 50,
        z = Z + 3,
        price = true,
        onClick = function()
            crewBuy("tier")
        end,
    })
    tierButton.Position = UDim2.fromOffset(0, 228)
    table.insert(crewGroup, tierButton)
    hireButton = Widgets.Button(body, {
        text = "",
        icon = "people",
        width = BODY_W,
        height = 50,
        z = Z + 3,
        price = true,
        onClick = function()
            crewBuy("hire")
        end,
    })
    hireButton.Position = UDim2.fromOffset(0, 286)
    table.insert(crewGroup, hireButton)
    setGroup(crewGroup, false)

    -- Refuzurile se anunta O SINGURA DATA, de aici (si pentru cladiri, si pentru meserii).
    deps.Remotes.UpgradeRejected.OnClientEvent:Connect(function(reason: string)
        deps.OnToast(Strings.upgradeRejected(reason), Theme.COLOR.bad)
    end)

    Panels.Register("station", { isOpen = StationMenu.IsOpen, close = StationMenu.Close })
end

return StationMenu
