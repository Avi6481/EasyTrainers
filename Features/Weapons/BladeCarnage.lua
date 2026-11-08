local HeldStats = require("Features/Weapons/HeldStats")

local BladeCarnage = {
    Enabled = false
}

local OWNERS = HeldStats.Owners("BladeCarnage")

local function WeaponStats()
    local stat = gamedataStatType
    local multiply = gameStatModifierType.Multiplier
    return {
        { stat.HitDismembermentFactor, multiply, 5 }
    }
end

function BladeCarnage.Update()
    HeldStats.Weapon(OWNERS, BladeCarnage.Enabled, WeaponStats)
end

return BladeCarnage
