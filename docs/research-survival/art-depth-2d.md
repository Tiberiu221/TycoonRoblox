# Cum arată bogat un joc 2D: lumină, straturi, atmosferă

## Rezumat executiv

- Bogăția vizuală într-un joc 2D nu vine din poligoane sau shadere — vine din **straturi** (parallax), **structură de valoare** (contrast lumină/întuneric, nu doar culoare), **paletă limitată coerentă**, **mișcare ambientală continuă** (nimic nu stă complet nemișcat) și **post-processing simplu** (vignette, tint). Niciuna din aceste cinci tehnici nu cere randare 3D sau shadere custom.
- Terraria nu are lumină "reală" (raycasting) — are propagare pe grid de tile-uri cu prag de tăiere: sub 1.85% intensitate, lumina nu se mai propagă. Torțele ajung ~42 de tile-uri prin aer dar doar ~7 prin blocuri solide, iar apa/mierea filtrează culori diferit (albastrul pătrunde mai departe prin apă, roșul prin miere). E o "minciună" ieftină computațional care arată convingător.
- Don't Starve nu are un motor de lumină sofisticat — are un sistem binar legat de proximitate la sursă: sanitate scade cu 5/minut lângă foc, 50/minut în întuneric complet, plus riscul de atac al monstrului Charlie în beznă totală. Atmosfera vine din stilul grafic "paper-cutout" (Tim Burton + Edward Gorey + Lovecraft), nu dintr-un sistem tehnic complex.
- Parallax e cea mai ieftină tehnică de adâncime din istoria jocurilor 2D: Moon Patrol (1982) a stabilit standardul cu 3 straturi la viteze diferite (cer static, vegetație la 2x, sol la 8x față de vegetație). Regula rămâne valabilă azi: straturile mai îndepărtate se mișcă mai încet.
- **Constrângere tehnică critică pentru Driftwood**: fiindcă jocul e 2D pur în `ScreenGui` cu `Workspace` gol (decizie D04 din CLAUDE.md), TOT ce ține de `Lighting` service — `Atmosphere`, `BlurEffect`, `Bloom`, `ColorCorrectionEffect`, `SunRaysEffect`, `DepthOfFieldEffect` — e inaccesibil. Confirmat oficial: `Atmosphere` e "exclusively a 3D-world effect" și nu se aplică pe `ScreenGui`. Orice atmosferă la Driftwood trebuie construită din `Frame`/`ImageLabel`/`UIGradient`/`UIStroke`/`UIShadow`/`CanvasGroup`.
- **`GuiObject` nu are blend modes native** (fără multiply/screen/overlay) — confirmat explicit în documentația oficială, nicio astfel de proprietate nu există. Tot tint-ul de zi/noapte la Driftwood va fi un simplu overlay alpha ("over" compositing), nu un multiply real ca în Unity/GameMaker/Godot — un compromis vizual de acceptat, nu de ignorat.
- `UIGradient` are 3 tipuri: Linear, Radial, Conical. **Radial e cheia pentru viniete și glow-uri de lumină** fără nicio imagine PNG suplimentară. `ParticleEmitter` NU poate fi parentat pe `GuiObject`/`ScreenGui` (confirmat oficial) — toate particulele ambientale (licurici, praf, fum) trebuie să fie un pool de `ImageLabel`-uri animate manual, exact cum a stabilit deja cercetarea internă din docs/research/11-juice-effects.md.
- Studiourile mici obțin atmosferă "bogată" din disciplină, nu din buget: Rain World a fost făcut de 2 oameni (Videocult, 2011-2017, ~6 ani) și e lăudat de IGN drept "among the best aesthetics in a 2D game" grație animației procedurale în timp real, nu artei statice desenate cadru cu cadru. Stardew Valley — un singur dezvoltator, 5 ani, Paint.NET.
- Eastward arată cât de departe poate merge un studio mic (Pixpil, Shanghai, crescut de la 3 la ~12 oameni) când adaugă un strat de lumină "3D" peste sprite-uri pixel art clasice, printr-un engine custom (Gii + MOAI open-source) — dovadă că "lumină dinamică peste pixel art" nu e exclusiv apanajul studiourilor AAA, dar cere motor custom, ceva ce Roblox nu permite pentru Driftwood.
- Lista prioritizată de tehnici pentru Driftwood (2D pur, ScreenGui, fără shadere), în ordinea cost/beneficiu: (1) paletă + structură de valoare, (2) parallax pe 3-4 straturi, (3) tint zi/noapte prin overlay, (4) vignette radial, (5) particule ambientale prin pool de ImageLabel, (6) UIStroke pentru contur/lizibilitate siluete, (7) shake/juice minimal — detaliat cu estimări de cost în secțiunea dedicată.

## Fapte verificate

