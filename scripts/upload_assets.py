#!/usr/bin/env python3
"""Urca imaginile din assets/sprites prin Open Cloud Assets API si scrie ID-urile in src/Shared/Config/Assets.luau.

Cheia API se citeste din ~/.driftwood_api_key (niciodata din argumente sau din repo).
Doc: https://create.roblox.com/docs/cloud/guides/usage-assets  [nota: sprites-assets]
Folosire: python3 scripts/upload_assets.py [nume_fara_extensie ...]   (fara argumente = toate PNG-urile fara prefix _)
          python3 scripts/upload_assets.py --audio [cheie ...]          (assets/audio/sfx_<cheie>.ogg -> Assets.sounds)
          python3 scripts/upload_assets.py --status nume ...            (starea moderarii pentru imagini deja urcate)
"""
import json, os, re, sys, time, urllib.error, urllib.request, uuid

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SPRITES = os.path.join(ROOT, "assets", "sprites")
MANIFEST = os.path.join(ROOT, "src", "Shared", "Config", "Assets.luau")
KEY_FILE = os.path.expanduser("~/.driftwood_api_key")
API = "https://apis.roblox.com/assets/v1"

# Coliziuni de prefix: doua fisiere diferite ar da aceeasi cheie dupa ce se taie prefixul, iar
# write_manifest scrie prima potrivire -- adica al doilea upload l-ar suprascrie pe primul in
# tacere. `prop_wheel` si `ui_wheel` sunt exact cazul asta (amandoua -> `wheel`).
OVERRIDE = {
    "ui_wheel": "wheel_face",
    # tinutele stau in Assets.people.outfit cu numele meseriei; clientii tavernei [D50]
    "outfit_townsfolk": "Townsfolk",
    "outfit_traveler": "Traveler",
    # [D55] foile in straturi stau in Assets.people cu cheia scurta (body.a, hair.short, outfit.Fisher)
    "body_a": "a",
    "body_b": "b",
    "hair_short": "short",
    "hair_long": "long",
    "hair_bun": "bun",
    "outfit_fisher": "Fisher",
    "outfit_crafter": "Crafter",
    "outfit_builder": "Builder",
    "outfit_gardener": "Gardener",
    "outfit_innkeeper": "Innkeeper",
    "outfit_keeper": "keeper",
    # [D56] linia fierului
    "outfit_scrapper": "Scrapper",
    "outfit_carter": "Carter",
    "outfit_smith": "Smith",
    "outfit_ironmonger": "Ironmonger",
    # [D65] oamenii Morii
    "outfit_gleaner": "Gleaner",
    "outfit_drayman": "Drayman",
    "outfit_founder": "Founder",
    "outfit_wheelwright": "Wheelwright",
    "outfit_merchant": "Merchant",
    "outfit_prospector": "Prospector",
    "outfit_mucker": "Mucker",
    "outfit_coppersmith": "Coppersmith",
    "outfit_teamster": "Teamster",
    # [D67] oamenii Wire Works
    "outfit_dredger": "Dredger",
    "outfit_barrowman": "Barrowman",
    "outfit_wiredrawer": "Wiredrawer",
    "outfit_coiler": "Coiler",
    "outfit_clerk": "Clerk",
    "outfit_lineman": "Lineman",
    "outfit_hodman": "Hodman",
    "outfit_electrician": "Electrician",
    "outfit_freighter": "Freighter",
    # [D59] tinutele jucatorului (cheile cu litera mica, ca keeper) si fata roatii din panou (prop_helm -> helm)
    "outfit_angler": "angler",
    "outfit_captain": "captain",
    "outfit_legend": "legend",
    # [D61, partea 2] tinutele croitoresei (`lampkeeper`, nu `lantern`: felinarul de decor are deja cheia aceea)
    "outfit_festival": "festival",
    "outfit_minstrel": "minstrel",
    "outfit_lampkeeper": "lampkeeper",
    "outfit_harvest": "harvest",
    "outfit_supporter": "supporter",  # vine cu pass-ul Supporter
    # [D75, lotul A4] oamenii barajului
    "outfit_turbineer": "Turbineer",
    "outfit_lugger": "Lugger",
    "outfit_switchman": "Switchman",
    "outfit_cooper": "Cooper",
    "outfit_dispatcher": "Dispatcher",
    "outfit_spooler": "Spooler",
    "outfit_packer": "Packer",
    "outfit_cablemaker": "Cablemaker",
    "outfit_reeler": "Reeler",
    "outfit_relayman": "Relayman",
    "outfit_linewalker": "Linewalker",
    "outfit_gemfinder": "Gemfinder",
    "outfit_bearer": "Bearer",
    "outfit_crystalsmith": "Crystalsmith",
    "outfit_bullioner": "Bullioner",
    "ui_helm": "helm_face",
}


