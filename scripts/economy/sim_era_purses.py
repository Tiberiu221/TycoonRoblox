#!/usr/bin/env python3
"""[D66] CAT DE MARE ERA „BANII DE OFFLINE CUMPARA ERA URMATOARE" si ce ar fi facut o punga pe cartier.

PUNGA PE CARTIER A FOST RESPINSA de owner (2026-09-21: „nu vreau alte monede"). S-a ales o singura moneda cu Moara pe
scara x3000 (sim_tycoon.ERA2_MULT) si poarta sim_tycoon.check_windfall. Scriptul ramane ca dovada a masuratorii: cu
cadrul de acum, partea 1 arata cat sare o absenta azi, iar partea 2 e varianta respinsa.

Unealta de „ce-ar fi daca", ca sim_era2.py: NU e in poarta si nu schimba nimic din joc. Incarca simulatorul adevarat
(sim_tycoon.py), joaca Era 1 si masoara trei lucruri:

  1. azi (o singura moneda): cat din Era 2 cumpara absenta de la sfarsitul Erei 1 (o ora, o noapte, o zi, si cazul
     owner-ului: 48 h cu Long Nights si 2x Flow, pe care le are fiindca e creatorul);
  2. experimentul: Era 2 platita DOAR din ce vinde Piata (punga Morii porneste goala, roata de apa e poarta platita cu
     banii satului, a sasea plasa e gratis ca prima plasa a Erei 1). Preturile ies din aceeasi scara de asteptare;
  3. absenta din MIJLOCUL unei ere: pleci imediat dupa cei cinci oameni si lipsesti 4 / 8 / 24 de ore -- cate din
     deblocarile ramase plateste, in Era 1 de azi si in Moara cu punga ei.

Timpii sunt ai jucatorului „lacom" al simulatorului (cei reali sunt cam de 1,8 ori mai lungi, vezi raportul lui).

Rulare: python3 scripts/economy/sim_era_purses.py
"""
import contextlib
import io
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import sim_tycoon as T  # noqa: E402

HOURS = (4, 8, 24)


def covered(rows, start_t, budget):
    """Cate cumparaturi (in ordinea simulatorului) plateste `budget` si cat timp de joc sar."""
    spent, n, last_t = 0.0, 0, start_t
    for _label, _kind, price, t, _after, _bn in rows:
        if spent + price > budget:
            break
        spent += price
        n += 1
        last_t = t
    return n, last_t - start_t


def absence_after(rows, marker):
    """Pleci imediat dupa `marker`: cate deblocari ramase plateste o absenta de 4 / 8 / 24 h."""
    row = next(r for r in rows if r[0] == marker)
    rate = row[4]
    later = [r for r in rows if r[3] > row[3]]
    total_unlocks = sum(1 for r in later if r[1] == "unlock")
    out = []
    for hours in HOURS:
        budget = rate * hours * 3600
        spent, last_unlock, n_unlock = 0.0, "-", 0
        for r in later:
            if spent + r[2] > budget:
                break
            spent += r[2]
            if r[1] == "unlock":
                last_unlock, n_unlock = r[0][7:], n_unlock + 1
        out.append((hours, budget, n_unlock, total_unlocks, last_unlock))
    return rate, out


