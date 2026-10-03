<!-- [D74, 2026-10-03] STARE: §9 (așezarea cartierului barajului) e APROBATĂ de owner („ia recomandatele și continuă”); §5 și §7 sunt
aduse la zi cu ea. Pașii 0, 2 și 3 din §7 sunt făcuți; restul, împărțit în j1–j15, k1–k12, l1–l3, e în PLAN-MOTOR-UNIRE §16.
[D70] Hotărârile owner-ului din 2026-09-24 sunt în DECIZII D70 și trec înaintea acestui text acolo unde diferă:
toți pornesc barajul cu aceeași sumă (`START_SUM`, derivată în simulator: 35T pe proba de azi, plus monedele cumpărate cu Robux,
R; „40T la hotărâre” a fost cifra de probă; nu „până la o noapte”); după film rămân primii cinci, ceilalți pleacă; filmul e scurt; de la
Era 4, 3 linii pe eră (două piese + asamblare) și marfa veche dusă de un om pe drum; fiecare eră cu alt cumpărător; din
Era 6 roboții înlocuiesc oameni; Era 8 = drum spre o hartă nouă, racheta pe etape.
[D70] PROPUNEREA INIȚIALĂ, DIN DEZBATERE (2026-09-24). Sinteza unei dezbateri pe Opus 5.5: cinci poziții (regulile, economia,
aspectul și filmul, jucătorul, ingineria), doi critici și o sinteză. Nimic de aici nu e construit; hotărârile owner-ului se
trec în DECIZII D70. [Cifrele din propunere (P ≈ 79B, K = 34,8T) sunt înlocuite: suma de start e `START_SUM` (35T) plus R, iar
nu există un preț al barajului.] Restul se derivă în sim_tycoon.py. -->

# Barajul (Era 4): recomandarea

## 1. Verdictul

**Da, dacă se respectă condițiile de mai jos.** Harta trebuie să se schimbe la Era 4, și nu doar e voie. Simulatorul arată că la finalul Erei 3 cartierele vechi aduc **0,0% din bani** (bobinele 65,3%, curentul 34,6%). Landing și Moara ajung doar drum de mers și desen de încărcat. Fără schimbare, harta ar trece de ~12.000 px până la Era 7. Pontonul, barca și avizierul stau deja la ~4.000 px de locul unde se lucrează în Era 3. Barajul mai împlinește și regula din D64: reperul erei se face din ce ai produs. Satul nu dispare, **devine barajul**.

Condițiile:
- **Alegi tu momentul:** butonul „Build the Dam” se ține apăsat, iar „Not yet” nu are nicio pedeapsă.
- **Serverul schimbă tot într-un singur pas.** Filmul vine abia după și doar arată ce s-a întâmplat.
- **Venitul nu scade niciodată.** Crește de ~16 ori.
- **Nimic plătit sau cosmetic nu se atinge,** iar din profil nu se șterge nimic.
- **Nicio imagine de dezastru** [D69]: satul se desface, nu se dărâmă.

Mă despart de tine într-un singur punct. „Partea mică din bani” nu se obține tăind banii tuturor. Scara ×3000 o dă deja. Se adaugă o singură regulă, pentru toți: **toți pornesc cu aceeași sumă, `START_SUM` (35T pe proba de azi), plus monedele cumpărate cu Robux (R)** [înainte: „păstrezi cât îți aduce o noapte”, înlocuit de D70 Runda 4 și D74].

## 2. Ce trăiește jucătorul

1. **Era 3, pe măsură ce cumperi:** satul se modernizează la vedere, în cinci trepte (secțiunea 5). Fiecare treaptă vine cu un banner și cu „Look (V)”, o privire de 4 s spre Landing.
2. **Power House (~41 min, cu ~12 min înainte de clopot):** la capătul din dreapta al Wire Works apare masa „Dam Plans”. Pe cardul E scrie: *„When the Works Bell rings, your people will take the old village apart and build the Dam with it.”* Lângă ponton apar țărușii topografilor, exact unde va sta zidul.
3. **Tragi Works Bell** (150B, +10%, ceremonia obișnuită). Masa se aprinde cu „Build the Dam (E)”, iar linia NEXT scrie *„Build the Dam — when you're ready”*.
4. **Apeși E** și vezi ecranul cu trei coloane și cifrele tale de pe server (secțiunea 3). Barajul nu are preț: nu plătești nimic, doar suma de start e fixă.
   - **„Not yet”** închide ecranul. Poți juca Era 3 cât vrei.
   - Din acest moment, cardurile de nivel ale clădirilor vechi scriu cinstit *„Goes into the Dam when you build it”* [D46].
   - Welcome back spune regula sumei de start (și că, până la cei 6 oameni noi, satul nu câștigă nimic cât lipsești).
