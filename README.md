# Driftwood

Tycoon 2D pe Roblox: raul aduce, plasele prind, vinzi la debarcader, cumperi urmatoarea platforma. Un singur numar central: monede pe secunda.

- Plan: `docs/TYCOON.md` · Decizii: `docs/DECIZII.md` · Cifre: `scripts/economy/sim_tycoon.py` · Research: `docs/research/`, `docs/research-survival/`
- Toolchain: Rojo 7.7 + Wally + StyLua + selene + Lune (versiuni in `rokit.toml`; local se pot instala si prin Homebrew)

```sh
wally install                 # Packages/ + ServerPackages/
lune run tests/_run.luau      # teste pe modulele pure (fara Studio)
python3 scripts/economy/sim_tycoon.py --table   # economia: iese cu eroare daca o platforma nu creste venitul
stylua --check src/ && selene src/
rojo build default.project.json -o Driftwood.rbxl
rojo serve                    # apoi Rojo plugin -> Connect in Studio
```
