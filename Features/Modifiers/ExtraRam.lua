local StatModifiers = require("Utils/StatModifiers")

local ExtraRam = {
    Enabled = false,
    Amount = 10
}

local OWNER = "ExtraRam"

local function Build()
    return { { gamedataStatType.Memory, gameStatModifierType.Additive, ExtraRam.Amount } }
end

function ExtraRam.Update(player)
    StatModifiers.Sync(OWNER, ExtraRam.Enabled, ExtraRam.Amount, player:GetEntityID(), Build)
end

return ExtraRam
