local Force = require("Utils/Force")
local Bindings = require("Controls/Bindings")

local VehicleNitro = {}

VehicleNitro.Multiplier = { value = 1.5, min = 1.0, max = 100.0, step = 0.5, unit = "x", enabled = false }

local BASE_FORCE = 50000.0
local IMPULSE_STEP = 0.05

function VehicleNitro.Tick()
    if not VehicleNitro.Multiplier.enabled or not Bindings.IsActionDown("NITRO") then return end

    local player = Game.GetPlayer()
    local vehicle = player and player:GetMountedVehicle() or nil
    if not vehicle then return end

    vehicle:ToggleHorn(false, false)
    Force.ApplyNitroImpulse(vehicle, BASE_FORCE, VehicleNitro.Multiplier.value * 100, IMPULSE_STEP)
end

return VehicleNitro
