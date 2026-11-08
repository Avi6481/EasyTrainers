local StatModifiers = require("Utils/StatModifiers")

local QuickhackSpread = {
    Enabled = false,
    Amount = 3
}

local OWNER = "QuickhackSpread"

local function Build()
    return {
        { gamedataStatType.QuickHackSpreadNumber, gameStatModifierType.Additive, QuickhackSpread.Amount }
    }
end

function QuickhackSpread.Update(player)
    StatModifiers.Sync(OWNER, QuickhackSpread.Enabled, QuickhackSpread.Amount, player:GetEntityID(), Build)
end

return QuickhackSpread
