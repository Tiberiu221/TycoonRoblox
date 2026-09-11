# Driftycoon — context de proiect

Citit automat la fiecare sesiune. Ține-l scurt: fiecare cuvânt de aici se plătește la fiecare pornire.

## Ce construim

Tycoon 2D pe Roblox, pe malul unui râu. **Râul aduce → plasele prind → vinzi la debarcader → cumperi
următoarea platformă → prinzi mai mult.** Un singur număr central: monede pe secundă.
Fraza pentru jucător: *This stretch of river is yours. Everything that floats past is money.*

## Surse de adevăr, în ordine

1. `docs/TYCOON.md` — **planul**: 6 principii, regula celor patru motive, 22 de arii dezbătute,
   cele 48 de platforme, fazele F0–F9 și lista de sarcini. Aici se lucrează.
2. `docs/DECIZII.md` — registrul; e lege. D45 = pivotarea la tycoon și ce decizii vechi cad.
3. `scripts/economy/sim_tycoon.py` — **sursa cifrelor**. Prețurile nu se ghicesc și nu se editează de
   mână în plan: se reglează în simulator. Iese cu eroare dacă o platformă nu crește venitul.
4. `docs/research/` (37 note, index în README) și `docs/research-survival/` (24 note, index în README).

Arhivat, nu în proiect: masterplanul vechi, direcțiile concurente, documentele de colonie —
`~/Desktop/Driftwood_arhiva_2026-09-11/`. Etichetele `[MASTERPLAN x.y]` din comentariile de cod trimit acolo.

## Reguli de design care nu se negociază

- **Nimic nu se pierde.** Fără dezastre, fără furt, fără scădere; offline doar binevoitor.
- **Banii cumpără viteză, spațiu, aspect.** Niciodată noroc, conținut sau ceva aleator.
- **Orice se cumpără** prinde mai mult, vinde mai scump, scapă de o corvoadă sau deschide ce urmează.
  **Nicio cumpărare nu scade venitul.**
- **Nimic nu se întâmplă în tăcere** (D43); **textul nu minte** (D40); următorul pas se vede, nu se explică.
- Textul din joc în **engleză**; comentariile și conversația în **română**.

## Stack și reguli de cod

Roblox Studio (Apple Silicon), Luau, **2D pur în ScreenGui**, Rojo 7.7 · StyLua · selene · Lune.
`--!strict` pe fiecare modul; doar `task.*`. **Serverul e singura sursă de adevăr** pentru economie;
clientul trimite intenții pe RemoteEvent (niciodată RemoteFunction), cu validare de tip, `math.isfinite`,
ownership și limitare de rată. Module pure în `src/Shared/Modules` (primesc `now`, fără `game`).
Timp absolut (`finishAt`), niciodată „timp rămas". Râul e determinist pe seed [D13].

**Capcane cunoscute:** stylua șterge punctul-și-virgula din fața unei instrucțiuni care începe cu `(` —
restructurează cu un `local`. `BindableEvent` copiază tabelele — trimite identități. Câmpurile trimise de
server trebuie **copiate explicit** pe client (am pierdut de două ori nume/meserie/înfățișare așa).

## Poarta, înainte de orice livrare

```
stylua --check src/ tests/ && selene src/ && lune run tests/_run.luau
rojo build default.project.json --output /tmp/check.rbxl
lune run scripts/check_requires /tmp/check.rbxl
python3 scripts/economy/sim_tycoon.py
```
`rojo build` și `check_requires` **nu parsează Luau** — o eroare de sintaxă trece de ele; doar
stylua/selene o prind. Rulează-le mereu pe toate, nu înlănțuite după o eroare.

## Mod de lucru

- Agenții pe **Sonnet**, niciodată moștenind modelul principal. Le dai instrucțiuni clare, apoi
  **verifici tu** în cod ce raportează — au greșit de mai multe ori.
- Dus la capăt singur, apoi o listă scurtă cu ce poate verifica doar owner-ul în Studio.
- **Fără commit fără cerere.** Repo privat `github.com/Tiberiu221/TycoonRoblox`, ramura `main`;
  CI-ul rulează poarta (fără Studio) la fiecare push.
- Cheia API în `~/.driftwood_api_key` — niciodată în chat, în repo sau ca argument de comandă.

## Stare (2026-09-11)

Planul tycoon e scris (`docs/TYCOON.md`); **faza F0 nu a început**. Codul din `src/` e încă cel de
colonie și se taie în F0, în același pas în care intră înlocuitorul (lista în `TYCOON.md` §6).
Rămas la owner: numele, terenuri multiple, lobby/DevEx, D19. Și F0-ul de cont:
Grup Roblox, 2FA + ID, **W-8BEN până la 31 oct 2026**, universuri Staging/Prod.
