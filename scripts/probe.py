#!/usr/bin/env python3
"""Telecomanda sondei din Studio: porneste un Play, trimite comenzi, citeste raspunsurile.

Drumul unei comenzi (vezi plugins/DriftwoodProbe.lua si scripts/probe_server.py):
  * `edit` si `server` isi iau comenzile de la serverul local (HTTP) si raspund tot acolo;
  * clientul unui Play n-are HTTP: comanda ajunge la el prin partea de server (atribut replicat), iar raspunsul e TIPARIT
    in Output, de unde ajunge in jurnalul Studio (~/Library/Logs/Roblox/*_last.log). De acolo il citeste scriptul asta.
  * `dev` merge la DevBridge, podul din joc: aceleasi comenzi ca in consola de dev (coins:500, buyto:6, state, ...).

ATENTIE: ceasul jurnalului Studio ramane in urma cat doarme Mac-ul. Nimic de aici nu se bazeaza pe ora, doar pe pozitia
in fisier.

  python3 scripts/probe.py play                 porneste un Play DE PROBA (profil gol, nu salvarea owner-ului)
  python3 scripts/probe.py stop                 opreste Play-ul
  python3 scripts/probe.py wait-boot [sec]      asteapta "server bootstrap complet" si sonda clientului
  python3 scripts/probe.py errors               erorile si avertismentele jocului de la ultimul Play incoace
  python3 scripts/probe.py output [text]        tot ce a tiparit jocul de la ultimul Play (filtrat dupa text)
  python3 scripts/probe.py client <comanda>     report | frames | texts[:radacina] | overlaps[:radacina] | find:<Nume>
                                                ui:open:quests | ui:station:net:first_net | ui:crew:porter | ui:close
  python3 scripts/probe.py dev <comanda> ...    coins:500 | buyto:6 | fill | sell | state | ... (doar intr-un Play de proba)
  python3 scripts/probe.py report edit|server   raportul unei ferestre cu HTTP
"""
import glob
import json
import os
import re
import sys
import time

LOGS = os.path.expanduser("~/Library/Logs/Roblox")
CREATOR = re.compile(r"\[FLog::Creator(\w+)\]\s?(.*)$")
PROBE = re.compile(r"\[\[PROBE (\w+) (\d+)/(\d+)\]\](.*)$")
BOOT_MARK = "sonda incarcata (server)"


def log_path():
    files = glob.glob(os.path.join(LOGS, "*_Studio_*_last.log"))
    if not files:
        sys.exit("niciun jurnal Studio in " + LOGS)
    return max(files, key=os.path.getmtime)


def read_from(offset):
    with open(log_path(), "rb") as f:
        f.seek(offset)
        return f.read().decode("utf-8", "replace")


def log_size():
    return os.path.getsize(log_path())


def last_play_offset():
    """Pozitia din jurnal unde a pornit ultimul Play (dupa semnul de viata al sondei din partea de server)."""
    data = read_from(0)
    at = data.rfind(BOOT_MARK)
    if at < 0:
        at = data.rfind("server bootstrap complet")
    return max(0, data.rfind("\n", 0, at) + 1) if at >= 0 else 0


def creator_lines(text):
    out = []
    for line in text.splitlines():
        m = CREATOR.search(line)
        if m:
            out.append((m.group(1), m.group(2)))
    return out


def queue(role, *cmds):
    path = f"/tmp/driftwood_cmds_{role}.json"
    pending = []
    if os.path.exists(path):
        try:
            pending = json.load(open(path))
        except Exception:
            pending = []
    pending.extend(cmds)
    with open(path, "w") as f:
        json.dump(pending, f)


def wait_report(role, timeout=12.0):
    path = f"/tmp/driftwood_probe_{role}.json"
    if os.path.exists(path):
        os.remove(path)
    queue(role, "report")
    end = time.time() + timeout
    while time.time() < end:
        if os.path.exists(path) and os.path.getsize(path) > 0:
            time.sleep(0.2)
            return json.load(open(path))
        time.sleep(0.4)
    return None


