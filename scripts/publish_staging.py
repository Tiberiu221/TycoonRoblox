#!/usr/bin/env python3
"""Publica satul si balciul pe staging, de pe Mac, dupa poarta intreaga.

DE CE EXISTA (2026-09-17): CI-ul publica la fiecare push (scripts/ci_publish.sh), dar pana azi publicarea satului a
picat de fiecare data cu 409, pentru ca satul era deschis in Studio (editare colaborativa). Scriptul asta e varianta de
pe Mac, pentru cand trebuie publicat fara un push: aceeasi poarta, aceleasi reincercari. Cere o cheie care are doar
dreptul de publicare (`universe-places`, Write) si verifica rezultatul in `updateTime`.

Cheile se citesc din fisiere si nu se afiseaza niciodata:
  ~/.driftwood_publish_key   publicarea (universe-places: write, experienta Driftycoon (Staging))
  ~/.driftwood_api_key       citirea place-urilor, pentru verificare

Folosire:  python3 scripts/publish_staging.py            (poarta, build, publicare, verificare)
           python3 scripts/publish_staging.py --only fair
Refuza sa publice cod necomis: pe staging ajunge doar ce e in git.
"""
import json
import os
import subprocess
import sys
import tempfile
import time
import urllib.error
import urllib.request

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
PUBLISH_KEY = os.path.expanduser("~/.driftwood_publish_key")
READ_KEY = os.path.expanduser("~/.driftwood_api_key")
UNIVERSE = 10765888327  # Driftycoon (Staging); aceleasi id-uri ca in src/Shared/Config/PlaceConfig.luau
PLACES = {
    "village": {"place": 132381101591529, "project": "default.project.json", "file": "Driftwood.rbxl"},
    "fair": {"place": 114983498774894, "project": "fair.project.json", "file": "DriftwoodFair.rbxl"},
}

GATE = [
    ["stylua", "--check", "src/", "tests/"],
    ["selene", "src/"],
    ["lune", "run", "tests/_run.luau"],
    ["python3", "scripts/economy/sim_tycoon.py", "--robust"],
    ["python3", "scripts/art/check_panel_rows.py"],
    ["python3", "scripts/art/village_ground.py", "--check"],
]


def read_key(path):
    with open(path, encoding="utf-8") as f:
        return f.read().strip()


def run(cmd, what):
    r = subprocess.run(cmd, cwd=ROOT, capture_output=True, text=True)
    if r.returncode != 0:
        tail = (r.stdout + r.stderr).strip().splitlines()[-15:]
        print(f"PICAT: {what}\n  " + "\n  ".join(tail))
        sys.exit(1)
    print(f"ok  {what}")


def update_time(place, key):
    req = urllib.request.Request(
        f"https://apis.roblox.com/cloud/v2/universes/{UNIVERSE}/places/{place}", headers={"x-api-key": key}
    )
    try:
        with urllib.request.urlopen(req, timeout=30) as r:
            return json.load(r).get("updateTime")
    except urllib.error.HTTPError as e:
        return f"(citire esuata: HTTP {e.code})"


# 409 "Server is busy": place-ul e deschis in Studio (editare colaborativa), iar Roblox nu primeste publicarea cat
# sesiunea traieste -- inca cateva minute dupa ce se inchide Studio (raspunsul Roblox de pe forum, 2026-09-17).
BUSY_WAITS = (0, 30, 60, 90)


def publish(place, path, key):
    with open(path, "rb") as f:
        body = f.read()
    for wait in BUSY_WAITS:
        time.sleep(wait)
        req = urllib.request.Request(
            f"https://apis.roblox.com/universes/v1/{UNIVERSE}/places/{place}/versions?versionType=Published",
            data=body,
            headers={"x-api-key": key, "Content-Type": "application/octet-stream"},
            method="POST",
        )
        try:
            with urllib.request.urlopen(req, timeout=120) as r:
                return json.load(r).get("versionNumber")
        except urllib.error.HTTPError as e:
            detail = e.read()[:300].decode("utf-8", "replace")
            if e.code == 409:
                print(f"  409, reincerc: {detail}")
                continue
            print(f"PICAT: publicarea place-ului {place}: HTTP {e.code} {detail}")
            sys.exit(1)
    print(f"PICAT: place-ul {place} e deschis in Studio (sesiune colaborativa). Inchide-l, asteapta cateva minute, reia.")
    sys.exit(1)


def main():
    only = None
    if "--only" in sys.argv:
        only = sys.argv[sys.argv.index("--only") + 1]
        if only not in PLACES:
            sys.exit(f"--only primeste unul din: {', '.join(PLACES)}")
    if not os.path.exists(PUBLISH_KEY):
        sys.exit(
            f"Lipseste {PUBLISH_KEY}: cheia de publicare (universe-places, Write, Driftycoon (Staging)).\n"
            "Se pune o singura data: copiezi cheia din Creator Hub, apoi `pbpaste > ~/.driftwood_publish_key`."
        )
    dirty = subprocess.run(["git", "status", "--porcelain"], cwd=ROOT, capture_output=True, text=True).stdout.strip()
    if dirty:
        sys.exit("Cod necomis in lucru: fa intai commit (pe staging ajunge doar ce e in git).")
    sha = subprocess.run(["git", "rev-parse", "--short", "HEAD"], cwd=ROOT, capture_output=True, text=True).stdout
    print(f"commit {sha.strip()}")

    for cmd in GATE:
        run(cmd, " ".join(cmd))
    out = tempfile.mkdtemp(prefix="driftwood_publish_")
    targets = {name: spec for name, spec in PLACES.items() if only in (None, name)}
    for name, spec in targets.items():
        path = os.path.join(out, spec["file"])
        run(["rojo", "build", spec["project"], "--output", path], f"rojo build {spec['project']}")
        run(["lune", "run", "scripts/check_requires", path], f"check_requires {name}")

    publish_key, read_key_value = read_key(PUBLISH_KEY), read_key(READ_KEY)
    for name, spec in targets.items():
        before = update_time(spec["place"], read_key_value)
        version = publish(spec["place"], os.path.join(out, spec["file"]), publish_key)
        after = before
        for _ in range(10):  # updateTime se misca la cateva secunde dupa raspuns
            after = update_time(spec["place"], read_key_value)
            if after != before:
                break
            time.sleep(3)
        state = "actualizat" if after != before else "NESCHIMBAT (de verificat)"
        print(f"{name}: versiunea {version} publicata; updateTime {before} -> {after} [{state}]")


if __name__ == "__main__":
    main()
