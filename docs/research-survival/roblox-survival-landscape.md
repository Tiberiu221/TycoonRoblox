# Peisajul Survival pe Roblox: Ce Există și Ce Nu (2026)

## Rezumat executiv

- Roblox NU are un joc survival "de sistem" comparabil ca profunzime cu Terraria, Valheim sau Rust. Cele mai jucate "survival-uri" de pe platformă sunt fie loop-uri idle superficiale (Grow a Garden, Steal a Brainrot), fie jocuri PvP full-loot orientate spre raiding (Apocalypse Rising 2, Fallen Survival, Booga Booga), fie tycoon-uri fără presiune de supraviețuire reală (Lumber Tycoon 2, Islands/Skyblock).
- Cele mai mari CCU-uri din istoria Roblox aparțin unor jocuri superficiale: Grow a Garden a atins 22,3 milioane CCU (23 august 2025), Steal a Brainrot 25,4 milioane CCU (octombrie 2025) — ambele idle-collector, nu survival cu sisteme adânci. Asta arată că "hit viral" ≠ "joc profund"; volumul de jucători nu validează calitatea sistemelor.
- Jocurile cu crafting/building real (Islands, Lumber Tycoon 2, Booga Booga Reborn, The Survival Game) au adâncime respectabilă pentru Roblox, dar rămân la un nivel de complexitate mult sub un Terraria/Valheim — zeci de tier-uri/rețete, nu sute.
- Modelele de monetizare "corecte" există deja ca precedent pe platformă: Booga Booga Reborn are doar 4 gamepass-uri, niciunul pay-to-win structural (viteză/cosmetice), spre deosebire de Steal a Brainrot unde abilități de admin sunt disponibile doar contra Robux — exact tipul de p2w pe care Driftwood vrea să-l evite.
- Arhitectura tehnică Roblox NU permite o lume unică persistentă comună pentru toți jucătorii (gen MMO clasic) — jocurile rulează pe instanțe de server paralele, separate; orice ambiție de "lume comună" trebuie rezolvată prin design (hub-uri, insule/plot-uri per server, sharding), nu e nativă în motor.
- DataStore-urile Roblox au limite concrete și verificabile: 4 MB per cheie, bugete de request calculate ca "300 + concurrentUsers × N" pe minut, plafon de stocare per joc de "500 MB + 1 MB × utilizatori lifetime" — un joc cu sisteme complexe și lumi mari trebuie proiectat cu aceste limite în minte de la început, nu descoperite prea târziu.
- Politica de conținut Roblox interzice gore realist/moarte explicită și glorificarea torturii/abuzului, interzice complet gambling-ul și cere verificare de eligibilitate pentru item-uri randomizate plătite — relevant direct pentru orice mecanică de loot box sau combat.
- Gap-ul real: nu există pe Roblox un joc survival 2D, cooperativ (nu raid-PvP), cu progres persistent adevărat, cu sisteme de crafting/building la scară de "sute de ore", fără disaster-uri, și cu monetizare strict non-p2w. Cel mai aproape sunt Booga Booga Reborn și 99 Nights in the Forest, dar amândouă sunt fie orientate spre PvP full-loot, fie relativ simple sistemic comparativ cu ambiția cerută.
- Recomandare centrală pentru designer: nu concura pe "viral CCU" (asta e loteria BMWLux/DoBig Studios, greu de reprodus intenționat), ci pe adâncime + retenție pe termen lung într-o nișă goală — publicul care vrea "Terraria/Valheim, dar pe Roblox, cu prietenii" există și în prezent nu are unde să se ducă.

## Fapte verificate

