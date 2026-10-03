# Planul: motorul lanțului cu unire și baraj, pentru Era 4 și după [D70]

**Stare (2026-10-03): pașii a–i sunt făcuți** (a–c: motorul general, fără Era 4, §10; d: Era 4 în simulator, §11; e: `GOLDEN_ERA4`, §12; f–g: configurația și `ChainMath`, §13; h: `HeldBack`, §14; i: modulele comune, §15). **Pasul j e împărțit în j1–j15, k1–k12, l1–l3 (§16, 2026-10-03)**; singurul commit care schimbă jocul viu e l3. Harta lumii 2 e aprobată (D74, PLAN-HARTA §9). [Starea din 2026-09-29, păstrată: pașii a–c făcuți; owner-ul a hotărât întrebările 2, 4 și 8 din §6 (piesele se vând doar unite, suma de start e cea din simulator, 35T, iar cristalul se vinde și în Era 4), apoi, pe 2026-09-30, 1, 3, 6 și 7 cu variantele recomandate. Au rămas deschise 9–11; 5 și 12 le-a închis D74, punctele 8 și 7.] Planul pornește de la designul B, cu barajul dat întreg și cablul lucrat de mână. Din designul A am luat patru lucruri: filtrul tabelelor de aur, locul de unde ia curierul, formula monedelor Robux și regula plaselor pe familii. Pe fiecare le-am verificat în cod. Cifrele vin din prototipuri (copii ale simulatorului, în afara repo-ului), rulate din nou de judecător. Cifrele finale se derivă doar în `sim_tycoon.py`.

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
- `ROLE_BASE` (după verificator, 2026-10-01; prototipul avea 4,0 / 6,0 / 7,5 / 4,0 / 5,0 / 7,0 / 7,0):
  - linia bateriilor: damCollector 4,7, damPorter 6,3, barrelHauler 7,3;
  - linia cablului: cableCollector 4,0 (vezi riscul 1), cablePorter 5,4, cableHauler 6,7;
  - unirea: pylonRunner 6,5 (ultimul drum al unirii duce tot timpul tău, 5,4, și la −15%: `check_hire_order`);
  - cristalul: crystalCollector 2,0, crystalPorter **2,7** (nu 2,5 ca bateria din Era 3: 2,0 × 5 = 2,5 × 4 ținea linia
    la egalitate jumătate de eră), ingotHauler 6,5.

  Cei șapte oameni care intră în minimul unirii, și cei trei de drum ai cristalului, nu pot avea același debit (bază ×
  treaptă × oameni): `walker_ties` din `check_lines.py` pică pe orice egalitate.
- `ERA4_ROLES` au `ROLE_COST_MULT = 2 × M4`: uneltele barajului costă dublu față de cadru (`ERA_TOOL_MULT[4] = 2`). În joc
  factorul are nume, `StationConfig.TOOL_COST_MULT[4] = 2`, iar `check_config_constants` îl compară pe fiecare eră din
  configurație.
- Scutiri noi în `BOTTLENECK_EXEMPT`: `crystalPort` și `ingotHaul`, în oglindă cu `batteryPort` și `powerHaul`.

**Plasele primesc rang explicit, nu loc în listă.** Turbinele și plasele de cablu se cumpără amestecat, deci `NETS_PER_ERA` rămâne doar pentru plasele 1–15.
- `unlock_net_ranked(kind, rank, lane)` pune `Net.base = 0.33 × 1.45^(rang−1)` și `Net.upgrade_base = 1.45^(rang−1) × M4`. Câmpul `upgrade_base` există deja.
- Rangurile:

| Plasa | Rang | Cum vine |
|---|---|---|
| Dam Turbine | 5 | zidită în baraj, gratis |
| Cable Net 1 | 1 | gratis |
| Cable Net 2–3 | 2–3 | cumpărate |
| Crystal Net | 5 | spre final |

[owner, 2026-10-01, varianta 1 din §11] Fără a doua turbină și a patra plasă de cablu: nu aduceau nimic (colectorii erau
deja plini), iar pe hartă deschideau Dam Bell pe la minutul 27. Dam Bell se deschide acum la un venit (`DAM_BELL_INCOME`).

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

**În joc** se reiau pașii 5 și 7 din `PLAN-HARTA.md` (`DamMath.build`, `DamService`, profilul v19; v18 e seria zilnică, D71). Formula veche („păstrezi până la o noapte”) se înlocuiește cu suma fixă:
- `R = min(monede, Purchases.coinsBought)`: monedele Robux încă în mână, socotite ca ultimele cheltuite [2026-10-03, R8: contorul se taie la cheltuire, nu există niciun reper „de la Works Bell”];
- `monede' = START_SUM + R`;
- `Stats.damGift = max(0, monede − R − START_SUM)`;
- pe ecran se vede și cât completează satul.

`TycoonConfig.DAM_START_COINS` trebuie să fie egal cu suma derivată. Simulatorul o verifică, la fel ca prețurile.

**[2026-10-03] Ce s-a lămurit la pasul j (§16):**
- **R, „ultimele cheltuite”, se ține cu un contor tăiat la cheltuire** (§16, R8): contorul crește la acordare și se taie la
  `min(contor, Coins)` la fiecare scădere. Nu există niciun reper la Works Bell; contorul stă în `Purchases.coinsBought`.
- **`DAM_START_COINS` nu există încă în cod:** vine în j2, ca `35000000000000`, iar simulatorul o compară cu suma lui.
- **`START_SUM` din text se numește în cod `DamRun.start_sum`** (`sim_tycoon.py`, `self.start_sum`).
- **Poarta monedelor Robux e a simulatorului** (D74, punctul 8): `PAID_COINS_MAX_SHARE = 0.40`, azi ~33%. Nu taie nimic la
  jucător.

## 6. Întrebări pentru owner, de la Era 1 la Era 8

Întrebările sunt puse în pașii jucătorului. Fiecare are recomandarea mea. **Pașii a–i sunt făcuți. Pașii j–l (§16) pornesc fără alt răspuns: opțiunile rămase sunt luate provizoriu ca recomandate (§16, O1), iar doar arta (aprobarea și fiecare urcare) cere owner-ul, explicit.** [2026-10-03; înainte: „Pașii a–c nu așteaptă răspunsurile. Pașii d–l le așteaptă.”] Deja hotărât, nu mai întreb: Erele 1–3 rămân cum sunt, iar la baraj satul vechi se oprește. De la Era 4 fiecare eră are trei linii: două fac piese, a treia le unește, iar cumpărătorul e altul la fiecare eră.

1. **Era 4, începutul.** Veteranii fac linia bateriilor, iar tu faci cablul de mână? *Recomandat: da.* Invers, n-ai avea ce face cu mâna pe linia bateriilor. **Hotărât (owner, 2026-09-30): da.**
2. **Bateriile (butoaiele) se vând și singure?** Ai spus „bateriile se vând la preț bun”. În planul acesta ele valorează bani doar unite cu cablul, ca curent vândut orașului, iar singure așteaptă la Relay. *Recomandat: nu se vând singure.* Dacă vrei să se vândă, e nevoie de o a doua ieșire pentru ele, cu altă poartă de venit. **Hotărât (owner, 2026-09-29): se vând doar unite.** Butoaiele așteaptă cablul la Relay.
3. **Cine duce curentul la oraș?** *Recomandat:* un Pylon Runner, pe podul cu stâlpi, până la Switch House, unde stă Dispatcher-ul. Varianta cealaltă: Relay-ul vinde direct, cu un om mai puțin. **Hotărât (owner, 2026-09-30): Pylon Runner.**
4. **Suma de start e 35T, nu 40T:** e cifra scrisă de simulator. Fără tine câștigi 0 cam 2–3 minute, până la cei 6 oameni, iar ecranul spune asta dinainte. E în regulă? **Hotărât (owner, 2026-09-29): da.** Suma e cea derivată de simulator (35T pe proba de azi), iar AWAY e 0 până la cei 6 oameni noi.
5. **Monedele Robux trec întregi.** În cel mai rău caz (Welcome Back x2 după 16 h cu 2x Flow), sar ~33% din Era 4. *Recomandat:* limită de 40% doar pentru monedele plătite, sau nicio limită. Tu alegi. **Hotărât (owner, 2026-10-03, „ia recomandatele și continuă”): D74, punctul 8.** Monedele plătite trec întregi peste suma de start (nimic plătit nu se taie, D70), iar limita de 40% e o poartă a simulatorului (`PAID_COINS_MAX_SHARE`, azi ~33%), nu o tăiere la jucător.
6. **Plasele de sub baraj nu mai prind găsiri** (o găsire nu se poate uni cu un butoi). Surprizele rămân darurile râului. *Recomandat: da.* **Hotărât (owner, 2026-09-30): da.**
7. **Pe la minutul 29 al Erei 4, venitul poate sta pe loc ~16 minute:** Cable Collector-ii sunt la maxim (2 oameni, treapta 5). *Recomandat:* repar cu cifrele, în simulator. Varianta a doua: un al treilea om pe meserie de la Era 4 („progresiv cu jocul”). **Hotărât (owner, 2026-09-30): din cifre.**
8. **Era 4, finalul.** Cristalul se vinde în Era 4, primul la oraș (ca fierul, cuprul și curentul), și tot cu el începe Era 5? *Recomandat: da.* Altfel ultimele ~11 minute ale erei nu aduc nimic. **Hotărât (owner, 2026-09-29): da.** Cristalul se vinde în Era 4, primul la oraș, și pornește Era 5.
9. **Erele 5–7.** Curierul care aduce produsul erei vechi vine gratis cu poarta erei noi? Ia el întâi, iar clădirea veche vinde ce rămâne? *Recomandat: da, la amândouă.*
10. **Era 6.** Un robot face cât un om, doar arată altfel? *Recomandat: da.* Motorul rămâne neschimbat.
11. **Era 8.** Etapele rachetei se cumpără cu monede, ca un clopot, din banii tuturor liniilor, fără o linie nouă de marfă? Lansarea e renașterea: +50%, fără să pierzi ceva plătit. *Recomandat: da.*
12. **Numele** (Switchman, Barrel Hauler, Cable Works, Relay Keeper, Pylon Runner, Switch House, Dispatcher) sunt propuneri. **Hotărât (owner, 2026-10-03): D74, punctul 7.** Rămân: Battery Store (unde Dam Collector-ul lasă bateriile; în §14 apărea „Dam Store”), Switchyard, Cable Works, Relay Station, Kiln, Switch House; oamenii Switchman, Relay Keeper, Pylon Runner, Dispatcher.

## 7. Pașii

La fiecare pas: toată poarta din CLAUDE.md, apoi commit și push.

| Pas | Ce | Cum se verifică |
|---|---|---|
| a | **Simulatorul, motorul (fără Era 4).** Cheile și invariantele; `open` / `supply` / `catch`; bazinul; trecerea înapoi; `credit`, `heldBy`, `netsLine`; venitul doar pe liniile care vând; `options` sare liniile închise; `unlock_net_ranked`; `nice()` urcă până la 10^24 (azi se oprește la 10^12 și întoarce `int(x)` nerotunjit) | ieșirea completă `--table --chain --robust`, rularea simplă și două `tune_tycoon.py eval`, identice la octet |
| b | **`check_lines.py`.** Unire de probă cu cifre socotite de mână: startul barajului; piese la egalitate (amândouă au câștig, fiecare singură dă 0); unirea ținută de Relay, apoi de vânzător; `closeFlag`; bazinul | rulează odată cu simulatorul; o regulă inversată îl pică |
| c | **`golden_chain.py`.** Blocurile de azi tipăresc doar liniile și vânzătorii Erelor 1–3 (azi buclele merg pe tot `LINE_ORDER`) | diferența față de `tests/ChainMath.test.luau` e goală |
| d | **Simulatorul, Era 4** (după răspunsuri). Rândurile din §2; `ERA4_UNLOCKS` pe familii (6 oameni în rafală, plasele, Kiln doar cu toți cei 11, cristalul, Dam Bell); `dam_transform`; cele două rulări; `START_SUM`; porțile din §5; `LATE_LINE[4]`; `report_era(4)` pentru N linii | `--robust` verde, cu `check_flat`; porțiunea Erelor 1–3 identică la octet |
| e | **`golden_chain.py --era4` → `GOLDEN_ERA4`.** Șase stări: startul barajului, după cei 6, butoaiele țin, egalitatea butoaie–cablu, Town plin, cristalul primul | tabelul generat |
| f | **Configurația.** `StationConfig` (rânduri prin referință, derivate noi, `TOOL_COST_MULT[4] = 2`, `CONFIG_ERAS` primește 4); `TycoonConfig` (GOODS, CATCH, PROCESSED, JOINED, platformele cu `netRank` și prețuri din simulator, `DAM_START_COINS`); pragurile de venit (`KILN_INCOME` al capitolului, `DAM_BELL_INCOME` al clopotului) ca scalari în `StationConfig`, citiți prin referință de `QuestConfig` și `TycoonConfig` și comparați de `check_config_constants` (regexul trebuie să accepte exponentul: azi `1e12` s-ar citi 1); Dam Bell cu `Needs.income = DAM_BELL_INCOME`, un fel nou de condiție citit de TOȚI cititorii unei platforme (`meetsNeeds`, `padStatuses`, `padBlocker`; pe server `PadService.Statuses` / `Buy` / `Deltas`, pe client `PadController.ruinNeeds`), cu venitul din HUD, iar statusurile se recalculează și după un nivel sau o treaptă, nu doar după o platformă. **Pragurile (`KILN_INCOME`, `DAM_BELL_INCOME`) se înmulțesc cu `PassMath.flowFactor`**: cu 2x Flow, cartonașul și pasul scriu 8T, ca era să-și păstreze conținutul (oamenii a doua vin înaintea clopotului) și pass-ul să dea tot jumătate din timp [verificator, 2026-10-01: fără scalare, cu 2x Flow clopotul suna la ~18 minute, fără niciun om al doilea]. Cartonașul ruinei scrie doar pragul („Opens at 4T coins a second”); cât mai e până la el arată contorul quest-ului (PadController îl desenează o singură dată pe țintă, deci un număr care curge ar îngheța); `Strings`. Era 4 cu `live = false` | stylua, selene, `sim --robust` (`check_config_constants` și `check_config_prices` extinse) |
| g | **`ChainMath`.** `model`, `flowWith` în trei treceri, `pickBottlenecks`, `valueWith`, totaluri, `empty`, `clone`, `supply`, `heldBy`, `netsLine`. Comparația veche–nouă pe 80.000 de stări, apoi scoasă | GOLDEN*, `GOLDEN_ERA4`, „liniile ca date” cu unirea de probă |
| h | **`HeldBack`.** `among` = grupul liniei (ea, piesele, unirea); `nets` doar pe liniile de plase; gardă pentru un `seller` nil (azi :133/:135); textele „the Cable line is slower” / „just as slow as the Barrel line”; când `heldBy` e o linie închisă, `Strings.lineNotOpen(heldBy)` („cast the Cable Net first”) cu Go to spre plasă, nu „is slower” | teste noi |
| i | **Modulele comune.** `FlowConfig` (`into`, `inputPiles`, `SELLERS.town`); `FlowMath.assemble` (`min(întregi, nA, nB)` perechi); `sellerOf(piesă) = nil`; refuzul `part_to_relay`; `split` primește piese la Relay; `HandRoutes` cu `job` pe pas, drumul pieselor la `inputIn` al Relay-ului | teste Lune |
| j | **[2026-10-03: împărțit în j1–j15, vezi §16; rândul de mai jos rămâne lista inițială, incompletă.]** **Serverul.** `EconomyService` (unirea merge doar cu ambele intrări nevide, `assemble`, `DropAt` pe fel de piesă, liniile închise fără tick); `HandService` (sare oamenii retrași); `NetService` (nu mai umple plasele închise); `StationService` (`StateFrom` cu `dam` și rangurile, garda din `BUILDING_ROWS`, `Snapshot` cu `supply` / `heldBy` / `netsLine`); `DamService` și profilul v19 după PLAN-HARTA, cu suma din §5 | teste: migrarea păstrează numele și chipul celor 5; `StateFrom` reproduce `dam_transform` |
| k | **[2026-10-03: împărțit în k1–k12, vezi §16; rândul rămâne lista inițială.]** **Clientul.** `LineController` pentru unire (două grămezi, „Waiting for cable/barrels”); `Overlay.DROP_AT`; `Bootstrap` copiază explicit câmpurile noi; `GuideMath` pentru primul tur (6 pași de mână); capitolele 10–12, în ordinea `DAM_CHAPTER`, cum le joacă a treia rulare din `DamRun`: a doua și a treia plasă de cablu, pasul „Earn 1T coins a second” (`KILN_INCOME`), Kiln-ul și cristalul, pasul „Earn 4T coins a second” (`DAM_BELL_INCOME`, același prag ca platforma), Dam Bell. Fără pasul ăsta, „Ring the Dam Bell” ar sta ~16 minute pe un clopot încuiat, cu 0/1 și fără contor (capcana Kiln-ului; verificator, 2026-10-01). Testul de ordine din `QuestMath` („niciun quest nu cere ceva ce încă nu se poate cumpăra”) învață că un quest de venit împlinește un `Needs.income` de după el. Pasul de venit e un fel nou de quest, pe venitul din HUD; ținta și eticheta lui sunt pragul platformei înmulțit cu `PassMath.flowFactor`, din aceeași funcție ca cartonașul clopotului (cu 2x Flow: „Earn 8T coins a second”). Pass-ul tot înjumătățește timpul, pentru că banii vin dublu. Numele pașilor de mai sus sunt etichetele fără pass. Nu ca la quest-ul AWAY, al cărui prag (1) nu se scalează: altfel, cu 2x Flow, quest-ul s-ar bifa la 4T pe HUD, iar clopotul ar cere 8T. Contorul lor trece printr-o singură funcție, `QuestMath.counterText`, folosită și de lista de quest-uri (`QuestController`), și de linia NEXT (`HUDController`): „966B/1T”, cu `TycoonMath.formatNumber`, nu „966000000000/1000000000000”. Lista renunță la paranteze pentru toate quest-urile („3.99T/4T” are ~58 px la 13, cutia are 60; cu paranteze, ~73). `Theme.fitSize` nu ajută: contorul e deja la `TEXT.tiny`. Pe un quest de venit, pasul ghidat nu poartă `price`, deci `HUDController.SetStep` nu suprascrie bara: linia NEXT arată venitul spre prag, nu monedele unui nivel. Cât ține un pas de venit, și cât Dam Bell așteaptă pragul, ghidajul arată veriga cu câștig real pe care se mai poate cumpăra ceva: sare meseriile la `MAX_PEOPLE` × `TIER_MAX`, ca `AmbitionMath`, iar dacă nu rămâne nimic, trece la veriga slabă a celeilalte linii a vânzătorului. Spre plafon, veriga globală e un Crystal Collector deja plin. Regulă generală: `GuideMath` nu pune „While you save” și nici bara de preț pe un quest a cărui platformă nu e încă `available`; indiciul AWAY | poarta, sonda pe texte și testele Lune din §8 (QuestMath, GuideMath) |
| l | **[2026-10-03: devine l1–l3, vezi §16; comutatorul `ENGINE_ERAS = 4` și `live = true` sunt l3.]** **Sonda, cap-coadă, pe profil de probă:** Works Bell → Build the Dam → turul → cei 6 → Kiln → Dam Bell. Arta se face pe planșe și se urcă doar cu acordul owner-ului. `live = true` doar după Studio | `errors` e gol; niciun text nu iese din cutie |

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
- **Pașii de venit ai capitolului (pasul k):**
  - `QuestMath`: progresul e venitul din HUD, cu pass-urile; quest-ul e gata la prag; fără câmpul de venit în `Facts`, progresul e 0, fără eroare;
  - `QuestMath.counterText`: „966B/1T”, fără paranteze; la goal și la 0,999 × goal, `#s × 0,5585 × TEXT.tiny` ≤ 60 px (lista) și ≤ 80 px (NEXT), pentru `KILN_INCOME` și `DAM_BELL_INCOME`;
  - `GuideMath`/HUD: pe un quest de venit, pasul ghidat n-are preț, iar bara NEXT rămâne venitul;
  - `GuideMath`: un quest cu platforma ne-`available` nu primește preț și nici „While you save”; pe un pas de venit, ghidajul numește o verigă pe care se mai poate cumpăra ceva;
  - pragurile din `QuestConfig` / `TycoonConfig` sunt exact `StationConfig.KILN_INCOME` / `DAM_BELL_INCOME`;
  - ținta quest-ului de venit și `Needs.income` al clopotului ies din aceeași funcție (de pildă `TycoonMath.incomeGoal(base, flowFactor)`): cu 2x Flow quest-ul nu se bifează sub pragul clopotului;
  - `Needs.income` pe Dam Bell: sub prag, `padStatuses` și `padBlocker` spun amândouă „încuiat” și dau același motiv; peste prag, amândouă „de cumpărat”; cu 2x Flow pragul se dublează (8T pe HUD, adică același venit de bază), iar cartonașul scrie cifra dublată (testul de potrivire de la `TycoonMath.test.luau` extins la Era 4);
  - testul de ordine din `QuestMath`: un quest de venit („Earn 4T coins a second”) împlinește `Needs.income` al clopotului de după el.
