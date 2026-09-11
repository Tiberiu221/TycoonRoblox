# Ecosistemul de framework-uri și librării Luau pentru Roblox (stare la 2026-09-08)

## Rezumat executiv

- **Knit e mort.** Arhivat oficial de Sleitnick pe 31 iulie 2024, banner explicit „No Longer Maintained". Nu se pornește un proiect nou cu Knit în 2026.
- **Roact e mort oficial.** Arhivat de Roblox pe 13 decembrie 2023, README-ul spune explicit să folosești `react-lua`. Roact nu mai e o opțiune serioasă.
- **Networking cu buffer/binary (Zap, Blink, ByteNet) a înlocuit RemoteEvents brute** ca standard de facto pentru orice proiect nou cu trafic de rețea semnificativ. Zap e cel mai matur (0.6.x, semnat criptografic, release pe 23 iunie 2026); Blink e încă pre-1.0 (v1.0.0-pre.7, 24 august 2026) dar cu autocomplete în Studio.
- **Red (predecesorul lui Zap, tot de la red-blox) a fost arhivat pe 23 decembrie 2025** — confirmă că echipa red-blox a consolidat totul pe Zap.
- **ProfileService e oficial deprecated în favoarea ProfileStore** — README-ul ProfileService spune textual „FOR NEW PROJECTS - USE ProfileStore". Pentru Driftwood, alegerea e ProfileStore, nu ProfileService.
- **Pentru ECS: jecs e mult mai activ decât Matter** în 2026 (push la 28 iulie 2026 vs. ultimul push al Matter la 31 decembrie 2024, cu 37 de issue-uri deschise nerezolvate). Totuși, pentru un joc 2D bazat pe Frame-uri ca Driftwood, un ECS complet e probabil supra-inginerie — de evaluat ca opțional, nu ca bază.
- **UI reactiv e fragmentat pe trei tabere fără un câștigător clar**: Fusion (0.3-beta stabil, dar 0.4 e în dezvoltare activă pe branch-ul principal, deci API-ul se va schimba), Vide (cel mai activ commit-wise, inspirat din Solid.js, foarte mic ca API), react-lua (fork comunitar al mirror-ului intern Roblox, cel mai apropiat de React clasic, dar fără commit nou din mai 2025).
- **Wally, registry-ul standard, nu a mai avut un release stabil din 5 iunie 2023** (peste 3 ani). Există commit-uri nepublicate pe branch-ul principal, deci nu e abandonat, dar nici activ împins către utilizatori. Există o alternativă nouă, `pesde`, dar adopția ei nu poate fi verificată din sursele consultate.
- **roblox-ts e viabil și activ** (v3.0.0 lansat 12 septembrie 2024, 1.3k stars, activitate constantă), dar aduce un pas de compilare suplimentar și fricțiune cu majoritatea resurselor comunității care sunt în Luau nativ.
- **Recomandarea de bază pentru Driftwood**: Luau nativ (nu roblox-ts) + Zap pentru networking + ProfileStore pentru date + Trove/Signal din RbxUtil pentru cleanup + un strat imperativ (nu reactiv) pentru obiectele râului care se mișcă în fiecare frame, cu Vide sau Fusion 0.3 doar pentru UI de tip „chrome" (HUD, atelier, index de colecție).

## Fapte verificate