- Grow a Garden a atins un vârf de 22,3 milioane de jucători concurenți (CCU) pe 23 august 2025, depășind recordul anterior al Fortnite de 15,3 milioane. — sursa: en.wikipedia.org/wiki/Grow_a_Garden (accesat 10.09.2026) — încredere ridicată
- Grow a Garden a acumulat peste 35,3 miliarde de vizite până în mai 2026 și a atins 1 miliard de vizite în doar 33 de zile de la lansare (26 martie 2025). — sursa: en.wikipedia.org/wiki/Grow_a_Garden (accesat 10.09.2026) — încredere ridicată
- Steal a Brainrot, lansat pe 16 mai 2025 de SpyderSammy (DoBig Studios), a devenit primul joc Roblox care a depășit 25 de milioane de CCU, atingând 25,4 milioane în octombrie 2025. — sursa: Wikipedia "List of Roblox games" / date agregate (accesat 10.09.2026) — încredere medie (cifrele diferă ușor între surse: 20M în august, 25,4M în octombrie)
- 99 Nights in the Forest a atins un vârf de 14,2 milioane CCU și peste 26 de miliarde de vizite (aprilie 2026), fiind al 7-lea cel mai jucat joc din istoria Roblox; a câștigat Best Adventure și Best Horror Experience la Roblox Innovation Awards 2025. — sursa: en.wikipedia.org/wiki/List_of_Roblox_games (accesat 10.09.2026) — încredere medie (cifrele de "all-time" sunt greu de verificat independent)
- Lumber Tycoon 2 (lansat în beta august 2015) a strâns peste 1,3 miliarde de vizite până în aprilie 2026, cu rating de aprobare de 86% și peste 2.000 de jucători concurenți constant încă din 2015. — sursa: agregare din căutare web (Sportskeeda și alte surse secundare) (accesat 10.09.2026) — încredere medie
- Booga Booga Reborn avea 2.300 de jucători concurenți și 258 de milioane de vizite totale în iulie 2026. — sursa: earnaldo.com/blog/booga-booga-reborn-beginner-guide (accesat 10.09.2026) — încredere medie (o altă sursă, Pocket Gamer/thespike.gg, menționează "peste 200.000 de jucători activi" fără dată precisă — discrepanță nereconciliată)
- Booga Booga Reborn are o scară de armură/unelte în 11 tier-uri (Leaf → Hide → Iron → Steel → Adurite → Crystal → Magnetite → Emerald → Pink Diamond → Void → God), fiecare reducere de daună fiind documentată explicit (ex. Leaf 6%, God 75%). — sursa: earnaldo.com/blog/booga-booga-reborn-beginner-guide (accesat 10.09.2026) — încredere medie (sursă secundară de tip ghid comunitar)
- Booga Booga Reborn folosește un sistem de "Rebirth" care resetează jucătorul la nivel 1 dar păstrează Coins, Hats și Mojo Points; deblocarea completă a Mojo Shop necesită 31 de rebirth-uri (sau 16 cu gamepass-ul Double Mojo). — sursa: earnaldo.com/blog/booga-booga-reborn-beginner-guide (accesat 10.09.2026) — încredere medie
- Apocalypse Rising 2 are peste 100 de arme diferite (de foc și corp la corp) și peste 1.000 de cosmetice deblocabile, cu 148 de milioane de "plays" cumulate. — sursa: robloxdesk.com/top-open-world-survival-games-on-roblox (accesat 10.09.2026) — încredere medie (sursă secundară agregatoare, fără dată exactă a cifrei)
- Limitele tehnice Roblox DataStore: maximum 4.194.304 caractere (~4 MB) per cheie; buget de request "300 + concurrentUsers × 40" pe minut pentru citire, "300 + concurrentUsers × 20" pentru scriere; stocare totală permisă per joc = "500 MB + 1 MB × numărul de utilizatori lifetime". — sursa: create.roblox.com/docs/cloud-services/data-stores/error-codes-and-limits (accesat 10.09.2026) — încredere ridicată (documentație oficială)
- Roblox rulează experiențele pe instanțe de server paralele separate (nu o lume unică persistentă); TeleportService este mecanismul oficial pentru mutarea jucătorilor între instanțe/locuri diferite. — sursa: create.roblox.com/docs/reference/engine/classes/TeleportService (accesat 10.09.2026) — încredere ridicată (documentație oficială)
- Politica de conținut Roblox interzice complet gambling-ul (simulat sau real) și cere verificare de eligibilitate via PolicyService API înainte de a permite item-uri randomizate plătite sau tranzacții cu obiecte de valoare. — sursa: about.roblox.com/community-standards (accesat 10.09.2026) — încredere ridicată (documentație oficială)
- Politica de conținut Roblox interzice "gore realist sau reprezentări grafice de moarte" și glorificarea torturii/abuzului; reclamele nu pot fi personalizate pentru utilizatori sub 18 ani. — sursa: about.roblox.com/community-standards (accesat 10.09.2026) — încredere ridicată (documentație oficială)
- Roblox a raportat 85,3 milioane de utilizatori activi zilnic (DAU) în februarie 2025, iar compania afirmă că platforma este folosită lunar de jumătate dintre copiii americani sub 16 ani. — sursa: en.wikipedia.org/wiki/Roblox (accesat 10.09.2026) — încredere medie (a doua cifră e o declarație a companiei, nu o măsurătoare independentă)
- Roblox Corporation a raportat venituri de 3,60 miliarde USD în 2024, cu o pierdere operațională de 1,06 miliarde USD și o pierdere netă de 935 milioane USD. — sursa: en.wikipedia.org/wiki/Roblox_Corporation (accesat 10.09.2026) — încredere medie
- În august 2025, Procurorul General al statului Louisiana a depus un proces împotriva Roblox legat de protecția minorilor pe platformă. — sursa: en.wikipedia.org/wiki/Roblox_Corporation (accesat 10.09.2026) — încredere medie

