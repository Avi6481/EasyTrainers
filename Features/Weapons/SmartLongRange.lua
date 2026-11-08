local HeldStats = require("Features/Weapons/HeldStats")

local SmartLongRange = {
    Enabled = false
}

local OWNERS = HeldStats.Owners("SmartLongRange")

local function WeaponStats()
    local stat = gamedataStatType
    local multiply = gameStatModifierType.Multiplier
    return {
        { stat.SmartGunTargetAcquisitionRange, multiply, 4 }
    }
end

function SmartLongRange.Update()
    HeldStats.Weapon(OWNERS, SmartLongRange.Enabled, WeaponStats, true)
end

return SmartLongRange
