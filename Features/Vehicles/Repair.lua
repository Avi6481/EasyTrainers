local Logger = require("Core/Logger")

local Repair = {
    Auto = false
}

local AUTO_INTERVAL = 0.5
local FULL_HEALTH = 100

local PARTS = {
    "hood_destruction", "trunk_destruction",
    "wheel_f_l_destruction", "wheel_f_r_destruction",
    "bumper_f_destruction", "bumper_b_destruction",
    "bumper_f_destruction_side_2", "bumper_b_destruction_side_2",
    "door_f_l_destruction", "door_f_r_destruction"
}

local s_NextAuto = 0
local s_Failed = {}

local function Try(name, callback)
    local ok, err = pcall(callback)
    if not ok and not s_Failed[name] then
        s_Failed[name] = true
        Logger.Log("Vehicle repair " .. name .. " failed: " .. tostring(err))
    end
end

local function Visuals(vehicle)
    Try("dents", function() vehicle:DestructionResetGrid() end)
    Try("glass", function() vehicle:DestructionResetGlass() end)
    Try("tires", function()
        for index = 0, 3 do vehicle:ToggleBrokenTire(index, false) end
    end)
end

local function Body(vehicle)
    local kind = vehicle:GetVehicleType()
    if kind and kind.value == "Bike" then return end

    local component = vehicle:GetVehicleComponent()
    if component then
        component.bumperFrontState = 0
        component.bumperBackState = 0
    end
    for _, part in ipairs(PARTS) do AnimationControllerComponent.SetInputFloat(vehicle, part, 0) end
end

function Repair.Fix(vehicle)
    Try("event", function() vehicle:QueueEvent(VehicleRepairEvent.new()) end)
    Try("health", function()
        Game.GetStatPoolsSystem():RequestSettingStatPoolMaxValue(vehicle:GetEntityID(), gamedataStatPoolType.Health, vehicle)
    end)
    Try("state", function() vehicle:GetVehiclePS():SetIsDestroyed(false) end)
    Try("paint lock", function() vehicle:GetVehiclePS():SetVehicleVisualCustomizationnBlockedByDamage(false) end)
    Try("body", function() Body(vehicle) end)
    Visuals(vehicle)
end

local function Hurt(vehicle)
    local ok, health = pcall(function()
        return Game.GetStatPoolsSystem():GetStatPoolValue(vehicle:GetEntityID(), gamedataStatPoolType.Health, true)
    end)
    return ok and type(health) == "number" and health < FULL_HEALTH
end

function Repair.Update(vehicle, now)
    if not Repair.Auto or not vehicle or now < s_NextAuto then return end
    s_NextAuto = now + AUTO_INTERVAL

    if Hurt(vehicle) then
        Repair.Fix(vehicle)
    else
        Visuals(vehicle)
    end
end

return Repair
