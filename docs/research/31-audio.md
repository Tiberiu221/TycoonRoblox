# Audio în Roblox: reguli, librărie, noul Audio API — note pentru Driftwood

## Rezumat executiv

- Roblox are acum **două sisteme audio paralele, ambele suportate**: `Sound` clasic (numit intern „LegacySound") și noul **Audio API** (`AudioPlayer` / `AudioEmitter` / `AudioListener` / `AudioDeviceOutput` / `Wire` / efecte). Tutorialele oficiale curente (2026) pentru sunet 2D folosesc deja noul Audio API, nu `Sound` clasic.
- Pentru Driftwood (joc 2D pur în `ScreenGui`), sunetul „2D" (non-spatial) e tratat oficial ca UI audio: `AudioPlayer → Wire → AudioDeviceOutput`, iar exemplul oficial chiar parentează un `AudioPlayer` direct sub `StarterGui`. Nu ai nevoie de `AudioEmitter`/`AudioListener` (acelea sunt pentru poziționare 3D).
- Limitele actuale de upload audio (documentate live, 2026): **100 fișiere gratuite/30 zile** pentru cont neverificat, **2.000/30 zile** pentru cont ID-verificat. Astea sunt semnificativ mai mari decât limita istorică de **10/lună** discutată pe DevForum între 2023 și aprilie 2025 — pare o creștere de politică relativ recentă, nedatată exact în documentație.
- Fișier audio: max **20 MB**, max **7 minute**, sample rate ≤ **48 kHz**, format `.mp3`, `.ogg`, `.wav` sau `.flac`, mono/stereo/3.0/5.1.
- Din **22 martie 2022**, tot audio nou încărcat e **privat by default**, iar tot audio existent mai lung de **6 secunde** a fost trecut automat pe privat. Nu mai poți refolosi `SoundId`-uri ale altor creatori decât dacă aceștia le-au făcut explicit publice (Creator Store) sau le-ai încărcat tu însuți.
- Roblox oferă o librărie audio oficială gratuită de peste **100.000 de piese/efecte** licențiate de la **APM, Monstercat, Pro Sound Effects, Nettwerk Music Group și Position Music**, disponibilă prin Toolbox/Creator Store — nu e afectată de schimbarea de privacy din 2022.
- Din mai 2024 există **„Public Sound Effects Upload"**: creatorii ID-verificați, 13+, cu cont curat pot distribui gratuit pe Creator Store efecte sonore **sub 10 secunde** (nu muzică, nu voce) — utilă pentru a construi bibliotecă proprie reutilizabilă între proiecte.
- Nu există (verificat) un slider nativ de volum Music/SFX expus jocurilor de Roblox — `UserGameSettings.MasterVolume` există dar e marcat `RobloxScriptSecurity`, deci Driftwood trebuie să-și construiască propriul meniu de volum și să-l persiste singur.
- `AudioPlayer` are `PlaybackRegion`/`LoopRegion` (un `NumberRange`) — poți încărca **un singur fișier lung cu mai multe sunete** și selecta segmentul de redat, tehnică de tip „sprite audio" care reduce drastic numărul de asset-uri distincte încărcate (relevant dat fiind plafonul lunar).

## Fapte verificate

- Limitele de upload audio curente: **100 fișiere/30 zile** (neverificat), **2.000 fișiere/30 zile** (ID-verificat), fără cost în Robux. — sursă: https://create.roblox.com/docs/audio/assets — data recuperării: 2026-09-08 — încredere: ridicata
- Fișier audio permis: **<20 MB**, **<7 minute**, sample rate **≤48 kHz**, format **.mp3/.ogg/.wav/.flac**, mono sau stereo/3.0/5.1. — sursă: https://create.roblox.com/docs/audio/assets — 2026-09-08 — ridicata
- Documentația spune explicit că poți „import audio assets that you're certain you have permission to use" (răspunderea legală a licenței cade pe creator). — sursă: https://create.roblox.com/docs/audio/assets — 2026-09-08 — ridicata
- Pe 22 martie 2022, tot audio nou încărcat a devenit privat by default, iar tot audio existent mai lung de 6 secunde a fost setat automat privat; experiențele care foloseau `SoundId`-uri ale altor creatori s-au rupt dacă acel audio nu era încărcat de același user/grup. — sursă: DevForum, „[Action Needed] Upcoming Changes to Asset Privacy for Audio", topic id 1701697, https://devforum.roblox.com/t/1701697 — 2022-03-09 — ridicata
- Ca urmare a schimbării de mai sus, Roblox a oferit un plugin **Audio Discovery** în Studio pentru a audita ce audio dintr-un proiect nu mai e valid, plus un follow-up cu instrucțiuni. — sursă: DevForum, „[Update] Changes to Asset Privacy for Audio", topic id 1715717, https://devforum.roblox.com/t/1715717 — 2022-03-16 — ridicata
- Rămân publice/utilizabile fără să fi fost încărcate de tine: audio sub 6 secunde (grandfathered) și catalogul licențiat oficial (**APM, Monstercat, Pro Sound Effects, Nettwerk Music Group, Position Music**, >100.000 piese/efecte). — sursă: DevForum topic 1701697 — 2022-03-09 — ridicata
- „Public Sound Effects Upload": creatorii pot distribui gratuit pe Creator Store efecte sonore **sub 10 secunde**, doar SFX (nu muzică/voce), condiționat de 13+, ID-verificare și cont în regulă; procesul se face din Creator Hub → Creations → Audio, cu opțiune „Distribute on Creator Store"; alți dezvoltatori trebuie să adauge sunetul respectiv în inventarul propriu înainte să-l poată folosi, iar grant-ul e per-user, nu se extinde automat la colaboratorii Team Create. — sursă: DevForum, „Public Sound Effects Upload Are Now Available for Creators", topic id 2980704, https://devforum.roblox.com/t/2980704 — 2024-05-23 — ridicata
- Istoric, limita implicită de upload audio a fost **10 fișiere/lună**, considerată „extrem de mică" de comunitate; o cerere de feature pentru limite mai mari + opțiuni plătite a fost deschisă în aprilie 2025 și era încă activă (ultimul răspuns) în iulie 2026, fără confirmare oficială de opțiune plătită implementată. — sursă: DevForum, „Increase Default Audio Upload Limits and Offer Paid Options", topic id 3629892, https://devforum.roblox.com/t/3629892 — creat 2025-04-28, ultima activitate 2026-07-08 — medie (limita curentă documentată e deja 100/2000, deci pare rezolvată parțial, dar nedatat exact)
- Noul **Audio API** a intrat în beta public cu instanțe precum `AudioPlayer`, `AudioEmitter`, `AudioListener`, `Wire`, efecte (`AudioReverb`, `AudioCompressor`, `AudioEqualizer`, `AudioChorus`, `AudioPitchShifter`, `AudioFader`, `AudioAnalyzer`) și `AudioDeviceInput`/`AudioDeviceOutput`; se activa din Studio Beta Features. — sursă: DevForum, „New Audio API [Beta]: Elevate Sound and Voice in Your Experiences", https://devforum.roblox.com/t/new-audio-api-beta-elevate-sound-and-voice-in-your-experiences — 2024-02-22 — ridicata
- Tutorialul oficial curent „Add 2D audio" folosește deja `AudioPlayer → Wire → AudioDeviceOutput` (nu `Sound` clasic) pentru muzică de fundal, feedback de gameplay și **sunete de UI**, inclusiv un exemplu cu `AudioPlayer` parentat direct sub `StarterGui > 2DAudioButton`. — sursă: https://create.roblox.com/docs/tutorials/use-case-tutorials/audio/add-2D-audio — 2026-09-08 — ridicata
- Clasa `Sound` e documentată explicit ca implementare „LegacySound", cu metode/proprietăți lowercase marcate deprecated — semn că Roblox tratează `Sound` ca fiind „vechi", dar rămâne complet funcțională, fără dată de eliminare anunțată. — sursă: https://create.roblox.com/docs/reference/engine/classes/Sound — 2026-09-08 — medie
- `AudioPlayer` are proprietăți `LoopRegion` și `PlaybackRegion` (ambele `NumberRange`), plus `Looping`, `PlaybackSpeed`, `TimePosition`, `TimeLength`; asta permite loop-uri cu puncte exacte și „sprite-uri audio" (mai multe sunete într-un singur fișier, selectate prin regiune). — sursă: https://create.roblox.com/docs/reference/engine/classes/AudioPlayer — 2026-09-08 — ridicata
- `Wire` conectează două obiecte audio prin `SourceInstance`/`TargetInstance`; efectele (ex. `AudioFader`, `AudioEqualizer`) pot primi mai mulți `AudioPlayer` prin wire-uri diferite, ceea ce le face utilizabile ca „bus"-uri de mixaj (echivalentul `SoundGroup`). — sursă: https://create.roblox.com/docs/audio/effects și https://create.roblox.com/docs/reference/engine/classes/Wire — 2026-09-08 — medie (arhitectura e clar documentată; termenul „bus" e interpretarea mea, nu termen oficial)
- `SoundGroup` clasic are proprietatea `Volume` și poate primi efecte (ex. `ReverbSoundEffect`) ca și copii; `Sound.SoundGroup` rutează un sunet clasic către un grup. — sursă: https://create.roblox.com/docs/reference/engine/classes/SoundGroup — 2026-09-08 — medie (documentația extrasă a fost parțială)
- `UserGameSettings` expune `MasterVolume`, `MasterVolumeStudio`, `PartyVoiceVolume`, `VoiceChatVolume`, dar toate marcate cu securitate `RobloxScriptSecurity` — nu par accesibile din LocalScript-uri normale de joc. — sursă: https://create.roblox.com/docs/reference/engine/classes/UserGameSettings — 2026-09-08 — medie
- Nu am găsit în documentație streaming/limite de memorie audio explicite pentru `ContentProvider`/`PreloadAsync`; comportamentul intern (streaming vs. load-in-memory) nu e specificat public. — NEVERIFICAT — https://create.roblox.com/docs/reference/engine/classes/ContentProvider — 2026-09-08 — scazuta
- Rate-limit-urile Open Cloud API pentru `CreateAsset` (audio via API, nu Studio) nu sunt centralizate pe pagina generală de rate limits; documentația trimite la limite per-endpoint și avertizează că „additional, undocumented limits may apply". Există indicii de comunitate (thread din 2023 și ianuarie 2026) despre un plafon separat, mai mic (~9-10/lună) pentru upload audio via Open Cloud API, diferit de plafonul din Studio. — NEVERIFICAT exact — https://create.roblox.com/docs/cloud/reference/rate-limits — 2026-09-08 — scazuta

