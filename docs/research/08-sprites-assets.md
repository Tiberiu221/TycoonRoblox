# Sprite-uri și asset-uri 2D pe Roblox: limite, upload, spritesheet

## Rezumat executiv

- Roblox promite acum rezoluție maximă de **4096×4096 (4K)** pentru texturi/decal-uri (anunț 30 ian. 2026), dar cel puțin două rapoarte de bug din martie și iunie 2026 arată că pagina de upload decal încă downscalează practic la **1024×1024** — situație **neclarificată oficial**, trebuie testată direct în Studio/Creator Dashboard înainte de a proiecta pipeline-ul de artă.
- Limita de upload prin API (Open Cloud) este **8000×8000 px, max 20 MB**, formate `.png/.jpeg/.bmp/.tga`; rezultatul e transcodat în josul lanțului de randare.
- Compresia agresivă tip DXT/BC (grăunți, artefacte de culoare) afectează **doar suprafețele 3D** (Decal pe Part, MeshPart, SurfaceAppearance) — conform unui răspuns oficial Roblox, **aceleași imagini afișate în ScreenGui/ImageLabel NU prezintă artefactele**. Pentru Driftwood (2D pur în ScreenGui) acesta e un avantaj important.
- Uploadul de imagini/decal-uri pentru uz privat într-un joc (nu pentru vânzare pe Marketplace ca avatar item) **nu are cost în Robux** documentat oficial; taxa de 80 Robux (500 pentru emissive mask) se aplică doar la accesorii de avatar publicate spre vânzare pe Marketplace, nu la sprite-uri de joc.
- Open Cloud Assets API: `POST https://apis.roblox.com/assets/v1/assets`, autentificare `x-api-key` sau OAuth2 (`asset:read`/`asset:write`), rate limit confirmat oficial: **120 req/min** pentru CreateAsset și GetAsset, **300 req/min** pentru GetOperation, **60 req/min** pentru asset-quotas — per cheie/owner (user sau grup).
- Există un tool open-source matur, **Asphalt** (jackTabsCode/asphalt, Rust CLI), care automatizează exact fluxul cerut: urcă fișiere prin Open Cloud și generează un **manifest Luau/TypeScript** cu numele fișierelor mapate la asset id-uri — soluția recomandată pentru 200+ sprite-uri.
- `ImageRectOffset`/`ImageRectSize` (spritesheet cropping) sunt **incompatibile cu `ScaleType.Tile`** — confirmat "as-designed" de un dev Roblox (6 feb. 2025). Pentru panouri 9-slice + spritesheet nu există confirmare că `ScaleType.Slice` + `ImageRectOffset` funcționează împreună — de testat.
- Modulul comunitar recomandat pentru animații spritesheet este **SpriteClip2** (gratuit, GitHub + Roblox Marketplace, oct. 2024), succesorul oficial-comunitar al vechiului SpriteClip (deprecat).
- Ownership-ul asset-urilor contează: asset-urile urcate pe cont personal trebuie **re-urcate manual** dacă jocul e transferat ulterior către un Grup Roblox; un Grup costă **100 Robux**, o singură dată.
- Moderarea durează, conform documentației oficiale, "**în câteva ore**" de la import, dar rapoarte din comunitate menționează întârzieri de până la 3+ zile în perioade aglomerate — planificați pipeline-ul cu marjă, nu cu upload sincron chiar înainte de lansare.

## Fapte verificate

