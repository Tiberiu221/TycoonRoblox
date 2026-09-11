# Mobil, tablete, console: cerințe și matrice de suport pentru Driftwood

## Rezumat executiv

- **Majoritatea sesiunilor Roblox se joacă pe mobil.** Documentația oficială o spune explicit ("The majority of Roblox sessions are played on mobile devices" — create.roblox.com/docs, Input/Mobile). O sursă secundară (backlinko.com, date estimate pentru 2025) dă un raport aproximativ **80% mobil / 17% desktop / 3% console** pe sesiuni — tratați acest procent ca estimare, nu cifră oficială Roblox.
- **Android domină, iar cea mai mare parte a bazei Android e slabă hardware.** Documentația oficială de performanță spune: Android ≈ 65% din baza tipică de jucători a unui joc; dintre aceștia, ~60% au 2–4 GB RAM, ~35% au 4–8 GB RAM, doar ~5% au peste 8 GB RAM. Peste 50% din baza de jucători Roblox rulează pe dispozitive cu scor Passmark între 10.000–20.000.
- **Driftwood trebuie proiectat mobile-first, nu desktop-first.** Fiind ScreenGui 2D, avantajul e că nu există cost de randare 3D — dar bugetul de memorie și Luau trebuie gândit pentru un telefon Android de gamă joasă-medie, nu pentru laptopul de dezvoltare.
- **`GuiService:IsTenFootInterface()` e deprecat.** Înlocuitorul oficial pentru detectarea „interfață TV/consolă" e `GuiService.ViewportDisplaySize` (`Enum.DisplaySize`: `Small` / `Medium` / `Large`), unde `Large` = televizoare/console.
- **Safe area pe mobil se rezolvă prin `ScreenGui.ScreenInsets`**, cu valoare implicită `CoreUISafeInsets`. Există și `GuiService:GetInsetArea(Enum.ScreenInsets)` pentru citire manuală și `ScreenGui.ClipToDeviceSafeArea` / `SafeAreaCompatibility`.
- **Consola cere UI de tip „10-foot"**: joc gândit pentru vizionare de la 8–10 picioare, navigare completă cu 4 direcții + select + back, chat dezactivat obligatoriu pe consolă, rating de conținut (maturitate) obligatoriu la publicare pentru consolă.
- **Roblox nu documentează public dimensiuni exacte în pixeli pentru touch target sau contrast minim** — nu există un echivalent oficial al Apple HIG (44×44pt) sau Material Design (48×48dp) pentru Roblox. Recomandarea practică vine din afara ecosistemului Roblox și trebuie tratată ca atare.
- **Sistemul de input recomandat pentru cod nou e Input Action System** (`InputContext`, `InputAction`, `InputBinding`, `InputActionLabel`) — unifică tastatură/mouse, touch și gamepad într-un singur set de acțiuni semantice ("Jump", "Sprint"), exact ce trebuie pentru plasele/reparatul din Driftwood ca să funcționeze identic pe toate platformele.
- **Testarea reală pe hardware e obligatorie**, nu doar emulare în Studio — documentația oficială numește explicit telefoane low-end de test (Infinix Smart 9, Motorola Moto G05, Oppo A18) și recomandă sesiuni de 10–15 minute pentru a detecta throttling termic.

## Fapte verificate

