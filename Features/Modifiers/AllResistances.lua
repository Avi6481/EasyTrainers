local StatModifiers = require("Utils/StatModifiers")

local AllResistances = {
    Enabled = false,
    Percent = 50
}

local OWNER = "AllResistances"

local function Build()
    local stat, add, percent = gamedataStatType, gameStatModifierType.Additive, AllResistances.Percent
    return {
        { stat.ThermalResistance, add, percent },
        { stat.ChemicalResistance, add, percent },
        { stat.ElectricResistance, add, percent },
        { stat.ExplosionResistance, add, percent },
        { stat.MeleeResistance, add, percent },
        { stat.DamageOverTimeResistance, add, percent }
    }
end

function AllResistances.Update(player)
    StatModifiers.Sync(OWNER, AllResistances.Enabled, AllResistances.Percent, player:GetEntityID(), Build)
end

return AllResistances
