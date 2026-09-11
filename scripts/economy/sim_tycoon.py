#!/usr/bin/env python3
"""Simulatorul economiei tycoon-ului. Se ruleaza INAINTE de orice cod de balans [23]: plasele,
capacitatea, automatizarea, procesarea si energia se cupleaza neliniar, iar o greseala de pret se
vede aici in secunde, nu dupa trei sesiuni de joc.

Doua reguli pe care simulatorul le IMPUNE, nu doar le masoara:
  1. Preturile se DERIVA din tinte de ritm (cat vrem sa astepte jucatorul intre cumparari),
     nu se ghicesc. pret = venit_curent x asteptare_tinta, rotunjit.
  2. Regula celor patru motive: orice platforma trebuie sa creasca venitul -- prinzi mai mult,
     vinzi mai scump, scapi de o corvoada sau deschizi ce urmeaza (clopotele dau si un bonus).
     O platforma care nu misca venitul opreste simularea cu eroare.

Jucatorul simulat e LACOM: cumpara imediat ce isi permite. Un om real merge, citeste si exploreaza,
deci e mai lent -- factorul REAL de mai jos e o ipoteza de validat la primul playtest.

Folosire:  python3 scripts/economy/sim_tycoon.py [--table]
"""
import math
import sys
from dataclasses import dataclass, field

REAL = 1.8   # un jucator real ~ de 1.8 ori mai lent decat cel lacom (IPOTEZA, de masurat)

GOODS = {    # valoare de baza in monede, pondere in prinderi
    "driftwood": (1.0, 0.70),
    "scrap":     (2.0, 0.13),   # doar de pe banda 2
    "reeds":     (2.0, 0.08),
    "shards":    (2.5, 0.04),   # doar de pe banda 3 (canalul adanc)
    "named":     (14.0, 0.05),  # obiectele cu nume din ItemConfig, media pe tiere
}

@dataclass
class State:
    t: float = 0.0
    coins: float = 0.0
    nets: list = field(default_factory=list)
    lanes: int = 1
    sack_big: bool = False
    runners: int = 0            # un alergator goleste automat 3 plase
    flume: bool = False         # jgheabul goleste automat TOATE plasele
    rate_mult: float = 1.0
    price_mult: float = 1.0
    named_mult: float = 1.0     # macaraua: obiectele grele se vand mai scump
    flow: float = 0.0
    crank: float = 0.0          # prima statie merge si fara energie, incet, cu manivela [dir04]
    stations: dict = field(default_factory=dict)   # bun -> [mult, debit/s, energie]
    miller: bool = False
    dockhand: bool = False
    boats: int = 0
    index_found: int = 0
    rebirths: int = 0
    bells: float = 1.0          # bonusurile permanente ale clopotelor

def income(s: State) -> float:
    per_net = [r * s.rate_mult for r in s.nets]
    auto = len(per_net) if s.flume else min(len(per_net), s.runners * 3)
    manual = len(per_net) - auto
    eff = (0.82 if s.sack_big else 0.70) / (1 + 0.08 * max(0, manual - 1))
    items = sum(per_net[:auto]) + sum(per_net[auto:]) * eff

    shares = {g: v[1] for g, v in GOODS.items()}
    if s.lanes < 2:
        shares["driftwood"] += shares.pop("scrap")
    if s.lanes < 3:
        shares["driftwood"] += shares.pop("shards")
    # RETEAUA DE ENERGIE. Energia merge intai la statiile care scot cea mai mare valoare pe unitate
    # de energie. Consecinta de care depinde tot: a adauga capacitate SAU energie nu poate niciodata
    # sa scada venitul -- doar sa-l creasca sau sa-l lase la fel. O cumparare care il face pe
    # jucator mai sarac dupa ce a platit e cel mai rau lucru pe care il poate face un tycoon.
    total = 0.0
    offers = []   # (castig pe unitate de energie, bun, bucati posibile, castig pe bucata, energie pe bucata)
    for g, share in shares.items():
        inflow = items * share
        base = GOODS[g][0] * (s.named_mult if g == "named" else 1.0)
        total += inflow * base                       # tot ce se prinde se vinde macar brut
        if g in s.stations:
            m, cap, draw = s.stations[g]
            m = m * (1.2 if s.miller else 1.0)       # morarul scoate mai mult din fiecare bucata
            gain = base * (m - 1)
            offers.append((gain / draw, g, min(inflow, cap), gain, draw))
    offers.sort(reverse=True)
    s._demand = sum(p * d for _, _, p, _, d in offers)
    flow = s.flow
    for i, (_, g, possible, gain, draw) in enumerate(offers):
        # prima statie merge si fara energie, incet, cu manivela [dir04]
        free = possible * s.crank if (i == 0 and s.crank > 0) else 0.0
        powered = min(possible - free, flow / draw) if draw > 0 else possible - free
        flow -= powered * draw
        total += (free + powered) * gain
    total += s.boats * 0.35 * GOODS["named"][0]            # barcile aduc incarcaturi rare
    price = s.price_mult * (1.2 if s.dockhand else 1.0)
    return total * price * s.bells * (1 + 0.01 * s.index_found) * (1 + 0.5 * s.rebirths)

