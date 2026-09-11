# Economie și balans: surse, sink-uri, spațiu limitat

## Rezumat executiv

- **DevEx confirmă cifrele din CLAUDE.md**: rata standard e $0.0038/Robux (a crescut de la $0.0035 pe 5 septembrie 2025), minim 30.000 Robux, o cerere pe lună. Există și o rată "enhanced" de $0.0054 pentru achiziții eligibile de la useri verificați 18+ din SUA — asta înseamnă că geografia și verificarea de vârstă a jucătorilor plătitori chiar contează pentru cash-out.
- **Creator Rewards (din 24 iulie 2025) cuantifică exact de ce "10 minute" contează**: 5 Robux/zi per "active spender" (cineva care a cheltuit ≥$9.99 în ultimele 60 de zile) DOAR dacă Driftwood e unul din primele 3 experience-uri jucate de userul respectiv, ȘI sesiunea trece de 10 minute. Asta transformă bucla zilnică de retenție dintr-un "nice to have" într-un obiectiv economic direct măsurabil.
- Roblox are un API dedicat pentru telemetrie de economie — `AnalyticsService:LogEconomyEvent` cu `Enum.AnalyticsEconomyFlowType` (Source/Sink) și `Enum.AnalyticsEconomyTransactionType` (IAP, Shop, Gameplay, ContextualPurchase, TimedReward, Onboarding). Trebuie folosit din prima zi, nu construit un sistem paralel de logging.
- **"Materiale rare" ca Developer Product cu recompensă aleatorie intră sub politica Paid Random Items** — obligă la afișarea procentelor exacte de probabilitate înainte de cumpărare și la respectarea `PolicyService:ArePaidRandomItemsRestricted()`. Dacă implementarea nu e clar deterministă (ex. "cumperi X materiale garantat"), riscul de compliance e real.
- **Tradingul de itemi/monedă cu bani reali (RMT) e interzis explicit de Roblox**, inclusiv prin servicii terțe. Trading player-to-player *intern* jocului (obiecte reparate, materiale) e tehnic permis, dar aduce riscuri de inflație, farming/dublare de conturi și scam — nu găsit un precedent oficial de "cum să faci trading sigur într-un joc custom" în documentație.
- **N-am putut verifica procentul exact pe care Roblox îl reține din vânzările de Developer Products/Game Passes** (diferit de comisionul pe itemi de avatar din marketplace, care e confirmat 30% Roblox / 40% game owner / 30% creator pentru achiziții in-game de itemi avatar). Cifra de "30%" din CLAUDE.md trebuie verificată direct în Creator Dashboard la crearea unui produs (afișează Robux estimat câștigat).
- Structura de Season Pass recomandată oficial de Roblox (1 lună durată, 10 tiere, pauză de min. 1 săptămână între sezoane, track gratuit + premium) se suprapune aproape perfect peste sezoanele de 4 săptămâni din CLAUDE.md — validare, dar cu recomandarea explicită de a introduce o pauză de o săptămână.
- Prețurile geometrice pentru sloturi ("cost = bază × raport^n") sunt un pattern standard în jocuri idle/incremental, dar n-am putut re-verifica un raport-etalon oficial în această sesiune (buget de căutare epuizat, wiki-uri blocate) — tratat ca punct de plecare de tuning, nu ca literatură confirmată.
- Recomandare de proces: model economic întâi în spreadsheet (surse vs. sink-uri pe oră), apoi simulare Monte Carlo (Python sau Lune) pentru interacțiunea plafon-offline × coadă-reparație × spațiu-limitat, ÎNAINTE de a scrie cod Luau de balans — pentru că aceste trei sisteme se cuplează neliniar.

## Fapte verificate