- Open Cloud CreateAsset acceptă imagini `.png/.jpeg/.bmp/.tga` **mai mici de 8000×8000 px**, fișier max **20 MB**; endpoint `POST https://apis.roblox.com/assets/v1/assets`. — sursa: create.roblox.com/docs/cloud/guides/usage-assets, accesat 2026-09-08 (pagina nu are dată explicită de ultima actualizare vizibilă) — confidence: ridicata
- Limitele de rate pentru Assets API, confirmate direct din pagina de referință interactivă (Try It Out): CreateAsset = **120 req/min**, GetAsset = **120 req/min**, GetOperation = **300 req/min**, List Asset Quotas = **60 req/min** — per cheie API, agregat pe user/grup. — sursa: create.roblox.com/docs/cloud/reference/features/assets, verificat live 2026-09-08 — confidence: ridicata
- Scope-urile OAuth2/API key pentru Assets API sunt `asset:read` și `asset:write`. — aceeași sursă — confidence: ridicata
- Roblox a anunțat "4K Texture Rendering" (4096×4096) pentru MeshPart, SurfaceAppearance, Texture, Decal, MaterialVariant, cu import posibil până la 8K și transcodare în jos la 4K; necesită Texture Streaming activat. — sursa: devforum.roblox.com/t/4k-texture-rendering/4316229, postat 30 ian. 2026 — confidence: medie (anunț oficial, dar contrazis practic de rapoarte ulterioare)
- Contrar anunțului de mai sus, un raport de bug din **19 martie 2026** și altul din **30 iunie 2026** arată că pagina de upload decal de pe Creator Hub afișează în continuare avertismentul de downscale la 1024×1024, iar un utilizator confirmă empiric că "decals are still getting downsized". Niciun răspuns oficial de staff nu a fost găsit în aceste fire. — sursa: devforum.roblox.com/t/decal-upload-page-still-mentions-1024x1024-limit-instead-of-4096x4096/4526770 (19 mar. 2026) și devforum.roblox.com/t/decal-uploads-are-still-limited-to-1024x1024/4710639 (30 iun. 2026) — confidence: medie (conflict activ, nerezolvat)
- Artefactele de compresie texturi (grăunți, tente violet/verde) afectează Decal-uri pe Part/MeshPart/SurfaceAppearance; un angajat Roblox (fnublox) a confirmat: "both the pixel grains and color shifts are compression artifacts", fără soluție/termen oferit. Raportorul a verificat că **aceeași imagine pe ImageLabel în ScreenGui nu are artefactele**. — sursa: devforum.roblox.com/t/texture-compression-and-weird-pixel-grains-after-importing-to-studio/2591486 — confidence: medie (confirmare oficială parțială + observație comunitară necontestată)
- `ResampleMode` (Default/Pixelated) există pe **ImageLabel și ImageButton** din 16 aug. 2021; modul "Pixelated" = nearest-neighbor, recomandat doar la **mărire** de imagine, nu la micșorare (produce aliasing). — sursa: devforum.roblox.com/t/resamplemode-new-property-for-image-gui-objects/1418681, 16 aug. 2021 — confidence: ridicata (dar sursă din 2021 — verificați dacă s-a extins între timp la alte clase)
- `ImageRectOffset`/`ImageRectSize` (folosite pentru spritesheet) **nu funcționează cu `ScaleType.Tile`** — comportament "as-designed", nu bug: "spritesheets are not supported for tiled scaletypes as we rely on UV wrapping ... rather than repeating a specific part of the texture" (răspuns oficial Roblox, 6 feb. 2025). — sursa: devforum.roblox.com/t/imagerectoffsetsize-does-not-work-with-tile-scaletype/3409510 — confidence: ridicata
- Asset Manager: import bulk legacy suportă **până la 50 de fișiere per lot**; noul "Universal Importer" (beta, anunțat 30 ian. 2026) unifică import de imagini/audio/video/3D, dar utilizatori raportează probleme la loturi de 150+ fișiere și recomandă loturi de ~10. — surse: create.roblox.com/docs/projects/assets/manager și devforum.roblox.com/t/studio-beta-universal-importer-import-images-audio-video-and-3d-in-one-place/4316127 (30 ian. 2026) — confidence: medie (limita de lot exactă a Universal Importer nu e documentată)
- Asset-urile sunt **private by default** la import; pentru a fi văzute de alți jucători trebuie doar publicate în experience (nu neapărat pe Creator Store) — moderarea le blochează vizibilitatea publică până la aprobare. — sursa: create.roblox.com/docs/projects/assets — confidence: ridicata
- Moderarea automată+umană a asset-urilor se termină, conform documentației oficiale, "**within a few hours after you import the asset**". — sursa: create.roblox.com/docs/projects/assets — confidence: ridicata (dar contrazisă empiric de rapoarte de comunitate care vorbesc de zile în perioade aglomerate — flag ca posibil optimist)
- Apelul (appeal) la moderare se face prin "Violations & Appeals" (dacă e eligibil) sau formularul de Support; termen limită **30 de zile** de la acțiune (**6 luni** pentru utilizatori UE, sub DSA); o moderare o dată revizuită nu mai poate fi rejudecată. — sursa: en.help.roblox.com "Appeal Your Content or Account Moderation", accesat 2026-09-08 — confidence: ridicata
- Taxa de upload de **80 Robux** (500 Robux pentru piese cu emissive mask) se aplică la **submisii de accesorii de avatar** spre Marketplace, nu la decal-uri/imagini folosite privat într-un joc; taxa nu se restituie dacă itemul e respins. — sursa: create.roblox.com/docs/marketplace/marketplace-fees-and-commissions — confidence: ridicata (pt. accesorii avatar) / medie (pt. inferența că decal-urile normale sunt gratuite — nicio pagină oficială nu afirmă explicit "decal upload is free")
- Crearea unui Grup Roblox costă **100 Robux**, taxă unică, nerambursabilă. — sursa: create.roblox.com/docs/projects/groups, accesat 2026-09-08 — confidence: ridicata
- La transferul unui experience către un Grup, scripturile private (ModuleScripts) și asset-urile folosite prin `InsertService` trebuie **re-urcate manual pe grup**; pachetele (Packages) deținute de un user (nu de grup) trebuie recreate sau înlocuite. — sursa: create.roblox.com/docs/projects/game-ownership-transfer — confidence: ridicata
- `ContentProvider:PreloadAsync(contentIdList, callback)` — yield până se încarcă tot ce e în listă; documentația oficială demonstrează preload pentru `Sound` (via `SoundId`) și `Decal` (via `ColorMapContent`); nu există exemplu oficial explicit cu `ImageLabel.Image`, iar în comunitate există confuzie/dezacord dacă instanțe ImageLabel merg direct sau trebuie folosit un Decal temporar / `IsLoaded`. — sursa: create.roblox.com/docs/reference/engine/classes/ContentProvider/PreloadAsync + devforum.roblox.com/t/properly-using-preloadasync/1148953 — confidence: scazuta pt. comportamentul exact pe ImageLabel — **de testat în Studio**
- SpriteClip (modulul original) e **oficial deprecat**; succesorul **SpriteClip2** e gratuit, disponibil pe GitHub (nooneisback/luau-spriteclip2) și pe Roblox Marketplace (asset id 111579633111377), postat 6 oct. 2024, cu suport pentru ImageSprite, EditableSprite și un sistem de semnale (`GetSignal`). — sursa: devforum.roblox.com/t/spriteclip2-a-free-versatile-spritesheet-animation-module/3184892 — confidence: ridicata
- **Asphalt** (jackTabsCode/asphalt) e un CLI (Rust, instalabil via Cargo/Homebrew/Rokit/Mise) care urcă asset-uri prin Open Cloud API (necesită cheie cu scope `asset:read`+`asset:write`) și generează automat cod Luau/TypeScript ce mapează căi de fișier → asset id, configurat printr-un `asphalt.toml`. — sursa: raw.githubusercontent.com/jackTabsCode/asphalt/main/README.md, accesat 2026-09-08 — confidence: ridicata (tool comunitar activ, nu oficial Roblox)
- Roblox nu are un importator nativ de spritesheet; pattern-ul standard e: pachetezi cu TexturePacker/Aseprite (export PNG + JSON cu coordonate per-frame), urci PNG-ul ca un singur asset Image/Decal, apoi setezi programatic `ImageRectOffset`/`ImageRectSize` per cadru din datele JSON parsate. — sursa: sinteză din community tutorials (codeandweb.com/texturepacker, aseprite.org/docs/exporting) + devforum — confidence: medie (nu există pagină oficială Roblox despre spritesheet packing)
- Anunțul original al Open Cloud Assets API (29 mar. 2023) confirmă tipurile inițiale (Audio, Decal, Model) și că verificarea stării de moderare via API a fost adăugată ulterior ("You'll probably see it in a few months" — citat staff). — sursa: devforum.roblox.com/t/introducing-open-cloud-assets-api/2245171 — confidence: ridicata

## Detalii

### 1. Limite de upload și formate — tabel

