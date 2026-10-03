#!/usr/bin/env python3
"""[D70, verificator 2026-10-03] Latimile literelor din Nunito-Regular (fontul "body" al jocului), pentru testele care
masoara texte fara Studio: CI-ul n-are fontul, deci latimile se scot o data din fontul livrat cu Studio si se comit.

Iesire: tests/fonts/NunitoWidths.luau, latimea fiecarui caracter la marimea 1000 (fara kerning; suma literelor iese cu
cel mult ~5 px peste sau sub textul randat la 15 px, deci testele pastreaza o marja).

Rulare (doar pe Mac-ul cu Studio): python3 scripts/art/nunito_widths.py
"""
import os

from PIL import ImageFont

FONT = "/Applications/RobloxStudio.app/Contents/Resources/content/fonts/Nunito-Regular.ttf"
OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "..", "tests", "fonts", "NunitoWidths.luau")
EXTRA = "’‘“”—–…·×→"


def main():
    font = ImageFont.truetype(FONT, 1000)
    chars = [chr(c) for c in range(32, 127)] + list(EXTRA)
    lines = [
        "-- GENERAT de scripts/art/nunito_widths.py din Nunito-Regular.ttf (Studio); nu se editeaza de mana.",
        "-- Latimea fiecarui caracter la marimea 1000, fara kerning.",
        "return {",
    ]
    for ch in chars:
        # ca stylua: ghilimelele duble intre apostrofuri, restul intre ghilimele
        key = "'\"'" if ch == '"' else '"' + ch.replace("\\", "\\\\") + '"'
        lines.append(f"    [{key}] = {font.getlength(ch):g},")
    lines.append("}")
    with open(OUT, "w", encoding="utf-8") as f:
        f.write("\n".join(lines) + "\n")
    print(f"scris {OUT} ({len(chars)} caractere)")


if __name__ == "__main__":
    main()