# ---- efecte ----
def net(r):            return lambda s: s.nets.append(r)
def mul(a, f):         return lambda s: setattr(s, a, getattr(s, a) * f)
def on(a):             return lambda s: setattr(s, a, True)
def plus(a, n):        return lambda s: setattr(s, a, getattr(s, a) + n)
def seq(*fs):          return lambda s: [f(s) for f in fs]
def build(g, m, c, e): return lambda s: s.stations.__setitem__(g, [m, c, e])
def upgrade(g, cf, ef):
    """Upgrade de CAPACITATE -- doar pentru statia care e chiar blocajul (gaterul)."""
    def f(s):
        st = s.stations[g]; st[1] *= cf
    return f
def refine(g, mf):
    """Upgrade de CALITATE: aceeasi cantitate, valoare mai mare. La statiile secundare, care nu
    sunt niciodata saturate (fierul vechi e 13% din prinderi), capacitate in plus ar fi decor."""
    def f(s):
        st = s.stations[g]; st[0] *= mf
    return f

# ---- drumul de platforme. Fiecare are un MOTIV: C=prinzi mai mult, V=vinzi mai scump,
#      A=scapi de o corvoada (automatizare), D=deschizi ce urmeaza ----
ERAS = {
 "Era 1 · The Landing": [
    ("First Net",       "C", net(0.33)),
    ("Second Net",      "C", net(0.33)),
    ("Bigger Sack",     "A", on("sack_big")),
    ("Third Net",       "C", net(0.33)),
    ("Sorting Crate",   "V", mul("price_mult", 1.20)),
    ("First Runner",    "A", plus("runners", 1)),
    ("Far-Lane Net",    "C", seq(net(0.40), plus("lanes", 1))),
    ("Weighted Nets",   "C", mul("rate_mult", 1.30)),
    ("Workshop",        "V", plus("index_found", 6)),
    ("Fifth Net",       "C", net(0.40)),
    ("Dock Stall",      "V", mul("price_mult", 1.25)),
    ("Landing Bell",    "D", mul("bells", 1.10)),
 ],
 "Era 2 · The Mill": [
    ("Sawmill",         "V", seq(build("driftwood", 3.0, 1.6, 4.0), plus("crank", 0.35))),
    ("Water Wheel",     "V", plus("flow", 10)),
    ("Flume",           "A", on("flume")),
    ("Sixth Net",       "C", net(0.45)),
    ("Smelter",         "V", build("scrap", 3.0, 1.0, 5.0)),
    ("Miller",          "V", on("miller")),
    ("Loom",            "V", build("reeds", 3.0, 0.8, 6.0)),
    ("Wide Nets",       "C", mul("rate_mult", 1.40)),
    ("Seventh Net",     "C", net(0.50)),
    # Roata vine DUPA ce jucatorul a simtit lipsa: gaterul a incetinit doua platforme la rand si
    # a aparut "Low power". Pusa exact la trecere, adauga 0,3% -- o cumparare care nu se simte.
    ("Second Wheel",    "V", plus("flow", 10)),
    ("Market",          "V", mul("price_mult", 1.25)),
    ("Mill Bell",       "D", mul("bells", 1.15)),
 ],
 "Era 3 · The Yard": [
    ("Crane",           "V", mul("named_mult", 1.5)),
    ("Eighth Net",      "C", net(0.55)),
    ("Sorting Shed",    "V", plus("index_found", 6)),
    ("Sawmill II",      "V", upgrade("driftwood", 2.0, 0)),
    ("Ninth Net",       "C", net(0.55)),
    ("Fine Ingots",     "V", refine("scrap", 1.5)),
    ("Dockhand",        "V", on("dockhand")),
    ("Deep Channel",    "C", seq(net(0.60), plus("lanes", 1))),
    ("Kiln",            "V", build("shards", 3.0, 0.6, 8.0)),
    ("Third Wheel",     "V", plus("flow", 10)),      # cererea tocmai a trecut de 20
    ("Salvage Hall",    "V", mul("named_mult", 1.3)),
    ("Yard Bell",       "D", mul("bells", 1.20)),
 ],
 "Era 4 · The Harbor": [
    ("Boathouse",       "C", plus("boats", 1)),
    ("Tenth Net",       "C", net(0.65)),
    ("Fine Cloth",      "V", refine("reeds", 1.5)),
    ("Deep Nets",       "C", mul("rate_mult", 1.30)),
    ("Second Boat",     "C", plus("boats", 1)),
    ("Glazed Pottery",  "V", refine("shards", 1.5)),
    ("Eleventh Net",    "C", net(0.70)),
    ("Lighthouse",      "V", mul("price_mult", 1.25)),
    ("Third Boat",      "C", plus("boats", 1)),
    ("Grand Market",    "V", mul("price_mult", 1.30)),
    ("Twelfth Net",     "C", net(0.75)),
    ("The Charter",     "D", mul("bells", 1.25)),
 ],
}

