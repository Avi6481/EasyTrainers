local StatModifiers = require("Utils/StatModifiers")

local SandevistanTimeScale = {
    Enabled = false,
    Multiplier = 0.5
}

local OWNER = "SandevistanTimeScale"

local function Build()
    return { { gamedataStatType.TimeDilationSandevistanTimeScale, gameStatModifierType.Multiplier, SandevistanTimeScale.Multiplier } }
end

function SandevistanTimeScale.Update(player)
    StatModifiers.Sync(OWNER, SandevistanTimeScale.Enabled, SandevistanTimeScale.Multiplier, player:GetEntityID(), Build)
end

return SandevistanTimeScale
