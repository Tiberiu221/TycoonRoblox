# Fezabilitatea unui joc 2D pur în ScreenGui (Roblox)

## Rezumat executiv

- **Fezabil, cu precedent real.** *Word Bomb* (OMG Studios, live din 16 decembrie 2018) rulează o interfață complet 2D, radială, în ScreenGui, cu peste 107.9 milioane de vizite și premiul „Best Education" la Roblox Innovation Awards 2024. Nu e Driftwood, dar dovedește că un joc GUI-only poate avea longevitate și scară pe Roblox. [roblox.fandom.com/wiki/OMG/Word_Bomb, fara data explicita pe pagina — sursa secundara wiki]
- **Comunitatea DevForum e împărțită.** Pe un thread din 2021-2024 despre fezabilitatea 2D pur, poziția dominantă e "fă 3D cu o cameră trucată, GUI e un chin" — dar un tutorial oficial-comunitar din 30 august 2025 (`How I make 2D (GUI-only) games, with Rojo`) descrie exact arhitectura pe care Driftwood o are în plan, funcțională în producție. [devforum.roblox.com/t/is-it-possible-to-make-a-fully-2d-game-on-roblox/1529211; devforum.roblox.com/t/how-i-make-2d-gui-only-games-with-rojo/3908147]
- **Lumea 3D poate fi eliminată complet.** `Players.CharacterAutoLoads = false` scoate avatarul din ecuație; nu e nevoie de `Camera.CameraType = Scriptable` sau de niciun truc de FOV dacă nu se randează deloc scena 3D — camera Roblox pur și simplu nu se vede dacă orice ScreenGui relevant e deasupra ei și `Workspace` rămâne gol.
- **Nu există culling nativ pentru GUI.** `GuiObject.VisibleOnScreen` a fost cerut ca feature în 2015 și **nu a fost livrat niciodată** — la data cercetării tot apare doar ca discuție de feature request, nu ca proprietate documentată în `create.roblox.com/docs/reference/engine/classes/GuiObject`. Culling-ul obiectelor din râu trebuie scris manual, pe coordonate logice, nu pe interogări ale motorului. [devforum.roblox.com/t/guiobjectvisibleonscreen/20164]
- **Interogarea `AbsoluteSize`/`AbsolutePosition` e costisitoare** când elementul e sub un `UIListLayout`/`UIGridLayout` — motorul reface layout-ul la fiecare citire. Containerul defilabil al râului (obiectul critic de performanță din Driftwood) nu trebuie pus sub layout automat. [devforum.roblox.com/t/querying-absolutesize-absoluteposition-on-a-gui-element-that-is-within-a-layout-is-extremely-costly/2427943]
- **Inset-ul barei de sus NU e o constantă.** Vechiul topbar avea 36px inset; discuții din octombrie-noiembrie 2024 raportează un topbar nou, mai mare (comunitatea vorbește de ~58px, neconfirmat oficial). Orice cod care poziționează UI relativ la topbar trebuie să citească dinamic `GuiService:GetGuiInset()`, niciodată să hardcodeze pixeli. [devforum.roblox.com/t/what-are-the-new-topbar-inset-dimensions/3237388, 31 oct 2024 — confirmare doar comunitară, nu Roblox staff]
- **Safe-area pentru notch e rezolvată de motor din 8 decembrie 2022** (full release), via `ScreenInsets`, `ClipToDeviceSafeArea` (default `true`) și `SafeAreaCompatibility`. E înainte de 2024 — de verificat în Studio dacă comportamentul mai e identic. [devforum.roblox.com/t/notched-screen-support-full-release/2074324]
- **Topbar-ul nu poate fi ascuns complet din motive de siguranță** — `StarterGui:SetCore("TopbarEnabled", false)` ascunde vizual bara, dar accesul la Report/Menu rămâne o cerință de platformă; există rapoarte de bug unde ascunderea nu elimină tot CoreGui-ul relevant pentru siguranță. NEVERIFICAT ca regulă scrisă explicit în Community Standards — de tratat ca risc de conformitate, nu ca fapt confirmat. [devforum.roblox.com/t/hiding-topbar-fails-to-hide-all-coregui-elements-account-overunder-13-yrs/33891]
- **80% din sesiunile Roblox erau pe mobil în Q4 2025**, cu referință de viewport ~390px lățime (iPhone) — arhitectura de UI trebuie gândită mobile-first, nu desktop-first. [rowatcher.com/news/mobile-vs-desktop-on-roblox-who-s-playing-what-in-2026 — sursa secundara, "Q4 2025"]

## Fapte verificate