## Detalii

### Categoria 1: Hiturile virale idle/collector (mari, dar superficiale)

**Grow a Garden** (lansat 26 martie 2025) — creat inițial de un dezvoltator anonim de 16 ani ("BMWLux") în trei zile, ulterior co-deținut de Splitting Point Studios (Jandel, 50%) și DoBig Studios. Loop-ul central: plot de fermă gol → cumperi semințe cu monedă "Sheckles" → plantezi → recoltezi (crește și offline) → cumperi semințe tot mai rare → Robux accelerează timerele și permite furtul de recolte de la alți jucători. Nu are crafting real, nu are building în sens de structuri, iar Wikipedia citează critici că jocul "seamănă mai mult cu un prototip decât cu un joc finit" și acuzații de inflație artificială a CCU prin boți (disputate de Roblox). Sursă: en.wikipedia.org/wiki/Grow_a_Garden.

**Steal a Brainrot** (lansat 16 mai 2025, SpyderSammy/DoBig Studios) — jucătorii colectează personaje "Brainrot" (bazate pe meme-uri "Italian brainrot") de pe o bandă rulantă, care generează venit pasiv; loop-ul central e "fură de la alți jucători în timp ce îți aperi propria bază" — practic o variantă de capture-the-flag cu apărare de bază. Are un element de bază/plot de apărat, ceea ce e mai aproape de "survival" decât Grow a Garden. Monetizare: cele mai bune iteme și abilități de admin de server sunt disponibile DOAR contra Robux — un caz clar de pay-to-win documentat de presă. A atins 25,4 milioane CCU (primul joc peste acest prag) și 7 miliarde de vizite până în iulie 2025. Sursă: agregare Wikipedia "List of Roblox games", accesat 10.09.2026.

**99 Nights in the Forest** — creat de Alec Kieft, Cameron Angland și Matthew Hufton. Loop: apărare cooperativă a unui foc de tabără împotriva unor amenințări nocturne ("The Deer", cultiști), salvare de copii dispăruți, crafting de arme/unelte defensive, arderea lemnului pentru a menține focul. Are elemente reale de survival cooperativ + building ușor (adăposturi, situri rituale), dar sistemele rămân relativ simple: nu e un crafting tree la scară Terraria, ci un set limitat de unelte defensive. A câștigat Best Adventure și Best Horror Experience la Roblox Innovation Awards 2025 și are acorduri de film (20th Century Studios, anunțat aprilie 2026) și crossover cu Fortnite (august 2026) — semn de succes cultural masiv, nu neapărat de adâncime sistemică.

### Categoria 2: Jocurile cu crafting și building real

**Islands (fostul Skyblock)**, de la studioul Easy.gg — descris consecvent de sursele secundare (creation.dev, obby.fun) drept "cea mai adâncă experiență de building de pe Roblox": pornești pe o insulă plutitoare minimală, faci farming, minerit, crafting, și extinzi insula cu sisteme de automatizare/factory pentru procesarea resurselor. Nu am putut verifica cifre exacte de CCU/vizite curente prin sursele accesate (NEVERIFICAT) — site-ul oficial și Fandom au blocat accesul automatizat (HTTP 402/403/404 la toate încercările). Ce e clar din sursele secundare convergente: e un joc solo/prieteni, nu un joc cooperativ la scară de server, iar presiunea de "supraviețuire" (foame, sănătate, moarte) e minimă sau absentă — e mai aproape de un city-builder/factory game decât de survival clasic.