def target_wait(k: int) -> float:
    """Asteptarea tinta (secunde, jucator lacom) inaintea platformei k. Porneste la ~20s, ca
    primele minute sa fie o rafala de cumparari, si urca incet spre ~7 minute la final.
    Plafonul exista pentru ca 'urmatorul pas mereu vizibil' [factorio] nu tine la 20 de minute."""
    return min(420.0, 20.0 * 1.125 ** k)

# Trepte de ~10%. Cu trepte mari (1 -> 1.2 -> 1.5 -> 2), la valori mari pretul urca mai repede decat
# venitul, iar regula "strict mai mare decat anterioara" le impinge in cascada: la prima incercare
# Charter-ul ajunsese la 19 ore reale, cu o asteptare de o ORA intre doua platforme.
NICE = (1, 1.1, 1.2, 1.3, 1.5, 1.6, 1.8, 2, 2.2, 2.5, 2.8, 3, 3.5, 4, 4.5, 5, 5.5, 6, 7, 7.5, 8, 9)

def nice(x: float, floor: int = 0) -> int:
    """Pret 'rotund' pe care il citeste un copil dintr-o privire (12, 150, 2.5K, 75K), si
    STRICT mai mare decat pretul platformei anterioare. Doua platforme la rand cu acelasi pret
    arata a greseala, chiar daca matematic sunt corecte."""
    if x < 10:
        v = max(0, int(round(x)))
        return v if v > floor else floor + 1
    for mag in (10 ** k for k in range(0, 13)):
        for n in NICE:
            v = int(n * mag)
            if v >= x * 0.93 and v > floor:
                return v
    return int(x)

