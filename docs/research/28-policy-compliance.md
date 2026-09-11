# Politici Roblox și conformitate pentru Driftwood

## Rezumat executiv

- Roblox impune **divulgarea obligatorie a șanselor numerice** pentru orice "paid random item" (loot box / prize wheel / egg cumpărat cu Robux). Dacă vreo variantă a lăzilor din râu ajunge cumpărabilă direct cu Robux (nu doar câștigată prin gameplay), se aplică regula integral.
- Chestionarul de **Content Maturity** nu e "obligatoriu" prin literă — pagina oficială spune "Roblox strongly recommends" — dar consecința nefolosirii lui corecte este clară: *"Roblox restricts the playability of the experience on the platform for all players."* Practic e obligatoriu pentru orice joc care vrea trafic organic.
- Din 2025-2026, Roblox a lansat un sistem de **age assurance** (estimare facială a vârstei) care leagă direct de vârsta confirmată: chatul nefiltrat, linkurile externe (Discord etc.) și accesul la Studio Team Create. Cronologia e clară și datată: anunț iul. 2025 → cerință globală ian. 2026 → rebrand "Trusted Friends" apr. 2026.
- **TextChatService** e sistemul de chat implicit din martie 2023, iar Legacy Chat a fost deja **eliminat complet** (nu doar "în curs de eliminare") — deadline oficial 30 aprilie 2025, la peste un an înainte de data acestei note (corectat la verificare). Driftwood trebuie construit direct pe `TextChatService`, nu pe `ChatService`/`ChatVersion.LegacyChatService`.
- Orice text generat de jucător (nume custom pentru plasă/obiect reparat, chat) trebuie trecut prin `TextService:FilterStringAsync()`. Roblox **nu** filtrează automat conținutul afișat prin UI custom (Frame/TextLabel), doar chatul nativ.
- `PolicyService:GetPolicyInfoForPlayerAsync()` e API-ul unic pentru verificarea restricțiilor regionale (paid random items, trading, reclame) — trebuie apelat înainte de a arăta orice UI de recompensă aleatoare plătită.
- Roblox e certificat COPPA prin kidSAFE și are un mecanism propriu de GDPR right-to-erasure ("Deletion Queue" + Open Cloud webhook, plus un tool nou din sept. 2025 de ștergere de DataStore din dashboard). **Developerul răspunde pentru ștergerea datelor proprii din DataStore** — Roblox doar notifică, nu șterge automat datele custom ale jocului.
- Reclama in-experience standard (Billboard/Portal/Image ads) e proiectată pentru lumi 3D (dimensiuni în studs, `SurfaceGui`/`AdGui` pe părți din `Workspace`) — nu se mapează direct pe un joc 2D pur `ScreenGui`. Necesită testare separată în Studio ca să vedem dacă se poate folosi deloc.
- Datele pe care Driftwood le poate primi de la Roblox despre un jucător sunt limitate explicit la: username, display name, user ID, metrici de joc, detalii tranzacții UGC, locație regională aproximativă (din IP). **Explicit exclus: IP-ul brut nu se dă creatorilor.**
- Din iun. 2026 Roblox testează **Scoped User Identifiers** (user ID unic per joc) — schimbă modul în care orice analytics cross-game ar funcționa; pentru Driftwood (joc single-experience) impactul e mic, dar afectează orice integrare analytics externă viitoare.

## Fapte verificate

