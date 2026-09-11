#!/usr/bin/env bash
# Copiaza sonda in folderul de plugin-uri al Studio. Studio o incarca la urmatoarea pornire
# (sau imediat, daca era deja pornit -- se reincarca singur cand fisierul se schimba).
set -euo pipefail
DEST="$HOME/Documents/Roblox/Plugins"
mkdir -p "$DEST"
cp "$(dirname "$0")/../plugins/DriftwoodProbe.lua" "$DEST/DriftwoodProbe.lua"
echo "instalat: $DEST/DriftwoodProbe.lua"