**Lumber Tycoon 2** — unul dintre cele mai vechi jocuri Roblox încă active (beta din august 2015, deci 11 ani vechime la data acestui research). Loop: tai copaci, vinzi lemn la Wood Dropoff, cumperi teren și construiești o afacere de tâmplărie, comerț cu alți jucători. Are un sistem de economie condus de jucători (player-driven economy) remarcabil de longeviv — 1,3 miliarde de vizite, 2.000+ CCU susținut de 11 ani. Istoric a avut probleme serioase de exploit-uri (duplicare de iteme, "base drop", "base wipe") care au necesitat multiple valuri de patch-uri de securitate — un avertisment direct pentru orice sistem de trading/economie persistentă construit de o echipă mică: anti-cheat/anti-dupe trebuie gândit din prima zi, nu adăugat ulterior.

**Booga Booga Reborn** — reînvierea (de către "Gang O' Fries Entertainment") a clasicului Booga Booga (Soybeen), cel mai popular joc "open-world survival" din 2026 conform mai multor surse secundare. E cel mai sistemic dintre toate jocurile analizate:
- **Progresie pe unelte/armură**: 11 tier-uri (Leaf, Hide, Iron, Steel, Adurite, Crystal, Magnetite, Emerald, Pink Diamond, Void, God), fiecare tier miniind materialul următorului — progresie clasică gen Minecraft/Terraria, dar comprimată.
- **Trib/clan**: jucătorii formează triburi (culoare unică, șef, aliați); triburile aliate nu se pot ataca reciproc dar nici nu pot construi pe teritoriul revendicat al aliatului (totem-based land claiming).
- **Moarte și pierdere**: la moarte pierzi itemele crafted, dar bag-urile/materialele/săgețile rămân; poți sprinta înapoi la locul morții să recuperezi lootul înainte să dispară sau să fie luat de altcineva — o variantă "softened" de full-loot, mai puțin punitivă decât Rust clasic.
- **Rebirth/prestige**: resetare la nivel 1, păstrezi Coins/Hats/Mojo; 31 de rebirth-uri (16 cu gamepass) pentru a debloca integral Mojo Shop — sistem de retenție pe termen lung clasic pentru jocuri live-service.
- **Monetizare**: doar 4 gamepass-uri (Double Mojo, Faster Chest Open, Cosmetics Plus, skin cosmetic "Boulder") — niciunul nu deblochează putere exclusivă imposibil de obținut gratuit; jocul e "complet finalizabil fără să cheltui bani" conform ghidurilor comunitare.
- Cifre: 2.300 CCU și 258 milioane de vizite (iulie 2026, earnaldo.com) — notabil, alte surse (necite exact) menționează "peste 200.000 jucători activi", discrepanță pe care nu am putut-o reconcilia (posibil cifre din perioade diferite, sau "activi" vs. "concurenți" măsurate diferit).

**The Survival Game** — temă medievală, sistem de "kingdoms" (regate), crafting de arme (sulițe, săbii, arcuri, scuturi), building progresiv (colibe de lemn → castele de piatră, ziduri defensive, turnuri de veghere, ferme), războaie între regate, vreme sezonieră și **stricăciune a resurselor** (resource spoilage — mâncarea se strică, un mecanism rar întâlnit pe Roblox și relevant direct pentru un joc despre un oraș de râu cu recolte/pescuit). Nu am găsit cifre verificabile de CCU/vizite/developer pentru acest joc (NEVERIFICAT).

### Categoria 3: Rust-alikes / survival PvP dur

**Apocalypse Rising 2** — supraviețuire post-apocaliptică cu zombi, peste 100 de arme, 1.000+ cosmetice, vehicule reparabile, ciclu zi-noapte, 20+ locații noi adăugate într-un beta din 2025; 148 milioane de "plays" cumulate. E orientat spre combat/looting mai mult decât crafting profund.

