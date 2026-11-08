local StatModifiers = require("Utils/StatModifiers")

local KerenzikovDuration = {
    Enabled = false,
    Multiplier = 2
}

local OWNER = "KerenzikovDuration"

local function Build()
    return {
        { gamedataStatType.TimeDilationKerenzikovDuration, gameStatModifierType.Multiplier, KerenzikovDuration.Multiplier }
    }
end

function KerenzikovDuration.Update(player)
    StatModifiers.Sync(OWNER, KerenzikovDuration.Enabled, KerenzikovDuration.Multiplier, player:GetEntityID(), Build)
end

return KerenzikovDuration
