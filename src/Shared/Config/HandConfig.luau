--!strict
-- Numele si infatisarea angajatilor [F1, aria I]. Bazinul de nume e cel al coloniei (SettlerConfig)
-- -- jucatorul citeste acelasi soi de nume peste tot -- dar aici nu exista un rng cu stare: server-ul
-- da un SINGUR numar (seed, vezi HandService) si acelasi seed trebuie sa dea mereu acelasi angajat,
-- ca sa nu fie nevoie sa salvam fiecare camp separat inainte sa il calculam o singura data.
local SettlerConfig = require(script and script.Parent.SettlerConfig or "./SettlerConfig")
local Prng = require(script and script.Parent.Parent.Modules.Prng or "../Modules/Prng")

export type Identity = {
    body: string, -- "a" | "b"
    hair: string, -- "short" | "long" | "bun" | "bald"
    skin: { number },
    hairColor: { number },
}

local HandConfig = {}

-- Fiecare rol poarta tinuta rolului lui, nu una aleasa -- meseria se citeste dintr-o privire [D44].
-- Cate o tinuta pe meserie [D49]: meseria se citeste din haine.
HandConfig.ROLE_OUTFIT = {
    collector = "Fisher", -- sta la plase, ca pescarul
    porter = "Crafter",
    sawyer = "Builder", -- omul de la gater [D48]: haine de lucru, ca sa se citeasca meseria
    hauler = "Gardener",
    trader = "Innkeeper", -- cine tine taverna poarta sort, nu cizme de rau
    -- [D56] linia fierului: silueta palariei e a meseriei-pereche de la lemn, culoarea a lor
    scrapCollector = "Scrapper",
    scrapPorter = "Carter",
    smelter = "Smith", -- sortul de piele: el e cel care lucreaza la foc
    ironHauler = "Ironmonger",
    -- [D65] Era 2: tinutele oamenilor Morii (scripts/art/settlers.py). Cat foaia unei tinute nu e urcata, clientul o
    -- deseneaza cu a meseriei-pereche din Era 1 (OUTFIT_LOOKS_LIKE, mai jos).
    millCollector = "Gleaner",
    millPorter = "Drayman",
    founder = "Founder",
    partsHauler = "Wheelwright",
    merchant = "Merchant",
    oreCollector = "Prospector",
    orePorter = "Mucker",
    coppersmith = "Coppersmith",
    copperHauler = "Teamster",
    -- [D67] Era 3: tinutele oamenilor Wire Works. Pana la foile lor, clientul le deseneaza cu a meseriei-pereche din Moara.
    worksCollector = "Dredger",
    worksPorter = "Barrowman",
    wiredrawer = "Wiredrawer",
    coilHauler = "Coiler",
    clerk = "Clerk",
    batteryCollector = "Lineman",
    batteryPorter = "Hodman",
    electrician = "Electrician",
    powerHauler = "Freighter",
}

-- [D65] DESENUL DE IMPRUMUT al unei tinute inca neurcate: tinuta meseriei-pereche din Era 1. Il intreaba doar cine
-- deseneaza (PersonView), si doar cand foaia lipseste; regula "rolul isi poarta tinuta" ramane ROLE_OUTFIT.
HandConfig.OUTFIT_LOOKS_LIKE = {
    Gleaner = "Fisher",
    Drayman = "Crafter",
    Founder = "Builder",
    Wheelwright = "Gardener",
    Merchant = "Innkeeper",
    Prospector = "Scrapper",
    Mucker = "Carter",
    Coppersmith = "Smith",
    Teamster = "Ironmonger",
    -- [D67] Era 3 -> perechea din Moara (care are foaia ei)
    Dredger = "Gleaner",
    Barrowman = "Drayman",
    Wiredrawer = "Founder",
    Coiler = "Wheelwright",
    Clerk = "Merchant",
    Lineman = "Prospector",
    Hodman = "Mucker",
    Electrician = "Coppersmith",
    Freighter = "Teamster",
} :: { [string]: string }

-- [D56, D65, D67] Meseriile care lucreaza cu ciocanul in mana langa atelierul lor (randul "work" e pe fiecare foaie de
-- tinuta), si incotro se uita cat lucreaza. Omul forjei, al cuptorului de cupru si al Power House sta sub dreapta
-- cladirii (SMELTER_STAND); al turnatoriei si al Wire Works sta la dreapta ei (SAWYER_STAND), deci se uita spre stanga.
-- Bat doar cat atelierul chiar lucreaza. Sawyer-ul lipseste intentionat: el sta la gater, nu la o nicovala.
HandConfig.WORKING_POSE = {
    smelter = "right",
    coppersmith = "right",
    electrician = "right",
    founder = "left",
    wiredrawer = "left",
    -- [D70] Era 4: propuse, ca in Erele 2-3 (prima linie spre stanga, a doua spre dreapta); harta barajului le poate muta
    switchman = "left",
    cablemaker = "right",
    relayKeeper = "left",
    crystalsmith = "right",
} :: { [string]: string }