**State of Anarchy** — "hardcore first-person looter shooter" inspirat explicit din DayZ și Escape from Tarkov: extraction-based (intri într-o hartă, extragi lootul, ieși), hărți limitate ca număr de jucători (Seaboard 20, Redwood 30), NPC traders, customizare de arme cu attachment-uri, sistem de armură avansat, vreme dinamică, AI de zombi.

**Fallen Survival** — descris explicit ca inspirat din Rust: "brutal PVPVE sandbox", gathering de lemn/piatră/metal/minereu, crafting de arme/armură/explozibili, research tables (deblocare de tehnologie), raidare de baze, joc solo sau echipă, pornire fără echipament ("no gear and no help").

Aceste trei jocuri confirmă că formula "Rust pe Roblox" există deja și e populată — dar toate sunt orientate spre PvP full-loot dur, ceva explicit incompatibil cu brief-ul Driftwood (public tânăr, corectitudine pentru jucătorii gratuiți).

### Categoria 4: Adiacente / neconcludente

**Bee Swarm Simulator** (Onett) — incremental pur, albinele urmăresc jucătorul și colectează polen convertit în miere; fără building, fără crafting real, dar cu quest-uri și evenimente sezoniere — relevant ca exemplu de loop simplu, extrem de longeviv, cu retenție bazată pe progresie incrementală constantă.

**Blox Fruits** (Gamer Robot) — RPG de acțiune inspirat din One Piece, cu combinații de stiluri de luptă (fructe, sabie, arte marțiale, armă); "unul dintre cele mai încărcate cu conținut jocuri de pe Roblox" (VG247, citat pe Wikipedia) — fără elemente de survival/building, dar un exemplu bun al cât de mult conținut de progresie poate susține un joc Roblox pe termen lung fără să fie survival.

**Doors** (LSPLASH/Red, 10 august 2022) — horror roguelite de explorare (deschizi uși, eviți entități), fără crafting, fără building, fără persistență reală — nu e un joc survival în sensul cerut de brief, doar clasificat uneori generic ca "survival horror" de agregatoare.

**Fisch** și **Dead Rails** — ambele menționate frecvent în conversația despre survival/adiacent pe Roblox (Fisch = fishing/progresie cu monetizare puternică; Dead Rails = supraviețuire pe o cale ferată în Vestul Sălbatic, viral în 2025), dar sursele accesate în această sesiune nu au oferit date verificabile (pagini 404, wiki-uri blocate, motoare de căutare captcha-gate). **NEVERIFICAT** pentru amândouă — recomand o sesiune de research dedicată doar acestor două jocuri, cu acces direct la paginile lor Roblox și la presa de gaming, dacă devin relevante pentru decizii de design.

### Tabel comparativ (cifre verificate sau cel mai bine sursate găsite)

| Joc | Tip | CCU vârf / Vizite | Dată | Sursă |
|---|---|---|---|---|
| Grow a Garden | Idle farming | 22,3M CCU / 35,3B+ vizite | aug 2025 / mai 2026 | Wikipedia |
| Steal a Brainrot | Idle + fură/apără bază | 25,4M CCU / 7B+ vizite | oct 2025 / iul 2025 | Wikipedia (agregat) |
| 99 Nights in the Forest | Survival cooperativ | 14,2M CCU / 26B+ vizite | — / apr 2026 | Wikipedia |
| Lumber Tycoon 2 | Tycoon/trading | 2.000+ CCU / 1,3B vizite | din 2015 / apr 2026 | surse secundare |
| Booga Booga Reborn | Survival tribal PvP | 2.300 CCU / 258M vizite | iul 2026 | earnaldo.com |
| Apocalypse Rising 2 | Survival PvP zombi | — / 148M plays | nedatat | robloxdesk.com |
| Islands (Skyblock) | Building/factory | NEVERIFICAT | — | — |

### Constrângeri tehnice ale platformei (relevante pentru orice joc "sisteme complexe")