- Knit (Sleitnick/Knit) a fost arhivat pe 31 iulie 2024, README afișează „No Longer Maintained"; 630 stars, 109 forks, 0 issue-uri deschise. — sursă: https://github.com/Sleitnick/Knit (fetch 2026-09-08) — încredere: ridicata
- Roact (Roblox/roact) a fost arhivat pe 13 decembrie 2023, README: „This repository is deprecated and no longer maintained. See react-lua for our currently maintained React in Lua library." — sursă: https://github.com/Roblox/roact (fetch 2026-09-08) — încredere: ridicata
- Flamework (rbxts-flamework/core): 158 stars, ultimul push 2025-09-04, 12 issue-uri deschise, licență MIT, necesită roblox-ts. — sursă: https://api.github.com/repos/rbxts-flamework/core (fetch 2026-09-08) — încredere: ridicata
- Zap (red-blox/zap): ultimul push 2026-06-23, branch implicit `0.6.x`, ultimul tag `v0.6.29` datat 23 iunie 2026, semnat GPG de sasial-dev; 187 stars, 9 issue-uri deschise. Un rewrite e în lucru pe alt branch, dar `0.6.x` rămâne susținut. — sursă: https://github.com/red-blox/zap/tags și https://api.github.com/repos/red-blox/zap (fetch 2026-09-08) — încredere: ridicata
- Blink (1Axen/blink): ultimul push 2026-08-24, ultima versiune `v1.0.0-pre.7` (24 august 2026); 181 stars, 11 issue-uri deschise; recunoaște explicit inspirația din sintaxa Zap pentru range/array. — sursă: https://github.com/1Axen/blink/releases și API (fetch 2026-09-08) — încredere: ridicata
- Red (red-blox/Red), predecesorul lui Zap: **arhivat pe 23 decembrie 2025**; 56 stars. — sursă: https://github.com/red-blox/Red (fetch 2026-09-08) — încredere: medie (data exactă nu a putut fi verificată printr-un al doilea fetch independent)
- ByteNet (ffrostfall/ByteNet): networking pe bază de buffer, 179 stars, activ (78 commits, 14 issue-uri deschise); se compară explicit cu BridgeNet2, nu cu Zap/Blink. — sursă: https://github.com/ffrostfall/ByteNet (fetch 2026-09-08) — încredere: medie
- Matter (matter-ecs/matter): ultimul push **2024-12-31**, 37 issue-uri deschise, 115 stars; scope-ul a migrat de la `evaera/matter` la `matter-ecs/matter` (predare comunitară). — sursă: https://api.github.com/repos/matter-ecs/matter (fetch 2026-09-08) — încredere: ridicata
- jecs (Ukendio/jecs): ultimul push **2026-07-28**, 464 stars, 15 issue-uri deschise; ultimul tag confirmat `v0.11.0` (10 martie 2026); pretinde iterare peste 800.000 de entități la 60 fps prin stocare arhetip/SoA. — sursă: https://api.github.com/repos/Ukendio/jecs și https://github.com/Ukendio/jecs/tags (fetch 2026-09-08) — încredere: ridicata
- Fusion (dphfox/Fusion): ultima versiune stabilă `v0.3-beta`, publicată 30 august 2024; ultimul push al repo-ului 2026-02-02; 795 stars, 64 issue-uri deschise. Pe branch-ul `main`, `wally.toml` arată `version = "0.4.0-dev1"` — Fusion 0.4 e în dezvoltare activă, nu lansat. — sursă: https://github.com/dphfox/Fusion/tags și https://raw.githubusercontent.com/dphfox/Fusion/main/wally.toml (fetch 2026-09-08) — încredere: ridicata
- react-lua (jsdotlua/react-lua): ultimul tag `v17.2.1` (4 decembrie 2024); ultimul push al repo-ului **2025-05-23** (peste 15 luni fără activitate până la 2026-09-08); 568 stars, ~20 issue-uri deschise. E un fork comunitar al mirror-ului read-only publicat de Roblox intern. — sursă: https://api.github.com/repos/jsdotlua/react-lua și https://github.com/jsdotlua/react-lua/tags (fetch 2026-09-08) — încredere: ridicata
- Vide (centau/vide): ultimul push **2026-08-05**, 322 stars, 12 issue-uri deschise; bibliotecă reactivă inspirată din Solid.js, documentație la centau.github.io/vide. — sursă: https://api.github.com/repos/centau/vide (fetch 2026-09-08) — încredere: ridicata
- Iris (SirMallard/Iris, fostă Michael_48/Iris): 348 stars, GUI immediate-mode stil Dear ImGui, explicit orientată spre unelte de debug/vizualizare, nu spre UI de joc pentru jucători. — sursă: https://github.com/SirMallard/Iris (fetch 2026-09-08) — încredere: medie
- ProfileStore (MadStudioRoblox/ProfileStore): ultimul push 2025-07-31, 333 stars, 6 issue-uri deschise; descris ca „a Roblox DataStore wrapper that streamlines auto-saving, session locking". — sursă: https://api.github.com/repos/MadStudioRoblox/ProfileStore (fetch 2026-09-08) — încredere: ridicata
- ProfileService (MadStudioRoblox/ProfileService): README conține explicit „FOR NEW PROJECTS - USE ProfileStore" și „This project is no longer supported - it's been stable for a long while and migration to ProfileStore is possible for most projects"; ultimul push 2024-10-13. — sursă: https://raw.githubusercontent.com/MadStudioRoblox/ProfileService/master/README.md (fetch 2026-09-08) — încredere: ridicata
- Promise (evaera/roblox-lua-promise): ultima versiune stabilă `v4.0.0`, 3 martie 2024; ultimul push al repo-ului 2024-08-06; 352 stars. Considerat feature-complete, nu abandonat. — sursă: https://github.com/evaera/roblox-lua-promise (fetch 2026-09-08) — încredere: medie (data exactă a v4.0.0 din sumarul paginii de releases, neconfirmată printr-un al doilea fetch)
- LemonSignal (Data-Oriented-House/LemonSignal): ultimul push **2026-07-13**, 51 stars, 0 issue-uri deschise; se descrie ca „faster than most other implementations in Roblox". — sursă: https://api.github.com/repos/Data-Oriented-House/LemonSignal (fetch 2026-09-08) — încredere: ridicata
- GoodSignal (stravant/goodsignal): 69 stars, 18 forks; implementare pură Lua fără BindableEvent, considerată stabilă/feature-complete, fără activitate recentă vizibilă. — sursă: https://github.com/stravant/goodsignal (fetch 2026-09-08) — încredere: medie (data ultimului commit nu a putut fi extrasă)
- RbxUtil (Sleitnick/RbxUtil) conține Trove ca modul inclus (36 module în total: Trove, Signal, Comm, Net, TableUtil, Option etc.); versiune exemplu văzută în dependințe: `sleitnick/trove@1.8.0`; 463 stars, 534 commits. — sursă: https://github.com/Sleitnick/RbxUtil (fetch 2026-09-08) — încredere: medie
- Janitor (howmanysmall/Janitor): 148 stars, are binding TypeScript (`@rbxts/janitor`), documentație la docs.howmanysmall.com/Janitor/, aparent activ menținut. — sursă: https://github.com/howmanysmall/Janitor (fetch 2026-09-08) — încredere: medie
- NevermoreEngine / Maid (Quenty/NevermoreEngine): 611 stars, 5.887 commits, 278 pachete; documentația afirmă „Code in Nevermore has powered over a billion play sessions on Roblox" și e folosit „in all Studio Koi Koi games". — sursă: https://github.com/Quenty/NevermoreEngine (fetch 2026-09-08) — încredere: medie (afirmația „billion play sessions" e a autorului, nu verificată independent)
- Sift (csqrl/sift): README conține explicit „Sift is no longer actively maintained. If you'd like to contribute, consider creating a fork."; 92 stars; bazat pe Llama (freddylist/llama). — sursă: https://github.com/csqrl/sift (fetch 2026-09-08) — încredere: ridicata
- Llama (freddylist/llama): predecesorul lui Sift; date exacte (stars, ultimul push) NEVERIFICAT — limita de rate a GitHub API a fost atinsă în timpul cercetării și nu a fost re-verificat separat. — încredere: scazuta
- Wally (UpliftGames/wally): ultimul tag stabil **`v0.3.2`, 5 iunie 2023** — peste 3 ani fără release stabil la data cercetării; CHANGELOG.md are o secțiune „Unreleased Changes" cu modificări necontopite într-un release (`--locked` flag, îmbunătățiri lockfile); 494 stars, 57 issue-uri deschise, 34 PR-uri deschise. Limită documentată: pachetele peste 2MB sunt respinse de CLI la publicare. — sursă: https://raw.githubusercontent.com/UpliftGames/wally/main/CHANGELOG.md și https://github.com/UpliftGames/wally/tags (fetch 2026-09-08) — încredere: ridicata
- Pesde (pesde.dev, autor daimond113): package manager alternativ pentru Luau, suportă atât Roblox cât și runtime-ul Lune; pachete publicate cu versiuni între v0.1.0 și v1.4.0-rc.1; comparație directă cu Wally NEVERIFICAT din sursele consultate. — sursă: https://pesde.dev (fetch 2026-09-08) — încredere: scazuta
- roblox-ts (roblox-ts/roblox-ts): versiunea majoră curentă `v3.0.0`, lansată **12 septembrie 2024**; 1.300 stars, 2.473 commits, 117 issue-uri deschise; se instalează cu `npm init roblox-ts`. Cerințe exacte de versiune Node/TypeScript: NEVERIFICAT din documentația accesată. — sursă: https://github.com/roblox-ts/roblox-ts/tags (fetch 2026-09-08) — încredere: ridicata pentru versiune, scazuta pentru cerințele Node
- Rokit (rojo-rbx/rokit): manager de toolchain pentru CLI-urile din ecosistemul Roblox (Rojo, Wally, Zap etc.), suportă explicit macOS și Linux printr-un script automat; compatibil drop-in cu fișierele de configurare Aftman/Foreman, poziționat ca succesor deoarece „they have an uncertain future as toolchain managers for the community"; 449 stars. — sursă: https://github.com/rojo-rbx/rokit (fetch 2026-09-08) — încredere: ridicata
- DataStoreService — pagina oficială de documentație a fost accesată cu succes, confirmând acces valid la create.roblox.com/docs; conținut detaliat nu a fost extras (nu era ținta principală a acestei cercetări). — sursă: https://create.roblox.com/docs/reference/engine/classes/DataStoreService (fetch 2026-09-08) — încredere: medie

