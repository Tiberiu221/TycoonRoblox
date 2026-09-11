#!/usr/bin/env python3
"""Capatul care asculta raportul plugin-ului din Studio.

DE CE EXISTA: nu pot vedea Studio. Un screenshot ar costa mult si oricum nu-mi spune daca un
font s-a rezolvat sau daca un controller a crapat la bootstrap. Plugin-ul citeste arborele real
de interfata din sesiunea care ruleaza si il trimite aici, ca text. Ieftin si exact.

Pornire:  python3 scripts/probe_server.py
Raportul se scrie in /tmp/driftwood_probe.json si se afiseaza pe stdout.
"""
import http.server
import json
import os
import sys
import datetime

PORT = int(os.environ.get("DRIFTWOOD_PROBE_PORT", "8787"))
OUT = "/tmp/driftwood_probe.json"


class Handler(http.server.BaseHTTPRequestHandler):
    def _cors(self):
        self.send_header("Access-Control-Allow-Origin", "*")
        self.send_header("Access-Control-Allow-Headers", "*")
        self.send_header("Access-Control-Allow-Methods", "POST, OPTIONS")

    def do_OPTIONS(self):
        self.send_response(200)
        self._cors()
        self.end_headers()

    def do_POST(self):
        length = int(self.headers.get("Content-Length", "0"))
        raw = self.rfile.read(length).decode("utf-8", "replace")
        stamp = datetime.datetime.now().strftime("%H:%M:%S")
        try:
            data = json.loads(raw)
            pretty = json.dumps(data, indent=2, ensure_ascii=False)
        except json.JSONDecodeError:
            pretty = raw  # tot il pastram: un raport stricat spune si el ceva
        with open(OUT, "w", encoding="utf-8") as f:
            f.write(pretty)
        print(f"\n===== raport {stamp} -> {OUT} =====")
        print(pretty)
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
