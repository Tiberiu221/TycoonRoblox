--!strict
-- LOCURILE UNEI LINII, DUPA TABEL [D65]: magazia (gramada, eticheta, gestul tau pe E) si atelierul (gramezile de la
-- intrare si de la iesire, inelul in care stai cat n-are om, gestul tau), plus VANZATORUL unui cartier (cladirea,
-- gramada, predarea).
--
-- Era 1 are cate un controller scris de mana pentru fiecare cladire (Storage, Shed, Sawmill, Forge, Dock), fiecare cu
-- locurile lui batute in cuie. Era 2 are aceleasi locuri pentru alte cladiri, asa ca aici e UN singur controller, care
-- isi ia totul din tabele: locurile din TycoonConfig.LINE_PLACES / SELLER_PLACES, numele locurilor si platformele care
-- le deschid din FlowConfig, cuvintele din Strings.LINE_WORDS, ce e in gramezi din `TycoonState.flow`. O era noua = o
-- linie noua in tabele si un `LineController.line(...)` in plus. Controllerele Erei 1 raman cum sunt (desenul lor a
-- fost reglat cu owner-ul); se pot muta aici cand va fi cazul.
--
-- Cladirile care sunt PLATFORME (magazia de minereu, cuptorul de cupru) le deseneaza PadController, cu ruina lor cu
-- tot, ca pe shed si pe forja. Cele care exista de cand se deschide cartierul (magazia Morii, turnatoria, Piata) se
-- deseneaza aici, din `building`.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local Assets = require(ReplicatedStorage.Shared.Config.Assets)
local DamTown = require(ReplicatedStorage.Shared.Modules.DamTown) -- [verificatorul A1] oraselul pictat (Look across)
local LOOK_ARM_SECONDS = 1.5
local FlowConfig = require(ReplicatedStorage.Shared.Config.FlowConfig)
local RiverConfig = require(ReplicatedStorage.Shared.Config.RiverConfig)
local StationConfig = require(ReplicatedStorage.Shared.Config.StationConfig)
local Strings = require(ReplicatedStorage.Shared.Config.Strings)
local TycoonConfig = require(ReplicatedStorage.Shared.Config.TycoonConfig)
local StateCopy = require(ReplicatedStorage.Shared.Modules.StateCopy)
local FlowMath = require(ReplicatedStorage.Shared.Modules.FlowMath)
local TycoonMath = require(ReplicatedStorage.Shared.Modules.TycoonMath)
local SceneArt = require(script.Parent.SceneArt)
local CustomerCrowd = require(script.Parent.Parent.UI.CustomerCrowd)
local Focus = require(script.Parent.Parent.UI.Focus)
local GroundShadow = require(script.Parent.Parent.UI.GroundShadow)
local PadArt = require(script.Parent.Parent.UI.PadArt)
local PileView = require(script.Parent.Parent.UI.PileView)
local StandRing = require(script.Parent.Parent.UI.StandRing)
local Theme = require(script.Parent.Parent.UI.Theme)
local Widgets = require(script.Parent.Parent.UI.Widgets)

export type Deps = {
    Plot: Frame,
    Remotes: { UsePlace: RemoteEvent, AtPlace: RemoteEvent, Sold: RemoteEvent },
    CharacterPos: () -> (number, number),
    -- [verificatorul A1, provizoriu] o privire (LookController.Look) spre un loc al terenului; nil = fara privire
    LookAt: ((x: number, y: number) -> ())?,
    -- [verificatorul A1] privirea nu se ofera cat bannerul oraselului (cu Look-ul lui) inca asteapta
    LookAcrossReady: (() -> boolean)?,
}

-- Ce stie clientul despre traista (TycoonState.sack) si despre gramezile unei linii (TycoonState.flow).
export type Sack = {
    count: number,
    capacity: number,
    rawBy: { [string]: number },
    sellBy: { [string]: { count: number, value: number } },
    partBy: { [string]: number }?, -- [D70, pasul k3] piesele gata, pe unirea lor
    contents: { [string]: number }?, -- [verificatorul k3] ce e in traista, pe marfa: ce piesa duci
}
-- [D70, pasul k3] formele vin din copia starii (Shared/Modules/StateCopy), una pentru toate liniile
export type StoreState = StateCopy.StoreState
export type ProcessorState = StateCopy.ProcessorState
export type SellerState = StateCopy.SellerState

