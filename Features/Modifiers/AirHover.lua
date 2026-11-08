local StatModifiers = require("Utils/StatModifiers")

local AirHover = {
    Enabled = false
}

local OWNER = "AirHover"

local function Build()
    return { { gamedataStatType.HasAirHover, gameStatModifierType.Additive, 1 } }
end

function AirHover.Update(player)
    StatModifiers.Sync(OWNER, AirHover.Enabled, true, player:GetEntityID(), Build)
end

return AirHover