- ScreenGui e containerul standard pentru elemente 2D pe ecran; se afișează doar dacă e sub `PlayerGui`, iar cele puse în `StarterGui` se clonează automat în `PlayerGui` la spawn. — create.roblox.com/docs/reference/engine/classes/ScreenGui — fara data explicita pe pagina (accesat 2026) — confidenta ridicata
- `ScreenGui.IgnoreGuiInset` (bool, default `false`, not replicated): dacă e `false`, `ScreenInsets` folosește `CoreUISafeInsets` (rămâne sub topbar); setat pe `true`, insetul trece la `DeviceSafeInsets`. — create.roblox.com/docs/reference/engine/classes/ScreenGui — confidenta ridicata
- `ScreenGui.ScreenInsets` (enum `Enum.ScreenInsets`): valori `CoreUISafeInsets` (default), `DeviceSafeInsets`, `TopbarSafeInsets`, `None`. `None` e recomandat doar pentru conținut non-interactiv (fundal), fiindcă poate fi acoperit de crestătura telefonului. — create.roblox.com/docs/ui/on-screen-containers — confidenta ridicata
- `ScreenGui.DisplayOrder` (int): controlează ordinea Z între mai multe `ScreenGui`; valoare mai mare = randat deasupra. — create.roblox.com/docs/reference/engine/classes/ScreenGui — confidenta ridicata
- `ScreenGui.ClipToDeviceSafeArea` (bool, default `true`): clipează descendenții ca să nu iasă din zona sigură a device-ului. — GitHub Roblox/creator-docs, ScreenGui.yaml — confidenta ridicata
- `ScreenGui.SafeAreaCompatibility` (enum, default `FullscreenExtension`): documentația recomandă folosirea `ScreenInsets` pentru proiecte noi în locul acestei proprietăți legacy. — GitHub Roblox/creator-docs, ScreenGui.yaml — confidenta ridicata
- `LayerCollector.ZIndexBehavior` (moștenit de `ScreenGui`; enum, default `Sibling`): cu `Sibling`, copiii se randează mereu deasupra părinților, iar `ZIndex` decide ordinea între frați; cu `Global`, `ZIndex` sortează toți descendenții din tot arborele, iar un copil cu `ZIndex` mai mic decât părintele se randează SUB părinte. — create.roblox.com/docs/reference/engine/enums/ZIndexBehavior — confidenta ridicata
- `LayerCollector.ResetOnSpawn` (moștenit de `ScreenGui`; bool, default `true`): dacă e `false` ȘI ScreenGui e copil direct al `StarterGui`, se clonează o singură dată per jucător și persistă la respawn; altfel (default sau imbricat în foldere) se distruge/reclonează la fiecare respawn al personajului. — GitHub Roblox/creator-docs, LayerCollector.yaml — confidenta ridicata
- `GuiObject.ClipsDescendants`: ascunde porțiunile descendenților care ies din dreptunghiul părintelui; clipping-ul pe forme rotite necesită `StarterGui.ClipsDescendantsSupportsRotation`; clipping pe colțuri rotunjite (`UICorner`) NU e suportat. — create.roblox.com/docs/reference/engine/classes/GuiObject#ClipsDescendants — confidenta ridicata
- `GuiObject.VisibleOnScreen` NU există ca proprietate livrată — a rămas doar cerere de feature din 29 noiembrie 2015, fără confirmare de livrare găsită în documentația curentă. — devforum.roblox.com/t/guiobjectvisibleonscreen/20164 — confidenta medie (absența e greu de dovedit 100%, dar nu apare în GuiObject.yaml din creator-docs)
- Formula `UDim2`: valoare finală în pixeli = `parentSize × Scale + Offset`, pe fiecare axă separat. Constructori: `UDim2.new(xScale, xOffset, yScale, yOffset)`, `UDim2.fromScale(xScale, yScale)`, `UDim2.fromOffset(xOffset, yOffset)`. — create.roblox.com/docs/reference/engine/datatypes/UDim2 — confidenta ridicata
- `UIAspectRatioConstraint.AspectRatio` (number) forțează raportul lățime:înălțime al unui `GuiObject` indiferent de `Size` (chiar dacă e în `Scale`); ex. `AspectRatio = 2` → lățimea e mereu dublul înălțimii. Are și `AspectType` (`Enum.AspectType`) și `DominantAxis` (`Enum.DominantAxis`). — create.roblox.com/docs/reference/engine/classes/UIAspectRatioConstraint — confidenta ridicata
- `UIScale.Scale` multiplică `AbsoluteSize` al părintelui cu un factor numeric; scalează proporțional și modificatorii vizuali (`UIStroke`, `UICorner`) ai părintelui. — create.roblox.com/docs/ui/size-modifiers — confidenta ridicata
- `TextLabel.TextScaled`: scalează fontul până la mărimea maximă (100) pe baza spațiului disponibil; documentația recomandă explicit să NU combini `AutomaticSize` cu `TextScaled` pe același obiect. — create.roblox.com/docs/reference/engine/classes/TextLabel#TextScaled — confidenta ridicata
- `RichText`: markup simplu pentru stilizare per-cuvânt/frază (bold, italic, underline, strikethrough, mărime, culoare) în cadrul unui singur string de text. — create.roblox.com/docs/reference/engine/classes/TextLabel — confidenta ridicata
- `Players.CharacterAutoLoads` (bool): dacă e `false`, personajul NU se încarcă automat la join/respawn; developerul trebuie să apeleze `Player:LoadCharacterAsync()` manual. Dacă e `false`, `ScreenGui`-urile din `StarterGui` NU se mai clonează automat decât dacă apelezi `LoadCharacterAsync()` — trebuie gestionat manual în arhitectura fără avatar. — create.roblox.com/docs/reference/engine/classes/Players; create.roblox.com/docs/ui/on-screen-containers — confidenta ridicata
- `Camera.CameraType = Enum.CameraType.Scriptable` dă control total asupra camerei (CFrame etc.), suprascriind scripturile default ale Roblox. `Camera.FieldOfView` acceptă 1–120 grade, default 70. — create.roblox.com/docs/reference/engine/classes/Camera; GitHub Roblox/creator-docs, workspace/camera.md — confidenta ridicata
- `StarterGui:SetCoreGuiEnabled(coreGuiType, enabled)` dezactivează elemente CoreGui specifice; valorile `CoreGuiType` găsite: `PlayerList`(0), `Health`(1), `Backpack`(2), `Chat`(3), `All`(4), `EmotesMenu`(5), `SelfView`(6), `Captures`(7), `AvatarSwitcher`(8), `ExperienceShop`(9). — create.roblox.com/docs/reference/engine/enums/CoreGuiType — confidenta ridicata
- Topbar-ul (butoanele Meniu/Report din bara de sus) NU se dezactivează prin `SetCoreGuiEnabled` — necesită `StarterGui:SetCore("TopbarEnabled", false)`, o metodă separată. — devforum.roblox.com/t/get-topbar-size-by-script/2733352 (comunitar) — confidenta medie
- `ReplicatedFirst:RemoveDefaultLoadingScreen()` elimină ecranul de încărcare implicit al Roblox, permițând afișarea unui `ScreenGui` custom construit dintr-un `LocalScript` plasat în `ReplicatedFirst` (rulează înaintea oricărui alt script client). — create.roblox.com/docs/reference/engine/classes/ReplicatedFirst; GitHub Roblox/creator-docs, players/loading-screens.md — confidenta ridicata
- Suport oficial pentru ecrane cu crestătură ("notch") a intrat în full release pe **8 decembrie 2022**, acoperind iPhone X/XR/14 Pro, Samsung Galaxy A51, Xiaomi Redmi Note 9 ca device-uri de test din Studio (5 modele emulate disponibile). — devforum.roblox.com/t/notched-screen-support-full-release/2074324, 8 dec 2022 — confidenta ridicata, dar sursa e din 2022, deci FLAG posibil-depasita
- Insetul topbar-ului vechi era **36px**; discuții comunitare din **31 octombrie 2024** raportează o schimbare la un topbar nou și mai mare (cifra de ~58px circulă în comunitate, dar nu e confirmată de staff Roblox în thread-ul găsit). Concluzie practică: nu hardcoda pixeli, citește `GuiService:GetGuiInset()` la runtime. — devforum.roblox.com/t/what-are-the-new-topbar-inset-dimensions/3237388 — confidenta medie (numărul nou), ridicata (faptul că s-a schimbat și nu trebuie hardcodat)
- `GuiService:GetGuiInset()` poate întoarce `0,0,0,0` la primul frame și valoarea corectă abia după un frame de așteptare — cod care citește insetul la `PlayerAdded`/primul frame trebuie să aștepte. — devforum.roblox.com/t/guiservicegetguiinset-returns-0000-at-first/3472295 — confidenta medie
- Interogarea `AbsoluteSize`/`AbsolutePosition` pe un element aflat sub un `UIListLayout`/`UIGridLayout` recalculează layout-ul de fiecare dată și e raportată ca „extrem de costisitoare" de dezvoltatori. — devforum.roblox.com/t/querying-absolutesize-absoluteposition-on-a-gui-element-that-is-within-a-layout-is-extremely-costly/2427943 — confidenta medie (raport comunitar, nu benchmark oficial)
- `Workspace.StreamingEnabled` e activ implicit pe locurile noi din Studio, dar se aplică DOAR instanțelor din `Workspace` — nu afectează `ScreenGui`/`ReplicatedFirst`/`ReplicatedStorage`. Pentru un joc GUI-only cu `Workspace` gol, streaming-ul nu aduce beneficii relevante. — create.roblox.com/docs/workspace/streaming — confidenta ridicata
- ~80% din sesiunile Roblox se întâmplă pe mobil (Q4 2025, în creștere de la ~74% anterior); desktop ~17%, console ~3%; doar ~24% dintre jucători folosesc EXCLUSIV mobil (restul comută între device-uri). Referință de viewport citată: ~390×844px (iPhone). — rowatcher.com/news/mobile-vs-desktop-on-roblox-who-s-playing-what-in-2026, "Q4 2025" — confidenta medie (sursa secundara/analitica, nu Roblox oficial)
- *Word Bomb* (creat 16 dec 2018): interfață GUI 2D circulară (avatare aranjate în cerc, bombă, tastare de cuvinte), 107.934.490 vizite raportate, câștigător „Best Education" la Roblox Innovation Awards 2024. — roblox.fandom.com/wiki/OMG/Word_Bomb — confidenta medie (wiki comunitar, nr. de vizite se schimbă continuu, fara data fixa a masuratorii)
- Tutorial comunitar „How I make 2D (GUI-only) games, with Rojo" (autor ethamcker, **30 august 2025**) descrie o arhitectură completă în producție: `CharacterAutoLoads=false`, cod organizat în `ReplicatedFirst`/`ReplicatedStorage`/`ServerScriptService`, `ScreenGui.IgnoreGuiInset=true`, `SetCoreGuiEnabled(All,false)`, `InputContext`/`InputAction` pentru input, `StyleSheet`/`StyleRule` pentru styling declarativ. — devforum.roblox.com/t/how-i-make-2d-gui-only-games-with-rojo/3908147 — confidenta medie (o singură sursă comunitară, nepublicată oficial de Roblox)