# numele PNG -> cheia din manifest (lazile in crate, cladirile in buildings)
def manifest_key(name):
    if name in OVERRIDE:
        return OVERRIDE[name], True
    m = re.match(r"crate_(\w+)$", name)
    if m:
        return m.group(1), True
    m = re.match(r"b_(\w+)$", name)
    if m:
        return m.group(1), True
    m = re.match(r"prop_(\w+)$", name)
    if m:
        return m.group(1), True
    m = re.match(r"ui_(\w+)$", name)
    if m:
        return m.group(1), True
    m = re.match(r"icon_(\w+)$", name)
    if m:
        return m.group(1), True
    m = re.match(r"goods_(\w+)$", name)
    if m:
        return m.group(1), True
    m = re.match(r"chapter_(\w+)$", name)
    if m:
        return m.group(1), True
    # [D59] pestii jurnalului, ce aduce raul, decorul satului: fiecare in tabelul lui din Assets, cheia fara prefix
    m = re.match(r"(?:fish|treasure|decor)_(\w+)$", name)
    if m:
        return m.group(1), True
    return name, False


# [D60] Cheie cu tabel ("fair.bench"): balciul are chei care exista si in alte tabele (bench, barrel, crate, table),
# iar write_manifest scrie PRIMA potrivire din fisier -- fara tabel, ID-ul balciului ar fi ajuns peste decorul satului.
# [D76, lotul A4] Marfa in tabelul `goods`: `goods_barrel` ar fi dat peste `props.barrel` (butoiul de decor, primul din fisier).
def table_key(name):
    m = re.match(r"prop_fair_(\w+)$", name)
    if m:
        return f"fair.{m.group(1)}"
    m = re.match(r"goods_(\w+)$", name)
    return f"goods.{m.group(1)}" if m else None


def api_key():
    try:
        key = open(KEY_FILE).read().strip()
    except FileNotFoundError:
        sys.exit(f"Lipseste {KEY_FILE}. Creeaza cheia in Creator Hub (Assets API: asset:read, asset:write) si salveaz-o acolo.")
    if not key:
        sys.exit("Fisierul cu cheia e gol.")
    return key


def creator():
    cfg = open(os.path.join(ROOT, "assets", "asphalt.toml")).read()
    ctype = re.search(r'type\s*=\s*"(\w+)"', cfg).group(1)
    cid = int(re.search(r"id\s*=\s*(\d+)", cfg).group(1))
    if cid == 0:
        sys.exit("Completeaza creator.id in assets/asphalt.toml (userId sau groupId) inainte de upload.")
    return {"userId": str(cid)} if ctype == "user" else {"groupId": str(cid)}