-- O cladire fixa a cartierului: unde sta (mijlocul, baza), cat e de mare si ce desen are (cheile din Assets.tycoon):
-- `sprite` = desenul ei; `borrowed` = al perechii din Era 1, purtat cat al ei nu e urcat; `ruin` = ce se vede pe locul
-- ei cat cartierul e inca inchis [D53, D65] (fara ruina urcata, locul ramane gol, ca pana acum).
export type Building = {
    x: number,
    y: number,
    w: number,
    h: number,
    sprite: string,
    borrowed: string?,
    ruin: string?,
    label: string,
}

export type Line = {
    Apply: (
        sack: Sack,
        store: StoreState?,
        processor: ProcessorState?,
        pads: { [string]: string },
        bottleneck: string
    ) -> (),
    FocusStore: (px: number, py: number) -> Focus.Focus?,
    FocusProcessor: (px: number, py: number) -> Focus.Focus?,
    Working: () -> boolean,
}
export type Seller = {
    Apply: (sack: Sack, state: SellerState?, open: boolean) -> (),
    Focus: (px: number, py: number) -> Focus.Focus?,
}

local LineController = {}
local deps: Deps

local EMPTY_SACK: Sack = { count = 0, capacity = 0, rawBy = {}, sellBy = {} }

-- [D43, D65] UN ATELIER CARE LUCREAZA SE VEDE: fum la horn cat are marfa la intrare si cineva o prelucreaza (omul lui
-- sau tu, in inel), ca la forja. Unde e hornul, in fractiuni din desenul cladirii: pe desenul ei (`own`) si pe cel de
-- imprumut, purtat cat al ei nu e urcat. Cutia cladirii de pe o platforma = desenul ei, prins de baza platformei.
local SMOKE_AT: { [string]: { own: { number }, borrowed: { number }, key: string, w: number, h: number } } =
    {
        foundry = {
            own = { 0.79, 0.02 },
            borrowed = { 0.79, 0.06 },
            key = "foundry",
            w = 40,
            h = 32,
        },
        furnace = {
            own = { 0.5, 0.0 },
            borrowed = { 0.77, 0.0 },
            key = "copper_furnace",
            w = 64,
            h = 48,
        },
        -- [verificatorul k3] atelierele barajului, cat poarta desenele erelor 2-3: hornul desenului de imprumut (`own` se
        -- masoara pe foile lor, la A4)
        switchyard = {
            own = { 0.79, 0.02 },
            borrowed = { 0.79, 0.02 },
            key = "switchyard",
            w = 40,
            h = 32,
        },
        cableworks = {
            own = { 0.79, 0.06 },
            borrowed = { 0.79, 0.06 },
            key = "cable_works",
            w = 40,
            h = 32,
        },
        kiln = {
            own = { 0.5, 0.0 },
            borrowed = { 0.5, 0.0 },
            key = "crystal_kiln",
            w = 64,
            h = 48,
        },
        -- [D67] Wire Works si Power House, cat poarta desenele Morii (turnatoria, cuptorul): hornul lor. Cand vine arta
        -- lor (pasul 7), `own` se masoara pe foile noi.
        wireworks = {
            own = { 0.79, 0.02 },
            borrowed = { 0.79, 0.02 },
            key = "wire_works",
            w = 40,
            h = 32,
        },
        powerhouse = {
            own = { 0.5, 0.0 },
            borrowed = { 0.5, 0.0 },
            key = "power_house",
            w = 64,
            h = 48,
        },
    }

local function keyHint(): string
    return if UserInputService.KeyboardEnabled then " (E)" else ""
end

-- Desenul unei cladiri fixe: sprite-ul ei, prins de baza, cu umbra pe pamant si numele deasupra usii. Fara arta urcata
-- inca, o cutie de lemn ii tine locul, ca locul sa se vada si sa se poata verifica.
local function uploaded(key: string?): Assets.Sprite?
    local sprite = if key ~= nil then (Assets.tycoon :: any)[key] else nil
    return if sprite ~= nil and Assets.has(sprite) then sprite else nil
end

