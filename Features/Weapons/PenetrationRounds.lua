local HeldStats = require("Features/Weapons/HeldStats")

local PenetrationRounds = {
    Enabled = false
}

local OWNERS = HeldStats.Owners("PenetrationRounds")

local function WeaponStats()
    local stat = gamedataStatType
    local add = gameStatModifierType.Additive
    local multiply = gameStatModifierType.Multiplier
    return {
        { stat.CanWeaponIgnoreArmor, add, 1 },
        { stat.TechPierceEnabled, add, 1 },
        { stat.TechPierceChargeLevel, multiply, 0 }
    }
end

function PenetrationRounds.Update()
    HeldStats.Weapon(OWNERS, PenetrationRounds.Enabled, WeaponStats, true)
end

return PenetrationRounds
