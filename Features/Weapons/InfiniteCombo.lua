local HeldStats = require("Features/Weapons/HeldStats")

local InfiniteCombo = {
    Enabled = false
}

local OWNERS = HeldStats.Owners("InfiniteCombo")

local function ComboStats()
    local stat = gamedataStatType
    local add = gameStatModifierType.Additive
    return {
        { stat.CanWeaponInfinitlyCombo, add, 1 },
        { stat.CanMeleeInfinitelyCombo, add, 1 }
    }
end

function InfiniteCombo.Update(player)
    HeldStats.Weapon(OWNERS, InfiniteCombo.Enabled, ComboStats)
    HeldStats.Player(OWNERS, InfiniteCombo.Enabled, player, ComboStats)
end

return InfiniteCombo
