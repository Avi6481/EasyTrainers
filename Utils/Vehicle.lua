local Vehicle = {}

local DRIVER_SEAT = "seat_front_left"
local SPAWN_LIFT = 0.5

function Vehicle.IsVehicle(entity)
    return entity ~= nil and entity:GetVehicleComponent() ~= nil
end

function Vehicle.Mounted(player)
    player = player or Game.GetPlayer()
    if not player then return nil end

    local vehicle = player:GetMountedVehicle()
    if not Vehicle.IsVehicle(vehicle) then return nil end
    return vehicle
end

function Vehicle.Mount(player, vehicle, seat)
    local component = Vehicle.IsVehicle(vehicle) and vehicle:GetVehicleComponent()
    if not component then return false end

    component:MountEntityToSlot(vehicle:GetEntityID(), player:GetEntityID(), CName.new(seat or DRIVER_SEAT))
    return true
end

function Vehicle.Unmount(player, force)
    local vehicle = Vehicle.Mounted(player)
    if not vehicle then return false end

    Game.GetWorkspotSystem():UnmountFromVehicle(vehicle, player, force == true)
    return true
end

function Vehicle.SpawnTransform(player, distance)
    local forward = player:GetWorldForward()
    local transform = player:GetWorldTransform()
    local position = transform.Position:ToVector4()

    transform:SetPosition(transform, Vector4.new(
        position.x + (forward.x * distance),
        position.y + (forward.y * distance),
        position.z + SPAWN_LIFT,
        1
    ))
    return transform
end

return Vehicle
