# Driftwood — Registrul deciziilor de arhitectură și design

Data: 2026-09-09. Bazat pe cele 37 de note din `docs/research/` (fiecare decizie citează nota-sursă).

Statusuri:
- **DECIS** — ferm; se schimbă doar cu motiv nou.
- **PROVIZORIU** — direcție aleasă, dar confirmarea vine dintr-un test în Studio sau de la Roblox.
- **DE DECIS** — rămâne la owner; e listat ce informație lipsește.

Convenție: în tot proiectul, „server" înseamnă o instanță Roblox efemeră; „oraș" înseamnă entitatea persistentă din DataStore (vezi D10). Nu se mai folosește „server" cu sensul de „oraș".

---

## D53 — Ruinele malului, bușteni care vin pe râu, atelierul nou
**DECIS** (2026-09-13) — owner-ul, după D52: *„în locul acestor chestii cu negru care urmează a fi
deblocate, să fie de fapt niște ruine sau lucruri stricate pe jos (dacă te duci la ele trebuie să scrie că
se deblochează înainte X ca să poți aici)"*, *„ar trebui făcut ceva cu animația de prindere a
driftwood-ului pentru că apar așa de nicăieri, ceva mai realistic din punct de vedere al logicii"*,
*„change the texture to the workshop, looks awful"*. Alese de owner: **toate ruinele, de la început**;
**avizier „Help wanted"** pentru Porter, Sawyer și Hauler (pe oameni îi angajezi, nu îi reconstruiești).

1. **Ceasul plasei nu se mai oprește când e plină.** `TycoonMath.netTick` decide un tick: cu loc, prinde
   câte momente au trecut (cel mult cât încape); plină, ceasul sare la primul moment de după acum, la
   fiecare tick. Golirea — de mână sau de Collector — nu mai repornește ceasul la „acum + interval".
   Prinderea de după golire vine la momentul ei din ritm: cel mult un interval mai devreme decât înainte.
   Simulatorul nu modelează pauzele plaselor pline, deci prețurile rămân.
2. **Buștenii vin pe râu** (`CatchFloat`, rescris): de la marginea din stânga a lumii, cu curentul
   (130 px/s), pe **curentul de lângă plase** (`NEAR_CURRENT_Y` 552), apoi un cot lin în plasă, pe măsura
   coborârii (`clamp(1,2 × coborârea, 120, 220)` px, pantă de cel mult 51°), exact la momentul prinderii;
   apare estompat și intră micșorându-se. La o plasă plină trece pe lângă și se stinge. Cel mult 6 bușteni
   spre o plasă, la cel puțin 0,9 s unul de altul. Test: niciun drum nu trece prin altă plasă.
3. **Decorul râului** rămâne pe curentul din larg (516), mai mic (×0,35), la viteza șirului, cu bunurile
   pe care încă nu le poți prinde (resturi / cioburi, după benzile atinse); lăzile coloniei ies.