## Detalii

### 1. Precedente reale de jocuri 2D/GUI pe Roblox

Nu există o categorie oficială „joc 2D GUI-only" pe Roblox și nu am găsit un blockbuster recent construit exclusiv în ScreenGui cu cifre publice de retenție. Ce există confirmat:

- **Word Bomb** — GUI circular peste ce pare a fi o scenă minimă (nu am putut confirma dacă e 100% ScreenGui sau are o componentă 3D reziduală); relevant ca dovadă că un „joc de cameră unică, tot ecranul e UI" poate atinge scară de peste 100M vizite pe ani de zile. Sursă secundară (wiki), NEVERIFICAT dacă backend-ul e ScreenGui pur.
- **Paper2D** și **Upside Engine** — plugin-uri/framework-uri comunitare pentru 2D pe Roblox, dar orientate pe randare cu **părți 3D + cameră trucată** (Paper2D anunțat oct. 2024 pe DevForum), NU pe ScreenGui. Confirmă că varianta „3D deghizat în 2D" e alternativa cea mai populară în comunitate față de GUI pur — relevantă ca opțiune de fallback pentru Driftwood dacă performanța GUI devine o problemă, dar CLAUDE.md exclude explicit parts 3D.
- Threaduri „2D Game Made In 8 hours" (iun. 2025) și „Glyph [2D]" (mart. 2026) arată activitate continuă de hobby/indie pe subiect, dar fără cifre de retenție publicate.

