# Factorio, Satisfactory: complexitatea care creează dependență

## Rezumat executiv

- **Nu există fail state clasic.** Nici Factorio, nici Satisfactory nu au un "game over". Poți epuiza resurse, poți fi copleșit de dușmani (Factorio) sau poți rata un design — dar consecința e mereu "rebuild", nu "restart". Asta elimină frica de eșec și transformă fiecare sesiune într-un experiment fără miză letală — exact modelul cozy/fair pe care Driftwood și-l dorește deja.
- **Bucla centrală e "investește timp → capeți capacitate de a investi și mai eficient timp"** — automatizarea nu e o recompensă cosmetică, e un multiplicator de progres. Fiecare mașină construită produce mai multe mașini mai repede. E o buclă de interes compus, nu o buclă de recompensă simplă (loot).
- **Tech tree-ul e gating dublu**: pe lângă cercetare (Factorio: "science packs" consumate în laboratoare), progresul e gated și de infrastructură fizică (trebuie să *produci* pachetul de știință înainte să-l poți consuma). Asta forțează un ciclu "cercetare → producție → mai multă cercetare" care ține jucătorul mereu într-un plan activ.
- **Blueprint/copy-paste-ul e mecanismul care face complexitatea suportabilă.** Fără el, fiecare reconstrucție ar fi muncă manuală repetitivă; cu el, jucătorul "compilează" un design odată și îl reutilizează infinit — practic un sistem de abstractizare/reuse împrumutat direct din inginerie software.
- **Multiplayer-ul funcționează prin diviziune naturală a muncii**, nu prin roluri impuse: un jucător poate extinde minarea, altul reconstruiește topirea, altul se ocupă de cercetare/apărare — sarcinile se separă organic pentru că fiecare subsistem (minerit, transport, producție, cercetare) e suficient de mare cât să ocupe o persoană întreagă.
- **Sesiunile lungi ("Cracktorio") sunt un efect secundar documentat empiric**, nu un artificiu de manipulare (nu are variable rewards de tip slot machine) — vine din "time dilation" cauzat de rezolvarea continuă de probleme mici cu feedback vizual imediat (o bandă se umple, un robot pornește).
- **Ambele jocuri se vând scump, o singură dată, fără nicio microtranzacție** — Factorio ~$35 (bază) + $35 (expansiunea Space Age, 2024), Satisfactory ~$40 la 1.0. Modelul lor de monetizare e opusul complet al ce trebuie să construiască Driftwood (F2P pe Roblox, bani doar pe viteză/spațiu/estetică) — util ca reper de calitate, inutilizabil ca model de business.
- **Echipele au pornit minuscule**: Factorio a pornit cu 1 om (2012), a ajuns la 31 la 1.0 (2020/2024). Satisfactory a fost făcut de Coffee Stain Studios, un studio mediu suedez. Complexitatea sistemică nu cere un studio AAA — cere ani de iterație pe un singur loop, nu un buget mare.
- **Nu există tutorial clasic în niciunul din jocuri** — învățarea se face prin descoperire, eșec local și presiune de sistem (banda se blochează → jucătorul investighează de ce). Aproape jumătate din jucătorii activi ai Factorio abandonează în jurul zidului "petrol + roboți" (sursă secundară, necorfirmată oficial) — un cost de retenție pe care Factorio îl poate accepta (preț premium, audiență auto-selectată de ingineri), dar pe care Driftwood NU și-l poate permite (F2P, audiență tânără, retenție = obiectivul principal).
- **Concluzia pentru design**: complexitatea nu creează dependență prin ea însăși — creează dependență combinația specifică "fără risc de eșec permanent" + "fiecare acțiune se compune cu următoarea" + "unealtă de reutilizare (blueprint) care scade costul de a repeta o soluție găsită o dată". Aceste trei proprietăți sunt portabile la Driftwood chiar dacă restul sistemului (fabrici, benzi, roboți) nu e.

---

## Fapte verificate