| Canal de upload | Format acceptat | Dimensiune max. | Observații | Sursă |
|---|---|---|---|---|
| Open Cloud `CreateAsset` (assetType Decal/Image) | `.png` `.jpeg` `.bmp` `.tga` | < 8000×8000 px, fișier ≤ 20 MB | Async, întorci un `operations/{id}`, apoi faci poll pe GetOperation | create.roblox.com/docs/cloud/guides/usage-assets |
| Creator Dashboard / Studio Asset Manager (UI) | `.png` `.jpg` `.gif` `.tga` `.bmp` | Documentat 4096×4096 (4K, ian. 2026), dar UI-ul de upload decal încă avertizează 1024×1024 (bug nerezolvat, iun. 2026) | Downscalare automată la ce depășește limita efectivă | devforum 4316229, 4526770, 4710639 |
| Bulk Import legacy | idem | max **50 fișiere/lot** | Intră direct în coadă de moderare | create.roblox.com/docs/projects/assets/manager |
| Universal Importer (beta) | imagini + audio + video + 3D, mixat | Nedocumentat oficial; comunitate raportează instabilitate la 150+, recomandă loturi ~10 | Va înlocui Bulk Importer legacy | devforum 4316127 |

**Recomandare practică**: nu presupune 4K funcțional în producție. Testează în Studio cu un cont real, cu o imagine 4096×4096, și verifică rezultatul efectiv (ce rezoluție are asset-ul final descărcat). Presupune worst-case 1024×1024 până confirmi contrariul — dimensionează arta astfel încât 1024×1024 să fie suficient pentru orice sprite individual afișat la scară maximă pe ecran.

### 2. Compresie și artefacte — de ce contează pentru Driftwood

Confirmarea oficială Roblox e clară: compresia tip DXT/BC ce produce grăunți și schimbări de culoare (violet/verde) apare **pe randarea 3D** (Decal pe Part, MeshPart cu SurfaceAppearance). Un raportor a verificat explicit: **același asset ID afișat printr-un ImageLabel în ScreenGui arăta perfect**, fără artefacte. Pentru Driftwood, care e "2D pur în ScreenGui — totul e Frame/ImageLabel, nu parts 3D" (din CLAUDE.md), acest risc practic nu se aplică deloc — un avantaj arhitectural real al alegerii voastre tehnice.

Rămâne totuși riscul de **compresie lossy la re-encodarea internă a imaginii** (independent de pipeline-ul 3D) — comunitatea recomandă:
- PNG pentru orice are transparență/muchii dure (majoritatea sprite-urilor de obiecte, iconițe UI).
- JPEG doar pentru fundaluri opace mari fără alpha, calitate export 60-80.
- Evită upscale: încarcă la rezoluția nativă țintă, nu la 2-4x "ca să fie sigur" — imaginile mult mai mari decât ImageLabel-ul care le afișează se văd, empiric, mai neclare după downscale-ul intern al Roblox decât dacă ai încărcat direct la dimensiunea corectă.

### 3. Moderare

- Timp tipic: "**within a few hours**" per documentația oficială (create.roblox.com/docs/projects/assets). Comunitatea (devforum, fire multiple din 2024-2025) raportează episoade de **3+ zile** în perioade de trafic mare pe coada de moderare.
- Ce se respinge frecvent: nuditate/conținut sugestiv, personaje/branduri protejate de copyright, simboluri de ură — dar și **fals-pozitive pe texturi abstracte** (lemn, țesătură, metal, gradient) interpretate greșit de clasificatorul AI, conform experienței developerilor citate în surse secundare (rowatcher.com, figbloxui.dev — **surse secundare, neverificate oficial**).
- Apel: prin **Violations & Appeals** (dacă notificarea de moderare oferă acest link) sau **formularul de Support**, cu Asset ID + link către conținut. Termen: **30 zile** (6 luni UE). O decizie revizuită o dată e finală — nu poți contesta a doua oară aceeași acțiune.
- Sistem "Reporting & Appeals" îmbunătățit din nov. 2023 acoperă apeluri pentru imagine/audio/mesh/model/avatar accessory, cu notificări email la moderare și proces "one-click" de apel.

**Implicație de plan**: pentru 200+ sprite-uri, dacă le urci individual (200 de asset-uri Image separate), fiecare intră separat în coada de moderare — expunere mare la fals-pozitive și volum mare de apeluri posibile. Împachetarea în spritesheet-uri (vezi secțiunea 6) reduce numărul de asset-uri urcate de la 200+ la ordinul zecilor, deci și expunerea la moderare individuală.

### 4. Cost și proprietate (ownership)