- Paid random items (loot boxes/prize wheels/eggs cumpărate cu Robux) trebuie să afișeze toate rezultatele posibile și șansele numerice exacte, ca procente însumând 100%. — https://create.roblox.com/docs/production/monetization/paid-random-items — accesat 2026-09-08 — confidence: ridicata
- Recompensele aleatorii câștigate gratuit prin gameplay (fără plată) NU necesită afișarea șanselor. — https://create.roblox.com/docs/production/monetization/paid-random-items — accesat 2026-09-08 — confidence: ridicata
- `PolicyService:GetPolicyInfoForPlayerAsync(player)` întoarce, printre altele, flag-urile `ArePaidRandomItemsRestricted` și `IsPaidItemTradingAllowed`; dacă restricționat, developerul trebuie să ofere alternativă neplătită, secvență fixă predeterminată, cumpărare directă garantată, ascundere sau blocare cu eroare. — https://create.roblox.com/docs/reference/engine/classes/PolicyService — accesat 2026-09-08 — confidence: ridicata
- Content Maturity: sistem cu 4 niveluri — Minimal/Mild (Roblox Kids 5-8 și Roblox Select 9-15), Moderate (Roblox Select 9-15 + conturi standard 16+), Restricted (doar utilizatori 18+ cu vârsta verificată). — https://create.roblox.com/docs/production/promotion/experience-guidelines — accesat 2026-09-08 — confidence: ridicata
- Chestionarul de content maturity acoperă **15 categorii** (nu 13 — corectat la verificare): violență (intensitate/frecvență), sânge, conținut înfricoșător, umor grosolan, gambling nejucabil, limbaj licențios, teme romantice, alcool, social hangouts, creație liberă a utilizatorilor, teme sensibile, **paid random items**, **paid item trading**, media sharing, interacțiuni AI. — https://create.roblox.com/docs/production/promotion/content-maturity — accesat 2026-09-08 — confidence: ridicata
- Chestionarul nu e strict "obligatoriu" ca acțiune, dar: *"If an experience does not have accurate or all content maturity information, Roblox restricts the playability of the experience on the platform for all players."* — https://create.roblox.com/docs/production/promotion/experience-guidelines — accesat 2026-09-08 — confidence: ridicata
- Experiențele cu "free-form user creation" și "social hangouts" au vârstă minimă de acces 16 ani conform aceleiași scheme de maturitate. — https://create.roblox.com/docs/production/promotion/experience-guidelines — accesat 2026-09-08 — confidence: medie (rezumat, nu citat literal)
- `TextService:FilterStringAsync(stringToFilter: string, fromUserId: number, textContext: Enum.TextFilterContext): TextFilterResult` este metoda pentru filtrarea textului generat de jucători (ex. nume custom) înainte de a-l arăta altor jucători; e asincronă, trebuie învelită în `pcall()`. — https://create.roblox.com/docs/reference/engine/classes/TextService — accesat 2026-09-08 — confidence: ridicata
- `TextChatService` e non-creatable; are proprietăți `ChatTranslationEnabled`, `ChatVersion` (marcat deprecated), `CreateDefaultTextChannels`, `PlatformIntegratedChat`; filtrarea se face prin evenimente `SendingMessage`/`MessageReceived`. — https://create.roblox.com/docs/reference/engine/classes/TextChatService — accesat 2026-09-08 — confidence: medie (pagina nu confirmă explicit dacă e default vs legacy)
- Thread oficial: "TextChatService is now the default for new experiences!" — devforum.roblox.com/t/textchatservice-is-now-the-default-for-new-experiences — 2023-03-16 — confidence: medie (titlu+dată din index de căutare, nu corpul integral)
- Thread oficial: "Migrate to TextChatService: Removing Support for Legacy Chat and Custom Chat Systems" — devforum.roblox.com/t/migrate-to-textchatservice-removing-support-for-legacy-chat-and-custom-chat-systems — 2024-10-30 — confidence: medie
- "Party Voice and chat without filters is only available for age-checked users and their eligible Connections. Filtered chat remains the standard for all other interactions." — https://en.help.roblox.com/hc/en-us/articles/4407444339348-Safety-Civility-at-Roblox — accesat 2026-09-08 — confidence: ridicata (citat literal)
- Pentru utilizatori sub 13 ani, filtrele de chat sunt și mai stricte, incluzând orice informație potențial identificabilă și slang. Mesajele cu limbaj vulgar pot fi re-formulate automat. Schimbul de imagini/video prin chat e interzis pentru toți utilizatorii. — https://en.help.roblox.com/hc/en-us/articles/4407444339348-Safety-Civility-at-Roblox — accesat 2026-09-08 — confidence: ridicata
- Roblox e membru kidSAFE Seal Program (certificare COPPA) și nu partajează date personale cu terți pentru useri sub 13 ani dincolo de ce permite COPPA. — https://en.help.roblox.com/hc/en-us/articles/4407444339348-Safety-Civility-at-Roblox — accesat 2026-09-08 — confidence: ridicata
- Anunț oficial: "Connecting with Confidence on Roblox: Introducing Trusted Connections, Age Estimation and Privacy Tools" — devforum.roblox.com — 2025-07-17 — confidence: medie (titlu+dată+excerpt din index)
- Anunț oficial: "Age Checks to Access Chat, Studio Team Create, and Links on Roblox" — devforum.roblox.com — 2025-11-18 — confidence: medie
- Anunț oficial: "Age Check Requirement to Chat Now Live Globally" — devforum.roblox.com — 2026-01-07 — confidence: medie
- Anunț oficial: "An Update on Our Age Check to Chat Fast Follow Roadmap" — devforum.roblox.com — 2026-01-23 — confidence: medie
- Anunț oficial: "Friends Are Back! Expanding Trusted Friends for a New Way to Chat and Play" (rebrand "Trusted Connections" → "Trusted Friends") — devforum.roblox.com — 2026-04-02 — confidence: medie
- Sistemul de "age-assurance" al Roblox procesează aproape 2 miliarde de înregistrări la nivel de cont pe zi și a procesat 338 de milioane de "age-check records" până la data articolului; combină XGBoost, transformers multilingve și rețele neuronale printr-un meta-learner gradient-boosted. — https://about.roblox.com/newsroom/2026/08/beyond-selfie-how-roblox-age-assurance-system-helps-keep-age-checks-current- — 2026-08 — confidence: medie (rezumat WebFetch, nu citat literal complet)
- Reclamă in-experience: 3 formate — Billboard (video ≤30s sau imagine statică), Portal ads (imagine statică cu "ușă" ce teleportează într-un alt joc), Image ads (imagini statice non-clickable în spațiul 3D). Dimensiune bloc: minim 8×4.5 studs, maxim 32×18 studs. Necesită `Workspace`, nu poate partaja aceeași față cu alt `AdGui`/`SurfaceGui`. — https://create.roblox.com/docs/production/monetization/immersive-ads — accesat 2026-09-08 — confidence: ridicata
- Pentru a monetiza prin reclame in-experience, publisherul trebuie să aibă 13+ ani. Plata se face pe 25 ale lunii următoare inserării unității de reclamă. Userii neeligibili văd imagine fallback custom sau logo Roblox, verificat prin `PolicyService:GetPolicyInfoForPlayerAsync()`. — https://create.roblox.com/docs/production/monetization/immersive-ads — accesat 2026-09-08 — confidence: ridicata
- Users sub 18 ani văd doar reclame nepersonalizate; users 18+ pot vedea reclame personalizate (cu consimțământ acolo unde e cerut de lege). — https://en.help.roblox.com/hc/en-us/articles/115004630823-Roblox-Privacy-and-Cookie-Policy — Effective Date: April 30, 2026 — confidence: ridicata
- Creatorii de experiențe primesc de la Roblox despre un jucător: username, display name, user ID, metrici de joc, detalii tranzacții UGC, locație regională (derivată din IP) — dar **nu** primesc IP-ul brut al jucătorului. — https://en.help.roblox.com/hc/en-us/articles/115004630823-Roblox-Privacy-and-Cookie-Policy — Effective Date: April 30, 2026 — confidence: ridicata (citat aproape literal)
- La ștergerea contului, Roblox inițiază ștergerea permanentă a datelor din sistemele proprii; pentru siguranță/securitate (prevenire bot-uri), poate procesa identificatori persistenți încă până la 2 ani după ștergerea contului. — https://en.help.roblox.com/hc/en-us/articles/115004630823-Roblox-Privacy-and-Cookie-Policy — Effective Date: April 30, 2026 — confidence: ridicata
- Pentru "age assurance" (estimare facială), imaginile colectate (ex. selfie) sunt șterse imediat ce procesul de verificare a vârstei se încheie — vezi și "Roblox Facial Media Capture Policy" (document separat, nefetch-uit direct). — https://en.help.roblox.com/hc/en-us/articles/115004630823-Roblox-Privacy-and-Cookie-Policy — Effective Date: April 30, 2026 — confidence: ridicata
- Reprezentant GDPR UE: DP-Dock GmbH, Hamburg; reprezentant UK: DP Data Protection Services UK Ltd, Londra; DPO UE: DP Dock DPO Services GmbH, Kiel (roblox@dp-officer.com); contact general privacy: privacy@roblox.com. — https://en.help.roblox.com/hc/en-us/articles/115004630823-Roblox-Privacy-and-Cookie-Policy — Effective Date: April 30, 2026 — confidence: ridicata
- Pentru Developer Exchange (DevEx), Roblox poate cere verificarea identității prin ID emis de guvern, printr-un vendor terț, plus formular IRS W-9 (SUA)/W-8 (non-SUA). Program disponibil doar pentru useri de 13+ ani. — https://en.help.roblox.com/hc/en-us/articles/115004630823-Roblox-Privacy-and-Cookie-Policy — Effective Date: April 30, 2026 — confidence: ridicata
- Roblox operează o "Deletion Queue" prin care developerii primesc notificări de "Right to Erasure" pentru jucători care au cerut ștergerea datelor conform GDPR; există workflow-uri oficiale de automatizare via webhook + Open Cloud API. — devforum.roblox.com, thread "Roblox Deletion Queue - Right to Erasure Action Requested" (2025-10-26) și "Automate RtbF Processing with Webhook and Open Cloud" (2023-06-21) — confidence: medie (titlu+excerpt, nu corp integral)
- În sept. 2025 Roblox a introdus un tool nou în Creator Dashboard pentru ștergerea DataStore-urilor direct din consolă de management ("Introducing Data Stores Deletion"). — devforum.roblox.com — 2025-09-17 — confidence: medie
- Din iun. 2026, Roblox testează în beta opțional "Scoped User Identifiers" — un user ID unic per joc, ce previne tracking-ul cross-game; nu necesită acțiune din partea developerilor care nu participă la test. — devforum.roblox.com, thread "Update on Safety & Privacy: Introducing Scoped User Identifiers" — 2026-06-10 — confidence: medie
- Engagement-Based Payouts (plăți bazate pe timp petrecut de useri Premium) au fost eliminate, efectiv 24 iulie 2025, și înlocuite cu programul Creator Rewards. — https://create.roblox.com/docs (pagina "Engagement-based payouts") — accesat 2026-09-08 — confidence: ridicata (citat literal)
- Thread oficial din 2023 despre proprietate intelectuală pentru creatori: "Protecting Creativity by Understanding Intellectual Property", update datat 1 septembrie 2023 — există, dar conținutul complet nu a putut fi extras (blocat de anti-bot); necesită citire directă pe devforum. — devforum.roblox.com — 2023-08-25 (update 2023-09-01) — confidence: scazuta (doar titlu+dată confirmate, conținut NEVERIFICAT)
- Roblox conectează linkurile externe (ex. Discord) de politica regională/de vârstă: există thread-uri comunitare confirmând suspendări de jocuri pentru linkuri Discord chiar și când erau "wrapped" în `PolicyService`, plus un API (`GetPolicyInfoForPlayerAsync`) folosit de developeri ca să arate linkuri Discord doar userilor eligibili. Regulile exacte NEVERIFICAT din sursă primară oficială (Community Standards) — nu am putut încărca pagina de Community Standards direct (403/404 repetate). — devforum.roblox.com (mai multe thread-uri, 2021-2026) — confidence: scazuta pentru regula exactă, medie pentru existența mecanismului

