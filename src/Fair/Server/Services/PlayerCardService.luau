--!strict
-- [D60] CARDUL ALTUI JUCATOR: ce a facut, din profilul lui. Doar pentru cineva de pe acelasi server (profilul lui e
-- incarcat aici); cifrele le pune serverul, nu clientul care intreaba.
--   Era la care a ajuns, venitul pe secunda (ultimul masurat in sat), cel mai mare peste, cate lucruri a scos din rau,
--   cate decoruri are satul, jurnalul (specii prinse din 12), tinuta si titlul.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local FishConfig = require(ReplicatedStorage.Shared.Config.FishConfig)
local LookMath = require(ReplicatedStorage.Shared.Modules.LookMath)

local DataService = require(script.Parent.DataService)
local TitleService = require(script.Parent.TitleService)

local PlayerCardService = {}

export type Card = {
    userId: number,
    name: string,
    title: string,
    outfit: string,
    look: { [string]: number }, -- [D61] infatisarea aleasa la croitoreasa (LookMath)
    era: number,
    incomePerSec: number, -- monede pe secunda; 0 = inca nemasurat
    fish: string?, -- specia celui mai mare peste
    fishCm: number,
    treasures: number,
    decor: number,
    likes: number, -- [D61, partea 2] like-urile primite de satul lui
    species: number,
    speciesTotal: number,
}

function PlayerCardService.Of(userId: number): Card?
    local target = Players:GetPlayerByUserId(userId)
    if target == nil then
        return nil
    end
    local data = DataService.Get(target)
    local facts = TitleService.Facts(target)
    if data == nil or facts == nil then
        return nil
    end
    local _, title = TitleService.Worn(target)
    local decor = 0
    for _, owned in data.Village.decor do
        if owned then
            decor += 1
        end
    end
    local record = facts.record
    local records: any = data.Records
    local income = if typeof(records) == "table"
            and typeof(records.incomePerSec) == "number"
        then records.incomePerSec / 100
        else 0
    return {
        userId = userId,
        name = target.DisplayName,
        title = title,
        outfit = data.Village.outfit,
        look = LookMath.clean(data.Village.look),
        era = facts.era,
        incomePerSec = income,
        fish = if record ~= nil then record.fish else nil,
        fishCm = if record ~= nil then record.cm else 0,
        treasures = data.Stats.treasures or 0,
        decor = decor,
        likes = if typeof((data.Fair :: any).likes) == "number"
            then math.floor((data.Fair :: any).likes)
            else 0,
        species = facts.species,
        speciesTotal = #FishConfig.SPECIES,
    }
end

return PlayerCardService
