# Arbori de Crafting, Tehnologie și Skill — Arhitectură de Progresie Profundă

## Rezumat executiv

- "Adânc" se măsoară în practică prin trei cifre corelate: numărul de rețete/obiecte, numărul de stații/gate-uri, și numărul de niveluri de tier. Terraria are ~35 de crafting stations și 5.400+ iteme pe o coloană de 33 de bosși ([nota: 01-terraria]); Minecraft are 972 de obiecte craftabile pe ~586 "pagini" de rețetă; Factorio are 12 tipuri de "science pack" (7 bază + 5 din expansiunea Space Age) ([nota: 01-factorio-satisfactory]). Nu există un "număr magic" — adâncimea vine din câte gate-uri distincte separă rețetele, nu din numărul brut de iteme.
- Distincția critică de design e **complexitate vs. complicație**: complexitatea (adâncimea strategică, alegeri semnificative) e de dorit; complicația (efort de a înțelege regulile, efort de a ține minte multe lucruri simultan) e aproape întotdeauna un cost pur. Designerul Dan Felder împarte "complexitatea" resimțită în trei tipuri — Comprehension Complexity, Tracking Complexity (ambele de minimizat) și Depth (de maximizat) — și recomandă tratarea complexității ca pe un buget, nu ca pe un obiectiv.
- Cele mai robuste jocuri nu gatează prin RNG sau prin bosși/dezastre spectaculoase, ci prin **lanțuri unealtă → resursă → unealtă mai bună**: în Minecraft, Valheim și Terraria, ai nevoie de unealta de tier N ca să extragi resursa de tier N+1. E un pattern ieftin de construit (o tabelă de comparație în cod), ușor de înțeles de jucător (un singur tip de regulă repetat), și scalează natural cu numărul de tiere.
- Stațiile de crafting sunt cel mai eficient "tier-key": Don't Starve Together deblochează zeci de rețete deodată la prototiparea unei singure stații (Science Machine → Alchemy Engine pentru Tier 1/2 Science; Prestihatitator → Shadow Manipulator pentru Magic), nu rețetă cu rețetă ([nota: 01-dst]). Asta reduce un arbore cu sute de noduri la o mână de decizii vizibile pentru jucător.
- Legibilitatea unui arbore mare nu vine din UI singur, ci din **descoperire ghidată**: Terraria n-are tutorial liniar, dar are un NPC ("Guide") care răspunde la cerere ("arată-mi ce pot face cu acest item") și progresul e construit ca breadcrumbing implicit (omorârea unui boss dă exact materialul necesar pentru pasul următor) ([nota: 01-terraria]).
- Factorio a introdus în versiunea 2.0 "trigger technologies" — tehnologii care se deblochează prin **acțiuni** (minat, craftat, lansat o rachetă), nu doar prin consum de puncte de cercetare — și a reparat o gaură de design veche: nu mai poți cerceta procesarea unei resurse pe care n-ai descoperit-o încă în lume. Ambele sunt tehnici direct transferabile pentru orice arbore ghidat de progresie fizică.
- Sistemele de skill au trei arhetipuri distincte, nu unul: **use-based** (Old School RuneScape — 23 skill-uri, toate pe aceeași curbă de XP, nivelul se ridică prin a face literal acțiunea), **perk-tree pe nivel de personaj** (Skyrim — 18 skill-uri, 251 perk-uri, punct de perk la fiecare nivel), și **arbore pasiv masiv, low-commitment-per-nod** (Path of Exile — ~1.325-1.384 noduri, majoritatea bonusuri mici de %, respec cu resurse limitate). Alegerea între ele schimbă radical costul de dezvoltare și balansare.
- Riscul central al oricărui arbore care crește prin update-uri e **"content treadmill"**: presiunea de a produce mereu conținut nou ca să nu piarzi jucători. Mitigarea nu e "mai mult conținut", e conținut **sistemic** care rămâne relevant — Clash Royale citat ca exemplu clasic, unde un card nou schimbă meta pentru toată populația de jucători, spre deosebire de un nivel nou care e "consumat" doar de o minoritate.
- Un precedent direct pe Roblox există deja și funcționează: **The Forge**, o buclă Mine → Forge → Fight → Upgrade cu crafting probabilistic (combinații de materiale determină distribuții de probabilitate pentru calitatea obiectului) și mini-jocuri de îndemânare la fiecare craft, a atins sesiuni medii de ~26 minute (neobișnuit de lung pentru Roblox) și un vârf peste 1.000.000 CCU.
- Pentru o echipă mică: nu construiești scara lui Terraria (35 stații, 14 ani, ~11 oameni). Construiești o arhitectură **care poate crește** fără să rupă conținutul vechi — tiere adăugate deasupra, nu recrafting-uri ale rețetelor existente — și investești bugetul de complexitate în puține gate-uri legibile, nu în multe gate-uri mărunte.

## Fapte verificate

