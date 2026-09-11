# Progres comun si obligatie sociala — cercetare pentru Driftwood

## Rezumat executiv

- **"Tot serverul" e o problema tehnica, nu doar de design.** Pe Roblox, un "server" e o instanta efemera creata cand se aduna jucatori si distrusa cand raman 0 — nu exista un server persistent unic ca la un MMO clasic. Daca Driftwood vrea literalmente UN oras global, are nevoie de `DataStoreService` + `MessagingService` pentru sincronizare cross-server; daca accepta orase separate per-instanta (varianta standard folosita de aproape toate jocurile mari de pe Roblox), atelierul se reseteaza conceptual la fiecare instanta noua.
- **Recomandare tehnica centrala**: foloseste `TeleportService:ReserveServerAsync()` + `TeleportService:TeleportToPrivateServer()` cu access code-ul salvat in DataStore, ca sa poti avea un numar fix de "orase" persistente (ex. 200) in loc de matchmaking public aleator — asta pastreaza legibilitatea contributiei ("cine a donat") care e motorul obligatiei sociale.
- **Stardew Valley Community Center**: 6 camere, 30 de bundle-uri, fiecare camera deblocheaza ceva permanent si diferit (pod, sera, minecart-uri, etc.) — nu un singur meniu de recompense generic. Modelul de "afiseaza 8-12 obiecte, cere doar 4-6" (Artisan Bundle) rezolva problema drop-ului aleator.
- **Animal Crossing (New Leaf)**: donatiile vin de la MAI MULTI vizitatori (nu doar proprietarul orasului), plus un trickle automat de la NPC-uri ("satenii doneaza sume mici zilnic") — un tampon anti-stagnare pentru cand jucatorii lipsesc.
- **FFXIV Ishgardian Restoration**: progresul e per-server (per "World"), nu global pe tot jocul — validare directa pentru arhitectura recomandata la Driftwood. Contributorii de top au primit titluri/achievement-uri unice si un monument vizibil permanent.
- **Sky: Children of the Light** nu are un mecanism de tip "bundle" — are totaluri agregate vizibile din donatii individuale (bani reali → copaci plantati, $ donati), utile ca model de "counter comunitar" dar nu de "deblocare de zona".
- **Grow a Garden** (cel mai mare joc single-topic de pe Roblox in 2025, varf de 22,3M CCU) confirma ca "vizibilitatea celuilalt jucator pe acelasi server" e faisabila si populara, dar ramane strict per-instanta — nu exista un oras/gradina globala unica.
- **Riscul de freeloading e structural, nu doar comportamental**: daca orasul se blocheaza la orice populatie mica sau daca un nou-venit intra intr-un oras deja complet deblocat, motorul de obligatie sociala moare — solutia testata de toate exemplele e "contributor recunoscut vizibil" + reward pentru toata lumea, nu doar pentru donator.
- **Reset-ul progresului comunitar e aproape universal EVITAT** in exemplele studiate (Stardew, Animal Crossing, FFXIV) — progresul e permanent; ceea ce se reinnoieste sunt straturile secundare (bundle-uri remixate, evenimente sezoniere), nu fundatia.

## Fapte verificate