def mill_purse_era2(s1):
    """Era 2 platita doar din punga Morii (experiment prin inlocuirea venitului si a optiunilor, pe o clona)."""
    era2_lines = T.ERA_LINES[2]
    era1_links = set(T.ERA_LINKS[1]) - {"nets"}
    real_income, real_options = T.income, T.options

    def mill_income(s):
        c = T.chain(s)
        gross = 0.0
        for line in T.LINE_ORDER:
            if line in era2_lines:
                gross += c.lines[line].delivered * T.line_avg(line)
        return gross * s.price_mult * s.bells * (1 + 0.01 * s.index_found) * (1 + 0.5 * s.rebirths)

    def mill_options(s, prices, era=None):
        out = []
        for o in real_options(s, prices, era):
            label, _price, _effect, kind, uid = o
            if kind in era1_links:
                continue  # cladirile si treptele oamenilor satului: le platesti cu banii satului
            if kind == "nets" and label.startswith("Net ") and int(label.split()[1]) <= T.NETS_PER_ERA:
                continue  # plasele satului
            if uid is not None and uid.endswith("2") and uid[:-1] in T.ERA1_ROLES:
                continue  # al doilea om din sat
            out.append(o)
        return out

    T.income, T.options = mill_income, mill_options
    try:
        s = T.clone(s1)
        s.wheel = True
        s.bought.add("wheel")
        s.coins = 0.0
        era = dict(T.ERA2)
        era["seed_prices"] = {"wheel": 0, "net6": 0}
        t0 = s.t
        s2, rows2, _prices2, longest, final_mill, _shares, _ = T.run(era=era, start=s, max_seconds=400000)
        return t0, s2, rows2, longest, final_mill
    finally:
        T.income, T.options = real_income, real_options


def main():
    with contextlib.redirect_stdout(io.StringIO()):
        s1, rows1, prices1, *_ = T.run()
        s2, rows2, *_ = T.run_era2(T.clone(s1), prices1)
    inc1 = T.income(s1)
    total2 = sum(r[2] for r in rows2)
    print(f"Sfarsitul Erei 1 ({T.fmt(s1.t)} lacom): venit {inc1:.1f}/s. Era 2 azi: {len(rows2)} cumparaturi, "
          f"{total2:,.0f} monede, {T.fmt(s2.t - s1.t)} lacom.")
    print("\n1. AZI, o singura moneda: cat din Era 2 plateste absenta de la sfarsitul Erei 1")
    # [D71] orele platite la viteza intreaga, pe curba de azi (plin 8 h / 16 h cu Long Nights, un sfert pana la 24 h)
    for label, hours, mult in (
        ("o ora", T.offline_equiv_hours(1), 1),
        ("o noapte (8 h)", T.offline_equiv_hours(8), 1),
        ("o zi (24 h, curba D71)", T.offline_equiv_hours(24), 1),
        ("o zi cu Long Nights (D71)", T.offline_equiv_hours(24, True), 1),
        ("o zi cu Long Nights si 2x Flow", T.offline_equiv_hours(24, True), 2),
        ("o zi intreaga, plin (pana la D66)", 24, 1),
        ("48 h cu 2x Flow (pana la D66)", 48, 2),
    ):
        money = inc1 * mult * hours * 3600
        n, dt = covered(rows2, s1.t, money)
        print(f"   {label:38s} {money:>13,.0f} -> primele {n:3d} din {len(rows2)} "
              f"(sare {T.fmt(dt)} din {T.fmt(s2.t - s1.t)})")

    with contextlib.redirect_stdout(io.StringIO()):
        t0, sm, rowsm, longest, final_mill = mill_purse_era2(s1)
    print("\n2. EXPERIMENT, Moara cu punga ei (roata de apa platita cu banii satului, a sasea plasa gratis)")
    print(f"   {len(rowsm)} cumparaturi in {T.fmt(sm.t - t0)} lacom, cea mai lunga pauza {T.fmt(longest)}, "
          f"venitul Morii la final {final_mill:.0f}/s")
    for label, kind, price, t, after, _bn in rowsm:
        if kind == "unlock":
            print(f"   {label[7:]:24s} {price:>10,.0f}  la {T.fmt(t - t0):>7s}   venitul Morii dupa: {after:8.1f}/s")

    print("\n3. ABSENTA DIN MIJLOCUL EREI: pleci imediat dupa cei cinci oameni")
    for title, rows, marker in (("Era 1, azi", rows1, "unlock:Innkeeper"), ("Moara cu punga ei", rowsm, "unlock:Merchant")):
        rate, out = absence_after(rows, marker)
        print(f"   {title} (venit {rate:.1f}/s dupa {marker[7:]}):")
        for hours, budget, n, total, last in out:
            print(f"      {hours:2d} h -> {budget:>11,.0f}: {n:2d} din {total} deblocari (pana la {last})")


if __name__ == "__main__":
    main()
