# Curba de dificultate: ce spun tycoon-urile care funcționează, și ce schimbăm

## Rezumat

Verdictul owner-ului după playtest: „mai greu, dar ușor la-nceput". Azi cele 48 de platforme se
derivă dintr-o singură formulă — preț = venit × așteptare-țintă, crescând lin 12,5%/platformă,
plafonată la 7 minute lacom — cumpărate mereu în aceeași ordine, garantat accesibile prin
construcție. Nu există moment în care jucătorul trebuie să aleagă altceva decât „mai aștept". Mai
jos, tiparul din idle-uri și tycoon-uri care au și rampă ușoară, și dificultate reală — plus unde
codul nostru produce exact simptomul reclamat.

## 1. Forma curbei

Idle-urile mature nu cresc prețul uniform pe tot jocul. AdVenture Capitalist crește un producător
obișnuit (Lemonade Stand) cu factor **1,07** per unitate deținută — cost = bază × rată^deținute —
dar suprapune bonusuri gratuite („Speed Doublers", ×2 venit) la **25 și 50** de unități din același
producător, plus un bonus „Capitalist" când TOATE producătorii ating același prag (ex. 100) [1][4].
Un ghid scris după 7 idle-uri construite în 30 de zile recomandă **~1,15×/nivel** ca bază, prima
achiziție sub 60 s, prima automatizare sub 3 minute — și avertizează că un cost liniar creează
„zone moarte" [5]. Nicio sursă găsită nu crește dificultatea printr-un factor constant pe tot jocul:
toate combină o rată lină cu salturi punctuale [1][3].

## 2. Ziduri

Nu există o cifră publică despre cât poate dura un zid înainte ca jucătorii să abandoneze — același
gol ca la D1/D7 pe Roblox [11]. Ce există: un zid bun nu se sparge prin așteptare, ci printr-o
pârghie diferită — automatizarea trece jucătorul de la click activ la venit pasiv, iar prestige-ul e
„marele zid" următor, nu un al doilea la fel [5]. AdVenture Capitalist numește explicit un „zid": la
2.880 de unități din „Oxygen Bar" de pe Lună, urmat de o „străpungere" [4]. Pecorella recomandă
deliberat *variație* de ritm — inclusiv în cadența reseturilor de prestige — nu o curbă netedă [3].

## 3. Prestige/renaștere

Pecorella compară patru jocuri pe cât trebuie să câștigi ca să-ți dublezi moneda de prestige față de
rularea precedentă: **~4×** la Realm Grinder, **~8×** la Cookie Clicker (rădăcină cubică), **~3-4×**
la AdVenture Capitalist, **128×** la Egg, Inc. (trepte de scară, nu curbă lină) [3]. Regula practică
găsită: a doua rulare trebuie să se simtă vizibil mai rapidă **în primele 30 de secunde**, altfel
sistemul a eșuat; bonusul liniar (nu exponențial) ține fiecare renaștere relevantă mai mult, dar cere
reseturi dese la-nceput [5][3]. Driftycoon a decis deja +50% aditiv/renaștere, prima la sfârșitul
Erei 2 (~1h15 real) — aliniat cu principiul liniar. Ce lipsește: alegerea de a renaște *la un zid* nu
e azi vizibilă ca alternativă la a aștepta.

## 4. Forma sesiunii

Un cadru de fază recurent: **Hook (0-30 min)** — recompense dese, decizie clară; **Habit (1-7
zile)** — reveniri zilnice, progres vizibil; **Hobby (săptămâni-luni)** — sisteme adânci [6].
Idle-urile au retenție de **18%** față de **10,5%** la hyper-casual, cu sesiune medie de **~8
minute** [7]. Pe Roblox: FTUE trebuie să distreze în ≤5 minute, algoritmul plafonează timpul
relevant la 60 min/utilizator/joc/zi, iar Creator Rewards cere 10+ minute [11]. Era 1 la Driftycoon
(real ~14 min) cade în Hook. Primul zid propus (§Ce schimbăm) cade real la ~45-58 min — deja peste
Hook, chiar sub plafonul Roblox de 60 min/zi — loc bun ca o sesiune lungă să se-ncheie cu un motiv
clar de revenit, nu cu oboseală.

## 5. Comunicarea corectă a dificultății

Efectul goal-gradient (Hull 1932/1934; Kivetz, Urminsky & Zheng 2006, cu studiul de fidelizare 34%
vs 19% deja citat în nota 21) arată că motivația crește pe măsură ce ținta pare mai aproape [9].
Practic: bara de progres nu se lasă niciodată „rezolvată" — imediat ce atinge ținta, urmează vizibil
următoarea [10]. Driftycoon are deja inelul de progres pe platforma următoare (§B) — corect, dar
insuficient la un zid: jucătorul are nevoie și de o *proiecție* („la ritmul curent, ajungi în ~X"),
nu doar de procent. La un zid real, proiecția trebuie să arate **doi timpi**: cât mai durează dacă
aștepți, și cât dacă cumperi alternativa care sparge zidul — alegerea trebuie văzută, nu doar
posibilă (D40, D43).

## 6. Anti-tipare

Sistemele de energie/stamina sunt criticate constant ca artificiale — se potrivesc rar cu tema
jocului, iar remediul recomandat e decuplarea recompensei de timpul scurs (cadență de misiuni, ca la
Hearthstone), nu un rezervor care se reface singur [8]. Un cronometru care ține jucătorul departe
fără nicio decizie de făcut e exact ce D43 interzice deja, și contrazice „banii cumpără viteză,
niciodată noroc": un zid *economic* (nu poți încă) e acceptabil, un zid *de ceas* (nu poți orice ai
face) nu e.

## Ce schimbăm la Driftycoon

1. **Primele 5 minute rămân neatinse.** `target_wait(0..5)` (primele 6 platforme, azi sub 3:18
   lacom / 5:56 real) nu se schimbă — validat deja pe [5][11].
2. **Plafonul de 420s e chiar cauza „nu se simte niciodată mai greu".** De la platforma ~26 încolo,
   `target_wait` e constant (~756s real) până la 48 — curba nu urcă, se aplatizează. Nu ridicăm
   plafonul global (ar strica și începutul); adăugăm vârfuri locale la 2-3 platforme, marcate
   explicit, restul rămânând cum e azi.
3. **Zidul 1 — Era 2, la Wide Nets → Second Wheel (platformele 20-22).** Comentariul din simulator
   spune azi: gaterul „a încetinit două platforme la rând" până vine roata, care „adaugă 0,3% — o
   cumpărare care nu se simte" — exact opusul unui zid, proiectat să nu se simtă. Schimbare: se
   întârzie Second Wheel cu 1-2 platforme, ca scăderea de producție să dureze 3-4 platforme, nu 2,
   și să apară explicit „Low power" în HUD, nu doar în log. Se sparge prin cumpărarea roții mai
   devreme, scoasă din ordinea strictă, sau prin redirecționare spre plase (tip C) — decizie reală,
   nu click repetat. Cade la ~45-58 min real, chiar sub plafonul Roblox de 60 min/zi [11][6].
4. **Zidul 2 — Era 3, la Kiln → Third Wheel (platformele 33-34).** Comentariul spune deja „cererea
   tocmai a trecut de 20" — azi dezamorsat intenționat, la limită. Se lasă nerezolvat 2-3 platforme,
   cu aceleași două ieșiri ca la Zidul 1.
5. **Ce arată jucătorul la zid, mereu, niciodată tăcut.** HUD-ul arată explicit *două* ținte
   cumpărabile simultan (roata + platforma din coadă), fiecare cu preț și proiecție proprie. Zidul
   rămâne economic, niciodată de ceas.
6. **Renașterea, a treia ieșire, nu doar posibilitate ascunsă.** La Zidul 1, dacă jucătorul are deja
   Era 2, ecranul arată și „renaște acum (+50%)" lângă cele două cumpărături — trei ieșiri reale
   dintr-un singur zid.
7. **Milestone opțional pe plase.** A patra, a opta și a douăsprezecea plasă (proporțional cu
   25/50/100 din AdVenture Capitalist, scalat la cele 12 plase) dau un mic bonus gratuit de rată —
   reîntărește „prinzi mai mult" fără o platformă nouă [1][4].
8. **Simulatorul capătă un marcaj, nu o rescriere.** Regula celor patru motive rămâne — nicio
   cumpărare nu scade venitul. Se adaugă un flag `wall` pe 2-3 platforme, care permite `target_wait`
   local peste plafonul de 420s și o a doua platformă cumpărabilă în paralel la acel pas; restul
   liniei de preț rămâne cum e azi. (Schimbarea de cod rămâne la echipă — această cercetare n-a
   atins codul sau simulatorul.)

## Surse

Accesate 2026-09-12 dacă nu e altfel notat.

[1] Pecorella, „The Math of Idle Games, Part I", gamedeveloper.com, 2016-10-13 —
https://www.gamedeveloper.com/design/the-math-of-idle-games-part-i — încredere ridicată.
[2] Pecorella, „Part II", 2016-12-14 —
https://www.gamedeveloper.com/game-platforms/the-math-of-idle-games-part-ii — încredere ridicată.
[3] Pecorella, „Part III", 2017-02-01 —
https://www.gamedeveloper.com/design/the-math-of-idle-games-part-iii — încredere ridicată.
[4] „Unlocks (Earth)", AdVenture Capitalist Wiki (Fandom, via oglindă shapes.inc, fetch direct
blocat 402) — https://adventure-capitalist.fandom.com/wiki/Unlocks_(Earth) — încredere medie.
[5] aguier, „I Built 7 Idle Games in 30 Days", DEV Community, 2026-08-02 —
https://dev.to/aguier/i-built-7-idle-games-in-30-days-what-i-learned-about-incremental-design-5d3f
— încredere medie.
[6] „Idle Games Best Practices", GridInc Blog, 2025-01-28 —
https://gridinc.co.za/blog/idle-games-best-practices — încredere medie.
[7] „How to Make an Idle Game", GameAnalytics/Adjust, actualizat 2025-03-17 —
https://www.gameanalytics.com/blog/how-to-make-an-idle-game-adjust — încredere medie (studiu sursă
necitat direct).
[8] Ed Biden, „Eliminating Energy", Mobile Free To Play, 2015-07-02 —
https://mobilefreetoplay.com/eliminating-energy/ — încredere medie.
[9] „Goal pursuit", Wikipedia (Nunes & Drèze 2006; Kivetz, Urminsky & Zheng 2006; Hull 1932/1934),
revizie 2026-07-14 — https://en.wikipedia.org/wiki/Goal_pursuit — încredere medie (aceeași sursă ca
în docs/research/21).
[10] Batterbee, „Designing for motivation with the goal-gradient effect", UX Collective —
https://uxdesign.cc/designing-for-motivation-with-the-goal-gradient-effect-c873cdf58beb — încredere
scăzută (rezumat din căutare, nu fetch complet; nespecific jocurilor; dată nespecificată).
[11] docs/research/18-retention-benchmarks.md (notă internă, verificată independent 2026-09-08) —
FTUE ≤5 min, plafon 60 min/utilizator/joc/zi, Creator Rewards 10+ min — încredere ridicată.
