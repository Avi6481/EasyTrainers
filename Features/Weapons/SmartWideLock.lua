local HeldStats = require("Features/Weapons/HeldStats")

local SmartWideLock = {
    Enabled = false
}

local OWNERS = HeldStats.Owners("SmartWideLock")

local function WeaponStats()
    local stat = gamedataStatType
    local multiply = gameStatModifierType.Multiplier
    return {
        { stat.SmartGunAdsLockingAnglePitch, multiply, 3 },
        { stat.SmartGunAdsLockingAngleYaw, multiply, 3 },
        { stat.SmartGunHipLockingAnglePitch, multiply, 3 },
        { stat.SmartGunHipLockingAngleYaw, multiply, 3 },
        { stat.SmartGunAdsTargetableAnglePitch, multiply, 3 },
        { stat.SmartGunAdsTargetableAngleYaw, multiply, 3 },
        { stat.SmartGunHipTargetableAnglePitch, multiply, 3 },
        { stat.SmartGunHipTargetableAngleYaw, multiply, 3 }
    }
end

function SmartWideLock.Update()
    HeldStats.Weapon(OWNERS, SmartWideLock.Enabled, WeaponStats, true)
end

return SmartWideLock
