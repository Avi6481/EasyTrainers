local Upright = {}

local LIFT = 1

function Upright.Flip(vehicle)
    local position = vehicle:GetWorldPosition()
    local yaw = vehicle:GetWorldYaw()
    Game.GetTeleportationFacility():Teleport(vehicle, Vector4.new(position.x, position.y, position.z + LIFT, 1), EulerAngles.new(0, 0, yaw))
end

return Upright
