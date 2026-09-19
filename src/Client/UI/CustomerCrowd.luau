--!strict
-- CLIENTII UNUI VANZATOR [D50, D65]: cati vin = cat vinde chiar acum (TavernCrowd, peste evenimentele `Sold`), nu cat
-- ar putea vinde. Vin pe rand de la capatul drumului, asteapta la locurile lor, iar la o vanzare unul pleaca acasa cu
-- marfa in brate.
--
-- Pana la D65 traia in DockController, cu locurile tavernei batute in cuie. Piata Morii are aceiasi clienti in alt loc,
-- deci logica s-a mutat aici INTOCMAI (aceleasi viteze, aceleasi pauze, aceeasi samanta pentru taverna), iar fiecare
-- vanzator isi face multimea lui din locurile lui.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local HandConfig = require(ReplicatedStorage.Shared.Config.HandConfig)
local TavernCrowd = require(ReplicatedStorage.Shared.Modules.TavernCrowd)
local PersonView = require(script.Parent.PersonView)

export type Point = { x: number, y: number }
export type Spot = { x: number, y: number, facing: string }
export type Options = {
    plot: Frame,
    name: string, -- prefixul numelui din ierarhie ("Customer", "MarketCustomer")
    spots: { Spot }, -- unde stau cei care asteapta (picioarele), cu fata spre cine stau
    entry: Point, -- de unde vin si pe unde pleaca
    -- Samanta clientilor. HandConfig o inmulteste cu ~2.65e9 inainte de modulo, deci trebuie sa ramana sub ~3.4e6,
    -- altfel produsul trece de 2^53 si bitii de jos se pierd (clienti aproape identici).
    seedBase: number,
    held: string, -- ce duce acasa cine a cumparat (PersonView: "plank", "part")
}
export type Crowd = {
    OnSold: (itemCount: number?) -> (),
    Step: (dt: number) -> (),
}

type Customer = {
    view: PersonView.View,
    state: string, -- "arriving" | "waiting" | "leaving"
    spot: number?,
    x: number,
    y: number,
    path: { Point },
    facing: string,
    bought: boolean,
}

local CUSTOMER_SPEED = 90 -- se plimba; oamenii tai merg cu 150
local SPAWN_GAP = 0.9 -- vin pe rand, nu toti deodata
local LEAVE_GAP = 1.2 -- o vanzare pe secunda n-are voie sa goleasca locul intr-o clipa

local CustomerCrowd = {}

function CustomerCrowd.new(o: Options): Crowd
    local customers: { Customer } = {}
    local crowd = TavernCrowd.new()
    local customerCount = 0
    local lastSpawnAt = -math.huge
    local lastLeaveAt = -math.huge

    local function freeSpot(): number?
        for i = 1, #o.spots do
            local taken = false
            for _, c in customers do
                if c.spot == i then
                    taken = true
                    break
                end
            end
            if not taken then
                return i
            end
        end
        return nil
    end

    local function spawnCustomer()
        local spot = freeSpot()
        if spot == nil then
            return
        end
        customerCount += 1
        local seed = o.seedBase + customerCount
        local look = HandConfig.appearanceFor(seed)
        local outfits = HandConfig.CUSTOMER_OUTFITS
        local view = PersonView.new(o.plot, `{o.name}{customerCount}`, o.held)
        view.SetAppearance({
            body = look.body,
            hair = look.hair,
            skin = look.skin,
            hairColor = look.hairColor,
            outfit = outfits[(customerCount % #outfits) + 1],
        })
        local s = o.spots[spot]
        table.insert(customers, {
            view = view,
            state = "arriving",
            spot = spot,
            x = o.entry.x,
            y = o.entry.y,
            path = { { x = s.x, y = o.entry.y }, { x = s.x, y = s.y } },
            facing = "right",
            bought = false,
        })
    end

    -- Pleaca pe drumul mare, spre locul de unde a venit; cu marfa in brate, daca pleaca pentru ca a cumparat.
    local function leave(c: Customer, bought: boolean)
        c.state = "leaving"
        c.spot = nil
        c.bought = bought
        c.path = { { x = c.x, y = o.entry.y }, { x = o.entry.x, y = o.entry.y } }
    end

    local function firstWaiting(): Customer?
        for _, c in customers do
            if c.state == "waiting" then
                return c
            end
        end
        return nil
    end

    local self = {}

    -- O vanzare: intra in fereastra clientilor si trimite un client acasa cu marfa.
    function self.OnSold(itemCount: number?)
        local now = os.clock()
        if type(itemCount) == "number" then
            TavernCrowd.add(crowd, now, itemCount)
        end
        if now - lastLeaveAt >= LEAVE_GAP then
            local c = firstWaiting()
            if c ~= nil then
                lastLeaveAt = now
                leave(c, true)
            end
        end
    end

    function self.Step(dt: number)
        local now = os.clock()
        local target = TavernCrowd.count(crowd, now)
        local present = 0
        for _, c in customers do
            if c.state ~= "leaving" then
                present += 1
            end
        end
        if present < target and now - lastSpawnAt >= SPAWN_GAP then
            lastSpawnAt = now
            spawnCustomer()
        elseif present > target and now - lastLeaveAt >= LEAVE_GAP then
            local c = firstWaiting()
            if c ~= nil then
                lastLeaveAt = now
                leave(c, false)
            end
        end

        for i = #customers, 1, -1 do
            local c = customers[i]
            local budget = CUSTOMER_SPEED * dt
            while budget > 0 and #c.path > 0 do
                local p = c.path[1]
                local dx, dy = p.x - c.x, p.y - c.y
                local d = math.sqrt(dx * dx + dy * dy)
                if d <= budget then
                    c.x, c.y = p.x, p.y
                    budget -= d
                    table.remove(c.path, 1)
                else
                    c.x += dx / d * budget
                    c.y += dy / d * budget
                    budget = 0
                    c.facing = if math.abs(dx) >= math.abs(dy)
                        then (if dx >= 0 then "right" else "left")
                        else (if dy >= 0 then "down" else "up")
                end
            end
            local moving = #c.path > 0
            if not moving then
                if c.state == "arriving" then
                    c.state = "waiting"
                    c.facing = o.spots[c.spot :: number].facing
                elseif c.state == "leaving" then
                    c.view.Destroy()
                    table.remove(customers, i)
                    continue
                end
            end
            c.view.Pose(c.x, c.y, "idle", c.facing, moving, dt)
            c.view.SetHeld(if c.bought then 1 else 0)
        end
    end

    return self
end

return CustomerCrowd
