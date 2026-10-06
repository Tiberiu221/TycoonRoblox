"""Folderul de lucru al scripturilor de arta si sunet: planse, previzualizari, PNG-urile unui lot inainte de urcare.

Pana pe 2026-10-06 fiecare script avea scrisa de mana calea scratchpad-ului unei sesiuni Claude
(/private/tmp/claude-501/.../<sesiune>/scratchpad): intr-o sesiune noua calea nu mai exista. Acum, intr-un singur loc:
  * DRIFTWOOD_SCRATCH, daca e pusa (o sesiune Claude o pune pe scratchpad-ul ei);
  * altfel <repo>/.scratch/ (ignorat de git; owner-ul il deschide din panoul de fisiere).
Nimic de aici nu intra in assets/ sau in joc. `--out` al fiecarui generator ramane cum era.
"""
import os

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
SPRITES = os.path.join(ROOT, "assets", "sprites")


def root():
    """Folderul de lucru, fara sa-l creeze."""
    return os.environ.get("DRIFTWOOD_SCRATCH") or os.path.join(ROOT, ".scratch")


def folder(*parts):
    """Un folder din cel de lucru (de exemplu folder("a1")), creat daca lipseste."""
    path = os.path.join(root(), *parts)
    os.makedirs(path, exist_ok=True)
    return path


def sprite(name, lot):
    """Un desen al unui lot (`prop_dam_wall`, "a1"): copia de lucru din folderul lotului, daca exista, altfel cel urcat din
    assets/sprites (loturile A1, A2 si A4 sunt urcate; copiile de lucru erau identice la pixel)."""
    path = os.path.join(root(), lot, name + ".png")
    return path if os.path.exists(path) else os.path.join(SPRITES, name + ".png")
