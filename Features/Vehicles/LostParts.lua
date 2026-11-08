local Notify = require("Utils/Notify")
local Vehicle = require("Utils/Vehicle")
local Catalog = require("Features/Vehicles/Catalog")
local Garage = require("Features/Vehicles/Garage")
local Spawner = require("Features/Vehicles/Spawner")

local LostParts = {}

local OUT_OF_THE_WAY = 500

local function Garaged(record)
    local vehicle = Catalog.ByKey[Catalog.Key(record)]
    if vehicle and Garage.IsUnlocked(vehicle) then return vehicle end
    return nil
end

local function Remove(player, old, record)
    local id = old:GetEntityID()
    if Spawner.Owns(id) then
        Spawner.Despawn(player, id)
        return
    end

    local garaged = Garaged(record)
    if garaged then
        Game.GetVehicleSystem():DespawnPlayerVehicle(GarageVehicleID.Resolve(garaged.Id))
        return
    end

    local position = old:GetWorldPosition()
    Game.GetTeleportationFacility():Teleport(old, Vector4.new(position.x, position.y, position.z - OUT_OF_THE_WAY, 1), EulerAngles.new(0, 0, 0))
end

function LostParts.Restore(player, old)
    local record = old:GetRecordID()
    local transform = old:GetWorldTransform()
    local known = Catalog.ByKey[Catalog.Key(record)]
    local label = known and known.Id or "mounted vehicle"

    Vehicle.Unmount(player, true)
    Remove(player, old, record)
    if Spawner.SpawnAt(record, label, transform) then Notify.Info(L("notify.vehicles.restoring")) end
end

return LostParts