## Detalii

### Framework-uri „all-in-one" (Knit, Flamework)

**Knit** (Sleitnick) a fost, până în 2024, standardul de facto pentru arhitectura client-server la proiecte Luau native: servicii pe server, controllere pe client, comunicare automată prin Remote-uri generate. Repo-ul a fost **arhivat pe 31 iulie 2024** cu un mesaj explicit de „no longer maintained" și un fișier `ARCHIVAL.md` care explică decizia. Nu a fost șters — codul rămâne funcțional și mulți dezvoltatori încă îl folosesc în proiecte existente — dar nu primește niciun update, patch de securitate sau suport pentru schimbări viitoare din motorul Roblox. **Pentru un proiect nou în 2026, Knit nu e o alegere apărabilă.**

**Flamework** e echivalentul pentru ecosistemul roblox-ts: framework bazat pe decoratori TypeScript (`@Controller`, `@Service`, dependency injection), documentat la flamework.fireboltofdeath.dev. Ultimul push a fost pe 4 septembrie 2025 — la un an distanță de data cercetării, cu 12 issue-uri deschise nerezolvate. Nu e arhivat și nu are un anunț de abandon, dar ritmul de commit-uri s-a redus vizibil. Flamework e relevant **doar dacă** Driftwood ar adopta roblox-ts (vezi secțiunea dedicată mai jos); pentru Luau nativ nu se aplică.

**Concluzie:** niciun framework „all-in-one" nu mai e o alegere sigură pentru proiect nou. Pattern-ul recomandat de comunitate în 2025-2026 e compoziția manuală din librării mici, cu scop unic (networking separat, cleanup separat, date separate) — exact abordarea recomandată mai jos pentru Driftwood.

### Networking: Zap vs. Blink vs. ByteNet vs. Red

Toate patru sunt **generatoare de cod** (compilatoare IDL scrise în Rust, rulate ca CLI la build-time), nu librării Luau instalate prin Wally direct — ele citesc un fișier de schemă (`.zap` / `.blink`) și generează un fișier `.luau` cu funcții tipizate pentru trimis/primit date prin `RemoteEvent`/`UnreliableRemoteEvent`, serializate în `buffer` binar în loc de tabele Lua obișnuite. Avantajul central: lățime de bandă mult redusă și validare automată a datelor primite de la client (server nu are încredere implicită în input).

| Proiect | Status 2026 | Ultima versiune confirmată | Ultimul push | Note |
|---|---|---|---|---|
| **Zap** (red-blox) | Activ | v0.6.29 (23 iun 2026) | 2026-06-23 | Branch implicit `0.6.x`; rewrite în lucru pe alt branch; release-uri semnate GPG |
| **Blink** (1Axen) | Activ, pre-1.0 | v1.0.0-pre.7 (24 aug 2026) | 2026-08-24 | Plugin de autocomplete în Studio; sintaxă inspirată din Zap |
| **ByteNet** (ffrostfall) | Activ | NEVERIFICAT | — | Se compară cu BridgeNet2, nu cu Zap/Blink direct |
| **Red** (red-blox) | **Arhivat** (23 dec 2025) | — | — | Predecesorul lui Zap; superseded intern de red-blox însuși |

