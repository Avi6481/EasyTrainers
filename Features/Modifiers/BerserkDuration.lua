local StatModifiers = require("Utils/StatModifiers")

local BerserkDuration = {
    Enabled = false,
    Multiplier = 2
}

local OWNER = "BerserkDuration"

local function Build()
    return {
        { gamedataStatType.BerserkDurationBase, gameStatModifierType.Multiplier, BerserkDuration.Multiplier }
    }
end

function BerserkDuration.Update(player)
    StatModifiers.Sync(OWNER, BerserkDuration.Enabled, BerserkDuration.Multiplier, player:GetEntityID(), Build)
end

return BerserkDuration
