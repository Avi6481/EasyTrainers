local HeldStats = require("Features/Weapons/HeldStats")

local InsaneCritDamage = {
    Enabled = false
}

local OWNERS = HeldStats.Owners("InsaneCritDamage")

local function PlayerStats()
    local stat = gamedataStatType
    local add = gameStatModifierType.Additive
    return {
        { stat.CritDamage, add, 1000 }
    }
end

function InsaneCritDamage.Update(player)
    HeldStats.Player(OWNERS, InsaneCritDamage.Enabled, player, PlayerStats)
end

return InsaneCritDamage
