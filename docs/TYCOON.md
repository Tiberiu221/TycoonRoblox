# Driftycoon — planul tycoon

Decis de owner pe 2026-09-11. **Înlocuiește** direcția de colonie (Riverkeep, D29–D44, arhivată).
Sursa de adevăr pentru ce jocul ESTE; `docs/DECIZII.md` rămâne legea pentru ce s-a hotărât și de ce.
Cifrele din §5 vin din `scripts/economy/sim_tycoon.py` — nu se editează de mână, se reglează acolo.

**Cum se citește:** fiecare arie are *Dezbatere* (opțiunile și ce spun dovezile), *Decizie*, *Detaliu*
și *Sarcini* (cu ID, adunate în §8). Marcaje: `[19]` = `docs/research/19-*.md`; `[wipes]` etc. =
`docs/research-survival/*.md` (legenda în §9); **IPOTEZĂ** = design propriu, de validat la playtest.

---

## 0. Fraza, și de ce jocul de dinainte nu se lega

> **This stretch of river is yours. Everything that floats past is money. Build until the whole river pays you.**

Asta trebuie înțeles în primele secunde — și un tycoon o face fără text: vezi o platformă care
strălucește cu un preț, calci pe ea, apare ceva care face bani.

Jocul de dinainte erau **două jocuri sudate**: un nucleu de colecție (râu, plase, reparat, Index) și
un simulator de colonie peste el (nevoi, meserii, clădiri libere, povestitor). Nu exista un singur
număr la care să contribuie toate. Aici există: **monede pe secundă**. Orice sistem care nu îl mișcă,
nu există (§2).

---

## 1. Cele șase principii

Fiecare decizie de mai jos trimite la unul din ele. Dacă o decizie nu poate, e greșită.

| | Principiu | De unde |
|---|---|---|
| **P1** | **Un singur verb central:** prinde → vinde → cumpără → prinde mai mult. | Fisch: un om, ~4 luni, o buclă [37]; checklist-ul de alarmă, punctul 4 [anti] |
| **P2** | **Nimic nu se pierde.** Fără dezastre, fără furt, fără scădere. Offline doar binevoitor. | regula owner-ului; aversiunea la pierdere nu funcționează fără risc real [addictive] |
| **P3** | **Următorul pas e mereu vizibil și strălucește.** Zero tutorial de text. | „Plant": 70,48% pierduți la primul pas, rezolvat cu o iconiță [24]; „next step always visible" [factorio] |
| **P4** | **Banii cumpără viteză, spațiu, aspect** — niciodată noroc sau conținut. | toate trei jocurile mari [19]; norocul e „cea mai clară linie roșie" [money] |
| **P5** | **Râul e motorul, literal.** Obiectele vin pe curent, energia vine din curent. | „pierderea identității de râu" e riscul numit [dir04] |
| **P6** | **Telefon întâi.** | 80% din sesiuni pe mobil [06][ui] |

---

## 2. Regula celor patru motive

**Orice lucru care se poate cumpăra trebuie să facă măcar unul din patru lucruri:**

| Cod | Motiv | Exemplu |
|---|---|---|
| **C** | prinzi mai mult | o plasă nouă, plase mai grele |
| **V** | vinzi mai scump | lada de sortare, gaterul, piața |
| **A** | scapi de o corvoadă | alergătorul, jgheabul |
| **D** | deschizi ce urmează | clopotele de sfârșit de eră (care dau și bonus) |

Și o regulă-soră, pe care simulatorul a descoperit-o singur (§5): **o cumpărare nu are voie
niciodată să scadă venitul** și trebuie să-l crească cu măcar 0,5% — sub prag nu se simte.
Simulatorul oprește rularea cu eroare dacă vreo platformă calcă asta. Asta e răspunsul la
„nu se leagă nimic de nimic": aici nimic nu poate exista fără să se lege de numărul central.

---

## 3. Bucla, pe trei scări

| Scară | Ce se întâmplă | Ce reține |
|---|---|---|
| **Secunde** | un buștean trece, plasa îl prinde, „+1" plutește | recompensă variabilă *garantat pozitivă* — orice prindere valorează ceva, unele sunt rare [addictive][16] |
| **Minute** | strângi, vinzi, cumperi următoarea platformă | „fiecare acțiune se compune cu următoarea" [factorio] |
| **Zile** | seiful se umple offline, renașterea, colecția | plafonul de capacitate [16]; „fresh start effect" [wipes]; colecția [21] |

---

## 4. Ariile

### A. Bucla și economia

**Dezbatere 1 — o monedă sau mai multe?**
Mai multe (monede + materiale + bunuri procesate ca valute) dau adâncime și lanțuri [dir03]. Dar
costul e *complexitatea de înțelegere*, pe care [depth] o cere minimizată, iar 56% dintre utilizatori
au sub 16 ani [ui]. Iar al treilea sistem de progresie adăugat înainte ca bucla de 3–5 minute să fie
testată e primul semnal de alarmă din [anti].
**Decizie: o singură monedă — Coins.** Bunurile procesate sunt obiecte care se vând automat mai
scump, nu valute. „Materialele" de acum dispar: dezmembrarea = vânzare.

**Dezbatere 2 — din ce se fac banii?**
Acum orice prindere e un obiect cu nume, deci niciunul nu e special.
**Decizie:** **bunuri de volum** (buștean, fier vechi, stuf, cioburi) = venitul constant; **obiectele
cu nume** (5% din prinderi) = fluxul de recompensă variabilă. Orice prindere valorează ceva; unele
sunt o întâmplare. Exact tiparul pe care [addictive] îl dă ca aplicabil unui tycoon.

**Dezbatere 3 — cum se stabilesc prețurile?**
Ghicite (cum am făcut prima dată) sau derivate. [23] cere explicit modelare *înainte* de cod, fiindcă
sistemele se cuplează neliniar — și modelul a găsit nouă defecte în prima variantă, cu prețurile
ghicite, fiecare invizibil fără el (lista în §5).
**Decizie:** `preț = venit curent × așteptare-țintă`, rotunjit pe o scară de ~10%, **strict
crescător**. Așteptarea-țintă pornește la ~20 s și urcă spre ~7 min (lacom).

