local Upright = require("Features/Vehicles/Upright")

local AutoFlip = {
    Enabled = false
}

local DELAY = 1.5

local s_FlippedAt = nil

function AutoFlip.Update(vehicle, now)
    if not AutoFlip.Enabled or not vehicle or not vehicle:IsFlippedOver() then
        s_FlippedAt = nil
        return
    end

    s_FlippedAt = s_FlippedAt or now
    if now - s_FlippedAt < DELAY then return end

    s_FlippedAt = nil
    Upright.Flip(vehicle)
end

return AutoFlip