5. **Ții apăsat „Build the Dam” 1,5 s.** Serverul face tot dintr-o dată și salvează. Abia apoi pornește filmul.
6. **Filmul, ~38 s în propunerea inițială.** Butonul „Skip” apare după 3 s la prima vizionare și imediat la reluări. **[O1, 2026-10-03: luat provizoriu ca recomandat: filmul se scurtează la 15–20 s, cu Skip de la secunda 3, în stilul (a), siluete, 2 imagini; cronologia de mai jos e a propunerii de 38 s și se comprimă la pasul k9, PLAN-MOTOR-UNIRE §16.]**
   - **0–2 s.** Cele trei clopote bat pe rând. Intră benzile negre, HUD-ul se stinge, mersul se oprește.
   - **2–9 s.** Pe ecran: *„Look how far you've come.”* Camera trece la scară normală, de la Wire Works la Landing, peste satul modernizat, la amurg. Fără zoom: pe telefon, valea întreagă ar face oamenii de 6×9 px.
   - **9–15 s.** Oamenii ies din colibe și se așază pe mal. Cu apusul în spate sunt siluete, mână în mână, cu numele deasupra. La fiecare pereche se aude un clinchet tot mai sus, iar contorul arată „54 people”. Pe ecran: *„Everyone lends a hand.”*
   - **15–17 s.** Apare un buton mare, „Let's build!”. Dacă nu-l apeși, pornește singur după 3 s.
   - **17–27 s.** De la dreapta la stânga, peste fiecare clădire urcă o schelă.
     - Sub schelă, clădirea devine o grămadă ordonată din marfa ei (`PileView`), pe care oamenii o duc cu roaba spre amonte. Rândurile `push`/`load`/`tip` există deja.
     - Plasele și turbina ies din apă.
     - Câte doi oameni duc fiecare clopot.
     - Decorul tău urcă într-o căruță: *„Your things are safe.”*
     - Taverna pleacă ultima. Pontonul, barca, roata și avizierul nu se ating.
     - Nimic nu cade, nu tremură, nu se prăfuiește.
   - **27–34 s.** Noaptea trece repede spre zori.
     - Barajul crește în 4 trepte, iar lacul se umple până la ponton.
     - Peste deversor curge apă albă.
     - Clopotele urcă pe coamă și bat împreună.
     - Oamenii sar de bucurie, acum în culori (rândul `cheer`).
   - **34–38 s.** Cinci veterani merg la posturi și turbina se învârte. Cartonaș: *„THE DAM · Era 4 · Your people built this.”* Urmează negru, ca la barcă, apoi intri în harta nouă.
7. **Chitanța:**
   - „Last cart: +X” (grămezile și sacul vândute la preț întreg);
   - „Old quests finished: +N pearls”;
   - „You start with 35T” (suma de start, `START_SUM`), plus monedele cumpărate cu Robux încă în mână (R), dacă ai;
   - „Given to the Dam: …” (doar dacă ai peste sumă: C − R − START > 0);
   - „The village adds: …” (doar dacă ai mai puțin: START − (C − R) > 0, completarea);
   - „Income 1.21B/s → ~19.6B/s”.
   (Textele exacte se scriu la k7; cifrele vin de la server, din `DamMath.preview`, PLAN-MOTOR-UNIRE §5 și §16 j14.)
8. **Primele minute din Era 4:**
   - Collector, Porter, Sawyer, Hauler și Innkeeper din Era 1 lucrează deja ca Dam Collector, Dam Porter, Switchman, Barrel Hauler și Dispatcher. Au același nume și aceeași față; treapta veche li se vede ca medalie. (Pylon Runner e o angajare nouă, nu un veteran: duce curentul pe podul cu stâlpi.)
   - Clopotele rămân plăci în clopotnița de pe coamă, cu cifrele tale, **fără quest pe ele** (R11, PLAN-MOTOR-UNIRE §16: „Ring your old bells” cade în fața ordinii `DAM_CHAPTER` din simulator). Quest-urile vin din capitolele 10–12, în ordinea `DAM_CHAPTER` din simulator; ghidajul pornește cu primul tur de mână, în 6 pași (k5).
   - Orice lucru nou costă de ~3000 de ori mai mult, deci pornești aproape de la zero, dar cu venitul mai mare decât înainte.
   - Angajările următoare sunt tot oamenii tăi, pe rând.

## 3. Ecranul „Build the Dam”

**Stays with you**
- Monedele: suma de start (`START_SUM`, 35T pe proba de azi) plus toate monedele cumpărate cu Robux încă în mână (R). Toate perlele.
- Venitul: nu scade, crește.
- Cele trei clopote, ×1,331 pe orice vânzare, pentru totdeauna, și Bigger Sack. Pad-urile rămân `bought`, ca să nu cadă venitul (−24,9%), sacul (60 → 30) și `TycoonMath.era()` (titlul din bâlci).
- Toți oamenii, cu nume și chip. Cinci merg la baraj, ceilalți locuiesc în Dam Town.
- Pontonul, undița, jurnalul peștilor, darurile care te așteaptă, barca spre bâlci, roata și avizierul, pe aceleași coordonate, acum pe malul lacului.
- Decorul cumpărat cu perle, pus pe 10 locuri noi în piața Dam Town.
- Ținutele, Look-ul, titlurile și tot bâlciul. Pass-urile și chitanțele. Stats, Records, Firsts și `Rebirths` (neatins).

**Becomes the Dam**
- Clădirile, plasele și turbina din Landing, Mill și Wire Works, cu nivelurile lor. Rămân scrise în profil; liniile lor se închid printr-un filtru pe lume.
- Meseriile vechi ale oamenilor. Treapta veche devine medalie.
- Marfa din grămezi, magazii și sac, vândută întâi la preț întreg.
- Quest-urile rămase din capitolele 1–9, plătite toate, apoi închise.
- Monedele de peste suma de start (fără R), dacă ai așa ceva: intră în construcție și rămân scrise pe placă, la „Given to the Dam”.
- Harta veche, de 5.520 px. Cea nouă are 3.385 px (cartierul barajului x 880–3065, plus ceața Erei 5 până la 3.385).

**You gain**
- Era 4, cu barajul din primul cadru, prima turbină gratis și cinci veterani la lucru: venitul crește de ~16 ori.
- Dacă ai mai puțin decât suma de start, satul completează diferența („The village adds”).
- O hartă curată, care crește spre dreapta, cu pontonul la câțiva pași de lucru.
- Memory Wall: macheta satului tău vechi și „Watch again”.
- Titlul gratuit „Dam Builder” și poza „Before the Dam” pe cardul din bâlci.

