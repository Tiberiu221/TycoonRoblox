# Designul colecției de 200 de obiecte (Indexul de reparații)

## Rezumat executiv

- Foloseste **6-7 niveluri de raritate ponderate** (nu uniforme), cu 65-90% din obiecte concentrate în primele 2-3 niveluri și sub 1% din masa totală de probabilitate în ultimele 2 niveluri — simularea proprie (secțiunea 2) arată că așa obții exact forma cerută: majoritatea colecției cade rapid, coada rămâne lungă.
- **Nu pune toată cadența pe probabilitatea de prindere din râu.** Driftwood are deja o a doua frână incorporată în design — spațiul limitat din atelier + timpul de reparație. Folosită corect, aceasta e mai importantă pentru ritm decât rata brută de drop, și evită senzația de "totul e RNG pur" (problema structurală a jocurilor de tip Fisch/Pet Sim la trafic mare de prindere).
- **Exclude obiectele ultra-rare din cerința de "100%"** afișată public — Fisch face exact asta ("Limited, Secret, and Divine Secret fish are not required for Bestiary completion"). Fără acest artificiu, 100% devine practic inaccesibil pentru un jucător F2P și generează frustrare, nu retenție.
- **Politica oficială Roblox "Paid Random Items"** (clarificată 26 mai 2026) obligă la afișarea procentuală a șanselor DOAR pentru obiecte aleatorii cumpărate cu Robux. Prinderea gratuită din râu e scutită. Decizia critică: dacă "Materiale rare" (Developer Product din brief) dă un rezultat aleator, intri sub politică; dacă dă o cantitate fixă, ieși complet din ea.
- **Endowed progress effect** are dovezi empirice mai solide decât Zeigarnik effect pentru acest caz de folosire — un studiu real de fidelizare a arătat 34% vs 19% rată de finalizare când clienții primeau progres "cadou" la start. Zeigarnik effect, în schimb, a eșuat să se replice într-o meta-analiză din 2025.
- **Recompense la praguri intermediare, nu doar la 100%** — modelul Muzeului din Stardew Valley (14 praguri între 5 și 95 obiecte donate) și al Fisch (70% → unealtă utilă, 100% → cosmetic) sunt ambele testate la scară mare și ambele evită "totul sau nimic".
- **Variantele procedurale ("shiny"/recolorări)** extind conținutul perceput fără cost de artă 1:1 — o recolorare durează mult mai puțin decât un sprite nou — dar trebuie tratate ca intrări opționale/bonus, nu obligatorii pentru 100%.
- **Afișarea socială a procentului de completare** se implementează tehnic simplu cu `OrderedDataStore` + `GetSortedAsync` — cost de request neglijabil, exact mecanismul cerut în CLAUDE.md ("procentul completat trebuie afișat mare și vizibil altor jucători").
- **Costul de artă pentru 200 de sprite-uri nu a putut fi verificat dintr-o sursă primară** — orice cifră din secțiunea de detalii e o ipotecă de lucru (NEVERIFICAT), de validat cu 5-10 comenzi reale înainte de bugetare.
- Limita DataStore de 4.194.304 bytes/cheie face ca stocarea unei colecții de 200+ intrări per jucător să fie non-problemă tehnică — nici măcar cu variante incluse.

## Fapte verificate