- **Uneltele Erei 4 (pasul f):** `ChainMath.tierCost(1, "damCollector") == 25 * StationConfig.ERA4_MULT * 2`, cu 2 scris de mână, ca testele de la Erele 2–3.

## 9. Riscuri

1. **Zidul de la mijlocul erei.** În prototipul B, Cable Collector-ul are baza 3,0. La 2 oameni pe treapta 5 duce 30/s, iar venitul stă la 1,78T/s de la 29m16s: **16m41s fără creștere** până la Crystal Net. Erele 1–3 au avut cel mult 10m52s, iar A 10m42s. `check_flat` prinde asta. Remediul îl alege simulatorul: baza 4,0, Kiln mai devreme sau întrebarea 7.
2. **Bazinul ține doar prin ordinea deblocărilor.** O linie deschisă peste pași de mână diluează timpul tău. Condițiile platformelor (Kiln cere toți cei 11), `check_hire_order` pe bazin și `VIOLATIONS` trebuie să o țină.
3. **Egalitățile între piese dau cumpărături cu câștig 0.** E cinstit [D46], dar textul trebuie să numească linia cealaltă. Ce se înțelege pe ecran vede owner-ul în Studio.
4. **AWAY e 0 după baraj**, până la cei 6 oameni. Ecranul și Welcome back o spun dinainte [D43].
5. **Tabelele de aur pot pica doar ca text.** Fără filtrul din pasul c, tabelele de aur s-ar schimba prin liniile închise în plus.
6. **Câmpurile noi trebuie copiate explicit pe client:** `supply`, `heldBy`, `netsLine`, `isOpen`, `waiting` (k3),
   `awayStalled`, `unhired` (k6), `partBy` din traistă, `inputs` / `waiting` ale atelierului unirii (k3), chitanța barajului
   (`DamController.copyReceipt`, făcut). Un câmp scos trebuie căutat la toți cititorii (capcana din CLAUDE.md).
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

## 11. Cum a ieșit pasul d (2026-09-30, după verificator; rundele 2–5 pe 2026-10-01)

**Era 4 e în simulator.** Erele 1–3 ies identice la octet: rularea simplă, `--table --chain`, cele trei blocuri din `golden_chain.py` și porțiunea lor din `--robust`. Singura diferență e că ieșirile au acum și Era 4, la coadă. `tune_tycoon.py eval` dă aceleași cifre; rândul cu toate verigile le listează acum și pe ale Erei 4, la 0%.

**Cifrele, față de prototipul B:**

| | Prototip | Simulator |
|---|---|---|
| venitul la baraj | 19,6B/s (×16,2) | 19,57B/s (×16,2) |
| cei șase oameni noi | 1,58T (4,5%) | 1,58T (4,5%) |
| primele 5 minute (C5) | 8,13T | 8,13T |
| o noapte la Works Bell | 34,86T | 34,86T |
| `START_SUM` | 35T | **35T** |
| Era 4, cu suma | 41m49s | 45m16s reale (fără bani: 54m55s) |
| cel mai lung platou (venit pe loc) | 16m41s (pica) | 6m27s (Erele 1–3: 6m28s / 9m10s / 10m51s) |
| cel mai lung tronson cu creștere sub 10% | — | 8m20s (Erele 1–3: 9m30s / 15m25s / 20m58s) |
| capitolul (plasele cum ai banii) | — | 43m46s, Kiln la 17m09s, platou 6m59s, creștere sub 10% 8m40s, pauza 2m15s lacome (4m03s reali; poarta: 3 minute lacome) |
| plafoanele pragurilor de venit (`dam_ceiling`) | — | 2,37T/s înainte de Kiln (pasul cere 1T/s), 4,89T/s înainte de clopot (Dam Bell cere 4T/s) |
| la Dam Bell | — | 4,95T/s; cristalul aduce 55,9% din bani; Dam Bell costă 600T |

**Ce e în cod:**
- **Tabelele** din §2: patru linii noi (`barrels`, `cable`, `grid`, `crystal`), `closeFlag = "dam"` pe cele șase vechi, cinci clădiri (Switchyard, Cable Works, Relay, Kiln, orașul), 15 oameni (`ERA4_ROLES`), bunurile și prinderile fără găsiri.
- **`dam_transform`**, pe o clonă a stării de la Works Bell: barajul, cei cinci veterani pe treapta 1, turbina zidită (rang 5) și Cable Net 1 gratis, suma de start.
- **`ERA4_UNLOCKS` pe familii:** cei șase în rafală (9–18 secunde de venit, ca oamenii capitolului 1), plasele de cablu 2 și 3, Kiln doar cu toți cei 11 și a treia plasă de cablu (`KILN_CABLE_NETS`, ultima), Crystal Net, **Crystal Shed** (în oglindă cu Battery Shed; planul nu-l numea), cei patru ai cristalului, al doilea om pe fiecare meserie a erei, Dam Bell (cu toți cei 15 și venitul de 4T/s, `DAM_BELL_INCOME`). Al doilea om al erelor vechi nu mai e de cumpărat: liniile lor sunt închise.
- **Quest-ul „nivelul 2 pe ultima plasă”, pe familii:** era își spune singură plasa (`quest_net`). Ca în Erele 2–3, capitolul cere nivelul 2 pe plasa dinaintea atelierului erei (aici a treia de cablu), apoi atelierul (Kiln-ul), dar abia după pasul de venit de 1T/s.
- **`AWAY`** și `away_income`, ca `idleOnly` din ChainMath: cât lipsești, pașii fără om nu merg, iar vânzătorul fără omul lui nu vinde.
- **`DamRun` / `play_era4`:** cele două rulări din §5. Rularea cu suma primește prețurile celei fără bani (`seed_prices`). A treia rulare e capitolul: pe aceleași prețuri și cu aceeași sumă, plasele de cablu 2 și 3 se iau cum ai banii (`DAM_CHAPTER`); pentru pasul curent strângi cât banii vin în cel mult 60 de secunde de venit (`DAM_CHAPTER_PATIENCE`; între 30 și 120, aceeași cronologie).
- **Porțile:** `check_run_era(4)` pe rularea cu suma, apoi `check_dam`:
  - suma sare cel mult 25%;
  - saltul la baraj e între 8 și 30;
  - AWAY după cei șase e cel puțin cât la Works Bell;
  - cei șase costă cel mult 10% din sumă;
  - platoul e cel mult cât cel mai lung din Erele 1–3;
  - tronsonul cu creștere sub 10% e cel mult cât cel mai lung din Erele 1–3;
  - pe rularea capitolului: platoul, creșterea sub 10%, durata (40–75 de minute reale) și pauza (cel mult 3 minute);
  - plafonul fiecărui prag de venit e cu cel puțin 10% peste el (`DAM_STEP_MARGIN`): pentru pasul Kiln-ului, cel de dinaintea Kiln-ului (fără cristal), pentru Dam Bell, cel de dinaintea clopotului;
  - nicio meserie nu are mai mult de jumătate din treptele luate pe veriga arătată cu câștig zero;
  - al doilea om al unei meserii costă mai mult decât treapta ei 5. Podeaua din prețuri e 1,25 × treapta 5, înainte de rotunjire (`SECOND_FLOOR`, din `price_floor`); `nice()` poate lua până la 7%, deci Cable Collector-ul iese 45T, adică 1,23×.
- **`robust_era4`:** 15 constante × 2, fiecare cu toate trei rulările, cu pragul verigilor pe jumătate (ca la Erele 2–3) și cu marja `ROBUST_FLAT_SLACK = 1,35` pentru platou și pentru creșterea sub 10%. La ±15% (după varianta 1 și scara 8,5), Era 4 ține între 44m07s și 1h03m, platoul iese cel mult 6m50s, iar creșterea sub 10% cel mult 15m59s; amândouă sub cele mai lungi din Erele 1–3 (10m51s și 20m58s) chiar fără marjă. Pauza cea mai lungă e 2m55s lacome (poarta: 3 minute). Capitolul ține între 42m03s și 51m36s, cu pauza cel mult 2m40s lacome. (Înainte de a doua rundă: 45m34s–1h08m, 10m24s, 23m16s.)
- **Testele de mână, în `check_lines.py`:** `nice_up`, `longest_flat`, `longest_crawl`, `spend_share`, `away_income` (și că `AWAY` revine după o eroare, și zero cu linia lemnului plină fără Innkeeper), `dead_tiers`, `walker_ties` (bazele Erei 4 n-au nicio egalitate în unire și pe cristal; doi colectori la 4,0 o au, la fel cristalul în oglinda Erei 3), `Chain.solo` (la egalitate niciuna dintre verigi nu aduce singură).
- **Raportul Erei 4:** suma și din ce vine, saltul, AWAY, platourile și creșterea sub 10% pe ere, banii pe linii, prețurile, apoi monedele Robux păstrate peste sumă (doar raport).

**Ce a găsit verificatorul și cum s-a reparat:**
- **Egalități permanente.** Dam Collector și Cable Collector aveau aceeași bază (4,0), la fel Cable Hauler și Pylon Runner (7,0). Pașii celor două piese intră în același minim al unirii, deci egalitatea ținea toată era, iar fiecare treaptă pe veriga arătată dădea zero. Bazele au devenit diferite (Dam Collector 4,4, Dam Porter 6,2, Pylon Runner 6,5), dar se mai egalau pe trepte; a doua rundă le-a schimbat din nou (mai jos).
- **Platoul măsura doar creșterea exact zero.** Un șir de niveluri de plasă de +0,3% repornea numărătoarea, deși pe ecran cifra abia se mișca. Cu uneltele la prețul Erelor 1–3, suma de start le cumpăra pe toate în primele minute. Cei doi colectori ajungeau la plafon (2 oameni × treapta 5) devreme, iar venitul creștea sub 10% timp de 26 de minute. Remediul, din cifre (D70 Runda 5):
  - **uneltele oamenilor barajului costă dublu** (`ROLE_COST_MULT = 2 × ERA4_MULT`);
  - **scara Erei 4 pornește de la 7,0** (6,5 după a doua rundă).

  Am încercat și Kiln după a treia plasă de cablu (platou mai scurt, dar Era 4 sub 40 de minute și jumătate din verigi decor) și a doua turbină după Kiln (Era 4 spre 75 de minute). A doua rundă l-a adoptat totuși, cu uneltele scumpe, bazele noi și a doua măsură pentru decor.
- **AWAY lăsa orașul să vândă fără om.** Jocul (`idleOnly`) nu o face; acum nici simulatorul.
- **Quest-ul Kiln-ului nu se aprindea niciodată.** Acum capitolul cere nivelul 2 pe plasa de cablu dinaintea Kiln-ului (a patra în prima rundă, a treia după a doua), apoi Kiln-ul.
- **O egalitate între piese dă uneori o treaptă cu zero** (riscul 3). E cinstit [D46], iar ecranul numește linia cealaltă. Poarta prinde doar egalitatea permanentă.

**A doua rundă a verificatorului (2026-10-01) și ce s-a schimbat după ea:**
- **Bazele din prima rundă se mai egalau pe trepte și oameni** (de pildă Barrel Hauler 7,5 × 2 = Cable Porter 5,0 × 3). Bazele noi n-au nicio egalitate între cei șapte oameni ai unirii, la orice treaptă (1–5) și oricâți oameni (1–2): Dam Collector 4,7, Dam Porter 6,3, Barrel Hauler 7,3, Cable Porter 5,4, Cable Hauler 6,7; Pylon Runner-ul rămâne la 6,5 (la 6,1, `check_hire_order` pica la −15%). Cu clădirile Erei 4 rămân câteva egalități la niveluri anume, trecătoare. `walker_ties` le fixează pe cele între oameni.
- **Cu Kiln-ul după a patra plasă de cablu, „târârea” nu cobora sub 22 de minute,** oricum am fi pus scara sau uneltele (Erele 1–3: cel mult 20m58s). Kiln-ul vine acum după a treia plasă, iar scara Erei 4 pornește de la 6,5. A patra plasă și a doua turbină rămân pentru Dam Bell; lacomul le ia după cristal.
- **Verigile pieselor ieșeau decor** cu Kiln-ul devreme: cristalul ține venitul o bună parte din eră, deci cota pieselor ca verigă care ține tot venitul scădea sub prag. Pentru Era 4, o verigă e decor doar dacă e sub prag și pe a doua măsură, `gain_time`: cât timp o treaptă sau un nivel doar pe ea ar fi adus câștig (după a treia rundă, fără secundele de egalitate: `Chain.solo`). Erele 1–3 nu folosesc măsura nouă, deci ies la fel.
- **Al doilea om era mai ieftin decât treapta 5 a meseriei lui** (uneltele s-au scumpit, oamenii nu). Meniul ar fi lăudat treapta. Acum podeaua e 1,25 × treapta 5 (în Erele 1–3 primul al doilea om al erei costă de 1,6–2,5 ori cât treapta 5, ceilalți mult mai mult). La 1,5, „târârea” ieșea 22m12s.
- **Factorul uneltelor n-avea nume în joc:** `StationConfig.TOOL_COST_MULT` (gol pentru Erele 1–3, deci aceleași prețuri), comparat de `check_config_constants`.
- **Plasele de cablu nu sunt quest-uri în simulator.** Modelate ca quest-uri, cu prețurile derivate din nou, Era 4 cădea la 11 minute: suma de start cumpăra tot. Capitolele (pasul k) le cer totuși, în ordinea `DAM_CHAPTER`; a treia și a patra rundă au pus capitolul printre porți (mai jos).

