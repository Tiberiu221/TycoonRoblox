# Game feel și efecte vizuale în GUI 2D (ScreenGui) pe Roblox

## Rezumat executiv

- `TweenService` este singurul mecanism nativ de animație pentru `GuiObject` — API stabil, gratuit ca „cost de licențiere", dar costul real e pe CPU client (fiecare tween activ e evaluat în fiecare frame). Nu există o limită numerică documentată de Roblox pentru câte tween-uri poți avea simultan; comunitatea recomandă disciplină, nu cantitate ("un joc nu are nevoie de tween-uri peste tot ca să arate bine" — thread oficial de performanță, vezi Surse).
- `ParticleEmitter` **nu poate fi parentat pe un `GuiObject`/`ScreenGui`** — funcționează doar pe `BasePart`/`Attachment` în lumea 3D (confirmat pe pagina oficială a clasei). Pentru Driftwood (2D pur), singura cale de particule e un pool de `ImageLabel`-uri reciclate manual — nu e opțional, e singura opțiune tehnică.
- Nu există un `Workspace.TimeScale` nativ în Roblox. Time-scale/slow-motion e implementat mereu manual, prin librării terțe (ex. „MoonScale") sau cod propriu care scalează `deltaTime` — hit-stop-ul pe Driftwood trebuie construit de la zero, nu bifat dintr-o proprietate a motorului.
- `Tween:Pause()` urmat de `Tween:Play()` **reia din poziția în care a fost oprit** (nu resetează) — `Cancel()` resetează la starea inițială. Diferența contează pentru hit-stop și pentru pauze de UI.
- Ecosistemul de librării de „motion" e fragmentat și inegal întreținut: **Fusion** (dphfox/Fusion, push 2026-02-02, 795★) și **Ripple** (littensy/ripple, push 2026-07-18, 128★) sunt active în 2026; **Flipper** (Reselim/Flipper, ultimul push 2021-11-25, 144★) e practic abandonat de ~5 ani deși încă funcțional; „Otter" ca librărie de referință istorică (evaera/Otter) **nu mai există pe GitHub** (404) — orice mențiune a ei azi e învechită.
- Pentru un motor de retenție bazat pe „prindere rară" (obiect rar în plasă), pattern-ul de reveal folosit consistent de jocuri Roblox de tip gacha/loot (confirmat indirect din discuții oficiale de dezvoltatori, nu dintr-un studiu al Fisch/Pet Sim în sine — vezi nota de sursă secundară) e: culoare-cod pe raritate + fundal/starburst + puls de particule + sunet distinct + scurtă pauză vizuală înainte de reveal. Nimic din asta cere 3D.
- `UIGradient`, `UIStroke`, `UICorner`, `UIPadding` sunt cele patru „UI modifiers" folosite pentru 90% din polish-ul vizual ieftin (glow, contur, colțuri rotunjite, spațiere) fără instanțe suplimentare de randat.
- Apă animată în 2D pur nu se face cu `ImageRectOffset` (asta e pentru sprite sheets/atlas), ci cu `ScaleType = Enum.ScaleType.Tile` + `TileSize` + scroll prin animarea `Offset`-ului unui `UIGradient` sau prin deplasarea propriu-zisă a unui `ImageLabel` mai mare decât fereastra vizibilă, într-un `Frame` cu `ClipsDescendants = true`.
- `CanvasGroup` permite `GroupTransparency`/`GroupColor3` pe un întreg subarbore dintr-un singur tween — util pentru fade-in/out de paneluri complexe — dar documentația oficială nu specifică un cost exact; tratează-l ca "mai scump decât un Frame simplu" (randare prin buffer separat) și nu îl abuza pe elemente care se redesenează des.
- `RunService:BindToRenderStep()` e recomandat oficial în locul conectării directe la `RenderStepped` pentru efecte vizuale per-frame (screen shake, particule) — dă control explicit asupra priorității de randare.

## Fapte verificate

- `TweenService:Create(instance, tweenInfo, propertyTable): Tween` este singura metodă de creare a unui tween; sursa: https://create.roblox.com/docs/reference/engine/classes/TweenService (fără dată vizibilă pe pagină, verificat 2026-09-08); încredere: ridicata.
- `TweenInfo.new(time, easingStyle, easingDirection, repeatCount, reverses, delayTime)` — valori implicite: `time=1`, `easingStyle=Enum.EasingStyle.Quad`, `easingDirection=Enum.EasingDirection.Out`, `repeatCount=0`, `reverses=false`, `delayTime=0`; sursa: https://create.roblox.com/docs/reference/engine/datatypes/TweenInfo ; încredere: ridicata.
- `Enum.EasingStyle` are 11 valori documentate: Linear, Sine, Back, Quad, Quart, Quint, Bounce, Elastic, Exponential, Circular, Cubic; niciuna marcată deprecated; sursa: https://create.roblox.com/docs/reference/engine/enums/EasingStyle ; încredere: ridicata.
- `TweenBase:Pause()` oprește fără resetare, `Play()` reia din poziția pauzată, `Cancel()` resetează la starea inițială; există evenimentul `Completed(playbackState: Enum.PlaybackState)`; sursa: https://create.roblox.com/docs/reference/engine/classes/TweenBase ; încredere: ridicata.
- Proprietăți tweenable pe `GuiObject` confirmate în ghidul oficial: `Position`, `Size`, `Rotation`, `BackgroundTransparency`/`ImageTransparency`/`TextTransparency`, `BackgroundColor3`/`ImageColor3`/`TextColor3`, plus proprietăți `UIStroke` (`Color`, `Thickness`, `Transparency`); sursa: https://create.roblox.com/docs/ui/animation ; încredere: ridicata.
- `TweenPosition`/`TweenSize`/`TweenSizeAndPosition` de pe `GuiObject` sunt **deprecated**, se recomandă `TweenService` modern; sursa: https://create.roblox.com/docs/reference/engine/classes/GuiObject ; încredere: ridicata.
- `ParticleEmitter` se parentează doar pe `Attachment`/`BasePart` în lumea 3D, nu pe `GuiObject`; sursa: https://create.roblox.com/docs/reference/engine/classes/ParticleEmitter ; încredere: ridicata.
- `ScaleType.Tile` face motorul să "randeze imaginea sursă de câte ori e nevoie pentru a umple spațiul elementului UI"; `TileSize` (UDim2) definește dimensiunea fiecărei repetiții, ex. `UDim2.new(0, 64, 0, 64)`; sursa: https://create.roblox.com/docs/reference/engine/classes/ImageLabel ; încredere: ridicata.
- `UIGradient` are proprietățile `Color` (ColorSequence), `Transparency` (NumberSequence), `Offset` (Vector2), `Rotation` (number), `Enabled` (bool), plus `Scale`/`TileMode`/`Type` menționate fără detaliere completă în extras; sursa: https://create.roblox.com/docs/reference/engine/classes/UIGradient ; încredere: medie (proprietăți suplimentare neconfirmate în detaliu).
- `UIStroke` are `Color`, `Thickness`, `Transparency`, `ApplyStrokeMode`, `LineJoinMode`, `Enabled`, `BorderStrokePosition`... ; sursa: https://create.roblox.com/docs/reference/engine/classes/UIStroke ; încredere: ridicata pentru lista de proprietăți, medie pentru valorile implicite (nespecificate în extras).
- `UICorner` are `CornerRadius` plus `TopLeftRadius`/`TopRightRadius`/`BottomLeftRadius`/`BottomRightRadius`, toate de tip `UDim`; sursa: https://create.roblox.com/docs/reference/engine/classes/UICorner ; încredere: ridicata.
- `UIPadding` are `PaddingTop`/`PaddingBottom`/`PaddingLeft`/`PaddingRight`, toate `UDim`; sursa: https://create.roblox.com/docs/reference/engine/classes/UIPadding ; încredere: ridicata.
- `CanvasGroup` expune `GroupColor3` și `GroupTransparency` pentru a tween-ui întreg subarborele dintr-o mișcare; sursa: https://create.roblox.com/docs/reference/engine/classes/CanvasGroup ; încredere: medie (pagina nu detaliază costul de randare în extrasul obținut).
- Nu există `Workspace.TimeScale` nativ documentat; slow-motion/time-scale e implementat mereu prin soluții proprii sau librării terțe (ex. "MoonScale", thread devforum #4143911); sursa: https://devforum.roblox.com/search.json?q=workspace%20TimeScale%20property și https://create.roblox.com/docs/reference/engine/classes/Workspace (proprietatea nu apare) ; încredere: medie-ridicata (absență confirmată pe pagina oficială a Workspace, dar nu e o interogare exhaustivă de changelog).
- `RunService:BindToRenderStep()` e recomandat oficial peste conectarea directă la `RenderStepped` pentru control de prioritate în efecte vizuale; sursa: https://create.roblox.com/docs/reference/engine/classes/RunService ; încredere: medie (parafrazat din extras, nu citat literal).
- Librăria **spr** (Fraktality/spr): "Small and fast motion library", ultimul push 2024-07-31, nearhivată, 4 issue-uri deschise; API: `spr.target(instance, dampingRatio, frequency, {Property = target})`; sursa: https://github.com/Fraktality/spr (README) + https://api.github.com/repos/Fraktality/spr ; încredere: ridicata.
- Librăria **Flipper** (Reselim/Flipper): "A motion library for Roblox", ultimul push **2021-11-25**, 144★, 1 issue deschis, nearhivată dar fără activitate de ~5 ani; sursa: https://api.github.com/repos/Reselim/Flipper ; încredere: ridicata.
- Librăria **Ripple** (littensy/ripple): "🎨 An elegant motion library for Roblox", ultimul push **2026-07-18**, 128★, MIT, inspirată din react-spring, oferă `createSpring`, `createTween`, `createMotion`, compatibilă cu React (Roact) și cu vanilla Luau; sursa: https://github.com/littensy/ripple + https://api.github.com/repos/littensy/ripple ; încredere: ridicata.
- Librăria **Fusion** (dphfox/Fusion): "Futuristic Luau for every universe", ultimul push **2026-02-02**, 795★, 64 issue-uri deschise, activă în 2026, folosită frecvent pentru UI reactiv cu animații/springuri integrate; sursa: https://api.github.com/repos/dphfox/Fusion ; încredere: ridicata.
- Librăria "Otter" ca proiect distinct de referință istorică nu are un repo public identificabil azi (căutare `evaera/Otter` → 404; există `azumanga/Otter`, ultimul push 2022-08-02, 1★, adopție neglijabilă); sursa: https://api.github.com/repos/evaera/Otter (404) + https://api.github.com/search/repositories?q=otter+roblox+animation ; încredere: medie (nu pot confirma dacă Otter istoric a fost redenumit/arhivat sub alt cont — NEVERIFICAT complet).
- Thread oficial de performanță recomandă: dezactivarea vizibilității (`Visible=false`) în loc de doar a muta elementele în afara ecranului, `UICorner` are cost mai mare decât imagini 9-slice pentru colțuri rotunjite, și pooling de instanțe în loc de creare/distrugere repetată; sursa: https://devforum.roblox.com/t/performance-considerations-improvements-and-optimizations-when-making-a-game/817499 (postat 2020-10-12, actualizat 2023-08-12) ; încredere: medie (sursă devforum, nu documentație oficială, dar thread de referință larg citat).
- `MaxVisibleGraphemes` pe `TextLabel` permite efect typewriter prin incrementare progresivă; sursa: https://create.roblox.com/docs/reference/engine/classes/TextLabel ; încredere: ridicata.
- Discuție devforum din 2025-06 despre satisfacția la drop-uri rare recomandă: codare pe culoare per raritate, fundaluri tip "starburst", particule/sclipici, contrast (fundal negru solid, nu gri); exemplu de rate menționate în context (Grand 12%, Unreal 8%, Illegal 2%) — **specifice acelui joc, nu Driftwood**; sursa: https://devforum.roblox.com/t/how-can-i-make-rare-drops-feel-more-satisfying-to-get/3743045 (2025-06-16/17) ; încredere: scazuta-medie (sursă secundară, opinii de comunitate, nu date de la Roblox).
- Rarity reveal specific din Fisch/Pet Simulator (culori exacte pe raritate, durate exacte de animație, praguri de "secret catch") — **NEVERIFICAT**: pagina fandom Fisch a fost blocată (HTTP 403/402 la fetch), iar bugetul de căutare web al sesiunii s-a epuizat înainte de a găsi o sursă oficială/verificabilă pentru mecanica exactă a acestor jocuri. Recomandările din secțiunea „Detalii" pentru reveal-ul de raritate sunt pattern-uri generice de design de joc confirmate indirect prin discuția devforum de mai sus, nu replici documentate ale Fisch/Pet Sim.

## Detalii

### 1. TweenService pe GuiObject — mecanica exactă

`TweenService` e un serviciu (`game:GetService("TweenService")`), nu se instanțiază. Semnătura completă:

```lua
local TweenService = game:GetService("TweenService")

local tweenInfo = TweenInfo.new(
    0.35,                        -- time (secunde)
    Enum.EasingStyle.Back,       -- easingStyle
    Enum.EasingDirection.Out,    -- easingDirection
    0,                           -- repeatCount (0 = o singură dată; -1 = infinit)
    false,                       -- reverses
    0                            -- delayTime
)

local tween = TweenService:Create(netFrame, tweenInfo, {
    Size = UDim2.fromScale(1.1, 1.1),
    BackgroundColor3 = Color3.fromRGB(255, 230, 150),
})

tween:Play()
tween.Completed:Connect(function(playbackState)
    if playbackState == Enum.PlaybackState.Completed then
        -- lanțuiește următorul tween aici
    end
end)
```

Reguli confirmate din documentație:
- Doar proprietăți **tweenable** (numerice, `UDim2`, `Color3`, `Vector2`/`Vector3`, `CFrame`) pot fi în `propertyTable`; proprietăți non-numerice (ex. `Text` ca string) nu pot fi tween-uite direct.
- Poți combina oricâte proprietăți într-un singur `Create` — un tween = un obiect `Tween`, dar poți actualiza mai multe proprietăți simultan, interpolate cu aceeași curbă de easing.
- `Tween:Pause()` + `Tween:Play()` reia din poziția curentă; `Tween:Cancel()` resetează instant proprietățile la valoarea dinaintea tween-ului (nu la valoarea originală dacă alt cod a modificat proprietatea între timp — comportament de reținut).
- Pentru înlănțuire de animații (ex: apare → pulsează → dispare), pattern-ul oficial e conectarea la `Completed` și pornirea următorului tween acolo, nu `wait()`.

### 2. Screen shake pe container 2D (fără cameră 3D)

Roblox nu are shake de cameră nativ pentru GUI (asta există doar pentru `Camera` 3D via `CFrame` jitter). Pentru Driftwood, „lumea" e desenată într-un `Frame` container (ex. `WorldRoot`) care conține râul, malurile, plasele. Shake = offset temporar aplicat pe `Position` a acestui container, randat per-frame cu `RunService:BindToRenderStep`, NU cu `TweenService` (tween-urile interpolează lin către o țintă, nu generează zgomot aleator eficient).

```lua
local RunService = game:GetService("RunService")

local WorldRoot = playerGui.MainUI.WorldRoot :: Frame
local basePosition = WorldRoot.Position

local shakeIntensity = 0
local shakeDuration = 0
local shakeElapsed = 0

local function updateShake(_, deltaTime)
    if shakeElapsed >= shakeDuration then
        WorldRoot.Position = basePosition
        RunService:UnbindFromRenderStep("DriftwoodShake")
        return
    end
    shakeElapsed += deltaTime
    local falloff = 1 - (shakeElapsed / shakeDuration)
    local offsetX = (math.random() * 2 - 1) * shakeIntensity * falloff
    local offsetY = (math.random() * 2 - 1) * shakeIntensity * falloff
    WorldRoot.Position = basePosition + UDim2.fromOffset(offsetX, offsetY)
end

local function shakeScreen(intensityPixels: number, durationSeconds: number)
    shakeIntensity = intensityPixels
    shakeDuration = durationSeconds
    shakeElapsed = 0
    RunService:BindToRenderStep("DriftwoodShake", Enum.RenderPriority.Last.Value, updateShake)
end

-- exemplu: obiect rar prins
shakeScreen(6, 0.25)
```

`BindToRenderStep` e recomandarea oficială pentru actualizări vizuale per-frame în loc de `RenderStepped:Connect`, pentru că îți dă control asupra `Enum.RenderPriority` — util ca shake-ul să se aplice după ce alte sisteme și-au terminat actualizările poziției (sursă: pagina `RunService`).

**Risc de accesibilitate confirmat de comunitate**: un thread devforum recent (postat 2026-08-06) menționează explicit că shake-ul pe countdown-uri e riscant pentru jucători fotosensibili — pune un toggle „reduce motion" în opțiuni dacă shake-ul devine intens sau frecvent.

### 3. Particule 2D via pool de ImageLabel — singura opțiune tehnică

Pentru că `ParticleEmitter` nu poate fi parentat pe `GuiObject`/`ScreenGui` (confirmat pe pagina oficială a clasei), orice „particulă" în Driftwood (stropi de apă la aruncarea plasei, scântei la reparație, sclipici la raritate) e un `ImageLabel` mic, manipulat manual. Pentru performanță, NU crea/distruge instanțe la fiecare particulă (recomandare explicită din thread-ul oficial de performanță: pooling în loc de create/destroy).

```lua
-- ParticlePool.lua (modul client)
local ParticlePool = {}
ParticlePool.__index = ParticlePool

function ParticlePool.new(parent: GuiObject, poolSize: number, image: string)
    local self = setmetatable({}, ParticlePool)
    self._free = {}
    self._active = {}
    for i = 1, poolSize do
        local label = Instance.new("ImageLabel")
        label.Name = "Particle"
        label.Image = image
        label.BackgroundTransparency = 1
        label.Size = UDim2.fromOffset(8, 8)
        label.Visible = false
        label.Parent = parent
        table.insert(self._free, label)
    end
    return self
end

function ParticlePool:Emit(position: UDim2, velocity: Vector2, lifetime: number)
    local label = table.remove(self._free)
    if not label then
        return -- pool epuizat: mai bine pierzi o particulă decât să aloci una noua în timpul jocului
    end
    label.Position = position
    label.Visible = true
    label.ImageTransparency = 0
    table.insert(self._active, {
        label = label,
        velocity = velocity,
        elapsed = 0,
        lifetime = lifetime,
    })
end

function ParticlePool:Update(deltaTime: number)
    for i = #self._active, 1, -1 do
        local p = self._active[i]
        p.elapsed += deltaTime
        if p.elapsed >= p.lifetime then
            p.label.Visible = false
            table.remove(self._active, i)
            table.insert(self._free, p.label)
        else
            local alpha = p.elapsed / p.lifetime
            p.label.Position += UDim2.fromOffset(p.velocity.X * deltaTime, p.velocity.Y * deltaTime)
            p.label.ImageTransparency = alpha
        end
    end
end

return ParticlePool
```

Actualizezi `pool:Update(deltaTime)` dintr-un singur `RunService:BindToRenderStep` central (nu unul per pool) — cu zeci de particule active, un singur loop de update e mult mai ieftin decât zeci de tween-uri separate.

**Dimensionare pool**: nu există un număr „oficial" — pentru un stropi-de-apă la fiecare aruncare de plasă plus câteva scântei la reparație, un pool de 40-80 `ImageLabel`-uri per efect e un punct de plecare rezonabil de testat în Studio cu profiler-ul (F9 → Memory/Frame time), nu un număr validat de Roblox.

### 4. UIGradient / UIStroke / UICorner / UIPadding — rețete

**Glow pulsatoriu pe un buton important (ex. buton de reparație gata)**:
```lua
local stroke = Instance.new("UIStroke")
stroke.Color = Color3.fromRGB(255, 210, 90)
stroke.Thickness = 2
stroke.Parent = repairButton

TweenService:Create(stroke, TweenInfo.new(0.8, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true), {
    Thickness = 5,
}):Play()
```
`repeatCount = -1` + `reverses = true` = puls continuu dus-întors, fără cod suplimentar de loop.

**Shine/sweep pe un card de raritate** (linie de lumină care traversează cardul la reveal): folosește `UIGradient` cu `Rotation` fix și animează `Offset.X` de la -1 la 1:
```lua
local shine = Instance.new("UIGradient")
shine.Color = ColorSequence.new({
    ColorSequenceKeypoint.new(0, Color3.new(1,1,1)),
    ColorSequenceKeypoint.new(0.5, Color3.new(1,1,1)),
    ColorSequenceKeypoint.new(1, Color3.new(1,1,1)),
})
shine.Transparency = NumberSequence.new({
    NumberSequenceKeypoint.new(0, 1),
    NumberSequenceKeypoint.new(0.45, 1),
    NumberSequenceKeypoint.new(0.5, 0.2),
    NumberSequenceKeypoint.new(0.55, 1),
    NumberSequenceKeypoint.new(1, 1),
})
shine.Rotation = 20
shine.Offset = Vector2.new(-1, 0)
shine.Parent = rarityCard

TweenService:Create(shine, TweenInfo.new(0.6, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
    Offset = Vector2.new(1, 0),
}):Play()
```

**Colțuri rotunjite**: `UICorner.CornerRadius = UDim.new(0, 12)` (offset în pixeli) sau `UDim.new(0.5, 0)` (scale, pentru cerc perfect pe un pătrat). Notă din thread-ul oficial de performanță: `UICorner` costă mai mult decât o imagine 9-slice pre-desenată cu colțuri rotunjite — pentru elemente statice repetate masiv (ex. sute de sloturi de inventar), ia în calcul 9-slice; pentru câteva paneluri principale, `UICorner` e suficient de ieftin.

**Spațiere consistentă**: `UIPadding` cu `PaddingTop/Bottom/Left/Right` — util în liste de obiecte reparate/index de colecție, combinat cu `UIListLayout`.

### 5. Apă animată — ScaleType.Tile, nu ImageRectOffset

Confuzie frecventă: `ImageRectOffset`/`ImageRectSize` sunt pentru **sprite sheets** (decupezi o sub-regiune dintr-o imagine mare — util pentru animații cadru-cu-cadru tip flipbook), NU pentru texturi repetate. Pentru apă care curge continuu:

```lua
local water = Instance.new("ImageLabel")
water.Image = "rbxassetid://<id_textura_apa_seamless>"
water.ScaleType = Enum.ScaleType.Tile
water.TileSize = UDim2.new(0, 128, 0, 128) -- fiecare tile = 128x128px
water.Size = UDim2.fromScale(1, 1)
water.Parent = riverFrame
```

`ScaleType.Tile` randeaza imaginea sursă repetat pentru a umple elementul (confirmat oficial). Pentru mișcare (scroll), două tehnici valide:

**A) Scroll prin UIGradient.Offset** — dacă efectul de "curgere" e doar o nuanță/luminozitate suprapusă peste apa statică, animezi `Offset` pe un `UIGradient` (ca la shine, dar în loop continuu cu `repeatCount = -1`).

**B) Scroll real de textură** — `TileSize` NU are un offset de animat direct documentat pentru scroll continuu; soluția funcțională e un `ImageLabel` mult mai lat decât fereastra vizibilă (ex. de 3x lățimea ecranului, cu tile-uri seamless), plasat într-un `Frame` cu `ClipsDescendants = true`, și animezi `Position.X` cu un tween linear infinit sau prin actualizare manuală în `RenderStepped`:
```lua
local speed = 40 -- pixeli/secundă, variază pe sezon conform brief-ului Driftwood
RunService:BindToRenderStep("RiverScroll", Enum.RenderPriority.First.Value, function(_, dt)
    local pos = water.Position
    local newX = pos.X.Offset - speed * dt
    if newX <= -water.AbsoluteSize.X / 2 then
        newX += water.AbsoluteSize.X / 2 -- reset când o "placă" a ieșit complet
    end
    water.Position = UDim2.new(pos.X.Scale, newX, pos.Y.Scale, pos.Y.Offset)
end)
```
Viteza variabilă pe sezon (menționată în brief-ul Driftwood) se leagă direct de variabila `speed` de mai sus, controlată server-side prin un `RemoteEvent`/atribut replicat, nu hardcodată client-side (regula de arhitectură din brief: server autoritar).

