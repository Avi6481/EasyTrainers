local HeldStats = require("Features/Weapons/HeldStats")

local SmartFastProjectiles = {
    Enabled = false
}

local OWNERS = HeldStats.Owners("SmartFastProjectiles")

local function WeaponStats()
    local stat = gamedataStatType
    local multiply = gameStatModifierType.Multiplier
    return {
        { stat.SmartGunPlayerProjectileVelocity, multiply, 3 }
    }
end

function SmartFastProjectiles.Update()
    HeldStats.Weapon(OWNERS, SmartFastProjectiles.Enabled, WeaponStats, true)
end

return SmartFastProjectiles