- DataStore: valoare maximă **4.194.304 bytes (4 MB) per cheie**; nume de cheie/DataStore/scope maxim **50 de caractere**. Sursă: https://create.roblox.com/docs/cloud-services/data-stores/error-codes-and-limits; accesat 2026-09-08; încredere: ridicată.
- Metadata DataStore: valoare maximă 250 caractere per câmp, total 300 caractere pe toate câmpurile. Sursă: idem; accesat 2026-09-08; încredere: ridicată.
- Formulele de request budget extrase din documentație (Standard: Read = 300 + concurrentUsers×40/min etc.; Ordered: identice) — extragerea automată a arătat cifre **identice** pentru Standard și Ordered DataStore, ceea ce contravine cunoștințelor mele anterioare despre platformă. Sursă: idem; accesat 2026-09-08; încredere: **medie** — de reverificat manual direct pe pagină înainte de a proiecta orice sistem cu volum mare de citiri/scrieri.
- Formula de stocare totală per experiență: "500 MB + 1 MB × lifetime user count". Sursă: idem; accesat 2026-09-08; încredere: medie (aceeași rezervă ca mai sus privind acuratețea extragerii automate).
- DevEx: rata standard **$0.0038/Robux câștigat** ("$114 USD for 30,000 Earned Robux"); rată mai mare **$0.0054/Robux** pentru anumite câștiguri de la useri SUA 18+; solduri de dinainte de 5 septembrie 2025 se convertesc la rata veche $0.0035/Robux; minim **30.000 Robux câștigați**; **o singură cerere finalizată pe lună calendaristică**. Sursă: https://create.roblox.com/docs/production/monetization/developer-exchange; accesat 2026-09-08; încredere: ridicată (confirmă exact cifrele din CLAUDE.md).
- Politica "Paid Random Items" definește categoriile acoperite: capsule (roți, ouă, cufere), enhancement (poțiuni/spell-uri cu durată/succes aleator), combination (sinteză pentru șanse mai bune), probability modifiers (luck boosts, **pity systems**, rate-up scrolls). Sursă: https://create.roblox.com/docs/production/monetization/paid-random-items; accesat 2026-09-08; încredere: ridicată.
- Cerință de disclosure: șansele numerice trebuie afișate pentru **toate** rezultatele posibile, însumând 100%, **vizibile înainte de cumpărare**; recompensele aleatorii **gratuite** (fără Robux) sunt **exceptate** de la obligația de disclosure. Sursă: idem; accesat 2026-09-08; încredere: ridicată.
- "If you bundle a random item into a paid pack or single transaction, this makes the entire bundle a Paid Random Item." Sursă: idem; accesat 2026-09-08; încredere: ridicată.
- Fiecare rezultat posibil trebuie să ofere un beneficiu — nu sunt permise rezultate de tip "nimic"/pierdere totală la un Paid Random Item. Sursă: idem; accesat 2026-09-08; încredere: ridicată.
- `PolicyService:GetPolicyInfoForPlayerAsync()` expune flag-urile `ArePaidRandomItemsRestricted` și `IsPaidItemTradingAllowed`; restricțiile se aplică explicit în **Australia, Belgia, Olanda, Regatul Unit, Brazilia**. Sursă: https://devforum.roblox.com/t/clarifying-requirements-for-paid-random-items/4654622 (anunț oficial Roblox, live 26 mai 2026); accesat 2026-09-08; încredere: ridicată.
- `OrderedDataStore:GetSortedAsync(ascending, pageSize, minValue, maxValue)` întoarce un `DataStorePages`, cu paginare via `AdvanceToNextPageAsync()` — modelul standard pentru clasamente. Sursă: https://create.roblox.com/docs/reference/engine/classes/OrderedDataStore; accesat 2026-09-08; încredere: ridicată.
- Zeigarnik effect: studiul original publicat în 1927 în *Psychologische Forschung*, bazat pe observația lui Kurt Lewin despre chelneri care rețin comenzile neplătite mai bine decât cele plătite; teoretizat via "tensiune specifică sarcinii" (field theory). Sursă: https://en.wikipedia.org/wiki/Zeigarnik_effect; accesat 2026-09-08; încredere: medie (via Wikipedia, nu studiul original).
- O meta-analiză din **2025** citată pe aceeași pagină "found no memory advantage for unfinished tasks"; o replicare anterioară (Van Bergen, 1968) a eșuat de asemenea să găsească diferențe semnificative. Sursă: idem; accesat 2026-09-08; încredere: ridicată (privind existența controversei/criticii).
- Endowed progress effect (Nunes & Drèze, 2006): 300 carduri de fidelitate la o spălătorie auto; grup "endowed" (10 ștampile necesare, 2 pre-completate) → **34% rată de răscumpărare**; grup de control (8 ștampile necesare, 0 pre-completate) → **19% rată de răscumpărare**; clienții "endowed" au avut și intervale mai scurte între spălări. Sursă: https://en.wikipedia.org/wiki/Goal_pursuit (revizie Wikipedia 17:53, 14 iulie 2026); accesat 2026-09-08; încredere: medie (citat via Wikipedia, nu articolul original din Journal of Consumer Research).
- Illusionary progress effect (Kivetz, Urminsky & Zheng, 2006) și goal-gradient hypothesis (Hull, 1932/1934) — motivația crește monoton pe măsură ce distanța percepută până la recompensă scade. Sursă: idem; accesat 2026-09-08; încredere: medie.
- Caz citat de Wikipedia (DevHub, 2010): rata de completare a task-urilor online a crescut de la 10% la 80% după adăugarea de elemente de gamification. Sursă: https://en.wikipedia.org/wiki/Gamification; accesat 2026-09-08; încredere: scăzută (sursă secundară, fără detalii metodologice, caz de marketing, nu studiu controlat).
- Muzeul din Stardew Valley: **95 de obiecte donabile** (din 102 sloturi fizice, 6 inaccesibile); praguri de recompensă la 5, 10, 15, 20, 25, 30, 35, 40, 50, 60, 70, 80, 90, 95 donații; 40 donații → Rarecrow #8 + achievement "Treasure Trove"; 95/95 → Stardrop + achievement "A Complete Collection". Sursă: https://stardewvalleywiki.com/Museum (fetch via proxy r.jina.ai, blocaj direct 403); accesat 2026-09-08; încredere: medie (wiki comunitară, nu sursă oficială ConcernedApe).
- Critterpedia (Animal Crossing: New Horizons): achievement-uri Nook Miles separate pentru insecte (10/20/40/60/toate → 300/500/1000/2000/3000 Nook Miles), identic pentru pești, și pentru creaturi marine (5/10/20/30/toate → aceleași praguri de miles); completarea insectelor și a peștilor deblochează rețete DIY pentru plasa de aur, respectiv undița de aur, trimise prin scrisoare de la muzeu; completarea creaturilor marine **nu are nicio recompensă**. Sursă: https://nookipedia.com/wiki/Critterpedia (fetch via proxy r.jina.ai); accesat 2026-09-08; încredere: medie (wiki comunitară, nu Nintendo oficial).
- Fisch — Bestiary: ~19 categorii de raritate declarate (Trash=30, Common=124, Uncommon=132, Unusual=111, Rare=130, Legendary=98, Mythical=100, Exotic=58, Secret=37, Relic=8, Fragment=8, Gemstone=8, Extinct=154, Seed=5, Limited=330, Apex=11, Nuclear=3, Special=113, Divine Secret=11); **"Limited, Secret, and Divine Secret fish are not required for Bestiary completion"** deși rămân obținibile prin trading; 70% completare → unealtă "Destiny Rod" (valoare 190.000 C$); 100% (din subsetul cerut) → "Aurora Bobber". Sursă: fisch.fandom.com/wiki/Rarity (accesat via proxy r.jina.ai; sursă secundară, wiki comunitară neoficială — fischipedia.org oficial a fost blocat de Cloudflare la toate încercările de fetch); accesat 2026-09-08; încredere: medie.
- Pet Simulator 99 se auto-descrie ca având "more than 2,000 collectible pets", cu categorii regular/shiny/gold/rainbow/Huge/Titanic/exclusive; există un wiki oficial de referință al dezvoltatorului (BIG Games) la db.biggames.io/wiki, separat de wiki-ul comunitar Fandom, dar pagina de start nu conține cifre granulare despre Index/rarități. Sursă: https://petsimulator99.wiki/ (secundară) + https://db.biggames.io/wiki (oficial, confirmă doar existența, nu cifrele); accesat 2026-09-08; încredere: scăzută pentru cifra "2000+", ridicată pentru existența wiki-ului oficial.

