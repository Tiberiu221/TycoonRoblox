--!strict
-- [D61, partea 2] COLTUL CU ROBUX: ce se vinde pe Robux si cu ce ID, pe univers.
--
-- Regulile (D20, D46, nota 41): banii cumpara VITEZA, SPATIU, ASPECT. Niciodata noroc, lazi, perle, continut doar pentru
-- platitori sau ceva cu cronometru de presiune. Niciun pass nu se pierde si nimic platit nu se reseteaza.
--
-- PRETURILE NU STAU AICI. Jocul afiseaza pretul citit de la Roblox (MarketplaceService), deci textul nu poate minti
-- [D40] si owner-ul il poate schimba oricand din Creator Hub. `suggested` e doar punctul de pornire din nota 41,
-- folosit cand se creeaza lucrul; nu se afiseaza nicaieri.
--
-- ID 0 = lucrul inca nu exista pe universul asta: randul lui scrie `Opens soon` si nu se poate cumpara.
local MonetizationConfig = {}

export type Item = {
    key: string, -- cheia din profil (Purchases.passes) si din remote-uri
    kind: string, -- "pass" (o data, pentru totdeauna) | "product" (de cate ori vrei)
    name: string,
    blurb: string, -- o fraza: ce face, exact
    icon: string, -- cheia din Assets.icons: pictograma de rezerva, deja urcata
    art: string, -- [D63] pictograma PROPRIE a ofertei (Assets.icons.shop_<cheie>); cat nu e urcata, se vede `icon`
    suggested: number, -- Robux, nota 41; doar pentru crearea lucrului
    -- unde se vinde: "shop" = panoul Shop (sat si balci); "village" = doar in sat (are nevoie de venitul tau de acum);
    -- "welcome" = doar pe fereastra "Welcome back"
    where: string,
}

MonetizationConfig.ITEMS = {
    {
        key = "flow2x",
        kind = "pass",
        name = "2x Flow",
        blurb = "Your village earns twice as many coins. Forever.",
        icon = "coin",
        art = "shop_flow2x",
        suggested = 799,
        where = "shop",
    },
    {
        key = "swift",
        kind = "pass",
        name = "Swift Boots",
        blurb = "Walk and run 1.5x faster, in the village and at the fair.",
        icon = "speed",
        art = "shop_swift",
        suggested = 149,
        where = "shop",
    },
    {
        key = "nights",
        kind = "pass",
        name = "Long Nights",
        blurb = "While you're away, your village works for up to 16 hours, not 8.", -- [D66]
        icon = "idle",
        art = "shop_nights",
        suggested = 349,
        where = "shop",
    },
    {
        key = "supporter",
        kind = "pass",
        name = "Supporter",
        blurb = "Looks only: the Supporter title, a golden name and an outfit.",
        icon = "people",
        art = "shop_supporter",
        suggested = 199,
        where = "shop",
    },
    {
        key = "hour",
        kind = "product",
        name = "One Hour of Flow",
        blurb = "Coins worth one hour of your income right now.",
        icon = "clock",
        art = "shop_hour",
        suggested = 99,
        where = "village",
    },
    {
        key = "welcome2x",
        kind = "product",
        name = "Welcome Back x2",
        blurb = "Doubles what your village earned while you were away.",
        icon = "coin",
        art = "shop_welcome2x",
        suggested = 79,
        where = "welcome",
    },
} :: { Item }

MonetizationConfig.byKey = {} :: { [string]: Item }
for _, item in MonetizationConfig.ITEMS do
    MonetizationConfig.byKey[item.key] = item
end

-- ID-urile de pe Roblox, pe univers (game.GameId), ca PlaceConfig: staging si productia au lucrurile lor. 0 = necreat.
MonetizationConfig.IDS = {
    -- staging: "Driftycoon (Staging)"
    [10765888327] = {
        flow2x = 1987136675,
        swift = 1981917327,
        nights = 1986296934,
        supporter = 1985151161,
        hour = 3713592670,
        welcome2x = 3713592681,
    },
    -- productia: "Driftycoon"
    [10766553412] = { flow2x = 0, swift = 0, nights = 0, supporter = 0, hour = 0, welcome2x = 0 },
} :: { [number]: { [string]: number } }

-- ID-ul unui lucru pe universul asta; 0 cand nu exista (inca), inclusiv intr-un univers necunoscut (Studio, fisier local).
function MonetizationConfig.idOf(gameId: number, key: string): number
    local ids = MonetizationConfig.IDS[gameId]
    local id = if ids ~= nil then ids[key] else nil
    return if typeof(id) == "number" and id > 0 then id else 0
end

-- Cheia lucrului cu ID-ul asta pe universul asta (chitanta vine cu ProductId, pass-ul cu gamePassId).
function MonetizationConfig.keyOf(gameId: number, kind: string, id: number): string?
    if id <= 0 then
        return nil
    end
    local ids = MonetizationConfig.IDS[gameId]
    if ids == nil then
        return nil
    end
    for key, value in ids do
        local item = MonetizationConfig.byKey[key]
        if value == id and item ~= nil and item.kind == kind then
            return key
        end
    end
    return nil
end

return MonetizationConfig
