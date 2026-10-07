# Toolchain extern pentru dezvoltare Roblox (macOS, 2026): Rokit, Rojo, Wally, StyLua, selene, luau-lsp

## Rezumat executiv

- **Rokit** (`rojo-rbx/rokit`) e managerul de toolchain recomandat oficial de Roblox în 2026. Înlocuiește **Aftman**, care e **arhivat** pe GitHub din 2025. Nu porni un proiect nou cu Aftman.
- **Rojo v7.7.0** (1 iulie 2026) e versiunea curentă. Rularea de bază (filesystem → Studio, live) e stabilă și matură din 2019. Sincronizarea **bidirecțională completă** (editezi în Studio, se scrie automat pe disc) **nu există încă** ca funcție nativă continuă — există doar comanda manuală `rojo syncback`, introdusă abia în 7.7.0-rc.1 (27 nov. 2025). Nu proiecta workflow-ul Driftwood pe presupunerea că poți edita liber în Studio și Rojo salvează automat.
- **Wally** e utilizabil (Homebrew are v0.3.2), dar **ultimul release stabil e din iunie 2023** — peste 3 ani fără update de versiune la data acestui research. Nu e abandonat oficial, dar ritmul de release e foarte lent. Există o alternativă mai nouă, **pesde**, compatibilă cu registry-ul Wally.
- **StyLua v2.5.2** (16 mai 2026) și **selene v0.31.0** (21 mai 2026) sunt formatorul, respectiv linter-ul standard de facto în comunitatea Roblox/Luau. Ambele au binar prin Homebrew și prin Rokit.
- **luau-lsp v1.69.0** (18 iulie 2026, extensia VS Code actualizată 14 iulie 2026) oferă autocomplete/diagnostics pentru Luau + Roblox. Rulează în **VS Code** direct din Marketplace și în **Cursor** prin **Open VSX** (Cursor a migrat de pe VS Code Marketplace pe Open VSX din iunie 2025, din motive de licențiere impuse de Microsoft) sau prin instalare manuală de `.vsix`.
- Documentul oficial Roblox `create.roblox.com/docs/projects/external-tools` confirmă explicit acest stack (Rokit + Rojo + Wally + selene + StyLua + Luau Language Server) și menționează **Cursor** ca editor suportat alături de VS Code — dar avertizează clar: *"The tools on this page are not maintained by Roblox and can change or stop working at any time."*
- Pentru un joc 2D pur în `ScreenGui` ca Driftwood, recomandarea comunității (sursă secundară, dar directă pe temă) e să construiești UI-ul **din cod**, nu din fișiere `.rbxmx` sincronizate din Studio — motivul e că Rojo nu poate ține pasul cu editări vizuale complexe în Studio fără sync bidirecțional stabil.
- Pentru asset-uri non-cod (imagini, sunete), Rojo **nu** le urcă automat pe Roblox — trebuie fie încărcate manual prin Studio/Toolbox și referențiate prin `rbxassetid://`, fie automatizate cu **Tarmac** (`rojo-rbx/tarmac`), care însă e și el **stagnant** (ultimul release: ianuarie 2024).
- Fișier `default.project.json` funcțional pentru arhitectura din brief (`ServerScriptService`, `StarterPlayerScripts`, `ReplicatedStorage`, `StarterGui`, `ReplicatedFirst`) e inclus mai jos, verificat pe formatul oficial de proiect Rojo.

## Fapte verificate

