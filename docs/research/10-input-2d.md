# Input pe Roblox pentru un joc 2D ScreenGui: mouse, touch, gamepad, drag-and-drop

## Rezumat executiv

- Roblox are trei straturi de input, nu unul: `UserInputService` (evenimente brute, orice dispozitiv), `ContextActionService` (legare acțiune-cu-nume ↔ input, cu buton touch auto-generat), și **Input Action System** (nou, `InputContext`/`InputAction`/`InputBinding`) — sistemul modern recomandat oficial pentru acțiuni gameplay tip „Jump"/"Sprint", orientat spre personaje 3D. Pentru un joc 100% `ScreenGui` ca Driftwood, evenimentele native de pe `GuiObject`/`GuiButton` plus `UIDragDetector` acoperă majoritatea nevoilor fără să fie necesar Input Action System.
- **`UIDragDetector`** e componenta nativă, fără cod, pentru drag pe elemente 2D: are `DragStyle` (TranslatePlane/TranslateLine/Rotate/Scriptable), `BoundingBehavior` (Automatic/EntireObject/HitPoint), `ResponseStyle` (Offset/Scale/CustomOffset/CustomScale), funcții de constrângere (`AddConstraintFunction`) și evenimente `DragStart`/`DragContinue`/`DragEnd`. E exact ce trebuie pentru „trage plasa pe mal, snap la slot".
- **Nu există hit-testing pe pixel/alpha** nicăieri în documentația oficială pentru `ImageButton`/`ImageLabel`. Zona clicabilă e mereu dreptunghiul (`AbsoluteSize`/`AbsolutePosition`); forme neregulate (cerc, poligon) trebuie verificate manual în `InputBegan`/`InputChanged` cu matematică proprie.
- `gameProcessedEvent` de pe `UserInputService.InputBegan/Changed/Ended` e **exact `true` quando input-ul a fost deja consumat de UI** ("if a button was touched or clicked from this input, gameProcessedEvent will be true") — esențial ca să nu procesezi de două ori un tap (o dată de buton, o dată de lumea din spate).
- Navigarea GUI cu gamepad e aproape gratuită: `GuiObject.Selectable = true` + `NextSelectionUp/Down/Left/Right` (sau `GuiBase2d` cu `SelectionGroup`/`Enum.SelectionBehavior` = Escape/Stop) + `GuiService.SelectedObject`/`AutoSelectGuiEnabled`/`GuiNavigationEnabled` controlează tot fluxul, fără librărie externă.
- Cerințele oficiale de certificare console (Xbox) pentru un joc bazat pe GUI: navigare pe 4 direcții + select + back către **fiecare** control, design „10-foot" cu dimensiuni relative/procentuale, zone TV-safe, **fără fereastră de chat**, iconițe de buton dinamice per-platformă, haptic feedback pentru confirmări.
- Accesibilitatea are cârlige gata construite în motor: `GuiService.PreferredTransparency` (0–1), `GuiService.PreferredTextSize` (Medium/Large/Larger/Largest), `GuiService.ReducedMotionEnabled` (bool) — Driftwood ar trebui să le citească și să le respecte automat, nu să construiască un meniu de setări de la zero.
- `ContextActionService:BindAction(..., createTouchButton = true, ...)` generează automat un buton touch (`ContextActionGui`/`ContextButtonFrame` în `PlayerGui`), dar **maxim 7 butoane touch simultan** pe jucător.
- Pentru actualizări de poziție per-frame legate de drag (urmărirea degetului/mouse-ului), documentația recomandă `RunService:BindToRenderStep` cu prioritate explicită, nu conectarea directă la `RenderStepped`/`PreRender` — pentru determinism de ordine, nu neapărat pentru latență brută (nu am găsit o cifră oficială de latență).
- Pentru pan/zoom pe o „lume" mai mare decât ecranul (dacă apare vreodată), **nu există o cameră 2D nativă** — se construiește manual din `GuiObject.TouchPan`/`TouchPinch` (touch), `MouseWheelForward/Backward` + drag (desktop) și `Thumbstick2` (gamepad), consistent cu ce spune deja `CLAUDE.md`-ul Driftwood despre lipsa camerei ortografice.

## Fapte verificate

