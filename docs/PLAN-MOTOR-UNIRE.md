# Planul: motorul lanțului cu unire și baraj, pentru Era 4 și după [D70]

**Stare (2026-09-29): propunere; pașii a–c sunt făcuți** (motorul general, fără Era 4; ce a ieșit altfel e la §10). Owner-ul a hotărât întrebările 2, 4 și 8 din §6 (piesele se vând doar unite, suma de start e cea din simulator, 35T, iar cristalul se vinde și în Era 4), apoi, pe 2026-09-30, 1, 3, 6 și 7 cu variantele recomandate. Pașii d–l pot porni; 5 și 9–12 așteaptă, fără să-i blocheze. Planul pornește de la designul B, cu barajul dat întreg și cablul lucrat de mână. Din designul A am luat patru lucruri: filtrul tabelelor de aur, locul de unde ia curierul, formula monedelor Robux și regula plaselor pe familii. Pe fiecare le-am verificat în cod. Cifrele vin din prototipuri (copii ale simulatorului, în afara repo-ului), rulate din nou de judecător. Cifrele finale se derivă doar în `sim_tycoon.py`.

## 0. Întrebarea owner-ului, pe scurt

*„Dacă la Era 4 rămân doar 5 oameni, cât produce jucătorul pe secundă? Cum mai prinde bateriile, dacă acolo e un baraj?"*

- **Bateriile nu se mai prind din râu, le face barajul.** Prima turbină e zidită în baraj și e gratis. Face 1,46 baterii/s, cât turbina din Era 3.
- **Cei cinci veterani lucrează linia bateriilor:**
  - Dam Collector și Dam Porter duc bateriile;
  - Switchman-ul le încarcă în butoaie;
  - Barrel Hauler-ul duce butoaiele la Relay Station;
  - Innkeeper-ul devine Dispatcher și vinde curentul orașului.
- **Râul aduce minereu peste deversor.** Prima Cable Net de sub baraj e gratis, iar turul cablului îl faci tu:
  - plasa → Cable Works → Relay Station;
  - la Relay stai în inel: un butoi plus o bucată de cablu dau o unitate de curent;
  - o duci pe podul cu stâlpi.