def roundtrip(kind, cmd, timeout=20.0):
    """Trimite o comanda prin partea de server a Play-ului si asteapta raspunsul tiparit in jurnal.
    `kind`: "client" (o executa sonda din client) sau "dev" (o executa consola de dev a jocului, pe server)."""
    ident = "c%d" % int(time.time() * 1000 % 100000000)
    start = log_size()
    queue("server", f"{kind}:{ident}|{cmd}")
    end = time.time() + timeout
    while time.time() < end:
        parts, total = {}, None
        for kind, text in creator_lines(read_from(start)):
            m = PROBE.search(text)
            if m and m.group(1) == ident:
                parts[int(m.group(2))] = m.group(4)
                total = int(m.group(3))
        if total is not None and len(parts) == total:
            body = "".join(parts[i] for i in range(1, total + 1))
            try:
                return json.loads(body)
            except json.JSONDecodeError:
                return {"raw": body}
        time.sleep(0.5)
    return None


def client(cmd, timeout=20.0):
    return roundtrip("client", cmd, timeout)


def dev(cmd, timeout=20.0):
    reply = roundtrip("dev", cmd, timeout)
    if reply is None:
        return None
    return reply.get("reply") if reply.get("ok") else "EROARE: " + str(reply)


def wait_boot(timeout=90.0):
    start = log_size()
    end = time.time() + timeout
    seen_server = seen_client = False
    while time.time() < end:
        text = read_from(start)
        seen_server = seen_server or "server bootstrap complet" in text
        seen_client = seen_client or "sonda (client) asculta" in text
        if seen_server and seen_client:
            return True
        time.sleep(1.0)
    print(f"  (server pornit: {seen_server}, sonda clientului: {seen_client})")
    return False


def show_problems(only_errors=False):
    text = read_from(last_play_offset())
    rows = [(k, t) for k, t in creator_lines(text) if k in ("Error", "Warning") or t.startswith(("Error:", "Warning:"))]
    # Stiva vine ca linii "Output" imediat dupa eroare: le pastram langa ea
    out, keep = [], 0
    for kind, line in creator_lines(text):
        if kind == "Error" or line.startswith("Error:"):
            out.append("EROARE   " + line)
            keep = 6
        elif (kind == "Warning" or line.startswith("Warning:")) and not only_errors:
            out.append("AVERTISM " + line)
            keep = 0
        elif keep > 0 and ("Stack" in line or "Script '" in line or "Line" in line):
            out.append("         " + line)
            keep -= 1
        else:
            keep = 0
    del rows
    if not out:
        print("nicio eroare si niciun avertisment de la ultimul Play")
    for line in out[-80:]:
        print(line[:300])
    return len([x for x in out if x.startswith("EROARE")])


def main():
    args = sys.argv[1:]
    if not args or args[0] in ("-h", "--help"):
        print(__doc__)
        return
    verb = args[0]
    if verb == "play":
        queue("edit", "play")
        print("cerut: play")
    elif verb == "stop":
        queue("server", "stop")
        print("cerut: stop")
    elif verb == "wait-boot":
        ok = wait_boot(float(args[1]) if len(args) > 1 else 90.0)
        print("pornit" if ok else "NU a pornit in timpul dat")
        sys.exit(0 if ok else 1)
    elif verb == "errors":
        sys.exit(1 if show_problems() > 0 else 0)
    elif verb == "output":
        needle = args[1] if len(args) > 1 else ""
        for kind, line in creator_lines(read_from(last_play_offset())):
            if needle in line and "[[PROBE" not in line:
                print(f"{kind:8s}{line[:300]}")
    elif verb == "client":
        reply = client(args[1], float(args[2]) if len(args) > 2 else 20.0)
        if reply is None:
            sys.exit("niciun raspuns de la client (ruleaza un Play? e sonda noua instalata?)")
        print(json.dumps(reply, indent=1, ensure_ascii=False))
    elif verb == "dev":
        for cmd in args[1:]:
            print(f"{cmd} -> {dev(cmd)}")
    elif verb == "report":
        reply = wait_report(args[1] if len(args) > 1 else "edit")
        print(json.dumps(reply, indent=1, ensure_ascii=False) if reply else "niciun raspuns")
    else:
        sys.exit("comanda necunoscuta: " + verb)


if __name__ == "__main__":
    main()