- Terraria are 35 de tipuri de crafting stations și peste 5.400 de iteme (posibil 6.000+ după update-ul "Bigger & Boulder"), pe o coloană de 33 de bosși. Sursă: [nota: 01-terraria] (terraria.wiki.gg/wiki/Crafting_stations); accesat 2026-09-09; încredere: ridicată.
- Minecraft are 972 de obiecte craftabile acoperite de ~586 de pagini de rețetă în versiunea curentă a site-ului comunitar Crafty. Sursă: https://crafty.gg/crafting; accesat 2026-09-09; încredere: medie (site secundar, versiune de joc etichetată "26.2", neconfirmată direct pe wiki oficial Minecraft).
- O sursă mai veche indică 739 de rețete de crafting pentru versiunea Minecraft 1.18.1 — arată că numărul de rețete a crescut cu ~230 în update-uri ulterioare fără să elimine rețetele vechi. Sursă: agregat din căutare web (fără link unic verificabil); accesat 2026-09-09; încredere: scăzută (cifră raportată, nu confirmată direct pe pagină oficială).
- Factorio are 12 tipuri de "science pack" (7 în jocul de bază: Automation, Logistic, Military, Chemical, Production, Utility, Space; +5 în expansiunea Space Age: Metallurgic, Electromagnetic, Agricultural, Cryogenic, Promethium). Sursă: [nota: 01-factorio-satisfactory] (wiki.factorio.com/Science_pack); accesat 2026-09-09; încredere: ridicată.
- Numărul total de tehnologii individuale din Factorio nu are o sursă oficială cu total agregat explicit; o căutare pe categoria wiki arată 210 pagini în categoria "Technology", dar cifra include probabil variante și pagini non-canonice, deci nu e un total curat de rețete distincte. Sursă: wiki.factorio.com/Category:Technology; accesat 2026-09-09; încredere: scăzută — NEVERIFICAT ca total oficial.
- Factorio 2.0 (Space Age) a introdus "trigger technologies" — tehnologii deblocate prin acțiuni de joc (minat, craftat, lansare de rachetă) — și a legat cercetarea de procesarea unei resurse de descoperirea fizică a acelei resurse în lume (nu mai poți cerceta rafinarea petrolului înainte să găsești petrol). Sursă: https://www.factorio.com/blog/post/fff-376 (Friday Facts oficial); accesat 2026-09-09; încredere: ridicată (blog oficial dezvoltator), dată exactă a postării NEVERIFICATĂ din fetch.
- Core Keeper are (după o sursă terță, necoroborată independent) 18 bosși pe 5 tiere de progresie (early/mid/late/Shimmering Frontier/end-game), gating pe biom + tier de minereu + tier de workbench. Sursă: [nota: 01-core-keeper-necesse]; accesat 2026-09-09; încredere: scăzută pe cifra exactă (sursă terțiară), medie pe structura generală (corroborată de mai multe surse independente).
- Don't Starve Together organizează crafting-ul în ~24 de filtre regulate + ~14 filtre specifice de stație, cu progresie pe două arbori tehnologice separate (Science Tier 1/2, Magic Tier 1/2), fiecare deblocat prin prototipare la o stație fizică — o singură dată, permanent pentru acea lume. Sursă: [nota: 01-dst]; accesat 2026-09-09; încredere: ridicată pe structură, NEVERIFICAT pe numărul total de rețete (nicio sursă primară Klei nu publică un total).
- Old School RuneScape are 23 de skill-uri, toate folosind aceeași curbă de experiență (nivelul 99 cere 13.034.431 XP), XP câștigat exclusiv prin efectuarea acțiunii (minat → XP la Mining, etc.) — sistem "use-based" pur, fără puncte alocate manual. Sursă: https://oldschool.runescape.wiki/w/Experience; accesat 2026-09-09; încredere: ridicată (wiki oficial al jocului).
- Skyrim are 18 skill-uri și 251 de perk-uri (180 de perk-uri unice, restul fiind ranguri suplimentare ale aceluiași perk); cu cap de nivel inițial 81, maximul teoretic era 80 de puncte de perk cheltuite, ridicat ulterior prin sistemul "Legendary Skills". Sursă: agregat din căutare web pe wiki-uri comunitare (Fandom, UESP); accesat 2026-09-09; încredere: medie (surse secundare, dar consistente între ele).
- Path of Exile are un arbore de skill-uri pasive cu ~1.325 de noduri (unele surse citează până la 1.384, probabil versiuni diferite); Path of Exile 2 extinde arborele la peste 1.800 de noduri, adăugat ca zonă nouă fără să elimine noduri vechi. Sursă: agregat din căutare web (pathofexile.com/passive-skill-tree + surse secundare); accesat 2026-09-09; încredere: medie.
- Valheim gatează progresia prin 7 bosși legați fiecare de un biom (Eikthyr → Elder → Bonemass → Moder → Yagluth → Queen → Fader), fiecare oferind atât o unealtă/resursă de tier următor cât și o abilitate pasivă ("Forsaken Power"); portalurile din joc nu permit transportul de minereu brut, forțând deplasare fizică pentru resurse grele — un gating de logistică, nu doar de unelte. Sursă: agregat din căutare web (valheim.fandom.com/wiki/Progression_guide + PCGamer); accesat 2026-09-09; încredere: medie (wiki comunitar + presă, nu sursă primară Iron Gate).
- The Forge (joc Roblox) rulează o buclă Mine → Forge (craft) → Fight (PvE) → Upgrade, cu forjatul compus din 3 mini-jocuri secvențiale de îndemânare per craft, iar combinațiile de materiale determină distribuții de probabilitate pentru categoria/varianta/damage-ul/trăsăturile obiectului rezultat; pickaxe-urile nu sunt craftabile, doar cumpărate cu monedă obținută din revânzarea obiectelor forjate. Sursă: https://www.maxpowergaming.co/post/the-forge-shows-there-s-still-room-for-deep-games-on-roblox; accesat 2026-09-09; încredere: medie (presă specializată, nu date first-party Roblox/dezvoltator).
- The Forge a atins o sesiune medie de ~26 de minute (fără mecanici de idle/AFK) și un vârf peste 1.000.000 de jucători concurenți, fiind unul din ~17 titluri din istoria Roblox care au atins acest prag. Sursă: idem articolul de mai sus; accesat 2026-09-09; încredere: medie — data exactă a vârfului de CCU NEVERIFICATĂ.

