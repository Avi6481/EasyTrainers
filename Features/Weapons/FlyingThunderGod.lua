local Teleport = require("Utils/Teleport")
local Weapon = require("Utils/Weapon")

local FlyingThunderGod = {
    Enabled = false
}

local s_Target = nil

function FlyingThunderGod.OnProjectileHit(eventData)
    if not FlyingThunderGod.Enabled or Weapon.Ranged() then return end

    local hits = eventData.hitInstances or {}
    local hit = hits[#hits]
    local position = hit and hit.position
    if position then s_Target = { x = position.x, y = position.y, z = position.z } end
end

function FlyingThunderGod.Update(player)
    if not s_Target then return end

    local target = s_Target
    s_Target = nil
    if FlyingThunderGod.Enabled then Teleport.To(player, target.x, target.y, target.z) end
end

function FlyingThunderGod.Reset()
    s_Target = nil
end

return FlyingThunderGod
