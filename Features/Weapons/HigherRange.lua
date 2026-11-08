local HeldStats = require("Features/Weapons/HeldStats")

local HigherRange = {
    Enabled = false
}

local OWNERS = HeldStats.Owners("HigherRange")

local function WeaponStats()
    local stat = gamedataStatType
    local multiply = gameStatModifierType.Multiplier
    return {
        { stat.EffectiveRange, multiply, 25 },
        { stat.MaximumRange, multiply, 25 }
    }
end

function HigherRange.Update()
    HeldStats.Weapon(OWNERS, HigherRange.Enabled, WeaponStats, true)
end

return HigherRange
