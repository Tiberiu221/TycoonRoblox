--!strict
-- Platformele de cumparat, ca obiect de lume, nu casuta de interfata [F2 finisaj, spec Agent U
-- pct.1]: un stalp cu o placuta de lemn care arata numele si pretul; cartonasul de la apropiere
-- (mai jos) e cel care vinde efectiv platforma. Cumperi calcand pe ea (sau apasand, pe telefon) --
-- o singura metoda de cumparare pentru tot. Serverul decide intotdeauna (PadService.Buy
-- revalideaza pretul si statutul); clientul doar sugereaza intentia si arata rezultatul.
-- `Assets.has(...)` pazeste fiecare bucata de arta noua: cat timp un id e 0, ramanem pe desenul
-- vechi -- asa nimic nu arata stricat inainte ca arta sa apara [F2 spec regula 6].
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local RiverConfig = require(ReplicatedStorage.Shared.Config.RiverConfig)
local TycoonConfig = require(ReplicatedStorage.Shared.Config.TycoonConfig)
local TycoonMath = require(ReplicatedStorage.Shared.Modules.TycoonMath)
local Assets = require(ReplicatedStorage.Shared.Config.Assets)
local Strings = require(ReplicatedStorage.Shared.Config.Strings)
local WorkshopController = require(script.Parent.WorkshopController)
local HUDController = require(script.Parent.HUDController)
local Theme = require(script.Parent.Parent.UI.Theme)
local Widgets = require(script.Parent.Parent.UI.Widgets)
local Focus = require(script.Parent.Parent.UI.Focus)

export type Deps = {
    Plot: Frame,
    Remotes: {
        BuyPad: RemoteEvent,
        PadBought: RemoteEvent,
        PadRejected: RemoteEvent,
    },
    CharacterPos: () -> (number, number),
    OnToast: (string) -> (),
    -- deschide panoul de niveluri pe o statie; dat din Bootstrap, ca sa nu cerem StationPanel aici
    OpenStation: ((string, string?) -> ())?,
}

local PadController = {}
local deps: Deps
local frames: { [string]: TextButton } = {}
local statuses: { [string]: string } = {}
-- Tinta cartonasului de la apropiere. Sus, cu restul starii: `ensureFrame` o citeste la clic,
-- iar o variabila locala declarata DUPA functia care o foloseste nu e vazuta de ea.
local approachTarget: string? = nil -- padId-ul cartonasului curent, sau nil daca e ascuns
local approachAffordable = false
local approachCoins = -1 -- banii cu care s-a desenat randul "343 → 330 left"; -1 = niciodata
-- Cand a aparut tinta curenta pe cartonas. Cumpararea ei e oprita un scurt moment: dupa un clic de
-- cumparare, cartonasul trece pe obiectul urmator din raza, iar al doilea clic al unui dublu-clic
-- l-ar cumpara si pe ala -- fara ca jucatorul sa-i fi vazut macar pretul.
local approachShownAt = 0
local APPROACH_ARM_SECONDS = 0.35
local lastStatus: { [string]: string } = {}
local lastAffordable: { [string]: boolean } = {}
local ringSetters: { [string]: (number, Color3, Color3) -> () } = {}
local needLabels: { [string]: TextLabel } = {} -- padId -> "Need N more", doar cat timp nu ajung banii
local plaques: { [string]: GuiObject } = {} -- padId -> tinta pentru Flash (placuta noua sau, fara arta, cadrul insusi)
local pulseGen: { [string]: number } = {} -- padId -> generatia pulsului curent, anuleaza un task.delay invechit
local coins = 0
local padDeltas: { [string]: number } = {}
local bottleneck = "nets" -- veriga slaba acum: cartonasul o foloseste cand delta e zero -- padId -> venit/s adaugat, calculat de server [F2 "Already done by me"]
local firedAt: { [string]: number } = {} -- padId -> os.clock() la ultima tragere, pentru cooldown-ul de 1s
local Z = 3 -- nivelul solului, sub personaj si decor

-- Geometria placutei. La PIXEL_SCALE (x3) iesea de 144x72, adica mai lata decat platforma si mai
-- inalta decat personajul: pe mal se vedeau numai panouri. Merge la scara recuzitei mici (x2),
-- ca orice obiect care nu e cladire.
-- Pancarda de lemn (stalp + placuta cu pretul) a fost SCOASA pe 2026-09-12, la cererea
-- owner-ului: "vreau sa se vada obiectul direct doar ca locked, trebuie bani ca sa fie cumparat".
-- Pe mal se vedeau doar panouri; acum se vede lumea de dupa, in umbra. Ce a ramas de-acolo:
-- latimea barei de progres spre pret, care e a platformei, nu a unei placute.
local PROGRESS_W = 152

-- Cartonasul de la apropiere: piesa cea mai importanta [F2 spec Agent U pct.2] -- transforma "un
-- patrat pe care calci" in "un lucru pe care decizi sa-l cumperi". Continutul si desenul lui
-- traiesc acum in HUDController (fix jos-centru, in HUD -- nu mai poate acoperi raul sau alta
-- platforma) [F3 spec item 5]; aici ramane doar raza de proximitate, ca sa stim CAND sa-l aratam.
local APPROACH_RADIUS = 220

-- [B5] Platformele sunt copii ai Plot-ului, in coordonate locale terenului; personajul umbla in
-- coordonate de LUME. PLOT_ORIGIN e (0,0) azi, dar conversia trebuie sa fie corecta oricum.
local PLOT_ORIGIN = TycoonConfig.PLOT_ORIGIN
local function toPlotLocal(worldX: number, worldY: number): (number, number)
    return worldX - PLOT_ORIGIN.x, worldY - PLOT_ORIGIN.y
end

