local Weapon = require("Utils/Weapon")

local SmartBlade = {
    Enabled = false
}

local DROP = 0.5

function SmartBlade.OnProjectileHit(projectile)
    if not SmartBlade.Enabled or Weapon.Ranged() then return end

    local player = Game.GetPlayer()
    if not player then return end

    local position = player:GetWorldPosition()
    local back = Vector4.new(position.x, position.y, position.z - DROP, 1)
    Game.GetTeleportationFacility():Teleport(projectile, back, player:GetWorldOrientation():ToEulerAngles())
end

return SmartBlade
