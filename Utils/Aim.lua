local Aim = {}

local EYE_HEIGHT = 1.6

local function SameEntity(first, second)
    return first ~= nil and second ~= nil and first:GetEntityID().hash == second:GetEntityID().hash
end

function Aim.IsOwn(player, entity)
    if not entity then return true end
    if SameEntity(entity, player) then return true end

    local ok, vehicle = pcall(Game.GetMountedVehicle, player)
    return ok and SameEntity(entity, vehicle)
end

function Aim.Object(player)
    local targeting = Game.GetTargetingSystem()
    if not targeting then return nil end

    local ok, target = pcall(function() return targeting:GetLookAtObject(player, true, false) end)
    if not ok or Aim.IsOwn(player, target) then return nil end
    return target
end

function Aim.Point(player)
    local targeting = Game.GetTargetingSystem()
    if not targeting then return nil end

    local ok, point = pcall(function() return targeting:GetLookAtPosition(player, true, false) end)
    if ok then return point end
    return nil
end

function Aim.Ray(player)
    local camera = Game.GetCameraSystem()
    local forward = camera and camera:GetActiveCameraForward()
    if not forward then return nil, nil end

    local position = player:GetWorldPosition()
    local origin = { x = position.x, y = position.y, z = position.z + EYE_HEIGHT }
    return origin, { x = forward.x, y = forward.y, z = forward.z }
end

function Aim.Distance(player, point)
    local position = player:GetWorldPosition()
    local dx, dy, dz = point.x - position.x, point.y - position.y, point.z - position.z
    return math.sqrt((dx * dx) + (dy * dy) + (dz * dz))
end

function Aim.Aiming(player)
    local ok, aiming = pcall(function()
        local blackboard = player:GetPlayerStateMachineBlackboard()
        return blackboard:GetInt(GetAllBlackboardDefs().PlayerStateMachine.UpperBody) == EnumInt(gamePSMUpperBodyStates.Aim)
    end)
    return ok and aiming == true
end

function Aim.IsPuppet(entity)
    local ok, puppet = pcall(function() return entity:IsPuppet() end)
    return ok and puppet == true
end

function Aim.IsVehicle(entity)
    local ok, vehicle = pcall(function() return entity:IsVehicle() end)
    return ok and vehicle == true
end

return Aim