-- Atelierul: singura platforma "bought" cu propriul indemn de interactiune (badge + "Workshop
-- (E)"), separat de cumparare -- odata construit, calci pe el ca sa deschizi panoul [F1 spec 4.5].
local workshopOwned = false
local workshopPile = 0
local workshopBadge: TextLabel? = nil
-- [D51] Cartonasul de cumparare si cardul obiectului (InteractController) nu se arata deodata: se vede
-- doar cel mai apropiat. `candidate` e platforma pe care ar arata-o cartonasul acum, cu distanta ei.
local approachSuppressed = false
local candidateId: string? = nil
local candidateDistance = math.huge

-- [D53] RUINELE. Orice platforma a Erei 1 necumparata sta pe mal ca ruina (cumparabila: ruina + pret), iar
-- langa una incuiata cartonasul spune ce trebuie facut intai. Nivelurile plaselor vin din TycoonState,
-- pentru conditia "Upgrade First Net to level 2 first".
local netLevels: { [string]: number } = {}
local RUIN_RADIUS = 120 -- mai mica decat cea de cumparare: 12 ruine pe mal, cartonasul n-are voie sa clipeasca
local RUIN_DWELL = 0.4 -- s in raza unei ruine, inainte sa apara cartonasul ei
local LOCKED_TINT = Color3.fromRGB(200, 196, 188) -- usor stinse: ruina cumparabila se citeste prima
local ruinTarget: string? = nil -- ruina de pe cartonas acum
local ruinCandidate: string? = nil
local ruinCandidateSince = 0
-- Avizierele: pe oameni ii angajezi, nu ii reconstruiesti. Pictograma meseriei pe avizierul curat.
local BOARD_ICON: { [string]: () -> Assets.Sprite } = {
    hire_porter = function()
        return Assets.goods.driftwood
    end,
    hire_sawyer = function()
        return Assets.icons.saw
    end,
    hire_hauler = function()
        return Assets.goods.planks
    end,
}

local function isNetPad(pad: TycoonConfig.Pad): boolean
    for _, e in pad.effects do
        if e.kind == "net" then
            return true
        end
    end
    return false
end

local function clearContent(frame: Frame)
    for _, child in frame:GetChildren() do
        if not child:IsA("UICorner") then
            child:Destroy()
        end
    end
end

local function formatPrice(pad: TycoonConfig.Pad): string
    return if pad.price == 0 then "FREE" else TycoonMath.formatNumber(pad.price)
end

local function nameLabel(frame: Frame, pad: TycoonConfig.Pad, color: Color3, y: number, h: number)
    local l = Widgets.Label(frame, pad.name, Theme.TEXT.tiny, color, "strong")
    l.AnchorPoint = Vector2.new(0.5, 0)
    l.Position = UDim2.new(0.5, 0, 0, y)
    l.Size = UDim2.fromOffset(TycoonConfig.PAD_SIZE - 8, h)
    l.TextXAlignment = Enum.TextXAlignment.Center
    l.TextWrapped = true
    l.ZIndex = Z + 2
    Theme.punch(l, 2)
end

-- "Need N more": cate monede mai lipsesc, nu doar "nu ai destui bani" -- un calcul, nu un text
-- ghicit [D40, research 38 pct.6]. Rotunjit in sus: la 45.7/50 lipsesc 5, nu 4 (4 tot nu ajunge).
-- `bottomY` difera intre placuta noua (deasupra ei) si patratul vechi (dedesubt) -- geometria e
-- alta, mesajul e acelasi. Text peste lume, fara panou -> Theme.punch, ca restul patratului.
local function attachNeedLabel(frame: TextButton, pad: TycoonConfig.Pad, bottomY: number): TextLabel
    -- PlateLabel, nu Label+punch: rosul mic pe apa albastra nu se citea nici cu contur. Placa il
    -- scoate la fel de clar peste apa, peste iarba si peste scandurile pontonului.
    local need = Widgets.PlateLabel(
        frame,
        `Need {math.max(0, math.ceil(pad.price - coins))} more`,
        Theme.TEXT.tiny,
        "strong"
    )
    need.TextColor3 = Theme.COLOR.bad
    need.AnchorPoint = Vector2.new(0.5, 1)
    need.Position = UDim2.new(0.5, 0, 0, bottomY)
    need.Size = UDim2.fromOffset(150, 20)
    need.TextXAlignment = Enum.TextXAlignment.Center
    need.ZIndex = Z + 3
    return need
end

-- Pulsul care se strange: 0.7s la inceput, ~0.4s dupa 15s de cand platforma e afordabila si tot
-- ignorata [research 38 pct.7, F2 spec Agent U pct.1] -- un nudge ieftin pentru ce poti cumpara dar
-- treci pe langa. `padId` + o generatie anuleaza un task.delay invechit daca starea se schimba
-- (alta cumparare, platforma redevine neafordabila) inainte sa treaca cele 15s.
local function startPulse(stroke: UIStroke, padId: string)
    pulseGen[padId] = (pulseGen[padId] or 0) + 1
    local gen = pulseGen[padId]
    local function play(duration: number)
        TweenService
            :Create(
                stroke,
                TweenInfo.new(duration, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true),
                { Transparency = 0.6 }
            )
            :Play()
    end
    play(0.7)
    task.delay(15, function()
        if pulseGen[padId] == gen and stroke.Parent ~= nil then
            play(0.4)
        end
    end)
end

local function boughtSprite(padId: string): (Assets.Sprite?, number)
    if padId == "bigger_sack" then
        return Assets.tycoon.sack, TycoonConfig.PROP_SCALE
    elseif padId == "dock_trader" then
        -- taraba ramane a lui: Sorting Crate si Dock Stall au devenit niveluri ale debarcaderului,
        -- iar Negustorul a mostenit locul si sprite-ul [E1.3]. `crate.common` si `weights` raman
        -- in manifest -- se intorc in Era 2, nu sunt orfane.
        return Assets.tycoon.stall, TycoonConfig.PROP_SCALE
    elseif padId == "landing_bell" then
        return Assets.tycoon.bell, Assets.PIXEL_SCALE
    elseif padId == "workshop" then
        -- [D53] atelierul nou, in stilul tavernei; cel din era coloniei doar cat timp noul nu e urcat
        if Assets.has(Assets.tycoon.workshop_e1) then
            return Assets.tycoon.workshop_e1, Assets.PIXEL_SCALE
        end
        return Assets.buildings.workshop, Assets.PIXEL_SCALE
    elseif padId == "first_runner" then
        -- adapostul Collector-ului, odata angajat [F2 spec Agent H]; id-ul vechi al platformei [D49].
        -- Porter-ul, Sawyer-ul si Hauler-ul n-au coliba: trei colibe ar fi umplut malul de acelasi desen.
        return Assets.tycoon.runner_hut, Assets.PIXEL_SCALE
    end
    return nil, Assets.PIXEL_SCALE
end

-- LOCKED: se vede OBIECTUL INSUSI, stins, exact acolo unde va sta -- nu o pancarda cu pretul.
-- Owner-ul a cerut asta direct ("vreau sa se vada obiectul direct doar ca locked"), si e tiparul
-- din tycoon-urile care au prins: umbra cladirii pe loc gol spune, fara niciun cuvant, ce cumperi
-- si cum va arata malul dupa. Pancarda spunea doar un pret, adica cerea bani fara sa arate pentru ce.
--
-- Doua stari, o singura diferenta vizuala, citibila dintr-o privire:
--   n-ai banii -> silueta albastru-cenusie, foarte stinsa
--   ai banii   -> aproape obiectul adevarat (culoare intreaga, doar putin transparent) + puls auriu
-- Intoarce tinta pentru glow/puls/Flash si Y-ul local al varfului, ca pretul sa stea DEASUPRA lui.
-- Tenta siluetei: aproape NEAGRA, nu albastra. Prima varianta era albastru-cenusiu si, pe apa
-- (tot albastra), fantoma plasei aproape ca disparea -- vazut in propria randare, nu in joc.
-- Negrul se citeste la fel de bine si pe apa, si pe iarba, si pe scandurile pontonului.
local GHOST_TINT = Color3.fromRGB(26, 32, 42)
local GHOST_FADE, READY_FADE = 0.48, 0.12
local HALF = TycoonConfig.PAD_SIZE / 2

local function ghostImage(
    parent: Instance,
    sprite: Assets.Sprite,
    w: number,
    h: number,
    affordable: boolean
): ImageLabel
    local img = Instance.new("ImageLabel")
    img.Name = "Ghost"
    img.BackgroundTransparency = 1
    img.Image = Assets.url(sprite)
    img.ResampleMode = Enum.ResamplerMode.Pixelated
    img.Size = UDim2.fromOffset(w, h)
    img.ImageColor3 = if affordable then Color3.new(1, 1, 1) else GHOST_TINT
    img.ImageTransparency = if affordable then READY_FADE else GHOST_FADE
    img.ZIndex = Z
    img.Parent = parent
    return img
end

-- Plasa nu se cumpara "pe platforma": stalpul se infige in ponton si plasa atarna in apa, pe banda
-- ei. Geometria e COPIATA din NetController (radacina la pad.x/pad.y, stalp ancorat jos, plasa
-- centrata pe TycoonConfig.LANE_Y[banda]) ca fantoma sa stea exact unde apare plasa adevarata --
-- altfel, la cumparare, obiectul ar sari din loc.
local function ghostNet(
    frame: TextButton,
    pad: TycoonConfig.Pad,
    affordable: boolean
): (GuiObject?, number)
    if not Assets.has(Assets.tycoon.netpost) or not Assets.has(Assets.tycoon.net_water) then
        return nil, 0
    end
    local lane = 1
    for _, e in pad.effects do
        if e.kind == "net" and e.lane ~= nil then
            lane = e.lane :: number
        end
    end
    local postW = Assets.tycoon.netpost.width * TycoonConfig.PROP_SCALE
    local postH = Assets.tycoon.netpost.height * TycoonConfig.PROP_SCALE
    local post = ghostImage(frame, Assets.tycoon.netpost, postW, postH, affordable)
    post.Name = "GhostPost"
    post.AnchorPoint = Vector2.new(0.5, 1)
    post.Position = UDim2.new(0.5, 0, 0, HALF)

    local netY = HALF + ((TycoonConfig.LANE_Y[lane] or TycoonConfig.LANE_Y[1]) - (pad.y :: number))
    local net = ghostImage(
        frame,
        Assets.tycoon.net_water,
        TycoonConfig.NET_DRAW.w,
        TycoonConfig.NET_DRAW.h,
        affordable
    )
    net.AnchorPoint = Vector2.new(0.5, 0.5)
    net.Position = UDim2.new(0.5, 0, 0, netY)
    net.ZIndex = Z + 1

    -- funia, la fel de stinsa: fara ea plasa pluteste fara sa fie prinsa de nimic
    local rope = Instance.new("Frame")
    rope.Name = "GhostRope"
    rope.AnchorPoint = Vector2.new(0.5, 0)
    rope.Position = UDim2.new(0.5, 0, 0, HALF - postH)
    rope.Size =
        UDim2.fromOffset(3, math.max(0, (netY - TycoonConfig.NET_DRAW.h / 2) - (HALF - postH)))
    rope.BackgroundColor3 = if affordable then Theme.COLOR.woodDark else GHOST_TINT
    rope.BackgroundTransparency = if affordable then READY_FADE else GHOST_FADE
    rope.BorderSizePixel = 0
    rope.ZIndex = Z
    rope.Parent = frame

    return net, netY - TycoonConfig.NET_DRAW.h / 2
end

local function buildGhost(
    frame: TextButton,
    pad: TycoonConfig.Pad,
    affordable: boolean
): (GuiObject?, number)
    if isNetPad(pad) then
        return ghostNet(frame, pad, affordable)
    end
    -- statiile stau pe o dala, exact ca dupa cumparare (aceeasi linie de sol: 1, 8)
    if Assets.has(Assets.tycoon.platform) then
        local plat = ghostImage(
            frame,
            Assets.tycoon.platform,
            Assets.tycoon.platform.width * TycoonConfig.PROP_SCALE,
            Assets.tycoon.platform.height * TycoonConfig.PROP_SCALE,
            affordable
        )
        plat.Name = "GhostPlatform"
        plat.AnchorPoint = Vector2.new(0.5, 1)
        plat.Position = UDim2.new(0.5, 0, 1, 8)
    end
    local sprite, scale = boughtSprite(pad.id)
    if sprite == nil or not Assets.has(sprite) then
        return nil, TycoonConfig.PAD_SIZE
    end
    local w, h = sprite.width * scale, sprite.height * scale
    local img = ghostImage(frame, sprite, w, h, affordable)
    img.Name = "GhostBuilding"
    img.AnchorPoint = Vector2.new(0.5, 1)
    img.Position = UDim2.new(0.5, 0, 1, 8)
    img.ZIndex = Z + 1
    return img, TycoonConfig.PAD_SIZE + 8 - h
end

-- [D53] Ruina fiecarei platforme (fara plase: stalpul si plasa rupte au functia lor, mai jos) si scara ei.
local function ruinSprite(padId: string): (Assets.Sprite?, number)
    if BOARD_ICON[padId] ~= nil then
        return Assets.tycoon.board_old, TycoonConfig.PROP_SCALE
    elseif padId == "first_runner" then
        return Assets.tycoon.ruin_hut, Assets.PIXEL_SCALE
    elseif padId == "dock_trader" then
        return Assets.tycoon.ruin_stall, TycoonConfig.PROP_SCALE
    elseif padId == "bigger_sack" then
        return Assets.tycoon.ruin_sack, TycoonConfig.PROP_SCALE
    elseif padId == "landing_bell" then
        return Assets.tycoon.ruin_bell, Assets.PIXEL_SCALE
    elseif padId == "workshop" then
        return Assets.tycoon.ruin_workshop, Assets.PIXEL_SCALE
    end
    return nil, 1
end

-- Are platforma asta arta de ruina urcata? Fara ea, raman siluetele de dinainte.
local function ruinReady(pad: TycoonConfig.Pad): boolean
    if isNetPad(pad) then
        return Assets.has(Assets.tycoon.ruin_netpost) and Assets.has(Assets.tycoon.ruin_net)
    end
    local sprite = ruinSprite(pad.id)
    return sprite ~= nil and Assets.has(sprite :: Assets.Sprite)
end

local function worldImage(
    parent: Instance,
    sprite: Assets.Sprite,
    w: number,
    h: number,
    tint: Color3
): ImageLabel
    local img = Instance.new("ImageLabel")
    img.BackgroundTransparency = 1
    img.Image = Assets.url(sprite)
    img.ResampleMode = Enum.ResamplerMode.Pixelated
    img.Size = UDim2.fromOffset(w, h)
    img.ImageColor3 = tint
    img.ZIndex = Z
    img.Parent = parent
    return img
end

-- Ruina, pe locul exact al obiectului construit (aceeasi baza ca in styleBought; plasa pe banda ei, ca in
-- NetController). Intoarce tinta pentru puls/Flash si Y-ul local al varfului, ca pretul sa stea deasupra.
local function buildRuin(
    frame: TextButton,
    pad: TycoonConfig.Pad,
    locked: boolean
): (GuiObject?, number)
    local tint = if locked then LOCKED_TINT else Color3.new(1, 1, 1)
    if isNetPad(pad) then
        local post, net = Assets.tycoon.ruin_netpost, Assets.tycoon.ruin_net
        local lane = 1
        for _, e in pad.effects do
            if e.kind == "net" and e.lane ~= nil then
                lane = e.lane :: number
            end
        end
        local postImg = worldImage(
            frame,
            post,
            post.width * TycoonConfig.PROP_SCALE,
            post.height * TycoonConfig.PROP_SCALE,
            tint
        )
        postImg.Name = "RuinPost"
        postImg.AnchorPoint = Vector2.new(0.5, 1)
        postImg.Position = UDim2.new(0.5, 0, 0, HALF)
        local netY = HALF
            + ((TycoonConfig.LANE_Y[lane] or TycoonConfig.LANE_Y[1]) - (pad.y :: number))
        local netImg =
            worldImage(frame, net, TycoonConfig.NET_DRAW.w, TycoonConfig.NET_DRAW.h, tint)
        netImg.Name = "RuinNet"
        netImg.AnchorPoint = Vector2.new(0.5, 0.5)
        netImg.Position = UDim2.new(0.5, 0, 0, netY)
        netImg.ZIndex = Z + 1
        return netImg, netY - TycoonConfig.NET_DRAW.h / 2
    end
    local sprite, scale = ruinSprite(pad.id)
    local s = sprite :: Assets.Sprite
    local h = s.height * scale
    local img = worldImage(frame, s, s.width * scale, h, tint)
    img.Name = "Ruin"
    img.AnchorPoint = Vector2.new(0.5, 1)
    img.Position = UDim2.new(0.5, 0, 1, 8)
    img.ZIndex = Z + 1
    return img, TycoonConfig.PAD_SIZE + 8 - h
end

-- Pretul, deasupra obiectului stins. Text peste lume, fara panou -> Theme.punch, ca tot ce scrie
-- direct pe harta. Un singur rand: moneda + cifra. Numele nu se mai scrie nicaieri pe harta --
-- il spune obiectul insusi, linia "NEXT" din HUD si cartonasul de la apropiere.
local function priceTag(
    frame: TextButton,
    pad: TycoonConfig.Pad,
    topY: number,
    affordable: boolean
): number
    -- PLACA de sub pret: obiectul stins sta cel mai des peste APA, iar acolo o cifra aurie fara
    -- fundal se pierde in valuri (vazut in randarea mea, scripts/art/preview_locked.py). Aceeasi
    -- placa semi-transparenta ca la orice text asezat direct peste lume.
    local row = Instance.new("Frame")
    row.Name = "PriceTag"
    row.BackgroundColor3 = Theme.COLOR.plate
    row.BackgroundTransparency = Theme.PLATE_TRANSPARENCY
    row.AutomaticSize = Enum.AutomaticSize.X
    row.AnchorPoint = Vector2.new(0.5, 1)
    row.Position = UDim2.new(0.5, 0, 0, topY - 6)
    row.Size = UDim2.fromOffset(0, 28)
    row.ZIndex = Z + 3
    row.Parent = frame
    local pad8 = Instance.new("UIPadding")
    pad8.PaddingLeft = UDim.new(0, 10)
    pad8.PaddingRight = UDim.new(0, 10)
    pad8.Parent = row
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 8)
    corner.Parent = row
    local layout = Instance.new("UIListLayout")
    layout.FillDirection = Enum.FillDirection.Horizontal
    layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
    layout.VerticalAlignment = Enum.VerticalAlignment.Center
    layout.Padding = UDim.new(0, 4)
    layout.Parent = row
    local coin = Widgets.CoinIcon(row, 18, Z + 4)
    coin.LayoutOrder = 1
    local price = Widgets.Label(
        row,
        formatPrice(pad),
        Theme.TEXT.small,
        if affordable then Theme.COLOR.gold else Theme.COLOR.onDark,
        "display"
    )
    price.LayoutOrder = 2
    price.AutomaticSize = Enum.AutomaticSize.X
    price.Size = UDim2.fromOffset(0, 20)
    price.ZIndex = Z + 4
    Theme.punch(price, 2)
    return topY - 38
