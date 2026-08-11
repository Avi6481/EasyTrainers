local Logger = require("Core/Logger")
local Vehicle = {}

function Vehicle.IsValidVehicle(ent)
    return ent ~= nil and ent:GetVehicleComponent() ~= nil
end

function Vehicle.GetMountedVehicleSafe()
    local player = Game.GetPlayer()
    if not player then return nil end
    local veh = player:GetMountedVehicle()
    if Vehicle.IsValidVehicle(veh) then
        return veh
    end
    return nil
end

function Vehicle.UnmountPlayer(force)
    local player = Game.GetPlayer()
    local vehicle = Vehicle.GetMountedVehicleSafe()
    if not (player and vehicle) then
        Logger.Log("Vehicle: no vehicle to unmount")
        return false
    end
    local workspot = Game.GetWorkspotSystem()
    if not workspot then return false end
    workspot:UnmountFromVehicle(vehicle, player, force or false)
    return true
end


function Vehicle.MountPlayer(vehicle, seat)
    if not Vehicle.IsValidVehicle(vehicle) then
        Logger.Log("Vehicle: invalid vehicle for mount")
        return false
    end
    local comp = vehicle:GetVehicleComponent()
    local player = Game.GetPlayer()
    if not (comp and player) then return false end
    comp:MountEntityToSlot(vehicle:GetEntityID(), player:GetEntityID(), CName.new(seat or "seat_front_left"))
    return true
end


function Vehicle.GetController()
    local vehicle = Vehicle.GetMountedVehicleSafe()
    if not vehicle then return nil end
    return vehicle:GetAccessoryController()
end

function Vehicle.GetSpawnTransform(player, dist)
    local forward = player:GetWorldForward()
    local offset  = Vector3.new(forward.x * dist, forward.y * dist, 0.5)

    local transform = player:GetWorldTransform()
    local pos = transform.Position:ToVector4()
    local spawnPos = Vector4.new(pos.x + offset.x, pos.y + offset.y, pos.z + offset.z, 1.0)

    transform:SetPosition(transform, spawnPos)
    return transform, spawnPos
end

return Vehicle