-- Ruina de pe locul unei cladiri fixe, cat cartierul e inchis; nil daca desenul ei nu e urcat.
local function drawRuin(b: Building): GuiObject?
    local sprite = uploaded(b.ruin)
    if sprite == nil then
        return nil
    end
    local img = Instance.new("ImageLabel")
    img.Name = b.label .. "Ruin"
    img.BackgroundTransparency = 1
    img.Image = Assets.url(sprite)
    img.ResampleMode = Enum.ResamplerMode.Pixelated
    img.AnchorPoint = Vector2.new(0.5, 1)
    img.Position = UDim2.fromOffset(b.x, b.y)
    img.Size = UDim2.fromOffset(b.w, b.h)
    img.ZIndex = 5 + math.clamp(math.floor(b.y / 64), 0, 40)
    img.Parent = deps.Plot
    return img
end

-- Cat urca peste acoperis numele unei cladiri fixe (eticheta de 18 px, cu baza la 4 px peste el): cardul E sta deasupra.
local NAME_ABOVE = 4 + 18

local function drawBuilding(b: Building): (GuiObject, TextLabel)
    local sprite = uploaded(b.sprite) or uploaded(b.borrowed)
    local art: GuiObject
    if sprite ~= nil then
        local img = Instance.new("ImageLabel")
        img.BackgroundTransparency = 1
        img.Image = Assets.url(sprite)
        img.ResampleMode = Enum.ResamplerMode.Pixelated
        art = img
    else
        local box = Instance.new("Frame")
        box.BackgroundColor3 = Theme.COLOR.woodDark
        box.BorderSizePixel = 0
        art = box
    end
    art.Name = b.label
    art.AnchorPoint = Vector2.new(0.5, 1)
    art.Position = UDim2.fromOffset(b.x, b.y)
    art.Size = UDim2.fromOffset(b.w, b.h)
    art.ZIndex = 5 + math.clamp(math.floor(b.y / 64), 0, 40)
    art.Visible = false
    art.Parent = deps.Plot
    -- umbra sta in desenul cladirii, ca sa apara si sa dispara odata cu ea
    local shadow = GroundShadow.add(art, UDim2.fromScale(0.5, 1), b.w, art.ZIndex - 1)
    shadow.Name = "Shadow"

    local label = Widgets.Label(deps.Plot, b.label, Theme.TEXT.tiny, Theme.COLOR.onDark, "strong")
    label.AnchorPoint = Vector2.new(0.5, 1)
    label.Position = UDim2.fromOffset(b.x, b.y - b.h - 4)
    label.Size = UDim2.fromOffset(math.max(b.w, 120), 18)
    label.TextXAlignment = Enum.TextXAlignment.Center
    label.ZIndex = 46
    label.Visible = false
    Theme.punch(label, 2)
    return art, label
end

-- [2026-09-29] CLADIREA CU NIVELURI A FIECAREI STATII din tabel (atelierul unei linii, vanzatorul): mijlocul ei in lume,
-- numele si ce sare cand urci un nivel (`art` pentru o cladire fixa, `pad` pentru una de pe platforma). Overlay le
-- citeste de aici: fara ele, orice nivel al Morii sau al Wire Works isi punea rafala si cifra pe taverna Erei 1, in
-- afara ecranului, iar bannerul de prag scria "Tavern".
export type StationSpot = { x: number, y: number, name: string, art: GuiObject?, pad: string? }
local stationSpots: { [string]: StationSpot } = {}

function LineController.StationSpot(kind: string): StationSpot?
    return stationSpots[kind]
end

