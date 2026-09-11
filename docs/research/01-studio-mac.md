# Roblox Studio pe macOS (Apple Silicon)

## Rezumat executiv

- Roblox Studio rulează **nativ pe Apple Silicon** (M1–M5) din iulie 2023, dar link-ul de download implicit de pe pagina publică livrează build-ul Intel (necesită Rosetta 2) — există un link direct pentru build-ul arm64 nativ.
- Cerința minimă oficială e **macOS 10.14**, recomandat **macOS 14+**; pe orice Mac Apple Silicon din 2026 (care rulează macOS 26 „Tahoe" sau beta macOS 27) asta nu e o problemă reală.
- **Riscul real nu e compatibilitatea minimă, ci instabilitatea pe cele mai noi versiuni de macOS**: crash-uri raportate activ pe DevForum pe macOS 26 Tahoe (2025–2026) și un bug de streaming/rendering pe macOS 27 beta (obiectele nu se încarcă peste ~200 studs) — nerezolvate oficial la data acestui research.
- **Politica de publicare s-a schimbat radical în 2026.** De la **19 mai 2026** există 3 tiere de publicare, iar pentru a publica un joc accesibil tuturor vârstelor (inclusiv conturi Roblox Kids/Select) e nevoie de **2FA obligatoriu + ID verification + abonament Roblox Plus/Premium activ** (sau o taxă alternativă de **1.000 Robux/joc**, one-time, rambursabilă).
- Colaborarea în **Team Create** necesită acum **age-check** între colaboratori (rollout global din ianuarie 2026) — dar **dezvoltarea solo nu e afectată**, poți crea și folosi Team Create singur fără verificare.
- **EditableImage/EditableMesh** (util dacă vrei sprite-uri generate/editate programatic pentru randarea 2D) sunt blocate by default în jocuri publicate: necesită cont **13+ verificat ID** și un toggle explicit „Enable Mesh/Image APIs" în Creator Dashboard.
- **Nu există o versiune web/cloud oficială a Studio** în 2026 — rămâne exclusiv aplicație desktop nativă (Windows/macOS). Orice unealtă „browser Roblox Studio" e third-party, neoficială.
- Plugin-urile din Toolbox au **probleme istorice și recurente pe Mac** (nu apar în tab-ul Plugins) — problemă raportată constant între 2021 și 2025 pe DevForum, fără fix permanent confirmat oficial.
- Anti-cheat-ul **Hyperion (ex-Byfron)** e documentat ca soluție centrată pe Windows; nu am găsit documentație oficială Roblox despre un echivalent kernel-level pe macOS — **NEVERIFICAT**.
- **DataStoreService** și **HttpService** necesită activare manuală per-experience („Enable Studio Access to API Services" / „Allow HTTP Requests") și, atenție, Studio accesează **aceleași date-store-uri ca jocul live** — periculos dacă testezi pe experience-ul de producție.

---

## Fapte verificate

- Roblox Studio rulează nativ pe procesoare Apple Silicon (M1/M2 confirmate în anunț, extins ulterior); build-ul nativ elimină layer-ul de emulare Rosetta. — sursa: https://devforum.roblox.com/t/native-support-for-apple-silicon-better-performance-and-improved-battery-life/2478678 — 20 iulie 2023 — confidence: ridicata (dar anunțul e vechi, posibil depășit pe detalii fine)
- Installer-ul descărcat de pe pagina web a Roblox pentru Apple Silicon necesită Rosetta 2 la instalare, deși Studio în sine are suport nativ arm64; link direct pentru build nativ: `https://setup.rbxcdn.com/channel/zmacarm64/mac/arm64/RobloxStudio.dmg`. — sursa: https://devforum.roblox.com/t/roblox-studio-installer-on-apple-silicon-requires-rosetta-2-despite-native-apple-silicon-support-within-studio/3789309 — 2025 — confidence: medie (thread comunitate, nu anunț oficial Roblox staff)
- Cerințe oficiale de sistem pentru Roblox Studio: minim Windows 10 / macOS 10.14, 3 GB RAM; recomandat Windows 11 / macOS 14+, 8 GB RAM, rezoluție 1600×900+. — sursa: https://create.roblox.com/docs/studio/setup — pagină curentă (accesată sept. 2026) — confidence: ridicata (documentație oficială Creator Hub)
- Instalare: descarci `RobloxStudio.dmg` (Mac) / `RobloxStudio.exe` (Windows), rulezi installer-ul, apeși „Launch Studio", te loghezi cu contul Roblox. — sursa: https://create.roblox.com/docs/tutorials/curriculums/studio/install-studio — pagină curentă — confidence: ridicata
- Studio pe macOS ARM are FPS-ul editorului (nu playtest-ul) plafonat la 120 FPS, chiar și pe display-uri 240Hz; comportamentul nu apare pe Windows. — sursa: https://devforum.roblox.com/t/studio-editor-on-macos-capped-at-120-fps-when-not-play-testing/3709420 — 2025 — confidence: medie (raport comunitate, neconfirmat ca „by design" de Roblox)
- Studio crash-uiește constant pe macOS 26 (Tahoe) Beta, mai ales la playtesting local. — sursa: https://devforum.roblox.com/t/roblox-studio-crashes-constantly-on-macos-26-tahoe-beta/3760929 — 19 iunie 2025 — confidence: medie
- Crash silențios la desktop, fără log/crash report, inclusiv pe un baseplate gol, pe macOS Beta. — sursa: https://devforum.roblox.com/t/macos-beta-roblox-studio-silent-crash-to-desktop-no-logs-no-crash-report/4699416 — 23 iunie 2026 — confidence: medie
- Studio a continuat să crape ("quit unexpectedly") după update-ul la macOS Tahoe. — sursa: https://devforum.roblox.com/t/continuously-crashing-after-updating-studio-mainly-as-soon-as-i-start-playtesting/4006921 — 14 octombrie 2025 — confidence: medie
- Bug sever de streaming/rendering pe macOS 27 Beta: obiectele se încarcă doar în ~200 studs, atât în Studio cât și în clientul Roblox. — sursa: https://devforum.roblox.com/t/severe-streamingrendering-issue-on-macos-27-objects-only-load-within-200-studs-in-studio-and-roblox-client/4679580 — 12 iunie 2026 — confidence: medie
- Plugin-urile instalate nu apar în tab-ul Plugins pe Mac (Studio Legacy și Next-Gen), problemă recurentă, fără fix definitiv confirmat. — sursa: https://devforum.roblox.com/t/installed-plugins-do-not-show-up-on-mac-next-gen-and-legacy-studio/3637180 — 2025 — confidence: medie
- Modurile de testare curente: **Test (F5)** — inserează avatarul la un SpawnLocation; **Test Here** — inserează avatarul unde e camera; **Run (F8)** — simulează fără avatar; **Server & Clients (F7)** — pornește 1 server + până la **8 sesiuni client**; **Team Test** — testare colaborativă cu alți colaboratori ai proiectului, **o singură sesiune Team Test poate rula simultan**. — sursa: https://create.roblox.com/docs/studio/testing-modes — pagină curentă — confidence: ridicata
- Pentru a activa accesul la DataStore/HTTP în Studio: File → Experience Settings (fostul „Game Settings") → Security → toggle „Enable Studio Access to API Services" → Save. Studio accesează **aceleași data store-uri ca și clientul live**, deci nu se recomandă activarea pe experience-ul de producție — se folosește o copie de test separată. — sursa: https://create.roblox.com/docs/cloud-services/data-stores — pagină curentă — confidence: ridicata
- Din **19 mai 2026**, publicarea de jocuri e structurată pe 3 tiere: (1) uz personal — fără cerințe suplimentare; (2) 16+ și „Trusted Friends" — age-check + cont în regulă + minim 2 zile vechime; (3) toate vârstele (inclusiv Roblox Kids/Select) — plus **ID verification, 2FA activat, abonament Roblox Plus/Premium activ**, sau alternativ o **taxă unică rambursabilă de 1.000 Robux/joc**. — sursa: https://devforum.roblox.com/t/new-publishing-requirements-evaluation-process-for-games/4573166 — actualizări 17 aprilie 2026 și 11 mai 2026 — confidence: ridicata (anunț oficial Roblox staff pe DevForum)
- ~100.000 de creatori existenți (100+ ore playtime în ultimele 30 de zile, fără violări majore) primesc 6 luni gratuite de Roblox Plus începând cu 19 mai 2026. — sursa: idem — 11 mai 2026 — confidence: ridicata
- Conturile **Roblox Kids (5–8 ani)** și **Roblox Select (9–15 ani)** au fost introduse cu rollout „early June 2026"; jocurile incluse pentru aceste categorii necesită creator cu **ID verification + 2FA + abonament Roblox Plus activ**, plus evaluare de conținut/maturitate. — sursa: https://about.roblox.com/newsroom/2026/04/introducing-roblox-kids-and-select-accounts — aprilie 2026 (rollout iunie 2026) — confidence: ridicata
- Colaborarea prin **Team Create** (funcția „Collaborate") necesită age-check din early 2026; **crearea solo și folosirea Team Create singur rămân neafectate**. — sursa: https://devforum.roblox.com/t/age-checks-to-access-chat-studio-team-create-and-links-on-roblox/4079702 — confidence: ridicata (anunț oficial) — completat de https://about.roblox.com/newsroom/2025/11/roblox-requires-age-checks-limits-minor-and-adult-chat — 19 noiembrie 2025 — confidence: ridicata
- Verificarea de vârstă (Facial Age Estimation sau ID Verification) e necesară pentru: chat (experience/party/DM), **Voice Chat** (minim 13 ani + verificare), linkuri social media în experience, colaborare Team Create, și e o precondiție pentru tier-ul 3 de publishing. — surse combinate: https://about.roblox.com/newsroom/2025/11/roblox-requires-age-checks-limits-minor-and-adult-chat, https://en.help.roblox.com/hc/en-us/articles/34506487825428-How-do-I-turn-on-Voice-Chat — confidence: ridicata
- **EditableImage/EditableMesh** funcționează doar dacă developerul e **13+, ID-verificat**, și a activat explicit „Enable Mesh / Image APIs" din Creator Dashboard; fără asta, API-urile eșuează by default în jocuri publicate. — sursa: https://devforum.roblox.com/t/remove-required-id-verification-for-editablemeshesimages/3981479 — confidence: medie (confirmat de mai multe thread-uri comunitate, dar nu am găsit pagina oficială de politică Creator Dashboard cu wording exact)
- Nu există Roblox Studio în versiune browser/web sau cloud oficială — rămâne aplicație desktop nativă pentru Windows și Mac; nu rulează pe Chromebook/ChromeOS oficial. — surse secundare: https://www.summerengine.com/blog/browser-roblox-studio-alternative, https://nilo.io/articles/roblox-studio-on-chromebook — 2026 — confidence: medie (surse secundare, dar consistente cu lipsa oricărui anunț oficial Roblox despre Studio web)
- Rata DevEx curentă: **$0.0038/Robux** pentru Robux câștigat după 5 septembrie 2025 10:00 PT (creștere de la $0.0035); minim **30.000 Robux** pentru cash-out; există și o rată separată de $0.0054/Robux pentru cheltuieli in-game ale userilor 18+ din SUA, efectivă din 8 iunie 2026. — surse secundare agregate (rolearn.dev, generalistprogrammer.com, bloxsniper.cc), citând pagina oficială https://en.help.roblox.com/hc/en-us/articles/13061189551124 — confidence: medie (nu am putut accesa direct pagina oficială Roblox — a întors HTTP 403 la fetch direct; cifrele coincid cu ce are deja CLAUDE.md, deci probabil corecte, dar rata pare crescută recent — recomand verificare manuală în Creator Dashboard)
- Roblox „Next-Gen Studio UI" (redesign complet al meniului/ribbon-ului) e în rollout activ, extins la mai mulți creatori din 20 noiembrie 2025; „Game Settings" a fost redenumit „Experience Settings" în noua UI. — surse: https://devforum.roblox.com/t/next-gen-studio-ui-preview-is-here-beta/3075390, https://github.com/Roblox/creator-docs/blob/main/content/en-us/studio/experience-settings.md — confidence: medie
- Beta Channel: File → Beta Features în Studio activează funcții experimentale individual, sau te poți înscrie în „Beta Channel" pentru activare automată a noilor beta-uri. — sursa: https://devforum.roblox.com/t/introducing-beta-channel-in-studio/800790 — confidence: medie (thread mai vechi, dar mecanismul e confirmat și de pagini recente de tip „how to enable Roblox beta")
- Device Emulator (Test → Device) permite emularea de telefoane/tablete/console/VR, simulare touch (single și two-touch), rotire portrait/landscape, și creare de device-uri custom via Manage Devices. — sursa: https://create.roblox.com/docs/studio/testing-modes (secțiune emulator) — confidence: ridicata
- Modelul de limite DataStore: documentația oficială curentă descrie un sistem **dual-tier** — limite **la nivel de experience** (pool partajat, ex. citiri „300 + concurrentUsers×40" cereri/min) **și, separat, limite la nivel de server** (configurabile, ex. „60 + numPlayers×40"); cele două coexistă, nu s-a înlocuit un model cu celălalt. Se verifică bugetul curent cu `GetRequestBudgetForRequestType()`. **(corectat la verificare — nu e o simplă înlocuire per-server → pool unic, ci ambele niveluri de limită coexistă)** — sursa: https://create.roblox.com/docs/cloud-services/data-stores/error-codes-and-limits — confidence: ridicata (pagină oficială, verificată direct)

---

## Detalii

### 1. Cerințe de sistem (oficial, create.roblox.com/docs/studio/setup)

| Componentă | Minim | Recomandat |
|---|---|---|
| OS | Windows 10 / **macOS 10.14** | Windows 11 / **macOS 14+** |
| RAM | 3 GB | 8 GB |
| Rezoluție | — | 1600×900 sau mai mare |
| Procesor | Intel Core i5 sau Apple Silicon (surse secundare) | Apple M1 sau mai nou |
| GPU | Metal-compatible (surse secundare) | — |
| Spațiu disc | ~20 GB liber recomandat (surse secundare, NEVERIFICAT oficial) | — |

Notă: pagina oficială nu listează explicit cerințe de GPU sau spațiu pe disc — acele cifre vin din surse secundare (LevelUpPlay, Fandom wiki) și trebuie tratate ca aproximative.

Pentru un Mac Apple Silicon cumpărat în ultimii 2-3 ani (M2/M3/M4), pe macOS 26 „Tahoe" curent, cerințele minime nu sunt deloc o problemă — riscul e invers: **stabilitatea Studio pe cele mai noi versiuni de macOS**, nu compatibilitatea cu versiuni vechi.

### 2. Instalare pe Apple Silicon — capcana Rosetta

Pași oficiali (create.roblox.com/docs/tutorials/curriculums/studio/install-studio):
1. Mergi pe pagina de download Roblox Studio, apeși „Download Studio".
2. Se descarcă `RobloxStudio.dmg`.
3. Deschizi `.dmg`-ul, rulezi installer-ul.
4. Apeși „Launch Studio" la finalul instalării.
5. Te loghezi cu contul Roblox (username/email + parolă).

**Problema raportată pe DevForum**: installer-ul livrat de pe pagina publică de download e build-ul Intel și necesită Rosetta 2 la prima rulare pe Apple Silicon, deși Studio are suport nativ arm64 din 2023. Dacă vrei build-ul nativ direct, fără Rosetta, link-ul comunitar identificat e:
```
https://setup.rbxcdn.com/channel/zmacarm64/mac/arm64/RobloxStudio.dmg
```
Acesta nu e un link oficial documentat de Roblox în paginile publice de docs — a fost extras din CDN-ul de channel al Roblox de utilizatori pe DevForum. Recomand: instalează normal, apoi verifică în Activity Monitor (coloana „Kind") dacă procesul `RobloxStudio` rulează ca „Apple" (nativ) sau „Intel" (Rosetta). Dacă rulează sub Rosetta, dezinstalează și reinstalează cu link-ul de mai sus, sau așteaptă update-ul automat — conform anunțului din 2023, „most users will automatically be updated" la build-ul nativ.

### 3. Cont Roblox — vârstă, verificare, 2FA

- Vârsta minimă tehnică pentru a crea un cont e listată de surse secundare ca fiind foarte joasă (ex. „5 ani"), dar pentru conturi sub 18 ani e necesar acum **consimțământ parental verificat prin email** la crearea contului (introdus 2026). Cifra exactă „5 ani" ca prag minim absolut e din surse secundare — **NEVERIFICAT** pe pagina oficială de Terms of Use.
- Din aprilie/iunie 2026 există segmentare pe categorii de cont: **Roblox Kids (5–8)**, **Roblox Select (9–15)**, cont standard (16+), fiecare cu acces diferit la jocuri în funcție de rating de conținut.
- **2FA (autentificare în doi factori)** e obligatorie **doar pentru tier-ul 3 de publishing (all-ages/Kids-Select)**, nu pentru orice cont care publică — tier 1 (uz personal) nu are cerințe suplimentare, iar tier 2 (16+/Trusted Friends) cere doar age-check + cont activ 2+ zile, fără 2FA explicit menționat. **(corectat la verificare)**
- **ID Verification** (sau Facial Age Estimation) e obligatorie pentru: Voice Chat, chat cu useri din alte grupe de vârstă (fără Trusted Connections), Team Create collaboration, EditableImage/EditableMesh, și tier-ul 3 de publishing (all-ages).

### 4. Ce deblochează verificarea de vârstă/ID — tabel sumar

| Funcție | Cerință minimă | Sursă |
|---|---|---|
| Voice Chat | 13+ verificat (Facial Age Estimation sau ID) | en.help.roblox.com Voice FAQ |
| Chat cross-age (fără Trusted Connections) | Age check complet | about.roblox.com nov. 2025 |
| Team Create — Collaborate | Age check + similaritate de vârstă cu colaboratorii | devforum.roblox.com/t/4079702 |
| EditableImage/EditableMesh publicat | 13+ ID-verificat + toggle explicit în Creator Dashboard | devforum.roblox.com/t/3981479 |
| Publishing tier 3 (all-ages, Kids/Select) | ID verification + 2FA + Roblox Plus/Premium activ (sau taxă 1.000 Robux) | devforum.roblox.com/t/4573166 |
| Publishing tier 2 (16+/Trusted Friends) | Age check + cont activ 2+ zile | devforum.roblox.com/t/4573166 |
| Publishing tier 1 (uz personal) | Fără cerințe suplimentare | devforum.roblox.com/t/4573166 |

### 5. Bug-uri cunoscute Studio pe macOS 26 Tahoe / macOS 27 beta (2025–2026)

Toate confirmate ca fiind active pe DevForum, fără fix oficial confirmat la data acestui research (8 septembrie 2026):

- **Crash constant la playtesting local** pe macOS 26 Tahoe Beta — https://devforum.roblox.com/t/roblox-studio-crashes-constantly-on-macos-26-tahoe-beta/3760929 (19 iun 2025)
- **Crash silențios, fără log**, chiar și pe baseplate gol — https://devforum.roblox.com/t/macos-beta-roblox-studio-silent-crash-to-desktop-no-logs-no-crash-report/4699416 (23 iun 2026)
- **„Quit unexpectedly" continuu** după update la Tahoe — https://devforum.roblox.com/t/continuously-crashing-after-updating-studio-mainly-as-soon-as-i-start-playtesting/4006921 (14 oct 2025)
- **Crash la Asset Manager** la lansare — https://devforum.roblox.com/t/asset-manager-instantly-crashes-studio-upon-launch/4526687
- **Crash la selectarea script-urilor / adăugare instanțe** pe Tahoe 26.2 — raportat iunie 2026
- **Bug sever de streaming pe macOS 27 Beta**: obiectele nu se randează dincolo de ~200 studs, atât în Studio cât și în client — https://devforum.roblox.com/t/severe-streamingrendering-issue-on-macos-27-objects-only-load-within-200-studs-in-studio-and-roblox-client/4679580 (12 iun 2026)
- **FPS-ul editorului plafonat la 120** pe macOS ARM (nu apare pe Windows) — https://devforum.roblox.com/t/studio-editor-on-macos-capped-at-120-fps-when-not-play-testing/3709420

Pattern observat: majoritatea crash-urilor grave sunt raportate pe **versiuni beta de macOS** (Tahoe beta în 2025, macOS 27 beta în 2026), nu pe release-uri stabile. Implicație practică: **nu rula Studio pe beta-uri publice de macOS** dacă lucrezi la Driftwood — actualizează doar pe versiuni stable, cu întârziere de câteva săptămâni după fiecare release major Apple.

### 6. Mac vs Windows — diferențe funcționale

- **Plugin-uri**: probleme recurente și confirmate multianual (2021–2025+) unde plugin-urile instalate nu apar deloc în tab-ul Plugins pe Mac, deși apar corect pe Windows cu același cont. Workaround comunitar: ștergerea folderului `InstalledPlugins` și reinstalare — nu e un fix permanent confirmat oficial.
- **Performanță editor**: FPS plafonat la 120 în editor pe Mac ARM (nu în playtest); pe Windows nu există acest cap documentat.
- **Anti-cheat Hyperion (ex-Byfron)**: documentat public ca soluție anti-tamper/anti-cheat achiziționată de Roblox, descrisă în discuții comunitare ca fiind centrată pe Windows (nivel kernel/driver). Nu am găsit pagină oficială Roblox care să detalieze explicit dacă/cum funcționează echivalentul pe macOS — **NEVERIFICAT**, merită testat direct: dacă publici un joc și un tester pe Mac raportează bans/kicks nejustificate, ar putea fi un semnal.
- **Team Create**: funcțional identic cross-platform (colaboratori pe Mac + Windows în aceeași sesiune), dar acum supus regulilor de age-check descrise mai sus.
- **Next-Gen Studio UI**: rollout identic pe ambele platforme, în curs de extindere din nov. 2025; „Game Settings" → „Experience Settings" e o redenumire, nu o schimbare funcțională.
- **Studio Beta Channel**: identic disponibil pe Mac — File → Beta Features, sau înscriere completă în Beta Channel pentru auto-activare.

### 7. Activarea „Studio Access to API Services" (DataStore + HTTP)

Pași (Next-Gen UI, cale curentă):
1. În Studio: **File → Experience Settings** (varianta veche: Home tab → Game Settings).
2. Tab **Security**.
3. Activează toggle-ul **„Enable Studio Access to API Services"** (pentru DataStore) și separat **„Allow HTTP Requests"** (pentru HttpService).
4. **Save**.

Atenție critică pentru Driftwood (persistență DataStore + acumulare offline): Studio, cu acest toggle activ, **citește/scrie în aceleași data store-uri ca jocul publicat live**. Recomandarea oficială e să NU activezi asta pe experience-ul de producție, ci pe o **copie separată de test** (duplică place-ul, folosește-l doar pentru dezvoltare).

Exemplu Luau de verificare a bugetului de cereri disponibil (util pentru debugging în Studio):
```lua
local DataStoreService = game:GetService("DataStoreService")
local budget = DataStoreService:GetRequestBudgetForRequestType(
    Enum.DataStoreRequestType.GetAsync
)
print("Buget GetAsync disponibil:", budget)
```

Dacă primești eroarea `StudioAccessToApisNotAllowed`, înseamnă că toggle-ul de mai sus nu e activat pe experience-ul curent testat.

Model de limite (context, nu specific Mac): pagina oficială de limite descrie un sistem **dual-tier**, nu o înlocuire a unui model cu altul — există atât limite **per-experience** (pool partajat între toate serverele, formulă de tip „300 + concurrentUsers×40" pentru citiri) cât și limite **per-server** configurabile (formulă de tip „60 + numPlayers×40") **(corectat la verificare)**. Ambele nivele contează pentru design-ul de retry/batching; recomand tot un research separat dedicat DataStore înainte de a proiecta sistemul de persistență, dar premisa „per-server a fost înlocuit de pool unic" din nota inițială era greșită — sursa: https://create.roblox.com/docs/cloud-services/data-stores/error-codes-and-limits.

### 8. Device Emulator (testare mobil)

Accesibil din **Test → Device** în Studio (identic pe Mac și Windows):
- Dropdown de selecție device deasupra viewport-ului 3D — telefoane, tablete, console, VR.
- Simulare touch: single-touch normal cu click, two-touch (pinch/rotate) cu modifier (Alt pe Windows, ⌥ Option pe Mac) + drag.
- Orientare portrait/landscape comutabilă.
- Device-uri custom: **Test → Device → Manage Devices**, poți defini rezoluții/aspect ratio-uri proprii.
- Util pentru Driftwood: fiindcă interfața e ScreenGui 2D pură, testarea pe rezoluții mobile variate (aspect ratio-uri diferite de desktop) e esențială — layout-ul de Frame/ImageLabel trebuie verificat pe emulator înainte de orice lansare pe telefon.

### 9. Moduri de testare — tabel complet

| Mod | Shortcut | Comportament | Notă pentru Driftwood |
|---|---|---|---|
| **Test** (fost „Play") | F5 | Inserează avatarul la SpawnLocation sau ~(0,100,0) | Simulare solo rapidă |
| **Test Here** (fost „Play Here") | — | Inserează avatarul unde e camera curentă | Util pentru debug la o poziție specifică pe mal |
| **Run** | F8 | Simulează fără avatar, navigare liberă cu camera Studio | Bun pentru a observa logica de râu/spawn fără interferența unui player |
| **Server & Clients** (Team Test local) | F7 | 1 fereastră server + **până la 8 ferestre client** | Recomandat 2 clienți pt majoritatea testelor (RAM redus); relevant pt testarea „orașul e comun tuturor jucătorilor de pe server" din brief |
| **Team Test** (colaboratori reali) | — | Testare live cu alți colaboratori ai proiectului, prin rețea | **O singură sesiune Team Test poate rula simultan**; necesită age-check între colaboratori din 2026 |

Recomandare comunitară (sursă secundară, confidence medie): un test cu 2 clienți e suficient pentru 90% din nevoile de dezvoltare; 3+ clienți consumă RAM semnificativ (fiecare fereastră client + fereastra server = procese separate). Pentru teste cu multe persoane reale (ex. validarea „Atelierul orașului" cu 10 jucători simultan din brief), varianta recomandată e publicarea pe un **place privat de test**, nu Server & Clients local.

### 10. Web/cloud Studio — nu există în 2026

Roblox Studio rămâne exclusiv aplicație desktop nativă pentru Windows și macOS. Nu există:
- Versiune oficială în browser.
- Suport oficial ChromeOS/Chromebook.
- Versiune cloud-hosted de Roblox (spre deosebire de unelte third-party gen Construct 3, PlayCanvas, care sunt alternative — nu Roblox).

Există unelte AI generative Roblox recente (ex. „Cube", model foundation 3D lansat 5 februarie 2026, conform surselor secundare) orientate spre generare de conținut, dar acestea NU înlocuiesc Studio ca IDE — **NEVERIFICAT** dacă au impact direct pe workflow-ul de dezvoltare Driftwood, merită research separat dacă interesează AI-assisted content generation.

### 11. Studio Beta Channel & Next-Gen UI

- **File → Beta Features**: bifezi individual funcții experimentale, Save, posibil restart Studio.
- **Beta Channel** complet: te înscrii pentru primirea automată a tuturor beta-urilor noi pe măsură ce apar.
- **Next-Gen Studio UI**: redesign complet al ribbon-ului/meniului, în rollout extins din 20 noiembrie 2025; identic disponibil Mac/Windows. „Game Settings" e acum „Experience Settings" în noua UI — tutorialele vechi (pre-2025) vor referi numele vechi.

---

## Recomandari concrete pentru Driftwood

1. **Instalează build-ul nativ Apple Silicon explicit**, nu doar installer-ul implicit de pe pagina de download — verifică în Activity Monitor că `RobloxStudio` rulează ca proces „Apple" nu „Intel". Rosetta adaugă overhead inutil pe un proiect care va rula ore întregi de dezvoltare zilnic.
2. **Nu actualiza macOS la versiuni beta** (ex. viitoare macOS 28 beta) pe mașina de dezvoltare principală, cel puțin nu fără o mașină secundară de test — pattern-ul din 2025–2026 arată crash-uri concentrate pe beta-uri macOS, nu pe release-uri stabile.
3. **Folosește o experience/place separată doar pentru testare DataStore**, distinctă de cea care va deveni producție — activează „Enable Studio Access to API Services" doar acolo, niciodată pe place-ul live, dat fiind că brief-ul Driftwood se bazează integral pe persistență DataStore + acumulare offline (risc de coruperi de date reale în timpul dezvoltării).
4. **Planifică din timp pentru 2FA + eventual ID verification pe contul de creator** — dat fiind că Driftwood țintește monetizare (Game Passes, Developer Products) și publicare pentru toate vârstele, tier-ul 3 de publishing (activ din 19 mai 2026) cere 2FA + ID verification + Roblox Plus/Premium activ sau taxa de 1.000 Robux/joc. 2FA e cerință explicită doar pentru tier-ul 3, nu pentru tier 1/2 **(corectat la verificare)** — dar tot recomand activarea ei din timp, dat fiind că Driftwood țintește probabil tier 3.
5. **Nu te baza pe EditableImage/EditableMesh** pentru randarea 2D principală (chestii precum sprite-uri generate dinamic) fără să confirmi explicit statusul de ID verification al contului — API-urile eșuează silent/by-default în build publicat dacă nu e activat toggle-ul din Creator Dashboard. Brief-ul spune „2D pur în ScreenGui — Frame/ImageLabel", deci probabil nu ai nevoie de EditableImage deloc; verifică asta explicit ca decizie de arhitectură, nu implicit.
6. **Testează layout-ul ScreenGui pe Device Emulator încă din prototip** (pasul 1 din brief), nu doar la final — fiindcă interfața e 100% 2D pe Frame/ImageLabel, orice breakpoint greșit de aspect ratio se vede imediat pe telefon și pică tot ce ai construit pe presupunerea de desktop 16:9.
7. **Pentru testare multiplayer locală, folosește F7 (Server & Clients) cu 2 clienți** pentru majoritatea iterațiilor de zi cu zi (server autoritar + un client observator e suficient să validezi RemoteEvents); rezervă un „place de test" privat publicat separat pentru validări cu mai mulți testeri reali (ex. mecanica de „Atelierul orașului" comun, care are sens doar cu mai mulți jucători simultan).
8. **Nu instala plugin-uri critice pentru workflow fără un test imediat pe Mac** — dat fiind istoricul recurent de plugin-uri care nu apar în tab pe Mac; verifică fiecare plugin nou imediat după instalare, nu presupune că funcționează ca pe tutorialele filmate pe Windows.
9. **Fii pregătit ca Team Create collaboration să ceară age-check** dacă la un moment dat aduci un al doilea developer/artist pe proiect — developarea solo nu e afectată, dar colaborarea da; verifică statusul de verificare al oricărui colaborator viitor înainte de a-l invita.
10. **Documentează separat un research dedicat pentru DataStore limits** (pool nou per-experience din 2026) înainte de a implementa pasul 2 din brief (Persistență DataStore + acumulare offline) — modelul de limite s-a schimbat recent și impactează direct design-ul de retry/batching pentru salvări periodice la 2 minute.

---

## Riscuri si necunoscute

- **Stabilitate Studio pe macOS Tahoe/27**: crash-uri active, nerezolvate oficial la data research-ului (8 sept. 2026). Risc direct pentru productivitate zilnică pe un proiect solo pe Mac.
- **Politica de publishing e recentă (mai 2026) și posibil încă în ajustare** — thread-ul DevForum are mii de reply-uri și update-uri succesive (17 apr, 11 mai 2026); posibil să mai apară modificări. Nu lua cifrele (1.000 Robux, 2 zile cont activ) ca definitive fără verificare în Creator Dashboard la momentul publicării efective.
- **Hyperion pe Mac — necunoscut oficial**: dacă anti-cheat-ul are limitări reale pe macOS, ar putea însemna risc de moderare/fraudă diferit pentru testeri pe Mac vs Windows. NEVERIFICAT, merită întrebat direct pe DevForum sau testat.
- **Rata DevEx $0.0038 nu a putut fi confirmată direct pe pagina oficială** (HTTP 403 la fetch automat) — confirmată doar prin agregatoare terțe. Verifică manual în Creator Dashboard înainte de orice calcul de monetizare din brief.
- **Plugin-urile lipsă pe Mac** pot bloca workflow-uri esențiale (ex. pluginuri de aliniere, export assets) fără avertisment clar — testează orice plugin nou imediat, nu la mijlocul unui sprint.
- **EditableImage/EditableMesh — wording exact al politicii de la Roblox nu a fost găsit pe o pagină oficială de politici**, doar prin thread-uri DevForum de discuție/cerere de schimbare. Confirmă în Creator Dashboard propriu ce opțiuni de „Enable Mesh/Image APIs" există efectiv.

---

## Intrebari deschise

1. Rulează efectiv `RobloxStudio.app` pe mașina ta ca proces nativ Apple Silicon, sau sub Rosetta? (Verifică în Activity Monitor → coloana Kind.)
2. Ce versiune exactă de macOS rulează mașina de dezvoltare acum, și e o versiune stabilă sau beta? (Crash-urile documentate sunt concentrate pe beta-uri.)
3. Ai deja activat 2FA pe contul de creator Roblox? Dacă nu, activează-l acum — e cerință obligatorie doar pentru tier-ul 3 de publishing (all-ages), nu pentru orice tier **(corectat la verificare)**, dar util să fie activă din timp dacă țintești tier 3.
4. Vrei să publici Driftwood pentru toate vârstele (tier 3, necesită ID verification + Plus/Premium sau taxă 1.000 Robux) sau doar pentru 16+/Trusted Friends (tier 2, mai puține cerințe)? Asta e o decizie de business, nu tehnică — impactează dacă faci ID verification acum sau mai târziu.
5. Ai nevoie de EditableImage/EditableMesh undeva în arhitectura de randare 2D (de ex. pentru a genera texturi dinamice pentru obiectele din râu), sau brief-ul „Frame/ImageLabel" acoperă 100% nevoile? Dacă da, verifică din timp statusul de ID verification.
6. Testează în Studio: reproduce crash-urile raportate pe macOS 26 Tahoe pe mașina ta specifică? Dacă da, ce workaround funcționează (downgrade versiune Studio, restart, dezactivare anumite plugin-uri)?
7. Confirmă manual în Creator Dashboard rata DevEx curentă și condițiile de cash-out — nu te baza doar pe acest research pentru cifrele financiare finale.
8. Dacă la un moment dat aduci un colaborator (artist, alt developer), testează fluxul de age-check pentru Team Create Collaborate înainte de a te baza pe el în plan.

---

## Surse

- Studio testing modes | Documentation - Roblox Creator Hub — https://create.roblox.com/docs/studio/testing-modes — pagină curentă (accesată sept. 2026)
- Install Roblox Studio | Documentation - Roblox Creator Hub — https://create.roblox.com/docs/tutorials/curriculums/studio/install-studio — pagină curentă
- Roblox Studio setup | Documentation - Roblox Creator Hub — https://create.roblox.com/docs/studio/setup — pagină curentă
- Data stores | Documentation - Roblox Creator Hub — https://create.roblox.com/docs/cloud-services/data-stores — pagină curentă
- Data store error codes and limits | Documentation - Roblox Creator Hub — https://create.roblox.com/docs/cloud-services/data-stores/error-codes-and-limits — referențiată
- creator-docs/content/en-us/studio/experience-settings.md — GitHub Roblox/creator-docs — https://github.com/Roblox/creator-docs/blob/main/content/en-us/studio/experience-settings.md
- New Publishing Requirements & Evaluation Process for Games — Developer Forum | Roblox — https://devforum.roblox.com/t/new-publishing-requirements-evaluation-process-for-games/4573166 — actualizări 17 apr. 2026 / 11 mai 2026
- Age Checks to Access Chat, Studio Team Create, and Links on Roblox — Developer Forum | Roblox — https://devforum.roblox.com/t/age-checks-to-access-chat-studio-team-create-and-links-on-roblox/4079702
- Roblox Requires Age Checks for Communication, Ushering in New Safety Standard — about.roblox.com — https://about.roblox.com/newsroom/2025/11/roblox-requires-age-checks-limits-minor-and-adult-chat — 19 noiembrie 2025
- Introducing Roblox Kids and Select Accounts — about.roblox.com — https://about.roblox.com/newsroom/2026/04/introducing-roblox-kids-and-select-accounts — aprilie 2026
- Native Support for Apple Silicon: Better Performance and Improved Battery Life — Developer Forum | Roblox — https://devforum.roblox.com/t/native-support-for-apple-silicon-better-performance-and-improved-battery-life/2478678 — 20 iulie 2023
- Roblox Studio installer on Apple Silicon requires Rosetta 2 despite native Apple Silicon support within Studio — Developer Forum | Roblox — https://devforum.roblox.com/t/roblox-studio-installer-on-apple-silicon-requires-rosetta-2-despite-native-apple-silicon-support-within-studio/3789309 — 2025
- Roblox Studio crashes constantly on macOS 26 (Tahoe) Beta — Developer Forum | Roblox — https://devforum.roblox.com/t/roblox-studio-crashes-constantly-on-macos-26-tahoe-beta/3760929 — 19 iunie 2025
- [macOS Beta] Roblox Studio silent crash to desktop (No logs, no crash report) — Developer Forum | Roblox — https://devforum.roblox.com/t/macos-beta-roblox-studio-silent-crash-to-desktop-no-logs-no-crash-report/4699416 — 23 iunie 2026
- Continuously Crashing after Updating Studio — Developer Forum | Roblox — https://devforum.roblox.com/t/continuously-crashing-after-updating-studio-mainly-as-soon-as-i-start-playtesting/4006921 — 14 octombrie 2025
- Severe streaming/rendering issue on macOS 27 — Developer Forum | Roblox — https://devforum.roblox.com/t/severe-streamingrendering-issue-on-macos-27-objects-only-load-within-200-studs-in-studio-and-roblox-client/4679580 — 12 iunie 2026
- Studio editor on macOS capped at 120 FPS when not play-testing — Developer Forum | Roblox — https://devforum.roblox.com/t/studio-editor-on-macos-capped-at-120-fps-when-not-play-testing/3709420 — 2025
- Installed Plugins Do Not Show Up on Mac (Next-Gen and Legacy studio) — Developer Forum | Roblox — https://devforum.roblox.com/t/installed-plugins-do-not-show-up-on-mac-next-gen-and-legacy-studio/3637180 — 2025
- Age Guidelines for Collaborating in Roblox Studio — Roblox Support — https://en.help.roblox.com/hc/en-us/articles/45500519296532-Age-Guidelines-for-Collaborating-in-Roblox-Studio
- How do I turn on Voice Chat? — Roblox Support — https://en.help.roblox.com/hc/en-us/articles/34506487825428-How-do-I-turn-on-Voice-Chat
- Remove required id verification for editablemeshes/images — Developer Forum | Roblox — https://devforum.roblox.com/t/remove-required-id-verification-for-editablemeshesimages/3981479
- Allow video age verified users to access editableimage/mesh apis — Developer Forum | Roblox — https://devforum.roblox.com/t/allow-video-age-verified-users-to-access-editableimagemesh-apis/4098817
- Introducing Beta Channel in Studio! — Developer Forum | Roblox — https://devforum.roblox.com/t/introducing-beta-channel-in-studio/800790
- Next Gen Studio UI Preview is here! [Beta] — Developer Forum | Roblox — https://devforum.roblox.com/t/next-gen-studio-ui-preview-is-here-beta/3075390 — extindere 20 noiembrie 2025
- Save number of client sessions needed for 'Server & Clients' tests — Developer Forum | Roblox — https://devforum.roblox.com/t/save-number-of-client-sessions-needed-for-server-clients-tests/4726568 (confirmă max. 8 clienți)
- Computer Hardware & Operating System Requirements — Roblox Support — https://en.help.roblox.com/hc/en-us/articles/203312800-Computer-Hardware-Operating-System-Requirements (accesat via search, fetch direct blocat HTTP 403)
- Developer Exchange – Help and Information Page — Roblox Support — https://en.help.roblox.com/hc/en-us/articles/13061189551124-Developer-Exchange-Help-and-Information-Page (fetch direct blocat HTTP 403; date confirmate via agregatoare terțe — vezi mai jos)
- Roblox DevEx Requirements in 2026 — ROLearn (secundar) — https://rolearn.dev/guidance/roblox-devex-requirements-2026/
- Roblox DevEx: How to Cash Out Robux to USD (2026 Rates) — GeneralistProgrammer (secundar) — https://generalistprogrammer.com/tutorials/roblox-devex-guide-how-to-cash-out-robux
- Roblox DevEx Rates 2026 — BloxSniper (secundar) — https://bloxsniper.cc/blog/devex-rates-2026
- 7 Browser-Based Roblox Studio Alternatives in 2026 — Summer Engine (secundar) — https://www.summerengine.com/blog/browser-roblox-studio-alternative
- Roblox Studio on Chromebook: Why It Won't Work — Nilo.io (secundar) — https://nilo.io/articles/roblox-studio-on-chromebook

---

## Verificare independenta (2026-09-08)

Verificare realizată de un agent independent, prin fetch direct al surselor primare (create.roblox.com/docs, devforum.roblox.com, about.roblox.com, en.help.roblox.com, github.com/Roblox/creator-docs). 14 afirmații cu impact ridicat asupra deciziilor de proiect au fost re-verificate; peste 15 fetch-uri au fost efectuate.

| Afirmatie | Verdict | Valoare corecta | Sursa (URL, data) |
|---|---|---|---|
| Roblox Studio rulează nativ pe Apple Silicon (M1/M2) din iulie 2023 | CONFIRMAT | Anunț oficial DevForum, 20 iulie 2023, confirmă suport nativ M1/M2 | https://devforum.roblox.com/t/native-support-for-apple-silicon-better-performance-and-improved-battery-life/2478678 (verificat 2026-09-08) |
| Installer-ul implicit de pe pagina de download necesită Rosetta 2 deși Studio are build nativ arm64 | CONFIRMAT (sursă comunitară, consistentă cu discuțiile din thread-ul oficial) | Confirmat de replies în thread-ul oficial de lansare — problema installer-ului Intel a fost semnalată de comunitate încă din 2023 | https://devforum.roblox.com/t/native-support-for-apple-silicon-better-performance-and-improved-battery-life/2478678 (verificat 2026-09-08) |
| Cerințe sistem: minim macOS 10.14 / Windows 10, 3 GB RAM; recomandat macOS 14+ / Windows 11, 8 GB RAM, 1600×900+ | CONFIRMAT | Exact ca în notă | https://create.roblox.com/docs/studio/setup (verificat 2026-09-08) |
| Server & Clients (F7) suportă până la 8 sesiuni client; Team Test permite o singură sesiune simultană | CONFIRMAT | Exact ca în notă — „you can simulate up to eight" clienți; „only one team test session can run at any given time" | https://create.roblox.com/docs/studio/testing-modes (verificat 2026-09-08) |
| Activare DataStore/HTTP: File → Experience Settings → Security → „Enable Studio Access to API Services"; Studio accesează aceleași data store-uri ca jocul live | CONFIRMAT | Exact ca în notă, inclusiv avertismentul oficial despre risc pe producție | https://create.roblox.com/docs/cloud-services/data-stores (verificat 2026-09-08) |
| Publishing în 3 tiere din 19 mai 2026; tier 3 (all-ages/Kids-Select) cere ID verification + 2FA + Roblox Plus/Premium, sau taxă unică rambursabilă de 1.000 Robux/joc | CONFIRMAT | Exact ca în notă | https://devforum.roblox.com/t/new-publishing-requirements-evaluation-process-for-games/4573166 (verificat 2026-09-08) |
| „2FA e obligatorie pentru orice cont care publică jocuri, indiferent de tier" | CORECTAT | 2FA e cerută explicit **doar la tier 3** (all-ages). Tier 1 (uz personal) nu are cerințe suplimentare; tier 2 (16+/Trusted Friends) cere doar age-check + cont activ 2+ zile — 2FA nu apare în cerințele tier 2 | https://devforum.roblox.com/t/new-publishing-requirements-evaluation-process-for-games/4573166 (verificat 2026-09-08) |
| ~100.000 de creatori existenți primesc 6 luni gratuite de Roblox Plus de la 19 mai 2026 | CONFIRMAT | „covering the cost of Roblox Plus for about one hundred thousand of our existing creators for the next 6 months"; eligibilitate pe baza unui snapshot de playtime la 13 aprilie 2026 | https://devforum.roblox.com/t/new-publishing-requirements-evaluation-process-for-games/4573166 (verificat 2026-09-08) |
| Roblox Kids (5–8) / Roblox Select (9–15), rollout „early June 2026"; jocurile incluse cer creator ID-verificat + 2FA + Roblox Plus | CONFIRMAT | Exact ca în notă | https://about.roblox.com/newsroom/2026/04/introducing-roblox-kids-and-select-accounts (verificat 2026-09-08) |
| Team Create „Collaborate" cere age-check din early 2026 (anunțat 19 nov. 2025); dezvoltarea/Team Create solo nu e afectată | CONFIRMAT | „All creators will still be able to create in Studio and use Team Create alone; this change only applies when using the Collaborate feature" | https://about.roblox.com/newsroom/2025/11/roblox-requires-age-checks-limits-minor-and-adult-chat și https://devforum.roblox.com/t/age-checks-to-access-chat-studio-team-create-and-links-on-roblox/4079702 (verificat 2026-09-08) |
| Rata DevEx $0.0038/Robux (Robux câștigat după 5 sept. 2025), minim 30.000 Robux la cash-out, rată separată $0.0054/Robux pt. cheltuieli in-game ale userilor 18+ SUA | CONFIRMAT | Confirmat direct pe pagina oficială (accesată prin proxy de citire, fetch direct tot blocat cu HTTP 403 ca și pentru autorul notei inițiale) — „0.0038 per 1 Earned Robux", „minimum of 30,000 Earned Robux", rată enhanced 0.0054 pentru achiziții calificate din SUA 18+ | https://en.help.roblox.com/hc/en-us/articles/13061189551124-Developer-Exchange-Help-and-Information-Page (verificat 2026-09-08, via r.jina.ai) |
| Modelul de limite DataStore „s-a schimbat" din per-server (~60+10×numJucători/min) la un pool unic per-experience, care a înlocuit modelul per-server | CORECTAT | Documentația oficială curentă descrie un sistem **dual-tier**: limite per-experience (pool partajat, ex. citiri „300 + concurrentUsers×40"/min) **și** limite per-server separate (ex. „60 + numPlayers×40"/min) coexistă — per-server nu a fost înlocuit de pool-ul unic, cele două nivele funcționează simultan | https://create.roblox.com/docs/cloud-services/data-stores/error-codes-and-limits (verificat 2026-09-08) |
| EditableImage/EditableMesh necesită cont 13+ ID-verificat pentru a funcționa în jocuri publicate | NEVERIFICABIL | Thread-ul oficial DevForum confirmă că e necesară ID verification pentru aceste API-uri, dar nu specifică explicit pragul de vârstă „13+"; nu am găsit pagină oficială de politică cu acest prag exact — cea mai bună dovadă secundară rămâne thread-ul DevForum citat, plus comparația cu pragul de 13+ folosit la Voice Chat | https://devforum.roblox.com/t/remove-required-id-verification-for-editablemeshesimages/3981479 (verificat 2026-09-08) |
| Next-Gen Studio UI „în rollout activ, extins la mai mulți creatori din 20 noiembrie 2025" | NEVERIFICABIL | Anunțul original DevForum e din **18 iulie 2024**, nu din noiembrie 2025; nu am găsit o sursă primară care să confirme explicit un „rollout extins" cu data de 20 noiembrie 2025 (poate exista un update ulterior în thread, dar fetch-ul disponibil a arătat doar postarea inițială din 2024) | https://devforum.roblox.com/t/next-gen-studio-ui-preview-is-here-beta/3075390 (verificat 2026-09-08) |
