#!/usr/bin/env bash
# Publica un place pe staging din CI (Open Cloud), cu reincercari cand Roblox raspunde 409 "Server is busy".
#
# DE CE (2026-09-17): publicarea satului a picat la fiecare push cu 409. Raspunsul Roblox de pe forum: "We don't allow
# overwriting the place file if a TC session is currently active" -- satul era deschis in Studio (editare
# colaborativa), iar serverul sesiunii mai traieste cateva minute dupa ce se inchide Studio. Deci: se incearca de cateva
# ori, apoi se spune limpede de ce nu s-a putut.
#
# Folosire: bash scripts/ci_publish.sh <placeId> <fisier.rbxl>
# Mediu:    ROBLOX_API_KEY, UNIVERSE_ID. Cheia nu se afiseaza niciodata (doar lungimea ei).
set -uo pipefail

place="$1"
file="$2"
if [[ ! "$place" =~ ^[0-9]+$ || ! "${UNIVERSE_ID:-}" =~ ^[0-9]+$ ]]; then
  echo "::error::id-uri invalide: universe='${UNIVERSE_ID:-}' place='$place'"
  exit 1
fi
echo "universe=$UNIVERSE_ID place=$place key_length=${#ROBLOX_API_KEY} fisier=$file ($(wc -c < "$file") octeti)"

# cine e in sesiunea colaborativa a place-ului (merge doar daca cheia are voie; altfel se vede 403 si atat)
members=$(curl -sS -H "x-api-key: $ROBLOX_API_KEY" -w " [HTTP %{http_code}]" \
  "https://apis.roblox.com/legacy-develop/v1/places/$place/teamcreate/active_session/members?limit=10")
echo "sesiunea colaborativa: $members"

body_file=$(mktemp)
for delay in 0 30 60 90; do
  sleep "$delay"
  code=$(curl -sS -o "$body_file" -w "%{http_code}" \
    -H "x-api-key: $ROBLOX_API_KEY" \
    -H "Content-Type: application/octet-stream" \
    --data-binary "@$file" \
    -X POST \
    "https://apis.roblox.com/universes/v1/$UNIVERSE_ID/places/$place/versions?versionType=Published")
  code=${code:-000}
  body=$(cat "$body_file")
  echo "HTTP $code: $body"
  if [[ "$code" == "200" ]]; then
    version=$(jq -r '.versionNumber' <<<"$body")
    echo "publicat: place $place, versiunea $version"
    if [[ -n "${GITHUB_OUTPUT:-}" ]]; then
      echo "version=$version" >> "$GITHUB_OUTPUT"
    fi
    exit 0
  fi
  if [[ "$code" != "409" ]]; then
    echo "::error::publicarea place-ului $place a picat (HTTP $code)"
    exit 1
  fi
done
echo "::error::place-ul $place e deschis in Studio (sesiune colaborativa): Roblox nu primeste publicarea cat e deschis"
exit 1
