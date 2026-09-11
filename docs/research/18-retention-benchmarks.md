# Metrici și benchmark-uri de retenție pe Roblox (2025-2026)

## Rezumat executiv

- Roblox definește oficial **D1/D7/D30 retention** ca procent de useri noi dintr-un cohort (grupați după data primei sesiuni) care revin la +1 zi, +7 zile, respectiv +30 zile. Nu există un target numeric public unic — Roblox oferă în schimb benchmark-uri personalizate per joc, disponibile doar în Creator Analytics.
- **Discovery-ul (algoritmul „Recommended for You") folosește explicit semnale de retenție** — „play days per user" (D1, D2-7, D8-28), „playtime per user" (plafonat la 60 min/user/joc/zi), „first play bounce rate" și „qualified play sessions per user" — deci retenția nu e doar o metrică de raportare, ci influențează direct distribuția organică.
- Accesul la dashboard-ul de analytics complet necesită **>10 DAU și >10 ore de joc cumulate, 7 zile consecutive**; benchmark-urile „similar players"/„genre" necesită jocuri de comparație cu **≥100 DAU**, iar pool-ul de „top games" ia **top 1000 jocuri după playtime cumulat pe 30 de zile rulante, excluzând jocurile mai noi de 30 de zile**.
- Roblox recomandă oficial ca **FTUE (first-time user experience) să dureze ≤5 minute** până la primul moment de distracție/recompensă — se aliniază perfect cu pasul 1 din planul Driftwood (râu + un obiect + plasă simplă).
- Pentru D30, Roblox recomandă cadență de conținut de **update-uri mici la 2-4 săptămâni și feature-uri mari la 2-3 luni** — coincide aproape exact cu ciclul de „Sezoane" de 4 săptămâni deja planificat pentru Driftwood.
- **Creator Rewards** (activ din 24 iulie 2025) plătește 5 Robux/zi când un „Active Spender" (cheltuit ≥$9.99 oriunde pe Roblox în ultimele 60 de zile) joacă ≥10 minute într-una din primele 3 experiențe pe care le lansează în ziua respectivă — asta face din **sesiunea de 10+ minute un target de business direct**, nu doar un proxy de engagement.
- Nu există benchmark-uri **publice, oficiale, per gen** (simulator vs. tycoon vs. RPG) — genul contează doar intern, în Creator Analytics, ca fallback la „similar players" atunci când nu sunt suficiente jocuri similare. Orice cifră „tipică pe gen" găsită pe DevForum e anecdotică, nu oficială.
- Roblox segmentează oficial churn-ul prin **„in-experience activity status"**: Early (primele 30 zile) → Active (≥1 sesiune în ultimele 30 zile) → Lapsed (0 sesiuni în 30 zile) → Reactivated (primele 30 zile după revenire) — un model gata-făcut pe care Driftwood îl poate replica intern pentru alerting.
- Datele D7/D30 au **latență inerentă**: cohortul din ziua X are D7 disponibil abia în X+7 și D30 abia în X+30 — trebuie planificat un soft launch de minim ~45 de zile ca să apuci un ciclu complet de D30.

## Fapte verificate

- Enrollment în dashboard-ul de analytics necesită „more than 10 daily active users (DAU) and 10 play hours for 7 consecutive days"; sursă: https://create.roblox.com/docs/en-us/production/analytics/analytics-dashboard (last_updated 2026-09-03); încredere: ridicată.
- D1 retention = „Users who first played the game on [dată] and returned to the game the next day"; D7 = revin după 1 săptămână; D30 = revin după 1 lună; cohortul e ancorat pe data primei sesiuni. Sursă: https://create.roblox.com/docs/en-us/production/analytics/retention (last_updated 2026-09-03); încredere: ridicată.
- D7 și D30 au date lipsă pentru cohorturile recente: „For a user cohort that first played the game on 06/20, their D7 retention data appears on 06/27 ... while their D30 retention data appears on 07/20". Sursă: idem retention.md; încredere: ridicată.
- FTUE trebuie să fie „ideally in 5 minutes or less after entering your game". Sursă: retention.md; încredere: ridicată.
- Cadență de conținut recomandată pentru D30: „smaller updates on the existing mechanics every 2-4 weeks, and bigger updates of new features every 2-3 months". Sursă: retention.md; încredere: ridicată.
- „Average Session Time" = „total time users spend in your game divided by the number of sessions". Sursă: https://create.roblox.com/docs/en-us/production/analytics/engagement (last_updated 2026-09-03); încredere: ridicată.
- Recomandare oficială: „Ensure users have fun within the first five minutes of joining your game". Sursă: engagement.md; încredere: ridicată.
- Există un chart oficial „New User First Session Retention" care arată câți useri noi mai sunt activi la X minute după intrarea în joc, comparat cu perioada anterioară. Sursă: engagement.md; încredere: ridicată.
- Algoritmul „Recommended for You" are 2 etape (Retrieval, Ranking) și folosește explicit „engagement, retention, and monetization" ca semnale de retrieval. Sursă: https://create.roblox.com/docs/en-us/discovery (last_updated 2026-09-03); încredere: ridicată.
- Semnale de ranking, în ordine de prioritate declarată „Most important": Play through rate; First play bounce rate (fereastră <60s și 61-180s, semnal negativ); Play days per user (ferestre D1, D2-7, D8-28); Playtime per user (plafon 60 min/user/joc/zi). Nivel „Important": Intentional co-play days per user; Qualified play sessions per user; Spend days per user; Robux spent per user. Sursă: discovery.md; încredere: ridicată.
- „Qualified play" = „a user's meaningful play session with your game, and it filters out accidental clicks or quick bounces" — fără prag numeric exact publicat. Sursă: discovery.md; încredere: ridicată.
- „Benchmarks and benchmark games do not impact the Recommended for You algorithm in any way." Sursă: discovery.md; încredere: ridicată.
- Ierarhia benchmark-urilor: „games with similar players" (dacă modelul găsește destule jocuri similare) → „Genre" (dacă nu găsește destule jocuri similare, dar jocul are un gen intern setat) → „All experiences" (dacă jocul nu are gen etichetat). Tranziția între seturi e adnotată vizual pe grafic. Sursă: analytics-dashboard.md; încredere: ridicată.
- Pool-ul de benchmark „similar players"/„genre" cere jocuri de comparație cu „at least 100 daily active users". Sursă: analytics-dashboard.md; încredere: ridicată.
- Pool-ul pentru benchmark-urile „overall success" (Top 200/500/1000) = „top 1000 games with the highest total playtime over a rolling 30 days ... excluding games that are less than 30 days old". Sursă: analytics-dashboard.md; încredere: ridicată.
- Benchmark-urile pentru „similar players" arată intervalul percentilei 50-90: exemplu ilustrativ din documentație — „Day 1 Retention benchmark's 50th - 90th percentile is 12.11% - 18.73%" (12.11% = percentila 50, 18.73% = percentila 90 printre jocuri similare). Sursă: analytics-dashboard.md; încredere: medie (exemplu didactic în doc, nu o cifră generală garantată).
- KPI-uri disponibile pentru benchmark „similar players": Retention (toate), Engagement (Average Session Time), Monetization (ARPPU, ARPDAU, CVR), Acquisition (Play Through Rate). Sursă: analytics-dashboard.md; încredere: ridicată.
- Segmentare „In-experience activity status": Early (primele 30 zile de la prima sesiune), Active (≥1 sesiune în ultimele 30 zile, nu Early/Reactivated), Lapsed (0 sesiuni în ultimele 30 zile), Reactivated (primele 30 zile după revenirea din Lapsed), Never played. Recalculat zilnic. Sursă: analytics-dashboard.md; încredere: ridicată.
- Segmentare „Platform activity status" (la nivel de tot Roblox, nu doar jocul tău): New signup (primele 60 zile), Active (≥1 sesiune în ultimele 60 zile), Lapsed (0 sesiuni în 60 zile), Reactivated (primele 60 zile după revenire). Sursă: analytics-dashboard.md; încredere: ridicată.
- Segmentare „User engagement" pe 7 zile: Inactive (0 zile), Low (1 zi), Medium (2-3 zile), High (4-7 zile). Sursă: analytics-dashboard.md; încredere: ridicată.
- „Platform spender status" = „Active" dacă userul a cheltuit „$9.99 or more anywhere on Roblox in the last 60 days"; definiția e „consistent with the Creator Rewards program". Sursă: analytics-dashboard.md; încredere: ridicată.
- „Active payer status" (intern jocului, percentile recalculate zilnic): Top 15% = percentila 85-100 a cheltuitorilor; Intermediate 35% = percentila 50-84; Casual 50% = percentila 0-49; Lapsed = fără cheltuieli în ultimele 30 zile; Never. Sursă: analytics-dashboard.md; încredere: ridicată.
- Creator Rewards — Daily Engagement Reward: plătește 5 Robux/zi când un „Active Spender" joacă ≥10 minute într-una din primele 3 experiențe lansate în acea zi; a înlocuit „Engagement Based Payouts" (EBP); lansat 24 iulie 2025. Sursă: https://create.roblox.com/docs/en-us/creator-rewards (via fetch direct); confirmat și pe DevForum („Introducing Creator Rewards", 24 iunie 2025, cont oficial Roblox); încredere: ridicată.
- Creator Rewards — Audience Expansion Reward: 35% revenue share din primii $100 cheltuiți de useri noi/reactivați care ajung prin share/search/link direct și joacă ≥10 min, în primele 60 de zile de la achiziție, condiționat de o medie de ≥100 DAU pe experiență timp de 60 de zile. Sursă: creator-rewards.md; încredere: ridicată.
- Update oficial DevForum (16 oct. 2025, autor „signal_zzz", staff Roblox): a fost lansată vizualizarea retenției pe sursă de achiziție (Source breakdown) și posibilitatea de a alege manual între benchmark „similar experience" și „genre". Sursă: https://devforum.roblox.com/t/4010157 (titlu: „Analytics: View retention by acquisition source and select your benchmark set"); încredere: ridicată (postare oficială Roblox Staff).
- Update oficial DevForum (31 martie 2025, autor „JavaJiving"): a fost introdus „qualified play-through rate (qPTR)" ca semnal separat de discovery, plus actualizare a celor 6 semnale principale (qPTR, 7-day playtime/user cu plafon 60 min, 7-day play days/user, 7-day spend days/user, 7-day Robux spent/user, 7-day intentional co-play days/user). Update ulterior din 11 decembrie 2025: sesiunile din reserved servers contează acum ca „intentional co-play". Sursă: https://devforum.roblox.com/t/boost-your-discovery-with-the-improved-recommended-for-you-algorithm-and-analytics-for-creators; încredere: ridicată.
- Clarificare oficială DevForum (14 iulie 2025, autor „quazotheduck", staff Roblox), thread „Experience Metric Benchmarks Randomly Changing": „If you can see similar experience benchmarks, this means our model found at least 50 experiences that have an overlap in playtime with yours". Sursă: https://devforum.roblox.com/t/experience-metric-benchmarks-randomly-changing; încredere: ridicată.
- Date anecdotice, comunitate (thread „Good Day 1 Retention", oct. 2025): un dezvoltator raportează D1 fluctuant între 9-15% (curent 14%); un comentator notează că „most d1 benchmarks i've seen have been around 7.7-8.5" și sugerează „10-15 is a great aim". Sursă: https://devforum.roblox.com/t/good-day-1-retention; încredere: scăzută (2 persoane, auto-raportat, fără gen de joc specificat, fără validare Roblox).
- Date anecdotice, comunitate (thread „Help getting D1 and D7 retention up", 15 sept. 2024, joc de tip idle/mining RNG): dezvoltatorul raportează session time „above 90% percentile" și playtime mediu de revenire ~45 min pentru userii care revin, dar D1/D7 tot problematice. Sursă: https://devforum.roblox.com/t/help-getting-d1-and-d7-retention-up/3159449; încredere: scăzută (un singur caz, gen specific idle, posibil neaplicabil la Driftwood).

## Detalii

### 1. Cum definește Roblox retenția în Creator Analytics

Pagina oficială `production/analytics/retention` (parte din Creator Hub → Creations → [joc] → Analytics → Retention) definește retenția pe cohorturi ancorate pe **data primei sesiuni** a unui user nou, nu pe data curentă a graficului. Asta înseamnă că un punct de pe axa X reprezintă un grup de useri noi dintr-o zi anume, iar cele trei linii (D1/D7/D30) arată câți din acel grup au revenit la intervalele respective.

Dashboard-ul oferă două tipuri de cohort table, la baza paginii de retenție:
- **Daily cohorts** — retenție zilnică pe primele 10 zile de la achiziție.
- **Weekly cohorts** — retenție săptămânală (luni-duminică) pe 10 săptămâni.

Pentru fiecare cohort sunt disponibile și metrici „down-funnel": 7D playtime/user cumulat, 7D player conversion rate cumulat, 7D revenue/user cumulat, 30D revenue/user cumulat — utile pentru a vedea dacă userii aduși de un eveniment (ex. „Inundația" din Driftwood) monetizează mai bine decât media.

Ghidul oficial leagă explicit fiecare interval de o cauză de design diferită:
- **D1** → core loop + FTUE + performanță tehnică.
- **D7** → sistem de progresie (obiective clare, varietate de conținut, dificultate echilibrată).
- **D30** → „ending system" (conținut nou la cadență regulată + mecanici sociale: trading, guilds, PvP, leaderboards).

Pentru Driftwood, „ending system"-ul propus în brief (Atelierul orașului = progres comun de server, Indexul de reparații = colecție, Sezoanele) mapează aproape 1:1 pe recomandările oficiale D30.

### 2. Engagement, session time și pragul de eligibilitate

„Average Session Time" e o metrică simplă: timp total petrecut în joc / număr de sesiuni, calculat zilnic. Roblox o leagă explicit de retenție („a key metric that's closely tied to retention") și recomandă trei pârghii: (1) distracție în primele 5 minute, (2) tutorial scurt și contextual + resurse de start, (3) eliminarea barierelor din calea interacțiunii sociale.

**Pragul de eligibilitate pentru dashboard-ul complet**: joc cu **peste 10 DAU și peste 10 ore de joc cumulate, timp de 7 zile consecutive**. Sub acest prag, Driftwood nu va avea deloc acces la D1/D7/D30 oficiale — testele din faza de prototip (probabil sub 10 useri simultan) trebuie măsurate manual (logging propriu, DataStore de test, sau chiar formular Google după sesiune).

### 3. Benchmark-uri: „similar experiences", „genre", „all experiences"

Documentația explică o ierarhie clară de fallback pentru benchmark-uri, aplicată automat de Roblox:

1. **„Games with similar players"** — dacă modelul găsește destule jocuri jucate de aceiași useri (ex. cele din secțiunea „recommended games" de pe Game Details Page a jocului tău).
2. **„Genre"** — dacă nu găsește destule jocuri similare, dar jocul are un gen setat intern (în Creator Dashboard, la publicare).
3. **„All experiences"** — dacă jocul nu are încă gen etichetat.

Jocul poate „migra" de la un set de benchmark la altul pe măsură ce crește audiența — Roblox marchează vizual tranziția pe grafic. Un incident documentat pe DevForum (iulie 2025) arată exact acest comportament: un dezvoltator a văzut categoria de benchmark trecând de la „Obby & Platformer" la „similar players" fără nicio schimbare de la el, ceea ce i-a modificat percentila afișată. Staff-ul Roblox a confirmat că pragul minim pentru a intra în „similar players" e **cel puțin 50 de experiențe cu suprapunere de playtime** cu jocul tău.

Pool-ul de comparație (indiferent de tip) conține doar jocuri cu **≥100 DAU**. Pentru benchmark-urile de „overall success" (Top 200/500/1000), pool-ul e **top 1000 jocuri după playtime cumulat pe o fereastră rulantă de 30 de zile, excluzând jocurile mai noi de 30 de zile**.

KPI-urile pentru care există benchmark „similar players": toate metricile de Retention, Average Session Time (Engagement), ARPPU/ARPDAU/CVR (Monetization), Play Through Rate (Acquisition). Fiecare e afișat ca interval percentila 50-90, cu un exemplu didactic în documentație: D1 retention 50th percentile = 12.11%, 90th percentile = 18.73% (adică jumătate din jocurile similare au D1 ≤12.11%, iar doar 10% au D1 ≥18.73%). **Important**: acesta e un exemplu ilustrativ pentru a explica mecanismul, nu o cifră medie garantată pentru toate jocurile de pe platformă.

Roblox insistă repetat, în trei surse diferite (discovery.md, analytics-dashboard.md, thread-ul staff din iulie 2025), că **benchmark-urile nu influențează algoritmul de discovery** — sunt doar un instrument de auto-evaluare.

### 4. Algoritmul de discovery și rolul retenției

Pagina `discovery.md` e cea mai densă sursă găsită. Recomandarea „Recommended for You" de pe Home funcționează în două etape:

- **Retrieval**: selectează un subset de jocuri per user, bazat pe „engagement, retention, and monetization".
- **Ranking**: ordonează personalizat subsetul, folosind semnale calculate **doar din userii veniți organic prin Recommended for You** (nu contează engagement-ul userilor veniți din reclame, curatoriat, prieteni, search etc., pentru stadiul de ranking).

Semnalele de ranking, cu prioritate declarată explicit:

| Prioritate | Semnal | Definiție / fereastră |
|---|---|---|
| Most important | Play through rate (qPTR) | Rata de joc efectiv după ce userul vede jocul în Recommended for You |
| Most important | First play bounce rate | Rata userilor care pleacă după o sesiune scurtă — semnal **negativ**; ferestre <60s și 61-180s |
| Most important | Play days per user | Nr. mediu de zile unice de joc; ferestre D1, D2-7, D8-28 |
| Most important | Playtime per user | Timp mediu petrecut; plafon **60 min/user/joc/zi** |
| Important | Intentional co-play days per user | Zile unice de joc cu prieteni (join, invite, private/reserved servers) |
| Important | Qualified play sessions per user | Sesiuni „meaningful" per user, filtrează click-uri accidentale/bounce rapid |
| Important | Spend days per user | Zile unice cu cheltuială Robux |
| Important | Robux spent per user | Suma medie cheltuită |

Toate semnalele se calculează **ca medie per user, nu ca total** — Roblox afirmă explicit că asta protejează jocurile mici cu useri foarte angajați față de jocurile mari cu engagement diluat: „These recommendation signals are calculated as averages per user, not total values... Roblox is focused on per user engagement, not total engagement."

Sistemul funcționează în faze de **explore/expand**: un update de conținut poate genera un „spike" de useri noi din recomandări (explore); dacă acel cohort are engagement și monetizare bune, Roblox continuă să recomande jocul la cohorturi similare (expand). Practic, orice update major la Driftwood (ex. lansarea unui Sezon) poate declanșa un nou ciclu explore/expand — merită monitorizat separat.

Update-ul din martie 2025 (confirmat oficial pe DevForum) a introdus explicit termenul **qPTR (qualified play-through rate)** ca metrică separată de discovery, plus cele 6 semnale „7-day": qPTR, 7-day playtime/user (plafon 60 min), 7-day play days/user, 7-day spend days/user, 7-day Robux spent/user, 7-day intentional co-play days/user. Un update ulterior (11 decembrie 2025) a extins „intentional co-play" să includă sesiunile din reserved servers.

### 5. Segmentare de churn — un model gata-făcut

Roblox oferă nativ, ca filtre/breakdown-uri în dashboard, o taxonomie de activitate/churn pe care Driftwood o poate reutiliza intern (ex. pentru alerting sau pentru a decide când să trimită o notificare de win-back):

**„In-experience activity status"** (specific jocului tău, recalculat zilnic):
- **Early** — primele 30 de zile de la prima sesiune a userului.
- **Active** — cel puțin 1 sesiune în ultimele 30 de zile, și nu e Early/Reactivated.
- **Lapsed** — 0 sesiuni în ultimele 30 de zile.
- **Reactivated** — primele 30 de zile după ce un user Lapsed revine.
- **Never played**.

**„Platform activity status"** (la nivel de tot contul Roblox al userului, nu doar jocul tău), fereastră de 60 de zile: New signup / Active / Lapsed / Reactivated — analog, dar cu fereastra dublă (60 zile în loc de 30).

**„User engagement"** (ultimele 7 zile): Inactive (0 zile), Low (1 zi), Medium (2-3 zile), High (4-7 zile).

**„Active payer status"** (intern jocului, percentile recalculate zilnic): Top 15% (percentila 85-100 a cheltuitorilor), Intermediate 35% (50-84), Casual 50% (0-49), Lapsed (fără cheltuieli în 30 zile), Never.

**„Platform spender status"** (fix, nu percentilă): Active = a cheltuit ≥$9.99 oriunde pe Roblox în ultimele 60 de zile. Această definiție e identică cu pragul de „Active Spender" din programul Creator Rewards — deloc întâmplător, e aceeași populație pe care se calculează bonusul de 5 Robux/zi.

### 6. Creator Rewards — de ce „10 minute" nu e doar un target de engagement

Din documentația oficială `creator-rewards.md` și confirmat pe DevForum (postare oficială Roblox, 24 iunie 2025), programul **Creator Rewards** (activ din **24 iulie 2025**, înlocuiește „Engagement Based Payouts") are două componente:

1. **Daily Engagement Reward**: plătește **5 Robux/zi** de fiecare dată când un „Active Spender" (cheltuit ≥$9.99 oriunde pe Roblox în ultimele 60 zile) joacă **≥10 minute** într-una din **primele 3 experiențe** pe care le lansează în acea zi calendaristică.
2. **Audience Expansion Reward**: **35% revenue share** din primii $100 cheltuiți de un user nou/reactivat, adus prin link/share/search, care joacă ≥10 min, în primele 60 de zile de la achiziție — condiționat ca jocul să mențină **medie ≥100 DAU timp de 60 de zile** de la data respectivă.

Asta transformă pragul de **10 minute per sesiune** dintr-un simplu „engagement bun" într-un obiectiv financiar direct pentru orice joc care vrea venituri din Creator Rewards, exact cum remarcă și brief-ul Driftwood („ne trebuie sesiuni de 10+ minute și să fim în primele trei jocuri ale zilei").

### 7. Ce NU e public despre benchmark-uri pe gen

Nu am găsit nicio sursă oficială Roblox care publică extern cifre de D1/D7/D30 pe gen (simulator vs. tycoon vs. RPG). Genul contează **doar ca fallback intern** în ierarhia de benchmark (vezi secțiunea 3) — și doar după ce jocul are suficiente date. Orice cifră „X% D1 e normal pentru simulatoare" circulă exclusiv pe DevForum/Reddit, e auto-raportată de dezvoltatori individuali, fără verificare, și fără un eșantion suficient pentru generalizare. Cele două exemple găsite (7.7-15% D1, un singur caz de joc idle cu ~45 min sesiune medie de revenire) sunt marcate explicit ca **încredere scăzută** în secțiunea de fapte verificate — bune ca ancoră de sanity-check, nu ca target.

Similar, nu am găsit nicio sursă oficială Roblox care publică un target de „DAU/MAU stickiness ratio" (concept comun în industria de mobile gaming, ex. 20% considerat bun la alți jucători din industrie, dar aceea nu e o cifră Roblox). Recomand tratarea acestui concept ca NEVERIFICAT pentru Roblox specific și folosirea în schimb a taxonomiei native Early/Active/Lapsed/Reactivated de mai sus.

## Recomandari concrete pentru Driftwood

1. **Instrumentează logging propriu de la primul playtest**, înainte de a avea 10 DAU (prag sub care Creator Analytics nu pornește deloc). Minim: timestamp join/leave, pași core loop completați (plasă pusă → obiect prins → reparat → donat), self-report „ai reveni mâine?". Motiv: sub pragul de 10 DAU/10h/7zile, singura sursă de adevăr e telemetria ta.
2. **Proiectează prima sesiune să livreze un „joyful moment" în ≤5 minute** — un obiect prins și, ideal, reparat/parțial reparat, în prima sesiune. Motiv: recomandare oficială explicită pentru D1 (retention.md) și pentru engagement (engagement.md); se aliniază cu pasul 1 din plan (râu + un obiect + plasă).
3. **Folosește acumularea offline (plafon 8h, deja în brief) ca semnal explicit pentru „Playtime per user" și „Play days per user"** din algoritmul de discovery — revenirea zilnică pentru a colecta plasa e exact tipul de comportament pe care Roblox îl recompensează organic cu distribuție. Afișează recompensa offline într-un moment vizual clar la login (nu silent), ca să contribuie și la „qualified play session" (evită bounce rapid).
4. **Setează targetul intern de sesiune medie la ≥10 minute**, nu doar ca proxy de engagement, ci pentru a qualifica direct la Creator Rewards Daily Engagement Reward odată ce jocul are Active Spenders. Motiv: prag hard-coded de Roblox (10 min, primele 3 experiențe/zi).
5. **Replichează taxonomia Roblox de churn intern** (Early <30 zile / Active / Lapsed ≥30 zile fără sesiune / Reactivated) în orice sistem de alerting sau notificare de win-back construit de voi, în loc să inventați praguri proprii. Motiv: datele voastre interne vor fi direct comparabile cu ce arată Creator Analytics odată ce jocul trece de 10 DAU, deci puteți valida un sistem cu celălalt.
6. **Nu vă bazați pe cifrele „tipice pe gen" de pe DevForum ca target de proiect** — folosiți-le doar ca sanity-check de ordin de mărime (ex. „dacă D1 e sub 5%, ceva e clar rupt"). Target-ul real de referință apare abia după ce Driftwood are propriile benchmark-uri „similar players"/„genre" în Creator Analytics (necesită ≥100 DAU în pool-ul de comparație).
7. **Planificați faza de soft launch la minim ~45 de zile**, nu 2-3 săptămâni. Motiv: D30 retention pentru cohortul din prima zi de soft launch nu e disponibil decât la +30 zile; sub acest orizont nu puteți evalua deloc D30, care e exact metrica legată de „Atelierul orașului" și „Index de colecție" (obiectivele pe termen lung din brief).
8. **Aliniați cadența de conținut la recomandarea oficială D30**: update-uri mici (obiecte noi, ajustări de plasă) la 2-4 săptămâni, feature-uri mari (zonă nouă din oraș, Amonte, Inundația) la 2-3 luni. Ciclul de „Sezoane" de 4 săptămâni din brief se potrivește deja cu limita superioară recomandată pentru update-uri mici — puteți folosi exact granița sezonului ca reper de cadență.
9. **Instrumentați „New User First Session Retention"-style tracking chiar și înainte de a avea acces la dashboard-ul oficial** — adică procent de useri noi încă activi la minutul 1, 3, 5, 10 din prima sesiune. E graficul exact pe care Roblox îl oferă oficial (engagement.md) și îl puteți replica manual cu evenimente custom.
10. **Activați dashboard-ul de analytics imediat ce atingeți pragul de 10 DAU / 10h în 7 zile** (chiar dacă e încă în faza de playtest restrâns) — enrollment-ul necesită email verificat și 2-step verification pe cont, deci configurați asta din timp ca să nu pierdeți zile de date valide de cohort.
11. **Odată ce aveți breakdown pe „Source" (funcție lansată oct. 2025), separați retenția organică (Home Recommendation) de cea din alte surse** — semnalele de discovery se calculează DOAR din traficul organic RFY, deci D1/D7 „per Source=Home Recommendation" e cifra care contează efectiv pentru a crește distribuția, nu media generală.

## Riscuri si necunoscute

- **Nu există un target D1/D7/D30 numeric oficial și universal.** Orice cifră-țintă din acest document (secțiunea de recomandări, dacă adăugați una proprie) e o estimare sintetizată din exemplul ilustrativ Roblox (12.11%-18.73% D1) + anecdote DevForum, NU o normă publicată.
- **Genul exact în care va fi clasificat Driftwood pe Roblox** (Simulator? Building? altceva?) nu e stabilit — afectează benchmark-ul „Genre" până jocul atinge pragul de „similar players" (≥50 experiențe cu overlap de playtime). Trebuie verificat direct în Creator Dashboard la publicare.
- **„Qualified play session" nu are prag numeric public** (secunde/minute) — Roblox îl păstrează intenționat vag, probabil ca să prevină optimizarea artificială a algoritmului. Orice presupunere despre prag e speculativă.
- **Benchmark-ul se poate schimba brusc** (Genre → Similar Players) pe măsură ce DAU crește, generând discontinuități vizuale în grafic care nu reflectă o schimbare reală de performanță (documentat oficial, incident iulie 2025). Nu interpretați o schimbare de benchmark ca pe un semnal de alarmă fără verificare.
- **Datele comunitare despre D1/D7 „tipic" sunt slabe ca eșantion** — un singur thread cu 2 comentarii, fără gen de joc specificat pentru targetul „10-15%". Nu generalizați la Driftwood (colecție + reparat + orășel comun) fără testare proprie.
- **DAU/MAU stickiness** ca și concept nu apare deloc în sursele oficiale Roblox găsite — dacă echipa vrea să-l folosească intern, e un import din industria de mobile gaming, nu un standard Roblox.
- **Nu am reușit să confirm o cifră platform-wide oficială pentru „sesiune medie" pe Roblox** (ex. minute/sesiune la nivel de întreaga platformă) — pagina de investor relations (ir.roblox.com) e randată prin JavaScript și nu a putut fi accesată direct prin fetch în această sesiune de research; rămâne NEVERIFICAT.

## Intrebari deschise

- Ce gen oficial Roblox se potrivește cel mai bine cu Driftwood la publicare (Simulator, Building, RPG, altceva) — de testat/decis în Creator Dashboard înainte de soft launch, pentru că afectează benchmark-ul inițial.
- La ce prag empiric (secunde de sesiune, sau interacțiuni minime) pare să se declanșeze „qualified play" — de investigat indirect în Studio/soft launch prin comparație impresii vs. plays vs. retenția raportată pe Home Recommendations.
- Cât din bugetul de playtesting alocat pasului „nu trece la pasul următor până nu e testat cu oameni reali" (din brief) trebuie dedicat exclusiv atingerii pragului de 10 DAU / 10h / 7 zile consecutive, ca să porniți cronometrul oficial de analytics cât mai devreme?
- Merită implementat, încă din prototip, un sistem de evenimente custom (compatibil cu ce ar accepta ulterior Explore/custom-fields din Creator Analytics) ca să nu pierdeți date istorice comparabile din primele teste?
- Care e targetul intern realist de D1 pentru Driftwood, dat fiind că bucla de bază (verifică plasa, colectează, repară) seamănă mai mult cu un idle/collection loop decât cu un simulator clasic de „grinding" — trebuie recalibrat după primele cohorturi reale, nu decis a priori.
- Cât de agresiv vreți să urmăriți pragul de 100+ DAU necesar pentru Audience Expansion Reward din Creator Rewards, având în vedere că e o sursă de venit separată de DevEx?

## Surse

- [Retention](https://create.roblox.com/docs/en-us/production/analytics/retention) — Roblox Creator Documentation, last_updated 2026-09-03
- [Engagement](https://create.roblox.com/docs/en-us/production/analytics/engagement) — Roblox Creator Documentation, last_updated 2026-09-03
- [Discovery](https://create.roblox.com/docs/en-us/discovery) — Roblox Creator Documentation, last_updated 2026-09-03
- [Analytics dashboard](https://create.roblox.com/docs/en-us/production/analytics/analytics-dashboard) — Roblox Creator Documentation, last_updated 2026-09-03
- [Onboarding](https://create.roblox.com/docs/en-us/production/game-design/onboarding) — Roblox Creator Documentation (data exactă de update nu a putut fi confirmată în această sesiune)
- [Acquisition](https://create.roblox.com/docs/en-us/production/analytics/acquisition) — Roblox Creator Documentation
- [Monetization](https://create.roblox.com/docs/en-us/production/analytics/monetization) — Roblox Creator Documentation
- [Core loops](https://create.roblox.com/docs/en-us/production/game-design/core-loops) — Roblox Creator Documentation
- [Creator Rewards](https://create.roblox.com/docs/en-us/creator-rewards) — Roblox Creator Documentation
- [Analytics: View retention by acquisition source and select your benchmark set](https://devforum.roblox.com/t/4010157) — DevForum, autor oficial Roblox Staff „signal_zzz", 16 octombrie 2025
- [Boost Your Discovery with the Improved Recommended For You Algorithm and Analytics for Creators](https://devforum.roblox.com/t/boost-your-discovery-with-the-improved-recommended-for-you-algorithm-and-analytics-for-creators) — DevForum, autor oficial Roblox „JavaJiving", 31 martie 2025 (update 11 decembrie 2025)
- [Experience Metric Benchmarks Randomly Changing](https://devforum.roblox.com/t/experience-metric-benchmarks-randomly-changing) — DevForum, discuție + răspuns oficial Roblox Staff „quazotheduck", 14 iulie 2025
- [Introducing Creator Rewards: Earn More by Growing the Community](https://devforum.roblox.com/t/introducing-creator-rewards-earn-more-by-growing-the-community/3777628) — DevForum, cont oficial Roblox, 24 iunie 2025
- [Good Day 1 Retention](https://devforum.roblox.com/t/good-day-1-retention) — DevForum, discuție comunitate (secundar, încredere scăzută), 23-26 octombrie 2025
- [Help getting D1 and D7 retention up](https://devforum.roblox.com/t/help-getting-d1-and-d7-retention-up/3159449) — DevForum, discuție comunitate (secundar, încredere scăzută), 15 septembrie 2024
- [Analytics: Recommendations Qualified Play Through Rate and Similar Experiences Benchmarks](https://devforum.roblox.com/t/analytics-recommendations-qualified-play-through-rate-and-similar-experiences-benchmarks) — DevForum, referință găsită prin search, 18 iulie 2024 (conținut complet neconfirmat, doar snippet)

## Verificare independenta (2026-09-08)

Verificare efectuată prin fetch direct pe sursele primare (create.roblox.com/docs și devforum.roblox.com), independent de citările din documentul original. Toate cele 14 afirmații verificate mai jos au fost **confirmate ca fiind corecte** — nu s-a găsit nicio eroare, valoare inventată sau informație depășită. Notă: statutul de „staff Roblox" al utilizatorului DevForum „quazotheduck" (citat pentru pragul de 50 de experiențe) nu a putut fi confirmat vizual la refetch — pagina nu afișează un badge de staff lângă numele lui — dar acest lucru nu afectează validitatea cifrei citate (50 de experiențe), care apare identic în textul postării.

| Afirmație | Verdict | Valoare corectă | Sursă (URL, data) |
|---|---|---|---|
| D1/D7/D30 retention = % useri noi dintr-un cohort (ancorat pe data primei sesiuni) care revin la +1 zi / +7 zile / +30 zile | CONFIRMAT | Cohortul e definit exact așa: „Users who first played the game on [dată] and returned to the game the next day / after 1 week / after 1 month" | https://create.roblox.com/docs/production/analytics/retention (accesat 2026-09-08) |
| Enrollment în dashboard-ul de analytics complet necesită >10 DAU și >10 ore de joc cumulate, 7 zile consecutive | CONFIRMAT | „Any game with more than 10 daily active users (DAU) and 10 play hours for 7 consecutive days is eligible for accessing all KPIs on the dashboard." | https://create.roblox.com/docs/production/analytics/analytics-dashboard (accesat 2026-09-08) |
| FTUE trebuie să dureze ≤5 minute până la primul moment de distracție | CONFIRMAT | „ideally in 5 minutes or less after entering your game" (retention.md); „Ensure users have fun within the first five minutes of joining your game" (engagement.md) | https://create.roblox.com/docs/production/analytics/retention și https://create.roblox.com/docs/production/analytics/engagement (accesat 2026-09-08) |
| Cadență D30 recomandată: update-uri mici la 2-4 săptămâni, feature-uri mari la 2-3 luni | CONFIRMAT | „smaller updates on the existing mechanics every 2-4 weeks, and bigger updates of new features every 2-3 months" | https://create.roblox.com/docs/production/analytics/retention (accesat 2026-09-08) |
| Pool-ul de benchmark „similar players"/„genre" cere jocuri de comparație cu ≥100 DAU | CONFIRMAT | Documentația confirmă comparația cu „games with at least 100 daily active users" | https://create.roblox.com/docs/production/analytics/analytics-dashboard (accesat 2026-09-08) |
| Pool-ul „overall success" (Top 200/500/1000) = top 1000 jocuri după playtime cumulat pe 30 zile rulante, excluzând jocuri <30 zile vechime | CONFIRMAT | „the top 1000 games with the highest total playtime over a rolling 30 days ... excluding games that are less than 30 days old" | https://create.roblox.com/docs/production/analytics/analytics-dashboard (accesat 2026-09-08) |
| Exemplu ilustrativ D1 retention benchmark: percentila 50 = 12.11%, percentila 90 = 18.73% | CONFIRMAT | Citat identic găsit în documentație, prezentat explicit ca exemplu didactic | https://create.roblox.com/docs/production/analytics/analytics-dashboard (accesat 2026-09-08) |
| Discovery: „playtime per user" plafonat la 60 min/user/joc/zi | CONFIRMAT | „There is a maximum of 60 minutes per user, per game, per day." | https://create.roblox.com/docs/discovery (accesat 2026-09-08) |
| Prag „similar players": modelul trebuie să găsească ≥50 de experiențe cu overlap de playtime | CONFIRMAT | „our model found at least 50 experiences that have an overlap in playtime with yours" (quazotheduck, 14 iulie 2025) — statutul de staff al autorului nu a putut fi reconfirmat vizual, dar cifra e identică în postare | https://devforum.roblox.com/t/experience-metric-benchmarks-randomly-changing (accesat 2026-09-08) |
| Creator Rewards Daily Engagement Reward: 5 Robux/zi, Active Spender joacă ≥10 min în una din primele 3 experiențe/zi, activ din 24 iulie 2025, a înlocuit Engagement Based Payouts | CONFIRMAT | „creators will earn 5 Robux when an Active Spender spends at least 10 minutes inside their experience", limitat la „the first three experiences they launch that day"; „All creators begin earning Daily Engagement Rewards starting July 24, 2025"; a înlocuit „Engagement Based Payouts and Creator Affiliate programs" | https://create.roblox.com/docs/creator-rewards și https://devforum.roblox.com/t/introducing-creator-rewards-earn-more-by-growing-the-community/3777628 (accesat 2026-09-08) |
| Active Spender = a cheltuit ≥$9.99 oriunde pe Roblox în ultimele 60 de zile | CONFIRMAT | „made Qualifying Purchases totaling at least $9.99 USD" în „the past 60 days" | https://create.roblox.com/docs/creator-rewards (accesat 2026-09-08) |
| Audience Expansion Reward: 35% revenue share din primii $100, useri noi/reactivați, ≥10 min, 60 zile, necesită medie ≥100 DAU pe 60 zile | CONFIRMAT | „a 35% revenue share on the first $100 in Robux purchases"; experiența trebuie „maintain an average DAU of 100 during the 60 day holding period" | https://create.roblox.com/docs/creator-rewards și postarea DevForum din 24 iunie 2025 (accesat 2026-09-08) |
| qPTR introdus 31 martie 2025 (JavaJiving); update 11 decembrie 2025: sesiuni din reserved servers contează ca „intentional co-play" | CONFIRMAT | Postare originală 31 martie 2025 de JavaJiving introduce qPTR; update din 11 decembrie 2025 de „starrrydays" (Roblox staff) confirmă: „Play sessions in reserved servers are now counted as intentional co-play." | https://devforum.roblox.com/t/boost-your-discovery-with-the-improved-recommended-for-you-algorithm-and-analytics-for-creators (accesat 2026-09-08) |
| Update DevForum 16 oct. 2025 (signal_zzz, staff Roblox): retenție pe sursă de achiziție + alegere manuală benchmark „similar experience"/„genre" | CONFIRMAT | Autor confirmat „signal_zzz (Roblox Staff)", dată confirmată 16 octombrie 2025, titlu identic | https://devforum.roblox.com/t/4010157 (accesat 2026-09-08) |
| Segmentare „In-experience activity status" / „Platform activity status" / „User engagement" / „Active payer status" (definițiile exacte, ferestrele de 30/60/7 zile, percentilele 15/35/50) | CONFIRMAT | Toate definițiile citate în notă apar identic în documentație | https://create.roblox.com/docs/production/analytics/analytics-dashboard (accesat 2026-09-08) |