**A treia rundă a verificatorului (2026-10-01):**
- **Cristalul stătea la egalitate ~31 de minute reale** (57% din eră): Crystal Collector pe treapta 5 și Crystal Porter pe treapta 4 duceau amândoi 10/s (2,0 × 5 = 2,5 × 4, oglinda compromisului D56). Jocul ar fi arătat Crystal Collector drept veriga care ține venitul, iar fiecare cumpărătură pe ea dădea zero. Lacomul nu le atingea deloc (al doilea Crystal Collector și Porter rămâneau necumpărați), iar în Erele 1–3 aceeași egalitate ține ~4 minute. Crystal Porter are acum baza 2,7, iar `walker_ties` verifică și linia cristalului. Lacomul ia acum ambii oameni secunzi ai cristalului. Cristalul aduce 51,5% din bani la Dam Bell (34,7% înainte), venitul final e 5,38T/s (3,99T/s), iar Dam Bell costă 700T (500T).
- **Capitolul putea cumpăra a treia plasă din primul minut.** Plasa costă 5,5T din cei 35T ai sumei. Cine o ia atunci are Kiln-ul de 100T la 86B/s: cu regula quest-urilor din simulator (strângi și nu mai cumperi altceva), Era 4 ar fi ținut 1h42m, cu un platou de 1h07m. Prima reparație a fost un prag de venit pe platforma Kiln-ului (1T/s), cu a treia rulare din `DamRun` pentru capitol; runda a patra a schimbat-o (mai jos).
- **Podeaua celui de-al doilea om nu era o poartă,** deși planul o trecea printre ele. Iar prin scara strict crescătoare, ea urcă și deblocările de după cei șapte oameni: Kiln-ul 80T → 100T, Crystal Net 100T → 120T, a doua turbină 75T → 90T, a patra plasă 90T → 110T (Era 4: 50m49s → 54m48s). Poarta din `check_dam` cere acum ce contează pentru meniu: omul e mai scump decât treapta 5. Fără podea ar pica (al doilea Dam Collector la 35T, al doilea Cable Collector la 30T, treapta 5 la 36,45T).
- **`gain_time` număra și egalitățile drept câștig** (`credit` dă câștig fiecărei verigi egale). Acum numără doar `Chain.solo`: verigile care aduc ceva singure, ca în meniul jocului.

**A patra rundă a verificatorului (2026-10-01):**
- **Pragul de pe platformă îl prindea pe cine urmează quest-ul.** „Build the Kiln” se aprindea din minutul 0, cu Kiln-ul încuiat până la 1T/s. Cine strânge pentru quest, cum l-au învățat Erele 1–3, ajungea la 100T după ~25 de minute, cu venitul pe loc, și găsea Kiln-ul tot încuiat. Iar pragul pe platformă cerea în joc ca toți cititorii condițiilor (`meetsNeeds`, `padStatuses`, `padBlocker`, `PadService.Statuses` / `Buy` / `Deltas`, `PadController.ruinNeeds`) să primească venitul. **Acum pragul e un pas de capitol, nu o condiție pe platformă:** „Make 1T coins a second” înaintea Kiln-ului (quest-ul Kiln-ului din simulator îl cere), cu ghidajul pe veriga slabă cât ține. Kiln-ul rămâne o platformă obișnuită. A treia plasă îl duce pe lacom peste prag (966B/s → 1,01T/s), deci cronologia lui nu se schimbă.
- **Rularea capitolului scăpa de porțile duratei și ale pauzei, și le-ar fi picat.** Cine lua a doua turbină și a patra plasă cum avea banii ajungea la clopot cu 3,2T/s și strângea 700T aproape 4 minute fără nimic de apăsat (216 s, peste cele 180). Capitolul cere acum și un pas de venit înaintea lor (`DAM_LATE_INCOME`; 4,5T în runda a patra, 4T după a cincea), iar rularea capitolului trece prin porțile duratei și pauzei.
- **Ce venit compară pasul:** cel din HUD, cu pass-urile (2x Flow îl grăbește, ca la quest-ul AWAY). *Înlocuit la varianta 1: pragurile se înmulțesc cu 2x Flow, rândul f.* Owner-ul, ca și creator, are toate pass-urile în Studio: ritmul Erei 4 se judecă după ce le stinge din rândul `robux` al consolei de dev.

**A cincea rundă a verificatorului (2026-10-01):**
- **Pragul de 4,5T stătea la 92% din plafon** (4,89T/s: toți oamenii la 2 × treapta 5, plasele și clădirile la nivelul 400). Cu Crystal Collector la −15%, plafonul coboară la 4,51T: pasul abia se mai mișca, iar rularea capitolului l-a sărit fără ca vreo poartă să vadă (lacomul a cumpărat turbina sub prag). Acum pragul e 4T (82%), deblocările de după un pas de venit nu se văd în rularea capitolului până la prag, iar `check_dam` cere ca plafonul (`dam_ceiling`) să fie cu 10% peste fiecare prag, și la `--robust`.
- **A încercat și ordinea cealaltă** (turbina și a patra plasă imediat după cristal, pasul de venit înaintea clopotului). Iese mai rău: capitolul cumpără turbina înaintea Kiln-ului (o vede din a treia plasă), iar amândouă tot nu aduc nimic. Turbina și a patra plasă sunt doar condiții ale clopotului: la lacom aduc +0,10% și 0%. Cartonașul lor spune asta (rândul k).
- **Ghidajul, contorul, puntea și testele** pentru pasul k sunt acum scrise în plan (corectate în runda a șasea): veriga arătată cât ține un pas de venit e una pe care se mai poate cumpăra ceva (spre plafon, veriga globală e un Crystal Collector plin); contorul „966B/1T” printr-o singură funcție, care încape în cutii; pragurile ca scalari în `StationConfig`, citiți de `QuestConfig` și comparați de simulator; testele din §8.

**A șasea rundă a verificatorului (2026-10-01):**
- **Reparate:** plafonul pasului Kiln-ului se socotește acum pe starea de dinaintea Kiln-ului (2,37T/s, fără cristal), nu pe cea de la clopot; pauza capitolului se scrie cu unitatea ei (lacomă, ca poarta); contorul din listă fără paranteze, verbul „Earn” (ca „Earn 1 coin a second while away”), linia NEXT fără preț pe un quest de venit, cartonașul „Needed for the Dam Bell” în locul ramurii „câștig zero” (scos odată cu platformele, la varianta 1).
- **HOTĂRÂT de owner pe 2026-10-01: varianta 1** (mai jos, „După hotărâre”). Constatarea: **a doua turbină și a patra plasă.** Pe hartă se pot cumpăra imediat după a treia plasă de cablu (ca orice platformă cu condiția împlinită), iar rularea capitolului le ascunde până la pasul de 4T/s. Cine le cumpără când apar, cum le arată harta, deschide Dam Bell pe la minutul 27, cu ~2,4T/s. Strânge apoi 700T: ~4m47s lacome, peste poarta de 3 minute. Sună clopotul pe la minutul 38, sub cele 40 de minute ale unei ere. Rădăcina e în economie: venitul Erei 4 se apropie de plafon (~4,9T/s) pe la minutul 40, iar clopotul e ținut în urmă doar de două platforme care nu aduc nimic (+0,10% / 0%). Variantele, ca pași de joc:
  1. **Clopotul se deschide la un venit** („Dam Bell opens at 4T coins a second”, pe cartonaș), iar turbina a doua și a patra plasă dispar din eră, pentru că nu aduc nimic. Era 4 ar ține ~40 de minute.
  2. **Turbina și plasa rămân, dar se deschid abia la pasul de venit** (cartonașul scrie pragul). Plătești 200T pe două lucruri care nu urcă venitul, apoi strângi pentru clopot aproape 3 minute.
  3. **Era 4 primește loc de creștere la final** (de pildă o a treia treaptă a cristalului), ca venitul să nu stea lângă plafon. E mai multă muncă de economie, iar era rămâne pe la ~55 de minute.

**După hotărâre (varianta 1, 2026-10-01):** a doua turbină și a patra plasă de cablu au ieșit din eră (`DAM_NETS = dam 1, cable_ore 3, crystal 1`), iar Dam Bell cere și un venit de 4T/s (`DAM_BELL_INCOME`, condiție pe platformă, citită în joc de toți cititorii ei: rândul f). Ascunderea din rularea capitolului nu mai trebuie: harta și capitolul arată același lucru. Capitolul cere și el pragul înaintea clopotului („Earn 4T coins a second”), iar în joc pragurile se înmulțesc cu 2x Flow (rândul f; verificatorul variantei 1). Fără cele două platforme, clopotul a ieșit mai ieftin (450T) și Era 4 ținea 38m49s, sub cele 40 de minute ale unei ere. Pragul nu ajuta (venitul sare de la 3,63T la 4,44T dintr-o singură cumpărătură, la minutul 37), deci scara Erei 4 pornește acum de la 8,5 (la 10 apare o prăpastie de 1h12m). Cu ea, „târârea” scade de la 17m38s la 8m20s, iar podeaua celui de-al doilea om aproape nu mai leagă (45m12s fără, 45m16s cu).

**Ce a ieșit altfel decât în plan:**
- **`check_hire_order` rămâne pe linii, nu pe bazin.** Pe linie, ultimul drum al fiecărei linii trebuie să ducă tot timpul tău (5,4). Pe bazin i s-ar cere doar partea lui din pașii rămași. Regula pe linii e deci mai strictă și o acoperă pe cea pe bazin.
- **`check_config_constants` compară `ROLE_BASE` doar pe erele din configurație** (`CONFIG_ERAS = (1, 2, 3)`), la fel `TOOL_COST_MULT`. Era 4 intră în `StationConfig` la pasul f, iar atunci `CONFIG_ERAS` primește 4.
- **„~2–3 minute fără câștig cât lipsești” vine din rularea fără bani.** Cu suma de start, cei șase costă 4,5% din ea și se pot angaja din prima clipă. AWAY = 0 ține doar cât faci drumul la aviziere. Textul din joc (pasul k) spune ce faci („angajează cei 6”), nu minute.
- **Marja de la `--robust`** (1,35) a fost aleasă după ce se văzuse cel mai rău caz al primei variante (14m04s). E o marjă de zgomot, nu o dovadă.
- **Timpul simulatorului s-a dublat** (10,5 → ~26 s pentru rularea simplă, peste 10 minute pentru `--robust`): Era 4 se joacă de trei ori (fără bani, cu suma, capitolul), iar lanțul are patru linii în plus.

## 12. Cum a ieșit pasul e (2026-10-02)

`python3 scripts/economy/golden_chain.py --era4` scrie blocul `local GOLDEN_ERA4`. Stările pornesc din Era 3 încheiată
(plasele și oamenii Erelor 1–3 la final) și trec prin `dam_transform`, ca barajul jocului: liniile vechi se închid,
veteranii intră pe butoaie, turbina din zid și Cable Net 1 vin gratis. Apoi fiecare stare își pune nivelurile pe cele
două plase date și își adaugă restul plaselor barajului: fel, rang, bandă, nivel (`unlock_net_ranked`).

Pentru fiecare stare se tipăresc liniile barajului (`barrels`, `cable`, `grid`, `crystal`) și lemnul, ca linie veche
închisă:
- prinderea, ce intră (`supply`), debitele pașilor, livratul;
- veriga liniei, a cui e veriga (`heldBy`), dacă piesa e ținută de unire (`byConsumer`);
- capacitatea orașului, veriga care ține venitul, ale cui plase (`netsLine`);
- câștigul unei bucăți în plus pe verigile cu câștig (`gains`) și verigile care îl aduc și singure (`solo`);
- venitul.

**Nouă stări**, nu șase:
- startul barajului (cifrele din §8: drumurile 0,9, Cable Works 0,333, Relay 0,467, livrat 0,33);
- după cei șase și a doua plasă de cablu (prima la nivelul 2, cum cere jocul);
- butoaiele țin unirea;
- cablul ține unirea, iar butoaiele așteaptă;
- **egalitatea butoaie–cablu**, între clădiri: Switchyard-ul cu un Switchman pe treapta 5 duce 12/s, cât Cable Works-ul
  cu doi Cablemaker pe treapta 3. Amândouă au câștig, `solo` e gol: fiecare singură dă 0 [D46], iar ecranul trebuie să
  numească linia cealaltă (pasul h);
- Kiln fără Crystal Net;
- turul de mână al cristalului;
- orașul plin: cristalul întâi, curentul din ce rămâne;
- toți oamenii la maxim, cu pragul 25.

**Egalitatea vine din clădiri, nu din oamenii de drum:** bazele oamenilor de drum ai Erei 4 sunt alese fără egalități
(`walker_ties` din `check_lines.py` se uită doar la ei), dar o clădire cu oamenii ei poate duce cât alta (bază × treaptă
× oameni). Starea de mai sus o fixează pentru portul din pasul g [verificator, 2026-10-02].

Venitul nu are clopotele (`bells = 1`), ca starea să se refacă în Luau fără ele. La baraj, cu clopotele celor trei ere,
iese 19,57B/s. Blocurile Erelor 1–3, formatate cu stylua, sunt identice cu cele din `tests/ChainMath.test.luau`. Blocul
nou intră în test la pasul g, odată cu `ChainMath`.

**Următorul pas: f** (configurația: `StationConfig`, `TycoonConfig`, `Strings`, cu Era 4 `live = false`).

## 13. Cum au ieșit pașii f și g (2026-10-02)

**Împărțirea:** pasul f s-a tăiat în două. Partea de acum e ce-i trebuie motorului. Platformele Erei 4 (prețuri,
`netRank`, `Needs.income`, textele lor) vin cu harta barajului (pașii j–k): fără loc pe hartă n-au unde sta, iar
cititorii platformelor (cartonașul, ruinele, `padStatuses`) se schimbă tot atunci.

**Era 4 stă în tabele, dar jocul n-o rulează încă.** `StationConfig.ENGINE_ERAS = 3`. Listele pe care le citesc serverul,
meniurile și ghidajul (`ERA_ROLES`, `ROLES`, `ERA_LINES`, `LINE_ORDER`, `SELLER_ORDER` și tot ce se derivă din ele) sunt
tot ale Erelor 1–3, la fel ca înainte. Variantele `_ALL` (`ERA_ROLES_ALL`, `ROLES_ALL`, `ERA_LINES_ALL`, `LINE_ORDER_ALL`,
`SELLER_ORDER_ALL`) au și barajul. [Înainte: „Pasul j pune `ENGINE_ERAS = 4`.”] **[2026-10-03] Comutatorul e pasul l3** (§16, R12): `ENGINE_ERAS = 4` și `live = true` pe cele 23 de platforme, abia după proba cap-coadă; pașii j1–k12 lasă jocul viu neschimbat.

**Pasul f, partea de acum:**
- `StationConfig`:
  - liniile barajului (`barrels`, `cable`, `grid`, `crystal`) cu cheile noi, iar `closeFlag = "dam"` pe cele șase vechi;
  - cele patru clădiri și orașul;
  - `ROLE_BASE` și `LEVEL_INC` ale Erei 4, `ERA4_MULT`, `TOOL_COST_MULT[4] = 2`;
  - pragurile `KILN_INCOME` și `DAM_BELL_INCOME`, scrise întregi.
- `TycoonConfig`: bunurile (`charge`, `barrel`, `cable_ore`, `cable` la 0; `grid`, `crystal`, `ingot` scrise ca produs, ca
  în simulator), `CATCH` (fără găsiri), `PROCESSED`, `JOINED`.
- `HandConfig`: pozele celor patru oameni de atelier ai barajului.
- Simulatorul: `CONFIG_ERAS = (1, 2, 3, 4)`. `check_config_constants` compară și constantele Erei 4, iar regex-ul citește
  exponentul.

