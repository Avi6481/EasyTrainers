local Logger = require("Core/Logger")

local Inventory = {}

local function List(player, system)
    local ok, found, items = pcall(function() return system:GetItemList(player) end)
    if ok and found and type(items) == "table" then return items end
    return {}
end

function Inventory.Give(record, count)
    if not record or record == "" then return false end

    local ok, err = pcall(Game.AddToInventory, record, count or 1)
    if not ok then Logger.Log("Inventory: couldn't give " .. record .. " (" .. tostring(err) .. ")") end
    return ok
end

function Inventory.Counts(player)
    local system = Game.GetTransactionSystem()
    local counts = {}
    if not player or not system then return counts end

    for _, data in ipairs(List(player, system)) do
        local id = data:GetID()
        local record = TDBID.ToStringDEBUG(id.id)
        counts[record] = (counts[record] or 0) + (data:GetQuantity() or 1)
    end
    return counts
end

function Inventory.Find(player, record)
    local system = Game.GetTransactionSystem()
    if not player or not system then return nil end

    for _, data in ipairs(List(player, system)) do
        if TDBID.ToStringDEBUG(data:GetID().id) == record then return data end
    end
    return nil
end

function Inventory.Remove(player, record, count)
    local system = Game.GetTransactionSystem()
    if not player or not system or not record then return 0 end

    local removed = 0
    count = count or 1
    for _, data in ipairs(List(player, system)) do
        if removed >= count then break end
        local id = data:GetID()
        if TDBID.ToStringDEBUG(id.id) == record then
            local take = math.min(count - removed, data:GetQuantity() or 1)
            local ok = pcall(function() system:RemoveItem(player, id, take) end)
            if ok then removed = removed + take end
        end
    end
    return removed
end

function Inventory.RemoveMany(player, counts)
    local system = Game.GetTransactionSystem()
    if not player or not system or not counts then return 0 end

    local removed = 0
    local taken = {}
    for _, data in ipairs(List(player, system)) do
        local id = data:GetID()
        local record = TDBID.ToStringDEBUG(id.id)
        local left = (counts[record] or 0) - (taken[record] or 0)
        if left > 0 then
            local take = math.min(left, data:GetQuantity() or 1)
            local ok = pcall(function() system:RemoveItem(player, id, take) end)
            if ok then
                taken[record] = (taken[record] or 0) + take
                removed = removed + take
            end
        end
    end
    return removed
end

return Inventory