-- [D50] Clientii tavernei: tinute pe care nu le poarta nicio meserie (fara palarie, prun si ardezie),
-- ca un client sa nu para un om al tau care sta degeaba [D44]. Testul HandConfig le tine separate.
HandConfig.CUSTOMER_OUTFITS = { "Townsfolk", "Traveler" }

-- Amestec Knuth (acelasi ca ItemConfig.pickFor): xorshift32 (Prng) nu amesteca bine o samanta MICA
-- chiar de la prima tragere (primii biti raman aproape de 0), iar seed-urile reale de aici pot fi
-- mici -- userId-uri istorice Roblox, sau index de platforma la un userId mic. Fara asta, angajatii
-- unor jucatori diferiti ar iesi identici.
local function mixSeed(seed: number): number
    return (math.floor(seed) * 2654435761) % 4294967296
end

-- Infatisarea (corp, par, culori), determinista din seed. Outfit-ul NU e aici -- vine din rol
-- (ROLE_OUTFIT), separat, ca acelasi seed sa poata fi refolosit daca un rol se schimba vreodata.
function HandConfig.appearanceFor(seed: number): Identity
    local rng = Prng.new(mixSeed(seed))
    return {
        body = SettlerConfig.BUILDS[rng:nextInteger(1, #SettlerConfig.BUILDS)],
        hair = SettlerConfig.HAIR_STYLES[rng:nextInteger(1, #SettlerConfig.HAIR_STYLES)],
        skin = SettlerConfig.SKIN[rng:nextInteger(1, #SettlerConfig.SKIN)],
        hairColor = SettlerConfig.HAIR_COLORS[rng:nextInteger(1, #SettlerConfig.HAIR_COLORS)],
    }
end

-- Doar prenumele, din acelasi bazin ca satenii -- un angajat se recunoaste dupa prenume si rol,
-- nu are nevoie de nume de familie. +1 fata de appearanceFor: nu vrem ca acelasi numar amestecat
-- sa decida SI corpul SI numele (le-ar cupla, doi angajati cu acelasi corp ar avea mereu acelasi nume).
function HandConfig.nameFor(seed: number): string
    local rng = Prng.new(mixSeed(seed + 1))
    return SettlerConfig.FIRST[rng:nextInteger(1, #SettlerConfig.FIRST)]
end

-- [D65] Cu Moara sunt 18 meserii, cate doi oameni: bazinul de prenume al satenilor nu mai ajunge, iar in jocul de proba
-- au iesit doi "Perrin" si doi "Brann" in acelasi sat. Prenume in plus, DOAR pentru oameni (lista satenilor nu se
-- atinge: lungimea ei decide ce iese din fiecare samanta).
HandConfig.MORE_NAMES = {
    "Alder",
    "Bryn",
    "Cael",
    "Doran",
    "Edda",
    "Finch",
    "Garrick",
    "Hollis",
    "Ilse",
    "Joss",
    "Kestrel",
    "Linnet",
    "Marek",
    "Nessa",
    "Orla",
    "Pike",
    "Quill",
    "Rowan",
    "Tamsin",
    "Ulric",
    "Vesna",
    "Wilf",
    "Yara",
    "Zeph",
    -- [D67] cu Era 3 sunt 27 de meserii, cate doi oameni: 54 de prenume. Adaugate la coada, ca sa nu mute nimic din
    -- cele alese pana acum.
    "Arlo",
    "Briar",
    "Dace",
    "Elm",
    "Faye",
    "Greer",
    "Hale",
    "Isolde",
    "Jory",
    "Kit",
    "Lark",
    "Moss",
    "Nia",
    "Odo",
    "Pell",
    "Rook",
    "Sorrel",
    "Tully",
    "Wynn",
    "Zinnia",
}

-- Prenumele unui om nou, ocolindu-le pe cele deja purtate in sat (`used`). Acelasi prenume ca `nameFor` cat e liber
-- (deci satele de pana acum isi pastreaza oamenii); altfel urmatorul liber din bazin, in ordine, pornind de la el.
function HandConfig.nameAvoiding(seed: number, used: { [string]: boolean }): string
    local first = HandConfig.nameFor(seed)
    if not used[first] then
        return first
    end
    local pool = table.clone(SettlerConfig.FIRST)
    table.move(HandConfig.MORE_NAMES, 1, #HandConfig.MORE_NAMES, #pool + 1, pool)
    local start = table.find(pool, first) or 1
    for step = 1, #pool do
        local candidate = pool[(start - 1 + step) % #pool + 1]
        if not used[candidate] then
            return candidate
        end
    end
    return first -- mai multi oameni decat prenume: se repeta, nu crapa
end

return HandConfig
