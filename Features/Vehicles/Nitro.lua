local Impulse = require("Utils/Impulse")
local Controls = require("Features/Vehicles/Controls")

local Nitro = {
    Enabled = false,
    Strength = 10
}

function Nitro.Update(vehicle, delta)
    if not Nitro.Enabled or not vehicle or not Controls.Held("Nitro") then return end

    local forward = vehicle:GetWorldForward()
    local amount = Impulse.Mass(vehicle) * Nitro.Strength * delta
    Impulse.Push(vehicle, forward.x * amount, forward.y * amount, forward.z * amount)
end

return Nitro