- Documentația oficială declară: „The majority of Roblox sessions are played on mobile devices." — Sursă: create.roblox.com/docs, pagina Input → Mobile (`/docs/en-us/input/mobile.md`), accesat 2026-09-08. Încredere: ridicata.
- Android reprezintă aproximativ 65% din baza tipică de jucători a unui joc Roblox; dintre jucătorii Android, ~60% au 2–4 GB RAM, ~35% au 4–8 GB RAM, ~5% au peste 8 GB RAM. — Sursă: create.roblox.com/docs, Performance Optimization → Test on Hardware (`/docs/en-us/performance-optimization/test-on-hardware.md`), accesat 2026-09-08. Încredere: ridicata.
- Peste 50% din baza de jucători Roblox joacă pe dispozitive cu scor Passmark între 10.000 și 20.000. — Aceeași sursă ca mai sus. Încredere: ridicata.
- Dispozitive Android low-end recomandate explicit pentru testare de documentația oficială: Infinix Smart 9, Motorola Moto G05, Oppo A18, plus Amazon Fire HD 10 (2023) pentru tabletă și Samsung Galaxy S22 Ultra ca reper high-end. — Aceeași sursă. Încredere: ridicata.
- `GuiService:IsTenFootInterface()` apare marcat explicit **Deprecated** în referința API curentă. — Sursă: create.roblox.com/docs, Engine Reference → GuiService (`/docs/reference/engine/classes/GuiService`), accesat 2026-09-08. Încredere: ridicata.
- `GuiService.ViewportDisplaySize` returnează `Enum.DisplaySize` cu trei membri: `Small` (0), `Medium` (1), `Large` (2). — Sursă: create.roblox.com/docs, Engine Reference → Enum DisplaySize, accesat 2026-09-08. Încredere: ridicata.
- `Enum.ScreenInsets` are patru membri: `None` (0), `DeviceSafeInsets` (1), `CoreUISafeInsets` (2), `TopbarSafeInsets` (3), folosiți cu `GuiService:GetInsetArea(screenInsets): Rect`. — Sursă: create.roblox.com/docs, Engine Reference → Enum ScreenInsets și GuiService.GetInsetArea, accesat 2026-09-08. Încredere: ridicata.
- `ScreenGui.ScreenInsets` are valoarea implicită `CoreUISafeInsets`, care ține automat conținutul copiilor departe de top bar-ul Roblox și de cutout-urile ecranului (notch). — Sursă: create.roblox.com/docs, UI → On-Screen Containers (`/docs/en-us/ui/on-screen-containers.md`), accesat 2026-09-08. Încredere: ridicata.
- `ScreenGui` are proprietățile confirmate: `ClipToDeviceSafeArea` (boolean), `DisplayOrder` (number), `IgnoreGuiInset` (boolean, tot există, marcat Not Replicated), `SafeAreaCompatibility` (`Enum.SafeAreaCompatibility`), `ScreenInsets` (`Enum.ScreenInsets`). — Sursă: create.roblox.com/docs, Engine Reference → ScreenGui, accesat 2026-09-08. Încredere: ridicata.
- `Enum.ScreenOrientation` are cinci membri: `LandscapeLeft` (0), `LandscapeRight` (1), `LandscapeSensor` (2, implicit), `Portrait` (3), `Sensor` (4). Se setează cu `StarterGui.ScreenOrientation` la start și se poate schimba live cu `PlayerGui.ScreenOrientation`; orientarea curentă se citește din `PlayerGui.CurrentScreenOrientation`. — Sursă: create.roblox.com/docs, Input → Mobile + Engine Reference → Enum ScreenOrientation, accesat 2026-09-08. Încredere: ridicata.
- `UserInputService` expune șase proprietăți read-only, non-replicate, pentru detecția tipului de input disponibil: `TouchEnabled`, `GamepadEnabled`, `KeyboardEnabled`, `MouseEnabled`, `AccelerometerEnabled`, `GyroscopeEnabled` — toate necesită capabilitatea „Input". — Sursă: create.roblox.com/docs, Engine Reference → UserInputService, accesat 2026-09-08. Încredere: ridicata.
- `GuiBase2d` expune `AbsolutePosition` (Vector2), `AbsoluteSize` (Vector2), `AbsoluteRotation` (Rotation2D) — toate read-only, calculate în coordonate de ecran; se pot asculta cu `:GetPropertyChangedSignal("AbsoluteSize")` pentru resize pe desktop. — Sursă: create.roblox.com/docs, Engine Reference → GuiBase2d, accesat 2026-09-08. Încredere: ridicata.
- Publicarea unei experiențe are un câmp „Devices" în setările de bază, care controlează pentru ce tipuri de dispozitive e disponibilă experiența; opțiunile implicite sunt descrise ca „practical for most new creators", fără enumerare explicită a listei complete în textul extras. — Sursă: create.roblox.com/docs, Production → Publishing → Publish Games and Places, accesat 2026-09-08. Încredere: medie (lista exactă de opțiuni — Computer/Phone/Tablet/Console/VR — nu a fost confirmată verbatim din pagina fetch-uită, dar corespunde configurației cunoscute din Creator Dashboard).
- Ghidul oficial de consolă cere UI gândit pentru vizionare de la 8–10 picioare („10-foot UI"), dezvoltare întâi pentru rezoluții joase, mărimi relative + `UISizeConstraint`, `ScrollingFrame` pentru a reduce aglomerarea, zone sigure (TV-safe areas) pentru elementele critice, navigare completă cu 4 direcții + select + back, dezactivarea ferestrelor de chat pe consolă, și obligativitatea informațiilor de maturitate a conținutului la publicare pentru consolă. — Sursă: create.roblox.com/docs, Production → Publishing → Console Guidelines (`/docs/en-us/production/publishing/console-guidelines.md`), accesat 2026-09-08. Încredere: ridicata.
- `GuiService.ViewportDisplaySize` clasifică dispozitivele în 3 categorii: `Small` (tablete, mobil, portabile), `Medium` (laptop-uri și monitoare), `Large` (televizoare/console). — Sursă: create.roblox.com/docs, Projects → Cross-Platform (`/docs/en-us/projects/cross-platform.md`), accesat 2026-09-08. Încredere: ridicata.
- Studio oferă un **Device Emulator** și un **Controller Emulator** ca instrumente native de test, dar documentația nu enumeră o listă fixă de presetări de dispozitiv într-o pagină dedicată accesibilă public la data cercetării. — Sursă: create.roblox.com/docs, Cross-Platform + Micro-Gamepad (menționează „Device Emulator (Android TV selection)"), accesat 2026-09-08. Încredere: medie — lista completă de presetări trebuie verificată direct în Studio (vezi „Întrebări deschise").
- Roblox acceptă input de la telecomenzi TV / micro-gamepad-uri prin sloturile `Gamepad1`–`Gamepad8`; un micro-gamepad se identifică prin absența suportului pentru `Thumbstick1`/`Thumbstick2`; keycode-uri standard: `ButtonUp`, `ButtonDown`, `ButtonLeft`, `ButtonRight`, `ButtonCenter`, `ButtonBack`. — Sursă: create.roblox.com/docs, Input → Micro-Gamepad, accesat 2026-09-08. Încredere: ridicata.
- Input Action System (recomandat pentru cod nou) e format din `InputContext`, `InputAction` (tipuri: `Bool`, `Direction1D`, `Direction2D`, `Direction3D`, `ViewportPosition`), `InputBinding`, cu evenimente `Pressed`/`Released`/`StateChanged` și componenta no-code `InputActionLabel` pentru afișarea automată a iconiței corecte per platformă. — Sursă: create.roblox.com/docs, Input → Input Action System, accesat 2026-09-08. Încredere: ridicata.
- Setările de accesibilitate expuse jucătorului: `PreferredTransparency` (0–1), `PreferredTextSize` (`Medium`/`Large`/`Larger`/`Largest`), `ReducedMotionEnabled` (boolean) — fără cifre exacte publicate pentru contrast minim sau mărime minimă de text în pixeli. — Sursă: create.roblox.com/docs, Production → Publishing → Accessibility, accesat 2026-09-08. Încredere: ridicata (pentru existența proprietăților) / lipsă date (pentru cifre exacte, marcat NEVERIFICAT mai jos).
- DAU Roblox raportat oficial pentru trimestrul încheiat: Q2 2026 — comunicatul de rezultate financiare confirmă doar data (30 iulie 2026, San Mateo, Calif.) și trimite cititorul la „shareholder letter" de pe ir.roblox.com pentru cifre; comunicatul-sursă în sine NU conține cifre de DAU sau breakdown pe platformă. — Sursă: PDF oficial `Roblox-Q2-2026-Earnings-Press-Release.pdf`, s27.q4cdn.com (domeniu CDN al ir.roblox.com), accesat 2026-09-08. Încredere: ridicata (pentru dată), scăzută (pentru orice cifră de DAU — nu era în acest document).
- DAU Roblox, Q4 2025: ~144,5 milioane (creștere de 69,4% față de 85,3 milioane în Q4 2024); split de sesiuni pe platformă citat: Mobil 80%, Desktop 17%, Console 3%; raport DAU/MAU de 20,92% pentru 2024. — Sursă secundară: backlinko.com/roblox-users, agregator de statistici care pretinde că citează filing-uri SEC oficiale dar nu oferă link direct verificabil în conținutul extras. Accesat 2026-09-08. Încredere: **medie** — cifrele de DAU agregat sunt plauzibile și consistente cu tendința de creștere Roblox, dar split-ul exact 80/17/3 NU a putut fi confirmat direct într-un raport financiar oficial Roblox în această cercetare; Roblox nu publică de regulă breakdown pe platformă în shareholder letter. Tratați procentul ca estimare de ordin de mărime, nu cifră exactă.
- Roblox a lansat pe platforme: iOS (11 decembrie 2012, versiune completă), Android (16 iulie 2014), Xbox One (20 noiembrie 2015), Meta Quest 2/Quest Pro (septembrie 2023), PlayStation 4 (10 octombrie 2023), PlayStation 5 (14 aprilie 2026, „via backward compatibility" conform sursei). — Sursă secundară: en.wikipedia.org/wiki/Roblox, accesat 2026-09-08. Încredere: medie — datele mai vechi (pre-2023) au încredere ridicată fiind fapte istorice stabile; data PS5 (aprilie 2026) e recentă și marcată **NEVERIFICAT** independent — formularea „via backward compatibility" e neobișnuită de vreme ce PS4 avea deja compatibilitate descendentă pe PS5 din 2023, deci s-ar putea referi la un client nativ PS5 sau la altceva; necesită confirmare dintr-un anunț oficial Roblox/Sony.

## Detalii

### 1. Mixul de platforme și ce înseamnă pentru Driftwood

Roblox confirmă oficial, fără cifră exactă, că majoritatea sesiunilor sunt mobile. Estimarea secundară (backlinko, 2025) de **80% mobil / 17% desktop / 3% console** e consistentă cu ce se știe public despre Roblox de ani buni (istoric, Roblox a raportat în trecut cifre similare de ~2/3 mobil în cifre de utilizatori, cu sesiuni mobile disproporționat de multe pentru că sesiunile mobile sunt mai scurte și mai frecvente). Pentru Driftwood, concluzia practică e simplă: **UI-ul, touch targets și performanța pe telefon sunt cazul principal, nu cazul special.** Testarea și design-ul „desktop-first, apoi adaptăm la mobil" ar inversa greșit prioritatea de efort.

Consola e sub 5% din sesiuni (estimare). Suportul de consolă merită implementat pentru că API-urile de input (Input Action System) fac asta aproape gratuit dacă e proiectat corect de la început — dar nu merită sesiuni dedicate de optimizare vizuală până când mobilul și desktopul sunt solide.

### 2. Bugete de performanță și memorie — realitatea hardware Android

Cifrele oficiale din Test on Hardware sunt esențiale pentru planificare:

| Segment | Procent din jucătorii Android | Sursă |
|---|---|---|
| 2–4 GB RAM | ~60% | create.roblox.com/docs, Test on Hardware |
| 4–8 GB RAM | ~35% | idem |
| >8 GB RAM | ~5% | idem |
| Scor Passmark 10.000–20.000 | >50% din toată baza Roblox | idem |
| Android ca % din baza tipică de jucători | ~65% | idem |

Dispozitive de test recomandate explicit de documentație (low-end → high-end):
- **Infinix Smart 9** — telefon low-end
- **Motorola Moto G05** — telefon low-end
- **Oppo A18** — telefon low-end
- **Amazon Fire HD 10 (2023)** — tabletă buget
- **Samsung Galaxy S22 Ultra** — reper high-end

Recomandarea oficială e să testați sesiuni de **10–15 minute** de gameplay activ pentru a detecta degradarea FPS din throttling termic — relevant direct pentru Driftwood, unde sesiunile lungi de „verificat plasele + reparat" sunt exact cazul de utilizare central.

Pentru un joc 2D pur în ScreenGui ca Driftwood, avantajul e uriaș față de un joc 3D: nu există cost de randare de geometrie, shadere, sau streaming de mesh-uri. Costurile reale de urmărit sunt:
- Numărul de `Instance`-uri GUI active simultan (fiecare `Frame`/`ImageLabel` are cost de layout și randare)
- Scripturi Luau care rulează pe `RenderStepped`/`Heartbeat` (bucla de update a râului, coliziunile AABB)
- Memoria ocupată de imagini/sprite-uri încărcate (atlas-uri, cache de imagini)
- `DataStoreService` — chemări de rețea, nu cost local, dar latența variază mult pe mobil cu conexiune slabă

### 3. Safe area, notch-uri, orientare

API-ul relevant e complet documentat și stabil:

```lua
-- Citire manuală a zonei sigure
local insetRect = GuiService:GetInsetArea(Enum.ScreenInsets.DeviceSafeInsets)

-- Pe un ScreenGui, comportamentul implicit e deja sigur:
screenGui.ScreenInsets = Enum.ScreenInsets.CoreUISafeInsets -- valoare implicită
screenGui.ClipToDeviceSafeArea = true
```

`Enum.ScreenInsets` are 4 membri (`None`, `DeviceSafeInsets`, `CoreUISafeInsets`, `TopbarSafeInsets`). Diferența practică:
- `DeviceSafeInsets` — doar hardware-ul (notch, colțuri rotunjite, camera perforată)
- `CoreUISafeInsets` — hardware + top bar-ul Roblox (butoanele de meniu, chat, avatar) — **acesta e implicit pe `ScreenGui`**
- `TopbarSafeInsets` — doar zona de sub top bar

Pentru Driftwood: fiindcă interfața ocupă tot ecranul permanent (râul, plasele, HUD de resurse), trebuie poziționate manual elementele critice (butoane de acțiune, indicatori de resurse) în interiorul `CoreUISafeInsets`, verificat separat pe orientare `LandscapeSensor` (implicit pe mobil) și pe desktop unde nu există insets fizice dar tot există top bar-ul Roblox.

Orientare: `StarterGui.ScreenOrientation` se setează o singură dată la pornire; `PlayerGui.ScreenOrientation` poate fi schimbat live (util dacă vreți să forțați landscape doar în anumite ecrane); `PlayerGui.CurrentScreenOrientation` se poate asculta pentru reacție la schimbare fizică a telefonului.

### 4. Resize pe desktop

Nu există un eveniment „WindowResized" dedicat documentat separat — mecanismul standard e să ascultați `AbsoluteSize` (proprietate din `GuiBase2d`, moștenită de `Frame`, `ScreenGui` etc.):

```lua
local screenGui = playerGui:WaitForChild("MainUI")
screenGui:GetPropertyChangedSignal("AbsoluteSize"):Connect(function()
    local size = screenGui.AbsoluteSize
    -- recalculați layout, poziții relative, UIScale etc.
end)
```

`AbsoluteSize`, `AbsolutePosition`, `AbsoluteRotation` sunt read-only și calculate automat de motor la fiecare schimbare de fereastră/rezoluție — confirmate ca proprietăți reale în referința API pentru `GuiBase2d`.

### 5. Detecția tipului de dispozitiv / input

`UserInputService` oferă 6 proprietăți boolean read-only pentru ce hardware e disponibil (nu neapărat ce folosește jucătorul activ acum):

```lua
local UserInputService = game:GetService("UserInputService")

if UserInputService.TouchEnabled then
    -- dispozitiv cu ecran tactil (telefon/tabletă) — dar poate avea și tastatură conectată
end
if UserInputService.GamepadEnabled then
    -- gamepad conectat/disponibil
end
```

Important: `TouchEnabled = true` NU înseamnă automat telefon fără tastatură — un Chromebook sau o tabletă cu tastatură Bluetooth poate avea ambele. Pentru „ce folosește jucătorul chiar acum" pentru scopuri de UI (ex. ce iconițe să arăți), API-ul recomandat de documentație e Input Action System, cu `PreferredBinding` (per acțiune) sau logica de `PreferredInput` menționată în pagina de Mobile — acestea reflectă dispozitivul curent folosit activ, nu doar ce hardware există.

Pentru consolă/TV, înlocuitorul lui `IsTenFootInterface()` (deprecat) e:

```lua
local GuiService = game:GetService("GuiService")

if GuiService.ViewportDisplaySize == Enum.DisplaySize.Large then
    -- interfață gândită pentru TV/consolă: text mare, navigare gamepad, safe area TV
end
```

### 6. Cerințe specifice consolă (Xbox/PlayStation)

Ghidul oficial de consolă (`console-guidelines.md`) stabilește:

1. **Distanță de vizionare 8–10 picioare** → text și elemente semnificativ mai mari decât pe mobil/desktop.
2. **Proiectare pentru rezoluție joasă întâi**, apoi scalare în sus (opus modului tipic web „mobile-first apoi desktop").
3. **Mărimi relative** (procent din dimensiunea frame-ului) + `UISizeConstraint` pentru limite min/max.
4. **`ScrollingFrame`** obligatoriu pentru orice listă care s-ar aglomera la scalare mare.
5. **TV-safe areas** — unele televizoare nu afișează conținutul complet până la margine; elementele critice nu trebuie plasate la marginea absolută a ecranului.
6. **Navigare completă cu 4 direcții + select + back** — orice element interactiv trebuie accesibil doar cu D-pad/thumbstick + 2 butoane, fără mouse.
7. **Chat dezactivat obligatoriu pe consolă** (cerință de platformă, nu opțiune de design).
8. **Rating de maturitate a conținutului obligatoriu** la publicare pentru consolă, pentru a evita respingere/retragere.
9. **`InputActionLabel`** sau metodele din `UserInputService` pentru afișarea automată a iconiței butonului corecte per platformă (glyph Xbox vs PlayStation).
10. **Haptics** (`HapticEffect`) recomandate pentru evenimente de impact (coliziuni, confirmări UI) — suportate documentat pe gamepad-uri PlayStation, Xbox și Quest Touch.
11. **Progressive disclosure** — ecranele complexe trebuie împărțite în meniuri secundare, nu înghesuite într-un singur ecran.

Micro-gamepad-urile (telecomenzi TV, Android TV remote) sunt un caz separat: intră tot pe sloturile `Gamepad1`–`Gamepad8`, dar fără suport pentru thumbstick-uri — se detectează testând absența `Thumbstick1`/`Thumbstick2` pe `Gamepad1`. Suportă doar 6 keycode-uri de navigare (`ButtonUp/Down/Left/Right/Center/Back`).

### 7. Ce documentația NU specifică (și de ce contează)

Documentația oficială Roblox **nu publică**:
- O dimensiune minimă exactă în pixeli/puncte pentru un buton touch. Referințele general acceptate din industrie (Apple Human Interface Guidelines: minim 44×44pt; Google Material Design: minim 48×48dp) **nu sunt cerințe Roblox** — sunt convenții externe pe care le puteți adopta ca regulă internă, dar nimic din engine le impune.
- Un raport de contrast minim (gen WCAG AA 4.5:1) — documentația de accesibilitate cere doar „contrast suficient" fără cifră.
- O listă completă, cu rezoluții exacte, a presetărilor din Device Emulator din Studio — trebuie verificată direct în Studio (Test tab → Device).
- Cerințe minime de sistem (RAM/CPU/OS) pentru instalarea clientului Roblox pe fiecare platformă — pagina de Help Center (en.help.roblox.com) care ar conține de regulă aceste cifre a răspuns cu HTTP 403 la accesul automat în această cercetare; necesită verificare manuală în browser.
- Breakdown oficial de DAU pe platformă (mobil/desktop/console) în rapoartele financiare — comunicatul Q2 2026 trimite explicit la „shareholder letter", document care nu a putut fi extras complet în această cercetare.

## Recomandari concrete pentru Driftwood

1. **Proiectați layout-ul principal (râul + plase + HUD) mobile-first, în orientare `LandscapeSensor`.** Justificare: majoritatea documentată a sesiunilor e mobilă; side-scroll-ul Driftwood are nevoie de lățime, deci landscape e orientarea naturală și cea implicită deja pe Roblox mobil.
2. **Setați explicit `ScreenGui.ScreenInsets = Enum.ScreenInsets.CoreUISafeInsets`** (deja implicit, dar setați-l explicit în cod pentru claritate) pe fiecare `ScreenGui` principal, și verificați manual poziționarea butoanelor de acțiune (plasă, reparat) să nu cadă sub top bar sau sub notch pe un telefon cu cutout mare.
3. **Testați pe cel puțin un dispozitiv din lista oficială low-end** (Infinix Smart 9, Moto G05, sau Oppo A18, dacă disponibil în regiune; altfel orice Android cu 2–3 GB RAM) înainte de fiecare milestone din „Ordinea de lucru" din CLAUDE.md. Motiv: 60% din baza Android are 2–4 GB RAM — dacă Driftwood nu rulează fluid acolo, pierdeți majoritatea utilizatorilor mobili.
4. **Rulați teste de sesiune de 10–15 minute** pe device fizic, nu doar în Studio, la fiecare sistem nou adăugat (râu, reparat, atelier). Motiv: throttling termic e menționat explicit ca risc documentat oficial, iar Driftwood e gândit pentru sesiuni lungi de „verificat + reparat".
5. **Folosiți Input Action System de la început, nu `UserInputService`/`ContextActionService` brut**, pentru toate acțiunile de gameplay (plasă, prindere, reparat, donare). Motiv: un singur set de `InputAction` cu `InputBinding` pentru tastatură+mouse, touch și gamepad elimină trei implementări paralele și dă suport de consolă aproape gratuit.
6. **Folosiți `GuiService.ViewportDisplaySize == Enum.DisplaySize.Large` pentru a comuta la un layout „10-foot"** (text mai mare, elemente mai rare, navigare cu focus vizibil) — nu folosiți `IsTenFootInterface()`, e deprecat.
7. **Dezactivați orice chat pe consolă din cod**, condiționat de detecția de mai sus — e cerință de platformă documentată, nu opțiune.
8. **Nu implementați text input custom fără să testați tastatura nativă on-screen** pe telefon și pe consolă — documentația nu detaliază comportamentul `TextBox` pe aceste platforme; testați manual în Studio cu Device Emulator + pe device fizic înainte de a construi ecrane cu input de text (nume, chat, denumire obiecte).
9. **Adoptați intern 44×44pt (iOS) / 48×48dp (Android) ca regulă minimă pentru touch targets** (plasă, butoane de reparat/donare), deși nu e cerință Roblox — e cea mai apropiată bază obiectivă disponibilă, mai bună decât ghicit.
10. **Ascultați `AbsoluteSize` pe `ScreenGui`-ul principal** pentru a recalcula layout-ul la resize de fereastră pe desktop (utilizatori care redimensionează fereastra Roblox pe PC), nu presupuneți o rezoluție fixă.
11. **La publicare, verificați manual câmpul „Devices" din Basic Info** ca să includeți explicit Console dacă vreți suport de lansare pe Xbox/PlayStation — nu presupuneți că e activat implicit fără verificare, deoarece documentația nu confirmă lista exactă de opțiuni implicite.

## Riscuri si necunoscute

- **Split-ul 80/17/3 (mobil/desktop/console) nu e confirmat oficial** — e o estimare secundară. Dacă planificarea bugetului de monetizare sau a priorităților de optimizare depinde critic de acest procent, riscul e suprainvestiție sau subinvestiție în consolă/desktop.
- **Data de lansare PS5 (14 aprilie 2026, „via backward compatibility")** vine dintr-o singură sursă secundară (Wikipedia) cu formulare ambiguă — nu a putut fi confirmată printr-un anunț oficial Roblox/Sony în această cercetare. Marcat NEVERIFICAT.
- **Cerințele minime de sistem oficiale (RAM/OS/spațiu pe disc) nu au putut fi accesate** — pagina de Help Center relevantă a blocat accesul automat (HTTP 403). Trebuie verificată manual.
- **Lista completă de presetări din Studio Device Emulator nu a fost găsită documentată public** într-o pagină dedicată — necesită verificare directă în Studio.
- **Roblox nu specifică cifre exacte pentru touch target / contrast** — orice standard adoptat de Driftwood (ex. 44pt) e o decizie internă, nu o cerință de platformă, deci nu va fi validată automat la review.
- **Sesiunea de cercetare a avut bugetul de WebSearch epuizat înainte de start** (folosit deja de alte task-uri din aceeași sesiune) — cercetarea s-a bazat pe navigare directă în documentația create.roblox.com (confirmată prin `llms.txt`) plus căutări de rezervă prin Bing/DuckDuckGo (rezultate parțial nefolositoare) și fetch direct de pagini secundare cunoscute. Asta înseamnă acoperire mai slabă pentru surse foarte recente (devforum.roblox.com a blocat accesul automat cu 403 pe toate încercările).

## Intrebari deschise

1. Ce presetări exacte (nume + rezoluție) există în Device Emulator-ul din Studio în versiunea curentă? — de testat direct: Studio → tab Test → Device.
2. Care sunt cerințele minime reale de RAM/OS pentru clientul Roblox pe Android/iOS/Windows/Mac în 2026? — de verificat manual pe en.help.roblox.com (blocat pentru fetch automat).
3. Există un proces de „opt-in"/certificare separat pentru a activa Console în „Devices" la publicare, sau e doar un toggle? Ce rating de maturitate minim e acceptat pentru consolă? — de verificat în Creator Dashboard, secțiunea Basic Info a unei experiențe reale.
4. Comportamentul exact al tastaturii on-screen (`TextBox`) pe mobil și pe consolă — apare automat la focus? Poate fi stilizată? — de testat manual, documentația nu a detaliat.
5. Ce procent din DAU-ul Driftwood ar fi realist pe fiecare platformă, dat fiind că e un joc 2D lent, cu sesiuni lungi de tip „verifică și repară" — probabil diferit de media platformei Roblox (jocuri de acțiune/social au alt mix)? Nu poate fi răspuns fără date proprii, doar după lansare/soft-launch.
5. Merită să investiți timp de dezvoltare în suport de consolă la lansare, dat fiind că e sub 5% din sesiuni estimat, sau se amână pentru după ce bucla de retenție de bază e validată pe mobil? — decizie de prioritizare pentru owner, conform „Ordinea de lucru" din CLAUDE.md (nu treceți la sisteme secundare până cel de bază nu e testat).

## Surse

- create.roblox.com/docs — Input → Mobile: `https://create.roblox.com/docs/en-us/input/mobile` — accesat 2026-09-08 (documentație curentă, fără dată de ultimă modificare afișată)
- create.roblox.com/docs — Production → Publishing → Console Guidelines: `https://create.roblox.com/docs/en-us/production/publishing/console-guidelines` — accesat 2026-09-08
- create.roblox.com/docs — Production → Publishing → Adaptive Design: `https://create.roblox.com/docs/en-us/production/publishing/adaptive-design` — accesat 2026-09-08
- create.roblox.com/docs — Projects → Cross-Platform: `https://create.roblox.com/docs/en-us/projects/cross-platform` — accesat 2026-09-08
- create.roblox.com/docs — Performance Optimization → Test on Hardware: `https://create.roblox.com/docs/en-us/performance-optimization/test-on-hardware` — accesat 2026-09-08
- create.roblox.com/docs — Input → Gamepad: `https://create.roblox.com/docs/en-us/input/gamepad` — accesat 2026-09-08
- create.roblox.com/docs — Input → Input Action System: `https://create.roblox.com/docs/en-us/input/input-action-system` — accesat 2026-09-08
- create.roblox.com/docs — Input → Micro-Gamepad: `https://create.roblox.com/docs/en-us/input/micro-gamepad` — accesat 2026-09-08
- create.roblox.com/docs — Production → Publishing → Accessibility: `https://create.roblox.com/docs/en-us/production/publishing/accessibility` — accesat 2026-09-08
- create.roblox.com/docs — UI → On-Screen Containers: `https://create.roblox.com/docs/en-us/ui/on-screen-containers` — accesat 2026-09-08
- create.roblox.com/docs — Production → Publishing → Publish Games and Places: `https://create.roblox.com/docs/en-us/production/publishing/publish-games-and-places` — accesat 2026-09-08
- create.roblox.com/docs — Engine Reference → GuiService: `https://create.roblox.com/docs/reference/engine/classes/GuiService` — accesat 2026-09-08
- create.roblox.com/docs — Engine Reference → GuiService.GetInsetArea: `https://create.roblox.com/docs/reference/engine/classes/GuiService/GetInsetArea` — accesat 2026-09-08
- create.roblox.com/docs — Engine Reference → Enum ScreenInsets: `https://create.roblox.com/docs/reference/engine/enums/ScreenInsets` — accesat 2026-09-08
- create.roblox.com/docs — Engine Reference → Enum DisplaySize: `https://create.roblox.com/docs/reference/engine/enums/DisplaySize` — accesat 2026-09-08
- create.roblox.com/docs — Engine Reference → Enum ScreenOrientation: `https://create.roblox.com/docs/reference/engine/enums/ScreenOrientation` — accesat 2026-09-08
- create.roblox.com/docs — Engine Reference → UserInputService: `https://create.roblox.com/docs/reference/engine/classes/UserInputService` — accesat 2026-09-08
- create.roblox.com/docs — Engine Reference → GuiBase2d: `https://create.roblox.com/docs/reference/engine/classes/GuiBase2d` — accesat 2026-09-08
- create.roblox.com/docs — Engine Reference → ScreenGui: `https://create.roblox.com/docs/reference/engine/classes/ScreenGui` — accesat 2026-09-08
- create.roblox.com/docs — Engine Reference → UIScale: `https://create.roblox.com/docs/reference/engine/classes/UIScale` — accesat 2026-09-08
- create.roblox.com/docs — index llms.txt (folosit pentru a descoperi structura reală a documentației): `https://create.roblox.com/docs/llms.txt` — accesat 2026-09-08
- Roblox Corporation — Q2 2026 Earnings Press Release (PDF): `https://s27.q4cdn.com/984876518/files/doc_financials/2026/q2/Roblox-Q2-2026-Earnings-Press-Release.pdf` — datat 30 iulie 2026, accesat 2026-09-08
- **[secundar]** Wikipedia — „Roblox": `https://en.wikipedia.org/wiki/Roblox` — accesat 2026-09-08 (conține date istorice de lansare pe platforme și cifre DAU mai vechi, cu citări proprii)
- **[secundar]** backlinko.com — „Roblox Users & Statistics": `https://backlinko.com/roblox-users` — accesat 2026-09-08 (agregator, cifre pentru Q4 2025; split mobil/desktop/console și DAU/MAU citate ca provenind din surse oficiale, dar fără link direct verificabil în conținutul extras)

**Notă de metodologie:** bugetul sesiunii pentru unealta WebSearch era deja epuizat înainte de începerea acestei cercetări (folosit de alte task-uri paralele din aceeași sesiune). Cercetarea a fost efectuată prin navigare directă pe create.roblox.com/docs (structura descoperită via `llms.txt`, un index conceput pentru consum de către modele de limbaj) și prin fetch direct de pagini cunoscute. Încercările de căutare de rezervă prin Bing și DuckDuckGo au fost în mare parte blocate (CAPTCHA) sau au întors rezultate irelevante; devforum.roblox.com a blocat accesul automat cu HTTP 403 pe toate încercările; en.help.roblox.com a blocat accesul automat cu HTTP 403; web.archive.org nu e accesibil din acest mediu. Aceste limitări explică de ce unele întrebări din brief rămân la secțiunea „Întrebări deschise" în loc de răspuns cu cifră exactă.
