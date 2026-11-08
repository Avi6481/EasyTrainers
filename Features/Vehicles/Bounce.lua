local Impulse = require("Utils/Impulse")

local Bounce = {
    Enabled = false,
    Strength = 1.5,
    Tempo = 135
}

local GRAVITY = 9.81
local PULSE_SHARPNESS = 3

local s_Beat = 0

local function Pulse(beat)
    return (0.5 + (0.5 * math.cos(beat * 2 * math.pi))) ^ PULSE_SHARPNESS
end

function Bounce.Update(vehicle, delta)
    if not Bounce.Enabled or not vehicle then
        s_Beat = 0
        return
    end

    s_Beat = (s_Beat + (delta * Bounce.Tempo / 60)) % 1
    if vehicle:IsInAir() then return end

    local push = Impulse.Mass(vehicle) * GRAVITY * Bounce.Strength * Pulse(s_Beat) * delta
    local up = vehicle:GetWorldUp()
    Impulse.Push(vehicle, -up.x * push, -up.y * push, -up.z * push)
end

return Bounce