## 4. Banii

**Hotărât în D70 (Runda 4) și D74. Textul inițial al secțiunii, cu „păstrezi o noapte de monede”, e înlocuit.**

**Regula pentru copil:** *„Everyone starts the Dam with the same coins. The rest builds the Dam.”*

- **Toți pornesc cu aceeași sumă:** `START_SUM`, derivată în `sim_tycoon.py` (35T pe proba de azi). E cea mai mare dintre
  costul primelor 5 minute ale erei și o noapte fără pass-uri la Works Bell (`NIGHT_HOURS`), rotunjită în sus.
  - Cine are mai puțin primește diferența.
  - Ce e peste ea intră în construcția barajului, e scris pe placă și e anunțat dinainte, pe ecranul „Build the Dam”.
- **Monedele cumpărate cu Robux trec întregi peste sumă** (`Purchases.coinsBought`, profilul v19): nimic plătit nu se
  taie. Le ține în frâu o poartă a simulatorului, nu o tăiere: în cel mai rău caz (Welcome Back x2 după o zi, cu Long
  Nights și 2x Flow) sar cel mult 40% din Era 4 (`PAID_COINS_MAX_SHARE`). Azi: 32,7%.
- **AWAY e 0 până la cei 6 oameni noi** (cablul și unirea). Ecranul și Welcome back o spun dinainte [D43].
- **Bonusul permanent:** cele trei clopote (+33,1%) rămân. Fără +50%: acela rămâne la renașterea de după Era 8 (§K).

**De ce așa:** o sumă egală face din Era 4 o eră pe care o joacă toți, nu una pe care o sare cine a dormit o săptămână.
Copilul grăbit nu pierde nimic: primește suma întreagă. Nimic plătit nu se taie.

## 5. Harta

**Era 3, cinci trepte.** Sunt doar desen, citite din stare (`ModernMath.stage`, pur), cu simulatorul neatins. Vizitatorii le văd prin `VillageLook.modern`.

| Treapta | Când | Ce se schimbă | Unde se vede | Imagini |
|---|---|---|---|---|
| 1 | Clerk (~4 min) | *Wire comes to every street*: stâlpi cu sârmă pe toate străzile, după modelul `StreetLamps` | și în Wire Works, unde stai | 2 |
| 2 | Thirteenth Net (~14 min) | *Iron carts*: roaba tuturor oamenilor devine cărucior de fier | peste tot | 1–2 |
| 3 | Second Works Porter (~19 min) sau Fourteenth Net (~37 min) | *Tin roofs and brick*: depozitul, gaterul, taverna, Scrap Shed și forja trec în varianta modernă (după varianta de bază și cea grand); dacă imaginea lipsește, rămâne desenul de azi | Look (V) și în film | 5 |
| 4 | Power House (~41 min) | geamuri pe case; țărușii lângă ponton; masa Dam Plans | lângă ponton și în Wire Works | 3 |
| 5 | Primul curent vândut (~48 min) | *The village lights up*: felinarele (există deja), ferestrele și firmele | tot satul | 2 |

- Treapta 0 rămâne identică la pixel (test).
- Amânate: pavajul (cere a doua imagine coaptă pe fiecare felie) și acoperișurile colibelor (~46 de straturi).

**Făcut (2026-09-29), cu cele 18 imagini aprobate de owner pe planșă și de moderare:**
- `ModernController` citește treapta din stare la fiecare `TycoonState`. Când treapta urcă, dă un toast (`Strings.MODERN_STAGE`, treapta 5 o anunță `LAMPS_ON`) și un clinchet.
- `UI/Modern` alege desenul: varianta modernă, geamurile, luminile, căruciorul.
- `UI/ModernProps` desenează stâlpii și sârma, tamburii și stația din curtea Wire Works, masa Dam Plans și țărușii cu sfoara. Sunt 15 stâlpi, de la stâlpul de capăt de vest (x 272) până la ultimul stâlp al Wire Works (x 4760). De la treapta 4, un fir urcă de acolo la izolatorul de pe acoperișul Power House, deci linia pleacă de la clădirea care face curentul.
- Locurile stau în `TycoonConfig` (`wirePoles`, `FIELD_PROPS`, `DAM_PLANS`, `SURVEY_STAKES`) și sunt testate să nu calce nimic. Desenul și punctele de prindere a sârmei stau în `ModernConfig`.
- Macheta din bâlci arată **treapta gazdei** (`VillageLook.modern`), nu pe a vizitatorului.
- **Făcut (2026-09-30): bannerul și „Look (V)”.** Fiecare treaptă urcată (și felinarele aprinse) vine cu un banner (`CeremonyController.PlayMoment`), nu cu un toast. Când locul schimbat nu e pe ecran, bannerul are butonul „Look (V)” și stă 7 s. Tasta V sau o atingere (butonul se vede doar fără meniu deschis) mută camera lin spre satul vechi, o ține acolo 2 s, apoi o aduce înapoi la tine: cam 4 s, cel mult ~5 s peste toată harta (`LookController`, drumul în `GlanceMath`, pur și testat). Camera pleacă de unde e și nu sare niciodată. Dacă pornești la drum, se întoarce pe loc, tot lin.
  - Locul privirii e pe treaptă (`TycoonConfig.modernLookAt`), unul pentru ecranul lat și unul pentru telefon: stâlpii străzii, clădirile, casele cu geamuri.
  - Testul privirii: pe ecranul mare (1600 x 900 de lume) se vede tot ce s-a schimbat; pe telefon (~990 x 460, și 941 x 424), lucrul din anunț (gaterul și forja întregi la treapta 3; casele din mijloc cu geamuri la 4 și 5, deasupra joystick-ului).
  - Anunțul cu Look așteaptă să închizi meniul din care ai cumpărat, iar clopoțelul sună odată cu bannerul. Butonul se hotărăște când bannerul apare (dacă locul nu se vede de unde stai).
  - Bannerele nu se mai șterg unul pe altul: un anunț venit în primele 2,5 s ale altuia (4 s pentru unul cu buton) așteaptă la rând. Fanfara capitolului și a pragurilor 10/25/50 sună odată cu bannerul ei, iar bannerul capitolului vine când închizi Quests (sub panou nu se vedea). Un clopot care înlocuiește un anunț abia apărut îl pune înapoi la rând. Cât stă un meniu (sau fereastra de revenire) peste bannerul cu Look, butonul și tasta V se ascund, apoi revin; cât ține privirea, cardul E nu se vede. Toast-urile ies sub bannerul de pe ecran, iar X-ul ferestrei „Welcome back” o închide.
  - Mersul nu mai rupe încadrarea darului de pe râu (camera sărea ~140 px la primul pas); pe telefon, joystick-ul anunță „ai pornit la drum” doar la prima împingere, ca o tastă.

