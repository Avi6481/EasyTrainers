local Logger = require("Core/Logger")

local QuickhackCost = {
    Enabled = false,
    Percent = 50
}

local s_Failed = false

local function UsesRam(action)
    local executor = action:GetExecutor()
    if not executor or not executor:IsPlayer() then return false end

    local record = action:GetObjectActionRecord()
    if not record or record:GetCostsCount() == 0 then return false end

    local cost = record:GetCostsItem(0)
    if not cost or not cost:IsA("gamedataStatPoolCost_Record") then return false end

    local pool = cost:StatPool()
    return pool ~= nil and pool:StatPoolType() == gamedataStatPoolType.Memory
end

local function Cut(action, cost)
    if cost <= 0 or not UsesRam(action) then return cost end
    return math.max(0, math.floor((cost * (1 - (QuickhackCost.Percent / 100))) + 0.5))
end

local function GetCost(action, wrapped)
    local cost = wrapped()
    if not QuickhackCost.Enabled then return cost end

    local ok, result = pcall(Cut, action, cost)
    if ok then return result end

    if not s_Failed then
        s_Failed = true
        Logger.Log("Quickhack cost failed: " .. tostring(result))
    end
    return cost
end

function QuickhackCost.Initialize()
    Override("BaseScriptableAction", "GetCost", GetCost)
end

return QuickhackCost
