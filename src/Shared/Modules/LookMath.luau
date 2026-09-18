--!strict
-- [D61] INFATISAREA JUCATORULUI, aleasa la croitoreasa din balci. Modul pur.
--
-- Pana la D61 jucatorul avea un singur chip, batut in cuie in patru locuri (SceneArt.MakeCharacter si trei
-- previzualizari): corpul "b", parul "long", o piele si un saten. Oamenii din sat aveau deja tot ce trebuie -- doua
-- siluete, patru coafuri, sase culori de piele si sase de par (SettlerConfig), desenate pe straturi si colorate cu tint
-- [D44] -- doar ca nimeni nu le putea alege. Aici infatisarea e patru INDICI in acele palete: profilul tine numere mici,
-- nu culori, iar o paleta reglata mai tarziu se vede la toata lumea.
--
-- Infatisarea implicita e EXACT cea de dinainte, ca nimeni sa nu se trezeasca schimbat.
local SettlerConfig =
    require(script and script.Parent.Parent.Config.SettlerConfig or "../Config/SettlerConfig")

local LookMath = {}

export type Look = { body: number, hair: number, skin: number, hairColor: number }
-- Ce deseneaza UI/PersonView si SceneArt: numele foilor si culorile
export type Resolved = { body: string, hair: string, skin: { number }, hairColor: { number } }

LookMath.FIELDS = { "body", "hair", "skin", "hairColor" }

local PALETTES: { [string]: { any } } = {
    body = SettlerConfig.BUILDS,
    hair = SettlerConfig.HAIR_STYLES,
    skin = SettlerConfig.SKIN,
    hairColor = SettlerConfig.HAIR_COLORS,
}

local function indexOf(list: { any }, want: any): number
    for i, v in list do
        if v == want then
            return i
        end
    end
    return 1
end

-- corpul "b", parul "long", pielea a doua, satenul: ce desena SceneArt.MakeCharacter pana la D61
LookMath.DEFAULT = {
    body = indexOf(SettlerConfig.BUILDS, "b"),
    hair = indexOf(SettlerConfig.HAIR_STYLES, "long"),
    skin = 2,
    hairColor = 2,
} :: Look

-- Cate variante are un camp (pentru sagetile din panou).
function LookMath.count(field: string): number
    local palette = PALETTES[field]
    return if palette ~= nil then #palette else 0
end

local function validIndex(field: string, value: unknown): boolean
    if typeof(value) ~= "number" then
        return false
    end
    local n = value :: number
    return n == n and n % 1 == 0 and n >= 1 and n <= LookMath.count(field)
end

-- O infatisare primita de la client (sau citita dintr-un profil vechi) e buna doar daca are toate cele patru campuri,
-- fiecare un intreg din paleta lui.
function LookMath.valid(look: unknown): boolean
    if typeof(look) ~= "table" then
        return false
    end
    for _, field in LookMath.FIELDS do
        if not validIndex(field, (look :: any)[field]) then
            return false
        end
    end
    return true
end

-- Infatisarea curata: ce e valid ramane, restul cade pe implicit. Intoarce mereu un tabel NOU, cu exact patru campuri.
function LookMath.clean(look: unknown): Look
    local out = table.clone(LookMath.DEFAULT)
    if typeof(look) == "table" then
        for _, field in LookMath.FIELDS do
            local value = (look :: any)[field]
            if validIndex(field, value) then
                (out :: any)[field] = value
            end
        end
    end
    return out
end

-- Urmatoarea (sau precedenta) varianta a unui camp, in cerc.
function LookMath.step(look: Look, field: string, direction: number): Look
    local out = LookMath.clean(look)
    local n = LookMath.count(field)
    if n > 0 then
        local current = (out :: any)[field] :: number
        (out :: any)[field] = (current - 1 + (if direction < 0 then -1 else 1)) % n + 1
    end
    return out
end

function LookMath.resolve(look: unknown): Resolved
    local l = LookMath.clean(look)
    return {
        body = SettlerConfig.BUILDS[l.body],
        hair = SettlerConfig.HAIR_STYLES[l.hair],
        skin = SettlerConfig.SKIN[l.skin],
        hairColor = SettlerConfig.HAIR_COLORS[l.hairColor],
    }
end

function LookMath.same(a: Look, b: Look): boolean
    for _, field in LookMath.FIELDS do
        if (a :: any)[field] ~= (b :: any)[field] then
            return false
        end
    end
    return true
end

return LookMath