4. **Ruinele:** orice platformă a Erei 1 necumpărată stă pe mal ca ruină, pe locul exact al construcției;
   încuiată e ușor stinsă, cumpărabilă are prețul deasupra, ca siluetele de dinainte. Lângă o ruină
   încuiată (rază 120, după 0,4 s) cartonașul are un mod nou: „RUINS" / „HELP WANTED", numele, descrierea
   și butonul stins cu **prima condiție neîndeplinită** (`TycoonMath.padBlocker` + `Strings.padNeeds`:
   „Hire a Hauler first", „Cast the Fourth Net first", „Upgrade First Net to level 2 first"…) — aceleași
   condiții pe care le verifică jocul. E, butonul și atingerea ruinei spun același lucru. Cardul unui
   obiect (Take logs, Sell…) bate mereu o ruină.
5. **Avizierele:** Porter, Sawyer, Hauler au un avizier strâmb cu un anunț rupt; după angajare, avizierul
   curat cu pictograma meseriei (buștean / fierăstrău / scânduri), în locul platformei cu bifă.
   Collector-ul își păstrează coliba: ruina colibei → coliba.
6. **Atelierul nou** (`prop_workshop_e1`, 64×48, din aceeași familie cu taverna): bârne, șindrilă
   verde-cenușie, fereastra-raft cu găsirile de pe râu (una strălucește), bancul cu menghina, uneltele pe
   perete, firma cu ciocanul, hornul fierăriei. `b_workshop` din era coloniei rămâne doar cât noul nu e urcat.
7. **Arta** (10 sprite-uri, `scripts/art/ruins_d53.py`) s-a urcat după aprobarea owner-ului pe
   previzualizare (`scripts/art/preview_ruins.py`: *„urcă arta, ruinele arată bine"*), cu moderarea în
   „Reviewing" la urcare. `Assets.has` știe doar dacă id-ul e 0: cât imaginea e încă în moderare, clientul
   n-are cum să afle, deci ruina poate apărea goală o vreme, nu cu desenul de dinainte.

**Găsite pe drum și reparate:** (a) textul ghidajului de deasupra țintei stătea în lume, **sub HUD**: cu
taverna sus-stânga (când ești la gater), „Sell the planks at the tavern" cădea sub monede, traistă și
linia NEXT și nu se citea [owner, Studio] — acum stă deasupra țintei dacă e loc, altfel sub inel, altfel
deloc (textul e oricum pe linia NEXT), și nu iese din ecran (`GuideMath.labelPlacement`, testat); (b) un
cot fix de 120 px ar fi dat, pe banda de lângă mal, un plonjon de 66°; (c) fără săritul ceasului la
fiecare tick, scoaterea resetărilor ar fi adus o rafală de prinderi după o plasă lăsată plină.

**Se abate** de la D47 („se vede obiectul direct, doar ca locked" — acum ca ruină, nu ca siluetă), de la
plutirea din F1 (un singur bun, 300 px, în linie dreaptă) și de la D49 (Porter, Sawyer, Hauler fără desen).

---

## D52 — Oamenii înaintea plaselor, meniul obiectului simplu
**DECIS** (2026-09-13) — owner-ul, după ce a jucat D51: *„vreau ca playerul să facă o singură dată un tur
net – sawmill – tavern iar al doilea tur să își deblocheze treptat npc-urile. în prezent te pune să îți
faci x nets și mai apoi npc-urile, ceea ce este greșit"*, *„meniurile astea trebuie schimbate pentru că nu
prea înțeleg nimic din ele dacă închid un ochi"*. Alese de owner: toți cinci oamenii după prima vânzare,
apoi plasele (confirmat după ce i s-a arătat compromisul de la pct. 3); ghidajul tace tot după cei cinci;
meniul — varianta simplă, cu fontul din joc.

1. **Ordinea Erei 1:** prima plasă → Collector (cere o singură plasă), Porter, Sawyer, Hauler,
   **Innkeeper după Hauler** (nu la trei plase) → **a doua plasă abia după Innkeeper** (pe lângă nivelul
   2 al primei) → a treia plasă, traista mare, a patra, Atelierul, a cincea, clopotul. Indexul
   platformelor urmează ordinea cumpărărilor din simulator. Capitolul 1 are 11 quest-uri: bucla de mână,
   cei cinci oameni, nivelul 2, a doua plasă. `sell_forty` iese; Innkeeper-ul dă 3 perle, deci totalul
   quest-urilor rămâne 40.
2. **Simulatorul urmează quest-ul:** cât lipsește un om al capitolului și condiția lui e împlinită,
   jucătorul îl ia când are banii și nu cumpără nimic altceva până atunci — cu o singură plasă, un om
   adaugă zero venit, deci lăcomia singură nu l-ar lua niciodată. Prețuri re-derivate: oamenii 13 / 15 /
   18 / 20 / 25, Second Net 30, Third Net 100, Bigger Sack 90, Fourth Net 900, Workshop 7K, Fifth Net
   7,5K; al doilea om 1,1K / 1,8K / 13K / 2,8K / 4,5K. 9 cumpărături în primele 5 minute reale.
3. **Compromisul, ales de owner după ce l-a văzut explicat pe pașii tutorialului:** un om la treapta 1
   lucrează de 7–12 ori mai repede decât o plasă. Cu toți cinci angajați devreme, veriga slabă e aproape
   mereu plasele (47% din Era 1) sau adunatul (41%); gaterul, Hauler-ul și taverna sunt gâtuirea doar
   2–3% — upgrade-urile lor rar aduc ceva în Era 1. Era 1 crește de la 27 la 34 de minute reale. ~200 de
   variante de constante (costuri, viteze, baze, creșteri, munca jucătorului, oameni-ucenici) n-au ținut
   pragul de 5% la ±15%; cea mai apropiată ordine care îl ținea era „Collector + Porter întâi". Poarta
   „fiecare verigă e gâtuirea ≥5% din timp" coboară la **0,5%** (cea mai mică cotă la ±15% iese 0,7%):
   prinde doar o verigă care nu e *niciodată* gâtuirea. Restul porților neschimbate.
4. **Meniul obiectului, simplu:** nivelul („Level 3 → Level 4"), o casetă cu ce face și cât **pe minut**
   („19.8 → 20.4 logs a minute"), pragul următor, **un rând colorat din câștigul real al unui nivel**
   (câmp nou `gain` pe rândurile clădirilor): verde „Next level earns +1.2 coins a minute", sau portocaliu
   „Won't earn more yet: your nets are slower" cu butonul „Go to Nets"; x1 / x10 / Max; butonul mare cu
   prețul pe el. La meserie: treapta și oamenii, ce face omul, cine face treaba, apoi treapta și al doilea
   om, fiecare cu prețul pe buton. Ies: cele șase pastile ale lanțului, debitele pe secundă, x50 (rămâne
   pe server). Lista veche (`StationPanel`) nu se atinge.
5. **Pe minut, nu pe secundă:** +3% la 0,33/s ieșea „0.3 → 0.3 (+0.0)" — adevărat și inutil; pe minut e
   „19.8 → 20.4" (`TycoonMath.formatPerMinute`, rotunjit, nu tăiat).

**Găsite pe drum și reparate:** (a) analytics-ul numea indexul 2 „BoughtSecondNet" — după reordonare ar
fi etichetat Collector-ul; acum toate platformele sunt `BoughtPad<index>`; (b) rândul „This is your
slowest link" al meniului vechi putea sta pe o verigă la egalitate, unde un nivel dă tot zero — rândul
nou se sprijină pe câștigul calculat, iar la egalitate spune „just as slow", nu „slower".

**Se abate** de la D51 pct. 1 (bucla repetată și „Sell 40 planks" înaintea extinderii, oamenii după trei
plase), de la D49 (Innkeeper-ul la trei plase) și de la pragul de 5% al verigilor [D48, D49].

---

## D51 — Primul minut ghidat pas cu pas, cardul obiectului, sunetul plaselor, muzica
**DECIS** (2026-09-13) — owner-ul, după ce a jucat D50: *„nu îmi place cum te ghidează jocul în acel
tutorial, te împinge să îți faci net-uri cât mai multe dar fără materiale, jucătorul nu știe exact ce să
facă la început"*, *„după ce pui driftwood-ul apare instant linia ghidaj către următorul obiectiv…
trebuie să îl pună să stea până când tot driftwood-ul este gata plank"*, *„când te duci la un obiect
vreau să existe opțiunea de upgrade, nu doar de la click"*, *„nu dispare partea neagră decât după al
doilea click"*, *„când prind net-urile sunetul devine enervant"*, *„o muzică instrumentală specifică
temei, fără copyright"*. Alese de owner: muzica compusă de noi, cartea după prima vânzare, recompensele
în perle, prima colectare = plasa plină, care prima dată se umple mai repede.

1. **Bucla se face de-adevăratelea înainte de extindere.** Capitolul 1 cere o plasă plină colectată
   (12), tăiată toată și vândută toată, apoi un nivel, a doua plasă, **Sell 40 planks**, abia apoi a
   treia plasă și oamenii. Quest-urile numără **bucăți** (`Stats.collected`, `Stats.sold`), nu gesturi.
2. **Toate recompensele quest-urilor sunt perle.** Primele cinci dădeau 95 de monede, cât plasele 2 și
   3 — se cumpărau din recompense, fără ca lemnul să treacă prin lanț. Simulatorul n-a numărat niciodată
   recompensele, deci prețurile rămân; se schimbă doar ritmul real al începutului (a doua plasă pe la
   ~1:25, din vânzare).
3. **Prima plasă se umple de 3 ori mai repede** până la primii 12 bușteni colectați (~12 s, nu ~36 s),
   cu eticheta „Fast first catch" pe ea: meniul arată ritmul normal, eticheta spune de ce e mai repede.
   **Și se golește abia plină** (completat după Studio, aceeași zi: *„zice wait dar eu pot să iau și să
   fug mai departe, ar trebui să fie locked până face 12/12"*): serverul refuză colectarea, cardul scrie
   „Filling up: 8/12", E pe el spune același lucru (`TycoonMath.collectLocked`).
4. **Ghidajul pe două niveluri:** quest-ul spune ce (linia NEXT), pasul spune cum și unde, din stare, în
   ordinea în care nu sare nimic: bușteni în traistă → gater; bușteni la gater fără Sawyer → **stai în
   inel până la ultimul**; scânduri gata → le iei; scânduri în traistă → taverna; depozit → plase. Un
   quest de cumpărare **fără bani** arată bucla care face banii (sau „Coins are coming in" cât se scurge
   grămada), nu platforma.
5. **Tutorialul:** cardul capitolului → mâna la prima plasă; **cartea cu reflector vine după prima
   vânzare**, când ai ce revendica, și se închide dintr-un singur click (pasul vechi verifica lista
   deschisă abia după un click pe întuneric).
6. **Cardul obiectului:** lângă plasă, depozit, gater, tavernă, atelier sau o platformă de meserie, un
   card arată acțiunea care e cazul (sau starea) și **Upgrade**, care deschide meniul obiectului (tasta
   U; butonul apare după prima vânzare și pulsează când pasul îl cere). Ținta e cea mai apropiată —
   cartonașul de cumpărare inclus — și E face exact ce scrie pe card. Cât tai de mână, gaterul nu oferă
   scândurile: plăcuța din D50 spune „Cutting — N left".
7. **Stropii plaselor** doar la cel mult 420 px de plasa care a prins; clinchetul găsirilor rare se
   aude oricum, mai încet de departe.
8. **Muzica:** o buclă de 2:17 compusă și sintetizată de noi (`scripts/audio/make_music.py`: lăută,
   fluier de lemn, pad, contrabas, kalimba, apă; re major, 84 BPM), fără drepturi de autor ale altcuiva;
   buton în bară (tasta M), ținut minte în profil (`Settings.music`, remote `SetMusic`).

**Găsite pe drum și reparate:** (a) canalul de analytics al quest-urilor trimitea „Quest_<id>" într-un
canal unde nu exista asemenea pas — fiecare revendicare era aruncată; acum quest-urile au canalul lor, pe
capitol; (b) `Apply` al tutorialului intra în „done" la prima plasă și nu mai ieșea; (c) un buton de
muzică fără muzică urcată ar fi mințit — nu apare până nu există piesa.

**Se abate** de la D50 pct. 3 (ghidajul care arăta direct ținta quest-ului) și de la vechea ordine a
tutorialului (cartea la început).

---

## D50 — Harta în buclă, taverna, dâra de ghidaj, sunetul
**DECIS** (2026-09-13) — owner-ul, după ce a jucat D49: *„la sawmill nu prea se vede textul că trebuie
să stai aici"*, *„la tutorial vreau o săgeată care să ghideze playerul pe unde trebuie să o ia și unde
trebuie să se ducă"*, *„trebuie schimbată iar poziționarea tuturor obiectelor… devin tot mai
aglomerate"*, *„dock-ul să arate complet altfel… o tavernă în care stau degeaba niște npc-uri «ca la
piață»"*, *„sunetul sawmill-ului devine foarte enervant… predominant când se prinde driftwood-ul în
nets"*.

1. **Harta e o buclă:** plasele pe râu → depozitul la capătul de est al punții → gaterul la sud-est →
   taverna la vest, fiecare om pe drumul lui (Collector pe punte, Porter pe drumul de est, Hauler pe
   drumul de sud și pintenul de vest). Drumurile sunt `TycoonConfig.ROADS`: dreptunghiuri care doar
   se ating. Terenul Erei 1 se lărgește până la x 1860 și coboară până la y 1650; gardul Morii ține
   toată înălțimea. Grămezile au locuri fixe (`PILES`), nu formule lipite de clădire.
2. **Oamenii merg pe drumuri** (`RoadGraph` + `HandMath.cycle` cu `via`). Cât duce un om pe drum rămâne
   debit × durată, deci meniul și simulatorul nu se schimbă. Măsurat: Collector 22 s cu cinci plase
   (poarta: 30 s), Porter 7.5 s, Hauler 19.2 s.
3. **Dâra de ghidaj:** săgeți care curg pe drumuri spre țintă, plus săgeata mare (34 → 48 px) și un inel
   pe țintă. **Imediat, și doar până ai câte un om la fiecare meserie** — apoi ghidajul tace. Iarba
   costă dublu: drumul se ia doar când scurtătura peste iarbă ar fi mai mult de jumătate din el
   (altfel primul pas al tutorialului, spawn → prima plasă, 311 px, cobora la drumul mare și urca
   înapoi, 826 px). Ținta e locul unde stai: stâlpul plasei, inelul gaterului, ușa tavernei.
4. **La gater, locul tău are un inel pe jos și o plăcuță** — auriu „Stand here to cut" cât sunt bușteni
   și nu ești acolo, verde „Cutting — N left" cât stai și taie — cât timp n-ai Sawyer.
5. **Debarcaderul devine taverna** (`prop_tavern`, 192×144): în joc *Tavern* și *Innkeeper*; id-urile
   rămân (`dock`, `dock_trader`, `trader`). **Clienții vin după vânzarea reală** — o fereastră de 20 s
   peste evenimentele `Sold`, 1 + bucăți/s, cel mult 8 — nu după capacitatea tavernei, care ar fi
   desenat clienți și fără nicio scândură [D40]. La fiecare vânzare unul pleacă ducând o scândură.
   Poartă ținute noi, fără pălărie (`Townsfolk`, `Traveler`): ținuta e meseria [D44]. Pontonul cu
   barca a rămas pe punte.
6. **Sunetul:** volum pe sunet (stropul și clinchetul găsirilor 0.7, casa de marcat și monedele 0.3,
   gaterul 0.12); gaterul se aude doar la cel mult 300 px și cel mult o dată la 4 s; predarea unui om
   nu mai sună a bani.

**De știut:** drumul tău de mână (prima plasă → gater → tavernă) crește de la 5.6 s la 7.8 s de mers.
Economia nu se schimbă (simulatorul: aceleași 279 de cumpărături, 27m05s reali); dacă se simte lung
în Studio, se strânge bucla, nu se ating prețurile.

**Găsite pe drum și reparate:** (a) `HandDelivered` suna casa de marcat la fiecare predare — bani care
nu existau [D40]; (b) „sack empty" ar fi apărut la fiecare trecere pe lângă ușa tavernei, acum lângă
drumul mare — acum doar chiar la ușă; (c) între două plase de pe punte, drumul cobora 2 px până la
linia de mijloc și urca înapoi — acum, cu ambele capete pe același drum, merge drept.

**Se abate** de la D49 pct. 2 (gaterul la mijloc sub alee, depozitul sub prima plasă): se schimbă
locurile, nu lanțul.

---

## D49 — Lanțul pe oameni: depozit, gater departe, cărăuși
**DECIS** (2026-09-13) — owner-ul, după ce a jucat D48: *„sawmill-ul este prea aproape de nets"* și
*„nu îmi place că se duce wood-ul prelucrat direct la vânzare, strică tot progresul cu transport"*.

1. **Fiecare pas e muncă de om.** Lanțul are șase verigi, venitul e minimul lor:
   `plase ─[Collector]─► DEPOZIT ─[Porter]─► GATER (Sawyer) ─[Hauler]─► DEBARCADER (Negustor) ─► monede`.
   Ce pas n-are om îl faci tu, iar timpul tău se împarte între pașii rămași — de aceea fiecare
   angajare grăbește tot, nu doar pasul ei. **Tăiatul de mână = stai lângă gater.**
2. **Gaterul se mută la mijloc, sub alee**, cu o potecă pe lângă el până într-o curte în fața ușii;
   **depozitul ia locul lui, sub prima plasă.** Nimic nu mai trece singur spre vânzare: debarcaderul
   primește doar ce e tăiat, adus de tine sau de Hauler.
3. **Oamenii au trepte (1–5), nu niveluri fără capăt**, și **al doilea om** pe aceeași meserie de la
   treapta 3 — *„nu foarte multe, pentru că se presupune că sunt oameni"*. Clădirile își păstrează
   nivelurile fără capăt. Un echipaj la maxim care e veriga slabă trimite la clopot, nu la „No gain yet".
4. **Angajările vin în ordinea râului**: Collector (la 2 plase) → Porter → Sawyer → Hauler; Negustorul
   separat (3 plase). **Venitul pasiv cere acum toate cinci meseriile.**
5. **Veriga „Carry" cu niveluri dispare.** Monedele plătite pe ea se dau înapoi o singură dată, la
   migrarea v5 — nimic nu se pierde.

**Constantele, măsurate în simulator** (`--robust`: fiecare ±15%, toate porțile țin): timpul tău
**3.6** (în D48 căratul tău era 1.2 — împărțit la patru pași, tu erai veriga slabă din prima secundă
și 24 din 27 de cumpărături din primele 5 minute nu dădeau nimic), meseriile **4 / 6 / 9** (egale,
stăteau la egalitate și o treaptă pe una singură dădea zero), treapta **×1 pe pas**, gaterul **2.4**
(la 3.6 era gâtuire 3% din timp). **Era 1: 27m05s reali** (de la 31m35s), clopotul tot 10K; gâtuirea:
plase 23% · adunat 24% · dus la gater 12% · tăiat 20% · dus la debarcader 10% · vânzare 12%.
Jucătorul simulat **urmează quest-urile** în două locuri (nivelul 2 al ultimei plase; strânge pentru
deblocarea următoare când veriga slabă n-are ce cumpăra) — fără ele porțile măsurau artefacte.

**Id-urile rămân:** `first_runner` e platforma Collector-ului (id-ul e și cheia omului în profil și
sămânța numelui lui), `hire_hand` e quest-ul Collector-ului — un quest redenumit s-ar fi putut
revendica a doua oară. Noi: `hire_porter`, `hire_hauler`, quest-urile `saw_once`, `hire_porter`,
`hire_hauler`.

**Găsite pe drum și reparate:** (a) grămezile erau liste cu un tabel pe bucată — un Collector fără
Porter ar fi umflat profilul peste limita DataStore (4 MB); acum sunt numărători, fără plafon;
(b) o plasă de nivel mare își umplea cele 12 locuri în 2 s și stătea plină — prinderea reală era mult
sub cifra din meniu; acum ține ~30 s de prindere; (c) `RateLimiter` lăsa să treacă orice nume de
bucket necunoscut, iar `SpinWheel` împrumuta bucket-ul lui `SellSack`, care a dispărut; acum un nume
necunoscut e refuzat și se aude; (d) ghidajul trimitea încă la debarcader traista cu bușteni, deși
din D48 predarea era la gater; acum bușteni → gater, scânduri → debarcader.

**Se abate** de la D48 (predarea la gater, scândurile singure spre debarcader, gaterul lângă plase,
veriga de cărat cu niveluri) și merge mai departe cu abaterea de la regula de fază.

---

## D48 — Gaterul intră în lanțul Erei 1 · meniul de niveluri e al obiectului
**DECIS** (2026-09-12) — owner-ul, după o sesiune în Studio.

1. **Buștenii nu se mai vând bruți.** Lanțul are patru verigi: *prinderea → căratul → tăiatul →
   vânzarea*, iar venitul e minimul lor. Gaterul există **de la început**, între punte și alee, la
   dreapta debarcaderului; **acolo se predă traista** (E), acolo predau și Mâinile, iar debarcaderul
   primește doar ce iese din gater. Driftwood-ul iese **scânduri**; restul trece neschimbat.
2. **Scândura valorează cât buștenul.** Gaterul fiind acolo din secunda 0, un ×3 n-ar fi schimbat
   ritmul — ar fi umflat doar cifrele și ar fi stricat tot ce e fix în monede (costuri de nivel,
   recompense, premiile roții). Valoarea lui e veriga nouă de urcat, omul ei și transformarea
   vizibilă. Un multiplicator de valoare se proiectează când se re-derivă Era 2.
3. **Sawyer**: fără el gaterul merge la **35%** (manivela din §G), cu el la 100% și și când lipsești —
   oglinda Negustorului. **Venitul pasiv cere acum Mână + Sawyer + Negustor.**
4. **Meniul de niveluri e al obiectului atins** (plasa, gaterul, debarcaderul, omul angajat, `Go!` la
   un quest de nivel): lanțul sus, cu obiectul evidențiat și veriga slabă marcată; nivelul; debitul
   acum → la nivelul următor; de ce merge la 35%; dacă un nivel ajută acum. Lista cu toate stațiile
   iese din bara de meniu și rămâne **ascunsă pe tasta U** — owner-ul decide mai târziu ce face cu ea.
5. **Se abate de la regula de fază** (`TYCOON.md:586`): gaterul era proiectat pentru Era 2, iar poarta F1
   nu e trecută. Consecința concretă: bucla pe care o măsoară F1 are patru verigi, nu trei. Decizia
   owner-ului, cunoscând asta.

**Ce a mutat simulatorul:** Era 1 de la 27m43s la **31m35s** reali (costul real al unei verigi în plus);
prețurile rămân, cu excepția lui Third Net (50 → 55) și a Sawyer-ului nou (50). Sawyer-ul **nu urcă
scara de așteptare** (`LADDER_EXEMPT`): numărat ca treaptă, făcea fiecare deblocare de după el cu 17%
mai scumpă și Era 1 ajungea la 34m31s fără ca designul să ceară asta. Gaterul e gâtuirea ~15% din timp —
nu e decor; simulatorul pică dacă vreo verigă nu e niciodată gâtuirea.

**Găsite pe drum și reparate:** (a) `StationService` număra Negustorul ca Mână care cară — căratul afișat
era umflat față de simulator, iar Negustorul singur dădea venit pasiv fără nicio Mână, contra D46;
(b) tastele din bara de meniu nu erau legate nicăieri, deși tooltip-urile le afișau („Quests (J)"), iar
atelierul avea tasta W — a mersului; acum sunt legate, atelierul e pe R; (c) „First sale" apare acum
odată cu primii bani, nu la predare.

---

## D47 — Obiectul din lume e interfața: se cumpără cu confirmare, se urcă atingându-l
**DECIS** (2026-09-12) — owner-ul, după o sesiune în Studio.

1. **Nimic nu se mai cumpără călcând pe obiect.** Apropierea (sub 220px) aduce un cartonaș care
   spune *ce* cumperi (`BUY`, numele, ce face), *cât* costă și **cât îți rămâne** (`343 → 330 left`).
   Cumpărarea cere o apăsare: butonul cartonașului, tasta E sau obiectul însuși — toate trei merg
   **doar** cât cartonașul arată acel obiect. Owner: *„nu aș vrea să mai avem chestia asta cu doar
   du-te în acel obiect și se deblochează"*. Mersul rămâne (D46): cartonașul apare doar în rază.
   Butonul unui obiect abia apărut pe cartonaș e viu după 0,35s, ca al doilea clic al unui
   dublu-clic să nu cumpere obiectul următor fără să-i fi văzut prețul.
2. **Un obiect cumpărat, atins, își deschide nivelul.** Plasa (și insigna ei `Lv N`), debarcaderul,
   alergătorul și Negustorul deschid panoul de niveluri direct pe rândul lor; `Go!` la un quest de
   nivel face la fel. Owner: *„nu am văzut opțiune de upgrade la următorul nivel pe nicăieri"* —
   panoul exista, dar singura cale spre el era un buton din bara de meniu.
3. **Plasa următoare cere ca cea dinainte să fie la nivelul 2** (`TycoonConfig.PREV_NET_LEVEL`), până
   la ultima plasă. Motivul: lumea oferea plasa a doua în timp ce quest-ul cerea încă nivelul 5 al
   primei. Consecință obligatorie: **înaintea fiecărei plase noi e un quest „Upgrade … to level 2"**
   (`net_two`, `second_two`, `third_two`, `fourth_two`) — fără ele banda ar fi cerut o plasă încă
   încuiată. Aceeași cifră stă în simulator, în config și în quest-uri; testele le țin împreună.
4. **Simulatorul verifică acum prețurile din `TycoonConfig.luau`** și pică dacă diferă. Până aici,
   testul „prețurile sunt exact cele din simulator" compara config-ul cu o listă scrisă de mână, iar
   config-ul rămăsese cu 2500 / 2800 / 13000 în timp ce simulatorul derivase 1500 / 1600 / 10000.

---

## D46 — Era 1 pe structura Idle Miner: stații cu niveluri, lanț cu gâtuire, roată zilnică
**DECIS** (2026-09-12) — owner-ul a jucat Idle Miner Tycoon, a trimis 18 capturi progresive și a
cerut explicit bucla și ghidajul lor, cu NPC-urile noastre. Era 1 se face ca **șablon**; Era 2 e
aceeași structură cu alte cifre.

**Ce se schimbă față de D45:**
1. **Era 1 nu mai e o linie de 12 platforme.** Sunt **10 deblocări** + **trei tipuri de stație cu
   niveluri infinite** (plasele, căratul, debarcaderul). Fiecare nivel dă puțin (+3…6% din bază),
   iar la nivelurile 10/25/50/100 se dublează. `Sorting Crate` și `Dock Stall` au devenit niveluri
   ale debarcaderului; `Weighted Nets` a devenit pragul de nivel 10 al plaselor.
2. **Venitul nu mai e o sumă, e minimul a trei debite** — prinderea, căratul, vânzarea. Veriga cea
   mai slabă decide, iar repararea ei e decizia jucătorului.
3. **Regula celor patru motive se rescrie** pentru modelul cu gâtuire: *orice cumpărătură trebuie
   să crească venitul **atunci când țintește veriga slabă**, și niciodată nu-l scade.* Un upgrade
   pe o verigă care nu e gâtuirea dă **exact zero** — asta nu e un bug, e lecția jocului, și se
   scrie pe ecran în loc să se inventeze o cifră frumoasă [D40].
4. **Două monede**: monede (din vânzare) și **perle** (premium). Perlele se cheltuie pe viteză,
   spațiu și aspect — niciodată pe putere, deci P4 rămâne intact **pe monedă**.
5. **Roata norocului intră în joc**, cu premii aleatorii. Asta **restrânge P4**: de la „niciodată
   noroc" la **„niciodată noroc care scade ceva ce ai"**. Limitele care rămân:
   - niciun premiu nu ia nimic — toate sunt în plus [P2 intact];
   - rotirea e **gratuită**, una la 24h. Rotiri cumpărate **nu** intră: D20 spune „zero paid random
     items", iar obiectele aleatorii plătite au reguli proprii de dezvăluire pe Roblox;
   - **șansele se afișează**, și sunt calculate din chiar ponderile folosite la tragere [D40].
6. **Venitul pasiv se câștigă.** Cere **și** o Mână care cară **și** un Negustor care vinde — cu una
   singură lanțul e tăiat. Pastila `IDLE` din HUD apare abia atunci; înainte nu există.
7. **Ghidajul**: capitole + listă de quest-uri + banner permanent + tutorial cu reflector. Progresul
   quest-urilor se **citește din stare**, nu se numără pe evenimente — clasa de bug „am făcut deja,
   dar nu s-a bifat" devine imposibilă.

Rămân în vigoare, neatinse: P1, P2 (nimic nu se pierde), P3, P5, P6, D40 (textul nu minte),
D43 (nimic în tăcere), D44, D20 (fără pay-to-win, fără obiecte aleatorii plătite), D13.

---

## A. Platformă, cont, mediu

### D01 — Proprietate și conturi · DECIS
- Experiențele sunt deținute de un **Grup Roblox** „Driftwood" (100 Robux, o singură dată), nu de contul personal. Motiv: transfer ulterior al unei experiențe către grup cere re-upload manual al ModuleScript-urilor private și al asset-urilor; grupul e și condiția pentru colaboratori plătiți și DevEx din fonduri de grup. [sprites-assets, legal-ip-tax]
- **2FA + verificare de identitate** pe contul owner din prima săptămână. Din 19 mai 2026 publicarea pentru toate vârstele (tier 3, care include conturile Roblox Kids/Select) cere ID + 2FA + abonament Roblox Plus activ sau taxă unică rambursabilă de 1.000 Robux/joc. Verificarea de ID mai deblochează: 2.000 vs 100 upload-uri audio/30 zile, Team Create Collaborate, DevEx. [studio-mac, audio]
- **Două universuri** separate: `Driftwood-Staging` și `Driftwood` (producție), fiecare cu DataStore-uri izolate. Pattern-ul oficial din `Roblox/place-ci-cd-demo`. [open-cloud-cicd]
- Formular fiscal **W-8BEN** depus în Creator Hub înainte de **31 octombrie 2026**: de la 1 noiembrie 2026 DevEx e reclasificat ca royalty, cu reținere la sursă 24% dacă lipsește formularul. [legal-ip-tax]

### D02 — Roblox Studio pe Mac · DECIS
- Se instalează build-ul **nativ Apple Silicon** (installer-ul public livrează build Intel sub Rosetta); se verifică în Activity Monitor coloana Kind = Apple. [studio-mac]
- Mașina de dezvoltare rămâne pe **macOS stabil**, nu beta: crash-urile documentate pe DevForum sunt concentrate pe macOS 26 beta și 27 beta. [studio-mac]
- „Enable Studio Access to API Services" doar pe place-ul de staging, niciodată pe producție. [studio-mac]
- Device Emulator (Test → Device) e parte din bucla zilnică din prototip, nu din faza de polish, pentru că 100% din joc e UI. [studio-mac, mobile-console]

### D03 — Limbă și localizare · DECIS
- Jocul se scrie **în engleză**. Traducerea automată Roblox acoperă 17 limbi și **nu include româna**. Româna se adaugă printr-un tabel de localizare manual când există trafic RO. [onboarding-ftue]

---

## B. Randare și UI

### D04 — Randare 2D pură în ScreenGui · DECIS
- Se rămâne pe ScreenGui pur, conform brief-ului. Argumente confirmate: determinism server-autoritar fără fizică, input simplu, comportament identic pe orice dispozitiv, fără StreamingEnabled, fără riscul ruperii camerei la GraphicsQuality ≤ 3. [alt-2-5d, screengui-2d-feasibility]
- Workspace gol, `Players.CharacterAutoLoads = false`, cameră Scriptable fixă, skybox uniform, `StarterGui:SetCoreGuiEnabled(All, false)`. Topbar-ul **nu** se dezactivează (acces la Report; risc de conformitate neverificat). [screengui-2d-feasibility]
- **Nu** se folosește EditableImage ca renderer: un singur EditableImage se actualizează pe frame, limită 1024×1024, cerință de ID verificat. [ui-performance]
- **Nu** se folosesc ParticleEmitter/Beam/Trail (nu se pot parenta pe GuiObject); efectele 2D sunt un pool de ImageLabel. [juice-effects, alt-2-5d]
- Condiții de reversare la 2.5D (niciuna adevărată azi): adâncime reală pe mai multe planuri Z, avatarul 3D ca identitate socială centrală, sau volum de efecte imposibil de reprodus manual. [alt-2-5d]

### D05 — Arhitectura GUI și performanță · DECIS
- **ScreenGui separate** pentru HUD static și pentru stratul dinamic (râu, plase, particule). Motorul cache-uiește aspectul la nivel de LayerCollector și invalidează tot ScreenGui-ul la orice scriere de proprietate pe orice descendent. [ui-performance]
- Pozițiile obiectelor din râu se scriu pe **`RunService.PreRender`** (RenderStepped e deprecated). Simularea logică rulează pe Heartbeat cu pas fix. [ui-performance]
- **Object pool** de 200–300 ImageLabel din pasul 1; fără `Instance.new`/`Destroy` pe calea fierbinte; ZIndex setat o dată la spawn; fără UIListLayout/UIGridLayout pe stratul râului; culling manual (nu există `VisibleOnScreen`). [ui-performance, screengui-2d-feasibility]
- CanvasGroup doar pe panouri statice (fereastra de reparații), niciodată pe râu. [ui-performance]
- **Test 2026-09-09 (desktop, Studio, M-series):** pool de 400 Frame-uri actualizat pe PreRender cu `DebugSpawnsPerWindow = 800`, fără lag perceptibil; rămâne DE VERIFICAT pe Android 2–4 GB după publicare.
- Buget de performanță (ipoteză de proiectare, de măsurat în prototip cu MicroProfiler Cmd+Opt+F6): 60 fps desktop, **30 fps prag minim pe Android low-end (2–4 GB RAM)**, ≤ 200 obiecte active pe râu în regim normal, plafon dur 400 obiecte vizibile la Inundație (restul se agregă vizual). [ui-performance, mobile-console]

### D06 — Coordonate, scalare, ecrane · DECIS
- Rezoluție de referință logică **1920×1080 landscape**. Pozițiile lumii în Offset (pixeli logici); un singur `UIScale` global = `min(viewport.X/1920, viewport.Y/1080)`, recalculat la `ViewportSize` changed. [screengui-2d-feasibility]
- `ScreenGui.IgnoreGuiInset = true` pe toate ScreenGui-urile de joc; `ScreenInsets = CoreUISafeInsets` pe HUD; insetul topbar-ului se citește dinamic din `GuiService:GetGuiInset()`, nu se hardcodează (s-a schimbat în 2024). [screengui-2d-feasibility, mobile-console]
- Dispozitive-țintă de test: iPhone cu notch (844×390), Android low-end (Infinix Smart 9 / Moto G05 clasă), desktop 1920×1080, iPad. Ținte tactile minime 44 pt la scara reală (≈ 100 px la referință). [mobile-console]
- Console: **nu la lansare** (≈ 3% din sesiuni), dar `Selectable` + `NextSelectionUp/Down/Left/Right` se setează pe fiecare control din HUD v1, ca să nu fie retrofit. [mobile-console, input-2d]

### D07 — Input · DECIS (revizuit 2026-09-09)
- **Revizuire (owner, 2026-09-09):** jocul are un **personaj 2D pe mal**, ca în inspirația Stardew: mers stânga-dreapta (A/D, săgeți; două butoane pe ecran la mobil), cameră care urmărește personajul pe o bandă orizontală (terenul = 2 ecrane, 3.840 px logici; orașul continuă la pasul 5 cu ≈ 20 de ecrane și chioșc de teleport). Interacțiunea e **prin apropiere**: lângă un slot liber → „Place net" (E / buton), lângă o plasă cu conținut → „Collect". Poziția personajului e strict client-side și nu influențează economia. Drag-and-drop-ul cu `UIDragDetector` a fost implementat și testat, apoi înlocuit; rămâne opțiune pentru inventar/atelier.
- Plasarea plaselor (varianta inițială, înlocuită): **`UIDragDetector`** (DragStyle TranslatePlane, BoundingBehavior EntireObject, `AddConstraintFunction` pentru snap la slot), validare finală pe server la DragEnd. [input-2d]
- Toate butoanele: `GuiButton.Activated` (uniform mouse/touch/gamepad), nu `MouseButton1Click`. [input-2d]
- `GuiService.PreferredTransparency / PreferredTextSize / ReducedMotionEnabled` se citesc la login și se respectă; toggle „reduce motion" propriu pentru screen shake și flash-uri. [input-2d, juice-effects]
- Fără pan/zoom în v1: terenul jucătorului încape pe ecran; orașul se vede ca bandă derulabilă orizontal cu butoane, nu cu gesturi libere. [input-2d]

### D08 — Styling și efecte · PROVIZORIU
- UI Styling API (`StyleSheet/StyleRule`, Full Release 20 ianuarie 2026) se adoptă de la **vertical slice**, nu de la prototip: owner-ul învață întâi Frame/UDim2 clasic. [platform-2025-2026-features]
- Animații: `TweenService` nativ în prototip; Ripple (activ, iulie 2026) doar dacă apare nevoia de spring-uri; Flipper e abandonat din 2021. [juice-effects]
- Apa: `ScaleType.Tile` + `TileSize` într-un Frame cu ClipsDescendants, derulată prin Position; `ImageRectOffset` e incompatibil cu Tile. [juice-effects, sprites-assets]

---

## C. Toolchain și cod

### D09 — Toolchain · DECIS
- **Rokit** (Aftman e arhivat), cu versiuni fixate în `rokit.toml`: `rojo 7.7.0`, `stylua 2.5.2`, `selene 0.31.0`, `wally 0.3.2`, `lune 0.10.5`, `zap` (când se adoptă, vezi D11). `luau-lsp` v1.69 în VS Code (Marketplace) sau Cursor (Open VSX). [toolchain-rojo, local-testing]
- **UI construit din cod**, nu din `.rbxmx` sincronizate din Studio: Rojo nu are sync bidirecțional live (doar `rojo syncback` manual). Orice editare directă în Studio se pierde. [toolchain-rojo]
- Extensia `.luau` peste tot; `--!strict` explicit pe fiecare modul (din 20 noiembrie 2025 default-ul e nonstrict); interzise `wait/spawn/delay` legacy, doar `task.*`. [luau-language]
- Pattern de cod: Service (server) / Controller (client) ca ModuleScript singleton, cu `Init(deps)` explicit dintr-un bootstrap; module de logică pură în `src/Shared/` fără `game`/`os.time` în interior (primesc timpul ca parametru) — condiție pentru teste fără Studio. [luau-language, local-testing]

### D10 vezi secțiunea D — modelul orașului (mutat acolo pentru că e decizie de produs).

### D11 — Librării · DECIS
- Persistență: **ProfileStore 1.0.3** (ProfileService e deprecat oficial de autor). [datastore-deep, frameworks-2026]
- Semnale și cleanup: **RbxUtil** (Trove + Signal). [frameworks-2026]
- Networking: prototipul (pasul 1) folosește **RemoteEvent brut** printr-un wrapper `Net` de 3 remote-uri; de la pasul 2 se adoptă **Zap 0.6.x** (tipat, buffer-packed; Red e arhivat, Blink e pre-1.0). [frameworks-2026]
- **Nu**: Knit (arhivat), Roact (arhivat), Matter/jecs (ECS, supra-inginerie pentru Frame-uri), roblox-ts (fricțiune pentru un începător pe Roblox), react-lua (fără commit din mai 2025). Vide rămâne opțiune pentru chrome UI după vertical slice. [frameworks-2026]
- Configurare live și feature flags: **ConfigService** (lansat 24 august 2026; propagare 15 s–1 min), nu un sistem propriu pe DataStore. [seasons-liveops, analytics-testing]

### D12 — Testare și CI · DECIS
- Teste unitare pe module pure cu **Lune + frktest** (`lune run tests/_run.luau`); TestEZ e arhivat din 14 septembrie 2024, Jest-Lua nu rulează în Lune. [local-testing]
- GitHub Actions pe `ubuntu-latest`: `stylua --check` → `selene` → teste Lune → `rojo build` → `rojo upload` pe staging. Promovarea la producție e manuală (workflow_dispatch). Fără `run-in-roblox` (cere Studio + cookie .ROBLOSECURITY în CI). [open-cloud-cicd, local-testing]
- Open Cloud Luau Execution API doar pentru câteva smoke-tests pe staging, presupunând limita conservatoare de 2 task-uri concurente (sursele se contrazic: 2 vs 10). [local-testing, open-cloud-cicd]
- Fiecare `.rbxl` publicat se păstrează ca artifact GitHub etichetat cu `versionNumber`: rollback-ul din Version History nu republică automat și nu oprește serverele pornite. [open-cloud-cicd, seasons-liveops]

---

## D. Arhitectură de joc

### D13 — Server-autoritar și simularea râului · DECIS
- Serverul e singura sursă de adevăr pentru economie. Clientul trimite doar intenții (`PlaceNet`, `Collect`, `StartRepair`, `Donate`, `SecureItem`). [server-authoritative, anti-exploit]
- **Râul e determinist pe seed**: serverul publică o dată `{seed, seasonParams, windowStart}`; clientul derivă pozițiile local din `Random.new(seed)` și le randează; **prinderea se decide exclusiv pe server**, care rulează aceeași simulare la 10 Hz. Nu se replică obiectele individual (bandwidth ≈ 0 în regim normal). [server-authoritative]
- Validare pe fiecare remote: tip, `math.isfinite`, ownership, stare curentă, cooldown cu timestamp server, anti-duplicare; **token bucket** (implementarea oficială Roblox) per tip de remote; throttle-ul motorului e ≈ 500 req/s per client, deci cooldown-urile de design sunt cu ordine de mărime mai stricte. [server-authoritative, anti-exploit]
- Anti-exploit la lansare: 2 honeypot remotes (log + kick), scor de suspiciune (rate-of-gain, cadență), `Players:BanAsync` cu durată finită la primul incident; **fără** anti-cheat client-side; **fără** Server Authority (feature-ul din iulie 2026 e pentru fizică 3D). Hyperion e confirmat doar pe Windows, deci Mac și mobil sunt mediile unde validarea server contează cel mai mult. [anti-exploit]

### D14 — Date de jucător · DECIS
- Un singur profil ProfileStore per jucător, `PROFILE_TEMPLATE` versionat + `Reconcile()` la fiecare load. Autosave la **120 s** (cheie ConfigService, default ProfileStore e 300 s) + `PlayerRemoving` + `BindToClose` cu salvări paralelizate (`task.spawn` per jucător, buget 30 s pe tot serverul). [datastore-deep, server-authoritative]
- Timpul se stochează **absolut** (`finishAt`, `lastCollectedAt`), niciodată ca „timp rămas". [offline-progress]
- Idempotență pentru cumpărături: `PurchaseId` scris în profil înainte de `PurchaseGranted`. [monetization-impl]
- Ștergere GDPR: toate datele unui jucător stau sub o singură cheie (profil) + intrări în ledger-ul orașului anonimizabile; runbook-ul rulează la notificarea din Deletion Queue. [policy-compliance]
- Limite reținute: 4 MB/cheie; bugete per experiență (citire 300+40×CCU/min, scriere 300+20×CCU/min) **și** per server (60+40×jucători/min) coexistă; 4 MB/min scriere per cheie. [datastore-deep, cross-server]

### D10 — Modelul orașului comun · PROVIZORIU (spike la pasul 5)
Problema: Roblox nu are servere persistente. „Tot serverul împarte același oraș" din brief nu poate însemna literal instanța de server (progresul s-ar pierde la fiecare reciclare). [cross-server, shared-progress-persistence, community-progression]

Decizie: **orașe persistente, de dimensiune fixă, pe reserved servers, cu un lobby de rutare.**
- Un **oraș** = o înregistrare în DataStore (`towns/<TownId>`) + un cod de reserved server (`ReserveServerAsync`) salvat în aceeași înregistrare. Un oraș e găzduit de **cel mult un server** la un moment dat, deci cheia lui are un singur scriitor: dispare problema hot-key și contenția UpdateAsync.
- **Place-ul de start e un lobby minimal** (încărcare sub 3 s): jucător nou → i se atribuie orașul deschis cel mai puțin populat (MemoryStoreSortedMap `TownId → populație activă`, volum mic, N orașe nu N jucători) și e teleportat; jucător care revine → teleportat în orașul lui (`TeleportAsync` + `ReservedServerAccessCode`). Teleportul adaugă 3–8 s la join; se acoperă cu ecranul „Corabia pleacă spre <Oraș>".
- **Apartenența** e per jucător (`profile.Data.Meta.HomeTownId`), plafon 120 membri/oraș; **concurența** e plafonată de `MaxPlayers = 24` al place-ului Town. Dacă orașul e plin, jucătorul poate intra ca vizitator în alt oraș: plasele, atelierul și indexul sunt **per jucător** și funcționează oriunde; doar donațiile și zonele sunt per oraș.
- Vizitarea altor orașe și „mergi la prietenul X" sunt funcții explicite din lobby/HUD (teleport pe codul orașului), pentru că butonul Join din Roblox nu funcționează pe reserved servers.
- Starea orașului se salvează la 120 s + `BindToClose`; `MessagingService` doar pentru anunțuri opționale între orașe (livrare best-effort, nu sursă de adevăr).
- La lansare: **8–12 orașe deschise**, se deschid altele automat când media de ocupare depășește 70%.

Alternative respinse:
- (a) Un singur oraș global pentru tot jocul: diluează obligația socială (mii de donatori) și creează hot-key cu lease de leader + cache MemoryStore — complexitate mai mare pentru un rezultat de design mai slab.
- (b) Oraș per instanță de server: contrazice „permanent"; se pierde la fiecare restart.
- (c′) Servere publice care „revendică" un oraș la boot: jucătorii care revin nu pot fi rutați acasă când orașul nu e găzduit nicăieri.

De testat în spike (înainte de pasul 5): latența reală de teleport din lobby pe mobil; comportamentul reserved server la ultimul jucător care pleacă și la reintrare; `TeleportService` nu funcționează în Studio, deci place-ul Town trebuie să pornească standalone cu un „dev town" când lipsesc datele de teleport. Prototipul (pașii 1–4) rulează pe **un singur place** fără lobby.

### D15 — Progres offline · DECIS
- Plafonul principal de acumulare e **capacitatea plasei** (sloturi), nu ceasul; plasa de bază se calibrează să se umple în ≈ **8 ore** reale (cifra din brief devine țintă de tuning, nu constantă). Plafon orar back-stop de 24 h pentru plasele mari cumpărate. [offline-progress]
- `lastCollectedAt` per plasă (nu doar `lastSeen` global). Rolurile de raritate offline sunt seedate determinist din `(userId, netId, lastCollectedAt)` și seed-ul avansează doar după procesare reușită — previne farming prin reconectare. [offline-progress]
- Ecran „Bun venit înapoi" la login, cu mesaje diferite pentru „plasă plină" vs „timp atins". [offline-progress, case-top-games]
- **Experience Notifications**: opt-in cerut contextual după minutul 4 din prima sesiune (nu în primele 30 s), maxim 1 notificare/zi/utilizator, agregată („toate plasele sunt pline"), plus una cu 24 h înainte de Inundație. Eligibilitate: 100 vizite, doar 13+. Tratată ca supliment, nu ca sistem central. [offline-progress, onboarding-ftue]

### D16 — Reparat și atelier · DECIS
- Atelierul are **N sloturi de reparație** simple (nu grid tip Tetris): 3 gratuite la start, +1 prin progres (index 25%), +1 și +2 prin Game Pass. Coada „grămada nesortată" e nelimitată ca număr, dar obiectele din ea nu contează în index și nu pot fi donate — tensiunea vine din sloturi, nu din energie. [economy-balance, collection-design]
- Timpul de reparație e absolut, continuă offline, scalat pe raritate (minute → zile). Materialele vin din dezmembrarea obiectelor duplicate (sink-ul principal). [economy-balance]
- Obiectele intră în Index **doar reparate complet** — al doilea gate de ritm, care întinde completarea colecției. [collection-design]

### D45 — Driftycoon: tycoon direct, un singur număr central · DECIS (2026-09-11)
Owner-ul: *„hai să facem acest joc tycoon direct, restructurăm tot"*. Planul complet, cu dezbaterea pe
22 de arii, e în **`docs/TYCOON.md`**; aici e doar ce s-a hotărât și ce cade.

**Diagnosticul:** jocul erau două jocuri sudate — un nucleu de colecție și un simulator de colonie peste
el — fără un număr la care să contribuie toate. De aici „nu se leagă nimic de nimic".

**Ce se hotărăște:**
- **O singură monedă** (Coins) și un singur număr central: monede pe secundă.
- **Regula celor patru motive:** orice se poate cumpăra trebuie să prindă mai mult, să vândă mai scump,
  să scape de o corvoadă sau să deschidă ce urmează. Și **nicio cumpărare nu are voie să scadă venitul**
  — simulatorul (`scripts/economy/sim_tycoon.py`) oprește rularea dacă vreuna o face.
- **Prețurile se derivă din ținte de ritm**, nu se ghicesc. Prima variantă ghicită avea nouă defecte pe
  care doar modelul le-a văzut (lista în `TYCOON.md` §5).
- **Platforme fixe de cumpărare, în 4 zone** (Landing, Mill, Yard, Harbor); nu construcție liberă.
- **Coloniștii devin angajați**: fără nevoi, fără plecare, fără hrană. Arta pe straturi (D44) rămâne.
- **Renaștere liniară** (+50%/tură), cu scară de cerințe; nu atinge nimic plătit [wipes].
- **Offline pe capacitate**: producția automatizată curge într-un Seif până se umple (~8 h) [16].
- **Monetizare: viteză da, noroc niciodată** [money].

**Ce cade:** direcția de colonie din D29–D31 și regulile specifice ei din D34–D39, D42 (lanțul de
obiective, economia hranei, nevoile, plecarea, construcția liberă, povestitorul ca motor). **Rămân în
vigoare:** D43 (*nimic nu se întâmplă în tăcere*), D44 (înfățișarea pe straturi), D40 (textul nu minte),
și tot ce ține de platformă, autoritate pe server, persistență, conformitate și principiile de
monetizare din D20.

**O corectură la baza deciziei.** Pe 2026-09-11 i-am spus owner-ului că direcția de colonie *„nu are
nicio cercetare în spate"*. Era greșit: căutasem doar în `docs/research/` și ratasem
`docs/research-survival/` (31 de note, inclusiv RimWorld/Dwarf Fortress) și `docs/directions/`.
Argumentele de scop rămân valabile — un solo reușește cu o singură buclă [37] —, dar premisa aceea n-a
fost adevărată. Tot atunci ratasem că renașterea *e* cercetată ([wipes], [landscape]).

**Arhivat, nu șters** (niciun commit nu exista): `MASTERPLAN.md` și cele 19 părți ale lui, direcțiile
concurente, notele de supraviețuire din alt gen, documentele de colonie, previzualizările — în total
~203.000 de cuvinte, în `~/Desktop/Driftwood_arhiva_2026-09-11/`.

### D44 — Chipuri, nu roluri: înfățișarea în trei straturi · DECIS (2026-09-11)
Owner-ul: *„main character arată ca oricine. NPC-urile trebuie să arate diferit, nu doar în funcție
de job, ci și gender și aspect, dar să aibă ceva în common când au același job."*

Cerința e un **sistem**, nu un desen. Identitatea variază liber, meseria rămâne constantă:

| strat | conține | variază |
|---|---|---|
| corp | doar pielea | siluetă (2) × nuanță (6), prin tint |
| păr | doar părul | coafură (4) × culoare (6), prin tint |
| **ținută** | cămașă, pantaloni, **pălăria și unealta meseriei** | **nu — e semnalul de meserie** |

288 de combinații de înfățișare, la un plafon de 80 de oameni. Jucătorul primește o a șasea
ținută (`keeper`) pe care niciun colonist nu o poate avea.

**Cauza reală a problemei raportate:** jucătorul era desenat complet netonat, iar `TINTS[1]` al
coloniștilor era `{255,255,255}` — adică unul din șase coloniști era pixel-identic cu jucătorul.

**Lecție din prima etapă de generare:** stratul de păr ieșise aproape gol, fiindcă pălăria acoperă
capul. Cu pălărie la fiecare meserie, patru coafuri ar fi arătat identic. Regula corectată:
coafurile se desenează prin ce **iese pe lângă** pălărie (tâmple, ceafă, umeri), iar hangiul nu
poartă pălărie deloc, ca să existe o meserie unde coafura se vede întreagă.

**Compunerea e verificată programatic**, nu din ochi: corp + păr + ținută suprapuse trebuie să dea
exact foaia dintr-o bucată, pixel cu pixel, pe toate cele 60 de cadre. Fără proba asta, un decalaj
de un pixel ar trece nevăzut prin generator și ar apărea abia în joc.

**Pornire automată:** foile sunt declarate în `Assets` cu id 0, deci `Assets.has` dă false și
clientul rămâne pe calea de acum. Când se încarcă, se pun id-urile și sistemul pornește singur.
**Se încarcă toate sau niciuna** — foaia dintr-o bucată e acum desenată pe rampe neutre, deci
încărcată singură ar face pe toată lumea gri.

### D43 — Nimic nu se întâmplă în tăcere · DECIS (2026-09-10)
Owner-ul a jucat două minute și a găsit ceva de comentat la fiecare pas. Toate observațiile s-au
dovedit **același defect**: jocul făcea lucruri fără să spună că le face. Dialogul avansa dar nu
spunea că poate fi avansat. Clădirile se ridicau dar nu spuneau de cine. Cartonașul zicea „Open
Build" dar nu spunea unde e Build. Atelierul dădea două butoane fără să spună că sunt opuse.

**Regula, de acum:** în orice moment ecranul răspunde la „ce fac acum", și orice acțiune își arată
urmarea. Trecerea pas cu pas e în `docs/PRIMELE_CINCI_MINUTE.md` și se reface după fiecare
schimbare de onboarding.

Ce a ieșit din ea:
- **Îndemnul din dialog era ascuns exact cât se scria textul** — adică fix în secundele în care
  jucătorul se întreabă ce să facă. Acum e mereu vizibil și își schimbă mesajul: *skip* cât scrie,
  *continue* după, *close* la ultima replică.
- **Introducerea nu spunea ce e jocul.** Patru replici acum, câte una per întrebare: unde ești,
  ce e motorul lumii, **ce ești tu** („what this settlement becomes is your call"), ce faci acum.
- **Nimic nu arăta pe ce buton se apasă.** Sarcina curentă aprinde un inel pe butonul din bară.
- **„Pământul luminat" nu era luminat** — `BackgroundTransparency = 0.93`, adică 7% opacitate.
  Un indiciu care numește ceva invizibil e mai rău decât lipsa indiciului.
- **Meseriile erau cinci butoane cu câte o literă.** Acum fiecare își spune rostul, iar textele
  descriu ce face codul — dacă se schimbă o regulă, se schimbă și textul.
- **Plasa apărea din neant.** Indiciul spune acum că cele trei locuri de pe râu sunt ale tale.
- **Acțiunea n-avea urmare vizibilă.** Cifrele își arată schimbarea: „+8" plutește de la cifra
  care s-a modificat, nu într-un colț îndepărtat de ecran.
- **Un colonist dispărea după patru minute invizibile.** Starea „leaving" era ștearsă în ACELAȘI
  tick de 0,25 s în care apărea, deci clientul n-o vedea niciodată și eticheta din panou era cod
  mort. Acum serverul trimite ambele numărători, semnul de deasupra capului are trei stări
  (nemulțumit → numărătoare → „LEAVING 9s"), iar omul merge spre debarcader înainte să dispară.
  Dacă nevoia se rezolvă între timp, rămâne. Asta e regula „nimic nu se pierde fără șansă de
  reacție", aplicată la singura pierdere reală din joc.
- **Pasul „watch the water" avea până la 45 s de nimic.** Prima sosire vine acum în 12.
- **Inelele de plasă pulsau stroboscopic** — `phase = (tick() * 1.6) % 1` calculat pe cadru,
  un dinte de fierăstrău care sărea instantaneu de la ~1 la 0, sincron pe toate trei.

### D42 — Telefonul nu e un desktop mic: joystick, nu patru butoane · DECIS (2026-09-10)
**Comenzile de mișcare.** Erau patru butoane pătrate de 112 px, împrăștiate în stânga-jos. Pe un ecran de 896×414 mâncau o treime din suprafață, unul stătea peste atelier, și dădeau doar 8 direcții. Trec pe **un joystick** într-un colț: o singură comandă, direcție analogică, nu acoperă nimic din joc. Magnitudinea contează — o împingere pe jumătate merge pe jumătate din viteză; direcția se normalizează, deci diagonala nu e mai rapidă.

Deplasarea se măsoară față de **punctul în care ai atins**, nu față de centrul desenat. Două motive: nu trebuie să nimerești mijlocul cu degetul, și dispare complet nepotrivirea dintre coordonatele de input și `AbsolutePosition` sub decupajul de sus al platformei — o clasă de bug greu de prins fără să poți rula pe dispozitiv.

Butonul de acțiune devine rotund, auriu, cu pictogramă în loc de glifa „●".

**Ferestrele se strâng pe pânză.** Panourile sunt dimensionate pentru desktop, dar pânza HUD e `viewport/hudScale`: pe telefon are ~1445×668 unități logice, iar o fereastră de 700 înălțime ieșea pe sub marginea de jos — rândurile de dedesubt deveneau inaccesibile, fără niciun semn că există. Limitarea se face în `Widgets.Window`, singurul loc prin care trec toate panourile, și se reface la rotirea telefonului.

**Regula generală:** orice dimensiune fixă scrisă pentru desktop e o presupunere despre ecran. Pe telefon presupunerea cade, iar interfața nu dă niciun semnal că a căzut — pur și simplu o parte din joc dispare sub margine.

### D41 — Limbaj vizual de joc mobil de construcție, și o sondă care vede din interiorul Studio · DECIS (2026-09-10)
**Fontul.** Merriweather (D37) a fost o greșeală de gen, nu de reglaj: e un serif de ziar, iar într-un joc colorat văzut de sus citește ca „document". De-aia a fost respins de trei ori oricât l-am ajustat. Titlurile trec pe **Fredoka One**, familia rotunjită și grea în care sunt scrise jocurile mobile de construcție. Textul curent rămâne Nunito.

**Conturul e jumătate din efect**, și lipsea complet. `Theme.punch()` pune contur închis pe glife, cu grosimea proporțională cu mărimea textului. Regula: se pune **doar pe text care stă peste lume** — peste iarbă, apă, acoperișuri. Pe pergament nu: text închis conturat cu închis se îmbâcsește. Consecință practică: textul peste lume nu mai are nevoie de placă neagră sub el ca să se citească.

**Monospace rămâne monospace.** Măturarea fonturilor scrise de mână a convertit și jurnalul consolei de dezvoltare la lățime variabilă. Acolo alinierea pe coloane e funcțională, nu decor. Theme are acum un `kind` de `mono` separat.

**Apăsatul pe clădire.** Clădirile nu erau apăsabile deloc — puteai ridica una, dar nu o puteai întreba nimic, deși ești administrator. Modelul luat din jocurile mobile de construcție, cu trei reguli: cartonașul stă **lângă clădire, în lume** (nu pierzi contextul), clădirea aleasă **se vede aleasă** (inel auriu care pulsează), și **cel mult o acțiune, mare**, doar unde chiar există una. Șantierele arată progres și câți constructori sunt efectiv pe ele; terminatele arată capacitatea în cuvântul potrivit — *beds*, *seats*, *plots* — nu „slots" pentru tot. Numărul de oameni se calculează din pozițiile pe care clientul le are deja, deci scrie „cine e aici", nu „cine e repartizat".

**Toastul a plecat din zona dialogului.** Stătea jos-centru la −150 px, exact peste caseta de dialog și peste d-pad-ul de telefon, și ducea replici de personaj — deci citea ca un al doilea sistem de dialog, în formatul vechi. A trecut în treimea de sus, centrat, unde e liber la orice lățime de ecran.

**Sondă în loc de ochi.** Nu pot deschide Studio și nu pot vedea ecranul; un screenshot costă mult și oricum nu răspunde la întrebările care încurcă cel mai des. `plugins/DriftwoodProbe.lua` rulează **în** Studio și trimite un raport text la un server local (`scripts/probe_server.py`): ce familie de font s-a rezolvat efectiv pe elementele reale, dimensiunile și pozițiile la rezoluția adevărată, `TextFits` pe fiecare etichetă, și ultimele erori din consolă. Pixelii rămân pentru întrebări chiar vizuale, decupați și micșorați — capturile consumă mult.

### D40 — Textul nu mai are voie să mintă: teren, apă, grămadă · DECIS (2026-09-10)
Trei locuri unde interfața promitea un lucru și jocul făcea altul. Regula pe care o fixează decizia: **dacă un text spune ceva, jocul trebuie să facă exact acel lucru**, altfel textul se schimbă. Un indiciu fals costă mai mult decât lipsa indiciului, pentru că jucătorul învață să nu se mai uite la ele.

- **Terenul luminat era o sugestie, nu o limită.** Indiciul spunea „așeaz-o pe pământul luminat", dar `BuildService.CanPlace` accepta orice loc liber din lume. Conturul nu însemna nimic. Acum limita se verifică **pe server** (`outside_plot`) și se oglindește în fantoma de așezare din client, ca ghidajul să devină roșu exact unde serverul ar refuza. Cele două verificări trebuie să rămână identice; când diferă, jucătorul apasă pe verde și primește refuz.
- **„Watch the water" arăta spre nimic.** Pasul 6 din lanț cerea să te uiți la apă, dar pe apă nu se întâmpla nimic: sprite-ul `boat` exista în `Assets` cu zero desenări în tot codul, iar sosirea era doar o linie de text într-un colț. Acum barca vine din amonte, **încetinește în dreptul terenului**, arată numele celui care coboară, apoi pleacă la vale și se stinge. Nu blochează nimic și nimeni nu o așteaptă — dacă jucătorul se uită în altă parte, pasul se termină oricum.
- **Debarcaderul e o singură sursă de adevăr** (`RiverConfig.LANDING`). Săgeata pasului arăta spre mijlocul lumii (x = 1440), barca ar fi tras în dreptul terenului (x = 950): indicatorul ar fi trimis jucătorul la 490 px de locul unde se întâmpla lucrul. Trei teste țin punctul în banda apei și în dreptul terenului.
- **Grămada goală din atelier** spunea „nimic aici" și când tot ce adunase jucătorul era pe masa de reparat. Acum distinge cele două cazuri și numără piesele în lucru.

### D39 — Dialog care oprește jocul, colonie care se salvează, economie cu presiune reală · DECIS (2026-09-10)
**Dialogul.** Primul colonist vine **la** jucător și îi vorbește într-o cutie mare jos-centru, cu portret, nume și text scris literă cu literă. Cât vorbește, jocul stă: personajul nu se mișcă, panourile nu se deschid, cartonașul și bara de butoane se ascund. Un mesaj în colț peste care jocul curge mai departe nu se citește, devine zgomot. Trei plase de siguranță ca jucătorul să nu rămână blocat: dacă nu are drum vorbește pe loc, dacă nu ajunge în 7 secunde vorbește oricum, iar clientul deblochează singur după 14. Numărătoarea se face pe **grafeme**, nu pe octeți, altfel diacriticele rup efectul.

**Busolă în jurul jucătorului.** Săgeata de deasupra țintei ajută doar când ținta e pe ecran. Când nu e, o săgeată orbitează jucătorul și arată încotro. Apare doar peste 260 px distanță.

**Defecte găsite de recenzia pe patru zone și reparate:**
- **Coliziunea jucătorului folosea clădirile fantomă din prototip.** Clădirile construite de jucător nu opreau deloc, iar acolo unde nu se desena nimic existau ziduri invizibile. Acum urmează starea reală a clădirilor.
- **Fundătură în lanțul de obiective:** pasul cerea „orice clădire terminată", nu un pat. Cine construia o vatră rămânea cu un singur pat, nimeni nu mai venea pe apă, iar pasul următor nu se putea termina niciodată. Condiția e acum **paturi ≥ 2**.
- **Scurgere de ocupare:** un colonist șters cât timp ocupa o clădire lăsa locul ocupat pe veci.
- **Atelierul se bloca** pe cea mai veche piesă chiar dacă nu și-o permitea, cu una gratuită mai jos în grămadă.
- `DataService` pornește **ultimul**: el declanșează încărcarea profilului, deci toți ascultătorii trebuie conectați înainte.
- Pânza interfeței urmează acum ecranul. Era fixă la 1920×1080 cu prag de scară 0,62, deci pe ecrane mici tot ce e ancorat la dreapta ieșea afara și nu se mai putea apăsa.
- Tragerea cartonașului se făcea în pixeli de ecran peste o pânză scalată: rămânea în urmă pe orice ecran mai mic decât referința.
- Butoanele de pe ecran se ascund când e un panou deschis. Pe telefon stăteau sub panou și apăsai panoul când voiai să mergi.

**Economia are presiune abia acum.** Pescuitul nu avea plafon, iar meseriile se împart pe rând: un pescar hrănea 18 oameni la orice mărime de colonie, deci raportul rămânea același și nu exista nicio decizie. Râul are acum **3 locuri de pescuit**. Pescuitul singur susține 24 de oameni; peste atât trebuie grădini. Hangiul împarte același bine la toată colonia, în loc să-l dea fiecăruia întreg. Două teste apără curba: unul verifică plafonul, altul că pescuitul singur nu duce colonia până la limita dură.

**Coloniștii se salvează.** Nume, meserie, nevoi, trăsături și poziție intră în profil, cu scriere la 15 secunde și la ieșire. O colonie crescută în câteva sesiuni se întorcea la un singur străin după orice repornire de server, în timp ce clădirile rămâneau în picioare.

### D38 — Colonia începe de la un singur om; textul nu mai are voie să mintă · DECIS (2026-09-10)
- **Se pornește cu UN colonist**, nu cu doisprezece. Primul om vine pe apă și cere de lucru: `"I heard someone was keeping this place. I can work, if you'll have me."` E singura dată când cineva vorbește direct cu jucătorul. Colonia trebuie să crească din el, nu să fie primită gata făcută.
- Așezarea moștenită are **un singur pat** (cort, nu cabană de trei). Nimeni nou nu se oprește acolo până nu construiești al doilea pat. Cu trei paturi din start, creșterea venea de la sine și nu mai era a jucătorului.
- **Inelul strălucitor există acum.** Indiciul primului obiectiv spunea „du-te la inelul strălucitor de pe apă", iar pe apă era un dreptunghi palid pe care nu-l vedeai. Acum e un cerc cu contur auriu și un al doilea inel care se umflă și se stinge.
- **Text care nu poate minți:** listele de semne și de panouri sunt acum sursă unică de adevăr în configurație, iar două teste verifică fiecare obiectiv. Un obiectiv care cere un semn inexistent lasă jucătorul fără indicație; unul care deblochează un panou inexistent îl lasă blocat. Testul a fost verificat inventând un semn: pică.
- **Cartonașul de obiectiv**: înălțimea vine din conținut printr-o singură legătură, deci nu mai există banda goală dintre titlu și indiciu. Se poate **strânge** la titlu și se poate **trage** oriunde pe ecran. Aceeași suprafață face și clic și tragere, după cât s-a mișcat degetul: două suprafețe separate ar fi fost o ghicitoare în plus.
- Sărbătoarea mișcă panoul, nu îl scalează. Un `UIScale` ar mări corpul, corpul ar cere altă înălțime pentru ramă, iar rama ar mări iar corpul: buclă, exact în timpul animației.

### D37 — Toate panourile pe aceeași trusă, font de registru · DECIS (2026-09-10)
- **Ce era greșit:** trusa de interfață exista, dar o foloseau doar HUD-ul, cartonașul de obiectiv și bara de butoane. Cele patru panouri mari erau desenate de mână, cu Gotham și **89 de culori scrise direct în cod**. De acolo venea impresia de interfață generică lipită peste un joc pixelat.
- Atelierul, meniul de construcții, panoul de oameni și tabloul coloniei trec toate prin `Widgets.Window`: aceeași ramă de lemn, aceeași banderolă de titlu, același buton de închidere, aceeași spațiere. Rândurile de listă sunt casete scobite care se luminează la trecerea mausului. Butoanele au trei stări desenate.
- **Tabloul coloniei are corp care se derulează**, cu secțiuni așezate una sub alta. Varianta veche calcula pozițiile pe verticală de mână, iar orice text mai lung ieșea din panou. Acum nu mai există aritmetică de așezare, deci nici clasa aia de erori.
- **Fontul:** Gotham e implicitul depreciat al platformei, iar Montserrat și Poppins sunt geometricele pe care le folosește toată lumea. Ambele citesc ca „am lăsat setarea din fabrică". Titlurile trec pe **Merriweather**, un serif de carte: pe pergament și lemn arată a registru scris, nu a dialog de aplicație. Textul curent rămâne **Nunito**, rotunjit și lizibil la dimensiuni mici, unde un serif ar deveni greu de citit. Greutatea de titlu coboară la Bold: un serif la greutate extremă își închide contraformele.
- **Fontul se caută prin nume, cu rezervă.** `Enum.Font.CevaGresit` aruncă pe loc, iar fiindcă modulul de temă e cerut de toate controllerele, o singură literă greșită ar opri tot bootstrap-ul clientului și jocul ar porni pe ecran gol.
- Singurele culori rămase scrise în cod convertesc triplete din configurație (raritatea lăzilor, tonul evenimentelor). Alea sunt date, nu decizii de stil.

### D36 — Cartonașul nu se golește niciodată, iar textele încap · DECIS (2026-09-10)
- **Textele se tăiau.** Creșterea automată a panoului nu apuca să urmeze conținutul înainte de desenare, iar eticheta ajungea în afara ramei, peste iarbă. Acum înălțimea e fixă, în două variante după cum există sau nu bară de progres, iar textele din configurație sunt scrise ca să încapă în două rânduri fiecare. **Un test verifică lungimea lor**, ca să nu se strecoare altele mai lungi.
- **„Tap this card to open it" a fost scos.** Era o instrucțiune despre interfață, nu despre joc, și mânca spațiul care lipsea textului. În locul ei stă o săgeată mică pe marginea cartonașului, doar când se poate apăsa: semn, nu propoziție.
- **Țelurile lungi au trepte, nu o singură țintă.** Paturi 6→12→20→32→50, grădini 1→2→4, populație 10→20→35→50→80, reparații 1→5→15→40. Când atingi una, apare următoarea. Se afișează cel mai aproape de finalizare: aia e sarcina care se simte la îndemână.
- **Cartonașul nu se golește niciodată.** Când toate treptele sunt atinse, rămâne sarcina permanentă de întreținere a coloniei. Un ecran fără nicio direcție, exact după ce tutorialul s-a terminat, e momentul în care jucătorul închide jocul.
- Tabloul coloniei arată **lista completă de țeluri**; cartonașul arată doar unul. Așa ai și o sarcină la îndemână, și imaginea de ansamblu dacă o vrei.

### D35 — Economia hranei: meseriile capătă rost · DECIS (2026-09-10)
- **Problema:** trei din cinci meserii nu produceau nimic. Pescarul pescuia fără rezultat, grădinarul și hangiul nu aveau unde lucra. O colonie mare nu costa nimic, deci nu exista nicio decizie de administrator.
- **Hrana** e resursa care leagă meseriile de populație. Pescarii produc pe mal, grădinarii într-o **grădină** (clădire nouă, 3×2, două locuri), hangiul ridică moralul întregii colonii din sala de adunare. Masa la bucătărie **costă hrană**; dacă depozitul e gol, colonistul pleacă flămând și se vede, în loc să primească o restaurare gratuită.
- **Bilanțul se arată jucătorului**, nu doar codului: tabloul coloniei afișează intrarea și ieșirea pe minut și câți oameni susține producția curentă. Un depozit care scade încet nu se observă până e gol. Calculul stă în modulul pur `Shared/Modules/FoodBalance`, cu 8 teste, printre care unul care verifică explicit că **colonia de start se susține singură**: o criză în primul minut e o criză pe care jucătorul nu are cum s-o înțeleagă.
- **Factorul de prezență la post** (0,55) e explicit în configurație. Fără el orice socoteală de producție iese de două ori mai optimistă decât realitatea.
- Adevărata presiune nu vine din numărul de producători, ci din **locurile din clădiri**: o bucătărie are două locuri, iar șaizeci de oameni nu încap la ea. Creșterea cere clădiri, nu doar oameni.
- **Bug reparat pe drum:** ținta unui colonist nu distingea între post de lucru și loc unde își rezolvă o nevoie. Grădinarul ajuns la grădină încerca să mănânce din depozit, iar sala de adunare era în același timp postul hangiului și locul de odihnă al tuturor. Există acum un semn explicit pe țintă.
- **Cartonașul de obiectiv** se strânge pe conținut. Înălțimea fixă lăsa două treimi de pergament gol, ceea ce arată a interfață stricată, nu a spațiu de respirație.

### D34 — Niciun pas pasiv, nicio țintă moartă, niciun panou fără ieșire · DECIS (2026-09-10)
- **Pasul „așteaptă constructorii" a fost eliminat.** Un pas în care jucătorul nu are ce face arată identic cu un joc stricat. „Build a tent" se termină acum când cortul e **gata**, iar cartonașul are o bară care se mișcă: fără ea, așteptarea e imposibil de deosebit de un blocaj. Lanțul are 6 pași, nu 7.
- **Meseriile se împart pe rând, nu la întâmplare.** Cu 12 oameni și 5 meserii, alegerea aleatoare poate lăsa colonia fără niciun constructor, iar atunci șantierul nu avansează niciodată. În plus, dacă nu există niciun constructor, pune mâna oricine e liber.
- **Toate semnele arată ținte vii**: plasa liberă, plasa plină, șantierul cel mai avansat, atelierul real. Săgeata dispare când nu există țintă. Înainte arăta spre centrul terenului, adică spre iarbă goală, ceea ce derutează mai tare decât lipsa ei.
- **Escape aparține meniului platformei** și nu ajunge niciodată la joc. Eticheta „Close (Esc)" trimitea jucătorul în meniul Roblox. Fiecare panou are acum un buton de închidere vizibil, tasta Q închide tot, iar butonul din bară comută atelierul.
- **Grămada goală din atelier spune ce e de făcut.** Un dreptunghi negru gol arată a eroare, nu a stare validă.

### D33 — Semnalele duc identități, nu tabele · DECIS (2026-09-10)
- Un `BindableEvent` **copiază** tabelele care trec prin el. `DataService.ProfileLoaded` trimitea `(player, data)`, iar `BuildService` crea cele patru clădiri de start în handler: scrierile intrau în copie și se pierdeau. Simptomele erau o așezare fără nicio clădire și contorul de paturi blocat pe zero, adică exact în altă parte decât cauza.
- **Regula de acum:** un semnal duce o identitate, niciodată un tabel modificabil. Semnalul trimite doar `player`; fiecare handler își ia profilul viu cu `DataService.Get(player)`. Verificatorul pică build-ul pe orice `ProfileLoaded:Connect(function(a, b`.
- Tot aici: `sendState` nu trimitea starea clădirilor. Transmisia de la încărcarea profilului pleacă înainte ca clientul să asculte, deci așezarea rămânea invizibilă până la prima construcție. Acum pleacă și la cererea clientului.
- Bara de butoane se împrospăta pe același remote ca starea de obiective, dar era conectată **prima**, deci citea mereu deblocările vechi. Butonul cerut de pasul curent nu apărea niciodată și jucătorul rămânea blocat definitiv. Anunțul vine acum din interiorul aplicării stării, după actualizarea deblocărilor.
- Plasă de siguranță: **cartonașul de obiectiv e el însuși buton**. Apeși pe sarcină și se deschide exact ce trebuie, fără să depinzi de bara laterală. Dacă bara nu apare din orice motiv, jocul rămâne jucabil.

### D32 — Direcție vizuală, trusă de interfață și onboarding fără tutorial · DECIS (2026-09-10)
**Ce nu mergea:** arta era plată (o singură dală de iarbă uniformă, fără decor), meniurile erau dreptunghiuri gri cu Gotham, iar jucătorul care intra nu avea nicio indicație despre ce să facă. Peste asta, HUD-ul afișa permanent fps și o linie de diagnostic peste lume.

**Arta.** Rampele de culoare se construiesc cu **deplasare de nuanță** (`scripts/art/palette.py`): umbra se rotește spre albastru și crește în saturație, lumina spre galben și scade. O rampă făcută doar din întunecare citește ca o culoare trecută prin filtru de gri, și ăsta e semnul cel mai vizibil de artă amatoare.
- Dalele sunt **bază plată plus fire**, nu pete mari de culoare. Petele mari citesc ca blană de leopard și fac repetiția dalei vizibilă de la distanță. Zgomotul e periodic (sume de sinusuri cu frecvențe întregi), deci dalele se leagă fără cusătură.
- Detaliile se împrăștie cu **distanță minimă** între ele: grămezile de detaliu nu au voie să se atingă pe muchie, altfel apar aglomerări care citesc ca zgomot.
- 14 obiecte de decor se așează determinist din seed (`Shared/Modules/WorldDecor`, testat). Decorul **nu blochează** trecerea: un copac lângă o ușă ar bloca coloniștii, iar jucătorul nu are cum să-l taie încă.
- Apa are trei straturi: dala care curge, un al doilea strat translucid mai lent pentru adâncime, și spumă la linia malului.
- Compunerea alfa era greșită în generator (două umbre translucide suprapuse deveneau negru opac). Corectată.

**Interfața.** Trei schimbări, fiecare cu motiv documentat:
- **Gotham a ieșit.** E fontul implicit **depreciat** al platformei din 2024; înlocuitorul oficial anunțat de Roblox pentru Gotham este Montserrat. Orice interfață pe Gotham arată ca interfața implicită a oricui. Acum: Montserrat pentru titluri, Nunito pentru text, ierarhia din **greutate** (`FontFace` + `FontWeight`), nu doar din mărime.
- **Ramele sunt imagini cu 9 felii**, nu `Frame` + `UICorner`. Un dreptunghi rotunjit nu poate purta textură, iar jocurile de top de pe platformă folosesc chenare desenate, nu chenare procedurale. Trusa: panou, buton în 3 stări, casetă scobită, banderolă, 15 pictograme.
- **Umbra e instanța nativă `UIShadow`**, cu rezervă pe `UIStroke` dacă lipsește.
- Culoarea e **semnal**, nu decor: verde merge, roșu nu-ți permiți, auriu atenția ta acum. Meniul de construcții stinge rândurile pe care nu ți le permiți **înainte** de clic.

**Onboarding.** Lanț de 7 obiective (`Shared/Config/ObjectiveConfig`, evaluat pe server):
- **Un singur obiectiv pe ecran** cât timp jucătorul învață, titlu care începe cu un verb, la prezent.
- **Un singur semn care pulsează** în tot ecranul. Dacă totul strălucește, nimic nu iese în evidență.
- Panourile mari **nu există** până nu sunt necesare. Un ecran plin de butoane la prima intrare e tiparul cel mai des reclamat pe jocurile care pierd jucători în primul minut.
- Sistemul cerut de un pas se deschide **în timpul** pasului, nu după: altfel jucătorul primește o sarcină pe care nu are cum s-o ducă la capăt. Există test pentru asta.
- **Bară de butoane cu pictograme** pe margine: până acum panourile se deschideau doar de la tastatură, iar pe telefon jumătate din joc era inaccesibil. Majoritatea jucătorilor platformei sunt pe telefon.
- Fps și diagnosticul au plecat din HUD în consola de dezvoltare.

**Bug-uri reale găsite și reparate:** `HUDController.SetWorkshop` și `SetAlert` erau apelate dar nu existau (crăpau la fiecare stare de atelier și la fiecare împrospătare a panoului de oameni); promptul atelierului era legat de o poziție din prototip, nu de clădirea reală. Verificatorul de căi a fost extins să prindă `Modul.Functie` unde modulul nu definește funcția — exact clasa asta.

### D31 — Povestitorul, tabloul coloniei și consola de dezvoltare · DECIS (2026-09-10)
- **Povestitorul** (`StorytellerService`) declanșează la 150–260 s un eveniment ales ponderat. Regula fixă cerută de owner rămâne în cod, scrisă în capul fișierului: **niciun dezastru natural**, nimic nu distruge o clădire, nimeni nu moare. Cele 11 evenimente sunt 7 bune, 1 neutru, 3 cu cost mic și reversibil (unelte uzate, nopți agitate, provizii puține).
- Alegerea ponderată stă în modulul **pur** `Shared/Modules/Storyteller` (eligibilitate, pondere, jurnal), testat cu Lune: 8 cazuri noi, 33 de teste în total. Serviciul de pe server păstrează doar efectele și anunțul. Un eveniment nu se repetă până nu trec alte 4.
- **Tabloul coloniei** (tasta C) primește o poză la 2 secunde: populație și paturi, materiale și grămadă, clădiri gata și șantiere, repartiția pe tipuri, nevoile medii, meseriile, numărătoarea până la următorul eveniment și ultimele 5 întâmplări. Se trimit doar 6 intrări de jurnal, nu tot, ca să nu se plimbe degeaba la fiecare push.
- **Consola de dezvoltare** (tasta ` sau F4) are **două porți independente**: panoul nu se construiește în afara Studio, iar `DevService` nici nu conectează handler-ul de remote în producție. Un singur remote `DevCommand`, o comandă pe apel, fiecare cu răspuns scris în jurnalul panoului. Butoanele improvizate din HUD au fost scoase.
- **Scara timpului** (`DevState`, ×1 până la ×60) accelerează scăderea nevoilor, sosirea bărcilor și povestitorul, dar **nu** viteza de mers și nici cronometrele de reparație. Testarea buclei de retenție durează minute în loc de ore. `DevState` e modul frunză, ca `SettlerService` să-l poată cere fără require încrucișat.
- **Un singur panou mare deschis o dată** (`Client/Controllers/Panels`): construcții, oameni, colonie, atelier și consolă se închid reciproc. Fără asta, tabloul și meniul de construcții se suprapun pe aceeași jumătate de ecran.
- **Verificare nouă de cale**: `scripts/check_requires.luau` deserializează place-ul construit și rezolvă fiecare `require` la o instanță reală (120 verificate azi). O cale greșită trece de stylua, de selene și de `rojo build` și se vede abia la rulare, unde oprește tot bootstrap-ul. Intrată în CI, testată cu o cale stricată intenționat.

### D30 — Un sprite per clădire și o foaie de animație cu 12 stări · DECIS (2026-09-10)
- Toate cele 8 clădiri randau același `house.png` și coloniștii aveau un singur ciclu de mers; meniul de construcții nu avea nicio pictogramă. Arta se generează procedural în Python pur (`scripts/art/buildings.py`, `scripts/art/settlers.py`), se urcă prin Open Cloud și se citește din `Assets.buildings` / `Assets.character_anim`. Confirmă D23: mediul și obiectele recognoscibile simple sunt generabile din cod.
- Fiecare `BuildingConfig` id are un sprite cu **aceeași proporție** ca amprenta lui în celule, deci `ScaleType.Fit` umple exact cadrul și pozițiile fracționare ale coșurilor de fum rămân valabile la orice scară.
- Șantierul are sprite propriu (`scaffold`), afișat **în locul** clădirii până la terminare. Varianta veche (clădirea finală, translucidă) nu comunica „încă se lucrează”.
- Foaia de animație: 12 rânduri × 4 cadre de 16×24 — mers și stat în 3 orientări, muncă, cărat, mâncat, dormit, sărbătoare, pescuit. Rândurile din profil se oglindesc pentru stânga (`ImageRectSize` negativ pe X), deci o singură orientare desenată acoperă ambele sensuri.
- Alegerea rândului stă în `AnimConfig.rowFor`, partajat între coloniști și personajul jucătorului. `moving` vine din interpolarea clientului, nu din starea serverului: altfel animația s-ar schimba când ajunge pachetul, nu când se oprește sprite-ul.
- Consecințe: serverul trimite în plus `tk` (felul țintei), altfel clientul nu deosebește „intră în bucătărie” de „intră în dormitor”. Pescarii au primit sarcina reală `fishing` pe malul de sud — deocamdată **fără producție**, doar prezență vizuală; de legat la economie când se decide randamentul.
- Particulele (fum de coș, foc, praf de șantier) rulează pe **o singură** buclă `PreRender` peste o listă, nu o conexiune per clădire.

### D29 — Lumea: hartă 2D liberă, văzută de sus · DECIS (owner, 2026-09-09)
- Se renunță la banda laterală (side-scroll) din brief în favoarea unei **hărți 2D libere, văzute de sus**, ca în inspirația Stardew: iarbă, râul ca bandă orizontală care traversează harta, terenul jucătorului pe malul de sud, orașul spre est. Motive: spațiu real pentru cele 7 sisteme (parcele, clădiri, atelierul orașului, Amonte), personajele celorlalți vizibile, decor cumpărabil; banda se simțea ca un coridor. Râul de sus e mai puțin spectaculos decât din profil, dar plasele rămân lizibile (confirmat de owner pe prototip).
- Tehnic: tile-uri de 48 px logici, hartă 60×40 la prototip (2.880×1.920), coliziuni pe dreptunghiuri (râu, clădiri, margini) în modulul pur `WorldMap`, cameră pe două axe, personaj cu 3 grupuri de cadre (down/up/side), d-pad pe mobil. Serverul (râu pe seed, prindere, date) nu se schimbă.
- Consecințe de propagat în masterplan: 4.1 (arbore GUI și cameră), 5.1 (benzi = rânduri ale benzii de râu), 5.4 (zonele orașului = locuri pe hartă, nu secțiuni de bandă), 8 (artă: tile-uri, sprite-uri 4 direcții, clădiri — cost mai mare), 14 (F4/F5). De făcut la următoarea reasamblare.

### D28 — Plasele: sloturi și tiere · DECIS (praguri PROVIZORII)
- Două axe independente. **Sloturi de plasă** (câte plase simultan): 1 gratuit; al 2-lea la Index ≥ 30%; al 3-lea prin Game Pass „Plasă suplimentară” **sau** la Index ≥ 80% (calea gratuită există; banii cumpără doar accesul mai devreme la spațiu, D20). Terenul are 4 benzi, deci o bandă rămâne mereu neacoperită. **Tiere de plasă** (calitate): Start 8 obiecte / 1,0 pe oră; Meșteșugită 12 / 1,4 (Index ≥ 10%, Materiale); Adâncime 16 / 1,8 (Index ≥ 40%, Materiale rare) — nu se vând pe Robux; timpul de umplere rămâne ≈ 8 h pe toate tierele (D15). [economy-balance, offline-progress]
- **Debit canonic de prinderi** pentru toate estimările până la măsurători: ≈ 15/zi (o plasă Start, 2 colectări), **≈ 25/zi referință pentru simulări**, ≈ 45/zi (3 plase Adâncime); Amonte adaugă 5–10/zi. [calcul propriu din tabelele de mai sus]
- Terminologie: **slot de plasă** (unde stă o plasă), **slot de decor** (decorațiuni de mal cumpărate cu Monede), **slot de atelier** (reparație). Orice „slot de mal” ambiguu se corectează.
- Respins: plase de tier superior vândute ca Game Pass (ar vinde debit de loot, prea aproape de pay-to-win) și plafonul de 2 plase simultan (costul server e neglijabil, acumularea e lazy).

### D17 — Indexul de reparații · DECIS
- **200 de obiecte la lansare**, 7 tiere cu ponderi geometrice (≈ 90% din masă în primele 3–4 tiere). Tierul Secret (și eventual Mitic) e **exclus din „100%"** afișat public, după modelul Fisch. [collection-design]
- **Ponderi recalibrate (2026-09-09)** pentru debitul pasiv al plaselor (T = 25 obiecte/zi, vezi D28), nu pentru cele 150–220/zi presupuse în notă: Comun 53,7% · Neobișnuit 24,8% · Rar 12,8% · Epic 6,1% · Legendar 2,1% · Mitic 0,45% · Secret 0,05% (doar în ferestrele de Inundație). Cu ponderile din notă, primul Legendar ar fi apărut după ≈ 4 luni și primul Mitic după ≈ 2 ani. [calcul propriu, coupon collector; de validat cu simularea din masterplan 6.6]
- **40 de obiecte exclusive de sezon** (10 pe sezon), nu 10: la T = 25/zi ≈ 90% din obiecte sunt descoperite în prima lună, deci coada lungă a Indexului vine din gate-ul de reparație, din exclusivele de sezon (100% cere un ciclu complet de 16 săptămâni) și din conținutul nou, nu din RNG. [calcul propriu]
- Recompense la 10/25/50/75/90/100%. 5 intrări oferite prin tutorial în prima sesiune (endowed progress: 34% vs 19% completare în studiul de referință). [collection-design]
- Procentul de completare e public: clasament pe `OrderedDataStore` actualizat la fiecare reparație finalizată; card de profil vizibil în oraș. [collection-design]
- Variante „shiny" sunt intrări opționale separate, nu condiție pentru 100%. Cadență de conținut după lansare: **10–20 obiecte noi la 2–4 săptămâni** (altfel colecția se epuizează ca motiv de revenire). [collection-design, case-top-games]

### D18 — Atelierul orașului (progres comun) · DECIS (parametri PROVIZORII)
- **12 zone** la lansare, deblocate secvențial, **1–2 seturi active** simultan. Un set cere 5–8 obiecte din 8–12 eligibile afișate (modelul Artisan Bundle din Stardew), ca să nu blocheze dropul aleator. [community-progression]
- Se pot dona doar obiecte **reparate complet** (anti-gunoi prin construcție). **Plafon 40% per jucător per set**: forțează minimum 3 contribuitori și protejează obligația socială de un singur „carry". [community-progression, shared-progress-persistence]
- Recompensă dublă: mică și imediată pentru donator, mare pentru tot orașul la completare. Plachetă cu top 5 contribuitori per zonă (`OrderedDataStore`, `IncrementAsync` pe cheie per jucător, deci fără hot-key). [community-progression]
- **Trickle anti-stagnare**: dacă orașul nu primește nicio donație 72 h, setul activ primește progres pasiv mic (modelul sătenilor din Animal Crossing). Deblocările nu se resetează niciodată. [community-progression]
- Nou-venit într-un oraș avansat: vede istoricul (cine a deblocat ce), primește un „bundle de bun venit" personal și un set activ mereu deschis. Cazul se testează cu oameni reali; nicio sursă nu-l rezolvă. [community-progression, onboarding-ftue]
- E **sistemul fără precedent** din cele 10 jocuri studiate: se testează cel mai devreme posibil, cu cohortă mică, înainte de monetizare. [case-top-games]

### D19 — Sezoane, Amonte, Inundația · DECIS
- Sezonul curent **nu se stochează**: se calculează pe fiecare server din `os.time()` (UTC) și `SEASON_EPOCH`, ciclu de 4 săptămâni; 4 sezoane, an de 16 săptămâni. Fără MessagingService ca sursă de adevăr (livrare best-effort). [seasons-liveops]
- **Inundația**: fereastră lunară derivată determinist (`windowId`), anunțată cu 7 zile înainte (countdown în HUD) și notificare cu 24 h înainte; **kill-switch** `flood_enabled` în ConfigService verificat înainte de orice efect distructiv (singurul rollback instant). Afectează obiectele nefixate ale **tuturor** jucătorilor (inclusiv offline) — altfel nu e obligație de revenire — dar fixarea e o acțiune gratuită, dintr-un tap, iar prima Inundație a fiecărui jucător e cu grație (pierdere zero, doar avertisment). [seasons-liveops]
- **Amonte**: reset zilnic la **UTC fix** (`floor(os.time()/86400)`), nu rulant per jucător (mai simplu, imun la exploatare prin reconectare). [seasons-liveops]
- Season Pass (dacă se face vreodată) = Game Pass permanent cu track resetat logic pe `cycleIndex`; nu în v1. [seasons-liveops]

---

## E. Monetizare, conformitate, legal

### D20 — Monetizare · DECIS (prețuri PROVIZORII)
- Game Passes (permanente, cotă dezvoltator 70%): plasă suplimentară, slot extra în atelier, viteză de reparație. Developer Products (repetabile): materiale rare **deterministe** (nu aleatorii → fără obligații Paid Random Items), skip la timp, extindere temporară de spațiu. Cosmetice (skin-uri de plasă, decorațiuni de mal) ca Passes/Products, nu ca iteme de catalog UGC (Driftwood n-are avatar 3D). [monetization-numbers, monetization-impl, collection-design]
- **Zero pay-to-win** (brief) și **zero paid random items** (nici lăzi, nici pachete cu conținut aleator). [policy-compliance]
- Managed/Regional Pricing activat pe toate produsele; Price Optimization abia la ~60.000 tranzacții/30 zile. [monetization-numbers]
- Bucla zilnică ținește explicit **Creator Rewards**: 5 Robux/zi per Active Spender (≥ 9,99 $ cheltuiți oriunde pe Roblox în 60 zile) care stă 10+ minute și pentru care Driftwood e printre **primele 3 experiențe lansate în ziua aceea de acel jucător** (formularea din CLAUDE.md e corectă; nu e un clasament de platformă). [monetization-numbers, retention-benchmarks]
- Cifre pentru planul financiar: DevEx **0,0038 $/Robux** (din 5 septembrie 2025), minim 30.000 Robux (114 $), o cerere/lună, Tipalti ≈ 5–10 zile lucrătoare; din 1 $ cheltuit de un jucător pe un pass ajung la dezvoltator ≈ **0,21 $**. Rata 0,0054 $/Robux (jucători SUA 18+ verificați, din 8 iunie 2026) se aplică jocurilor „fără personaj vizibil" — Driftwood pare eligibil; **se confirmă prin ticket la Roblox** înainte de a intra în proiecții. [monetization-numbers, monetization-impl]
- Fără Immersive Ads (gândite pentru Workspace 3D, share nepublic), fără Subscriptions în v1. [policy-compliance, monetization-numbers]
- `ProcessReceipt` idempotent într-un singur modul `EconomyServer`; `PromptProductPurchaseFinished` nu e sursă de livrare. Testele de cumpărare se fac cu un produs de 1 Robux pe staging. [monetization-impl]

### D21 — Conformitate · DECIS
- Chestionarul Content Maturity țintește **Minimal/Mild**; se recompletează la orice adăugare de loot plătit sau trading. [policy-compliance]
- Chat: **TextChatService implicit**, fără sistem custom; Roblox gestionează filtrarea și Age Check to Chat. Fără text generat de jucători în UI propriu în v1 (numele orașelor sunt din listă predefinită); dacă apare, trece prin `TextService:FilterStringAsync`. [policy-compliance, platform-2025-2026-features]
- Fără linkuri externe (Discord/YouTube) în joc până la verificarea 16+ a contului și citirea manuală a Community Standards (pagina n-a putut fi verificată automat). [policy-compliance, discovery-marketing]
- Fără trading între jucători în v1 (RMT, gri, abuz; exemplele Fisch și Grow a Garden). [case-fisch-gag, economy-balance]

### D22 — Legal și nume · PROVIZORIU
- Mecanicile se pot copia; expresia nu (Legea 8/1996 art. 9; Tetris v. Xio). Toată arta, textele, numele și muzica sunt originale. [legal-ip-tax]
- Numele „Driftwood": niciun joc Roblox major cu numele exact; căutarea de marcă USPTO/EUIPO a fost neexhaustivă → **audit de marcă plătit înainte de marketing** (DE DECIS: buget). [legal-ip-tax]
- Structură fiscală RO (PFA vs SRL micro, plafon 60k vs 100k EUR incert) → **contabil înainte de primul cash-out**. Venit DevEx declarat în D212. [legal-ip-tax]

---

## F. Conținut

### D23 — Artă · DECIS (estimare revizuită 2026-09-09)
- **Test măsurat (2026-09-09):** o scenă completă generată programatic (teren cu value noise, maluri, apă cu adâncime și curenți, copaci/tufe/stuf/pietre cu umbre, cabană cu fețe luminate, ponton, personaj, pas de lumină caldă + vignetă) s-a produs în **0,78 secunde** de script Python, la o calitate acceptabilă pentru lansare. Estimarea de ~968 h de artă tier 2 din capitolul 8.4 se aplică doar unui flux 100% manual și **nu mai e validă** ca atare.
- Revizuire: **mediul (tile-uri, vegetație, apă, clădiri, lumină, efecte) se generează din cod** — ore, nu sute de ore. Rămân cu adevărat costisitoare, și acolo e nevoie de artist sau de o soluție dedicată: cele ~200 de obiecte care trebuie să fie **recognoscibile individual** (o bicicletă citită ca bicicletă), animația de personaj cu personalitate, și identitatea vizuală (paletă, hero art, icon, thumbnail). Bugetul din 8.4 și 14.3/14.4 se recalculează după alegerea direcției.

- Stil **pixel-art low-res** (sau flat/vector), sprite-uri de obiecte 32–128 px, fundaluri pe straturi de parallax ≤ 1024 px lățime, atlas-uri ≤ 1024×1024. Motive: ~80% din sesiuni pe mobil; rezoluția reală de upload e contradictorie (4K anunțat ianuarie 2026, downscale la 1024 raportat în iunie 2026); diferență de cost ≈ 10× față de hand-painted. [art-pipeline, sprites-assets]
- Pipeline: Aseprite/Affinity (gratuit) → export atlas → **Asphalt** (upload Open Cloud + manifest Luau generat) → `SpriteAtlas.luau`. Upload ca `Image`, nu `Decal`. `SpriteClip2` pentru animații. Preload doar foile de atlas (10–20 ID-uri). [sprites-assets, art-pipeline]
- Faze: placeholder (prototip) → vertical slice (o zonă + 20 obiecte la calitate finală) → lansare (200). Hand-painted doar post-lansare pentru rarități. [art-pipeline]
- Reprezentarea jucătorului: **fără avatar Roblox 3D**; un **sprite 2D de personaj** (16×24 px, 4 cadre de mers, placeholder generat) care merge pe mal, plus card de profil. La pasul 5, personajele celorlalți membri ai orașului sunt vizibile pe bandă. Rămâne „fără personaj 3D vizibil" pentru rata DevEx 18+ (D20). [monetization-numbers, alt-2-5d; revizuit 2026-09-09]

### D24 — Audio · DECIS
- **Noul Audio API** (`AudioPlayer` → `Wire` → `AudioDeviceOutput`, `AudioFader` ca bus), nu `Sound` clasic (marcat intern Legacy). 3 bus-uri: Music, SFX, Ambience, cu slidere persistate. Straturi muzicale pe sezon cu crossfade. Sunete din librăria gratuită (APM, Monstercat) + SFX proprii; „sprite audio" prin `PlaybackRegion` ca să economisească plafonul de upload. [audio]

---

## G. Măsurare, lansare, producție

### D25 — Analytics · DECIS
- Din pasul 1: `LogOnboardingFunnelStepEvent` pe 8 pași (Joined, PlacedFirstNet, CaughtFirstItem, ReachedWorkshop, StartedFirstRepair, FirstRepairComplete, SawOfflineHook, NotificationOptInShown), `LogEconomyEvent` pe fiecare tranzacție, buget ≤ 30 din cele 100 custom events. Funcționează doar din server, doar în joc publicat. [analytics-testing, onboarding-ftue]
- Sub 10 DAU/10 h/7 zile Creator Analytics nu pornește: alpha închis cu **foaie manuală + webhook de erori** (`ScriptContext.Error`). Experiments (A/B) abia peste ~1.000 DAU. [analytics-testing, retention-benchmarks]
- Ținte (ipoteze; Roblox publică doar un exemplu ilustrativ D1 p50 = 12,1%, p90 = 18,7%): prototip — 70% din testeri prind primul obiect în < 2 min; soft launch — D1 ≥ 15%, sesiune mediană ≥ 10 min, D30 ≥ 3%; lansare — D1 ≥ 20%, D7 ≥ 8%. Soft launch-ul durează **minim 45 de zile** (o cohortă D30 completă). [retention-benchmarks]

### D26 — Lansare și marketing · DECIS
- Ordine: Private → Limited/Playtesters (alpha 20 persoane) → Public fără reclame → reclame doar când D1 organic ≥ 15%. Traficul plătit **nu** alimentează semnalele de ranking organic. [discovery-marketing]
- 1–3 clipuri de gameplay (15–20 s) ca video pe Home (lift documentat +30–41% în teste oficiale 2026), icon 512², thumbnail 1920×1080. Share Links per canal pentru atribuire (Audience Expansion Rewards cere 100+ DAU medie 60 zile). [discovery-marketing]
- Buget test Ads Manager: 100–300 $ (1 credit = 263 Robux) ca să măsurăm propriul cost per play; nicio cifră publică de CPP nu există. Game Fund (2021) și Accelerator (2022) sunt defuncte; înlocuitoarele anunțate pe 9 martie 2026 sunt **Jumpstart** (continuu, pentru creatori noi pe Roblox, mentorat + promovare, fără finanțare) și **Incubator** (cohortă de 6 luni). Driftwood se potrivește profilului Jumpstart: **aplicăm după vertical slice**. [discovery-marketing, corectat la verificare]
- Secvența oficială de testare pre-lansare: Closed Access Beta prin Grup → Limited Time Test → Open Access Beta (ascuns din Recommended) → lansare completă. [solo-dev-production]
- Evenimentele de platformă (The Hunt) sunt fereastră de evitat pentru lansare, nu strategie. RDC 2026 e 10–12 septembrie 2026: planul se recitește după. [seasons-liveops, platform-2025-2026-features]

### D27 — Producție · DE DECIS (ore/săptămână)
- Ordinea din brief rămâne obligatorie (7 pași, fiecare cu test pe oameni reali). Planul de producție din masterplan dă două coloane: 15–20 h/săptămână și 40 h/săptămână. Owner-ul alege.
- Reper de durată din postmortem-uri: niciun succes rapid nu a avut scopul celor 7 sisteme interconectate; cel mai apropiat ca profunzime (DOORS, 2 oameni) a durat 1,5–2 ani. Planificare realistă: **9–14 luni part-time** până la lansarea publică, cu învățarea Roblox de la zero inclusă. [solo-dev-production]
- Roblox Group + staging/prod + toolchain se fac **înainte** de pasul 1, nu după. Update-uri post-lansare la 2–4 săptămâni (recomandarea oficială), nu săptămânal. [solo-dev-production]

---

## Întrebări deschise consolidate (răspuns doar din Studio sau de la Roblox)
1. Latența reală de teleport lobby → oraș pe mobil (D10).
2. Câte ImageLabel poolate țin 30 fps pe un Android de 2–4 GB (D05).
3. Rezoluția efectivă de upload pentru imagini pe contul grupului (D23).
4. Eligibilitatea Driftwood pentru rata DevEx 0,0054 $ „fără personaj vizibil" (D20).
5. Comportamentul `ConfigService` la pierderea rețelei: fail-open sau fail-closed (D19).
6. Clonarea ScreenGui-urilor din StarterGui cu `CharacterAutoLoads = false` (D04).
7. Comportamentul `UIDragDetector` peste `ScrollingFrame` (D07).
8. Plafonul real de upload audio pe cont (100/2.000 vs 10 istoric) (D24).