end

-- "outline": urmatoarea platforma, vizibila ca sa se stie ce urmeaza dar nu inca de cumparat.
-- Placuta greiata (sau, fara arta, patratul sters de azi): nume + pret, fara stralucire
-- [F2 spec Agent U pct.1 -- "plaque greyed, name + price visible, no glow"].
local function styleOutline(frame: TextButton, pad: TycoonConfig.Pad)
    clearContent(frame)
    ringSetters[pad.id] = nil
    needLabels[pad.id] = nil
    frame.BackgroundTransparency = 1
    -- "outline" = se vede ca acolo URMEAZA ceva, dar nu e randul lui inca: aceeasi silueta, si
    -- mai stinsa, si fara pret. Pretul apare cand platforma devine cumparabila.
    local target = buildGhost(frame, pad, false)
    if target ~= nil then
        for _, child in frame:GetChildren() do
            if child:IsA("ImageLabel") then
                child.ImageTransparency = 0.72
            end
        end
        plaques[pad.id] = target
        return
    end

    local stroke = Instance.new("UIStroke")
    stroke.Thickness = 2
    stroke.Color = Theme.COLOR.onDarkSoft
    stroke.Transparency = 0.4
    stroke.Parent = frame
    nameLabel(frame, pad, Theme.COLOR.onDarkSoft, 40, 26)
    plaques[pad.id] = frame