- Factorio a intrat în Early Access pe 25 februarie 2016 și a avut lansarea 1.0 pe 14 august 2020 (data a fost mutată cu o lună mai devreme ca să evite lansarea Cyberpunk 2077 din septembrie 2020). — sursa: https://en.wikipedia.org/wiki/Factorio — accesat sept. 2026 — confidence: ridicata
- Expansiunea plătită Factorio: Space Age a apărut pe 21 octombrie 2024, la preț de $35 (aceeași cifră ca jocul de bază), simultan cu update-ul gratuit 2.0. — surse: https://www.neowin.net/news/factorio-space-age-expansion-gets-an-october-release-date-cost-same-price-as-base-game/, https://factorio.com/blog/post/fff-418 — 2024 — confidence: ridicata
- Prețul curent (Steam, accesat sept. 2026) al Factorio (joc de bază) e €32,00; DLC-ul Space Age costă tot €32,00. — sursa: https://store.steampowered.com/app/427520/Factorio/ — accesat sept. 2026 — confidence: ridicata
- Factorio a vândut peste 1 milion de copii (prima aniversare majoră), 2 milioane până la începutul lui 2020, 2,5 milioane la începutul lui 2021, 3,1 milioane în februarie 2022, 3,5 milioane în decembrie 2022 (ritm mediu ~500.000/an), iar Space Age a vândut peste 400.000 de copii doar în prima săptămână (oct. 2024). — surse: https://en.wikipedia.org/wiki/Factorio, https://www.pcgamesn.com/factorio/3-million-sales — confidence: ridicata pentru cifrele Wikipedia, medie pentru cifrele agregate mai vechi
- Echipa Wube Software a pornit ca "garage company" de 2 programatori + 1 graphician (Kovarex a renunțat la job în 2012) și a crescut la 31 de oameni până în februarie 2024. — sursa: https://en.wikipedia.org/wiki/Factorio — confidence: ridicata
- Scor Metacritic Factorio (PC): 90/100; PC Gamer: 91/100; Space Age: ~92/100 (PC Gamer). Pe Steam: 98% pozitiv din 117.738 recenzii (Overwhelmingly Positive), accesat direct sept. 2026. — surse: https://en.wikipedia.org/wiki/Factorio, https://store.steampowered.com/app/427520/Factorio/ — confidence: ridicata
- La lansarea Space Age, Factorio a atins un record istoric de jucători concurenți pe Steam: 91.801 în weekend-ul de lansare, urcând la 118.674 — de peste 3x față de vârful de la 1.0 (34.700 jucători, 2020). — surse: https://www.pcgamer.com/games/strategy/factorios-player-count-is-through-the-roof-after-the-space-age-expansion-ripping-thousands-of-engineers-away-from-their-day-jobs/, https://programming.dev/post/20809889 — oct. 2024 — confidence: medie (agregare presă + comunitate, nu cifră oficială Wube)
- Blogul dezvoltatorilor "Friday Facts" (FFF) apare săptămânal, neîntrerupt, din 2013; până la FFF #200 nu ratase nicio vineri. — surse: https://factorio.com/blog/post/fff-1, https://spieswl.github.io/blog/2020/seven-years-of-factorio-friday-facts — confidence: medie (blog secundar de fan, dar consistent cu arhiva oficială factorio.com/blog)
- Sistemul de copy-paste/blueprint: Ctrl+C intră în mod copiere, Ctrl+X taie (marchează pentru deconstrucție), Shift+drag deschide configurarea completă de blueprint (grid snapping, tiles, trenuri). Din versiunea 0.17.0 există istoric de clipboard: copiile anterioare rămân accesibile (Shift+scroll), salvate în fișierul de save. — sursa: https://wiki.factorio.com/Copy_and_paste — accesat sept. 2026 — confidence: ridicata (wiki oficial al jocului, secundar față de Wube dar tehnic precis)
- Factorio are 7 tipuri de "science pack" în jocul de bază (Automation, Logistic, Military, Chemical, Production, Utility, Space) și încă 5 în Space Age (Metallurgic, Electromagnetic, Agricultural, Cryogenic, Promethium) — total 12 tipuri, fiecare cu rețetă proprie și necesitând o infrastructură de producție dedicată. — sursa: https://wiki.factorio.com/Science_pack — accesat sept. 2026 — confidence: ridicata (wiki oficial)
- Satisfactory a intrat în Early Access pe 19 martie 2019, exclusiv Epic Games Store timp de un an; lansarea 1.0 a fost pe 10 septembrie 2024, simultan pe Steam și Epic Games Store. — sursa: https://en.wikipedia.org/wiki/Satisfactory — confidence: ridicata
- La 1.0, Satisfactory a atins un vârf de 104.677 jucători concurenți (locul 3 între toate jocurile Coffee Stain). — surse: https://gameworldobserver.com/2024/09/11/satisfactory-peaks-at-over-100k-ccu-launch, https://coffeestain.com/news/satisfactory-1-0-launch/ — sept. 2024 — confidence: medie-ridicata
- Satisfactory a vândut 500.000 de copii în primele 3 luni de Early Access (2019), 1,3 milioane până în iulie 2020, și 5,5 milioane până la începutul lui 2024 (pre-1.0). — surse: https://en.wikipedia.org/wiki/Satisfactory, https://games-stats.com/blog/SatisfactoryCoffeeStainStudios/ — confidence: medie (a doua sursă nu a putut fi verificată direct — fetch a întors HTTP 403 — cifrele coincid însă cu cele independente de pe Wikipedia)
- Epic Games a plătit un minim garantat de $11,5 milioane către Coffee Stain pentru exclusivitatea de un an pe Epic Games Store. — sursa: https://en.wikipedia.org/wiki/Satisfactory — confidence: ridicata
- Scor Metacritic Satisfactory: 91/100 (Universal Acclaim); IGN 9/10; PC Gamer 90/100. Premiul "PC Game of the Year" la Golden Joystick Awards 2024. — sursa: https://en.wikipedia.org/wiki/Satisfactory — confidence: ridicata
- Prețul curent (Steam, accesat sept. 2026) e $39,99. — surse: https://steampricehistory.com/app/526870, https://steamdb.info/app/526870/ — confidence: medie (agregatoare de preț, nu pagina oficială Steam accesată direct)
- Satisfactory are 10 tiere de milestone-uri (Tier 0–9), totalizând 48 de milestone-uri, deblocate prin HUB Terminal + 4 faze de Space Elevator ("Project Assembly"). Tier 0 (onboarding) are 6 milestone-uri; restul tierelor au 3–5 fiecare. — sursa: https://satisfactory.wiki.gg/wiki/Milestones — accesat sept. 2026 — confidence: medie (wiki comunitar, dar structural verificabil în joc)
- Coffee Stain a declarat explicit politica "no microtransactions, ever" pentru Satisfactory, jocul fiind cumpărare unică, fără loot boxes. — surse: https://steamcommunity.com/app/526870/discussions/0/1750148517259754600/ (thread din feb. 2020, citând comunicare oficială a studioului), corroborat de existența video-ului oficial Coffee Stain "6 things we're NEVER adding to Satisfactory" — confidence: medie (nu am găsit citatul direct pe un canal oficial primar, dar politica e consistentă cu 5+ ani fără nicio MTX introdusă)
- Nu am găsit sursa primară exactă a citatului "no fail state, only optimization" atribuit uneori dezvoltatorilor Factorio — pare a fi o formulare a comunității, nu o declarație oficială verificabilă. **NEVERIFICAT** ca citat exact, dar conceptul de fond (jocul nu are ecran de game over în Freeplay/peaceful mode; pierderea la biteri sau epuizarea resurselor duce la reconstrucție, nu la restart) e confirmat de discuții multiple pe forumurile oficiale și Steam Community. — surse: https://forums.factorio.com/viewtopic.php?t=42009, https://steamcommunity.com/app/427520/discussions/0/3044983510181289139/ — confidence: scazuta pentru citatul exact, medie pentru concept

