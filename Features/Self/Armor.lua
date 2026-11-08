local StatModifiers = require("Utils/StatModifiers")

local Armor = {
    Enabled = false,
    Amount = 1000
}

local OWNER = "Armor"

local function Build()
    return { { gamedataStatType.Armor, gameStatModifierType.Additive, Armor.Amount } }
end

function Armor.Update(player)
    StatModifiers.Sync(OWNER, Armor.Enabled, Armor.Amount, player:GetEntityID(), Build)
end

return Armor