end

-- [D53] Incuiata: doar ruina, usor stinsa. Fara pret: pretul apare cand platforma devine cumparabila.
local function styleLocked(frame: TextButton, pad: TycoonConfig.Pad)
    clearContent(frame)
    ringSetters[pad.id] = nil
    needLabels[pad.id] = nil
    frame.BackgroundTransparency = 1
    plaques[pad.id] = buildRuin(frame, pad, true)
end

-- "available": placuta (sau patratul de azi) + pictograma + nume + pret. Fara bani: pretul rosu +
-- inel de progres (coins/price) + "Need N more" sub pret. Cu bani: stralucire aurie + puls -- indemnul
-- vizual de "calca aici" [docs/TYCOON.md B, F2 spec Agent U pct.1].
local function styleAvailable(frame: TextButton, pad: TycoonConfig.Pad, affordable: boolean)
    clearContent(frame)
    ringSetters[pad.id] = nil
    needLabels[pad.id] = nil
    frame.BackgroundTransparency = 1
    local needBottomY: number

    -- [D53] ruina, daca arta ei e urcata; altfel silueta de dinainte
    local target: GuiObject?, topY: number
    if ruinReady(pad) then
        target, topY = buildRuin(frame, pad, false)
    else
        target, topY = buildGhost(frame, pad, affordable)
    end
    if target ~= nil then
        needBottomY = priceTag(frame, pad, topY, affordable)
        plaques[pad.id] = target
        if affordable then
            -- ai banii: obiectul e aproape real si pulseaza auriu. Asta e tot indemnul de care
            -- e nevoie -- nu mai trebuie niciun text care sa spuna "calca aici".
            local glow = Instance.new("UIStroke")
            glow.Name = "Glow"
            glow.Thickness = 3
            glow.Color = Theme.COLOR.gold
            glow.Parent = target
            startPulse(glow, pad.id)
        end
    else
        -- fara arta pentru obiectul asta: patratul de azi tine locul, neschimbat [item 6]
        frame.BackgroundColor3 = Theme.COLOR.gold
        frame.BackgroundTransparency = 0.6
        local stroke = Instance.new("UIStroke")
        stroke.Name = "Edge"
        stroke.Thickness = 3
        stroke.Color = Theme.COLOR.gold
        stroke.Parent = frame
        nameLabel(frame, pad, Theme.COLOR.onDark, 40, 26)
        needBottomY = priceTag(frame, pad, 0, affordable)
        plaques[pad.id] = frame
        if affordable then
            startPulse(stroke, pad.id)
        end
    end

    if not affordable then
        -- Progresul spre pret, ca BARA sub placuta, nu ca inel in jurul platformei. Inelul era
        -- desenat cu un gradient orizontal peste un contur rotund: pe ecran se vedea un cerc
        -- negru in jurul stalpului, nu un progres (vazut in Studio, 2026-09-12).
        local track = Instance.new("Frame")
        track.Name = "ProgressTrack"
        track.AnchorPoint = Vector2.new(0.5, 0)
        track.Position = UDim2.new(0.5, 0, 0, needBottomY - 12)
        track.Size = UDim2.fromOffset(PROGRESS_W, 6)
        track.BackgroundColor3 = Theme.COLOR.woodDark
        track.BackgroundTransparency = 0.25
        track.BorderSizePixel = 0
        track.ZIndex = Z + 2
        local tc = Instance.new("UICorner")
        tc.CornerRadius = UDim.new(1, 0)
        tc.Parent = track
        track.Parent = frame

        local fill = Instance.new("Frame")
        fill.Name = "Fill"
        fill.Size = UDim2.fromScale(0, 1)
        fill.BackgroundColor3 = Theme.COLOR.gold
        fill.BorderSizePixel = 0
        fill.ZIndex = Z + 3
        local fc = Instance.new("UICorner")
        fc.CornerRadius = UDim.new(1, 0)
        fc.Parent = fill
        fill.Parent = track

        local function setProgress(progress: number, _bright: Color3, _dim: Color3)
            fill.Size = UDim2.fromScale(math.clamp(progress, 0, 1), 1)
        end
        setProgress(
            if pad.price > 0 then coins / pad.price else 1,
            Theme.COLOR.gold,
            Theme.COLOR.gold
        )
        ringSetters[pad.id] = setProgress
        needLabels[pad.id] = attachNeedLabel(frame, pad, needBottomY)
    end
