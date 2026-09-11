# Discovery, algoritm, Ads Manager și lansare

## Rezumat executiv

- Algoritmul de Home (Recomandări) funcționează în două etape — **Retrieval** (selecție pe bază de engagement/retenție/monetizare) și **Ranking** (personalizare per utilizator) — și, esențial, **doar traficul organic venit din Home Recommendations alimentează algoritmul**; jucătorii aduși prin ads, curare, prieteni sau search NU contează pentru engagement/retenție/monetizare în scopul ranking-ului. Deci reclamele plătite nu "hrănesc" direct algoritmul de descoperire organică — cumpără trafic, nu semnal de calitate. Sursă: create.roblox.com/docs/discovery, accesat 2026-09-08.
- Semnalele-cheie sunt **medii per utilizator**, nu totaluri — un joc mic cu jucători implicați nu e dezavantajat față de un joc mare cu retenție slabă. Playtime e plafonat la 60 min/utilizator/joc/zi — sesiunile foarte lungi nu mai aduc beneficiu suplimentar de ranking peste acest prag. Sursă: create.roblox.com/docs/discovery, 2026-09-08.
- Cold-start e adresat explicit de Roblox: **"even a small number of people playing can signal to the system that the game is worth considering for distribution to more users"** — deci un test mic, bine țintit (10-50 jucători reali, sesiuni de calitate) poate declanșa extindere organică, fără reclame. Sursă: create.roblox.com/docs/discovery, 2026-09-08.
- Video-urile de gameplay pe Home sunt cea mai mare pârghie nouă din 2026: în teste oficiale (mai-iulie 2026), jocuri cu video au avut **până la +39% playtime din Recommended-For-You**; cazuri concrete: Superstar Baseball +30% plays/+31% playtime, Notoriety: A PAYDAY Experience +41%/+39%. Upload gratuit, max 3 video-uri/joc, moderare ~24h. Sursă: devforum.roblox.com, postări din 09.03.2026 și 31.08.2026.
- Ads Manager e licitație automată (nu manuală): Roblox calculează bidul optim pentru "cele mai multe play-uri la cel mai mic cost". 1 credit publicitar = 263 Robux; prima taxă card e $5 USD. Nu există prag minim de buget documentat public — orice sumă e acceptată. Sursă: create.roblox.com/docs/production/promotion/ads-manager, 2026-09-08.
- **"Today's Picks" a fost redenumit oficial "Standout Games"** (anunț 09.03.2026) — orice referință mai veche la "Today's Picks" e depășită. Standout Games e curatoriere manuală pentru mecanici noi/genuri sub-reprezentate — nu afectează ranking-ul organic, doar promovarea curatoriată.
- **(corectat la verificare) Există în prezent (sept. 2026) programe publice active de tip finanțare/susținere pentru creatori — "Jumpstart" și "Incubator"**, anunțate oficial pe 09.03.2026, care înlocuiesc funcțional vechile "Game Fund" (2021) și "Accelerator" (2022, ambele închise). Jumpstart e continuu/rolling, pentru echipe noi pe Roblox sau care explorează jocuri noi (necesită cel puțin un membru 18+); Incubator e un program de 6 luni, milestone-driven, pentru echipe cu prototip solid (până la 40 de echipe/cohortă, cohorta 2026 a avut 26 de echipe selectate). Ambele oferă sprijin "in-kind" (mentorat, promovare, ajutor la user acquisition), NU finanțare cash directă. Sursă: https://create.roblox.com/docs/creator-programs/jumpstart și https://about.roblox.com/newsroom/2026/03/roblox-announces-incubator-jumpstart-creator-programs, verificat 2026-09-09.
- Grow a Garden a crescut **aproape exclusiv organic** (fără publicitate plătită documentată): lansat 26.03.2025 de un dezvoltator solo de 16 ani, 1.000 CCU în aprilie 2025, 22,3M CCU vârf în august 2025, 35,3 miliarde vizite până în mai 2026 — motorul a fost bucla de creștere offline + conținut săptămânal, nu marketing extern. Detalii complete (inclusiv Fisch) sunt deja documentate în `docs/research/[object Object]1-case-fisch-gag.md` — acest fișier nu le repetă integral.
- Pentru un dezvoltator solo, nou pe Roblox, fără buget mare: strategia realistă e **cold-start organic prin calitatea semnalelor (retenție, sesiuni calificate) + test mic cu Ads Manager (50-200$ ca să valideze CPP) înainte de orice cheltuială serioasă**, plus marketing extern prin Share Links trackabile (TikTok/YouTube Shorts), nu prin sponsorizări scumpe de influenceri mari.

## Fapte verificate

