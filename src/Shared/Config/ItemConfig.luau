--!strict
-- Catalogul obiectelor pe care le aduce raul [DECIZII D17, RIVERKEEP 3].
--
-- DE CE EXISTA: pana acum raul aducea "common crate", "rare crate" -- sase tiere cu o culoare
-- si nimic altceva. Reparatia scria un contor pe care nu-l citea nimeni, iar dezmembrarea dadea
-- materiale, deci nu exista niciun motiv rational sa repari ceva. Un obiect cu nume schimba
-- ecuatia: reparatia il pune PERMANENT in Index, dezmembrarea il transforma in materiale si il
-- pierde. Fiecare prindere devine o intrebare -- il pastrez sau imi trebuie materialele acum?
--
-- FELIE VERTICALA: 36 de obiecte la calitate finala [CLAUDE.md pasul 4]. Tinta de lansare din
-- D17 e 200. Numarul per tier urmeaza frecventa de prindere: obiectele comune se vad des, deci
-- trebuie sa fie destule ca sa nu se repete din a doua prindere.
--
-- Textele sunt in engleza (jocul e in engleza), comentariile in romana.
-- Culorile stau ca triplete rgb, nu Color3: fisierul e incarcat si de testele Lune, unde
-- tipurile Roblox nu exista.

export type Item = {
    id: string,
    name: string, -- ce scrie in Index si in atelier
    tier: string, -- cheie din RiverConfig.TIERS
    family: string, -- silueta sprite-ului; vezi FAMILIES
    accent: { number }, -- rgb, varianta de culoare peste silueta
    flavour: string, -- o singura propozitie. Vocea asezarii, nu a unui narator.
}

local ItemConfig = {}

-- Siluetele din care se genereaza pictogramele. Un obiect nou nu cere desen nou: alege o
-- familie si o culoare de accent. Asa se ajunge la 200 fara 200 de sprite-uri pictate.
ItemConfig.FAMILIES = { "tool", "vessel", "mech", "cloth", "paper", "trinket", "instrument" }

local function item(t: Item): Item
    return t
end

