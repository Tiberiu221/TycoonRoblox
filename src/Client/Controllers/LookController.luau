--!strict
-- [D70] "LOOK (V)": O PRIVIRE SPRE SATUL VECHI. Treptele modernizarii se vad mai ales in Landing (tabla si caramida,
-- geamurile, luminile), departe de Wire Works, unde stai cand vin: toastul spunea "old village", iar schimbarea o vedeai
-- abia cand treceai pe acolo. Acum bannerul treptei are butonul Look (tasta V): camera pleaca lin spre loc, sta, apoi se
-- intoarce lin la tine (drumul in GlanceMath, pur). Daca pornesti la drum, se intoarce pe loc, tot lin. Nimic nu se
-- opreste: satul lucreaza, iar tu poti merge oricand.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GlanceMath = require(ReplicatedStorage.Shared.Modules.GlanceMath)
local CameraController = require(script.Parent.CameraController)

export type Deps = {
    -- pozitia personajului, in coordonatele lumii (CharacterController.Position)
    CharacterPos: () -> (number, number),
}

local LookController = {}
local deps: Deps? = nil
local glance: GlanceMath.Glance? = nil

-- Getter-ul camerei (CameraController.SetFocus). La capat intoarce nil, iar camera lasa privirea: drumul inapoi s-a
-- terminat chiar pe om, deci fara salt.
local function focusGetter(): (number?, number?)
    local g, d = glance, deps
    if g == nil or d == nil then
        glance = nil
        return nil, nil
    end
    local px, py = d.CharacterPos()
    local x, y = GlanceMath.point(g, os.clock(), px, py)
    if x == nil then
        glance = nil
    end
    return x, y
end

function LookController.Init(d: Deps)
    deps = d
end

-- Locul (x, y in lume) nu se vede de unde stai (camera asezata pe tine, nu una in mijlocul unei priviri): abia atunci
-- merita oferita privirea.
function LookController.OffScreen(x: number, y: number): boolean
    local d = deps
    if d == nil then
        return false
    end
    local px, py = d.CharacterPos()
    local camX, camY = CameraController.OriginFor(px, py)
    local w, h = CameraController.VisibleSize()
    return x < camX or x > camX + w or y < camY or y > camY + h
end

-- Porneste privirea spre (x, y), in coordonatele lumii: din punctul in care e camera acum (o privire in curs, sau
-- mijlocul ecranului, poate tras spre un dar de pe rau), nu de la om.
function LookController.Look(x: number, y: number)
    local d = deps
    if d == nil then
        return
    end
    local now = os.clock()
    local fromX, fromY = nil, nil
    local g = glance
    if g ~= nil and CameraController.Holds(focusGetter) then
        local px, py = d.CharacterPos()
        fromX, fromY = GlanceMath.point(g, now, px, py)
    end
    if fromX == nil or fromY == nil then
        local camX, camY = CameraController.WorldOrigin()
        local w, h = CameraController.VisibleSize()
        fromX, fromY = camX + w / 2, camY + h / 2
    end
    glance = GlanceMath.start(fromX :: number, fromY :: number, x, y, now)
    CameraController.SetFocus(focusGetter)
end

-- O privire tine acum camera (InteractController isi tine cardul fata de camera de repaus doar atunci).
function LookController.Active(): boolean
    return glance ~= nil and CameraController.Holds(focusGetter)
end

-- Te-ai pornit la drum: camera se intoarce acum la tine, lin. Intoarce true cat privirea tine camera (atunci ramane a
-- ei pana ajunge inapoi).
function LookController.Cancel(): boolean
    local g, d = glance, deps
    if g == nil or d == nil or not CameraController.Holds(focusGetter) then
        return false
    end
    local px, py = d.CharacterPos()
    glance = GlanceMath.cancel(g, os.clock(), px, py)
    return true
end

return LookController
