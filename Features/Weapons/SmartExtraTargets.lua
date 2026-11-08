local HeldStats = require("Features/Weapons/HeldStats")

local SmartExtraTargets = {
    Enabled = false
}

local OWNERS = HeldStats.Owners("SmartExtraTargets")

local function WeaponStats()
    local stat = gamedataStatType
    local add = gameStatModifierType.Additive
    return {
        { stat.SmartGunAdsMaxLockedTargets, add, 6 },
        { stat.SmartGunHipMaxLockedTargets, add, 6 }
    }
end

function SmartExtraTargets.Update()
    HeldStats.Weapon(OWNERS, SmartExtraTargets.Enabled, WeaponStats, true)
end

return SmartExtraTargets
