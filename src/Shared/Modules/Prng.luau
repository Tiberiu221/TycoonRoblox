--!strict
-- PRNG determinist (xorshift32) identic pe server, client si Lune: nu depinde de Random.new [DECIZII D13]
local Prng = {}
Prng.__index = Prng

export type Prng = typeof(setmetatable({} :: { state: number }, Prng))

function Prng.new(seed: number): Prng
    local state = bit32.band(math.floor(seed), 0xFFFFFFFF)
    if state == 0 then
        state = 0x9E3779B9
    end
    return setmetatable({ state = state }, Prng)
end

function Prng.nextU32(self: Prng): number
    local x = self.state
    x = bit32.bxor(x, bit32.lshift(x, 13))
    x = bit32.bxor(x, bit32.rshift(x, 17))
    x = bit32.bxor(x, bit32.lshift(x, 5))
    self.state = x
    return x
end

function Prng.nextNumber(self: Prng): number -- [0, 1)
    return Prng.nextU32(self) / 4294967296
end

function Prng.nextInteger(self: Prng, min: number, max: number): number
    return min + math.floor(Prng.nextNumber(self) * (max - min + 1))
end

return Prng