## Detalii

### 1. Cât de "adânc" e adânc — tabel comparativ

| Joc | Unitate de măsură | Cifră | Structură de gating |
|---|---|---|---|
| Terraria | crafting stations / iteme / bosși | 35 stații, 5.400+ iteme, 33 bosși | 2 macro-tiere (Pre-Hardmode / Hardmode), separate de un singur boss-gate (Wall of Flesh) |
| Minecraft | obiecte craftabile / pagini de rețetă | 972 obiecte, ~586 pagini | Lanț unealtă-material pe 5-6 tiere (lemn→piatră→fier→diamant→netherite), fără bosși obligatorii pe traseul de crafting de bază |
| Factorio | tipuri de "science pack" | 12 (7 bază + 5 expansiune) | Gating dublu: cercetare (consum de pachete) + producție fizică (trebuie să *fabrici* pachetul înainte să-l consumi) |
| Core Keeper | bosși / tiere | 18 bosși, 5 tiere (NEVERIFICAT cifra exactă) | Biom + tier de minereu + tier de workbench, fiecare boss deblochează exact un pas |
| Don't Starve Together | filtre de crafting / arbori tehnologici | ~38 filtre, 2 arbori (Science, Magic) × 2 tiere | Prototipare o singură dată la stație fizică → rămâne craftabil oriunde pe restul lumii |
| Old School RuneScape | skill-uri | 23, curbă XP comună | Use-based pur — nu există "arbore", doar niveluri liniare pe fiecare skill |
| Skyrim | skill-uri / perk-uri | 18 skill-uri, 251 perk-uri (180 unice) | Nivel de personaj → punct de perk; skill-ul individual urcă prin folosire |
| Path of Exile | noduri de skill pasiv | ~1.325 (PoE1), 1.800+ (PoE2) | Arbore spațial masiv, majoritatea noduri = bonus mic de %, câteva "notable" = abilitate unică |
| Valheim | bosși / biomuri | 7 bosși, 7+ biomuri | Boss dă unealtă de tier următor + abilitate pasivă; portalurile nu transportă minereu brut (gating de logistică) |

Observație transversală: jocurile cu cele mai multe "noduri" (PoE, Terraria) au și cel mai mare buget de dezvoltare și cea mai lungă durată de viață (10+ ani). Jocurile cu arbori "subțiri dar adânci" (Valheim: 7 bosși, DST: 4 tiere pe 2 arbori) au reușit să pară la fel de "profunde" resimțit, pentru că gating-ul e legibil și fiecare prag schimbă vizibil ce poți face — nu pentru că au mii de rețete.

### 2. Arhitectura arborelui: breadth vs. depth, station-gating vs. recipe-gating

Există două axe independente de "adâncime":
- **Breadth (lățime)**: câte opțiuni ai la un moment dat (câte rețete poți face acum, câte skill-uri poți investi punctul curent).
- **Depth (adâncime)**: câte pași trebuie să parcurgi ca să ajungi la o opțiune anume (câte tiere separă lemn de netherite).

Un arbore poate fi lat-și-plat (multe rețete disponibile devreme, puține tiere) — riscă paralizia de alegere devreme și lipsa unui sentiment de progres. Sau îngust-și-adânc (puține opțiuni la fiecare pas, dar mulți pași) — riscă senzația de "coridor", nu de joc deschis. Cele mai reușite arhitecturi combină: puține gate-uri majore (adâncime, legibile, rare) fiecare deblocând un pachet lat de opțiuni noi deodată (lățime, generoasă local). DST e cazul de manual: 2 arbori × 2 tiere = 4 gate-uri majore, dar fiecare gate deblochează zeci de rețete simultan prin prototipare la o singură stație.

**Recipe-gating** (fiecare rețetă are propria condiție de deblocare — ex. Factorio, unde fiecare tehnologie deblochează un subset specific de rețete) dă control fin, dar costă mult în date de configurare și în UI de explicare ("de ce nu pot face asta încă?" trebuie să aibă un răspuns per-rețetă). **Station-gating** (o stație fizică deblochează un întreg palier de rețete deodată — DST, Core Keeper) e mult mai ieftin de construit și de explicat: un singur mesaj ("ai nevoie de Alchemy Engine") acoperă zeci de cazuri.

