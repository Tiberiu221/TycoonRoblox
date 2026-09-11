# Sunetul care creează atmosferă într-un joc 2D — studii de caz și plan concret pentru Driftwood

## Rezumat executiv

- **Muzica adaptivă reală (vertical layering / horizontal resequencing) e rară chiar și în jocurile studiate.** Terraria și Subnautica NU fac mixaj live de straturi — ele fac **selecție de track** (track A se oprește, track B pornește/crossfade) în funcție de zonă/oră/pericol. Asta e mult mai ieftin de construit decât un sistem cu stem-uri sincronizate și e exact ce își poate permite o echipă mică.
- **Stardew Valley demonstrează cel mai clar "identitate emoțională prin muzică"**: Eric Barone a compus și produs singur toată muzica (folosind Reason Studios), fără experiență muzicală anterioară, în cei ~5 ani de dezvoltare solo. Rezultatul: soundtrack lansat separat (2016), carte de piano (2018), versiune simfonică cu orchestră reală (2020), turnee de concerte live în 2023 și 2024 — un semnal foarte tare că un "voice" muzical coerent, compus de o singură persoană/echipă mică, poate deveni un asset de marcă pe termen lung, nu doar decor.
- **Don't Starve/DST leagă direct sunetul de o mecanică (Sanity)**: praguri clare (75%/60%/50%/15%) declanșează progresiv shake vizual, desaturare, apoi la ≤50% "insanity ambiance" audio, iar la ≤15% jingle-ul zi/noapte se distorsionează și apar creaturi fizice. E un exemplu direct de **sunet diegetic care transmite informație mecanică** ("ești în pericol de a pierde sănătatea mintală"), fără UI.
- **Subnautica arată puterea tăcerii**: nu are muzică de fundal continuă — fiecare zonă are teme declanșate contextual ("Into The Unknown" pentru Safe Shallows, temă separată pentru Kelp Forest), iar restul timpului jocul se bazează pe ambianță pură (sunet de apă, creaturi). Muzica de pericol ("Fear the Reapers", "Red Alert" la atacul asupra Cyclops-ului) e rezervată strict pentru momente de amenințare reală — ceea ce o face eficientă tocmai pentru că nu concurează cu zgomot de fundal.
- **Terraria are peste 100 de piese (104 confirmate + 27 "Otherworldly")** dintr-un sistem simplu, riguros: track ales după bioma curentă × ziua/noaptea × boss/eveniment activ. Compozitor principal: Scott Lloyd Shelly. Modelul e ușor de imitat: un tabel/matrice zonă×moment→track, nu un motor adaptiv complex.
- **Sursele de sunet ieftine/gratuite există și sunt solide**: Sonniss oferă anual, gratuit, de 10 ani, bundle-uri masive de SFX cu licență foarte permisivă (comercial, fără atribuire, permanentă). Roblox însuși oferă o librărie licențiată de peste 100.000 de piese/efecte (parteneri: APM, Monstercat, Pro Sound Effects, Nettwerk, Position Music) direct din Creator Store, gratuit de folosit în orice experiență.
- **Roblox rulează acum două sisteme audio complet funcționale**: `Sound` (legacy) și noul **Audio API** (`AudioPlayer` → `Wire` → `AudioDeviceOutput`, plus efecte: `AudioEqualizer`, `AudioCompressor`, `AudioReverb`, `AudioFader` etc.). Documentația oficială recomandă explicit noul API pentru cazuri ca al Driftwood (audio 2D, non-spațial).
- **Roblox marchează explicit "ominous music", "shrieking or screaming", "loud/heavy breathing, pounding heart" și "gameplay that builds suspense" ca fear-content care cere disclosure de maturitate** — un semnal direct că design-ul de tip Subnautica/Don't Starve (tensiune prin sunet de groază) trebuie diluat serios pentru un public tânăr, exact cum cere brief-ul (fără dezastre, ton non-scary).
- **Adaptive music "la pachet" (Wwise/FMOD) nu are sens pe Roblox** — motorul nu suportă plugin-uri de middleware audio extern ca Unity/Unreal; orice logică adaptivă trebuie construită manual peste graful `AudioPlayer`/`Wire`/`AudioFader`, ceea ce e perfect fezabil pentru selecție de track (gen Terraria), dar costisitor pentru mixaj live pe multe straturi.

## Fapte verificate

