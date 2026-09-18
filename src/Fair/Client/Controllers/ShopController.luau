--!strict
-- [D61, partea 2] TARABA CU COPERTINA AURIE: locul din balci al coltului cu Robux. Panoul e cel comun (ShopPanel, montat
-- si in sat); aici e doar locul din lume: te apropii de taraba, apare cardul `Shop (E)`, iar E deschide panoul. Tasta P
-- si intrarea din bara din dreapta raman, ca magazinul sa nu depinda de drumul pana la taraba.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local Strings = require(ReplicatedStorage.Shared.Config.Strings)

local FairScene = require(script.Parent.FairScene)
local Focus = require(script.Parent.Parent.UI.Focus)

local ShopController = {}

export type Deps = { Open: () -> () }

local NEAR = 130 -- ca la croitoreasa si la poarta: cat sa ajungi in fata tarabei
local deps: Deps? = nil

function ShopController.Focus(px: number, py: number): Focus.Focus?
    local d = deps
    if d == nil then
        return nil
    end
    local x, y, _, h = FairScene.Spot("shop")
    local distance = Focus.distance(px, py, x, y + 10)
    if distance > NEAR then
        return nil
    end
    local keyHint = if UserInputService.KeyboardEnabled then " (E)" else ""
    return {
        key = "shop",
        distance = distance,
        x = x,
        y = y - h - 8,
        action = Strings.shopCard(keyHint),
        act = d.Open,
    }
end

function ShopController.Init(d: Deps)
    deps = d
end

return ShopController