---

## Detalii

### 1. Bucla centrală: de ce "the factory must grow" ține de investiție compusă, nu de reward simplu

Structura de bază în ambele jocuri e identică: (1) extragi manual o resursă, (2) automatizezi extracția, (3) folosești produsul automatizării ca input pentru un nivel de producție mai complex, (4) acel nivel deblochează cercetare/tehnologie care îți dă unelte mai bune pentru pasul (1)-(3), repetat la scară mai mare. Diferența față de o buclă de recompensă clasică (gen loot RPG) e că **fiecare investiție de timp crește rata la care poți investi timp în continuare** — analog cu dobânda compusă. Nu primești doar "mai mult", primești "mai rapid mai mult".

Byrne Hobart, într-un eseu analitic despre Factorio ("The Factorio Mindset"), descrie asta ca pe un obicei mental transferabil: jocul te obișnuiește "să nu lași niciodată un proces manual neautomatizat" — comparând mecanic bucla cu meditația (repetiție care instalează un reflex), nu cu un slot machine. — sursa: https://www.thediff.co/archive/the-factorio-mindset/ — confidence: medie (eseu de opinie, nu cercetare empirică)

Un alt unghi, din perspectivă de inginerie software (Erik McClure, "Factorio Is the Best Technical Interview We Have"): scalarea în Factorio expune organic bottleneck-uri — "handling your logistics network itself becomes a logistics problem in the late game" — jucătorul e forțat să re-proiecteze sistemul când designul inițial cedează sub sarcină, exact ca refactorizarea unui sistem software care nu mai ține pasul cu load-ul. Blueprint-urile standardizează soluții (analog framework-urilor de cod), iar semnalizarea trenurilor predă concepte de concurență (race conditions, deadlocks) prin manifestare fizică vizibilă. — sursa: https://erikmcclure.com/blog/factorio-is-best-interview-we-have/ — confidence: medie (blog de opinie tehnică, dar cu exemple concrete verificabile în joc)

