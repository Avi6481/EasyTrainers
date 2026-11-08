local HeldStats = require("Features/Weapons/HeldStats")

local HighBlock = {
    Enabled = false
}

local OWNERS = HeldStats.Owners("HighBlock")

local function PlayerStats()
    local stat = gamedataStatType
    local multiply = gameStatModifierType.Multiplier
    return {
        { stat.BlockFactor, multiply, 10 }
    }
end

function HighBlock.Update(player)
    HeldStats.Player(OWNERS, HighBlock.Enabled, player, PlayerStats)
end

return HighBlock