## Detalii

### 1. Psihologia colecției: ce e solid și ce nu

**Zeigarnik effect** (sarcini neterminate rețin atenția mai bine decât cele terminate) e citat aproape universal în literatura de game design pop ca justificare pentru bare de progres și colecții incomplete. Problema: dovada empirică modernă e slabă. O meta-analiză din 2025 nu a găsit avantaj de memorie pentru sarcini neterminate, iar o replicare din 1968 a eșuat similar. Asta nu înseamnă că bara de progres nu funcționează — înseamnă că mecanismul citat frecvent ("creierul nu suportă incompletitudinea") nu are fundamentul științific pe care i-l atribuie majoritatea articolelor de game design. Recomandarea practică: nu construi argumentația de design pe Zeigarnik ca "lege psihologică dovedită".

**Endowed progress effect** (Nunes & Drèze, 2006) are dovadă empirică mult mai directă și relevantă pentru mecanica de colecție: un studiu real de fidelizare (nu de laborator) a arătat diferență de 15 puncte procentuale în rata de finalizare (34% vs 19%) doar prin a oferi progres inițial "cadou", fără să schimbe efortul real necesar. Aplicație directă la Driftwood: dă jucătorului nou 5-10 intrări în Index deja "descoperite" prin tutorial (nu prin RNG), astfel încât la finalul primei sesiuni bara arate deja 3-5%, nu 0%.

**Goal-gradient hypothesis** (Hull, 1932/1934) și **illusionary progress effect** (Kivetz, Urminsky & Zheng, 2006) susțin ambele ideea că motivația crește pe măsură ce ținta pare mai aproape — motiv suplimentar pentru praguri de recompensă dese la începutul colecției (unde progresul e rapid oricum) și mai rare, dar mai mari, spre final.