**După verificator (2026-09-29):**
- **Treapta 3 vine și cu Fourteenth Net.** Al doilea Works Porter e opțional, clopotul nu-l cere. Fără el, satul ajungea la clopot oprit pe treapta 2.
- **Fiecare treaptă urcată se anunță, pe rând, după toastul cumpărăturii.** Treapta 5 are fraza ei („The old village lights up!”). Fraza tace doar când vine odată cu primul curent vândut, fiindcă atunci anunță felinarele.
- **Serverul nu mai trimite starea înainte de profil.** Starea goală de dinainte făcea ca anunțurile (și felinarele) să se repete la fiecare intrare și la fiecare întoarcere din bâlci.
- **Treapta se calculează înaintea oricărei desenări.** Redesenarea schimbă doar desenul și straturile, deci casa care tocmai răsare își păstrează creșterea.
- **Cifrele grămezilor stau în banda textului din lume** (Z 46/47), peste sârmă.
- **Săgeata firului e 3%, nu 6%.** La 6%, firul trecea peste numele „Merchant” și „Clerk” (testat).
- **La est, linia se oprește la ultimul stâlp al cartierului (x 4760), în fața curții Power House.** De acolo până la gard curtea e plină, iar gardul Erei 4 se desenează peste tot ce stă la 42 px de el, deci și peste traversa unui stâlp pus acolo.
- **Tamburii de cablu stau în spatele firelor** (baza la y 1250). Testul recuzitei are acum și banda firelor.
- **Roata de apă a Morii se învârte și după o treaptă nouă.** Redesenarea schimbă desenul doar când treapta îl schimbă, iar o roată rămâne pe foaia ei de mișcare.
- **Ancora stâlpului de capăt de vest** se prinde în pământ în fața bradului de la capătul străzii. E singurul loc liber între brad și taraba Innkeeper-ului.

**Era 4, harta nouă (3.385 px; D74, §9).** Barajul stă **în aval de ponton**, la x 640–880. Am verificat: PIER x300, FERRY x418, WHEEL_STAND x400, VILLAGE_BOARD x486, TREASURE_SLOTS x214 și TAVERN x400 sunt toate la stânga zidului.
- **x 0–640, lacul.** Tot colțul copilului rămâne pe loc, iar barca vâslește tot spre stânga, fără să treacă prin zid.
  - Dam Town stă unde erau taverna și debarcaderul: 3–4 căsuțe, un Canteen și piața cu cele 10 locuri de decor. Textele locurilor se rescriu.
  - Cei 5 veterani au casele sub zid (patru în rând, iar taraba Dispatcher-ului la colțul pieței; D74, punctul 3). Ceilalți oameni ai satului vechi locuiesc în căsuțele din Dam Town, se plimbă pe străzi și apar pe pagina „Your people”.
- **x 640–880, zidul.** Pe coamă stă clopotnița cu cele trei clopote, la mijloc deversorul, la capătul de sud Memory Wall.
- **Râul.** Tot ce vine din amonte, de la navă (cristalul, piesele erelor 5–7), trece lacul și cade peste deversor, deci D64 regula 2 rămâne adevărată. Darurile plutesc încet pe lac și pe puntea de sub baraj și se scot de pe amândouă (`DriftMath` cu porțiunile și `EXIT_X` pe lume; D74, punctul 6), iar `RiverSim` pornește de la piciorul deversorului, tot determinist [D13].
- **x 880–3065, cartierul Erei 4** (2.185 px, nu 1.680). Turbina zidită în fața barajului (prima „plasă”, gratis), Battery Store (D74, punctul 7; planșa îl scrie încă „Dam Store”), Switchyard, Cable Works, cele trei plase de cablu, Relay Station ca o casă-pod peste capătul unui **canal scurt (x 2193–2257)** care intră din râu (acolo nu se mai lovește de ponton), Switch House, Crystal Shed, Kiln, Dam Bell în colțul de nord-est și orășelul pictat din D68 pe malul de nord. Coordonatele, la pixel, sunt în §9.
- **x 3065–3385:** ceața Erei 5 (text neutru, fără nume de eră).

**Erele 5–7:** câte ~2.185 px spre dreapta, cât cartierul barajului (Erele 1–3 aveau 1.680), deci ~9,9k px la Era 7 (3.385 + 3 × 2.185). Fiecare eră aduce și 1–2 atingeri pe baraj și pe lac: lumini, geamanduri, un robot pe coamă, o barjă lângă ponton. Harta continuă să se modernizeze.