- Algoritmul de Home are 2 etape: Retrieval (pe bază de "engagement, retention, and monetization") și Ranking (personalizare); sursă: https://create.roblox.com/docs/discovery, accesat 2026-09-08, fără dată de ultimă actualizare vizibilă pe pagină; confidence: ridicata (documentație oficială).
- Doar traficul organic din Home Recommendations e folosit pentru semnalele de engagement/retenție/monetizare din ranking — traficul din ads, curare, prieteni sau search e exclus din acest calcul; sursă: https://create.roblox.com/docs/discovery, 2026-09-08; confidence: ridicata.
- Semnale "most important": Play Through Rate, First Play Bounce Rate (praguri la <60s și 61-180s), Play Days per User (D1, D2-7, D8-28), Playtime per User (plafon 60 min/utilizator/joc/zi); semnale "important": Co-Play Days, Qualified Play Sessions per User, Spend Days per User, Robux Spent per User — toate ca medii per utilizator; sursă: https://create.roblox.com/docs/discovery, 2026-09-08; confidence: ridicata.
- Citat oficial despre cold-start: "even a small number of people playing can signal to the system that the game is worth considering for distribution to more users"; sursă: https://create.roblox.com/docs/discovery, 2026-09-08; confidence: ridicata.
- "Today's Picks" a fost redenumit "Standout Games" — curatoriere manuală pentru mecanici noi/stiluri distincte/genuri sub-reprezentate; nu influențează ranking-ul organic; sursă: devforum.roblox.com/t/how-we-are-improving-home-this-year, autor starrrydays (staff Roblox), publicat 09.03.2026, actualizat de loopcoded pe 29.07.2026; confidence: ridicata (postare oficială Roblox).
- Semnale noi de algoritm introduse pe 26.03.2026: Deep Play Through Rate, 7-Day Qualified Play Sessions, semnal Dismiss/Not Interested; sursă: devforum.roblox.com/t/how-we-are-improving-home-this-year, 2026-03-09/03-26; confidence: ridicata.
- Video-urile de gameplay pe Home: test mai-iulie 2026 a arătat până la +39% playtime din Recommended-For-You; pentru Standout Games cu video: +47% quality plays, +1,09% playtime; sursă: devforum.roblox.com/t/how-we-are-improving-home-this-year, actualizare 29.07.2026; confidence: ridicata.
- Cazuri concrete de lift din video pe Home: Superstar Baseball +30% RFY plays / +31% RFY playtime; Notoriety: A PAYDAY® Experience +41% RFY plays / +39% RFY playtime; perioadă test 7-26 iunie 2026; sursă: devforum.roblox.com/t/gameplay-videos-on-home-help-your-games-get-discovered/4842601, publicat 31.08.2026; confidence: ridicata (postare oficială Roblox, date exacte).
- Limită video pe Home: maxim 3 video-uri per joc, upload din Creator Hub → Place settings → Videos, moderare ~24h; conținutul trebuie să fie gameplay real, fără trailer cinematic, voiceover sau muzică cu versuri; sursă: devforum.roblox.com/t/gameplay-videos-on-home-help-your-games-get-discovered/4842601, 31.08.2026; confidence: ridicata.
- Thumbnail imagine: raport 16:9, ideal 1920×1080px, formate .jpg/.gif/.png/.tga/.bmp, până la 10 imagini per pagină de joc, sub 3 MB; sursă: https://create.roblox.com/docs/production/publishing/thumbnails, 2026-09-08; confidence: ridicata.
- Thumbnail video: cotă de 3 upload-uri/lună, NU suportat pe Xbox/PlayStation/VR, interzis voiceover/narațiune/muzică cu versuri; lungime exactă, format și dimensiune fișier NU sunt publicate — NEVERIFICAT; sursă: https://create.roblox.com/docs/production/publishing/thumbnails, 2026-09-08; confidence: medie (parțial documentat).
- Icon experiență: șablon 512×512px, pătrat, minim 512×512 pentru rezoluție înaltă, se micșorează la 150×150px în unele zone ale UI; format fișier și limită de mărime NU sunt publicate — NEVERIFICAT; sursă: https://create.roblox.com/docs/production/publishing/experience-icons, 2026-09-08; confidence: medie.
- Ads Manager: obiective de campanie — Plays, Earnings (Limited), Engagement (necesită age-check, pentru Kids/Select); licitație automată — Roblox calculează bidul pentru cele mai multe play-uri la cel mai mic cost; tipuri de buget: zilnic și lifetime; sursă: https://create.roblox.com/docs/production/promotion/ads-manager, 2026-09-08; confidence: ridicata.
- 1 credit publicitar = 263 Robux; taxă inițială card $5 USD la prima campanie, folosită spre prima factură; țintire după: All Players, New Players, Recent Players, Lapsed Players, plus locație, vârstă, gen, gen(re), tip dispozitiv; CPP = cheltuială totală ÷ număr de play-uri; sursă: https://create.roblox.com/docs/production/promotion/ads-manager, 2026-09-08; confidence: ridicata.
- Statistici oficiale de marketing (fără metodologie/eșantion publicate): "150% lift in impressions for games that run ads", "24% increase in plays", "16% increase in playtime"; caz Hypershot: reclamele sponsorizate = până la 10% din play-uri; sursă: https://create.roblox.com/docs/production/promotion/advertise, 2026-09-08; confidence: medie (cifre de marketing proprii Roblox, fără interval de timp/eșantion specificat).
- Nu s-a găsit niciun cost-per-play (CPP) sau CPM în dolari publicat oficial de Roblox pentru Ads Manager — thread-urile de comunitate din 2024 confirmă doar conceptul (CPP ~ cost pe 1000 impresii, licitație tip auction), fără cifre; sursă: devforum.roblox.com/t/what-is-cost-per-play, 02.04.2024, clarificare 04.11.2024; confidence: scazuta (subiect vechi, fără cifre reale, marcat NEVERIFICAT pentru $ concret).
- Immersive Ads (billboards video/imagine, portaluri): dimensiuni unitate video min 8×4,5 studs, max 32×18 studs; eligibilitate creator: cont 13+, ID-verificat, 2FA activ; joc public cu 2.000+ vizitatori unici lunari; plată pe 25 ale lunii următoare inserării unității; sursă: https://create.roblox.com/docs/production/monetization/immersive-ads, 2026-09-08; confidence: ridicata.
- Creator Rewards — Daily Engagement: activ automat pentru toți creatorii din 24.07.2025, fără verificare ID; 5 Robux per "Active Spender" cu sesiune 10+ minute, dacă jocul e printre primele 3 lansate de acel jucător în ziua respectivă; sursă: https://create.roblox.com/docs/creator-rewards, 2026-09-08; confidence: ridicata (confirmă exact ce spune deja CLAUDE.md al proiectului).
- Creator Rewards — Audience Expansion: necesită cont ID-verificat + DevEx; 35% revenue share din primii 100$ de "Qualifying Purchases" în primele 60 de zile ale unui jucător; necesită medie 100+ DAU susținută 60 de zile de la alăturare; sursă: https://create.roblox.com/docs/creator-rewards, 2026-09-08; confidence: ridicata.
- Rata DevEx standard actuală: 0,0038$/Robux câștigat (ex.: 114$ pentru 30.000 Robux); rată majorată 0,0054$/Robux pentru câștiguri specifice de la jucători SUA 18+ verificați facial/ID; rata veche (0,0035$) s-a aplicat până pe 05.09.2025, ora 10:00 PT; minim 30.000 Robux câștigați, o cerere/lună calendaristică; sursă: https://create.roblox.com/docs/production/monetization/developer-exchange, 2026-09-08; confidence: ridicata.
- Legături social media pe pagina de joc: doar Facebook, Twitter/X, YouTube, Twitch, Discord, Guilded, comunitate Roblox — **TikTok NU e un tip de link suportat nativ**; maxim 3 link-uri; UI-ul de adăugare e ascuns dacă creatorul nu are 16+ vârstă verificată (facial sau ID); sursă: https://create.roblox.com/docs/production/promotion/social-media-links, 2026-09-08; confidence: ridicata.
- Share Links: link-uri trackabile nelimitate, create din Creator Dashboard → Creations → Share Links, cu LaunchData opțional; folosite pentru a măsura achiziția de utilizatori din surse externe (TikTok, YouTube etc.); sursă: https://create.roblox.com/docs/production/promotion/share-links, 2026-09-08; confidence: ridicata.
- "Game Fund" (2021, 500.000$) și "Accelerator" (2022) sunt încheiate, dar **(corectat la verificare) au fost înlocuite de programele active "Jumpstart" și "Incubator"**, anunțate 09.03.2026: Jumpstart — rolling/continuu, pentru echipe noi pe Roblox; Incubator — 6 luni, milestone-driven, până la 40 echipe/cohortă (26 selectate în cohorta 2026); ambele oferă mentorat + promovare (nu cash direct), cel puțin un membru de echipă trebuie să aibă 18+; sursă: https://create.roblox.com/docs/creator-programs/jumpstart, https://about.roblox.com/newsroom/2026/03/roblox-announces-incubator-jumpstart-creator-programs, verificat 2026-09-09; confidence: ridicata (documentație oficială + comunicat de presă oficial).
- Roblox Q2 2026 (încheiat 30.06.2026): 123 milioane DAU, 29 miliarde ore de engagement, venit 1,5 miliarde $, bookings 1,6 miliarde $; sursă: Roblox Q2 2026 Earnings Press Release, https://s27.q4cdn.com/984876518/files/doc_financials/2026/q2/Roblox-Q2-2026-Earnings-Press-Release.pdf, prin ir.roblox.com; confidence: ridicata (comunicat oficial pentru investitori).
- Grow a Garden: lansat 26.03.2025, dezvoltat inițial de un adolescent solo de 16 ani ("BMWLux"), construit "în doar trei zile", ~1.000 CCU înainte de achiziția parțială de către Splitting Point Studios (aprilie 2025); vârf de 22,3 milioane CCU pe 23.08.2025; 35,3 miliarde+ vizite până în mai 2026; cel mai rapid joc care a atins 1 miliard de vizite (33 zile) — creștere descrisă ca predominant organică/virală, fără dovezi de campanie publicitară plătită majoră; sursă: en.wikipedia.org/wiki/Grow_a_Garden (agregator secundar, cu citări din PC Gamer, NYT, Reuters, PocketGamer.biz), accesat 2026-09-08; confidence: medie (sursă secundară) — detalii complete deja în `docs/research/[object Object]1-case-fisch-gag.md`.
- Fisch nu are pagină Wikipedia dedicată (verificat direct); creșterea sa e documentată doar prin surse comunitare secundare (fandom wiki) în fișierul dedicat de caz — NU s-a găsit un interviu sau sursă oficială despre strategia de marketing (organic vs. plătit); confidence: scazuta pentru orice cifră de marketing Fisch — marcat NEVERIFICAT.
- Rate de sponsorizare pentru YouTuberi Roblox (cost/video, reach tipic) — căutările acestei sesiuni (motoare de căutare blocate de CAPTCHA/403) NU au produs nicio sursă primară sau secundară fiabilă; marcat explicit **NEVERIFICAT** — nu inventez cifre.

