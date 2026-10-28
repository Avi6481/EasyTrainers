local Scene = {}

local EDIT_SETTLE = 0.5

local s_Added = {}
local s_Edited = {}
local s_PlacedSource = nil
local s_Focus = nil

local function Safe(callback)
    local ok, value = pcall(callback)
    if ok then return value end
    return nil
end

local function Hash(entity)
    return entity and Safe(function() return tostring(entity:GetEntityID().hash) end)
end

local function IsValid(entity)
    local id = Safe(function() return entity:GetEntityID() end)
    return id ~= nil and Safe(function() return Game.FindEntityByID(id) end) ~= nil
end

local function Find(hash)
    for index, entry in ipairs(s_Added) do
        if entry.Hash == hash then return index end
    end
    return nil
end

function Scene.SetPlacedSource(source)
    s_PlacedSource = source
end

function Scene.Add(entity, name, kind)
    local hash = Hash(entity)
    if not hash or Find(hash) then return false end
    for _, placed in ipairs(s_PlacedSource and s_PlacedSource() or {}) do
        if Hash(placed.Entity) == hash then return false end
    end
    table.insert(s_Added, { Entity = entity, Hash = hash, Name = name or "Entity", Kind = kind or "Prop" })
    return true
end

function Scene.Remove(entity)
    local index = Find(Hash(entity))
    if not index then return false end
    table.remove(s_Added, index)
    return true
end

function Scene.Contains(entity)
    local hash = Hash(entity)
    if not hash then return false end
    if Find(hash) then return true end
    for _, placed in ipairs(s_PlacedSource and s_PlacedSource() or {}) do
        if Hash(placed.Entity) == hash then return true end
    end
    return false
end

function Scene.GetAll()
    local list = {}
    for _, placed in ipairs(s_PlacedSource and s_PlacedSource() or {}) do
        table.insert(list, { Entity = placed.Entity, Name = placed.Name, Kind = "Prop", Placed = true })
    end
    for _, entry in ipairs(s_Added) do
        table.insert(list, { Entity = entry.Entity, Name = entry.Name, Kind = entry.Kind, Placed = false })
    end
    return list
end

function Scene.Replace(old, new)
    local oldHash, newHash = Hash(old), Hash(new)
    local index = oldHash and Find(oldHash)
    if index then s_Added[index].Entity, s_Added[index].Hash = new, newHash end
    if oldHash and s_Edited[oldHash] then s_Edited[newHash or oldHash] = s_Edited[oldHash] end
    if s_Focus and oldHash and Hash(s_Focus.Entity) == oldHash then s_Focus.Entity = new end
end

function Scene.SetFocus(entity, name)
    s_Focus = entity and { Entity = entity, Name = name or "Entity" } or nil
end

function Scene.GetFocus()
    if s_Focus and not IsValid(s_Focus.Entity) then return nil end
    return s_Focus
end

function Scene.Touch(entity)
    local hash = Hash(entity)
    if hash then s_Edited[hash] = os.clock() end
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
end

function Scene.Forget()
    s_Added = {}
    s_Edited = {}
    s_Focus = nil
end

return Scene
