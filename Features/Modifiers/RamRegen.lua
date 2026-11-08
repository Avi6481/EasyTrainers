local StatModifiers = require("Utils/StatModifiers")

local RamRegen = {
    Enabled = false,
    Multiplier = 3
}

local OWNER = "RamRegen"

local function Build()
    return { { gamedataStatType.MemoryRegenRateMult, gameStatModifierType.Additive, RamRegen.Multiplier - 1 } }
end

function RamRegen.Update(player)
    StatModifiers.Sync(OWNER, RamRegen.Enabled, RamRegen.Multiplier, player:GetEntityID(), Build)
end

return RamRegen