**Concluzie:** fezabilitatea tehnică e confirmată de surse primare (documentație + un tutorial de producție din aug. 2025); dovada de succes comercial la scară mare, specific pentru arhitectură 100% ScreenGui, rămâne NEVERIFICAT — Word Bomb e cel mai apropiat caz găsit, dar cu ambiguitate despre implementare.

### 2. Proprietăți cheie ScreenGui — tabel de referință

| Proprietate | Tip | Default | Efect |
|---|---|---|---|
| `IgnoreGuiInset` | bool | `false` | `true` → ignoră insetul CoreUI, trece la `DeviceSafeInsets` |
| `ScreenInsets` | `Enum.ScreenInsets` | `CoreUISafeInsets` | `CoreUISafeInsets` / `DeviceSafeInsets` / `TopbarSafeInsets` / `None` |
| `ClipToDeviceSafeArea` | bool | `true` | clipează descendenții la zona sigură a device-ului |
| `SafeAreaCompatibility` | `Enum.SafeAreaCompatibility` | `FullscreenExtension` | legacy — docs recomandă `ScreenInsets` pentru cod nou |
| `DisplayOrder` | int | `0` (implicit) | Z-index între mai multe `ScreenGui` |
| `ZIndexBehavior` (din `LayerCollector`) | `Enum.ZIndexBehavior` | `Sibling` | `Sibling` = copii peste părinți, ordine pe frați; `Global` = ordine absolută pe `ZIndex` în tot arborele |
| `ResetOnSpawn` (din `LayerCollector`) | bool | `true` | `false` + copil direct al `StarterGui` = persistă la respawn |
| `Enabled` (din `LayerCollector`) | bool | `true` | arată/ascunde tot arborele dintr-un `ScreenGui` fără să-l distrugi |

Pentru Driftwood, cu `CharacterAutoLoads=false`, conceptul de „respawn" practic nu există — deci `ResetOnSpawn` devine mai puțin relevant, dar tot recomand `false` explicit pe fiecare `ScreenGui` rădăcină, ca plasă de siguranță împotriva unui `LoadCharacterAsync()` accidental.

### 3. Containerul defilabil al lumii (râul) și culling

Arhitectura tipică: un `Frame` foarte lat (lățimea = lungimea totală a "hărții" râului în pixeli logici), poziționat în `Offset` negativ pe X pentru a simula scroll-ul camerei:

```lua
-- WorldContainer: Frame, Size = UDim2.fromOffset(WORLD_WIDTH, WORLD_HEIGHT)
-- cameraOffsetX crește pe măsură ce râul "curge"
WorldContainer.Position = UDim2.fromOffset(-cameraOffsetX, 0)
```

Puncte critice găsite în cercetare:

1. **Nu pune obiectele râului sub `UIListLayout`/`UIGridLayout`.** Layout-urile automate recalculează la fiecare citire de `AbsoluteSize`/`AbsolutePosition`, ceea ce e documentat ca fiind costisitor pe elemente aflate sub un layout. Poziționează manual, cu `Position` calculat direct din modelul logic al jocului (o listă de obiecte cu `worldX` numeric), nu citind proprietăți GUI derivate.
2. **Nu există culling nativ.** `VisibleOnScreen` nu a fost livrat niciodată. Implementarea corectă: ține modelul lumii (poziții, tip obiect) într-un tabel Lua simplu, nu în starea GUI; la fiecare tick, calculează ce obiecte cad în fereastra vizibilă (`worldX` între `cameraOffsetX - marja` și `cameraOffsetX + viewportWidth + marja`) și doar pentru acelea creează/menține instanțe `ImageLabel`; distruge sau reciclează (pool) instanțele care ies din fereastră.
3. **`ClipsDescendants` pe containerul viewport-ului** (nu pe `WorldContainer` însuși) previne randarea vizuală a obiectelor din afara ecranului, dar NU oprește costul de calcul al acelor instanțe — clipping-ul e cosmetic, nu e optimizare de performanță. Culling-ul logic (crearea/distrugerea instanțelor) trebuie făcut separat, în cod.
4. Pentru un râu cu multe obiecte simultan, recomand un **pool de instanțe** reciclate (10-30 `ImageLabel`-uri pre-create, reatribuite pe măsură ce obiectele intră/ies din ecran), nu creare/distrugere per obiect — pattern standard de performanță UI, dedus din discuțiile despre lag la ScrollingFrame cu 200+ elemente. [devforum.roblox.com/t/scrollingframe-lag/1042397 — NEVERIFICAT ca prag exact, dar consistent cu mai multe rapoarte]