## Detalii

### Cum funcționează algoritmul de Home (Recommended For You)

Sursa primară e https://create.roblox.com/docs/discovery, completată de postarea oficială de roadmap din 09.03.2026 (actualizată 29.07.2026): https://devforum.roblox.com/t/how-we-are-improving-home-this-year.

**Arhitectura în două etape:**

1. **Retrieval** — un set mai larg de jocuri candidate e selectat pe baza semnalelor agregate de engagement, retenție și monetizare.
2. **Ranking** — din setul de candidate, sistemul alege și ordonează personalizat pentru fiecare utilizator, în funcție de comportamentul lui istoric.

**Nuanța critică pentru buget de marketing:** documentația spune explicit că Roblox NU contorizează engagement/retenție/monetizare pentru utilizatorii "first acquired from ads, curation, friends, search" — doar traficul organic din Home Recommendations alimentează bucla de ranking. Practic: dacă cumperi trafic prin Ads Manager, acei jucători nu "împing" jocul mai sus în Recommended For You doar pentru că au jucat mult — trebuie ca jocul să performeze și cu trafic organic (search, share links, viral) ca să crească în Home.

**Tabel — semnale de ranking (per utilizator, medii, nu totaluri):**

| Semnal | Categorie | Detaliu |
|---|---|---|
| Play Through Rate | Most important | Rata la care utilizatorii joacă după ce văd jocul recomandat |
| First Play Bounce Rate | Most important | Măsurat la <60s și medie 61-180s |
| Play Days per User | Most important | Urmărit pe D1, D2-7, D8-28 |
| Playtime per User | Most important | Plafon: 60 min/utilizator/joc/zi |
| Intentional Co-Play Days per User | Important | Prieteni care se alătură intenționat |
| Qualified Play Sessions per User | Important | Exclude click-uri accidentale |
| Spend Days per User | Important | Zile cu tranzacție |
| Robux Spent per User | Important | Medie, nu total |
| Deep Play Through Rate (nou, 26.03.2026) | Nou | Implicare susținută, nu doar click inițial |
| 7-Day Qualified Play Sessions (nou, 26.03.2026) | Nou | Angajament repetat în 7 zile |
| Dismiss / Not Interested (nou, 26.03.2026) | Nou | Feedback negativ explicit al jucătorului |

**Alte suprafețe de descoperire** (dincolo de Home Recommendations): Continue Playing, Friends List, Sponsored (reclame), Standout Games (curatoriere manuală, fost "Today's Picks"), Search (acum cu suport de "semantic search" — interogări în limbaj natural, nu doar potrivire exactă de cuvinte-cheie), Discover page (charts/trending), notificări de experiență, plus un nou "Avatar Sort" (personalizat, anunțat 09.03.2026) și un meniu flyout pe mobil pentru "resume playing".

**Cold-start** — citatul oficial complet din docs: un joc cu puțini jucători poate totuși "semnala" sistemului că merită distribuit mai departe, DACĂ acei puțini jucători au sesiuni de calitate (qualified, nu bounce). Concluzie practică: nu ai nevoie de mulți jucători la lansare, ai nevoie ca jucătorii pe care îi ai să nu plece în <60s.

### Video-uri de gameplay pe Home — cea mai nouă pârghie (2026)

Din 29.07.2026, jocurile pot afișa video-uri de gameplay direct în Recommended For You, redate automat la hover (desktop) sau la oprirea scroll-ului (mobil). Această funcție era deja disponibilă pe pagina de detalii a jocului, dar extinderea pe Home e recentă.

**Cerințe de conținut** (din postările oficiale):
- Footage real, curent, din joc — nu trailer cinematic, nu gameplay "dramatizat"
- Focalizat pe bucla de bază de gameplay, clar din primele secunde
- Interzis: voiceover, narațiune, text promoțional suprapus, muzică cu versuri

**Limite tehnice:** maxim 3 video-uri per joc; upload din Creator Hub → Place settings → tab Videos; moderare ~24h.

**Rezultate din teste oficiale (mai-iulie 2026):**
- Lift general: până la +39% playtime din RFY
- Standout Games cu video: +47% quality plays, +1,09% playtime
- Superstar Baseball: +30% RFY plays, +31% RFY playtime
- Notoriety: A PAYDAY® Experience: +41% RFY plays, +39% RFY playtime (test 07-26.06.2026)

Pentru Driftwood (joc 2D pur ScreenGui) asta e relevant direct — nu ai nevoie de o cameră 3D "cinematică" ca să faci un video bun; un clip de 15-20s cu râul curgând, o plasă care prinde un obiect, și reparația lui e exact profilul de conținut cerut ("core gameplay loop", nu trailer).

### Genre labels și keywords

Nu am putut confirma lista curentă exactă de genuri din docs (paginile relevante au dat 404 sau nu conțineau lista). Ce e confirmat: Ads Manager permite țintire după "genre" ca parametru de targeting, și search-ul folosește acum "semantic search" (potrivire semantică, nu doar keyword exact) — deci descrierea jocului contează mai mult pentru search decât o listă de cuvinte-cheie separate. **NEVERIFICAT:** lista exactă de genuri disponibile în 2026 și limitele de caractere pentru nume/descriere — de verificat direct în Creator Hub la publicare.

