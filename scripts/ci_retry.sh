#!/usr/bin/env bash
# Ruleaza o comanda de pe runner-ul de CI cu reincercari: `bash scripts/ci_retry.sh rokit install --no-trust-check`.
#
# Uneltele se descarca de pe GitHub (release-urile lui Rokit, StyLua, selene, Lune, Rojo, Wally), iar API-ul lor mai
# raspunde 403 (limita de rata pe IP-ul runner-ului comun) sau 500. Pe 2026-09-18 asa au picat doua rulari la rand, fara
# nicio legatura cu codul. O pana trecatoare a altcuiva nu trebuie sa arate ca o poarta picata.
set -u
attempt=1
while true; do
    if "$@"; then
        exit 0
    fi
    if [ "$attempt" -ge 4 ]; then
        echo "::error::comanda a picat dupa $attempt incercari: $*"
        exit 1
    fi
    wait_s=$((attempt * 20))
    echo "comanda a picat (incercarea $attempt): $* -- reincerc in ${wait_s}s"
    sleep "$wait_s"
    attempt=$((attempt + 1))
done
