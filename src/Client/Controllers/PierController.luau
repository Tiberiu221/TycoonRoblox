--!strict
-- [D59] UNDITA TA, pe ecran. Owner-ul (2026-09-15): "A si B cum recomanzi, apuca-te" -- A e jocul dintre asteptari: la
-- capatul pontonului arunci, pestele musca, tii apasat cat sta in zona luminoasa. In pasii jucatorului:
--   1. la capat, cardul scrie `Cast (E)` (sau `Hook the chest (E)`, cand te asteapta ceva la ponton);
--   2. firul si plutitorul cad pe apa; cand musca: stropi, "!", un sunet, bara;
--   3. tii E (pe telefon, butonul) cat pestele e in zona -> firul se strange; afara -> se desface putin; fara buton ->
--      nu se misca nimic. NU EXISTA ESEC (ReelMath, testat);
--   4. bara plina -> serverul spune ce era: iconita, numele, marimea, perlele care zboara in pastila lor.
-- Pleci de pe capat si aruncarea se anuleaza in liniste: pestele nu era inca al tau.
--
-- Clientul nu stie ce e in apa pana nu scoate [D13]: primeste doar clipa muscaturii, dificultatea (culoarea pestelui
-- de pe bara) si samanta barei, ca s-o deseneze exact cum o socoteste serverul.
--
-- [D61] Undita propriu-zisa (firul, plutitorul, bara, cartonasul, pasii) sta acum in UI/FishingRig, comuna cu jetiul din
-- balci. Aici a ramas ce e al satului: locul de pe ponton, lucrurile aduse de rau si ceremonia jurnalului.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local Assets = require(ReplicatedStorage.Shared.Config.Assets)
local RiverConfig = require(ReplicatedStorage.Shared.Config.RiverConfig)
local Strings = require(ReplicatedStorage.Shared.Config.Strings)
local TreasureConfig = require(ReplicatedStorage.Shared.Config.TreasureConfig)
local TycoonConfig = require(ReplicatedStorage.Shared.Config.TycoonConfig)

local CeremonyController = require(script.Parent.CeremonyController)
local HUDController = require(script.Parent.HUDController)
local JuiceController = require(script.Parent.JuiceController)
local SoundController = require(script.Parent.SoundController)
local TreasureController = require(script.Parent.TreasureController)
local FishingRig = require(script.Parent.Parent.UI.FishingRig)
local Focus = require(script.Parent.Parent.UI.Focus)
local Theme = require(script.Parent.Parent.UI.Theme)

export type Deps = {
    Plot: Frame,
    CharacterPos: () -> (number, number),
    WorldToHud: (number, number) -> (number, number),
    Remotes: {
        Cast: RemoteEvent,
        CastResult: RemoteEvent,
        Land: RemoteEvent,
        LandResult: RemoteEvent,
    },
    OnToast: (string, Color3?) -> (),
}

local PierController = {}
local rig: FishingRig.Rig? = nil

local STAND = TycoonConfig.FISH_STAND
local BOBBER_AT = TycoonConfig.BOBBER_AT
local SPOT_DISTANCE = 70 -- cardul apare doar pe capatul pontonului, nu de oriunde de pe el
local waiting: { string } = {}

-- Cardul locului de pescuit. Cat arunci, astepti sau mulinezi, fara continut: cardul se ascunde, iar E nu mai face
-- nimic altceva (tinut apasat, strange firul).
function PierController.Focus(px: number, py: number): Focus.Focus?
    local r = rig
    if r == nil then
        return nil
    end
    local d = Focus.distance(px, py, STAND.x, STAND.y)
    if d > math.min(SPOT_DISTANCE, RiverConfig.INTERACT_DISTANCE) then
        return nil
    end
    local f: Focus.Focus = { key = "pier", distance = d, x = STAND.x, y = STAND.y - 84 }
    if r.state() ~= "idle" then
        return f
    end
    local keyHint = if UserInputService.KeyboardEnabled then " (E)" else ""
    local first = waiting[1]
    local kind = if first ~= nil then TreasureConfig.byId[first] else nil
    f.action = if kind ~= nil then Strings.fishHook(kind.id, keyHint) else Strings.fishCast(keyHint)
    f.act = r.cast
    return f
end

-- Din TycoonState: ce te asteapta la ponton (pe primul il agata urmatoarea aruncare).
function PierController.Apply(newWaiting: { string })
    waiting = table.clone(newWaiting)
end

-- Un lucru adus de rau, agatat: se ridica din apa, cartonasul lui, perlele, si nota daca are una.
local function onTreasure(result: { [string]: any }, h: FishingRig.Helpers)
    local def = TreasureConfig.byId[result.treasure or ""]
    if def == nil then
        return
    end
    local pearls = if typeof(result.pearls) == "number" then result.pearls else 0
    local lx, ly = h.characterAt()
    TreasureController.PlayHooked(lx, ly - 40)
    SoundController.Play("chime", 1.1)
    local icon = (Assets.treasure :: any)[def.id]
    local wx, wy = h.popResult(icon, def.name, Strings.pearlsGained(pearls), nil, Theme.COLOR.gold)
    h.flyPearls(wx, wy, pearls)
    local note = result.note
    if typeof(note) == "number" and TreasureConfig.NOTES[note] ~= nil then
        CeremonyController.PlayMoment(Strings.NOTE_TITLE, TreasureConfig.NOTES[note])
    end
end

function PierController.Init(d: Deps)
    rig = FishingRig.new({
        Layer = d.Plot,
        Origin = Vector2.new(TycoonConfig.PLOT_ORIGIN.x, TycoonConfig.PLOT_ORIGIN.y),
        CharacterPos = d.CharacterPos,
        WorldToHud = d.WorldToHud,
        Remotes = d.Remotes,
        Target = function(c: FishingRig.Cast): (number, number)
            if c.kind == "treasure" then
                return TreasureController.SlotPosition(1)
            end
            return BOBBER_AT.x, BOBBER_AT.y
        end,
        -- pestii sunt in aval (dreapta); ce aduce raul asteapta in amonte (stanga)
        SideFor = function(c: FishingRig.Cast?): string
            if c == nil then
                return if waiting[1] ~= nil then "left" else "right"
            end
            return if c.kind == "treasure" then "left" else "right"
        end,
        IsActionHeld = HUDController.IsActionHeld,
        PearlFly = JuiceController.PearlFly,
        OnToast = d.OnToast,
        OnTreasure = onTreasure,
        OnOutfit = function(_outfit: string)
            task.delay(1.2, function()
                CeremonyController.PlayMoment(
                    Strings.JOURNAL_COMPLETE_TITLE,
                    Strings.outfitUnlocked("River Legend")
                )
            end)
        end,
        LineZ = 8,
        Z = 50, -- peste cardul obiectului (48) si textul lumii (46/47): bara si cartonasul prinderii conteaza [D67, audit]
    })
end

return PierController