def run(rebirths=0, index_found=0, stop_after=None):
    s = State(rebirths=rebirths, index_found=index_found)
    rows, k, prices = [], 0, []
    for era, pads in ERAS.items():
        for name, why, effect in pads:
            if rebirths:
                price = PRICES[k]
            elif k == 0:
                price = 0
            else:
                price = nice(income(s) * target_wait(k), prices[-1])
            prices.append(price)
            while s.coins < price:
                s.coins += income(s)
                s.t += 1
            before = income(s)
            s.coins -= price
            effect(s)
            after = income(s)
            if k > 0 and after <= before * 1.005:
                VIOLATIONS.append(f"{name}: {before:.2f} -> {after:.2f}")
            rows.append((era, name, why, price, s.t, after))
            DEMAND.append((name, round(getattr(s, "_demand", 0.0), 1), s.flow))
            k += 1
        if stop_after and era.startswith(stop_after):
            break
    return s, rows, prices

def fmt(sec):
    m, x = divmod(int(sec), 60)
    h, m = divmod(m, 60)
    return f"{h}h{m:02d}m" if h else f"{m}m{x:02d}s"

def big(n):
    for unit, d in (("B", 1e9), ("M", 1e6), ("K", 1e3)):
        if n >= d:
            return f"{n / d:.2f}".rstrip("0").rstrip(".") + unit
    return str(int(n))

PRICES = []
VIOLATIONS = []
DEMAND = []

if __name__ == "__main__":
    s1, rows, PRICES[:] = run()
    if VIOLATIONS:
        print("EROARE -- platforme care nu cresc venitul cu macar 0,5% (regula celor patru motive):")
        for v in VIOLATIONS:
            print("  " + v)
        print("\ncerere de energie vs energie disponibila, dupa fiecare platforma:")
        for n, d, f in DEMAND:
            print(f"  {n:<15} cerere {d:>6}  energie {f:>5}" + ("  <- LIPSA" if d > f + 0.01 and f > 0 else ""))
        sys.exit(1)
    if "--table" in sys.argv:
        prev, cur = 0.0, None
        print(f"{'#':>3} {'platforma':<15} {'mot':>3} {'pret':>8} {'lacom':>8} {'real~':>8} {'venit/s':>9}")
        for i, (era, name, why, price, t, inc) in enumerate(rows, 1):
            if era != cur:
                print(f"    --- {era}"); cur = era
            print(f"{i:>3} {name:<15} {why:>3} {big(price):>8} {fmt(t):>8} {fmt(t * REAL):>8} {inc:>9.1f}")
            prev = t
    ends = {}
    for era, name, why, price, t, inc in rows:
        ends[era] = t
    print("\nsfarsitul fiecarei ere (tura 1, lacom -> estimat real):")
    for era, t in ends.items():
        print(f"  {era:<22} {fmt(t):>8}  ->  {fmt(t * REAL):>8}")
    print(f"primele 5 platforme: {fmt(rows[4][4])} lacom -> {fmt(rows[4][4] * REAL)} real   (tinta: sub 5 min [18][24])")
    waits = [rows[i][4] - rows[i - 1][4] for i in range(1, len(rows))]
    print(f"cea mai lunga asteptare intre doua cumparari: {fmt(max(waits))} lacom")
    # scara renasterii: tura 2 cere Era 3, tura 3 cere Era 4 (fiecare renastere cere o era mai departe)
    idx = 12
    _, r2, _ = run(rebirths=1, index_found=idx, stop_after="Era 3")
    _, r3, _ = run(rebirths=2, index_found=idx + 12, stop_after="Era 4")
    t1 = ends["Era 2 · The Mill"]
    print(f"\nscara renasterii (bonus LINIAR +50%/renastere [wipes], Index pastrat):")
    print(f"  tura 1  pana la Era 2: {fmt(t1)} lacom  -> {fmt(t1 * REAL)} real")
    print(f"  tura 2  pana la Era 3: {fmt(r2[-1][4])} lacom  -> {fmt(r2[-1][4] * REAL)} real")
    print(f"  tura 3  pana la Era 4: {fmt(r3[-1][4])} lacom  -> {fmt(r3[-1][4] * REAL)} real")
