local StatModifiers = require("Utils/StatModifiers")

local ExplosionResistance = {
    Enabled = false,
    Percent = 50
}

local OWNER = "ExplosionResistance"

local function Build()
    return {
        { gamedataStatType.ExplosionResistance, gameStatModifierType.Additive, ExplosionResistance.Percent }
    }
end

function ExplosionResistance.Update(player)
    StatModifiers.Sync(OWNER, ExplosionResistance.Enabled, ExplosionResistance.Percent, player:GetEntityID(), Build)
end

return ExplosionResistance