end

-- Sprite-ul cladirii pentru o platforma CUMPARATA [F1 spec 4.5], plus scara la care se deseneaza:
-- recuzita mica (sac, lada, taraba, greutati) la PROP_SCALE, cladirile adevarate la PIXEL_SCALE --
-- un singur limbaj de marime [F3 spec item 3]. nil = "marcatorul curent" (stalp pentru plase, bifa
-- pentru rest), doar pentru orice sprite inca neincarcat (Assets.has = false).

-- Platforma pe care sta orice statie cumparata, in afara de plase (care stau direct pe ponton):
-- o dala mica, la PROP_SCALE, sub sprite-ul cladirii -- fara ea, lada/sacul/taraba pareau aruncate
-- pe iarba goala [F3 spec item 2]. Acelasi Assets.has ca oriunde: fara arta inca, pur si simplu nu
-- se deseneaza nimic [item 6].
local function drawPlatform(frame: Frame)
    if not Assets.has(Assets.tycoon.platform) then
        return
    end
    local plat = Instance.new("ImageLabel")
    plat.Name = "Platform"
    plat.BackgroundTransparency = 1
    plat.Image = Assets.url(Assets.tycoon.platform)
    plat.ResampleMode = Enum.ResamplerMode.Pixelated
    plat.AnchorPoint = Vector2.new(0.5, 1)
    -- acelasi +8 fata de baza cadrului ca sprite-ul cladirii de mai jos: platforma si cladirea
    -- impart exact aceeasi linie de sol, altfel una plutea fata de cealalta
    plat.Position = UDim2.new(0.5, 0, 1, 8)
    plat.Size = UDim2.fromOffset(
        Assets.tycoon.platform.width * TycoonConfig.PROP_SCALE,
        Assets.tycoon.platform.height * TycoonConfig.PROP_SCALE
    )
    plat.ZIndex = Z
    plat.Parent = frame
end

local function refreshWorkshopBadge()
    local badge = workshopBadge
    if badge == nil then
        return
    end
    badge.Text = tostring(workshopPile)
    badge.Visible = workshopPile > 0
end

