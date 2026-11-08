local HeldStats = require("Features/Weapons/HeldStats")

local ShotgunSpray = {
    Enabled = false
}

local OWNERS = HeldStats.Owners("ShotgunSpray")

local function WeaponStats()
    local stat = gamedataStatType
    local add = gameStatModifierType.Additive
    return {
        { stat.ProjectilesPerShot, add, 12 }
    }
end

function ShotgunSpray.Update()
    HeldStats.Weapon(OWNERS, ShotgunSpray.Enabled, WeaponStats, true)
end

return ShotgunSpray
