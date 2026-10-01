<!-- [D68] PROPUNERE, NEAPROBATA. Owner-ul, 2026-09-24: „Nu încă" pentru construcție; marfa liniei întâi e deschisă
(vezi DECIZII D68: varianta recomandată e „curentul, dus pe stâlpi", nu „din curent se fac stâlpi", cum scrie mai jos);
cristalul apare de la finalul Erei 3, nu din Era 1 (amendează secțiunea 8, întrebarea 2). Textul de mai jos e sinteza
panoului de trei designuri, păstrată întocmai ca să se poată relua.
**ATENȚIE:** trecerea în Era 4 (pasul 1 de mai jos) e înlocuită de cererea owner-ului din D70: demolarea filmată și
pornirea de la semi-zero, în dezbatere. -->

# Propunerea finală pentru Era 4, „The Dam"

**Pornire:** Design 2 („Barajul ca zid continuu peste tot râul"), câștigător clar la toate cele trei judecăți (logică 8–8,5, look 9, fit 7–8,5). Am grefat din Design 1 motivul dublu „de ce abia acum" pentru cristale și ideea Radio Beacon ca piesă separată de clopot; din Design 3, disciplina economică (cifre din cod, nu inventate) și — cea mai importantă corecție — renunțarea la o macara nouă, ca să nu se ceară un al treilea fel de platformă. Am verificat personal în cod fiecare afirmație disputată de judecători (nu doar am ales o parte): rezultatele sunt mai jos, la fiecare secțiune unde contează.

---

## 1) În pașii jucătorului

1. Tragi **Works Bell**, iar râul se deschide mai departe spre dreapta: **The Dam**. Se vede deja, de departe, un zid de beton care taie tot râul, cu apă albă țâșnind pe un deversor — prima clădire din joc care nu e o cutie lângă drum.
2. Cumperi **Spillway Gate** — comporta se ridică; povestea ei spune că e sudată din bobinele de sârmă și celulele cu care ai terminat Era 3 (exact ce faci deja, ca la Steam Engine). Apa începe să curgă cu putere printr-un canal spre turbine.
3. **Second Turbine** e gratis și continuă direct numărătoarea lui *First Turbine* din Era 3 — nu e o mașină nouă, e aceeași idee, mai mare, pentru că barajul strânge tot râul într-un canal în loc să lase o roată să plutească liber.
4. Primul tur îl faci tu: aduni curentul (**Charge**) în **Dam Store**, îl duci la **Switchyard** — stai în inel cât se sudează în **Pylon** —, îl cari pe puntea îngustă care iese peste apă până la **Relay Station**, unde-l vinzi Dispatcher-ului.
5. Cei cinci oameni ai liniei vin în câteva minute: **Dam Collector, Dam Porter, Switchman, Pylon Hauler, Dispatcher**.
6. Mai ridici **Third, Fourth, Fifth Turbine**, cumperi niveluri și al doilea om pe fiecare meserie — barajul crește la vedere, cu mai multe rotoare în canal.
7. Cu primul Pylon vândut, ferestrele unui orășel pictat de pe malul celălalt se aprind, una câte una — ecoul felinarelor din Era 3, dar lumina merge la altcineva de data asta.
8. Spre final, o piatră violet cu o luminiță slabă — cea pe care o tot vezi plutind în larg încă din Era 1, fără s-o poți prinde — ajunge, în sfârșit, la îndemână: cumperi **Fifteenth Net**, întărită cu cablu, singura care rezistă în canalul rapid pe care tocmai l-ai făcut. Ridici **Crystal Shed** și **Electric Kiln** — cuptorul electric, alimentat cu propriul tău curent, în sfârșit destul de fierbinte ca să topească cristalul într-un **Crystal Ingot**.
9. Patru oameni noi: **Crystal Collector, Crystal Porter, Crystalsmith, Ingot Hauler** — duc lingoul tot la Relay Station, lângă Pylon.
10. Ridici **Radio Beacon**: nu deschide nimic economic, doar trimite un semnal în amonte spre nava din poveste — ecranul spune cinstit „Signal sent. No answer yet." Abia apoi poți trage **Dam Bell**: +10% la toate vânzările, se deschide tronsonul următor, **The Lab** (Era 5, neconstruită).

---

## 2) Numele

| Ce | Wire Works (Era 3) | The Dam (Era 4) |
|---|---|---|
| poarta erei (plătită) | Steam Engine | **Spillway Gate** |
| prima unealtă, gratis | Eleventh Net | **Second Turbine** |
| magazia | Works Store | **Dam Store** |
| atelierul întâi | Wire Works | **Switchyard** |
| vânzătorul / omul lui | Depot / Clerk | **Relay Station / Dispatcher** |
| linia întâi | minereu de cupru → bobine | **curent → Pylon** |
| unealta liniei târzii | First Turbine | **Fifteenth Net** (plasă întărită) |
| magazia liniei târzii | Battery Shed | **Crystal Shed** |
| atelierul liniei târzii | Power House | **Electric Kiln** |
| linia târzie | baterii → celule de energie | **cristal → Crystal Ingot** |
| oamenii liniei întâi | Works Collector, Works Porter, Wiredrawer, Coil Hauler, Clerk | **Dam Collector, Dam Porter, Switchman, Pylon Hauler, Dispatcher** |
| oamenii liniei târzii | Battery Collector, Battery Porter, Electrician, Power Hauler | **Crystal Collector, Crystal Porter, Crystalsmith, Ingot Hauler** |
| clopotul | Works Bell | **Dam Bell** (precedat de **Radio Beacon**, fără efect economic) |

Am verificat toate numele noi contra `HandConfig.ROLE_OUTFIT` și contra tuturor `Config`-urilor existente: niciunul nu se ciocnește. Am **evitat explicit „Linesman"** — Design 2 original îl propunea pentru Switchman, dar `HandConfig.ROLE_OUTFIT.batteryCollector = "Lineman"` e deja live din Era 3 (o singură literă distanță; exact greșeala pe care Design 1 a evitat-o și pe care am corectat-o aici). Am renunțat și la „Turbine Yard"/„Crystal Vault" (ieșeau din familia deja stabilită *…Store / …Shed / …House*) și la „Crystal Core"/„Twentieth Net" (motivele, la secțiunea 3).

---

## 3) De ce are sens

**Cauzalitate, verificată în cod, nu doar în vorbe.** Al doilea rotor continuă direct numărătoarea lui *First Turbine* — nu e o mașină nouă, e aceeași mecanică pe care ai învățat-o la finalul Erei 3, doar că barajul o strânge într-un canal controlat în loc s-o lase liberă în curent: un copil citește „știu deja asta, doar e mai mult acum" fără nicio cifră. Spillway Gate e povestit ca fiind făcut din bobinele și celulele cu care ai terminat Wire Works — am restrâns flavor-textul la **o singură eră în urmă** (ca la Steam Engine, făcut din „piese de mașini și cupru", nu din tot ce ai produs vreodată în joc): ține regula deja stabilită „începi cu marfa de la finalul erei dinainte" [D64] fără s-o dilueze.