- Rata DevEx standard e $0.0038 per Earned Robux; rata "enhanced" e $0.0054 pentru achiziții eligibile de la useri 18+ verificați din SUA; rata legacy (înainte de 5 septembrie 2025) era $0.0035. — sursă: https://create.roblox.com/docs/production/monetization/developer-exchange — acces 2026-09-08 — încredere: ridicata
- Minimul pentru un DevEx cash-out e 30.000 Earned Robux, cu maxim o cerere finalizată pe lună calendaristică; verificare necesită email confirmat, cont de min. 13 ani, formular fiscal (W-9/W-8) și cont DevEx Portal valid. — sursă: https://create.roblox.com/docs/production/monetization/developer-exchange — acces 2026-09-08 — încredere: ridicata
- Developer Products se pot prețui între 1 și 1.000.000.000 Robux; din 30 mai 2026 vânzările cross-game de Developer Products sunt dezactivate. — sursă: https://create.roblox.com/docs/production/monetization/developer-products — acces 2026-09-08 — încredere: ridicata
- Game Passes se pot prețui între 1 și 1.000.000.000 Robux; din 30 mai 2026 vânzările cross-game de Game Pass sunt dezactivate; iconițele nu trebuie să depășească 512×512px. — sursă: https://create.roblox.com/docs/production/monetization/game-passes — acces 2026-09-08 — încredere: ridicata
- Pentru itemi de avatar din marketplace: comision marketplace 30% creator/70% Roblox; achiziții in-game de itemi avatar: 30% creator / 40% game owner / 30% Roblox; revânzare de itemi limitate: 50% reseller / 10% creator original / 10% seller-affiliate / 30% Roblox. — sursă: https://create.roblox.com/docs/marketplace/marketplace-fees-and-commissions — acces 2026-09-08 — încredere: ridicata
- Comisionul exact pe vânzările de Developer Products/Game Passes (spre deosebire de itemii de avatar de mai sus) NU a putut fi confirmat într-o pagină oficială accesată în această sesiune. — NEVERIFICAT — încredere: scazuta
- `AnalyticsService:LogEconomyEvent(player, flowType, currencyType, amount, endingBalance, transactionType, itemSku, customFields)` există ca API oficial pentru telemetrie de economie, cu `flowType` din `Enum.AnalyticsEconomyFlowType` (Sink=0, Source=1) și `transactionType` din `Enum.AnalyticsEconomyTransactionType` (IAP, Shop, Gameplay, ContextualPurchase, TimedReward, Onboarding). — surse: https://create.roblox.com/docs/reference/engine/classes/AnalyticsService, https://create.roblox.com/docs/reference/engine/enums/AnalyticsEconomyFlowType, https://create.roblox.com/docs/reference/engine/enums/AnalyticsEconomyTransactionType — acces 2026-09-08 — încredere: ridicata
- Dashboard-ul de Monetization din Creator Hub arată Revenue (pe oră/zi), Conversion Rate, Paying Users, ARPPU, ARPDAU; retenția standard e raportată la Day 1/Day 7/Day 30. — surse: https://create.roblox.com/docs/production/analytics/monetization, https://create.roblox.com/docs/production/analytics/get-started — acces 2026-09-08 — încredere: ridicata
- N-am găsit, în paginile accesate, un dashboard vizual dedicat datelor din `LogEconomyEvent` (spre deosebire de Monetization/Retention/Engagement, care au pagini proprii) — posibil expus doar prin export/API, nu prin panou vizual. — NEVERIFICAT (necesită test direct în Creator Hub) — încredere: scazuta
- Din 24 iulie 2025, programul Engagement-Based Payouts (Premium Payouts) a fost înlocuit de Creator Rewards. Daily Engagement Rewards plătesc 5 Robux/zi per "active spender" (userul a cheltuit ≥$9.99 în ultimele 60 de zile) dacă experience-ul e unul din primele 3 jucate de acel user în ziua respectivă, cu sesiune de minim 10 minute. — sursă: https://create.roblox.com/docs/creator-rewards — acces 2026-09-08 — încredere: ridicata
- Audience Expansion Rewards din Creator Rewards oferă 35% revenue share din primii $100 cheltuiți de un user nou atras (prin Share Links / linkuri directe / căutare de nume), cu condiția de 100+ DAU susținut 60 de zile după atragere; Robux câștigat prin Creator Rewards are o perioadă de 60 de zile înainte de a putea fi retras prin DevEx. — sursă: https://create.roblox.com/docs/creator-rewards — acces 2026-09-08 — încredere: ridicata
- Un Season Pass, conform ghidului oficial de design, are ca punct de plecare recomandat: durată de o lună, minim o săptămână de pauză între sezoane, 10 tiere, track gratuit (misiuni zilnice limitate) + track premium (misiuni bonus), fără misiuni care necesită cheltuială de hard currency. — sursă: https://create.roblox.com/docs/production/game-design/season-pass-design — acces 2026-09-08 — încredere: ridicata
- Roblox definește oficial: Hard Currency = "unique to a specific experience and is primarily obtained by spending real money (represented by Robux)"; Soft Currency = "unique to a specific experience and is usually earned through gameplay"; Economy = "the numerical system dictating the impact of users' behaviors... and the inflows and outflows of currencies". — sursă: https://create.roblox.com/docs/production/game-design/monetization-foundations — acces 2026-09-08 — încredere: ridicata
- Itemii cu recompense randomizate cumpărate cu Robux (direct sau indirect, ex. chei/bilete) intră sub politica Paid Random Items: obligatoriu de afișat toate rezultatele posibile și procentele numerice exacte (însumând 100%) ÎNAINTE de cumpărare, cu update dinamic dacă modificatorii de șansă sunt activi. `PolicyService:ArePaidRandomItemsRestricted()` trebuie verificat per user; dacă restricționat, jocul trebuie să ofere o alternativă (cale gratuită, achiziție garantată, ascundere item etc.). — sursă: https://create.roblox.com/docs/production/monetization/paid-random-items — acces 2026-09-08 — încredere: ridicata
- Roblox interzice explicit real-money-trading (RMT) — tranzacții off-platform pentru itemi/acces la cont contra bani reali — și interzice folosirea serviciilor terțe pentru cumpărare/vânzare/tranzacționare de Robux. `PolicyService:IsPaidItemTradingAllowed()` controlează, per user, dacă tradingul de itemi plătiți e permis (bazat pe legislație locală). — sursă: https://en.help.roblox.com/hc/en-us/articles/203313410-Roblox-Trading-FAQ — acces 2026-09-08 — încredere: medie (extras via reader-proxy, nu confirmat direct din pagina originală care a întors 403)
- Lune este un runtime standalone pentru Luau (similar Node.js/Deno pentru alte limbaje), cu FS, Net, task scheduling — poate rula scripturi/simulări Luau (inclusiv Monte Carlo) în afara Roblox Studio. — sursă: https://lune-org.github.io/docs — acces 2026-09-08 — încredere: medie (conținut parafrazat de reader, nu paginile primare integral)
- Machinations.io e o platformă comercială de modelare vizuală și simulare pentru economii de joc ("Describe any economy, process or loop and simulate it in seconds"), folosită de studiouri ca Amazon Games, Zynga; oferă generare de diagrame din descrieri text și simulare de stress-test. — sursă: https://machinations.io — acces 2026-09-08 — încredere: medie
- Stardew Valley: energia maximă de start e 270; la 0 energie jucătorul devine "exhausted" (mișcare/unelte încetinite); la -15 energie jucătorul leșină, pierde ziua și, dacă e afară din casă, pierde 10% din bani (max 1000g); culcarea înainte de miezul nopții reface energia la maxim, cu penalizări progresive de la -2.5% la -50% pentru culcare târzie, penalizări care se cumulează cu cele de epuizare. — sursă secundară: https://stardewvalleywiki.com/Energy (extras via r.jina.ai reader) — acces 2026-09-08 — încredere: medie
- Backpack Hero (joc indie) a lansat 14 noiembrie 2023 pe Windows/Linux/macOS/Switch (11 iunie 2024 pe PlayStation/Xbox), dezvoltat de Jaspel; mecanica centrală e organizarea tip-Tetris a itemilor într-un inventar-grid, explicit inspirată de caseta din Resident Evil 4 și de inventarul din Deus Ex original. — sursă secundară: Wikipedia, extras via r.jina.ai — acces 2026-09-08 — încredere: medie
- Resident Evil 4 folosește o valiză-inventar (attaché case) cu grid, unde fiecare item ocupă un număr de celule; valiza poate fi upgradată de mai multe ori pentru spațiu suplimentar. — sursă secundară: Wikipedia — acces 2026-09-08 — încredere: medie

