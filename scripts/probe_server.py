#!/usr/bin/env python3
"""Capatul care asculta raportul plugin-ului din Studio si ii tine cozile de comenzi.

DE CE EXISTA: nu pot vedea Studio. Un screenshot ar costa mult si oricum nu-mi spune daca un
font s-a rezolvat sau daca un controller a crapat la bootstrap. Plugin-ul citeste arborele real
de interfata din sesiunea care ruleaza si il trimite aici, ca text. Ieftin si exact.

[2026-09-19] COZI PE ROL. Pana acum era o singura coada, luata de cine intreba primul: editorul, serverul de joc si podul
de dev (DevBridge) isi furau comenzile unul altuia. Acum fiecare are coada lui:
  edit    -- plugin-ul din fereastra de editare: porneste Play (`play`), raporteaza
  server  -- plugin-ul din partea de server a unui Play: opreste testul (`stop`), transmite comenzi clientului
             (`client:<comanda>`), raporteaza erorile serverului
  bridge  -- DevBridge din joc: comenzile consolei de dev (`coins:500`, `buyto:6`, ...). E si coada implicita, pentru
             cine intreaba fara `who`.
Clientul unui Play nu are voie la HTTP: raspunsurile lui vin tiparite in jurnalul Studio (vezi scripts/probe.py).

Pornire:  python3 scripts/probe_server.py
Rapoartele se scriu in /tmp/driftwood_probe_<rol>.json (si, ca inainte, in /tmp/driftwood_probe.json).
"""
import datetime
import http.server
import json
import os
import sys
import time
import urllib.parse

PORT = int(os.environ.get("DRIFTWOOD_PROBE_PORT", "8787"))
OUT = "/tmp/driftwood_probe.json"
ROLES = ("edit", "server", "bridge")
PROBE_FLAG = "/tmp/driftwood_probe_run"


def queue_path(role):
    return f"/tmp/driftwood_cmds_{role}.json"


class Handler(http.server.BaseHTTPRequestHandler):
    def _cors(self):
        self.send_header("Access-Control-Allow-Origin", "*")
        self.send_header("Access-Control-Allow-Headers", "*")
        self.send_header("Access-Control-Allow-Methods", "POST, OPTIONS")

    def _role(self):
        query = urllib.parse.urlparse(self.path).query
        role = urllib.parse.parse_qs(query).get("who", ["bridge"])[0]
        return role if role in ROLES else "bridge"

    def do_GET(self):
        # [2026-09-19] "E Play de proba?": partea de server a unui Play intreaba asta chiar la incarcare. Da doar daca
        # `probe.py play` a cerut un Play in ultimele doua minute (steagul se sterge dupa pornire), ca un Play apasat de
        # owner sa nu ajunga niciodata pe profilul de proba.
        if urllib.parse.urlparse(self.path).path == "/proberun":
            fresh = os.path.exists(PROBE_FLAG) and time.time() - os.path.getmtime(PROBE_FLAG) < 120
            body = b"1" if fresh else b"0"
            self.send_response(200)
            self._cors()
            self.send_header("Content-Type", "text/plain")
            self.send_header("Content-Length", str(len(body)))
            self.end_headers()
            self.wfile.write(body)
            return
        if urllib.parse.urlparse(self.path).path != "/cmd":
            self.send_response(404)
            self._cors()
            self.end_headers()
            return
        role = self._role()
        path = queue_path(role)
        payload = "[]"
        if os.path.exists(path):
            with open(path, encoding="utf-8") as f:
                payload = f.read().strip() or "[]"
            os.remove(path)
        if payload != "[]":
            print(f"-> comenzi pentru {role}: {payload}")
            sys.stdout.flush()
        body = payload.encode("utf-8")
        self.send_response(200)
        self._cors()
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)

    def do_OPTIONS(self):
        self.send_response(200)
        self._cors()
        self.end_headers()

    def do_POST(self):
        role = self._role()
        length = int(self.headers.get("Content-Length", "0"))
        raw = self.rfile.read(length).decode("utf-8", "replace")
        stamp = datetime.datetime.now().strftime("%H:%M:%S")
        try:
            data = json.loads(raw)
            pretty = json.dumps(data, indent=2, ensure_ascii=False)
        except json.JSONDecodeError:
            pretty = raw  # tot il pastram: un raport stricat spune si el ceva
        for path in (OUT, f"/tmp/driftwood_probe_{role}.json"):
            with open(path, "w", encoding="utf-8") as f:
                f.write(pretty)
        print(f"\n===== raport {stamp} ({role}) =====")
        print(pretty[:1500])
        sys.stdout.flush()
        self.send_response(200)
        self._cors()
        self.send_header("Content-Type", "text/plain")
        self.end_headers()
        self.wfile.write(b"ok")

    def log_message(self, fmt, *args):
        pass  # jurnalul implicit al bibliotecii ar ineca raportul


if __name__ == "__main__":
    print(f"ascult pe http://127.0.0.1:{PORT}/report  (Ctrl+C ca sa opresti)")
    sys.stdout.flush()
    http.server.HTTPServer(("127.0.0.1", PORT), Handler).serve_forever()