- Nu există taxă documentată oficial pentru upload de Decal/Image pentru uz într-un experience propriu. Surse secundare vechi (wiki, bloguri) menționează "10 Robux" — acesta pare a fi **rest istoric** dintr-o eră anterioară (Builder's Club) și nu apare în niciuna din paginile oficiale curente (create.roblox.com/docs/projects/assets, create.roblox.com/docs/parts/textures-decals, create.roblox.com/docs/cloud/guides/usage-assets). Marcat **NEVERIFICAT cu certitudine 100%** — testați o încărcare de test în Studio pe cont propriu înainte de a bugeta orice cost aici.
- Taxa de **80 Robux / 500 Robux** e documentată explicit doar pentru **accesorii de avatar publicate pe Marketplace** (nu decal-uri de joc) — nu confundați cele două fluxuri.
- **Ownership**: implicit privat, legat de contul/grupul care a făcut uploadul. Dacă Driftwood pornește pe cont personal și se transferă mai târziu unui Grup (echipă, parteneri), toate ModuleScript-urile private și asset-urile via InsertService trebuie re-urcate manual pe grup — friction real. **Recomandare: creați un Grup Roblox (100 Robux, o singură dată) de la început** și urcați toate asset-urile pe grup, chiar dacă lucrați singur acum.

### 5. Open Cloud Assets API — referință completă

Endpoint-uri (bază `apis.roblox.com`, verificate live pe pagina interactivă a documentației, 2026-09-08):

| Metodă | Cale | Scope | Rate limit (per cheie API, agregat user/grup) |
|---|---|---|---|
| POST | `/assets/v1/assets` (CreateAsset) | `asset:write` | 120 req/min |
| GET | `/assets/v1/assets/{assetId}` (GetAsset) | `asset:read` | 120 req/min |
| PATCH | `/assets/v1/assets/{assetId}` (UpdateAsset) | `asset:write` | limitat doar la `.fbx` la content-update; alte câmpuri suportate | nedocumentat explicit — presupune 120 req/min ca restul familiei |
| GET | `/assets/v1/assets/{assetId}/versions` | `asset:read` | nedocumentat explicit |
| POST | `/assets/v1/assets/{assetId}/versions:rollback` | `asset:write` | nedocumentat |
| POST | `/assets/v1/assets/{assetId}:archive` / `:restore` | `asset:write` | nedocumentat |
| GET | `/assets/v1/operations/{operationId}` (GetOperation) | `asset:read` | **300 req/min** |
| GET | `/cloud/v2/users/{user_id}/asset-quotas` | `asset:read` | **60 req/min** |

Autentificare: header `x-api-key: <cheie>` (creat din Creator Dashboard → API Keys) sau OAuth 2.0 Bearer token. Cheile API au rate limit **agregat pe toate cheile ale aceluiași owner** (user sau grup) — nu per cheie individuală.

Exemplu request (Node.js, din tutorial comunitate devforum, 15 apr. 2023, adaptat):

```js
const Axios = require('axios');
const FormData = require('form-data');
const fs = require('fs');

async function createAsset() {
  const form = new FormData();
  form.append('request', JSON.stringify({
    assetType: 'Decal',
    displayName: 'crate_broken_01',
    description: 'Sprite obiect spart - lada',
    creationContext: { creator: { groupId: '<GROUP_ID>' } },
  }));
  form.append('fileContent', fs.readFileSync('crate_broken_01.png'), 'crate_broken_01.png');

  const res = await Axios.post('https://apis.roblox.com/assets/v1/assets', form, {
    headers: { 'x-api-key': process.env.ROBLOX_API_KEY, ...form.getHeaders() },
  });
  console.log(res.data.path); // "operations/{operationId}"
}
```

Apoi faci poll pe `GET /assets/v1/operations/{operationId}` până `done: true`; `response.assetId` e ID-ul final, `response.moderationResult.moderationState` (string, valorile exacte nu sunt documentate explicit public — **NEVERIFICAT**, dar practic conțin stări de tip "în verificare / aprobat / respins" — verificați empiric un răspuns real).

Sistemul de **quotas**: există un endpoint dedicat (`asset-quotas`) care întoarce obiecte cu `quotaType`, `assetType`, `usage`, `capacity`, `period`, `usageResetTime` — deci Roblox impune plafoane de câte asset-uri poți urca într-o perioadă, per tip, dar **valorile numerice nu sunt publicate în documentație** — se interoghează dinamic per cont. **NEVERIFICAT ca număr fix** — interogați acest endpoint cu cheia voastră înainte de a planifica un upload masiv de 200+ fișiere într-o singură sesiune.

### 6. `rbxassetid` vs Decal ID vs Image ID — sursa confuziei

Un **Decal** e o instanță-container (are proprietăți precum `Face`, `Color3`, `Transparency`) care **referă** un asset de tip Image/textură printr-o proprietate internă (`Texture` / `ColorMapContent`). Când urci o imagine prin fluxul clasic "Decal" din Creator Dashboard, Roblox creează **două** asset ID-uri: unul pentru containerul Decal, altul pentru imaginea propriu-zisă. `ImageLabel.Image` are nevoie de **ID-ul de imagine**, nu de ID-ul de Decal — dacă pui ID-ul greșit (al Decal-ului), proprietatea nu randează.

Cum obții ID-ul corect de imagine dintr-un ID de Decal:
1. **Via Open Cloud Assets API** (dacă tu ai urcat asset-ul): `CreateAsset` cu `assetType: "Decal"` sau `"Image"` întoarce direct `assetId`-ul corect de folosit — evită complet confuzia dacă urci cu API-ul de la zero.
2. **Via Studio**: `InsertService:LoadAsset(decalId)` încarcă instanța Decal, apoi citești proprietatea `Texture` care conține `rbxassetid://<imageId>`.
3. Formatul `rbxassetid://<ID>` e schema URI universală pentru orice content id valid (imagine, sunet, mesh) — funcționează identic indiferent dacă ID-ul provine dintr-un upload Decal sau Image, atâta timp cât e ID-ul asset-ului de conținut real, nu al containerului.

**Recomandare Driftwood**: urcați direct cu `assetType: "Image"` (nu `"Decal"`) prin Open Cloud API pentru sprite-urile UI — eviți din start dubla-ID și primești un singur `assetId` de folosit direct în `ImageLabel.Image`.

### 7. Proprietăți `ImageLabel` relevante pentru spritesheet/9-slice

| Proprietate | Tip | Rol |
|---|---|---|
| `Image` | `ContentId` (string `rbxassetid://ID`) | Asset-ul sursă (spritesheet-ul întreg) |
| `ImageRectOffset` | `Vector2` | Colțul stânga-sus (în px) al cadrului curent din spritesheet |
| `ImageRectSize` | `Vector2` | Lățime/înălțime (în px) a cadrului; `(0,0)` = imaginea întreagă |
| `ScaleType` | `Enum.ScaleType` | `Stretch` / `Slice` / `Crop` / `Fit` / `Tile` |
| `SliceCenter` | `Rect` | Zona centrală (în px) pentru 9-slice, doar cu `ScaleType.Slice` |
| `SliceScale` | `number` | Scalează grosimea marginilor la 9-slice |
| `TileSize` | `UDim2` | Dimensiunea unui tile, doar cu `ScaleType.Tile` |
| `ResampleMode` | `Enum.ResamplerMode` (`Default` / `Pixelated`) | `Pixelated` = nearest-neighbor, bun pt. pixel art la mărire, nu la micșorare |
| `ImageColor3` | `Color3` | Tint peste imagine (multiplicativ) |
| `ImageTransparency` | `number` (0-1) | Transparență adițională peste alpha-ul din PNG |

**Incompatibilitate confirmată oficial**: `ImageRectOffset`/`ImageRectSize` nu funcționează cu `ScaleType.Tile` (design intenționat, nu bug, confirmat de staff Roblox pe 6 feb. 2025). Pentru fundaluri repetitive (ex. textura apei râului, dacă vreți tiling) **nu** le puteți combina cu un spritesheet — folosiți o imagine dedicată separată pentru orice element care trebuie să facă tile.

Interacțiunea `ScaleType.Slice` (9-slice) + `ImageRectOffset`/`ImageRectSize` (adică 9-slice pe un singur cadru dintr-un spritesheet, pentru panouri UI cu variante) **nu are confirmare oficială** găsită — marcat ca întrebare deschisă de testat în Studio.

### 8. Pipeline de spritesheet — tool-uri

- **TexturePacker** (codeandweb.com, plătit/trial) — nu are exporter nativ Roblox, dar exportă JSON generic (nume-cadru → `{x,y,w,h}`); scrii un script mic (Python/Luau la build-time) care transformă JSON-ul în tabel Luau cu `ImageRectOffset`/`ImageRectSize` per cadru.
- **Aseprite** (aseprite.org, ~20 USD) — "Export Sprite Sheet" nativ + CLI (`aseprite --batch ... --sheet out.png --data out.json`), scriptabil în Lua pentru automatizare completă a exportului pentru 200+ item-uri dintr-un singur pas.
- **I Love Sprites** (ilovesprites.com/spritesheet-generator-roblox) — tool browser, **sursă secundară/comunitară**, orientat specific spre Roblox (generează direct coordonatele pentru ImageRectOffset); nu verificat independent, testați înainte de a-l integra în pipeline de producție.
- Module Luau de animație spritesheet:
  - **SpriteClip2** (gratuit, github.com/nooneisback/luau-spriteclip2, Roblox Marketplace id `111579633111377`) — grid-based (`spriteSize`, `spriteCount`, `columnCount`, `edgeOffset`, `spriteOffset`), API `Play/Pause/Stop/SetFrame/Advance/GetSignal`, suportă și `EditableImage`. Recomandat ca bază.
  - **SpriteClip** original — **deprecat oficial**, nu-l folosiți pentru cod nou.
  - **Flipbook Animator** (github.com/Grunionnn/FlipbookAnimator) — alternativă mai simplă, comunitară, neverificată în profunzime aici.

### 9. Design propus pentru modulul Luau de spritesheet (Driftwood)

Given confirmarea că `Tile` nu merge cu Rect-cropping, și că aveți nevoie de animații per-item (unelte reparate, obiecte plutind pe râu) plus posibil 9-slice pentru panouri UI — recomand **două module separate**, nu unul singur care încearcă să acopere ambele cazuri:

```lua
-- SpriteSheetAnimator.luau (schelet minimal, bazat pe pattern-ul grid din SpriteClip2)
local SpriteSheetAnimator = {}
SpriteSheetAnimator.__index = SpriteSheetAnimator

-- config: { image = "rbxassetid://...", frameSize = Vector2, columns = number,
--           frameCount = number, frameRate = number, edgeOffset = Vector2?, spacing = Vector2? }
function SpriteSheetAnimator.new(imageLabel: ImageLabel, config)
	local self = setmetatable({}, SpriteSheetAnimator)
	self.label = imageLabel
	self.config = config
	self.currentFrame = 0
	self.playing = false
	imageLabel.Image = config.image
	imageLabel.ImageRectSize = config.frameSize
	return self
end

function SpriteSheetAnimator:SetFrame(index: number)
	local cfg = self.config
	local col = index % cfg.columns
	local row = math.floor(index / cfg.columns)
	local offset = cfg.edgeOffset or Vector2.zero
	local spacing = cfg.spacing or Vector2.zero
	self.label.ImageRectOffset = offset + Vector2.new(
		col * (cfg.frameSize.X + spacing.X),
		row * (cfg.frameSize.Y + spacing.Y)
	)
	self.currentFrame = index
end

function SpriteSheetAnimator:Play(loop: boolean?)
	self.playing = true
	task.spawn(function()
		local frameTime = 1 / self.config.frameRate
		while self.playing do
			self:SetFrame((self.currentFrame + 1) % self.config.frameCount)
			task.wait(frameTime)
			if not loop and self.currentFrame == self.config.frameCount - 1 then
				self.playing = false
			end
		end
	end)
end

function SpriteSheetAnimator:Stop()
	self.playing = false
end

return SpriteSheetAnimator
```

Pentru producție reală, evaluați SpriteClip2 direct — are deja gestionarea corectă a pauzei/frame-rate-ului variabil și un ecosistem testat, în loc să reinventați asta.

### 10. `ContentProvider:PreloadAsync` — strategie

```lua
local ContentProvider = game:GetService("ContentProvider")

local function preloadSpriteSheets(imageIds: {string})
	local total = #imageIds
	local loaded = 0
	ContentProvider:PreloadAsync(imageIds, function(contentId, status)
		loaded += 1
		-- status: Enum.AssetFetchStatus (Success / Failure / TimedOut / NotFound)
		loadingBar.Size = UDim2.fromScale(loaded / total, 1)
	end)
end
```

Documentația oficială demonstrează preload cu `Decal`/`Sound`, nu explicit cu `ImageLabel`. Pattern-uri sigure, ambele valide conform surselor:
1. Pasezi direct string-uri `"rbxassetid://<id>"` în listă (funcționează pentru majoritatea tipurilor de conținut, inclusiv imagini).
2. Alternativ (recomandat dacă (1) dă erori intermitente): creezi instanțe `Decal` temporare cu `Texture` setat la ID-ul dorit, le pasezi la `PreloadAsync`, apoi le distrugi.

Pentru un ecran de loading la 200+ sprite-uri împachetate în, să zicem, 10-20 spritesheet-uri: preîncărcați lista de **ID-uri de spritesheet** (nu 200 de ID-uri individuale — ele sunt deja parte din puținele foi mari), ceea ce reduce dramatic numărul de cereri de rețea la pornire.

## Recomandari concrete pentru Driftwood

1. **Urcați toate asset-urile pe un Grup Roblox, nu pe contul personal**, chiar de la început (100 Robux, o singură dată). Motiv: evitați re-uploadul manual al zecilor de sprite-uri dacă proiectul crește într-o echipă sau se transferă ulterior — friction-ul de migrare e documentat oficial și real.
2. **Împachetați cele 200+ item-uri în spritesheet-uri tematice** (ex. câte o foaie per categorie: unelte, lăzi, epave, decorațiuni), nu ca 200 de asset-uri Image separate. Reduceți numărul de asset-uri urcate individual de la 200+ la câteva zeci — mai puține treceri prin coada de moderare, mai puține HTTP requests la runtime, mai simplu de gestionat rate-limit-ul de 120 req/min.
3. **Testați empiric limita reală de rezoluție** înainte de a stabili rezoluția de lucru pentru artă: încărcați o imagine 4096×4096 de test în contul/grupul vostru și verificați rezoluția efectivă a asset-ului rezultat (descărcați-l înapoi sau verificați dimensiunile în Studio). Dat fiind conflictul documentat (anunț 4K vs. bug rapoarte 1024×1024 din 2026), nu bugetați timpul de artă pe presupunerea optimistă.
4. **Folosiți Open Cloud API (`assetType: "Image"`, nu `"Decal"`)** pentru upload programatic — evitați complet confuzia decal-id vs image-id descrisă în secțiunea 6, și obțineți `assetId` direct utilizabil în `ImageLabel.Image`.
5. **Adoptați Asphalt** (github.com/jackTabsCode/asphalt) ca tool de sincronizare: definiți un `asphalt.toml` cu toate sprite-urile/spritesheet-urile din `assets/`, rulați `asphalt sync`, obțineți automat un modul Luau generat (`Assets.luau` sau similar) cu toate ID-urile — evitați total gestionarea manuală de 200+ numere magice în cod.
6. **Nu folosiți `ScaleType.Tile` pentru nimic care are nevoie de `ImageRectOffset`/`ImageRectSize`** — e incompatibilitate confirmată oficial "as-designed". Pentru texturi repetitive (apă, teren) folosiți imagini dedicate separate, nu cadre dintr-un spritesheet.
7. **Adoptați SpriteClip2** ca bază pentru animații (unelte care se repară, obiecte care plutesc) în loc să scrieți de la zero un sistem complet — e gratuit, activ întreținut, are deja gestionarea corectă a pauzei/distrugerii instanțelor (relevant pentru performanță cu potențial multe animații simultane pe ecran — plase, obiecte pe râu).
8. **Preîncărcați doar foile de spritesheet (10-20 ID-uri), nu 200 de ID-uri individuale**, la loading screen, folosind `ContentProvider:PreloadAsync`. Testați ambele pattern-uri (string direct vs. Decal temporar) în Studio, pentru că documentația oficială nu confirmă explicit comportamentul cu `ImageLabel`.
9. **Format PNG pentru toate sprite-urile de obiecte/UI cu transparență**; JPEG doar pentru fundaluri mari, opace, fără alpha. Nu upscalați artificial imagini pentru "siguranță" — încărcați la dimensiunea nativă țintă.
10. **Planificați moderarea cu marjă de câteva zile**, nu ore, mai ales pentru upload-uri în bloc (200+ item-uri) chiar înainte de un lansare/eveniment — documentația oficială spune "câteva ore" dar comunitatea raportează episoade de zile în perioade aglomerate.
11. **Interogați endpoint-ul de asset-quotas** (`GET /cloud/v2/users/{user_id}/asset-quotas`) cu cheia voastră API înainte de un upload masiv, ca să aflați plafonul real per tip de asset — nu e documentat public ca număr fix.
12. Dacă folosiți `ResampleMode.Pixelated` pentru un stil pixel-art, aplicați-l doar acolo unde imaginea e **mărită** față de sursă, nu micșorată — altfel apar artefacte de aliasing documentate oficial.

## Riscuri si necunoscute

- **Rezoluția reală de upload e într-o stare contradictorie** (anunț oficial 4K din ian. 2026 vs. bug-uri raportate încă active în iun. 2026 care arată 1024×1024). Acesta e cel mai mare risc pentru planificarea pipeline-ului de artă — poate schimba complet bugetul de timp per sprite dacă rezoluția utilizabilă e de fapt mult mai mică decât anunțat.
- **Rate limits pentru UpdateAsset/versiuni** nu sunt documentate explicit în pagina de referință (doar CreateAsset/GetAsset/GetOperation/asset-quotas au valori confirmate) — dacă plănuiți re-uploaduri frecvente de versiuni (ex. rebalansare artă), verificați empiric limita.
- **Costul real de upload al unui Decal/Image** nu e confirmat printr-o afirmație oficială explicită de tipul "uploading is free" — inferența vine din absența oricărei mențiuni de cost pe paginile relevante, contrastată cu taxa documentată pentru altă categorie (avatar). Recomand un test cu upload real de câțiva Robux de rezervă înainte de a garanta cost zero în bugetul de proiect.
- **Valorile exacte ale enum-ului `moderationState`** din răspunsul API nu sunt documentate public — codul care depinde de starea de moderare trebuie scris defensiv (verificare pe substring/valoare necunoscută), nu hard-codat pe un set presupus de string-uri.
- **Interacțiunea `ScaleType.Slice` + `ImageRectOffset`** (9-slice pe un cadru dintr-un spritesheet) nu are nicio confirmare găsită, nici pozitivă, nici negativă — posibil să nu funcționeze la fel ca `Tile`.
- Universal Importer e încă **în beta** (ian. 2026) — comportamentul la loturi mari (200+ fișiere deodată) nu e testat/documentat oficial; folosiți loturi mici (~10-20) până se stabilizează.

## Intrebari deschise

1. Testați în Studio: încărcați o imagine PNG la 4096×4096 pe contul/grupul de Driftwood și verificați rezoluția efectivă a asset-ului rezultat — decide dacă lucrați la 1024, 2048 sau 4096 nativ.
2. Testați dacă `ContentProvider:PreloadAsync` acceptă direct string-uri `rbxassetid://` pentru imagini folosite doar în `ImageLabel` (nu Decal pe Part) — sau dacă trebuie pattern-ul cu Decal temporar.
3. Testați `ScaleType.Slice` + `ImageRectOffset`/`ImageRectSize` combinate — funcționează 9-slice pe un singur cadru dintr-un spritesheet?
4. Confirmați costul real (0 Robux sau nu) al unui upload de Decal/Image prin Creator Dashboard, cu un cont de test.
5. Interogați `asset-quotas` cu o cheie API reală pentru a afla plafonul curent (zilnic/lunar) pentru `assetType: Image` — relevant direct pentru fereastra de timp în care puteți urca cele 200+ sprite-uri.
6. Decideți dacă organizați sprite-urile într-un singur spritesheet mare (mai puține asset-uri, mai simplu de moderat) sau mai multe foi tematice mai mici (mai flexibil pentru actualizări parțiale fără re-upload total) — depinde de cât de des se schimbă arta unui singur item vs. tot setul.
7. Verificați dacă `Asphalt` suportă fluxul specific de grup (creator `type = "group"` în `asphalt.toml`) fără fricțiuni — README-ul arată exemplu doar cu `type = "user"`.

## Surse

- [Usage guide for assets](https://create.roblox.com/docs/cloud/guides/usage-assets) — Roblox Creator Hub, accesat 2026-09-08
- [Assets API reference (interactive)](https://create.roblox.com/docs/cloud/reference/features/assets) — Roblox Creator Hub, verificat live (Try It Out) 2026-09-08
- [Rate limits](https://create.roblox.com/docs/cloud/reference/rate-limits) / [raw md](https://raw.githubusercontent.com/Roblox/creator-docs/main/content/en-us/cloud/reference/rate-limits.md) — Roblox Creator Hub / GitHub Roblox/creator-docs, accesat 2026-09-08
- [Texture specifications](https://create.roblox.com/docs/art/modeling/texture-specifications) — Roblox Creator Hub, accesat 2026-09-08
- [Textures and decals](https://create.roblox.com/docs/parts/textures-decals) — Roblox Creator Hub, accesat 2026-09-08
- [Assets (overview)](https://create.roblox.com/docs/projects/assets) — Roblox Creator Hub, accesat 2026-09-08
- [Asset Manager](https://create.roblox.com/docs/projects/assets/manager) — Roblox Creator Hub, accesat 2026-09-08
- [Text & image labels](https://create.roblox.com/docs/ui/labels) — Roblox Creator Hub, accesat 2026-09-08
- [UI 9-slice design](https://create.roblox.com/docs/ui/9-slice) — Roblox Creator Hub, accesat 2026-09-08
- [ImageLabel class reference](https://create.roblox.com/docs/reference/engine/classes/ImageLabel) — Roblox Creator Hub, accesat 2026-09-08
- [ContentProvider:PreloadAsync](https://create.roblox.com/docs/reference/engine/classes/ContentProvider/PreloadAsync) — Roblox Creator Hub, accesat 2026-09-08
- [Marketplace fees and commissions](https://create.roblox.com/docs/marketplace/marketplace-fees-and-commissions) — Roblox Creator Hub, accesat 2026-09-08
- [Groups (teams)](https://create.roblox.com/docs/projects/groups) — Roblox Creator Hub, accesat 2026-09-08
- [Game ownership transfer](https://create.roblox.com/docs/projects/game-ownership-transfer) — Roblox Creator Hub, accesat 2026-09-08
- [4k Texture Rendering](https://devforum.roblox.com/t/4k-texture-rendering/4316229) — DevForum Announcements, 30 ian. 2026
- [Studio Beta: Universal Importer](https://devforum.roblox.com/t/studio-beta-universal-importer-import-images-audio-video-and-3d-in-one-place/4316127) — DevForum Announcements, 30 ian. 2026
- [Decal Upload Page Still Mentions 1024x1024 Limit Instead of 4096x4096](https://devforum.roblox.com/t/decal-upload-page-still-mentions-1024x1024-limit-instead-of-4096x4096/4526770) — DevForum Bugs, 19 mar. 2026
- [Decal uploads are still limited to 1024x1024](https://devforum.roblox.com/t/decal-uploads-are-still-limited-to-1024x1024/4710639) — DevForum Bugs, 30 iun. 2026
- [Texture compression and weird pixel grains after importing to studio](https://devforum.roblox.com/t/texture-compression-and-weird-pixel-grains-after-importing-to-studio/2591486) — DevForum Bugs (cu răspuns oficial staff)
- [ResampleMode - New Property for Image GUI Objects](https://devforum.roblox.com/t/resamplemode-new-property-for-image-gui-objects/1418681) — DevForum Announcements, 16 aug. 2021
- [ImageRectOffset/Size does not work with Tile ScaleType](https://devforum.roblox.com/t/imagerectoffsetsize-does-not-work-with-tile-scaletype/3409510) — DevForum Bugs, raportat 24 ian. 2025, răspuns staff 6 feb. 2025
- [Introducing Open Cloud Assets API](https://devforum.roblox.com/t/introducing-open-cloud-assets-api/2245171) — DevForum Announcements, 29 mar. 2023
- [OpenCloud | Assets API (community tutorial)](https://devforum.roblox.com/t/opencloud-assets-api/2298007) — DevForum Community Tutorials, 15 apr. 2023 (sursă secundară pt. exemplul de cod)
- [Convert decal ID to image ID (2025)](https://devforum.roblox.com/t/convert-decal-id-to-image-id-2025/3401001) — DevForum Community Resources
- [Properly using PreloadAsync](https://devforum.roblox.com/t/properly-using-preloadasync/1148953) — DevForum Scripting Support (sursă secundară)
- [Introducing an Improved Appeals Process](https://devforum.roblox.com/t/introducing-an-improved-appeals-process/2690139) — DevForum Announcements, 6 nov. 2023
- [Appeal Your Content or Account Moderation](https://en.help.roblox.com/hc/en-us/articles/360000245263-Appeal-Your-Content-or-Account-Moderation) — Roblox Support, accesat 2026-09-08
- [SpriteClip Sprite Sheet Animation Module (deprecated)](https://devforum.roblox.com/t/spriteclip-sprite-sheet-animation-module/294195) — DevForum Community Resources
- [SpriteClip2 - A Free Versatile Spritesheet Animation Module](https://devforum.roblox.com/t/spriteclip2-a-free-versatile-spritesheet-animation-module/3184892) — DevForum Community Resources, 6 oct. 2024
- [asphalt (GitHub README)](https://raw.githubusercontent.com/jackTabsCode/asphalt/main/README.md) — jackTabsCode/asphalt, accesat 2026-09-08 (tool comunitar, nu oficial Roblox)
- [TexturePacker custom exporter](https://www.codeandweb.com/texturepacker/documentation/custom-exporter) — CodeAndWeb, sursă secundară
- [Aseprite CLI docs](https://www.aseprite.org/docs/cli/) — Aseprite, sursă secundară

## Verificare independenta (2026-09-08)

Verificare efectuată de un agent separat, prin acces direct (fetch/browser) la sursele primare citate în notă, nu prin re-citirea afirmațiilor notei. Toate cele 14 afirmații verificate s-au confirmat ca fiind corecte; nu a fost necesară nicio corecție în corpul notei.

| Afirmatie | Verdict | Valoare corecta | Sursa (URL, data) |
|---|---|---|---|
| Open Cloud `CreateAsset`: imagini < 8000×8000 px, fișier ≤ 20 MB, formate `.png/.jpeg/.bmp/.tga` | CONFIRMAT | Identic: "smaller than 8000x8000 pixels", "file size up to 20 MB" | create.roblox.com/docs/cloud/guides/usage-assets, verificat 2026-09-08 |
| Rate limits Assets API: CreateAsset 120/min, GetAsset 120/min, GetOperation 300/min, List Asset Quotas 60/min (per cheie API / user OAuth) | CONFIRMAT | Identic — verificat direct în paginile interactive "Try It Out" pentru fiecare endpoint (secțiunea "Limits") | create.roblox.com/docs/cloud/reference/features/assets, verificat live în browser 2026-09-08 |
| Scope-uri OAuth2/API key: `asset:read`, `asset:write` | CONFIRMAT | Identic, vizibil în secțiunea "Scopes" a fiecărui endpoint (CreateAsset, GetAsset) | create.roblox.com/docs/cloud/reference/features/assets, verificat live 2026-09-08 |
| "4K Texture Rendering" anunțat 30 ian. 2026: 4096×4096, import posibil până la 8K, clase MeshPart/SurfaceAppearance/Texture/Decal/MaterialVariant | CONFIRMAT | Anunțul există, postat 30 ian. 2026, exact aceste clase și cifre | devforum.roblox.com/t/4k-texture-rendering/4316229, verificat 2026-09-08 |
| Rapoarte de bug (19 mar. 2026 și 30 iun. 2026) despre pagina de upload decal care încă arată/produce limita 1024×1024, fără răspuns oficial de staff | CONFIRMAT (cu nuanță) | Ambele fire există la datele citate, status încă "Open"/fără clarificare oficială. Nuanță: firul din 19 mar. a fost despre textul de avertizare învechit de pe pagină ("mesajul spune 1024 dar limita reală ar trebui să fie 4096"), marcat ulterior "Fixed" de raportor pe 30 iun., care a redirecționat problema efectivă de downscaling către un fir separat — firul din 30 iun. (4710639) e cel care afirmă explicit downscaling real la 1024×1024 și rămâne "Open", fără reply de staff | devforum.roblox.com/t/…/4526770 și devforum.roblox.com/t/…/4710639, verificat live în browser 2026-09-08 |
| Artefacte compresie DXT/BC afectează doar suprafețe 3D (Decal pe Part/MeshPart/SurfaceAppearance); același asset în ImageLabel/ScreenGui nu are artefacte — confirmat de staff Roblox (fnublox) | CONFIRMAT | Citat exact: "both the pixel grains and color shifts are compression artifacts"; raportor confirmă ImageLabel în ScreenGui arată corect | devforum.roblox.com/t/texture-compression-and-weird-pixel-grains-after-importing-to-studio/2591486 (postat 12 sept. 2023), verificat 2026-09-08 |
| Fără taxă documentată oficial pentru upload de decal/imagine privat; taxă 80 Robux (500 pt. emissive mask) doar pt. accesorii avatar publicate pe Marketplace | CONFIRMAT | Pagina de fees confirmă "80 Robux per submission" / "500 Robux" pt. emissive mask, exclusiv pt. avatar items; nicio mențiune de taxă pt. decal/imagine de joc | create.roblox.com/docs/marketplace/marketplace-fees-and-commissions, verificat 2026-09-08 |
| Bulk Import legacy: max 50 fișiere per lot | CONFIRMAT | Citat: "ideal for importing up to 50 files in one batch" | create.roblox.com/docs/projects/assets/manager, verificat 2026-09-08 |
| Moderare: "within a few hours after you import the asset" (documentație oficială) | CONFIRMAT | Identic | create.roblox.com/docs/projects/assets, verificat 2026-09-08 |
| Apel moderare: termen 30 de zile de la acțiune; 6 luni pentru utilizatori UE (DSA) | CONFIRMAT | Identic: "must be submitted within 30 days...", "EU users will have 6 months to appeal" | en.help.roblox.com/hc/en-us/articles/360000245263-Appeal-Your-Content-or-Account-Moderation, verificat live în browser 2026-09-08 |
| Creare Grup Roblox: 100 Robux, taxă unică | CONFIRMAT | Identic: "Creating a group costs 100 Robux", fără taxe recurente | create.roblox.com/docs/projects/groups, verificat 2026-09-08 |
| `ImageRectOffset`/`ImageRectSize` incompatibil cu `ScaleType.Tile`, confirmat "as-designed" de staff Roblox (6 feb. 2025) | CONFIRMAT | Citat exact (DrRanchDressing, 6 feb. 2025): "I believe this is as-designed - spritesheets are not supported for tiled scaletypes..." | devforum.roblox.com/t/imagerectoffsetsize-does-not-work-with-tile-scaletype/3409510, verificat 2026-09-08 |
| SpriteClip2: gratuit, GitHub (nooneisback/luau-spriteclip2), Roblox Marketplace id `111579633111377`, postat 6 oct. 2024, succesor al SpriteClip (deprecat) | CONFIRMAT | Identic pe toate punctele | devforum.roblox.com/t/spriteclip2-a-free-versatile-spritesheet-animation-module/3184892, verificat 2026-09-08 |
| Asphalt (jackTabsCode/asphalt): CLI Rust, urcă prin Open Cloud, generează manifest Luau/TypeScript, instalabil via Cargo/Homebrew/Rokit/Mise | CONFIRMAT | Identic; README menționează suplimentar și Pesde ca metodă de instalare (detaliu în plus, nu contrazice nota) | raw.githubusercontent.com/jackTabsCode/asphalt/main/README.md, verificat 2026-09-08 |

**Concluzie verificare**: nota este solidă — toate afirmațiile cu impact mare asupra deciziilor de proiect (limite de upload, rate limits, costuri, incompatibilități API) s-au confirmat identic în sursele primare curente. Singura nuanță de adăugat: din cele două fire de bug citate pentru "downscale la 1024×1024", doar cel din 30 iun. 2026 (4710639) susține explicit downscaling real al pixelilor; cel din 19 mar. 2026 (4526770) a fost inițial despre un text de avertizare învechit pe pagină și a fost marcat "Fixed" de raportor, care a redirecționat problema de fond către firul separat din iunie. Recomandarea practică a notei (testați empiric înainte de a bugeta pe presupunerea de 4K) rămâne validă și de fapt întărită de acest detaliu.
