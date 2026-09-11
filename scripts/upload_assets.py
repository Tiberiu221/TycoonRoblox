#!/usr/bin/env python3
"""Urca imaginile din assets/sprites prin Open Cloud Assets API si scrie ID-urile in src/Shared/Config/Assets.luau.

Cheia API se citeste din ~/.driftwood_api_key (niciodata din argumente sau din repo).
Doc: https://create.roblox.com/docs/cloud/guides/usage-assets  [nota: sprites-assets]
Folosire: python3 scripts/upload_assets.py [nume_fara_extensie ...]   (fara argumente = toate PNG-urile fara prefix _)
"""
import json, os, re, sys, time, urllib.request, uuid

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SPRITES = os.path.join(ROOT, "assets", "sprites")
MANIFEST = os.path.join(ROOT, "src", "Shared", "Config", "Assets.luau")
KEY_FILE = os.path.expanduser("~/.driftwood_api_key")
API = "https://apis.roblox.com/assets/v1"

# numele PNG -> cheia din manifest (lazile in crate, cladirile in buildings)
def manifest_key(name):
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
    return name, False


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


def upload(key, name, path):
    boundary = uuid.uuid4().hex
    request = {
        "assetType": "Image",
        "displayName": name,
        "description": "Driftwood placeholder sprite",
        "creationContext": {"creator": creator()},
    }
    body = b""
    body += f"--{boundary}\r\nContent-Disposition: form-data; name=\"request\"\r\nContent-Type: application/json\r\n\r\n".encode() + json.dumps(request).encode() + b"\r\n"
    body += f"--{boundary}\r\nContent-Disposition: form-data; name=\"fileContent\"; filename=\"{name}.png\"\r\nContent-Type: image/png\r\n\r\n".encode() + open(path, "rb").read() + b"\r\n"
    body += f"--{boundary}--\r\n".encode()
    req = urllib.request.Request(f"{API}/assets", data=body, method="POST", headers={
        "x-api-key": key,
        "Content-Type": f"multipart/form-data; boundary={boundary}",
    })
    with urllib.request.urlopen(req, timeout=60) as r:
        op = json.load(r)
    op_path = op.get("path") or op.get("operationId")
    for _ in range(60):  # pana la ~2 minute per asset
        time.sleep(2)
        req = urllib.request.Request(f"{API}/{op_path}" if "/" in op_path else f"{API}/operations/{op_path}", headers={"x-api-key": key})
        with urllib.request.urlopen(req, timeout=30) as r:
            status = json.load(r)
        if status.get("done"):
            resp = status.get("response", {})
            if "assetId" in resp:
                return int(resp["assetId"]), resp.get("moderationResult", {}).get("moderationState", "?")
            sys.exit(f"{name}: operatia s-a terminat fara assetId: {status}")
    sys.exit(f"{name}: operatia nu s-a terminat in timp util ({op_path})")


def write_manifest(results):
    src = open(MANIFEST, encoding="utf-8").read()
    for name, asset_id in results.items():
        key, is_crate = manifest_key(name)
        pattern = rf"(?<![A-Za-z_])({key}) = sprite\(\d+, "
        src, n = re.subn(pattern, rf"\1 = sprite({asset_id}, ", src, count=1)
        if n != 1:
            print(f"  ! {name}: nu am gasit intrarea `{key}` in manifest, ID-ul {asset_id} trebuie pus manual")
    open(MANIFEST, "w", encoding="utf-8").write(src)


def main():
    key = api_key()
    names = sys.argv[1:] or sorted(f[:-4] for f in os.listdir(SPRITES) if f.endswith(".png") and not f.startswith("_"))
    results = {}
    for name in names:
        path = os.path.join(SPRITES, name + ".png")
        if not os.path.exists(path):
            print(f"  ! lipseste {path}")
            continue
        asset_id, state = upload(key, name, path)
        results[name] = asset_id
        print(f"  {name:18s} -> {asset_id}  ({state})")
    write_manifest(results)
    print(f"{len(results)} asset-uri scrise in {os.path.relpath(MANIFEST, ROOT)}")


if __name__ == "__main__":
    main()