### 4. Rezoluție și aspect ratio

- **Nu există „rezoluție de referință" oficială** în documentația Roblox pentru UI — fiecare joc trebuie să-și definească propria bază. Pattern comunitar (modulul „Scaler", martie 2021, SECUNDAR): alegi o rezoluție de referință (ex. 720p înălțime), pui pe elementul rădăcină un `UIScale`, și calculezi `Scale = viewport.Y / referenceHeight` la fiecare schimbare de `Camera.ViewportSize`. Dimensiunile interne ale UI-ului se definesc atunci în **Offset** (pixeli ficși la rezoluția de referință), nu în Scale — `UIScale` se ocupă de proporționalitate.
- **`UIAspectRatioConstraint`** forțează raportul lățime:înălțime al containerului principal al jocului (util pentru banda orizontală a râului, care ar trebui să aibă un raport constant indiferent de telefon/desktop).
- **Safe area pe notch**: din 8 dec. 2022, motorul gestionează automat majoritatea cazurilor via `ScreenInsets`; pentru `Frame`-uri de fundal (râul, cerul) folosește `ScreenInsets = None` (poate ieși sub crestătură — e fundal, nu interactiv); pentru butoane/text folosește `CoreUISafeInsets` sau `DeviceSafeInsets`.
- Cu **~80% din sesiuni pe mobil (Q4 2025)** și viewport de referință ~390px lățime, Driftwood trebuie proiectat mobile-first: testează layout-ul îngust (portret, ~390×844) ca prioritate #1, nu ca afterthought pentru desktop 1920×1080.

### 5. Scale vs Offset — regulă practică

Formula motorului: `pixel final = parentSize × Scale + Offset` (pe fiecare axă). Pentru un joc-lume ca Driftwood:

- **Poziții logice ale obiectelor din lume (râu, plase, teren)** → **Offset**, calculate dintr-un sistem de coordonate logic al jocului (ex. 1 unitate = 1 pixel la rezoluția de referință), apoi scalate global printr-un `UIScale` pe containerul rădăcină.
- **Elemente de HUD/UI care trebuie să rămână la marginile ecranului** (bara de resurse, meniul) → **Scale**, ca să se ancoreze proporțional indiferent de rezoluție.
- Evită amestecul Scale+Offset pe același element pentru poziții "de joc" (obiecte din râu) — complică culling-ul și calculul de coliziune AABB descris în CLAUDE.md.

### 6. Text

- `TextScaled` scalează fontul automat până la maximum 100pt, pe baza spațiului `AbsoluteSize` disponibil — NU combina cu `AutomaticSize` pe același element (recomandare explicită din documentație).
- `RichText` permite markup inline (bold/italic/underline/strikethrough/culoare/mărime) — util pentru numele obiectelor rare din indexul de reparații (200+ obiecte, CLAUDE.md) fără să creezi `TextLabel`-uri separate pentru fiecare stil.

### 7. Layering: râu / obiecte / plase / UI

Recomandare bazată pe `ZIndexBehavior` (default `Sibling`) și `DisplayOrder`:

- **Un singur `ScreenGui` rădăcină per "scenă logică"** (ex. `GameScreen`, `LoadingScreen`, `MenuScreen`) — mai multe `ScreenGui`-uri simultane complică debugging-ul de `ZIndex`.
- În interiorul `GameScreen`, straturile (fundal râu → obiecte plutitoare → plase jucător → efecte particule → HUD) se ordonează prin **ordinea în ierarhie** (comportament `Sibling`: fratele randat ultimul e deasupra) + `ZIndex` explicit doar acolo unde ordinea de inserare nu ajunge (ex. obiecte din pool create/distruse dinamic, unde ordinea de inserție nu e garantată).
- **Nu comuta la `ZIndexBehavior = Global`** decât dacă ai un motiv clar (ex. tooltip-uri care trebuie mereu deasupra a tot, indiferent de subarbore) — `Global` cere disciplină: fiecare copil trebuie să aibă `ZIndex` ≥ părintele, altfel se randează sub el, o capcană ușor de lovit din greșeală.
- Pentru overlay-uri modale (dialog de reparație, magazin) — `ScreenGui` separat cu `DisplayOrder` mai mare, nu doar `ZIndex` mai mare în același `ScreenGui`.

### 8. Dezactivarea lumii 3D

```lua
-- ServerScriptService (la start)
local Players = game:GetService("Players")
Players.CharacterAutoLoads = false
```