### 6. Parallax layers

Straturi multiple de `ImageLabel` (cer, dealuri îndepărtate, copaci apropiați, apă) în spatele `WorldRoot`, fiecare cu propriul `RenderPriority`/multiplicator de viteză relativ la scroll-ul principal al râului (ex. cer 0.1x, dealuri 0.3x, mal apropiat 1x). Tehnic, e aceeași buclă ca la apă (secțiunea 5B), aplicată la N layere cu `speed * multiplier`. Nu există o clasă specială "Parallax" în Roblox — e pattern manual, valabil identic pentru orice motor 2D.

### 7. Tentă zi-noapte și overlay de vreme

Nu există `ColorCorrectionEffect` funcțional în GUI pur (acela e un efect de `Lighting`, afectează doar randarea 3D) — pentru 2D, tenta zi-noapte se face fie:
- **(a)** un `Frame` full-screen deasupra întregii scene, cu `BackgroundColor3` portocaliu/albastru și `BackgroundTransparency` ridicată (~0.7-0.85), tween-uit lent (minute, sincron cu ciclul zi-noapte al jocului), sau
- **(b)** `ImageColor3` tween-uit direct pe fiecare layer de fundal (mai scump vizual — colorează fiecare strat, nu doar adaugă o peliculă), util dacă vrei ca elementele din prim-plan (personaj, plase) să nu fie afectate.

