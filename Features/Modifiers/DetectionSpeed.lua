local StatModifiers = require("Utils/StatModifiers")

local DetectionSpeed = {
    Enabled = false,
    Percent = 50
}

local OWNER = "DetectionSpeed"

local function Build()
    return {
        { gamedataStatType.Visibility, gameStatModifierType.Multiplier, DetectionSpeed.Percent / 100 }
    }
end

function DetectionSpeed.Update(player)
    StatModifiers.Sync(OWNER, DetectionSpeed.Enabled, DetectionSpeed.Percent, player:GetEntityID(), Build)
end

return DetectionSpeed
