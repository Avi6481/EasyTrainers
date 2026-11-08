local StatModifiers = require("Utils/StatModifiers")

local CarryCapacity = {
    Enabled = false,
    Amount = 1000
}

local OWNER = "CarryCapacity"

local function Build()
    return { { gamedataStatType.CarryCapacity, gameStatModifierType.Additive, CarryCapacity.Amount } }
end

function CarryCapacity.Update(player)
    StatModifiers.Sync(OWNER, CarryCapacity.Enabled, CarryCapacity.Amount, player:GetEntityID(), Build)
end

return CarryCapacity