-- "bought": stalp pe mal pentru platformele de plasa (plasa insasi o deseneaza NetController in
-- apa); pentru rest, o platforma [item 2] cu cladirea dedicata deasupra cand exista sprite-ul ei,
-- altfel o bifa. Fara stralucire -- nu mai e de vanzare, si nicio placuta -- platforma insasi
-- vorbeste acum [F2 spec Agent U pct.1]. Fara nume: numele traieste doar pe cartonasul de la
-- apropiere, cat timp platforma inca se cumpara -- o data cumparata, n-are nevoie de el [item 4].
local function styleBought(frame: TextButton, pad: TycoonConfig.Pad)
    clearContent(frame)
    ringSetters[pad.id] = nil
    needLabels[pad.id] = nil
    plaques[pad.id] = nil
    if pad.id == "workshop" then
        workshopBadge = nil
    end
    frame.BackgroundTransparency = 1
    -- Plasele NU se mai deseneaza aici: stalpul, franghia, plasa din apa, marfa dinauntru si
    -- cifra sunt un singur ansamblu, desenat de NetController [F3]. Cat le desena si acesta,
    -- pe ponton apareau doi stalpi peste aceeasi platforma.
    if isNetPad(pad) then
        return
    end

    -- [D53] avizierul curat, cu pictograma meseriei, in locul platformei cu bifa
    local iconFor = BOARD_ICON[pad.id]
    if iconFor ~= nil and Assets.has(Assets.tycoon.board) then
        local board = worldImage(
            frame,
            Assets.tycoon.board,
            Assets.tycoon.board.width * TycoonConfig.PROP_SCALE,
            Assets.tycoon.board.height * TycoonConfig.PROP_SCALE,
            Color3.new(1, 1, 1)
        )
        board.Name = "Board"
        board.AnchorPoint = Vector2.new(0.5, 1)
        board.Position = UDim2.new(0.5, 0, 1, 8)
        local icon = iconFor()
        if Assets.has(icon) then
            -- pe hartia avizierului: centrul ei e la 17 px de sprite deasupra bazei (x2 = 34)
            local fit = 24 / math.max(icon.width, icon.height)
            local mark =
                worldImage(frame, icon, icon.width * fit, icon.height * fit, Color3.new(1, 1, 1))
            mark.Name = "BoardIcon"
            mark.AnchorPoint = Vector2.new(0.5, 0.5)
            mark.Position = UDim2.new(0.5, 0, 1, 8 - 34)
            mark.ZIndex = Z + 1
        end
        return
    end

    -- orice statie non-plasa sta pe-o platforma, ca nimic sa nu ramana pe iarba goala [item 2]
    drawPlatform(frame)

    local sprite, scale = boughtSprite(pad.id)
    if sprite ~= nil and Assets.has(sprite) then
        local img = Instance.new("ImageLabel")
        img.Name = "Building"
        img.BackgroundTransparency = 1
        img.Image = Assets.url(sprite)
        img.ResampleMode = Enum.ResamplerMode.Pixelated
        img.AnchorPoint = Vector2.new(0.5, 1)
        img.Position = UDim2.new(0.5, 0, 1, 8)
        img.Size = UDim2.fromOffset(sprite.width * scale, sprite.height * scale)
        img.ZIndex = Z
        img.Parent = frame

        if pad.id == "workshop" then
            -- insigna cu numarul de obiecte care asteapta in gramada [F1 spec 4.5]
            local badge = Widgets.PlateLabel(frame, "0", Theme.TEXT.tiny, "strong")
            badge.AnchorPoint = Vector2.new(1, 0)
            badge.Position = UDim2.new(1, 6, 0, -10)
            badge.Size = UDim2.fromOffset(32, 24)
            badge.TextXAlignment = Enum.TextXAlignment.Center
            badge.TextColor3 = Theme.COLOR.gold
            badge.ZIndex = Z + 3
            badge.Visible = false
            workshopBadge = badge
            refreshWorkshopBadge()
        end
        return
    end

    -- marcatorul curent: sprite-ul nu e inca incarcat -- platforma de mai sus tot arata unde e statia
    local icon = Widgets.Icon(frame, "check", 26)
    if icon ~= nil then
        icon.AnchorPoint = Vector2.new(0.5, 1)
        icon.Position = UDim2.new(0.5, 0, 1, -22)
    end
end

-- [O2] O platforma se striveste scurt (0.9 -> 1) chiar in clipa in care se trage cumpararea --
-- raspuns imediat, inainte sa vina confirmarea serverului (care aduce Flourish-ul mai mare, la
-- PadBought). Vizual, nu logic: daca serverul refuza, platforma ramane oricum "available".
local function squash(frame: GuiObject)
    local scale = frame:FindFirstChildOfClass("UIScale") or Instance.new("UIScale")
    scale.Parent = frame
    scale.Scale = 0.9
    TweenService:Create(
        scale,
        TweenInfo.new(0.18, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
        { Scale = 1 }
    ):Play()
end

-- [D53] Ce trebuie facut intai langa ruina asta, sau nil daca nimic (ar trebui sa fie cumparabila).
local function ruinNeeds(pad: TycoonConfig.Pad): string?
    local bought: { [string]: boolean } = {}
    for id, status in statuses do
        if status == "bought" then
            bought[id] = true
        end
    end
    local blocker = TycoonMath.padBlocker(pad, bought, netLevels)
    return if blocker ~= nil then Strings.padNeeds(blocker) else nil
end

local function tryBuy(padId: string)
    if statuses[padId] ~= "available" then
        return
    end
    local last = firedAt[padId]
    if last ~= nil and os.clock() - last < 1 then
        return -- cooldown-ul de 1s inca nu a trecut
    end
    firedAt[padId] = os.clock()
    local frame = frames[padId]
    if frame ~= nil then
        squash(frame)
    end
    deps.Remotes.BuyPad:FireServer(padId)
end

-- Ce meniu tine de un obiect CUMPARAT. Plasele sunt fiecare meniul lor; o platforma de meserie deschide
-- meniul meseriei ("crew", rol), prin TycoonConfig.CREWS -- nu cate o ramura pe id [D49]. Traista mare,
-- atelierul si clopotul n-au niveluri: atelierul are panoul lui, pe E.
local function stationFor(pad: TycoonConfig.Pad): (string?, string?)
    if isNetPad(pad) then
        return "net", pad.id
    end
    local role = TycoonConfig.CREW_OF_PAD[pad.id]
    if role ~= nil then
        return "crew", role
    end
    return nil, nil
end

local function ensureFrame(pad: TycoonConfig.Pad): TextButton
    local existing = frames[pad.id]
    if existing ~= nil then
        return existing
    end
    local frame = Instance.new("TextButton")
    frame.Name = pad.id
    frame.AnchorPoint = Vector2.new(0.5, 0.5)
    frame.Position = UDim2.fromOffset(pad.x :: number, pad.y :: number)
    frame.Size = UDim2.fromOffset(TycoonConfig.PAD_SIZE, TycoonConfig.PAD_SIZE)
    frame.AutoButtonColor = false
    frame.Text = ""
    frame.BackgroundTransparency = 1
    frame.ZIndex = Z
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 12)
    corner.Parent = frame
    frame.Activated:Connect(function()
        -- Apasatul obiectului e a treia cale spre ACEEASI confirmare (dupa buton si E), nu o
        -- scurtatura in jurul ei: cumpara doar daca exact obiectul asta e pe cartonas. Altfel ai
        -- putea cumpara de la celalalt capat al malului ceva al carui pret nici nu l-ai vazut.
        if approachTarget == pad.id then
            tryBuy(pad.id)
            return
        end
        -- [D53] o ruina atinsa spune ce trebuie facut intai -- nu tace [D43]
        if statuses[pad.id] ~= "bought" and statuses[pad.id] ~= "available" then
            local needs = ruinNeeds(pad)
            if needs ~= nil then
                deps.OnToast(needs)
            end
            return
        end
        -- Cumparat: il atingi si ii ridici nivelul, ca la Idle Miner. Aceeasi mana, acelasi loc.
        if statuses[pad.id] == "bought" and deps.OpenStation ~= nil then
            local kind, id = stationFor(pad)
            if kind ~= nil then
                (deps.OpenStation :: (string, string?) -> ())(kind :: string, id)
            end
        end
    end)
    frame.Parent = deps.Plot
    frames[pad.id] = frame
    return frame
end

-- ---- cartonasul de la apropiere [F2 spec Agent U pct.2] ----

