# Viață în lumea mică: NPC-uri și ambient pentru Driftycoon

Verdictul owner-ului: *„there is a single NPC and that's it."* Nota caută, cu surse, ce face o
hartă 2D mică să pară vie — și ce putem lua deja gata din codul și sprite-urile existente, înainte
de a desena ceva nou.

## 1. NPC-uri în tycoon-uri Roblox și jocuri idle

Niciun număr canonic de „câte NPC-uri vizibile" n-a fost găsit — NEVERIFICAT. Bucla
„drop-money-buy-upgrade" rămâne formula Roblox cea mai longevivă pentru recompensa scurtă și
constantă, nu pentru volumul de NPC-uri (game-ace.com, actualizat 2026-06-05, accesat
2026-09-12 — încredere medie). Restaurant Tycoon 2 face munca vizibilă cu **clienți-NPC** care vin,
comandă și pleacă, nu doar angajați ficși (cercetare internă, `docs/research/20-case-top-games.md`).
Sfatul recurent pentru „NPC viu": dă-i un scop propriu, nu-l lăsa în așteptare; fă-l indiferent la
tine ca atenția lui să fie câștigată; și **nu repeta aceeași replică** — cât dispare din ecran,
imaginația jucătorului completează ce face (Hadrian Lin, *How to Make NPC's Feel Alive*, itch.io,
~2020, accesat 2026-09-12 — încredere medie, sursă unică). Documentația oficială Roblox confirmă
principiul opus reflexului „un singur idle": *„Idle has two variations that you can program to
play more or less frequently"* (create.roblox.com, accesat 2026-09-12 — încredere ridicată).

## 2. Viață ambientală în lumi 2D top-down

Stardew Valley populează harta cu critters **pur cosmetici** — păsări, veverițe, broaște, fluturi,
licurici — care fug la apropiere, condiționați de vreme/sezon/oră, fără nicio interacțiune în afară
de un fluture special (stardewvalleywiki.com/Animals, accesat 2026-09-12 prin căutare — fetch
direct blocat HTTP 403 — încredere medie). Tehnicile de adâncime ieftină (parallax, umbră de
contact pictată în sprite, iarbă legănată cu fază aleatorie per instanță, tint zi/noapte) sunt deja
cercetate pentru noi în `docs/research-survival/art-depth-2d.md` — nu le repet, doar le aplic mai
jos.

## 3. Ce citește „ieftin" într-o scenă 2D

Un singur plan, zero umbre de contact, zero variație — și mai ales **mișcare sincronă**: dacă toate
tufele se leagănă în fază, ochiul citește tiparul instant și scena pare tapet, nu lume (offset de
fază aleatoriu per instanță, deja notat în `art-depth-2d.md`). Umbra lipsă e cel mai citat semn de
„lipit, nu desenat": un obiect fără umbră de contact pare că plutește deasupra fundalului chiar
dacă poziția e corectă (sinteză din surse de pixel-art, `art-depth-2d.md` secțiunea 3).

## 4. Câștiguri ieftine pentru ScreenGui pur

`ParticleEmitter` nu se poate parenta pe `GuiObject` — confirmat pe pagina oficială a clasei —
deci singura cale de particule la Driftwood e un pool de `ImageLabel` reciclate manual, exact ce
`SceneArt.luau` are deja (cercetare internă, `docs/research/11-juice-effects.md` — încredere
ridicată). Nu există benchmark oficial pentru „câte ImageLabel pe cadru la 60fps" (căutat explicit,
negativ — `docs/research/07-ui-performance.md`); pagina oficială de performanță dă cifre doar
pentru pipeline-ul 3D (sub 1000 draw calls, sub 1.000.000 triunghiuri, 16,67ms/cadru la 60fps —
create.roblox.com/docs/performance-optimization/design, accesat 2026-09-12 — încredere medie, **nu
se transferă** la GuiObject). Concluzia practică: cea mai ieftină „viață" per ciclu CPU vine din 1-3 `ImageLabel` reciclate
dintr-un pool existent, nu dintr-o foaie nouă.

## 5. Cum poate fi viu personajul jucătorului

Idle-ul „viu" nu cere cadre noi: variații secundare (transfer de greutate la 4-8s, respirație, un
gest ocazional) revin la poze deja existente, pe un cronometru de 30-60s, nu pe foaie nouă
(mocaponline.com, ghid idle animation, dată nespecificată, accesat 2026-09-12 — încredere medie,
cifre din animație de personaje 3D, folosite aici doar ca ordin de mărime). La Driftwood, rândul
`carry` există deja în foaie dar azi îl joacă doar Builder-ul spre șantier — pus pe jucător cu
plasa plină spre debarcader, e „gratis" din foaia care există.

## Ce am găsit deja în cod

