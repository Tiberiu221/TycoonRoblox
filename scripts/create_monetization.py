#!/usr/bin/env python3
"""Creeaza pass-urile si produsele din coltul cu Robux prin Open Cloud si le scrie ID-urile in MonetizationConfig.luau.

Catalogul (nume, descriere, pret de pornire) se citeste din src/Shared/Config/MonetizationConfig.luau, iar iconita de
512x512 din assets/store/<cheie>_512.png (scripts/art/d63_shop_icons.py --hub). Cheia API se citeste din
~/.driftwood_api_key (niciodata din argumente sau din repo) si are nevoie de `game-pass` si `developer-product`, cu
citire si scriere.

Nu face dubluri: intai LISTEAZA ce exista pe univers si, pentru un lucru cu acelasi nume, doar ii ia ID-ul. Forma
cererilor e cea din specificatia publicata de Roblox (creator-docs, reference/cloud/game-passes-http-service/v1.json si
developer-products-api/v1.json): multipart/form-data cu `name`, `description`, `price`, `isForSale`, `imageFile`.

Preturile de aici sunt doar punctul de pornire: jocul afiseaza pretul citit de la Roblox, deci owner-ul il schimba oricand
din Creator Hub.

Folosire: python3 scripts/create_monetization.py [--universe staging|production] [--dry-run]
          python3 scripts/create_monetization.py --update <cheie> [--universe ...] [--dry-run]
              [D66] rescrie DOAR descrierea unui pass deja creat, din `blurb`-ul lui din MonetizationConfig (PATCH
              game-passes/v1/universes/{u}/game-passes/{id}, campul `description`, dreptul `game-pass:write`)
"""
import json
import os
import re
import sys
import urllib.error
import urllib.request
import uuid

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
CONFIG = os.path.join(ROOT, "src", "Shared", "Config", "MonetizationConfig.luau")
STORE = os.path.join(ROOT, "assets", "store")
KEY_FILE = os.path.expanduser("~/.driftwood_api_key")
API = "https://apis.roblox.com"
UNIVERSES = {"staging": 10765888327, "production": 10766553412}


def api_key():
    try:
        key = open(KEY_FILE).read().strip()
    except FileNotFoundError:
        sys.exit(f"Lipseste {KEY_FILE}.")
    if not key:
        sys.exit(f"{KEY_FILE} e gol.")
    return key


def read_items():
    src = open(CONFIG, encoding="utf-8").read()
    items = []
    for block in re.findall(r"\{\s*key = \"(\w+)\",(.*?)\n    \},", src, re.S):
        key, body = block
        def field(name, body=body):
            m = re.search(rf'{name} = "([^"]*)"', body)
            return m.group(1) if m else None
        price = re.search(r"suggested = (\d+)", body)
        items.append({"key": key, "kind": field("kind"), "name": field("name"), "blurb": field("blurb"),
                      "price": int(price.group(1)) if price else None})
    if len(items) < 1:
        sys.exit("n-am gasit niciun lucru in MonetizationConfig.ITEMS")
    return items


def request(key, method, url, fields=None, file_path=None):
    headers = {"x-api-key": key}
    data = None
    if fields is not None:
        boundary = uuid.uuid4().hex
        parts = []
        for name, value in fields.items():
            parts.append(f'--{boundary}\r\nContent-Disposition: form-data; name="{name}"\r\n\r\n{value}\r\n'.encode())
        if file_path is not None:
            blob = open(file_path, "rb").read()
            parts.append(
                (f'--{boundary}\r\nContent-Disposition: form-data; name="imageFile"; filename="{os.path.basename(file_path)}"\r\n'
                 "Content-Type: image/png\r\n\r\n").encode() + blob + b"\r\n"
            )
        parts.append(f"--{boundary}--\r\n".encode())
        data = b"".join(parts)
        headers["Content-Type"] = f"multipart/form-data; boundary={boundary}"
    req = urllib.request.Request(url, data=data, method=method, headers=headers)
    try:
        with urllib.request.urlopen(req, timeout=60) as r:
            raw = r.read()
            return r.status, (json.loads(raw) if raw.strip() else {})
    except urllib.error.HTTPError as e:
        body = e.read().decode("utf-8", "replace")
        try:
            return e.code, json.loads(body)
        except json.JSONDecodeError:
            return e.code, {"raw": body[:400]}


def list_existing(key, universe, kind):
    """Numele -> ID, pentru tot ce exista deja pe univers (toate paginile)."""
    base = (f"{API}/game-passes/v1/universes/{universe}/game-passes/creator" if kind == "pass"
            else f"{API}/developer-products/v2/universes/{universe}/developer-products/creator")
    found, token = {}, ""
    for _ in range(20):
        url = base + (f"?pageToken={token}" if token else "")
        status, body = request(key, "GET", url)
        if status != 200:
            sys.exit(f"listarea ({kind}) a raspuns {status}: {body}")
        rows = body.get("gamePasses") if kind == "pass" else body.get("developerProducts")
        for row in rows or []:
            found[row.get("name")] = row.get("gamePassId") if kind == "pass" else row.get("productId")
        token = body.get("nextPageToken") or ""
        if not token:
            break
    return found