```lua
local overlay = mainUI.NightOverlay
TweenService:Create(overlay, TweenInfo.new(180, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut), {
    BackgroundColor3 = Color3.fromRGB(20, 30, 70),
    BackgroundTransparency = 0.6,
}):Play()
```

**Overlay de vreme** (ploaie/ceață): un al doilea `Frame` full-screen, `ZIndex` mare, cu un `ImageLabel` tile de dungi de ploaie scrollat vertical rapid (aceeași tehnică ca apa, direcție Y) + `BackgroundTransparency` variabil pentru ceață.

### 8. Hit-stop (fără TimeScale nativ)

Pentru că `Workspace.TimeScale` nu există ca proprietate nativă (verificat pe pagina oficială — absentă din listă), hit-stop-ul se implementează manual. Pentru Driftwood (2D, fără fizică de coliziune complexă), cea mai simplă variantă: la momentul de impact (ex. plasa prinde un obiect rar), oprești temporar buclele de update proprii (mișcarea râului, animațiile de particule) pentru câteva zeci de milisecunde, apoi le reiei — NU opri `TweenService` global (nu există un „pause all tweens", trebuie ținută o listă de tween-uri active de pus pe pauză individual dacă vrei acest efect și pe ele).

```lua
local isFrozen = false

local function hitStop(durationSeconds: number)
    isFrozen = true
    task.delay(durationSeconds, function()
        isFrozen = false
    end)
end

-- în bucla de scroll a râului (secțiunea 5B):
RunService:BindToRenderStep("RiverScroll", Enum.RenderPriority.First.Value, function(_, dt)
    if isFrozen then return end
    -- ... update poziție ...
end)
```

Pentru un „freeze frame" mai dramatic (flash alb + pauză totală, tipic pentru catch rar), combină cu tween instant de `ImageTransparency` pe un `Frame` alb full-screen (0 → 1 în ~80-120ms).

### 9. Number pop-ups și feedback sonor

**Pop-up de număr** (ex. "+3 pești", "+250 monede" la donație în atelier):
```lua
local function spawnNumberPopup(text: string, startPos: UDim2, color: Color3)
    local label = numberPopupTemplate:Clone()
    label.Text = text
    label.TextColor3 = color
    label.Position = startPos
    label.TextTransparency = 0
    label.Parent = popupLayer

    local tween = TweenService:Create(label, TweenInfo.new(0.9, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
        Position = startPos + UDim2.fromOffset(0, -40),
        TextTransparency = 1,
    })
    tween:Play()
    tween.Completed:Connect(function()
        label:Destroy()
    end)
end
```
Notă de performanță: dacă numerele apar des (ex. râu cu multe obiecte mici), preferă un pool similar celui de particule în loc de `Clone`/`Destroy` pe fiecare popup.

**Sunet**: `Sound.SoundId` acceptă formatul `"rbxassetid://<id>"`. Pentru un one-shot fără loop:
```lua
local sfx = Instance.new("Sound")
sfx.SoundId = "rbxassetid://123456789"
sfx.Volume = 0.6
sfx.Parent = SoundService
sfx.Ended:Connect(function() sfx:Destroy() end)
sfx:Play()
```
`Sound.PlaybackSpeed` poate varia tonul (ex. 0.95-1.05 randomizat ușor la fiecare prindere, pentru a evita monotonia repetitivă la prinderi frecvente). Sincronizarea timing-ului sunet-vizual contează mai mult decât alegerea sunetului: sunetul de impact trebuie pornit exact la frame-ul de contact vizual (ex. când plasa se închide peste obiect), nu la începutul animației.

### 10. Rarity reveal — recipe pentru „prinderea rară" din Driftwood

**Important**: acest pattern e o sinteză de design de joc general (confirmat prin discuția devforum despre satisfacția drop-urilor rare, sursă secundară) și convenții comune GUI din secțiunile de mai sus, NU o descriere verificată a implementării exacte din Fisch sau Pet Simulator — nu am putut accesa o sursă primară/verificabilă pentru mecanica lor internă în această sesiune (pagina fandom Fisch a răspuns cu 403/402, iar bugetul de căutare web s-a epuizat).

Secvență recomandată pentru catch rar (obiect rar prins în plasă, legat de brief-ul Driftwood — obiectele rare de iarnă, „Amonte", inundația):

1. **Hit-stop scurt** (~150-250ms) la momentul prinderii — secțiunea 8.
2. **Flash alb** full-screen, tween instant transparency 0→0.7→1 (~200ms total).
3. **Card/siluetă a obiectului** apare cu `Size` pornind de la `UDim2.fromScale(0,0)` și tween către `1,1` cu `EasingStyle.Back` (efectul de "overshoot" caracteristic reveal-urilor de raritate).
4. **UIStroke colorat pe raritate** — paletă simplă, server-authoritative (culoarea vine din datele obiectului, nu e ghicită client-side): comun = gri/alb, neobișnuit = verde, rar = albastru, foarte rar = auriu/violet (paletă proprie Driftwood, nu copiată dintr-un joc anume — brief-ul interzice copierea de assets).
5. **Shine sweep** peste card (secțiunea 4) sincron cu apariția.
6. **Puls de particule** din pool (secțiunea 3) emise radial din centrul cardului, cantitate proporțională cu raritatea.
7. **Sunet distinct** per prag de raritate (nu doar volum diferit — ton/instrument diferit, pentru recunoaștere fără să te uiți la ecran).
8. **Text/label de raritate** cu `MaxVisibleGraphemes` incrementat progresiv (typewriter scurt, opțional pentru obiecte foarte rare).

### 11. Tranziții de loading

Cea mai simplă și fiabilă tehnică documentată (surse: ghidul oficial de animație UI + thread-uri devforum despre fade in/out): un `Frame` full-screen, `ZIndex` maxim, tween pe `BackgroundTransparency` între 0 și 1. Pentru tranziții „scenă → scenă" (ex. la resetarea zilnică a zonei Amonte), pattern comun din comunitate (sursă secundară, exemplul "Lyxo"): fade-out complet → schimbare de stare/date → fade-in, cu un buffer de timp minim pentru ca asset-urile server-authoritative să ajungă la client înainte de fade-in. Un risc semnalat direct de autorul acelui resource: prea multe tween-uri simultane pe ecranul de loading pot deveni ele însele o problemă de performanță — ține tranziția la 1-3 tween-uri, nu la un sistem de particule complex.

## Recomandari concrete pentru Driftwood

1. **Construiește de la început un `ParticlePool` reutilizabil** (secțiunea 3) — folosit identic pentru stropi de apă la plasă, scântei la reparație, și puls de raritate la catch. Un singur modul, trei configurări de imagine/culoare. Motiv: `ParticleEmitter` nu e o opțiune (confirmat), deci ăsta e infrastructură obligatorie, nu un nice-to-have — mai bine construită o dată, corect, decât reinventată de trei ori.
2. **Nu folosi `Workspace.TimeScale`** în nicio schiță de design — nu există. Orice hit-stop/slow-motion trebuie planificat ca listă explicită de sisteme care se opresc (scroll râu, particule, animații de UI), nu ca un singur switch global al motorului.
3. **Leagă viteza vizuală a râului de un atribut server-authoritative** (ex. `workspace:SetAttribute("RiverSpeed", n)` sau un `RemoteEvent`/`IntValue` replicat), nu de o constantă client. Motiv: brief-ul Driftwood cere viteză variabilă pe sezon și server autoritar pentru economie — clientul doar randează, nu decide viteza care influențează ce poate fi prins.
4. **Folosește `UICorner` cu măsură pe elemente statice repetate masiv** (sloturi de inventar, index de 200+ obiecte) — la scară, ia în calcul imagini 9-slice pre-rotunjite dacă profiling-ul din Studio arată cost vizibil; nu presupune costul, măsoară-l (F9 → Memory/Frame Time), pentru că documentația oficială nu dă un număr exact.
5. **Definește o paletă de culori pe raritate ca date, nu ca cod**: un `ModuleScript` cu tabel `RarityConfig = {Common = {Color3, sunet, particleCount}, ...}` — folosit atât de reveal-ul de catch cât și de indexul de reparații (procent completat, afișat vizibil altor jucători conform brief-ului). O sursă unică de adevăr pentru culoare/raritate evită inconsistențe vizuale între sistemul de catch și cel de colecție.
6. **Adaugă un toggle „reduce motion" în opțiuni de la primul prototip de UI**, nu ca adăugire ulterioară — shake-ul de ecran (secțiunea 2) e semnalat explicit de comunitate ca risc de fotosensibilitate; costă puțin să dezactivezi condițional apelurile la `shakeScreen()` și la flash-uri albe rapide.
7. **Preferă `Ripple` sau `Fusion` peste `Flipper`** dacă decizi să introduci o librărie de spring/motion externă în loc de `TweenService` pur — ambele sunt întreținute activ în 2026 (push-uri recente confirmate), Flipper nu mai are commit-uri de 5 ani. Totuși, pentru MVP-ul din pasul 1 al ordinii de lucru din brief (râul, un obiect, plasă simplă), `TweenService` nativ e suficient — nu introduce o dependență externă înainte să simți nevoia reală de fizică spring (ex. UI care reacționează continuu la input, nu doar tranziții discrete).
8. **Sincronizează sunetul cu frame-ul de impact vizual, nu cu începutul animației** (secțiunea 9) — pentru momentul de „plasa se închide peste obiect", testează manual offset-ul în Studio până sunetul cade exact pe frame-ul de contact; e diferența principală dintre un joc care „se simte" bine și unul care nu, și nu apare în nicio documentație — se testează cu urechea.
9. **Nu tenta zi-noapte prin `ColorCorrectionEffect`** — irelevant în GUI pur; folosește overlay `Frame` (secțiunea 7), separat de layerele de parallax, ca să poți controla independent intensitatea tentei fără să recolorezi fiecare imagine de fundal.

## Riscuri si necunoscute

- **Cost real per-tween necunoscut cantitativ**: documentația Roblox nu publică un număr de tween-uri simultane „sigure" pentru GUI. Recomandarea din brief de a avea râul plin de obiecte + particule + UI animat simultan trebuie profilată în Studio pe un device mid-range (mobil), nu presupusă din documentație.
- **`CanvasGroup` — cost de randare neconfirmat exact**: pagina oficială menționează proprietățile dar extrasul obținut nu a confirmat/infirmat explicit costul de „offscreen render target"; tratează orice folosire masivă de `CanvasGroup` (ex. fade pe fiecare card din indexul de 200+ obiecte simultan) ca risc de testat, nu ca sigur.
- **Rarity reveal Fisch/Pet Simulator**: nu am putut verifica mecanica lor exactă din surse primare în această sesiune (fandom blocat HTTP 403/402, buget de căutare web epuizat). Orice paralelă directă cu acele jocuri trebuie tratată ca inspirație generică, nu ca benchmark tehnic — și oricum brief-ul interzice copierea de assets/nume, doar mecanicile sunt libere de copiat.
- **`Workspace.TimeScale`**: absența a fost confirmată doar prin lipsa proprietății din pagina oficială a clasei `Workspace` la data verificării (2026-09-08) — nu e echivalent cu o confirmare oficială explicită „nu există și nu va exista". De verificat din nou dacă Roblox anunță o funcție nouă de time-scale (există cereri vechi de feature request din comunitate, ex. topicul #30727).
- **Buget de căutare web epuizat în timpul cercetării**: sesiunea a atins limita de 200 căutări web (probabil partajată între mai multe cercetări paralele), ceea ce a limitat verificarea unor detalii secundare (ex. exemple video/comunitate suplimentare). Materialul de mai sus se bazează pe fetch-uri directe de pagini (permise în continuare) după acel punct.
- **Numărul optim de particule/pool size** e o decizie de tuning specifică jocului, nu o valoare din documentație — necesită testare directă în Studio.

## Intrebari deschise

1. Ce dimensiune de ecran/aspect ratio țintă are Driftwood (telefon portret vs. desktop landscape)? Afectează direct cât de mare poate fi `TileSize` la apă și câte layere de parallax au sens fără să aglomereze un ecran mic.
2. Câte obiecte simultan pe râu la vârf de sezon (Inundație, x10 obiecte conform brief) — trebuie testat în Studio câte `ImageLabel`-uri de obiect + pool de particule simultan țin un frame rate acceptabil pe mobil low-end.
3. Paleta exactă de culori pe raritate pentru Driftwood — decizie de design, nu de research (dar recomandarea e s-o pui în `ModuleScript` de date, nu în cod, per recomandarea 5).
4. Se dorește un toggle „reduce motion" separat de setările native de accesibilitate ale Roblox client, sau te bazezi doar pe faptul că jucătorul poate reduce global efectele din clientul Roblox? De testat ce control are de fapt clientul Roblox asupra GUI-ului custom (probabil niciunul — orice reducere trebuie construită de Driftwood).
5. Merită introdusă `Ripple`/`Fusion` din pasul 1 (prototip) sau abia când UI-ul devine suficient de complex încât `TweenService` pur devine incomod de întreținut? Recomandarea 7 sugerează amânare, dar e o decizie de arhitectură a echipei, nu doar tehnică.
6. De verificat direct în Studio (nu în documentație): comportamentul exact al `UIGradient.Offset` la valori peste 1/sub -1 — se repetă tile-ul sau se clampează? Extrasul din documentație nu a clarificat complet mecanica `TileMode`.
7. De recuperat separat (altă sesiune de research, cu buget de căutare proaspăt): o sursă primară verificabilă pentru mecanica de reveal din Fisch și Pet Simulator, dacă echipa consideră că merită studiate mai atent ca referință de gameplay (nu de assets).

## Surse

- TweenService — https://create.roblox.com/docs/reference/engine/classes/TweenService (verificat 2026-09-08, fără dată de publicare vizibilă pe pagină)
- TweenInfo — https://create.roblox.com/docs/reference/engine/datatypes/TweenInfo (verificat 2026-09-08)
- TweenBase — https://create.roblox.com/docs/reference/engine/classes/TweenBase (verificat 2026-09-08)
- Enum.EasingStyle — https://create.roblox.com/docs/reference/engine/enums/EasingStyle (verificat 2026-09-08)
- Ghid oficial „Animation" (UI) — https://create.roblox.com/docs/ui/animation (verificat 2026-09-08)
- Ghid oficial UI (hub) — https://create.roblox.com/docs/ui (verificat 2026-09-08)
- GuiObject — https://create.roblox.com/docs/reference/engine/classes/GuiObject (verificat 2026-09-08)
- UIGradient — https://create.roblox.com/docs/reference/engine/classes/UIGradient (verificat 2026-09-08)
- UIStroke — https://create.roblox.com/docs/reference/engine/classes/UIStroke (verificat 2026-09-08)
- UICorner — https://create.roblox.com/docs/reference/engine/classes/UICorner (verificat 2026-09-08)
- UIPadding — https://create.roblox.com/docs/reference/engine/classes/UIPadding (verificat 2026-09-08)
- UIListLayout — https://create.roblox.com/docs/reference/engine/classes/UIListLayout (verificat 2026-09-08)
- ImageLabel (ScaleType/TileSize/ImageRectOffset) — https://create.roblox.com/docs/reference/engine/classes/ImageLabel (verificat 2026-09-08)
- ParticleEmitter — https://create.roblox.com/docs/reference/engine/classes/ParticleEmitter (verificat 2026-09-08)
- CanvasGroup — https://create.roblox.com/docs/reference/engine/classes/CanvasGroup (verificat 2026-09-08)
- Sound — https://create.roblox.com/docs/reference/engine/classes/Sound (verificat 2026-09-08)
- RunService (BindToRenderStep/RenderStepped) — https://create.roblox.com/docs/reference/engine/classes/RunService (verificat 2026-09-08)
- Workspace (absența TimeScale) — https://create.roblox.com/docs/reference/engine/classes/Workspace (verificat 2026-09-08)
- TextLabel (MaxVisibleGraphemes) — https://create.roblox.com/docs/reference/engine/classes/TextLabel (verificat 2026-09-08)
- UDim2 — https://create.roblox.com/docs/reference/engine/datatypes/UDim2 (verificat 2026-09-08)
- spr (Fraktality) — https://github.com/Fraktality/spr (README verificat 2026-09-08; ultimul push confirmat via API: 2024-07-31)
- Flipper (Reselim) — https://github.com/Reselim/Flipper (verificat 2026-09-08; ultimul push confirmat via API: 2021-11-25)
- Ripple (littensy) — https://github.com/littensy/ripple (README verificat 2026-09-08; ultimul push confirmat via API: 2026-07-18)
- Fusion (dphfox) — https://github.com/dphfox/Fusion (verificat via API 2026-09-08; ultimul push: 2026-02-02)
- Otter (azumanga, adopție neglijabilă) — https://github.com/azumanga/Otter (verificat via API 2026-09-08; ultimul push: 2022-08-02)
- Devforum — „3 ways to create Fade In and Out Transitions" — https://devforum.roblox.com/t/3-ways-to-create-fade-in-and-out-transitions-color-correction-tweening/646484 (postat 2020-06-27; SECUNDAR, potențial învechit)
- Devforum — „Performance considerations, improvements, and optimizations when making a game" — https://devforum.roblox.com/t/performance-considerations-improvements-and-optimizations-when-making-a-game/817499 (postat 2020-10-12, actualizat 2023-08-12; SECUNDAR)
- Devforum — „How to improve my gui" — https://devforum.roblox.com/t/how-to-improve-my-gui/4779404 (postat 2026-08-06; SECUNDAR)
- Devforum — „How can I make rare drops feel more satisfying to get?" — https://devforum.roblox.com/t/how-can-i-make-rare-drops-feel-more-satisfying-to-get/3743045 (postat 2025-06-16/17; SECUNDAR)
- Devforum — „How can I make a time stop mechanic" — https://devforum.roblox.com/t/how-can-i-make-a-time-stop-mechanic/1748255 (postat aprox. aprilie 2022; SECUNDAR, posibil învechit)
- Devforum — „Lyxo | The Modern Loading Screen" — https://devforum.roblox.com/t/lyxo-the-modern-loading-screen/2413937 (postat 2023-06-07; SECUNDAR)
- Devforum — căutare „workspace TimeScale property" (context MoonScale #4143911) — https://devforum.roblox.com/search.json?q=workspace%20TimeScale%20property (verificat 2026-09-08; SECUNDAR)
- Fisch Fandom Wiki (Rarity) — https://fisch.fandom.com/wiki/Rarity — **NEACCESIBIL în această sesiune** (HTTP 403/402); NEVERIFICAT, listat doar ca sursă țintă neexploatată pentru research viitor.

*Notă metodologică: bugetul de căutări web (`WebSearch`) al sesiunii a fost epuizat (200/200, aparent partajat între cercetări paralele) după primele interogări; restul cercetării s-a bazat pe `WebFetch` direct pe URL-uri cunoscute din documentația oficială Roblox, pe API-ul public GitHub (`api.github.com`) și pe endpoint-ul de căutare JSON al Discourse de pe devforum.roblox.com (`/search.json?q=...`).*
