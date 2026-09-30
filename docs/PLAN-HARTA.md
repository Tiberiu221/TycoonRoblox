<!-- [D70] Hotărârile owner-ului din 2026-09-24 sunt în DECIZII D70 și trec înaintea acestui text acolo unde diferă:
toți pornesc barajul cu aceeași sumă (40T la hotărâre, 35T pe prototipurile simulatorului pe 2026-09-29; nu „până la o noapte”); după film rămân primii cinci, ceilalți pleacă; filmul e scurt; de la
Era 4, 3 linii pe eră (două piese + asamblare) și marfa veche dusă de un om pe drum; fiecare eră cu alt cumpărător; din
Era 6 roboții înlocuiesc oameni; Era 8 = drum spre o hartă nouă, racheta pe etape.
[D70] PROPUNEREA INIȚIALĂ, DIN DEZBATERE (2026-09-24). Sinteza unei dezbateri pe Opus 5.5: cinci poziții (regulile, economia,
aspectul și filmul, jucătorul, ingineria), doi critici și o sinteză. Nimic de aici nu e construit; hotărârile owner-ului se
trec în DECIZII D70. Cifrele (P ≈ 79B, K = 34,8T) sunt verificate pe simulatorul de azi; restul se derivă în sim_tycoon.py. -->

# Barajul (Era 4): recomandarea

## 1. Verdictul

**Da, dacă se respectă condițiile de mai jos.** Harta trebuie să se schimbe la Era 4, și nu doar e voie. Simulatorul arată că la finalul Erei 3 cartierele vechi aduc **0,0% din bani** (bobinele 65,3%, curentul 34,6%). Landing și Moara ajung doar drum de mers și desen de încărcat. Fără schimbare, harta ar trece de ~12.000 px până la Era 7. Pontonul, barca și avizierul stau deja la ~4.000 px de locul unde se lucrează în Era 3. Barajul mai împlinește și regula din D64: reperul erei se face din ce ai produs. Satul nu dispare, **devine barajul**.

Condițiile:
- **Alegi tu momentul:** butonul „Build the Dam” se ține apăsat, iar „Not yet” nu are nicio pedeapsă.
- **Serverul schimbă tot într-un singur pas.** Filmul vine abia după și doar arată ce s-a întâmplat.
- **Venitul nu scade niciodată.** Crește de ~16 ori.
- **Nimic plătit sau cosmetic nu se atinge,** iar din profil nu se șterge nimic.
- **Nicio imagine de dezastru** [D69]: satul se desface, nu se dărâmă.

Mă despart de tine într-un singur punct. „Partea mică din bani” nu se obține tăind banii tuturor. Scara ×3000 o dă deja. Se adaugă o singură limită, pentru cine amână: **păstrezi cât îți aduce o noapte**.

## 2. Ce trăiește jucătorul

1. **Era 3, pe măsură ce cumperi:** satul se modernizează la vedere, în cinci trepte (secțiunea 5). Fiecare treaptă vine cu un banner și cu „Look (V)”, o privire de 4 s spre Landing.
2. **Power House (~41 min, cu ~12 min înainte de clopot):** la capătul din dreapta al Wire Works apare masa „Dam Plans”. Pe cardul E scrie: *„When the Works Bell rings, your people will take the old village apart and build the Dam with it.”* Lângă ponton apar țărușii topografilor, exact unde va sta zidul.
3. **Tragi Works Bell** (150B, +10%, ceremonia obișnuită). Masa se aprinde cu „Build the Dam (E)”, iar linia NEXT scrie *„Build the Dam — when you're ready”*.
4. **Apeși E** și vezi ecranul cu trei coloane și cifrele tale de pe server (secțiunea 3), plus prețul barajului.
   - **„Not yet”** închide ecranul. Poți juca Era 3 cât vrei.
   - Din acest moment, cardurile de nivel ale clădirilor vechi scriu cinstit *„Goes into the Dam when you build it”* [D46].
   - Welcome back spune regula nopții.
