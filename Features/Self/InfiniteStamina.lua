local StatModifiers = require("Utils/StatModifiers")

local InfiniteStamina = {
    Enabled = false
}

local OWNER = "InfiniteStamina"

local function Build()
    return { { gamedataStatType.CanIgnoreStamina, gameStatModifierType.Additive, 1 } }
end

function InfiniteStamina.Update(player)
    StatModifiers.Sync(OWNER, InfiniteStamina.Enabled, true, player:GetEntityID(), Build)
end

return InfiniteStamina