## Detalii

### 1. Paid random items — regula de divulgare a șanselor

Politica se aplică oricărui rezultat randomizat cumpărat cu Robux sau cu monedă in-game cumpărată cu Robux (prize wheels, loot boxes, "eggs"). Cerințe concrete confirmate din documentație:

- Toate rezultatele posibile + șansele numerice exacte trebuie afișate, ca procente însumând exact 100%.
- Zecimale lungi pot fi rotunjite la minim 4 zecimale **sub poziția primei cifre nenule** (nu un "minim 4 zecimale" fix — corectat la verificare), cu un disclaimer.
- Când multe obiecte au aceeași șansă, se poate scrie compact: "Odds for each item listed below: X%".
- Dacă sunt prea multe rezultate pentru UI, șansele pot fi într-un pop-up clicabil cu etichetă descriptivă ("Details"/"Info") — o simplă iconiță fără text NU e suficientă.
- Dacă un modificator de probabilitate există (luck boost, rate-up, sistem de pity), trebuie explicat numeric înainte de cumpărare.
- **Excepție:** recompense aleatorii câștigate gratis prin gameplay (fără plată) NU necesită divulgare de șanse.

Regional: `PolicyService:GetPolicyInfoForPlayerAsync(player)` întoarce `ArePaidRandomItemsRestricted` (bool). Dacă `true`, developerul trebuie să implementeze una din: alternativă gratuită obținută prin joc, secvență predeterminată (nu random), cumpărare directă garantată a obiectului dorit, ascunderea completă a mecanicii, blocare cu eroare, sau separarea pe zonă/instanță.

```lua
local PolicyService = game:GetService("PolicyService")
local Players = game:GetService("Players")

local function canShowPaidRandomItems(player)
    local ok, policyInfo = pcall(function()
        return PolicyService:GetPolicyInfoForPlayerAsync(player)
    end)
    if not ok then
        warn("PolicyService call failed:", policyInfo)
        return false -- fail-safe: nu arăta mecanica dacă nu poți verifica
    end
    return not policyInfo.ArePaidRandomItemsRestricted
end
```

