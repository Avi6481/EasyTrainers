local StatModifiers = require("Utils/StatModifiers")

local OpticalCamoDuration = {
    Enabled = false,
    Multiplier = 2
}

local OWNER = "OpticalCamoDuration"

local function Build()
    return {
        { gamedataStatType.OpticalCamoChargesDecayRateMult, gameStatModifierType.Additive, (1 / OpticalCamoDuration.Multiplier) - 1 }
    }
end

function OpticalCamoDuration.Update(player)
    StatModifiers.Sync(OWNER, OpticalCamoDuration.Enabled, OpticalCamoDuration.Multiplier, player:GetEntityID(), Build)
end

return OpticalCamoDuration
