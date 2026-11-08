local Impulse = require("Utils/Impulse")
local Controls = require("Features/Vehicles/Controls")

local BunnyHop = {
    Enabled = false,
    Height = 2
}

local GRAVITY = 9.81
local COOLDOWN = 0.6

local s_Next = 0

function BunnyHop.Update(vehicle, now)
    if not BunnyHop.Enabled or not vehicle or not Controls.Pressed("BunnyHop") or now < s_Next then return end
    s_Next = now + COOLDOWN

    local lift = Impulse.Mass(vehicle) * math.sqrt(2 * GRAVITY * BunnyHop.Height)
    Impulse.Push(vehicle, 0, 0, lift)
end

return BunnyHop