- `GuiObject.InputBegan`/`InputChanged`/`InputEnded` au un singur parametru, `input: InputObject`, și descrierea oficială identică pentru toate trei: „Fired when a user begins/changes/stops interacting via a Human-Computer Interface device (Mouse button down, touch begin, keyboard button down, etc)." Sursă: [GuiObject.yaml, creator-docs (GitHub)](https://github.com/Roblox/creator-docs/blob/main/content/en-us/reference/engine/classes/GuiObject.yaml), accesat 2026-09-08. Încredere: ridicată.
- `GuiButton` (părinte pentru `ImageButton`/`TextButton`) are `MouseButton1Down`, `MouseButton1Up`, `MouseButton1Click` (fără parametri), `MouseButton2Down/Up/Click`, `Activated(inputObject: InputObject, clickCount: number)` și `SecondaryActivated(inputObject: InputObject)`. Sursă: [GuiButton | Roblox Creator Hub](https://create.roblox.com/docs/reference/engine/classes/GuiButton), accesat 2026-09-08. Încredere: ridicată.
- `Activated` e evenimentul recomandat pentru butoane pentru că e declanșat uniform de mouse, touch și gamepad (Select); `MouseButton1Click` reacționează doar la mouse. (Inferență din faptul că `Activated` e listat separat de evenimentele specifice de mouse și e folosit ca atare în tutorialele oficiale de UI — NEVERIFICAT ca declarație explicită într-o singură propoziție oficială găsită, dar consistentă cu design-ul API-ului.) Încredere: medie.
- `GuiObject.Active`: „Determines whether this UI element sinks input." `GuiObject.Interactable`: „Determines whether the GuiButton can be interacted with or not, or if the GuiState of the GuiObject is changing or not." `Selectable`: „Determine whether the GuiObject can be selected by a gamepad." Sursă: [GuiObject.yaml (GitHub)](https://github.com/Roblox/creator-docs/blob/main/content/en-us/reference/engine/classes/GuiObject.yaml), accesat 2026-09-08. Încredere: ridicată.
- Nu există nicio mențiune de hit-testing pe pixel/alpha pentru `ImageButton`/`ImageLabel` în pagina de referință `GuiObject` — verificat explicit, absent din conținut. Sursă: [GuiObject | Roblox Creator Hub](https://create.roblox.com/docs/reference/engine/classes/GuiObject), accesat 2026-09-08. Încredere: ridicată (pentru absență, nu poate exclude 100% o pagină separată nevăzută).
- `UserInputService.InputBegan` are parametrii `input: InputObject, gameProcessedEvent: boolean`; descrierea oficială a `gameProcessedEvent`: „Indicates whether the engine internally observed this input and acted on it. Generally this refers to UI processing, so if a button was touched or clicked from this input, gameProcessedEvent will be true." Sursă: [UserInputService.yaml (GitHub)](https://github.com/Roblox/creator-docs/blob/main/content/en-us/reference/engine/classes/UserInputService.yaml), accesat 2026-09-08. Încredere: ridicată.
- `UserInputService` descriere oficială: „primarily used to detect the input types available on a user's device, as well as detect input events... perform different actions depending on the device." Proprietăți: `TouchEnabled`, `GamepadEnabled`, `KeyboardEnabled`, `MouseEnabled` (fiecare cu metodele asociate menționate explicit: `TouchStarted`/`TouchMoved`, `GetConnectedGamepads()`, `IsKeyDown()`/`GetKeysPressed()`, `GetMouseLocation()`), plus `PreferredInput` (read-only, tipul de input probabil folosit curent). Sursă: idem. Încredere: ridicată.
- `Enum.UserInputType` conține: MouseButton1, MouseButton2, MouseButton3, MouseWheel, MouseMovement, Touch, Keyboard, Focus, Accelerometer, Gyro, Gamepad1…Gamepad8, TextInput, InputMethod, None. Sursă: [UserInputType | Roblox Creator Hub](https://create.roblox.com/docs/reference/engine/enums/UserInputType), accesat 2026-09-08. Încredere: ridicată.
- `Enum.KeyCode` include butoanele de gamepad: ButtonX, ButtonY, ButtonA, ButtonB, ButtonR1, ButtonL1, ButtonR2, ButtonL2, ButtonR3, ButtonL3, ButtonStart, ButtonSelect, DPadLeft/Right/Up/Down, Thumbstick1, Thumbstick2, ButtonCenter, plus alte alias-uri (ButtonUp/Down/Left/Right, ButtonBack) — același enum e folosit și pentru taste de tastatură. Sursă: [KeyCode | Roblox Creator Hub](https://create.roblox.com/docs/reference/engine/enums/KeyCode), accesat 2026-09-08. Încredere: ridicată.
- `Enum.UserInputState` are exact 5 valori: Begin, Change, End, Cancel, None. Sursă: [UserInputState | Roblox Creator Hub](https://create.roblox.com/docs/reference/engine/enums/UserInputState), accesat 2026-09-08. Încredere: ridicată.
- `ContextActionService` descriere oficială: „A service used to bind user input to contextual actions" — funcționează exclusiv în `LocalScript` (client). `BindAction(actionName, functionToBind, createTouchButton, ...inputTypes)`: handler-ul primește `(actionName: string, inputState: Enum.UserInputState, inputObject: InputObject)`. Model de stivă: „the most recently bound action takes priority"; un handler poate întoarce `Enum.ContextActionResult.Pass` ca input-ul să treacă mai departe la handler-ul următor din stivă. `BindActionAtPriority` adaugă un parametru de prioritate numerică (valoare mai mare = procesat mai întâi), prioritate implicită **2000** dacă nu se folosește `BindActionAtPriority`. Sursă: [ContextActionService.yaml (GitHub)](https://github.com/Roblox/creator-docs/blob/main/content/en-us/reference/engine/classes/ContextActionService.yaml), accesat 2026-09-08. Încredere: ridicată.
- Când `createTouchButton = true`, `ContextActionService` creează automat un `ScreenGui` numit `ContextActionGui` cu un `Frame` numit `ContextButtonFrame` în `PlayerGui`, cu câte un `ImageButton` per acțiune legată; **maxim 7 butoane touch** pot fi create simultan. Sursă: idem. Încredere: ridicată.
- `UIDragDetector` — ghid oficial: „facilitates and encourages interaction with 2D user interface elements in a game, such as sliders, spinners, and more." Se adaugă în Studio din Explorer (hover pe `GuiObject` → butonul ⊕ → `UIDragDetector`); **nu funcționează în Studio cât timp uneltele Select/Move/Scale/Rotate (sau anumite plugin-uri) sunt active**. Scripturile care-l accesează trebuie să fie `LocalScript` sau `Script` cu `RunContext = Client`. Sursă: [UI Drag Detectors | Roblox Creator Hub](https://create.roblox.com/docs/ui/ui-drag-detectors), accesat 2026-09-08. Încredere: ridicată.
- `Enum.UIDragDetectorDragStyle` are exact 4 valori: `TranslatePlane` (0, implicit), `TranslateLine` (1), `Rotate` (2), `Scriptable` (3). Sursă: [UIDragDetectorDragStyle | Roblox Creator Hub](https://create.roblox.com/docs/reference/engine/enums/UIDragDetectorDragStyle), accesat 2026-09-08. Încredere: ridicată.
- `Enum.UIDragDetectorBoundingBehavior` are exact 3 valori: `Automatic` (0), `EntireObject` (1), `HitPoint` (2) — fără text de descriere per-valoare în pagina consultată. Sursă: [UIDragDetectorBoundingBehavior | Roblox Creator Hub](https://create.roblox.com/docs/reference/engine/enums/UIDragDetectorBoundingBehavior), accesat 2026-09-08. Încredere: ridicată pentru listă, medie pentru semantica exactă a fiecărei valori (fără descriere text confirmată).
- `Enum.UIDragDetectorResponseStyle` are exact 4 valori: `Offset` (0), `Scale` (1), `CustomOffset` (2), `CustomScale` (3). Sursă: [UIDragDetectorResponseStyle | Roblox Creator Hub](https://create.roblox.com/docs/reference/engine/enums/UIDragDetectorResponseStyle), accesat 2026-09-08. Încredere: ridicată.
- `Enum.UIDragDetectorDragRelativity`: `Absolute` (0) — „the absolute target position/rotation in the space defined by DragSpace"; `Relative` (1) — „the change from the current position/rotation in the space defined by DragSpace." Sursă: [UIDragDetectorDragRelativity.yaml (GitHub)](https://github.com/Roblox/creator-docs/blob/main/content/en-us/reference/engine/enums/UIDragDetectorDragRelativity.yaml), accesat 2026-09-08. Încredere: ridicată.
- `Enum.UIDragDetectorDragSpace` are 3 valori: `Parent` (0, spațiul local al `GuiObject`-ului părinte al detectorului), `LayerCollector` (1, spațiul `ScreenGui`-ului), `Reference` (2, spațiul lui `ReferenceUIInstance`; dacă `ReferenceUIInstance` e setat, se comportă identic cu `Parent`). Sursă: [UIDragDetectorDragSpace.yaml (GitHub)](https://github.com/Roblox/creator-docs/blob/main/content/en-us/reference/engine/enums/UIDragDetectorDragSpace.yaml), accesat 2026-09-08. Încredere: ridicată.
- `UIDragDetector` are metodele `AddConstraintFunction(priority: int, function) -> RBXScriptConnection` (adaugă o funcție care modifică/constrânge mișcarea propusă, apelate în ordine de prioritate), `GetReferencePosition() -> UDim2`, `GetReferenceRotation() -> float`, `SetDragStyleFunction(function)` (folosită doar dacă `DragStyle = Scriptable`), și evenimentele `DragStart(inputPosition: Vector2)`, `DragContinue(inputPosition: Vector2)`, `DragEnd(inputPosition: Vector2)`. Sursă: [UIDragDetector.yaml (GitHub)](https://github.com/Roblox/creator-docs/blob/main/content/en-us/reference/engine/classes/UIDragDetector.yaml), accesat 2026-09-08. Încredere: ridicată.
- Ghidul oficial `UIDragDetector` conține 4 exemple complete de cod: slider de transparență (event-based, DragStart/Continue/End), rotator de nuanță (property monitoring via `GetPropertyChangedSignal("DragRotation")`), urmărire sinusoidală (Scriptable drag prin `SetDragStyleFunction`), și **snap la grid prin `AddConstraintFunction`** rotunjind valorile de scală — exact tiparul pentru snap-la-slot pe malul râului din Driftwood. Sursă: [UI Drag Detectors | Roblox Creator Hub](https://create.roblox.com/docs/ui/ui-drag-detectors), accesat 2026-09-08. Încredere: ridicată.
- `GuiObject` are și evenimente de gest touch: `TouchTap(touchPositions)`, `TouchPan(touchPositions, totalTranslation: Vector2, velocity: Vector2, state: UserInputState)`, `TouchPinch(touchPositions, scale: float, velocity: float, state: UserInputState)`, `TouchRotate(touchPositions, rotation: float, velocity: float, state: UserInputState)`, `TouchSwipe(swipeDirection: Enum.SwipeDirection, numberOfTouches: int)`, `TouchLongPress(touchPositions, state: UserInputState)`. `DragBegin`/`DragStopped` sunt marcate **deprecated** (înlocuite conceptual de `UIDragDetector`). Sursă: [GuiObject.yaml (GitHub)](https://github.com/Roblox/creator-docs/blob/main/content/en-us/reference/engine/classes/GuiObject.yaml), accesat 2026-09-08. Încredere: ridicată.
- `GuiService.SelectedObject`: „Sets the GuiObject currently being focused on by the GUI navigator. This may reset to nil if the object is off screen." `AutoSelectGuiEnabled`: „If activated, the Select button on a gamepad or Backslash will automatically set a GUI as the selected object. Disabling this means that GUI navigation will still work if GuiNavigationEnabled is enabled, but you will have to set SelectedObject manually to start navigation." `GuiNavigationEnabled`: „Used to enable and disable the default controller GUI navigation." Sursă: [GuiService.yaml (GitHub)](https://github.com/Roblox/creator-docs/blob/main/content/en-us/reference/engine/classes/GuiService.yaml), accesat 2026-09-08. Încredere: ridicată.
- `GuiObject.NextSelectionUp/Down/Left/Right`: fiecare setează explicit `GuiObject`-ul următor selectat la navigare cu gamepad în direcția respectivă. Există și un mecanism mai nou pe `GuiBase2d`: `SelectionBehaviorUp/Down/Left/Right` folosind `Enum.SelectionBehavior` cu valorile `Escape` (0 — prioritizează grupul, dar permite ieșirea dacă nu găsește buton potrivit) și `Stop` (1 — restricționează selecția strict la grup). Surse: [GuiObject.yaml (GitHub)](https://github.com/Roblox/creator-docs/blob/main/content/en-us/reference/engine/classes/GuiObject.yaml); [SelectionBehavior.yaml (GitHub)](https://github.com/Roblox/creator-docs/blob/main/content/en-us/reference/engine/enums/SelectionBehavior.yaml), accesat 2026-09-08. Încredere: ridicată.
- Ghid oficial de certificare console: navigare gamepad de bază pe 4 direcții + select + back trebuie să ajungă la **fiecare** element de UI; „Roblox offers directional selection and virtual cursor options out-of-the-box"; design „10-foot" cu dimensiuni/poziții relative (procentuale) și zone TV-safe pentru overscan; recomandare explicită **„Disable the chat window"** pentru console indiferent de altă personalizare; scalare UI ghidată de `UISizeConstraint` + `GuiService.ViewportDisplaySize`; afișare dinamică a iconițelor de buton per-platformă (`InputActionLabel` sau metode `UserInputService`); haptic feedback prin `HapticEffect`. Sursă: [Console Guidelines | Roblox Creator Hub](https://create.roblox.com/docs/production/publishing/console-guidelines), accesat 2026-09-08. Încredere: ridicată (oficial), dar rezumat generat, nu citat verbatim complet — de reverificat pasaj cu pasaj înainte de certificare reală.
- `GuiService.ViewportDisplaySize` are 3 valori conceptuale: Small (tablete/mobil), Medium (laptop/monitor), Large (TV/ecrane mari). Sursă: [GuiService.yaml (GitHub)](https://github.com/Roblox/creator-docs/blob/main/content/en-us/reference/engine/classes/GuiService.yaml), accesat 2026-09-08. Încredere: ridicată.
- `GuiService.PreferredTransparency`: număr 0–1, „A value of 1 (default) indicates the player prefers the default background transparency, while a value of 0 indicates the player prefers fully opaque (non-transparent) background transparency." `PreferredTextSize`: Medium (implicit)/Large/Larger/Largest. `ReducedMotionEnabled`: bool, „player wants motion effects and animations to be reduced or completely removed." `TouchControlsEnabled`: bool, implicit **true**, controlează afișarea controalelor touch native. Sursă: [GuiService.yaml (GitHub)](https://github.com/Roblox/creator-docs/blob/main/content/en-us/reference/engine/classes/GuiService.yaml), accesat 2026-09-08. Încredere: ridicată.
- Pagina oficială de accesibilitate recomandă: contrast suficient text/fundal, mărire font, simboluri în plus față de culoare (≈5% din oameni au deficiențe de percepție a culorii), feedback vizual pe lângă cel sonor, controale de volum separate pe categorii (muzică/efecte/voce). Sursă: [Accessibility | Roblox Creator Hub](https://create.roblox.com/docs/production/publishing/accessibility), accesat 2026-09-08. Încredere: ridicată pentru conținut general; **fără cifre exacte de contrast (WCAG) sau dimensiune minimă de tap target** găsite în pagină — NEVERIFICAT.
- **Input Action System** (`InputContext`, `InputAction`, `InputBinding`, `InputActionLabel`): sistemul „core" e General Available; `InputActionLabel` și „Input Action Manager" (unealtă din Studio) sunt încă **în beta**, necesită activare din File → Beta Features; funcționarea completă necesită și proprietatea `Workspace.PlayerScriptsUseInputActionSystem` activată. `InputAction.Type` poate fi Bool, Direction1D, Direction2D, Direction3D, ViewportPosition; evenimente `Pressed`/`Released`/`StateChanged`. Sursă: [Input Action System | Roblox Creator Hub](https://create.roblox.com/docs/input/input-action-system), accesat 2026-09-08. Încredere: medie (rezumat din conținut extras automat, nu verificat linie cu linie din YAML sursă).
- `RunService`: se recomandă oficial `BindToRenderStep(name, priority, function)` în locul conectării directe la evenimentul de randare, exemplul din documentație marcând conectarea directă drept „Also works, but not recommended." Sursă: [RunService | Roblox Creator Hub](https://create.roblox.com/docs/reference/engine/classes/RunService), accesat 2026-09-08. Încredere: ridicată pentru recomandare; **NEVERIFICAT** motivul exact/cifre de latență în textul extras.
- Nu am găsit, în sursele consultate, data exactă a lansării/anunțului `UIDragDetector` (beta → GA) și nici un thread oficial de anunț pe DevForum — motorul de căutare (WebSearch) nu a fost disponibil în această sesiune (buget epuizat de sesiune înainte de prima interogare), iar căutarea pe Bing/DuckDuckGo prin WebFetch a fost blocată de CAPTCHA/rezultate irelevante. **NEVERIFICAT.**

## Detalii

### 1. Cele trei straturi de input pe Roblox

| Strat | Pentru ce e bun | Observație pentru Driftwood |
|---|---|---|
| `UserInputService` | Evenimente brute, orice dispozitiv, acces la stare (`TouchEnabled`, `GamepadEnabled`, `PreferredInput`) | Bun pentru logică globală client (ex. schimbă layout HUD după `PreferredInput`) |
| `ContextActionService` | Legare `actionName` ↔ input, cu prioritate/stivă și buton touch auto-generat (max. 7) | Bun pentru acțiuni discrete legate de context (ex. „Repară" cât ești lângă atelier) |
| Input Action System (`InputContext`/`InputAction`/`InputBinding`) | Acțiuni gameplay abstracte legate declarativ la mai multe tipuri de hardware deodată | Orientat spre personaj 3D (Jump/Sprint); parțial în beta; pentru un joc pur `ScreenGui` fără `Humanoid`, valoarea adăugată e neclară — **de evaluat**, nu obligatoriu |
| `GuiObject`/`GuiButton` evenimente native + `UIDragDetector` | Interacțiune directă cu elemente UI: click, hover, drag | **Stratul principal pentru Driftwood** — plasarea plaselor, butoane HUD, sloturi de atelier |

Pentru un joc 2D pur ca Driftwood, cel mai simplu și mai puțin predispus la bug-uri e să tratezi **fiecare `GuiObject` ca sursă de adevăr pentru propriul input** (evenimentele lui native) și să folosești `UserInputService` doar pentru lucruri globale (taste de shortcut, detectare tip dispozitiv), nu pentru re-implementarea click-detection peste elemente UI.

### 2. Evenimente native `GuiObject`/`GuiButton`

```lua
-- Pe un GuiButton (ex. buton "Repară" din atelier)
local button = script.Parent :: GuiButton

button.Activated:Connect(function(inputObject: InputObject, clickCount: number)
    -- Activated se declanseaza uniform pe mouse, touch SI select-ul gamepad-ului
    requestRepair:FireServer(slotId)
end)

button.MouseEnter:Connect(function()
    tooltip.Visible = true
end)
```

De reținut: `Activated` e alegerea implicită pentru butoane pentru că funcționează identic indiferent de dispozitiv (mouse click, touch tap, gamepad Select pe elementul focalizat). `MouseButton1Down/Up/Click` reacționează **doar** la mouse — evită-le pentru acțiuni principale, folosește-le doar pentru comportamente specifice de mouse (ex. drag manual, right-click context menu prin `MouseButton2Click`).

### 3. Hit-testing pentru forme custom (fără pixel-perfect nativ)

Roblox nu oferă hit-testing pe alpha/pixel pentru `ImageButton`. Zona de click e mereu dreptunghiul complet al elementului. Pentru o formă circulară (ex. un buton rotund de "plasă") sau un poligon neregulat, trebuie făcută verificare manuală:

```lua
local UserInputService = game:GetService("UserInputService")

local function isInsideCircle(button: GuiObject, inputPosition: Vector2): boolean
    local center = button.AbsolutePosition + button.AbsoluteSize / 2
    local radius = math.min(button.AbsoluteSize.X, button.AbsoluteSize.Y) / 2
    return (inputPosition - center).Magnitude <= radius
end

button.InputBegan:Connect(function(input: InputObject)
    if input.UserInputType == Enum.UserInputType.MouseButton1
        or input.UserInputType == Enum.UserInputType.Touch then
        if isInsideCircle(button, input.Position) then
            -- click valid in interiorul cercului, nu doar in dreptunghi
        end
    end
end)
```

Pentru poligoane arbitrare, tehnica standard e ray-casting 2D (point-in-polygon) pe coordonate `AbsolutePosition`-relative — nu există API Roblox dedicat pentru asta, e matematică Luau simplă.

### 4. `UIDragDetector` — tabel complet de proprietăți

| Proprietate | Tip | Rol |
|---|---|---|
| `Enabled` | boolean (implicit `true`) | Activează/dezactivează detectorul |
| `DragStyle` | `Enum.UIDragDetectorDragStyle` | TranslatePlane (implicit) / TranslateLine / Rotate / Scriptable |
| `ResponseStyle` | `Enum.UIDragDetectorResponseStyle` | Offset / Scale / CustomOffset / CustomScale — cum se aplică mișcarea calculată |
| `BoundingBehavior` | `Enum.UIDragDetectorBoundingBehavior` | Automatic / EntireObject / HitPoint |
| `BoundingUI` | `GuiBase2d` (implicit `nil`) | Containerul care limitează zona de drag |
| `DragRelativity` | `Enum.UIDragDetectorDragRelativity` | Absolute / Relative — pentru funcții custom |
| `DragSpace` | `Enum.UIDragDetectorDragSpace` | Parent / LayerCollector / Reference — spațiul de coordonate |
| `DragAxis` | `Vector2` | Axa pentru `TranslateLine` |
| `DragRotation` | `float` | Rotația curentă (grade), poate fi setată direct |
| `DragUDim2` | `UDim2` | Translația curentă |
| `MinDragTranslation` / `MaxDragTranslation` | `UDim2` | Limite de translație |
| `MinDragAngle` / `MaxDragAngle` | `float` | Limite de rotație |
| `ReferenceUIInstance` | `GuiObject` (implicit `nil`) | Element de referință pentru spațiul `Reference` |
| `CursorIcon` / `ActivatedCursorIcon` | `ContentId` | Cursor la hover / la activare |
| `SelectionModeDragSpeed` / `SelectionModeRotateSpeed` | `UDim2` / `float` | Viteză când dragul e simulat prin gamepad (mod selecție) |
| `UIDragSpeedAxisMapping` | `Enum.UIDragSpeedAxisMapping` | Cum se mapează viteza pe X/Y |

Metode: `AddConstraintFunction(priority, fn) -> RBXScriptConnection`, `SetDragStyleFunction(fn)` (doar cu `DragStyle = Scriptable`), `GetReferencePosition()`, `GetReferenceRotation()`.
Evenimente: `DragStart(inputPosition)`, `DragContinue(inputPosition)`, `DragEnd(inputPosition)`.

### 5. Pattern de drag-and-drop pentru plasarea plaselor pe mal

Design propus (sintetizat din exemplul oficial de snap-la-grid din ghidul `UIDragDetector`, adaptat la Driftwood — nu e citat direct din documentație, e aplicarea recomandărilor de mai sus):

```lua
-- NetIcon (ImageButton) are un UIDragDetector copil, "Drag"
local dragDetector = netIcon.Drag :: UIDragDetector
dragDetector.BoundingUI = riverbankContainer   -- Frame care reprezinta malul
dragDetector.BoundingBehavior = Enum.UIDragDetectorBoundingBehavior.EntireObject
dragDetector.ResponseStyle = Enum.UIDragDetectorResponseStyle.Offset

local startPosition = netIcon.Position

-- Snap la cel mai apropiat slot definit in ReplicatedStorage/config
dragDetector:AddConstraintFunction(1, function(offset: UDim2, rotation: number)
    local proposedPos = startPosition + offset
    local nearestSlot = findNearestSlot(proposedPos, riverbankSlots)
    if nearestSlot then
        return (nearestSlot.Position - startPosition), rotation
    end
    return offset, rotation
end)

dragDetector.DragContinue:Connect(function(inputPosition: Vector2)
    local nearestSlot = findNearestSlot(netIcon.AbsolutePosition, riverbankSlots)
    -- Preview LOCAL, doar vizual - server-ul valideaza real la DragEnd
    previewFrame.Visible = nearestSlot ~= nil
    previewFrame.BackgroundColor3 = nearestSlot and VALID_COLOR or INVALID_COLOR
end)

dragDetector.DragEnd:Connect(function(inputPosition: Vector2)
    local nearestSlot = findNearestSlot(netIcon.AbsolutePosition, riverbankSlots)
    if nearestSlot then
        local ok = placeNetRemote:InvokeServer(nearestSlot.Id)
        if not ok then
            -- server a refuzat (slot ocupat intre timp etc.) - animam inapoi
            netIcon:TweenPosition(startPosition, Enum.EasingDirection.Out, Enum.EasingStyle.Quad, 0.2)
        end
    else
        netIcon:TweenPosition(startPosition, Enum.EasingDirection.Out, Enum.EasingStyle.Quad, 0.2)
    end
end)
```

Puncte critice, consistente cu regula „server autoritar" din `CLAUDE.md`-ul Driftwood: validarea de pe client (culoarea preview, snap vizual) e **doar cosmetică**. Confirmarea reală trece printr-un `RemoteFunction`/`RemoteEvent` validat pe server, care verifică din nou dacă slotul e liber, dacă jucătorul deține plasa respectivă etc.

### 6. Touch: gesturi și butoane

`GuiObject` expune direct `TouchTap`, `TouchPan`, `TouchPinch`, `TouchRotate`, `TouchSwipe`, `TouchLongPress` — utile pentru interacțiuni custom (ex. long-press pe o plasă pentru meniu contextual „Golește / Mută / Vinde"). Pentru acțiuni discrete legate de context (ex. „Donează" cât ești lângă atelier), `ContextActionService:BindAction(name, fn, true, Enum.KeyCode.E)` generează automat butonul touch — dar nu uita plafonul de **7 butoane simultane**.

### 7. Gamepad și navigare GUI

```lua
-- Fiecare buton interactiv trebuie sa fie explicit selectabil pentru gamepad
repairButton.Selectable = true
repairButton.NextSelectionRight = donateButton
donateButton.Selectable = true
donateButton.NextSelectionLeft = repairButton

local GuiService = game:GetService("GuiService")
GuiService.SelectedObject = repairButton  -- focus initial cand se deschide meniul
```

`GuiService.AutoSelectGuiEnabled` (implicit probabil `true`) decide dacă apăsarea butonului Select de pe gamepad pornește automat navigarea; dacă e dezactivat, trebuie setat manual `SelectedObject`. `GuiNavigationEnabled` pornește/oprește complet navigarea implicită cu controller.

Butoanele de gamepad relevante din `Enum.KeyCode`: `ButtonA`/`ButtonB`/`ButtonX`/`ButtonY`, `DPadUp/Down/Left/Right`, `Thumbstick1`/`Thumbstick2`, `ButtonL1/R1/L2/R2`, `ButtonStart`/`ButtonSelect`. Tipul de input pentru un gamepad conectat e `Enum.UserInputType.Gamepad1` (până la `Gamepad8` pentru multiplayer local).

### 8. Cerințe console (Xbox) pentru un joc GUI-only

Din moment ce Driftwood e 100% `ScreenGui`, fiecare element interactiv trebuie să fie accesibil prin navigare pe 4 direcții. Recomandări oficiale relevante: dimensiuni/poziții **relative** (nu pixeli ficși) pentru scalare TV, zone safe pentru overscan, dezactivarea chatului pe console, folosirea `GuiService.ViewportDisplaySize` pentru a decide layout-uri diferite (Small/Medium/Large), și afișarea de iconițe specifice platformei pentru butoane (nu presupune mereu "click" — pe Xbox arată iconița reală de `ButtonA` etc.).

### 9. Latența de input și bucla de randare

`RunService` oferă `Heartbeat`, `Stepped` și evenimente de randare, dar documentația recomandă explicit `BindToRenderStep(name, priority, fn)` în locul conectării directe, pentru control asupra ordinii de execuție (`Enum.RenderPriority`). Pentru urmărirea unui drag (poziția vizuală a unei plase în timp ce e trasă), procesarea trebuie să fie pe partea de randare a client-ului, nu în bucle server-side — asta e oricum implicit adevărat pentru `UIDragDetector`, care rulează integral client-side.

### 10. Pinch/zoom și pan (dacă lumea depășește ecranul)

Nu există un echivalent 2D al `Camera` pentru `ScreenGui`. Dacă Driftwood ajunge să aibă un teren de jucător mai mare decât ecranul, singura cale e manuală: un `Frame` „lume" mai mare decât viewport-ul, poziționat printr-un offset controlat de:
- `GuiObject.TouchPan` (translație cu un deget) și `TouchPinch` (scală) pe mobil;
- `MouseWheelForward/Backward` pentru zoom și drag cu butonul din mijloc/dreapta pentru pan, pe desktop;
- `Thumbstick2` mapat manual pe offset, pe gamepad.

Aceasta e o soluție construită manual, nu un API dedicat Roblox — de tratat ca decizie de design, nu ca fapt din documentație.

### 11. Accesibilitate — ce oferă motorul gratuit

```lua
local GuiService = game:GetService("GuiService")

local function applyAccessibilityPrefs()
    local transparency = GuiService.PreferredTransparency -- 0..1, 1 = implicit
    hud.BackgroundTransparency = baseTransparency * transparency

    if GuiService.ReducedMotionEnabled then
        TWEEN_TIME = 0
    end

    -- PreferredTextSize: Medium/Large/Larger/Largest -> scaleaza UIScale sau font direct
end

GuiService:GetPropertyChangedSignal("ReducedMotionEnabled"):Connect(applyAccessibilityPrefs)
applyAccessibilityPrefs()
```

## Recomandari concrete pentru Driftwood

1. **Folosește `UIDragDetector` pentru plasarea plaselor**, nu un state-machine manual pe `InputBegan`/`InputChanged`/`InputEnded`. Motiv: mouse, touch și gamepad (mod selecție) sunt gestionate automat de motor, cu mult mai puțin cod și mai puține clase de bug-uri (drag „blocat" dacă degetul iese din ecran etc.).
2. **`BoundingBehavior = EntireObject` + `BoundingUI` = containerul malului**, ca plasa să nu poată fi trasă vizual în afara zonei valide. Nu înlocuiește validarea server — e doar UX.
3. **`ResponseStyle = Offset`**, nu `Scale`, pentru comportament predictibil indiferent de raportul de aspect al ecranului (mobil portret vs. desktop landscape).
4. **Snap-la-slot prin `AddConstraintFunction`**, exact tiparul din exemplul oficial de grid-snapping — e hook-ul menit pentru asta, nu trebuie reinventat.
5. **Preview de validitate doar cosmetic pe client** (culoare pe `DragContinue`), cu **confirmare finală printr-un `RemoteFunction` la `DragEnd`**, conform regulii „server autoritar" deja stabilite în `CLAUDE.md`. Dacă serverul refuză (slot ocupat între timp), animă plasa înapoi la poziția de start.
6. **Folosește `Activated` pe toate butoanele HUD/atelier**, nu `MouseButton1Click` — funcționează identic pe mouse, touch și gamepad fără cod suplimentar per-dispozitiv.
7. **Verifică `gameProcessedEvent`** oriunde ai și logică de input pe „fundal" (ex. click pe râu pentru debug/inspectare) ca să nu se declanșeze concomitent cu un click pe un buton HUD suprapus.
8. **Setează `Selectable = true` + `NextSelectionUp/Down/Left/Right` din prima etapă de implementare a HUD-ului**, nu ca adăugire ulterioară. Motiv: e cerință de bază pentru certificare console și e ieftin de făcut din start, costisitor de adăugat retroactiv peste 200+ elemente de index de reparații.
9. **Citește și aplică `GuiService.PreferredTransparency`/`PreferredTextSize`/`ReducedMotionEnabled` la login**, în loc de un meniu de setări custom pentru accesibilitate — sunt preferințe deja setate de jucător la nivel de platformă/dispozitiv.
10. **Dacă țintești vreodată console**: dezactivează explicit chatul, folosește dimensiuni relative + `GuiService.ViewportDisplaySize` pentru layout adaptiv, și testează navigarea completă doar cu gamepad (fără mouse/touch) înainte de submit la certificare.
11. **Pentru acțiuni discrete în afara elementelor de UI** (ex. o tastă rapidă „deschide index"), folosește `ContextActionService:BindAction` cu `createTouchButton = true` — dar ține cont de plafonul de 7 butoane; pentru mai multe acțiuni simultane, construiește butoane `GuiButton` proprii în loc să te bazezi pe generarea automată.
12. **Nu implementa pan/zoom decât dacă design-ul de nivel chiar cere o "lume" mai mare decât ecranul** — dacă fiecare teren de jucător încape pe ecran (probabil cazul pentru Driftwood, judecând după `CLAUDE.md`), evită complet complexitatea de camera 2D manuală.
13. **Folosește `RunService:BindToRenderStep`** (cu un nume unic și o prioritate din `Enum.RenderPriority`) pentru orice logică proprie de update per-frame legată de input, nu conectare directă — pentru control explicit al ordinii față de alte sisteme (randare râu, HUD).

## Riscuri si necunoscute

- Nu există, în sursele găsite, o comparație oficială explicită „UserInputService vs. ContextActionService vs. Input Action System" pentru cazul specific „joc 2D pur `ScreenGui`, fără `Humanoid`". Recomandările oficiale par orientate spre jocuri 3D cu personaj. Aplicabilitatea Input Action System la Driftwood rămâne **NEVERIFICAT** — probabil inutil pentru interacțiunea cu plase/atelier (unde `UIDragDetector`/`GuiButton` sunt suficiente), dar posibil util pentru comenzi globale multi-dispozitiv (deschide meniu, pauză).
- Data exactă a lansării `UIDragDetector` (beta → GA) nu a putut fi confirmată — WebSearch a fost indisponibil în această sesiune (buget epuizat înainte de prima căutare) și căutările alternative prin Bing/DuckDuckGo au fost blocate (CAPTCHA sau rezultate irelevante). Documentația oficială e live și pare stabilă la data accesării (2026-09-08), dar **istoricul exact NEVERIFICAT**.
- Nicio cifră oficială de „dimensiune minimă recomandată pentru tap target" (px) sau raport de contrast (tip WCAG) nu a fost găsită în pagina de accesibilitate consultată — **NEVERIFICAT**.
- Semantica exactă a fiecărei valori `UIDragDetectorBoundingBehavior` (Automatic vs. EntireObject vs. HitPoint) a fost confirmată doar ca listă de nume, fără text de descriere per-valoare în sursele accesate — comportamentul exact **trebuie testat în Studio**.
- Interacțiunea `UIDragDetector` cu un `ScrollingFrame` (dacă sloturile de plasare ar fi într-o listă derulabilă) nu e documentată explicit în materialul găsit — **de testat**.
- Comportamentul exact al `DragUDim2`/`ResponseStyle = Scale` la schimbare de rezoluție a ferestrei **în timpul** unui drag activ nu e documentat — **de testat**.
- Nu s-a putut confirma dacă proprietăți individuale ale `UIDragDetector` sunt marcate „beta" undeva în afara paginii principale (unele API-uri Roblox au etichete de versiune per-proprietate, nevăzute în extragerile automate folosite aici).

## Intrebari deschise

1. Driftwood țintește vreodată console (Xbox)? Dacă da, `Selectable`/`NextSelection*` pe fiecare element de UI trebuie planificat din pasul 1 al implementării, nu adăugat later — retrofit-ul peste indexul de 200+ obiecte ar fi costisitor.
2. Slotul de plasare a plasei pe mal e o poziție **discretă** (grid fix) sau **continuă** de-a lungul malului? Răspunsul determină dacă `AddConstraintFunction` trebuie să facă snap la grid sau doar clamping în interiorul unei zone valide.
3. Ce se întâmplă vizual când doi jucători încearcă simultan să tragă o plasă spre același slot? Serverul e sursa de adevăr, dar experiența pe client (ex. slotul devine "ocupat" în timp real) trebuie proiectată — posibil printr-un `RemoteEvent` de sincronizare a stării sloturilor către toți clienții de pe server.
4. Are Driftwood nevoie reală de pan/zoom (lume mai mare decât ecranul) sau fiecare teren de jucător încape integral pe ecran? Dacă răspunsul e "da, la un moment dat", arhitectura de coordonate a întregului sistem de randare 2D trebuie gândită de la început cu un offset de "cameră virtuală", nu adăugată ulterior.
5. **De testat direct în Studio** (nu poate fi confirmat din documentație): comportamentul `UIDragDetector` peste un `ScrollingFrame`; diferența vizibilă `Enum.SelectionBehavior.Escape` vs. `Stop` pe un HUD cu mai multe grupuri (ex. bară de acțiuni vs. index de colecție); performanța cu multe `UIDragDetector`-e active simultan pe ecran (mai multe plase disponibile de tras deodată); comportamentul exact `BoundingBehavior.HitPoint` vs. `EntireObject` pe un `BoundingUI` cu formă neregulată.

## Surse

- [GuiObject | Roblox Creator Hub](https://create.roblox.com/docs/reference/engine/classes/GuiObject) — accesat 2026-09-08
- [GuiObject.yaml, creator-docs (GitHub)](https://github.com/Roblox/creator-docs/blob/main/content/en-us/reference/engine/classes/GuiObject.yaml) — accesat 2026-09-08
- [GuiButton | Roblox Creator Hub](https://create.roblox.com/docs/reference/engine/classes/GuiButton) — accesat 2026-09-08
- [GuiBase2d | Roblox Creator Hub](https://create.roblox.com/docs/reference/engine/classes/GuiBase2d) — accesat 2026-09-08
- [UserInputService | Roblox Creator Hub](https://create.roblox.com/docs/reference/engine/classes/UserInputService) — accesat 2026-09-08
- [UserInputService.yaml, creator-docs (GitHub)](https://github.com/Roblox/creator-docs/blob/main/content/en-us/reference/engine/classes/UserInputService.yaml) — accesat 2026-09-08
- [ContextActionService | Roblox Creator Hub](https://create.roblox.com/docs/reference/engine/classes/ContextActionService) — accesat 2026-09-08
- [ContextActionService.yaml, creator-docs (GitHub)](https://github.com/Roblox/creator-docs/blob/main/content/en-us/reference/engine/classes/ContextActionService.yaml) — accesat 2026-09-08
- [GuiService | Roblox Creator Hub](https://create.roblox.com/docs/reference/engine/classes/GuiService) — accesat 2026-09-08
- [GuiService.yaml, creator-docs (GitHub)](https://github.com/Roblox/creator-docs/blob/main/content/en-us/reference/engine/classes/GuiService.yaml) — accesat 2026-09-08
- [UI Drag Detectors | Roblox Creator Hub](https://create.roblox.com/docs/ui/ui-drag-detectors) — accesat 2026-09-08
- [UIDragDetector | Roblox Creator Hub](https://create.roblox.com/docs/reference/engine/classes/UIDragDetector) — accesat 2026-09-08
- [UIDragDetector.yaml, creator-docs (GitHub)](https://github.com/Roblox/creator-docs/blob/main/content/en-us/reference/engine/classes/UIDragDetector.yaml) — accesat 2026-09-08
- [UIDragDetectorDragStyle | Roblox Creator Hub](https://create.roblox.com/docs/reference/engine/enums/UIDragDetectorDragStyle) — accesat 2026-09-08
- [UIDragDetectorBoundingBehavior | Roblox Creator Hub](https://create.roblox.com/docs/reference/engine/enums/UIDragDetectorBoundingBehavior) — accesat 2026-09-08
- [UIDragDetectorResponseStyle | Roblox Creator Hub](https://create.roblox.com/docs/reference/engine/enums/UIDragDetectorResponseStyle) — accesat 2026-09-08
- [UIDragDetectorDragRelativity.yaml, creator-docs (GitHub)](https://github.com/Roblox/creator-docs/blob/main/content/en-us/reference/engine/enums/UIDragDetectorDragRelativity.yaml) — accesat 2026-09-08
- [UIDragDetectorDragSpace.yaml, creator-docs (GitHub)](https://github.com/Roblox/creator-docs/blob/main/content/en-us/reference/engine/enums/UIDragDetectorDragSpace.yaml) — accesat 2026-09-08
- [SelectionBehavior.yaml, creator-docs (GitHub)](https://github.com/Roblox/creator-docs/blob/main/content/en-us/reference/engine/enums/SelectionBehavior.yaml) — accesat 2026-09-08
- [UserInputType | Roblox Creator Hub](https://create.roblox.com/docs/reference/engine/enums/UserInputType) — accesat 2026-09-08
- [KeyCode | Roblox Creator Hub](https://create.roblox.com/docs/reference/engine/enums/KeyCode) — accesat 2026-09-08
- [UserInputState | Roblox Creator Hub](https://create.roblox.com/docs/reference/engine/enums/UserInputState) — accesat 2026-09-08
- [RunService | Roblox Creator Hub](https://create.roblox.com/docs/reference/engine/classes/RunService) — accesat 2026-09-08
- [Input | Roblox Creator Hub](https://create.roblox.com/docs/input) — accesat 2026-09-08
- [Input Action System | Roblox Creator Hub](https://create.roblox.com/docs/input/input-action-system) — accesat 2026-09-08
- [Gamepad Input | Roblox Creator Hub](https://create.roblox.com/docs/input/gamepad) — accesat 2026-09-08
- [Mobile Input | Roblox Creator Hub](https://create.roblox.com/docs/input/mobile) — accesat 2026-09-08
- [Mouse and Keyboard Input | Roblox Creator Hub](https://create.roblox.com/docs/input/mouse-and-keyboard) — accesat 2026-09-08
- [Detect User Input tutorial | Roblox Creator Hub](https://create.roblox.com/docs/tutorials/use-case-tutorials/input-and-camera/detect-user-input) — accesat 2026-09-08
- [Console Guidelines | Roblox Creator Hub](https://create.roblox.com/docs/production/publishing/console-guidelines) — accesat 2026-09-08
- [Accessibility | Roblox Creator Hub](https://create.roblox.com/docs/production/publishing/accessibility) — accesat 2026-09-08
- [Proximity Prompts | Roblox Creator Hub](https://create.roblox.com/docs/ui/proximity-prompts) — accesat 2026-09-08 (context secundar, GamepadKeyCode/KeyboardKeyCode pentru prompturi)

**Notă de metodologie:** în această sesiune, unealta WebSearch a avut bugetul epuizat înainte de prima interogare (folosit probabil de alte procese din aceeași sesiune de lucru), deci cercetarea s-a bazat exclusiv pe `WebFetch` direct pe pagini `create.roblox.com/docs` și pe fișierele YAML sursă din repo-ul oficial `github.com/Roblox/creator-docs` (descoperite prin `sitemap.1.xml` al site-ului de documentație). Un prim fetch pe pagina de referință `UIDragDetector` a întors, aparent, conținut amestecat cu clasa 3D `DragDetector` (enum-uri gen `RotateAxis`/`TranslateViewPlane` care nu există de fapt pentru `UIDragDetector`) — acele valori au fost **respinse** după verificare încrucișată cu paginile de enum dedicate și cu fișierul YAML sursă, care confirmă doar 4 valori pentru `DragStyle` (TranslatePlane/TranslateLine/Rotate/Scriptable). Toate cifrele din acest document reflectă versiunea reconfirmată prin YAML.
