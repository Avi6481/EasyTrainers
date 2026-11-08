local HeldStats = require("Features/Weapons/HeldStats")

local RapidFire = {
    Enabled = false
}

local OWNERS = HeldStats.Owners("RapidFire")

local function WeaponStats()
    local stat = gamedataStatType
    local multiply = gameStatModifierType.Multiplier
    return {
        { stat.CycleTime, multiply, 0.1 },
        { stat.CycleTime_Burst, multiply, 0.1 }
    }
end

function RapidFire.Update()
    HeldStats.Weapon(OWNERS, RapidFire.Enabled, WeaponStats, true)
end

return RapidFire