**Relevanță directă pentru Driftwood:** dacă vreodată apare o "ladă premium" cumpărabilă cu Robux care conține materiale/obiecte random, cade integral sub această regulă. Sistemul de bază (râul aduce obiecte gratuit, offline accumulation) NU cade sub regulă cât timp nu se plătește direct pentru un rezultat randomizat.

### 2. Content Maturity — chestionar și vizibilitate pe vârste

| Nivel | Public accesibil |
|---|---|
| Minimal / Mild | Roblox Kids (5-8) și Roblox Select (9-15), plus conturi standard |
| Moderate | Roblox Select (9-15) și conturi standard (16+) |
| Restricted | Doar useri cu vârsta verificată 18+ |

Chestionarul acoperă **15 categorii** (nu 13 — corectat la verificare; Roblox nu declară explicit un total, dar documentația enumeră 15 subiecte) (violență, sânge, frică, umor grosolan, gambling nejucabil, limbaj, romantism, alcool, social hangouts, creație liberă, teme sensibile, **paid random items**, **paid item trading**, media sharing, interacțiuni AI). Nu completarea corectă => *"Roblox restricts the playability of the experience on the platform for all players."* — deci deși tehnic "recomandat", efectul practic e obligatoriu.

Pentru Driftwood: jocul (râu, reparat, colecție, atelier comun) nu conține conținut matur — target realist e **Minimal/Mild**, ceea ce maximizează audiența (inclusiv Roblox Kids 5-8). Categoria "paid random items" din chestionar trebuie bifată onest dacă se implementează vreo ladă premium cu conținut random cumpărat.

### 3. Chat, filtrare text și age assurance (2025-2026)

**TextChatService** e implicit din martie 2023; Legacy Chat a fost deja **eliminat complet, cu deadline oficial 30 aprilie 2025** (nu "în proces de eliminare" — corectat la verificare; thread anunț oct. 2024, cu etape intermediare 30 nov. 2024 și 30 ian. 2025). Proprietăți confirmate din class reference: `ChatTranslationEnabled`, `ChatVersion` (deprecated), `CreateDefaultCommands`, `CreateDefaultTextChannels`, `PlatformIntegratedChat`. Filtrarea automată a chatului nativ se face prin Roblox server-side; pentru text custom (nume de plasă, nume de obiect reparat, orice string introdus de jucător și persistat/afișat altor jucători) developerul trebuie să apeleze explicit:

```lua
local TextService = game:GetService("TextService")

local function filterPlayerText(rawText, fromPlayer)
    local ok, result = pcall(function()
        return TextService:FilterStringAsync(rawText, fromPlayer.UserId, Enum.TextFilterContext.PublicChat)
    end)
    if not ok then
        warn("FilterStringAsync failed:", result)
        return nil
    end
    -- rezultatul trebuie apoi convertit per-viewer, ex:
    -- local ok2, filtered = pcall(function() return result:GetNonChatStringForBroadcastAsync() end)
    return result
end
```

Din 2025, Roblox a introdus un sistem de **age assurance** (estimare facială a vârstei, "age-check") care determină accesul la:
- Chat nefiltrat / Party Voice ("only available for age-checked users and their eligible Connections" — citat din Safety & Civility);
- Linkuri externe în experiență (Discord etc.) — legate explicit de age-check din anunțul din nov. 2025;
- Studio Team Create.

Cronologie confirmată (titluri + date, devforum.roblox.com, corp complet neaccesibil din cauza blocării anti-bot pe pagini `/t/`):
1. 2025-07-17 — "Connecting with Confidence on Roblox: Introducing Trusted Connections, Age Estimation and Privacy Tools" (anunțul original)
2. 2025-11-18 — "Age Checks to Access Chat, Studio Team Create, and Links on Roblox"
3. 2026-01-07 — "Age Check Requirement to Chat Now Live Globally"
4. 2026-01-23 — "An Update on Our Age Check to Chat Fast Follow Roadmap"
5. 2026-04-02 — "Friends Are Back! Expanding Trusted Friends for a New Way to Chat and Play" — rebrand "Trusted Connections" → "Trusted Friends"

Articolul tehnic din newsroom (aug. 2026, "Beyond the Selfie") descrie sistemul ca fiind continuu (nu doar un check unic la selfie): ~2 miliarde de înregistrări la nivel de cont procesate zilnic, 338 milioane "age-check records" acumulate, combinând XGBoost + transformers multilingve + rețele neuronale printr-un meta-learner. Imaginile folosite pentru verificare (selfie) sunt șterse imediat după procesare, conform Privacy Policy.

**Implicație pentru Driftwood:** dacă jocul are chat text propriu (ex. chat de zonă/oraș), userii ne-age-checked vor avea automat chat filtrat mai strict; nu există control developer separat peste asta — e la nivel de platformă, nu de experiență.

### 4. Linkuri externe (Discord/YouTube)

Nu am putut încărca direct pagina oficială de Community Standards (403 pe WebFetch pentru en.help.roblox.com, 404 pe URL-urile ghicite din create.roblox.com/docs). Din surse secundare (thread-uri devforum, cu titlu+dată confirmate, dar fără corp complet):
- Linkurile externe sunt tratate ca politică sensibilă la vârstă/regiune — thread oficial nov. 2025 leagă explicit "Links" de age-check, alături de chat și Team Create.
- Există un pattern comunitar de a arăta linkuri Discord condiționat, verificând `PolicyService:GetPolicyInfoForPlayerAsync()` înainte de afișare — dar există și reclamații (2025-2026) despre suspendări de jocuri cu linkuri Discord chiar și quando "wrapped" în verificare de policy.
- **NEVERIFICAT:** regula exactă (ce tip de link e permis, unde poate apărea, ce text trebuie să însoțească) — necesită citire directă a Community Standards pe cont propriu, din browser normal (pagina pare protejată de Cloudflare/anti-bot pentru fetch automatizat).

