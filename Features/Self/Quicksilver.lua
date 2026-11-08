local StatModifiers = require("Utils/StatModifiers")
local StatPools = require("Utils/StatPools")

local Quicksilver = {
    Enabled = false
}

local OWNER = "Quicksilver"
local SLOWDOWN = 0.1
local REFILL_INTERVAL = 0.25

local s_NextRefill = 0

local function Build()
    return { { gamedataStatType.TimeDilationSandevistanTimeScale, gameStatModifierType.Multiplier, SLOWDOWN } }
end

function Quicksilver.Update(player)
    StatModifiers.Sync(OWNER, Quicksilver.Enabled, true, player:GetEntityID(), Build)
    if not Quicksilver.Enabled then return end

    local now = os.clock()
    if now < s_NextRefill then return end
    s_NextRefill = now + REFILL_INTERVAL

    StatPools.Refill(gamedataStatPoolType.SandevistanCharge)
end

return Quicksilver