- Comunity Center din Stardew Valley are **6 camere si 30 de bundle-uri** in total, plus un al 7-lea set ("Missing Bundle") in Joja Warehouse abandonat dupa completare; sursa: https://stardewvalleywiki.com/Bundles — pagina fara data explicita de update, accesata 2026-09-08; incredere: **ridicata**.
- Fiecare camera din Community Center deblocheaza altceva, permanent: Crafts Room → poarta spre Quarry, Pantry → Greenhouse (recolte tot anul), Fish Tank → elimina un bolovan + acvariu cosmetic, Boiler Room → Minecart-uri (fast travel intre 4 zone), Bulletin Board → +2 inimi de prietenie cu toti satenii nedatabili, Vault → 42.500g + reparatie Bus Stop spre desert; sursa: https://stardewvalleywiki.com/Bundles; incredere: **ridicata**.
- Bundle-urile pot afisa mai multe obiecte decat sloturi de completat (ex. "Artisan Bundle: 12 items, 6 slots to fill") — jucatorul alege ce doneaza din lista; sursa: https://stardewvalleywiki.com/Bundles; incredere: **ridicata**.
- In multiplayer Stardew, cutscene-ul de deschidere a Community Center-ului trebuie declansat de host, dar orice "farmhand" poate dona la bundle-uri dupa aceea; sursa: https://stardewvalleywiki.com/Community_Center; incredere: **ridicata**.
- Animal Crossing: New Leaf are **104 proiecte publice** posibile, din care doar 13 sunt disponibile din start, restul se deblocheaza prin sugestii de sateni sau conditii; maximum **30 de proiecte construite simultan**; demolarea costa 10% din costul de constructie; sursa: https://nookipedia.com/wiki/Public_works_project; incredere: **ridicata**.
- La proiectele publice din New Leaf, **satenii doneaza sume mici automat in fiecare zi**, iar donatiile mari vin de la jucator/vizitatori prin cutia lui Lloid; costurile variaza intre 12.800 si 498.000 Bells per proiect; sursa: https://nookipedia.com/wiki/Public_works_project; incredere: **ridicata**.
- FFXIV Ishgardian Restoration a rulat in **4 faze majore** (patch-urile 5.1–5.5), iar progresul a fost gestionat **independent per World (server)** — nu exista un stoc global unic; la finalul Fazei IV s-a ridicat un "Skybuilders' Monument" care arata ce clasa a contribuit cel mai mult pe fiecare World; sursa: https://ffxiv.consolegameswiki.com/wiki/Ishgardian_Restoration; incredere: **medie** (wiki secundar, dar coerent cu cunostinte generale despre FFXIV).
- Sky: Children of the Light a strans **40.576 de copaci plantati** (Days of Nature, 2020), **$719.138** donati catre Medecins Sans Frontieres (Days of Healing, 2020) si **$794.420** pentru The Trevor Project / Global Fund for Women (Days of Rainbow, 2021), toate ca totaluri agregate din achizitii individuale de bani reali; sursa: https://en.wikipedia.org/wiki/Sky:_Children_of_the_Light; incredere: **medie** (Wikipedia, cu citari catre presa/anunturi oficiale thatgamecompany).
- Adopt Me! (Uplift Games) a avut medii de **100.000–160.000 CCU** in septembrie 2022, un varf de **1,92 milioane CCU**, si **peste 40,8 miliarde de vizite** pana in noiembrie 2025; evenimentele promotionale (Scoob!, Sing 2, Minions) sunt structurate ca task-uri individuale, NU ca progres comunitar de tip bundle; sursa: https://en.wikipedia.org/wiki/Adopt_Me!; incredere: **medie**.
- Grow a Garden (lansat 26 martie 2025) a atins **22,3 milioane CCU** pe 23 august 2025, cel mai mare CCU inregistrat vreodata pentru un joc video la acel moment; gradinile jucatorilor sunt **"vizibile altor jucatori de pe acelasi server"**, iar obiecte exclusive saptamanale trebuie revendicate live (motor de retentie explicit); sursa: https://en.wikipedia.org/wiki/Grow_a_Garden; incredere: **ridicata**.
- Roblox a organizat evenimentul platform-wide **"The Hunt: Mega Edition"** in 2025, cu itemi limitati/serializati; a existat un bug raportat pe DevForum legat de bans automate ("ExploitDetected") reversate cu tricou de compensare; sursa: fire de discutie DevForum (cautare full-text, martie 2025), ex. https://devforum.roblox.com/t/the-hunt-mega-edition-2025-ban-wave-surf-champion-is-bugged-out-making-it-unable-to-wear-at-all/3561720; incredere: **medie** (confirmat prin cautare, nu am citit thread-ul integral).
- `MemoryStoreService` ofera "fast in-memory data storage accessible from all servers in a live session" — deci e singurul serviciu Roblox nativ cu stare **partajata in timp real intre instante de server diferite** ale aceluiasi joc; limite: quota memorie **64 KB + 1,2 KB per utilizator concurent**, quota API **1.000 + 120 per utilizator concurent (unitati/minut)**, max 1.000.000 iteme/structura, max 100 MB/structura, max 32 KB/item, TTL maxim **3.888.000 secunde (~45 zile)**; sursa: https://create.roblox.com/docs/cloud-services/memory-stores, accesat 2026-09-08; incredere: **ridicata** (citat direct din documentatie).
- `MessagingService` permite comunicare server-to-server prin `PublishAsync`/`SubscribeAsync`, functioneaza intre instante de server diferite ale aceluiasi joc, mesajele sunt limitate la **1 KB**; sursa: https://create.roblox.com/docs/reference/engine/classes/MessagingService, accesat 2026-09-08; incredere: **ridicata**.
- Anuntul oficial Roblox "Enhanced MessagingService Limits" (Roblox Creator Services Team, 12 februarie 2024) a crescut limitele: mesaje trimise per server game **de la 150+60×jucatori la 600+240×jucatori pe minut**; mesaje primite per topic **de la (10+20×servere) la (40+80×servere) pe minut**; mesaje primite pt tot jocul **de la (100+50×servere) la (400+200×servere) pe minut**; subscriptii per server **de la 5+2×jucatori la 20+8×jucatori**; subscribe requests **de la 60 la 240/min**; marimea mesajului a ramas **1 KB**; sursa: https://devforum.roblox.com/t/2835576 ("Enhanced MessagingService Limits"), 2024-02-12; incredere: **ridicata** (anunt oficial cu tabel exact), dar **flag: anterior pragului 2024 recomandat in brief — verifica in docs curente ca nu s-a schimbat din nou**.
- `TeleportService:ReserveServerAsync()` (metoda curenta; `ReserveServer` e **deprecated**) genereaza un access code ce poate fi salvat in DataStore si refolosit cu `TeleportToPrivateServer` pentru a teleporta jucatori inapoi in **aceeasi instanta persistenta de server**; sursa: https://create.roblox.com/docs/reference/engine/classes/TeleportService, accesat 2026-09-08; incredere: **ridicata**.
- Limitele de rate pentru DataStore (formule citate din pagina oficiala de limite): Read **300 + concurrentUsers×40**/min, Write **300 + concurrentUsers×20**/min, List **300 + concurrentUsers×2**/min pentru data stores standard/ordonate; valoare maxima per cheie **4.194.304 bytes (4 MB)**; lungime nume cheie/datastore/scope **max 50 caractere**; coada de request-uri **max 30 per tip**; debit per cheie **25 MB/min citire, 4 MB/min scriere**; sursa: https://create.roblox.com/docs/cloud-services/data-stores/error-codes-and-limits, accesat 2026-09-08; incredere: **medie** (extras printr-un instrument de fetch/sumarizare, nu citit direct din HTML brut — recomand verificare manuala inainte de a proiecta bugetul de call-uri).
- Bee Swarm Simulator (Onett) a participat la evenimente Roblox in 2024 si la Egg Hunt 2020; **NU am putut verifica** daca mecanica de Hive e partajata sau strict privata per jucator; sursa cautata: pagina Wikipedia dedicata nu exista, doar mentiuni in "List of Roblox games"; incredere: **NEVERIFICAT** pentru detaliile de Hive — tratat ca fapt din cunostinte generale, nu din sursa confirmata acum.
- Detaliile exacte despre "Guardian Games" din Destiny 2 (scoruri agregate pe clase, recompense) **NU au putut fi verificate** in aceasta sesiune (pagina Wikipedia dedicata a returnat 404, cautarile web nu au mai fost disponibile); marcat **NEVERIFICAT** — folosit doar ca referinta calitativa, nu cantitativa.