**Gamification generic** (badge-uri, bare de progres, monedă virtuală) are studii de caz favorabile în literatura de business (ex. DevHub, 10%→80% completare task-uri), dar sursele sunt secundare și necontrolate metodologic — de tratat ca semnal, nu ca dovadă.

### 2. Matematica ratelor de drop

Pentru colectarea a *n* obiecte cu probabilitate **uniformă** per încercare, problema colecționarului de cupoane dă un timp așteptat de `n × H(n)` încercări, unde `H(n)` e numărul armonic (`H(n) ≈ ln(n) + 0,5772`). Pentru n=200, `H(200) ≈ 5,878`, deci ~1176 încercări dacă toate cele 200 de obiecte ar avea aceeași șansă — ceea ce nu vrem, pentru că ar face colecția fie prea rapidă (dacă e ușor de prins), fie complet lipsită de progresie perceptibilă (toate obiectele la fel de "rare").

**De aceea se ponderează pe niveluri.** Tabelul propus mai jos (recalculat via simulare proprie, nu dintr-o sursă externă — e matematică standard, nu un fapt de verificat) distribuie cele 200 de obiecte pe 7 niveluri, cu pondere de probabilitate în scădere geometrică aproximativă per nivel:

| Nivel | Nr. obiecte | Pondere din probabilitatea totală | Prob./obiect per prindere | Prinderi așteptate pt. 1 obiect din nivel |
|---|---:|---:|---:|---:|
| Comun | 65 | 55% | 0,846% | ~118 |
| Neobișnuit | 48 | 28% | 0,583% | ~171 |
| Rar | 38 | 12% | 0,316% | ~317 |
| Epic | 27 | 4,5% | 0,167% | ~600 |
| Legendar | 15 | 0,47% | 0,0313% | ~3.192 |
| Mitic | 6 | 0,03% | 0,005% | ~20.000 |
| Secret | 1 | 0,003% | 0,003% | ~33.333 |
| **Total** | **200** | **100%** | — | — |

"Prindere" = un obiect brut interceptat de plasă din râu, înainte de reparație (nu neapărat un obiect adăugat efectiv în Index — vezi secțiunea 8 pentru gate-ul suplimentar).

**Simulare Monte Carlo** (script propriu, 300-400 rulări per scenariu, prezentată aici ca metodologie transparentă, nu ca fapt extern verificat) pe tabelul de mai sus, presupunând un debit ipotetic de **T prinderi/zi** per jucător (plasă activă + acumulare offline plafonată la 8h — **cifră necunoscută încă, de măsurat în Studio**):

| Zi | % colecție descoperită (T=150/zi) | % colecție descoperită (T=220/zi) |
|---:|---:|---:|
| 7 | 90,9% | 92,1% |
| 15 | 93,1% | 94,3% |
| 30 | 95,4% | 96,5% |
| 60 | 97,3% | 98,0% |
| 90 | 98,1% | 98,6% |
| 180 | 99,0% | 99,4% |
| 365 | 99,7% | 99,9% |

Completare 100% (mediana din simulare): **~345 zile la T=150/zi**, **~259 zile la T=220/zi** (percentila 90 se întinde până la 617-453 zile). Adică: **bulk-ul colecției (peste 90%) cade în prima-a doua săptămână**, dar **ultimele câteva obiecte (Mitic + Secret) se întind pe 8-12+ luni** — exact forma "coadă lungă" cerută, doar că pragul concret nu e "60% în luna 1" ci mai degrabă "~90-95% în luna 1, ultimele procente pe termen de multe luni". Dacă se dorește o curbă mai lentă la mijloc (nu doar rush inițial + coadă lungă), soluția e să se reducă T real (nu doar ponderile), ceea ce trimite direct la secțiunea 8 (gate-ul de reparație).

**Important**: acest calcul modelează doar *prima prindere* a fiecărui obiect, nu adăugarea lui efectivă în Index — dacă Index-ul cere reparație completă (cum specifică arhitectura Driftwood), curba reală va fi semnificativ mai lentă decât cea de mai sus.

### 3. Studii de caz comparate

| Joc | Nr. intrări (aprox.) | Niveluri de raritate | Prag intermediar | Recompensă la 100% | Excluderi de la 100% |
|---|---:|---|---|---|---|
| Fisch | ~1.400+ (19 categorii) | 19 | 70% → Destiny Rod | Aurora Bobber | Limited, Secret, Divine Secret |
| Pet Simulator 99 | 2.000+ | regular/shiny/gold/rainbow/Huge/Titanic/exclusive | NEVERIFICAT (n-am găsit cifre granulare) | NEVERIFICAT | NEVERIFICAT |
| Stardew Valley (Muzeu) | 95 | fără niveluri explicite (artefacte/minerale) | 14 praguri (5→95) | Stardrop + achievement | 7 sloturi fizice inaccesibile |
| Animal Crossing: New Horizons (Critterpedia) | insecte+pești+creaturi marine (total NEVERIFICAT exact) | fără niveluri de raritate — organizat pe categorii de specii | 5 praguri per categorie (Nook Miles) | Plasă de aur / undiță de aur (nu și pt. creaturi marine) | — |