**Era 8, „The Launch Site”:** a doua și ultima mutare, dar ca **drum**, nu ca a doua desfacere (oboseala de reset, Diablo 4).
- Se deschide la Sky Dock Bell, cu același ecran și aceeași regulă a banilor.
- Filmul (~25 s): barjele Erei 7 îți duc noaptea oamenii și roboții în aval, pe tiparul `RideScene`.
- Valea barajului rămâne în urmă, ca a doua poză pe Memory Wall.
- Harta nouă e mică: noapte cu stele, canal turcoaz cu dâre de lumină, străzi maglev, case-cupolă și turnul cu nava ta pe rampă.
- Colțul pontonului stă pe aceleași coordonate, cu desen SF: hover-pier (aceeași undiță și același jurnal), hover-skiff spre bâlci, avizier holografic.
- Decorul își păstrează înfățișarea. Barajul se vede departe, la stânga, luminos.
- Pe fiecare pas de lucru rămâne un om lângă robot.
- Costă ~60 de imagini.
- Racheta e renașterea din §K: singura resetare completă a monedelor, tot la alegerea ta.

## 6. Ce se amendează

1. **CLAUDE.md, regula „Nimic nu se pierde”, și TYCOON §1 P2.** Se adaugă excepția scrisă [D70], cum stă acum în CLAUDE.md: *„la schimbarea de hartă aleasă de jucător („Build the Dam”, drumul spre Era 8) toți pornesc cu aceeași sumă (35T pe proba de azi; se derivă în `sim_tycoon.py`, `START_SUM`). Ce e peste ea intră în construcție, e scris pe placă și e anunțat dinainte. Nimic plătit nu se taie, iar venitul crește.”* Monedele cumpărate cu Robux trec întregi (D74, punctul 8). [Textul inițial, „păstrezi monedele până la o noapte de venit”, e înlocuit. **Aplicat în TYCOON P2 (D0, 2026-10-03); în CLAUDE.md există deja.**]
2. **D46 pct. 3:** „nicio cumpărare nu scade venitul” devine „nicio cumpărare **și nicio schimbare de hartă**”. **Aplicat (D0, 2026-10-03), în DECIZII D46.**
3. **TYCOON §K, Dezbaterea 3:** scara „prima renaștere la Era 2/3/4” e depășită de D64. Se adaugă „Barajul nu e renaștere: `Rebirths` nu crește, fără +50%”. Fraza din D70 „poate rămâne cinstită doar ca renaștere” se înlocuiește. **Aplicat (D0, 2026-10-03), în TYCOON §K; în D70 fraza e marcată înlocuită.**
4. **D64 regula 4** („tronsonul următor spre dreapta”): excepții la Era 4 și la Era 8. **Aplicat (D0, 2026-10-03), în DECIZII D64.**
5. **D66 `check_windfall`:** se extinde la pass-uri și la `PAID_COINS_MAX_SHARE` (poarta de 40% a simulatorului pentru monedele cumpărate cu Robux; D74, punctul 8; nu mai există „plafonul K”). La 2026-09-24, cu Long Nights + 2x Flow, o noapte cumpăra 30,2% din Era 2 și 26,0% din Era 3, peste pragul de 25%, și totuși simulatorul ieșea cu 0 (cifre dinainte de curba D71; de re-măsurat). **Amendat în DECIZII D66 (D0, 2026-10-03).**
6. **D68 / PLAN-ERA4, pașii 1–2:**
   - zidul nu mai stă la x 5240–5520, ci la x 640–880 în lumea 2;
   - Spillway Gate devine Build the Dam și nu mai există ca platformă;
   - „Second Turbine” nu mai există: prima turbină e zidită în baraj, gratis (`dam_turbine`, D74, punctul 4), iar a doua a ieșit din eră (D70, Runda 6);
   - Relay Station e o casă-pod peste capătul unui canal scurt (x 2193–2257).
   **Aplicat în PLAN-ERA4 și în D68 (D0, 2026-10-03).**
7. **Textul ceții `dam`** (TycoonConfig, x 5240–5520) se rescrie, de exemplu „The Dam will rise by your pier”. În joc se scrie „take apart / build”, niciodată „demolish” [D69]. **Făcut (D73)** pentru zona `dam` din lumea 1, care rămâne încuiată cât timp Era 4 e în joc; ceața din lumea 2 (`fog5`, x 3065–3385) are text neutru, fără nume de eră.

**De ce rămâne cinstit:** jucătorul alege și apasă ținut. E anunțat cu ~12 minute înainte. Suma exactă se vede înainte de apăsare [D40], iar fiecare monedă are un loc vizibil: „Last cart”, placa [D43]. Nimic plătit nu se taie, venitul crește, iar cine apasă în aceeași zi nu pierde nimic.

## 7. Cum se construiește

**[2026-10-03] Pașii 0, 2 și 3 sunt făcuți. Restul, împărțit în sub-pași cu dependențe și verificări (j1–j15, k1–k12, l1–l3), e în `docs/PLAN-MOTOR-UNIRE.md` §16;** cifrele motorului și ale banilor, în §5 și §11 din același plan. Singurul commit care schimbă jocul viu e l3.

0. **Commit la auditul D67. Făcut** (`git status` curat la 2026-10-03).
1. **Planșele, fără nimic urcat** → PLAN-MOTOR-UNIRE §16, lotul A0.
   - Silueta barajului, cu fața din aval și spumă, ca să nu pară pod.
   - ~6 cadre-cheie ale filmului, compuse în Python după tiparul `preview_d67.py`.
   - Treptele modernizării (făcute și aprobate, 2026-09-29) și previzualizarea pământului lumii 2.
   Le aprobi înainte de cod. Planșa cartierului (`scripts/art/preview_dam_layout.py`) e aprobată (§9, D74).