-- O linie: magazia si atelierul ei. `storeBuilding` / `processorBuilding` = cladirea fixa, cand locul nu e o platforma.
function LineController.line(
    line: string,
    storeBuilding: Building?,
    processorBuilding: Building?
): Line
    local flow = FlowConfig.LINES[line]
    local places = TycoonConfig.LINE_PLACES[line]
    local words = Strings.LINE_WORDS[line]
    assert(
        flow ~= nil and places ~= nil and words ~= nil,
        `LineController: linia {line} lipseste din tabele`
    )

    local sack: Sack = EMPTY_SACK
    local storeState: StoreState = { count = 0, contents = {} }
    local state: ProcessorState = {
        count = 0,
        contents = {},
        out = 0,
        outContents = {},
        rate = 0,
        present = false,
        staffed = false,
    }
    local storeOpen, processorOpen = false, false
    local bottleneck = ""

    local storePile =
        PileView.new(deps.Plot, places.storePile.x, places.storePile.y, { warnAt = 60 })
    local inPile = PileView.new(deps.Plot, places.inPile.x, places.inPile.y, { warnAt = 40 })
    local outPile = PileView.new(deps.Plot, places.outPile.x, places.outPile.y, { warnAt = 40 })

    local storeArt: GuiObject?, storeLabel: TextLabel? = nil, nil
    local ruins: { GuiObject } = {}
    if storeBuilding ~= nil then
        storeArt, storeLabel = drawBuilding(storeBuilding)
        local ruin = drawRuin(storeBuilding)
        if ruin ~= nil then
            table.insert(ruins, ruin)
        end
    end
    local processorArt: GuiObject?, processorLabel: TextLabel? = nil, nil
    if processorBuilding ~= nil then
        processorArt, processorLabel = drawBuilding(processorBuilding)
        local ruin = drawRuin(processorBuilding)
        if ruin ~= nil then
            table.insert(ruins, ruin)
        end
    end

    -- [2026-09-29] Mijlocul si acoperisul cladirii chiar desenate (magazia, atelierul), pentru cardul E: cea fixa are cutia
    -- ei, cea de pe platforma sta la TycoonConfig.buildingBase, cat desenul ales de PadArt. Cardul socotea inaltimea
    -- din cifre scrise de mana (144 si pe turnatoria de 96 px, deci plutea la 54 px peste acoperis) si mijlocul din
    -- gramada (40 px spre stanga la magaziile Morii si ale Wire Works). Cardul sta la 6 px peste acoperis; la cladirea
    -- fixa, deasupra numelui ei, care sta si el peste acoperis (drawBuilding: 18 px, cu baza la 4 px peste el).
    -- Intoarce mijlocul (x), acoperisul, baza si unde sta baza cardului E.
    local function roofOf(
        building: Building?,
        padId: string?,
        fallbackX: number,
        fallbackBase: number,
        fallbackH: number
    ): (number, number, number, number)
        if building ~= nil then
            local roof = building.y - building.h
            return building.x, roof, building.y, roof - NAME_ABOVE - 6
        end
        local pad = if padId ~= nil then TycoonConfig.byId[padId] else nil
        if pad ~= nil and pad.x ~= nil and pad.y ~= nil then
            local sprite, scale = PadArt.bought(pad.id, 0)
            local h = if sprite ~= nil then sprite.height * scale else fallbackH
            local base = TycoonConfig.buildingBase(pad)
            return pad.x :: number, base - h, base, base - h - 6
        end
        return fallbackX, fallbackBase - fallbackH, fallbackBase, fallbackBase - fallbackH - 6
    end
    local storeX, _, _, storeCardY =
        roofOf(storeBuilding, flow.storePad, places.storePile.x + 100, places.storePile.y, 96)
    local processorX, processorRoof, processorBase, processorCardY = roofOf(
        processorBuilding,
        flow.processorPad,
        (places.inPile.x + places.outPile.x) / 2,
        places.inPile.y,
        144
    )
    stationSpots[flow.station] = {
        x = processorX,
        y = (processorRoof + processorBase) / 2,
        name = words.processor,
        art = processorArt,
        pad = if processorBuilding == nil then flow.processorPad else nil,
    }

    StandRing.new({
        plot = deps.Plot,
        name = flow.processor,
        stand = places.playerStand,
        remote = deps.Remotes.AtPlace,
        place = flow.processor,
        characterPos = deps.CharacterPos,
        standHere = words.standHere,
        working = function(left: number): string
            return Strings.lineWorking(words, left)
        end,
        state = function(): (number, boolean)
            return state.count, state.staffed == true
        end,
        active = function(): boolean
            return processorOpen
        end,
    })

    local function raw(): number
        return sack.rawBy[line] or 0
    end
    -- [verificatorul k4] fara nimic de facut aici, dar cu marfa bruta a altei linii: cardul spune unde merge, inainte de E
    local function hintStatus(isStore: boolean): string?
        local hint = FlowMath.hintAt(sack.rawBy, line)
        if hint == nil then
            return nil
        end
        return Strings.placeResult(line, nil, isStore, false, hint, 0, 0, state.staffed == true)
    end

    -- fumul atelierului: un cadru gol peste cladire, aratat doar cat atelierul chiar lucreaza
    local smokeHost: Frame? = nil
    local smoke = SMOKE_AT[flow.processor]
    if smoke ~= nil then
        local pad = if flow.processorPad ~= nil then TycoonConfig.byId[flow.processorPad] else nil
        local box = processorBuilding
        if box == nil and pad ~= nil and pad.x ~= nil and pad.y ~= nil then
            box = {
                x = pad.x :: number,
                y = TycoonConfig.buildingBase(pad), -- unde prinde PadController desenul de platforma
                w = smoke.w * Assets.PIXEL_SCALE,
                h = smoke.h * Assets.PIXEL_SCALE,
                sprite = "",
                label = "",
            }
        end
        if box ~= nil then
            local host = Instance.new("Frame")
            host.Name = flow.processor .. "Smoke"
            host.BackgroundTransparency = 1
            host.AnchorPoint = Vector2.new(0.5, 1)
            host.Position = UDim2.fromOffset(box.x, box.y)
            host.Size = UDim2.fromOffset(box.w, box.h)
            host.ZIndex = 46
            host.Visible = false
            host.Parent = deps.Plot
            local at = if uploaded(smoke.key) ~= nil then smoke.own else smoke.borrowed
            SceneArt.AddSmoke(host, at[1], at[2])
            smokeHost = host
        end
    end

    -- Meseria care conteaza acum la magazie, ca la depozit: cine aduce, daca adunatul e veriga slaba a liniei; altfel
    -- cine ia de aici.
    local steps = StationConfig.LINES[line].steps -- primul om goleste plasele la magazie, al doilea ia de aici
    local function storeCrew(): string
        return if bottleneck == steps[1].link then steps[1].role else steps[2].role
    end

    local self = {}

    function self.Apply(
        newSack: Sack,
        store: StoreState?,
        processor: ProcessorState?,
        pads: { [string]: string },
        bn: string
    )
        sack = newSack
        bottleneck = bn
        -- magazia exista cand exista platforma ei (sau, fara platforma, cand atelierul liniei e pornit)
        processorOpen = flow.processorPad == nil or pads[flow.processorPad] == "bought"
        storeOpen = if flow.storePad ~= nil then pads[flow.storePad] == "bought" else processorOpen
        if store ~= nil then
            storeState = store
            storePile.Set(store.count, store.contents)
        end
        if processor ~= nil then
            state = processor
            inPile.Set(processor.count, processor.contents)
            outPile.Set(processor.out, processor.outContents)
        end
        -- cladirile fixe se vad de cand se deschide cartierul lor (roata de apa): pana atunci sunt ruinele din desen
        for _, part in
            {
                storeArt :: GuiObject?,
                storeLabel :: GuiObject?,
                processorArt :: GuiObject?,
                processorLabel :: GuiObject?,
            }
        do
            if part ~= nil then
                part.Visible = processorOpen
            end
        end
        for _, ruin in ruins do
            ruin.Visible = not processorOpen
        end
        if smokeHost ~= nil then
            smokeHost.Visible = processorOpen and state.rate > 0 and state.count > 0
        end
    end

    function self.FocusStore(px: number, py: number): Focus.Focus?
        if not storeOpen then
            return nil
        end
        local stand = places.storeStand
        local d = Focus.distance(px, py, stand.x, stand.y)
        if d > RiverConfig.INTERACT_DISTANCE then
            return nil
        end
        local text: string? = nil
        if raw() > 0 then
            text = Strings.promptStoreRaw(words, keyHint())
        elseif storeState.count > 0 and sack.count < sack.capacity then
            text = Strings.promptTakeRaw(words, keyHint())
        end
        return {
            status = if text == nil then hintStatus(true) else nil, -- [verificatorul k4]
            key = flow.store,
            at = places.storeStand,
            distance = d,
            x = storeX,
            y = storeCardY,
            action = text,
            act = if text ~= nil
                then function()
                    deps.Remotes.UsePlace:FireServer(flow.store)
                end
                else nil,
            upgradeKind = "crew",
            upgradeId = storeCrew(),
        }
    end

    function self.FocusProcessor(px: number, py: number): Focus.Focus?
        if not processorOpen then
            return nil
        end
        local stand = places.playerStand
        local d = Focus.distance(px, py, stand.x, stand.y)
        if d > RiverConfig.INTERACT_DISTANCE then
            return nil
        end
        -- cat lucrezi TU la atelier (fara omul lui), gestul nu-ti ia marfa gata de sub mana: intai se termina lotul
        local byHand = state.staffed ~= true and state.count > 0
        local text: string? = nil
        if raw() > 0 then
            text = Strings.promptProcess(words, keyHint())
        elseif state.out > 0 and sack.count < sack.capacity and not byHand then
            text = Strings.promptTakeDone(words, keyHint())
        end
        return {
            status = if text == nil then hintStatus(false) else nil, -- [verificatorul k4]
            key = flow.processor,
            at = places.playerStand,
            distance = d,
            x = processorX,
            y = processorCardY,
            action = text,
            act = if text ~= nil
                then function()
                    deps.Remotes.UsePlace:FireServer(flow.processor)
                end
                else nil,
            upgradeKind = flow.station,
        }
    end

    function self.Working(): boolean
        return processorOpen and state.rate > 0
    end

    return self
