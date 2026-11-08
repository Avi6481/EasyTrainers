local Teleport = {}

local LIFT = 0.5

function Teleport.To(player, x, y, z)
    local target = player
    local ok, vehicle = pcall(Game.GetMountedVehicle, player)
    if ok and vehicle then target = vehicle end

    local rotation = EulerAngles.new(0, 0, target:GetWorldYaw())
    Game.GetTeleportationFacility():Teleport(target, Vector4.new(x, y, z + LIFT, 1), rotation)
end

return Teleport