**Dezbatere 4 — ce ritm?**
Ținte: primele 5 cumpărări sub 5 minute [18][24]; sesiuni de 10–60 min, fiindcă algoritmul
plafonează valoarea timpului la 60 min/utilizator/zi [35] și Creator Rewards cere 10+ min [18][26];
prima renaștere în **prima zi**, ca „fresh start"-ul să cadă devreme [wipes].
**Decizie:** cifrele din §5. Factorul lacom→real (1,8×) e **IPOTEZĂ** — se măsoară la primul playtest.

**Sarcini:** A1 `TycoonConfig.luau` (platforme, prețuri, efecte, derivat din simulator) · A2
`TycoonMath.luau`, modul pur: venit, rețea de energie, offline, renaștere · A3 teste Lune care
reproduc simulatorul și păzesc regula celor patru motive · A4 `EconomyService`: registrul de monede,
venitul calculat **pe server** · A5 formatare K/M/B pentru numere mari.

### B. Terenul

**Dezbatere — construcție liberă sau platforme fixe?**
Liberă: flexibilitate. Dar jgheaburile și logica din [dir04] sunt marcate *„cost: mare"*, nu există
nicio dovadă de simulare de acest tip în ScreenGui 2D [dir04][factorio], „mai multe elemente = mai
prost" pe GUI [2d], iar zidul de complexitate din Factorio pierde ~jumătate din jucători [factorio,
neverificat]. Fixe: tipar clasic Roblox, lizibil, iar „chunking-ul spațial" (terminale fizice
separate, vizibile dar blocate) e soluția [ui] pentru hub-uri cu multe sisteme.
**Decizie: platforme fixe, în 4 zone. Fiecare eră e un cartier. Zonele viitoare se văd, estompate
și îngrădite** — vizibil-dar-blocat [ui], iar bucla deschisă trage înapoi (Ovsiankina, ~67% reluare
[addictive]).

**Detaliu:**
- Râul pe latura de nord (banda existentă, `RIVER_TOP=480..768`), malul dedesubt.
- **Zona 1 — The Landing**, lângă spawn, la vest. **Zona 2 — The Mill**, în centru, lângă apa rapidă.
  **Zona 3 — The Yard**, la est. **Zona 4 — The Harbor**, în aval.
- **O platformă** = pătrat strălucitor pe sol + pictogramă + nume + preț. Stări: *ascunsă →
  contur estompat → următoarea (strălucește) → accesibilă (pulsează) → cumpărată (construită)*.
- Se văd mereu **1–3 platforme** active — niciodată mai mult de două niveluri de dezvăluire [ui].
- **Cumperi călcând pe ea** (sau apăsând, pe telefon). Fără bani: prețul roșu + un inel de progres
  cât de aproape ești.
- **O singură metodă de cumpărare pentru tot**, inclusiv upgrade-uri („Sawmill II" e o platformă
  lângă gater). Un singur verb.

**Sarcini:** B1 harta celor 4 zone pe `RiverConfig.PLOT` · B2 `PadService` (server): lista, ordinea,
validarea, efectul, persistența · B3 `PadController` (client): stări, preț, inel de progres,
cumpărare la contact · B4 garduri și estompare pe zonele blocate · B5 teren desenat ca **o singură
unitate cu origine proprie**, ca mai multe terenuri pe un server să fie posibile mai târziu (arie R).

### C. Progresia