### Specificații icon, thumbnail, video (tabel complet)

| Asset | Dimensiune | Format | Limită mărime | Cantitate | Sursă |
|---|---|---|---|---|---|
| Icon experiență | 512×512px (șablon), pătrat; se micșorează la 150×150px în unele zone UI | NEVERIFICAT | NEVERIFICAT | 1 | create.roblox.com/docs/production/publishing/experience-icons |
| Thumbnail imagine | 16:9, ideal 1920×1080px | .jpg/.gif/.png/.tga/.bmp | sub 3 MB | până la 10 | create.roblox.com/docs/production/publishing/thumbnails |
| Thumbnail video | NEVERIFICAT (lungime, fps) | NEVERIFICAT | NEVERIFICAT | 3 upload-uri/lună (cotă) | create.roblox.com/docs/production/publishing/thumbnails |
| Video pe Home (RFY) | Idem thumbnail video | NEVERIFICAT | NEVERIFICAT | max 3/joc | devforum — postările din 03.2026 și 08.2026 |

Notă importantă: thumbnail video și "video pe Home" NU sunt suportate pe Xbox, PlayStation și VR — pe acele platforme utilizatorii văd doar imaginile statice.

### Ads Manager — mecanism, obiective, țintire

Sursă: https://create.roblox.com/docs/production/promotion/ads-manager.

**Obiective de campanie:**
- **Plays** — maximizează probabilitatea ca utilizatorul să înceapă o sesiune
- **Earnings (Limited)** — țintește utilizatori cu probabilitate mare de a cheltui Robux
- **Engagement** — utilizatori foarte activi, cu age-check (pentru calificare Kids/Select)

**Model de licitație:** automat — stabilești buget + durată, Roblox calculează bidul care aduce cele mai multe play-uri la cel mai mic cost. Nu poți licita manual un CPM/CPP fix (spre deosebire de Meta/Google Ads clasic).

**Buget:** tipuri zilnic sau lifetime; niciun minim USD documentat public; 1 credit publicitar = 263 Robux; prima taxă card = 5$ (folosită spre prima factură).

**Țintire:** audiențe predefinite (All Players, New Players, Recent Players, Lapsed Players) plus filtre avansate: locație, vârstă, gen, gen(re) de joc, tip dispozitiv.

**Metrică cheie:** CPP (Cost Per Play) = cheltuială totală campanie ÷ număr de play-uri. **Nu există un CPP tipic în dolari publicat oficial** — comunitatea de pe devforum confirmă doar mecanismul de licitație (tip auction pe 1000 impresii), fără cifre concrete verificabile în 2025-2026. Recomand testare directă cu buget mic (vezi Recomandări) în loc să te bazezi pe cifre de CPP raportate anecdotic online.

**Statistici de marketing proprii Roblox** (fără eșantion/interval publicat, tratați cu prudență): "150% lift in impressions for games that run ads", "+24% plays", "+16% playtime"; caz citat Hypershot — reclamele sponsorizate reprezintă până la 10% din play-urile jocului.

### Immersive Ads (Billboards, Portals, Rewarded Video) — monetizare, nu achiziție

Sursă: https://create.roblox.com/docs/production/monetization/immersive-ads. Acestea sunt reclame ale ALTOR jocuri/branduri afișate ÎN interiorul jocului tău (monetizare pentru tine ca dezvoltator), nu un canal prin care tu cumperi trafic — util de menționat pentru claritate, ca să nu se confunde cu Ads Manager.

**Tipuri:**
- **Billboards video** — până la 30s, click-to-play sau autoplay
- **Billboards imagine** — statice, neclicabile
- **Portals** — imagine statică cu ușă care teleportează jucătorul în alt joc

**Specificații tehnice unitate video:** min 8×4,5 studs, max 32×18 studs.

**Reguli de contorizare a impresiei:**
- Imagine: minim 1s vizionare, minim 1,5% din viewport, unghi ≤55°, minim 50% din pixeli vizibili
- Video autoplay: minim 0,5s, aceleași praguri de viewport/unghi/vizibilitate
- Video click-to-play: minim 15s vizionate

**Implementare în Studio:** adaugi un `Block` Part, atașezi un obiect `AdGui`, selectezi fața de afișare, publici. Portalurile folosesc pachete `BasePortal` predefinite din Creator Store.

**Eligibilitate:** cont 13+, ID-verificat, 2FA activ; joc public, minimum 2.000 vizitatori unici lunari; chestionar de maturitate/conformitate aprobat.

**Model de venit:** Robux per vizionare de 15s (click-to-play), per impresie (autoplay/imagine), per teleportare reușită (portal). Plată pe 25 ale lunii următoare inserării unității.

**API relevant:** `PolicyService:GetPolicyInfoForPlayerAsync()` pentru a ascunde reclamele utilizatorilor neeligibili (ex. minori sub praguri regionale).

### Ad Integrations (branded content) — un produs diferit, cu prețuri anunțate pentru 2027

Sursă: https://create.roblox.com/docs/production/promotion/ad-integrations. Acesta e un al treilea produs, distinct de Ads Manager și Immersive Ads: reclame plătite de branduri, integrate direct de CREATORI în conținutul jocului lor (billboard-uri branded, rewarded video branded), gestionate tot prin ads.roblox.com. Cere înregistrare campanie, creare asset în Studio, submisie cu minim 5 zile înainte de lansare, moderare ~48h, etichetare obligatorie ("clar și vizibil" — format floating, HUD sau sticker).

**Prețuri anunțate, valabile de la 1 ianuarie 2027** (deci încă neefective la data cercetării, dar publicate oficial): cost per 1000 "qualified visits" (CPTV) în primele 28 de zile — SUA 1,50$, Tier 1 (UK/Canada/Australia/NZ/Nordics) 0,75$, Tier 2 (Europa de Vest/Japonia/Coreea de Sud) 0,20$, Tier 3 (prag global) 0,05$; după 28 de zile, rată fixă 0,10$/1000 vizite până la finalul campaniei (max 12 luni); plafon dur de 400.000$/campanie pentru 2027. Nu e relevant pentru achiziția de utilizatori a Driftwood pe termen scurt (Driftwood nu va vinde publicitate brandată în 2026), dar arată încotro se mișcă monetizarea ecosistemului de reclame Roblox.

### Programe pentru dezvoltatori: Creator Rewards, DevEx, "Game Fund"/"Accelerator"