def upload(key, name, path, asset_type="Image", content_type="image/png", ext="png"):
    boundary = uuid.uuid4().hex
    request = {
        "assetType": asset_type,
        "displayName": name,
        "description": "Driftycoon " + (
            ("music" if name.startswith("music_") else "sound effect") if asset_type == "Audio" else "sprite"
        ),
        "creationContext": {"creator": creator()},
    }
    body = b""
    body += f"--{boundary}\r\nContent-Disposition: form-data; name=\"request\"\r\nContent-Type: application/json\r\n\r\n".encode() + json.dumps(request).encode() + b"\r\n"
    body += f"--{boundary}\r\nContent-Disposition: form-data; name=\"fileContent\"; filename=\"{name}.{ext}\"\r\nContent-Type: {content_type}\r\n\r\n".encode() + open(path, "rb").read() + b"\r\n"
    body += f"--{boundary}--\r\n".encode()
    req = urllib.request.Request(f"{API}/assets", data=body, method="POST", headers={
        "x-api-key": key,
        "Content-Type": f"multipart/form-data; boundary={boundary}",
    })
    # Open Cloud intoarce uneori 500 trecator (vazut la primul upload audio, 2026-09-11):
    # reincercam de cateva ori inainte sa renuntam; erorile 4xx raman fatale imediat.
    for attempt in range(4):
        try:
            with urllib.request.urlopen(req, timeout=60) as r:
                op = json.load(r)
            break
        except urllib.error.HTTPError as e:
            if e.code < 500 or attempt == 3:
                raise
            time.sleep(3 * (attempt + 1))
    op_path = op.get("path") or op.get("operationId")
    for _ in range(60):  # pana la ~2 minute per asset
        time.sleep(2)
        req = urllib.request.Request(f"{API}/{op_path}" if "/" in op_path else f"{API}/operations/{op_path}", headers={"x-api-key": key})
        # Interogarea operatiei NU avea reincercare: un singur `SSLEOFError` trecator omora toata
        # rularea, iar asset-urile deja urcate ramaneau orfane pe Roblox (fara ID scris nicaieri).
        # Vazut pe 2026-09-12, la jumatatea unui lot de 16.
        status = None
        for attempt in range(4):
            try:
                with urllib.request.urlopen(req, timeout=30) as r:
                    status = json.load(r)
                break
            except (urllib.error.URLError, TimeoutError, OSError) as e:
                if attempt == 3:
                    raise
                print(f"    {name}: interogare esuata ({type(e).__name__}), reincerc")
                time.sleep(3 * (attempt + 1))
        if status.get("done"):
            resp = status.get("response", {})
            if "assetId" in resp:
                return int(resp["assetId"]), resp.get("moderationResult", {}).get("moderationState", "?")
            sys.exit(f"{name}: operatia s-a terminat fara assetId: {status}")
    sys.exit(f"{name}: operatia nu s-a terminat in timp util ({op_path})")


def manifest_id(name):
    """ID-ul scris in manifest pentru un PNG, prin aceeasi mapare ca la scriere (tabelul lui, apoi cheia)."""
    src = open(MANIFEST, encoding="utf-8").read()
    scoped = table_key(name)
    if scoped is not None:
        table, field = scoped.split(".", 1)
        m = re.search(rf"(?ms)^    {re.escape(table)} = \{{.*?^    \}},", src)
        src = m.group(0) if m else ""
        key = field
    else:
        key, _ = manifest_key(name)
    m = re.search(rf"(?<![A-Za-z_]){re.escape(key)} = sprite\((\d+),", src)
    return int(m.group(1)) if m else 0


def main_status(key, names):
    """Starea moderarii: o imagine respinsa ramane cu ID in manifest, dar in joc se vede goala -- iar jocul n-are cum
    sa stie. Dupa o urcare, asta e singurul fel de a afla fara Creator Hub."""
    pending = 0
    for name in names:
        asset_id = manifest_id(name)
        if asset_id == 0:
            print(f"  {name:24s} -> fara ID in manifest")
            continue
        req = urllib.request.Request(f"{API}/assets/{asset_id}?readMask=moderationResult", headers={"x-api-key": key})
        try:
            with urllib.request.urlopen(req, timeout=30) as r:
                data = json.load(r)
            state = data.get("moderationResult", {}).get("moderationState", "?")
        except urllib.error.HTTPError as e:
            state = f"HTTP {e.code}"
        if state != "Approved":
            pending += 1
        print(f"  {name:24s} -> {asset_id}  ({state})")
    print(f"{len(names) - pending} din {len(names)} aprobate")


def png_size(path):
    # latimea si inaltimea stau in antetul IHDR, octetii 16..24 (big-endian)
    with open(path, "rb") as f:
        head = f.read(24)
    return int.from_bytes(head[16:20], "big"), int.from_bytes(head[20:24], "big")


def replace_in_table(src, table, field, asset_id, size):
    """Scrie ID-ul doar in tabelul cerut din manifest, nu la prima potrivire din fisier."""
    m = re.search(rf"(?ms)^    {re.escape(table)} = \{{.*?^    \}},", src)
    if m is None:
        return src, 0
    block = m.group(0)
    if size:
        w, h = size
        pattern = rf"(?<![A-Za-z_])({re.escape(field)}) = sprite\(\d+, \d+, \d+\)"
        new, n = re.subn(pattern, rf"\1 = sprite({asset_id}, {w}, {h})", block, count=1)
    else:
        pattern = rf"(?<![A-Za-z_])({re.escape(field)}) = sprite\(\d+, "
        new, n = re.subn(pattern, rf"\1 = sprite({asset_id}, ", block, count=1)
    return src[: m.start()] + new + src[m.end() :], n


