local StatModifiers = require("Utils/StatModifiers")

local MeleeResistance = {
    Enabled = false,
    Percent = 50
}

local OWNER = "MeleeResistance"

local function Build()
    return {
        { gamedataStatType.MeleeResistance, gameStatModifierType.Additive, MeleeResistance.Percent }
    }
end

function MeleeResistance.Update(player)
    StatModifiers.Sync(OWNER, MeleeResistance.Enabled, MeleeResistance.Percent, player:GetEntityID(), Build)
end

return MeleeResistance
