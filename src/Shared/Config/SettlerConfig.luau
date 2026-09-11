--!strict
-- Parametri de colonist, replicati (clientul ii foloseste la randare) [RIVERKEEP 4.1]
local SettlerConfig = {
    -- Se incepe cu UN singur om. Colonia trebuie sa creasca din el, nu sa fie primita gata
    -- facuta: primul lucru pe care il faci trebuie sa se si vada.
    START_COUNT = 1,
    HARD_CAP = 80, -- plafon dur pentru testul de stres; jocul real tinteste ~40 [RIVERKEEP 4.1]
    SPEED_MIN = 90, -- pixeli logici/secunda
    SPEED_MAX = 130,
    IDLE_MIN = 1.5,
    IDLE_MAX = 5.0,
    PATH_BUDGET = 900,
    WANDER_RADIUS_CELLS = 7, -- se plimba in jurul locului lui, nu prin toata harta
    -- meseria decide unde isi petrece timpul cand n-are treaba
    -- unde isi petrece timpul, dupa tipul de cladire (nu dupa un id fix)
    HOME_BY_JOB = {
        Fisher = "river",
        Gardener = "farm",
        Crafter = "work",
        Builder = "work",
        Innkeeper = "joy",
    }, -- celule expandate maxim per cautare A*
    WIDTH = 40,
    HEIGHT = 60,
    JOBS = { "Fisher", "Crafter", "Builder", "Gardener", "Innkeeper" },
    -- Ce face fiecare meserie, in cuvintele jucatorului. Pasul de tutorial cere "alege o meserie",
    -- iar panoul arata cinci butoane cu cate o LITERA: nimeni nu poate sti ce inseamna F, C, B,
    -- G, I. Textele de mai jos descriu ce face codul cu adevarat, nu ce ne-ar placea sa faca --
    -- daca se schimba o regula, se schimba si aici.
    JOB_INFO = {
        Fisher = "Pulls food from the river. Only three can work the good spots at once.",
        Crafter = "Works the workshop bench and speeds up whatever is being repaired.",
        Builder = "Raises what you have placed. With no Builder, whoever is free steps in.",
        Gardener = "Grows food in gardens — steadier than fishing, but you must build one.",
        Innkeeper = "Keeps spirits up at the firepit and hall. One covers about eight people.",
    },
    -- Cele 3 stari [RIVERKEEP 4.1]. Scad in puncte pe minut real; nimeni nu moare.
    NEEDS = {
        { id = "fed", label = "Fed", decayPerMinute = 1.7, kind = "food" },
        { id = "rested", label = "Rested", decayPerMinute = 1.1, kind = "rest" },
        { id = "content", label = "Content", decayPerMinute = 0.8, kind = "joy" },
    },
    NEED_MAX = 100,
    NEED_SEEK = 45, -- sub pragul asta, colonistul lasa munca si isi rezolva nevoia
    NEED_WARN = 25, -- sub pragul asta apare avertisment vizibil deasupra capului
    NEED_LEAVE = 0, -- la 0 sustinut, colonistul isi face bagajul si pleaca pe apa
    LEAVE_GRACE_SECONDS = 240, -- cat sta la 0 inainte sa plece: mereu ai timp sa reactionezi
    -- Cat merge spre debarcader dupa ce s-a hotarat. Fara asta, starea "leaving" era stearsa in
    -- ACELASI tick de 0.25s in care aparea: clientul n-o vedea niciodata, eticheta "leaving" din
    -- panou era cod mort, iar omul disparea cu un mesaj DUPA fapt. Regula owner-ului e ca nimic
    -- nu se pierde fara sansa de reactie; asta e fereastra in care inca poti face ceva.
    LEAVE_WALK_SECONDS = 12,
    -- Economia hranei [RIVERKEEP 5]. Cifrele sunt alese ca la 12 oameni sa ai surplus si la
    -- 40 sa nu-ti mai ajunga fara sa muti oameni pe productie: acolo incepe administrarea.
    -- Raul are un numar LIMITAT de locuri bune de pescuit. Fara plafon, pescuitul scala odata
    -- cu populatia (meseriile se impart pe rand), deci raportul productie/consum ramanea acelasi
    -- la orice marime si nu exista nicio presiune: un pescar hranea 18 oameni, la 5 oameni sau
    -- la 60. Plafonul e ce face gradinile necesare.
    FISH_SPOTS = 3,
    FISH_SECONDS = 45, -- o repriza de pescuit
    FISH_FOOD = 1, -- hrana per repriza de pescuit
    FARM_SECONDS = 24, -- o repriza de munca in gradina
    GARDEN_FOOD = 1, -- hrana per repriza in gradina
    -- Cat din timp petrece efectiv un colonist la post: restul se duce pe drum, mancat si odihna.
    -- Fara factorul asta, orice socoteala de productie iese de doua ori mai optimista decat
    -- realitatea si jucatorul ramane fara hrana exact cand credea ca sta bine.
    WORK_UPTIME = 0.55,
    MEAL_FOOD_COST = 3, -- cat costa o masa la bucatarie
    -- Hangiul imparte acelasi bine la toata colonia, nu il da fiecaruia intreg. Inainte, +2 la
    -- FIECARE colonist insemna ca un singur hangiu tinea moralul a oricati oameni.
    INNKEEPER_CONTENT = 2,
    INNKEEPER_COVERS = 8, -- cati oameni acopera un hangiu la putere intreaga
    RESTORE_PER_SECOND = 14, -- cat de repede se reface o nevoie in cladirea potrivita
    WORK_SECONDS = 8, -- o unitate de munca la atelier
    WORK_YIELD_PROGRESS = 12,
    BUILD_YIELD = 10, -- progres de constructie per unitate de munca
    ARRIVAL_INTERVAL = 45, -- secunde intre doua barci cu oameni noi, daca e loc
    -- PRIMA sosire vine mai repede. Pasul de tutorial spune "uita-te la apa", iar la 45 de
    -- secunde jucatorul se uita la o apa pe care nu se intampla nimic si crede ca s-a blocat.
    -- Se aplica o singura data, cat timp n-a mai venit nimeni pe apa.
    FIRST_ARRIVAL_INTERVAL = 12, -- cat progres de reparatie da o unitate de munca
    -- variatie vizuala fara sprite-uri noi: se coloreaza acelasi sprite
    -- NICIO nuanta nu e alb curat: jucatorul e singurul desenat netonat, si asa se deosebeste
    -- de colonisti dintr-o privire. Inainte, TINTS[1] era {255,255,255} -- adica un colonist
    -- din sase arata exact ca jucatorul, iar in poza nu puteai spune care esti tu.
    -- Se PASTREAZA sase intrari: indicele e salvat per colonist, iar scoaterea uneia ar face
    -- ca profilele vechi sa ceara o nuanta care nu mai exista.
    TINTS = {
        { 232, 240, 228 },
        { 210, 235, 255 },
        { 255, 225, 205 },
        { 220, 255, 220 },
        { 255, 215, 235 },
        { 235, 225, 180 },
    },
    -- INFATISAREA, in trei straturi [D44]. Identitatea variaza liber, meseria ramane constanta:
    -- doi pescari cu gen, piele si par complet diferite poarta aceeasi palarie si aceeasi tinuta.
    -- Asa meseria se citeste dintr-o privire, dar nimeni nu arata ca altcineva.
    --   1. corp   -> BUILDS (silueta) + SKIN (tint)
    --   2. par    -> HAIR_STYLES (forma) + HAIR_COLORS (tint)
    --   3. tinuta -> data de meserie, culori fixe; ASTA e elementul comun
    BUILDS = { "a", "b" }, -- doua siluete; se citesc a gen diferit prin umeri/solduri, nu prin culoare
    HAIR_STYLES = { "short", "long", "bun", "bald" },
    SKIN = {
        { 246, 214, 184 },
        { 231, 188, 150 },
        { 205, 154, 112 },
        { 171, 120, 82 },
        { 128, 87, 60 },
        { 92, 62, 44 },
    },
    HAIR_COLORS = {
        { 46, 36, 32 }, -- negru
        { 92, 62, 40 }, -- saten
        { 148, 104, 58 }, -- castaniu
        { 206, 170, 96 }, -- blond
        { 166, 82, 48 }, -- roscat
        { 178, 178, 172 }, -- carunt
    },
    -- Trasaturi: fiecare colonist primeste 2. Efectele sunt multiplicatori mici, niciodata blocante.
    -- speed = viteza de mers, work = randament la munca, decay = cat de repede ii scad nevoile.
    TRAITS = {
        { id = "quick", label = "Quick", speed = 1.25, work = 1.0, decay = 1.0 },
        { id = "slow", label = "Slow", speed = 0.8, work = 1.0, decay = 0.9 },
        { id = "tireless", label = "Tireless", speed = 1.0, work = 1.0, decay = 0.75 },
        { id = "frail", label = "Frail", speed = 0.95, work = 1.0, decay = 1.3 },
        { id = "handy", label = "Handy", speed = 1.0, work = 1.35, decay = 1.0 },
        { id = "clumsy", label = "Clumsy", speed = 1.0, work = 0.75, decay = 1.0 },
        { id = "cheerful", label = "Cheerful", speed = 1.0, work = 1.05, decay = 0.85 },
        { id = "gloomy", label = "Gloomy", speed = 1.0, work = 0.95, decay = 1.15 },
        { id = "hearty", label = "Hearty", speed = 1.0, work = 1.0, decay = 0.85 },
        { id = "hungry", label = "Big appetite", speed = 1.05, work = 1.1, decay = 1.25 },
        { id = "earlybird", label = "Early riser", speed = 1.1, work = 1.05, decay = 1.0 },
        { id = "dreamer", label = "Dreamer", speed = 0.9, work = 0.9, decay = 0.8 },
        { id = "stubborn", label = "Stubborn", speed = 0.95, work = 1.2, decay = 1.1 },
        { id = "gentle", label = "Gentle", speed = 1.0, work = 1.0, decay = 0.95 },
    },
    FIRST = {
        "Mira",
        "Tobin",
        "Sable",
        "Wren",
        "Odis",
        "Perrin",
        "Lys",
        "Corin",
        "Hazel",
        "Brann",
        "Nell",
        "Osric",
        "Fen",
        "Dara",
        "Kell",
        "Ivo",
    },
    LAST = {
        "Reed",
        "Marsh",
        "Stone",
        "Fisher",
        "Bright",
        "Vale",
        "Thorn",
        "Quill",
    },
}

function SettlerConfig.randomName(rng: { nextInteger: (any, number, number) -> number }): string
    local first = SettlerConfig.FIRST[rng:nextInteger(1, #SettlerConfig.FIRST)]
    local last = SettlerConfig.LAST[rng:nextInteger(1, #SettlerConfig.LAST)]
    return `{first} {last}`
end

return SettlerConfig
