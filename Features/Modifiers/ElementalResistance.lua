local StatModifiers = require("Utils/StatModifiers")

local ElementalResistance = {
    Enabled = false,
    Percent = 50
}

local OWNER = "ElementalResistance"

local function Build()
    return {
        { gamedataStatType.ThermalResistance, gameStatModifierType.Additive, ElementalResistance.Percent },
        { gamedataStatType.ChemicalResistance, gameStatModifierType.Additive, ElementalResistance.Percent },
        { gamedataStatType.ElectricResistance, gameStatModifierType.Additive, ElementalResistance.Percent }
    }
end

function ElementalResistance.Update(player)
    StatModifiers.Sync(OWNER, ElementalResistance.Enabled, ElementalResistance.Percent, player:GetEntityID(), Build)
end

return ElementalResistance
