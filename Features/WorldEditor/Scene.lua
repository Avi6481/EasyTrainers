local Entities = require("Utils/Entities")
local Tracker = require("Features/WorldEditor/Tracker")
local Changes = require("Features/WorldEditor/Changes")

local Scene = {}

local EDIT_SETTLE = 0.5

local s_Added = {}
local s_Edited = {}
local s_PlacedList = nil
local s_IsPlaced = nil
local s_Focus = {}

local Hash = Entities.Hash
local IsValid = Entities.IsValid

local function Find(hash)
    for index, entry in ipairs(s_Added) do
        if entry.Hash == hash then return index end
    end
    return nil
end

local function IsPlaced(entity)
    return s_IsPlaced ~= nil and s_IsPlaced(entity) ~= nil
end

function Scene.SetPlacedSource(list, check)
    s_PlacedList, s_IsPlaced = list, check
end

function Scene.Add(entity, name, kind)
    local hash = Hash(entity)
    if not hash or Find(hash) or IsPlaced(entity) then return false end
    table.insert(s_Added, { Entity = entity, Hash = hash, Name = name or "Entity", Kind = kind or "Prop" })
    Tracker.Set(entity, "Scene", { Name = name or "Entity", Kind = kind or "Prop" })
    Changes.Mark()
    return true
end

function Scene.Remove(entity)
    local index = Find(Hash(entity))
    if not index then return false end
    table.remove(s_Added, index)
    Tracker.Set(entity, "Scene", nil)
    Changes.Mark()
    return true
end

function Scene.Contains(entity)
    local hash = Hash(entity)
    return hash ~= nil and (Find(hash) ~= nil or IsPlaced(entity))
end

function Scene.GetAll()
    local list = {}
    for _, placed in ipairs(s_PlacedList and s_PlacedList() or {}) do
        table.insert(list, { Entity = placed.Entity, Name = placed.Name, Kind = "Prop", Placed = true })
    end
    for _, entry in ipairs(s_Added) do
        table.insert(list, { Entity = entry.Entity, Name = entry.Name, Kind = entry.Kind, Placed = false })
    end
    return list
end

function Scene.Count()
    return #(s_PlacedList and s_PlacedList() or {}) + #s_Added
end

function Scene.Replace(old, new)
    local oldHash, newHash = Hash(old), Hash(new)
    if not oldHash then return end
    local index = Find(oldHash)
    if index then s_Added[index].Entity, s_Added[index].Hash = new, newHash end
    if s_Edited[oldHash] then s_Edited[newHash or oldHash] = s_Edited[oldHash] end
    for _, focus in pairs(s_Focus) do
        if focus.Hash == oldHash then focus.Entity, focus.Hash = new, newHash end
    end
end

function Scene.SetFocus(depth, entity, name)
    s_Focus[depth] = entity and { Entity = entity, Hash = Hash(entity), Name = name or "Entity" } or nil
end

function Scene.GetFocus(depth)
    local focus = s_Focus[depth]
    if focus and not IsValid(focus.Entity) then return nil end
    return focus
end

function Scene.Touch(entity)
    local hash = Hash(entity)
    if hash then s_Edited[hash] = os.clock() end
    Changes.Mark()
end

function Scene.IsEditingAny()
    local now = os.clock()
    for _, at in pairs(s_Edited) do
        if now - at < EDIT_SETTLE then return true end
    end
    return false
end

function Scene.GetName(entity)
    local hash = Hash(entity)
    local index = hash and Find(hash)
    return index and s_Added[index].Name or nil
end

function Scene.IsEditing(entity)
    local hash = Hash(entity)
    local at = hash and s_Edited[hash]
    return at ~= nil and os.clock() - at < EDIT_SETTLE
end

function Scene.Tick()
    for index = #s_Added, 1, -1 do
        if not IsValid(s_Added[index].Entity) then table.remove(s_Added, index) end
    end
    local now = os.clock()
    for hash, at in pairs(s_Edited) do
        if now - at >= EDIT_SETTLE then s_Edited[hash] = nil end
    end
end

function Scene.Forget()
    s_Added = {}
    s_Edited = {}
    s_Focus = {}
end

return Scene
