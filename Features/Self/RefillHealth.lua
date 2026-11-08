local StatPools = require("Utils/StatPools")

local RefillHealth = {
    Enabled = false
}

local INTERVAL = 0.25

local s_Next = 0

function RefillHealth.Update()
    if not RefillHealth.Enabled then return end

    local now = os.clock()
    if now < s_Next then return end
    s_Next = now + INTERVAL

    StatPools.Refill(gamedataStatPoolType.Health)
end

return RefillHealth