-- `nearestId`: platforma "available" cea mai apropiata aflata sub 220px, sau nil. Doar geometria
-- ramane aici -- continutul si aparitia cartonasului sunt in HUDController.ShowApproachCard/
-- HideApproachCard [F3 spec item 5]. Schimbarea tintei sau a afordabilitatii cere HUD-ului sa
-- refaca cartonasul; ramanerea pe aceeasi tinta, neschimbata, nu face nimic (fara reconstruiri
-- inutile la fiecare cadru).
local function updateApproachCard(nearestId: string?)
    if nearestId == nil then
        if approachTarget ~= nil then
            approachTarget = nil
            approachCoins = -1
            HUDController.HideApproachCard() -- "hides when you walk away" [F2 spec Agent U pct.2]
        end
        return
    end
    local pad = TycoonConfig.byId[nearestId] :: TycoonConfig.Pad
    local affordable = coins >= pad.price
    -- Se redeseneaza la schimbarea tintei, a pragului SI a banilor: randul "cat iti ramane" ar
    -- ramane altfel cu suma de la prima aparitie, iar dupa o vanzare ar minti [D40]. Banii se
    -- schimba doar la un TycoonState, nu la fiecare cadru, deci redesenarea ramane rara.
    if
        nearestId ~= approachTarget
        or affordable ~= approachAffordable
        or coins ~= approachCoins
    then
        if nearestId ~= approachTarget then
            approachShownAt = os.clock()
        end
        approachTarget = nearestId
        approachAffordable = affordable
        approachCoins = coins
        HUDController.ShowApproachCard(
            pad,
            padDeltas[nearestId] or 0,
            affordable,
            bottleneck,
            coins
        )
    end
end

-- Cumpara obiectul de pe cartonas, daca exista unul si ajung banii. Singurul drum spre `BuyPad`:
-- butonul cartonasului, tasta E (prin InteractController.Interact) si apasarea obiectului trec toate
-- pe aici. Intoarce true daca a trimis cererea, ca lantul de interactiune sa se opreasca.
function PadController.TryBuyFocused(): boolean
    local ruin = ruinTarget
    if approachTarget == nil and ruin ~= nil then
        -- [D53] E pe cartonasul unei ruine: acelasi text ca butonul stins, ca toast
        local needs = ruinNeeds(TycoonConfig.byId[ruin])
        if needs ~= nil then
            deps.OnToast(needs)
        end
        return true
    end
    local target = approachTarget
    if target == nil or os.clock() - approachShownAt < APPROACH_ARM_SECONDS then
        return false
    end
    local pad = TycoonConfig.byId[target]
    if pad == nil or statuses[target] ~= "available" or coins < pad.price then
        return false
    end
    tryBuy(target)
    return true
end

-- Starea vine din TycoonState, inlocuita in intregime la fiecare mesaj [F0 spec 4.1]. Se
-- reconstruieste vizualul doar cand statutul sau granita afordabil/neafordabil chiar se schimba --
-- altfel un Collect oarecare ar reporni pulsul fiecarei platforme accesibile de pe ecran.
function PadController.Apply(
    pads: { [string]: string },
    newCoins: number,
    deltas: { [string]: number },
    newBottleneck: string?,
    newNetLevels: { [string]: number }?
)
    statuses = pads
    coins = newCoins
    netLevels = newNetLevels or netLevels
    bottleneck = newBottleneck or bottleneck
    padDeltas = deltas
    for _, pad in TycoonConfig.PADS do
        if pad.x == nil or pad.y == nil then
            continue -- erele 2-4 n-au inca lume construita
        end
        local status = pads[pad.id]
        -- [D53] incuiata (ascunsa sau doar conturata) si cu arta de ruina: ruina se vede mereu
        if pad.era == 1 and (status == nil or status == "outline") and ruinReady(pad) then
            local frame = ensureFrame(pad)
            frame.Visible = true
            if lastStatus[pad.id] ~= "locked" then
                styleLocked(frame, pad)
            end
            lastStatus[pad.id] = "locked"
            continue
        end
        if status == nil then
            local frame = frames[pad.id]
            if frame ~= nil then
                frame.Visible = false
            end
            lastStatus[pad.id] = nil
            continue
        end
        local frame = ensureFrame(pad)
        frame.Visible = true
        if status == "available" then
            local affordable = coins >= pad.price
            if lastStatus[pad.id] ~= status or lastAffordable[pad.id] ~= affordable then
                styleAvailable(frame, pad, affordable)
                lastAffordable[pad.id] = affordable
            elseif not affordable then
                local setter = ringSetters[pad.id]
                if setter ~= nil then
                    setter(
                        if pad.price > 0 then coins / pad.price else 1,
                        Theme.COLOR.gold,
                        Theme.COLOR.woodDark
                    )
                end
                local need = needLabels[pad.id]
                if need ~= nil then
                    need.Text = `Need {math.max(0, math.ceil(pad.price - coins))} more`
                end
            end
        elseif lastStatus[pad.id] ~= status then
            if status == "outline" then
                styleOutline(frame, pad)
            elseif status == "bought" then
                styleBought(frame, pad)
            end
        end
        lastStatus[pad.id] = status
    end
end

-- Impins din Bootstrap la fiecare TycoonState (state.workshop, state.pile) [F1 spec 4.5].
function PadController.SetWorkshop(owned: boolean, pile: number)
    workshopOwned = owned
    workshopPile = pile
    refreshWorkshopBadge()
end

-- Aproape de atelier si e construit? Deschide panoul si intoarce true -- ultima veriga din
-- lantul de interactiune (dupa Collect si Sell) [F1 spec 4.5].
-- [D51] Cardul obiectelor construite pe platforme: atelierul (E il deschide) si platformele de meserie
-- cumparate (Upgrade = meniul meseriei). Plasele au cardul lor (NetController.Focus); traista mare si
-- clopotul n-au nici gest, nici niveluri.
function PadController.FocusBuilt(px: number, py: number): Focus.Focus?
    local best: Focus.Focus? = nil
    for _, pad in TycoonConfig.PADS do
        if statuses[pad.id] ~= "bought" or pad.x == nil or pad.y == nil then
            continue
        end
        local role = TycoonConfig.CREW_OF_PAD[pad.id]
        local isWorkshop = pad.id == "workshop" and workshopOwned
        if role == nil and not isWorkshop then
            continue
        end
        local x, y = pad.x :: number, pad.y :: number
        local d = Focus.distance(px, py, x, y)
        if
            d > RiverConfig.INTERACT_DISTANCE
            or (best ~= nil and d >= (best :: Focus.Focus).distance)
        then
            continue
        end
        local keyHint = if UserInputService.KeyboardEnabled then " (E)" else ""
        best = {
            key = `pad:{pad.id}`,
            distance = d,
            x = x,
            y = y - 56,
            action = if isWorkshop then Strings.promptWorkshop(keyHint) else nil,
            act = if isWorkshop
                then function()
                    WorkshopController.Open()
                end
                else nil,
            upgradeKind = if role ~= nil then "crew" else nil,
            upgradeId = role,
        }
    end
    return best
