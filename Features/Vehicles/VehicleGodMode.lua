local Lifecycle = require("Core/Lifecycle")
local Vehicle = require("Utils/Vehicle")
local VehicleRepair = require("Features/Vehicles/VehicleRepair")

local VehicleGodMode = {}

VehicleGodMode.Enabled = { value = false }

local SOURCE = "EasyTrainer"
local CHECK_INTERVAL = 1.0

local s_VehicleID = nil
local s_NextCheck = 0

local function SetInvulnerable(entityID, enable)
    local godModeSystem = Game.GetGodModeSystem()
    if not godModeSystem or not entityID then return end

    if enable then
        godModeSystem:AddGodMode(entityID, gameGodModeType.Invulnerable, CName.new(SOURCE))
    else
        godModeSystem:RemoveGodMode(entityID, gameGodModeType.Invulnerable, CName.new(SOURCE))
    end
end

local function Release()
    if s_VehicleID then SetInvulnerable(s_VehicleID, false) end
    s_VehicleID = nil
end

function VehicleGodMode.Tick()
    if not VehicleGodMode.Enabled.value then
        if s_VehicleID then Release() end
        return
    end

    local now = os.clock()
    if now < s_NextCheck then return end
    s_NextCheck = now + CHECK_INTERVAL

    local vehicle = Vehicle.GetMountedVehicleSafe()
    if not vehicle then return end

    local entityID = vehicle:GetEntityID()
    if not s_VehicleID or s_VehicleID.hash ~= entityID.hash then
        Release()
        SetInvulnerable(entityID, true)
        VehicleRepair.Repair(vehicle)
        s_VehicleID = entityID
    end
end

Lifecycle.Register("VehicleGodMode", {
    OnSessionEnd = function()
        s_VehicleID = nil
    end,
    OnShutdown = Release
})

return VehicleGodMode