Observație transversală: **niciunul dintre aceste jocuri nu cere 100% literal pe absolut toate intrările** pentru recompensa finală vizibilă — fie exclud explicit un subset (Fisch), fie nu leagă deloc anumite categorii de recompense (Animal Crossing, creaturi marine), fie muzeul fizic are locuri inaccesibile prin design (Stardew). Tiparul se repetă suficient de consistent încât să fie tratat ca regulă de design, nu coincidență.

### 4. Conținutul per intrare + schema Luau

Fiecare intrare din Index are nevoie minim de: nume, lore scurt, raritate, sezon (opțional), materiale de reparație, sprite. Propunere de schemă, respectând regulile de arhitectură din brief (definiții statice partajate client/server, stare per-jucător minimală în DataStore, server autoritar):

```lua
-- ReplicatedStorage/Shared/IndexItemDefinitions.lua
-- Definitii STATICE, identice pe server si client. Nu contin nimic sensibil
-- (lore/nume/sprite sunt publice oricum), deci replicarea completa e ok.

export type Rarity =
	"Comun" | "Neobisnuit" | "Rar" | "Epic" | "Legendar" | "Mitic" | "Secret"

export type RepairMaterial = {
	MaterialId: string,
	Count: number,
}

export type IndexItemDef = {
	Id: string,                      -- unic, stabil, niciodata refolosit ("net_bottle_glass_01")
	DisplayName: string,             -- RO, afisat in UI
	Lore: string,                    -- 1-2 propozitii, deblocat vizual doar dupa prima prindere
	Rarity: Rarity,
	Season: string?,                 -- nil = tot anul; altfel "Vara" | "Iarna" | "Primavara" | "Toamna"
	SpriteId: string,                -- rbxassetid://...
	BaseCatchWeight: number,         -- pondere relativa in tabelul de raritate (sectiunea 2)
	RepairMaterials: {RepairMaterial},
	RepairTimeSeconds: number,       -- timp real, continua offline (al doilea gate de ritm)
	RequiredForCompletion: boolean,  -- false pt. nivelul Secret / editii limitate sezoniere
	VariantOf: string?,              -- daca e varianta proceduala ("shiny"), Id-ul obiectului de baza
	VariantWeight: number?,          -- pondere suplimentara a variantei fata de baza (mult mai mica)
}

return {} :: {[string]: IndexItemDef}
```

```lua
-- ServerScriptService/PlayerIndexSave.lua
-- Stare per-jucator, MINIMALA. Nu duplica definitiile statice aici.

export type PlayerIndexEntry = {
	FirstCaughtAt: number,  -- os.time(), pt. "data descoperirii" in UI
	IsVariant: boolean,
}

export type PlayerIndexSave = {
	Entries: {[string]: PlayerIndexEntry}, -- cheie = IndexItemDef.Id
	SchemaVersion: number,                 -- pt. migrari viitoare
}

return {}
```

Selecția ponderată la prindere (server-side, autoritar — clientul nu decide niciodată rezultatul):

```lua
-- ServerScriptService/RiverLoot.lua
local function pickWeightedItem(
	sortedIds: {string},
	cumulativeWeights: {number},
	totalWeight: number
): string
	local r = math.random() * totalWeight
	local lo, hi = 1, #cumulativeWeights
	while lo < hi do
		local mid = (lo + hi) // 2
		if cumulativeWeights[mid] < r then
			lo = mid + 1
		else
			hi = mid
		end
	end
	return sortedIds[lo]
end
```

Scriere clasament public de completare (folosind `OrderedDataStore`, valoare = procent × 10.000 rotunjit, pentru precizie fără zecimale):

```lua
local DataStoreService = game:GetService("DataStoreService")
local completionBoard = DataStoreService:GetOrderedDataStore("IndexCompletionPct")

local function updateCompletionBoard(userId: number, completionPercent: number)
	local scaled = math.floor(completionPercent * 10000 + 0.5) -- 0-1.000.000
	local ok, err = pcall(function()
		completionBoard:SetAsync(tostring(userId), scaled)
	end)
	if not ok then
		warn("[IndexBoard] update esuata:", err)
	end
end

local function getTopCompletions(count: number)
	local pages = completionBoard:GetSortedAsync(false, count)
	return pages:GetCurrentPage()
end
```

