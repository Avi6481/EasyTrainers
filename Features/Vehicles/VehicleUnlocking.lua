local Logger = require("Core/Logger")
local Notification = require("UI/Panels/Notification/Notification")
local VehicleLoader = require("Utils/DataExtractors/VehicleLoader")

local VehicleUnlocking = {}

local function ForEachVehicle(predicate, callback)
    for _, vehicle in ipairs(VehicleLoader:GetAll()) do
        if vehicle.id and predicate(vehicle) then callback(vehicle) end
    end
end

local function IsPlayerVehicle(vehicle)
    return vehicle.id:lower():match("_player$") ~= nil
end

local function IsModded(vehicle)
    return vehicle.isModded == true
end

function VehicleUnlocking.IsUnlocked(vehicleID)
    local vehicleSystem = Game.GetVehicleSystem()
    if not vehicleSystem then return false end
    return vehicleSystem:IsVehiclePlayerUnlocked(TweakDBID.new(vehicleID))
end

function VehicleUnlocking.SetPlayerVehicleState(vehicleID, enable)
    local vehicleSystem = Game.GetVehicleSystem()
    if not vehicleSystem then return false end

    local recordName = type(vehicleID) == "string" and vehicleID or TDBID.ToStringDEBUG(vehicleID)
    local result = vehicleSystem:EnablePlayerVehicle(recordName, enable, not enable)
    Logger.Log(string.format("VehicleUnlocking: %s %s (%s)", enable and "unlock" or "lock", recordName, tostring(result)))
    return result
end

function VehicleUnlocking.Unlock(vehicleID)
    return VehicleUnlocking.SetPlayerVehicleState(vehicleID, true)
end

function VehicleUnlocking.Disable(vehicleID)
    return VehicleUnlocking.SetPlayerVehicleState(vehicleID, false)
end

local function SetWithVariants(vehicle, enable)
    VehicleUnlocking.SetPlayerVehicleState(vehicle.id, enable)
    for _, variant in ipairs(vehicle.variants or {}) do
        VehicleUnlocking.SetPlayerVehicleState(variant, enable)
    end
end

function VehicleUnlocking.UnlockAllPlayerVehicles()
    ForEachVehicle(IsPlayerVehicle, function(vehicle) VehicleUnlocking.Unlock(vehicle.id) end)
    Notification.Info("All player vehicles unlocked")
end

function VehicleUnlocking.DisableAllPlayerVehicles()
    ForEachVehicle(IsPlayerVehicle, function(vehicle) VehicleUnlocking.Disable(vehicle.id) end)
    Notification.Info("All player vehicles disabled")
end

function VehicleUnlocking.UnlockFaction(faction)
    ForEachVehicle(function(vehicle) return vehicle.faction == faction end, function(vehicle) SetWithVariants(vehicle, true) end)
    Notification.Info("All " .. tostring(faction) .. " vehicles unlocked")
end

function VehicleUnlocking.DisableFaction(faction)
    ForEachVehicle(function(vehicle) return vehicle.faction == faction end, function(vehicle) SetWithVariants(vehicle, false) end)
    Notification.Info("All " .. tostring(faction) .. " vehicles disabled")
end

function VehicleUnlocking.UnlockAllModded()
    ForEachVehicle(IsModded, function(vehicle) SetWithVariants(vehicle, true) end)
    Notification.Info("All add-on vehicles unlocked")
end

function VehicleUnlocking.DisableAllModded()
    ForEachVehicle(IsModded, function(vehicle) SetWithVariants(vehicle, false) end)
    Notification.Info("All add-on vehicles disabled")
end

return VehicleUnlocking
