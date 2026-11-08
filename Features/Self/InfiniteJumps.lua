local StatModifiers = require("Utils/StatModifiers")

local InfiniteJumps = {
    Enabled = false
}

local OWNER = "InfiniteJumps"

local s_JumpCount = nil

local function Build()
    return {
        { gamedataStatType.HasDoubleJump, gameStatModifierType.Additive, 1 },
        { gamedataStatType.HasChargeJump, gameStatModifierType.Additive, -1 },
        { gamedataStatType.HasAirHover, gameStatModifierType.Additive, -1 }
    }
end

local function ResetCount(stateContext)
    if not InfiniteJumps.Enabled then return end
    stateContext:SetPermanentIntParameter(s_JumpCount, 0, true)
end

function InfiniteJumps.Initialize()
    s_JumpCount = CName.new("currentNumberOfJumps")
    ObserveAfter("DoubleJumpEvents", "OnEnter", function(_, stateContext) ResetCount(stateContext) end)
end

function InfiniteJumps.Update(player)
    StatModifiers.Sync(OWNER, InfiniteJumps.Enabled, true, player:GetEntityID(), Build)
end

return InfiniteJumps
