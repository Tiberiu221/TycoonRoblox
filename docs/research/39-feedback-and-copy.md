# Feedback vizual, numere și microcopy pentru Driftycoon

## Rezumat executiv

- 25 de propoziții e puțin pentru 48 de platforme și 4 ere — polish-ul vine din **mai multe momente care reacționează** (D43), nu din mai mult text.
- Vocabular fix: text plutitor (<1s), toast (3–6s), banner (până la tap), etichetă persistentă — fiecare cu locul lui.
- K/M/B universal, zecimale fără regulă unică. Text ieftin (uman sau AI) înseamnă generalitate — nimic despre obiectul sau cifra reală de pe ecran.

## Fapte verificate

- „+N" trebuie să apară în 2–3 cadre de la acțiune; culoare și traiectorie diferă pe tip de feedback (verde lin sus / roșu rapid). (S3, ridicată)
- Toast: 3–6s pe ecran, tranziție 200–300ms; ~500ms/cuvânt ca regulă de citire. (S4, medie)
- Contor care urcă spre valoarea nouă în 2–4s cu ease-out se reține mai bine decât un salt instant. (S5, medie)
- Pop de recompensă cu ușoară depășire (easeOutBack) se simte „apăsabil"; apariția liniară, fără depășire, e plată. (S14, ridicată)
- Ecran gol bun spune ce lipsește + ce poți face acum; „No data"/„Nothing here yet" singure sunt eșecul citat explicit. (S8, ridicată)
- Peste 5 pop-up-uri de tutorial la rând opresc cititul; o propoziție fără context lasă scopul neclar. (S11, medie)
- Microcopy bun sub trei propoziții, buton/tooltip la 20–35 caractere; CTA vag creează ezitare exact în clipa deciziei. (S12/S15, medie)
- K/M/B/T e convenția universală; zecimalele n-au regulă unică — fiecare joc o fixează și o ține. (S9/S10, ridicată)
- 80–90% nu citesc text de tutorial; victorie mică în 30s — confirmă nota 24 (70,48% abandon la pasul 2, „Plant"). (S13, medie; nota 24, ridicată)
- Gradientul albastru-violet e „the official color scheme of we used AI" în 2026; semnul de TEXT e generalitatea — titluri interschimbabile ca „Build faster. Ship smarter." (S6/S7/S16, medie)

## Riscuri și note

- Multe surse despre durate/easing sunt UX generalist sau marketing, nu jocuri Roblox — punct de plecare, de calibrat la playtest-ul F1.
- „AI slop" e cercetare despre web/SaaS, nu UI de joc — extrapolarea la Driftycoon e IPOTEZĂ, la fel ca zecimalele și bara de progres, fără convenție citabilă.

## Ce facem la Driftycoon

Fiecare rând de mai jos tace azi sau arată un cuvânt tehnic. Regulă: scurt, englez, adevărat (D40), nu gol (D43).

Tip: A text mic 0,6–0,9s ease-out; B text mare + sunet, ease-out-back; C bandă HUD 3–4s; D banner overshoot, până la tap; E etichetă persistentă; F panou modal, până la acțiune; G tooltip 1-dată, tap/~4s.

Trei reguli: fără emoji/superlative — numele obiectului bate orice adjectiv; fără text la dublu-tap/rate-limit — se ignoră, nu se ceartă; fără streak-uri noi (decis, §Q; **amendat de D71**: o serie zilnică binevoitoare, la bâlci) — „revino mâine" doar pe ecranul offline. „Low power" pulsează discret, niciodată roșu (P2).

| Categorie | Moment | Text (EN) | Tip |
|---|---|---|---|
| Râu | Prima prindere | „+1" | A |
| Râu | Prindere volum | „+1" | A |
| Râu | Prindere obiect cu nume | „Rusty Kettle!" | B |
| Râu | Plasă plină | „Net full" | E |
| Râu | Upgrade de plasă | „Nets cast wider now" | C |
| Sac | Collect la plasă | „+3 to sack" | A |
| Sac | Sac plin | „Sack full — go sell" | E |
| Sac | Bigger Sack cumpărat | „Sack holds more now" | C |
| Debarcader | Sell | „+42" | B |
| Debarcader | Prima vânzare din joc | „First sale. The river pays." | D |
| Debarcader | Preț mai mare activ | „+20% sold here" | A |
| HUD | Venitul pe secundă crește | „+15/s" | A |
| Pad | Cumpărabil acum | „Second Net — 9" | E |
| Pad | Bani insuficienți (nou) | „Need 6 more coins" | A |
| Pad | Cumpărare reușită | „Built!" | B |
| Pad | Pad următor dezvăluit | „Sorting Crate — 40" | E |
| Eră | Clopot tras | „The Landing pays 10% more. Forever." | D |
| Eră | Zonă nouă deblocată | „The Mill is open" | D |
| Atelier | Primul obiect cu nume | „The Workshop is open." | F |
| Atelier | Reparație finalizată | „Repaired. +1% income. Forever." | B |
| Atelier | Vânzare obiect cu nume | „Sold for 14" | A |
| Atelier | Colecție la 25% | „A quarter of the river, catalogued" | D |
| Atelier | Colecție la 50% | „Halfway through the Index" | D |
| Atelier | Obiect nou descoperit | „New: Rusty Kettle" | B |
| Angajați | Primul angajat sosește | „Room on this dock for one more?" | F |
| Angajați | Angajat nou cumpărat | „Miller hired" | C |
| Offline | Revenire după absență | „Your river earned 12.4K while you were away." | F |
| Offline | Seif plin cât ai lipsit | „The Vault filled up — a bigger one holds more" | F |
| Offline | Vault upgrade cumpărat | „Vault holds more now" | C |
| Renaștere | Disponibilă | „Move Downstream is ready" | E |
| Renaștere | Ecran de renaștere | „Stays: Index, Rebirths. Resets: Coins, Pads. You gain: +50% income." | F |
| Renaștere | Confirmată | „Moving downstream…" | D |
| Renaștere | Set nou deblocat | „New finds, downstream" | D |
| Energie | Insuficientă | „Low power" | E |
| Energie | Roată înlocuiește manivela | „Power flowing" | A |
| Energie | Upgrade de calitate | „Fine Ingots — worth more per sale" | C |
| Refuz | Sac gol la debarcader | „Nothing to sell yet" | A |
| Refuz | Zonă blocată atinsă | „Opens after the Mill Bell" | A |
| Sistem | Încărcare/reconectare | „Loading your river…" | F |
| Tooltip | Bara de energie | „Stations slow down without power" | G |
| Tooltip | Indexul | „Every repair raises your income for good" | G |
| Tooltip | Eligibilitate de renaștere | „A bonus that never touches what you've paid for" | G |

42 de rânduri, gata de lipit — cifrele exacte vin din server, nu se hardcodează.

## Surse

*(accesate 2026-09-12, dacă nu alt specificat)*

- [S1] Roblox — Onboarding techniques, via nota 24 (2026-09-08) — încredere: ridicată
- [S2] „Juice it or lose it" (GDC 2012): eastondev.com/blog/en/posts/dev/20260521-game-feedback-feel/ — încredere: medie
- [S3] GameJuice: gamejuice.co.uk/articles/damage-numbers-satisfying-feedback — încredere: ridicată
- [S4] StudyAround: studyaround.blog/toast-notification-design-guide — încredere: medie
- [S5] Krumzi: krumzi.com/tools/animated-counter — încredere: scăzută
- [S6] 925 Studios: 925studios.co/blog/ai-slop-design-tells — încredere: medie
- [S7] SmoothUI: smoothui.dev/blog/ai-design-slop — încredere: medie
- [S8] Eleken (publicat 2026-02-24): eleken.co/blog-posts/empty-state-ux — încredere: ridicată
- [S9] SimpleIdle: simpleidle.com/learn/big-number-notation-explained — încredere: medie
- [S10] GameDeveloper.com (2016-11-03): gamedeveloper.com/design/names-of-large-numbers-for-idle-games — încredere: ridicată
- [S11] UX Writing Hub: uxwritinghub.com/mobile-games-microcopy/ — încredere: medie
- [S12] parafraze NN/g, via parallelhq.com/blog/ux-writing-best-practices — încredere: medie
- [S13] Wayline: wayline.io/blog/tutorial-ux-indie-game-onboarding — încredere: medie
- [S14] GSAP + Mt. Mograph: gsap.com/resources/getting-started/Easing/ — încredere: ridicată
- [S15] TypeCount: typecount.com/blog/microcopy-ux-writing-guide — încredere: medie
- [S16] Writer.com: writer.com/blog/detect-destroy-ai-isms-marketing-copy/ — încredere: medie
