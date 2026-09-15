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
}

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

return HandConfig