### 5. Date personale, COPPA, GDPR

Sursă primară: Roblox Privacy and Cookie Policy, Effective Date **April 30, 2026**.

Puncte cheie pentru un developer (nu utilizator):
- **Ce date primește creatorul despre un jucător:** username, display name, user ID, metrici de joc, detalii de tranzacție UGC, locație regională (derivată din IP). **IP-ul brut NU se dă creatorilor.**
- Pentru useri sub 13 ani, Roblox colectează doar: username, parolă, dată de naștere (toate obligatorii), gen (opțional), opțional email de părinte. Nu se cere alt PII.
- Filtrarea elimină din orice conținut public (chat, forumuri, group walls, posturi): PII (adrese, emailuri, telefoane), încercări de phishing, cuvinte ofensatoare/conținut sexual.
- Retenție: date persistente păstrate cât timp există contul; la ștergerea contului, ștergere permanentă în sistemele Roblox, cu excepția identificatorilor persistenți reținuți până la 2 ani pentru prevenire fraudă/bot-uri.
- Reprezentanți GDPR: EEA — DP-Dock GmbH (Hamburg); UK — DP Data Protection Services UK Ltd (Londra); DPO UE — DP Dock DPO Services GmbH (Kiel, roblox@dp-officer.com). Contact general: privacy@roblox.com.

**Obligația developerului (Driftwood) privind GDPR right-to-erasure:** Roblox NU șterge automat datele custom pe care Driftwood le salvează în propriile `DataStore`-uri. Din thread-uri oficiale devforum: Roblox trimite notificări printr-o **"Deletion Queue"** când un jucător cere ștergerea datelor conform GDPR ("Right to Erasure"), iar developerul trebuie să șteargă manual (sau automatizat) datele respective din DataStore-urile proprii. Există:
- un pattern oficial de automatizare prin webhook + Open Cloud API (thread 2023-06-21);
- un tool nou (sept. 2025) în Creator Dashboard pentru ștergerea DataStore-urilor direct din consolă.

Termenul exact (SLA în zile) pentru conformare **NEVERIFICAT** din sursele accesate — recomand citirea directă a documentației Open Cloud / GDPR pe create.roblox.com înainte de lansare.

### 6. Reclame in-experience

| Format | Descriere | Dimensiune |
|---|---|---|
| Billboard | Video ≤30s (click-to-play sau autoplay) sau imagine statică | 8×4.5 — 32×18 studs |
| Portal ads | Imagine statică cu "ușă" ce teleportează în alt joc | 8×4.5 — 32×18 studs |
| Image ads | Imagine statică non-clickable | 8×4.5 — 32×18 studs |

Reguli tehnice: unitatea trebuie să fie neobstrucționată, în `Workspace`, nu poate partaja aceeași față cu alt `AdGui`/`SurfaceGui`; reclamele video necesită `EnableVideoAds` bifat. Userii neeligibili (regional/vârstă, verificat via `PolicyService`) văd imagine fallback custom sau logo Roblox. Publisherul trebuie să aibă 13+ ani. Plata pe 25 ale lunii următoare inserării.

**Risc pentru Driftwood:** acest sistem e proiectat pentru `Workspace`/`Part`/`SurfaceGui` — jocuri 3D. Driftwood e 2D pur ScreenGui. NEVERIFICAT dacă/cum se poate integra un `AdGui` într-un joc fără parts 3D vizibile — de testat direct în Studio, posibil printr-un part 3D "ascuns" în afara camerei doar pentru a găzdui reclama, sau prin renunțare completă la acest canal de monetizare.

### 7. Proprietate intelectuală (Creator Terms)

Există un thread oficial devforum, "Protecting Creativity by Understanding Intellectual Property" (postat 2023-08-25, update datat 1 septembrie 2023), dar conținutul complet nu a putut fi extras (blocat repetat de protecția anti-bot a devforum pe pagini `/t/`). Conform notei legale deja din CLAUDE.md al proiectului, strategia Driftwood (mecanici inspirate din Stardew Valley, fără assets/nume/muzică copiate) e aliniată cu principiul general că mecanicile de joc nu sunt protejate de copyright — dar clauzele exacte ale Creator Terms (ce licență capătă Roblox asupra UGC-ului încărcat, ce păstrează creatorul) sunt **NEVERIFICAT** din sursă primară în această sesiune și trebuie citite direct de pe roblox.com/creator-terms-of-service sau echivalent înainte de lansare comercială.

## Recomandari concrete pentru Driftwood