5. **Ții apăsat „Build the Dam” 1,5 s.** Serverul face tot dintr-o dată și salvează. Abia apoi pornește filmul.
6. **Filmul, ~38 s.** Butonul „Skip” apare după 3 s la prima vizionare și imediat la reluări.
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
   - „You kept 34.8T”;
   - „Given to the Dam: …” (doar dacă e cazul);
   - „Income 1.21B/s → ~19.6B/s”.
8. **Primele minute din Era 4:**
   - Collector, Porter, Sawyer, Hauler și Innkeeper din Era 1 lucrează deja ca Dam Collector, Dam Porter, Switchman, Pylon Hauler și Dispatcher. Au același nume și aceeași față; treapta veche li se vede ca medalie.
   - Primul quest e *„Ring your old bells”*: clopotele de pe coamă au plăci cu cifrele tale.
   - Orice lucru nou costă de ~3000 de ori mai mult, deci pornești aproape de la zero, dar cu venitul mai mare decât înainte.
   - Angajările următoare sunt tot oamenii tăi, pe rând.

## 3. Ecranul „Build the Dam”

**Stays with you**
- Monedele, până la cât îți aduce o noapte, plus toate monedele cumpărate cu Robux. Toate perlele.
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
- Monedele de peste o noapte, dacă ai așa ceva: rămân scrise pe placă, la „Given to the Dam”.
- Harta veche, de 5.520 px. Cea nouă pornește de la 2.880 px.

**You gain**
- Era 4, cu barajul din primul cadru, prima turbină gratis și cinci veterani la lucru: venitul crește de ~16 ori.
- O hartă curată, care crește spre dreapta, cu pontonul la câțiva pași de lucru.
- Memory Wall: macheta satului tău vechi și „Watch again”.
- Titlul gratuit „Dam Builder” și poza „Before the Dam” pe cardul din bâlci.

## 4. Banii

**Regula pentru copil:** *„You keep up to one night of coins. The rest builds the Dam.”*

`păstrat = min(monede − P, K + R)`
- **P** e prețul lui „Build the Dam”, poarta erei, derivat în simulator ca celelalte porți. Water Wheel costă 7K la 111,65/s (63 s), Steam Engine 25M la 368,6K/s (68 s), deci P ≈ 65 s de venit ≈ **80B**.
- **K** e o absență a ta: 8 h sau 16 h (Long Nights) × venitul de la Works Bell, cu 2x Flow dacă îl ai. Dă **34,8T**, 69,7T cu Long Nights și 139T cu Long Nights + 2x Flow. Un pass plătit nu-și pierde valoarea.
- **R** sunt monedele cumpărate cu Robux (One Hour of Flow = 4,36T la finalul Erei 3, Welcome Back x2), numărate de la profilul v18. Producția nu e lansată, deci contorul e complet pentru orice jucător adevărat.

**De ce e semi-zero pentru toți:**
- Copilul grăbit are aproape nimic după clopot. Strânge ~80B într-un minut, apasă și pornește de la ~0, fără să i se ia ceva.
- Copilul care a dormit o noapte vine cu 34,8T. Simulatorul arată un caz identic cu o eră mai devreme: o noapte de la finalul Morii cumpără **17,3%** din Era 3 (21,3% cu Long Nights, 26,0% cu Long Nights + 2x Flow).
- Fără limită, o săptămână de „Not yet” sau o pauză între update-uri ar aduce de 7 ori mai mult sau chiar peste, iar Era 4 s-ar sări. Limita e singurul lucru care garantează „semi-zero”, și atinge doar pe cine a amânat mai mult de o noapte. Ecranul și Welcome back o spun dinainte.

**Bonusul permanent:** cele trei clopote (+33,1%), care există deja. **Fără +50%**: acela rămâne la renașterea de după Era 8 (§K).

**Variante respinse:**
- **O sumă fixă mică (60 de monede) și rebazarea.** Contorul ar coborî sub ochii copilului de la 34,8T la 60, exact când își vede satul desfăcut. S-ar șterge monedele cumpărate cu Robux. Venitul ar scădea la 0,92/s, iar pe tabla din bâlci ar ajunge sub un începător.
- **„1 din 100”.** Textul ar minți pentru copilul grăbit, care ar primi pragul, nu 1%.
- **Un preț după punga ta.** Ar pedepsi copilul care a strâns.

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

