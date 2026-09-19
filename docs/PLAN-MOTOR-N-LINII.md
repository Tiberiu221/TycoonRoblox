# Planul: motorul lanțului, de la două linii la oricâte

**Stare:** plan, nimic scris încă (2026-09-19). Făcut de un agent pe Sonnet; referințele lui cheie le-am verificat în
cod (regula `swap` și alocarea la tavernă din `sim_tycoon.py` și `ChainMath.luau`, verificarea cu regex a constantelor
din `StationConfig`, numele schimbate după import de `tune_tycoon.py`). Restul se verifică pas cu pas, la implementare.

**De ce:** Era 2 [DECIZII D64] aduce linii noi de aceeași formă (plasă → collector → magazie → porter → atelier → hauler
→ vânzător), iar fiecare eră își vinde marfa la clădirea ei (Era 2: o Piață). Motorul de azi e scris de mână pentru
exact două linii, lemn și fier, care împart un singur vânzător (taverna).

**Constrângerea tare:** după refactor, Era 1 se poartă IDENTIC. Tabelul de aur din `tests/ChainMath.test.luau`
(generat de `scripts/economy/golden_chain.py` din simulator) nu se schimbă cu nicio cifră, iar
`python3 scripts/economy/sim_tycoon.py --robust` tipărește aceeași cronologie (333 de cumpărături, 33m36s reali).

## 1. Modelul de date

În simulator, ALĂTURI de globalele de azi, nu în locul lor (`check_config_constants` și `tune_tycoon.py` le citesc după
nume):

```python
LINE_ORDER = ("wood", "iron")          # ordinea in care se itereaza ORICE suma si orice alocare
LINES = {
    "wood": {"netKind": "wood", "openFlag": None, "seller": "dock",
             "steps": (("collector", "collect", "walk"), ("porter", "port", "walk"),
                       ("sawyer", "saw", "processor"), ("hauler", "haul", "walk"))},
    "iron": {"netKind": "scrap", "openFlag": "workshop", "seller": "dock",
             "steps": (("scrapCollector", "scrapCollect", "walk"), ("scrapPorter", "scrapPort", "walk"),
                       ("smelter", "forge", "processor"), ("ironHauler", "ironHaul", "walk"))},
}
SELLERS = {"dock": {"role": "trader", "priority": ("iron", "wood")}}   # cine ia primul din capacitatea vanzatorului
```

- Un pas e `(rol, veriga, fel)`. `walk` folosește `ROLE_BASE[rol]`, iar fără om cade pe partea jucătorului;
  `processor` folosește nivelul unei clădiri, iar fără om cade pe `cap / manualSteps(linie)`. Sunt două formule diferite.
- `priority` e un tuplu ordonat de linii, nu un număr pe linie: nu se poate desincroniza.
- În Luau, `ChainMath.Rates` primește `lines` și `sellers` (hărți pe id), iar câmpurile plate de azi (`woodCatch`,
  `collect`, … `ironBottleneck`) rămân, calculate din ele, ca vedere de compatibilitate.
- `StationConfig.LINES` / `SELLERS` se construiesc **referind** `ROLE_BASE`, `SAW_BASE_RATE` etc., nu copiind cifre:
  simulatorul scoate exact acele literale din textul fișierului, cu regex fără acolade imbricate. `ROLE_BASE` nu se
  mută niciodată într-un tabel imbricat.

## 2. Matematica, generic

Două comportări sunt azi ORDINE DE COD, nu date:
- fierul ia primul din capacitatea tavernei (`scrap = min(iron_max, sales)`, apoi `wood = min(wood_max, sales - scrap)`);
- câștigul marginal al unei verigi de fier e `swap = AVG.scrap - (AVG.wood dacă lemnul e ținut de tavernă)`.

**Alocarea generică**, pe vânzător, în ordinea `priority`:

```
ramas = capacitatea vanzatorului
pentru fiecare linie din priority:
    livrat[linie]   = min(minimulPropriu[linie], ramas)
    tinutDeVanzator = livrat[linie] == ramas si livrat[linie] < minimulPropriu[linie]
    ramas          -= livrat[linie]
```