**Pasul g:** `ChainMath` e portul lui `chain` / `bottlenecks` din simulator:
- `model` cu invariantele lui `derive_tables`, plus `consumerOf` și `poolLines`;
- `lineOpen` cu `closeFlag` și uniri;
- pașii de mână pe bazin, trei treceri;
- `credit` / `creditSolo` / `ownFirst`, `heldBy`, `netsLine`, `gains`, `solo`;
- venitul fără piese, cu `value`;
- câmpurile Erei 4 în `empty()`.

`ChainMath.GAME` e lanțul erelor din joc, `ChainMath.FULL` pe cel cu barajul.

**Verificat:**
- Toate tabelele de aur ale Erelor 1–3 trec neschimbate.
- `GOLDEN_ERA4` (nouă stări, plus `GOLDEN_ERA4_FROM`, Era 3 încheiată) trece la bit pe `FULL`: debite, `supply`, livrat,
  veriga și a cui e, piesele ținute de unire, capacitatea orașului, `netsLine`, câștigurile, `solo` și venitul. La
  startul barajului, venitul fără tine e 0 (§8).
- Suita „unirea ca date” e oglinda probei de unire din `check_lines.py`, cu aceleași cifre socotite de mână:
  - înainte de baraj;
  - startul (bazinul de 6);
  - bazinul fără niciun om;
  - o piesă închisă;
  - egalitatea pe plase și pe oameni (`solo`), plus `idleOnly`;
  - modelul care pică pe o unire care nu se leagă.
- `tierCost(1, "damCollector") == 25 × ERA4_MULT × 2`.
- **Comparația veche–nouă pe 80.000 de stări nu s-a rulat.** Paritatea Erelor 1–3 o țin tabelele de aur, iar regulile
  unirii, cele nouă stări ale barajului și proba de unire.
- `luau-analyze` nu rezolvă `require(script and … or "…")`: modulele comune ajung `any`, deci tipurile cititorilor nu
  sunt verificate de el.

**Cititorii unui `seller` / `netKind` care acum poate fi nil:**
- `StationPanel.chainRowsFor` și `Overlay.lineOpenedText` sunt apărați de acum;
- `HeldBack` (:133/:135) intră la pasul h;
- `HandRoutes.netKindOf` întoarce deja `string?`.

Înainte de pasul j se mai caută o dată `.seller` / `.netKind` în tot `src/`.

**Următorul pas: h** (`HeldBack` pe grupul unirii; textele „the Cable line is slower” / „just as slow as the Barrel
line”, „cast the Cable Net first”). Apoi i (`FlowConfig`, `FlowMath.assemble`, `HandRoutes`), j (serverul, `DamService`,
profilul v19, platformele Erei 4 cu harta; [2026-10-03: `ENGINE_ERAS = 4` e pasul l3, §16]), k (clientul), l (sonda).

## 14. Cum a ieșit pasul h (2026-10-02)

**`HeldBack` știe unirea.** Ce vede jucătorul când o cumpărătură pe baraj nu aduce nimic (meniul obiectului, panoul
Upgrades, cartonașul platformei):
- **piesa ținută de cealaltă:** „No gain yet — the Barrel line is slower”, cu Go to spre veriga ei;
- **la egalitate între piese:** „the Cable line is just as slow” (amândouă au câștig, niciuna singură);
- **plasele celeilalte piese:** „the cable nets are slower”;
- **plasa celeilalte piese lipsește:** „cast a Cable Net first” [D43]. La fel pe rândurile unirii (Relay Station, Pylon
  Runner).
- **veriga e a unirii sau a orașului:** se numește clădirea („the Relay Station is slower”, „the Switch House is slower”),
  nu „the Power line”. Linia se numește doar când veriga e a celeilalte piese.
- **rândul Switch House-ului:** plasele care chiar țin („the cable nets are slower”, apoi „the crystal net”), nu
  cuvintele lemnului.

**Cum:**
- `HeldBack.by` întoarce și a treia valoare, linia care deține veriga (`heldBy` din lanț), când e cealaltă piesă a
  aceleiași uniri. De la un vânzător se uită la prima lui linie deschisă, ca `lineBottleneck`.
- `HeldBack.netsLine` caută, de la un vânzător, în ordinea lui (cum alege și `lineBottleneck`), iar o unire trimite la
  piesa ale cărei plase țin. În Erele 1–3 se schimbă un singur caz: la Taverna cu ambele linii ținute de plase, plasele
  numite sunt ale fierului, a cărui verigă o arată deja rândul (înainte, ale lemnului).
- La egalitate, compară cu tot grupul unirii (`HeldBack.group`: unirea și piesele ei). Plasele se compară doar la liniile
  cu plase, iar vânzătorul doar la liniile care vând.
- `LineView.heldBy` e opțional. Serverul îl trimite de la pasul j, iar clientul îl copiază explicit (pasul k).
- `viewOf` primește modelul (`FULL` în teste).
- Cei trei cititori (`StationMenu`, `StationPanel`, `PadController`) trec linia mai departe, iar `Strings.menuHeldBack`
  primește `holder`.

**Cuvintele barajului** (`LINE_WORDS` cu `name`, `LINK_WORDS`, `NET_WORDS`, `BUILDING_WORDS`) sunt propuneri:
Switchyard, Cable Works, Relay Station, Kiln, Switch House, Battery Store, Cable Store. Turbina din zid umple
**baterii**, pe care Switchyard-ul le încarcă în butoaie („Load”). Un test cere ca orice „No gain yet” al oricărei
verigi a oricărei ere să încapă pe rândul panoului Upgrades. Două texte ale Erei 3 se tăiau: au devenit „battery
pickup” și „hauling cells”. Numele le hotărăște owner-ul
(§6, întrebarea 12). Un test cere cuvinte pentru fiecare verigă a tuturor erelor și sfatul panoului pe rândul lui.

**Verificat** pe stările barajului din `GOLDEN_ERA4`: egalitatea dintre clădiri, butoaiele care țin unirea, startul și
plasa de cablu scoasă.

**Rămâne pentru k:** `StationMenu.CHAIN` (azi verigile erelor din joc: o cheie a barajului ar cădea pe prima) și
comutatorul de cartier al panoului.

**Următorul pas: i** (`FlowConfig`, `FlowMath.assemble`, `HandRoutes` cu `job`).

## 15. Cum a ieșit pasul i (2026-10-02)

**Cum s-a ales forma:** un workflow cu trei cititori (cine citește modulele, ce îi trebuie serverului la pasul j,
simulatorul și harta), două variante independente (minimală și „datele întâi”) și un judecător. S-a luat varianta
minimală, cu bucăți din cealaltă.

**Ce e nou:**
- **`FlowConfig`:**
  - Rândurile tuturor erelor stau în `LINES_ALL` / `SELLERS_ALL`, iar `model(lineOrder, sellerOrder)` face
    `GAME` (erele din joc) și `FULL` (cu barajul).
  - `LINES`, `SELLERS`, `BY_*` și `PILES` sunt cele ale lui `GAME`, ca până acum.
  - Barajul are rândurile lui:
    - **barrels:** `damStore`, `switchyard`, `barrel`;
    - **cable:** `cableStore`, `cableworks`, `cable`;
    - **grid**, unirea: fără magazie; `inputPiles` pe linia piesei, `RelayBarrelPile` / `RelayCablePile`; `relay`;
      `grid`; refuzul `part_to_relay`;
    - **crystal:** `crystalShed`, `kiln`, `ingot`;
    - orașul (`TownPile`), fără găsiri.
- **Verificări la încărcare**, pe toate erele:
  - unirea n-are magazie, marfă brută sau găsiri;
  - produsul ei e `value`, iar piesele, în ordinea rețetei, sunt `TycoonConfig.JOINED`;
  - locurile și grămezile nu se repetă.
- **`takeOrder` e derivat:** ordinea în care vinde orașul (`ingot` înaintea lui `grid`, ca `priority`). Cheile
  alfabetice ar fi vândut întâi curentul, mai ieftin: -28% în starea „orașul plin”. La vânzătorii Erelor 1–3 ordinea
  cheilor e chiar `priority`, deci nu primesc nimic.
- **`FlowMath` primește modelul la coadă** (implicit `GAME`) și funcții noi:
  - `partOf` (piesa → unirea ei);
  - `split` primește piesele gata la Relay, iar un rând al barajului cu modelul jocului pică;
  - `dropJoin` (o grămadă lipsă pică, nu pierde bucăți);
  - `useJoin`;
  - `joinWaiting` („Waiting for cable”);
  - `assemble`: `min(întregi, butoaie, cablu)`; restul sub 1 nu se strânge și se pierde cu o intrare goală;
  - `deliver` refuză piesele cu `part_to_relay`;
  - `drainOrder`.
- **`PileMath.take`** primește ordinea opțional.
- **`StationConfig.stepJobs` / `STEP_JOBS` / `STEP_OF_JOB`:** meseria fiecărui pas (`job` scris pe pașii unirii,
  altfel după poziție), verificată la încărcare. O unire viitoare fără `job` ar fi primit „collect” pe atelier.
- **`HandRoutes` primește un context** (liniile, meseriile, locurile, drumurile):
  - cărăușii pieselor duc la intrarea lor în Relay;
  - Pylon Runner-ul duce de la Relay la oraș;
  - fără loc pe hartă, niciun drum, fără eroare.
  
  `TycoonConfig.JOIN_PLACES` e gol până la harta barajului.

**Verificat:**
- 744 de teste. Între ele:
  - convergența unirii pe multe tick-uri;
  - „orașul plin” pe grămezi (cristalul întâi, ca `GOLDEN_ERA4` × 1000);
  - drumurile pe locuri inventate;
  - gardurile.
- **A/B:** modulele din HEAD față de cele noi, pe tot ce citește jocul (Erele 1–3, toate meseriile, 54 de plase): 131.754
  de comparații, 0 diferențe.

**Pentru pasul j** (lista judecătorului, plus verificatorul). **[2026-10-03: lista completă, cu ordine, dependențe și verificări, e în §16 (j1–j15, k1–k12, l1–l3); ce urmează rămâne ca sursă a conținutului.]** `ENGINE_ERAS = 4` intră abia când e făcut tot ce urmează (acum: pasul l3),
altfel primul push strică jocul tuturor:
- **pornirea:** `ENGINE_ERAS = 4` [2026-10-03: pasul l3, nu j]; testele de adormire se rescriu (`#PILES` 34, ChainMath.test).
- **profilul v19:** cele 13 grămezi și numărătorile noi, în șablon și în migrare.
- **`EconomyService`:**
  - tick-ul face `assemble` pe uniri și sare liniile închise;
  - `processorSpeed` folosește `joinWaiting`, `UseProcessor` → `useJoin`;
  - `DropAt("relay")` → `dropJoin`, iar `HandService.drop` șterge `hand.carry` abia după ce `DropAt` întoarce și păstrează
    restul;
  - `DropAt` la un vânzător filtrează piesele;
  - scurgerea folosește `drainOrder`;
  - câmpul `waiting` („Waiting for cable”);
  - `stamp`-ul unirii; `DevFillPile` pentru unire.
- **`SackSnapshot`:** piesele gata se numără separat (de pildă `partBy[unire]`, prin `FlowMath.partOf`), nu în `rawBy`.
  Altfel butoaiele gata trimit la Switchyard („take the batteries to the Switchyard”), iar cardul magaziei oferă „Drop”.
- **Instantaneele** (`StoreSnapshotOf`, `ProcessorSnapshotOf`, `NetServer.flowSnapshot`) știu de unire: fără magazie,
  intrările din `joins`. Altfel `pileOf(data, nil)` crapă la fiecare stare trimisă.
- **`StationService`:** garda pe `seller` nil în `BUILDING_ROWS` [2026-10-03, corectat: bucla din `StationService.luau:118-141` nu „crapă” pe un `seller` nil, ci doar `BUILDING_PAD[nil] = …` dacă o piesă primește `processorPad`; garda se pune acolo și pe `LINK_WORDS[seller]`]; steagul `dam` din profil (în cod iese azi mereu fals, §16 R5); platformele Kiln și Crystal
  Shed. Un test cere ca fiecare `pad` din FULL să existe, iar nicio platformă să nu poarte numele unui loc din FlowConfig.
- **Platformele angajărilor barajului** poartă lanțul `needs.after` din `ERA4_UNLOCKS` (cableCollector → cablePorter →
  cablemaker → cableHauler → relayKeeper → pylonRunner; cristalul după Crystal Shed). Paza negativă arată că ordinea ține
  monotonia. Testul de lanț din TycoonConfig.test se extinde, iar simulatorul citește `needs.after` și pică dacă
  ordinea diferă. **[2026-10-03] Încă nu e scris:** simulatorul nu citește `needs.after`; vine în j2 (`ERA4_AFTER`, §16).
- **Clientul, înainte de pornire:**
  - `Bootstrap` (bucla `sellerOpenPad` sare `seller` nil);
  - `Overlay.luau` :273 și :810, cu locul unirii din `JOIN_PLACES`;
  - `GuideMath`, care indexează `LINE_PLACES` pe linie, ia rolul din `STEP_OF_JOB`.
  
  Un test Lune rulează aceste bucle pe ordinea FULL.
- **Harta:** `LINE_PLACES` pentru barrels, cable, crystal; `JOIN_PLACES.grid`; `SELLER_PLACES.town`. Cu ele,
  `lampHitsWorker` și testele de așezare trec și pe `JOIN_PLACES`, iar `HandRoutes` primește graful de drumuri al lumii
  2 (cheia cache-ului pe graf).
- **`DamService`:** marfa și găsirile erelor vechi din traistă, grămezile vânzătorilor vechi, `hand.carry` al veteranilor.

**Pentru k:**
- `Strings` pentru codurile noi de refuz;
- `placeResult` cu `part_to_relay` („Barrels and cable go to the Relay Station”);
- `hint` / `hintedBy` pe liniile barajului;
- indiciul la livrarea parțială [D43];
- `LineController` pentru unire (două grămezi la Relay);
- copierea explicită a lui `waiting`;
- `GuideMath` și `LineController` trec de la `steps[n]` la `STEP_OF_JOB`.

**Deja făcute în i:**
- bucla `DROP_AT` din `Overlay` sare liniile fără loc, iar la o unire ia intrarea primei piese;
- iconițele din panou și din meniul obiectului vin din `STEP_JOBS`, nu din poziție;
- `SELLER_WORDS.town`.

**Simulatorul, tot azi (6aeb879 și pasul i):**
- **monotonia:** pe fiecare stare nouă (după fiecare cumpărătură), înaintea scurtăturilor capitolului și ale
  quest-urilor, nicio opțiune de pe ecran nu scade venitul;
- **paza negativă:** Cable Collector-ul angajat ultimul (§8).

## 16. Pasul j împărțit: j1–j15, k1–k12, l1–l3 (2026-10-03)

**Regula.** Fiecare commit lasă jocul viu neschimbat. Singurul care îl schimbă e **l3**: `ENGINE_ERAS = 4` și `live = true` pe
cele 23 de platforme ale Erei 4. Până atunci Era 4 stă în tabele, adormită, iar clientul și serverul se probează pe un
comutator local care nu se comite (R10). La fiecare pas: poarta întreagă din CLAUDE.md, apoi `verify-work` (Opus 5.5), apoi
commit și push.

Ordinea mare: **D0** (documentele) → **O1** (pachetul pentru owner, nu blochează) → **j1–j15** (fundația pură și serverul) →
**k1–k12** (clientul) → **A0–A4** (arta, în paralel, după O1) → **l1–l3** (proba și comutatorul).

### Conflicte între cititori, rezolvate citind codul (R1–R12)

- **R1. D74 e deja comis (9d2c752).** Comitul are DECIZII D74, PLAN-HARTA §4 rescris și poarta de 40% din simulator
  (`PAID_COINS_MAX_SHARE`, `sim_tycoon.py:2636`, `:2684-2691`). Rămâne doar testul care inversează poarta (intră în j2).
- **R2. Platformele Erei 4 se adaugă în `TycoonConfig.PADS` cu `live=false` (indecșii 55–77).** Lista separată `DAM_PADS` cade.
  Toate buclele suportă rânduri `live=false`:
  - `TycoonMath.padStatuses` (`:459-510`): cu tot cumpărat, prima platformă necumpărată e una a Erei 4; devine `blocker`, dar
    `blocker.live` e fals, deci n-are contur, iar ieșirea e identică cu cea de azi;
  - `TycoonMath.era` sare platformele fără `live`; `PadController:1090-1110` ascunde platformele fără `live` sau fără x/y;
    `VillageDiorama:605` și `village_geometry.luau:47-50` le sar;
  - `StationService:63-73` le pune în `NET_PAD_IDS` pe pozițiile 16–20, dar sunt citite doar dacă sunt cumpărate;
  - `NetServer` `ZONE_BELL[5]` nu e folosit; `ModernController.plansBell` se potrivește doar pe Era 3; `EraWords.bellOf(4)` se
    atinge abia după `eraIsLive(4)`.
  Se schimbă doar testele `TycoonConfig.test.luau:101` (54 → 77) și `:124` (`perEra[4]`).