### 2. Structura tech tree-ului: gating dublu (cercetare + infrastructură fizică)

Factorio nu deblochează tehnologii doar prin "timp petrecut" sau "puncte acumulate" — trebuie *produs fizic* combustibilul cercetării (science pack-urile), ceea ce înseamnă că progresul tehnologic e limitat de capacitatea ta de producție, nu doar de decizie. Progresia standard recomandată e: **Red (automation) → Green (logistic) → Grey/black (military) → Blue (chemical) → Purple (production) → Yellow (utility) → White (space)**, cu science pack-urile din Space Age (Metallurgic, Electromagnetic, Agricultural, Cryogenic, Promethium) adăugate ca straturi separate, fiecare specific unei planete noi. Rata de producție trebuie sincronizată — o sursă de comunitate citează un raport recomandat de 5:6:5:12:7:7 între pachetele automation/logistic/military/chemical/production/utility ca să nu se creeze blocaje în laborator. — surse: https://wiki.factorio.com/Science_pack, forum agregat (confidence scazuta pentru raportul exact 5:6:5:12:7:7 — sursă comunitară, nu verificată oficial)

Satisfactory folosește un model diferit, dar cu aceeași logică de gating dublu: **10 tiere (0-9)**, cu **48 de milestone-uri** în total, deblocate la HUB Terminal prin depunere fizică de resurse (nu se pot retrage — "parts inserted into the HUB Terminal cannot be taken back"). Progresul între tiere e blocat de fazele Space Elevator (Project Assembly): completarea Fazei 1 deblochează Tier 3-4, Faza 2 → Tier 5-6, Faza 3 → Tier 7-8, Faza 4 → Tier 9. Costul agregat al tuturor milestone-urilor e enorm în resurse brute — aproximativ 13.055 plăci de fier, 4.720 cabluri, 6.480 beton, plus zeci de componente specializate (calculatoare, sisteme de răcire, materiale exotice). — sursa: https://satisfactory.wiki.gg/wiki/Milestones — accesat sept. 2026 — confidence: medie (wiki comunitar)

### 3. Blueprint/copy-paste ca sistem de reutilizare — piesa care face complexitatea suportabilă

Fără blueprint-uri, orice reconstrucție ar necesita muncă manuală identică repetată de fiecare dată — exact tipul de fricțiune care ar transforma complexitatea în frustrare, nu în satisfacție. Sistemul Factorio permite: copiere selectivă (Ctrl+C + drag), tăiere cu deconstrucție automată (Ctrl+X), configurare completă de blueprint cu grid snapping și includere de șine/trenuri (Shift+drag), și — din 0.17.0 — un istoric de clipboard persistent în save, accesibil prin Shift+scroll. Practic, blueprint-ul e mecanismul prin care jucătorul "compilează" o soluție găsită o dată (poate după 5-6 încercări eșuate) și o poate reutiliza la nesfârșit, la scară, fără cost cognitiv repetat. — sursa: https://wiki.factorio.com/Copy_and_paste — confidence: ridicata

Ambele jocuri au și o cultură comunitară puternică de partajare a blueprint-urilor (Factorio: factorioprints.com, un site dedicat exclusiv acestui scop) — semn că reutilizarea nu e doar o unealtă individuală, ci un obiect social de schimb între jucători.

### 4. Multiplayer: diviziune naturală a muncii, nu roluri impuse

Limita tehnică de jucători pe server Factorio e 65.535, dar limita practică recomandată e ~500 (sursă comunitară secundară). Ce contează pentru design nu e cifra, ci structura: fiecare subsistem (minerit, transport pe șine, topire, producție de componente, cercetare, apărare) e suficient de mare și suficient de independent cât să poată fi "deținut" integral de un jucător, fără să blocheze pe ceilalți. Diviziunea muncii apare organic — un jucător extinde rețeaua de minerit și șinele, altul reconstruiește topirea, altul se ocupă de știință sau apărare — coordonarea se face prin voice chat, nu prin sistem de roluri fix impus de joc. Există și mod-uri dedicate rolurilor stricte (ex. mod-ul "Teamwork", care forțează baze separate pe cadrane cu schimb de bunuri între ele), dar acestea sunt varianta minoritară — jocul de bază preferă cooperare fluidă. — surse: https://www.co-optimus.com/game/3888/pc/factorio.html, https://gamefoundry.games/blog/best-factory-games-coop — confidence: medie (surse secundare, agregare comunitară)

### 5. Fără tutorial clasic — învățare prin presiune de sistem