## Detalii

### 1. Reguli de upload audio (gratuit/plătit, limite, formate, moderare)

Sursa oficială curentă e `create.roblox.com/docs/audio/assets`. Rezumat cu numere exacte:

| Parametru | Valoare | Sursă |
|---|---|---|
| Upload gratuit — cont neverificat | 100 fișiere / 30 zile | create.roblox.com/docs/audio/assets |
| Upload gratuit — cont ID-verificat | 2.000 fișiere / 30 zile | create.roblox.com/docs/audio/assets |
| Cost Robux | 0 (în limita gratuită) | create.roblox.com/docs/audio/assets |
| Dimensiune maximă fișier | < 20 MB | create.roblox.com/docs/audio/assets |
| Durată maximă | < 7 minute | create.roblox.com/docs/audio/assets |
| Sample rate maxim | ≤ 48 kHz | create.roblox.com/docs/audio/assets |
| Canale acceptate | mono, stereo 2.0, 3.0, 5.1 surround | create.roblox.com/docs/audio/assets |
| Formate acceptate | .mp3, .ogg, .wav, .flac | create.roblox.com/docs/audio/assets |
| Limită „Public Sound Effects Upload" | < 10 secunde, doar SFX (nu muzică/voce) | DevForum topic 2980704 (2024-05-23) |