## Detalii

### 1. Cine ia cât din fiecare Robux — fluxul de bani complet

Pentru Driftwood contează trei conversii separate, nu una singură:

1. **Jucător → Robux**: prețul de achiziție Robux (pachete în USD) nu a putut fi confirmat exact în această sesiune (pagina `roblox.com/upgrades/robux` e randată integral prin JS, inaccesibilă prin WebFetch). Istoric, Robux se cumpără la un preț efectiv per unitate mai mare decât rata DevEx — asta creează marja Roblox. **NEVERIFICAT — de verificat direct în cont Roblox sau Creator Dashboard.**
2. **Robux cheltuit în joc → dezvoltator**: comisionul confirmat pentru itemi de *avatar/marketplace* e 30% creator / 40% game owner / 30% Roblox (achiziții in-game) — dar acesta e un mecanism diferit de Developer Products/Game Passes generice, iar procentul pentru acestea din urmă **nu a fost găsit** în paginile accesate. CLAUDE.md presupune "Roblox reține 30%" — tratați asta ca ipoteză de lucru, nu ca fapt confirmat, până la verificare în Creator Dashboard (care afișează estimarea de Robux câștigați la crearea unui produs).
3. **Robux câștigat → USD (DevEx)**: $0.0038/Robux standard, $0.0054/Robux "enhanced" (achiziții de la useri 18+ verificați SUA), minim 30.000 Robux, o cerere/lună (sursă: pagina DevEx de mai sus).

