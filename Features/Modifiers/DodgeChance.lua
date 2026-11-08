local StatModifiers = require("Utils/StatModifiers")

local DodgeChance = {
    Enabled = false,
    Percent = 50
}

local OWNER = "DodgeChance"

local function Build()
    return { { gamedataStatType.Evasion, gameStatModifierType.Additive, DodgeChance.Percent } }
end

function DodgeChance.Update(player)
    StatModifiers.Sync(OWNER, DodgeChance.Enabled, DodgeChance.Percent, player:GetEntityID(), Build)
end

return DodgeChance
