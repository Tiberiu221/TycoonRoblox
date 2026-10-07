--!strict
-- Ecran de incarcare (ReplicatedFirst ruleaza inaintea oricarui alt cod) [MASTERPLAN 11.1]. Montat in AMBELE place-uri
-- [D60]; `Place` (StringValue, din fisierul de proiect) spune in care suntem.
--
-- Ramane pe ecran pana se incarca jocul SI profilul (atributul SaveLoaded, pus de DataService). Dupa un drum cu barca,
-- profilul inca e in celalalt place cateva secunde; fara asteptarea asta, satul aparea gol si balciul fara perle.
-- Venit cu barca: se pastreaza ecranul drumului (negru, "Rowing up to the fair..."), ca trecerea sa para una singura.
-- Textele stau aici, nu in Strings: ReplicatedStorage inca nu e aici cand ruleaza scriptul asta.
local Players = game:GetService("Players")
local ReplicatedFirst = game:GetService("ReplicatedFirst")
local TeleportService = game:GetService("TeleportService")

ReplicatedFirst:RemoveDefaultLoadingScreen()

local WAIT_LIMIT = 25 -- secunde: dupa atat, ecranul pleaca oricum (jocul arata singur ce lipseste)
-- [auditul balciului, 2026-10-07] In sat, harta se construieste pe lumea din profil: fara profil, un jucator de la baraj
-- ar fi primit satul vechi, inghetat si fara niciun cuvant. Satul asteapta deci profilul cat il asteapta si serverul
-- (DataService: incarcat sau Kick „Could not load your save” la 120 s), iar dupa 25 s spune ca inca se incarca.
local VILLAGE_WAIT_LIMIT = 150
local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui") :: PlayerGui
local placeValue = script.Parent:FindFirstChild("Place")
local isFair = placeValue ~= nil and placeValue:IsA("StringValue") and placeValue.Value == "fair"

local gui: ScreenGui
local arriving = TeleportService:GetArrivingTeleportGui()
if arriving ~= nil then
    gui = arriving
else
    gui = Instance.new("ScreenGui")
    local frame = Instance.new("Frame")
    frame.Size = UDim2.fromScale(1, 1)
    frame.BackgroundColor3 = if isFair
        then Color3.fromRGB(14, 16, 32)
        else Color3.fromRGB(12, 24, 32)
    frame.BorderSizePixel = 0
    frame.Parent = gui
    local title = Instance.new("TextLabel")
    title.AnchorPoint = Vector2.new(0.5, 0.5)
    title.Position = UDim2.fromScale(0.5, 0.46)
    title.Size = UDim2.fromScale(0.8, 0.12)
    title.BackgroundTransparency = 1
    title.TextColor3 = Color3.fromRGB(240, 233, 218)
    title.Font = Enum.Font.Arcade
    title.TextScaled = true
    title.Text = if isFair then "The Evening Fair" else "Driftycoon"
    title.Parent = frame
    local sub = Instance.new("TextLabel")
    sub.AnchorPoint = Vector2.new(0.5, 0)
    sub.Position = UDim2.fromScale(0.5, 0.56)
    sub.Size = UDim2.fromScale(0.8, 0.04)
    sub.BackgroundTransparency = 1
    sub.TextColor3 = Color3.fromRGB(196, 186, 168)
    sub.Font = Enum.Font.Arcade
    sub.TextScaled = true
    sub.Text = if isFair then "Loading the fair..." else "Loading your river..."
    sub.Parent = frame
end
gui.Name = "Loading"
gui.IgnoreGuiInset = true
gui.ResetOnSpawn = false
gui.DisplayOrder = 100
gui.Parent = playerGui

if not game:IsLoaded() then
    game.Loaded:Wait()
end
local started = os.clock()
local limit = if isFair then WAIT_LIMIT else VILLAGE_WAIT_LIMIT
local still: TextLabel? = nil
local function waitFor(attribute: string)
    while player:GetAttribute(attribute) ~= true and os.clock() - started < limit do
        if still == nil and os.clock() - started >= WAIT_LIMIT then
            -- nimic nu se intampla in tacere [D43]: un rand jos, peste orice cortina (si peste cea a drumului cu barca)
            local label = Instance.new("TextLabel")
            label.AnchorPoint = Vector2.new(0.5, 1)
            label.Position = UDim2.new(0.5, 0, 1, -32)
            label.Size = UDim2.fromScale(0.8, 0.04)
            label.BackgroundTransparency = 1
            label.TextColor3 = Color3.fromRGB(196, 186, 168)
            label.Font = Enum.Font.Arcade
            label.TextScaled = true
            label.Text = "Still loading your save..."
            label.ZIndex = 50
            label.Parent = gui
            still = label
        end
        task.wait(0.1)
    end
end
waitFor("SaveLoaded")
-- [D70, verificatorul k1] in sat, harta se construieste abia dupa profil: cortina pleaca dupa ce e gata (atributul local
-- ClientBuilt, pus de Bootstrap.client), in aceeasi limita de timp. Balciul nu-l pune.
if not isFair then
    waitFor("ClientBuilt")
end
task.wait(0.25)
gui:Destroy()