Roblox nu oferă o lume unică persistentă la scară MMO — fiecare "server" e o instanță separată, izolată; comunicarea între instanțe se face explicit prin MessagingService, MemoryStoreService sau TeleportService, nu implicit. Orice ambiție de "oraș comun persistent" trebuie tradusă în design concret: fie un hub central + instanțe/plot-uri private per grup (modelul Bloxburg/Adopt Me), fie shard-uri de dimensiune fixă (modelul Islands: o insulă = o instanță). Nu există o soluție "gratuită" din partea motorului.

DataStore-urile au limite numerice stricte și verificate oficial: max. ~4 MB per cheie, bugete de request calculate dinamic în funcție de câți jucători sunt concurenți pe server ("300 + concurrentUsers × 40" citiri/minut etc.), plafon total de stocare per joc = "500 MB + 1 MB per utilizator lifetime". Pentru un joc cu crafting/building la scară mare (sute de iteme, structuri persistente, inventare complexe per jucător), arhitectura de salvare a datelor (chunking, compresie, batching) trebuie proiectată din faza de prototip, nu adăugată ulterior — Lumber Tycoon 2 și alte jocuri vechi au avut ani de probleme de exploit-uri legate exact de sincronizarea stării persistente.

## Ce putem fura pentru Driftwood

1. **Sistemul de Rebirth/prestige al Booga Booga Reborn** (resetare de progres, păstrare de monedă meta + cosmetice, deblocare treptată a unui "shop" permanent) — un hook de retenție pe termen lung dovedit, ușor de adaptat la o temă non-violentă (ex. "sezoane" de râu care se resetează dar păstrează un magazin de decor/unelte permanente). Cost: **mediu** (necesită monedă meta separată, UI de shop, balans de progresie pe mai multe cicluri).
2. **Economia condusă de jucători a Lumber Tycoon 2** (vânzare/cumpărare de resurse între jucători, nu doar către NPC) — motorul central care a ținut jocul viu 11 ani. Cost: **mare** dacă vrem trading direct P2P (risc de dupe/exploit, necesită anti-cheat serios); **mediu** dacă implementăm doar o piață tip "auction house" server-side, mai ușor de securizat.
3. **Automatizarea/factory chain-urile din Islands** (plasezi o mașinărie care procesează resurse în timp, inclusiv offline) — mecanism excelent pentru un joc unde vrem ca jucătorii gratuiți să progreseze fără să fie "obligați" să stea online non-stop. Cost: **mediu**.
4. **Moartea "softened" din Booga Booga Reborn** (pierzi itemele crafted la moarte, dar rămân recuperabile pentru o fereastră de timp la locul morții) — mult mai puțin punitiv decât full-loot clasic (Rust/Fallen Survival), potrivit pentru public tânăr și pentru fairness cu jucătorii casual. Cost: **mic**.
5. **Separarea cosmetic/putere din Apocalypse Rising 2** (1.000+ cosmetice vs. echipament găsit/craftat în lume, nu cumpărat) — validează exact filozofia "banii cumpără doar look" cerută de brief. Cost: **mic-mediu** (pipeline de cosmetice e mai ales conținut, nu sistem nou).
6. **Stricăciunea resurselor (resource spoilage) din The Survival Game** — mecanism rar pe Roblox, foarte natural pentru o temă de râu/recoltă/pescuit (peștele se strică, recolta se ofilește dacă nu ajunge la timp la piață) — creează presiune de timp fără să fie "dezastru natural". Cost: **mic-mediu**.
7. **Obiectivul cooperativ pe timer din 99 Nights in the Forest** ("apărați ceva împreună în fiecare noapte/ciclu") — poate fi reformulat non-violent pentru Driftwood (ex. menținerea unui dig/zăgaz, procesarea unui transport de marfă pe râu înainte de următorul ciclu) — păstrează tensiunea cooperativă fără dezastre sau gore. Cost: **mediu**.
8. **Modelul de gamepass-uri "fără putere exclusivă" al Booga Booga Reborn** (4 gamepass-uri, toate viteză/confort/cosmetic) — template direct aplicabil pentru politica de monetizare cerută de brief. Cost: **mic** (e o decizie de design, nu un sistem tehnic nou).

## Ce NU merge pentru noi

