--!strict
-- [D60] PACHETUL CU OAMENII DIN BALCI: 24 de oameni intr-un UnreliableRemoteEvent, a carui limita e ~1000 de octeti.
-- Ca tabel Luau (id, x, y, directie, mers) ar trece de ea; ca buffer, 6 octeti de om = 144 pentru 24.
--   slot u8 | x u16 | y u16 | directia (2 biti) + mers (bitul 3) u8
-- Slotul e numarul omului pe server (lista `People` spune cine e); coordonatele sunt intregi, harta are sub 65536.
-- Modul pur: acelasi cod scrie pe server si citeste pe client, iar testul verifica drumul dus-intors.
local CrowdCodec = {}

CrowdCodec.BYTES = 6
CrowdCodec.FACINGS = { "down", "up", "left", "right" }
local indexOf: { [string]: number } = {}
for i, f in CrowdCodec.FACINGS do
    indexOf[f] = i - 1
end

export type Entry = { slot: number, x: number, y: number, facing: string, moving: boolean }

local function u16(v: number): number
    return math.clamp(math.round(v), 0, 65535)
end

function CrowdCodec.encode(entries: { Entry }): buffer
    local buf = buffer.create(#entries * CrowdCodec.BYTES)
    for i, e in entries do
        local o = (i - 1) * CrowdCodec.BYTES
        buffer.writeu8(buf, o, math.clamp(e.slot, 0, 255))
        buffer.writeu16(buf, o + 1, u16(e.x))
        buffer.writeu16(buf, o + 3, u16(e.y))
        local flags = (indexOf[e.facing] or 0) + (if e.moving then 4 else 0)
        buffer.writeu8(buf, o + 5, flags)
    end
    return buf
end

-- Un pachet stricat (lungime gresita, alt tip) da o lista goala, nu o eroare.
function CrowdCodec.decode(value: unknown): { Entry }
    local out: { Entry } = {}
    if typeof(value) ~= "buffer" then
        return out
    end
    local buf = value :: buffer
    local len = buffer.len(buf)
    if len % CrowdCodec.BYTES ~= 0 then
        return out
    end
    for o = 0, len - CrowdCodec.BYTES, CrowdCodec.BYTES do
        local flags = buffer.readu8(buf, o + 5)
        table.insert(out, {
            slot = buffer.readu8(buf, o),
            x = buffer.readu16(buf, o + 1),
            y = buffer.readu16(buf, o + 3),
            facing = CrowdCodec.FACINGS[bit32.band(flags, 3) + 1],
            moving = bit32.band(flags, 4) ~= 0,
        })
    end
    return out
end

return CrowdCodec