### 3. Tehnici de gating: resurse, unelte, biom, boss, timp

Din corpusul analizat reies cinci familii de gate, adesea combinate:

1. **Gating pe unealtă → resursă → unealtă mai bună.** Minecraft (pickaxe de lemn nu poate mina obsidian; ai nevoie de diamond pickaxe pentru ancient debris/netherite), Valheim (pickaxe de coarne pentru piatră, apoi bronz pentru fier, apoi fier pentru argint), Terraria (Cobalt/Palladium pickaxe pentru Mythril/Orichalcum, apoi Mythril pentru Adamantite/Titanium). E cel mai ieftin gate de implementat: o tabelă `tier_unealtă >= tier_resursă` și nimic mai mult. Legibil pentru jucător pentru că regula e mereu aceeași, doar cifrele cresc.
2. **Gating pe stație fizică.** DST, Core Keeper: o construcție nouă deblochează un palier întreg de rețete. Ieftin de construit tehnic (flag boolean per lume/jucător: "stația X a fost construită"), dar Core Keeper e criticat explicit de jucători pentru frecare inutilă când fiecare tier cere o stație complet nouă în loc de un upgrade in-place al aceleiași stații ([nota: 01-core-keeper-necesse]) — lecție: preferă upgrade-uri de stație existentă, nu multiplicare de stații noi.
3. **Gating pe biom/zonă.** Valheim (fiecare biom are propriile resurse și propriul boss), Terraria (Corruption/Crimson sunt reciproc exclusive per lume, Hallow apare doar după Hardmode). Costă mai mult (design de conținut per zonă), dar dă varietate vizuală și narativă gratuită odată ce zona există.
4. **Gating pe boss/eveniment.** Terraria (Wall of Flesh dublează literal jocul disponibil), Valheim, Core Keeper. Cel mai scump de construit (necesită sisteme de luptă/challenge), dar și cel mai memorabil ca "moment" de progres. Notă critică pentru Driftwood: toate evenimentele Terraria sunt fie previzibile (warning on-screen înainte de Blood Moon), fie voluntare (jucătorul craftează itemul care declanșează evenimentul) — niciun gate nu e un "gotcha" fără avertisment, ceea ce se aliniază cu cerința de "fără dezastre naturale" din brief: gate-ul poate rămâne dramatic fără să fie un dezastru impus fără control.
5. **Gating pe timp/sezon.** Sezoane cu conținut exclusiv (deja decis pentru Driftwood, D19) sunt propriul lor tip de gate — nu cer material nou, doar fereastră temporală. Riscul lor specific e tratat separat mai jos (content treadmill).

### 4. Arbori de tehnologie: cazul Factorio

Factorio e cazul de studiu cel mai relevant pentru un joc cu producție/economie, pentru că gatingul e **dublu**: nu doar cercetare (consum de "science pack"-uri în laboratoare), ci și producție fizică — trebuie să *fabrici* pachetul de știință înainte să-l poți consuma ([nota: 01-factorio-satisfactory]). Asta creează o buclă "cercetare → producție → mai multă cercetare" care ține jucătorul mereu într-un plan activ, nu doar într-un meniu de alocare de puncte.

Inovația din versiunea 2.0 — "trigger technologies" — e direct aplicabilă oricărui joc cu descoperire fizică de resurse: în loc ca jucătorul să poată cerceta teoretic "rafinare de petrol" înainte să fi văzut vreodată petrol pe hartă, tehnologia se deblochează abia după ce jucătorul *întâlnește* resursa în lume. Developerii au numit explicit problema veche ca fiind un "design flaw" — poți cerceta procesarea unei resurse pe care n-ai descoperit-o încă, ceea ce rupe legătura dintre explorare și progres tehnologic. Pentru Driftwood (unde râul aduce materiale la vale, descoperite treptat), pattern-ul se mapează aproape 1:1: rețetele pentru un material nu ar trebui vizibile/cercetabile înainte ca jucătorul să fi prins fizic măcar o dată acel material.

De asemenea, tehnologiile "infinite" din Factorio (care consumă exclusiv cel mai avansat pachet, "Space science pack", și pot fi cercetate la nesfârșit) rezolvă problema "arborelui terminat" — jucătorii avansați care termină tot arborele nu rămân fără obiectiv, doar trec la o curbă de cost crescător fără plafon. E o soluție ieftină la "ce faci după ce ai deblocat tot" fără să adaugi conținut nou.

### 5. Sisteme de skill: use-based vs. XP-alocat vs. perk tree

Trei arhetipuri distincte, cu costuri de dezvoltare foarte diferite:

**Use-based (OSRS).** 23 de skill-uri, toate pe aceeași curbă matematică de XP; nivelul crește direct proporțional cu acțiunea făcută (minezi → XP la Mining, gătești → XP la Cooking). Nu există "alocare de puncte" — jucătorul nu ia decizii explicite de build, doar decide *ce face* cu timpul lui. Cost de dezvoltare: mic (un contor de XP + o curbă + praguri de nivel per skill), cost de conținut: mare pe termen lung dacă vrei 23 de skill-uri cu conținut propriu fiecare. Risc: "grindul e singura expresie de skill" — fără decizii de build, diferențierea între jucători vine doar din timp investit, ceea ce poate favoriza plătitorii dacă timpul poate fi cumpărat.

**Perk-tree pe nivel de personaj (Skyrim).** Hibrid: skill-urile individuale urcă prin folosire (ca OSRS), dar fiecare nivel de personaj (agregat din toate skill-urile) dă un punct de perk cheltuibil discreționar într-un arbore. Combină "progres pasiv garantat prin joc" cu "decizie activă de build". Cost: mediu — 18 arbori de perk-uri de balansat, plus sistemul de nivel agregat.

**Arbore pasiv masiv (Path of Exile).** ~1.325-1.800 de noduri, majoritatea bonusuri mici de statistică (+2% damage), câteva noduri "notable" cu efecte unice. Respec limitat (resurse rare). Avantaj: senzația de personalizare extremă, hartă vizuală impresionantă ca obiect în sine. Dezavantaj uriaș pentru o echipă mică: costul de balansare crește aproximativ cu pătratul numărului de combinații posibile de noduri, iar comprehension complexity (cât de greu e de înțeles pentru un jucător nou) e printre cele mai mari din industrie — PoE e cunoscut explicit ca greu de învățat pentru boboci.

**Regula de calitate GDKeys — "verb test".** Un skill bun conține un verb ("revive", "possess"); un skill slab e doar un bonus procentual pasiv ("+5% XP"). Autorul citează o analiză proprie: în Control doar ~17% din skill-uri treceau testul de "semnificativ" (aveau impact de gameplay, nu doar stat), față de ~76% în Assassin's Creed Origins (cifre din analiza secundară a autorului, nu date oficiale). Alte reguli citate: evită să gatezi abilități *de bază* (mișcare esențială, atac de bază) în spatele arborelui — creează frustrare, mai ales pentru jucători noi; evită skill-uri atât de nișate încât nu sunt niciodată utile în joc real (exemplul citat: "dual death from below" din Far Cry 3).

### 6. Complexitate vs. complicație

Distincția lui Dan Felder e cea mai utilă unealtă mentală din tot research-ul pentru un arbore mare:

- **Comprehension Complexity** — cât de greu e să înțelegi ce comunică designerul (o regulă, o abilitate, un obiectiv, o interfață). Aproape întotdeauna rău.
- **Tracking Complexity** — efortul mental de a ține minte multiple lucruri simultan în timp ce joci. Aproape întotdeauna rău.
- **Depth** — provocarea de a găsi mutarea optimă odată ce regulile sunt înțelese și starea curentă e urmărită. De dorit, de maximizat.

Recomandarea practică: tratează complexitatea ca pe un buget. Când ești nesigur dacă un sistem nou "merită" costul cognitiv, probabil nu merită. E mai ușor să adaugi complexitate ulterior (după ce vezi că jucătorii cer mai mult) decât s-o scoți (jucătorii investiți se plâng când li se simplifică sistemul preferat).

Pentru un arbore de crafting, traducerea directă: **numărul de rețete nu e problema** (Terraria are 5.400+ și rămâne jucabil de copii); problema e câte *reguli distincte* trebuie învățate ca să navighezi arborele. Un arbore cu 500 de rețete dar o singură regulă repetată ("unealta de tier N deschide resursa de tier N+1") e mai puțin complicat decât un arbore cu 50 de rețete și 50 de condiții diferite de deblocare.

### 7. Legibilitate: encyclopedia, NPC-ghid, breadcrumbing

Terraria rezolvă legibilitatea unui arbore de 5.400+ iteme fără tutorial liniar, prin trei mecanisme combinate ([nota: 01-terraria]):
1. **Hint la cerere, nu forțat.** NPC-ul "Guide" răspunde doar când ești tu inițiatorul: arată-i un item, primești toate rețetele care-l folosesc; opțiunea "Help" dă sfaturi contextuale pe stadiul curent de joc.
2. **Breadcrumbing implicit prin drop-uri.** Omorârea unui boss dă exact materialul necesar pentru pasul logic următor (Eye of Cthulhu → Demonite/Crimtane → poți face armele pentru următorul boss). Jocul nu spune explicit "acum fă X", dar structura recompenselor te împinge acolo natural.
3. **Encyclopedia pasivă construită de comunitate.** Un risc onest de menționat: Terraria se bazează pe 14+ ani de wiki-uri și ghiduri video externe ca "safety net" pentru jucători pierduți — o echipă nouă, fără acest corp comunitar la lansare, nu poate conta pe aceeași plasă de siguranță și trebuie să construiască mai multă legibilitate in-game de la început (encyclopedia in-game robustă, nu doar hint-uri sporadice).

### 8. Cum extind expansion-urile arborele fără să invalideze conținutul vechi