## Detalii

### 1. Stardew Valley — Community Center (referinta principala pentru "seturi + zona")

Structura verificata (stardewvalleywiki.com): jucatorul deblocheaza Community Center-ul printr-o cutscena (in multiplayer, doar host-ul o poate declansa), apoi citeste "Golden Scrolls" care cer bundle-uri de obiecte specifice. Exista **6 camere** (Crafts Room, Pantry, Fish Tank, Boiler Room, Bulletin Board, Vault) plus Bulletin Board reveleaza progresiv (Pantry apare dupa 1 bundle completat in Crafts Room; Fish Tank dupa 1; Boiler Room dupa 2; Bulletin Board dupa 3; Vault dupa 4) — deci exista un **gating secvential care creeaza un sentiment de progres continuu**, nu totul deschis din prima zi.

Fiecare bundle da o recompensa imediata la completare (item/unealta), iar completarea INTREGII camere da o recompensa mare, permanenta, vizibila in lume (nu doar in inventar): un pod reparat, o sera, minecart-uri etc. Aceasta separare — recompensa mica per bundle vs recompensa mare per camera — e exact tiparul pe care Driftwood il poate replica: donatie individuala = progres vizibil in bara camerei; camera completa = zona noua deschisa in lume, pentru toti.

Mecanismul anti-blocaj ("ce faci daca nu ai exact obiectul cerut"): bundle-urile suprasolicita optiuni — Artisan Bundle cere 6 din 12 posibile. Pentru Driftwood, unde obiectele vin aleator din rau, acest tipar e **critic**: seturile trebuie sa aiba intotdeauna mai multe optiuni valide decat sloturi cerute, altfel un singur obiect rar blocheaza tot orasul.

Alternativa Joja (plateste 5.000g, sari peste bundle-uri, cumperi upgrade-uri direct cu bani) e un exemplu de "pay-to-skip progresul comun" — Stardew il permite dar il face narativ negativ (JojaMart e antagonistul). Brief-ul Driftwood interzice explicit pay-to-win pe obiecte, deci acest tipar **nu** trebuie copiat 1:1 — dar varianta "plateste ca sa accelerezi TIMPUL de reparatie al obiectelor donate" (nu sa sari peste donatie) ar respecta regula anti-p2w.

### 2. Animal Crossing: New Leaf — Public Works Projects (referinta pentru contributie multi-jucator + trickle automat)