ItemConfig.ITEMS = {
    -- ---- common (53.7% din prinderi): 10 obiecte ----
    item({
        id = "nail_tin",
        name = "Tin of Bent Nails",
        tier = "common",
        family = "vessel",
        accent = { 150, 124, 96 },
        flavour = "Every one of them straightened at least once already.",
    }),
    item({
        id = "blunt_hatchet",
        name = "Blunt Hatchet",
        tier = "common",
        family = "tool",
        accent = { 128, 132, 138 },
        flavour = "The handle is good. The edge is a suggestion.",
    }),
    item({
        id = "cracked_jug",
        name = "Cracked Jug",
        tier = "common",
        family = "vessel",
        accent = { 176, 136, 104 },
        flavour = "Holds water for about an hour. Long enough, some days.",
    }),
    item({
        id = "sodden_ledger",
        name = "Sodden Ledger",
        tier = "common",
        family = "paper",
        accent = { 196, 182, 150 },
        flavour = "Columns of numbers, all of them someone else's problem.",
    }),
    item({
        id = "one_good_boot",
        name = "One Good Boot",
        tier = "common",
        family = "cloth",
        accent = { 96, 70, 52 },
        flavour = "Left foot. Somebody upstream is limping.",
    }),
    item({
        id = "copper_coil",
        name = "Coil of Copper Wire",
        tier = "common",
        family = "mech",
        accent = { 190, 118, 66 },
        flavour = "Unwound and rewound so often it remembers the shape.",
    }),
    item({
        id = "chipped_plate",
        name = "Chipped Enamel Plate",
        tier = "common",
        family = "vessel",
        accent = { 226, 228, 232 },
        flavour = "White, blue rim, one bad morning.",
    }),
    item({
        id = "painted_float",
        name = "Painted Float",
        tier = "common",
        family = "trinket",
        accent = { 208, 84, 74 },
        flavour = "Red and white, still bobbing when we found it.",
    }),
    item({
        id = "rusted_hinge",
        name = "Rusted Hinge",
        tier = "common",
        family = "mech",
        accent = { 156, 92, 58 },
        flavour = "It belonged to a door that mattered to somebody.",
    }),
    item({
        id = "barrel_staves",
        name = "Bundle of Staves",
        tier = "common",
        family = "tool",
        accent = { 158, 122, 78 },
        flavour = "Barrel parts, waiting to be a barrel again.",
    }),

    -- ---- uncommon (24.8%): 8 obiecte ----
    item({
        id = "brass_padlock",
        name = "Brass Padlock",
        tier = "uncommon",
        family = "mech",
        accent = { 204, 164, 74 },
        flavour = "Locked. No key came down with it.",
    }),
    item({
        id = "surveyors_chain",
        name = "Surveyor's Chain",
        tier = "uncommon",
        family = "tool",
        accent = { 140, 146, 152 },
        flavour = "Sixty-six feet of somebody's property line.",
    }),
    item({
        id = "tin_whistle",
        name = "Tin Whistle",
        tier = "uncommon",
        family = "instrument",
        accent = { 186, 190, 196 },
        flavour = "Two notes are flat. Nobody minds after dark.",
    }),
    item({
        id = "glass_demijohn",
        name = "Glass Demijohn",
        tier = "uncommon",
        family = "vessel",
        accent = { 120, 174, 158 },
        flavour = "Wicker jacket still intact, which is the remarkable part.",
    }),
    item({
        id = "sailors_knife",
        name = "Sailor's Knife",
        tier = "uncommon",
        family = "tool",
        accent = { 168, 172, 178 },
        flavour = "Marlinspike folded in. Initials scratched on the scale.",
    }),
    item({
        id = "wool_blanket",
        name = "Wet Wool Blanket",
        tier = "uncommon",
        family = "cloth",
        accent = { 148, 96, 88 },
        flavour = "Heavy now. Warm once it dries.",
    }),
    item({
        id = "seed_tin",
        name = "Seed Tin",
        tier = "uncommon",
        family = "vessel",
        accent = { 128, 158, 94 },
        flavour = "The labels washed off. Plant them and find out.",
    }),
    item({
        id = "lamp_burner",
        name = "Lamp Burner",
        tier = "uncommon",
        family = "mech",
        accent = { 198, 150, 72 },
        flavour = "The wick is gone. The wheel still turns.",
    }),

    -- ---- rare (12.8%): 7 obiecte ----
    item({
        id = "ships_lantern",
        name = "Ship's Lantern",
        tier = "rare",
        family = "vessel",
        accent = { 226, 186, 96 },
        flavour = "Glass unbroken. That is the rare part.",
    }),
    item({
        id = "brass_sextant",
        name = "Brass Sextant",
        tier = "rare",
        family = "instrument",
        accent = { 212, 168, 78 },
        flavour = "For finding yourself, which makes where it ended up unkind.",
    }),
    item({
        id = "clockwork_movement",
        name = "Clockwork Movement",
        tier = "rare",
        family = "mech",
        accent = { 206, 176, 110 },
        flavour = "Wind it and it still tries.",
    }),
    item({
        id = "printers_tray",
        name = "Printer's Type Tray",
        tier = "rare",
        family = "paper",
        accent = { 118, 110, 104 },
        flavour = "Somebody's newspaper, in pieces, out of order.",
    }),
    item({
        id = "annotated_map",
        name = "Annotated River Map",
        tier = "rare",
        family = "paper",
        accent = { 206, 190, 148 },
        flavour = "Marks upstream that do not match anything we know.",
    }),
    item({
        id = "still_coil",
        name = "Copper Still Coil",
        tier = "rare",
        family = "mech",
        accent = { 196, 112, 60 },
        flavour = "Nobody has asked what it was for.",
    }),
    item({
        id = "silver_locket",
        name = "Silver Locket",
        tier = "rare",
        family = "trinket",
        accent = { 214, 218, 226 },
        flavour = "It opens. There is a face inside. We closed it again.",
    }),

    -- ---- epic (6.1%): 5 obiecte ----
    item({
        id = "music_box",
        name = "Music Box",
        tier = "epic",
        family = "instrument",
        accent = { 158, 104, 176 },
        flavour = "Plays four bars, then seems to think about it.",
    }),
    item({
        id = "surgeons_case",
        name = "Surgeon's Case",
        tier = "epic",
        family = "tool",
        accent = { 92, 76, 96 },
        flavour = "Every instrument in its slot. Every one of them clean.",
    }),
    item({
        id = "brass_telescope",
        name = "Brass Telescope",
        tier = "epic",
        family = "instrument",
        accent = { 218, 172, 84 },
        flavour = "Three draws, all smooth. Somebody loved this.",
    }),
    item({
        id = "ledger_of_debts",
        name = "Ledger of Debts",
        tier = "epic",
        family = "paper",
        accent = { 172, 88, 84 },
        flavour = "Names we recognise. Amounts we do not.",
    }),
    item({
        id = "clockmakers_lathe",
        name = "Clockmaker's Lathe",
        tier = "epic",
        family = "mech",
        accent = { 132, 140, 156 },
        flavour = "Small enough for a table, precise enough to matter.",
    }),

    -- ---- legendary (2.1%): 4 obiecte ----
    item({
        id = "river_bell",
        name = "River Bell",
        tier = "legendary",
        family = "mech",
        accent = { 234, 190, 92 },
        flavour = "Cast for a boat that had a name. The name is filed off.",
    }),
    item({
        id = "orrery_fragment",
        name = "Orrery Fragment",
        tier = "legendary",
        family = "instrument",
        accent = { 224, 182, 104 },
        flavour = "Three brass planets and one missing sun.",
    }),
    item({
        id = "sealed_strongbox",
        name = "Sealed Strongbox",
        tier = "legendary",
        family = "vessel",
        accent = { 108, 92, 78 },
        flavour = "Heavy, and dry inside. Nobody has opened it yet.",
    }),
    item({
        id = "captains_coat",
        name = "Captain's Coat",
        tier = "legendary",
        family = "cloth",
        accent = { 62, 78, 118 },
        flavour = "Braid on the cuffs, river in the pockets.",
    }),

    -- ---- mythic (0.45%): 2 obiecte ----
    item({
        id = "drowned_organ_pipe",
        name = "Drowned Organ Pipe",
        tier = "mythic",
        family = "instrument",
        accent = { 190, 200, 214 },
        flavour = "It still sounds. We only did it the once.",
    }),
    item({
        id = "upstream_charter",
        name = "The Upstream Charter",
        tier = "mythic",
        family = "paper",
        accent = { 222, 206, 158 },
        flavour = "It grants land that appears on no map we own.",
    }),
} :: { Item }

