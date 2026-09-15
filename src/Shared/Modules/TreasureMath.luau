--!strict
-- [D59] Ce aduce raul: ceasul si ce vine. Modul PUR, pe ceasul de perete (os.time, ca venitul offline): primeste `now` si
-- starea din profil (`River`), o schimba pe loc si intoarce ce a sosit. Serverul e singurul care o cheama.
--
-- Regulile, in pasii jucatorului:
--   * pana la primul tau peste, raul nu aduce nimic (nu stii inca sa scoti ce aduce); primul vine la FIRST_DELAY dupa
--     si e o sticla, cu biletul care spune cum merge;
--   * apoi cate unul la 4-8 minute, si cat esti in joc, si cat lipsesti;
--   * la ponton stau cel mult MAX_WAITING. Cat sunt atatea, ceasul STA (nextAt = 0) si porneste iar cand scoti unul --
--     nimic nu expira si nimic nu se pierde, iar plafonul e spus pe fata [D40].
local Prng = require(script and script.Parent.Prng or "./Prng")
local TreasureConfig =
    require(script and script.Parent.Parent.Config.TreasureConfig or "../Config/TreasureConfig")

local TreasureMath = {}

export type State = {
    started: boolean,
    waiting: { string }, -- in ordinea sosirii; se scot de la primul
    nextAt: number, -- os.time al urmatorului; 0 = ceasul sta (pontonul e plin sau raul n-a pornit)
    seed: number,
    total: number, -- cate au sosit vreodata (primul e mereu sticla)
    notes: number, -- cate bilete ai citit; urmatorul e NOTES[notes % #NOTES + 1]
}

function TreasureMath.pickKind(roll: number): string
    local total = 0
    for _, k in TreasureConfig.KINDS do
        total += k.weight
    end
    local target = math.clamp(roll, 0, 0.9999999) * total
    local acc = 0
    for _, k in TreasureConfig.KINDS do
        acc += k.weight
        if target < acc then
            return k.id
        end
    end
    return TreasureConfig.KINDS[#TreasureConfig.KINDS].id
end

function TreasureMath.interval(roll: number): number
    local lo, hi = TreasureConfig.INTERVAL_MIN, TreasureConfig.INTERVAL_MAX
    return lo + math.floor(math.clamp(roll, 0, 0.9999999) * (hi - lo + 1))
end

-- O tragere din samanta starii, care avanseaza: aceeasi stare da aceleasi sosiri, oricand se recalculeaza.
local function draw(state: State): number
    local rng = Prng.new(state.seed)
    rng:nextU32()
    local roll = rng:nextNumber()
    state.seed = rng:nextU32()
    return roll
end

-- La primul peste. Intoarce true doar prima data.
function TreasureMath.start(state: State, now: number): boolean
    if state.started then
        return false
    end
    state.started = true
    -- cu pontonul deja plin (daruri ale roatii inainte de primul peste) ceasul sta, ca peste tot: porneste la primul scos
    state.nextAt = if #state.waiting < TreasureConfig.MAX_WAITING
        then now + TreasureConfig.FIRST_DELAY
        else 0
    return true
end

-- Tot ce a sosit pana la `now`, in ordine (si ce a venit cat ai lipsit, pana la plafon).
function TreasureMath.advance(state: State, now: number): { string }
    local arrived = {}
    if not state.started then
        return arrived
    end
    while
        state.nextAt > 0
        and now >= state.nextAt
        and #state.waiting < TreasureConfig.MAX_WAITING
    do
        local kind = if state.total == 0
            then TreasureConfig.FIRST_KIND
            else TreasureMath.pickKind(draw(state))
        table.insert(state.waiting, kind)
        state.total += 1
        table.insert(arrived, kind)
        if #state.waiting >= TreasureConfig.MAX_WAITING then
            state.nextAt = 0
        else
            state.nextAt += TreasureMath.interval(draw(state))
        end
    end
    return arrived
end

-- Scoti primul lucru de la ponton. Daca pontonul era plin, ceasul porneste iar de acum.
function TreasureMath.take(state: State, now: number): string?
    local kind = table.remove(state.waiting, 1)
    if kind ~= nil and state.started and state.nextAt == 0 then
        state.nextAt = now + TreasureMath.interval(draw(state))
    end
    return kind
end

-- Un dar al roatii care vine la ponton. False = pontonul e plin: roata il plateste pe loc in perle.
function TreasureMath.grant(state: State, kind: string): boolean
    if #state.waiting >= TreasureConfig.MAX_WAITING or TreasureConfig.byId[kind] == nil then
        return false
    end
    table.insert(state.waiting, kind)
    state.total += 1
    if #state.waiting >= TreasureConfig.MAX_WAITING then
        state.nextAt = 0
    end
    return true
end

-- Biletul din sticla pe care o deschizi acum: in ordine, apoi de la capat.
function TreasureMath.nextNote(state: State): number
    local index = state.notes % #TreasureConfig.NOTES + 1
    state.notes += 1
    return index
end

return TreasureMath
