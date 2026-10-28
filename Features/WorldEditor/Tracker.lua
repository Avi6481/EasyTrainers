local Entities = require("Utils/Entities")

local Tracker = {}

local s_Items = {}

local Safe = Entities.Safe
local Hash = Entities.Hash

local function Write(hash)
    local item = s_Items[hash]
    if not item or not EasyWorldEditor then return end
    local id = Safe(function() return item.Entity:GetEntityID() end)
    if not id then return end

    if next(item.Data) == nil then
        Safe(function() EasyWorldEditor.Untrack(id) end)
        s_Items[hash] = nil
        return
    end
    local ok, text = pcall(json.encode, item.Data)
    if ok then Safe(function() EasyWorldEditor.Track(id, text) end) end
end

local function Item(entity)
    local hash = Hash(entity)
    if not hash then return nil end
    local item = s_Items[hash]
    if not item then
        item = { Entity = entity, Data = {} }
        s_Items[hash] = item
    end
    item.Entity = entity
    return item, hash
end

function Tracker.Set(entity, role, value)
    local item, hash = Item(entity)
    if not item then return end
    item.Data[role] = value
    Write(hash)
end

function Tracker.Remove(entity)
    local hash = Hash(entity)
    if not hash then return end
    local id = Safe(function() return entity:GetEntityID() end)
    if id and EasyWorldEditor then Safe(function() EasyWorldEditor.Untrack(id) end) end
    s_Items[hash] = nil
end

function Tracker.Replace(old, new)
    local oldHash = Hash(old)
    local previous = oldHash and s_Items[oldHash]
    if not previous then return end
    Tracker.Remove(old)

    local item, hash = Item(new)
    if not item then return end
    for role, value in pairs(previous.Data) do item.Data[role] = value end
    Write(hash)
end

function Tracker.IdString(entity)
    if not EasyEntityTools then return nil end
    return Safe(function() return EasyEntityTools.GetEntityIDString(entity) end)
end

function Tracker.FindById(text)
    if not text or text == "" or not EasyEntityTools then return nil end
    local id = Safe(function() return EasyEntityTools.EntityIDFromString(text) end)
    return id and Safe(function() return Game.FindEntityByID(id) end) or nil
end

function Tracker.Load()
    local list = {}
    if not EasyWorldEditor then return list end
    local ids = Safe(function() return EasyWorldEditor.GetTrackedIDs() end)
    for _, id in ipairs(type(ids) == "table" and ids or {}) do
        local text = Safe(function() return EasyWorldEditor.GetTrackedData(id) end)
        local ok, data = pcall(json.decode, text or "")
        local entity = Safe(function() return Game.FindEntityByID(id) end)
        if entity and ok and type(data) == "table" then
            s_Items[Hash(entity)] = { Entity = entity, Data = data }
            table.insert(list, { Entity = entity, Data = data })
        else
            Safe(function() EasyWorldEditor.Untrack(id) end)
        end
    end
    return list
end

function Tracker.Forget()
    s_Items = {}
end

return Tracker