Concluzie de proiectare: bucla economică internă a Driftwood (coins/materiale) e complet separată de conversia Robux→USD, dar orice sink care implică Developer Products (skip reparație, extindere temporară de spațiu) trebuie prețuit știind că suma finală "utilă" developerului e semnificativ mai mică decât prețul afișat în Robux — nu presupuneți 1 Robux = 1 Robux de venit net.

### 2. AnalyticsService — telemetria de economie, gata făcută

Roblox are un API dedicat, nu trebuie construit un sistem paralel:

```lua
local AnalyticsService = game:GetService("AnalyticsService")

-- Exemplu SINK: jucătorul plătește cu coins pentru skip la reparație
AnalyticsService:LogEconomyEvent(
    player,
    Enum.AnalyticsEconomyFlowType.Sink,
    "Coins",
    -150,               -- amount (negativ pentru sink)
    850,                -- endingBalance
    Enum.AnalyticsEconomyTransactionType.Gameplay.Name,
    "repair_skip_common",  -- itemSku
    { itemRarity = "common", stationId = "workshop_slot_2" }
)

-- Exemplu SOURCE: jucătorul cumpără un bundle de coins cu Robux
AnalyticsService:LogEconomyEvent(
    player,
    Enum.AnalyticsEconomyFlowType.Source,
    "Coins",
    1000,
    2020,
    Enum.AnalyticsEconomyTransactionType.IAP.Name,
    "coin_bundle_1000",
    {}
)
```

`Enum.AnalyticsEconomyTransactionType` are 6 valori: `IAP`, `Shop`, `Gameplay`, `ContextualPurchase`, `TimedReward`, `Onboarding` — mapați-le explicit pe sistemele Driftwood (ex: donații la atelierul orașului = `Gameplay`; recompensă de offline = `TimedReward`; cumpărare de slot direct din shop = `Shop`). Nu am găsit, în paginile accesate, un panou vizual dedicat acestor date în Creator Hub (spre deosebire de Monetization/Retention care au pagini proprii) — de verificat direct în Studio dacă apar sub "Insights" sau doar prin export.

### 3. Spațiu limitat ca mecanică de tensiune — analiză comparativă

CLAUDE.md postulează explicit: nu energie (ca Stardew), ci **spațiu în atelier**. Comparație cu precedentele cerute:

| Joc | Resursă limitată | Cum se resetează | Ce sink creează | Lecție pentru Driftwood |
|---|---|---|---|---|
| Stardew Valley | Energie (max 270 la start, confirmat) | Se reface la somn, cu penalizări dacă te culci târziu sau ești epuizat | Aproape nimic — energia consumată nu produce venit developerului, doar limitează acțiuni/zi | Modelul lor NU are sink monetizabil — Driftwood, cu spațiu-atelier, poate transforma limita direct în Developer Product ("extindere temporară"), lucru pe care Stardew nu-l face |
| Resident Evil 4 | Grid de valiză, upgradabil | Nu se resetează — e progres permanent | N/A (joc single-player fără monetizare live) | Modelul de grid cu forme diferite per item (tetris) crește complexitatea decizională, dar cere UI 2D solid — fezabil în ScreenGui, dar mai scump de implementat decât "N sloturi identice" |
| Diablo (seria) | Grid inventar (D2) → sloturi simple (D3/D4, fără tetris) | Persistent, extensibil prin stash/cufere | Cufere/stash suplimentar cumpărabil în unele titluri | Trendul industriei a fost simplificarea de la grid-tetris la sloturi numărate — semnal că tetris-ul e cost UX ridicat pentru beneficiu incert |
| Backpack Hero | Grid-inventar tip Tetris, central mecanicii de joc (confirmat, lansat nov. 2023) | Persistent per run (roguelike) | Cumpărare de sloturi/pungi mai mari în magazin | Validează că un grid-tetris POATE fi mecanica principală a unui joc întreg, nu doar o constrângere secundară |
| Deep Rock Galactic | N/A direct — dar are sink-uri paralele (Nitra consumat în misiune, Credits/Perk Points pentru upgrade-uri) | Nitra se resetează la fiecare misiune; progres de upgrade e permanent | Sistem de resurse pe mai multe monede simultan | Model de referință pentru "resursă consumabilă în sesiune + monedă de progres permanent" — relevant pentru split soft/hard currency Driftwood |

