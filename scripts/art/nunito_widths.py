#!/usr/bin/env python3
"""[D70, verificator 2026-10-03] Latimile literelor din Nunito-Regular (fontul "body" al jocului), pentru testele care
masoara texte fara Studio: CI-ul n-are fontul, deci latimile se scot o data din fontul livrat cu Studio si se comit.

Iesire: tests/fonts/NunitoWidths.luau, latimea fiecarui caracter la marimea 1000, fara kerning. Suma literelor iese cu
cel mult ~5 px fata de textul randat de PIL la 15 px (hinting) si ~3 px fata de textul asezat cu kerning (CoreText),
deci testele pastreaza o marja. Caracterele pe care fontul nu le are lipsesc din tabel.

Rulare (doar pe Mac-ul cu Studio): python3 scripts/art/nunito_widths.py
"""
import os

from PIL import ImageFont

FONT = "/Applications/RobloxStudio.app/Contents/Resources/content/fonts/Nunito-Regular.ttf"
OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "..", "tests", "fonts", "NunitoWidths.luau")
EXTRA = "’‘“”—–…·×→"


def main():
    font = ImageFont.truetype(FONT, 1000)
    # [verificator, 2026-10-03] doar caracterele pe care fontul le are: unul lipsa se deseneaza ca dreptunghiul .notdef
    # (sau din alt font, in joc), deci n-are ce cauta in tabel; testul pica atunci pe o descriere care l-ar folosi
    probe = ImageFont.truetype(FONT, 100)

    def glyph(ch):
        mask = probe.getmask(ch)
        return mask.size, tuple(mask)

    notdef = glyph("\uffff")
    chars = [
        ch
        for ch in [chr(c) for c in range(32, 127)] + list(EXTRA)
        if ch == " " or glyph(ch) != notdef
    ]
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