Niciunul din jocuri nu are un tutorial tradițional cu pași ghidați end-to-end. Factorio are un scenariu de campanie/introducere gândit ca tutorial parțial — dar deliberat lasă anumite lucruri neclare, "precis ca să învețe jucătorii să facă cercetare [să investigheze singuri]" (sursă comunitară secundară, forums.factorio.com, neconfirmată oficial ca intenție explicită de design). Modul real de învățare e prin blocaj vizibil: o bandă se umple și se oprește, un robot rămâne fără combustibil, un laborator stă inactiv — fiecare simptom vizibil forțează jucătorul să investigheze cauza. O sursă comunitară (neconfirmată oficial) susține că aproape jumătate din jucătorii activi abandonează undeva între atingerea petrolului și obținerea roboților de construcție — un "zid de complexitate" real, documentat empiric doar la nivel anecdotic. — surse: https://steamcommunity.com/app/427520/discussions/0/1693788384138138735/, forumuri agregate — confidence: scazuta pentru cifra "jumătate abandonează" (NEVERIFICAT ca statistică oficială)

### 6. "No fail state" — ce înseamnă mai exact

Nu am găsit un citat oficial verificabil "there is no fail state, only optimization" atribuit direct echipei Wube. Ce e verificabil: în Freeplay/peaceful mode, nu există ecran de game over — moartea jucătorului înseamnă doar respawn cu pierdere de inventar nedepus, iar epuizarea resurselor locale sau distrugerea unei părți de fabrică de către biteri înseamnă doar rebuild, nu restart de campanie. Discuțiile pe forumul oficial confirmă că designul a evoluat explicit către reducerea presiunii letale (ex. eliminarea "alien artifacts" în 0.15, mutând accentul integral pe designul fabricii ca "the main part of the game" — citat direct de la un dezvoltator Wube, Rseding91). — surse: https://forums.factorio.com/viewtopic.php?t=42009, https://steamcommunity.com/app/427520/discussions/0/3044983510181289139/ — confidence: medie

### 7. Sesiuni lungi și "time dilation" — documentate empiric, nu artificiu de manipulare

Comunitatea Factorio folosește constant porecla **"Cracktorio"** (confirmată și pe pagina Wikipedia a jocului). Rapoarte directe din Steam Community: un jucător a plănuit "20-30 de minute înainte de culcare" și a jucat 9 ore; altul descrie "time dilation" — o oră percepută devine efectiv 4 ore reale; un al treilea: "I think 'just two hours, just two hours...' and I only recover my senses eight hours later". Important pentru design: acest efect NU vine din variable-reward gambling-style (nu există loot cu probabilitate randomizată care să creeze anticipare de tip slot machine) — vine din rezolvarea continuă de micro-probleme cu feedback vizual imediat și din faptul că "următorul pas" e mereu vizibil și mereu accesibil (nu există cooldown-uri artificiale sau bariere de timp). — surse: discuții multiple Steam Community (427520), agregare — confidence: scazuta-medie (evidență anecdotică, nu studiu formal)

### 8. Update cadence și modelul 1.0 → expansiune plătită

Factorio a rulat blogul **Friday Facts** neîntrerupt, săptămânal, din 2013 — o unealtă de retenție a comunității în timpul unui development de 8 ani în Early Access (2016-2020), fără nicio pauză de comunicare. Modelul de monetizare post-1.0: joc premium ($35), **zero microtranzacții**, o singură expansiune mare plătită la același preț ca jocul de bază (Space Age, 2024) + update gratuit major (2.0) livrat simultan. Wikipedia notează că în iunie 2026 dezvoltatorii au anunțat 2.1 ca ultimul update major planificat — semn că echipa consideră ciclul de conținut încheiat, nu că jocul "moare" comercial (vânzările Space Age au bătut recorduri). — surse: https://en.wikipedia.org/wiki/Factorio, https://factorio.com/blog/post/fff-418 — confidence: ridicata pentru datele de lansare, medie pentru interpretarea „ciclu încheiat”

Satisfactory a urmat un tipar similar: 5+ ani de Early Access (martie 2019 → septembrie 2024) cu update-uri regulate, apoi lansare 1.0 simultan pe Steam + Epic (rupând exclusivitatea EGS), politică fermă "no microtransactions, ever", migrare de motor UE4→UE5 în timpul dezvoltării (noiembrie 2023) — un semnal că echipa a fost dispusă să suporte cost tehnic mare de refactorizare pentru calitate, nu doar să adauge conținut. — surse: https://en.wikipedia.org/wiki/Satisfactory — confidence: ridicata

### 9. Tabel comparativ — repere cheie