**Recomandare de design derivată**: spațiul-atelier ca N sloturi simple (nu grid tetris) e mai ieftin de implementat în ScreenGui și suficient pentru tensiunea "mereu ai mai multe obiecte prinse decât sloturi libere". Grid tetris (RE4/Backpack Hero) ar crește miza vizuală dar și costul de dezvoltare — de evaluat ca îmbunătățire post-lansare, nu pentru prototip.

### 4. Prețuri geometrice pentru sloturi

Formula standard pentru sink-uri de tip "cumpără al N-lea slot": `cost(n) = cost_bază × raport^(n-1)`, cu `raport` tipic > 1 pentru a descuraja achiziția nelimitată. **N-am putut verifica un raport-etalon dintr-o sursă accesibilă în această sesiune** (wiki-uri de jocuri idle blocate de protecție anti-bot, articolul de referință căutat a întors 404) — tratați valorile de mai jos ca punct de plecare de tuning intern, nu ca literatură confirmată:

| Slot # | Cost coins (ipotetic, raport 1.6×) | Cost Robux (Game Pass, dacă permanent) |
|---|---|---|
| 1 (start, gratuit) | 0 | — |
| 2 | 200 | — |
| 3 | 320 | — |
| 4 | 512 | Game Pass (permanent, preț fix ex. 99 Robux) |
| 5 | 819 | Developer Product (extindere temporară) |
| 6+ | ×1.6 succesiv | — |

Notă: dat fiind că Game Pass-urile Driftwood includ deja "slot extra în atelier" ca achiziție permanentă (conform CLAUDE.md), sloturile cumpărate cu coins (soft currency) ar trebui limitate la un plafon mic (ex. 2-3 sloturi suplimentare), restul fiind monetizare hard-currency — altfel jucătorii plătitori nu au motiv să cumpere Game Pass-ul.

### 5. Curbe de reparație pe raritate — tabel de pornire

Nicio sursă oficială Roblox nu dictează timpi de reparație (asta e design intern Driftwood). Propunere de plecare, corelată cu plafonul de acumulare offline (8h, conform CLAUDE.md):

| Raritate | Timp reparație (real-time) | Materiale necesare | Motivație |
|---|---|---|---|
| Comun | 5-15 minute | 1-2 tipuri, cantități mici | Se termină în timp ce jucătorul mai stă în sesiune — feedback rapid |
| Neobișnuit | 30-90 minute | 2-3 tipuri | Se termină "mai târziu azi" — motiv de revenire în aceeași zi |
| Rar | 4-8 ore | 3-4 tipuri, unele rare | Se aliniază cu plafonul de 8h offline — gata la următorul login realist |
| Epic | 12-24 ore | 4+ tipuri, materiale de sezon | Motiv de revenire "mâine" |
| Legendar | 2-4 zile | Materiale rare + posibil donație-comunitate | Proiect pe termen lung, potrivit unghiului "colecție" |

Aceste cifre trebuie tratate ca ipoteze de test A/B, nu ca adevăr — telemetria din `LogEconomyEvent` (câte reparații active per jucător, rata de skip cu Robux) e ce le va corecta.

### 6. Interacțiunea plafon-offline × spațiu-limitat (tensiunea centrală)

Aici e cuplajul neliniar care merită modelat separat, nu presupus: dacă plasele acumulează 8h offline dar atelierul are doar N sloturi libere, obiectele suplimentare prinse peste capacitate trebuie să aibă o regulă explicită (se pierd? se pun într-o coadă "neprocesat" fără limită? se vând automat la preț redus?). CLAUDE.md nu specifică asta — e o decizie de design care afectează direct percepția de "am pierdut progres" (foarte prost pentru retenție) vs. "am mereu ceva de organizat" (bun pentru retenție, conform tezei Stardew din CLAUDE.md). Recomandare: coadă de tip "netă/nesortat" nelimitată ca buffer, cu doar *reparația activă* limitată la N sloturi — astfel jucătorul nu pierde niciodată prinderi, dar tot resimte presiunea de a alege ce repară primul.

### 7. Progression targets — ipoteze de pornire (necesită validare cu playtesteri reali, conform "Ordinea de lucru" din CLAUDE.md)

| Orizont | Țintă propusă | Rationament |
|---|---|---|
| 1 oră (prima sesiune) | 3-5 obiecte prinse, minim 1 reparat complet, primul slot de atelier ocupat | Trebuie să vadă bucla completă (prinde→repară→beneficiu) înainte să plece |
| 1 zi | Revine cel puțin o dată pentru colectarea offline; 1-2 reparații "peste noapte" finalizate | Validează valoarea plafonului offline ca motiv de revenire dimineața |
| 1 săptămână | Progres vizibil în indexul de colecție (>5%), a contribuit la min. 1 set la atelierul orașului | Activează obligația socială (proiect comun) |
| 1 lună | A trecut printr-un ciclu de sezon complet, a văzut Inundația (eveniment lunar) | Validează bucla de conținut recurent, nu doar progres liniar |

