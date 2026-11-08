local StatModifiers = require("Utils/StatModifiers")

local JumpHeight = {
    Enabled = false,
    Multiplier = 3
}

local OWNER = "JumpHeight"

local function Build()
    return { { gamedataStatType.JumpHeight, gameStatModifierType.Multiplier, JumpHeight.Multiplier } }
end

function JumpHeight.Update(player)
    StatModifiers.Sync(OWNER, JumpHeight.Enabled, JumpHeight.Multiplier, player:GetEntityID(), Build)
end

return JumpHeight