Cu `CharacterAutoLoads = false`:
- Niciun avatar nu se încarcă, deci nicio fizică de personaj, nicio coliziune 3D, niciun cost de randare 3D per jucător.
- `ScreenGui`-urile din `StarterGui` NU se mai clonează automat în `PlayerGui` — trebuie clonate manual la `PlayerAdded` (documentat în `create.roblox.com/docs/ui/on-screen-containers`), sau apelat `Player:LoadCharacterAsync()` dacă vrei totuși clonarea automată standard fără avatar vizibil (NEVERIFICAT dacă `LoadCharacterAsync` fără avatar e posibil fără workaround — de testat în Studio).
- Nu e nevoie de `Camera.CameraType = Scriptable` sau de skybox/lighting ascunse dacă `Workspace` rămâne complet gol și niciun `ScreenGui` nu lasă zone transparente mari — camera 3D pur și simplu nu are ce reda. Dacă totuși rămâne un fundal 3D vizibil accidental (ex. skybox implicit), setează `Lighting.Skybox = nil`/înlocuiește cu un skybox negru solid ca plasă de siguranță, și opțional `Camera.CameraType = Scriptable` cu `CFrame` fix, ca să elimini orice control implicit al camerei.
- `StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.All, false)` ascunde health bar, backpack, playerlist, emotes etc. — dar NU ascunde topbar-ul (Meniu/Report); pentru asta separat `StarterGui:SetCore("TopbarEnabled", false)`, cu riscul de conformitate menționat în Riscuri.
- `GuiService.TouchControlsEnabled = false` dezactivează thumbstick-ul/butonul de jump virtual pe mobil (irelevante fără avatar).

### 9. Loading screen prin ReplicatedFirst

Pattern confirmat oficial:

```lua
-- LocalScript în ReplicatedFirst
local ReplicatedFirst = game:GetService("ReplicatedFirst")
local Players = game:GetService("Players")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local loadingScreen = script:WaitForChild("LoadingScreen") -- ScreenGui predefinit
loadingScreen.IgnoreGuiInset = true
loadingScreen.Parent = playerGui

ReplicatedFirst:RemoveDefaultLoadingScreen()

-- animatii cu TweenService in timp ce game.Loaded asteapta

if not game:IsLoaded() then
    game.Loaded:Wait()
end

loadingScreen:Destroy()
```

Recomandare din documentație: impune o durată minimă de afișare (`task.wait(N)`) ca ecranul de loading să nu clipească dacă asset-urile se încarcă instant — relevant fiindcă Driftwood are texturi 2D relativ ușoare, deci riscul e real.

## Recomandari concrete pentru Driftwood

1. **Un `ScreenGui` rădăcină per scenă logică** (`LoadingScreen`, `MenuScreen`, `GameScreen`, `ModalOverlay`), fiecare cu `IgnoreGuiInset = true` și `ResetOnSpawn = false` — control explicit al insetului, fără dependență de comportamentul implicit al topbar-ului (care s-a schimbat deja o dată, oct. 2024).
2. **Citește `GuiService:GetGuiInset()` dinamic**, niciodată hardcodat — Roblox a schimbat deja topbar-ul (36px → discuție de ~58px în 2024); Driftwood, fiind pur GUI, e mai expus la breaking changes de topbar decât un joc 3D unde topbar-ul acoperă doar HUD.
3. **`WorldContainer` (Frame al râului) poziționat prin `Offset`, calculat dintr-un model logic Lua**, NU printr-un `UIListLayout`/`UIGridLayout` — evită costul de recalculare documentat la interogări `AbsoluteSize`/`AbsolutePosition` sub layout automat, critic pentru un râu cu obiecte multe și mișcare continuă.
4. **Implementează culling manual + pool de instanțe** pentru obiectele din râu: ține poziția logică (`worldX`) într-un tabel separat de starea GUI; creează/reciclează `ImageLabel`-uri doar pentru obiectele din fereastra vizibilă + o marjă; NU te baza pe `VisibleOnScreen` (nu există) sau pe `ClipsDescendants` pentru optimizare de cost (doar cosmetic).
5. **Rezoluție de referință fixă + `UIScale` global**, calculat din `Camera.ViewportSize.Y / referenceHeight` la fiecare `GetPropertyChangedSignal("ViewportSize")`. Poziționează obiectele lumii în Offset la rezoluția de referință; lasă `UIScale` să facă proporționalitatea. Testează prioritar la ~390×844 (referință mobil dominant, Q4 2025).
6. **`UIAspectRatioConstraint` pe containerul principal al scenei de joc** ca să eviți distorsiuni pe ecrane ultra-late sau ultra-înalte (tablete, ultrawide desktop).
7. **`CharacterAutoLoads = false` din primul script server** + clonare manuală a `ScreenGui`-urilor la `PlayerAdded`, nu bazată pe comportamentul implicit legat de spawn — testează explicit în Studio că UI-ul apare corect fără avatar (nu e un flux "din oficiu" al motorului).
8. **`StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.All, false)`** la intrarea în joc, plus dezactivare explicită a `GuiService.TouchControlsEnabled` pe mobil. NU dezactiva `TopbarEnabled` fără să verifici explicit în Community Standards actuale că accesul la Report rămâne posibil — risc de conformitate, nu doar UX (vezi Riscuri).
9. **Loading screen în `ReplicatedFirst`** cu `RemoveDefaultLoadingScreen()` + durată minimă impusă (`task.wait`), pentru consistență vizuală indiferent cât de repede se încarcă asset-urile 2D.
10. **`ZIndexBehavior = Sibling` (default) + straturi pe ordine de inserție** pentru scena de joc; rezervă `DisplayOrder` mai mare doar pentru `ScreenGui`-uri modale separate (magazin, dialog reparație), nu pentru straturi din interiorul aceleiași scene.
11. **`ClipsDescendants` pe fereastra vizibilă a râului**, dar tratează-l ca optimizare cosmetică — nu înlocuiește pool-ul de instanțe de la punctul 4.
12. **Fundal (cer, apă) cu `ScreenInsets = None`; UI interactiv cu `CoreUISafeInsets`/`DeviceSafeInsets`** — separă explicit `ScreenGui`-urile sau folosește containere diferite în interior pentru fundal vs. interactiv.