### 5. Recompense la praguri

Model recomandat, combinând Stardew (praguri dese, mici) cu Fisch (prag mare la 70%, cosmetic final):

| Prag | Tip recompensă | Rationament |
|---|---|---|
| 10% | Material comun bonus | Confirmă bucla încă din prima sesiune (endowed progress) |
| 25% | Slot temporar extra în atelier (24h) | Recompensă utilitară legată direct de constrângerea centrală a jocului |
| 50% | Skin de plasă (cosmetic minor) | Prima recompensă pur decorativă — vizibilă permanent în 2D |
| 75% | Reducere % la timpul de reparație (permanentă, mică) | Accelerează coada lungă fără a fi pay-to-win |
| 90% | Decorațiune de mal unică | Semnal social vizibil altor jucători pe server |
| 100% (subset obligatoriu) | Cosmetic rar/animat, achievement afișat pe profil | Recompensa de trofeu — obiectele Secret rămân bonus, nu blocaj |

### 6. Afișarea socială a completării

CLAUDE.md cere explicit ca procentul completat să fie "mare și vizibil altor jucători" — tehnic, soluția e un `OrderedDataStore` separat (nu suprapus peste datele de joc reale), actualizat la fiecare prindere reparată cu succes, citit via `GetSortedAsync` pentru clasamentul de server. Costul de request e neglijabil (o scriere per progres, nu per prindere brută). Recomandare de UX: afișează procentul propriu mare, pe ecran, permanent (nu doar într-un meniu), plus un clasament "top completare pe server" accesibil dintr-un tab — replicând mecanismul de comparație socială pe care brief-ul îl cere explicit.

### 7. Costul de conținut și variantele procedurale

Nu am găsit o sursă primară sau oficială pentru costul per sprite de colecție — piața de comisioane pixel-art e extrem de variabilă (stil, rezoluție, număr de cadre de animație, experiența artistului) și nu există un preț de referință public verificabil. **Orice cifră de mai jos e o ipoteză de lucru (NEVERIFICAT), nu un fapt cercetat.**

Ce se poate spune cu încredere mai mare, din rațiune structurală, nu din sursă externă: o **recolorare/variantă procedurală** (paletă de culori diferită pe același sprite de bază) necesită vizibil mai puțin timp decât un sprite original nou, pentru că geometria și animația rămân identice. Asta face din variantele "shiny" (după modelul Golden/Rainbow din Pet Simulator 99) o pârghie ieftină de a extinde numărul perceput de intrări din Index dincolo de cele 200 de bază, fără a multiplica costul de artă proporțional.

Recomandare: tratează costul de artă ca necunoscută de validat direct (comandă 5-10 sprite-uri reale de la artistul/artiștii vizați, cronometrează sau cere ofertă explicită per bucată), nu ca parametru de bugetare presupus dintr-o sursă generică negăsită.

### 8. Al doilea gate: reparația, nu doar RNG-ul

Simularea din secțiunea 2 arată o problemă structurală dacă tot ritmul de completare depinde doar de probabilitatea de prindere: la un debit de 150-220 prinderi/zi (o cifră deloc absurdă pentru un joc cu plase multiple + acumulare offline), **peste 90% din colecție cade în mai puțin de două săptămâni**, indiferent cât de agresiv se ponderează nivelurile rare — pentru că orice probabilitate nenulă, la volum mare de încercări, devine "curând" în termeni absoluti.

Driftwood are deja soluția în arhitectura proprie: **spațiul limitat din atelier + timpul de reparație scalat pe raritate**. Dacă Index-ul numără doar obiecte **reparate complet** (nu doar prinse), iar reparația unui obiect Legendar/Mitic durează, real-time, zile în loc de minute, ritmul efectiv de completare devine mult mai lent decât rata brută de prindere, fără să fie nevoie de probabilități absurd de mici la nivelurile rare (care oricum ar fi greu de comunicat jucătorului ca "fair"). Acest gate dublu — RNG la prindere + capacitate limitată la reparație — e și motivul pentru care CLAUDE.md insistă că spațiul de atelier, nu energia, e resursa de tensiune centrală a jocului: aceeași resursă rezolvă simultan constrângerea de gameplay și cadența colecției.

## Recomandari concrete pentru Driftwood

1. **Folosește 6-7 niveluri de raritate ponderate geometric** (tabelul din secțiunea 2 ca punct de plecare), cu 90%+ din masa de probabilitate în primele 3-4 niveluri. *Rationament*: dă ritm rapid de start (endowed progress, goal-gradient) fără să sacrifice coada lungă pentru nivelurile rare.