- **PvP full-loot / raidare de baze** (Booga Booga, Fallen Survival, Apocalypse Rising 2, State of Anarchy) — direct incompatibil cu cerința de corectitudine pentru jucătorii gratuiți și cu un public tânăr: un jucător nou/casual care pierde ore de progres într-un raid renunță la joc. Genul e deja suprapopulat pe Roblox și nu e diferențiatorul pe care îl caută Driftwood.
- **Abilități/itemi pay-to-win vândute doar pe Robux** (modelul admin-abilities din Steal a Brainrot) — exact opusul principiului "banii cumpără doar viteză/spațiu/aspect" din brief; și reputațional riscant (presa a documentat critici pentru exact acest model).
- **Gore realist sau reprezentări explicite de moarte** (temele zombi din Apocalypse Rising 2, Fallen Survival) — interzis explicit de Community Standards Roblox ("realistic or real-world depictions of extreme gore, graphic violence, or death"), și oricum nepotrivit pentru un public tânăr pe o platformă unde jumătate din utilizatori sunt copii.
- **O lume unică persistentă la scară MMO pentru toți jucătorii simultan** — nu există nativ în Roblox; orice pretenție de "un singur oraș-râu comun, tot timpul" ar necesita inginerie de sharding/sincronizare cross-server foarte costisitoare pentru o echipă mică. Chiar și hiturile mari (Islands, Lumber Tycoon 2) folosesc instanțe separate, nu o lume comună.
- **Loot box-uri/randomizare fără transparență, sau orice mecanism care seamănă cu gambling-ul** — interzis explicit de politica Roblox (gambling simulat sau real e complet interzis; item-urile randomizate plătite necesită verificare de eligibilitate prin PolicyService pe vârstă/locație).
- **Trading P2P nesecurizat de tip Lumber Tycoon 2 din 2015** — istoricul arată ani de exploit-uri de duplicare; o echipă mică nu are resursele să reacționeze la fel de rapid la exploit-uri ca un studio cu 11 ani de patch-uri în spate. Dacă vrem economie de jucători, trebuie gândită server-authoritative de la început, nu client-trust.
- **Integrare NFT sau monetizare experimentală de tip Pet Simulator X** — a generat controverse documentate și risc de percepție negativă din partea comunității și a presei.

## Riscuri și necunoscute

- Bugetul de WebSearch al sesiunii s-a epuizat rapid (folosit de alți agenți în paralel în același research batch), așa că o bună parte din research s-a bazat pe WebFetch direct pe URL-uri cunoscute/deduse, nu pe căutare liberă. Asta înseamnă acoperire inegală: Grow a Garden, Steal a Brainrot, Booga Booga Reborn și 99 Nights in the Forest au date solide; **Islands, Fisch, Dead Rails și cifrele exacte pentru Apocalypse Rising 2 / The Survival Game rămân NEVERIFICAT sau slab sursate**.
- Multiple pagini Fandom (wiki-urile dedicate pentru Lumber Tycoon 2, Islands, Dead Rails) au blocat accesul automatizat (HTTP 402/403) — sursă majoră de detalii de gameplay pentru aceste jocuri, inaccesibilă în această sesiune.
- Discrepanța de cifre pentru Booga Booga Reborn (2.300 CCU vs. "peste 200.000 jucători activi" din altă sursă) nu a putut fi reconciliată — posibil diferență între "concurenți în acest moment" și "jucători unici activi într-o perioadă", dar nu e confirmat.
- Cifrele de "vizite totale" (billions de vizite) sunt ușor de umflat prin re-joins, boți sau alt-uri — mai multe surse (inclusiv Wikipedia despre Grow a Garden) menționează suspiciuni de inflație artificială a CCU prin boți, disputate de Roblox însuși. Orice cifră de CCU/vizite trebuie tratată ca orientativă, nu ca măsură exactă de calitate sau retenție reală.
- Nu am reușit să confirm dacă există deja un proiect "stealth" în dezvoltare pe Roblox care vizează exact nișa identificată (survival 2D cooperativ, sisteme adânci, non-p2w) — DevForum-ul Roblox (unde ar apărea astfel de discuții) nu a fost accesibil în această sesiune (pagini 404 la toate încercările).
- Politica Roblox privind pay-to-win e vagă/neaplicată strict: platforma "descurajează" dar nu interzice explicit p2w (spre deosebire de gambling, care e interzis clar). Asta înseamnă că fairness-ul cerut de brief e o disciplină auto-impusă de Driftwood, nu una impusă de Roblox — nimeni nu ne oprește să copiem modelul Steal a Brainrot dacă am vrea, deci trebuie tratat ca decizie de valori a echipei, nu ca literă de regulament.