Fluxul de moderare: Studio transcodează fișierul la import; fișierele corupte sau cu headere invalide sunt respinse la acest pas. După import, asset-ul intră în moderare (automată + probabil manuală pentru copyright), iar pentru distribuție publică pe Creator Store trece printr-un „sound effect classifier" — deciziile de moderare pe efecte sonore **nu sunt contestabile** ("not appealable", conform topicului 2980704).

Notă istorică importantă: între cel puțin 2023 și aprilie 2025, comunitatea discuta o limită implicită de **10 uploaduri/lună**, considerată foarte restrictivă, cu o cerere oficială de creștere + opțiuni plătite rămasă deschisă (fără status „Implemented" confirmat) până cel puțin iulie 2026. Limita curentă din documentație (100/2.000 per 30 zile) e mult mai generoasă — fie politica s-a schimbat între timp, fie documentele vechi de pe DevForum reflectă un plafon diferit (posibil per tip de cont/vechime). **Recomandare: verifică plafonul exact în Creator Hub → Creations → Audio la momentul producției**, nu te baza doar pe acest document.

### 2. Schimbarea de privacy din 2022 — refolosirea sunetelor altor creatori

Context: Roblox a fost ținta unor investigații jurnalistice despre muzică protejată prin copyright reîncărcată deghizat (pitch/speed shift) pentru a păcăli moderarea, plus un proces al National Music Publishers' Association (NMPA) intentat în iunie 2021 și retras în septembrie 2021, cu o colaborare formată ulterior (sursă secundară: Wikipedia, verificat 2026-09-08 — nu am găsit un articol de presă primar cu data exactă, deci consider acest context ca fundal, nu ca fapt de citat separat).

Ce s-a schimbat concret, pe 22 martie 2022 (sursă: DevForum topic 1701697):
- Tot audio **nou încărcat** devine **Private by default**.
- Tot audio **existent mai lung de 6 secunde** a fost trecut automat pe Private.
- Metadatele (nume, descriere) rămân vizibile, dar conținutul audio propriu-zis nu mai e accesibil altor useri/grupuri decât uploaderul original.
- Experiențele care refereau `SoundId`-uri încărcate de alți creatori (comun în „boombox"-uri, jukebox-uri, playlist-uri custom) s-au rupt dacă acel audio nu era încărcat de contul/grupul care deține experiența.
- Excepții rămase publice: audio ≤6 secunde (grandfathered) și catalogul licențiat oficial Roblox (APM, Monstercat, Pro Sound Effects, Nettwerk Music Group, Position Music).
- Roblox a lansat un plugin **Audio Discovery** (Studio) pentru a audita ce ID-uri audio dintr-un loc/joc nu mai sunt valide (DevForum topic 1715717, 2022-03-16).

**Implicație directă pentru Driftwood:** nu poți lua un `SoundId` de pe YouTube-to-Roblox converters, dintr-un alt joc, sau dintr-un tutorial vechi și să-l folosești direct — dacă nu a fost făcut public explicit (ex. via „Public Sound Effects Upload" din 2024) sau nu e din librăria oficială, nu va funcționa. Regula practică: **fie încarci tu tot audio-ul (pe contul/grupul Driftwood), fie folosești exclusiv Creator Store/librăria oficială, fie folosești surse externe CC0/licențiate pe care le încarci tu.**

### 3. Librăria audio gratuită Roblox și licențierea (APM etc.)

Din 2022, Roblox oferă acces la un catalog licențiat de peste **100.000 de piese muzicale și efecte sonore** produse profesionist, prin parteneriate cu **APM Music, Monstercat, Pro Sound Effects, Nettwerk Music Group și Position Music** (sursă: DevForum topic 1701697, 2022-03-09; confirmat și indirect de create.roblox.com/docs/audio care menționează „the Creator Store" cu „more than 100,000 professionally-produced sound effects and music tracks", recuperat 2026-09-08).

Termeni de licențiere (interpretare pe baza documentației disponibile, **NEVERIFICAT** în detaliu contractual): conținutul e utilizabil **în interiorul experiențelor Roblox**, fără cost suplimentar, fără atribuire vizibilă necesară în UI (nu am găsit o cerință explicită de atribuire în text) — dar nu am găsit textul integral al termenilor de licență APM/Monstercat/etc. pe o pagină publică fetch-uibilă. **Recomandare: nu presupune că poți extrage/folosi aceste piese în afara Roblox (trailer YouTube, Discord etc.) — tratează-le ca „doar în engine" până verifici explicit termenii din Creator Hub.**

### 4. Surse externe SFX/muzică (CC0, pachete comerciale)

Nu există o pagină Roblox oficială dedicată listării surselor externe recomandate — asta ține de practica generală de game dev, nu de regulile platformei. Regula Roblox relevantă e cea deja citată: **"import audio assets that you're certain you have permission to use"** (create.roblox.com/docs/audio/assets) — responsabilitatea legală a licenței rămâne integral la uploader (Driftwood), Roblox nu verifică proveniența, doar moderarea de conținut/copyright-matching automat.

Surse tipice pentru echipe mici (cunoștințe generale de industrie, **nu specifice Roblox**, tratate ca atare):
- **CC0 / domeniu public:** freesound.org (filtrat după licența CC0), Kenney.nl (assets audio CC0, inclusiv pachete SFX de tip UI/impact/water), OpenGameArt.org.
- **Pachete comerciale cu licență „game dev" perpetuă:** Zapsplat (abonament), Sonniss GDC Bundle-uri (gratuite anual, licență foarte permisivă „use in any project"), asset store-uri specializate (ex. pachete de „river/water ambience", „mechanical repair SFX").

În toate cazurile: păstrează dovada licenței (factură, fișier LICENSE, link) separat de proiect, pentru că Roblox NU stochează sau verifică sursa — dacă apare o contestație de copyright, dovada e responsabilitatea ta.

### 5. Noul Audio API vs `Sound` clasic

Roblox rulează în paralel două sisteme complet funcționale:

**A. `Sound` clasic (SoundService / SoundGroup)** — modelul „un obiect, o redare", cu `Sound.SoundId`, `Sound:Play()`, parentat sub `SoundService`, `Workspace`, sau orice `Instance`. Documentat ca „LegacySound" intern, cu unele metode/proprietăți lowercase deprecated, dar complet suportat (create.roblox.com/docs/reference/engine/classes/Sound, 2026-09-08).

**B. Noul Audio API** — model de graf de noduri audio: `AudioPlayer` (sursă), `AudioEmitter`/`AudioListener` (poziționare 3D — nu e nevoie pentru Driftwood), `AudioDeviceOutput`/`AudioDeviceInput` (I/O fizic), efecte (`AudioEqualizer`, `AudioCompressor`, `AudioReverb`, `AudioChorus`, `AudioDistortion`, `AudioEcho`, `AudioFlanger`, `AudioPitchShifter`, `AudioTremolo`, `AudioFader`, `AudioAnalyzer`), toate conectate prin instanțe `Wire` (proprietăți `SourceInstance`/`TargetInstance`). A intrat în beta public pe 22 februarie 2024 (DevForum, „New Audio API [Beta]"), cu extensii ulterioare („Directional Audio, AudioLimiter and More", DevForum, 2024-12-02).

Diferențe practice cheie față de `Sound`:
- Un singur `AudioPlayer` poate fi rutat, prin mai multe `Wire`-uri, către mai mulți emițători simultan — cu `Sound` clasic trebuia duplicat obiectul pentru fiecare locație.
- `AudioPlayer` are `LoopRegion`/`PlaybackRegion` (`NumberRange`) — control fin la eșantion/secundă pentru loop-uri și pentru „sprite-uri audio" (mai multe sunete scurte într-un singur fișier uploadat).
- `AudioPlayer:GetWaveformAsync()` — acces la forma de undă (util pentru UI de tip music-visualizer, dacă vrei asta pentru „river ambience" vizual).
- Efectele (inclusiv un `AudioFader` folosit ca bus de volum) pot primi input de la mai mulți `AudioPlayer` diferiți prin wire-uri separate — echivalentul funcțional al unui `SoundGroup`, dar mai flexibil (poți înlănțui EQ → Compressor → Fader → Output).

**Recomandare pentru Driftwood:** pornește direct cu noul Audio API. Motiv: tutorialul oficial curent pentru „2D audio" (cazul exact al Driftwood) e scris deja cu `AudioPlayer`/`Wire`/`AudioDeviceOutput`, nu cu `Sound`. Înveți sistemul „viitor" o singură dată, nu mai migrezi ulterior.

### 6. Mixaj: SoundGroup vs graf Audio API

`SoundGroup` (clasic): instanță cu proprietate `Volume`, parentată de obicei sub `SoundService`; orice `Sound.SoundGroup` setat către acel grup e afectat de `Volume`-ul grupului; efecte (ex. `ReverbSoundEffect`) pot fi adăugate ca și copii ai `SoundGroup`-ului (create.roblox.com/docs/reference/engine/classes/SoundGroup, 2026-09-08 — documentație parțială extrasă, doar `Volume` confirmat explicit).

Graf Audio API (nou): nu există un „SoundGroup" dedicat — pattern-ul e să creezi un nod de efect (tipic `AudioFader`, eventual `AudioEqualizer`) per „bus" (Music/SFX/Ambience), să legi toți `AudioPlayer`-ii din acea categorie la acel nod prin `Wire`, apoi să legi nodul mai departe la `AudioDeviceOutput`. Volumul busului se controlează dintr-un singur loc (proprietatea de volum a efectului/faderului). Asta e recomandarea mea bazată pe modul documentat în care efectele acceptă input de la mai multe surse (create.roblox.com/docs/audio/effects, 2026-09-08) — Roblox nu numește explicit acest pattern „bus", dar arhitectura tehnică îl suportă direct.

### 7. Redare din context `ScreenGui` (2D, non-spatial)

Confirmat oficial: tutorialul „Add 2D audio" (create.roblox.com/docs/tutorials/use-case-tutorials/audio/add-2D-audio, 2026-09-08) folosește exact structura relevantă pentru Driftwood:
- Muzică de fundal în loop: `AudioPlayer`/`Wire`/`AudioDeviceOutput` parentate sub `SoundService`.
- Feedback de gameplay (colectare obiect): aceeași structură, parentată lângă obiectul din `Workspace` (nu se aplică 1:1 la Driftwood, care e 2D pur fără `Workspace` — parentează în schimb lângă structura ta de date/`Folder` din client).
- **Sunete de UI (buton apăsat):** `AudioPlayer`/`Wire`/`AudioDeviceOutput` parentate direct sub `StarterGui > 2DAudioButton`, declanșate dintr-un `LocalScript` la evenimentul `Activated` al butonului.

„2D audio" e definit oficial ca „non-directional sound that doesn't emit from any particular location, remaining the same regardless of a listener's position" — exact ce vrei pentru orice sunet din Driftwood, pentru că nu ai poziționare 3D deloc.

Cod ilustrativ (bazat pe pattern-ul din tutorial, adaptat):

```lua
-- LocalScript sub un buton ScreenGui (ex: Frame_Repair > Button_Confirm)
local button = script.Parent
local audioPlayer = button:WaitForChild("AudioPlayer") -- AudioPlayer -> Wire -> AudioDeviceOutput, deja legate în Studio

button.Activated:Connect(function()
    audioPlayer:Play()
end)
```

### 8. Loop-uri fără cusătură și straturi pe sezon

Nu există un articol oficial dedicat exclusiv acestui subiect; recomandarea de mai jos combină proprietăți confirmate ale `AudioPlayer` (`Looping`, `LoopRegion`, `PlaybackSpeed`, `TimePosition`) cu practică standard de game audio:

- **Loop fără cusătură:** setează `AudioPlayer.Looping = true` și `LoopRegion` la exact punctele de start/sfârșit din fișierul sursă (evită tăierea "la ureche" din DAW — folosește `LoopRegion` ca sursă de adevăr, nu trim manual pe fișier, ca să poți itera fără re-upload).
- **Straturi pe sezon (vară/iarnă, conform sistemului de sezoane din brief):** un `AudioPlayer` per strat, toate legate prin `Wire` la același bus `AudioFader` de „Music", toate pornite simultan cu `Looping = true`, dar cu `Volume` la 0 pentru straturile inactive; la schimbarea de sezon, faci un crossfade (tween pe `Volume`, câteva secunde) în loc de tăiere bruscă — evită capcana „toate straturile trebuie să fie perfect sincron în fază", pentru că pornesc din același `TimePosition` de la începutul sesiunii de server.
- **Sprite audio pentru SFX scurte multiple:** dat fiind plafonul de upload/30 zile, ia în calcul să încarci UN singur fișier lung cu mai multe SFX (ex: 5 variații de „prins în plasă") și să selectezi segmentul prin `PlaybackRegion`, reducând 5 asset-uri la 1.

### 9. Volum mobil, memorie/streaming, opțiuni de mute

- **Volum mobil implicit:** nu am găsit o sursă oficială care să specifice un volum implicit diferit pe mobil vs. desktop pentru experiențe Roblox — **NEVERIFICAT**. Ce e confirmat: `UserGameSettings` expune `MasterVolume` etc., dar cu `RobloxScriptSecurity`, deci probabil inaccesibil din LocalScript-uri normale de joc (create.roblox.com/docs/reference/engine/classes/UserGameSettings, 2026-09-08) — Driftwood nu se poate baza pe citirea volumului global al playerului.
- **Memorie/streaming audio:** nedocumentat public în ce am putut verifica (`ContentProvider`/`PreloadAsync` — **NEVERIFICAT** dacă audio-ul se streamuiește sau se încarcă integral în memorie). Plafonul de 20 MB/7 min per fișier acționează oricum ca limită naturală per-asset.
- **Mute options:** nu există un API standard prin care jocul „ascultă" dacă playerul a dat mute din setările native Roblox. Concluzie practică: **Driftwood trebuie să-și construiască propriul meniu de audio (Music/SFX/Ambience, slidere separate), cu valori persistate** (DataStore sau, minim, `localStorage`-echivalent pe client — dar preferabil server-side dacă vrei sincronizare cross-device).

## Recomandari concrete pentru Driftwood

1. **Folosește noul Audio API de la început** (`AudioPlayer`/`Wire`/`AudioDeviceOutput`/`AudioFader`), nu `Sound` clasic. Motiv: tutorialul oficial pentru cazul exact al Driftwood (2D, UI) e scris deja pe noul API; înveți o singură dată sistemul recomandat curent.
2. **Construiește 3 bus-uri de mixaj** (`Music`, `SFX`, `Ambience`), fiecare cu propriul `AudioFader` legat la `AudioDeviceOutput`; toți `AudioPlayer`-ii relevanți se leagă prin `Wire` la bus-ul lor. Expune 3 slidere în meniul de setări al Driftwood, salvate în `DataStore` per jucător.
3. **Parentează toate `AudioPlayer`-ele de UI direct în ierarhia `ScreenGui`** (ex. `ScreenGui > SFX > Catch_AudioPlayer`), exact ca în exemplul oficial `StarterGui > 2DAudioButton` — păstrează logica audio lângă elementul vizual care o declanșează, ușor de întreținut într-un proiect 100% ScreenGui.
4. **Fă „sprite-uri audio"**: grupează variații scurte (ex. 4-5 variante de sunet „prins în plasă", variante de „țăcănit reparație") într-un singur fișier per categorie, selectate prin `AudioPlayer.PlaybackRegion`. Reduce numărul de asset-uri distincte încărcate, relevant dat fiind plafonul lunar (100 sau 2.000/30 zile).
5. **Ia ID verificarea contului/studioului devreme** (deblochează 2.000 vs 100 uploaduri/30 zile) — pentru un joc cu minim 200 obiecte de reparat (din brief) plus variații de sunet per obiect, plafonul de 100 se poate epuiza rapid dacă nu faci sprite audio.
6. **Muzica de sezon = straturi crossfade, nu track-uri separate care se opresc/pornesc brusc.** Toate straturile (vară/iarnă) pornesc `Looping = true` simultan din server-start, cu `Volume` tween-uit la schimbarea de sezon — evită artefacte de fază/sincronizare.
7. **Ambianța de râu ca strat continuu, separat de muzică**, pe bus-ul `Ambience`, cu `Looping = true` și `LoopRegion` calibrat manual în Studio (ascultă loop-ul de câteva ori înainte de a-l considera final — nu te baza pe tăiere „la ochi" în DAW).
8. **Nu refolosi `SoundId`-uri din tutoriale vechi/alte jocuri.** De la 22 martie 2022, audio-ul altcuiva e privat by default — fie încarci tu tot, fie folosești explicit Creator Store (librăria APM/Monstercat/etc. sau SFX publice ale altor creatori marcate distribuibile).
9. **Documentează sursa și licența pentru fiecare asset audio extern** (CC0/pachet comercial) într-un fișier separat de proiect — Roblox nu verifică proveniența, responsabilitatea legală e integral a echipei Driftwood.
10. **Nu te baza pe citirea volumului global Roblox al playerului** (`UserGameSettings.MasterVolume` pare inaccesibil din script normal) — construiește slider-e proprii cu valori implicite rezonabile (ex. Music 50%, SFX 70%, Ambience 40%) mai degrabă decât să presupui vreun comportament implicit al platformei.

## Riscuri si necunoscute

- **Discrepanța de plafon (10/lună istoric vs. 100-2.000/30 zile curent)** nu e datată exact — dacă echipa a citit vreun ghid mai vechi (2023-2024) și a bugetat pe baza limitei de 10/lună, planificarea de asset-uri ar putea fi complet greșită în ambele direcții. Trebuie verificat live în Creator Hub la momentul producției.
- **Licența exactă a librăriei oficiale (APM/Monstercat/etc.)** nu a putut fi confirmată textual (doar existența parteneriatului și numărul de piese). Riscul: presupunerea greșită că poți exporta/folosi aceste piese în marketing extern (trailer, social media) când s-ar putea să fie licențiate doar „in-engine".
- **Streaming vs. load-in-memory pentru audio** rămâne nedocumentat public — pentru un joc cu multe SFX + straturi de muzică simultane, comportamentul de memorie la runtime trebuie testat empiric în Studio (profiler de memorie), nu presupus.
- **Plafonul separat pentru Open Cloud API** (upload automatizat/CI) pare să existe și să fie mai mic decât plafonul din Studio, dar numărul exact nu a putut fi confirmat dintr-o pagină oficială — relevant dacă echipa (dezvoltator experimentat, obișnuit cu CI/CD) vrea să automatizeze upload-ul de asset-uri audio.
- **`Sound` clasic marcat „Legacy" intern** dar fără dată de eliminare — riscul opus (a nu folosi noul API) e mic pe termen scurt, dar proiectul ar trebui să evite construirea de infrastructură audio grea pe `Sound` clasic dacă echipa oricum pornește de la zero acum.

## Intrebari deschise

1. Care e plafonul EXACT de upload audio pentru contul/grupul Driftwood chiar acum (Creator Hub → Creations → Audio) — coincide cu 100/2.000 sau diferă?
2. Merită ID-verificarea acum, în faza de prototip, sau se poate amâna până aproape de lansare (dat fiind că prototipul din brief cere „un tip de obiect" inițial, deci volum mic de audio)?
3. Termenii de licență ai librăriei APM/Monstercat din Creator Store permit extragerea audio pentru trailer/marketing extern jocului, sau strict in-engine? (De verificat direct în Creator Hub la selectarea unei piese — de obicei apare un link „License" pe fiecare asset.)
4. Comportamentul real de memorie/streaming pentru 10+ `AudioPlayer`-e simultane (straturi de sezon + ambianță + SFX) — de testat în Studio cu Memory Profiler (`View > Performance`), nu de presupus.
5. Există un plafon separat, mai mic, pentru upload audio prin Open Cloud API față de Studio manual? Relevant doar dacă echipa vrea pipeline automatizat de asset-uri (CI/CD pentru audio).
6. Ce valori implicite de volum (Music/SFX/Ambience) simt bine în playtest real pe mobil vs. desktop — nu există recomandare oficială Roblox, deci e o decizie 100% de design/UX pentru Driftwood, testabilă doar empiric.

## Surse

- Roblox Creator Documentation — Audio asset specs: https://create.roblox.com/docs/audio/assets (recuperat 2026-09-08)
- Roblox Creator Documentation — Audio objects (Audio API): https://create.roblox.com/docs/audio/objects (recuperat 2026-09-08)
- Roblox Creator Documentation — Audio effects: https://create.roblox.com/docs/audio/effects (recuperat 2026-09-08)
- Roblox Creator Documentation — Audio index: https://create.roblox.com/docs/audio (recuperat 2026-09-08)
- Roblox Creator Documentation — Tutorial „Add 2D audio": https://create.roblox.com/docs/tutorials/use-case-tutorials/audio/add-2D-audio (recuperat 2026-09-08)
- Roblox Engine API Reference — AudioPlayer: https://create.roblox.com/docs/reference/engine/classes/AudioPlayer (recuperat 2026-09-08)
- Roblox Engine API Reference — AudioDeviceOutput: https://create.roblox.com/docs/reference/engine/classes/AudioDeviceOutput (recuperat 2026-09-08)
- Roblox Engine API Reference — Wire: https://create.roblox.com/docs/reference/engine/classes/Wire (recuperat 2026-09-08)
- Roblox Engine API Reference — Sound: https://create.roblox.com/docs/reference/engine/classes/Sound (recuperat 2026-09-08)
- Roblox Engine API Reference — SoundService: https://create.roblox.com/docs/reference/engine/classes/SoundService (recuperat 2026-09-08)
- Roblox Engine API Reference — SoundGroup: https://create.roblox.com/docs/reference/engine/classes/SoundGroup (recuperat 2026-09-08)
- Roblox Engine API Reference — UserGameSettings: https://create.roblox.com/docs/reference/engine/classes/UserGameSettings (recuperat 2026-09-08)
- Roblox Engine API Reference — ContentProvider: https://create.roblox.com/docs/reference/engine/classes/ContentProvider (recuperat 2026-09-08)
- Roblox Open Cloud — Rate limits: https://create.roblox.com/docs/cloud/reference/rate-limits (recuperat 2026-09-08)
- DevForum — „[Action Needed] Upcoming Changes to Asset Privacy for Audio": https://devforum.roblox.com/t/1701697 (postat 2022-03-09)
- DevForum — „[Update] Changes to Asset Privacy for Audio": https://devforum.roblox.com/t/1715717 (postat 2022-03-16)
- DevForum — „Public Sound Effects Upload Are Now Available for Creators": https://devforum.roblox.com/t/2980704 (postat 2024-05-23)
- DevForum — „New Audio API [Beta]: Elevate Sound and Voice in Your Experiences": https://devforum.roblox.com/t/new-audio-api-beta-elevate-sound-and-voice-in-your-experiences (postat 2024-02-22)
- DevForum — „Increase Default Audio Upload Limits and Offer Paid Options": https://devforum.roblox.com/t/3629892 (postat 2025-04-28, activ până cel puțin 2026-07-08)
- DevForum — titluri identificate via căutare (context, nefetch-uite integral): „New Audio API Features: Directional Audio, AudioLimiter and More" (2024-12-02), „Sound API / New Sound API" (2026-08-16), „Open-Cloud Assets API only giving 10 uploads a month" (2023-08-30), „OpenCloud Generate AI Speech Asset API fails after 9 uploads per account" (2026-01-21)
- Wikipedia — „Roblox" (context secundar pentru disputa copyright „oof" 2022/reinstate 2025 și procesul NMPA 2021): https://en.wikipedia.org/wiki/Roblox (recuperat 2026-09-08)