2. **Numără în Index doar obiectele reparate complet, nu doar prinse**, și scalează timpul de reparație pe raritate (minute pentru Comun, zile pentru Legendar/Mitic). *Rationament*: e a doua frână de ritm, deja compatibilă cu arhitectura existentă (spațiu limitat de atelier), și evită ca 90%+ din colecție să cadă în prima săptămână doar din volumul brut de prinderi.

3. **Exclude explicit nivelul Secret (și eventual Mitic) din cerința de "100% Index"** afișată public, după modelul Fisch. *Rationament*: fără acest artificiu, "100%" devine practic inaccesibil pentru un jucător F2P obișnuit și transformă un obiectiv motivant într-o sursă de frustrare cronică.

4. **Adaugă recompense la 5-6 praguri intermediare** (10/25/50/75/90/100%), nu doar la final. *Rationament*: modelul Stardew (14 praguri) și Fisch (70% + 100%) sunt ambele testate la scară mare; pragurile dese mențin motivația vizibilă pe tot parcursul, nu doar la capăt.

5. **Fă Developer Product-urile deterministe (cantitate fixă de materiale), nu aleatorii.** *Rationament*: evită complet obligațiile de disclosure/PolicyService din politica "Paid Random Items" — mai puțină complexitate de conformitate, fără compromis pe gameplay, pentru că aleatoritatea reală rămâne oricum la prinderea gratuită din râu (scutită de politică).

6. **Dacă totuși se dorește un Developer Product aleator ("Materiale rare" cu rezultat random)**, implementează de la început: afișare procentuală per rezultat însumând 100%, verificare `PolicyService:GetPolicyInfoForPlayerAsync().ArePaidRandomItemsRestricted` înainte de a oferi opțiunea, și o alternativă compliant (cale gratuită sau achiziție garantată) pentru userii restricționați (AU/BE/NL/UK/BR). *Rationament*: cerință legală directă, nu opțională.

7. **Tratează variantele procedurale ("shiny") ca intrări opționale, separate, cu probabilitate condiționată de deținerea obiectului de bază** (nu independente). *Rationament*: extind conținutul perceput fără cost de artă proporțional, dar nu trebuie să blocheze completarea de bază — modelul Pet Simulator 99 (regular/shiny/gold/rainbow ca straturi peste aceeași bază) e direct aplicabil.

8. **Implementează clasamentul public de completare cu un `OrderedDataStore` dedicat**, actualizat la fiecare reparație finalizată cu succes. *Rationament*: cerință explicită din brief ("procentul completat trebuie afișat mare și vizibil"), cost tehnic minim, pattern documentat oficial.

9. **Dă 5-10 intrări în Index gratuit prin tutorial/poveste** la prima sesiune, nu prin RNG. *Rationament*: replică direct mecanismul cu dovadă empirică cea mai solidă din research (endowed progress, +15pp rată de finalizare într-un studiu real), fără cost de gameplay.

10. **Nu bugeta costul de artă pentru cele 200 de sprite-uri pe baza unei cifre generice găsite online** — validează cu comenzi reale mici înainte. *Rationament*: n-am găsit nicio sursă primară verificabilă pentru preț per sprite; orice cifră ar fi inventată, ceea ce contravine cerinței de acuratețe a acestui research.

11. **Măsoară rata reală de "prinderi/zi" per jucător în Studio înainte de a bloca tabelul de probabilități final.** *Rationament*: întreaga simulare din secțiunea 2 depinde de o ipoteză (150-220/zi) care nu există încă în joc — tabelul propus e punct de plecare, nu produs final.

## Riscuri si necunoscute

- Formulele de request-budget DataStore extrase automat arată cifre identice pentru Standard și Ordered DataStore, ceea ce e suspect — de reverificat manual, direct pe pagina oficială, înainte de a proiecta orice sistem cu volum mare de citiri (ex. clasament global recalculat des).
- Numerele Fisch și Pet Simulator 99 provin din wiki-uri comunitare (surse secundare), nu din documentație oficială a acelor jocuri — jocurile live-service își schimbă loot table-urile frecvent, deci cifrele pot fi deja perimate la momentul citirii acestui document.
- Politica "Paid Random Items" e foarte recentă (clarificată 26 mai 2026) — există risc real de clarificări/modificări ulterioare înainte de lansarea Driftwood; de verificat din nou direct înainte de a implementa monetizarea finală.
- Dovezile științifice pentru Zeigarnik effect sunt slabe/contestate în literatura recentă (2025) — risc de a construi narativul de design pe un fundament psihologic supraestimat în cultura populară de game design, în loc să te bazezi pe endowed progress (dovadă mai solidă).
- Costul de artă per sprite e complet neverificat — orice buget calculat pe o presupunere generică riscă să fie greșit cu un factor de 2-5x.
- Nu există încă date reale despre debitul de prindere (catches/zi) în Driftwood — întreg modelul matematic din secțiunea 2 e speculativ până la playtesting real.
- Roblox extinde treptat cerințele de age-check/trust-and-safety (semnale găsite pentru chat, nu specific pentru mecanici de grind/colecție) — de monitorizat DevForum periodic pentru schimbări care ar putea afecta un design bazat pe sesiuni lungi și colecție extinsă.