Verificat pe Nookipedia: **104 proiecte** posibile, 13 disponibile din start, restul deblocate prin sugestii de sateni (unele conditionate de personalitate) sau conditii speciale (ex. muzeul cere minim 50 de obiecte donate + 7 zile deschis pentru a debloca proiectul de renovare). Costurile variaza masiv: de la ~12.800 Bells pana la 498.000 Bells pentru statii/renovari mari.

Mecanismul de donatie: un NPC (Lloid) sta la locul viitorului proiect si accepta Bells de la **orice jucator, inclusiv vizitatori din alte orase** (nu doar proprietarul). In plus, **satenii doneaza automat sume mici in fiecare zi**, indiferent daca jucatorul e online — un tampon anti-stagnare direct relevant pentru Driftwood (raul aduce obiecte si offline, dar donatia la atelier ramane un act al jucatorului; New Leaf sugereaza un mic "trickle" pasiv suplimentar din partea NPC-urilor orasului, ca sa nu se opreasca complet progresul cand toata lumea lipseste).

Cap de constructii simultane: **maximum 30 de proiecte construite in acelasi timp** (exceptii: cafenea, sectie de politie, Main Street, renovari de gara/primarie). Aplicat la Driftwood: daca orasul are, sa zicem, 10-14 zone in plan, nu exista nevoie de acest cap — dar principiul "un singur proiect activ deodata" (New Leaf permite un singur proiect in constructie simultan) e util ca sa concentrezi atentia comunitatii pe UN obiectiv vizibil, nu pe 5 bare de progres in paralel care dilueaza obligatia sociala.

### 3. Final Fantasy XIV — Ishgardian Restoration (referinta pentru progres per-server + recunoastere de top-contributor)

Confirmat (consolegameswiki.com): jucatorii creaza obiecte ("Disciples of the Hand/Land") si le trimit catre reconstructia districtului Firmament. Progresul s-a desfasurat in **4 faze majore** (patch 5.1–5.5) si a fost **gestionat independent per World** — citat direct: *"The restoration effort was carried out independently on each World, and as such the stockpile was also managed separately."* Asta e validarea directa ca modelul "progres per instanta de server, nu global" e testat si functional la scara unui MMO major, nu doar o compromitere tehnica improvizata.

Elemente de vizibilitate a contributiei: jucatorii au fost **clasati dupa calitatea si cantitatea obiectelor trimise**; contributorii de top per clasa au primit titluri/achievement-uri acum imposibil de obtinut; la finalul Fazei IV s-a ridicat un **"Skybuilders' Monument"** care arata public ce clasa a contribuit cel mai mult pe World-ul respectiv. Nu exista plafon la cate obiecte poti trimite ("no cap on how many items a player can submit"), deci whales/hardcore players pot contribui nelimitat fara sa fure sansa altora — completarea nu e "primul ajuns castiga", ci "orice depui conteaza pentru scor".

### 4. Sky: Children of the Light — totaluri agregate, nu deblocari de zona

Sky NU are o mecanica de tip "bundle → zona noua" in gameplay-ul de baza. Progresia individuala (candles/wax → cape level) e strict personala. Ce e relevant pentru Driftwood e modelul de eveniment caritabil: fiecare achizitie individuala (bani reali) se aduna intr-un total public — thatgamecompany a anuntat rezultate concrete: **40.576 copaci plantati** (Days of Nature 2020), **$719.138** donati (Days of Healing 2020), **$794.420** stransi (Days of Rainbow 2021). Acesta e un tipar de "counter comunitar vizibil, alimentat de actiuni individuale, fara prag de deblocare" — util pentru un widget secundar la Driftwood (ex. "raul a adus X obiecte in total pe server luna asta"), dar nu inlocuieste mecanismul de deblocare pe seturi.

Un alt detaliu transferabil: monedele sezoniere din Sky **se convertesc automat in moneda normala la finalul sezonului** — nimic nu se pierde, doar isi schimba forma. Recomandat pentru Driftwood daca introduceti bundle-uri sezoniere: materialele nefolosite la finalul sezonului ar trebui sa se converteasca, nu sa dispara.

### 5. Exemple Roblox — ce se poate replica direct

