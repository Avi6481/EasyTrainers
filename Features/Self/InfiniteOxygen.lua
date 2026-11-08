local StatPools = require("Utils/StatPools")

local InfiniteOxygen = {
    Enabled = false
}

local INTERVAL = 0.25

local s_Next = 0

function InfiniteOxygen.Update()
    if not InfiniteOxygen.Enabled then return end

    local now = os.clock()
    if now < s_Next then return end
    s_Next = now + INTERVAL

    StatPools.Refill(gamedataStatPoolType.Oxygen)
end

return InfiniteOxygen
