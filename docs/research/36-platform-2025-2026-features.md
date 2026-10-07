# Ce s-a schimbat pe platforma Roblox in 2025-2026

> Cercetare pentru Driftwood (joc 2D side-scroll, ScreenGui pur, economie server-autoritara).
> Data cercetarii: 2026-09-08. RDC 2026 e programat 10-12 septembrie 2026 (San Jose) — **nu s-a
> intamplat inca** la data acestui research, deci tot ce e "RDC 2026" mai jos e doar anuntul
> "save the date", nu recap de continut.

## Rezumat executiv

- **DevEx are acum doua rate, nu una.** Rata standard a crescut de la $0.0035 la $0.0038 per
  Robux pe 5 septembrie 2025 (+8.5%), iar din 8 iunie 2026 exista o rata premium de $0.0054
  per Robux (+42%) doar pentru cheltuieli ale jucatorilor 18+ din SUA, in jocuri care indeplinesc
  criterii stricte de avatar. Nota din CLAUDE.md ("$0.0038, standard") e corecta ca baseline, dar
  incompleta — merita verificat daca Driftwood poate califica pentru rata premium.
- **"Primele trei jocuri ale zilei" din CLAUDE.md e o interpretare gresita a Creator Rewards.**
  Sursa oficiala spune ca bonusul de 5 Robux/zi se acorda pentru **primele 3 experiente pe care
  un Active Spender le lanseaza in ziua respectiva** — nu "top 3 jocuri de pe platforma". E o
  cerinta despre comportamentul jucatorului, nu un clasament de ranking pe care Driftwood ar
  trebui sa-l "castige".
- **UI Styling API (StyleSheet/StyleRule/StyleLink) a ajuns la Full Release pe 20 ianuarie 2026.**
  Pentru un joc 2D construit integral din Frame/ImageLabel in ScreenGui, e cel mai relevant
  update de UI din tot intervalul — permite gestionarea centralizata a stilului (culori, fonturi,
  padding) fara sa modifici proprietati pe fiecare instanta.
- **UIDragDetector e o clasa nativa stabila pentru interactiuni de tip drag-and-drop**, utila
  direct pentru plasarea plaselor pe mal sau reorganizarea inventarului din atelier, fara cod
  custom de InputBegan/InputChanged.
- **Chat-ul vechi (legacy chat) a fost oprit obligatoriu pe 30 aprilie 2025** — orice experienta
  trebuie sa foloseasca `TextChatService`. Daca Driftwood adauga vreodata chat intre jucatori,
  se porneste direct de la `TextChatService`, nu de la API-uri vechi.
- **Age Check to Chat e live global din 9 ianuarie 2026** si imparte userii in categorii de varsta
  (sub 9, 9-12, 13-15, 16+) care limiteaza cu cine pot vorbi. Relevant doar daca Driftwood
  introduce chat text intre jucatori sau in "orasul comun".
- **Managed Pricing (15 iunie 2026) a unificat Regional Pricing si Price Optimization** intr-un
  singur sistem automat de testare a preturilor pentru Developer Products, cu crestere medie
  raportata de 4-10% in cheltuiala Robux si ~4% in castiguri.
- **Server Authority a ajuns la Full Release pe 9 iulie 2026** — un mecanism nativ de motor care
  reduce nevoia de anti-cheat custom pentru fizica/miscare. Driftwood foloseste deja arhitectura
  server-autoritara manual (AABB simplu, validare pe server), deci beneficiul e limitat, dar merita
  testat in Studio daca reduce cod de validare.
- **Experience Notifications** (notificari push in Roblox app, nu doar in joc) sunt un canal
  direct relevant pentru mecanica de retentie/offline a Driftwood — permit sa anunti un jucator
  ca plasa lui e plina sau ca a inceput o Inundatie, cu maximum o notificare/zi/experienta.
- **Open Cloud Luau Execution API e inca in beta dupa aproape 2 ani** (lansat sept. 2024, tot
  beta in mai 2026) — utilizabil pentru CI/CD si teste automate in Studio headless, dar trebuie
  tratat ca instabil in pipeline-uri de productie.
- **EditableImage/EditableMesh nu au un anunt clar de "General Availability"** in documentatie —
  sunt utilizabile in experiente publicate din noiembrie 2024, dar Roblox continua sa le trateze
  ca in evolutie (ex. `CreateDataModelContentAsync` a ajuns Full Release abia in mai 2026).
  Relevanta scazuta pentru Driftwood (nu genereaza mesh-uri/imagini procedural la runtime).

## Fapte verificate

- DevEx: rata standard a crescut de la $0.0035/Robux la $0.0038/Robux incepand cu 5 septembrie
  2025, ora 10:00 PT. Sursa: devforum.roblox.com, "Increasing DevEx — Creators Will Now Earn
  8.5% More", 2025-09-05. Incredere: ridicata.
- DevEx: minimul de cash-out ramane 30.000 Robux castigati, o cerere completata pe luna
  calendaristica. Sursa: create.roblox.com/docs/production/monetization/developer-exchange
  (pagina curenta, verificata 2026-09-08). Incredere: ridicata.
- DevEx: din 8 iunie 2026 exista o rata suplimentara de $0.0054/Robux (+42% fata de $0.0038)
  pentru Robux castigati din cheltuieli ale jucatorilor 18+ verificati din SUA, doar in jocuri
  eligibile (avatar R15 standard, rig custom uman cu 15+ articulatii, rig non-uman custom, sau
  fara personaj vizibil). Sursa: devforum.roblox.com, "Introducing the US 18+ DevEx Rate: Earn
  42% More on Spend from 18+ US Players", 2026-04-30. Incredere: ridicata.
- Creator Rewards: bonus de 5 Robux catre creator cand un "Active Spender" (a cheltuit minim
  $9.99 in ultimele 60 de zile) petrece 10+ minute intr-o experienta, limitat la primele 3
  experiente lansate de acel user in ziua respectiva. Sursa: devforum.roblox.com, "Introducing
  Creator Rewards: Earn More by Growing the Community", 2025-06-24 (program live din
  2025-07-24). Incredere: ridicata.
- Creator Rewards: "Audience Expansion Rewards" da 35% revenue-share din primii $100 Robux
  cheltuiti de un user nou/inactiv 60+ zile care a jucat 10+ min si a gasit jocul prin link
  direct/cautare de nume, cu conditia ca experienta sa mentina DAU mediu de 100 in perioada de
  retinere de 60 de zile. Sursa: aceeasi ca mai sus. Incredere: ridicata.
- UI Styling API (StyleSheet, StyleRule, StyleLink, StyleDerive) a trecut de la Studio Beta
  (22 mai 2025) la Client Beta cu publicare permisa (26 august 2025) la Full Release
  (20 ianuarie 2026). Sursa: devforum.roblox.com, "[Full Release] UI Styling is officially
  released!", 2026-01-20. Incredere: ridicata.
- StyleQuery (echivalent CSS media/container queries) a ajuns Full Release pe **11 mai 2026**
  (corectat la verificare; nu 9 aprilie 2026 — aceea e data postarii initiale a topicului, care la
  origine descria un stadiu anterior, iar statusul de Full Release a fost confirmat ulterior prin
  editare, cf. Weekly Recap 11-15 mai 2026); tranzitii de stil (animatii declarative) au ajuns Full
  Release pe **27 iulie 2026** (corectat la verificare; nu 21 mai 2026 — aceea e data postarii
  initiale, care anunta doar Studio Beta, iar anuntul de Full Release a fost adaugat prin editare
  pe 27 iulie 2026). Sursa: devforum.roblox.com, slug-uri
  "full-release-stylequery-more-styling-features" si "full-release-styling-transitions".
  Incredere: ridicata.