2. **Modernizarea Erei 3. Făcută (2026-09-29/30)**, cu cele 18 imagini aprobate și urcate: `ModernMath`, `UI/StreetLamps`, foaia căruciorului, lanțul de variante din PadArt, `PlayMoment` + „Look (V)”. Sonda verifică treapta citită din stare și textele; aspectul îl judeci tu.
3. **Numerele, înainte de Era 5, independent de baraj. Făcut (2026-09-29).**
   - `formatNumber` peste Qi: Sx, Sp, Oc, No, Dc, Ud, Dd, Td (până la 10^42), apoi scriere științifică („1e45”), tot în cel mult 5 caractere (`TycoonMath.UNITS`, testat pe citire înapoi până la 10^60).
   - Tabla de venit din bâlci: sutimile se codează (`BoardMath.encodeIncome`: sub 10^12 chiar cifra, deci tabelele vechi rămân bune; peste, exponent × 10^12 + 12 cifre), ordinea se păstrează și codul rămâne sub 2^53. Panoul mare scrie venitul cu unitățile contorului (la Era 3 scria „1200000000.00/s”), iar cel de pe scenă încape în opt litere și cu sufixele de două litere.
4. **Filtrul pe lume** → j6–j10 (serverul, partea pură) și k1–k2 (clientul). Filtrul acoperă mult mai mult decât `PADS` (planul de aici vorbea de „~23 de bucle”): `LINE_PLACES` / `JOIN_PLACES` / `SELLER_PLACES`, `DISTRICTS`, `ZONES`, `homeClearRects`, `streetLamps`, `RoadGraph`, cache-ul de drumuri al `HandRoutes`, râul și darurile, statusurile, quest-urile și controllerele clientului. Lumea 1 trebuie să iasă bit cu bit (martorul j1 și tabelul de aur). Fiecare apelant primește un test pe un profil din lumea 2.
5. **Profilul v19, aditiv** (v18 e seria zilnică, D71) → j4 (și j5, contorul monedelor Robux): `World`, `Memories.oldVillage` (`VillageLook.of` + treapta modernă), `Stats.damGift`, `Purchases.coinsBought`, medalia și legătura veteranului pe `Hands`.
6. **Simulatorul. Făcut** (pasul d al motorului, PLAN-MOTOR-UNIRE §5 și §11): trecerea `dam_transform`, suma `START_SUM`, cele trei rulări și `check_dam`, plus poarta monedelor Robux (`PAID_COINS_MAX_SHARE`, D74). Planul de aici (proxy cu P și K, `check_dam_floor`) e înlocuit.
7. **`DamMath.build` (pur) și serviciul** → PLAN-MOTOR-UNIRE §5 (formula banilor) și §16: j14 (`DamMath.build` / `preview`, cu invarianta „monede noi + dar = C + completare”), j15 (`DamService`, `BuildDam`, plata offline deja făcută, altfel „settling”, `dev "world:2"` + Stop/Play) și k8 (salvare forțată, apoi teleport în același place, pe drumul `FerryService`/`MarkTeleporting`, cu cartonașul final ca TeleportGui).
8. **Ecranul cu trei coloane** → k7 (cifrele vin de la server, textul trece prin `Theme.fitSize`, butonul se ține apăsat) și k6 (cardurile de nivel din Era 3 de după clopot, masa „Build the Dam (E)”).
9. **Filmul** → k9 (15–20 s, O1).
   - `VillageDiorama` se mută în Client/UI (montat și în `fair.project.json`).
   - `DamMath.frameAt(t)` e pur și se aplică direct pe proprietăți, nu prin TweenService. Sonda poate citi atunci orice secundă cu `client "cinematic:seek 12.5"`, chiar cu Studio ascuns.
   - De adăugat: `MusicController.Play`, oprirea mersului, `ReducedMotionEnabled`, lămpile pe un strat deasupra voalului.
10. **Harta lumii 2** → j7–j9 (datele, drumurile, râul și darurile), k1, k10–k12 (pământul copt, macheta pentru vizitatori) și artă A1/A3. Era 4 nu devine `live` fără ea (l3).
11. **Rândurile Erei 4 (D68). Rezolvat** → j2 (23 de platforme și 15 meserii, adormite, cu oglinda din simulator).
12. **Sonda, cap-coadă, pe profil de probă** → l1: Works Bell → Build the Dam → reîncărcare → o absență → vizită în bâlci. Mișcarea filmului o vezi doar tu (l2).

**Arta** (estimare din 2026-10-03; loturile A0–A4 și dependențele lor, în PLAN-MOTOR-UNIRE §16):

| Ce | Imagini |
|---|---|
| Modernizarea Erei 3 | făcută, 18 urcate |
| Reperele lumii 2 (zidul, deversorul, turbina, canalul, stâlpii, orașul pictat, clopotnița, Memory Wall, căsuța, cristalul) | ~13 |
| Filmul | ~12, plus 3 sunete (`music_dam`, ciocănele moi, `sfx_dam_rise`) |
| Pământul copt al lumii 2 | 2 |
| Clădiri, colibe, mărfuri, ținute (pot veni și după lansare) | ~14 + ~20–28 + ~12–15 + 10–15 |
| **Până se joacă Era 4** | **~92–97 de imagini și 3 sunete** |
| **Până la Era 8** | **~330** |

