local StatPools = require("Utils/StatPools")

local RefillRam = {
    Enabled = false
}

local INTERVAL = 0.25

local s_Next = 0

function RefillRam.Update()
    if not RefillRam.Enabled then return end

    local now = os.clock()
    if now < s_Next then return end
    s_Next = now + INTERVAL

    StatPools.Refill(gamedataStatPoolType.Memory)
end

return RefillRam
