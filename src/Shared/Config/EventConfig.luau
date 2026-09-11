--!strict
-- Evenimentele povestitorului [RIVERKEEP 6]. Reguli fixe, stabilite cu owner-ul:
--   * NICIODATA dezastre naturale. Nimic nu distruge o cladire si nimeni nu moare.
--   * Orice eveniment cu cost e mic, reversibil si anuntat; jucatorul are mereu ce face dupa.
--   * Textele sunt in engleza (jocul e in engleza), comentariile in romana.
-- Culorile stau ca triplete rgb, nu Color3: fisierul e incarcat si de testele Lune, unde
-- tipurile Roblox nu exista.
export type Effect = {
    materials: number?, -- adaugat (sau scazut, daca e negativ) din stocul de materiale
    food: number?, -- la fel, dar din depozitul de hrana
    need: string?, -- id de nevoie afectata la toti colonistii
    needDelta: number?,
    settlers: number?, -- oameni noi, doar daca sunt paturi libere
    pileItems: number?, -- obiecte aruncate direct in gramada de la atelier
    rerollJob: boolean?, -- un colonist isi schimba meseria
}
export type Event = {
    id: string,
    title: string,
    body: string,
    tone: string, -- "good" | "cost" | "neutral": doar culoarea din interfata
    weight: number,
    requires: string?, -- "beds" | "firepit" | "settlers" | nil
    effect: Effect,
}

local EventConfig = {
    -- Cat de des se intampla ceva. Intervalul se alege aleator intre cele doua capete.
    MIN_SECONDS = 150,
    MAX_SECONDS = 260,
    -- Un eveniment nu se repeta decat dupa ce au trecut atatea altele
    REPEAT_GAP = 4,
    -- Cate evenimente tine jurnalul pentru tabloul coloniei
    LOG_SIZE = 12,
    TONES = {
        good = { 150, 210, 140 },
        cost = { 226, 170, 110 },
        neutral = { 165, 190, 215 },
    },
}

local function event(t: Event): Event
    return t
end

EventConfig.EVENTS = {
    event({
        id = "trader",
        title = "A trader ties up at the landing",
        body = "They leave a crate of salvage in exchange for directions downriver.",
        tone = "good",
        weight = 14,
        effect = { materials = 18 },
    }),
    event({
        id = "driftwood_haul",
        title = "The river runs high",
        body = "Good timber comes down with it. The builders are pleased.",
        tone = "good",
        weight = 16,
        effect = { materials = 11 },
    }),
    event({
        id = "wanderers",
        title = "A family asks to stay the season",
        body = "They have tools and they are willing to work.",
        tone = "good",
        weight = 10,
        requires = "beds",
        effect = { settlers = 2 },
    }),
    event({
        id = "fiddle",
        title = "Someone unpacked a fiddle",
        body = "The evening went long and nobody minded.",
        tone = "good",
        weight = 12,
        requires = "settlers",
        effect = { need = "content", needDelta = 16 },
    }),
    event({
        id = "warm_evening",
        title = "A warm evening around the fire",
        body = "Stories, mostly untrue, and everyone slept better for it.",
        tone = "good",
        weight = 10,
        requires = "firepit",
        effect = { need = "rested", needDelta = 14 },
    }),
    event({
        id = "smoked_surplus",
        title = "A good drying week",
        body = "Racks full, nothing spoiled. The stores are heavier than usual.",
        tone = "good",
        weight = 11,
        effect = { food = 25 },
    }),
    event({
        id = "spoiled_stores",
        title = "Part of the stores turned",
        body = "Damp got into a corner of the larder. Not a disaster, but it stings.",
        tone = "cost",
        weight = 6,
        effect = { food = -14 },
    }),
    event({
        id = "good_catch",
        title = "The nets came up full",
        body = "More than the pile can sort in a day.",
        tone = "good",
        weight = 12,
        effect = { pileItems = 3 },
    }),
    event({
        id = "shared_pot",
        title = "One big pot, one long table",
        body = "Nobody remembers whose idea it was.",
        tone = "good",
        weight = 9,
        requires = "settlers",
        effect = { need = "fed", needDelta = 15 },
    }),
    event({
        id = "apprentice",
        title = "An apprentice changed trade",
        body = "They watched someone work all winter and decided to try it.",
        tone = "neutral",
        weight = 8,
        requires = "settlers",
        effect = { rerollJob = true },
    }),
    event({
        id = "worn_tools",
        title = "Tools are wearing thin",
        body = "Handles split, blades dull. Some stock goes into fixing them.",
        tone = "cost",
        weight = 7,
        effect = { materials = -7 },
    }),
    event({
        id = "restless_nights",
        title = "Restless nights",
        body = "Something kept the settlement awake. Nobody agrees on what.",
        tone = "cost",
        weight = 6,
        requires = "settlers",
        effect = { need = "rested", needDelta = -12 },
    }),
    event({
        id = "lean_stores",
        title = "Stores ran lean",
        body = "Portions were smaller this week. It will pass.",
        tone = "cost",
        weight = 6,
        requires = "settlers",
        effect = { need = "fed", needDelta = -12 },
    }),
}

function EventConfig.get(id: string): Event?
    for _, e in EventConfig.EVENTS do
        if e.id == id then
            return e
        end
    end
    return nil
end

return EventConfig
