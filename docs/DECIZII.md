# Driftwood — Registrul deciziilor de arhitectură și design

Data: 2026-09-09. Bazat pe cele 37 de note din `docs/research/` (fiecare decizie citează nota-sursă).

Statusuri:
- **DECIS** — ferm; se schimbă doar cu motiv nou.
- **PROVIZORIU** — direcție aleasă, dar confirmarea vine dintr-un test în Studio sau de la Roblox.
- **DE DECIS** — rămâne la owner; e listat ce informație lipsește.

Convenție: în tot proiectul, „server" înseamnă o instanță Roblox efemeră; „oraș" înseamnă entitatea persistentă din DataStore (vezi D10). Nu se mai folosește „server" cu sensul de „oraș".

---

## D63 — Jocul pornește sigur, cuvinte pentru copii, o țintă care nu se termină; propunerea pentru Era 2
**ÎN LUCRU** (noaptea de 2026-09-19) — owner-ul, înainte de culcare: *„poți continua logica jocului și monetizarea, să nu
fie prea enervantă (dar să ne facă bani); fă jocul să te facă să VREI să joci (psihologic, gândește-te de două ori la ce
este mai bine); dacă tu consideri că Era 1 este gata, poți începe să copiezi schemele și pentru Era 2 (se continuă harta
în dreapta). Aspectul general al meniurilor și tot ce vede jucătorul, revizuiește să aibă logică și să fie maxim de
ușor de înțeles pentru copii."*

**Cum s-a lucrat:** patru sinteze făcute de agenți și verificate în cod: notele noastre despre retenție (18, 19, 20,
21, 24, 11, 16) și despre monetizare (26, 27, 28, 41), un inventar al tuturor textelor și panourilor satului, și o
căutare pe web despre interfețe pentru copii (NN/g, documentația Roblox, codul britanic ICO pentru copii, FTC).

**1. Ecranul gol de la Play (f41c4aa).** Owner-ul a dat Play și a văzut doar cerul. Cauza, din jurnalul Studio:
`Controllers is not a valid member of PlayerScripts`, la primul `require` al scriptului de pornire. Roblox copiază
copiii lui StarterPlayerScripts în PlayerScripts pe rând, iar scriptul poate porni înaintea folderelor de lângă el.
- Satul și bâlciul așteaptă acum `Controllers` și `UI` (`WaitForChild`) înainte de primul `require`.
- `check_requires` pică la `script.Parent.X` într-un LocalScript din StarterPlayerScripts.
- `scripts/check_compile` (în poartă și în CI) compilează fiecare fișier: stylua și selene nu prind limitele
  compilatorului, iar un fișier care nu se compilează dă același ecran gol.
- Următorul Play al owner-ului a pornit curat: ambele bootstrap-uri complete, nicio eroare și niciun avertisment.

**2. Sonda din Studio pornește singură un Play (022e6f3).** `plugins/DriftwoodProbe.lua` are trei roluri: `edit`
pornește un test (StudioTestService), `server` îl oprește și transmite comenzi clientului printr-un atribut replicat,
iar `client`, care n-are HTTP, își tipărește răspunsurile în Output; `scripts/probe.py` le citește din jurnalul
Studio (panourile deschise, tot textul vizibil cu mărimea lui, texte care se calcă, erorile). Serverul local ține câte
o coadă de comenzi pe rol. **Fereastra de editare încarcă sonda nouă abia după o repornire a Studio-ului.**

**3. Cuvintele jocului, pentru copii (dfe4bae).** Din inventar; regula „textul nu minte" [D40] rămâne peste tot.
- **Un cuvânt pentru un lucru:** „tier" → „level" peste tot; „Crew full" → „All hired".
- **Verbul de pe buton e cel din quest:** „Cast for 28", „Hire for 5", „Build for 5.5K", „Get", „Ring", nu „Buy" la
  toate (`TycoonConfig.verbOf`; un test leagă verbul de primul cuvânt al quest-ului platformei).
- **Veriga slabă, spusă scurt și la fel în ambele meniuri:** „No gain yet — carrying scrap is slower". Subiectul
  rămâne acțiunea, nu omul: cât n-ai angajat pe nimeni, pasul îl faci tu.
- „IDLE" (scris direct în HUD) → „AWAY", în Strings; numele clădirilor cu majusculă, ca eticheta lor din lume.
- Au ieșit „maxed", „35%", „for a single level", contracțiile și fraza de 15 cuvinte a tavernei.

**4. Linia NEXT nu mai dispare (3b9a1ee).** Când se terminau quest-urile și ghidajul tăcea, linia NEXT dispărea: după
capitolul 3 HUD-ul nu mai spunea „ce urmează", deși P3 cere ca următorul pas să fie mereu vizibil, iar nota 18 leagă
retenția din ziua 7 de „obiective clare". `AmbitionMath` (pur, testat) alege o țintă care există mereu și care e
adevărată: pragul următor (10 / 25 / 50 …) al clădirii sau al plasei care ține venitul în loc, nivelul următor al
meseriei slabe sau al doilea om, iar altfel cel mai apropiat prag. Bara pornește de la ultimul prag; apăsarea deschide
meniul obiectului.

**5. Monetizarea, fără presiune.**
- **Fiecare ofertă are pictograma ei** (d88a5d4; desenate, neurcate): două monede cu „x2", gheata cu aripă, luna peste
  casa luminată, inima cu stea, clepsidra, sacul cu „x2". Până la urcare se văd cele de rezervă. Generatorul scrie și
  iconițele de 512 px pentru Creator Hub (`assets/store/`).
- **Pe „Welcome back" butonul auriu e cel gratuit,** nu „Double it". Documentația Roblox de monetizare interzice
  urgența falsă și cere text neutru pentru minori, iar codul ICO interzice împinsul copiilor spre calea plătită prin
  culoare și frecare. Oferta rămâne la vedere, cu prețul pe ea.
- **Nu am adăugat** oferte la momentul în care copilul nu-și permite ceva: e exact tiparul pe care sursele de mai sus
  îl numesc presiune.
- **Banii care nu vin din cumpărături** (nota 26): Roblox plătește 5 Robux pe zi pentru fiecare jucător plătitor care
  stă cel puțin 10 minute în joc. Un motiv sănătos de a reveni zilnic e, deci, venit.
- **Cheia API** primește 403 „Scope not authorized" pe API-urile de pass-uri și produse (verificat cu o citire).
  Rămâne pasul owner-ului: permisiunile de game pass și developer product pe cheie, sau crearea celor șase de mână.

**6. Găsit, nerezolvat în noaptea asta, ca să nu schimb orbește:**
- **Textul e prea mic pe telefon și pe tabletă.** Interfața se desenează la cel mult 62% din mărimea de proiectare
  (`hudScale`, Bootstrap), deci textul „tiny" de 13 px iese la ~8 px, iar „small" la ~9 px; NN/g recomandă ~12–14 pt
  pentru copii. Se repară cu sonda, măsurând fiecare text pe un ecran de telefon, nu mărind fonturile pe nevăzute.
- Panoul „Upgrades" (tasta U) n-are buton pe ecran, deci pe telefon nu se ajunge la el. E ascuns la cererea
  owner-ului (2026-09-12); meniul obiectului îl acoperă.

**7. Era 2 — propunere, nu cod.** Era 1 e scrisă, dar nejucată cap-coadă, deci n-o consider gata. Totuși Era 2 e ce
lipsește cel mai tare: la ~34 de minute jucătorul trage Landing Bell, cea mai scumpă cumpărare, iar zona care se
deschide scrie „coming soon". Prima sesiune se termină exact în punctul ei cel mai slab.
- **Ce am aflat despre cod:** motorul lanțului e scris de mână pentru exact două linii. O a treia marfă atinge ~17
  fișiere (`ChainMath` și simulatorul, cu testele de aur; `EconomyService`; o pereche nouă de controllere; o migrare
  de profil; artă). E muncă de zile și se face cu testele de aur alături, nu peste noapte.
- **Varianta A — „The Mill, actul întâi", pe motorul de azi (2–3 zile, cu artă).** Tragi clopotul, gardul cade,
  puntea și strada continuă spre est. Construiești **Roata de apă** în râu: gaterul și forja lucrează de două ori
  mai repede. Arunci **a șasea și a șaptea plasă** și a doua plasă de scrap. Ridici **Moara** și angajezi un
  **Morar** (nivel 1–5), care îngrijește roata. Deschizi **Piața**: tot ce vinzi aduce +25%. La capăt, **Mill Bell**.
- **Varianta B — a treia marfă, cu oamenii ei (1–2 săptămâni):** de pildă in → pânză la război, cu patru meserii noi.
  Cere întâi generalizarea motorului la N linii, utilă oricum pentru Erele 3–4.
- **Recomandarea mea: A acum, B după.** A dă primei sesiuni un final care deschide ceva, în câteva zile; B se face pe
  îndelete, cu testele de aur. Schița hărții pentru A e în mesajul de dimineață.
- **Rămâne la owner:** alegerea, și arta nouă pe planșe, ca de obicei.

---

## D62 — De ce nu prinde jocul: auditul, și primele reparații
**SCRIS ÎN ÎNTREGIME, NEJUCAT ÎNCĂ** (2026-09-18 → 2026-09-19) — owner-ul: *„verifică graficile, texturile și tot. și
verifică mai ales logica jocului, am impresia că nu te prinde deloc, adică nu mă atrage deloc"*. Cei cinci pași sunt
comiși, iar arta lor e urcată (2026-09-19). Dacă jocul prinde sau nu se află doar jucându-l: asta e verificarea rămasă.

**Cum s-a verificat:**
- **Jurnalele Studio:** ce a rulat și cât.
- **Simulatorul:** cronologia completă a celor 333 de cumpărături din Era 1.
- **Patru inventare pe cod, verificate apoi de mână:**
  - feedback-ul fiecărei acțiuni;
  - ce se schimbă la vedere în lume la fiecare cumpărare;
  - primele 15 minute, pas cu pas;
  - ce spun notele noastre de cercetare.
- **Grafica:** planșe cu toate sprite-urile la scara din joc și capturile owner-ului din Studio.

**Ce s-a găsit:**
1. **Primele cinci minute erau o sală de așteptare.**
   - După primul tur (22 s, cu plasa grăbită), plasa dă 12 bușteni la 36 s.
   - Cei cinci oameni costau 90 de monede, deci ~4,5 minute, la 41 / 49 / 59 / 67 / 83 s unul de altul.
   - Niciunul nu crește venitul: plasa e veriga slabă, iar simulatorul îi cumpăra cu forța tocmai de aceea.
   - Jucătorul stă ~25 s din fiecare 36.
2. **313 din 333 de cumpărături erau mute și invizibile.**
   - Nivelurile și treptele aveau doar clicul butonului.
   - Serverul anunța refuzul, dar niciodată reușita.
   - Pragul 10/25/50, unde debitul se dublează, trecea ca un nivel oarecare.
   - În lume se schimba doar textul „Lv N"; treapta unui om nu se vedea nicăieri.
3. **Recompensele primelor minute nu cumpără nimic.**
   - Toate sunt perle. Capitolul 1 dădea 14, iar cel mai ieftin lucru costă 20.
   - Recompensa capitolului (`reward` în `QuestConfig`) exista, dar n-o plătea nimeni.
   - Avizierul satului nu e arătat de niciun quest.
4. **După al cincilea om jucătorul nu mai are ce face cu mâinile.**
   - Rămân meniurile și undița.
   - Undița n-are miză: jocul perfect scurtează ciclul cu 0,5 s.
   - Colecția, adică recompensa variabilă, e parcată din D56.
5. **Linia fierului** cerea 27K pentru +7% de venit în 14 minute (minutele 24–38).
6. **Grafica.**
   - **Sprite-urile** (clădiri, oameni, UI, bâlci) sunt coerente și bune.
   - **Părțile slabe:** iarba și apa (plate, uniforme) și lipsa vieții.
     - copacii sunt statici;
     - fumul apare doar la forjă;
     - nu sunt păsări;
     - spuma e doar la maluri.
   - **Cod mort:** `SceneArt.AddSmoke/AddDust/WorkSpark/Flourish` sunt scrise și nechemate nicăieri.
7. **Poarta F1** din plan (playtest cu 5 oameni din afară) n-a fost trecută niciodată, iar peste ea s-au pus D53–D61. E
   exact semnalul de alarmă din nota `anti-patterns`.

**Pasul 1 — fiecare cumpărare se simte** (86e4a62):
- **Rețea:** `StationUpgraded`, `CrewUpgraded` și `QuestClaimed`, trimise de server la reușită. Poartă nivelul, pragul
  trecut (`ChainMath.milestoneCrossed`) și creșterea de venit.
- **În lume:** obiectul sare (`UI/Pop`), „Level N" plutește, o rafală de monede, iar „+N/s" zboară spre venit.
- **La prag:** banner („First Net · Level 10 / Catches twice as much now"), rafală mare, camera și sunet propriu.
- **În meniu:** cifra sare, o bară arată cât mai e până la pragul următor, iar rândul pragului scrie „Level 10
  reached!".
- **Oamenii:** coliba sare, omul spune „Better tools. Thanks!", iar al doilea om are toastul lui.
- **Sunete:** `sfx_levelup` și `sfx_milestone`, sintetizate de noi, urcate și aprobate de moderare (bb301c1). Nivelurile
  cumpărate la rând urcă în înălțime, câte un semiton.
- **Quest-urile:** perlele zboară de la Claim spre contor.
  - Recompensa capitolului se plătește la ultima revendicare (`QuestMath.chapterClosedBy`), cu banner.
  - Capitolul 1 dă acum 20 de perle, exact cât primul decor.
- **Marfa dusă de mână:** lăsatul și luatul se aud.

**Pasul 2 — oamenii vin în rafală** (5a12a14):
- **Capitolul 1:** cele cinci angajări ies de pe scara deblocărilor și costă câteva secunde de venit, ca oamenii
  fierului din D56.
  - **Prețurile:** 5 / 6 / 7 / 8 / 10 (erau 12 / 15 / 18 / 20 / 25).
  - **Efectul:** prima vânzare îi plătește pe primii doi, iar toți cinci sunt angajați în ~2 minute reale.
  - **Restul prețurilor:** neschimbate, fiindcă scara pornește de unde ajunsese (`LADDER_START`).
- **Linia fierului:** shed-ul și cei patru oameni costă 700 / 700 / 800 / 900 / 1100 (erau 2,5K–3,5K).
- **Porți noi în simulator:**
  - cel puțin 20 de cumpărături în primele 5 minute reale (acum 48, erau 6);
  - echipa capitolului 1 angajată în cel mult 2m30s.
- **Era 1:** 33m36s reali (era 41m52s); `--robust` trece.
- **Ordinea aleasă de owner în D52** rămâne: un tur de mână, cei cinci oameni, apoi plasele.

**Ce n-a mers, ca să nu se mai încerce la fel:**
- **Încercarea:** „fiecare angajare crește venitul", făcând jucătorul veriga slabă (plasă de 3 ori mai rapidă, munca ta
  mai mică).
- **În model iese, fizic nu.** Un jucător atent mută 30 de bușteni în ~14 s, peste orice plasă rezonabilă. Cifra de pe
  HUD ar fi mințit, iar restul curbei se strica (platou la 66/s între minutele 15 și 25).
- **Concluzia:** angajările nu cresc venitul, doar te eliberează. Deci trebuie să vină repede, iar timpul eliberat
  trebuie să aibă o folosință (pasul 3).

**Pasul 3 — darurile râului (făcut pe 2026-09-18, în planul aprobat de owner; neverificat încă în Studio).**
- **Ce vede jucătorul:** la fiecare 56 s trece pe râu, dincolo de plase, un **butoi** (72%), o **ladă** (22%) sau un
  **buștean de aur** (6%, cu clinchet și anunț). Alergi pe punte sau pe ponton în dreptul lui; cardul scrie
  `Grab it (E)`. Darul vine spre tine, iar monedele sar spre contor.
- **Cât aduce:** butoiul cât **10 s** din venitul tău de acum (minimum 6 monede, ca în primul minut să însemne un om
  angajat), lada **25 s** (minimum 15), bușteanul de aur **75 s** (minimum 40).
- **Scăpat, pleacă pe râu și atât:** n-ai avut nimic, nu pierzi nimic [P2]. Oamenii tăi nu le prind: e treaba ta, singurul
  lucru de făcut cu mâinile după ce satul merge singur.
- **Programul e determinist** pe sămânța râului și fereastra de timp (`DriftMath`, pur): serverul nu lansează nimic și
  clientul nu cere nimic ca să-l deseneze. La `GrabDrift`, serverul reface același dar și verifică **momentul** (chiar
  trece prin dreptul punții), că e **mai nou decât ultimul scos** (`Stats.lastDrift`, în profil: nici o reintrare, nici
  alt server nu-l mai dau o dată) și rata. **Poziția ta nu se verifică:** în sat serverul nu știe unde stai nici la
  cules, nici la predat. Cine trimite cererea fără să alerge câștigă cel mult cât unul care le prinde pe toate.
- **Pe telefon** râul din larg iese din ecran când stai pe punte: cât ai un dar în rază, camera se mută lin la jumătatea
  drumului și se întoarce după (`CameraController.ReleaseFocus` lasă camera doar dacă încă e a ta).
- **Cât adaugă la venit:** ~31% pentru cine le prinde pe toate, ~15% pentru cine prinde jumătate. E o **estimare**, deci
  **nu intră în prețuri și nici în porțile de ritm**: acelea rămân pe jucătorul care nu prinde niciunul. Simulatorul
  doar afișează cât s-ar scurta Era 1 (33m36s → ~29m cu jumătate prinse), din aceleași cifre ca `DriftMath` (un test
  le ține legate).
- **Amendează D59,** unde râul dădea doar perle: aici bonusul e mărginit de program, deci se poate socoti; perlele rămân
  la undiță și la comori.
- Profil **v15**, aditiv: `Stats.drifts`, `Stats.lastDrift`. Butoiul și lada pe apă (`treasure_barrel_water`,
  `treasure_crate_water`) sunt urcate din 2026-09-19.
