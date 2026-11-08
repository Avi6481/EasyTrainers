local StatModifiers = require("Utils/StatModifiers")

local RunSpeed = {
    Enabled = false,
    Multiplier = 2
}

local OWNER = "RunSpeed"

local function Build()
    return { { gamedataStatType.MaxSpeed, gameStatModifierType.Multiplier, RunSpeed.Multiplier } }
end

function RunSpeed.Update(player)
    StatModifiers.Sync(OWNER, RunSpeed.Enabled, RunSpeed.Multiplier, player:GetEntityID(), Build)
end

return RunSpeed