### 8. Soft/hard currency — propunere de split

Conform definiției oficiale Roblox (Hard = obținut cu bani reali, Soft = obținut prin joc): coins (soft) din reparații/donații rămân moneda de progres zilnic; Robux (hard, prin Developer Products) cumpără doar viteză/spațiu, niciodată obiecte exclusive — asta respectă deja regula anti-pay-to-win din CLAUDE.md. Recomandare suplimentară: NU introduceți o a treia monedă intermediară (gems/tokens) decât dacă Season Pass-ul o cere explicit — ghidul oficial de season pass nu impune o monedă proprie de sezon.

### 9. Trading — de ce NU la lansare

RMT (schimb de itemi/valută contra bani reali în afara platformei) e interzis explicit de Roblox. Trading player-to-player intern (schimbi un obiect reparat cu altul) e tehnic posibil de implementat, dar: (a) nicio documentație oficială găsită nu descrie un "safe trading pattern" pentru jocuri custom (spre deosebire de sistemul de trading Roblox pentru itemi limitate, care e alt mecanism); (b) trading deschide vector de dublare/exploit dacă serverul nu validează atomicitatea tranzacției; (c) poate submina economia comună a orașului (un jucător activ farmează și "vinde" progres altora, ocolind obligația socială care e tocmai mecanismul de retenție dorit). Recomandare: fără trading la lansare; dacă se adaugă ulterior, doar prin RemoteEvent validat server-side cu tranzacție atomică (ambele părți confirmă simultan, fără fereastră de "am dat dar n-am primit").

### 10. Modelare economică — plan concret