## Riscuri si necunoscute

- **Instabilitate la actualizări Roblox.** Cel puțin un dezvoltator DevForum avertizează explicit: „ROBLOX could break it in next updates" referitor la abordarea GUI-pur (thread din 2021-2024, opinie comunitară, NEVERIFICAT ca risc oficial recunoscut de Roblox). Confirmat indirect de schimbarea reală a topbar-ului în 2024, care a stricat cod ce hardcoda 36px.
- **`TopbarEnabled = false` — risc de conformitate NEVERIFICAT explicit.** Nu am găsit un text oficial de Community Standards care să interzică ascunderea topbar-ului, dar există rapoarte de bug/comportament că ascunderea nu elimină tot ce ține de siguranță (Report), sugerând intenție de platformă ca acel acces să rămână disponibil. Trebuie verificat explicit înainte de lansare, posibil prin întrebare directă către Roblox Trust & Safety sau testare atentă în Studio + citirea Community Standards curente.
- **Costul real al `AbsoluteSize`/`AbsolutePosition` sub layout** e raportat comunitar, nu are benchmark oficial Roblox cu cifre exacte (ms per query) — de măsurat direct în Studio Profiler pentru Driftwood, nu de presupus.
- **Pragul de lag pentru multe elemente GUI simultane** (obiecte din râu) nu are un număr oficial Roblox — rapoartele comunitare vorbesc de „200+ elemente" ca prag problematic pentru `ScrollingFrame`, dar Driftwood nu folosește neapărat `ScrollingFrame` pentru râu — testare directă necesară.
- **`Word Bomb` ca precedent** — nu am putut confirma din surse primare dacă e 100% ScreenGui sau folosește și `Workspace`/`SurfaceGui`; tratează cifra de 107.9M vizite ca „un joc de tip GUI-heavy poate avea succes", nu ca dovadă tehnică directă a arhitecturii Driftwood.
- **Numărul exact al noului inset de topbar (~58px)** vine strict din discuții comunitare necofirmate de staff Roblox — poate diferi între platforme (mobil vs desktop) și se poate schimba din nou; motiv suplimentar să NU se hardcodeze.

## Intrebari deschise

1. Dezactivarea `TopbarEnabled` e permisă fără restricții pentru un joc lansat public, sau există o cerință de a păstra accesul la Report vizibil? — de clarificat citind Community Standards curente sau întrebând pe DevForum/Trust & Safety înainte de lansare.
2. Cu `CharacterAutoLoads = false`, clonarea automată a `ScreenGui`-urilor din `StarterGui` în `PlayerGui` se mai întâmplă fără avatar, sau trebuie clonare 100% manuală la `PlayerAdded`? — de testat direct în Studio, documentația nu confirmă explicit comportamentul exact în acest caz.
3. Care e pragul real (număr de `ImageLabel`-uri active simultan) la care performanța GUI a Driftwood scade sub un FPS acceptabil pe un telefon mediu (nu flagship)? — de măsurat cu Studio Profiler / Micro Profiler, nu există cifră oficială generică.
4. Costul exact al interogării `AbsoluteSize`/`AbsolutePosition` (ms) în cazul specific al containerului lumii Driftwood — de profilat direct, raportul comunitar nu dă cifre.
5. Care e valoarea curentă și corectă a insetului de topbar în 2026 pe fiecare platformă (mobil/desktop/consolă)? — de citit direct din `GuiService:GetGuiInset()` la runtime în Studio, nu din surse scrise.
6. `TextScaled` cu `RichText` — funcționează corect împreună în versiunea curentă de Roblox? Există un thread `RichText [TextScaled Support Added]` care sugerează că a fost o problemă rezolvată la un moment dat, dar data exactă a rezolvării nu a fost confirmată în cercetarea de față — NEVERIFICAT, de testat în Studio.

## Surse

