#!/usr/bin/env bash
# Instaleaza Rokit pe runner-ul de CI, cu reincercari.
#
# Scriptul oficial intreaba API-ul GitHub care e ultima versiune, FARA autentificare; pe runner-ele comune, limita de rata
# pe IP se atinge din cand in cand si raspunsul e 403. Asa a picat publicarea pe staging la f1019ca (2026-09-18), desi
# acelasi pas trecuse, cu un minut inainte, in jobul de teste. Cu jetonul job-ului (GITHUB_PAT, citit de scriptul Rokit)
# limita e a repo-ului, nu a IP-ului; reincercarile acopera restul.
set -u
set -o pipefail  # fara el, un curl picat ar da `bash` cu intrare goala si iesire 0: instalare "reusita" fara Rokit
attempt=1
while true; do
    if curl -sSf https://raw.githubusercontent.com/rojo-rbx/rokit/main/scripts/install.sh | bash; then
        exit 0
    fi
    if [ "$attempt" -ge 4 ]; then
        echo "::error::Rokit nu s-a instalat dupa $attempt incercari"
        exit 1
    fi
    wait_s=$((attempt * 15))
    echo "instalarea Rokit a picat (incercarea $attempt); reincerc in ${wait_s}s"
    sleep "$wait_s"
    attempt=$((attempt + 1))
done
