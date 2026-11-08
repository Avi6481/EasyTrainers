local StatModifiers = require("Utils/StatModifiers")

local SandevistanDuration = {
    Enabled = false,
    Multiplier = 2
}

local OWNER = "SandevistanDuration"

local function Build()
    return { { gamedataStatType.TimeDilationSandevistanDuration, gameStatModifierType.Multiplier, SandevistanDuration.Multiplier } }
end

function SandevistanDuration.Update(player)
    StatModifiers.Sync(OWNER, SandevistanDuration.Enabled, SandevistanDuration.Multiplier, player:GetEntityID(), Build)
end

return SandevistanDuration
