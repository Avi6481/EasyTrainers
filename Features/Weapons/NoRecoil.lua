local HeldStats = require("Features/Weapons/HeldStats")

local NoRecoil = {
    Enabled = false
}

local OWNERS = HeldStats.Owners("NoRecoil")

local function WeaponStats()
    local stat = gamedataStatType
    local multiply = gameStatModifierType.Multiplier
    return {
        { stat.RecoilKickMin, multiply, 0 },
        { stat.RecoilKickMax, multiply, 0 },
        { stat.RecoilKickMinADS, multiply, 0 },
        { stat.RecoilKickMaxADS, multiply, 0 },
        { stat.RecoilMaxLength, multiply, 0 },
        { stat.RecoilMaxLengthADS, multiply, 0 }
    }
end

function NoRecoil.Update()
    HeldStats.Weapon(OWNERS, NoRecoil.Enabled, WeaponStats)
end

return NoRecoil