## Surse

- [Grow a Garden — Wikipedia](https://en.wikipedia.org/wiki/Grow_a_Garden) — accesat 10.09.2026
- [Blox Fruits — Wikipedia](https://en.wikipedia.org/wiki/Blox_Fruits) — accesat 10.09.2026
- [List of Roblox games — Wikipedia](https://en.wikipedia.org/wiki/List_of_Roblox_games) — accesat 10.09.2026 (sursă pentru 99 Nights in the Forest, Steal a Brainrot, Dandy's World, Doors, și alte ~30 de jocuri)
- [Fisch (disambiguation) — Wikipedia](https://en.wikipedia.org/wiki/Fisch) — accesat 10.09.2026 (fără detalii, doar mențiune generică)
- [Roblox — Wikipedia](https://en.wikipedia.org/wiki/Roblox) — accesat 10.09.2026
- [Roblox Corporation — Wikipedia](https://en.wikipedia.org/wiki/Roblox_Corporation) — accesat 10.09.2026
- [Roblox Data Stores — error codes and limits — create.roblox.com](https://create.roblox.com/docs/cloud-services/data-stores/error-codes-and-limits) — accesat 10.09.2026 (documentație oficială)
- [TeleportService — create.roblox.com](https://create.roblox.com/docs/reference/engine/classes/TeleportService) — accesat 10.09.2026 (documentație oficială)
- [Monetization — create.roblox.com](https://create.roblox.com/docs/production/monetization) — accesat 10.09.2026 (documentație oficială)
- [Roblox Community Standards — about.roblox.com](https://about.roblox.com/community-standards) — accesat 10.09.2026 (documentație oficială)
- [Booga Booga Reborn Beginner Guide — earnaldo.com](https://earnaldo.com/blog/booga-booga-reborn-beginner-guide) — accesat 10.09.2026 (secundară, ghid comunitar)
- [Booga Booga Reborn codes — robloxden.com](https://robloxden.com/game-codes/booga-booga-reborn) — accesat 10.09.2026 (secundară)
- [Top Open-World Survival Games on Roblox — robloxdesk.com](https://www.robloxdesk.com/top-open-world-survival-games-on-roblox/) — accesat 10.09.2026 (secundară, agregator)
- [Best Roblox Survival Games — creation.dev](https://www.creation.dev/blog/best-roblox-survival-games) — accesat 10.09.2026 (secundară, agregator)
- [Best Roblox Survival Games — thespike.gg](https://www.thespike.gg/roblox/best-roblox-games/best-survival-games) — accesat 10.09.2026 (secundară, agregator)
- [Roblox Survival Games — obby.fun](https://www.obby.fun/blog/roblox-survival-games) — accesat 10.09.2026 (secundară, agregator)
- [Build to Survive Games on Roblox — obby.fun](https://www.obby.fun/blog/build-to-survive-games-roblox) — accesat 10.09.2026 (secundară, agregator)
- [Beginner's guide to Lumber Tycoon 2 — Sportskeeda](https://www.sportskeeda.com/roblox-news/beginners-guide-to-roblox-lumber-tycoon-2) — citat prin căutare web, accesat 10.09.2026 (secundară; fetch direct blocat de site, HTTP 405)

**Notă despre limitări de acces**: mai multe surse relevante nu au putut fi accesate direct în această sesiune din cauza restricțiilor site-urilor (Fandom wiki-uri: HTTP 402/403; unele articole de presă: HTTP 404; motoarele de căutare Bing/DuckDuckGo au returnat fie rezultate irelevante, fie pagini CAPTCHA). Bugetul de WebSearch al sesiunii (partajat cu alți agenți din același batch de research) s-a epuizat după 4 căutări. Recomand o rundă suplimentară de verificare directă pe paginile oficiale Roblox ale jocurilor (roblox.com/games/...) și pe RTrack/Rolimons pentru cifre CCU actualizate, dacă aceste date devin critice pentru o decizie de design.