**Era 4, harta nouă (~2.880 px).** Barajul stă **în aval de ponton**, la x 640–880. Am verificat: PIER x300, FERRY x418, WHEEL_STAND x400, VILLAGE_BOARD x486, TREASURE_SLOTS x214 și TAVERN x400 sunt toate la stânga zidului.
- **x 0–640, lacul.** Tot colțul copilului rămâne pe loc, iar barca vâslește tot spre stânga, fără să treacă prin zid.
  - Dam Town stă unde erau taverna și debarcaderul: 3–4 căsuțe, un Canteen și piața cu cele 10 locuri de decor. Textele locurilor se rescriu.
  - Pe străzi se plimbă ~12 veterani; toți apar pe pagina „Your people”.
- **x 640–880, zidul.** Pe coamă stă clopotnița cu cele trei clopote, la mijloc deversorul, la capătul de sud Memory Wall.
- **Râul.** Tot ce vine din amonte, de la navă (cristalul, piesele erelor 5–7), trece lacul și cade peste deversor, deci D64 regula 2 rămâne adevărată. Darurile plutesc încet pe lac (`DriftMath.REACH` pe lume, 200–620), iar `RiverSim` pornește de la piciorul deversorului, tot determinist [D13].
- **x 880–2560, cartierul Erei 4.** Canalul turbinelor, Dam Store, Switchyard, Relay Station pe o punte peste canal (acolo nu se mai lovește de ponton) și orășelul pictat din D68 pe malul de nord.
- **x 2560–2880:** ceața Erei 5.

**Erele 5–7:** câte +1.680 px spre dreapta, deci ~7.900 px la Era 7. Fiecare eră aduce și 1–2 atingeri pe baraj și pe lac: lumini, geamanduri, un robot pe coamă, o barjă lângă ponton. Harta continuă să se modernizeze.

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

1. **CLAUDE.md, regula „Nimic nu se pierde”, și TYCOON §1 P2.** Se adaugă: *„Excepția scrisă [D70]: la o schimbare de hartă aleasă de jucător (Build the Dam, Launch Site) păstrezi monedele până la o noapte de venit; ce e peste intră în construcție. Ecranul arată suma înainte să apeși, suma rămâne scrisă pe placă, monedele cumpărate cu Robux trec întregi, venitul nu scade, iar din profil nu se șterge nimic.”*
2. **D46 pct. 3:** „nicio cumpărare nu scade venitul” devine „nicio cumpărare **și nicio schimbare de hartă**”.
3. **TYCOON §K, Dezbaterea 3:** scara „prima renaștere la Era 2/3/4” e depășită de D64. Se adaugă „Barajul nu e renaștere: `Rebirths` nu crește, fără +50%”. Fraza din D70 „poate rămâne cinstită doar ca renaștere” se înlocuiește.
4. **D64 regula 4** („tronsonul următor spre dreapta”): excepții la Era 4 și la Era 8.
5. **D66 `check_windfall`:** se extinde la pass-uri și la plafonul K. Azi, cu Long Nights + 2x Flow, o noapte cumpără 30,2% din Era 2 și 26,0% din Era 3, peste pragul de 25%, și totuși simulatorul iese cu 0.
6. **D68 / PLAN-ERA4, pașii 1–2:**
   - zidul nu mai stă la x 5240–5520;
   - Spillway Gate devine Build the Dam;
   - „Second Turbine” se redenumește, pentru că prima turbină a intrat în baraj [D40];
   - Relay Station stă pe o punte peste canal.
7. **Textul ceții `dam`** (TycoonConfig, x 5240–5520) se rescrie, de exemplu „The Dam will rise by your pier”. În joc se scrie „take apart / build”, niciodată „demolish” [D69].

**De ce rămâne cinstit:** jucătorul alege și apasă ținut. E anunțat cu ~12 minute înainte. Suma exactă se vede înainte de apăsare [D40], iar fiecare monedă are un loc vizibil: „Last cart”, placa [D43]. Nimic plătit nu se taie, venitul crește, iar cine apasă în aceeași zi nu pierde nimic.

## 7. Cum se construiește

