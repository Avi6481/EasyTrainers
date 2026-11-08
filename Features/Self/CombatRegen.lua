local StatModifiers = require("Utils/StatModifiers")

local CombatRegen = {
    Enabled = false
}

local OWNER = "CombatRegen"

local function Build()
    return { { gamedataStatType.HealthInCombatRegenEnabled, gameStatModifierType.Additive, 1 } }
end

function CombatRegen.Update(player)
    StatModifiers.Sync(OWNER, CombatRegen.Enabled, true, player:GetEntityID(), Build)
end

return CombatRegen
