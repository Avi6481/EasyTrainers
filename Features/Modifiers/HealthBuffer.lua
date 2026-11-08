local StatModifiers = require("Utils/StatModifiers")

local HealthBuffer = {
    Enabled = false,
    Amount = 200
}

local OWNER = "HealthBuffer"
local REFILL = 0.5
local FULL = 100

local s_NextRefill = 0

local function Build()
    return {
        { gamedataStatType.Overshield, gameStatModifierType.Additive, HealthBuffer.Amount },
        { gamedataStatType.OvershieldDecayEnabled, gameStatModifierType.Multiplier, 0 }
    }
end

local function Refill(player)
    local pools = Game.GetStatPoolsSystem()
    local id = player:GetEntityID()
    if pools:GetStatPoolValue(id, gamedataStatPoolType.Overshield, true) >= FULL then return end
    pools:RequestSettingStatPoolValue(id, gamedataStatPoolType.Overshield, FULL, player, true)
end

function HealthBuffer.Update(player)
    StatModifiers.Sync(OWNER, HealthBuffer.Enabled, HealthBuffer.Amount, player:GetEntityID(), Build)
    if not HealthBuffer.Enabled then return end

    local now = os.clock()
    if now < s_NextRefill then return end
    s_NextRefill = now + REFILL
    Refill(player)
end

return HealthBuffer
