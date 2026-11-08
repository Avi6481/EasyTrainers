local HeldStats = require("Features/Weapons/HeldStats")

local AdsAccuracy = {
    Enabled = false
}

local OWNERS = HeldStats.Owners("AdsAccuracy")

local function WeaponStats()
    local stat = gamedataStatType
    local multiply = gameStatModifierType.Multiplier
    return {
        { stat.SpreadAdsDefaultX, multiply, 0 },
        { stat.SpreadAdsDefaultY, multiply, 0 },
        { stat.SpreadAdsMinX, multiply, 0 },
        { stat.SpreadAdsMinY, multiply, 0 },
        { stat.SpreadAdsMaxX, multiply, 0 },
        { stat.SpreadAdsMaxY, multiply, 0 },
        { stat.SpreadAdsChangePerShot, multiply, 0 }
    }
end

function AdsAccuracy.Update()
    HeldStats.Weapon(OWNERS, AdsAccuracy.Enabled, WeaponStats, true)
end

return AdsAccuracy
