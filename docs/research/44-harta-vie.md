# Harta vie: ancorarea obiectelor si plasament cu logica

Scrisa 2026-09-14 de un agent de cercetare (Sonnet), pentru dezbaterea despre harta ceruta de owner. Citatele din
Slynyrd *Pixelblog 21* si din *The Level Design Book* (capitolul Flow) au fost redeschise si confirmate cuvant cu
cuvant; restul surselor au nivelul de incredere scris langa ele. Machetele dezbaterii ("asezat pe pamant" si "satul
pe flux") au fost trimise owner-ului in conversatie, nu sunt in repo.

Raspunde la doua plangeri verbatim ale owner-ului: obiectele "plutesc", plasamentul "pare random si
fara cap". Nu repet umbrele de contact in general, faza aleatoare la leganat, particulele pool-uite,
vinieta, parallax-ul sau UIShadow/UIGradient — deja in `docs/research/40-world-life.md` si
`docs/research-survival/art-depth-2d.md`. Aici: ancorarea exacta la sol si principii de plasament din
tycoon/farm/city-builder, cu exemple concrete.

## Rezumat

- Plutirea vine din patru lipsuri simultane, nu una: fara umbra de contact **pictata in sprite**,
  fara fundatie/curte sub cladire, fara recuzita suprapusa peste baza, directie de lumina
  inconsistenta intre obiecte (Slynyrd Pixelblog 21/6, Saint11/Medeiros — incredere ridicata, consens
  de breasla).
- Eastward (Pixpil) confirma nevoia de ceva **in fata** cladirii, suprapus peste baza — straturi +
  verticalitate ca prim-planul sa nu lase fundalul plat; noi n-avem motorul lor 3D, dar principiul de
  compozitie se transfera fara cod nou (gamedeveloper.com, interviu — incredere medie).
- Foundation (city-builder) trateaza acoperisul ca element dominant din camera de sus si materialul
  bazei ca ancora tematica — fiecare cladire ar trebui sa stea pe o "curte" de material propriu, nu pe
  iarba goala (gamedeveloper.com — incredere medie).
- Plasamentul "cu cap" vine din **lizibilitatea fluxului**: Idle Miner Tycoon (flux vertical, gatuire
  vizibila ca forma), Township/Hay Day (zone pe functie, materialul potecii marcheaza zona),
  tycoon-urile Roblox (dropper→conveior→collector ca o banda continua) — toate fac ochiul sa urmareasca
  marfa, nu cladirile (surse mixte — incredere medie).
- Kevin Lynch (*The Image of the City*, 1960) — paths/edges/districts/nodes/landmarks — se aplica
  direct: Driftycoon are deja paths si nodes, dar ii lipsesc districts vizibile (curtea de lemn vs.
  fier) si edges clare (marginea platoului) — sinteza din surse secundare, incredere medie.
- "Desire paths" (carari formate de mersul real, nu trasate cu rigla) explica direct "par random
  plasate": un drum care nu urmeaza traseul real al oamenilor citeste ca decor arbitrar, chiar daca e
  corect geometric (Wikipedia — incredere medie-ridicata, fapt consacrat).
- Spatiul gol conteaza la fel de mult ca obiectele: un talk GDC dedicat exact acestui subiect trateaza
  golul ca instrument de atentie — relevant pentru "aglomerat si fara cap" (GDC Vault, titlu
  confirmat, continut nefetch-uit — incredere medie).
- Un reper/landmark central (taverna, unde converg ambele lanturi) ajuta orientarea fara harta —
  cartografia foloseste explicit simbol marit pentru reperul principal; principiul se transfera direct
  (maplibrary.org — incredere medie).
- Viata dincolo de ce exista deja: fum de horn pe colibe, spuma la stalpii plasei, pasari care
  reactioneaza la apropiere, piese mecanice vizibile pe cladirile active — completeaza, nu repeta,
  `40-world-life.md`.
- Nu exista cifra oficiala "cate particule simultan e sigur pe mobil" nici la sursele externe —
  confirma, nu contrazice, concluzia interna (ordinul zecilor, nu sutelor).

## A. De ce plutesc obiectele si cum se aseaza

**Patru cauze tehnice, nu una.** Slynyrd (Pixelblog 21 — *Top Down Objects*, accesat 14.09.2026,
incredere ridicata — autor de referinta in pixel art top-down) e explicit: *"Cast shadows help make
objects feel like they actually connect with the ground."* Da doua variante: umbra **pictata direct
in sprite** (cand incape in cadru, ex. copacii) sau pe **strat separat** (un sprite de baza + mai multe
umbre, cate una per tip de sol), scurte, fara proiectie lunga, ca sa nu intre in conflict cu tile-urile
vecine. Pentru obiectele facute de om insista pe **consistenta perspectivei**: toate trebuie sa
respecte aceeasi regula de proiectie, altfel "plutirea" vine din faptul ca fiecare obiect pare desenat
cu alt unghi, nu doar din umbra.

Pixelblog 6 (*Light and Shadow*, accesat 14.09.2026, incredere ridicata) adauga a doua cauza: **o
singura directie de lumina, stabilita o data, respectata peste tot** — *"A light source should be
established at the very start of any illustration. This will dictate the flow of shadows."* Autorul
prefera lumina diagonala din stanga-sus sau dreapta-sus. Daca azi fiecare din cele 130 de obiecte din
`WorldDecor` a fost desenat separat, probabil nu au aceeasi directie de umbra — ochiul simte
inconsecventa chiar fara s-o poata numi.

Saint11/Pedro Medeiros (via Lospec, accesat 14.09.2026, incredere medie — sursa respectata, continut
agregat) distinge trei componente pentru bazele obiectelor: **umbra proprie**, **terminatorul**
(tranzitia, taiata clar in pixel art, nu gradient) si **lumina reflectata** (o dunga usor mai deschisa
chiar la baza obiectului, din lumina care sare din sol) — explica de ce o umbra de contact 100% neagra
arata nefiresc.

**A treia cauza: nimic nu ancoreaza baza.** Eastward/Pixpil (interviu Tommo Zhou, gamedeveloper.com,
accesat 14.09.2026, incredere medie) descrie cum impart fiecare obiect pe straturi ("separate a
building rooftop and the wall into two layers") si mizeaza pe verticalitate ca prim-planul sa nu lase
fundalul plat. Driftycoon n-are motorul lor de lumina 3D, dar principiul de compozitie se transfera
fara cod nou: **ceva trebuie sa se suprapuna peste marginea de jos a fiecarei cladiri** — gard,
gramada, butoi cu ZIndex peste baza. Un sprite cu nimic in fata sau langa el, pe iarba goala, citeste
ca decupat si lipit, indiferent cat de buna e umbra lui.

Foundation, city-builder cu plasare libera, confirma a patra cauza (interviu Olivier Latouche,
gamedeveloper.com, accesat 14.09.2026, incredere medie): din camera de sus, **acoperisul e elementul
dominant**, iar **materialul bazei ancoreaza tematic cladirea de zona din jur** (dale de piatra
albastra sub manastire, legate de restul incintei). Tradus la Driftycoon: fiecare cladire ar trebui sa
stea pe o "curte" proprie — pamant batut la gater, scanduri la depozit, piatra la taverna — mai lata
decat cladirea insasi.

**Tranzitii de teren** (Slynyrd Pixelblog 20; conventie generala din pachete de tile-uri pixel art,
incredere medie): marginea iarba-pamant se trateaza ca o "patura" — iarba atarna peste marginea
drumului 2-4px, nu se taie drept; drumul se deseneaza din forme neregulate de piatra/pietris, nu
dreptunghi plat; coltarile/jonctiunile au tile-uri dedicate. Drumul din CLAUDE.md ("dreptunghiuri plate
de pamant") e exact simptomul de "desenat cu rigla", nu de "calcat".

## B. Plasament cu cap

**Fluxul trebuie citibil dintr-o privire, nu doar corect economic.** Idle Miner Tycoon aseaza cele
trei verigi (mina → lift → depozit) vertical, iar gatuirea e vizibila direct din forma: *"if only one
of these three components is lacking in throughput, the amount of money that reaches the Warehouse is
limited"* (idleminertycoon.fandom.com, accesat 14.09.2026 prin cautare — fetch direct blocat HTTP 402,
incredere medie, wiki comunitar). E exact principiul "veriga cea mai slaba" din D46/D49 — dar acolo
**se vede in forma**, nu doar in cifre; la Driftycoon lantul exista azi in cod (`ChainMath`), nu
neaparat in felul cum sunt asezate cladirile pe platou.

Tycoon-urile Roblox rezolva asta literal, cu banda vizibila: dropper → conveior → collector, desenate
ca o linie continua, cu zone marcate clar (creation.dev, buzzy.gg, accesat 14.09.2026, incredere medie
— ghiduri de tutorial, nu documentatie oficiala). Ideea transferabila: **marfa ar trebui sa aiba un
traseu fizic vizibil** de la un capat la altul al platoului, nu cladiri imprastiate care doar "stiu"
unele de altele prin cod.

Township si Hay Day (ghiduri de comunitate, accesat 14.09.2026, incredere medie-scazuta, nu declaratii
oficiale Supercell) converg pe: **zone separate pe functie**, delimitate cu garduri/vegetatie,
**cladiri de productie langa sursa lor de materie prima** ("laptaria langa grajdul de vaci"),
**materialul potecii marcheaza zona** (piatra industrial, pamant natural). Aplicat direct: lantul de
lemn (plasa → depozit → gater → taverna) si cel de fier (plasa de fier vechi → Scrap Shed → forja →
taverna) ar trebui sa fie **doua curti vizual distincte**, nu amestecate, cu taverna drept punct comun
unde se vad amandoua ajungand.

Factorio/Satisfactory (ghiduri de comunitate, accesat 14.09.2026, incredere medie, nu oficiale) numesc
evolutia "spaghete → magistrala → blocuri modulare": spaghete (inghesuit, fara ordine) e primul
instinct si cel mai greu de citit; o magistrala (flux clar, o directie dominanta) e mai lenta de
construit dar mult mai lizibila. Verdictul owner-ului suna exact ca un "spaghete" din greseala, nu din
alegere.

Cadrul lui Kevin Lynch, *The Image of the City* (1960) — **paths, edges, districts, nodes,
landmarks** — se citeaza des in design de nivel (architecturecourses.org, accesat 14.09.2026, incredere
medie — sinteza secundara; pagina ArtStation cea mai relevanta a picat cu HTTP 403). Aplicat la
Driftycoon:

- **Paths** — drumurile hard-codate deja exista (`TycoonConfig.ROADS`).
- **Nodes** — debarcader, gater, taverna: deja exista ca statii.
- **Districts** — lipsesc: curtea de lemn si cea de fier ar trebui sa citeasca vizual ca zone diferite.
- **Edges** — lipsesc: fara granita clara (gard/copaci/apa), ochiul nu stie unde "se termina" lumea
  jucabila, si tot ce e pe ea pare plutitor la nivel de compozitie, nu doar de sprite individual.
- **Landmark** — taverna (unde converg ambele lanturi): ar trebui sa fie cea mai mare/detaliata/
  saturata cladire.

"Desire paths" (Wikipedia, accesat 14.09.2026, incredere medie-ridicata, fapt consacrat, folosit si in
planificare urbana — Finlanda paveaza cararile facute in zapada in loc sa impuna un grid) explica
direct "par foarte random plasate": un drum care nu urmeaza traseul real al oamenilor (azi
`HandRoutes` calculeaza acest traseu) citeste ca decor arbitrar, chiar daca e "corect" geometric.
Recomandare: arta drumului ar trebui derivata din/aliniata la traseele reale din `HandRoutes`.

*Book of Level Design*, capitolul *Flow* (accesat 14.09.2026, incredere medie — referinta in
comunitatea de level design, nu peer-reviewed): *"Designing with circulation can help support a
level's storytelling and wayfinding... allowing players to read and predict patterns based on their
general knowledge."* Tradus: daca regula "materia prima in amonte, produsul finit in aval, spre
taverna" e respectata consecvent, jucatorul poate ghici unde apare urmatoarea cladire inainte s-o
cumpere — asta inseamna "cu cap".

Un talk GDC dedicat spatiului gol (*"The Importance of Nothing: Using Negative Space in Level
Design"*, accesat 14.09.2026 — titlu confirmat prin index, incredere medie) argumenteaza ca golul
dirijeaza atentia "ca un scamator" — solutia la "fara cap" nu e umplerea platoului cu mai multe
obiecte, ci spatiu gol intentionat intre cele doua curti, ca fiecare sa citeasca drept loc distinct.

## C. Viata

Completeaza, nu repeta, `40-world-life.md` (acolo: idle variat, replici, WorkSpark, jucator cu
carry/cheer, varietate lane 1, barci, umbra de nor, tufe leganate, praf de pasi, fum/foc pe cladiri
fierbinti, clopot, insecte, sclipiri pe apa, flourish la angajare):

- **Fum de horn pe colibe** (al doilea sprite de fum, mai subtire/alb decat cel de la forja, ciclu
  lent) — semnaleaza "aici locuieste cineva", diferit de fumul industrial deja planificat.
- **Rufe la uscat langa colibe** — static sau cu balans minim (faza aleatoare deja folosita la tufe) —
  semn de gospodarie, nu de santier.
- **Spuma/valuri mici la stalpii plasei** unde apa se rupe de obstacol — pool de `ImageLabel` deja
  existent, doar mutat la stalp.
- **Pasari care se ridica la apropierea jucatorului** — difera de "insecte ratacind": reactie directa
  la jucator, motiv recurent in jocuri "cozy" cu diorame pline de detaliu (presa de gen, accesat
  14.09.2026, incredere scazuta-medie — conventie observata, nu studiu tehnic).
- **Piese mecanice vizibile pe cladirile active** (roata/paleta care se-nvarte cat gaterul proceseaza)
  — semnaleaza "cladirea lucreaza acum", extensie a ideii deja acceptate de `WorkSpark`.
- **Geam luminat/felinar static, cald, la baza** colibelor sau tavernei — interior locuit, fara sistem
  de zi/noapte (nu exista azi, D54 a tratat doar sunetul); un dreptunghi cald, mic, fix, e suficient.

**Buget de performanta pe mobil.** Nicio sursa externa (starloopstudios.com, gamedeveloper.com,
accesat 14.09.2026, incredere medie — practica generala din VFX mobil, nu specifica Roblox/ScreenGui)
nu da o cifra universala — toate recomanda doar calitativ: numar redus, pooling, spawn controlat. Asta
**confirma**, nu contrazice, concluzia interna: fara benchmark oficial Roblox pentru `ImageLabel`,
ramane prudent "ordinul zecilor, nu sutelor" simultan pe mobil.

## Ce se aplica la Driftycoon

| Tehnica | Ce vede jucatorul | Cost | Arta/cod |
|---|---|---|---|
| Umbra de contact pictata, la baza fiecarui obiect din `WorldDecor` | obiectul atinge iarba, nu mai pluteste | mic per obiect, ~130 de reparat | arta |
| Curte/fundatie sub fiecare cladire, mai lata decat cladirea | cladirea sta "pe ceva" anume | mediu | arta |
| Iarba suprapusa 2-4px peste marginea fundatiei/drumului | linia de contact nu mai e taiata drept | mic | arta |
| Recuzita partial suprapusa peste baza cladirii, ZIndex peste sprite | cladirea pare folosita, nu depusa | mediu | arta + ZIndex |
| Directie de lumina unica, verificata pe tot ce exista azi | scena arata ca un singur loc | mare o data, mic apoi | pipeline arta |
| Tranzitie iarba-drum neregulata (zimtata, pietre/smocuri) | drumul pare calcat, nu desenat cu rigla | mediu | arta |
| Cele doua curti (lemn/fier) separate spatial, cu gol intre ele | jucatorul citeste lanturile dintr-o privire | mediu | arta + `TycoonConfig` |
| Drumuri aliniate la traseul real din `HandRoutes` | drumul pare facut de pasi, nu decor peste harta | mic-mediu | cod + arta |
| Taverna ca reper central — cea mai mare/saturata cladire | ochiul gaseste instant unde "se termina" lantul | mic | arta |
| Gard/copaci/apa la marginea platoului | limita lumii jucabile e clara | mic-mediu | arta |
| Fum de horn + rufe la colibe | se vede ca cineva locuieste acolo | mic (reuse `AddSmoke`) | arta + cod minor |
| Piesa mecanica vizibila pe cladirea activa | cladirea "lucreaza", nu doar asteapta | mediu | arta + tween |
| Spuma la stalpii plasei | apa pare ca impinge ceva real | mic (pool existent) | cod |

## NEVERIFICAT si riscuri

- Idle Miner Tycoon: pagina fandom nefetch-uibila direct (HTTP 402); descrierea vine doar din
  rezultatul de cautare.
- Township/Hay Day/Factorio/Satisfactory: ghiduri de jucatori/SEO, nu declaratii oficiale ale
  studiourilor.
- Kevin Lynch aplicat la jocuri: sinteza din articole secundare; pagina ArtStation cea mai relevanta a
  picat cu HTTP 403.
- "Recuzita ancoreaza cladirea" e consens de breasla din pachete de asset-uri, nu o sursa primara
  unica.
- Talk-ul GDC despre spatiul negativ confirmat doar ca titlu pe GDC Vault, continutul complet posibil
  blocat.
- Nicio sursa nu da o cifra exacta de particule sigure pe mobil pentru `ImageLabel` — ramane de testat
  direct in Studio.
- Eastward: tehnicile de straturi/verticalitate sunt gandite pentru motorul lor 3D-peste-2D — la
  Driftycoon doar principiul de compozitie e transferabil.
- Pasarile/diorame "cozy": observatie de gen din presa, nu studiu de design citat direct.

## Surse

Toate accesate 14.09.2026.

- Slynyrd, *Pixelblog 21 — Top Down Objects* — https://www.slynyrd.com/blog/2019/9/18/pixelblog-21-top-down-objects
- Slynyrd, *Pixelblog 6 — Light and Shadow* — https://www.slynyrd.com/blog/2018/6/15/pixelblog-6-light-and-shadow
- Slynyrd, *Pixelblog 20 — Top Down Tiles* (tranzitii de teren) — https://www.slynyrd.com/blog/2019/8/27/pixelblog-20-top-down-tiles
- Pedro Medeiros (Saint11), tutoriale iluminare, via Lospec — https://lospec.com/pixel-art-tutorials/illumination-techniques-by-pedro-medeiros
- Game Developer, *Eastward's creators share insights on making pixel art adventures* — https://www.gamedeveloper.com/art/eastward-s-creators-share-insights-on-making-pixel-art-adventures
- Game Developer, *Deep Dive: The Art of Foundation* — https://www.gamedeveloper.com/art/deep-dive-the-art-of-i-foundation-i-
- Idle Miner Tycoon Wiki (Fandom), *Fundamental Gameplay* — https://idleminertycoon.fandom.com/wiki/Fundamental_Gameplay (fetch blocat HTTP 402, doar rezultat de cautare)
- creation.dev, *How Do You Build a Roblox Tycoon Game?* — https://www.creation.dev/templates/tycoon-template
- buzzy.gg, *How to Make a Collector (Tycoon)* — https://buzzy.gg/roblox-studio-tutorials/how-to-make-a-collector-tycoon/
- townshipcoop.com, *Township Design Ideas* — https://www.townshipcoop.com/township_design_ideas/
- Gamepur, *Best farm layouts in Hay Day* — https://www.gamepur.com/guides/best-farm-layouts-in-hay-day
- Steam Community Guide, *Principles of Industrial Design* (Factorio) — https://steamcommunity.com/sharedfiles/filedetails/?id=1416661068
- Chill Place Gaming, *Factorio Factory Layouts and Expansion Strategies* — https://chillplacegaming.com/factorio-factory-layouts/
- Steam Community Guide, *Satisfactory Base-layout Guide* — https://steamcommunity.com/sharedfiles/filedetails/?id=2151025387
- architecturecourses.org, *Kevin Lynch's 5 Elements of a City* — https://www.architecturecourses.org/design/kevin-lynchs-5-elements-city-guide-urban-design
- Wikipedia, *Desire path* — https://en.wikipedia.org/wiki/Desire_path
- The Level Design Book, capitolul *Flow* — https://book.leveldesignbook.com/process/layout/flow
- GDC Vault, *The Importance of Nothing: Using Negative Space in Level Design* — https://gdcvault.com/play/1020169/The-Importance-of-Nothing-Using
- maplibrary.org, *Visual Hierarchy in Complex Map Designs* — https://www.maplibrary.org/1483/visual-hierarchy-in-complex-map-designs/
- starloopstudios.com, *Mobile Game VFX: Techniques for Optimizing Performance and Visuals* — https://starloopstudios.com/mobile-game-vfx-techniques-for-optimizing-performance-and-visuals/
- Game Developer, *Tutorial: Simple, High-Performance Particles for Mobile* — https://www.gamedeveloper.com/production/tutorial-simple-high-performance-particles-for-mobile

Cercetare interna, doar referita, nu repetata: `docs/research/40-world-life.md`,
`docs/research-survival/art-depth-2d.md`.