- Terraria folosește propagare de lumină pe grid de tile-uri (`BlurLine()` în `LightMap.cs`) cu prag de tăiere: lumina sub 1.85% intensitate nu se mai propagă dincolo de tile-ul sursă. — sursa: https://terraria.wiki.gg/wiki/Lighting (accesat 10.09.2026) — încredere medie (wiki comunitar, dar citează cod sursă).
- Torțele în Terraria ajung ~42 de tile-uri prin aer, dar doar ~7 tile-uri prin blocuri solide; apa filtrează astfel încât albastrul pătrunde mai departe, mierea filtrează astfel încât roșul pătrunde mai departe. — sursa: https://terraria.wiki.gg/wiki/Lighting (accesat 10.09.2026) — încredere medie.
- Terraria are 3 moduri de randare a luminii: Colored (RGB complet), White/Colorless (doar procent de luminozitate 0-100%), Trippy (mod alternativ). — sursa: https://terraria.wiki.gg/wiki/Lighting (accesat 10.09.2026) — încredere medie.
- Update-ul Terraria 1.1 din 1 decembrie 2011 a introdus îmbunătățiri explicite ale sistemului de lumină și generării de lume. — sursa: https://en.wikipedia.org/wiki/Terraria (accesat 10.09.2026) — încredere medie.
- Stilul grafic Terraria e descris ca "reminiscent of the 16-bit sprites found on the Super Nintendo"; recenzenții au lăudat constant "retro-styled graphics" și tranziția lină zi/noapte. — sursa: https://en.wikipedia.org/wiki/Terraria (accesat 10.09.2026) — încredere medie.
- În Don't Starve: sanitatea scade cu 50/minut în întuneric complet (jucătorul nu poate interacționa cu nimic decât să pună foc de tabără), cu 5/minut lângă o sursă de lumină activă, și cu 5/minut în timpul amurgului (dusk); monstrul Charlie atacă doar în întuneric total. — sursa: https://dontstarve.wiki.gg/wiki/Darkness (accesat 10.09.2026) — încredere medie (wiki comunitar; pagina însăși notează că "lacks SW, HAM and DST specific info").
- Sub 15% sanitate în Don't Starve, "figments" imaginare devin corporale și pot ataca jucătorul; sanitatea poate fi refăcută prin somn, cules de flori sau haine stilate. — sursa: https://en.wikipedia.org/wiki/Don%27t_Starve (accesat 10.09.2026) — încredere medie.
- Stilul artistic Don't Starve e "paper-cutout", influențat explicit de Tim Burton, Edward Gorey și H.P. Lovecraft; recenzenții au numit atmosfera "captivating" și au notat cum obiecte banale devin amenințătoare prin stil. — sursa: https://en.wikipedia.org/wiki/Don%27t_Starve (accesat 10.09.2026) — încredere medie.
- Parallax scrolling a intrat în jocuri video prin Jump Bug (1981, formă limitată) și a fost popularizat de Moon Patrol (1982), primul cu 3 straturi complete la viteze diferite, simulând distanța; exemplul tehnic citat: sol la 8x viteza vegetației, vegetație la 2x viteza norilor. — sursa: https://en.wikipedia.org/wiki/Parallax_scrolling (accesat 10.09.2026) — încredere medie-ridicată (Wikipedia, dar istorie tehnică bine documentată/consensuală).
- Există 4 metode tehnice istorice de parallax: layer method (straturi hardware separate), sprite method (sprite-uri individuale ca pseudo-straturi, ex. Star Force pe NES), repeating pattern/animation method (animarea bitmap-urilor de tile), raster method (schimbarea poziției de scroll pe fiecare linie de scanare, în timpul intervalului de blanking orizontal). — sursa: https://en.wikipedia.org/wiki/Parallax_scrolling (accesat 10.09.2026) — încredere medie.
- Hollow Knight: arta a fost desenată de mână de Ari Gibson și scanată direct în Unity; echipa a ales deliberat un stil "simplu" ca să nu prelungească excesiv dezvoltarea; complexitatea lumii Hallownest a fost inspirată din Metroid, cu indicatoare minime pentru a lăsa jucătorul să se orienteze singur. Echipa centrală: 5 oameni. — sursa: https://en.wikipedia.org/wiki/Hollow_Knight (accesat 10.09.2026) — încredere medie.
- Dead Cells folosește pixel art ca element vizual central; jocul are ~50 de arme, fiecare cu animații/comportament unic, dezvoltate printr-un proces iterativ pe gameplay, grafică și artă simultan (Motion Twin). — sursa: https://en.wikipedia.org/wiki/Dead_Cells (accesat 10.09.2026) — încredere medie.
- Rain World folosește animație procedurală în timp real (nu cadre desenate manual) pentru mișcarea personajelor și creaturilor; sistemul produce neintenționat animații expresive (prădători par "frustrați" când nu reușesc să vâneze). Dezvoltat de un studio de 2 oameni (Videocult: Joar Jakobsson, James Therrien), început în 2011, migrat pe Unity în 2015, lansat martie 2017 (~6 ani de dezvoltare). IGN a numit animațiile "among the best aesthetics in a 2D game". — sursa: https://en.wikipedia.org/wiki/Rain_World (accesat 10.09.2026) — încredere medie.
- Stardew Valley a fost dezvoltat solo de Eric "ConcernedApe" Barone timp de 5 ani, folosind Paint.NET pentru pixel art și Reason Studios pentru audio; programat inițial în C#/XNA, migrat la MonoGame în 2021. Recenzenții au descris efectele de lumină drept "magical" și atmosfera drept "picturesque". — sursa: https://en.wikipedia.org/wiki/Stardew_Valley (accesat 10.09.2026) — încredere medie.
- Eastward combină pixel art cu efecte de lumină "3D" printr-un motor custom numit Gii, construit peste open-source-ul MOAI, ales explicit ca să adauge iluminare dimensională și post-processing fără să încarce excesiv hardware-ul. Dezvoltat de Pixpil (Shanghai), studio crescut de la 3 fondatori la ~12 angajați full-time, început în 2015, publicat de Chucklefish. — sursa: https://en.wikipedia.org/wiki/Eastward_(video_game) (accesat 10.09.2026) — încredere medie.
- Blasphemous folosește pixel art gothic influențat direct de iconografia religioasă din Sevilla (Săptămâna Mare/Holy Week), cu referințe explicite la pictori precum Goya, Murillo, Velázquez (director creativ Enrique Cabeza); dezvoltat de The Game Kitchen (Spania) pe Unity. — sursa: https://en.wikipedia.org/wiki/Blasphemous_(video_game) (accesat 10.09.2026) — încredere medie.
- Core Keeper folosește pixel art top-down într-un mediu subteran generat procedural; recenzenții au remarcat explicit contrastul "cozy vs. creepy" (PC Gamer) și comparația cu Dungeon Keeper pentru tonul întunecat (NME). Dezvoltat de Pugstorm. — sursa: https://en.wikipedia.org/wiki/Core_Keeper (accesat 10.09.2026) — încredere medie.
- Graveyard Keeper e dezvoltat de Lazy Bear Games pe Unity, inspirat explicit de Stardew Valley/Harvest Moon; sursa consultată nu conține detalii tehnice despre stilul artistic specific (semi-realist/hatching) — de tratat ca NEVERIFICAT din sursă primară. — sursa: https://en.wikipedia.org/wiki/Graveyard_Keeper (accesat 10.09.2026) — încredere scăzută pe partea de artă.
- `UIGradient` suportă `Type` = Linear/Radial/Conical, `TileMode` = Clamp/Repeat/Mirror, plus `Color` (ColorSequence), `Transparency` (NumberSequence), `Rotation` (number), `Offset` (Vector2), `Scale` (number), `Enabled` (bool). — sursa: https://create.roblox.com/docs/reference/engine/classes/UIGradient + https://create.roblox.com/docs/ui/appearance-modifiers + https://create.roblox.com/docs/reference/engine/enums/GradientType (accesat 10.09.2026) — încredere ridicată.
- `CanvasGroup` expune `GroupColor3` și `GroupTransparency` pentru compositing pe întreg subarborele de UI dintr-o singură proprietate; nu are documentat costul exact de randare (folosește un buffer separat de compositing). — sursa: https://create.roblox.com/docs/reference/engine/classes/CanvasGroup (accesat 10.09.2026) — încredere ridicată pe API, medie pe cost de performanță (nedocumentat explicit).
- `UIStroke` are 10 proprietăți configurabile: `ApplyStrokeMode`, `BorderOffset`, `BorderStrokePosition`, `Color`, `Enabled`, `LineJoinMode`, `StrokeSizingMode`, `Thickness`, `Transparency`, `ZIndex`; suportă și `UIGradient` copil pentru contur cu gradient. — sursa: https://create.roblox.com/docs/reference/engine/classes/UIStroke + https://create.roblox.com/docs/ui/appearance-modifiers (accesat 10.09.2026) — încredere ridicată.
- `UIShadow` are `BlurRadius` (UDim, controlează moliciunea umbrei), `Color`, `Offset` (UDim2), `Spread` (UDim2), `Transparency`, `Enabled`, `ZIndex`; respectă rotația și colțurile rotunjite ale părintelui. — sursa: https://create.roblox.com/docs/reference/engine/classes/UIShadow + https://create.roblox.com/docs/ui/appearance-modifiers (accesat 10.09.2026) — încredere ridicată.
- `ParticleEmitter` se poate parenta DOAR pe `BasePart` sau `Attachment` în lumea 3D, niciodată pe `GuiObject`/`ScreenGui`; rata maximă documentată e 400 particule/secundă (100 pe mobil), lifetime maxim 20 secunde, suportă animație flipbook de la 2×2 la 8×8 cadre. — sursa: https://create.roblox.com/docs/effects/particle-emitters (accesat 10.09.2026) — încredere ridicată.
- `Atmosphere` (obiect din `Lighting` service) e descris oficial ca efect exclusiv pentru lumea 3D — controlează `Density`, `Offset`, `Haze`, `Color`, `Glare`, `Decay` pentru fog/haze/culoare de mediu — și NU se aplică pe `ScreenGui`. — sursa: https://create.roblox.com/docs/environment/atmosphere (accesat 10.09.2026) — încredere ridicată.
- `GuiObject` NU are nicio proprietate de blend mode/compositing (fără multiply, screen, overlay) — confirmat prin absența completă din referința oficială a clasei; singurele controale de culoare sunt `BackgroundColor3`/`BorderColor3` + transparență + `ZIndex`. — sursa: https://create.roblox.com/docs/reference/engine/classes/GuiObject (accesat 10.09.2026) — încredere ridicată.
- `ImageLabel.ScaleType` suportă `Stretch`, `Tile` (cu `TileSize`), `Slice` (9-slice scaling via `SliceCenter` + `SliceScale`), plus `ImageColor3`, `ImageTransparency`, `ResampleMode`; `ImageRectOffset`/`ImageRectSize` permit afișarea unei regiuni specifice dintr-un sprite atlas. — sursa: https://create.roblox.com/docs/reference/engine/classes/ImageLabel (accesat 10.09.2026) — încredere ridicată.
- Documentația oficială de animație UI (`ui/animation`) listează explicit ca proprietăți tween-abile: `Position`, `Size`, `Rotation`, variantele de transparență (`BackgroundTransparency`/`ImageTransparency`/`TextTransparency`/`TextStrokeTransparency`), variantele de culoare (`BackgroundColor3`/`ImageColor3`/`TextColor3`/`BorderColor3`/`TextStrokeColor3`), proprietățile `UIStroke` și `CanvasGroup.GroupTransparency`/`GroupColor3` — dar NU menționează nicio proprietate `UIGradient` (Rotation/Offset/Color) ca fiind confirmat tween-abilă în acest document. — sursa: https://create.roblox.com/docs/ui/animation (accesat 10.09.2026) — încredere medie (absența din acest document nu e dovadă completă de imposibilitate tehnică, doar lipsă de confirmare oficială explicită).
- Baza de date Lospec catalogează peste 4.463 de palete limitate publicate de comunitate, cu exemple de dimensiuni variate: 4 culori (CYBER 4, GONGLEGB), 5 culori (Albuquerque Blue), 10 (dino destruction!), 12 (Spilt Milk at Sunset), 16 (MaxiM RBow), 22 (MrD's Basic 22), 24 (Herbarium24), 64 (Jehkoba64) — dovadă a convenției larg răspândite de paletă limitată (tipic sub 32-64 culori) în pixel art. — sursa: https://lospec.com/palette-list (accesat 10.09.2026) — încredere ridicată pe cifre, medie pe relevanța eșantionului (nu am putut confirma exact paletele "clasice" precum PICO-8/DawnBringer prin fetch direct — vezi Riscuri).
- Cercetarea internă deja existentă în proiect confirmă: `ParticleEmitter` nu poate fi parentat pe `GuiObject` (deci particulele Driftwood trebuie să fie un pool de `ImageLabel`), și că nu există `Workspace.TimeScale` nativ pentru efecte de tip slow-motion — relevant pentru orice efect de "moment de reveal" atmosferic. — sursa internă: docs/research/11-juice-effects.md (fișier din proiect, nu URL extern) — încredere ridicată (verificat anterior cu documentația oficială Roblox).

## Detalii

### 1. Cum "trișează" jocurile 2D lumina dinamică

Niciun joc 2D popular nu face raycasting real de lumină per-pixel în timp real pe un CPU/GPU obișnuit — toate folosesc aproximări ieftine care arată convingător:

- **Terraria** — propagare de lumină pe grid de tile-uri, nu raycasting. Fiecare tile sursă de lumină "împinge" o valoare de intensitate către vecini, care scade (`BlurLine()`), până sub un prag de 1.85% unde se oprește complet — exact ca un flood-fill cu decay, nu ca o simulare fizică de fotoni. Diferența dintre "42 tile-uri prin aer" și "7 tile-uri prin blocuri solide" arată că materialul afectează decay-ul, nu doar distanța. Costul computațional e predictibil (grid finit, prag de tăiere), ceea ce contează enorm pentru un joc care trebuie să ruleze pe mii de tile-uri simultan.
- **Don't Starve** — nu propagă lumină deloc în sensul Terraria. E un sistem de zone binare: ești "în raza" unei surse de lumină sau nu ești, cu o rată de decădere a sanității diferită pentru fiecare stare (5/min vs. 50/min, verificat mai sus). Bogăția percepută vine din **stil**, nu din tehnică — silueta de hârtie decupată + paleta întunecată + muzica fac diferența, nu un motor sofisticat.
- **Core Keeper** — folosește tot un model de "zonă întunecată vs. luminată" pe hărți subterane generate procedural, cu accent pe contrastul emoțional cozy/creepy (confirmat de recenzii), nu pe realism fizic al luminii.
- **Graveyard Keeper** — stil pixel art detaliat, cunoscut (din cunoștințe generale de design, NEVERIFICAT din sursă primară în această cercetare) pentru un aspect semi-pictural cu hatching/cross-hatching aplicat peste sprite-uri clasice, mai degrabă decât un sistem de lumină dinamică — flag explicit: nu am putut verifica tehnica exactă din surse primare accesibile.

**Concluzia pentru designer**: "lumină dinamică" într-un joc 2D de succes aproape niciodată nu înseamnă simulare fizică — înseamnă o regulă simplă (rază + decay + prag) aplicată consistent, plus un strat de artă/stil care face diferența vizibilă. Pentru Driftwood, fără `Lighting` service 3D, echivalentul e o regulă și mai simplă: un `UIGradient` de tip Radial pe un `ImageLabel` circular, cu `ColorSequence` de la galben-cald (centru) la negru-transparent (margine), scalat/poziționat pe fiecare sursă de lumină din scenă (felinar, foc de tabără, fereastră luminată).

### 2. Parallax layering — tehnica de adâncime cea mai ieftină din istoria jocurilor 2D

Patru metode istorice identificate (vezi Fapte verificate), dintre care **layer method** e singura relevantă azi pentru un motor modern ca Roblox: straturi independente, fiecare cu propria viteză de scroll proporțională cu "distanța" percepută. Regula Moon Patrol (sol 8x, vegetație 2x, cer 1x/static) se traduce direct: cu cât un strat e "mai aproape de cameră" în design, cu atât se mișcă mai repede față de fundal.

Pentru un joc top-down/side-view 2D pur în `ScreenGui`, parallax nu înseamnă camere 3D — înseamnă `Frame`-uri suprapuse (`ZIndex` crescător de la fundal la prim-plan), fiecare cu propriul offset de poziție actualizat la o fracțiune din viteza de scroll a camerei logice a jocului. Cercetarea internă (docs/research/06-screengui-2d-feasibility.md) a stabilit deja arhitectura de bază pentru un `WorldContainer` care se deplasează pe `Position` — parallax e aceeași idee, multiplicată pe 3-4 straturi cu factori de viteză diferiți (ex. 0.2x pentru cer/nori îndepărtați, 0.5x pentru maluri/copaci de fundal, 1.0x pentru stratul de joc propriu-zis, opțional 1.3x pentru un strat de prim-plan care trece PESTE jucător — frunze, ceață joasă — pentru senzația de adâncime "în fața camerei", nu doar în spate).

### 3. Ambient occlusion și contact shadows în pixel art

Nu am reușit să extrag conținutul complet al tutorialelor dedicate (Lospec "Light and Shadow"/"Pixel Logic" au fost accesibile doar ca index, nu conținut complet — vezi Riscuri). Ce rămâne cunoștință general acceptată în comunitatea de pixel art, dar NEVERIFICAT printr-o sursă primară completă în această cercetare:

- **Contact shadow** = o linie de 1-2 pixeli, ușor mai închisă decât umbra normală a obiectului, exact la punctul unde un obiect atinge suprafața de sub el (personaj/copac/piatră pe iarbă). Fără ea, obiectele par să "plutească" deasupra fundalului chiar dacă poziția e corectă.
- **Ambient occlusion** în pixel art se simulează static (pictat manual în sprite, nu calculat), de obicei ca o bandă îngustă întunecată în colțurile/crăpăturile unde două suprafețe se întâlnesc — nu e un pass de randare separat ca în 3D, e parte din desenul original.
- **Dithering** (alternarea a doi pixeli de culori adiacente pentru a simula o a treia valoare intermediară) e tehnica standard pentru a extinde efectiv o paletă mică fără să adaugi culori noi — relevantă direct pentru un joc cu paletă limitată gen Driftwood.

Recomandare pentru Driftwood: fiindcă totul e `ImageLabel` (sprite-uri desenate static, nu randate procedural), AO și contact shadows se rezolvă **în artă**, nu în cod — cerință directă pentru artistul/generatorul de sprite-uri: fiecare obiect din lume trebuie să vină cu o umbră de contact deja pictată în partea de jos a sprite-ului, nu adăugată separat prin cod (mai ieftin de randat, mai consistent vizual).

### 4. Paletă de culori și structură de valoare

Convenția dominantă în pixel art e paleta limitată (confirmat de eșantionul Lospec: majoritatea palete populare catalogate au între 4 și 64 de culori, nu sute). Beneficiul e coeziune vizuală automată — cu mai puține culori posibile, e aproape imposibil ca două elemente alăturate să "bată" din ochi din cauza unei nuanțe greșit alese, fiindcă toate culorile provin din același set testat.

**Structura de valoare** (value structure) e distinctă de paletă: chiar cu o paletă bogată, un joc arată "plat" dacă toate elementele au aceeași luminozitate medie. Regula generală de design (cunoștință consacrată, nu dintr-o sursă unică citabilă): elementele importante pentru gameplay (obiecte interactive, jucător, inamici) trebuie să aibă un contrast de valoare clar față de fundal — fundalul își poate permite o gamă de valori restrânsă (de obicei valori medii, nici prea deschis nici prea întunecat), în timp ce prim-planul interactiv "sare în ochi" prin valori extreme (foarte deschis sau contur foarte închis).

Pentru Driftwood: recomand definirea explicită a **2 palete separate** — o paletă de "fundal/mediu" (valori medii, saturație redusă) și o paletă de "obiecte interactive" (contrast mare, saturație mai mare) — plus o regulă fixă (ex. UIStroke negru de 1-2px pe orice obiect ce poate fi interacționat) care garantează lizibilitate indiferent de ce se întâmplă în fundal.

### 5. Day/night și weather tinting

Fără `ColorCorrectionEffect`/`Atmosphere` (confirmat inaccesibile pentru `ScreenGui`), tint-ul de zi/noapte la Driftwood se face exclusiv prin overlay: un `Frame` full-screen (sau `ImageLabel` cu `UIGradient`) cu `BackgroundColor3` = culoarea momentului (portocaliu cald la apus, albastru-violet la noapte) și `BackgroundTransparency` variabilă, poziționat deasupra scenei dar sub HUD.

**Limitarea reală**: fiindcă `GuiObject` nu are blend mode multiply (confirmat), acest overlay se comportă ca un strat semi-transparent normal ("over" compositing) — NU întunecă proporțional zonele deja întunecate ca un multiply real. Rezultatul practic: un overlay albastru la 30% transparency va face un obiect alb să pară albastru-deschis, dar un obiect deja negru rămâne aproape negru (nu se "adâncește" cum ar face cu multiply). Pentru un rezultat mai convingător, două tehnici de compensare (ambele necesită testare în Studio, NEVERIFICAT ca rezultat exact):
1. Overlay dublu — un strat de culoare + un al doilea strat separat doar pentru a întuneca (negru la transparency variabil), aplicate simultan.
2. Culori pre-calculate per obiect — sprite-urile cheie (apă, clădiri) au variante de culoare pre-desenate pentru zi/amurg/noapte, swapate direct (mai scump în asset-uri, dar vizual corect).

### 6. Particule și efecte de ecran

Confirmat: `ParticleEmitter` nu funcționează în `ScreenGui`. Singura cale la Driftwood e un pool de `ImageLabel` reciclate (deja documentat arhitectural în docs/research/11-juice-effects.md). Limitele native ale `ParticleEmitter` (400/s desktop, 100/s mobil, lifetime max 20s) NU se aplică direct unui pool custom de `ImageLabel` — dar sunt un reper util de ordin de mărime: dacă Roblox însuși limitează particulele native la ~100/s pe mobil pentru performanță, un pool manual de `ImageLabel`-uri (mai scump per-instanță decât particulele native GPU) ar trebui să fie semnificativ mai conservator pe mobil (ordinul zecilor, nu sutelor, simultan) — recomandare de prudență, nu cifră testată.

### 7. Mediu animat (iarbă, apă, fum, licurici)

Fără shadere de vertex-displacement (gen "grass sway" din motoare 3D), mișcarea ambientală la Driftwood se limitează la ce poate anima `TweenService` sau `RunService:BindToRenderStep` pe proprietăți 2D:

- **Apă** — deja rezolvat arhitectural (cercetare internă): `ScaleType.Tile` + animarea `Offset`-ului, NU sprite sheet cu `ImageRectOffset` (aia e pentru animație cadru-cu-cadru, nu scroll continuu).
- **Iarbă/frunze legănate** — un `UIGradient` sau o mică rotație oscilantă (`Rotation` tween în buclă, ±3-5 grade, easing Sine) pe sprite-uri individuale de tufe/copaci; ieftin, dar dacă TOATE elementele oscilează sincron arată artificial — recomand offset de fază aleatoriu per instanță (fiecare tufă începe animația la un timp diferit).
- **Fum** — `ImageLabel` mic, transparență crescândă + poziție crescândă pe Y (plutire în sus) + scară crescândă, într-un ciclu scurt repetat, din pool.
- **Licurici/praf în aer** — exact tehnica de particule din secțiunea 6, cu `Rate` mic (ordinul unităților/secundă) și mișcare lentă, aleatorie (nu liniară) pentru senzația organică.

**Notă critică din Fapte verificate**: proprietățile `UIGradient` NU sunt confirmate explicit tween-abile în documentația oficială de animație. Pentru orice efect care depinde de animarea unui `UIGradient` (shimmer pe apă, rotație de lumină), varianta sigură e actualizare manuală prin `RunService:BindToRenderStep` (deja pattern recomandat pentru shake, conform cercetării interne), nu `TweenService:Create` direct pe `UIGradient` — de testat explicit în Studio înainte de a construi sisteme pe această presupunere.

### 8. Viniete și post-processing "sărac, dar eficient"

Vignette (întunecarea marginilor ecranului pentru a direcționa atenția spre centru) e trivial de construit cu `UIGradient` de tip **Radial**: un `ImageLabel` full-screen, `BackgroundTransparency = 1`, cu un `UIGradient` Radial ce merge de la transparent (centru) la negru opac (margine), plasat deasupra întregii scene cu `ZIndex` mare, dar sub HUD critic. Costul e un singur `Frame`+`UIGradient` static (sau animat pentru puls la moment tensionat) — mult mai ieftin decât orice echivalent 3D.

Alte efecte de "post-processing sărac" realizabile fără shadere:
- **Chromatic-aberration fals** — 2-3 copii ale aceluiași `ImageLabel` cu `ImageColor3` roșu/verde/albastru, offsetate cu 1-2px, la un eveniment de impact scurt (nu permanent, prea scump vizual dacă rulează continuu).
- **Flash de ecran** — `Frame` alb full-screen, `BackgroundTransparency` de la 0 la 1 într-un tween scurt (0.1-0.2s), pentru impact/reveal rar.
- **Blur real NU există** pentru `GuiObject` (confirmat: `BlurEffect` e `PostEffect` din `Lighting`, exclusiv 3D) — orice "blur" pe UI la Driftwood trebuie simulat prin transparență + scădere de contrast, nu blur real de pixeli.

### 9. Siluete de personaj și lizibilitate

Testul clasic de design (Disney, consacrat, nu dintr-o sursă unică citabilă în această cercetare): un personaj bine desenat trebuie să fie identificabil doar din silueta lui neagră, fără detalii interne. Pentru Driftwood, cu `UIStroke` disponibil nativ (confirmat: 10 proprietăți, inclusiv `Color`/`Thickness`/`LineJoinMode`), fiecare `ImageLabel` de obiect interactiv important (obiect de prins din râu, plasă, NPC) ar trebui să aibă un contur consistent (ex. negru, 1-2px) — separă vizual obiectul de fundal indiferent de ce culoare are fundalul în acel moment (zi/noapte/vreme).

### 10. UI diegetică

Concept de design (nu dintr-o sursă fetch-uită direct în această cercetare, dar consacrat prin exemple ca Dead Space): elementele de UI "trăiesc" în lumea jocului în loc să plutească deasupra ei ca overlay abstract — bara de viață pe corpul personajului, contorul afișat pe unealtă, etc. Pentru Driftwood, relevanța practică e limitată de faptul că totul e deja UI (`ScreenGui`) — "diegetic" aici înseamnă mai degrabă integrarea vizuală a HUD-ului CU stilul lumii (aceeași paletă, aceleași contururi, aceeași "textură de hârtie" dacă asta e direcția artistică), nu separarea tehnică 3D vs. UI care nu există la Driftwood oricum.

### 11. Tabel comparativ — studii de caz

| Joc | Tehnică principală de atmosferă | Echipă/timp dezvoltare | Confirmat prin |
|---|---|---|---|
| Terraria | Propagare de lumină pe grid + prag de tăiere (1.85%) | N/A (Re-Logic) | terraria.wiki.gg/wiki/Lighting |
| Don't Starve | Stil "paper-cutout" + sistem binar de sanitate/lumină | Klei Entertainment | dontstarve.wiki.gg, Wikipedia |
| Core Keeper | Contrast "cozy vs. creepy", zone întunecate proceduale | Pugstorm | Wikipedia (Core Keeper) |
| Hollow Knight | Artă desenată de mână, scanată direct în Unity | 5 oameni (Team Cherry) | Wikipedia (Hollow Knight) |
| Dead Cells | Pixel art + iterație artă-gameplay pe ~50 arme | Motion Twin | Wikipedia (Dead Cells) |
| Rain World | Animație procedurală în timp real | 2 oameni, ~6 ani (Videocult) | Wikipedia (Rain World) |
| Stardew Valley | Pixel art solo, lumină "magică" lăudată de critici | 1 om, 5 ani (ConcernedApe) | Wikipedia (Stardew Valley) |
| Eastward | Pixel art + lumină "3D" prin engine custom (Gii+MOAI) | 3→12 oameni (Pixpil) | Wikipedia (Eastward) |
| Blasphemous | Pixel art gothic, referințe la pictură religioasă spaniolă | The Game Kitchen | Wikipedia (Blasphemous) |
| Graveyard Keeper | NEVERIFICAT (sursă primară incompletă) | Lazy Bear Games | Wikipedia (thin pe artă) |

### 12. Tabel — ce e posibil în Roblox GUI pur (fără shadere)

| Tehnică | Posibil în `ScreenGui` pur? | Cum |
|---|---|---|
| Vignette | DA | `UIGradient` Radial pe `ImageLabel` full-screen |
| Glow radial (lumină punctuală) | DA | `UIGradient` Radial, culoare caldă→transparent |
| Parallax multi-strat | DA | `Frame`-uri suprapuse, offset de poziție proporțional |
| Contur/silhouette | DA | `UIStroke` |
| Umbră moale (drop shadow) | DA | `UIShadow` (`BlurRadius`, `Spread`) |
| Fade/compositing de subarbore întreg | DA | `CanvasGroup.GroupTransparency`/`GroupColor3` |
| Apă animată (scroll continuu) | DA | `ScaleType.Tile` + animare `Offset` |
| 9-slice pentru panouri UI | DA | `ImageLabel.ScaleType = Slice` + `SliceCenter` |
| Particule (licurici, praf, fum) | DA, dar manual | Pool de `ImageLabel`, NU `ParticleEmitter` |
| Tint zi/noapte | PARȚIAL | Overlay alpha simplu, FĂRĂ multiply real (blend mode inexistent) |
| Blur real | NU | `BlurEffect` e exclusiv 3D (`Lighting` service) |
| Bloom/god rays/depth of field | NU | Toate sunt `PostEffect` din `Lighting`, exclusiv 3D |
| Fog/haze volumetric | NU | `Atmosphere` e exclusiv 3D, confirmat oficial |
| Ambient occlusion dinamic | NU | Trebuie pictat static în sprite, nu calculat |

## Ce putem fura pentru Driftwood

1. **Paletă dublă (fundal vs. interactiv) + regulă de contur fix pe obiecte interactive** — cost: **mic**. Nu cere cod nou, doar disciplină de artă: o paletă de 16-24 culori pentru fundal/mediu (valori medii, saturație joasă) și una separată, mai contrastantă, pentru obiecte de gameplay, plus `UIStroke` obligatoriu pe orice obiect interactiv.
2. **Parallax pe 3-4 straturi pentru fundalul râului** — cost: **mic-mediu**. Arhitectura `WorldContainer` cu offset de poziție există deja (cercetare internă); extinderea la 3-4 `Frame`-uri cu factori de viteză diferiți (0.2x/0.5x/1.0x/1.3x) e o modificare directă, nu un sistem nou.
3. **Vignette radial permanent, subtil** — cost: **mic**. Un `ImageLabel` full-screen + `UIGradient` Radial static, opțional cu intensitate crescută la noapte/pericol. O singură instanță, zero cost de întreținere.
4. **Tint zi/noapte prin overlay dublu (culoare + întunecare separată)** — cost: **mediu**. Cere testare în Studio pentru a valida că rezultatul vizual (fără multiply real) e acceptabil; dacă nu, varianta de rezervă (sprite-uri pre-colorate per moment al zilei) e cost **mare** în asset-uri, dar vizual superior — decizie de prototipat înainte de a angaja artă finală.
5. **Pool de particule ambientale reciclate (licurici seara, praf de-a lungul zilei, stropi la plasă)** — cost: **mediu**. Sistemul de bază există deja documentat intern; ce lipsește e conținutul (texturi de particule) și tunarea ratelor per platformă (conservator pe mobil, conform limitei native Roblox de 100/s ca reper).
6. **Contact shadow pictată în fiecare sprite de obiect din lume** — cost: **mic per obiect, dar recurent** — regulă de pipeline de artă (fiecare sprite nou trebuie să includă o umbră de contact la bază), nu cod. Ieftin per obiect, dar trebuie aplicat consecvent la sute de obiecte (indexul de reparații din masterplan-ul vechi avea 200+ obiecte) — cost total pe termen lung: **mediu**.
7. **Animație de fază aleatorie pentru elemente ambientale (iarbă/frunze legănate)** — cost: **mic**. Un singur parametru suplimentar (offset de start) pe fiecare instanță de tween în buclă, evită senzația artificială de sincronizare.
8. **Mod "reduce motion" pentru shake/particule intense** — cost: **mic**, deja semnalat ca risc de accesibilitate în cercetarea internă (docs/research/11-juice-effects.md) — de bifat din prima versiune, nu adăugat ulterior.

## Ce NU merge pentru noi

- **Fog/haze volumetric, bloom, god rays, depth of field** — toate sunt `PostEffect`/`Atmosphere` din `Lighting` service, confirmat exclusiv 3D. Cu `Workspace` gol (D04), nu există nimic de "luminat" — aceste efecte pur și simplu nu au unde să se aplice. Nu e o limitare de buget, e o limitare arhitecturală fermă: schimbarea ar însemna abandonarea deciziei 2D-pur-ScreenGui.
- **Blur real de ecran** — `BlurEffect` e din același `Lighting` service, inaccesibil. Orice "blur" la Driftwood trebuie simulat (transparență + desaturare), niciodată blur real de pixeli.
- **Lumină dinamică per-pixel (raycasting, gen Terraria "real-time")** — chiar Terraria nu face asta, face propagare pe grid cu prag de tăiere; pentru Driftwood, echivalentul realist e și mai simplu — un `UIGradient` Radial static/animat per sursă de lumină, NU un sistem de calcul de vizibilitate/umbre proiectate. Ambiția de "lumină ca în Terraria" trebuie tradusă în "glow radial static", nu construită ca sistem de calcul.
- **Animație procedurală complexă gen Rain World** — cere un motor de fizică/oase 2D dedicat (Rain World a avut 6 ani de dezvoltare pentru asta, cu 2 oameni concentrați exclusiv pe acest aspect). Pentru o echipă mică ce construiește primul joc Roblox, cost/beneficiu nu se justifică — animații pe cadre (sprite sheets) sau tween-uri simple pe proprietăți sunt suficiente și mult mai ieftine de întreținut.
- **Engine custom pentru lumină "3D peste 2D" gen Eastward (Gii+MOAI)** — Roblox nu permite înlocuirea pipeline-ului de randare; nu există echivalent la construirea unui motor custom peste Roblox Engine. Ambiția Eastward e complet incompatibilă cu platforma.
- **Efecte de ecran intense/repetate (chromatic aberration permanent, shake puternic frecvent)** — public tânăr pe Roblox + risc de fotosensibilitate deja semnalat în cercetarea internă; orice efect intens trebuie să fie rar (evenimente cheie), opțional (toggle reduce-motion), nu ambiental constant.
- **Paletă foarte mare/realistă (sute+ de culori, gradient photo-real)** — contravine convenției pixel art care produce coeziune vizuală (paletele populare catalogate sunt tipic sub 64 de culori); și crește costul de artă per sprite fără beneficiu clar de "bogăție" percepută — dovada empirică (Stardew, Terraria, Don't Starve) arată că paleta limitată, nu bogată, e ce se asociază cu jocurile lăudate pentru atmosferă.

## Riscuri si necunoscute

- **Bugetul de căutare web al sesiunii a fost epuizat înainte de a finaliza cercetarea** (WebSearch a raportat "200 of 200" folosite) — toată cercetarea de mai sus s-a bazat exclusiv pe WebFetch direct pe URL-uri cunoscute/deduse (Wikipedia, documentație Roblox, wiki-uri de joc), NU pe căutări noi. E posibil să existe surse primare mai bune (interviuri cu artiști, GDC talks, postmortemuri Gamasutra/Game Developer) pe care nu le-am putut găsi fără căutare activă — de reluat cercetarea cu buget de căutare proaspăt dacă se dorește adâncime suplimentară pe tehnici specifice (în special pentru AO/contact shadows în pixel art, unde sursele accesate au fost doar index-uri, nu conținut complet).
- **Numerele exacte de lumină Terraria (42/7 tile-uri) provin dintr-un wiki comunitar**, nu din documentație oficială Re-Logic sau cod sursă direct verificat de mine — tratați ca aproximare credibilă, nu ca specificație garantată.
- **Numerele de sanitate Don't Starve (50/min, 5/min) provin dintr-un wiki comunitar** care semnalează el însuși lipsă de informații specifice pe variante de joc (Shipwrecked, Hamlet, Together) — posibil ca numerele exacte să difere între versiuni/DLC-uri.
- **Nu am putut verifica tehnica exactă de "lumină 3D" din Eastward** dincolo de mențiunea Wikipedia despre engine-ul Gii + MOAI — nu am găsit un interviu tehnic detaliat cu echipa Pixpil în cercetarea curentă (căutare blocată de epuizarea bugetului).
- **UIGradient tween-abilitate** — absența din documentația oficială de animație NU e o dovadă definitivă că `TweenService` nu poate anima `UIGradient.Rotation`/`Offset`; e doar o absență de confirmare explicită. Trebuie testat direct în Roblox Studio înainte de a proiecta sisteme de shimmer/rotație de lumină pe baza acestei presupuneri.
- **Costul real de performanță al `CanvasGroup`** rămâne nedocumentat oficial — tratați ca "mai scump decât un `Frame` simplu" (confirmă un buffer separat de compositing), dar fără cifră concretă de la Roblox. Recomand profiling direct în Studio pe device mobil de gamă medie înainte de a-l folosi extensiv pe elemente care se redesenează des.
- **Graveyard Keeper rămâne insuficient documentat** pentru tehnica sa artistică specifică (stil semi-pictural) — orice afirmație despre tehnica lor exactă din surse externe acestei cercetări trebuie tratată ca NEVERIFICAT până la o cercetare dedicată.
- **Paletele "clasice" numite explicit în brief (PICO-8, DawnBringer)** nu au putut fi confirmate cu cifre exacte prin fetch direct pe Lospec (pagina de listă generică nu le-a inclus în eșantionul primit) — folosiți eșantionul Lospec obținut doar ca dovadă a convenției generale ("palete limitate, tipic sub 64 culori"), nu ca sursă pentru cifrele exacte ale paletelor numite în brief.

## Surse

- terraria.wiki.gg — Lighting: https://terraria.wiki.gg/wiki/Lighting (accesat 10.09.2026)
- terraria.wiki.gg — Torch: https://terraria.wiki.gg/wiki/Torch (accesat 10.09.2026)
- terraria.wiki.gg — Background: https://terraria.wiki.gg/wiki/Background (accesat 10.09.2026)
- Wikipedia — Terraria: https://en.wikipedia.org/wiki/Terraria (accesat 10.09.2026)
- dontstarve.wiki.gg — Darkness: https://dontstarve.wiki.gg/wiki/Darkness (accesat 10.09.2026)
- dontstarve.wiki.gg — Light: https://dontstarve.wiki.gg/wiki/Light (accesat 10.09.2026)
- Wikipedia — Don't Starve: https://en.wikipedia.org/wiki/Don%27t_Starve (accesat 10.09.2026)
- Wikipedia — Parallax scrolling: https://en.wikipedia.org/wiki/Parallax_scrolling (accesat 10.09.2026)
- Wikipedia — Hollow Knight: https://en.wikipedia.org/wiki/Hollow_Knight (accesat 10.09.2026)
- Wikipedia — Dead Cells: https://en.wikipedia.org/wiki/Dead_Cells (accesat 10.09.2026)
- Wikipedia — Rain World: https://en.wikipedia.org/wiki/Rain_World (accesat 10.09.2026)
- Wikipedia — Stardew Valley: https://en.wikipedia.org/wiki/Stardew_Valley (accesat 10.09.2026)
- Wikipedia — Eastward (video game): https://en.wikipedia.org/wiki/Eastward_(video_game) (accesat 10.09.2026)
- Wikipedia — Blasphemous (video game): https://en.wikipedia.org/wiki/Blasphemous_(video_game) (accesat 10.09.2026)
- Wikipedia — Core Keeper: https://en.wikipedia.org/wiki/Core_Keeper (accesat 10.09.2026)
- Wikipedia — Graveyard Keeper: https://en.wikipedia.org/wiki/Graveyard_Keeper (accesat 10.09.2026)
- Roblox Creator Docs — UIGradient: https://create.roblox.com/docs/reference/engine/classes/UIGradient (accesat 10.09.2026)
- Roblox Creator Docs — CanvasGroup: https://create.roblox.com/docs/reference/engine/classes/CanvasGroup (accesat 10.09.2026)
- Roblox Creator Docs — UIStroke: https://create.roblox.com/docs/reference/engine/classes/UIStroke (accesat 10.09.2026)
- Roblox Creator Docs — UIShadow: https://create.roblox.com/docs/reference/engine/classes/UIShadow (accesat 10.09.2026)
- Roblox Creator Docs — Appearance modifiers: https://create.roblox.com/docs/ui/appearance-modifiers (accesat 10.09.2026)
- Roblox Creator Docs — GradientType enum: https://create.roblox.com/docs/reference/engine/enums/GradientType (accesat 10.09.2026)
- Roblox Creator Docs — ParticleEmitter: https://create.roblox.com/docs/effects/particle-emitters (accesat 10.09.2026)
- Roblox Creator Docs — Atmosphere: https://create.roblox.com/docs/environment/atmosphere (accesat 10.09.2026)
- Roblox Creator Docs — BlurEffect: https://create.roblox.com/docs/reference/engine/classes/BlurEffect (accesat 10.09.2026)
- Roblox Creator Docs — GuiObject: https://create.roblox.com/docs/reference/engine/classes/GuiObject (accesat 10.09.2026)
- Roblox Creator Docs — ImageLabel: https://create.roblox.com/docs/reference/engine/classes/ImageLabel (accesat 10.09.2026)
- Roblox Creator Docs — UI animation: https://create.roblox.com/docs/ui/animation (accesat 10.09.2026)
- Lospec — Palette list: https://lospec.com/palette-list (accesat 10.09.2026)
- Lospec — Pixel art tutorials index: https://lospec.com/pixel-art-tutorials/light-and-shadow (accesat 10.09.2026, conținut complet inaccesibil, doar index)
- Intern — docs/research/06-screengui-2d-feasibility.md (fișier din proiect Driftwood)
- Intern — docs/research/11-juice-effects.md (fișier din proiect Driftwood)