- **R3. Lumea unui lucru se derivă din eră (`WorldConfig.worldOfEra`), fără câmp `Pad.world`.**
  - Statusurile se calculează pe `padsOfWorld(data.World)`. `needs.all` de pe Works Bell garantează Erele 1–3 cumpărate la
    baraj.
  - Condițiile Erei 4 se numără pe lista lumii 2, cu turbina și Cable Net 1 gratuite incluse: `second_cable_net` cere
    `netsExactly 2`, `third_cable_net` cere 3, `crystal_kiln` cere `netsOwned 4`.
  - `prevNetLevel` rămâne pozițional (`TycoonMath.luau:278`) dacă ordinea din PADS e: turbina, cable 1, cable 2, cable 3,
    crystal. Nu e nevoie de o cheie nouă de condiție pe familii de plase.
- **R4. Geometria lumii 2 intră în `TycoonConfig.WORLDS[2]`, niciodată în `DISTRICTS`, `ZONES` sau `DECOR`.** Altfel
  `RoadGraph.fromConfig` (`RoadGraph.luau:308-322`) ar uni drumurile ei cu ale lumii 1, iar amprenta pământului copt s-ar
  schimba. Tabelele pe chei primesc rânduri noi (`LINE_PLACES.barrels/cable/crystal`, `JOIN_PLACES.grid`,
  `SELLER_PLACES.town`). Înainte de asta se filtrează pe lume cei doi care le parcurg: `lampHitsWorker`
  (`TycoonConfig.luau:2041`) și `Overlay.luau:736` (comentariul de la `TycoonConfig.luau:732-734` avertizează deja).
- **R5. Steagul `dam` iese azi mereu fals.** Bucla din `StationService.luau:186-191` scrie `fields.dam` din `processorPad`-ul
  liniilor barrels/cable/grid, care e nil. Corect: `dam = data.World >= 2`, iar bucla sare steagul „dam”. Pentru cristal,
  `FlowConfig.crystal` primește `processorPad = "crystal_kiln"` și `storePad = "crystal_shed"` (`FlowConfig.luau:243-244` spune
  că vin cu harta).
- **R6. Comutatorul ar prăbuși jocul pentru toți (confirmat).** `pileOf(data, nil)` (`EconomyService.luau:227-235`) se cheamă
  pe linia `grid`, care n-are grămadă de intrare, din `process` (`:607`) și din `NetServer.flowSnapshot` (`:143-156`). Venitul
  ar ajunge la 0, iar `TycoonState` n-ar mai ajunge la niciun client. De aceea j13 se probează pe un comutator local înainte
  de orice pas de client.
- **R7. Quest-urile s-ar întoarce în capitolul 1 după baraj (confirmat).** `QuestMath.currentChapter` (`:220-229`) se oprește
  la `idle_one` (`QuestConfig.luau:277-282`), al cărui AWAY cade la 0 după baraj, iar `QuestConfig.CHAPTERS` e global
  (`:962-969`). Se repară amândouă în j11.
- **R8. Monedele Robux se țin cu un contor tăiat la cheltuire** (decizia agentului; se scrie în DECIZII și i se spune
  owner-ului). Contorul crește la acordare și se taie la `min(contor, Coins)` la fiecare scădere (`EconomyService.luau:162,173`,
  `DevService.luau:57`). E exact „socotite ca ultimele cheltuite” din §5, fără vreun reper la Works Bell.
- **R9. Rangul plaselor.** `ChainMath.netBase` și `netUpgradeBase` merg după index (`ChainMath.luau:271-287`). Se adaugă variante
  pe (rang, eră): pentru Erele 1–3, rangul e `(i-1)%5+1` și era `(i-1)//5+1`, deci ies identice la bit; pentru Era 4,
  `Pad.netRank` și `netEra` reproduc `unlock_net_ranked` (`sim_tycoon.py:1003-1020`). `NET_LANES` și `NET_KINDS`
  (`StationConfig.luau:79-99`) nu se ating.
- **R10. Proba Erei 4 cere un comutator local.** `ENGINE_ERAS` e citit la încărcare (`StationConfig.luau:219`, `table.move`).
  `scripts/era4_flip.py on|off|status` schimbă `ENGINE_ERAS` și `live` pe cele 23 de rânduri și **nu se comite niciodată**;
  poarta pică deja pe un comutator comis (`ChainMath.test.luau:3214`).
- **R11. Primul quest al barajului.** „Ring your old bells” (PLAN-HARTA §2) cade în fața ordinii `DAM_CHAPTER` din simulator.
  Clopotele rămân plăci în clopotniță, fără quest. (Decizia agentului.)
- **R12. Comutatorul e un pas separat.** „Pasul j pune `ENGINE_ERAS = 4`” (§13) e înlocuit: comutatorul e l3, după proba
  cap-coadă.

### D0 și O1

**D0. Documentele, fără cod** (făcut pe 2026-10-03): pasajele învechite din PLAN-HARTA, PLAN-MOTOR-UNIRE, PLAN-ERA4, DECIZII
(D46 punctul 3, D64 regula 4, D66 `check_windfall`, D68, „Toți pornesc cu 40T”, „o noapte de monede”) și TYCOON (P2, §K); PLAN-HARTA
§9 devine „APROBATĂ (D74)”. Blocul de stare din CLAUDE.md îl scrie sesiunea principală. Verificare: poarta și `verify-work`
pe lentila de reguli.

**O1. Pachetul pentru owner.** Owner-ul a spus pe 2026-10-03 *„ia recomandatele și continuă”*, deci **opțiunile recomandate
sunt LUATE, provizoriu**, și le poate schimba dintr-un cuvânt. Nimic nu așteaptă după ele.
- **Filmul:**
  - lungime **15–20 s**, cu „Skip” de la secunda 3 (owner-ul spusese „câteva secunde”; propunerea inițială avea ~38 s);
  - stil **(a) siluete la apus**, cu numele deasupra, apoi bucuria în culorile lor: 2 imagini noi (nu (b) în culori, cu un rând
    nou de animație pe ~43 de foi, și nu (c) fără mâini);
  - butonul **„Not yet”** în loc de un film pornit singur la clopot, iar **taverna pleacă ultima**.
- **Ce intră la prima lansare a Erei 4.** Vin **după** lansare: macheta lumii 2 pentru vizitatori, titlul „Dam Builder”, poza
  „Before the Dam” și „Watch again” pe Memory Wall. Până atunci, bâlciul arată fotografia satului vechi, cu un semn „Building the
  Dam” (k11).
- **Decise de agent, doar informare:**
  - R8 (contorul monedelor Robux) și R11 (fără quest „Ring your old bells”);
  - veteranii poartă ținuta noii meserii, iar până vine arta arată ca în Era 1 (prin `OUTFIT_LOOKS_LIKE`);
  - „Last cart”: marfa rămasă se vinde la preț întreg înainte de calculul banilor, altfel s-ar pierde;
  - textul ceții Erei 5 rămâne neutru, fără nume de eră.
- **Încă cer owner-ul, explicit:** aprobarea planșelor de artă și, separat, acordul pentru **fiecare** urcare. Judecata filmului
  și a mersului, plus verificarea pe telefon, rămân la el (l2).
- **De verificat în Studio:** pe telefon se văd 460 px, iar de la acoperișul Switch House la ieșirea Relay sunt 476 px.

### j: fundația pură și serverul. Fără owner, fără artă.

**j1. Martorul de identitate pentru lumea 1, scris primul, din HEAD.** Depinde de: nimic.
- Fișiere: `tests/WorldIdentity.test.luau`, un fișier martor citit cu `@lune/fs` și un mod care îl scrie.
- Fixează: graful `RoadGraph.fromConfig`; `streetLamps()`, `wirePoles()`, `homeClearRects()`, `deckSpans()`, `ZONES`;
  `WorldDecor.village` cu argumentele din SceneArt; `padStatuses` și `TycoonMath.era` pe trei stări (proaspătă, la mijlocul
  Erei 2, la Works Bell cu tot cumpărat); `HandRoutes.cycleFor/standFor` pentru fiecare meserie din `ERA_ROLES`; id-urile din
  `QuestConfig.CHAPTERS`; `LINE_ORDER` și `ROLES`.
- Verificare: trece pe HEAD; o coordonată de drum mutată îl pică (apoi se revine).
- **Făcut (2026-10-03), cu verificatorul:** lumea 1 e descrisă după eră (1–3), nu după `live` / `ENGINE_ERAS`, cu lista de
  platforme dată explicit lui `padStatuses` / `era` / `padBlocker` (nivelul 1 pe ultima plasă deținută, ca poarta
  `prevNetLevel` să fie prinsă). Pe lângă lista de mai sus fixează platformele erelor 1–3 (loc, condiție, efect, preț),
  cartierele, curțile, decorul pus de mână, `LINE_PLACES` / `SELLER_PLACES` ale erelor 1–3, grămezile, locurile de lângă
  ponton, râul (`RiverConfig`, `blockedRects`, `RiverSim.schedule`), plutirea spre plase, darurile râului, quest-urile
  întregi (fără text) și ciclurile 1/1, 1/2, 2/2. Decorul îl desenează toți prin `VillageDecor.items()` (SceneArt, pământul
  copt, martorul). **Două fișiere:** `tests/witness/world1.txt` (nu se schimbă niciodată din cauza barajului) și
  `tests/witness/engine.txt` (listele motorului, capitolele din joc, statusurile pe toată lista; se rescrie la l3 și doar
  atunci). Proba comutatorului pe o copie: `world1.txt` identic, doar `engine.txt` se schimbă.

**j2. Rândurile Erei 4 în configurație, adormite, cu oglinda din simulator.** Depinde de: nimic. Dacă iese prea mare, se taie
la granița CREWS / `DAM_START_COINS`.
- **Platformele:** 23 de rânduri în `TycoonConfig.PADS`, `live=false`, deocamdată fără x/y.
  - 16 cu preț: `hire_cable_collector`, `hire_cable_porter`, `hire_cablemaker`, `hire_cable_hauler`, `hire_relay_keeper`,
    `hire_pylon_runner`, `second_cable_net`, `third_cable_net`, `crystal_kiln`, `crystal_net`, `crystal_shed`,
    `hire_crystal_collector`, `hire_crystal_porter`, `hire_crystalsmith`, `hire_ingot_hauler`, `dam_bell`.
  - 7 gratuite (preț 0): `dam_turbine`, `cable_net` și casele celor cinci veterani, `hire_dam_*`.
  - Efecte: angajare / plasă (`good` = dam, cable_ore sau crystal; benzile 3/1/1/2/3) / steag (`kiln`, `crystal_shed`) /
    clopot. Condiții: după R3 și lanțul `after` din `ERA4_UNLOCKS`; `dam_bell` are `all` plus
    `income = StationConfig.DAM_BELL_INCOME`.
  - Tipurile primesc câmpurile opționale `Pad.netRank`, `Pad.netEra` și `Needs.income`. `PAD_LOOKS_LIKE` primește desene de
    împrumut pentru cele 23.
- **Meseriile:** 15 rânduri `CREWS`, fiecare pe un singur rând, cu `secondPrice` din `DamRun.prices`.
- **Suma de start:** `TycoonConfig.DAM_START_COINS = 35000000000000`. **FlowConfig:** `processorPad` și `storePad` pentru linia
  cristalului (R5).
- **Simulatorul:** `PAD_IDS_ERA4` și `check_config_prices(dam.prices, PAD_IDS_ERA4, ERA4_ROLES)`; verificarea platformelor
  gratuite (preț 0); verificarea inversă, pe Erele 2–4 (orice platformă cu preț e în hartă); `check_config_dam`
  (`DAM_START_COINS` egal cu `d.start_sum`); `PAD_NETS_ERA4` (rang, bandă, fel și eră, comparate cu rândurile); `ERA4_AFTER`
  (fiecare intrare validată prin schimbarea lambdei din fals în adevărat pe stările date de `dam_transform`, apoi comparată
  prin regex cu `needs.after`); opțional, raportul nopții de după cele 6 angajări în `report_era4`.
- **Atenție:** prețurile se scriu ca întregi întregi, nu `1.5e12` (regexul de la `sim_tycoon.py:2269` alunecă altfel în
  platforma următoare). Id-urile nu au voie să coincidă cu id-uri de locuri.
- **Teste:** `TycoonConfig.test` (77 de platforme, `perEra[4] = 23`, toate `live=false`, `eraIsLive(4)` fals; platformele din
  FlowConfig există în `byId`; `needs.income` egal cu `DAM_BELL_INCOME`); `check_lines`: câte un test inversat pentru fiecare
  verificare nouă și pentru `PAID_COINS_MAX_SHARE`.
- Verificare: j1 neschimbat; `golden_chain` fără diferențe; `--robust` rulat detașat (~13 minute).

**j3. Plasele pe rang.** Depinde de: j2.
- `ChainMath.netBaseRank` / `netUpgradeBaseRank` (funcțiile pe index devin învelișuri); `TycoonConfig.netIdentity(pad)` întoarce
  rangul și era; le citesc `StationService.StateFrom` (`:162-171`) și `UpgradeBase` (`:142-151`); `TycoonMath.netKind` întoarce
  dam / cable_ore / crystal.
- Verificare (teste): plasele 1–15 identice la bit; cele 5 plase ale Erei 4 egale cu bazele din `golden_chain build_era4`.

**j4. Profilul v19, aditiv.** Depinde de: j2.
- Șablonul, tipurile, `Meta.version = 19` și `toV19` după `toV18` (`DataService.luau:669-685`).
- Câmpuri noi: `World = 1` și `Memories = {}`; `Stats.damGift` și cele 6 numărători ale Erei 4 (numele din
  `processedStat`/`soldStat` din FlowConfig); `Purchases.coinsBought`; cele 13 grămezi din `FlowConfig.FULL`;
  `Stations.switchyard/cableworks/relay/kiln/town`; 15 rânduri `Crews`; pe `Hand`, opționale: `formerRole`, `formerKey`,
  `medal`, `retired`.
- `player:SetAttribute("World")`, curățat la 1 sau 2, pus înainte de `SaveLoaded`.
- Verificare: suita v19 (acele din șablon, idempotența, ce există nu se atinge); acul de la `ProfileMigrate.test.luau:1102` se
  mută; șablonul are toate grămezile din `FULL`, ca suita v16 (`:976-978`) să rămână verde la comutator.

**j5. Contorul monedelor Robux (R8).** Depinde de: j4. Owner: doar informare.
- O funcție pură `afterGrant` / `afterCoins`, apelată în `PurchaseService.grant` (`:83-98`), `EconomyService.TrySpend` și
  `AddCoins` cu sumă negativă, `DevService setcoins` și `Reset`.
- Verificare (teste): cumperi 10, cheltui 5 din 20: rămân 10; monedele scad la 3: contorul scade la 3.

**j6. Modelul de lume, doar lumea 1.** Depinde de: j1, j2.
- `Shared/Config/WorldConfig.luau` (`worldOfEra`, `sanitize`); `TycoonConfig.WORLDS[1]` și `RiverConfig.WORLDS[1]` arată spre
  aceleași obiecte de azi.
- Accesori cu lumea implicit 1: `padsOfWorld`, `districtsOf`, `zonesOf`, `decorOf`, `spawnOf`, `deckSpans(w)`, `streetLamps(w)`,
  `wirePoles(w)`, `homeClearRects(w)`, `comingEra(w)`.
- Filtrul pe lume intră acum, înainte de date: `lampHitsWorker` citește `LINE_PLACES` și `JOIN_PLACES` doar ale lumii;
  `Overlay.luau:736` trece prin `sellerPlacesOf(w)`.
- Verificare: j1 identic; `padsOfWorld(1)` identic cu `PADS[1..54]`; un test text cere ca niciun modul să nu citească lumea la
  `require`.

- **Făcut (2026-10-03), cu verificatorul:** `WorldConfig`, `TycoonConfig.WORLDS[1]` și accesoriile. `RiverConfig.WORLDS` a
  intrat la j7 (lumea 1 e copia de azi, cheie cu cheie, sub test). Felinarele au o singură regulă publică,
  `TycoonConfig.lampBlocked(x, w)`, care ocolește și roabele Relay-ului; felinarele lumii 2, scrise de mână, trec prin ea.
  Un loc cu o cheie necunoscută nu mai cade în sat: nu e al niciunei lumi, iar un test cere ca toate cheile să fie
  cunoscute. Atributul `World` trece prin `WorldConfig.sanitize`.