**Creator Rewards** (înlocuiește Engagement-Based Payouts și Creator Affiliate, ambele discontinuate) — sursă: https://create.roblox.com/docs/creator-rewards:
- **Daily Engagement Rewards** — activ automat pentru toți creatorii din 24.07.2025, fără verificare ID: 5 Robux per "Active Spender" cu sesiune de 10+ minute, DOAR dacă jocul tău e printre primele 3 experiențe lansate de acel jucător în ziua respectivă. Asta confirmă exact ce spune deja CLAUDE.md al proiectului — și înseamnă că Driftwood trebuie să fie genul de joc pe care cineva îl deschide din obișnuință, nu al patrulea joc al zilei.
- **Audience Expansion Rewards** — necesită cont ID-verificat + DevEx valid: 35% revenue share din primii 100$ cheltuiți de un jucător nou în primele lui 60 de zile în jocul tău, DAR jocul trebuie să mențină o medie de 100+ DAU susținută timp de 60 de zile de la alăturare/rejoin. Câștigurile stau blocate 60 de zile înainte de a putea fi retrase.

**DevEx** — sursă: https://create.roblox.com/docs/production/monetization/developer-exchange: rata standard actuală 0,0038$/Robux (confirmă CLAUDE.md), cu o rată superioară 0,0054$/Robux pentru câștiguri specifice de la jucători din SUA, 18+, verificați facial sau prin ID guvernamental. Rata anterioară de 0,0035$ s-a aplicat până pe 5 septembrie 2025, ora 10:00 PT — soldurile vechi se decontează la rata veche mai întâi. Minim 30.000 Robux câștigați, o cerere pe lună calendaristică, procesare ~10 zile lucrătoare (prima dată) sau ~5 zile (ulterior).

**"Game Fund" și "Accelerator"** — (corectat la verificare) numele vechi sunt încheiate ("Introducing the Game Fund", postare din 19.07.2021, fond de 500.000$, ultima activitate pe thread în august 2023; "Important Update on the Accelerator Program", noiembrie 2022, thread închis), DAR au fost înlocuite de două programe active, anunțate oficial pe 09.03.2026 (în timpul GDC Festival of Gaming): **Jumpstart** — program continuu/rolling, pentru studiouri off-platform, creatori noi pe Roblox și echipe mici care explorează jocuri noi; nu necesită experiență anterioară pe Roblox; cel puțin un membru al echipei trebuie să aibă 18+; oferă sprijin in-kind (mentorat pe design/engineering/growth, ajutor de promovare și user acquisition on/off-platform), NU finanțare cash directă. **Incubator** — program de 6 luni, milestone-driven, pentru echipe experimentate cu un prototip solid, orientat spre genuri/mecanici/stiluri vizuale noi; până la 40 de echipe per cohortă (cohorta 2026 a avut 26 de echipe selectate); deadline prioritar de aplicare 06.04.2026 pentru cohorta 2026. Ambele se aplică prin create.roblox.com/build. Sursă: https://create.roblox.com/docs/creator-programs/jumpstart, https://about.roblox.com/newsroom/2026/03/roblox-announces-incubator-jumpstart-creator-programs, verificat 2026-09-09. **Recomandare actualizată: pentru Driftwood (dezvoltator solo, nou pe Roblox), Jumpstart e potrivit ca profil de eligibilitate — de aplicat direct pe create.roblox.com/build, nu doar de așteptat o invitație informală.**

### Marketing extern: Share Links, invite prompts, referral system, social media

**Share Links** (create.roblox.com/docs/production/promotion/share-links) — link-uri trackabile, nelimitate ca număr, create din Creator Dashboard → Creations → Share Links. Poți atașa `LaunchData` opțional (ex. teleportare la o zonă specifică pentru cei veniți dintr-un video TikTok). Acesta e mecanismul corect prin care măsori dacă un video TikTok/YouTube Shorts chiar aduce jucători — fără el, nu poți atribui trafic extern.

**Referral system** (create.roblox.com/docs/production/promotion/referral-system) — `GetJoinData().ReferredByPlayerId` se populează automat pentru toate tipurile de invitații. Cerințe: jocul trebuie să fie live de minimum 1 zi; recompensele (pentru invitator și invitat) sunt alese de dezvoltator, nesetate de Roblox; link-ul nu expiră niciodată; poate fi banner de recompensă un singur tip activ odată.

**Invite Prompts** — API în Luau:

```lua
local SocialService = game:GetService("SocialService")
local Players = game:GetService("Players")

local function promptInvite(player)
    local success, canInvite = pcall(function()
        return SocialService:CanSendGameInviteAsync(player)
    end)
    if success and canInvite then
        local inviteOptions = Instance.new("ExperienceInviteOptions")
        inviteOptions.LaunchData = "zone=riverbank" -- max 200 caractere
        SocialService:PromptGameInvite(player, inviteOptions)
    end
end
```

Notă: șirul de notificare custom trebuie să includă `{experienceName}` (opțional `{displayName}`); `LaunchData` are un plafon strict de 200 de caractere.

**Social media links pe pagina jocului** (create.roblox.com/docs/production/promotion/social-media-links): doar Facebook, Twitter/X, YouTube, Twitch, Discord, Guilded, comunitate Roblox — **TikTok nu e un tip de link disponibil nativ** (trebuie promovat doar extern, fără link direct pe pagina Roblox). Maxim 3 link-uri. Foarte important: UI-ul de configurare a acestor link-uri e ASCUNS complet dacă creatorul nu are vârsta verificată ca 16+ (verificare facială sau ID guvernamental) — un developer solo nou trebuie să treacă prin acest age-check înainte să poată lega orice comunitate Discord de joc. În plus, link-urile pot apărea DOAR pe pagina de detalii a jocului — e explicit interzis să postezi link-uri sociale directe în textul din interiorul jocului.

### Soft-launch — ce e documentat vs. ce nu

Nu am găsit o pagină oficială dedicată strategiei de "soft launch" (căutările pe devforum nu au returnat rezultate). Ce ȘTIM cert din documentație: (1) accesul la o experiență poate fi restricționat la testeri din Creator Hub — mecanismul exact (denumiri curente ale opțiunilor de tip Public/Private/Friends) **NEVERIFICAT în această sesiune, de confirmat direct în Studio → Game Settings → Permissions**; (2) cold-start funcționează cu un grup mic dacă sesiunile sunt calitative (vezi mai sus); (3) Share Links + Ads Manager cu buget mic sunt instrumentele corecte pentru un test controlat, măsurabil, înainte de a scala bugetul.

## Recomandari concrete pentru Driftwood