1. **Construiește chat-ul (dacă există) exclusiv pe `TextChatService`**, niciodată pe Legacy Chat — sistemul vechi a fost deja **eliminat oficial din 30 aprilie 2025** (corectat la verificare; thread anunț oct. 2024), nu doar "în curs de eliminare".
2. **Trece orice string generat de jucător prin `TextService:FilterStringAsync()`** înainte de a-l arăta altor jucători — inclusiv nume custom de plase/obiecte reparate dacă adaugi personalizare, nu doar chat. Roblox nu filtrează automat text în `Frame`/`TextLabel` custom.
3. **Completează chestionarul de Content Maturity cu grijă la lansare**, țintind Minimal/Mild pentru audiență maximă — reverifică-l dacă adaugi vreo mecanică de tip loot cumpărat sau trading.
4. **Verifică `PolicyService:GetPolicyInfoForPlayerAsync()` înainte de a arăta orice ladă/pachet cu conținut random cumpărat cu Robux** — implementează fail-safe (nu arăta mecanica dacă apelul eșuează) și cel puțin o alternativă non-random (ex. cumpărare directă garantată a materialului dorit).
5. **Dacă implementezi vreun "ladă premium" plătită, afișează șansele numerice explicit, ca procente însumând 100%**, din prima versiune — retrofit-ul e mai costisitor decât proiectarea corectă de la început.
6. **Nu implementa linkuri Discord/YouTube in-game fără să citești întâi Community Standards direct din browser** (pagina oficială nu a putut fi verificată automat în această sesiune) — riscul e suspendarea jocului, documentat în reclamații reale devforum din 2025-2026.
7. **Proiectează salvarea de date presupunând GDPR right-to-erasure de la început**: structurează `DataStore`-urile per-jucător astfel încât o ștergere completă a datelor unui user (la cerere) să fie o singură operație (`RemoveAsync` pe cheia userului), nu o căutare prin zeci de chei disparate.
8. **Nu te baza pe reclame in-experience (Billboard/Portal/Image) ca sursă principală de monetizare** — sistemul e gândit pentru lumi 3D; testează în Studio dacă se poate integra deloc într-un joc ScreenGui pur, înainte de a-l include în planul de monetizare.
9. **Nu colecta și nu stoca PII dincolo de ce oferă Roblox nativ** (username, display name, userId) — orice sistem de "prieteni" sau clasament custom trebuie să folosească userId, nu email/nume real, pentru a rămâne în afara scope-ului GDPR/COPPA complex.
10. **Documentează explicit categoria "paid random items = Nu" în chestionar** cât timp mecanica de bază (râul + reparat) rămâne 100% gameplay-earned, ca să eviți orice ambiguitate de audit din partea Roblox Trust & Safety.
11. **Citește integral Creator Terms of Service și Community Standards direct pe roblox.com/en.help.roblox.com din browserul propriu** înainte de submit pentru publicare — aceste pagini au blocat accesul automatizat în această sesiune de research (403/404 repetate), deci nu pot fi considerate pe deplin verificate aici.

## Riscuri si necunoscute

- **Pagina oficială "Roblox Community Standards"** (regulile centrale de conduită/conținut interzis) nu a putut fi încărcată direct în această sesiune (403 pe WebFetch, navigare browser blocată repetat de protecția anti-bot a en.help.roblox.com). Recomandările despre linkuri externe și monetizare înșelătoare se bazează pe surse secundare (thread-uri comunitare) și pe conținut adiacent (Safety & Civility, Privacy Policy) — nu pe textul integral al politicii centrale.
- **Reguli exacte pentru "misleading monetization"** (dincolo de best-practice-urile pentru Premium purchase modal găsite) nu au putut fi confirmate dintr-o pagină dedicată — pagina ghicită a returnat 404.
- **SLA exact pentru GDPR right-to-erasure** (câte zile are developerul la dispoziție după notificare) nu a fost găsit — doar existența mecanismului ("Deletion Queue", webhook, tool de ștergere DataStore) e confirmată.
- **Clauzele exacte ale Creator Terms privind IP-ul** (licența acordată către Roblox pe UGC încărcat) nu au putut fi extrase — doar existența și data documentului oficial.
- **Compatibilitatea reclamelor in-experience cu un joc 2D ScreenGui pur** e complet neverificată — sistemul documentat presupune parts 3D în `Workspace`.
- Mediul de browsing folosit în această sesiune de research a fost instabil (tab-uri partajate cu alți agenți paraleli, navigări respinse aleatoriu) — orice discrepanță ar trebui reverificată manual într-un browser normal.
- Toate datele "2026" din surse (ex. Privacy Policy effective April 30, 2026, newsroom aug. 2026) sunt curente la data acestei cercetări (2026-09-08), dar Roblox actualizează frecvent politicile — reverifică înainte de lansare dacă trec luni.

## Intrebari deschise

1. Community Standards integral trebuie citit manual (nu automatizat) înainte de lansare — cine face asta și când?
2. Va avea Driftwood vreun sistem de chat propriu (peste `TextChatService`) sau doar UI social minimal (ex. emote-uri predefinite, fără text liber)? Decizia afectează direct cât de mult din regulile de age-check/filtrare trebuie implementat manual.
3. Se va implementa vreodată o "ladă premium" cumpărată direct cu Robux (nu doar materiale earned + skip time cu Developer Products)? Dacă da, planul de UI pentru odds disclosure trebuie proiectat din faza de design, nu adăugat ulterior.
4. Va exista un server Discord oficial pentru comunitate, promovat in-game? Dacă da — necesită citirea directă a Community Standards + testare a unui link `PolicyService`-gated în Studio, cu cont de test sub 13 ani (dacă e posibil) pentru a verifica comportamentul real.
5. Cine se ocupă de conformarea GDPR practică (ștergere DataStore la cerere) — e nevoie de un script/webhook dedicat conectat la Open Cloud înainte de lansarea comercială în UE?
6. Reclamele in-experience rămân în planul de monetizare sau sunt eliminate din cauza incompatibilității arhitecturale cu 2D ScreenGui? Necesită un test practic în Studio.
7. DevEx cash-out (menționat deja în CLAUDE.md) va necesita verificare ID prin vendor terț — cine din echipă trece prin acest proces și când (probabil abia la prima cerere de cash-out)?

## Surse

