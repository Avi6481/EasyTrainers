local StatPools = {}

local FULL = 100

local function Context()
    local player = Game.GetPlayer()
    local system = Game.GetStatPoolsSystem()
    if not player or not system then return nil, nil end
    return player, system
end

function StatPools.Get(pool)
    local player, system = Context()
    if not player then return nil end
    return system:GetStatPoolValue(player:GetEntityID(), pool, true)
end

function StatPools.Set(pool, percent)
    local player, system = Context()
    if not player then return false end

    system:RequestSettingStatPoolValue(player:GetEntityID(), pool, percent, player, true, true)
    return true
end

function StatPools.Refill(pool)
    local value = StatPools.Get(pool)
    if not value or value >= FULL then return end
    StatPools.Set(pool, FULL)
end

return StatPools