## Intrebari deschise

- Care e rata reală de prinderi/zi per jucător (plasă activă + acumulare offline plafonată la 8h)? Trebuie măsurată în Studio, după pasul 1 din planul de lucru din CLAUDE.md.
- Câte sloturi de atelier are un jucător F2P la lansare, și cât durează real-time reparația unui obiect Legendar/Mitic? Decizia asta stabilește a doua frână de ritm și trebuie luată înainte de a bloca tabelul de raritate.
- "Materiale rare" (Developer Product) va fi determinist sau aleator? Alegerea declanșează sau evită complet obligațiile din politica Paid Random Items.
- Câte obiecte rămân explicit excluse din cerința de "100% Index" (după modelul Fisch)? Trebuie decis explicit, altfel default-ul e "toate 200 obligatorii", ceea ce contrazice recomandarea 3.
- Variantele procedurale ("shiny") sunt obligatorii pentru "100% Index" sau bonus opțional? Afectează atât UI-ul cât și presiunea reală de conținut resimțită de jucător.
- Se dorește un mecanism explicit de pity/garanție după X încercări fără succes la nivelurile Mitic/Secret? Politica Roblox permite explicit asta ca "probability modifier" — decizia de design rămâne la echipă.
- Care e costul real per sprite (timp și/sau bani) la artistul/artiștii vizați pentru Driftwood? De validat cu o comandă test înainte de a bugeta cele 200+ intrări.

## Surse

- https://create.roblox.com/docs/cloud-services/data-stores/error-codes-and-limits — "Data Store Limits" (Roblox Creator Docs) — accesat 2026-09-08
- https://create.roblox.com/docs/production/monetization/developer-exchange — "Developer Exchange (DevEx)" (Roblox Creator Docs) — accesat 2026-09-08
- https://create.roblox.com/docs/production/monetization/paid-random-items — "Paid Random Items" (Roblox Creator Docs) — accesat 2026-09-08
- https://create.roblox.com/docs/reference/engine/classes/OrderedDataStore — "OrderedDataStore" (Roblox Creator Docs) — accesat 2026-09-08
- https://devforum.roblox.com/t/clarifying-requirements-for-paid-random-items/4654622 — "Clarifying Requirements for Paid Random Items" (anunț oficial Roblox, live 26 mai 2026) — accesat 2026-09-08
- https://en.wikipedia.org/wiki/Zeigarnik_effect — "Zeigarnik effect" (Wikipedia) — accesat 2026-09-08
- https://en.wikipedia.org/wiki/Goal_pursuit — "Goal pursuit" (Wikipedia, revizie 14 iulie 2026) — accesat 2026-09-08
- https://en.wikipedia.org/wiki/Gamification — "Gamification" (Wikipedia) — accesat 2026-09-08
- https://stardewvalleywiki.com/Museum — "Museum" (Stardew Valley Wiki, comunitar) — accesat 2026-09-08 (via proxy, acces direct blocat 403)
- https://nookipedia.com/wiki/Critterpedia — "Critterpedia" (Nookipedia, comunitar) — accesat 2026-09-08 (via proxy)
- https://fisch.fandom.com/wiki/Rarity — "Rarity / Bestiary" (Fisch Wiki, Fandom, comunitar) — accesat 2026-09-08 (via proxy, acces direct blocat)
- https://petsimulator99.wiki/ — "Pet Simulator 99 Wiki" (agregator comunitar neoficial) — accesat 2026-09-08
- https://db.biggames.io/wiki — "Wiki — Pet Simulator 99 Game Systems & Reference" (BIG Games, wiki oficial al dezvoltatorului) — accesat 2026-09-08
- https://en.wikipedia.org/wiki/Animal_Crossing:_New_Horizons — "Animal Crossing: New Horizons" (Wikipedia, context general) — accesat 2026-09-08