**Ce aștepta D68: rezolvat.** Marfa liniei întâi (curentul dus pe stâlpi, D70 Runda 2), cristalul (se vinde în Era 4, D70 Runda 4), prețurile adevărate (simulatorul: `START_SUM` 35T, primele minute) și așezarea cartierului (§9, D74).

## 8. Întrebări

**[2026-10-03] Întrebările 1, 2 și 4 sunt hotărâte de owner (D70, D74); întrebarea 3 și cele cinci „Le-am hotărât eu” au trecut în pachetul O1 (PLAN-MOTOR-UNIRE §16) și sunt luate provizoriu ca recomandate** („ia recomandatele și continuă”, 2026-10-03).

1. **Banii, când apeși „Build the Dam”:** **HOTĂRÂT (D70, Runda 4, 2026-09-29; D74, punctul 8):** nu (a) și nu (b). Forma e (c), cu o sumă mai mare și fixă: toți pornesc cu `START_SUM` (35T pe proba de azi), plus monedele cumpărate cu Robux (R). Ce e peste intră în baraj, pe placă; cine are mai puțin e completat. Variantele de mai jos sunt cele din propunerea inițială.
   - **(a) recomandat** [înlocuit]: păstrezi tot, până la cât îți aduce o noapte. Ce e peste intră în baraj și rămâne scris pe placă. Cine apasă în aceeași zi nu pierde nimic.
   - **(b)** păstrezi tot, fără limită. Cine așteaptă o săptămână sare o bună parte din Era 4.
   - **(c)** păstrezi o sumă mică, aceeași pentru toți. Contorul coboară sub ochii tăi fix când îți vezi satul desfăcut.
2. **Oamenii, după film:** **HOTĂRÂT (D70, 2026-09-24): (a).** Primii cinci lucrează la baraj, cu numele lor; ceilalți pleacă din lucru și locuiesc în Dam Town. [Atenție: „o noapte după film tot plătește” de mai jos e înlocuit de D70 Runda 4: AWAY e 0 până la cei 6 oameni noi.]
   - **(a) recomandat:** primii cinci din Era 1 lucrează deja gratis la baraj, cu numele lor. Ceilalți locuiesc în Dam Town, iar fiecare angajare nouă e tot unul dintre ei. Venitul crește din prima secundă, iar o noapte după film tot plătește.
   - **(b)** îi angajezi din nou, plătit. Malul e gol, iar venitul e zero până angajezi.
3. **Mână în mână:** **PROVIZORIU, în O1: (a), siluete** (2 imagini), luat ca recomandat; owner-ul poate schimba dintr-un cuvânt.
   - **(a) recomandat:** siluete la apus, cu numele deasupra, apoi valul de bucurie în culorile lor. 2 imagini noi.
   - **(b)** în culori, cu ținutele: un rând nou de animație în ~43 de foi de oameni, reurcate, și în fiecare ținută de acum înainte.
   - **(c)** fără mâini, doar bucuria și roabele.
4. **Era 8:** **HOTĂRÂT ca direcție (D70, 2026-09-24): (a),** un drum spre o hartă nouă, nu o a doua desfacere a satului; detaliile Erei 8 se mai discută.
   - **(a) recomandat:** barjele îți duc oamenii noaptea la The Launch Site, o hartă nouă, mică, SF. Valea barajului rămâne pe Memory Wall. ~60 de imagini.
   - **(b)** valea Erelor 4–7 devine SF pe loc. Peste 200 de imagini, fiindcă fiecare clădire, colibă și plasă cere varianta ei.

**Le-am hotărât eu, dar le schimbi dintr-un cuvânt** (trecute în O1, PLAN-MOTOR-UNIRE §16, luate provizoriu ca recomandate):
- butonul „Not yet”, în loc de un film care pornește singur la clopot: **da**;
- barajul în aval de ponton: **da** (aprobat și prin D74);
- taverna pleacă ultima în zid: **da**;
- filmul de ~38 s, cu „Skip” de la secunda 3: **filmul se scurtează la 15–20 s**, cu Skip de la secunda 3;
- pavajul și acoperișurile colibelor, mai târziu: **da** (rămân amânate, §5).

**Fișiere relevante:**
- `docs/DECIZII.md` (D68, D69, D70, D74)
- `docs/PLAN-ERA4.md` (înlocuit)
- `docs/PLAN-MOTOR-UNIRE.md` (§5, §11, §13, §16)
- `docs/TYCOON.md` (§1 P2, §K)
- `src/Shared/Config/TycoonConfig.luau` (`ZONES`, azi la `:464`; coordonatele lumii 2 vor sta în `WORLDS[2]`, j7)
- raportul simulatorului: `python3 scripts/economy/sim_tycoon.py`; planșa cartierului: `scripts/art/preview_dam_layout.py`

## 9. Propunerea de așezare a cartierului barajului (2026-10-03, APROBATĂ (D74, 2026-10-03))

Făcută cu un workflow: trei cititori (planurile, așezarea Erelor 1–3, testele de așezare), trei propuneri independente
(compactă pe canal, lată, pe terase) și un judecător care le-a verificat cu un verificator de așezare refăcut după
testele jocului. Coordonatele, la pixel, sunt în `scripts/art/preview_dam_layout.py`. Rulat, scriptul desenează planșa
`dam_layout_preview.png` și scrie `dam_layout.json` în scratchpad.

**Aprobată de owner pe 2026-10-03** („ia recomandatele și continuă”, DECIZII D74): răspunsurile la întrebările de mai jos sunt cele recomandate și sunt marcate la fiecare. Coordonatele se pun în joc la j7 (PLAN-MOTOR-UNIRE §16); nimic din joc nu se schimbă înainte de l3.

