local HeldStats = require("Features/Weapons/HeldStats")

local AlwaysCrit = {
    Enabled = false
}

local OWNERS = HeldStats.Owners("AlwaysCrit")

local function PlayerStats()
    local stat = gamedataStatType
    local add = gameStatModifierType.Additive
    return {
        { stat.CritChance, add, 100 }
    }
end

function AlwaysCrit.Update(player)
    HeldStats.Player(OWNERS, AlwaysCrit.Enabled, player, PlayerStats)
end

return AlwaysCrit
