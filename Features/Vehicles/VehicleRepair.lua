local Logger = require("Core/Logger")
local Notification = require("UI/Panels/Notification/Notification")
local Vehicle = require("Utils/Vehicle")

local VehicleRepair = {}

VehicleRepair.AutoRepair = { value = false }

local AUTO_INTERVAL = 0.5

local s_NextAuto = 0

local DESTRUCTION_PARTS = {
    "hood_destruction",
    "wheel_f_l_destruction",
    "wheel_f_r_destruction",
    "bumper_b_destruction",
    "bumper_f_destruction",
    "door_f_l_destruction",
    "door_f_r_destruction",
    "trunk_destruction",
    "bumper_b_destruction_side_2",
    "bumper_f_destruction_side_2"
}

local function Try(label, callback)
    local ok, err = pcall(callback)
    if not ok then Logger.Log("VehicleRepair: " .. label .. " failed (" .. tostring(err) .. ")") end
    return ok
end

function VehicleRepair.IsVehicleDamaged()
    local vehicle = Vehicle.GetMountedVehicleSafe()
    local persistentState = vehicle and vehicle:GetVehiclePS() or nil
    return persistentState and persistentState:GetIsDestroyed() or false
end

function VehicleRepair.RestoreVisuals(vehicle)
    Try("destruction grid", function() vehicle:DestructionResetGrid() end)
    Try("glass", function() vehicle:DestructionResetGlass() end)
    Try("tires", function()
        for i = 0, 3 do vehicle:ToggleBrokenTire(i, false) end
    end)
end

local function ResetBodyParts(vehicle)
    local vehicleType = vehicle:GetVehicleType()
    if vehicleType and vehicleType.value == "Bike" then return end

    local component = vehicle:GetVehicleComponent()
    if component then
        component.bumperFrontState = 0
        component.bumperBackState = 0
    end
    for _, part in ipairs(DESTRUCTION_PARTS) do
        AnimationControllerComponent.SetInputFloat(vehicle, part, 0.0)
    end
end

function VehicleRepair.Repair(vehicle)
    Try("repair event", function() vehicle:QueueEvent(VehicleRepairEvent.new()) end)
    Try("health", function()
        Game.GetStatPoolsSystem():RequestSettingStatPoolMaxValue(vehicle:GetEntityID(), gamedataStatPoolType.Health, vehicle)
    end)
    Try("persistent state", function() vehicle:GetVehiclePS():SetIsDestroyed(false) end)
    Try("paint lock", function() vehicle:GetVehiclePS():SetVehicleVisualCustomizationnBlockedByDamage(false) end)
    Try("body parts", function() ResetBodyParts(vehicle) end)
    VehicleRepair.RestoreVisuals(vehicle)
end

function VehicleRepair.RepairMounted()
    local vehicle = Vehicle.GetMountedVehicleSafe()
    if not vehicle then
        Notification.Info("No mounted vehicle to repair")
        return false
    end

    VehicleRepair.Repair(vehicle)
    Logger.Log("VehicleRepair: repaired mounted vehicle")
    Notification.Success("Vehicle repaired", 2)
    return true
end

local function IsHurt(vehicle)
    local ok, health = pcall(function()
        return Game.GetStatPoolsSystem():GetStatPoolValue(vehicle:GetEntityID(), gamedataStatPoolType.Health, true)
    end)
    return ok and health ~= nil and health < 100
end

function VehicleRepair.Tick()
    if not VehicleRepair.AutoRepair.value then return end

    local now = os.clock()
    if now < s_NextAuto then return end
    s_NextAuto = now + AUTO_INTERVAL

    local vehicle = Vehicle.GetMountedVehicleSafe()
    if not vehicle then return end

    if IsHurt(vehicle) then
        VehicleRepair.Repair(vehicle)
    else
        VehicleRepair.RestoreVisuals(vehicle)
    end
end

return VehicleRepair