**Dezbatere — un drum sau ramificații?**
Ramificațiile dau autonomie, iar autonomia prezice plăcerea (B=.41 [addictive]). Dar prea multe
alegeri paralizează un public tânăr, iar [ui] limitează dezvăluirea la două niveluri.
**Decizie: drum aproape liniar, cu bifurcații mici** — în orice moment 1–3 platforme deodată
(„a treia plasă *sau* lada de sortare"). Autonomie fără paralizie.

**Detaliu — cele 48 de platforme** sunt în §5, cu prețul, motivul și momentul estimat.
**Clopotele** închid fiecare eră: dau un bonus permanent (+10/15/20/25%) **și** deschid zona
următoare — ca să nu fie niciodată o cumpărare goală, cea mai scumpă din eră.

**Sarcini:** C1 cele 12 platforme ale Erei 1 · C2 Era 2 · C3 Era 3 · C4 Era 4 · C5 ceremonia de
clopot (animație, sunet, zona nouă se luminează).

### D. Râul și ce aduce

**Detaliu:**

| Bun | Valoare | Pondere | De unde |
|---|---|---|---|
| Driftwood | 1 | 70% | orice bandă |
| Scrap | 2 | 13% | banda 2 (Far-Lane Net) |
| Reeds | 2 | 8% | orice bandă |
| Shards | 2,5 | 4% | banda 3 (Deep Channel) |
| obiecte cu nume | ~14 (media pe tiere) | 5% | orice bandă; mai multe rare pe canalul adânc |

- Râul rămâne **determinist pe seed** și prinderea se decide pe server [D13].
- Obiectele cu nume sunt `ItemConfig` (36 azi, ținta 200 [D17]), cu tiere geometrice [21].
- Benzile se deschid cu platforme: banda 2 în Era 1, banda 3 în Era 3.

**Sarcini:** D1 `GoodsConfig.luau` · D2 `RiverSim` scoate bunuri de volum, nu doar obiecte cu nume
· D3 valoare de vânzare per tier în `ItemConfig` · D4 banda 3 și ponderea mai mare de rare pe ea.

### E. Plasele

**Detaliu:** o plasă are bandă, rată de prindere și capacitate. Capacitatea contează de două ori:
când o golești de mână (plasa plină nu mai prinde — corvoada pe care o rezolvă automatizarea) și
offline (plafonul real, nu ceasul [16]). Upgrade-uri globale: Weighted (+30%), Wide (+40%),
Deep (+30% și mai multe rare).
Plasele *Deep* cresc șansa de rare — dar se câștigă în joc, nu se vând. Linia roșie din [money] e
**vânzarea** norocului, nu existența lui.

**Sarcini:** E1 plasa ca obiect cu rată/capacitate/bandă · E2 cele trei upgrade-uri globale ·
E3 capacitatea vizibilă (`8/12`) pe plasă.

### W. Vânzarea (debarcaderul)

**Dezbatere — vânzare instant sau cărat la debarcader?**
Instant: zero fricțiune. Cărat: o primă buclă fizică — strângi, mergi, vinzi — care dă debarcaderului
un rost și primei automatizări un scop limpede: *scapi de drum*. „Nu lăsa niciodată un proces manual
neautomatizat" e reflexul pe care îl instalează automatizarea bună [factorio]. Precedentul direct:
Lumber Tycoon 2 — tai, cari la punctul de predare, vinzi; 1,3 miliarde de vizite [landscape].
**Decizie: cărat în Era 1** (un sac cu capacitate), automatizat de alergător, apoi de jgheab.

**Detaliu:** debarcaderul e **gata construit de la început** (altfel nu poți vinde ca să cumperi
prima dată). Multiplicatori de preț: Sorting Crate +20%, Dock Stall +25%, Market +25%, Dockhand +20%,
Lighthouse +25%, Grand Market +30%.

**Sarcini:** W1 sacul (capacitate, afișat pe HUD) · W2 debarcaderul: vânzare la interacțiune ·
W3 multiplicatorii de preț · W4 „+N" care zboară de la debarcader la contorul de monede.
*(Aria se numește W, nu F, ca sarcinile ei să nu se confunde cu fazele F0–F9.)*

### G. Procesarea și energia

**Dezbatere 1 — fabrică liberă sau stații fixe?** Aceeași ca la B. **Stații fixe**, cu ce e mai bun
din [dir04]: roata de apă care produce energie din curent și stații care se îmbunătățesc pe loc.

**Dezbatere 2 — upgrade de viteză sau de valoare?**
Simulatorul a răspuns singur: la stațiile secundare (fierul vechi e 13% din prinderi) capacitatea
nu e niciodată blocajul, deci un upgrade de viteză **nu face nimic**. Prima variantă avea trei
upgrade-uri goale din cauza asta.
**Decizie: upgrade-urile cresc valoarea, nu viteza — cu excepția stației care chiar e blocajul**
(gaterul, care primește 70% din tot). Morarul, la fel: *calitate*, nu viteză.

**Dezbatere 3 — cum se împarte energia?**
Prima variantă: energia insuficientă încetinea *toate* stațiile egal. Rezultat: „Smelter II"
**scădea** venitul după ce plăteai.
**Decizie: rețeaua dă energie întâi stațiilor care scot cea mai mare valoare pe unitate de energie,
și o stație consumă doar pe ce procesează efectiv.** Consecința de care depinde tot: a adăuga
capacitate sau energie nu poate niciodată să scadă venitul.

**Detaliu:**

| Stație | Primește | Multiplicator | Energie / bucată |
|---|---|---|---|
| Sawmill | driftwood → scânduri | ×3 | 4 |
| Smelter | scrap → lingouri | ×3 | 5 |
| Loom | reeds → pânză | ×3 | 6 |
| Kiln | shards → ceramică | ×3 | 8 |

- Gaterul merge și fără energie, la 35%, **cu manivela** [dir04] — altfel prima stație ar fi o
  cumpărare goală până vine roata.
- Energie puțină = stațiile încetinesc, **niciodată nu se strică** (soft-fail [dir04]). Se vede un
  „Low power" — presiunea de sistem vizibilă e ce face automatizarea satisfăcătoare [factorio].
- Roțile se pun **exact unde cererea trece de ofertă** — trei, nu cinci. Și *după* ce jucătorul a
  simțit lipsa câteva platforme: pusă chiar la trecere, a doua roată adăuga 0,3%.

**Sarcini:** G1 `StationService` + rețeaua de energie (alocare pe valoare) · G2 cele 4 stații ·
G3 manivela · G4 afișajul de energie și „Low power" · G5 upgrade-urile de calitate (Fine Ingots,
Fine Cloth, Glazed Pottery) · G6 Sawmill II (capacitate) · G7 jgheabul ca traseu fix, nu plasat.

### H. Atelierul și colecția

**Dezbatere — cum se leagă colecția de numărul central?**
Acum reparatul dă o intrare în Index și atât. Frumos, dar paralel cu tycoon-ul.
**Decizie: fiecare obiect distinct din Index = +1% venit, permanent, și supraviețuiește renașterii.**
Colecția intră în numărul central fără să devină obligatorie.

**Detaliu:** obiectele cu nume ajung în grămadă; fiecare: **Sell** (monede acum, pierdut) sau
**Repair** (timp, intră în Index pentru totdeauna). Sloturile de reparat, pragurile de 25%/50% și
cartonașul de colecție **există deja** și rămân. Atelierul apare *exact când* prinzi primul obiect cu
nume — la momentul potrivit, nu înainte [onboard].

**Sarcini:** H1 bonusul de Index în venit · H2 atelierul apare la prima prindere cu nume · H3 prețul
de vânzare al obiectelor cu nume · H4 cele 36 de siluete de obiecte (amânate de owner) · H5 extinderea
catalogului spre 200 [D17].

### I. Angajații

**Dezbatere — oameni simulați sau automatizare cu chip?**
Coloniștii aveau nevoi, plecau, mâncau. Dar aversiunea la pierdere nu funcționează fără risc real
[addictive], iar regula owner-ului interzice riscul real — deci nevoile adăugau doar corvezi.
**Decizie: angajați fără nevoi, fără plecare.** Îi cumperi, fiecare rulează o stație, poartă
ținuta meseriei. Arta pe straturi (D44) își găsește rolul.

