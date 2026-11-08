local HeldStats = require("Features/Weapons/HeldStats")

local InfiniteCombo = {
    Enabled = false
}

local OWNERS = HeldStats.Owners("InfiniteCombo")

local function WeaponStats()
    local stat = gamedataStatType
    local add = gameStatModifierType.Additive
    return {
        { stat.CanWeaponInfinitlyCombo, add, 1 }
    }
end

local function PlayerStats()
    local stat = gamedataStatType
    local add = gameStatModifierType.Additive
    return {
        { stat.CanMeleeInfinitelyCombo, add, 1 }
    }
end

function InfiniteCombo.Update(player)
    HeldStats.Weapon(OWNERS, InfiniteCombo.Enabled, WeaponStats)
    HeldStats.Player(OWNERS, InfiniteCombo.Enabled, player, PlayerStats)
end

return InfiniteCombo