**j7. Datele lumii 2, din planșa aprobată (`preview_dam_layout.py:24-192`).** Depinde de: j6.
- **`WORLDS[2]`:** mărimea 3385×1920, PLOT, țărmurile cu `calm`; două cartiere (puntea lacului, x 240–640, și puntea
  barajului, x 880–2760), cu drumuri și curți (id-uri `*_yard`); zonele `dam_town` (fără gard) și `fog5` (x 3065–3385), cu
  text neutru; spawn la (800, 1180); dreptunghiuri blocate: zidul (x 640–880, y 768–960) și canalul în două bucăți
  (2193,856 64×234 și 2193,1170 64×66); sloturile de decor din piață.
- **Rânduri pe chei:** `LINE_PLACES` barrels/cable/crystal, `JOIN_PLACES.grid`, `SELLER_PLACES.town` (ușa 2059,1130, clienții
  în oglinda tavernei), cele 9 clădiri fixe, 13 grămezi, 6 felinare, 4 stâlpi.
- x/y/bandă pe cele 23 de platforme, încă `live=false`. Pontonul, barca, comorile, roata și avizierul rămân unde sunt.
- Teste: verificatorul de așezare `synth_check` portat în `tests/`, pe lume; oglinda clienților; felinarele generalizate
  dincolo de `for era = 1, 3`.
- Verificare: j1 identic; `village_ground --check` neschimbat; `check_config_prices` găsește toate prețurile.
- **Făcut (2026-10-03).** `TycoonConfig.WORLDS[2]` (mărimea, cele două cartiere cu drumuri și curți, zonele `dam_town` fără
  gard și `fog5` cu text neutru, spawn, `blocked`, apa, zidul, cele 9 clădiri, căsuțele, felinarele, stâlpii, cardurile) și
  `RiverConfig.WORLDS` (lumea 1 = copia de azi; lumea 2: 3.385 px, terenul până la 3145, malul amenajat). Grămezile stau în
  locurile liniilor, ale unirii și ale vânzătorului (ca la Erele 2–3), deci n-au tabel separat. Testul de așezare
  (`tests/World2Layout.test.luau`) aplică regulile satului pe lumea 2 și derivă felinarele din regula străzii.
  **Amânat la k11:** sloturile decorului cumpărat în Dam Town. Schița din scratchpad nu le are pe toate (lipsește bunting-ul),
  iar clientul le citește abia atunci.

**j8. Drumurile pe lume.** Depinde de: j7.
- `RoadGraph.forWorld(w)` (`fromConfig()` rămâne `forWorld(1)`); `HandRoutes.context` poartă graful în loc de `true`; cheia
  cache-ului din `viaBetween` (`:212-226`) include lumea; `HandRoutes.forWorld(w)`, iar lumea se alege după rol.
- Verificare (teste): j1 identic; graful lumii 2 e conex; ciclurile fiecărei meserii a Erei 4 pe locurile reale nu taie apă sau
  zone blocate; durata unui ciclu între 4,5 și 19,4 s; turul de mână are 2996 px.

**j9. Râul, mersul și darurile pe lume, partea pură.** Depinde de: j7.
- `WorldMap.forWorld(w)`; `CatchFloat.travel(netX, spawnX?)`, cu bușteni pornind de la piciorul deversorului; `DriftMath` cu
  porțiunile de unde se scoate darul și `EXIT_X` pe lume, adică lacul și puntea barajului (D74, punctul 6); `RiverSim.box` pe
  lume; `DriftService.reachesOf(world)`.
- Verificare (teste): lumea 1 neschimbată; cazuri pentru lumea 2; determinismul [D13].

**j10. Statusurile și porțile pe lume, pe server.** Depinde de: j2, j6.
- `padStatuses` / `meetsNeeds` / `padBlocker` primesc venitul, printr-o singură funcție `TycoonMath.incomeGoal(base,
  flowFactor)`; `TycoonMath.era(bought, padsOfWorld(w))`.
- `PadService.Statuses` folosește lista lumii, nivelurile și venitul; `PadService.Grant` devine public; `DevGrant` refuză
  platformele altei lumi.
- O funcție pură `WorldMath.allowed(world, era)`, citită de BuyPad, UpgradeStation, UpgradeCrew, UsePlace, AtPlace,
  CollectNet și DevGrant. Refuzul are motiv (`closed`), nu e tăcut [D43].
- `NetService.Snapshot` și `tick` sar plasele altei lumi; `zoneStatuses` merge pe lume, iar zona `dam` din lumea 1 rămâne
  încuiată cât timp Era 4 e în joc (`NetServer.luau:16-33`).
- Verificare (teste): condiția de venit, cu și fără 2x Flow; tabelul de adevăr al lui `allowed`; `era` cu lista lumii; j1
  identic.

**j11. Quest-urile.** Depinde de: j2, j10.
- Un quest revendicat nu mai e nici activ, nici capitol curent (R7). `QuestConfig.chaptersOfWorld(w)`, cu `facts.world` în
  `currentChapter` și `chapterClosedBy`; `Claim` refuză quest-urile altei lumi.
- Un fel nou de quest, `income`: `Facts.income`, `Facts.flowFactor`, `QuestMath.goalOf`, `counterText`; îl citesc
  `QuestService.factsFor`, `Snapshot` și `Claim`; `DevService.chapter` sare `income`.
- Capitolele 10–12 în `ALL_CHAPTERS`, în ordinea `DAM_CHAPTER`, adormite. `QuestMath.settleWorld`, pur: plătește doar în perle
  tot ce e nerevendicat din capitolele 1–9, plus recompensele de capitol.
- Verificare (teste): totul revendicat și AWAY 0, capitolul curent nu mai e 1; cu 2x Flow, pasul de venit cere 8T; testul de
  ordine acceptă un quest de venit înaintea unei condiții `income`; sumele din `settleWorld`.

**j12. `StateFrom` pur și startul de aur al barajului.** Depinde de: j3, j4.
- `StationService.StateFrom` (`:159-213`) se mută într-un modul din Shared, care primește modelul ca parametru (`GAME` sau
  `FULL`); `dam = data.World >= 2`; `UPGRADE_BASE` derivat pe erele din joc, cu rândurile switchyard/cableworks/relay/kiln/town.
- `golden_chain.py --dam-start` scrie `GOLDEN_DAM_START`: venit 19.567.696.500/s, cu clopote.
- Verificare (teste): profilurile de aur ale Erelor 1–3 dau același venit; profilul startului barajului, sub `FULL`, dă 19,57B/s.

- **[Verificatorul j6]** steagul `dam` se derivă din aceeași valoare curățată: `WorldConfig.sanitize(data.World) >= 2`, ca
  lumea afișată (atributul `World`) și liniile închise să nu se poată contrazice.
**j13a. Serverul pe unire: EconomyService și instantaneele.** Depinde de: j10, j11, j12.
- `process` cu `assemble`, iar `processorSpeed` cu `joinWaiting`; liniile închise nu mai fac tick; scurgerea cu `drainOrder`.
- `UseProcessor` → `useJoin`; `DropAt` → `dropJoin` și întoarce restul; vânzătorul refuză piesele (`part_to_relay`).
- Instantaneele unirii fără `pileOf(nil)`; `SackSnapshot` cu `partBy`; gardă în `DevFillPile`; `HandService.drop` păstrează
  restul.
- Se adaugă `scripts/era4_flip.py` (R10).
- **[Făcut]** `EconomyService`: `process` cu `FlowMath.assemble` pe uniri (ștampila pe fiecare grămadă a unei piese), viteza cu
  `joinWaiting`; liniile și vânzătorii altei hărți nu lucrează și nu se scurg (`openFor`); scurgerea cu `drainOrder`;
  `UseProcessor` → `useJoin`; `DropAt` întoarce `(câte, restul)`: la unire `dropJoin`, la vânzător piesele rămân la om, la un loc
  necunoscut tot; `HandService.drop` păstrează restul în `hand.carry`; `SackSnapshot.partBy`; `StoreSnapshotOf` gol la unire;
  `ProcessorSnapshotOf` la unire cu toate piesele laolaltă, plus `inputs` (pe piesă) și `waiting`; `DevFillPile` pe unire pune
  piese gata în fiecare grămadă. `scripts/era4_flip.py on|off|status` (marcaj `-- era4_flip`, `off` reface fișierele identic,
  `status` iese cu 1 cât e pornit).

**j13b. Serverul pe unire: restul serviciilor.** Depinde de: j13a.
- `HandService` sare oamenii retrași; plasele închise nu se mai umplu.
- `StationService`: gardă în `BUILDING_ROWS`; rânduri și meserii doar ale lumii; `LineView` cu `supply`, `heldBy`, `netsLine`,
  `isOpen`, `waiting`. `WelcomeInfo` primește `awayStalled` / `unhired`. `CrewMath.fromProfile` și `VillageLook.hands` sar
  oamenii retrași.
- **[Făcut]** `HandService` sare oamenii retrași în tick și refuză o angajare a altei hărți; `VillageLook.hands` îi sare;
  `CrewMath.unhired(crews, flow, lines)`: meseriile fără om de pe liniile deschise (la startul barajului, exact cei șase:
  cableCollector … pylonRunner; testat pe startul de aur, cu AWAY 0 și apoi > 0). `StationService`: garda pe `seller` nil în
  `BUILDING_ROWS`; panoul arată doar plasele, clădirile și meseriile hărții tale; `LineView` are `supply`, `heldBy`, `isOpen`,
  `waiting` (`EconomyService.WaitingOf`), iar instantaneul `netsLine`; `WelcomeInfo.awayStalled` / `unhired` doar în lumea 2,
  după cel puțin un minut, când absența n-a adus nimic (fereastra se deschide și fără monede); regula e pură,
  `CrewMath.stalledWelcome` (verificatorul j13b), cu teste pe lume, minut, monede și lipsuri. `waiting` e nil pe o linie închisă
  sau a altei hărți. **Clientul copiază explicit câmpurile noi la k3 (`LineView`) și la k6 (`WelcomeController`).**
- **Verificare j13 (prima probă pe comutatorul local):** **[2026-10-03: amânată]** Studio nu era conectat la Rojo (pluginul
  se reconectează doar la Connect, iar `rojo serve` pica pe o legătură simbolică `Packages/Packages -> Packages`, ștearsă). Se
  face la prima sesiune cu Studio conectat, înaintea lui k1. profil de probă în lumea 1, la Works Bell. `errors` gol, `TycoonState`
  ajunge, venitul e egal cu cel de fără comutator, nicio platformă a Erei 4 nu e `available`, capitolele se opresc la 9, zona
  `dam` e încuiată. Apoi comutatorul se oprește.

**j14. Ridicarea și previzualizarea, pure (făcute în `DamMath`; planul le numea `WorldMath.buildDam`).** Depinde de: j4, j5, j11, j12, j13b.
- **Ordinea:**
  1. gărzi;
  2. `Memories.oldVillage`, copie adâncă a satului;
  3. „Last cart”: marfa rămasă se vinde la preț întreg;
  4. `settleWorld` plătește quest-urile vechi;
  5. banii: R = min(C, coinsBought); monedele noi = START + R; darul = max(0, C − R − START); completarea = max(0, START − (C − R));
  6. `World = 2`;
  7. cei 5 veterani se re-cheiază, cu numele și chipul copiate explicit, plus `formerRole` și medalie; restul oamenilor devin
     `retired`;
  8. cele 7 platforme gratuite, veteranii puși direct (fără `Hire`);
  9. `Firsts`, chitanța.
- Verificare (teste): a doua chemare nu face nimic; invarianta „monede noi + dar = C + completare” pe toate ramurile; nimic
  șters în afara celor 5 chei vechi; numele și chipurile sunt copii, nu referințe; venitul de după ≥ venitul de dinainte și
  egal cu startul de aur; grămezile vechi golite, cu suma vândută egală cu „Last cart”.
- **[Făcut, 2026-10-03]** în modulul lui, `Shared/Modules/DamMath` (`DamMath.build(data, ctx)` / `preview` / `blocked`), nu
  în `WorldMath`: WorldMath e citit la fiecare cerere și n-are de ce să tragă quest-urile, oamenii și fotografia satului.
  `ctx` = ceasul râului, userId (veteranul care lipsește), `valueOfCounts` (prețul de acum, `EconomyService.ValueOfCounts`),
  modelul și `eraIsLive`. Plasele dăruite prind de la `ctx.now`, nivelul 1, fără `PadService.Grant`. Chitanța (`Receipt`) are
  „Last cart”, perlele quest-urilor, C, R, START, monedele noi, darul, completarea, venitul înainte și după, veteranii; se scrie
  și în `Memories.dam`. Teste (`tests/DamMath.test.luau`): gărzile, a doua chemare, invarianta banilor pe șase ramuri, „Last
  cart” pe traistă, grămezi, plase și `carry`, quest-urile, veteranii (copii, medalia, cele 5 chei), un veteran lipsă, darurile,
  venitul după = startul de aur (19,57B/s), previzualizarea fără efect și egală cu ridicarea.
- **[Verificatorul j10]** „Last cart” vinde și marfa și găsirile din **plasele lumii 1** (`data.Nets[*].goods`), din traistă și
  din `carry` al **tuturor** oamenilor vechi (nu doar al veteranilor), apoi le golește. Plasele rămân în profil cu nivelul lor
  (pentru `Memories`), cu `goods = {}`. Invarianta: suma „Last cart” = traista + grămezile + plasele + `carry`, iar după
  ridicare toate sunt goale. `PadService.Grant` dă platforma **fără om** (turbina, Cable Net); casele veteranilor le scrie
  `DamMath.build` direct, deci testul cere: după ridicare, fiecare meserie a barajului are exact un om, cu numele și chipul vechi.

**j15. `DamService`, remote-urile și uneltele de probă.** Depinde de: j13, j14.
- **Remote-uri (doar RemoteEvent):** `BuildDam`, `DamPreview`/`DamPreviewResult`, `DamBuilt`, `DamRejected`, `DamFilmSeen`;
  găleata `Dam` în RateLimiter; handlerele în NetServer; ordinea `Init` în `Bootstrap.server` fixată de un test text.
- **`DamService`:** răspunde `soon` cât Era 4 nu e în joc; refuză cu `settling` cât plata offline nu e făcută; verifică
  `expectedKeep`; aplică `DamMath.build` dintr-o bucată; invalidează Pads și Stations; `DataService.SaveNow` (scos din
  PurchaseService), apoi `DamBuilt`; Analytics.
- **DevService:** `world:N`, `dam`, saltul la capitolele 10–12, numele noilor grămezi, `up:` pe clădirile noi.
- **[Făcut, 2026-10-03]** `DamService` (doar în sat): `Preview` (chitanța, `Firsts.DamPreviewed`), `Build(player, expectedKeep)`
  cu ordinea `no_profile` → `busy` → `settling` (`StationService.Settled`, pus după plata offline de la încărcare) → gărzile din
  `DamMath` → `changed` (monedele cu care pornești nu mai sunt cele de pe ecran) → `DamMath.build` → invalidare, atributul
  `World`, starea → `DataService.SaveNow` (scos din PurchaseService, aceeași buclă) până când `LastSavedData.World == 2`, apoi
  `DamBuilt`. `FilmSeen` (`Firsts.DamFilmSeen`). Remote-urile în `Net.luau`, găleata `Dam` (4, 0,5/s), handlerele în NetServer
  răspund și la limită („busy”); `Analytics.DamStep` (canalul „Dam”). DevService: `world N` (doar 1..`COUNT`, fără ridicare),
  `dam` (chitanța) și `dam build` (drumul adevărat), `chapter N` refuză capitolele altei hărți și le sare pe ale ei,
  listele din `pile` și `up` vin din FlowConfig / `UPGRADE_KINDS`. Teste: `tests/DamService.test.luau` (ordinea Init, bâlciul
  fără serviciu, remote-urile, limita, ordinea gărzilor în `Build`, salvarea comună, uneltele). Capătul clientului,
  `Client/Controllers/DamController` (cererile, chitanța copiată câmp cu câmp, un toast la orice refuz sau la ridicare,
  `Strings.damRejected` / `DAM_BUILT`), e pus acum fiindcă `check_requires` nu primește remote-uri pe care clientul nu le atinge;
  ecranul (k7), masa Dam Plans (k6) și filmul (k9) se așază peste el prin `OnPreview` / `OnBuilt`.
- **[Verificatorul j10]** odată cu `data.World = 2`, și `player:SetAttribute("World", 2)`. Serverul citește lumea din profil
  (`PadService.World`, pentru statusuri și zone, de la verificatorul j10), dar atributul îl citește clientul la k1.
- Verificare: `check_requires` pe ambele proiecte (`DamService` nu intră în bâlci); probă pe comutator, **în același Play al
  sondei** (un Play nou al sondei e mereu un profil nou, în lumea 1): `dev chapter 10` (face tot satul, cu Works Bell), `dev dam`
  (cifrele lui `DamMath`), `dev dam build`, apoi starea, `dev away 8` și fereastra: serverul e în lumea 2, AWAY 0 cu cei șase
  numiți, capitolul 10, plasele vechi stau, fără erori. `dev world N` scrie doar lumea (fără ridicare) și e refuzat pe salvarea
  păstrată a owner-ului [verificatorul j15].