1. **Nu cumpăra reclame înainte de a avea retenție D1 solidă.** Din moment ce Ads Manager NU alimentează algoritmul organic de Home (traficul din ads e exclus din semnalele de ranking), banii cheltuiți pe reclame înainte ca jocul să rețină jucătorii organic sunt bani pierduți dublu: nu convertesc bine ȘI nu ajută descoperirea organică. Rationament: confirmat direct din create.roblox.com/docs/discovery.
2. **Fă un test "soft" cu grup mic de testeri reali (prieteni, comunitate mică) înainte de publicare completă**, urmărind explicit First Play Bounce Rate (<60s) și Qualified Play Sessions — dacă bounce-ul e mare, NU lansa Ads Manager, repară onboarding-ul întâi. Rationament: cold-start-ul Roblox recompensează calitatea sesiunii, nu volumul.
3. **Filmează 1-3 clipuri scurte (15-20s) de gameplay real** — râul, o plasă care prinde un obiect, reparația — și încarcă-le ca video de Home (Creator Hub → Place settings → Videos), în plus față de thumbnail-uri statice. Rationament: lift documentat de +30-41% în teste oficiale 2026; costul e zero (doar timp de producție), deci ROI e cel mai bun canal disponibil.
4. **Setează icon-ul la exact 512×512px, pătrat, cu siluetă clară testată la 150×150px** (mărimea la care apare în multe zone de UI) — un 2D pur cu culori saturate (râul, plasa) se pretează bine la genul de contrast recomandat de Roblox pentru icon-uri. Rationament: cerințe explicite din create.roblox.com/docs/production/publishing/experience-icons.
5. **Configurează un Share Link dedicat pentru fiecare canal extern** (unul pentru TikTok, unul pentru YouTube Shorts, unul pentru Discord) înainte de a posta orice conținut extern — altfel nu poți măsura ce canal chiar aduce jucători. Rationament: mecanismul oficial de tracking off-platform, gratuit, nelimitat ca număr de link-uri.
6. **Nu bugeta pe baza unui CPP anecdotic găsit online** — testează direct cu 50-100$ (sau echivalent ad credits) pe obiectivul "Plays", măsoară CPP-ul tău real (cheltuială ÷ play-uri), și abia apoi decide dacă scalezi. Rationament: Roblox nu publică CPP tipic, iar comunitatea nu a confirmat cifre fiabile — orice număr auzit "pe undeva" e NEVERIFICAT.
7. **Treci prin age-verification (16+) devreme** pe contul de dezvoltator, ca să poți lega Discord-ul comunității pe pagina jocului din prima zi — fără asta, UI-ul de social links e complet ascuns. Rationament: cerință hard documentată, altfel pierzi luni bune de construire de comunitate pe Discord fără link vizibil.
8. **(corectat la verificare) Nu conta pe "Game Fund" sau "Accelerator" (nume vechi, închise) ca sursă de finanțare cash — dar aplică la "Jumpstart"** (create.roblox.com/build), programul activ din 09.03.2026 potrivit exact pentru un dezvoltator solo nou pe Roblox; oferă mentorat și promovare, nu bani direcți, deci NU îl pune ca linie de venit în planul financiar, dar poate accelera descoperirea și reduce nevoia de buget de ads.
9. **Construiește bucla de retenție din CLAUDE.md ÎNAINTE de orice cheltuială de marketing** — Creator Rewards (Daily Engagement) plătește 5 Robux doar pentru sesiuni de 10+ minute și doar dacă jocul e în top 3 al zilei pentru jucătorul respectiv; fără o buclă care ține jucătorul 10+ minute, nici acest program de monetizare "gratuit" nu produce venit.
10. **Pentru buget de lansare, folosește un plan în trepte, legat de metrici, nu de calendar:** (a) 0$ — soft-launch la grup mic, măsoară bounce rate; (b) doar dacă bounce <40% la <60s — 50-150$ test Ads Manager pe "Plays", măsoară CPP real; (c) doar dacă retenția D1 e vizibil peste medie anecdotică pentru genul idle/collection (vezi fișierul de benchmarks de retenție al proiectului) — scalează bugetul lunar în trepte de 2x, nu dintr-o dată.

## Riscuri și necunoscute

- **CPP/CPM real în dolari pentru Ads Manager rămâne NEVERIFICAT.** Fără el, orice buget de marketing din masterplan e o estimare, nu o cifră testată — trebuie validat empiric în Studio/Ads Manager, nu luat din surse secundare nesigure.
- **Statisticile de marketing publicate de Roblox** ("+150% impressions", "+24% plays") nu au eșantion, interval de timp sau metodologie — pot fi cazuri favorabile selectate, nu medii reprezentative. Nu le folosi ca bază de calcul financiar.
- **(corectat la verificare) "Game Fund"/"Accelerator" au fost înlocuite de Jumpstart/Incubator** (active din 09.03.2026) — riscul rămas e altul: acestea oferă mentorat/promovare, NU finanțare cash, deci nu trebuie tratate ca sursă de venit garantată în planul financiar, dar merită aplicare pentru Driftwood ca profil eligibil (solo, nou pe Roblox).
- **Specificațiile tehnice pentru video (thumbnail și Home)** — lungime, format, mărime fișier — nu sunt publicate. Riscul practic: un upload poate fi respins la moderare din motive tehnice nedocumentate; testează din timp, nu chiar înainte de lansare.
- **Genre labels curente** (lista exactă disponibilă la publicare) nu au fost confirmate — verifică direct în Creator Hub la configurarea experienței, nu presupune o listă din memorie/surse vechi.
- **Discovery e "black box" prin design** — Roblox publică principii (semnale, praguri conceptuale), nu formula exactă de ranking; orice optimizare rămâne empirică, testată live, nu calculabilă dinainte.
- **Grow a Garden și Fisch sunt outlier-i, nu bază de estimare** — creșterea lor (33 zile la 1 miliard de vizite, 22M+ CCU) nu e un scenariu de planificare realist pentru un dezvoltator solo nou; folosește-le doar ca dovadă de mecanism (offline growth funcționează la scară), nu ca target de creștere.

## Întrebări deschise

1. Care sunt opțiunile EXACTE și denumirile curente pentru controlul accesului la o experiență în Studio (Public/Private/Friends/testeri invitați) — de verificat direct în Creator Hub → Game Settings → Permissions, sesiune nouă în Studio.
2. Care e lista curentă completă de genuri disponibile la publicare, și există vreun impact documentat al alegerii genului asupra Charts/Discover page — de verificat la fluxul real de publicare a unui loc nou.
3. Există vreun prag minim de buget/durată recomandat de Roblox pentru ca "Learning Mode" din Ads Manager să iasă din faza de învățare eficient? (Comunitatea sugerează anecdotic "10 credite/zi timp de două săptămâni" — 2.630 Robux/zi — dar fără confirmare oficială; de testat direct.)
4. Ce rate reale practică influencerii Roblox mai mici (sub 100k abonați, nișă farming/collection/idle) pentru un video sponsorizat sau o mențiune — nu s-a putut verifica în această sesiune (motoare de căutare blocate); necesită contact direct sau o platformă de influencer marketing dedicată.
5. Regulile specifice Roblox pentru comunități Discord oficiale (moderare minori, ce se poate posta) — nu am găsit o pagină dedicată; de verificat în Community Standards general + politica de Trust & Safety pentru servere Discord asociate unui joc.
6. Are Driftwood nevoie de 2.000+ vizitatori unici lunari (pragul Immersive Ads) înainte să poată chiar activa monetizare prin reclame in-game — dacă da, la ce etapă din roadmap-ul din CLAUDE.md (pas 6, monetizare) devine relevant acest prag?

## Surse

