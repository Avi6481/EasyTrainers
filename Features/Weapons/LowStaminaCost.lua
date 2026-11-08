local HeldStats = require("Features/Weapons/HeldStats")

local LowStaminaCost = {
    Enabled = false
}

local OWNERS = HeldStats.Owners("LowStaminaCost")

local function PlayerStats()
    local stat = gamedataStatType
    local multiply = gameStatModifierType.Multiplier
    return {
        { stat.BaseMeleeAttackStaminaCost, multiply, 0.2 }
    }
end

function LowStaminaCost.Update(player)
    HeldStats.Player(OWNERS, LowStaminaCost.Enabled, player, PlayerStats)
end

return LowStaminaCost