- Content Maturity Framework — https://create.roblox.com/docs/production/promotion/experience-guidelines — accesat 2026-09-08
- Paid Random Items — https://create.roblox.com/docs/production/monetization/paid-random-items — accesat 2026-09-08
- PolicyService (class reference) — https://create.roblox.com/docs/reference/engine/classes/PolicyService — accesat 2026-09-08
- TextChatService (class reference) — https://create.roblox.com/docs/reference/engine/classes/TextChatService — accesat 2026-09-08
- TextService / FilterStringAsync (class reference) — https://create.roblox.com/docs/reference/engine/classes/TextService — accesat 2026-09-08
- Immersive Ads (reclame in-experience) — https://create.roblox.com/docs/production/monetization/immersive-ads — accesat 2026-09-08
- Engagement-based payouts (deprecat, înlocuit de Creator Rewards efectiv 24 iulie 2025) — https://create.roblox.com/docs (pagina "Engagement-based payouts") — accesat 2026-09-08
- Safety & Civility at Roblox — https://en.help.roblox.com/hc/en-us/articles/4407444339348-Safety-Civility-at-Roblox — accesat 2026-09-08
- Roblox Privacy and Cookie Policy — https://en.help.roblox.com/hc/en-us/articles/115004630823-Roblox-Privacy-and-Cookie-Policy — Effective Date: 30 aprilie 2026, accesat 2026-09-08
- "Beyond the Selfie: How Roblox's Age-Assurance System Helps Keep Age Checks Current" — https://about.roblox.com/newsroom/2026/08/beyond-selfie-how-roblox-age-assurance-system-helps-keep-age-checks-current- — august 2026
- devforum.roblox.com, index de căutare (search.json), thread-uri oficiale (titlu+dată+excerpt, corp integral neaccesibil din cauza protecției anti-bot pe pagini `/t/`):
  - "TextChatService is now the default for new experiences!" — 2023-03-16
  - "Migrate to TextChatService: Removing Support for Legacy Chat and Custom Chat Systems" — 2024-10-30
  - "Connecting with Confidence on Roblox: Introducing Trusted Connections, Age Estimation and Privacy Tools" — 2025-07-17
  - "Age Checks to Access Chat, Studio Team Create, and Links on Roblox" — 2025-11-18
  - "Age Check Requirement to Chat Now Live Globally" — 2026-01-07
  - "An Update on Our Age Check to Chat Fast Follow Roadmap" — 2026-01-23
  - "Friends Are Back! Expanding Trusted Friends for a New Way to Chat and Play" — 2026-04-02
  - "Protecting Creativity by Understanding Intellectual Property" — 2023-08-25 (update 2023-09-01)
  - "Introducing Data Stores Deletion" — 2025-09-17
  - "Roblox Deletion Queue - Right to Erasure Action Requested" — 2025-10-26
  - "Automate RtbF Processing with Webhook and Open Cloud" — 2023-06-21
  - "Update to GDPR Right-to-be-Forgotten Messaging" — 2020-11-23 (posibil depășit — flag conform instrucțiunilor pentru surse pre-2024)
  - "Update on Safety & Privacy: Introducing Scoped User Identifiers" — 2026-06-10
  - "GetPolicyInfoForPlayerAsync - Rarely used function that allows for in-game Discord links" — 2021-09-01 (secundar, posibil depășit)
  - "I need help on right-of-erasure-request" — 2024-03-01 (secundar)
  - "Right to Be Forgotten - Keep getting messages despite having no datastores" — 2026-06-13 (secundar, confirmă că sistemul e încă activ)
- Pagini care NU au putut fi accesate în această sesiune (de reverificat manual): en.help.roblox.com/hc/en-us/articles/203313410-Roblox-Community-Standards (403), en.help.roblox.com/hc/en-us/articles/115004647846-Roblox-Terms-of-Use (403), create.roblox.com/docs/production/monetization/marketplace-policy (404), create.roblox.com/docs/production/promotion/community-standards (404).

## Verificare independenta (2026-09-08)

Verificare efectuată de un agent separat, prin re-fetch direct al surselor primare (create.roblox.com/docs, en.help.roblox.com, devforum.roblox.com, about.roblox.com), nu prin re-citirea citatelor din notă. 14 afirmații cu impact ridicat asupra deciziilor de proiect au fost reverificate.

