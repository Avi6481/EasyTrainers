local HeldStats = require("Features/Weapons/HeldStats")

local HipfireAccuracy = {
    Enabled = false
}

local OWNERS = HeldStats.Owners("HipfireAccuracy")

local function WeaponStats()
    local stat = gamedataStatType
    local multiply = gameStatModifierType.Multiplier
    return {
        { stat.SpreadDefaultX, multiply, 0 },
        { stat.SpreadDefaultY, multiply, 0 },
        { stat.SpreadMinX, multiply, 0 },
        { stat.SpreadMinY, multiply, 0 },
        { stat.SpreadMaxX, multiply, 0 },
        { stat.SpreadMaxY, multiply, 0 },
        { stat.SpreadChangePerShot, multiply, 0 }
    }
end

function HipfireAccuracy.Update()
    HeldStats.Weapon(OWNERS, HipfireAccuracy.Enabled, WeaponStats, true)
end

return HipfireAccuracy