- Eric "ConcernedApe" Barone a compus toată muzica și toate efectele sonore din Stardew Valley singur, folosind Reason Studios, pe parcursul celor ~5 ani de dezvoltare solo. — sursă: Wikipedia, „Stardew Valley" — 2026-09-10 — încredere: ridicata
- Soundtrack-ul Stardew Valley a fost lansat oficial pe 19 septembrie 2016; au urmat o carte+album de piano (5 octombrie 2018), o versiune orchestrală „Symphonic Tale" cu Budapest Symphony Orchestra (15 august 2020), o colaborare cu Norihiko Hibino „Prescription for Sleep" (19 mai 2021) și un album instrumental „Festival of Seasons" (29 august 2025); au fost anunțate două turnee de concerte live: „Festival of Seasons" (10 octombrie 2023) și „Symphony of Seasons" (20 noiembrie 2024). — sursă: Wikipedia, „Stardew Valley" — 2026-09-10 — ridicata
- Muzica din Don't Starve/Don't Starve Together a fost compusă de Vince de Vera, Jason Garner și Emmett Hall. — sursă: Wikipedia, „Don't Starve" — 2026-09-10 — medie (nu am putut verifica pe o a doua sursă independentă)
- Mecanica Sanity din DST leagă praguri numerice de efecte audio-vizuale progresive: la ≤75% ecranul începe să tremure și culorile se desaturează; la ≤60% apare distorsiune vizuală; la ≤50% devine audibilă „insanity ambiance" (un strat sonor suplimentar); la ≤15% ecranul e înconjurat de tentacule roșii, jingle-ul de tranziție zi/noapte se distorsionează, iar creaturile-umbră devin fizice și agresive. — sursă: dontstarve.wiki.gg, „Sanity" (wiki comunitar, sursă secundară) — 2026-09-10 — medie
- Don't Starve Together are pe Steam 95% recenzii „Overwhelmingly Positive" din 82.156 recenzii totale, preț 14,99€, lansat 21 aprilie 2016; „Atmospheric" e unul din tag-urile populare definite de utilizatori. — sursă: store.steampowered.com/app/322330 — 2026-09-10 — ridicata
- Terraria conține peste 100 de piese muzicale (104 în versiunea curentă) plus 27 de piese „Otherworldly" (din jocul anulat Terraria: Otherworld, activabile prin NPC-ul Party Girl în lumi „Drunk"); marea majoritate a muzicii a fost compusă de Scott Lloyd Shelly (Resonance Array), cu excepții punctuale (Deerclops – Klei Entertainment; Torch God – Prosthetic Orchestra). — sursă: terraria.wiki.gg, „Music" (wiki comunitar) — 2026-09-10 — medie
- Selecția muzicii în Terraria e determinată de biomă (ex. Forest zi → „Overworld Day", Jungle → temă proprie, Underworld → „Hell"), de ziua/noaptea curentă (variante zi/noapte separate per biomă) și de evenimente/boss-uri active (Blood Moon, invazii, evenimente lunare); pe Desktop există „Resource Packs" pentru înlocuirea track-urilor, iar accesoriul „Music Box" permite înregistrarea și redarea la cerere a oricărei piese auzite deja. — sursă: terraria.wiki.gg, „Music" — 2026-09-10 — medie
- Terraria are pe Steam 97% recenzii pozitive din 601.379 recenzii, lansat 16 mai 2011, preț 9,75€; soundtrack-ul oficial se vinde separat ca DLC la 4,99€. — sursă: store.steampowered.com/app/105600 — 2026-09-10 — ridicata
- Soundtrack-ul Subnautica a fost compus de Simon Chylinski: 56 de piese, durată totală 1h39m24s, album lansat 1 februarie 2018. — sursă: wiki.subnautica.com, „Music" (wiki comunitar) — 2026-09-10 — medie
- Subnautica NU folosește un sistem muzical adaptiv complex, ci cue-uri muzicale legate de locație/context: teme specifice per biomă (ex. „Into The Unknown" pentru Safe Shallows, temă proprie pentru Kelp Forest), plus cue-uri de pericol explicite — „Fear the Reapers" în zone cu prădători periculoși (Mountains, Lost River), „Red Alert" când submarinul Cyclops e atacat de o creatură de tip Leviathan. — sursă: wiki.subnautica.com, „Music" — 2026-09-10 — medie
- Core Keeper (dezvoltator Pugstorm, publisher Fireshine Games) are muzică compusă de Jonathan Geer; jocul a vândut 250.000 de copii în prima săptămână de Early Access, peste 500.000 în două săptămâni și peste 1.000.000 până în iulie 2022; suportă cooperare online de până la 8 jucători; soundtrack-ul se vinde separat ca DLC. — sursă: Wikipedia, „Core Keeper" — 2026-09-10 — ridicata
- Core Keeper are pe Steam 94% recenzii pozitive (23.531 recenzii), scor Metacritic 86, preț 19,99€, lansat integral pe 27 august 2024 (Early Access din 8 martie 2022); include un DLC „soundtrack" separat (~7,79€) și mecanici de „instrumente cântabile" în joc. — sursă: store.steampowered.com/app/1621690 — 2026-09-10 — ridicata
- Istoric, muzica dinamică în jocuri există de la Frogger (1981, cel puțin 11 piese diferite de gameplay ce se schimbă cu acțiunile jucătorului) și Dig Dug (1982, muzica se oprea când jucătorul se oprea din mișcare); sistemul iMUSE, pionierat de LucasArts, schimba muzica dinamic în funcție de nivelul de pericol; în SSX, muzica se estompează/înfundă când jucătorul e în aer după o săritură, iar sunetul ambiental de vânt crește. — sursă: Wikipedia, „Video game music" — 2026-09-10 — ridicata
- Sonniss distribuie anual, gratuit, de 10 ani, bundle-uri masive de efecte sonore sub numele „GameAudioGDC": licență permisivă (comercial, fără atribuire necesară, fără expirare, drept de editare), interzisă doar redistribuirea ca fișiere de sine stătătoare/librărie și antrenarea de modele AI/ML pe conținut; bundle-ul din 2024 a avut 9 părți, cele din 2020-2023 câte 14 părți fiecare. — sursă: sonniss.com/gameaudiogdc — 2026-09-10 — ridicata
- Incompetech (Kevin MacLeod) oferă gratuit o librărie de aproximativ 400 de piese muzicale sub licență royalty-free; textul exact al termenilor de atribuire (dacă e necesară fără plata unei taxe „no-attribution") NU a putut fi confirmat din pagina fetch-uită. — sursă: incompetech.com — 2026-09-10 — NEVERIFICAT termenii exacți de licență, scazuta
- Roblox rulează în paralel `Sound` (documentat intern ca „LegacySound", cu proprietăți/metode deprecated dar complet funcțional) și noul Audio API: `AudioPlayer` (sursă), `AudioEmitter`/`AudioListener` (poziționare 3D), `AudioDeviceOutput`/`AudioDeviceInput` (I/O fizic), `AudioTextToSpeech`/`AudioSpeechToText`, toate conectate prin instanțe `Wire` (`SourceInstance`/`TargetInstance`). — sursă: create.roblox.com/docs/audio, create.roblox.com/docs/sound — 2026-09-10 — ridicata
- Efectele audio disponibile în noul API: `AudioEqualizer` (control pe benzi de frecvență — documentația dă explicit exemplul „creating underwater sound effects"), `AudioCompressor` (reduce dynamic range, permite „ducking" — scade unele surse când altele trebuie să iasă în față), `AudioReverb` (simulare acustică interioară), `AudioChorus`, `AudioDistortion`, `AudioEcho`, `AudioFlanger`, `AudioPitchShifter`, `AudioTremolo` (fluctuații de volum, descris ca util pentru efecte „dreamy sau legate de vreme"), `AudioFader` (mixaj pe mai multe surse simultan — echivalentul unui bus/`SoundGroup`), `AudioAnalyzer` (analiză frecvență/volum, ex. pentru vizualizatoare). — sursă: create.roblox.com/docs/audio/effects — 2026-09-10 — ridicata
- Limitele curente de upload audio: 100 fișiere/30 zile pentru cont neverificat, 2.000 fișiere/30 zile pentru cont ID-verificat, gratuit; fișier <20MB, <7 minute, sample rate ≤48kHz, format .mp3/.ogg/.wav/.flac, mono/stereo/3.0/5.1; Creator Store oferă gratuit peste 100.000 de piese/efecte licențiate profesionist. — sursă: create.roblox.com/docs/audio/assets — 2026-09-10 — ridicata (re-confirmat, coincide cu nota internă 31-audio.md din 2026-09-08)
- `AudioPlayer` are proprietățile `LoopRegion` și `PlaybackRegion` (ambele `NumberRange`), permițând „audio sprites" — mai multe sunete scurte într-un singur fișier, selectate prin regiune, reducând numărul de asset-uri distincte încărcate. — sursă: create.roblox.com/docs/reference/engine/classes/AudioPlayer — 2026-09-10 — ridicata
- Ghidul oficial de conținut/maturitate al Roblox listează explicit, ca exemple de conținut „mild fear-based": „Loud/heavy breathing, pounding heart, shrieking or screaming, creepy-looking NPCs, jump scares, ominous music, and/or gameplay that builds suspense" — creatorii trebuie să declare acest tip de conținut prin chestionarul de maturitate. — sursă: create.roblox.com/docs/production/promotion/experience-guidelines — 2026-09-10 — ridicata
- Nu am putut confirma pe pagina Wikipedia dedicată listei complete de câștigători IGF ("Independent Games Festival winners") vreo mențiune a Don't Starve la categoria "Excellence in Audio" — pagina Wikipedia a jocului Don't Starve menționează un asemenea premiu în 2014, dar tabelul de câștigători nu conține acest rezultat. Tratez afirmația ca **NEVERIFICAT/posibil contradictoriu** între cele două surse. — 2026-09-10 — scazuta

## Detalii

### 1. Cadru teoretic minim: straturi de sunet și diegeză

Orice joc care vrea "atmosferă" combină, de regulă, patru straturi separate, fiecare cu propriul bus de volum:

1. **Muzică** — non-diegetică de obicei (personajele din lume "nu o aud"), poartă identitatea emoțională.
2. **Ambianță** — loop-uri continue, adesea diegetice (vânt, apă, insecte, oraș), construiesc senzația de "loc".
3. **SFX de gameplay** — reacții la acțiuni (lovit, colectat, craftat) — pot fi diegetice (personajul lovește o piatră) sau semi-diegetice (un "ding" de reușită care nu există fizic în lume, dar e legat de acțiune).
4. **SFX de UI** — non-diegetice, pur informaționale (click, eroare, notificare).

Distincția importantă pentru brief: un sunet "diegetic care poartă informație mecanică" (ex. "plasa ta e plină") stă tehnic la mijloc — sună ca ceva ce s-ar întâmpla în lume (un "clonc" de plasă grea), dar funcția lui reală e de UI. Toate cele cinci jocuri analizate folosesc acest hibrid intens, pentru că reduce nevoia de HUD text și funcționează instant, fără traducere.

### 2. Studii de caz — tabel comparativ

| Joc | Compozitor principal | Volum muzică | Model de selecție | Rolul tăcerii |
|---|---|---|---|---|
| Don't Starve / DST | Vince de Vera, Jason Garner, Emmett Hall | NEVERIFICAT (total exact) | legată de mecanica Sanity (praguri 75/60/50/15%) | ambianță de bază relativ austeră; whisper-uri/„insanity ambiance" apar progresiv, nu de la început |
| Stardew Valley | Eric Barone (solo) | zeci de piese (exact NEVERIFICAT), pe locație+sezon+vreme+eveniment | track fix per context, fără mixaj live | muzică aproape mereu prezentă — e opusul tăcerii, e o alegere de identitate |
| Terraria | Scott Lloyd Shelly (+ excepții punctuale) | 104 + 27 „Otherworldly" | matrice biomă × zi/noapte × boss/eveniment, cu prioritate pentru evenimente | tăcere rară — aproape orice zonă/moment are un track dedicat |
| Subnautica | Simon Chylinski | 56 (album OST) | cue-uri per locație + cue-uri de pericol explicite, muzică absentă în restul timpului | tăcerea/ambianța (apă, creaturi) domină explorarea; muzica marchează doar momente speciale |
| Core Keeper | Jonathan Geer | NEVERIFICAT total exact | pare per-biomă (Sunken Sea, Desert, Meadow, Shimmering Frontier etc.) — detaliu tehnic NEVERIFICAT | NEVERIFICAT |

**Observație de design:** Stardew și Subnautica sunt polii opuși ai aceluiași spectru — Stardew alege "mereu muzică, mereu aceeași voce" ca identitate; Subnautica alege "aproape deloc muzică, ambianță + cue-uri rare" ca instrument de tensiune. Terraria și DST sunt undeva la mijloc, cu muzică aproape omniprezentă dar organizată strict pe context (Terraria) sau legată de o mecanică de risc (DST). Pentru un joc "cozy dar cu adâncime" ca Driftwood, poziția din brief se apropie mai mult de Stardew (identitate emoțională puternică) + un strat subtil de tip Subnautica pentru zonele de noapte/adâncime a râului.

### 3. Muzică adaptivă — ce înseamnă tehnic și ce e realist

Literatura de gaming audio (vezi istoricul din Wikipedia „Video game music") descrie două tehnici clasice:

- **Horizontal re-sequencing** — jocul trece de la un "segment" muzical la altul (track A se termină/crossfade → track B începe), fără ca cele două piese să sune simultan. Exact ce fac Terraria (schimbare de biomă) și Subnautica (schimbare de locație/pericol). E **ieftin**: fiecare piesă e un fișier separat, logica e un simplu `if zonă/oră/pericol == X then play track X`.
- **Vertical layering** — mai multe stem-uri (linii de instrumente) ale ACELUIAȘI track rulează simultan, sincronizate, iar jocul le crește/scade volumul independent (ex. adaugi o linie de tobe când pericolul crește, fără să schimbi piesa). Exemplul clasic citat e SSX, unde ambianța de vânt crește și muzica se "înfundă" când ești în aer. E **mai scump**: toate stem-urile trebuie compuse ca să sune bine în orice combinație, și trebuie sincronizate perfect (fază/tempo identice).

Pentru o echipă mică, **horizontal re-sequencing e calea corectă de start** (ca Terraria) — un tabel zonă×moment→track, cu crossfade de 2-5 secunde. Vertical layering (adăugarea unui strat de "urgență" peste piesa de bază) poate fi adăugat ULTERIOR fără să rescrii arhitectura, pentru că, tehnic, mai mulți `AudioPlayer` pot fi conectați simultan prin `Wire` la același bus `AudioFader` — arhitectura suportă nativ layering, doar conținutul muzical (stem-urile compuse să se combine) lipsește inițial.

### 4. Sunetul diegetic ca purtător de informație mecanică

Toate jocurile analizate folosesc "sunete-semnal" care înlocuiesc текст pe ecran:

- **DST**: whisper-uri/ambianță de insanitate la ≤50% Sanity — jucătorul știe că trebuie să reacționeze fără să se uite la niciun număr.
- **Subnautica**: "Red Alert" la atacul asupra Cyclops-ului — un cue muzical distinct, nu doar un beep, care spune "submarinul tău e în pericol acum".
- **Terraria**: schimbarea bruscă de track la apariția unui boss sau a unui Blood Moon — jucătorul aude imediat "ceva important tocmai a început", indiferent unde se uită pe ecran.

Pentru Driftwood, brief-ul cere exact acest tip de cue pentru mecanici gen "plasa ta e plină" sau "vine noaptea" — rețeta comună e: **sunet scurt (1-3 secunde), unic, distinct de restul paletei sonore a jocului** (timbru diferit, nu doar "mai tare"), declanșat o singură dată la trecerea unui prag, nu repetitiv/enervant.

### 5. Tăcerea ca instrument — cazul Subnautica

Cel mai important lucru de reținut din Subnautica: **absența muzicii nu e un gol, e o alegere activă**. Pentru că majoritatea timpului nu are muzică, momentele în care apare o temă ("Fear the Reapers") capătă greutate imediată — creierul jucătorului a fost "resetat" să nu se aștepte la muzică, deci prezența ei devine ea însăși informație. Dacă un joc are muzică 100% din timp (ca Terraria), fiecare piesă trebuie să facă treaba de "atmosferă generală"; dacă muzica apare rar (Subnautica), fiecare piesă poate face treaba de "alertă specifică". Cele două strategii nu se amestecă ușor — un designer trebuie să aleagă explicit unde se situează jocul pe acest spectru, zonă cu zonă.

### 6. Cum își permit echipele mici muzică și SFX

| Sursă | Cost | Licență (pe cât am putut verifica) | Observații |
|---|---|---|---|
| Sonniss GDC Bundle | Gratuit | comercială, fără atribuire, permanentă, fără redistribuire ca librărie, AI training interzis | doar SFX, nu muzică; recomandat pentru zgomote de bază (impact, UI, ambient generic) |
| Incompetech (Kevin MacLeod) | Gratuit (sau taxă unică pentru "fără atribuire") | NEVERIFICAT exact — verifică per-piesă | ~400 piese, stil generic, potrivit pentru fundal temporar/prototip |
| Epidemic Sound / Artlist etc. | Abonament lunar (preț exact NEVERIFICAT din research) | acces nelimitat cât ești abonat | risc contractual la anulare — verifică ce se întâmplă cu piesele deja integrate |
| Compozitor freelance dedicat | Mediu-mare (per piesă sau per proiect) | exclusivă/negociabilă | calea "Stardew" — un singur "voice" coerent, diferențiator de brand pe termen lung |
| Roblox Creator Store (librăria licențiată) | Gratuit, in-engine | doar în interiorul experienței Roblox (extragerea pentru trailer extern rămâne NEVERIFICAT) | zero risc legal, zero cost, dar nu diferențiază jocul de altele care folosesc aceeași librărie |

Recomandarea pragmatică pentru o echipă mică: **SFX din Sonniss/Creator Store (gratuit, volum mare, risc zero) + un buget dedicat pentru muzică originală** (fie un compozitor, fie timp de producție intern), pentru că datele de la Stardew arată clar că identitatea muzicală proprie e un asset care se recuperează la scară de ani (re-lansări, concerte), nu doar decor de fundal.

### 7. Roblox — Audio API, limite, moderare, librărie gratuită

Detaliile tehnice complete sunt deja documentate exhaustiv în nota internă `docs/research/31-audio.md` (verificată 2026-09-08, re-confirmată parțial aici pe 2026-09-10). Esențial pentru context:

- **Folosește noul Audio API de la început** (`AudioPlayer`/`Wire`/`AudioDeviceOutput`/`AudioFader`), nu `Sound` legacy — tutorialul oficial pentru cazul 2D/UI al Driftwood e deja scris pe noul API.
- **Trei buse de mixaj** (Music/SFX/Ambience), fiecare cu propriul `AudioFader`, cu slidere proprii în meniul jocului (Roblox nu expune un volum global accesibil din script).
- **Efectele au roluri directe pentru Driftwood**: `AudioEqualizer` — documentația dă explicit exemplul "underwater sound effects" (util dacă râul are zone subacvatice/scufundare); `AudioCompressor` — ducking automat (ambianța scade automat când sună un cue important de "plasă plină" sau notificare de trade); `AudioTremolo` — descris ca util pentru efecte "legate de vreme" (potrivit pentru sistemul de sezoane/vreme din brief, fără să fie nevoie de dezastre).
- **Limite de upload**: 100/2.000 fișiere per 30 zile (neverificat/ID-verificat) — folosește "audio sprites" via `PlaybackRegion` pentru variații scurte de SFX (ex. 4-5 variante de "prins ceva în plasă" într-un singur fișier), ca să nu epuizezi plafonul.
- **Librăria gratuită** (>100.000 piese/efecte, parteneri APM/Monstercat/Pro Sound Effects/Nettwerk/Position Music) e disponibilă direct din Creator Store, fără cost — bun punct de plecare pentru SFX generice de UI/impact înainte de a avea buget pentru sunet custom.

### 8. Fezabilitatea muzicii adaptive pe Roblox

Roblox **nu suportă middleware audio extern** (Wwise/FMOD nu se pot conecta ca plugin-uri, spre deosebire de Unity/Unreal) — orice logică adaptivă trebuie scrisă manual în Luau peste graful de `AudioPlayer`/`Wire`. Concret, fezabil pentru o echipă mică:

- **Horizontal re-sequencing (model Terraria/Subnautica): DA, ușor fezabil.** Un tabel Luau `{zonă, moment} -> assetId`, cu un `AudioPlayer` per bus care face `Stop()`/`Play()` sau crossfade prin tween pe `Volume`, la schimbare de zonă/oră/sezon.
- **Vertical layering simplu (2-3 straturi, ex. bază + strat de "urgență"): fezabil, cost mediu.** Fiecare strat e un `AudioPlayer` separat, toate pornite `Looping = true` din același `TimePosition` la începutul sesiunii de server (ca să rămână sincronizate), cu `Volume` crescut/scăzut prin tween când se schimbă contextul. Cere disciplină de producție muzicală (stem-urile trebuie compuse să se combine armonic), nu doar cod.
- **Mixaj live complex, multi-parametric (gen motoare AAA cu zeci de variabile): NU recomandat pentru o echipă mică** — costul de producție muzicală (compunerea a zeci de stem-uri variate) depășește rapid beneficiul, mai ales quando modelul mai simplu (Terraria) acoperă deja majoritatea nevoilor de "atmosferă pe zonă".

### 9. Memorie și constrângeri mobile — ce NU se știe

Nu există documentație publică Roblox despre comportamentul de streaming vs. încărcare completă în memorie pentru `AudioPlayer`/`ContentProvider`, și nici despre limite specifice de memorie audio pe mobil. Plafonul de 20MB/7min per fișier acționează ca o limită naturală per-asset, dar comportamentul cu **10+ `AudioPlayer` simultani** (3 buse + straturi de sezon + ambianță de zonă + SFX) pe un device mobil de gamă joasă **trebuie testat empiric** în Studio (Memory Profiler, `View > Performance`) înainte de a finaliza bugetul de straturi audio simultane — nu presupune că "mai multe straturi" e gratuit din perspectiva memoriei doar pentru că API-ul permite tehnic conectarea lor.

### 10. Plan concret de audio pentru Driftwood (joc co-op 2D de supraviețuire-orășel)

Propunere de arhitectură, combinând ce s-a "furat" mai jos:

1. **Trei buse native** (`AudioFader` Music / Ambience / SFX-UI → `AudioDeviceOutput`), volume separate persistate per jucător.
2. **Muzică — model Terraria simplificat**: un tabel `{zonă_hartă, sezon, moment_zi} -> assetId`, crossfade de 3-4 secunde la schimbare, fără vertical layering la lansare (adăugabil ulterior fără refactor arhitectural).
3. **Ambianță — model Subnautica reskin-uit "cozy"**: un loop continuu per zonă (râu, pădure, piață, interior de casă), calibrat manual în Studio cu `LoopRegion`; noaptea, ambianța se schimbă (greieri/liniște) mai degrabă decât "muzica de teamă" — păstrează tonul non-scary cerut de brief.
4. **Diegetic-informativ**: un set mic de stinger-uri unice de 1-3 secunde pentru evenimente mecanice ("plasă plină", "resursă gata de recoltat", "trade finalizat", "se apropie seara") — fiecare cu timbru distinct, declanșat o singură dată la prag, nu în buclă.
5. **Tensiune fără groază**: în loc de heartbeat/shriek (marcate explicit de Roblox ca fear-content), folosește `AudioEqualizer` (low-pass ușor, "sunet înfundat") și tempo ușor crescut pe ambianță pentru a semnala urgență (ex. resursă pe cale să dispară, timp limitat la un eveniment cooperativ) — fără conținut care ar declanșa disclosure de maturitate.
6. **Sprite audio**: variații de SFX (pași, recoltare, reparat) grupate câte 4-6 într-un singur fișier per categorie, selectate prin `PlaybackRegion`, pentru a conserva plafonul de upload.
7. **Sursare**: SFX de bază din Sonniss GDC Bundle + Roblox Creator Store (gratuit, zero risc legal); muzică originală de la un compozitor dedicat sau produsă intern, cu scopul explicit de a construi un "voice" recognoscibil (modelul Stardew), nu un mozaic de stock-tracks.
8. **Testare tehnică obligatorie înainte de a finaliza numărul de straturi simultane**: profilare de memorie pe un device mobil emulat cu toate busele + straturile de ambianță pornite simultan.

## Ce putem fura pentru Driftwood

1. **Tabel de selecție muzică zonă × moment (model Terraria)** — cost: **mic**. Doar date (assetId per combinație) + o funcție de crossfade; arhitectura Roblox (`AudioPlayer`/`Wire`/`AudioFader`) o suportă nativ.
2. **Ambianță continuă per zonă, calibrată cu `LoopRegion` (model Subnautica, reskin cozy)** — cost: **mic-mediu**. Necesită câteva loop-uri audio de bază (râu, pădure, piață) + timp de calibrare manuală a punctelor de loop.
3. **Stinger-uri diegetice unice pentru evenimente mecanice (model DST/Subnautica "Red Alert")** — cost: **mic**. 5-10 sunete scurte, unice per acțiune importantă (plasă plină, recoltă gata, seara se apropie).
4. **Ducking automat via `AudioCompressor`** — cost: **mic**. Ambianța/muzica scad automat volumul când sună un stinger important, fără cod complex de mixaj manual.
5. **Identitate muzicală de autor unic (model Stardew)** — cost: **mediu-mare** (buget pentru un compozitor dedicat sau timp intern semnificativ), dar cu potențial de recuperare pe termen lung (marketing, diferențiere, posibil merch/soundtrack extern) — dovedit de longevitatea comercială a soundtrack-ului Stardew (re-lansări și concerte la 7-9 ani de la lansare).
6. **Audio sprites via `PlaybackRegion`** — cost: **mic**. Reduce direct presiunea pe plafonul de upload lunar Roblox (100-2.000 fișiere/30 zile).
7. **EQ "subacvatic" pentru zonele de scufundare în râu** (exemplul oficial dat chiar de Roblox pentru `AudioEqualizer`) — cost: **mic**. Un singur nod de efect reutilizabil pentru orice zonă subacvatică din hartă.
8. **Straturi de "urgență" opționale peste ambianță (vertical layering minimal, 1-2 straturi)** pentru evenimente cooperative cu timp limitat — cost: **mediu**. Cere stem-uri compuse să se combine, dar arhitectura permite adăugarea ulterioară fără refactor.
9. **Soundtrack vândut/oferit separat ca material de comunitate (model Core Keeper — DLC soundtrack)** — cost: **mic** (dacă muzica există deja) — utilă ca gest de comunitate/marketing, nu neapărat monetizare directă pe Roblox.
10. **Sursare SFX gratuită și legal sigură din Sonniss + Creator Store Roblox** — cost: **mic** (timp de curatoriat, zero cost licență) — acoperă marea majoritate a nevoilor de bază înainte de a investi în sunet custom.

## Ce NU merge pentru noi

- **Heartbeat/shriek/jump-scare stingers (model de groază Subnautica/DST în forma lor originală)** — Roblox le clasifică explicit ca "mild fear-based content" ce cere disclosure de maturitate, iar brief-ul cere explicit ton non-scary, fără dezastre, pentru public tânăr. Riscul nu e doar de ton, ci de **discoverability/rating** pe platformă.
- **Vertical layering complex, multi-parametric** — costul de producție muzicală (zeci de stem-uri variate, sincronizate) depășește ce își poate permite o echipă mică, mai ales când modelul simplu (Terraria) acoperă deja nevoia de bază de "atmosferă pe zonă".
- **Middleware audio extern (Wwise/FMOD)** — nu se integrează cu Roblox/Luau; orice investiție de timp în a învăța aceste unelte nu se transferă direct pe platformă. Toată logica trebuie construită manual peste `AudioPlayer`/`Wire`.
- **Reutilizarea de `SoundId`-uri din alte jocuri/tutoriale Roblox** — de la 22 martie 2022, tot audio-ul altcuiva e privat by default (fapt deja documentat în nota internă 31-audio.md); planul de sursare trebuie să se bazeze pe upload propriu, Creator Store, sau surse externe licențiate corect.
- **Producție orchestrală/live la scară Stardew "Symphonic Tale"** — complet nerealist ca buget de pornire pentru o echipă mică; de păstrat, eventual, ca obiectiv post-lansare dacă jocul are succes financiar.
- **Voice acting extins / jurnale audio complexe (model PDA din Subnautica)** — costisitor de produs și de întreținut (traduceri, actori vocali), plus presiune suplimentară pe plafonul de upload audio; de evitat la scara unei echipe mici, cel puțin la lansare.

## Riscuri și necunoscute

- **WebSearch nu a fost disponibil în această sesiune** (buget de căutări epuizat la nivel de sesiune, partajat între mai mulți agenți de research care rulează în paralel pe acest proiect) — cercetarea de mai sus s-a bazat exclusiv pe `WebFetch` direct pe URL-uri cunoscute/ghicite (Wikipedia, wiki-uri comunitare, Steam, documentația Roblox) și pe nota internă deja verificată `31-audio.md`. Nu am putut face căutări exploratorii noi pentru surse primare suplimentare (GDC talks, interviuri de presă directe cu compozitorii).
- **Afirmația despre premiul "Excellence in Audio" 2014 pentru Don't Starve** apare pe pagina Wikipedia a jocului, dar NU apare în tabelul complet de câștigători IGF verificat separat — posibilă eroare/confuzie de sursă; de tratat ca NEVERIFICAT până la o a treia confirmare.
- **Termenii exacți de licență ai librăriei APM/Monstercat/etc. din Creator Store Roblox** (poate fi extras conținutul pentru trailer/marketing extern jocului?) rămân NEVERIFICAT — recomandare: verifică direct în Creator Hub la selectarea unei piese, nu presupune.
- **Comportamentul de memorie/streaming pe mobil pentru multe `AudioPlayer` simultane** e complet nedocumentat public — planul de straturi audio de mai sus trebuie validat empiric (Memory Profiler în Studio) înainte de a fi considerat final, mai ales pe device-uri de gamă joasă.
- **Sursele secundare (wiki-uri comunitare: dontstarve.wiki.gg, terraria.wiki.gg, wiki.subnautica.com) nu au putut fi cross-verificate** cu o a doua sursă independentă pentru fiecare detaliu tehnic (praguri exacte Sanity, cue-uri exacte Subnautica) — sunt marcate cu încredere "medie", nu "ridicata".
- **Detaliile despre sistemul muzical al Core Keeper** (adaptiv sau nu, per-biomă exact) nu au putut fi confirmate — pagina wiki dedicată a întors erori de acces în timpul cercetării.
- **Prețurile exacte pentru Epidemic Sound/Artlist și pentru Wwise/FMOD (praguri de venit pentru tier-ul gratuit)** nu au putut fi extrase din paginile oficiale (erori 403/pagini goale la fetch) — decizia de mai sus (evită middleware extern) face acest detaliu mai puțin critic, dar merită o verificare directă dacă echipa reconsideră vreodată un motor non-Roblox.

## Surse

- Wikipedia — „Stardew Valley": https://en.wikipedia.org/wiki/Stardew_Valley (recuperat 2026-09-10)
- Wikipedia — „Don't Starve": https://en.wikipedia.org/wiki/Don%27t_Starve (recuperat 2026-09-10)
- Wikipedia — „Terraria": https://en.wikipedia.org/wiki/Terraria (recuperat 2026-09-10)
- Wikipedia — „Core Keeper": https://en.wikipedia.org/wiki/Core_Keeper (recuperat 2026-09-10)
- Wikipedia — „Video game music" (istoric muzică adaptivă, iMuse, SSX, Frogger, Dig Dug): https://en.wikipedia.org/wiki/Video_game_music (recuperat 2026-09-10)
- Wikipedia — „Independent Games Festival" (verificare/contra-verificare premiu Don't Starve): https://en.wikipedia.org/wiki/Independent_Games_Festival (recuperat 2026-09-10)
- dontstarve.wiki.gg — „Sanity" (wiki comunitar, secundar): https://dontstarve.wiki.gg/wiki/Sanity (recuperat 2026-09-10)
- terraria.wiki.gg — „Music" (wiki comunitar, secundar): https://terraria.wiki.gg/wiki/Music (recuperat 2026-09-10)
- wiki.subnautica.com — „Music" (wiki comunitar, secundar): https://wiki.subnautica.com/sn/Music (recuperat 2026-09-10)
- Steam — Don't Starve Together: https://store.steampowered.com/app/322330/Dont_Starve_Together/ (recuperat 2026-09-10)
- Steam — Terraria: https://store.steampowered.com/app/105600/Terraria/ (recuperat 2026-09-10)
- Steam — Core Keeper: https://store.steampowered.com/app/1621690/Core_Keeper/ (recuperat 2026-09-10)
- Sonniss — GameAudioGDC bundle: https://sonniss.com/gameaudiogdc (recuperat 2026-09-10)
- Incompetech (Kevin MacLeod): https://incompetech.com/ (recuperat 2026-09-10)
- Roblox Creator Documentation — Audio index: https://create.roblox.com/docs/audio (recuperat 2026-09-10)
- Roblox Creator Documentation — Sound (legacy): https://create.roblox.com/docs/sound (recuperat 2026-09-10)
- Roblox Creator Documentation — Audio objects: https://create.roblox.com/docs/audio/objects (recuperat 2026-09-10)
- Roblox Creator Documentation — Audio effects: https://create.roblox.com/docs/audio/effects (recuperat 2026-09-10)
- Roblox Creator Documentation — Audio assets (limite upload, formate, librărie licențiată): https://create.roblox.com/docs/audio/assets (recuperat 2026-09-10)
- Roblox Creator Documentation — Experience guidelines (content maturity, fear-based content): https://create.roblox.com/docs/production/promotion/experience-guidelines (recuperat 2026-09-10)
- Roblox Engine API Reference — AudioPlayer: https://create.roblox.com/docs/reference/engine/classes/AudioPlayer (recuperat 2026-09-10)
- Roblox Engine API Reference — Wire: https://create.roblox.com/docs/reference/engine/classes/Wire (recuperat 2026-09-10)
- Notă internă Driftwood (deja verificată, refolosită ca sursă pentru secțiunea Roblox): `docs/research/31-audio.md` (recuperat/verificat original 2026-09-08)