end

-- Platforma pe care ar arata-o cartonasul de cumparare acum si cat de departe e (math.huge = niciuna).
function PadController.ApproachCandidate(): (string?, number)
    return candidateId, candidateDistance
end

-- Ascunde cartonasul cat timp cardul unui obiect mai apropiat e pe ecran [D51].
function PadController.SetApproachSuppressed(on: boolean)
    if approachSuppressed == on then
        return
    end
    approachSuppressed = on
    if on then
        updateApproachCard(nil)
    end
end

-- Coordonatele PLOT ale platformei (acelasi sistem in care traiesc frame-urile de mai sus) --
-- agentul J stie de unde sa porneasca rafala de monede / eticheta "+delta/s" la PadBought
-- [F2 spec Agent U pct.5]. Expusa, dar apelata doar de celalalt agent.
function PadController.PadScreenPos(padId: string): (number, number)
    local pad = TycoonConfig.byId[padId]
    if pad == nil or pad.x == nil or pad.y == nil then
        return 0, 0
    end
    return pad.x :: number, pad.y :: number
end

-- Fulger alb de 120ms pe placuta platformei, la cumparare [F2 spec Agent U pct.5]. Tinta e placuta
-- (sau, fara arta, cadrul insusi) cat timp mai exista -- daca statutul "bought" a ajuns deja si a
-- sters-o, cade pe cadrul ramas (post/cladire), asa ca fulgerul tot are unde sa cada.
function PadController.Flash(padId: string)
    local target: GuiObject? = plaques[padId] or frames[padId]
    if target == nil then
        return
    end
    local t = target :: GuiObject
    local flash = Instance.new("Frame")
    flash.Name = "Flash"
    flash.BackgroundColor3 = Color3.new(1, 1, 1)
    flash.BackgroundTransparency = 0.15
    flash.Size = UDim2.fromScale(1, 1)
    flash.ZIndex = t.ZIndex + 5
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 10)
    corner.Parent = flash
    flash.Parent = t
    TweenService:Create(
        flash,
        TweenInfo.new(0.12, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
        { BackgroundTransparency = 1 }
    ):Play()
    task.delay(0.15, function()
        flash:Destroy()
    end)
end

function PadController.Init(d: Deps)
    deps = d
    -- butonul de pe cartonas: aceeasi functie ca tasta E si ca apasarea obiectului
    HUDController.SetApproachBuy(function()
        PadController.TryBuyFocused()
    end)

    RunService.PreRender:Connect(function()
        local cx, cy = deps.CharacterPos()
        local px, py = toPlotLocal(cx, cy)
        local nearestId: string? = nil
        local nearestD = math.huge -- cel mai mic INDEX de platforma din raza, nu cea mai mica distanta
        for _, pad in TycoonConfig.PADS do
            if pad.x == nil or pad.y == nil or statuses[pad.id] ~= "available" then
                continue
            end
            -- NU SE MAI CUMPARA CALCAND PE OBIECT. Owner-ul: "nu as vrea sa mai avem chestia asta
            -- cu doar du-te in acel obiect si se deblocheaza". Mersul aduce cartonasul (raza de
            -- mai jos); cumpararea cere o apasare. Pauza de o secunda dintre doua cereri ramane in
            -- tryBuy, pur pe timp: vechea rearmare "cand iesi de pe platforma" ar fi anulat-o,
            -- pentru ca acum cumperi de la distanta, deci aproape mereu esti in afara ei.
            --
            -- Din platformele aflate in raza, o alegem pe PRIMA din drum (index mic), nu pe cea
            -- mai apropiata: la start stai intre First Net si Second Net, iar cartonasul arata
            -- "Second Net" in timp ce sageata te trimite la prima -- doua indicatii contrare
            -- [vazut in Studio, 2026-09-12]. Distanta ramane doar filtrul de raza.
            local dx, dy = px - (pad.x :: number), py - (pad.y :: number)
            if math.sqrt(dx * dx + dy * dy) < APPROACH_RADIUS and pad.index < nearestD then
                nearestId = pad.id
                nearestD = pad.index
            end
        end
        candidateId = nearestId
        candidateDistance = math.huge
        if nearestId ~= nil then
            local near = TycoonConfig.byId[nearestId] :: TycoonConfig.Pad
            candidateDistance = Focus.distance(px, py, near.x :: number, near.y :: number)
        end

        -- [D53] Nimic de cumparat in raza: cea mai apropiata ruina incuiata, dupa RUIN_DWELL secunde langa
        -- ea. Distanta ei nu concureaza cu cardul unui obiect (ramane infinita): Take logs bate o ruina.
        local ruinId: string? = nil
        if nearestId == nil then
            local best = RUIN_RADIUS
            for _, pad in TycoonConfig.PADS do
                local frame = frames[pad.id]
                if
                    pad.era ~= 1
                    or pad.x == nil
                    or statuses[pad.id] == "bought"
                    or statuses[pad.id] == "available"
                    or frame == nil
                    or not frame.Visible
                then
                    continue
                end
                local dist = Focus.distance(px, py, pad.x :: number, pad.y :: number)
                if dist < best then
                    best = dist
                    ruinId = pad.id
                end
            end
        end
        if ruinId ~= ruinCandidate then
            ruinCandidate = ruinId
            ruinCandidateSince = os.clock()
        end
        local showRuin = ruinId ~= nil
            and not approachSuppressed
            and os.clock() - ruinCandidateSince >= RUIN_DWELL
        if ruinId ~= nil and candidateId == nil then
            candidateId = ruinId -- distanta ramane math.huge
        end

        updateApproachCard(if approachSuppressed then nil else nearestId)
        if nearestId == nil then
            if showRuin then
                local pad = TycoonConfig.byId[ruinId :: string]
                local needs = ruinNeeds(pad)
                if needs ~= nil and ruinTarget ~= ruinId then
                    ruinTarget = ruinId
                    local eyebrow = if BOARD_ICON[pad.id] ~= nil
                        then Strings.PAD_EYEBROW_WANTED
                        else Strings.PAD_EYEBROW_RUINS
                    HUDController.ShowRuinCard(pad, eyebrow, needs)
                elseif needs == nil and ruinTarget ~= nil then
                    ruinTarget = nil
                    HUDController.HideApproachCard()
                end
            elseif ruinTarget ~= nil then
                ruinTarget = nil
                HUDController.HideApproachCard()
            end
        else
            ruinTarget = nil
        end
    end)

    -- PadBought si PadRejected NU se asculta aici: momentul cumpararii (fulger pe placuta,
    -- explozie, "Built!", "+x/s" spre HUD, ceremonie) si refuzul ("Need N more coins") apartin
    -- in intregime lui Overlay. Cand le tratau amandoua, jucatorul vedea doua efecte peste
    -- acelasi eveniment si doua mesaje diferite pentru acelasi refuz.
end

return PadController
