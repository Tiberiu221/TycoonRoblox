--!strict
-- Ecran de incarcare minimal (ReplicatedFirst ruleaza inaintea oricarui alt cod) [MASTERPLAN 11.1]
local ReplicatedFirst = game:GetService("ReplicatedFirst")
local Players = game:GetService("Players")

ReplicatedFirst:RemoveDefaultLoadingScreen()

local playerGui = Players.LocalPlayer:WaitForChild("PlayerGui") :: PlayerGui
local gui = Instance.new("ScreenGui")
gui.Name = "Loading"
gui.IgnoreGuiInset = true
gui.DisplayOrder = 100
local frame = Instance.new("Frame")
frame.Size = UDim2.fromScale(1, 1)
frame.BackgroundColor3 = Color3.fromRGB(12, 24, 32)
frame.Parent = gui
local text = Instance.new("TextLabel")
text.Size = UDim2.fromScale(1, 1)
text.BackgroundTransparency = 1
text.TextColor3 = Color3.fromRGB(220, 230, 235)
text.TextScaled = true
text.Text = "Riverkeep"
text.Parent = frame
gui.Parent = playerGui

if not game:IsLoaded() then
    game.Loaded:Wait()
end
task.wait(0.25)
gui:Destroy()
