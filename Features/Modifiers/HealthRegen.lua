local StatModifiers = require("Utils/StatModifiers")

local HealthRegen = {
    Enabled = false,
    Rate = 5
}

local OWNER = "HealthRegen"
local FULL = 100

local function Build()
    local stat, add, multiply = gamedataStatType, gameStatModifierType.Additive, gameStatModifierType.Multiplier
    return {
        { stat.HealthGeneralRegenRateAdd, add, HealthRegen.Rate },
        { stat.HealthInCombatRegenEnabled, add, 1 },
        { stat.HealthInCombatRegenEndThreshold, add, FULL },
        { stat.HealthOutOfCombatRegenEndThreshold, add, FULL },
        { stat.HealthInCombatStartDelay, multiply, 0 },
        { stat.HealthInCombatRegenDelayOnChange, multiply, 0 },
        { stat.HealthOutOfCombatRegenDelayOnChange, multiply, 0 }
    }
end

function HealthRegen.Update(player)
    StatModifiers.Sync(OWNER, HealthRegen.Enabled, HealthRegen.Rate, player:GetEntityID(), Build)
end

return HealthRegen
