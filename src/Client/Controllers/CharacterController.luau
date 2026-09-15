--!strict
-- Personajul in lumea de sus: WASD/sageti sau d-pad pe ecran, coliziuni pe dreptunghiuri; pozitia e locala [DECIZII D07 v2]
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local RiverConfig = require(ReplicatedStorage.Shared.Config.RiverConfig)
local TycoonConfig = require(ReplicatedStorage.Shared.Config.TycoonConfig)
local WorldMap = require(ReplicatedStorage.Shared.Modules.WorldMap)
local SceneArt = require(script.Parent.SceneArt)

local CharacterController = {}
-- SPAWN, nu RiverConfig.CHARACTER.START_X/Y: locul de start e acum al tycoon-ului [F0 spec 1.1].
local x, y = TycoonConfig.SPAWN.x, TycoonConfig.SPAWN.y
local facing = "down"
-- [D59] ce face personajul pe loc (undita) si spre ce parte; nil = nimic, ca pana acum. Nu `task`: ar ascunde
-- biblioteca task.* in tot fisierul.
local activity: string? = nil
local activityFacing: string? = nil
local setOutfitFn: ((string) -> ())? = nil
local wantedOutfit: string? = nil
local keys: { [string]: boolean } = {}
-- directia de la joystick, ca vector: -1..1 pe fiecare axa. Patru butoane dadeau doar 8
-- directii si mancau o treime din ecranul de telefon.
local stickX, stickY = 0, 0
local locked = false
local onPlayerInput: (() -> ())? = nil
-- Static: nu mai exista cladiri de colonie care sa blocheze mersul, iar platformele tycoon-ului
-- NU blocheaza (trebuie sa poti calca pe ele ca sa le cumperi) -- doar raul opreste personajul.
-- [D59] ...in afara pontonului lung: pe el mergi pana la capat, unde pescuiesti.
local rects = WorldMap.blockedRects(RiverConfig, nil, TycoonConfig.PIER_WALK)

local KEYMAP: { [Enum.KeyCode]: string } = {
    [Enum.KeyCode.A] = "left",
    [Enum.KeyCode.Left] = "left",
    [Enum.KeyCode.D] = "right",
    [Enum.KeyCode.Right] = "right",
    [Enum.KeyCode.W] = "up",
    [Enum.KeyCode.Up] = "up",
    [Enum.KeyCode.S] = "down",
    [Enum.KeyCode.Down] = "down",
}

function CharacterController.Position(): (number, number)
    return x, y
end

function CharacterController.X(): number
    return x
end

-- Blocheaza miscarea cat timp cineva vorbeste cu jucatorul. Fara asta, replica devine zgomot
-- de fundal peste care jucatorul se plimba, si nimeni nu o citeste.
function CharacterController.SetLocked(value: boolean)
    locked = value
    if locked then
        stickX, stickY = 0, 0
    end
end

function CharacterController.IsLocked(): boolean
    return locked
end

-- [D59] O treaba pe loc (undita), cu fata spre `facing`. Cat stai, randul ei; cand pornesti, mersul. nil = gata.
function CharacterController.SetTask(newTask: string?, newFacing: string?)
    activity = newTask
    activityFacing = newFacing
    if newFacing ~= nil then
        facing = newFacing
    end
end

-- [D59] Tinuta de la avizierul satului. Inainte de Init se tine minte si se aplica la desenare.
function CharacterController.SetOutfit(outfit: string)
    wantedOutfit = outfit
    local fn = setOutfitFn
    if fn ~= nil then
        fn(outfit)
    end
end

-- Joystick-ul de pe telefon. Magnitudinea conteaza: o impingere usoara merge incet.
function CharacterController.SetStick(vx: number, vy: number)
    stickX, stickY = vx, vy
    if (vx ~= 0 or vy ~= 0) and onPlayerInput ~= nil then
        onPlayerInput()
    end
end

function CharacterController.Init(deps: {
    Scroll: Frame,
    OnMove: (number, number) -> (),
    OnPlayerInput: (() -> ())?,
})
    onPlayerInput = deps.OnPlayerInput
    local sprite, setPose, setOutfit = SceneArt.MakeCharacter(deps.Scroll)
    setOutfitFn = setOutfit
    if wantedOutfit ~= nil then
        setOutfit(wantedOutfit :: string)
    end
    local c = RiverConfig.CHARACTER
    sprite.Position = UDim2.fromOffset(x, y)

    UserInputService.InputBegan:Connect(function(input: InputObject, processed: boolean)
        local dir = KEYMAP[input.KeyCode]
        if dir ~= nil and not processed then
            keys[dir] = true
            if deps.OnPlayerInput then
                deps.OnPlayerInput()
            end
        end
    end)
    UserInputService.InputEnded:Connect(function(input: InputObject)
        local dir = KEYMAP[input.KeyCode]
        if dir ~= nil then
            keys[dir] = false
        end
    end)

    local function down(dir: string): boolean
        return keys[dir] == true
    end

    RunService.PreRender:Connect(function(dt: number)
        local dx = if locked
            then 0
            else (if down("right") then 1 else 0) - (if down("left") then 1 else 0)
        local dy = if locked
            then 0
            else (if down("down") then 1 else 0) - (if down("up") then 1 else 0)
        local stickMag = math.min(1, math.sqrt(stickX * stickX + stickY * stickY))
        if not locked and (stickX ~= 0 or stickY ~= 0) then
            dx, dy = stickX, stickY -- joystick-ul are prioritate; nu se apasa si taste in acelasi timp
        end
        -- Alergarea nu are control propriu: pe telefon e joystick-ul impins pana la capat,
        -- pe desktop e Shift. Zero elemente noi pe ecran pentru o a doua viteza.
        local running = not locked
            and (dx ~= 0 or dy ~= 0)
            and (
                stickMag >= c.RUN_THRESHOLD
                or UserInputService:IsKeyDown(Enum.KeyCode.LeftShift)
                or UserInputService:IsKeyDown(Enum.KeyCode.RightShift)
            )
        if dx ~= 0 or dy ~= 0 then
            local len = math.sqrt(dx * dx + dy * dy)
            -- Directia se normalizeaza (diagonala nu e mai rapida), dar MAGNITUDINEA se pastreaza
            -- pana la 1: o impingere pe jumatate din joystick merge pe jumatate din viteza.
            local mag = math.min(len, 1)
            local speed = c.SPEED * (if running then c.RUN_MULTIPLIER else 1)
            local nx = x + dx / len * mag * speed * dt
            local ny = y + dy / len * mag * speed * dt
            if not WorldMap.isBlocked(rects, RiverConfig, nx, y) then
                x = nx
            end
            if not WorldMap.isBlocked(rects, RiverConfig, x, ny) then
                y = ny
            end
            facing = if dx ~= 0
                then (if dx > 0 then "right" else "left")
                else (if dy > 0 then "down" else "up")
            setPose(true, facing, dt, running, nil)
        else
            setPose(false, activityFacing or facing, dt, false, activity)
        end
        sprite.Position = UDim2.fromOffset(x, y)
        sprite.ZIndex = 6
        deps.OnMove(x, y)
    end)
end

return CharacterController