- Roblox Creator Docs — Discovery: https://create.roblox.com/docs/discovery (accesat 2026-09-08, fără dată vizibilă de ultimă actualizare)
- Roblox Creator Docs — Ads Manager: https://create.roblox.com/docs/production/promotion/ads-manager (accesat 2026-09-08)
- Roblox Creator Docs — Advertise (overview): https://create.roblox.com/docs/production/promotion/advertise (accesat 2026-09-08)
- Roblox Creator Docs — Immersive Ads: https://create.roblox.com/docs/production/monetization/immersive-ads (accesat 2026-09-08)
- Roblox Creator Docs — Ad Integrations: https://create.roblox.com/docs/production/promotion/ad-integrations (accesat 2026-09-08)
- Roblox Creator Docs — Experience Icons: https://create.roblox.com/docs/production/publishing/experience-icons (accesat 2026-09-08)
- Roblox Creator Docs — Thumbnails: https://create.roblox.com/docs/production/publishing/thumbnails (accesat 2026-09-08)
- Roblox Creator Docs — Share Links: https://create.roblox.com/docs/production/promotion/share-links (accesat 2026-09-08)
- Roblox Creator Docs — Referral System: https://create.roblox.com/docs/production/promotion/referral-system (accesat 2026-09-08)
- Roblox Creator Docs — Invite Prompts: https://create.roblox.com/docs/production/promotion/invite-prompts (accesat 2026-09-08)
- Roblox Creator Docs — Social Media Links: https://create.roblox.com/docs/production/promotion/social-media-links (accesat 2026-09-08)
- Roblox Creator Docs — Creator Rewards: https://create.roblox.com/docs/creator-rewards (accesat 2026-09-08)
- Roblox Creator Docs — Developer Exchange (DevEx): https://create.roblox.com/docs/production/monetization/developer-exchange (accesat 2026-09-08)
- Roblox Creator Docs — Recommendation (RecommendationService, in-experience — NU e algoritmul de Home): https://create.roblox.com/docs/production/recommendation (accesat 2026-09-08)
- Roblox Creator Docs — llms.txt (index): https://create.roblox.com/docs/llms.txt (accesat 2026-09-08)
- DevForum — "How we are improving Home this year" (starrrydays, staff): https://devforum.roblox.com/t/how-we-are-improving-home-this-year (publicat 09.03.2026, actualizat 29.07.2026)
- DevForum — "Gameplay Videos on Home: Help Your Games Get Discovered": https://devforum.roblox.com/t/gameplay-videos-on-home-help-your-games-get-discovered/4842601 (publicat 31.08.2026)
- DevForum — "Leveling Up Ads Manager With New Features" (titlu găsit, conținut inaccesibil — 403): https://devforum.roblox.com/t/leveling-up-ads-manager-with-new-features (24.07.2026)
- DevForum — "Ads Manager Updates - Maximize Earnings, Attribution Updates, New Tile in Beta, Other Updates" (titlu găsit, conținut inaccesibil — 403): https://devforum.roblox.com/t/ads-manager-updates-maximize-earnings-attribution-updates-new-tile-in-beta-other-updates (07.05.2026)
- DevForum — "Learning Mode in Ads Manager" (discuție comunitate, fără răspuns oficial staff): https://devforum.roblox.com/t/learning-mode-in-ads-manager (29.03.2026)
- DevForum — "What is Cost Per Play?" (discuție comunitate, veche): https://devforum.roblox.com/t/what-is-cost-per-play (02.04.2024, clarificare 04.11.2024) — FLAG: sursă pre-2024/2024, posibil depășită
- DevForum — "Introducing the Game Fund" (istoric, topic 1361477): https://devforum.roblox.com/t/introducing-the-game-fund/1361477 (19.07.2021, ultima activitate 13.08.2023) — FLAG: sursă veche, status curent neconfirmat
- DevForum — "Important Update on the Accelerator Program" (istoric): https://devforum.roblox.com/t/important-update-on-the-accelerator-program (07.11.2022) — FLAG: sursă veche
- Roblox Investor Relations — Q2 2026 Earnings Press Release: https://s27.q4cdn.com/984876518/files/doc_financials/2026/q2/Roblox-Q2-2026-Earnings-Press-Release.pdf (perioadă raportată: încheiată 30.06.2026)
- Wikipedia — Grow a Garden (secundar, agregator cu citări din PC Gamer, NYT, Reuters, PocketGamer.biz): https://en.wikipedia.org/wiki/Grow_a_Garden (accesat 2026-09-08) — vezi și `docs/research/[object Object]1-case-fisch-gag.md` pentru detalii complete
- Roblox Corporate — Newsroom (index general, nu conținea direct articolele căutate despre Game Fund/Accelerator): https://about.roblox.com/newsroom (accesat 2026-09-08)
- Roblox Creator Docs — Jumpstart program: https://create.roblox.com/docs/creator-programs/jumpstart (accesat 2026-09-09, adăugat la verificarea independentă)
- Roblox Corporate — Newsroom — "Roblox Announces New Incubator and Jumpstart Programs...": https://about.roblox.com/newsroom/2026/03/roblox-announces-incubator-jumpstart-creator-programs (09.03.2026, accesat 2026-09-09)

**Notă despre limitări ale acestei cercetări:** bugetul de căutare web (WebSearch) al sesiunii a fost epuizat înainte de a începe (motiv necunoscut, posibil folosit de alte sesiuni în paralel), deci această cercetare s-a bazat exclusiv pe WebFetch — fetch direct de pagini cunoscute/ghicite plus căutarea internă (`search.json`) a devforum.roblox.com, care a funcționat bine. Motoarele de căutare generale (Bing, DuckDuckGo, Ecosia) au fost blocate de CAPTCHA sau 403 pe majoritatea încercărilor, motiv pentru care unele subiecte (rate YouTuberi, reguli Discord specifice, Fisch marketing) rămân NEVERIFICAT explicit în loc de a fi completate cu presupuneri.

## Verificare independenta (2026-09-08)

Verificare efectuată de un agent independent, cu WebSearch și WebFetch funcționale, pe 15 dintre afirmațiile cu cel mai mare impact asupra deciziilor de proiect (numere, prețuri, rate, procente, date, nume de API, reguli de politică). Fiecare rând de mai jos a fost verificat direct pe sursa primară citată (nu doar pe baza citării din notă).