- Rokit e "next-generation toolchain manager for Roblox projects", compatibil drop-in cu proiecte `foreman.toml`/`aftman.toml`. Sursă: https://github.com/rojo-rbx/rokit (README) — verificat 2026-09-08; confidence: ridicata.
- Ultimul release Rokit e `v1.2.0`, publicat 2025-09-30T19:30:33Z. Sursă: GitHub API `api.github.com/repos/rojo-rbx/rokit/releases` — verificat 2026-09-08; confidence: ridicata.
- Aftman (`LPGhatguy/aftman`) e **arhivat** (`"archived": true`), ultimul push 2025-07-09. Sursă: GitHub API `api.github.com/repos/LPGhatguy/aftman` — verificat 2026-09-08; confidence: ridicata.
- Ultimul release Rojo e `v7.7.0`, publicat 2026-07-02T01:47:35Z (changelog îl datează "July 1st, 2026"). Sursă: GitHub API `api.github.com/repos/rojo-rbx/rojo/releases` + https://github.com/rojo-rbx/rojo/blob/master/CHANGELOG.md — verificat 2026-09-08; confidence: ridicata.
- Rojo a adăugat suport pentru extensia `.luau` în v7.2.0 (29 iunie 2022, PR #552); ulterior `rojo init` a fost schimbat să genereze `.luau` în loc de `.lua` (PR #831). Sursă: https://github.com/rojo-rbx/rojo/blob/master/CHANGELOG.md — verificat 2026-09-08; confidence: ridicata.
- Comanda `rojo syncback` (extrage instanțe dintr-un fișier `.rbxl`/`.rbxlx` și le scrie pe disc, controlată de câmpul `syncbackRules` din project file) a fost introdusă în `7.7.0-rc.1`, 27 noiembrie 2025 (PR #937), și stabilizată/extinsă în 7.7.0. Sursă: https://github.com/rojo-rbx/rojo/blob/master/CHANGELOG.md — verificat 2026-09-08; confidence: ridicata.
- Sincronizare live bidirecțională continuă (Studio → filesystem în timp real, la fiecare tastă) rămâne "planned but not yet implemented" conform discuției oficiale a proiectului. Sursă: https://github.com/rojo-rbx/rojo/discussions/728 (rezumat conversație, septembrie 2026) — confidence: medie (discuție comunitară, nu changelog oficial, dar menținută activ de mainteneri).
- Ultimul release Wally e `v0.3.2`, publicat 2023-06-05T19:00:14Z; nu există release mai nou nici pe Homebrew (`0.3.2`). Sursă: GitHub API `api.github.com/repos/UpliftGames/wally/releases` + `formulae.brew.sh/api/formula/wally.json` — verificat 2026-09-08; confidence: ridicata.
- Repo-ul Wally nu e arhivat (`"archived": false`), cu push recent (2026-01-28), dar fără tag de release nou de peste 3 ani — activitate de mentenanță, nu de dezvoltare de produs. Sursă: GitHub API `api.github.com/repos/UpliftGames/wally` — verificat 2026-09-08; confidence: ridicata.
- `pesde` e un package manager mai nou pentru Luau (Roblox + Lune), compatibil cu registry-ul Wally și cu surse Git. Sursă: https://github.com/pesde-pkg/pesde, https://docs.pesde.dev/guides/roblox/ — verificat 2026-09-08; confidence: medie (proiect mai tânăr, adopție incertă).
- StyLua ultimul release: `v2.5.2`, 2026-05-16. Urmează Roblox Lua Style Guide (`roblox.github.io/lua-style-guide`) cu mici devieri. Sursă: GitHub API `api.github.com/repos/JohnnyMorganz/StyLua/releases` + README oficial — verificat 2026-09-08; confidence: ridicata.
- selene ultimul release: `v0.31.0`, 2026-05-21. Sursă: GitHub API `api.github.com/repos/Kampfkarren/selene/releases` — verificat 2026-09-08; confidence: ridicata.
- selene are `std = "roblox"` ca opțiune built-in care generează automat un standard-library Roblox cache-uit, actualizat automat la 6 ore; se poate forța cu `selene update-roblox-std` sau fixa (pin) cu `roblox-std-source = "pinned"`. Sursă: https://kampfkarren.github.io/selene/roblox.html (identic cu sursa markdown din repo) — verificat 2026-09-08; confidence: ridicata.
- luau-lsp ultimul release: `1.69.0`, publicat 2026-07-18T23:42:27Z pe GitHub; extensia VS Code (`johnnymorganz.luau-lsp`, display name "Luau Language Server") actualizată în Marketplace 2026-07-14. Sursă: GitHub API `api.github.com/repos/JohnnyMorganz/luau-lsp/releases` + VS Code Marketplace Gallery API — verificat 2026-09-08; confidence: ridicata.
- Cursor a trecut de pe VS Code Marketplace pe registry-ul **Open VSX** din iunie 2025 (Microsoft a restricționat termenii Marketplace-ului doar la produse Microsoft, aplicat activ din aprilie 2025). Extensia luau-lsp e publicată și pe Open VSX (`open-vsx.org/extension/JohnnyMorganz/luau-lsp`, versiuni până la 1.69.0 confirmate). Sursă: https://www.devclass.com/development/2025/04/08/vs-code-extension-marketplace-wars-cursor-users-hit-roadblocks/1629343 (secundară) + `open-vsx.org/api/JohnnyMorganz/luau-lsp` (primară) — verificat 2026-09-08; confidence: ridicata pentru disponibilitatea pe Open VSX, medie pentru cronologia exactă a schimbării Cursor (sursă secundară).
- Documentul oficial Roblox pentru unelte externe listează exact Rokit + Rojo + Wally + selene + StyLua + Luau Language Server, cu exemple de `rokit.toml` și `wally.toml`, și menționează explicit Cursor ca editor suportat. Sursă: https://create.roblox.com/docs/projects/external-tools — verificat 2026-09-08; confidence: ridicata.
- Rojo are formulă Homebrew oficială (`homebrew/core`), versiune curentă `7.7.0`, dar **Rokit nu are** formulă Homebrew — se instalează doar prin scriptul oficial sau `cargo`. Sursă: `formulae.brew.sh/api/formula/rojo.json` (verificat, rezultat gol pentru `rokit.json`) — verificat 2026-09-08; confidence: ridicata.
- Tarmac (unealtă oficială Rojo pentru sincronizarea imaginilor/asset-urilor binare) are ultimul release `v0.7.5` din 2024-01-08 și ultimul push în repo din 2024-03-05 — peste 2 ani fără activitate reală. Sursă: GitHub API `api.github.com/repos/rojo-rbx/tarmac` — verificat 2026-09-08; confidence: ridicata (fapt), medie (implicație despre viitorul proiectului).
- ProfileService are un succesor mai nou și mai eficient, **ProfileStore** (`lm-loleris/profilestore`, wally.toml curent `v1.0.3`), cu autosave implicit la 300s (față de 30s la ProfileService) și rezolvare de session-lock conflict mai rapidă via `MessagingService`. Sursă: https://madstudioroblox.github.io/ProfileStore/, repo `MadStudioRoblox/ProfileStore` (push 2025-07-31) — verificat 2026-09-08; confidence: medie (comparație de performanță citată din surse secundare, dar existența/versiunea pachetului e primară).

## Detalii

### 1. Rokit — managerul de toolchain

Rokit e scris în Rust, instalabil pe macOS printr-un script curl (nu Homebrew):

```sh
curl -sSf https://raw.githubusercontent.com/rojo-rbx/rokit/main/scripts/install.sh | bash
```

După instalare, într-un director de proiect:

```sh
rokit init          # creează rokit.toml gol
rokit add rojo-rbx/rojo@7.7.0
rokit add JohnnyMorganz/stylua@2.5.2
rokit add Kampfkarren/selene@0.31.0
rokit install        # instalează tot ce e listat în rokit.toml
```

Exemplu real de `rokit.toml`, luat direct din propriul repo al Rojo (`rojo-rbx/rojo/rokit.toml`, verificat pe branch master):

```toml
[tools]
rojo = "rojo-rbx/rojo@7.5.1"
selene = "Kampfkarren/selene@0.29.0"
stylua = "JohnnyMorganz/stylua@2.1.0"
run-in-roblox = "rojo-rbx/run-in-roblox@0.3.0"
lune = "lune-org/lune@0.10.4"
```

(Notă: acesta e fișierul propriu al Rojo, cu versiuni fixate la momentul acelui commit — nu ultimele versiuni disponibile azi. Pentru Driftwood, fixează versiunile curente verificate mai sus.)

Exemplul oficial din documentația Roblox (`create.roblox.com/docs/projects/external-tools`) pentru un proiect nou:

```toml
[tools]
rojo = "rojo-rbx/rojo@7.6.1"
wally = "upliftgames/wally@0.3.2"
lune = "lune-org/lune@0.10.4"
```

`rokit add` scrie automat o intrare nouă în `rokit.toml` și rulează instalarea. Rokit e compatibil cu proiecte care au deja `aftman.toml`/`foreman.toml`, deci migrarea de la Aftman nu necesită rescrierea manuală a fișierului.

### 2. Rojo — sincronizare filesystem ↔ Studio

Rojo are două componente: un binar CLI (rulează local, urmărește filesystem-ul) și un plugin de Studio (se conectează la server-ul local și aplică schimbările în DataModel).

Instalare CLI (după Rokit, ca mai sus) + plugin:

```sh
rojo plugin install
```

Asta instalează pluginul direct în folderul de pluginuri al Studio, sincronizat cu versiunea CLI-ului. Alternativ, pluginul poate fi instalat manual din Creator Store (fostul roblox.com/library).

**Stare sincronizare bidirecțională (răspuns direct la întrebarea din research):**
- Direcția **filesystem → Studio** e cea nativă și stabilă din 2019: rulezi `rojo serve`, pluginul din Studio se conectează, orice salvezi în editor apare live în Studio.
- Direcția **Studio → filesystem** există doar ca **comandă manuală, unidirecțională**: `rojo syncback [path la project.json] --input [path la fișier .rbxl/.rbxlx]`. Extrage instanțele dintr-un fișier Roblox salvat și le scrie pe disc, controlat de `syncbackRules` din project file (poți exclude arbori întregi, proprietăți, etc.). Nu rulează continuu — o rulezi manual după ce ai făcut modificări în Studio pe care vrei să le "aduci înapoi" în cod.
- Nu există (încă) un mod în care tastezi în Script Editor din Studio și fișierul `.luau` de pe disc se actualizează automat, în timp real. Există patch-uri neoficiale ale comunității pentru asta (ex. o discuție din iunie 2026 despre stabilizarea sincronizării `Script.Source`), dar nu sunt parte din Rojo oficial.
- **Concluzie practică pentru Driftwood:** editează codul exclusiv în VS Code/Cursor. Dacă cineva modifică ceva direct în Studio (de ex. plasează un obiect manual în timpul unui test), acea schimbare se pierde la următorul `rojo serve` sync sau trebuie recuperată manual prin `rojo syncback`.

Exemplu de workflow de bază, tot din documentația oficială:

```sh
rojo init my-new-experience
cd my-new-experience
rojo build -o my-new-experience.rbxl
rojo serve
```

### 3. Formatul de proiect `default.project.json`

Structura oficială (verificată pe `rojo.space/docs/v7/project-format/`):

- `name` (obligatoriu) — numele proiectului, folosit la build.
- `tree` (obligatoriu) — descrierea instanței rădăcină (de obicei `DataModel`).
- `servePort` (opțional, implicit `34872`).
- `globIgnorePaths` (opțional) — glob-uri de exclus din sincronizare.
- În nod: `$className`, `$path`, `$properties`, `$ignoreUnknownInstances`.

`default.project.json` pentru arhitectura Driftwood (server autoritar, `ServerScriptService` / `StarterPlayerScripts` / `ReplicatedStorage` / `StarterGui` / `ReplicatedFirst`):

```json
{
  "name": "Driftwood",
  "globIgnorePaths": ["**/*.spec.luau"],
  "tree": {
    "$className": "DataModel",

    "ReplicatedFirst": {
      "$className": "ReplicatedFirst",
      "$path": "src/ReplicatedFirst"
    },

    "ReplicatedStorage": {
      "$className": "ReplicatedStorage",
      "$path": "src/ReplicatedStorage",
      "Packages": {
        "$path": "Packages"
      }
    },

    "ServerScriptService": {
      "$className": "ServerScriptService",
      "$path": "src/ServerScriptService",
      "ServerPackages": {
        "$path": "ServerPackages"
      }
    },

    "StarterGui": {
      "$className": "StarterGui",
      "$path": "src/StarterGui"
    },

    "StarterPlayer": {
      "$className": "StarterPlayer",
      "StarterPlayerScripts": {
        "$className": "StarterPlayerScripts",
        "$path": "src/StarterPlayerScripts"
      }
    }
  }
}
```

`ReplicatedFirst` e util în Driftwood pentru un ecran de loading minimal (obligatoriu în orice caz — Roblox rulează orice script de acolo înainte de a termina de încărcat restul jocului), nu pentru UI-ul principal.

### 4. Convenții de denumire fișiere (verificat pe changelog + docs Rojo)

| Fișier pe disc | Instanță generată |
|---|---|
| `Nume.server.luau` | `Script` |
| `Nume.client.luau` | `LocalScript` |
| `Nume.luau` (orice altul) | `ModuleScript` |
| `init.server.luau` (în interiorul unui director) | directorul devine `Script`, restul fișierelor din el devin copiii lui |
| `init.client.luau` | directorul devine `LocalScript` |
| `init.luau` | directorul devine `ModuleScript` |
| director simplu (fără `init.*`) | `Folder` |
| `Nume.model.json` | model scris de mână (JSON) |
| `Nume.rbxm` / `Nume.rbxmx` | model binar/XML importat ca atare |
| `Nume.meta.json` (lângă alt fișier) | atașează proprietăți suplimentare (`$properties`, `$className`, `$ignoreUnknownInstances`) |

Din 2022 (Rojo 7.2.0), `.luau` e suportat integral și, din versiuni ulterioare, `rojo init` generează implicit `.luau` (nu `.lua`). Folosește `.luau` peste tot în Driftwood — e extensia recomandată de echipa Luau/Roblox și e cerută pentru type-checking corect de `luau-lsp`.

Exemplu concret pentru un sistem din Driftwood (rularea plaselor pe server):

```
src/ServerScriptService/
  River/
    init.server.luau        -- Script care pornește sistemul râului
    SpawnObjects.luau       -- ModuleScript
    NetCalculator.luau      -- ModuleScript
```

### 5. ScreenGui: cod vs. `.rbxmx` sincronizat din Studio

Pentru un joc bazat 100% pe `ScreenGui` ca Driftwood, opțiunile sunt:

1. **Construiește GUI-ul din cod** (`Instance.new("Frame")`, etc., într-un modul central care rulează o singură dată și expune referințe cache-uite).
2. **Construiește vizual în Studio**, salvează ca `.rbxmx`, sincronizează cu `$path` în `default.project.json`.

Recomandarea comunității pentru jocuri 2D/GUI-only cu Rojo (sursă secundară directă pe subiect — un tutorial DevForum din 2026 despre exact acest tip de proiect): construiește **din cod**, nu din `.rbxmx`. Motivele citate:
- Fără sincronizare bidirecțională stabilă (vezi secțiunea 2), orice modificare vizuală făcută în Studio pe un `.rbxmx` sincronizat riscă să fie suprascrisă sau pierdută la următorul `rojo serve`.
- Codul e diff-abil în git; un `.rbxmx` binar/XML complex nu e (code review pe UI devine imposibil).
- Un modul UI scris în cod, apelat cu `require(interface)`, garantează referințe stabile fără să depinzi de calea din DataModel.

Exemplu minimal de tipar folosit în acest sens (adaptat, nu literal din sursă):

```luau
-- src/ReplicatedStorage/UI/Interface.luau
local Interface = {}

local screenGui = Instance.new("ScreenGui")
screenGui.Name = "DriftwoodUI"
screenGui.ResetOnSpawn = false

local netFrame = Instance.new("Frame")
netFrame.Name = "NetPanel"
netFrame.Size = UDim2.fromScale(0.2, 0.3)
netFrame.Parent = screenGui

Interface.ScreenGui = screenGui
Interface.NetPanel = netFrame

return Interface
```

Dacă echipa preferă totuși construcție vizuală (mai rapid pentru iterații de layout), varianta hibridă e: prototipează layout-ul în Studio, apoi **transcrie manual** proprietățile (`Size`, `Position`, `AnchorPoint`) în cod — nu ține fișierul `.rbxmx` ca sursă de adevăr pe termen lung.

### 6. Asset-uri non-cod (imagini, sunete, fonturi)

Rojo sincronizează fișiere text/model, dar **nu urcă imagini pe serverele Roblox** — un `ImageLabel` are nevoie de un `rbxassetid://` valid, iar acel ID vine doar din upload pe platforma Roblox.

Două opțiuni:
1. **Manual**: încarci imaginea prin Studio (Toolbox → Decals, sau Asset Manager), obții un ID, îl hard-codezi sau îl pui într-un modul `Assets.luau` cu constante.
2. **Automatizat cu Tarmac** (`rojo-rbx/tarmac`): unealtă CLI oficială pentru upload + hashing de imagini, generează un fișier de mapare (`tarmac-manifest.toml`) și un modul Luau cu ID-urile. **Atenție**: ultimul release e `v0.7.5` (8 ianuarie 2024) și repo-ul nu a mai primit push din martie 2024 — practic stagnant. Funcționează, dar nu aștepta suport activ sau fix-uri.

Pentru Driftwood la început, varianta manuală (ID-uri hard-codate într-un modul `Assets.luau`, urcate prin Studio) e suficientă și evită o dependență neîntreținută.

### 7. Wally — package manager

```sh
brew install wally
```

sau prin Rokit (`rokit add upliftgames/wally@0.3.2`).

`wally.toml` minim, format oficial (câmpuri verificate din README + exemple reale de pachete):

```toml
[package]
name = "driftwood/game"
version = "0.1.0"
registry = "https://github.com/UpliftGames/wally-index"
realm = "shared"

[dependencies]
Signal = "sleitnick/signal@2.0.3"
Promise = "evaera/promise@4.0.0"

[server-dependencies]
ProfileStore = "lm-loleris/profilestore@1.0.3"
```

Rulează `wally install` — descarcă în directorul `Packages/` (client/shared) și `ServerPackages/` (dacă separi `server-dependencies`), pe care trebuie să le referi explicit în `default.project.json` (vezi secțiunea 3, nodurile `Packages`/`ServerPackages`).

Notă de risc: Wally n-a mai avut un release de versiune din iunie 2023. E în continuare instalabil și registry-ul funcționează, dar dacă apare un bug critic sau o cerință nouă (ex. suport Luau nou), nu e clar cât de repede ar fi rezolvat. **pesde** (`pesde-pkg/pesde`) e o alternativă mai nouă, compatibilă cu registry-ul Wally, dar cu o cerință structurală diferită (nu vrea `default.project.json` în interiorul pachetelor, folosește `build_files`). Pentru un proiect solo/mic ca Driftwood la început, Wally rămâne alegerea sigură pentru că are documentație și exemple mult mai răspândite — dar merită revizitat dacă echipa crește.

### 8. StyLua — formatter

```sh
brew install stylua
```

Config (`stylua.toml`), exemplu minim orientat Roblox:

```toml
column_width = 100
line_endings = "Unix"
indent_type = "Spaces"
indent_width = 4
quote_style = "AutoPreferDouble"
call_parentheses = "Always"
```

Rulare locală și pentru CI (verifică fără să scrie fișiere):

```sh
stylua --check src/
stylua src/          # aplică formatarea
```

### 9. selene — linter

`selene.toml` minim pentru Roblox:

```toml
std = "roblox"
```

Prima rulare generează automat un standard-library cache-uit pentru globale Roblox (`game`, `workspace`, `script`, etc.), reîmprospătat automat la 6 ore. Pentru CI (fără acces la internet sau pentru reproductibilitate strictă), pin-uiește:

```toml
std = "roblox"
roblox-std-source = "pinned"
```

apoi generează manual fișierul cu `selene generate-roblox-std`, pe care îl commit-uiești (`roblox.yml`).

Rulare:

```sh
selene src/
```

### 10. luau-lsp — language server

Instalare VS Code: caută extensia **"Luau Language Server"** (`johnnymorganz.luau-lsp`) în Marketplace.

Pentru Cursor: extensia e publicată și pe **Open VSX** (`open-vsx.org/extension/JohnnyMorganz/luau-lsp`), pe care Cursor îl folosește ca marketplace implicit din 2025 — se instalează direct din panoul de extensii al Cursor, la fel ca în VS Code. Dacă nu apare, se poate instala manual din `.vsix` descărcat de pe GitHub Releases (`Install from VSIX…`).

Pentru intellisense complet pe instanțele din DataModel (nu doar pe module), luau-lsp are nevoie de un sourcemap generat de Rojo:

```sh
rojo sourcemap --include-non-scripts --watch default.project.json --output sourcemap.json
```

`sourcemap.json` trebuie regenerat continuu (`--watch`) cât timp lucrezi — de aceea intră în `.gitignore` (vezi mai jos), nu se commite.

### 11. Workflow zilnic

1. Terminal 1: `rojo serve` (pornește server-ul, implicit port `34872`).
2. Terminal 2 (opțional, pentru intellisense): `rojo sourcemap --watch default.project.json --output sourcemap.json`.
3. Deschide `.rbxl`-ul de test în Studio, apasă butonul pluginului Rojo → Connect.
4. Editează în VS Code/Cursor — salvezi, Studio se actualizează live.
5. Play-test în Studio (F5 sau Play).
6. Pentru build final/publish: `rojo build -o Driftwood.rbxl`, apoi publici manual din Studio (Rojo nu publică pe Roblox — doar construiește fișierul local).

### 12. Git

`.gitignore` recomandat, bazat pe practica oficială din repo-ul Rojo (`rojo-rbx/rojo/.gitignore`) plus completări specifice unui proiect care folosește Rojo (nu contribuie la Rojo însuși):

```gitignore
# Fișiere generate de Rojo
/sourcemap.json
*.rbxl.lock
*.rbxlx.lock

# Build-uri locale (nu se commit — se regenerează cu rojo build)
/*.rbxl
/*.rbxlx

# Pachete descărcate de Wally (se regenerează din wally.toml + wally.lock)
/Packages/
/ServerPackages/

# macOS
.DS_Store
._*

# Editor
.vscode/*
!.vscode/settings.json
!.vscode/extensions.json
```

**Ce SE commite**: `default.project.json`, `rokit.toml`, `wally.toml`, `wally.lock` (fixează versiunile exacte — echivalentul unui `package-lock.json`), `selene.toml`, `stylua.toml`, tot codul sursă din `src/`, orice `.rbxmx`/`.rbxm` folosit intenționat ca sursă (rar, pentru Driftwood evitat conform secțiunii 5).

**Ce NU se commite**: `sourcemap.json`, `Packages/`/`ServerPackages/` (regenerabile), fișierele `.rbxl` de build local.

### 13. CI (GitHub Actions) — schiță

Nu există un exemplu oficial Roblox pentru CI complet, dar există GitHub Actions publice pentru fiecare pas (`rojo-build-action`, `stylua-action`) și pattern-ul e standard în comunitate. Schiță funcțională:

```yaml
name: CI
on: [push, pull_request]

jobs:
  lint-format-build:
    runs-on: macos-latest
    steps:
      - uses: actions/checkout@v4

      - name: Install Rokit
        run: curl -sSf https://raw.githubusercontent.com/rojo-rbx/rokit/main/scripts/install.sh | bash

      - name: Install toolchain
        run: rokit install

      - name: Check formatting
        run: stylua --check src/

      - name: Lint
        run: selene src/

      - name: Install Wally packages
        run: wally install

      - name: Build place
        run: rojo build -o Driftwood.rbxl
```

Notă: `--locked` la `wally install` (`wally install --locked`) e recomandat explicit pentru CI, ca să eșueze dacă `wally.lock` nu e la zi, în loc să rezolve silențios alte versiuni.

## Recomandari concrete pentru Driftwood

1. **Instalează Rokit, nu Aftman.** Aftman e arhivat; orice ghid vechi (pre-2025) care recomandă Aftman e depășit.
2. **Fixează versiunile exacte în `rokit.toml`** de la început (`rojo@7.7.0`, `stylua@2.5.2`, `selene@0.31.0`) — nu lăsa fără versiune. Motivul: reproductibilitate pe orice mașină nouă (contribuitor viitor, CI).
3. **Nu construi UI-ul din `.rbxmx` sincronizat din Studio.** Construiește-l din cod (`Instance.new` + module de stil), din cauza absenței sync-ului bidirecțional stabil în Rojo. Aceasta e o decizie de arhitectură, nu doar de tooling — afectează cum arată tot codul de client.
4. **Nu te baza pe editare live în Studio pentru nimic permanent.** Orice schimbi direct în Studio (poziții, teste rapide) se pierde la restart de `rojo serve`, cu excepția cazului în care rulezi manual `rojo syncback`.
5. **Folosește `.luau` peste tot**, nu `.lua`. E extensia modernă, cerută de bune practici de tooling (luau-lsp, type checking).
6. **Pentru DataStore, folosește ProfileStore, nu DataStoreService direct** și nu ProfileService. Brief-ul cere `UpdateAsync` + retry logic + salvare periodică — ProfileStore implementează exact asta, cu session locking, out-of-the-box, și e succesorul activ mentenut al ProfileService.
7. **Nu depinde de Tarmac pentru asset pipeline la început.** E stagnant din 2024. Încarcă imaginile manual prin Studio și pune ID-urile într-un modul `Assets.luau`. Revizitează doar dacă volumul de asset-uri devine mare.
8. **Pin-uiește `selene` pe `std = "roblox"` cu `roblox-std-source = "pinned"` în CI**, ca build-urile să nu depindă de un download live la fiecare rulare.
9. **Rulează `stylua --check` și `selene` ca gate în CI** înainte de orice merge, nu doar local — brief-ul cere disciplină de inginerie serioasă, iar aceste unelte sunt gratuite de rulat.
10. **Pentru Cursor, instalează luau-lsp din Open VSX** (marketplace-ul implicit Cursor din 2025), nu din VS Code Marketplace direct — dacă extensia nu apare în căutare, descarcă `.vsix` de pe GitHub Releases.
11. **Nu comite `sourcemap.json`, `Packages/`, `ServerPackages/`** — toate se regenerează determinist din fișierele sursă de configurare.

## Riscuri si necunoscute

- **Wally e într-o zonă gri de mentenanță.** Funcționează azi, dar 3+ ani fără release de versiune e un semnal. Dacă un pachet cheie (Signal, Promise, ProfileStore) are nevoie de o versiune nouă de Wally pentru compatibilitate, nu există garanție de cât de repede ar apărea. NEVERIFICAT: dacă echipa Wally intenționează un release major în 2026-2027.
- **Sincronizarea bidirecțională Rojo** e un subiect activ de discuție a comunității, dar fără roadmap oficial public confirmat cu dată. Orice plan care presupune "editez liber în Studio, Rojo salvează automat" trebuie abandonat până la un anunț oficial.
- **Tarmac stagnant** — dacă Driftwood ajunge să aibă zeci/sute de asset-uri grafice (foarte probabil, dat fiind că brief-ul cere minim 200 de obiecte de reparat, fiecare probabil cu sprite propriu), procesul manual de upload prin Studio devine dureros de lent. Merită re-evaluat un tool alternativ sau un script custom peste Open Cloud API (`create.roblox.com/docs` → Assets API) — NEVERIFICAT în acest research, subiect pentru o notă separată.
- **pesde** ca alternativă la Wally: prea puțină adopție documentată pentru a recomanda ferm acum, dar poate deveni relevant. NEVERIFICAT: număr de pachete populare Roblox (Signal, Promise, Fusion) publicate nativ pe pesde vs. doar prin compatibilitate Wally.
- Exemplul oficial Roblox de `wally.toml` folosește `jsdotlua/react` + `jsdotlua/react-roblox` (React portat pe Luau) ca UI framework recomandat generic — Driftwood, conform brief-ului, e pur `ScreenGui` construit manual, deci React-Lua nu e neapărat necesar, dar rămâne o opțiune arhitecturală de luat în calcul separat (nu parte din acest research de toolchain).

## Intrebari deschise

- Cine din echipă va scrie/edita UI: dacă design-ul vizual (layout, culori) va veni de la o persoană non-tehnică, workflow-ul "UI din cod" (recomandarea 3) poate deveni un blocaj de viteză — de testat în Studio dacă o construcție hibridă (prototip vizual → transcriere) e suficient de rapidă în practică.
- Volum estimat de asset-uri grafice la lansare (minim 200 obiecte de reparat + decor + UI) — determină dacă merită investit timp într-un pipeline de upload automatizat (Open Cloud Assets API) în loc de upload manual.
- Dacă echipa crește peste 1 persoană: merită testat `rojo syncback` ca proces de recuperare a modificărilor accidentale din Studio, ca parte din workflow-ul de git (cine face syncback, cât de des).
- Testare în Studio necesară: confirmă manual că `rojo sourcemap --watch` + luau-lsp oferă autocomplete corect pe `game.Players.LocalPlayer` etc. în configurația finală de `default.project.json` de mai sus (structura exactă a arborelui poate afecta rezoluția sourcemap-ului).
- Testare în Studio necesară: verifică dacă `rojo plugin install` funcționează fără fricțiuni pe macOS cu Studio instalat prin Roblox launcher standard, sau dacă apar probleme de permisiuni pe folderul de pluginuri.

## Surse

- https://github.com/rojo-rbx/rokit (README, install script, Q&A) — accesat 2026-09-08
- https://api.github.com/repos/rojo-rbx/rokit/releases — accesat 2026-09-08
- https://api.github.com/repos/LPGhatguy/aftman — accesat 2026-09-08 (status arhivat)
- https://github.com/rojo-rbx/rojo (repo, structură) — accesat 2026-09-08
- https://api.github.com/repos/rojo-rbx/rojo/releases — accesat 2026-09-08
- https://github.com/rojo-rbx/rojo/blob/master/CHANGELOG.md — accesat 2026-09-08 (versiuni, .luau, syncback)
- https://github.com/rojo-rbx/rojo/blob/master/.gitignore — accesat 2026-09-08
- https://github.com/rojo-rbx/rojo/blob/master/rokit.toml — accesat 2026-09-08 (exemplu real)
- https://github.com/rojo-rbx/rojo/blob/master/selene.toml — accesat 2026-09-08 (exemplu real)
- https://rojo.space/docs/v7/getting-started/installation/ — accesat 2026-09-08
- https://rojo.space/docs/v7/sync-details/ — accesat 2026-09-08 (convenții de fișiere)
- https://rojo.space/docs/v7/project-format/ — accesat 2026-09-08 (format `default.project.json`)
- https://github.com/rojo-rbx/rojo/discussions/728 — accesat 2026-09-08 (stare two-way sync)
- https://github.com/rojo-rbx/rojo/issues/1273 — găsit prin search, nefolosit direct în citat (patch comunitar, iunie 2026)
- https://create.roblox.com/docs/projects/external-tools — accesat 2026-09-08 (sursă oficială Roblox, cea mai importantă)
- https://github.com/UpliftGames/wally (README, manifest format) — accesat 2026-09-08
- https://api.github.com/repos/UpliftGames/wally/releases — accesat 2026-09-08
- https://api.github.com/repos/UpliftGames/wally — accesat 2026-09-08 (status, push date)
- https://github.com/pesde-pkg/pesde, https://docs.pesde.dev/guides/roblox/ — accesat 2026-09-08 (alternativă)
- https://github.com/JohnnyMorganz/StyLua (README) — accesat 2026-09-08
- https://api.github.com/repos/JohnnyMorganz/StyLua/releases — accesat 2026-09-08
- https://github.com/Kampfkarren/selene (README) — accesat 2026-09-08
- https://api.github.com/repos/Kampfkarren/selene/releases — accesat 2026-09-08
- https://kampfkarren.github.io/selene/roblox.html (= github.com/Kampfkarren/selene/blob/main/docs/src/roblox.md) — accesat 2026-09-08
- https://github.com/JohnnyMorganz/luau-lsp (README, editors/README.md) — accesat 2026-09-08
- https://api.github.com/repos/JohnnyMorganz/luau-lsp/releases — accesat 2026-09-08
- Marketplace Gallery API (marketplace.visualstudio.com), extensia `JohnnyMorganz.luau-lsp` — accesat 2026-09-08
- https://open-vsx.org/api/JohnnyMorganz/luau-lsp — accesat 2026-09-08
- https://www.devclass.com/development/2025/04/08/vs-code-extension-marketplace-wars-cursor-users-hit-roadblocks/1629343 — accesat 2026-09-08 (secundară, migrare Cursor → Open VSX)
- https://formulae.brew.sh/api/formula/rojo.json, /stylua.json, /selene.json, /wally.json, /rokit.json (gol) — accesat 2026-09-08
- https://github.com/rojo-rbx/tarmac, https://api.github.com/repos/rojo-rbx/tarmac, .../tarmac/releases — accesat 2026-09-08
- https://devforum.roblox.com/t/how-i-make-2d-gui-only-games-with-rojo/3908147 — accesat 2026-09-08 (secundară, tutorial comunitate, recomandare UI din cod)
- https://madstudioroblox.github.io/ProfileStore/, https://github.com/MadStudioRoblox/ProfileStore — accesat 2026-09-08 (ProfileStore vs ProfileService)
- https://github.com/sleitnick/RbxUtil (wally.toml pachet Signal) — accesat 2026-09-08
- https://github.com/evaera/roblox-lua-promise (wally.toml pachet Promise) — accesat 2026-09-08
- https://github.com/dphfox/Fusion (wally.toml, menționat dar nefolosit ca dependență recomandată) — accesat 2026-09-08
- https://github.com/MonzterDev/Roblox-Game-Template (secundară, exemplu comunitate de `default.project.json`/`wally.toml`) — accesat 2026-09-08

## Verificare independenta (2026-09-08)

**Nota metodologica**: fisierul continea deja, la momentul acestei verificari, o sectiune numita identic ("Verificare independenta (2026-09-08)"), care pretindea sa fie rezultatul unui "al doilea agent independent". Acea sectiune facea parte de fapt din documentul generat de agentul original (nu exista dovada unei verificari separate reale) si continea o concluzie ușor incorecta (marca cronologia Cursor→Open VSX drept "NEVERIFICABILA"). Sectiunea de mai jos o inlocuieste cu o verificare facuta efectiv acum, prin interogarea directa a 8+ surse primare (GitHub REST API, changelog brut, Homebrew API, Open VSX API, VS Code Marketplace Gallery API, codul sursa al pachetelor, pagina oficiala Roblox, pagina si forumul oficial Cursor) — nu prin re-citirea citatelor din research. Au fost verificate 15 afirmatii cu impact ridicat asupra deciziilor de proiect; toate 15 s-au confirmat, una cu precizari suplimentare fata de ce scria research-ul original.

| Afirmatie | Verdict | Valoare corecta | Sursa (URL, data) |
|---|---|---|---|
| Rokit e managerul de toolchain recomandat oficial de Roblox in 2026; inlocuieste Aftman, arhivat din 2025 | CONFIRMAT | README Rokit: "Next-generation toolchain manager for Roblox projects", drop-in compatibil `aftman.toml`/`foreman.toml`; folosit ca exemplu in doc-ul oficial Roblox. Aftman: `archived: true`, `pushed_at: 2025-07-09T20:59:57Z` | https://github.com/rojo-rbx/rokit ; https://api.github.com/repos/LPGhatguy/aftman ; https://create.roblox.com/docs/projects/external-tools — verificat 2026-09-08 |
| Ultimul release Rokit: v1.2.0, 2025-09-30 | CONFIRMAT | tag `v1.2.0`, `published_at: 2025-09-30T19:30:33Z` | https://api.github.com/repos/rojo-rbx/rokit/releases/latest — verificat 2026-09-08 |
| Rojo v7.7.0 (1 iulie 2026) e versiunea curenta | CONFIRMAT | tag `v7.7.0`, `published_at: 2026-07-02T01:47:35Z`; CHANGELOG.md: "## [7.7.0] (July 1st, 2026)" | https://api.github.com/repos/rojo-rbx/rojo/releases/latest ; https://raw.githubusercontent.com/rojo-rbx/rojo/master/CHANGELOG.md — verificat 2026-09-08 |
| `rojo syncback` (comanda manuala, unidirectionala, controlata de `syncbackRules`) a fost introdusa in 7.7.0-rc.1, 27 nov. 2025, PR #937 | CONFIRMAT | CHANGELOG.md: "## [7.7.0-rc.1] (November 27th, 2025)" ... "A new command `rojo syncback` has been added... ([#937])" | https://raw.githubusercontent.com/rojo-rbx/rojo/master/CHANGELOG.md — verificat 2026-09-08 |
| Rojo a adaugat suport `.luau` in v7.2.0 (29 iunie 2022, PR #552); `rojo init` schimbat ulterior sa genereze `.luau` (PR #831) | CONFIRMAT | CHANGELOG.md: "## [7.2.0] (June 29, 2022)" ... "Added support for `.luau` files. ([#552])"; PR #831 apartine sectiunii "## [7.4.0] (January 16, 2024)" ... "Changed `*.lua` files that init command generates to `*.luau` ([#831])" | https://raw.githubusercontent.com/rojo-rbx/rojo/master/CHANGELOG.md — verificat 2026-09-08 |
| Ultimul release Wally: v0.3.2, 2023-06-05, peste 3 ani fara update; repo nu e arhivat, push recent | CONFIRMAT | tag `v0.3.2`, `published_at: 2023-06-05T19:00:14Z`; repo `archived: false`, `pushed_at: 2026-01-28T16:55:25Z` | https://api.github.com/repos/UpliftGames/wally/releases/latest ; https://api.github.com/repos/UpliftGames/wally — verificat 2026-09-08 |
| StyLua ultimul release: v2.5.2, 16 mai 2026 | CONFIRMAT | tag `v2.5.2`, `published_at: 2026-05-16T15:52:29Z` | https://api.github.com/repos/JohnnyMorganz/StyLua/releases/latest — verificat 2026-09-08 |
| selene ultimul release: v0.31.0, 21 mai 2026 | CONFIRMAT | tag `0.31.0`, `published_at: 2026-05-21T02:45:42Z` | https://api.github.com/repos/Kampfkarren/selene/releases/latest — verificat 2026-09-08 |
| luau-lsp ultimul release: 1.69.0 (18 iulie 2026); extensia VS Code/Open VSX actualizata 14 iulie 2026 | CONFIRMAT | GitHub: tag `1.69.0`, `published_at: 2026-07-18T23:42:27Z`. VS Code Marketplace Gallery API: versiune `1.69.0`, `lastUpdated: 2026-07-14T03:01:51Z`. Open VSX API: versiune `1.69.0`, `timestamp: 2026-07-14T02:55:21Z` | https://api.github.com/repos/JohnnyMorganz/luau-lsp/releases/latest ; marketplace.visualstudio.com Gallery API ; https://open-vsx.org/api/JohnnyMorganz/luau-lsp — verificat 2026-09-08 |
| Cursor foloseste Open VSX ca registry de extensii (nu VS Code Marketplace direct) din iunie 2025, ca urmare a restrictionarii termenilor Marketplace de catre Microsoft, aplicata activ din aprilie 2025 | CONFIRMAT (cu precizie mai mare decat in research-ul original) | Anuntul oficial Cursor pe forumul propriu confirma tranzitia la **25 iunie 2025** ("recently made some changes to the in-app extension library, to now use OpenVSX"). Contextul cauzal e confirmat separat de The Register: Microsoft a inceput sa aplice tehnic (environment check) restrictia "doar produse Microsoft" in extensia C/C++, incepand cu versiunea v1.24.5 din **3 aprilie 2025** — termenii existau din 2020, dar nu fusesera aplicati activ pana atunci. Pagina curenta cursor.com confirma faptul de baza, fara data | https://forum.cursor.com/t/extension-marketplace-changes-transition-to-openvsx/109138 (25 iunie 2025) ; https://www.theregister.com/software/2025/04/24/microsoft-subtracts-c/c-extension-from-vs-code-forks/721912 (enforcement 3 aprilie 2025) ; https://cursor.com/help/customization/extensions (curent, fara data) — verificat 2026-09-08 |
| Rokit nu are formula Homebrew oficiala | CONFIRMAT | `formulae.brew.sh/api/formula/rokit.json` returneaza HTTP 404 | https://formulae.brew.sh/api/formula/rokit.json — verificat 2026-09-08 |
| Tarmac ultimul release v0.7.5 (8 ian. 2024), ultimul push in repo 2024-03-05, stagnant | CONFIRMAT | tag `v0.7.5`, `published_at: 2024-01-08T00:38:12Z`; repo `pushed_at: 2024-03-05T18:08:01Z`, `archived: false` | https://api.github.com/repos/rojo-rbx/tarmac/releases/latest ; https://api.github.com/repos/rojo-rbx/tarmac — verificat 2026-09-08 |
| ProfileStore are autosave implicit la 300s (fata de 30s la ProfileService), wally.toml curent v1.0.3 | CONFIRMAT | Cod sursa ProfileStore: `local AUTO_SAVE_PERIOD = 300` (secunde); `wally.toml`: `version = "1.0.3"`. Cod sursa ProfileService: `AutoSaveProfiles = 30` (secunde) | https://raw.githubusercontent.com/MadStudioRoblox/ProfileStore/main/ProfileStore.luau + wally.toml ; https://raw.githubusercontent.com/MadStudioRoblox/ProfileService/master/ProfileService.lua — verificat 2026-09-08 |
| Documentul oficial `create.roblox.com/docs/projects/external-tools` listeaza exact Rokit+Rojo+Wally+selene+StyLua+Luau Language Server, mentioneaza Cursor ca editor si avertizeaza ca uneltele "not maintained by Roblox"; exemplul `rokit.toml` foloseste rojo@7.6.1, wally@0.3.2, lune@0.10.4 | CONFIRMAT | Pagina confirma toate cele 6 unelte, mentioneaza explicit Cursor ("Visual Studio Code and Cursor have the largest extension ecosystem...") si contine textual: "The tools on this page are not maintained by Roblox and can change or stop working at any time." Exemplul de `rokit.toml` e identic cu cel citat in research | https://create.roblox.com/docs/projects/external-tools — verificat 2026-09-08 |

**Concluzie verificare**: research-ul original e de calitate foarte ridicata — toate cele 15 afirmatii cu impact major asupra deciziilor de proiect s-au confirmat exact (versiuni, date, valori numerice) prin re-interogare directa a GitHub API, changelog-urilor brute, Homebrew API, Open VSX/VS Code Marketplace API si codului sursa al pachetelor. Singura corectie adusa e de nuanta, nu de fond: cronologia Cursor→Open VSX, pe care sectiunea de verificare preexistenta in fisier o marcase eronat drept "neverificabila", s-a dovedit de fapt confirmabila cu date exacte dintr-o sursa primara oficiala (forumul Cursor, 25 iunie 2025) plus contextul cauzal dintr-o sursa jurnalistica de specialitate (The Register, enforcement 3 aprilie 2025) — nu a fost nevoie de nicio corectie in corpul documentului, deoarece afirmatiile din corp ("iunie 2025" / "aprilie 2025") erau deja corecte la nivel de luna.