**Pentru Driftwood**, traficul de rețea relevant e: poziția/tipul obiectelor care apar pe râu (broadcast frecvent, tolerant la pierdere → candidat pentru `UnreliableRemoteEvent`), evenimentele de „prins în plasă" (trebuie fiabile, validate server-side împotriva cheat-urilor de poziție/timp), progresul reparațiilor și donațiile la atelier (fiabile, rate redusă). Zap acoperă exact acest tipar cu tipurile `event` (reliable/unreliable) declarate în schema `.zap`. Exemplu de schemă minimală relevantă:

```
-- network.zap
opt namespace = "Net"

type CatchId = u16

event CatchRequest = {
    from: Client,
    type: Reliable,
    call: SingleSync,
    data: struct {
        netId: CatchId,
        clientTimestamp: f64,
    },
}

event RiverSpawn = {
    from: Server,
    type: Unreliable,
    call: SingleSync,
    data: struct {
        itemId: u16,
        x: f32,
        y: f32,
    },
}
```

Codul generat (`network.luau`) e commit-uit direct în repo, nu instalat prin Wally — asta înseamnă că CLI-ul `zap` trebuie instalat local (prin Rokit, vezi mai jos) doar de dezvoltatori, nu și rulat la runtime.

### ECS: Matter vs. jecs

Ambele implementează arhitectura Entity-Component-System în Luau pur. Diferența majoră observată: **jecs e semnificativ mai activ** — push la 28 iulie 2026, față de ultimul push al Matter la 31 decembrie 2024 (peste un an și jumătate de inactivitate relativă) și 37 de issue-uri deschise nerezolvate. jecs pretinde performanță mult mai bună prin stocare arhetip/structură-de-array-uri (claim: 800.000 entități la 60 fps) și tratează relațiile între entități ca cetățeni de prim rang în API.

**Relevanță pentru Driftwood: scăzută-medie.** Jocul e descris explicit ca „2D pur în ScreenGui" cu coliziuni AABB simple — nu are mii de entități simultane cu comportamente eterogene care ar justifica arhitectura ECS clasică. Numărul de obiecte pe râu la un moment dat e probabil în zeci, nu în mii. Un ECS complet (Matter sau jecs) aduce beneficii clare când ai sute-mii de entități cu query-uri complexe pe combinații de componente — nu e cazul unui joc de tip Stardew 2D. Recomandarea e să **nu** se adopte ECS de la început; dacă mai târziu apare nevoie reală (ex: sute de obiecte simultane pe hartă cu comportamente diverse), jecs e alegerea cu mentenanță activă, nu Matter.

### UI reactiv: Fusion, react-lua, Vide, Roact (mort), Iris (nu e pentru asta)

| Bibliotecă | Autor/Org | Stele | Ultimul push | Status | Potrivire cu UI-heavy 2D |
|---|---|---|---|---|---|
| Roact | Roblox (arhivă) | — | 2023-12-13 | **Arhivat/deprecated oficial** | Nu se folosește pentru proiect nou |
| react-lua | jsdotlua (fork comunitar) | 568 | 2025-05-23 | Stagnant (~15 luni fără commit) | Ecosistem matur, dar risc de abandon |
| Fusion | dphfox (Elttob) | 795 | 2026-02-02 | Activ, dar în tranziție (0.3 stabil, 0.4-dev pe main) | Bun, dar API instabil pe termen mediu |
| Vide | centau | 322 | 2026-08-05 | Cel mai activ dintre cele trei | Foarte potrivit — granular, mic, rapid |
| Iris | SirMallard | 348 | — | Activ, dar **nu e pentru UI de joc** | Nepotrivit (e pentru unelte de debug) |

**Roact** e mort oficial — Roblox însuși spune să folosești react-lua. Nu se ia în calcul.