0. **Commit la auditul D67, care stă necomis.** `UI/Spin`, `UI/StreetLamps`, `prop_turbine_spin`, `prop_water_wheel_spin` și `PLAN-ERA4.md` sunt `??`, iar `git status` are 57 de rânduri. Pe baza asta se construiește restul.
1. **Planșele, fără nimic urcat.**
   - Silueta barajului, cu fața din aval și spumă, ca să nu pară pod.
   - ~6 cadre-cheie ale filmului, compuse în Python după tiparul `preview_d67.py`.
   - Treptele modernizării.
   Le aprobi înainte de cod.
2. **Modernizarea Erei 3.** Se livrează singură și **nu așteaptă D68**: `ModernMath`, `UI/StreetPoles`, foaia căruciorului, lanțul de variante din PadArt, `PlayMoment` + „Look (V)”. Sonda verifică treapta citită din stare și textele; aspectul îl judeci tu.
3. **Numerele, înainte de Era 5, independent de baraj. Făcut (2026-09-29).**
   - `formatNumber` peste Qi: Sx, Sp, Oc, No, Dc, Ud, Dd, Td (până la 10^42), apoi scriere științifică („1e45”), tot în cel mult 5 caractere (`TycoonMath.UNITS`, testat pe citire înapoi până la 10^60).
   - Tabla de venit din bâlci: sutimile se codează (`BoardMath.encodeIncome`: sub 10^12 chiar cifra, deci tabelele vechi rămân bune; peste, exponent × 10^12 + 12 cifre), ordinea se păstrează și codul rămâne sub 2^53. Panoul mare scrie venitul cu unitățile contorului (la Era 3 scria „1200000000.00/s”), iar cel de pe scenă încape în opt litere și cu sufixele de două litere.
4. **Filtrul pe lume.** `TycoonConfig.padsOfWorld(w)` se pune peste cele ~23 de bucle pe `PADS`, în controllerele Erei 1 scrise de mână (Dock, Storage, Sawmill, Shed, Forge, Pier, Treasure, Drift, Ferry, WheelSignpost) și în Overlay/GuideMath. Lumea 1 trebuie să iasă bit cu bit (tabelul de aur). Fiecare apelant primește un test pe un profil din lumea 2.
5. **Profilul v18, aditiv:** `World`, `Memories.oldVillage` (`VillageLook.of` + treapta modernă), `Stats.damGift`, `Purchases.coinsBought`, medalia și legătura veteranului pe `Hands`.
6. **Simulatorul.**
   - Trecerea se scrie ca funcție în afara lui `buy()`: clopotele, sackBig, cinci veterani pe treapta 1, turbina gratuită, formula banilor.
   - Întâi pe un proxy (rândurile Erei 3 × 3000), ca să iasă P și K; apoi pe rândurile adevărate.
   - Porți: `check_windfall` pe cele trei cazuri de noapte, `check_dam_floor` (venitul de după ≥ 2 × venitul de la Works Bell), 15 cumpărături în primele 5 minute, `--robust`.
7. **`WorldMath.buildDam` (pur) și serviciul.**
   - Teste Lune: se poate repeta fără efect; monedele de dinainte + ce s-a vândut = păstrat + dat barajului; tot ce rămâne e identic; venitul nu scade.
   - `DamService` + RemoteEvent `BuildDam`, validat: tip, ownership, rată, Works Bell, Era 4 `live`, plata offline deja făcută (altfel „settling”).
   - Salvare forțată, apoi teleport în același place, pe drumul `FerryService`/`MarkTeleporting`, cu cartonașul final ca TeleportGui.
   - În Studio: `dev "world:2"` + Stop/Play.
8. **Ecranul cu trei coloane:** cifrele vin de la server, textul trece prin `Theme.fitSize`, butonul se ține apăsat. Plus cardurile de nivel din Era 3 de după clopot.
9. **Filmul.**
   - `VillageDiorama` se mută în Client/UI (montat și în `fair.project.json`).
   - `DamMath.frameAt(t)` e pur și se aplică direct pe proprietăți, nu prin TweenService. Sonda poate citi atunci orice secundă cu `client "cinematic:seek 12.5"`, chiar cu Studio ascuns.
   - De adăugat: `MusicController.Play`, oprirea mersului, `ReducedMotionEnabled`, lămpile pe un strat deasupra voalului.