- **Adopt Me!** (verificat via Wikipedia): evenimentele promotionale (Scoob!, Sing 2, Minions) sunt structurate ca sarcini INDIVIDUALE cu recompensa individuala, nu ca progres comunitar partajat. Adopt Me! NU pare sa foloseasca un mecanism de tip "bundle comunitar" — e mai degraba dovada ca succesul masiv (100k-160k CCU medie, 1,92M varf, 40,8 miliarde vizite pana in noiembrie 2025) e posibil si FARA progres comun; obligatia sociala la Adopt Me! vine din trading intre jucatori, nu din constructie comuna.
- **Grow a Garden** (verificat via Wikipedia): gradinile individuale sunt vizibile celorlalti jucatori de pe acelasi server — presiune sociala prin **comparatie**, nu prin contributie la un obiectiv comun. Modelul de "itemi exclusivi saptamanali care trebuie revendicati live" e motorul de retentie explicit mentionat de sursa — foarte aproape de "sezoanele" din brief-ul Driftwood.
- **"The Hunt: Mega Edition"** (Roblox, 2025): eveniment platform-wide cu itemi limitati/serializati, gazduit in mai multe jocuri simultan — confirmat prin fire de discutie DevForum despre bug-uri (ban wave revocat cu compensatie, itemi netradeabili din greseala). Relevant ca precedent pentru "eveniment cu resurse limitate in timp, cu recompense vizibile/colectionabile" — dar e un eveniment PLATFORM-wide (Roblox insusi), nu un tipar per-joc de progres comunitar; nu e direct copiabil pentru atelierul din Driftwood.
- **Bee Swarm Simulator, Islands**: nu am putut verifica in aceasta sesiune mecanica exacta de progres comun (surse blocate/indisponibile) — **NEVERIFICAT**, nu construi pe ele fara research suplimentar direct in joc (recomand testare manuala in Studio/joc, vezi "Intrebari deschise").

### 6. Arhitectura tehnica Roblox pentru "progres comun" — partea cea mai importanta pentru Driftwood

Aceasta e diferenta fata de Stardew/Animal Crossing/FFXIV: acolo, "serverul" persista (fie ca farm save, fie ca World de MMO cu backend centralizat). Pe Roblox, o instanta de server e creata la cerere si moare cand se goleste — nu exista, implicit, "orasul" ca entitate persistenta separata de un DataStore key.

Trei servicii oficiale relevante, toate verificate din documentatia curenta:

| Serviciu | Ce face | Partajat intre instante de server? | Persistent? |
|---|---|---|---|
| `DataStoreService` / `OrderedDataStore` | Stocare cheie-valoare durabila | Nu direct (fiecare server citeste/scrie aceleasi chei, dar nu exista push in timp real) | Da |
| `MemoryStoreService` | Stocare rapida in memorie, cu TTL | **Da** — "accessible from all servers in a live session" | Nu (expira, max TTL ~45 zile) |
| `MessagingService` | Pub/sub server-to-server (`PublishAsync`/`SubscribeAsync`) | **Da** — mesaje livrate catre toate instantele abonate | Nu (doar mesaj instant, 1 KB max) |

Pattern recomandat pentru "un set se completeaza → zona se deschide pentru toata lumea, instant, in toate instantele":

```lua
-- Server care primeste donatia (ServerScriptService)
local DataStoreService = game:GetService("DataStoreService")
local MessagingService = game:GetService("MessagingService")

local cityStore = DataStoreService:GetDataStore("DriftwoodCity_" .. CITY_ID)

local function donateItem(player, setId, itemId)
    -- validare server-side a obiectului reparat detinut de player, apoi:
    local newCount, unlocked = cityStore:UpdateAsync("Set_" .. setId, function(old)
        old = old or { count = 0, donors = {} }
        old.count += 1
        old.donors[tostring(player.UserId)] = (old.donors[tostring(player.UserId)] or 0) + 1
        return old
    end)

    if newCount and newCount.count >= REQUIRED_FOR_SET[setId] then
        -- anunta TOATE instantele active ale acestui oras ca zona s-a deschis
        MessagingService:PublishAsync("CityUnlock_" .. CITY_ID, { setId = setId })
    end
end
```

```lua
-- In fiecare instanta de server, la pornire: abonare la evenimentul de deblocare
local MessagingService = game:GetService("MessagingService")

MessagingService:SubscribeAsync("CityUnlock_" .. CITY_ID, function(message)
    local setId = message.Data.setId
    unlockZoneLocally(setId) -- deschide poarta/zona in Workspace-ul acestei instante
end)
```

Pentru orase PERSISTENTE (nu instante publice aleatorii), pattern-ul verificat e:

```lua
-- La creare oras nou (o singura data)
local TeleportService = game:GetService("TeleportService")
local accessCode = TeleportService:ReserveServerAsync(game.PlaceId)
cityStore:SetAsync("AccessCode_" .. CITY_ID, accessCode)

-- Cand un jucator vrea sa intre in orasul lui persistent
local savedCode = cityStore:GetAsync("AccessCode_" .. CITY_ID)
TeleportService:TeleportToPrivateServer(game.PlaceId, savedCode, {player})
```

Buget de request-uri: conform paginii oficiale de limite (verificare recomandata inainte de implementare finala, vezi nota de incredere "medie" mai sus), rata de scriere pentru un data store standard e de ordinul **300 + 20×utilizatori concurenti pe minut** — pentru un oras cu 20-50 jucatori simultan, asta inseamna cateva sute-mii de scrieri/minut disponibile, suficient pentru donatii individuale, DAR o singura cheie ("Set_X") scrisa concurent de multi jucatori via `UpdateAsync` poate genera coliziuni/retry-uri sub sarcina mare — motiv sa NU pui toate donatiile pe o singura cheie daca te astepti la trafic mare simultan (ex. la un eveniment de tip Inundatie).