- Legacy Chat (API vechi de chat) a devenit obligatoriu inlocuit cu `TextChatService` — migrare
  automata a inceput in loturi din mai 2025, cu termen dur de 30 aprilie 2025 pentru
  functionalitati custom. Sursa: devforum.roblox.com, "Update on Legacy Chat Deprecation and
  TextChatService Migration", 2025-01-13. Incredere: ridicata.
- Age Check to Chat a devenit obligatoriu global din 9 ianuarie 2026; userii neverificati nu pot
  folosi chat text cu alti useri; verificarea se face prin estimare faciala a varstei (vendor
  Persona) sau verificare de act. Sursa: devforum.roblox.com, "Age Check Requirement to Chat Now
  Live Globally", 2026-01-07 (continut actualizat pana in ian. 2026). Incredere: ridicata.
- Din 23 februarie 2026, link-urile catre social media din profil sunt vizibile doar userilor
  verificati 13+; din martie 2026, verificarea de varsta e ceruta si pentru Team Create in
  Studio. Sursa: aceeasi mai sus + "An Update on Our Age Check to Chat Fast Follow Roadmap",
  2026-01-23. Incredere: medie (date derivate din recapitulari, nu din pagina oficiala de
  politica).
- Managed Pricing a lansat pe 15 iunie 2026, unificand Regional Pricing si Price Optimization;
  jocurile/itemele noi sunt inrolate automat, cele existente cu Regional Pricing trec automat,
  opt-out disponibil oricand; testele ruleaza cel putin o data la 90 de zile, cu preaviz de 7
  zile. Sursa: devforum.roblox.com, "Managed Pricing: One System for Better Pricing and Earnings
  Growth", 2026-06-15. Incredere: ridicata.
- Managed Pricing/Regional Pricing: crestere medie raportata de 4-10% in cheltuiala Robux si
  crestere similara in engagement; Price Optimization a dus la ~4% crestere medie a castigurilor,
  cu exemplul "Slap Battles" la peste 15%. Sursa: aceeasi. Incredere: medie (cifre auto-raportate
  de Roblox, fara metodologie publica detaliata).
- Server Authority (mecanism nativ server-autoritar pentru fizica/miscare, reduce nevoia de
  anti-cheat custom) a trecut prin Studio Beta (9 dec. 2025), Client Beta la scara (30 apr. 2026)
  si Full Release (9 iulie 2026). Sursa: devforum.roblox.com, "[Full Release] Ship Fair And
  Competitive Games with Server Authority", 2026-07-09. Incredere: ridicata pentru datele de
  status, medie pentru detaliile tehnice exacte de API (fetch nu a returnat lista completa de
  clase implicate).