**Cum se merge, de la vest la est:**
1. Ieși din film la piciorul zidului, la (800, 1180).
2. **Butoaiele:** turbina pe punte, la x 980, zidită în fața barajului. Dam Store și Switchyard stau dedesubt, una sub
   alta, iar veteranii coboară pe aleea zidului.
3. **Cablul:** trei plase deasupra Cable Store-ului, iar Cable Works stă sub el.
4. Butoaiele și cablul merg pe stradă spre est, până la cele două grămezi din stânga Relay-ului.
5. **Relay Station** e o casă-pod peste capătul unui canal scurt (x 2193–2257) care intră din râu.
6. **Pylon Runner-ul** urcă pe aleea cu stâlpi și trece podul spre vest, până la ușa Switch House-ului. Switch House
   stă deasupra intrărilor Relay-ului.
7. **Cristalul** e la capătul de est: plasa, Crystal Shed, Kiln. Ingot Hauler-ul duce lingourile spre vest, peste
   același pod.
8. **Dam Bell** e în colțul de nord-est, lângă ceața Erei 5.

[D74, punctul 7: „Dam Store” de mai sus se numește „Battery Store” în joc; planșa îl scrie încă „Dam Store”.]

**Mărimi și drumuri:**
- Cartierul ocupă x 880–3065 (2185 px, nu 1680), deci lumea 2 are 3385 px.
- Toți oamenii merg pe drumuri, cu cicluri de 4,5–19,4 s, cât în Erele 1–3.
- Turul de mână are 2996 px (~9,4 s); în Era 1 avea 2208.
- Pe verificatorul judecătorului: 0 încălcări, un singur graf de drumuri, niciun drum prin apa canalului.

**Ce mai cere, la pasul j** (acum j6–j10, k1–k2 și k12, PLAN-MOTOR-UNIRE §16):
- un filtru pe lume peste PADS, LINE/JOIN/SELLER_PLACES, DISTRICTS, ZONES, `homeClearRects`, `streetLamps`, RoadGraph,
  cache-ul de drumuri al HandRoutes și testele de așezare;
- canalul în `WorldMap.blockedRects` (CharacterController și VillageDiorama trimit azi `nil`);
- testul felinarelor generalizat dincolo de `for era = 1, 3`;
- fără gard la prima zonă a lumii 2;
- `PadArt.isTurbine` pentru turbina din zid;
- pământul copt în două felii.

**Riscuri:**
- puntea are porțiuni fără plase (x 1028–1332 și cheiul x 1828–2577);
- pe telefon, de la acoperișul Switch House-ului până la ieșirea Relay-ului sunt 476 px, peste cei 460 pe care îi
  arată telefonul;
- Cablemaker-ul și Relay Keeper-ul au pozele inversate față de HandConfig.

**Întrebări pentru owner (ca pași din joc), cu răspunsurile din D74:**
1. **HOTĂRÂT (D74, punctul 1): rămâne cum e.** Ieși din film lângă zid. Până la Relay sunt ~2.600 px de mers (~8 s), iar harta lumii 2 iese de 3.385 px, nu de 2.880.
   Rămâi la asta, sau o vrei mai strânsă, cu drumuri de ~3 s?
2. **HOTĂRÂT (D74, punctul 2): podul cu stâlpi, cu canal scurt sub Relay.** Stai în inelul Relay-ului și iese curentul. Îl duci pe aleea cu stâlpi, peste podul canalului, până la ușa Switch
   House-ului, care stă chiar deasupra Relay-ului. Așa vrei „podul cu stâlpi”, cu un canal scurt sub Relay? Sau fără
   canal: stâlpii doar desenați, iar Pylon Runner-ul merge pe stradă?
3. **HOTĂRÂT (D74, punctul 3): da.** Ajungi la baraj. Casele celor patru veterani stau deja în rând sub zid, cu „veteran” sub nume. Taraba Dispatcher-ului
   e la colțul pieței, iar ceilalți oameni din satul vechi locuiesc în căsuțele din Dam Town. Te bucură așa?
4. **HOTĂRÂT (D74, punctul 4): da.** Pe punte, primul lucru e turbina gratis, zidită în fața barajului, nu plutind ca o plasă. Dam Collector-ul ia
   bateriile de la piciorul zidului. E bine?
5. **HOTĂRÂT (D74, punctul 5): la capătul din dreapta, lângă ceață.** Ultimul pas al erei e Dam Bell (la 4T pe secundă). Îl cauți la capătul din dreapta, lângă ceață, ca la celelalte
   ere, sau sus pe zid, lângă cele trei clopote vechi?
6. **HOTĂRÂT (D74, punctul 6): și de pe lac, și de pe puntea de sub baraj.** Un butoi plutește pe râu. Îl prinzi doar de pe lacul de lângă ponton, sau și de pe puntea de sub baraj, ca azi pe
   toate punțile (D73)?
7. **HOTĂRÂT (D74, punctul 7): „Battery Store”**, nu „Dam Store”; rămân Switchman, Relay Keeper, Pylon Runner, Switch House și Dispatcher.
   (Întrebarea: pe clădirea unde Dam Collector-ul lasă bateriile scrie „Dam Store” sau „Battery Store”? Rămân numele de mai sus?)
8. **HOTĂRÂT (D74, punctul 8)** (vine din PLAN-MOTOR-UNIRE §6, întrebarea 5): monedele cumpărate cu Robux trec întregi peste suma de start (35T), fiindcă nimic plătit nu se taie (D70). Limita de 40% e o poartă a simulatorului (`PAID_COINS_MAX_SHARE`, azi ~33%), nu o tăiere la jucător.