1. **Spreadsheet întâi** (Google Sheets/Excel): o coloană pe oră de joc, surse (coins/oră per plasă activă, per raritate) vs. sink-uri (cost reparații, cost sloturi, cost skip). Scop: verifica manual dacă un jucător activ 1h/zi ajunge la inflație (surplus necheltuibil) sau la deficit (nu poate ține pasul).
2. **Machinations.io** (https://machinations.io) pentru modelare vizuală de flux + simulare rapidă fără cod — util pentru a testa rapid variante de raport geometric la sloturi, dar e tool comercial extern, nu Roblox.
3. **Monte Carlo pentru varianța de raritate**: pentru că râul aduce obiecte cu probabilități pe raritate + sezon modifică ratele, o simulare Monte Carlo (rulează mii de "zile virtuale" cu RNG) arată distribuția realistă de venit, nu doar media. Se poate scrie în Python (rapid de prototipat) SAU direct în Luau rulat prin **Lune** (https://lune-org.github.io/docs) — avantaj: aceeași logică de balans (funcțiile de calcul rate/raritate) poate fi literalmente codul de producție, testat headless prin Lune, apoi copiat/rulat identic în Roblox Studio, eliminând un întreg strat de "am reimplementat balansul de două ori și au divergut".
4. **Telemetrie reală din ziua 1**: `LogEconomyEvent` pe fiecare sink/source, cu `itemSku` consistent, pentru a putea ulterior interoga (prin export sau Insights) rata reală de acumulare vs. cheltuire per jucător și a recalibra tabelele de mai sus cu date, nu presupuneri.

## Recomandari concrete pentru Driftwood

1. **Implementați `AnalyticsService:LogEconomyEvent` pe fiecare tranzacție de coins/materiale din prima versiune jucabilă** (pasul 2-3 din "Ordinea de lucru"), nu abia la pasul de monetizare — altfel pierdeți datele din exact perioada de prototip când balansul e cel mai nesigur.
2. **Nu implementați grid-inventar tip Tetris pentru atelier la lansare.** N sloturi simple e suficient pentru tensiunea dorită și mult mai ieftin în ScreenGui; tetris (validat de Backpack Hero ca mecanică centrală viabilă) rămâne o opțiune de "season 2".
3. **Definiți explicit regula pentru "ce se întâmplă cu obiectele prinse peste capacitatea de reparație active"** înainte de a scrie codul de plase — o coadă nesortată nelimitată protejează retenția mai bine decât pierderea obiectelor.
4. **Verificați direct în Creator Dashboard, la crearea primului Developer Product de test, procentul real de Robux afișat ca "estimated earnings"** — nu vă bazați pe presupunerea de 30% din CLAUDE.md până nu vedeți cifra oficială pentru produsul vostru.
5. **Dacă implementați "materiale rare" ca recompensă aleatorie cumpărabilă (Developer Product tip crate), tratați-o explicit ca Paid Random Item**: afișați procentele exacte înainte de cumpărare și verificați `PolicyService:ArePaidRandomItemsRestricted()` per jucător. Alternativ, simplificați la achiziție garantată (cumperi X materiale, nu o șansă) pentru a evita complexitatea de compliance la un studio solo/mic.
6. **Nu implementați trading player-to-player la lansare.** Riscul de exploit/dublare și de subminare a mecanismului de obligație socială (atelierul orașului) depășește beneficiul, mai ales fără precedent oficial de "safe pattern".
7. **Introduceți o pauză explicită de minim 1 săptămână între "sezoanele" de 4 săptămâni**, aliniat cu recomandarea oficială de season-pass design, pentru a evita burnout și a da timp de producție conținutului sezonier următor.
8. **Mapați explicit fiecare sink Driftwood pe un `Enum.AnalyticsEconomyTransactionType`** (donație atelier = Gameplay, skip reparație = Gameplay sau ContextualPurchase, cumpărare directă din shop = Shop, recompensă offline = TimedReward, bundle Robux = IAP) — decizia se ia o singură dată, la design, ca să telemetria fie interogabilă coerent mai târziu.
9. **Construiți simularea Monte Carlo a economiei în Luau rulat prin Lune**, nu doar în Python, pentru ca funcțiile de calcul de rate/raritate testate acolo să fie literalmente codul folosit în producție (elimină divergența spec-vs-implementare).
10. **Tratați toate cifrele numerice din secțiunea de Detalii (timpi de reparație, rapoarte de preț, ținte de progresie) ca ipoteze de test, nu ca balans final** — niciuna nu vine dintr-o sursă oficială Roblox specifică Driftwood; sunt puncte de plecare pentru telemetrie și playtesting conform regulii proprii din CLAUDE.md ("nu trece la pasul următor până cel anterior nu e testat cu oameni reali").

## Riscuri si necunoscute

- **Comisionul real Roblox pe Developer Products/Game Passes nu a fost confirmat** — dacă diferă semnificativ de presupunerea de 30% din CLAUDE.md, toate calculele de "cât Robux echivalează cu cât efort de dezvoltare" trebuie refăcute.
- **Politica Paid Random Items** poate complica orice mecanică de recompensă aleatorie plătită ("materiale rare" ca Developer Product) — necesită fie transparență completă de procente, fie renunțare la aleatoriu pentru itemii cumpărați direct cu bani.
- **Data de 30 mai 2026 pentru dezactivarea vânzărilor cross-game** de Developer Products/Game Passes nu afectează Driftwood direct (joc single-experience), dar semnalează că Roblox restrânge activ mecanisme cross-experience — de urmărit dacă planurile viitoare includ mai multe experience-uri conectate.
- **N-am găsit dovadă a unui dashboard vizual dedicat pentru `LogEconomyEvent`** în Creator Hub — dacă datele sunt accesibile doar prin export/API, planificați timp de dezvoltare pentru un dashboard intern de analiză, nu presupuneți că Creator Hub le arată automat.
- **Bugetul de căutare web (WebSearch) a fost epuizat înainte de a începe cercetarea acestui fișier** (folosit de alte sesiuni paralele) — toată cercetarea de mai sus s-a bazat pe WebFetch direct pe URL-uri cunoscute/deduse plus un serviciu de tip reader-proxy (r.jina.ai) pentru paginile care blocau accesul direct (Cloudflare/CAPTCHA pe wiki-uri de jocuri). Asta înseamnă acoperire mai slabă pe exemplele din literatura de design generală (Diablo, Deep Rock Galactic, rapoarte de preț idle-games) față de documentația oficială Roblox, care a fost accesibilă direct.
- **Cifrele de reparație/preț-sloturi/ținte de progresie sunt integral ipoteze interne**, nesusținute de nicio sursă externă — riscul e să fie tratate ca "cercetate" când de fapt sunt design de pornire.

## Intrebari deschise

1. Ce procent real din prețul unui Developer Product/Game Pass ajunge efectiv ca Robux al dezvoltatorului? (de verificat în Creator Dashboard la primul produs creat)
2. Există un dashboard Creator Hub dedicat datelor `LogEconomyEvent`, sau trebuie exportate/interogate separat? (de testat direct în Studio + Creator Hub după primele evenimente logate)
3. "Materiale rare" ca Developer Product: recompensă garantată sau aleatorie? Dacă aleatorie, cine scrie și menține textul de disclosure de procente (cerință legală, nu doar UX)?
4. Ce se întâmplă cu obiectele prinse de plasă când toate sloturile de reparație active sunt ocupate ȘI coada de nesortat atinge o limită practică de UI/DataStore (vezi fișierul de cercetare DataStore pentru limitele exacte de dimensiune per cheie)?
5. Raportul geometric optim pentru prețul sloturilor (propus ipotetic 1.6× mai sus) — de testat cu simulare Monte Carlo pe date de playtesting, nu de presupus dintr-o "regulă din literatură" care n-a putut fi re-verificată acum.
6. Cum interacționează exact plafonul offline de 8h cu ratele de sezon (vara rapid/ușor vs. iarna rar/greu) — dacă plafonul e fix în ore, dar valoarea pe oră variază pe sezon, target-ul de "cât câștigă un jucător offline" se schimbă de 4x pe an; e intenționat?
7. Va exista vreodată un al doilea/al treilea experience Driftwood care ar beneficia de cross-game passes — dacă da, planificați migrarea către transferuri Robux directe înainte de 30 mai 2026 (deadline confirmat oficial).

## Surse

- Roblox Creator Hub — Developer Exchange (DevEx) — https://create.roblox.com/docs/production/monetization/developer-exchange — acces 2026-09-08
- Roblox Creator Hub — Developer Products — https://create.roblox.com/docs/production/monetization/developer-products — acces 2026-09-08
- Roblox Creator Hub — Passes (Game Passes) — https://create.roblox.com/docs/production/monetization/game-passes — acces 2026-09-08
- Roblox Creator Hub — Marketplace Fees and Commissions — https://create.roblox.com/docs/marketplace/marketplace-fees-and-commissions — acces 2026-09-08
- Roblox Creator Hub — Monetization overview — https://create.roblox.com/docs/production/monetization — acces 2026-09-08
- Roblox Creator Hub — Monetization Foundations (game design) — https://create.roblox.com/docs/production/game-design/monetization-foundations — acces 2026-09-08
- Roblox Creator Hub — Season Pass Design — https://create.roblox.com/docs/production/game-design/season-pass-design — acces 2026-09-08
- Roblox Creator Hub — Paid Random Items — https://create.roblox.com/docs/production/monetization/paid-random-items — acces 2026-09-08
- Roblox Creator Hub — Premium Payouts (deprecated notice) — https://create.roblox.com/docs/production/monetization/premium-payouts — acces 2026-09-08
- Roblox Creator Hub — Creator Rewards — https://create.roblox.com/docs/creator-rewards — acces 2026-09-08
- Roblox Creator Hub — Analytics: Get started — https://create.roblox.com/docs/production/analytics/get-started — acces 2026-09-08
- Roblox Creator Hub — Analytics: Monetization — https://create.roblox.com/docs/production/analytics/monetization — acces 2026-09-08
- Roblox Creator Hub — Analytics: Insights — https://create.roblox.com/docs/production/analytics/insights — acces 2026-09-08
- Roblox Creator Hub — Reference: AnalyticsService — https://create.roblox.com/docs/reference/engine/classes/AnalyticsService — acces 2026-09-08
- Roblox Creator Hub — Reference: Enum AnalyticsEconomyFlowType — https://create.roblox.com/docs/reference/engine/enums/AnalyticsEconomyFlowType — acces 2026-09-08
- Roblox Creator Hub — Reference: Enum AnalyticsEconomyTransactionType — https://create.roblox.com/docs/reference/engine/enums/AnalyticsEconomyTransactionType — acces 2026-09-08
- Roblox Help Center — Roblox Trading FAQ — https://en.help.roblox.com/hc/en-us/articles/203313410-Roblox-Trading-FAQ — acces 2026-09-08 (extras via r.jina.ai reader; fetch direct a întors 403)
- Lune (Luau standalone runtime) — documentație oficială — https://lune-org.github.io/docs — acces 2026-09-08 [secundar/comunitate]
- Machinations.io — pagină principală produs — https://machinations.io — acces 2026-09-08 [secundar, tool comercial]
- Stardew Valley Wiki — Energy — https://stardewvalleywiki.com/Energy — acces 2026-09-08 [secundar, extras via r.jina.ai reader]
- Wikipedia — Backpack Hero — https://en.wikipedia.org/wiki/Backpack_Hero — acces 2026-09-08 [secundar]
- Wikipedia — Resident Evil 4 — https://en.wikipedia.org/wiki/Resident_Evil_4 — acces 2026-09-08 [secundar]
