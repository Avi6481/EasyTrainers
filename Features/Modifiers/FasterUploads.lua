local StatModifiers = require("Utils/StatModifiers")

local FasterUploads = {
    Enabled = false,
    Percent = 50
}

local OWNER = "FasterUploads"

local function Build()
    return {
        { gamedataStatType.QuickHackUploadTimeDecrease, gameStatModifierType.Additive, FasterUploads.Percent / 100 }
    }
end

function FasterUploads.Update(player)
    StatModifiers.Sync(OWNER, FasterUploads.Enabled, FasterUploads.Percent, player:GetEntityID(), Build)
end

return FasterUploads
