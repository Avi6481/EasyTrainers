local StatModifiers = require("Utils/StatModifiers")

local LowTrace = {
    Enabled = false
}

local OWNER = "LowTrace"
local TRACE_TIME = 10

local function Build()
    return { { gamedataStatType.HackRevealPositionModifier, gameStatModifierType.Multiplier, TRACE_TIME } }
end

function LowTrace.Update(player)
    StatModifiers.Sync(OWNER, LowTrace.Enabled, true, player:GetEntityID(), Build)
end

return LowTrace