- **Cât face pe secundă:** cât unește Relay-ul pe secundă × prețul unității × clopotele. Adică 0,33 × 44,55B × 1,331 = **19,6B/s, de 16,2 ori mai mult decât la Works Bell** (1,21B/s).
  - Turbina face mult, dar cablul e mai încet, deci butoaiele se strâng lângă Relay („Waiting for cable").
  - Un nivel la turbină scrie „No gain yet — the Cable line is slower".
  - Un nivel la Cable Net aduce +198M/s pentru 27B.
- **Fără tine (AWAY) câștigi 0** până angajezi cei 6 oameni ai cablului și ai Relay-ului. Costă 1,58T din 35T și vin în ~2,5 minute. Apoi AWAY e 19,6B/s.

## 1. Ce rămâne neatins

- **Erele 1–3 rămân bit cu bit.** La fel ca în `PLAN-MOTOR-N-LINII.md`:
  - `sim_tycoon.py --table --chain --robust`, rularea simplă și două `tune_tycoon.py eval` ies identice la octet, înainte și după;
  - `GOLDEN`, `GOLDEN_ERA2` și `GOLDEN_ERA3` rămân neschimbate;
  - un script de unică folosință compară motorul vechi cu cel nou pe 80.000 de stări la întâmplare.
- **Simulatorul vine primul.** Niciun preț nu se ghicește. `ChainMath.luau` e portul lui la bit.
- **Nicio cumpărare nu scade venitul** (`VIOLATIONS` rămâne goală). Când o cumpărare dă zero, ecranul spune de ce [D46, D40].
- **Fiecare pas are omul lui** (din Era 6, om sau robot). Serverul decide, iar profilul crește doar aditiv.
- Cheile noi sunt **opționale**. O linie fără ele se poartă exact ca azi. Liniile noi se adaugă la coada lui `LINE_ORDER`. O linie închisă livrează exact 0 și are câștig 0, deci cu `>` strict nu schimbă nicio departajare.

## 2. Forma tabelelor

**Cheile noi pe o linie** (în `sim_tycoon.LINES` și în `StationConfig.LINES`):

| Cheie | Sens |
|---|---|
| `closeFlag` | Câmpul din State care închide linia. Cele 6 linii vechi primesc `"dam"`. |
| `inputs` | Linia e o unire, cu rețeta 1:1: `("barrels", "cable")`. Nu are `netKind`. |
| `into` | Linia e o piesă și merge în unirea numită. Nu are `seller`. |
| `value` | Cheia din GOODS a produsului unit. Implicit `AVG[netKind]`. |
| `pool` | Linii care împart timpul jucătorului. Fără cheie, linia e propriul ei bazin, ca în Erele 1–3. |
| `source` | **Rezervată pentru curierul din Era 5.** `derive_tables` o refuză până atunci. |

**Ce verifică `derive_tables` și `ChainMath.model`:**
- **Sursa:** fiecare linie are exact una dintre `netKind`, `inputs` și `source`.
- **Capătul:** fiecare linie are exact unul dintre `seller` și `into`.
- **Ordinea:** o piesă stă în `inputs` ale unirii ei și e înaintea ei în `LINE_ORDER`.
- **Unirile:** au `value`.
- **Vânzătorii:** `priority` conține doar linii cu `seller`.
- **Plasele:** `lineOfNetKind` se construiește doar din liniile cu plase. Azi `ChainMath.model:333` crapă pe un `netKind` nil.

**Era 4, în simulator** (constantele sunt punct de plecare, din prototipul B):
```python
ERA4_MULT = ERA3_MULT * 3000.0                      # 2.7e10
LINE_ORDER += ("barrels", "cable", "grid", "crystal")   # piesele inaintea unirii: ordine topologica
LINES["barrels"] = {"netKind": "dam", "openFlag": "dam", "into": "grid", "pool": "dam", "steps": (
    ("damCollector", "damCollect", "walk"), ("damPorter", "damPort", "walk"),
    ("switchman", "switchyard", "processor"), ("barrelHauler", "barrelHaul", "walk"))}
LINES["cable"] = {"netKind": "cable_ore", "openFlag": "dam", "into": "grid", "pool": "dam", "steps": (
    ("cableCollector", "cableCollect", "walk"), ("cablePorter", "cablePort", "walk"),
    ("cablemaker", "cableworks", "processor"), ("cableHauler", "cableHaul", "walk"))}
LINES["grid"] = {"inputs": ("barrels", "cable"), "openFlag": "dam", "seller": "town", "value": "grid", "pool": "dam",
    "steps": (("relayKeeper", "relay", "processor"), ("pylonRunner", "pylonRun", "walk"))}
LINES["crystal"] = {"netKind": "crystal", "openFlag": "kiln", "seller": "town", "pool": "dam", "steps": (
    ("crystalCollector", "crystalCollect", "walk"), ("crystalPorter", "crystalPort", "walk"),
    ("crystalsmith", "kiln", "processor"), ("ingotHauler", "ingotHaul", "walk"))}
# wood, iron, parts, copper, coils, power: "closeFlag": "dam" scris in randul fiecareia
PROCESSORS += switchyard (SWITCHYARD_BASE_RATE 2.4), cableworks (2.0), relay (2.8), kiln (1.2)   # niveluri 7/7/8/60 x M4
SELLERS["town"] = {"role": "dispatcher", "base": "TOWN_BASE_RATE", "level": "town_level", "priority": ("crystal", "grid")}
GOODS += {"charge": 0, "barrel": 0, "cable_ore": 0, "cable": 0,          # piesele nu se vand: part = true
          "grid": 1.65 * ERA4_MULT, "crystal": 3.5 * ERA4_MULT, "ingot": 3.5 * ERA4_MULT}
CATCH += {"dam": (("charge", 1.0),), "cable_ore": (("cable_ore", 1.0),), "crystal": (("crystal", 1.0),)}  # fara gasiri
```

**De ce valorile acestea:**
- **Produsul unit:** 1,65 × M4 e oglinda mediei primei linii din fiecare eră. Dă saltul ×16,2 cerut de D70.
- **Cristalul:** 3,5 × M4, cât bateria din Era 3.
- **Scrierea constantelor:** `1.65 * ERA4_MULT` se scrie la fel în Python și în Luau, nu ca literal `4.455e10`. Altfel se poate muta un ulp.

**Oamenii și bazele lor:**
- `ROLE_BASE`:
  - linia bateriilor: damCollector 4,0, damPorter 6,0, barrelHauler 7,5;
  - linia cablului: cableCollector **4,0** (vezi riscul 1), cablePorter 5,0, cableHauler 7,0;
  - unirea: pylonRunner 7,0;
  - cristalul: crystalCollector 2,0, crystalPorter 2,5, ingotHauler 6,5.
- `ERA4_ROLES` au `ROLE_COST_MULT = M4`.
- Scutiri noi în `BOTTLENECK_EXEMPT`: `crystalPort` și `ingotHaul`, în oglindă cu `batteryPort` și `powerHaul`.

**Plasele primesc rang explicit, nu loc în listă.** Turbinele și plasele de cablu se cumpără amestecat, deci `NETS_PER_ERA` rămâne doar pentru plasele 1–15.
- `unlock_net_ranked(kind, rank, lane)` pune `Net.base = 0.33 × 1.45^(rang−1)` și `Net.upgrade_base = 1.45^(rang−1) × M4`. Câmpul `upgrade_base` există deja.
- Rangurile:

| Plasa | Rang | Cum vine |
|---|---|---|
| Dam Turbine | 5 | zidită în baraj, gratis |
| Cable Net 1 | 1 | gratis |
| Cable Net 2–4 | 2–4 | cumpărate |
| Second Dam Turbine | 6 | cumpărată |
| Crystal Net | 5 | spre final |

- Quest-ul „nivelul 2 pe ultima plasă” trece pe **familii**. Azi `prev_net_ready` se uită la `s.nets[-1]`.
- În joc, platformele primesc `netRank` și `netEra`, citite de `StationService.StateFrom` în locul lui `netBase(i)`.

**În Luau:**
- `Line = {netKind?, inputs?, into?, value?, pool?, openFlag?, closeFlag?, seller?, steps}`.
- `Step.job`, opțional: collect, port, work, haul sau courier. Fără el, se ia după poziție, ca azi (`HandRoutes.JOB_OF_STEP`).
- Tabele derivate noi: `CONSUMER_OF` (piesă → unire), `POOL_LINES`, `ERA_LINKS[4]` și `LINE_OF` pentru verigile noi.
- `TycoonConfig` primește `PROCESSED` (charge → barrel, cable_ore → cable, crystal → ingot) și `JOINED = { grid = {"barrel", "cable"} }`.

## 3. Formulele (un singur lanț, trei treceri)

```
INAINTE, in LINE_ORDER (piesele inaintea unirii):
  open(l)    = not closeFlag  and (openFlag nil or flag)  and sursa exista
               (linie de plase cu openFlag: macar o plasa de felul ei, ca azi; unire: toate piesele deschise)
  catch(l)   = suma plaselor felului ei (0 pentru unire: "nets" apartine doar liniilor de plase)
  supply(l)  = catch(l)  |  unire: min(own_max(i) pentru i in inputs)
  manual(P)  = pasii fara om din liniile DESCHISE ale bazinului P   (fara `pool`: P = linia -> formula de azi)
  drum       = ROLE_BASE*treapta*oameni   sau  3.6*1.5 / manual(P)
  cladire    = levelOutput*treapta*oameni sau  cap / manual(P);  0 cat linia e inchisa
  own_max(l) = min(supply, pasii);   active(l) = not inchisa and (openFlag nil or supply > 0)
VANZATORII, neschimbati: room = cap; delivered = min(own_max, room); by_seller = active and delivered == room
            and delivered < own_max; room -= delivered
INAPOI, in LINE_ORDER inversat: piesa l cu into = c: delivered(l) = delivered(c);
            by_consumer(l) = active(l) and delivered(l) < own_max(l)
VENIT = suma, in LINE_ORDER, pe liniile CU seller: delivered * value(l)  x priceMult x bells x index x rebirths
```

**Veriga slabă:**
- **Câștigul unei bucăți în plus.** Regula de azi pe vânzător rămâne: `AVG(l) − AVG(prima linie ținută după l)`. Se schimbă doar pasul care dă câștigul verigilor: `credit(l, x, g)`.
  - Fiecare verigă a lui l cu debitul == x primește g, ca maxim.
  - Dacă l e o unire cu `supply == x`, fiecare piesă cu `own_max == x` primește `credit(i, x, g)`. La egalitate, câștigul îl primesc amândouă piesele.
- **Veriga fiecărei linii:**
  - `""` dacă linia e inactivă;
  - vânzătorul, dacă `by_seller`;
  - veriga consumatorului, dacă `by_consumer`;
  - altfel `own_first`. La o unire ținută de piese, e `own_first` al primei piese, în ordinea din `inputs`, care o ține.
- **Câmpuri noi în `Flow`, copiate explicit pe client:**
  - `supply` pe fiecare linie;
  - `heldBy`: linia care deține veriga;
  - `netsLine`: ale cui plase au dus câștigul global. Fără el, veriga `nets` e ambiguă.
- **Totalurile:** `Flow.catch` adună doar plasele, iar `Flow.delivered` doar liniile care vând.
- **AWAY:** `idleOnly` rămâne ca azi. Venitul fără tine cere deci om pe toți cei 10 pași ai pieselor și ai unirii, plus Dispatcher-ul.
- **`ERA_MODELS` și `eraBottleneck` rămân.** Erele nu împart nimic, iar liniile vechi sunt închise. Cad abia cu curierul.

**Dovada pentru Erele 1–3:** `supply == catch`, nu există piese și nici bazine. Trecerea înapoi nu atinge nimic. Suma adaugă doar termenii de azi, în aceeași ordine.

## 4. Curierul (Era 5; nu se scrie acum)

Aici se fixează doar forma, ca tabelele Erei 4 să nu-l blocheze.

**Datele:**
- Curierul e o linie-piesă a erei noi: `{source = "grid", into = <unirea Erei 5>, openFlag = <poarta Erei 5>, pool = <Era 5>, steps = {{gridCourier, courierRun, walk, job = "courier"}}}`.
- Meseria lui e a erei noi, deci o plătești în banii ei (M5). Ținuta e a erei vechi.
- Vine gratis cu poarta erei noi, ca veteranii la baraj.
- `source` trebuie să fie o linie care vinde, niciodată o piesă.

**Matematica:**
- `supply = own_max(source)`.
- Vânzătorii se socotesc de la era cea mai nouă la cea mai veche. După fiecare vânzător urmează trecerea înapoi, care adaugă `delivered(curier)` la `taken(source)`.
- Vânzătorul vechi vede `avail = own_max − taken`.
- Curierul ia primul, dar doar cât folosește unirea.
- Poarta `check_courier_value` cere `value(nou) ≥ value(source)`. Cu scara ×3000 trece cu mult.

**Fizic:**
- Curierul ia din lada de la ușa vânzătorului vechi, nu din ieșirea Relay-ului. Motivul: `own_max(grid)` include drumul pe stâlpi, deci Pylon Runner-ul duce totul la ușă.
- Acolo `DropAt` pune fracțiunea φ = taken / (delivered + taken) în lada curierului, cu un acumulator determinist, ca `drainCarry`.
- Încărcătura curierului e `loadFor(delivered(curier), durata)`, adică după cerere. Altfel vânzătorul vechi ar vinde sub cifra de pe ecran [D40].

**Ce se schimbă în motor atunci:**
- `ERA_MODELS` e înlocuit de lanțul întreg, filtrat pe era cerută. Câștigul plaselor se ține pe eră.
- Un test arată că pentru Erele 1–4 răspunsul iese același.
- Prototip: a încercat 159.429 de cumpărături pe 4.000 de stări atinse și n-a găsit nicio scădere de venit.

## 5. Barajul și suma de start

**`dam_transform(s3, coins)` se aplică pe o clonă a stării de la Works Bell:**
- `s.dam = True`. Cele 6 linii vechi se închid. Plasele, nivelurile și oamenii lor rămân în State și în profil.
- Oamenii erelor vechi au 0 în socoteală, fiindcă sunt retrași sau mutați.
- Cei cinci veterani intră pe treapta 1, câte unul: damCollector, damPorter, switchman, barrelHauler, dispatcher.
- Turbina din zid și Cable Net 1 vin gratis. Switchyard, Cable Works, Relay și Switch House există de la baraj.
- Clopotele (1,331), traista, `price_mult`, indexul și renașterile rămân.
- `s.coins = coins`.
- `options` sare peste plasele, clădirile și treptele liniilor închise.

**Două rulări:**
1. **Rularea fără bani** (`coins = 0`) fixează prețurile, ca la orice eră.
   - `C5` = costul cumpărăturilor din primele 300 s reale. În prototip: 8,13T.
   - `noapte` = venitul la Works Bell × 8 h, fără pass-uri = 34,86T.
   - `START_SUM = nice_up(max(C5, noapte))` = **35T**. Cei 40T din D70 erau cifra de probă.
2. **Rularea cu suma** pornește cu `START_SUM` și aceleași prețuri. E cronologia adevărată. În prototip ține 41m49s, față de 51m28s pornind fără bani.

**Porțile noi:**

| Poarta | Ce cere | Prototip |
|---|---|---|
| `check_windfall_dam` | suma sare cel mult 25% din cronologia fără bani | 18,1% |
| `check_windfall_dam` (raport) | cazurile plătite: +1h Flow, Welcome Back x2 după 8 h, după 16 h cu 2x Flow | 19,0% / 23,7% / 32,9% |
| `check_era_jump` | venitul la t=0 ÷ venitul la Works Bell, între 8 și 30 | 16,2 |
| `check_dam_away` | AWAY după angajările capitolului ≥ AWAY la Works Bell; angajările costă cel mult 10% din sumă | 19,6B ≥ 1,21B; 1,58T = 4,5% |
| `check_hire_order` pe bazin | în ordinea capitolului, cu n pași de mână rămași, un drum duce ≥ 5,4/n; ultimul, Pylon Runner-ul, ≥ 5,4 și la −15% | trece |
| `check_flat` (nou) | cel mai lung tronson în care venitul nu crește ≤ cel mai lung din Erele 1–3, socotit în aceeași rulare (azi 10m52s); pentru Erele 1–3 doar raport | **B: 16m41s, pică** (riscul 1) |
| obișnuite, pe rularea cu suma | `check_run_era(4)`, `--robust` pe `ROBUST_KNOBS_ERA4` | — |

**În joc** se reiau pașii 5 și 7 din `PLAN-HARTA.md` (`WorldMath.buildDam`, `DamService`, profilul v18). Formula veche („păstrezi până la o noapte”) se înlocuiește cu suma fixă:
- `R = min(monede, Purchases.coinsBought de la Works Bell)`: monedele Robux încă în mână, socotite ca ultimele cheltuite;
- `monede' = START_SUM + R`;
- `Stats.damGift = max(0, monede − R − START_SUM)`;
- pe ecran se vede și cât completează satul.

`TycoonConfig.DAM_START_COINS` trebuie să fie egal cu suma derivată. Simulatorul o verifică, la fel ca prețurile.

## 6. Întrebări pentru owner, de la Era 1 la Era 8

Întrebările sunt puse în pașii jucătorului. Fiecare are recomandarea mea. **Pașii a–c de mai jos nu așteaptă răspunsurile. Pașii d–l le așteaptă.** Deja hotărât, nu mai întreb: Erele 1–3 rămân cum sunt, iar la baraj satul vechi se oprește. De la Era 4 fiecare eră are trei linii: două fac piese, a treia le unește, iar cumpărătorul e altul la fiecare eră.

1. **Era 4, începutul.** Veteranii fac linia bateriilor, iar tu faci cablul de mână? *Recomandat: da.* Invers, n-ai avea ce face cu mâna pe linia bateriilor. **Hotărât (owner, 2026-09-30): da.**
2. **Bateriile (butoaiele) se vând și singure?** Ai spus „bateriile se vând la preț bun”. În planul acesta ele valorează bani doar unite cu cablul, ca curent vândut orașului, iar singure așteaptă la Relay. *Recomandat: nu se vând singure.* Dacă vrei să se vândă, e nevoie de o a doua ieșire pentru ele, cu altă poartă de venit. **Hotărât (owner, 2026-09-29): se vând doar unite.** Butoaiele așteaptă cablul la Relay.
3. **Cine duce curentul la oraș?** *Recomandat:* un Pylon Runner, pe podul cu stâlpi, până la Switch House, unde stă Dispatcher-ul. Varianta cealaltă: Relay-ul vinde direct, cu un om mai puțin. **Hotărât (owner, 2026-09-30): Pylon Runner.**
4. **Suma de start e 35T, nu 40T:** e cifra scrisă de simulator. Fără tine câștigi 0 cam 2–3 minute, până la cei 6 oameni, iar ecranul spune asta dinainte. E în regulă? **Hotărât (owner, 2026-09-29): da.** Suma e cea derivată de simulator (35T pe proba de azi), iar AWAY e 0 până la cei 6 oameni noi.
5. **Monedele Robux trec întregi.** În cel mai rău caz (Welcome Back x2 după 16 h cu 2x Flow), sar ~33% din Era 4. *Recomandat:* limită de 40% doar pentru monedele plătite, sau nicio limită. Tu alegi.
6. **Plasele de sub baraj nu mai prind găsiri** (o găsire nu se poate uni cu un butoi). Surprizele rămân darurile râului. *Recomandat: da.* **Hotărât (owner, 2026-09-30): da.**
7. **Pe la minutul 29 al Erei 4, venitul poate sta pe loc ~16 minute:** Cable Collector-ii sunt la maxim (2 oameni, treapta 5). *Recomandat:* repar cu cifrele, în simulator. Varianta a doua: un al treilea om pe meserie de la Era 4 („progresiv cu jocul”). **Hotărât (owner, 2026-09-30): din cifre.**
8. **Era 4, finalul.** Cristalul se vinde în Era 4, primul la oraș (ca fierul, cuprul și curentul), și tot cu el începe Era 5? *Recomandat: da.* Altfel ultimele ~11 minute ale erei nu aduc nimic. **Hotărât (owner, 2026-09-29): da.** Cristalul se vinde în Era 4, primul la oraș, și pornește Era 5.
9. **Erele 5–7.** Curierul care aduce produsul erei vechi vine gratis cu poarta erei noi? Ia el întâi, iar clădirea veche vinde ce rămâne? *Recomandat: da, la amândouă.*
10. **Era 6.** Un robot face cât un om, doar arată altfel? *Recomandat: da.* Motorul rămâne neschimbat.
11. **Era 8.** Etapele rachetei se cumpără cu monede, ca un clopot, din banii tuturor liniilor, fără o linie nouă de marfă? Lansarea e renașterea: +50%, fără să pierzi ceva plătit. *Recomandat: da.*
12. **Numele** (Switchman, Barrel Hauler, Cable Works, Relay Keeper, Pylon Runner, Switch House, Dispatcher) sunt propuneri.

## 7. Pașii

La fiecare pas: toată poarta din CLAUDE.md, apoi commit și push.

| Pas | Ce | Cum se verifică |
|---|---|---|
| a | **Simulatorul, motorul (fără Era 4).** Cheile și invariantele; `open` / `supply` / `catch`; bazinul; trecerea înapoi; `credit`, `heldBy`, `netsLine`; venitul doar pe liniile care vând; `options` sare liniile închise; `unlock_net_ranked`; `nice()` urcă până la 10^24 (azi se oprește la 10^12 și întoarce `int(x)` nerotunjit) | ieșirea completă `--table --chain --robust`, rularea simplă și două `tune_tycoon.py eval`, identice la octet |
| b | **`check_lines.py`.** Unire de probă cu cifre socotite de mână: startul barajului; piese la egalitate (amândouă au câștig, fiecare singură dă 0); unirea ținută de Relay, apoi de vânzător; `closeFlag`; bazinul | rulează odată cu simulatorul; o regulă inversată îl pică |
| c | **`golden_chain.py`.** Blocurile de azi tipăresc doar liniile și vânzătorii Erelor 1–3 (azi buclele merg pe tot `LINE_ORDER`) | diferența față de `tests/ChainMath.test.luau` e goală |
| d | **Simulatorul, Era 4** (după răspunsuri). Rândurile din §2; `ERA4_UNLOCKS` pe familii (6 oameni în rafală, plasele, Kiln doar cu toți cei 11, cristalul, Dam Bell); `dam_transform`; cele două rulări; `START_SUM`; porțile din §5; `LATE_LINE[4]`; `report_era(4)` pentru N linii | `--robust` verde, cu `check_flat`; porțiunea Erelor 1–3 identică la octet |
| e | **`golden_chain.py --era4` → `GOLDEN_ERA4`.** Șase stări: startul barajului, după cei 6, butoaiele țin, egalitatea butoaie–cablu, Town plin, cristalul primul | tabelul generat |
| f | **Configurația.** `StationConfig` (rânduri prin referință, derivate noi); `TycoonConfig` (GOODS, CATCH, PROCESSED, JOINED, platformele cu `netRank` și prețuri din simulator, `DAM_START_COINS`); `Strings`. Era 4 cu `live = false` | stylua, selene, `sim --robust` (`check_config_constants` și `check_config_prices` extinse) |
| g | **`ChainMath`.** `model`, `flowWith` în trei treceri, `pickBottlenecks`, `valueWith`, totaluri, `empty`, `clone`, `supply`, `heldBy`, `netsLine`. Comparația veche–nouă pe 80.000 de stări, apoi scoasă | GOLDEN*, `GOLDEN_ERA4`, „liniile ca date” cu unirea de probă |
| h | **`HeldBack`.** `among` = grupul liniei (ea, piesele, unirea); `nets` doar pe liniile de plase; gardă pentru un `seller` nil (azi :133/:135); textele „the Cable line is slower” / „just as slow as the Barrel line”; când `heldBy` e o linie închisă, `Strings.lineNotOpen(heldBy)` („cast the Cable Net first”) cu Go to spre plasă, nu „is slower” | teste noi |
| i | **Modulele comune.** `FlowConfig` (`into`, `inputPiles`, `SELLERS.town`); `FlowMath.assemble` (`min(întregi, nA, nB)` perechi); `sellerOf(piesă) = nil`; refuzul `part_to_relay`; `split` primește piese la Relay; `HandRoutes` cu `job` pe pas, drumul pieselor la `inputIn` al Relay-ului | teste Lune |
| j | **Serverul.** `EconomyService` (unirea merge doar cu ambele intrări nevide, `assemble`, `DropAt` pe fel de piesă, liniile închise fără tick); `HandService` (sare oamenii retrași); `NetService` (nu mai umple plasele închise); `StationService` (`StateFrom` cu `dam` și rangurile, garda din `BUILDING_ROWS`, `Snapshot` cu `supply` / `heldBy` / `netsLine`); `DamService` și profilul v18 după PLAN-HARTA, cu suma din §5 | teste: migrarea păstrează numele și chipul celor 5; `StateFrom` reproduce `dam_transform` |
| k | **Clientul.** `LineController` pentru unire (două grămezi, „Waiting for cable/barrels”); `Overlay.DROP_AT`; `Bootstrap` copiază explicit câmpurile noi; `GuideMath` pentru primul tur (6 pași de mână); capitolele 10–12; indiciul AWAY | poarta și sonda pe texte |
| l | **Sonda, cap-coadă, pe profil de probă:** Works Bell → Build the Dam → turul → cei 6 → Kiln → Dam Bell. Arta se face pe planșe și se urcă doar cu acordul owner-ului. `live = true` doar după Studio | `errors` e gol; niciun text nu iese din cutie |

## 8. Teste

- **Erele 1–3:** cele șase ieșiri identice din pasul a, tabelele de aur neschimbate și comparația pe 80.000 de stări.
- **Unirea (`check_lines`, Luau):**
  - la startul barajului: drumurile 0,9, Cable Works 0,333, Relay 0,467, livrat 0,33, venit 19,57B;
  - pe fiecare stare, `delivered(piesă) == delivered(unire)`;
  - o piesă `by_consumer` arată veriga celeilalte, cu `heldBy` corect;
  - la egalitate, `gain_of` pe fiecare piesă singură dă 0.
- **Monotonia pe stări atinse** (veteranii mereu; angajările în ordinea capitolului; Kiln după cei 11):
  - nicio opțiune nu scade venitul;
  - **paza negativă:** aceleași angajări în altă ordine chiar scad venitul (prototipul A a găsit 252 de cazuri). Asta dovedește că regula o țin condițiile platformelor.
- **Porțile din §5**, plus rândul vânzătorului (cristalul valorează măcar cât curentul unit) și „fără găsiri pe piese”.
- **`GOLDEN_ERA4` la bit.** Plus trei verificări:
  - liniile închise livrează 0 și au veriga `""`;
  - `idleIncome` e 0 până la ultimul om;
  - `clone` păstrează câmpurile noi.
- **`HeldBack`:**
  - rândul turbinei spune „the Cable line is slower”;
  - o piesă a cărei pereche n-are încă plasa spune „No gain yet — cast the Cable Net first”, nu „is slower”;
  - `netsLine` numește plasele cablului;
  - o piesă fără vânzător nu crapă.
- **Fizic:** `assemble` nu pierde nicio bucată și se oprește cu o intrare goală; drumurile pieselor se termină la intrarea Relay-ului; `loadFor` = rată × durată.

## 9. Riscuri

1. **Zidul de la mijlocul erei.** În prototipul B, Cable Collector-ul are baza 3,0. La 2 oameni pe treapta 5 duce 30/s, iar venitul stă la 1,78T/s de la 29m16s: **16m41s fără creștere** până la Crystal Net. Erele 1–3 au avut cel mult 10m52s, iar A 10m42s. `check_flat` prinde asta. Remediul îl alege simulatorul: baza 4,0, Kiln mai devreme sau întrebarea 7.
2. **Bazinul ține doar prin ordinea deblocărilor.** O linie deschisă peste pași de mână diluează timpul tău. Condițiile platformelor (Kiln cere toți cei 11), `check_hire_order` pe bazin și `VIOLATIONS` trebuie să o țină.
3. **Egalitățile între piese dau cumpărături cu câștig 0.** E cinstit [D46], dar textul trebuie să numească linia cealaltă. Ce se înțelege pe ecran vede owner-ul în Studio.
4. **AWAY e 0 după baraj**, până la cei 6 oameni. Ecranul și Welcome back o spun dinainte [D43].
5. **Tabelele de aur pot pica doar ca text.** Fără filtrul din pasul c, tabelele de aur s-ar schimba prin liniile închise în plus.
6. **Câmpurile noi trebuie copiate explicit pe client:** `supply`, `heldBy`, `netsLine`. Un câmp scos trebuie căutat la toți cititorii (capcana din CLAUDE.md).
7. **Grămada piesei mai rapide crește fără capăt ca număr** (PileMath n-are plafon). Desenul trebuie plafonat. Când veriga se mută, grămada se golește mai repede decât rata de pe ecran, la fel ca azi.
8. **Profilul la baraj:** oamenii se re-cheiază cu `formerRole`, iar ceilalți primesc `retired`. Numele și chipul se copiază explicit și se testează.
9. **Scara numerelor:** o noapte la Dam Bell face 96Qa. `formatNumber` (plafon Qi) și tabla de venit din bâlci (int64) se rezolvă înainte de Era 5 (PLAN-HARTA, pasul 3).
10. **Unelte fără CI:** `tune_tycoon.py` nu rulează în CI, deci se rulează de mână la pașii a și d.
11. **Cifrele vin din prototipuri care înlocuiesc funcțiile unei copii a simulatorului.** Constantele finale se reglează în `sim_tycoon.py`, cu porțile lui.


## 10. Cum au ieșit pașii a–c (2026-09-24, cu reparațiile verificatorului din 2026-09-29)

**Dovezile că Erele 1–3 sunt neschimbate:** `--table --chain --robust`, rularea simplă, `golden_chain.py` (toate trei blocurile) și trei `tune_tycoon.py eval` (două cu constante suprascrise) ies identice la octet, înainte și după. Tabelele de aur sunt identice jeton cu jeton cu `tests/ChainMath.test.luau`. Poarta e verde.

**Simulatorul (pasul a).** Ce a ieșit altfel decât în §2–§3 sau ce trebuie să copieze întocmai portul din pasul g:
- `derive_tables` întoarce trei tabele în plus: `NET_LINE` (felul de plasă → linia ei), `CONSUMER_OF` și `POOL_LINES`. Pe lângă invariantele din §2, mai refuză două lucruri: două linii pe același fel de plasă (altfel `NET_LINE` n-ar fi o funcție) și o unire fără piese.
- **`active` = linia e deschisă** și (`openFlag` nil sau `supply > 0`). „Nu e închisă” din §3 s-a citit ca „e deschisă”. Diferența apare doar la o unire fără `openFlag` cu piese încă nedeschise.
- O unire închisă sau încă nedeschisă are `supply = 0`. Altfel, oamenii ei de drum ar vinde din piese.
- **O unire n-are veriga `nets`:** `links()` are doar pașii ei. Locul plaselor îl ia `supply`, verificat înaintea pașilor, ca plasele în fața liniei. Tot așa se caută `own_first` și se dă `credit`.
- **`held_by`:** la o linie ținută de vânzător e chiar linia. La o piesă ținută de unire e cel al unirii. Altfel e linia căreia îi aparține primul minim.
- **O piesă a unei uniri care nu merge încă** (turbina fără plasa de cablu) are veriga `nets`, cu `held_by` = prima piesă din `inputs` care nu e deschisă. Ecranul nu tace [D43]: spune fraza jocului pentru o linie nedeschisă, `Strings.lineNotOpen(heldBy)` („No gain yet — cast the Cable Net first”), cu Go to spre locul plasei, nu „is slower”. Pentru asta, `LineFlow` ține și `is_open`.
- **Plasa de siguranță:** `silent_lines` găsește liniile active fără verigă slabă (contractul e că `""` înseamnă inactivă). `run` se oprește cu eroare dacă apare una în cronologie. Nicio formă din plan nu ajunge acolo; un caz construit anume (o unire oprită de câmpul ei, cu piesele deschise) e în `check_lines`.
- **`nets_line`** se scrie doar când veriga globală e `nets` (cu câștig > 0). E prima linie, în `LINE_ORDER`, ale cărei plase au dus câștigul. În rest e `""`.
- **`Chain.gains`** (câștigul fiecărei verigi) e acum vizibil. Fără el, „amândouă piesele au câștig” nu se putea verifica. `HeldBack` va avea nevoie de aceeași cifră.
- **`options` sare doar liniile închise de `closeFlag`**, nu și pe cele încă nedeschise. Simulatorul oglindește jocul, unde o clădire deținută se poate urca și cât linia ei nu e deschisă (forja înaintea plasei de scrap). Pe cifrele Erelor 1–3 nu contează: un asemenea nivel dă 0, iar cumpărătorul lacom nu-l ia. Regula e fixată în `check_lines` (starea „bazin cu cablul închis”).
- `line_time` numără `supply > 0`, nu `catch > 0`, ca unirea să aibă timpul ei.
- **`unlock_net_ranked(kind, rank, lane, era)`:** al patrulea parametru e explicit, fiindcă M4 trebuie să vină de undeva. Rangul 5 al Erei 3 e bit cu bit First Turbine.
- **`nice()`:**
  - prețul se face din zecimi întregi, până la 9 × 10^24;
  - până la 10^12 dă aceleași cifre, verificat pe o baleiere;
  - peste scară oprește simulatorul, în loc să întoarcă `int(x)`;
  - `int(x)` putea ieși chiar sub prețul dinainte, iar `int(2.8 × 10^14)` dădea 279999999999999.
- **Timpul simulatorului:** +14% (6,3 → 7,2 s pentru cele trei ere). Starea deschisă și pașii de mână ai bazinului se socotesc o dată pe linie la fiecare `chain`.

**`check_lines.py` (pasul b).** A treia copie a simulatorului conține:
- startul barajului: drumurile 0,9, Cable Works 2/6, Relay 2,8/6, livrat 0,33;
- bazinul, inclusiv cu o linie nedeschisă în el;
- egalitatea pe plase și pe oameni: amândouă piesele au câștig, iar fiecare singură dă 0;
- piesa ținută de unire, cu veriga și `held_by` ale celeilalte;
- piesa unei uniri care nu merge încă: veriga `nets` a celeilalte piese;
- unirea ținută de Relay, apoi de vânzător;
- egalitățile dintre o piesă și Relay: Relay-ul cât turbina (veriga e a pieselor, verificate întâi) și Cable Collector-ul cât Relay-ul (câștigul pe amândouă verigile);
- `nets_line` gol când venitul nu-l țin plasele și când niciun câștig nu există;
- `closeFlag` și `options`, cu regula îngustă (clădirile unei linii nedeschise rămân de urcat);
- plasa de siguranță, pe fiecare stare și pe unirea oprită de câmpul ei;
- invariantele refuzate;
- `unlock_net_ranked` și `nice()`.

Piesele au intenționat o valoare ne-zero, ca un venit care le-ar număra să pice. Prima variantă lăsa să treacă trei inversări, găsite de verificator: fără garda câștigului la `nets_line`, `nets_line` scris și când veriga nu e `nets`, și pașii unirii verificați înaintea pieselor. Acum sunt inversate, pe rând, 22 de reguli ale motorului, și fiecare pică verificarea (scriptul de mutații n-a rămas în repo).

**`golden_chain.py` (pasul c).** Blocurile tipăresc doar `GOLDEN_LINES` și `GOLDEN_SELLERS` (Erele 1–3). Dovada: cu liniile de probă ale unirii adăugate închise în simulator, iese același text. Fără filtru, `GOLDEN_ERA2` și `GOLDEN_ERA3` s-ar fi schimbat.

**Rămâne pentru pasul d, pe bazin:** `check_hire_order`, `link_share` / `LATE_LINE`, `report_era` (banii doar pe liniile care vând) și `BOTTLENECK_EXEMPT`.

## 11. Cum a ieșit pasul d (2026-09-30, după verificator)

**Era 4 e în simulator.** Erele 1–3 ies identice la octet: rularea simplă, `--table --chain`, cele trei blocuri din `golden_chain.py` și porțiunea lor din `--robust`. Singura diferență e că ieșirile au acum și Era 4, la coadă. `tune_tycoon.py eval` dă aceleași cifre; rândul cu toate verigile le listează acum și pe ale Erei 4, la 0%.

**Cifrele, față de prototipul B:**

| | Prototip | Simulator |
|---|---|---|
| venitul la baraj | 19,6B/s (×16,2) | 19,57B/s (×16,2) |
| cei șase oameni noi | 1,58T (4,5%) | 1,58T (4,5%) |
| primele 5 minute (C5) | 8,13T | 7,48T |
| o noapte la Works Bell | 34,86T | 34,86T |
| `START_SUM` | 35T | **35T** |
| Era 4, cu suma | 41m49s | 1h05m reale (fără bani: 1h14m) |
| cel mai lung platou (venit pe loc) | 16m41s (pica) | 7m51s (Erele 1–3: 6m28s / 9m10s / 10m51s) |
| cel mai lung tronson cu creștere sub 10% | — | 20m06s (Erele 1–3: 9m30s / 15m25s / 20m58s) |

**Ce e în cod:**
- **Tabelele** din §2: patru linii noi (`barrels`, `cable`, `grid`, `crystal`), `closeFlag = "dam"` pe cele șase vechi, cinci clădiri (Switchyard, Cable Works, Relay, Kiln, orașul), 15 oameni (`ERA4_ROLES`), bunurile și prinderile fără găsiri.
- **`dam_transform`**, pe o clonă a stării de la Works Bell: barajul, cei cinci veterani pe treapta 1, turbina zidită (rang 5) și Cable Net 1 gratis, suma de start.
- **`ERA4_UNLOCKS` pe familii:** cei șase în rafală (9–18 secunde de venit, ca oamenii capitolului 1), plasele de cablu și a doua turbină (după a treia plasă de cablu), Kiln doar cu toți cei 11 și a patra plasă de cablu, Crystal Net, **Crystal Shed** (în oglindă cu Battery Shed; planul nu-l numea), cei patru ai cristalului, al doilea om pe fiecare meserie a erei, Dam Bell. Al doilea om al erelor vechi nu mai e de cumpărat: liniile lor sunt închise.
- **Quest-ul „nivelul 2 pe ultima plasă”, pe familii:** era își spune singură plasa (`quest_net`). Ca în Erele 2–3, capitolul cere nivelul 2 pe plasa dinaintea atelierului erei (aici a patra de cablu), apoi atelierul (Kiln-ul).
- **`AWAY`** și `away_income`, ca `idleOnly` din ChainMath: cât lipsești, pașii fără om nu merg, iar vânzătorul fără omul lui nu vinde.
- **`DamRun` / `play_era4`:** cele două rulări din §5. Rularea cu suma primește prețurile celei fără bani (`seed_prices`).
- **Porțile:** `check_run_era(4)` pe rularea cu suma, apoi `check_dam`:
  - suma sare cel mult 25%;
  - saltul la baraj e între 8 și 30;
  - AWAY după cei șase e cel puțin cât la Works Bell;
  - cei șase costă cel mult 10% din sumă;
  - platoul e cel mult cât cel mai lung din Erele 1–3;
  - tronsonul cu creștere sub 10% e cel mult cât cel mai lung din Erele 1–3;
  - nicio meserie nu are mai mult de jumătate din treptele luate pe veriga arătată cu câștig zero.
- **`robust_era4`:** 15 constante × 2, fiecare cu ambele rulări, cu pragul verigilor pe jumătate (ca la Erele 2–3) și cu marja `ROBUST_FLAT_SLACK = 1,35` pentru platou și pentru creșterea sub 10%. La ±15%, Era 4 ține între 45m34s și 1h08m, platoul iese cel mult 10m24s (sub 10m51s chiar fără marjă), iar creșterea sub 10% cel mult 23m16s.
- **Testele de mână, în `check_lines.py`:** `nice_up`, `longest_flat`, `longest_crawl`, `spend_share`, `away_income` (și că `AWAY` revine după o eroare), `dead_tiers`.
- **Raportul Erei 4:** suma și din ce vine, saltul, AWAY, platourile și creșterea sub 10% pe ere, banii pe linii, prețurile, apoi monedele Robux păstrate peste sumă (doar raport).

**Ce a găsit verificatorul și cum s-a reparat:**
- **Egalități permanente.** Dam Collector și Cable Collector aveau aceeași bază (4,0), la fel Cable Hauler și Pylon Runner (7,0). Pașii celor două piese intră în același minim al unirii, deci egalitatea ținea toată era, iar fiecare treaptă pe veriga arătată dădea zero. Bazele sunt acum diferite și nu se pot egala pe trepte: Dam Collector 4,4, Dam Porter 6,2, Pylon Runner 6,5.
- **Platoul măsura doar creșterea exact zero.** Un șir de niveluri de plasă de +0,3% repornea numărătoarea, deși pe ecran cifra abia se mișca. Cu uneltele la prețul Erelor 1–3, suma de start le cumpăra pe toate în primele minute. Cei doi colectori ajungeau la plafon (2 oameni × treapta 5) devreme, iar venitul creștea sub 10% timp de 26 de minute. Remediul, din cifre (D70 Runda 5):
  - **uneltele oamenilor barajului costă dublu** (`ROLE_COST_MULT = 2 × ERA4_MULT`);
  - **scara Erei 4 pornește de la 7,0.**

  Am încercat și Kiln după a treia plasă de cablu (platou mai scurt, dar Era 4 sub 40 de minute și jumătate din verigi decor) și a doua turbină după Kiln (Era 4 spre 75 de minute).
- **AWAY lăsa orașul să vândă fără om.** Jocul (`idleOnly`) nu o face; acum nici simulatorul.
- **Quest-ul Kiln-ului nu se aprindea niciodată.** Acum capitolul cere nivelul 2 pe a patra plasă de cablu, apoi Kiln-ul.
- **O egalitate între piese dă uneori o treaptă cu zero** (riscul 3). E cinstit [D46], iar ecranul numește linia cealaltă. Poarta prinde doar egalitatea permanentă.

**Ce a ieșit altfel decât în plan:**
- **`check_hire_order` rămâne pe linii, nu pe bazin.** Pe linie, ultimul drum al fiecărei linii trebuie să ducă tot timpul tău (5,4). Pe bazin i s-ar cere doar partea lui din pașii rămași. Regula pe linii e deci mai strictă și o acoperă pe cea pe bazin.
- **`check_config_constants` compară `ROLE_BASE` doar pe erele din configurație** (`CONFIG_ERAS = (1, 2, 3)`). Era 4 intră în `StationConfig` la pasul f, iar atunci `CONFIG_ERAS` primește 4.
- **„~2–3 minute fără câștig cât lipsești” vine din rularea fără bani.** Cu suma de start, cei șase costă 4,5% din ea și se pot angaja din prima clipă. AWAY = 0 ține doar cât faci drumul la aviziere. Textul din joc (pasul k) spune ce faci („angajează cei 6”), nu minute.
- **Marja de la `--robust`** (1,35) a fost aleasă după ce se văzuse cel mai rău caz al primei variante (14m04s). E o marjă de zgomot, nu o dovadă.
- **Timpul simulatorului s-a dublat** (10,5 → ~23 s pentru rularea simplă, ~10 minute pentru `--robust`): Era 4 se joacă de două ori, iar lanțul are patru linii în plus.

**Următorul pas: e** (`golden_chain.py --era4` → `GOLDEN_ERA4`).