- După aceea pot veni evenimentele anunțate („Log drive!").

**Pasul 4 — undița și avizierul, devreme (făcut pe 2026-09-18, în planul aprobat de owner; neverificat încă în Studio).**
- **De ce:** după al cincilea om satul merge singur și aștepți ~50 s banii pentru nivelul plasei, iar ghidajul tăcea
  exact atunci: prima pauză a jocului n-avea nimic în ea. Iar avizierul satului nu era arătat de **niciun** quest:
  perlele se strângeau fără ca jucătorul să afle pe ce se dau.
- **`Catch a fish` s-a mutat din capitolul 2 în capitolul 1,** imediat după `Hire an Innkeeper`, cu săgeata spre capătul
  pontonului. Id-ul e același, deci cine l-a revendicat deja îl are revendicat și aici. Amendează locul din D59.
- **Quest nou, `Build something in your village`** (felul `decor`, citit din stare: câte lucruri din catalog ai construit),
  cu ținta nouă `targetBoard` spre avizierul de pe punte. Răsplată: 2 perle.
- **Perlele ajung:** 12 din quest-urile dinainte + 3 de la quest-ul peștelui + cel puțin 6 pe primul pește (1 + bonusul
  speciei noi) = 21, iar primul lucru de la avizier costă 20. Un test ține socoteala asta [PearlBudget].
- **Ghidajul** dă săgeată celor două quest-uri chiar dacă tace (excepții numite, ca undița din D59). Apoi capitolul
  continuă ca înainte: nivelul 2 al plasei, a doua plasă.
- Capitolul 1 are acum 13 quest-uri și 25 de perle cu tot cu răsplata lui; capitolul 2 are cu 3 mai puțin.

**Pasul 5 — satul crește la vedere (prima parte, făcută pe 2026-09-18; arta urcată pe 2026-09-19; neverificată încă în
Studio).**
- **Ce se vede fără imagini noi, de acum:**
  - **treapta meseriei** (1–5), ca cinci pătrățele deasupra acoperișului casei, cele câștigate aurii. Treapta nu schimbă
    înfățișarea omului, deci până acum o treaptă cumpărată nu se vedea nicăieri în lume. Deasupra acoperișului, nu sub
    nume: acolo stau straturile de flori de la avizier (testul de așezare a prins suprapunerea);
  - **fum la hornuri:** casele mari (doi oameni pe meserie) au horn, deci fumul e și un semn că meseria a crescut;
    taverna fumegă mereu. Hornurile sunt măsurate pe foile de sprite (`PadArt.CHIMNEY`). `SceneArt.AddSmoke` exista,
    nefolosit.
- **Ce se vede cu arta urcată** (o variantă care lipsește cade pe desenul de bază):
  - **plasa pe ranguri,** la pragurile 10 / 25 / 50 (`ChainMath.rankOf`, pur): flotoare roșii pe ramă, apoi mai multe și
    ață mai deasă, apoi flotoare și ramă aurii (`prop_net_water_r1..r3`, cu varianta plină);
  - **insigna `Lv N`** trece din albastru în bronz / argint / aur (`ui_levelbadge_*`), cu textul închis pe argint și aur;
  - **păsări** care trec peste sat la 22–48 s, singure sau în șir, cu umbra lor pe pământ (`AmbientController`,
    `prop_bird`). Doar desen: nu se ating, nu dau nimic.
- **Și în satul vizitat** (poarta satelor) se văd rangurile plaselor, treapta și fumul.
- **Scos din plan:** „spumă la stâlpii plaselor". Stâlpii stau pe scândurile punții, nu în apă; spuma plasei e deja în
  desenul ei.

**Pasul 5 — a doua parte (făcută pe 2026-09-19; arta aprobată de owner și urcată în aceeași zi; neverificată în Studio).**
- **Pământul satului, copt într-o singură imagine** (`scripts/art/village_ground.py` → `prop_village_ground.png`,
  960×640, un pixel = 3 pixeli de lume, cu alfa):
  - **uscatul e opac:** iarbă în pete de lumină, pădurea de pe malul de nord cu trei feluri de copaci, plaje cu nisip
    ud, malul amenajat din dreptul punții (zid de bârne), puntea, curțile (rumeguș la gater, zgură la forjă), drumurile
    cu făgașe, piața de piatră, cărări roase între case;
  - **apa e transparentă,** ca râul animat să curgă pe dedesubt. Peste ea stau doar tente: apă mică lângă maluri și
    canalul adânc la mijloc, în trepte care urmează forma malurilor. Tentele sunt netede: puncte fixe peste un râu care
    se mișcă ar fi arătat ca o sită;
  - **geometria nu e copiată în Python.** O scoate `scripts/art/village_geometry.luau` din modulele jocului
    (`Shoreline`, `TycoonConfig`, `WorldDecor`). Puntea și piața folosesc dalele aprobate deja;
  - **în joc** (`SceneArt.BuildBackground`): când imaginea e urcată, rămân din desenul vechi doar apa, spuma și
    obiectele așezate peste. Până atunci harta se desenează din dale, ca înainte. Satul vizitat din bâlci o primește
    la fel, fiindcă folosește aceeași funcție;
  - **poarta o păzește:** fiecare coacere scrie amprenta geometriei în `village_ground.lock`, iar
    `village_ground.py --check` (în poartă și în CI) pică dacă s-a mutat un drum, o curte sau malul fără recoacere.
    După recoacere, imaginea trebuie urcată din nou.
- **A doua înfățișare a clădirilor lanțului, la pragul 25** (`scripts/art/d62_grand.py`): gaterul, taverna și forja.
  Pragul 25 e al doilea din scara nivelurilor, deci clădirea se schimbă exact când debitul se dublează a doua oară
  (`ChainMath.isGrand`, pur, testat).
  - **Ce se adaugă:** temelie de piatră, felinare, stegulețe; la gater a doua grămadă de bușteni și stiva de scânduri;
    la tavernă lucarna luminată, jardiniera și rama aurie a firmei; la forjă focul aprins, lingoul încins și nicovala.
  - **Fiecare variantă pornește din desenul aprobat,** pe aceeași foaie. Pânza gaterului, hornurile și ușa tavernei
    rămân la locul lor, deci fumul și animațiile din joc cad unde cădeau.
  - **Alegerea desenului e una singură** (`PadArt.station`), folosită de `SawmillController`, `DockController`,
    `PadController` (forja e o platformă) și de satul vizitat din bâlci. Forja „crește" doar când își schimbă
    înfățișarea, nu la fiecare nivel.
  - **Depozitul nu are variantă:** în joc nu are niveluri, deci n-ar avea după ce să se schimbe. Planul îl pomenea
    din greșeală.

---

## D61 (partea a doua) — Croitoreasa, poarta satelor și colțul cu Robux
**DECIS** (2026-09-18) — owner-ul, după auditul D62: *„tot ce știi sigur că funcționează, fără presupus. nu uita de
monetizare și continuare la ce făceam deja"*, cu alegerea **„Întâi D61 partea a doua"**. Planul a fost aprobat înainte
de cod. Comis pe pași: croitoreasa (55d9056), poarta satelor (7abf7a6), colțul cu Robux. **Neverificat încă în
Studio.**

**Ce era de rezolvat:** două margini ale bâlciului scriau încă `Opens soon`, jucătorul avea un singur chip, fix, iar
satul tău nu-l vedea nimeni: bâlciul te lăsa să te etalezi doar cu o ținută și un titlu.

1. **Croitoreasa** (cortul vărgat din sud-est, `Tailor (E)`).
   - Panoul are omul tău desenat mare, întors pe rând: față, profil, spate.
   - **`Look`, gratuit, oricând:** silueta (2), coafura (4), culoarea părului (6), culoarea pielii (6). Sunt straturile
     și paletele pe care le aveau deja oamenii din sat [D44]; nu s-a desenat nimic nou. Înfățișarea e patru indici în
     paletele din `SettlerConfig` (`LookMath`), deci o paletă reglată mai târziu se vede la toată lumea. Implicit =
     chipul de dinainte, ca nimeni să nu se trezească schimbat. `Save look` trimite o singură cerere.
   - **`Outfits`:** atingi un rând ca să probezi ținuta, apoi `Buy` (perle) sau `Wear`. Patru ținute noi, doar aici:
     `Festival Coat` 200, `Minstrel` 250, `Lantern Keeper` 350, `Harvest Crown` 500. Nu intră în vitrina negustorului,
     iar avizierul satului scrie despre ele `Sold by the tailor at the fair`.
   - **Cât foaia unei ținute nu e urcată,** rândul ei scrie `Still being sewn` și serverul refuză cumpărarea
     (`"soon"`): nu se iau perle pe ceva ce nu se vede [D40].
   - Ce alegi văd toți cei din bâlci pe loc (lista `People`, cardul tău) și rămâne la fel în sat și pe barcă.
   - **Bugetul de perle:** catalogul a urcat de la 2.010 la 3.310, deci plafonul testului a urcat la 4.000; ce vinde
     satul rămâne sub 3.000. De la D61 perlele vin și din iaz și din gherete, nu doar din undița de acasă.
   - Profil **v12**, aditiv: `Village.look`.
2. **Poarta satelor** (arcada din sud-vest, `Village Gate (E)`).
   - Panoul arată cine e acum în bâlci: numele, titlul, Era, câte decoruri și câte like-uri are satul, cu butonul
     `Visit`. Sus scrie câte like-uri a strâns satul tău. Același drum pornește de pe cardul unui om (`Visit village`)
     și de la cele trei machete din fața porții, care poartă numele primelor trei sate după decoruri.
   - **Vizita e o fotografie, în bâlci, nu un teleport în satul celuilalt.** Satul adevărat rulează economia pe server;
     un „mod vizită" acolo ar fi însemnat porți în exact codul care ține banii. Gazda e în bâlci, deci profilul ei e
     deja încărcat pe serverul bâlciului: `VillageLook` (modul pur) scoate din el doar ce se VEDE. Nicio monedă, nicio
     grămadă, niciun quest nu trece pe aici.
   - **Ce vezi:** pământul, râul și drumurile satului, pontonul, taverna, depozitul, gaterul, fiecare platformă a Erei 1
     (cumpărată = clădirea ei, cu coliba mică sau mare; necumpărată = ruina), plasele cu insigna nivelului, decorul
     cumpărat, oamenii mergând pe drumurile lor cu roabele. Te plimbi liber; nu poți lua sau strica nimic, fiindcă
     nimic de acolo n-are remote.
   - **`Leave a like (E)`** la cartea de oaspeți (`Guest Book`), lângă locul în care apari: un like pe zi (UTC) pentru
     fiecare sat, doar cât ești în vizită acolo. Gazda află pe loc (`Dan liked your village`), iar numărul apare pe
     cardul ei și în panoul porții.
   - **Întoarcerea** e un buton mereu la vedere, sub banda cu numele satului (`Back to the fair`), și tasta Q. Planul
     zicea „la poartă"; pe telefon nu există Q, iar cine s-a rătăcit prin sat n-are de ce să caute un obiect.
   - Cât ești în vizită, ceilalți te văd stând în fața arcadei (`PresenceService.PlaceAt`), iar poziția ta nu se mai
     trimite: e pe altă hartă.
   - Se pot vizita doar oamenii care sunt acum în bâlci. Satele celor plecați vin mai târziu, dacă vizitele prind.
   - Profil **v13**, aditiv: `Fair.likes`, `Fair.liked`.
3. **Tehnic.**
   - Satul vizitat stă în același strat cu bâlciul, departe în dreapta hărții (`VillageDiorama.ORIGIN`): camera trece pe
     dreptunghiul lui (`CameraController.SetWorld`), omul e mutat acolo (`CharacterController.Teleport`), iar mersul
     ascultă de harta satului (`WorldMap`, ca acasă). Ca acasă, omul tău stă mereu deasupra a tot ce e pe teren.
   - Alegerea desenului unei platforme s-a mutat din `PadController` în `UI/PadArt`, comun cu fotografia: două liste ar
     fi ajuns să spună lucruri diferite. La fel lista oamenilor: `HandService.Snapshot` o ia acum din `VillageLook`.
   - Marginile fără firma lor au câmpul `tag` în `FairLayout.EDGES`: numele rămâne deasupra și după deschidere.
   - Pași noi în pâlnia bâlciului: `FirstLookSaved`, `FirstVillageVisit`, `FirstLikeGiven`.

4. **Colțul cu Robux** (monetizarea). Codul e gata; **nimic nu se vinde încă**, fiindcă pass-urile și produsele nu
   există pe Roblox (ID-urile sunt 0 și fiecare rând scrie `Opens soon`).
   - **Ce se vinde** (`MonetizationConfig`, prețurile de pornire din nota 41):
     - `2x Flow` (pass, ~799): venitul în monede se dublează, pentru totdeauna, peste tot unde apare;
     - `Swift Boots` (pass, ~149): mergi și alergi de 1,5 ori mai repede, în sat și în bâlci. D60 zicea ×2; la ×2
       traversezi bâlciul în 1,6 s și nu mai vezi nimic;
     - `Long Nights` (pass, ~349): cât lipsești, satul lucrează până la 48 de ore, nu 24;
     - `Supporter` (pass, ~199): doar aspect — titlul `Supporter`, numele auriu în bâlci, ținuta `Supporter`;
     - `One Hour of Flow` (produs, ~99, doar în sat): monede cât o oră din venitul de acum; suma scrie pe rând;
     - `Welcome Back x2` (produs, ~79): doar pe fereastra „Welcome back" (`Double it`), o dată pentru fiecare revenire.
   - **Ce nu se vinde, niciodată** (D20, D46, nota 41): noroc, lăzi, perle, conținut doar pentru plătitori, nimic cu
     cronometru de presiune. Un test citește catalogul și pică la cuvinte ca `luck`, `chance`, `crate`, `pearl`.
   - **Prețurile nu stau în cod.** Jocul afișează prețul citit de la Roblox (`GetProductInfo`), deci textul nu poate
     minți [D40], iar owner-ul îl schimbă din Creator Hub fără noi.
   - **Unde:** în sat, intrarea `Shop` (P) din bara din dreapta, care apare **după prima vânzare** (nota 41: un magazin
     arătat înainte de prima monedă strică și jocul, și conversia). În bâlci, aceeași intrare și, din 2026-09-19, taraba cu copertină
     aurie: sub gheretele negustorului, în dreapta cortului croitoresei, cu cardul `Shop (E)` (`ShopController`) și cu
     poteca ei coaptă în fundal.
   - **Pass-urile au o copie în profil** (`Purchases.passes`). La intrare întrebăm Roblox și trecem în copie ce ai
     cumpărat în altă parte. Un răspuns „nu" **nu șterge nimic**: `UserOwnsGamePassAsync` ține răspunsurile în memorie
     și poate spune „nu" despre un pass abia cumpărat, iar prima regulă a jocului e că nimic nu se pierde [P2]. Mai
     bine un pass rambursat rămas activ decât unul plătit dispărut.
   - **`2x Flow` stă în afara formulelor lanțului.** `TycoonMath` și `ChainMath` sunt portări bit-exacte ale
     simulatorului, păzite de teste de aur. Factorul se pune pe `priceMult` după ce starea e făcută, în cele două
     locuri în care se face (`PadService.StateFor` = banii adevărați, `StationService.StateFrom` = toate cifrele
     afișate). Când un pass se schimbă, ambele cache-uri se golesc.
   - **Produsele** trec printr-un singur `ProcessReceipt` pe place, după tiparul ProfileStore: chitanța intră în
     `Purchases.ids` (ultimele 100), se onorează o singură dată, iar `PurchaseGranted` se întoarce abia când
     `LastSavedData` conține chitanța. Serviciul e montat și în bâlci: Roblox retrimite o chitanță neonorată pe
     serverul pe care intri data viitoare, iar acolo se plătește din ultima cifră de venit măsurată în sat.
   - **Fereastra de cumpărare o deschide serverul** (`RobuxBuy` → `PurchaseService.Prompt`), nu clientul: un lucru
     necreat (`soon`), un pass deja luat (`owned`) sau un `Welcome Back x2` fără nimic de dublat (`nothing`) nici nu
     ajung la fereastra Roblox, iar refuzul se spune [D43].
   - `2x Flow` bifează mai devreme quest-ul `Earn 1 coin/s while away`. E în regulă: banii cumpără viteză [D46].
   - Profil **v14**, aditiv: `Purchases = { ids, passes }`, `Meta.lastWelcome`.
   - **De probă, în Studio, fără Robux:** consola de dev are rândul `robux` (comută pass-urile, dă o oră de venit). În
     `Balci.rbxl`: `workspace:SetAttribute("DevPasses", "swift,supporter")` înainte de Play.
   - **Rămâne la owner:** cele șase lucruri se creează pe contul lui. Cheia API de azi are drept doar pe imagini; cu
     permisiunile pentru game passes și developer products le pot crea eu (nume, descriere, preț, iconiță). ID-urile
     intră în `MonetizationConfig.IDS`, pe univers.

**Din plan nu mai rămâne nimic de scris** (a doua parte din D62 pasul 5 s-a făcut pe 2026-09-19); rămân aprobarea și
urcarea artei, ID-urile pentru Robux și verificarea în Studio.

---

## D61 — Iazul de concurs, gheretele de joc, mesele cu muzicanții (partea 1)
**DECIS** (2026-09-17) — owner-ul: *„ok, continuăm dezvoltarea"*. Dintre variante a ales **„Iazul și jocurile"**, iar
planul a fost aprobat înainte de cod. Machetele sunt desenate peste fundalul copt: `d61_iaz.png`, `d61_jocuri.png`,
`d61_mese.png`.
- **Partea a doua din D61:** croitoreasa și poarta satelor — făcute pe 2026-09-18, vezi intrarea de mai sus.
- **Mai târziu:** colțul cu Robux (etapa 3 din planul aprobat pe 2026-09-18).

**Ce era de rezolvat:** în bâlci nu aveai ce face în afară de roată, tabelă și negustor. Trei margini ale hărții scriau
`Opens soon`, iar pescuitul, activitatea de așteptare din sat, nu avea unde să se întreacă cu alții.

1. **Iazul.**
   - **Jetiul** pleacă de pe malul de sud și se poate călca (`FairLayout.JETTY`). Capătul lui e zona de aruncare
     (`CAST_ZONE`), unde apare cardul `Cast (E)`.
   - **Undița e aceeași ca acasă:** `UI/FishingRig`, scos din `PierController` și folosit de amândouă. Aceiași pești,
     aceleași perle, același jurnal și aceleași recorduri; un pește mare intră și pe `BIGGEST FISH`.
   - **Ce aduce râul rămâne la ponton:** `FishService.Cast(player, "pond")` nu agață comori.
   - **Plutitorul** cade mereu în apă, dincolo de marginea jetiului (`FairLayout.bobberFor`).
   - **Ceilalți te văd pescuind:** flagul `fishing` din `Crowd`, pe care serverul îl crede doar pe jetiu. Eticheta ta se
     ascunde cât mulinezi.
   - **Bug găsit la plan:** în bâlci, `FishService` socotea mușcătura pe `os.clock`, iar clientul o aștepta pe
     `GetServerTimeNow`. Acum serviciul primește `Now`.
2. **Concursul** (`PondMath`, `PondService`).
   - **Rundele merg după ceas,** la fel pe toate serverele: 6 minute, 4 de pescuit și 2 de pauză, numerotate în zi.
   - **Câștigă cel mai mare pește** (în cm) scos în rundă; la egalitate, cine l-a scos primul.
   - **Premiile** se dau la final, doar cui e încă în bâlci:
     - cu cel puțin doi pescari: **20 / 12 / 8**, iar oricine altcineva a prins ceva ia **3**;
     - singur la iaz: **3**, cu mesajul `You were the only one fishing`.
   - **Tabla de pe malul de nord:** în rundă, primii 4, rândul tău și timpul; în pauză, podiumul și `Next round in`.
     Banda de sus apare cât ești lângă iaz.
   - **`Pond Champion`** vine după 3 runde câștigate cu cel puțin doi pescari.
   - **Bugetul:** cine câștigă toate rundele ia în plus cel mult 3,3 perle pe minut, sub jumătate din pescuit (8,3).
     Testul `PearlBudget` verifică pragul.
3. **Gheretele** (`BoothMath`, `BoothService`, `BoothController`).
   - **`Ring Toss`:** 5 inele peste trei sticle, fiecare mai repede decât cel dinainte.
   - **`Hook a Duck`:** 3 cârlige, rățuște cu 1/2/3/5; cele mari înoată mai repede.
   - **Scorul îl socotește serverul.** El dă sămânța, iar clientul trimite doar clipele apăsărilor. Serverul le verifică
     (ordinea, pauza minimă, timpul trecut), apoi socotește cu aceleași funcții ca desenul. La scor ajung doar
     aruncările verificate.
   - **Premiu dau doar primele 5 jocuri din ziua UTC,** la un loc pentru ambele gherete, deci cel mult 50 de perle pe zi.
     - la inele: 0/1/2/4/6/10 perle, după câte ai prins;
     - la rățuște: 1/2/4/6/10 perle, pentru scorurile 0–3 / 4–6 / 7–9 / 10–12 / 13–15.
   - **Restul jocurilor sunt de plăcere,** iar panoul o spune (`Prize games today 2/5`).
   - **`Sharpshooter`** vine după 5 jocuri perfecte.
4. **Mesele și muzicanții.**
   - **`Sit (E)`** merge la 6 bănci și la 4 locuri de la mese (`FairLayout.SEATS`).
     - Omul trece pe loc cu fața spre cameră, desenat sub mobilă.
     - Serverul verifică dacă locul e liber și dacă ești aproape. La refuz te ridici, iar un toast spune de ce.
     - Orice pas sau `Stand up (E)` te ridică.
   - **`Wave`** (tasta G și butonul din bara din dreapta): brațele sus 2 s și o mână deasupra capului.
   - **Ceilalți văd tot:** pachetul `Crowd` spune și cine stă jos și cine face cu mâna.
   - **Muzicanții:** scripcarul și toboșarul își schimbă cadrele, iar deasupra lor se ridică note.
   - **Melodia bâlciului** (`make_music.py fair`: sol major, 108 BPM) se aude tare lângă muzicanți și la 35% departe de
     ei. Panoul Sound o reglează ca pe cealaltă.
   - **Nimic de aici nu dă recompense.**
5. **Profilul și rețeaua.**
   - **Profil v11, aditiv:** `Fair.pond = {wins, rounds}` și `Fair.booth = {day, prizeGames, perfect}`.
   - **Remote-uri noi în bâlci:**
     - iazul: `PondCast`, `PondCastResult`, `PondLand`, `PondLandResult`, `PondState`, `PondResult`;
     - gheretele: `BoothStart`, `BoothStarted`, `BoothFinish`, `BoothResult`;
     - mesele: `Sit`, `Stand`, `Wave`, `SeatResult`.
   - **Limitele de rată:** bucket-uri noi `Booth` și `Seat`; iazul folosește `Fishing`.
   - **Pâlnia „Fair":** FirstPondCast, FirstPondRound, FirstBoothGame, FirstSit, FirstWave.
   - **Pachetul `Crowd`** rămâne de 6 octeți de om: flagurile stau pe biții liberi.
   - **Quest-ul** `Catch a fish at the pier` devine `Catch a fish`, pentru că se bifa oricum și la iaz.
   - **Arta:** 11 imagini urcate (tabla iazului, muzicanții pe două cadre, piesele jocurilor, mâna, nota, fundalul
     refăcut), plus melodia.

**Abateri de la plan, ale mele:**
- **Muzicanții** stau la (1030/1090, 612), nu lângă a doua masă. Acolo se călcau între ei și cu firma negustorului, iar
  copacii intrau în masa mutată; a doua masă a rămas unde era.
- **Aruncarea** se face dintr-o zonă (capătul jetiului), nu din trei puncte fixe. Plutitorul se socotește din poziția ta.
- **Cadrele muzicanților** sunt două imagini care se schimbă între ele, nu `ImageRectOffset`: așa le urcă scriptul de
  artă.
- **Așezarea** se vede imediat, înainte de răspunsul serverului.
  - **De ce:** dacă omul aștepta răspunsul, cine apăsa E din mers nu se așeza și nu afla de ce.
  - **Plasa de siguranță:** un pachet de poziție întârziat nu ridică pe nimeni în prima secundă.
- **Numele:** `SeatController` din plan se numește `SocialController`, pentru că are și Wave.

**Se verifică doar publicat** (sau în Studio, cu un server local și 2 clienți):
- o rundă cu doi pescari dă locuri și premii;
- singur la iaz primești 3 perle și mesajul;
- un pește de la iaz apare pe `BIGGEST FISH` într-un minut;
- celălalt jucător vede Sit și Wave.

**În Studio** (`Balci.rbxl`) se văd:
- jetiul și undița;
- tabla și banda;
- gheretele: 5 jocuri cu premiu, apoi fără;
- Sit și Wave;
- muzica, mai tare lângă muzicanți.

În sat, pontonul trebuie să se poarte ca înainte după mutarea undiței în `FishingRig`.

---

## D60 — Bâlciul de seară: locul unde te vezi cu ceilalți și te etalezi
**DECIS** (2026-09-16) — owner-ul, după machete: *„un hub circular în care ai în fiecare margine câte ceva de văzut/făcut,
hartă mult mai mare"*, *„mai bine place separat și ajungi cu barca contrar river flow"*, *„bâlci de seară cu lumini și
scenă"*, *„scena mai mare să încapă cât mai multe stats pentru etalare"*, *„hai să punem roata zilnică aici"*, *„la
titluri poate ca aceste cumpărabile să fie mai scumpe"*, *„ar fi ok dacă am dubla numărul de oameni pe server"*. Macheta
aprobată în trei runde (41 de obiecte, zero suprapuneri), planul aprobat înainte de cod.

**Ce era de rezolvat:** nimeni nu vedea pe nimeni — clientul nu desena niciun alt jucător, deci ținutele și decorul din
D59 n-aveau privitori, iar perlele rămâneau fără cheltuială după 8–10 ore (catalog fix).

1. **Place separat, același univers** (`fair.project.json`, `src/Fair/`, `PlaceConfig`). Staging: satul
   132381101591529, bâlciul 114983498774894; producția n-are încă bâlci (barca spune `The fair isn't open in this game
   yet`). CI construiește, verifică și publică ambele place-uri.
2. **Barca.** În sat, legată în aval de ponton, între plutitor și mal (`TycoonConfig.FERRY`, 62×30 la ×2, prova în
   amonte), cu eticheta `Ferry to the Fair`; de pe marginea pontonului (`FERRY_BOARD`), cardul `Row up to the fair (E)`.
   Drumul pictat (`UI/RideScene`, comun celor două place-uri) durează 6 s (`RideMath`): barca merge **în amonte** (spre
   stânga: râul curge spre dreapta — `RideMath` mergea greșit spre dreapta și a fost reparat), malurile rămân în urmă,
   seara se lasă, felinarele cresc odată cu ea, iar la capăt apar stâlpii, steagurile și becurile bâlciului. `Skip` apare
   de la al doilea drum, după 1,2 s. Cererea pleacă la server abia la capăt, pe negru; același negru se vede în timpul
   teleportului (`SetTeleportGui`) și la sosire (`ReplicatedFirst/Loading`, care acum așteaptă și profilul). Înapoi,
   `Row home (E)` la debarcaderul bâlciului, cu drumul în aval și casele satului la capăt. În Studio teleportul nu există:
   drumul se vede întreg, apoi toastul spune `The ferry only sails in the published game`.
3. **Predarea profilului.** Sesiunea **nu** se închide înainte de teleport: dacă teleportul pică, rămâi unde erai, cu
   profilul în mână, iar toastul spune de ce (`FerryService`: studio / closed / no_profile / busy / failed / timeout, 20 s).
   Place-ul în care ajungi ia sesiunea (ProfileStore cere prin MessagingService celei vechi să se închidă);
   `DataService.MarkTeleporting` oprește Kick-ul „another server took over" pentru cine e în drum și notează, la urcare,
   ora plecării și timpul jucat. **Bâlciul nu simulează satul și nu scrie `lastSeenAt`**: la întoarcere satul plătește,
   exact ca offline, tot timpul cât ai lipsit (plafonul de 24 h rămâne). O vizită în bâlci nu numără o sesiune nouă; se
   numără în `Fair.visits`.
4. **Roata s-a mutat în bâlci — amendează D59 pct. 6.** Stă pe stâlpul ei, cu baldachin și focuri; aceleași premii,
   aceleași șanse afișate, aceeași regulă de 24 h. În sat, unde era timonierul, un indicator (`WheelSignpostController`)
   scrie `Wheel moved to the fair`; când rotirea e gata are inelul auriu, cardul spune `A free spin is waiting at the fair`
   și un toast o spune o dată. **Abatere de la plan, a mea:** `TycoonState` păstrează ceasul roții (fără rotire), ca
   indicatorul să poată spune când te așteaptă — altfel rotirea zilnică ar fi fost invizibilă din sat. Consecința, spusă
   pe față: rotirea zilnică cere drumul cu barca.
5. **Oamenii.** Până la **24** pe server. Fiecare client își trimite poziția de 10 ori pe secundă pe un
   `UnreliableRemoteEvent` (`Where`); serverul o verifică (`FairPresence`: numere adevărate, loc pe care se merge, pas cât
   se poate alerga) și le trimite pe toate într-un singur pachet (`Crowd`, `CrowdCodec`: 6 octeți de om, 144 la 24 —
   un tabel ar fi trecut de limita de ~1.000 de octeți). Cine e fiecare (numele, ținuta, titlul) pleacă separat
   (`People`), doar când se schimbă, și îl pune serverul din profil. Ceilalți se mișcă lin, cu o zecime de secundă în
   urmă, desenați ca tine; deasupra fiecăruia, numele și titlul (și deasupra ta). **Poziția e doar aspect:** nicio cifră
   din economie nu trece prin ea.
6. **Cardul altui jucător.** Lângă cineva, `Look at Mara (E)`: Era, venitul pe secundă (ultimul măsurat în sat, la minut
   și la plecare), cel mai mare pește, câte lucruri a scos din râu, câte decoruri are satul, jurnalul (x/12), plus
   `Add friend`. Doar pentru cineva de pe același server, cu limită.
7. **Titlurile.** Unul purtat, sub nume. Câștigate, gratuite: Era (`Of the Landing / Mill / Yard / Harbor`), `River
   Legend`, recordul tău (`Sturgeon 187 cm`), `Fountain Patron` / `Statue Patron` / `Beekeeper` / `Gardener` din decor,
   `Champion of the Week` (#1 la pește săptămâna trecută; concursul de la iaz îi ia locul în D61). **Cumpărate, scumpe
   intenționat:** `Old Salt` 600, `River Baron` 1.000, `Lord of the River` 1.600 de perle — peste tot catalogul de decor.
   Panoul (tasta T) arată și ce se mai poate câștiga (jurnalul cu progresul lui, decorul lipsă). Un titlu care nu mai e al
   tău cade pe cel al Erei.
8. **Scena, adică tabela.** Trei clasamente **săptămânale** (încep din nou lunea UTC): cel mai mare pește, cel mai mare
   venit pe secundă, cel mai scurt drum până la clopotul Erei 1 (timp de joc efectiv, `Stats.playSeconds`, fără zilele
   offline). **Satul scrie** (`LeaderboardService`: doar la un record nou al tău pe săptămână, venitul cel mult o dată pe
   minut; unealta de dezvoltare nu intră pe tabelă, iar Play-ul din Studio pornit de la zero nu scrie nimic), **bâlciul
   citește** (`BoardService`: la minut, campionul la oră, trofeele la 5 min). Pe panourile pictate, câte 6 rânduri, al tău
   auriu, iar când nu ești printre primii 6 ultimul rând spune unde ești; tabela goală spune `No one yet`. Sub trofee,
   cele mai mari 4 exemplare prinse vreodată; deasupra soclului, campionul. `Leaderboards (E)` deschide panoul mare, cu
   specia peștelui și toate cele 12 trofee.
9. **Negustorul.** Trei tarabe cu **vitrina zilei**: 4 lucruri din tot catalogul de aspect (decor, ținute cu preț, titluri
   de vânzare), aceleași pentru toată lumea, alese din zi (`MarketMath`). Vitrina **nu e o poartă**: cumpărarea trece prin
   aceiași validatori ca în sat, iar tot catalogul rămâne de cumpărat și acolo (D46).
10. **Ce rămâne închis până la D61**, cu plăcuța lor (`Opens soon`, D43): iazul de concurs, gheretele de joc, poarta
    satelor (vizitele), croitoreasa; colțul cu Robux (×2 venit, spațiu, viteza de mers ×2, Supporter) vine tot atunci.
11. **Profil v10, aditiv** (`Titles`, `Fair`, `Records`, `Stats.playSeconds`; șablonul și `ProfileMigrate.toV10` adaugă
    exact aceleași câmpuri, verificat de test). Remote-uri noi în sat: `RowUp`, `FerryFailed`; ies `SpinWheel`,
    `WheelResult` (se mută în bâlci). Remote-urile bâlciului au lista lor (`src/Fair/Net`), inclusiv cele nesigure, iar
    `check_requires` le verifică pe amândouă listele. Bucket-uri noi: `Ferry`, `LookAt`. Pâlnie de analytics „Fair"
    (FirstRide, FirstFairVisit, FirstTitleWorn, FirstBoardSeen, FirstFairPurchase). Module pure noi și testate:
    `FairLayout.isWalkable`, `FairPresence`, `CrowdCodec`, `MarketMath`, `TitleMath` (etichetele erelor), `BoardMath.compact`,
    `TycoonMath.era`; plus testele de așezare: barca din sat, indicatorul roții, etichetele din bâlci.

12. **Aspectul, refăcut după prima vedere în Studio (2026-09-17).** Owner-ul: *„arată super super cheap atm texturile,
    efectele acelea de lumină, obiectele, pământul ăla circular, basically everything"*. Prima versiune desena poiana din
    forme plate. Acum jocul face ce făcea macheta aprobată: **fundalul e o singură imagine coaptă**
    (`scripts/art/d60_ground.py` → `Assets.fair.ground`, 740×720 la ×3, cu pădure pe margini): iarbă de noapte, pământ
    bătătorit cu marginea ruptă și cărări, iazul, râul, umbrele și bălțile de lumină caldă. Peste el, obiectele colorate de
    lumina din jur (`FairScene.LitTint`, aceeași socoteală ca la coacere), pădurea, lumina moale care pâlpâie
    (`Assets.fair.glow`), scânteile, ghirlandele cu becuri și etichete doar din text cu contur. Datele comune (lumini,
    focuri, copaci, ghirlande) le scrie același script în `FairScenery.luau`, verificat de test.
    **A doua privire (aceeași zi), pe captura din Studio:**
    - **Pietrele din jurul vetrei:** cele 26 de pe cerc se vedeau ca puncte gri presărate pe poiană și au fost scoase.
    - **Trofeele:** cele patru etichete de sub ele se călcau. Acum cutia are 84, iar testul măsoară textul, nu doar
      cutia. Când niciun trofeu n-are record, apare o singură frază sub tot rândul.
    - **Tabelele de pe scenă:** hârtia lor strălucea ca un ecran. Acum trece prin lumina scenei și acoperă doar liniile
      pictate. Pătrățelele pictate devin insigna cu locul, între rânduri sunt linii de caiet, iar tabela goală scrie la
      mijloc *No one yet / this week*.
    - **Cifra de venit:** urcă la unitatea următoare înainte să ajungă la „1000.0K".

**Se verifică doar publicat** (teleportul nu există în Studio): drumul sat → bâlci → sat fără Kick și cu venitul cât ai
lipsit, doi jucători care se văd, tabela după un pește mare, vitrina de a doua zi, un teleport eșuat care nu lasă
profilul agățat. În Studio se văd lumea bâlciului, mersul, cardurile, roata, titlurile, negustorul și drumul pictat.

---

## D59 — Pontonul: undița, ce aduce râul, perlele pe sat, roata la locul ei
**DECIS** (2026-09-15) — owner-ul, după recomandarea pentru „ce face jucătorul cât așteaptă": *„A și B cum recomanzi,
apucă-te. și să șlefuim lucky wheel, nu prea se integrează «cu cap» în acest moment."* Recomandarea acceptată: **A
(undița ta) și B (ce aduce râul) împreună, iar perlele cumpără decor pentru sat și ținute**; C (comenzile tavernei)
după primul playtest, D (ajutorul dat oamenilor) la final. Plan aprobat înainte de cod.

**Ce era de rezolvat (verificat în cod și în simulator):** cea mai lungă pauză fără nimic de apăsat e 2m01s pentru
jucătorul lacom (~3,6 min real), iar după Era 1 nu mai e nimic de făcut; perlele veneau din quest-uri (48 în Era 1) și de
la roată, dar niciun cod nu le cheltuia. Roata nu se lega de nimic: o roată de cazino cu felii curcubeu, în colțul de jos
al satului, pe unde nu trece nicio buclă, singurul obiect deschis cu click, nu cu cardul E (D51), cu jumătate din premii în
perle fără rost, iar premiile în monede săreau peste tutorial: o rotire în primul minut dădea 324 de monede (10 min de
venit, 10%) sau 972 (30 min, 3%), când capitolul 1 costă ~120 (cu Third Net și Bigger Sack, ~290).

1. **Pontonul lung.** Pontonul intră ~150 px în râu (`prop_pier_long`, 32×104 la ×3, cu baza unde era `pier3`) și se
   merge pe el până la capăt: `WorldMap.blockedRects` primește o trecere (`TycoonConfig.PIER_WALK`) și sparge banda
   râului în trei, doar pentru jucător (oamenii merg pe `RoadGraph`). La capăt e locul de pescuit (`FISH_STAND`),
   plutitorul cade în aval (`BOBBER_AT`), ce aduce râul așteaptă în amonte (`TREASURE_SLOTS`), iar roata și avizierul
   stau pe punte, la vest de aleea tavernei, unde nu umblă nimeni. Barca vânzării pleacă acum spre dreapta pontonului,
   ca să nu treacă peste ce așteaptă în stânga. Locurile sunt verificate pe harta randată și în `TycoonConfig.test`.
2. **Undița (A).** La capăt, `Cast (E)`; după 3–8 s (clipa o alege serverul) plutitorul se scufundă, cu stropi, „!" și
   un sunet; apoi bara: ții apăsat E (pe telefon, butonul de acțiune) cât peștele e în zona luminoasă și firul se strânge;
   ținut cât e afară, se desface puțin, niciodată sub zero; fără buton, nu se mișcă nimic. **Nu există eșec**: doar ținând
   apăsat tot timpul scoți orice pește, sub 22 s pe 2.500 de semințe (testul cere sub 30 s), iar jocul perfect termină în
   medie în 2,6 / 3,6 / 4,9 / 6,5 / 8,1 s pe cele cinci rarități (`ReelMath`, poziția peștelui e o funcție de timp și
   sămânță, aceeași pe client și pe server). Serverul trage specia și mărimea la aruncare și nu le spune până la scoatere;
   scoaterea se crede doar după timpul jocului perfect pe exact acea bară (toleranță 0,3 s). Pleci de unde ai aruncat și
   aruncarea se anulează în liniște. 12 specii pe 5 rarități (culorile din `RiverConfig.TIERS`, fără mythic); un pește dă
   1/1/2/5/12 perle, prima prindere a fiecărei specii +5. **Jurnalul** (tasta K) arată siluete până la prima prindere,
   apoi câte ai prins și cea mai mare mărime; jurnalul complet dă ținuta **River Legend**, care nu se vinde.
3. **Ce aduce râul (B).** Cam la 4–8 minute vine pe râu ceva ce plasele nu prind și se oprește la ponton; te așteaptă,
   nu pleacă. Cât lipsești se adună cel mult trei, iar cât sunt trei, ceasul stă și pornește iar când scoți unul — nimic
   nu expiră, plafonul e spus pe față. Primul vine la 45 s după primul tău pește și e o sticlă al cărei bilet spune cum
   merge. Sticla dă 5 perle și un bilet (10 texte, fiecare adevărat în jocul de azi — o regulă schimbată își schimbă și
   biletul), cufărul 15, Golden Driftwood 40, valori fixe. Sosirea se vede (plutește din stânga până la locul ei, apoi
   toast și sunet), iar cele venite cât ai lipsit sunt spuse pe ecranul de bun venit, care apare acum și când monedele
   sunt zero. Le scoți cu undița: la capăt cardul scrie `Hook the chest (E)`, cu aceeași bară.
4. **Perlele se cheltuie doar pe aspect — amendează D46 pct. 4.** De acum le faci cât vrei la undiță; dacă ar cumpăra și
   viteză sau spațiu, pescuitul ar scurta Era 1 exact pentru cine pescuiește, fără ca simulatorul să știe, deci prețurile
   n-ar mai fi adevărate. Robux-ul rămâne pentru viteză, spațiu și aspect (D20). Tot ce aduce D59 plătește **doar în
   perle**: simulatorul rămâne neatins (Era 1 tot la 41m52s reali).
5. **Avizierul satului.** Pe punte, cu card E și buton în bară (tasta B). Pagina *Village*: 10 îmbunătățiri cu locul lor
   fix pe hartă — Flower Beds 20 · Pier Lamps 30 · Bench 40 · Bunting 60 · Well 90 · Vegetable Garden 120 · Rowboat 150 ·
   Beehives 200 · Fountain 300 · River Statue 450; cumpărată, apare pe loc cu un salt, stropi, sunetul de construcție și
   numele ei. Pagina *Outfits*: Keeper (de la început), Angler 150, Captain 400 și River Legend (din jurnal); cumperi o
   dată, apoi schimbi gratuit. Ținutele sunt doar ale jucătorului, cu siluete de pălărie pe care nu le poartă nicio
   meserie (D44). Azi numai tu îți vezi satul și ținuta: alți jucători nu se desenează.
6. **Roata la ponton — amendează lista de premii din D46 pct. 5.** Stă pe punte ca un timonier de lemn; când rotirea e
   gata, sub el pulsează inelul auriu al locurilor care te cheamă, butonul ei din bara de meniu primește un punct, iar dacă
   devine gata în timpul sesiunii apare un toast. Se deschide cu **cardul E**, ca orice obiect (tasta L, de oriunde).
   Premiile sunt darurile râului, **fără monede**: 5/10/25/60 de perle, o sticlă / un cufăr / Golden Driftwood care vin
   la ponton (dacă pontonul e plin, valoarea lor în perle, pe loc, iar textul spune asta) și Golden bait ×5 (următorii 5
   pești dau perle ×2). Media: ~11,8 perle pe rotire. Șansele rămân afișate, din ponderi. Fața din panou e timonierul
   desenat, iar iconițele premiilor le așază codul între spițe, din `WheelConfig`, recalculate la fiecare cadru cât se
   învârte — desenul nu poate rămâne în urma listei (testul cere 8 premii pentru cele 8 spițe). Restul din D46 pct. 5
   rămâne: gratuită, o dată la 24h, fără rotiri cumpărate, niciun premiu nu ia nimic.
7. **Ghidajul și quest-ul.** Capitolul 2 are, după `big_sack`, `Catch a fish at the pier` (3 perle, felul nou `fished`):
   e momentul în care încep strângerile lungi de bani, iar ghidajul tace deja după cei cinci oameni (D50) — deci quest-ul
   își are săgeata spre capătul pontonului ca **excepție numită și testată**. După primul pește, cât quest-ul activ e o
   cumpărare pe care n-o poți plăti și mâinile n-au nimic de făcut, al doilea rând al liniei NEXT spune `While you save:
   fish at the pier` (sau `A chest is waiting at your pier`), fără săgeată: pescuitul e o alegere, nu un pas.
8. **Profil v9, aditiv** (`Fishing`, `River`, `Village`, `Stats.fished`, `Stats.treasures`; șablonul și
   `ProfileMigrate.toV9` adaugă exact aceleași câmpuri, verificat de test). Remote-uri noi: `Cast`, `CastResult`, `Land`,
   `LandResult`, `TreasureArrived`, `BuyDecor`, `BuyOutfit`, `WearOutfit`, `ShopResult`; bucket-uri `Fishing` și `Shop`.
   Perlele se schimbă doar prin `EconomyService.AddPearls` / `TrySpendPearls` (roata și quest-urile trec și ele pe acolo).
   Pâlnie de analytics separată, „Pier" (FirstCast, FirstFish, FirstTreasure, FirstDecor, FirstOutfit). Consola de
   dezvoltare: `pearls`, `fish <id>`, `treasure <kind>`, `wheel`, `village`.

| Sursă de perle | Cât (țintele din `PearlBudget.test`) |
|---|---|
| Pescuit continuu | ~7–8 perle/min + 60 din primele prinderi |
| Ce aduce râul | în medie 11 perle, cam o dată la 6 min |
| Roata | ~11,8 perle/rotire |
| Quest-uri, Era 1 | 48 + 3 |
| Cel mai ieftin decor / tot ce se vinde | 20 / 1.460 decor + 550 ținute ≈ 4–5 h de pescuit continuu |

**Arta** (`scripts/art/d59.py`, ținutele în `settlers.py`, sunetele în `make_sounds.py`): pontonul lung, plutitorul, 12
pești, cele trei lucruri aduse de râu (întregi și pe apă), timonierul și fața lui, avizierul, trei iconițe, zece obiecte de
decor, trei ținute — 40 de imagini — plus trei sunete (aruncarea, mușcătura, mulinetul). Rândul `fish` al ținutelor
jucătorului ține acum undița fără fir (firul și plutitorul se desenează în lume); foile ținutelor oamenilor au rămas
identice bit cu bit, verificat pe sumele de control. Previzualizate pe harta randată înainte de urcare.
`character_anim.png` (foaia veche, dintr-o bucată) rămâne cea urcată: generatorul o rescrie, deci a fost readusă din git.

---

## D58 — Al cui e fiecare lucru: numele pe case, meseria sub oameni, tasta U la vedere, X-ul desenat
**DECIS** (2026-09-14) — owner-ul, pe două capturi din Studio (rândul de case cu cardul „Upgrade" și meniul Sawyer-ului):
*„aș vrea să apară numele a cui căsuță este (pentru upgrade). de asemenea, când mă apropii de npc-uri să le văd job-ul
sub ei. aș vrea și o tastă care să deschidă meniul de upgrade la orice apare pe ecran cu upgrade. și hai să rezolvăm
acel buton de X"*.

1. **Numele pe case.** Sub casa fiecărei meserii (și sub taraba Innkeeper-ului), numele ei, exact cum îl scrie meniul
   care se deschide de acolo („Scrap Porter"); ca „Lucky Wheel" sub roată — scris pe casă ar fi acoperit ușa. Mereu
   vizibil: rândul de case se citește dintr-o privire. **Forja**, singura clădire cu Upgrade fără nume, primește
   „Forge" pe acoperiș, ca firma tavernei (`PadController.worldName`).
2. **Meseria sub oameni, doar când treci pe lângă ei.** În raza de 170 px a personajului tău (puțin peste raza
   cardului, 130), numele meseriei apare sub picioare și se stinge lin când pleci; când omul împinge roaba spre tine,
   eticheta coboară sub roabă. Aprinse pe toți deodată, strada ar fi fost plină de etichete. Clienții tavernei nu au
   etichetă (nu sunt oamenii tăi).
3. **Tasta U exista de la D51 și nu scria nicăieri.** Butonul de pe cardul obiectului spune acum „Upgrade (U)" (și
   „Upgrade (U) · 1.25K"), cum spune „Collect (E)" acțiunea — doar cu tastatură; butonul crește după text
   (`Theme.textWidth`: fontul de pixeli are 0,56 em pe literă, iar cel mai lung cost, „123.45K", nu mai încăpea în 180 px).
   U deschide exact ce deschide butonul, doar cât butonul se vede; **a doua apăsare închide meniul**, ca J și M. Înainte,
   cu meniul deschis cardul era ascuns, iar U deschidea peste el lista veche a stațiilor.
4. **X-ul.** Butonul scria „✕" (U+2715) cu fontul de pixeli (`Arcade` = Press Start 2P); fontul n-are glifa, nici
   fonturile de rezervă din Studio (verificat în tabelele `cmap` ale fișierelor), deci pe ecran apărea pătrățelul
   caracterului lipsă. Acum X-ul e desenat ca restul trusei de interfață (`scripts/art/d58.py`: rama de lemn a
   butoanelor, fața roșie, X-ul crem cu umbră; normal, sub maus, apăsat), 40×40. Celelalte caractere speciale scrise cu
   fontul de pixeli (— · → … ← ▼ ×) există în el. Cele trei imagini sunt urcate și aprobate.
5. **„Un al 6-lea net buguit în stânga de tot"** (owner-ul, pe altă captură). E **Sixth Net-ul Erei 2**: platformele
   erelor 2–4 n-au încă loc pe hartă (`live = false`, fără `x`), deci în joc nu se pot cumpăra. În profilul din Studio
   intra din consola de dezvoltare: butonul „buy to 24" dădea platformele cu indexul sub 24, iar de la D56 Era 1 are
   18, deci trecea în Era 2 (roata de apă, jgheabul, Sixth Net, topitoria, morarul). Serverul trimitea plasa cu
   `x = pad.x or 0`, iar clientul o desena lipită de marginea din stânga a râului, peste plasele celorlalte benzi.
   Acum: nici unealta de dezvoltare nu mai dă o platformă care nu e în joc (`PadService.DevGrant`; `buyto` spune câte
   a sărit), butonul devine „all of Era 1", iar o plasă fără loc pe hartă nu mai ajunge la client (rămâne în profil,
   neatinsă).

Verificat înainte de Studio pe hărțile randate din config, cu textul rasterizat din fontul adevărat: numele caselor nu
se ating între ele (cel mai lat, „Scrap Collector", 109 px la case așezate la 150–190 px), firma forjei stă pe acoperiș
fără să atingă hornul, iar eticheta omului stă sub picioare.

---

## D57 — Satul pe flux: harta Erei 1 cu cap, clădirile așezate pe pământ
**DECIS** (2026-09-14) — owner-ul, pe o captură din joc: *„vreau să aibă mai multă viață această hartă, arată cam
urât și simplă, texturile obiectelor (taverna sawmill forge etc) parcă plutesc mereu, nu fac parte din realul
absolut al jocului, trebuie să dezbatem puțin"*, apoi *„consideră și un plasament al lucrurilor/obiectelor diferit
(par foarte random plasate și fără «cap»)"*.

**Dezbaterea.** Diagnosticul, arătat pe machete: clădirile n-aveau umbră (oamenii și copacii aveau), drumurile de
pământ aveau umbră ca niște scânduri puse pe iarbă, decorul era împrăștiat doar în afara terenului, iar pozițiile
veniseră pe rând, „unde mai era loc" — lemnul ocolea toată harta, fierul o traversa de două ori. Principiile, cu
surse (`docs/research/44-harta-vie.md`; citatele Slynyrd și The Level Design Book reverificate): umbra leagă
obiectul de sol, fiecare clădire stă pe ceva al ei, fiecare linie are curtea ei, un centru și margini. Trei variante
arătate ca imagini (așezat pe pământ în aceleași locuri · satul pe flux · lume nouă pe dale); owner-ul a ales
**satul pe flux**, apoi: *„doar că distanțele puțin mai mari, ca totuși npc-urile să facă un drum. și harta ține-o
în jos la fel de mare"*, casele *„pe pământ"*, iar la tavernă *„poți păstra piatra, doar niște pământ în plus"*.

1. **Așezarea.** Râul și puntea sus, neschimbate. **Curtea lemnului** sub plasele de lemn, lângă tavernă: depozitul
   sus, lângă aleea tavernei; gaterul jos, cu fața la stradă. **Curtea fierului** spre Moară: shed-ul sus, sub plasa
   de scrap; forja jos, cu fața la stradă. Marfa brută coboară de pe punte pe câte o **alee**, cea gata iese pe
   **strada satului** și merge pe ea spre **piața tavernei**. **Casele oamenilor** stau pe un rând, peste stradă de
   curtea liniei lor; clopotul, în colțul de sus de lângă poarta Morii; roata și traista mare, peste stradă de piață.
   **Patru drumuri** în loc de șapte (`street`, `tavern_link`, `plaza`, `iron_lane`), fiecare într-o singură direcție.
   Sudul străzii rămâne deschis: acolo va duce drumul spre harta cu clasamente (de discutat altă dată).
2. **Drumurile oamenilor**, dus, pe graful din joc (secunde la viteza lor): Porter 5,5 (azi 5,5) · Hauler 7,4 (10,5) ·
   Scrap Porter 4,5 (9,2) · Iron Hauler 11,8 (6,8) · turul Collector-ului 12,2 (16,6); ciclul oricărui culegător sub
   30 s. Față de machetă, de două-trei ori mai lungi; turul tău de mână, cu ~30% mai scurt.
3. **Nimic construit pe iarbă goală.** `TycoonConfig.YARDS`: pământ bătătorit sub fiecare curte de lucru, sub fiecare
   casă, sub tarabă, clopot, roată și traistă, și în jurul pieței tavernei (piatra rămâne, cu pământ în plus). Dala
   drumului, mai deschisă, cu colțuri rotunjite și iarbă peste margini. În Era 1 dala-platformă de sub clădiri iese
   (ar fi arătat lipită peste pământ).
4. **Umbre** (`UI/GroundShadow`: elipsa de sub oameni, lată cât obiectul, împinsă spre dreapta-jos — lumina din
   stânga-sus) sub tavernă, depozit, gater, roată, clădirile platformelor și ruinele lor. **Drumurile de pământ nu mai
   au umbră**; puntea, care chiar stă peste mal, o păstrează.
5. **Decor așezat de mână** (`TycoonConfig.DECOR`, 36 de obiecte din recuzita existentă): felinarele și butoiul
   pieței, stiva de bușteni și butucii curții lemnului, pietrele și butoaiele de lângă forjă, gardurile curților spre
   stradă, indicatoarele de la capetele aleilor, felinarele străzii, flori între case, copaci. Sub clădiri și oameni.
6. **Artă nouă** (`scripts/art/d57.py`): `tile_plaza` (piatra pieței) și `grass_edge_h/v` (smocuri peste marginile
   pământului), din culorile dalelor existente. Owner-ul a aprobat piața și marginile desenate procedural pe
   previzualizare; arta finală, urcată odată cu mutarea, i-a fost arătată pe harta randată din config.
7. **Verificarea înainte de joc.** Harta a fost proiectată ca date, cu un port Python al `RoadGraph` și al testelor de
   așezare (a dat exact ciclurile de azi: Collector 20 s, Scrap Collector 5,3 s), randată din acele date și aprobată
   de owner; config-ul portat e identic cu ea (0 diferențe). În cod: la shed omul stă acum cu fața spre dreapta, unde e
   grămada (test nou pentru orice așezare: fiecare om stă cu fața spre grămada lui); exemplul testului „scurtătura
   peste iarbă" s-a mutat (spawn-ul stă lângă alee); id-urile curților caselor nu sunt ale platformelor —
   simulatorul caută prețul unei platforme după primul `id = "…"` din fișier.
8. **Tot din sesiunea asta, reparate înainte:** pe telefon, reflectorul „Claim your rewards here!" cădea lângă
   butonul cu cartea — `AbsolutePosition` folosește sistemul zonei sigure (CoreUISafeInsets), iar noi adunam doar bara
   de sus; acum conversia între straturi se citește din straturile însele (aceeași corectură pentru textele „+N" și
   eticheta ghidajului). Lista de quest-uri: cele de revendicat sus, apoi cele nefăcute, cele revendicate la coadă
   (`QuestMath.displayOrder`); recompensa stă pe buton, „Claim 1 (perlă)", fără rândul „Reward".

**Se abate** de la D50 (harta în buclă, șapte drumuri), D55 (colibele lipite de meseria lor — acum pe rândul liniei
lor, lângă curte) și D53 (dala sub clădirile cumpărate). Viața hărții (fum din hornuri, păsări, spumă la stâlpi,
frunze care se mișcă) e pasul următor, nefăcut încă.

## D56 — Linia fierului cu oamenii ei; atelierul devine Forge, colecția așteaptă
**DECIS** (2026-09-14) — owner-ul, după D55: *„revizuiește cum este făcut workshop-ul (este varianta veche?); am
impresia că player-ul se pierde când ajunge la scraps și nu știe ce să facă… scraps nu are om npc care se ocupă de
transport la storage, după transport la workshop, după cineva care prelucrează, după cineva care le duce la
tavern… nu știu care e treaba cu acele collectables, nu au texturi"*. Din variantele arătate ca pași ai
jucătorului a ales **A** (linia fierului cu patru oameni ai ei) și **1** (clădirea devine Forge, colecția
așteaptă). Planul, cu cele două revizii: `~/.claude/plans/d56-linia-fierului.md`.

**Ce a găsit revizia (înainte de schimbare):** atelierul era pe jumătate vechi — E la ușă și butonul „Workshop"
deschideau panoul de reparații din colonie, cu forja D55 lipită peste; ghidajul tăcea după cei cinci oameni ai
lemnului; Workshop → Scrap Shed → Fifth Net erau trei cumpărări la rând, primele două fără efect vizibil; aceiași
oameni cărau și scrap-ul; scrap-ul curgea ~4 minute înainte de clopot și aducea ~8% din bani. **Collection** era
sistemul de găsiri din colonie (TYCOON §H), cu 36 de obiecte fără pictograme și butonul în bară din primul minut.

1. **Linia fierului, în ordine** (Era 1 are 18 platforme, erele 2–4 se renumerotează cu +4; profilurile țin
   platformele pe id): Fourth Net → **Forge** 5,5K (id-ul rămâne `workshop`) → **Fifth Net** 7K (cere Forge; prinde
   scrap, nu îl ia nimeni) → **turul de mână** (culegi, duci la forjă, stai în inel, iei fierul, îl vinzi) →
   **Scrap Shed** 2,5K (cere 5 plase) → **Scrap Collector** 2,5K → **Scrap Porter** 2,8K → **Smelter** 3,5K →
   **Iron Hauler** 3,5K → **Landing Bell** 8K. Al doilea om: Scrap Collector 10K, Scrap Porter 11K, Smelter 9K,
   Iron Hauler 18K (Sawyer 16K, de la 12K). Oamenii lemnului se întorc la drumurile lor, fără opririle de scrap
   din D55; Innkeeper-ul vinde amândouă.
2. **Forja ca gaterul:** fără Smelter topește doar cât stai în inelul ei („Stand here to smelt", „Smelting — N
   left"); cu Smelter, tot timpul, iar el bate cu ciocanul cât forja chiar topește. **Prezența e pe loc**
   (`presentUntil[player][place]`, remote nou `AtForge` cu bucket propriu), ca inelul forjei să nu pornească
   gaterul; toastul unui E citește „are om" pe locul lui. Inelul, plăcuța și bucla de prezență au ieșit din
   `SawmillController` într-un modul comun (`UI/StandRing`), folosit de amândouă. E la forjă: „Smelt scrap" / „Take
   iron"; Upgrade = nivelul forjei. Fumul din horn e desen (fâșie de trei nori), nu cercuri din cod.
3. **Atelierul vechi și colecția, puse deoparte — intenționat fără nicio intrare:** butoanele „Workshop" (R) și
   „Collection" (C) au ieșit din bară, forja nu mai deschide panoul, insigna cu găsirile de pe clădire a ieșit.
   Codul și profilul (`Pile`, `Index`, `Workshop`) rămân neatinse; controller-ele rămân inițializate, ascunse, ca
   remote-urile lor să fie folosite pe ambele părți. Găsirile deja strânse în atelier (doar în profilurile din
   Studio) rămân în `data.Pile`, nearătate. Efectul `indexFound +6` al platformei a ieșit (intra în venitul
   lanțului doar pentru că deții clădirea); bonusul colecției reparate rămâne în formule.
4. **Găsirile merg cu marfa și se vând la tavernă.** Nu mai ocolesc spre atelier (nici la tine, nici la oameni):
   ocupă loc în traistă sau în roabă, iar cu traista plină rămân în plasă. **Ales de mine în implementare:** o
   găsire neprelucrată din traistă se vinde direct la tavernă, iar locul unde lași lemnul (depozit, gater) sau
   scrap-ul (shed, forjă) o ia și pe ea, neschimbată. Până acum era „lemn brut": taverna o refuza — deci toastul
   primei găsiri, *„A rare find: {name}! The tavern pays well for it."*, ar fi mințit — iar una prinsă în plasa
   de scrap ar fi trimis ghidajul cu ea la gater („Take the logs to the sawmill" fără niciun buștean). Capitolul 1
   rămâne identic: găsirea trece prin gater odată cu buștenii și e numărată la „Cut the logs into planks".
5. **Economia** (simulatorul întâi, `ChainMath` port la bit, valori de aur din `golden_chain.py`, 14 cazuri):
   două linii care împart doar taverna — `lemn_max = min(plasele de lemn, Collector, Porter, gater, Hauler)`,
   `fier_max = min(Fifth Net, Scrap Collector, Scrap Porter, forja, Iron Hauler)`; taverna vinde întâi fierul,
   lemnul din ce rămâne; venit = `lemn·1,65 + fier·3,55` × multiplicatorii. **Timpul tău se împarte pe linii**
   (fiecare linie are timpul tău întreg), așa că deschiderea fierului nu poate scădea lemnul în nicio stare, iar
   capitolele 1–2 sunt bit cu bit cele de dinainte. Linia fierului e deschisă = Forge + Fifth Net. **Veriga slabă**
   rămâne cea cu cei mai mulți bani pe bucată, plus veriga slabă a fiecărei linii (`woodBottleneck`,
   `ironBottleneck`, `""` cât fierul e închis), ca meniul unui obiect cu câștig zero să spună ce îl ține **în
   linia lui**. Oamenii fierului vin în rafală, ca cei ai capitolului 1: prețul lor e 45–60 s din venitul din
   clipa în care se deschid (`BURST_WAIT`), fără scara deblocărilor. `ROLE_BASE`: Scrap Collector 2,0, Scrap Porter
   2,5, Iron Hauler 6,5. **Era 1 la 41m52s** reali (de la 37m44s), `--robust` între 41m29s și 43m10s; fierul face
   **35% din bani** la final (de la 8%).
6. **Compromisul porții de 0,5%, decis de mine după intenția owner-ului.** Scrap Porter-ul (1,3%) și Iron
   Hauler-ul (0,3%) rar sunt cea mai lentă verigă: ultimul om de drum trebuie să care cel puțin cât tot timpul
   tău (altfel angajarea lui ar scădea venitul), iar la baza asta rar mai e el gâtuirea; nicio ordine a angajărilor,
   bază sau cost de treaptă încercat nu l-a urcat peste 0,5%. Întrebat, owner-ul n-a înțeles problema și a spus
   intenția: *„eu mă gândeam că fierul este într-adevăr ceva care se face mai greu la început dar care aduce mai
   mulți bani pentru a te ajuta să deblochezi era 2"*. Ca atare, cele două verigi sunt scutite de poartă
   (`BOTTLENECK_EXEMPT`); efectul pentru jucător: urcarea lor rar merită în Era 1 — gâtuirea fierului e forja
   (70% din timpul cu scrap) și Scrap Collector-ul (27%).
7. **Ghidajul se trezește la Forge** și merge până ai cei patru oameni ai fierului (`GuideMath.guidedRoles`);
   până la Forge tace după cei cinci oameni ai lemnului, ca în D50. `GuideMath.loopStep` e un singur lanț de 11
   pași, cu pașii fierului lângă perechea lor de lemn (bușteni → gater; scrap → forjă; inelul gaterului; inelul
   forjei; ia scândurile; ia fierul; vinde; ia din depozit; ia din shed; plasele fără omul liniei lor; plasele
   prind), testat în ordine. **Textele spun ce duci**: „Sell the planks / the iron / the planks and iron / the
   find at the tavern", la fel mesajul de traistă plină. **Capitolul 2** se oprește înaintea Forge; **capitolul 3
   „The Iron Line"** (8 perle): Build the Forge · Cast the Fifth Net · Smelt 10 iron at the Forge · Sell the iron at
   the tavern (10, doar fierul, `Stats.ironSold`) · Build the Scrap Shed · Hire a Scrap Collector · Hire a Scrap
   Porter · Hire a Smelter · Hire an Iron Hauler · Ring the Landing Bell. Id-urile salvate rămân unde sensul e
   același.
8. **Profil v8** (`toV8`, aditiv, idempotent): `Crews` pentru cele patru meserii, `Stats.ironSold`; ce duceau
   oamenii de lemn pe drumurile D55 se mută după marfă — scrap brut în shed, fier în grămada forjei.
9. **Meniurile:** meniul unei plase de scrap spune „scrap a minute", forja „Smelts only while you stand here" fără
   Smelter, iar forja fără plasa de scrap *„Won't earn more yet: no scrap comes in until the Fifth Net"*; panoul
   ascuns de pe U arată lemnul, taverna, apoi verigile fierului (ascunse cât linia e închisă).
10. **Arta** (`scripts/art/d56.py`, ținute noi în `settlers.py`, previzualizare `scripts/art/preview_d56.py`):
    4 ținute (Scrap Collector, Scrap Porter, Smelter cu șorț de piele, Iron Hauler), 8 colibe (două mărimi) și
    fumul forjei — 13 fișiere urcate, **toate aprobate la moderare**. Avizierele poartă pictograma meseriei
    (plasa, scrap-ul, ciocanul, fierul). **Pozițiile** ies din harta randată acum direct din `TycoonConfig.luau`
    (`preview_d56.py map`, nu copiate de mână): Scrap Collector lângă shed, Scrap Porter la capătul de sus al
    drumului lui, Smelter în spatele forjei, Iron Hauler la capătul lui de la tavernă. **Ales de mine:** al doilea
    Smelter stă în dreapta primului — în stânga ar fi stat exact unde răstoarnă Scrap Porter-ul roaba.

**Revizia codului** (doi agenți independenți, pe server și pe client, după implementare): pe server nimic de
reparat (o funcție rămasă fără cititori, `EconomyService.PileCount`, a ieșit); pe client un text care mințea —
traista plină doar de găsiri spunea „take the planks to the tavern" — reparat cu „Sack full — take the finds to the
tavern", și în ghidaj, cu test. Poarta întreagă trece: 326 de teste, `check_requires` fără nicio problemă (remote-ul
`AtForge` e folosit pe ambele părți), `--robust`, panourile.

**Se abate** de la D55 (forja singură, aceiași oameni pentru scrap, „Smelt 25 iron at the Workshop", Workshop →
Shed → Fifth Net), D50 (ghidajul tace definitiv după cinci meserii) și F1 spec 4.5 (Workshop și Collection în
bară). **Platforma `smelter` a Erei 2** (neconstruită, „Melt scrap into iron") rămâne cum e: topitul s-a mutat în
Era 1, clădirea Erei 2 se regândește când ajungem acolo.

## D55 — Resturile pe drumul lor, roabele, grămezile la gater, colibele care cresc
**DECIS** (2026-09-13, noaptea) — owner-ul, înainte de culcare, a cerut ca planul să fie scris și aprobat de
mine: *„este o confuzie la ce prinde al doilea net: scraps. scraps ar trebui să poți prinde doar la ultimul
net, să se ducă în altă parte la procesare, nu la sawmill, și apoi la final duse la tavernă la vânzare"*,
*„primii oameni ar trebui să poată căra scraps nu la storage de wood ci alt storage separat, deblocabil"*,
*„npc-urile cară driftwood-ul într-un sac, nu într-o roabă… și când le pune apare un ciocan"*, *„texturile
pentru când npc-ul pune jos lemnul respectiv plank-urile sunt patetice… ar trebui să fie măcar lângă sawmill
în stânga respectiv în dreapta"*, *„pancardele npc-urilor ar trebui puse în apropierea job-urilor"*, *„când
angajezi npc-ul aș vrea să se transforme într-o colibă mică… care când se angajează mai mulți npc, să crească
în dimensiune"*. Planul, cu cele două revizii: `~/.claude/plans/d55-resturi-roabe-colibe.md`.

1. **Ce prinde fiecare plasă.** Plasele 1–4 prind lemn (driftwood 95%, finds 5%); **Fifth Net**, cea din
   larg, prinde **scrap** (95%, finds 5%) — felul stă în efectul plasei (`TycoonMath.netKind`,
   `pickGood(roll, kind)`), nu mai decide banda. **Reeds și shards ies din Era 1**: treceau prin gater
   exact ca scrap-ul; ce e deja în profiluri se vinde în continuare.
2. **Scrap Shed** (platformă nouă, indexul 12 — toate platformele de după s-au renumerotat): al doilea
   depozit, la stânga drumului depozitului, sub Fifth Net. Cere Workshop; Fifth Net cere Scrap Shed.
3. **Forja atelierului** topește scrap-ul în **Iron** (valoarea 3 = trei scânduri), cu niveluri ca gaterul
   (`FORGE_BASE_RATE` 1,2, `FORGE_UPGRADE_BASE` 60), singură — fierarul vine cu atelierul. Grămada de topit la
   stânga atelierului, fierul la dreapta; E la ușă topește și ia fierul, fără nimic de făcut intră în atelier.
4. **Aceiași oameni, drumuri mai lungi** (`HandRoutes`, opriri de „ia" și „lasă" cu direcție): Collector-ul
   lasă scrap-ul la shed și lemnul la depozit, ținând loc în roabă pentru scrap-ul care îl așteaptă; Porter-ul
   face bucla shed → depozit → gater (lasă buștenii) → atelier (lasă scrap-ul), dar ia scrap doar cât
   atelierul are sub 40 de topit; Hauler-ul ia întâi fierul, apoi scândurile. Collector-ul lasă scrap-ul în
   plasă cât shed-ul are deja 60. Fără scrap, drumurile sunt cele de dinainte.
5. **Matematica** (simulator → `ChainMath`, paritate la bit, valori de aur tipărite de
   `scripts/economy/golden_chain.py`): `shared = min(adunat, dus, dus la tavernă, vândut)`;
   `scrap = min(min(S, forja), shared)`, `lemn = min(min(W, gater), shared − scrap)`; venit =
   `lemn·1,65 + scrap·3,55` × multiplicatorii. Orice capacitate în plus doar lărgește ce se poate, deci nicio
   cumpărare nu scade venitul; fără scrap e exact minimul celor șase debite. **Veriga slabă** e cea al cărei
   pas în plus aduce cei mai mulți bani pe bucată (fără scrap iese primul minim, ca înainte); `forge` e a
   șaptea verigă. Simulatorul cumpără traista și shed-ul când le cer quest-urile (`QUEST_UNLOCKS` — fără asta,
   o variantă din `--robust` ajungea la 1h40m pentru o traistă de 80), shed-ul nu urcă scara prețurilor, iar
   poarta de 0,5% a forjei se măsoară pe timpul în care există scrap.
6. **Prețurile re-derivate:** Collector 12, Porter 15, Sawyer 18, Hauler 20, Innkeeper 25, Second Net 28,
   Third Net 90, Bigger Sack 80, Fourth Net 900, Workshop 5,5K, Scrap Shed 7,5K, Fifth Net 8K, Landing Bell 9K;
   al doilea om: Collector 1,1K, Porter 1,6K, Sawyer 12K, Hauler 2,5K, Innkeeper 4K. Era 1 la **37m44s** reali
   (de la 33m59s); `--robust` între 37m19s și 39m50s.
7. **Quest-uri:** „Build the Scrap Shed" înaintea plasei a cincea, „Smelt 25 iron at the Workshop" (fel nou
   `smelted`) înaintea clopotului. **Profil v7**: `ScrapPile`, `ForgePile`, `IronPile`, `Stations.forge`,
   `Stats.smelted`, aditiv, și în șablon. Remote-uri `UseShed`, `UseForge`.
8. **Roabele.** Collector, Porter și Hauler împing o roabă în care se vede ce duc (bușteni, scânduri, scrap,
   fier, ladă; trei trepte); rânduri noi în foile în straturi (`push_side/down/up`, `load`, `tip` — primele
   15 rânduri identice bit cu bit); la opriri omul stă spre grămadă, încarcă sau răstoarnă roaba (rotită în
   jurul roții). Ciocanul a ieșit din drumul oamenilor.
9. **Grămezile** sunt obiecte pe trepte (1–4, 5–14, 15–39, 40+): stivă de bușteni, teanc de scânduri, morman
   de scrap, lingouri; al doilea fel alături, mai mic; cifra rămâne. **La gater: bușteni în stânga, scânduri în
   dreapta**, lipite de clădire (sensul din desenul gaterului).
10. **Avizierele lângă meserii și colibele care cresc:** Porter — sus pe drumul lui, lângă depozit; Sawyer —
    lipit de spatele gaterului; Hauler — la capătul lui de la tavernă. La angajare avizierul devine coliba
    omului (răsare de la bază, cu praf); al doilea om o face mai mare. Colibe Porter/Sawyer/Hauler în două
    mărimi, coliba mare a Collector-ului, taraba mare a Innkeeper-ului.
11. **Arta** (`scripts/art/d55.py`, rânduri noi în `settlers.py`, previzualizare `scripts/art/preview_d55.py`):
    34 de fișiere urcate după ce le-am verificat pe previzualizări — 13 foi de oameni și 21 de sprite-uri —, cu
    moderarea în „Reviewing" la urcare.

**Revizia codului** (agent independent, după implementare) a găsit trei lucruri, reparate: panoul vechi de pe
tasta U nu avea rândul forjei (sfatul spunea „the forge is slowest" fără rând pe care să-l arate), taverna
spunea doar „Logs go to the sawmill" cu bușteni și scrap în traistă, și o ramură moartă în `PadController`.
Tot eu: Collector-ul ținea loc pentru scrap și când plasa de scrap era a celuilalt Collector (ar fi dus mai
puțin lemn decât debitul lui), iar încărcătura din roabă se desena peste peretele din față (copil al imaginii).
Toate cele 34 de fișiere de artă au trecut moderarea („Approved").

**Alese de mine, de revăzut cu owner-ul:** reeds și shards ies din Era 1; forja merge singură (nu o meserie
nouă); fierul = 3; coliba crește la al doilea om; atelierul e locul unde se topește.

**Se abate** de la D49 (lanțul unic cu șase debite), D50 (grămezile gaterului sub curte, Hauler-ul pleacă din
vest), D51 (plasa a patra deschidea scrap-ul pentru toate) și D53 (avizierul curat după angajare).

## D54 — Nivelul sunetului: muzica de fundal și panoul „Sound"
**DECIS** (2026-09-13) — owner-ul, după ce a intrat în joc: *„muzica este prea tare, nu prea este de
fundal. userul ar trebui să poată selecta nivelul audio, dar momentan tot este prea tare când intru
în-game"*.

1. **Două niveluri, 0–10:** **Music** (implicit 4) și **Sounds** (implicit 10 = amestecul de dinainte);
   0 = oprit. Curba e pătratică, ca pașii să se audă egal: `volum = max × (nivel/10)²` (`AudioLevels`,
   testat). Muzica are `max` 0,6: la nivelul 4 volumul e 0,096, cu ~11 dB sub vechiul 0,35 (piesa e
   masterizată tare, vârfuri la −3 dBFS); la 10, 0,6 pentru cine o vrea tare. Dacă tot e prea tare, se
   reglează un singur număr: `AudioLevels.MUSIC_MAX`.
2. **Volumul stă pe grupuri:** `SoundGroup` „Music" — sunetul e fixat la 1, iar estomparea urcă grupul
   de la 0, deci niciun cadru la volum plin la intrare — și „Effects", pus pe fiecare efect (tabelul
   `VOLUME` rămâne amestecul dintre ele). Muzica la 0 se stinge și intră în pauză; la revenire continuă
   de unde era, nu de la capăt.
3. **Panoul „Sound"** (`AudioPanel`), pe butonul din bară (tasta M) care înainte comuta muzica: două
   rânduri — numele, **−**, zece segmente aurii care cresc spre dreapta (se pot și apăsa), **+**,
   „40%" / „Off". Schimbarea se aude pe loc; la Sounds, un click de probă. Butonul care nu mai are unde e
   gri. Rândul Music apare doar cu muzica urcată (un reglaj care nu schimbă nimic ar minți, D40); butonul
   din bară e mereu acolo, pentru că efectele există și fără muzică.
4. **Salvarea** pleacă după 0,6 s de liniște, **separat pe fiecare canal**, iar la închiderea panoului
   (buton, Esc, Q, M) imediat. Nivelurile din profil se aplică doar la **prima** stare de la server; după
   aia panoul e adevărul pe client, ca o stare venită între apăsare și salvare să nu mute bara înapoi.
   Cine iese din joc în cele 0,6 s de după o apăsare, cu panoul deschis, pierde doar acea ultimă apăsare.
5. **Serverul:** remote `SetAudio(kind, level)` în locul lui `SetMusic` — `kind` ∈ {music, sound}, nivel
   întreg finit 0..10, bucket `SetAudio` (6, 2/s). Profil **v6** (`ProfileMigrate.toV6`, înainte de
   `Reconcile`): cine oprise muzica o găsește la 0, nu repornită; restul primesc implicitele;
   `Settings.music` rămâne în profil, necitit. O valoare stricată cade pe implicit, pe server și pe client.
6. **Ies:** `SetMusic`, `DataService.MusicOn/SetMusic`, `MusicController.Toggle`,
   `MenuBarController.SetDimmed`, `Strings.MENU_MUSIC/musicToggled` și toastul „Music on/off" — panoul
   spune „Off" chiar pe rândul lui.

**Persistența se verifică doar în jocul publicat:** în Studio ProfileStore merge pe mock și nimic nu se
salvează între sesiuni.

**Se abate** de la D51 pct. 8 (butonul pornit/oprit, `Settings.music`, volumul fix 0,35).

## D53 — Ruinele malului, bușteni care vin pe râu, atelierul nou
**DECIS** (2026-09-13) — owner-ul, după D52: *„în locul acestor chestii cu negru care urmează a fi
deblocate, să fie de fapt niște ruine sau lucruri stricate pe jos (dacă te duci la ele trebuie să scrie că
se deblochează înainte X ca să poți aici)"*, *„ar trebui făcut ceva cu animația de prindere a
driftwood-ului pentru că apar așa de nicăieri, ceva mai realistic din punct de vedere al logicii"*,
*„change the texture to the workshop, looks awful"*. Alese de owner: **toate ruinele, de la început**;
**avizier „Help wanted"** pentru Porter, Sawyer și Hauler (pe oameni îi angajezi, nu îi reconstruiești).

1. **Ceasul plasei nu se mai oprește când e plină.** `TycoonMath.netTick` decide un tick: cu loc, prinde
   câte momente au trecut (cel mult cât încape); plină, ceasul sare la primul moment de după acum, la
   fiecare tick. Golirea — de mână sau de Collector — nu mai repornește ceasul la „acum + interval".
   Prinderea de după golire vine la momentul ei din ritm: cel mult un interval mai devreme decât înainte.
   Simulatorul nu modelează pauzele plaselor pline, deci prețurile rămân.
2. **Buștenii vin pe râu** (`CatchFloat`, rescris): de la marginea din stânga a lumii, cu curentul
   (130 px/s), pe **curentul de lângă plase** (`NEAR_CURRENT_Y` 552), apoi un cot lin în plasă, pe măsura
   coborârii (`clamp(1,2 × coborârea, 120, 220)` px, pantă de cel mult 51°), exact la momentul prinderii;
   apare estompat și intră micșorându-se. La o plasă plină trece pe lângă și se stinge. Cel mult 6 bușteni
   spre o plasă, la cel puțin 0,9 s unul de altul. Test: niciun drum nu trece prin altă plasă.
3. **Decorul râului** rămâne pe curentul din larg (516), mai mic (×0,35), la viteza șirului, cu bunurile
   pe care încă nu le poți prinde (resturi / cioburi, după benzile atinse); lăzile coloniei ies.
4. **Ruinele:** orice platformă a Erei 1 necumpărată stă pe mal ca ruină, pe locul exact al construcției;
   încuiată e ușor stinsă, cumpărabilă are prețul deasupra, ca siluetele de dinainte. Lângă o ruină
   încuiată (rază 120, după 0,4 s) cartonașul are un mod nou: „RUINS" / „HELP WANTED", numele, descrierea
   și butonul stins cu **prima condiție neîndeplinită** (`TycoonMath.padBlocker` + `Strings.padNeeds`:
   „Hire a Hauler first", „Cast the Fourth Net first", „Upgrade First Net to level 2 first"…) — aceleași
   condiții pe care le verifică jocul. E, butonul și atingerea ruinei spun același lucru. Cardul unui
   obiect (Take logs, Sell…) bate mereu o ruină.
5. **Avizierele:** Porter, Sawyer, Hauler au un avizier strâmb cu un anunț rupt; după angajare, avizierul
   curat cu pictograma meseriei (buștean / fierăstrău / scânduri), în locul platformei cu bifă.
   Collector-ul își păstrează coliba: ruina colibei → coliba.
6. **Atelierul nou** (`prop_workshop_e1`, 64×48, din aceeași familie cu taverna): bârne, șindrilă
   verde-cenușie, fereastra-raft cu găsirile de pe râu (una strălucește), bancul cu menghina, uneltele pe
   perete, firma cu ciocanul, hornul fierăriei. `b_workshop` din era coloniei rămâne doar cât noul nu e urcat.
7. **Arta** (10 sprite-uri, `scripts/art/ruins_d53.py`) s-a urcat după aprobarea owner-ului pe
   previzualizare (`scripts/art/preview_ruins.py`: *„urcă arta, ruinele arată bine"*), cu moderarea în
   „Reviewing" la urcare. `Assets.has` știe doar dacă id-ul e 0: cât imaginea e încă în moderare, clientul
   n-are cum să afle, deci ruina poate apărea goală o vreme, nu cu desenul de dinainte.

**Găsite pe drum și reparate:** (a) textul ghidajului de deasupra țintei stătea în lume, **sub HUD**: cu
taverna sus-stânga (când ești la gater), „Sell the planks at the tavern" cădea sub monede, traistă și
linia NEXT și nu se citea [owner, Studio] — acum stă deasupra țintei dacă e loc, altfel sub inel, altfel
deloc (textul e oricum pe linia NEXT), și nu iese din ecran (`GuideMath.labelPlacement`, testat); (b) un
cot fix de 120 px ar fi dat, pe banda de lângă mal, un plonjon de 66°; (c) fără săritul ceasului la
fiecare tick, scoaterea resetărilor ar fi adus o rafală de prinderi după o plasă lăsată plină.

**Se abate** de la D47 („se vede obiectul direct, doar ca locked" — acum ca ruină, nu ca siluetă), de la
plutirea din F1 (un singur bun, 300 px, în linie dreaptă) și de la D49 (Porter, Sawyer, Hauler fără desen).

---

## D52 — Oamenii înaintea plaselor, meniul obiectului simplu
**DECIS** (2026-09-13) — owner-ul, după ce a jucat D51: *„vreau ca playerul să facă o singură dată un tur
net – sawmill – tavern iar al doilea tur să își deblocheze treptat npc-urile. în prezent te pune să îți
faci x nets și mai apoi npc-urile, ceea ce este greșit"*, *„meniurile astea trebuie schimbate pentru că nu
prea înțeleg nimic din ele dacă închid un ochi"*. Alese de owner: toți cinci oamenii după prima vânzare,
apoi plasele (confirmat după ce i s-a arătat compromisul de la pct. 3); ghidajul tace tot după cei cinci;
meniul — varianta simplă, cu fontul din joc.

1. **Ordinea Erei 1:** prima plasă → Collector (cere o singură plasă), Porter, Sawyer, Hauler,
   **Innkeeper după Hauler** (nu la trei plase) → **a doua plasă abia după Innkeeper** (pe lângă nivelul
   2 al primei) → a treia plasă, traista mare, a patra, Atelierul, a cincea, clopotul. Indexul
   platformelor urmează ordinea cumpărărilor din simulator. Capitolul 1 are 11 quest-uri: bucla de mână,
   cei cinci oameni, nivelul 2, a doua plasă. `sell_forty` iese; Innkeeper-ul dă 3 perle, deci totalul
   quest-urilor rămâne 40.
2. **Simulatorul urmează quest-ul:** cât lipsește un om al capitolului și condiția lui e împlinită,
   jucătorul îl ia când are banii și nu cumpără nimic altceva până atunci — cu o singură plasă, un om
   adaugă zero venit, deci lăcomia singură nu l-ar lua niciodată. Prețuri re-derivate: oamenii 13 / 15 /
   18 / 20 / 25, Second Net 30, Third Net 100, Bigger Sack 90, Fourth Net 900, Workshop 7K, Fifth Net
   7,5K; al doilea om 1,1K / 1,8K / 13K / 2,8K / 4,5K. 9 cumpărături în primele 5 minute reale.
3. **Compromisul, ales de owner după ce l-a văzut explicat pe pașii tutorialului:** un om la treapta 1
   lucrează de 7–12 ori mai repede decât o plasă. Cu toți cinci angajați devreme, veriga slabă e aproape
   mereu plasele (47% din Era 1) sau adunatul (41%); gaterul, Hauler-ul și taverna sunt gâtuirea doar
   2–3% — upgrade-urile lor rar aduc ceva în Era 1. Era 1 crește de la 27 la 34 de minute reale. ~200 de
   variante de constante (costuri, viteze, baze, creșteri, munca jucătorului, oameni-ucenici) n-au ținut
   pragul de 5% la ±15%; cea mai apropiată ordine care îl ținea era „Collector + Porter întâi". Poarta
   „fiecare verigă e gâtuirea ≥5% din timp" coboară la **0,5%** (cea mai mică cotă la ±15% iese 0,7%):
   prinde doar o verigă care nu e *niciodată* gâtuirea. Restul porților neschimbate.
4. **Meniul obiectului, simplu:** nivelul („Level 3 → Level 4"), o casetă cu ce face și cât **pe minut**
   („19.8 → 20.4 logs a minute"), pragul următor, **un rând colorat din câștigul real al unui nivel**
   (câmp nou `gain` pe rândurile clădirilor): verde „Next level earns +1.2 coins a minute", sau portocaliu
   „Won't earn more yet: your nets are slower" cu butonul „Go to Nets"; x1 / x10 / Max; butonul mare cu
   prețul pe el. La meserie: treapta și oamenii, ce face omul, cine face treaba, apoi treapta și al doilea
   om, fiecare cu prețul pe buton. Ies: cele șase pastile ale lanțului, debitele pe secundă, x50 (rămâne
   pe server). Lista veche (`StationPanel`) nu se atinge.
5. **Pe minut, nu pe secundă:** +3% la 0,33/s ieșea „0.3 → 0.3 (+0.0)" — adevărat și inutil; pe minut e
   „19.8 → 20.4" (`TycoonMath.formatPerMinute`, rotunjit, nu tăiat).

**Găsite pe drum și reparate:** (a) analytics-ul numea indexul 2 „BoughtSecondNet" — după reordonare ar
fi etichetat Collector-ul; acum toate platformele sunt `BoughtPad<index>`; (b) rândul „This is your
slowest link" al meniului vechi putea sta pe o verigă la egalitate, unde un nivel dă tot zero — rândul
nou se sprijină pe câștigul calculat, iar la egalitate spune „just as slow", nu „slower".

**Se abate** de la D51 pct. 1 (bucla repetată și „Sell 40 planks" înaintea extinderii, oamenii după trei
plase), de la D49 (Innkeeper-ul la trei plase) și de la pragul de 5% al verigilor [D48, D49].

---

## D51 — Primul minut ghidat pas cu pas, cardul obiectului, sunetul plaselor, muzica
**DECIS** (2026-09-13) — owner-ul, după ce a jucat D50: *„nu îmi place cum te ghidează jocul în acel
tutorial, te împinge să îți faci net-uri cât mai multe dar fără materiale, jucătorul nu știe exact ce să
facă la început"*, *„după ce pui driftwood-ul apare instant linia ghidaj către următorul obiectiv…
trebuie să îl pună să stea până când tot driftwood-ul este gata plank"*, *„când te duci la un obiect
vreau să existe opțiunea de upgrade, nu doar de la click"*, *„nu dispare partea neagră decât după al
doilea click"*, *„când prind net-urile sunetul devine enervant"*, *„o muzică instrumentală specifică
temei, fără copyright"*. Alese de owner: muzica compusă de noi, cartea după prima vânzare, recompensele
în perle, prima colectare = plasa plină, care prima dată se umple mai repede.

1. **Bucla se face de-adevăratelea înainte de extindere.** Capitolul 1 cere o plasă plină colectată
   (12), tăiată toată și vândută toată, apoi un nivel, a doua plasă, **Sell 40 planks**, abia apoi a
   treia plasă și oamenii. Quest-urile numără **bucăți** (`Stats.collected`, `Stats.sold`), nu gesturi.
2. **Toate recompensele quest-urilor sunt perle.** Primele cinci dădeau 95 de monede, cât plasele 2 și
   3 — se cumpărau din recompense, fără ca lemnul să treacă prin lanț. Simulatorul n-a numărat niciodată
   recompensele, deci prețurile rămân; se schimbă doar ritmul real al începutului (a doua plasă pe la
   ~1:25, din vânzare).
3. **Prima plasă se umple de 3 ori mai repede** până la primii 12 bușteni colectați (~12 s, nu ~36 s),
   cu eticheta „Fast first catch" pe ea: meniul arată ritmul normal, eticheta spune de ce e mai repede.
   **Și se golește abia plină** (completat după Studio, aceeași zi: *„zice wait dar eu pot să iau și să
   fug mai departe, ar trebui să fie locked până face 12/12"*): serverul refuză colectarea, cardul scrie
   „Filling up: 8/12", E pe el spune același lucru (`TycoonMath.collectLocked`).
4. **Ghidajul pe două niveluri:** quest-ul spune ce (linia NEXT), pasul spune cum și unde, din stare, în
   ordinea în care nu sare nimic: bușteni în traistă → gater; bușteni la gater fără Sawyer → **stai în
   inel până la ultimul**; scânduri gata → le iei; scânduri în traistă → taverna; depozit → plase. Un
   quest de cumpărare **fără bani** arată bucla care face banii (sau „Coins are coming in" cât se scurge
   grămada), nu platforma.
5. **Tutorialul:** cardul capitolului → mâna la prima plasă; **cartea cu reflector vine după prima
   vânzare**, când ai ce revendica, și se închide dintr-un singur click (pasul vechi verifica lista
   deschisă abia după un click pe întuneric).
6. **Cardul obiectului:** lângă plasă, depozit, gater, tavernă, atelier sau o platformă de meserie, un
   card arată acțiunea care e cazul (sau starea) și **Upgrade**, care deschide meniul obiectului (tasta
   U; butonul apare după prima vânzare și pulsează când pasul îl cere). Ținta e cea mai apropiată —
   cartonașul de cumpărare inclus — și E face exact ce scrie pe card. Cât tai de mână, gaterul nu oferă
   scândurile: plăcuța din D50 spune „Cutting — N left".
7. **Stropii plaselor** doar la cel mult 420 px de plasa care a prins; clinchetul găsirilor rare se
   aude oricum, mai încet de departe.
8. **Muzica:** o buclă de 2:17 compusă și sintetizată de noi (`scripts/audio/make_music.py`: lăută,
   fluier de lemn, pad, contrabas, kalimba, apă; re major, 84 BPM), fără drepturi de autor ale altcuiva;
   buton în bară (tasta M), ținut minte în profil (`Settings.music`, remote `SetMusic`).

**Găsite pe drum și reparate:** (a) canalul de analytics al quest-urilor trimitea „Quest_<id>" într-un
canal unde nu exista asemenea pas — fiecare revendicare era aruncată; acum quest-urile au canalul lor, pe
capitol; (b) `Apply` al tutorialului intra în „done" la prima plasă și nu mai ieșea; (c) un buton de
muzică fără muzică urcată ar fi mințit — nu apare până nu există piesa.

**Se abate** de la D50 pct. 3 (ghidajul care arăta direct ținta quest-ului) și de la vechea ordine a
tutorialului (cartea la început).

---

## D50 — Harta în buclă, taverna, dâra de ghidaj, sunetul
**DECIS** (2026-09-13) — owner-ul, după ce a jucat D49: *„la sawmill nu prea se vede textul că trebuie
să stai aici"*, *„la tutorial vreau o săgeată care să ghideze playerul pe unde trebuie să o ia și unde
trebuie să se ducă"*, *„trebuie schimbată iar poziționarea tuturor obiectelor… devin tot mai
aglomerate"*, *„dock-ul să arate complet altfel… o tavernă în care stau degeaba niște npc-uri «ca la
piață»"*, *„sunetul sawmill-ului devine foarte enervant… predominant când se prinde driftwood-ul în
nets"*.

1. **Harta e o buclă:** plasele pe râu → depozitul la capătul de est al punții → gaterul la sud-est →
   taverna la vest, fiecare om pe drumul lui (Collector pe punte, Porter pe drumul de est, Hauler pe
   drumul de sud și pintenul de vest). Drumurile sunt `TycoonConfig.ROADS`: dreptunghiuri care doar
   se ating. Terenul Erei 1 se lărgește până la x 1860 și coboară până la y 1650; gardul Morii ține
   toată înălțimea. Grămezile au locuri fixe (`PILES`), nu formule lipite de clădire.
2. **Oamenii merg pe drumuri** (`RoadGraph` + `HandMath.cycle` cu `via`). Cât duce un om pe drum rămâne
   debit × durată, deci meniul și simulatorul nu se schimbă. Măsurat: Collector 22 s cu cinci plase
   (poarta: 30 s), Porter 7.5 s, Hauler 19.2 s.
3. **Dâra de ghidaj:** săgeți care curg pe drumuri spre țintă, plus săgeata mare (34 → 48 px) și un inel
   pe țintă. **Imediat, și doar până ai câte un om la fiecare meserie** — apoi ghidajul tace. Iarba
   costă dublu: drumul se ia doar când scurtătura peste iarbă ar fi mai mult de jumătate din el
   (altfel primul pas al tutorialului, spawn → prima plasă, 311 px, cobora la drumul mare și urca
   înapoi, 826 px). Ținta e locul unde stai: stâlpul plasei, inelul gaterului, ușa tavernei.
4. **La gater, locul tău are un inel pe jos și o plăcuță** — auriu „Stand here to cut" cât sunt bușteni
   și nu ești acolo, verde „Cutting — N left" cât stai și taie — cât timp n-ai Sawyer.
5. **Debarcaderul devine taverna** (`prop_tavern`, 192×144): în joc *Tavern* și *Innkeeper*; id-urile
   rămân (`dock`, `dock_trader`, `trader`). **Clienții vin după vânzarea reală** — o fereastră de 20 s
   peste evenimentele `Sold`, 1 + bucăți/s, cel mult 8 — nu după capacitatea tavernei, care ar fi
   desenat clienți și fără nicio scândură [D40]. La fiecare vânzare unul pleacă ducând o scândură.
   Poartă ținute noi, fără pălărie (`Townsfolk`, `Traveler`): ținuta e meseria [D44]. Pontonul cu
   barca a rămas pe punte.
6. **Sunetul:** volum pe sunet (stropul și clinchetul găsirilor 0.7, casa de marcat și monedele 0.3,
   gaterul 0.12); gaterul se aude doar la cel mult 300 px și cel mult o dată la 4 s; predarea unui om
   nu mai sună a bani.

**De știut:** drumul tău de mână (prima plasă → gater → tavernă) crește de la 5.6 s la 7.8 s de mers.
Economia nu se schimbă (simulatorul: aceleași 279 de cumpărături, 27m05s reali); dacă se simte lung
în Studio, se strânge bucla, nu se ating prețurile.

**Găsite pe drum și reparate:** (a) `HandDelivered` suna casa de marcat la fiecare predare — bani care
nu existau [D40]; (b) „sack empty" ar fi apărut la fiecare trecere pe lângă ușa tavernei, acum lângă
drumul mare — acum doar chiar la ușă; (c) între două plase de pe punte, drumul cobora 2 px până la
linia de mijloc și urca înapoi — acum, cu ambele capete pe același drum, merge drept.

**Se abate** de la D49 pct. 2 (gaterul la mijloc sub alee, depozitul sub prima plasă): se schimbă
locurile, nu lanțul.

---

## D49 — Lanțul pe oameni: depozit, gater departe, cărăuși
**DECIS** (2026-09-13) — owner-ul, după ce a jucat D48: *„sawmill-ul este prea aproape de nets"* și
*„nu îmi place că se duce wood-ul prelucrat direct la vânzare, strică tot progresul cu transport"*.

1. **Fiecare pas e muncă de om.** Lanțul are șase verigi, venitul e minimul lor:
   `plase ─[Collector]─► DEPOZIT ─[Porter]─► GATER (Sawyer) ─[Hauler]─► DEBARCADER (Negustor) ─► monede`.
   Ce pas n-are om îl faci tu, iar timpul tău se împarte între pașii rămași — de aceea fiecare
   angajare grăbește tot, nu doar pasul ei. **Tăiatul de mână = stai lângă gater.**
2. **Gaterul se mută la mijloc, sub alee**, cu o potecă pe lângă el până într-o curte în fața ușii;
   **depozitul ia locul lui, sub prima plasă.** Nimic nu mai trece singur spre vânzare: debarcaderul
   primește doar ce e tăiat, adus de tine sau de Hauler.
3. **Oamenii au trepte (1–5), nu niveluri fără capăt**, și **al doilea om** pe aceeași meserie de la
   treapta 3 — *„nu foarte multe, pentru că se presupune că sunt oameni"*. Clădirile își păstrează
   nivelurile fără capăt. Un echipaj la maxim care e veriga slabă trimite la clopot, nu la „No gain yet".
4. **Angajările vin în ordinea râului**: Collector (la 2 plase) → Porter → Sawyer → Hauler; Negustorul
   separat (3 plase). **Venitul pasiv cere acum toate cinci meseriile.**
5. **Veriga „Carry" cu niveluri dispare.** Monedele plătite pe ea se dau înapoi o singură dată, la
   migrarea v5 — nimic nu se pierde.

**Constantele, măsurate în simulator** (`--robust`: fiecare ±15%, toate porțile țin): timpul tău
**3.6** (în D48 căratul tău era 1.2 — împărțit la patru pași, tu erai veriga slabă din prima secundă
și 24 din 27 de cumpărături din primele 5 minute nu dădeau nimic), meseriile **4 / 6 / 9** (egale,
stăteau la egalitate și o treaptă pe una singură dădea zero), treapta **×1 pe pas**, gaterul **2.4**
(la 3.6 era gâtuire 3% din timp). **Era 1: 27m05s reali** (de la 31m35s), clopotul tot 10K; gâtuirea:
plase 23% · adunat 24% · dus la gater 12% · tăiat 20% · dus la debarcader 10% · vânzare 12%.
Jucătorul simulat **urmează quest-urile** în două locuri (nivelul 2 al ultimei plase; strânge pentru
deblocarea următoare când veriga slabă n-are ce cumpăra) — fără ele porțile măsurau artefacte.

**Id-urile rămân:** `first_runner` e platforma Collector-ului (id-ul e și cheia omului în profil și
sămânța numelui lui), `hire_hand` e quest-ul Collector-ului — un quest redenumit s-ar fi putut
revendica a doua oară. Noi: `hire_porter`, `hire_hauler`, quest-urile `saw_once`, `hire_porter`,
`hire_hauler`.

**Găsite pe drum și reparate:** (a) grămezile erau liste cu un tabel pe bucată — un Collector fără
Porter ar fi umflat profilul peste limita DataStore (4 MB); acum sunt numărători, fără plafon;
(b) o plasă de nivel mare își umplea cele 12 locuri în 2 s și stătea plină — prinderea reală era mult
sub cifra din meniu; acum ține ~30 s de prindere; (c) `RateLimiter` lăsa să treacă orice nume de
bucket necunoscut, iar `SpinWheel` împrumuta bucket-ul lui `SellSack`, care a dispărut; acum un nume
necunoscut e refuzat și se aude; (d) ghidajul trimitea încă la debarcader traista cu bușteni, deși
din D48 predarea era la gater; acum bușteni → gater, scânduri → debarcader.

**Se abate** de la D48 (predarea la gater, scândurile singure spre debarcader, gaterul lângă plase,
veriga de cărat cu niveluri) și merge mai departe cu abaterea de la regula de fază.

---

## D48 — Gaterul intră în lanțul Erei 1 · meniul de niveluri e al obiectului
**DECIS** (2026-09-12) — owner-ul, după o sesiune în Studio.

1. **Buștenii nu se mai vând bruți.** Lanțul are patru verigi: *prinderea → căratul → tăiatul →
   vânzarea*, iar venitul e minimul lor. Gaterul există **de la început**, între punte și alee, la
   dreapta debarcaderului; **acolo se predă traista** (E), acolo predau și Mâinile, iar debarcaderul
   primește doar ce iese din gater. Driftwood-ul iese **scânduri**; restul trece neschimbat.
2. **Scândura valorează cât buștenul.** Gaterul fiind acolo din secunda 0, un ×3 n-ar fi schimbat
   ritmul — ar fi umflat doar cifrele și ar fi stricat tot ce e fix în monede (costuri de nivel,
   recompense, premiile roții). Valoarea lui e veriga nouă de urcat, omul ei și transformarea
   vizibilă. Un multiplicator de valoare se proiectează când se re-derivă Era 2.
3. **Sawyer**: fără el gaterul merge la **35%** (manivela din §G), cu el la 100% și și când lipsești —
   oglinda Negustorului. **Venitul pasiv cere acum Mână + Sawyer + Negustor.**
4. **Meniul de niveluri e al obiectului atins** (plasa, gaterul, debarcaderul, omul angajat, `Go!` la
   un quest de nivel): lanțul sus, cu obiectul evidențiat și veriga slabă marcată; nivelul; debitul
   acum → la nivelul următor; de ce merge la 35%; dacă un nivel ajută acum. Lista cu toate stațiile
   iese din bara de meniu și rămâne **ascunsă pe tasta U** — owner-ul decide mai târziu ce face cu ea.
5. **Se abate de la regula de fază** (`TYCOON.md:586`): gaterul era proiectat pentru Era 2, iar poarta F1
   nu e trecută. Consecința concretă: bucla pe care o măsoară F1 are patru verigi, nu trei. Decizia
   owner-ului, cunoscând asta.

**Ce a mutat simulatorul:** Era 1 de la 27m43s la **31m35s** reali (costul real al unei verigi în plus);
prețurile rămân, cu excepția lui Third Net (50 → 55) și a Sawyer-ului nou (50). Sawyer-ul **nu urcă
scara de așteptare** (`LADDER_EXEMPT`): numărat ca treaptă, făcea fiecare deblocare de după el cu 17%
mai scumpă și Era 1 ajungea la 34m31s fără ca designul să ceară asta. Gaterul e gâtuirea ~15% din timp —
nu e decor; simulatorul pică dacă vreo verigă nu e niciodată gâtuirea.

**Găsite pe drum și reparate:** (a) `StationService` număra Negustorul ca Mână care cară — căratul afișat
era umflat față de simulator, iar Negustorul singur dădea venit pasiv fără nicio Mână, contra D46;
(b) tastele din bara de meniu nu erau legate nicăieri, deși tooltip-urile le afișau („Quests (J)"), iar
atelierul avea tasta W — a mersului; acum sunt legate, atelierul e pe R; (c) „First sale" apare acum
odată cu primii bani, nu la predare.

---

## D47 — Obiectul din lume e interfața: se cumpără cu confirmare, se urcă atingându-l
**DECIS** (2026-09-12) — owner-ul, după o sesiune în Studio.

1. **Nimic nu se mai cumpără călcând pe obiect.** Apropierea (sub 220px) aduce un cartonaș care
   spune *ce* cumperi (`BUY`, numele, ce face), *cât* costă și **cât îți rămâne** (`343 → 330 left`).
   Cumpărarea cere o apăsare: butonul cartonașului, tasta E sau obiectul însuși — toate trei merg
   **doar** cât cartonașul arată acel obiect. Owner: *„nu aș vrea să mai avem chestia asta cu doar
   du-te în acel obiect și se deblochează"*. Mersul rămâne (D46): cartonașul apare doar în rază.
   Butonul unui obiect abia apărut pe cartonaș e viu după 0,35s, ca al doilea clic al unui
   dublu-clic să nu cumpere obiectul următor fără să-i fi văzut prețul.
2. **Un obiect cumpărat, atins, își deschide nivelul.** Plasa (și insigna ei `Lv N`), debarcaderul,
   alergătorul și Negustorul deschid panoul de niveluri direct pe rândul lor; `Go!` la un quest de
   nivel face la fel. Owner: *„nu am văzut opțiune de upgrade la următorul nivel pe nicăieri"* —
   panoul exista, dar singura cale spre el era un buton din bara de meniu.
3. **Plasa următoare cere ca cea dinainte să fie la nivelul 2** (`TycoonConfig.PREV_NET_LEVEL`), până
   la ultima plasă. Motivul: lumea oferea plasa a doua în timp ce quest-ul cerea încă nivelul 5 al
   primei. Consecință obligatorie: **înaintea fiecărei plase noi e un quest „Upgrade … to level 2"**
   (`net_two`, `second_two`, `third_two`, `fourth_two`) — fără ele banda ar fi cerut o plasă încă
   încuiată. Aceeași cifră stă în simulator, în config și în quest-uri; testele le țin împreună.
4. **Simulatorul verifică acum prețurile din `TycoonConfig.luau`** și pică dacă diferă. Până aici,
   testul „prețurile sunt exact cele din simulator" compara config-ul cu o listă scrisă de mână, iar
   config-ul rămăsese cu 2500 / 2800 / 13000 în timp ce simulatorul derivase 1500 / 1600 / 10000.

---

## D46 — Era 1 pe structura Idle Miner: stații cu niveluri, lanț cu gâtuire, roată zilnică
**DECIS** (2026-09-12) — owner-ul a jucat Idle Miner Tycoon, a trimis 18 capturi progresive și a
cerut explicit bucla și ghidajul lor, cu NPC-urile noastre. Era 1 se face ca **șablon**; Era 2 e
aceeași structură cu alte cifre.

**Ce se schimbă față de D45:**
1. **Era 1 nu mai e o linie de 12 platforme.** Sunt **10 deblocări** + **trei tipuri de stație cu
   niveluri infinite** (plasele, căratul, debarcaderul). Fiecare nivel dă puțin (+3…6% din bază),
   iar la nivelurile 10/25/50/100 se dublează. `Sorting Crate` și `Dock Stall` au devenit niveluri
   ale debarcaderului; `Weighted Nets` a devenit pragul de nivel 10 al plaselor.
2. **Venitul nu mai e o sumă, e minimul a trei debite** — prinderea, căratul, vânzarea. Veriga cea
   mai slabă decide, iar repararea ei e decizia jucătorului.
3. **Regula celor patru motive se rescrie** pentru modelul cu gâtuire: *orice cumpărătură trebuie
   să crească venitul **atunci când țintește veriga slabă**, și niciodată nu-l scade.* Un upgrade
   pe o verigă care nu e gâtuirea dă **exact zero** — asta nu e un bug, e lecția jocului, și se
   scrie pe ecran în loc să se inventeze o cifră frumoasă [D40].
4. **Două monede**: monede (din vânzare) și **perle** (premium). Perlele se cheltuie pe viteză,
   spațiu și aspect — niciodată pe putere, deci P4 rămâne intact **pe monedă**.
5. **Roata norocului intră în joc**, cu premii aleatorii. Asta **restrânge P4**: de la „niciodată
   noroc" la **„niciodată noroc care scade ceva ce ai"**. Limitele care rămân:
   - niciun premiu nu ia nimic — toate sunt în plus [P2 intact];
   - rotirea e **gratuită**, una la 24h. Rotiri cumpărate **nu** intră: D20 spune „zero paid random
     items", iar obiectele aleatorii plătite au reguli proprii de dezvăluire pe Roblox;
   - **șansele se afișează**, și sunt calculate din chiar ponderile folosite la tragere [D40].
6. **Venitul pasiv se câștigă.** Cere **și** o Mână care cară **și** un Negustor care vinde — cu una
   singură lanțul e tăiat. Pastila `IDLE` din HUD apare abia atunci; înainte nu există.
7. **Ghidajul**: capitole + listă de quest-uri + banner permanent + tutorial cu reflector. Progresul
   quest-urilor se **citește din stare**, nu se numără pe evenimente — clasa de bug „am făcut deja,
   dar nu s-a bifat" devine imposibilă.

Rămân în vigoare, neatinse: P1, P2 (nimic nu se pierde), P3, P5, P6, D40 (textul nu minte),
D43 (nimic în tăcere), D44, D20 (fără pay-to-win, fără obiecte aleatorii plătite), D13.

---

## A. Platformă, cont, mediu

### D01 — Proprietate și conturi · DECIS
- **[2026-09-15] Fără grup, deocamdată** — owner-ul, după reverificarea de mai jos: *„da, renunțăm"*. Pentru un proiect
  solo contul personal publică ambele universuri, încasează și face DevEx, iar formularul fiscal e oricum pe persoană
  fizică; un grup ar fi adus acum doar 100 Robux, împărțirea celor ~180 de asset-uri și o cheie API nouă. Jocurile se mută
  gratuit pe un grup (Community) când apare un colaborator plătit sau o pagină pentru jucători. Punctul de mai jos e istoric.
- Experiențele sunt deținute de un **Grup Roblox** „Driftwood" (100 Robux, o singură dată), nu de contul personal. Motiv: transfer ulterior al unei experiențe către grup cere re-upload manual al ModuleScript-urilor private și al asset-urilor; grupul e și condiția pentru colaboratori plătiți și DevEx din fonduri de grup. [sprites-assets, legal-ip-tax]
- **2FA + verificare de identitate** pe contul owner din prima săptămână. Din 19 mai 2026 publicarea pentru toate vârstele (tier 3, care include conturile Roblox Kids/Select) cere ID + 2FA + abonament Roblox Plus activ sau taxă unică rambursabilă de 1.000 Robux/joc. Verificarea de ID mai deblochează: 2.000 vs 100 upload-uri audio/30 zile, Team Create Collaborate, DevEx. [studio-mac, audio]
- **Două universuri** separate: `Driftwood-Staging` și `Driftwood` (producție), fiecare cu DataStore-uri izolate. Pattern-ul oficial din `Roblox/place-ci-cd-demo`. [open-cloud-cicd]
- Formular fiscal **W-8BEN** depus în Creator Hub înainte de **31 octombrie 2026**: de la 1 noiembrie 2026 DevEx e reclasificat ca royalty, cu reținere la sursă 24% dacă lipsește formularul. [legal-ip-tax]
- **[Reverificat 2026-09-15, pe sursele oficiale]** Motivul de mai sus pentru grup nu mai stă în picioare: din decembrie 2024
  un joc se mută gratuit de pe cont pe grup (Creator Hub → Configure → Settings → *Initiate ownership transfer*), cu același
  ID de joc și de place; nu se poate întoarce pe cont, iar după primire trebuie 30 de zile până la o nouă mutare. Rămâne
  motivul colaboratorilor și al plăților. Apare însă altceva: din 5 mai 2026, conturile și grupurile noi au imaginile
  „Restricted" implicit, deci un joc al grupului folosește imaginile și sunetele urcate de pe cont doar după ce le sunt
  împărțite (Asset Manager în Studio, sau API-ul Open Cloud de permisiuni, în beta). Grupurile se numesc acum
  „Communities" (100 Robux). Publicarea pentru copiii sub 16 cere, pentru jocurile grupului, ca **owner-ul** să aibă ID,
  2FA, chestionarul de maturitate și fie taxa de 1.000 Robux per joc (returnată după 90 de zile), fie Roblox Plus sau
  Premium activ de cel puțin 2 luni; jocul pornește la 16+ și trece la copii după 250 de jucători implicați în 60 de zile.
  Taxele se depun din Creator Hub → Finances → Taxes; în tabelul IRS (Table 1), România are 10% la redevențele de
  copyright și 15% la cele industriale, doar pe partea din jucătorii din SUA. **Pe contul owner-ului pagina Taxes nu apare**
  (verificat de el pe 2026-09-15, cu 0 Robux câștigați; „Account information" din Finances e doar pentru facturi la
  servicii de business, nu pentru reținerea DevEx). Formularul se depune când apare pagina, înainte de primul cash-out
  (minimum 30.000 Robux) — până atunci nu există nicio plată DevEx căreia să i se aplice reținerea.

### D02 — Roblox Studio pe Mac · DECIS
- Se instalează build-ul **nativ Apple Silicon** (installer-ul public livrează build Intel sub Rosetta); se verifică în Activity Monitor coloana Kind = Apple. [studio-mac]
- Mașina de dezvoltare rămâne pe **macOS stabil**, nu beta: crash-urile documentate pe DevForum sunt concentrate pe macOS 26 beta și 27 beta. [studio-mac]
- „Enable Studio Access to API Services" doar pe place-ul de staging, niciodată pe producție. [studio-mac]
- Device Emulator (Test → Device) e parte din bucla zilnică din prototip, nu din faza de polish, pentru că 100% din joc e UI. [studio-mac, mobile-console]

### D03 — Limbă și localizare · DECIS
- Jocul se scrie **în engleză**. Traducerea automată Roblox acoperă 17 limbi și **nu include româna**. Româna se adaugă printr-un tabel de localizare manual când există trafic RO. [onboarding-ftue]

---

## B. Randare și UI

### D04 — Randare 2D pură în ScreenGui · DECIS
- Se rămâne pe ScreenGui pur, conform brief-ului. Argumente confirmate: determinism server-autoritar fără fizică, input simplu, comportament identic pe orice dispozitiv, fără StreamingEnabled, fără riscul ruperii camerei la GraphicsQuality ≤ 3. [alt-2-5d, screengui-2d-feasibility]
- Workspace gol, `Players.CharacterAutoLoads = false`, cameră Scriptable fixă, skybox uniform, `StarterGui:SetCoreGuiEnabled(All, false)`. Topbar-ul **nu** se dezactivează (acces la Report; risc de conformitate neverificat). [screengui-2d-feasibility]
- **Nu** se folosește EditableImage ca renderer: un singur EditableImage se actualizează pe frame, limită 1024×1024, cerință de ID verificat. [ui-performance]
- **Nu** se folosesc ParticleEmitter/Beam/Trail (nu se pot parenta pe GuiObject); efectele 2D sunt un pool de ImageLabel. [juice-effects, alt-2-5d]
- Condiții de reversare la 2.5D (niciuna adevărată azi): adâncime reală pe mai multe planuri Z, avatarul 3D ca identitate socială centrală, sau volum de efecte imposibil de reprodus manual. [alt-2-5d]

### D05 — Arhitectura GUI și performanță · DECIS
- **ScreenGui separate** pentru HUD static și pentru stratul dinamic (râu, plase, particule). Motorul cache-uiește aspectul la nivel de LayerCollector și invalidează tot ScreenGui-ul la orice scriere de proprietate pe orice descendent. [ui-performance]
- Pozițiile obiectelor din râu se scriu pe **`RunService.PreRender`** (RenderStepped e deprecated). Simularea logică rulează pe Heartbeat cu pas fix. [ui-performance]
- **Object pool** de 200–300 ImageLabel din pasul 1; fără `Instance.new`/`Destroy` pe calea fierbinte; ZIndex setat o dată la spawn; fără UIListLayout/UIGridLayout pe stratul râului; culling manual (nu există `VisibleOnScreen`). [ui-performance, screengui-2d-feasibility]
- CanvasGroup doar pe panouri statice (fereastra de reparații), niciodată pe râu. [ui-performance]
- **Test 2026-09-09 (desktop, Studio, M-series):** pool de 400 Frame-uri actualizat pe PreRender cu `DebugSpawnsPerWindow = 800`, fără lag perceptibil; rămâne DE VERIFICAT pe Android 2–4 GB după publicare.
- Buget de performanță (ipoteză de proiectare, de măsurat în prototip cu MicroProfiler Cmd+Opt+F6): 60 fps desktop, **30 fps prag minim pe Android low-end (2–4 GB RAM)**, ≤ 200 obiecte active pe râu în regim normal, plafon dur 400 obiecte vizibile la Inundație (restul se agregă vizual). [ui-performance, mobile-console]

### D06 — Coordonate, scalare, ecrane · DECIS
- Rezoluție de referință logică **1920×1080 landscape**. Pozițiile lumii în Offset (pixeli logici); un singur `UIScale` global = `min(viewport.X/1920, viewport.Y/1080)`, recalculat la `ViewportSize` changed. [screengui-2d-feasibility]
- `ScreenGui.IgnoreGuiInset = true` pe toate ScreenGui-urile de joc; `ScreenInsets = CoreUISafeInsets` pe HUD; insetul topbar-ului se citește dinamic din `GuiService:GetGuiInset()`, nu se hardcodează (s-a schimbat în 2024). [screengui-2d-feasibility, mobile-console]
- Dispozitive-țintă de test: iPhone cu notch (844×390), Android low-end (Infinix Smart 9 / Moto G05 clasă), desktop 1920×1080, iPad. Ținte tactile minime 44 pt la scara reală (≈ 100 px la referință). [mobile-console]
- Console: **nu la lansare** (≈ 3% din sesiuni), dar `Selectable` + `NextSelectionUp/Down/Left/Right` se setează pe fiecare control din HUD v1, ca să nu fie retrofit. [mobile-console, input-2d]

### D07 — Input · DECIS (revizuit 2026-09-09)
- **Revizuire (owner, 2026-09-09):** jocul are un **personaj 2D pe mal**, ca în inspirația Stardew: mers stânga-dreapta (A/D, săgeți; două butoane pe ecran la mobil), cameră care urmărește personajul pe o bandă orizontală (terenul = 2 ecrane, 3.840 px logici; orașul continuă la pasul 5 cu ≈ 20 de ecrane și chioșc de teleport). Interacțiunea e **prin apropiere**: lângă un slot liber → „Place net" (E / buton), lângă o plasă cu conținut → „Collect". Poziția personajului e strict client-side și nu influențează economia. Drag-and-drop-ul cu `UIDragDetector` a fost implementat și testat, apoi înlocuit; rămâne opțiune pentru inventar/atelier.
- Plasarea plaselor (varianta inițială, înlocuită): **`UIDragDetector`** (DragStyle TranslatePlane, BoundingBehavior EntireObject, `AddConstraintFunction` pentru snap la slot), validare finală pe server la DragEnd. [input-2d]
- Toate butoanele: `GuiButton.Activated` (uniform mouse/touch/gamepad), nu `MouseButton1Click`. [input-2d]
- `GuiService.PreferredTransparency / PreferredTextSize / ReducedMotionEnabled` se citesc la login și se respectă; toggle „reduce motion" propriu pentru screen shake și flash-uri. [input-2d, juice-effects]
- Fără pan/zoom în v1: terenul jucătorului încape pe ecran; orașul se vede ca bandă derulabilă orizontal cu butoane, nu cu gesturi libere. [input-2d]

### D08 — Styling și efecte · PROVIZORIU
- UI Styling API (`StyleSheet/StyleRule`, Full Release 20 ianuarie 2026) se adoptă de la **vertical slice**, nu de la prototip: owner-ul învață întâi Frame/UDim2 clasic. [platform-2025-2026-features]
- Animații: `TweenService` nativ în prototip; Ripple (activ, iulie 2026) doar dacă apare nevoia de spring-uri; Flipper e abandonat din 2021. [juice-effects]
- Apa: `ScaleType.Tile` + `TileSize` într-un Frame cu ClipsDescendants, derulată prin Position; `ImageRectOffset` e incompatibil cu Tile. [juice-effects, sprites-assets]

---

## C. Toolchain și cod

### D09 — Toolchain · DECIS
- **Rokit** (Aftman e arhivat), cu versiuni fixate în `rokit.toml`: `rojo 7.7.0`, `stylua 2.5.2`, `selene 0.31.0`, `wally 0.3.2`, `lune 0.10.5`, `zap` (când se adoptă, vezi D11). `luau-lsp` v1.69 în VS Code (Marketplace) sau Cursor (Open VSX). [toolchain-rojo, local-testing]
- **UI construit din cod**, nu din `.rbxmx` sincronizate din Studio: Rojo nu are sync bidirecțional live (doar `rojo syncback` manual). Orice editare directă în Studio se pierde. [toolchain-rojo]
- Extensia `.luau` peste tot; `--!strict` explicit pe fiecare modul (din 20 noiembrie 2025 default-ul e nonstrict); interzise `wait/spawn/delay` legacy, doar `task.*`. [luau-language]
- Pattern de cod: Service (server) / Controller (client) ca ModuleScript singleton, cu `Init(deps)` explicit dintr-un bootstrap; module de logică pură în `src/Shared/` fără `game`/`os.time` în interior (primesc timpul ca parametru) — condiție pentru teste fără Studio. [luau-language, local-testing]

### D10 vezi secțiunea D — modelul orașului (mutat acolo pentru că e decizie de produs).

### D11 — Librării · DECIS
- Persistență: **ProfileStore 1.0.3** (ProfileService e deprecat oficial de autor). [datastore-deep, frameworks-2026]
- Semnale și cleanup: **RbxUtil** (Trove + Signal). [frameworks-2026]
- Networking: prototipul (pasul 1) folosește **RemoteEvent brut** printr-un wrapper `Net` de 3 remote-uri; de la pasul 2 se adoptă **Zap 0.6.x** (tipat, buffer-packed; Red e arhivat, Blink e pre-1.0). [frameworks-2026]
- **Nu**: Knit (arhivat), Roact (arhivat), Matter/jecs (ECS, supra-inginerie pentru Frame-uri), roblox-ts (fricțiune pentru un începător pe Roblox), react-lua (fără commit din mai 2025). Vide rămâne opțiune pentru chrome UI după vertical slice. [frameworks-2026]
- Configurare live și feature flags: **ConfigService** (lansat 24 august 2026; propagare 15 s–1 min), nu un sistem propriu pe DataStore. [seasons-liveops, analytics-testing]

### D12 — Testare și CI · DECIS
- Teste unitare pe module pure cu **Lune + frktest** (`lune run tests/_run.luau`); TestEZ e arhivat din 14 septembrie 2024, Jest-Lua nu rulează în Lune. [local-testing]
- GitHub Actions pe `ubuntu-latest`: `stylua --check` → `selene` → teste Lune → `rojo build` → `rojo upload` pe staging. Promovarea la producție e manuală (workflow_dispatch). Fără `run-in-roblox` (cere Studio + cookie .ROBLOSECURITY în CI). [open-cloud-cicd, local-testing]
- Open Cloud Luau Execution API doar pentru câteva smoke-tests pe staging, presupunând limita conservatoare de 2 task-uri concurente (sursele se contrazic: 2 vs 10). [local-testing, open-cloud-cicd]
- Fiecare `.rbxl` publicat se păstrează ca artifact GitHub etichetat cu `versionNumber`: rollback-ul din Version History nu republică automat și nu oprește serverele pornite. [open-cloud-cicd, seasons-liveops]

---

## D. Arhitectură de joc

### D13 — Server-autoritar și simularea râului · DECIS
- Serverul e singura sursă de adevăr pentru economie. Clientul trimite doar intenții (`PlaceNet`, `Collect`, `StartRepair`, `Donate`, `SecureItem`). [server-authoritative, anti-exploit]
- **Râul e determinist pe seed**: serverul publică o dată `{seed, seasonParams, windowStart}`; clientul derivă pozițiile local din `Random.new(seed)` și le randează; **prinderea se decide exclusiv pe server**, care rulează aceeași simulare la 10 Hz. Nu se replică obiectele individual (bandwidth ≈ 0 în regim normal). [server-authoritative]
- Validare pe fiecare remote: tip, `math.isfinite`, ownership, stare curentă, cooldown cu timestamp server, anti-duplicare; **token bucket** (implementarea oficială Roblox) per tip de remote; throttle-ul motorului e ≈ 500 req/s per client, deci cooldown-urile de design sunt cu ordine de mărime mai stricte. [server-authoritative, anti-exploit]
- Anti-exploit la lansare: 2 honeypot remotes (log + kick), scor de suspiciune (rate-of-gain, cadență), `Players:BanAsync` cu durată finită la primul incident; **fără** anti-cheat client-side; **fără** Server Authority (feature-ul din iulie 2026 e pentru fizică 3D). Hyperion e confirmat doar pe Windows, deci Mac și mobil sunt mediile unde validarea server contează cel mai mult. [anti-exploit]

### D14 — Date de jucător · DECIS
- Un singur profil ProfileStore per jucător, `PROFILE_TEMPLATE` versionat + `Reconcile()` la fiecare load. Autosave la **120 s** (cheie ConfigService, default ProfileStore e 300 s) + `PlayerRemoving` + `BindToClose` cu salvări paralelizate (`task.spawn` per jucător, buget 30 s pe tot serverul). [datastore-deep, server-authoritative]
- Timpul se stochează **absolut** (`finishAt`, `lastCollectedAt`), niciodată ca „timp rămas". [offline-progress]
- Idempotență pentru cumpărături: `PurchaseId` scris în profil înainte de `PurchaseGranted`. [monetization-impl]
- Ștergere GDPR: toate datele unui jucător stau sub o singură cheie (profil) + intrări în ledger-ul orașului anonimizabile; runbook-ul rulează la notificarea din Deletion Queue. [policy-compliance]
- Limite reținute: 4 MB/cheie; bugete per experiență (citire 300+40×CCU/min, scriere 300+20×CCU/min) **și** per server (60+40×jucători/min) coexistă; 4 MB/min scriere per cheie. [datastore-deep, cross-server]

### D10 — Modelul orașului comun · PROVIZORIU (spike la pasul 5)
Problema: Roblox nu are servere persistente. „Tot serverul împarte același oraș" din brief nu poate însemna literal instanța de server (progresul s-ar pierde la fiecare reciclare). [cross-server, shared-progress-persistence, community-progression]

Decizie: **orașe persistente, de dimensiune fixă, pe reserved servers, cu un lobby de rutare.**
- Un **oraș** = o înregistrare în DataStore (`towns/<TownId>`) + un cod de reserved server (`ReserveServerAsync`) salvat în aceeași înregistrare. Un oraș e găzduit de **cel mult un server** la un moment dat, deci cheia lui are un singur scriitor: dispare problema hot-key și contenția UpdateAsync.
- **Place-ul de start e un lobby minimal** (încărcare sub 3 s): jucător nou → i se atribuie orașul deschis cel mai puțin populat (MemoryStoreSortedMap `TownId → populație activă`, volum mic, N orașe nu N jucători) și e teleportat; jucător care revine → teleportat în orașul lui (`TeleportAsync` + `ReservedServerAccessCode`). Teleportul adaugă 3–8 s la join; se acoperă cu ecranul „Corabia pleacă spre <Oraș>".
- **Apartenența** e per jucător (`profile.Data.Meta.HomeTownId`), plafon 120 membri/oraș; **concurența** e plafonată de `MaxPlayers = 24` al place-ului Town. Dacă orașul e plin, jucătorul poate intra ca vizitator în alt oraș: plasele, atelierul și indexul sunt **per jucător** și funcționează oriunde; doar donațiile și zonele sunt per oraș.
- Vizitarea altor orașe și „mergi la prietenul X" sunt funcții explicite din lobby/HUD (teleport pe codul orașului), pentru că butonul Join din Roblox nu funcționează pe reserved servers.
- Starea orașului se salvează la 120 s + `BindToClose`; `MessagingService` doar pentru anunțuri opționale între orașe (livrare best-effort, nu sursă de adevăr).
- La lansare: **8–12 orașe deschise**, se deschid altele automat când media de ocupare depășește 70%.

Alternative respinse:
- (a) Un singur oraș global pentru tot jocul: diluează obligația socială (mii de donatori) și creează hot-key cu lease de leader + cache MemoryStore — complexitate mai mare pentru un rezultat de design mai slab.
- (b) Oraș per instanță de server: contrazice „permanent"; se pierde la fiecare restart.
- (c′) Servere publice care „revendică" un oraș la boot: jucătorii care revin nu pot fi rutați acasă când orașul nu e găzduit nicăieri.

De testat în spike (înainte de pasul 5): latența reală de teleport din lobby pe mobil; comportamentul reserved server la ultimul jucător care pleacă și la reintrare; `TeleportService` nu funcționează în Studio, deci place-ul Town trebuie să pornească standalone cu un „dev town" când lipsesc datele de teleport. Prototipul (pașii 1–4) rulează pe **un singur place** fără lobby.

### D15 — Progres offline · DECIS
- Plafonul principal de acumulare e **capacitatea plasei** (sloturi), nu ceasul; plasa de bază se calibrează să se umple în ≈ **8 ore** reale (cifra din brief devine țintă de tuning, nu constantă). Plafon orar back-stop de 24 h pentru plasele mari cumpărate. [offline-progress]
- `lastCollectedAt` per plasă (nu doar `lastSeen` global). Rolurile de raritate offline sunt seedate determinist din `(userId, netId, lastCollectedAt)` și seed-ul avansează doar după procesare reușită — previne farming prin reconectare. [offline-progress]
- Ecran „Bun venit înapoi" la login, cu mesaje diferite pentru „plasă plină" vs „timp atins". [offline-progress, case-top-games]
- **Experience Notifications**: opt-in cerut contextual după minutul 4 din prima sesiune (nu în primele 30 s), maxim 1 notificare/zi/utilizator, agregată („toate plasele sunt pline"), plus una cu 24 h înainte de Inundație. Eligibilitate: 100 vizite, doar 13+. Tratată ca supliment, nu ca sistem central. [offline-progress, onboarding-ftue]

### D16 — Reparat și atelier · DECIS
- Atelierul are **N sloturi de reparație** simple (nu grid tip Tetris): 3 gratuite la start, +1 prin progres (index 25%), +1 și +2 prin Game Pass. Coada „grămada nesortată" e nelimitată ca număr, dar obiectele din ea nu contează în index și nu pot fi donate — tensiunea vine din sloturi, nu din energie. [economy-balance, collection-design]
- Timpul de reparație e absolut, continuă offline, scalat pe raritate (minute → zile). Materialele vin din dezmembrarea obiectelor duplicate (sink-ul principal). [economy-balance]
- Obiectele intră în Index **doar reparate complet** — al doilea gate de ritm, care întinde completarea colecției. [collection-design]

### D45 — Driftycoon: tycoon direct, un singur număr central · DECIS (2026-09-11)
Owner-ul: *„hai să facem acest joc tycoon direct, restructurăm tot"*. Planul complet, cu dezbaterea pe
22 de arii, e în **`docs/TYCOON.md`**; aici e doar ce s-a hotărât și ce cade.

**Diagnosticul:** jocul erau două jocuri sudate — un nucleu de colecție și un simulator de colonie peste
el — fără un număr la care să contribuie toate. De aici „nu se leagă nimic de nimic".

**Ce se hotărăște:**
- **O singură monedă** (Coins) și un singur număr central: monede pe secundă.
- **Regula celor patru motive:** orice se poate cumpăra trebuie să prindă mai mult, să vândă mai scump,
  să scape de o corvoadă sau să deschidă ce urmează. Și **nicio cumpărare nu are voie să scadă venitul**
  — simulatorul (`scripts/economy/sim_tycoon.py`) oprește rularea dacă vreuna o face.
- **Prețurile se derivă din ținte de ritm**, nu se ghicesc. Prima variantă ghicită avea nouă defecte pe
  care doar modelul le-a văzut (lista în `TYCOON.md` §5).
- **Platforme fixe de cumpărare, în 4 zone** (Landing, Mill, Yard, Harbor); nu construcție liberă.
- **Coloniștii devin angajați**: fără nevoi, fără plecare, fără hrană. Arta pe straturi (D44) rămâne.
- **Renaștere liniară** (+50%/tură), cu scară de cerințe; nu atinge nimic plătit [wipes].
- **Offline pe capacitate**: producția automatizată curge într-un Seif până se umple (~8 h) [16].
- **Monetizare: viteză da, noroc niciodată** [money].

**Ce cade:** direcția de colonie din D29–D31 și regulile specifice ei din D34–D39, D42 (lanțul de
obiective, economia hranei, nevoile, plecarea, construcția liberă, povestitorul ca motor). **Rămân în
vigoare:** D43 (*nimic nu se întâmplă în tăcere*), D44 (înfățișarea pe straturi), D40 (textul nu minte),
și tot ce ține de platformă, autoritate pe server, persistență, conformitate și principiile de
monetizare din D20.

**O corectură la baza deciziei.** Pe 2026-09-11 i-am spus owner-ului că direcția de colonie *„nu are
nicio cercetare în spate"*. Era greșit: căutasem doar în `docs/research/` și ratasem
`docs/research-survival/` (31 de note, inclusiv RimWorld/Dwarf Fortress) și `docs/directions/`.
Argumentele de scop rămân valabile — un solo reușește cu o singură buclă [37] —, dar premisa aceea n-a
fost adevărată. Tot atunci ratasem că renașterea *e* cercetată ([wipes], [landscape]).

**Arhivat, nu șters** (niciun commit nu exista): `MASTERPLAN.md` și cele 19 părți ale lui, direcțiile
concurente, notele de supraviețuire din alt gen, documentele de colonie, previzualizările — în total
~203.000 de cuvinte, în `~/Desktop/Driftwood_arhiva_2026-09-11/`.

### D44 — Chipuri, nu roluri: înfățișarea în trei straturi · DECIS (2026-09-11)
Owner-ul: *„main character arată ca oricine. NPC-urile trebuie să arate diferit, nu doar în funcție
de job, ci și gender și aspect, dar să aibă ceva în common când au același job."*

Cerința e un **sistem**, nu un desen. Identitatea variază liber, meseria rămâne constantă:

| strat | conține | variază |
|---|---|---|
| corp | doar pielea | siluetă (2) × nuanță (6), prin tint |
| păr | doar părul | coafură (4) × culoare (6), prin tint |
| **ținută** | cămașă, pantaloni, **pălăria și unealta meseriei** | **nu — e semnalul de meserie** |

288 de combinații de înfățișare, la un plafon de 80 de oameni. Jucătorul primește o a șasea
ținută (`keeper`) pe care niciun colonist nu o poate avea.

**Cauza reală a problemei raportate:** jucătorul era desenat complet netonat, iar `TINTS[1]` al
coloniștilor era `{255,255,255}` — adică unul din șase coloniști era pixel-identic cu jucătorul.

**Lecție din prima etapă de generare:** stratul de păr ieșise aproape gol, fiindcă pălăria acoperă
capul. Cu pălărie la fiecare meserie, patru coafuri ar fi arătat identic. Regula corectată:
coafurile se desenează prin ce **iese pe lângă** pălărie (tâmple, ceafă, umeri), iar hangiul nu
poartă pălărie deloc, ca să existe o meserie unde coafura se vede întreagă.

**Compunerea e verificată programatic**, nu din ochi: corp + păr + ținută suprapuse trebuie să dea
exact foaia dintr-o bucată, pixel cu pixel, pe toate cele 60 de cadre. Fără proba asta, un decalaj
de un pixel ar trece nevăzut prin generator și ar apărea abia în joc.

**Pornire automată:** foile sunt declarate în `Assets` cu id 0, deci `Assets.has` dă false și
clientul rămâne pe calea de acum. Când se încarcă, se pun id-urile și sistemul pornește singur.
**Se încarcă toate sau niciuna** — foaia dintr-o bucată e acum desenată pe rampe neutre, deci
încărcată singură ar face pe toată lumea gri.

### D43 — Nimic nu se întâmplă în tăcere · DECIS (2026-09-10)
Owner-ul a jucat două minute și a găsit ceva de comentat la fiecare pas. Toate observațiile s-au
dovedit **același defect**: jocul făcea lucruri fără să spună că le face. Dialogul avansa dar nu
spunea că poate fi avansat. Clădirile se ridicau dar nu spuneau de cine. Cartonașul zicea „Open
Build" dar nu spunea unde e Build. Atelierul dădea două butoane fără să spună că sunt opuse.

**Regula, de acum:** în orice moment ecranul răspunde la „ce fac acum", și orice acțiune își arată
urmarea. Trecerea pas cu pas e în `docs/PRIMELE_CINCI_MINUTE.md` și se reface după fiecare
schimbare de onboarding.

Ce a ieșit din ea:
- **Îndemnul din dialog era ascuns exact cât se scria textul** — adică fix în secundele în care
  jucătorul se întreabă ce să facă. Acum e mereu vizibil și își schimbă mesajul: *skip* cât scrie,
  *continue* după, *close* la ultima replică.
- **Introducerea nu spunea ce e jocul.** Patru replici acum, câte una per întrebare: unde ești,
  ce e motorul lumii, **ce ești tu** („what this settlement becomes is your call"), ce faci acum.
- **Nimic nu arăta pe ce buton se apasă.** Sarcina curentă aprinde un inel pe butonul din bară.
- **„Pământul luminat" nu era luminat** — `BackgroundTransparency = 0.93`, adică 7% opacitate.
  Un indiciu care numește ceva invizibil e mai rău decât lipsa indiciului.
- **Meseriile erau cinci butoane cu câte o literă.** Acum fiecare își spune rostul, iar textele
  descriu ce face codul — dacă se schimbă o regulă, se schimbă și textul.
- **Plasa apărea din neant.** Indiciul spune acum că cele trei locuri de pe râu sunt ale tale.
- **Acțiunea n-avea urmare vizibilă.** Cifrele își arată schimbarea: „+8" plutește de la cifra
  care s-a modificat, nu într-un colț îndepărtat de ecran.
- **Un colonist dispărea după patru minute invizibile.** Starea „leaving" era ștearsă în ACELAȘI
  tick de 0,25 s în care apărea, deci clientul n-o vedea niciodată și eticheta din panou era cod
  mort. Acum serverul trimite ambele numărători, semnul de deasupra capului are trei stări
  (nemulțumit → numărătoare → „LEAVING 9s"), iar omul merge spre debarcader înainte să dispară.
  Dacă nevoia se rezolvă între timp, rămâne. Asta e regula „nimic nu se pierde fără șansă de
  reacție", aplicată la singura pierdere reală din joc.
- **Pasul „watch the water" avea până la 45 s de nimic.** Prima sosire vine acum în 12.
- **Inelele de plasă pulsau stroboscopic** — `phase = (tick() * 1.6) % 1` calculat pe cadru,
  un dinte de fierăstrău care sărea instantaneu de la ~1 la 0, sincron pe toate trei.

### D42 — Telefonul nu e un desktop mic: joystick, nu patru butoane · DECIS (2026-09-10)
**Comenzile de mișcare.** Erau patru butoane pătrate de 112 px, împrăștiate în stânga-jos. Pe un ecran de 896×414 mâncau o treime din suprafață, unul stătea peste atelier, și dădeau doar 8 direcții. Trec pe **un joystick** într-un colț: o singură comandă, direcție analogică, nu acoperă nimic din joc. Magnitudinea contează — o împingere pe jumătate merge pe jumătate din viteză; direcția se normalizează, deci diagonala nu e mai rapidă.

Deplasarea se măsoară față de **punctul în care ai atins**, nu față de centrul desenat. Două motive: nu trebuie să nimerești mijlocul cu degetul, și dispare complet nepotrivirea dintre coordonatele de input și `AbsolutePosition` sub decupajul de sus al platformei — o clasă de bug greu de prins fără să poți rula pe dispozitiv.

Butonul de acțiune devine rotund, auriu, cu pictogramă în loc de glifa „●".

**Ferestrele se strâng pe pânză.** Panourile sunt dimensionate pentru desktop, dar pânza HUD e `viewport/hudScale`: pe telefon are ~1445×668 unități logice, iar o fereastră de 700 înălțime ieșea pe sub marginea de jos — rândurile de dedesubt deveneau inaccesibile, fără niciun semn că există. Limitarea se face în `Widgets.Window`, singurul loc prin care trec toate panourile, și se reface la rotirea telefonului.

**Regula generală:** orice dimensiune fixă scrisă pentru desktop e o presupunere despre ecran. Pe telefon presupunerea cade, iar interfața nu dă niciun semnal că a căzut — pur și simplu o parte din joc dispare sub margine.

### D41 — Limbaj vizual de joc mobil de construcție, și o sondă care vede din interiorul Studio · DECIS (2026-09-10)
**Fontul.** Merriweather (D37) a fost o greșeală de gen, nu de reglaj: e un serif de ziar, iar într-un joc colorat văzut de sus citește ca „document". De-aia a fost respins de trei ori oricât l-am ajustat. Titlurile trec pe **Fredoka One**, familia rotunjită și grea în care sunt scrise jocurile mobile de construcție. Textul curent rămâne Nunito.

**Conturul e jumătate din efect**, și lipsea complet. `Theme.punch()` pune contur închis pe glife, cu grosimea proporțională cu mărimea textului. Regula: se pune **doar pe text care stă peste lume** — peste iarbă, apă, acoperișuri. Pe pergament nu: text închis conturat cu închis se îmbâcsește. Consecință practică: textul peste lume nu mai are nevoie de placă neagră sub el ca să se citească.

**Monospace rămâne monospace.** Măturarea fonturilor scrise de mână a convertit și jurnalul consolei de dezvoltare la lățime variabilă. Acolo alinierea pe coloane e funcțională, nu decor. Theme are acum un `kind` de `mono` separat.

**Apăsatul pe clădire.** Clădirile nu erau apăsabile deloc — puteai ridica una, dar nu o puteai întreba nimic, deși ești administrator. Modelul luat din jocurile mobile de construcție, cu trei reguli: cartonașul stă **lângă clădire, în lume** (nu pierzi contextul), clădirea aleasă **se vede aleasă** (inel auriu care pulsează), și **cel mult o acțiune, mare**, doar unde chiar există una. Șantierele arată progres și câți constructori sunt efectiv pe ele; terminatele arată capacitatea în cuvântul potrivit — *beds*, *seats*, *plots* — nu „slots" pentru tot. Numărul de oameni se calculează din pozițiile pe care clientul le are deja, deci scrie „cine e aici", nu „cine e repartizat".

**Toastul a plecat din zona dialogului.** Stătea jos-centru la −150 px, exact peste caseta de dialog și peste d-pad-ul de telefon, și ducea replici de personaj — deci citea ca un al doilea sistem de dialog, în formatul vechi. A trecut în treimea de sus, centrat, unde e liber la orice lățime de ecran.

**Sondă în loc de ochi.** Nu pot deschide Studio și nu pot vedea ecranul; un screenshot costă mult și oricum nu răspunde la întrebările care încurcă cel mai des. `plugins/DriftwoodProbe.lua` rulează **în** Studio și trimite un raport text la un server local (`scripts/probe_server.py`): ce familie de font s-a rezolvat efectiv pe elementele reale, dimensiunile și pozițiile la rezoluția adevărată, `TextFits` pe fiecare etichetă, și ultimele erori din consolă. Pixelii rămân pentru întrebări chiar vizuale, decupați și micșorați — capturile consumă mult.

### D40 — Textul nu mai are voie să mintă: teren, apă, grămadă · DECIS (2026-09-10)
Trei locuri unde interfața promitea un lucru și jocul făcea altul. Regula pe care o fixează decizia: **dacă un text spune ceva, jocul trebuie să facă exact acel lucru**, altfel textul se schimbă. Un indiciu fals costă mai mult decât lipsa indiciului, pentru că jucătorul învață să nu se mai uite la ele.

- **Terenul luminat era o sugestie, nu o limită.** Indiciul spunea „așeaz-o pe pământul luminat", dar `BuildService.CanPlace` accepta orice loc liber din lume. Conturul nu însemna nimic. Acum limita se verifică **pe server** (`outside_plot`) și se oglindește în fantoma de așezare din client, ca ghidajul să devină roșu exact unde serverul ar refuza. Cele două verificări trebuie să rămână identice; când diferă, jucătorul apasă pe verde și primește refuz.
- **„Watch the water" arăta spre nimic.** Pasul 6 din lanț cerea să te uiți la apă, dar pe apă nu se întâmpla nimic: sprite-ul `boat` exista în `Assets` cu zero desenări în tot codul, iar sosirea era doar o linie de text într-un colț. Acum barca vine din amonte, **încetinește în dreptul terenului**, arată numele celui care coboară, apoi pleacă la vale și se stinge. Nu blochează nimic și nimeni nu o așteaptă — dacă jucătorul se uită în altă parte, pasul se termină oricum.
- **Debarcaderul e o singură sursă de adevăr** (`RiverConfig.LANDING`). Săgeata pasului arăta spre mijlocul lumii (x = 1440), barca ar fi tras în dreptul terenului (x = 950): indicatorul ar fi trimis jucătorul la 490 px de locul unde se întâmpla lucrul. Trei teste țin punctul în banda apei și în dreptul terenului.
- **Grămada goală din atelier** spunea „nimic aici" și când tot ce adunase jucătorul era pe masa de reparat. Acum distinge cele două cazuri și numără piesele în lucru.

### D39 — Dialog care oprește jocul, colonie care se salvează, economie cu presiune reală · DECIS (2026-09-10)
**Dialogul.** Primul colonist vine **la** jucător și îi vorbește într-o cutie mare jos-centru, cu portret, nume și text scris literă cu literă. Cât vorbește, jocul stă: personajul nu se mișcă, panourile nu se deschid, cartonașul și bara de butoane se ascund. Un mesaj în colț peste care jocul curge mai departe nu se citește, devine zgomot. Trei plase de siguranță ca jucătorul să nu rămână blocat: dacă nu are drum vorbește pe loc, dacă nu ajunge în 7 secunde vorbește oricum, iar clientul deblochează singur după 14. Numărătoarea se face pe **grafeme**, nu pe octeți, altfel diacriticele rup efectul.

**Busolă în jurul jucătorului.** Săgeata de deasupra țintei ajută doar când ținta e pe ecran. Când nu e, o săgeată orbitează jucătorul și arată încotro. Apare doar peste 260 px distanță.

**Defecte găsite de recenzia pe patru zone și reparate:**
- **Coliziunea jucătorului folosea clădirile fantomă din prototip.** Clădirile construite de jucător nu opreau deloc, iar acolo unde nu se desena nimic existau ziduri invizibile. Acum urmează starea reală a clădirilor.
- **Fundătură în lanțul de obiective:** pasul cerea „orice clădire terminată", nu un pat. Cine construia o vatră rămânea cu un singur pat, nimeni nu mai venea pe apă, iar pasul următor nu se putea termina niciodată. Condiția e acum **paturi ≥ 2**.
- **Scurgere de ocupare:** un colonist șters cât timp ocupa o clădire lăsa locul ocupat pe veci.
- **Atelierul se bloca** pe cea mai veche piesă chiar dacă nu și-o permitea, cu una gratuită mai jos în grămadă.
- `DataService` pornește **ultimul**: el declanșează încărcarea profilului, deci toți ascultătorii trebuie conectați înainte.
- Pânza interfeței urmează acum ecranul. Era fixă la 1920×1080 cu prag de scară 0,62, deci pe ecrane mici tot ce e ancorat la dreapta ieșea afara și nu se mai putea apăsa.
- Tragerea cartonașului se făcea în pixeli de ecran peste o pânză scalată: rămânea în urmă pe orice ecran mai mic decât referința.
- Butoanele de pe ecran se ascund când e un panou deschis. Pe telefon stăteau sub panou și apăsai panoul când voiai să mergi.

**Economia are presiune abia acum.** Pescuitul nu avea plafon, iar meseriile se împart pe rând: un pescar hrănea 18 oameni la orice mărime de colonie, deci raportul rămânea același și nu exista nicio decizie. Râul are acum **3 locuri de pescuit**. Pescuitul singur susține 24 de oameni; peste atât trebuie grădini. Hangiul împarte același bine la toată colonia, în loc să-l dea fiecăruia întreg. Două teste apără curba: unul verifică plafonul, altul că pescuitul singur nu duce colonia până la limita dură.

**Coloniștii se salvează.** Nume, meserie, nevoi, trăsături și poziție intră în profil, cu scriere la 15 secunde și la ieșire. O colonie crescută în câteva sesiuni se întorcea la un singur străin după orice repornire de server, în timp ce clădirile rămâneau în picioare.

### D38 — Colonia începe de la un singur om; textul nu mai are voie să mintă · DECIS (2026-09-10)
- **Se pornește cu UN colonist**, nu cu doisprezece. Primul om vine pe apă și cere de lucru: `"I heard someone was keeping this place. I can work, if you'll have me."` E singura dată când cineva vorbește direct cu jucătorul. Colonia trebuie să crească din el, nu să fie primită gata făcută.
- Așezarea moștenită are **un singur pat** (cort, nu cabană de trei). Nimeni nou nu se oprește acolo până nu construiești al doilea pat. Cu trei paturi din start, creșterea venea de la sine și nu mai era a jucătorului.
- **Inelul strălucitor există acum.** Indiciul primului obiectiv spunea „du-te la inelul strălucitor de pe apă", iar pe apă era un dreptunghi palid pe care nu-l vedeai. Acum e un cerc cu contur auriu și un al doilea inel care se umflă și se stinge.
- **Text care nu poate minți:** listele de semne și de panouri sunt acum sursă unică de adevăr în configurație, iar două teste verifică fiecare obiectiv. Un obiectiv care cere un semn inexistent lasă jucătorul fără indicație; unul care deblochează un panou inexistent îl lasă blocat. Testul a fost verificat inventând un semn: pică.
- **Cartonașul de obiectiv**: înălțimea vine din conținut printr-o singură legătură, deci nu mai există banda goală dintre titlu și indiciu. Se poate **strânge** la titlu și se poate **trage** oriunde pe ecran. Aceeași suprafață face și clic și tragere, după cât s-a mișcat degetul: două suprafețe separate ar fi fost o ghicitoare în plus.
- Sărbătoarea mișcă panoul, nu îl scalează. Un `UIScale` ar mări corpul, corpul ar cere altă înălțime pentru ramă, iar rama ar mări iar corpul: buclă, exact în timpul animației.

### D37 — Toate panourile pe aceeași trusă, font de registru · DECIS (2026-09-10)
- **Ce era greșit:** trusa de interfață exista, dar o foloseau doar HUD-ul, cartonașul de obiectiv și bara de butoane. Cele patru panouri mari erau desenate de mână, cu Gotham și **89 de culori scrise direct în cod**. De acolo venea impresia de interfață generică lipită peste un joc pixelat.
- Atelierul, meniul de construcții, panoul de oameni și tabloul coloniei trec toate prin `Widgets.Window`: aceeași ramă de lemn, aceeași banderolă de titlu, același buton de închidere, aceeași spațiere. Rândurile de listă sunt casete scobite care se luminează la trecerea mausului. Butoanele au trei stări desenate.
- **Tabloul coloniei are corp care se derulează**, cu secțiuni așezate una sub alta. Varianta veche calcula pozițiile pe verticală de mână, iar orice text mai lung ieșea din panou. Acum nu mai există aritmetică de așezare, deci nici clasa aia de erori.
- **Fontul:** Gotham e implicitul depreciat al platformei, iar Montserrat și Poppins sunt geometricele pe care le folosește toată lumea. Ambele citesc ca „am lăsat setarea din fabrică". Titlurile trec pe **Merriweather**, un serif de carte: pe pergament și lemn arată a registru scris, nu a dialog de aplicație. Textul curent rămâne **Nunito**, rotunjit și lizibil la dimensiuni mici, unde un serif ar deveni greu de citit. Greutatea de titlu coboară la Bold: un serif la greutate extremă își închide contraformele.
- **Fontul se caută prin nume, cu rezervă.** `Enum.Font.CevaGresit` aruncă pe loc, iar fiindcă modulul de temă e cerut de toate controllerele, o singură literă greșită ar opri tot bootstrap-ul clientului și jocul ar porni pe ecran gol.
- Singurele culori rămase scrise în cod convertesc triplete din configurație (raritatea lăzilor, tonul evenimentelor). Alea sunt date, nu decizii de stil.

### D36 — Cartonașul nu se golește niciodată, iar textele încap · DECIS (2026-09-10)
- **Textele se tăiau.** Creșterea automată a panoului nu apuca să urmeze conținutul înainte de desenare, iar eticheta ajungea în afara ramei, peste iarbă. Acum înălțimea e fixă, în două variante după cum există sau nu bară de progres, iar textele din configurație sunt scrise ca să încapă în două rânduri fiecare. **Un test verifică lungimea lor**, ca să nu se strecoare altele mai lungi.
- **„Tap this card to open it" a fost scos.** Era o instrucțiune despre interfață, nu despre joc, și mânca spațiul care lipsea textului. În locul ei stă o săgeată mică pe marginea cartonașului, doar când se poate apăsa: semn, nu propoziție.
- **Țelurile lungi au trepte, nu o singură țintă.** Paturi 6→12→20→32→50, grădini 1→2→4, populație 10→20→35→50→80, reparații 1→5→15→40. Când atingi una, apare următoarea. Se afișează cel mai aproape de finalizare: aia e sarcina care se simte la îndemână.
- **Cartonașul nu se golește niciodată.** Când toate treptele sunt atinse, rămâne sarcina permanentă de întreținere a coloniei. Un ecran fără nicio direcție, exact după ce tutorialul s-a terminat, e momentul în care jucătorul închide jocul.
- Tabloul coloniei arată **lista completă de țeluri**; cartonașul arată doar unul. Așa ai și o sarcină la îndemână, și imaginea de ansamblu dacă o vrei.

### D35 — Economia hranei: meseriile capătă rost · DECIS (2026-09-10)
- **Problema:** trei din cinci meserii nu produceau nimic. Pescarul pescuia fără rezultat, grădinarul și hangiul nu aveau unde lucra. O colonie mare nu costa nimic, deci nu exista nicio decizie de administrator.
- **Hrana** e resursa care leagă meseriile de populație. Pescarii produc pe mal, grădinarii într-o **grădină** (clădire nouă, 3×2, două locuri), hangiul ridică moralul întregii colonii din sala de adunare. Masa la bucătărie **costă hrană**; dacă depozitul e gol, colonistul pleacă flămând și se vede, în loc să primească o restaurare gratuită.
- **Bilanțul se arată jucătorului**, nu doar codului: tabloul coloniei afișează intrarea și ieșirea pe minut și câți oameni susține producția curentă. Un depozit care scade încet nu se observă până e gol. Calculul stă în modulul pur `Shared/Modules/FoodBalance`, cu 8 teste, printre care unul care verifică explicit că **colonia de start se susține singură**: o criză în primul minut e o criză pe care jucătorul nu are cum s-o înțeleagă.
- **Factorul de prezență la post** (0,55) e explicit în configurație. Fără el orice socoteală de producție iese de două ori mai optimistă decât realitatea.
- Adevărata presiune nu vine din numărul de producători, ci din **locurile din clădiri**: o bucătărie are două locuri, iar șaizeci de oameni nu încap la ea. Creșterea cere clădiri, nu doar oameni.
- **Bug reparat pe drum:** ținta unui colonist nu distingea între post de lucru și loc unde își rezolvă o nevoie. Grădinarul ajuns la grădină încerca să mănânce din depozit, iar sala de adunare era în același timp postul hangiului și locul de odihnă al tuturor. Există acum un semn explicit pe țintă.
- **Cartonașul de obiectiv** se strânge pe conținut. Înălțimea fixă lăsa două treimi de pergament gol, ceea ce arată a interfață stricată, nu a spațiu de respirație.

### D34 — Niciun pas pasiv, nicio țintă moartă, niciun panou fără ieșire · DECIS (2026-09-10)
- **Pasul „așteaptă constructorii" a fost eliminat.** Un pas în care jucătorul nu are ce face arată identic cu un joc stricat. „Build a tent" se termină acum când cortul e **gata**, iar cartonașul are o bară care se mișcă: fără ea, așteptarea e imposibil de deosebit de un blocaj. Lanțul are 6 pași, nu 7.
- **Meseriile se împart pe rând, nu la întâmplare.** Cu 12 oameni și 5 meserii, alegerea aleatoare poate lăsa colonia fără niciun constructor, iar atunci șantierul nu avansează niciodată. În plus, dacă nu există niciun constructor, pune mâna oricine e liber.
- **Toate semnele arată ținte vii**: plasa liberă, plasa plină, șantierul cel mai avansat, atelierul real. Săgeata dispare când nu există țintă. Înainte arăta spre centrul terenului, adică spre iarbă goală, ceea ce derutează mai tare decât lipsa ei.
- **Escape aparține meniului platformei** și nu ajunge niciodată la joc. Eticheta „Close (Esc)" trimitea jucătorul în meniul Roblox. Fiecare panou are acum un buton de închidere vizibil, tasta Q închide tot, iar butonul din bară comută atelierul.
- **Grămada goală din atelier spune ce e de făcut.** Un dreptunghi negru gol arată a eroare, nu a stare validă.

### D33 — Semnalele duc identități, nu tabele · DECIS (2026-09-10)
- Un `BindableEvent` **copiază** tabelele care trec prin el. `DataService.ProfileLoaded` trimitea `(player, data)`, iar `BuildService` crea cele patru clădiri de start în handler: scrierile intrau în copie și se pierdeau. Simptomele erau o așezare fără nicio clădire și contorul de paturi blocat pe zero, adică exact în altă parte decât cauza.
- **Regula de acum:** un semnal duce o identitate, niciodată un tabel modificabil. Semnalul trimite doar `player`; fiecare handler își ia profilul viu cu `DataService.Get(player)`. Verificatorul pică build-ul pe orice `ProfileLoaded:Connect(function(a, b`.
- Tot aici: `sendState` nu trimitea starea clădirilor. Transmisia de la încărcarea profilului pleacă înainte ca clientul să asculte, deci așezarea rămânea invizibilă până la prima construcție. Acum pleacă și la cererea clientului.
- Bara de butoane se împrospăta pe același remote ca starea de obiective, dar era conectată **prima**, deci citea mereu deblocările vechi. Butonul cerut de pasul curent nu apărea niciodată și jucătorul rămânea blocat definitiv. Anunțul vine acum din interiorul aplicării stării, după actualizarea deblocărilor.
- Plasă de siguranță: **cartonașul de obiectiv e el însuși buton**. Apeși pe sarcină și se deschide exact ce trebuie, fără să depinzi de bara laterală. Dacă bara nu apare din orice motiv, jocul rămâne jucabil.

### D32 — Direcție vizuală, trusă de interfață și onboarding fără tutorial · DECIS (2026-09-10)
**Ce nu mergea:** arta era plată (o singură dală de iarbă uniformă, fără decor), meniurile erau dreptunghiuri gri cu Gotham, iar jucătorul care intra nu avea nicio indicație despre ce să facă. Peste asta, HUD-ul afișa permanent fps și o linie de diagnostic peste lume.

**Arta.** Rampele de culoare se construiesc cu **deplasare de nuanță** (`scripts/art/palette.py`): umbra se rotește spre albastru și crește în saturație, lumina spre galben și scade. O rampă făcută doar din întunecare citește ca o culoare trecută prin filtru de gri, și ăsta e semnul cel mai vizibil de artă amatoare.
- Dalele sunt **bază plată plus fire**, nu pete mari de culoare. Petele mari citesc ca blană de leopard și fac repetiția dalei vizibilă de la distanță. Zgomotul e periodic (sume de sinusuri cu frecvențe întregi), deci dalele se leagă fără cusătură.
- Detaliile se împrăștie cu **distanță minimă** între ele: grămezile de detaliu nu au voie să se atingă pe muchie, altfel apar aglomerări care citesc ca zgomot.
- 14 obiecte de decor se așează determinist din seed (`Shared/Modules/WorldDecor`, testat). Decorul **nu blochează** trecerea: un copac lângă o ușă ar bloca coloniștii, iar jucătorul nu are cum să-l taie încă.
- Apa are trei straturi: dala care curge, un al doilea strat translucid mai lent pentru adâncime, și spumă la linia malului.
- Compunerea alfa era greșită în generator (două umbre translucide suprapuse deveneau negru opac). Corectată.

**Interfața.** Trei schimbări, fiecare cu motiv documentat:
- **Gotham a ieșit.** E fontul implicit **depreciat** al platformei din 2024; înlocuitorul oficial anunțat de Roblox pentru Gotham este Montserrat. Orice interfață pe Gotham arată ca interfața implicită a oricui. Acum: Montserrat pentru titluri, Nunito pentru text, ierarhia din **greutate** (`FontFace` + `FontWeight`), nu doar din mărime.
- **Ramele sunt imagini cu 9 felii**, nu `Frame` + `UICorner`. Un dreptunghi rotunjit nu poate purta textură, iar jocurile de top de pe platformă folosesc chenare desenate, nu chenare procedurale. Trusa: panou, buton în 3 stări, casetă scobită, banderolă, 15 pictograme.
- **Umbra e instanța nativă `UIShadow`**, cu rezervă pe `UIStroke` dacă lipsește.
- Culoarea e **semnal**, nu decor: verde merge, roșu nu-ți permiți, auriu atenția ta acum. Meniul de construcții stinge rândurile pe care nu ți le permiți **înainte** de clic.

**Onboarding.** Lanț de 7 obiective (`Shared/Config/ObjectiveConfig`, evaluat pe server):
- **Un singur obiectiv pe ecran** cât timp jucătorul învață, titlu care începe cu un verb, la prezent.
- **Un singur semn care pulsează** în tot ecranul. Dacă totul strălucește, nimic nu iese în evidență.
- Panourile mari **nu există** până nu sunt necesare. Un ecran plin de butoane la prima intrare e tiparul cel mai des reclamat pe jocurile care pierd jucători în primul minut.
- Sistemul cerut de un pas se deschide **în timpul** pasului, nu după: altfel jucătorul primește o sarcină pe care nu are cum s-o ducă la capăt. Există test pentru asta.
- **Bară de butoane cu pictograme** pe margine: până acum panourile se deschideau doar de la tastatură, iar pe telefon jumătate din joc era inaccesibil. Majoritatea jucătorilor platformei sunt pe telefon.
- Fps și diagnosticul au plecat din HUD în consola de dezvoltare.

**Bug-uri reale găsite și reparate:** `HUDController.SetWorkshop` și `SetAlert` erau apelate dar nu existau (crăpau la fiecare stare de atelier și la fiecare împrospătare a panoului de oameni); promptul atelierului era legat de o poziție din prototip, nu de clădirea reală. Verificatorul de căi a fost extins să prindă `Modul.Functie` unde modulul nu definește funcția — exact clasa asta.

### D31 — Povestitorul, tabloul coloniei și consola de dezvoltare · DECIS (2026-09-10)
- **Povestitorul** (`StorytellerService`) declanșează la 150–260 s un eveniment ales ponderat. Regula fixă cerută de owner rămâne în cod, scrisă în capul fișierului: **niciun dezastru natural**, nimic nu distruge o clădire, nimeni nu moare. Cele 11 evenimente sunt 7 bune, 1 neutru, 3 cu cost mic și reversibil (unelte uzate, nopți agitate, provizii puține).
- Alegerea ponderată stă în modulul **pur** `Shared/Modules/Storyteller` (eligibilitate, pondere, jurnal), testat cu Lune: 8 cazuri noi, 33 de teste în total. Serviciul de pe server păstrează doar efectele și anunțul. Un eveniment nu se repetă până nu trec alte 4.
- **Tabloul coloniei** (tasta C) primește o poză la 2 secunde: populație și paturi, materiale și grămadă, clădiri gata și șantiere, repartiția pe tipuri, nevoile medii, meseriile, numărătoarea până la următorul eveniment și ultimele 5 întâmplări. Se trimit doar 6 intrări de jurnal, nu tot, ca să nu se plimbe degeaba la fiecare push.
- **Consola de dezvoltare** (tasta ` sau F4) are **două porți independente**: panoul nu se construiește în afara Studio, iar `DevService` nici nu conectează handler-ul de remote în producție. Un singur remote `DevCommand`, o comandă pe apel, fiecare cu răspuns scris în jurnalul panoului. Butoanele improvizate din HUD au fost scoase.
- **Scara timpului** (`DevState`, ×1 până la ×60) accelerează scăderea nevoilor, sosirea bărcilor și povestitorul, dar **nu** viteza de mers și nici cronometrele de reparație. Testarea buclei de retenție durează minute în loc de ore. `DevState` e modul frunză, ca `SettlerService` să-l poată cere fără require încrucișat.
- **Un singur panou mare deschis o dată** (`Client/Controllers/Panels`): construcții, oameni, colonie, atelier și consolă se închid reciproc. Fără asta, tabloul și meniul de construcții se suprapun pe aceeași jumătate de ecran.
- **Verificare nouă de cale**: `scripts/check_requires.luau` deserializează place-ul construit și rezolvă fiecare `require` la o instanță reală (120 verificate azi). O cale greșită trece de stylua, de selene și de `rojo build` și se vede abia la rulare, unde oprește tot bootstrap-ul. Intrată în CI, testată cu o cale stricată intenționat.

### D30 — Un sprite per clădire și o foaie de animație cu 12 stări · DECIS (2026-09-10)
- Toate cele 8 clădiri randau același `house.png` și coloniștii aveau un singur ciclu de mers; meniul de construcții nu avea nicio pictogramă. Arta se generează procedural în Python pur (`scripts/art/buildings.py`, `scripts/art/settlers.py`), se urcă prin Open Cloud și se citește din `Assets.buildings` / `Assets.character_anim`. Confirmă D23: mediul și obiectele recognoscibile simple sunt generabile din cod.
- Fiecare `BuildingConfig` id are un sprite cu **aceeași proporție** ca amprenta lui în celule, deci `ScaleType.Fit` umple exact cadrul și pozițiile fracționare ale coșurilor de fum rămân valabile la orice scară.
- Șantierul are sprite propriu (`scaffold`), afișat **în locul** clădirii până la terminare. Varianta veche (clădirea finală, translucidă) nu comunica „încă se lucrează”.
- Foaia de animație: 12 rânduri × 4 cadre de 16×24 — mers și stat în 3 orientări, muncă, cărat, mâncat, dormit, sărbătoare, pescuit. Rândurile din profil se oglindesc pentru stânga (`ImageRectSize` negativ pe X), deci o singură orientare desenată acoperă ambele sensuri.
- Alegerea rândului stă în `AnimConfig.rowFor`, partajat între coloniști și personajul jucătorului. `moving` vine din interpolarea clientului, nu din starea serverului: altfel animația s-ar schimba când ajunge pachetul, nu când se oprește sprite-ul.
- Consecințe: serverul trimite în plus `tk` (felul țintei), altfel clientul nu deosebește „intră în bucătărie” de „intră în dormitor”. Pescarii au primit sarcina reală `fishing` pe malul de sud — deocamdată **fără producție**, doar prezență vizuală; de legat la economie când se decide randamentul.
- Particulele (fum de coș, foc, praf de șantier) rulează pe **o singură** buclă `PreRender` peste o listă, nu o conexiune per clădire.

### D29 — Lumea: hartă 2D liberă, văzută de sus · DECIS (owner, 2026-09-09)
- Se renunță la banda laterală (side-scroll) din brief în favoarea unei **hărți 2D libere, văzute de sus**, ca în inspirația Stardew: iarbă, râul ca bandă orizontală care traversează harta, terenul jucătorului pe malul de sud, orașul spre est. Motive: spațiu real pentru cele 7 sisteme (parcele, clădiri, atelierul orașului, Amonte), personajele celorlalți vizibile, decor cumpărabil; banda se simțea ca un coridor. Râul de sus e mai puțin spectaculos decât din profil, dar plasele rămân lizibile (confirmat de owner pe prototip).
- Tehnic: tile-uri de 48 px logici, hartă 60×40 la prototip (2.880×1.920), coliziuni pe dreptunghiuri (râu, clădiri, margini) în modulul pur `WorldMap`, cameră pe două axe, personaj cu 3 grupuri de cadre (down/up/side), d-pad pe mobil. Serverul (râu pe seed, prindere, date) nu se schimbă.
- Consecințe de propagat în masterplan: 4.1 (arbore GUI și cameră), 5.1 (benzi = rânduri ale benzii de râu), 5.4 (zonele orașului = locuri pe hartă, nu secțiuni de bandă), 8 (artă: tile-uri, sprite-uri 4 direcții, clădiri — cost mai mare), 14 (F4/F5). De făcut la următoarea reasamblare.

### D28 — Plasele: sloturi și tiere · DECIS (praguri PROVIZORII)
- Două axe independente. **Sloturi de plasă** (câte plase simultan): 1 gratuit; al 2-lea la Index ≥ 30%; al 3-lea prin Game Pass „Plasă suplimentară” **sau** la Index ≥ 80% (calea gratuită există; banii cumpără doar accesul mai devreme la spațiu, D20). Terenul are 4 benzi, deci o bandă rămâne mereu neacoperită. **Tiere de plasă** (calitate): Start 8 obiecte / 1,0 pe oră; Meșteșugită 12 / 1,4 (Index ≥ 10%, Materiale); Adâncime 16 / 1,8 (Index ≥ 40%, Materiale rare) — nu se vând pe Robux; timpul de umplere rămâne ≈ 8 h pe toate tierele (D15). [economy-balance, offline-progress]
- **Debit canonic de prinderi** pentru toate estimările până la măsurători: ≈ 15/zi (o plasă Start, 2 colectări), **≈ 25/zi referință pentru simulări**, ≈ 45/zi (3 plase Adâncime); Amonte adaugă 5–10/zi. [calcul propriu din tabelele de mai sus]
- Terminologie: **slot de plasă** (unde stă o plasă), **slot de decor** (decorațiuni de mal cumpărate cu Monede), **slot de atelier** (reparație). Orice „slot de mal” ambiguu se corectează.
- Respins: plase de tier superior vândute ca Game Pass (ar vinde debit de loot, prea aproape de pay-to-win) și plafonul de 2 plase simultan (costul server e neglijabil, acumularea e lazy).

### D17 — Indexul de reparații · DECIS
- **200 de obiecte la lansare**, 7 tiere cu ponderi geometrice (≈ 90% din masă în primele 3–4 tiere). Tierul Secret (și eventual Mitic) e **exclus din „100%"** afișat public, după modelul Fisch. [collection-design]
- **Ponderi recalibrate (2026-09-09)** pentru debitul pasiv al plaselor (T = 25 obiecte/zi, vezi D28), nu pentru cele 150–220/zi presupuse în notă: Comun 53,7% · Neobișnuit 24,8% · Rar 12,8% · Epic 6,1% · Legendar 2,1% · Mitic 0,45% · Secret 0,05% (doar în ferestrele de Inundație). Cu ponderile din notă, primul Legendar ar fi apărut după ≈ 4 luni și primul Mitic după ≈ 2 ani. [calcul propriu, coupon collector; de validat cu simularea din masterplan 6.6]
- **40 de obiecte exclusive de sezon** (10 pe sezon), nu 10: la T = 25/zi ≈ 90% din obiecte sunt descoperite în prima lună, deci coada lungă a Indexului vine din gate-ul de reparație, din exclusivele de sezon (100% cere un ciclu complet de 16 săptămâni) și din conținutul nou, nu din RNG. [calcul propriu]
- Recompense la 10/25/50/75/90/100%. 5 intrări oferite prin tutorial în prima sesiune (endowed progress: 34% vs 19% completare în studiul de referință). [collection-design]
- Procentul de completare e public: clasament pe `OrderedDataStore` actualizat la fiecare reparație finalizată; card de profil vizibil în oraș. [collection-design]
- Variante „shiny" sunt intrări opționale separate, nu condiție pentru 100%. Cadență de conținut după lansare: **10–20 obiecte noi la 2–4 săptămâni** (altfel colecția se epuizează ca motiv de revenire). [collection-design, case-top-games]

### D18 — Atelierul orașului (progres comun) · DECIS (parametri PROVIZORII)
- **12 zone** la lansare, deblocate secvențial, **1–2 seturi active** simultan. Un set cere 5–8 obiecte din 8–12 eligibile afișate (modelul Artisan Bundle din Stardew), ca să nu blocheze dropul aleator. [community-progression]
- Se pot dona doar obiecte **reparate complet** (anti-gunoi prin construcție). **Plafon 40% per jucător per set**: forțează minimum 3 contribuitori și protejează obligația socială de un singur „carry". [community-progression, shared-progress-persistence]
- Recompensă dublă: mică și imediată pentru donator, mare pentru tot orașul la completare. Plachetă cu top 5 contribuitori per zonă (`OrderedDataStore`, `IncrementAsync` pe cheie per jucător, deci fără hot-key). [community-progression]
- **Trickle anti-stagnare**: dacă orașul nu primește nicio donație 72 h, setul activ primește progres pasiv mic (modelul sătenilor din Animal Crossing). Deblocările nu se resetează niciodată. [community-progression]
- Nou-venit într-un oraș avansat: vede istoricul (cine a deblocat ce), primește un „bundle de bun venit" personal și un set activ mereu deschis. Cazul se testează cu oameni reali; nicio sursă nu-l rezolvă. [community-progression, onboarding-ftue]
- E **sistemul fără precedent** din cele 10 jocuri studiate: se testează cel mai devreme posibil, cu cohortă mică, înainte de monetizare. [case-top-games]

### D19 — Sezoane, Amonte, Inundația · DECIS
- Sezonul curent **nu se stochează**: se calculează pe fiecare server din `os.time()` (UTC) și `SEASON_EPOCH`, ciclu de 4 săptămâni; 4 sezoane, an de 16 săptămâni. Fără MessagingService ca sursă de adevăr (livrare best-effort). [seasons-liveops]
- **Inundația**: fereastră lunară derivată determinist (`windowId`), anunțată cu 7 zile înainte (countdown în HUD) și notificare cu 24 h înainte; **kill-switch** `flood_enabled` în ConfigService verificat înainte de orice efect distructiv (singurul rollback instant). Afectează obiectele nefixate ale **tuturor** jucătorilor (inclusiv offline) — altfel nu e obligație de revenire — dar fixarea e o acțiune gratuită, dintr-un tap, iar prima Inundație a fiecărui jucător e cu grație (pierdere zero, doar avertisment). [seasons-liveops]
- **Amonte**: reset zilnic la **UTC fix** (`floor(os.time()/86400)`), nu rulant per jucător (mai simplu, imun la exploatare prin reconectare). [seasons-liveops]
- Season Pass (dacă se face vreodată) = Game Pass permanent cu track resetat logic pe `cycleIndex`; nu în v1. [seasons-liveops]

---

## E. Monetizare, conformitate, legal

### D20 — Monetizare · DECIS (prețuri PROVIZORII)
- Game Passes (permanente, cotă dezvoltator 70%): plasă suplimentară, slot extra în atelier, viteză de reparație. Developer Products (repetabile): materiale rare **deterministe** (nu aleatorii → fără obligații Paid Random Items), skip la timp, extindere temporară de spațiu. Cosmetice (skin-uri de plasă, decorațiuni de mal) ca Passes/Products, nu ca iteme de catalog UGC (Driftwood n-are avatar 3D). [monetization-numbers, monetization-impl, collection-design]
- **Zero pay-to-win** (brief) și **zero paid random items** (nici lăzi, nici pachete cu conținut aleator). [policy-compliance]
- Managed/Regional Pricing activat pe toate produsele; Price Optimization abia la ~60.000 tranzacții/30 zile. [monetization-numbers]
- Bucla zilnică ținește explicit **Creator Rewards**: 5 Robux/zi per Active Spender (≥ 9,99 $ cheltuiți oriunde pe Roblox în 60 zile) care stă 10+ minute și pentru care Driftwood e printre **primele 3 experiențe lansate în ziua aceea de acel jucător** (formularea din CLAUDE.md e corectă; nu e un clasament de platformă). [monetization-numbers, retention-benchmarks]
- Cifre pentru planul financiar: DevEx **0,0038 $/Robux** (din 5 septembrie 2025), minim 30.000 Robux (114 $), o cerere/lună, Tipalti ≈ 5–10 zile lucrătoare; din 1 $ cheltuit de un jucător pe un pass ajung la dezvoltator ≈ **0,21 $**. Rata 0,0054 $/Robux (jucători SUA 18+ verificați, din 8 iunie 2026) se aplică jocurilor „fără personaj vizibil" — Driftwood pare eligibil; **se confirmă prin ticket la Roblox** înainte de a intra în proiecții. [monetization-numbers, monetization-impl]
- Fără Immersive Ads (gândite pentru Workspace 3D, share nepublic), fără Subscriptions în v1. [policy-compliance, monetization-numbers]
- `ProcessReceipt` idempotent într-un singur modul `EconomyServer`; `PromptProductPurchaseFinished` nu e sursă de livrare. Testele de cumpărare se fac cu un produs de 1 Robux pe staging. [monetization-impl]

### D21 — Conformitate · DECIS
- Chestionarul Content Maturity țintește **Minimal/Mild**; se recompletează la orice adăugare de loot plătit sau trading. [policy-compliance]
- Chat: **TextChatService implicit**, fără sistem custom; Roblox gestionează filtrarea și Age Check to Chat. Fără text generat de jucători în UI propriu în v1 (numele orașelor sunt din listă predefinită); dacă apare, trece prin `TextService:FilterStringAsync`. [policy-compliance, platform-2025-2026-features]
- Fără linkuri externe (Discord/YouTube) în joc până la verificarea 16+ a contului și citirea manuală a Community Standards (pagina n-a putut fi verificată automat). [policy-compliance, discovery-marketing]
- Fără trading între jucători în v1 (RMT, gri, abuz; exemplele Fisch și Grow a Garden). [case-fisch-gag, economy-balance]

### D22 — Legal și nume · PROVIZORIU
- Mecanicile se pot copia; expresia nu (Legea 8/1996 art. 9; Tetris v. Xio). Toată arta, textele, numele și muzica sunt originale. [legal-ip-tax]
- Numele „Driftwood": niciun joc Roblox major cu numele exact; căutarea de marcă USPTO/EUIPO a fost neexhaustivă → **audit de marcă plătit înainte de marketing** (DE DECIS: buget). [legal-ip-tax]
- Structură fiscală RO (PFA vs SRL micro, plafon 60k vs 100k EUR incert) → **contabil înainte de primul cash-out**. Venit DevEx declarat în D212. [legal-ip-tax]

---

## F. Conținut

### D23 — Artă · DECIS (estimare revizuită 2026-09-09)
- **Test măsurat (2026-09-09):** o scenă completă generată programatic (teren cu value noise, maluri, apă cu adâncime și curenți, copaci/tufe/stuf/pietre cu umbre, cabană cu fețe luminate, ponton, personaj, pas de lumină caldă + vignetă) s-a produs în **0,78 secunde** de script Python, la o calitate acceptabilă pentru lansare. Estimarea de ~968 h de artă tier 2 din capitolul 8.4 se aplică doar unui flux 100% manual și **nu mai e validă** ca atare.
- Revizuire: **mediul (tile-uri, vegetație, apă, clădiri, lumină, efecte) se generează din cod** — ore, nu sute de ore. Rămân cu adevărat costisitoare, și acolo e nevoie de artist sau de o soluție dedicată: cele ~200 de obiecte care trebuie să fie **recognoscibile individual** (o bicicletă citită ca bicicletă), animația de personaj cu personalitate, și identitatea vizuală (paletă, hero art, icon, thumbnail). Bugetul din 8.4 și 14.3/14.4 se recalculează după alegerea direcției.

- Stil **pixel-art low-res** (sau flat/vector), sprite-uri de obiecte 32–128 px, fundaluri pe straturi de parallax ≤ 1024 px lățime, atlas-uri ≤ 1024×1024. Motive: ~80% din sesiuni pe mobil; rezoluția reală de upload e contradictorie (4K anunțat ianuarie 2026, downscale la 1024 raportat în iunie 2026); diferență de cost ≈ 10× față de hand-painted. [art-pipeline, sprites-assets]
- Pipeline: Aseprite/Affinity (gratuit) → export atlas → **Asphalt** (upload Open Cloud + manifest Luau generat) → `SpriteAtlas.luau`. Upload ca `Image`, nu `Decal`. `SpriteClip2` pentru animații. Preload doar foile de atlas (10–20 ID-uri). [sprites-assets, art-pipeline]
- Faze: placeholder (prototip) → vertical slice (o zonă + 20 obiecte la calitate finală) → lansare (200). Hand-painted doar post-lansare pentru rarități. [art-pipeline]
- Reprezentarea jucătorului: **fără avatar Roblox 3D**; un **sprite 2D de personaj** (16×24 px, 4 cadre de mers, placeholder generat) care merge pe mal, plus card de profil. La pasul 5, personajele celorlalți membri ai orașului sunt vizibile pe bandă. Rămâne „fără personaj 3D vizibil" pentru rata DevEx 18+ (D20). [monetization-numbers, alt-2-5d; revizuit 2026-09-09]

### D24 — Audio · DECIS
- **Noul Audio API** (`AudioPlayer` → `Wire` → `AudioDeviceOutput`, `AudioFader` ca bus), nu `Sound` clasic (marcat intern Legacy). 3 bus-uri: Music, SFX, Ambience, cu slidere persistate. Straturi muzicale pe sezon cu crossfade. Sunete din librăria gratuită (APM, Monstercat) + SFX proprii; „sprite audio" prin `PlaybackRegion` ca să economisească plafonul de upload. [audio]

---

## G. Măsurare, lansare, producție

### D25 — Analytics · DECIS
- Din pasul 1: `LogOnboardingFunnelStepEvent` pe 8 pași (Joined, PlacedFirstNet, CaughtFirstItem, ReachedWorkshop, StartedFirstRepair, FirstRepairComplete, SawOfflineHook, NotificationOptInShown), `LogEconomyEvent` pe fiecare tranzacție, buget ≤ 30 din cele 100 custom events. Funcționează doar din server, doar în joc publicat. [analytics-testing, onboarding-ftue]
- Sub 10 DAU/10 h/7 zile Creator Analytics nu pornește: alpha închis cu **foaie manuală + webhook de erori** (`ScriptContext.Error`). Experiments (A/B) abia peste ~1.000 DAU. [analytics-testing, retention-benchmarks]
- Ținte (ipoteze; Roblox publică doar un exemplu ilustrativ D1 p50 = 12,1%, p90 = 18,7%): prototip — 70% din testeri prind primul obiect în < 2 min; soft launch — D1 ≥ 15%, sesiune mediană ≥ 10 min, D30 ≥ 3%; lansare — D1 ≥ 20%, D7 ≥ 8%. Soft launch-ul durează **minim 45 de zile** (o cohortă D30 completă). [retention-benchmarks]

### D26 — Lansare și marketing · DECIS
- Ordine: Private → Limited/Playtesters (alpha 20 persoane) → Public fără reclame → reclame doar când D1 organic ≥ 15%. Traficul plătit **nu** alimentează semnalele de ranking organic. [discovery-marketing]
- 1–3 clipuri de gameplay (15–20 s) ca video pe Home (lift documentat +30–41% în teste oficiale 2026), icon 512², thumbnail 1920×1080. Share Links per canal pentru atribuire (Audience Expansion Rewards cere 100+ DAU medie 60 zile). [discovery-marketing]
- Buget test Ads Manager: 100–300 $ (1 credit = 263 Robux) ca să măsurăm propriul cost per play; nicio cifră publică de CPP nu există. Game Fund (2021) și Accelerator (2022) sunt defuncte; înlocuitoarele anunțate pe 9 martie 2026 sunt **Jumpstart** (continuu, pentru creatori noi pe Roblox, mentorat + promovare, fără finanțare) și **Incubator** (cohortă de 6 luni). Driftwood se potrivește profilului Jumpstart: **aplicăm după vertical slice**. [discovery-marketing, corectat la verificare]
- Secvența oficială de testare pre-lansare: Closed Access Beta prin Grup → Limited Time Test → Open Access Beta (ascuns din Recommended) → lansare completă. [solo-dev-production]
- Evenimentele de platformă (The Hunt) sunt fereastră de evitat pentru lansare, nu strategie. RDC 2026 e 10–12 septembrie 2026: planul se recitește după. [seasons-liveops, platform-2025-2026-features]

### D27 — Producție · DE DECIS (ore/săptămână)
- Ordinea din brief rămâne obligatorie (7 pași, fiecare cu test pe oameni reali). Planul de producție din masterplan dă două coloane: 15–20 h/săptămână și 40 h/săptămână. Owner-ul alege.
- Reper de durată din postmortem-uri: niciun succes rapid nu a avut scopul celor 7 sisteme interconectate; cel mai apropiat ca profunzime (DOORS, 2 oameni) a durat 1,5–2 ani. Planificare realistă: **9–14 luni part-time** până la lansarea publică, cu învățarea Roblox de la zero inclusă. [solo-dev-production]
- Roblox Group + staging/prod + toolchain se fac **înainte** de pasul 1, nu după. **[2026-09-15]** Fără grup (vezi D01). Update-uri post-lansare la 2–4 săptămâni (recomandarea oficială), nu săptămânal. [solo-dev-production]

---

## Întrebări deschise consolidate (răspuns doar din Studio sau de la Roblox)
1. Latența reală de teleport lobby → oraș pe mobil (D10).
2. Câte ImageLabel poolate țin 30 fps pe un Android de 2–4 GB (D05).
3. Rezoluția efectivă de upload pentru imagini pe contul grupului (D23).
4. Eligibilitatea Driftwood pentru rata DevEx 0,0054 $ „fără personaj vizibil" (D20).
5. Comportamentul `ConfigService` la pierderea rețelei: fail-open sau fail-closed (D19).
6. Clonarea ScreenGui-urilor din StarterGui cu `CharacterAutoLoads = false` (D04).
7. Comportamentul `UIDragDetector` peste `ScrollingFrame` (D07).
8. Plafonul real de upload audio pe cont (100/2.000 vs 10 istoric) (D24).
