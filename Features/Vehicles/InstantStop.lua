local Impulse = require("Utils/Impulse")
local Controls = require("Features/Vehicles/Controls")

local InstantStop = {
    Enabled = false
}

function InstantStop.Update(vehicle)
    if not InstantStop.Enabled or not vehicle or not Controls.Pressed("Stop") then return end

    local velocity = vehicle:GetLinearVelocity()
    local mass = Impulse.Mass(vehicle)
    Impulse.Push(vehicle, -velocity.x * mass, -velocity.y * mass, -velocity.z * mass)
end

return InstantStop