**Detaliu:**

| Rol | Ținuta (D44) | Ce face |
|---|---|---|
| Runner | pescar — bor lat, albastru | golește 3 plase și le duce la debarcader |
| Miller | constructor — cască galbenă | +20% valoare procesată |
| Dockhand | hangiu — bandă, fără pălărie | +20% la vânzare |
| Crafter | meșteșugar — bonetă | grăbește reparațiile (mai târziu) |

**Primul angajat vine pe mal și îți spune o replică** — cererea owner-ului de la începutul
proiectului („un NPC care vine și vrea să lucreze la tine") păstrată, dar fără să blocheze primul minut.

**Sarcini:** I1 `HandService` (din `SettlerService`, fără nevoi/plecare/hrană) · I2 angajatul merge
la stație o dată, apoi lucrează pe loc · I3 cele 4 roluri · I4 replica primului angajat.

### J. Offline și revenirea

**Dezbatere — cât produce colonia cât lipsești?**
Tot venitul (generos, dar fără motiv să revii), o fracție, sau plafonat de capacitate. [16]:
plafonul principal trebuie să fie **capacitatea**, nu ceasul; Grow a Garden e validarea la cea mai
mare scară [16][20]. Și „recompensele zilnice simple nu funcționează" [16].
**Decizie: producția automatizată curge offline în Seif (Vault), 100%, până se umple — ~8 h la
capacitatea de bază.** Plasele de mână se umplu și ele până la capacitatea lor. Doar ce e
automatizat produce offline — încă un motiv să automatizezi.

**Detaliu:** la revenire, *„Your river earned 12.4K while you were away"* cu un buton de colectare.
Capacitatea Seifului se mărește prin platforme și printr-un pass (spațiu [P4]).

**Sarcini:** J1 Seiful (capacitate, umplere) · J2 calculul offline pe `OfflineCalc`, pe capacitate ·
J3 ecranul de bun venit în monede · J4 upgrade-urile de Seif.

### K. Renașterea — „Move Downstream"

**Dezbatere 1 — ce se resetează?**
În toate cele șase jocuri analizate nu se resetează niciodată identitatea, cosmeticele și **nimic
din ce s-a plătit cu bani reali** [wipes]. Un reset forțat care șterge ce ai plătit e și risc legal,
cu 73% dintre utilizatorii verificați sub 18 ani [wipes].
**Decizie:** se resetează monedele, platformele, stațiile, angajații. **Rămân:** Indexul și
bonusul lui, numărul de renașteri, cosmeticele, tot ce e plătit.

**Dezbatere 2 — cât bonus?**
Exponențial (×2 la fiecare) sau liniar. [wipes] recomandă **liniar**, ca fiecare renaștere să rămână
relevantă. **Decizie: +50% venit per renaștere, aditiv.** Tura 2 e cu ~40% mai rapidă.

**Dezbatere 3 — când?**
Doar la Charter (~6,5 h) = mulți nu o văd niciodată. După Era 1 = prea ieftin.
**Decizie: scară de cerințe** — prima renaștere cere Era 2 (~1h15m), a doua Era 3, a treia Era 4.
Recompensă devreme, coadă lungă. Fiecare tură merge o eră mai departe în ~2 h (§5).

**Dezbatere 4 — cum să nu se simtă ca pierdere?**
Reset impus și fără sens = respins (*„I want to start Diablo again. Not restart the Season."*
[wipes]). Anunț din timp, un ecran care spune ce rămâne / ce se mută, și un motiv tematic [wipes].
**Decizie:** tematic, **te muți în aval**, pe un tronson mai bogat. Ecranul de tranziție listează
*Stays / Resets / You gain*. Și fiecare renaștere **adaugă conținut** — un set nou de obiecte pe râu,
prinse doar după ea — nu doar un număr [depth: conținut nou peste cel vechi].

**Sarcini:** K1 `RebirthService` · K2 ecranul Stays/Resets/You gain · K3 scara de cerințe · K4
bonusul liniar · K5 setul de obiecte deblocat de fiecare renaștere.

### L. Primele cinci minute

**Dezbatere — dialogul de deschidere rămâne?**
Owner-ul a cerut un NPC la început. Dar dialogul de 4 replici blochează jucătorul fix în secundele în
care trebuie să se distreze [24]: *„get to the fun quickly"*.
**Decizie:** o singură frază pe ecran + prima platformă strălucind. NPC-ul vine ca **primul angajat**
(platforma 6, ~4 min), cu o replică.

**Detaliu — scenariul, cu momentele din simulator (real estimat):**

| Când | Ce vede | Ce face |
|---|---|---|
| 0:00 | fraza + săgeata spre *First Net — FREE* | calcă pe platformă, plasa cade în apă cu stropi |
| 0:20 | primul buștean, „+1" | — |
| 0:40 | *Collect (E)* pe plasă | strânge în sac |
| 0:50 | săgeata spre debarcader, *Sell (E)* | vinde; monedele zboară spre contor |
| ~0:41 | *Second Net — 9* se aprinde | cumpără |
| ~3:18 | a 5-a cumpărare (Sorting Crate) | — |
| ~4:19 | *First Runner* — primul angajat vine și vorbește | automatizarea începe |
| ~8:24 | primul obiect cu nume → apare *Workshop* | decizia vinde-sau-păstrează |

- **Indiciu după 11 secunde de blocaj** — pentru o acțiune care durează normal ~10 s [onboard].
- Vizual > text, mereu [24][onboard].

**Sarcini:** L1 fraza de deschidere · L2 săgeata și strălucirea primei platforme · L3 indiciul de 11 s
· L4 atelierul la prima prindere cu nume · L5 replica primului angajat · L6 pâlnia pe platforme în
analytics (arie T).

### M. Interfața

**Detaliu:**
- **HUD:** monedele, mari; sub ele venitul pe secundă (*+12/s*); sacul (*8/30*); energia din Era 2.
- **Dispar:** cele cinci cifre de colonie (Food, Materials, Salvage, People, Beds), cartonașul de
  obiective, panourile Build / People / Colony.
- **Bara din dreapta:** Workshop, Collection, Shop, Rebirth (când e disponibilă), Settings.
- **Atingi o stație** → cartonașul ei (nivel, ce produce) — `BuildingCardController` reconvertit.
- Tot ce cere bucla centrală: **cel mult un tap** [ui]. Ținte de atingere de 44 pt [ui].

**Sarcini:** M1 HUD nou · M2 scoaterea panourilor de colonie · M3 cartonașul de stație ·
M4 panoul Shop · M5 panoul Rebirth.

### N. Arta

Pipeline-ul din Python rămâne (`scripts/art/`). **De desenat:** platforma (4 stări) și plăcuța de preț
· debarcaderul (3 niveluri) · roata de apă (animată) · gaterul, topitoria, războiul, cuptorul · jgheabul
· lada de sortare, piața, macaraua, magazia, farul · barcile · clopotele · pictogramele celor 4 bunuri
de volum și ale celor 4 produse · gardurile zonelor blocate · stropi, praf de construcție, monede.
**Reutilizat:** oamenii pe straturi (D44), râul, decorul, dalele.

**Sarcini:** N1 platforma și plăcuța · N2 debarcaderul · N3 roata de apă · N4 cele 4 stații · N5
restul clădirilor · N6 bunurile · N7 efectele.

### O. Sunet și „juice"

Monedă la fiecare vânzare, stropi la plasă, „thunk" la construcție, casa de marcat la debarcader,
scârțâitul roții (ambient), clinchet distinct per tier la prinderile rare. Numărul care se umflă la
creștere, platforma care se turtește la apăsare, stația care „sare" la apariție. **Fără tremurat de
ecran** — telefon, copii.
Mecanismele de celebrare la praguri sunt recomandate explicit de Roblox [onboard].

**Sarcini:** O1 sunetele de bază · O2 efectele de număr și platformă · O3 clinchetele pe tier.

### P. Monetizarea

**Dezbatere — e „venit dublu" putere?**
Norocul vândut (Fisch: 2x/4x/8x Luck) e *„cea mai clară linie roșie"* [money] — schimbă **ce** poți
obține. Venitul dublu te duce doar **mai repede** la același loc, într-un joc fără PvP și fără
comerț. **Decizie: da la viteză, nu la noroc.**

| Tip | Ce | Principiu |
|---|---|---|
| Game Pass | 2× Income | viteză |
| Game Pass | Bigger Vault (offline ×2) | spațiu |
| Game Pass | Auto-Collect (plasele tale se golesc singure) | comoditate |
| Game Pass | Extra Hand | viteză |
| Game Pass | aspect de debarcader, cosmetice | aspect |
| Developer Product | pachet de monede = „o oră de venit" | viteză, determinist |
| Developer Product | reparație instant | viteză |
| Developer Product | colectare offline ×2 | viteză |

**Niciodată de vânzare:** noroc, obiecte de colecție, conținut exclusiv, nimic aleator [19][money].
Tot ce se plătește **nu se resetează la renaștere** [wipes]. Prețurile rămân provizorii (D20).

**Sarcini:** P1 `MarketplaceService` + `ProcessReceipt` · P2 cele 4 pass-uri · P3 cele 3 produse ·
P4 panoul Shop.

### Q. Retenția pe termen lung

Seiful (2–3 reveniri pe zi [16]) · scara renașterii (zile) · colecția (luni [21]) · **conținut nou la
2–4 săptămâni** — colecțiile rețin doar cu cadență [20], iar un solo ține un update la 2 săptămâni –
1 lună [37] · evenimente **cu preaviz**, care merg mai bine decât surprizele [20].
**Nu:** recompense zilnice simple [16]; mecanici de tip „ratezi dacă nu vii" [addictive].

**Sarcini:** Q1 calendarul de conținut · Q2 primul eveniment cu preaviz · Q3 decizia D19 (Inundația).

### R. Social — mai târziu

Mai multe terenuri pe un server (tycoon-ul clasic), clasament, vizite. Jocul cu prieteni e semnal
pentru algoritm [35], iar retenția pe 30 de zile vine din mecanici sociale [18]. **Nu acum** — [37] și
[anti] cer ca bucla să fie validată întâi. Dar terenul se construiește de la început ca unitate
izolată (B5), ca să nu fie o rescriere.

**Sarcini:** R1 terenuri multiple · R2 clasamentul top 30 (`OrderedDataStore`) · R3 lobby-ul
(decizia de avatar, D20/D23).

### S. Arhitectura tehnică

**Detaliu — schema profilului, v2:** `Coins`, `Pads` (mulțimea cumpărate), `Stations` (niveluri),
`Hands`, `Nets`, `Pile`, `Workshop`, `Index`, `Vault`, `Rebirths`, `Stats`, `Firsts`.
**Migrare:** încă nu există jucători reali, doar profilul de test al owner-ului → **start curat,
păstrând Indexul**. Un teren de 48 de platforme e câțiva KB; plafonul de 4 MB/cheie [persist] nu e o
problemă aici (devine una doar la terenuri multiple, arie R).
**Performanță:** pool de `ImageLabel`, particule plafonate, niciun obiect GUI per tile [2d].
**Autoritate:** toate cumpărările, venitul și vânzările se decid pe server; clientul trimite intenții.

**Sarcini:** S1 schema v2 + migrarea · S2 `PadService`, `EconomyService`, `StationService`,
`HandService`, `RebirthService` · S3 contracte noi de remote cu validare și limitare de rată.

### T. Unelte, teste, analytics

**Sarcini:** T1 simulatorul devine test: `lune run` citește `TycoonConfig` și verifică regula celor
patru motive și ritmul · T2 unelte de dezvoltare noi: +monede, sari la eră, derulează offline, forțează
renașterea · T3 **pâlnia pe platforme** în analytics, ca la „Plant" [24] — găsim pasul unde pleacă
lumea · T4 verificator de tipuri `luau-lsp` în poartă (ar fi prins ambele câmpuri pierdute din D44)
· T5 sonda din Studio actualizată pentru noile elemente.

### U. Curățenie de cod

Fișierele de colonie **nu se șterg acum**: jocul ar rămâne fără nimic jucabil. Se scot **în același
pas** în care intră înlocuitorul (faza F0). Lista exactă e în §6.

### V. Producția

Fazele din §7, fiecare cu o **poartă de validare** pe oameni reali — eșecul documentat din [37] (2 ani,
35.000 Robux pe reclame, 0 CCU) a avut cauza citată *„scop prea mare + zero validare"*.

---

## 5. Economia, în cifre

Generat de `python3 scripts/economy/sim_tycoon.py --table`. Jucătorul simulat e **lacom** (cumpără
imediat); coloana *real* folosește factorul 1,8× (IPOTEZĂ).

| # | Platforma | Motiv | Preț | Real ~ | Venit/s după |
|---|---|---|---|---|---|
| | **Era 1 · The Landing** | | | | |
| 1 | First Net | C | gratis | 0:00 | 0,4 |
| 2 | Second Net | C | 9 | 0:41 | 0,7 |
| 3 | Bigger Sack | A | 18 | 1:26 | 0,9 |
| 4 | Third Net | C | 25 | 2:18 | 1,2 |
| 5 | Sorting Crate | V | 40 | 3:18 | 1,5 |
| 6 | First Runner | A | 50 | 4:19 | 2,1 |
| 7 | Far-Lane Net | C | 80 | 5:29 | 2,9 |
| 8 | Weighted Nets | C | 130 | 6:50 | 3,8 |
| 9 | Workshop | V | 200 | 8:24 | 4,1 |
| 10 | Fifth Net | C | 220 | 10:01 | 4,9 |
| 11 | Dock Stall | V | 300 | 11:51 | 6,1 |
| 12 | Landing Bell | D | 450 | 14:04 | 6,8 |
| | **Era 2 · The Mill** | | | | |
| 13 | Sawmill | V | 550 | 16:30 | 8,6 |
| 14 | Water Wheel | V | 750 | 19:06 | 12,1 |
| 15 | Flume | A | 1,2K | 22:04 | 13,2 |
| 16 | Sixth Net | C | 1,5K | 25:30 | 15,1 |
| 17 | Smelter | V | 2K | 29:29 | 17,7 |
| 18 | Miller | V | 2,5K | 33:43 | 20,2 |
| 19 | Loom | V | 3,5K | 38:54 | 22,3 |
| 20 | Wide Nets | C | 4K | 44:18 | 28,2 |
| 21 | Seventh Net | C | 6K | 50:40 | 32,0 |
| 22 | Second Wheel | V | 7,5K | 57:43 | 33,0 |
| 23 | Market | V | 9K | 1h05 | 41,3 |
| 24 | Mill Bell | D | 12K | 1h14 | 47,5 |
| | **Era 3 · The Yard** | | | | |
| 25 | Crane | V | 15K | 1h24 | 51,9 |
| 26 | Eighth Net | C | 20K | 1h35 | 60,2 |
| 27 | Sorting Shed | V | 25K | 1h48 | 63,6 |
| 28 | Sawmill II | V | 28K | 2h01 | 74,6 |
| 29 | Ninth Net | C | 30K | 2h13 | 83,4 |
| 30 | Fine Ingots | V | 35K | 2h26 | 92,1 |
| 31 | Dockhand | V | 40K | 2h39 | 110,5 |
| 32 | Deep Channel | C | 45K | 2h51 | 123,8 |
| 33 | Kiln | V | 50K | 3h03 | 125,3 |
| 34 | Third Wheel | V | 55K | 3h16 | 130,5 |
| 35 | Salvage Hall | V | 60K | 3h30 | 138,6 |
| 36 | Yard Bell | D | 70K | 3h45 | 166,3 |
| | **Era 4 · The Harbor** | | | | |
| 37 | Boathouse | C | 75K | 3h59 | 185,0 |
| 38 | Tenth Net | C | 80K | 4h12 | 199,8 |
| 39 | Fine Cloth | V | 90K | 4h25 | 210,0 |
| 40 | Deep Nets | C | 100K | 4h39 | 242,2 |
| 41 | Second Boat | C | 110K | 4h53 | 261,0 |
| 42 | Glazed Pottery | V | 120K | 5h07 | 269,3 |
| 43 | Eleventh Net | C | 130K | 5h21 | 288,4 |
| 44 | Lighthouse | V | 150K | 5h37 | 360,5 |
| 45 | Third Boat | C | 160K | 5h50 | 384,0 |
| 46 | Grand Market | V | 180K | 6h04 | 499,2 |
| 47 | Twelfth Net | C | 200K | 6h16 | 531,2 |
| 48 | The Charter | D | 220K | 6h29 | 664,0 |

**Scara renașterii** (+50% liniar, Indexul păstrat): tura 1 până la Era 2 în **~1h14m**, tura 2 până la
Era 3 în **~2h15m**, tura 3 până la Era 4 în **~2h39m**.

### Ce a descoperit simulatorul — și ar fi fost livrat altfel

Prima variantă, cu prețurile ghicite, avea **nouă defecte**, toate invizibile fără model:

1. **Jgheabul nu făcea nimic** — doi alergători goleau deja toate plasele.
2. **Prima roată de apă nu făcea nimic** — energie fără consumator. → gaterul merge cu manivela.
3. **Clopotele nu făceau nimic** — cele mai scumpe platforme din eră. → dau și bonus permanent.
4. **Așteptări de 15–19 minute** în Era 2 — prețurile creșteau de 19×, venitul de 5×. → prețuri derivate.
5. **Morarul nu făcea nimic** — grăbea stații care nu erau blocajul. → calitate, nu viteză.
6. **„Smelter II" scădea venitul** după ce plăteai. → energie pe consum real, alocare pe valoare.
7. **Trei upgrade-uri de capacitate goale** la stațiile secundare. → upgrade-uri de calitate.
8. **Cinci roți pentru o cerere care nu trecea de 27.** → trei, la punctele de trecere.
9. **Rotunjirea strictă umfla prețurile în cascadă** — Charter-ul ajunsese la 19 ore reale, cu o
   așteptare de o oră. → trepte de ~10%.

---

## 6. Ce rămâne, ce se reconvertește, ce se taie

| | Fișiere |
|---|---|
| **Rămân** | `DataService` (schemă nouă) · `NetService` · `RiverService` · `WorkshopService` · `Analytics` · `DevService` · `NetServer`, `RateLimiter` · `SceneArt` · `NetController` · `IndexController` · `WorkshopController` · `RiverRenderController` · `CharacterController` · `CameraController` · `WelcomeController` · `DialogueController` · `MenuBarController` · `Panels` · `Theme`, `Widgets` · `ItemConfig` · `RiverConfig` · `RepairConfig` · `Assets` · `AnimConfig` · `RiverSim` · `Prng` · `OfflineCalc` · `AABB` · `Grid` · `Pathfind` · `WorldMap` · `WorldDecor` |
| **Se reconvertesc** | `SettlerService` (1.166 linii) → `HandService` · `SettlerRenderController` → randarea angajaților · `SettlerConfig` → `HandConfig` · `BuildService` → `PadService` · `BuildingRenderController` → randarea stațiilor · `BuildingCardController` → cartonașul de stație · `EconomyService` (7 linii) → registrul de monede · `EconomyConfig` → `TycoonConfig` · `HUDController` (HUD nou) · `DevPanelController` (comenzi noi) |
| **Se taie** | `ColonyService` · `StoreService` · `ObjectiveService` · `IntroService` · `StorytellerService` · `DashboardController` · `SettlerPanelController` · `BuildController` · `ObjectiveController` · `EventBannerController` · `ObjectiveConfig` · `EventConfig` · `BuildingConfig` · `DialogueConfig` (redus la replica angajatului) · `FoodBalance` + test · `Storyteller` + test · `ObjectiveConfig.test` |

Povestitorul și evenimentele nu dispar ca idee — revin în faza de conținut (Q2), ca evenimente cu
preaviz, nu ca motor de colonie.

**Precizare la pornirea F0 (2026-09-11):** `SettlerService`, `BuildService`,
`BuildingRenderController` și `BuildingCardController` depind de fișiere tăiate, deci ies și ele în
F0. Se recuperează din commit-ul `62bd1cc` când le vine faza: angajații (I1–I2), cartonașul de
stație (M3), randarea stațiilor (G). `SettlerConfig`, `SettlerRenderController` și `DialogueConfig`
rămân în repo, neconectate, până atunci.

---

## 7. Fazele, cu porți de validare

| Fază | Ce | Poarta de trecere |
|---|---|---|
| **F0** | Curățenie + schelet: schema v2, `PadService`, monede, debarcader, sacul, prima plasă | jocul se joacă: plasa 1 → strâng → vând → cumpăr plasa 2 |
| **F1** | **Era 1 completă** (12 platforme), primul angajat, atelierul la prima prindere cu nume, bonusul de Index, onboarding-ul, juice-ul de bază, pâlnia în analytics | **playtest cu ≥5 oameni din afara echipei**: ≥70% ajung la platforma 5; sesiunea mediană ≥10 min; nimeni nu se blochează la „ce fac acum" |
| **F2** | Seiful offline + ecranul de bun venit | testerii revin a doua zi și înțeleg ce au primit |
| **F3** | **Era 2** — gater, roți, jgheab, stații, rețeaua de energie | pâlnia nu cade la trecerea în Moară |
| **F4** | Renașterea | cine ajunge la Mill Bell și renaște, joacă și tura 2 |
| **F5** | Monetizarea | niciun tester nu percepe un pass ca obligatoriu |
| **F6** | Era 3 | — |
| **F7** | Era 4 + Charter | — |
| **F8** | Conținut și finisaj: siluete, catalog spre 200, sunet, artă | — |
| **F9** | Pregătirea lansării: F0-ul owner-ului (Grup, universuri, W-8BEN), dashboard-uri, soft launch | D1 ≥ 15% în soft launch (D25) |

**Regula de fază, din [anti]:** nu se adaugă un sistem de progresie nou înainte ca bucla de 3–5
minute să fie testată pe oameni din afara echipei. Deci **Era 2 începe abia după poarta F1.**

---

## 8. Lista completă de sarcini

Ordinea de execuție. Fiecare ID trimite la aria lui din §4.

**F0 — Curățenie și schelet**
- [x] F0.1 Snapshot git înainte de tăiere — primul commit pe `main`, 2026-09-11
- [x] F0.2 S1 Schema de profil v2 + migrare cu start curat, Indexul păstrat
- [x] F0.3 A1 `TycoonConfig.luau`, derivat din simulator
- [x] F0.4 A2 `TycoonMath.luau` (venit, energie, offline, renaștere) — modul pur
- [x] F0.5 A3 Teste Lune pentru `TycoonMath` și regula celor patru motive
- [x] F0.6 A4 `EconomyService`: monede, venit calculat pe server
- [x] F0.7 B2 `PadService`: listă, ordine, validare, efect, persistență
- [x] F0.8 B3 `PadController`: stări, preț, inel de progres, cumpărare la contact
- [x] F0.9 W1 Sacul · W2 debarcaderul cu vânzare
- [x] F0.10 E1 Plasa ca obiect (rată, capacitate, bandă) · E3 capacitatea vizibilă
- [x] F0.11 M1 HUD nou: monede, venit/s, sac · A5 formatare K/M/B
- [x] F0.12 U Scoaterea fișierelor de colonie din §6, în același pas
- [x] F0.13 T2 Unelte de dezvoltare noi
- [x] F0.14 **Poarta:** plasa 1 → strâng → vând → cumpăr plasa 2 — trecută de owner în Studio pe
  2026-09-11 (până la Sorting Crate, 1,5/s). Singura eroare găsită: panoul atelierului citea
  câmpurile vechi (materiale), reparată în aceeași zi.

*Notă F0:* plasele prind pe cronometru (`nextCatchAt`), nu prin coliziune cu obiectele de pe râu; de
aceea o revenire după absență le umple singură până la capacitate. Obiectele care plutesc sunt, deocamdată,
doar decor — în F1 (D2) prinderea trebuie să se vadă: bunul intră în plasă în clipa în care e prins.

**F1 — Era 1 completă**
- [ ] B1 Harta celor 4 zone · B4 garduri și estompare · B5 terenul ca unitate cu origine proprie
- [ ] C1 Cele 12 platforme ale Erei 1 · C5 ceremonia de clopot
- [ ] D1 `GoodsConfig` · D2 bunuri de volum pe râu · D3 valoarea obiectelor cu nume
- [ ] E2 Weighted Nets
- [ ] W3 Multiplicatorii de preț · W4 „+N" spre contor
- [ ] H1 Bonusul de Index · H2 atelierul la prima prindere cu nume · H3 vânzarea obiectelor cu nume
- [ ] I1 `HandService` · I2 angajatul merge și lucrează · I3 rolul Runner · I4 replica lui
- [ ] L1 Fraza · L2 săgeata primei platforme · L3 indiciul de 11 s · L4 · L5
- [ ] M2 Scoaterea panourilor de colonie · M3 cartonașul de stație
- [ ] N1 Platforma și plăcuța · N2 debarcaderul · N6 bunurile · N7 efectele de bază
- [ ] O1 Sunetele de bază · O2 efectele de număr
- [ ] T3 Pâlnia pe platforme · T5 sonda actualizată
- [ ] **Poarta F1:** playtest cu ≥5 oameni din afară

**F2 — Offline**
- [ ] J1 Seiful · J2 calculul pe capacitate · J3 ecranul de bun venit · J4 upgrade-urile de Seif
- [ ] **Poarta F2:** testerii revin a doua zi

**F3 — Era 2**
- [ ] C2 Cele 12 platforme · G1 `StationService` + rețeaua de energie · G2 cele 4 stații · G3 manivela
- [ ] G4 Afișajul de energie și „Low power" · G7 jgheabul ca traseu fix · E2 Wide Nets
- [ ] I3 Rolul Miller · N3 roata de apă animată · N4 stațiile · O3 clinchetele pe tier
- [ ] **Poarta F3**

**F4 — Renașterea**
- [ ] K1 `RebirthService` · K2 ecranul Stays/Resets/You gain · K3 scara · K4 bonusul · K5 setul nou
- [ ] M5 Panoul Rebirth
- [ ] **Poarta F4**

**F5 — Monetizarea**
- [ ] P1 `MarketplaceService` + `ProcessReceipt` · P2 pass-urile · P3 produsele · P4/M4 Shop
- [ ] **Poarta F5**

**F6 — Era 3** · C3 · G5 upgrade-urile de calitate · G6 Sawmill II · D4 banda 3 · I3 Dockhand · N5
**F7 — Era 4** · C4 · barcile · farul · Charter-ul · E2 Deep Nets
**F8 — Conținut și finisaj** · H4 siluetele · H5 catalogul spre 200 · Q1 calendarul · Q2 primul eveniment
**F9 — Lansare** · R1–R3 (dacă s-au decis) · T4 verificatorul de tipuri · F0-ul owner-ului · soft launch

---

## 9. Ce e cercetare și ce e ipoteză

**Susținut de cercetare:** bucla de colecție pasivă (Grow a Garden, *„cel mai important studiu de caz
pentru Driftwood"* [20]); plafonul offline pe capacitate [16]; monetizarea prin viteză și spațiu
[19]; renașterea care nu atinge ce e plătit și bonusul liniar [wipes]; stațiile fixe și energia din
curent [dir04]; vizual peste text și indiciul de 11 s [24][onboard]; dezvăluirea pe două niveluri [ui].

**IPOTEZE, de validat la playtest:** factorul lacom→real 1,8×; valorile bunurilor și ponderile lor;
+1% per obiect de Index; +50% per renaștere (cifra — principiul liniar e din [wipes]); cele 48 de
platforme și ordinea lor; platformele de cumpărare ca mecanică (nicio notă nu le studiază).

**Legenda marcajelor:** `[16]`…`[37]` = `docs/research/NN-*.md`. Din `docs/research-survival/`:
`[wipes]` wipes-seasons-resets · `[landscape]` roblox-survival-landscape · `[depth]`
progression-depth · `[factorio]` factorio-satisfactory · `[money]` roblox-monetization-complex ·
`[persist]` roblox-persistence-scale · `[2d]` roblox-2d-ceiling · `[complex]` roblox-complex-games ·
`[addictive]` why-survival-addictive · `[anti]` anti-patterns · `[onboard]` onboarding-complex ·
`[ui]` ui-complex-games. `[dir03]`/`[dir04]` = propunerile de direcție, **arhivate** în
`~/Desktop/Driftwood_arhiva_2026-09-11/docs/directions/`.

---

## 10. Decizii care rămân la owner

1. ~~Snapshot git înainte de tăiere.~~ **Rezolvat 2026-09-11:** primul commit e pe `main`, în
   repo-ul privat `Tiberiu221/TycoonRoblox`. Cele ~4.400 de linii pe care le scoate F0 rămân în istoric.
2. **Numele.** Place-ul din Studio se numește deja *Driftycoon*. Îl păstrăm?
3. **Terenuri multiple pe server** — recomandarea e *mai târziu* (arie R).
4. **Lobby-ul cu avatar** — așteaptă ticketul la Roblox despre rata DevEx (D20/D23).
5. **D19 / Inundația** — contrazice regula „nimic nu se distruge".