def write_manifest(results, sizes=None):
    src = open(MANIFEST, encoding="utf-8").read()
    for name, asset_id in results.items():
        scoped = table_key(name)
        if scoped is not None:
            table, field = scoped.split(".", 1)
            src, n = replace_in_table(src, table, field, asset_id, sizes.get(name) if sizes else None)
            if n != 1:
                print(f"  ! {name}: nu am gasit `{field}` in tabelul `{table}`, ID-ul {asset_id} trebuie pus manual")
            continue
        key, is_crate = manifest_key(name)
        if sizes and name in sizes:
            w, h = sizes[name]
            pattern = rf"(?<![A-Za-z_])({key}) = sprite\(\d+, \d+, \d+\)"
            src, n = re.subn(pattern, rf"\1 = sprite({asset_id}, {w}, {h})", src, count=1)
        else:
            pattern = rf"(?<![A-Za-z_])({key}) = sprite\(\d+, "
            src, n = re.subn(pattern, rf"\1 = sprite({asset_id}, ", src, count=1)
        if n != 1:
            print(f"  ! {name}: nu am gasit intrarea `{key}` in manifest, ID-ul {asset_id} trebuie pus manual")
    open(MANIFEST, "w", encoding="utf-8").write(src)


AUDIO = os.path.join(ROOT, "assets", "audio")


def write_sound_manifest(results):
    # sunetele stau in tabelul `sounds` ca numere simple: `splash = 0,` -> `splash = <id>,`
    src = open(MANIFEST, encoding="utf-8").read()
    for key, asset_id in results.items():
        pattern = rf"(?<![A-Za-z_])({key}) = \d+,"
        src, n = re.subn(pattern, rf"\1 = {asset_id},", src, count=1)
        if n != 1:
            print(f"  ! sunetul {key}: nu am gasit intrarea in manifest, ID-ul {asset_id} trebuie pus manual")
    open(MANIFEST, "w", encoding="utf-8").write(src)


def audio_file(name):
    # "splash" -> sfx_splash.ogg (Assets.sounds.splash); "music_river" -> music_river.ogg
    # (Assets.music.river) [D51]. Cheia din manifest e ce ramane dupa prefix.
    if name.startswith("music_"):
        return name, name[len("music_"):]
    return f"sfx_{name}", name


def main_audio(key, names):
    # fara nume: toate efectele sfx_<cheie>.ogg; muzica se urca doar numita explicit
    files = names or sorted(f[4:-4] for f in os.listdir(AUDIO) if f.startswith("sfx_") and f.endswith(".ogg"))
    results = {}
    for name in files:
        stem, manifest = audio_file(name)
        path = os.path.join(AUDIO, f"{stem}.ogg")
        if not os.path.exists(path):
            print(f"  ! lipseste {path}")
            continue
        asset_id, state = upload(key, stem, path, "Audio", "audio/ogg", "ogg")
        results[manifest] = asset_id
        print(f"  {stem:18s} -> {asset_id}  ({state})")
    write_sound_manifest(results)
    print(f"{len(results)} sunete scrise in {os.path.relpath(MANIFEST, ROOT)}")


def main():
    key = api_key()
    if sys.argv[1:2] == ["--audio"]:
        main_audio(key, sys.argv[2:])
        return
    if sys.argv[1:2] == ["--status"]:
        main_status(key, sys.argv[2:])
        return
    names = sys.argv[1:] or sorted(f[:-4] for f in os.listdir(SPRITES) if f.endswith(".png") and not f.startswith("_"))
    results = {}
    sizes = {}
    try:
        for name in names:
            path = os.path.join(SPRITES, name + ".png")
            if not os.path.exists(path):
                print(f"  ! lipseste {path}")
                continue
            asset_id, state = upload(key, name, path)
            results[name] = asset_id
            sizes[name] = png_size(path)
            print(f"  {name:18s} -> {asset_id}  ({state})")
    finally:
        # SI pe drumul cu eroare: un asset urcat pentru care nu scriem ID-ul e pierdut definitiv
        # (reluarea creeaza un duplicat). Scrie ce s-a obtinut, apoi lasa exceptia sa iasa.
        if results:
            write_manifest(results, sizes)
            print(f"{len(results)} asset-uri scrise in {os.path.relpath(MANIFEST, ROOT)}")


if __name__ == "__main__":
    main()