| | Factorio | Satisfactory |
|---|---|---|
| Early Access start | 25 feb. 2016 | 19 mar. 2019 |
| 1.0 | 14 aug. 2020 | 10 sept. 2024 |
| Preț bază (curent) | €32 (~$35) | $39,99 |
| Expansiune plătită | Space Age, $35 (oct. 2024) | — (fără expansiuni plătite până la data cercetării) |
| Microtranzacții | Zero | Zero ("no microtransactions, ever") |
| Vânzări | 3,5M+ (dec. 2022), 500k/an mediu | 5,5M+ (ian. 2024), 6M+ la 1.0 |
| Peak concurrent (Steam) | 118.674 (oct. 2024, record istoric) | 104.677 (sept. 2024, 1.0) |
| Metacritic | 90/100 | 91/100 |
| Steam review % | 98% pozitiv (117.738 recenzii) | — (nu am verificat direct, NEVERIFICAT) |
| Tiere tech tree | 12 tipuri de science pack | 10 tiere (Tier 0-9), 48 milestone-uri |
| Echipa la 1.0 | 31 oameni (Wube Software) | Coffee Stain Studios (studio mediu) |

---

## Ce putem fura pentru Driftwood

1. **"No fail state, doar setback"** ca principiu de design formal — nu doar absența morții permanente (deja adevărat în Driftwood), ci extinderea explicită a principiului la orice sistem nou (dacă adăugăm crafting/automatizare, un eșec de design nu trebuie să coste progres pierdut ireversibil, doar timp de reconstrucție). Cost: **mic** — e o regulă de design, nu cod nou.
2. **Blueprint/"save layout" pentru zonele construibile ale jucătorului** — dacă Driftwood ajunge să aibă structuri plasabile pe malul propriu (plase, unelte, decor, eventual mici "stații" de procesare), o funcție de "salvează acest aranjament, aplică-l în altă parte" reduce fricțiunea repetitivă drastic. Cost: **mediu** — necesită serializare de layout + UI de plasare, dar se pretează bine la arhitectura 2D ScreenGui deja aleasă (D04/D09).
3. **Gating dublu cercetare+producție** pentru orice sistem de progresie viitor (ex. upgrade-uri de plasă/atelier) — nu doar "acumulează puncte", ci "trebuie să produci fizic resursa de cercetare", ceea ce leagă progresul de participare activă la economia jocului, nu doar de timp scurs. Cost: **mic** — e o regulă de tuning peste sistemele deja planificate (meșteșugit D18).
4. **Diviziune naturală a muncii în cooperarea de oraș** — atelierul orașului (D18, 12 zone) poate fi proiectat explicit ca "fiecare zonă/set e suficient de mare cât să ocupe o persoană complet", nu ca sarcini mărunte împărțite artificial. Cost: **mic-mediu** — impact mai ales pe design-ul conținutului din atelier, nu pe arhitectură.
5. **Sistem de calitate stratificat (Normal→Legendary), împrumutat din Quality System-ul Space Age** — aceleași rețete, dar cu variante de calitate mai bune ca sink de progres pe termen lung pentru jucătorii veterani, fără să adauge conținut nou de bază. Se mapează natural pe obiectele din Index (D17, 200 obiecte, 7 tiere) — poate deveni un al doilea ax de progres ortogonal pe tiere. Cost: **mediu** — necesită variante vizuale/valorice per obiect, dar reutilizează sistemele existente de tiere.
6. **Cercetare "infinită"/repetabilă opțională** (analog Factorio: infinite technologies plătite cu Space Science) — un sink Sisific opțional pentru jucătorii care au terminat conținutul de bază, fără presiune pentru jucătorii casual. Cost: **mic** — un multiplicator de cost + bonus marginal, nu conținut nou.
7. **Onboarding prin presiune de sistem vizibilă, nu tutorial text** — în loc de popup-uri explicative, semnalizare vizuală clară când un sistem e blocat/inactiv (bandă plină, plasă la capacitate) care invită investigația, exact ca modelul Factorio. Cost: **mic** — design de UI/feedback, nu sistem nou.
8. **Weekly devblog stil "Friday Facts" pentru construirea comunității înainte de lansare** — un ritual săptămânal de comunicare (chiar și scurt) construiește anticipare și încredere tehnică, exact cum a făcut Wube timp de 8 ani în Early Access. Cost: **mic** — cost de marketing/comunicare, nu de dezvoltare.
9. **Blueprint sharing comunitar** (analog factorioprints.com) — dacă layout-urile devin salvabile, un mecanism simplu de export/import de coduri (string) permite jucătorilor să schimbe design-uri fără infrastructură server suplimentară. Cost: **mic-mediu** — depinde dacă se face local (string copiabil) sau prin DataStore centralizat.

---

## Ce NU merge pentru noi