end

-- [D70, pasul k3] O UNIRE (Relay Station-ul barajului): fiecare piesa isi are gramada la intrarea ei (JOIN_PLACES), iesirea
-- una, inelul in care stai cat n-are om si gestul tau pe E (lasi piesele, iei curentul gata). Unirea merge doar cu toate
-- piesele: cat una lipseste, placa de deasupra inelului spune care („Waiting for cable”), iar inelul nu te cheama (n-ai ce
-- lucra acolo). N-are magazie si nici ruina: e acolo de la baraj.
function LineController.join(line: string, building: Building): Line
    local flow = FlowConfig.LINES[line]
    local places = TycoonConfig.JOIN_PLACES[line]
    local words = Strings.LINE_WORDS[line]
    assert(
        flow ~= nil and flow.joins ~= nil and places ~= nil and words ~= nil,
        `LineController: unirea {line} lipseste din tabele`
    )
    local joins = flow.joins :: { FlowConfig.Join }

    local sack: Sack = EMPTY_SACK
    local state: ProcessorState = {
        count = 0,
        contents = {},
        out = 0,
        outContents = {},
        rate = 0,
        present = false,
        staffed = false,
    }
    local open = false

    -- gramada fiecarei piese, la intrarea ei; o piesa e o singura marfa (iesirea liniei ei)
    local inPiles: { [string]: PileView.View } = {}
    for _, join in joins do
        local at = places.inPiles[join.line]
        inPiles[join.line] = PileView.new(deps.Plot, at.x, at.y, { warnAt = 40 })
    end
    local outPile = PileView.new(deps.Plot, places.outPile.x, places.outPile.y, { warnAt = 40 })
    local art, label = drawBuilding(building)
    stationSpots[flow.station] = {
        x = building.x,
        y = building.y - building.h / 2,
        name = words.processor,
        art = art,
    }

    -- cate uniri se pot face acum: cea mai mica gramada de piese (o bucata din fiecare face una, FlowMath.assemble); aceeasi
    -- regula ca ghidajul (StateCopy.joinable)
    local function joinable(): number
        return StateCopy.joinable(state)
    end

    StandRing.new({
        plot = deps.Plot,
        name = flow.processor,
        stand = places.playerStand,
        remote = deps.Remotes.AtPlace,
        place = flow.processor,
        characterPos = deps.CharacterPos,
        standHere = words.standHere,
        working = function(left: number): string
            return Strings.lineWorking(words, left)
        end,
        state = function(): (number, boolean)
            return joinable(), state.staffed == true
        end,
        active = function(): boolean
            return open
        end,
    })

    -- „Waiting for cable”: pe locul placii inelului (StandRing o arata doar cand e ceva de unit, deci nu se calca)
    local waitSign = Widgets.PlateLabel(deps.Plot, "", Theme.TEXT.body, "strong")
    waitSign.Name = `{flow.processor}WaitSign`
    waitSign.AnchorPoint = Vector2.new(0.5, 1)
    waitSign.Position = UDim2.fromOffset(places.playerStand.x, places.playerStand.y - 24 - 4)
    waitSign.TextXAlignment = Enum.TextXAlignment.Center
    waitSign.TextColor3 = Theme.COLOR.onDarkSoft
    waitSign.ZIndex = 47
    waitSign.Visible = false
    Theme.punch(waitSign, 2)

    local self = {}

    function self.Apply(
        newSack: Sack,
        _store: StoreState?,
        processor: ProcessorState?,
        pads: { [string]: string },
        _bottleneck: string
    )
        sack = newSack
        open = flow.processorPad == nil or pads[flow.processorPad] == "bought"
        art.Visible = open
        label.Visible = open
        if processor ~= nil then
            state = processor
            local inputs = processor.inputs or {}
            for _, join in joins do
                local n = inputs[join.line] or 0
                inPiles[join.line].Set(n, if n > 0 then { [join.good] = n } else {})
            end
            outPile.Set(processor.out, processor.outContents)
        end
        -- ce lipseste, doar cand chiar asteapta ceva (macar o piesa e acolo)
        local missing = state.waiting
        local missingWords = if missing ~= nil then Strings.LINE_WORDS[missing] else nil
        local showWait = open and missingWords ~= nil and state.count > 0
        if showWait then
            local text = Strings.joinWaiting(missingWords :: Strings.LineWords)
            if waitSign.Text ~= text then
                waitSign.Text = text
                local width = Theme.textWidth(text, Theme.TEXT.body, "strong")
                    + 2 * Theme.SPACE.sm
                    + 4
                waitSign.Size = UDim2.fromOffset(math.max(220, math.ceil(width)), 30)
            end
        end
        waitSign.Visible = showWait
    end

    function self.FocusStore(_px: number, _py: number): Focus.Focus?
        return nil -- o unire n-are magazie
    end

    function self.FocusProcessor(px: number, py: number): Focus.Focus?
        if not open then
            return nil
        end
        local stand = places.playerStand
        local d = Focus.distance(px, py, stand.x, stand.y)
        if d > RiverConfig.INTERACT_DISTANCE then
            return nil
        end
        -- cat unesti TU (fara omul ei), gestul nu-ti ia curentul gata de sub mana: intai se termina lotul
        local byHand = state.staffed ~= true and joinable() > 0
        local parts = if sack.partBy ~= nil then sack.partBy[line] or 0 else 0
        local text: string? = nil
        if parts > 0 then
            -- [verificatorul k3] o singura piesa in traista: „Drop cable (E)”, nu „Join barrels and cable”
            local carried = StateCopy.partsCarried(sack.contents or {}, joins)
            local only: string? = nil
            local kinds = 0
            for part in carried do
                only = part
                kinds += 1
            end
            text = if kinds == 1 and only ~= nil
                then Strings.promptDropPart(Strings.LINE_WORDS[only], keyHint())
                else Strings.promptProcess(words, keyHint())
        elseif state.out > 0 and sack.count < sack.capacity and not byHand then
            text = Strings.promptTakeDone(words, keyHint())
        end
        -- [verificatorul k4] fara nimic de facut, cu marfa bruta a unei piese: unde merge (aceeasi regula ca serverul)
        local hint = if text == nil then FlowMath.hintAt(sack.rawBy, line) else nil
        return {
            status = if hint ~= nil
                then Strings.placeResult(line, nil, false, false, hint, 0, 0, state.staffed == true)
                else nil,
            key = flow.processor,
            at = places.playerStand,
            distance = d,
            x = building.x,
            y = building.y - building.h - NAME_ABOVE - 6, -- deasupra numelui, ca la atelierele fixe
            action = text,
            act = if text ~= nil
                then function()
                    deps.Remotes.UsePlace:FireServer(flow.processor)
                end
                else nil,
            upgradeKind = flow.station,
        }
    end

    function self.Working(): boolean
        return open and state.rate > 0
    end

    return self