Pattern comun în toate jocurile studiate: **conținutul nou se adaugă deasupra, nu în locul** celui vechi.
- Minecraft: lanțul lemn→piatră→fier→diamant a rămas neschimbat de peste un deceniu; netherite a fost adăugat ca tier *suplimentar* deasupra diamantului, nu ca înlocuitor.
- Factorio Space Age: 5 tipuri noi de science pack, fiecare legat de o planetă nouă — straturi paralele, nu recalibrare a celor 7 vechi.
- Path of Exile 2: arborele pasiv a crescut de la ~1.325 la 1.800+ noduri prin adăugare de zonă spațială nouă, fără eliminare de noduri vechi.
- DST: numărul de filtre de crafting a crescut de la organizarea originală pe taburi (19 categorii în Don't Starve solo) la sistemul actual de ~38 de filtre — reorganizat, dar recompatibil cu tot conținutul vechi ([nota: 01-dst]).

Regula arhitecturală derivată: dacă un tier nou de conținut cere modificarea rețetelor/costurilor tierelor vechi ca să rămână "relevant", arhitectura arborelui e greșită de la bază. Un arbore bine construit tolerează adăugare infinită de tiere fără regresie.

### 9. Riscul de "content treadmill"

Un joc bazat pe niveluri/conținut autorat (fiecare update = X niveluri/rețete noi) intră ușor într-un cerc vicios: fără conținut nou constant, jucătorii avansați ajung la plafon și pleacă; producerea constantă de conținut nou cere echipă și buget în creștere continuă — nesustenabil pentru o echipă mică. Mitigări documentate:
- **Recompensarea măiestriei, nu doar a completării** — sisteme de tip "stele"/mastery care fac replay-ul conținutului existent valoros (citat: Angry Birds Rio).
- **Reglaj dinamic** — conținut generat/ajustat procedural pe baza comportamentului jucătorului, care extinde durata de viață a conținutului existent.
- **Metagame sistemic + social** — cel mai puternic mitigant citat: Clash Royale, unde un card nou schimbă strategiile *pentru toată populația de jucători existentă*, spre deosebire de un nivel nou care e "consumat" o singură dată de o minoritate. Diferența cheie: conținut sistemic (o rețetă nouă care interacționează cu tot ce există deja) scalează cu numărul de combinații posibile; conținut autorat (un nivel, o hartă) scalează liniar cu efortul de producție.

Pentru Driftwood, implicația directă: rețete/materiale noi adăugate sezonier ar trebui proiectate să **interacționeze cu materialele/rețetele deja existente** (combinații noi posibile, nu doar obiecte noi izolate), altfel fiecare sezon nou devine cost de producție pur, fără efect de multiplicare a conținutului deja construit.

## Ce putem fura pentru Driftwood

1. **Lanț unealtă → resursă → unealtă mai bună** (Minecraft/Valheim/Terraria). Aplicat râului: plasă de tier N poate prinde doar obiecte de tier N; upgrade-ul plasei deblochează tier-ul următor. Cost: **mic** — e o comparație numerică în cod, reutilizează sistemul de tiere deja existent în masterplan (Indexul are 7 tiere, D17).
2. **Station-gating în loc de recipe-gating per-obiect** (DST, Core Keeper). Atelierul orașului (12 zone, deja decis D18) devine "cheia" care deblochează un pachet întreg de rețete la un upgrade, nu fiecare rețetă cu propria condiție. Cost: **mic-mediu** — logica tehnică e simplă, costul real e în conținut/balansare per zonă.
3. **Trigger technologies (Factorio 2.0)**: rețeta/informația pentru un material nu devine vizibilă/cercetabilă până jucătorul nu-l prinde fizic măcar o dată în plasă. Se leagă natural de mecanica de bază a jocului (râul aduce materiale progresiv) și elimină nevoia unui "tech tree screen" explicit. Cost: **mic** — flag boolean per material descoperit + UI care ascunde rețetele nedescoperite.
4. **Upgrade in-place al stațiilor, nu multiplicare de stații noi** — lecția negativă explicită din Core Keeper (jucătorii critică frecarea de a construi o stație complet nouă per tier). O singură "masă de lucru" a orașului care se upgradează vizual/funcțional pe tiere. Cost: **mic** — payoff mare în percepție de calitate pentru cost tehnic minim.
5. **NPC/sistem de hint la cerere, stil Guide din Terraria**: "arată-mi ce pot face cu acest obiect" — un buton în inventar care listează toate rețetele posibile cu obiectul selectat, plus ce mai lipsește. Cost: **mic-mediu** — query simplu pe tabela de rețete, UI dedicat.
6. **"Verb test" pentru orice deblocare de tip skill/perk** (GDKeys): fiecare deblocare din atelier/progres ar trebui să activeze o acțiune nouă vizibilă (o unealtă nouă, o zonă nouă accesibilă), nu doar un bonus procentual invizibil. Cost: **mediu** — cere design de conținut per deblocare, dar crește percepția de progres fără cost tehnic suplimentar față de un simplu +X%.
7. **Sistem de skill use-based simplu, stil OSRS, dar redus la 3-5 categorii** (nu 23) — ex. Pescuit, Reparat, Explorare, Meșteșugit — fiecare cu propria curbă de XP câștigată prin acțiunea directă, fără alocare manuală de puncte. Cost: **mic** — un contor + o curbă per categorie, ușor de înțeles de un public tânăr pentru că nu cere decizii de "build".
8. **Arhitectură "adaugă deasupra, nu suprascrie"** ca regulă de proces, nu de cod: fiecare sezon/update nou trebuie să adauge un tier deasupra celui existent (materiale/rețete noi care *folosesc* materiale vechi ca ingredient), niciodată să oblige rebalansarea rețetelor deja lansate. Cost: **mic** — disciplină de design, nu construcție tehnică nouă.
9. **Conținut sistemic în loc de conținut autorat pentru evitarea content treadmill**: rețetele sezoniere noi ar trebui să combine materiale din sezoane anterioare (crescând numărul de combinații posibile), nu doar să adauge obiecte izolate. Cost: **mediu** — cere planificare de material design pe termen lung, dar reduce presiunea de producție an de an.
10. **Crafting cu mini-joc de îndemânare + rezultat calitativ variabil, stil The Forge** — precedent Roblox dovedit (26 min sesiune medie, 1M+ CCU). Aplicat la "reparat" (deja parte din masterplan): un mini-joc scurt de precizie la reparare, unde performanța afectează calitatea finală a obiectului reparat. Cost: **mare** — cere sistem nou de mini-joc, sistem de "calitate" pe obiecte, UI dedicat; dar e cel mai apropiat precedent direct de succes pe platforma-țintă.
11. **Gate-uri de tip "eveniment voluntar craftat de jucător", nu RNG impus** (Terraria: Pumpkin Moon/Frost Moon se declanșează cu un item craftat de jucător) — se aliniază perfect cu cerința "fără dezastre naturale": un eveniment cu miză mare poate exista, atât timp cât jucătorul alege când îl declanșează. Cost: **mediu** — logică de wave/threshold simplă, greutatea e în conținutul recompensă.
12. **Tehnologii "infinite" pentru veteran endgame** (Factorio): o categorie de upgrade fără plafon (ex. capacitate de plasă +1% la nesfârșit, cost crescător) care dă obiectiv continuu jucătorilor avansați fără conținut nou de proiectat. Cost: **mic** — o formulă de cost crescător + o singură buclă de UI, reutilizabilă la nesfârșit.

## Ce NU merge pentru noi

- **Arbore pasiv masiv stil Path of Exile (1.300-1.800 de noduri).** Cost de balansare și de UI e nejustificabil pentru o echipă mică/solo; mai grav, comprehension complexity e prea mare pentru publicul tânăr Roblox — exact tipul de complicație pe care Felder recomandă s-o eliminăm, nu s-o construim.
- **23 de skill-uri separate stil OSRS, fiecare cu progres propriu de ani de zile.** Realist necesită echipe mari și ani de conținut de balansat per skill; pentru un MVP e supra-scop masiv. Se poate păstra *principiul* (use-based, curbă comună), redus radical la numărul de categorii.
- **Sisteme de respec cu economie de resurse rare** (stil PoE, Skyrim Legendary) — riscă să devină o pârghie de monetizare pay-to-win dacă respec-ul rapid se cumpără cu bani reali, ceea ce încalcă direct principiul "banii cumpără doar viteză, spațiu și aspect", nu putere/decizii de build.
- **Bosși de luptă în timp real, stil Terraria/Valheim/Core Keeper**, ca mecanism principal de gating. Driftwood e 2D în ScreenGui, fără avatar/combat de bază (decizie D04 din CLAUDE.md); construirea unui sistem de luptă real doar pentru gate-uri de progres ar fi o schimbare de scop majoră, nu o extensie a arhitecturii deja decise.
- **Evenimente-dezastru direct copiate** (Blood Moon-uri agresive impuse, meteori, furtuni distructive) — excluse explicit de brief-ul de proiect. Chiar dacă mecanismul lor de gating e valid (presiune temporară, recompensă mare), reskin-ul necesar (eveniment voluntar/anunțat, fără distrugere de proprietate a jucătorului) e obligatoriu.
- **Buclă economică de revânzare tip The Forge** (unde uneltele nu sunt craftabile, doar cumpărate cu bani din revânzarea obiectelor forjate) — presupune o piață/schimb între jucători, care intră în conflict cu decizia deja luată "fără trading" în v1 (D21, menționat în notele DST despre monetizare). Ideea de mini-joc de calitate e utilă, bucla economică din spate nu e transferabilă direct fără redesign.
- **Content treadmill autorat** (adăugare constantă de niveluri/hărți noi, stil multe live-service-uri) — echipa e solo/mică (confirmat de propriul research al proiectului, 37-solo-dev-production.md); orice arhitectură care presupune producție continuă de conținut nou la scară mare, în loc de conținut sistemic recombinabil, nu e susținebilă pe termen lung.

## Riscuri și necunoscute

- Cifrele exacte de recipe/tehnologii din Factorio (210 din categoria wiki) și din DST (fără total oficial) sunt NEVERIFICATE ca totaluri curate — orice folosire ca "benchmark cantitativ" în design ar trebui re-verificată direct în joc/wiki structurat, nu doar din agregate de căutare.
- Numărul de bosși din Core Keeper (18/5 tiere) vine dintr-o sursă terțiară necoroborată independent și poate varia cu versiunea jocului (update-uri frecvente); dacă se folosește ca benchmark, trebuie re-verificat la momentul design-ului efectiv.
- Analiza "verb test" (17% vs. 76% skill-uri semnificative) din GDKeys e opinia/metodologia proprie a unui singur autor de blog, nu date empirice publicate sau testate cu jucători — util ca euristică, nu ca standard demonstrat.
- Nu există date directe găsite despre pragurile de încărcare cognitivă specifice publicului tânăr de pe Roblox pentru arbori de crafting — toate recomandările de "minimizare a complicației" sunt principii generale de design de joc, nu cercetare specifică vârstei-țintă Roblox. Recomandat: playtesting direct cu copii/adolescenți din segmentul de vârstă țintă înainte de a fixa dimensiunea finală a arborelui.
- Mecanismul de crafting probabilistic din The Forge (rezultat de calitate variabilă din combinații de materiale) se apropie conceptual de mecanici gen "loot box" — dacă se împrumută ideea, trebuie verificată explicit cu notele de conformitate/politică existente ale proiectului (28-policy-compliance.md, 26/27-monetizare) înainte de implementare, mai ales dacă vreo variantă a rezultatului poate fi cumpărată sau grăbită cu bani reali.
- Datele publice despre The Forge (sesiune medie 26 min, vârf 1M+ CCU) vin dintr-un singur articol de presă specializată, fără link direct către date first-party Roblox; ar trebui coroborate cu alte surse (Roblox Talent Hub, DevForum, rankings publice) dacă devin un reper important pentru decizii de scop.

## Surse

- Terraria Wiki oficial — Crafting stations. https://terraria.wiki.gg/wiki/Crafting_stations — accesat 2026-09-09 (verificat prin [nota: 01-terraria])
- Terraria Wiki oficial — Recipes. https://terraria.wiki.gg/wiki/Recipes — accesat 2026-09-09
- Terraria Wiki oficial — Guide. https://terraria.wiki.gg/wiki/Guide — accesat 2026-09-09 (verificat prin [nota: 01-terraria])
- Crafty — All Minecraft Crafting Recipes. https://crafty.gg/crafting — accesat 2026-09-09
- Factorio Wiki oficial — Technologies. https://wiki.factorio.com/Technologies — accesat 2026-09-09
- Factorio Wiki oficial — Category:Technology. https://wiki.factorio.com/Category:Technology — accesat 2026-09-09
- Factorio Wiki oficial — Science pack. https://wiki.factorio.com/Science_pack — accesat 2026-09-09 (verificat prin [nota: 01-factorio-satisfactory])
- Factorio — Friday Facts #376: Research and Technology (blog oficial dezvoltator). https://www.factorio.com/blog/post/fff-376 — accesat 2026-09-09
- Core Keeper DB — Boss Order & Progression Guide. https://www.corekeeperdb.com/guides/boss-order — accesat 2026-09-09 (context: [nota: 01-core-keeper-necesse])
- Don't Starve Wiki — Crafting/DST. https://dontstarve.wiki.gg/wiki/Crafting/DST — accesat 2026-09-09 (verificat prin [nota: 01-dst])
- Old School RuneScape Wiki — Experience. https://oldschool.runescape.wiki/w/Experience — accesat 2026-09-09
- UESP / Fandom (agregat) — Skyrim Skills & Perks. https://elderscrolls.fandom.com/wiki/Perks_(Skyrim) și https://en.uesp.net/wiki/Skyrim:Skills — accesat 2026-09-09
- Path of Exile — Passive Skill Tree (pagină oficială). https://www.pathofexile.com/passive-skill-tree — accesat 2026-09-09
- Valheim Fandom Wiki — Progression guide. https://valheim.fandom.com/wiki/Progression_guide — accesat 2026-09-09
- PCGamer — Valheim 1.0 progression guide. https://www.pcgamer.com/games/survival-crafting/valheim-biome-order/ — accesat 2026-09-09
- Dan Felder — Design 101: Complexity vs. Depth. https://danfelder.net/2015/05/21/design-101-complexity-vs-depth/ — publicat 2015-05-21, accesat 2026-09-09
- GDKeys — Keys to Meaningful Skill Trees. https://gdkeys.com/keys-to-meaningful-skill-trees/ — accesat 2026-09-09
- Deconstructor of Fun — Managing and Avoiding Content Treadmills. https://www.deconstructoroffun.com/blog//2016/09/managing-and-avoiding-content-treadmills.html — publicat sept. 2016, accesat 2026-09-09
- MaxPowerGaming — The Forge Shows There's Still Room for Deep Games on Roblox. https://www.maxpowergaming.co/post/the-forge-shows-there-s-still-room-for-deep-games-on-roblox — accesat 2026-09-09
- Cross-referințe interne: [nota: 01-terraria], [nota: 01-factorio-satisfactory], [nota: 01-core-keeper-necesse], [nota: 01-dst] (docs/research-survival/, corpus deja verificat al proiectului)