def create(key, universe, item):
    url = (f"{API}/game-passes/v1/universes/{universe}/game-passes" if item["kind"] == "pass"
           else f"{API}/developer-products/v2/universes/{universe}/developer-products")
    icon = os.path.join(STORE, f"{item['key']}_512.png")
    fields = {"name": item["name"], "description": item["blurb"], "price": str(item["price"]), "isForSale": "true"}
    status, body = request(key, "POST", url, fields, icon if os.path.exists(icon) else None)
    if status != 200:
        sys.exit(f"crearea lui {item['name']} a raspuns {status}: {body}")
    return body.get("gamePassId") if item["kind"] == "pass" else body.get("productId")


def read_id(universe, item_key):
    """ID-ul unui lucru deja creat, din randul universului din MonetizationConfig.IDS (0 = inca necreat)."""
    src = open(CONFIG, encoding="utf-8").read()
    m = re.search(rf"\[{universe}\] = \{{([^}}]*)\}}", src)
    found = re.search(rf"\b{item_key} = (\d+)", m.group(1)) if m else None
    return int(found.group(1)) if found else 0


def update_description(key, universe, item, dry):
    """[D66] Descrierea unui pass, rescrisa din `blurb` (Roblox o arata pe pagina pass-ului)."""
    if item["kind"] != "pass":
        sys.exit(f"{item['key']}: doar pass-urile se actualizeaza de aici")
    pass_id = read_id(universe, item["key"])
    if pass_id == 0:
        sys.exit(f"{item['key']}: n-are ID pe universul {universe}; intai creeaza-l")
    if dry:
        print(f"  AR SCHIMBA descrierea lui {item['name']} ({pass_id}) in: {item['blurb']}")
        return
    url = f"{API}/game-passes/v1/universes/{universe}/game-passes/{pass_id}"
    status, body = request(key, "PATCH", url, {"description": item["blurb"]})
    if status not in (200, 204):
        sys.exit(f"actualizarea lui {item['name']} a raspuns {status}: {body}")
    status, now = request(key, "GET", url + "/creator")
    shown = now.get("description") if status == 200 else None
    print(f"  descrierea lui {item['name']} ({pass_id}): {shown!r}")
    if shown is not None and shown != item["blurb"]:
        sys.exit("  ! Roblox arata alta descriere decat cea trimisa")


def write_ids(universe, ids):
    src = open(CONFIG, encoding="utf-8").read()
    m = re.search(rf"\[{universe}\] = \{{([^}}]*)\}}", src)
    if m is None:
        sys.exit(f"n-am gasit randul universului {universe} in MonetizationConfig.IDS")
    row = m.group(1)
    for k, v in ids.items():
        row, n = re.subn(rf"\b{k} = \d+", f"{k} = {v}", row)
        if n != 1:
            sys.exit(f"cheia {k} nu e in randul universului {universe}")
    src = src[: m.start(1)] + row + src[m.end(1) :]
    open(CONFIG, "w", encoding="utf-8").write(src)


def main():
    args = sys.argv[1:]
    which = args[args.index("--universe") + 1] if "--universe" in args else "staging"
    universe = UNIVERSES.get(which)
    if universe is None:
        sys.exit("--universe staging|production")
    dry = "--dry-run" in args
    key = api_key()
    items = read_items()
    if "--update" in args:
        wanted = args[args.index("--update") + 1]
        item = next((i for i in items if i["key"] == wanted), None)
        if item is None:
            sys.exit(f"nu exista `{wanted}` in MonetizationConfig.ITEMS")
        update_description(key, universe, item, dry)
        return
    existing = {"pass": list_existing(key, universe, "pass"), "product": list_existing(key, universe, "product")}
    ids = {}
    for item in items:
        have = existing[item["kind"]].get(item["name"])
        if have:
            print(f"  exista deja  {item['kind']:8s} {item['name']:18s} -> {have}")
            ids[item["key"]] = have
        elif dry:
            print(f"  AR CREA      {item['kind']:8s} {item['name']:18s} {item['price']:>4} R$  | {item['blurb']}")
        else:
            new_id = create(key, universe, item)
            print(f"  creat        {item['kind']:8s} {item['name']:18s} {item['price']:>4} R$ -> {new_id}")
            ids[item["key"]] = new_id
    if ids and not dry:
        write_ids(universe, ids)
        print(f"{len(ids)} ID-uri scrise in {os.path.relpath(CONFIG, ROOT)} (universul {which})")


if __name__ == "__main__":
    main()
