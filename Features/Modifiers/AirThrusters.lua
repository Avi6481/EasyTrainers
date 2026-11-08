local StatModifiers = require("Utils/StatModifiers")

local AirThrusters = {
    Enabled = false
}

local OWNER = "AirThrusters"

local function Build()
    return { { gamedataStatType.HasAirThrusters, gameStatModifierType.Additive, 1 } }
end

function AirThrusters.Update(player)
    StatModifiers.Sync(OWNER, AirThrusters.Enabled, true, player:GetEntityID(), Build)
end

return AirThrusters