### 7. Vizibilitatea contributiei — plachete, nume, leaderboard

Toate exemplele verificate folosesc recunoastere **nominala**, nu doar procentuala:
- New Leaf: Isabelle "congratulate those who donated" la ceremonia de finalizare a unui proiect public.
- FFXIV: monument public cu numele/clasa celui mai bun contributor per World.
- Stardew: nu identifica donatorul individual per bundle (progresul e al fermei/gospodariei, nu al persoanei) — dar in multiplayer, farmhand-ul care declanseaza fiecare bundle vede reactia Junimo-ilor direct.

Pentru Driftwood, `OrderedDataStore:GetSortedAsync()` (confirmat in documentatie: metoda pentru clasamente/leaderboard-uri) e API-ul corect pentru un panou "Top contribuitori saptamana asta" per oras — dar tine cont ca `OrderedDataStore` stocheaza doar o valoare numerica per cheie (scor), nu structuri complexe; numele + avatarul jucatorului trebuie preluate separat (`Players:GetNameFromUserIdAsync` sau cache local).

### 8. Freeloader si nou-venit — problema nerezolvata explicit in sursele gasite

Niciuna dintre sursele verificate NU rezolva perfect "ce vede un jucator nou intr-un oras deja complet deblocat" — in Stardew, jucatorul NOU e mereu acelasi cu cel care a construit orasul (joc single-player sau co-op de la inceput), deci problema nu exista structural. In New Leaf, orasul e al unui singur mayor; vizitatorii doar doneaza, nu "intra" intr-un oras finalizat ca resedinta. FFXIV rezolva partial: Ishgardian Restoration a ramas activa "for rewards" dupa completare — jucatorii noi tot pot trimite obiecte si primesc alte recompense (Skybuilders' Scrips), chiar daca reconstructia in sine s-a incheiat narativ.

**Concluzie pentru Driftwood**: acesta ramane un risc real de design, nu doar tehnic — vezi sectiunea Riscuri.

## Recomandari concrete pentru Driftwood

1. **Alege explicit modelul de "oras"**: recomand orase persistente de dimensiune fixa (ex. 20-40 jucatori "membri" per oras, similar unui server Discord de comunitate), via `TeleportService:ReserveServerAsync()` + cod salvat in DataStore, NU matchmaking public aleator. Rationament: fara asta, un jucator care revine peste 3 zile poate ajunge intr-o instanta complet diferita, cu un "oras" pe care nu-l recunoaste — obligatia sociala ("daca lipsesti, cartierul stagneaza si oamenii observa", cf. brief) devine imposibila daca "oamenii" se schimba la fiecare sesiune.
2. **10-14 zone in planul de lansare**, nu mai mult — mai putine decat cele 200+ obiecte din indexul de reparatii (brief), pentru ca zonele sunt evenimente rare/majore, nu bife dese. Fiecare zona = 1 set de 5-8 obiecte reparate, cu **8-12 obiecte eligibile afisate** per set (Stardew: model Artisan Bundle) ca sa nu blocheze progresul din cauza dropului aleator din rau.
3. **Gating secvential, nu paralel**: dupa modelul Stardew (Pantry apare doar dupa 1 bundle din Crafts Room), afiseaza maximum 1-2 seturi "active" simultan, restul "ascunse" pana la deblocare. Concentreaza atentia si conversatia comunitatii pe un singur obiectiv vizibil, exact ca principiul "un singur proiect in constructie" din New Leaf.
4. **Trickle automat anti-stagnare**: cand orasul are 0 donatii intr-o fereastra (ex. 48h reale), adauga automat un mic progres pasiv la setul activ (ex. 1 obiect random din partea "orasului insusi" / NPC generic) — echivalentul satenilor din New Leaf care doneaza sume mici zilnic. Nu inlocuieste jucatorii, doar previne blocajul total cand toata lumea lipseste temporar.
5. **Recompensa dubla, mereu**: recompensa mica + imediata pentru donatorul individual (XP, moneda, un cosmetic minor de tip "insigna de donator #N pentru acest set"), plus recompensa mare pentru TOATA lumea de pe server la completarea setului (zona noua). Fara recompensa individuala, apare freeloading pasiv (de ce sa donez daca oricum se deblocheaza pentru toti); fara recompensa colectiva, dispare obligatia sociala.
6. **Plachetă nominala vizibila in zona noua**: dupa deblocare, afiseaza in zona un panou fizic (Frame/ImageLabel in ScreenGui, aliniat cu stack-ul tehnic din brief) cu numele celor 3-5 contribuitori de top pentru acel set — mecanism confirmat de FFXIV (Skybuilders' Monument) si New Leaf (ceremonie cu nume). Foloseste `OrderedDataStore:GetSortedAsync()` per set pentru topul contribuitorilor.
7. **Anti-abuz prin validare, nu prin restrictie**: pentru ca economia e server-authoritative (cf. brief), un obiect "donat" trebuie sa fie deja reparat integral (nu materie prima brută) — asta elimina automat "donatiile de gunoi" (spam de obiecte ieftine nereparate), pentru ca reparatia consuma deja timp+resurse reale, deci fiecare donatie are un cost dovedit. Nu are sens sa limitezi CATE doneaza cineva (FFXIV: "no cap on submissions") — limitarea vine natural din capacitatea de reparatie (spatiul limitat din atelier, deja in brief).
8. **Nu reseta niciodata progresul de zona** odata deblocata — permanent, cf. tuturor exemplelor studiate (Stardew, New Leaf, FFXIV). Ce se poate "reseta"/reinnoi sunt straturile secundare: bundle-uri sezoniere suplimentare (cosmetice, decoratiuni de mal) dupa modelul Sky (moneda sezoniera se converteste, nu dispare) — util pentru sezoanele de 4 saptamani deja planificate in brief.
9. **Rezolva explicit problema nou-venitului**: cand un jucator se alatura unui oras deja avansat, arata-i un ecran/istoric ("acest oras a fost construit de comunitate in X saptamani, iata cine a contribuit cel mai mult") in loc sa-l lasi sa descopere pasiv un oras "gata facut" fara context — niciuna din sursele studiate nu rezolva perfect asta, deci e teren propriu de design pentru Driftwood (vezi Intrebari deschise).
10. **Foloseste `MessagingService` pentru anunt instant de deblocare** in toate instantele aceluiasi oras persistent (relevant doar daca alegi arhitectura "un oras = mai multe instante posibile", nu una singura reserved server) — mesaj sub 1 KB, deci trimite doar `{setId=X}`, nu tot state-ul.
11. **Nu pune toate donatiile pe o singura cheie DataStore** daca te astepti la trafic concurent mare (ex. in timpul evenimentului Inundatia din brief) — sharding pe 4-8 sub-chei per set, agregate periodic printr-un script server, evita coliziunile de `UpdateAsync` sub sarcina.

## Riscuri si necunoscute

- **Arhitectura "un oras per server" vs "oras global" nu e decisa in brief** — brief-ul zice "tot serverul imparte acelasi oras", ceea ce pe Roblox nu inseamna automat "toata lumea, mereu" (vezi Detalii #6). Aceasta ambiguitate trebuie rezolvata inainte de a implementa DataStore-ul de oras, altfel arhitectura se schimba radical dupa ce ai construit-o.
- **Nu exista date verificate despre timpi reali de completare a unui set** la populatii mici (10-20 jucatori activi) — toate exemplele studiate (Stardew, New Leaf) sunt single-player sau co-op mic, nu multiplayer masiv anonim; FFXIV are populatii de mii per World. Driftwood, cu orase de 20-40 jucatori, e undeva la mijloc, fara precedent direct verificat. Pacing-ul (cate obiecte pe zi ajung realist donate) trebuie masurat, nu presupus.
- **Freeloading la scara**: daca orasul are 40 de "membri" dar doar 5 activi saptamanal, restul de 35 primesc zona noua gratis. Niciun exemplu studiat nu rezolva asta cu o metrica clara (Stardew/New Leaf nu au conceptul de "membru pasiv al unui oras multiplayer mare"). Risc real de resentiment intre jucatorii activi si cei pasivi.
- **Abuz/griefing**: nu am gasit exemple verificate de griefing intentionat pe bundle-uri comunitare (ex. cineva care doneaza strategic ca sa ia toate creditele, sau blocheaza progresul refuzand sa doneze un obiect rar pe care il detine exclusiv). Cu 200+ obiecte in indexul Driftwood si obiecte care vin aleator din rau, probabilitatea ca UN jucator sa "monopolizeze" un obiect necesar e mica, dar merita testat.
- **Formulele exacte de rate-limit DataStore** citate mai sus vin dintr-un fetch sumarizat, nu dintr-o citire directa a HTML-ului paginii oficiale — recomand sa le confirmi manual in Studio cu `DataStoreService:GetRequestBudgetForRequestType()` inainte sa proiectezi bugetul final de call-uri pentru orase mari.
- **Bee Swarm Simulator si Islands** raman NEVERIFICATE ca precedente — nu construi pe presupuneri despre "hive-ul comun" fara sa te loghezi si sa testezi direct.

## Intrebari deschise

1. Driftwood are UN oras global (toti jucatorii, oricand) sau orase separate de dimensiune fixa (ex. 20-40 jucatori/oras, gen "server Discord")? Aceasta decizie schimba toata arhitectura tehnica (DataStore simplu vs DataStore+MessagingService+ReserveServerAsync).
2. Cate zone vrei la lansare — planul propus (10-14) e un punct de plecare, nu un numar validat; trebuie testat cu jucatori reali cf. "Ordinea de lucru" din brief (nu treci mai departe fara testare umana).
3. Ce se intampla cu un jucator care intra intr-un oras unde TOATE zonele sunt deja deblocate (dupa saptamani/luni)? Nicio sursa studiata nu rezolva clar acest caz — necesita design propriu (istoric vizibil? sezon nou cu zone suplimentare? oras nou dedicat noilor jucatori?).
4. Praguri exacte per set (cate obiecte, ce raritate) — trebuie calibrate empiric fata de rata reala de acumulare din rau + reparatie (care depinde de plasele/sloturile din atelier, alt sistem inca netestat).
5. Testeaza in Studio: comportamentul real al `UpdateAsync` sub scriere concurenta de la 20+ jucatori simultan pe aceeasi cheie de set — simuleaza cu NPC-uri script-ate inainte de lansare, ca sa vezi rata de retry/esec.
6. Verifica direct in dashboard-ul Creator Hub / documentatia curenta valorile exacte de rate-limit pentru DataStore inainte de a finaliza bugetul tehnic (vezi nota de incredere medie de mai sus).

## Surse

- OrderedDataStore — Roblox Creator Documentation. https://create.roblox.com/docs/reference/engine/classes/OrderedDataStore (accesat 2026-09-08, fara data explicita de ultima modificare pe pagina)
- Data Store error codes and limits — Roblox Creator Documentation. https://create.roblox.com/docs/cloud-services/data-stores/error-codes-and-limits (accesat 2026-09-08)
- Memory Stores — Roblox Creator Documentation. https://create.roblox.com/docs/cloud-services/memory-stores (accesat 2026-09-08)
- MemoryStoreService — Roblox Creator Documentation. https://create.roblox.com/docs/reference/engine/classes/MemoryStoreService (accesat 2026-09-08)
- MessagingService — Roblox Creator Documentation. https://create.roblox.com/docs/reference/engine/classes/MessagingService (accesat 2026-09-08)
- TeleportService — Roblox Creator Documentation. https://create.roblox.com/docs/reference/engine/classes/TeleportService (accesat 2026-09-08)
- Players (MaxPlayers) — Roblox Creator Documentation. https://create.roblox.com/docs/reference/engine/classes/Players (accesat 2026-09-08)
- "Enhanced MessagingService Limits", Roblox Creator Services Team — Roblox DevForum. https://devforum.roblox.com/t/2835576 (2024-02-12)
- "Max Player Count Increased (in Beta)" — Roblox DevForum. https://devforum.roblox.com/t/722045 (2020-08-13, POSIBIL INVECHIT — flag conform instructiunilor pentru surse pre-2024)
- Fire de discutie DevForum despre "The Hunt: Mega Edition" (bug-uri, ban wave) — Roblox DevForum, cautare full-text, ex. https://devforum.roblox.com/t/the-hunt-mega-edition-2025-ban-wave-surf-champion-is-bugged-out-making-it-unable-to-wear-at-all/3561720 (~martie 2025)
- Community Center — Stardew Valley Wiki. https://stardewvalleywiki.com/Community_Center (ultima editare pagina: 17 mai 2026, conform footer-ului paginii)
- Bundles — Stardew Valley Wiki. https://stardewvalleywiki.com/Bundles (accesat 2026-09-08)
- Public works project — Nookipedia (Animal Crossing wiki). https://nookipedia.com/wiki/Public_works_project (accesat 2026-09-08)
- Ishgardian Restoration — FFXIV Console Games Wiki. https://ffxiv.consolegameswiki.com/wiki/Ishgardian_Restoration (accesat 2026-09-08, secundar)
- "Sky: Children of the Light" — Wikipedia. https://en.wikipedia.org/wiki/Sky:_Children_of_the_Light (accesat 2026-09-08, secundar)
- "Adopt Me!" — Wikipedia. https://en.wikipedia.org/wiki/Adopt_Me! (accesat 2026-09-08, secundar)
- "Grow a Garden" — Wikipedia. https://en.wikipedia.org/wiki/Grow_a_Garden (accesat 2026-09-08, secundar)
- "List of Roblox games" (sectiunea Bee Swarm Simulator) — Wikipedia. https://en.wikipedia.org/wiki/Bee_Swarm_Simulator (redirect catre lista generala; accesat 2026-09-08, secundar, informatii limitate)
