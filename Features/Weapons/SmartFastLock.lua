local HeldStats = require("Features/Weapons/HeldStats")

local SmartFastLock = {
    Enabled = false
}

local OWNERS = HeldStats.Owners("SmartFastLock")

local function WeaponStats()
    local stat = gamedataStatType
    local multiply = gameStatModifierType.Multiplier
    return {
        { stat.SmartGunAdsTimeToLock, multiply, 0.1 },
        { stat.SmartGunHipTimeToLock, multiply, 0.1 }
    }
end

function SmartFastLock.Update()
    HeldStats.Weapon(OWNERS, SmartFastLock.Enabled, WeaponStats, true)
end

return SmartFastLock