- **Simularea fizică continuă de mii de entități pe bandă** (belt logistics la scară Factorio) — Driftwood e construit integral 2D în ScreenGui, fără Workspace/fizică (D04, D09). Factorio însuși a avut nevoie de un engine C++ optimizat manual, ani de optimizare UPS dedicată (vezi Friday Facts #421 "Optimizations 2.0") pentru performanță la scară mare — o echipă mică pe Luau/Roblox nu poate reconstrui asta fără un cost tehnic disproporționat. Dacă vrem "automatizare", trebuie simulată abstract (tick-uri discrete, nu mișcare continuă a mii de sprite-uri).
- **Modelul de monetizare premium + DLC plătit, zero MTX** — incompatibil direct cu decizia deja luată pentru Driftwood (D20: Passes + Products, F2P, banii cumpără doar viteză/spațiu/estetică). Factorio/Satisfactory pot ignora F2P pentru că vând o singură dată la preț mare unei audiențe auto-selectate (ingineri adulți, dispuși să plătească $35-70). Roblox nu permite acest model pentru jocul de bază.
- **Zidul de complexitate care pierde ~jumătate din jucători** (NEVERIFICAT ca statistică oficială, dar direcția e plauzibilă și documentată anecdotic) — acceptabil pentru Factorio (cumpărătorul deja a plătit, deja s-a auto-selectat ca "genul de om care vrea asta"), complet inacceptabil pentru Driftwood: retenția e obiectivul central declarat al proiectului, iar audiența Roblox e tânără și eterogenă ca skill. Orice zid de complexitate similar ar trebui introdus mult mai gradual, cu mult mai mult scaffolding.
- **Hărți hand-crafted de zeci de km²** (Satisfactory: ~30 km²) — imposibil de produs de o echipă mică fără instrumente proceduralizate; Driftwood a ales deja generare determinist pe seed pentru râu (D13) — direcția corectă, dar exclude explicit ambiția de "hartă masivă construită manual".
- **Sesiuni deliberat concepute să erodeze percepția timpului ("time dilation", 8-12h neîntrerupte)** — pe lângă riscul etic cu o audiență tânără, Roblox are politici active de screen-time și protecție a minorilor (vezi notele de cercetare 01/06 din corpusul existent despre verificare de vârstă); a proiecta deliberat pierderea noțiunii timpului ca obiectiv de retenție e un risc de conformitate, nu doar etic. Compulsion loop-ul de recompensă-pas-cu-pas e de furat; "uită să te oprești" nu e un obiectiv de design sănătos aici.
- **Combat/presiune letală de tip "biteri"** — brief-ul exclude explicit dezastrele naturale și cere joc corect; sistemul de apărare împotriva dușmanilor din Factorio (deși opțional dezactivabil în peaceful mode) e gândit ca sistem de tensiune care nu se potrivește automat tonului "orășel cozy pe malul râului" fără o re-tematizare atentă.

---

## Riscuri și necunoscute

- **NEVERIFICAT**: citatul exact "there is no fail state, only optimization" — nu am găsit sursă primară Wube care să-l confirme cuvânt cu cuvânt; tratați-l ca rezumat comunitar al unui principiu real, nu ca citat de folosit direct.
- **NEVERIFICAT**: statistica "aproape jumătate din jucătorii activi Factorio abandonează în jurul zidului petrol+roboți" — vine din surse comunitare secundare, nu dintr-un raport oficial Wube cu date de retenție.
- **Confidence medie**: cifrele de vânzări/venit Satisfactory de pe games-stats.com (5,5M copii, $120M venit) nu au putut fi verificate prin fetch direct (pagina a răspuns HTTP 403); cifrele parțiale se confirmă independent pe Wikipedia, dar suma exactă de venit rămâne neconfirmată dintr-o sursă primară.
- **Întrebare tehnică deschisă, fără sursă găsită**: nu există niciun caz documentat public de "belt/factory automation la scară Factorio construit pe Roblox ScreenGui 2D fără Workspace" — nu știm dacă arhitectura aleasă (D04/D09, UI pur, fără fizică) poate susține o simulare de automatizare la orice scară relevantă, sau dacă limitele Luau/replicare RemoteEvent forțează un plafon mult mai mic decât ce ar fi "satisfăcător" ca sistem. Recomand un spike tehnic dedicat înainte de a proiecta orice sistem de automatizare inspirat din Factorio.
- **Necunoscut**: nu există date despre cum reacționează concret audiența tânără de pe Roblox la sisteme de complexitate stil Factorio — toate datele de mai sus vin din audiența PC/Steam a unor jocuri premium, auto-selectată spre adulți cu toleranță ridicată la complexitate. Fit-ul cu audiența Roblox e o ipoteză de design, nu un fapt verificat.
- **Numărul exact de items/rețete/tehnologii din Factorio nu a putut fi confirmat** dintr-o sursă oficială cu total agregat (wiki.factorio.com nu publică un total explicit) — util de reținut ca gaură de date dacă se dorește un benchmark cantitativ precis "câte sisteme sunt prea multe sisteme".

---

## Surse

- Wikipedia — Factorio. https://en.wikipedia.org/wiki/Factorio — accesat sept. 2026
- Wikipedia — Satisfactory. https://en.wikipedia.org/wiki/Satisfactory — accesat sept. 2026
- Factorio Steam Store Page. https://store.steampowered.com/app/427520/Factorio/ — accesat sept. 2026
- Factorio Wiki — Science pack. https://wiki.factorio.com/Science_pack — accesat sept. 2026
- Factorio Wiki — Copy and paste. https://wiki.factorio.com/Copy_and_paste — accesat sept. 2026
- Factorio Wiki — Technologies. https://wiki.factorio.com/Technologies — accesat sept. 2026
- Friday Facts #418 — Space Age release date. https://factorio.com/blog/post/fff-418 — 2024
- Friday Facts #1. https://factorio.com/blog/post/fff-1 — 2013
- Neowin — Factorio: Space Age expansion gets an October release date. https://www.neowin.net/news/factorio-space-age-expansion-gets-an-october-release-date-cost-same-price-as-base-game/ — 2024
- PCGamesN — Factorio has passed 3.1 million sales in 6 years. https://www.pcgamesn.com/factorio/3-million-sales — 2022
- PC Gamer — Factorio's player count is through the roof after the Space Age expansion. https://www.pcgamer.com/games/strategy/factorios-player-count-is-through-the-roof-after-the-space-age-expansion-ripping-thousands-of-engineers-away-from-their-day-jobs/ — oct. 2024
- programming.dev — Factorio reached its highest ever concurrent player count. https://programming.dev/post/20809889 — oct. 2024
- GamesRadar+ — Factorio launches Space Age DLC to 98% overwhelmingly positive reviews. https://www.gamesradar.com/games/strategy/beloved-factory-management-game-factorio-launches-its-sequel-sized-dlc-to-98-percent-overwhelmingly-positive-reviews-and-an-all-time-player-count-record/ — oct. 2024
- The Diff (Byrne Hobart) — The Factorio Mindset. https://www.thediff.co/archive/the-factorio-mindset/ — nedatat, accesat sept. 2026
- Erik McClure — Factorio Is the Best Technical Interview We Have. https://erikmcclure.com/blog/factorio-is-best-interview-we-have/ — accesat sept. 2026
- Factorio Forums — Design Issues thread (Rseding91 quote). https://forums.factorio.com/viewtopic.php?t=42009 — accesat sept. 2026
- Steam Community — Failure Condition on FreePlay?. https://steamcommunity.com/app/427520/discussions/0/3044983510181289139/ — accesat sept. 2026
- Steam Community — Factorio, discuții despre sesiuni lungi de joc ("Cracktorio"). https://steamcommunity.com/app/427520/discussions/0/1629665087666913587, https://steamcommunity.com/app/427520/discussions/0/3055111535935721042 — accesat sept. 2026
- Co-Optimus — Factorio (PC) Co-Op Information. https://www.co-optimus.com/game/3888/pc/factorio.html — accesat sept. 2026
- spieswl — Seven Years of Factorio Friday Facts. https://spieswl.github.io/blog/2020/seven-years-of-factorio-friday-facts — 2020
- Satisfactory Wiki (wiki.gg) — Milestones. https://satisfactory.wiki.gg/wiki/Milestones — accesat sept. 2026
- Game World Observer — Satisfactory peaks at over 100k concurrent players after 1.0 launch. https://gameworldobserver.com/2024/09/11/satisfactory-peaks-at-over-100k-ccu-launch — sept. 2024
- Coffee Stain Group — Satisfactory 1.0 Launch. https://coffeestain.com/news/satisfactory-1-0-launch/ — sept. 2024
- games-stats.com — Commercial Success of Satisfactory 1.0. https://games-stats.com/blog/SatisfactoryCoffeeStainStudios/ — nu a putut fi accesat direct (HTTP 403), citat prin rezultate de căutare agregate
- Steam Price History — Satisfactory. https://steampricehistory.com/app/526870 — accesat sept. 2026
- SteamDB — Satisfactory. https://steamdb.info/app/526870/ — accesat sept. 2026
- Steam Community — Micro Transactions (Satisfactory). https://steamcommunity.com/app/526870/discussions/0/1750148517259754600/ — accesat sept. 2026