**Câștigul marginal generic:** pentru o linie `l` care NU e ținută de vânzător, fie `j` prima linie de după `l`, în
ordinea de prioritate, care e ținută de vânzător. Verigile lui `l` al căror debit e egal cu `livrat[l]` primesc
`AVG[l] - AVG[j]` (sau `AVG[l]` dacă nu există `j`). Câștigul vânzătorului e `AVG` al primei linii ținute de el. Cu două
linii, regula se reduce exact la `swap`.

- **Trei sau mai multe linii pe același vânzător** nu apar nici în Era 1, nici în Era 2 (Piața e a Erei 2), deci regula
  nu se poate verifica pe date de aur acolo. Dacă va fi nevoie, întâi teste calculate de mână.
- **Două ordini diferite, care azi coincid doar din întâmplare:** prioritatea la vânzător (fier, apoi lemn) și ordinea
  de afișare și de departajare (`LINKS`: lemnul, fierul, taverna). Rămân două liste separate.
- **Virgula mobilă:** `income` e azi `c.wood * AVG.wood + c.scrap * AVG.scrap`, în ordine fixă. Generalizat, se adună
  peste `LINE_ORDER` (un tablou ordonat), NICIODATĂ cu `pairs()` peste o hartă cu chei text: ordinea nedefinită ar muta
  ultimii biți. La fel pentru totalurile `catch` și `delivered`. `min` / `max` nu depind de ordine.

## 3. Pașii, fiecare cu poarta verde

| Pas | Ce | Cum se verifică |
|---|---|---|
| a | `sim_tycoon.py`: `LINE_ORDER` / `LINES` / `SELLERS`; `chain`, `bottlenecks`, `income`, debitele, pe tabel. Numele câmpurilor lui `Chain` și globalele citite de `tune_tycoon.py` rămân | ieșirea completă a lui `sim_tycoon.py --table --chain --robust`, comparată cu cea de dinainte; o rulare de `tune_tycoon.py eval` |
| b | nimic de scris: `golden_chain.py` | diferența față de `tests/ChainMath.test.luau` e goală |
| c | `StationConfig.luau`: `LINES` / `SELLERS` / `LINE_ORDER`, prin referință | stylua, selene, `sim_tycoon.py --robust` |
| d | `ChainMath.luau`: motorul generic ALĂTURI de cel vechi, plus un test care le compară pe aceleași stări | `lune run tests/_run.luau` |
| e | `ChainMath.luau`: `rates` / `idleRates` trec pe motorul generic și umplu aceleași câmpuri plate; codul vechi iese | toată poarta; verificările de aur se potrivesc bit cu bit |
| f | `StationService.luau`: `lineBottleneck` și câmpurile pe linii din `Snapshot`, prin bucle peste `LINE_ORDER`, cu forma trimisă clientului NESCHIMBATĂ | toată poarta și o comparație de `Snapshot` pe un profil fix |
| g | amânat: scoaterea vederii plate și generalizarea clientului | — |

Tabelul de aur plat ESTE contractul de exactitate. Rămâne pe forma plată până la o decizie separată.

## 4. Ce se poate strica în tăcere

- `Bootstrap.client.luau` copiază fiecare câmp plat după nume, cu `or 0` / `or ""`, din `rawRates: any`: un câmp
  redenumit devine 0 pe client, fără nicio eroare [CLAUDE.md, capcana câmpurilor copiate].
- `StationService.StateFrom` leagă câmpurile cu nume din profil (`Stations.saw / .dock / .forge`) de `ChainMath.State`:
  e cusătura de adaptare, iar schema profilului nu se schimbă aici.
- `tune_tycoon.py` nu rulează în CI: o rupere acolo nu o prinde nicio poartă.
- `StationMenu` și `StationPanel` citesc `woodBottleneck` / `ironBottleneck` după nume; rămân neatinse doar fiindcă pasul
  f ține `Snapshot` plat.

## 5. În afara acestui refactor

Grămezile din `EconomyService` și controllerele lor (`Storage` / `Shed` / `Sawmill` / `Forge`), meniurile și
`Bootstrap.client`, schema `Stations` din profil și migrarea ei, scara de pași din `GuideMath`. Platformele cu `era = 2`
din `TycoonConfig` sunt rămășițe ale modelului vechi (dinainte de D46): lista și prețurile Erei 2 se derivă din
simulator, ca la Era 1.