**react-lua** e traducerea comunitară a bibliotecii interne folosite chiar de echipa de inginerie Roblox (repo-ul oficial `Roblox/react-lua` e doar o oglindă read-only fără istoric de commit-uri; dezvoltarea reală se face în fork-ul `jsdotlua/react-lua`, publicat pe Wally/npm). E cel mai apropiat de React clasic (hooks, componente funcționale, `react-roblox` ca renderer echivalent lui `react-dom`), ceea ce contează dacă echipa are deja experiență React. Riscul: **niciun commit din mai 2025** — la peste un an de la data cercetării, semn de scădere a ritmului de mentenanță a fork-ului comunitar, chiar dacă API-ul e stabil (React 17.x e „finished", nu are nevoie de features noi frecvent).

**Fusion** e cea mai populară bibliotecă „nativă Luau" pentru UI reactiv (795 stars, cea mai mare din grup), cu concepte proprii (`scoped`, `New`, `Computed`, `Observer`) inspirate parțial din SolidJS dar cu sintaxă proprie. Problema pentru un plan serios: **v0.3-beta e ultima versiune lansată** (30 august 2024), dar `wally.toml` de pe branch-ul `main` arată deja `0.4.0-dev1` — autorul lucrează activ la o rescriere a internals-urilor (memory management, context sharing). Asta înseamnă că orice cod scris azi pe 0.3 va necesita muncă de migrare când 0.4 devine stabil, fără dată anunțată public verificabilă.

**Vide** e cea mai mică și mai activă alternativă (ultimul push 5 august 2026, cu doar 30 de zile înainte de data cercetării). Inspirată explicit din Solid.js, cu reactivitate granulară (fiecare `source()` urmărește exact ce citește, fără re-render de componente întregi). API-ul e mult mai mic decât Fusion sau react-lua, ceea ce reduce suprafața de risc de breaking changes.

**Iris** nu e o alternativă validă pentru UI de jucător — e explicit un GUI immediate-mode stil Dear ImGui, gândit pentru panouri de debug/dezvoltator, nu pentru interfețe polizate cu care interacționează jucătorii.

### Date persistente: ProfileStore (nu ProfileService)

ProfileService (Madwork/MadStudioRoblox), timp de ani standardul absolut pentru salvare cu session-locking, e acum **explicit marcat ca succedat**: README-ul propriu spune „FOR NEW PROJECTS - USE ProfileStore" și „This project is no longer supported — it's been stable for a long while and migration to ProfileStore is possible for most projects." ProfileStore, de la același autor (loleris/MadStudioRoblox), continuă API-ul de session-locking + auto-save periodic, dar cu îmbunătățiri interne. Pentru Driftwood, care are cerința explicită din brief „`UpdateAsync`, nu `SetAsync`, cu retry logic, salvare la ieșire ȘI periodic la 2 minute" — ProfileStore acoperă exact acest tipar din cutie (auto-save periodic configurabil + save la `PlayerRemoving` + session locking împotriva duplicării progresului dacă serverul crapă).

### Semnale și cleanup: Signal/Trove (RbxUtil) vs. alternative

Pentru semnale custom (evenimente interne, nu `RBXScriptSignal`), trei familii principale:
- **GoodSignal** (stravant) — implementarea originală „pură Lua", stabilă, fără BindableEvent-uri (evită leak-uri de memorie asociate). Nu mai are activitate vizibilă recentă, dar e considerată feature-complete — multe alte librării (inclusiv Signal din RbxUtil) sunt derivate din designul ei.
- **Signal** (parte din Sleitnick/RbxUtil) — practic succesorul „oficial" în ecosistemul Sleitnick, folosit alături de Trove/Comm/Net.
- **LemonSignal** — cea mai nouă, cu claim de performanță superioară, activitate foarte recentă (push 13 iulie 2026), dar comunitate mică (51 stars, 0 issue-uri deschise — fie foarte stabilă, fie foarte puțin folosită încă; nu se poate distinge din datele disponibile).

Pentru cleanup (deconectare automată a conexiunilor/instanțelor la distrugere), trei opțiuni consacrate:
- **Maid** (Quenty/NevermoreEngine) — cel mai vechi, „a alimentat peste un miliard de sesiuni de joc" după afirmația autorului; API-ul e mai puțin tipizat decât succesorii.
- **Trove** (Sleitnick/RbxUtil) — succesorul modern al Maid, API tipizat, parte din același pachet cu Signal/Comm/Net, deci se integrează natural dacă alegi restul ecosistemului Sleitnick.
- **Janitor** (howmanysmall) — alternativă cu binding TypeScript (`@rbxts/janitor`), utilă doar dacă se merge pe roblox-ts.

**Recomandare:** Trove + Signal din pachetul `RbxUtil`, pentru consistență (un singur pachet Wally, un singur stil de API) — vezi `wally.toml` recomandat mai jos.

### Utilitare de date imutabile: Sift/Llama — ambele efectiv abandonate

Sift (csqrl), bazat pe Llama (freddylist), declară explicit în README: „Sift is no longer actively maintained." Llama, predecesorul, nu a putut fi verificat direct (limită de rate atinsă), dar e cunoscut ca fiind și mai vechi. **Nu există în 2026 o bibliotecă activă și dominantă pentru operații imutabile pe tabele/array-uri în Luau** — pentru Driftwood, tabelele de date (index de reparații, inventar) pot fi manipulate direct cu funcții native Luau (`table.clone`, `table.freeze` disponibile nativ în Luau) fără dependință externă.

### Wally (registry) — sănătate discutabilă, dar încă standard

Wally e managerul de pachete de facto (`wally.toml`, similar Cargo/npm) folosit de aproape toate librăriile de mai sus. Problema documentată: **ultimul release stabil e v0.3.2 din 5 iunie 2023** — peste trei ani fără o versiune nouă tăiată, deși CHANGELOG.md arată commit-uri nepublicate încă pe branch-ul principal (`--locked` flag pentru instalare, îmbunătățiri de formatare a lockfile-ului). Registry-ul propriu-zis (`wally-index`) rămâne funcțional și e folosit activ de toate proiectele citate în acest document — deci **nu e o problemă de disponibilitate**, ci un semnal că proiectul CLI-ului are mentenanță redusă la partea de release management. Există o limită documentată: **pachetele mai mari de 2MB sunt respinse la publicare** de CLI.

Există o alternativă mai nouă, **pesde** (pesde.dev, autor daimond113), care suportă atât Roblox cât și runtime-ul Lune, cu pachete active (versiuni v0.1.0 – v1.4.0-rc.1 văzute pe site). Nu am putut verifica din sursele consultate nivelul real de adopție sau o comparație directă publicată cu Wally — de tratat ca opțiune de urmărit, nu de adoptat acum pentru un proiect care are nevoie de librăriile consacrate (toate publicate pe Wally, nu pe pesde).

### roblox-ts — viabilitate pentru un dezvoltator venit din TypeScript

roblox-ts compilează TypeScript în Luau. Versiunea majoră curentă e **v3.0.0** (12 septembrie 2024), proiect activ (2.473 commits, 1.300 stars). Se instalează prin `npm init roblox-ts`, deci toolchain-ul e npm/Node standard, nu ceva specific Roblox pentru partea de compilator.

**Pro:**
- Tipuri statice, autocomplete robust, refactoring sigur — avantaje pe care un dezvoltator experimentat le cunoaște deja.
- Ecosistem propriu de pachete npm (`@rbxts/*`), inclusiv binding-uri pentru Janitor, jecs are suport TypeScript documentat, Flamework există doar pentru acest ecosistem.
- Compatibil cu macOS ca mediu de dezvoltare (compilatorul e un pachet npm, rulează pe orice platformă cu Node — Roblox Studio pe Mac nu e afectat, doar se folosește Rojo pentru sincronizare, ca la Luau nativ).

**Contra:**
- Pas de compilare suplimentar (watch mode necesar în paralel cu Rojo).
- Marea majoritate a exemplelor de cod, tutorialelor DevForum și pluginurilor Studio sunt în Luau nativ — orice căutare de soluție necesită traducere mentală.
- Flamework (framework-ul principal al ecosistemului roblox-ts) are ritm de commit-uri redus (ultimul push 4 septembrie 2025).
- Cerințele exacte de versiune Node.js/TypeScript nu au putut fi confirmate din pagina de Quick Start accesată — NEVERIFICAT, de testat direct în Studio/terminal înainte de a decide.

**Verdict pentru Driftwood:** roblox-ts e o alegere defensabilă tehnic, dar aduce fricțiune netă pentru cineva „complet nou pe Roblox" — orice problemă specifică motorului (evenimente de UI, comportament DataStore, particularități ale ScreenGui) va fi mai greu de depanat cu un strat de compilare între cod și erorile Studio. Recomandarea e Luau nativ pentru prototip și primele sisteme; roblox-ts rămâne o opțiune de reevaluat doar dacă echipa crește și tipurile statice devin un blocaj real de coordonare.

## Recomandari concrete pentru Driftwood

1. **Nu adopta niciun framework „all-in-one".** Knit e arhivat oficial (31 iulie 2024) — nu se pornește cu el. Compune manual din librării mici (vezi mai jos), care se pot înlocui individual dacă una moare.

2. **Networking: Zap, nu Blink, nu RemoteEvents brute.** Zap e mai matur (release-uri semnate, branch stabil `0.6.x`, comunitate mai mare — 187 vs 181 stars, dar activitate constantă din 2023). Blink e promițător (autocomplete Studio) dar încă pre-1.0 (`v1.0.0-pre.7`) — de reevaluat după ce ajunge la 1.0.0 stabil. Motiv: brief-ul cere „validare pe server la fiecare apel" — Zap generează exact acest cod de validare automat din schemă, eliminând o clasă întreagă de bug-uri de securitate scrise manual.

3. **Separă explicit rețeaua fiabilă de cea nefiabilă în schema Zap.** Poziția obiectelor pe râu (actualizată des, tolerantă la un pachet pierdut) → `Unreliable`. Evenimentul „am prins ceva în plasă" (trebuie validat, nu se poate pierde) → `Reliable`. Această distincție reduce lățimea de bandă fără a compromite integritatea economiei.

4. **Date persistente: ProfileStore, nu ProfileService.** Autorul original recomandă explicit migrarea. ProfileStore acoperă direct cerințele din brief (`UpdateAsync`, retry, salvare periodică + la ieșire, session locking împotriva duplicării progresului din acumularea offline la plase).

5. **Nu adopta un ECS (Matter/jecs) de la început.** Numărul de entități simultane într-un joc 2D de tip Stardew e prea mic pentru a justifica complexitatea arhitecturală. Reevaluează doar dacă apar sute de obiecte active simultan pe ecran cu logică eterogenă — atunci jecs (activ, 28 iulie 2026), nu Matter (stagnant din decembrie 2024).

6. **UI: separă stratul „obiecte pe râu" (imperativ) de stratul „chrome" (reactiv).** Obiectele care se mișcă în fiecare frame (râul) sunt cel mai eficient actualizate direct prin `RenderStepped`/`Heartbeat`, setând `Position` pe `Frame`-uri reciclate dintr-un pool — nicio bibliotecă reactivă (Fusion/Vide/react-lua) nu aduce beneficii aici și adaugă overhead de tracking al dependențelor pentru ceva ce oricum se schimbă la fiecare tick. Pentru HUD, panoul atelierului, indexul de colecție, notificări — unde starea se schimbă rar și declarativ — folosește **Vide** (cel mai activ, cel mai mic API, risc redus de breaking changes majore) în locul lui Fusion (0.4 încă nelansat, risc de migrare) sau react-lua (stagnant din mai 2025).

7. **Cleanup și semnale: pachetul `RbxUtil` (Sleitnick) — Trove + Signal.** Un singur pachet Wally, API tipizat, folosit consecvent în tot codul (conexiuni de `RemoteEvent`, `Signal`-uri custom pentru evenimente economice interne ca „set complet la atelier").

8. **Promise (evaera) doar dacă e nevoie reală de compunere asincronă complexă.** Pentru fluxuri simple (cerere-răspuns către `DataStoreService`), `task.spawn` + `pcall`/retry manual e suficient și evită o dependință în plus. Dacă apar lanțuri de operații asincrone (ex: reparație → validare materiale → deducere inventar → notificare atelier), Promise v4.0.0 e stabilă și larg adoptată.

9. **Toolchain pe Mac: instalează Rokit, nu Aftman/Foreman.** Rokit e succesorul recomandat (compatibil drop-in cu `aftman.toml`/`foreman.toml`), suportă explicit macOS, și e necesar pentru a instala CLI-urile Zap, Wally și Rojo local ca binare de dezvoltare (nu ajung în jocul rulat pe Roblox — doar generează cod/sincronizează fișiere la build-time).

10. **Nu adopta roblox-ts pentru versiunea inițială.** Aduce valoare reală (tipuri statice) dar și fricțiune netă pentru cineva nou pe Roblox — majoritatea documentației, exemplelor din DevForum și pluginurilor Studio sunt în Luau nativ. Rămâne o opțiune de reevaluat mai târziu, nu o decizie de blocat acum.

11. **Rămâi pe Wally ca registry, ignoră pesde deocamdată.** Toate librăriile recomandate mai sus (ProfileStore, RbxUtil, Vide) sunt publicate pe Wally. Lipsa unui release CLI nou din 2023 nu afectează instalarea pachetelor existente — riscul e doar că feature-uri noi ale CLI-ului (ex: `--locked`) nu sunt încă disponibile într-un release tăiat.

## Wally.toml recomandat (schelet minimal)

```toml
[package]
name = "driftwood/game"
version = "0.1.0"
registry = "https://github.com/UpliftGames/wally-index"
realm = "shared"

[dependencies]
# Verifica ultima versiune publicata pe Wally inainte de a fixa — 
# numerele de mai jos sunt cele mai recente confirmate la data cercetarii (2026-09-08)
# si pot sa nu mai fie cele mai noi.
ProfileStore = "madstudioroblox/profilestore@^0"   # varianta exacta: verifica pe Wally
Trove        = "sleitnick/trove@1.8.0"
Signal       = "sleitnick/signal@^1"

[server-dependencies]
# nimic specific server momentan

[dev-dependencies]
# Vide se poate adauga aici sau in dependencies, dupa cum se decide stratul UI:
# Vide = "centau/vide@^0"
```

Notă: **Zap și Blink nu se instalează prin Wally** — sunt CLI-uri Rust separate (instalate prin Rokit), rulate manual sau într-un pas de build, care generează un fișier `.luau` ce se commite direct în repo-ul de sincronizare Rojo.

## Riscuri si necunoscute

- **Fusion 0.4** poate schimba API-ul substanțial față de 0.3 — dacă Driftwood adoptă Fusion acum, migrarea ulterioară nu are o dată sau un ghid confirmat public la momentul cercetării.
- **react-lua (fork jsdotlua)** nu a mai primit commit-uri din mai 2025 — dacă Roblox schimbă intern ceva ce rupe compatibilitatea, nu e clar cine repară fork-ul comunitar.
- **Wally CLI** nu a mai avut un release stabil de peste 3 ani — dacă apare o problemă critică de securitate sau compatibilitate cu o versiune nouă a Roblox Studio, nu există un canal de patch confirmat activ.
- **ByteNet, LemonSignal, Blink, pesde** au comunități mici (sub 200 stars, uneori sub 50) — risc de proiect „one-person show" care poate fi abandonat brusc; de monitorizat, nu de pariat exclusiv pe ele fără plan de rezervă.
- **Matter vs. jecs**: nu am putut verifica dacă Matter a primit vreo contribuție relevantă între decembrie 2024 și septembrie 2026 dincolo de push-ul înregistrat de API — posibil ca proiectul să fie complet oprit, nu doar încetinit.
- Bugetul de căutare web (WebSearch) al sesiunii a fost epuizat (200/200) chiar la începutul cercetării, înainte de prima interogare reușită. Toată cercetarea de mai sus s-a bazat pe **WebFetch direct către surse cunoscute** (pagini GitHub, fișiere raw, GitHub REST API) — o metodă mai riguroasă per-sursă, dar care nu a permis descoperirea de surse noi/necunoscute prin căutare liberă (ex. discuții DevForum recente despre alegerea de stack, comparații publicate în 2026). E posibil să existe librării sau discuții relevante din 2025-2026 pe care nu le-am descoperit din lipsă de căutare liberă.
- Pentru câteva fapte (data exactă a release-ului Promise v4.0.0, cerințele Node/TS ale roblox-ts, statisticile Llama) sursele accesate nu au oferit confirmare fermă — marcate explicit mai sus cu încredere „medie"/„scazuta" sau NEVERIFICAT.
- Rezultatele automate de tip WebFetch (rezumate generate de un model mic) au dat **cel puțin o dată o eroare de an** (data unui release Zap raportată inițial ca 2024, apoi corectată la 2026 printr-un fetch separat pe pagina de tag-uri, coroborat cu `pushed_at` din API) — orice dată extrasă printr-un singur fetch WebFetch fără corroborare via API sau o a doua sursă trebuie tratată cu precauție suplimentară.

## Intrebari deschise

1. Câte obiecte simultane pe râu sunt de așteptat la vârf de trafic (server plin)? Răspunsul determină dacă pool-ul de `Frame`-uri reciclate e suficient sau dacă totuși un ECS (jecs) devine justificat pentru gestionarea entităților.
2. Echipa are experiență prealabilă cu React/JSX? Dacă da, react-lua (în ciuda stagnării de commit-uri) reduce curba de învățare mai mult decât Vide sau Fusion, pentru că modelul mental (componente, hooks, `useState`) e deja cunoscut.
3. Testare directă în Studio necesară: confirmă practic dacă instalarea Zap/Rokit/Wally pe macOS (Apple Silicon) funcționează fără fricțiune — sursele confirmă suport oficial pentru macOS la nivel de documentație, dar nu am putut testa efectiv o instalare pe acest Mac în cadrul cercetării.
4. Merită investigat dacă Zap poate genera și tipuri TypeScript (util doar dacă se reconsideră roblox-ts mai târziu) — nu a fost confirmat din sursele consultate (NEVERIFICAT).
5. Pesde merită o reevaluare separată peste 6-12 luni: dacă adopția crește semnificativ și pachetele cheie (ProfileStore, RbxUtil, Vide) devin disponibile și acolo, poate deveni o alternativă mai sănătoasă la Wally.
6. Dacă bugetul de căutare web permite în viitor, o trecere separată prin DevForum (categoria „Resources") pentru discuții din 2025-2026 despre alegerea de stack ar completa lacunele semnalate mai sus.

## Surse

- https://github.com/Sleitnick/Knit — Knit repository (README, banner arhivare), fetch 2026-09-08
- https://api.github.com/repos/Sleitnick/Knit — GitHub REST API, fetch 2026-09-08
- https://github.com/Roblox/roact — Roact repository (README, banner deprecare), fetch 2026-09-08
- https://github.com/rbxts-flamework/core — Flamework repository, fetch 2026-09-08
- https://api.github.com/repos/rbxts-flamework/core — GitHub REST API, fetch 2026-09-08
- https://github.com/red-blox/Zap — Zap repository, fetch 2026-09-08
- https://api.github.com/repos/red-blox/zap — GitHub REST API, fetch 2026-09-08
- https://github.com/red-blox/zap/tags — Zap tags/releases, fetch 2026-09-08
- https://github.com/1Axen/blink — Blink repository, fetch 2026-09-08
- https://api.github.com/repos/1Axen/blink — GitHub REST API, fetch 2026-09-08
- https://github.com/1Axen/blink/releases — Blink releases, fetch 2026-09-08
- https://github.com/red-blox/Red — Red repository (arhivat), fetch 2026-09-08
- https://github.com/ffrostfall/ByteNet — ByteNet repository, fetch 2026-09-08
- https://github.com/matter-ecs/matter — Matter repository, fetch 2026-09-08
- https://api.github.com/repos/matter-ecs/matter — GitHub REST API, fetch 2026-09-08
- https://github.com/matter-ecs/matter/releases — Matter releases, fetch 2026-09-08
- https://github.com/Ukendio/jecs — jecs repository, fetch 2026-09-08
- https://api.github.com/repos/Ukendio/jecs — GitHub REST API, fetch 2026-09-08
- https://github.com/Ukendio/jecs/tags — jecs tags, fetch 2026-09-08
- https://github.com/dphfox/Fusion — Fusion repository, fetch 2026-09-08
- https://api.github.com/repos/dphfox/Fusion — GitHub REST API, fetch 2026-09-08
- https://github.com/dphfox/Fusion/tags — Fusion tags, fetch 2026-09-08
- https://raw.githubusercontent.com/dphfox/Fusion/main/wally.toml — Fusion manifest (main branch, 0.4.0-dev1), fetch 2026-09-08
- https://github.com/jsdotlua/react-lua — react-lua repository, fetch 2026-09-08
- https://api.github.com/repos/jsdotlua/react-lua — GitHub REST API, fetch 2026-09-08
- https://github.com/jsdotlua/react-lua/tags — react-lua tags, fetch 2026-09-08
- https://github.com/centau/vide — Vide repository, fetch 2026-09-08
- https://api.github.com/repos/centau/vide — GitHub REST API, fetch 2026-09-08
- https://github.com/SirMallard/Iris — Iris repository, fetch 2026-09-08
- https://github.com/Michael-48/Iris — Iris fork (identificare inițială a proiectului), fetch 2026-09-08
- https://github.com/MadStudioRoblox/ProfileStore — ProfileStore repository, fetch 2026-09-08
- https://api.github.com/repos/MadStudioRoblox/ProfileStore — GitHub REST API, fetch 2026-09-08
- https://github.com/MadStudioRoblox/ProfileService — ProfileService repository, fetch 2026-09-08
- https://api.github.com/repos/MadStudioRoblox/ProfileService — GitHub REST API, fetch 2026-09-08
- https://raw.githubusercontent.com/MadStudioRoblox/ProfileService/master/README.md — ProfileService README (notă deprecare), fetch 2026-09-08
- https://raw.githubusercontent.com/MadStudioRoblox/ProfileStore/main/README.md — ProfileStore README, fetch 2026-09-08
- https://github.com/evaera/roblox-lua-promise — Promise repository, fetch 2026-09-08
- https://api.github.com/repos/evaera/roblox-lua-promise — GitHub REST API, fetch 2026-09-08
- https://github.com/Data-Oriented-House/LemonSignal — LemonSignal repository, fetch 2026-09-08
- https://api.github.com/repos/Data-Oriented-House/LemonSignal — GitHub REST API, fetch 2026-09-08
- https://github.com/stravant/goodsignal — GoodSignal repository, fetch 2026-09-08
- https://github.com/Sleitnick/RbxUtil — RbxUtil repository (conține Trove, Signal), fetch 2026-09-08
- https://github.com/howmanysmall/Janitor — Janitor repository, fetch 2026-09-08
- https://github.com/Quenty/NevermoreEngine — NevermoreEngine repository (Maid), fetch 2026-09-08
- https://github.com/csqrl/sift — Sift repository (notă „no longer maintained"), fetch 2026-09-08
- https://github.com/UpliftGames/wally — Wally repository, fetch 2026-09-08
- https://github.com/UpliftGames/wally/tags — Wally tags, fetch 2026-09-08
- https://raw.githubusercontent.com/UpliftGames/wally/main/CHANGELOG.md — Wally CHANGELOG (secțiunea „Unreleased"), fetch 2026-09-08
- https://wally.run — Wally landing page, fetch 2026-09-08
- https://pesde.dev — Pesde package manager landing page, fetch 2026-09-08
- https://github.com/roblox-ts/roblox-ts — roblox-ts repository, fetch 2026-09-08
- https://github.com/roblox-ts/roblox-ts/tags — roblox-ts tags (v3.0.0), fetch 2026-09-08
- https://roblox-ts.com/docs/quick-start — roblox-ts Quick Start (documentație oficială), fetch 2026-09-08
- https://github.com/rojo-rbx/rokit — Rokit repository (toolchain manager, suport macOS), fetch 2026-09-08
- https://create.roblox.com/docs/reference/engine/classes/DataStoreService — documentație oficială Roblox, verificare acces, fetch 2026-09-08

**Notă metodologică:** bugetul WebSearch al sesiunii a fost epuizat (200/200) înainte de prima căutare reușită din această cercetare. Toate sursele de mai sus au fost accesate prin WebFetch direct (inclusiv GitHub REST API neautentificat, care s-a lovit la rândul lui de rate-limiting după ~9 apeluri) pe URL-uri cunoscute din prealabil, nu prin căutare liberă. Această limitare e semnalată explicit în secțiunea „Riscuri si necunoscute".
