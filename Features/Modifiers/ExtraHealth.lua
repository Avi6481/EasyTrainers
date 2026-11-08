local StatModifiers = require("Utils/StatModifiers")

local ExtraHealth = {
    Enabled = false,
    Amount = 500
}

local OWNER = "ExtraHealth"

local function Build()
    return { { gamedataStatType.Health, gameStatModifierType.Additive, ExtraHealth.Amount } }
end

function ExtraHealth.Update(player)
    StatModifiers.Sync(OWNER, ExtraHealth.Enabled, ExtraHealth.Amount, player:GetEntityID(), Build)
end

return ExtraHealth
