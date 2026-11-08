local Notify = require("Utils/Notify")
local StatPools = require("Utils/StatPools")

local FullRestore = {}

local POOLS = { "Health", "Stamina", "Memory", "Oxygen" }

local s_Pending = false

function FullRestore.Request()
    s_Pending = true
end

function FullRestore.Update()
    if not s_Pending then return end
    s_Pending = false

    for _, pool in ipairs(POOLS) do StatPools.Refill(gamedataStatPoolType[pool]) end
    Notify.Success(L("notify.self.restored"))
end

function FullRestore.Reset()
    s_Pending = false
end

return FullRestore
