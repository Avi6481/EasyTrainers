local StatModifiers = require("Utils/StatModifiers")

local StrongerHeals = {
    Enabled = false,
    Percent = 100
}

local OWNER = "StrongerHeals"

local function Build()
    return {
        { gamedataStatType.HealingItemsEffectPercentBonus, gameStatModifierType.Additive, StrongerHeals.Percent / 100 }
    }
end

function StrongerHeals.Update(player)
    StatModifiers.Sync(OWNER, StrongerHeals.Enabled, StrongerHeals.Percent, player:GetEntityID(), Build)
end

return StrongerHeals