- **[Verificatorul j15, făcut]** salvarea forțată e pură și testată (`Shared/Modules/SaveLoop`, cu termen la fiecare așteptare:
  o salvare picată nu mai ține răspunsul până la autosave-ul de peste ~5 minute; comună cu chitanțele Robux); o previzualizare
  refuzată de limită păstrează chitanța bună; refuzurile au culoarea lor; „save” spune adevărul („The Dam is built. It saves
  when you leave”).

### k: clientul. Fără owner, cu desene de împrumut, în afară de k9 și k12.

- **[Verificatorul j6]** `dev world:N` refuză un N în afara 1..`WorldConfig.COUNT`.
**k1. Clientul pornește după lume.** Depinde de: j9, j15.
- `WorldSession`; `Bootstrap` așteaptă atributul `World` (cel mult 25 s, apoi 1), cu `TycoonState.world` copiat explicit și o
  gardă care îngheață starea. Camera și personajul pe `WorldMap.forWorld`, cu spawn-ul lumii.
- În lumea 2 nu pornesc controllerele satului vechi (Dock, Storage, Sawmill, Shed, Forge, Modern, Look); River, Ambient și Drift
  merg pe lume. `SceneArt.BuildBackground(layers, world)`, cu dale și forme provizorii pentru lac, zid și canal; se repară și
  scurgerea de conexiuni `PreRender`.
- Verificare: sonda pe lumea 1, pe codul comis, dă aceleași texte; pe comutator, lumea 2 pornește fără erori, iar zidul și
  canalul opresc personajul.

- **[Verificatorii j6 și j9] De făcut aici:**
  - lumea ajunge la controllere explicit (`Init(deps.world)`), citită o dată de Bootstrap după `SaveLoaded`;
  - testul textual „nicio citire a lumii la încărcare” se înlocuiește cu unul care cere ca în `src/Client` să nu existe
    apeluri fără lume la accesoriile de lume în corpul unui modul. Primul caz e `DriftController.luau:61`;
  - `DriftController` folosește `DriftMath.reachesFor(world, pads)` (regula serverului) și nu desenează darul cât
    `DriftMath.hiddenAt(x, world)`, adică peste zid. Darul se arată căzând pe spuma deversorului;
  - plutitorii spre plase pornesc de la `CatchFloat.SPAWN_X_BY_WORLD[w]` (x 880 la baraj, fața zidului). La fel decorul din
    larg (`RiverRenderController`), care la baraj pornește de la piciorul deversorului (PLAN-HARTA §5), nu de la marginea
    lacului. Piciorul zidului și spuma se desenează deasupra plutitorilor.
- **[Făcut, 2026-10-03]** `Bootstrap.client` citește lumea o dată, după `SaveLoaded` (cel mult 25 s, apoi satul, cu
  avertisment), și o dă explicit: `CameraController` / `CharacterController` (mărimea, spawn-ul și zidurile din
  `WorldMap.forWorld`), `RiverRenderController` (configul, fundalul, decorul din larg de la `SPAWN_X_BY_WORLD`),
  `AmbientController`, `DriftController` (`SetPads` cu regula serverului, `xAt` / `activeAt` / `hiddenAt` pe lume),
  `NetController` (plutitorii), `Overlay` (ghidajul pe meseriile hărții). Garda lumii: o stare cu alt `world` (câmp nou, de
  la server) sau atributul schimbat îngheață clientul până la reîncărcare (k8). Gaterul, taverna, depozitul, shed-ul, forja,
  Moara / Wire Works, modernizarea și privirea „Look” nu pornesc la baraj (iar Apply-urile lor rulează doar în sat); din
  taverna rămâne pontonul (`DockController.BuildPier`); cardurile Storage / Sawmill / Dock tac nepornite; `LineController.Init`
  e în ambele lumi. `SceneArt.BuildBackground(layers, world)`: lățimea și malurile lumii, fără pământul copt al satului,
  cu lacul, zidul, deversorul (alb, pulsând), canalul și spuma de la piciorul zidului (în `Plot`, peste plutitori), toate
  provizorii; legătura `PreRender` se desface când desenul iese din lume (macheta bâlciului). `VillageDecor.items(world)`.
  Fără garda pe vânzătorul nil, primul rând din Bootstrap ar fi oprit tot clientul la l3. Zonele se copiază după
  `zonesOf(world)`; tutorialul și promisiunea râului știu de baraj. Rândul de final și „Next” vin de la server (`coming`, pe
  lume). Test: în `src/Client`, nicio accesorie de lume fără lume în corpul unui modul. **Nevăzut în Studio** (Rojo
  neconectat): proba din l1 pornește lumea 2 cu comutatorul și se uită la zid, canal, spawn și erori.
**k2. Platformele, zonele, Overlay și ghidajul pe lume.** Depinde de: k1.
- Cele 4 bucle din PadController; Overlay (refuzurile, `DROP_AT` cu rezerva de la DOCK); ZoneController (prima zonă a unei
  lumi fără gard); StationPanel; CeremonyController; GuideMath cu țintele lumii 1 doar în lumea 1; Sound și Dock; felinarele pe
  lume; locurile de decor din Dam Town.

- **[Verificatorul j8]** dâra ghidajului (`GuideController`, azi pe `RoadGraph.fromConfig()`) merge pe
  `RoadGraph.forWorld(lumea jucătorului)`. Oamenii nu mai cer nimic: contextul implicit din `HandRoutes` e al lumii meseriei
  (cât era ei e în joc), deci la l3 serverul și clientul îi duc pe drumurile barajului singuri. Graful lumii 2 ocolește
  zidul și canalul și pe iarbă (`RoadGraph.blockedBetween`).
- **[Pasul j10]** cartonașul condiției (`PadController`, `TycoonMath.padBlocker`) primește lista lumii jucătorului, venitul
  de acum și factorul 2x Flow, ca Dam Bell să spună „Earn 4T coins a second first” (8T cu pass-ul), la fel ca serverul.
  Zonele vin pe lume de la server (`WorldMath.zoneStatuses`), dar clientul încă le citește pe ale satului.
- **[Verificatorul j10] Cititorii din client care trec pe lume** (statusurile și zonele de la server sunt doar ale hărții de
  acum):
  - `PadController.ruinNeeds` (:887-893): garda clopotului citește `WorldMath.bellBefore(pad.era, world)`, care e nil pentru
    prima eră a unei lumi. Altfel fiecare ruină a barajului scrie „Opens after the Works Bell”. Test Lune: lumea 2, totul
    cumpărat fără Dam Bell, 3.9T → „Earn 4T coins a second first”, cu Flow 2 → „Earn 8T ...”;
  - `Bootstrap.client` copiază zonele după `TycoonConfig.zonesOf(world)`, nu după `ZONES` (azi `dam_town`/`fog5` s-ar pierde);
  - `ZoneController.Apply` și gardul din Overlay primesc lumea (azi `nil` = satul) pentru `WorldMath.zoneSign` /
    `WorldMath.fenceText`, regula unică a textelor (făcută la verificatorul j10, cu teste pe ambele ramuri);
  - promisiunea râului (`RiverRenderController.SetPromise`, din `snapshot.pads.fifth_net`) e pe lume: la baraj, nil.
    Regulă, cu test textual: niciun cod din `src/Client` nu citește `snapshot.pads.<id al lumii 1>` sau `TycoonConfig.ZONES`
    în afara unei ramuri a lumii 1 sau a unui accesoriu de lume;
  - `firsts.runner` / `firsts.bell` vin din profil (`PadService.Owns`, făcut), deci rămân adevărate la baraj; `workshop`
    rămâne pe statusuri (atelierul parcat).
- **[Făcut, 2026-10-03]** `PadController` (cele 4 bucle pe `padsOfWorld`, pământul pe `districtsOf`, ruina prin
  `WorldMath.ruinNeeds`: clopotul de dinaintea erei pe harta ta, apoi condiția cu venitul și 2x Flow; serverul trimite
  `flowFactor`, Bootstrap îl dă cu `PadController.SetIncome`), `ZoneController` (zonele hărții, prima zonă a ei fără gard,
  `fence = false` fără gard, textele pe lume), `Overlay` (gardul pe lume, refuzul tavernei și „+N” de rezervă doar în sat,
  vânzătorii hărții), `StationPanel` (cartierul de sub tine și filele doar ale hărții, prima eră a ei implicit),
  `CeremonyController` (zona fiecărei ere pe harta ei; nimic „nu se deschide” peste hărți), `GuideController` (dâra pe
  `RoadGraph.forWorld`), felinarele pe lume (la baraj, aprinse de la început), `VillageController` (la baraj, doar decorul de
  pe apă și de pe ponton). `GuideMath` ia oamenii după meserie (`STEP_OF_JOB`), nu după poziție, și lasă unirea pe seama lui k5:
  cele 16 căderi de pe linia unirii au dispărut (cu comutatorul pornit pică 16, toate adormiri sau lipsurile din HandConfig,
  ChainWords, EraWords). Test: clientul nu citește direct `ZONES` / `DISTRICTS` / `DECK` / `ROADS` / `YARDS` / `DECOR`.
- **k2b (făcut; locurile sunt o propunere, de privit pe planșă):** decorul cumpărat în piața Dam Town (PLAN-HARTA §3: „10 locuri”
  = cele 10 lucruri; pe uscat sunt 12 locuri, cât în sat). `VillageConfig.DECOR[*].spotsByWorld[2]` / `whereByWorld[2]` pentru
  cele 8 lucruri de pe uscat (pontonul și lacul stau pe aceleași coordonate, deci felinarele de ponton și barca nu se mută);
  `VillageConfig.spotsOf(decor, lume)` / `whereOf` sunt singurele citiri (`VillageController` după lumea lui, macheta din bâlci
  `spotsOf(decor, 1)`; lumea 1 rămâne `decor.spots`, test). Locurile: sudul pietei (patru straturi de flori, fântâna, banca), Memory
  Wall (grădina), piciorul zidului (stupii, puțul), vest de Canteen (statuia), două ghirlande peste stradă. Planșa
  (`preview_dam_layout.py`) le citește din surse și le desenează cu mărimea lor reală; testul `World2Decor` din
  `World2Layout.test` le pune la aceleași reguli ca ale satului (uscat, în zonă, fără clădiri, oameni, curți, drumuri, nume,
  felinare, stâlpi, carduri E, unul peste altul).
- **[Verificatorul k2b, făcut]** fâșia de sub clopotniță (de unde apari spre ponton, roată, avizier și barcă) e liberă: fântâna
  (puțul) stă la vest de Canteen, statuia la gura aleii pieței, stupii pe iarba dintre Battery Store și Switchyard; textele
  spun lucruri care se văd („On the town green”, nu „Dam Town” și nici „East of”). `World2Decor` cere acum: locurile și textele
  pentru fiecare lume de după sat, fără busolă și fără „Dam Town”, ghirlanda peste un drum cu stâlpii pe iarbă, 32 px de capătul
  pontonului, clienții orașului fără decor în cale și drumul tău (drept și pe drumuri) de unde apari până la colțurile satului.
**k3. Liniile barajului în client.** Depinde de: k2, j13.
- 6 clădiri fixe cu `borrowed`; `LineController` pentru unire (două grămezi, `waiting` copiat explicit); Overlay `DROP_AT` /
  `playerStand` la `:273, :721-743, :821`; GuideMath și `STEP_OF_JOB`.
- Turbina din zid (824–880, 690–768); Dam Collector-ul ia de la piciorul zidului; oamenii retrași stau fără traseu.
- **[Verificatorul k2]** `GuideMath` primește lumea: `logsGoal` / `scrapGoal` / `sellGoal` și pașii 3–9 ai lemnului și fierului
  rulează doar în lumea 1, iar `logs` scade și piesele (`partBy`), cu pasul lor spre `JOIN_PLACES[unire].inputIn[linie]`. Azi, cu
  comutatorul, trei cabluri în traistă la baraj dau „Take the logs to the Sawmill”. Test Lune în lumea 2: nicio țintă cu cheia
  sawmill / forge / dock / storage / shed.
- **[Verificatorul j13a]** clientul copiază explicit `sack.partBy[unire]` (0 implicit, pentru fiecare unire din `LINE_ORDER`) și
  `processor.inputs[piesă]` / `waiting` ale atelierului unirii; Overlay, GuideMath și LineController citesc `partBy` pentru cardul
  „Drop” al Relay-ului și pentru săgeată. Test Lune: copia din Bootstrap, rulată pe ordinea FULL, are fiecare câmp al traistei
  și al atelierului trimis de server.
- **[Verificatorul j13a]** „+N” de la `HandDelivered` la o unire: Overlay caută `handId` în ultimele `hands`, ia linia omului
  (`HandRoutes.jobOf(role).line`) și pune cifra la `JOIN_PLACES[unire].inputIn[linie]`; intrarea primei piese rămâne doar rezerva,
  când omul nu se găsește.
- **[Verificatorul j13b]** `Bootstrap.client` copiază explicit, pe fiecare `LineView`, `supply`, `heldBy`, `isOpen`, `waiting`, iar în
  instantaneu `netsLine`, cu valori implicite cinstite (supply = catch, heldBy = linia, isOpen = true, waiting = nil,
  netsLine = ""). Azi copia ia doar catch / delivered / bottleneck / playerShare (`Bootstrap.client.luau` ~:1272).
- **[Verificatorul j11, făcut]** săgeata unui quest pe un loc citește `LINE_PLACES[line] or JOIN_PLACES[line]` (Overlay), deci
  „Join barrels and cable 10 times” arată spre inelul Relay-ului; testul de locuri din `QuestMath.test` citește la fel.

- **[Verificatorul j7]** casele barajului, până la arta lor: `PadArt.bought` să încerce întâi `PadArt.home(padId, count)`
  (lanțul `PAD_LOOKS_LIKE` duce la colibele urcate ale erelor 2–3, fiecare alta), nu direct perechea din Era 1. Atunci și
  amprenta din `World2Layout.test` (120×102) e cea desenată. Al doilea Dispatcher stă la 48 px de primul, iar clienții
  orașului vin de la y 1240 (abateri mici de la oglinda tavernei, puse și în planșă).
- **k3 (făcut):** `Shared/Modules/StateCopy` (pur) e copia stării pe linii, folosită de `Bootstrap.client`: traista (`rawBy`,
  `sellBy`, `partBy` pe fiecare unire), gramezile (`inputs` / `waiting` doar la unire; liniile Erelor 1–3 ies cu cheile de
  dinainte), vânzătorii, `LineView` (`supply`, `heldBy`, `isOpen`, `waiting`, cu valorile implicite cinstite) și `netsLine`.
  `tests/StateCopy.test` citește tipurile serverului (`ProcessorSnapshot`, `LineView`) și cere fiecare câmp copiat, pe ordinea
  FULL. `LineController.join` desenează Relay-ul: gramada fiecărei piese la intrarea ei, ieșirea, inelul (te cheamă doar cât
  se poate uni ceva: cea mai mică grămadă de piese) și placa „Waiting for cable” (`Strings.joinWaiting`) când lipsește o
  piesă. Lumea 2 își face liniile și vânzătorii din tabele (`Bootstrap`, `WORLD_BUILDING_ART`: fiecare clădire fixă poartă
  desenul altei clădiri din erele 2–3 până la A0–A4); vânzătorul fără platformă (Switch House) e deschis. Overlay: „+N” la
  unire pe intrarea piesei omului (`HandRoutes.jobOf`), ținta plasei de pe stâlp (`pad.x`). GuideMath primește `world` și
  `parts`: pașii lemnului și ai fierului, prima plasă și taverna doar în sat; piesele merg la **inelul** Relay-ului
  (`playerStand`, unde apare cardul E; `inputIn` e intrarea oamenilor, la ~300 px de inel), iar inelul și curentul gata intră
  în pașii 4b / 6b. Turbina barajului se desenează în fața zidului (`TycoonConfig.wallTurbineAt`, `WORLDS[2].turbine`), fără
  stâlp și funie, fără legănat; stâlpul ei (unde o golește Dam Collector-ul) rămâne la x 980 pe punte, ca în planșa aprobată.
  `PadArt.bought` încearcă întâi casa primei perechi urcate (colibele Erei 3), nu direct pe cea din Era 1. Oamenii retrași
  nu sunt în instantaneu (`VillageLook.hands`, j13b), deci n-au traseu; Dam Town îi arată la k10.