| Afirmatie | Verdict | Valoare corecta | Sursa (URL, data) |
|---|---|---|---|
| Algoritmul Home are 2 etape (Retrieval pe engagement/retenție/monetizare; Ranking personalizat) | CONFIRMAT | Confirmat cuvânt cu cuvânt: Retrieval selectează pe "engagement, retention, and monetization"; Ranking "selects the most relevant games...in a personalized way" | create.roblox.com/docs/discovery, verificat 2026-09-09 |
| Doar traficul organic din Home Recommendations alimentează semnalele de ranking; ads/curare/prieteni/search excluse | CONFIRMAT | Citat exact: "Roblox doesn't count the engagement, monetization, or retention of users first acquired from ads, curation, friends, search, social media, or any other source in the ranking stage" | create.roblox.com/docs/discovery, verificat 2026-09-09 |
| Playtime plafonat la 60 min/utilizator/joc/zi | CONFIRMAT | Citat exact: "There is a maximum of 60 minutes per user, per game, per day" | create.roblox.com/docs/discovery, verificat 2026-09-09 |
| Citat cold-start despre "even a small number of people playing..." | CONFIRMAT | Citat aproape identic: "Games that have even a small number of people playing can signal to the system that the game is worth considering for distribution to more users" | create.roblox.com/docs/discovery, verificat 2026-09-09 |
| Video pe Home: până la +39% playtime RFY; Superstar Baseball +30%/+31%; Notoriety +41%/+39%; max 3 video/joc; moderare ~24h | CONFIRMAT | Toate cifrele confirmate exact, inclusiv perioada de test 7-26.06.2026 | devforum.roblox.com/t/how-we-are-improving-home-this-year și /t/gameplay-videos-on-home-help-your-games-get-discovered/4842601, verificat 2026-09-09 |
| "Today's Picks" redenumit "Standout Games" (anunț 09.03.2026) | CONFIRMAT | Confirmat: "Today's Picks will evolve into a new sort dedicated to highlighting novel games", datat 09.03.2026 | devforum.roblox.com/t/how-we-are-improving-home-this-year, verificat 2026-09-09 |
| Ads Manager: licitație automată; 1 credit = 263 Robux; prima taxă card $5 | CONFIRMAT | Citate exacte: "1 ad credit is equivalent to 263 Robux"; "$5 USD will be charged upon campaign submission" | create.roblox.com/docs/production/promotion/ads-manager, verificat 2026-09-09 |
| Immersive Ads: unitate video min 8×4,5 studs, max 32×18 studs; eligibilitate 13+/ID/2FA + 2.000 vizitatori unici lunari; plată pe 25 ale lunii următoare | CONFIRMAT | Citat exact: "at least 8 studs wide and 4.5 studs tall...no more than 32 studs wide and 18 studs tall"; "2,000 unique visitors per month"; plată "on the 25th of the following month" | create.roblox.com/docs/production/monetization/immersive-ads, verificat 2026-09-09 |
| Creator Rewards Daily Engagement: 5 Robux/Active Spender, sesiune 10+ min, top 3 jocuri ale zilei, activ din 24.07.2025 | CONFIRMAT | Citat exact: "5 Robux each day if their experience is one of the first three an Active Spender plays for 10+ minutes"; "starting July 24, 2025" | create.roblox.com/docs/creator-rewards, verificat 2026-09-09 |
| Creator Rewards Audience Expansion: 35% revenue share din primii $100 în 60 zile; necesită 100+ DAU susținut 60 zile; hold 60 zile | CONFIRMAT | Toate cifrele confirmate exact | create.roblox.com/docs/creator-rewards, verificat 2026-09-09 |
| DevEx: $0,0038/Robux standard, $0,0054 rată majorată (SUA 18+ verificat), rată veche $0,0035 până 05.09.2025 10:00 PT, minim 30.000 Robux, 1 cerere/lună | CONFIRMAT | Toate cifrele confirmate exact | create.roblox.com/docs/production/monetization/developer-exchange, verificat 2026-09-09 |
| Link-uri social media pe pagina de joc: fără TikTok, max 3 link-uri, UI ascuns sub 16+ neverificat | CONFIRMAT | Confirmat: 7 platforme suportate (fără TikTok), "up to three links", UI ascuns fără verificare 16+ | create.roblox.com/docs/production/promotion/social-media-links, verificat 2026-09-09 |
| Roblox Q2 2026: 123M DAU, 29 miliarde ore, venit $1,5 miliarde, bookings $1,6 miliarde | CONFIRMAT | Confirmat de acoperirea presei financiare a comunicatului oficial: DAU +10% YoY la 123M, ore +5% la 29 miliarde, venit +36% la $1,5 miliarde, bookings +8% la $1,6 miliarde | Acoperire earnings call Roblox Q2 2026 (Investing.com, GuruFocus, citând comunicatul oficial ir.roblox.com), verificat 2026-09-09 — comunicatul PDF direct de pe s27.q4cdn.com nu a putut fi deschis (404 la link vechi), dar cifrele sunt confirmate consistent de multiple surse financiare secundare care citează direct comunicatul |
| Grow a Garden: lansat 26.03.2025, dev solo 16 ani, construit în 3 zile, peak 22,3M CCU pe 23.08.2025, 35,3 miliarde+ vizite până mai 2026, cel mai rapid la 1 miliard vizite (33 zile) | CONFIRMAT | Toate cifrele confirmate exact | en.wikipedia.org/wiki/Grow_a_Garden, verificat 2026-09-09 |
| Ad Integrations: preț efectiv 01.01.2027, CPTV SUA $1,50/Tier1 $0,75/Tier2 $0,20/Tier3 $0,05, rată fixă $0,10 după 28 zile, plafon $400.000/campanie | CONFIRMAT | Toate cifrele confirmate exact | create.roblox.com/docs/production/promotion/ad-integrations, verificat 2026-09-09 |
| "Nu există în prezent un program public activ numit Game Fund sau Accelerator" (implicație: nicio sursă de finanțare/susținere activă pentru creatori noi) | **CORECTAT** | Roblox a lansat programele active **Jumpstart** (continuu, pentru creatori noi/off-platform, min. 1 membru 18+, sprijin in-kind: mentorat + promovare, NU cash) și **Incubator** (6 luni, milestone-driven, până la 40 echipe/cohortă, pentru echipe cu prototip solid), ambele anunțate oficial pe **09.03.2026**. Numele vechi ("Game Fund" 2021, "Accelerator" 2022) sunt într-adevăr încheiate, dar nota omite că au fost înlocuite — relevant direct pentru Driftwood ca profil de eligibilitate Jumpstart. | create.roblox.com/docs/creator-programs/jumpstart; about.roblox.com/newsroom/2026/03/roblox-announces-incubator-jumpstart-creator-programs, verificat 2026-09-09 |

**Concluzie verificare independentă:** 14 din 15 afirmații verificate s-au confirmat exact pe sursa primară citată (inclusiv citate textuale identice sau aproape identice). O singură afirmație a fost corectată: nota greșește prin omisiune când spune că nu există niciun program activ de tip "Game Fund"/"Accelerator" — există, sub numele "Jumpstart" și "Incubator", active din 09.03.2026, direct relevante pentru recomandarea #8 din secțiunea "Recomandari concrete pentru Driftwood". Nu s-a găsit nicio altă discrepanță materială (cifre, date, procente, denumiri de API) în restul afirmațiilor verificate. Afirmațiile legate de cifre Q2 2026 nu au putut fi confirmate direct pe PDF-ul oficial (link 404 la verificare), dar sunt confirmate consistent de multiple surse financiare secundare independente care citează comunicatul oficial — verdict CONFIRMAT cu încredere ridicată, nu NEVERIFICABIL.