| Afirmatie | Verdict | Valoare corecta | Sursa (URL, data) |
|---|---|---|---|
| Paid random items (loot boxes/eggs cumpărate cu Robux) trebuie să afișeze toate rezultatele + șansele numerice, procente însumând 100%; recompensele gratuite prin gameplay sunt exceptate. | CONFIRMAT | Confirmat literal: "the probability percentages of all final outcomes must sum to exactly 100%"; exceptie confirmată pentru recompense fără plată Robux. | https://create.roblox.com/docs/production/monetization/paid-random-items — accesat 2026-09-09 |
| Zecimalele lungi ale probabilităților "pot fi rotunjite la minim 4 zecimale, cu un disclaimer" (regulă descrisă ca prag fix). | CORECTAT | Regula reală: rotunjire la "four or more decimal places lower than the decimal place with the first non-zero number" — adică pragul e relativ la poziția primei cifre nenule, nu un minim fix de 4 zecimale (contează pentru probabilități foarte mici, sub 0.0001%). | https://create.roblox.com/docs/production/monetization/paid-random-items — accesat 2026-09-09 |
| `PolicyService:GetPolicyInfoForPlayerAsync()` întoarce printre altele `ArePaidRandomItemsRestricted` și `IsPaidItemTradingAllowed`. | CONFIRMAT | Ambele câmpuri există exact cu aceste nume, plus alte câmpuri (AreAdsAllowed, IsContentSharingAllowed, IsEligibleToPurchaseCommerceProduct, IsEligibleToPurchaseSubscription, IsPhotoToAvatarAllowed, IsSubjectToChinaPolicies, AllowedExternalLinkReferences, IsEndlessContentLoadAllowed/AutoplayAllowed). | https://github.com/Roblox/creator-docs/blob/main/content/en-us/reference/engine/classes/PolicyService.yaml + https://create.roblox.com/docs/reference/engine/classes/PolicyService — accesat 2026-09-09 |
| Content Maturity are 4 niveluri (Minimal/Mild, Moderate, Restricted) cu accesul pe vârste: Minimal/Mild → Roblox Kids 5-8 + Select 9-15; Moderate → Select 9-15 + standard 16+; Restricted → doar 18+ verificat. | CONFIRMAT | Confirmat exact, inclusiv citatul despre consecința datelor lipsă/incorecte: "Roblox restricts the playability of the experience on the platform for all players." | https://create.roblox.com/docs/production/promotion/experience-guidelines — accesat 2026-09-09 |
| Chestionarul de Content Maturity acoperă 13 categorii. | CORECTAT | Documentația Roblox (pagina dedicată "Content maturity and compliance") enumeră **15** subiecte/categorii (violență, sânge, frică, umor grosolan, gambling nejucabil, limbaj, romantism, alcool, social hangout, creație liberă, teme sensibile, paid random items, paid item trading, media, interacțiuni AI); Roblox nu declară explicit un total, dar sunt 15, nu 13. | https://create.roblox.com/docs/production/promotion/content-maturity — accesat 2026-09-09 |
| TextChatService e sistemul de chat implicit din martie 2023 (thread oficial 2023-03-16). | CONFIRMAT | Data exactă a postării confirmată: "March 16, 2023, 10:18pm". | https://devforum.roblox.com/t/textchatservice-is-now-the-default-for-new-experiences/2220324 — accesat 2026-09-09 |
| Legacy Chat este "în curs de eliminare" / "în proces de eliminare" (stare descrisă ca fiind încă în desfășurare). | DEPASIT | Legacy Chat a fost deja **eliminat complet** — anunțat 2024-10-30, cu etape 2024-11-30 (fără experiențe noi pe Legacy Chat) și 2025-01-30 (migrare `CanUserDirectChatAsync`), deadline final de eliminare **30 aprilie 2025**. La data verificării (sept. 2026), procesul e încheiat de peste un an — nu mai e "în curs". | https://devforum.roblox.com/t/migrate-to-textchatservice-removing-support-for-legacy-chat-and-custom-chat-systems/3237100 — accesat 2026-09-09 |
| Cronologia age-assurance: 2025-07-17 (anunț) → 2025-11-18 ("Age Checks to Access Chat...") → 2026-01-07 ("...Now Live Globally") → 2026-01-23 (update roadmap) → 2026-04-02 (rebrand "Trusted Friends"). | CONFIRMAT | Datele exacte de postare verificate direct pe cele mai importante două thread-uri: 2025-11-18 ("November 18, 2025, 5:00pm") și 2026-01-07 ("January 7, 2026, 5:00pm"); celelalte trei date confirmate din titlu+context de căutare. | https://devforum.roblox.com/t/age-checks-to-access-chat-studio-team-create-and-links-on-roblox/4079702 ; https://devforum.roblox.com/t/age-check-requirement-to-chat-now-live-globally/4226101 — accesat 2026-09-09 |
| Sistemul de age-assurance procesează ~2 miliarde de înregistrări la nivel de cont/zi, a procesat 338 milioane "age-check records", combină XGBoost + transformers multilingve + rețele neuronale printr-un meta-learner gradient-boosted. | CONFIRMAT | Citat literal: "processes close to two billion account-level records each day"; "processed 338 million age-check records"; foloseste "XGBoost classifiers", un "fine-tuned multilingual transformer encoder (mmBERT)", "Multilayer Perceptron" și un "gradient-boosted meta-learner". | https://about.roblox.com/newsroom/2026/08/beyond-selfie-how-roblox-age-assurance-system-helps-keep-age-checks-current- — accesat 2026-09-09 |
| Reclame in-experience: 3 formate (Billboard/Portal/Image), video ≤30s, dimensiune 8×4.5–32×18 studs, publisher 13+ ani, payout pe 25 ale lunii următoare. | CONFIRMAT | Toate valorile confirmate literal, inclusiv exemplul: "if you insert ad units during March, your payout date... is April 25." (plus cerințe suplimentare neincluse în notă: minim 2000 vizitatori lunici unici, 2FA activat, verificare ID.) | https://create.roblox.com/docs/production/monetization/immersive-ads — accesat 2026-09-09 |
| Engagement-Based Payouts eliminate efectiv 24 iulie 2025, înlocuite cu Creator Rewards. | CONFIRMAT | Citat literal: "Effective July 24, 2025, the Engagement-Based Payouts program is deprecated and has been replaced by the Creator Rewards program." | https://create.roblox.com/docs/production/monetization/engagement-based-payouts — accesat 2026-09-09 |
| Creatorii primesc de la Roblox despre un jucător: username, display name, user ID, metrici de joc, tranzacții UGC, locație regională (din IP) — dar NU IP-ul brut; identificatori persistenți pot fi reținuți până la 2 ani după ștergerea contului. | CONFIRMAT (sursă directă blocată 403, corroborat din index/cache) | Aceleași date confirmate, inclusiv formularea "we do not share your IP address with the creators" și reținerea de identificatori persistenți "up to two years after account deletion" pentru prevenire fraudă/securitate. Fetch direct pe en.help.roblox.com a picat cu 403 și în această sesiune de verificare, la fel ca la scrierea notei. | https://en.help.roblox.com/hc/en-us/articles/115004630823-Roblox-Privacy-and-Cookie-Policy (403 direct; conținut corroborat via cache/index căutare) — accesat 2026-09-09 |
| Reprezentanți GDPR: DP-Dock GmbH (Hamburg, EU), DPO DP Dock DPO Services GmbH (Kiel, roblox@dp-officer.com). | CONFIRMAT | Confirmat, inclusiv adresa: "Ballindamm 39 / Ecke Jungfernstieg, 20095 Hamburg" pentru reprezentantul EU și "Grüffkamp 10, 24159 Kiel" pentru DPO. Reprezentantul UK ("DP Data Protection Services UK Ltd", Londra) nu a putut fi re-confirmat separat în această sesiune — sursele găsite menționează un contact unificat EEA/UK/Elveția (roblox@gdpr-rep.com); NEVERIFICABIL punctual pentru entitatea UK separată. | https://www.dp-dock.com/en/european-gdpr-representative + căutare index en.help.roblox.com — accesat 2026-09-09 |
| Scoped User Identifiers testate din iun. 2026 (thread devforum 2026-06-10). | CONFIRMAT | Confirmat: "Roblox launched an early preview and rollout timeline for Scoped User IDs on June 10, 2026." | https://devforum.roblox.com/t/update-on-safety-privacy-introducing-scoped-user-identifiers/4677155 — accesat 2026-09-09 |

**Notă:** data curentă la momentul verificării independente este 2026-09-09 (nu 2026-09-08 ca în nota originală) — decalajul de o zi nu afectează niciun verdict de mai sus.