end

-- [inventarul A4] Ce duce acasa clientul unui vanzator: marfa ultimei linii din preferintele lui (Piata: piesa de masina, ca
-- inainte; Depoul: colacul de sarma; Switch House: curentul). Inainte toti plecau cu piesa de masina a Morii.
local function customerCarry(seller: string): string
    local good = FlowConfig.customerGood(seller)
    if good == nil or good == "parts" then
        return "part"
    end
    return `good:{good}`
end

-- Vanzatorul unui cartier: cladirea, gramada de langa ea si predarea la usa.
function LineController.seller(seller: string, building: Building): Seller
    local flow = FlowConfig.SELLERS[seller]
    local places = TycoonConfig.SELLER_PLACES[seller]
    assert(flow ~= nil and places ~= nil, `LineController: vanzatorul {seller} lipseste din tabele`)

    local sack: Sack = EMPTY_SACK
    local isOpen = false
    local sellShownAt = -math.huge -- [verificatorul A1] ultima data cand cardul a aratat „Sell”
    local pile = PileView.new(deps.Plot, places.pile.x, places.pile.y, { warnAt = 60 })
    local art, label = drawBuilding(building)
    local ruin = drawRuin(building)
    stationSpots[flow.station] = {
        x = building.x,
        y = building.y - building.h / 2,
        name = building.label,
        art = art,
    }
    -- [D50, D65] clientii: vin cat vinde vanzatorul chiar acum si pleaca acasa cu marfa in brate (UI/CustomerCrowd)
    local crowd = CustomerCrowd.new({
        plot = deps.Plot,
        name = `{building.label}Customer`,
        spots = places.customerSpots,
        entry = places.customerEntry,
        seedBase = 950000,
        held = customerCarry(seller),
    })
    RunService.PreRender:Connect(crowd.Step)
    deps.Remotes.Sold.OnClientEvent:Connect(
        function(_total: number, itemCount: number, soldBy: string?)
            if soldBy == seller then
                crowd.OnSold(itemCount)
            end
        end
    )

    local self = {}

    function self.Apply(newSack: Sack, state: SellerState?, open: boolean)
        sack = newSack
        isOpen = open
        art.Visible = open
        label.Visible = open
        if ruin ~= nil then
            ruin.Visible = not open
        end
        if state ~= nil then
            pile.Set(state.count, state.contents)
        end
    end

    function self.Focus(px: number, py: number): Focus.Focus?
        if not isOpen then
            return nil
        end
        local d = Focus.distance(px, py, places.door.x, places.door.y)
        if d > RiverConfig.INTERACT_DISTANCE then
            return nil
        end
        local mine = sack.sellBy[seller]
        local text: string? = nil
        local status: string? = nil
        if mine ~= nil and mine.count > 0 then
            text = Strings.promptSellAt(keyHint(), TycoonMath.formatNumber(mine.value))
            sellShownAt = os.clock()
        else
            -- [verificatorii k3, k4, k9-k10a] n-ai ce vinde aici: cardul spune unde merge ce duci, nu tace si nu suna a
            -- refuz [D43] (piesele la unire, marfa altui vanzator, marfa bruta a oricarei linii, la atelierul ei)
            local kind, which, also = StateCopy.sellerNote(
                sack,
                seller,
                StationConfig.LINE_ORDER,
                StationConfig.SELLER_ORDER,
                function(line: string): string?
                    local spec = StationConfig.LINES[line]
                    return if spec ~= nil then spec.seller else nil
                end,
                function(line: string): string?
                    local w = Strings.LINE_WORDS[line]
                    return if w ~= nil then w.raw else nil
                end
            )
            local words = if which ~= nil then Strings.LINE_WORDS[which] else nil
            local alsoWords = if also ~= nil then Strings.LINE_WORDS[also] else nil
            if kind == "part" and words ~= nil then
                status = Strings.partsToJoin(words)
            elseif kind == "other" and which ~= nil then
                status = Strings.sellerElsewhere(which)
            elseif kind == "raw" and words ~= nil and alsoWords ~= nil then
                status = Strings.rawGoesToBoth(words, alsoWords)
            elseif kind == "raw" and words ~= nil then
                status = Strings.rawGoesTo(words)
            end
        end
        -- [verificatorul A1, provizoriu] n-ai nimic de vandut si nimic de spus: cardul Switch House priveste peste rau, la
        -- oraselul care iti cumpara curentul (doar cu desenul lui urcat)
        local lookAt = deps.LookAt
        local center = DamTown.townCenter()
        -- [verificatorul A1] armata abia la LOOK_ARM_SECONDS dupa ce cardul n-a mai aratat „Sell”: o a doua apasare pe E,
        -- din obisnuinta, nu muta camera peste rau
        local ready = deps.LookAcrossReady
        local across = text == nil
            and status == nil
            and (places :: any).lookAcross == true
            and lookAt ~= nil
            and center ~= nil
            and Assets.has(Assets.tycoon.painted_town)
            and os.clock() - sellShownAt >= LOOK_ARM_SECONDS
            and (ready == nil or ready())
        return {
            status = status,
            key = seller,
            at = places.door,
            distance = d,
            x = building.x,
            y = building.y - building.h - NAME_ABOVE - 6, -- deasupra numelui, ca la atelier si la magazie
            action = if across then Strings.lookAcross(keyHint()) else text,
            act = if text ~= nil
                then function()
                    deps.Remotes.UsePlace:FireServer(seller)
                end
                elseif across then function()
                    local c = center :: { x: number, y: number }
                    local look = lookAt :: (number, number) -> ()
                    look(c.x, c.y)
                end
                else nil,
            upgradeKind = flow.station,
        }
    end

    return self
end

function LineController.Init(d: Deps)
    deps = d
end

return LineController
