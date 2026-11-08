local HeldStats = require("Features/Weapons/HeldStats")

local SmartPerfectAccuracy = {
    Enabled = false
}

local OWNERS = HeldStats.Owners("SmartPerfectAccuracy")

local function WeaponStats()
    local stat = gamedataStatType
    local add = gameStatModifierType.Additive
    local multiply = gameStatModifierType.Multiplier
    return {
        { stat.SmartGunHitProbability, add, 1 },
        { stat.SmartGunMissRadius, multiply, 0 },
        { stat.SmartGunSpreadMultiplier, multiply, 0 }
    }
end

function SmartPerfectAccuracy.Update()
    HeldStats.Weapon(OWNERS, SmartPerfectAccuracy.Enabled, WeaponStats, true)
end

return SmartPerfectAccuracy