- ScreenGui | Documentation - Roblox Creator Hub — https://create.roblox.com/docs/reference/engine/classes/ScreenGui — fara data explicita, accesat 2026
- On-screen UI containers | Documentation - Roblox Creator Hub — https://create.roblox.com/docs/ui/on-screen-containers — fara data explicita, accesat 2026
- ScreenGui.yaml, Roblox/creator-docs (GitHub) — https://github.com/Roblox/creator-docs/blob/main/content/en-us/reference/engine/classes/ScreenGui.yaml — accesat 2026
- LayerCollector.yaml, Roblox/creator-docs (GitHub) — https://github.com/Roblox/creator-docs/blob/main/content/en-us/reference/engine/classes/LayerCollector.yaml — accesat 2026
- GuiObject.yaml, Roblox/creator-docs (GitHub) — https://github.com/Roblox/creator-docs/blob/main/content/en-us/reference/engine/classes/GuiObject.yaml — accesat 2026
- GuiObject | Documentation - Roblox Creator Hub (ClipsDescendants) — https://create.roblox.com/docs/reference/engine/classes/GuiObject#ClipsDescendants — accesat 2026
- ZIndexBehavior | Documentation - Roblox Creator Hub — https://create.roblox.com/docs/reference/engine/enums/ZIndexBehavior — accesat 2026
- UIAspectRatioConstraint | Documentation - Roblox Creator Hub — https://create.roblox.com/docs/reference/engine/classes/UIAspectRatioConstraint — accesat 2026
- Size modifiers (UIScale, UIAspectRatioConstraint) | Documentation - Roblox Creator Hub — https://create.roblox.com/docs/ui/size-modifiers — accesat 2026
- UDim2 | Documentation - Roblox Creator Hub — https://create.roblox.com/docs/reference/engine/datatypes/UDim2 — accesat 2026
- position-and-size.md, Roblox/creator-docs (GitHub) — https://github.com/Roblox/creator-docs/blob/main/content/en-us/ui/position-and-size.md — accesat 2026
- TextLabel | Documentation - Roblox Creator Hub — https://create.roblox.com/docs/reference/engine/classes/TextLabel#TextScaled — accesat 2026
- Players | Documentation - Roblox Creator Hub — https://create.roblox.com/docs/reference/engine/classes/Players — accesat 2026
- Camera | Documentation - Roblox Creator Hub — https://create.roblox.com/docs/reference/engine/classes/Camera — accesat 2026
- camera.md, Roblox/creator-docs (GitHub) — https://github.com/Roblox/creator-docs/blob/main/content/en-us/workspace/camera.md — accesat 2026
- CoreGuiType | Documentation - Roblox Creator Hub — https://create.roblox.com/docs/reference/engine/enums/CoreGuiType — accesat 2026
- ReplicatedFirst | Documentation - Roblox Creator Hub — https://create.roblox.com/docs/reference/engine/classes/ReplicatedFirst — accesat 2026
- loading-screens.md, Roblox/creator-docs (GitHub) — https://github.com/Roblox/creator-docs/blob/main/content/en-us/players/loading-screens.md — accesat 2026
- Instance streaming | Documentation - Roblox Creator Hub — https://create.roblox.com/docs/workspace/streaming — accesat 2026
- Notched Screen Support - FULL RELEASE — DevForum — https://devforum.roblox.com/t/notched-screen-support-full-release/2074324 — 8 decembrie 2022 (PRE-2024, verifica in Studio)
- What are the new topbar inset dimensions? — DevForum — https://devforum.roblox.com/t/what-are-the-new-topbar-inset-dimensions/3237388 — 31 octombrie 2024
- GuiService:GetGuiInset() returns 0,0,0,0 at first — DevForum — https://devforum.roblox.com/t/guiservicegetguiinset-returns-0000-at-first/3472295 — accesat 2026, data postarii nespecificata
- GuiObject.VisibleOnScreen — DevForum (feature request) — https://devforum.roblox.com/t/guiobjectvisibleonscreen/20164 — creat 29 noiembrie 2015, inca deschis
- Querying AbsoluteSize/AbsolutePosition on a Gui element within a layout is EXTREMELY costly — DevForum — https://devforum.roblox.com/t/querying-absolutesize-absoluteposition-on-a-gui-element-that-is-within-a-layout-is-extremely-costly/2427943 — accesat 2026
- Scrollingframe Lag — DevForum — https://devforum.roblox.com/t/scrollingframe-lag/1042397 — accesat 2026
- How I make 2D (GUI-only) games, with Rojo — DevForum (Community Tutorial), autor ethamcker — https://devforum.roblox.com/t/how-i-make-2d-gui-only-games-with-rojo/3908147 — 30 august 2025
- Is it possible to make a fully 2D game on Roblox? — DevForum — https://devforum.roblox.com/t/is-it-possible-to-make-a-fully-2d-game-on-roblox/1529211 — postari din decembrie 2021 - ianuarie 2024
- Paper2D - A new roblox plugin and framework for 2D game development — DevForum — https://devforum.roblox.com/t/paper2d-a-new-roblox-plugin-and-framework-for-2d-game-development/3183674 — octombrie 2024
- Hiding topbar fails to hide all coregui elements — DevForum (Engine Bugs) — https://devforum.roblox.com/t/hiding-topbar-fails-to-hide-all-coregui-elements-account-overunder-13-yrs/33891 — accesat 2026
- Word Bomb | Roblox Wiki — Fandom (SECUNDAR) — https://roblox.fandom.com/wiki/OMG/Word_Bomb — fara data explicita, accesat 2026
- Mobile vs. Desktop on Roblox: Who's Playing What in 2026 — RoWatcher (SECUNDAR, analitic) — https://rowatcher.com/news/mobile-vs-desktop-on-roblox-who-s-playing-what-in-2026 — date "Q4 2025", articol 2026
- Scaler - Using UIScale to Scale Your UI — DevForum (Community Resource, SECUNDAR) — https://devforum.roblox.com/t/scaler-using-uiscale-to-scale-your-ui/1105672 — 15 martie 2021 (PRE-2024, verifica relevanta)