`AnimConfig.luau` are azi **15 rânduri**, nu 12 — `run_down/up/side` s-au adăugat după F1. Trei
rânduri (`eat`, `sleep`, `cheer`) au rămas **orfane**: serveau nevoile coloniștilor, scoase la D45.
`Assets.props.boat` și `Assets.cloud` sunt deja desenate și încărcate, dar **neutilizate** — niciun
`grep` prin `src/Client` nu le găsește. Râul are deja o bandă ambientală (lane 1, „curentul din
larg", separată de benzile de prindere prin D2) randată de `RiverRenderController`, dar totul trece
prin `SceneArt.StyleCrate` — arată ca lăzi tentate pe raritate, nu ca varietatea din `Assets.goods`
(reeds/scrap/shards, deja încărcate, folosite azi doar de floater-ul de prindere din
`NetController`). Cele 130 de obiecte din `WorldDecor` sunt 100% statice. `SceneArt` are deja un
singur loop `PreRender` comun pentru particule (`AddSmoke`, `AddFire`, `Splash`, `WorkSpark`,
`Flourish`) — orice idee de mai jos care „reutilizează" înseamnă zero infrastructură nouă, doar
apeluri noi.

## Ce facem la Driftycoon

| # | Adăugare | Sprite / rânduri | Cost | Unde |
|---|---|---|---|---|
| 1 | Idle variat: reciclează `eat`/`sleep`/`cheer` orfane | 0, deja în foaie | zero, doar logică | stație, în timp mort |
| 2 | Replici ambientale, nu doar la angajare | 0 — bulă de text | mic, 1 label reutilizat | lângă fiecare angajat |
| 3 | `WorkSpark` pe cele 4 meserii (azi chei de colonie) | 0 — date noi în tabel | zero | fiecare stație activă |
| 4 | Jucător: `carry` la plasă plină, `cheer` la cumpărare | 0 — există, azi doar Builder | zero, doar logică | drumul spre debarcader |
| 5 | Varietate în lane 1: amestecă `Assets.goods` cu `StyleCrate` | 0 — deja încărcate | mic, pool existent | curentul din larg |
| 6 | Bărci în derivă pe râu | 0 — `Assets.props.boat`, neutilizat | mic, 2-3 `ImageLabel` | banda râului, fundal |
| 7 | Vizitator-client ocazional la debarcader | 0 — foaie + strat ținută existente | mic-mediu, 3 `ImageLabel` | debarcader, la vânzare |
| 8 | Umbră de nor peste iarbă | 0 — `Assets.cloud`, neutilizat | mic, 2-3 `ImageLabel` | peste tot decorul |
| 9 | Tufe/papură/copaci legănate, fază aleatorie | 0 — rotație pe decor existent | mic, un loop comun | `WorldDecor`: bush, cattails |
| 10 | Praf de pași și la angajați | 0 — `FootDust` există | zero, doar wiring | mersul spre stație |
| 11 | Fum/foc pe clădirile „fierbinți" | 0 — `AddSmoke`/`AddFire` există | zero, doar wiring | topitorie, cuptor |
| 12 | Clopotul se leagănă când sună | 0 — tween de rotație | zero | `prop_bell`/`landing_bell` |
| 13 | Insecte mici, rătăcind peste iarbă | 0 — punct colorat, fără sprite | mic, 4-6 particule | zona de câmp |
| 14 | Sclipiri ocazionale pe apă | 0 — `Frame` alb, fade rapid | mic, pool existent | banda râului |
| 15 | `Flourish` și la angajare | 0 — `SceneArt.Flourish` există | zero, doar wiring | apariția noului angajat |

## Surse

Toate accesate 2026-09-12; date/încredere detaliate inline mai sus.

- Roblox Creator Hub, *Play character animations* — https://create.roblox.com/docs/tutorials/use-case-tutorials/animation/play-character-animations
- Roblox Creator Hub, *Design for performance* — https://create.roblox.com/docs/performance-optimization/design
- Game-Ace, *12 Roblox game ideas that actually work for devs* — https://game-ace.com/blog/roblox-game-ideas-that-actually-work/
- Hadrian Lin, *How to Make NPC's Feel Alive* — https://anv.itch.io/the-year-after/devlog/176557/how-to-make-npcs-feel-alive
- Stardew Valley Wiki, *Animals* — https://stardewvalleywiki.com/Animals
- MoCap Online, *Idle Animation for Games: Design Guide* — https://mocaponline.com/blogs/mocap-news/idle-animation-game-dev-guide
- Roblog, *Juice it or lose it* (talk GDC Europe 2012, Jonasson & Purho) — https://roblog.co.uk/2024/03/juicy-games/ ; GDC Vault — https://www.gdcvault.com/play/1016487/Juice-It-or-Lose

Cercetare internă: `docs/research/{11-juice-effects,07-ui-performance,20-case-top-games}.md`,
`docs/research-survival/art-depth-2d.md`. Cod citit direct: `AnimConfig.luau`, `SceneArt.luau`,
`RiverRenderController.luau`, `Assets.luau`, `WorldDecor.luau`, `scripts/art/*.py`.
