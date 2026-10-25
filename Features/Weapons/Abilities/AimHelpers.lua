local AimHelpers = {}

function AimHelpers.GetAimDirection(player, targeting)
    local origin = player:GetWorldPosition()
    local lookAt = targeting:GetLookAtPosition(player, true, false)
    if not lookAt then return nil, origin end

    local x = lookAt.x - origin.x
    local y = lookAt.y - origin.y
    local z = lookAt.z - origin.z
    local length = math.sqrt(x * x + y * y + z * z)
    if length < 0.001 then return nil, origin end

    return { x = x / length, y = y / length, z = z / length }, origin
end

function AimHelpers.IsFromPlayer(projectile)
    if not projectile then return false end
    local ok, instigator = pcall(function() return projectile:GetInstigator() end)
    return ok and instigator ~= nil and instigator:IsPlayer()
end

function AimHelpers.IsPlayerOrMount(entity)
    if not entity then return true end

    local player = Game.GetPlayer()
    if not player then return true end

    local entityHash = entity:GetEntityID().hash
    if entityHash == player:GetEntityID().hash then return true end

    local mounted = player:GetMountedVehicle()
    return mounted ~= nil and mounted:GetEntityID().hash == entityHash
end

return AimHelpers