10. **Harta lumii 2:** geometria, locurile de decor, `RiverSim`/`DriftMath` pe lume, pământul copt (`village_ground` pe lume, `--check`), macheta pentru vizitatori. Era 4 nu devine `live` fără ea.
11. **Rândurile Erei 4 (D68).**
12. **Sonda, cap-coadă, pe profil de probă:** Works Bell → Build the Dam → reîncărcare → o absență → vizită în bâlci. Mișcarea filmului o vezi doar tu.

**Arta:**

| Ce | Imagini |
|---|---|
| Modernizarea Erei 3 | ~14 |
| Filmul, Dam Plans, Memory Wall | ~12, plus 3 sunete (`music_dam`, ciocănele moi, `sfx_dam_rise`) |
| Harta lumii 2, peste D68 | ~10 |
| Era 4 după D68 | 55–60 |
| **Până se joacă Era 4** | **~90–95** |
| **Până la Era 8** | **~330** |

**Ce așteaptă D68:** marfa liniei întâi, cristalul, prețurile adevărate (P, K, primele minute) și așezarea cartierului. Pașii 0–9 pot începe acum.

## 8. Întrebări

1. **Banii, când apeși „Build the Dam”:**
   - **(a) recomandat:** păstrezi tot, până la cât îți aduce o noapte. Ce e peste intră în baraj și rămâne scris pe placă. Cine apasă în aceeași zi nu pierde nimic.
   - **(b)** păstrezi tot, fără limită. Cine așteaptă o săptămână sare o bună parte din Era 4.
   - **(c)** păstrezi o sumă mică, aceeași pentru toți. Contorul coboară sub ochii tăi fix când îți vezi satul desfăcut.
2. **Oamenii, după film:**
   - **(a) recomandat:** primii cinci din Era 1 lucrează deja gratis la baraj, cu numele lor. Ceilalți locuiesc în Dam Town, iar fiecare angajare nouă e tot unul dintre ei. Venitul crește din prima secundă, iar o noapte după film tot plătește.
   - **(b)** îi angajezi din nou, plătit. Malul e gol, iar venitul e zero până angajezi.
3. **Mână în mână:**
   - **(a) recomandat:** siluete la apus, cu numele deasupra, apoi valul de bucurie în culorile lor. 2 imagini noi.
   - **(b)** în culori, cu ținutele: un rând nou de animație în ~43 de foi de oameni, reurcate, și în fiecare ținută de acum înainte.
   - **(c)** fără mâini, doar bucuria și roabele.
4. **Era 8:**
   - **(a) recomandat:** barjele îți duc oamenii noaptea la The Launch Site, o hartă nouă, mică, SF. Valea barajului rămâne pe Memory Wall. ~60 de imagini.
   - **(b)** valea Erelor 4–7 devine SF pe loc. Peste 200 de imagini, fiindcă fiecare clădire, colibă și plasă cere varianta ei.

**Le-am hotărât eu, dar le schimbi dintr-un cuvânt:**
- butonul „Not yet”, în loc de un film care pornește singur la clopot;
- barajul în aval de ponton;
- taverna pleacă ultima în zid;
- filmul de ~38 s, cu „Skip” de la secunda 3;
- pavajul și acoperișurile colibelor, mai târziu.

**Fișiere relevante:**
- `/Users/tiberiubojan/Desktop/Driftwood/docs/DECIZII.md` (D68, D69, D70)
- `/Users/tiberiubojan/Desktop/Driftwood/docs/PLAN-ERA4.md`
- `/Users/tiberiubojan/Desktop/Driftwood/docs/TYCOON.md` (§K, rândul 329)
- `/Users/tiberiubojan/Desktop/Driftwood/src/Shared/Config/TycoonConfig.luau` (coordonatele de la rândurile 267–475 și ceața `dam` de la rândul 440)
- raportul simulatorului: `/private/tmp/claude-501/-Users-tiberiubojan-Desktop-Driftwood/b9d4df87-0fc9-4d56-a2d7-bd3169d84806/scratchpad/sim_plain.txt`