-- Indexuri construite o singura data, la incarcarea modulului. Cautarea liniara peste 200 de
-- obiecte s-ar face de cateva ori pe secunda cand raul aduce ceva.
local byId: { [string]: Item } = {}
local byTier: { [string]: { Item } } = {}
for _, it in ItemConfig.ITEMS do
    byId[it.id] = it
    local bucket = byTier[it.tier]
    if bucket == nil then
        bucket = {}
        byTier[it.tier] = bucket
    end
    table.insert(bucket, it)
end

function ItemConfig.get(id: string): Item?
    return byId[id]
end

function ItemConfig.ofTier(tier: string): { Item }
    return byTier[tier] or {}
end

function ItemConfig.count(): number
    return #ItemConfig.ITEMS
end

-- Alege un obiect din tier dintr-un numar in [0,1). Deterministic: serverul decide prinderea
-- dintr-un seed, iar acumularea offline trebuie sa dea acelasi rezultat la recalculare [D13].
function ItemConfig.pick(tier: string, roll: number): Item?
    local bucket = byTier[tier]
    if bucket == nil or #bucket == 0 then
        return nil
    end
    local i = math.floor(roll * #bucket) + 1
    return bucket[math.clamp(i, 1, #bucket)]
end

-- Alege obiectul pentru un anumit lucru de pe rau. Determinist din id-ul obiectului, deci
-- serverul si clientul ajung la acelasi rezultat FARA sa-si mai trimita nimic: clientul poate
-- scrie numele adevarat in mesajul de prindere, serverul il pune in gramada, si nu exista un al
-- treilea loc unde cele doua sa se contrazica.
function ItemConfig.pickFor(tier: string, seed: number): Item?
    local bucket = byTier[tier]
    if bucket == nil or #bucket == 0 then
        return nil
    end
    -- Knuth: inmultire cu un intreg prim fata de 2^32, apoi restul. Amesteca destul cat id-uri
    -- consecutive de pe rau sa nu dea obiecte consecutive din catalog.
    local h = (seed * 2654435761) % 4294967296
    return bucket[math.floor(h % #bucket) + 1]
end

return ItemConfig
