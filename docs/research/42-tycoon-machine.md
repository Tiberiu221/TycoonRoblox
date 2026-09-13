# Mecanica de tycoon: ce fac jocurile care au reușit, ce-i lipsește Driftycoon-ului

Owner-ul are dreptate: azi râul livrează pe cronometru, jucătorul calcă pad-uri într-o ordine fixă,
alergătorul cară — nicio mașină nu se construiește, nicio valoare nu se multiplică vizibil, aproape
nicio decizie. Citit înainte: §4.A/4.G/4.C/4.K, notele 20 și 38. Mai jos, cercetarea pe cele cinci
întrebări cerute.

## 1. Mașinăria clasică: dropper → conveyor → upgrader → collector

Genericul: dropper-ul toarnă bunul brut la interval fix, conveyorul îl mută, upgradere îi adaugă sau
multiplică valoarea în lanț, collector-ul îl transformă în bani — jucătorul cumpără mai mulți
dropperi, upgradere sau conveioare mai rapide (roblox.fandom.com/wiki/Tycoon; generalistprogrammer.
com, „How to Make a Roblox Tycoon Game 2026"; sinteză, 2026-09-12, medie).

**Miner's Haven** (berezaa; „cel mai mare sandbox tycoon de pe Roblox", minershaven.fandom.com,
sinteză, 2026-09-12, medie) leagă upgradere ca mașini cu conveior propriu sau piese atașate pe
lateral, care adaugă o sumă, un procent sau multiplică valoarea — unele aprind minereul sau îl fac
radioactiv. Terenul fiind limitat, jucătorii construiesc „upgrader loops": minereul trece de mai
multe ori prin același upgrader via teleportoare (/wiki/Upgrader_Loop, sinteză, 2026-09-12, medie) —
lanțul e limitat de cât de inteligent îl pliezi, nu de teren, exact ce „platforme fixe" (§4.B)
exclude la noi. Renașterea explică de ce se reconstruia de bunăvoie: la $25 cvintilioane baza și
inventarul se șterg (cu excepții „reborn-proof"), dar fiecare viață dă un obiect Reborn tot mai
puternic, tot mai rar (minershaven.fandom.com, revamped-miners-haven.fandom.com, sinteză,
2026-09-12, medie). La ei chiar se pierde — ce P2 interzice la noi; recompensa lor e un obiect nou
și tangibil, nu un procent. K păstrează deja Indexul și ce s-a plătit, corect — dar recompensa
rămâne 100% abstractă, fără echivalent al obiectului Reborn.

Restul genului confirmă „procesarea multiplică": la **Lumber Tycoon 2** bușteanul trecut prin gater
aduce ~8× mai mult decât vândut brut (lumber-tycoon-2.fandom.com, sinteză, 2026-09-12, medie) —
mecanismul pe care G îl are deja pe hârtie (gater ×3), încă invizibil. **Retail Tycoon 2** leagă
vânzarea de un rating pe 4+ factori (adăpost, decor, aglomerare, curățenie) și de vehicule ce aduc
marfa din depozit, unde plasarea rafturilor contează explicit (retail-tycoon.fandom.com,
deltiasgaming.com, sinteză, 2026-09-12, medie). **Theme Park Tycoon 2** obligă la coadă vizibilă la
fiecare atracție — cozile lungi scad satisfacția, remediul e evident: o atracție paralelă
(tpt2.fandom.com, sinteză, 2026-09-12, medie). **Restaurant Tycoon 2** (nota 38) împarte rating-ul
în reputație/mâncare/serviciu/design, fiecare cu propriul levier — patru pârghii, nu una
(restaurant-tycoon-2.fandom.com, sinteză, 2026-09-12, medie).

Cine câștigă cel mai mult în 2026 nu seamănă cu niciunul de mai sus: Rivals, Blox Fruits, Brookhaven,
Adopt Me, Pet Simulator 99, Steal a Brainrot, Fisch, Dress to Impress, Anime Defenders, Royal High —
niciun tycoon-mașină clasic în top 10, iar sursa declară explicit că sunt estimări, nu cifre Roblox
(rowatcher.com, 2026-09-12, scăzută-medie). **Steal a Brainrot** adaugă furt între jucători peste
formula dropper/conveyor (en.wikipedia.org/wiki/Steal_a_Brainrot, 2026-09-12, medie) — pierdere
reală, exact ce P2 interzice: de evitat, nu de imitat.

## 2. Pe ecran, nu în abstract

Diferența dintre un tycoon și un contor e reprezentarea concretă — clădiri, mașini, muncitori care
produc vizibil, nu doar o cifră care urcă (medium.com/tindalos-games, acces blocat HTTP 403, prin
motor de căutare, 2026-09-12, medie). Pe DevForum, un dezvoltator descrie exact simptomul nostru:
„waiting for your factory's storage to fill up can be incredibly boring" (devforum.roblox.com, fir
„a lot less repetitive and boring", accesat direct 2026-09-12, ridicată). Problema nu e acumularea,
ci acumularea nevăzută. Grow a Garden, deja cel mai important studiu de caz pentru noi (nota 20),
confirmă la scară maximă — bucla lui e vizibilă, nu abstractă, și a atins 22,3M CCU
(en.wikipedia.org/wiki/Grow_a_Garden, deja citat în nota 20). La noi bunurile de pe râu sunt „doar
decor" până la prindere, iar procesarea din G n-are încă nicio reprezentare vizuală — riscul e un
contor cu artă în jur, nu o mașinărie.

## 3. Deciziile care dau adâncime

Firul „Different approach to tycoons" ajunge la răspunsul pe care comunitatea îl dă constant:
modelele care rezistă (Miner's Haven, Lumber Tycoon 2) funcționează fiindcă jucătorul „maximize
profits" prin decizii „creative and smart" de amplasare, nu prin apăsat butoane într-o ordine dată;
propunerea din fir e un lanț cu ramificații reale — cărbune + fier → oțel, oțel + cauciuc → mașini
(devforum.roblox.com/t/different-approach-to-tycoons/533253, accesat direct 2026-09-12, medie).
Blocajul vizibil e al doilea ingredient recurent: la Theme Park Tycoon 2 coada lungă e diagnoza
jucătorului, nu un mesaj de sistem; un ghid generic descrie același tipar — o stație de 100
unități/minut care alimentează una de 50 „costă" 50 pe minut, vizibil ca stivă care crește (sinteză,
2026-09-12, medie). Acest tipar l-a găsit simulatorul nostru singur la energie (§5, defectul 6:
„Smelter II" scădea venitul) — dovadă independentă că mecanismul e real; la noi e rezolvat prin
formulă, invizibil pentru jucător.

## 4. Ce spun jucătorii

Răspunsul la „What do you want to see in a tycoon?" e aproape un diagnostic al jocului nostru: se
reclamă baze predeterminate unde „players just step on the pads" fără control creativ, progresie
unde „everything is decided for you", și se cere explicit „strategy and creativity"; Retail Tycoon,
Theme Park Tycoon, Lumber Tycoon sunt lăudate fiindcă „give a lot more to do and are a lot more
interesting" (devforum.roblox.com/t/what-do-you-want-to-see-in-a-tycoon/1048161, accesat direct
2026-09-12, medie). Aceiași jucători resping renașterile repetate ca substitut de conținut,
preferând „NO REBIRTHS, just more content" — relevant direct pentru K. Alt fir spune direct
„Tycoons are kinda boring actually", motivat tot de lipsa de decizie reală (devforum.roblox.com,
fir „a lot less repetitive and boring", 2026-09-12, ridicată).

## Ce lipsește la Driftycoon

Ordonate după adâncime per oră de lucru. Toate respectă P1–P6 și regula celor patru motive — nimic
de mai jos scade venitul, adaugă noroc sau pierdere.

1. **Lanțul de procesare, azi invizibil, devine vizibil.** G are gaterul (×3) pe hârtie, dar nimic
   arată bușteanul devenind scândură. Bunul prins ar călători vizual plasă → gater → jgheab (G7) →
   debarcader, schimbând sprite la fiecare stație. Muncă mică (traseu + sprite; prețul e deja pe
   server); efectul e exact „vezi mașina" — golul cel mai mare de la punctul 2.
2. **Plasa plină n-are semnal propriu.** Capacitatea se vede ca „8/12" (E3), dar nimic pe plasă arată
   sufocarea. Propunere: plasa se umflă/întunecă la capacitate — jucătorul observă blocajul, tiparul
   de la coada din Theme Park Tycoon 2.
3. **Grămada de bunuri crește doar ca număr.** Sacul/debarcaderul n-au reprezentare fizică. Sprite-uri
   stivuite vizibil la umplere, din pool-ul de `ImageLabel` deja planificat (§4.S) — marfa arată ca
   marfă, nu doar cifră.
4. **Bunurile procesate nu arată calitatea cumpărată.** G decide corect „upgrade = valoare, nu
   viteză" (Fine Ingots etc.), dar iconița rămâne aceeași. O strălucire/un contur la fiecare treaptă
   — cumpărătura se vede pe obiect, nu doar în preț.
5. **Renașterea dă doar procent, niciodată un obiect.** Miner's Haven arată de ce se reconstruia: nu
   procentul, ci obiectul Reborn nou și vizibil. Fiecare „Move Downstream" ar putea da un ornament
   cosmetic unic (steag, felinar, culoare) — nu putere, deci nu încalcă P4, dar dă dovada tangibilă
   pe care azi doar +50%/venit n-o dă.
6. **Coada la debarcader nu există** — vânzarea e instant, fără semnal de „am nevoie de mai multă
   capacitate". Un backlog vizibil și mic la sosiri peste ritm ar motiva Dock Stall/Market cu un
   motiv văzut, nu doar citit în tabel.
7. **În interiorul unei stații fixe, nimic nu se alege.** B a decis corect platforme fixe pentru
   bugetul de UI, dar asta a șters orice configurare. La cumpărare, două atașamente exclusive cu
   efecte diferite, ambele validate de simulator (gater: „lamă rapidă" pt. volum vs. „lamă fină" pt.
   bunuri cu nume) — prima ramificație reală, fără construcție liberă.
8. **Ordinea celor 48 de platforme e, în practică, un singur drum.** C vorbește de „1-3 platforme
   deodată", dar §5 le listează secvențial. La 2-3 puncte din fiecare eră, două platforme fără
   prioritate, spre configurații vizibil diferite — cere rescris în simulator, deci ultimul.

## Surse

Toate accesate/sintetizate 2026-09-12. Fandom = sinteză motor de căutare (acces direct blocat HTTP
402, ca și în notele 19/21/38); devforum = accesat direct.

- roblox.fandom.com/wiki/Tycoon · generalistprogrammer.com/tutorials/how-to-make-a-roblox-tycoon-game
- minershaven.fandom.com/wiki/Category:Upgrader, /Upgrader_Loop, /Category:Rebirth
- revamped-miners-haven.fandom.com/wiki/Reborns
- lumber-tycoon-2.fandom.com/wiki/Lumber_Tycoon_2
- retail-tycoon.fandom.com/wiki/Retail_Tycoon_2, /Upgrades · deltiasgaming.com/roblox-retail-tycoon-2-a-beginners-guide
- tpt2.fandom.com/wiki/Tutorial · progameguides.com/roblox/roblox-theme-park-tycoon-2-beginners-guide
- restaurant-tycoon-2.fandom.com/wiki/Upgrades
- rowatcher.com/news/the-10-highest-earning-roblox-games-in-2026 — estimări declarate, nu date Roblox
- en.wikipedia.org/wiki/Steal_a_Brainrot · en.wikipedia.org/wiki/Grow_a_Garden (deja în nota 20)
- medium.com/tindalos-games/idle-vs-incremental-vs-tycoon — acces blocat HTTP 403, prin sinteză
- devforum.roblox.com/t/making-a-tycoon-ish-game-a-lot-less-repetitive-and-boring/2043849
- devforum.roblox.com/t/different-approach-to-tycoons/533253
- devforum.roblox.com/t/what-do-you-want-to-see-in-a-tycoon/1048161
- docs/TYCOON.md §4.A/B/C/G/K/S, §5 · docs/research/20, 38 — note interne, context