**Două motive pentru „de ce abia acum" cristalul** (grefat din Design 1, adaptat ca să nu ceară cod nou):
1. Cristalul stă în banda din larg, unde nicio plasă n-a ajuns până acum; abia canalul rapid pe care Spillway Gate îl deschide aduce acea bandă la îndemână — motivul e legat direct de clădirea pe care tocmai ai construit-o, nu de „electricitate în general".
2. Electric Kiln are nevoie de curentul propriu al barajului ca să fie destul de fierbinte — exact motivul din roadmap-ul D64 („un cuptor electric le poate topi"), transcris literal.

**Radio Beacon vs. Dam Bell.** Am despărțit cele două, ca în Design 3: *Dam Bell* rămâne mecanic identic cu Landing/Mill/Works Bell (+10%, deschide tronsonul următor) — niciun risc ca „textul nu minte" [D40] să pară o schimbare de regulă. *Radio Beacon* e doar o condiție (`needs.after`) înaintea clopotului, fără rol economic, care trimite semnalul și scrie cinstit „No answer yet" — răspunsul vine abia în Era 5, cum spune roadmap-ul, fără să-l dezvăluie acum.

**Coliziunea de nume cu Era 5, rezolvată prin scop, nu prin improvizație.** Am verificat în cod: Depot-ul Erei 3 vinde deja `id="cell"`, afișat „Power Cell" (`TycoonConfig.luau:121,423`), live din 2026-09-21. D64 zice că Era 5 face „celule de energie" din cristale — cuvântul „cell" nu mai e liber. Am ales ca marfa Erei 4 să fie **„Crystal Ingot"** (un lingou topit, nu un borcan) — nu „Crystal Core" cum propunea Design 2. Motivul: dacă Era 4 ia deja cuvântul „Core", Era 5 rămâne fără el ȘI fără „cell" — două cuvinte arse pentru o singură eră viitoare. Cu „Ingot" la Era 4, **„Core" rămâne complet liber pentru Era 5** (ex. *Energy Core* sau *Crystal Core*, de ales atunci) — soluție mai curată decât a oricăruia dintre cele trei designuri inițiale, de consemnat în D64 ca amendament înainte să înceapă cineva Era 5 crezând vechiul nume valabil.

**Promisiunea „cristalele plutesc din Era 1".** Verificat direct: `RiverRenderController.luau:34` ține un singur `promised: string?` (implicit `"scrap"`), setat cu `SetPromise` — arată mereu UN SINGUR bun, legat de deblocarea imediat următoare. Azi n-ar putea arăta simultan „scrap" (Era 1) și „cristal" (Era 4) pe aceeași bandă. Promisiunea din D64 nu e literalmente adevărată în codul de azi — cere cod nou, mic dar real (secțiunea 7), nu doar text. Las decizia exactă la secțiunea 8.

---

## 4) Cum arată

**Paletă, deliberat opusă lui Wire Works.** Wire Works e cald și închis: fier ruginiu-nituit, sticlă crem, alamă, portelan, cu albastrul curentului ca accent (confirmat în `scripts/art/d67_works.py`: IRON, BRASS, SPARK). The Dam trebuie să citească RECE și MASIV: beton turnat gri-albăstrui în planuri mari, oțel galvanizat argintiu pe turbine și stâlpi, apă turcoaz-adâncă cu spumă albă continuă pe deversor, accent de culoare ROȘU (avertizare, farul, geamurile calde ale orașului de peste apă) — nu albastru cald ca la Wire Works.

**Silueta.** Barajul e primul reper din joc care nu e o „cutie" tip casă/șopron: un zid continuu peste toată banda apei, vizibil de departe cu mult înainte să ajungi acolo (confirmat: harta de azi merge de la `wire_works` 3560–5240 până la `dam` 5240–5520 — deci zidul s-ar vedea deja de la marginea Wire Works-ului). Turbinele stau într-un canal la baza zidului, cu apărătoare metalică — nu mai plutesc liber lângă mal, ca *First Turbine*. Switchyard e o curte cu gard de plasă și transformatoare, nu o hală. Relay Station atârnă la capătul unei punți înguste peste apă, cu geamurile ei mici privind spre orășelul pictat de pe malul celălalt. Electric Kiln n-are fum (arde electric): coș scurt și gros, gură portocalie care **pâlpâie și trosnește** — o „bătaie" de lumină, nu un glow constant ca Power House. Radio Beacon e un turn de zăbrele mai înalt decât orice construit până acum, lumină roșie intermitentă, antenă care se rotește o dată la activare.

**Corectare de nuanță pe punte.** Ambele judecăți au numit puntea „prima geometrie nord-sud din joc" — verificat, e fals: `TycoonConfig.ROADS` are deja `tavern_link` și `iron_lane`, drumuri nord-sud (îngust pe x, lung pe y) care leagă puntea (DECK, y 772–856) de stradă. Ce e cu adevărat nou e altceva: toate drumurile de azi se opresc la marginea uscatului (DECK, y ≥ 772); niciuna nu iese ÎN apă. Relay Station, la capătul punții, ar sta dincolo de acea limită, peste râu — asta cere puțină atenție la adâncimea de desenare (z-order) și la felul cum se randează barca/râul acolo, nu un tip nou de drum.

**Layout de cartier.** Strada rămâne pe malul de sud, cu aceleași piese (*street/lane/plaza*) ca la Moară și Wire Works — angajarea generică nu se schimbă. La capătul ei spre nord, puntea nouă duce la Relay Station, cu zidul barajului ca fundal imens în spatele întregului cartier.

---

## 5) Ce e nou de jucat

1. Linia întâi a erei nu mai pornește cu o plasă aruncată pe mal — pornește direct cu o turbină, mecanica deja cunoscută din finalul Erei 3, la scară mai mare.
2. Pentru prima dată vinzi cuiva din afara satului tău: un orășel pictat, niciodată vizitabil, ale cărui ferestre se aprind cu vânzările tale.
3. Puntea peste apă e primul drum care iese dincolo de mal — o clădire stă, pentru prima dată, deasupra râului.
4. Electric Kiln „bate" în loc să lumineze constant — prima clădire cu propriul ei ritm de lumină și sunet.
5. Radio Beacon deschide clopotul erei fără să aibă rol economic — prima recompensă explicit amânată între două ere, cu text cinstit despre asta.

---

## 6) Cifrele și limitele

**Cadrul.** Verificat în `StationConfig.luau:57`: `ERA3_MULT = 9.000.000`. Aplicând regula deja scrisă în cod (D66: fiecare eră ×3000 față de cea dinainte), **ERA4_MULT = 27.000.000.000 (2,7×10¹⁰)** — nu o inventez, e produsul direct al constantei confirmate. (Design 1 scrisese greșit 27.000.000.000.000, de 1000 de ori mai mare — corectat aici.) Rămâne de reglat prin `sim_tycoon.py`, nu de fixat acum. `ROLE_BASE`, `TIER_COST_BASE`/`GROWTH` (25/75/225/675) și tiparul `UPGRADE_BASE` = 7/60/9 × ERA_MULT sunt deja generice pe orice eră (confirmat, `StationConfig.luau:91-118,400-423`): linia întâi (Dam Collector/Porter/Pylon Hauler) poate moșteni direct 4.0/6.0/9.0 (ca worksCollector/worksPorter/coilHauler), linia târzie (Crystal Collector/Porter/Ingot Hauler) poate moșteni 2.0/2.5/6.5 (ca batteryCollector/Porter/powerHauler) — zero cifre noi de rol.

**Ritm.** Am rulat chiar acum simulatorul real: Era 2 se termină la **47m34s**, venit final 368.610/s; Era 3 la **53m27s**, venit final **1,21 B/s** (creștere ×3283,8 în interiorul erei). Ținta pentru Era 4, pe același trend: undeva între 55 și 65 de minute — cifra exactă vine doar din `--robust`, nu se ghicește.

**Absența de o noapte.** `check_windfall` e deja generic pe orice eră (rulat cu `era=3` pentru Wire Works, confirmat în cod) — va rula automat și pe Era 4 odată ce intră în tabele. N-am cifra reală Eră3→Eră4 (Era 4 nu e în simulator), dar am cel mai apropiat precedent, verificat chiar acum: o noapte la finalul Erei 2 plătește **17,3%** din Era 3 (8h), **21,3%** cu Long Nights, **26,0%** cu Long Nights + 2x Flow — ultima depășește deja pragul de 25% al porții, deși pare tolerat azi pentru cazul special al creatorului (are ambele pass-uri active). Merită verificat explicit dacă Era 4 rămâne sub prag și pentru acel caz, nu doar pentru jucătorul obișnuit.

**Magnitudini — estimare proprie, mai devreme decât au calculat toate cele trei designuri.** Extrapolând regula ×3000: ERA5_MULT ≈ 8,1×10¹³, ERA6_MULT ≈ 2,43×10¹⁷, ERA7_MULT ≈ 7,29×10²⁰ (deja peste plafonul Qi = 1×10¹⁸, confirmat `TycoonMath.luau:543`). Toate cele trei designuri au oprit analiza aici, la „Era 7-8". Dar plafonul relevant nu e ERA_MULT, e **venitul final afișat**, care e de ~130-150 de ori mai mare decât ERA_MULT (raport observat chiar acum: Era 2 → 122,9×, Era 3 → 134,4×, în creștere ușoară). Aplicând acel raport înainte: venitul final al Erei 6 ar cădea în jur de **3-4×10¹⁹** — **deja peste Qi**, cu un era mai devreme decât sugerau toate cele trei propuneri. E o estimare grosieră (de verificat cu simulatorul abia când Era 5-6 vor exista în tabele), dar Era 4 în sine (venit final estimat în zona T, ~10¹²) stă confortabil sub plafon — **nimic de schimbat în `formatNumber` acum**; semnalul e doar să nu se presupună orbește regula ×3000 până la Era 8 fără s-o testa mult mai devreme decât plănuit.

---

## 7) Ce se construiește

**Tabele** (tiparul „N linii" de la D67, fără motor nou):
- `sim_tycoon.py`: ERA4_MULT, ~18 platforme (Spillway Gate, 4 turbine, Dam Store, Switchyard, Relay Station, Fifteenth Net, Crystal Shed, Electric Kiln, Radio Beacon, Dam Bell + cei 9 oameni), stări de aur `--era4`, extinderea `--robust` și `check_windfall(era=4)`.
- `StationConfig.luau`: `ERA_MULT[4]`, liniile „grid"/„crystal" în `LINE_ORDER`/`ERA_LINES`, `PROCESSORS` (Switchyard, Electric Kiln), `SELLERS` (Relay Station).
- `TycoonConfig.luau`: `GOODS` (charge/pylon/crystal/ingot), `CATCH`, cele ~18 platforme cu prețuri din simulator, `CREWS`×9, `PAD_LOOKS_LIKE`/`GOOD_LOOKS_LIKE` (desen de împrumut până la artă), **lărgirea reală a hărții**: `ZONES.dam` e azi doar 280px (5240–5520, verificat) față de cei 1680px ai Wire Works — trebuie extins, cu `RiverConfig.WORLD_WIDTH` crescut și o nouă fâșie de ceață pentru Era 5 dincolo de el.
- `FlowConfig.luau`, `Strings.luau` (LINE_WORDS, NET_WORDS, BUILDING_WORDS, SELLER_WORDS, CREW_HELLO×9), `QuestConfig.luau` — capitolele 10-12 (confirmat: azi sunt exact 9 capitole, ultimul „The Power Line"; propun „The Dam" / „Miles of Cable" / „Cold Fire"), `HandConfig.luau` (ROLE_OUTFIT×9). Profil nou (v19: v18 e seria zilnică, D71).

**Cod nou, nu doar rânduri** (mic, dar real):
1. Decorul „cristal văzut din larg" pe banda îndepărtată, dincolo de `RiverRenderController.promised` (care azi arată un singur bun) — necesar doar dacă se alege varianta „vizibil din Era 1" la secțiunea 8.
2. Recoacerea obligatorie a pământului (`village_ground.py --check`) după orice lărgire de hartă, ca la fiecare eră de până acum.
3. Un flag de tip `firsts.pylonSold` pentru geamurile orașului de peste apă (pe tiparul deja scris `LampController`/`firsts.power`) — cosmetic, opțional pentru un prim build.

**Artă:** ordin de mărime similar Wire Works-ului (54 de imagini): 8 clădiri × 2 (clădire + ruină) = 16, turbina reutilizată ×4, plasa a cincisprezecea (o variantă nouă de sprite pe plasă existentă), 4 mărfuri, zidul barajului (fundal unic), orașul de peste apă (stins/aprins), 9 ținute, colibe/tarabe/încărcături ale echipei (~18-20) — estimat **~55-60 de imagini**.

---

## 8) Întrebări pentru owner

**1. Cristalul — plasă întărită sau macara nouă?**
- **Recomandat:** *Fifteenth Net*, o plasă obișnuită întărită cu cablu de cupru — arată altfel (artă nouă), se comportă ca orice plasă (fără cod nou de randare). Cei trei judecători, independent, au flagat exact costul unei macarale noi (al treilea „fel" de platformă, pe lângă plasă și turbină).
- Alternativă: *Crystal Crane* — o mașină care se apleacă și ridică, mai spectaculoasă vizual, dar cere cod de randare nou (ca turbina pentru Era 3).
- Hibrid: pornești cu plasa întărită acum, macaraua vine mai târziu ca aspect nou al aceleiași platforme, fără cost suplimentar imediat.

**2. „Cristalele plutesc din Era 1" — literal sau doar de la Era 3 încolo?**
- **Recomandat:** rămâne doar promisiune, cu decor mic, nou, dintre debarcaderul satului și banda din larg — literal din Era 1, cum scrie deja D64. Cere cod mic acum (punctul 7.1).
- Mai ieftin: piatra apare abia din Era 3 (când tragi Works Bell), fără cod nou — dar contrazice fraza deja scrisă „văzute pe râu încă din Era 1" din D64, care ar trebui amendată.
- Amânat: se construiește Era 4 fără acest decor acum, adăugat separat oricând — risc: jucătorii care termină Era 4 n-au cum să fi văzut promisiunea vreodată.

**3. Orașul de peste apă — element nou de poveste sau payoff mai simplu?**
- **Recomandat:** orașul rămâne, strict pictat, niciodată vizitabil — geamurile i se aprind una câte una la fiecare Pylon vândut. E cea mai lăudată idee de „look" a tuturor celor trei judecăți, dar e prima așezare din poveste în afara satului tău, deci merită un cuvânt explicit înainte de artă.
- Fără oraș: Pylonii se vând generic („rețelei"), fără element narativ nou — mai ieftin, dar pierde exact payoff-ul lăudat.
- Doar text: orașul există în quest/flavor text, nu ca imagine — cel mai ieftin, dar fără nicio recompensă vizuală nouă.

---

**Verificat direct în cod, nu doar citat din designuri:** `ERA3_MULT=9.000.000`; `ROLE_BASE`/`TIER_COST_BASE`/`UPGRADE_BASE` deja generice; `batteryCollector="Lineman"` live; `id="cell"→"Power Cell"` live; `formatNumber` plafonat la `Qi=1e18`; `RiverRenderController.promised` arată un singur bun; `ZONES.dam` are azi doar 280px; drumurile nord-sud există deja (`tavern_link`, `iron_lane`), dar niciunul nu iese peste apă; ultimul capitol de quest e al 9-lea. Rulat chiar acum: `sim_tycoon.py` confirmă 47m34s/53m27s și cifrele de absență Era2→Era3 (17,3%/21,3%/26,0%) folosite ca precedent, nu ca rezultat final pentru Era 4.