**k4. Meniurile și cuvintele.** Depinde de: k3.
- **[Verificatorul k2]** capul panoului Stations la baraj are 18 verigi (butoaie 5, cablu 5, unirea 2 + orașul 1, cristal 5):
  lista clădirilor ar rămâne cu ~1,5 rânduri. Lanțul pe două coloane sau compactat (ori panoul mai înalt), cu un test pe
  aritmetica înălțimii pe ambele lumi (`624 − (250 + HEAD_SHIFT + TABS_H) − 16 ≥ 2 · (ROW_H + 8)`). Satul rămâne pe 11 (test).
- **[Verificatorul k2]** ruina unei platforme a barajului: eticheta `PAD_EYEBROW_NOT_BUILT`, nu „RUINS” (acolo n-a fost nimic de
  reconstruit), iar ramura „all” din `Strings.padNeeds` spune „Build everything else in Dam Town first” (numele zonei din
  `zonesOf(worldOfEra(era))`), cu test pe ramura „all” a lumii 2.
- `StationMenu.CHAIN` pe lume și schimbarea de cartier în StationPanel; `Strings` pentru Era 4 (refuzurile, „Opens at 4T coins a
  second”, „Waiting for cable/barrels”, indiciile, AWAY 0); textele `HeldBack`; `check_panel_rows`.

- **k4 (făcut):** `Shared/Modules/ChainHead` (pur) face verigile capului Stations și așezarea lor: o coloană până la 11 verigi
  (satul, neschimbat la pixel: aceleași cutii, `HEAD_SHIFT` 80), două coloane de la 12, rupte între două linii (barajul: 10 + 8,
  `HEAD_SHIFT` 60, deci lista păstrează ~3 rânduri), cu numele (100 px), cifra (72) și „← slowest” (70) strânse.
  `tests/ChainHead.test` socotește înălțimea pe fiecare lume și măsoară numele în Nunito. Ruina unei platforme a lumii 2 scrie
  „NOT BUILT YET”, iar ramura „all” spune „Build everything else at The Dam first” (`TycoonMath` ia zona din lumea erei;
  `fresh` apare doar în lumea 2, ca martorul satului să rămână identic). Refuzurile Erei 4 au text (magazia goală și „No … yet”
  după numele motivului, Crystal Shed / Kiln, „Barrels and cable go to the Relay Station first” la vânzător, „Dropped 3
  parts” la Relay), iar bateriile, minereul de cablu și cristalul duse greșit spun unde merg (`hint` / `hintedBy` în
  FlowConfig). **Reparat și în sat:** refuzul „raw_only” de la Piață și Depou spunea textul tavernei („The Tavern buys planks
  and iron…”); acum spune vânzătorul lui. `StationMenu.CHAIN` rămâne tabelul de căutare al tuturor verigilor: cheile vin din
  vederea serverului, deja pe lume. „Opens at 4T” e cartonașul Dam Bell („Earn 4T coins a second first”, j11); AWAY 0 e la
  k6 (fereastra „Welcome back”). Harta comutatorului: 15 (ChainWords reparat).

**k5. Quest-uri, linia NEXT și ghidajul pentru capitolele 10–12.** Depinde de: k4, j11.
- `counterText` și lista fără paranteze; `HUDController.SetStep` păstrează bara de venit; primul tur în 6 pași de mână; fără
  preț și fără „While you save” pe o platformă încuiată; ghidajul sare meseriile la maxim cât ține un pas de venit; indiciul
  AWAY. Teste Lune pe GuideMath și QuestMath.
- **[Verificatorul j11, făcut]** eticheta quest-ului de venit vine de la server cu pragul înmulțit (`QuestMath.textOf`, același
  șablon ca pe cartonașul clopotului, `Strings.earnPerSecond`): cu 2x Flow „Earn 8T coins a second”. Lista, linia NEXT și
  bannerul citesc `text`, deci nu mai e nimic de făcut în client pentru ea.

- **k5 (făcut):** serverul trimite contorul scris al fiecărui quest (`counter` = `QuestMath.counterText`, pe rând și pe quest-ul
  activ), copiat explicit; lista și linia NEXT îl arată, **fără paranteze și în sat** („3/10”; la venit „966B/1T”, ≤ 60 px).
  Un quest de venit ajunge la ghidaj fără loc: pasul n-are săgeată și nici preț (bara NEXT rămâne venitul), iar textul lui
  numește ce se mai poate urca acum (`AmbitionMath.pick`, aceeași țintă ca linia NEXT fără quest; sare meseriile la maxim),
  cu butonul Upgrade al stației pulsând. Un quest pe o platformă încă încuiată (`outline`) are săgeata spre ea (cartonașul
  spune ce lipsește), fără preț și fără „While you save”; regula e și în sat. Turul cablului la baraj (plasă → Cable Works →
  inel → cablul gata → inelul Relay-ului → curentul → Switch House) e testat cu comutatorul. **Indiciul AWAY** trece la k6,
  lângă fereastra „AWAY 0” (aceleași cuvinte).

**k6. Intrarea din lumea 1.** Depinde de: k2, j15.
- Steagul `damAvailable` în stare. Masa Dam Plans devine „Build the Dam (E)” (azi ar dispărea la `eraIsLive(4)`,
  `ModernController.luau:104-150`); bannerul de la Works Bell și linia NEXT; „Goes into the Dam when you build it” pe cardurile
  de nivel; „Welcome back” spune regula sumei de start; EraWords, Ceremony, `Overlay:794`, `comingEra(w)`.
- Verificare: ambele ramuri (Era 4 în joc și nu) testate.
- **[Verificatorul j13b] Fereastra „AWAY 0”:** `WelcomeController` copiază explicit `awayStalled` și `unhired` (listă de
  șiruri), iar ieșirea timpurie (`WelcomeController.luau` ~:253, „fără monede, fără nimic venit, fără serie”) cere și
  `not awayStalled`. Textul numește doar `unhired[1]` (lanțul `after` face ca doar ea să se poată cumpăra acum) și e adevărat
  în orice caz: „Your Dam earned nothing while you were away.” + „Hire a {name} to keep it running!” (nu „Nobody worked”:
  veteranii lucrează pe linia butoaielor; nu „waited for cable”: e fals când lipsesc doar Relay Keeper-ul sau Pylon
  Runner-ul). Rândul se rupe (TextWrapped + AutomaticSize Y, ca `note`), măsurat cu `Theme.textHeight`; înălțimea ferestrei
  se socotește din nou; test Lune pe ramura `coins == 0 and awayStalled` și pe cel mai lung nume, la lățimea de telefon.
- **[Verificatorul j10]** după Works Bell, cu `damAvailable`, panoul zonei barajului din sat și textul de la gard spun unde se
  ridică barajul și cum („Build the Dam at the Dam Plans”): ramură nouă în `WorldMath.zoneSign` / `fenceText`, cu test.
  Azi, după l3, ele spun `Strings.zoneAway` („The Dam will rise by your pier”), fără clopot și fără „coming soon”.
- **[Verificatorul j11]** rândul de final al listei de quest-uri citește `snap.lastOfWorld` (serverul, după capitolele lumii; făcut
  în j11), dar și `TycoonConfig.comingEra()`, care după l3 întoarce nil în lumea 1 (zona `dam` e a Erei 4). În sat, cu Era 4 în
  joc, rândul trebuie să spună „Build the Dam” (aceeași ramură ca masa Dam Plans), nu să dispară.

**k7. Ecranul „Build the Dam”.** Depinde de: k6.
- **[Verificatorul j15]** cât n-a venit răspunsul la „Build” (salvarea poate dura), ecranul scrie „Saving…”, iar satul golit de
  starea lumii 2 nu se desenează: clientul îngheață la schimbarea lumii (k1). Pe „save”, ecranul nu oferă „Try again”.
- Trei coloane cu cifrele din `DamPreviewResult`; `Widgets.HoldButton` nou (1,5 s); „Not yet”; `Theme.fitSize` pe fiecare cifră;
  textele pentru refuzuri; chitanța.

**k8. Reîncărcarea în lumea 2.** Depinde de: k7.
- `FerryService.Depart(player, destination?)` (barca rămâne identică); salvare, `MarkTeleporting`, apoi teleport în același
  place; cartonașul „THE DAM” ca TeleportGui.
- Verificare: sonda pe barcă, identică. Teleportul real se probează doar pe staging (l2).

**k9. Filmul.** Depinde de: k8. Owner: stilul și lungimea (O1, luate ca recomandate), plus arta filmului.
- `DamMath.frameAt(t)` pur, cu teste; `VillageDiorama` se mută în `Client/UI` (`check_requires` pe ambele proiecte);
  `MusicController.Play`; mersul se oprește; `ReducedMotionEnabled`; Skip de la secunda 3 la prima vizionare; comanda de sondă
  `cinematic:seek`.

**k10. Dam Town și oamenii retrași.** Depinde de: k9, j14.
- Cantina, căsuțele, piața, clopotnița cu plăcile cu cifrele jucătorului, Memory Wall din `Memories.oldVillage`; oamenii
  retrași se plimbă pe graful lumii 2; o pagină „Your people”.
- **[Verificatorul k2b]** etichetele clădirilor lumii 2 scriu exact „Canteen” și „Memory Wall”: textele avizierului de la baraj
  le folosesc („Beside the Canteen”, „Beside the Memory Wall”), iar un test cere ca fiecare nume propriu din `whereByWorld[2]`
  să fie printre etichetele lumii 2 (azi: și „Battery Store”, eticheta de la k3). Orașul nu se numește „Dam Town” în textele
  jucătorului cât numele nu e pe hartă (testul World2Decor respinge „Dam Town” și cuvintele de busolă); dacă la k10 primește un
  semn, testul se leagă de el.
- **[Verificatorul k2b]** oamenii retrași, plimbați pe graful lumii 2, nu calcă decorul cumpărat: același test ca drumul de unde
  apari (`World2Decor`, pas de 4 px, om de 48×72), pe traseele lor.

**k11. Bâlciul pentru gazdele din lumea 2.** Depinde de: j4, k10. Owner: ce intră la prima lansare (O1, luat ca recomandat).
- `VillageLook.Snapshot.world`, copiat explicit. Până la decizie (și acum, provizoriu): fotografia satului vechi, cu semnul
  „Building the Dam”. `TitleMath` „Dam Builder” derivat din `World >= 2`; `build_balci DevWorld`. Macheta lumii 2, titlul, poza
  „Before the Dam” și „Watch again” vin după prima lansare.
- **[Verificatorul j10, făcut]** macheta satului din bâlci (`VillageDiorama`) și pământul copt (`village_geometry.luau`) parcurg
  `padsOfWorld(1)`, deci ruinele barajului nu apar peste satul vechi după l3. Macheta unei gazde din lumea 2 e treaba lui k11.

**k12. Pământul copt al lumii 2.** Depinde de: j7, A0. Owner: aprobarea planșei și a urcării (2 imagini).
- `village_geometry.luau` cu lumea ca argument (lumea 1 iese identică în JSON); `village_ground.py --world 2` scrie două felii
  (`prop_dam_ground`, `_2`) și `dam_ground.lock`; `--check` pe ambele lumi, în CI, `publish_staging` și CLAUDE.md;
  `BAKED_DISTRICTS` pentru lumea 2 abia după urcare.

### A: arta, în paralel, după O1

Fiecare lot: planșă, aprobare, acordul de urcare, apoi verificarea moderării. **Aprobarea și fiecare urcare cer owner-ul,
explicit.**

| Lot | Ce | Imagini | Se poate împrumuta? |
|---|---|---|---|
| A0 | Planșe fără urcare: silueta barajului (fața din aval și spumă), ~6 cadre-cheie ale filmului, previzualizarea pământului lumii 2 | 0 | — |
| A1 | Reperele lumii 2: zidul, deversorul, fața turbinei, canalul cu stăvila și casa podului, stâlpii, orașul pictat stins și aprins, clopotnița, Memory Wall, căsuța, cristalul pe râu | ~13 | Nu |
| A2 | Filmul | ~12 imagini și 3 sunete | Nu |
| A3 | Pământul copt (k12) | 2 | Nu |
| A4 | Clădirile, colibele, mărfurile, ținutele | ~14 + ~20–28 + ~12–15 + 10–15 | Da; pot veni și după lansare |

Totalul, ~92–97 de imagini și 3 sunete până se joacă Era 4 (PLAN-HARTA §7).

### l: proba și comutatorul

**l1. Proba cap-coadă pe comutatorul local, pe profil de probă.** Depinde de: toate j și k, A1, A2.
- Înainte de Play: `lsof -nP -iTCP:34872` arată `ESTABLISHED`.
- Drumul: Works Bell → previzualizare → Build → `dev world:2`, Stop/Play cu „keep save” → **o absență de peste un minut
  înainte de cei 6 (fereastra se deschide și numește Cable Collector) și una sub un minut (nu se deschide)** [verificatorul
  j13b] → turul cablului → cei 6 oameni (AWAY 0, apoi peste 0) → „Earn 1T” → Kiln → cristalul → „Earn 4T” → Dam Bell → o absență → o vizită în bâlci.
- Verificări: `errors` gol, niciun text care iese din cutie; quest-urile nu se întorc în capitolul 1; grămezile vechi nu mai
  cresc; un al doilea Build nu face nimic.

**l2. Ce poate verifica doar owner-ul, în Studio și pe staging.**
- Filmul și mișcarea, mersul (~8 s până la Relay), riscul de pe telefon (460 vs 476 px).
- Teleportul, doar pe un place publicat: fereastra satului din Studio se închide întâi, altfel Roblox răspunde 409. Cere acordul
  lui pentru publicare.

**l3. Comutatorul: singurul commit care schimbă jocul.** Depinde de: l1, l2.
- `ENGINE_ERAS = 4` și `live = true` pe cele 23 de platforme.
- **Testele de adormire, rescrise:** `ChainMath.test.luau:3214`, `FlowMath.test.luau:76` (devine 34) și `:374-383` / `:501`,
  `HandRoutes.test.luau:715`, `TycoonConfig.test.luau:101` / `:124` / `:1245-1262`.
- **[Pasul j13a, remăsurată după verificatorul j13a] Harta comutatorului** (`python3 scripts/era4_flip.py on` pe o copie a
  arborelui, cu `fair.project.json` copiat și el; 862 de teste, 2026-10-03). Testele care depindeau de comutator fără s-o spună
  (așezarea satului pe `PADS`, casele din `WorldDecor`, zonele și clopotul din `WorldMath.test`, oamenii satului în lumea 2, puntea
  râului, grămezile v19, ghidajul pe meseriile hărții) citesc acum lista lumii 1 sau `eraIsLive(4)`. Cu comutatorul pornit pică
  32, după nume (nu după rânduri, care se mută):
  - **adormiri, de rescris aici:** ChainMath „modelul jocului e cel din StationConfig, cu verigile în ordinea de aur” și „jocul
    rulează încă Erele 1-3; FULL are și barajul”; FlowConfig „locurile și grămezile nu se repetă” (devine 34); FlowMath „un rând
    al barajului cerut cu modelul jocului pică”; HandRoutes „jocul nu-i vede pe oamenii barajului”; „Meseriile barajului
    adormit”; TycoonConfig „Era 4 stă adormită”; World2Layout „lumea 2 are datele ei” (`live` fals) și World2Roads „fiecare om
    al barajului merge sau stă pe uscat” (`jobOf("damCollector")` / `standFor("relayKeeper")` nil); WorldIdentity (engine.txt);
    TycoonConfig „finalul ce e în joc” (`comingEra()` iese nil în sat: după l3 finalul trebuie să anunțe barajul, k6, nu să tacă);
  - **așteptat cât comutatorul e pornit:** WorldConfig „comutatorul local al Erei 4 nu e niciodată comis”;
  - **lipsuri reale, pe pașii lor:** GuideMath crapă pe linia unirii (`index nil with 'role'`, 16 teste: turul de mână, linia
    fierului, Moara, regula 0, pontonul; k2 și k5: `STEP_OF_JOB` și `JOIN_PLACES`); HandConfig: meseriile barajului n-au ținută
    (`ROLE_OUTFIT`, k10 / A) și nici destule prenume pentru doi oameni pe fiecare meserie (k10); ChainWords: `Strings.NET_WORDS`
    n-are unirea (k4, unirea n-are plase); EraWords: textul de după Works Bell (k6).
  - **reparat la verificatorul j13a:** `GuideMath.guidedRoles(opened, world)` ia doar meseriile hărții tale. Altfel, după l3,
    ghidajul din sat ar fi așteptat oamenii barajului și n-ar mai fi tăcut (D50). Overlay îi dă lumea la k1.
  Fiecare pas k își reia lista: comutatorul pornit pe o copie, apoi doar adormirile de mai sus rămân roșii.
- Verificare: `tests/witness/world1.txt` identic (zona `dam` din lumea 1 rămâne în `ZONES`, încuiată; masa Dam Plans nu e în
  martor), `tests/witness/engine.txt` rescris cu `WORLD_WITNESS=write` și citit rând cu rând; `sim --table --chain --robust` identic;
  CLAUDE.md și DECIZII actualizate; `verify-work`; push.