- EditableImage si EditableMesh au trecut in Client Beta si sunt utilizabile in experiente
  publicate din 20 noiembrie 2024 (update la un topic din 23 octombrie 2024) — deci sunt
  pre-2025 ca disponibilitate, dar continua sa primeasca functii noi in 2025-2026 (ex.
  `AssetService:CreateDataModelContentAsync` la Full Release pe **18 mai 2026** (corectat la
  verificare; nu 27 martie 2026 — aceea e data postarii initiale, care anunta doar Studio Beta;
  disponibilitatea in experiente publicate a fost confirmata printr-un update pe 18 mai 2026).
  Sursa: devforum.roblox.com, "[Studio Beta] Major updates to in-experience Mesh &
  Image APIs" si "[Full Release] Introducing CreateDataModelContent...". Incredere: medie —
  documentatia oficiala a claselor (create.roblox.com/docs/reference/engine/classes/EditableImage
  si .../EditableMesh) NU marcheaza explicit un status Beta/GA in continutul extras.
- Open Cloud "Engine API for Executing Luau" (Luau Execution API) a fost lansat in Beta pe 25
  septembrie 2024 si **este inca in Beta** in mai 2026, cu adaugiri (timeout configurabil,
  logging structurat) dar fara anunt de Full Release. Sursa: devforum.roblox.com, "[Beta] Open
  Cloud Engine API for Executing Luau", topic activ pana in mai 2026. Incredere: ridicata pentru
  status, dar NEVERIFICAT daca a iesit din beta dupa mai 2026 pana la data cercetarii.
- Experience Notifications: maximum 99 de caractere per notificare, maximum 200 bytes launch
  data, un user primeste maximum 1 notificare/zi de la o experienta, eligibilitate minima 100
  vizite de la lansare, se trimit via Open Cloud V2 UserNotification (`createUserNotification`).
  Sursa: create.roblox.com/docs/production/promotion/experience-notifications (pagina curenta).
  Incredere: ridicata.
- Parallel Luau: scripturile trebuie sa fie sub instante `Actor`, iar codul trebuie sa apeleze
  `task.desynchronize()` pentru executie paralela; `require()` nu poate fi apelat in faza
  paralela; instantele nu pot fi modificate in faza paralela. Sursa: create.roblox.com/docs/
  scripting/multithreading. Incredere: ridicata (documentatie oficiala curenta, dar fara data
  explicita de "ultima actualizare" vizibila in continutul extras).
- Audio API (AudioPlayer/AudioEmitter/AudioListener/Wire) a iesit din beta pe 10 septembrie
  2024 (deci **inainte** de fereastra 2025-2026, flag ca posibil in afara scopului), cu adaugiri
  in 2025-2026: Acoustic Simulation in Client Beta din 28 ianuarie 2026. Sursa: devforum.roblox.com,
  cautare + "[Client Beta] Acoustic Simulation: Emit audio with presence!", 2026-01-28.
  Incredere: medie (data exacta a postarii de exit-beta nu a fost verificata direct pe pagina
  originala, ci dedusa din rezultate de cautare).
- RDC 2026 e programat 10-12 septembrie 2026 in San Jose — anuntat pe 3 aprilie 2026, deci
  **nu s-a intamplat inca** la data acestei cercetari (8 septembrie 2026). Sursa:
  devforum.roblox.com, "Save the Date: RDC26", 2026-04-03. Incredere: ridicata.
- Cube 3D (model generativ text-to-3D, 1.8B parametri) a intrat in Beta pe 20 martie 2025;
  "4D Generation" (obiecte functionale multi-parte, migrare de la `GenerateMeshAsync`) a intrat
  in Beta pe 4 februarie 2026. Sursa: devforum.roblox.com, "[Beta] Cube 3D Generation Tools and
  APIs for Creators" si "[Beta] 4D Generation: Unlock New Types of Gameplay". Incredere: ridicata
  pentru date, relevanta scazuta pentru Driftwood (joc 2D, fara generare de mesh-uri 3D).

## Detalii

### 1. RDC 2025 vs RDC 2026 — ce exista de fapt la 8 septembrie 2026

RDC (Roblox Developer Conference) 2025 a avut loc in jurul datei de 5 septembrie 2025 (recapul
oficial "RDC25: What we announced" a fost postat pe devforum.roblox.com pe 2025-09-05). RDC 2026
e anuntat pentru **10-12 septembrie 2026** in San Jose (postare "Save the Date: RDC26",
2026-04-03) — adica la doar cateva zile dupa data acestei cercetari (2026-09-08). **Nu exista
inca niciun recap de continut pentru RDC 2026** — orice afirmatie despre "ce s-a anuntat la RDC
2026" gasita in surse secundare inainte de 10 septembrie 2026 e prematura sau speculativa si
trebuie ignorata pana la recapul oficial.

Ce s-a anuntat concret la RDC 2025 (sursa: devforum "RDC25: What we announced" + "Creator Roadmap
2025: RDC Update"):

| Domeniu | Anunt | Status la RDC | Relevanta Driftwood |
|---|---|---|---|
| Monetizare | DevEx +8.5% ($0.0035 -> $0.0038) | Live imediat | Ridicata |
| Monetizare | Regional Pricing pentru Developer Products | Rollout | Ridicata |
| Monetizare | Creator Store — vanzare de modele intre creatori | "luna viitoare" (oct. 2025) | Scazuta |
| Grafica | 4K texture, emissive maps | Late 2025 | Scazuta (2D ScreenGui) |
| Grafica | CSG pe mesh-uri, SLIM (inlocuieste LOD) | Late 2025 - mid 2026 | Nula (fara 3D) |
| Anti-cheat | Server Authority — early access | Beta | Medie |
| Voce/audio | Text-to-Speech API live; Speech-to-Text si traducere in lucru | Beta -> GA treptat | Scazuta-medie |
| Colaborare | Comentarii in viewport 3D, Creator Groups cu permisiuni | Live | Medie (echipa mica) |
| Safety | Age estimation extinsa la toti userii pana la finalul anului | Rollout | Ridicata (vezi sectiunea chat) |
| AI | Assistant cu actiuni multi-step, integrare MCP cu LLM-uri terte | Rollout | Medie (unealta pt. developer) |

Recapul de sfarsit de an ("Creator Roadmap: 2025 End of Year Recap", 2025-12-16) confirma 39 de
feature-uri noi livrate din toamna 2025, peste 1.400 de bug-uri inchise, si un rating intern de
livrare la timp de doar **53%** (in scadere fata de 59% anterior) — Roblox insusi recunoaste ca a
prioritizat stabilitatea in detrimentul vitezei de livrare. Actualizarea de primavara 2026
("Creator Roadmap 2026: Spring Update", 2026-05-08) raporteaza 52 de feature-uri livrate de la
recapul de iarna, cu intarzieri notabile pentru CSG pe mesh-uri, physics solver imbunatatit,
voxel terrain extins si API video avansat — toate impinse din nou spre mijlocul/finalul lui 2026.

### 2. Monetizare: DevEx, Creator Rewards, Managed Pricing

**DevEx — tabel de rate (verificat pe create.roblox.com/docs/production/monetization/
developer-exchange, pagina curenta):**

| Rata | Valoare | Cui se aplica | De cand |
|---|---|---|---|
| Legacy | $0.0035 / Robux | Solduri castigate inainte de 5 sept. 2025 10:00 PT | pana la epuizare |
| Standard | $0.0038 / Robux | Toti creatorii, orice Robux castigat | din 5 sept. 2025 |
| Premium 18+ US | $0.0054 / Robux | Robux din cheltuieli ale userilor 18+ verificati din SUA, doar in jocuri eligibile, doar pentru game passes/developer products/subscriptii Robux/private servers (NU avatar items/marketplace) | din 8 iunie 2026 |

Minimul de cash-out ramane **30.000 Robux castigati**, o cerere completata **pe luna
calendaristica** — exact ce spune CLAUDE.md. Ce lipseste din CLAUDE.md e rata premium:
criteriile de eligibilitate pentru rata de $0.0054 sunt: avatarul jucatorului e mereu R15
standard, SAU un rig uman custom cu 15+ articulatii distribuite pe corp, SAU un rig non-uman
custom (patruped, dragon, vehicul), SAU **niciun personaj de jucator vizibil** (jocuri
puzzle/strategie/carti). Robux-ul cu rata mai mare se caseaza intai, ca sa maximizeze castigul.

**Creator Rewards** (live din 24 iulie 2025, anuntat 24 iunie 2025) are doua componente:

1. **Daily Engagement Rewards**: 5 Robux catre creator per "Active Spender" (user care a
   cheltuit minim $9.99 in ultimele 60 de zile) care petrece 10+ minute intr-o zi in experienta,
   cumulate pe mai multe sesiuni. **Se plateste doar pentru primele 3 experiente pe care acel
   user le lanseaza in ziua respectiva** — nu exista bonus pentru "a fi in top 3 jocuri de pe
   platforma" cum sugereaza formularea din CLAUDE.md. E o distinctie critica: obiectivul de
   design corect e "fii una din primele 3 experiente pe care jucatorul tau tipic le deschide in
   ziua aia", nu "castiga un clasament global".
2. **Audience Expansion Rewards**: 35% revenue-share din primii $100 Robux cheltuiti de un user
   nou sau inactiv 60+ zile, care a jucat 10+ minute si a gasit experienta prin link direct sau
   cautare de nume (nu prin discovery/recomandari) — cu conditia ca experienta sa mentina un DAU
   mediu de 100 in perioada de retinere de 60 de zile.

Ambele au o **perioada de retinere de 60 de zile** inainte ca Robux-ul sa ajunga in soldul
creatorului.

**Managed Pricing** (15 iunie 2026) unifica Regional Pricing (preturi diferite pe piata/putere de
cumparare) si Price Optimization (teste automate bazate pe cerere/conversie) intr-un singur
sistem: jocurile si itemele noi sunt inrolate automat; itemele existente cu Regional Pricing
trec automat, fara actiune; opt-out disponibil oricand din Creator Dashboard. Testele ruleaza cel
putin o data la 90 de zile (sau mai des daca pretul pare suboptim), cu preaviz de 7 zile inainte
de un test si posibilitate de reprogramare. Roblox raporteaza cresteri medii de 4-10% in
cheltuiala Robux pentru jocurile cu Regional Pricing si ~4% crestere medie a castigurilor pentru
cele eligibile pentru Price Optimization (exemplu citat: Slap Battles, +15%).

### 3. UI: StyleSheet API, UIDragDetector, fonturi

**UI Styling API** (clasele `StyleSheet`, `StyleRule`, `StyleLink`, `StyleDerive`) e cea mai
relevanta schimbare de UI din interval pentru Driftwood, pentru ca tot jocul e Frame/ImageLabel
in ScreenGui. Cronologie: Studio Beta (22 mai 2025) -> Client Beta cu publicare permisa in
experiente live (26 august 2025) -> **Full Release (20 ianuarie 2026)**. Ulterior au aparut
StyleQuery — echivalentul CSS media/container queries, pentru stiluri conditionale dupa
dimensiune ecran/orientare — la Full Release pe **11 mai 2026** (corectat la verificare, nu 9
aprilie 2026 — acea data e a postarii initiale a topicului, dinainte ca statusul de Full Release
sa fie confirmat prin editare, cf. Weekly Recap 11-15 mai 2026), si tranzitii de stil (animatii
declarative intre stari) la Full Release pe **27 iulie 2026** (corectat la verificare, nu 21 mai
2026 — acea data e a postarii initiale de Studio Beta, editata ulterior cu anuntul de Full
Release).

Model conceptual (Luau, aproximativ dupa documentatie):

```lua
local StyleSheet = Instance.new("StyleSheet")
local rule = Instance.new("StyleRule")
rule.Selector = ".net-slot"
rule.Parent = StyleSheet
rule:SetProperty(Enum.StyleProperty.BackgroundColor3, Color3.fromRGB(40, 90, 120))

local link = Instance.new("StyleLink")
link.StyleSheet = StyleSheet
link.Parent = someScreenGuiOrFrame -- radacina arborelui la care se aplica stilul
```

Practic: in loc sa setezi `BackgroundColor3` pe fiecare Frame din inventarul atelierului si sa le
tii sincronizate manual, tagg-uiesti instantele si le controlezi central printr-un `StyleRule`.
Exista si un Style Editor no-code in Studio (tab UI) pentru echipe care nu vor sa scrie tot in
cod.

**UIDragDetector** e o clasa nativa (mostenita din `UIComponent`) cu evenimente `DragStart`,
`DragContinue`, `DragEnd`, proprietati de constrangere (`MinDragTranslation`,
`MaxDragTranslation`, `BoundingBehavior`, `BoundingUI`) si metode ca `AddConstraintFunction()`
pentru logica custom de constrangere. Nu am gasit in documentatie o data explicita de
introducere (NEVERIFICAT exact cand a aparut), dar e prezenta stabil in documentatia curenta
2026. Pentru Driftwood, inlocuieste cod custom de drag pentru plasarea plaselor pe mal sau
rearanjarea obiectelor in inventar/atelier, cu constrangeri native de tip "nu iesi din zona X".

**Fonturi si rich text**: nu am gasit un anunt oficial de "sistem de fonturi nou" in 2025-2026 —
singura schimbare identificata e evidentierea fontului nativ **BuilderIcons** (set mare de
iconite incluse in engine, subfolosit pana acum), aparuta in discutie pe devforum pe 30 septembrie
2025. `RichText` pe `TextLabel`/`TextButton` (tag-uri gen `<b>`, `<i>`, `<font color="">`) ramane
o functionalitate stabila, pre-existenta — **nu am gasit dovezi ca s-ar fi schimbat semnificativ
in 2025-2026**; orice afirmatie despre "font system nou" trebuie tratata ca NEVERIFICAT pana la o
sursa oficiala clara. La fel, `UIFlexLayout` — nicio cautare pe devforum n-a returnat update-uri
2025-2026; ramane o feature stabila mai veche, nu o schimbare de raportat aici.

### 4. Chat, varsta si social

Cronologie critica pentru orice experienta cu chat:

| Data | Eveniment | Sursa |
|---|---|---|
| 30 apr. 2025 | Deadline dur: toate experientele trebuie sa foloseasca `TextChatService`; chat vechi (`LegacyChatService`) trece in "compatibility mode" invizibil | devforum 3376880 (2025-01-13) |
| mai 2025 | Auto-migrare in loturi pentru sistemele care n-au migrat manual | idem |
| 18 nov. 2025 | Anunt: age check va fi cerut pentru chat, link-uri social, Team Create | devforum 4079702 |
| 9 ian. 2026 | Age Check to Chat **live global** (SUA + regiuni selectate, apoi extins in ~1 saptamana) | devforum 4226101 (2026-01-07) |
| 23 feb. 2026 | Link-urile social din profil vizibile doar userilor verificati 13+ | devforum "An Update on Our Age Check to Chat Fast Follow Roadmap" |
| mar. 2026 | Verificare de varsta ceruta si pentru Team Create in Studio | idem |
| 8 iun. 2026 | Rata DevEx premium 18+ US devine live (vezi sectiunea monetizare) | devforum 4607091 |

Verificarea de varsta se face prin **estimare faciala** (vendor extern: Persona) sau prin
**verificare de act de identitate**; Roblox afirma explicit ca fotografiile/videoclipurile nu sunt
pastrate si sunt sterse imediat dupa procesare. Userii sunt sortati in categorii: sub 9, 9-12,
13-15, 16+, iar implicit pot vorbi doar cu propria categorie plus categoriile adiacente — deci un
adult verificat NU poate vorbi implicit cu un copil de 9-12 ani. Exista un "Text Chat Matchmaking
Signal" mentionat pentru ca developerii sa poata grupa preferential jucatorii eligibili pentru
chat intre ei.

Alte schimbari sociale relevante daca Driftwood adauga vreodata prieteni/co-op:
- **"Friends Are Back: Expanding Trusted Friends"** (2 apr. 2026) — extindere a sistemului de
  prieteni de incredere.
- **"Introducing Trusted Connections & Privacy Tools"** (17 iul. 2025) — control mai fin al
  cine poate contacta un user.
- **Cross-Server Chat** — live din 12 mai 2026, permite chat intre servere diferite ale aceleiasi
  experiente (relevant pentru un joc unde tot serverul imparte acelasi oras, dar Driftwood n-are
  nevoie de cross-server in faza actuala).

**Nu am gasit o feature dedicata numita "Party" sau "Connect" ca produs separat, activ lansat in
2025-2026** dincolo de "Roblox Connect" (API de apeluri video, anuntat inca din noiembrie 2023 —
deci in afara ferestrei cerute) si un "Party Chat" mentionat colateral intr-un raport de
utilizator despre suspendare de cont (fara pagina oficiala de anunt gasita). **Marcati ca
NEVERIFICAT** orice afirmatie specifica despre un sistem "Party" nou in 2025-2026; nu exista
sursa primara clara gasita in aceasta cercetare.

### 5. Server Authority (motor, nu cod custom)

Server Authority e o feature de motor care muta autoritatea fizicii/miscarii pe server, cu
scopul declarat de a "reduce cheating and improve fairness" fara cod anti-cheat custom, blocand
exploit-uri gen speed-hack, mentinand raspuns instant pe client. Cronologie: Studio Beta
(9 dec. 2025) -> Client Beta la scara, publicabil (30 apr. 2026) -> **Full Release (9 iulie
2026)**, disponibil "pentru toti creatorii".

Pentru Driftwood: arhitectura descrisa deja in CLAUDE.md (server decide ce a prins jucatorul,
RemoteEvents cu validare pe server) e conceptual identica cu ce Server Authority automatizeaza la
nivel de motor pentru miscare fizica standard (Humanoid/parts 3D). Documentatia extrasa **nu
specifica** daca se aplica si la coliziuni AABB custom in 2D pe ScreenGui (Driftwood nu foloseste
Humanoid/fizica 3D nativa) — practic feature-ul pare gandit pentru jocuri cu personaje 3D
standard. **De testat in Studio** daca are vreo aplicabilitate reala pentru un joc 100% 2D custom;
altfel Driftwood ramane pe validarea proprie pe server, ceea ce oricum e planul corect.

### 6. EditableImage, EditableMesh, Cube 3D, Studio Assistant

`EditableImage` (desenare/compunere de pixeli in runtime — `DrawImage`, `WritePixelsBuffer`,
`ReadPixelsBuffer`) si `EditableMesh` (manipulare de mesh — vertecsi, fete, UV-uri, bones) sunt
"Not Creatable" direct — se creeaza prin `AssetService`, necesita capacitatea `DynamicGeneration`.
Documentatia oficiala a claselor **nu marcheaza explicit un status Beta/GA** in continutul
extras — sunt tratate ca API-uri normale de engine. Au fost mutate in Client Beta si permise in
experiente publicate din 20 noiembrie 2024 (deci tehnic inainte de fereastra 2025-2026), iar in
2025-2026 au primit adaugiri incrementale: `AssetService:CreateDataModelContentAsync` (converteste
date editable in continut static persistent) a ajuns Full Release pe **18 mai 2026** (corectat la
verificare; 27 martie 2026 a fost data postarii initiale de Studio Beta, nu de Full Release).

**Relevanta pentru Driftwood: scazuta in faza curenta** — jocul foloseste sprite-uri statice
(ImageLabel), nu genereaza imagini/mesh-uri procedural la runtime. Ar deveni relevant doar daca
se decide generarea proceduala de sprite-uri (ex. combinarea vizuala a obiectelor reparate) —
de pastrat ca optiune viitoare, nu ca prioritate.

**Cube 3D** (model generativ text-to-3D, 1.8B parametri) a intrat Beta pe 20 martie 2025;
"4D Generation" (obiecte functionale multi-parte cu miscare, inlocuind fluxul vechi bazat pe
`GenerateMeshAsync`) a intrat Beta pe 4 februarie 2026. Ambele genereaza continut 3D — **irelevante
pentru un joc 2D pur**, dar util de stiut ca `GenerateMeshAsync` e in proces de inlocuire, deci
orice tutorial vechi care il foloseste ca API principal e potential invechit.

**Studio AI Assistant** a primit in 2025-2026: mod de planificare (genereaza liste de task-uri si
valideaza rezultatul), comanda `/generate_procedural_model`, suport server MCP pentru integrare cu
LLM-uri externe, API de speech-to-text la Full Release, text-to-speech multilingv. Util ca unealta
de productivitate pentru developer (owner-ul e nou pe Roblox), dar nu afecteaza direct design-ul
de joc.

### 7. Parallel Luau / Actors

Model de executie paralela: scripturile trebuie plasate sub instante `Actor`; codul apeleaza
`task.desynchronize()` pentru a intra in faza paralela (implicit, scripturile ruleaza serial).
Nivele de siguranta a accesului la API: Unsafe / Read Parallel / Local Safe / Safe. Comunicare
intre actori prin `SendMessage()`/`BindToMessage()`/`BindToMessageParallel()` (async) sau
`SharedTable`. Limitari: `require()` nu functioneaza in faza desincronizata; instantele nu pot fi
modificate direct in faza paralela; scripturile din acelasi Actor ruleaza tot secvential intre
ele.

**Relevanta pentru Driftwood: medie** — nu pentru gameplay-ul de baza (economia e simpla, server-
autoritara, low-throughput per server), dar potential util daca se calculeaza acumularea offline
pentru multi jucatori simultan la login/reset de sezon, sau daca simularea raului (multe obiecte
in miscare pe server) devine costisitoare pe un singur thread. De evaluat doar daca profiling-ul
arata bottleneck real, nu preventiv.

### 8. Audio API

API-ul audio nou (`AudioPlayer`, `AudioEmitter`, `AudioListener`, `Wire`) a iesit din beta pe
10 septembrie 2024 — **inainte** de fereastra ceruta 2025-2026, deci e flag-uit ca posibil in
afara scopului strict, dar il mentionez pentru ca ramane sistemul curent de baza. In decembrie
2024 a primit `AngleAttenuation` (beta), `AudioLimiter`, `AudioPlayer:GetWaveformAsync`. In 2026,
noutatea reala e **Acoustic Simulation** (reverb si ocluzie in timp real) — intrat in Client Beta
pe 28 ianuarie 2026, utilizabil in experiente publicate. Pentru sunetul de rau/ambient in
Driftwood, sistemul de baza (AudioPlayer + AudioEmitter) e deja suficient; Acoustic Simulation e
"nice to have", nu critic pentru un joc 2D.

### 9. Experience Notifications — canal de retentie

Direct relevant pentru "motorul principal de retentie" din CLAUDE.md. Limite verificate pe
create.roblox.com/docs/production/promotion/experience-notifications:

| Limita | Valoare |
|---|---|
| Caractere per notificare | 99 |
| Marime launch data | 200 bytes |
| Notificari per user per experienta | 1 / zi |
| Vizite minime pentru eligibilitate | 100 de la lansare |
| Impresii minime pentru analytics vizibil | 100 agregate |

Trimiterea se face server-side prin **Open Cloud V2 UserNotification** (pachet Luau din Creator
Store, `require(ServerScriptService.OpenCloud.V2.UserNotification)`), apeland
`createUserNotification(userId, userNotification)`, cu payload optional `joinExperience` (pentru
deep-link direct in joc la anumite date) si `analyticsData`. Livrarea NU e garantata — exista un
sistem anti-spam care poate filtra notificarea; motive de non-livrare: user neopt-in, throttle
atins, text moderat, sau conditii de mentionare a userului neindeplinite. Continutul e supus
Community Standards si filtrare de text; sunt interzise dark patterns, reclame deghizate, urgenta
falsa, bait-and-switch.

Pentru Driftwood: canal ideal pentru "plasa ta e plina", "a inceput Inundatia", "atelierul orasului
a deblocat o zona noua" — dar limitat strict la 1/zi/experienta, deci trebuie ales cu grija CE
notificare conteaza cel mai mult intr-o zi dw.

### 10. Open Cloud — Luau Execution API si alte adaugiri

**Luau Execution API** ("Engine API for Executing Luau") permite rularea headless de scripturi
Luau intr-un place Roblox, prin Open Cloud, util pentru CI/CD (teste automate fara sa deschizi
Studio manual). Lansat Beta pe 25 septembrie 2024, **ramane in Beta cel putin pana in mai 2026**
(ultimele postari active gasite pe topicul oficial dateaza din mai 2026, fara anunt de Full
Release). A primit imbunatatiri: timeout configurabil pentru task-uri de executie, logging
structurat. Probleme raportate de comunitate in 2025-2026: timeout-uri interne aleatorii, task-uri
care raman blocate, pachete (packages) care nu se incarca corect — semne ca stabilitatea inca
variaza.

**Relevanta pentru Driftwood**: util pentru pipeline de CI (ex. rulare de teste Luau la fiecare
push, in combinatie cu Rojo), dar de tratat ca beta — nu baza intregul flux de deploy pe el fara
fallback manual.

### 11. Deprecari notabile de evitat

1. **Legacy Chat / `ChatService` vechi** — obligatoriu inlocuit cu `TextChatService` din 30
   aprilie 2025. Orice tutorial sau exemplu de cod care foloseste `Chat.Chatted`,
   `LegacyChatService` sau evenimente vechi de chat e invechit.
2. **`PolicyServiceAPI.GetExternalLinkReference`** — in curs de "sunset", va returna liste goale
   (efect al rollout-ului de age check pentru link-uri social).
3. **`GenerateMeshAsync`** — in proces de inlocuire cu fluxul "4D Generation" (irelevant direct
   pentru Driftwood, dar semnaleaza ca API-urile generative 3D se schimba rapid; nu construi pe
   ele fara sa verifici statusul curent).

Nu am gasit o lista oficiala unica, centralizata, de "deprecari 2025-2026" (cautarile directe pe
devforum pentru "deprecated"/"sunset" in aceasta fereastra n-au returnat un topic-catalog dedicat)
— cele trei de mai sus sunt cele confirmate explicit in sursele citate. Orice alta afirmatie
despre "X e deprecated" gasita in surse secundare (YouTube, bloguri) trebuie verificata pe
devforum/create.roblox.com inainte de a fi tratata ca adevarata.

## Recomandari concrete pentru Driftwood

1. **Adopta UI Styling API (StyleSheet/StyleRule/StyleLink) de la inceputul prototipului**, nu
   dupa. Motivatie: intregul joc e Frame/ImageLabel in ScreenGui; a gestiona culori/fonturi/
   padding centralizat de la pasul 1 evita un refactor masiv mai tarziu cand UI-ul creste (inventar,
   atelier, index de colectie, HUD de sezon). Full Release confirmat 20 ianuarie 2026, deci e
   stabil pentru productie.
2. **Foloseste `UIDragDetector` pentru plasarea plaselor si reorganizarea inventarului din
   atelier**, in loc de InputBegan/InputChanged custom. Motivatie: constrangeri native
   (`BoundingUI`, `MinDragTranslation`) reduc bug-uri de "drag iesit din ecran" fata de cod
   manual scris de cineva nou pe Roblox.
3. **Corecteaza intern intelegerea Creator Rewards**: obiectivul nu e "sa fim in top 3 jocuri de
   pe platforma" (imposibil de controlat direct), ci "sa fim una din primele experiente pe care
   jucatorul nostru tipic o deschide in ziua respectiva" — ceea ce inseamna sesiune scurta si
   rapida de check-in dimineata (acumularea offline!) plus motiv sa revina de mai multe ori/zi
   daca se poate. Bucla de retentie deja planificata (plase + reparatii + atelier comun) se
   potriveste natural cu asta.
4. **Nu construi chat intre jucatori decat daca e strict necesar** — Age Check to Chat (live din
   ianuarie 2026) adauga complexitate semnificativa de compliance (verificare de varsta,
   categorii de brackets, restrictii de contact). Daca "obligatia sociala" din atelierul comun
   poate functiona doar prin donatii + progres vizibil (fara chat text), evita tot acest cost.
   Daca se adauga totusi chat, porneste direct de la `TextChatService`.
5. **Investigheaza eligibilitatea pentru rata DevEx premium ($0.0054/Robux, 18+ US)** —
   criteriul "niciun personaj de jucator vizibil" ar putea incadra Driftwood daca reprezentarea
   jucatorului pe malul raului nu foloseste un rig de avatar Roblox standard/R15. De verificat
   exact ce conteaza drept "personaj vizibil" in politica oficiala (docs-ul complet, nu doar
   recapul) inainte de a proiecta monetizarea in jurul acestei ipoteze.
6. **Foloseste Experience Notifications strategic, nu pentru orice eveniment** — limita de 1/zi/
   experienta forteaza o ierarhie: cel mai probabil candidat e alerta de Inundatie (eveniment
   lunar, rar, cu mare impact) sau "plasa ta s-a umplut" doar daca userul a fost inactiv suficient
   de mult. Nu trimite notificare pentru fiecare reparatie finalizata.
7. **Testeaza Server Authority in Studio (Full Release din iulie 2026) doar ca experiment**, nu
   ca dependinta de arhitectura. Motivatie: documentatia gasita nu confirma aplicabilitate clara
   la coliziuni AABB 2D custom (fara Humanoid). Planul din CLAUDE.md (validare server pe fiecare
   RemoteEvent) ramane calea sigura indiferent de rezultat.
8. **Nu investi in EditableImage/EditableMesh/Cube 3D acum** — potrivite pentru continut 3D
   generat procedural, irelevant pentru sprite-uri 2D statice. Revizuit doar daca planul de arta
   se schimba spre generare proceduala de sprite-uri compuse.
9. **Daca se foloseste Luau Execution API pentru CI/CD, pastreaza un fallback manual** (testare
   locala in Studio via Rojo) — API-ul e inca in beta dupa 2 ani, cu rapoarte de timeout-uri si
   task-uri blocate in 2025-2026.
10. **Monitorizeaza recapul RDC 2026 dupa 12 septembrie 2026** — conferinta are loc la doar
    cateva zile dupa aceasta cercetare; orice decizie mare de arhitectura UI/monetizare luata
    acum ar trebui re-verificata dupa recap, in caz ca schimba planul anuntat pentru Managed
    Pricing/Server Authority/UI Styling.

## Riscuri si necunoscute

- **RDC 2026 nu s-a intamplat inca** (10-12 sept. 2026) — orice plan facut acum poate fi
  suprascris de anunturi noi in urmatoarele 1-2 saptamani de la data acestei cercetari.
- **Eligibilitatea exacta pentru rata DevEx premium 18+ US** ("niciun personaj de jucator
  vizibil") nu a putut fi verificata in detaliu tehnic complet (fetch-ul a extras un rezumat, nu
  textul integral al politicii) — risc de a construi o presupunere de monetizare pe o interpretare
  gresita.
- **Server Authority**: documentatia extrasa nu confirma daca se aplica la fizica 2D custom
  (AABB manual, fara Humanoid). Necesita test direct in Studio, nu doar research pe forum.
- **EditableImage/EditableMesh nu au un status Beta/GA explicit documentat** — posibil ca
  documentatia oficiala sa foloseasca alt limbaj (ex. "Client Beta" undeva in pagina, netaptat de
  instrumentul de extractie folosit). De reverificat direct pe pagina in Studio/docs daca devine
  relevant vreodata.
- **Cifrele de crestere pentru Managed Pricing/Regional Pricing (4-10%, ~4%, +15% Slap Battles)**
  sunt auto-raportate de Roblox, fara metodologie publica — tratati ca indicativ, nu ca garantie
  pentru Driftwood.
- **Nu exista o lista oficiala centralizata de deprecari** pentru 2025-2026 — riscul e sa se
  foloseasca fara sa se stie un API pe cale de disparitie, descoperit doar prin research punctual
  ca cel de mai sus.
- **"Party"/"Connect" ca feature dedicat**: nu s-a gasit sursa primara clara — posibil sa existe
  sub alt nume sau sa nu fi fost inca lansat oficial ca produs separat pana la data cercetarii.

## Intrebari deschise

1. Reprezentarea jucatorului pe malul raului va folosi un avatar Roblox standard (R15) sau un
   sprite 2D complet custom fara legatura cu sistemul de avatar? Raspunsul decide direct
   eligibilitatea pentru rata DevEx premium 18+ US.
2. Are sens sa se testeze Server Authority in Studio pe un prototip mic (chiar daca Driftwood
   foloseste AABB custom), doar ca sa se vada daca engine-ul ofera vreun beneficiu masurabil
   pentru validarea miscarii jucatorului pe server?
3. Va avea Driftwood vreodata chat text intre jucatori (in afara de "donatii la atelier" si
   evenimente de server)? Daca da, trebuie planificat costul de compliance al Age Check to Chat
   (verificare de varsta, categorii de brackets) din faza de design, nu adaugat ulterior.
4. Merita migrarea timpurie catre UI Styling API, sau echipa (un singur developer nou pe Roblox)
   are nevoie mai intai sa invete Frame/UDim2 "clasic" inainte sa adauge un strat de abstractizare
   suplimentar? (Compromis intre viteza de invatare si evitarea refactorului ulterior.)
5. Care e volumul real de obiecte simultane pe server (rau + inventar + atelier comun) la care
   Parallel Luau/Actors ar aduce beneficii masurabile? Necesita profiling, nu decizie a priori.
6. Va folosi Driftwood Open Cloud (Luau Execution API, Experience Notifications) suficient de
   devreme incat sa merite configurarea unui API key/scopes de Open Cloud in etapa de prototip,
   sau se amana pana la etapa de monetizare (pasul 6 din ordinea de lucru din CLAUDE.md)?
7. Dupa RDC 2026 (10-12 septembrie 2026): a schimbat ceva planul anuntat pentru Managed Pricing,
   Server Authority sau UI Styling? Necesita o trecere rapida peste recap dupa eveniment.

## Surse

- devforum.roblox.com, "RDC25: What we announced", 2025-09-05 —
  https://devforum.roblox.com/t/rdc25-what-we-announced/3920245
- devforum.roblox.com, "Creator Roadmap 2025: RDC Update", 2025-09-26 —
  https://devforum.roblox.com/t/creator-roadmap-2025-rdc-update/3961527
- devforum.roblox.com, "Creator Roadmap: 2025 End of Year Recap", 2025-12-16 —
  https://devforum.roblox.com/t/creator-roadmap-2025-end-of-year-recap/4156739
- devforum.roblox.com, "Creator Roadmap 2026: Spring Update", 2026-05-08 —
  https://devforum.roblox.com/t/creator-roadmap-2026-spring-update/4625473
- devforum.roblox.com, "Save the Date: RDC26", 2026-04-03 —
  https://devforum.roblox.com/t/save-the-date-rdc26/4556064
- devforum.roblox.com, "Increasing DevEx — Creators Will Now Earn 8.5% More", 2025-09-05 —
  https://devforum.roblox.com/t/increasing-devex-creators-will-now-earn-85-more/3920159
- devforum.roblox.com, "Introducing the US 18+ DevEx Rate: Earn 42% More on Spend from 18+ US
  Players", 2026-04-30 —
  https://devforum.roblox.com/t/introducing-the-us-18-devex-rate-earn-42-more-on-spend-from-18-us-players/4607091
- create.roblox.com/docs, "Developer Exchange (DevEx)", pagina curenta, verificata 2026-09-08 —
  https://create.roblox.com/docs/production/monetization/developer-exchange
- devforum.roblox.com, "Introducing Creator Rewards: Earn More by Growing the Community",
  2025-06-24 —
  https://devforum.roblox.com/t/introducing-creator-rewards-earn-more-by-growing-the-community/3777628
- devforum.roblox.com, "Creator Rewards is Live", 2025-07-24 —
  https://devforum.roblox.com/t/creator-rewards-is-live/3838257
- devforum.roblox.com, "Managed Pricing: One System for Better Pricing and Earnings Growth",
  2026-06-15 —
  https://devforum.roblox.com/t/managed-pricing-one-system-for-better-pricing-and-earnings-growth/4684738
- devforum.roblox.com, "[Full Release] UI Styling is officially released!", 2026-01-20 —
  https://devforum.roblox.com/t/full-release-ui-styling-is-officially-released/4275082
- devforum.roblox.com, "[Studio Beta] Introducing UI Styling!", 2025-05-22 —
  https://devforum.roblox.com/t/studio-beta-introducing-ui-styling/3660722
- devforum.roblox.com, "[Client Beta] You can now publish Styles in your experience!",
  2025-08-26 —
  https://devforum.roblox.com/t/client-beta-you-can-now-publish-styles-in-your-experience/3901480
- devforum.roblox.com, "[Full Release] StyleQuery + More Styling Features!", 2026-04-09 —
  https://devforum.roblox.com/t/full-release-stylequery-more-styling-features/4566519
- devforum.roblox.com, "[Full Release] Styling Transitions", 2026-05-21 —
  https://devforum.roblox.com/t/full-release-styling-transitions/4646870
- create.roblox.com/docs, "UIDragDetector" (referinta clasa), verificata 2026-09-08 —
  https://create.roblox.com/docs/reference/engine/classes/UIDragDetector
- create.roblox.com/docs, "EditableImage" (referinta clasa), verificata 2026-09-08 —
  https://create.roblox.com/docs/reference/engine/classes/EditableImage
- create.roblox.com/docs, "EditableMesh" (referinta clasa), verificata 2026-09-08 —
  https://create.roblox.com/docs/reference/engine/classes/EditableMesh
- devforum.roblox.com, "[Studio Beta] Major updates to in-experience Mesh & Image APIs",
  2024-10-23 (actualizat 2024-11-20) —
  https://devforum.roblox.com/t/studio-beta-major-updates-to-in-experience-mesh-image-apis/3225681
- devforum.roblox.com, "[Full Release] Introducing CreateDataModelContent...", 2026-03-27
  (actualizat 2026-05-18) —
  https://devforum.roblox.com/t/full-release-introducing-createdatamodelcontent-convert-editable-mesh-and-image-data-into-static-content/4541898
- create.roblox.com/docs, "Multithreading (Parallel Luau)", verificata 2026-09-08 —
  https://create.roblox.com/docs/scripting/multithreading
- create.roblox.com/docs, "Experience Notifications", verificata 2026-09-08 —
  https://create.roblox.com/docs/production/promotion/experience-notifications
- devforum.roblox.com, "Update on Legacy Chat Deprecation and TextChatService Migration",
  2025-01-13 —
  https://devforum.roblox.com/t/update-on-legacy-chat-deprecation-and-textchatservice-migration/3376880
- devforum.roblox.com, "Age Checks to Access Chat, Studio Team Create, and Links on Roblox",
  2025-11-18 —
  https://devforum.roblox.com/t/age-checks-to-access-chat-studio-team-create-and-links-on-roblox/4079702
- devforum.roblox.com, "Age Check Requirement to Chat Now Live Globally", 2026-01-07 —
  https://devforum.roblox.com/t/age-check-requirement-to-chat-now-live-globally/4226101
- devforum.roblox.com, "An Update on Our Age Check to Chat Fast Follow Roadmap", 2026-01-23 —
  https://devforum.roblox.com/t/an-update-on-our-age-check-to-chat-fast-follow-roadmap/4288168
- devforum.roblox.com, "March 26, 2026: An Update on our Age Check to Chat Fast-Follow Roadmap",
  2026-03-26 —
  https://devforum.roblox.com/t/march-26-2026-an-update-on-our-age-check-to-chat-fast-follow-roadmap/4539685
- devforum.roblox.com, "Friends Are Back: Expanding Trusted Friends for a New Way to Chat and
  Play", 2026-04-02 —
  https://devforum.roblox.com/t/friends-are-back-expanding-trusted-friends-for-a-new-way-to-chat-and-play/4554217
- devforum.roblox.com, "Introducing Trusted Connections & Privacy Tools", 2025-07-17 —
  https://devforum.roblox.com/t/introducing-trusted-connections-privacy-tools/3820020
- devforum.roblox.com, "Cross-Server Chat and Chat Summaries Now Live, Plus Chat Roadmap
  Updates", 2026-05-12 —
  https://devforum.roblox.com/t/cross-server-chat-and-chat-summaries-are-now-live-plus-chat-roadmap-updates/4632665
- devforum.roblox.com, "[Studio Beta] Build Fair, Responsive Games with Server Authority",
  2025-12-09 (topic gasit prin cautare, slug indicativ) —
  https://devforum.roblox.com/t/studio-beta-build-fair-responsive-games-with-server-authority
- devforum.roblox.com, "[Client Beta] Publish & Test Your Server Authoritative Experiences",
  2026-04-30 —
  https://devforum.roblox.com/t/client-beta-publish-test-your-server-authoritative-experiences/4606949
- devforum.roblox.com, "[Full Release] Ship Fair And Competitive Games with Server Authority",
  2026-07-09 —
  https://devforum.roblox.com/t/full-release-ship-fair-and-competitive-games-with-server-authority/4727993
- devforum.roblox.com, "[Beta] Open Cloud Engine API for Executing Luau", 2024-09-25 (activ pana
  in 2026-05) — https://devforum.roblox.com/t/beta-open-cloud-engine-api-for-executing-luau/3172185
- devforum.roblox.com, "[Beta] Cube 3D Generation Tools and APIs for Creators", 2025-03-20 —
  https://devforum.roblox.com/t/beta-cube-3d-generation-tools-and-apis-for-creators/3558947
- devforum.roblox.com, "[Beta] 4D Generation: Unlock New Types of Gameplay", 2026-02-04 —
  https://devforum.roblox.com/t/beta-4d-generation-unlock-new-types-of-gameplay/4331818
- devforum.roblox.com, "Customize your GUIs with builder icons", 2025-09-30 —
  https://devforum.roblox.com/t/customize-your-guis-with-builder-icons/3968755
- devforum.roblox.com, "[Client Beta] Acoustic Simulation: Emit audio with presence!",
  2026-01-28 (data dedusa din rezultat de cautare, de reverificat) —
  https://devforum.roblox.com/t/client-beta-acoustic-simulation-emit-audio-with-presence
- devforum.roblox.com, "Weekly Recap: July 6-10, 2026", 2026-07-10 —
  https://devforum.roblox.com/t/weekly-recap-july-6-10-33-more-games-entering-kids-select/4730771
- Fisier local: CLAUDE.md (brieful proiectului) — context de proiect Driftwood, citit
  2026-09-08 (sursa interna, nu web).

## Verificare independenta (2026-09-08)

Verificare facuta de un agent separat, prin fetch direct pe paginile primare (nu doar pe baza
citatelor din research-ul original). 16 afirmatii-cheie re-verificate, minimum 16 fetch-uri pe
create.roblox.com/docs si devforum.roblox.com.

| Afirmatie | Verdict | Valoare corecta | Sursa (URL, data) |
|---|---|---|---|
| DevEx rata standard: $0.0035 -> $0.0038/Robux (+8.5%), din 5 sept. 2025, ora 10:00 PT | CONFIRMAT | Neschimbat | devforum.roblox.com/t/increasing-devex-creators-will-now-earn-85-more/3920159 (verificat 2026-09-08) |
| DevEx minim cash-out: 30.000 Robux castigati, o cerere/luna calendaristica | CONFIRMAT | Neschimbat | create.roblox.com/docs/production/monetization/developer-exchange (verificat 2026-09-08) |
| DevEx rata premium 18+ US: $0.0054/Robux (+42%), din 8 iunie 2026, doar game passes/developer products/subscriptii/private servers, criterii avatar (R15, rig uman 15+ articulatii, rig non-uman, sau fara personaj vizibil) | CONFIRMAT | Neschimbat | devforum.roblox.com/t/introducing-the-us-18-devex-rate-earn-42-more-on-spend-from-18-us-players/4607091 (verificat 2026-09-08) |
| Creator Rewards — Daily Engagement: 5 Robux/Active Spender ($9.99+ cheltuiti in 60 zile), 10+ min/zi, doar primele 3 experiente lansate de user in ziua respectiva | CONFIRMAT | Neschimbat | devforum.roblox.com/t/introducing-creator-rewards-earn-more-by-growing-the-community/3777628 (verificat 2026-09-08) |
| Creator Rewards — Audience Expansion: 35% revenue-share din primii $100 Robux, user nou/inactiv 60+ zile, DAU mediu 100 in 60 zile retinere; program live 24 iulie 2025 | CONFIRMAT | Neschimbat | devforum.roblox.com/t/creator-rewards-is-live/3838257 (verificat 2026-09-08) |
| UI Styling API (StyleSheet/StyleRule/StyleLink/StyleDerive) — Full Release pe 20 ianuarie 2026 | CONFIRMAT | Neschimbat | devforum.roblox.com/t/full-release-ui-styling-is-officially-released/4275082 (verificat 2026-09-08, postat 2026-01-20) |
| StyleQuery — Full Release pe 9 aprilie 2026 | CORECTAT (corectat la verificare) | Full Release pe **11 mai 2026**; 9 aprilie 2026 e data postarii initiale a topicului (continut de etapa anterioara), iar statusul de Full Release a fost confirmat printr-o editare ulterioara, reflectata si in Weekly Recap 11-15 mai 2026 | devforum.roblox.com/t/full-release-stylequery-more-styling-features/4566519 + devforum.roblox.com/t/weekly-recap-may-11-to-may-15-2026/4638298 (verificat 2026-09-08) |
| Tranzitii de stil (Styling Transitions) — Full Release pe 21 mai 2026 | CORECTAT (corectat la verificare) | Full Release pe **27 iulie 2026**; 21 mai 2026 e data postarii initiale, care anunta doar Studio Beta ("Styling Transitions are now available in Studio Beta!"); anuntul de Full Release a fost adaugat prin editare pe 27 iulie 2026 | devforum.roblox.com/t/full-release-styling-transitions/4646870 (verificat 2026-09-08) |
| `AssetService:CreateDataModelContentAsync` — Full Release pe 27 martie 2026, actualizat 18 mai 2026 | CORECTAT (corectat la verificare) | Full Release efectiv pe **18 mai 2026**; 27 martie 2026 e data postarii initiale, care anunta doar "available as a Studio beta" — disponibilitatea in experiente publicate a fost confirmata abia prin update-ul din 18 mai 2026 | devforum.roblox.com/t/full-release-introducing-createdatamodelcontent-convert-editable-mesh-and-image-data-into-static-content/4541898 (verificat 2026-09-08) |
| Legacy Chat: deadline dur 30 aprilie 2025, migrare obligatorie la `TextChatService` | CONFIRMAT | Neschimbat | devforum.roblox.com/t/update-on-legacy-chat-deprecation-and-textchatservice-migration/3376880 (verificat 2026-09-08) |
| Age Check to Chat: live global din 9 ianuarie 2026; categorii sub 9, 9-12, 13-15, 16+; verificare prin Persona (facial) sau act de identitate, fara pastrare de imagini | CONFIRMAT | Neschimbat | devforum.roblox.com/t/age-check-requirement-to-chat-now-live-globally/4226101 (verificat 2026-09-08) |
| Managed Pricing: lansat 15 iunie 2026, unifica Regional Pricing + Price Optimization; +4-10% cheltuiala Robux, ~4% castiguri medii, Slap Battles +15%; teste la minim 90 zile, preaviz 7 zile | CONFIRMAT | Neschimbat (sursa mentioneaza si date suplimentare neincluse in research: +1-6% jucatori/playtime, +43-52% pass purchases in regiuni cu discount) | devforum.roblox.com/t/managed-pricing-one-system-for-better-pricing-and-earnings-growth/4684738 (verificat 2026-09-08) |
| Server Authority: Full Release pe 9 iulie 2026; documentatia nu confirma aplicabilitate la coliziuni 2D custom fara Humanoid | CONFIRMAT | Neschimbat — sursa vorbeste explicit doar despre "character movement, vehicles, and sports" cu avataruri implicite/fizica simpla, fara mentiune de 2D custom | devforum.roblox.com/t/full-release-ship-fair-and-competitive-games-with-server-authority/4727993 (verificat 2026-09-08) |
| Experience Notifications: 99 caractere/notificare, 200 bytes launch data, 1 notificare/user/zi/experienta, minim 100 vizite eligibilitate | CONFIRMAT | Neschimbat | create.roblox.com/docs/production/promotion/experience-notifications (verificat 2026-09-08) |
| Open Cloud Luau Execution API: lansat Beta 25 sept. 2024, inca in Beta la data cercetarii (fara anunt de Full Release) | CONFIRMAT (cu rezerva) | Neschimbat ca status declarat — titlul topicului oficial ramane "[Beta] Open Cloud Engine API for Executing Luau" si nu exista topic separat de "Full Release"; NOTA: pagina de referinta API (create.roblox.com/docs/cloud/reference/features/luau-execution) marcheaza endpoint-urile ca "Stable", ceea ce pare sa indice stabilitatea contractului API (versionare), nu neaparat statusul de maturitate a produsului (Beta/GA) — ambiguitate nerezolvata complet | devforum.roblox.com/t/beta-open-cloud-engine-api-for-executing-luau/3172185 + create.roblox.com/docs/cloud/reference/features/luau-execution (verificat 2026-09-08) |
| RDC 2026: 10-12 septembrie 2026, San Jose | CONFIRMAT | Neschimbat | devforum.roblox.com/t/save-the-date-rdc26/4556064 (verificat 2026-09-08) |

**Observatie sistemica pentru research-uri viitoare pe devforum.roblox.com:** cel putin 3 din cele
16 afirmatii verificate au avut aceeasi eroare — research-ul original a citat **data postarii
initiale a unui topic** (care descria adesea doar un stadiu "Studio Beta" sau o etapa anterioara)
ca fiind data de "Full Release", desi devforum permite editarea in acelasi topic (acelasi URL/ID)
cand statusul avanseaza, cu titlul schimbat (ex. `[Studio Beta] X` devine `[Full Release] X`) fara
sa schimbe data primului mesaj afisata implicit. Data reala de Full Release trebuie cautata in
textul de "Update"/"Edit" din interiorul postarii sau confirmata printr-un Weekly Recap separat, nu
doar prin data initiala a topicului.
