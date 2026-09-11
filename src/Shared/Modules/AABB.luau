--!strict
-- Coliziune plasa-obiect in pixeli logici (referinta 1920x1080) [DECIZII D06, D13]
local AABB = {}

export type Box = { x: number, y: number, width: number, height: number }

function AABB.intersects(a: Box, b: Box): boolean
    return a.x < b.x + b.width
        and a.x + a.width > b.x
        and a.y < b.y + b.height
        and a.y + a.height > b.y
end

return AABB
